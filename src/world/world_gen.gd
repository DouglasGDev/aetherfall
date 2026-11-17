class_name WorldGen
## Geracao deterministica de terreno: (world_seed, gen_version) => mesmo mundo.
## Nota de determinismo: features (arvores, blocos) so escrevem dentro do chunk de origem,
## com inset de 3, para que a ordem de geracao de vizinhos nao altere o resultado.

const GEN_VERSION: int = 3
const TREE_DENSITY: float = 0.018
const BOULDER_DENSITY: float = 0.004
const FEATURE_INSET: int = 3
const SPAWN_RADIUS_CLEAR: int = 4
const CAVE_THRESHOLD: float = 0.80
# Espessura de cada folha que, intersecada com a outra, forma o tubo. Medido na
# varredura (mundo inteiro, ruido amostrado 1 de 2 colunas): 0,035 dava 2,9% de
# ar e so 2,0% das colunas com corredor >= 4 -- tunel quase inexistente; 0,110
# da 6,0% de ar e 11,0% com corredor >= 4, que e o diametro de uma caverna onde
# se anda, com 1,8% de pocilgas grandes e 0% de pilar flutuante.
const TUNNEL_THRESHOLD: float = 0.110
# Blocos solidos minimos entre o topo da coluna e qualquer vazio. Com 1 (a regra
# antiga parava em y < h-1) 25% das colunas ficavam com crosta de 1-2 blocos e
# 42% com buraco a 2-4 blocos do chao: o terreno virava casca sobre queijo suico
# e o jogador via atraves do proprio chao.
const CARVE_CRUST: int = 5
# Profundidade minima de escavacao, medida do topo da coluna. Crosta de 5 so
# garante o piso imediato; com 5 a escavacao ainda comia 21,5% do volume abaixo
# do chao e 95,8% das colunas tinham buraco embaixo -- o horizonte inteiro
# virava grade, e e isso que a camera mostrava como "bloco transparente".
const CAVE_MIN_DEPTH: int = 12


var world_seed: int = 0
var _height := FastNoiseLite.new()
var _mountain := FastNoiseLite.new()
var _moist := FastNoiseLite.new()
var _temp := FastNoiseLite.new()
var _cave := FastNoiseLite.new()
var _tunnel := FastNoiseLite.new()
var _tunnel_b := FastNoiseLite.new()


func setup(p_seed: int) -> void:
	world_seed = p_seed
	_noise(_height, p_seed + 1, 0.0075, FastNoiseLite.FRACTAL_FBM, 5)
	_noise(_mountain, p_seed + 2, 0.0035, FastNoiseLite.FRACTAL_FBM, 3)
	_noise(_moist, p_seed + 3, 0.0045, FastNoiseLite.FRACTAL_NONE, 1)
	_noise(_temp, p_seed + 4, 0.0030, FastNoiseLite.FRACTAL_NONE, 1)
	_cave.seed = p_seed + 5
	_cave.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cave.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_cave.fractal_octaves = 3
	_cave.frequency = 0.045
	_tunnel.seed = p_seed + 6
	_tunnel.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_tunnel.fractal_type = FastNoiseLite.FRACTAL_NONE
	_tunnel.frequency = 0.021
	_tunnel_b.seed = p_seed + 7
	_tunnel_b.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_tunnel_b.fractal_type = FastNoiseLite.FRACTAL_NONE
	_tunnel_b.frequency = 0.021


static func _noise(n: FastNoiseLite, s: int, freq: float, fractal: int, oct: int) -> void:
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.fractal_type = fractal
	n.fractal_octaves = oct
	n.frequency = freq


func surface_height(x: int, z: int) -> int:
	var n1: float = (_height.get_noise_2d(float(x), float(z)) + 1.0) * 0.5
	var m: float = (_mountain.get_noise_2d(float(x), float(z)) + 1.0) * 0.5
	var mask: float = clampf((m - 0.42) / 0.58, 0.0, 1.0)
	mask = mask * mask * (3.0 - 2.0 * mask)
	var h: float = 27.0 + n1 * 10.0 + mask * 23.0
	h = _spawn_flatten(x, z, h)
	return int(h)


## Plataforma ao redor do centro do mundo: spawn garantido e sem buraco.
func _spawn_flatten(x: int, z: int, h: float) -> float:
	var cx: float = float(VoxelConfig.world_size_x()) * 0.5
	var cz: float = float(VoxelConfig.world_size_z()) * 0.5
	var d: float = Vector2(float(x) - cx, float(z) - cz).length()
	if d > 16.0:
		return h
	var base: float = 30.0 + _height.get_noise_2d(cx, cz) * 3.0
	var w: float = clampf((d - 6.0) / 10.0, 0.0, 1.0)
	return lerpf(base, h, w * w * (3.0 - 2.0 * w))


func surface_block(x: int, z: int, h: int) -> int:
	var moist: float = _moist.get_noise_2d(float(x), float(z))
	var temp: float = _temp.get_noise_2d(float(x), float(z))
	if h <= VoxelConfig.SEA_LEVEL + 1:
		return BlockDefs.Block.SAND
	if h >= 52:
		return BlockDefs.Block.SNOW if h < 57 else BlockDefs.Block.STONE
	if temp < -0.35:
		return BlockDefs.Block.SNOW
	if moist < -0.30:
		return BlockDefs.Block.SAND
	return BlockDefs.Block.GRASS


