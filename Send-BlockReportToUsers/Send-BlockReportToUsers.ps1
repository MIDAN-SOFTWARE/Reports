<#
.SYNOPSIS
  Name: Send-Send-BlockReportToUsers.ps1
  Create report of permanently blocked emails for your employees.

.DESCRIPTION
  This script can be used to generate a report about E-Mails which where permanently blocked.
  It is possible to filter the results for a specific time duration and sends the report only to specific or all affected users.
  This script only uses the NoSpamProxy Powershell Cmdlets to generate the report file.

.PARAMETER AdBaseDN
  Define the BaseDN for searching a user group in the defined AD.

.PARAMETER AdPort
  Default: 389
  Define a custom port to access the AD.

.PARAMETER AdReportGroup
  Define the AD user group to search for.
  The users in this group will receive a report.

.PARAMETER AdServer
  Define the hostname, FQDN or IP address of the desired AD.

.PARAMETER AdUsername
  Define an optional username to authenticate against the AD.
  A password have to be set before using <SetAdPassword>.

 .PARAMETER CheckuserExistance
  The switch allows to check each report recipient against the known NoSpamProxy users.
  Only usable if no recipient list is provided.
  Can have a huge performance impact.

.PARAMETER FromDate
  Mandatory if you like to use a timespan.
  Specifies the start date for the E-Mail filter.
  Please use ISO 8601 date format: "YYYY-MM-DD hh:mm:ss"
  E.g.:
  	"2019-06-05 08:00" or "2019-06-05 20:00:00"

.PARAMETER NoTime
  Mandatory if you do not like to specify a time value in any kind of way.
  No value needs to be passed here <NoTime> is just a single switch.
  
.PARAMETER NspRule
  Specify a rule name which is defined in NSP as E-Mail filter.

.PARAMETER NumberOfDays
  Mandatory if you like to use a number of days for filtering.
  Specifies the number of days for which th E-Mails should be filtered.

.PARAMETER NumberOfHoursToReport
  Mandatory if you like to use a number of hours for filtering.
  Specifies the number of hours for which th E-Mails should be filtered.

.PARAMETER ReportFileName
  Default: reject-analysis
	Sets the reports file name. No file extension required.
	
.PARAMETER ReportInterval
  Mandatory if you like to use a predifined timespan.
  Specifies a predifined timespan.
	Possible values are:
	daily, monthly, weekly
	The report will start at 00:00:00 o'clock and ends at 23:59:59 o'clock.
	The script call must be a day after the desired report end day.
  
.PARAMETER ReportRecipient
  Specifies the E-Mail recipient. It is possible to pass a comma seperated list to address multiple recipients. 
  E.g.: alice@example.com,bob@example.com

.PARAMETER ReportRecipientCSV
  Set a filepath to an CSV file containing a list of report E-Mail recipient. Be aware about the needed CSV format, please watch the provided example.

.PARAMETER ReportSender
  Default: NoSpamProxy Report Sender <nospamproxy@example.com>
  Sets the report E-Mail sender address.
  
.PARAMETER ReportSubject
  Default: Auswertung der abgewiesenen E-Mails an Sie
  Sets the report E-Mail subject.

.PARAMETER SetAdPassword
  Set a password to use for authentication against the AD.
  The password will be saved as encrypted "NspAdReportingPass.bin" file under %APPDATA%.

.PARAMETER SmtpHost
  Default: 127.0.0.1
  Specifies the SMTP host which should be used to send the report E-Mail.
  It is possible to use a hostname, FQDN or IP address.
	
.PARAMETER ToDate
  Optional if you like to use a timespan.
  Specifies the end date for the E-Mail filter.
  Please use ISO 8601 date format: "YYYY-MM-DD hh:mm:ss"
  E.g.:
	  "2019-06-05 08:00" or "2019-06-05 20:00:00"
	  
.OUTPUTS
  Report is stored under %TEMP%\reject-analysis.html unless a custom <ReportFileName> parameter is given.
  Will be deleted after the email to the recipient was sent.

.NOTES
  Version:        1.0.3
  Author:         Jan Jaeschke
  Creation Date:  2022-05-13
  Purpose/Change: added possibility to use the script with v14
  
.LINK
  https://www.nospamproxy.de
  https://github.com/noSpamProxy

.EXAMPLE
  .\Send-Send-BlockReportToUsers.ps1 -NoTime -ReportFileName "Example-Report" -ReportRecipient alice@example.com -ReportSender "NoSpamProxy Report Sender <nospamproxy@example.com>" -ReportSubject "Example Report" -SmtpHost mail.example.com
  
.EXAMPLE
  .\Send-Send-BlockReportToUsers.ps1 -FromDate: "2019-06-05 08:00:00" -ToDate: "2019-06-05 20:00:00" 
  It is mandatory to specify <FromDate>. Instead <ToDate> is optional.
  These parameters can be combined with all other parameters except <NumberOfDaysToReport>, <NumberOfHoursToRepor>, <ReportIntervall> and <NoTime>.

.EXAMPLE 
  .\Send-Send-BlockReportToUsers.ps1 -NumberOfDaysToReport 7 
  You can combine <NumberOfDaysToReport> with all other parameters except <FromDate>, <ToDate>, <NumberOfHoursToRepor>, <ReportIntervall> and <NoTime>.
  
