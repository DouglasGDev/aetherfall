# Dossie 15 — oráculo embutido no boot: o que cada log aqui decide

Motor da medição: **Godot 4.7.2.stable.official.ed1daf0bf**, Vulkan Forward+,
`AMD Radeon RX 9060 XT` + `AMD Ryzen 7 5700X3D`, Windows 10.0.26200.
Árvore medida: `feat/oraculo-embutido-no-boot-15` em `09780c4`. Os caminhos reais
do runtime e do modelo ficam fora do git (`.gitignore`), então onde a sonda precisou
deles ela recebeu `--llm-server=` / `--llm-model=` apontando para o checkout
principal — é o override documentado em `src/ai/llm_server_host.gd`, não um
caminho inventado para a corrida passar.

Assets da corrida: `.tools/llama/runtime/llama-server.exe` (9 728 B, llama.cpp
`b12499-401563f10`, lido do `/props`) e `models/qwen3.5-4b-q4_k_m.gguf`
(2 740 937 888 B). A chave que aparece nos `create_process` e nos curls está
mascarada aqui como `<chave-redactada>`, em todos os arquivos deste diretório. Na
corrida ela era a constante do repositório (`src/ai/mind_oracle.gd:20` à época),
servida só em `127.0.0.1`; em 2026-11-21 o dono decidiu que nenhuma credencial fica
num repo público, e a chave hoje nasce de ambiente ou de arquivo
(`MindOracle.resolve_api_key()`). O resto das linhas continua literal — só o valor
da chave saiu daqui, e os SHA-256 de `artifacts.sha256` são dos arquivos mascarados.

Os arquivos abaixo são tudo o que a perna mediu: quatro suítes com seus `-err`,
o par da janela de produto, as cinco sondas com os dois vermelhos antes/depois,
as amostras de `/health`, os dois logs de servidor verboso e os runners
(`*.sh`, `*.ps1`) que produzem cada um.

## 1. A suíte, nos três momentos da perna

| Log | Comando | Última linha literal |
| --- | --- | --- |
| `main-suite-base.log` | `godot --headless --path . tests/smoke_test.tscn` na `main` `27800eb` | `== 239 checagens  0 falhas  38.1 s de teste ==` |
| `branch-suite.log` | idem, em `f8b42a5` | `== 246 checagens  0 falhas  40.0 s de teste ==` |
| `branch-suite-pos-corte-reentrada.log` | idem, em `fae0b40` | `== 246 checagens  0 falhas  40.4 s de teste ==` |
| `branch-suite-dono-unico.log` | idem, em `09780c4` | `== 246 checagens  0 falhas  40.2 s de teste ==` |
| `branch-suite-evidencia-1.log` | idem, nesta árvore de documentos (sem código mudado desde `09780c4`) | `== 246 checagens  0 falhas  46.9 s de teste ==` |
| `branch-suite-evidencia-2.log` | idem, logo em seguida | `== 246 checagens  0 falhas  46.2 s de teste ==` |

As duas últimas corridas valem pela **contagem** (246/0, exit 0), não pelos
segundos. Os diagnósticos do boot, linha a linha:

| Corrida | `gen_ms` | `mesh_ms` | `worst_sim_ms` | `dropped_ticks` |
| --- | --- | --- | --- | --- |
| `branch-suite-dono-unico.log` (máquina mais quieta) | 1029.802 | 4972.543 | 14.194 | 0 |
| `branch-suite-evidencia-1.log` | 1324.058 | 7011.647 | 16.881 | 0 |
| `branch-suite-evidencia-2.log` | 1121.599 | 6659.312 | 41.055 | 0 |

Na mesma árvore de código, com outros processos ativos, o mesher comeu ~2 s a mais
e um passo de simulação isolado chegou a 41 ms dos 50 ms do orçamento. É o que o
contrato desta casa já diz — timing em máquina concorrente é número do
concorrente. Nenhum `dropped_ticks` apareceu e nenhuma checagem mudou de veredito
nas três; o pico de 41 ms fica registrado, não atribuído.

Em headless o mundo **não** monta hospedeiro (`_start_llm_host` retorna cedo em
`DisplayServer.get_name() == "headless"`), então nenhuma dessas corridas levantou
modelo. A checagem que cobra isso na suíte é `suite nao levanta modelo`, em
`tests/smoke_test.gd:202`, e a linha dela no log da branch é literal:

```
  [PASS] suite nao levanta modelo               display=headless  llm={  }
```

