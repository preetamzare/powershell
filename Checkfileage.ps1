$Path = "C:\Windows\SysWOW64\config\systemprofile\AppData\Local\Microsoft\Windows\Temporary Internet Files\Content.IE5"
$Daysback = "-365"
$CurrentDate = Get-Date
$DatetoDelete = $CurrentDate.AddDays($Daysback)
Get-ChildItem $Path | Where-Object { $_.LastWriteTime -lt $DatetoDelete }

# to delete files del . /f /s /q