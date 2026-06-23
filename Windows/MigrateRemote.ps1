param (
    [Parameter(Mandatory=$true)]
    [string]$OldHost,

    [Parameter(Mandatory=$true)]
    [string]$NewHost
)

$ErrorActionPreference = "Stop"

$currentDir = Get-Item .
Write-Host "🚀 Scanning subdirectories under: $($currentDir.FullName)" -ForegroundColor Cyan
Write-Host "   Old host: $OldHost  →  New host: $NewHost"
Write-Host "--------------------------------------------------"

$repoCount = 0
$updatedCount = 0

$subDirs = Get-ChildItem -Directory

foreach ($dir in $subDirs) {
    Set-Location $dir.FullName

    if (git rev-parse --is-inside-work-tree 2>$null) {
        $repoCount++
        $hasUpdates = $false

        $remotes = git remote

        foreach ($remote in $remotes) {
            $currentUrl = git remote get-url $remote

            if ($currentUrl -like "*$OldHost*") {
                $newUrl = $currentUrl -replace [regex]::Escape($OldHost), $NewHost

                if (-not $hasUpdates) {
                    Write-Host "📦 Git repository found: [$($dir.Name)]" -ForegroundColor Yellow
                    $hasUpdates = $true
                }

                Write-Host "   ⚙️  Remote [$remote]:"
                Write-Host "      Old URL: $currentUrl"
                Write-Host "      New URL: $newUrl" -ForegroundColor Green

                git remote set-url $remote $newUrl
            }
        }

        if ($hasUpdates) {
            Write-Host "   ✅ Domain updated for this repository." -ForegroundColor Green
            Write-Host "--------------------------------------------------"
            $updatedCount++
        }
    }
}

Set-Location $currentDir.FullName

Write-Host "🏁 Scan complete." -ForegroundColor Cyan
Write-Host "📊 Summary: $repoCount Git repositories detected, $updatedCount updated with new domain." -ForegroundColor White