O stderr de cada uma dessas corridas está arquivado ao lado, com o sufixo `-err`.
Os quatro trazem a mesma linha `WARNING: 12 ObjectDB instances were leaked at
exit` — inclusive a base da `main`, que não tem nada desta perna —, então o aviso
de leak é anterior a aqui e está registrado como furo no status. A linha seguinte,
`ERROR: N resources still in use at exit`, traz `6` na base da `main` e `4` nas
três corridas da branch. Esta perna não mediu por quê: é um número que caiu, não
apareceu, e nenhuma das peças escritas aqui segura recurso. Fica na mesma cobrança
do leak, junto do fato de que o "stderr de zero bytes" publicado para `2bf0854`
não se reproduz nesta máquina.

## 2. O produto, na janela real, sem sonda nenhuma

`janela-produto-log-do-jogo.log` é o stdout do próprio jogo aberto em janela
(`--path` no worktree, `--quit-after 2400`, sem `--headless`). As cinco linhas
`llm_host` dele são a resposta à pergunta do dono:

```
llm_host  sondando  sonda /v1/models em http://127.0.0.1:8741
llm_host  create_process  C:/Aetherfall/.tools/llama/runtime/llama-server.exe -m C:/Aetherfall/models/qwen3.5-4b-q4_k_m.gguf --host 127.0.0.1 --port 8741 -c 4096 -ngl 99 --alias mind-small --reasoning off --api-key <chave-redactada>  (sem servidor na porta 8741)
llm_host  carregando  pid 26852  boot do modelo iniciado  (1/1 spawn)
llm_host  pronto  boot 2762 ms  503=11  pid 26852
llm_host  encerrando pid 26852  OK
```

`janela-produto-observacao-de-fora.log` é a mesma corrida vista de fora do processo
(`janela-embedded.ps1`), com `GET /v1/models` autenticado a cada segundo. As linhas
abaixo são literais, com os espaços em branco do fim da linha cortados.

```
t+ 2281 ms  janela=True  porta=sem conexao  filhos=conhost.exe,Godot_v4.7.2-stable_win64.exe
t+ 5400 ms  janela=True  porta=sem conexao  filhos=conhost.exe,Godot_v4.7.2-stable_win64.exe
t+ 8519 ms  janela=True  porta=sem conexao  filhos=conhost.exe,Godot_v4.7.2-stable_win64.exe
t+10165 ms  janela=True  porta=http 503  filhos=conhost.exe,Godot_v4.7.2-stable_win64.exe  pid Win32_Process: llama-server.exe (Handle = "26852") (26852) pai 11512
t+11292 ms  janela=True  porta=http 503  filhos=conhost.exe,Godot_v4.7.2-stable_win64.exe  pid Win32_Process: llama-server.exe (Handle = "26852") (26852) pai 11512
t+12536 ms  janela=True  porta=200 mind-small  filhos=conhost.exe,Godot_v4.7.2-stable_win64.exe  pid Win32_Process: llama-server.exe (Handle = "26852") (26852) pai 11512
```

Depois do fecho da janela: `Test-NetConnection 127.0.0.1:8741` → `False` e nenhum
`llama-server.exe` na tabela de processos. Checagem 6 do dossie (fechar a janela
mata o filho) medida de fora, como o arquivo-ponte pede.

Dois detalhes do próprio runner, registrados porque mudam a leitura: o laço da
sonda externa parou ao ver o primeiro 200 e o `WaitForExit(180)` são 180
**milissegundos**, então a linha "apos o fecho" daquele log foi escrita com a
janela ainda aberta — ela não vale como prova do fecho. A prova do fecho é o
`encerrando pid 26852  OK` do log do jogo somado à checagem de porta e de processo
feita depois, quando já não havia janela alguma.

## 3. A sonda, modo por modo

Cinco modos, cada um respondendo uma premissa diferente. Todos os logs abaixo
foram lidos inteiros; a linha que decide é a `sonda 15  modo=<modo>  N checagens
M falhas ...`, que vem antes dos avisos de encerramento do engine quando o log
capturou o stderr junto. A terceira coluna transcreve essa linha a partir de
`modo=`.

