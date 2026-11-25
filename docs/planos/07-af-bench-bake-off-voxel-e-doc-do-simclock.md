# 07 — `af-bench` de 10 min, bake-off de voxel e o doc do `SimClock`

Alvo: as três linhas do checklist P0 em `docs/melhorias-status.md:818-825` que este dossiê mirava. São P0,
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
em `tests/smoke_test.gd:221-224`, exit 1 se `M > 0`), os runners `extends SceneTree`
`tests/simulation_rng_test.gd:1`, `tests/tick_journal_test.gd:1`, `tests/aether_reactions_test.gd:1`,
o primitivo de hash `src/persistence/tick_journal.gd:16-44`, o CLI `--tick-journal=`
`src/main.gd:1286-1293` e `diagnostics()` `src/main.gd:1204-1239` (já expõe `gen_ms`, `mesh_ms`,
`triangles`, `tick`, `worst_sim_ms`, `dropped_ticks`, `journal`). Logs abertos por mim:
`.tools/af-clean-suite2.log:12` geração 939.3 ms / malharia 4.677,9 ms, `:292` `tick=359`,
`dropped_ticks=0`, `triangles=214480`, `:294` `219 checagens 0 falhas 35,4 s`;
`.tools/af-clean-suite.log:12` 935,1/4.749,9 ms com `:294` **4 falhas**; `.tools/clean_suite.log:12`
963,6/4.707,8 ms. Reconstruir o mundo uma segunda vez dentro da suíte custou 5.588,9 ms
(`.tools/af-clean-suite.log:25`).

Não existia quando a pauta foi escrita: `af-bench` (só como intenção em
`docs/design/06-godot-architecture.md:199`), `docs/engine/`, tabela de bake-off com dois braços e custo
"edição → malha pronta". Pousaram as três: 07a `779d19b`, 07b merge `35959e0`, 07c aqui. VRAM segue sem número.

## 3. `af-bench --scenario boot_walk_10min`

10 min de simulação = 600 s ÷ `STEP = 1/20` s = **12 000 ticks** (`src/core/sim_clock.gd:5-6`). No
ritmo de parede sustentado pela suíte (359 ticks em 35,4 s, `.tools/af-clean-suite2.log:292,294`)
isso é ordem de 20 min de corrida × 3; derivado do código e do log, **não medido**.

API que o cenário usaria, sem inventar nada: `main.state_hash()` (`src/main.gd:1282-1283` →
`TickJournal.state_hash` `:16-44`), `clock.step_duration()` (`src/core/sim_clock.gd:42-43`),
`player.update_local(dt)` chamado pelo próprio runner em `dt` fixo (precedente real:
`tests/smoke_test.gd:128-134` e o porquê em `:245-254`), e `tick_journal.record()` com recusa de
arquivo existente (`src/persistence/tick_journal.gd:47-62`) e monotonicidade `last_tick + 1`
(`:69-73`) — o "sem buraco" vem de graça. Forma: runner `extends SceneTree` sob `tests/`, como os
três já existentes; `src/tools/` não existe.

Hoje o passo vem do `_physics_process` com `delta` real (`src/main.gd:281-287`) e o teto de 5
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
(`:132`, `:139-152`), fila com orçamento de 2 chunks por frame (`src/main.gd:28` → `:314-315`,
consumido em `src/world/voxel_world.gd:204-212`) e geometria só de cubo unitário (`:14-21`).
O precedente medido está no comentário de `:135-138` (dicionário de chunks ≈ 250 ms/chunk, boot
congelado ≈ 16 s) e no README: `~0,9 s de geração + ~4,3 s de malharia` dos 64 chunks, 214.480
triângulos, e a queda de ~16 s para ~7,5 s quando as consultas de vizinhança passaram a ler a
cópia linear (`README.md:642-647`; os logs locais dão 4.640–4.886 ms de malha,
`docs/melhorias-status.md:83`). A mesa foi corrida, serial, três execuções por braço, na árvore do pin (`docs/evidence/af-bakeoff-voxel/`):

