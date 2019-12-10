<#
.SYNOPSIS
  Name: Get-NspLicenseReport.ps1
  Create NSP license report from the last 90 days.

.DESCRIPTION
  This script can be used to generate a license report either user-based, domain-based or both.
  It is possible to send the report via E-Mail to one or multiple recipients.
	This script uses the NoSpamProxy Powershell Cmdlets and an SQL query to generate the report files.
	The report will be generated always for the past 90 days.

.PARAMETER NoMail
	Does not generate an E-Mail and saves the genereated reports to the current execution location.
	Ideal for testing or manual script usage.

.PARAMETER ReportFileName
  Default: License_Report
	Define a part of the complete file name.
	E.g.: 
	user-based:
	C:\Users\example\Documents\2019-05-27_License_Report_per_user.txt
	domain-based:
	C:\Users\example\Documents\2019-05-27_License_Report_example.com.txt
	
.PARAMETER ReportRecipient
  Specifies the E-Mail recipient. It is possible to pass a comma seperated list to address multiple recipients. 
  E.g.: alice@example.com,bob@example.com

.PARAMETER ReportRecipientCSV
  Set a filepath to an CSV file containing a list of report E-Mail recipient. Be aware about the needed CSV format, please watch the provided example.

.PARAMETER ReportSender
  Default: NoSpamProxy Report Sender <nospamproxy@example.com>
  Sets the report E-Mail sender address.
  
.PARAMETER ReportSubject
  Default: NSP License Report
	Sets the report E-Mail subject.
	
.Parameter ReportType
	Default: user-based
	Sets the type of generated report.
	Possible values are: user-based, domain-based, both

.PARAMETER SmtpHost
  Specifies the SMTP host which should be used to send the report E-Mail.
	It is possible to use a FQDN or IP address.
	
.PARAMETER SqlCredential
	Sets custom credentials for database access.
	By default the authentication is done using current users credentials from memory.

.PARAMETER SqlDatabase
	Default: NoSpamProxyAddressSynchronization
	Sets a custom SQl database name which should be accessed. The required database is the one from the intranet-role.

.PARAMETER SqlInstance
	Default: NoSpamProxy
	Sets a custom SQL instance name which should be accessed. The required instance must contain the intranet-role database.

.PARAMETER SqlServer
	Default: (local)
	Sets a custom SQL server which must contains the instance and the database of the intranet-role.

.OUTPUTS
	Report is temporary stored under %TEMP% if the report is send via by E-Mail.
	If the parameter <NoMail> is used the files will be saved at the current location of the executing user.

.NOTES
  Version:        1.0.2
  Author:         Jan Jaeschke
  Creation Date:  2019-12-10
  Purpose/Change: added encryption details
  
.LINK
  https://https://www.nospamproxy.de
  https://github.com/noSpamProxy

.EXAMPLE
  .\Get-NspLicenseReport.ps1 -ReportRecipient alice@example.com -ReportSender "NoSpamProxy Report Sender <nospamproxy@example.com>" -ReportSubject "Example Report" -SmtpHost mail.example.com
  
.EXAMPLE
  .\Get-NspLicenseReport.ps1 -ReportRecipient alice@example.com -ReportSender "NoSpamProxy Report Sender <nospamproxy@example.com>" -ReportSubject "Example Report" -SmtpHost mail.example.com -ReportRecipientCSV "C:\Users\example\Documents\email-recipient.csv"
  The CSV have to contain the header "Email" else the mail addresses cannot be read from the file. 
  E.g: email-recipient.csv
  User,Email
  user1,user1@example.com
	user2,user2@example.com
	The "User" header is not necessary.

.EXAMPLE
	.\Get-NspLicenseReport.ps1 -NoMail -ReportType both
	Generates a user-based and a domain-based report which are saved at the current location of execution, here: ".\"

.EXAMPLE
	.\Get-NspLicenseReport.ps1 -NoMail -SqlServer sql.example.com -SqlInstance NSPIntranetRole -SqlDatabase NSPIntranet -SqlCredential $Credentials
	This generates a user-based report. Therefore the script connects to the SQL Server "sql.example.com" and accesses the SQL instance "NSPIntranetRole" which contains the "NSPIntranet" database.
	The passed varaible "$Credentials" contains the desired user credentials. (e.x. $Credentials = Get-Credentials)

