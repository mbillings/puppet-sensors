#!/bin/bash

zs=<%= scope.lookupvar('zabbix-agent::which_zsender') %>
zserver=<%= scope.lookupvar('zabbix-agent::zabbix_server') %>
zport=10051
thisserver=<%= fqdn %>
key="csg.sensors_ipmi_"

# only grab the information we care about and what ipmitool can actually read: 3=CPU, 7=System Board, 8=Memory, 10=Power, 26=Disk Drive Bay
# 34 sometimes returns, but the values aren't important
for i in 3 7 8 10 26
do
        IPMInum=( $( /usr/bin/ipmitool sdr entity $( echo $i ) | egrep -iv "\ $|Disabled|State\ Deasserted|No\ Reading|Error|Unknown" | tr [:upper:] [:lower:] | sed s/-//g | tr '\n' ';' ) )

        IPMIcount=`echo "${IPMInum[@]}" | tr ';' '\n' | grep -v "^$" | wc -l`

        # set/reset counter
        counter=0

        for (( j=1; j<=$IPMIcount; j++ ))
        do
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
				then	qualifier=disk"$counter"_
				else	qualifier=""
				fi
                        fi
                fi

                # send to zabbix
                echo $zs -vv -z $zserver -p $zport -s $thisserver -k $key"$qualifier"$( echo $IPMIval | awk -F \| '{print $1}' | sed 's/[ \t]*$//g' | sed s/\ /_/g ) -o $( if [ $( echo $IPMIval | awk -F \| '{print $5}' | awk '{print $1}' | grep ^[0-9] | wc -l ) -eq 1 ]; then echo $IPMIval | awk -F \| '{print $5}' | awk '{print $1}' ; else echo $IPMIval | awk -F \| '{print $5}' | sed 's/[ \t]*$//g' | sed 's/^[ \t]*//' | sed s/\ /_/g ; fi )
        done
done

