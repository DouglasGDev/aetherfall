@echo off
REM Leitura dos export-sets do runtime llama.cpp pinado em .tools/llama/runtime (Fase 0, dossie 22 §1.3).
REM A contagem é o que decide o "gate de link" da Fase 1: o binding só pode chamar o que aparece aqui.
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
dumpbin /exports "C:\Aetherfall\.tools\llama\runtime\llama.dll" > "C:\Aetherfall\docs\evidence\oraculo-nativo-22\exports-llama.txt"
dumpbin /exports "C:\Aetherfall\.tools\llama\runtime\ggml-base.dll" > "C:\Aetherfall\docs\evidence\oraculo-nativo-22\exports-ggml-base.txt"
dumpbin /exports "C:\Aetherfall\.tools\llama\runtime\ggml.dll" > "C:\Aetherfall\docs\evidence\oraculo-nativo-22\exports-ggml.txt"
dumpbin /exports "C:\Aetherfall\.tools\llama\runtime\ggml-vulkan.dll" > "C:\Aetherfall\docs\evidence\oraculo-nativo-22\exports-ggml-vulkan.txt"
dumpbin /exports "C:\Aetherfall\.tools\llama\runtime\llama-fit-params-impl.dll" > "C:\Aetherfall\docs\evidence\oraculo-nativo-22\exports-fit-params.txt"
