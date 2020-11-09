<#
    .NOTES
        AUTHOR  AlexK (1928311@tuta.io)
        CREATED 09.11.2020
        VER     1
        LANG    En
    .LINK
        https://github.com/Alex-0293/WindowsCrashDumpAnalyzer.git
    .COMPONENT
        
    .SYNOPSIS
        %Synopsis%
    .DESCRIPTION
        Find crash events and analyze crash dumps.
    .EXAMPLE
        WindowsCrashDumpAnalyzer.ps1

#>
Param (
    [Parameter( Mandatory = $false, Position = 0, HelpMessage = "Initialize global settings." )]
    [bool] $InitGlobal = $true,
    [Parameter( Mandatory = $false, Position = 1, HelpMessage = "Initialize local settings." )]
    [bool] $InitLocal  = $true
)

$Global:ScriptInvocation = $MyInvocation
if ($env:AlexKFrameworkInitScript){
    . "$env:AlexKFrameworkInitScript" -MyScriptRoot (Split-Path $PSCommandPath -Parent) -InitGlobal $InitGlobal -InitLocal $InitLocal
} Else {
    Write-host "Environmental variable [AlexKFrameworkInitScript] does not exist!" -ForegroundColor Red
     exit 1
}
if ($LastExitCode) { exit 1 }

# Error trap
trap {
    if (get-module -FullyQualifiedName AlexkUtils) {
        Get-ErrorReporting $_
        . "$($Global:gsGlobalSettingsPath)\$($Global:gsSCRIPTSFolder)\Finish.ps1"
    }
    Else {
        Write-Host "[$($MyInvocation.MyCommand.path)] There is error before logging initialized. Error: $_" -ForegroundColor Red
    }
    exit 1
}
#################################  Mermaid diagram  #################################
<#
```mermaid

```
#>
################################# Script start here #################################






################################# Script end here ###################################
. "$($Global:gsGlobalSettingsPath)\$($Global:gsSCRIPTSFolder)\Finish.ps1"
