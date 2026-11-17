class_name BlockDefs
## Registro de blocos: solidez, opacidade, tiles do atlas e nome.
## Ids estaveis: sao gravados no save. Remover/reordenar exige migracao (ver save_manager).

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
}

const COUNT: int = 9

# Tiles no atlas 8x8 (index = ty * 8 + tx).
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

static var _solid: PackedByteArray = PackedByteArray()
static var _opaque: PackedByteArray = PackedByteArray()
static var _names: PackedStringArray = PackedStringArray()


static func init_tables() -> void:
	if _names.size() == COUNT:
		return
	_solid.resize(COUNT)
	_opaque.resize(COUNT)
	_names.resize(COUNT)
	for i in COUNT:
		_solid[i] = 1
		_opaque[i] = 1
	_solid[Block.AIR] = 0
	_opaque[Block.AIR] = 0
	_solid[Block.WATER] = 0
	_opaque[Block.WATER] = 0
	_names[Block.AIR] = "ar"
	_names[Block.GRASS] = "grama"
	_names[Block.DIRT] = "terra"
	_names[Block.STONE] = "pedra"
	_names[Block.SAND] = "areia"
	_names[Block.SNOW] = "neve"
	_names[Block.WOOD] = "madeira"
	_names[Block.LEAVES] = "folhas"
	_names[Block.WATER] = "agua"


static func is_solid(b: int) -> bool:
	return _solid[b] == 1


static func is_opaque(b: int) -> bool:
	return _opaque[b] == 1


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
		_: return Color(0.0, 0.0, 0.0, 0.0)


static func placeable_blocks() -> Array[int]:
	var out: Array[int] = []
	out.assign([
		Block.GRASS, Block.DIRT, Block.STONE, Block.SAND,
		Block.SNOW, Block.WOOD, Block.LEAVES,
	])
	return out