.EXAMPLE 
  .\Send-Send-BlockReportToUsers.ps1 -NumberOfHoursToReport 12
  You can combine <NumberOfHoursToReport> with all other parameters except <FromDate>, <ToDate>, <NumberOfDaysToReport>, <ReportIntervall> and <NoTime>.
	
.EXAMPLE
	.\Send-BlockReportToUsers.ps1 -ReportInterval weekly
	You can combine <ReportInterval> with all other parameters except <FromDate>, <ToDate>, <NumberOfDaysToReport>, <NumberOfHoursToReport>, <ReportIntervall> and <NoTime>.

.EXAMPLE
  .\Send-BlockReportToUsers.ps1 -NoTime -NspRule "All other inbound mails"
  
.EXAMPLE
  .\Send-BlockReportToUsers.ps1 -NoTime -SmtpHost mail.example.com -ReportRecipientCSV "C:\Users\example\Documents\email-report.csv"
  The CSV have to contain the header "Email" else the mail addresses cannot be read from the file.
  It is possible to combine <ReportRecipientCSV> with <ReportRecipient> and a AD group.
  E.g: email-report.csv
  User,Email
  user1,user1@example.com
  user2,user2@example.com

.EXAMPLE
  .\Send-BlockReportToUsers.ps1 -NoTime -AdServer ad.example.com -AdBaseDN "DC=example,DC=com" -AdReportGroup "MyReportGroup"
  Connect to AD as anonymous.

.EXAMPLE 
  .\Send-BlockReportToUsers.ps1 -NoTime -AdServer ad.example.com -AdBaseDN "DC=example,DC=com" -AdReportGroup "MyReportGroup" -AdUsername Administrator
  Connect to AD as Administrator, password needs to be set using .\Send-BlockReportToUsers.ps1 -SetAdPassword

.EXAMPLE 
  .\Send-BlockReportToUsers.ps1 -SetAdPassword
  Will wait for a user input. The input is shown in plain text!
#>
Param(
	# set start date for filtering
	[Parameter(Mandatory=$true, ParameterSetName="dateSpanSet")]
		[ValidatePattern("^([0-9]{4})-?(1[0-2]|0[1-9])-?(3[01]|0[1-9]|[12][0-9])\s(2[0-3]|[01][0-9]):?([0-5][0-9]):?([0-5][0-9])?$")]
		[string] $FromDate,
	# set end date for filtering
	[Parameter(Mandatory=$false, ParameterSetName="dateSpanSet")]
		[ValidatePattern("^([0-9]{4})-?(1[0-2]|0[1-9])-?(3[01]|0[1-9]|[12][0-9])\s(2[0-3]|[01][0-9]):?([0-5][0-9]):?([0-5][0-9])?$")]
		[string] $ToDate,
	# if set not time duration have to be set the E-Mail of the last few hours will be filtered
	[Parameter(Mandatory=$true, ParameterSetName="noTimeSet")]
		[switch] $NoTime, 
	# set number of days for filtering
	[Parameter(Mandatory=$true, ParameterSetName="numberOfDaysSet")]	
		[ValidatePattern("[0-9]+")]
		[string] $NumberOfDaysToReport,
	# set number of hours for filtering
	[Parameter(Mandatory=$true, ParameterSetName="numberOfHoursSet")]
		[int] $NumberOfHoursToReport,
	# set reporting intervall
	[Parameter(Mandatory=$true, ParameterSetName="reportIntervalSet")]
		[ValidateSet('daily','weekly','monthly')]
		[string] $ReportInterval,
	# run script to save AD user password in an encrypted file
	[Parameter(Mandatory=$true, ParameterSetName="setAdPassword")]
		[switch] $SetAdPassword,
	# set report sender address for outbound email
	[parameter(ParameterSetName = "dateSpanSet")][parameter(ParameterSetName = "numberOfDaysSet")][parameter(ParameterSetName = "numberOfHoursSet")][parameter(ParameterSetName = "noTimeSet")][parameter(ParameterSetName = "reportIntervalSet")]
		[ValidatePattern("^([a-zA-Z0-9\s.!£#$%&'^_`{}~-]+)?<?[a-zA-Z0-9.!£#$%&'^_`{}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*>?$")]
		[string] $ReportSender = "NoSpamProxy Report Sender <nospamproxy@example.com>",	
	# set outbound email subject
	[parameter(ParameterSetName = "dateSpanSet")][parameter(ParameterSetName = "numberOfDaysSet")][parameter(ParameterSetName = "numberOfHoursSet")][parameter(ParameterSetName = "noTimeSet")][parameter(ParameterSetName = "reportIntervalSet")]
		[string] $ReportSubject = "Auswertung der abgewiesenen E-Mails an Sie",
	# change report filename
	[Parameter(Mandatory=$false)]
		[string] $ReportFileName = "reject-analysis",
	# set smtp host for relaying outpund email
	[parameter(ParameterSetName = "dateSpanSet")][parameter(ParameterSetName = "numberOfDaysSet")][parameter(ParameterSetName = "numberOfHoursSet")][parameter(ParameterSetName = "noTimeSet")][parameter(ParameterSetName = "reportIntervalSet")]
		[ValidatePattern("^(((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|((([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])))$")]
		[string] $SmtpHost = "127.0.0.1",
	# set report recipient only valid E-Mail addresses are allowed
	[Parameter(ParameterSetName = "dateSpanSet")][parameter(ParameterSetName = "numberOfDaysSet")][parameter(ParameterSetName = "numberOfHoursSet")][parameter(ParameterSetName = "noTimeSet")][parameter(ParameterSetName = "reportIntervalSet")]
		[ValidatePattern("^<?[a-zA-Z0-9.!£#$%&'^_`{}~-]+?<?[a-zA-Z0-9.!£#$%&'^_`{}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*>?$")]
		[string[]] $ReportRecipient,
	# set path to csv file containing report recipient E-Mail addresses
	[Parameter(ParameterSetName = "dateSpanSet")][parameter(ParameterSetName = "numberOfDaysSet")][parameter(ParameterSetName = "numberOfHoursSet")][parameter(ParameterSetName = "noTimeSet")][parameter(ParameterSetName = "reportIntervalSet")]
		[string] $ReportRecipientCSV,
	# enable user existance check
	[parameter(ParameterSetName = "dateSpanSet")][parameter(ParameterSetName = "numberOfDaysSet")][parameter(ParameterSetName = "numberOfHoursSet")][parameter(ParameterSetName = "noTimeSet")][parameter(ParameterSetName = "reportIntervalSet")]
		[switch] $CheckUserExistence,
	# set AD host
	[parameter(ParameterSetName = "dateSpanSet")][parameter(ParameterSetName = "numberOfDaysSet")][parameter(ParameterSetName = "numberOfHoursSet")][parameter(ParameterSetName = "noTimeSet")][parameter(ParameterSetName = "reportIntervalSet")]
		[ValidatePattern("^(((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|((([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])))$")]
		[string] $AdServer,	
	# set port to access AD
	[parameter(ParameterSetName = "dateSpanSet")][parameter(ParameterSetName = "numberOfDaysSet")][parameter(ParameterSetName = "numberOfHoursSet")][parameter(ParameterSetName = "noTimeSet")][parameter(ParameterSetName = "reportIntervalSet")]
		[ValidateRange(0,65535)]
		[int] $AdPort = 389,
	# set base DN for filtering
	[parameter(ParameterSetName = "dateSpanSet")][parameter(ParameterSetName = "numberOfDaysSet")][parameter(ParameterSetName = "numberOfHoursSet")][parameter(ParameterSetName = "noTimeSet")][parameter(ParameterSetName = "reportIntervalSet")]
		[string] $AdBaseDN,
	# set AD security group containing the desired user objects
	[parameter(ParameterSetName = "dateSpanSet")][parameter(ParameterSetName = "numberOfDaysSet")][parameter(ParameterSetName = "numberOfHoursSet")][parameter(ParameterSetName = "noTimeSet")][parameter(ParameterSetName = "reportIntervalSet")]
		[string] $AdReportGroup,
	# set  AD username for authorization
	[parameter(ParameterSetName = "dateSpanSet")][parameter(ParameterSetName = "numberOfDaysSet")][parameter(ParameterSetName = "numberOfHoursSet")][parameter(ParameterSetName = "noTimeSet")][parameter(ParameterSetName = "reportIntervalSet")]
		[string] $AdUsername
)

