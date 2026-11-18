class_name AetherField
## Memoria espacial do mundo (docs/design/02 I1): grade grosseira acoplada ao voxel,
## com canais que difendem e decaem. Mentes leem daqui em O(1) em vez de raycast.
##
## Storage: um unico PackedFloat32Array achatado [canal][y][z][x]. Packed arrays sao
## copy-on-write, entao `_cur[ch][i] = v` mutaria uma copia silenciosamente; um
## subscript de nivel unico elimina a armadilha.

enum Channel { WORK = 0, BLOOD = 1, FEAR = 2, COUNT = 3 }

const CHANNEL_NAMES: PackedStringArray = ["work", "blood", "fear"]
# Meia-vida em segundos de logica por canal.
const HALF_LIFE: Array = [90.0, 55.0, 120.0]
# Velocidade de difusao (0 = estatico). Barreiras solidas reduzem o fluxo.
const DIFFUSE_RATE: Array = [0.06, 0.16, 0.10]
const MIN_VALUE: float = 0.004
const MAX_VALUE: float = 4.0
const _DIR6: Array = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var cell: int = VoxelConfig.AETHER_CELL
var size_x: int = 0
var size_y: int = 0
var size_z: int = 0
var world: VoxelWorld = null

var _per_channel: int = 0
var _cur := PackedFloat32Array()
var _nxt := PackedFloat32Array()
# Scratch de _neighbours(): realocar por cada celula activa seria ruido no GC.
var _nb_i := PackedInt32Array()
var _nb_w := PackedFloat32Array()


func setup(p_world: VoxelWorld) -> void:
	world = p_world
	cell = VoxelConfig.AETHER_CELL
	size_x = int(ceilf(float(VoxelConfig.world_size_x()) / float(cell)))
	size_y = int(ceilf(float(VoxelChunk.SIZE_Y) / float(cell)))
	size_z = int(ceilf(float(VoxelConfig.world_size_z()) / float(cell)))
	_per_channel = size_x * size_y * size_z
	_cur.resize(int(Channel.COUNT) * _per_channel)
	_nxt.resize(int(Channel.COUNT) * _per_channel)
	_cur.fill(0.0)
	_nxt.fill(0.0)


