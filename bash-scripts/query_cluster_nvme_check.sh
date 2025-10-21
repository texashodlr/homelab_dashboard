#!/bin/bash
set -euo pipefail

### ~~~ Script Directory and Cluster Variables ~~~ ###
DATASTORE="nvme_ipmi.json"                               # File for server names
OUTFILE="cluster_failed_nvme.csv"                  # File to save leak info
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
  echo "name,rack,ru,nvme-ssd1-sn,nvme-ssd2-sn,nvme-ssd3-sn,nvme-ssd4-sn" > "$OUTFILE"
  exit 0
fi

### ~~~ Script makes temp csv and inputs headers ~~~ ###
TMP_OUT="$(mktemp)"
echo "name,nvme-ssd1-sn,nvme-ssd1-health,nvme-ssd2-sn,nvme-ssd2-health,nvme-ssd3-sn,nvme-ssd3-health,nvme-ssd4-sn,nvme-ssd4-health" > "$TMP_OUT"

export TMP_OUT RED GREEN YELLOW BOLD NC
check_one(){
  declare -a SNs=() Healths=()
  for i in $(seq 1 4); do
    local NAME="$1"
    read -r sn health < <(./redfishcmd "$NAME" "/redfish/v1/Chassis/1/PCIeDevices/NVMeSSD$i" | jq -r '[.SerialNumber, .Status.Health] | @tsv')
    SNs[i]=$sn
    Healths[i]=$health
  done
  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s\n" "$NAME" "${SNs[1]}" "${Healths[1]}" "${SNs[2]}" "${Healths[2]}" "${SNs[3]}" "${Healths[3]}" "${SNs[4]}" "${Healths[4]}" >> $TMP_OUT
}
export -f check_one

# Running the cluster checks in parallel
printf '%s\n' "${SERVER_NAMES[@]}" | xargs -r -n1 -P2 bash -c 'check_one "$1"' _

mv -- "$TMP_OUT" "$OUTFILE"
echo
echo -e "  CSV Written to: ${BOLD}${OUTFILE}${NC}"


# Output CSV
# server,rack,ru,nvmessd1-sn,nvmessd2-sn,nvmessd3-sn,nvmessd4-sn
# tus1-p16-g56,100,1,

