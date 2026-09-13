#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

foreach ($relative in @('XVV.ps1', 'Start-XVV.ps1', 'src\XVV.Core.psm1')) {
    $path = Join-Path $root $relative
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) { throw "$relative parser error: $($errors[0].Message)" }
}

[xml](Get-Content -LiteralPath (Join-Path $root 'src\MainWindow.xaml') -Raw -Encoding UTF8) | Out-Null
Get-Content -LiteralPath (Join-Path $root 'data\install-apps.json') -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null
Write-Host 'XVV validation passed / XVV doğrulaması başarılı.' -ForegroundColor Green
