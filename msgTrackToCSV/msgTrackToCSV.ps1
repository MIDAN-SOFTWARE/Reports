<#
.SYNOPSIS
  Name: msgTrackToCSV.ps1
  Create CSV export of the message track.

.DESCRIPTION
  This script can be used to generate a CSV export of the message track.
	It is possible to send the report via E-Mail, to filter the results and set a specific time duration.
	The CSV file will contain the following data in the displayed order: Sent, Status, Sender, Recipient, Signed, Encrypted, MessageId
  This script only uses the NoSpamProxy Powershell Cmdlets to generate the report file.

.PARAMETER FromDate
  Mandatory if you like to use a timespan.
  Specifies the start date for the E-Mail filter.
  It is important to use US date format MM/dd/YYYY.
  E.g.:
  	"11/16/2018 08:00" or "11/16/2018 20:00"
  	"11/16/2018 8am" or "11/16/2018 8pm"

.PARAMETER ToDate
  Optional if you like to use a timespan.
  Specifies the end date for the E-Mail filter.
  It is important to use US date format MM/dd/YYYY.
  E.g.:
  	"11/16/2018 08:00" or "11/16/2018 20:00"
  	"11/16/2018 8am" or "11/16/2018 8pm"

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
  Default: msgTrackReport
  Sets the reports file name. No file extension required.
  
.PARAMETER ReportRecipient
  Specifies the E-Mail recipient. It is possible to pass a comma seperated list to address multiple recipients. 
  E.g.: alice@example.com,bob@example.com

.PARAMETER ReportRecipientCSV
  Set a filepath to an CSV file containing a list of report E-Mail recipient. Be aware about the needed CSV format, please watch the provided example.

.PARAMETER ReportSender
  Default: NoSpamProxy Report Sender <nospamproxy@example.com>
  Sets the report E-Mail sender address.
  
.PARAMETER ReportSubject
  Default: Message Track Report
  Sets the report E-Mail subject.

.PARAMETER SmtpHost
  Specifies the SMTP host which should be used to send the report E-Mail.
  It is possible to use a FQDN or IP address.

.PARAMETER Status
  Specifies a filter to get only E-Mails which are matching the defined state.
  Possible values are: 
  None | Success | DispatcherError | TemporarilyBlocked | PermanentlyBlocked | PartialSuccess | DeliveryPending | Suppressed | DuplicateDrop | PutOnHold | All

.OUTPUTS
  Report is stored under %TEMP%\msgTrackReport.html unless a custom <ReportFileName> parameter is given.

.NOTES
  Version:        1.0.1
  Author:         Jan Jaeschke
  Creation Date:  2019-03-01
  Purpose/Change: changed output to get Sender and Recipient
  
.LINK
  https://https://www.nospamproxy.de
  https://github.com/noSpamProxy

.EXAMPLE
  .\msgTrackToCSV.ps1 -NoTime -Status "Success" -ReportFileName "Example-Report" -ReportRecipient alice@example.com -ReportSender "NoSpamProxy Report Sender <nospamproxy@example.com>" -ReportSubject "Example Report" -SmtpHost mail.example.com
  
.EXAMPLE
  .\msgTrackToCSV.ps1 -FromDate: "10/14/2018 08:00" -ToDate: "10/14/2018 20:00" -NoMail
  It is mandatory to specify <FromDate>. Instead <ToDate> is optional.
  These parameters can be combined with all other parameters except <NumberOfDaysToReport> and <NumberOfHoursToRepor>.

.EXAMPLE 
  .\msgTrackToCSV.ps1 -NumberOfDaysToReport 7 -NoMail
  You can combine <NumberOfDaysToReport> with all other parameters except <FromDate>, <ToDate> and <NumberOfHoursToRepor>.
  
.EXAMPLE 
  .\msgTrackToCSV.ps1 -NumberOfHoursToReport 12 -NoMail
  You can combine <NumberOfHoursToReport> with all other parameters except <FromDate>, <ToDate> and <NumberOfDaysToReport>.
  
.EXAMPLE
  .\msgTrackToCSV.ps1 -NoTime -NoMail -NspRule "All other inbound mails"
  
.EXAMPLE
  .\msgTrackToCSV.ps1 -NoTime -SmtpHost mail.example.com -ReportRecipientCSV "C:\Users\example\Documents\email-report.csv"
  The CSV have to contain the header "Email" else the mail addresses cannot be read from the file.
  It is possible to combine <ReportRecipientCSV> with <ReportRecipient>.
  E.g: email-report.csv
  User,Email
  user1,user1@example.com
  user2,user2@example.com
