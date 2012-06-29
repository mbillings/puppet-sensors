#!/bin/bash
#
# Initialize ipmi and create Zabbix items for the host
# As of 26 June 2012, IPMI identifiers are not only non-unique, but also not consistent across platforms.
# Therefore, a template or templates to rule them all isn't/aren't exactly feasible.
# In addition, the Zabbix IPMI interface requires a template to work. 
# Thus, until a grand unified template is created or a newer IPMItools returns unique and consistent IDs,
# we are stuck doing this as a pseudo-customized operation.
# However, this is only pseudo-custom since this script names items based on what IPMI returns

key="csg.sensors_ipmi_"
key_last_sel=$key"last_sel"
ipmistatus=$key"daemon_status"
ipmilog="/etc/zabbix/ipmilog"

zs=<%= scope.lookupvar('zabbix-agent::which_zsender') %>
zserver=<%= scope.lookupvar('zabbix-agent::zabbix_server') %>
zport=10051
thisserver=<%= fqdn %>
zapi="https://zabbix.missouri.edu/zabbix/api_jsonrpc.php"
zauth="91240fb8d61542580a3d2e7b00920b3c"

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
                        $zs -vv -z $zserver -p $zport -s $thisserver -k $ipmistatus -o Stopped
                        exit 0
                     }
                fi
        fi
fi


#### curl to zabbix api ####
# Due to curl formatting, we have to delimit in such a way that the delimits will be read at execution time.
# See http://www.zabbix.com/documentation/1.8/api or "zabbix_curl_api" in the csglinux git repo for more info
# Example json request: 
# { 
#   "jsonrpc":"2.0",
#   "method":"host.get",
#   "params":{
#  	        "output":"extend",
#	        "filter": { 
#			     "host":["ecmsapp1.missouri.edu"] 
#			  }
#	     }, 
#   "auth":"91240fb8d61542580a3d2e7b00920b3c",
#   "id":"2"
# }

echo ============================================================== >> $ipmilog

	
## get host id ##
hostdata=\{\"jsonrpc\":\"2.0\",\"method\":\"host.get\",\"params\":\{\"output\":\"extend\",\"filter\":\{\"host\":\[\"$thisserver\"\]\}\},\"auth\":\"$zauth\",\"id\":\"2\"\}

# curl get host id to zabbix
echo curl -i -X POST -H 'Content-Type:application/json' -d $hostdata $zapi >> $ipmilog
hostid=$( curl -i -X POST -H 'Content-Type:application/json' -d $hostdata $zapi | tr ',' '\n' | grep \"hostid | tr '\"' '\n' | grep [0-9] )
####


## get sensors app id ##
getappid=\{\"jsonrpc\":\"2.0\",\"method\":\"application.get\",\"params\":\{\"search\":\{\"name\":\"Sensors\"\},\"hostid\":\"$hostid\",\"output\":\"extend\",\"expandData\":1,\"limit\":1\},\"auth\":\"$zauth\",\"id\":2\}

# curl get sensors app id to zabbix
echo curl -i -X POST -H 'Content-Type:application/json' -d $getappid $zapi >> $ipmilog
appid_exists=$( curl -i -X POST -H 'Content-Type:application/json' -d $getappid $zapi | grep $thisserver | tr ',' '\n' | grep \"applicationid | tr '\"' '\n' | grep [0-9] )
####


#if application does not exist, we need to create it along with all items
if [ -z $appid_exists ]
then
	# create Sensors application for host's classification
	appdata=\{\"jsonrpc\":\"2.0\",\"method\":\"application.create\",\"params\":\[\{\"name\":\"Sensors\",\"hostid\":\"$hostid\"\}\],\"auth\":\"$zauth\",\"id\":2\}
	echo curl -i -X POST -H 'Content-Type:application/json' -d $appdata $zapi >> $ipmilog
	appid=$( curl -i -X POST -H 'Content-Type:application/json' -d $appdata $zapi | tr ',' '\n' | grep \"applicationid | tr '\"' '\n' | grep [0-9] )
	
	# create csg.sensors_ipmi_daemon_status item 
	itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"$ipmistatus\",\"key_\":\"$ipmistatus\",\"type\":\"7\",\"value_type\":\"4\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\}
	echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi >> $ipmilog
	curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi

	
	# create ipmi security event log key
	itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"$key_last_sel\",\"key_\":\"$key_last_sel\",\"type\":\"7\",\"value_type\":\"4\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\}
        echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi >> $ipmilog
        curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi
fi	




# inform zabbix that the ipmi daemon is active
$zs -vv -z $zserver -p $zport -s $thisserver -k $ipmistatus -o Active
	
# send the last line of the security event log log to zabbix
$zs -vv -z $zserver -p $zport -s $thisserver -k $key_last_sel -o "$( /usr/bin/ipmitool sel list | tail -1 | sed 's/^[ \t]*//' | sed 's/[ \t]*$//g' | sed s/\|//g | sed s/\ /_/g | sed s/\\//_/g | sed s/\:/_/g | sed s/\#//g )"




# ipmitool only returns a few entities, and of those, we only care about these: 3=CPU, 7=System Board, 8=Memory, 10=Power, 26=Disk Drive Bay 
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
				itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"$keyname\",\"key_\":\"$keyname\",\"type\":\"7\",\"value_type\":\"$valuetype\",\"units\":\"$units\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\}
			else 
				itemdata=\{\"jsonrpc\":\"2.0\",\"method\":\"item.create\",\"params\":\{\"description\":\"$keyname\",\"key_\":\"$keyname\",\"type\":\"7\",\"value_type\":\"$valuetype\",\"delay\":\"120\",\"hostid\":\"$hostid\",\"applications\":\[\"$appid\"\]\},\"auth\":\"$zauth\",\"id\":\"2\"\}
			fi
			echo curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi >> $ipmilog
			curl -i -X POST -H 'Content-Type:application/json' -d $itemdata $zapi
		fi
		#### /create items ####
		

		# send the item's value to zabbix
		$zs -vv -z $zserver -p $zport -s $thisserver -k $keyname -o "$keyval"
        done 
done 

