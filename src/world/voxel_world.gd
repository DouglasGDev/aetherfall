class_name VoxelWorld
## Dono dos chunks: queries globais, malharia com face-culling + AO por vertice,
## raycast DDA e colisao AABB-contra-voxel. Corpo voxel resolvido por aqui (sem
## trimesh), que e o que permite rodar igual em headless e em dedicado.

signal block_changed(pos: Vector3i, prev: int, now: int)

const FACE_NORMALS: Array = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1),
	Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(0, -1, 0),
]
# Vertices por face em ordem CCW vista de fora (normal externa verificada);
# _emit_face os indexa em CW porque o Godot trata horario-visto-de-fora como frontal.
const FACE_CORNERS: Array = [
	[Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(1, 1, 1), Vector3i(1, 0, 1)],   # +X
	[Vector3i(0, 0, 1), Vector3i(0, 1, 1), Vector3i(0, 1, 0), Vector3i(0, 0, 0)],   # -X
	[Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(0, 1, 1)],   # +Z
	[Vector3i(1, 0, 0), Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0)],   # -Z
	[Vector3i(0, 1, 0), Vector3i(0, 1, 1), Vector3i(1, 1, 1), Vector3i(1, 1, 0)],   # +Y
	[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 1), Vector3i(0, 0, 1)],   # -Y
]
const FACE_UVS: Array = [
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)],
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)],
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)],
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
]
# tile_for() espera 0=topo 1=base 2..5=laterais: traduz da ordem das faces acima.
const FACE_TILE: Array = [2, 3, 4, 5, 0, 1]
const FACE_TINT: Array = [0.88, 0.88, 0.82, 0.82, 1.0, 0.60]
const AO_MIN_BRIGHT: float = 0.42
const WATER_TOP_DROP: float = 0.12
const MAX_DDA_STEPS: int = 512

const CHUNK_SIZE_X: int = VoxelChunk.SIZE_X
const CHUNK_SIZE_Y: int = VoxelChunk.SIZE_Y
const CHUNK_SIZE_Z: int = VoxelChunk.SIZE_Z

var chunks: Dictionary = {}          # Vector2i -> VoxelChunk
var edits: Dictionary = {}           # Vector3i -> int (edicoes persistentes)
var gen: WorldGen = WorldGen.new()
var nodes_root: Node3D = null

# Copia linear do mundo inteiro: (y * _sz + z) * _sx + x.
var _flat: PackedByteArray = PackedByteArray()
var _sx: int = 0
var _sz: int = 0
var _flat_ready: bool = false

var _atlas: Texture2D = null
var _mat_opaque: StandardMaterial3D = null
var _mat_water: StandardMaterial3D = null
var _mat_glass: StandardMaterial3D = null
var _dirty: Array = []
var _last_mesh_ms: float = 0.0
var _meshes_built: int = 0

static var _ao_offsets: Array = []
static var _tables_ready: bool = false


func _init() -> void:
	_ensure_tables()
	_sx = VoxelConfig.world_size_x()
	_sz = VoxelConfig.world_size_z()


func setup_world(p_root: Node3D) -> void:
	nodes_root = p_root
	_build_materials()


func _build_materials() -> void:
	_atlas = VoxelAtlas.build_texture()
	_mat_opaque = StandardMaterial3D.new()
	_mat_opaque.albedo_texture = _atlas
	_mat_opaque.vertex_color_use_as_albedo = true
	_mat_opaque.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_mat_opaque.roughness = 0.92
	_mat_opaque.metallic = 0.0
	_mat_water = StandardMaterial3D.new()
	_mat_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_water.albedo_texture = _atlas
	_mat_water.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_water.roughness = 0.3
	_mat_water.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# O vidro e amostrado como a agua mas sem o recuo de topo, e com o filtro
	# NEAREST da pedra: linear em cima de um tile que e quase todo alpha deixa a
	# chapa borrada em vez de limpa.
	_mat_glass = StandardMaterial3D.new()
	_mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_glass.albedo_texture = _atlas
	_mat_glass.vertex_color_use_as_albedo = true
	_mat_glass.roughness = 0.25
	_mat_glass.metallic = 0.0
	_mat_glass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS


