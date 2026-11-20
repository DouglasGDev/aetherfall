# Sobe o oraculo local do Aetherfall: llama-server (llama.cpp, MIT) servindo o
# mind-small (Qwen3.5-4B Q4_K_M, Apache-2.0) na 9060 XT via Vulkan. Enquanto
# este processo roda, o MindOracle do jogo narra o interior dos mobs no debug
# (F3). Sem ele o jogo segue completo — a narrativa fica vazia e a IA decide
# como sempre (degradacao, docs/design/08).
#
# Desde a perna 15 o lancamento normal NAO precisa deste script: o jogo levanta
# e derruba o llama-server sozinho (src/ai/llm_server_host.gd). Ele ficou para
# dois casos: servir uma janela que roda em outro checkout, e a medicao/sonda
# que quer o servidor vivo antes de o jogo abrir. Se os dois rodarem juntos na
# mesma porta, o host reusa o servidor (mesma chave, mesmo alias) em vez de
# criar um segundo processo.
#
# Packs: rode antes tools\fetch_models.ps1 (runtime + mind-small).
# Uso (PowerShell, um comando por bloco):
#   powershell -ExecutionPolicy Bypass -File tools\run_mind_server.ps1

param(
    [int]$Port = 8741,
    [int]$Ctx = 4096,
    [int]$GpuLayers = 99,
    [string]$ApiKey = "aetherfall-mind-2026"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Server = Join-Path $Root ".tools\llama\runtime\llama-server.exe"
$Model = Join-Path $Root "models\qwen3.5-4b-q4_k_m.gguf"

if (-not (Test-Path $Server)) {
    throw "runtime ausente: rode tools\fetch_models.ps1 -Pack runtime"
}
if (-not (Test-Path $Model)) {
    throw "modelo ausente: rode tools\fetch_models.ps1 -Pack mind-small"
}

Write-Host "oraculo local em http://127.0.0.1:$Port  (ctrl+c encerra)"
& $Server `
    -m $Model `
    --host 127.0.0.1 `
    --port $Port `
    -c $Ctx `
    -ngl $GpuLayers `
    --alias mind-small `
    --reasoning off `
    --api-key $ApiKey
