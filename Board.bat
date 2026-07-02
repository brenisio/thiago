@echo off
REM Abre o Board Nulla: sobe o servidor local (PowerShell) e o navegador.
REM Basta dar duplo-clique neste arquivo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0server.ps1"
