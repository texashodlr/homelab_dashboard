#!/bin/bash
NAME=${1}
DATASTORE="ipmi.json"

IP=$(jq -r ".[]| select(.name==\"$NAME\")|.ip" $DATASTORE)

if [ -z "$IP" ]; then
    echo "Unable to determine IP for $NAME" 1>&2
    exit 1
fi
IPMI_USER=$(jq -r ".[]| select(.name==\"$NAME\")|.username" $DATASTORE)
IPMI_PASS=$(jq -r ".[]| select(.name==\"$NAME\")|.password" $DATASTORE)
LAN_MAC=$(jq -r ".[]| select(.name==\"$NAME\")|.lanmac" $DATASTORE | tr a-z A-Z)

ID=$IPMI_USER
PW=$IPMI_PASS
IS_REBOOT_NEEDED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color


function ipmi_rawcmd() {
    if [ ! -n "$1" ] || [ ! -n "$2" ]; then
        echo "Failed \n"
        exit 1
    fi
    local val
    if [ "$2" -eq "1" ]; then
        #val=`ipmitool -I lanplus -H $IP -U $IPMI_USER -P $IPMI_PASS $1` ##ok: 0 filed: 1
        val=$(ipmitool -H $IP -U $IPMI_USER -P $IPMI_PASS $1) ##ok: 0 filed: 1
    else
        #ipmitool -I lanplus -H $IP -U $IPMI_USER -P $IPMI_PASS $1 > /dev/null ##ok: 0 filed: 1
        ipmitool -H $IP -U $IPMI_USER -P $IPMI_PASS $1 >/dev/null ##ok: 0 filed: 1
    fi

    if [ "$?" -eq "1" ]; then
        echo "Failed \n"
        exit 1
    fi
    if [ "$2" -eq "1" ]; then
        echo "$val"
    else
        echo "Done"
    fi
    return
}

val=$(ipmi_rawcmd "raw 0x30 0x68 0x28 0x09 0x18" "1")

if [ "$val" == " 32" ]; then
    echo -e "${YELLOW}BIOS STATUS:${NC}\\t${GREEN}BIOS is ONLINE${NC}"
elif [ "$val" == " 33" ]; then
    echo -e "${YELLOW}BIOS STATUS:${NC}\\t${GREEN}BIOS is ONLINE${NC}"
else
    echo -e "${YELLOW}BIOS STATUS:${NC}\\t${RED}BIOS is OFFLINE${NC}"
fi

