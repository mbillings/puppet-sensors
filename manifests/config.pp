# ===Class: sensors::config.pp
#
# Sets up BMC/IPMI or lm_sensors on physical hosts.
#
# See the init for more info.
#
class sensors::config
{
  # start with a naming convention 
  if $manufacturer =~ /^VMware/ { } # NOOP
  elsif ( $manufacturer == "Supermicro" ) # Supermicro X7SLA 
  { 
    $apptype = '${sensors::lm_script}' 
    $rpm     = '${sensors::lm_package}'
  }
  else # Dell
  { 
    $apptype = '${sensors::ipmi_script}'
    if ($operatingsystemrelease >= 6) { $rpm = ['${sensors::ipmi_package6}'] }
    else                              { $rpm = ['${sensors::ipmi_package5}'] } 
  }


	$rpms = ["$rpm"] 
	package { $rpms: ensure => installed, }
	
    # for convenience, this is done by root 
    # however, a user could be configured to run this with sudo access
	file { "$apptype script":
           path    => "'${sensors::path}'/$apptype",    
           owner   => "root",
           group   => "root",
           mode    => "0700", 
           content => template("sensors/$apptype"),
           require => Package[$rpms],
	     } 


	# cron to poll the hardware, 1 and 2 are redirected to null to avoid cron email spam
	cron { "$apptype cron":
           ensure  => present,
           command => "if [ `ps aux | grep $apptype | grep -v grep | wc -l` -eq 0 ]; then `nice -10 '${sensors::path}'/$apptype 1>/dev/null 2>/dev/null`; fi 1>/dev/null 2>/dev/null",
           user    => "root",
           minute  => "*/2",
	     }
  
    if $apptype != /^lm_sensors/
    {
	  # set ipmi time
	  exec { "set_ipmi_time":
             command => 'ipmitool sel time set "`date +%m\/%d\/%Y\ %H:%M:%S`"',
             path    => "/sbin/:/usr/sbin/:/bin/:/usr/bin/",
             onlyif  => 'ipmitime=$( ipmitool sel time get | sed s/\\///g | sed s/\://g | sed s/\ //g ) && datetime=$( date +%m%d%Y%H%M%S ) && test `if [ "${ipmitime}" -ne "${datetime}" ]; then echo 1; fi` -eq 1'
           }


      # set root user pass, null user pass, and community string
      exec { "set_pass_and_community_string":
             command => "ipmitool lan set 1 password '${sensors::ipmi_pass_lan}' && ipmitool user set password 2 '${sensors::ipmi_pass_user}' && ipmitool lan set 1 snmp '${sensors::ipmi_group}'",
             path    => "/sbin/:/usr/sbin/:/bin/:/usr/bin/",
             onlyif  => 'test `ipmitool lan print | grep CSGLINUX | wc -l` -eq 0'
           }
	
	  # here be future sol configuration when networking allows us 10.0.0.0/16 IPs for all boxen
    }
}
