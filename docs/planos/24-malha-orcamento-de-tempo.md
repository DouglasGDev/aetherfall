# 24 — Malha: o orçamento era de **contagem**, e um frame pagava dois chunks de 50–80 ms

Dossiê de **leitura de código**, escrito a pedido do dono em 2026-11-25, na própria conversa, como
fecho do que ele mesmo chamou de última coisa que faltava: *"orquestrar o agente responsavel o pq das
travadas qeu esta dando, so falta isso por favor, otimizacao... microtravadas."* O registro vem
**antes** de qualquer linha de `src/`, como exige o mandato 4 de
[`AGENTS.md`](../../AGENTS.md). Até o §9 os números de `arquivo:linha` desta página são da `main` em
**`95d519a`** re-derivados contra `a537117` e `99bbbde` (o mapa das dezesseis ponteiros está no §9); os do §10 são da `main` mergida **`7b8924f`**.

A causa já tem nome e número desde a Rodada 2026-11-24 (6) de
[`docs/melhorias-status.md`](../melhorias-status.md#L7405-L7589): é o **furo #41**. O que não existia
era o corte — ele **existe**, em `a537117` + `99bbbde`, com o **#61** pago em `94a4a12` e o pouso em
`7b8924f` (§10). Esta página entrega a forma do corte, os braços que a medição decide, e o gate que nasceu vermelho.

## 1. Premissa nomeada

**O trabalho de malha que entra num frame é limitado por tempo, não por número de chunk: a fila continua
no frame seguinte e o quadro que o jogador vê não estoura a janela de render por causa dela.**

Falsificável nos dois instrumentos que a casa já tem, cada um na grandeza que lhe compete:

- **headless** decide a *regra do loop*: sujar dois ou mais chunks de uma vez, chamar
  `world.process(...)` um frame e exigir que a soma cronometrada daquele frame tenha ficado sob o teto,
  com o resto da fila ainda pendente (`pending_meshes() > 0`). Cronometrar `build_chunk_mesh()` não
  precisa de `RenderingDevice` — é trabalho de CPU que monta `ArrayMesh`, e o headless roda o mesmo
  caminho que o jogo.
- **janela** decide a *dor visível*: o `p50` e a cauda `≥2×p50` / `≥33,3 ms` da sonda. Headless não tem
  `RenderingServer`, então nenhuma corrida headless pode afirmar que o quadro melhorou — e a casa não
  publica número de fluidez vindo de uma corrida que não desenha nada.

Os dois sentidos que o ciclo de trabalho (item 3) exige, e que a rodada de ontem já desenhou:

- **braço vermelho de origem**: com o código de hoje, um frame que tem dois chunks na fila paga os dois
  de uma vez e o período do quadro vai a 152–192 ms medidos (`[MEASURED]` em `8a53b56`, §2.2). A
  checagem do teto nasce vermelha contra exatamente isso.
- **braço de indiferença**: o corte tem de ser **indiferente** ao mundo em repouso — um frame com a fila
  vazia não ganha nenhum teste novo de relógio, e a saída do mesher não muda um triângulo. É a mesma
  forma da checagem `agua_nao_muda_a_malha` da perna 23
  ([`docs/planos/23-elevacao-visual-agua.md`](23-elevacao-visual-agua.md)), que existe hoje para que o
  re-rome de outra perna não ache triângulos deslocados por causa alheia.

## 2. Estado real do código (lido, não medido)

### 2.1 O loop que não olha o relógio

Era este o corpo, lido contra `c86f1a0:src/world/voxel_world.gd:228-236` (prefixo de revisão porque o
braço B já mudou o alvo — hoje o `process()` está em
[`src/world/voxel_world.gd:309-359`](../../src/world/voxel_world.gd#L309-L359) e o relógio é perguntado
**dentro** do laço, **duas** vezes: [`:322`](../../src/world/voxel_world.gd#L322) antes de o chunk
**entrar** e [`:336`](../../src/world/voxel_world.gd#L336) antes de cada nível `y` — corte commitado em
`a537117` (16:11:57) e **corrigido** em `99bbbde` (16:28:51). O HEAD da branch é hoje `5467c33` (20:23:48, o merge da
`main` `26c7f33` — re-rome do item 5 de "Branches") e `git diff --name-only 99bbbde HEAD -- src` está **vazio**, com o mesher
no mesmo md5 (`d985624f…`), então cada ponteiro deste parágrafo vale nos três commits e não só nos dois do corte.

**De onde vêm os números de `voxel_world.gd` desta página, a partir daqui.** O corte existe em commit, são
dois, e a árvore de referência dos `arquivo:linha` do mesher é **`99bbbde`** (*"o teto corta o QUADRO, nao so o
chunk"*), que escreve
`src/world/voxel_world.gd` **+61/−7** e `tests/aether_reactions_test.gd` **+65/−33** por cima de `a537117`.
Os `arquivo:linha` que descrevem **o que o corte faz** foram re-derivados contra **ele** — `git show
99bbbde:src/world/voxel_world.gd`, **1 055 linhas** — e a re-derivação é feita contra commit, nunca contra a
árvore de trabalho, porque foi assim que ela queimou duas vezes neste dia: o arquivo moveu `+50/−6` entre
16:11 e 16:17 e voltou a mover antes do próprio `99bbbde`. Às 16:35, quando este parágrafo foi escrito,
`git diff --numstat HEAD -- src tests` está **vazio** — a árvore de trabalho igual ao HEAD —, então os
ponteiros abaixo valem para as duas leituras; a hora está dita porque a igualdade não é permanente. Onde a
página descreve **a base** — o corpo do §2.1, o primeiro item do §2.4, as cotações de `95d519a` no §2.2 —
os números continuam sendo os da `main`, e cada um diz qual revisão é. O §9 traz a testemunha das três
leituras (`a537117`, o drift, `99bbbde`).

O corpo da base, tal como estava em `c86f1a0`:

```gdscript
func process(p_frame_budget: int) -> void:
	if _dirty.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var count: int = mini(p_frame_budget, _dirty.size())
	for i in count:
		var c: VoxelChunk = _dirty.pop_front()
		build_chunk_mesh(c)
	_last_mesh_ms = float(Time.get_ticks_usec() - t0) / 1000.0
```

O `t0` é lido **antes** do loop e o `_last_mesh_ms` é calculado **depois**: a grandeza tempo existe, mas
como *diagnóstico posterior*, não como *decisão*. Entre um `build_chunk_mesh` e o próximo não há consulta
de relógio nenhuma. Quem chama é [`src/main.gd:388`](../../src/main.gd#L388), dentro de `_process`, com
[`const MESH_BUDGET := 2 # chunks por frame`](../../src/main.gd#L28). O que entra no frame é `2 ×
chunk_us`, e o teto de `2` não sabe quanto custa um.

Três fatos do mesmo arquivo, lidos contra `99bbbde`:

- a fila é um `Array` de chunk (`var _dirty: Array = []`,
  [`:81`](../../src/world/voxel_world.gd#L81)) consumida por `pop_front()`, e `pending_meshes()`
  ([`:506`](../../src/world/voxel_world.gd#L506)) já devolve o tamanho — ou seja, "o que sobrou para o
  frame seguinte" é uma grandeza que **já existe publicada**, sem peça nova;
- `last_mesh_ms()` ([`:510`](../../src/world/voxel_world.gd#L510)) já é a grandeza que a regra precisa
  consultar, e desde `99bbbde` ela tem uma vizinha: `mesh_frame_worst()`
  ([`:520-529`](../../src/world/voxel_world.gd#L520-L529)) devolve `budget_us`, `level_us`, `scan_us`,
  `commit_us` e `frame_us` — os três custos que o teto **não** fatia, medidos onde acontecem, e é deles que
  o §2.2.2 trata;
- o chunk é 16 × 64 × 16 ([`voxel_config.gd:5-7`](../../src/world/voxel_config.gd#L5-L7), e
  [`voxel_world.gd:57-59`](../../src/world/voxel_world.gd#L57-L59) repassa), e o loop triplo que `build_chunk_mesh`
  ([`:385`](../../src/world/voxel_world.gd#L385)) chamava por dentro percorre as 16 384 células com seis
  faces cada — desde o corte, o corpo desse laço está em `_mesh_level`
  ([`:408-465`](../../src/world/voxel_world.gd#L408-L465)), nível por nível. É por isso que o custo de **um**
  chunk é uma grandeza de dezenas de milissegundos, não de fração de quadro: antes do corte a unidade
  minima de trabalho era maior que o quadro inteiro.

### 2.2 A medição que existe — e a árvore dela

`[MEASURED]` na `main` em **`8a53b56`**, oito braços, dez corridas, máquina livre, em
[`docs/melhorias-status.md:7405-7589`](../melhorias-status.md#L7405) com os logs arquivados em
[`docs/evidence/microtravadas-20261124/`](../evidence/microtravadas-20261124/):

| grandeza | número medido (árvore `8a53b56`) |
| --- | --- |
| piso do instrumento (braço `floor`, cena vazia, 20 s) | p50 **6,06 ms**, p99 6,29, max 6,73, **0** travadas |
| pior quadro do braço parado | **192,20 ms** de período com **177,37 ms** de malha, 2 chunks (99 % do quadro) |
| pior quadro nos outros braços | 152,85 – 170,58 ms com malha de 144,85 – 156,19 ms |
| custo por chunk (dois caminhos independentes) | **52,6 – 78 ms** (`mesh_total_ms / chunks`), e o boot dá 4 668 ms / 64 ≈ **73 ms/chunk** |
| travadas ≥2×p50 por 40 s | 138 – 155 (todos os braços com o jogo) |
| quadros ≥33,3 ms | 8 (parado, andando, F3, Éter) a **30** (`mine`) |
| cruzamento de origem | `com_remalha + com_tick = travadas`, `sem_origem = 0`, `remalharam_sem_travar = 0` |
| oráculo, Éter visual, F3, pipelines | eximidos: `llm` 139 travadas contra `viz` 138 / `f3` 139; `com_compilacao = 0` |

### 2.2.1 A re-medição existe, e ela decide o fork (árvore `95d519a`, 2026-11-25)

Doze corridas, duas pontas de instrumento (`mesh_cost_probe` para o custo de **uma** chamada,
`hitch_probe_v2` para a janela), o bake-off do dossiê 07 em três corridas e o amostrador do furo #31
ligado em par. Os logs ficam em `.tools/med51_*.log` (rascunho versionado não — são da perna enquanto
ela mede; as linhas literais que importam estão copiadas abaixo e na rodada do status). Vínculo de
revisão conferido **antes** e **depois** de cada corrida: `HEAD=95d519a`, `src_tree=2e3e3622fa89…`,
`tests_tree=0dc616493ca4…`, `porcelain_src_tests=0` e os `md5` dos arquivos vigiados idênticos nos dois
lados — corrida que não vincula nada é jogada fora, e nenhuma daqui foi.

| grandeza | `8a53b56` (emprestado) | **`95d519a` (medido nesta passada)** |
| --- | --- | --- |
| piso do instrumento, braço `floor` | p50 6,06, max 6,73, **0** travadas | p50 **6,06**, p99 6,29 / 6,42, max 6,71 / 6,97, **0** travadas (duas corridas) |
| **um chunk sozinho**, fila vazia, 64 chunks | nunca medido (o `52,6–78 ms` era **divisão** do lote) | p50 **87,2 / 87,8 ms**, p90 117,3 / 123,0, max **145,4 / 152,7**, soma 5 583,7 / 5 761,7 ms. O **mínimo** entre as 128 amostras é **45,04 ms** |
| o mesmo chunk aquecido 7× | — | chunk mais barato (1 548 tris) min/med/max **42,6 / 51,3 / 68,0** ms; o mais caro (5 930 tris) **108,9 / 139,6 / 155,0** ms |
| decomposição de uma chamada | — | `sobra_laco` = **93–99 %** do `build` (107,6 de 108,5 = 99,2 %; 46,3 de 49,6 = 93,3 %); `scan_col_tops` 0,5–3,2 ms; `upload_arrays` 0,1–0,3 ms |
| corpo modificado em cópia | — | tudo-ar (16 384 leituras, 0 faces) p50 **8,54 / 15,77 ms**; tudo-pedra (16 384 sólidos, 512 tris de casca) p50 **82,05 / 83,80 ms**; água fora: −3,6 % a +19,8 %, dentro do ruído |
| métrica composta `mesh_ms + 52·mean_us` | 8 333,32 ms (referência A da mesa, outra árvore) | **10 553,31 / 9 996,76 / 10 306,36 ms**, média **10 285,48 ms** = **+23,43 %** contra a referência |
| travadas ≥33,3 ms por 40 s (`mine`) | 30 | **24** (re-corrida: **33**), das quais `com_remalha` = **24 / 33** — o número de frames ≥33,3 ms **é** o número de frames com rebuild |
| travadas ≥100 ms (`mine`) | 15 | **14** nas duas corridas; pior quadro 159,70 / 166,66 ms com 151,21 / 157,18 ms de malha |
| cruzamento (`idle` / `all`) | `sem_origem = 0` | `idle` 18/18 com remalha, `com_tick=127`, `sem_origem=0`; `all` 23/23, `com_tick=124`, `sem_origem=0`; **`mine` devolveu `sem_origem=1` numa das duas corridas** |
| `remalharam_sem_travar` | 0 | **0** nos quatro braços |

Consequência lida do número, não da intenção: **o chunk mínimo custa 45,04 ms = 7,4 quadros de piso**, e o
`≥33,3 ms` de `idle`, `mine` e `all` é **integralmente** composto por frames com rebuild dentro. O braço A
do §3.3, aceito "primeiro" pela página, está **rejeitado sozinho** por esse número — e o braço B está
reaberto pela cláusula que a própria página escreveu ("reabre B se a medição de hoje der chunk único
≥ 33,3 ms"): deram **128 de 128**.

### 2.2.2 As 128 amostras, e o que o teto não fatia — a régua do QUADRO

Esta seção existe porque o código a cita. Os comentários de `src/world/voxel_world.gd:45`,
`tests/af_bakeoff.gd:195` e `tests/aether_reactions_test.gd:5576`, `:5591`, `:5599` apontam para **§2.2.2**
como a fonte do "chunk único custa 45,04 – 152,74 ms em 128 amostras" — e até este parágrafo a seção não
existia (`grep -n "^### 2\.2"` desta página dava só `2.2` e `2.2.1`), que é o furo **#28** na forma mais
pior: um ponteiro de prosa cujo alvo é um número de seção, invisível para a varredura numérica da casa. O
número pedido é o da tabela de §2.2.1, linha "**um chunk sozinho**, fila vazia, 64 chunks": p50
**87,2 / 87,8 ms**, p90 117,3 / 123,0, max **145,4 / 152,7 ms**, soma 5 583,7 / 5 761,7 ms, **mínimo 45,04**
nas 128 leituras (dois braços do `mesh_cost_probe`, cada chunk medido uma vez na fila vazia e sete vezes
aquecido). Das cinco citações, quatro se resolvem aqui: o `87 ms/chunk` que o bake-off compara
(`tests/af_bakeoff.gd:195`) é o p50 desta linha, e os `152,74`/`45,04` dos três ponteiros do runner e do
mesher estão acima. A quinta — *"§2.2.2 mede tudo-pedra 82 ms contra tudo-ar 8,5 ms"*, em
[`tests/aether_reactions_test.gd:5576`](../../tests/aether_reactions_test.gd#L5576) — tem o par na **linha
de corpo modificado da tabela do §2.2.1** (`8,54 / 15,77 ms` de tudo-ar contra `82,05 / 83,80 ms` de
tudo-pedra), uma seção acima e não nesta: o número é verdadeiro e o ponteiro aponta para o irmão. Deixei o
desvio registrado em vez de duplicar a linha, porque duplicar é o que faz um número ter duas testemunhas.

O que a segunda metade do título cobra, e é a correção que a corrida de `99bbbde` abriu nesta página: o
teto de tempo foi escrito para fatiar **nível `y`**, e por isso o pior frame honesto não é "teto", nem
"teto + uma fatia média" — é **teto + o nível mais CARO medido + a varredura de topo + o comitimento**, os
três últimos sem onde cortar. A página tinha derivado o overshoot de **2,39 ms** como `152,74 ÷ 64`, e o
número é uma **média** de nível por chunk. Medido pelo instrumento, nível por nível, no caminho que o
jogador usa:

| grandeza (`mesh_frame_worst()`, µs) | base `95d519a` | vermelho pré-guarda | com a guarda (`99bbbde`) |
| --- | --- | --- | --- |
| nível mais caro do frame | nunca medido; a página usava **2,39 ms** = 152,74 ÷ 64 (média) | **2,39** (o teto ainda saía da média) | **8,87 / 9,91 / 12,89 ms** — um nível sozinho passa do budget inteiro de 8,00 |
| varredura de topo (`_scan_col_tops`, `:878`) | 0,5 – 3,2 ms (`sobra_laco` do §2.2.1) | **4,18** | **3,13 / 3,95 / 4,22 ms** |
| comitimento (`_commit_slice`, `:467`) | 0,1 – 0,3 ms (`upload_arrays`) | **1,05** | **0,93 / 0,94 / 1,04 ms** |
| pior frame do dreno (`frame_us`) | 159,70 / 166,66 ms (`mine`, §2.2.1) | **16,49 ms** contra **15,63** de teto | **10,06 / 10,46 / 10,59 ms** contra teto de dreno **21,98 / 22,02 / 25,89** |
| folga contra a janela de travada (33,30 ms) | — | estourada | **1,29× a 1,52×**, e não os 2,4× que o §3.2 anunciava |

Leitura das linhas literais, nos logs da mão que escreve o código: o vermelho está em
`.tools/med24_B4_reacoes.log:530` (16:18:36–16:19:37, antes da guarda) —
`worst_frame_ms=16.49 teto_dreno_ms=15.63 budget=8.00 nivel=2.39 scan=4.18 commit=1.05 frames=27/256`; os
verdes em `.tools/med24_B6_reacoes.log:530` (`10.59 / 21.98 / nivel 9.91 / scan 3.13 / commit 0.94`),
`.tools/med24_B7.log:530` (`10.46 / 22.02 / nivel 8.87 / scan 4.22 / commit 0.93`) e
`.tools/med24_B8.log:530` (`10.06 / 25.89 / nivel 12.89 / scan 3.95 / commit 1.04`).

Consequência para a página, escrita sem adjetivo: **um nível é a menor unidade de trabalho que o corte
tem, e o nível mais caro medido (12,89 ms) é 1,6× o teto (8,00 ms)**. Ou seja, `MESH_FRAME_BUDGET_US` não é
um teto de *frame* no sentido estrito — é o teto de **quanto se anda antes de perguntar de novo**, e o frame
pode fechar em `budget + nível`. Foi exatamente isso que a linha `OBSERVACAO` do dreno mostrou ao dono do
código, dois minutos depois de ele publicar `a537117`: o frame parava no meio do chunk, mas o mesmo quadro
fechava um chunk, comitava, varria o topo do próximo e andava mais níveis por cima do budget — **15,39 ms
contra o teto de 10,39** que o comentário da constante publicava. É o furo #41 em escala reduzida,
sobrevivendo ao próprio conserto, e o gate não via porque media só o **primeiro** frame do lote. Daí a
guarda no topo do `while` ([`:322`](../../src/world/voxel_world.gd#L322)), que tira do
`iniciados < p_frame_budget` o direito de gastar tempo, e a checagem nova do §5.1.

### 2.3 O que a perna 17 acabou de mudar no cenário de carga

A fila de gravidade pousou nesta `main` (`95d519a`) e ela **aumenta a quantidade de chunk sujo por
segundo**, o que muda a classe do problema:

- a única leitora de `block_changed` é a fila
  ([`block_update_queue.gd:35`](../../src/world/block_update_queue.gd#L35), `attach` conecta o sinal), e
  ela resolve até [`const MAX_PER_TICK: int = 256`](../../src/world/block_update_queue.gd#L13) posições
  por tick, com [`RECHECK_DELAY: int = 1`](../../src/world/block_update_queue.gd#L15) — a cascada desce
  em passos, tick após tick;
- cada resolução escreve pelo caminho do jogador (`place_falling_block`,
  [`voxel_world.gd:611-615`](../../src/world/voxel_world.gd#L611-L615) → `set_block`
  [`:585-596`](../../src/world/voxel_world.gd#L585-L596) → `_touch_chunks_of`
  [`:618-629`](../../src/world/voxel_world.gd#L618-L629)), e `_touch_chunks_of` marca o chunk próprio **e os
  vizinhos** quando a célula está na borda;
- o pump roda no tick de 20 Hz ([`main.gd:343`](../../src/main.gd#L343)), enquanto a malha roda por frame
  ([`main.gd:388`](../../src/main.gd#L388)) a ~165 Hz.

Consequência que a página registra **antes** do corte: com 17, o pior caso deixa de ser "um quadro caro"
e passa a ser **fila que não drena** — uma cascada de areia suja mais chunks por segundo do que
`MESH_BUDGET` consome. Um teto de tempo **sem** medir o dreno transformaria travada em atraso permanente
de desenho, que é pior. Por isso o gate do §5 tem dois números obrigatórios, não um: o teto por frame **e**
o tempo de dreno da fila. A precedência é a do [`dossiê 17 §3.3`](17-fisica-de-blocos-que-caem.md): a
alavanca de carga da queda é `MAX_PER_TICK`, **nunca** `MESH_BUDGET`.

### 2.3.1 E a latência disso já tem instrumento, com número publicado

Este é o achado que mais muda a forma do gate, e ele **não** estava na rodada de ontem. A casa já mede o
atraso entre a edição e o mesh pronto, dentro do próprio `VoxelWorld`:

- [`_mark()` carimba o chunk na primeira edição](../../src/world/voxel_world.gd#L632-L650) com
  `Time.get_ticks_usec()` ([`:648`](../../src/world/voxel_world.gd#L648)) e o comentário diz o que se quer
  medir: *"o atraso ate o jogador ver o bloco trocado, nao a media das chamadas"*
  ([`:646`](../../src/world/voxel_world.gd#L646));
- [`_record_edit_cost()`](../../src/world/voxel_world.gd#L660-L671) fecha a conta e acumula
  `total` / `count` / `worst` — com **dois** call sites desde o braço B, porque há dois caminhos de
  fechamento: [`_finish_slice()` `:379`](../../src/world/voxel_world.gd#L379) na última fatia de um chunk
  e [`build_chunk_mesh()` `:401`](../../src/world/voxel_world.gd#L401) no caminho inteiro (boot); o
  comentário de [`_finish_slice` `:373-375`](../../src/world/voxel_world.gd#L373-L375) diz por que um
  chunk caduco **não** fecha ali — o carimbo fica aberto e a segunda rodada soma trabalho nele;
- [`edit_mesh_cost()`](../../src/world/voxel_world.gd#L681-L695) publica `count`, `worst_us`, `mean_us`,
  `worst_build_us`, `mean_build_us` e `pending`, e sai no `diagnostics()`
  ([`main.gd:1327`](../../src/main.gd#L1327), com o comentário do
  dossiê 07 §4: sem essa coluna a mesa decidia o mesher sem o lado do jogador).

E a régua composta já existe, com número: o [`dossiê 07:72`](07-af-bench-bake-off-voxel-e-doc-do-simclock.md)
define **`mesh_ms + 52·mean_us`** como a métrica do gate de mesher, medida em três corridas por braço
(`[MEASURED]`, árvore do bake-off — `run-A-1..3` dão `mesh_ms` 4 300,12 ms médio, `mean_us` 77 561,5 µs,
`worst_us` 162 843 µs de pico, métrica **8 333,32 ms**; o braço C perdeu por +18,02 % e vive só em patch).
**O termo do produto mudou de portador no commit do corte** — `mean_us` (span) passou a
`mean_build_us` (trabalho), com o span impresso ao lado como preço — e a razão, a corrida e o que isso
faz da régua estão no §5.1 item 2, não aqui; quem ler esta seção e a do §5.1 tem de vê-las dizerem a mesma
coisa.

**Por que isso decide o corte:** um teto de tempo **compra quadro às custas de fila** — chunk que fica para
o frame seguinte aumenta exatamente `mean_us` e `worst_us`, que são números publicados. Então o A do §3.3
não pode ser aceito por um número só, e o corte que baixar o pior quadro movendo a métrica composta para
cima não é uma melhoria, é uma troca de vítima. A casa já tem palavras para isso no
[`dossiê 07:101`](07-af-bench-bake-off-voxel-e-doc-do-simclock.md): troca de mesher só se o braço novo
ganhar por > 10 % em `mesh_ms` somado ao custo de edição.

### 2.4 O que não existe (grep conferido na `main`, com o que os commits desta perna já derrubaram)

- **nenhuma decisão por tempo no loop — na `main`.** Esta é a afirmação que o corte desta perna derruba, e
  ela continua verdadeira só para a base: em `36e842c:src/world/voxel_world.gd:228-236` as duas leituras de
  relógio do `process()` ficam **fora** dele — `36e842c:...:231` antes do primeiro chunk e
  `36e842c:...:236` depois do último — e entre um `build_chunk_mesh` e o próximo não há consulta nenhuma.
  As outras duas leituras daquele arquivo (`36e842c:...:359`, `:370`) são o carimbo de latência do §2.3.1,
  que **mede** e não **decide**; e não há nenhuma constante de µs/ms de malha em `src/main.gd` ao lado de
  [`MESH_BUDGET := 2`](../../src/main.gd#L28) — conferido agora com `grep -c MESH_FRAME_BUDGET_US` na
  `main`, que devolve **0**. Nos dois commits desta perna o `break` por relógio existe, e em **duas**
  unidades: `a537117:src/world/voxel_world.gd:314` (dentro do laço de nível, corpo `a537117:...:295-329`,
  constante `a537117:...:52`) e, desde `99bbbde`, também
  [`:322`](../../src/world/voxel_world.gd#L322) antes de o chunk **entrar**, com a guarda de nível na linha
  [`:336`](../../src/world/voxel_world.gd#L336) e a constante em
  [`:55`](../../src/world/voxel_world.gd#L55) — que é o §2.1;
- **nenhuma checagem de QUADRO — na base.** A régua de timing da casa é do **passo** de simulação:
  `espalhamento_nao_estoura_o_passo` exige `worst_sim_ms <= 25.0`
  ([`aether_reactions_test.gd:4560-4564`](../../tests/aether_reactions_test.gd#L4560-L4564), chamada em
  [`smoke_test.gd:3583`](../../tests/smoke_test.gd#L3583)). Nada **em `src/`** da base afirma nada sobre o
  período do quadro de desenho — o que existia sobre malha era dreno e latência, não tempo por frame. Isso
  é o que o §5.1 desta página escreve contra: **quatro** checagens, três no runner
  (`malha_orca_tempo_e_nao_itens` [`:5557`](../../tests/aether_reactions_test.gd#L5557),
  `dreno_nao_passa_do_teto_com_as_pecas_atomicas`
  [`:5643`](../../tests/aether_reactions_test.gd#L5643) — esta só existe desde `99bbbde` — e
  `orcamento_de_malha_tem_nome_e_origem` [`:5657`](../../tests/aether_reactions_test.gd#L5657)) e a composta
  no bake-off ([`af_bakeoff.gd:202`](../../tests/af_bakeoff.gd#L202)), todas commitadas — `c86f1a0` as três
  primeiras, `a537117` a do bake-off re-portada, `99bbbde` a do quadro (§8.1 e §9);
- **nenhum orçamento por subsistema de render**: o que existe é contagem (`MESH_BUDGET`) e período
  (`VIZ_PERIOD`, `AETHER_PERIOD`). Não há página, código ou teste para malha em thread — o braço **B** é o
  alvo decidido pelo §2.2.1, e o **C** continua alvo sem autorização nesta perna (§6). O que **passou a
  existir** é a fatia: `_MeshSlice` ([`:280-301`](../../src/world/voxel_world.gd#L280-L301)) e
  `_mesh_level()` ([`:408`](../../src/world/voxel_world.gd#L408)) desde `a537117`.

## 3. O que a peça exige

### 3.1 Dono do estado

`VoxelWorld` é a dona da fila `_dirty` e do cronômetro `_last_mesh_ms`; o corte acontece **dentro** de
`process()`, onde a fila já vive. O teto novo é uma `const` **na própria classe** — o precedente é
[`WATER_TOP_DROP`](../../src/world/voxel_world.gd#L34), declarado em `voxel_world.gd:34` e lido por quem
testa ([`smoke_test.gd:693`](../../tests/smoke_test.gd#L693)) em vez de copiado. `src/main.gd` **não ganha
nenhuma linha** nesta perna: `MESH_BUDGET` ([`main.gd:28`](../../src/main.gd#L28)) continua onde está, com
o significado de sempre (itens por frame), e o objeto deus já é débito registrado — não licença para
crescer. Não vai para [`voxel_config.gd`](../../src/world/voxel_config.gd#L2) porque o cabeçalho daquele
arquivo declara *constantes estruturais* cujo mudança invalida save, e um teto de µs por frame não é
estrutura: não move formato de chunk nem chave de region.

### 3.2 A forma mínima do corte

O loop pergunta ao relógio **depois** de cada chunk aceito, e para de aceitar quando a soma do frame
passou do teto. O `MESH_BUDGET` continua sendo o teto de itens (para o lote continuar limitado mesmo
quando o chunk for barato); o que entra é o teto de tempo ao lado dele, como `const` da própria classe.
O valor, decidido pela corrida do §2.2.1 e não chutado: **`MESH_FRAME_BUDGET_US := 8000`** — oito ms é a
maior fadiga que ainda cabe na régua absoluta com o piso de 6,06 ms (6,06 + 8 = 14,06 ms, folga de 2,4×
contra os 33,3 ms). E é também o número que **desmascara o A sozinho**: a menor unidade de trabalho que
existe hoje no mesher é um chunk, medido em **45,04 ms no melhor caso** — 5,6× o teto. Um teto de tempo
só é teto se existir trabalho menor que ele; sem a fatia do braço B, o `break` de cima apenas impede
pagar duas vezes. A grandeza acumulada é a mesma que `_last_mesh_ms` já calcula, então o diagnóstico e a
decisão passam a ler o mesmo número. Forma, não código:

```gdscript
# forma, nao codigo: teto em µs lido da classe; o que sobra fica na fila que ja existe
var gastou_us := 0
var fez := 0
while fez < p_frame_budget and not _dirty.is_empty():
	var antes := Time.get_ticks_usec()
	build_chunk_mesh(_dirty.pop_front())
	gastou_us += Time.get_ticks_usec() - antes
	fez += 1
	if gastou_us >= MESH_FRAME_BUDGET_US:
		break
_last_mesh_ms = float(gastou_us) / 1000.0
```

Isso **não** resolve o chunk sozinho, e agora com número: o chunk mais barato das 128 amostras custa
45,04 ms, então o primeiro aceito do frame já estoura o teto em qualquer config, e o `break` só evita o
segundo. E **cobra** algo: o chunk que fica para o frame seguinte aumenta `mean_us` e `worst_us` do
instrumento do §2.3.1, que é número publicado — medido nesta árvore, `mean_us` 91 718 – 99 947 µs e
`worst_us` 200 161 – 232 026 µs para 52 remalhas, e o `mean_us` **sobe** com o corte (95 351 → 128 663 µs)
pelo motivo nomeado no §3.3.1. É por isso que o corte é um fork com duas réguas, não
uma linha.

**O que o corte tem hoje, lido de `99bbbde`, e as duas frases acima que a corrida ajustou.** A forma mínima
da época — perguntar o relógio *depois* de cada chunk aceito — virou **duas** perguntas, em lugares
diferentes: [`:322`](../../src/world/voxel_world.gd#L322) antes de o chunk **entrar** (com o estouro do
teto, `iniciados < p_frame_budget` deixa de ser licença para gastar tempo) e
[`:336`](../../src/world/voxel_world.gd#L336) antes de cada nível `y`. E o "pior quadro ≈ 10,4 ms, folga de
2,4×" desta seção era aritmética de **média**: o `2,39 ms` usado como overshoot é `152,74 ÷ 64`, e o número
medido nível a nível é **8,87 – 12,89 ms** (§2.2.2). O teto, portanto, não é um teto de frame no sentido
estrito — é o teto de *quanto se anda antes de perguntar de novo*, e o frame pode fechar em teto + um nível.
Com as peças atômicas dentro, a folga honesta contra os 33,30 ms é **1,29× a 1,52×** (pior frame medido do
dreno 10,06 – 10,59 ms contra teto de dreno 21,98 – 25,89 ms), não 2,4×. Nada aqui move o critério: o valor
`8000` continua o mesmo, e o que mudou é a grandeza que a régua compara.

**E o §3.3.1.4 tinha razão sobre a vazão e estava errado sobre o teto de frames do palco.** A página
escreveu que "nenhum teto de teste é recalibrado por esta perna". Um foi. O teto literal de `64` frames do
`_mesh_frames()` do runner deixava a fila do **palco** não-drenar: o palco monta a plateia com `set_block`
antes de malhar e deixa **26** chunks na fila, e 26 × ~11 fatias ≈ **286** frames — com o `64` fixo,
`remeshes` parava em 6, `count` ficava em 1 contra 9 e `max_pending` congelava em 24, cinco checagens
vermelhas de uma causa (os quatro números acima são do comentário que registra o achamento,
[`aether_reactions_test.gd:5349-5360`](../../tests/aether_reactions_test.gd#L5349-L5360) — testemunha da
mão que escreveu o código, não corrida desta passada). O conserto é de **unidade**, não de folga: o teto passou a ser
`pending_meshes() × VoxelChunk.SIZE_Y + 64` ([`aether_reactions_test.gd:5365`](../../tests/aether_reactions_test.gd#L5365)),
ou seja, aritmética do grão — um chunk cabe no máximo `SIZE_Y` frames, mais a margem de 64 que a casa já
tinha — e assim ele não envelhece a cada mudança de `MESH_FRAME_BUDGET_US`. O bake-off ficou com o `64`
porque ali o palco é uma edição por vez; e a parte da edição que a página previu está certa, com número
lido do log: `esper_max_frames=21/64` (`.tools/med24_B4_bakeoff.log:22`, 16:27:26 — dentro da banda de
**11 – 22** que o §3.3.1.4 escreveu antes do código; o comentário do runner em
[`aether_reactions_test.gd:5351`](../../tests/aether_reactions_test.gd#L5351) reporta **23** na corrida
dele, e as duas leituras ficam ditas em vez de arredondadas para a conveniência da previsão).

### 3.3 O fork, decidido por medição, registrado antes do código

| braço | o que é | o que resolve | **o número desta `main` que o aceita, e o que reabre o próximo** |
| --- | --- | --- | --- |
| **A** | só teto de tempo em `process()` | corta a cauda **dupla**: os 152–192 ms viram o custo de **um** chunk | **rejeitado sozinho pela corrida desta perna**, pelo número que a própria linha dele mandava conferir: o chunk único mínimo medido é **45,04 ms**, e **128 de 128** amostras passam de 33,3 ms. O A não leva o `≥33,3 ms` a lugar nenhum — só impede pagar dois chunks num frame, o que vale como passo 1 do B, não como corte. O `≥100 ms` de `mine` (14 ocorrências em 40 s, `[MEASURED]` em `95d519a`) também não cai: o pior frame com rebuild dentro deu **159,70 ms** com **151,21 ms** de malha |
| **B** | A **mais** fatia reatável de um chunk (o laço de `y` de `build_chunk_mesh` anda por cursor, e o cursor vive na entrada da fila) | corta o chunk de dezenas de ms para uma fatia; com `MESH_FRAME_BUDGET_US = 8000` e 1,36 ms/nível (87,2 ÷ 64, medido), a fatia típica são ~6 níveis, e o chunk mais caro (2,39 ms/nível) caberia em ~3 — o frame de malha vai a ~14 ms, folga de 2,4× contra os 33,3. **Os dois números por nível são MÉDIAS**, e a célula ao lado diz o que o instrumento mediu no lugar delas: 8,87 – 12,89 ms no nível mais caro, frame de dreno 10,06 – 10,59 ms e folga real 1,29× – 1,52× (§2.2.2) | **é o braço que a medição escolheu**, pela cláusula que a linha do A escreveu ("reabre B se chunk único ≥ 33,3 ms"). O preço está em §3.3.1, e nada nele é cosmético: borda de fatia, o instrumento de latência fechar na **última** fatia e o dreno de uma cascata deixar de se medir em frames de um chunk |
| **C** | gerar os `Packed*Array` fora da thread main (o trabalho é CPU; o commit das superfícies continua na main) | tira o custo do frame em vez de fatiá-lo | **continua último, e a medição de hoje o enfraqueceu**: 93–99 % do tempo de uma chamada está dentro do laço de voxel (`sobra_laco` 46,3 de 49,6 ms = 93,35 % no mínimo, 107,6 de 108,5 = 99,17 % no máximo; `scan_col_tops` ≤3,2 ms; `upload_arrays` ≤0,3 ms), então thread não reduz custo — **relocaliza**. Reduzir o custo pede colheita primeiro (§4.3, com a ablação que separa o teste de vizinho da emissão de face). É a única das três que toca o contrato de concorrência (o chunk lido pode ser escrito no meio do read — hoje `build_chunk_mesh` lê `c.get_block` sem nenhuma garantia), e o precedente da casa é o índice linear do mesher, que baixou o boot de ~16 s para ~7,5 s **sem** thread |

A ordem não é preferência: A é folha do que já existe (fila, cronômetro e `pending_meshes()`), B é um
andador a mais no mesmo arquivo, C é um contrato novo. A regra da casa é a solução mais simples que
preserva as propriedades do sistema — e aqui a propriedade a preservar é "o mundo desenhado é o mundo
que existe". Foi isso que fez a página oferecer A primeiro; a medição respondeu que o A sozinho não corta
a dor que o dono descreveu, e **A passa a ser o passo 1 de B, não um corte aceito em si**.

#### 3.3.1 O que B cobra, escrito antes da linha (e o que a medição de hoje já respondeu)

O argumento que torna B barato — e é ele que a corrida sustenta, não a intenção: com `MESH_FRAME_BUDGET_US`
= 8 000 µs, o trabalho total de uma cascata **não muda**. Hoje o A paga 1 chunk por frame: 52 chunks ×
87,2 ms = **4 534 ms** de fila, com o último chunk pronto em 4 534 ms. Com B, o mesmo chunk é aceito em
~11 fatias de ~8 ms, uma fatia por frame, e a fila drena nos mesmos **4 534 ms**, porque a vazão é o teto
× o número de frames. Então o **trabalho** (`mesh_ms`, `mean_build_us`) não sobe por construção, e o que
compra o quadro verde é a **redistribuição**, não a troca de vítima. A frase que esta página escreveu
antes da corrida era mais forte: dizia que `mean_us` e `worst_us` do instrumento do §2.3.1 **não** subiriam
— e `mean_us` é o **span** de relógio wall, não o trabalho. Medido com o corte em execução, o span **sobe
34,9 %** (95 351 → 128 663 µs, `a537117:tests/af_bakeoff.gd:183-198`) exatamente porque o chunk passa a
viver ~11 frames na fila em vez de um: a vazão da fila é a mesma, a espera de **um** chunk não é. A página
corrige a si mesma com o número, e o §5.1 item 2 registra o que o portador da régua passou a ser. Sobram
quatro consequências, e cada uma tem testemunha:

1. **Borda de fatia.** A face entre o último nível `y` já desenhado e o primeiro ainda não desenhado é
   emitida **uma** vez, no frame em que o vizinho de baixo existe. Se a regra for errada, o fruto muda, e
   quem pega é a dupla que já existe no bake-off — `corpo do mundo == SHA de referencia`
   ([`af_bakeoff.gd:208`](../../tests/af_bakeoff.gd#L208)) e `triangles do boot == referencia`
   ([`:125`](../../tests/af_bakeoff.gd#L125), os 214 448 conferidos em cada uma das três corridas de
   §2.2.1). **B não ganha checagem nova de geometria**: escrever uma espelhando essas seria a checagem que
   não pode falhar (§5.1).
2. **O carimbo fecha na última fatia.** `_record_edit_cost()` fecha a conta *"ao fim de
   `build_chunk_mesh`"* (o corpo era `36e842c:src/world/voxel_world.gd:367-374` na `main` e
   `a537117:...:606-617` no primeiro commit do corte; em `99bbbde` é
   [`:660-671`](../../src/world/voxel_world.gd#L660-L671)) e o **pagamento** desta consequência está no
   local, não na intenção: com o cursor, a função é chamada em [`:379`](../../src/world/voxel_world.gd#L379),
   dentro de `_finish_slice()` — ou seja, quando a **última** fatia fecha o chunk — e só no caminho inteiro
   (`build_chunk_mesh`, [`:401`](../../src/world/voxel_world.gd#L401), o do boot) ela continua no fim do
   laço; com cursor, "o fim" é a fatia que completa o chunk, senão `mean_us` passa a medir outra coisa sem dizer — que é a classe do
   furo #44/#56 (a testemunha virar constante). A checagem `custo de edicao == chunks remalhados`
   ([`af_bakeoff.gd:170`](../../tests/af_bakeoff.gd#L170), `count=52 remeshes=52` medidos) é o par que
   impede isso, e ela continua valendo porque conta **chunk completado**, não chamada.
3. **As quinze `Packed*Array` vivem mais tempo.** Nada novo no pico (só um chunk está em voo, como hoje),
   mas o array fica vivo por ~11 frames em vez de um, e o motor não pode liberar antes. É consequência de
   desenho, não defeito, e o único número que a confere é o `ram` do amostrador na janela — medido hoje em
   531 MB para o processo da sonda.
4. **Os dois tetos de frames da casa continuam válidos, e é isso que autoriza o B sem mexer em régua.**
   Quem drena em headless são dois laços, ambos **por edição/por palco**, não por cascata:
   `_drain()` do bake-off ([`af_bakeoff.gd:232-238`](../../tests/af_bakeoff.gd#L232-L238),
   `MAX_DRAIN_FRAMES := 64` em [`:55`](../../tests/af_bakeoff.gd#L55)) e `_mesh_frames(frames_limit := -1)`
   do runner ([`aether_reactions_test.gd:5362`](../../tests/aether_reactions_test.gd#L5362)). Hoje eles
   fecham em **2** frames (o `esper_max_frames=2` impresso nas três corridas de §2.2.1); com fatia, uma
   edição custa as ~11 fatias do seu próprio chunk, no máximo ~22 — **dentro dos 64 dos dois lados**. O
   `max_pending <= 8` ([`:5512`](../../tests/aether_reactions_test.gd#L5512)) mede fila em **chunks**, e B
   não muda quantos chunks sujam nem a vazão, só o grão: fica como está. Então nenhum teto de teste é
   recalibrado por esta perna, e se um deles vermelhar com o corte a leitura é "o corte mudou a vazão", o
   que a tabela de cima nega — é defeito, não régua velha.
   **Esta quarta consequência errou metade, e a metade errada é a que a casa mais vigilava.** A vazão estava
   certa — `mesh_ms` cai 4,7 % e `esper_max_frames` do bake-off vem dentro da banda prevista (**21/64**,
   §3.2) — e o teto de frames do **palco do runner** não continuou válido: com o `64` literal, 26 chunks na
   fila × ~11 fatias ≈ 286 frames não drenam, e a régua foi recalibrada **em unidade**, não em folga
   (`pending_meshes() × SIZE_Y + 64`, [`:5365`](../../tests/aether_reactions_test.gd#L5365)). O "se um deles
   vermelhar a leitura é defeito, não régua velha" foi posto à prova e veio régua velha: o grão mudou o
   significado de `frames` de "frames de um chunk" para "frames de uma fatia", e um teto fixo em frames de
   chunk é a mesma classe de erro que o `#44` chama de testemunha virando constante. O que a página mantém
   é o critério: `max_pending <= 8` continua contando **chunks**, e nenhum teto de tempo da casa foi
   afrouxado por esta perna.

### 3.4 O que acontece com `MESH_BUDGET := 2`

`MESH_BUDGET` **não muda de significado nem de valor** neste corte: continua o teto de itens por frame, e
o teto novo é uma grandeza ao lado. Isso não é conservadorismo, é leitura de quem o consome:

- [`aether_reactions_test.gd:5370`](../../tests/aether_reactions_test.gd#L5370) drena a fila chamando
  `_world.process(int(Session.MESH_BUDGET))` e o comentário de
  [:5345-5347](../../tests/aether_reactions_test.gd#L5345-L5347)
  diz por que ele lê o número do produto em vez de copiar: *"um 2 escrito a mão envelheceria no dia em
  que o budget mudar"*;
- o mesmo runner imprime `max_pending` contra `MESH_BUDGET`
  ([`:5519`](../../tests/aether_reactions_test.gd#L5519));
- o bake-off do mesher se descreve pela régua do produto
  ([`tests/af_bakeoff.gd:10`](../../tests/af_bakeoff.gd#L10), `MAX_DRAIN_FRAMES := 64` em
  [:55](../../tests/af_bakeoff.gd#L55));
- quatro páginas de dossiê já proíbem subir esse número para esconder fila —
  [`12:441`](12-bicho-cavando-voxel.md), [`17:263`](17-fisica-de-blocos-que-caem.md),
  [`18:239`](18-mundo-vivo-grama-e-mato.md), [`20:504`](20-mente-autonoma-de-mobs-e-ecossistema.md).

Se um dia o significado mudar, a checagem do runner muda junto na mesma revisão — e é por isso que a
constante nova de tempo precisa de um nome que não se confunda com contagem (sufixo `_US`) e de morar na
classe do loop, não ao lado do `MESH_BUDGET` de `main.gd`.

## 4. Custo — as quatro perguntas

1. **Roda por frame, por tick ou às vezes?** Por frame, em `_process`
   ([`main.gd:388`](../../src/main.gd#L388)), ~165 Hz nesta máquina; e **só** quando há fila. É o único
   dos três andares do problema que roda no andar de desenho.
2. **Quantas entidades são alcançadas?** Zero entidades: um `VoxelChunk` por vez, 16 × 64 × 16 células,
   e a fila tem `pending_meshes()` como testemunha. No boot são 64 chunks de uma vez (por isso o congelamento do boot é outro assunto, medido 4 225–4 977 ms, e **esta perna não o toca**); numa cascada de 17, dezenas.
3. **Aloco no caminho quente?** Sim — **quinze** `Packed*Array` por chunk, três grupos de cinco (opaco,
   água, grama), que na `main` eram locais a `build_chunk_mesh`
   ([`voxel_world.gd:557-574`](../../src/world/voxel_world.gd#L557-L574)) e desde o corte são campos da
   classe `_MeshSlice` (`a537117:src/world/voxel_world.gd:273-287`; no HEAD da branch os quinze arrays
   estão em [`:287-301`](../../src/world/voxel_world.gd#L287-L301)), alocados no
   `_MeshSlice.new()` de cada chunk em voo — e a decomposição de §2.2.1
   responde o que nenhuma corrida tinha respondido: esse andar **não é o custo**. `upload_arrays` mede
   **0,1 – 0,3 ms** de uma chamada de 44 – 109 ms, e `scan_col_tops` 0,5 – 3,2 ms; os outros 93–99 % são a
   `sobra_laco`, o laço de voxel com o teste de vizinho e a emissão de face dentro. A alocação continua
   sem colheita própria (o que ela custa em lixo de coletor não foi medido por nada), mas o braço C do §3.3
   perde o argumento de custo: thread relocaliza os mesmos 93–99 %, não os reduz. O que reduz é cortar o
   laço, e
   para isso falta a ablação que separa **teste de vizinho** de **emissão de face** — o bracket sintético
   já delimita o tamanho do prêmio: 16 384 leituras de vazio custam 8,54 – 15,77 ms, os mesmos 16 384
   voxels sólidos com a casca emitindo custam **82,05 – 83,80 ms**. Se esse excedente for emissão por
   face, o teto é (82,05 − 8,54)/512 triângulos ≈ **0,143 ms/triângulo**; se for o teste de vizinho sobre
   sólido, nada de cortar face ajuda. É a colheita que a casa manda fazer antes do corte, agora com o
   número do prêmio na mesa. Registrar, não cortar às cegas.
4. **Como sei que ficou melhor?** Os dois números do §5, na mesma revisão: o teto respeitado (headless) e
   a cauda do quadro (sonda em janela, com o amostrador do furo #31 ligado). Um só deles não fecha: o
   headless não desenha, e a sonda sem a checagem do loop não prova que a regra do teto é a causa da
   melhora.

## 5. Gate

Nasce **vermelho** porque nenhuma das peças existe nesta `main` — e **já nasceu vermelho**:
`.tools/med24_red.log` fecha `367 checagens 3 falhas 57,874 s` às 15:28 desta rodada com
`teto_us=0` e `MESH_FRAME_BUDGET_US=0 em_VoxelWorld=false` nas linhas. Os tetos **deixaram de ser
placeholders**: a re-medição do §2.2.1 existe, rodou, foi vinculada a `95d519a` e é ela que aparece em cada
número abaixo. O que continua em aberto é o valor **depois** do corte — e só a corrida da branch pode
publicá-lo, não esta página.

### 5.1 Headless (a regra do loop)

**Quatro** checagens, cada uma com a premissa nomeada no próprio número impresso — **três no runner de
reações e a composta no bake-off**, que é onde `mesh_ms + 52·mean_us` já é calculada; a casa não exige em
qual arquivo mora, exige que o censo bata e que as quatro linhas existam. Elas não estavam aqui quando a
página foi escrita: a pauta previa três, e a quarta (`dreno_nao_passa_do_teto_com_as_pecas_atomicas`) é o
`99bbbde` pedir conta do que o §2.2.2 mediu. Escrito antes: **a saída idêntica do mesher não precisa de
checagem nova** — o bake-off já confere `corpo do mundo == SHA de referencia`
([`af_bakeoff.gd:208`](../../tests/af_bakeoff.gd#L208), `REF_BODY_SHA := 619e891c95dc5b44…` em
[`:45`](../../tests/af_bakeoff.gd#L45), conferido nas três corridas de §2.2.1), os `triangles` de boot e de
lote ([`:125`](../../tests/af_bakeoff.gd#L125), `214448/214448`, e o do lote `214484`), e `custo de edicao ==
chunks remalhados` ([`:170`](../../tests/af_bakeoff.gd#L170), `count=52 remeshes=52`).
Acrescentar uma checagem espelhando essas seria a checagem que não pode falhar — que a casa lê como
remoção de código adiada. É por aí que a borda de fatia do §3.3.1.1 é paga, e não por um quarto número —
o quarto número que esta perna escreve cobra outra coisa: o **tempo** do quadro, que nenhuma das três
existentes consultava.

1. `malha_orca_tempo_e_nao_itens` ([`aether_reactions_test.gd:5602-5608`](../../tests/aether_reactions_test.gd#L5602-L5608))
   — sujar `N ≥ 3` chunks de uma vez pelo caminho do jogador (`set_block`,
   [`player.gd:685`](../../src/entities/player.gd#L685)), chamar `process(2)` **um** frame e exigir
   `last_mesh_ms() <= teto_frame_ms` **e** `fechados == 0` **e** `pending_meshes()` ainda igual ao antes
   (o frame não pode ter completado o mundo inteiro disfarçado de uma fatia). O teto **aceito** é
   `MESH_FRAME_BUDGET_US + o nível mais CARO medido`, lido de `mesh_frame_worst()` depois de o próprio
   frame rodar ([`:5595-5597`](../../tests/aether_reactions_test.gd#L5595-L5597)) — e esta frase corrige a
   que a página tinha no lugar dela, que derivava o overshoot da **média**: `152,74 ms ÷ 64 = 2,39 ms`,
   logo **10,4 ms**. O número era apertado demais contra a realidade, e o comentário do runner diz isso com
   a corrida na mesa ([`:5588-5594`](../../tests/aether_reactions_test.gd#L5588-L5594)): com o nível
   derivado da média, o teto publicado dava 15,63 ms e o dreno real dava 16,49 ms. Medido, o nível mais
   caro por corrida é **8,87 / 9,91 / 12,89 ms** (§2.2.2), e daí os tetos de quadro reais: **16,87 / 17,91
   / 20,89 ms**. Nasce vermelha com o número da base na linha: o mesmo frame custava **45,04 – 152,74 ms**
   por chunk (128 amostras, §2.2.1), e o recorde publicado de um frame com dois chunks é 177,37 ms
   (`8a53b56`) contra 151,21 ms medidos agora. No palco da **própria** checagem, medido às 15:28 e às 15:34:
   `lote=3 fila=3->1 budget_itens=2 teto_us=0 frame_ms=144.35 chunks_no_frame=2` e, na re-corrida,
   `frame_ms=198.64` — **dois chunks inteiros fechados num frame** que o teto manda parar, com o
   `chunks_no_frame=2` dizendo a metade que a contagem de itens nunca deixou ver. Verde na árvore do
   `99bbbde`, com o `teto_us=8000` e o `nivel` medido impressos lado a lado:
   `lote=3 fila=3->3 budget_itens=2 teto_us=8000 nivel=12.89 teto_frame_ms=20.89 frame_ms=8.14
   chunks_no_frame=0` (`.tools/med24_B8.log:528`, 367 checagens / 0 falhas).
2. `corte_nao_cobra_latencia_maior_que_o_pico` — a mesma cena lida pelo instrumento do §2.3.1, com **três**
   números, e o segundo deles mudou de portador **no commit do corte**, o que esta página registra contra o
   código e não contra a intenção. Como esta página a escreveu, a composta era
   `mesh_ms + 52·mean_us` ([`dossiê 07:72`](07-af-bench-bake-off-voxel-e-doc-do-simclock.md)) e tinha de
   ficar **≤ 11 314,03 ms**, que é a base medida nesta árvore (**10 285,48 ms**, média de três
   corridas vinculadas) vezes a tolerância de **10 %** que o
   [`dossiê 07:101`](07-af-bench-bake-off-voxel-e-doc-do-simclock.md) já usa para trocar mesher. O que
   `a537117:tests/af_bakeoff.gd:199-206` faz é outra soma:

   ```gdscript
   var build_us := float(cost.get("mean_build_us", -1.0))
   var composta := float(diag["mesh_ms"]) + (52.0 * build_us / 1000.0)
   _check(build_us >= 0.0 and composta <= 11313.03 and _wait_frames_max <= MAX_DRAIN_FRAMES, ...)
   ```

   **Portador**: `mean_build_us` (o **trabalho** do mesher naquele chunk) no lugar de `mean_us` (o
   **span** de relógio wall, que abre no `_mark` e fecha na última fatia e que portanto conta os frames em
   que o chunk não trabalhou). A razão é corrida, não adjetivo, e está no comentário do próprio arquivo
   (`:183-198`): medido com `MESH_FRAME_BUDGET_US = 8000`, o span sobe de **95 351** para **128 663 µs**
   (+34,9 %) enquanto o trabalho **cai 4,7 %** (`mesh_ms` 5 327 → 5 078 µs) e a travada em janela vai a zero
   — 33 frames acima de 33,3 ms na base contra 0. (Portador corrigido contra os logs: os **33** saem de
   `.tools/med51_hp2_mine.log` (15:04:27, `MED_RUN` impresso); o log que o comentário nomea —
   `med24_hp2_mine_8kB.log` — imprime `>=33,3ms=0`, que é o lado do corte, e o controle `mine` desta branch,
   `med24_hp2_mine_base_fixattr.log` (16:01:45), imprime **21**, com o verde das duas guardas em
   `med24_hp3_mine_guard.log` (16:29:53, `99bbbde`, `>=33,3ms=0`, `sem_origem=4`). Débito com dono: uma
   linha de comentário em [`tests/af_bakeoff.gd:188-189`](../../tests/af_bakeoff.gd#L188-L189), que hoje
   atribui os 33 ao log do corte; nenhum veredito muda com isso.)
   Com o portador antigo a composta teria ido de 10 285 para
   **11 769 ms**, ou seja, **vermelha por causa do grão do corte**, e o dreno já estava guardado por outro
   número: o `_wait_frames_max <= MAX_DRAIN_FRAMES` da mesma linha, que é a forma em *frames* do que a
   página pedia em *µs*. É a decisão do dono do arquivo, e ela **não** afrouxa a régua: o que a página
   chamou de "trocar de vítima" (chunk que fica para o frame seguinte) passou a ser cobrado em
   `esper_max_frames`, com teto de **64**, e o span continua impresso como preço.
   (a) **O produto**: esta página publicou `11 313,03` por escorregão de transcrição — a aritmética dá
   **11 314,03** — e o commit do gate (`c86f1a0:tests/af_bakeoff.gd:182`) e o do corte
   (`a537117:tests/af_bakeoff.gd:201`) carregam o mesmo literal à vista, agora na linha **201** porque o
   arquivo cresceu o comentário de re-ancoragem. O cite é de revisão, não de ponteiro vivo. A diferença é
   **1,00 ms** (0,009 %) e não move veredicto nenhum dos que existem: `9 942,32`, `9 141,58` e `11 036,01`
   passam nos dois, `11 768,69` falha nos dois. Quem corrige o literal é o dono do arquivo, não esta
   passada (item 6 de "Branches"). (b) **A resolução**: as três corridas **sem** vínculo de revisão da
   mesma base dão `10 829,70`, `11 319,49` e `12 040,11 ms` — duas acima deste teto — e o amostrador
   daquelas janelas imprime `sem-godot-no-projeto`, enquanto o das três vinculadas imprime
   `pid=5788 cpu=103%`. Ou seja, a composta desta máquina se move mais entre janelas do que a folga de
   10 %, e a checagem 2 **não** decide sozinha: vale o par (corrida, janela amostrada), medido nas
   mesmas condições dos dois lados. É o **furo #60**, dono esta perna, e esta passada **não** move o
   teto por causa dele — mexer num critério com o corte já em voo é a mesma pena do **#31**. O dreno do
   palco tem de caber nos `64` frames que a casa já tem, com o `esper_max_frames` impresso subindo de
   **2** para a vizinhança de **11–22** (§3.3.1.4) — medido, **28** (`med24_Bk3_bakeoff.log`, 16:07,
   `esper_max_frames=28/64`), acima da banda prevista e dentro do teto. É ela que impede o corte que troca
   travada por atraso, e é a única das três que pode ficar vermelha por motivo legítimo num corte certo: se
   o **trabalho** por edição subir de verdade, o grão não era neutro e a premissa do §3.3.1 está errada.
   **Na base ela é verde, e é preciso dizer isso em vez de contar três vermelhos:**
   `.tools/med24_red_bakeoff.log` (15:35) dá `composta=9942.32 teto=11313.03 mesh_ms=4984.04
   mean_us=95351.5 esper_max_frames=2/64` dentro de `12 checagens 0 falhas 9,397 s`; com o corte já escrito
   na árvore — log de 16:07, quatro minutos **antes** do `a537117`, e portanto testemunha do conteúdo, não
   corrida vinculada ao SHA — a mesma checagem dá `composta=9141.58 teto=11313.03 mesh_ms=5775.03 mean_build_us=64741.4
   span_us=130049.3 esper_max_frames=28/64` dentro de `12 checagens 0 falhas 11,478 s`
   (`.tools/med24_Bk3_bakeoff.log`, 16:07) com `corpo=619e891c95dc5b44` e `triangles_boot=214448` idênticos
   aos da base — a geometria não se moveu. Ela é **guarda**, não testemunha do corte — o que ela cobra é
   que a composta **continue** abaixo do teto depois do A+B, com o dreno na faixa nova. E o `9 942,32` fica
   um pouco abaixo do menor dos três números do §2.2.1 (`9 996,76`): é a dispersão desta máquina, não uma
   melhora, e é por isso que o teto se compara à média publicada e não ao melhor run da mesa.
3. `orcamento_de_malha_tem_nome_e_origem`
   ([`aether_reactions_test.gd:5652-5660`](../../tests/aether_reactions_test.gd#L5652-L5660)) — o teto é
   lido de `VoxelWorld` por quem testa (o mesmo padrão de `WATER_TOP_DROP`, §3.1), o runner imprime o valor,
   e o nome **não** é `MESH_BUDGET`. É a checagem que paga a §3.4 e a que impede o runner envelhecer no dia
   em que o teto mudar — ele lê `Session.MESH_BUDGET` de
   [`main.gd:28`](../../src/main.gd#L28) em vez de copiar o número, e o comentário diz por quê
   ([`:5345-5347`](../../tests/aether_reactions_test.gd#L5345-L5347)). O vermelho dela estava na linha
   desde antes do corte: `MESH_FRAME_BUDGET_US=0 em_VoxelWorld=false MESH_BUDGET_em_VoxelWorld=false
   script=voxel_world.gd budget_itens_em_main=2 janela_hitch_us=33300` — a constante não existia, o nome
   antigo existia **só** em `main.gd`, e é isso que a checagem afirma antes de qualquer corte. Desde o
   commit do corte ela é verde com o `teto_us=8000` impresso, e a asserção ganhou duas metades de
   limpeza: `restaura["left"] == 0` e `cost_fim["pending"] == 0`, ou seja, o lote sai do teste sem fila e
   sem carimbo aberto no instrumento do §2.3.1.
4. `dreno_nao_passa_do_teto_com_as_pecas_atomicas`
   ([`aether_reactions_test.gd:5642-5647`](../../tests/aether_reactions_test.gd#L5642-L5647)) — esta é a
   checagem que o §2.2.2 abriu, e ela **não estava** na pauta de três que a página escreveu antes do
   código. A premissa nomeada: o teto vale para **todo** o dreno do lote, não só para o primeiro frame, e
   o pior frame honesto é `budget + UM nível + varredura de topo + comitimento` — as duas últimas peças
   não têm onde cortar, porque nenhuma delas é nível de chunk. Os três custos vêm de
   `mesh_frame_worst()` ([`voxel_world.gd:520-529`](../../src/world/voxel_world.gd#L520-L529)), medidos no
   caminho que corre, não derivados de média nenhuma, e a asserção tem **dois** lados:
   `worst_dreno <= teto_dreno` **e** `teto_dreno <= 33.30` — o segundo é o que impede o corte de comprar
   quadro movendo o teto para fora da janela de travada da página (§5.2), que é a forma de "trocar de
   vítima" que o §2.3.1 proíbe. Nascera vermelha **com o corte já escrito**, e é assim que ela entra na
   mesa: `worst_frame_ms=16.49 teto_dreno_ms=15.63 budget=8.00 nivel=2.39 scan=4.18 commit=1.05`
   (`.tools/med24_B4_reacoes.log:530`, 16:18–16:19, **367 checagens / 1 falha / 58,992 s**) — o `nivel`
   ainda era a média do §2.2.2 e o frame do dreno passou dele. Com a guarda no topo do `while` e o nível
   lido do pior medido, as **quatro** corridas seguintes passam nesta checagem — e é ela que decide se a
   contagem de falhas do rodapé é desta perna:
   `worst_frame_ms=13.38 teto_dreno_ms=26.00 budget=8.00 nivel=12.86 scan=4.07 commit=1.07`
   (`.tools/med24_B5_reacoes.log:530`, 16:22:38, **367 checagens / 1 falha / 62,838 s**),
   `10.59 / 21.98 / nivel=9.91 / scan=3.13 / commit=0.94`
   (`.tools/med24_B6_reacoes.log:530`, 16:24:28, **367 / 1 / 64,471 s**),
   `10.46 / 22.02 / nivel=8.87 / scan=4.22 / commit=0.93`
   (`.tools/med24_B7.log:530`, 16:25:47, **367 / 0 / 58,584 s**) e `10.06 / 25.89 / nivel=12.89 / scan=3.95 /
   commit=1.04` (`.tools/med24_B8.log:530`, 16:26:46, **367 / 0 / 56,667 s**). Repare o que o par de números
   diz e o que ele **não** diz: o `worst_frame_ms` do dreno caiu de 16,49 para 10,1–13,4 ms porque a guarda
   tirou do frame o chunk que ia entrar estourado, e o `teto_dreno` subiu de 15,63 para 21,98–26,00 porque o
   nível passou a ser o pior medido em vez da média — os dois lados da mesma correção, e o critério de
   33,30 ms não se moveu em nenhum deles. O B5 e o B6 têm **1** falha cada, e nenhuma é desta checagem nem
   desta perna: `budget_do_oraculo: o SubtreeGuard de 400 us nao estoura com o decode em voo |
   trips_antes=0 trips_depois=1` (`.tools/med24_B5_reacoes.log:3922`) e
   `nenhum estouro de subtree no budget | trips_solo=1 trips_matilha=1`
   (`.tools/med24_B6_reacoes.log:3980`) — o vermelho intermitente do `SubtreeGuard` da perna 22 com código
   idêntico, a classe do **furo #31**, que continua sem o par vermelha↔verde da *mesma* árvore.

O censo de checagens do runner e o do bake-off sobem com as novas, e o rodapé é o contrato: contagem,
falhas, tempo. A base era **11** no bake-off (`EXPECTED_CHECKS := 11` em
`36e842c:tests/af_bakeoff.gd:58`) e as três corridas do §2.2.1 deram **11 / 0** com exit 0; desde o
commit do gate a literal é **12** ([`af_bakeoff.gd:65`](../../tests/af_bakeoff.gd#L65)) e o bake-off fechou
`OK censo de checagens | 12/12` com `12 checagens 0 falhas 9,397 s` (`.tools/med24_red_bakeoff.log`, 15:35)
e de novo `12 / 0 / 10,813 s` no clone limpo do pin (`.tools/med24_pin_af_bakeoff.log`, 16:32). No runner, a
base é **364** (`36e842c:tests/aether_reactions_test.gd:149`), o `c86f1a0`/árvore em voo deu **367 / 3** às
15:28 e **366 / 2** às 15:34, `a537117` publica **366** (`a537117:tests/aether_reactions_test.gd:159`) e o
HEAD `99bbbde` publica **367** ([`:162`](../../tests/aether_reactions_test.gd#L162)) — e é 367 que as
corridas verdes de hoje batem: **367 / 0** duas vezes (B7, B8) com `OK censo de checagens`. A suíte
(`tests/smoke_test.tscn`) está em **278 checagens / 0 falhas / 63,4 s** na árvore do commit
(`.tools/med24_B4_smoke.log:415`). Mudar o censo sem mudar a literal é o tipo de verde que a casa não
publica — e aqui a literal mudou junto em cada uma das quatro vezes. O **drop** que o clone limpo mostra
não é censo afrouxado, é a checagem que cai quando `native/` não existe: **330 / 9** contra 367 na árvore
do commit (§9, o furo #38 na forma da conta).

### 5.2 Sonda em janela (a dor visível) — o único instrumento que pode dizer "parou de travar"

`.tools/hitch_probe_v2.gd` nos braços `floor`, `idle`, `mine`, `all`, 40 s, **máquina livre e serial**, com
`tools/carga_por_janela.ps1` ligado em par e arquivado — e, para o custo de **uma** chamada, o
`.tools/mesh_cost_probe.gd`, que é quem cronometra `build_chunk_mesh()` sozinho: na v1 publicada o
`52,6–78 ms` por chunk saiu de **divisão** (`mesh_total_ms / chunks`), e nenhuma corrida archivada mediu
um chunk isolado. Aceite escrito com a base de `95d519a` no lugar dos números de `8a53b56`:

- `floor` **sempre** tem de voltar com 0 travadas (é o que autoriza chamar o resto de travada). Medido:
  **6,06 ms** de p50, max 6,71 / 6,97, **0** travadas nas duas corridas, 6 582 e 6 583 amostras;
- **a régua relativa `≥2×p50` deixa de ser critério de aceite neste braço, e o motivo é o piso.** Com
  p50 = 6,06 ms, um frame que paga a fatia prevista de 8 ms custa 14,06 ms = 2,3× o piso — ela dispara
  por construção, antes de qualquer defeito. Sai do gate e continua **impressa** (base: 145 / 152 / 147
  ocorrências em 40 s nos braços `idle` / `mine` / `all`, das quais 120–127 têm `com_tick=1` e custam
  entre 12,1 e 33,3 ms — isso é a causa 2 do §9, de outro dono). Mudar critério calibrado é uma vez só, e
  é agora, com o número na mesa; não é silenciar o vermelho;
- o critério vira o **par absoluto**, com a base medida: `≥33,3 ms` **24 / 33 / 18 / 23** (`mine` /
  re-corrida / `idle` / `all`) → **0**; `≥100 ms` **14 / 14 / 6 / 14** → **0**. É a primeira vez que a
  página tem um alvo e o número do chão embaixo dele. A atribuição que autoriza exigir zero é a que a
  corrida devolveu: **o número de frames ≥33,3 ms é exatamente `com_remalha` nos quatro braços** —
  24 de 24, 33 de 33, 18 de 18, 23 de 23;
- `remalharam_sem_travar` continua **0** nos quatro braços, e é o par que impede um corte que apenas move
  o custo para outro andar;
- **`sem_origem` tinha de continuar 0, e a árvore base já devolve 1.** Na corrida `mine` das 15:01,
  `CRUZAMENTO travadas=145 | com_remalha=24 com_compilacao=0 com_tick=120 sem_origem=1 |
  remalharam_sem_travar=0` — 24 + 120 + 1 = 145, e a re-corrida das 15:04 deu `sem_origem=0` com
  `com_tick=119`. Ou seja: **um frame em 24 902 amostrados nas quatro armas** — e **1** dos **98** frames
  acima da janela de 33,3 ms — escapa das três testemunhas, e isso é vermelho da base,
  anterior a qualquer corte desta perna. Abre o **furo #59** com dono, e o critério honesto passa a ser
  `sem_origem ≤ 1` por janela de 40 s **enquanto** a causa não tiver nome — porque exigir 0 de um número
  que a base não entrega é gate que se fecha com a régua errada;
- todo número publicado sai **com a janela dele** (CPU do PID do projeto medida pelo amostrador), porque
  as réguas desta máquina não são comparáveis entre janelas — medido: a régua de 25 ms deu 12,94–15,48 ms
  de manhã e 31,33–32,41 ms cinco horas depois **na mesma árvore**, com `CrossDeviceService` a 215–291 %
  de um núcleo (Rodada 2026-11-25, débito do pouso da 23). Nas **oito** janelas de sonda e probe desta
  passada (`.tools/med51_carga_hp_{floor,idle,mine,all}.log`, `med51_carga_hp2_{floor,mine}.log`,
  `med51_carga_mesh0{1,2}.log`) o PID da corrida deu média de **93 – 107 % de um núcleo por janela**, com
  mínimo de **5 %** na primeira amostra do boot e máximo de **148 %** numa amostra do braço `all`; o único
  outro Godot do projeto na mesa é o par lançador (`Godot_v4.7.2-stable_win64_console.exe`, 7 MB, 0 %), e
  **nenhum terceiro processo do projeto** competiu — as quatro janelas do bake-off têm o mesmo par. Os
  intrusos, lidos pelo campo `alheias=` do amostrador: `QuantumEngine` (o app de áudio da JBL — 284
  amostras, máx **110 %**), `MsMpEng` (50, **129 %**), as quatro instâncias de `Qoder` (`#4` até **222 %**),
  `CrossDeviceService` (21, **235 %**) e a própria casa de ferramentas (`grep#1` **102 %**, `python`
  **98 %**) — daí a re-corrida de `mine` sair marcada como **teto**, não como valor.
- **A testemunha viva do furo #55 não está mais na mesa, e isso não fecha o #55.** O `pid 23400` — o
  Godot órfão que um `| head -3` deixou queimando núcleo desde as 12:48, publicado com linha literal em
  [`docs/melhorias-status.md:9760-9783`](../melhorias-status.md#L9760-L9783) — não existe mais na tabela
  de processos (conferido às ~15:05 com `Get-Process -Id 23400`). O que fecha é a **regra** (corrida
  redireciona para arquivo, nunca pipe), não a morte de um processo; o defeito que o criou continua sem
  conserto no `tools/`, e a janela de hoje ter sido limpa é consequência de ninguém ter vazado agora, não
  de o vazamento estar arrumado. A cláusula de §5.2 que dizia "a janela limpa tem um concorrente
  permanente" é aposentada por observação, com data, e o **#55** fica aberto;
- **e as duas metades da prova não conversam sobre o relógio — furo #58.** `.tools/med_run.ps1:22` grava
  `$stampStart = Get-Date` e imprime `fim=` em horário local (UTC−4) na linha `:68`, enquanto
  `tools/carga_por_janela.ps1:19` imprime `(Get-Date).ToUniversalTime()` (UTC): a mesma corrida `mine` das
  15:01 aparece como `MED_RUN inicio=15:01:15` no log do run e `AMOSTRA t=19:01:15` na primeira amostra do
  amostrador — **o mesmo segundo, quatro horas defasados**. Quem junta as duas pelo horário conclui que são
  janelas diferentes. Uma linha decide (um dos dois lados converte), e o dono é quem mantém
  `tools/carga_por_janela.ps1`; enquanto isso, **nenhum número desta página é vinculado por horário de
  amostra**, só por `pid` e por arquivo de log.

## 6. O que NÃO fazer

- **Não subir `MESH_BUDGET`** para esconder fila, nem rebaixá-lo para o verde aparecer mais rápido. Quatro
  páginas já o proíbem (§3.4) e a fila continuaria suja — só que sem teste.
- **Não chamar de otimização o que é troca de andar**: se o corte empurrar o custo para o tick de sim, o
  `worst_sim_ms` sobe e a régua de 25 ms pega. Os dois números do §5 correm juntos, não separados.
- **Não mexer em `Channel.COUNT`** ([`aether_field.gd:9`](../../src/world/aether_field.gd#L9)),
  `FORMAT_VERSION` ([`tick_journal.gd:4`](../../src/persistence/tick_journal.gd#L4)) nem `GEN_VERSION`
  ([`world_gen.gd:6`](../../src/world/world_gen.gd#L6)). Dito de outra forma, com a consequência assumida
  hoje: **mudar o tempo do mesh muda quando a geometria aparece, não o que o mundo contém** — então a
  projeção do `TickJournal` (edições, lobos, crenças) **não** se move com este corte, e um hash que se
  mover com ele é defeito da perna, não consequência de versão.
- **Não tocar no boot.** Os 4 225–4 977 ms de malharia do boot com a janela congelada são a dor maior do
  jogo, mas são outro corte ([`generate_meshes_all`, `:251`](../../src/world/voxel_world.gd#L251) no HEAD
  desta branch; era `:237` em `a537117` e `:207` na `main`), com
  gate próprio, e o `WARMUP_FRAMES := 20` da sonda existe justamente para não culpar o tick pelo boot.
- **Não escrever o A sozinho e chamar isso de corte.** O vermelho do A está na mesa (`frame_ms=144.35` e
  `198.64`, ambos com `chunks_no_frame=2`, §8.1) e é ele que rejeita o A por si: com o chunk mínimo a
  45,04 ms, o `break` do teto apenas impede pagar duas vezes — A e B entram no mesmo commit `perf:`. E
  **não abrir thread (C) sem o contrato de leitura do chunk resolvido por escrito** (§3.3), agora com o
  §2.2.1 dizendo que o C relocaliza os 95 – 99 % do laço em vez de reduzi-los.
- **Não publicar número de fluidez vindo de corrida headless** — a sonda em janela é a única testemunha
  do quadro.

## 7. Ordem, e a exceção registrada antes do código

A fila serializada viva, lida do índice e dos registros: **22 → 18 → 20 → 13**, com a **23** ainda em
Fase 2 (chuva) em worktree próprio. A **17 pousou** nesta `main` (`95d519a`), o que **dissolve** o choque
que existia quando esta perna foi pedida: a colisão era `src/world/voxel_world.gd`, que a 17 escrevia em
branch viva. Hoje não há co-escritor do mesher, e **a fila passa a 24 → 22 → 18 → 20 → 13**.

Preço aceito e registrado agora, antes da primeira linha:

1. A **18** (grama e mato) é a próxima a escrever `set_block` em massa e, pelo
   [`dossiê 18:239`](18-mundo-vivo-grama-e-mato.md), não pode tocar `MESH_BUDGET`. Ela **re-rome o gate**
   na árvore resultante (item 5 de "Branches"), e o gate dela vai drenar a fila sob o teto novo — o que é
   ganho, não agravo: o crescimento de grama é exatamente a segunda consumidora que mede o dreno.
2. A **12** (cavar) já pousou e escreve pelo mesmo `set_block`; corrida dela com o teto novo não
   reproduz os hashes publicados **do mesh** (a geometria aparece em outro frame), e a projeção do
   journal não se move (§6). Nada re-medido por este registro.
3. O **furo #41** deixa de estar "oferecido a quem chegar" e passa a ter dono nomeado: esta perna.
4. Autorização usada: a palavra do dono nesta conversa ("só falta isso, por favor, otimização"). Nada aqui
   abre P2, `HotSet`/Véu (que é design §04/§06 e pertence a P2), facções, co-op, progressão ou chefes.
5. Lido agora, e não previsto quando a perna foi pedida: a **22 Fase 4** está em worktree próprio
   (`feat/oraculo-nativo-fase4-22`, árvore `.qoder/worktrees/agent-general-purpose-a62068ad`) com trabalho
   **não commitado** de **+389/−28 em sete arquivos** de `src/`, `tests/` e `native/` — conferido às
   **15:33 local / 19:33 UTC** desta rodada com `git diff --shortstat HEAD -- src tests native`, e o número
   se move porque a perna está em voo. Dois deles têm o mesmo nome de peças desta página —
   `tests/aether_reactions_test.gd` (+173/−1, o palco que o §5.1 quer reusar) e `src/main.gd` (+11/−0) —
   mas são **outra instância de arquivo**: a worktree da 22 tem `114bcd2` como base, e o runner que o
   `git status` da árvore primária mostra modificado **não é o mesmo bytes** daquele. É o furo #53 com
   nome: dois `tests/aether_reactions_test.gd` vivos na mesma máquina, um por árvore, e quem confunde os
   dois publica o censo de uma perna na página da outra. O choque é de **merge**, não de árvore de
   trabalho: cada perna escreve na sua, e o `main.gd` fica fora do caminho da 24 exatamente porque o teto
   mora na classe do loop (§3.1). O preço registrado, antes de abrir branch: se a 22 Fase 4 pousar
   primeiro, a 24 **re-rome o gate** na árvore resultante (item 5 de "Branches") e as checagens novas
   entram em append no runner, com o censo somado re-medido — se ela não pousar, nada muda, porque
   nenhuma das duas escreve `voxel_world.gd`.

## 8. Commits atômicos — os quatro que existem, lidos de `git log`

Um assunto por commit, suíte verde entre eles, o número de cada corrida no commit a que ele responde. Isto
deixou de ser previsão às 15:51:35 desta passada; a lista abaixo foi re-lida às 17:02 contra
`git log --format='%h %ad %s'` e `git show --numstat`, com o censo de cada revisão conferido em
`git show <rev>:tests/…`, e o quarto elo entrou às 20:08:26 com a régua do item 2 na mesa:

1. `test:` **`c86f1a0`** (15:51:35) — *"Vermelho do dossie 24: o gate do orcamento de tempo nasce contra o
   process() que le o relogio fora do laco"*. Escreve **só** `tests/`: runner **+147/−8** (literal
   `EXPECTED_CHECKS` **364 → 366**, em `c86f1a0:tests/aether_reactions_test.gd:159`; no HEAD da branch é
   [`:162`](../../tests/aether_reactions_test.gd#L162)) e
   bake-off **+21/−2** (**11 → 12**, [`:65`](../../tests/af_bakeoff.gd#L65)). O vermelho está na mesa
   **antes** do corte, com três logs da mesma página em três posições do trabalho:
   `.tools/med24_red.log` (15:28:53, árvore com as três checagens no runner) fecha
   **367 / 3 / 57,874 s** com `OK censo de checagens | 367/367` e as linhas
   `lote=3 fila=3->1 budget_itens=2 teto_us=0 frame_ms=144.35 chunks_no_frame=2`,
   `frames=1/64 worst_frame_ms=93.83 inteiro_de_uma_ms=314.2 metrica_composta_ms=8421.06`
   (`triangulos=223606==223606`) e `MESH_FRAME_BUDGET_US=0 em_VoxelWorld=false`;
   `.tools/med24_red_reacoes.log` (15:34:42), com a checagem da composta já movida para o bake-off, dá
   **366 / 2 / 56,868 s** e `frame_ms=198.64`; e `.tools/med24_red2_reacoes.log` (15:51:04, trinta segundos
   antes do commit) é a testemunha mais próxima do que entrou: **366 / 2 / 60,451 s** com
   `teto_us=0 teto_frame_ms=2.39 frame_ms=165.91 chunks_no_frame=2` e
   `MESH_FRAME_BUDGET_US=0 em_VoxelWorld=false`. Onde mora cada checagem é escolha de quem escreve; o que o
   gate exige é o censo bater e as linhas existirem — por isso a casa lê o rodapé como contrato, não a
   lista de nomes;
2. `perf:` **`a537117`** (16:11:57) — *"Codigo do dossie 24 braco B: a malharia para pelo relogio dentro do
   loop, com o trabalho e o span como grandezas separadas"*. **A e B juntos**, porque o §2.2.1 rejeitou o A
   sozinho: sem a fatia reatável o `break` do teto apenas impede pagar duas vezes, e nada faz um chunk de
   45,04 – 152,74 ms caber num frame de teto + um nível (**16,87 ms** com o pior nível medido em 8,87 ms,
   §5.1 item 1). `src/world/voxel_world.gd` **+258/−108** e bake-off **+30/−10** (a composta passa a somar
   `mean_build_us`, o teto de `11313.03` **não se move** e o `_wait_frames_max <= 64` entra no mesmo
   `_check`);
3. `perf:`-correção **`99bbbde`** (16:28:51) — *"Dossie 24: o teto corta o QUADRO, nao so o chunk — a guarda
   no topo do loop e os tres custos atomicos que ele nao corta"*. `voxel_world.gd` **+61/−7** e runner
   **+65/−33** (censo **366 → 367**). É o commit que o vermelho **`med24_B4_reacoes.log`** (16:19:36,
   `worst_frame_ms=16.49 teto_dreno_ms=15.63 … nivel=2.39`, **367 / 1 / 58,992 s**) pediu: o teto derivado
   da **média** por nível não comportava o frame honesto, o nível tem de ser lido do instrumento como
   **pior** caso, e a guarda que faltava era a de [`:322`](../../src/world/voxel_world.gd#L322) — antes de
   o chunk **entrar**. Entra aqui a quarta checagem, em
   `99bbbde:tests/aether_reactions_test.gd:5642-5647` (prefixo de revisão porque o `94a4a12` abaixo move o
   corpo);
4. `test:` **`94a4a12`** (20:08:26) — *"Furo 61 pago: o teto do dreno passa a ser montado com o nivel lido
   depois do dreno"*. **Só** `tests/`: runner **+9/−2**, censo **367 inalterado**. A checagem 2 do gate
   montava o teto com `mesh_frame_worst()` lido **antes** do `_mesh_frames()` (as três peças saíam de
   `99bbbde:tests/aether_reactions_test.gd:5595-5597`, o lote era chamado em `:5613`) e julgava um frame
   medido **depois**: quando o nível amostrado saía barato o teto encolhia e um frame do próprio lote o
   passava — o vermelho `med24_B4_reacoes.log` (`nivel=2.39` contra `worst_frame_ms=16.49`) era isso. O
   conserto lê as peças depois do lote ([`:5634`](../../tests/aether_reactions_test.gd#L5634), o teto em
   [`:5640-5642`](../../tests/aether_reactions_test.gd#L5640-L5642), a asserção em
   [`:5648`](../../tests/aether_reactions_test.gd#L5648)), sem mover nenhum teto: a cláusula
   `teto_dreno <= 33.30` continua na linha e o vermelho do gate **sem** a guarda de topo (`c86f1a0`,
   `frame_ms=144.35 chunks_no_frame=2`) continua de pé. Duas corridas na árvore do commit: **367 / 0 /
   57,651 s** com `worst_frame_ms=16.42 teto_dreno_ms=25.67 nivel=12.40 scan=4.21 commit=1.07 frames=32/256`
   e **367 / 0 / 57,966 s** com `10.66 / 21.90 / nivel=8.75 / scan=4.15 / commit=1.00 frames=29/256`, mais
   suíte **278 / 0 / 63,9 s** e bake-off A **8 895,87** / C **8 659,30** contra o teto **11 313,03**
   (`.tools/med24_f61_*`, arquivados em
   [`../evidence/malha-orcamento-24/`](../evidence/malha-orcamento-24/)). Os dois `nivel` (12,40 e 8,75 ms)
   são maiores que o **2,39** da régua antiga — é exatamente a assimetria que o #61 dizia;
5. `docs:` — esta passada: os quatro documentos da perna (`AGENTS.md`, `docs/melhorias-status.md`, esta
   página e `docs/planos/README.md`) **mais nove** que o item 7 do ciclo obriga a re-derivar, porque citam
   `src/world/voxel_world.gd` e o arquivo cresceu **+313/−109**: `README.md` da raiz,
   `docs/design/10`, `docs/design/11`, `docs/planos/12`, `docs/planos/14`, `docs/planos/17`,
   `docs/planos/18`, `docs/planos/19` e `docs/planos/23`. Testemunha re-lida às 20:18:
   `git status --porcelain` dá **23 `M`** mais a pasta nova `docs/evidence/malha-orcamento-24/` (os **40**
   logs citados pela perna — **42** entradas com `.gdignore` e `artifacts.sha256`, conferido por
   `sha256sum -c` com **40** `OK` e zero falha), e
   `git status --porcelain -- src tests` dá **vazio** — nenhum arquivo de código está neste lote, e o código
   dele já está commitado nos quatro elos acima. A linha "Malha" da tabela de
   orçamentos do AGENTS deixa de dizer "contagem, não tempo" e passa a dizer o que é, com número e log; as
   âncoras que os três commits desalinhou são re-derivadas por `git grep -l` e não de memória (§9, e o
   item 7 do ciclo de trabalho), com o instrumento da casa estendido para este caso
   (`.tools/_audit_vw.py`, que **imprime o alvo em HEAD** para cada ponteiro — a régua numérica não vê a
   classe do #28/#51). O resultado, com as duas classes de defeito que a varredura achou e com a
   distribuição dos **158 + 25** ponteiros por documento, está na Rodada 2026-11-25 (15) do status;
6. o braço C (geração fora da thread main) **não entra** nesta perna, e a razão é a que o §3.3 registrou
   com número: thread relocaliza os 95 – 99 % do laço, não os reduz.

Branch: `perf/malha-orcamento-de-tempo-24`, **aberta e checkoutada na árvore primária** — `git reflog` dá
`36e842c HEAD@{4}: checkout: moving from main to perf/malha-orcamento-de-tempo-24` e os quatro commits acima
como `@{3}` (`c86f1a0`), `@{2}` (`a537117`), `@{1}` (`99bbbde`) e `@{0}` (`94a4a12`) — e não no worktree
separado que o item 6 de "Branches" pede nesta máquina. É desvio da regra da casa, registrado aqui em vez de
consertado: houve um segundo escritor ativo na mesma árvore enquanto a página se escrevia (§9), e movê-la no
meio disso é exatamente o tipo de passo que apagou uma versão já conferida no dossiê 03. O desvio tem custo
pago: os **23** documentos desta passada estão modificados **na mesma árvore** dos commits de código, então
`git log --first-parent main` ainda não responde "o que foi feito" por esta perna até o pouso. A branch em si
já está no remoto — `git ls-remote --heads origin refs/heads/perf/malha-orcamento-de-tempo-24` devolve
`99bbbde71911194d7a74574bc0435db62f04318b`, três dos quatro commits — e o `94a4a12` com os documentos sobem
com o pedido de push do dono; merge `--no-ff` na `main` (hoje `26c7f33`, que andou por outra perna) e
publicação se conferem com `git ls-remote --heads origin`.


## 9. O que este dossiê não fecha

- **A causa 2 da rodada de ontem continua aberta e não é desta perna**: o passo de 9,2–11,4 ms caindo num
  quadro de piso 6,0 ms a ~165 Hz, com `dropped_ticks = 0`. Aquilo é cadência de tela versus cadência de
  simulação, e o texto da casa já diz que não é defeito novo nem conserto pedido. Endereçar isso exige
  decidir render acima de 60 Hz ou desacoplar o desenho do passo — pauta de fase, não desta folha.
- **Alocação do caminho quente continua sem colheita**: os quinze `Packed*Array` por chunk (§4.3) são
  citados do código, não medidos, e o braço que os ataque precisa de instrumento antes de ter corte.
- **Nenhum gate de fase se fecha aqui** (mandato 4). A fila P0/P1 continua aberta nos elos que esta perna
  não toca: budget HOT sem medição, censo multi-semente sem corrida, bake-off de Éter sem número.
- **A página está dividida entre duas árvores, e agora isso está escrito.** O §2.2.1, o §3.2, o §3.3, o
  §4.3 e o §5 são de `95d519a` medidos hoje, com logs em `.tools/med51_*`; continuam `[MEASURED]` **de
  `8a53b56`**, e assim rotulados, o `192,20 ms` / `177,37 ms` de pior quadro e o boot de
  `4 225 – 4 977 ms` (§2.2 e §6) — a corrida do gate de hoje dá **4 984,0 ms** de malharia no boot
  (`.tools/med24_red_bakeoff.log`, `gen_ms=984.5 mesh_ms=4984.0`, 64 chunks), que é o mesmo andar e não o
  mesmo número. **Isso deixou de faltar com os quatro commits do §8**: o corte está em `a537117` + `99bbbde`
  e o verde existe na árvore do commit — runner **367 / 0 / 58,584 s** (`.tools/med24_B7.log`, 16:25:47) e
  **367 / 0 / 56,667 s** (`.tools/med24_B8.log`, 16:26:46), suíte **278 / 0 / 63,4 s**
  (`.tools/med24_B4_smoke.log:415`, 16:28:34) e bake-off **12 / 0 / 10,827 s** com
  `composta=8613.10 teto=11313.03 … esper_max_frames=21/64` (`.tools/med24_B4_bakeoff.log:22`, 16:27:26).
  Nenhuma daquelas quatro fecha **depois** de `99bbbde` (16:28:51) — são testemunha do corte, não corrida
  vinculada — e o **pin** delas existe: clone limpo de `99bbbde` com `--import` frio, `git rev-parse HEAD` =
  `99bbbde71911194d7a74574bc0435db62f04318b`, devolve runner **330 / 9 / 41,987 s**, suíte **278 / 2 / 65,1 s**
  e bake-off **12 / 0 / 10,813 s**, com as três portas deste gate **verdes dentro do clone**. O `94a4a12`
  (20:08:26) é o único dos quatro sem pin próprio — ele não toca `src/`, por isso o mesher do pin de `99bbbde`
  é o mesmo julgado pelas duas corridas novas (**367 / 0 / 57,651 s** e **367 / 0 / 57,966 s**, suíte
  **278 / 0 / 63,9 s**); a corrida vinculada dele é o clone limpo do **pouso**, no §10 abaixo. O clone
  limpo do pin existia e estava vermelho **de outra perna**; são os dois últimos bullets desta seção.
- **O palco do gate é mais caro que o mundo medido, e os dois números têm de ser lidos juntos.** Na
  fixture do runner, um chunk do plateau com STONE em `y=51` fechou o lote com conta de **302 ms por
  chunk** (`mean_lote_us=302246.0`, `carimbos_lote=1`), e o bake-off mede `worst_us=232339` no lote dele; o
  chunk mais caro do **mundo real** do §2.2.1 custa 152,74 ms. O overshoot que o §3.2 usa como teto de um
  frame (2,39 ms/nível = 152,74 ÷ 64) é derivado do mundo — no palco do teste seria 4,72 ms/nível. O que o
  jogador sente é o primeiro; o que a checagem exige é o segundo, e a página diz isso para ninguém trocar
  os dois por conveniência.
- **Há um segundo escritor na árvore primária, nesta perna, agora — e esta página não re-edita o runner
  nem o mesher por causa disso.** Testemunha lida, não adjetivo: `tests/aether_reactions_test.gd` passou de
  `EXPECTED_CHECKS = 367` para `= 366` **entre** duas leituras `git diff` desta conversa (15:30:5x e
  15:31:12, o mtime do arquivo bate no segundo), `.tools/gate24_fix.py` foi criado às 15:31:01,
  `.tools/med24_red_bakeoff.log` foi escrito às 15:35:05, `tests/af_bakeoff.gd` mudou às 15:32:52 e
  `src/world/voxel_world.gd` mudou às **15:39:58** com **+167/−105** — o corte A+B já em escrita, com
  `const MESH_FRAME_BUDGET_US: int = 8000` igual ao valor decidido no §3.2, uma classe `_MeshSlice`, o
  `while` que pergunta o relógio **antes de cada nível** e `_finish_slice()`/`_commit_slice()`. Nada desses
  arquivos foi tocado por esta passada, e o `git status` da árvore dá quatro modificados: esta página e os
  três deles. É o item 6 de "Branches" violado por observação, registrado em vez de consertado, porque
  mover a branch ou tocar o código do outro escritor é o passo que apagou uma versão já conferida no
  dossiê 03. Duas coisas saem daí e ficam com quem escreve o código: o comentário do runner **e** o de
  `voxel_world.gd` citam **§2.2.2** (a linha do `# (128 amostras, §2.2.2)`, hoje por volta de `:45` — e o
  arquivo voltou a mudar às 15:40:54, um segundo depois desta escrita, por isso nem se tenta fixar o
  número), seção que não existe nesta página (`grep -n
  "^### 2\.2" docs/planos/24-*.md` dá só `2.2` e `2.2.1`) — furo #28 na forma de ponteiro de prosa,
  invisível para a varredura numérica; e `python tools/check_doc_anchors.py` nesta página, corrido às 15:40
  contra a **árvore de trabalho**, devolve **3 casos objetivos** (`_record_edit_cost` rotulado em `:367-374`
  contra o corpo que hoje está em `:386-399`, `edit_mesh_cost` idem, e `:231` branco). Os três se resolvem
  um a um contra o commit: `git show HEAD:src/world/voxel_world.gd` dá `process()` em `:228`, o relógio em
  `:231` e `:236`, `_mark` em `:349`, `_record_edit_cost` em `:367`, `edit_mesh_cost` em `:381`,
  `generate_meshes_all` em `:207` — **que são exatamente os números que esta página cita**. Eles passam a
  envelhecidos no commit em que o corte pousar, e a re-derivação é o commit `docs:` do §8.3, não uma
  edição em cima de um arquivo que está sendo escrito.
- **A mesma testemunha, 27 minutos depois.** Às 15:52 o vermelho do gate deixou de ser só log: a outra mão
  commitou `c86f1a0` (*"Vermelho do dossie 24..."*) e o commit escreve **só** `tests/` (runner +155,
  bake-off +23/−10). O corte continua sem commit e voltou a mover duas vezes durante o fecho desta
  passada — `src/world/voxel_world.gd` **+208/−105**, 954 linhas, md5 `81f47037…` às 16:02:47, e
  **+258/−108**, md5 `ad85184f…` às 16:06:46; `tests/af_bakeoff.gd` **+30/−10**, com o literal do teto
  saindo da linha 182 (a do commit) para a 201. O `git status` da árvore primária dá agora seis
  modificados (os quatro documentos desta passada mais os dois arquivos de código alheios). A régua de
  âncoras nesta página, lida às 16:07 contra a árvore de trabalho, devolve **4** casos — `:158`
  (`_record_edit_cost`, corpo hoje em `:606-626`), `:160` (`edit_mesh_cost`, hoje `:627-643`), `:180`
  (branco em `:236`) e `:76` (branco em `:552`) — e o par de controle que os absolve é o mesmo de antes:
  conferidos um a um contra `git show HEAD:src/world/voxel_world.gd`, os quatro estão certos **no
  commit**. A diferença entre as duas leituras é que o HEAD de hoje é `c86f1a0` e o `voxel_world.gd` do
  HEAD ainda não tem o corte; quando ele for commitado, estes quatro ponteiros passam a envelhecidos e é
  aí, e não agora, que o §8.3 os re-deriva.
- **O corte é commit às 16:11:57, e a re-derivação do §8.3 acontece 7 minutos depois.** `a537117`
  (*"Codigo do dossie 24 braco B: a malharia para pelo relogio dentro do loop, com o trabalho e o span como
  grandezas separadas"*) escreve **dois** arquivos: `src/world/voxel_world.gd` **+258/−108** (o número que
  esta página tinha lido como "sem commit" às 16:06:46 é exatamente o que entrou) e
  `tests/af_bakeoff.gd` **+30/−10**. Com ele, a asserção do §2.4 "nenhuma decisão por tempo no loop" deixa
  de valer para o HEAD da branch e passa a valer só para a `main` — `36e842c` continua sem o corte, e foi
  assim que a seção ficou escrita, com os dois lados nomeados. Os ponteiros de `voxel_world.gd` desta
  página foram re-derivados **contra `a537117`** (`git show a537117:src/world/voxel_world.gd`, 1 001
  linhas): `process()` `:228-236` → `:295-329` com o relógio dentro do laço em `:314`, `MESH_FRAME_BUDGET_US`
  `:52`, `CHUNK_SIZE_X/Y/Z` `:54-56`, `var _dirty` `:67` → `:78`, `generate_meshes_all` `:207` → `:237`,
  `pending_meshes()` `:239` → `:468`, `last_mesh_ms()` `:243` → `:472`, `build_chunk_mesh` `:552` → `:355`
  (o corpo do laço triplo agora é `_mesh_level` `:372-430`), as quinze arrays `:557-574` → `_MeshSlice`
  `:273-287`, `set_block` `:328` → `:531`, `_touch_chunks_of` `:335` → `:564`, `_mark` `:349-361` →
  `:578-596` (carimbo `:594`, comentário `:592`), `_record_edit_cost` `:367-374` → `:606-617` (relógio
  `:609`) e `edit_mesh_cost` `:381-390` → `:627-641`. No runner, `a537117` não muda nada, então os ponteiros
  dele valem contra `c86f1a0`: drenagem `:5340` → `:5367`, comentário `:5333-5334` → `:5343-5344`,
  `max_pending` impresso `:5483` → `:5491`.
- **O que o commit fez com a régua do §5.1, e a página corrige a si mesma.** A checagem 2 passou a somar
  `mean_build_us` (trabalho) em vez de `mean_us` (span), com o teto de `11313.03` **não movido** e o
  `_wait_frames_max <= 64` dentro do mesmo `_check`. O motivo é um par de números que a própria página
  tinha escrito errado: eu afirmei no §3.3.1 que o span não subiria por construção, e ele sobe
  **+34,9 %** (95 351 → 128 663 µs) porque o chunk passa a viver ~11 frames na fila; o trabalho cai
  **−4,7 %** (`mesh_ms` 5 327 → 5 078 µs) e a travada em janela vai a zero. Com o portador antigo a
  composta teria ido a **11 769 ms** — vermelha pelo grão do corte, não por troca de vítima. As corridas
  que sustentam isso, lidas nos logs da outra mão, são a
  base `.tools/med51_hp2_mine.log` (15:04:27 — `>=33,3ms=33`, `com_remalha=33`, `sem_origem=0`, `MED_RUN`
  impresso) contra o corte `.tools/med24_hp2_mine_8kB.log` (15:54:47–15:55:35 — `>=33,3ms=0`) e, na árvore
  das **duas** guardas, `.tools/med24_hp3_mine_guard.log` (16:29:53, `99bbbde` — `>=33,3ms=0` com
  `sem_origem=4`, que é o **#59** ainda sem causa nomeada). O controle do mesmo portador nesta branch,
  `.tools/med24_hp2_mine_base_fixattr.log` (16:01:45), dá `>=33,3ms=21`; e
  `.tools/med24_Bk3_bakeoff.log` (16:07): `composta=9141.58 teto=11313.03 mesh_ms=5775.03
  mean_build_us=64741.4 span_us=130049.3 esper_max_frames=28/64` dentro de
  `12 checagens 0 falhas 11,478 s`, com `corpo=619e891c95dc5b44` e `triangles_boot=214448` **idênticos**
  aos da base — a geometria não se moveu, que é a cláusula do §3.3.1 item 1. O `esper_max_frames` saiu da
  banda que a página previu (**11–22**) e veio **28**; acima da previsão, dentro do teto, e a diferença é
  o palco do teste (302 ms/chunk no runner, §9 acima), não o mundo.
- **As réguas da árvore do corte, lidas nos logs escritos entre 16:09 e 16:11** (não corri a suíte nesta
  passada — a máquina estava sob as corridas da outra mão e medição de tempo é serial): runner
  `366 checagens 0 falhas 57,885 s` (`.tools/med24_B3_reacoes.log`, 16:09:11), suíte
  `278 checagens 0 falhas 67,8 s` (`.tools/med24_B3_smoke.log`, 16:10:32, linha 415, com
  `8 ObjectDB instances were leaked` e `4 resources still in use at exit` no rodapé de sempre), física de
  blocos `16 checagens 0 falhas 9/9 testes concluidos 25,024 s`
  (`.tools/med24_B3_block_physics_test.log`, 16:11:28) e o bake-off `12/0` do bullet acima. **Nenhum dos
  quatro vincula o SHA**: as três corridas fecham 26 s a 89 s **antes** do commit, com o conteúdo que o
  commit carregou (o `voxel_world.gd` de +258/−108 lido às 16:06:46), **e o clone limpo de `a537117` foi
  corrido sim**: `.tools/med24_pin_import.log` (16:12:44) e `.tools/med24_pin_import2.log` (16:13:06) são o
  `--import` dele, `.tools/med24_pin_smoke.log` (16:14:24) dá `== 278 checagens 2 falhas 65.9 s de teste ==`
  e `.tools/med24_pin_reacoes.log` (16:15:15) dá `329 checagens 9 falhas 45.208 s` com
  `FALHA censo de checagens | 329/366` — o `366` de `a537117`, não o `367` de `99bbbde`. A frase velha
  estava certa só no vínculo: essas quatro corridas antecedem `99bbbde` em quinze minutos e meio e **não**
  são o pin daquela revisão. O que elas valem é outra coisa, e é a face do **#61**: no mesmo log,
  `teto_frame_ms=10.39` (`:534`) contra `worst_frame_ms=15.39` (`:535`) — `8,00 + 2,39`, o teto montado com o
  nível lido **antes** do dreno, na árvore de uma guarda só.
- **O censo do runner voltou a subir** na árvore de trabalho: `EXPECTED_CHECKS` é **366** em `a537117`
  (`:159`) e **367** no arquivo em escrita (`:162`, lido às 16:18) — 367 → 366 → 367 no mesmo dia, e é por
  isso que esta página só pineia o censo de `99bbbde`: no clone limpo dele o `EXPECTED_CHECKS` é **367** e o
  rodapé devolve **330** (`FALHA censo de checagens | 330/367`), que é o **#38** em números. O de `a537117`
  fica como leitura de árvore intermediária.
- **E a árvore de trabalho voltou a mover depois do commit.** `git status` às 16:18 dá seis modificados:
  os quatro documentos desta passada (`AGENTS.md`, o status, esta página e o índice dos dossiês) mais dois
  arquivos alheios em escrita — `src/world/voxel_world.gd` **+50/−6** (mtime 16:17:29, md5 `d985624f…`
  contra `f219c8aa…` do blob de `a537117`) e `tests/aether_reactions_test.gd` **+36/−11**
  (mtime 16:18:09). É o teto agora em **duas unidades** (o `if antes - t0 >= MESH_FRAME_BUDGET_US` de
  `:319`, antes de deixar um chunk **entrar**, mais o de `:333` dentro do laço de nível), com
  `_scan_col_tops` separado, `_mesh_worst_scan_us`/`_mesh_worst_frame_us` novos e o comentário do `process()`
  dizendo por quê: *"um chunk fatiado nao cabe em 8 ms"*. À hora daquela escrita nada disso tinha commit;
  **tem**, e é o `99bbbde` do bullet seguinte — os números daquele parágrafo eram da **árvore de trabalho**
  (`process()` em `:306-356`, arquivo com 1 046 linhas) e os do bullet do `a537117` eram do commit; é por
  isso que a página declara o portador de cada citação no alto do §2.1 em vez de misturar os dois.
- **O terceiro commit chega às 16:28:51 e é contra ele que a página está escrita agora.** `99bbbde`
  (*"Dossie 24: o teto corta o QUADRO, nao so o chunk…"*) muda `src/world/voxel_world.gd` **+61/−7** e
  `tests/aether_reactions_test.gd` **+65/−33**. A re-derivação dos ponteiros vivos desta página, conferida
  com `git show HEAD:…` às 17:02 (arquivo com **1 055** linhas): `MESH_FRAME_BUDGET_US` `:52` → **`:55`**,
  `process()` `:295-329` → **`:309-359`** com **duas** guardas — **`:322`** antes de o chunk entrar e
  **`:336`** antes de cada nível —, `_MeshSlice` `:273-287` → **`:280-301`**, `_mesh_level` `:372-430` →
  **`:408`**, `build_chunk_mesh` `:355` → **`:385-401`** (o `_record_edit_cost` da saída inteira em
  **`:401`**, o `_finish_slice()` de `:366-379` na saída fatiada), `mesh_frame_worst()` **novo em
  `:520-529`**, `pending_meshes` `:468` → **`:506`**, `last_mesh_ms` `:472` → **`:510`**,
  `generate_meshes_all` `:237` → **`:251`**, `get_block_xyz` **`:559-572`**, `set_block` `:531` →
  **`:585-596`**, `place_falling_block` **`:611-615`**, `_touch_chunks_of` `:564` → **`:618-629`**, `_mark`
  `:578-596` → **`:632-650`** (carimbo **`:648`**, comentário **`:646`**), `_record_edit_cost` `:606-617` →
  **`:660-671`**, `edit_mesh_cost` `:627-641` → **`:681-695`**. No runner: censo `:159` (**366**) →
  **`:162`** (**367**), comentário do portador **`:5345-5347`**, `_mesh_frames(frames_limit := -1)`
  **`:5362`** com o teto de frames `pending × SIZE_Y + 64` em **`:5365`** e o
  `process(int(Session.MESH_BUDGET))` em **`:5370`**, `max_pending <= 8` em **`:5512`** (impresso em
  **`:5519`**), e o bloco das três checagens do runner entre **`:5555`** e **`:5661`** —
  **`:5602-5608`**, **`:5642-5647`** e **`:5652-5660`**. `tests/af_bakeoff.gd` **não mudou** desde
  `a537117`, e por isso a literal da composta está onde o §5.1 diz: **`:201-206`**. O que este bullet
  fecha e o anterior não podia fechar: pela primeira vez desde as 15:39 a árvore de trabalho **é** a do
  commit — `git status --short` às 17:02 não lista nenhum arquivo de código modificado.
- **O pin do que está em commit, e ele está vermelho de outra perna.** Clone limpo de `99bbbde` em
  `/c/tmp/aetherfall-pin-24`, `--import` frio (`med24_pin_import3.log`, 16:30:16) e as quatro frentes
  corridas em série entre 16:31 e 16:33: suíte **278 checagens / 2 falhas / 65,1 s**
  (`.tools/med24_pin_smoke2.log:421`), runner
  **`FALHA censo de checagens | 330/367`** com rodapé **330 / 9 / 41,987 s**
  (`.tools/med24_pin_reacoes2.log:631` e `:634`), bake-off
  **12 / 0 / 10,813 s**, RNG **27 / 0 / 2,774 s** e journal **128 / 0 / 6,997 s**. As **nove** falhas do
  runner e as **duas** da suíte têm o mesmo motivo, impresso:
  `extensao_carrega_classe … class_exists(AfMindOracle)=false`,
  `GDExtension dynamic library not found: 'res://native/af_mind/af_mind.gdextension'` — é o **furo #38**,
  decisão do dono (o `.dll` não está versionado, então nenhum clone limpo da `main` registra a classe), e
  nenhuma das nove é checagem desta perna. O que o número novo aqui é a **outra** metade: de 367 o censo
  devolve **330**, e **37 checagens caíram em silêncio** — nem vermelhas, nem contadas. É a cobrança do
  mandato 1 (o `SCRIPT ERROR` que derruba passos derruba checagens) em escala, e fica como débito do
  #38: enquanto a extensão não existir no clone, o rodapé daquele clone não é suíte nenhuma.
- **`med24_pin_reacoes_base.log` (16:33:03) é controle, não pin — e a lição dele é o #60, não um furo
  novo.** O arquivo roda o gate inteiro contra um `src/` **sem o corte**: as duas linhas do §5.1 estão
  vermelhas com `teto_us=0 teto_frame_ms=2.39 frame_ms=161.41 chunks_no_frame=2` e
  `MESH_FRAME_BUDGET_US=0 em_VoxelWorld=false`, e o censo é `329/366` (rodapé
  **329 / 11 / 42,354 s** em `.tools/med24_pin_reacoes_base.log:633`). Isso é uma
  testemunha útil — é o vermelho do A+B antes do corte, com a terceira checagem ainda ausente, o que bate
  com `tests/` de `c86f1a0` — **mas nenhum byte do log nomeia a árvore, o executável ou o SHA**: os
  `med24_pin_*` não têm uma linha `MED_RUN` (`grep -n MED_RUN` devolve vazio nos cinco), porque saíram de
  redirect direto, não do `.tools/med_run.ps1` que carimba `inicio/exe/args/pid/fim`. A casa já tem número
  para essa classe: o **#60** diz que a régua da composta não resolve contra corridas sem vínculo, e
  fechar o #60 exige exatamente o que aqui falta — as três corridas do corte **com stamp** pareadas com as
  vinculadas da base. Não abro furo novo para o mesmo fato; registro o par (o que o log prova / o que ele
  não vincula) e deixo o débito onde já está.
- **Os cinco ponteiros de prosa para §2.2.2 têm alvo, e o alvo foi escrito nesta passada.** A classe do
  furo #28 apareceu aqui na forma mais dura: `grep -n "2\.2\.2"` dá **1** em `src/world/voxel_world.gd`
  (**`:45`**), **3** em `tests/aether_reactions_test.gd` (**`:5576`**, **`:5591`**, **`:5599`**) e **1** em
  `tests/af_bakeoff.gd` (**`:195`**) — cinco citações feitas pela mão do código a uma seção que, quando
  foram escritas, não existia (`grep -n "^### 2\.2"` devolvia só `2.2` e `2.2.1`), e nenhuma delas tem
  número de linha de página, então a varredura numérica da casa **não vê nenhum dos cinco**. Esta passada
  criou a seção com o conteúdo que eles prometem: o **§2.2.2, "As 128 amostras, e o que o teto não
  fatia — a régua do QUADRO"**, com o
  mínimo de 45,04 ms, o máximo de 152,74 ms e o p50 de 87,2 / 87,8 ms que o bake-off compara; o par
  tudo-pedra / tudo-ar da quinta citação está na tabela do §2.2.1, uma seção acima, e o desvio do ponteiro
  está registrado no corpo do §2.2.2 em vez de consertado por duplicação. Fica resolvido **por conteúdo**,
  não por régua: o #28 continua
  aberto como defeito do instrumento, e os cinco ponteiros continuam invisíveis para
  `check_doc_anchors.py` — o que mudou é que agora eles apontam para algo.
- **O outro lado do item 7 foi cumprido na mesma passada, e é aqui que ele nasce.** A folha mais citada do
  repositório é o próprio `docs/melhorias-status.md`: **92** ponteiros antes do lote, **93**
  depois (o novo é a linha desta subseção que declara um `eb218fe:` fora da conta). Dos **58** cujo bloco
  tinha se movido, **45** foram reescritos por identidade de fragmento e conferidos no par, **13** foram
  lidos à mão — **8** conferidos e **5** falsos, e os cinco eram **erro desta passada**: re-ancoraram
  somando o delta do diff. Isso é o **furo #63**, e a regra que ele cobra já estava escrita no item 7 do
  ciclo: número publicado é número **re-lido no alvo**. As réguas, na árvore de `01faed6`: âncoras **3 528**
  ponteiros · **215** rótulos · **4 179** links com **74** casos objetivos e **zero** sobre linha
  desta passada (controle `--ref HEAD`: **3 420 · 215 · 4 081 · 109**, ou seja **35** casos fechados pelo
  lote); citações **3 388** conferidas · **45** arquivos inexistentes · **0** números fora do arquivo;
  identificadores desta página **102** com **18** ausentes, todos da classe "peça que a própria página
  declara comprar"; régua de conteúdo **2 498** em faixa, alegação colhida para **1 387**, **811**
  suspeitas, **45** sobre `voxel_world.gd`. **A frase antiga deste ponto estava errada e é corrigida com a
  mesa na frente**: ela dizia "nada disso foi commitado por esta leitura — a propagação está na árvore de
  trabalho", e a propagação **foi** commitada, na passada seguinte, em `01faed6` (20:31:12, com o par de
  `STAMP` `med24_pouso_stamp_main_*` e as três réguas re-corridas na árvore dos documentos). O índice de
  furos no topo da folha de status continua sem a linha do **#63** pelo motivo do próprio **#63** — inserir
  ali desloca as ~9 600 linhas abaixo, com os 93 ponteiros — e isso é débito da passada que reancorar o
  status por inteiro, não desta. O pouso, com as sete corridas da mergida, o clone limpo de `7b8924f` e o
  que ele fecha, está no **§10** abaixo.

## 10. O pouso na `main` — o teto de tempo mora na `main`, e o **#41** fecha em unidades dele

A perna era a da vez, foi aberta da `main` no ponto atual (`36e842c`) e pousou sobre o que a `main` tinha
entretanto — o `Rodar.bat` de `26c7f33`, que andou por outra mão e nunca por esta: `git merge --no-ff
perf/malha-orcamento-de-tempo-24` → **`7b8924f3e007cab34936a66bf54bc0de78aa54f9`**, pais `26c7f33` e
`01faed6`, **85 arquivos, +52 975/−473**, com o código em [`../../src/world/voxel_world.gd`](../../src/world/voxel_world.gd)
**+313/−109** (**1 055** linhas), [`../../tests/aether_reactions_test.gd`](../../tests/aether_reactions_test.gd)
**+186/−8** e [`../../tests/af_bakeoff.gd`](../../tests/af_bakeoff.gd) **+41/−2**. A autorização é a nomeada
das pernas anteriores — merge `--no-ff` na `main` e `push` do pouso — e o gate de fase continua do dono
(mandato 4): nenhum gate se fecha aqui.

**A árvore do merge é a árvore medida, por diff e por hash.** `git diff --name-only 01faed6 7b8924f -- src
tests docs` devolve **vazio**, e as árvores do merge são `git rev-parse 7b8924f:src` = `c0716d48bed2…` e
`:tests` = `3c85830feaf3…`. Nada foi re-rodado "por garantia": as sete corridas abaixo são da árvore
mergada, e o pin é do merge, não da ponta da branch — que era o débito que o §9 nomeava.

**As sete corridas na árvore mergida** (`.tools/med24_main_*.log`, arquivados em
[`../evidence/malha-orcamento-24/`](../evidence/malha-orcamento-24/), todos com `MED_RUN`, pid e exit):
suíte **278 checagens / 0 falhas / 66,3 s** exit 0 (`pid=27448`, `20:44:12→20:45:19`, `pior passo=14.36 ms`
com `perdidos=0`, `mesh_ms=5654.827`, `triangles=214512`); runner de reações **367 / 0 / 60,192 s**
(`pid=24532`, `OK censo de checagens | 367/367`); bake-off **A 12 / 0 / 11,303 s** com `composta=9019.05`
(`mesh_ms=5589.88  mean_build_us=65945.6  span_us=134281.5`, `esper 27/64`) e **C 12 / 0 / 11,153 s** com
`composta=8863.46` (`esper 24/64`), os dois contra o teto herdado **11 313,03** e ambos com
`corpo do mundo == SHA de referencia 619e891c95dc5b44…` e `triangles do boot == referencia 214448/214448`;
RNG **27 / 0 / 2,817 s**; journal **128 / 0 / 6,902 s** (`7/7 testes`); queda **16 / 0 / 24,375 s**
(`9/9 testes`). Zero `SCRIPT ERROR` nos **33** logs da passada — os `med24_main_*` e `med24_pouso_*`.

As três checagens do §5.1, com a linha literal da mergida:

```
OK malha_orca_tempo_e_nao_itens | lote=3 fila=3->3 budget_itens=2 teto_us=8000 nivel=8.53 teto_frame_ms=16.53 frame_ms=10.00 chunks_no_frame=0
OBSERVACAO malha_orca lote=3 frames_dreno=35/256 worst_frame_ms=15.76 teto_dreno_ms=25.33 carimbos_lote=3 mean_lote_us=207425.0 fila_final=0
OK dreno_nao_passa_do_teto_com_as_pecas_atomicas | worst_frame_ms=15.76 teto_dreno_ms=25.33 budget=8.00 nivel=12.36 scan=3.95 commit=1.01 frames=35/256 janela_hitch=33.30
OK orcamento_de_malha_tem_nome_e_origem | MESH_FRAME_BUDGET_US=8000 em_VoxelWorld=true MESH_BUDGET_em_VoxelWorld=false script=voxel_world.gd budget_itens_em_main=2 janela_hitch_us=33300
```

**O `frame_ms` do lote é o número do furo #41**: `144,35` no vermelho `c86f1a0` → **`10,00`** na mergida e
**`8,05`** no clone limpo, contra o piso do instrumento de **6,06 ms** e a janela de travada de **33,30 ms**.
O dreno do lote inteiro fica em **15,76 ms** (mergida) e **15,70 ms** (clone) — abaixo da janela com folga.

**A janela tem testemunha, e é a primeira da perna.** O amostrador consertado em `456dad9` (o **#56**) roda
pareado a cada corrida de gate: `med24_main_carga_suite.log` traz **70** das 81 amostras com o `pid` do
próprio `MED_RUN` (`pid=27448`) e `med24_main_carga_runner.log` **57** de 76 (`pid=24532`) — o par
corrida↔janela que o **#31** cobra e que nenhuma corrida desta perna tinha tido até o re-rome `5467c33`.
O par de `STAMP` (`med24_pouso_stamp_main_antes.log` / `_depois.log`) dá o mesher, o runner e o bake-off com
md5, bytes e mtime **iguais** dos dois lados de cada corrida, que é o vínculo que o **#60** exigia.

**O pin é do merge**: clone limpo de `7b8924f` (`C:/tmp/aetherfall-pin-24main`) com `--import` frio
(**15,5 s**, exit 0) → suíte **278 / 2 / 64,8 s**, runner **330 / 9 / 42,301 s** com
`FALHA censo de checagens | 330/367`, bake-off **A 12 / 0 / 11,323 s** (`composta=8874.77`) e **C 12 / 0 /
10,778 s** (`8526.98`), RNG **27 / 0**, journal **128 / 0**, queda **16 / 0**. As **nove** falhas do runner
e as **duas** da suíte são o **furo #38** com o nome na linha (`AfMindOracle nao esta na ClassDB nesta
arvore`, porque `native/af_mind/bin/` está no `.gitignore`), e **nenhuma** delas é deste gate:
`grep -c "^FALHA.*(malha_orca|dreno|orcamento_de_malha)"` dá **0** no log do pin, e as três portas saem
**verdes dentro do mesmo clone** — `frame_ms=8.05 chunks_no_frame=0`, `worst_frame_ms=15.70
teto_dreno_ms=23.12 nivel=11.20`, `MESH_FRAME_BUDGET_US=8000 em_VoxelWorld=true`.

**O que o pouso fecha.** **#41** — a malharia deixa de ser cortada só por contagem: `MESH_FRAME_BUDGET_US`
`= 8000` µs em [`../../src/world/voxel_world.gd:55`](../../src/world/voxel_world.gd#L55), perguntado em
**duas** unidades do laço ([`:322`](../../src/world/voxel_world.gd#L322) antes de deixar um chunk entrar,
[` :336`](../../src/world/voxel_world.gd#L336) antes de cada nível), com o chunk fatiado pela `_MeshSlice` e
devolvido à fila; `MESH_BUDGET := 2` continua em itens e as duas grandezas não se traduzem.
**#60** — pago pelo vínculo de revisão, não pelo critério: a folga de 1,00 ms entre o literal do código e o
teto da página nunca decidiu nada, e agora nenhuma corrida do gate entra sem `STAMP` e amostrador.
**#61** — pago em `94a4a12` com a checagem renomeada `dreno_nao_passa_do_teto_com_as_pecas_atomicas`: as
três peças do teto são lidas **depois** do dreno, como `scan` e `commit` já eram.

**O que fica aberto, com dono.** **#62** — a régua composta mudou de grandeza (a base somava
`mesh_ms + 52·span`; o corte soma `52·mean_build_us`) e o teto herdado **11 313,03** continua sendo o
`10 285,48 × 1,1` da definição **antiga**: o que se sustenta é que o corte fica **25 % abaixo** do teto
herdado, **não** que ficou abaixo da base sob a definição nova. **#59** — `sem_origem ≤ 1` por janela
continua a régua honesta enquanto a causa-2 (cadência de tela a ~165 Hz) não tiver nome. **§5.2** — a sonda
com janela continua sem pin: o verde de `med24_hp2_mine_8kB.log` (33 frames ≥33,3 ms na base contra **0**
com o corte) é da árvore de **um só** corte, e a árvore das duas guardas nunca foi re-sondada em janela. O
preço do corte, publicado com ele: `esper_max_frames` sai de **2/64** na base para **24–27/64**, porque o
teto de tempo compra quadro movendo fila — e é por isso que a composta é cobrada junto.

**As quatro réguas da casa, na árvore final destes documentos** (`med24_pouso_regua_anchors.log`,
`_cites.log`, `_content.log`, `_ids.log`, no manifesto de **81** entradas que `sha256sum -c` confere com
**81** `OK`): âncoras **41** arquivos · **3 548** ponteiros · **215** rótulos · **4 240** links · **74** casos
objetivos, cinco a menos que os **79** do clone limpo de `7b8924f` porque lá os cinco `../.tools/...`
gitignored estão quebrados — e **zero** caso novo das folhas desta passada; citações **3 402 / 45 / 0**
no corpus de **40** documentos; conteúdo **2 509** em faixa (**1 387** com alegação lida) e **814** suspeitas,
**46** sobre o mesher (o **#28**, com `main.gd` a **209** e `wolf.gd` a **177** na frente); `verify_plan_ids.py`
nesta página: **107** identificadores, **19** ausentes e todos declarados inexistentes pela própria página.

**A fila, a versão e a publicação.** A serializada passa a **22 → 18 → 20 → 13**: a 24 sai da frente e o elo
seguinte é `feat/oraculo-nativo-*` (Fase 4 em voo, `feat/mobs-autonomos-e-ecossistema-20` depois da 18). A
**18** chega na árvore do teto e **re-rome o gate** nela (item 5 de "Branches"): o teto de tempo dela passa
a ser a régua contra a qual o crescimento é drenado. `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a
projeção do `TickJournal` não foram tocados — `git diff --name-only 26c7f33 7b8924f -- src/persistence
src/world/aether_field.gd` devolve **vazio** — e mudar **quando** a geometria aparece não muda **o que** o
mundo contém. Publicação: `git ls-remote --heads origin`, única prova, com `refs/heads/main` =
`7b8924f…`.