| Braço | O que mudaria | Número que decide | O que a mesa devolveu |
| --- | --- | --- | --- |
| A — atual (cubo + face-culling + AO, cópia linear global) | referência da mesa | `gen_ms` 943,77 · `mesh_ms` 4.300,12 · `triangles` 214.448 no boot · 52 remeshes × 77.561,5 µs | **referência com número** (`run-A-1..3`, exit 0, 11 checagens 0 falhas): métrica `mesh_ms + 52·mean_us` = 8.333,32 ms. O `mesh_ms` 4.677,9 que esta linha trazia era `.tools/af-clean-suite2.log:12` de antes das pernas 16 e 19; o `214.480` é o diagnóstico final da suíte, 13 edições e 32 triângulos depois do boot |
| B — greedy meshing (funde faces coplanares) no mesmo mesher | menos triângulos e menos bytes por chunk | `triangle_count()` `:221-231`, `mesh_ms` | `[OPEN]` — reabre quando a métrica `mesh_ms + 52·mean_us` cair a ≤ **7.500,0 ms** (0,9 × A) em três corridas, o que pede `mesh_ms` ≤ 3.870,1 ms com o custo de edição no lugar. Aí `triangles` deixa de ser invariante e o `REF_TRIANGLES := 214448` do runner vira literal novo |
| C — halo vizinho por chunk em vez do `_flat` global | mata o `_rebuild_flat` (1 alloc de `128×64×128` = 1.048.576 bytes por `generate()`, `:139-152`) | `gen_ms`+`mesh_ms`, custo de edição | **medido e perdido** (`run-C-1..3`): ganha `gen_ms` −7,75 % (casaco `18×66×18` = 21.384 bytes, 1/49 das do `_flat`) e perde `mesh_ms` +16,23 %, custo de edição +19,94 % em média (pico +31,75 %), `worst_sim_ms` +7,0 %, métrica +18,02 %. Vive só no patch `docs/evidence/af-bakeoff-voxel/arm-c-halo-por-chunk.patch` (base `e486cd3`, branch local `8d9dc97`): nada de halo em `src/` |
| D — Voxel Tools (Zylann) por GDExtension | `[CLAIMED — medição pendente]`, nada vendorizado aqui (`docs/design/06:76-79`) | boot, disco, build multiplataforma | não corrido nesta mesa — continua `[CLAIMED — medição pendente]` |

O critério com pesos (`docs/design/06:81-89`) tinha uma coluna sem instrumento; hoje ela tem número: o custo
de edição local é carimbo aberto em `_mark` (`src/world/voxel_world.gd:306-318`), fechado no fim da malha
(`:312-319`) e lido por `edit_mesh_cost()` (`:326-335`) → `diagnostics()["edit_mesh"]` (`src/main.gd:1221`).
O agregado cobra chunks carimbados: `apply_edits` (`:178-189`) no boot cai em `mesh_ms`, e `last_mesh_ms()`
(`:207-208`) é lote do frame. Sem instrumento seguem "FPS com 50 mentes HOT" e "shapes não-cúbicos".

## 5. `docs/engine/simclock.md`

Seções derivadas de `src/core/sim_clock.gd`: (a) `HZ = 20`, `STEP = 1/20` s (`:5-6`); (b) acumulador
com teto de 5 passos/frame e `dropped_ticks += 1` com corte do acumulador, "nunca catch-up
silencioso" (`:17-29`); (c) cronômetro `begin_step`/`end_step` em µs com `worst_step_ms`
monotônico por reset (`:32-39`, `:46-47`); (d) cadências por subsistema montadas em cima do tick,
em `src/main.gd:27-31` (`AETHER_PERIOD 0,25`, `MESH_BUDGET 2`, `VIZ_PERIOD 0,25`, `RESPAWN_DELAY 45`, `CORPSE_CHECK_PERIOD 1,0`) e no corpo de
`_sim_tick` (`src/main.gd:290-332`); (e) o que **não** é autoridade: locomoção do jogador e do
lobo andam por frame (`src/main.gd:281-287`). Regra da casa: o `EntityStore` SoA que o design
descreve (`docs/design/06:46-63`) não existe — no doc entra marcado como `[TARGET]`, nunca no
indicativo; legenda em `docs/design/README.md:12-16`.

## 6. Gate de cada peça (comando existente + critério que pode falhar)

| Peça | Comando | Critério numérico |
| --- | --- | --- |
| doc | `godot --headless --path . --check-only --script src/core/sim_clock.gd` + `python .tools/verify_plan_cites.py docs/engine/simclock.md` | as 5 linhas-limite do §5 aparecem com `arquivo:linha` dentro do range; 0 asserção de existência sem linha correspondente |
| bench | 3 × `godot --headless --path . --script tests/<bench>.gd` com caminho novo por corrida | `records == 12000`, `dropped_ticks == 0`, hash da última linha idêntico nos 3 arquivos, exit 0 no runner |
| bake-off | suíte completa serial, 1 braço por corrida, 3 corridas cada | ≥ 2 braços com `gen_ms`, `mesh_ms`, `triangles` e custo de edição impressos; troca de mesher só se o braço novo ganhar por > 10% em `mesh_ms` somado ao custo de edição. **Corrido**: `mesh_ms + 52·mean_us` deu A 8.333,32 ms × C 9.835,24 ms (+18,02 %), sem as distribuições se tocarem (pior A 8.458,5 ms, melhor C 9.696,4 ms) — A continua o default e C vive só no patch. B reabre com ≤ 7.500,0 ms na mesma métrica. Nenhum FPS prometido além da tabela (`docs/design/08:61-63`) |

Ordem: doc → harness/bench → bake-off, porque comparar braços exige o driver de `dt` fixo que o
bench introduz. Um hash estável em 3 execuções é condição do bake-off, não consequência.

## 7. Custo nas quatro perguntas

