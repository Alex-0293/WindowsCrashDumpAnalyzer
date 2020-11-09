# Rename this file to Settings.ps1
######################### value replacement #####################



######################### no replacement ########################



[bool]  $Global:LocalSettingsSuccessfullyLoaded  = $true
# Error trap
trap {
    $Global:LocalSettingsSuccessfullyLoaded = $False
    exit 1
}
