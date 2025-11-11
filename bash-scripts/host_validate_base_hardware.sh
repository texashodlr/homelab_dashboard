#!/bin/bash
set -euo pipefail


NAME=${1}
DATASTORE="ipmi.json"

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
    $(basename "$0") kicks off several scripts TBD TBD TBD TBD."
}

### ~~~ Script Argument Passing ~~~ ###
while [[ $# -gt 1 ]]; do
    case "$1" in
      -h|--help)     usage; exit 0 ;;
      *)             echo -e "${RED}Unknown option:${NC} $1"; usage; exit 1 ;;
    esac
done

### ~~~ Script Breakout ~~~ ###
echo -e "${GREEN}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${NC}"
echo -e "${GREEN}~~~ Starting Host Validation ~~~${NC}\\n"
#echo -e "~~~ [[[ HOST VALIDATION TEST 1/4 ]]] ~~~\\n"
	# Liquid Leaks
#echo "Performing host liquid leak check"
./query_host_liquid_leak_check.sh "$NAME"
#echo "Completed host liquid leak check"
sleep 2

#echo -e "~~~ [[[ HOST VALIDATION TEST 2/4 ]]] ~~~\\n"	
	# All PSUs Online
#echo "Performing host PSU check"
./query_host_boot_status.sh "$NAME"
sleep 2

./query_host_psu_check.sh "$NAME"
#echo "Completed host PSU check"
sleep 2

#echo "Performing detailed host PSU check"
#./query_host_psu_check.sh "$LOG_DIR"
#echo "Completed detailed host PSU check"
#sleep 10

#echo -e "~~~ [[[ HOST VALIDATION TEST 3/4 ]]] ~~~\\n"
	# All NVME Online
#echo "Performing detailed host NVME check"
./query_host_nvme_check.sh "$NAME"
#echo "Completed detailed host NVME check"
sleep 2

#echo "~~~ [[[ HOST VALIDATION TEST 4/4 ]]] ~~~\\n"
	# All M.2 Online
#echo "Performing detailed host M2 Drive check"
./query_host_m2_check.sh "$NAME"
#echo "Completed detailed host M2 Drive check"
sleep 2

./query_host_gpu_check.sh "$NAME"
sleep 2

./query_host_nic_check.sh "$NAME"
sleep 2

echo -e "${YELLOW}QUERYING FIRMWARE${NC}\\n"
./query_firmware.sh "$NAME"
sleep 2
echo -e "\\n"

echo -e "${GREEN}~~~ [[[ CLUSTER VALIDATION TEST $(date +"%Y%m%d_%H%M%S") COMPLETED  ]]] ~~~${NC}"
echo -e "${GREEN}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${NC}"
exit 0
