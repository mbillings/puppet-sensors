#!/bin/bash
#===============================================================================
#
#          FILE: <%= scope.lookupvar('sensors::lm_script') %>
# 
#         USAGE: Part of the Puppet module "sensors"
# 
#   DESCRIPTION: Initialize lm (if necessary), polls hardware info and 
#                sensors, and creates/sends items/values to reporting 
#                application
# 
#       OPTIONS: ---
#  REQUIREMENTS: --- 
#          BUGS: ---
#
#         NOTES: Part of the Puppet module "sensors", although variables can be
#                hard-coded if facter and foreman are not used
# 	             Due to curl formatting, quotation marks must be delimited so 
#                that the delimits will be read at execution time and 
#                interpreted as quotes. 
#	             For examples and formatting (may be outdated), see 
#                http://www.zabbix.com/documentation/1.8/api 
#
#  ORGANIZATION: ---
#       CREATED: ---
#      REVISION: ---
#===============================================================================

#-------------------------------------------------------------------------------
# Look up variables once to save on overhead and increase readability
#
# These can be removed/commented out and filled in manually if facter and 
# foreman are not part of your environment
#-------------------------------------------------------------------------------
key=<%= scope.lookupvar('sensors::key') %>
key_last_sel=<%= scope.lookupvar('sensors::key_last_sel') %>
log=<%= scope.lookupvar('sensors::log') %>
reporting_class=<%= scope.lookupvar('sensors::facter_reporting_class') %>
reporting_sender=<%= scope.lookupvar('sensors::facter_reporting_sender') %>
reporting_server=<%= scope.lookupvar('sensors::facter_reporting_server') %>
thisserver=<%= fqdn %>
zs=<%= scope.lookupvar('$reporting_class::$reporting_sender') %>
zserver=<%= scope.lookupvar('$reporting_class::$reporting_server') %>
zport=<%= scope.lookupvar('sensors::reporting_port') %>
zapi=<%= scope.lookupvar('sensors::reporting_api_url') %>
zauth=<%= scope.lookupvar('sensors::reporting_auth') %>
thisserver=<%= fqdn %>


# if lm_sensors does not detect any sensor modules, run initial configuration
/etc/init.d/lm_sensors status
if [ $? -ne 0 ]
then	echo "Running initial config" >> $log
	# detect the kernel modules we need (this is run twice)
	(while :; do echo ""; done ) | /usr/sbin/sensors-detect
	sleep 1
	# testing on cap1-ge02-hsc has shown that, despite logical sense, a second run either: 
	# 1. makes more sensors discoverable, and/or 
	# 2. makes more modules accessible
	(while :; do echo ""; done ) | /usr/sbin/sensors-detect
	
	# now see if any modules are loaded
	module_list=`grep -i MODULE_[0-9]= /etc/sysconfig/lm_sensors | wc -l`

	if [ "$module_list" -eq 0 ]
	then
		$zs -vv -z $zserver -p $zport -s $thisserver -k $key"status" -o NoKernelModulesAvailable 1>/dev/null 2>/dev/null
		exit 0
	else	for i in `grep -i MODULE_ /etc/sysconfig/lm_sensors | grep -v "#" | awk -F'=' '{print $2}'`; do /sbin/modprobe $i; done
	fi
fi



# Gather sensors information in one variable. Why not an array? Surprisingly, at this time of writing (6 August 2012), `time` says arrays are marginally slower. And since it's less words to expand variables than write for loops, let's do this
SENSORS=( `/usr/bin/sensors 2>/dev/null | grep "(" | grep -iv ALARM | tr '\n' ';'` )


# If no info returned, we have a problem <- unnecessary? #
#if [ $( echo /usr/bin/sensors | wc -l ) -eq 0 ]
#then $zs -vv -z $zserver -p $zport -s $thisserver -k $key"lm_status" -o NoInformationAvailable 2>/dev/null
#fi
#



# Get the host id for this host #
hostdata=\{\"jsonrpc\":\"2.0\",\"method\":\"host.get\",\"params\":\{\"output\":\"extend\",\"filter\":\{\"host\":\[\"$thisserver\"\]\}\},\"auth\":\"$zauth\",\"id\":\"2\"\}

#echo curl -i -X POST -H 'Content-Type:application/json' -d $hostdata $zapi >> $log
hostid=$( curl -i -X POST -H 'Content-Type:application/json' -d $hostdata $zapi | tr ',' '\n' | grep \"hostid | tr '\"' '\n' | grep [0-9] )


# Get the app id for this host's sensors application #
getappid=\{\"jsonrpc\":\"2.0\",\"method\":\"application.get\",\"params\":\{\"search\":\{\"name\":\"Sensors\"\},\"hostids\":\"$hostid\",\"output\":\"extend\",\"expandData\":1,\"limit\":1\},\"auth\":\"$zauth\",\"id\":2\}


# Get the zabbix application id for this host #
#echo curl -i -X POST -H 'Content-Type:application/json' -d $getappid $zapi >> $log
appid_exists=$( curl -i -X POST -H 'Content-Type:application/json' -d $getappid $zapi | grep $thisserver | tr ',' '\n' | grep \"applicationid | tr '\"' '\n' | grep [0-9] )


# number of data items #
totalitems=$( echo "${SENSORS[@]}" | tr ';' '\n' | grep -v "^$" | wc -l )


#if application does not exist, we need to create it along with all items #
if [ -z $appid_exists ]
then
        # create sensors application for host's classification
        appdata=\{\"jsonrpc\":\"2.0\",\"method\":\"application.create\",\"params\":\[\{\"name\":\"Sensors\",\"hostid\":\"$hostid\"\}\],\"auth\":\"$zauth\",\"id\":2\}
        #echo curl -i -X POST -H 'Content-Type:application/json' -d $appdata $zapi >> $log
        appid=$( curl -i -X POST -H 'Content-Type:application/json' -d $appdata $zapi | tr ',' '\n' | grep \"applicationid | tr '\"' '\n' | grep [0-9] )

        # create csg.sensors_ipmi_daemon_status item 
        itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"csg.sensors_lm_status\",\"key_\":\"csg.sensors_lm_status\",\"type\":\"7\",\"value_type\":\"4\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\}
        #echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi >> $log
        curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi


	# create items for all data points
	for (( i=1; i<=$totalitems; i++ )); do 
		itemname=$( echo "${SENSORS[@]}" | tr ';' '\n' | awk -F\: '{print $1}' | head -"$i" | tail -1 | sed s/\://g | sed s/\ //g ) && 
		itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"$key"$itemname"\",\"key_\":\"$key"$itemname"\",\"type\":\"7\",\"value_type\":\"0\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\} && 
		echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi >> $log && 
		curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi; done

fi




# Inform zabbix that the daemon is active 
$zs -vv -z $zserver -p $zport -s $thisserver -k $key"status" -o Active 2>/dev/null



# send gathered sensor data to zabbix 
for (( i=1; i<=$totalitems; i++ )); do itemline=$( echo "${SENSORS[@]}" | tr ';' '\n' | head -"$i" | tail -1 ) && itemname=$( echo $itemline | awk -F\: '{print $1}' | sed s/\://g | sed s/\ //g ) && itemvalue=$( echo $itemline | awk -F\: '{print $2}' | awk -F\( '{print $1}' | awk '{print $1}' | sed s/\+//g | sed s/\°//g ) && $zs -vv -z $zserver -p $zport -s $thisserver -k $key"$itemname" -o $itemvalue; done
