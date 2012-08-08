#!/bin/bash
#
# Purpose: Initialize ipmi and create Zabbix items for the host
#
# Comments: As of 26 June 2012, IPMI identifiers are not only non-unique, but also not consistent across platforms.
# 	    Therefore, a template or templates to rule them all is not feasible.
# 	    In addition, the Zabbix IPMI interface requires a template to work. 
# 	    Thus, until a grand unified template is created or a newer IPMItools returns unique and consistent IDs,
# 	    we are forced to create Zabbix items based on what IPMI returns.
#
# 	    Due to curl formatting, quotation marks must be delimited so that the delimits will be read at
#	    execution time and interpreted as quotes. 
#	    See http://www.zabbix.com/documentation/1.8/api or the "zabbix_curl_api" in the csglinux 
#	    git repo for Zabbix curl formatting.

#############################
## User-editable variables ##
#############################
key="csg.sensors_ipmi_"
key_last_sel=$key"last_sel"
ipmistatus=$key"daemon_status"
LSMOD="/sbin/lsmod"

zs=/usr/bin/zabbix_sender

zserver=128.206.15.46
zport=10051
thisserver=csgsandbox.doit.missouri.edu
zapi="https://zabbix.missouri.edu/zabbix/api_jsonrpc.php"
zauth="91240fb8d61542580a3d2e7b00920b3c"
#############################


#######################################################################################
## Check if ipmi modules are loaded. If none detected, try to load necessary modules ##
#######################################################################################
modules=`$LSMOD | grep -i ^ipmi | wc -l`
echo "first number of modules found: "$modules >> /etc/zabbix/ipmitrouble
echo "lsmod command: "$LSMOD >> /etc/zabbix/ipmitrouble
if [ "$modules" -eq 0 ] 
then
	/sbin/modprobe ipmi_devintf

        if [ -c /dev/ipmi0 ]
	then rm -f /dev/ipmi0
	fi

	/bin/mknod /dev/ipmi0 c `cat /proc/devices | awk '/ipmidev/{print $1}'` 0

	IPMI_DRIVERS="ipmi_si ipmi_si_drv ipmi_kcs_drv"
	for driver in $IPMI_DRIVERS; 
	do
	  found=$( find /lib/modules/`uname -r`/kernel/drivers/char/ipmi | grep $driver | grep -v "^$" | wc -l 2>/dev/null )
	  if [ "$found" -ne 0 ] 
	  then
	    #Here are specific memory locations for Supermicro AOC-type IPMI cards
	    /sbin/modprobe $driver type=kcs ports=0xca8 regspacings=4
	    break
	  fi
	done

	modules=`$LSMOD | grep -i ^ipmi | wc -l`
	if [ "$modules" -eq 0 ]	
	then
		# if no modules are available, alert zabbix
		$zs -vv -z $zserver -p $zport -s $thisserver -k $ipmistatus -o NoModulesAvailable 1>/dev/null 2>/dev/null
		exit 0
	fi
fi
#######################################################################################




