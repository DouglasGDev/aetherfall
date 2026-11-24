@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
pushd C:\Users\dougl\AppData\Local\Temp
cl /nologo /EHsc /std:c++17 /O2 af_native_probe2.cpp /Fe:af_native_probe2.exe
echo BUILD_ERRORLEVEL=%ERRORLEVEL%
af_native_probe2.exe > C:\Aetherfall\docs\evidence\oraculo-nativo-22\probe2-stdout.txt 2> C:\Aetherfall\docs\evidence\oraculo-nativo-22\probe2-stderr.txt
echo RUN_ERRORLEVEL=%ERRORLEVEL%
popd
