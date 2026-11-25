# Abre o Aetherfall sem compilar nada e sem linha de comando.
#
# O que este script faz, nesta ordem:
#   1. acha o motor Godot 4.7.2 (o pin do projeto; project.godot declara
#      config/features = "4.7"),
#   2. se nao ha motor, baixa o build portavel oficial para dentro de .tools/
#      e confere tamanho + sha256 antes de extrair,
#   3. confere o cache de importacao (.godot/) contra a arvore: se falta, se o
#      motor mudou, ou se algum .gd/.tscn/.tres/imagem/audio esta mais novo que
#      o ultimo import, roda o --import antes de abrir. Sem isso o jogo abre
#      lendo produto velho -- "Could not find type" para todo class_name novo,
#      textura e som antigos -- porque o que ele carrega e o .godot/imported/,
#      nao o arquivo da arvore,
#   4. recusa abrir se ja ha janela do mesmo save (user:// e o config/name do
#      project.godot, nao a pasta), e lanca o jogo.
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
$ImportedDir = Join-Path $Root ".godot\imported"

# O carimbo que este launcher grava depois de um import bem sucedido: a data do
# global_script_class_cache.cfg nao serve de referencia porque o motor so reescreve
# aquele arquivo quando a LISTA de classes muda -- editar um .gd sem mudar o
# registro deixaria o cache parecendo fresco para sempre.
$ImportStampRel = ".godot\aetherfall_last_import.txt"

# Tipos cujo conteudo o motor copia para dentro de .godot/imported/ (e o registro
# de classes): mexer neles e o que faz a arvore ficar mais nova que o produto.
# .json fica fora de proposito: o jogo le levels.json e os saves direto do disco.
$ImportExts = @(
    ".gd", ".uid", ".tscn", ".tres", ".gdshader",
    ".png", ".jpg", ".jpeg", ".webp", ".svg",
    ".ogg", ".wav", ".mp3", ".ttf", ".otf", ".glb", ".gltf"
)

# docs/ nao entra: nenhuma linha de res:// carrega a evidencia, e cada commit de
# documento forcaria um import. models/ e lido pelo oraculo em disco, nao pelo
# motor. Os pontos comecados em "." (.git, .godot, .qoder, .tools) caiem sozinhos.
$ImportSkipDirs = @("docs", "models", "logs", "bin", "saves", "__pycache__")

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


## Divide uma linha de comando em tokens respeitando as aspas duplas do Windows.
function Get-CmdTokens([string]$CommandLine) {
    $tokens = @()
    $cur = ""
    $inQ = $false
    foreach ($ch in $CommandLine.ToCharArray()) {
        if ($ch -eq '"') {
            $inQ = -not $inQ
            continue
        }
        if (-not $inQ -and $ch -match "\s") {
            if ($cur) { $tokens += $cur; $cur = "" }
            continue
        }
        $cur += [string]$ch
    }
    if ($cur) { $tokens += $cur }
    return $tokens
}


## O --path de uma linha de comando: o projeto que aquele processo abriu.
function Get-PathArg([string[]]$Tokens) {
    for ($i = 0; $i -lt $Tokens.Count; $i++) {
        if ($Tokens[$i] -eq "--path" -and ($i + 1) -lt $Tokens.Count) { return $Tokens[$i + 1] }
        if ($Tokens[$i].StartsWith("--path=")) { return $Tokens[$i].Substring(7) }
    }
    return $null
}


## Pasta de user:// que o engine monta para um projeto: o nome vem de
## application/config/name no project.godot, nao do diretorio no disco.
function Get-ProjectSaveSpace([string]$ProjectDir) {
    $cfg = Join-Path $ProjectDir "project.godot"
    if (-not (Test-Path -LiteralPath $cfg)) { return $null }
    foreach ($line in (Get-Content -LiteralPath $cfg)) {
        if ($line -match '^config/name=(.*)$') {
            $v = $Matches[1].Trim().Trim('"')
            if ($v) { return $v }
        }
    }
    return $null
}


