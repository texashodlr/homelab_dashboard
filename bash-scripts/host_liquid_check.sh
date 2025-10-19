#!/bin/bash
set -euo pipefail

### ~~~ Script Directory and Cluster Variables ~~~ ###
# Expection for running the script:
#   ./host_liquid_check.sh SERVER
#               or
#   echo "SERVER1 SERVER1....." | xargs -i -P 2 ./host_liquid_check.sh {}
NAME=${1}
DATASTORE="ipmi.json"
ENDPOINT="/redfish/v1/Chassis/1/Sensors/LiquidLeak"

### ~~~ Script Coloring Template ~~~ ###
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

### ~~~ Script CLI Definition ~~~ ###
usage() {
    # Where Basename "$0" is the script name
    echo -e "${BOLD}Usage:{NC}
    $(basename "$0") [SERVER-IP-00]

    ${BOLD}Description:${NC}
    $(basename "$0") accepts server ip(s) (ex: ${BOLD}tus1-p1-g1${NC}, queries the server's Redfish LiquidLeak sensor via ${BOLD}./redfishcmd${NC},
    and stdouts if a leak is detected."
}

### ~~~ Script Argument Passing ~~~ ###
while [[ $# -gt 1 ]]; do
    case "$1" in
      -h|--help)     usage; exit 0 ;;
      *)             echo -e "${RED}Unknown option:${NC} $1"; usage; exit 1 ;;
    esac
done

### ~~~ Script Preflight Checks START ~~~ ###
    ### ~~~ IP Validation ~~~ ###
if [ -z "$NAME" ]; then
    echo "Unable to determine IP for $NAME" 1>&2
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
echo -e "  Endpoint  : ${BOLD}${ENDPOINT}${NC}"
echo -e "  Server    : ${BOLD}${NAME}${NC}"
echo

### ~~~ Script Host Liquid Leak Check Command ~~~ ###
LIQUID_LEAK="$(./redfishcmd "$NAME" "$ENDPOINT" | jq -r '.Oem.Supermicro.SensorValue // empty' || true)"

### ~~~ Script Host Liquid Leak Catch ~~~ ###
if [[ -z "$LIQUID_LEAK" ]]; then
  echo -e "${YELLOW}${NAME}${NC} -- Sensor value ${YELLOW}missing/empty${NC}"
  exit 0
if [[ "$LIQUID_LEAK" == *"leakage detected"* ]]; then
  echo -e "${RED}${NAME}${NC} -- ${BOLD}Leak Detected${NC}"
  exit 0
else
  echo -e "${GREEN}${NAME}${NC} -- No leak"
fi