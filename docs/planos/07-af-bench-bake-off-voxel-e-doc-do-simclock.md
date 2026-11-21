# 07 — `af-bench` de 10 min, bake-off de voxel e o doc do `SimClock`

Alvo: as três linhas não marcadas do checklist P0 em `docs/melhorias-status.md:489-493`. São P0,
não P1. Nenhuma das três peças existe hoje em `src/` — este texto diz o que precisa nascer, em
que ordem e com que comando. Gate de fase fecha o dono do repositório, não este plano.

## 1. Premissa nomeada (uma frase falsificável por peça)

| Peça | Premissa |
| --- | --- |
| `af-bench` | Se o passo de simulação for alimentado por `dt` fixo e não pelo relógio de parede, a mesma semente devolve o mesmo hash nos 12 000 ticks em 3 execuções seguidas em arquivo novo por corrida. |
| bake-off | Duas abordagens de malharia rodadas serialmente na mesma máquina produzem `gen_ms`, `mesh_ms` e `triangles` tabeláveis; sem essa tabela a escolha do mesher é opinião. |
| doc `simclock.md` | Cada limite escrito no doc corresponde a uma linha de `src/core/sim_clock.gd`; qualquer número no indicativo sem linha correspondente é defeito do doc. |

## 2. Estado real do instrumento

Existe e roda: `godot --headless --path . tests/smoke_test.tscn` (saída `N checagens M falhas T s`
em `tests/smoke_test.gd:169-170`, exit 1 se `M > 0`), os runners `extends SceneTree`
`tests/simulation_rng_test.gd:1`, `tests/tick_journal_test.gd:1`, `tests/aether_reactions_test.gd:1`,
o primitivo de hash `src/persistence/tick_journal.gd:16-44`, o CLI `--tick-journal=`
`src/main.gd:675-682` e `diagnostics()` `src/main.gd:620-631` (já expõe `gen_ms`, `mesh_ms`,
`triangles`, `tick`, `worst_sim_ms`, `dropped_ticks`, `journal`). Logs abertos por mim:
`.tools/af-clean-suite2.log:12` geração 939.3 ms / malharia 4.677,9 ms, `:292` `tick=359`,
`dropped_ticks=0`, `triangles=214480`, `:294` `219 checagens 0 falhas 35,4 s`;
`.tools/af-clean-suite.log:12` 935,1/4.749,9 ms com `:294` **4 falhas**; `.tools/clean_suite.log:12`
963,6/4.707,8 ms. Reconstruir o mundo uma segunda vez dentro da suíte custou 5.588,9 ms
(`.tools/af-clean-suite.log:25`).

Não existe: `af-bench` (aparece só como intenção em `docs/design/06-godot-architecture.md:199`),
`docs/engine/` (o diretório não existe; o arquivo `docs/engine/simclock.md` também não), tabela de
bake-off com dois braços, medição de custo "edição → malha pronta" e qualquer número de VRAM.

## 3. `af-bench --scenario boot_walk_10min`

10 min de simulação = 600 s ÷ `STEP = 1/20` s = **12 000 ticks** (`src/core/sim_clock.gd:5-6`). No
ritmo de parede sustentado pela suíte (359 ticks em 35,4 s, `.tools/af-clean-suite2.log:292,294`)
isso é ordem de 20 min de corrida × 3; derivado do código e do log, **não medido**.

API que o cenário usaria, sem inventar nada: `main.state_hash()` (`src/main.gd:671-672` →
`TickJournal.state_hash` `:16-44`), `clock.step_duration()` (`src/core/sim_clock.gd:42-43`),
`player.update_local(dt)` chamado pelo próprio runner em `dt` fixo (precedente real:
`tests/smoke_test.gd:103-109` e o porquê em `:235-244`), e `tick_journal.record()` com recusa de
arquivo existente (`src/persistence/tick_journal.gd:47-62`) e monotonicidade `last_tick + 1`
(`:69-73`) — o "sem buraco" vem de graça. Forma: runner `extends SceneTree` sob `tests/`, como os
três já existentes; `src/tools/` não existe.

Hoje o passo vem do `_physics_process` com `delta` real (`src/main.gd:155-161`) e o teto de 5
passos por frame zera o acumulador ao estourar (`src/core/sim_clock.gd:19-29`), ou seja: em modo
vivo o número de ticks e a sequência de estados dependem do relógio de parede — é exatamente isso
que o driver de `dt` fixo precisa remover. Por isso a checagem é o hash e não fps: fps é função da
máquina e de concorrentes (AGENTS.md: medição de tempo é serial, com a máquina livre), hash é
binário e independente de máquina. Consequência honesta: a projeção do hash **exclui** jogador,
corpos, RNG, episódios, relações, timers e comandos (`docs/design/08-roadmap-risks-licensing.md:46-48`),
então 3 hashes iguais provam determinismo **do que está na projeção**, não da simulação inteira.
Número publicado volta a ser hipótese se o código mudou depois da medição: re-medir em clone limpo
com `--import` (`AGENTS.md:381-383`).

