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
# Quantos blocos de coluna separam o topo da ravina do beiral que ja conta como
# exposto (dossie 23 §3.10b): `expos = 1 - (topo - y) / EXPOSURE_FALL`. Com 4, a face
# do proprio topo chega 1,000, uma celula abaixo sai 0,750 e quatro abaixo sai zero --
# o gradiente que a sonda §5.4 mede em duas caixas. Menor que isso e degrau na parede,
# maior e morro inteiro escurecendo junto, que e o braco (c) rejeitado.
const EXPOSURE_FALL: int = 4

# Teto de tempo de UM frame de malharia, em microsegundos (dossie 24 §3.3, braco B).
# Derivado da medicao desta perna, nao chutado: um chunk sozinho custa 45,04-152,74 ms
# (128 amostras, §2.2.2) e o `process()` de antes li o relogio FORA do laco, entao um
# quadro pagava dois de uma vez e o periodo ia a 152-192 ms. Com 8 000 µs de teto e o
# nivel `y` mais caro medido em 2,39 ms (152,74 ÷ 64), o pior frame honesto sai 10,4 ms
# contra os 33,3 ms da janela de travada -- folga de 3x, e o overshoot e limitado a UMA
# fatia porque o relogio e perguntado antes de cada nivel, nunca no meio de um.
# O nome tem sufixo de tempo e mora na classe do laco: `MESH_BUDGET` de `main.gd:28`
# continua sendo ITENS por frame (§3.4) e as duas grandezas nao se traduzem entre si.
const MESH_FRAME_BUDGET_US: int = 8000

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
var _mat_opaque: ShaderMaterial = null
var _mat_water: ShaderMaterial = null
var _mat_glass: StandardMaterial3D = null
# A direcao do sol e do `main.gd`, que cria o no, nao daqui; o material da agua
# precisa dela porque a caustica so liga com o sol alto (dossie 23 §2). O default
# e o zenith, que e o que o shader tambem declara -- ausencia de fiação muda o
# visual, nunca o comportamento do mundo.
var _water_sun: Vector3 = Vector3.UP
var _dirty: Array = []
# A fatia em voo (dossie 24 §3.3): o chunk da cabeca da fila que ja comecou a ser malhado,
# com o cursor de nivel `y` e os quinze arrays que ele ja encheu. So existe UMA por vez, do
# mesmo jeito que so existia um chunk em trabalho antes do corte -- o que mudou e que ele
# agora atravessa frames. `pending_meshes()` o conta porque a fila nao o descartou.
var _slice: _MeshSlice = null
var _last_mesh_ms: float = 0.0
var _meshes_built: int = 0
# Custo de edicao local (dossie 07 §4): `last_mesh_ms()` times o lote inteiro do
# frame, nao uma edicao ate o mesh pronto dela, entao o preco do re-mesh — que e
# exatamente onde um mesher novo ganharia ou perderia — nao tinha clock nenhum.
# O carimbo nasce em `_mark`, quando a edicao suja o chunk, e morre em
# `build_chunk_mesh`, que fecha a conta em microsegundos.
var _edit_stamp: Dictionary = {}    # Vector2i (coord) -> usec do carimbo aberto
var _edit_us_total: int = 0
var _edit_us_worst: int = 0
var _edit_us_count: int = 0
# Os MICROSEGUNDOS DE TRABALHO do mesher naquele chunk, somados entre o carimbo abrir e
# fechar (dossie 24 §5.1 gate 2). Moram separados do span porque com fatia as duas
# grandezas se separam: o span de um chunk cortado a 8 000 µs sao ~11 frames de relogio
# wall, e 10 deles nao tem malharia nenhuma — medido, span 95 351 -> 128 663 (+34,9 %)
# enquanto o trabalho caia 4,7 %. Sem este nome o gate 2 acusaria de "troca de vitima" o
# proprio desenho do braco B, que e a classe do furo #44: uma testemunha que passa a
# medir outra coisa sem dizer.
var _edit_build_us: Dictionary = {}  # Vector2i (coord) -> usec de malha ja gastos
var _edit_build_total: int = 0
var _edit_build_worst: int = 0
# Cache de topo de coluna do chunk sendo malhado agora (dossie 23 §3.10b): um `int` por
# coluna, e a unica fonte do `expos` que vai ao `COLOR.a` do grupo opaco. Varre **uma vez
# por rebuild**, nao por face nem por voxel — o braco (b) rejeitado custaria ate 6 faces
# × 64 leituras no lugar exato onde a casa ja teve de aprender a nao varrer o mundo por
# triangulo (furo #41). Os tres contadores abaixo sao a testemunha: a suíte asserta
# `col_lidas == chunks_lidos * CHUNK_SIZE_X * CHUNK_SIZE_Z`, que e aritmetica de uma
# leitura por coluna, e `faces_opacas` ao lado mostra o que o braco rejeitado custaria.
var _ct_top: PackedInt32Array = PackedInt32Array()
var _exposure_chunks: int = 0
var _exposure_cols: int = 0
var _exposure_faces: int = 0

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
	# O opaco passou a `ShaderMaterial` porque o molhamento da Fase 2 e um numero por
	# vertice (o `COLOR.a` do §3.10b) e um `StandardMaterial3D` nao le canal nenhum: ele
	# multiplica o RGB pelo tint da face e descarta o alfa. O que o material velho fazia
	# esta reproduzido dentro da SOURCE do `OpaqueSurface`, e o braco `--weather=0` da
	# sonda §5.4 e que mede se a reproducao e fiel.
	_mat_opaque = OpaqueSurface.build_material(_atlas)
	_mat_water = WaterSurface.build_material(_atlas, _water_sun)
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


