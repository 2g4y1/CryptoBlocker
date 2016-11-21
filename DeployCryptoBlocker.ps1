# DeployCryptoBlocker.ps1
#
################################ Notification Options ################################
$DCB = New-Object psobject
#1. Get the location that the configuration file will be saved in
Write-Host "Getting Configuration File Information"
Add-Type -AssemblyName System.Windows.Forms
$ConfigFolder = New-Object System.Windows.Forms.FolderBrowserDialog
Write-Host "Choose the folder in which to save the configuration information"
[void]$ConfigFolder.ShowDialog()
$DCB | Add-Member -NotePropertyName "Directory" -NotePropertyValue "$($ConfigFolder.SelectedPath)"
#1.a. Now that directory has been chosen, look for previous configuration
if(Test-Path "$($DCB.Directory)\DCBConfig.txt"){#If config file exists
    Write-Host "Configuration file found. Loading..."
    $DCB = Import-Csv -Path "$($DCB.Directory)\DCBConfig.txt" -Delimiter "`t"
}
Else{
#2. Get the email recipient for notification emails - screen for valid
while($EmailRecipient -notmatch "\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"){
$EmailRecipient = Read-Host -Prompt "Please enter the email address of that you want notification emails to be sent to."
}
$DCB | Add-Member -NotePropertyName "EmailRecipient" -NotePropertyValue "$EmailRecipient"
#3. Get the email sender for notification emails - screen for valid
while($EmailSender -notmatch "\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"){
$EmailSender = Read-Host -Prompt "Please enter the email address of that you want notification emails to be sent from."
}
$DCB | Add-Member -NotePropertyName "EmailSender" -NotePropertyValue "$EmailSender" 
#4. Get the SMTP server - Screen for either IP address or FQDN
while($SMTP -notmatch "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$" -and $SMTP -notmatch "(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63}\.?$)"){
$SMTP = Read-Host -Prompt "Please enter either the IP Address or Fully Qualified Domain Name of the SMTP Server you wish to use"
}
$DCB | Add-Member -NotePropertyName "SMTPServer" -NotePropertyValue "$SMTP"
#5. Set generic FSRM email from address
#5.a. First prompt if the user wants to use the same emails they entered earlier
$choiceTitle = "Setup Email for File Server Resource Manager"
$choiceMessage = "FSRM can have separate email addresses for general reporting. Do you want to use the emails you entered earlier?"
$choiceYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Uses the email addresses entered earlier for FSRM defaults"
$choiceNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Prompts you to enter email addresses for FSRM defaults"
$choiceOptions = [System.Management.Automation.Host.ChoiceDescription[]]($choiceYes,$choiceNo)
$choiceResult = $host.ui.PromptForChoice($choiceTitle,$choiceMessage,$choiceOptions,0)
switch ($choiceResult)
    {
        0 { #User chose to use same email address as earlier entered
            $DCB | Add-Member -NotePropertyName "SMTPMailFrom" -NotePropertyValue "$EmailSender"
            $DCB | Add-Member -NotePropertyName "SMTPMailRecipients" -NotePropertyValue "$EmailRecipient"
        }
        1 { #User chose to enter new email addresses for generic FSRM notifications 
            while($SMTPEmailRecipient -notmatch "\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"){
                $SMTPEmailRecipient = Read-Host -Prompt "Please enter the email address of that you want generic FSRM notification emails to be sent to."
            }
            while($SMTPEmailSender -notmatch "\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"){
                $SMTPEmailSender = Read-Host -Prompt "Please enter the email address of that you want generic FSRM notification emails to be sent from."
            }
            $DCB | Add-Member -NotePropertyName "SMTPMailFrom" -NotePropertyValue "$SMTPEmailSender"
            $DCB | Add-Member -NotePropertyName "SMTPMailRecipients" -NotePropertyValue "$SMTPEmailRecipient"
        }
    }
#6. Now trickle down that information to other variables
$DCB | Add-Member -NotePropertyName "ConfigFile" -NotePropertyValue "$($DCB.Directory)\DCBConfig.txt"
$DCB | Add-Member -NotePropertyName "Script" -NotePropertyValue "$($DCB.Directory)\DeployCryptoBlocker.ps1"
$DCB | Add-Member -NotePropertyName "TaskScript" -NotePropertyValue "$($DCB.Directory)\UpdateDeployCryptoBlocker.ps1"
$DCB | Add-Member -NotePropertyName "TaskName" -NotePropertyValue "FSRM DeployCryptoBlocker Updater"
#7. Set the notification text
$EventNote1 = 'Notification=e'
$EventNote2 = 'RunLimitInterval=5'
$EventNote3 = 'EventType=Warning'
$EventNote4 = 'Message=User [Source Io Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in the [Violated File Group] file group, which is not permitted on the server.'
$DCB | Add-Member -NotePropertyName "EventNote1" -NotePropertyValue $EventNote1
$DCB | Add-Member -NotePropertyName "EventNote2" -NotePropertyValue $EventNote2
$DCB | Add-Member -NotePropertyName "EventNote3" -NotePropertyValue $EventNote3
$DCB | Add-Member -NotePropertyName "EventNote4" -NotePropertyValue $EventNote4
$EmailNote1 = "Notification=m"
$EmailNote2 = "RunLimitInterval=5"
$EmailNote3 = "To=$($DCB.EmailRecipient)"
$EmailNote4 = "From=$($DCB.EmailSender)"
$EmailNote5 ="Subject=Cryptowatch: Unauthorized file from the [Violated File Group] file group detected"
$EmailNote6 = "Message=User [Source Io Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in the [Violated File Group] file group, which is not permitted on the server."
$DCB | Add-Member -NotePropertyName "EmailNote1" -NotePropertyValue $EmailNote1
$DCB | Add-Member -NotePropertyName "EmailNote2" -NotePropertyValue $EmailNote2
$DCB | Add-Member -NotePropertyName "EmailNote3" -NotePropertyValue $EmailNote3
$DCB | Add-Member -NotePropertyName "EmailNote4" -NotePropertyValue $EmailNote4
$DCB | Add-Member -NotePropertyName "EmailNote5" -NotePropertyValue $EmailNote5
$DCB | Add-Member -NotePropertyName "EmailNote6" -NotePropertyValue $EmailNote6
#8. Write to Config File
New-Item -ItemType File -Path $DCB.ConfigFile
$DCB | Export-Csv $DCB.ConfigFile -Delimiter "`t" -NoTypeInformation 
}

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
$monitoredExtensions = @(ConvertFrom-Json20($jsonStr) | % { $_.filters })

