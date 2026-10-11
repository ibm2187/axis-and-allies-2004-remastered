@echo off
rem Axis and Allies (2004) Remastered: double-click to install.
rem You can also drop the game folder onto this file.
title Axis and Allies (2004) Remastered - Install
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Wizard %*
echo.
pause