## O atlas do mundo, emprestado aos dois corpos: o bloco na mao do rig de 3a
## pessoa e o bloco na frente da lente amostram os mesmos tiles do bloco na
## parede, nao uma reamostragem a parte.
func atlas_texture() -> Texture2D:
	return _atlas


## O material da agua, emprestado a quem precisa olhá-lo: a suíte (§5.1) prova por
## aqui que o surface de água de um chunk real carrega um `ShaderMaterial`, e o
## `main.gd` grava nele a direção do sol.
func water_material() -> ShaderMaterial:
	return _mat_water


## O material opaco, pela mesma porta da agua (§5.3): a suíte prova por aqui que o surface
## opaco de um chunk real carrega um `ShaderMaterial` -- e o `main.gd` grava nele o
## `molhado` que o `Weather` integra, sem que o clima precise conhecer o mundo.
func opaque_material() -> ShaderMaterial:
	return _mat_opaque


func set_water_sun_direction(dir: Vector3) -> void:
	_water_sun = dir
	_mat_water.set_shader_parameter("sun_dir", dir)


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
	# A fatia em voo morre com o mundo antigo: os arrays dela sao de chunks que acabaram
	# de ter o nó liberado, e comita-los depois penduraria uma malha no lugar errado.
	_slice = null
	# Carimbos abertos do mundo antigo morrem com ele: o chunk nao vai ser malhado
	# nunca mais. O AGGREGADO, nao -- azera-lo aqui faria o `worst` mentir depois de
	# um load e o `count` zerado na ultima linha do diagnostico seria lido como
	# instrumento morto, que e justamente o erro que o mandato 1 nao deixa passar.
	_edit_stamp.clear()
	_edit_build_us.clear()


func generate_meshes_all() -> void:
	# Malha o mundo inteiro de uma vez, entao nao pode haver fatia pela metade: o cache de
	# topo de coluna (`_ct_top`) e do chunk sendo malhado AGORA, e dois construtores
	# escrevendo nele ao mesmo tempo daria ao chunk em voo o relevo de outro.
	_slice = null
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


## O estado de um chunk em voo (dossie 24 §3.3, braco B): o cursor do nivel `y` e os
## quinze arrays que o andador ja encheu, que sao exatamente os que `build_chunk_mesh`
## declarava como locais -- agora vivem o tempo de uma cascata de fatias em vez do tempo
## de uma chamada. So um existe por vez (§3.3.1.3): o pico de arrays nao cresce, o que
## cresce e o tempo que eles ficam vivos. `stale` e a edicao que caiu no meio das fatias.
class _MeshSlice:
	var c: VoxelChunk = null
	var y: int = 0
	var stale: bool = false
	# Microsegundos de mesher gastos NESTE chunk ate aqui, acumulados entre frames e entre
	# rodadas quando uma edicao o devolve para o fim da fila. E o par do span (§5.1 gate 2).
	var us: int = 0
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


