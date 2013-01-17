puppet-sensors
==============

BMC/IPMI and lm_sensors

Sensors is categorized as configuration and mamagement for Baseboard Management Console / Intelligent Platform Management Interface (BMC/IPMI), 
and Linux Hardware Monitoring (lm_sensors). These applications poll information from hardware on many physical machines. 

Fields of interest include temperature, voltage, wattage, amperage, fan speed, hardware presence/capabilities, 
along with some other fields that aren't really important or don't always return information.
 
BMC/IPMI also allows OS-independent console access to hardware-layer controls, providing invaluable management 
commands such as <power reset> to remotely hard-reset a kernel-panicked machine, and 
<delloem powermonitor powerconsumptionhistory> (if you have a Dell machine).
 
See files/ipminotes.txt for field explanation and more commands.
