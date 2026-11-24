@echo off
rem Passo 1 (a) — o que a casca resolve SEM o vcvars64. Rodar em cmd comum, na raiz:
rem   cmd /c docs\evidence\oraculo-nativo-22\passo1_fora_da_casca.bat > docs\evidence\oraculo-nativo-22\passo1_fora_da_casca.log 2>&1
rem Nada aqui compila: e leitura de PATH. Serve para o build.bat saber o que ele herda se esquecer o vcvars.
rem Cada ferramenta passa por :um, um processo por linha — dentro de um for, %ERRORLEVEL% e do comando
rem anterior a expansao, nao do where que esta na tela (e o furo #32 com outra cara).
echo == Passo 1 (a): resolucao fora da casca do vcvars, %DATE% %TIME% ==
echo.
call :um cl
call :um link
call :um dumpbin
call :um lib
call :um scons
call :um cmake
call :um ninja
echo.
echo [o que o link.exe que o PATH devolve faz]
where link
for /f "delims=" %%P in ('where link') do "%%P" --version 2>&1 | more +0
echo.
echo [fim]
exit /b 0

:um
echo [where %1]
where %1 2>&1
if errorlevel 1 (echo   exit=1 - nao resolvido) else (echo   exit=0)
exit /b 0
