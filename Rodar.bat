@echo off
setlocal
title Aetherfall
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
"%PS%" -NoProfile -NoLogo -ExecutionPolicy Bypass -File "%~dp0tools\run_game.ps1" %*
set "RC=%ERRORLEVEL%"
if "%RC%"=="2" (
  echo.
  echo Nada foi aberto. Fecha a outra janela e da o clique de novo, ou:
  echo    .\Rodar.bat -Force
  echo.
  pause
)
if not "%RC%"=="0" if not "%RC%"=="2" (
  echo.
  echo Falhou com codigo %RC%. Diagnostico sem abrir nada:
  echo    powershell -ExecutionPolicy Bypass -File tools\run_game.ps1 -CheckOnly
  echo.
  pause
)
exit /b %RC%