#Make sure you've set your SMTP server in FSRM as well
&filescrn admin options /smtp:$($DCB.SMTPServer) /from:$($DCB.SMTPMailFrom) /AdminEmails:$($DCB.SMTPMailRecipients)

#Check the most recent version of the script to see if it has changed
$RawScript = $webClient.DownloadString("https://raw.githubusercontent.com/nexxai/CryptoBlocker/master/DeployCryptoBlocker.ps1")

if(!($DCB.Script)){ #Save the currently running script in the DCB folder
    New-Item -ItemType File -Path $DCB.Script
    Add-Content -Value $RawScript -Path $DCB.Script -Force
} elseif(!((Get-content $DCB.Script) -eq $RawScript)){ #Compare online version with version as saved
    Write-Host "The Online version differs from the script that is currently running. There may be an updated version available online at https://github.com/nexxai/CryptoBlocker/"
} else {}


$DCBUpdateScript = {
    $DCB = Import-Csv -Path "$($DCB.Directory)\DCBConfig.txt" -Delimiter "`t"
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

    $fileGroupName = "CryptoBlockerGroup"
    $fileTemplateName = "CryptoBlockerTemplate"
    $fileScreenName = "CryptoBlockerScreen"

    $webClient = New-Object System.Net.WebClient
    $jsonStr = $webClient.DownloadString("https://fsrm.experiant.ca/api/v1/get")
    $monitoredExtensions = @(ConvertFrom-Json20($jsonStr) | % { $_.filters })

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

    Write-Host "Adding/replacing File Screen Template [$fileTemplateName] with Event Notification and Command Notification .."
    &filescrn.exe Template Delete /Template:$fileTemplateName /Quiet
    # Build the argument list with all required fileGroups
    $EventNotification = "'"+$DCB.EventNote1+"','"+$DCB.EventNote2+"','"+$DCB.EventNote3+"','"+$DCB.EventNote4+"'"
    $EmailNotification = "'"+$DCB.EmailNote1+"','"+$DCB.EmailNote2+"','"+$DCB.EmailNote3+"','"+$DCB.EmailNote4+"','"+$DCB.EmailNote5+"','"+$DCB.EmailNote6+"'"
    $screenArgs = 'Template','Add',"/Template:$fileTemplateName","/Add-Notification:E,$EventNotification","/Add-Notification:M,$EmailNotification" 
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
}
if(!($DCB.TaskScript)){ #Save the task script in the DCB folder
    New-Item -ItemType File -Path $DCB.TaskScript
    Add-Content -Value $DCBUpdateScript -Path $DCB.TaskScript -Force
}
else{
    Add-Content -Value $DCBUpdateScript -Path $DCB.TaskScript -Force
}

