# 02 — Censo do lobo em 20 sementes × 1000 ticks

Plano derivado de leitura; nada foi rodado por mim. Cobre o item 3 de "Falta" (`docs/melhorias-status.md:540-541`) e a linha do P1 (`:706`), cujo gate escrito é "cenário … passa em 20 sementes × 1000 ticks com hash igual" (`docs/design/08-roadmap-risks-licensing.md:72-74`). O item 3 pressupõe 1 (concluído, `docs/melhorias-status.md:526-528`) e 2 (não iniciado, `:529-539`). Marcas por `docs/design/README.md:10-16`. Nenhum gate de fase se fecha aqui (`docs/design/08-roadmap-risks-licensing.md:36`: "sem nenhum gate fechado").

## Premissa nomeada: cadência sintética, não relógio de parede
A igualde do hash 1000 ticks à frente é função de uma só coisa: a mesma sequência de passos. O passo autoritativo é `_sim_tick()` com `dt = clock.step_duration()` e cadências internas por contadores decrementados em `dt` (`src/main.gd:316-350`), mais K chamadas de `_physics_process` por tick para corpo e timers (`tests/aether_reactions_test.gd:379-381` faz K = 3). Fora disso, nada do relógio de parede entra: o passo de contrato chama `_sim_tick()` direto com `process_mode` desligado (`tests/tick_journal_test.gd:357-366`), a percepção é voxel pura — `line_of_sight` → `ray_voxel` (`src/world/voxel_world.gd:478-484`), consultada em `src/entities/wolf.gd:934` — e os sorteios do caminho de tick são por dono (`src/entities/wolf.gd:215`, `:664`, `:681-682`, `:1252-1253`; população em `src/main.gd:809-810`). A checagem nomeia a premissa imprimindo K, `dt`, o primeiro tick divergente e o número de hashes distintos por corrida.

## Estado real do código
Hoje: uma semente em cada harness (`tests/smoke_test.gd:10`, `tests/aether_reactions_test.gd:4`) e uma determinística de relevo duplicado (`tests/smoke_test.gd:436`, comparação `:441-446`) mais a de triângulos (`:447`); não há harness multi-semente em `tests/` (`docs/melhorias-status.md:540-541`). O hash existe e é função do tick: `TickJournal.state_hash(tick, world, field, roster)` é `static` e cobre `FORMAT_VERSION`, `world.gen.world_seed`, `GEN_VERSION`, dimensões, edições ordenadas, mentes por identidade e crenças ordenadas, mais os bytes integrais dos canais (`src/persistence/tick_journal.gd:16-44`; `GEN_VERSION` = 4 em `src/world/world_gen.gd:6`). `record()` só funciona com journal aberto e recusa tick não-consecutivo (`:69-87`); `start()` recusa caminho existente (`:50-51`). O que a projeção **não** contém: jogador, corpos, stream de RNG, episódios, relações, timers, fila de respawn (`docs/melhorias-status.md:1315-1316`) — mas corpos entram de rebote, porque `_sense()` e `_find_scent()` leem `center()` (`src/entities/wolf.gd:929`, `:977`). `main.gd` não aceita semente por linha de comando: `SEED` é `const` (`src/main.gd:25`), usado em `world.generate(SEED)` no `_ready` (`:150`) e no load (`:1116`), e `_start_journal_from_args()` só lê `--tick-journal=` (`:1315-1324`). `[MEASURED]` da suíte: 232 checagens / 0 falhas / 33,7 s, `gen_ms` 926,4, `mesh_ms` 4134,9 (`docs/evidence/third-person-carry/clone-suite.log:305`).

