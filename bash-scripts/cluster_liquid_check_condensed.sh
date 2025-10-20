#!/bin/bash
set -euo pipefail
# Pipefail for errors:
# -e exit immediately
# -u treat unset variables as an error (typos)
# -o pipefail --> Pipe fails if any command in the pipe fails.

### ~~~ Script Directory and Cluster Variables ~~~ ###
DATASTORE="ipmi.json"                               # File for server names
OUTFILE="cluster_liquid_leaks.csv"                  # File to save leak info
PREFIX="tus1-p"                                     # Current naming prefix
ENDPOINT="/redfish/v1/Chassis/1/Sensors/LiquidLeak" # Redfish leak endpoint

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
while [[ $# -gt 0 ]]; do
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
echo -e "  Datastore : ${BOLD}${DATASTORE}${NC}"
echo -e "  Prefix    : ${BOLD}${PREFIX}${NC}"
echo -e "  Endpoint : ${BOLD}${ENDPOINT}${NC}"
echo -e "  Output    : ${BOLD}${OUTFILE}${NC}"
echo

### ~~~ Script Extracting Servers from ipmi.json ~~~ ###
mapfile -t SERVER_NAMES < <(jq -r --arg p "$PREFIX" '.[] | select(.name | startswith($p)) | .name' "$DATASTORE")
    
### ~~~ If ipmi.json is empty exit ~~~ ###
if [[ ${#SERVER_NAMES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No servers found with prefix '${PREFIX}'.${NC}"
  echo "name,status" > "$OUTFILE"
  exit 0
fi

### ~~~ Script makes temp csv and inputs headers ~~~ ###
TMP_OUT="$(mktemp)"
echo "name,status" > "$TMP_OUT"

export ENDPOINT TMP_OUT RED GREEN YELLOW BOLD NC

check_one(){
	local NAME="$1"
	LIQUID_LEAK="$(./redfishcmd "$NAME" "$ENDPOINT" | jq -r '.Oem.Supermicro.SensorValue // empty' || true)"
	
	if [[ -z "$LIQUID_LEAK" ]]; then
		echo -e "${YELLOW}${NAME}${NC} -- Sensor value ${YELLOW}missing/empty${NC}"
		return
	fi
	if [[ "$LIQUID_LEAK" == *"leakage detected"* ]]; then
		echo -e "${RED}${NAME}${NC} -- ${BOLD}Leak Detected${NC}"
		printf "%s,%s\n" "$NAME" "Leak Detected" >> "$TMP_OUT"
	elif [[ "$LIQUID_LEAK" == *"is not responding"* ]]; then
		echo -e "${YELLOW}${NAME}${NC} -- Failed to connect"
	fi
}
export -f check_one

# Running the cluster checks in parallel
printf '%s\n' "${SERVER_NAMES[@]}" | xargs -r -n1 -P8 bash -c 'check_one "$1"' _


mv "$TMP_OUT" "$OUTFILE"

echo
#echo -e "${BOLD}Done!${NC} Checked ${BOLD}${TOTAL}${NC} servers."
#echo -e "  ${RED}Leaks Detected:${NC} ${BOLD}${LEAK_COUNT}${NC}"
#echo -e "  ${Yellow}Failed Connects:${NC} ${BOLD}${FAIL_COUNT}${NC}"
echo -e "  CSV Written to: ${BOLD}${OUTFILE}${NC}"
