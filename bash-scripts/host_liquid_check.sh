#!/bin/bash
set -euo pipefail

### ~~~ Script Directory and Cluster Variables ~~~ ###
# Expectation for running the script:
#   ./host_liquid_check.sh SERVER
#     or
#   printf '%s\n' SERVER1 SERVER2 ... | xargs -n1 -P 2 ./host_liquid_check.sh
DATASTORE="ipmi.json"   # (not used here; kept for context)
ENDPOINT="/redfish/v1/Chassis/1/Sensors/LiquidLeak"

### ~~~ Script Coloring Template ~~~ ###
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

### ~~~ Script CLI Definition ~~~ ###
usage() {
  # Where basename "$0" is the script name
  echo -e "${BOLD}Usage:${NC}
  $(basename "$0") ${BOLD}[SERVER-NAME-OR-IP]${NC}

  ${BOLD}Description:${NC}
  $(basename "$0") accepts a server (e.g., ${BOLD}tus1-p1-g1${NC}), queries the server's
  Redfish LiquidLeak sensor via ${BOLD}./redfishcmd${NC}, and prints a status line."
}

### ~~~ Script Argument Parsing ~~~ ###
NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -*) echo -e "${RED}Unknown option:${NC} $1"; usage; exit 1 ;;
    *) NAME="$1"; shift; break ;;   # first non-flag is the server name
  esac
done

### ~~~ Script Preflight Checks START ~~~ ###
# Name provided?
if [[ -z "${NAME:-}" ]]; then
  echo -e "${RED}Missing server argument.${NC}"; usage
  exit 1
fi

# redfishcmd present and executable?
if [[ ! -x "./redfishcmd" ]]; then
  echo -e "${RED}Missing or non-executable:${NC} ./redfishcmd"
  exit 1
fi

# jq present?
if ! command -v jq >/dev/null 2>&1; then
  echo -e "${RED}jq not found${NC} (required)"
  exit 1
fi
### ~~~ Script Preflight Checks END ~~~ ###

### ~~~ Script Initiation Banner ~~~ ###
echo -e "${BOLD}Scanning for leaks..${NC}"
echo -e "  Datastore : ${BOLD}${DATASTORE}${NC}  (info)"
echo -e "  Endpoint  : ${BOLD}${ENDPOINT}${NC}"
echo -e "  Server    : ${BOLD}${NAME}${NC}"
echo

### ~~~ Script Host Liquid Leak Check Command ~~~ ###
LIQUID_LEAK="$(./redfishcmd "$NAME" "$ENDPOINT" | jq -r '.Oem.Supermicro.SensorValue // empty' || true)"

### ~~~ Script Host Liquid Leak Catch ~~~ ###
if [[ -z "$LIQUID_LEAK" ]]; then
  echo -e "${YELLOW}${NAME}${NC} -- Sensor value ${YELLOW}missing/empty${NC}"
  exit 0
fi

if [[ "$LIQUID_LEAK" == *"leakage detected"* ]]; then
  echo -e "${RED}${NAME}${NC} -- ${BOLD}Leak Detected${NC}"
  exit 0
elif [[ "$LIQUID_LEAK" == *"is not responding"* ]]; then
  echo -e "${YELLOW}${NAME}${NC} -- Failed to connect"
  exit 0
else
  echo -e "${GREEN}${NAME}${NC} -- No leak"
fi
