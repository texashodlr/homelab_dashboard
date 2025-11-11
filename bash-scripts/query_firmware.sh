#!/bin/bash
NAME=${1}
DATASTORE="ipmi.json"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SLOT_COUNT=11
TMPFILE_PREFIX="query_firmware_$$_"
TMPFILE_PATH="/tmp/query_firmware"
mkdir -p "$TMPFILE_PATH"
# echo $TMPFILE_PREFIX; exit

HEADERS="Name,BIOS Version,TW Bios Settings,BMC Version,GPU Version"
for s in $(seq 1 ${SLOT_COUNT}); do
    HEADERS="${HEADERS},SLOT$s Manufacturer,SLOT$s Model,SLOT$s Firmware Version,SLOT$s MAC Address,SLOT$s PortCount,SLOT${s}P1 LinkStatus,SLOT${s}P1 CurrentSpeedGbps"
done


if [ -z "$NAME" ] || [ "$NAME" == "--help" ] ; then
    echo -ne "${BOLD}Usage:${NC}
    ${BOLD}$(basename "$0") [NAME] ${NC}

    Where ${BOLD}[NAME]${NC} is a server name located in ${BOLD}ipmi.json${NC}. 

    ${BOLD}Description:${NC}
    This command will output firmware versions for the given server. It will
    be in the form of:

    ${BOLD}${HEADERS}${NC}" 1>&2
    echo -e "
    ${BOLD}Example: ${NC}
    $(basename "$0") tw001

    You may wish to loop this and run it for multiple servers in the form of:

    ${BOLD}echo \"$HEADERS\"; \\
    for i in {001..054}; do ./$(basename "$0") tw\$i; done${NC}

" 1>&2
    exit 1
fi
IP=`jq -r ".[]| select(.name==\"$NAME\")|.ip" $DATASTORE`

function redfish_with_retry(){
    _label=$1
    shift
    _path=$1
    shift
    _method=$1
    shift
    _data=$1
    shift
    _jqfilter=$1
    shift
    _cmd=
    _retries=5
    _delay=5
    echo -e "$NAME - ${_label}... " 1>&2
    # echo curl -sk --user ${IPMI_USER}:${IPMI_PASS} https://${IP}${_path} -X${_method} -d "${_data}"
    _dataval=""
    if [ ! -z $_data ]; then
        _dataval="-d ${_data}"
    fi
    result=`./redfishcmd $NAME ${_path} -X${_method} $_dataval`
    ret=$?
    while [ "$ret" != "0" ]; do
        if [ "$_retries" -ge 0 ]; then
            echo -e "${YELLOW}$NAME - WARNING Error code ${BOLD}$ret${NC}${YELLOW} while $_label $_path - Will retry${NC}\n" 1>&2
            _retries=$((_retries - 1))
            sleep $_delay
        fi        
        result=`./redfishcmd $NAME ${_path} -X${_method} $_dataval`
        ret=$?
    done

    if [ "$ret" != "0" ]; then
        echo -e "${RED}$NAME - FATAL Error code ${BOLD}$ret${NC}${RED} while $_label $_path - Aborting!${NC}" 1>&2
        exit $ret
    fi
    if [ ! -z "$_jqfilter" ]; then
        result=$(echo "$result" | jq -r "$_jqfilter")
    fi
    echo $result
}

_pingretries=2
_pingdelay=5
ping -W 3 -c 1 ${IP} 2>/dev/null 1>/dev/null
ret=$?
while [ "$ret" != "0" ]; do
    if [ "$_pingretries" -ge 0 ]; then
        _pingretries=$((_pingretries - 1))
        sleep $_pingdelay
    else
        echo "${NAME},"
        echo -e "${RED}$NAME - FATAL Error while pinging ${NAME} / ${IP} - System is offline. Aborting!${NC}" 1>&2
        exit $ret
    fi        
    ping -W 3 -c 1 ${IP} 2>/dev/null 1>/dev/null
    ret=$?
done

if [ "$ret" == 0 ]; then
    # FW_BIOS=$(./redfishcmd $NAME /redfish/v1/UpdateService/FirmwareInventory/BIOS |jq -r ".Version")
    FW_BIOS=$(redfish_with_retry "Loading BIOS Version" /redfish/v1/UpdateService/FirmwareInventory/BIOS GET "" ".Version")
    FW_BMC=$(redfish_with_retry "Loading BMC Version" /redfish/v1/Managers/1/ GET "" ".FirmwareVersion")
    FW_GPU=$(redfish_with_retry "Loading GPU Version" /redfish/v1/UpdateService/FirmwareInventory/bundle_active GET "" '.Oem.AMD.VersionID.ComponentDetails')
    SMT_CONTROL=$(redfish_with_retry "Loading BIOS SMT Setting" /redfish/v1/Systems/1/Bios GET "" ".Attributes.SMTControl")
    NUMA_ZONES=$(redfish_with_retry "Loading NUMA ZONES" /redfish/v1/Systems/1/Bios GET "" ".Attributes.NUMANodesPerSocket")

    TW_BIOS_SETTINGS="false"
    if [ "$SMT_CONTROL" == "Disabled" ]; then
        TW_BIOS_SETTINGS="true"
    fi
    
    # FW_BMC=$(./redfishcmd $NAME /redfish/v1/Managers/1/ |jq -r ".FirmwareVersion")
    # FW_GPU=$(./redfishcmd $NAME /redfish/v1/UpdateService/FirmwareInventory/bundle_active | jq -r '.Oem.AMD.VersionID.ComponentDetails')
    # NUMA_ZONES=$(./redfishcmd $NAME /redfish/v1/Systems/1/Bios|jq -r ".Attributes.NUMANodesPerSocket")
    #NUMA_ZONES=$(ssh -o StrictHostKeyChecking=no tensorwave@$LANIP /bin/bash -c "lscpu |grep 'NUMA node('|awk '{print \$3}'")
