#!/bin/bash
NAME=${1}
DATASTORE="ipmi.json"

TEST_QUERY=$(./redfishcmd $NAME /redfish/v1/Systems/1/Memory/12/MemoryMetrics)

echo -e "${NAME} -- Redfish Result: \\n${TEST_QUERY}"
exit



#/redfish/v1/Chassis/1/Sensors/LiquidLeak
#/redfish/v1/Chassis/1/LeakDetectors
#/redfish/v1/Chassis/1/LeakDetectors/CPU1_Coldplate
#
#
