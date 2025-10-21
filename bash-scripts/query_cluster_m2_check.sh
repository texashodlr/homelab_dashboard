#!/bin/bash
set -euo pipefail

### ~~~ Script Directory and Cluster Variables ~~~ ###
DATASTORE="ipmi.json"                               # File for server names
OUTFILE="cluster_failed_m2.csv"                  # File to save leak info
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

### ~~~ If ipmi.json is empty exit ~~~ ###
if [[ ${#SERVER_NAMES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No servers found with prefix '${PREFIX}'.${NC}"
  echo "name,m2-ssd1-sn,m2-ssd1-health,m2-ssd1-othererrcount,m2-ssd1-mediaerrcount,m2-ssd2-sn,m2-ssd2-health,m2-ssd2-othererrcount,m2-ssd2-mediaerrcount" > "$OUTFILE"
  exit 0
fi

### ~~~ Script makes temp csv and inputs headers ~~~ ###
TMP_OUT="$(mktemp)"
LOCK_FILE="${TMP_OUT}.lock"
echo "name,m2-ssd1-sn,m2-ssd1-health,m2-ssd1-othererrcount,m2-ssd1-mediaerrcount,m2-ssd2-sn,m2-ssd2-health,m2-ssd2-othererrcount,m2-ssd2-mediaerrcount" > "$TMP_OUT"

export TMP_OUT LOCK_FILE RED GREEN YELLOW BOLD NC

check_one(){
  local NAME="$1"
  
  # Jitter control to not timeout BMCs
  sleep $((RANDOM % 200))e-3

  # TEST_QUERY_2=$(./redfishcmd $NAME /redfish/v1/Chassis/HA-RAID.0.StorageEnclosure.0/Drives/Disk.Bay.0 | jq -r '[.SerialNumber, .Status.Health, .Oem.Supermicro.OtherErrCount, .Oem.Supermicro.MediaErrCount]')


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

    local sn="" health="" othererrcount="" mediaerrcount=""
    IFS=$'\t' read -r sn health othererrcount mediaerrcount <<<"$TSV"
    
    SNs[i]="$sn"
    Healths[i]="$health"
    OtherErrCounts[i]="$othererrcount"
    MediaErrCounts[i]="$mediaerrcount"

    if [[ "$sn" == *"UNKNOWN"* || "$health" != *"OK"* ]]; then
      STATUS="potential nvme drive bad"
    elif [[ "$othererrcount" != "0" || "$mediaerrcount" != "0" ]]; then
      STATUS="possible m2 drive errors detected"
    fi
  done

  # CSV Row add to the lock file
  { 
    flock -x 200 printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' "$NAME" "${SNs[0]}" "${Healths[0]}" "${OtherErrCounts[0]}" "${MediaErrCounts[0]}" "${SNs[1]}" "${Healths[1]}" "${OtherErrCounts[1]}" "${MediaErrCounts[1]}" "$STATUS" >> "$TMP_OUT"
  } 200>"$LOCK_FILE"
}
export -f check_one

# Running the cluster checks in parallel
printf '%s\n' "${SERVER_NAMES[@]}" | xargs -r -n1 -P4 bash -c 'check_one "$0"'

mv -- "$TMP_OUT" "$OUTFILE"
rm -r -- "$LOCK_FILE"
echo
echo -e "  CSV Written to: ${BOLD}${OUTFILE}${NC}"