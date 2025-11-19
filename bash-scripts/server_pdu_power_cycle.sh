#!/bin/bash
# Get a server
SERVER=${1}
DATASTORE=""
IP=`jq -r ".[]| select(.name==\"$SERVER\")|.ip" $DATASTORE`;

ping -W 4 -c 4 ${IP} 2>/dev/null 1>/dev/null
if [ "$?" != 0 ]; then
  echo "server ${SERVER} is not responding on ${IP}" 1>&2
  exit 1
fi
## Server Up Check ##


RACK=`jq -r ".[]| select(.name==\"$SERVER\")|.rack" $DATASTORE`
RU=`jq -r ".[]| select(.name==\"$SERVER\")|.ru" $DATASTORE`

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# echo -e "Server: ${SERVER} \\nIP: ${IP}\\nRack: ${RACK}\\nRU: ${RU}"

## Position Setting ##
if [[ "$RU" == 33 ]] 
then
  POSITION=8
  PDU_1="tus1-pdu-${RACK}-L1"
  PDU_2="tus1-pdu-${RACK}-L2"
  PDU_3="tus1-pdu-${RACK}-R1"
  PDU_4="tus1-pdu-${RACK}-R2"
elif [[ "$RU" == 29 ]]
then
  POSITION=7
  PDU_1="tus1-pdu-${RACK}-L3"
  PDU_2="tus1-pdu-${RACK}-L4"
  PDU_3="tus1-pdu-${RACK}-R3"
  PDU_4="tus1-pdu-${RACK}-R4"
elif [[ "$RU" == 25 ]]
then
  POSITION=6
  PDU_1="tus1-pdu-${RACK}-L1"
  PDU_2="tus1-pdu-${RACK}-L2"
  PDU_3="tus1-pdu-${RACK}-R1"
  PDU_4="tus1-pdu-${RACK}-R2"
elif [[ "$RU" == 21 ]]
then
  POSITION=5
  PDU_1="tus1-pdu-${RACK}-L3"
  PDU_2="tus1-pdu-${RACK}-L4"
  PDU_3="tus1-pdu-${RACK}-R3"
  PDU_4="tus1-pdu-${RACK}-R4"
elif [[ "$RU" == 17 ]]
then
  POSITION=4
  PDU_1="tus1-pdu-${RACK}-L1"
  PDU_2="tus1-pdu-${RACK}-L2"
  PDU_3="tus1-pdu-${RACK}-R1"
  PDU_4="tus1-pdu-${RACK}-R2"
elif [[ "$RU" == 13 ]]
then
  POSITION=3
  PDU_1="tus1-pdu-${RACK}-L3"
  PDU_2="tus1-pdu-${RACK}-L4"
  PDU_3="tus1-pdu-${RACK}-R3"
  PDU_4="tus1-pdu-${RACK}-R4"
elif [[ "$RU" == 9 ]]
then
  POSITION=2
  PDU_1="tus1-pdu-${RACK}-L1"
  PDU_2="tus1-pdu-${RACK}-L2"
  PDU_3="tus1-pdu-${RACK}-R1"
  PDU_4="tus1-pdu-${RACK}-R2"
elif [[ "$RU" == 5 ]]
then
  POSITION=1
  PDU_1="tus1-pdu-${RACK}-L3"
  PDU_2="tus1-pdu-${RACK}-L4"
  PDU_3="tus1-pdu-${RACK}-R3"
  PDU_4="tus1-pdu-${RACK}-R4"
else
  echo "${SERVER} rack position not found"
  exit 1
fi
## Position Setting ##
#echo -e "Position: ${POSITION}"

## PDU Check ##
PDU_DATASTORE="pdu_list.json"
IP_PDU_1=`jq -r ".[]| select(.name==\"$PDU_1\")|.ip" $PDU_DATASTORE`;
IP_PDU_2=`jq -r ".[]| select(.name==\"$PDU_2\")|.ip" $PDU_DATASTORE`;
IP_PDU_3=`jq -r ".[]| select(.name==\"$PDU_3\")|.ip" $PDU_DATASTORE`;
IP_PDU_4=`jq -r ".[]| select(.name==\"$PDU_4\")|.ip" $PDU_DATASTORE`;
## PDU Check ##


## Server Up check ##
for VAR_NAME in IP_PDU_1 IP_PDU_2 IP_PDU_3 IP_PDU_4; do
    PDU_IP=${!VAR_NAME}
    if [ -z "$PDU_IP" ] ; 
    then
      echo "Unable to determine IP for $SERVER" 1>&2;
	  exit 1
    fi
    ping -W 4 -c 1 ${PDU_IP} 2>/dev/null 1>/dev/null
    if [ "$?" != 0 ]; then
      echo "server ${SERVER} is not responding on ${PDU_IP}" 1>&2
      exit 1
    fi
