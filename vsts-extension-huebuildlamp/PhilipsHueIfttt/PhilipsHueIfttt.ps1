#
# Control Philips Hue Light via IFTTT
#
[CmdletBinding(DefaultParameterSetName = 'None')]
param(
	[string][Parameter(Mandatory=$true)] $sendMailFrom,
	#[string][Parameter(Mandatory=$true)] $smtpServerEndpoint,
	[string][Parameter(Mandatory=$true)] $smtpServer,
	[string][Parameter(Mandatory=$true)] $smtpUserName,
	[string][Parameter(Mandatory=$true)] $smtpPassword,
	[string][Parameter(Mandatory=$true)] $smtpUseSslVariable,
	[string][Parameter(Mandatory=$true)] $smtpPortVariable,
	[string] $buildNames,
	[string][Parameter(Mandatory=$true)] $sendMailTo,
	[string] $mailHashtag
)

<#$sendMailFrom = Get-VstsInput -Name sendMailFrom -Require
$smtpServerEndpoint = Get-VstsInput -Name smtpServerEndpoint -Require
$smtpServer = Get-VstsInput -Name smtpServer -Require
$smtpUserName = Get-VstsInput -Name smtpUserName -Require
$smtpPassword = Get-VstsInput -Name smtpPassword -Require
$smtpUseSslVariable = Get-VstsInput -Name smtpUseSslVariable -Require
$smtpPortVariable = Get-VstsInput -Name smtpPortVariable -Require
$buildNames = Get-VstsInput -Name buildNames
$sendMailTo = Get-VstsInput -Name sendMailTo -Require
$mailHashtag = Get-VstsInput -Name mailHashtag

# Retrieves the url, username and password from the specified generic endpoint.
function GetEndpointData
{
	param([string][ValidateNotNullOrEmpty()]$smtpServerEndpoint)

	$serviceEndpoint = Get-VstsEndpoint -Name $smtpServerEndpoint -Require

	if (!$serviceEndpoint)
	{
		throw "A Connected Service with name '$smtpServerEndpoint' could not be found. Ensure that this Connected Service was successfully provisioned using the services tab in the Admin UI."
	}

   return $serviceEndpoint
}#>

Write-Host "Starting Control Philips Hue Task via IFTTT"

# TODO: Validate global variables
[string]$serverUrl = $Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
[string]$projectName = $Env:SYSTEM_TEAMPROJECT
[int]$smtpPort = [convert]::ToInt32($smtpPortVariable, 10)
[boolean]$smtpUseSsl = [convert]::ToBoolean($smtpUseSslVariable)
[securestring]$securePassword = convertto-securestring $smtpPassword -asplaintext -force
[string]$scriptPath = Split-Path -parent $PSCommandPath

# Split URL in port and URL if possible
<#$serviceEndpoint = GetEndpointData $smtpServerEndpoint
$smtpServer = "$($serviceEndpoint.Url)"
$smtpPort = $serviceEndpoint.Url.Port
Write-Host "SMTP server url set to $($smtpServer)"
Write-Host "SMTP port set to $($serviceEndpoint.Url.Port)"
$smtpUserName = $serviceEndpoint.Auth.Parameters.Username
$securePassword = $serviceEndpoint.Auth.Parameters.Password#>

# Built email message
$message = New-Object System.Net.Mail.MailMessage
$message.From = $sendMailFrom
$message.To.add($sendMailTo)
$message.Body = "Green"
$message.Subject = "Green"
$message.IsBodyHtml = $true
$fileUrl = "green.jpg"

# Base64-encodes the Personal Access Token (PAT) appropriately
[string]$user = ""
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$Env:SYSTEM_ACCESSTOKEN)))

# Construct the REST URL to obtain Build Definitions
$uri = "{0}{1}/_apis/build/definitions?api-version=2.0" -f $serverUrl,[uri]::EscapeDataString($projectName)
$buildDefinitions = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
 
# Fail if no build definitions found.
if ($buildDefinitions.count -eq 0)
{
     throw "No build definitions found."
}

Write-Host "Start matching $($buildDefinitions.count) found build definitions"
[string] $matchedBuildDefinitions = ""
[int] $totalMatches = 0;
foreach($buildDef in $buildDefinitions.value)
{
	[boolean] $match = $false;
	if([string]::IsNullOrEmpty($buildNames))
	{
		$match = $true
	}

	if($buildNames -contains $buildDef.name)
	{
		$match = $true
	}

	if($match)
	{
		$totalMatches += 1

		if([string]::IsNullOrEmpty($matchedBuildDefinitions))
		{
			$matchedBuildDefinitions = "{0}" -f $buildDef.id
		}
		else
		{
			$matchedBuildDefinitions = "{0},{1}" -f $matchedBuildDefinitions,$buildDef.id
		}
	}
	else
	{
		Write-Host "No match found for $($buildDef)"
	}
}

Write-Host "Matched build definition string complete and contains $($matchedBuildDefinitions)"
Write-Host "Total matches found: $($totalMatches)"

# Invoke the REST call and capture the results
$uri = "{0}{1}/_apis/build/builds?api-version=2.0&definitions={2}&statusFilter=inProgress,Completed&maxBuildsPerDefinition=1" -f $serverUrl,[uri]::EscapeDataString($projectName),$matchedBuildDefinitions
$buildResults = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}

# This call should only provide a single result; Capture the Build ID from the result
if ($buildResults.count -eq 0)
{
     throw "No build results found."
}

foreach($buildResult in $buildResults.value)
{
	if($buildResult.status -eq "inProgress")
	{
		# If status is in progress, get the actual state (and if errors) of this build.
		$uri = "{0}{1}/_apis/build/builds/{2}/timeline?api-version=2.0" -f $serverUrl,[uri]::EscapeDataString($projectName),$buildResult.id
		$detailedBuildResults = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
		foreach($detailedBuildResult in $detailedBuildResults.records)
		{
			if($detailedBuildResult.result -eq "failed")
			{
				$message.Body = "Red"
				$message.Subject = "Red"
				$fileUrl = "red.jpg"
				break
			}

			if($detailedBuildResult.result -eq "partiallysucceeded")
			{
				$message.Body = "Orange"
				$message.Subject = "Orange"
				$fileUrl = "orange.jpg"
			}
		}

		continue
	}

	if($buildResult.result -eq "failed")
	{
		$message.Body = "Red"
		$message.Subject = "Red"
		$fileUrl = "red.jpg"
		break
	}

	if($buildResult.result -eq "partiallysucceeded")
	{
		$message.Body = "Orange"
		$message.Subject = "Orange"
		$fileUrl = "orange.jpg"
	}
}

$mailAttachment = new-object Net.Mail.Attachment("$($scriptPath)/$($fileUrl)")
$message.Attachments.Add($mailAttachment)

if($mailHashtag)
{
	$message.Subject = "$($message.Subject) #$($mailHashtag)"
}

<#Sending message to IFTTT#>
write-Host "Sending email message"
Write-Host "With body: $($message.Body)"

$smtpClient = New-Object Net.Mail.SmtpClient($smtpServer, $smtpPort) 
$smtpClient.EnableSsl = $smtpUseSsl 
$smtpClient.UseDefaultCredentials = $false
$smtpClient.Credentials = New-Object System.Management.Automation.PSCredential($smtpUserName, $securePassword)
$smtpClient.Send($message)

Write-Host "Closing Control Philips Hue via IFTTT"