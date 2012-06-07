#!/bin/bash
# Ensure sensors and gather information for zabbix

# set zabbix sender
zs=<%= scope.lookupvar('zabbix-agent::which_zsender') %>
zserver=<%= scope.lookupvar('zabbix-agent::zabbix_server') %>
zport=10051
thisserver=<%= fqdn %>

# make sure lm_sensors is installed, otherwise we can't do anything
SENSORS=`which sensors`
if [ $? -ne 0 ]
then    $zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_lm_status -o NotInstalled
        exit 0
fi
SENSORS_DETECT="/usr/sbin/sensors-detect"
MODPROBE="/sbin/modprobe"

# gather data at this instant in time. Save it to an array so we don't have to probe multiple times. If this is the first run, detect the modules we need
SENSORS=( `$SENSORS -u 2>/dev/null | tr '\n' ';' 2>/dev/null` )

# if we failed to run lm_sensors and dump vaild output, try to load the appropriate module
if [ `echo "${SENSORS[@]}" | tr ';' '\n' | grep -v "^$" | wc -l` -eq 0 ]
then
	# detect the kernel modules we need (this is run twice)
	(while :; do echo ""; done ) | $SENSORS_DETECT
	sleep 1
	# testing on cap1-ge02-hsc has shown that a second run either makes more sensors discoverable and/or more modules accessible
	(while :; do echo ""; done ) | $SENSORS_DETECT
	
	# now see if any modules are loaded
	module_list=`grep -i MODULE_[0-9]= /etc/sysconfig/lm_sensors | wc -l`

	if [ "$module_list" -eq 0 ]
	then
		$zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_lm_status -o NoKernelModulesAvailable
		exit 0
	else	for i in `grep -i MODULE_ /etc/sysconfig/lm_sensors | grep -v "#" | awk -F'=' '{print $2}'`; do $MODPROBE $i; done
	fi
fi

# inform zabbix that the daemon is active
$zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_lm_status -o Active


# core temp
cores=`echo "${SENSORS[@]}" | tr ';' '\n' | grep -i core\ | wc -l`
cores=$(( $cores - 1 )) # conventional cpu notation begins at zero
for (( i=0; i<=$cores; i++ )); do $zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_lm_temp_core"$i" -o `echo "${SENSORS[@]}" | tr ';' '\n' | grep -A 1 -i "core\ $i" | tail -1 | awk '{print $2}' | cut -d. -f1`; done


# ins voltage
ins=`echo "${SENSORS[@]}" | tr ';' '\n' | grep -i in[0-9]_input | wc -l`
ins=$(( $ins - 1 )) # begins at zero
for (( i=0; i<=$ins; i++ )); do $zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_lm_volts_in"$i" -o `echo "${SENSORS[@]}" | tr ';' '\n' | grep -i in"$i"_input\: | awk '{print $2}' | cut -d. -f1`; done


# fan RPM
fans=`echo "${SENSORS[@]}" | tr ';' '\n' | grep -i fan[0-9]_input\: | wc -l`
for (( i=1; i<=$fans; i++ )); do if (( "`echo "${SENSORS[@]}" | tr ';' '\n' | grep -i fan"$i"_alarm | grep 0\.0 | wc -l`"=="1" )); then $zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_lm_rpm_fan$i -o `echo "${SENSORS[@]}" | tr ';' '\n' | grep -i fan"$i"_input\: | awk '{print $2}' | cut -d. -f1`; fi ; done
