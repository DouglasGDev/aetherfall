@echo off
rem Passo 1 (a) — dentro da casca do vcvars64: onde resolvem cl, link, dumpbin e lib.
rem Toda linha imprime o ERRORLEVEL do comando dela, e nenhum redirect entre o call e o echo
rem (e o banner do cl vai para arquivo, medido na linha seguinte — e nao atras de um cano).
setlocal
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
echo call vcvars64 exit=%ERRORLEVEL%
where cl 2>nul
echo where cl exit=%ERRORLEVEL%
where link 2>nul
echo where link exit=%ERRORLEVEL%
where dumpbin 2>nul
echo where dumpbin exit=%ERRORLEVEL%
where lib 2>nul
echo where lib exit=%ERRORLEVEL%
cl > "%~dp0_passo1_cl_banner.txt" 2>&1
echo cl sem arquivo exit=%ERRORLEVEL%
findstr /C:"Version" /C:"Vers" "%~dp0_passo1_cl_banner.txt"
echo onde esta o linker que o cl usa
echo VCToolsInstallDir=%VCToolsInstallDir%
echo PATH tem Git\usr\bin?
echo %PATH% | findstr /C:"Git\usr\bin" >nul
echo git_bin_no_path exit=%ERRORLEVEL%
endlocal
