# Abre o Aetherfall sem compilar nada e sem linha de comando.
#
# O que este script faz, nesta ordem:
#   1. acha o motor Godot 4.7.2 (o pin do projeto; project.godot declara
#      config/features = "4.7"),
#   2. se nao ha motor, baixa o build portavel oficial para dentro de .tools/
#      e confere tamanho + sha256 antes de extrair,
#   3. se falta o cache de importacao (.godot/global_script_class_cache.cfg),
#      roda o --import: sem ele o projeto abre com "Could not find type" em
#      tudo que usa class_name,
#   4. lanca o jogo.
#
# Nao ha build step: o "executavel" do jogo e o proprio projeto (GDScript) mais
# a engine portavel. models/ e .tools/ estao no .gitignore e o jogo roda sem
# eles (o oraculo de IA e opcional).
#
# Uso (PowerShell, um comando por bloco):
#   powershell -ExecutionPolicy Bypass -File tools\run_game.ps1              # abre o jogo
#   powershell -ExecutionPolicy Bypass -File tools\run_game.ps1 -CheckOnly   # so diagnostico
#   powershell -ExecutionPolicy Bypass -File tools\run_game.ps1 -Editor      # abre o editor
#   powershell -ExecutionPolicy Bypass -File tools\run_game.ps1 -Tests       # suite headless
#   powershell -ExecutionPolicy Bypass -File tools\run_game.ps1 -Engine "D:\Godot\Godot_v4.7.2-stable_win64.exe"
#   powershell -ExecutionPolicy Bypass -File tools\run_game.ps1 -Force       # abre mesmo com outra janela do jogo
#
# Ou com 1 clique: dois toques em Rodar.bat na raiz do clone.