#Create task event that will run the saved script Daily at 4AM -- but only if the update of DeployCryptoBlocker was successful
$TaskExists = Get-ScheduledTask | Where-Object {$_.Taskname -like $DCB.TaskName}
if($TaskExists){
    Unregister-ScheduledTask -TaskName $DCB.TaskName #Remove task 
    $TaskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-noprofile -file `"$($DCB.TaskScript)`""
    $TaskTrigger = New-ScheduledTaskTrigger -At "4:00AM" -Daily
    $TaskPrincipal = New-ScheduledTaskPrincipal -UserId "LOCALSERVICE" -RunLevel Highest -LogonType ServiceAccount
    $Task = New-ScheduledTask -Action $TaskAction -Principal $TaskPrincipal -Trigger $TaskTrigger -Description "This updates the File System Resource Monitor file screen group for anti-cryptoware screening."
    Register-ScheduledTask $DCB.TaskName -InputObject $Task
} else {
    if(!((Get-content $DCB.Script) -eq $RawScript)){#Only update task if script has changed
        $TaskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-noprofile -file `"$($DCB.TaskScript)`""
        $TaskTrigger = New-ScheduledTaskTrigger -At "4:00AM" -Daily
        $TaskPrincipal = New-ScheduledTaskPrincipal -UserId "LOCALSERVICE" -RunLevel Highest -LogonType ServiceAccount
        $Task = New-ScheduledTask -Action $TaskAction -Principal $TaskPrincipal -Trigger $TaskTrigger -Description "This updates the File System Resource Monitor file screen group for anti-cryptoware screening."
        Register-ScheduledTask $DCB.TaskName -InputObject $Task
    }
}

########################################### Setup FSRM ###########################################

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

Write-Host "Adding/replacing File Screen Template [$fileTemplateName] with Event Notification and Command Notification .."
&filescrn.exe Template Delete /Template:$fileTemplateName /Quiet
# Build the argument list with all required fileGroups
$EventNotification = "'"+$DCB.EventNote1+"','"+$DCB.EventNote2+"','"+$DCB.EventNote3+"','"+$DCB.EventNote4+"'"
$EmailNotification = "'"+$DCB.EmailNote1+"','"+$DCB.EmailNote2+"','"+$DCB.EmailNote3+"','"+$DCB.EmailNote4+"','"+$DCB.EmailNote5+"','"+$DCB.EmailNote6+"'"
$screenArgs = 'Template','Add',"/Template:$fileTemplateName","/Add-Notification:E,$EventNotification","/Add-Notification:M,$EmailNotification" 
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