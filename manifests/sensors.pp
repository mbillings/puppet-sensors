# ===Class: sensors::lm
# 
# Installs and configures the Linux Management Sensors package and loads necessary kernel modules
#
class sensors::lm {	

$rpms = ["lm_sensors"] 

package { $rpms: ensure => installed, }

file { "sensors.sh":
	path	=> "/etc/zabbix/sensors.sh",
	owner	=> "root",
	group	=> "root",
	mode	=> "0750",
	content => template("bmc/sensors.sh"),
	require => Package[$rpms],
     } 

# set a cron job to poll the server's sensors every minute
cron { "poll_sensors":
	ensure  => present,
	command => "nice -10 /etc/zabbix/sensors.sh",
	user    => "root",
	minute  => "*/1",
     }
	
	File["sensors.sh"] -> Cron["poll_sensors"]
}
