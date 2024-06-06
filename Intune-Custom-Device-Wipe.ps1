#=============================================================================================================================
#
# Script Name:     Intune-Custom-Device-Wipe.ps1
# Description:     Adds customization to the Intune Device Wipe process to run a diskpart clean all command.
# Notes:           Modified from Rudy Ooms' wipeitall code: https://call4cloud.nl/2022/04/mamma-mia-here-we-wipe-again/
#				   https://call4cloud.nl/wp-content/uploads/2022/03/wipeitall.zip
# Author: 		   Georgia Schafer
# Date:			   20240531
# WARNING - SCRIPT WILL FORMAT SYSTEM IT IS RUN ON - USE EXTREME CAUTION
#
#=============================================================================================================================

#######################################################
# create enablecustomizations.cmd in the oem folder   #
#######################################################

$path = "C:\recovery\oem"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

$content = @'
diskpart /s c:\recovery\oem\wipeitall.txt
'@

$MyPath = "c:\recovery\oem\CommonCustomizations.cmd"
#this file needs to be UTF8, but not with the BOM option, using New-Item will do this
$null = New-Item -Force $MyPath -Value $content

#######################################################
# create wipeitall.txt   #
# Updated to do all attached drives #
# WARNING - attached USB mass storage drives WILL BE WIPED #
#######################################################
$disks = Get-Disk
$content = ""
foreach ($disk in $disks) {
	if ($disk.PartitionStyle -ne "raw") {
	$content += @'
select disk diskNum
clean all

'@
	}
	$content = $content.replace("diskNum",$disk.Number)
}
$content = $content.substring(0,$content.length -1)
Out-File -FilePath c:\recovery\oem\wipeitall.txt  -Encoding utf8 -Force -InputObject $content -Confirm:$false

#######################################################
# create ResetConfig.xml in the oem folder   #
#######################################################
$content2 = @'
<?xml version="1.0" encoding="utf-8"?>
<!-- ResetConfig.xml -->
<Reset>
<Run Phase="FactoryReset_AfterDiskFormat">
<Path>CommonCustomizations.cmd</Path>
<Duration>2</Duration>
</Run>
<Run Phase="FactoryReset_AfterImageApply">
<Path>CommonCustomizations.cmd</Path>
<Duration>2</Duration>
</Run>
<SystemDisk>
<DiskpartScriptPath>wipeitall.txt</DiskpartScriptPath>
<MinSize>75000</MinSize>
<WindowsREPartition>1</WindowsREPartition>
<WindowsREPath>Recovery\WindowsRE</WindowsREPath>
<OSPartition>4</OSPartition>
<RecoveryImagePartition>5</RecoveryImagePartition>
<RecoveryImagePath>RecoveryImage</RecoveryImagePath>
<RestoreFromIndex>1</RestoreFromIndex>
<RecoveryImageIndex>1</RecoveryImageIndex>
</SystemDisk>
</Reset>
'@

$MyPath = "c:\recovery\oem\ResetConfig.xml"
#this file needs to be UTF8, but not with the BOM option, using New-Item will do this
$null = New-Item -Force $MyPath -Value $content2

#######################################################
# reset wmi bridge  #
#######################################################

$reset =
@'
$namespaceName = "root\cimv2\mdm\dmmap"
$className = "MDM_RemoteWipe"
$methodName = "doWipeProtectedMethod"
$session = New-CimSession
$params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
$param = [Microsoft.Management.Infrastructure.CimMethodParameter]::Create("param", "", "String", "In")
$params.Add($param)
$instance = Get-CimInstance -Namespace $namespaceName -ClassName $className -Filter "ParentID='./Vendor/MSFT' and InstanceID='RemoteWipe'"
$session.InvokeMethod($namespaceName, $instance, $methodName, $params)
'@

New-Item -Path c:\programdata\customscripts -ItemType Directory -Force -Confirm:$false | out-null
Out-File -FilePath $(Join-Path $env:ProgramData CustomScripts\reset.ps1) -Encoding unicode -Force -InputObject $reset -Confirm:$false

#If running from Intune, use Start-Process - uncomment next line
#Start-Process -FilePath "powershell.exe" -windowstyle hidden -ArgumentList '-ExecutionPolicy Bypass -File "c:\programdata\customscripts\reset.ps1"'

#If running in an admin user context, use this instead - uncomment remaining lines
#$taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument '-NoProfile -ExecutionPolicy Bypass -File "c:\programdata\customscripts\reset.ps1"'
#$taskPrincipal = New-ScheduledTaskPrincipal -UserId "System" -LogonType ServiceAccount -RunLevel Highest
#$taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DisallowDemandStart -DisallowHardTerminate -DontStopIfGoingOnBatteries
#Register-ScheduledTask 'Intune-Data-Wipe' -Action $taskAction -Principal $taskPrincipal -Settings $tasksettings -ErrorAction Ignore
#$wipeTask = Get-ScheduledTask 'Intune-Data-Wipe' -ErrorAction Ignore
#Start-ScheduledTask $wipeTask.TaskName
