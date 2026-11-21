$ErrorActionPreference = "Stop"
# Teste do produto, na janela real: o proprio processo do jogo tem de subir o
# llama-server sem nenhum passo manual, e o fecho da janela tem de derruba-lo.
# O override por variavel de ambiente existe para isto: o runtime mora no
# checkout principal, o codigo em revisao esta no worktree.
$Exe   = "C:\Aetherfall\.tools\Godot_v4.7.2-stable_win64_console.exe"
$Proj  = "C:\Aetherfall\.tools\wt-code-15"
$Log   = "C:\Aetherfall\.tools\logs15\janela-embedded.log"
$env:AETHERFALL_LLM_SERVER = "C:/Aetherfall/.tools/llama/runtime/llama-server.exe"
$env:AETHERFALL_LLM_MODEL  = "C:/Aetherfall/models/qwen3.5-4b-q4_k_m.gguf"
$Hdr = @{ Authorization = "Bearer aetherfall-mind-2026" }

function Probe-Port() {
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:8741/v1/models" -Headers $Hdr -UseBasicParsing -TimeoutSec 2
        return "200 " + (($r.Content | ConvertFrom-Json).data | ForEach-Object { $_.id }) -join ","
    } catch {
        $c = $_.Exception.Response.StatusCode.value__
        if ($c) { return "http $c" }
        return "sem conexao"
    }
}

$t0 = Get-Date
$p = Start-Process -FilePath $Exe -ArgumentList @("--path", $Proj, "--quit-after", "2400") `
    -RedirectStandardOutput $Log -RedirectStandardError "$Log.err" -PassThru
Write-Host "janela pid=$($p.Id)  iniciada $($t0.ToString('HH:mm:ss.fff'))"

$maxima = ""
$sobiu = $false
for ($i = 0; $i -lt 120; $i++) {
    $st = Probe-Port
    $kids = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" |
        ForEach-Object { $_.Name })
    $llamas = @(Get-CimInstance Win32_Process -Filter "Name='llama-server.exe'" |
        ForEach-Object { "pid $_ ($($_.ProcessId)) pai $($_.ParentProcessId)" })
    $vivo = -not $p.HasExited
    Write-Host ("t+{0,5} ms  janela={1}  porta={2}  filhos={3}  {4}" -f `
        [int]((Get-Date) - $t0).TotalMilliseconds, $vivo, $st, ($kids -join ","), ($llamas -join " | "))
    if ($llamas.Count -gt 0) { $sobiu = $true }
    if (-not $vivo) { break }
    if ($st -like "200*") { break }
    Start-Sleep -Milliseconds 1000
}

Write-Host "esperando a janela fechar sozinha (--quit-after 2400)..."
$null = $p.WaitForExit(180)
Write-Host ("janela saiu com codigo {0}  t+{1} ms" -f $p.ExitCode, [int]((Get-Date) - $t0).TotalMilliseconds)
Start-Sleep -Seconds 3
$depois = Probe-Port
$llamasDepois = @(Get-CimInstance Win32_Process -Filter "Name='llama-server.exe'" | ForEach-Object { $_.ProcessId })
Write-Host ("apos o fecho: porta={0}  llama-server restantes={1}" -f $depois, ($llamasDepois -join ","))
Write-Host "subiu filho durante a janela? $sobiu"
