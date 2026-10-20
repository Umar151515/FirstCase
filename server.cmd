@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ops\windows\Server.ps1" %*
set "server_exit=%errorlevel%"
if not "%server_exit%"=="0" if "%~1"=="" pause
exit /b %server_exit%
