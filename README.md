puppet-sensors
==============

BMC/IPMI and lm_sensors

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
