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
SNs=() Healths=() OtherErrCount=() MediaErrCounts=()
STATUS="Healthy"
for i in $(seq 0 1); do
  RAW=$(timeout -k 2 10 ./redfishcmd "$NAME" "/redfish/v1/Chassis/HA-RAID.0.StorageEnclosure.0/Drives/Disk.Bay.$i" 2>&1)
  rc=$?
  if ((rc !=0 )) || [[ -z "$RAW" ]]; then
    # Marked as unknown on failure
    SNs[i]="" ; Healths[i]="" ; OtherErrCount[i]="" ; MediaErrCount[i]="" 
    continue
  fi

  TSV=$(jq -r '[(.SerialNumber // ""), (.Status.Health // ""), (.Oem.Supermicro.OtherErrCount // ""), (.Oem.Supermicro.MediaErrCount // "")] | @tsv' <<<"$RAW" 2>/dev/null || TSV=$'\t')

  sn="" health="" othererrcount="" mediaerrcount="" status=""
  IFS=$'\t' read -r sn health othererrcount mediaerrcount <<<"$TSV"
  SNs[i]="$sn"
  Healths[i]="$health"
  OtherErrCounts[i]="$othererrcount"
  MediaErrCounts[i]="$mediaerrcount"
  if [[ "$sn" == *"UNKNOWN"* || "$health" != *"OK"* ]]; then
    status="potential m2 drive bad"
  elif [[ "$othererrcount" != "0" || "$mediaerrcount" != "0" ]]; then
    status="possible m2 drive errors detected"
  elif [[ "$status" == "" ]]; then
    status="Healthy"
  fi
  STATUS=$status
done

echo -e "${YELLOW}M2 DRIVE STATUS:${NC}\\n  ${YELLOW}M2 DRIVE #1:${NC}\\n\\tSSN: \\t  ${RED}${SNs[0]}${NC}\\n\\tHealth:   ${RED}${Healths[0]}${NC}\\n\\tOtherErr: ${RED}${OtherErrCounts[0]}${NC}\\n\\tMediaErr: ${RED}${MediaErrCounts[0]}${NC}\\n  ${YELLOW}M2 DRIVE #2:${NC}\\n\\tSSN: \\t  ${RED}${SNs[1]}${NC}\\n\\tHealth:   ${RED}${Healths[1]}${NC}\\n\\tOtherErr: ${RED}${OtherErrCounts[1]}${NC}\\n\\tMediaErr: ${RED}${MediaErrCounts[1]}${NC}\\n${YELLOW}Overall M2 Status:${NC}${RED}${STATUS}${NC}"
exit 0