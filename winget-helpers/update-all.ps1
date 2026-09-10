<#
.SYNOPSIS
    Updates all WinGet-installed apps silently.

.NOTES
    Requires administrator rights.
#>

# -------------------------------------------------
#   Emoji characters
#   Defined by Unicode code points
# -------------------------------------------------

$RocketEmoji   = [char]::ConvertFromUtf32(0x1F680) # 🚀
$SearchEmoji   = [char]::ConvertFromUtf32(0x1F50E) # 🔎
$PackageEmoji  = [char]::ConvertFromUtf32(0x1F4E6) # 📦
$GearEmoji     = [char]::ConvertFromUtf32(0x2699)  # ⚙
$SuccessEmoji  = [char]::ConvertFromUtf32(0x2705)  # ✅
$WarningEmoji  = [char]::ConvertFromUtf32(0x2757)  # ❗
$InfoEmoji     = [char]::ConvertFromUtf32(0x2139) + [char]::ConvertFromUtf32(0xFE0F) # ℹ️
$FinishEmoji   = [char]::ConvertFromUtf32(0x1F3C1) # 🏁
$SparkleEmoji  = [char]::ConvertFromUtf32(0x2728)  # ✨
$ClockEmoji    = [char]::ConvertFromUtf32(0x23F1) + [char]::ConvertFromUtf32(0xFE0F) # ⏱️

# -------------------------------------------------
#   Configuration
# -------------------------------------------------

$RootPath = if ($PSScriptRoot) {
    $PSScriptRoot
}
else {
    (Get-Location).Path
}

$LogFolder = Join-Path $RootPath "logs"
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile   = Join-Path $LogFolder "update-all_$TimeStamp.log"

# -------------------------------------------------
#   Prepare logging
# -------------------------------------------------

if (-not (Test-Path -LiteralPath $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $Entry = "$(Get-Date -Format 'u') | $Message"
    $Entry | Tee-Object -FilePath $LogFile -Append
}

# -------------------------------------------------
#   Start update
# -------------------------------------------------

$StartTime = Get-Date

Write-Log "$RocketEmoji Starting global WinGet update."
Write-Log "$GearEmoji Preparing silent application upgrades."

# -------------------------------------------------
#   Check for WinGet
# -------------------------------------------------

Write-Log "$SearchEmoji Looking for winget.exe..."

$WingetCommand = Get-Command winget.exe -ErrorAction SilentlyContinue

if ($null -eq $WingetCommand) {
    Write-Log "$WarningEmoji winget.exe was not found on this system."
    Write-Log "$InfoEmoji Install or repair the App Installer package before running this script."
    exit 1
}

Write-Log "$SuccessEmoji WinGet found at: $($WingetCommand.Source)"
Write-Log "$PackageEmoji Checking for available application updates..."

# -------------------------------------------------
#   Run upgrades
# -------------------------------------------------

try {
    Write-Log "$GearEmoji Starting all available upgrades."
    Write-Log "$InfoEmoji Agreement prompts and interactive prompts are disabled."

    & winget.exe upgrade --all --silent `
        --accept-source-agreements `
        --accept-package-agreements `
        --disable-interactivity 2>&1 |
        Tee-Object -FilePath $LogFile -Append

    $WingetExitCode = $LASTEXITCODE

    if ($WingetExitCode -eq 0) {
        Write-Log "$SuccessEmoji WinGet completed the upgrade process successfully."
        Write-Log "$SparkleEmoji All available application upgrades have been processed."
    }
    else {
        Write-Log "$WarningEmoji WinGet returned exit code $WingetExitCode."
        Write-Log "$InfoEmoji Some applications may not have updated."
        exit $WingetExitCode
    }
}
catch {
    Write-Log "$WarningEmoji Update process failed: $($_.Exception.Message)"
    exit 1
}

# -------------------------------------------------
#   Completion message
# -------------------------------------------------

$EndTime = Get-Date
$ElapsedTime = $EndTime - $StartTime
$Duration = "{0:hh\:mm\:ss}" -f $ElapsedTime

Write-Log "$ClockEmoji Total update duration: $Duration"
Write-Log "$FinishEmoji Update process finished."
Write-Log "$SuccessEmoji Log saved to: $LogFile"
