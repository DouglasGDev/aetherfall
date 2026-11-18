# 11 — Inventário com quantidade, pilhas, craft e construção

O pedido: *"pegar mecânicas do Veloren e mais blocos… foque nas mecânicas existentes
pra melhorar e novas desde o inventário até a criação, construção… preciso trabalhar
com quantidade também de blocos, fica de determinados blocos"*. Este documento descreve
**o que está em código agora** e marca como `[TARGET]` o que ficou de propósito de fora.
Ele não substitui o [documento 10](10-world-layers-and-block-physics.md), que especifica
camadas verticais e física de bloco — os dois se encontram no registro de blocos (§11.3).

Legenda de status é a do [`README.md`](README.md) da pasta.

## 11.1 O que fechou

| Pedido | Onde está | Como a suíte mede |
|---|---|---|
| Quantidade por bloco | `Inventory._ids`/`_counts` [inventory.gd:29-30](../../src/items/inventory.gd) | `tecla 1 comeca no capim com 32`, `colocar gastou um da pilha` |
| Teto diferente por bloco | `BlockDefs.stack_max` [block_defs.gd:161](../../src/world/block_defs.gd) | `pilha maxima vem do registro`, `bancada tem teto menor que bloco comun` |
| Inventário | 36 slots, grade 4×9, painel em `I` [hud.gd:445-537](../../src/ui/hud.gd) | `painel com 36 celulas`, `sem bancada so mostra as receitas de mao` |
| Hotbar | 10 pinos sobre os mesmos slots [inventory.gd:153-165](../../src/items/inventory.gd) | `hotbar tem 10 teclas pinadas nos slots`, `tecla 3 troca o pino` |
| Criar item novo | lista de receitas [recipes.gd:31-43](../../src/items/recipes.gd) | `1 madeira -> 4 tabuas, com o preco cobrado`, `a cadeia ate a bancada fecha` |
| Estação de craft | bancada é um bloco, casado por distância [player.gd:216-225](../../src/entities/player.gd) | `sem bancada so mostra as receitas de mao` |
| Mais blocos | 4 ids novos: bruta, tabua, vidro, bancada [block_defs.gd:123-137](../../src/world/block_defs.gd) | `pano de vidro sozinho tem 6 faces`, `vidro colado nao desenha a face de contato` |
| Construir com o que tem | `consume_selected` no colocar [player.gd:668-690](../../src/entities/player.gd) | `colocar gastou um da pilha` |

Os nomes de checagem acima vivem na suíte, e a lista `_steps`
([smoke_test.gd:63-95](../../tests/smoke_test.gd)) é a ordem dos passos que os medem.
Contagem de checagens e tempo de corrida não vivem aqui: são publicados no
[`README.md`](../../README.md) da raiz, derivados da corrida.

## 11.2 O que veio do Veloren, lido na fonte

Rasgado em `veloren/veloren@master` pelo caminho e número de linha; é leitura de fonte
aberta, não medição nossa `[CLAIMED]`:

| Fato lá | Referência | Como cá |
|---|---|---|
| 36 slots de personagem | `common/src/comp/inventory/mod.rs:44` (`DEFAULT_INVENTORY_SLOTS`) | `Inventory.SLOTS = 36` — mesmo número, mesma razão: 4 fileiras de 9 |
| Hotbar é fila do cliente sobre slots | `voxygen/src/hud/hotbar.rs` (10 slots) | `_pins[10]` apontando para índices de slot; não existe depósito separado |
| Empilhável é decisão da **classe** do item; teto é `u32::MAX` | `common/src/comp/inventory/item/mod.rs:873,889` | **aqui não**: o teto é um número por bloco, no registro (§11.3). É a única divergência numérica deste documento, e ela é `[DECIDED]` |
| Mesclar só se a definição for a mesma e empilhável | `mod.rs:398` | `pick_drop` exige `slot_block(i) == held_id` |
| Arrastar sobre pilha do mesmo item mescla, senão troca; o resto volta pro mundo | `server/src/events/inventory_manip.rs:814` | mescla e troca idênticas; o "volta pro mundo" ainda não existe (§11.5) |
| Partir é `take_amount(amount / 2)` | `voxygen/src/ui/widgets/slot.rs:250` | `split()` com divisão inteira: pilha de 1 não parte |
| Coletar preenche toda pilha parcial antes do primeiro buraco | `push_prefer_slot` + `insert` em `mod.rs` | laço 1 de `add()` sobre parciais, laço 2 sobre vazias |
| Receite é uma **lista**, não uma grade | `common/src/recipe.rs` (`Recipe { output, inputs, craft_sprite }`) | `Recipes.list()` — dicionários `{out, out_n, in, station}` |
| Estação é um sprite do mundo a `MAX_PICKUP_RANGE = 5,0` m | `common/src/consts.rs:2` | bancada é um bloco; a distância é o mesmo 5,0 |
| Entrada com valor 0 = ferramenta obrigatória não consumida | `recipe.rs` | ainda não usado: nenhuma receita nossa pede ferramenta `[TARGET]` |
| Conhecimento vem de um item `RecipeGroup` consumido | `inventory_manip.rs:668` | **não adaptado**: o jogador começa sabendo tudo e quem filtra a lista é a estação |
| Durabilidade é contagem de mortes (`MAX_DURABILITY = 12`) | `item/mod.rs` | **não adaptado**: bloco não quebra na mão |