.EXAMPLE 
	.\Get-NspLicenseReport.ps1 -NoMail -SqlInstance ""
	Use the above instance name "" if you try to access the default SQL instance.
	If there is aconnection problem and the NSP configuration shows an empty instance for the intranet-role under "Configuration -> NoSpamProxy components" than this instance example should work.
#>
param (
# userParams are used for filtering
	# generate the report but do not send an E-Mail
	[Parameter(Mandatory=$false)][switch]$NoMail, 
	# change report filename
	[Parameter(Mandatory=$false)][string] $ReportFileName = "License_Report" ,
	# set report recipient only valid E-Mail addresses are allowed
	[Parameter(Mandatory=$false)][ValidatePattern("^<?[a-zA-Z0-9.!£#$%&'^_`{}~-]+?<?[a-zA-Z0-9.!£#$%&'^_`{}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*>?$")][string[]] $ReportRecipient,
	# set path to csv file containing report recipient E-Mail addresses
	[Parameter(Mandatory=$false)][string] $ReportRecipientCSV,
	# set report sender address only a valid E-Mail addresse is allowed
	[Parameter(Mandatory=$false)][ValidatePattern("^([a-zA-Z0-9\s.!£#$%&'^_`{}~-]+)?<?[a-zA-Z0-9.!£#$%&'^_`{}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*>?$")][string] $ReportSender = "NoSpamProxy Report Sender <nospamproxy@example.com>",
	# change report E-Mail subject
	[Parameter(Mandatory=$false)][string] $ReportSubject = "NSP License Report",
	[Parameter(Mandatory=$false)][ValidateSet('user-based','domain-based','both')][string] $ReportType = "user-based",
	# set used SMTP host for sending report E-Mail only a valid  IP address or FQDN is allowed
	[Parameter(Mandatory=$false)][ValidatePattern("^(((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|(((?!-)[a-zA-Z0-9-]{0,62}[a-zA-Z0-9]\.?)+[a-zA-Z]{2,63}))$")][string] $SmtpHost,
	# sql credentials
	[Parameter(Mandatory=$false)][pscredential] $SqlCredential,
	# database name
	[Parameter(Mandatory=$false)][string] $SqlDatabase = "NoSpamProxyAddressSynchronization",
	# sql server instance
	[Parameter(Mandatory=$false)][string] $SqlInstance = "NoSpamProxy",
	# sql server
	[Parameter(Mandatory=$false)][string] $SqlServer = "(local)",
	# generate detailed report including which encryption features are used
	[Parameter(Mandatory=$false)][switch]$WithEncryptionDetails 
)

#-------------------Functions----------------------
# send report E-Mail 
function sendMail($ReportRecipient, $ReportRecipientCSV, $reportAttachment){ 
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
		Send-MailMessage -SmtpServer $SmtpHost -From $ReportSender -To $mailRecipient -Subject $ReportSubject -Body "Im Anhang dieser E-Mail finden Sie einen automatisch Lizenz-Bericht vom NoSpamProxy" -Attachments $reportAttachment
	}
}

# create database connection
function New-DatabaseConnection() {
	$connectionString = "Server=$SqlServer\$SqlInstance;Database=$SqlDatabase;"
	if ($SqlCredential) {
		$networkCredential = $SqlCredential.GetNetworkCredential()
		$connectionString += "uid=" + $networkCredential.UserName + ";pwd=" + $networkCredential.Password + ";"
	}
	else {
		$connectionString +="Integrated Security=True";
	}
	$connection = New-Object System.Data.SqlClient.SqlConnection
	$connection.ConnectionString = $connectionString
	
	$connection.Open()

	return $connection;
}

# run sql query
function Invoke-SqlQuery([string] $queryName, [bool] $isInlineQuery = $false, [bool] $isSingleResult) {
	try {
		$connection = New-DatabaseConnection
		$command = $connection.CreateCommand()
		if ($isInlineQuery) {
			$command.CommandText = $queryName;
		}
		else {
			$command.CommandText = (Get-Content "$PSScriptRoot\$queryName.sql")
		}
		if ($isSingleResult) {
			return $command.ExecuteScalar();
		}
		else {
			$result = $command.ExecuteReader()
			$table = new-object "System.Data.DataTable"
			$table.Load($result)
			return $table
		}
	}
	finally {
		$connection.Close();
	}
}