done


declare -i PDU_POWER_1_1 PDU_POWER_1_2 PDU_POWER_2_1 PDU_POWER_2_2 PDU_POWER_3_1 PDU_POWER_3_2 PDU_POWER_4_1 PDU_POWER_4_2
declare -i PSU_POWER_0 PSU_POWER_1 PSU_POWER_2 PSU_POWER_3

echo -e "Executing ${SERVER}'s PDU Outlet Validation.."


PDU_USER="USER"
PDU_PW="PASSWORD"
POWER_FILE="cycle.log"
PSU_1_TEST=0
PSU_2_TEST=0
PSU_3_TEST=0
PSU_4_TEST=0
echo "######################### -- Testing Server: ${SERVER} -- #########################" >> $POWER_FILE
## Power Retrieval ## 
if [[ "$RU" == 33 ]] 
then
  PDU_OUTLET1=38
  PDU_OUTLET2=40
  ## ------------------ PSU: 1 ------------------ ##
  echo -e "\\t\\t\\tPSU #1"
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET38 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET40 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle on PSU 1 failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET38 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET40 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi
  ## ------------------ PSU: 1 ------------------ ##
  ## ------------------ PSU: 2 ------------------ ##
  echo -e "\\t\\t\\tPSU #2"
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET38 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET40 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET38 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET40 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi
  ## ------------------ PSU: 2 ------------------ ##
  ## ------------------ PSU: 3 ------------------ ##
  echo -e "\\t\\t\\tPSU #3"
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET38 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET40 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET38 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET40 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi
  ## ------------------ PSU: 3 ------------------ ##
  ## ------------------ PSU: 4 ------------------ ##
  echo -e "\\t\\t\\tPSU #4"
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET38 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET40 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET38 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET40 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi
  if [[ $PSU_1_TEST -eq 0 && $PSU_2_TEST -eq 0 && $PSU_3_TEST -eq 0 && $PSU_4_TEST -eq 0 ]]; then
    echo -e "[SUCCESS] ${SERVER} -- All PSUs passed" >> $POWER_FILE
  fi
  ## ------------------ PSU: 4 ------------------ ##
elif [[ "$RU" == 29 ]]
then
  PDU_OUTLET1=32
  PDU_OUTLET2=34
  ## ------------------ PSU: 1 ------------------ ##
  echo -e "\\t\\t\\tPSU #1"
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET32 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET34 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle on PSU 1 failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET32 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET34 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi
  ## ------------------ PSU: 1 ------------------ ##
  ## ------------------ PSU: 2 ------------------ ##
  echo -e "\\t\\t\\tPSU #2"
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET32 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET34 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET32 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET34 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi
  ## ------------------ PSU: 2 ------------------ ##
  ## ------------------ PSU: 3 ------------------ ##
  echo -e "\\t\\t\\tPSU #3"
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET32 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET34 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET32 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET34 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi
  ## ------------------ PSU: 3 ------------------ ##
  ## ------------------ PSU: 4 ------------------ ##
  echo -e "\\t\\t\\tPSU #4"
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET32 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET34 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET32 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET34 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi
  if [[ $PSU_1_TEST -eq 0 && $PSU_2_TEST -eq 0 && $PSU_3_TEST -eq 0 && $PSU_4_TEST -eq 0 ]]; then
    echo -e "[SUCCESS] ${SERVER} -- All PSUs passed" >> $POWER_FILE
  fi
  ## ------------------ PSU: 4 ------------------ ##
elif [[ "$RU" == 25 ]]
then
  PDU_OUTLET1=26
  PDU_OUTLET2=28
  ## ------------------ PSU: 1 ------------------ ##
  echo -e "\\t\\t\\tPSU #1"
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET26 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET28 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle on PSU 1 failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET26 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET28 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi
  ## ------------------ PSU: 1 ------------------ ##
  ## ------------------ PSU: 2 ------------------ ##
  echo -e "\\t\\t\\tPSU #2"
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET26 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET28 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET26 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET28 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi
  ## ------------------ PSU: 2 ------------------ ##
  ## ------------------ PSU: 3 ------------------ ##
  echo -e "\\t\\t\\tPSU #3"
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET26 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET28 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET26 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET28 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi
  ## ------------------ PSU: 3 ------------------ ##
  ## ------------------ PSU: 4 ------------------ ##
  echo -e "\\t\\t\\tPSU #4"
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET26 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET28 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET26 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET28 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi
  if [[ $PSU_1_TEST -eq 0 && $PSU_2_TEST -eq 0 && $PSU_3_TEST -eq 0 && $PSU_4_TEST -eq 0 ]]; then
    echo -e "[SUCCESS] ${SERVER} -- All PSUs passed" >> $POWER_FILE
  fi
  ## ------------------ PSU: 4 ------------------ ##
