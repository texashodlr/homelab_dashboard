#!/bin/bash
#set -euo pipefail 


### ~~~ Script Directory and Cluster Variables ~~~ ###
DATASTORE="cluster_psu.csv"                               # File for server names
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

### ~~~ Script makes temp csv and inputs headers ~~~ ###
#TMP_OUT="$(mktemp)"
echo "name,rack,ru,psu-b1,psu-b2,psu-b3,psu-b4" > "$OUTFILE"

awk -F, 'NR>1 {print $1}' cluster_psu.csv | while read -r NAME; do
    echo -e "AWK'ng"
    RAW=$(./query_power.sh "$NAME" 2>&1 )
    #RAW=$(timeout -k 2 15 ./query_power.sh "$NAME" 2>&1 )
    # echo -e "$RAW"
    rc=$?

    if (( rc != 0)) || [[ -z "$RAW" ]]; then
        printf '%s,%s,%s,%s,%s,%s,%s\n' "$NAME" "???" "??" "" "" "" "" >> "$OUTFILE"
        echo "WARN: $NAME connection failed (rc=$rc)"
        continue
    fi
    LINE=$(
        jq -r --arg host "$NAME" '
        . as $r
        | (($r.rack // "") | if . == "" then "???" else . end) as $rack
        | (($r.ru   // "") | if . == "" then "??"  else . end) as $ru
        | ($r.power // [] | sort_by(.id | tonumber)) as $p
        | ($p[0].LineInputVoltage | tonumber? // 0) as $b1
        | ($p[1].LineInputVoltage | tonumber? // 0) as $b2
        | ($p[2].LineInputVoltage | tonumber? // 0) as $b3
        | ($p[3].LineInputVoltage | tonumber? // 0) as $b4
        | "\($host),\($rack),\($ru),\($b1),\($b2),\($b3),\($b4)"
        ' 2>/dev/null <<<"$RAW"
    )

    if [[ -z "$LINE" ]]; then
      printf '%s,\n%s,\n%s,\n%s,\n%s,\n%s,\n%s\n' "$NAME" "???" "??" "" "" "" "" >> "$OUTFILE"
      echo "WARN: $NAME produced unparsable JSON"
      continue
    fi
    #echo -e "$LINE"
    printf '%s\n' "$LINE" >> "$OUTFILE"
done

#mv -- "$TMP_OUT" "$OUTFILE"
echo
echo -e "  CSV Written to: ${BOLD}${OUTFILE}${NC}"


