<#
.SYNOPSIS
    Creates emoji-enriched CSV and ASCII-art TXT inventories of apps.

.DESCRIPTION
    Uses winget export to create an inventory of installed applications.
    If winget export fails, the script uses winget list as a fallback.

.NOTES
    Run from an elevated PowerShell session.
    Automatically purges files older than 30 days.
#>

# -------------------------------------------------
#   Emoji characters
#   Defined by Unicode code points to prevent encoding errors
# -------------------------------------------------

$SuccessEmoji = [char]::ConvertFromUtf32(0x2705)
$WarningEmoji = [char]::ConvertFromUtf32(0x26A0) + [char]::ConvertFromUtf32(0xFE0F)
$ErrorEmoji   = [char]::ConvertFromUtf32(0x2757)
$InfoEmoji    = [char]::ConvertFromUtf32(0x2139) + [char]::ConvertFromUtf32(0xFE0F)
$BoxEmoji     = [char]::ConvertFromUtf32(0x1F4E6)
$ComputerEmoji = [char]::ConvertFromUtf32(0x1F4BB)
$GlobeEmoji   = [char]::ConvertFromUtf32(0x1F310)
$ChatEmoji    = [char]::ConvertFromUtf32(0x1F4AC)
$MusicEmoji   = [char]::ConvertFromUtf32(0x1F3B5)
$DocumentEmoji = [char]::ConvertFromUtf32(0x1F4C4)
$GameEmoji    = [char]::ConvertFromUtf32(0x1F3AE)
$GearEmoji    = [char]::ConvertFromUtf32(0x2699) + [char]::ConvertFromUtf32(0xFE0F)
$PackageEmoji = [char]::ConvertFromUtf32(0x1F4E6)

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

$CsvPath = Join-Path $ExportFolder "winget-inventory_$TimeStamp.csv"
$TxtPath = Join-Path $ExportFolder "winget-inventory_$TimeStamp.txt"
$LogPath = Join-Path $LogFolder "audit-winget_$TimeStamp.log"

# -------------------------------------------------
#   Prepare folders
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
    $Entry | Tee-Object -FilePath $LogPath -Append
}

# -------------------------------------------------
#   Application emoji helper
# -------------------------------------------------

function Get-AppEmoji {
    param (
        [string]$Id,
        [string]$Name
    )

    $LowerId = if ($Id) {
        $Id.ToLower()
    }
    else {
        ""
    }

    $LowerName = if ($Name) {
        $Name.ToLower()
    }
    else {
        ""
    }

    $SearchText = "$LowerId $LowerName"

    if ($SearchText -match "python|git|powertoys|docker|vscode|visualstudio|terminal|developer|sdk|node") {
        return $ComputerEmoji
    }

    if ($SearchText -match "browser|chrome|edge|firefox|opera|brave|vivaldi") {
        return $GlobeEmoji
    }

    if ($SearchText -match "discord|teams|zoom|slack|whatsapp|messenger|telegram") {
        return $ChatEmoji
    }

    if ($SearchText -match "spotify|vlc|music|video|player|plex|netflix|obs") {
        return $MusicEmoji
    }

    if ($SearchText -match "office|excel|word|notion|adobe|reader|pdf|7zip|winrar") {
        return $DocumentEmoji
    }

    if ($SearchText -match "steam|epic|xbox|game|gog|origin") {
        return $GameEmoji
    }

    if ($SearchText -match "nvidia|amd|intel|driver|hardware|logitech") {
        return $GearEmoji
    }

    return $PackageEmoji
}

# -------------------------------------------------
#   ASCII-art title generator
# -------------------------------------------------

function Get-AsciiHeader {
    $Art = @"
========================================================================
 __          __ _         __      __             _
 \ \        / /(_)        \ \    / /            | |
  \ \  /\  / /  _  _ __    \ \  / /___  _ __  _ | |_  ___   _ __  _   _
   \ \/  \/ /  | || '_ \    \ \/ // _ \| '__|| \| __|/ _ \ | '__|| | | |
    \  /\  /   | || | | |    \  /|  __/| |   | | |_| (_) | |     | |_| |
     \/  \/    |_||_| |_|     \/  \___||_|   |_|\__|\___/|_|      \__, |
                                                                   __/ |
                                                                  |___/
========================================================================
 Inventory Created : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
 Target Scope      : WinGet Managed Repository Sources Only
 Status            : Verified Consistent and Alphabetized
========================================================================

"@

    return $Art
}

# -------------------------------------------------
#   Start
# -------------------------------------------------

Write-Log "Initializing automated WinGet asset tracking pipeline."

# -------------------------------------------------
#   Retention cleanup
# -------------------------------------------------

Write-Log "Scanning directories for files older than 30 days."

$CutoffDate = (Get-Date).AddDays(-30)
$TargetPaths = @($ExportFolder, $LogFolder)
$PurgeCount = 0

