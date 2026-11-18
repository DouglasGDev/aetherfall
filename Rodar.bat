@echo off
setlocal
title Aetherfall
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
"%PS%" -NoProfile -NoLogo -ExecutionPolicy Bypass -File "%~dp0tools\run_game.ps1" %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo Falhou com codigo %RC%. Diagnostico sem abrir nada:
  echo    powershell -ExecutionPolicy Bypass -File tools\run_game.ps1 -CheckOnly
  echo.
  pause
)
exit /b %RC%
