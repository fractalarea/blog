@echo off
setlocal
echo.
echo ===== O que esta instalado nesta maquina =====
echo.

echo --- System32 no PATH? ---
if exist "%SystemRoot%\System32\cmd.exe" echo A pasta existe em %SystemRoot%\System32
chcp >nul 2>&1
if errorlevel 1 (echo PROBLEMA: o System32 NAO esta no PATH) else (echo OK: o System32 esta no PATH)
echo.

echo --- Git ---
git --version 2>&1
if exist "%ProgramFiles%\Git\cmd\git.exe" echo Instalado em: "%ProgramFiles%\Git\cmd\git.exe"
if exist "%ProgramFiles(x86)%\Git\cmd\git.exe" echo Instalado em: "%ProgramFiles(x86)%\Git\cmd\git.exe"
if exist "%LOCALAPPDATA%\Programs\Git\cmd\git.exe" echo Instalado em: "%LOCALAPPDATA%\Programs\Git\cmd\git.exe"
echo.

echo --- Quarto ---
call quarto --version 2>&1
if exist "%LOCALAPPDATA%\Programs\Quarto\bin\quarto.cmd" echo Instalado em: "%LOCALAPPDATA%\Programs\Quarto\bin\quarto.cmd"
if exist "%ProgramFiles%\Quarto\bin\quarto.cmd" echo Instalado em: "%ProgramFiles%\Quarto\bin\quarto.cmd"
echo.

echo --- R ---
where R 2>nul
if exist "%ProgramFiles%\R" dir /b "%ProgramFiles%\R" 2>nul
echo.

echo --- PATH completo ---
echo %PATH%
echo.
echo Copie tudo acima e mande para o Claude.
echo.
pause
endlocal
