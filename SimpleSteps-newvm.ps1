$localadminpassword="Secret!2geheim"
$localuserpassword="Simple!8wort"
$FullName="First Name and Last Name"
$username="firstname.lastname"
$servername="VMName"
$GermanyTZ0="W. Europe Standard Time"
$IPAddres="10.10.10.90"
$subnetmask="24"
$dgw="10.10.10.1"
$dnservers=@("8.8.8.8","4.4.4.4")

# change the admin password from default and set it to non-expiring
$adminpassword=ConvertTo-SecureString -String $localadminpassword -AsPlainText -Force
$adminuser=get-localuser -Name administrator
Set-LocalUser -AccountNeverExpires:$true -Name Administrator
$adminuser | Set-LocalUser -Password $adminpassword

# new user with local admin permissions
$userpassword=ConvertTo-SecureString -String $localuserpassword -AsPlainText -Force
New-LocalUser -Name $username -Password $userpassword -AccountNeverExpires -FullName $FullName | Set-LocalUser -PasswordNeverExpires $false
$user=Get-LocalUser -Name $username
Add-LocalGroupMember -Group "Administrators" -Member $user

# rename computer
Rename-Computer -NewName $servername

# set timezone
Set-TimeZone -Name $GermanyTZ0

# enable icmp
netsh firewall set icmpsetting 8

# Configure IP Address
New-NetIPAddress -IPAddress $IPAddres -PrefixLength $subnetmask -DefaultGateway $dgw -InterfaceIndex (Get-NetAdapter).InterfaceIndex
Set-DnsClientServerAddress -ServerAddresses $dnservers -InterfaceIndex (Get-NetAdapter).InterfaceIndex



# Renew license
DISM /online /Get-TargetEditions
dism /online /set-edition:ServerDatacenter /productkey:CB7KF-BWN84-R7R2Y-793K2-8XDDG /accepteula
slmgr /skms emp-sql-bak01.emp.mailorder.dom:1688
slmgr /ato – initiate activation