| Modo | O que nega | Linha que decide |
| --- | --- | --- |
| `sonda-ci.log` | sem runtime e sem rede: os dois motivos são frases diferentes, zero pedidos HTTP, zero processos, portão fechado | `modo=ci  9 checagens  0 falhas  6.6 s  llm=llm: ausente (runtime)  rode tools\fetch_models.ps1 -Pack runtime` |
| `sonda-boot-janela.log` | boot medido na janela, ticks andando, narrativa, chave | `modo=boot  9 checagens  0 falhas  12.4 s  llm=llm: pronto  porta 8741  pid 13924  boot 2792 ms  503=11` |
| `sonda-reuse.log` | servidor nosso na porta ⇒ reuso, sem segundo spawn, sem assumir pid alheio | `modo=reuse  5 checagens  0 falhas  9.2 s  llm=llm: reuso do servidor existente  porta 8741` |
| `sonda-foreign.log` | 401 de terceiro ⇒ `estrangeiro`, ninguém morre, nada é duplicado | `modo=foreign  4 checagens  0 falhas  6.4 s  llm=llm: porta 8741 ocupada por outro servidor  oraculo desligado` |
| `sonda-death.log` | morte externa depois do 200 ⇒ exatamente uma retentativa | `modo=death  7 checagens  0 falhas  14.2 s  llm=llm: pronto  porta 8741  pid 10556  boot 2614 ms  503=20` |

Os dois antes/depois que ficaram registrados de propósito:

- `sonda-ci-antes-do-corte-reentrada.log` — `modo=ci  9 checagens  2 falhas  7.2 s`, com
  `estado=ocioso` nas duas checagens do segundo host e **30 linhas** `ausente
  (modelo)` no log. Era o `_run_ci` reentrando a cada frame enquanto `_phase`
  valia `ci`, trocando o host injetado por um novinho.
- `sonda-boot-janela-antes-do-dono-unico.log` — `modo=boot  9 checagens  1 falhas  18.5 s`
  e, no corpo, **dois** `create_process` com pids `2556` e `27328`, os dois
  `pronto`, e dois `encerrando` na saída. Na janela, o `_ready` do mundo já cria
  o host dele; a sonda injetava o segundo por cima. Consertado em `attach_llm_host`
  (um dono por porta) e na sonda (adota o hospedeiro da janela).

### Números da corrida boa em janela (`sonda-boot-janela.log`)

```
janela  main_ready=6149 ms  frames_no_braco=463  tick_no_braco=56  pior_passo=10.49 ms  estado=pronto  boot=2792 ms  503=11  pid=13924
OK     o modelo ficou pronto com a janela ja aberta  [main_ready=6149 ms  primeiro_200=10521 ms  duracao_do_boot=2792 ms]
lobo0  +11.3 s  ia: O lobo cruza o bosque em estado de alerta constante, ignorando o jogador invisível enquanto busca sinais de uma presa ferida, mantendo uma f...
lobo1  +12.1 s  ia: O lobo varre o horizonte com cautela, seus sentidos aguçados escaneando o ambiente enquanto a fome aperta sua barriga e a ausência de jogado...
OK     narrativa chega sem passo manual  [narrativas=2  pedidos=2]
OK     pedido sem a chave devolve 401  [codigo=401]
OK     pedido com a chave devolve 200  [codigo=200]
```

A checagem 4 é a que estava errada de conceito: ela comparava `main_ready`
(duração do `_ready` do mundo) com `boot_ms` (duração do boot do modelo) como se
fossem a mesma grandeza, e deu vermelho sem nada estar bloqueando. O que se nega é
uma **sequência** — se a carga do modelo estivesse dentro do `_ready`, o primeiro
200 teria chegado antes de ele voltar. Os dois números agora são timestamps do
mesmo relógio.

### Morte externa (`sonda-death.log`)

A sonda imprime o pid do filho e espera — `sonda 15  esperando morte externa do
pid 27104  (taskkill /PID 27104 /F)` é a linha 13 de `sonda-death.log`, e
`death-run.sh` executa exatamente esse `taskkill` quando lê o pid. A resposta do
Windows saiu no console do runner, não no log; o que fica provado no log é a
cadeia de estados depois da morte:

```
llm_host  caiu  is_process_running falso no pid 27104  (codigo 1)  retentativa 1/1
llm_host  create_process  C:/Aetherfall/.tools/llama/runtime/llama-server.exe -m C:/Aetherfall/models/qwen3.5-4b-q4_k_m.gguf --host 127.0.0.1 --port 8741 -c 4096 -ngl 99 --alias mind-small --reasoning off --api-key <chave-redactada>  (retentativa 1/1 apos is_process_running falso no pid 27104)
llm_host  carregando  pid 10556  boot do modelo iniciado  (2/1 spawn)
llm_host  pronto  boot 2614 ms  503=20  pid 10556
OK     uma unica retentativa  [retentativas=1]
OK     dois spawns: o boot e a retentativa  [spawns=2]
```

A linha final ainda traz `oraculo: sem resposta (RESULT_CONNECTION_ERROR (codigo
http 0))` no F3: é o motivo nomeado pelo engine vindo da janela entre a morte e o
respawn — exatamente o que a derivação da chave e o conserto do `get_result_string`
foram pagar.

