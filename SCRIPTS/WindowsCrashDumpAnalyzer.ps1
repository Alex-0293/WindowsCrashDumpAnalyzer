<#
    .SYNOPSIS
        WindowsCrashDumpAnalyzer
    .DESCRIPTION
        Find crash events and analyze crash dumps.
    .COMPONENT
        AlexKUtils
    .LINK
        https://github.com/Alex-0293/WindowsCrashDumpAnalyzer.git
    .NOTES
        AUTHOR  AlexK (1928311@tuta.io)
        CREATED 09.11.20
        VER     1
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

$Global:gsGitMetaData.Commit  = $true
$Global:gsGitMetaData.Message = "[Fix] time format in interval header."
$Global:gsGitMetaData.Branch  = "master"

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

# https://docs.microsoft.com/en-us/windows/client-management/troubleshoot-stop-errors
# Windows Debugging Tools for Windows should be installed
# https://developer.microsoft.com/en-us/windows/downloads/windows-10-sdk/
# https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-code-reference2

function Get-ErrorCodeTrim {
<#
    .SYNOPSIS
        Get error code trim
    .EXAMPLE
        Get-ErrorCodeTrim [-ErrorCode $ErrorCode]
    .NOTES
        AUTHOR  Alexk
        CREATED 11.11.20
        VER     1
#>
    param(
        [string] $ErrorCode
    )

    $Array = $ErrorCode.split("x")
    $Num = ([uint64] $ErrorCode).ToString('x')

    return "$($Array[0])x$Num"
}

[string[]] $DumpFileLocations = "%SystemRoot%\MEMORY.DMP", "%SystemRoot%\Minidump\*.dmp"

[int[]] $CrashEvents = 1001

$DumpFiles = @()

$Filter = @{
    LogName = "System"
    Id      = $CrashEvents
}

$EventArray        = Get-WinEvent -FilterHashTable $Filter -ComputerName $Computer
$EventId1001       = $EventArray | Where-Object { $_.id -eq 1001} | sort-object message
$EventId1001Object = @()
$Details           = @()
$Detail            = $null

$OS       = Get-CimInstance Win32_OperatingSystem -ComputerName $Computer
$OSFamily = ($OS.Caption.Split(" ")[1..2]) -join "+"

