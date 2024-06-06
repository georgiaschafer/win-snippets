#=============================================================================================================================
#
# Script Name:     Intune-Custom-Device-Wipe-Detect.ps1
# Description:     Check for existance of scheduled task to run device wipe
# Notes:           https://learn.microsoft.com/en-us/mem/intune/fundamentals/powershell-scripts-remediation
#				   https://call4cloud.nl/2022/04/mamma-mia-here-we-wipe-again/
#				   https://call4cloud.nl/wp-content/uploads/2022/03/wipeitall.zip
# Author: 		   Georgia Schafer
# Date:			   20240605
# WARNING - SCRIPT WILL FORMAT SYSTEM IT IS RUN ON WHEN PAIRED WITH REMEDIATION SCRIPT - USE EXTREME CAUTION
#
#=============================================================================================================================

# Define Variables
$results = ""

try
{
    $results = Get-ScheduledTask 'Intune-Data-Wipe' -ErrorAction Ignore
    if (($results -ne $null)){
        #Scheduled task found
        Write-Host "Task-Found"
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