Roda por frame (o `advance` com `delta` real, `src/main.gd:281-287`, o `advance` em `:262`) ou por
tick (o corpo do `_sim_tick`, 12 000 vezes por corrida de bench); alcança 5 lobos (`src/main.gd:9`),
64 chunks
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
linha (quatro checagens somem quando a premissa não existe, `docs/melhorias-status.md:756-760`),
escrever estado na mão para o cenário passar, vendorizar addon para "ganhar" o bake-off, ou fechar
gate de fase por este documento. Commits atômicos, um por linha da tabela do §6, suíte verde entre
eles: (1) `docs/engine/simclock.md`; (2) runner de `dt` fixo + hash, sem número publicado;
(3) `--scenario boot_walk_10min` com as 3 execuções e os 3 caminhos no log; (4) braço B/C do
bake-off com sua corrida; (5) tabela publicada + atualização do status (`docs/melhorias-status.md:818-825`).

Citações que não conferem (verificadas abrindo os arquivos):

- `docs/melhorias-status.md:682-683` fixava a "altura certa" do boot em geração **942 ms** e malha
  **4.682 ms**. Nenhuma corrida publicada devolve esse par: a tabela do próprio status dá
  936,0/944,5/952,3/961,9 ms com malha 4640,6/4847,6/4885,8/4724,2 ms (`docs/melhorias-status.md:2051`) e 929,7/967,7/
  932,9 com 4684,0/4661,6/4675,9 (`docs/melhorias-status.md:2053`); o clone limpo re-medido dá 926,4 / 4.134,9 ms
  (`docs/melhorias-status.md:1652`). O par de `:626` é arredondamento de uma corrida que não está nomeada ali — e contra o
  número de `docs/melhorias-status.md:1652` ele está velho em 1,7% na geração e 13% na malha.
  Os quatro ponteiros deste item estavam **fora de posição já em `f843fa6`** (o par de corrida em `:1429`/`:1431`,
  o clone em `:1030`, a altura em `:554` — 63 a 72 linhas antes do lugar certo) e a reancoragem é por
  conteúdo lido, não por translação: quem reancora somando o deslocamento do diff leva a podridão adiante
  com aparência de atualizado.
  **O que mudou desde que esta pauta foi escrita** (re-derivado por conteúdo na árvore da perna 12, e não
  por translação): os três números acima foram para `:2042`, `:2044` e `:1643` e continuam os mesmos
  números; já o par de `:678-679` e o de `:622` **não têm mais alvo** — as duas posições caem hoje sobre a
  reacção do vizinho e sobre o `wolf.gd:215`, e a linha que afirmava a altura certa foi **retratada** pelo
  status na própria linha P0 (`docs/melhorias-status.md:833`: "o par '942 ms / 4682 ms' que esta linha
  afirmava como altura certa nunca teve corrida publicada que o sustentasse"), que é o fecho deste item.
  Ficam escritos como estavam porque é a posição que a pauta auditou, e reancorá-los exigiria um alvo que a
  afirmação já não tem. Os dois ponteiros órfãos são a classe do **furo #28** com testemunha: a régua de
  âncoras vê `:1309` cair em linha branca e não vê `:678-679` cair noutra linha qualquer.
- `README.md:642` diz `~4,3 s de malharia` contra 4,64–4,89 s nas quatro corridas de `docs/melhorias-status.md:1754` e
  4.134,9 ms no clone re-medido.
- `docs/design/06:33` aponta `src/core/sim/tick_clock.gd` (caminho inexistente — o arquivo real é
  `src/core/sim_clock.gd`) e `:200` aponta `src/tools/` (diretório inexistente).
- `docs/design/08:56` lista `EntityStore SoA` como entrega de P0 sem código correspondente.
- O comentário-modelo que `AGENTS.md` item 7 cita (`tests/smoke_test.gd:281-289`) está certo: o
  bloco real vai de `:213` a `:223`, e a proibição do passo em série — que trava este censo — está
  em `:220-223`, dentro da faixa citada. O que falta ao contrato é citar `:220-223` pelo nome.
- As citações de `AGENTS.md` às constantes de `src/main.gd` estão certas (`:12` difusão, `:13`
  malha, `:14` visão, `:16` cadáveres); a alegação de deslocamento em +1 foi deste briefing e o
  código a refuta. `WOLF_COUNT` está em `:9`, `SEED` em `:10`, `SLOT` em `:11`.
- A contagem publicada é **236 checagens / 0 falhas / 37,1 s** no clone limpo de `9f3622b`
  (`docs/melhorias-status.md:1981` e a nota em `:1903-1906`). As ocorrências antigas de 232 —
  `docs/design/08-roadmap-risks-licensing.md:44-45` (que agora diz os dois números) e quatro linhas
  do status de antes (91, 249, 665, 702) — são da rodada do `a8967e0` e continuam corretas porque mediram aquele clone.
  Os logs que eu abri aqui são os locais de `.tools/` e dão 219 (um com 4 falhas) — contagem
  anterior ao refinamento. Este plano não re-mediu nada: a engine não foi rodada.
