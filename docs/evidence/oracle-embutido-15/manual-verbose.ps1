$ErrorActionPreference = "Stop"
# Linhas do proprio llama-server com verbosidade máxima: e delas que sai o
# total de VRAM do device Vulkan e o que o modelo realmente pousou na placa.
$Server = "C:\Aetherfall\.tools\llama\runtime\llama-server.exe"
$Model  = "C:\Aetherfall\models\qwen3.5-4b-q4_k_m.gguf"
$Log    = "C:\Aetherfall\.tools\logs15\manual-server-verbose.log"
$p = Start-Process -FilePath $Server -ArgumentList @(
    "-m", $Model, "--host", "127.0.0.1", "--port", "8741", "-c", "4096",
    "-ngl", "99", "--alias", "mind-small", "--reasoning", "off",
    "--api-key", "aetherfall-mind-2026", "-lv", "7"
) -RedirectStandardOutput $Log -RedirectStandardError "$Log.err" -NoNewWindow -PassThru
Write-Host "pid_win=$($p.Id)"
$deadline = (Get-Date).AddSeconds(150)
$code = ""
while ((Get-Date) -lt $deadline) {
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:8741/health" -Headers @{Authorization = "Bearer aetherfall-mind-2026"} -UseBasicParsing -TimeoutSec 3
        $code = [string]$r.StatusCode
    } catch { $code = [string]$_.Exception.Response.StatusCode.value__ }
    if ($code -eq "200") { break }
    Start-Sleep -Milliseconds 250
}
Write-Host "health=$code  apos=$((Get-Date).Subtract($p.StartTime).TotalMilliseconds) ms"
Start-Sleep -Seconds 3
Write-Host "--- props ---"
try { (Invoke-WebRequest -Uri "http://127.0.0.1:8741/props" -Headers @{Authorization = "Bearer aetherfall-mind-2026"} -UseBasicParsing).Content } catch { Write-Host "props falhou: $($_.Exception.Message)" }
Stop-Process -Id $p.Id -Force
Write-Host "fixture verboso encerrado"
