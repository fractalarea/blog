@echo off
setlocal
cd /d "%~dp0"

rem Reforca o PATH nesta janela (esta maquina esta sem o System32 no PATH).
set "PATH=%PATH%;%SystemRoot%\System32;%SystemRoot%;%SystemRoot%\System32\Wbem;%SystemRoot%\System32\WindowsPowerShell\v1.0"
set "RDIR="
for /d %%d in ("%ProgramFiles%\R\R-*") do set "RDIR=%%d"
if defined RDIR set "PATH=%PATH%;%RDIR%\bin\x64;%RDIR%\bin"

set "PS=powershell"
if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

echo.
echo Abrindo o editor do blog no navegador...
echo Deixe esta janela aberta enquanto usa o editor.
echo.
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0editor.ps1"
echo.
pause
endlocal