## 11.3 O registro é a única fonte de número

Nada de inventário, craft ou malharia tem tabela própria. Um bloco responde a estas
perguntas no registro ([block_defs.gd:147-176](../../src/world/block_defs.gd)):

| Acesso | Pergunta | Consumido por |
|---|---|---|
| `hardness(b)` | quantos segundos de lavra? | `Player._update_target` → `target_hardness` |
| `stack_max(b)` | quantos cabem num slot? (0 = não é coletável) | `Inventory.add/space_for/split`, `Recipes.can_craft` |
| `drop_of(b)` | o que a lavra solta? (AIR = nada) | `Player._mine_target` |
| `draw_of(b)` | face opaca, alfa ou líquida? | face-culling e superfície do mesh |
| `is_solid` / `is_opaque` | colide? esconde a face do vizinho? | corpo, raycast, malharia |

Ids novos são append-only, como exige o save: **19 COBBLESTONE · 20 PLANK · 21 GLASS ·
22 BENCH**, com tiles 19..22 no atlas (`GRID = 8` dá 64 tiles). Os ids 9..18 continuam
reservados pelo documento 10, e os 0..8 não mudaram de valor — um save velho continua
legível quanto ao vocabulário.

Os números de pilha são nossos `[DECIDED]`: 64 para todo bloco comum (`STACK_DEFAULT`),
16 para a bancada (`STACK_BENCH`). O Veloren não tem número por item; lá quem decide é a
classe. Aqui o mundo é feito de blocos e o limite de carga é exatamente o que dá
trabalho carregar, então o teto mora no registro e o `Inventory` só pergunta. Bancada em
16 porque é um objeto com lógica própria e pilha de bancada é a porta para fabricar
estações em série.

O drop também é uma decisão de design, não um espelho do id: pedra lavrada vira **bruta**
(e é a bruta que entra na receita de pedra assentada), grama sem ferramenta solta
**terra**, folha não solta **nada** `[TARGET]` até existir muda.

## 11.4 `Inventory`: trinta e seis pilhas e dez teclas

Três arrays paralelos por índice de slot — ids, quantidades e os pinos das dez teclas
([inventory.gd:29-37](../../src/items/inventory.gd) e o cabeçalho, que cita a fonte de
cada regra). O tipo é `RefCounted`: o inventário não é nó de cena, então roda igual em
headless e no dedicado.

As operações, todas com a regra do Veloren anotada no arquivo:

- `add(b, n) → sobra` — laço 1 enche **toda** pilha parcial do mesmo bloco, na ordem dos
  slots; laço 2 abre buracos. Devolve o que **não** entrou, e é por isso que o chamador
  pode decidir o que fazer com a sobra em vez de perder item.
- `take(b, n) → saiu` — do último slot para trás, então as pilhas cheias da frente são as
  últimas a baixar. Quando um slot zera, o id volta a AIR: slot vazio não guarda memória.
- `space_for(b, want)` — quanto ainda entraria. É a pergunta que o `Player` faz **antes**
  de tirar o bloco do mundo.
- `pick_drop(i)` — mão vazia sobe a pilha inteira; mão cheia mescla se for o mesmo bloco
  e couber (e o que não coube continua na mão), senão **troca**.
- `split(i)` — metade por divisão inteira para a mão, exige mão vazia.
- `pin(key, i)` / `select(i)` — a tecla mostra o slot; `select` dá volta na hotbar
  (`posmod`), então a roda do mouse nunca cai num índice inválido.
- `stash_hand()` — fecha o painel devolvendo a mão primeiro para as parciais, depois para
  o primeiro buraco; devolve `false` se não coube tudo.

