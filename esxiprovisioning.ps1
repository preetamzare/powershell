<# Purpose of the script is to provision a new ESXI host to vcenter.
It is simple as i can get it. It should be run as single file but line by line (F8) option

#>

#variables to be defined
$vcenter="your vcenter name or ip address"
$vmhostname="put your vmhost name or ip address"
$DomainName = "your domain name"
$dnserversip=@()
$dnserversip += "x.y.z.a"
$dnserversip += "x.y.z.b"
$ntpservers=@()
$ntpservers += "a.b.c.x"
$ntpservers += "a.b.c.y"
$vmotionIP = "i.j.k.l"
$vmotionvlan = "VLAN ID"
$ESXiLocalDatastore = "datastorename"

Connect-VIServer -Server $vcenter -Force

$esxihostusingip = Get-VMHost -Name $vmhostname
#set vmhostname

$name = $vmhostname
$esxihostname = Get-EsxCli -VMHost $vmhostname

$esxihostname.system.hostname.get()
$esxihostname.system.hostname.set($DomainName,$null,$name)

$esxihostname.system.wbem.Get()
#$esxihostname.system.wbem.set

Get-VMHost -Name $esxihostusingip | Get-VMHostNetwork | Set-VMHostNetwork -DnsAddress $dnserversip
Get-VMHost $esxihostusingip | Add-VMHostNtpServer -NtpServer $ntpservers
Get-VMHostNtpServer -VMHost $esxihostusingip

#start the NTP service 
$NTPService=Get-VMHostService -VMHost $esxihostusingip | where-object-object{$_.Key -eq "ntpd"}
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
#work is pending here

#Configure vMotion
$vs = Get-VirtualSwitch -Name "vswitch0" -VMHost $esxihostusingip
$vmotionpg = New-VirtualPortGroup -Name VMOTION-10 -VirtualSwitch $vs -VLanId $vmotionvlan
$pg = Get-VirtualPortGroup -Name $vmotionpg -VirtualSwitch $vs
New-VMHostNetworkAdapter -VMHost $esxihostusingip -PortGroup $pg -VirtualSwitch $vs -IP $vmotionIP -SubnetMask 255.255.255.0 -VMotionEnabled:$true -Mtu 9000

# special port for vCenter as we do not want to keep vCenter on DVSwitch
New-VirtualPortGroup -Name vCenter-Manage -VirtualSwitch $vs -VLanId $vcentervlan


# configure syslogging to local datastore only
Get-AdvancedSetting -Entity (Get-VMHost -Name $esxihostusingip) -Name "Syslog.global.logDirUnique" | Set-AdvancedSetting -Value $true
Get-AdvancedSetting -Entity (Get-VMHost -Name $esxihostusingip) -Name "Syslog.global.logDir" | Set-AdvancedSetting -Value $ESXiLocalDatastore



Get-AdvancedSetting -Entity (Get-VMHost -Name $esxihostusingip) -Name "Syslog.global.logDir" | select-object Entity, Name, Value
Get-AdvancedSetting -Entity (Get-VMHost -Name $esxihostusingip) -Name "Syslog.global.logDirUnique" | select-object Entity, Name, Value
#Get-AdvancedSetting -Entity (Get-VMHost -Name $esxihostusingip) -Name "Syslog.global.logHost" | select-object Entity, Name, Value

# configure remote dump
$esxihostname.system.coredump.network.set($null,"vmk0",$null,$vcenter,6500)
$esxihostname.system.coredump.network.set($true)
$esxihostname.system.coredump.network.Get()

# add esxi to active directory
Get-VMHost $esxihostusingip | Get-AdvancedSetting -Name Config.HostAgent.plugins.hostsvc.esxAdminsGroup

#put credentials without domain e.g.  NOT domain\username
$mycred=Get-Credential
Get-VMHost $esxihostusingip | Get-VMHostAuthentication | Set-VMHostAuthentication -JoinDomain -Domain $DomainName -Credential $mycred

#dell SC 5200 best practices
#autoremoveonPDL is default value is 1, i need to just check if it is 1
Get-AdvancedSetting -Entity (Get-VMHost -Name $esxihostusingip) -name Disk.AutoremoveOnPDL
Get-AdvancedSetting -Entity $esxihostusingip -Name VMKernel.Boot.terminateVMonPDL | Set-AdvancedSetting -Value $true

# Add ESXi host in your monitoring systems





# reference https://kb.vmware.com/s/article/1026538
# reference http://vbrainstorm.com/investigating-and-setting-syslog-settings-for-esxi-with-powercli/