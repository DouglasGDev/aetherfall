class_name BlockDefs
## Registro de blocos: solidez, opacidade, tiles do atlas, nome, pilha e drop.
## Ids estaveis: sao gravados no save. Remover/reordenar exige migracao (ver save_manager).
##
## 9..18 continuam RESERVADOS para as camadas verticais e a fisica de blocos
## (docs/design/../10-world-layers-and-block-physics.md 10.3). O inventario chegou
## antes delas, entao os materiais de craft usam 19 em diante: nenhum id novo pode
## ocupar o valor que a especificacao ja promete.

enum Block {
	AIR = 0,
	GRASS = 1,
	DIRT = 2,
	STONE = 3,
	SAND = 4,
	SNOW = 5,
	WOOD = 6,
	LEAVES = 7,
	WATER = 8,
	COBBLESTONE = 19,
	PLANK = 20,
	GLASS = 21,
	BENCH = 22,
}

## Como a face do bloco e desenhada. NAO e o mesmo eixo de `is_opaque`: a
## opacidade manda no face-culling do vizinho, a classe de desenho manda no
## material da propria face. Folhas viram opacas=0 na especificacao das camadas
## (doc 10 10.3) e continuam desenhadas como OPAQUE: sem isso a mudança de uma
## daria outro material em cada arvore.
enum Draw {
	OPAQUE = 0,
	ALPHA = 1,
	LIQUID = 2,
}

const COUNT: int = 23

# Tiles no atlas 8x8 (index = ty * 8 + tx). 10..18 reservados pelo documento 10.
const TILE_GRASS_TOP: int = 0
const TILE_GRASS_SIDE: int = 1
const TILE_DIRT: int = 2
const TILE_STONE: int = 3
const TILE_SAND: int = 4
const TILE_SNOW: int = 5
const TILE_WOOD_SIDE: int = 6
const TILE_WOOD_TOP: int = 7
const TILE_LEAVES: int = 8
const TILE_WATER: int = 9
const TILE_COBBLE: int = 19
const TILE_PLANK: int = 20
const TILE_GLASS: int = 21
const TILE_BENCH: int = 22

## Tamanho de pilha por bloco. O Veloren nao tem numero por item: `max_amount()`
## devolve u32::MAX para qualquer item `is_stackable()` e 1 para o resto, e a
## pilha e decidida pela CLASSE do item (common/src/comp/inventory/item/mod.rs:873,889).
## Aqui o numero e por bloco, como no Minecraft, porque o limite de 64 e o que da
## trabalho de carregar: 16 para a bancada porque ela e um objeto de 1x1x1 com
## logica propria, e pilha de bancada no inventario e a porta para o jogador
## fabricar estacoes em serie sem custo.
const STACK_DEFAULT: int = 64
const STACK_BENCH: int = 16

static var _solid: PackedByteArray = PackedByteArray()
static var _opaque: PackedByteArray = PackedByteArray()
static var _draw: PackedByteArray = PackedByteArray()
static var _stack: PackedByteArray = PackedByteArray()
static var _drop: PackedByteArray = PackedByteArray()
static var _hard: PackedFloat32Array = PackedFloat32Array()
static var _names: PackedStringArray = PackedStringArray()


static func init_tables() -> void:
	if _names.size() == COUNT:
		return
	# Um resize por variavel propria: PackedByteArray e copy-on-write em GDScript 4,
	# entao `for a in [_solid, _opaque, ...]: a.resize(COUNT)` moraria na copia e o
	# primeiro acesso ao registro daria indice fora do range em plena malharia.
	_solid.resize(COUNT)
	_opaque.resize(COUNT)
	_draw.resize(COUNT)
	_stack.resize(COUNT)
	_drop.resize(COUNT)
	_hard.resize(COUNT)
	_names.resize(COUNT)
	for i in COUNT:
		_solid[i] = 1
		_opaque[i] = 1
		_draw[i] = Draw.OPAQUE
		_stack[i] = STACK_DEFAULT
		_drop[i] = i                 # por regra o bloco cai como ele mesmo
		_hard[i] = 0.4
	_solid[Block.AIR] = 0
	_opaque[Block.AIR] = 0
	_stack[Block.AIR] = 0
	_drop[Block.AIR] = Block.AIR
	_hard[Block.AIR] = 0.0
	_solid[Block.WATER] = 0
	_opaque[Block.WATER] = 0
	_draw[Block.WATER] = Draw.LIQUID
	_stack[Block.WATER] = 0
	_drop[Block.WATER] = Block.AIR   # agua nao e coletavel sem balde
	_hard[Block.WATER] = 0.05
	_names[Block.AIR] = "ar"
	_names[Block.GRASS] = "grama"
	_names[Block.DIRT] = "terra"
	_names[Block.STONE] = "pedra"
	_names[Block.SAND] = "areia"
	_names[Block.SNOW] = "neve"
	_names[Block.WOOD] = "madeira"
	_names[Block.LEAVES] = "folhas"
	_names[Block.WATER] = "agua"
	# --- durezas: vieram 1:1 da tabela que morava no Player; o registro e a unica
	# fonte, e o 0,4 default acima cobre os ids que ainda nao tem material
	_hard[Block.STONE] = 0.95
	_hard[Block.WOOD] = 0.55
	_hard[Block.LEAVES] = 0.22
	_hard[Block.DIRT] = 0.35
	_hard[Block.GRASS] = 0.38
	_hard[Block.SAND] = 0.30
	_hard[Block.SNOW] = 0.25
	# --- materiais de craft
	_names[Block.COBBLESTONE] = "pedra bruta"
	_names[Block.PLANK] = "tabua"
	_names[Block.GLASS] = "vidro"
	_names[Block.BENCH] = "bancada"
	_hard[Block.COBBLESTONE] = 0.85
	_hard[Block.PLANK] = 0.45
	_hard[Block.BENCH] = 0.50
	# o vidro e a unica face ALPHA do registro: solida para pisar e encostar,
	# nao opaca para o vizinho, e desenhada com o material transparente
	_hard[Block.GLASS] = 0.10
	_solid[Block.GLASS] = 1
	_opaque[Block.GLASS] = 0
	_draw[Block.GLASS] = Draw.ALPHA
	_stack[Block.BENCH] = STACK_BENCH
	# pedra lavrada vira bruta: e o que da trabalho na cadeia de construcao, e o
	# motivo de "pedra" nao sair da lavra direto como bloco de construcao.
	_drop[Block.STONE] = Block.COBBLESTONE
	# grama sem ferramenta nao solta o torrao, solta terra.
	_drop[Block.GRASS] = Block.DIRT
	# folha nao e material de construcao: cai como nada ate existir sapling.
	_drop[Block.LEAVES] = Block.AIR


