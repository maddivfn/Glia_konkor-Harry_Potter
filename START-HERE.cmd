@echo off
chcp 65001 >nul
setlocal
title Harry Potter Biology Quiz - Keep This Window Open
cd /d "%~dp0"

if not exist "serve.ps1" goto :not_extracted
if not exist "index.html" goto :not_extracted
if not exist "book.pdf" goto :not_extracted
if not exist "vendor\pdf.min.mjs" goto :not_extracted
if not exist "vendor\pdf.worker.compat.mjs" goto :not_extracted

where powershell.exe >nul 2>&1
if errorlevel 1 goto :no_powershell

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
if errorlevel 1 goto :start_failed
exit /b 0

:not_extracted
echo.
echo =============================================================
echo This app cannot run from inside the ZIP file.
echo Right-click the ZIP, choose Extract All, open the extracted
echo folder, and then double-click START-HERE.cmd again.
echo =============================================================
echo.
pause
exit /b 2

:no_powershell
echo PowerShell was not found on this Windows device.
echo Read the included guide file for help.
pause
exit /b 3

:start_failed
echo.
echo The app could not start. Move the extracted folder to Desktop
echo and try START-HERE.cmd again.
pause
exit /b 4
