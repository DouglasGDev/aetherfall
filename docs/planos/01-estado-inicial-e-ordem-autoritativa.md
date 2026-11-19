# 01 — Estado inicial completo, comandos, RNG e ordem autoritativa

Plano derivado de leitura; nada foi rodado por mim. Cobre o item 2 de "Falta" (`docs/melhorias-status.md:262-271`) e a linha não marcada do P0 (`:299`), cujo débito declarado é "não foi iniciado" (`:252-253`). A frase do P0 **não** está em `docs/design/08`, cujo gate (`:61-63`) é `af-bench --scenario boot_walk_10min` — peça que não existe em `src/` nem em `tests/`. Marcas por `docs/design/README.md:10-16`: `[MEASURED]` lido, `[TARGET]`/`[OPEN]` inexistente.

## Premissa nomeada: diário com duas portas

O journal grava `[tick, hash]` de uma projeção mínima e recusa tick não-consecutivo (`src/persistence/tick_journal.gd:69-87`, regra em `:72-73`), mas quem escreve no mundo não vive no tick: o jogador lava, coloca e imprime dentro de `_physics_process` (`src/main.gd:136-142` → `src/entities/player.gd:354-380`, com `world.set_block` em `src/entities/player.gd:667` e `:693`), e corpos e timers dos lobos andam por frame (`src/entities/wolf.gd:501-546`). O hash do tick N não é função só do que o tick N aplicou: é função de quantos frames caberam entre N−1 e N, e isso `SimClock.advance` decide pelo `delta` de parede (`src/core/sim_clock.gd:19-29`). Nomear a segunda porta é o plano: sem ela, hash por tick é testemunha do acaso, não replay.

## Estado real do código

| Quem escreve | Onde | Quando | Na projeção hoje |
| --- | --- | --- | --- |
| edição de voxel | `src/entities/player.gd:667`, `:693` | frame | sim, ordenada (`tick_journal.gd:17-21`) |
| imprint de trabalho, sangue e medo | `src/main.gd:268-273`, `:306-313`, `:192` | frame / tecla | só os bytes finais (`aether_field.gd:218-219`) |
| corpo, `_stagger`, `_unstick`, `_corpse_timer` | `src/entities/wolf.gd:501-546` | frame | **não** |
| sorteios do lobo | `src/entities/wolf.gd:538-539`, `:301-304` | misto | **não** |
| BT, intenção, crenças | `src/entities/wolf.gd:408-433` | tick | sim (`tick_journal.gd:22-35`) |
| difusão, cadáveres e fila de respawn | `src/main.gd:148-163`, `:37` | tick (4/s, 1/s) | só o campo, não a fila |
| jogador `hp`, inventário, feet, yaw/pitch | `src/main.gd:357-362` | frame | **não** |
Fora também episódios, relações e personalidade (`src/ai/mind.gd:14-22`), `elapsed` e cadências (`src/main.gd:30,38-40`), `_next_identity` (`:35`) e `_checked_scents` (`src/entities/wolf.gd:82`). Dono único hoje é `main.gd`, 501 linhas e a matilha como `var wolves: Array` (`:29`) mais as portas `targets_under_crosshair()` (`:245-250`) e `wolves_roster()` (`:253-254`). Os nomes `src/session/`, `wolf_roster.gd` e `scene_readiness.gd` vieram do briefing desta sessão e não existem em `src/` nem em `docs/design/` — registrados aqui só para não voltarem como peça esperada. `[MEASURED]` do log lido (`docs/evidence/third-person-carry/clone-suite.log:303-307`): 232 checagens / 0 falhas / 33,7 s, `tick=359`, `dropped_ticks=0`, `worst_sim_ms=6,779`, `edits=13`, `meshes=147`, 5 lobos no boot (`src/main.gd:9`) e 4 vivos no fim (log `:300`), `journal.records=0` — a suíte roda sem `--tick-journal`.

## O que o plano exige

### Estado inicial completo `[TARGET]`
Quase existe: `save_game()` (`src/main.gd:341-364`) grava `schema` (`src/persistence/save_manager.gd:8` = 1), `gen_version` (`src/world/world_gen.gd:6` = 4), `seed`, `tick`, `elapsed`, `stats`, `edits`, Éter, inventário, jogador e o `state_dict()` por lobo (`src/entities/wolf.gd:641-646`). Estado inicial = isso mais os bytes integrais do campo (o save corta ≤ 0,01 em `aether_field.gd:199-202`, o hash usa tudo — comentário em `:217`), os timers por frame da tabela, os geradores, a fila e `_next_identity`. Armadilha lida: `VoxelWorld.generate()` **não** limpa `edits` (`src/world/voxel_world.gd:108-124`; só `apply_edits` limpa, `:164-172`) — restaurar passa por lá, como já faz `load_game` (`src/main.gd:384-388`); `_benches` (`src/main.gd:46`) é derivado do mundo (`:421-425`) e entra como derivado, não como arquivo.