func in_bounds(c: Vector3i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.z >= 0 \
			and c.x < size_x and c.y < size_y and c.z < size_z


func index_of(c: Vector3i) -> int:
	return (c.y * size_z + c.z) * size_x + c.x


func _i(ch: int, c: Vector3i) -> int:
	return ch * _per_channel + index_of(c)


func cell_of_voxel(p: Vector3i) -> Vector3i:
	return Coords.cell_of_voxel(p, cell)


func cell_of_world(p: Vector3) -> Vector3i:
	return cell_of_voxel(Coords.to_block(p))


func _clamped(c: Vector3i) -> Vector3i:
	return Vector3i(
		clampi(c.x, 0, size_x - 1), clampi(c.y, 0, size_y - 1), clampi(c.z, 0, size_z - 1))


func cell_center(c: Vector3i) -> Vector3:
	return Vector3((c.x + 0.5) * cell, (c.y + 0.5) * cell, (c.z + 0.5) * cell)


func imprint(world_pos: Vector3, ch: int, amount: float) -> void:
	var i := _i(ch, _clamped(cell_of_world(world_pos)))
	_cur[i] = clampf(_cur[i] + amount, 0.0, MAX_VALUE)


func sample(world_pos: Vector3, ch: int) -> float:
	return sample_cell(cell_of_world(world_pos), ch)


func sample_cell(c: Vector3i, ch: int) -> float:
	if not in_bounds(c):
		return 0.0
	return _cur[_i(ch, c)]


func set_cell_value(c: Vector3i, ch: int, v: float) -> void:
	if not in_bounds(c):
		return
	_cur[_i(ch, c)] = clampf(v, 0.0, MAX_VALUE)


## Uma passada de difusao + decaimento. Chamada pelo SimClock em cadencia propria.
##
## Empurra das celulas activas para as vizinhas. No esquema de puxar, uma celula
## fria (`v <= MIN_VALUE`) saia do laco antes de somar os vizinhos e nunca recebia
## fluxo: o rastro ficava confinado a celula original para sempre. Como o fluxo
## sai todo da fonte, a massa conservada e o custo e proporcional ao que esta aceso.
func diffuse_and_decay(elapsed: float) -> void:
	for ch in Channel.COUNT:
		var base: int = ch * _per_channel
		var keep: float = pow(0.5, elapsed / float(HALF_LIFE[ch]))
		var rate: float = float(DIFFUSE_RATE[ch])
		var hot := PackedInt32Array()
		for i in _per_channel:
			var v: float = _cur[base + i]
			_nxt[base + i] = v * keep
			if v > MIN_VALUE:
				hot.append(i)
		if rate <= 0.0:
			continue
		for i in hot:
			var v: float = _cur[base + i]
			_neighbours(i)
			if _nb_i.is_empty():
				continue
			var flow: float = v * rate
			var wsum := 0.0
			for k in _nb_w.size():
				wsum += _nb_w[k]
			for k in _nb_i.size():
				var share: float = flow * _nb_w[k] / wsum
				_nxt[base + _nb_i[k]] += share
				_nxt[base + i] -= share
	# Troca uma unica vez, depois de todos os canais: trocar dentro do laco de
	# canais jogava o buffer de um canal sobre o de outro e apagava sangue e medo.
	for i in _cur.size():
		if _nxt[i] < MIN_VALUE:
			_nxt[i] = 0.0
	var swap := _cur
	_cur = _nxt
	_nxt = swap


## Vizinhos 6-dentro-dos-limites de um indice achatado, com a permeabilidade do
## atravessamento. Barreira solida no caminho reduz drasticamente o fluxo.
func _neighbours(i: int) -> void:
	_nb_i.resize(0)
	_nb_w.resize(0)
	var x: int = i % size_x
	var y: int = int(i / (size_x * size_z))
	var z: int = int(i / size_x) % size_z
	for d in 6:
		var n: Vector3i = _DIR6[d]
		var nx: int = x + n.x
		var ny: int = y + n.y
		var nz: int = z + n.z
		if nx < 0 or ny < 0 or nz < 0 or nx >= size_x or ny >= size_y or nz >= size_z:
			continue
		var mid := Vector3i((x + nx) * cell, (y + ny) * cell, (z + nz) * cell)
		_nb_i.append((ny * size_z + nz) * size_x + nx)
		_nb_w.append(0.15 if world.is_solid(mid) else 1.0)


func total_energy() -> float:
	var t := 0.0
	for i in _cur.size():
		t += _cur[i]
	return t


## [ [Vector3i cell, channel, value], ... ] - usado pela visualizacao e pelo save.
func active_cells(threshold: float) -> Array:
	var out: Array = []
	for ch in Channel.COUNT:
		var base: int = ch * _per_channel
		for i in _per_channel:
			if _cur[base + i] <= threshold:
				continue
			var x: int = i % size_x
			var z: int = int(i / size_x) % size_z
			var y: int = int(i / (size_x * size_z))
			out.append([Vector3i(x, y, z), ch, _cur[base + i]])
	return out


func channel_totals() -> Array:
	var out: Array = []
	for ch in Channel.COUNT:
		var t := 0.0
		var base: int = ch * _per_channel
		for i in _per_channel:
			t += _cur[base + i]
		out.append(t)
	return out


func to_dict() -> Dictionary:
	var cells_as_list: Array = []
	for entry in active_cells(0.01):
		var c: Vector3i = entry[0]
		cells_as_list.append([c.x, c.y, c.z, entry[1], entry[2]])
	return {"cell": cell, "sx": size_x, "sy": size_y, "sz": size_z, "cells": cells_as_list}


func from_dict(d: Dictionary) -> bool:
	if int(d.get("cell", -1)) != cell:
		return false
	if int(d.get("sx", size_x)) != size_x or int(d.get("sy", size_y)) != size_y \
			or int(d.get("sz", size_z)) != size_z:
		return false
	_cur.fill(0.0)
	for raw in d.get("cells", []):
		set_cell_value(Vector3i(int(raw[0]), int(raw[1]), int(raw[2])), int(raw[3]), float(raw[4]))
	return true
