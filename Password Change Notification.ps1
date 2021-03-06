#
# Modified fokkre
# Version 1.2 Feb 2015 (Previous
# Version 1.3 Feb 2015 - Added Log Purging
#
#
#################################################################################################################
# Version 1.1 
# Original Auther - Robert Pearman (WSSMB MVP) of TitleRequried.com
# Script to Automated Email Reminders when Users Passwords due to Expire.
#
# Requires: Windows PowerShell Module for Active Directory
#
# For assistance and ideas, visit the TechNet Gallery Q&A Page. http://gallery.technet.microsoft.com/Password-Expiry-Email-177c3e27/view/Discussions#content
#
##################################################################################################################
# Please Configure the following variables
$date = Get-Date -format ddMMyyyy # Used for readability in log file
$smtpServer="mail.yourdomain.com" # Mail server
$expireindays = 10 # Number of days left to start sending notifications
$from = "Support - I.T. Team <support@yourdoming.com>" # From Email Address
$logging = "Enabled" # Set to Disabled to Disable Logging
$logFile = "C:\Password Notification Script\notification-log-$date.csv" # ie. c:\mylog.csv
$testing = "Enabled" # Set to Disabled to Email Users
$testRecipient = "test@yourdomain.com" # Email used when testing is enabled.
# Please Configure the following 
$todaydate = Get-Date # Used to calculate against lastWrite
$days = 1  # Number of days to keep logs
$targetFolder = "C:\Password Notification Script"  # Folder where logs have been placed
$extension = "*.csv" # Extension of type of log to be purged
$lastWrite = $todaydate.AddDays(-$days) # Calculate cut off date/time for deletion.
#
###################################################################################################################

# Check Logging Settings
if (($logging) -eq "Enabled")
{
    # Test Log File Path
    $logfilePath = (Test-Path $logFile)
    if (($logFilePath) -ne "True")
    {
        # Create CSV File and Headers
        New-Item $logfile -ItemType File
        Add-Content $logfile "Date,Name,EmailAddress,DaystoExpire,ExpiresOn"
    }

    
} # End Logging Check

# Get Users From AD who are Enabled, Passwords Expire and are Not Currently Expired
Import-Module ActiveDirectory
$users = get-aduser -filter * -properties GivenName, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress |where {$_.Enabled -eq "True"} | where { $_.PasswordNeverExpires -eq $false } | where { $_.passwordexpired -eq $false }
$maxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge

# Process Each User for Password Expiry
foreach ($user in $users)
{
    $Name = (Get-ADUser $user | foreach { $_.GivenName})
    $emailaddress = $user.emailaddress
    $passwordSetDate = (get-aduser $user -properties * | foreach { $_.PasswordLastSet })
    $PasswordPol = (Get-AduserResultantPasswordPolicy $user)
    # Check for Fine Grained Password
    if (($PasswordPol) -ne $null)
    {
        $maxPasswordAge = ($PasswordPol).MaxPasswordAge
    }
  
    $expireson = $passwordsetdate + $maxPasswordAge
    $today = (get-date)
    $daystoexpire = (New-TimeSpan -Start $today -End $Expireson).Days
        
    # Set Greeting based on Number of Days to Expiry.

    # Check Number of Days to Expiry
    $messageDays = $daystoexpire

    if (($messageDays) -ge "1")
    {
        $messageDays = "in " + "$daystoexpire" + " days."
    }
    else
    {
        $messageDays = "today."
    }

    # Email Subject Set Here
    $subject="Your password will expire $messageDays"
  
    # Email Body Set Here, Note You can use HTML, including Images.
    $body ="
    Dear $name,
    <p> Your Password will expire $messageDays.<br>
    To change your password on a PC press CTRL ALT Delete and choose Change Password. <br>
    To change your password on Citrix goto Start and select Windows Security, then choose Change Password. <br>
    <p>Thanks, <br>
	IT Support
    </P>"

   
    # If Testing Is Enabled - Email Administrator
    if (($testing) -eq "Enabled")
    {
        $emailaddress = $testRecipient
    } # End Testing

    # If a user has no email address listed
    if (($emailaddress) -eq $null)
    {
        $emailaddress = $testRecipient    
    }# End No Valid Email

    # Send Email Message
    if (($daystoexpire -ge "1") -and ($daystoexpire -lt $expireindays))
    {
         # If Logging is Enabled Log Details
        if (($logging) -eq "Enabled")
        {
            Add-Content $logfile "$date,$Name,$emailaddress,$daystoExpire,$expireson" 
        }
        # Send Email Message
        Send-Mailmessage -smtpServer $smtpServer -from $from -to $emailaddress -subject $subject -body $body -bodyasHTML -priority High  

    } # End Send Message
    
} # End User Processing

# Get files based on last write filter and within the target folder
$files = Get-ChildItem $targetFolder -Include $extension -Recurse  | where {$_.LastWriteTime -le "$lastWrite"}

foreach ($file in $files)
{
if ($file -ne $Null)
{
Add-Content $logfile "Deleting File $file"
Remove-item $file.FullName | Out-Null
}
}


# End