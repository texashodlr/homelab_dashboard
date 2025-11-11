#!/bin/bash
set -euo pipefail

### ~~~ Script Directory and Cluster Variables ~~~ ###
LOG_DIR="$1"
DATASTORE="$2"                               # File for server names
OUTFILE="cluster_offline_psus.csv"                  # File to save leak info
PREFIX="tus1-p"                                     # Current naming prefix

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
    $(basename "$0") reads ${BOLD}ipmi.json${NC}, queries each server's PSU to verify if its offline via ${BOLD}./query_power.sh${NC},
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

    ### ~~~ Query Power Script Exists ~~~ ###
if [[ ! -x "./query_power.sh" ]]; then
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
echo -e "  Datastore : ${BOLD}${DATASTORE}${NC}"
echo -e "  Prefix    : ${BOLD}${PREFIX}${NC}"
echo -e "  Output    : ${BOLD}${OUTFILE}${NC}"
echo

### ~~~ Script Extracting Servers from ipmi.json ~~~ ###
mapfile -t SERVER_NAMES < <(jq -r --arg p "$PREFIX" '.[] | select(.name | startswith($p)) | .name' "$DATASTORE")
TOTAL=${#SERVER_NAMES[@]}

### ~~~ If ipmi.json is empty exit ~~~ ###
if [[ ${#SERVER_NAMES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No servers found with prefix '${PREFIX}'.${NC}"
  echo "name,rack,ru,status" > "$OUTFILE"
  exit 0
fi

### ~~~ Script makes temp csv and inputs headers ~~~ ###
TMP_OUT="$(mktemp)"
LOCK_FILE="${TMP_OUT}.lock"
: > "$LOCK_FILE"
echo "name,rack,ru,status" > "$TMP_OUT"

export TMP_OUT LOCK_FILE RED GREEN YELLOW BOLD NC

check_one(){
	  local NAME="$1"
    local PSU_OFFLINE

    sleep $((RANDOM % 200))e-3

    PSU_OFFLINE=$(timeout -k 2 10 ./query_power.sh "$NAME" |
    jq -r --arg host "$NAME" '
      . as $r
      | ([ $r.power[]? | select(.LineInputVoltage < 100) ] | length) as $bad
      | (($r.rack // "") | if . == "" then "???" else . end) as $rack
      | (($r.ru   // "") | if . == "" then "??"  else . end) as $ru
      | select($bad > 0)
      | ("PSUs at 0v: " + (if $bad == 1 then "1 PSU" else ($bad|tostring + " PSUs") end)) as $status
      | "\($host)\t\($rack)\t\($ru)\t\($status)"
    ')
	if [[ -n "$PSU_OFFLINE" ]]; then
      local HOST RACK RU STATUS
      IFS=$'\t' read -r HOST RACK RU STATUS <<<"$PSU_OFFLINE"
      echo -e "${RED}${HOST}${NC} (${BOLD}Rack:${NC} ${RACK}, ${BOLD}RU:${NC} ${RU}) -- ${BOLD}${STATUS}${NC}"
      # printf "%s,%s,%s,%s\n" "$NAME" "$RACK" "$RU" "$STATUS" >> "$TMP_OUT"
      { flock -x 200; printf "%s,%s,%s,%s\n" "$NAME" "$RACK" "$RU" "$STATUS" >> "$TMP_OUT"; } 200>"$LOCK_FILE"
      return
	elif [[ "$PSU_OFFLINE" == *"is not responding"* ]]; then
		echo -e "${YELLOW}${NAME}${NC} -- Failed to connect"
	fi
}
export -f check_one

# Running the cluster checks in parallel
printf '%s\n' "${SERVER_NAMES[@]}" | xargs -r -n1 -P4 bash -c 'check_one "$1"' _

FAIL_DRIVE=$(awk -F, 'NR>1 && $NF ~ /PSUs at 0v/ {c++} END{print c+0}' "$TMP_OUT")

mv -- "$TMP_OUT" "$LOG_DIR"/"$OUTFILE"
rm -r -- "$LOCK_FILE"

echo
echo -e "${BOLD}Done!${NC} Checked ${BOLD}${TOTAL}${NC} servers."
echo -e "  ${RED}Failed PSUs:${NC} ${BOLD}${FAIL_DRIVE}${NC}"
echo -e "  CSV Written to: ${BOLD}${LOG_DIR}${OUTFILE}${NC}"
