#
# Sensors: Probe physical hardware for temperature, voltage, wattage, amperage, presence, etc.
#
# Originally two manifests (ipmi and lm_sensors), it seemed easier to group them together for one-click execution
# Apply this to any host, physical or virtual, and it should JustWork(tm) or at least Z!send an error message
#
class sensors::new
{

	# cron to poll sensors
	cron { "sensors_cron":
		ensure  => present,
		command => "if [ `ps aux | egrep 'lm_sensors.sh|ipmi.sh' | grep -v grep | wc -l` -eq 0 ]; then `nice -10 /etc/zabbix/sensors`; fi",
		user    => "root",
		minute  => "*/1",
	     }

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



	# create symlink on first run
	exec { "create sensors symlink to lm_sensors on first run":
		command => "ln -s /etc/zabbix/lm_sensors.sh /etc/zabbix/sensors",
		path 	=> "/bin/:/sbin/:/usr/bin/:/usr/sbin/",
		onlyif	=> 'if [ ! -L /etc/zabbix/sensors ]',
	     }


	# cron to poll sensors 
	cron { "poll_sensors":
		ensure  => present,
		command => "nice -10 /etc/zabbix/lm_sensors.sh",
		user    => "root",
		minute  => "*/1",
	     }  
	
	
	# Order of operations        
	File["lm_sensors.sh"] -> Cron["poll_sensors"]	
}
#### /Supermicro ####
else #### catch-all (Dell) ####
{
	# RHEL6=ipmitool, RHEL5=OpenIPMI-tools
	if ($operatingsystemrelease >= 6)       { $rpms = ["ipmitool"] }
	else                                    { $rpms = ["OpenIPMI-tools"] }

	package { $rpms: ensure => installed, }


	# loads ipmi kernel modules, runs tool, and sends to zabbix
	file { "/etc/zabbix/ipmi_init.sh":
		path    => "/etc/zabbix/ipmi_init.sh",
		owner   => "root",
		group   => "root",
		mode    => "0750",
		content	=> template("sensors/ipmi.sh"),
		require	=> Package[$rpms],
	     }	 

	
	# cron to poll ipmi
	cron { "ipmi.sh_cron":
		ensure  => present,
		command => "if [ `ps aux | grep 'ipmi.sh' | grep -v grep | wc -l` -eq 0 ]; then `nice -10 /etc/zabbix/ipmi.sh`; fi",
		user    => "root",
		minute  => "*/1",
	     }
		

	# create symlink on first run
	exec { "link sensors to ipmi for the first run":
		command => "ln -s /etc/zabbix/ipmi_init.sh /etc/zabbix/sensors",
		path 	=> "/bin/:/sbin/:/usr/bin/:/usr/sbin/",
		onlyif	=> 'test `ls -l /etc/zabbix/sensors | grep lrwxrwxrwx | wc -l` -eq 0 && test `ls /etc/zabbix/ipmi.sh | wc -l` -eq 0',
	     }


	# after first run: copy the ipmi file, sed replace $havewerunyet from no to yes in the new script, remove the current symlink, and relink to the new script
	exec { "move sensors symlink to ipmi.sh and reformat to not recheck items":
		command => "cp /etc/zabbix/ipmi_init.sh /etc/zabbix/ipmi.sh && sed -i s/havewerunyet\=\"no\"/havewerunyet\=\"yes\"/ && rm -f /etc/zabbix/sensors && ln -s /etc/zabbix/ipmi.sh /etc/zabbix/sensors",
		path 	=> "/bin/:/sbin/:/usr/bin/:/usr/sbin/",
		onlyif	=> 'test `ls /etc/zabbix/ipmi.sh | wc -l` -eq 0 && test `ls /etc/zabbix/ipmi_initialization_complete | wc -l` -eq 1',
	     }


	# hacked-together time check
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


	# Order of operations   
	#File["/etc/zabbix/ipmi.sh"] -> Cron["ipmi.sh_cron"] -> Exec["chkconfig_ipmievd_on"] -> Exec["set_ipmi_time"] -> Exec["set_pass_and_community_string"]
	
	
	# here be future sol configuration
		
}
#### /catch-all (Dell) ####
}
#### /class ####