# generates user-based report
function userBased($licUsage){
	$userReport = "$reportFile" + "_per_user.txt"
	# the @ sign in each .Count line is needed in the case there is only 1 item
	# in this case PS return this single item instead of an array which breaks .Count
	# get license count per feature
	$protectionLicCount = @($licUsage | Where-Object{$_.Protection -eq 1}).Count
	$encryptionLicCount = @($licUsage | Where-Object{$_.Encryption -eq 1}).Count
	$largeFilesLicCount = @($licUsage | Where-Object{$_.LargeFiles -eq 1}).Count
	$disclaimerLicCount = @($licUsage | Where-Object{$_.Disclaimer -eq 1}).Count
	$sandBoxLicCount = @($licUsage | Where-Object{$_.FilesUploadedToSandbox -eq 1}).Count
	# get users per feature
	$protectionUsers = ($licUsage | Where-Object{$_.Protection -eq 1}).DisplayName
	$encryptionUsers = ($licUsage | Where-Object{$_.Encryption -eq 1}).DisplayName
	$largeFilesUsers = ($licUsage | Where-Object{$_.LargeFiles -eq 1}).DisplayName
	$disclaimerUsers = ($licUsage | Where-Object{$_.Disclaimer -eq 1}).DisplayName
	$sandBoxUsers = ($licUsage | Where-Object{$_.FilesUploadedToSandbox -eq 1}).DisplayName
	# parse detailed information if parameter flag is used
	if ($WithEncryptionDetails){
		$pdfMailsSentCount = @($licUsage | Where-Object{$_.PdfMailsSent -eq 1}).Count
		$sMimeMailsSignedCount = @($licUsage | Where-Object{$_.SMimeMailsSigned -eq 1}).Count
		$sMimeMailsEncryptedCount = @($licUsage | Where-Object{$_.SMimeMailsEncrypted -eq 1}).Count
		$pgpMailsSignedCount = @($licUsage | Where-Object{$_.PgpMailsSigned -eq 1}).Count
		$pgpMailsEncryptedCount = @($licUsage | Where-Object{$_.PgpMailsEncrypted -eq 1}).Count

		$pdfMailsSentUsers = ($licUsage | Where-Object{$_.PdfMailsSent -eq 1}).DisplayName
		$sMimeMailsSignedUsers = ($licUsage | Where-Object{$_.SMimeMailsSigned -eq 1}).DisplayName
		$sMimeMailsEncryptedUsers = ($licUsage | Where-Object{$_.SMimeMailsEncrypted -eq 1}).DisplayName
		$pgpMailsSignedUsers = ($licUsage | Where-Object{$_.PgpMailsSigned -eq 1}).DisplayName
		$pgpMailsEncryptedUsers = ($licUsage | Where-Object{$_.PgpMailsEncrypted -eq 1}).DisplayName
	}
	# generate formated output
	$stream = [System.IO.StreamWriter] $userReport
	$stream.WriteLine("Protection: $protectionLicCount User")
	$stream.WriteLine("-----------------------------")
	$protectionUsers | ForEach-Object{$stream.WriteLine($_)}
	$stream.WriteLine("`r`n`r`nEncryption: $encryptionLicCount User")
	$stream.WriteLine("-----------------------------")
	$encryptionUsers | ForEach-Object{$stream.WriteLine($_)}
	$stream.WriteLine("`r`n`r`nLargeFiles: $largeFilesLicCount User")
	$stream.WriteLine("-----------------------------")
	$largeFilesUsers | ForEach-Object{$stream.WriteLine($_)}
	$stream.WriteLine("`r`n`r`nDisclaimer: $disclaimerLicCount User")
	$stream.WriteLine("-----------------------------")
	$disclaimerUsers | ForEach-Object{$stream.WriteLine($_)}
	$stream.WriteLine("`r`n`r`nSandBox: $sandBoxLicCount User")
	$stream.WriteLine("-----------------------------")
	$sandBoxUsers | ForEach-Object{$stream.WriteLine($_)}
	# print detailed information if parameter flag is used
	if($WithEncryptionDetails){
		$stream.WriteLine("`r`n`r`n`r`nEncryption details")
		$stream.WriteLine("-----------------------------")
		$stream.WriteLine("Please be warned that users can be displayed multiple times.")
		$stream.WriteLine("In this case the number count is not affected.")
        $stream.WriteLine("-----------------------------")
        $stream.WriteLine("`r`nPDF Mail: $pdfMailsSentCount User")
        $stream.WriteLine("-----------------------------")
        $pdfMailsSentUsers | ForEach-Object { $stream.WriteLine($_) }
        $stream.WriteLine("`r`n`r`nSMIME signature: $sMimeMailsSignedCount User")
        $stream.WriteLine("-----------------------------")
        $sMimeMailsSignedUsers | ForEach-Object { $stream.WriteLine($_) }
        $stream.WriteLine("`r`n`r`nSMIME encryption: $sMimeMailsEncryptedCount User")
        $stream.WriteLine("-----------------------------")
        $sMimeMailsEncryptedUsers | ForEach-Object { $stream.WriteLine($_) }
        $stream.WriteLine("`r`n`r`PGP signature: $pgpMailsSignedCount User")
        $stream.WriteLine("-----------------------------")
        $pgpMailsSignedUsers | ForEach-Object { $stream.WriteLine($_) }
        $stream.WriteLine("`r`n`r`PGP encryption: $pgpMailsEncryptedCount User")
        $stream.WriteLine("-----------------------------")
        $pgpMailsEncryptedUsers | ForEach-Object { $stream.WriteLine($_) }
	}
	$stream.Close()

	return $userReport
}

