#!/bin/bash
set -euo pipefail

### ~~~ Script Directory and Cluster Variables ~~~ ###
NAME=${1}

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
while [[ $# -gt 1 ]]; do
    case "$1" in
      -h|--help)     usage; exit 0 ;;
      *)             echo -e "${RED}Unknown option:${NC} $1"; usage; exit 1 ;;
    esac
done

### ~~~ Script Preflight Checks START ~~~ ###

    ### ~~~ Query Power Script Exists ~~~ ###
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

### ~~~ Script Executes NVME Checks ~~~ ###
SNs=() Healths=()
STATUS=""
for i in $(seq 1 4); do
  RAW=$(timeout -k 2 10 ./redfishcmd "$NAME" "/redfish/v1/Chassis/1/PCIeDevices/NVMeSSD$i" 2>&1)
  rc=$?
  if ((rc !=0 )) || [[ -z "$RAW" ]]; then
    # Marked as unknown on failure
    SNs[i]="" ; Healths[i]=""
    continue
  fi

  TSV=$(jq -r '[(.SerialNumber // ""), (.Status.Health // "")] | @tsv' <<<"$RAW" 2>/dev/null || TSV=$'\t')

  sn="" health="" status=""
  IFS=$'\t' read -r sn health <<<"$TSV"
  SNs[i]="$sn"
  Healths[i]="$health"
  if [[ "$sn" == *"UNKNOWN"* || "$health" != *"OK"* ]]; then
    status="potential nvme drive bad"
  else
    status="healthy"
  fi
    STATUS=$status 
done

echo -e "${BOLD}NVME DRIVE STATUS:${NC}${YELLOW}${NAME}${NC} --> \\n\\t\\t${BOLD}DRIVE #1:${NC}${SNs[1]} , ${RED}${Healths[1]}${NC}\\n\\t\\t${BOLD}DRIVE #2:${NC}${SNs[2]} , ${RED}${Healths[2]}${NC}\\n\\t\\t${BOLD}DRIVE #3:${NC}${SNs[3]} , ${RED}${Healths[3]}${NC}\\n\\t\\t${BOLD}DRIVE #4:${NC}${SNs[4]} , ${RED}${Healths[4]}${NC}\\n\\t\\t${BOLD}Overall NVME STATUS:${NC}\\t${RED}${STATUS}${NC}\\n"
exit 0