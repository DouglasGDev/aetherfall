# 12 — Bicho cavando voxel

Dossiê de **leitura de código**, não de corrida: nenhuma engine rodou aqui e nenhum número
publicado foi re-medido por este arquivo. Autorização do dono em 2026-11-20
([`AGENTS.md`](../../AGENTS.md), extensão de 2026-11-20), com o recorte answered na mesma
conversa: **"os dois — lavra contínua + animal cavando"**. Última da série serializada
09 → 10 → 11 → **12** porque a folha de cavar entra na árvore que a alcateia (10) reorganizou.

## 1. Premissa nomeada

**Um animal que cava tem de ser observado removendo um voxel que o jogador não tocou, e o mundo tem
de registrar isso.** Falsificável em headless: cenário sem nenhum input do jogador, `world.get_block`
de um voxel ocupado vira `AIR` por ação do lobo, `block_changed` dispara, o imprint de WORK aparece
na célula, e a edição entra na lista de `edits` do save — **tudo isso sem uma linha de lavra do
jogador no meio**. Se o único `set_block` do cenário for o do `Player`, a mecânica não existe.

Recorte que a premissa **não** cobre, e o código já entrega: a lavra contínua do jogador existe —
segurar `break_block` soma `_mining_accum` por frame até a dureza
([player.gd:636-647](../../src/entities/player.gd#L636-L647), o reset de alvo em
[`_progress_of`](../../src/entities/player.gd#L626-L630)), e o drop do registro entra direto no
inventário ([`_mine_target`](../../src/entities/player.gd#L659-L672), com a recusa de espaço em
`:662-666`). As três promessas já são checadas
([smoke_test.gd:881-889](../../tests/smoke_test.gd#L881-L889): "segurar break minerou", "tempo de
mineracao == dureza", "lavra entrou no inventario como drop"). **Mexer nisso é violar o mandato
"não melhorar um sistema que já passou no gate dele"** — este dossiê não toca `player.gd`.

## 2. Estado real do código (lido, não medido)

- **Nenhum bicho escreve no mundo.** Os dois únicos `world.set_block` de gameplay do `src/` são do
  jogador ([player.gd:667](../../src/entities/player.gd#L667),
  [:693](../../src/entities/player.gd#L693)); os outros chamadores são a própria classe
  ([voxel_world.gd:247](../../src/world/voxel_world.gd#L247), em `_write_raw`) e a geração
  ([world_gen.gd:134](../../src/world/world_gen.gd#L134), [:136](../../src/world/world_gen.gd#L136),
  [:215](../../src/world/world_gen.gd#L215), [:233](../../src/world/world_gen.gd#L233),
  [:249](../../src/world/world_gen.gd#L249)).
- **A API já é a certa e já é pública**:
  [`set_block(p, b, record := true) -> bool`](../../src/world/voxel_world.gd#L252-L263) — recusa
  fora dos limites, recusa escrever o que já está lá, grava em
  [`_write_raw`](../../src/world/voxel_world.gd#L242-L249) (chunk **e** índice linear `_flat`),
  guarda a edição em `edits[p]`, marca chunks sujos em
  [`_touch_chunks_of`](../../src/world/voxel_world.gd#L266-L277) e emite
  `block_changed(pos, prev, now)` ([:6](../../src/world/voxel_world.gd#L6)). O lobo já segura
  `world` e `aether` desde o [`setup`](../../src/entities/wolf.gd#L166-L182).
- **O caminho do WORK hoje é do jogador** — o sinal `acted` do `Player` é o que imprime WORK 0,42
  (quebra) e 0,20 (coloca) em [main.gd:365-370](../../src/main.gd#L365-L370). Se o lobo cavar sem
  imprimir, o rastro de trabalho continua sendo assinatura exclusiva do jogador — e é exatamente
  isso que os cenários `_test_work_cycle` e `_test_work_approach`
  ([aether_reactions_test.gd:9-13](../../tests/aether_reactions_test.gd#L9-L13)) usam como
  premissa. **Consequência registrada:** um `WORK` vindo de bicho passa a ser lido como se fosse de
  jogador; o lote decide isso **antes** de escrever, com a checagem A/B dos dois canais nomeada no §5.
- **Durezas que um bicho de pata consegue vencer** (`hardness` em segundos de lavra a mão nua,
  [block_defs.gd:116-122](../../src/world/block_defs.gd#L116-L122)): `SNOW 0,25`, `SAND 0,30`,
  `DIRT 0,35`, `GRASS 0,38` — e `STONE 0,95`, `WOOD 0,55`, `COBBLESTONE 0,85` ficam **fora** do
  alcance com a mesma régua usada pelo jogador (`_mining_accum >= target_hardness`,
  [player.gd:646](../../src/entities/player.gd#L646)). O teto de "o que o bicho cava" é uma lista de
  blocos, não uma força arbitrada.
- **O custo de cada voxel removido é a malharia, medida:** `set_block` → `_touch_chunks_of` → fila
  `_dirty`, consumida por [`process(p_frame_budget)`](../../src/world/voxel_world.gd#L178-L186) com
  `MESH_BUDGET := 2` chunks por frame ([main.gd:13](../../src/main.gd#L13), chamada em
  [[:192-193](../../src/main.gd#L192-L193)](../../src/main.gd#L192-L193)). As duas leituras que o
  contrato publica: **64 chunks em ~4,3 s no boot**
  (`README.md:548`; 4.640–4.886 ms nas cinco corridas históricas,
  `docs/melhorias-status.md:83-83`) ≈ 67 ms/chunk, e **3,14 ms no frame de jogo**
  (`_last_mesh_ms` em [voxel_world.gd:186](../../src/world/voxel_world.gd#L186), lido pelo F3 em
  [hud.gd:241-275](../../src/ui/hud.gd#L241-L275)). Os dois números convivem porque o boot congela a
  janela e **não há medição de um chunk sujo isolado** — e é ela que o cavar consome. Instrumento
  que já existe e resolve a pergunta sem código novo:
  [`pending_meshes()`](../../src/world/voxel_world.gd#L189) e
  [`meshes_built()`](../../src/world/voxel_world.gd#L197).
- **Onde a mecânica se encaixa, com nome:** a árvore tem `Selector[flee, hunt, sniff, patrol]`
  ([wolf.gd:201-227](../../src/entities/wolf.gd#L201-L227)); o desemperto atual termina em desvio
  geométrico ([`_physics_process`:738-742](../../src/entities/wolf.gd#L738-L742)) e nunca em
  escavação; a inspeção de rastro é RUNNING por `INSPECT_SECONDS`
  ([`_leaf_investigate`](../../src/entities/wolf.gd#L249-L279)) e o chão encontrado vem de
  [`_scent_ground_y`](../../src/entities/wolf.gd#L689-L697) — a "boca da caverna farejada" é este
  ponto, e a camada é a do achado, não o topo da coluna (regra medida na rodada das duas camadas).

## 3. O que a peça exige

1. **Folha `dig` com estado, medida em segundos de simulação.** Accumulador por lobo
   (`_dig_accum`), mesmo modelo do do jogador (`_mining_accum`,
   [player.gd:137](../../src/entities/player.gd#L137)), somado em `sim_step`
   ([wolf.gd:409-433](../../src/entities/wolf.gd#L409-L433)) e comparado a
   `BlockDefs.hardness(block)`. A escrita no mundo acontece **uma vez**, quando estoura — nunca por
   frame.
2. **Duas razões para cavar, e só duas:**
   - **(a) abrir passagem** quando o bloqueio persiste: depois de N ticks de progresso de locomoção
     abaixo do mínimo **com a mesma face bloqueada** (a mesma grandeza que dispara o desvio em
     `:562-566`), o lobo cava o que está na frente, se estiver na lista do §2 (neve/areia/terra/
     grama). Cavar é a escalonação do desemperto, não uma intenção nova concorrente.
   - **(b) destruir a entrada do rastro** quando a inspeção achou BLOOD dentro de uma cavidade: o
     alvo é a célula que `_scent_ground_y` devolve, e a consequência observável é o rastro exposto
     (WORK + BLOOD difundem com menos barreira — a difusão já trata sólido como barreira,
     [aether_field.gd:18-22](../../src/world/aether_field.gd#L18-L22)).
   - **NÃO entra: "pisar neve/areia patrulhando".** É cosmeticamente tentador e custa um remesh por
     passo de patrulha, sem premissa que ele decida. Vira linha de backlog no status.
3. **`record: = true` por decisão explícita**: escrever em `edits` significa que a cova **sobrevive
   ao save** ([main.gd:443](../../src/main.gd#L443) grava a lista,
   [:474-477](../../src/main.gd#L474-L477) aplica no load). O lote grava (é o mundo real do lobo) e
   imprime `edits.size()` no `diagnostics()` ([main.gd:523-534](../../src/main.gd#L523-L534)) para a
   fila de crescimento do save ficar à vista.
4. **WORK do bicho com assinatura própria**: o imprint acontece no **lobo** (ele tem `aether`), com
   o mesmo valor da lavra do jogador (0,42) se a intenção for "o outro predador está trabalhando
   aqui". O que precisa existir antes de qualquer curva de utilidade ler isso é a checagem A/B do
   §5.3, senão o `_test_work_cycle` passa a ter uma fonte que ele não declara.
5. **Item nenhum**: não existe inventário de criatura nem entidade de item no chão (o drop do
   jogador vai direto para `inv`, [player.gd:670](../../src/entities/player.gd#L670)). O bloco
   cavado **desaparece** — isso é honesto e precisa estar escrito, não fingido.

## 4. Custo — as quatro perguntas

- **Roda por frame, por tick ou às vezes?** Acumulador e decisão: **tick de 20 Hz**, dentro do
  `sim_step` cronometrado ([main.gd:158-160](../../src/main.gd#L158-L160),
  [sim_clock.gd:32-39](../../src/core/sim_clock.gd#L32-L39)). A escrita no mundo: um evento por
  bloco removido. O remesh resultante: no `_process` ([main.gd:192-193](../../src/main.gd#L192-L193)),
  **fora** do passo de simulação, com budget próprio.
- **Quantas entidades são alcançadas?** 5 lobos (12 com o censo do dossiê 11), e cada um alcança
  **1 voxel** por vez. A grande que assusta é o raio do `7×7` do rastro
  ([:462-506](../../src/entities/wolf.gd#L462-L506)) — cavar **não** varre nada: lê `get_block` do
  alvo e do vizinho de baixo.
- **Aloco no caminho quente?** Não no acumulador (`float` + uma `Vector3i`). O que aloca é a
  consequência: `edits[p] = b` (Dictionary do mundo) e a fila `_dirty` (`Array` de chunk, já
  existente). Nada de `Array` novo por tick.
- **Como sei que ficou melhor / quanto custa?** Medindo, antes de celebrar: o lote **primeiro**
  publica `worst _last_mesh_ms` com o cavar ativo (F3/`diagnostics`, já lido por
  [hud.gd:241-275](../../src/ui/hud.gd#L241-L275)) e `pending_meshes()` máximo, e só depois o
  número vai para o status. Critério numérico escrito antes da corrida: **nenhum frame com
  `pending_meshes()` acima de 8** (4 frames de budget a 60 fps) e `dropped_ticks` continua 0 no
  smoke — se estourar, a cadência de cavar cai (bloqueio persistente por mais ticks), não o
  budget de malha sobe.

## 5. Gate em headless

```sh
godot --headless --path . --check-only --script src/entities/wolf.gd
godot --headless --path . --script tests/aether_reactions_test.gd
godot --headless --path . tests/smoke_test.tscn
```

1. **`lobo_cava_sem_input_do_jogador`** — voxel de `DIRT`/`SNOW` ocupado, jogador longe e sem
   `action_press`, N passos: `get_block` vira `AIR`, `block_changed` visto por um contador, e o
   `edits` do mundo ganhou a chave. Imprime o tick em que estourou, a dureza do bloco e o número de passos.
2. **`cavar_respeita_a_lista`** — o mesmo cenário em `STONE`: **nada** é removido em 2× o tempo do
   braço verde. Imprime o bloco e a dureza recusada.
3. **`work_de_bicho_nao_confundido`** — A/B: cenário com WORK só do lobo, e a leitura que decide
   `investigate` (`_find_scent` com `BLOOD + 0,35 × WORK`,
   [wolf.gd:462-506](../../src/entities/wolf.gd#L462-L506)) é conferida contra o caso de WORK só do
   jogador. Ou a curva distingue (por canal/origem já existente), ou o texto deixa de dizer que
   WORK é pegada do jogador — **esta checagem é a que decide o desenho**, e ela nasce antes da
   folha `dig` ficar verde.
4. **`malharia_do_cavar_medida`** — a colheita: `worst _last_mesh_ms`, `max pending_meshes()`,
   `meshes_built()` antes/depois do lote, e `dropped_ticks == 0`. Sem estas quatro linhas o número
   publicado é hipótese.
5. **`abrir_passagem_depois_de_bloqueio`** — cenário de corredor entupido por neve (o mesmo tipo de
   estado que a rodada do "passo do lobo" produziu, [status — furo do contato com o chão]): um
   braço com a folha `dig` atravessa, o outro **não**. Os dois sentidos, como o contrato exige
   (ciclo 3).
6. `EXPECTED_CHECKS` ([aether_reactions_test.gd:19](../../tests/aether_reactions_test.gd#L19), hoje
   **109**) e a suíte (hoje **236**) sobem com o lote, re-medidos no clone limpo com `--import`
   frio.

## 6. O que NÃO fazer

- Não tocar em `player.gd`: a lavra do jogador tem gate próprio e verde
  ([smoke_test.gd:881-889](../../tests/smoke_test.gd#L881-L889)); refatorar `set_block` "para os dois
  chamadores ficarem limpos" é generalizar no primeiro, e o contrato manda no segundo.
- Não dar ao bicho uma força de escavação maior que a mão do jogador: se o lobo quebra `STONE` em
  0,3 s, o `hardness` do registro ([block_defs.gd:116-122](../../src/world/block_defs.gd#L116-L122))
  deixa de ser a régua do mundo e os números do README passam a valer só para o jogador.
- Não fazer cópia de inventário de criatura nem entidade de item no chão: nenhuma das duas existe,
  e a segunda é P2.
- Não subir `MESH_BUDGET` ([main.gd:13](../../src/main.gd#L13)) para esconder a fila `_dirty`: o
  budget é o número do contrato, e a cadência de cavar é a alavanca.
- Não imprimir WORK de bicho sem a checagem 3: é a única coisa que impede os cenários existentes de
  passarem a afirmar algo que deixou de ser verdade.

## 7. Commits atômicos

(a) instrumento primeiro: `pending_meshes()`/`_last_mesh_ms` colhidos no runner, com o número do
estado **atual** (sem cavar) na mesa; (b) folha `dig` + acumulação + lista de blocos, com 1 e 2;
(c) WORK com 3; (d) abrir passagem com 5; (e) destruir entrada de rastro com (b.2) do §3; (f)
status + `README.md` com as medições do clone limpo. Branch `feat/bicho-cavando-12`, merge `--no-ff`.

## 8. O que este dossiê não fecha

Nenhum gate de fase (mandato 4). Não é ecologia (P2), não é física de blocos nem camadas verticais
— a especificação dessas (`docs/design/10-world-layers-and-block-physics.md`) continua com os ids 9..18 reservados
([block_defs.gd:5-8](../../src/world/block_defs.gd#L5-L8), [:39](../../src/world/block_defs.gd#L39)),
e o cavar de um bicho **não** preenche essa reserva: ele usa `AIR` e o registro existente.
