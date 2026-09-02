<#
.SYNOPSIS
    Cleans WinGet's local cache and temporary download folders.

.NOTES
    Requires administrator rights because some cache locations may be
    protected by Windows.
#>

# -------------------------------------------------
#   Emoji characters
# -------------------------------------------------

$CleaningEmoji = [char]::ConvertFromUtf32(0x1F9F9)
$SuccessEmoji  = [char]::ConvertFromUtf32(0x2705)
$WarningEmoji  = [char]::ConvertFromUtf32(0x26A0) + [char]::ConvertFromUtf32(0xFE0F)
$InfoEmoji     = [char]::ConvertFromUtf32(0x2139) + [char]::ConvertFromUtf32(0xFE0F)
$FinishEmoji   = [char]::ConvertFromUtf32(0x1F3C1)

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
$LogFile   = Join-Path $LogFolder "cleanup-winget_$TimeStamp.log"

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
#   Start cleanup
# -------------------------------------------------

Write-Log "$CleaningEmoji Starting WinGet cache cleanup."

# -------------------------------------------------
#   1. Run WinGet's internal cleanup command
# -------------------------------------------------

$WingetCommand = Get-Command winget.exe -ErrorAction SilentlyContinue

if ($null -ne $WingetCommand) {
    try {
        winget clean --silent 2>&1 | Out-Null

        $WingetExitCode = $LASTEXITCODE

        if ($WingetExitCode -eq 0) {
            Write-Log "$SuccessEmoji winget clean succeeded."
        }
        else {
            Write-Log "$WarningEmoji winget clean returned exit code $WingetExitCode."
        }
    }
    catch {
        Write-Log "$WarningEmoji winget clean failed: $($_.Exception.Message)"
    }
}
else {
    Write-Log "$InfoEmoji winget.exe was not found on this system."
}

# -------------------------------------------------
#   2. Remove WinGet LocalCache folders
# -------------------------------------------------

$CachePattern = Join-Path `
    $env:LOCALAPPDATA `
    "Packages\Microsoft.DesktopAppInstaller_*\LocalCache"

$CacheFolders = Get-Item `
    -Path $CachePattern `
    -Force `
    -ErrorAction SilentlyContinue

if ($null -ne $CacheFolders) {
    foreach ($CacheFolder in $CacheFolders) {
        try {
            Get-ChildItem `
                -LiteralPath $CacheFolder.FullName `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue |
                Remove-Item `
                    -Force `
                    -Recurse `
                    -ErrorAction SilentlyContinue

            Write-Log "$SuccessEmoji Deleted WinGet LocalCache at $($CacheFolder.FullName)."
        }
        catch {
            Write-Log "$WarningEmoji Could not completely clean $($CacheFolder.FullName): $($_.Exception.Message)"
        }
    }
}
else {
    Write-Log "$InfoEmoji No WinGet LocalCache folder found."
}

# -------------------------------------------------
#   3. Remove temporary WinGet download folders
# -------------------------------------------------

$TempPaths = @(
    (Join-Path $env:TEMP "WinGet"),
    (Join-Path $env:TEMP "winget"),
    (Join-Path $env:LOCALAPPDATA "Temp\WinGet"),
    (Join-Path $env:LOCALAPPDATA "Temp\winget")
)

foreach ($TempPath in $TempPaths) {
    if (Test-Path -LiteralPath $TempPath) {
        try {
            Remove-Item `
                -LiteralPath $TempPath `
                -Recurse `
                -Force `
                -ErrorAction Stop

            Write-Log "$SuccessEmoji Deleted temporary folder: $TempPath."
        }
        catch {
            Write-Log "$WarningEmoji Could not delete temporary folder ${TempPath}: $($_.Exception.Message)"
        }
    }
}

Write-Log "$FinishEmoji Cleanup finished."
