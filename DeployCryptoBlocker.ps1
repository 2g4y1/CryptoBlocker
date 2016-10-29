# DeployCryptoBlocker.ps1
#
################################ Notification Options ################################
$Script = New-Object psobject
$Script | Add-Member -NotePropertyName "Directory" -NotePropertyValue "C:\FSRMScripts" #Modify this the first time you run it
$Script | Add-Member -NotePropertyName "EmailRecipient" -NotePropertyValue "email@domain.com" #Modify this the first time you run it - will be TO in Email
$Script | Add-Member -NotePropertyName "EmailSender" -NotePropertyValue "email@domain.com" #Modify this the first time you run it - will be FROM in Email
#Make sure you've set your SMTP server in FSRM as well

if(!(Test-Path $PSScriptRoot)){#Create Directory if there is no current directory
    New-Item -ItemType Directory -Path $Script.Directory
} else { $Script.Directory = $PSScriptRoot } 

$Script | Add-Member -NotePropertyName "EventNotification" -NotePropertyValue "$($Script.Directory)\EventNotification.txt"
$Script | Add-Member -NotePropertyName "EmailNotification" -NotePropertyValue "$($Script.Directory)\EmailNotification.txt"
$Script | Add-Member -NotePropertyName "Script" -NotePropertyValue "$($Script.Directory)\DeployCryptoBlocker.ps1"
$Script | Add-Member -NotePropertyName "TaskName" -NotePropertyValue "FSRM DeployCryptoBlocker Updater"

if(!(Test-Path $Script.EventNotification)){#Create the Event Notification template
    New-Item -ItemType File -Path $Script.EventNotification
}
$EventNote = 'Notification=e','RunLimitInterval=5','EventType=Warning','Message=User [Source Io Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in the [Violated File Group] file group, which is not permitted on the server.'
Add-Content -Value $EventNote -Path $Script.EventNotification -Force

if(!(Test-Path $Script.EmailNotification)){#Create the Email Notification template
    New-Item -ItemType File -Path $Script.EmailNotification
} else { #If the file exists, get email addresses from the file
    $OldEmailNotification = get-content $script.EmailNotification
    $script.EmailRecipient = $OldEmailNotification[2].Substring(3)
    $Script.EmailSender = $OldEmailNotification[3].Substring(5)
}
$EmailNote = "Notification=m","RunLimitInterval=5","To=$($Script.EmailRecipient)","From=$($Script.EmailSender)","Subject=Unauthorized file from the [Violated File Group] file group detected","Message=User [Source Io Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in the [Violated File Group] file group, which is not permitted on the server."
Add-Content -Value $EmailNote -PassThru $Script.EmailNotification -Force

################################ Functions ################################

function ConvertFrom-Json20([Object] $obj)
{
    Add-Type -AssemblyName System.Web.Extensions
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    return ,$serializer.DeserializeObject($obj)
}

Function New-CBArraySplit {

    param(
        $extArr,
        $depth = 1
    )

    $extArr = $extArr | Sort-Object -Unique

    # Concatenate the input array
    $conStr = $extArr -join ','
    $outArr = @()

    # If the input string breaks the 4Kb limit
    If ($conStr.Length -gt 4096) {
        # Pull the first 4096 characters and split on comma
        $conArr = $conStr.SubString(0,4096).Split(',')
        # Find index of the last guaranteed complete item of the split array in the input array
        $endIndex = [array]::IndexOf($extArr,$conArr[-2])
        # Build shorter array up to that indexNumber and add to output array
        $shortArr = $extArr[0..$endIndex]
        $outArr += [psobject] @{
            index = $depth
            array = $shortArr
        }

        # Then call this function again to split further
        $newArr = $extArr[($endindex + 1)..($extArr.Count -1)]
        $outArr += New-CBArraySplit $newArr -depth ($depth + 1)
        
        return $outArr
    }
    # If the concat string is less than 4096 characters already, just return the input array
    Else {
        return [psobject] @{
            index = $depth
            array = $extArr
        }  
    }
}

################################ Functions ################################

# Add to all drives
$drivesContainingShares = Get-WmiObject Win32_Share | Select Name,Path,Type | Where-Object { $_.Type -eq 0 } | Select -ExpandProperty Path | % { "$((Get-Item -ErrorAction SilentlyContinue $_).Root)" } | Select -Unique
if ($drivesContainingShares -eq $null -or $drivesContainingShares.Length -eq 0)
{
    Write-Host "No drives containing shares were found. Exiting.."
    exit
}

Write-Host "The following shares needing to be protected: $($drivesContainingShares -Join ",")"

$majorVer = [System.Environment]::OSVersion.Version.Major
$minorVer = [System.Environment]::OSVersion.Version.Minor

Write-Host "Checking File Server Resource Manager.."

Import-Module ServerManager

