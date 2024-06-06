#=============================================================================================================================
#
# Script Name:     Bitlocker-Lost-Device.ps1
# Description:     Script requires the lost device to be on and have a network connection to deploy via a remote agent. Intune 
#				   Is ideal because the script can be assigned and will deploy if the system checks in
# Notes:           
# Author: 		   Georgia Schafer
# Date:			   20240605
# WARNING - SCRIPT WILL REMOVE BITLOCKER KEYS FROM TPM AND ROTATE RECOVERY PASSWORD - USE EXTREME CAUTION
#
#=============================================================================================================================

# Define Variables
$results = ""

try
{
	$volumes = Get-BitLockerVolume | Where {$_.ProtectionStatus -eq "On"}
	foreach ($volume in $volumes) {
		$volume.keyprotector | Where {$_.keyprotectortype -eq "Tpm"} | %{$results += Remove-BitLockerKeyProtector -MountPoint $volume.MountPoint -KeyProtectorId $_.keyprotectorid}
		$volume.keyprotector | Where {$_.keyprotectortype -eq "RecoveryPassword"} | %{
			$results += Remove-BitLockerKeyProtector -MountPoint $volume.MountPoint -KeyProtectorId $_.keyprotectorid
			$results += Add-BitLockerKeyProtector -MountPoint $volume.MountPoint -RecoveryPasswordProtector -WarningAction SilentlyContinue
			$results += BackupToAAD-BitLockerKeyProtector -MountPoint $volume.MountPoint -KeyProtectorId $_.keyprotectorid
		}
	}
	if (($results -ne $null)){
		Return $results
		exit 0
    }
    else{
        #Nothing happened
		#Below necessary for Intune as of 10/2019 will only remediate Exit Code 1
        Write-Host "No-Bitlocker-Action"        
        exit 1
    }   
}
catch{
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}