## Chunks ainda nao malhados ganham mesh sob demanda; ja malhados so sujos.
## O corte tem DUAS unidades e e assim de proposito (dossie 24 §3.4): `p_frame_budget` e
## quantos chunks o frame pode **comecar**, `MESH_FRAME_BUDGET_US` e quanto tempo ele pode
## gastar. Quem manda numa cascata e o relogio -- um chunk fatiado nao cabe em 8 ms -- e o
## teto de itens so mordia antes, quando a unidade de trabalho era o chunk inteiro.
func process(p_frame_budget: int) -> void:
	if _dirty.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var iniciados: int = 0
	var antes := Time.get_ticks_usec()
	while iniciados < p_frame_budget and not _dirty.is_empty():
		if _slice == null:
			_slice = _MeshSlice.new()
			_slice.c = _dirty.front()
			_scan_col_tops(_slice.c)
			var apos := Time.get_ticks_usec()
			_slice.us = apos - antes
			antes = apos
			iniciados += 1
		while _slice.y < CHUNK_SIZE_Y:
			# O relogio DENTRO do laco e a linha desta perna. Lido so no fim do frame, como
			# era antes, ele nao podia cortar nada: era assim que um quadro pagava dois
			# chunks de ~87 ms (furo #41; 144-198 ms medidos no MESMO frame desta suíte).
			if antes - t0 >= MESH_FRAME_BUDGET_US:
				break
			_mesh_level(_slice)
			_slice.y += 1
			# A mesma leitura serve as duas contas: ela e o "agora" do teto no proximo giro
			# e o fim do nivel que acabou de rodar. Por isso o custo de trabalho do chunk
			# nao custa um relogio a mais no caminho quente (§3.3.1.3 cobra as arrays vivas,
			# nao a colheita).
			var depois := Time.get_ticks_usec()
			_slice.us += depois - antes
			antes = depois
		if _slice.y < CHUNK_SIZE_Y:
			break
		_finish_slice()
		antes = Time.get_ticks_usec()
	_last_mesh_ms = float(Time.get_ticks_usec() - t0) / 1000.0


## Fecha a fatia completa: comita a malha, tira o chunk da fila e, se uma edicao caiu no
## meio das fatias, devolve o chunk para o fim da fila com o `dirty` que o comitimento
## acabou de apagar. Sem esta ultima linha o mundo desenhado pararia de ser o mundo que
## existe, que e a unica propriedade que o §3.3 usou para escolher o braco.
func _finish_slice() -> void:
	var c: VoxelChunk = _slice.c
	var caduca: bool = _slice.stale
	_commit_slice(_slice)
	_slice = null
	_dirty.pop_front()
	if caduca:
		# O carimbo FICA aberto: a segunda rodada vai somar trabalho nele, e fechar agora
		# contaria um chunk que o jogador ainda nao ve pronto — a mesma classe do erro que
		# o §3.3.1.2 temia ao fechar o carimbo numa fatia do meio.
		c.dirty = true
		_dirty.append(c)
	else:
		_record_edit_cost(c)


## O chunk inteiro, de uma vez, sem perguntar ao relogio: o caminho do boot e de
## `generate_meshes_all()`, onde nao ha quadro para proteger -- e por isso que a malha do
## boot nao muda de byte com esta perna, e o SHA do bake-off continua sendo a testemunha.
func build_chunk_mesh(c: VoxelChunk) -> void:
	var st := _MeshSlice.new()
	st.c = c
	var t0 := Time.get_ticks_usec()
	_scan_col_tops(c)
	while st.y < CHUNK_SIZE_Y:
		_mesh_level(st)
		st.y += 1
	st.us = Time.get_ticks_usec() - t0
	_commit_slice(st)
	_record_edit_cost(c)


