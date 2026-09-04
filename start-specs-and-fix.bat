@echo off
title SPECS AND FIX BY VH
setlocal

net session >nul 2>&1
if %errorLevel% == 0 (
    goto :RunAdmin
) else (
    echo [!] SOLICITANDO PERMISSOES DE ADMINISTRADOR...
    powershell -Command "Start-Process cmd -ArgumentList '/c, %~f0' -Verb RunAs"
    exit
)

:RunAdmin
pushd "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "specs-and-fix.ps1"