func generate(p_seed: int) -> void:
	_release_mesh_nodes()
	_flat_ready = false
	gen.setup(p_seed)
	chunks.clear()
	for cz in VoxelConfig.WORLD_CHUNKS_Z:
		for cx in VoxelConfig.WORLD_CHUNKS_X:
			var key := Vector2i(cx, cz)
			var c := VoxelChunk.new(key)
			chunks[key] = c
			gen.generate_chunk(c)
	# Decoracao em passagem separada: arvores so escrevem dentro do proprio chunk
	# (inset de 3), o que mantem a geracao deterministica sem escrita entre vizinhos.
	for key in chunks:
		gen.decorate_chunk(chunks[key])
	_rebuild_flat()


## A malharia e o raycast perguntam pelo vizinho de cada voxel, o que da dezenas
## de milhares de perguntas por chunk. Respondê-las pelo dicionario de chunks
## (chave Vector2i) custava ~250 ms por chunk e congelava o boot por ~16 s; com a
## copia linear a resposta vira um indice de array.
func _rebuild_flat() -> void:
	_flat.resize(CHUNK_SIZE_Y * _sz * _sx)
	_flat.fill(BlockDefs.Block.AIR)
	for key in chunks:
		var c: VoxelChunk = chunks[key]
		var ox: int = c.coord.x * CHUNK_SIZE_X
		var oz: int = c.coord.y * CHUNK_SIZE_Z
		for y in CHUNK_SIZE_Y:
			for z in CHUNK_SIZE_Z:
				var src: int = (y * CHUNK_SIZE_Z + z) * CHUNK_SIZE_X
				var dst: int = (y * _sz + oz + z) * _sx + ox
				for x in CHUNK_SIZE_X:
					_flat[dst + x] = c.data[src + x]
	_flat_ready = true


## Regerar o mundo nao pode deixar as malhas antigas penduradas na arvore.
func _release_mesh_nodes() -> void:
	for key in chunks:
		var c: VoxelChunk = chunks[key]
		if c.mesh_instance != null:
			c.mesh_instance.queue_free()
		c.mesh_instance = null
		c.dirty = true
	_dirty.clear()


func generate_meshes_all() -> void:
	for key in chunks:
		var c: VoxelChunk = chunks[key]
		if c.dirty:
			build_chunk_mesh(c)


func apply_edits(source: Dictionary) -> void:
	edits.clear()
	for k in source:
		var parts: PackedStringArray = String(k).split(",")
		if parts.size() != 3:
			continue
		var pos := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
		var b: int = int(source[k])
		edits[pos] = b
		_write_raw(pos, b)
		_touch_chunks_of(pos, true)


## Chunks ainda nao malhados ganham mesh sob demanda; ja malhados so sujos.
func process(p_frame_budget: int) -> void:
	if _dirty.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var count: int = mini(p_frame_budget, _dirty.size())
	for i in count:
		var c: VoxelChunk = _dirty.pop_front()
		build_chunk_mesh(c)
	_last_mesh_ms = float(Time.get_ticks_usec() - t0) / 1000.0


func pending_meshes() -> int:
	return _dirty.size()


func last_mesh_ms() -> float:
	return _last_mesh_ms


func meshes_built() -> int:
	return _meshes_built


func chunk_at(p: Vector3i) -> VoxelChunk:
	return chunks.get(Coords.chunk_of(p))


## Total de triangulos malhados agora: e a medida que prova que o face-culling
## cortou as faces internas (chunks cheios nao podem dar triangulo de volume).
func triangle_count() -> int:
	var n := 0
	for key in chunks:
		var c: VoxelChunk = chunks[key]
		if c.mesh_instance == null or c.mesh_instance.mesh == null:
			continue
		for s in c.mesh_instance.mesh.get_surface_count():
			var arr: Array = c.mesh_instance.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			n += int(idx.size() / 3)
	return n


func get_block(p: Vector3i) -> int:
	return get_block_xyz(p.x, p.y, p.z)


## Fora dos limites: x/z e y<0 sao solidos (parede invisivel e piso do mundo),
## y acima do topo e ar.
func get_block_xyz(x: int, y: int, z: int) -> int:
	if y < 0:
		return BlockDefs.Block.STONE
	if y >= CHUNK_SIZE_Y:
		return BlockDefs.Block.AIR
	if x < 0 or z < 0 or x >= _sx or z >= _sz:
		return BlockDefs.Block.STONE
	if _flat_ready:
		return _flat[(y * _sz + z) * _sx + x]
	var c = chunks.get(Coords.chunk_of(Vector3i(x, y, z)))
	if c == null:
		return BlockDefs.Block.STONE
	var l := Coords.local_of(Vector3i(x, y, z), c.coord)
	return c.get_block(l.x, l.y, l.z)