if ($majorVer -ge 6)
{
    $checkFSRM = Get-WindowsFeature -Name FS-Resource-Manager

    if ($minorVer -ge 2 -and $checkFSRM.Installed -ne "True")
    {
        # Server 2012
        Write-Host "FSRM not found.. Installing (2012).."
        Install-WindowsFeature -Name FS-Resource-Manager -IncludeManagementTools
    }
    elseif ($minorVer -ge 1 -and $checkFSRM.Installed -ne "True")
    {
        # Server 2008 R2
        Write-Host "FSRM not found.. Installing (2008 R2).."
        Add-WindowsFeature FS-FileServer, FS-Resource-Manager
    }
    elseif ($checkFSRM.Installed -ne "True")
    {
        # Server 2008
        Write-Host "FSRM not found.. Installing (2008).."
        &servermanagercmd -Install FS-FileServer FS-Resource-Manager
    }
}
else
{
    # Assume Server 2003
    Write-Host "Other version of Windows detected! Quitting.."
    return
}

$fileGroupName = "CryptoBlockerGroup"
$fileTemplateName = "CryptoBlockerTemplate"
$fileScreenName = "CryptoBlockerScreen"

$webClient = New-Object System.Net.WebClient
$jsonStr = $webClient.DownloadString("https://fsrm.experiant.ca/api/v1/get")
$RawScript = $webClient.DownloadString("https://raw.githubusercontent.com/nexxai/CryptoBlocker/master/DeployCryptoBlocker.ps1")
$monitoredExtensions = @(ConvertFrom-Json20($jsonStr) | % { $_.filters })


if(!($Script.Script)){ #Save the script if it doesn't exist
    New-Item -ItemType File -Path $Script.Script
    Add-Content -Value $RawScript -Path $Script.Script -Force
} elseif(!((Get-content $Script.Script) -eq $RawScript)){ #Otherwise update it if it's different
    Add-Content -Value $RawScript -Path $Script.Script -Force
} else {}

#Create task event that will run the saved script Daily at 4AM -- but only if the update of DeployCryptoBlocker was successful
$TaskExists = Get-ScheduledTask | Where-Object {$_.Taskname -like $Script.TaskName}
if($TaskExists){
    Unregister-ScheduledTask -TaskName $script.TaskName #Remove task 
    $TaskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-noprofile -file `"$($Script.Script)`""
    $TaskTrigger = New-ScheduledTaskTrigger -At "4:00AM" -Daily
    $TaskPrincipal = New-ScheduledTaskPrincipal -UserId "LOCALSERVICE" -RunLevel Highest -LogonType ServiceAccount
    $Task = New-ScheduledTask -Action $TaskAction -Principal $TaskPrincipal -Trigger $TaskTrigger -Description "This updates the File System Resource Monitor file screen group for anti-cryptoware screening."
    Register-ScheduledTask $Script.TaskName -InputObject $Task
} else {
    if(!((Get-content $Script.Script) -eq $RawScript)){#Only update task if script has changed
        $TaskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-noprofile -file `"$($Script.Script)`""
        $TaskTrigger = New-ScheduledTaskTrigger -At "4:00AM" -Daily
        $TaskPrincipal = New-ScheduledTaskPrincipal -UserId "LOCALSERVICE" -RunLevel Highest -LogonType ServiceAccount
        $Task = New-ScheduledTask -Action $TaskAction -Principal $TaskPrincipal -Trigger $TaskTrigger -Description "This updates the File System Resource Monitor file screen group for anti-cryptoware screening."
        Register-ScheduledTask $Script.TaskName -InputObject $Task
    }
}

# Split the $monitoredExtensions array into fileGroups of less than 4kb to allow processing by filescrn.exe
$fileGroups = New-CBArraySplit $monitoredExtensions
ForEach ($group in $fileGroups) {
    $group | Add-Member -MemberType NoteProperty -Name fileGroupName -Value "$FileGroupName$($group.index)"
}

# Perform these steps for each of the 4KB limit split fileGroups
ForEach ($group in $fileGroups) {
    Write-Host "Adding/replacing File Group [$($group.fileGroupName)] with monitored file [$($group.array -Join ",")].."
    &filescrn.exe filegroup Delete "/Filegroup:$($group.fileGroupName)" /Quiet
    &filescrn.exe Filegroup Add "/Filegroup:$($group.fileGroupName)" "/Members:$($group.array -Join '|')"
}

Write-Host "Adding/replacing File Screen Template [$fileTemplateName] with Event Notification [$eventConfFilename] and Command Notification [$cmdConfFilename].."
&filescrn.exe Template Delete /Template:$fileTemplateName /Quiet
# Build the argument list with all required fileGroups
$screenArgs = 'Template','Add',"/Template:$fileTemplateName","/Add-Notification:E,$($Script.EventNotification)","/Add-Notification:M,$($Script.EmailNotification)" 
ForEach ($group in $fileGroups) {
    $screenArgs += "/Add-Filegroup:$($group.fileGroupName)"
}

&filescrn.exe $screenArgs

Write-Host "Adding/replacing File Screens.."
$drivesContainingShares | % {
    Write-Host "`tAdding/replacing File Screen for [$_] with Source Template [$fileTemplateName].."
    &filescrn.exe Screen Delete "/Path:$_" /Quiet
    &filescrn.exe Screen Add "/Path:$_" "/SourceTemplate:$fileTemplateName"
}