## 4. Bake-off de voxel, com as abordagens que o código permite

O mesher de hoje é um `ArrayMesh` por chunk, face-culling + AO por vértice (`src/world/voxel_world.gd:2-4`),
vizinho respondido por cópia linear do mundo inteiro reconstruída uma vez por `generate()`
(`:123`, `:130-143`), fila com orçamento de 2 chunks por frame (`src/main.gd:18` → `:239-240`,
consumido em `src/world/voxel_world.gd:178-186`) e geometria só de cubo unitário (`:14-21`).
O precedente medido está no comentário de `:126-129` (dicionário de chunks ≈ 250 ms/chunk, boot
congelado ≈ 16 s) e no README: `~0,9 s de geração + ~4,3 s de malharia` dos 64 chunks, 214.480
triângulos, e a queda de ~16 s para ~7,5 s quando as consultas de vizinhança passaram a ler a
cópia linear (`README.md:559-566`; os logs locais dão 4.640–4.886 ms de malha,
`docs/melhorias-status.md:83`). Braços reais na mesa hoje:

| Braço | O que mudaria | Número que decide |
| --- | --- | --- |
| A — atual (cubo + face-culling + AO, cópia linear global) | referência | `mesh_ms` 4.677,9 ms · `triangles` 214.480 |
| B — greedy meshing (funde faces coplanares) no mesmo mesher | menos triângulos e menos bytes por chunk | `triangle_count()` `:207-217`, `mesh_ms` |
| C — halo vizinho por chunk em vez do `_flat` global | mata o `_rebuild_flat` (1 alloc de `128×64×128` bytes por `generate()`, `:131-142`) | `gen_ms`+`mesh_ms`, custo de edição |
| D — Voxel Tools (Zylann) por GDExtension | `[CLAIMED — medição pendente]`, nada vendorizado aqui (`docs/design/06:76-79`) | boot, disco, build multiplataforma |

O critério com pesos já está escrito (`docs/design/06:81-89`), mas duas colunas dele não têm
instrumento: "FPS com 50 mentes HOT" (não existem 50 mentes; `WOLF_COUNT = 5`, `src/main.gd:9`) e
"shapes não-cúbicos" (o mesher só emite cubo). "Custo de edição local" precisa de um carimbo de
tempo que hoje não existe: só há `last_mesh_ms()` do frame (`:189-194`). Não medir isso é o débito
de colheita que AGENTS.md já registra.

## 5. `docs/engine/simclock.md`

Seções derivadas de `src/core/sim_clock.gd`: (a) `HZ = 20`, `STEP = 1/20` s (`:5-6`); (b) acumulador
com teto de 5 passos/frame e `dropped_ticks += 1` com corte do acumulador, "nunca catch-up
silencioso" (`:17-29`); (c) cronômetro `begin_step`/`end_step` em µs com `worst_step_ms`
monotônico por reset (`:32-39`, `:46-47`); (d) cadências por subsistema montadas em cima do tick,
em `src/main.gd:18-22` (`AETHER_PERIOD 0,25`, `MESH_BUDGET 2`, `VIZ_PERIOD 0,25`, `RESPAWN_DELAY 45`, `CORPSE_CHECK_PERIOD 1,0`) e no corpo de
`_sim_tick` (`src/main.gd:229-259`); (e) o que **não** é autoridade: locomoção do jogador e do
lobo andam por frame (`src/main.gd:155-161`). Regra da casa: o `EntityStore` SoA que o design
descreve (`docs/design/06:46-63`) não existe — no doc entra marcado como `[TARGET]`, nunca no
indicativo; legenda em `docs/design/README.md:12-16`.

## 6. Gate de cada peça (comando existente + critério que pode falhar)

| Peça | Comando | Critério numérico |
| --- | --- | --- |
| doc | `godot --headless --path . --check-only --script src/core/sim_clock.gd` + `python .tools/verify_plan_cites.py docs/engine/simclock.md` | as 5 linhas-limite do §5 aparecem com `arquivo:linha` dentro do range; 0 asserção de existência sem linha correspondente |
| bench | 3 × `godot --headless --path . --script tests/<bench>.gd` com caminho novo por corrida | `records == 12000`, `dropped_ticks == 0`, hash da última linha idêntico nos 3 arquivos, exit 0 no runner |
| bake-off | suíte completa serial, 1 braço por corrida, 3 corridas cada | ≥ 2 braços com `gen_ms`, `mesh_ms`, `triangles` e custo de edição impressos; troca de mesher só se o braço novo ganhar por > 10% em `mesh_ms` somado ao custo de edição. Nenhum FPS prometido além da tabela (`docs/design/08:61-63`) |

