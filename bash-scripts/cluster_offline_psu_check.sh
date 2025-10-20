#!/bin/bash
set -euo pipefail

# Directions: (Sean) We're going to do the same process for liquid leaks 
#   only for power supply health. We want to check for power supplies that may be offline.

# Provided Scripts (Sean):
# "Here's a short script that will check all the power supply 
#    input voltages and output hosts that have one or more input lines down:"
# cat ipmi.json | jq -r '.[] |select(.name|startswith("tus1-p"))|select(.pod>0).name' | xargs -i -P 16 /bin/bash -c "./query_power.sh {} | jq -r '.|select(.power[].LineInputVoltage<100) |\"Server \(.hostname) in Rack \(.rack | if . == \"\" then \"???\" else . end) at RU \(.ru | if . == \"\" then \"??\" else . end) is showing \([.power[]|select(.LineInputVoltage<100)]|length) power supply at 0v\"'" | sort


### ~~~ Script Directory and Cluster Variables ~~~ ###
DATASTORE="ipmi.json"                               # File for server names
OUTFILE="cluster_offline_psu.csv"                   # File to save leak info
QUERY_POWER="query_power.sh"                        # File for querying power
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
    echo -e "${BOLD}Usage:{NC}
    $(basename "$0")

    ${BOLD}Description:${NC}
    $(basename "$0") reads ${BOLD}ipmi.json${NC}, queries every server in the cluster's output power supply input voltages for the given server 
    via ${BOLD}./query_power.sh${NC},
    and writes a CSV of servers where a PSU line is down."
}

### ~~~ Script Argument Passing ~~~ ###
while [[ $# -gt 1 ]]; do
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
#cat ipmi.json | jq -r '.[] |select(.name|startswith("tus1-p"))|select(.pod>0).name'
mapfile -t SERVER_NAMES < <(jq -r --arg p "$PREFIX" '.[] | select(.name | startswith($p)) | .name' "$DATASTORE")
    
### ~~~ If ipmi.json is empty exit ~~~ ###
if [[ ${#SERVER_NAMES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No servers found with prefix '${PREFIX}'.${NC}"
  echo "name,status" > "$OUTFILE"
  exit 0
fi

### ~~~ Script makes temp csv and inputs headers ~~~ ###
TMP_OUT="$(mktmp)"
echo "name,status" > "$TMP_OUT"

### ~~~ Script Loop Begins ~~~ ###
OFFLINE_PSU_COUNT=0            # Counter for detected offline PSUs
FAIL_COUNT=0                   # Counter for fail to connects "[SERVER] is not responding..."
TOTAL=${#SERVER_NAMES[@]}
for NAME in "${SERVER_NAMES[@]}"; do
  # Query Redfish for leak sensor value
  # Could // empty to avoid 'null' if path missing
  # "./query_power.sh {} | jq -r '.|select(.power[].LineInputVoltage<100) |\"Server \(.hostname) in Rack \(.rack | if . == \"\" then \"???\" else . end) at RU \(.ru | if . == \"\" then \"??\" else . end) is showing \([.power[]|select(.LineInputVoltage<100)]|length) power supply at 0v\"'" | sort
  OFFLINE_PSU="$(./query_power "$NAME" | '.|select(.power[].LineInputVoltage<100) |\"Server \(.hostname) in Rack \(.rack | if . == \"\" then \"???\" else . end) at RU \(.ru | if . == \"\" then \"??\" else . end) is showing \([.power[] | select(.LineInputVoltage<100)] | length) power supply at 0v\"'" | sort)"

  if [[ -z "$OFFLINE_PSU" ]]; then
    echo -e "${YELLOW}${NAME}${NC} -- Sensor value ${YELLOW}missing/empty${NC}"
    continue
  
  if [[ "$OFFLINE_PSU" == *"leakage detected"* ]]; then
    echo -e "${RED}${NAME}${NC} -- ${BOLD}Leak Detected${NC}"
    printf "%s,%s\n" "$NAME" "Leak Detected" >> "$TMP_OUT"
    ((OFFLINE_PSU_COUNT++))
    # Output to CSV
  elif [[ "$OFFLINE_PSU" == *"is not responding"* ]]; then
    echo -e "${YELLOW}${NAME}${NC} -- Failed to connect"
    ((FAIL_COUNT++))
    # Not output to CSV 
  else
    echo -e "${GREEN}${NAME}${NC} -- No offline PSUs detected"
    # Not output to CSV
  fi
done

mv "$TMP_OUT" "$OUTFILE"

echo
echo -e "${BOLD}Done!${NC} Checked ${BOLD}${TOTAL}${NC} servers."
echo -e "  ${RED}Leaks Detected:${NC} ${BOLD}${LEAK_COUNT}${NC}"
echo -e "  ${Yellow}Failed Connects:${NC} ${BOLD}${FAIL_COUNT}${NC}"
echo -e "  CSV Written to: ${BOLD}${OUTFILE}${NC}"

cat ipmi.json 
| jq -r '.[] |select(.name|startswith("tus1-p"))|select(.pod>0).name' 
| xargs -i -P 16 /bin/bash -c "./query_power.sh {} 
  | jq -r '.|select(.power[].LineInputVoltage<100) | \"Server \(.hostname) in Rack \(.rack | if . == \"\" then \"???\" else . end) at RU \(.ru | if . == \"\" then \"??\" else . end) is showing \([.power[]|select(.LineInputVoltage<100)]|length) power supply at 0v\"'
    " 
| sort