#>
param (
# userParams are used for filtering
	# set start date for filtering
	[Parameter(Mandatory=$true, ParameterSetName="dateSpanSet")][string] $FromDate,
	# set end date for filtering
	[Parameter(Mandatory=$false, ParameterSetName="dateSpanSet")][string] $ToDate,
	# set number of days for filtering
	[Parameter(Mandatory=$true, ParameterSetName="numberOfDaysSet")][ValidatePattern("[0-9]+")][string] $NumberOfDaysToReport,
	# set number of hours for filtering
	[Parameter(Mandatory=$true, ParameterSetName="numberOfHoursSet")][int] $NumberOfHoursToReport,
	# if set not time duration have to be set the E-Mail of the last few hours will be filtered
	[Parameter(Mandatory=$true, ParameterSetName="noTimeSet")][switch] $NoTime, # no userParam just here for better Get-Help output
	# set E-Mail status which will be filtered
	[Parameter(Mandatory=$false)][string] $Status,
	# set NSP Rule for filtering
	[Parameter(Mandatory=$false)][string] $NspRule,
	# additional params are used for additional actions
	[Parameter(Mandatory=$false)][string] $MailRecipientCSV,
	# generate the report but do not send an E-Mail
	[Parameter(Mandatory=$false)][switch]$NoMail, 
	# change report filename
	[Parameter(Mandatory=$false)][string] $ReportFileName = "msgTrackReport" ,
	# set report recipient only valid E-Mail addresses are allowed
	[Parameter(Mandatory=$false)][ValidatePattern("^<?[a-zA-Z0-9.!£#$%&'^_`{}~-]+?<?[a-zA-Z0-9.!£#$%&'^_`{}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*>?$")][string[]] $ReportRecipient,
	# set path to csv file containing report recipient E-Mail addresses
	[Parameter(Mandatory=$false)][string] $ReportRecipientCSV,
	# set report sender address only a valid E-Mail addresse is allowed
	[Parameter(Mandatory=$false)][ValidatePattern("^<?[a-zA-Z0-9.!£#$%&'^_`{}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*>?$")][string] $ReportSender = "NoSpamProxy Report Sender <nospamproxy@example.com>",
	# change report E-Mail subject
	[Parameter(Mandatory=$false)][string] $ReportSubject = "Message Track Report",
	# set used SMTP host for sending report E-Mail only a valid  IP address or FQDN is allowed
	[Parameter(Mandatory=$false)][ValidatePattern("^(((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|(((?!-)[a-zA-Z0-9-]{0,62}[a-zA-Z0-9]\.)+[a-zA-Z]{2,63}))$")][string] $SmtpHost
)

#-------------------Functions----------------------
# send report E-Mail 
function sendMail($ReportRecipient, $ReportRecipientCSV){ 
	if ($ReportRecipient -and $ReportRecipientCSV){
		$recipientCSV = Import-Csv $ReportRecipientCSV
		$mailRecipient = @($ReportRecipient;$recipientCSV.Email)
	}
	elseif($ReportRecipient){
		$mailRecipient = $ReportRecipient
	}
	elseif($ReportRecipientCSV){
		$csv = Import-Csv $ReportRecipientCSV
		$mailRecipient = $csv.Email
	}
	if ($SmtpHost -and $mailRecipient){
		Send-MailMessage -SmtpServer $SmtpHost -From $ReportSender -To $mailRecipient -Subject $ReportSubject -Body "Im Anhang dieser E-Mail finden Sie einen automatisch genrerierten Bericht vom NoSpamProxy" -Attachments $reportFile
	}
}

#-------------------Variables----------------------
if ($NumberOfHoursToReport){
	$FromDate = (Get-Date).AddHours(-$NumberOfHoursToReport)
}
# create hashtable which will preserve the order of the added items and mapps userParams into needed parameter format
$userParams = [ordered]@{ 
From = $FromDate
To = $ToDate
Age = $NumberOfDaysToReport
Rule = $NspRule
Status = $Status
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
$fileDate = Get-Date -UFormat "%Y-%m-%d"
$reportFile =  "$ENV:TEMP\" + "$fileDate-$ReportFileName" + ".csv"
# condition to run Main part, if false program will end
$getMessageTracks = $true
# number of messages whcih will be skipped by Get-NspMessageTrack, will increase by 100 at each call
$skipMessageTracks = 0

#--------------------Main-----------------------
if(Test-Path $reportFile){
	Remove-Item -Path $reportFile
}
while($getMessageTracks -eq $true){	
	if($skipMessageTracks -eq 0){
		$messageTracks = Get-NSPMessageTrack @cleanedParams -WithAddresses -Directions FromExternal -First 100
	}else{
		$messageTracks = Get-NSPMessageTrack @cleanedParams -WithAddresses -Directions FromExternal -First 100 -Skip $skipMessageTracks
	}
#  @=define array, n=Name, e=Exression statement - e.x. Sender: go through each piped object, show the addresses, but only the  ones with type "Sender", and get these address
	$messageTracks | Select-Object Sent,Subject,Status,@{n="Sender";e={($_ | Select-Object -ExpandProperty Addresses | Where-Object{[string]$_.AddressType -eq "Sender"}).Address}},@{n="Recipient";e={($_ | Select-Object -ExpandProperty Addresses | Where-Object{[string]$_.AddressType -eq "Recipient"}).Address}},Signed,Encrypted,MessageId | Export-Csv -Append -NoTypeInformation -Path $reportFile
# exit condition
	if($messageTracks){
		$skipMessageTracks = $skipMessageTracks+100
		Write-Host $skipMessageTracks
	}else{
		$getMessageTracks = $false
		break
	}
}
# send mail if <NoMail> switch is not used and delete temp report file
if (!$NoMail){
	sendMail $ReportRecipient $ReportRecipientCSV
	Remove-Item $reportFile
}
Write-Host "Skript durchgelaufen"