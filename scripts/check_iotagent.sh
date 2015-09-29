#!/bin/bash
# sanity_check_iotagent.sh
# Sanity check for iota agent installation


# Copyright 2015 Telefonica Investigación y Desarrollo, S.A.U
#
# This file is part of iotagent project.
#
# iotagent is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# iotagent is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with iotagent. If not, see http://www.gnu.org/licenses/.
#
# For those usages not covered by the GNU Affero General Public License
# please contact with iot_support at tid dot es

echo "sanity check for iot agent"

declare -i number_errors=0
start_time=`date +%s`

function assert_code()
{
echo $res
res_code=` echo $res | grep -c "#code:$1"`
if [ $res_code -eq 1 ]
then
echo " OKAY"
else
echo  " ERROR: " $2
((number_errors++))
delete_all_data
exit -1
fi
}

function assert_contains()
{
if [[ "$res" =~ .*"$1".* ]]
then
echo " OKAY"
else
echo  " ERROR: " $2
((number_errors++))
delete_all_data
exit -1
fi

}

function write_help()
{
    echo "sanity check for iota agent installation"
    echo "usage:    sanity_check_manger.sh [-a/--iotagent IOTA_AGENT_URI] [-c/--contextbroker CONTEXT_BROKER_URI] [-v/--verbose LEVEL] "
    echo "example:  sanity_check_manger.sh --iotagent 127:0.0.1:8080 --contextbroker 127.0.0.1:1026 -verbose 0"
    echo "other option: you can use environment variables  iotagent (export HOST_IOT=127.0.0.1:8080)"
    echo "                                                 contextbroker (export HOST_CB=127.0.0.1:1026)"
}

function delete_all_data()
{
# delete old data
res=$(curl -X DELETE "http://$HOST_IOT/iot/services?resource=/iot/d&device=true" \
-i -s -w "#code:%{http_code}#" \
-H "Content-Type: application/json" \
-H "Fiware-Service: $SERVICE_TEST" \
-H "Fiware-ServicePath: $SERVICE_PATH_TEST")

}

# check parameters
if [ "$1" == "-h" ] || [ "$1" == "--help" ] ; then
    write_help
    exit -1
elif [ "$1" == "-a" ] || [  "$1" == "--iotagent" ] ; then
    export HOST_IOT=$2
elif [ "$1" == "-c" ] || [  "$1" == "--contextbroker" ] ; then
    export HOST_CB=$2
fi

if [ "$3" == "-h" ] || [ "$3" == "--help" ] ; then
    write_help
    exit -1
elif [ "$3" == "-a" ] || [  "$3" == "--iotgent" ] ; then
    export HOST_IOT='$4/iot'
elif [ "$3" == "-c" ] || [  "$3" == "--contextbroker" ] ; then
    export HOST_CB=$4
fi

if test -z "$HOST_MAN" ; then
   export HOST_IOT=127.0.0.1:8080
fi

if test -z "$HOST_CB" ; then
   export HOST_CB=127.0.0.1:1026
fi

if test -z "$SERVICE_TEST" ; then
   export SERVICE_TEST=srvcheck
fi

if test -z "$SERVICE_PATH_TEST" ; then
   export SERVICE_PATH_TEST='/spathcheck'
fi

#exits iota manager
echo "1- uri for iota agent is $HOST_IOT"
res=$( curl -X GET http://$HOST_IOT/iot/about \
-i -s -w "#code:%{http_code}#" \
-H "Content-Type: application/json" )

assert_code 200 "iota manager no respond"
assert_contains "IoTAgents" "respond is not from iotagent"

echo "2- uri for context broker is $HOST_CB"
res=$( curl -X GET http://$HOST_CB/version \
-i -s -w "#code:%{http_code}#" \
-H "Accept: application/json"  )

assert_code 200 "context broker no respond"
assert_contains "orion" "no correct respond from context broker  "

delete_all_data

echo "10- create service $SERVICE_TEST  $SERVICE_PATH_TEST  for ul"
res=$( curl -X POST http://$HOST_IOT/iot/services \
-i -s -w "#code:%{http_code}#" \
-H "Content-Type: application/json" \
-H "Fiware-Service: $SERVICE_TEST" \
-H "Fiware-ServicePath: $SERVICE_PATH_TEST" \
-d '{"services": [{ "apikey": "apikey", "token": "token", "entity_type": "thingsrv", "resource": "/iot/d" }]}' )

