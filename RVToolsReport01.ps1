# this checks today date and finds the file and give the output
$date=get-date
$filenamerv=$date.Date.ToString("yyyyMMdd")
$filepath="c:\rvtools\data\"

$VMInventory=Import-Csv $filepath+RVToolsInfo_$filenamerv.csv -Delimiter ";" | where{$_.Powerstate -eq "poweredOn"}
$RAMsum=0
$CPUsum=0
$PStorage=0
$UStorage=0

$VMInventory.memory | ForEach-Object {$RAMsum +=$_}
$VMInventory.CPUs | ForEach-Object {$CPUsum +=$_}
$VMInventory."Provisioned MB" | ForEach-Object {$PStorage +=$_}
$VMInventory."In Use MB" | ForEach-Object {$UStorage +=$_}

$SumGB=$RAMsum/(1024)
$SumGB2DP=[Math]::round($SumGB,2)

$PStorageGB=$PStorage/(1024*1024)
$PStorageGB2DP=[Math]::round($PStorageGB,2)


$UStorageGB=$UStorage/(1024*1024)
$UStorageGB2DP=[Math]::round($UStorageGB,2)



write-host total memory in TB is $SumGB2DP
write-host total VMs are ($VMInventory.VM).Count
write-host total Corecount is $CPUsum
write-host total Provisioned Storage is $PStorageGB2DP in TB
write-host total Consumed Storage is $UStorageGB2DP in TB