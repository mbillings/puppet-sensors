
# Ensure IPMI daemon is running, and gather information for zabbix

# set zabbix sender
zs=<%= scope.lookupvar('zabbix-agent::which_zsender') %>
zserver=<%= scope.lookupvar('zabbix-agent::zabbix_server') %>
zport=10051
thisserver=<%= fqdn %>


# see if we are physical or virtual
FACTER=`which facter`
whatami=`$FACTER | grep -i virtual | grep -i physical | awk '{print $3}'`
if [ "$whatami" != "physical" ]
then exit 0
fi

# check for ipmitool, otherwise we can't do anything
IPMITOOL=`which ipmitool`
if [ $? -ne 0 ]
then	$zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_daemon_status -o IPMItoolNotInstalled
	exit 0
fi


# ensure the daemon is running
running=`/etc/init.d/ipmievd status 2>/dev/null | grep -i running | wc -l`
if [ $running -eq 0 ]
then
        ipmiresult=`/etc/init.d/ipmievd start 2>/dev/null`
        if [ $? -ne 0 ]
        then
                /sbin/modprobe ipmi_devintf

                maj=`cat /proc/devices | awk '/ipmidev/{print $1}'`
                echo $maj
                if [ -c /dev/ipmi0 ]
                then rm -f /dev/ipmi0
                fi
                
		/bin/mknod /dev/ipmi0 c $maj 0

                IPMI_DRIVERS="ipmi_si ipmi_si_drv ipmi_kcs_drv"
                for driver in $IPMI_DRIVERS; do
                  find /lib/modules/`uname -r`/kernel/drivers/char/ipmi | grep $driver > /dev/null
                  if [ $? -eq 0 ] ; then
                    #Here are specific memory locations for Supermicro AOC-type IPMI cards
                    /sbin/modprobe $driver type=kcs ports=0xca8 regspacings=4
                    break
                  fi
                done

                nowrunning=`/etc/init.d/ipmievd start 2>/dev/null | grep -i running | wc -l`
                if [ $nowrunning -eq 0 ]
                then { # if the daemon cannot be started, alert zabbix
			$zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_daemon_status -o Stopped
		        exit 0
		     }
                fi
        fi
fi

# inform zabbix that the daemon is active
$zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_daemon_status -o Active


# gather data (takes a few seconds)
IPMISDR=( `$IPMITOOL sdr elist | tr '\n' ';'` )


#### 3.x: Processor info: slots occupied/available, temp ###
cpus=`echo "${IPMISDR[@]}" | tr ';' '\n' | grep "3\." | grep -i Presence | grep -iv detected | wc -l`

cpus=$(( $cpus - 1 )) # conventional cpu notation begins at zero

for (( i=0; i<=$cpus; i++ )); do $zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_presence_cpu"$i" -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "3\.$(( $i + 1 ))" | grep -i Presence | grep -iv  detected | awk -F \| '{print $5}' | awk '{print $1}' | sed -e 's/^[ \t]*//'` && $zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_temp_cpu"$i" -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "3\.$(( $i + 1 ))" | grep Temp | awk -F \| '{print $5}' | awk '{print $1}' | sed s/-// | sed -e 's/^[ \t]*//'`; done
############################################################



#### 7.x: System Board: ambient temp, fan rpm ##############
$zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_temp_ambient -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "Ambient Temp" | awk -F \| '{print $5}' | awk '{print $1}' | sed -e 's/^[ \t]*//'`

$zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_temp_planar -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "Planar Temp" | awk -F \| '{print $5}' | awk '{print $1}' | sed -e 's/^[ \t]*//'`

$zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_redundancy_ps -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "PS Redundancy" | awk -F \| '{print $5}' | sed s/\ //g | sed -e 's/^[ \t]*//'`

$zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_redundancy_fan -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "Fan Redundancy" | awk -F \| '{print $5}' | sed s/\ //g | sed -e 's/^[ \t]*//'`

fans=`echo "${IPMISDR[@]}" | tr ';' '\n' | grep "7\." | grep RPM | wc -l`
for (( i=0; i<=$fans; i++ )); do $zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_rpm_fan"$i" -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "7\." | grep "FAN $i RPM" | awk -F \| '{print $5}' | awk '{print $1}' | sed -e 's/^[ \t]*//'`; done

$zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_system_watts -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "7\." | grep Watts | awk -F \| '{print $5}' | awk '{print $1}' | sed -e 's/^[ \t]*//'`
############################################################



#### 8.x: Memory module: DIMM temp #########################
dimms=`echo "${IPMISDR[@]}" | tr ';' '\n' | grep "8\." | grep Temp | wc -l`

dimms=$(( $dimms - 1 ))

for (( i=0; i<=$dimms; i++ )); do $zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_temp_dimm"$i" -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "8\." | grep "Temp" | awk -F \| '{print $5}' | awk '{print $1}' | sed -e 's/^[ \t]*//'`; done
############################################################



#### 10.x: Power Supply: slots occupied, temp #############
psnum=`echo "${IPMISDR[@]}" | tr ';' '\n' | grep "10\." | grep -i presence | grep -iv status | wc -l`

for (( i=1; i<=$psnum; i++ )); do $zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_presence_ps"$i" -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "10\.$i" | grep Presence | awk -F \| '{print $5}' | awk '{print $1}' | sed -e 's/^[ \t]*//'` && $zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_temp_ps"$i" -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "10\.$i" | grep Temp | awk -F \| '{print $5}' | awk '{print $1}' | sed -e 's/^[ \t]*//'` && $zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_amps_ps"$i" -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "10\.$i" | grep Current | awk -F \| '{print $5}' | awk '{print $1}' | sed -e 's/^[ \t]*//'` && $zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_volts_ps"$i" -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "10\.$i" | grep Voltage | awk -F \| '{print $5}' | awk '{print $1}' | sed -e 's/^[ \t]*//'`; done
############################################################



#### 26.x: Disk Drive Bay: SAS cable status, presence ######
$zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_presence_diskdrive -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "26\." | grep Presence | awk -F \| '{print $5}' | awk '{print $1}' | sed -e 's/^[ \t]*//'`

cablenum=`echo "${IPMISDR[@]}" | tr ';' '\n' | grep "26\." | grep Cable | wc -l`

for (( i=1; i<=$cablenum; i++ )); do $zs -vv -z $zserver -p $zport -s $thisserver -k csg.sensors_ipmi_conn_cable"$i" -o `echo "${IPMISDR[@]}" | tr ';' '\n' | grep "26\." | grep Cable | awk -F \| '{print $5}' | awk '{print $1}' | sed -e 's/^[ \t]*//'`; done
############################################################