## Um nivel `y` do chunk dentro do estado da fatia: o corpo exato do laco que era interno a
## `build_chunk_mesh`, com arrays, origem e nivel lidos do estado. Compartilhar o corpo com
## o caminho inteiro e o que faz a borda de fatia (dossie 24 §3.3.1.1) sair do mesmo mesher
## que o boot usa -- se a regra de emissao mudar, muda nos dois juntos.
func _mesh_level(st: _MeshSlice) -> void:
	var c: VoxelChunk = st.c
	var ox: int = c.coord.x * CHUNK_SIZE_X
	var oz: int = c.coord.y * CHUNK_SIZE_Z
	var y: int = st.y
	for z in CHUNK_SIZE_Z:
		var gz: int = oz + z
		for x in CHUNK_SIZE_X:
			var b: int = c.get_block(x, y, z)
			if b == BlockDefs.Block.AIR:
				continue
			var gx: int = ox + x
			var dr: int = BlockDefs.draw_of(b)
			# O que o shader precisa saber antes de existir pixel (§3.3): se este
			# bloco e o topo de uma coluna (vizinho de cima AIR) e quantos blocos
			# de agua ha embaixo dele, em quartos de 1, saturado em 4. Le-se uma
			# unica vez por bloco, e so quando a primeira face dele sai: no
			# interior do oceano todo vizinho e agua, nenhuma face e emitida, e
			# ler a coluna la seria pagar cinco consultas por voxel para alimentar
			# triangulo nenhum. O -1 e o "ainda nao lido", nao um valor de canal.
			var water_flags := Vector2(-1.0, -1.0)
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
					if water_flags.x < 0.0:
						water_flags = Vector2(
							1.0 if get_block_xyz(gx, y + 1, gz) == BlockDefs.Block.AIR else 0.0,
							float(_water_blocks_below(gx, y, gz)) / 4.0)
					_emit_face(st.wv, st.wn, st.wuv, st.wc, st.wi, gx, y, gz, f, tile,
						PackedFloat32Array([1.0, 1.0, 1.0, 1.0]), FACE_TINT[f],
						WATER_TOP_DROP, water_flags)
				elif dr == BlockDefs.Draw.ALPHA:
					_emit_face(st.gv, st.gn, st.guv, st.gc, st.gi, gx, y, gz, f, tile,
						_corner_ao_array(gx, y, gz, f), FACE_TINT[f], 0.0)
				else:
					var ao := _corner_ao_array(gx, y, gz, f)
					var jitter: float = float(_hash3(gx, y, gz) % 5) * 0.012
					_exposure_faces += 1
					_emit_face(st.v, st.nr, st.uv, st.cl, st.ix, gx, y, gz, f, tile, ao,
						FACE_TINT[f] + jitter, 0.0, Vector2.ZERO,
						_ct_top[z * CHUNK_SIZE_X + x])


## O ponto de comitimento: so aqui o chunk ganha malha, `dirty` vira falso, o contador
## sobe e o carimbo de latencia fecha. Fechar o carimbo numa fatia do meio faria o
## `mean_us` do instrumento medir outra coisa sem dizer, que e a classe do furo #44/#56
## (a testemunha virar constante) e e o preco que o §3.3.1.2 do dossie 24 cobra do B.
func _commit_slice(st: _MeshSlice) -> void:
	var tc := Time.get_ticks_usec()
	var c: VoxelChunk = st.c
	var mesh := ArrayMesh.new()
	# O indice do surface e o que era antes de acrescentar: um chunk de vidro sem
	# agua tem dois surfaces e o hardcoded 2 caia fora deles, e o pano ficava sem
	# material nenhum (o erro do engine passavaquieto na suíte de triangulos).
	var s := 0
	if not st.v.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surface_arrays(st.v, st.nr, st.uv, st.cl, st.ix))
		mesh.surface_set_material(s, _mat_opaque)
		s += 1
	if not st.wv.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surface_arrays(st.wv, st.wn, st.wuv, st.wc, st.wi))
		mesh.surface_set_material(s, _mat_water)
		s += 1
	if not st.gv.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surface_arrays(st.gv, st.gn, st.guv, st.gc, st.gi))
		mesh.surface_set_material(s, _mat_glass)
		s += 1

	if c.mesh_instance == null:
		c.mesh_instance = MeshInstance3D.new()
		c.mesh_instance.name = "chunk_%d_%d" % [c.coord.x, c.coord.y]
		nodes_root.add_child(c.mesh_instance)
	c.mesh_instance.mesh = mesh
	c.dirty = false
	_meshes_built += 1
	# O commit (o `ArrayMesh`, o upload das superficies e o no que nasce) e trabalho DESTE
	# chunk, nao do proximo que herdar o relogio do frame: por isso ele entra em `st.us`
	# aqui. A conta nao fecha neste ponto — quem fecha e dono da decisao de reabrir ou nao
	# a fila (`_finish_slice`), e um chunk editado no meio das fatias soma a segunda rodada.
	st.us += Time.get_ticks_usec() - tc
	if _edit_stamp.has(c.coord):
		_edit_build_us[c.coord] = int(_edit_build_us.get(c.coord, 0)) + st.us


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


