#!/usr/bin/env pwsh
#requires -Version 7
$ErrorActionPreference = 'Stop'

Write-Host "Upgrading winget packages..."
winget upgrade --all

$home = $env:USERPROFILE

$repos = @(
    @{ Path = Join-Path $home '.zprezto'; Name = 'Prezto' },
    @{ Path = Join-Path $home '.tmux'; Name = 'oh-my-tmux' }
)

foreach ($repo in $repos) {
    if (Test-Path $repo.Path) {
        Write-Host "Updating $($repo.Name)..."
        git -C $repo.Path pull --ff-only
    }
}