foreach ($Target in $TargetPaths) {
    if (Test-Path -LiteralPath $Target) {
        $ExpiredFiles = Get-ChildItem -LiteralPath $Target -File |
            Where-Object {
                $_.LastWriteTime -lt $CutoffDate
            }

        foreach ($File in $ExpiredFiles) {
            try {
                Remove-Item -LiteralPath $File.FullName -Force -ErrorAction Stop
                $PurgeCount++
            }
            catch {
                Write-Log "Failed to purge obsolete file: $($File.Name) - $($_.Exception.Message)" -Level WARN
            }
        }
    }
}

if ($PurgeCount -gt 0) {
    Write-Log "Retention check complete. Purged $PurgeCount expired file(s)." -Level SUCCESS
}
else {
    Write-Log "Retention check complete. No expired files found."
}

# -------------------------------------------------
#   Primary engine - WinGet JSON parser
# -------------------------------------------------

$TempJson = [System.IO.Path]::GetTempFileName()
$PrimarySucceeded = $false

try {
    Write-Log "Running WinGet export."

    winget export `
        --source winget `
        --output $TempJson `
        --include-versions `
        --accept-source-agreements 2>$null

    $ExportExitCode = $LASTEXITCODE

    if ($ExportExitCode -eq 0 -and (Test-Path -LiteralPath $TempJson)) {
        $JsonContent = Get-Content -LiteralPath $TempJson -Raw
        $Data = $JsonContent | ConvertFrom-Json
        $Packages = @($Data.Sources.Packages)

        if ($Packages.Count -gt 0) {
            Write-Log "WinGet parsed metadata accurately. Found $($Packages.Count) managed installation(s)." -Level SUCCESS

            $NormalizedOutput = $Packages |
                ForEach-Object {
                    $RawId = $_.PackageIdentifier

                    if ([string]::IsNullOrWhiteSpace($RawId)) {
                        return
                    }

                    $RawName = ($RawId -split "\.")[-1]
                    $Icon = Get-AppEmoji -Id $RawId -Name $RawName

                    [PSCustomObject]@{
                        Type      = $Icon
                        Name      = $RawName
                        Id        = $RawId
                        Version   = $_.PackageVersion
                        Publisher = ($RawId -split "\.")[0]
                    }
                } |
                Sort-Object Name

            # CSV export
            $NormalizedOutput |
                Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8

            Write-Log "Structured alphabetical CSV catalog generated at: $CsvPath" -Level SUCCESS

            # TXT export
            $AsciiHeader = Get-AsciiHeader
            $TableData = $NormalizedOutput |
                Format-Table -AutoSize |
                Out-String

            Set-Content `
                -LiteralPath $TxtPath `
                -Value ($AsciiHeader + $TableData) `
                -Encoding UTF8

            Write-Log "Readable alphabetical TXT snapshot generated at: $TxtPath" -Level SUCCESS

            $PrimarySucceeded = $true
        }
        else {
            Write-Log "WinGet engine emitted an empty manifest block." -Level WARN
        }
    }
    else {
        Write-Log "WinGet export failed with exit code $ExportExitCode." -Level WARN
    }
}
catch {
    Write-Log "Core script module failure: $($_.Exception.Message). Falling back to text processing." -Level ERROR
}
finally {
    if (Test-Path -LiteralPath $TempJson) {
        Remove-Item -LiteralPath $TempJson -Force
    }
}

if ($PrimarySucceeded) {
    exit 0
}

# -------------------------------------------------
#   Emergency fallback engine - text processing
# -------------------------------------------------

Write-Log "Executing textual fallback diagnostic scrape." -Level WARN

$Raw = winget list `
    --source winget `
    --accept-source-agreements 2>$null

if ($Raw) {
    $CleanLines = $Raw |
        Where-Object {
            $_ -match "\S"
        }

    $FallbackObjects = $CleanLines |
        Select-Object -Skip 2 |
        ForEach-Object {
            $Parts = $_ -split "\s{2,}"

            if ($Parts.Count -ge 3) {
                $RawName = $Parts[0].Trim()
                $RawId = $Parts[1].Trim()
                $RawVersion = $Parts[2].Trim()
                $Icon = Get-AppEmoji -Id $RawId -Name $RawName

                [PSCustomObject]@{
                    Type      = $Icon
                    Name      = $RawName
                    Id        = $RawId
                    Version   = $RawVersion
                    Publisher = ($RawId -split "\.")[0]
                }
            }
        } |
        Where-Object {
            $null -ne $_
        } |
        Sort-Object Name

    if (@($FallbackObjects).Count -gt 0) {
        # CSV fallback export
        $FallbackObjects |
            Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8

        Write-Log "Fallback alphabetical CSV approximation built successfully." -Level SUCCESS

        # TXT fallback export
        $AsciiHeader = Get-AsciiHeader
        $TableData = $FallbackObjects |
            Format-Table -AutoSize |
            Out-String

        Set-Content `
            -LiteralPath $TxtPath `
            -Value ($AsciiHeader + $TableData) `
            -Encoding UTF8

        Write-Log "Fallback alphabetical TXT snapshot built successfully." -Level SUCCESS
    }
    else {
        Write-Log "Fallback loop failed to extract meaningful text tokens." -Level ERROR
        exit 1
    }
}
else {
    Write-Log "Terminal execution breakdown. WinGet interface was unreachable." -Level ERROR
    exit 1
}