# generates domain-based report
function domainBased($licUsage){
	$ownDomains = ($licUsage.Domain | Get-Unique)
	foreach($domain in $ownDomains){
		$domainReport = "$reportFile" + "_" + "$domain.txt"
		# the @ sign in each .Count line is needed in the case there is only 1 item
		# in this case PS return this single item instead of an array which breaks .Count
		# get license count per feature
		$protectionLicCount = @($licUsage | Where-Object {$_.Protection -eq 1 -and $_.Domain -eq $domain}).Count
		$encryptionLicCount = @($licUsage | Where-Object {$_.Encryption -eq 1 -and $_.Domain -eq $domain}).Count
		$largeFilesLicCount = @($licUsage | Where-Object {$_.LargeFiles -eq 1 -and $_.Domain -eq $domain}).Count
		$disclaimerLicCount = @($licUsage | Where-Object {$_.Disclaimer -eq 1 -and $_.Domain -eq $domain}).Count
		$sandBoxLicCount = @($licUsage | Where-Object {$_.FilesUploadedToSandbox -eq 1 -and $_.Domain -eq $domain}).Count
		# get users per feature
		$protectionUsers = ($licUsage | Where-Object{$_.Protection -eq 1 -and $_.Domain -eq $domain}).DisplayName
		$encryptionUsers = ($licUsage | Where-Object{$_.Encryption -eq 1 -and $_.Domain -eq $domain}).DisplayName
		$largeFilesUsers = ($licUsage | Where-Object{$_.LargeFiles -eq 1 -and $_.Domain -eq $domain}).DisplayName
		$disclaimerUsers = ($licUsage | Where-Object{$_.Disclaimer -eq 1 -and $_.Domain -eq $domain}).DisplayName
		$sandBoxUsers = ($licUsage | Where-Object{$_.FilesUploadedToSandbox -eq 1 -and $_.Domain -eq $domain}).DisplayName

		# parse detailed information if parameter flag is used
		if ($WithEncryptionDetails){
			$pdfMailsSentCount = @($licUsage | Where-Object{$_.PdfMailsSent -eq 1 -and $_.Domain -eq $domain}).Count
			$sMimeMailsSignedCount = @($licUsage | Where-Object{$_.SMimeMailsSigned -eq 1 -and $_.Domain -eq $domain}).Count
			$sMimeMailsEncryptedCount = @($licUsage | Where-Object{$_.SMimeMailsEncrypted -eq 1 -and $_.Domain -eq $domain}).Count
			$pgpMailsSignedCount = @($licUsage | Where-Object{$_.PgpMailsSigned -eq 1 -and $_.Domain -eq $domain}).Count
			$pgpMailsEncryptedCount = @($licUsage | Where-Object{$_.PgpMailsEncrypted -eq 1 -and $_.Domain -eq $domain}).Count
	
			$pdfMailsSentUsers = ($licUsage | Where-Object{$_.PdfMailsSent -eq 1 -and $_.Domain -eq $domain}).DisplayName
			$sMimeMailsSignedUsers = ($licUsage | Where-Object{$_.SMimeMailsSigned -eq 1 -and $_.Domain -eq $domain}).DisplayName
			$sMimeMailsEncryptedUsers = ($licUsage | Where-Object{$_.SMimeMailsEncrypted -eq 1 -and $_.Domain -eq $domain}).DisplayName
			$pgpMailsSignedUsers = ($licUsage | Where-Object{$_.PgpMailsSigned -eq 1 -and $_.Domain -eq $domain}).DisplayName
			$pgpMailsEncryptedUsers = ($licUsage | Where-Object{$_.PgpMailsEncrypted -eq 1 -and $_.Domain -eq $domain}).DisplayName
		}
		# generate formated output
		$stream = [System.IO.StreamWriter] "$domainReport"
		$stream.WriteLine("Protection: $protectionLicCount User")
		$stream.WriteLine("-----------------------------")
		$protectionUsers | ForEach-Object{$stream.WriteLine($_)}
		$stream.WriteLine("`r`n`r`nEncryption: $encryptionLicCount User")
		$stream.WriteLine("-----------------------------")
		$encryptionUsers | ForEach-Object{$stream.WriteLine($_)}
		$stream.WriteLine("`r`n`r`nLargeFiles: $largeFilesLicCount User")
		$stream.WriteLine("-----------------------------")
		$largeFilesUsers | ForEach-Object{$stream.WriteLine($_)}
		$stream.WriteLine("`r`n`r`nDisclaimer: $disclaimerLicCount User")
		$stream.WriteLine("-----------------------------")
		$disclaimerUsers | ForEach-Object{$stream.WriteLine($_)}
		$stream.WriteLine("`r`n`r`nSandBox: $sandBoxLicCount User")
		$stream.WriteLine("-----------------------------")
		$sandBoxUsers | ForEach-Object{$stream.WriteLine($_)}
		# print detailed information if parameter flag is used
		if($WithEncryptionDetails){
			$stream.WriteLine("`r`n`r`n`r`nEncryption details")
			$stream.WriteLine("-----------------------------")
			$stream.WriteLine("Please be warned that users can be displayed multiple times.")
			$stream.WriteLine("In this case the number count is not affected.")
			$stream.WriteLine("-----------------------------")
			$stream.WriteLine("`r`nPDF Mail: $pdfMailsSentCount User")
			$stream.WriteLine("-----------------------------")
			$pdfMailsSentUsers | ForEach-Object { $stream.WriteLine($_) }
			$stream.WriteLine("`r`n`r`nSMIME signature: $sMimeMailsSignedCount User")
			$stream.WriteLine("-----------------------------")
			$sMimeMailsSignedUsers | ForEach-Object { $stream.WriteLine($_) }
			$stream.WriteLine("`r`n`r`nSMIME encryption: $sMimeMailsEncryptedCount User")
			$stream.WriteLine("-----------------------------")
			$sMimeMailsEncryptedUsers | ForEach-Object { $stream.WriteLine($_) }
			$stream.WriteLine("`r`n`r`PGP signature: $pgpMailsSignedCount User")
			$stream.WriteLine("-----------------------------")
			$pgpMailsSignedUsers | ForEach-Object { $stream.WriteLine($_) }
			$stream.WriteLine("`r`n`r`PGP encryption: $pgpMailsEncryptedCount User")
			$stream.WriteLine("-----------------------------")
			$pgpMailsEncryptedUsers | ForEach-Object { $stream.WriteLine($_) }
		}
		$stream.Close()
	}
	return $domainReport
}
#-------------------Variables----------------------
# get the current date for report file name
$reportFileDate = Get-Date -UFormat "%Y-%m-%d"
# define file path of the report file
if ($NoMail){
	$reportFilePath = (Get-Location).Path
} else{
	$reportFilePath = $ENV:TEMP
}
# build the complete default report file path
$reportFile =  "$reportFilePath" + "\" + "$reportFileDate" + "_" + "$ReportFileName"