## A celula p tem chao? O suporte e sempre a celula de baixo lida por get_block_xyz,
## que ja devolve STONE fora do mapa (parede invisivel e piso do mundo, :274-282) -- por
## isso a queda nunca precisa de tratamento de borda, e nunca de varredura: quem pergunta
## e o evento que escreveu no grid, nao um laco sobre as 1.048.576 celulas.
func is_supported(p: Vector3i) -> bool:
	return BlockDefs.is_solid(get_block_xyz(p.x, p.y - 1, p.z))


## Pouso de bloco com gravidade: escreve a celula so onde ela e livre ou liquida, que e
## o unico caso em que o grao desloca o que ja estava la sem destruir construcao. Rocha,
## madeira e bancada devolvem false e quem caiu vira outra decisao (empilhar ao lado),
## nunca reescrita silenciosa de obra alheia.
func place_falling_block(cell: Vector3i, b: int) -> bool:
	var cur: int = get_block(cell)
	if cur != BlockDefs.Block.AIR and BlockDefs.draw_of(cur) != BlockDefs.Draw.LIQUID:
		return false
	return set_block(cell, b)


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
	# A edicao caiu no chunk que esta em fatia agora? Entao os niveis ja andados dela nao a
	# viram, e o round que esta comitando vai devolver o chunk para o fim da fila
	# (`_finish_slice`). Sem esta linha o `not _dirty.has(c)` de baixo engoliria a segunda
	# passada e o mundo desenhado ficaria mais velho que o mundo que existe.
	if _slice != null and _slice.c == c:
		_slice.stale = true
	# So chunk ja malhado tem "custo de edicao": a primeira malharia do boot e o
	# lote inteiro, que ja tem coluna propria no `mesh_ms`. Varios edits no mesmo
	# chunk antes do mesh guardam o PRIMEIRO carimbo porque o que se quer medir e
	# o atraso ate o jogador ver o bloco trocado, nao a media das chamadas.
	if c.mesh_instance != null and not _edit_stamp.has(key):
		_edit_stamp[key] = Time.get_ticks_usec()
	if not _dirty.has(c):
		_dirty.append(c)


## Fecha a conta de um chunk carimbado com as DUAS grandezas que o dossie 24 §5.1 separa:
## o SPAN (`us`: usec entre a edicao que sujou o chunk e o mesh pronto, inclusive a espera
## pelo orcamento de frame) e o TRABALHO (`build_us`: os microsegundos que o mesher de fato
## gastou nele). Ate o braco B os dois eram o mesmo numero porque um chunk fechava num frame
## so; com fatia eles se separam por construcao — medido, span 95 351 -> 128 663 (+34,9 %)
## com trabalho 5 327 -> 5 078 (-4,7 %) — e uma regua que soma o span passaria a acusar o
## corte de trocar de victima pelo motivo errado, que e a classe do furo #44.
func _record_edit_cost(c: VoxelChunk) -> void:
	if not _edit_stamp.has(c.coord):
		return
	var us: int = int(Time.get_ticks_usec()) - int(_edit_stamp[c.coord])
	var build: int = int(_edit_build_us.get(c.coord, 0))
	_edit_stamp.erase(c.coord)
	_edit_build_us.erase(c.coord)
	_edit_us_total += us
	_edit_us_count += 1
	_edit_us_worst = maxi(_edit_us_worst, us)
	_edit_build_total += build
	_edit_build_worst = maxi(_edit_build_worst, build)


