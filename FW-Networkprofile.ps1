
# Change the network profile
# When you change the virtual port group on VMware side and there is firewall enabled on Windows, sometime it changes Firewall profile to public. Hence your public firewall rules applies which are more restrictive than private.
# This is the simplest script to avoid.
 
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private