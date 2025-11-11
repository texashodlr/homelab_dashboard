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
Models=() SNs=() FirmwareVersions=() LanesInUse=() Healths=() States=()
STATUS=""
for i in $(seq 1 11); do
  RAW=$(timeout -k 2 10 ./redfishcmd "$NAME" "/redfish/v1/Chassis/1/PCIeDevices/NIC$i" 2>&1)
  rc=$?
  if ((rc !=0 )) || [[ -z "$RAW" ]]; then
    # Marked as unknown on failure
    SNs[i]="" ; Healths[i]=""
    continue
  fi

  TSV=$(jq -r '[(.Model // ""), (.SerialNumber // ""), (.FirmwareVersion // ""),(.PCIeInterface.LanesInUse // ""), (.Status.Health // ""), (.Status.State // "")] | @tsv' <<<"$RAW" 2>/dev/null || TSV=$'\t')

  model="" sn="" firmwareversions="" lanesinuse="" health="" states="" status=""
  IFS=$'\t' read -r model sn firmwareversions lanesinuse health states <<<"$TSV"
  Models[i]="$model"
  SNs[i]="$sn"
  FirmwareVersions[i]="$firmwareversions"
  LanesInUse[i]="$lanesinuse"
  Healths[i]="$health"
  States[i]="$states"
  if [[ "$sn" == *"UNKNOWN"* || "$health" != *"OK"* ]]; then
    echo -e "Faulty SN: ${sn} and Health ${health}"
    status="potential GPU bad"
  else
    status="Healthy"
  fi
    STATUS=$status 
done
echo -e "${YELLOW}NICs' STATUS:${NC} ${RED}${STATUS}${NC}"
for j in $(seq 1 11); do
  echo -e "\\t${BOLD}NIC #${j}:${NC}" 
  echo -e "\\t\\t${BOLD}Model          :${NC} ${RED}${Models[$j]}${NC}"
  echo -e "\\t\\t${BOLD}SN             :${NC} ${RED}${SNs[$j]}${NC}"
  echo -e "\\t\\t${BOLD}FirmwareVersion:${NC} ${RED}${FirmwareVersions[$j]}${NC}"
  echo -e "\\t\\t${BOLD}Health         :${NC} ${RED}${Healths[$j]}${NC}"
  echo -e "\\t\\t${BOLD}State          :${NC} ${RED}${States[$j]}${NC}"
done

exit 0