## 4. Tempo até o `/health` — três relógios, não um número só

`manual-boot.sh` sobe o servidor **com o mesmo argv** que `_spawn` usa e mede o
primeiro 200 no `/health` a cada 250 ms. Cada amostra tem dois arquivos:
`servidor-saude-1.log` / `servidor-saude-2.log` são o stdout do laço de polling e
`servidor-manual-1.log` / `servidor-manual-2.log` são o log do próprio servidor,
com o seu relógio interno; o par do caso de terceiro é
`servidor-saude-estrangeiro.log` + `servidor-estrangeiro.log`.

| Amostra | Laço de polling | Relógio do servidor (`model loaded`) |
| --- | --- | --- |
| `servidor-saude-1.log` | `health 200 em 2740 ms  (tentativa 7)` | `0.02.538.849 I srv  server_run_i: model loaded` |
| `servidor-saude-2.log` | `health 200 em 2709 ms  (tentativa 7)` | `0.02.471.815 I srv  server_run_i: model loaded` |
| `servidor-saude-estrangeiro.log` | `health 200 em 2571 ms` | `0.02.472.776 I srv  server_run_i: model loaded` |
| `servidor-vram-resumo-medido.log` | `health=200  apos=3864.7003 ms` | — (mesma corrida do log de VRAM, com `-lv 7`) |

Os dois relógios batem: o servidor se anuncia pronto em 2,47–2,54 s e o `curl`
vê o primeiro 200 99–238 ms depois — uma a duas voltas do laço de `sleep 0.25`,
mais o spawn do processo. A amostra de 3 864,7 ms vem do `Process.StartTime` de
uma corrida com `-lv 7`, que imprime 4 348 linhas durante a carga; ela vale como
teto de um servidor verboso, não como o tempo normal.

A linha do estrangeiro é o caso de porta compartilhada: o servidor é meu, mas
com outra chave e outro alias, e a mesma corrida imprime `/v1/models com a chave
do jogo -> 401`. Ou seja, o 200 no `/health` **não** prova que o servidor é
nosso — é por isso que o hospedeiro sonda `/v1/models` com a chave antes de
decidir `reusado` ou `estrangeiro`.

Nenhum desses é o número do produto. O número do produto é o `boot_ms` que o
hospedeiro lê no **seu** processo filho, dentro da janela: **2 762 ms** e **2 792
ms** em duas corridas, 11×`503` no meio, e o primeiro 200 visto de fora entre
10,5 s e 12,5 s depois de abrir a janela — a diferença entre os dois é o custo de
abrir o mundo e a janela antes de a sonda existir, não do modelo.

## 5. VRAM — lida do próprio servidor, não do WMI

`servidor-vram-linhas-do-llama.log` é o log de um `llama-server` com `-lv 7`
(466 372 bytes, 4 348 linhas, sem corte). Ele é o **stderr** da corrida: com
verbosidade máxima o llama.cpp escreve tudo no stderr, e o stdout que o
`manual-verbose.ps1` daqui redireciona ficou vazio. As linhas `verbosity = 7`,
`no_alloc = 1` e `no_alloc = 0` estão dentro do próprio arquivo (linhas 3, 113 e
2253). Duas extrações reproduzem os números abaixo. A primeira pega o device
string, a tabela de decomposição e o ajuste; a segunda corta pelo `no_alloc = 0`,
porque a primeira passada da carga roda com `no_alloc = 1` e imprime os buffers
como `0.00 MiB` — sem esse corte o grep devolve as duas passadas misturadas.

```sh
grep -anE "common_param:   - |breakdown_print|projected to use|will leave|fitting params to free memory took" \
  docs/evidence/oracle-embutido-15/servidor-vram-linhas-do-llama.log

sed -n '/no_alloc              = 0/,$p' \
  docs/evidence/oracle-embutido-15/servidor-vram-linhas-do-llama.log \
  | grep -aE "model buffer size|KV buffer size|RS buffer size|compute buffer size"
```

As linhas que importam, literais (na ordem em que as duas extrações as devolvem):