#-------------------Functions----------------------
# save AD password as encrypted file
function Set-adPass{
	$adPass = Read-Host -Promp 'Input your AD User password'
	$passFileLocation = $(Join-Path $env:APPDATA 'NspAdReportingPass.bin')
    $inBytes = [System.Text.Encoding]::Unicode.GetBytes($adPass)
    $protected = [System.Security.Cryptography.ProtectedData]::Protect($inBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
	[System.IO.File]::WriteAllBytes($passFileLocation, $protected)
}
# read encrypted AD password from file if existing else user is promted to enter the password
function Get-adPass {
	$passFileLocation = $(Join-Path $env:APPDATA 'NspAdReportingPass.bin')
    if (Test-Path $passFileLocation) {
        $protected = [System.IO.File]::ReadAllBytes($passFileLocation)
        $rawKey = [System.Security.Cryptography.ProtectedData]::Unprotect($protected, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        return [System.Text.Encoding]::Unicode.GetString($rawKey)
    } else {
		Write-Output "No Password file found! Please run 'Send-ReportToUsersWithBlockedEmails.ps1 -SetPassword' for saving your password encrypted."
		$adPass = Read-Host -Promp 'Input your AD User password'
		return $adPass
    }
}
# generate HMTL report
function createHTML($htmlContent) {
	$htmlOut =
"<html>
	<head>
		<title>Abgewiesene E-Mails an Sie</title>
		<style>
			table, td, th { border: 1px solid black; border-collapse: collapse; padding:10px; text-align:center;}
			#headerzeile         {background-color: #DDDDDD;}
		</style>
	</head>
	<body style=font-family:arial>
		<h1>Abgewiesene E-Mails an Sie</h1>
		<br>
		<table>
			 <tr id=headerzeile>
			 <td><h3>Uhrzeit</h3></td><td><h3>Absender</h3></td><td><h3>Betreff</h3></td>
			 </tr>
			 $htmlContent				
		</table>
	</body>
</html>"
	$htmlOut | Out-File "$reportFile"

}

#-------------------Variables----------------------
# check SmtpHost is set
if ($ReportInterval){
	# equals the day where the script runs
	$reportEndDay = (Get-Date -Date ((Get-Date).AddDays(-1)) -UFormat "%Y-%m-%d")
	switch ($ReportInterval){
		'daily'{
			$reportStartDay = $reportEndDay
		}
		'weekly'{
			$reportStartDay = (Get-Date -Date ((Get-Date).AddDays(-7)) -UFormat "%Y-%m-%d")
		}
		'monthly'{
			$reportStartDay = (Get-Date -Date ((Get-Date).AddMonths((-1))) -UFormat "%Y-%m-%d")
		}
	}
	$FromDate = "$reportStartDay 00:00:00"
	$ToDate = "$reportEndDay 23:59:59"
}elseif ($NumberOfHoursToReport){
	$FromDate = (Get-Date).AddHours(-$NumberOfHoursToReport)
}

# create hashtable which will preserve the order of the added items and mapps userParams into needed parameter format
$userParams = [ordered]@{ 
	From = $FromDate
	To = $ToDate
	Age = $NumberOfDaysToReport
	Rule = $NspRule
} 
# for loop problem because hashtable have no indices to access items, this is a workaround
# new hashtable which only holds non empty userParams
$cleanedParams=@{}
# this loop removes all empty userParams and add the otherones into the new hashtable
foreach ($userParam in $userParams.Keys) {
	if ($($userParams.Item($userParam)) -ne "") {
		$cleanedParams.Add($userParam, $userParams.Item($userParam))
	}
}
# end workaround
$reportAll = $false

#--------------------Main-----------------------
$nspVersion = (Get-ItemProperty -Path HKLM:\SOFTWARE\NoSpamProxy\Components -ErrorAction SilentlyContinue).'Intranet Role'
if ($nspVersion -gt '14.0') {
	# NSP v14 has a new authentication mechanism, Connect-Nsp is required to authenticate properly
	# -IgnoreServerCertificateErrors allows the usage of self-signed certificates
	Connect-Nsp -IgnoreServerCertificateErrors
}
# set AD User password and exit program
if($SetAdPassword){
	# Imports Security library for encryption
	Add-Type -AssemblyName System.Security
	Set-adPass
	EXIT
}

if($AdServer){
	# Imports Security library for encryption
	Add-Type -AssemblyName System.Security
	# create AD connection
	# create ADSISearcher object
		$ds=[AdsiSearcher]""
	# define the needed AD object properties
	$ds.PropertiesToLoad.AddRange(@('mail'))
	# define AD search filter
	$ds.filter="(&((memberOf=CN=$AdReportGroup,$AdBaseDN)(ObjectCategory=user)))"
	# define AD paging
	$ds.pagesize=100
	# check if username and read the password from encrypted file else use anonymous connection
	if($AdUsername){
		$password = Get-adPass
		$ds.searchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://${AdServer}:$AdPort","$AdUsername","$password")
	}else{
		$ds.searchRoot = [Adsi]"LDAP://${AdServer}:$AdPort"
	}
	# get all desired users from AD
	$UserListe = $ds.findall()
	# save users mail addresses
	$userMailList = $UserListe.Properties.mail
}

if($ReportRecipientCSV){
	$csv = Import-Csv $ReportRecipientCSV
	$csvMailRecipient = $csv.Email
}
$uniqueReportRecipientList = (($ReportRecipient + $csvMailRecipient + $userMailList) | Get-Unique)
if($null -eq $uniqueReportRecipientList){
	Write-Output "No report recipient list generated, every affected user will receive a report."
	$reportAll = $true
}

# condition to run Main part, if false program will end
$getMessageTracks = $true
$skipMessageTracks = 0
$reportFile = $Env:TEMP + "\" + "$ReportFileName" + ".html"
$entries = @{}


while($getMessageTracks -eq $true){	
	if($skipMessageTracks -eq 0){
		$messageTracks = Get-NSPMessageTrack @cleanedParams -Status PermanentlyBlocked -WithAddresses -Directions FromExternal -First 100
	}else{
		$messageTracks = Get-NSPMessageTrack @cleanedParams -Status PermanentlyBlocked -WithAddresses -Directions FromExternal -First 100 -Skip $skipMessageTracks
	}

	foreach ($messageTrack in $messageTracks){
		$addresses = $messageTrack.Addresses
		foreach ($addressEntry in $addresses){
			if ($addressEntry.AddressType -eq "Recipient"){
				$messageRecipient = $addressEntry.Address
				if($reportAll -eq $false){
					if ($messageRecipient -notin $uniqueReportRecipientList){
						continue
					}
				} elseif ($CheckUserExistence) {
					if (!(Get-Nspuser -Filter "$messageRecipient")) {
						Write-Verbose "$messageRecipient is not a known nsp user."
						continue
					}
				}
				<# 
					create tmp list containing the data of hashtable "entries" for the key "messageRecipient"
					if there is no data use the current messagetrack else add the current messagetrack to the data
					save the  tmp list back into the hashtable for the used key 
				#>
				$list = $entries[$messageRecipient]
				if (!$list) {
					$list = @($messagetrack)
				}
				else
				{
					$list += $messageTrack
				}
				$entries[$messageRecipient] = $list
				}
		}
	}
	# exit condition
	if($messageTracks){
		$skipMessageTracks = $skipMessageTracks+100
		Write-Verbose $skipMessageTracks
	}else{
		$getMessageTracks = $false
		break
	}
}
if($entries.Count -ne 0){
    Write-Output "Generating and sending reports for the following e-mail addresses:"
    $entries.GetEnumerator() | ForEach-Object {
		$htmlContent = ""
        $_.Name
        foreach ($validationItem in $_.Value) {
            $NSPStartTime = $validationItem.Sent.LocalDateTime
            $addresses2 = $validationItem.Addresses
            $NSPSender = ($addresses2 | Where-Object { $_.AddressType -eq "Sender" } | Select-Object "Address").Address		
            $NSPSubject = $validationItem.Subject
            $htmlContent += "<tr><td width=150px>$NSPStartTime</td><td>$NSPSender</td><td>$NSPSubject</td></tr>`r`n`t`t`t"
        }
        createHTML $htmlContent
        Send-MailMessage -SmtpServer $SmtpHost -From $ReportSender -To $_.Name -Subject $ReportSubject -BodyAsHtml -Body "Im Anhang dieser E-Mail finden Sie den Bericht mit der Auswertung der abgewiesenen E-Mails." -Attachments $reportFile
	}
}else{
	Write-Output "Nothing found for report generation."
}

if(Test-Path $reportFile -PathType Leaf){
	Write-Output "Doing some cleanup...."
	Remove-Item $reportFile
}
# SIG # Begin signature block
# MIIc2AYJKoZIhvcNAQcCoIIcyTCCHMUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQULClii0zuA3UdMEBWWYjFkJlg
# YsGgghcTMIIElDCCA3ygAwIBAgIOSBtqBybS6D8mAtSCWs0wDQYJKoZIhvcNAQEL
# BQAwTDEgMB4GA1UECxMXR2xvYmFsU2lnbiBSb290IENBIC0gUjMxEzARBgNVBAoT
# Ckdsb2JhbFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcNMTYwNjE1MDAwMDAw
# WhcNMjQwNjE1MDAwMDAwWjBaMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFs
# U2lnbiBudi1zYTEwMC4GA1UEAxMnR2xvYmFsU2lnbiBDb2RlU2lnbmluZyBDQSAt
# IFNIQTI1NiAtIEczMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAjYVV
# I6kfU6/J7TbCKbVu2PlC9SGLh/BDoS/AP5fjGEfUlk6Iq8Zj6bZJFYXx2Zt7G/3Y
# SsxtToZAF817ukcotdYUQAyG7h5LM/MsVe4hjNq2wf6wTjquUZ+lFOMQ5pPK+vld
# sZCH7/g1LfyiXCbuexWLH9nDoZc1QbMw/XITrZGXOs5ynQYKdTwfmOPLGC+MnwhK
# kQrZ2TXZg5J2Yl7fg67k1gFOzPM8cGFYNx8U42qgr2v02dJsLBkwXaBvUt/RnMng
# Ddl1EWWW2UO0p5A5rkccVMuxlW4l3o7xEhzw127nFE2zGmXWhEpX7gSvYjjFEJtD
# jlK4PrauniyX/4507wIDAQABo4IBZDCCAWAwDgYDVR0PAQH/BAQDAgEGMB0GA1Ud
# JQQWMBQGCCsGAQUFBwMDBggrBgEFBQcDCTASBgNVHRMBAf8ECDAGAQH/AgEAMB0G
# A1UdDgQWBBQPOueslJF0LZYCc4OtnC5JPxmqVDAfBgNVHSMEGDAWgBSP8Et/qC5F
# JK5NUPpjmove4t0bvDA+BggrBgEFBQcBAQQyMDAwLgYIKwYBBQUHMAGGImh0dHA6
# Ly9vY3NwMi5nbG9iYWxzaWduLmNvbS9yb290cjMwNgYDVR0fBC8wLTAroCmgJ4Yl
# aHR0cDovL2NybC5nbG9iYWxzaWduLmNvbS9yb290LXIzLmNybDBjBgNVHSAEXDBa
# MAsGCSsGAQQBoDIBMjAIBgZngQwBBAEwQQYJKwYBBAGgMgFfMDQwMgYIKwYBBQUH
# AgEWJmh0dHBzOi8vd3d3Lmdsb2JhbHNpZ24uY29tL3JlcG9zaXRvcnkvMA0GCSqG
# SIb3DQEBCwUAA4IBAQAVhCgM7aHDGYLbYydB18xjfda8zzabz9JdTAKLWBoWCHqx
# mJl/2DOKXJ5iCprqkMLFYwQL6IdYBgAHglnDqJQy2eAUTaDVI+DH3brwaeJKRWUt
# TUmQeGYyDrBowLCIsI7tXAb4XBBIPyNzujtThFKAzfCzFcgRCosFeEZZCNS+t/9L
# 9ZxqTJx2ohGFRYzUN+5Q3eEzNKmhHzoL8VZEim+zM9CxjtEMYAfuMsLwJG+/r/uB
# AXZnxKPo4KvcM1Uo42dHPOtqpN+U6fSmwIHRUphRptYCtzzqSu/QumXSN4NTS35n
# fIxA9gccsK8EBtz4bEaIcpzrTp3DsLlUo7lOl8oUMIIE+zCCA+OgAwIBAgIMXyow
# wDWeCuKMV1r4MA0GCSqGSIb3DQEBCwUAMFoxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMTAwLgYDVQQDEydHbG9iYWxTaWduIENvZGVTaWdu
# aW5nIENBIC0gU0hBMjU2IC0gRzMwHhcNMTkwNjA2MTM0NzIxWhcNMjIwNjA2MTM0
# NzIxWjB1MQswCQYDVQQGEwJERTEcMBoGA1UECBMTTm9yZHJoZWluLVdlc3RmYWxl
# bjESMBAGA1UEBxMJUGFkZXJib3JuMRkwFwYDVQQKExBOZXQgYXQgV29yayBHbWJI
# MRkwFwYDVQQDExBOZXQgYXQgV29yayBHbWJIMIIBIjANBgkqhkiG9w0BAQEFAAOC
# AQ8AMIIBCgKCAQEAstEMIFLNGUWS4uipXK3J6jJRBtI8+WjlUNal/WmOU4vSeJBC
# 4BkG8AsTZPd4KNEIVlbXi4MNV2eMtoQgyhRF1iQFGFXhqO0qxhYLArfUSEPPekL+
# t/ySEPVEurliH6Di1qfaFxceM+dXWG6ybrlOOZkHqow1PqBPfOUC54Rcyq6Co+mu
# qNvznCBPZSK4wvbiHCYb2pN0tnl7swP1q/K0ODB23wJathgKmLemW6Coz7L/sBHH
# vpgU1fVwi8huavjtQMFv0IRXiKZuHDnAugyNrEpJpFpQpxXLUpEN9Bn0GzmTth0N
# tVCMXVPeChj3qjvJEYP3GnGpY7K6O0Zc6Ao/jQIDAQABo4IBpDCCAaAwDgYDVR0P
# AQH/BAQDAgeAMIGUBggrBgEFBQcBAQSBhzCBhDBIBggrBgEFBQcwAoY8aHR0cDov
# L3NlY3VyZS5nbG9iYWxzaWduLmNvbS9jYWNlcnQvZ3Njb2Rlc2lnbnNoYTJnM29j
# c3AuY3J0MDgGCCsGAQUFBzABhixodHRwOi8vb2NzcDIuZ2xvYmFsc2lnbi5jb20v
# Z3Njb2Rlc2lnbnNoYTJnMzBWBgNVHSAETzBNMEEGCSsGAQQBoDIBMjA0MDIGCCsG
# AQUFBwIBFiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzAI
# BgZngQwBBAEwCQYDVR0TBAIwADA/BgNVHR8EODA2MDSgMqAwhi5odHRwOi8vY3Js
# Lmdsb2JhbHNpZ24uY29tL2dzY29kZXNpZ25zaGEyZzMuY3JsMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMB8GA1UdIwQYMBaAFA8656yUkXQtlgJzg62cLkk/GapUMB0GA1Ud
# DgQWBBQfMkfbwLvXrRRwHDgqny8W9JqFizANBgkqhkiG9w0BAQsFAAOCAQEATV/B
# SwkQkEbtB4JVCZBEowPzU2FdJzxS3LKg6NW2GX9vd3iHU/703AL8dqBSdoO6CREw
# /GV3pXtQhWDv1HVuCCRNk+rf4NooDMgxtNZFaAcKn8Zto+/a+4f01URf1LObbIeg
# bHByaBzlLv1FW3v/ilsLCs+KJ8Vkp/qG1gxac/KR79yLTXa1wgNkIvAtCz9LRlqf
# 0qUWubVC6Hg1s2EnuSs2d+v497zZRIp+UxkqLp3Uuvacp8VTl+NY3q064Fm2QyG5
# xwX8FWO+hwEF6mH2vh71icxXsRVADCgiOBX7S0l0M+zTVwnadPE6VlmLlcRo2Uv/
# /xrNfYi4zYch/b/ZtjCCBq4wggSWoAMCAQICEAc2N7ckVHzYR6z9KGYqXlswDQYJ
# KoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IElu
# YzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQg
# VHJ1c3RlZCBSb290IEc0MB4XDTIyMDMyMzAwMDAwMFoXDTM3MDMyMjIzNTk1OVow
# YzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQD
# EzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGlu
# ZyBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMaGNQZJs8E9cklR
# VcclA8TykTepl1Gh1tKD0Z5Mom2gsMyD+Vr2EaFEFUJfpIjzaPp985yJC3+dH54P
# Mx9QEwsmc5Zt+FeoAn39Q7SE2hHxc7Gz7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupR
# PfDWVtTnKC3r07G1decfBmWNlCnT2exp39mQh0YAe9tEQYncfGpXevA3eZ9drMvo
# hGS0UvJ2R/dhgxndX7RUCyFobjchu0CsX7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV
# 5huowWR0QKfAcsW6Th+xtVhNef7Xj3OTrCw54qVI1vCwMROpVymWJy71h6aPTnYV
# VSZwmCZ/oBpHIEPjQ2OAe3VuJyWQmDo4EbP29p7mO1vsgd4iFNmCKseSv6De4z6i
# c/rnH1pslPJSlRErWHRAKKtzQ87fSqEcazjFKfPKqpZzQmiftkaznTqj1QPgv/Ci
# PMpC3BhIfxQ0z9JMq++bPf4OuGQq+nUoJEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5
# K6jzRWC8I41Y99xh3pP+OcD5sjClTNfpmEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oi
# qMEmCPkUEBIDfV8ju2TjY+Cm4T72wnSyPx4JduyrXUZ14mCjWAkBKAAOhFTuzuld
# yF4wEr1GnrXTdrnSDmuZDNIztM2xAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAG
# AQH/AgEAMB0GA1UdDgQWBBS6FtltTYUvcyl2mi91jGogj57IbzAfBgNVHSMEGDAW
# gBTs1+OC0nFdZEzfLmc/57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAww
# CgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8v
# b2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDow
# OKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRS
# b290RzQuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkq
# hkiG9w0BAQsFAAOCAgEAfVmOwJO2b5ipRCIBfmbW2CFC4bAYLhBNE88wU86/GPvH
# UF3iSyn7cIoNqilp/GnBzx0H6T5gyNgL5Vxb122H+oQgJTQxZ822EpZvxFBMYh0M
# CIKoFr2pVs8Vc40BIiXOlWk/R3f7cnQU1/+rT4osequFzUNf7WC2qk+RZp4snuCK
# rOX9jLxkJodskr2dfNBwCnzvqLx1T7pa96kQsl3p/yhUifDVinF2ZdrM8HKjI/rA
# J4JErpknG6skHibBt94q6/aesXmZgaNWhqsKRcnfxI2g55j7+6adcq/Ex8HBanHZ
# xhOACcS2n82HhyS7T6NJuXdmkfFynOlLAlKnN36TU6w7HQhJD5TNOXrd/yVjmScs
# PT9rp/Fmw0HNT7ZAmyEhQNC3EyTN3B14OuSereU0cZLXJmvkOHOrpgFPvT87eK1M
# rfvElXvtCl8zOYdBeHo46Zzh3SP9HSjTx/no8Zhf+yvYfvJGnXUsHicsJttvFXse
# GYs2uJPU5vIXmVnKcPA3v5gA3yAWTyf7YGcWoWa63VXAOimGsJigK+2VQbc61RWY
# MbRiCQ8KvYHZE/6/pNHzV9m8BPqC3jLfBInwAM1dwvnQI38AC+R2AibZ8GV2QqYp
# hwlHK+Z/GqSFD/yYlvZVVCsfgPrA8g4r5db7qS9EFUrnEw4d2zc4GqEr9u3WfPww
# ggbGMIIErqADAgECAhAKekqInsmZQpAGYzhNhpedMA0GCSqGSIb3DQEBCwUAMGMx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMy
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcg
# Q0EwHhcNMjIwMzI5MDAwMDAwWhcNMzMwMzE0MjM1OTU5WjBMMQswCQYDVQQGEwJV
# UzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xJDAiBgNVBAMTG0RpZ2lDZXJ0IFRp
# bWVzdGFtcCAyMDIyIC0gMjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# ALkqliOmXLxf1knwFYIY9DPuzFxs4+AlLtIx5DxArvurxON4XX5cNur1JY1Do4Hr
# OGP5PIhp3jzSMFENMQe6Rm7po0tI6IlBfw2y1vmE8Zg+C78KhBJxbKFiJgHTzsNs
# /aw7ftwqHKm9MMYW2Nq867Lxg9GfzQnFuUFqRUIjQVr4YNNlLD5+Xr2Wp/D8sfT0
# KM9CeR87x5MHaGjlRDRSXw9Q3tRZLER0wDJHGVvimC6P0Mo//8ZnzzyTlU6E6XYY
# mJkRFMUrDKAz200kheiClOEvA+5/hQLJhuHVGBS3BEXz4Di9or16cZjsFef9LuzS
# mwCKrB2NO4Bo/tBZmCbO4O2ufyguwp7gC0vICNEyu4P6IzzZ/9KMu/dDI9/nw1oF
# Yn5wLOUrsj1j6siugSBrQ4nIfl+wGt0ZvZ90QQqvuY4J03ShL7BUdsGQT5TshmH/
# 2xEvkgMwzjC3iw9dRLNDHSNQzZHXL537/M2xwafEDsTvQD4ZOgLUMalpoEn5deGb
# 6GjkagyP6+SxIXuGZ1h+fx/oK+QUshbWgaHK2jCQa+5vdcCwNiayCDv/vb5/bBMY
# 38ZtpHlJrYt/YYcFaPfUcONCleieu5tLsuK2QT3nr6caKMmtYbCgQRgZTu1Hm2GV
# 7T4LYVrqPnqYklHNP8lE54CLKUJy93my3YTqJ+7+fXprAgMBAAGjggGLMIIBhzAO
# BgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEF
# BQcDCDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwHwYDVR0jBBgw
# FoAUuhbZbU2FL3MpdpovdYxqII+eyG8wHQYDVR0OBBYEFI1kt4kh/lZYRIRhp+pv
# HDaP3a8NMFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5j
# cmwwgZAGCCsGAQUFBwEBBIGDMIGAMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5k
# aWdpY2VydC5jb20wWAYIKwYBBQUHMAKGTGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdD
# QS5jcnQwDQYJKoZIhvcNAQELBQADggIBAA0tI3Sm0fX46kuZPwHk9gzkrxad2bOM
# l4IpnENvAS2rOLVwEb+EGYs/XeWGT76TOt4qOVo5TtiEWaW8G5iq6Gzv0UhpGThb
# z4k5HXBw2U7fIyJs1d/2WcuhwupMdsqh3KErlribVakaa33R9QIJT4LWpXOIxJiA
# 3+5JlbezzMWn7g7h7x44ip/vEckxSli23zh8y/pc9+RTv24KfH7X3pjVKWWJD6Kc
# wGX0ASJlx+pedKZbNZJQfPQXpodkTz5GiRZjIGvL8nvQNeNKcEiptucdYL0EIhUl
# cAZyqUQ7aUcR0+7px6A+TxC5MDbk86ppCaiLfmSiZZQR+24y8fW7OK3NwJMR1TJ4
# Sks3KkzzXNy2hcC7cDBVeNaY/lRtf3GpSBp43UZ3Lht6wDOK+EoojBKoc88t+dMj
# 8p4Z4A2UKKDr2xpRoJWCjihrpM6ddt6pc6pIallDrl/q+A8GQp3fBmiW/iqgdFtj
# Zt5rLLh4qk1wbfAs8QcVfjW05rUMopml1xVrNQ6F1uAszOAMJLh8UgsemXzvyMjF
# jFhpr6s94c/MfRWuFL+Kcd/Kl7HYR+ocheBFThIcFClYzG/Tf8u+wQ5KbyCcrtlz
# MlkI5y2SoRoR/jKYpl0rl+CL05zMbbUNrkdjOEcXW28T2moQbh9Jt0RbtAgKh1pZ
# BHYRoad3AhMcMYIFLzCCBSsCAQEwajBaMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQ
# R2xvYmFsU2lnbiBudi1zYTEwMC4GA1UEAxMnR2xvYmFsU2lnbiBDb2RlU2lnbmlu
# ZyBDQSAtIFNIQTI1NiAtIEczAgxfKjDANZ4K4oxXWvgwCQYFKw4DAhoFAKB4MBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYE
# FFYPkQtFz63Wmyl6WG4L04uI6hozMA0GCSqGSIb3DQEBAQUABIIBAADJ5ZmWf852
# YTPvsWWvkAYbHAErKp/QudaPJQ/DIF90rRQ2GsYv2HrgRi0/UoHEao1XYB4R60pd
# 1vCpKd+oHz6i4d9evvM7Jf68RDeYJ16Bep8ZD81sMPsSK5dgSSf/yIXBQ+5InBCo
# 7ETywQvcz063jBeCBfccncu1A9fRlDYwzkZFwm6BbRGa+JgPFVL4UQs5f4OW1L0R
# dgxELsSM6wl/HnX3iAWPcYNzGXZn9/ggIoN8GIJCCD/tE+ikzuhf34+I312A36PH
# ybH8lqatzQ8IS1uOpTmYZTIcjbUi+Z/gWR4JTsPOZUKvMOD1LHvq0YRwKMIR4A9F
# Uane4k57qmyhggMgMIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQswCQYD
# VQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lD
# ZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhAK
# ekqInsmZQpAGYzhNhpedMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsG
# CSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjIwNTEzMDgzNTI0WjAvBgkqhkiG
# 9w0BCQQxIgQgpVaVT2Xi3gW6yup05mB3EaTa0KU+T2vLqOIU4DJKsTEwDQYJKoZI
# hvcNAQEBBQAEggIAV9U+ZcZaMQt80SkF867zSte3tyM9yeMCaBQpZ9sckhnkRkAk
# Mf57e1RA4ayKEUbVxiHmrbhscKZvQgGU1tljkQ3QaFC5GU3j5LPbTf32E6z9jtgt
# ZHvTi8MX6DNd69sTLjlnzCslf3fu47ms0gOhWzFob30dvzhkYJnhKfJXu0YBMqHT
# ZHE6zDfZCAZiyY2e+RPzGznZn4FjwjdK6EFoxL6Iy1rokjdVuU8O60S715e9BFTA
# vG/BZ5nXHv7jVGn+Rp1ULB9pfU1i8gz8Op9wxW+fnN3ICaOm+38UVps2s8ldqA5r
# svOa5NK/EKticxu5kQJmeGqS4rkakhKb+3AhLG5DXMHZ1cJ7uDEZx3eNNkQxpp34
# EU1oePnphqHvVO4uYy4zmNIglFZbkBLUxV8fuGX7I2Emv8WqCsYkQaLkZp3J4OV+
# jySa0CiWaX/oNBTbkSnsxO/6nfWSTMSXQ1ZNex1KgoztffegAeQ/TKMo7uBg2QYu
# F8TlCUCcNaqilETPTV865e8phrcn4+hC20hKS8lEDElak7GthrJsWBK3YAe/QMgn
# s6oF7CpywRJgUYi/+JeodITG91MUOSRj9eEcj4+jAO4gWMAr/hMIZLq+rVlgrO6R
# QFY806kFwjs9ePTAyumUiJdnDbqp8ZAwojoGkZh20+ccKEFJlBwq1SHrtsE=
# SIG # End signature block
