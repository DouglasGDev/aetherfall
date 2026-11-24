@echo off
rem Passo 2 (a) do dossie 22 (S5.1): o A/B que MEDE a frase do ordinal, em vez de deixa-la
rem como comentario no codigo.
rem
rem A alegacao em teste (esta no cabecalho de gen_import_libs.py e no `extra` da recusa de
rem check_imports.py): um `.def` com `nome @37` faz o `lib /def:` produzir import POR ORDINAL, e
rem ai o `dumpbin /imports` do exe imprime `Ordinal 167` sem nome nenhum -- a regua de que
rem "este nome vem desta DLL" deixa de existir.
rem
rem Um por um, o que esta sob controle:
rem   - o MESMO symbol_gate.obj (o do build; este instrumento nao recompila nada);
rem   - os MESMOS quatro modulos, os MESMOS nomes, a MESMA linha de /DELAYLOAD;
rem   - a unica variavel e o `@n` dentro do `.def`;
rem   - a regua e o MESMO check_imports.py, chamado duas vezes, uma contra cada tabela.
rem
rem Nao le o codigo do `call vcvars64.bat` atraves do redirect (furo #32): o que autoriza a
rem continuar e a presenca dos proprios arquivos, e cada codigo de saida e lido na linha
rem imediatamente abaixo do seu comando.
rem
rem Pre-requisito: `native\af_mind\build.bat` rodou (precisa de bin\symbol_gate.obj).
rem Rodar de C:\Aetherfall, com a saida redirectida para o proprio log.

setlocal enableextensions

set "ROOT=C:\Aetherfall"
set "AFM=%ROOT%\native\af_mind"
set "BIN=%AFM%\bin"
set "ORD=%BIN%\ab-ordinal"
set "LIBS=%ORD%\llama_import.lib %ORD%\ggml_import.lib %ORD%\ggml-base_import.lib %ORD%\ggml-vulkan_import.lib"
set "NAMES=%BIN%\llama_import.lib %BIN%\ggml_import.lib %BIN%\ggml-base_import.lib %BIN%\ggml-vulkan_import.lib"
set "DELAY=/DELAYLOAD:llama.dll /DELAYLOAD:ggml.dll /DELAYLOAD:ggml-base.dll /DELAYLOAD:ggml-vulkan.dll"

call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" > "%BIN%\ab_vcvars.log" 2>&1

if not exist "%BIN%\symbol_gate.obj" goto :sem_obj
if not exist "%AFM%\gen_import_libs.py" goto :sem_gen
if not exist "%AFM%\check_imports.py" goto :sem_gen

rem A mesma regua 4 do build.bat, aqui porque este instrumento chama `link` duas vezes: fora do
rem toolset nomeado o `link` que resolve e o do Git (furo #35), e um "link codigo=0" dele nao e
rem prova de nada.
set "LINK_FIRST="
for /f "usebackq delims=" %%L in (`where link`) do if not defined LINK_FIRST set "LINK_FIRST=%%L"
if /i not "%LINK_FIRST%"=="%VCToolsInstallDir%bin\Hostx64\x64\link.exe" goto :link_errado
echo [ab] link_primeiro=%LINK_FIRST%

if exist "%ORD%" rmdir /s /q "%ORD%"
mkdir "%ORD%"

echo [ab] obj=%BIN%\symbol_gate.obj (o MESMO nas duas pontas)

rem --- A: os .def COM ordinal -----------------------------------------------------------
python "%AFM%\gen_import_libs.py" --out "%ORD%" --ordinal
set "RC=%ERRORLEVEL%"
echo [ab] gen_ordinal_codigo=%RC%
if not "%RC%"=="0" goto :gen_recusou
for %%L in (llama ggml ggml-base ggml-vulkan) do call :make_lib "%ORD%" %%L
link /nologo /OUT:"%ORD%\af_gate_ord.exe" "%BIN%\symbol_gate.obj" %LIBS% delayimp.lib %DELAY%
set "RC=%ERRORLEVEL%"
echo [ab] link_A_codigo=%RC%
if not "%RC%"=="0" goto :link_recusou
dumpbin /imports "%ORD%\af_gate_ord.exe" > "%ORD%\imports-ordinal.txt" 2>&1
set "RC=%ERRORLEVEL%"
echo [ab] dumpbin_A_codigo=%RC%

rem --- B: os .def SEM ordinal (os que o build usa) --------------------------------------
link /nologo /OUT:"%ORD%\af_gate_nomes.exe" "%BIN%\symbol_gate.obj" %NAMES% delayimp.lib %DELAY%
set "RC=%ERRORLEVEL%"
echo [ab] link_B_codigo=%RC%
if not "%RC%"=="0" goto :link_recusou
dumpbin /imports "%ORD%\af_gate_nomes.exe" > "%ORD%\imports-nomes.txt" 2>&1
set "RC=%ERRORLEVEL%"
echo [ab] dumpbin_B_codigo=%RC%

rem --- as duas contagens cruas, lidas do texto -------------------------------------------
rem Contar com `find /c /v ""` NAO funciona aqui, e isso e o furo #35 de novo: dentro da casca
rem do vcvars o `find.exe` que resolve e o do Git (GNU find), porque o vcvars PREPONE as pastas
rem dele e nao tira o `usr\bin` do PATH -- o MSVC nao tem `find`, entao o nome cai no coreutils
rem e a contagem vira uma varredura do C: inteiro (medido: `find: '/c/Config.Msi': Permission
rem denied` e dez minutos sem fim). Nenhum nome nu de ferramenta neste instrumento; so os
rem caminhos que o proprio build nomeia, e a contagem feita em python.
set "LIN_A="
for /f "usebackq delims=" %%N in (`python -c "import sys;print(len([l for l in open(sys.argv[1],encoding='utf-8',errors='replace') if 'Ordinal' in l]))" "%ORD%\imports-ordinal.txt"`) do set "LIN_A=%%N"
set "LIN_B="
for /f "usebackq delims=" %%N in (`python -c "import sys;print(len([l for l in open(sys.argv[1],encoding='utf-8',errors='replace') if 'Ordinal' in l]))" "%ORD%\imports-nomes.txt"`) do set "LIN_B=%%N"
echo [ab] linhas_com_palavra_ordinal A=%LIN_A% B=%LIN_B%

rem --- a mesma regua, duas tabelas -------------------------------------------------------
echo [ab] --- regua contra A (import por ordinal) ---
python "%AFM%\check_imports.py" --gate "%AFM%\src\symbol_gate.cpp" --absent "%AFM%\src\symbol_gate_absent.cpp" --defs "%ORD%" --imports "%ORD%\imports-ordinal.txt"
set "RC=%ERRORLEVEL%"
echo [ab] regua_A_codigo=%RC%
set "RC_A=%RC%"

echo [ab] --- regua contra B (import por nome) ---
python "%AFM%\check_imports.py" --gate "%AFM%\src\symbol_gate.cpp" --absent "%AFM%\src\symbol_gate_absent.cpp" --defs "%BIN%" --imports "%ORD%\imports-nomes.txt"
set "RC=%ERRORLEVEL%"
echo [ab] regua_B_codigo=%RC%
set "RC_B=%RC%"

rem O veredito so vale se a frase do ordinal foi MESMA: A recusa, B passa.
if not "%RC_B%"=="0" goto :veredito_ruim
if "%RC_A%"=="0" goto :veredito_ruim
echo [ab] OK: com `@n` a regua recusa (codigo %RC_A%); sem `@n` ela passa (codigo %RC_B%)
exit /b 0

rem --- sub-rotinas e diagnosticos --------------------------------------------------------

:make_lib
lib /def:"%~1\%~2.def" /machine:x64 /out:"%~1\%~2_import.lib" >nul 2>&1
set "RC=%ERRORLEVEL%"
echo [ab] lib %~2 codigo=%RC%
if not "%RC%"=="0" goto :lib_recusou
exit /b 0

:sem_obj
echo [falha] sem bin\symbol_gate.obj -- rode native\af_mind\build.bat primeiro
exit /b 2
:sem_gen
echo [falha] sem gen_import_libs.py ou check_imports.py
exit /b 2
:link_errado
echo [falha] o primeiro link do PATH e "%LINK_FIRST%", nao o do toolset -- VCToolsInstallDir="%VCToolsInstallDir%"
exit /b 2
:gen_recusou
echo [falha] o gerador com --ordinal saiu com %RC%
exit /b 3
:lib_recusou
echo [falha] lib recusou um .def gerado com --ordinal
exit /b 4
:link_recusou
echo [falha] link saiu com %RC% -- as duas pontas precisam linkar para o A/B comparar tabelas
exit /b 5
:veredito_ruim
echo [falha] o A/B nao separou: regua_A=%RC_A% regua_B=%RC_B% (esperado A nao-zero, B zero)
exit /b 6
