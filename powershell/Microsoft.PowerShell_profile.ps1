# PowerShell profile providing aliases similar to zsh
# Set up posh-git and oh-my-posh if available
Import-Module posh-git -ErrorAction SilentlyContinue
Import-Module oh-my-posh -ErrorAction SilentlyContinue

# Common aliases
Set-Alias ll Get-ChildItem
Set-Alias la "Get-ChildItem -Force"
Set-Alias l "Get-ChildItem -Force"
Set-Alias vim nvim

# Quickly cd up directories like .., ..., etc.
function global:Up-Directory([int]$count=1) {
    for ($i = 0; $i -lt $count; $i++) { Set-Location .. }
}
Set-Alias .. { Up-Directory 1 }
for ($i = 2; $i -le 10; $i++) {
    $dots = "." * $i
    Set-Alias $dots { Up-Directory $i }
}

# Simple prompt similar to minimal zsh prompt
function global:prompt {
    $path = $(Get-Location)
    "PS $path> "
}
