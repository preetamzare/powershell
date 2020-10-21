#variables to be defined
$vcenter="your vcenter name"
$vmhostname="put your vmhost name"
$DomainName = "your domain name"
$dnservers=@()
$dnservers += "x.x.x.x"
$dnservers += "x.x.x.x" 

Connect-VIServer -Server $vcenter -Force

$esxihostusingip = Get-VMHost -Name $vmhostname
#set vmhostname

$name = $vmhostname
$esxihostname = Get-EsxCli -VMHost $vmhostname

$esxihostname.system.hostname.get()
$esxihostname.system.hostname.set($DomainName,$null,$name)

$esxihostname.system.wbem.Get()
#$esxihostname.system.wbem.set

Get-VMHost -Name $esxihostusingip | Get-VMHostNetwork | Set-VMHostNetwork -DnsAddress $dnservers
Get-VMHost $esxihostusingip | Add-VMHostNtpServer -NtpServer 192.168.125.9, 192.168.125.200
Get-VMHostNtpServer -VMHost $esxihostusingip

#start the NTP service 

$NTPService=Get-VMHostService -VMHost $esxihostusingip | where{$_.Key -eq "ntpd"}
if(!$NTPService.Running){
Start-VMHostService -HostService $NTPService
}

#Configure NTP Service automatic
if($NTPService.Policy -eq "off"){
Write-Host $NTPService.Policy
$NTPService | Set-VMHostService -Policy "on"
}



#disable salting & Disable large paging

Set-VMHostAdvancedConfiguration -VMHost $esxihostusingip -Name Mem.ShareForceSalting -Value 0 
Set-VMHostAdvancedConfiguration -VMHost $esxihostusingip -Name Mem.AllocGuestLargePage -Value 0 

#check salting value
Get-VMhostAdvancedConfiguration -VMHost $esxihostusingip -Name Mem.ShareForceSalting
Get-VMhostAdvancedConfiguration -VMHost $esxihostusingip -Name Mem.AllocGuestLargePage

#set esxi timeout

Get-VMHost $esxihostusingip | Get-AdvancedSetting -Name 'UserVars.ESXiShellInteractiveTimeOut' | Set-AdvancedSetting -Value "300" -Confirm:$false
Get-VMHost $esxihostusingip | Get-AdvancedSetting -Name UserVars.ESXiShellTimeOut | Set-AdvancedSetting -Value "600" -Confirm:$false


#change the power policy to high

(Get-View (Get-VMHost -Name $esxihostusingip| Get-View).ConfigManager.PowerSystem).ConfigurePowerPolicy(1)

#see the vmnic0 and vmnic1 are added to vswitch0
#Configure vMotion

$vs = Get-VirtualSwitch -Name "vswitch0" -VMHost $esxihostusingip
$vmotionpg = New-VirtualPortGroup -Name VMOTION-10 -VirtualSwitch $vs -VLanId 10
$pg = Get-VirtualPortGroup -Name $vmotionpg -VirtualSwitch $vs
New-VMHostNetworkAdapter -VMHost $esxihostusingip -PortGroup $pg -VirtualSwitch $vs -IP 10.10.10.151 -SubnetMask 255.255.255.0 -VMotionEnabled:$true -Mtu 9000

New-VirtualPortGroup -Name vCenter-Manage -VirtualSwitch $vs -VLanId 130


# configure syslogging

Get-AdvancedSetting -Entity (Get-VMHost -Name $esxihostusingip) -Name "Syslog.global.logDir" | Set-AdvancedSetting -Value "[LOCAL_RZ2-CLU01-NODE12] /syslogs"
Get-AdvancedSetting -Entity (Get-VMHost -Name $esxihostusingip) -Name "Syslog.global.logDirUnique" | Set-AdvancedSetting -Value $True


Get-AdvancedSetting -Entity (Get-VMHost -Name $esxihostusingip) -Name "Syslog.global.logDir" | Select Entity, Name, Value
Get-AdvancedSetting -Entity (Get-VMHost -Name $esxihostusingip) -Name "Syslog.global.logDirUnique" | Select Entity, Name, Value
#Get-AdvancedSetting -Entity (Get-VMHost -Name $esxihostusingip) -Name "Syslog.global.logHost" | Select Entity, Name, Value

# configure remote dump


$esxihostname.system.coredump.network.set($null,"vmk0",$null,"192.168.130.161",6500)
$esxihostname.system.coredump.network.set($true)
$esxihostname.system.coredump.network.Get()



# add esxi to active directory
Get-VMHost $esxihostusingip | Get-AdvancedSetting -Name Config.HostAgent.plugins.hostsvc.esxAdminsGroup



#put credentials without domain e.g. itkadmin9 but NOT emp\itkadmin9
$mycred=Get-Credential
Get-VMHost $esxihostusingip | Get-VMHostAuthentication | Set-VMHostAuthentication -JoinDomain -Domain $DomainName -Credential $mycred




#dell best practices

#autoremoveonPDL is default value is 1
Get-AdvancedSetting -Entity (Get-VMHost -Name $esxihostusingip) -name Disk.AutoremoveOnPDL

Get-AdvancedSetting -Entity $esxihostusingip -Name VMKernel.Boot.terminateVMonPDL | Set-AdvancedSetting -Value $true

# Add ESXi host in solarwinds





# reference https://kb.vmware.com/s/article/1026538
# reference http://vbrainstorm.com/investigating-and-setting-syslog-settings-for-esxi-with-powercli/