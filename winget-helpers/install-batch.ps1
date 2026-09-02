<#
.SYNOPSIS
    Installs multiple Winget packages listed in packages.txt.

.DESCRIPTION
    Reads each line of packages.txt as a Winget package ID and installs
    packages that are not already installed.

.NOTES
    Run this script from an elevated PowerShell session.
#>

# ----- Emoji characters ----------------------------------------------

$CrossMark    = [char]::ConvertFromUtf32(0x274C)
$Rocket       = [char]::ConvertFromUtf32(0x1F680)
$Coffee       = [char]::ConvertFromUtf32(0x2615)
$Magnifying   = [char]::ConvertFromUtf32(0x1F50D)
$Skip         = [char]::ConvertFromUtf32(0x23ED) + [char]::ConvertFromUtf32(0xFE0F)
$Package      = [char]::ConvertFromUtf32(0x1F4E6)
$Tools        = [char]::ConvertFromUtf32(0x1F527)
$Info         = [char]::ConvertFromUtf32(0x2139) + [char]::ConvertFromUtf32(0xFE0F)
$Success      = [char]::ConvertFromUtf32(0x2705)
$Warning      = [char]::ConvertFromUtf32(0x2757)
$Finish       = [char]::ConvertFromUtf32(0x1F3C1)

# ----- Paths ---------------------------------------------------------

$PackageFile = Join-Path $PSScriptRoot "packages.txt"
$LogFolder   = Join-Path $PSScriptRoot "logs"
$TimeStamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile     = Join-Path $LogFolder "install-batch_$TimeStamp.log"

# ----- Prepare logging -----------------------------------------------

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

# ----- Verify packages.txt exists ------------------------------------

if (-not (Test-Path -LiteralPath $PackageFile)) {
    Write-Log "$CrossMark packages.txt not found at $PackageFile - aborting."
    exit 1
}

Write-Log "$Rocket Starting app installation. Feel free to grab a coffee $Coffee."

# ----- Load package IDs ----------------------------------------------

$Apps = Get-Content -LiteralPath $PackageFile |
    ForEach-Object {
        $Id = $_.Trim()

        # Ignore blank lines and lines beginning with #
        if ($Id -and -not $Id.StartsWith("#")) {
            [PSCustomObject]@{
                Name = $Id
            }
        }
    }

# ----- Process each package ------------------------------------------

foreach ($App in $Apps) {
    $PackageId = $App.Name

    Write-Log "$Magnifying Checking whether $PackageId is already installed."

    # Query Winget for an exact package ID match
    $InstalledApp = winget list `
        --id $PackageId `
        --exact `
        --accept-source-agreements 2>$null

    $ListExitCode = $LASTEXITCODE
    $InstalledText = [string]::Join("", $InstalledApp)

    if ($ListExitCode -eq 0 -and $InstalledText.Contains($PackageId)) {
        Write-Host "$Skip Skipping $PackageId (app already installed)"
        Write-Log "$Info $PackageId - app already installed"
        continue
    }

    Write-Host "$Package Installing $PackageId"
    Write-Log "$Tools Installing $PackageId"

    winget install `
        --id $PackageId `
        --exact `
        --silent `
        --accept-source-agreements `
        --accept-package-agreements 2>$null

    $InstallExitCode = $LASTEXITCODE

    if ($InstallExitCode -eq 0) {
        Write-Log "$Success Successfully installed $PackageId"
    }
    else {
        Write-Log "$Warning Failed to install $PackageId - exit code: $InstallExitCode"
    }
}

Write-Log "$Finish Bulk-install run complete."