```
0.00.099.656 I cmn  common_param:   - Vulkan0 : AMD Radeon RX 9060 XT (16304 MiB, 15445 MiB free)
0.00.099.667 I cmn  common_param:   - CPU     : AMD Ryzen 7 5700X3D 8-Core Processor            (32687 MiB, 17134 MiB free)
0.01.022.282 I common_memory_breakdown_print: |   - Vulkan0 (RX 9060 XT) | 16304 = 15445 + (3015 =  2603 +     329 +      83) +       -2156 |
0.01.022.283 I common_memory_breakdown_print: |   - Host                 |                   521 =   497 +       0 +      24                |
0.01.073.824 I common_params_fit_impl: projected to use 3015 MiB of device memory vs. 15445 MiB of free device memory
0.01.073.825 I common_params_fit_impl: will leave 12429 >= 1024 MiB of free device memory, no changes needed
0.01.073.834 I common_fit_params: fitting params to free memory took 0.96 seconds
0.02.070.285 I load_tensors:   CPU_Mapped model buffer size =   497.31 MiB
0.02.070.286 I load_tensors:      Vulkan0 model buffer size =  2603.50 MiB
0.03.465.484 I llama_kv_cache:    Vulkan0 KV buffer size =   128.00 MiB
0.03.474.530 I llama_memory_recurrent:    Vulkan0 RS buffer size =   201.00 MiB
0.03.704.342 I sched_reserve:    Vulkan0 compute buffer size =    83.02 MiB
0.03.704.344 I sched_reserve: Vulkan_Host compute buffer size =    24.02 MiB
```

Leitura: a placa tem **16 304 MiB**, estavam **15 445 MiB** livres no boot do
modelo, e o ajuste projetou **3 015 MiB** de memória de dispositivo (2 603 de
pesos + 329 de contexto + 83 de compute), deixando 12 429 MiB — `no changes
needed`, com o próprio `fitting` custando 0.96 s. Os buffers reais da segunda
passada (`no_alloc = 0`) batem com o projetado: 2 603,50 MiB de pesos na placa +
128 MiB de KV + 201 MiB de estado recorrente + 83,02 MiB de compute, mais os
497,31 MiB de pesos e os 24,02 MiB de compute que ficam no host (os 521 da segunda
linha da tabela).

Por que `-lv 7`: `servidor-verbosidade-padrao.log` é a mesma carga com a
verbosidade default do servidor (linhas 1–2, `verbosity = 3`) — 25 linhas, e a
única que menciona `Vulkan0` é o aviso de Flash Attention:

```
4:0.02.401.340 W resolve_fused_ops: layer 3 is assigned to device Vulkan0 but Flash Attention over K/V rows is assigned to device CPU (usually due to missing support)
```

Sem `-lv 7` não há device string nem tabela de decomposição para ler, e a VRAM
teria de vir de uma fonte indireta. Com ele vêm as 4 348 linhas do arquivo
anterior.

Por que não o número do WMI: `Win32_VideoController.AdapterRAM` devolve
`4293918720` nesta máquina — o teto de 4 GiB que a WMI aplica, não a placa. Um
counter de VRAM por processo não existe aqui (`nvidia-smi` enxerga só a 4060
secundária; `rocm-smi` não está instalado; não há conjunto PDH de contadores de
GPU). Então a fonte é o device string do próprio servidor, e o valor do WMI fica
registrado como o que ele **não** é.

## 6. O que estas corridas não provam

- Nenhum gate de fase fechou com isso. O dossie 15 §8 cobra o que está aqui; o
  gate de P1 continua aberto por outras peças.
- `boot_ms` é o tempo do processo filho desta máquina, com o modelo já em disco e
  o runtime já baixado. Primeiro boot com `fetch_models.ps1` não foi medido.
- A janela de teste foi aberta por mim, para medir, com `--quit-after`. Não é uma
  partida jogada: nenhuma das narrativas acima veio de input de jogador.
- O estado `estrangeiro` foi medido contra um `llama-server` de terceiro que eu
  mesmo subi com outra chave na mesma porta — não contra um servidor real de outro
  programa desta máquina.
- `death` mede uma retentativa. A segunda morte cai em `desligado` e é coberta
  pela checagem da suíte, não por esta corrida.
- As quatro amostras de `/health` são uma corrida cada, com a máquina livre (nenhum
  `llama-server` e nenhuma janela de jogo antes delas), e medem o servidor de pé
  por fora do jogo — não o caminho do hospedeiro, que é o `boot_ms` da seção 2. O
  `pid=` que `manual-boot.sh` imprime é o pid do job do MSYS, não o pid Windows do
  `llama-server.exe`; os pids citados nas seções 2 e 3 são o retorno de
  `OS.create_process` (`src/ai/llm_server_host.gd:311`), que é pid do Windows, e
  batem com a tabela de processos e com `is_process_running`.
- Quem não tem placa de vídeo continua `[OPEN]`: nenhuma corrida acima toca esse
  caminho.
