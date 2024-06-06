#=============================================================================================================================
#
# Script Name:     Remediate-Intune-Device-Wipe.ps1
# Description:     Execute device wipe using Intune remediation. You could set this as the detection script and avoid the 
#				   redundant detection script. The main reason to setup as a remediation script is to take advantage of
#				   the Run Remediation command available in Intune to run the script on demand.
# Notes:           https://learn.microsoft.com/en-us/mem/intune/fundamentals/powershell-scripts-remediation
#				   https://call4cloud.nl/2022/04/mamma-mia-here-we-wipe-again/
#				   https://call4cloud.nl/wp-content/uploads/2022/03/wipeitall.zip
# Author: 		   Georgia Schafer
# Date:			   20240605
# WARNING - SCRIPT WILL FORMAT SYSTEM IT IS RUN ON - USE EXTREME CAUTION
#
#=============================================================================================================================

# Define Variables
$results = ""

try
{
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

		Start-Process -FilePath "powershell.exe" -windowstyle hidden -ArgumentList '-ExecutionPolicy Bypass -File "c:\programdata\customscripts\reset.ps1"'
        Return $results
        exit 0
    }
    else{
        #No matching scheduled task
		#Below necessary for Intune as of 10/2019 will only remediate Exit Code 1
        Write-Host "No-Task"        
        exit 1
    }   
}
catch{
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}
