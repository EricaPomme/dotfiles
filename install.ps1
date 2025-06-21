#!/usr/bin/env pwsh
#requires -Version 7
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$packFile = Join-Path $repoRoot 'packagelists/winget.packages'

if (Test-Path $packFile) {
    $packages = Get-Content $packFile | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() } |
        ForEach-Object { ($_ -split '\s+')[0] }
    foreach ($pkg in $packages) {
        Write-Host "Installing $pkg..."
        winget install --id $pkg -e
    }
}

# Symlink configuration files
$home = $env:USERPROFILE
$links = @{
    (Join-Path $repoRoot 'git/gitconfig') = Join-Path $home '.gitconfig'
    (Join-Path $repoRoot 'nvim/config') = Join-Path $env:LOCALAPPDATA 'nvim'
}

foreach ($src in $links.Keys) {
    $dst = $links[$src]
    $dstDir = Split-Path $dst
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    if (Test-Path $dst) { Remove-Item $dst -Force }
    New-Item -ItemType SymbolicLink -Path $dst -Target $src -Force | Out-Null
}

# PowerShell profile
$profileDir = Join-Path $home 'Documents/PowerShell'
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
$profileDest = Join-Path $profileDir 'Microsoft.PowerShell_profile.ps1'
$profileSrc = Join-Path $repoRoot 'powershell/Microsoft.PowerShell_profile.ps1'
if (Test-Path $profileDest) { Remove-Item $profileDest -Force }
New-Item -ItemType SymbolicLink -Path $profileDest -Target $profileSrc -Force | Out-Null