O kit inicial (`kit_counts`) é a antiga hotbar de 7 com número — grama 32, terra 32,
pedra/areia/neve 16, madeira/folhas 8 — mais tabua e bancada **em 0 de propósito**: a
cadeira madeira → tabua → bancada continua sendo o único caminho até eles. Isso não é
criativo: é o oposto, é o que faz o primeiro minuto do jogo ter o que fazer.

## 11.5 O que não cabe não sai do mundo

O Veloren escrevia a sobra de volta no mundo como entidade de item
(`inventory_manip.rs:814`). Nós não temos entidade de item — e uma pilha fantasma no chão
seria pior que o problema que resolve. Então o portão é **antes**:

- `Player._mine_target` pergunta `inv.space_for(drop, 1)` **antes** do `set_block(AIR)`
  ([player.gd:652-665](../../src/entities/player.gd)). Sem espaço, o bloco continua onde
  está, o acumulador zera e aparece no toast `inventario cheio: pedra bruta nao tem onde
  entrar`. A lavra não consome o bloco para jogar o drop fora.
- `Player.close_panel` recusa fechar com pilha na mão que não tem para onde voltar
  ([player.gd:300-306](../../src/entities/player.gd)): o `ESC` vira aviso, não perdão.
- `Recipes.can_craft` inclui o espaço de **saída** no portão
  ([recipes.gd:71-78](../../src/items/recipes.gd)), então não existe meio-craft: `craft`
  roda o portão inteiro antes do primeiro `take` e, se falhar, não toca em nada.

A entidade de item fica `[TARGET]`: ela é pré-requisito do drop de entidade do
documento 10 (§10.4) e da mesma linha deste. Enquanto não existe, o contrato é
"não minerado", e a suíte mede os dois lados (`cheio devolve a sobra e nao cria pilha
fora do teto`, `craft recusado nao toca em nada`).

## 11.6 Receitas: lista, estação e preço

Quatro receitas ([recipes.gd:31-43](../../src/items/recipes.gd)):

| Saída | Insumos | Estação | Por quê |
|---|---|---|---|
| 4 tabua | 1 madeira | mao | o primeiro degrau, sem estação: é o que se faz com o que está na mão |
| 1 bancada | 4 tabua | mao | a estação sai da própria cadeia, senão o craft não começa |
| 1 pedra | 4 pedra bruta | bancada | é o prêmio de a lavra soltar bruta |
| 1 vidro | 2 areia | bancada | areia em vidro **no lugar** de forja/caldeirão: simplificação explícita, até existir estação de calor (o documento 10 trata de lava) `[TARGET]` |

A estação é um bloco no mundo, casado por distância, no modelo do sprite do Veloren:
`Main._benches` mantém a lista ([main.gd:249-258](../../src/main.gd)) — entra no
`block_placed`, sai no `block_broken`, e é **reconstruída do diário de edições** no load
([main.gd:390-394](../../src/main.gd)), então não há estado de bancada para corromper.
`Player.bench_near()` pergunta ao `bench_provider` (um `Callable` injetado, não uma
referência de cena) e compara com `Recipes.BENCH_RANGE = 5,0`
([player.gd:216-225](../../src/entities/player.gd)). A varredura é de ~5 entradas, não do
mundo: é a mesma regra do documento 10 — nunca varrer o mundo por frame.

Conhecimento de receita **não** foi adaptado: sem pergaminho, sem `RecipeBook`. O filtro
que existe é o de estação (`Recipes.visible(bench_near)`), e a suíte mede que a lista
encolhe sem bancada por perto.

## 11.7 Vidro: por que existe uma classe de desenho

O vidro é sólido para pisar e **não** é opaco para o vizinho. A tentação era deixar
`opaco = 0` e nada mais — e aí a malharia desenharia a face do vidro com o material opaco
e um painel de vidro viraria um cubo leitoso. Então a face ganhou uma pergunta própria,
`draw_of` ∈ {OPAQUE, ALPHA, LIQUID} ([block_defs.gd:31-35](../../src/world/block_defs.gd)),
e a malharia decide a face por ela
([voxel_world.gd:463-483](../../src/world/voxel_world.gd)):

- vizinho do mesmo bloco não tem face entre si: dois panos de vidro colados não desenham
  a face interna (a suíte mede 20 tri no par, não 24);
- face ALPHA é cortada por vizinho opaco: o pano encostado na parede não desenha a face,
  e ela só aparece contra ar ou água;
- a malharia passou a emitir uma terceira superfície com `_mat_glass`
  (`TRANSPARENCY_ALPHA`, rugosidade 0,25, `NEAREST_WITH_MIPMAPS` —
  [voxel_world.gd:92-98](../../src/world/voxel_world.gd), aplicada em `:505`).
  `LINEAR` borrava o tile, que é quase puro alfa;
