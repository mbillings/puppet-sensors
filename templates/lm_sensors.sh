#!/bin/bash
# Ensure sensors and gather information for zabbix

# set user-modifiable variables
key="csg.sensors_lm_"
sensorslog="/etc/zabbix/sensorslog"
thisserver=<%= fqdn %>
zapi="https://zabbix.missouri.edu/zabbix/api_jsonrpc.php"
zauth="91240fb8d61542580a3d2e7b00920b3c"
zs=<%= scope.lookupvar('zabbix-agent::which_zsender') %>
zserver=<%= scope.lookupvar('zabbix-agent::zabbix_server') %>
zport=10051

# set OS variables
MODPROBE="/sbin/modprobe"
SENSORS="/usr/bin/sensors"
SENSORS_DETECT="/usr/sbin/sensors-detect"


## if lm_sensors does not detect any sensor modules, run initial configuration ##
/etc/init.d/lm_sensors status
if [ $? -ne 0 ]
then	echo "Running initial config" >> $sensorslog
	# detect the kernel modules we need (this is run twice)
	(while :; do echo ""; done ) | $SENSORS_DETECT
	sleep 1
	# testing on cap1-ge02-hsc has shown that, despite logical sense, a second run either: 
	# 1. makes more sensors discoverable, and/or 
	# 2. makes more modules accessible
	(while :; do echo ""; done ) | $SENSORS_DETECT
	
	# now see if any modules are loaded
	module_list=`grep -i MODULE_[0-9]= /etc/sysconfig/lm_sensors | wc -l`

	if [ "$module_list" -eq 0 ]
	then
		$zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_lm_status -o NoKernelModulesAvailable 1>/dev/null 2>/dev/null
		exit 0
	else	for i in `grep -i MODULE_ /etc/sysconfig/lm_sensors | grep -v "#" | awk -F'=' '{print $2}'`; do $MODPROBE $i; done
	fi
fi
##


## Gather sensors information in one variable. Why not an array? Because, surprisingly, at this time of writing (6 August 2012), this is faster :p Less memory lookups, I guess? ##
SENSORS=( `$SENSORS 2>/dev/null | grep "(" | grep -iv ALARM | tr '\n' ';'` )
##

## If no info returned, we have a problem <- unnecessary? ##
#if [ $( echo $SENSORS | wc -l ) -eq 0 ]
#then $zs -vv -z $zserver -p $zport -s $thisserver -k $key"lm_status" -o NoInformationAvailable 2>/dev/null
#fi
#

## Inform zabbix that the daemon is active ##
$zs -vv -z $zserver -p $zport -s $thisserver -k $key"lm_status" -o Active 2>/dev/null
##


## Get the host id for this host ##
hostdata=\{\"jsonrpc\":\"2.0\",\"method\":\"host.get\",\"params\":\{\"output\":\"extend\",\"filter\":\{\"host\":\[\"$thisserver\"\]\}\},\"auth\":\"$zauth\",\"id\":\"2\"\}

echo curl -i -X POST -H 'Content-Type:application/json' -d $hostdata $zapi >> $sensorslog
hostid=$( curl -i -X POST -H 'Content-Type:application/json' -d $hostdata $zapi | tr ',' '\n' | grep \"hostid | tr '\"' '\n' | grep [0-9] )
##


## Get the app id for this host's sensors application ##
getappid=\{\"jsonrpc\":\"2.0\",\"method\":\"application.get\",\"params\":\{\"search\":\{\"name\":\"Sensors\"\},\"hostids\":\"$hostid\",\"output\":\"extend\",\"expandData\":1,\"limit\":1\},\"auth\":\"$zauth\",\"id\":2\}
##


## Get the zabbix application id for this host ##
echo curl -i -X POST -H 'Content-Type:application/json' -d $getappid $zapi >> $sensorslog
appid_exists=$( curl -i -X POST -H 'Content-Type:application/json' -d $getappid $zapi | grep $thisserver | tr ',' '\n' | grep \"applicationid | tr '\"' '\n' | grep [0-9] )
##


## number of data items ##
totalitems=$( echo "${SENSORS[@]}" | tr ';' '\n' | wc -l )
##


##if application does not exist, we need to create it along with all items ##
if [ -z $appid_exists ]
then
        # create sensors application for host's classification
        appdata=\{\"jsonrpc\":\"2.0\",\"method\":\"application.create\",\"params\":\[\{\"name\":\"Sensors\",\"hostid\":\"$hostid\"\}\],\"auth\":\"$zauth\",\"id\":2\}
        echo curl -i -X POST -H 'Content-Type:application/json' -d $appdata $zapi >> $sensorslog
        appid=$( curl -i -X POST -H 'Content-Type:application/json' -d $appdata $zapi | tr ',' '\n' | grep \"applicationid | tr '\"' '\n' | grep [0-9] )

        # create csg.sensors_ipmi_daemon_status item 
        itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"csg.sensors_lm_status\",\"key_\":\"csg.sensors_lm_status\",\"type\":\"7\",\"value_type\":\"4\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\}
        echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi >> $sensorslog
        curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi


	# create items for all data points
	for (( i=1; i<=$totalitems; i++ )); do itemname=$( echo "${SENSORS[@]}" | tr ';' '\n' | awk -F\: '{print $1}' | head -"$i" | tail -1 | sed s/\://g | sed s/\ //g ) && itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"$key"$itemname"\",\"key_\":\"$key"$itemname"\",\"type\":\"7\",\"value_type\":\"0\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\} && echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi >> $sensorslog && curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi; done

fi
##


## send gathered sensor data to zabbix ##
for (( i=1; i<=$totalitems; i++ )); do itemline=$( echo "${SENSORS[@]}" | tr ';' '\n' | head -"$i" | tail -1 ) && itemname=$( echo $itemline | awk -F\: '{print $1}' | sed s/\://g | sed s/\ //g ) && itemvalue=$( echo $itemline | awk -F\: '{print $2}' | awk -F\( '{print $1}' | awk '{print $1}' | sed s/\+//g | sed s/\°//g ) && $zs -vv -z $zserver -p $zport -s $thisserver -k $key"$itemname" -o $itemvalue; done
##
