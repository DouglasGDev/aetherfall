# Baixa os pacotes de IA local do Aetherfall com verificacao de integridade.
#
# Padrao do ModelPackFetcher (docs/design/04 e 08): cada pacote e um par
# URL + SHA256 + licenca. O arquivo so entra no destino depois de conferido;
# download parcial nunca vira modelo. Tudo aqui vive fora do repositorio
# (.tools/ e models/ estao no .gitignore): o jogo roda 100% sem eles.
#
# Uso (PowerShell, um comando por bloco):
#   powershell -ExecutionPolicy Bypass -File tools\fetch_models.ps1
#   powershell -ExecutionPolicy Bypass -File tools\fetch_models.ps1 -Pack runtime
#   powershell -ExecutionPolicy Bypass -File tools\fetch_models.ps1 -Pack mind-small

param(
    [ValidateSet("all", "runtime", "mind-small")]
    [string]$Pack = "all"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()
}

function Install-Pack {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Sha256,
        [long]$Bytes,
        [string]$DestDir,
        [string]$DestName,
        [string]$License,
        [switch]$ExtractZip
    )
    Write-Host "== pacote $Name =="
    Write-Host "   licenca: $License"
    Write-Host "   origem : $Url"

    New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
    $Dest = Join-Path $DestDir $DestName

    if ($ExtractZip -and (Test-Path $Dest)) {
        Write-Host "   ok: $DestName ja extraido em $DestDir"
        return
    }

    if (Test-Path $Dest) {
        $Atual = Get-FileSha256 $Dest
        if ($Atual -eq $Sha256) {
            Write-Host "   ok: $DestName ja presente e conferido"
            return
        }
        Write-Host "   presente mas com sha diferente; baixando de novo"
        Remove-Item -Force $Dest
    }

    $Tmp = "$Dest.tmp"
    if (Test-Path $Tmp) { Remove-Item -Force $Tmp }
    $curl = Join-Path $env:SystemRoot "System32\curl.exe"
    & $curl -L --fail --retry 3 -o $Tmp $Url
    if ($LASTEXITCODE -ne 0) {
        throw "curl falhou ($LASTEXITCODE) em $Url"
    }

    $RealBytes = (Get-Item $Tmp).Length
    if ($Bytes -gt 0 -and $RealBytes -ne $Bytes) {
        throw "tamanho divergente: esperado $Bytes, recebido $RealBytes"
    }
    $RealSha = Get-FileSha256 $Tmp
    if ($RealSha -ne $Sha256) {
        throw "sha256 divergente: esperado $Sha256, recebido $RealSha (arquivo descartado)"
    }

    if ($ExtractZip) {
        $TmpZip = Join-Path $DestDir "$DestName.zip"
        Move-Item -Force $Tmp $TmpZip
        Expand-Archive -Path $TmpZip -DestinationPath $DestDir -Force
        Remove-Item -Force $TmpZip
        Write-Host "   extraido em $DestDir"
    }
    else {
        Move-Item -Force $Tmp $Dest
        Write-Host "   instalado em $Dest ($([math]::Round($Bytes / 1GB, 2)) GB)"
    }
}

# runtime: llama.cpp pre-built Vulkan (MIT) para o 9060 XT e qualquer GPU
# moderna; serve o modelo via llama-server (endpoint OpenAI em localhost).
if ($Pack -in @("all", "runtime")) {
    Install-Pack `
        -Name "llama.cpp b12499 (win-vulkan-x64)" `
        -Url "https://github.com/ggml-org/llama.cpp/releases/download/b12499/llama-b12499-bin-win-vulkan-x64.zip" `
        -Sha256 "84db9d1816121328c9425fb41f4667209302584cf1016a2c4b5e759096a74f72" `
        -Bytes 38603682 `
        -DestDir (Join-Path $Root ".tools\llama") `
        -DestName "runtime" `
        -License "MIT (llama.cpp, ggml-org)" `
        -ExtractZip
}

# mind-small: o modelo sempre ligado da arquitetura (docs/design/04),
# faixa 1.5-4B em Q4_K_M. Qwen3.5-4B (Apache-2.0, 2026), quantizacao da
# unsloth. Narracao de memoria dos mobs e NPC em pt-BR.
if ($Pack -in @("all", "mind-small")) {
    Install-Pack `
        -Name "Qwen3.5-4B Q4_K_M" `
        -Url "https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_K_M.gguf" `
        -Sha256 "00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4" `
        -Bytes 2740937888 `
        -DestDir (Join-Path $Root "models") `
        -DestName "qwen3.5-4b-q4_k_m.gguf" `
        -License "Apache-2.0 (Qwen3.5-4B; quantizacao unsloth)"
}

Write-Host ""
Write-Host "licencas registradas em THIRD_PARTY_LICENSES.md"