param(
    [string]$Engine = "",
    [switch]$CheckOnly,
    [switch]$Editor,
    [switch]$Tests,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Os erros daqui sao para uma pessoa que deu dois toques num .bat: sai so a
# frase, sem o quadro de excecao do PowerShell em cima.
trap {
    Write-Host ""
    Write-Host "ERRO: $($_.Exception.Message)"
    exit 1
}

$Root = Split-Path -Parent $PSScriptRoot
$ClassCache = Join-Path $Root ".godot\global_script_class_cache.cfg"

# Este launcher e do Windows: o pin e o zip win64, e a leitura das instancias
# abertas usa WMI. Em Linux/macOS o caminho e o mesmo, na mao:
#   godot --headless --path . --import && godot --path .
if ($env:OS -ne "Windows_NT") {
    throw "este launcher so roda no Windows; em Linux/macOS: godot --headless --path . --import e depois godot --path ."
}

# Pin do motor. URL, tamanho e digest vem da API de releases do repositorio
# oficial do Godot (tag 4.7.2-stable, asset Godot_v4.7.2-stable_win64.exe.zip);
# conferidos nesta maquina em 2026-11-18 contra o zip ja presente em .tools/.
# O download so e aceito se bater os dois numeros.
$EngineVersion = "4.7.2-stable"
$EngineExeName = "Godot_v4.7.2-stable_win64.exe"
$EngineUrl = "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip"
$EngineZipBytes = 86013866
$EngineZipSha256 = "731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953"
$ToolsDir = Join-Path $Root ".tools"
$PinnedExe = Join-Path $ToolsDir $EngineExeName


function Write-Step([string]$Text) {
    Write-Host "== $Text =="
}


## A versao que o binario reporta, lida de um probe real e nao do nome do
## arquivo: medido aqui, os dois builds imprimem "4.7.2.stable.official.<hash>"
## quando o PowerShell captura o stdout, e isso acontece antes de abrir janela.
## Um exe corrompido nao imprime nada e devolve $null, que e o ponto: nome de
## arquivo sozinho aprovaria o binario que nao roda.
function Get-GodotVersion([string]$Exe) {
    if (-not (Test-Path $Exe)) { return $null }
    foreach ($p in @($Exe, ($Exe -replace "\.exe$", "_console.exe"))) {
        if (-not (Test-Path $p)) { continue }
        # exe truncado/nao-executavel faz o call operator lancar com
        # ErrorActionPreference Stop: o probe quebra em silencio, nao o launcher
        try {
            $out = & $p --version 2>$null | Select-Object -Last 1
            if ($out -match "(\d+\.\d+\.\d+)") { return $Matches[1] }
        }
        catch { }
    }
    return $null
}


## Candidatos do PATH. Isso nao e varrer o disco: e a lista de pastas que o
## proprio usuario ja declarou. Quem tem o motor em outro lugar usa -Engine.
function Find-GodotOnPath {
    $hits = @()
    if (-not $env:PATH) { return $hits }
    $names = @($EngineExeName, "godot.exe", "Godot.exe")
    foreach ($dir in ($env:PATH -split ";")) {
        # entrada de PATH aspasada e literal em alguns instaladores
        $d = $dir.Trim().Trim('"')
        if (-not $d) { continue }
        foreach ($leaf in $names) {
            $p = Join-Path $d $leaf
            if (Test-Path $p) {
                $full = (Get-Item $p).FullName
                if ($hits -notcontains $full) { $hits += $full }
            }
        }
    }
    return $hits
}


function Install-PinnedGodot {
    Write-Step "baixando o Godot $EngineVersion (portavel, $([math]::Round($EngineZipBytes / 1MB, 1)) MB)"
    Write-Host "   origem : $EngineUrl"
    New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null

    $Zip = Join-Path $ToolsDir ("godot_$EngineVersion.zip")
    $Tmp = "$Zip.tmp"
    if (Test-Path $Tmp) { Remove-Item -Force $Tmp }

    $curl = Join-Path $env:SystemRoot "System32\curl.exe"
    & $curl -L --fail --retry 3 -o $Tmp $EngineUrl
    if ($LASTEXITCODE -ne 0) { throw "curl falhou ($LASTEXITCODE) em $EngineUrl" }

    $Real = (Get-Item $Tmp).Length
    if ($Real -ne $EngineZipBytes) {
        Remove-Item -Force $Tmp
        throw "tamanho divergente: esperado $EngineZipBytes, recebido $Real (arquivo descartado)"
    }
    $Sha = (Get-FileHash -Path $Tmp -Algorithm SHA256).Hash.ToLower()
    if ($Sha -ne $EngineZipSha256) {
        Remove-Item -Force $Tmp
        throw "sha256 divergente: esperado $EngineZipSha256, recebido $Sha (arquivo descartado)"
    }
    Write-Host "   ok: tamanho e sha256 conferem"

    Move-Item -Force $Tmp $Zip
    Expand-Archive -Path $Zip -DestinationPath $ToolsDir -Force
    Remove-Item -Force $Zip
    if (-not (Test-Path $PinnedExe)) {
        throw "o zip nao continha $EngineExeName; nada foi instalado"
    }
    Write-Host "   instalado em $ToolsDir"
}


## Devolve uma tabela @{exe; ver; from} do motor a usar, ou para com mensagem.
function Resolve-Godot {
    if ($Engine -ne "") {
        if (-not (Test-Path $Engine)) { throw "-Engine aponta para algo que nao existe: $Engine" }
        $v = Get-GodotVersion $Engine
        if (-not $v) {
            throw "nao consegui ler a versao de $Engine - o binario nao respondeu a --version (nao roda, ou nao e o Godot)"
        }
        return @{ exe = (Get-Item $Engine).FullName; ver = $v; from = "-Engine" }
    }

    if (Test-Path $PinnedExe) {
        $v = Get-GodotVersion $PinnedExe
        if ($v -eq "4.7.2") {
            return @{ exe = $PinnedExe; ver = $v; from = ".tools, o pin do projeto" }
        }
        if ($v) { Write-Host "aviso: $PinnedExe reporta $v, nao 4.7.2; procurando outro" }
        else { Write-Host "aviso: $PinnedExe nao respondeu a --version; procurando outro" }
    }

    foreach ($c in (Find-GodotOnPath)) {
        $v = Get-GodotVersion $c
        if ($v -like "4.7.*") {
            Write-Host "usando o Godot $v que ja esta no PATH: $c"
            Write-Host "   (o pin do projeto e $EngineVersion; -Engine aponta para outro se quiser)"
            return @{ exe = $c; ver = $v; from = "PATH" }
        }
        if ($v) { Write-Host "ignorado, versao $v e o projeto pede 4.7: $c" }
    }

    Install-PinnedGodot
    $v = Get-GodotVersion $PinnedExe
    if ($v -ne "4.7.2") { throw "motor baixado nao reporta 4.7.2 (reportou $v)" }
    return @{ exe = $PinnedExe; ver = $v; from = ".tools, baixado agora" }
}


## Build de console quando existe: e ele que escreve na janela do launcher
## enquanto roda. O build de GUI tambem escreve quando o stdout e redirecionado
## (medido no --version), mas ao vivo nada aparece nele -- por isso a rota sem
## console da Invoke-GodotHeadless redireciona para arquivo.
function Get-ConsoleExe([string]$Exe) {
    $c = $Exe -replace "\.exe$", "_console.exe"
    if (Test-Path $c) { return $c }
    return $Exe
}


## Instancias deste projeto que ja estao de pe. So da para afirmar quando o
## motor e o .tools do proprio projeto: qualquer processo rodando aquele
## binario com --path e daqui, e duas janelas abertas disputam o mesmo
## user://saves. Rodada --headless (a suite) nao escreve save, entao nao conta.
## O build de GUI e o de console sao o mesmo jogo: os dois nomes contam, e o
## que separa este projeto de outro clone com a mesma engine e o diretorio.
function Get-GameInstances([string]$Exe) {
    $dir = Split-Path -Parent $Exe
    $leaf = Split-Path -Leaf $Exe
    $console = $leaf -replace "\.exe$", "_console.exe"
    $rows = Get-CimInstance -Query "Select ProcessId, CommandLine From Win32_Process Where Name = '$leaf' OR Name = '$console'" -ErrorAction SilentlyContinue
    $found = @()
    foreach ($r in $rows) {
        $cl = [string]$r.CommandLine
        if (-not $cl) { continue }
        if ($cl -notmatch "--path") { continue }
        if ($cl -match "--headless") { continue }
        $first = $cl
        if ($first.StartsWith('"')) {
            $first = $first.Substring(1)
            $cut = $first.IndexOf('"')
            if ($cut -ge 0) { $first = $first.Substring(0, $cut) }
        }
        else {
            $first = ($first -split "\s+")[0]
        }
        if ((Split-Path -Parent $first) -ne $dir) { continue }
        $found += ("PID " + $r.ProcessId + "  " + $cl)
    }
    return $found
}


## Start-Process nao coloca aspas nos argumentos, entao o caminho do clone, que
## pode ter espaco, e citado a mao.
function Format-Argv([string[]]$Argv) {
    $quoted = @()
    foreach ($a in $Argv) {
        if ($a -match "\s") { $quoted += ('"' + $a + '"') }
        else { $quoted += $a }
    }
    return $quoted
}


## Lanca o motor sem prender a janela do launcher: se o processo ainda esta vivo
## depois de 6 s, o jogo abriu e este script sai limpo (a janela preta nao fica
## na tela durante a partida). Se ele morreu nesse prazo, devolvemos o codigo
## para o chamador reabrir pelo build de console e mostrar o erro.
function Start-GodotAndCheck([string]$Exe, [string[]]$Argv) {
    $p = Start-Process -FilePath $Exe -ArgumentList (Format-Argv $Argv) -PassThru
    if (-not $p.WaitForExit(6000)) {
        Write-Host "   o jogo abriu; esta janela ja pode fechar (ou fechar ela mesma)."
        return 0
    }
    return $p.ExitCode
}


## Rodadas sem janela: --import e a suite. Precisam de log visivel, entao o
## build de console e chamado direto; sem ele, o stdout e redirecionado para um
## arquivo, porque build de GUI lancado de um console nao escreve em lugar algum.
function Invoke-GodotHeadless([string]$Exe, [string[]]$Argv) {
    $console = Get-ConsoleExe $Exe
    if ($console -ne $Exe) {
        & $console $Argv
        return $LASTEXITCODE
    }
    $log = Join-Path $env:TEMP ("aetherfall_godot_" + [guid]::NewGuid().ToString("N") + ".log")
    $p = Start-Process -FilePath $Exe -ArgumentList (Format-Argv $Argv) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    if (Test-Path $log) { Get-Content $log -Tail 40 }
    if (Test-Path "$log.err") { Get-Content "$log.err" -Tail 40 }
    Remove-Item -Force $log, "$log.err" -ErrorAction SilentlyContinue
    return $p.ExitCode
}


# --------------------------------------------------------------------- fluxo

if (-not (Test-Path (Join-Path $Root "project.godot"))) {
    throw "project.godot nao esta em $Root - rode de dentro do clone."
}

Write-Step "motor"
$godot = Resolve-Godot
Write-Host "   $($godot.ver)  ($($godot.from))"
Write-Host "   exe : $($godot.exe)"

$importArgv = @("--headless", "--path", $Root, "--import")
if ($Editor) {
    $runArgv = @("-e", "--path", $Root)
    $mode = "editor"
}
elseif ($Tests) {
    $runArgv = @("--headless", "--path", $Root, "tests/smoke_test.tscn")
    $mode = "suite"
}
else {
    $runArgv = @("--path", $Root)
    $mode = "jogo"
}

$needsImport = -not (Test-Path $ClassCache)

# com motor do PATH nao da para saber de qual projeto e a instancia, e o check
# viraria falso positivo; so vale para o binario pinado em .tools
$openGames = @()
if ($godot.from -like ".tools*") {
    $openGames = @(Get-GameInstances $godot.exe)
}

Write-Step "plano"
Write-Host "   projeto : $Root"
Write-Host "   modo    : $mode"
if ($needsImport) {
    Write-Host "   import  : necessario (falta .godot\global_script_class_cache.cfg)"
}
else {
    Write-Host "   import  : ja feito"
}
if ($openGames.Count -gt 0) {
    Write-Host "   aberto  : $($openGames.Count) instancia(s) deste projeto"
    foreach ($g in $openGames) { Write-Host "             $g" }
}
Write-Host "   comando : `"$($godot.exe)`" $($runArgv -join ' ')"

if ($CheckOnly) {
    Write-Host ""
    Write-Host "diagnostico apenas (-CheckOnly): nada foi aberto."
    exit 0
}

if ($openGames.Count -gt 0 -and $mode -eq "jogo" -and -not $Force) {
    Write-Host ""
    Write-Host "Ja existe uma janela deste projeto aberta (lista acima). Abrir a segunda"
    Write-Host "faz as duas escreverem no mesmo save (user://saves/world_alpha.json) e a"
    Write-Host "ultima gravacao vence. Fecha a janela que esta aberta, ou passa -Force."
    exit 2
}

if ($openGames.Count -gt 0 -and $mode -eq "suite") {
    Write-Host "aviso: ha jogo aberto; a suite vai rodar competindo por CPU, entao os"
    Write-Host "       numeros de tempo desta corrida nao sao publicaveis."
}

if ($needsImport) {
    Write-Step "importando o projeto (uma vez so; monta o .godot/ e o registro de classes)"
    $rc = Invoke-GodotHeadless $godot.exe $importArgv
    if ($rc -ne 0) { throw "o import falhou com codigo $rc" }
    if (-not (Test-Path $ClassCache)) {
        throw "o import terminou mas o cache de classes nao apareceu; veja o log acima"
    }
    Write-Host "   ok"
}

if ($mode -eq "suite") {
    Write-Step "suite headless"
    $rc = Invoke-GodotHeadless $godot.exe $runArgv
    Write-Host ""
    Write-Host "codigo $rc (0 = tudo passou)"
    exit $rc
}

Write-Step "abrindo o $mode"
Write-Host "   primeiro boot gera o mundo e malha os 64 chunks: alguns segundos de espera."
$rc = Start-GodotAndCheck $godot.exe $runArgv
if ($rc -eq 0) { exit 0 }

Write-Host ""
Write-Host "o motor saiu com codigo $rc. Reabrindo pelo build de console para o erro aparecer:"
$console = Get-ConsoleExe $godot.exe
if ($console -eq $godot.exe) {
    Write-Host "   nao ha build de console junto de $($godot.exe); rode -CheckOnly e veja o plano acima."
    exit $rc
}
& $console $runArgv
exit $LASTEXITCODE