### Comandos/input `[TARGET]`
Não há captura: só o efeito já escrito. Gravar tecla não reproduz — medido no harness, `Input.parse_input_event` chega 6 a 7 iterações depois (`tests/smoke_test.gd:140-144`) e a janela real deu 163 quadros/s contra 59,8 ticks (`:118-121`). O que tem posição reproduzível é a intenção aplicada, que já passa por handlers com evento e relógio à vista (`src/main.gd:268-321`); vocabulário nomeado existe (`src/input/input_actions.gd:18-54`). Fita: `[tick_do_relogio, seq, tipo, args]` com as regras já cobradas de `record()` (negativo, duplicata, regressão, salto — `tick_journal.gd:72-73`). `start()` não escreve cabeçalho (`tests/tick_journal_test.gd:291`) e o leitor exige aridade 2 (`:431-432`): `FORMAT_VERSION` (`tick_journal.gd:4`) mora só dentro do hash, então v2 é indistinguível de v1 para quem lê e nenhuma checagem exige que ele altere o hash. Cabeçalho lateral é pré-requisito da fita.

### RNG no estado `[TARGET]` + `[OPEN]`
Sementes derivadas já provadas: população (`src/main.gd:200-201`, uso em `:221-222`), lobo (`src/entities/wolf.gd:120`), personalidade por semente (`src/ai/mind.gd:24-32`). Falta a **posição do fluxo**, que não é função do tick: dois dos três sorteios do lobo são em `_physics_process` (`src/entities/wolf.gd:538-539`). `[OPEN]`: qual propriedade do engine faz o fluxo ir e voltar — não há snapshot de gerador em `src/` (grep de `state` sobre `rng` não devolve uso). Sem isso, o caminho sem API nova é gravar por dono o contador de sorteios, número que a suíte de reações já imprime (`frames_bloqueados=679 desvios=22`, `docs/melhorias-status.md:784-786`). Débito lido: `load_state()` não re-semeia (`src/entities/wolf.gd:649-680`). Quarto dono fica fora por motivo medido: o `_rng` do áudio (`src/audio/audio_director.gd:117,140`, sorteios em `:521,529`) não escreve no mundo — grep de `aether`/`imprint` no arquivo devolve 0 ocorrências.

### Ordem autoritativa `[TARGET]` + `[OPEN]`
A regra-alvo está escrita (`docs/design/06-godot-architecture.md:34-38`, que ainda cita `src/core/sim/tick_clock.gd`, caminho inexistente; o real é `src/core/sim_clock.gd`) e o código não obedece: a ordem real é jogador-primeiro, passos-depois (`src/main.gd:136-142`), hash no fim do passo, depois de `clock.tick += 1` (`:164-166`). Decisão `[OPEN]` do dono, dois braços. **A (menor diff)**: a fita carimba o evento com o tick vigente e o passo ganha fases nomeadas — (1) eventos com carimbo ≤ N, (2) cadências, (3) `sim_step` dos lobos, (4) `clock.tick += 1`, (5) hash/registro; exige trazer corpos e timers para a projeção, porque `_sense()` lê a posição do corpo (`src/entities/wolf.gd:435-441`) e isso contamina intenção e crença. **B (autoridade única)**: mover locomoção e timers para o passo com K sub-passos fixos, como o harness de reações faz com K = 3 (`tests/aether_reactions_test.gd:118-120`); custo: mexe na cadência que produziu o conserto medido do buffer de colocação (`src/entities/player.gd:44,650-652`, protegido em `tests/smoke_test.gd:118-126`). Em qualquer braço, fita e snapshot usam o mesmo dono (`src/main.gd:19`) e o mesmo `FORMAT_VERSION`.

## Gate de fechamento
Comandos que já existem (`docs/melhorias-status.md:1037-1043`, `AGENTS.md:289-298`):

```sh
godot --headless --path . --import
godot --headless --path . --check-only --script src/persistence/tick_journal.gd
godot --headless --path . --script tests/tick_journal_test.gd
godot --headless --path . tests/smoke_test.tscn -- --tick-journal=CAMINHO-NOVO.jsonl
```

