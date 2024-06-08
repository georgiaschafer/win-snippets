#=============================================================================================================================
#
# Script Name:     Bitlocker-Lost-Device.ps1
# Description:     Script requires the lost device to be on and have a network connection to deploy via a remote agent. Intune 
#				   Is ideal because the script can be assigned and will deploy if the system checks in
# Notes:           
# Author: 		   Georgia Schafer
# Date:			   20240605
# WARNING - USE AT YOUR OWN RISK!
#	SCRIPT WILL REMOVE BITLOCKER KEYS FROM TPM AND ROTATE RECOVERY PASSWORD - USE EXTREME CAUTION
#
#=============================================================================================================================

# Define Variables
$results = ""

try
{
	$volumes = Get-BitLockerVolume | Where {$_.ProtectionStatus -eq "On"}
	foreach ($volume in $volumes) {
 		#rotate the recovery password
   		$results += & manage-bde -protectors -delete -type RecoveryPassword $volume.MountPoint
   		$results += & manage-bde -protectors -add -RecoveryPassword $volume.MountPoint
     		$rpID = ((Get-BitLockerVolume -MountPoint $volume.MountPoint).KeyProtector | Where {$_.KeyProtectorType -eq 'RecoveryPassword'}).KeyProtectorId
       		#backup to AAD, uncomment next line if desired
     		#$results += & manage-bde -protectors -aadbackup $volume.MountPoint -id $rpID
       		#delete TPM keys
 		$results += & manage-bde -protectors -delete -type TPM $volume.MountPoint
	}
	if (($results -ne $null)){
 		$results += & shutdown /s /t 20
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