func _write_raw(p: Vector3i, b: int) -> void:
	var c := chunk_at(p)
	if c == null:
		return
	var l := Coords.local_of(p, c.coord)
	c.set_block(l.x, l.y, l.z, b)
	if _flat_ready:
		_flat[(p.y * _sz + p.z) * _sx + p.x] = b


func set_block(p: Vector3i, b: int, record: bool = true) -> bool:
	if not VoxelConfig.in_world_bounds(p):
		return false
	var prev: int = get_block(p)
	if prev == b:
		return false
	_write_raw(p, b)
	if record:
		edits[p] = b
	_touch_chunks_of(p, true)
	block_changed.emit(p, prev, b)
	return true


func _touch_chunks_of(p: Vector3i, force: bool) -> void:
	var key := Coords.chunk_of(p)
	_mark(key)
	var l := Coords.local_of(p, key)
	if l.x == 0:
		_mark(key + Vector2i(-1, 0))
	elif l.x == CHUNK_SIZE_X - 1:
		_mark(key + Vector2i(1, 0))
	if l.z == 0:
		_mark(key + Vector2i(0, -1))
	elif l.z == CHUNK_SIZE_Z - 1:
		_mark(key + Vector2i(0, 1))


func _mark(key: Vector2i) -> void:
	var c = chunks.get(key)
	if c == null:
		return
	c.dirty = true
	if not _dirty.has(c):
		_dirty.append(c)


func is_solid(p: Vector3i) -> bool:
	return BlockDefs.is_solid(get_block(p))


func is_solid_xyz(x: int, y: int, z: int) -> bool:
	return BlockDefs.is_solid(get_block_xyz(x, y, z))


func is_water_xyz(x: int, y: int, z: int) -> bool:
	return get_block_xyz(x, y, z) == BlockDefs.Block.WATER


func aabb_hits_solid(box: AABB) -> bool:
	var lo := Vector3i(
		floori(box.position.x), floori(box.position.y), floori(box.position.z))
	var hi := Vector3i(
		floori(box.end.x - 0.0001), floori(box.end.y - 0.0001), floori(box.end.z - 0.0001))
	for y in range(lo.y, hi.y + 1):
		for z in range(lo.z, hi.z + 1):
			for x in range(lo.x, hi.x + 1):
				if is_solid_xyz(x, y, z):
					return true
	return false


func box_in_water(box: AABB) -> bool:
	var lo := Vector3i(
		floori(box.position.x), floori(box.position.y), floori(box.position.z))
	var hi := Vector3i(floori(box.end.x), floori(box.end.y), floori(box.end.z))
	for y in range(lo.y, hi.y + 1):
		for z in range(lo.z, hi.z + 1):
			for x in range(lo.x, hi.x + 1):
				if is_water_xyz(x, y, z):
					return true
	return false


class VoxelRayHit:
	var valid: bool = false
	var voxel := Vector3i.ZERO
	var normal := Vector3i.ZERO
	var point := Vector3.ZERO
	var block: int = 0
	var distance: float = 0.0


## Sinal do eixo do raio. Nao e signi(): signi trunca o float para int antes de
## comparar, entao signi(-0.783) devolve 0 e todo raio inclinado ficava preso na
## celula de origem.
static func _axis_sign(v: float) -> int:
	if v > 1e-8:
		return 1
	if v < -1e-8:
		return -1
	return 0