#  set -x
    slot_data=()
    pcie_data=$(redfish_with_retry "Loading PCIe devices" '/redfish/v1/Chassis/1/PCIeDevices?\$expand=*' GET "")

    pids=()
    for s in $(seq 1 ${SLOT_COUNT}); do
        (
        slot=$(echo "$pcie_data" | jq -rc ".Members[]| select(.Slot.Location.PartLocation.ServiceLabel==\"System Slot $s\") //empty")
        # slot_data[$s]=$(echo $slot|jq -r '{Name:.Name,Manufacturer:.Manufacturer,Model:.Model,FirmwareVersion:.FirmwareVersion,Slot:.Slot.Location.PartLocation.ServiceLabel}')
        _local_slot_data='{}'
        if [ "$slot" != '{}' ]; then
# set -x
            _local_slot_data=$(echo $slot|jq -r '{Name:.Name,Manufacturer:.Manufacturer,Model:.Model,FirmwareVersion:.FirmwareVersion,Slot:.Slot.Location.PartLocation.ServiceLabel}')
            portCount=$(redfish_with_retry "Loading Slot $s ports" "/redfish/v1/Chassis/1/NetworkAdapters/$s/Ports" GET "" '.Members | length')

            if [ ${portCount} -gt 0 ]; then
                _first_port_data=$(redfish_with_retry "Loading Slot $s port 1 data" "/redfish/v1/Chassis/1/NetworkAdapters/$s/Ports/1" GET "")
                if [ -z "$_first_port_data" ]; then
                    _first_port_data='{}'
                fi
                port_data=$(echo "$_first_port_data" | jq --arg pc "$portCount" -rc '{"PortCount":$pc,"LinkStatus":.LinkStatus,"CurrentSpeedGbps":.CurrentSpeedGbps}')
                _local_slot_data=$(echo "${_local_slot_data}" | jq -r ". += $port_data")
                set +x
            fi

            pcieFunctionsLink=$(echo "$slot" | jq -r '.PCIeFunctions."@odata.id" //empty')
            if [ ! -z "$pcieFunctionsLink" ]; then
                pcie_functions=$(redfish_with_retry "Loading Slot $s PCIe functions" "$pcieFunctionsLink/1" GET "" ) #note: additional enabled ports are on /2 (or more) - we really only care about the first one
                if [ ! -z "$pcie_functions" ]; then
                    ethernetInterfaceLink=$(echo "$pcie_functions" | jq -r '.Links.EthernetInterfaces[0]."@odata.id" //empty')
                    if [ ! -z "$ethernetInterfaceLink" ]; then
                        ethernetInterface=$(redfish_with_retry "Loading Slot $s Ethernet interface information" "$ethernetInterfaceLink" GET "" )
                        if [ ! -z "$ethernetInterface" ]; then
                            eth_data=$(echo "$ethernetInterface" | jq -rc '{MACAddress:.MACAddress} //{}')
                            # slot_data[$s]=$(echo "${slot_data[$s]}" | jq -r ". += $eth_data")
                            _local_slot_data=$(echo "${_local_slot_data}" | jq -rc ". += $eth_data")
                        fi
                    fi
                else
                    # No PCIe functions found, continue
                    # continue
                    exit 1
                fi
            else
                # No PCIe functions link found, continue
                # continue
                exit 1
            fi
        else
            # No slot data found, continue
            # continue
            exit 1
        fi
        # echo "Processing slot $s: $_local_slot_data"
        _tfile=$(mktemp -p ${TMPFILE_PATH} ${TMPFILE_PREFIX}_slot_${s}_XXXXXX)
        
        # echo "Writing slot $s data to $_tfile"
        echo "$_local_slot_data" | jq -rc > "$_tfile"
        # echo "Finished processing slot $s"
        ) &
        pids+=($!)
    done

    for pid in "${pids[@]}"; do
        wait $pid || true
    done
    for s in $(seq 1 ${SLOT_COUNT}); do
        # echo "checking for ls -l ${TMPFILE_PATH}/${TMPFILE_PREFIX}_slot_${s}_*"
        _tfile=$(ls ${TMPFILE_PATH}/${TMPFILE_PREFIX}_slot_${s}_* | head -n 1)
        if [ -z "$_tfile" ]; then
            # echo -e "${RED}Error: No temporary file found for slot $s${NC}" 1>&2
            slot_data[$s]="{}"
        else
            # echo "Reading slot $s data from $_tfile"
            slot_data[$s]=$(cat "$_tfile")
            # echo "Slot $s data: ${slot_data[$s]}"
        fi
        rm -f "$_tfile"
    done

    databuf="${NAME},${FW_BIOS},${TW_BIOS_SETTINGS},${FW_BMC},${FW_GPU}"
    for s in $(seq 1 ${SLOT_COUNT}); do
        # echo "${slot_data[$s]}"
        databuf+=","
        if [ -z "${slot_data[$s]}" ]; then
            databuf+=",,,,,,"
            continue
        fi
        
        databuf+=$(echo "${slot_data[$s]}" | jq -rcj '. | [.Manufacturer,.Model,.FirmwareVersion,.MACAddress,.PortCount,.LinkStatus,.CurrentSpeedGbps]|@csv')
    done
    echo $databuf

else
    echo "${NAME},"
fi
