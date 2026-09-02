<#
.SYNOPSIS
    User-based script to remove selected pre-installed AppX applications
    for the current user.

.DESCRIPTION
    Uses the native AppX PowerShell module and does not require WinGet.
    Automatically purges log and report files older than 30 days.

.NOTES
    Can be run from a standard or elevated PowerShell session.
#>

# -------------------------------------------------
#   Emoji characters
#   Defined by Unicode code points to prevent encoding errors
# -------------------------------------------------

$SuccessEmoji  = [char]::ConvertFromUtf32(0x2705)
$WarningEmoji  = [char]::ConvertFromUtf32(0x26A0) + [char]::ConvertFromUtf32(0xFE0F)
$ErrorEmoji    = [char]::ConvertFromUtf32(0x2757)
$InfoEmoji     = [char]::ConvertFromUtf32(0x2139) + [char]::ConvertFromUtf32(0xFE0F)
$CalendarEmoji = [char]::ConvertFromUtf32(0x1F4C5)
$TargetEmoji   = [char]::ConvertFromUtf32(0x1F3AF)
$GearEmoji     = [char]::ConvertFromUtf32(0x2699) + [char]::ConvertFromUtf32(0xFE0F)
$SearchEmoji   = [char]::ConvertFromUtf32(0x1F50D)
$TrashEmoji    = [char]::ConvertFromUtf32(0x1F5D1) + [char]::ConvertFromUtf32(0xFE0F)
$FinishEmoji   = [char]::ConvertFromUtf32(0x1F3C1)
$WritingEmoji  = [char]::ConvertFromUtf32(0x1F4DD)
$PageEmoji     = [char]::ConvertFromUtf32(0x1F4C4)
$SparkleEmoji  = [char]::ConvertFromUtf32(0x2728)
$PackageEmoji  = [char]::ConvertFromUtf32(0x1F4E6)
$GreenEmoji    = [char]::ConvertFromUtf32(0x1F7E2)
$StarEmoji     = [char]::ConvertFromUtf32(0x1F31F)
$LockEmoji     = [char]::ConvertFromUtf32(0x1F512)
$RedEmoji      = [char]::ConvertFromUtf32(0x1F534)

# -------------------------------------------------
#   Configuration
# -------------------------------------------------

$RootPath = if ($PSScriptRoot) {
    $PSScriptRoot
}
else {
    (Get-Location).Path
}

$ExportFolder = Join-Path $RootPath "reports"
$LogFolder    = Join-Path $RootPath "logs"
$TimeStamp    = Get-Date -Format "yyyyMMdd_HHmmss"

$LogFile    = Join-Path $LogFolder "uninstall-bloat_$TimeStamp.log"
$ReportFile = Join-Path $ExportFolder "debloat-summary_$TimeStamp.txt"

# -------------------------------------------------
#   Vetted bloatware package list
# -------------------------------------------------

$BloatIds = @(
    # Core baseline
    "Microsoft.3DBuilder",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameCallableUI",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.People",
    "Microsoft.Getstarted",
    "Microsoft.SkypeApp",

    # Modern OS tracking, feeds, and widgets
    "MicrosoftWindows.Client.WebExperience",
    "Microsoft.Windows.Ai.Copilot.Provider",
    "Microsoft.Copilot",
    "Microsoft.Microsoft365Copilot",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.YourPhone",
    "Microsoft.GetHelp",
    "Microsoft.WindowsMaps",

    # Advertising and news feeds
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.BingSearch",
    "Microsoft.BingFinance",
    "Microsoft.BingSports",
    "Microsoft.News",

    # Xbox and gaming modules
    "Microsoft.GamingApp",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.Edge.GameAssist",
    "Microsoft.MicrosoftSolitaireCollection",

    # Office, media, and utilities
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.Office.OneNote",
    "Microsoft.Todos",
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.Clipchamp.Clipchamp",
    "Clipchamp.Clipchamp",
    "Microsoft.Whiteboard",
    "Microsoft.MixedReality.Portal",
    "Microsoft.ScreenSketch",

    # Built-in system tools
    "Microsoft.WindowsAlarms",
    "Microsoft.SoundRecorder",
    "Microsoft.WindowsCamera",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.Wallet",
    "Microsoft.Messaging",
    "Microsoft.OneConnect",
    "Microsoft.549981C3F5F10",

    # Consumer and third-party applications
    "SpotifyAB.SpotifyMusic",
    "Disney.DisneyPlus",
    "Netflix.Netflix",
    "AdobeSystemsIncorporated.AdobePhotoshopExpress",
    "PandoraMediaInc.29160A0A7A14F",
    "HuluLLC.Hulu",
    "King.com.CandyCrushSaga",
    "King.com.CandyCrushSodaSaga",
    "WinZipUniversal",
    "Fitbit.FitbitCoach",

    # OEM vendor applications
    "DellInc.DellDigitalDelivery",
    "DellInc.DellHelpandSupport",
    "DellInc.DellUpdate",
    "DellInc.DellOptimizer",
    "DellInc.SupportAssist",
    "Hewlett-Packard.HPPrivacySettings",
    "Hewlett-Packard.HPQuickDrop",
    "Hewlett-Packard.HPSmart",
    "Hewlett-Packard.HPSupportAssistant",
    "LenovoCorporation.LenovoVantage",
    "Lenovo.LenovoWelcome",
    "ASUSTeKComputerInc.ArmouryCrate",
    "ASUSTeKComputerInc.MyASUS",
    "AcerIncorporated.AcerCareCenter"
)

