#!/bin/bash
set -euo pipefail
# Pipefail for errors:
# -e exit immediately
# -u treat unset variables as an error (typos)
# -o pipefail --> Pipe fails if any command in the pipe fails.

# TensorWave Bash Script Coloring Template
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

# General Server Variables/Configs
DATASTORE="ipmi.json"                               # File for server names
OUTFILE="cluster_liquid_leaks.csv"                  # File to save leak info
PREFIX="tus1-p"                                     # Current naming prefix
ENDPOINT="/redfish/v1/Chassis/1/Sensors/LiquidLeak" # Redfish leak endpoint

# Function for printing the 'how-to' message for the script to CLI
usage() {
    # Where Basename "$0" is the script name
    echo -e "${BOLD}Usage:{NC}
    $(basename "$0") [--prefix PREFIX] [--datastore FILE] [--outfile FILE]

    ${BOLD}Options:${NC}
    --prefix PREFIX      Filter server names that start with this prefix (default: ${BOLD}${PREFIX}${NC})
    --datastore FILE     Path to ipmi.json (default: ${BOLD}${DATASTORE}${NC})
    --outfile FILE       Output CSV path (default: ${BOLD}${OUTFILE}${NC})

    ${BOLD}Description:${NC}
    Reads ${BOLD}ipmi.json${NC}, queries each server's Redfish LiquidLeak sensor via ${BOLD}./redfishcmd${NC},
    and writes a CSV of servers where a leak is detected."
}

# Argument parsing for the script
while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)   PREFIX="${2:-}"; shift 2;;
      --datastore)   DATASTORE="${2:-}"; shift 2;;
      --outfile)   OUTFILE="${2:-}"; shift 2;;
      -h|--help) usage; exit 0 ;;
      *) echo -e "${RED}Unknown option:${NC} $1"; usage; exit 1 ;;
    esac
done


# Script preflight checks Start
if [[ ! -f "$DATASTORE" ]]; then
  echo -e "${RED}Missing datastore:${NC} ${DATASTORE}"
  exit 1
fi

if [[ ! -x "./redfishcmd" ]]; then
  echo -e "${RED}Missing or non-executable:${NC} ./redfishcmd"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo -e "${RED}jq not found${NC} (required)"
  exit 1
fi
# Script preflight checks end 

# Initial script status banner
echo -e "${BOLD}Scanning for leaks..${NC}"
echo -e "  Datastore : ${BOLD}${DATASTORE}${NC}"
echo -e "  Prefix    : ${BOLD}${PREFIX}${NC}"
echo -e "  Endpoint : ${BOLD}${ENDPOINT}${NC}"
echo -e "  Output    : ${BOLD}${OUTFILE}${NC}"
echo

# Pulling list of names for ipmi.json
# mapfile -t ARRAY < <(command ...)
mapfile -t SERVER_NAMES < <(jq -r --arg p "$PREFIX" '.[] | select(.name | startswith($p)) | .name' "$DATASTORE")
# If no matching servers found then emit an empty header-only CSV
if [[ ${#SERVER_NAMES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No servers found with prefix '${PREFIX}'.${NC}"
  echo "name,status" > "$OUTFILE"
  exit 0
fi

# Temp Output CSV preparation
TMP_OUT="$(mktmp)"
echo "name,status" > "$TMP_OUT"

LEAK_COUNT=0
FAIL_COUNT=0
TOTAL=${#SERVER_NAMES[@]}
for NAME in "${SERVER_NAMES[@]}"; do
  # Query Redfish for leak sensor value
  # Could // empty to avoid 'null' if path missing
  LIQUID_LEAK="$(./redfishcmd "$NAME" "$ENDPOINT" | jq -r '.Oem.Supermicro.SensorValue // empty' || true)"

  if [[ -z "$LIQUID_LEAK" ]]; then
    echo -e "${YELLOW}${NAME}${NC} -- Sensor value ${YELLOW}missing/empty${NC}"
    continue
  
  if [[ "$LIQUID_LEAK" == *"leakage detected"* ]]; then
    echo -e "${RED}${NAME}${NC} -- ${BOLD}Leak Detected${NC}"
    printf "%s,%s\n" "$NAME" "Leak Detected" >> "$TMP_OUT"
    ((LEAK_COUNT++))
    # Output to CSV
  elif [[ "$LIQUID_LEAK" == *"is not responding"* ]]; then
    echo -e "${YELLOW}${NAME}${NC} -- Failed to connect"
    ((FAIL_COUNT++))
    # Not output to CSV 
  else
    echo -e "${GREEN}${NAME}${NC} -- No leak"
    # Not output to CSV
  fi
done

mv "$TMP_OUT" "$OUTFILE"

echo
echo -e "${BOLD}Done!${NC} Checked ${BOLD}${TOTAL}${NC} servers."
echo -e "  ${RED}Leaks Detected:${NC} ${BOLD}${LEAK_COUNT}${NC}"
echo -e "  ${Yellow}Failed Connects:${NC} ${BOLD}${FAIL_COUNT}${NC}"
echo -e "  CSV Written to: ${BOLD}${OUTFILE}${NC}"