static func is_solid(b: int) -> bool:
	return _solid[b] == 1


static func is_opaque(b: int) -> bool:
	return _opaque[b] == 1


## Classe de desenho da face (Draw.OPAQUE / ALPHA / LIQUID).
static func draw_of(b: int) -> int:
	return int(_draw[b])


## Quantos cabem num slot de inventario. 0 = nao e coletavel (ar, agua).
static func stack_max(b: int) -> int:
	return int(_stack[b])


## O que o jogador recebe ao quebrar este bloco (AIR = nada).
static func drop_of(b: int) -> int:
	return int(_drop[b])


## Segundos de lavra com a mao.
static func hardness(b: int) -> float:
	return _hard[b]


static func display_name(b: int) -> String:
	return _names[b]


## face: 0=+Y topo, 1=-Y base, 2..5 laterais (+X,-X,+Z,-Z)
static func tile_for(b: int, face: int) -> int:
	match b:
		Block.GRASS:
			if face == 0:
				return TILE_GRASS_TOP
			if face == 1:
				return TILE_DIRT
			return TILE_GRASS_SIDE
		Block.DIRT:
			return TILE_DIRT
		Block.STONE:
			return TILE_STONE
		Block.SAND:
			return TILE_SAND
		Block.SNOW:
			if face == 1:
				return TILE_DIRT
			return TILE_SNOW
		Block.WOOD:
			if face == 0 or face == 1:
				return TILE_WOOD_TOP
			return TILE_WOOD_SIDE
		Block.LEAVES:
			return TILE_LEAVES
		Block.WATER:
			return TILE_WATER
		Block.COBBLESTONE:
			return TILE_COBBLE
		Block.PLANK:
			return TILE_PLANK
		Block.GLASS:
			return TILE_GLASS
		Block.BENCH:
			# tampo de tabua em cima, estrutura de madeira na lateral:
			# o jogador le " superficie de trabalho" de cima, "movele" de lado
			if face == 0:
				return TILE_BENCH
			return TILE_WOOD_SIDE
		_:
			return TILE_STONE


## Cor de referencia por bloco: mesma base do atlas, para HUD e legendas.
static func swatch(b: int) -> Color:
	match b:
		Block.GRASS: return Color(0.34, 0.55, 0.26)
		Block.DIRT: return Color(0.42, 0.31, 0.20)
		Block.STONE: return Color(0.52, 0.53, 0.55)
		Block.SAND: return Color(0.83, 0.76, 0.52)
		Block.SNOW: return Color(0.92, 0.94, 0.97)
		Block.WOOD: return Color(0.40, 0.28, 0.16)
		Block.LEAVES: return Color(0.20, 0.40, 0.16)
		Block.WATER: return Color(0.16, 0.38, 0.62)
		Block.COBBLESTONE: return Color(0.46, 0.46, 0.48)
		Block.PLANK: return Color(0.58, 0.44, 0.26)
		Block.GLASS: return Color(0.72, 0.86, 0.92, 0.55)
		Block.BENCH: return Color(0.50, 0.36, 0.20)
		_: return Color(0.0, 0.0, 0.0, 0.0)


## Blocos que ocupam a hotbar no kit com que a sessao abre, na ordem dos ids.
## Colocar nao depende desta lista: qualquer coisa que esteja no inventario e
## solida pode ser colocada. Ela existe porque as 10 teclas da hotbar comportam
## menos ids do que o registro tem, e a vidraca e a pedra bruta entram pela lavra
## e pelo craft, nao pelo kit.
static func default_hotbar_blocks() -> Array[int]:
	var out: Array[int] = []
	out.assign([
		Block.GRASS, Block.DIRT, Block.STONE, Block.SAND,
		Block.SNOW, Block.WOOD, Block.LEAVES, Block.PLANK, Block.BENCH,
	])
	return out