function Norm-Path([string]$Path) {
    try {
        return [System.IO.Path]::GetFullPath($Path).TrimEnd("\").ToLowerInvariant()
    }
    catch {
        return $Path.ToLowerInvariant()
    }
}


## Classifica a linha de comando de um processo do engine: "salva" quando a
## janela escreve no save deste projeto, "" quando nao. O que define o arquivo
## nao e a pasta do clone nem o binario: user:// e
## %APPDATA%\Godot\app_userdata\<config/name>, entao dois clones diferentes e o
## F5 do editor disputam o mesmo world_alpha.json. --headless (a suite) nao
## escreve save e o editor parado tambem nao, entao os dois saem da conta.
## Um --path relativo so pode ser atribuido pelo binario que o executou: se ele
## mora dentro deste projeto, a instancia e daqui. Sem --path e o gerente de
## projetos do engine aberto, que nao escreve save de jogo nenhum.
function Get-InstanceVerdict([string]$CommandLine, [string]$MyRoot, [string]$MyName) {
    if (-not $CommandLine) { return "" }
    if ($CommandLine -match "--headless") { return "" }
    if ($CommandLine -match "(^|\s)(-e|--editor)(\s|$)") { return "" }
    $tokens = Get-CmdTokens $CommandLine
    $proj = Get-PathArg $tokens
    if (-not $proj) { return "" }
    if ([System.IO.Path]::IsPathRooted($proj)) {
        $space = Get-ProjectSaveSpace $proj
        if ($space -and $space -eq $MyName) { return "salva" }
        return ""
    }
    if ($tokens.Count -eq 0) { return "" }
    $exeDir = Norm-Path (Split-Path -Parent $tokens[0])
    if ($exeDir.StartsWith((Norm-Path $MyRoot) + "\")) { return "salva" }
    return ""
}


function Get-GameInstances([string]$Exe) {
    $leaf = Split-Path -Leaf $Exe
    $console = $leaf -replace "\.exe$", "_console.exe"
    $mine = Get-ProjectSaveSpace $Root
    $filter = "Name LIKE 'Godot%' OR Name LIKE 'godot%' OR Name = '$leaf' OR Name = '$console'"
    $rows = Get-CimInstance -Query "Select ProcessId, CommandLine From Win32_Process Where $filter" -ErrorAction SilentlyContinue
    $found = @()
    foreach ($r in $rows) {
        if ((Get-InstanceVerdict ([string]$r.CommandLine) $Root $mine) -ne "salva") { continue }
        $found += ("PID " + $r.ProcessId + "  " + [string]$r.CommandLine)
    }
    return $found
}


## Os arquivos da arvore que tem um produto dentro de .godot/. A descida e feita
## a mao com uma pilha porque um Get-ChildItem -Recurse puro atravessaria
## .qoder/worktrees (outros clones, cada um com a arvore inteira) e .tools (o
## motor baixado) para depois descartar o que ele mesmo caminhou.
function Get-ImportedSources([string]$ProjectDir) {
    $found = @()
    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($ProjectDir)
    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        foreach ($sub in (Get-ChildItem -LiteralPath $dir -Directory -Force -ErrorAction SilentlyContinue)) {
            if ($sub.Name.StartsWith(".") -or $ImportSkipDirs -contains $sub.Name) { continue }
            $stack.Push($sub.FullName)
        }
        foreach ($f in (Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue)) {
            if ($ImportExts -contains $f.Extension.ToLowerInvariant()) { $found += $f }
        }
    }
    return $found
}


## O veredito de frescor com o numero que o decide: quantos arquivos importaveis
## estao mais novos que o ultimo import e qual e o mais recente. "Pronto" e os
## quatro juntos -- registro de classes presente, produtos presentes, o mesmo
## motor que importou, e nada da arvore tocado depois do carimbo.
function Get-ImportVerdict([string]$EngineVer) {
    $out = @{ pronto = $true; motivo = ""; novos = 0; mais_novo = ""; desde = "" }
    if (-not (Test-Path -LiteralPath $ClassCache)) {
        $out.pronto = $false
        $out.motivo = "falta o registro de classes (.godot\global_script_class_cache.cfg)"
        return $out
    }
    if (-not (Test-Path -LiteralPath $ImportedDir)) {
        $out.pronto = $false
        $out.motivo = "falta .godot\imported (os produtos do ultimo import sumiram da arvore)"
        return $out
    }
    $stamp = Join-Path $Root $ImportStampRel
    $ref = $null
    if (Test-Path -LiteralPath $stamp) {
        $linhas = @(Get-Content -LiteralPath $stamp -ErrorAction SilentlyContinue)
        $ver = ""
        if ($linhas.Count -gt 0) { $ver = ([string]$linhas[0]).Trim() }
        $ref = (Get-Item -LiteralPath $stamp).LastWriteTime
        $out.desde = $ref.ToString("yyyy-MM-dd HH:mm")
        if ($ver -and ($ver -ne $EngineVer)) {
            $out.pronto = $false
            $out.motivo = "o cache veio do motor $ver e esta rodada usa $EngineVer"
            return $out
        }
    }
    else {
        # cache feito antes deste carimbo: a data do cfg e o melhor palpite que ha, e
        # o proximo import grava o carimbo -- a duvida nao passa de uma rodada
        $ref = (Get-Item -LiteralPath $ClassCache).LastWriteTime
        $out.desde = ($ref.ToString("yyyy-MM-dd HH:mm") + ", sem carimbo (li a data do cfg)")
    }
    $mais = $ref
    foreach ($f in (Get-ImportedSources $Root)) {
        if ($f.LastWriteTime -gt $ref) { $out.novos += 1 }
        if ($f.LastWriteTime -gt $mais) { $mais = $f.LastWriteTime; $out.mais_novo = $f.FullName }
    }
    if ($out.novos -gt 0) {
        $out.pronto = $false
        $out.motivo = "$($out.novos) arquivo(s) importavel(is) mais novo(s) que o ultimo import"
    }
    return $out
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
    # o texto do engine vai para a janela por Out-Host: solto no pipeline ele
    # viria junto com o codigo de saida e o "if ($rc -ne 0)" de quem chama leria
    # um vetor de linhas como se fosse o numero
    $console = Get-ConsoleExe $Exe
    if ($console -ne $Exe) {
        & $console $Argv | Out-Host
        return $LASTEXITCODE
    }
    $log = Join-Path $env:TEMP ("aetherfall_godot_" + [guid]::NewGuid().ToString("N") + ".log")
    $p = Start-Process -FilePath $Exe -ArgumentList (Format-Argv $Argv) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    if (Test-Path $log) { Get-Content $log -Tail 40 | Out-Host }
    if (Test-Path "$log.err") { Get-Content "$log.err" -Tail 40 | Out-Host }
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

$frescor = Get-ImportVerdict $godot.ver

# vale para qualquer motor: o que identifica o projeto nao e o binario e sim o
# --path lido da linha de comando de cada processo (mesmo config/name = mesmo
# save), entao um Godot do PATH ou o F5 do editor tambem entram na conta
$openGames = @(Get-GameInstances $godot.exe)

Write-Step "plano"
Write-Host "   projeto : $Root"
Write-Host "   modo    : $mode"
if ($frescor.pronto) {
    Write-Host "   import  : fresco (ultimo em $($frescor.desde); $($frescor.novos) arquivo(s) mais novo(s))"
}
else {
    Write-Host "   import  : necessario - $($frescor.motivo)"
    if ($frescor.desde) { Write-Host "             ultimo import em $($frescor.desde)" }
    if ($frescor.mais_novo) { Write-Host "             o mais recente: $($frescor.mais_novo)" }
}
if ($openGames.Count -gt 0) {
    Write-Host "   aberto  : $($openGames.Count) janela(s) do mesmo save"
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
    Write-Host "Ja existe janela do mesmo save aberta (lista acima): outra copia do projeto"
    Write-Host "ou o jogo rodando pelo editor. Abrir a segunda faz as duas escreverem no"
    Write-Host "mesmo arquivo (user://saves/world_alpha.json) e a ultima gravacao vence."
    Write-Host "Fecha a janela que esta aberta, ou passa -Force."
    exit 2
}

if ($openGames.Count -gt 0 -and $mode -eq "suite") {
    Write-Host "aviso: ha jogo aberto; a suite vai rodar competindo por CPU, entao os"
    Write-Host "       numeros de tempo desta corrida nao sao publicaveis."
}

if (-not $frescor.pronto) {
    # importar com outra instancia viva do projeto escreve em .godot/ enquanto o
    # outro processo le os mesmos produtos: no melhor caso o import errora com
    # sharing violation, no pior o jogo abre com meio arquivo de cada rodada.
    if ($openGames.Count -gt 0) {
        Write-Host ""
        Write-Host "ATENCAO: o cache esta velho ($($frescor.motivo)) mas ha janela do mesmo save aberta."
        Write-Host "Nada foi reimportado -- o jogo vai abrir lendo o produto velho de .godot/imported/."
        Write-Host "Fecha a janela e roda de novo para o import acontecer."
    }
    else {
        Write-Step "reimportando o projeto ($($frescor.motivo); monta o .godot/ e o registro de classes)"
        $rc = Invoke-GodotHeadless $godot.exe $importArgv
        if ($rc -ne 0) { throw "o import falhou com codigo $rc" }
        if (-not (Test-Path -LiteralPath $ClassCache)) {
            throw "o import terminou mas o cache de classes nao apareceu; veja o log acima"
        }
        Set-Content -LiteralPath (Join-Path $Root $ImportStampRel) -Value $godot.ver
        Write-Host "   ok"
    }
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
