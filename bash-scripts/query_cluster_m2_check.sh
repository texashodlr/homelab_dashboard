#!/bin/bash
set -euo pipefail

### ~~~ Script Directory and Cluster Variables ~~~ ###
LOG_DIR="$1"
DATASTORE="$2"                               # File for server names
OUTFILE="cluster_failed_m2.csv"                  # File to save leak info
ENDPOINT="/redfish/v1/Chassis/HA-RAID.0.StorageEnclosure.0/Drives/Disk.Bay.NUM"
PREFIX="tus1-p"                                     # Current naming prefix

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
    $(basename "$0") reads ${BOLD}ipmi.json${NC}, queries each server's M2 to verify if its offline via ${BOLD}./query_power.sh${NC},
    and writes a CSV of servers where a psu is at 0 volts (v) (basically offline)."
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
echo -e "${BOLD}Scanning for failed M2 Drives...${NC}"
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
  echo "name,m2-ssd1-sn,m2-ssd1-health,m2-ssd1-othererrcount,m2-ssd1-mediaerrcount,m2-ssd2-sn,m2-ssd2-health,m2-ssd2-othererrcount,m2-ssd2-mediaerrcount,status" > "$OUTFILE"
  exit 0
fi

### ~~~ Script Tuning Knobs (Otherwise I ping spam the cluster...) ~~~ ###
#PARALLEL=4
#PER_CALL_TIMEOUT=10
#RETRIES=3
#BACKOFF_BASE=0.4
#JITTER_MAX_MS=250

### ~~~ Script makes temp csv and inputs headers ~~~ ###
TMP_OUT="$(mktemp)"
LOCK_FILE="${TMP_OUT}.lock"
: > "$LOCK_FILE"
echo "name,m2-ssd1-sn,m2-ssd1-health,m2-ssd1-othererrcount,m2-ssd1-mediaerrcount,m2-ssd2-sn,m2-ssd2-health,m2-ssd2-othererrcount,m2-ssd2-mediaerrcount,status" > "$TMP_OUT"

export TMP_OUT LOCK_FILE RED GREEN YELLOW BOLD NC 

check_one(){
  local NAME="$1"
  
  # Jitter control to not timeout BMCs
  sleep $((RANDOM % 200))e-3

  local -a SNs=() Healths=() OtherErrCount=() MediaErrCounts=()
  local STATUS=''
  
  for i in $(seq 0 1); do
    local RAW rc
    RAW=$(timeout -k 2 10 ./redfishcmd "$NAME" "/redfish/v1/Chassis/HA-RAID.0.StorageEnclosure.0/Drives/Disk.Bay.$i" 2>&1)
    rc=$?
    if ((rc !=0 )) || [[ -z "$RAW" ]]; then
      # Marked as unknown on failure
      SNs[i]="" ; Healths[i]="" ; OtherErrCount[i]="" ; MediaErrCount[i]="" 
      continue
    fi

    local TSV
    TSV=$(jq -r '[(.SerialNumber // ""), (.Status.Health // ""), (.Oem.Supermicro.OtherErrCount // ""), (.Oem.Supermicro.MediaErrCount // "")] | @tsv' <<<"$RAW" 2>/dev/null || TSV=$'\t')

    local sn="" health="" othererrcount="" mediaerrcount="" status=""
    IFS=$'\t' read -r sn health othererrcount mediaerrcount <<<"$TSV"
    
    SNs[i]="$sn"
    Healths[i]="$health"
    OtherErrCounts[i]="$othererrcount"
    MediaErrCounts[i]="$mediaerrcount"

    if [[ "$sn" == *"UNKNOWN"* || "$health" != *"OK"* ]]; then
      status="potential m2 drive bad"
    elif [[ "$othererrcount" != "0" || "$mediaerrcount" != "0" ]]; then
      status="possible m2 drive errors detected"
    fi
    STATUS=$status
  done
  # CSV Row add to the lock file
  if [[ "$STATUS" == "potential m2 drive bad" || "$STATUS" == "possible m2 drive errors detected" ]]; then
    # Basically only editing the file with broken things, else ignore.
    { flock -x 200; printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' "$NAME" "${SNs[0]}" "${Healths[0]}" "${OtherErrCounts[0]}" "${MediaErrCounts[0]}" "${SNs[1]}" "${Healths[1]}" "${OtherErrCounts[1]}" "${MediaErrCounts[1]}" "$STATUS" >> "$TMP_OUT"; } 200>"$LOCK_FILE"
  fi
}
export -f check_one

# Running the cluster checks in parallel
printf '%s\n' "${SERVER_NAMES[@]}" | xargs -r -n1 -P4 bash -c 'check_one "$0"'

FAIL_DRIVE=$(awk -F, 'NR>1 && $NF ~ /m2 drive bad|m2 drive errors/ {c++} END{print c+0}' "$TMP_OUT")
mv -- "$TMP_OUT" "$LOG_DIR"/"$OUTFILE"
rm -r -- "$LOCK_FILE"

echo
echo -e "${BOLD}Done!${NC} Checked ${BOLD}${TOTAL}${NC} servers."
echo -e "  ${RED}Failed M2 Drives:${NC} ${BOLD}${FAIL_DRIVE}${NC}"
echo -e "  CSV Written to: ${BOLD}${LOG_DIR}${OUTFILE}${NC}"