Ordem: doc → harness/bench → bake-off, porque comparar braços exige o driver de `dt` fixo que o
bench introduz. Um hash estável em 3 execuções é condição do bake-off, não consequência.

## 7. Custo nas quatro perguntas

Roda por frame (o `advance` com `delta` real, `src/main.gd:155-161`) ou por tick (o corpo do
`_sim_tick`, 12 000 vezes por corrida de bench); alcança 5 lobos (`src/main.gd:9`), 64 chunks
(`src/world/voxel_config.gd:10-11`), 1 jogador. Aloca no caminho quente: `state_bytes()` devolve
cópia do `_cur` inteiro por registro (`src/world/aether_field.gd:233-234`, tamanho =
`Channel.COUNT` × `size_x·size_y·size_z`, `:9`, `:45-46`), com serialização + SHA256 + `flush` por
linha (`src/persistence/tick_journal.gd:74-87`) — **bytes por tick e µs do journal no cenário de
10 min não medidos**; a cadência de 0,25 s da difusão e o orçamento de 2 chunks/frame ficam
intocados. Sabemos que ficou melhor por log headless existente (`diagnostics()`), e o único custo
de journal já medido é histórico: 205 registros / 160.000 µs / pico 1.646 µs, antes deste plano.

## 8. Não fazer, commits, e citações que não conferem

Não: prometer FPS (`docs/design/08:62`), chamar o bench de replay (o journal é `[tick,hash]`
apêndice-only, `src/persistence/tick_journal.gd:69-87`), contar checagem sem conferir a última
linha (quatro checagens somem quando a premissa não existe, `docs/melhorias-status.md:560-564`),
escrever estado na mão para o cenário passar, vendorizar addon para "ganhar" o bake-off, ou fechar
gate de fase por este documento. Commits atômicos, um por linha da tabela do §6, suíte verde entre
eles: (1) `docs/engine/simclock.md`; (2) runner de `dt` fixo + hash, sem número publicado;
(3) `--scenario boot_walk_10min` com as 3 execuções e os 3 caminhos no log; (4) braço B/C do
bake-off com sua corrida; (5) tabela publicada + atualização do status (`docs/melhorias-status.md:489-493`).

Citações que não conferem (verificadas abrindo os arquivos):

- `docs/melhorias-status.md:491-492` fixa a "altura certa" do boot em geração **942 ms** e malha
  **4.682 ms**. Nenhuma corrida publicada devolve esse par: a tabela do próprio status dá
  936,0/944,5/952,3/961,9 ms com malha 4640,6/4847,6/4885,8/4724,2 ms (`docs/melhorias-status.md:1357`) e 929,7/967,7/
  932,9 com 4684,0/4661,6/4675,9 (`docs/melhorias-status.md:1359`); o clone limpo re-medido dá 926,4 / 4.134,9 ms
  (`docs/melhorias-status.md:958`). O par de `:492` é arredondamento de uma corrida que não está nomeada ali — e contra o
  número de `docs/melhorias-status.md:958` ele está velho em 3,9% na geração e 13% na malha.
- `README.md:561` diz `~4,3 s de malharia` contra 4,64–4,89 s nas quatro corridas de `docs/melhorias-status.md:1357` e
  4.134,9 ms no clone re-medido.
- `docs/design/06:33` aponta `src/core/sim/tick_clock.gd` (caminho inexistente — o arquivo real é
  `src/core/sim_clock.gd`) e `:200` aponta `src/tools/` (diretório inexistente).
- `docs/design/08:56` lista `EntityStore SoA` como entrega de P0 sem código correspondente.
- O comentário-modelo que `AGENTS.md` item 7 cita (`tests/smoke_test.gd:237-245`) está certo: o
  bloco real vai de `:213` a `:223`, e a proibição do passo em série — que trava este censo — está
  em `:220-223`, dentro da faixa citada. O que falta ao contrato é citar `:220-223` pelo nome.
- As citações de `AGENTS.md` às constantes de `src/main.gd` estão certas (`:12` difusão, `:13`
  malha, `:14` visão, `:16` cadáveres); a alegação de deslocamento em +1 foi deste briefing e o
  código a refuta. `WOLF_COUNT` está em `:9`, `SEED` em `:10`, `SLOT` em `:11`.
- A contagem publicada é **236 checagens / 0 falhas / 37,1 s** no clone limpo de `9f3622b`
  (`docs/melhorias-status.md:1466` e a nota em `:1437-1518`). As ocorrências antigas de 232 —
  `docs/design/08-roadmap-risks-licensing.md:44-45` (que agora diz os dois números) e quatro linhas
  do status de antes (91, 249, 665, 702) — são da rodada do `a8967e0` e continuam corretas porque mediram aquele clone.
  Os logs que eu abri aqui são os locais de `.tools/` e dão 219 (um com 4 falhas) — contagem
  anterior ao refinamento. Este plano não re-mediu nada: a engine não foi rodada.
