# 17 — Física de blocos que caem (o evento que ninguém assina)

Dossiê de **leitura de código**, não de corrida: nenhuma engine rodou aqui e nenhum número
publicado foi re-medido por este arquivo. Entra na fila porque o dono pediu a pauta em
2026-11-21, por escrito, em dois prompts ("Física de Blocos + Mundo Reativo" e "Física de
Blocos + Mundo Vivo"); o registro vem **antes** de qualquer linha de código, como exige o
mandato 4 de [`AGENTS.md`](../../AGENTS.md). Nada aqui reabre o que já passou no gate do
dossiê 10 do design: [`docs/design/10-world-layers-and-block-physics.md`](../design/10-world-layers-and-block-physics.md)
é a especificação, este arquivo é a conferência dela contra o que existe.

Números de `arquivo:linha` desta página são da `main` em `86e63c4`. A perna 11 em curso
(`feat/acasalamento-e-censo-11`) empurra `_sim_tick` de `:229` para `:251` e acrescenta
constantes de acasalamento; onde este dossiê depende de linha do `main.gd`, ela é re-derivada
no fechamento da perna, não adivinhada agora.

## 1. Premissa nomeada

**Se um bloco granular perde o apoio, ele some do grid no tick N, existe como corpo em queda
e passa a ocupar uma célula livre mais abaixo no tick N+k — e nada no mundo foi varrido para
chegar a isso.** Falsificável em headless, com o jogador longe e sem um único `action_press`:
montar uma coluna de `SAND`, remover o sólido debaixo dela com `world.set_block`, e exigir
(i) a célula de origem virando `AIR`, (ii) uma célula mais abaixo virando `SAND`, (iii) o
contador da fila visível no `diagnostics()` caindo a zero depois, e (iv) `get_block` lido um
número **limitado por evento**, não proporcional ao tamanho do mundo.

O segundo sentido que o ciclo de trabalho (item 3) exige: com a fila **não anexada** ao sinal,
o mesmo cenário não move um voxel em 200 ticks. Sem esse braço, a checagem verde pode estar
afirmando apenas que a geração já deixou a areia no lugar certo.

Recorte que a premissa **não** cobre, e que o prompt misturou:

- **Rebase das camadas verticais** (Y ∈ [−64, 319], chunk 16 × 384 × 16, translação de +38 do
  relevo e das edições gravadas) — doc 10 §10.2 [`:50-58`](../design/10-world-layers-and-block-physics.md#L50-L58),
  §10.6, §10.7. É outro trabalho, quebra formato de save e não é pedido aqui. A queda de
  bloco roda **na geometria que existe**: 128 × 64 × 128 ([voxel_config.gd:5-11](../../src/world/voxel_config.gd#L5-L11)).
- **Fluidos** (correnteza, escorrimento lateral, lava+água→obsidiana): o próprio doc 10 declara
  ambos `[OPEN]` e fora do pedido das regras [`:1081-1084`](../design/10-world-layers-and-block-physics.md#L1081-L1084).
- **Luz/`TORCH`, biomas novos, cavernas novas** — nada disso tem comprador aqui.
- **Dano de impacto de bloco pesado**: nenhum bloco `HEAVY` existe (§2), então a fórmola de
  dano do doc 10 [`:452-471`](../design/10-world-layers-and-block-physics.md#L452-L471) fica
  `[TARGET]` e sem checagem, não sem documentação.

## 2. Estado real do código (lido, não medido)

- **O sinal existe e ninguém o escuta.** [`signal block_changed(pos, prev, now)`](../../src/world/voxel_world.gd#L6)
  é declarado em `voxel_world.gd:6` e emitido no fim de
  [`set_block`](../../src/world/voxel_world.gd#L252-L263) (emissão em
  [`:262`](../../src/world/voxel_world.gd#L262)). Um grep de `block_changed` em `src/` e
  `tests/` devolve **duas** ocorrências, as duas nessa file — a declaração e a emissão — e
  nenhum `.connect(` em lugar nenhum: o sinal nunca teve leitor desde que entrou. A porta do
  design ("a única porta de entrada para 'este voxel tem
  gravidade?' é o sinal", doc 10 [`:663-665`](../design/10-world-layers-and-block-physics.md#L663-L665))
  está construído do lado de escrever e vazia do lado de ler.
- **`set_block` já é o ponto único de mutação, com as quatro consequências certas**
  ([`:252-263`](../../src/world/voxel_world.gd#L252-L263)): recusa fora de
  `VoxelConfig.in_world_bounds` ( [`:26`](../../src/world/voxel_config.gd#L26), que exige
  `0 ≤ y < 64`), retorna `false` se `prev == b` (`:256-257` — escrever o que já está lá **não**
  emite evento), grava chunk **e** índice linear em
  [`_write_raw`](../../src/world/voxel_world.gd#L242-L249), guarda a edição em
  [`edits[p]`](../../src/world/voxel_world.gd#L260) quando `record` (o default é `true`), suja
  o chunk e os vizinhos de borda em
  [`_touch_chunks_of`](../../src/world/voxel_world.gd#L266-L277) e só então emite. Os dois
  únicos chamadores de gameplay hoje são do jogador:
  [`:685`](../../src/entities/player.gd#L685) (quebra → `AIR`) e
  [`:711`](../../src/entities/player.gd#L711) (colocação).
- **Nenhuma das peças nomeadas existe.** Grep em `src/` e `tests/`: `BlockUpdateQueue` — zero,
  `FallingBlock` — zero, `FallingBlockSpawner` — zero, `DropSpawner`/`DropItem` — zero,
  `is_supported` — zero, `place_falling_block` — zero. As quatro primeiras são §10.4/§10.5 do
  doc 10 ([entidade `:476-565`](../design/10-world-layers-and-block-physics.md#L476-L565),
  [spawner `:614-631`](../design/10-world-layers-and-block-physics.md#L614-L631),
  [fila `:667-749`](../design/10-world-layers-and-block-physics.md#L667-L749),
  [API nova `:774-790`](../design/10-world-layers-and-block-physics.md#L774-L790)); o doc mesmo
  já tabela isso como inexistente em
  [`:652-659`](../design/10-world-layers-and-block-physics.md#L652-L659).
- **As flags de blocos não estão no registro.** [`BlockDefs`](../../src/world/block_defs.gd)
  tem **sete** tabelas paralelas — `_solid`, `_opaque`, `_draw`, `_stack`, `_drop`, `_hard`,
  `_names` ([`:65-71`](../../src/world/block_defs.gd#L65-L71)) — e nenhum campo de gravidade,
  classe de queda, "quebra queda", "substituível" ou "destrutível". Os nove campos que a
  especificação exige um por pergunta estão descritos em
  [doc 10 `:145-160`](../design/10-world-layers-and-block-physics.md#L145-L160) e na tabela de
  19 linhas [`:170-190`](../design/10-world-layers-and-block-physics.md#L170-L190); no código,
  `SAND` é só `is_solid` + `hardness 0,30` + tile 4. `COUNT = 23`
  ([`:37`](../../src/world/block_defs.gd#L37)) e os ids 9..18 continuam reservados
  ([`:5-8`](../../src/world/block_defs.gd#L5-L8)), com os tiles 10..18 igualmente livres
  ([`:39`](../../src/world/block_defs.gd#L39)) — os materiais de craft de `19..22` chegaram
  antes e não interferem.
- **Não há bloco `HEAVY` nem `quebra_queda` no mundo.** `ANVIL` (14), `ROCK_LOOSE` (15),
  `POWDER_SNOW` (13), `TORCH` (16), `PLANT` (17) e `SLAB` (18) são números prometidos, não
  registros. Então das três saídas da célula de pouso do doc
  ([`_landing_cell` `:554-565`](../design/10-world-layers-and-block-physics.md#L554-L565))
  **duas não têm comprador hoje**: só `FIX` sobre um sólido acontece, porque `SHATTER` exige
  `breaks_a_fall` e `impact` exige `FallClass.HEAVY`. É a regra da casa — generalizar no
  segundo comprador, não no primeiro — que corta essas duas saídas do primeiro lote, não
  preguiça.
- **O integrador que a entidade precisa já existe e é o mesmo do lobo.**
  [`VoxelBody`](../../src/entities/voxel_body.gd): `setup(world, pos, dims)`
  ([`:27`](../../src/entities/voxel_body.gd#L27)), `feet_pos` como canto inferior da AABB
  ([`:15`](../../src/entities/voxel_body.gd#L15), montado em `aabb()` `:33-35`),
  `apply_gravity` com `gravity = 24,0` e teto `TERMINAL_VELOCITY = 42,0`
  ([`:17`](../../src/entities/voxel_body.gd#L17), [`:6`](../../src/entities/voxel_body.gd#L6),
  [`:42-43`](../../src/entities/voxel_body.gd#L42-L43)) e
  `move_and_collide` com substep de `0,35` m ([`:7`](../../src/entities/voxel_body.gd#L7),
  [`:47-57`](../../src/entities/voxel_body.gd#L47-L57)) — os mesmos `g = 24` e `v_term = 42`
  que a matemática do doc [`:452-457`](../design/10-world-layers-and-block-physics.md#L452-L457)
  usa para derivar `h_segura = 4,08`. **Detalhe que muda o resultado:** o mesmo
  `move_and_collide` faz *auto step-up* de `0,62` m em movimento horizontal com pé no chão
  ([`step_up` `:19`](../../src/entities/voxel_body.gd#L19), aplicado em
  [`:90-97`](../../src/entities/voxel_body.gd#L90-L97)) e `escape_embedded` empurra para cima
  quem está dentro de sólido ([`:65-76`](../../src/entities/voxel_body.gd#L65-L76)). Um bloco
  em queda que herdar `step_up` **sobe** em vez de parar no apoio; o `setup` da entidade novo
  tem de zerar `step_up` e o lote tem de ter a checagem que prova isso (§5.4).
- **O fundo do mundo segura a cascata sem `BEDROCK`.**
  [`get_block_xyz`](../../src/world/voxel_world.gd#L226-L239) devolve `STONE` para `y < 0` e
  para `x`/`z` fora do mapa, e `AIR` acima de `CHUNK_SIZE_Y` (`:226-232`). Logo
  `is_supported(x, 0, z)` é **verdadeiro por construção** e nenhuma cascata atravessa o soalho
  — o que também significa que um bloco expulso pelo topo só para com o teto de ticks da
  entidade (`MAX_FALL_TICKS`, doc [`:486`](../design/10-world-layers-and-block-physics.md#L486)).
- **O custo real de cada voxel movido é a malharia, e ela tem orçamento próprio.**
  `set_block` → `_touch_chunks_of` → fila `_dirty` consumida por
  [`process(p_frame_budget)`](../../src/world/voxel_world.gd#L178-L186) chamada no
  `_process`, **fora** do passo de simulação, com
  [`MESH_BUDGET := 2`](../../src/main.gd#L19) chunks por frame
  (chamada em [main.gd:262-263](../../src/main.gd#L262-L263)). As duas leituras que o contrato
  publica: **64 chunks em ~4,3 s no boot** ([README.md:148-149](../../README.md#L148-L149)) ≈
  67 ms/chunk, e o `_last_mesh_ms` do frame lido pelo F3. Uma pilha de N areias em cascata
  são N remoções **e** N fixações: até `2N` células sujas, e a malharia não sabe que a
  remoção e a fixação foram o mesmo cubo. Isso é motivo para o teto por tick da fila
  (doc [`:672`](../design/10-world-layers-and-block-physics.md#L672)) existir, não para
  aumentar `MESH_BUDGET`.
- **Cada escrita de bloco entra no save e no hash.** `edits[p]` é gravado inteiro no
  [`save_game()`](../../src/main.gd#L623-L637) (`:625-637`) e re-aplicado no
  [`load_game()`](../../src/main.gd#L654-L670) (`:668-670`), e o `diagnostics()` já imprime
  `edits.size()` ([`:721`](../../src/main.gd#L721)). A projeção do
  [`TickJournal.state_hash`](../../src/persistence/tick_journal.gd#L16-L44) ordena e mistura as
  **edições** na conta ([`:17-21`](../../src/persistence/tick_journal.gd#L17-L21)).
  Consequência declarada antes do código: um corrida com areia caindo **não** reproduz os
  hashes das rodadas publicadas — não porque o journal mudou (`FORMAT_VERSION` continua 1,
  [`:4`](../../src/persistence/tick_journal.gd#L4)), mas porque o mundo mudou. Os hashes
  históricos continuam valendo na revisão em que foram medidos.
- **A cascata não precisa de código de cascata.** Remover o apoio é um `set_block(AIR)`, que
  emite `block_changed`, que olha o vizinho de cima — o doc 10 explica a recursão em
  [`:634-638`](../design/10-world-layers-and-block-physics.md#L634-L638) e a terminação em
  [`:640-648`](../design/10-world-layers-and-block-physics.md#L640-L648). O que a fila tem de
  garantir é (a) iterar sobre **snapshot** (o `flush` do doc usa `_due(tick)`
  [`:707-717`](../design/10-world-layers-and-block-physics.md#L707-L717) antes de resolver,
  senão o próprio `_resolve` mutaria o dicionário em iteração) e (b) ordem determinística: Y
  decrescente, depois X, depois Z
  ([`:720-734`](../design/10-world-layers-and-block-physics.md#L720-L734)) — sem isso, dois
  executores da mesma semente resolvem pilhas em ordens diferentes e o hash do parágrafo
  acima deixa de ser função do estado.

## 3. O que a peça exige

1. **Uma flag nova, não nove.** `_gravity` (`PackedByteArray`, `COUNT` de `:37`) com
   `SAND = 1`, e o acesso `BlockDefs.has_gravity(b)`. A tabela de `init_tables` ganha um
   `resize` próprio, porque `PackedByteArray` é copy-on-write em GDScript 4 e um `for` sobre as
   variáveis moraria na cópia — o comentário que já avisa isso está em
   [`:77-79`](../../src/world/block_defs.gd#L77-L79), com o primeiro `resize` em `:80`. `fall_class`, `breaks_a_fall`,
   `blocks_air`, `is_replaceable` e `destructible` entram **com seus compradores**, um por
   commit (§7), nunca de uma vez "para ficar completo".
2. **`BlockUpdateQueue` com as três constantes do doc, marcadas `[TARGET]` até a primeira
   corrida**: `MAX_PER_TICK = 256`, `MAX_QUEUED = 8192`, `RECHECK_DELAY = 1`. A garantia de
   performance **não** é CPU: é o fato de que Posição que ninguém colocou na fila nunca é
   lida. A régua do que se evita é aritmética sobre os números verificados: o mapa tem
   128 × 64 × 128 = **1 048 576** células; uma varredura de gravidade por tick seriam
   **20 971 520** `get_block`/s. Com a fila, o custo por evento é 2 `get_block` + 2
   `has_gravity` (doc [`:769-772`](../design/10-world-layers-and-block-physics.md#L769-L772)),
   e o número de eventos é o de edições do tick.
3. **`is_supported(p)` e `place_falling_block(cell, b)` como API nova de `VoxelWorld`**
   (doc [`:774-790`](../design/10-world-layers-and-block-physics.md#L774-L790)): o teste de
   apoio é o bloco de baixo lido por `get_block_xyz`, que já devolve sólido fora do mundo; a
   fixação só aceita célula livre ou líquida, porque um bloco que não coube vira drop, não
   fantasma dentro de pedra.
4. **`FallingBlock` com `step_up = 0`** e célula de pouso derivada do **apoio**, nunca da
   posição do corpo (doc [`:549-553`](../design/10-world-layers-and-block-physics.md#L549-L553)):
   o integrador para em substep e a AABB pode parar um substep acima do solo.
5. **Onde a roda roda**: `updates.flush(clock.tick)` e depois o `sim_step` das entidades,
   dentro de [`_sim_tick`](../../src/main.gd#L229) — **antes** das mentes, para que uma
   conversão só integre no tick seguinte (doc
   [`:757-759`](../design/10-world-layers-and-block-physics.md#L757-L759)). Nada em
   `_physics_process`: o passo de simulação é o que o `clock.begin_step`/`end_step` cronometra
   ([main.gd:220-226](../../src/main.gd#L220-L226),
   [sim_clock.gd:32-39](../../src/core/sim_clock.gd#L32-L39)) e é o que o hash lê.
6. **`queued` e `overflow` visíveis**, no `diagnostics()` ao lado de `dropped_ticks`
   ([main.gd:717-725](../../src/main.gd#L717-L725)) e no F3, como o doc exige em
   [`:746-749`](../design/10-world-layers-and-block-physics.md#L746-L749): estourar o teto
   adia grãos, não os perde, e sem o número a discussão sobre `MAX_PER_TICK` é opinião.
7. **O estado de queda não vai para o save — e isso é decisão escrita, não esquecimento.**
   Não existe chave para entidades em voo hoje, e criar uma é mexer no schema por uma
   janela de ~1 s de vida média. O lote resolve por **quiesce**: `save_game()` chama
   `flush` + integra as entidades até todas pousarem (ou estourarem `MAX_FALL_TICKS`) antes
   de serializar, de modo que o disco nunca vê o mundo com um bloco "nem lá nem lá". A
   checagem §5.5 é o que impede a regra de virar prosa.

## 4. Custo — as quatro perguntas

- **Roda por frame, por tick ou às vezes?** A fila e a integração: **tick de 20 Hz**
  ([sim_clock.gd:5-7](../../src/core/sim_clock.gd#L5-L7)), dentro do cronômetro do passo. O
  evento de entrada: só quando alguém escreve no grid, hoje dois lugares no jogador. A
  malharia causada: `_process`, budget próprio de 2 chunks/frame.
- **Quantas entidades são alcançadas?** Um evento de bloco alcança **2 células** (`p+Y` e `p`).
  Nenhuma entidade viva é alcançada no primeiro lote; o `entity_provider` do impacto fica
  `[TARGET]` até existir bloco `HEAVY`. O pior caso real é a lavra de uma coluna de N areias:
  N eventos por quebra, N resoluções em N ticks (ordem Y desc), e o teto de fila nunca é
  tocado porque `_pending.has(p)` deduplica.
- **Aloco no caminho quente?** `_pending` (Dictionary de `Vector3i → int`) e o snapshot
  ordenado do `_due` **alocam por tick de fila ativa** — é o débito declarado, do mesmo tipo
  que os 100 dicionários/s do blackboard que o contrato já lista como não medidos. No passo
  sem eventos, `flush` alocaria um `Array` vazio: o lote devolve cedo (`if _pending.is_empty()`),
  e isso é uma linha, não uma abstração. O `_flat` já existe para leitura barata
  ([`:233-234`](../../src/world/voxel_world.gd#L233-L234)).
- **Como sei que ficou melhor / quanto custa?** Não é otimização, é mecânica: o número que
  tem de existir antes de qualquer celebração é `worst_sim_ms` com a cascata andando
  (`clock.worst_step_ms`, [sim_clock.gd:37-39](../../src/core/sim_clock.gd#L37-L39), já lido
  pelo F3), `max queued`, `overflow`, `edits.size()` e `dropped_ticks == 0` no smoke. Critério
  numérico escrito **antes** da corrida: nenhum passo de cascata acima de 25 ms dos 50 ms do
  budget, `dropped_ticks` continua 0, e `queued` volta a zero em ≤ N ticks depois da última
  edição — se estourar, a alavanca é `MAX_PER_TICK`, nunca `MESH_BUDGET`.

## 5. Gate em headless

```sh
godot --headless --path . --check-only --script src/world/block_defs.gd
godot --headless --path . --script tests/aether_reactions_test.gd
godot --headless --path . tests/smoke_test.tscn
```

1. **`queda_sem_varredura_de_mundo`** — contador de `get_block` instalado no `flush` de um
   cenário que **não** edita nada, 1 000 ticks: `queued == 0` e leituras == 0. Depois, uma
   coluna de 6 areias com o apoio removido: leituras totais ≤ `2 × eventos` + as resoluções,
   impressas. É a checagem que dá dente ao "zero varredura global" do prompt.
2. **`queda_move_a_celula`** — origem vira `AIR`, uma célula mais abaixo vira `SAND`, `edits`
   ganhou as duas chaves e `queued` volta a 0. Imprime os ticks `N`, `N+k` e o número de
   leituras. Nasce **vermelha** no código atual, porque nenhum consumidor existe.
3. **`queda_cascade_em_passos`** — pilha de N: exige N ticks de resolução, não 1, e a ordem
   Y decrescente visível na sequência de células impressa. A mesma cena, com o `_due` em ordem
   de dicionário, tem de **divergir** entre duas execuções da mesma semente — o doc
   [`:720-722`](../design/10-world-layers-and-block-physics.md#L720-L722) afirma isso e é
   checável sem código de jogo.
4. **`bloco_em_queda_nao_sobe`** — coluna de areia encostada numa parede de 2: a entidade
   desce e pousa **ao lado** do apoio, não em cima dele. Esta é a checagem do `step_up` do §3.4
   e do `escape_embedded` do §2.
5. **`queda_pousa_antes_do_save`** — salvar no meio de uma cascata (tick em que `queued > 0`):
   o `state_dict` gravado não contém a célula de origem nem uma célula fantasma, e o load
   devolve o mundo já em repouso. Imprime `edits.size()` antes/depois do quiesce.
6. **`queda_nao_custou_tempo_de_ninguem`** — os braços de sempre: 1 000 ticks sem areia e
   1 000 ticks com uma coluna caindo no tick 500, com `worst_sim_ms`, `max queued` e
   `dropped_ticks` lado a lado. A atribuição é por composição, como o contrato exige.
7. **`journal_hash_muda_so_com_movimento`** — dois runs da mesma semente, um sem nenhuma
   edição, um com a cascata: o primeiro **reproduz** o hash da rodada sem a feature (nenhum
   bloco se move sozinho), o segundo diverge e a divergência é atribuída às duas chaves de
   `edits` novas. Sem o primeiro lado, a checagem aceita queda em qualquer lugar.
8. `EXPECTED_CHECKS` ([aether_reactions_test.gd:30](../../tests/aether_reactions_test.gd#L30),
   **183** nesta leitura) e a última linha do smoke ([smoke_test.gd:184](../../tests/smoke_test.gd#L184))
   sobem com o lote e são re-medidos no clone limpo com `--import` frio, com o SHA pinado.

## 6. O que NÃO fazer

- **Não copiar nada do Veloren**, nem código, nem asset, nem "só o `.ron` de tabela". O veto
  está registrado no contrato com a contagem dos 645 arquivos de áudio GPL-3.0 deles
  ([`AGENTS.md`, mandato 8](../../AGENTS.md)). O que se aproveita é a **ideia** de areia que
  cai, que este dossiê já deriva do doc 10 e do `BlockDefs` daqui.
- **Não aumentar `MESH_BUDGET`** ([main.gd:19](../../src/main.gd#L19)) para esconder a fila de
  chunks sujos: o budget é número do contrato, a alavanca é o teto por tick da fila.
- **Não fazer varredura de coluna nem de chunk** para "achar areia solta", nem no boot, nem a
  cada N ticks. Se aparecer necessidade de re-validação em massa, ela entra como item de
  design novo, com custo medido, não como otimização de emergência.
- **Não dar destino inventado ao `_shatter`**: não existe entidade de item no chão
  ([doc 10 `:655`](../design/10-world-layers-and-block-physics.md#L655) já tabela isso, e o
  drop do jogador vai direto para `inv`, [player.gd:679-688](../../src/entities/player.gd#L679-L688)).
  Enquanto não houver `quebra_queda` com comprador, o caminho não é escrito.
- **Não reabrir a reserva de ids 9..18** com um bloco novo de conveniência, nem usar tile fora
  do que o doc promete ([block_defs.gd:5-8](../../src/world/block_defs.gd#L5-L8),
  [doc 10 `:1067-1070`](../design/10-world-layers-and-block-physics.md#L1067-L1070)). Id novo
  exige migracao de save, e o `[DECIDED]` do doc é append-only.
- **Não misturar com o dossiê 12** (bicho cavando): os dois escrevem no grid e ambos passam
  pelo mesmo `set_block`, mas um é causa de bicho e o outro é regra de apoio. As duas pernas
  têm gates diferentes e não se emprestam checagem.

## 7. Commits atômicos

(a) `BlockDefs`: tabela `_gravity` + `has_gravity` + `SAND`, com o registro re-impresso em
`--check-only` e **nenhuma** mudança de comportamento (nada consome a flag ainda);
(b) `VoxelWorld.is_supported` + `place_falling_block`, com 2.1 do §5 ainda vermelha e o motivo
impresso; (c) `BlockUpdateQueue` anexado ao `block_changed`, `flush` em `_sim_tick`, `stats()`
no `diagnostics()` e as checagens 1 e 6; (d) `FallingBlock` + spawner + `FIX`, com 2, 3 e 4;
(e) quiesce no save com 5; (f) hash com 7; (g) status + `README.md` + evidência em
`docs/evidence/fisica-de-blocos-17/`, com os números do clone limpo. Branch
`feat/fisica-de-blocos-que-caem-17`, merge `--no-ff` na `main`.

## 8. O que este dossiê não fecha

Nenhum gate de fase (mandato 4). Não é camadas verticais nem rebase de save, não é fluido, não
é luz, não é o `Landing.SHATTER` nem o dano de impacto — ambos ficam `[TARGET]` neste
arquivo enquanto não houver bloco com a flag correspondente. O dossiê 12
([`:186-189`](12-bicho-cavando-voxel.md#L186-L189)) já disse que cavar **não** preenche a
reserva dos ids: este aqui também não preenche — ele só gasta a flag de `SAND`, que é o bloco
que já existe.

## 9. Invenções do prompt, registradas aqui

- "`sofre_gravidade` em `SAND`/`GRAVEL`": `SAND` existe (id 4, tile 4, dureza 0,30), **`GRAVEL`
  não existe** — é o id 10 reservado do doc 10 e não está em
  [`block_defs.gd:10-22`](../../src/world/block_defs.gd#L10-L22). O primeiro lote é um bloco.
- "`BlockUpdateQueue` e `FallingBlock` como peças a serem *ligadas*": elas não existem para
  ligar, existem para serem escritas; o doc 10 as especifica em pseudocódigo e o próprio doc
  as lista como inexistentes em [`:652-659`](../design/10-world-layers-and-block-physics.md#L652-L659).
- "processar no tick de 20 Hz com orçamento": correto e alinhado com
  [`_sim_tick`](../../src/main.gd#L229)/[`SimClock`](../../src/core/sim_clock.gd#L5-L7) — mas o
  prompt chama de "orçamento" o que **não** é o budget de malha; os dois tetos são diferentes
  e o do meio de campo (`MESH_BUDGET`) não pode ser tocado por esta perna.
- "`Landing.SHATTER` vira item no chão": não há item no chão. Ver §6.
- "luz ambiente / `TORCH`" e "biomas/cavernas" aparecem como contexto no mesmo prompt; este
  dossiê não os cobre e o doc 10 mantém os dois `[OPEN]`
  ([`:1072-1086`](../design/10-world-layers-and-block-physics.md#L1072-L1086)).
- A tabela de geometria do doc 10 assume `Y_MIN = -64`, `Y_BUILD_LIMIT = 320`, `SEA_LEVEL = 64`
  ([`:84-88`](../design/10-world-layers-and-block-physics.md#L84-L88)); o código tem
  `CHUNK_SIZE_Y = 64` e `SEA_LEVEL = 26`
  ([`voxel_config.gd:6`](../../src/world/voxel_config.gd#L6),
  [`:13`](../../src/world/voxel_config.gd#L13)). Nada do prompt exige o rebase, e nada neste
  lote o faz.
