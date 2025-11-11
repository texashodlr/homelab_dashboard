#!/bin/bash
NAME=${1}
DATASTORE="ipmi.json"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SLOT_COUNT=11

if [ -z "$NAME" ] || [ "$NAME" == "--help" ] ; then
    echo -ne "${BOLD}Usage:${NC}
    ${BOLD}$(basename "$0") [NAME] ${NC}

    Where ${BOLD}[NAME]${NC} is a server name located in ${BOLD}ipmi.json${NC}. 

    ${BOLD}Description:${NC}
    This command will output power supply input voltages for the given server. It will
    return data in JSON format, which will be in the form of:
    {
        "hostname": "tus1-gpu-0000",
        "power": [
            {
            "id": "0",
            "name": "Power Supply Bay 1",
            "LineInputVoltage": 206
            },
            {
            "id": "1",
            "name": "Power Supply Bay 2",
            "LineInputVoltage": 206
            },
            {
            "id": "2",
            "name": "Power Supply Bay 3",
            "LineInputVoltage": 207
            },
            {
            "id": "3",
            "name": "Power Supply Bay 4",
            "LineInputVoltage": 207
            }
        ]
    }


    ${BOLD}Example: ${NC}
    $(basename "$0") tus1-gpu-0000
    
    ${BOLD}Example to csv output: ${NC}
    $(basename "$0") tus1-gpu-0000 | jq -r \"[.hostname,.rack,.ru,.power[].LineInputVoltage]|@csv\"

" 1>&2
    exit 1
fi
IP=`jq -r ".[]| select(.name==\"$NAME\")|.ip" $DATASTORE`
RACK=`jq -r ".[]| select(.name==\"$NAME\")|.rack" $DATASTORE`
RU=`jq -r ".[]| select(.name==\"$NAME\")|.ru" $DATASTORE`

ping -W 5 -c 1 ${IP} 2>/dev/null 1>/dev/null
if [ "$?" == 0 ]; then
    ./redfishcmd ${NAME} /redfish/v1/Chassis/1/Power |jq -r '[.PowerSupplies[]|{id:.MemberId,name:.Name,LineInputVoltage:.LineInputVoltage}]' | jq -r "{hostname:\"${NAME}\",rack:\"${RACK}\",ru:\"${RU}\",power:.}"
else
    echo "$NAME in Rack $RACK at RU $RU is not responding on $IP" 1>&2
    exit 1
fi