foreach ( $item in $EventId1001 ) {
    $Array = $Item.message.split(".").trim()
    if ( $Array.count -gt 1 ) {
        $ErrorCode  = $array[1].split(":")[1].trim().split(" ")[0]
        $Parameters = $array[1].split(":")[1].trim().split("(")[1].replace(")","").split(",")
        $Param1     = $Parameters[0]
        $Query      = "$OSFamily+Bug+Check+$($ErrorCode)+$($Param1)"
        $SearchURL  = "https://duckduckgo.com/?q=$Query&t=ffab&ia=web"

        Write-Host "    Processing: [$($Array[0])] [$ErrorCode] [$Param1]" -ForegroundColor DarkBlue

        if ( $details ) {
            $Detail = $details | Where-Object { ( $_.ErrorCode -eq $ErrorCode ) -and ( $_.Param1 -eq $Param1 ) }
        }

        if ( !$Detail ) {
            if ( $PrevErrorCode -ne $ErrorCode ){
                $TrimErrorCode = Get-ErrorCodeTrim -ErrorCode $ErrorCode
                $TrimParam1    = Get-ErrorCodeTrim -ErrorCode $Param1

                $Reference = Invoke-WebRequest -Uri $Global:BugCheckCodeReferenceURL
                $BugLink   = @()
                foreach ( $link in $Reference.links) {
                    if ( $link.href -like "*-$TrimErrorCode-*" ) {
                        $BugLink += $link
                    }
                }
                #$BugLink =  $Reference | where-object { $_.links.href -like "*$TrimErrorCode*" }
                if ( $BugLink ){
                    $DocURL    = "$(Split-Path -path $Global:BugCheckCodeReferenceURL -parent)\$( $BugLink[0].href )".replace("\","/")
                    $Reference = Invoke-WebRequest -Uri $DocURL

                    $Src  = [System.Text.Encoding]::Unicode.GetBytes( $reference.Content )
                    $HTML = New-Object -ComObject "HTMLFile"
                    $HTML.write( $Src )

                    $Header = $HTML.All | Where-Object {$_.tagName -eq "H1" -and $_.innerText -ne $null} |  Select-Object -ExpandProperty innerText
                    $Table  = $HTML.All | Where-Object {$_.tagName -eq "TD" -and $_.innerText -ne $null} |  Select-Object -ExpandProperty innerText
                    if ( $table.count -eq 8 ){
                        $Param1Details = $table
                    }
                    Else {
                        $Param1Index   = $Table.IndexOf($TrimParam1)
                        $Param1Details = $Table[$Param1Index..($Param1Index+1)]
                    }

                    $Detail = [PSCustomObject]@{
                        ErrorCode     = $ErrorCode
                        Param1        = $Param1
                        DocURL        = $DocURL
                        SearchURL     = $SearchURL
                        Header        = $Header
                        Param1Details = $Param1Details
                    }

                    $Details += $Detail

                }
                Else {
                    Write-host "Error code [$ErrorCode] not found, on the reference site [https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-code-reference2]."

                    $Detail = [PSCustomObject]@{
                        ErrorCode     = $ErrorCode
                        Param1        = $Param1
                        DocURL        = ""
                        SearchURL     = $SearchURL
                        Header        = ""
                        Param1Details = ""
                    }
                    $Details += $Detail
                }
            }
            Else {
                if ( $BugLink ){
                    $DocURL    = "$(Split-Path -path $Global:BugCheckCodeReferenceURL -parent)\$( $BugLink[0].href )".replace("\","/")
                    $Reference = Invoke-WebRequest -Uri $DocURL

                    $Src  = [System.Text.Encoding]::Unicode.GetBytes( $reference.Content )
                    $HTML = New-Object -ComObject "HTMLFile"
                    $HTML.write( $Src )

                    $Header = $HTML.All | Where-Object {$_.tagName -eq "H1" -and $_.innerText -ne $null} |  Select-Object -ExpandProperty innerText
                    $Table  = $HTML.All | Where-Object {$_.tagName -eq "TD" -and $_.innerText -ne $null} |  Select-Object -ExpandProperty innerText
                    if ( $table.count -eq 8 ){
                        $Param1Details = $table
                    }
                    Else {
                        $Param1Index   = $Table.IndexOf($TrimParam1)
                        $Param1Details = $Table[$Param1Index..($Param1Index+1)]
                    }

                    $Detail = [PSCustomObject]@{
                        ErrorCode     = $ErrorCode
                        Param1        = $Param1
                        DocURL        = $DocURL
                        SearchURL     = $SearchURL
                        Header        = $Header
                        Param1Details = $Param1Details
                    }

                    $Details += $Detail

                }
                Else {
                    Write-host "Error code [$ErrorCode] not found, on the reference site [https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-code-reference2]."

                    $Detail = [PSCustomObject]@{
                        ErrorCode     = $ErrorCode
                        Param1        = $Param1
                        DocURL        = ""
                        SearchURL     = $SearchURL
                        Header        = ""
                        Param1Details = ""
                    }
                    $Details += $Detail
                }
            }
        }
        Else {
        }

        if ( $array[3] -ne "DMP" ) {
            $DumpArray   = $array[2]
            $ReportArray = $array[3]
        }
        Else {
            $DumpArray   = "$($array[2]).$($array[3])"
            $ReportArray = $array[4]
        }

        $PSO         = [PSCustomObject]@{
            Date         = [datetime] $Item.TimeCreated
            EventId      = $item.Id
            LogName      = $item.LogName
            RecordId     = $item.RecordId
            ProviderName = $item.ProviderName
            Error        = $Array[0]
            ErrorCode    = $ErrorCode
            Parameter1   = $Parameters[0].trim()
            Parameter2   = $Parameters[1].trim()
            Parameter3   = $Parameters[2].trim()
            Parameter4   = $Parameters[3].trim()
            DumpFilePath = "$($DumpArray.split(":")[1].trim()):$($DumpArray.split(":")[2].trim())"
            ReportId     = $ReportArray.split(":")[1].trim()
            DocURL       = $Detail.DocURL
            SearchURL    = $Detail.SearchURL
            Header       = $Detail.Header
            Param1Detail = $Detail.Param1Details
        }
        $EventId1001Object += $PSO

        $PrevErrorCode = $ErrorCode
    }
}


$ErrorGroups = $EventId1001Object | Group-Object ErrorCode | Sort-Object Count -Descending
#$ErrorGroups | Format-Table

[string[]] $Report = @()
$Report += "Generated: [$(Get-Date -Format $Global:gsGlobalDateTimeFormat)]"
$Report += "Interval:  [$(($EventId1001Object | Sort-Object date | Select-Object -first 1).Date.ToString($Global:gsGlobalDateTimeFormat)) - $(($EventId1001Object | Sort-Object date -Descending | Select-Object -first 1).Date.ToString($Global:gsGlobalDateTimeFormat))]"
$Report += "By:        [$($Global:gsRunningCredentials.Name)]"
$Report += "Host:      [$Computer]"
$Report += "======================"
$Report += ""
foreach ( $ErrorGroup in $ErrorGroups ){
    write-host ""
    $Report += ""
    write-host "Header:    [$($ErrorGroup.group[0].Header)]" -ForegroundColor DarkBlue
    $Report += "Header:    [$($ErrorGroup.group[0].Header)]"
    write-host "Error:     [$($ErrorGroup.group[0].Error)]" -ForegroundColor DarkBlue
    $Report += "Error:     [$($ErrorGroup.group[0].Error)]"
    write-host "DocURL:    [$($ErrorGroup.group[0].DocURL)]" -ForegroundColor DarkBlue
    $Report += "DocURL:    [$($ErrorGroup.group[0].DocURL)]"
    write-host "Count:     [$($ErrorGroup.count)]" -ForegroundColor DarkBlue
    $Report += "Count:     [$($ErrorGroup.count)]"

    #$ErrorGroup | Select-Object -ExpandProperty group | ForEach-Object {$_.Date.ToString($Global:gsGlobalDateTimeFormat)} | out-null

    $Result = "$($ErrorGroup | Select-Object -ExpandProperty group | select-object Date, EventId, LogName, RecordId, ProviderName, ErrorCode, Parameter1, Parameter2, Parameter3,Parameter4, DumpFilePath, ReportId, SearchURL, Param1Detail | Sort-Object date, parameter1, parameter2, parameter3, parameter4  -Descending | select-object @{Name = "Date"; exp={$_.Date.ToString($Global:gsGlobalDateTimeFormat)}}, EventId, LogName, RecordId, ProviderName, ErrorCode, Parameter1, Parameter2, Parameter3,Parameter4, DumpFilePath, ReportId, SearchURL, Param1Detail | Out-String)"

    foreach ( $line in $Result.split("`n") ){
       write-host "    $line" -ForegroundColor Blue
       $Report += "    $line".Replace("`r","")
    }
}

if ( $Details ) {
    write-host ""
    $Report += ""
    write-host "Unique errors: [$($Details.count)]" -ForegroundColor DarkBlue
    $Report += "Unique errors: [$($Details.count)]"
    write-host "$($Details | sort-object ErrorCode, Param1 | Format-Table | Out-String)" -ForegroundColor Blue
    $Report += "$($Details | sort-object ErrorCode, Param1 | Format-Table | Out-String)"
    $Report | Out-File -FilePath $Global:ReportFilePath  | out-null

    write-host ""
    $Report += ""
    write-host "Errors by date: [$($EventId1001Object.count)]" -ForegroundColor DarkBlue
    $Report += "Errors by date: [$($EventId1001Object.count)]"

    #$EventId1001Object | ForEach-Object {$_.Date.ToString($Global:gsGlobalDateTimeFormat)}
    $Result = "$($EventId1001Object | Select-Object Date, ErrorCode, Param1, header, DocURL| sort-object Date, ErrorCode, Param1 -Descending | Select-Object @{Name = "Date"; exp={$_.Date.ToString($Global:gsGlobalDateTimeFormat)}}, ErrorCode, Param1, header, DocURL | Format-Table -AutoSize | Out-String)"
    write-host $Result -ForegroundColor Blue
    $Report += $Result
    $Report | Out-File -FilePath $Global:ReportFilePath
}

################################# Script end here ###################################
. "$($Global:gsGlobalSettingsPath)\$($Global:gsSCRIPTSFolder)\Finish.ps1"