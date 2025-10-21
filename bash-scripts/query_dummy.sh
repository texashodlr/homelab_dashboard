#!/bin/bash
NAME=${1}
DATASTORE="ipmi.json"

echo -e "Server ${NAME}"

declare -a SNs=() Healths=()

for i in $(seq 1 4); do
    read -r sn health < <(./redfishcmd "$NAME" "/redfish/v1/Chassis/1/PCIeDevices/NVMeSSD$i" | jq -r '[.SerialNumber, .Status.Health] | @tsv')
    SNs[i]=$sn
    Healths[i]=$health
    

    #echo -e "Drive $i:"
    #echo -e "  Serial: ${SNs[$i]}"
    #echo -e "  Health: ${Healths[$i]}"
    #echo -e "  Serial: ${!("NVMeSSD${i}_SN")}"
    #echo -e "  Health: ${!("NVMeSSD${i}_Health")}"
done
echo -e "Server:${NAME}, \\nSSD1-SN: ${SNs[1]} , SSD1-Health: ${Healths[1]}, \\nSSD1-SN: ${SNs[2]} , SSD1-Health: ${Healths[2]}, \\nSSD1-SN: ${SNs[3]} , SSD1-Health: ${Healths[3]}, \\nSSD1-SN: ${SNs[4]} , SSD1-Health: ${Healths[4]}" 
exit

#echo -e "${NAME} -- Status \\n${TEST_QUERY}"
# TEST_QUERY_2=$(./redfishcmd $NAME /redfish/v1/Chassis/1/PCIeDevices/NVMeSSD4/PCIeFunctions/1)
# TEST_QUERY=$(./redfishcmd $NAME /redfish/v1/Chassis/1/PCIeDevices/NVMeSSD4 | )
# TEST_QUERY=$(./redfishcmd $NAME /redfish/v1/Chassis/1/PCIeDevices/NVMeSSD4 | jq -r ".SerialNumber")
# TEST_QUERY=$(./redfishcmd $NAME /redfish/v1/Chassis/1/PCIeDevices)
# #FW_BMC=$(./redfishcmd $NAME /redfish/v1/Managers/1/ |jq -r ".FirmwareVersion")


# for i in $(seq 1 4); do
#    TEST_QUERY=$(./redfishcmd $NAME /redfish/v1/Chassis/1/PCIeDevices/NVMeSSD$i | jq -r ".SerialNumber")
#    if [[ "$TEST_QUERY" == *"UNKNOWN"* ]]; then
#        echo -e "${NAME} --  NVMeSSD${i} Failed --> Status ${TEST_QUERY}"
#    fi
#done
# output_csv
# name, ssd1 sn, ssd1 health, ssd2 sn, ssd2 health, ssd3 sn, ssd3 health, ssd4 sn, ssd4 health,