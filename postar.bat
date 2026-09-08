@echo off
setlocal
cd /d "%~dp0"

rem O chcp fica opcional: se o PATH estiver sem o System32 ele nao existe,
rem e nada aqui depende dele.
if exist "%SystemRoot%\System32\chcp.com" "%SystemRoot%\System32\chcp.com" 65001 >nul 2>&1

echo.
echo ================================
echo   Publicando: Notas de Joao Mello
echo ================================
echo.

rem Procura o git: primeiro no PATH, depois nos lugares onde ele costuma ser
rem instalado. Nao usamos "where", que tambem mora no System32.
set "GIT="
git --version >nul 2>&1
if not errorlevel 1 set "GIT=git"
if not defined GIT if exist "%ProgramFiles%\Git\cmd\git.exe" set "GIT=%ProgramFiles%\Git\cmd\git.exe"
if not defined GIT if exist "%ProgramFiles(x86)%\Git\cmd\git.exe" set "GIT=%ProgramFiles(x86)%\Git\cmd\git.exe"
if not defined GIT if exist "%LOCALAPPDATA%\Programs\Git\cmd\git.exe" set "GIT=%LOCALAPPDATA%\Programs\Git\cmd\git.exe"
if not defined GIT goto :sem_git

set "QUARTO="
call quarto --version >nul 2>&1
if not errorlevel 1 set "QUARTO=quarto"
if not defined QUARTO if exist "%LOCALAPPDATA%\Programs\Quarto\bin\quarto.cmd" set "QUARTO=%LOCALAPPDATA%\Programs\Quarto\bin\quarto.cmd"
if not defined QUARTO if exist "%ProgramFiles%\Quarto\bin\quarto.cmd" set "QUARTO=%ProgramFiles%\Quarto\bin\quarto.cmd"
if not defined QUARTO goto :sem_quarto

echo [1/4] Renderizando o site (executa os chunks de R e Python)...
echo.
call "%QUARTO%" render
if errorlevel 1 goto :erro_render

echo.
echo [2/4] O que mudou:
echo.
"%GIT%" status --short
echo.

rem git diff nao enxerga arquivo novo ainda nao rastreado, entao usamos status
set "TEMMUDANCA="
for /f "usebackq delims=" %%i in (`"%GIT%" status --porcelain`) do set "TEMMUDANCA=1"
if not defined TEMMUDANCA goto :sem_mudancas

set "MSG=%~1"
if not "%MSG%"=="" goto :tem_msg
set /p "MSG=[3/4] Mensagem do commit (Enter para a padrao): "
if "%MSG%"=="" set "MSG=Atualiza o blog"
:tem_msg

"%GIT%" add -A
if errorlevel 1 goto :erro_git
"%GIT%" commit -m "%MSG%"
if errorlevel 1 goto :erro_git
goto :enviar

:sem_mudancas
echo [3/4] Nenhum arquivo novo ou alterado. Verificando commits pendentes...

:enviar
echo.
echo [4/4] Enviando para o GitHub...
echo.
"%GIT%" push
if errorlevel 1 goto :erro_push

echo.
echo --------------------------------
echo  Pronto. O site atualiza em 1 a 2 minutos.
echo.
echo    Site:  https://fractalarea.github.io/blog/
echo    Build: https://github.com/fractalarea/blog/actions
echo --------------------------------
goto :fim

:sem_git
echo ERRO: nao encontrei o Git.
echo.
echo Se voce ainda nao instalou: https://git-scm.com/download/win
echo Se ja instalou, o PATH do Windows pode estar quebrado. Confira com:
echo.
echo    echo %%PATH%%
echo.
echo Ele precisa conter C:\Windows\System32 e a pasta cmd do Git.
goto :fim

:sem_quarto
echo ERRO: nao encontrei o Quarto.
echo.
echo Instale em https://quarto.org/docs/get-started/ e reabra esta janela.
echo.
echo Observacao: post sem chunk de codigo dispensa o Quarto. Nesse caso
echo publique com: git add -A   depois   git commit -m "..."   depois   git push
goto :fim

:erro_render
echo.
echo ERRO na renderizacao. Nada foi enviado.
echo Leia a mensagem acima: em geral e erro no codigo de algum chunk,
echo ou um pacote de R / Python que falta instalar.
goto :fim

:erro_git
echo.
echo ERRO ao registrar o commit. Nada foi enviado.
goto :fim

:erro_push
echo.
echo ERRO ao enviar. O commit foi feito localmente e nao se perdeu.
echo Causa mais comum: o repositorio no GitHub tem algo que voce nao tem aqui.
echo Tente:  git pull --rebase   e rode este arquivo de novo.
goto :fim

:fim
echo.
pause
endlocal
