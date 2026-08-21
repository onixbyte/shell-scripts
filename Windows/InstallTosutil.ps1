# Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Architecture Check (Only AMD64 / 64-bit Intel/AMD is supported)
$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -ne "AMD64") {
    Write-Error "Error: tosutil for Windows only supports AMD64 architecture. Detected architecture: $arch"
    exit 1
}

# Configuration & URLs
$binUrl = "https://m645b3e1bb36e-mrap.mrap.accesspoint.tos-global.volces.com/windows/tosutil"
$shaUrl = "https://m645b3e1bb36e-mrap.mrap.accesspoint.tos-global.volces.com/windows/tosutil.sha256sum"

$installDir = "$env:ProgramFiles\tosutil"
$targetExe = Join-Path $installDir "tosutil.exe"

# Helper function to print and run commands
function Invoke-LoggedCommand {
    param([string]$CommandText, [scriptblock]$Action)
    Write-Host ">> Running: $CommandText" -ForegroundColor Cyan
    & $Action
}

# Create Temporary Workspace
$tempDir = Join-Path $env:TEMP ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $tempDir | Out-Null

try {
    Write-Host "=== Starting tosutil installation for Windows (AMD64) ===" -ForegroundColor Green

    $tempBin = Join-Path $tempDir "tosutil.exe"
    $tempSha = Join-Path $tempDir "tosutil.sha256sum"

    # Download binary & checksum
    Write-Host "`n[1/5] Downloading tosutil binary and SHA256 checksum..." -ForegroundColor Yellow
    Invoke-LoggedCommand "Invoke-WebRequest -Uri '$binUrl' -OutFile '$tempBin'" {
        Invoke-WebRequest -Uri $binUrl -OutFile $tempBin -UseBasicParsing
    }
    Invoke-LoggedCommand "Invoke-WebRequest -Uri '$shaUrl' -OutFile '$tempSha'" {
        Invoke-WebRequest -Uri $shaUrl -OutFile $tempSha -UseBasicParsing
    }

    # Verify SHA256
    Write-Host "`n[2/5] Verifying SHA256 checksum..." -ForegroundColor Yellow
    $rawExpected = (Get-Content -Path $tempSha -Raw).Trim()
    $expectedHash = ($rawExpected -split '\s+')[0].ToLowerInvariant()

    $computedHash = (Get-FileHash -Path $tempBin -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host ">> Expected: $expectedHash"
    Write-Host ">> Actual:   $computedHash"

    if ($computedHash -ne $expectedHash) {
        Write-Error "SHA256 checksum verification failed!"
        exit 1
    }
    Write-Host "SHA256 verification passed." -ForegroundColor Green

    # Install binary
    Write-Host "`n[3/5] Installing binary to $targetExe..." -ForegroundColor Yellow
    if (-not (Test-Path $installDir)) {
        Invoke-LoggedCommand "New-Item -ItemType Directory -Path '$installDir'" {
            New-Item -ItemType Directory -Path $installDir | Out-Null
        }
    }
    Invoke-LoggedCommand "Move-Item -Force -Path '$tempBin' -Destination '$targetExe'" {
        Move-Item -Force -Path $tempBin -Destination $targetExe
    }

    # Add to System PATH
    Write-Host "`n[4/5] Updating system PATH environment variable..." -ForegroundColor Yellow
    $machinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
    if ($machinePath -split ';' -notcontains $installDir) {
        Invoke-LoggedCommand "Add '$installDir' to Machine PATH" {
            [Environment]::SetEnvironmentVariable("Path", "$machinePath;$installDir", [EnvironmentVariableTarget]::Machine)
            $env:Path = "$env:Path;$installDir"
        }
    } else {
        Write-Host "Target directory already present in PATH."
    }

    # Verify installation
    Write-Host "`n[5/5] Checking installation..." -ForegroundColor Yellow
    Invoke-LoggedCommand "& '$targetExe' version" {
        & "$targetExe" version
    }

    Write-Host "`n========================================================" -ForegroundColor Green
    Write-Host "✅ tosutil installed successfully to $targetExe." -ForegroundColor Green
    Write-Host "========================================================" -ForegroundColor Green
    Write-Host "`nNext Steps:"
    Write-Host "1. Initialise and configure your credentials (in PowerShell or CMD):"
    Write-Host '   tosutil config -i "$env:TOS_ACCESS_KEY" -k "$env:TOS_SECRET_KEY" -e "$env:TOS_ENDPOINT" -re "$env:TOS_REGION"' -ForegroundColor Cyan
    Write-Host "`n2. For more detailed documentation, visit:"
    Write-Host "   https://docs.volcengine.com/docs/6349/148775?lang=zh`n"

} finally {
    Remove-Item -Recurse -Force -Path $tempDir -ErrorAction SilentlyContinue
}