assert_code 201 "cannot create service"

echo "11- get service $SERVICE_TEST  $SERVICE_PATH_TEST  for ul"
res=$( curl -X GET http://$HOST_IOT/iot/services \
-i -s -w "#code:%{http_code}#" \
-H "Content-Type: application/json" \
-H "Fiware-Service: $SERVICE_TEST" \
-H "Fiware-ServicePath: $SERVICE_PATH_TEST"  )

assert_code 200 "get service fails"
assert_contains "srvcheck" "no correct respond from context broker  "

echo "20- create device for ul"
res=$( curl -X POST http://$HOST_IOT/iot/devices \
-i -s -w "#code:%{http_code}#" \
-H "Content-Type: application/json" \
-H "Fiware-Service: $SERVICE_TEST" \
-H "Fiware-ServicePath: $SERVICE_PATH_TEST" \
-d '{"devices":[{"device_id":"sensor_ul","protocol":"PDI-IoTA-UltraLight", "commands": [{"name": "PING","type": "command","value": "" }]}]}' )

assert_code 201 "cannot create device for ultralight"

echo "21- check type thingul to iotagent"
res=$( curl -X GET http://$HOST_IOT/iot/devices/sensor_ul \
-i -s -w "#code:%{http_code}#" \
-H "Content-Type: application/json" \
-H "Fiware-Service: $SERVICE_TEST" \
-H "Fiware-ServicePath: $SERVICE_PATH_TEST" )

assert_code 200 "get device fails"
assert_contains "srvcheck" "no correct respond from context broker  "

echo "22- check type thingul:sensor_ul to CB"

res=$( curl -X POST http://$HOST_CB/v1/queryContext \
-i -s -w "#code:%{http_code}#" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
-H "Fiware-Service: $SERVICE_TEST" \
-H "Fiware-ServicePath: $SERVICE_PATH_TEST" \
-d '{"entities": [{ "id": "thingsrv:sensor_ul", "type": "thingsrv", "isPattern": "false" }]}' )

assert_code 200 "get cb fails"
assert_contains "200" "no correct respond from context broker"
assert_contains "thingsrv:sensor_ul" "no correct respond from context broker"

echo "30- send command to thingul:sensor_ul to CB"

res=$( curl -X POST http://$HOST_CB/v1/updateContext \
-i -s -w "#code:%{http_code}#" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
-H "Fiware-Service: $SERVICE_TEST" \
-H "Fiware-ServicePath: $SERVICE_PATH_TEST" \
-d '{"updateAction":"UPDATE","contextElements":[{"id":"thingsrv:sensor_ul","type":"thingsrv","isPattern":"false","attributes":[{"name":"PING","type":"command","value":"22","metadatas":[{"name":"TimeInstant","type":"ISO8601","value":"2014-11-23T17:33:36.341305Z"}]}]} ]}' )
echo $res
assert_code 200 "sending command"
assert_contains "200" "no correct respond from context broker"

echo "40- check PING_status in command"

#sleep 1

res=$( curl -X POST http://$HOST_CB/v1/queryContext \
-i -s -w "#code:%{http_code}#" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
-H "Fiware-Service: $SERVICE_TEST" \
-H "Fiware-ServicePath: $SERVICE_PATH_TEST" \
-d '{"entities": [{ "id": "thingsrv:sensor_ul", "type": "thingsrv", "isPattern": "false" }]}' )
echo $res
assert_code 200 "sending command"
assert_contains "PING_status" "no correct respond from context broker"

echo "50- delete device ul20"
res=$( curl -X DELETE "http://$HOST_IOT/iot/devices/sensor_ul?resource=/iot/d" \
-i -s -w "#code:%{http_code}#" \
-H "Content-Type: application/json" \
-H "Fiware-Service: $SERVICE_TEST" \
-H "Fiware-ServicePath: $SERVICE_PATH_TEST" )
assert_code 204 "delete device"

echo "51- delete service ul20"
res=$( curl -X DELETE "http://$HOST_IOT/iot/services?resource=/iot/d&device=true" \
-i -s -w "#code:%{http_code}#" \
-H "Content-Type: application/json" \
-H "Fiware-Service: $SERVICE_TEST" \
-H "Fiware-ServicePath: $SERVICE_PATH_TEST" )
assert_code 204 "delete service"

echo sanity check is OK in $(expr `date +%s` - $start_time) seg

exit


