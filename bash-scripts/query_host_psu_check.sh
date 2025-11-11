#!/bin/bash
set -euo pipefail 


### ~~~ Script Directory and Cluster Variables ~~~ ###
NAME=${1}
DATASTORE="ipmi.json"                       # File for server names
OUTFILE="cluster_offline_psus_detailed.csv"

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
    ### ~~~ CSV Exists ~~~ ###

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

### ~~~ Script Host PSU Check (split into variables) ~~~ ###
rack="???" ; ru="??"
declare -a PSU_V       # 1..4
PSU_V=(unused "" "" "" "")  # pad index 0

RAW=$(timeout -k 2 15 ./query_power.sh "$NAME" 2>&1)
rc=$?

if (( rc != 0 )) || [[ -z "$RAW" ]]; then
  # Keep defaults: rack="???", ru="??", PSU_V[1..4]=""
  :
else
  # rack, ru, b1..b4 as TSV; volts coerced with tonumber? // 0
  TSV=$(jq -r '
    . as $r
    | [ (($r.rack // "") | if .=="" then "???" else . end)
      ,(($r.ru   // "") | if .=="" then "??"  else . end)
      ,($r.power // [] | sort_by(.id | tonumber)
         | [.[0].LineInputVoltage, .[1].LineInputVoltage, .[2].LineInputVoltage, .[3].LineInputVoltage]
         | map(tonumber? // 0)
         | .[]
       )
      ] | @tsv
  ' <<<"$RAW" 2>/dev/null || true)

  if [[ -n "$TSV" ]]; then
    IFS=$'\t' read -r rack ru b1 b2 b3 b4 <<<"$TSV"
    PSU_V[1]="$b1"; PSU_V[2]="$b2"; PSU_V[3]="$b3"; PSU_V[4]="$b4"
  fi
fi

# ------ From here down, you can format however you like. Examples: ------

# 1) CSV line (exactly like your old $LINE content but built from vars)
#LINE="${NAME},${rack},${ru},${PSU_V[1]},${PSU_V[2]},${PSU_V[3]},${PSU_V[4]}"

# 2) Pretty print example (optional)
#echo    "                           name,rack,ru,psu-b1,psu-b2,psu-b3,psu-b4"
echo -e "${YELLOW}PSU STATUS:${NC}"
echo -e "\\t\\tRack:${RED}${rack}${NC}"
echo -e "\\t\\tRU  :${RED}${ru}${NC}"
echo -e "\\t\\tPSU1:${RED}${b1}${NC}"
echo -e "\\t\\tPSU2:${RED}${b2}${NC}"
echo -e "\\t\\tPSU3:${RED}${b3}${NC}"
echo -e "\\t\\tPSU4:${RED}${b4}${NC}"


exit 0