## Amanatides & Woo: atravessia de grade exatamente na ordem de fronteira.
func ray_voxel(origin: Vector3, direction: Vector3, max_dist: float) -> VoxelRayHit:
	var res := VoxelRayHit.new()
	if direction.length_squared() < 1e-12:
		return res
	var d := direction.normalized()
	var cell := Coords.to_block(origin)
	var step := Vector3i(_axis_sign(d.x), _axis_sign(d.y), _axis_sign(d.z))
	var t_max := Vector3(INF, INF, INF)
	var t_delta := Vector3(INF, INF, INF)
	for axis in 3:
		var comp: float = d[axis]
		if absf(comp) > 1e-8:
			t_delta[axis] = absf(1.0 / comp)
			var bound: float = float(cell[axis]) + (1.0 if step[axis] > 0 else 0.0)
			t_max[axis] = (bound - origin[axis]) / comp
	var normal := Vector3i.ZERO
	var travelled := 0.0
	for _iter in MAX_DDA_STEPS:
		if is_solid_xyz(cell.x, cell.y, cell.z):
			res.valid = true
			res.voxel = cell
			res.normal = normal
			res.block = get_block(cell)
			res.distance = travelled
			res.point = origin + d * maxf(travelled, 0.0)
			return res
		if t_max.x <= t_max.y and t_max.x <= t_max.z:
			travelled = t_max.x
			t_max.x += t_delta.x
			cell.x += step.x
			normal = Vector3i(-step.x, 0, 0)
		elif t_max.y <= t_max.z:
			travelled = t_max.y
			t_max.y += t_delta.y
			cell.y += step.y
			normal = Vector3i(0, -step.y, 0)
		else:
			travelled = t_max.z
			t_max.z += t_delta.z
			cell.z += step.z
			normal = Vector3i(0, 0, -step.z)
		if travelled > max_dist:
			break
	return res


func line_of_sight(from: Vector3, to: Vector3) -> bool:
	var dir := to - from
	var dist := dir.length()
	if dist < 0.001:
		return true
	var hit := ray_voxel(from, dir, dist)
	return (not hit.valid) or hit.distance >= dist - 0.05


func surface_height(x: int, z: int) -> int:
	var y := CHUNK_SIZE_Y - 1
	while y > 0:
		if is_solid_xyz(x, y, z):
			return y
		y -= 1
	return 0


# ------------------------------------------------------------------ malharia

static func _ensure_tables() -> void:
	if _tables_ready:
		return
	for f in FACE_NORMALS.size():
		var n: Vector3i = FACE_NORMALS[f]
		var axes: Array = []
		for a in 3:
			if n[a] == 0:
				axes.append(a)
		var per_corner: Array = []
		for k in 4:
			var corner: Vector3i = FACE_CORNERS[f][k]
			var u1 := Vector3i.ZERO
			var u2 := Vector3i.ZERO
			u1[axes[0]] = 1 if corner[axes[0]] == 1 else -1
			u2[axes[1]] = 1 if corner[axes[1]] == 1 else -1
			per_corner.append([n + u1, n + u2, n + u1 + u2])
		_ao_offsets.append(per_corner)
	_tables_ready = true


func build_chunk_mesh(c: VoxelChunk) -> void:
	var ox: int = c.coord.x * CHUNK_SIZE_X
	var oz: int = c.coord.y * CHUNK_SIZE_Z

	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var uv := PackedVector2Array()
	var cl := PackedColorArray()
	var ix := PackedInt32Array()

	var wv := PackedVector3Array()
	var wn := PackedVector3Array()
	var wuv := PackedVector2Array()
	var wc := PackedColorArray()
	var wi := PackedInt32Array()

	var gv := PackedVector3Array()
	var gn := PackedVector3Array()
	var guv := PackedVector2Array()
	var gc := PackedColorArray()
	var gi := PackedInt32Array()

	for y in CHUNK_SIZE_Y:
		for z in CHUNK_SIZE_Z:
			var gz: int = oz + z
			for x in CHUNK_SIZE_X:
				var b: int = c.get_block(x, y, z)
				if b == BlockDefs.Block.AIR:
					continue
				var gx: int = ox + x
				var dr: int = BlockDefs.draw_of(b)
				for f in 6:
					var n: Vector3i = FACE_NORMALS[f]
					var nb: int = get_block_xyz(gx + n.x, y + n.y, gz + n.z)
					if dr == BlockDefs.Draw.LIQUID:
						if nb != BlockDefs.Block.AIR:
							continue
					elif dr == BlockDefs.Draw.ALPHA:
						# panos contra panos nao tem face: a emenda de dois vidros
						# identicos e uma superficie so na janela do jogador
						if nb == b or BlockDefs.is_opaque(nb):
							continue
					elif BlockDefs.is_opaque(nb):
						continue
					var tile: int = BlockDefs.tile_for(b, FACE_TILE[f])
					if dr == BlockDefs.Draw.LIQUID:
						_emit_face(wv, wn, wuv, wc, wi, gx, y, gz, f, tile,
							PackedFloat32Array([1.0, 1.0, 1.0, 1.0]), FACE_TINT[f], WATER_TOP_DROP)
					elif dr == BlockDefs.Draw.ALPHA:
						_emit_face(gv, gn, guv, gc, gi, gx, y, gz, f, tile,
							_corner_ao_array(gx, y, gz, f), FACE_TINT[f], 0.0)
					else:
						var ao := _corner_ao_array(gx, y, gz, f)
						var jitter: float = float(_hash3(gx, y, gz) % 5) * 0.012
						_emit_face(v, nr, uv, cl, ix, gx, y, gz, f, tile, ao,
							FACE_TINT[f] + jitter, 0.0)

	var mesh := ArrayMesh.new()
	if not v.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surface_arrays(v, nr, uv, cl, ix))
		mesh.surface_set_material(0, _mat_opaque)
	if not wv.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surface_arrays(wv, wn, wuv, wc, wi))
		mesh.surface_set_material(1, _mat_water)
	if not gv.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surface_arrays(gv, gn, guv, gc, gi))
		mesh.surface_set_material(2, _mat_glass)

	if c.mesh_instance == null:
		c.mesh_instance = MeshInstance3D.new()
		c.mesh_instance.name = "chunk_%d_%d" % [c.coord.x, c.coord.y]
		nodes_root.add_child(c.mesh_instance)
	c.mesh_instance.mesh = mesh
	c.dirty = false
	_meshes_built += 1


