@echo off
setlocal
title WinTune Advisor

rem This applies only to this one PowerShell process. It does not change the
rem machine or user execution-policy setting.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinTuneLauncher.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo WinTune ended with code %EXIT_CODE%.
  echo You can close this window after reading any message above.
  pause
)

exit /b %EXIT_CODE%