## Aggregate do custo de edicao local, no estilo das outras colunas de medida.
## `count` zero significa "ninguem editou ainda", nao "e barato"; `pending` sao os
## carimbos abertos cujo mesh ainda nao rodou -- sair com pending > 0 descarta
## latencia real e o readback precisa dizer isso com o numero na mesa.
## As duas medias sao grandezas diferentes e uma regua precisa dizer qual usa:
## `mean_us` e o span (edicao ate mesh pronto, com a espera do orcamento dentro)
## e `mean_build_us` e o trabalho (so os usec que o mesher gastou no chunk).
func edit_mesh_cost() -> Dictionary:
	return {
		"count": _edit_us_count,
		"worst_us": _edit_us_worst,
		"mean_us": (
			float(_edit_us_total) / float(_edit_us_count)
			if _edit_us_count > 0 else 0.0
		),
		"worst_build_us": _edit_build_worst,
		"mean_build_us": (
			float(_edit_build_total) / float(_edit_us_count)
			if _edit_us_count > 0 else 0.0
		),
		"pending": _edit_stamp.size(),
	}


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


## O plano de agua da coluna (dossie 23 §3.7): o `y` de mundo onde a superficie
## ondulada daquele ponto esta — topo do bloco de agua mais alto, menos o recuo de
## topo que a malharia usa — ou `-1,0` quando a coluna nao tem agua nenhuma. Desce
## do teto e para no primeiro voxel de agua, entao custa no maximo `CHUNK_SIZE_Y`
## leituras de uma coluna, e isso acontece por evento, nunca por frame.
func water_surface_y(x: int, z: int) -> float:
	var y := CHUNK_SIZE_Y - 1
	while y >= 0:
		if is_water_xyz(x, y, z):
			return float(y) + 1.0 - WATER_TOP_DROP
		y -= 1
	return -1.0


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


## Quantos blocos de agua contiguos existem embaixo deste (dossie 23 §3.3, canal G).
## Saturado em 4 porque o `COLOR` e um byte por canal e 4 ja leva o corpo ao azul
## fundo: alem dai nao ha mais cor a ganhar, so leituras a perder.
func _water_blocks_below(x: int, y: int, z: int) -> int:
	var n := 0
	while n < 4 and is_water_xyz(x, y - 1 - n, z):
		n += 1
	return n


## Varre o topo de cada coluna do chunk, **uma vez por rebuild** (dossie 23 §3.10b).
## Desce do teto e para no primeiro solido, entao a coluna coberta custa uma leitura e a
## coluna de ar custa `CHUNK_SIZE_Y` -- a mesma conta do `surface_height`
## (`voxel_world.gd:463-469`), feita uma vez por coluna em vez de uma por face.
##
## A leitura e no `data` do proprio chunk, nao por `get_block_xyz`: aqui sao ate 16 384
## perguntas por rebuild e o `get_block_xyz` gasta cada uma em quatro testes de limite que,
## dentro do chunk sendo malhado, nunca sao verdadeiros (x e z vem do laco, y de
## `CHUNK_SIZE_Y`). O indice e o MESMO caminho linear que `c.get_block` usa, e o chunk tem
## altura cheia (`CHUNK_SIZE_Y` camadas), entao a coluna inteira cabe nos 16 KB do proprio
## `data` -- nem o `ox` nem o `oz` globais entram na conta.
func _scan_col_tops(c: VoxelChunk) -> void:
	var n := CHUNK_SIZE_X * CHUNK_SIZE_Z
	if _ct_top.size() != n:
		_ct_top.resize(n)
	var d: PackedByteArray = c.data
	for z in CHUNK_SIZE_Z:
		for x in CHUNK_SIZE_X:
			# O indice comeca no **topo** da coluna, porque e de la que a conta desce:
			# o local e `(y * CHUNK_SIZE_Z + z) * CHUNK_SIZE_X + x`, entao o passo e um
			# `n` por camada e o primeiro byte lido e o de `y = CHUNK_SIZE_Y - 1`.
			var i: int = (CHUNK_SIZE_Y - 1) * n + z * CHUNK_SIZE_X + x
			var top := -1
			var y := CHUNK_SIZE_Y - 1
			while y >= 0:
				if BlockDefs.is_solid(d[i]):
					top = y
					break
				i -= n
				y -= 1
			_ct_top[z * CHUNK_SIZE_X + x] = top
	_exposure_cols += n
	_exposure_chunks += 1


