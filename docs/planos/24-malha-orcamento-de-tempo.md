# 24 — Malha: o orçamento é de **contagem**, e um frame paga dois chunks de 50–80 ms

Dossiê de **leitura de código**, escrito a pedido do dono em 2026-11-25, na própria conversa, como
fecho do que ele mesmo chamou de última coisa que faltava: *"orquestrar o agente responsavel o pq das
travadas qeu esta dando, so falta isso por favor, otimizacao... microtravadas."* O registro vem
**antes** de qualquer linha de `src/`, como exige o mandato 4 de
[`AGENTS.md`](../../AGENTS.md). Números de `arquivo:linha` desta página são da `main` em **`95d519a`**
(o pouso da perna 17), conferidos nesta árvore, não copiados da rodada que mediu.

A causa já tem nome e número desde a Rodada 2026-11-24 (6) de
[`docs/melhorias-status.md`](../melhorias-status.md#L7310-L7455): é o **furo #41**. O que nunca existiu
é o corte. Esta página entrega a forma do corte, os braços que a medição decide, e o gate que nasce
vermelho.

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

[`src/world/voxel_world.gd:228-236`](../../src/world/voxel_world.gd#L228-L236):

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

Três fatos do mesmo arquivo, lidos agora:

- a fila é um `Array` de chunk (`var _dirty: Array = []`,
  [`:67`](../../src/world/voxel_world.gd#L67)) consumida por `pop_front()`, e `pending_meshes()`
  ([`:239`](../../src/world/voxel_world.gd#L239)) já devolve o tamanho — ou seja, "o que sobrou para o
  frame seguinte" é uma grandeza que **já existe publicada**, sem peça nova;
- `last_mesh_ms()` ([`:243`](../../src/world/voxel_world.gd#L243)) já é a grandeza que a regra precisa
  consultar;
- o chunk é 16 × 64 × 16 ([`voxel_config.gd:5-7`](../../src/world/voxel_config.gd#L5-L7), e
  [`voxel_world.gd:43-45`](../../src/world/voxel_world.gd#L43-L45) repassa), e o loop triplo de
  `build_chunk_mesh` ([`:552`](../../src/world/voxel_world.gd#L552)) percorre as 16 384 células com seis
  faces cada. É por isso que o custo de **um** chunk é uma grandeza de dezenas de milissegundos, não de
  fração de quadro: a unidade minima de trabalho é maior que o quadro inteiro.

### 2.2 A medição que existe — e a árvore dela

`[MEASURED]` na `main` em **`8a53b56`**, oito braços, dez corridas, máquina livre, em
[`docs/melhorias-status.md:7310-7455`](../melhorias-status.md#L7310) com os logs arquivados em
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

O que **não** vale mais como número: a árvore de hoje tem **181 linhas a mais** em
`src/world/voxel_world.gd` e **175** em `src/main.gd` do que `8a53b56`. Metade delas é a perna 23 (água
viva), que pôs no mesher a leitura de coluna por voxel — o `water_flags` declarado hoje em
[`voxel_world.gd:591`](../../src/world/voxel_world.gd#L591), com o comentário que diz que ele é lido "uma
unica vez por bloco, e so quando a primeira face dele sai". Portanto **o 52–78 ms de ontem é hipótese
hoje** — pode ter encarecido, e a régua do gate não pode ser escrita com número emprestado de outra
revisão. A re-medição em `95d519a` está em curso (ponta de medição desta perna) e os placeholders do §5
são para ela.

### 2.3 O que a perna 17 acabou de mudar no cenário de carga

A fila de gravidade pousou nesta `main` (`95d519a`) e ela **aumenta a quantidade de chunk sujo por
segundo**, o que muda a classe do problema:

- a única leitora de `block_changed` é a fila
  ([`block_update_queue.gd:35`](../../src/world/block_update_queue.gd#L35), `attach` conecta o sinal), e
  ela resolve até [`const MAX_PER_TICK: int = 256`](../../src/world/block_update_queue.gd#L13) posições
  por tick, com [`RECHECK_DELAY: int = 1`](../../src/world/block_update_queue.gd#L15) — a cascada desce
  em passos, tick após tick;
- cada resolução escreve pelo caminho do jogador (`place_falling_block` →
  [`voxel_world.gd:328-333`](../../src/world/voxel_world.gd#L328-L333) → `set_block` → `_touch_chunks_of`
  [`:335`](../../src/world/voxel_world.gd#L335)), e `_touch_chunks_of` marca o chunk próprio **e os
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

- [`_mark()` carimba o chunk na primeira edição](../../src/world/voxel_world.gd#L349-L361) com
  `Time.get_ticks_usec()` (linha 359) e o comentário diz o que se quer medir: *"o atraso ate o jogador ver
  o bloco trocado, nao a media das chamadas"*;
- [`_record_edit_cost()`](../../src/world/voxel_world.gd#L367-L374) fecha a conta no fim de
  `build_chunk_mesh` e acumula `total` / `count` / `worst`;
- [`edit_mesh_cost()`](../../src/world/voxel_world.gd#L381-L390) publica `count`, `worst_us`, `mean_us`,
  `pending`, e sai no `diagnostics()` ([`main.gd:1327`](../../src/main.gd#L1327), com o comentário do
  dossiê 07 §4: sem essa coluna a mesa decidia o mesher sem o lado do jogador).

E a régua composta já existe, com número: o [`dossiê 07:72`](07-af-bench-bake-off-voxel-e-doc-do-simclock.md)
define **`mesh_ms + 52·mean_us`** como a métrica do gate de mesher, medida em três corridas por braço
(`[MEASURED]`, árvore do bake-off — `run-A-1..3` dão `mesh_ms` 4 300,12 ms médio, `mean_us` 77 561,5 µs,
`worst_us` 162 843 µs de pico, métrica **8 333,32 ms**; o braço C perdeu por +18,02 % e vive só em patch).

**Por que isso decide o corte:** um teto de tempo **compra quadro às custas de fila** — chunk que fica para
o frame seguinte aumenta exatamente `mean_us` e `worst_us`, que são números publicados. Então o A do §3.3
não pode ser aceito por um número só, e o corte que baixar o pior quadro movendo a métrica composta para
cima não é uma melhoria, é uma troca de vítima. A casa já tem palavras para isso no
[`dossiê 07:101`](07-af-bench-bake-off-voxel-e-doc-do-simclock.md): troca de mesher só se o braço novo
ganhar por > 10 % em `mesh_ms` somado ao custo de edição.

### 2.4 O que não existe (grep conferido nesta `main`)

- **nenhuma decisão por tempo no loop**: as duas leituras de relógio do `process()` ficam **fora** dele —
  [`:231`](../../src/world/voxel_world.gd#L231) antes do primeiro chunk e
  [`:236`](../../src/world/voxel_world.gd#L236) depois do último. Entre um `build_chunk_mesh` e o próximo
  não há consulta nenhuma. As outras duas leituras do arquivo (`:359`, `:370`) são o carimbo de latência
  do §2.3.1, que **mede** e não **decide**; e não há nenhuma constante de µs/ms de malha em `src/main.gd`
  ao lado de [`MESH_BUDGET := 2`](../../src/main.gd#L28);
- **nenhuma checagem de QUADRO**: a régua de timing da casa é do **passo** de simulação —
  `espalhamento_nao_estoura_o_passo` exige `worst_sim_ms <= 25.0`
  ([`aether_reactions_test.gd:4547-4551`](../../tests/aether_reactions_test.gd#L4547-L4551), chamada em
  [`smoke_test.gd:3583`](../../tests/smoke_test.gd#L3583)). Nada nesta árvore afirma nada sobre o período
  do quadro de desenho — o que existe sobre malha é dreno e latência, não tempo por frame;
- **nenhum orçamento por subsistema de render**: o que existe é contagem (`MESH_BUDGET`) e período
  (`VIZ_PERIOD`, `AETHER_PERIOD`). Não há página, código ou teste para "fatia de chunk" nem para malha em
  thread — os braços B e C do §3 são alvo, não fato.

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
quando o chunk for barato); o que entra é o teto de tempo ao lado dele, como `const` da própria classe
(`MESH_FRAME_BUDGET_US`, com o valor decidido no §5 e não chutado aqui). A grandeza acumulada é a mesma
que `_last_mesh_ms` já calcula, então o diagnóstico e a decisão passam a ler o mesmo número. Forma, não
código:

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

Isso **não** resolve o chunk sozinho: se um chunk custa 52–78 ms, o primeiro do frame já estoura, e o
teto só impede que ele estoure duas vezes. E **cobra** algo: o chunk que fica para o frame seguinte
aumenta `mean_us` e `worst_us` do instrumento do §2.3.1, que é número publicado. É por isso que o corte é
um fork com duas réuas, não uma linha.

### 3.3 O fork, decidido por medição, registrado antes do código

| braço | o que é | o que resolve | **o número desta `main` que o aceita, e o que reabre o próximo** |
| --- | --- | --- | --- |
| **A** | só teto de tempo em `process()` | corta a cauda **dupla**: os 152–192 ms viram o custo de um chunk; o `≥100 ms` do braço `mine` (15 ocorrências em 40 s, `[MEASURED]` em `8a53b56`) perde a metade superior | **aceito primeiro** (é o corte pequeno, no dono do estado, sem artefato visual novo). Aceite em **duas** réguas: o pior quadro cai **e** a métrica composta `mesh_ms + 52·mean_us` do [`dossiê 07:72`](07-af-bench-bake-off-voxel-e-doc-do-simclock.md) não sobe contra a referência A publicada (8 333,32 ms, `[MEASURED]` em outra árvore — re-medir nesta). **Reabre B** se a medição de hoje der chunk único ≥ 33,3 ms — aí o pior quadro continua acima de 5 quadros de piso e o A é só um atenuante |
| **B** | A **mais** fatia reatável de um chunk (ex.: o loop de `y` de `build_chunk_mesh` anda em slab de 16 e o estado do meio vive na própria fila) | corta o chunk de dezenas de ms para uma fração dele; o quadro fica sob a janela, e o `mean_us` sobe menos do que no A (porque o chunk não espera o frame inteiro) | aceito **só com o vermelho do A na mesa** e com o custo do `A` medido impresso. Preço escrito: o chunk fica **incompleto entre frames** — é artefato visual novo (uma faixa do terreno aparece um frame depois) e só é aceitável se a sonda em janela mostrar a cauda caindo sem introduzir pop visível. Reabre **C** se B não baixar o pior quadro para perto do piso |
| **C** | gerar os `Packed*Array` fora da thread main (o trabalho é CPU; o commit das superfícies continua na main) | tira o custo do frame em vez de fatiá-lo, e é o único braço que ataca as 15 linhas de alocação do §4.3 | **não** entra sem A e B medidos: é a única das três que toca o contrato de concorrência (o chunk lido pode ser escrito no meio do read — hoje `build_chunk_mesh` lê `c.get_block` sem nenhuma garantia), e o precedente da casa é o índice linear do mesher, que baixou o boot de ~16 s para ~7,5 s **sem** thread. Reabre quando A+B deixarem de levar o `≥33,3 ms` do braço `mine` para perto de zero |

A ordem não é preferência: A é folha do que já existe (fila, cronômetro e `pending_meshes()`), B é um
andador a mais no mesmo arquivo, C é um contrato novo. A regra da casa é a solução mais simples que
preserva as propriedades do sistema — e aqui a propriedade a preservar é "o mundo desenhado é o mundo
que existe", o que faz o artefato de B ser caro o bastante para exigir número antes de existir.

### 3.4 O que acontece com `MESH_BUDGET := 2`

`MESH_BUDGET` **não muda de significado nem de valor** neste corte: continua o teto de itens por frame, e
o teto novo é uma grandeza ao lado. Isso não é conservadorismo, é leitura de quem o consome:

- [`aether_reactions_test.gd:5340`](../../tests/aether_reactions_test.gd#L5340) drena a fila chamando
  `_world.process(int(Session.MESH_BUDGET))` e o comentário de [:5333-5334](../../tests/aether_reactions_test.gd#L5333-L5334)
  diz por que ele lê o número do produto em vez de copiar: *"um 2 escrito a mão envelheceria no dia em
  que o budget mudar"*;
- o mesmo runner imprime `max_pending` contra `MESH_BUDGET`
  ([`:5483`](../../tests/aether_reactions_test.gd#L5483));
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
3. **Aloco no caminho quente?** Sim, e é onde o A não chega: `build_chunk_mesh` aloca **quinze**
   `Packed*Array` por chunk — três grupos de cinco, o opaco, a água e a grama
   ([`voxel_world.gd:557-574`](../../src/world/voxel_world.gd#L557-L574)). O número é **contado do
   código**, não medido: isso é débito **sem colheita própria**, e a casa diz que o primeiro passo de
   qualquer otimização é a colheita (`AGENTS.md`, "Alocação no caminho quente existe e não é medida").
   Registrar, não cortar às cegas — por isso o braço C do §3.3 é o único que ataca essa linha, e ele vem
   por último.
4. **Como sei que ficou melhor?** Os dois números do §5, na mesma revisão: o teto respeitado (headless) e
   a cauda do quadro (sonda em janela, com o amostrador do furo #31 ligado). Um só deles não fecha: o
   headless não desenha, e a sonda sem a checagem do loop não prova que a regra do teto é a causa da
   melhora.

## 5. Gate

Nasce **vermelho** porque nenhuma das peças existe nesta `main`. Os tetos são placeholders `a medir` até
a corrida desta perna publicar o número na árvore do pin — é assim que a casa escreve um gate, e é o
motivo pelo qual nenhum valor está chutado aqui.

### 5.1 Headless (a regra do loop)

Três checagens novas, cada uma com a premissa nomeada no próprio número impresso. Escrito antes: **a
saída idêntica do mesher não precisa de checagem nova** — o bake-off já confere `corpo do mundo == SHA de
referencia` ([`af_bakeoff.gd:169`](../../tests/af_bakeoff.gd#L169), `REF_BODY_SHA := 619e891c95dc5b44…`),
os `triangles` de boot e de lote, e `custo de edicao == chunks remalhados`
([:162-163](../../tests/af_bakeoff.gd#L162-L163)). Acrescentar uma checagem espelhando essas seria a
checagem que não pode falhar — que a casa lê como remoção de código adiada.

1. `malha_orca_tempo_e_nao_itens` (em `tests/aether_reactions_test.gd`, no palco que já drena a fila com
   `Session.MESH_BUDGET` — [`:5335-5345`](../../tests/aether_reactions_test.gd#L5335-L5345)) — sujar
   `N ≥ 3` chunks de uma vez pelo caminho do jogador
   (`set_block`, [`player.gd:685`](../../src/entities/player.gd#L685)), chamar `process(2)` **um** frame e
   exigir `last_mesh_ms() <= teto_ms` **e** `pending_meshes() == N - 1`. Nasce vermelha: hoje o mesmo
   cenário constrói dois chunks por frame sem nenhuma consulta de relógio entre eles, e o pior quadro
   medido levou 177,37 ms de malha num frame só.
2. `corte_nao_cobra_latencia_maior_que_o_pico` — a mesma cena, lida pelo instrumento do §2.3.1: o dreno
   completo tem de caber em `frames_dreno ≤ teto` **e** a métrica composta
   `mesh_ms + 52·mean_us` ([`dossiê 07:72`](07-af-bench-bake-off-voxel-e-doc-do-simclock.md)) não pode
   subir contra a referência A da mesa. É ela que impede o corte que troca travada por atraso. O `teto`
   de frames tem de ser escrito a partir do `MAX_DRAIN_FRAMES := 64`
   ([`af_bakeoff.gd:55`](../../tests/af_bakeoff.gd#L55)), não de um número novo: se o teto de frames do
   bake-off deixar de esvaziar a fila com o corte, o corte é rejeitado por ele, e é isso que a página quer
   dizer com "testemunha".
3. `orcamento_de_malha_tem_nome_e_origem` — o teto é lido de `VoxelWorld` por quem testa, não escrito à
   mão no runner, e o nome dele **não** é `MESH_BUDGET` (é a checagem que paga a §3.4, e é a que impede o
   runner envelhecer no dia em que o teto mudar).

O censo de checagens do runner e o do bake-off sobem com as novas, e o rodapé é o contrato: contagem,
falhas, tempo. Os três `esperados` do bake-off (`EXPECTED_CHECKS := 11`,
[`af_bakeoff.gd:58`](../../tests/af_bakeoff.gd#L58)) são literal no arquivo — mudar o censo sem mudar a
literal é o tipo de verde que a casa não publica.

### 5.2 Sonda em janela (a dor visível) — o único instrumento que pode dizer "parou de travar"

`.tools/hitch_probe.gd` nos braços `floor`, `idle`, `mine`, `all`, 40 s, **máquina livre e serial**, com
`tools/carga_por_janela.ps1` ligado em par e arquivado — e, para o custo de **uma** chamada, o
`.tools/mesh_cost_probe.gd`, que é quem cronometra `build_chunk_mesh()` sozinho: na v1 publicada o
`52,6–78 ms` por chunk saiu de **divisão** (`mesh_total_ms / chunks`), e nenhuma corrida archivada mede
um chunk isolado. Aceite, escrito com o número da re-medição de `95d519a` no lugar dos de `8a53b56`:

- `floor` **sempre** tem de voltar com 0 travadas (é o que autoriza chamar o resto de travada);
- `≥33,3 ms` no braço `mine`: **30 → a medir**, alvo perto de zero **só se** o chunk único medido for
  menor que 33,3 ms; se não for, o alvo honesto do braço A é `≥100 ms` ir a zero e o `≥33,3` cair à
  metade — e a página diz isso em vez de prometer o que o A não alcança;
- `remalharam_sem_travar` e `sem_origem` têm de continuar **0**: é o par que impede um corte que apenas
  move o custo para outro andar;
- todo número publicado sai **com a janela dele** (CPU do PID do projeto medida pelo amostrador), porque
  as réguas desta máquina não são comparáveis entre janelas — medido: a régua de 25 ms deu 12,94–15,48 ms
  de manhã e 31,33–32,41 ms cinco horas depois **na mesma árvore**, com `CrossDeviceService` a 215–291 %
  de um núcleo (Rodada 2026-11-25, débito do pouso da 23).
- **A janela limpa tem agora um concorrente permanente que não é meu para fechar.** O `pid 23400` vivo
  desde as 12:48, a 11–27 % de um núcleo, é a **testemunha viva do furo #55** (o pipe que mata o `head` e
  deixa o Godot queimando núcleo), publicado em
  [`docs/melhorias-status.md:9687-9705`](../melhorias-status.md#L9687-L9705) com a linha literal do
  amostrador. Matá-lo é apagar a evidência de outra perna. Daí a regra desta página, lida do lado do
  instrumento e não do desejo: corrida **com carga só prova teto**. Se o chunk único medir `< 33,3 ms`
  mesmo com o vazamento ligado, o braço A basta e o número é decisivo; se medir `≥ 33,3 ms` sob carga, o
  número **não** compra o braço B — exige janela limpa antes de qualquer fatia. A sonda em janela (a dor
  visível) não tem versão sob carga: sem `floor` limpo ela não afirma nada.

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
  jogo, mas são outro corte (`generate_meshes_all`, [`:207`](../../src/world/voxel_world.gd#L207)), com
  gate próprio, e o `WARMUP_FRAMES := 20` da sonda existe justamente para não culpar o tick pelo boot.
- **Não escrever o braço B ou C sem o vermelho do A na mesa**, e não abrir thread sem o contrato de
  leitura do chunk resolvido por escrito (§3.3).
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
   (`feat/oraculo-nativo-fase4-22`) com trabalho **não commitado** de +379 linhas em sete arquivos, e dois
   deles são desta página — `tests/aether_reactions_test.gd` (+164, o palco que o §5.1 quer reusar) e
   `src/main.gd` (+11). O choque é de **merge**, não de árvore de trabalho: cada perna escreve na sua, e o
   `main.gd` fica fora do caminho da 24 exatamente porque o teto mora na classe do loop (§3.1). O preço
   registrado, antes de abrir branch: se a 22 Fase 4 pousar primeiro, a 24 **re-rome o gate** na árvore
   resultante (item 5 de "Branches") e as checagens novas entram em append no runner, com o censo somado
   re-medido — se ela não pousar, nada muda, porque nenhuma das duas escreve `voxel_world.gd`.

## 8. Commits atômicos previstos

Um assunto por commit, suíte verde entre eles, o número de cada corrida no commit a que ele responde:

1. `test:` as três checagens do §5.1 escritas **antes** do corte, com o rodapé vermelho que as nomeia
   (gate nascendo vermelho);
2. `perf:` o teto de tempo no `process()` — uma folha, com o par headless + sonda do mesmo pin;
3. `docs:` status, AGENTS.md (a linha "Malha" da tabela de orçamentos deixa de dizer "contagem, não
   tempo" e passa a dizer o que é, com número e log) e as âncoras que este corte desalinhou, re-derivadas
   por `git grep -l` e não de memória;
4. só com o vermelho do A na mesa: o braço B, com commits próprios e a mesma sequência.

Branch: `perf/malha-orcamento-de-tempo-24`, em worktree separado (item 6 de "Branches" — há três frentes
em worktree nesta máquina). Merge `--no-ff` na `main` e push só quando o dono pedir; publicação se confere
com `git ls-remote --heads origin`.

## 9. O que este dossiê não fecha

- **A causa 2 da rodada de ontem continua aberta e não é desta perna**: o passo de 9,2–11,4 ms caindo num
  quadro de piso 6,0 ms a ~165 Hz, com `dropped_ticks = 0`. Aquilo é cadência de tela versus cadência de
  simulação, e o texto da casa já diz que não é defeito novo nem conserto pedido. Endereçar isso exige
  decidir render acima de 60 Hz ou desacoplar o desenho do passo — pauta de fase, não desta folha.
- **Alocação do caminho quente continua sem colheita**: os quinze `Packed*Array` por chunk (§4.3) são
  citados do código, não medidos, e o braço que os ataque precisa de instrumento antes de ter corte.
- **Nenhum gate de fase se fecha aqui** (mandato 4). A fila P0/P1 continua aberta nos elos que esta perna
  não toca: budget HOT sem medição, censo multi-semente sem corrida, bake-off de Éter sem número.
- **Nenhum número desta página é de `95d519a` ainda.** Todo `[MEASURED]` aqui carrega a árvore
  `8a53b56`, e os tetos do §5 estão escritos como `a medir`. Antes de o primeiro commit de código existir,
  a re-medição tem de existir com logs arquivados e vínculo de revisão.
