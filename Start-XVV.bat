@echo off
setlocal
cd /d "%~dp0"
start "" powershell.exe -NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0src\Launcher.ps1"
exit /b 0