## O censo proposto
Runner próprio `tests/wolf_multiseed_census_test.gd`, formato do que existe (`extends SceneTree`, lista `TESTS`, `_check`, `EXPECTED_CHECKS` travada, `quit(1)` — `tests/tick_journal_test.gd:1-13`, `:480-486`), fixture como a do lobo (`tests/aether_reactions_test.gd:345-377`: mundo, 2025 colunas secas, `meshes_built() == 0`, jogador a 73,6 m de SPAWN para manter LOS falsa — `:7`, `:364`), 5 lobos por semente com o par de derivações de `src/main.gd:809-810`, K fixo por tick, hash por tick chamado **direto** do `state_hash` estático, comparação em memória. 20 sementes × 1000 ticks × 2 corridas = 40.000 passos.
**Igual por construção** (não se gateia, só não pode colidir): `FORMAT_VERSION`, `world_seed`, `GEN_VERSION`, dimensões, `Channel.COUNT` (`src/persistence/tick_journal.gd:36-38`) e `edits` vazio (nada lava no censo) — por isso duas sementes distintas já dão hashes distintos no tick 0.
**Livre e esperado divergir entre sementes** (imprime, não gateia por igualdade): sequência de `intent`, crenças e suas confianças, energia do Éter, lobos vivos. O gate é repetição **por semente**, nunca igualdade **entre sementes**.
**Custo de parede** `[DERIVADO]` de números lidos: 2005 µs/passo com journal ligado (12030 µs / 6 passos, `docs/evidence/aether-reactions/candidate-contract.log:127`) ⇒ 80,2 s; sem hash em disco, 1257 µs/passo ((12030 − 4488) / 6) ⇒ 50,3 s; 40 gerações de mundo a 926,4 ms ⇒ 37,1 s. Total 87–117 s, serial, contra 33,7 s da suíte. A rota por cena (`main.tscn` por semente) custaria ~202 s só de boot (40 × (926,4 + 4134,9) ms), porque `generate_meshes_all()` está no `_ready` (`src/main.gd:155`) e não há como pular sem mudança de código: rejeitada.

## Gate de fechamento
Comandos que já existem (`AGENTS.md`, "Comandos de medição"; `--script` resolve por caminho, `docs/melhorias-status.md:849-850`):

```sh
godot --headless --path . --import
godot --headless --path . --check-only --script tests/wolf_multiseed_census_test.gd
godot --headless --path . --script tests/wolf_multiseed_census_test.gd
godot --headless --path . --script tests/tick_journal_test.gd   # regressao, 128 / 0
```

Critério numérico, com as checagens **inexistentes** hoje e a primeira tarefa sendo escrevê-las: `repeticao_por_semente` — 20/20 sementes com `divergencia_primeiro = -1` e `ticks_conferidos = 1000`; `hash_varia_dentro_da_corrida` — `hashes_distintos >= 2` por semente (prova que a projeção está viva); `sementes_distintas` — 19/19 pares com hash do tick 1000 diferentes (prova que a semente chega à projeção); `contraste_de_cadencia` — mesma semente com K = 1 vs K = 3 deve **divergir** (`divergencia_primeiro >= 0` impresso): se der 0 divergências, a checagem de igualdade é vazia e o item 3 não fecha; `contagem_travada` — `EXPECTED_CHECKS` no código, porque o smoke imprime sem exigir (`tests/smoke_test.gd:265`) e o censo já caiu de 220 para 216 sem nenhum vermelho (`docs/melhorias-status.md:816-820`). Saída com código 0 e a última linha `N checagens 0 falhas ... s`. `dropped_ticks` não se aplica ao passo sintético: quem o produz é `clock.advance(delta)` (`src/core/sim_clock.gd`, usado em `src/main.gd:309`), que não roda aqui — não registrar isso como métrica verde.

## Custo — as quatro perguntas (`AGENTS.md`)
1. Por frame, por tick, às vezes? O censo roda 1× por passo sintético: 1000 × 20 × 2 = 40.000 execuções de `sim_step` por lobo, K × 40.000 de `_physics_process`; difusão 1 a cada 5 passos (`AETHER_PERIOD` 0,25 s em `src/main.gd:27`, `:298-301`); geração 40 vezes, uma por corrida.
2. Quantas entidades? 5 lobos (`src/main.gd:9`), 1 jogador estático fora de LOS, 64 chunks, campo 32 × 16 × 32 × 3 canais varrido por hash.
3. Aloco no caminho quente? Sim: 196.608 bytes/tick de cópia Float32 (`src/world/aether_field.gd:233-234`, tamanho conferido no contrato), blackboard novo por lobo por tick (`src/entities/wolf.gd:923`), `keys()` por varredura de rastro (`:974-976`), um `PackedInt32Array` por canal na difusão (`src/world/aether_field.gd:122`). Com hash em memória, o `Array[String]` de 40.000 hex-string (~2,8 MB) é alocação do teste, não do jogo; em disco seriam 40.000 linhas × 71 bytes (426 / 6, `docs/evidence/aether-reactions/candidate-contract.log:127`). Alocação total medida: **não medida** (débito em `docs/melhorias-status.md:1007-1014`).
4. Como sei que ficou melhor? Não é otimização: é cobertura. Os números novos são `ticks_conferidos`, `divergencia_primeiro`, `hashes_distintos`, K e o tempo de parede da corrida, em máquina livre e serial; número publicado re-medido no clone limpo do SHA final com `--import`.

