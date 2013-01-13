# ===Class: sensors
#
# This module manages files and scripts related to the Baseboard Management 
# Console and Intelligent Platform Management Interface hardware polling
# application, or Linux Hardware Monitoring for other devices. 
#
# The application probes hardware for temperature, voltage, wattage, 
# amperage, fan speed, hardware presence/capabilities, and some other things
# that aren't really important.
#
# BMC/IPMI also allows OS-independent console access to hardware-layer controls,
# providing invaluable management controls such as power on (provided the 
# machine is receiving some form of power) and reset (handy for kernel panics).
#
# See files/ipminotes.txt for more commands.
#
# ===Parameters: 
#
# ===Actions:
#
# Sets up physical machines for hardware polling and reporting.
# Configures console access for hardware-layer controls.
#
# ===Requires:
#
# facter, foreman, zabbix 
# Note: Due to how this class was set up to use facter variables, all 
#       parameterized variables have been only set once in scripts
#       if you would prefer to not use facter variables.
#
# ===Sample Usage:
#
# Include class in host or Foreman hostgroup profile.
#
# ===Notes:
#
# This has only been tested on Dell and Supermicro hardware with 
# Red Hat Enterprise Linux >= 5.x
#
# In our environment, we only have three types of hardware manufacturers:
# Dell, VMware, and Supermicro. Out of those three, there were only two types
# of packages to choose from: lm or ipmi (doesn't make sense to track VMware). 
#
# Thus, this module was originally a fire-n-forget blanket apply with
# if/then/else statements for deployment convenience. 
#
class sensors
(
  $facter_reporting_class  = $sensors::params::facter_reporting_class,
  $facter_reporting_sender = $sensors::params::facter_reporting_sender,
  $facter_reporting_server = $sensors::params::facter_reporting_server,
  $key                     = $sensors::params::key,
  $key_last_sel            = $sensors::params::key_last_sel,
  $key_ipmi_status         = $sensors::params::key_ipmi_status,
  $lm_package              = $sensors::params::lm_package,
  $lm_script               = $sensors::params::lm_script,
  $ipmi_group              = $sensors::params::ipmi_group,
  $ipmi_pass_lan           = $sensors::params::ipmi_pass_lan,
  $ipmi_pass_user          = $sensors::params::ipmi_pass_user,
  $ipmi_package5           = $sensors::params::package5,
  $ipmi_package6           = $sensors::params::package6,
  $ipmi_script             = $sensors::params::script,
  $log                     = $sensors::params::log,
  $path                    = $sensors::params::path,
  $reporting_api_url       = $sensors::params::reporting_api_url,
  $reporting_auth          = $sensors::params::reporting_auth,
  $reporting_port          = $sensors::params::reporting_port,
) 

inherits sensors::params
{
    include sensors::config 
}
