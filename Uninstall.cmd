@echo off
rem Axis and Allies (2004) Remastered: double-click to uninstall.
rem You can also drop the game folder onto this file.
title Axis and Allies (2004) Remastered - Uninstall
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" -Wizard %*
echo.
pause