- o documento 10 pediu `opaco = 0` para folha em `Draw.OPAQUE`: as duas coisas continuam
  separadas. O tile do vidro escreve alfa por pixel — 0,85 na borda, 0,30 no anel
  interno, 0,10 no campo ([voxel_atlas.gd:214-221](../../src/world/voxel_atlas.gd)).

## 11.8 HUD: hotbar com número e painel de 36 celulas

A hotbar são 10 células com swatch, nome quando selecionada e **quantidade** quando > 1
(`build_hotbar` + `_refresh_slots`, [hud.gd:101-238](../../src/ui/hud.gd)); a legenda de
teclas passou a ser `1-9,0` porque o `0` é a décima tecla física, não a primeira
([input_actions.gd:10-15](../../src/input/input_actions.gd)).

O painel (`I`) é o inventário inteiro em 4×9, com o badge do pino em cada celula, cursor
em ambar, coluna de receitas à direita e rodapé de teclas. Sem mouse: o cursor anda com
o mesmo teclado que anda o personagem, `E` pega/solta, `Q` parte, `TAB` troca de receita,
`ENTER` crafta, e as dez teclas **repinam** o celula sob o cursor
([hud.gd:554-600](../../src/ui/hud.gd)). Com o painel aberto o `Player` segura o
movimento, o sprint, o planar e as mãos ([player.gd:411,481,489,627](../../src/entities/player.gd))
— senão abrir o inventário seria andar de lado para sempre.

Quem abre a tela é o `Player`, não o HUD: `panel_changed` é um sinal e o HUD escuta
([player.gd:20](../../src/entities/player.gd), [main.gd:89](../../src/main.gd)). O
refresh do conteúdo roda na cadência `REFRESH = 0,1 s` do `_process` do HUD, igual aos
slots.

## 11.9 Persistência: campo aditivo, sem bump de schema

`save_game` escreve `"inv": player.inv.to_dict()` ([main.gd:330](../../src/main.gd)); o
formato é `{slots: [[i,b,n]…], pins: […], sel: n, hand: [id,n]}` — só os slots com
quantidade, então um inventário vazio custa ~2 bytes de JSON e não 36 triples.

`SaveManager.SCHEMA` continua **1**. O campo é aditivo e o loader não tem whitelist de
chaves: `load_game` usa `inv` quando existe e, quando não existe, aplica o kit
([main.gd:372-375](../../src/main.gd)) — um save de antes da hotbar infinita não
acordaria um jogador sem blocos. O `SCHEMA = 2` está reservado ao rebase de Y do
documento 10, que é a única mudança que invalida saves de verdade. O `from_dict` faz
`clampi` em índice, id e quantidade, então um save corrompido não indexa fora do
registro.

## 11.10 Decidido × aberto

`[DECIDED]`

1. Inventário único de 36 slots; hotbar é dez **pinos** sobre ele, não um segundo
   depósito. Era a única forma de quantidade, arranjo e seleção serem um mecanismo só.
2. Teto de pilha é número por bloco no registro (64 comum, 16 bancada). Divergência
   explícita do Veloren, que decide por classe de item.
3. Lavrar é gated por espaço: sem entidade de item, o que não cabe **não sai do mundo**.
4. Craft é lista com estação por distância (5,0 m), e o portão exige insumo **e** espaço
   de saída antes de qualquer consumo.
5. Face tem classe própria (`draw_of`); `opaco` não carrega decisão de material.
6. Blocos novos entram por 19..22, append-only, tiles 19..22; 9..18 continuam do
   documento 10.

`[OPEN]`

1. Entidade de item no chão — fecha a sobra de coleta e o drop do documento 10. Sem
   prazo deste documento; é pré-requisito de §10.4.
2. Durabilidade como contagem de uso (o `MAX_DURABILITY = 12` deles) — hoje nada quebra
   na mão; decisão de quando a ferramenta entra, junto com o portão de ferramenta com
   quantidade 0 na receita.
3. Bolsas que **acrescentam** slots: `SLOTS` é constante e o painel é 4×9 fixo; a
   mudança é de layout de HUD, não de estrutura.
4. Conhecimento de receita por item consumido (o `RecipeGroup`), hoje inexistente.
5. Estação de calor: areia → vidro está indevidamente na bancada e é a única receita
   com essa dívida anotada no próprio arquivo.
6. Mudar a ordem de `add`/`take` (o Veloren tem cinco modos de ordenação de inventário)
   — nada aqui depende de ordem além do "parciais antes de vazias".
