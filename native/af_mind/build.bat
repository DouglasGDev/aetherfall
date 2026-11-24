@echo off
rem Passo 1 (c) do dossie 22 (S5.1, S12.1, S12.2): o build do esqueleto nativo.
rem
rem Este .bat nao e um "cl src\*.cpp" porque a Fase 0 mediu tres coisas que tornam o
rem atalho perigoso nesta maquina, e cada uma virou uma regua aqui:
rem
rem  1. NAO EXISTE "o MSVC da máquina": existem tres instalacoes (2022 Community, 2019
rem     BuildTools, 2022 BuildTools) com dois toolsets (14.44.35207 e 14.29.30133) e as
rem     tres consultas `-latest` do vswhere divergem entre si (furo #34). Entao o build
rem     nomeia o toolset e so aceita uma instalacao que o tenha; ele nao pergunta ao
rem     vswhere qual e a mais nova.
rem  2. Fora da casca do vcvars, `link` RESOLVE -- para C:\Program Files\Git\usr\bin\
rem     link.exe, hard link de arquivo do coreutils, que nao linka nada (furo #35). Um
rem     build que esquecesse o vcvars falharia por presenca errada em vez de falhar por
rem     ausencia. Entao o build confere onde o primeiro `link` do PATH aponta.
rem  3. O instrumento da Fase 0 leu o codigo do proprio redirect em vez do compilador
rem     (furo #32). Entao todo codigo de saida aqui e lido na linha imediatamente
rem     seguinte ao comando SEM redirect, e as tres testemunhas de toolchain sao
rem     positivas (um caminho, uma linha de banner, um simbolo exportado), nao codigos.
rem
rem O cabecalho de interface e conferido por SHA-256 e o gate aceita AS DUAS FORMAS
rem (S12.2): a do checkout do git (LF, 4c0aac8d...) e a do fruto cru do gerador (CRLF,
rem 777a3fe5...). Uma regua que soubesse so uma delas passaria ou falharia conforme o
rem core.autocrlf de quem clonou.
rem
rem Nada aqui encosta no llama.cpp: nao ha uma .lib de importacao na arvore inteira
rem (S12.3), entao o Passo 1 compila contra o cabecalho e linka so contra o CRT estatico.

setlocal enableextensions

set "TOOLSET=14.44.35207"
set "CL_BANNER=19.44.35228"
set "SHA_LF=4c0aac8da3dfedc14d0e049205aeaaa11f32802bee56d4a275a466ac231fa916"
set "SHA_CRLF=777a3fe517c1b29eece0646c50ec0da1c617586ea2e9ffbc1965e8fdb9149b2b"

set "ROOT=%~dp0"
set "HDR=%ROOT%include\gdextension_interface.h"
set "SRC=%ROOT%src\register_types.cpp"
set "OUTDIR=%ROOT%bin"
set "DLL=%OUTDIR%\af_mind.dll"

if not exist "%HDR%" goto :sem_header
if not exist "%SRC%" goto :sem_src
if not exist "%OUTDIR%" mkdir "%OUTDIR%"
rem O importador do editor varre res:// e reclama o .obj do linker como Wavefront: medido,
rem tres linhas de ERROR em cada `--import` desta arvore (furo #37). `.gdignore` dentro de
rem bin e o mecanismo da propria engine para tirar a pasta da varredura, e o build o escreve
rem porque bin/ e gitignored -- num clone sem build nao ha bin, logo nao ha o que ignorar.
if not exist "%OUTDIR%\.gdignore" type nul > "%OUTDIR%\.gdignore"
if not exist "%OUTDIR%\.gdignore" goto :sem_gdignore

rem --- regua 1: o cabecalho vendorado e o fruto do gerador da tag 4.7.2-stable ---------
rem A linha de hash do certutil e a unica que consiste so em hexdigitos; as outras duas
rem (titulo e rodape) tem espacos e ponteiro e o texto delas e traduzido no Windows
rem pt-BR, entao a regua le a FORMA do valor, nao um rotulo em ingles.
set "HEADER_SHA="
for /f "usebackq delims=" %%L in (`certutil -hashfile "%HDR%" SHA256 ^| findstr /r "^[0-9A-Fa-f][0-9A-Fa-f]*$"`) do if not defined HEADER_SHA set "HEADER_SHA=%%L"
if not defined HEADER_SHA goto :hash_ilegivel
if /i "%HEADER_SHA%"=="%SHA_LF%" goto :header_ok
if /i "%HEADER_SHA%"=="%SHA_CRLF%" goto :header_ok
goto :hash_recusado
:header_ok
echo [regua] header_sha256=%HEADER_SHA% forma=aceita

rem --- regua 2: o toolset, nomeado; nunca o "mais novo" do vswhere ---------------------
set "VSROOT="
for %%V in ("C:\Program Files\Microsoft Visual Studio\2022\Community" "C:\Program Files\Microsoft Visual Studio\2022\BuildTools") do call :try_vs "%%~V"
if not defined VSROOT goto :sem_toolset
set "VCVARS=%VSROOT%\VC\Auxiliary\Build\vcvars64.bat"
echo [regua] vcvars=%VCVARS% toolset=%TOOLSET%

rem O chatter do vcvars vai para um log proprio; a decisao de continuar nao e o
rem ERRORLEVEL dele (furo #32) e sim a presenca de VCToolsInstallDir apontando para o
rem toolset nomeado, conferida logo abaixo.
call "%VCVARS%" -vcvars_ver=%TOOLSET% > "%OUTDIR%\vcvars.log" 2>&1

if not defined VCToolsInstallDir goto :sem_vctools
echo [regua] VCToolsInstallDir=%VCToolsInstallDir%
set "VC_TAIL=%VCToolsInstallDir:~-12%"
if /i not "%VC_TAIL%"=="%TOOLSET%\" goto :toolset_recusado

rem --- regua 3: o banner do cl e o do toolset, lido como texto -------------------------
set "CL_LINE="
for /f "usebackq delims=" %%L in (`cl /? 2^>^&1 ^| findstr /c:"%CL_BANNER%"`) do if not defined CL_LINE set "CL_LINE=%%L"
if not defined CL_LINE goto :cl_recusado
echo [regua] cl_banner=%CL_LINE%

rem --- regua 4: o primeiro `link` do PATH e o do toolset, nao o do Git (furo #35) ------
set "LINK_FIRST="
for /f "usebackq delims=" %%L in (`where link`) do if not defined LINK_FIRST set "LINK_FIRST=%%L"
if not defined LINK_FIRST goto :sem_link
if /i not "%LINK_FIRST%"=="%VCToolsInstallDir%bin\Hostx64\x64\link.exe" goto :link_recusado
echo [regua] link_primeiro=%LINK_FIRST%

rem --- compilar e linkar ----------------------------------------------------------------
cl /nologo /std:c++17 /O2 /MT /W3 /EHsc /I "%ROOT%include" /c "%SRC%" /Fo"%OUTDIR%\register_types.obj"
if errorlevel 1 goto :compilou_errado

link /nologo /DLL /OUT:"%DLL%" /IMPLIB:"%OUTDIR%\af_mind.lib" "%OUTDIR%\register_types.obj"
if errorlevel 1 goto :linkou_errado

if not exist "%DLL%" goto :sem_dll
for %%F in ("%DLL%") do set "DLL_BYTES=%%~zF"
echo [regua] dll_bytes=%DLL_BYTES%

rem --- regua 5: o simbolo que o .gdextension nomeia existe na tabela de exports --------
set "EXPORT_LINE="
for /f "usebackq delims=" %%L in (`dumpbin /exports "%DLL%" 2^>^&1 ^| findstr /c:"af_mind_entry"`) do if not defined EXPORT_LINE set "EXPORT_LINE=%%L"
if not defined EXPORT_LINE goto :sem_export
echo [regua] export=%EXPORT_LINE%

rem ================================================================================
rem Passo 2 (a) do dossie 22 (S1.3, S5.1): o gate de simbolos, executado.
rem
rem O criterio esta escrito ANTES das linhas abaixo, no S5.1 da pagina: o gate de
rem simbolos do S1.3 passa a ser gate do Passo 2, com import libs gerados do
rem export-set MEDIDO e /DELAYLOAD; e "o `.dll` resolve as DLLs do runtime no
rem diretorio de processo" e premissa do Passo 2, e e aqui que ela deixa de ser
rem frase. O que cada passo prova, na ordem em que roda:
rem
rem  1. os `.def` saem dos dumps ARQUIVADOS em docs/evidence (S1.3) e, se houver
rem     runtime no disco, sao re-medidos contra eles -- divergencia e recusa;
rem  2. quatro import libs por `lib /def:`; o `.lib` existir e a testemunha;
rem  3. o exe do gate linka contra os quatro libs com `/DELAYLOAD` em cada um: um
rem     nome que nao esteja no export-set medido e LNK2019 AQUI, nao um crash
rem     dentro do jogo (mandato 1);
rem  4. `check_imports.py` compara a tabela de imports do binario com o DONO medido
rem     de cada nome no export-set -- a metade que o linker nao sabe, e que custou o
rem     "0 backends" silencioso da segunda sonda (S1.3);
rem  5. as duas corridas: `nu` mede a premissa do diretorio do processo,
rem     `preload <runtime>` reproduz os numeros de S1.2. Cada codigo de saida e
rem     lido na linha imediatamente seguinte ao proprio comando e impresso
rem     (furo #32: nunca se le um codigo atraves de outra linha);
rem  6. o controle negativo: se `symbol_gate_absent.cpp` LINKAR, o gate nao e
rem     falsificavel e o build recusa. A recusa esperada e LNK2019 nomeando cada um
rem     dos quatro nomes, e o texto e conferido, nao presumido.
rem
rem O caminho do runtime vem de %1; sem argumento cai no caminho que a Fase 0
rem mede e que esta escrito nas sondas arquivadas. Sem runtime no disco o build
rem recusa (codigo 7): a regua de imports e o controle negativo continuam validos
rem sem ele, mas as corridas nao, e uma corrida pulada nao pode virar verde.
rem ================================================================================

set "GATE=%ROOT%src\symbol_gate.cpp"
set "ABSENT=%ROOT%src\symbol_gate_absent.cpp"
set "GEN=%ROOT%gen_import_libs.py"
set "CHK=%ROOT%check_imports.py"
set "GATE_EXE=%OUTDIR%\af_symbol_gate.exe"
set "IMPORT_LIBS=%OUTDIR%\llama_import.lib %OUTDIR%\ggml_import.lib %OUTDIR%\ggml-base_import.lib %OUTDIR%\ggml-vulkan_import.lib"
set "DELAYFLAGS=/DELAYLOAD:llama.dll /DELAYLOAD:ggml.dll /DELAYLOAD:ggml-base.dll /DELAYLOAD:ggml-vulkan.dll"
set "RUNTIME=%~1"
if not defined RUNTIME set "RUNTIME=C:\Aetherfall\.tools\llama\runtime"
if not exist "%GATE%" goto :sem_gate
if not exist "%ABSENT%" goto :sem_gate
if not exist "%GEN%" goto :sem_gen
if not exist "%CHK%" goto :sem_gen
if not exist "%RUNTIME%\llama.dll" goto :sem_runtime
echo [regua] runtime=%RUNTIME%

rem --- 1 e 2: os `.def` do export-set medido, e as quatro bibliotecas de importacao -----
pushd "%ROOT%..\.."
echo [regua] cwd_gerador=%CD%
python "%GEN%" --out "%OUTDIR%" --runtime "%RUNTIME%"
set "RC=%ERRORLEVEL%"
echo [gen] codigo=%RC%
if not "%RC%"=="0" goto :gen_recusou
popd
for %%L in (llama ggml ggml-base ggml-vulkan) do call :importlib %%L

rem --- 3: o exe do gate -----------------------------------------------------------------
cl /nologo /std:c++17 /O2 /MT /W3 /EHsc /c "%GATE%" /Fo"%OUTDIR%\symbol_gate.obj"
set "RC=%ERRORLEVEL%"
echo [gate] cl_codigo=%RC%
if not "%RC%"=="0" goto :compilou_errado
link /nologo /OUT:"%GATE_EXE%" "%OUTDIR%\symbol_gate.obj" %IMPORT_LIBS% delayimp.lib %DELAYFLAGS%
set "RC=%ERRORLEVEL%"
echo [gate] link_codigo=%RC%
if not "%RC%"=="0" goto :linkou_errado
if not exist "%GATE_EXE%" goto :sem_gate_exe
for %%F in ("%GATE_EXE%") do echo [regua] gate_exe_bytes=%%~zF

rem --- 4: a regua de imports, lida do binario, nao da minha prosa -----------------------
dumpbin /imports "%GATE_EXE%" > "%OUTDIR%\gate-imports.txt" 2>&1
set "RC=%ERRORLEVEL%"
echo [dumpbin] imports_codigo=%RC%
if not "%RC%"=="0" goto :dumpbin_recusou
pushd "%ROOT%..\.."
python "%CHK%" --gate "%GATE%" --absent "%ABSENT%" --defs "%OUTDIR%" --imports "%OUTDIR%\gate-imports.txt"
set "RC=%ERRORLEVEL%"
echo [imports] codigo=%RC%
if not "%RC%"=="0" goto :imports_recusou
popd

rem --- 5: as duas corridas, com o codigo lido na linha seguinte -------------------------
rem `nu` mede a premissa do diretorio do processo. Os dois codigos aceitos sao 0 (a
rem premissa e verdadeira e os numeros de S1.2 sairam por nome nu) e 5 (a premissa e
rem falsa e o gate RECUSOU em vez de morrer de STATUS_DLL_NOT_FOUND -- recusar e o
rem resultado medido, morrer nao e). Qualquer outro codigo, inclusive um codigo de
rem crash do loader, derruba o build.
echo [corrida] nu
"%GATE_EXE%" nu
set "RC=%ERRORLEVEL%"
echo [corrida] nu_codigo=%RC%
if "%RC%"=="0" goto :nu_ok
if "%RC%"=="5" goto :nu_ok
goto :corrida_recusada
:nu_ok

echo [corrida] preload
"%GATE_EXE%" preload "%RUNTIME%"
set "RC=%ERRORLEVEL%"
echo [corrida] preload_codigo=%RC%
if not "%RC%"=="0" goto :corrida_recusada

rem --- 6: o controle negativo, que NAO pode linkar --------------------------------------
cl /nologo /std:c++17 /O2 /MT /W3 /EHsc /c "%ABSENT%" /Fo"%OUTDIR%\symbol_gate_absent.obj"
set "RC=%ERRORLEVEL%"
echo [controle] cl_codigo=%RC%
if not "%RC%"=="0" goto :controle_compilou_errado
rem O exe do controle nao deve nascer; se sobrar de uma corrida anterior, ele invalidaria a
rem testemunha de baixo, entao sai antes do link.
if exist "%OUTDIR%\af_symbol_gate_absent.exe" del "%OUTDIR%\af_symbol_gate_absent.exe"
link /nologo /OUT:"%OUTDIR%\af_symbol_gate_absent.exe" "%OUTDIR%\symbol_gate_absent.obj" %IMPORT_LIBS% delayimp.lib %DELAYFLAGS% > "%OUTDIR%\gate-absent-link.txt" 2>&1
set "RC=%ERRORLEVEL%"
echo [controle] link_codigo=%RC%
if "%RC%"=="0" goto :controle_linkou
for %%N in (ggml_backend_buffer_type_get_base_buffer llama_model_n_ctx llama_new_context_with_model ggml_backend_buffer_type_get_alloc_size) do call :exige_lnk2019 %%N
if exist "%OUTDIR%\af_symbol_gate_absent.exe" goto :controle_exe_existe
echo [controle] OK: o gate e falsificavel -- os quatro nomes foram recusados pelo linker

echo [ok] build.bat: %DLL%
exit /b 0

rem --- sub-rotinas e diagnosticos -------------------------------------------------------

:try_vs
rem Aceita uma instalacao so se ela TIVER o toolset nomeado; o 2019 (14.29.30133) cai
rem aqui e a recusa e impressa, nao silenciosa.
if exist "%~1\VC\Tools\MSVC\%TOOLSET%" if not defined VSROOT set "VSROOT=%~1"
exit /b 0

:importlib
rem `lib /def:` nao tem saida em sucesso; a testemunha e o arquivo existir com bytes.
if not exist "%OUTDIR%\%~1.def" goto :sem_def
lib /def:"%OUTDIR%\%~1.def" /machine:x64 /out:"%OUTDIR%\%~1_import.lib"
set "RC=%ERRORLEVEL%"
echo [importlib] %~1 codigo=%RC%
if not "%RC%"=="0" goto :lib_recusou
if not exist "%OUTDIR%\%~1_import.lib" goto :sem_lib
for %%F in ("%OUTDIR%\%~1_import.lib") do echo [importlib] %~1_bytes=%%~zF
exit /b 0

:exige_lnk2019
rem A recusa so vale se for pelo motivo certo: LNK2019 nomeando o simbolo. Um LNK1561
rem (sem ponto de entrada) ou um LNK1181 (arquivo errado) daria nao-zero pelo motivo
rem errado e o controle pareceria ter funcionado.
findstr /c:"%~1" "%OUTDIR%\gate-absent-link.txt" >nul
set "RC=%ERRORLEVEL%"
echo [controle] %~1 recusa_lida=%RC%
if not "%RC%"=="0" goto :controle_silencioso
exit /b 0

:sem_header
echo [falha] sem include\gdextension_interface.h -- o Passo 1 (c) vendoriza o fruto do gerador da tag 4.7.2-stable
exit /b 2
:sem_src
echo [falha] sem src\register_types.cpp
exit /b 2
:sem_gdignore
echo [falha] nao consegui escrever bin\.gdignore -- sem ele o `--import` reclama o .obj do linker como OBJ
exit /b 2
:hash_ilegivel
echo [falha] certutil nao devolveu uma linha de hexdigitos para o cabecalho
exit /b 3
:hash_recusado
echo [falha] SHA-256 do cabecalho nao e nenhuma das duas formas aceitas: %HEADER_SHA%
exit /b 3
:sem_toolset
echo [falha] nenhuma instalacao com o toolset %TOOLSET%; o build recusa os outros toolsets porque dois toolsets sao duas ABIs
exit /b 4
:sem_vctools
echo [falha] vcvars rodou mas VCToolsInstallDir nao esta definido -- veja bin\vcvars.log
exit /b 4
:toolset_recusado
echo [falha] VCToolsInstallDir nao e o toolset nomeado: cauda=%VC_TAIL%, esperado=%TOOLSET%
exit /b 4
:cl_recusado
echo [falha] o cl no PATH nao devolveu o banner %CL_BANNER%
exit /b 4
:sem_link
echo [falha] link nao resolve dentro da casca do vcvars
exit /b 4
:link_recusado
echo [falha] o primeiro link do PATH e %LINK_FIRST%, nao o do toolset %TOOLSET%
exit /b 4
:compilou_errado
echo [falha] cl saiu com codigo nao-zero
exit /b 5
:linkou_errado
echo [falha] link saiu com codigo nao-zero
exit /b 5
:sem_dll
echo [falha] o link saiu zero mas %DLL% nao existe
exit /b 5
:sem_export
echo [falha] dumpbin nao viu af_mind_entry na tabela de exports: o entry_symbol do .gdextension mentiria
exit /b 6

rem --- codigos 7..9 sao do Passo 2 (a); 2..6 continuam sendo os do Passo 1 --------------
:sem_gate
echo [falha] Passo 2 (a): sem src\symbol_gate.cpp ou src\symbol_gate_absent.cpp -- o gate nao existe
exit /b 7
:sem_gen
echo [falha] Passo 2 (a): sem gen_import_libs.py ou check_imports.py -- nao ha de onde tirar os .def
exit /b 7
:sem_runtime
echo [falha] Passo 2 (a): sem llama.dll em %RUNTIME% -- as corridas nao rodam e corrida pulada nao e verde
echo [falha] passe o caminho como primeiro argumento: build.bat "C:\caminho\do\runtime"
exit /b 7
:gen_recusou
echo [falha] Passo 2 (a): gen_import_libs.py recusou -- ou nao ha dump arquivado, ou o runtime vivo diverge do pin b12499
exit /b 7
:sem_def
echo [falha] Passo 2 (a): sem %OUTDIR%\%~1.def -- o gerador nao escreveu o que o export-set medido tem
exit /b 7
:lib_recusou
echo [falha] Passo 2 (a): lib saiu com %RC% criando %~1_import.lib -- o .def do export-set medido foi recusado
exit /b 7
:sem_lib
echo [falha] Passo 2 (a): lib saiu zero mas %~1_import.lib nao existe
exit /b 7
:sem_gate_exe
echo [falha] Passo 2 (a): o link do gate saiu zero mas af_symbol_gate.exe nao existe
exit /b 7
:dumpbin_recusou
echo [falha] Passo 2 (a): dumpbin /imports do gate saiu com %RC% -- sem a tabela nao ha regua de modulos
exit /b 7
:imports_recusou
echo [falha] Passo 2 (a): a regua de imports recusou -- nome referenciado sem dono medido, dono duplo, ou importado do modulo errado
exit /b 7
:corrida_recusada
echo [falha] Passo 2 (a): o gate saiu com %RC%; aceitos 0 e 5 em nu, 0 em preload -- os numeros de S1.2 nao sairam
exit /b 8
:controle_compilou_errado
echo [falha] Passo 2 (a): symbol_gate_absent.cpp nem compilou -- o controle nao chegou ao linker
exit /b 9
:controle_linkou
echo [falha] Passo 2 (a): o controle negativo LINKOU -- os quatro nomes existem no que foi linkado, entao a lista do gate nao veio do export-set medido
exit /b 9
:controle_exe_existe
echo [falha] Passo 2 (a): o link recusou mas af_symbol_gate_absent.exe existe -- a testemunha nao e do que esta no disco
exit /b 9
:controle_silencioso
echo [falha] Passo 2 (a): o link recusou sem nomear %~1 em gate-absent-link.txt -- recusou pelo motivo errado e o controle nao vale
exit /b 9
