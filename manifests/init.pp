#
# Sensors: Probe physical hardware for temperature, voltage, wattage, amperage, presence, etc.
#
# Originally two manifests (ipmi and lm_sensors), it seemed easier to group them together for one-click execution
# Apply this to any host, physical or virtual, and it should JustWork(tm) or at least Z!send an error message
#
class sensors
{
# Supermicro
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
	
	# set a cron job to poll the server's sensors every minute
	cron { "poll_sensors":
		ensure  => present,
		command => "nice -10 /etc/zabbix/lm_sensors.sh",
		user    => "root",
		minute  => "*/1",
	     }  
	
	# Order of operations        
	File["lm_sensors.sh"] -> Cron["poll_sensors"]	
}
else # catch-all (Dell)
{
	# RHEL6 has ipmitool, whereas RHEL5 has OpenIPMI-tools. They are the same binary <__<
	if ($operatingsystemrelease >= 6)       { $rpms = ["ipmitool"] }
	else                                    { $rpms = ["OpenIPMI-tools"] }

	package { $rpms: ensure => installed, }

	# loads ipmi kernel modules, runs tool, and sends to zabbix
	file { "/etc/zabbix/ipmi.sh":
		path    => "/etc/zabbix/ipmi.sh",
		owner   => "root",
		group   => "root",
		mode    => "0750",
		content	=> template("sensors/ipmi.sh"),
		require	=> Package[$rpms],
	     }	 

	# set a cron job to poll ipmi every two minutes
	cron { "ipmi.sh_cron":
		ensure  => present,
		command => "nice -10 /etc/zabbix/ipmi.sh",
		user    => "root",
		minute  => "*/1",
	     }
	
	# ensure the ipmi daemon running for all runlevels
	exec { "chkconfig_ipmievd_on":
		command => "chkconfig --level 12345 ipmievd on",
		path    => "/sbin/:/usr/sbin/:/bin/:/usr/bin/",
		onlyif  => 'test `chkconfig --list | grep -i ipmi | grep \:on | wc -l` -eq 0'
	     }

	# set root user pass, null user pass, and community string
	exec { "set_pass_and_community_string":
		command => "ipmitool lan set 1 password 1T1ger1mu.1 && ipmitool user set password 2 alphadog && ipmitool lan set 1 snmp CSGLINUX",
		path    => "/sbin/:/usr/sbin/:/bin/:/usr/bin/",
		onlyif  => 'test `/etc/init.d/ipmievd status 2>/dev/null | grep -i running | wc -l` -eq 1 && test `ipmitool lan print | grep CSGLINUX | wc -l` -eq 0'
	     }

	# Order of operations   
	File["/etc/zabbix/ipmi.sh"] -> Cron["ipmi.sh_cron"] -> Exec["chkconfig_ipmievd_on"] -> Exec["set_pass_and_community_string"]
	
	# here be future sol configuration
	
	#
}
}