func generate_chunk(c: VoxelChunk) -> void:
	var ox: int = c.coord.x * VoxelChunk.SIZE_X
	var oz: int = c.coord.y * VoxelChunk.SIZE_Z
	for z in VoxelChunk.SIZE_Z:
		var gz: int = oz + z
		for x in VoxelChunk.SIZE_X:
			var gx: int = ox + x
			var h: int = surface_height(gx, gz)
			var top: int = surface_block(gx, gz, h)
			var sub: int = BlockDefs.Block.SAND if top == BlockDefs.Block.SAND else BlockDefs.Block.DIRT
			for y in h + 1:
				var b: int
				if y == h:
					b = top
				elif y > h - 4:
					b = sub
				else:
					b = BlockDefs.Block.STONE
				if y > 1 and y <= h - CARVE_CRUST and not _near_spawn(gx, gz) and _carved(gx, y, gz, h):
					b = BlockDefs.Block.AIR
				c.set_block(x, y, z, b)
			for y in range(h + 1, VoxelConfig.SEA_LEVEL + 1):
				c.set_block(x, y, z, BlockDefs.Block.WATER)
	c.dirty = true


func _near_spawn(x: int, z: int) -> bool:
	var cx: int = VoxelConfig.world_size_x() / 2
	var cz: int = VoxelConfig.world_size_z() / 2
	return absi(x - cx) <= 10 and absi(z - cz) <= 10


func _carved(x: int, y: int, z: int, h: int) -> bool:
	if y > h - CAVE_MIN_DEPTH:
		return false
	# Tuneis vermes: a intersecao de duas folhas finas de ruido independente e uma
	# curva com secao de poucos blocos. Uma folha so (absf(n) < t) e uma superficie
	# 2D: ela atravessa o mundo inteiro e o fatia em lajes soltas.
	var a: float = _tunnel.get_noise_3d(float(x), float(y) * 1.5, float(z))
	if absf(a) < TUNNEL_THRESHOLD:
		var b: float = _tunnel_b.get_noise_3d(float(x), float(y) * 1.5, float(z))
		if absf(b) < TUNNEL_THRESHOLD:
			return true
	return _cave.get_noise_3d(float(x), float(y), float(z)) > CAVE_THRESHOLD


func decorate_chunk(c: VoxelChunk) -> void:
	var ox: int = c.coord.x * VoxelChunk.SIZE_X
	var oz: int = c.coord.y * VoxelChunk.SIZE_Z
	for z in range(FEATURE_INSET, VoxelChunk.SIZE_Z - FEATURE_INSET):
		var gz: int = oz + z
		for x in range(FEATURE_INSET, VoxelChunk.SIZE_X - FEATURE_INSET):
			var gx: int = ox + x
			if _near_spawn(gx, gz):
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = _mix(gx, gz)
			var r: float = rng.randf()
			var h: int = _column_top(c, x, z)
			if h <= 0:
				continue
			var surface: int = c.get_block(x, h, z)
			if surface == BlockDefs.Block.GRASS and r < TREE_DENSITY:
				_plant_tree(c, x, h, z, rng)
			elif r > 1.0 - BOULDER_DENSITY and h > VoxelConfig.SEA_LEVEL + 2:
				_place_boulder(c, x, h, z, rng)
	c.dirty = true


func _column_top(c: VoxelChunk, x: int, z: int) -> int:
	var y: int = VoxelChunk.SIZE_Y - 1
	while y > 0:
		var b: int = c.get_block(x, y, z)
		if b != BlockDefs.Block.AIR and b != BlockDefs.Block.WATER:
			return y
		y -= 1
	return 0


func _mix(x: int, z: int) -> int:
	var h: int = world_seed
	h = _hash_mix(h, x)
	h = _hash_mix(h, z)
	return h


static func _hash_mix(acc: int, v: int) -> int:
	var m: int = acc * 1103515245 + v * 12345 + 0x5DEECE66
	m = m ^ (m >> 27)
	m = m * 0x2545F491
	return m ^ (m >> 31)


func _plant_tree(c: VoxelChunk, x: int, h: int, z: int, rng: RandomNumberGenerator) -> void:
	var trunk: int = rng.randi_range(4, 6)
	var top: int = mini(h + trunk, VoxelChunk.SIZE_Y - 6)
	for t in range(1, trunk + 1):
		var y: int = h + t
		if y >= VoxelChunk.SIZE_Y:
			break
		if c.get_block(x, y, z) == BlockDefs.Block.AIR:
			c.set_block(x, y, z, BlockDefs.Block.WOOD)
	var r: int = 2
	for dy in range(-1, 3):
		var yy: int = top + dy
		if yy >= VoxelChunk.SIZE_Y:
			continue
		var rr: int = r - absi(dy - 1)
		if rr < 1:
			rr = 1
		for dz in range(-rr, rr + 1):
			for dx in range(-rr, rr + 1):
				if dx * dx + dz * dz > rr * rr + 1:
					continue
				var nx: int = x + dx
				var nz: int = z + dz
				if nx < 0 or nz < 0 or nx >= VoxelChunk.SIZE_X or nz >= VoxelChunk.SIZE_Z:
					continue
				if c.get_block(nx, yy, nz) == BlockDefs.Block.AIR:
					c.set_block(nx, yy, nz, BlockDefs.Block.LEAVES)


func _place_boulder(c: VoxelChunk, x: int, h: int, z: int, rng: RandomNumberGenerator) -> void:
	var size: int = rng.randi_range(1, 2)
	for dy in size:
		for dz in range(-size + 1, size):
			for dx in range(-size + 1, size):
				var nx: int = x + dx
				var nz: int = z + dz
				var ny: int = h + 1 + dy
				if nx < 0 or nz < 0 or nx >= VoxelChunk.SIZE_X or nz >= VoxelChunk.SIZE_Z:
					continue
				if ny >= VoxelChunk.SIZE_Y:
					continue
				if c.get_block(nx, ny, nz) == BlockDefs.Block.AIR:
					c.set_block(nx, ny, nz, BlockDefs.Block.STONE)
