#!/bin/bash
# Ensure sensors and gather information for zabbix

# set zabbix sender
sensorslog="/etc/zabbix/sensorslog"
key="csg.sensors_lm_"
thisserver=<%= fqdn %>
zapi="https://zabbix.missouri.edu/zabbix/api_jsonrpc.php"
zauth="91240fb8d61542580a3d2e7b00920b3c"
zs=<%= scope.lookupvar('zabbix-agent::which_zsender') %>
zserver=<%= scope.lookupvar('zabbix-agent::zabbix_server') %>
zport=10051


# make sure lm_sensors is installed, otherwise we can't do anything
#SENSORS=`which sensors`
#if [ $? -ne 0 ]
#then    $zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_lm_status -o NotInstalled
#        exit 0
#fi
MODPROBE="/sbin/modprobe"
SENSORS="/usr/bin/sensors"
SENSORS_DETECT="/usr/sbin/sensors-detect"

# if lm_sensors does not detect any sensors, run initial configuration
/etc/init.d/lm_sensors status
if [ $? -eq 0 ]
then	SENSORS=( `$SENSORS -u 2>/dev/null | tr '\n' ';' 2>/dev/null` )
else	echo "Running initial config" >> $sensorslog
	# detect the kernel modules we need (this is run twice)
	(while :; do echo ""; done ) | $SENSORS_DETECT
	sleep 1
	# testing on cap1-ge02-hsc has shown that a second run either makes more sensors discoverable and/or more modules accessible
	(while :; do echo ""; done ) | $SENSORS_DETECT
	
	# now see if any modules are loaded
	module_list=`grep -i MODULE_[0-9]= /etc/sysconfig/lm_sensors | wc -l`

	if [ "$module_list" -eq 0 ]
	then
		$zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_lm_status -o NoKernelModulesAvailable 1>/dev/null 2>/dev/null
		exit 0
	else	for i in `grep -i MODULE_ /etc/sysconfig/lm_sensors | grep -v "#" | awk -F'=' '{print $2}'`; do $MODPROBE $i; done
		SENSORS=( `$SENSORS -u 2>/dev/null | tr '\n' ';' 2>/dev/null` )
	fi
fi


# inform zabbix that the daemon is active
$zs -vv -z $zserver -p $zport -s $thisserver -k $key"daemon_status" -o Active 2>/dev/null


## get host id ##
hostdata=\{\"jsonrpc\":\"2.0\",\"method\":\"host.get\",\"params\":\{\"output\":\"extend\",\"filter\":\{\"host\":\[\"$thisserver\"\]\}\},\"auth\":\"$zauth\",\"id\":\"2\"\}

# curl get host id to zabbix
echo curl -i -X POST -H 'Content-Type:application/json' -d $hostdata $zapi >> $sensorslog
hostid=$( curl -i -X POST -H 'Content-Type:application/json' -d $hostdata $zapi | tr ',' '\n' | grep \"hostid | tr '\"' '\n' | grep [0-9] )
####


## get sensors app id ##
getappid=\{\"jsonrpc\":\"2.0\",\"method\":\"application.get\",\"params\":\{\"search\":\{\"name\":\"Sensors\"\},\"hostids\":\"$hostid\",\"output\":\"extend\",\"expandData\":1,\"limit\":1\},\"auth\":\"$zauth\",\"id\":2\}

# curl get sensors app id to zabbix
#echo curl -i -X POST -H 'Content-Type:application/json' -d $getappid $zapi #>> $sensorslog
appid_exists=$( curl -i -X POST -H 'Content-Type:application/json' -d $getappid $zapi | grep $thisserver | tr ',' '\n' | grep \"applicationid | tr '\"' '\n' | grep [0-9] )
####



# get values for sensors
cores=`echo "${SENSORS[@]}" | tr ';' '\n' | grep Core\ | wc -l`
ins=`echo "${SENSORS[@]}" | tr ';' '\n' | grep in[0-9]_input | wc -l`
fans=`echo "${SENSORS[@]}" | tr ';' '\n' | grep fan[0-9]_input | wc -l`


#if application does not exist, we need to create it along with all items
if [ -z $appid_exists ]
then
        # create Sensors application for host's classification
        appdata=\{\"jsonrpc\":\"2.0\",\"method\":\"application.create\",\"params\":\[\{\"name\":\"Sensors\",\"hostid\":\"$hostid\"\}\],\"auth\":\"$zauth\",\"id\":2\}
        echo curl -i -X POST -H 'Content-Type:application/json' -d $appdata $zapi >> $sensorslog
        appid=$( curl -i -X POST -H 'Content-Type:application/json' -d $appdata $zapi | tr ',' '\n' | grep \"applicationid | tr '\"' '\n' | grep [0-9] )

        # create csg.sensors_ipmi_daemon_status item 
        itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"csg.sensors_lm_status\",\"key_\":\"csg.sensors_lm_status\",\"type\":\"7\",\"value_type\":\"4\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\}
        echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi >> $sensorslog
        curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi

	# create "cores" items
	for (( i=0; i<=$cores; i++ )); do itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"$key"temp_core"$i\",\"key_\":\"$key"temp_core"$i\",\"type\":\"7\",\"value_type\":\"4\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\} && echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi >> $sensorslog && echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi; done

	# create "voltage" items
	for (( i=0; i<=$ins; i++ )); do itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"$key"volts_in"$i\",\"key_\":\"$key"volts_in"$i\",\"type\":\"7\",\"value_type\":\"4\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\} && echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi >> $sensorslog && curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi; done

	# create "fan" items
	for (( i=0; i<=$fans; i++ )); do itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"$key"rpm_fan"$i\",\"key_\":\"$key"rpm_fan"$i\",\"type\":\"7\",\"value_type\":\"4\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\} && echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi >> $sensorslog && curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi; done

	
fi



# core temp
cores=$(( $cores - 1 )) # conventional cpu notation begins at zero
for (( i=0; i<=$cores; i++ )); do $zs -vv -z $zserver -p $zport -s $thisserver -k $key"temp_core"$i -o `echo "${SENSORS[@]}" | tr ';' '\n' | grep -A 1 -i "core\ $i" | tail -1 | awk '{print $2}' | cut -d. -f1` 2>/dev/null; done


# ins voltage
ins=$(( $ins - 1 )) # begins at zero
for (( i=0; i<=$ins; i++ )); do $zs -vv -z $zserver -p $zport -s $thisserver -k $key"volts_in"$i -o `echo "${SENSORS[@]}" | tr ';' '\n' | grep -i in"$i"_input\: | awk '{print $2}' | cut -d. -f1` 2>/dev/null; done


# fan RPM
for (( i=1; i<=$fans; i++ )); do if (( "`echo "${SENSORS[@]}" | tr ';' '\n' | grep -i fan"$i"_alarm | grep 0\.0 | wc -l`"=="1" )); then $zs -vv -z $zserver -p $zport -s $thisserver -k $key"rpm_fan"$i -o `echo "${SENSORS[@]}" | tr ';' '\n' | grep -i fan"$i"_input\: | awk '{print $2}' | cut -d. -f1` 2>/dev/null; fi ; done
