# Sensors: Probe physical hardware for temperature, voltage, wattage, amperage, hw presence/capability, etc.
#
# Originally two manifests (ipmi and lm_sensors), it seemed easier to group them together for one-click execution
# Apply this to any host, physical or virtual, and it should JustWork(tm) or at least Z!send an error message
#
class sensors
{
#### Supermicro ####
if ( $manufacturer == "Supermicro" )
{ 
	$rpms = ["lm_sensors"] 
	package { $rpms: ensure => installed, }
	
	file { "lm_sensors.sh":
		path    => "/etc/zabbix/lm_sensors.sh",    
		owner   => "root",
		group   => "root",
		mode    => "0750", 
		content => template("sensors/lm_sensors.sh"),
		require => Package[$rpms],
	     } 


	# cron to poll lm sensors
	cron { "lm_sensors_cron":
		ensure  => present,
		command => "if [ `ps aux | grep sensors | grep -v grep | wc -l` -eq 0 ]; then `nice -10 /etc/zabbix/lm_sensors.sh 1>/dev/null 2>/dev/null`; fi 1>/dev/null 2>/dev/null",
		user    => "root",
		minute  => "*/2",
	     }
}
else #### Dell (catch-all) ####
{
	# RHEL6=ipmitool, RHEL5=OpenIPMI-tools
	if ($operatingsystemrelease >= 6)       { $rpms = ["ipmitool"] }
	else                                    { $rpms = ["OpenIPMI-tools"] }

	package { $rpms: ensure => installed, }


	# loads ipmi kernel modules, runs tool, and sends to zabbix
	# This file is only ensured once. If you need to reinitialize, just delete this file on the host
	file { "/etc/zabbix/ipmi.sh":
		#replace => "no",
		ensure	=> "present",
		path    => "/etc/zabbix/ipmi.sh",
		owner   => "root",
		group   => "root",
		mode    => "0750",
		content	=> template("sensors/ipmi.sh"),
		require	=> Package[$rpms],
	     }	 


	# cron to poll ipmi sensors
	cron { "ipmi_sensors_cron":
		ensure  => present,
		command => "if [ `ps aux | grep 'ipmi.sh' | grep -v grep | wc -l` -eq 0 ]; then `nice -10 /etc/zabbix/ipmi.sh 1>/dev/null 2>/dev/null`; fi 1>/dev/null 2>/dev/null",
		user    => "root",
		minute  => "*/2",
	     }


	# hacked-together time set
	exec { "set_ipmi_time":
		command => 'ipmitool sel time set "`date +%m\/%d\/%Y\ %H:%M:%S`"',
		path    => "/sbin/:/usr/sbin/:/bin/:/usr/bin/",
		onlyif  => 'test `/etc/init.d/ipmievd status 2>/dev/null | grep -i running | wc -l` -eq 1 && ipmitime=$( ipmitool sel time get | sed s/\\///g | sed s/\://g | sed s/\ //g ) && datetime=$( /bin/date +%m%d%Y%H%M%S ) && test `if [ "${ipmitime}" -ne "${datetime}" ]; then echo 1; fi` -eq 1'
	     }


	# set root user pass, null user pass, and community string
	exec { "set_pass_and_community_string":
		command => "ipmitool lan set 1 password 1T1ger1mu.1 && ipmitool user set password 2 alphadog && ipmitool lan set 1 snmp CSGLINUX",
		path    => "/sbin/:/usr/sbin/:/bin/:/usr/bin/",
		onlyif  => 'test `/etc/init.d/ipmievd status 2>/dev/null | grep -i running | wc -l` -eq 1 && test `ipmitool lan print | grep CSGLINUX | wc -l` -eq 0'
	     }
	
	# here be future sol configuration when we have 10.x.x.x hooks into physical boxen
		
}
}