## Os tres numeros do §3.10b: quantos chunks foram varridos, quantas colunas isso da e
## quantas faces essas colunas emitiram. E a linha que impede a varredura por face de
## voltar pela janela -- `col_lidas == chunks_lidos * 256` e aritmetica de uma leitura por
## coluna, e `faces_por_coluna` ao lado mostra o que o braco rejeitado custaria.
func exposure_diagnostics() -> Dictionary:
	return {
		"chunks_lidos": _exposure_chunks, "col_lidas": _exposure_cols,
		"faces_opacas": _exposure_faces, "fall": EXPOSURE_FALL,
	}


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
	ao: PackedFloat32Array, tint: float, top_drop: float,
	water_flags: Vector2 = Vector2.ZERO, topo: int = -1) -> void:
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
		if top_drop > 0.0:
			# Agua: aqui o COLOR nao e cor, e o atributo que o shader lee, e com isto
			# o furo #43 fecha (o canal era escrito com o tint da face e lido por
			# ninguem). R vale so no canto de topo de quem nao tem agua em cima, para
			# o quad de topo e as laterais do mesmo bloco se moverem pelo mesmo numero.
			cols.append(Color(
				water_flags.x if corner.y == 1 else 0.0,
				water_flags.y,
				0.0 if f == 4 or f == 5 else 1.0,
				1.0))
		else:
			# O alfa do grupo opaco era o canal escrito e lido por ninguem (o espelho do
			# furo #43, do outro lado da mesa): o `StandardMaterial3D` multiplica o RGB no
			# albedo e nao tem transparencia ligada, entao o que ele carregava nao chegava
			# a lugar nenhum. Com o material em shader (§3.10c) o canal passou a ter
			# comprador: a exposicao de cielo da coluna, que o `molhado × COLOR.a` do
			# fragment usa para escurecer o beiral e deixar o leito da ravina intocado.
			# `topo < 0` e o "sem coluna" do vidro, que nao tem comprador de molhamento
			# nesta fase (§3.10f) e continua com o alfa 1,0 de sempre.
			var a := 1.0
			if topo >= 0:
				a = clampf(1.0 - float(topo - int(py)) / float(EXPOSURE_FALL), 0.0, 1.0)
			cols.append(Color(bright, bright, bright, a))
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


## Cubo de bloco fora do mundo: as MESMAS tabelas de face, tile e tint da
## malharia, entao o item na mao e o bloco que esta na parede, so que menor e
## centrado na propria origem. 24 vertices, um par de triangulos CW por face.
static func block_cube_mesh(b: int, size: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for f in 6:
		var tile: int = BlockDefs.tile_for(b, FACE_TILE[f])
		var n: Vector3i = FACE_NORMALS[f]
		var corners: Array = FACE_CORNERS[f]
		var face_uvs: Array = FACE_UVS[f]
		var tu: float = float(tile % VoxelAtlas.GRID) / VoxelAtlas.GRID
		var tv: float = float(int(tile / VoxelAtlas.GRID)) / VoxelAtlas.GRID
		var span: float = 1.0 / VoxelAtlas.GRID
		var inset: float = 0.35 / float(VoxelAtlas.GRID * VoxelAtlas.TILE)
		var base: int = verts.size()
		for k in 4:
			var corner: Vector3i = corners[k]
			verts.append((Vector3(corner) - Vector3(0.5, 0.5, 0.5)) * size)
			norms.append(Vector3(n))
			uvs.append(Vector2(
				tu + inset + face_uvs[k].x * (span - 2.0 * inset),
				tv + inset + face_uvs[k].y * (span - 2.0 * inset)))
			var bright: float = clampf(float(FACE_TINT[f]), 0.05, 1.2)
			cols.append(Color(bright, bright, bright, 1.0))
		idx.append(base)
		idx.append(base + 2)
		idx.append(base + 1)
		idx.append(base)
		idx.append(base + 3)
		idx.append(base + 2)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