############################	
## Format host id request ##
############################
hostdata=\{\"jsonrpc\":\"2.0\",\"method\":\"host.get\",\"params\":\{\"output\":\"extend\",\"filter\":\{\"host\":\[\"$thisserver\"\]\}\},\"auth\":\"$zauth\",\"id\":\"2\"\}

# get host id from zabbix
#echo curl -i -X POST -H 'Content-Type:application/json' -d $hostdata $zapi >> $ipmilog
hostid=$( curl -i -X POST -H 'Content-Type:application/json' -d $hostdata $zapi | tr ',' '\n' | grep \"hostid | tr '\"' '\n' | grep [0-9] )
############################




###################################
## Format sensors app id request ##
###################################
appid=\{\"jsonrpc\":\"2.0\",\"method\":\"application.get\",\"params\":\{\"search\":\{\"name\":\"Sensors\"\},\"hostids\":\"$hostid\",\"output\":\"extend\",\"expandData\":1,\"limit\":1\},\"auth\":\"$zauth\",\"id\":2\}

# get sensors app id from zabbix
#echo curl -i -X POST -H 'Content-Type:application/json' -d $appid $zapi #>> $ipmilog
appid_exists=$( curl -i -X POST -H 'Content-Type:application/json' -d $appid $zapi | grep $thisserver | tr ',' '\n' | grep \"applicationid | tr '\"' '\n' | grep [0-9] )
###################################




###################################################################
## If application does not exist, create it along with all items ##
###################################################################
if [ -z $appid_exists ]
then
	# create Sensors application for host's classification
	appdata=\{\"jsonrpc\":\"2.0\",\"method\":\"application.create\",\"params\":\[\{\"name\":\"Sensors\",\"hostid\":\"$hostid\"\}\],\"auth\":\"$zauth\",\"id\":2\}
#	echo curl -i -X POST -H 'Content-Type:application/json' -d $appdata $zapi >> $ipmilog
	appid=$( curl -i -X POST -H 'Content-Type:application/json' -d $appdata $zapi | tr ',' '\n' | grep \"applicationid | tr '\"' '\n' | grep [0-9] )
	
	# create csg.sensors_ipmi_daemon_status item 
	itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"$ipmistatus\",\"key_\":\"$ipmistatus\",\"type\":\"7\",\"value_type\":\"4\",\"history\":\"30\",\"trends\":\"365\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\}
#	echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi >> $ipmilog
	curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi

	
	# create ipmi security event log key
	itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"$key_last_sel\",\"key_\":\"$key_last_sel\",\"type\":\"7\",\"value_type\":\"4\",\"history\":\"30\",\"trends\":\"365\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\}
#        echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi >> $ipmilog
    curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi
fi	
###################################################################




###########################################
## Inform zabbix that ipmitool is active ##
###########################################
$zs -vv -z $zserver -p $zport -s $thisserver -k $ipmistatus -o Active 1>/dev/null 2>/dev/null
###########################################




############################################################
## Send the last line of the security event log to zabbix ##
############################################################
$zs -vv -z $zserver -p $zport -s $thisserver -k $key_last_sel -o "$( /usr/bin/ipmitool sel list | tail -1 | sed 's/^[ \t]*//' | sed 's/[ \t]*$//g' | sed s/\|//g | sed s/\ /_/g | sed s/\\//_/g | sed s/\:/_/g | sed s/\#//g )" 1>/dev/null 2>/dev/null
############################################################




#############################################################################
## Ipmitool only returns a few entities, and of those, we only care about: ##
## 3=CPU, 7=System Board, 8=Memory, 10=Power, 26=Disk Drive Bay            ##
#############################################################################
for i in 3 7 8 10 26 
do 
        IPMInum=( $( /usr/bin/ipmitool sdr entity $( echo $i ) | egrep -iv "\ $|Disabled|State\ Deasserted|No\ Reading|Error|Unknown" | tr [:upper:] [:lower:] | sed s/-//g | tr '\n' ';' ) ) 
 
        IPMIcount=`echo "${IPMInum[@]}" | tr ';' '\n' | grep -v "^$" | wc -l` 
 
        # set counter to create unique id names (IPMI does not always have unique ids, so we must make them unique)
        counter=0 
 
	# get values for keys
        for (( j=1; j<=$IPMIcount; j++ )) 
        do	# move sequentially top to bottom 
	        IPMIval=`echo "${IPMInum[@]}" | tr ';' '\n' | head -"$j" | tail -1` 
 
                if [ `echo $IPMIval | egrep "3\.[0-9]|8\.[0-9]|10\.[0-9]" | wc -l` -ge 1 ] 
                then 
                        # get the number of the device 
                        qualifier=`echo $IPMIval | awk -F \| '{print $4}' | awk -F \. '{print $2}' | sed 's/[ \t]*$//g'` 
                        if [ `echo $IPMIval | awk -F \| '{print $4}' | egrep -i "3\.[0-9]" | wc -l` -ge 1 ] 
                        then    qualifier=cpu"$qualifier"_ 
                        else    if [ `echo $IPMIval | awk -F \| '{print $4}' | grep -i "8\.[0-9]" | wc -l` -ge 1 ] 
                                then    qualifier=dimm"$counter"_ 
                                        counter=$(( $counter + 1 )) 
                                else    qualifier=ps"$qualifier"_ 
                                fi 
                        fi 
                else    if [ `echo $IPMIval | grep "7\.[0-9]" | awk -F \| '{print $1}' | grep -i BMC | wc -l` -ge 1 ] 
                        then    qualifier=bmc"$counter"_ 
                                counter=$(( $counter + 1 )) 
                        else    if [ `echo $IPMIval | grep "26\.[0-9]" | wc -l` -ge 1 ] 
                                then    qualifier=disk"$counter"_ 
                                else    qualifier="" 
                                fi 
                        fi 
                fi 
 
		# get key suffix
                keyname=$key"$qualifier""$( echo $IPMIval | awk -F \| '{print $1}' | sed 's/[ \t]*$//g' | sed s/\ /_/g )"
		# determine what unit value zabbix should use for this key
		if [ $( echo $IPMIval | awk -F \| '{print $5}' | awk '{print $1}' | sed s/\-// | grep ^[0-9] | wc -l ) -eq 1 ]
		then 	# numeric (float)
			units=$( echo $IPMIval | awk -F \| '{print $5}' | cut -d' ' -f2 --complement | sed 's/^[ \t]*//' | sed s/\ /_/g | sed 's/[ \t]*//' | tr [:upper:] [:lower:] )
			valuetype=0
			keyval=$( echo $IPMIval | awk -F \| '{print $5}' | awk '{print $1}' | sed s/\-// )
		else 	# text
			valuetype=4
			keyval=$( echo $IPMIval | awk -F \| '{print $5}' | sed 's/[ \t]*$//g' | sed 's/^[ \t]*//' | sed s/\ /_/g ) 
		fi

		#### create items ####
		if [ -z $appid_exists ]
		then
			if [ $valuetype -eq 0 ]
			then 
				itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"$keyname\",\"key_\":\"$keyname\",\"type\":\"7\",\"value_type\":\"$valuetype\",\"units\":\"$units\",\"history\":\"30\",\"trends\":\"365\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\}
			else 
				itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"$keyname\",\"key_\":\"$keyname\",\"type\":\"7\",\"value_type\":\"$valuetype\",\"history\":\"30\",\"trends\":\"365\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\}
			fi
#			echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi >> $ipmilog
			curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi
		fi
		#### /create items ####
		

		# send the item's value to zabbix
		$zs -vv -z $zserver -p $zport -s $thisserver -k $keyname -o "$keyval" 1>/dev/null 2>/dev/null
        done 
done 
#############################################################################