Âncora no contrato, o único com contagem travada em código (`tests/tick_journal_test.gd:13`, exigida em `:461`: 128 checagens); o smoke imprime sem exigir (`tests/smoke_test.gd:158-161`) — por isso o censo pode cair de 220 para 216 sem nenhum vermelho (`docs/melhorias-status.md:370-374`). As checagens abaixo **não existem**; a primeira tarefa é o driver de replay na forma do que existe (`extends SceneTree`, `TESTS`, `_check`, censo, `quit(1)` — `tests/tick_journal_test.gd:1-13,45-51,458-464`) dirigindo `main._sim_tick()` com `process_mode` desligado, como já faz `tests/tick_journal_test.gd:359-382`. `snapshot_resta_hash`: snapshot + fita desde o tick 0 em dois processos → `ticks_conferidos=N`, `divergencia_primeiro=-1`. `ordem_independente_de_quadros`: mesma fita com K=1 e K=8 → `divergentes=0` `[TARGET]`, e a primeira corrida imprime o valor real (esperado > 0), número que nomeia o vazamento por frame. `rng_restaurada_no_load`: `sorteios_iguais=verdadeiro` por dono após load. `formato_declarado`: `FORMAT_VERSION` 1 vs 2 dão hashes diferentes e a fita recusa versão estrangeira. Custo sem regressão: `dropped_ticks=0` e `worst_sim_ms` contra o `6,779 ms` `[MEASURED]`. Nada aqui fecha gate de fase: P0 e P1 seguem abertos, e quem fecha é o dono.

## Custo — as quatro perguntas (`AGENTS.md:242-244`)
1. Por frame, por tick, às vezes? `record()` roda 1× por passo (20×/s, `src/main.gd:165-166`); a fita roda no ponto de
   escrita (13 edições na corrida lida); o carimbo `frames_do_tick` rodaria 1× por frame — 60 Hz é default do engine, não
   fixado em `project.godot:27-29`, `[CLAIMED]`. Custo das linhas novas: **não medido**.
2. Entidades alcançadas? 5 lobos (`src/main.gd:9`; 4 vivos no fim da corrida lida), 1 jogador, 64 chunks
   (`src/world/voxel_config.gd:10-11`), 49.152 células de Éter (32×16×32×3) varridas por registro hoje, 359 ticks na
   janela medida.
3. Aloco no caminho quente? Sim e medido no recorte: 196.608 bytes/tick de cópia Float32 (`aether_field.gd:218-219`) mais
   os arrays da projeção (`tick_journal.gd:17-39`); o journal custou 160.000 µs em 205 registros (~780 µs médios), pico
   1,646 ms, pior passo 9,738 ms ON contra 10,574 ms OFF (`docs/melhorias-status.md:1016-1017,1030`). Bytes novos: não
   medidos; a colheita por registro já existe (`tick_journal.gd:84-86,96-98`).
4. Como sei que ficou melhor? Não é otimização, é propriedade: o censo do contrato (128 → novo `EXPECTED_CHECKS`) mais as
   linhas de cima, em corrida serial com a máquina livre (`AGENTS.md:300-302`), e número publicado re-medido no clone
   limpo do SHA final (`docs/melhorias-status.md:608-615`).

## O que NÃO fazer
Não chamar de replay a igualdade da projeção atual, que exclui jogador, corpos, RNG e comandos
(`docs/melhorias-status.md:541-544`). Não gravar tecla crua como verdade, nem inventar flag de engine nem o `af-bench`. Não
mover locomoção para o tick sem re-medir a borda de input. Não abrir canal novo de Éter, inspector de mentes,
`HotSet` ou facções. Fita e snapshot nascem das transições reais (`respawn_at`, `close_panel`, `set_block`), não de
campo escrito à mão.

## Checklist de commits atômicos (cada um com corrida própria)
1. Cabeçalho de formato + `formato_declarado`, gameplay intocado.
2. Snapshot sobre `save_game` mais timers e fila, restauração por `apply_edits`, `snapshot_resta_hash`.
3. Fita nos handlers `src/main.gd:268-321` com as regras de `record()`, ainda sem aplicar na restauração.
4. Driver de replay + `ordem_independente_de_quadros` **vermelho com o número real de ticks divergentes**.
5. RNG: estado ou contador; restaurar no load; fechar `rng_restaurada_no_load`.
6. Decisão A/B do dono e só então o corte que leva `divergentes` a zero; re-medida no clone limpo do SHA final com
   `--import`, SHA pinado, `docs/melhorias-status.md` atualizado (item 2, débitos de ordem e de RNG).
