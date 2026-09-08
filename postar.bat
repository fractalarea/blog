@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo.
echo ================================
echo   Publicando: Notas de Joao Mello
echo ================================
echo.

where git >nul 2>&1
if errorlevel 1 goto :sem_git

where quarto >nul 2>&1
if errorlevel 1 goto :sem_quarto

echo [1/4] Renderizando o site (isso executa os chunks de R e Python)...
echo.
call quarto render
if errorlevel 1 goto :erro_render

echo.
echo [2/4] O que mudou:
echo.
git status --short
echo.

rem git diff nao enxerga arquivo novo ainda nao rastreado, entao usamos status
set "TEMMUDANCA="
for /f "delims=" %%i in ('git status --porcelain') do set "TEMMUDANCA=1"
if not defined TEMMUDANCA goto :sem_mudancas

set "MSG=%~1"
if not "%MSG%"=="" goto :tem_msg
set /p "MSG=[3/4] Mensagem do commit (Enter para a padrao): "
if "%MSG%"=="" set "MSG=Atualiza o blog"
:tem_msg

git add -A
if errorlevel 1 goto :erro_git
git commit -m "%MSG%"
if errorlevel 1 goto :erro_git
goto :enviar

:sem_mudancas
echo [3/4] Nenhum arquivo novo ou alterado. Verificando commits pendentes...

:enviar
echo.
echo [4/4] Enviando para o GitHub...
echo.
git push
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
echo ERRO: o comando "git" nao foi encontrado.
echo Instale o Git para Windows: https://git-scm.com/download/win
goto :fim

:sem_quarto
echo ERRO: o comando "quarto" nao foi encontrado.
echo Instale o Quarto: https://quarto.org/docs/get-started/
echo.
echo Observacao: post sem chunk de codigo dispensa o Quarto. Nesse caso,
echo publique com: git add -A  depois  git commit -m "..."  depois  git push
goto :fim

:erro_render
echo.
echo ERRO na renderizacao. Nada foi enviado.
echo Leia a mensagem acima: normalmente e um erro no codigo de algum chunk,
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
echo Tente:  git pull --rebase  e rode este arquivo de novo.
goto :fim

:fim
echo.
pause
endlocal
