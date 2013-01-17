puppet-sensors
==============

BMC/IPMI and lm_sensors

Sensors is categorized as configuration and mamagement for Baseboard Management Console / Intelligent Platform Management Interface (BMC/IPMI), and Linux Hardware Monitoring (lm_sensors). These applications poll information from hardware on many physical machines. 

This Puppet module automates the additional configuration required to get them running, and includes the option of sending metrics to a reporting instance such as Zabbix. It was tested on Dell (BMC/IPMI) and Supermicro (lm_sensors) with RHEL5 and 6 (x86_64) OSes. Information on each package can be found at http://openipmi.sourceforge.net, http://ipmitool.sourceforge.net, and http://lm-sensors.org.

Fields of interest include temperature, voltage, wattage, amperage, fan speed, hardware presence/capabilities, 
along with some other fields that aren't really important or don't always return information.

Here is an example of ipmitool implemented on a Dell R900. Units were dynamically named by ipmitool.

![IPMItool on a Dell R900](http://github.com/mbillings/puppet-sensors/pics/ipmi_zabbix_r900.jpg "IPMItool on a Dell R900")

Over two weeks, it becomes easier to see averages and trending.

![IPMItool over 2 weeks on a Dell R900](http://github.com/mbillings/puppet-sensors/pics/ipmi_zabbix2weekgraphs_r900.jpg "Values for IPMItool over 2 weeks")

BMC/IPMI also allows OS-independent console access to hardware-layer controls, providing invaluable management 
commands such as <power reset> to remotely hard-reset a kernel-panicked machine, and 
<delloem powermonitor powerconsumptionhistory> (if you have a Dell machine).

See files/ipminotes.txt for field explanation and more commands.
