# ===Class: sensors::params
#
# Modify variables as necessary

class sensors::params
{
  $facter_reporting_class  = 'zabbix-agent'
  $facter_reporting_sender = 'which_zsender'
  $facter_reporting_server = 'zabbix_server'
  $key                     = 'sensors_'
  $key_last_sel            = 'sensors_last_sel'
  $key_ipmi_status         = 'sensors_ipmi_status'
  $lm_package              = 'lm_sensors'
  $lm_script               = 'lm_script.sh'
  $ipmi_group              = 'LINUX_GUISE'
  $ipmi_pass_lan           = 'omgp4$w33r9?'
  $ipmi_pass_user          = 'roflp4$w33r9?'
  $ipmi_package5           = 'OpenIPMI-tools'
  $ipmi_package6           = 'ipmitool'
  $ipmi_script             = 'ipmi_script.sh'
  $log                     = '/tmp/sensors_log'
  $path                    = '/usr/local/sbin'
  $reporting_api_url       = 'http://zabbix.host.domain/zabbix/api_jsonrpc.php'
  $reporting_auth          = '3ut8tzru47doslauc900475hg88qbat3'
  $reporting_port          = '10051'
}