elif [[ "$RU" == 21 ]]
then
  PDU_OUTLET1=22
  PDU_OUTLET2=24
  ## ------------------ PSU: 1 ------------------ ##
  echo -e "\\t\\t\\tPSU #1"
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle on PSU 1 failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi
  ## ------------------ PSU: 1 ------------------ ##
  ## ------------------ PSU: 2 ------------------ ##
  echo -e "\\t\\t\\tPSU #2"
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi
  ## ------------------ PSU: 2 ------------------ ##
  ## ------------------ PSU: 3 ------------------ ##
  echo -e "\\t\\t\\tPSU #3"
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi
  ## ------------------ PSU: 3 ------------------ ##
  ## ------------------ PSU: 4 ------------------ ##
  echo -e "\\t\\t\\tPSU #4"
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi
  if [[ $PSU_1_TEST -eq 0 && $PSU_2_TEST -eq 0 && $PSU_3_TEST -eq 0 && $PSU_4_TEST -eq 0 ]]; then
    echo -e "[SUCCESS] ${SERVER} -- All PSUs passed" >> $POWER_FILE
  fi
  ## ------------------ PSU: 4 ------------------ ##
elif [[ "$RU" == 17 ]]
then
  PDU_OUTLET1=18
  PDU_OUTLET2=20
  PDU_OUTLET3=14
  PDU_OUTLET4=16
  ## ------------------ PSU: 1 ------------------ ##
  echo -e "\\t\\t\\tPSU #1"
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle on PSU 1 failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi
  ## ------------------ PSU: 1 ------------------ ##
  ## ------------------ PSU: 2 ------------------ ##
  echo -e "\\t\\t\\tPSU #2"
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET3
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET4
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET3 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET4 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET3
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET4
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET3
  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET4

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET3 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET4 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi
  ## ------------------ PSU: 2 ------------------ ##
  ## ------------------ PSU: 3 ------------------ ##
  echo -e "\\t\\t\\tPSU #3"
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi
  ## ------------------ PSU: 3 ------------------ ##
  ## ------------------ PSU: 4 ------------------ ##
  echo -e "\\t\\t\\tPSU #4"
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET3
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET4
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET3 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET4 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET3
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET4
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET3
  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET4

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET3 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET4 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi
  if [[ $PSU_1_TEST -eq 0 && $PSU_2_TEST -eq 0 && $PSU_3_TEST -eq 0 && $PSU_4_TEST -eq 0 ]]; then
    echo -e "[SUCCESS] ${SERVER} -- All PSUs passed" >> $POWER_FILE
  fi
  ## ------------------ PSU: 4 ------------------ ##
elif [[ "$RU" == 13 ]]
then
  PDU_OUTLET1=14
  PDU_OUTLET2=16
  ## ------------------ PSU: 1 ------------------ ##
  echo -e "\\t\\t\\tPSU #1"
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle on PSU 1 failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi
  ## ------------------ PSU: 1 ------------------ ##
  ## ------------------ PSU: 2 ------------------ ##
  echo -e "\\t\\t\\tPSU #2"
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi
  ## ------------------ PSU: 2 ------------------ ##
  ## ------------------ PSU: 3 ------------------ ##
  echo -e "\\t\\t\\tPSU #3"
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi
  ## ------------------ PSU: 3 ------------------ ##
  ## ------------------ PSU: 4 ------------------ ##
  echo -e "\\t\\t\\tPSU #4"
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi
  if [[ $PSU_1_TEST -eq 0 && $PSU_2_TEST -eq 0 && $PSU_3_TEST -eq 0 && $PSU_4_TEST -eq 0 ]]; then
    echo -e "[SUCCESS] ${SERVER} -- All PSUs passed" >> $POWER_FILE
  fi
  ## ------------------ PSU: 4 ------------------ ##
