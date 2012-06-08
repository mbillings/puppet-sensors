# ===Class: sensors
# 
# Installs and configures the baseboard management controller on physical hardware
#
class sensors::ipmi {	

if ($operatingsystemrelease >= 6) 	{ $rpms = ["ipmitool"] }
else 					{ $rpms = ["OpenIPMI-tools"] }

package { $rpms: ensure => installed, }

# loads ipmi kernel modules, runs tool, and sends to zabbix
file { "/etc/zabbix/ipmi.sh":
	path	=> "/etc/zabbix/ipmi.sh",
	owner	=> "root",
	group	=> "root",
	mode	=> "0750",
	content => template("sensors/ipmi.sh"),
	require => Package[$rpms],
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
	path	=> "/sbin/:/usr/sbin/:/bin/:/usr/bin/",
	onlyif	=> 'test `chkconfig --list | grep -i ipmi | grep \:on | wc -l` -eq 0'
     }

# set root user pass, null user pass, and community string
exec { "set_pass_and_community_string":
	command => "ipmitool lan set 1 password 1T1ger1mu.1 && ipmitool user set password 2 alphadog && ipmitool lan set 1 snmp CSGLINUX",
	path 	=> "/sbin/:/usr/sbin/:/bin/:/usr/bin/",
	onlyif	=> 'test `/etc/init.d/ipmievd status 2>/dev/null | grep -i running | wc -l` -eq 1 && test `ipmitool lan print | grep CSGLINUX | wc -l` -eq 0'
     }

# here be future sol configuration

#

# Order of operations	
	File["/etc/zabbix/ipmi.sh"] -> Cron["ipmi.sh_cron"] -> Exec["chkconfig_ipmievd_on"] -> Exec["set_pass_and_community_string"]
}
