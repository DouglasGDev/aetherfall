# 10 — Camadas verticais, física de blocos e Block Update Event

Linguagem de todo código deste documento: **GDScript 4.7** (a língua do projeto —
premissa 4 do [README](README.md)). É especificação `[TARGET]`: nada aqui existe em
`src/` ainda, e nada aqui compila contra o tree atual sem os passos de migração de
§10.7. Os números de baseline são `[MEASURED]` e vêm da suíte e do log citados.

Escopo: as três regras pedidas — faixas de Y com camadas, física de queda por bloco,
estrutura de dados + evento de atualização local — traduzidas para a arquitetura real
de `src/world/` (`VoxelConfig`, `BlockDefs`, `VoxelChunk`, `VoxelWorld`, `WorldGen`,
`Coords`, `VoxelBody`, `SimClock`, `SaveManager`).

## 10.1 Baseline medido (o que esta especificação pisa)

| Grandeza | Baseline / atualização indicada | Fonte |
|---|---|---|
| Chunk | 16 × 64 × 16, Y global 0..63 | [voxel_config.gd:5-7](../../src/world/voxel_config.gd) |
| Mundo | 8 × 8 chunks = 128 × 128 × 64 = 1 048 576 voxels | `WORLD_CHUNKS_X/Z`, `world_size_x()` |
| Nível do mar | `SEA_LEVEL = 26` | [voxel_config.gd:13](../../src/world/voxel_config.gd) |
| Altura no spawn | y = 31 | `.tools/suite_final.log:227` (`feet (64.5, 31.0, 64.5)`) |
| Geração | **980,5 ms** os 64 chunks | `.tools/suite_final.log:12` |
| Malharia | **4 799,1 ms** os 64 chunks (≈ 75 ms/chunk) | `.tools/suite_final.log:12` |
| Triângulos no mundo | 214 480 | `.tools/suite_final.log:227` |
| Pior passo de sim | 8,82 ms, nenhum tick perdido | `.tools/suite_final.log:225` |
| Blocos | 9 ids; tabelas de `solido`/`opaco`/`nome` apenas | [block_defs.gd:5-38](../../src/world/block_defs.gd) |
| Dureza | `Player._hardness()` não existe mais: quem responde é o registro (`BlockDefs.hardness`) | [player.gd:629](../../src/entities/player.gd) |
| Gravidade de **bloco** | não existe. Gravidade de **corpo** sim: 24,0 m/s², terminal 42,0 | [voxel_body.gd:6-15](../../src/entities/voxel_body.gd) |
| Queda do jogador | dano por velocidade de impacto; seguro 14 m/s, 3,5 por m/s, teto 55 | [player.gd:75-77](../../src/entities/player.gd), `:567-573` |
| Respiração / sufoco | medidor `air` + dano por período, ligado só a água | [player.gd:565-577](../../src/entities/player.gd) |
| Evento de bloco | `VoxelWorld.block_changed` **declarado e emitido, com zero inscritos** | [voxel_world.gd:6](../../src/world/voxel_world.gd), emissão em `:261` |
| Colisão voxel | binária: `aabb_hits_solid` pergunta `is_solid` por célula | [voxel_world.gd:300-310](../../src/world/voxel_world.gd) |
| Drop / item coletável | no baseline, minerar só apagava e contava; hoje há pilhas (§11), mas não entidade de item no mundo | contador atual em [main.gd:913-915](../../src/main.gd#L913-L915); coleta em [player.gd:670-683](../../src/entities/player.gd#L670-L683) |

**O baseline é o commit em que a spec foi escrita, e três linhas dele já foram pagas
pelo [documento 11](11-inventory-crafting.md):** a dureza saiu de `Player._hardness()`
e entrou no registro (`BlockDefs.hardness`, preservada 1:1), o drop virou pilha de
inventário (`BlockDefs.drop_of` + `Inventory.add`), e a hotbar de 7 virou dez pinos
sobre 36 slots. O que continua em falta é a **entidade de item no mundo**: sem ela o
que não cabe no inventário não é minerado, em vez de voltar para o chão — é por isso
que a linha 32 ainda importa para o §10.4.

A última linha mas uma é a peça que faltava: a regra 3 do pedido ("atualize a física
só nos vizinhos, nunca varra o mundo") não precisa de um mecanismo de detecção novo —
precisa de um **consumidor** do sinal que já existe e hoje ninguém escuta.

## 10.2 Eixo Y: faixas e camadas

### A conta que fecha o chunk de 384

`320 − (−64) = 384`. Com o fundo em Y = −64, o topo precisa ser **exclusivo** em 320
para a coluna ter exatamente 384 células (`Y ∈ [−64, 319]`). `[DECIDED]`

- **Limite superior de construção Y = 320 é exclusivo**: o bloco mais alto possível
  fica em Y = 319. É a convenção do Minecraft (build limit 320 ⇒ alturas 0..319) e a
  única leitura que faz o chunk 16 × 384 × 16 fechar com o fundo em −64.
- **Y = −64 é linha contínua de rocha matriz** em todas as colunas; acima dela o teto
  do bedrock é irregular, entre −60 e −63.
- **"Abaixo de Y = −54" é estrito**: lava em Y ≤ −55; superfície dos lagos em −55.

### Tabela de camadas

| # | Faixa de Y | Nome | Conteúdo | Nota |
|---|---|---|---|---|
| 1 | 320 (exclusivo) | teto de construção | — | `set_block` e `_try_place` recusam acima |
| 2 | 319 .. 65 | céu / relevo | AR, terreno acima do mar, WOOD/LEAVES | até 255 níveis de ar; custo zero com span (§10.7) |
| 3 | 64 | **nível do mar** | superfície de WATER | `SEA_LEVEL = 64` |
| 4 | 63 .. 1 | **subsolo raso** | solo nos 4 primeiros (DIRT/SAND/SNOW), depois STONE | predomínio de terra e pedra comum |
| 5 | 0 .. −8 | **transição** | STONE ↔ DEEPSLATE, rampa procedural | rampa em §10.6 |
| 6 | −9 .. −59 | **subterrâneo profundo** | DEEPSLATE de alta dureza, cavernas amplas | soleira de carve própria |
| 7 | ≤ −55 | lagos de lava | LAVA nos vazios da faixa 6 | regra de preenchimento, não de ruído |
| 8 | −60 .. −64 | **rocha matriz** | BEDROCK: teto irregular −60..−63, linha −64 contínua | `destrutivel = false` |

### Constantes (em `VoxelConfig`)

```gdscript
class_name VoxelConfig
## Constantes estruturais do mundo voxel. Mudar qualquer tamanho aqui invalida
## saves existentes (o formato de chunk e a chave de region derivam destes valores).

const CHUNK_SIZE_X: int = 16
const CHUNK_SIZE_Y: int = 384          # era 64; 320 - (-64) = 384
const CHUNK_SIZE_Z: int = 16

# --- eixo vertical [TARGET] ---
const Y_MIN: int = -64                 # primeira linha do mundo: bedrock continuo
const Y_BUILD_LIMIT: int = 320         # exclusivo: nada placeavel em y >= 320
const SEA_LEVEL: int = 64              # era 26
const Y_SOIL_BOTTOM: int = 1           # subsolo raso vai ate aqui (63..1)
const Y_TRANSITION_TOP: int = 0        # faixa 0..-8: stone <-> deepslate
const Y_TRANSITION_BOTTOM: int = -8
const Y_DEEP_TOP: int = -9             # faixa -9..-59: rocha profunda
const Y_DEEP_BOTTOM: int = -59
const Y_LAVA_LEVEL: int = -54          # vazio com y < -54 enche de lava
const Y_BEDROCK_TOP: int = -60         # teto irregular: -60 .. -63

const WORLD_CHUNKS_X: int = 8
const WORLD_CHUNKS_Z: int = 8
const AETHER_CELL: int = 4

static func world_size_x() -> int:
	return WORLD_CHUNKS_X * CHUNK_SIZE_X

static func world_size_z() -> int:
	return WORLD_CHUNKS_Z * CHUNK_SIZE_Z

static func world_height() -> int:
	return Y_BUILD_LIMIT - Y_MIN         # 384

## Unica porta de entrada para "existe mundo aqui?". O limite de construcao e
## exclusivo, entao o ultimo Y construivel e 319.
static func in_world_bounds(p: Vector3i) -> bool:
	return (
		p.x >= 0 and p.x < world_size_x()
		and p.z >= 0 and p.z < world_size_z()
		and p.y >= Y_MIN and p.y < Y_BUILD_LIMIT
	)
```

`in_world_bounds` é hoje `p.y >= 0 and p.y < CHUNK_SIZE_Y`
([voxel_config.gd:26-31](../../src/world/voxel_config.gd)) e é chamada por
`VoxelWorld.set_block` (voxel_world.gd:252) e por `Player._try_place`
(player.gd:689) — ou seja, **o limite de construção Y = 320 sai de graça dessas duas
chamadas**, sem tocar em HUD nem em input.

## 10.3 Estrutura de dados de bloco

### Por que script, não JSON

A tabela é em script, não um `.json` carregado em runtime:

1. As chaves são o `enum Block` e os ids **são gravados no save** — o cabeçalho de
   [block_defs.gd:3](../../src/world/block_defs.gd) já declara isso e exige
   append-only. Um JSON lido em runtime não tem como ser mais estável que o enum que
   indexa as tabelas.
2. `VoxelWorld` consulta propriedade de bloco **dentro do laço de malharia**
   (voxel_world.gd:455-488) e dentro de `aabb_hits_solid` (:300-310).
   `PackedByteArray` é acesso O(1) sem hash; um Dictionary de JSON seria um hash por
   voxel por iteração de bake.
3. Tipagem estática: `hardness(b) -> float` não compila se a tabela encolher; um campo
   ausente num JSON falha no meio de uma partida.

O que se justifica como JSON é um **export** da tabela — para ferramenta de balancea-
mento e para um teste de golden file — gerado a partir do script, nunca o contrário.

### Tabela de propriedades

Nove campos, cada um respondendo **uma** pergunta. Dois deles existem porque uma
propriedade única não separava perguntas distintas:

| Campo | Pergunta | Consumido por |
|---|---|---|
| `dureza` | quantos segundos de lavra? | `Player._apply_actions` (player.gd:655-658) |
| `solido` | corpo colide? | `aabb_hits_solid`, `is_supported`, raycast DDA |
| `opaco` | esconde a face do vizinho? | face-culling e AO (voxel_world.gd:475, 517) |
| `destrutivel` | pode virar AR por lavra/explosão? | caminho de quebra (novo gate) |
| `sofre_gravidade` | olha para Y−1 quando o vizinho muda? | `BlockUpdateQueue._try` |
| `classe_queda` | GRANULAR (sufocamento) ou HEAVY (impacto)? | `FallingBlock._fix` |
| `liquido` | segura queda? quebra queda? **nenhuma das duas** | `_landing_cell` |
| `substituivel` | outro bloco pode ocupar esta célula? | `_try_place`, `place_falling_block` |
| `quebra_queda` | bloco em queda se destrói sobre este? | `_landing_cell` |

`dureza` = segundos de lavra com a ferramenta básica: a suíte já mede
`tempo de mineracao == dureza` ([smoke_test.gd:807](../../tests/smoke_test.gd)). Essa
migração **já foi paga**: os sete valores originais vivem 1:1 no registro
([block_defs.gd:114-122](../../src/world/block_defs.gd), `_hard` preenchido em
`init_tables()`; o acesso e `hardness()` em `:171`)
e `Player` pergunta a `BlockDefs.hardness()`, sem tabela própria. Os números novos
abaixo continuam `[TARGET]` — são durezas de blocos que ainda não existem.

| ID | Bloco | dureza | sólido | opaco | destrut. | gravidade | classe de queda | líquido | substituível | quebra queda | tile |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | AIR | 0 | não | não | — | não | — | não | sim | não | — |
| 1 | GRASS | 0,38 | sim | sim | sim | não | — | não | não | não | 0/1 |
| 2 | DIRT | 0,35 | sim | sim | sim | não | — | não | não | não | 2 |
| 3 | STONE | 0,95 | sim | sim | sim | não | — | não | não | não | 3 |
| 4 | SAND | 0,30 | sim | sim | sim | **sim** | **granular** | não | não | não | 4 |
| 5 | SNOW | 0,25 | sim | sim | sim | não | — | não | não | não | 5 |
| 6 | WOOD | 0,55 | sim | sim | sim | não | — | não | não | não | 6/7 |
| 7 | LEAVES | 0,22 | sim | **não** | sim | não | — | não | não | não | 8 |
| 8 | WATER | 0,05 | não | não | **não** | não | — | **sim** | sim | não | 9 |
| 9 | DEEPSLATE | 1,75 | sim | sim | sim | não | — | não | não | não | 10 |
| 10 | GRAVEL | 0,60 | sim | sim | sim | **sim** | **granular** | não | não | não | 11 |
| 11 | LAVA | — | não | não | **não** | não | — | **sim** | sim | não | 12 |
| 12 | BEDROCK | — | sim | sim | **não** | não | — | não | não | não | 13 |
| 13 | POWDER_SNOW | 0,15 | não | não | sim | **sim** | **granular** | não | sim | **sim** | 14 |
| 14 | ANVIL | 2,00 | sim | sim | sim | **sim** | **pesado** | não | não | não | 15 |
| 15 | ROCK_LOOSE | 1,10 | sim | sim | sim | **sim** | **pesado** | não | não | não | 16 |
| 16 | TORCH | 0,05 | não | não | sim | não | — | não | sim | **sim** | 17 |
| 17 | PLANT | 0,05 | não | não | sim | não | — | não | sim | **sim** | 18 |
| 18 | SLAB | 0,95 | sim | sim | sim | não | — | não | não | **sim** | 3 |

Regras que a tabela carrega:

- **Líquido não segura e não quebra.** A regra 2 distingue os três casos: vazio ou
  líquido ⇒ continua caindo; não-sólido com `quebra_queda` ⇒ destrói; sólido ⇒ fixa.
  Um único campo "não sólido" daria a resposta errada para a lava.
- **`quebra_queda` ≠ `not solido`.** SLAB é sólido para movimento (você pisa nela) e é
  alvo de quebra para queda — no modelo de colisão binário de hoje
  (voxel_world.gd:300-310) não existe "colisão de meia altura", então a laje precisa
  dos dois flags separados ou a regra do pedido vira mentira. A colisão parcial fica
  `[OPEN]` (§10.9).
- **`destrutivel == false`** (BEDROCK, WATER, LAVA) trava a lavra **antes** do
  `set_block(AIR)`, que hoje é chamado sem consultar destrutibilidade nenhuma
  ([player.gd:678](../../src/entities/player.gd)).
- **IDs 9..18 são append-only.** AIR = 0 e os oito existentes não mudam de valor, então
  um save velho continua legível *quanto ao vocabulário de blocos*.
- **Atlas.** `VoxelAtlas.GRID = 8` dá 64 tiles e só 10 estão tomados
  ([voxel_atlas.gd:5-6](../../src/world/voxel_atlas.gd), `TILE_WATER = 9`): os tiles
  10..18 cabem sem mexer no layout. Três blocos novos não são um cubo comum:
  - **SLAB** não pede geometria nova: `_emit_face` já aceita `top_drop`, usado hoje
    para a superfície da água (`WATER_TOP_DROP = 0.12`,
    [voxel_world.gd:34](../../src/world/voxel_world.gd), aplicado em `:569-570`). Uma
    laje baixa é `top_drop = 0,5` na mesma função.
  - **LAVA** pede emissão. O material opaco único (`_mat_opaque`, :77-82) não emite; a
    malharia já separa um segundo surface para água (`_mat_water`, :499-502) e um
    terceiro para o vidro (`_mat_glass`, :503-506). `[TARGET]`: um quarto surface com
    `emission_enabled = true` e o mesmo atlas. Sem isso a lava é um cubo cinza.
  - **TORCH/PLANT** como poste/cruzeta pedem uma tabela de shapes que não existe. A
    regra de física funciona sem isso; o visual fica `[OPEN]`.

### O registro em código

```gdscript
class_name BlockDefs
## Registro de blocos: solidez, opacidade, dureza, gravidade, destrutibilidade,
## tiles do atlas e nome. Ids estaveis: sao gravados no save. Remover/reordenar
## exige migracao (SaveManager.SCHEMA e WorldGen.GEN_VERSION).

enum Block { AIR = 0, GRASS = 1, DIRT = 2, STONE = 3, SAND = 4, SNOW = 5, WOOD = 6,
	LEAVES = 7, WATER = 8, DEEPSLATE = 9, GRAVEL = 10, LAVA = 11, BEDROCK = 12,
	POWDER_SNOW = 13, ANVIL = 14, ROCK_LOOSE = 15, TORCH = 16, PLANT = 17, SLAB = 18 }

enum FallClass { NONE = 0, GRANULAR = 1, HEAVY = 2 }   # sufocamento vs. impacto

const COUNT: int = 19

# tiles novos (10..18); os 0..9 existentes nao mudam
const TILE_DEEPSLATE: int = 10
const TILE_GRAVEL: int = 11
const TILE_LAVA: int = 12
const TILE_BEDROCK: int = 13
const TILE_POWDER: int = 14
const TILE_ANVIL: int = 15
const TILE_ROCK: int = 16
const TILE_TORCH: int = 17
const TILE_PLANT: int = 18

static var _solid := PackedByteArray()
static var _opaque := PackedByteArray()
static var _destructible := PackedByteArray()
static var _gravity := PackedByteArray()
static var _fall_class := PackedByteArray()
static var _liquid := PackedByteArray()
static var _replaceable := PackedByteArray()
static var _breaks_fall := PackedByteArray()
static var _hardness := PackedFloat32Array()
static var _names := PackedStringArray()


static func init_tables() -> void:
	if _names.size() == COUNT:
		return
	# Cada resize numa variavel propria, como ja faz block_defs.gd:39-41. Um
	# `for a in [_solid, _opaque, ...]: a.resize(COUNT)` NAO funciona: PackedByteArray
	# e copy-on-write em GDScript 4, entao `a` e uma copia e o resize morre nela -
	# as tabelas ficariam tamanho 0 e o primeiro acesso daria erro de indice fora
	# do range em plena malharia.
	_solid.resize(COUNT)
	_opaque.resize(COUNT)
	_destructible.resize(COUNT)
	_gravity.resize(COUNT)
	_fall_class.resize(COUNT)
	_liquid.resize(COUNT)
	_replaceable.resize(COUNT)
	_breaks_fall.resize(COUNT)
	_hardness.resize(COUNT)
	_names.resize(COUNT)
	for i in COUNT:
		_solid[i] = 1
		_opaque[i] = 1
		_destructible[i] = 1
		_gravity[i] = 0
		_fall_class[i] = FallClass.NONE
		_liquid[i] = 0
		_replaceable[i] = 0
		_breaks_fall[i] = 0
		_hardness[i] = 0.4
	# --- durezas que ja existem no jogo: preservadas 1:1 de Player._hardness()
	_hardness[Block.STONE] = 0.95
	_hardness[Block.WOOD] = 0.55
	_hardness[Block.LEAVES] = 0.22
	_hardness[Block.DIRT] = 0.35
	_hardness[Block.GRASS] = 0.38
	_hardness[Block.SAND] = 0.30
	_hardness[Block.SNOW] = 0.25
	# --- ar
	_solid[Block.AIR] = 0
	_opaque[Block.AIR] = 0
	_destructible[Block.AIR] = 0
	_replaceable[Block.AIR] = 1
	_hardness[Block.AIR] = 0.0
	# --- folha nao e opaca (ja era hoje)
	_opaque[Block.LEAVES] = 0
	# --- liquidos: nao solidos, nao opacos, ocupaveis, inquebraveis por lavra,
	#     e NENHUM deles quebra uma queda (a regra do pedido diz "vazio ou liquido"
	#     = continua caindo)
	for l in [Block.WATER, Block.LAVA]:
		_solid[l] = 0
		_opaque[l] = 0
		_destructible[l] = 0
		_liquid[l] = 1
		_replaceable[l] = 1
	_hardness[Block.WATER] = 0.05
	# dureza 0 em quem nao se quebra por lavra: o numero nao e lido pelo caminho de
	# quebrar (o gate de `destrutivel` vem antes), mas e lido pelo HUD, e "segundos"
	# para algo inquebravel nao pode ser o default herdado das rochas.
	_hardness[Block.LAVA] = 0.0
	# --- rocha profunda e os novos solidos de construcao
	_hardness[Block.DEEPSLATE] = 1.75
	_hardness[Block.GRAVEL] = 0.60
	_hardness[Block.ANVIL] = 2.00
	_hardness[Block.ROCK_LOOSE] = 1.10
	_hardness[Block.SLAB] = 0.95
	# --- rocha matriz: solida, opaca, IMDESTRUTIVEL
	_hardness[Block.BEDROCK] = 0.0
	_destructible[Block.BEDROCK] = 0
	# --- gravidade e classe de queda
	for g in [Block.SAND, Block.GRAVEL, Block.POWDER_SNOW]:
		_gravity[g] = 1
		_fall_class[g] = FallClass.GRANULAR
	for h in [Block.ANVIL, Block.ROCK_LOOSE]:
		_gravity[h] = 1
		_fall_class[h] = FallClass.HEAVY
	# --- neve fofa e plantas: nao solidas, ocupaveis, e quebram uma queda
	for t in [Block.POWDER_SNOW, Block.TORCH, Block.PLANT]:
		_solid[t] = 0
		_opaque[t] = 0
		_replaceable[t] = 1
		_breaks_fall[t] = 1
	_hardness[Block.POWDER_SNOW] = 0.15
	_hardness[Block.TORCH] = 0.05
	_hardness[Block.PLANT] = 0.05
	# --- laje e solida para pisar mas quebra queda (colisao parcial e [OPEN])
	_breaks_fall[Block.SLAB] = 1
	# --- nomes
	_names[Block.AIR] = "ar"
	_names[Block.GRASS] = "grama"
	_names[Block.DIRT] = "terra"
	_names[Block.STONE] = "pedra"
	_names[Block.SAND] = "areia"
	_names[Block.SNOW] = "neve"
	_names[Block.WOOD] = "madeira"
	_names[Block.LEAVES] = "folhas"
	_names[Block.WATER] = "agua"
	_names[Block.DEEPSLATE] = "rocha profunda"
	_names[Block.GRAVEL] = "cascalho"
	_names[Block.LAVA] = "lava"
	_names[Block.BEDROCK] = "rocha matriz"
	_names[Block.POWDER_SNOW] = "neve fofa"
	_names[Block.ANVIL] = "bigorna"
	_names[Block.ROCK_LOOSE] = "pedra solta"
	_names[Block.TORCH] = "tocha"
	_names[Block.PLANT] = "planta"
	_names[Block.SLAB] = "laje"


static func is_solid(b: int) -> bool:
	return _solid[b] == 1

static func is_opaque(b: int) -> bool:
	return _opaque[b] == 1

static func is_liquid(b: int) -> bool:
	return _liquid[b] == 1

static func is_destructible(b: int) -> bool:
	return _destructible[b] == 1

## Regra 2 do pedido: so granulares e pesados olham para Y-1.
static func has_gravity(b: int) -> bool:
	return _gravity[b] == 1

static func fall_class(b: int) -> int:
	return _fall_class[b]

## Outro bloco pode ocupar esta celula (ar, liquidos, tocha, planta, neve fofa).
static func is_replaceable(b: int) -> bool:
	return _replaceable[b] == 1

## Bloco em queda se destrói sobre este.
static func breaks_a_fall(b: int) -> bool:
	return _breaks_fall[b] == 1

## Celula que nao deixa respirar (sufocamento): todo bloco que NAO pode ser ocupado
## por outro - solido, ou laje - mais todo granular, inclusive a neve fofa que e
## ocupavel. Derivado de campos que ja existem; nao e um decimo flag.
static func blocks_air(b: int) -> bool:
	return _fall_class[b] == FallClass.GRANULAR or not is_replaceable(b)

static func hardness(b: int) -> float:
	return _hardness[b]

static func display_name(b: int) -> String:
	return _names[b]
```

`tile_for` e `swatch` mantêm as assinaturas de hoje
[block_defs.gd:180-243](../../src/world/block_defs.gd); `swatch` ganha um color por id
novo (HUD e legenda, [hud.gd](../../src/ui/hud.gd)). O `_hardness` do esqueleto acima
chama-se `_hard` no arquivo real, e o registro já carrega três campos que este
documento não pediu e o documento 11 sim: `stack_max` (teto de pilha por bloco),
`drop_of` (o que a lavra solta) e `draw_of` (classe de desenho da face — foi assim que
o vidro entrou sem sobrecarregar `opaco`).

`placeable_blocks()` **não existe mais**: a hotbar deixou de ser uma lista própria e
virou dez pinos sobre os 36 slots do inventário, então o que escolhe o que o jogador
pode colocar é a pilha selecionada ([inventory.gd](../../src/items/inventory.gd)).
Sobrou `default_hotbar_blocks()` ([block_defs.gd:245](../../src/world/block_defs.gd)),
que só ordena o kit inicial. Os blocos novos desta spec entram no jogo pelo drop e pelo
craft, não por uma lista de hotbar.

## 10.4 Física e gravidade dos blocos

### Máquina de estados

```
GRID  --(evento: o bloco de baixo virou vazio ou liquido)-->  FALLING  --+--(apoio solido)--> GRID (fix)
                                                                         |--(quebra_queda)--> SHATTER -> drop
                                                                         |--(teto de ticks)--> SHATTER -> drop
```

`FALLING` é entidade do mundo, não voxel: `VoxelBody` com `dims = (0.98, 0.98, 0.98)`
e `gravity = 24.0`, o valor do corpo hoje ([voxel_body.gd:6-15](../../src/entities/voxel_body.gd)).
É o mesmo integrador do jogador e do lobo, portanto roda igual em cliente e em
dedicado headless — que é a premissa declarada no cabeçalho de `VoxelWorld`
(voxel_world.gd:2-4). Cubo de 0,98 centrado em `cell + 0.5` ocupa **exatamente uma**
coluna de células (`0.5 ± 0.49 ⊂ [0, 1)`), que é o que permite derivar a célula-alvo
do corpo sem ambiguidade.

Integração `[TARGET]` no tick de simulação, em `Main._sim_tick()`
([main.gd:264-298](../../src/main.gd#L264-L298)), 20 Hz (`SimClock.HZ`,
[sim_clock.gd:5-7](../../src/core/sim_clock.gd)) — nunca em `_process`: queda de
bloco é estado de mundo, e o hash de estado do gate P0 depende disso. O `TickJournal`
atual só assina uma projeção mínima, **sem corpos nem comandos**
([tick_journal.gd:16-44](../../src/persistence/tick_journal.gd#L16-L44)); não cobre a
entidade de queda proposta nem fecha esse gate. Hoje, jogador e locomoção/timers do lobo
ainda mudam por frame de física ([main.gd:256](../../src/main.gd#L256),
[wolf.gd:923-968](../../src/entities/wolf.gd#L923-L968)).

### Matemática

```
g           = 24,0 m/s²                       # VoxelBody.gravity
v(h)        = sqrt(2 g h)                     # h = Y_origem - Y_destino, em blocos
v_term      = 42,0 m/s                        # TERMINAL_VELOCITY => h_term = 36,75 blocos
h_segura    = FALL_SAFE_SPEED^2 / (2 g)
            = 14^2 / 48 = 4,08 blocos         # derivado das constantes do jogador
dmg_peso(h) = clampf((h - 4,08) * 3,0, 0, 55)
              # 3,0 por bloco: um jogador caindo h blocos toma 3,5 * (v(h) - 14),
              # ~4,2 por bloco na faixa de 20 m/s. O bloco pesa menos que um corpo:
              # 3,0, e o teto e o mesmo FALL_DAMAGE_MAX = 55 (player.gd:77).
granular    : dano 0 no impacto; quem fica sob o bloco entra em sufocamento
sufoco      : mesmo caminho de _update_breath (player.gd:572-584) =>
              7 de dano a cada 1,0 s enquanto a celula dos olhos for enterrante
tempo de queda do teto ao fundo (383 blocos): ~11 s < MAX_FALL_TICKS (20 s)
```

Exemplos (`[TARGET]`, calculados da fórmula, não medidos): bigorna caindo 20 blocos →
(20 − 4,08) × 3 = **47,7** de dano num jogador de `max_hp = 100`
([player.gd:98](../../src/entities/player.gd)); 36 blocos → teto **55**; 4 blocos →
**0**.

### A entidade

```gdscript
class_name FallingBlock
extends Node3D
## [TARGET] Bloco granular/peso em queda. Nao existe nenhuma antes de um evento de
## vizinho dizer que o suporte sumiu, entao o numero de entidades deste tipo e sempre
## menor ou igual ao numero de edicoes de bloco do ultimo tick.

const SIZE: float = 0.98
const IMPACT_MIN_HEIGHT: float = 4.08      # h_segura = FALL_SAFE_SPEED^2 / (2g)
const IMPACT_DMG_PER_BLOCK: float = 3.0
const IMPACT_DAMAGE_MAX: float = 55.0      # mesmo teto do dano de queda do player
const MAX_FALL_TICKS: int = 400            # 20 s a 20 Hz; a queda maxima real e ~11 s

var world: VoxelWorld
var block: int = BlockDefs.Block.AIR
var origin_y: int = 0
var _ticks: int = 0
var _settled: bool = false
var body: VoxelBody = VoxelBody.new()

enum Landing { NONE, FIX, SHATTER }

## Quem aplica dano em entidade do mundo e o dono da cena, no mesmo padrao de
## Player.attacked -> Main._on_attacked (main.gd:731-733): as assinaturas de
## take_damage diferentes entre Player (amount, from) e Wolf (amount, actor, from)
## nao permitem chamar de dentro daqui sem um `is Player` que nao existe hoje.
signal impact(targets: Array, at: Vector3, amount: float, suffocate: bool)
var entity_provider: Callable


func setup(p_world: VoxelWorld, cell: Vector3i, p_block: int, p_provider: Callable) -> void:
	world = p_world
	block = p_block
	origin_y = cell.y
	entity_provider = p_provider
	# feet_pos e o canto inferior da AABB: assim o cubo comeca exatamente na celula.
	body.setup(world, Vector3(float(cell.x) + 0.5, float(cell.y), float(cell.z) + 0.5),
		Vector3(SIZE, SIZE, SIZE))
	add_child(_make_mesh(p_block))


## Visual da entidade: cubo com a cor de referencia do bloco. `BlockDefs.swatch()` ja
## existe para HUD e legenda (block_defs.gd:104-116) e e a unica fonte de cor por
## tipo sem textura de atlas - uma BoxMesh com o atlas precisaria de UV por face, que
## e o trabalho de malharia de 10.3, nao um pre-requisito da fisica.
func _make_mesh(b: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SIZE, SIZE, SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BlockDefs.swatch(b)
	mat.roughness = 0.9
	box.material = mat
	mi.mesh = box
	return mi


func sim_step(dt: float) -> void:
	if _settled:
		return
	_ticks += 1
	body.apply_gravity(dt)
	body.move_and_collide(dt)              # zera vy no choque vertical
	var landing := _landing_cell()
	match landing[0]:
		Landing.FIX:
			_fix(landing[1])
		Landing.SHATTER:
			_shatter(landing[1])
		_:
			if _ticks >= MAX_FALL_TICKS:
				_shatter(Coords.to_block(body.feet_pos))


## A celula de fixacao e derivada do APOIO, nunca da posicao do corpo: o integrador
## para em substep de 0,35 m e a AABB pode parar ate um substep acima do solo, o que
## trocaria a celula-alvo entre execucoes. Com feet parado no topo exato do apoio
## (VoxelBody so aplica o incremento que nao colide), `apoio + (0,1,0)` e a unica
## leitura correta da celula que o cubo ocupa.
func _landing_cell() -> Array:
	var cx := int(floorf(body.feet_pos.x))
	var cz := int(floorf(body.feet_pos.z))
	var below := Vector3i(cx, int(floorf(body.feet_pos.y - 0.02)), cz)
	var b: int = world.get_block(below)
	# `breaks_a_fall` vem ANTES de `is_solid`: a laje e solida para pisar e alvo de
	# quebra para queda ao mesmo tempo, e so esta ordem expressa a regra do pedido.
	if BlockDefs.breaks_a_fall(b):
		return [Landing.SHATTER, below]       # tocha/planta/laje/neve fofa
	if BlockDefs.is_solid(b):
		return [Landing.FIX, below + Vector3i.UP]
	return [Landing.NONE, below]              # AR e liquidos: continua caindo
```

```gdscript
func _fix(cell: Vector3i) -> void:
	_settled = true
	if not world.place_falling_block(cell, block):
		_shatter(cell)                        # nao coube: vira item, nao fantasma
		return
	var h := float(origin_y - cell.y)
	var cls: int = BlockDefs.fall_class(block)
	var targets := _overlapping(cell)
	if cls == BlockDefs.FallClass.HEAVY and not targets.is_empty():
		impact.emit(targets, Coords.block_center(cell),
			clampf((h - IMPACT_MIN_HEIGHT) * IMPACT_DMG_PER_BLOCK, 0.0, IMPACT_DAMAGE_MAX),
			false)
	elif cls == BlockDefs.FallClass.GRANULAR and not targets.is_empty():
		# granular: o bloco FICA no grid e quem estava ali dentro fica enterrado.
		# O dano e periodico e vem do caminho de respiracao, nao desta entidade.
		impact.emit(targets, Coords.block_center(cell), 0.0, true)
	queue_free()


func _shatter(cell: Vector3i) -> void:
	_settled = true
	DropSpawner.spawn(world, Coords.block_center(cell), block)   # [TARGET]: ver a tabela
	queue_free()


func _overlapping(cell: Vector3i) -> Array:
	if not entity_provider.is_valid():
		return []
	var box := AABB(Vector3(cell), Vector3.ONE)
	var out: Array = []
	for e in entity_provider.call():
		if e is Node3D and e.has_method("body_aabb") and e.body_aabb().intersects(box):
			out.append(e)
	return out
```

`e.has_method("body_aabb")` não é decoração: `body_aabb()` já é o contrato de
entidade visada do projeto (player.gd:616, [wolf.gd:246-247](../../src/entities/wolf.gd#L246-L247)),
e `entity_provider` é o `Callable` que `Main` injeta hoje no jogador
([main.gd:150](../../src/main.gd#L150) → `targets_under_crosshair`,
[main.gd:813-818](../../src/main.gd#L813-L818)).

### Da fila para a entidade

```gdscript
class_name FallingBlockSpawner
## [TARGET] Unico lugar que apaga um voxel e cria corpo. Ficar num ponto so da para
## auditar a conversao (Cronica) e para garantir que o voxel some ANTES de o corpo
## existir: o contrario deixaria dois blocos na mesma celula por um tick.

static var scene_root: Node3D               # Main injeta, como injeta entity_provider
static var provider: Callable
static var falling: Array[FallingBlock] = []   # a lista que Main._sim_tick percorre


static func convert(world: VoxelWorld, cell: Vector3i, b: int) -> void:
	if not world.set_block(cell, BlockDefs.Block.AIR):
		return                                # a celula ja mudou de dono neste tick
	var f := FallingBlock.new()
	f.setup(world, cell, b, provider)
	f.impact.connect(scene_root._on_block_impact)
	falling.append(f)
	scene_root.add_child(f)
```

O `set_block(AIR)` daqui **dispara o próprio evento que o converte**: `block_changed`
chega de novo em `BlockUpdateQueue._on_block_changed`, que testa `(x, y+1, z)` — o
bloco de cima, que acabou de perder o apoio. É assim que uma pilha de areia desce em
cascata sem nenhum código de cascata: cada remoção produz o próximo evento, e o teto
`MAX_PER_TICK` mais o `_pending.has(p)` são o que limita o alcance por tick.

### Por que a cascada termina

Um bloco convertido que pousa de volta na **própria célula de origem** não cria loop:
a fila só converte quando `is_supported` é falso, e se ele voltou a estar em `origem`
então `origem − 1` é sólido, e a próxima avaliação da origem retorna cedo. Não há
trava de reentrância nem flag de supressão no design — o que encerra é a própria
regra de suporte. (É por isso também que `_landing_cell` não pode ter um "não fixe na
origem" absoluto: com a AABB parada exatamente no topo do apoio, esse guard faria o
bloco cair para sempre em cima de um suporte recém-colocado.)

### O que ainda não existe para essa regra fechar

| Necessidade | Estado hoje | Custo real |
|---|---|---|
| Entidade física de bloco | inexistente | `src/entities/falling_block.gd` + spawner e step em `Main` |
| Item coletável / drop | entidade no mundo inexistente; pilhas já existem (§11). `_on_block_broken` atualiza o contador e as bancadas ([main.gd:921-924](../../src/main.gd#L921-L924)) | sistema inteiro: `DropItem` (VoxelBody pequeno) + pickup + destino no HUD. O `_shatter` do pedido **não tem onde cair** sem isso |
| Sufocamento em jogador | o medidor `air` existe, mas `_update_breath` só olha água (player.gd:572-574) | uma linha: `no_air := world.is_water_xyz(olho) or BlockDefs.blocks_air(world.get_block(olho))` — `blocks_air` é derivado dos campos de §10.3, não um décimo flag |
| Sufocamento em NPC | o lobo **não tem medidor de ar** | ou um `Breath` comum aos dois, ou dano por tick direto no NPC enterrado |
| Dano vindo de objeto do mundo | `take_damage` é `(amount, from)` no jogador e `(amount, actor, from)` no lobo | dispatch no dono da cena (padrão `Main._on_attacked`, main.gd:946-949); nenhum `is Player` dentro da física |
| Blocos com geometria própria | a malharia só conhece cubos (`FACE_CORNERS`, voxel_world.gd:14-21) | SLAB grátis via `top_drop`; LAVA pede surface emissivo; TORCH/PLANT pedem shape table |

## 10.5 Block Update Event — o que nunca varre o mundo

A garantia de performance não é um orçamento de CPU: é o fato de que **a única porta de
entrada para "este voxel tem gravidade?" é o sinal `block_changed`**. Posição que
ninguém colocou na fila não é lida, nunca, em nenhum frame.

```gdscript
class_name BlockUpdateQueue
## [TARGET] Fila de eventos de bloco, 20 Hz. Nada daqui varre o mundo: os unicos
## vetores que entram em _pending chegam por VoxelWorld.block_changed.

const MAX_PER_TICK: int = 256          # teto de resolucoes por tick
const MAX_QUEUED: int = 8192           # teto de memoria da fila
const RECHECK_DELAY: int = 1           # tick; faz a cascada descer em passos

var _world: VoxelWorld
var _pending: Dictionary = {}          # Vector3i -> int (tick do teste)
var _tick_now: int = 0
var _overflow: int = 0


func attach(world: VoxelWorld) -> void:
	_world = world
	world.block_changed.connect(_on_block_changed)   # voxel_world.gd:6, :261


## A regra do pedido e literal: quando um bloco muda, olha-se o vizinho que perdeu
## ou ganhou suporte (o de cima) e o proprio bloco colocado. Dois testes por evento,
## independente do tamanho do mundo.
func _on_block_changed(pos: Vector3i, _prev: int, now: int) -> void:
	_try(Vector3i(pos.x, pos.y + 1, pos.z))
	if now != BlockDefs.Block.AIR:
		_try(pos)


func _try(p: Vector3i) -> void:
	if _pending.has(p):
		return
	if not BlockDefs.has_gravity(_world.get_block(p)):
		return                              # ~99% dos eventos morrem aqui: 1 leitura
	if _pending.size() >= MAX_QUEUED:
		_overflow += 1                      # expansao gigante: um grao adiado, nao perdido
		return
	_pending[p] = _tick_now + RECHECK_DELAY


func flush(tick: int) -> int:
	_tick_now = tick
	var due := _due(tick)                   # snapshot ordenado: determinismo do hash
	var done := 0
	for p in due:
		if done >= MAX_PER_TICK:
			break                           # o resto continua em _pending para o proximo
		done += 1
		_pending.erase(p)
		_resolve(p)
	return done


## Ordem de resolucao: de cima para baixo (Y desc), depois X, depois Z. Uma pilha de
## N areias sem suporte resolve em N ticks com esta ordem; em ordem de dicionario
## resolveria em ordem arbitraria e o hash de estado mudaria entre execucoes.
func _due(tick: int) -> Array:
	var out: Array = []
	for p in _pending:
		if int(_pending[p]) <= tick:
			out.append(p)
	out.sort_custom(func(a, b):
		if a.y != b.y:
			return a.y > b.y
		if a.x != b.x:
			return a.x < b.x
		return a.z < b.z)
	return out


func _resolve(p: Vector3i) -> void:
	var b: int = _world.get_block(p)
	if not BlockDefs.has_gravity(b):
		return
	if _world.is_supported(p):
		return
	FallingBlockSpawner.convert(_world, p, b)   # set_block(AIR) + entidade FallingBlock


## Visivel no overlay, nunca em log silencioso: estourar o teto da fila adia graos,
## nao os perde, e o numero conteudo e o que diz se o teto esta apertado.
func stats() -> Dictionary:
	return {"queued": _pending.size(), "overflow": _overflow}
```

`Main.diagnostics()` ([main.gd:1152-1163](../../src/main.gd#L1152-L1163)) ganha `"block_updates":
updates.stats()` junto de `"dropped_ticks"` — os dois são a mesma categoria de medida
(quantos ticks de simulação o orçamento não absorveu), e sem o número a discussão sobre
`MAX_PER_TICK` e `MAX_QUEUED` seria opinião.

`Main._sim_tick()` passa a chamar, uma vez por tick, `updates.flush(clock.tick)` e
depois `for f in falling: f.sim_step(dt)` — a fila vem **antes** das entidades, para
que uma conversão só integre no tick seguinte.

Explosões, quando existirem, não adicionam mecanismo: cada célula destruída passa pelo
mesmo `set_block`, e portanto pelos mesmos dois testes de vizinho. O ponto único de
mutação do grid é `VoxelWorld.set_block`
([voxel_world.gd:251-262](../../src/world/voxel_world.gd)) — que retorna cedo se
`prev == b` (:255) e é o único lugar que escreve em `_flat`/`VoxelChunk` além da
geração e de `apply_edits` (:163-173). É isso que torna a regra "só nos vizinhos"
verificável, e não apenas intencional.

Custo por evento, no pior caso: 2 × `get_block` (índice direto em `_flat`,
voxel_world.gd:233) + 2 × `has_gravity` (byte array). Com `MAX_PER_TICK = 256` o teto
é **5 120 resoluções/s**, e uma cascata de pilha inteira de areia consome 1 entrada de
fila por bloco em queda.

### API nova em `VoxelWorld`

```gdscript
## Suporte para gravidade: a regra e literalmente o bloco de baixo.
func is_supported(p: Vector3i) -> bool:
	return BlockDefs.is_solid(get_block_xyz(p.x, p.y - 1, p.z))


## Fixacao de bloco em queda. Diferente de set_block porque so aceita celula livre
## ou liquida: um bloco que nao coube vira drop, nao fantasma dentro de pedra.
## Checagem de entidade fica na FallingBlock (ela tem o provider), nao aqui.
func place_falling_block(cell: Vector3i, b: int) -> bool:
	if not VoxelConfig.in_world_bounds(cell):
		return false
	var here := get_block(cell)
	if here != BlockDefs.Block.AIR and not BlockDefs.is_liquid(here):
		return false
	return set_block(cell, b)
```

`is_supported` herda uma conveniência importante: `get_block_xyz` devolve sólido para
`y < Y_MIN` (hoje devolve STONE para `y < 0`, voxel_world.gd:226-227) — com a mudança
de §10.7 esse caso vira BEDROCK, então nenhuma entidade de queda cai para fora do
mundo: a barreira de −64 é o piso físico **e** o limite do algoritmo, sem cláusula
especial.

## 10.6 Geração das camadas subterrâneas

```gdscript
## WorldGen [TARGET]. A coluna inteira de uma vez, do fundo ate o topo gerado.
const SOIL_DEPTH: int = 4                # era o literal `h - 4` em generate_chunk
const DEEP_ROOM_THRESHOLD: float = 0.55  # [TARGET] a varrer em 10.8
const DEEP_ROOM_FREQ: float = 0.018      # [TARGET] cavernas amplas da faixa profunda

var _deep_mix := FastNoiseLite.new()     # 2D, jitter da zona de transicao
var _deep_room := FastNoiseLite.new()    # 3D, salas largas do subterraneo profundo


## Os dois ruidos sao semeados em `setup()` (world_gen.gd:41-60) na mesma regra dos
## canais existentes — `p_seed + n`, um `n` por ruido, nunca dois canais no mesmo.
## `+8` ja e do `_basin` (:47), entao os novos vem depois; chama-los de `+3` ou
## reusar um seed existente muda o mundo para toda semente antiga e o censo de 10.8
## deixa de comparar com nada:
##
##     _noise(_deep_mix,  p_seed + 9,  0.0120, FastNoiseLite.FRACTAL_NONE,   1)
##     _noise(_deep_room, p_seed + 10, DEEP_ROOM_FREQ, FastNoiseLite.FRACTAL_RIDGED, 2)


func _fill_column(c: VoxelChunk, x: int, z: int) -> void:
	var gx: int = c.coord.x * VoxelChunk.SIZE_X + x
	var gz: int = c.coord.y * VoxelChunk.SIZE_Z + z
	var h: int = clampi(surface_height(gx, gz), VoxelConfig.Y_BEDROCK_TOP + 1,
		VoxelConfig.Y_BUILD_LIMIT - 8)
	var top: int = surface_block(gx, gz, h)
	var sub: int = BlockDefs.Block.SAND if top == BlockDefs.Block.SAND else BlockDefs.Block.DIRT
	var ceil: int = _bedrock_ceiling(gx, gz)
	for y in range(VoxelConfig.Y_MIN, h + 1):
		var b: int = _rock_at(gx, y, gz, h, top, sub, ceil)
		# escavacao: nunca dentro do bedrock, sempre abaixo da crosta de superficie
		if b != BlockDefs.Block.BEDROCK and y > ceil and y <= h - CARVE_CRUST \
				and not _near_spawn(gx, gz) \
				and _carved(gx, y, gz, h, y <= VoxelConfig.Y_DEEP_TOP):
			# o vazio abaixo do nivel da lava ja nasce lava (regra de preenchimento)
			b = BlockDefs.Block.AIR if y > VoxelConfig.Y_LAVA_LEVEL else BlockDefs.Block.LAVA
		c.set_block(x, y, z, b)                # x/z locais, Y GLOBAL (ver 10.7)
	for y in range(h + 1, VoxelConfig.SEA_LEVEL + 1):
		c.set_block(x, y, z, BlockDefs.Block.WATER)
```

```gdscript
## Regra de preenchimento por faixa de Y. Sem ruido aqui: o ruido decide vazio e
## mistura; a faixa decide a familia de rocha.
func _rock_at(x: int, y: int, z: int, h: int, top: int, sub: int, ceil: int) -> int:
	if y == VoxelConfig.Y_MIN:
		return BlockDefs.Block.BEDROCK          # linha -64: barreira continua
	if y <= ceil:
		return BlockDefs.Block.BEDROCK          # teto irregular, continuo para baixo
	if y == h:
		return top
	if y > h - SOIL_DEPTH:
		return sub
	if y >= VoxelConfig.Y_SOIL_BOTTOM:
		return BlockDefs.Block.STONE            # 63..1: pedra comum
	if y >= VoxelConfig.Y_TRANSITION_BOTTOM:
		return _transition_block(x, y, z)       # 0..-8: stone <-> deepslate
	return BlockDefs.Block.DEEPSLATE            # -9..-60: alta dureza (acima do teto)


## Rampa linear com jitter de 4 blocos: 0% de rocha profunda em Y=0, 50% em Y=-4,
## 100% em Y=-8. O jitter e 2D (por coluna), senao a fronteira vira um plano e a
## zona de transicao vira uma laje.
func _transition_block(x: int, y: int, z: int) -> int:
	var jitter: float = _deep_mix.get_noise_2d(float(x), float(z))      # -1..1
	var t: float = clampf(float(-y) / 8.0 + jitter, 0.0, 1.0)
	return BlockDefs.Block.DEEPSLATE if _rand3(x, y, z) < t else BlockDefs.Block.STONE


## Teto do bedrock por coluna: -60 (r=0) ate -63 (r->1). O -64 e garantido pelo ramo
## `y == Y_MIN` de _rock_at, entao nenhuma coluna tem menos de 2 niveis de rocha
## matriz e nenhuma coluna tem buraco no fundo do mundo.
func _bedrock_ceiling(x: int, z: int) -> int:
	return VoxelConfig.Y_BEDROCK_TOP - int(floorf(_rand2(x, z) * 4.0))
```

```gdscript
## deep = true na faixa -9..-59: salas largas em vez de tuneis vermes.
func _carved(x: int, y: int, z: int, h: int, deep: bool) -> bool:
	if y > h - CAVE_MIN_DEPTH:
		return false                    # crosta: nada de buraco sob o chao imediato
	if deep:
		return _deep_room.get_noise_3d(float(x), float(y), float(z)) > DEEP_ROOM_THRESHOLD
	# ... ramo atual, preservado: intersecao de duas folhas de tunel (world_gen.gd:146-157)
```

Determinismo: `_rand2`/`_rand3` são extensões de `_mix`/`_hash_mix`
([world_gen.gd:193-204](../../src/world/world_gen.gd)), **semeadas por `world_seed`** e
por coordenada. Nenhuma função nova pode usar um `RandomNumberGenerator` global —
se não, a geração deixa de ser reproduzível e a checagem
`geracao deterministica (16 colunas)` (smoke_test.gd:315-319) quebra, junto com o
princípio declarado no cabeçalho de `WorldGen` (:2-4).

A regra de feature por chunk continua valendo: `decorate_chunk` escreve só dentro do
próprio chunk com `FEATURE_INSET = 3` (world_gen.gd:9, :160-180). As faixas novas não
a desafiam — bedrock, transição e lava são funções da **coluna**, e coluna é 1:1 com
chunk local, então não há escrita entre vizinhos.

## 10.7 Custo e migração do chunk 16 × 384 × 16

### A classe de bug que precisa ser tratada primeiro

Hoje **Y local == Y global**, porque `Y_MIN = 0`. O comentário de `Coords` diz isso
literalmente: "a coordenada local guarda X/Z deslocados e Y global"
([coords.gd:10-11](../../src/world/coords.gd)); `local_of` devolve `b.y` cru
(coords.gd:43-45) e `VoxelChunk.local_index` usa esse Y direto como índice
(voxel_chunk.gd:21-22). Com `Y_MIN = −64`, isso passa a ser índice negativo em metade
do mundo. A correção barata é **confinar o offset a uma função só**:

```gdscript
## VoxelChunk [TARGET]: recebe Y GLOBAL, devolve indice local. get_block/set_block
## do chunk passam a falar Y global, como ja falam X/Z globais em VoxelWorld.
static func local_index(x: int, y_global: int, z: int) -> int:
	return ((y_global - VoxelConfig.Y_MIN) * SIZE_Z + z) * SIZE_X + x
```

Consequência útil: todo chamador continua correto, e os que **param** de compilar são
os que assumiam `range(CHUNK_SIZE_Y)` como Y global — que é exatamente o erro
silencioso que se quer evitar. Lista completa dos sítios que mudam:

| Sítio | Hoje | Precisa mudar para |
|---|---|---|
| [voxel_chunk.gd:21](../../src/world/voxel_chunk.gd) | `(y*SZ+z)*SX+x` | `- Y_MIN` no índice |
| [coords.gd:37-45](../../src/world/coords.gd) `chunk_origin`/`local_of` | `Vector3i(x, 0, z)` | Y global; o offset sai de `local_of` e entra só em `local_index` |
| [voxel_world.gd:130](../../src/world/voxel_world.gd) `_flat.resize` | `64*_sz*_sx` (1 MiB) | `384*_sz*_sx` (**6 MiB**) |
| voxel_world.gd:136-141 `_rebuild_flat` | `for y in CHUNK_SIZE_Y` | laço pelo **span** populado (abaixo) |
| voxel_world.gd:225-238 `get_block_xyz` | `y<0 → STONE`, `y≥64 → AIR` | `y<Y_MIN → BEDROCK`, `y≥Y_BUILD_LIMIT → AIR` |
| voxel_world.gd:248 `_write_raw` | `(p.y*_sz+p.z)*_sx+p.x` | `- Y_MIN` no índice |
| voxel_world.gd:401-407 `surface_height` | desce de 63 | começa do `y_hi` do chunk, não de 383 |
| voxel_world.gd:434 `build_chunk_mesh` | 98 304 voxels/chunk | span `y_lo..y_hi` (abaixo) |
| world_gen.gd:83 `surface_height` | `27.0 + …` | `65.0 + …` (**+38**, ver migração de save) |
| world_gen.gd:95 `_spawn_flatten` | base `30.0` | `68.0` (+38) |
| world_gen.gd:103-106 `surface_block` | `SEA_LEVEL+1`, `h>=52`, `h<57` | o primeiro segue a constante; 52 → 90, 57 → 95 |
| world_gen.gd:124-136 `generate_chunk` | `for y in h+1` | `range(Y_MIN, h+1)` (~4,2× escritas) |
| world_gen.gd:132 | guard `y > 1` | `y > ceil` (o `1` era o fundo do mundo velho) |
| world_gen.gd:184 `_column_top` | desce de 63 | span do chunk |
| world_gen.gd:209-247 (`_plant_tree`, `_place_boulder`) | clampam em `SIZE_Y` | clampam em `Y_BUILD_LIMIT`; seguem válidos |
| [smoke_test.gd:401-404](../../tests/smoke_test.gd) | `for y in CHUNK_SIZE_Y` + `c.get_block(x, y, z)` | **Y global**: `range(Y_MIN, Y_BUILD_LIMIT)` |
| smoke_test.gd:324, :606 | `CHUNK_SIZE_Y - 5`, `get_block_xyz(10, CHUNK_SIZE_Y, 10)` | continuam válidos (topo virou 383/320) |
| smoke_test.gd:618-619 | "parede invisivel solida" == STONE | X/Z continua STONE; o **piso** vira BEDROCK e pede checagem nova |
| `.tools/shot_gallery.gd` (gitignored) | `_heights` do `surface_height` | continua valendo: as alturas transdam +38 junto |

### Memória e tempo, com a aritmética sobre o número medido

- **Bytes.** 16 × 384 × 16 = **98 304** por chunk; 64 chunks = 6 291 456 B ≈ **6,0
  MiB** de `VoxelChunk.data` + **6,0 MiB** de `_flat` = 12 MiB. Orçamento proposto
  `[DECIDED]`: 16 MiB. É folgado; o problema não é memória.
- **Tempo, sem otimização.** A malharia iterava 16 384 voxels/chunk e passa a iterar
  98 304 ⇒ **6×**, sobre o baseline medido de 4 799,1 ms ⇒ **≈ 28,8 s** de boot.
  Geração: `for y in h+1` com `h ≈ 31` passa a escrever `h − Y_MIN ≈ 95..160` níveis
  ⇒ ~4,2× sobre 980,5 ms ⇒ **≈ 4,1 s**. (Ambos derivados por aritmética do número
  medido, não medidos ainda — `[TARGET]`.)
- **Correção obrigatória: span populado por chunk.**
  ```gdscript
  # VoxelChunk [TARGET]
  var y_lo: int = VoxelConfig.Y_MIN      # menor/maior Y != AIR da coluna
  var y_hi: int = VoxelConfig.Y_MIN
  func mark(y_global: int) -> void:
      y_lo = mini(y_lo, y_global)
      y_hi = maxi(y_hi, y_global)
  ```
  `set_block` e a geração chamam `mark`; `build_chunk_mesh` e `_rebuild_flat` iteram
  `range(c.y_lo, c.y_hi + 1)`. Numa coluna de superfície com relevo em ~65..95 e
  fundo em −64, o span é ~160 níveis em vez de 384 ⇒ a malharia volta a ~2,5× o
  baseline (**≈ 12 s**) em vez de 6×. Os 168 níveis de ar acima de `y_hi` custam
  **zero**.
- **Segundo passo, se 12 s não couber no gate:** o chunk continua 16 × 384 × 16 como
  unidade de storage (é o que o pedido pede) e ganha um bitmask de 24 seções de 16
  (`sections: int`, bit `i` ⇄ `y_lo + 16i`) para pular seções totalmente sólidas ou
  totalmente vazias. `[OPEN]`, decidido com número no mesmo formato do bake-off de
  voxel de §06.4.
- **Gate de boot proposto `[TARGET]`:** `gen_ms + mesh_ms ≤ 12,0 s` em headless, com a
  linha `diagnostico final` (main.gd:648-659) como fonte. Se estourar, streaming de
  chunk entra na frente do gate P1 em [08-roadmap](08-roadmap-risks-licensing.md); o
  que não se faz é cortar qualidade de camadas para caber no tempo.

### Migração de save — o ponto que pode ser barato

`SaveManager` guarda **semente + diário de edições** (`world_%s.json`, chave `"x,y,z"`
de `Coords.block_key`), nunca voxels ([save_manager.gd:5-6](../../src/persistence/save_manager.gd)).
Duas versões sobem:

```gdscript
const SCHEMA: int = 2          # era 1 (save_manager.gd:8)
const GEN_VERSION: int = 5     # era 4 (world_gen.gd:6)
```

`read_slot` hoje recusa apenas schema **mais novo** (:69) — um save v1 entraria num v2
e reinterpretaria todas as coordenadas em silêncio. Mas como o rebase do relevo é uma
**translação pura de +38** nas quatro alturas fixas de `WorldGen` (27 → 65, 30 → 68,
52 → 90, 57 → 95) e `SEA_LEVEL` translada de 26 para 64 com o mesmo número, existe
migração exata do diário:

```
y_novo = y_velho + 38
```

Ela é correta para toda edição com `y_velho > 0` (relevo, árvores, construções, e as
cavernas — que são escavadas *relativas a* `h`, por `CARVE_CRUST`/`CAVE_MIN_DEPTH`,
então transdam junto). Ela é **silenciosa e errada** para edição antiga em `y ≤ 0`: o
mundo velho não tinha nada ali, e o novo tem faixa profunda, lava e bedrock. Regra de
fechamento `[DECIDED]`: migrar por translação e **recusar o slot se qualquer edição
antiga cair em faixa que o novo mundo não conhece** (`y_novo < Y_BEDROCK_TOP + 1`).
A gravação/conferência de `gen_version` já existe em `save_game`/`load_game`
([main.gd:989](../../src/main.gd#L989), [main.gd:1024](../../src/main.gd#L1024)):
hoje o save incompatível é recusado antes da restauração. A migração proposta precisa
atualizar essa versão junto das edições; não há migração implementada aqui.

### Checagens novas de suíte (contrato, não intenção)

| Checagem | Asserção | Fecha qual regra |
|---|---|---|
| `limites verticais` | `in_world_bounds((64,319,64))`, `not in_world_bounds((64,320,64))`, `in_world_bounds((64,-64,64))`, `not in_world_bounds((64,-65,64))` | 1 |
| `bedrock continuo no fundo` | `y == Y_MIN` nos 64 chunks: 100% BEDROCK | 1 |
| `barreira indestrutivel` | lavra em `(x,-64,z)` não produz `set_block(AIR)` | 1 |
| `faixas por Y` | amostrar 256 colunas: `[1,63]` ⊂ {GRASS,DIRT,STONE,SAND,SNOW}; `[0,-8]` ⊂ {STONE,DEEPSLATE}; `[-9,-59]` ≥ 90% DEEPSLATE | 1 |
| `rampa da transicao` | `p(deepslate \| y=0) < 0,05`, `p(y=-4) ∈ [0,40..0,60]`, `p(y=-8) > 0,95` | 1 |
| `lava abaixo de -54` | todo vazio com `y < -54` é LAVA; nenhum `y ≥ -54` é LAVA | 1 |
| `areia cai sozinha` | SAND com ar abaixo ⇒ ≥ 1 `FallingBlock` vivo no tick seguinte | 2 |
| `pedra nao cai` | STONE com ar abaixo ⇒ zero entidades após 10 ticks | 2 |
| `tocha quebra a queda` | SAND caindo sobre TORCH ⇒ SAND vira drop, nenhum SAND no grid, TORCH intacto | 2 |
| `dano proporcional a altura` | ANVIL de 20 blocos ⇒ 47,7 ± 0,5; de 5 ⇒ 0; de 60 ⇒ 55 | 2 |
| `sufocamento granular` | SAND sobre o jogador ⇒ `air` drena e 7 de dano a cada 1,0 s | 2 |
| `lava nao quebra queda` | AREIA sobre LAVA continua caindo; sobre BEDROCK fixa | 2 |
| `nenhuma varredura` | com fila vazia e mundo intacto, contador de chamadas de gravidade por tick == 0 | 3 |
| `orcamento da fila` | 4 096 eventos de uma explosão ⇒ `flush ≤ 256`/tick e fila esvazia com `worst_sim_ms` ≤ 8,82 ms | 3 |

## 10.8 Como cada `[TARGET]` vira número

O repo já tem o precedente: os limiares de caverna de `WorldGen` foram decididos por
uma varredura do mundo inteiro, com os números do lado de dentro e do lado de fora no
próprio comentário (world_gen.gd:12-27). A mesma rotina fecha esta especificação:

1. **Censo de camadas** (probe em `tests/`, não suíte): 128 × 128 colunas × 384
   níveis, contar por (faixa, bloco). Saída esperada: ~4 níveis de solo por coluna;
   rampa medida em `y = 0 / −4 / −8`; profundo ≥ 90% DEEPSLATE; `y == Y_MIN` 100%
   BEDROCK; lava = fração de vazio abaixo de −54.
2. **Varredura dos limiares profundos** (`DEEP_ROOM_THRESHOLD`, `DEEP_ROOM_FREQ`) no
   formato da varredura de `TUNNEL_THRESHOLD`: duas colunas de números por candidata
   (% de ar, % de colunas com corredor ≥ 4 blocos, % de pilares flutuantes), e o
   comentário registra o que foi medido, não o que foi escolhido.
3. **Probe de orçamento**: soltar N = 1 024 e N = 4 096 colunas de areia e medir
   `worst_sim_ms` (`SimClock`, main.gd:743-758). Gate: nenhum tick perdido, com o
   piso de pior passo medido nestas quatro corridas: 7,68 / 8,66 / 9,01 / 11,21 ms
   (smoke_test.gd:221-222 e 2459-2461).
4. **Ablação do span**: `build_chunk_mesh` com e sem `y_lo..y_hi`, dois `mesh_ms` lado
   a lado, antes de qualquer discussão de seção de 16.

## 10.9 Decidido × aberto

`[DECIDED]`

1. `Y ∈ [−64, 319]`, 384 níveis, chunk 16 × 384 × 16; build limit 320 **exclusivo**.
2. Propriedades de bloco ficam em `BlockDefs` (script, `PackedByteArray` por campo), e
   `dureza` sai de `Player._hardness()` sem alterar os sete valores existentes. Esta
   migração já aconteceu (documento 11): `_hard` no registro, `Player` sem tabela
   própria, e `tempo de mineracao == dureza` segue verde pelos mesmos números.
3. Nove campos, um por pergunta. `liquido`, `substituivel` e `quebra_queda` não são
   sinônimos de `not solido` — o pedido exige separá-los.
4. Gravidade de bloco é **evento local**: candidatos `p + (0,1,0)` e `p` quando o
   bloco colocado é gravitacional. Dois testes por evento, nenhuma varredura de mundo.
5. Célula de fixação derivada do **bloco de apoio**, nunca da posição do corpo.
6. Dano de impacto é a fórmula de queda do jogador com `h_segura = 4,08` derivada de
   `FALL_SAFE_SPEED` e `g = 24`, e o mesmo teto de 55.
7. Sufocamento granular usa o caminho de `air` que já existe, não um dano paralelo.
8. IDs de bloco novos são append-only (9..18). Rebase de relevo por translação de
   +38, com o diário de edições migrando pelo mesmo shift. O documento 11 chegou antes
   e tomou **19..22** (COBBLESTONE, PLANK, GLASS, BENCH) com tiles 19..22; os ids desta
   spec continuam livres em 9..18 e nenhum dos dois toca nos 0..8.

`[OPEN]` (cada um com critério de fechamento em §10.8)

1. Seções de 16 dentro do chunk de 384 (bitmask de ocupação) — entra se o span deixar
   `mesh_ms` acima do gate de 12 s.
2. Colisão de meia altura para SLAB, hoje inexistente no modelo binário
   (`aabb_hits_solid`); sem ela a laje é "sólida para pisar" e "alvo de quebra" ao
   mesmo tempo, o que só a tabela resolve, não o motor de física.
3. Geometria de TORCH/PLANT (shape table na malharia) vs. deixar como cubo e adiar
   arte. Superfície emissiva da lava é item separado e obrigatório.
4. Lava + água → obsidiana/pedra: **não foi pedido** e não está especificado aqui;
   implementar por acidente criaria um bloco fora da tabela de §10.3.
5. Correnteza de fluido e escorrimento lateral: o pedido diz "o bloco abaixo (Y − 1)",
   e é só isso que a fila implementa.
6. Inventário/coletáveis, sem o qual `_shatter` não tem destino. É pré-requisito da
   regra 2, não detalhe de arte.