elif [[ "$RU" == 9 ]]
then
  PDU_OUTLET1=10
  PDU_OUTLET2=12
  PDU_OUTLET3=6
  PDU_OUTLET4=8
  ## ------------------ PSU: 1 ------------------ ##
  echo -e "\\t\\t\\tPSU #1"
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle on PSU 1 failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi
  ## ------------------ PSU: 1 ------------------ ##
  ## ------------------ PSU: 2 ------------------ ##
  echo -e "\\t\\t\\tPSU #2"
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET3
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET4
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET3 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET4 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET3
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET4
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET3
  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET4

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET3 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET4 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi
  ## ------------------ PSU: 2 ------------------ ##
  ## ------------------ PSU: 3 ------------------ ##
  echo -e "\\t\\t\\tPSU #3"
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi
  ## ------------------ PSU: 3 ------------------ ##
  ## ------------------ PSU: 4 ------------------ ##
  echo -e "\\t\\t\\tPSU #4"
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi
  if [[ $PSU_1_TEST -eq 0 && $PSU_2_TEST -eq 0 && $PSU_3_TEST -eq 0 && $PSU_4_TEST -eq 0 ]]; then
    echo -e "[SUCCESS] ${SERVER} -- All PSUs passed" >> $POWER_FILE
  fi
  ## ------------------ PSU: 4 ------------------ ##
elif [[ "$RU" == 5 ]]
then
  PDU_OUTLET1=6
  PDU_OUTLET2=8
  ## ------------------ PSU: 1 ------------------ ##
  echo -e "\\t\\t\\tPSU #1"
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle on PSU 1 failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_1 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[0].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_1/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#1 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU1 -- failure" >> $POWER_FILE
    PSU_1_TEST=1
  fi
  ## ------------------ PSU: 1 ------------------ ##
  ## ------------------ PSU: 2 ------------------ ##
  echo -e "\\t\\t\\tPSU #2"
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_2 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[1].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_2/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#2 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU2 -- failure" >> $POWER_FILE
    PSU_2_TEST=1
  fi
  ## ------------------ PSU: 2 ------------------ ##
  ## ------------------ PSU: 3 ------------------ ##
  echo -e "\\t\\t\\tPSU #3"
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_3 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[2].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_3/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#3 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU3 -- failure" >> $POWER_FILE
    PSU_3_TEST=1
  fi
  ## ------------------ PSU: 3 ------------------ ##
  ## ------------------ PSU: 4 ------------------ ##
  echo -e "\\t\\t\\tPSU #4"
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
  ./outlet_off.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2
  
  sleep 3

  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -gt 10 ]]; then
    echo -e "Power cycle failed, turning back on outlets"
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
    ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi 

  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET1
  ./outlet_on.exp $PDU_USER $IP_PDU_4 $PDU_PW $PDU_OUTLET2

  sleep 3
  
  PDU_POWER___1=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET1 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  PSU_POWER_0=$(./redfishcmd $SERVER /redfish/v1/Chassis/1/Power | jq -r '.PowerSupplies[3].PowerInputWatts')
  PDU_POWER___2=$(curl -sk --user USER:PASSWORD https://$IP_PDU_4/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET$PDU_OUTLET2 | jq -r '[.PowerWatts.Reading] | @tsv' | sort -V | column -t)
  echo -e "PSU#4 Outlet 1: ${PDU_POWER___1} | Outlet 2: ${PDU_POWER___2} | PSU: ${PSU_POWER_0}" >> $POWER_FILE
  if [[ "$PSU_POWER_0" -lt 10 ]]; then
    echo -e "Power cycle failed, exiting..."
    echo -e "[ERROR] ${SERVER} -- PSU4 -- failure" >> $POWER_FILE
    PSU_4_TEST=1    
  fi
  if [[ $PSU_1_TEST -eq 0 && $PSU_2_TEST -eq 0 && $PSU_3_TEST -eq 0 && $PSU_4_TEST -eq 0 ]]; then
    echo -e "[SUCCESS] ${SERVER} -- All PSUs passed" >> $POWER_FILE
  fi
  ## ------------------ PSU: 4 ------------------ ##
else
  echo "${SERVER} rack position not found"
  exit 1
fi
if [[ "$PDU_POWER_1_1" == 0 || "$PDU_POWER_1_2" == 0 || "$PDU_POWER_2_1" == 0 || "$PDU_POWER_2_2" == 0 || "$PDU_POWER_3_1" == 0 || "$PDU_POWER_3_2" == 0 || "$PDU_POWER_4_1" == 0 || "$PDU_POWER_4_2" == 0 ]]; then
    echo "wrong outlet"
    #exit 0
    :
fi