#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$appScript = Join-Path $PSScriptRoot 'XVV.ps1'
$errorLog = Join-Path $PSScriptRoot 'XVV-error.log'

try {
    if (-not (Test-Path -LiteralPath $appScript -PathType Leaf)) {
        throw "XVV.ps1 bulunamadı. ZIP içindeki XVV klasörünü tamamen çıkardığından emin ol."
    }

    & $appScript
} catch {
    $details = ($_ | Out-String).Trim()
    try {
        [IO.File]::WriteAllText($errorLog, $details, [Text.UTF8Encoding]::new($true))
    } catch { }

    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        $message = "XVV başlatılamadı.`n`n$details`n`nAyrıntılar XVV-error.log dosyasına kaydedildi."
        [System.Windows.MessageBox]::Show($message, 'XVV Başlatma Hatası', 'OK', 'Error') | Out-Null
    } catch { }

    exit 1
}