# -------------------------------------------------
#   Create folders
# -------------------------------------------------

if (-not (Test-Path -LiteralPath $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $ExportFolder)) {
    New-Item -ItemType Directory -Path $ExportFolder -Force | Out-Null
}

# -------------------------------------------------
#   Logging helper
# -------------------------------------------------

function Write-Log {
    param (
        [string]$Message,

        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    switch ($Level) {
        "SUCCESS" {
            $LevelLabel = "[$SuccessEmoji SUCCESS]"
        }

        "WARN" {
            $LevelLabel = "[$WarningEmoji WARNING]"
        }

        "ERROR" {
            $LevelLabel = "[$ErrorEmoji ERROR]  "
        }

        default {
            $LevelLabel = "[$InfoEmoji INFO]   "
        }
    }

    $Entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $LevelLabel | $Message"
    $Entry | Tee-Object -FilePath $LogFile -Append
}

# -------------------------------------------------
#   ASCII banner helper
# -------------------------------------------------

function Get-AsciiHeader {
    $Art = @"
===================================================================================
 ______   _______  ______   _        _______  _______ _________ _______  ______
(  __  \ (  ____ \(  __  \ ( \      (  ___  )(  ___  )\__   __/(  ____ \(  __  \
| (  \  )| (    \/| (  \  )| (      | (   ) || (   ) |   ) (   | (    \/| (  \  )
| |   ) || (__    | |   ) || |      | |   | || (___) |   | |   | (__    | |   ) |
| |   | ||  __)   | |   | || |      | |   | ||  ___  |   | |   |  __)   | |   | |
| |   ) || (      | |   ) || |      | |   | || (   ) |   | |   | (      | |   ) |
| (__/  )| (____/\| (__/  )| (____/\| (___) || )   ( |   | |   | (____/\| (__/  )
(______/ (_______/(______/ (_______/(_______)|/     \|   )_(   (_______/(______/

===================================================================================
$CalendarEmoji Execution Date : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
$TargetEmoji   Target Scope   : Current User Profile Only
$GearEmoji     Engine Status  : AppX Module Processing Complete
===================================================================================

"@

    return $Art
}

# -------------------------------------------------
#   Retention cleanup
# -------------------------------------------------

$CutoffDate = (Get-Date).AddDays(-30)
$TargetPaths = @($LogFolder, $ExportFolder)

foreach ($Target in $TargetPaths) {
    if (Test-Path -LiteralPath $Target) {
        $ExpiredFiles = Get-ChildItem -LiteralPath $Target -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.LastWriteTime -lt $CutoffDate
            }

        foreach ($File in $ExpiredFiles) {
            Remove-Item -LiteralPath $File.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

# -------------------------------------------------
#   Execution engine
# -------------------------------------------------

Write-Log "$SearchEmoji Starting bloatware removal." -Level INFO

$RemovedApps = New-Object "System.Collections.Generic.List[string]"
$FailedApps  = New-Object "System.Collections.Generic.List[string]"

foreach ($Id in $BloatIds) {
    Write-Log "$TrashEmoji Attempting to uninstall $Id ..." -Level INFO

    try {
        $UserPackages = @(Get-AppxPackage -Name $Id -ErrorAction SilentlyContinue)

        if ($UserPackages.Count -gt 0) {
            foreach ($UserPackage in $UserPackages) {
                $UserPackage | Remove-AppxPackage -ErrorAction Stop
            }

            Write-Log "$SuccessEmoji $Id removed successfully." -Level SUCCESS
            $RemovedApps.Add($Id)
        }
        else {
            Write-Log "$InfoEmoji $Id was not present on this profile." -Level INFO
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Log "$WarningEmoji Could not remove $Id - $ErrorMessage" -Level ERROR
        $FailedApps.Add("$Id ($ErrorMessage)")
    }
}

Write-Log "$FinishEmoji Bloatware purge complete." -Level SUCCESS

# -------------------------------------------------
#   Generate text report
# -------------------------------------------------

Write-Log "$WritingEmoji Generating text-based deployment manifest." -Level INFO

$ReportContent = New-Object System.Text.StringBuilder
$null = $ReportContent.AppendLine((Get-AsciiHeader))

if ($RemovedApps.Count -gt 0) {
    $null = $ReportContent.AppendLine("$SparkleEmoji CLEARANCE SNAPSHOT $SparkleEmoji")
    $null = $ReportContent.AppendLine("$PackageEmoji SUCCESSFULLY PURGED PACKAGES:")

    foreach ($App in $RemovedApps) {
        $null = $ReportContent.AppendLine("  • [$GreenEmoji REMOVED] $App")
    }
}
else {
    $null = $ReportContent.AppendLine(
        "$StarEmoji PERFECT PROFILE STATE: Checked all entries. No matching target bloatware remained on your user profile."
    )
}

if ($FailedApps.Count -gt 0) {
    $null = $ReportContent.AppendLine("")
    $null = $ReportContent.AppendLine("$LockEmoji SYSTEM PROTECTED / LOCKED PACKAGES:")

    foreach ($App in $FailedApps) {
        $null = $ReportContent.AppendLine("  • [$RedEmoji LOCKED] $App")
    }
}

Set-Content `
    -LiteralPath $ReportFile `
    -Value $ReportContent.ToString() `
    -Encoding UTF8

Write-Log "$PageEmoji Detailed snapshot summary documented at: $ReportFile" -Level SUCCESS
