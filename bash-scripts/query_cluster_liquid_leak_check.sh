#!/bin/bash
set -euo pipefail
# Pipefail for errors:
# -e exit immediately
# -u treat unset variables as an error (typos)
# -o pipefail --> Pipe fails if any command in the pipe fails.

### ~~~ Script Directory and Cluster Variables ~~~ ###
LOG_DIR="$1"
DATASTORE="$2"                               # File for server names
OUTFILE="cluster_liquid_leaks.csv"                  # File to save leak info
PREFIX="tus1-p"                                     # Current naming prefix
ENDPOINT="/redfish/v1/Chassis/1/Sensors/LiquidLeak" # Redfish leak endpoint

  ### ~~~ Log Directory Exists ~~~ ###
if [[ -z "$LOG_DIR" ]]; then
  echo "Error: no log directory specified."
  exit 1
fi


### ~~~ Script Coloring Template ~~~ ###
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

### ~~~ Script CLI Definition ~~~ ###
usage() {
    # Where Basename "$0" is the script name
    echo -e "${BOLD}Usage:${NC}
    $(basename "$0")

    ${BOLD}Description:${NC}
    $(basename "$0") reads ${BOLD}ipmi.json${NC}, queries each server's Redfish LiquidLeak sensor via ${BOLD}./redfishcmd${NC},
    and writes a CSV of servers where a leak is detected."
}

### ~~~ Script Argument Passing ~~~ ###
while [[ $# -gt 2 ]]; do
    case "$1" in
      -h|--help)     usage; exit 0 ;;
      *)             echo -e "${RED}Unknown option:${NC} $1"; usage; exit 1 ;;
    esac
done

### ~~~ Script Preflight Checks START ~~~ ###
    ### ~~~ CSV Exists ~~~ ###
if [[ ! -f "$DATASTORE" ]]; then
  echo -e "${RED}Missing datastore:${NC} ${DATASTORE}"
  exit 1
fi

    ### ~~~ Redfishcmd Exists ~~~ ###
if [[ ! -x "./redfishcmd" ]]; then
  echo -e "${RED}Missing or non-executable:${NC} ./redfishcmd"
  exit 1
fi

    ### ~~~ jq Installed ~~~ ###
if ! command -v jq >/dev/null 2>&1; then
  echo -e "${RED}jq not found${NC} (required)"
  exit 1
fi
### ~~~ Script Preflight Checks END ~~~ ###

### ~~~ Script Initiation Checks ~~~ ###
echo -e "${BOLD}Scanning for leaks..${NC}"
echo -e "  Prefix    : ${BOLD}${PREFIX}${NC}"
echo -e "  Endpoint : ${BOLD}${ENDPOINT}${NC}"
echo -e "  Output    : ${BOLD}${OUTFILE}${NC}"
echo

### ~~~ Script Extracting Servers from ipmi.json ~~~ ###
mapfile -t SERVER_NAMES < <(jq -r --arg p "$PREFIX" '.[] | select(.name | startswith($p)) | .name' "$DATASTORE")
TOTAL=${#SERVER_NAMES[@]}


### ~~~ If ipmi.json is empty exit ~~~ ###
if [[ ${#SERVER_NAMES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No servers found with prefix '${PREFIX}'.${NC}"
  echo "name,status" > "$OUTFILE"
  exit 0
fi

### ~~~ Script Tuning Knobs (Otherwise I ping spam the cluster...) ~~~ ###
PARALLEL=4
PER_CALL_TIMEOUT=10
RETRIES=3
BACKOFF_BASE=0.4
JITTER_MAX_MS=250

### ~~~ Script makes temp csv and inputs headers ~~~ ###
TMP_OUT="$(mktemp)"
LOCK_FILE="${TMP_OUT}.lock"
: > "$LOCK_FILE"
echo "name,status" > "$TMP_OUT"

export ENDPOINT TMP_OUT LOCK_FILE RED GREEN YELLOW BOLD NC \
       PER_CALL_TIMEOUT RETRIES BACKOFF_BASE JITTER_MAX_MS

check_one(){
	local NAME="$1"

  # Jitter control to not timeout BMCs
  sleep $((RANDOM % 200))e-3


  local attempt rc RAW
  for ((attempt=1; attempt<=RETRIES; attempt++)); do
    RAW=$(timeout -k 2 "$PER_CALL_TIMEOUT" ./redfishcmd "$NAME" "$ENDPOINT" 2>&1)
    rc=$?

    if (( rc == 0)) && [[ -n "$RAW" ]]; then
      local VALUE
      VALUE=$(jq -r '.Oem.Supermicro.SensorValue // empty' <<<"$RAW" 2>/dev/null || VALUE="")
     
        # Connection Fail Conditional
      if [[ -z "$VALUE" ]]; then
        echo -e "${YELLOW}${NAME}${NC} -- Sensor value ${YELLOW}missing/empty${NC}"
        {
          flock -x 200
          printf "%s,%s\n" "$NAME" "missing/empty" >> "$TMP_OUT"
        } 200>"$LOCK_FILE"
        return
	    fi
    
      if [[ "$VALUE" == *"leakage detected"* ]]; then
        echo -e "${RED}${NAME}${NC} -- ${BOLD}Leak Detected${NC}"
        {
            flock -x 200
            printf "%s,%s\n" "$NAME" "Leak detected" >> "$TMP_OUT"
        } 200>"$LOCK_FILE"
      fi  
      return
    fi

    if (( attempt < RETRIES )); then
      local sleep_s
      sleep_s=$(awk -v b="$BACKOFF_BASE" -v n="$attempt" 'BEGIN{printf "%.3f", b*(2**(n-1))}')
      sleep "$sleep_s"
      sleep $((RANDOM % JITTER_MAX_MS))e-3
    fi
  done
  echo -e "${YELLOW}${NAME}${NC} -- ${BOLD}Failed to connect${NC}"
  { flock -x 200 printf "%s,%s\n" "$NAME" "missing/empty" >> "$TMP_OUT"; } 200>"$LOCK_FILE"
}
export -f check_one

# Running the cluster checks in parallel
printf '%s\n' "${SERVER_NAMES[@]}" | xargs -r -n1 -P"$PARALLEL" bash -lc 'check_one "$0"'

LEAK_COUNT=$(awk -F, 'NR>1 && $2=="Leak detected"{c++} END{print c+0}' "$TMP_OUT")
mv "$TMP_OUT" "$LOG_DIR"/"$OUTFILE"
rm -r -- "$LOCK_FILE"

echo
echo -e "${BOLD}Done!${NC} Checked ${BOLD}${TOTAL}${NC} servers."
echo -e "  ${RED}Leaks Detected:${NC} ${BOLD}${LEAK_COUNT}${NC}"
echo -e "  CSV Written to: ${BOLD}${LOG_DIR}${OUTFILE}${NC}"
