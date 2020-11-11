# Rename this file to Settings-[..].ps1
######################### value replacement #####################



######################### no replacement ########################
[string] $Global:Computer                 = $Env:COMPUTERNAME
[string] $Global:BugCheckCodeReferenceURL = "https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-code-reference2"
[string] $Global:ReportFilePath           = "$ProjectRoot\$($global:gsDATAFolder)\CrashReport-$($Global:Computer)-$(Get-date -format 'dd.MM.yy HH-mm-ss').log"


[bool]  $Global:LocalSettingsSuccessfullyLoaded  = $true
# Error trap
trap {
    $Global:LocalSettingsSuccessfullyLoaded = $False
    exit 1
}