## O que NÃO fazer
Não chamar o censo de replay: a projeção exclui jogador, corpos, RNG e comandos (`docs/melhorias-status.md:1315-1316`) e o item 2 não existe. Não gatear igualdade entre sementes. Não encaixar o censo dentro do smoke: o passo em série já matou o jogador parado e derrubou as seções seguintes com 32 falhas em cascata (`tests/smoke_test.gd:370-373`) e o tempo iria a ~4×. Não escrever crença nem intenção à mão para fabricar divergência — usar o imprint de sangue da fonte (`tests/aether_reactions_test.gd:6`) e o passo. Não presumir `af-bench` (`docs/design/08:61-63`), `MindsInspector` (`:82`), 6 canais, `HotSet` nem inspector de mentes. Não somar picos de instantes distintos para declarar o budget de 2,5 ms cumprido (`docs/melhorias-status.md:870-873`). Não reabrir caminho de journal existente (`src/persistence/tick_journal.gd:50-51`).

## Checklist de commits atômicos (cada um com corrida própria)
1. Runner com fixture e uma semente × 50 passos, `EXPECTED_CHECKS` travada, imprime K, `dt`, `hashes_distintos` — sem gate.
2. Non-vacuidade: `hash_varia_dentro_da_corrida` e `sementes_distintas` sobre 20 sementes × 100 passos, com tempo de parede impresso.
3. `contraste_de_cadencia` K = 1 vs K = 3, com o primeiro tick divergente impresso — o braço vermelho obrigatório.
4. Escala final 20 × 1000 × 2, journal em disco opcional com caminho novo por corrida e manifest de evidência (`docs/evidence/` no formato dos blocos anteriores).
5. Atualizar `docs/melhorias-status.md` (item 3, furos de contagem, notas de medição), re-derive as citações velhas, re-medir no clone limpo com `--import` e pinar o SHA.

## Citações que não conferem
- `AGENTS.md` item 7 e "duas cadências" citam `player.gd:659` e `:675` para lavra e colocação: as
  duas linhas são o cabeçalho das funções (`func _mine_target()` e `func _try_place()`); o
  `world.set_block` que escreve no mundo está em `src/entities/player.gd:667` e `:693`. Citação
  desalinhada em 8 e 18 linhas, não invenção — mas quem for corrigir o voxel não é pego por ela.
  Números do parágrafo são registro da leitura da perna 02, não ponteiro vivo: a re-derivação da
  perna 19 moveu o texto vivo de `AGENTS.md`, e esta linha diz o que se leu então.
- Achei e fechei nesta ponta: a linha que chama a checagem determinística de "uma só" é a 50 da tabela de prompts do status, e a faixa real do smoke é `tests/smoke_test.gd:436-446` — linha e faixa foram re-ancoradas neste bloco, cada uma na sua própria linha.
- Achei e fechei nesta ponta: `AGENTS.md` dá como modelo de comentário `tests/smoke_test.gd:365-375`, faixa que contém o bloco inteiro e também a frase que proíbe o passo em série — a que trava este censo.
- O briefing deste plano dizia que o `TickJournal` "expõe `state_hash()` por tick": a frase é
  verdadeira no conteúdo e imprecisa na forma — `state_hash(tick, world, field, roster)` é
  `static` (`src/persistence/tick_journal.gd:16`) e recebe o tick como argumento, mas quem o
  carimba em disco é `record()` (`:69-87`), ativo só com journal aberto. O censo pode chamar o
  `static` direto; quem chama na gameplay é `main.state_hash()` (`src/main.gd:1317`).
- O briefing dizia "a única checagem determinística conhecida compara 16 colunas geradas duas vezes": existe a segunda comparação das mesmas 16 colunas após load (`tests/smoke_test.gd:3400-3404`).
