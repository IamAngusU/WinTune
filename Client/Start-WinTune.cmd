@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title WinTune Advisor

rem Applies only to this PowerShell process; it does not change Windows execution-policy settings.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinTuneLauncher.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo WinTune ended with code %EXIT_CODE%.
  echo WinTune wurde mit Code %EXIT_CODE% beendet.
  echo You can close this window after reading any message above.
  echo Sie koennen dieses Fenster nach dem Lesen der Meldung oben schliessen.
  pause
)

exit /b %EXIT_CODE%
