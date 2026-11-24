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

echo [ok] build.bat: %DLL%
exit /b 0

rem --- sub-rotinas e diagnosticos -------------------------------------------------------

:try_vs
rem Aceita uma instalacao so se ela TIVER o toolset nomeado; o 2019 (14.29.30133) cai
rem aqui e a recusa e impressa, nao silenciosa.
if exist "%~1\VC\Tools\MSVC\%TOOLSET%" if not defined VSROOT set "VSROOT=%~1"
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