#--------------------Main-----------------------
$licUsage = Invoke-SqlQuery "LicenseUsage"
if($ReportType){
	switch($ReportType){
		'user-based'{
			$userReport = userBased $licUsage
			# send mail if <NoMail> switch is not used and delete temp report file
			if (!$NoMail){
				sendMail $ReportRecipient $ReportRecipientCSV $userReport
				Remove-Item $userReport
			}
		}
		'domain-based'{
			$domainReport = domainBased $licUsage
			if (!$NoMail){
				sendMail $ReportRecipient $ReportRecipientCSV $domainReport
				Remove-Item $domainReport
			}
		}
		'both'{
			$userReport = userBased $licUsage
			$domainReport = domainBased $licUsage
			if (!$NoMail){
				$bothReports = "$userReport", "$domainReport"
				sendMail $ReportRecipient $ReportRecipientCSV $bothReports
				Remove-Item $userReport
				Remove-Item $domainReport
			}
		}
	}
}
Write-Host "Skript durchgelaufen"
# SIG # Begin signature block
# MIIbigYJKoZIhvcNAQcCoIIbezCCG3cCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUIf3DKreo5tJNNppGE5bhPQ3/
# EFSgghbWMIIElDCCA3ygAwIBAgIOSBtqBybS6D8mAtSCWs0wDQYJKoZIhvcNAQEL
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
# /xrNfYi4zYch/b/ZtjCCBmowggVSoAMCAQICEAMBmgI6/1ixa9bV6uYX8GYwDQYJ
# KoZIhvcNAQEFBQAwYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IElu
# YzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQg
# QXNzdXJlZCBJRCBDQS0xMB4XDTE0MTAyMjAwMDAwMFoXDTI0MTAyMjAwMDAwMFow
# RzELMAkGA1UEBhMCVVMxETAPBgNVBAoTCERpZ2lDZXJ0MSUwIwYDVQQDExxEaWdp
# Q2VydCBUaW1lc3RhbXAgUmVzcG9uZGVyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEAo2Rd/Hyz4II14OD2xirmSXU7zG7gU6mfH2RZ5nxrf2uMnVX4kuOe
# 1VpjWwJJUNmDzm9m7t3LhelfpfnUh3SIRDsZyeX1kZ/GFDmsJOqoSyyRicxeKPRk
# tlC39RKzc5YKZ6O+YZ+u8/0SeHUOplsU/UUjjoZEVX0YhgWMVYd5SEb3yg6Np95O
# X+Koti1ZAmGIYXIYaLm4fO7m5zQvMXeBMB+7NgGN7yfj95rwTDFkjePr+hmHqH7P
# 7IwMNlt6wXq4eMfJBi5GEMiN6ARg27xzdPpO2P6qQPGyznBGg+naQKFZOtkVCVeZ
# VjCT88lhzNAIzGvsYkKRrALA76TwiRGPdwIDAQABo4IDNTCCAzEwDgYDVR0PAQH/
# BAQDAgeAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwggG/
# BgNVHSAEggG2MIIBsjCCAaEGCWCGSAGG/WwHATCCAZIwKAYIKwYBBQUHAgEWHGh0
# dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwggFkBggrBgEFBQcCAjCCAVYeggFS
# AEEAbgB5ACAAdQBzAGUAIABvAGYAIAB0AGgAaQBzACAAQwBlAHIAdABpAGYAaQBj
# AGEAdABlACAAYwBvAG4AcwB0AGkAdAB1AHQAZQBzACAAYQBjAGMAZQBwAHQAYQBu
# AGMAZQAgAG8AZgAgAHQAaABlACAARABpAGcAaQBDAGUAcgB0ACAAQwBQAC8AQwBQ
# AFMAIABhAG4AZAAgAHQAaABlACAAUgBlAGwAeQBpAG4AZwAgAFAAYQByAHQAeQAg
# AEEAZwByAGUAZQBtAGUAbgB0ACAAdwBoAGkAYwBoACAAbABpAG0AaQB0ACAAbABp
# AGEAYgBpAGwAaQB0AHkAIABhAG4AZAAgAGEAcgBlACAAaQBuAGMAbwByAHAAbwBy
# AGEAdABlAGQAIABoAGUAcgBlAGkAbgAgAGIAeQAgAHIAZQBmAGUAcgBlAG4AYwBl
# AC4wCwYJYIZIAYb9bAMVMB8GA1UdIwQYMBaAFBUAEisTmLKZB+0e36K+Vw0rZwLN
# MB0GA1UdDgQWBBRhWk0ktkkynUoqeRqDS/QeicHKfTB9BgNVHR8EdjB0MDigNqA0
# hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURDQS0x
# LmNybDA4oDagNIYyaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNz
# dXJlZElEQ0EtMS5jcmwwdwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRENBLTEuY3J0MA0GCSqGSIb3
# DQEBBQUAA4IBAQCdJX4bM02yJoFcm4bOIyAPgIfliP//sdRqLDHtOhcZcRfNqRu8
# WhY5AJ3jbITkWkD73gYBjDf6m7GdJH7+IKRXrVu3mrBgJuppVyFdNC8fcbCDlBkF
# azWQEKB7l8f2P+fiEUGmvWLZ8Cc9OB0obzpSCfDscGLTYkuw4HOmksDTjjHYL+Nt
# FxMG7uQDthSr849Dp3GdId0UyhVdkkHa+Q+B0Zl0DSbEDn8btfWg8cZ3BigV6diT
# 5VUW8LsKqxzbXEgnZsijiwoc5ZXarsQuWaBh3drzbaJh6YoLbewSGL33VVRAA5Ir
# a8JRwgpIr7DUbuD0FAo6G+OPPcqvao173NhEMIIGzTCCBbWgAwIBAgIQBv35A5YD
# reoACus/J7u6GzANBgkqhkiG9w0BAQUFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UE
# ChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYD
# VQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMDYxMTEwMDAwMDAw
# WhcNMjExMTEwMDAwMDAwWjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNl
# cnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdp
# Q2VydCBBc3N1cmVkIElEIENBLTEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQDogi2Z+crCQpWlgHNAcNKeVlRcqcTSQQaPyTP8TUWRXIGf7Syc+BZZ3561
# JBXCmLm0d0ncicQK2q/LXmvtrbBxMevPOkAMRk2T7It6NggDqww0/hhJgv7HxzFI
# gHweog+SDlDJxofrNj/YMMP/pvf7os1vcyP+rFYFkPAyIRaJxnCI+QWXfaPHQ90C
# 6Ds97bFBo+0/vtuVSMTuHrPyvAwrmdDGXRJCgeGDboJzPyZLFJCuWWYKxI2+0s4G
# rq2Eb0iEm09AufFM8q+Y+/bOQF1c9qjxL6/siSLyaxhlscFzrdfx2M8eCnRcQrho
# frfVdwonVnwPYqQ/MhRglf0HBKIJAgMBAAGjggN6MIIDdjAOBgNVHQ8BAf8EBAMC
# AYYwOwYDVR0lBDQwMgYIKwYBBQUHAwEGCCsGAQUFBwMCBggrBgEFBQcDAwYIKwYB
# BQUHAwQGCCsGAQUFBwMIMIIB0gYDVR0gBIIByTCCAcUwggG0BgpghkgBhv1sAAEE
# MIIBpDA6BggrBgEFBQcCARYuaHR0cDovL3d3dy5kaWdpY2VydC5jb20vc3NsLWNw
# cy1yZXBvc2l0b3J5Lmh0bTCCAWQGCCsGAQUFBwICMIIBVh6CAVIAQQBuAHkAIAB1
# AHMAZQAgAG8AZgAgAHQAaABpAHMAIABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAIABj
# AG8AbgBzAHQAaQB0AHUAdABlAHMAIABhAGMAYwBlAHAAdABhAG4AYwBlACAAbwBm
# ACAAdABoAGUAIABEAGkAZwBpAEMAZQByAHQAIABDAFAALwBDAFAAUwAgAGEAbgBk
# ACAAdABoAGUAIABSAGUAbAB5AGkAbgBnACAAUABhAHIAdAB5ACAAQQBnAHIAZQBl
# AG0AZQBuAHQAIAB3AGgAaQBjAGgAIABsAGkAbQBpAHQAIABsAGkAYQBiAGkAbABp
# AHQAeQAgAGEAbgBkACAAYQByAGUAIABpAG4AYwBvAHIAcABvAHIAYQB0AGUAZAAg
# AGgAZQByAGUAaQBuACAAYgB5ACAAcgBlAGYAZQByAGUAbgBjAGUALjALBglghkgB
# hv1sAxUwEgYDVR0TAQH/BAgwBgEB/wIBADB5BggrBgEFBQcBAQRtMGswJAYIKwYB
# BQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0
# cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDovL2NybDQu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDAdBgNVHQ4E
# FgQUFQASKxOYspkH7R7for5XDStnAs0wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGL
# p6chnfNtyA8wDQYJKoZIhvcNAQEFBQADggEBAEZQPsm3KCSnOB22WymvUs9S6TFH
# q1Zce9UNC0Gz7+x1H3Q48rJcYaKclcNQ5IK5I9G6OoZyrTh4rHVdFxc0ckeFlFbR
# 67s2hHfMJKXzBBlVqefj56tizfuLLZDCwNK1lL1eT7EF0g49GqkUW6aGMWKoqDPk
# mzmnxPXOHXh2lCVz5Cqrz5x2S+1fwksW5EtwTACJHvzFebxMElf+X+EevAJdqP77
# BzhPDcZdkbkPZ0XN1oPt55INjbFpjE/7WeAjD9KqrgB87pxCDs+R1ye3Fu4Pw718
# CqDuLAhVhSK46xgaTfwqIa1JMYNHlXdx3LEbS0scEJx3FMGdTy9alQgpECYxggQe
# MIIEGgIBATBqMFoxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52
# LXNhMTAwLgYDVQQDEydHbG9iYWxTaWduIENvZGVTaWduaW5nIENBIC0gU0hBMjU2
# IC0gRzMCDF8qMMA1ngrijFda+DAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEK
# MAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3
# AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU8HottZXyV/HVns+5
# 1OJUeplm1fswDQYJKoZIhvcNAQEBBQAEggEABYLK2oyAOnZ783RDEf2Gztcf5hNT
# 1wSM5pIhB7F1GKSkJVCHXvhA9VHQrvTwM3X3ByZxVI/rErs5ez7i0JnATnImZjmN
# bc8E8WG5XbTL7Ct7U5ygnb1gLZ/k0QHVog1f/OFmA7fjVMOcq1/8NRw3rdEHKOUR
# QQ0JHILLNobjcMZQQ5/383pDVEpDJ4CUJtdtZqbsKFKzhZ40tpDT/r5ngxO18oyW
# yVBJzdpV0l3JCFdFwYMoWfv8oYLTAmF18Lu16/7PBMProvfS9JmTBYWn5K6YqbDk
# DDsuxFaivclOQPM/lgz8AnMkTr/ER1+SG9T3jKtmocUVmVgLPi0PJqQ+HaGCAg8w
# ggILBgkqhkiG9w0BCQYxggH8MIIB+AIBATB2MGIxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAf
# BgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQgQ0EtMQIQAwGaAjr/WLFr1tXq5hfw
# ZjAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG
# 9w0BCQUxDxcNMTkxMjEwMTAwMjM0WjAjBgkqhkiG9w0BCQQxFgQUqU6xDYxcnQPM
# PN7ZE43YW51P3jAwDQYJKoZIhvcNAQEBBQAEggEAaTn8bh4nrKbWpJB8KapQhPVc
# LtHXNAA3xIWNHSXH5Bk6t2IDGbK8O32MxMBcMJjdwmWdhX/rZFDS7y1xpIaBJH3K
# ZK6/GHrW7o0E2LvAscCS3kcCS87qn7llMx2miEEbbtJbPoIct2f8x+Vgiq7iOrum
# kZRUC7a4PxXhc7kPXSiOnW1eerAv0QGdmBKtNevUBar1cCfYOfo67VY3CkxuK0GM
# iVwrmmPd91/fYduGHNVjhm/eJkU18meNrvWFPhtjuhccHaxx+fxnzqX/In5k9rPh
# xf2cvNt9zZ3LFLlWflv5m8b6A48rpBw/ReGwpp89BwFnkkrnnmShCJM0IMsaug==
# SIG # End signature block