func _corner_ao_array(gx: int, gy: int, gz: int, f: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(4)
	var corners: Array = _ao_offsets[f]
	for k in 4:
		var offs: Array = corners[k]
		var s1: Vector3i = offs[0]
		var s2: Vector3i = offs[1]
		var cr: Vector3i = offs[2]
		var a: int = _opaque_at(gx + s1.x, gy + s1.y, gz + s1.z)
		var b: int = _opaque_at(gx + s2.x, gy + s2.y, gz + s2.z)
		var cc: int = _opaque_at(gx + cr.x, gy + cr.y, gz + cr.z)
		var ao: int = 3 - (a + b + cc)
		if a == 1 and b == 1:
			ao = 0
		out[k] = lerpf(AO_MIN_BRIGHT, 1.0, float(ao) / 3.0)
	return out


func _opaque_at(x: int, y: int, z: int) -> int:
	return 1 if BlockDefs.is_opaque(get_block_xyz(x, y, z)) else 0


static func _surface_arrays(
	verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array,
	cols: PackedColorArray, idx: PackedInt32Array) -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = norms
	a[Mesh.ARRAY_TEX_UV] = uvs
	a[Mesh.ARRAY_COLOR] = cols
	a[Mesh.ARRAY_INDEX] = idx
	return a


func _emit_face(
	verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array,
	cols: PackedColorArray, idx: PackedInt32Array,
	gx: int, gy: int, gz: int, f: int, tile: int,
	ao: PackedFloat32Array, tint: float, top_drop: float) -> void:
	var base: int = verts.size()
	var corners: Array = FACE_CORNERS[f]
	var face_uvs: Array = FACE_UVS[f]
	var n: Vector3i = FACE_NORMALS[f]
	var tu: float = float(tile % VoxelAtlas.GRID) / VoxelAtlas.GRID
	var tv: float = float(int(tile / VoxelAtlas.GRID)) / VoxelAtlas.GRID
	var span: float = 1.0 / VoxelAtlas.GRID
	var inset: float = 0.35 / float(VoxelAtlas.GRID * VoxelAtlas.TILE)
	for k in 4:
		var corner: Vector3i = corners[k]
		var py: float = float(gy) + float(corner.y)
		if top_drop > 0.0 and corner.y == 1:
			py -= top_drop
		verts.append(Vector3(float(gx) + float(corner.x), py, float(gz) + float(corner.z)))
		norms.append(Vector3(n))
		uvs.append(Vector2(
			tu + inset + face_uvs[k].x * (span - 2.0 * inset),
			tv + inset + face_uvs[k].y * (span - 2.0 * inset)))
		var bright: float = clampf(tint * ao[k], 0.05, 1.2)
		cols.append(Color(bright, bright, bright, 1.0))
	# CW visto de fora = face frontal no Godot (Vulkan inverte o Y no framebuffer):
	# com (0,1,2)/(0,2,3) o rasterizador descartava todo topo e os blocos
	# apareciam transparentes.
	idx.append(base)
	idx.append(base + 2)
	idx.append(base + 1)
	idx.append(base)
	idx.append(base + 3)
	idx.append(base + 2)


static func _hash3(x: int, y: int, z: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (z * 83492791))
