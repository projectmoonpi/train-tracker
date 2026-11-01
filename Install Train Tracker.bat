@echo off
rem Install US Train Tracker on this PC. Double-click to run; run it again later to update.
rem Needs Python 3.11 or newer; offers to install it from python.org if it isn't there. Designed and Created by Project Moon Pi.
title Install US Train Tracker
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\windows\install.ps1"
if errorlevel 1 (echo. & echo The install did not finish: see the messages above.)
pause
