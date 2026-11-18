extends Node
## Smoke test do slice: roda a sessao real (src/main.tscn) em headless e so conta
## como prova o que foi medido nesta execucao. Nada aqui injeta tecla no desktop:
## os unicos eventos sinteticos sao Input.action_press / Input.parse_input_event
## dentro deste proprio processo sem janela.
##
## Cada passo da lista espera um numero de frames de fisica e depois emite PASS/FAIL
## com o numero medido. Qualquer FAIL faz o processo sair com codigo 1.

const SEED := 20261116
const DT_SIM := 0.05
const ARM_STEPS := 40
const BELIEF := "danger_from_actor_1"
const SLOT := "alpha"
const ARM_NONE := 0
const ARM_WOUND := 1
const ARM_REMEMBER := 2

var main: Node3D = null
var _steps: Array = []
var _step := 0
var _frame := 0
var _until := 0
var _checks := 0
var _fails := 0
var _t0 := 0
var _scratch: VoxelWorld = null
var _scratch_root: Node3D = null
var _spawn := Vector3.ZERO
var _heights := {}
var _spawn_pos: Array = []
var _corpse_n := 0
var _place_voxel := Vector3i.ZERO
var _place_sel := 0
var _place0 := 0
var _lava_target := Vector3i.ZERO
var _click_pending := false
var _click_state := false
var _armed := false
var _tick_player := false
var _click_frame := -1
var _click_detail := ""
var _swim_wolf: Wolf = null
var _swim_start := Vector3.ZERO
var _swim_bed_y := 0.0
var _swim_seen := false
var _swim_min_y := 999.0
var _swim_max_leg := 0.0
var _swim_seek := false
var _lake := Vector3i.ZERO
var _oracle_probe: MindOracle = null


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	_spawn = main.spawn_point()
	for x in [12, 44, 100, 116]:
		for z in [12, 44, 100, 116]:
			_heights["%d,%d" % [x, z]] = main.world.surface_height(x, z)
	_steps = [
		["boot do mundo", 2, _check_boot],
		["relogio real", 150, _check_live],
		["malha e face-culling", 0, _check_meshing],
		["edicoes no mundo", 0, _check_edits],
		["sistema de coordenadas", 0, _check_coords],
		["campo de eter", 0, _check_aether],
		["relogio de simulacao", 0, _check_clock],
		["minerar e colocar", 0, _check_mechanics],
		["colocar com clique", 20, _check_place],
		["soltar o botao", 12, _check_click_release],
		["guarda de colocacao", 20, _check_place_guard],
		["tecla 3 no hotbar", 3, _check_hotbar_key],
		["construir enquanto lava", 0, _check_build_setup],
		["lavra + clique direito", 20, _check_build_while_mining],
		["memoria muda comportamento", 0, _check_memory],
		["lobo na agua", 0, _check_swim_setup],
		["lobo nada e busca margem", 280, _check_swim_assert],
		["golpe no lobo: dano e empurrada", 0, _check_attack],
		["rolamento e invencibilidade", 0, _check_roll],
		["vigor: dreno, recupero e trava", 0, _check_energy],
		["planar e queda", 0, _check_glide_fall],
		["respiracao e afogamento", 0, _check_breath],
		["regeneracao fora de combate", 0, _check_regen],
		["oraculo: sonda em porta fechada", 0, _check_oracle_arm],
		["oraculo degrada sem servidor", 90, _check_oracle],
		["hud, morte e renascer", 0, _check_hud],
		["salvar e carregar", 0, _check_save],
		["cadaver no chao", 0, _check_corpse],
		["recolhimento e reposicao", 460, _check_reap],
	]
	_until = int(_steps[0][1])
	print("== aetherfall smoke test  seed %d ==" % SEED)


func _physics_process(_delta: float) -> void:
	_frame += 1
	# Mundo congelado: sem process_mode ligado quem da o passo no jogador e o teste,
	# senao a borda do clique cairia num frame em que ninguem le o input.
	if _tick_player:
		main.player.update_local(1.0 / 60.0)
	if _swim_wolf != null and is_instance_valid(_swim_wolf) and _swim_wolf.alive:
		if _swim_wolf.body.in_water:
			_swim_seen = true
			_swim_min_y = minf(_swim_min_y, _swim_wolf.body.feet_pos.y)
			for leg in _swim_wolf._legs:
				_swim_max_leg = maxf(_swim_max_leg, absf((leg as Node3D).rotation.x))
		if _swim_wolf._swim_time > Wolf.SHORE_AFTER \
				and _swim_wolf._dry_ground(_swim_wolf._move_target):
			_swim_seek = true
	if _armed and Input.is_action_just_pressed("place_block"):
		var p: Player = main.player
		_armed = false
		# A borda chega num quadro em que o jogador NAO foi tickado de proposito: era
		# assim que o clique se perdia (medido na janela real: 163 quadros/s contra
		# 59,8 ticks -> 63,3% dos quadros sem tick). Do proximo frame em diante o
		# passo volta e o buffer de 0,22 s e obrigado a produzir o bloco.
		_tick_player = true
		_click_frame = _frame
		_click_detail = "frame=%d  alvo=%s  place=%s  no_corpo=%s  cooldown=%.3f" % [
			_frame, p.target_voxel, p.place_voxel,
			p.body.aabb().intersects(AABB(Vector3(p.place_voxel), Vector3.ONE)), p._place_cd]
	if _step >= _steps.size() or _frame < _until:
		return
	var s: Array = _steps[_step]
	print("\n--- %s ---" % s[0])
	(s[2] as Callable).call()
	_step += 1
	if _step < _steps.size():
		_until = _frame + int(_steps[_step][1])
	else:
		_finish()


func _process(_delta: float) -> void:
	## O clique sintetrico sai daqui, no tempo ocioso, como no jogo real (o evento
	## nasce antes da fisica). Medido nesta maquina, headless, o engine so drena a
	## fila de 6 a 7 iteracoes depois de `Input.parse_input_event()` -- por isso o passo
	## que arma o clique congela o mundo e segue girando o jogador ate a borda
	## aparecer, em vez de confiar num numero fixo de frames.
	if _click_pending:
		_click_pending = false
		_click(_click_state)


func _check(label: String, ok: bool, detail := "") -> void:
	_checks += 1
	if not ok:
		_fails += 1
	var tag := "PASS" if ok else "FAIL"
	print("  [%s] %-38s %s" % [tag, label, detail])


func _finish() -> void:
	var secs := float(Time.get_ticks_msec() - _t0) / 1000.0
	print("\n== %d checagens  %d falhas  %.1f s de teste ==" % [_checks, _fails, secs])
	get_tree().quit(1 if _fails > 0 else 0)


# --------------------------------------------------------------------- mundo

func _check_boot() -> void:
	var d: Dictionary = main.diagnostics()
	_check("64 chunks gerados", int(d["chunks"]) == 64, "chunks=%d" % d["chunks"])
	_check("64 chunks malhados", int(d["meshes"]) == 64, "meshes=%d" % d["meshes"])
	_check("mundo com triangulos", int(d["triangles"]) > 0, "triangulos=%d" % d["triangles"])
	_check("5 lobos na matilha", int(d["wolves"]) == 5, "lobos=%d" % d["wolves"])
	_check("spawn em terra firme", _spawn.y > float(VoxelConfig.SEA_LEVEL), "y=%d" % int(_spawn.y))
	_check("jogador apoiado no chao", bool(d["on_ground"]), "feet=%s" % d["feet"])
	print("       geracao %.1f ms   malharia %.1f ms" % [d["gen_ms"], d["mesh_ms"]])
	for w in main.wolves:
		_spawn_pos.append(w.global_position)


func _check_live() -> void:
	var d: Dictionary = main.diagnostics()
	var tick := int(d["tick"])
	_check("tick de simulacao avanca", tick > 0, "tick=%d em %.2f s de logica" % [tick, float(main.elapsed)])
	_check("ritmo de 20 Hz sustentado", absf(float(tick) - float(main.elapsed) * 20.0) < 1.0,
		"tick=%d  esperado=%d" % [tick, int(float(main.elapsed) * 20.0)])
	_check("nenhum tick perdido", int(d["dropped_ticks"]) == 0,
		"perdidos=%d  pior passo=%.2f ms" % [d["dropped_ticks"], d["worst_sim_ms"]])
	_check("jogador segue no chao", bool(d["on_ground"]), "feet=%s" % d["feet"])
	var moved := 0
	for i in main.wolves.size():
		if (main.wolves[i] as Node3D).global_position.distance_to(_spawn_pos[i]) > 0.5:
			moved += 1
	_check("lobos caminham sozinhos", moved >= 2, "%d/%d se moveram" % [moved, main.wolves.size()])
	var intents := ""
	var legal := true
	for w in main.wolves:
		intents += "%s " % w.intent
		if not (w.intent in ["patrol", "hunt", "investigate", "flee"]):
			legal = false
	_check("intento sempre valido", legal, intents.strip_edges())


# --------------------------------------------------------------------- malha

func _check_meshing() -> void:
	_scratch_root = Node3D.new()
	add_child(_scratch_root)
	_scratch = VoxelWorld.new()
	_scratch.setup_world(_scratch_root)
	var t := Time.get_ticks_usec()
	_scratch.generate(SEED)
	_scratch.generate_meshes_all()
	var ms := float(Time.get_ticks_usec() - t) / 1000.0
	var tri_a := _scratch.triangle_count()
	var tri_b := int(main.diagnostics()["triangles"])
	var same := true
	for k in _heights:
		var parts: PackedStringArray = String(k).split(",")
		if _scratch.surface_height(int(parts[0]), int(parts[1])) != int(_heights[k]):
			same = false
	_check("geracao deterministica (16 colunas)", same, "ms=%.1f" % ms)
	_check("malha identica entre mundos", tri_a == tri_b, "espelho=%d  sessao=%d" % [tri_a, tri_b])

	var cx := 20
	var cz := 20
	var base := mini(_scratch.surface_height(cx, cz) + 12, VoxelConfig.CHUNK_SIZE_Y - 5)
	var air := true
	for dy in 3:
		for dz in 3:
			for dx in 3:
				if _scratch.get_block(Vector3i(cx + dx, base + dy, cz + dz)) != BlockDefs.Block.AIR:
					air = false
	_check("regiao do cubo estava em ar", air, "voxel=(%d,%d,%d)" % [cx, base, cz])
	var before := _scratch.triangle_count()
	for dy in 3:
		for dz in 3:
			for dx in 3:
				_scratch.set_block(Vector3i(cx + dx, base + dy, cz + dz), BlockDefs.Block.STONE, false)
	_scratch.generate_meshes_all()
	var delta := _scratch.triangle_count() - before
	_check("face-culling exato (cubo 3x3x3)", delta == 108,
		"delta=%d  esperado=108  sem culling=324" % delta)

	var c: VoxelChunk = _scratch.chunks[Vector2i(3, 3)]
	var solid := 0
	for y in VoxelConfig.CHUNK_SIZE_Y:
		for z in VoxelConfig.CHUNK_SIZE_Z:
			for x in VoxelConfig.CHUNK_SIZE_X:
				if BlockDefs.is_solid(c.get_block(x, y, z)):
					solid += 1
	var naive := solid * 12
	var real := _chunk_triangles(c)
	_check("culling dentro de um chunk", real > 0 and real < naive,
		"voxel solido=%d  malha=%d  sem culling=%d  (%.1f%%)" % [solid, real, naive, 100.0 * real / float(naive)])
	# Winding: o Godot (Vulkan inverte o Y do framebuffer) trata como frontal o
	# triangulo horario visto de fora, entao a normal geometrica do indice tem de
	# apontar CONTRA a normal do vertice. Com o indice em (0,1,2) todo topo era
	# descartado e o terreno aparecia transparente.
	var wn := _winding_bad(_scratch)
	_check("winding = face frontal do Godot", wn == 0, "triangulos contra=%d" % wn)
	_scratch_root.queue_free()
	_scratch = null


## Triangulos cuja normal geometrica (ordem dos indices) concorda com a normal do
# vertice: winding invertido, ou seja, a face e descartada como traseira.
func _winding_bad(w: VoxelWorld) -> int:
	var bad := 0
	for key in w.chunks:
		var c: VoxelChunk = w.chunks[key]
		if c.mesh_instance == null or c.mesh_instance.mesh == null:
			continue
		for s in c.mesh_instance.mesh.get_surface_count():
			var arr: Array = c.mesh_instance.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			for t in int(idx.size() / 3):
				var a := v[idx[t * 3]]
				var geo := (v[idx[t * 3 + 1]] - a).cross(v[idx[t * 3 + 2]] - a)
				if geo.length_squared() < 1e-8:
					continue
				if geo.normalized().dot(nr[idx[t * 3]]) > 0.0:
					bad += 1
	return bad


## Caixas do avatar: conta a arvore de nodes, sem depender de nomes internos.
func _mesh_count(n: Node) -> int:
	var total := 0
	if n is MeshInstance3D:
		total += 1
	for c in n.get_children():
		total += _mesh_count(c)
	return total


## Malhas efetivamente em cena: desconta as que estao sob um no oculto.
func _mesh_count_visible(n: Node) -> int:
	var total := 0
	if n is MeshInstance3D and n.is_visible_in_tree():
		total += 1
	for c in n.get_children():
		total += _mesh_count_visible(c)
	return total


## Extensao vertical global das malhas: [base, topo] da silhueta em coordenadas
## de mundo. Pega o torso montado no lugar errado, que a contagem de caixas nao
## distingue.
func _mesh_span(n: Node) -> Array:
	var lo := 999.0
	var hi := -999.0
	for b in n.find_children("*", "MeshInstance3D", true, false):
		var mi := b as MeshInstance3D
		var ab: AABB = mi.global_transform * mi.mesh.get_aabb()
		lo = minf(lo, ab.position.y)
		hi = maxf(hi, ab.position.y + ab.size.y)
	return [lo, hi]


func _chunk_triangles(c: VoxelChunk) -> int:
	var n := 0
	if c.mesh_instance == null or c.mesh_instance.mesh == null:
		return 0
	for s in c.mesh_instance.mesh.get_surface_count():
		var idx: PackedInt32Array = c.mesh_instance.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		n += int(idx.size() / 3)
	return n


# --------------------------------------------------------------------- edicoes

func _check_edits() -> void:
	var w: VoxelWorld = main.world
	var p := Vector3i(6, w.surface_height(6, 6) + 6, 6)
	_check("alvo dentro dos limites", VoxelConfig.in_world_bounds(p), "voxel=%s" % p)
	_check("fora dos limites recusado", not w.set_block(Vector3i(-4, 10, -4), BlockDefs.Block.STONE))
	_check("parede invisivel solida",
		w.get_block_xyz(-1, 10, 10) == BlockDefs.Block.STONE, "bloco=%d" % w.get_block_xyz(-1, 10, 10))
	_check("acima do topo e ar",
		w.get_block_xyz(10, VoxelConfig.CHUNK_SIZE_Y, 10) == BlockDefs.Block.AIR)
	var n0 := w.edits.size()
	_check("set_block grava edicao", w.set_block(p, BlockDefs.Block.STONE), "voxel=%s" % p)
	_check("diario de edicoes cresceu", w.edits.size() == n0 + 1, "%d -> %d" % [n0, w.edits.size()])
	var queued := w.pending_meshes()
	_check("chunk sujo entrou na fila", queued >= 1, "fila=%d" % queued)
	w.process(64)
	_check("rebuild sob demanda", w.get_block(p) == BlockDefs.Block.STONE,
		"fila apos process=%d" % w.pending_meshes())
	_check("leitura igual ao escrito", w.get_block(p) == BlockDefs.Block.STONE)
	_check("repetir o mesmo valor e no-op", not w.set_block(p, BlockDefs.Block.STONE))
	_check("no-op nao polui o diario", w.edits.size() == n0 + 1, "%d" % w.edits.size())


# ------------------------------------------------------------- coordenadas

## O vocabulario canônico (Coords): piso de negativos, bordas de chunk,
## ida e volta da chave de save e a grade do Eter saem todos da mesma fonte.
func _check_coords() -> void:
	var tb := Coords.to_block(Vector3(-0.25, 3.75, 127.9))
	_check("to_block e piso com negativo", tb == Vector3i(-1, 3, 127), "to_block=%s" % tb)
	var edge_a := Vector3i(15, 31, 16)
	var edge_b := Vector3i(16, 31, 15)
	_check("chunk na borda 15/16",
		Coords.chunk_of(edge_a) == Vector2i(0, 1) and Coords.chunk_of(edge_b) == Vector2i(1, 0),
		"chunk(15,y,z16)=%s  chunk(16,y,z15)=%s" % [Coords.chunk_of(edge_a), Coords.chunk_of(edge_b)])
	var round_ok := true
	for b in [edge_a, edge_b, Vector3i.ZERO, Vector3i(127, 63, 127)]:
		var key := Coords.chunk_of(b)
		if Coords.chunk_origin(key) + Coords.local_of(b, key) != b:
			round_ok = false
	_check("origem + local devolve o bloco", round_ok, "bordas, origem e canto oposto")
	var k := Vector3i(-3, 27, 129)
	_check("chave de save ida e volta", Coords.parse_block_key(Coords.block_key(k)) == k,
		"chave=%s" % Coords.block_key(k))
	var c1 := Coords.cell_of_voxel(Vector3i(17, 3, 5))
	var c2 := Coords.cell_of_voxel(Vector3i(-1, 0, 0))
	_check("celula do eter e piso por 4", c1 == Vector3i(4, 0, 1) and c2 == Vector3i(-1, 0, 0),
		"cell(17,3,5)=%s  cell(-1,0,0)=%s" % [c1, c2])
	var co := Coords.cell_origin(Vector3i(4, 0, 1))
	_check("origem da celula devolve o canto", co == Vector3i(16, 0, 4), "cell_origin=%s" % co)


# --------------------------------------------------------------------- eter

func _check_aether() -> void:
	var a: AetherField = main.aether
	var pos := _spawn + Vector3(0.0, 6.0, 0.0)
	var cell := a.cell_of_world(pos)
	var e0 := a.total_energy()
	_check("celula comecou limpa", a.sample_cell(cell, AetherField.Channel.FEAR) < 0.01,
		"valor=%.4f" % a.sample_cell(cell, AetherField.Channel.FEAR))
	a.imprint(pos, AetherField.Channel.FEAR, 2.5)
	var peak := a.sample(pos, AetherField.Channel.FEAR)
	_check("imprint lido de volta", peak > 1.0, "amostra=%.3f" % peak)
	var e1 := a.total_energy()
	_check("energia total subiu", e1 > e0, "%.3f -> %.3f" % [e0, e1])
	var nb := cell + Vector3i(1, 0, 0)
	var v0 := a.sample_cell(nb, AetherField.Channel.FEAR)
	for i in 8:
		a.diffuse_and_decay(0.25)
	var v1 := a.sample_cell(nb, AetherField.Channel.FEAR)
	_check("difusao passou para a vizinha", v1 > v0, "%.4f -> %.4f em 2 s" % [v0, v1])
	var e2 := a.total_energy()
	_check("meia-vida reduziu a energia", e2 < e1, "%.3f -> %.3f" % [e1, e2])
	a.imprint(pos, AetherField.Channel.FEAR, 900.0)
	_check("teto de valor aplicado",
		is_equal_approx(a.sample(pos, AetherField.Channel.FEAR), AetherField.MAX_VALUE),
		"teto=%.1f" % AetherField.MAX_VALUE)
	var totals: Array = a.channel_totals()
	_check("ledger com 3 canais", totals.size() == 3,
		"work=%.2f blood=%.2f fear=%.2f" % [totals[0], totals[1], totals[2]])


# --------------------------------------------------------------------- relogio

func _check_clock() -> void:
	var c := SimClock.new()
	var total := 0
	for i in 600:
		total += c.advance(1.0 / 60.0)
	_check("60 Hz vira 20 Hz", absf(float(total) - 200.0) <= 1.0,
		"%d passos em 10 s de logica" % total)
	var s := c.advance(1.0)
	_check("cap de 5 passos por frame", s == 5 and c.dropped_ticks == 1,
		"passos=%d  perdidos=%d" % [s, c.dropped_ticks])
	_check("duracao do passo", is_equal_approx(c.step_duration(), 0.05), "step=%.3f" % c.step_duration())
	c.begin_step()
	c.end_step()
	_check("cronometro do passo preenche o pico", c.worst_step_ms >= 0.0,
		"ultimo=%.3f ms  pior=%.3f ms" % [c.last_step_ms, c.worst_step_ms])


# --------------------------------------------------------------------- mecanicas

## Apontar exige dois updates: _update_target le a base da camera que o update
## anterior escreveu, e _update_camera roda no fim do mesmo call.
func _aim(p: Player, pitch: float) -> void:
	p.pitch = pitch
	p.update_local(1.0 / 60.0)
	p.update_local(1.0 / 60.0)


func _check_mechanics() -> void:
	var p: Player = main.player
	var w: VoxelWorld = main.world
	# Congela o mundo: um lobo que atravesse a mira entre o minerar e o colocar
	# trocaria o alvo, e o passo passaria a medir a IA em vez da mecanica. Pause,
	# e nao process_mode DISABLED em main: congelado assim o node nao recebe input
	# nenhum, e e no `_input` do jogador que a borda do clique agora nasce.
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	p.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	get_tree().paused = true
	p.feet_to_spawn(_spawn)
	p.yaw = 0.0
	_aim(p, -0.9)
	var dirv: Vector3 = p.camera.global_transform.basis.z * -1.0
	var probe := w.ray_voxel(p.eye_position(), dirv, Player.REACH)
	print("       mira: olho=%s  dir=(%.3f, %.3f, %.3f)  dda=%.2f m em %s"
		% [p.eye_position(), dirv.x, dirv.y, dirv.z, probe.distance, probe.voxel])
	_check("mira encontrou um bloco", p.target_valid,
		"voxel=%s  dureza=%.2f  name=%s" % [p.target_voxel, p.target_hardness, p.look_target_name])
	if p.target_valid:
		var tgt := p.target_voxel
		var h := p.target_hardness
		var mined0 := int(main.stats["mined"])
		Input.action_press("break_block")
		var n := 0
		while int(main.stats["mined"]) == mined0 and n < 400:
			p.update_local(1.0 / 60.0)
			n += 1
		Input.action_release("break_block")
		_check("segurar break minerou", int(main.stats["mined"]) == mined0 + 1,
			"%d atualizacoes" % n)
		_check("tempo de mineracao == dureza", absf(float(n) / 60.0 - h) < 0.034,
			"dureza=%.3f  medido=%.3f" % [h, float(n) / 60.0])
		_check("voxel virou ar", w.get_block(tgt) == BlockDefs.Block.AIR, "voxel=%s" % tgt)

	# Corpo do jogador: o rig e o unico corpo no quadro nas duas vistas. Em 1a
	# pessoa cabeca e tronco saem (a camera mora dentro do cranio; o tronco
	# virava slab na frente da camera) e bracos/pernas/cinto/mochila ficam; na
	# 3a tudo em cena, nos pes e girando com o yaw.
	p.yaw = 0.62
	p.third_person = true
	p.update_local(1.0 / 60.0)
	var head_tp := p.avatar.head_shown()
	var drift := p.avatar.global_position.distance_to(p.body.feet_pos)
	var facing := rad_to_deg(p.avatar.rotation.y)
	var parts := _mesh_count(p.avatar)
	p.third_person = false
	p.update_local(1.0 / 60.0)
	var head_fp := p.avatar.head_shown()
	var limbas_fp := _mesh_count_visible(p.avatar)
	_check("corpo do jogador tem malhas", parts >= 20, "caixas=%d" % parts)
	var span := _mesh_span(p.avatar)
	var top: float = span[1] - p.body.feet_pos.y
	var base: float = span[0] - p.body.feet_pos.y
	_check("silhueta fecha em ~1,8 m", top > 1.7 and top < 1.9, "altura=%.2f" % top)
	_check("nenhuma malha abaixo dos pes", base > -0.15, "base=%.2f" % base)
	_check("avatar cola nos pes", drift < 0.002, "desvio=%.5f" % drift)
	_check("avatar gira com o yaw", absf(facing - rad_to_deg(0.62)) < 0.01,
		"corpo=%.2fdeg  esperado=%.2fdeg" % [facing, rad_to_deg(0.62)])
	_check("corpo inteiro em cena na 3a pessoa", head_tp and p.avatar.visible)
	_check("cabeca sai de cena na 1a pessoa", not head_fp)
	_check("bracos e pernas em cena na 1a pessoa", limbas_fp >= 10,
		"malhas visiveis=%d" % limbas_fp)

	# Colocar exige o pipeline real de input: a borda do clique nasce em `_input` e
	# vira bloco no tick seguinte. Minerar pode continuar sintetico porque le o
	# nivel da acao, nao a borda. O mundo segue congelado e o clique arma a maquina
	# de espera: a assercao vive em _check_place.
	_aim(p, -0.9)
	_place_voxel = p.place_voxel
	_place_sel = p.selected_block()
	_place0 = int(main.stats["placed"])
	print("       alvo do place: valid=%s  voxel=%s  place=%s  pos=%s  bloco=%d"
		% [p.target_valid, p.target_voxel, _place_voxel, p.body.feet_pos, _place_sel])
	_arm_click(true)

	_check("hotbar comeca no capim", p.hotbar[0] == BlockDefs.Block.GRASS,
		"slots=%d" % p.hotbar.size())

	var ray := w.ray_voxel(p.eye_position(), Vector3(0.0, -1.0, 0.0), 8.0)
	_check("raycast DDA acerta o chao", ray.valid and ray.distance < 3.0,
		"dist=%.2f  voxel=%s" % [ray.distance, ray.voxel])
	var diag := w.ray_voxel(p.eye_position(), Vector3(0.0, -0.6, -0.8), Player.REACH)
	_check("raycast DDA em raio inclinado", diag.valid,
		"dist=%.2f  voxel=%s" % [diag.distance, diag.voxel])
	_check("linha de visada curta e limpa",
		w.line_of_sight(p.eye_position(), p.eye_position() + Vector3(0.0, 3.0, 0.0)))


## Clique direito de verdade: um InputEventMouseButton novo por chamada (o engine
## recusa o mesmo objeto duas vezes no mesmo frame). Vai por
## `Input.parse_input_event()`, que e o caminho que atualiza o estado das acoes do
## InputMap; `Viewport.push_input()` entrega o evento aos callbacks dos nodes mas
## nao acende a acao, e `_apply_actions` le a acao.
func _click(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
	ev.global_position = Vector2(640.0, 360.0)
	ev.position = ev.global_position
	Input.parse_input_event(ev)


## Enfileira um clique e congela o passo do jogador ate a borda aparecer no input
## do engine: e o quadro em que o jogo real nao tinha tick de fisica. A assercao
## vive em _check_place. `soltar` nao arma: sem borda para esperar, basta o frame.
func _arm_click(pressed: bool) -> void:
	_click_frame = -1
	_click_detail = ""
	_armed = pressed
	_tick_player = false
	_click_pending = true
	_click_state = pressed


func _release_click() -> void:
	_armed = false
	_tick_player = false
	_click_pending = true
	_click_state = false


func _check_place() -> void:
	var w: VoxelWorld = main.world
	_check("clique do mouse virou acao no jogador", _click_frame > 0,
		_click_detail if _click_frame > 0 else "a borda nunca chegou (frame %d)" % _frame)
	_check("place_block colocou", _click_frame > 0 and int(main.stats["placed"]) == _place0 + 1,
		"voxel=%s  bloco=%d  achado=%d  colocados=%d->%d"
		% [_place_voxel, _place_sel, w.get_block(_place_voxel), _place0, int(main.stats["placed"])])
	_check("bloco certo no voxel certo", w.get_block(_place_voxel) == _place_sel,
		"esperado=%d  achado=%d" % [_place_sel, w.get_block(_place_voxel)])
	_release_click()


## Antes de apontar para os pes o botao precisa ser lido como solto: se a acao
## continuasse presa, o proximo clique nao produziria borda nenhuma. Depois
## disto o mesmo clique cai numa celula que intersecta a AABB do corpo.
func _check_click_release() -> void:
	var p: Player = main.player
	_check("soltar o botao limpou a acao", not Input.is_action_pressed("place_block"),
		"frame=%d  presa=%s" % [_frame, Input.is_action_pressed("place_block")])
	# Gira o jogador ate o cooldown de colocacao (0,16 s) expirar: sem isto a recusa
	# da guarda poderia ser atribuida ao cooldown e nao a guarda em si.
	var n := 0
	while p._place_cd > 0.0 and n < 60:
		p.update_local(1.0 / 60.0)
		n += 1
	_aim(p, -1.4)
	_place_voxel = p.place_voxel
	_place0 = int(main.stats["placed"])
	print("       mira nos pes: place=%s  pos=%s  cooldown=%.3f  giros=%d"
		% [_place_voxel, p.body.feet_pos, p._place_cd, n])
	_arm_click(true)


func _check_place_guard() -> void:
	var p: Player = main.player
	var w: VoxelWorld = main.world
	var over_body := p.body.aabb().intersects(AABB(Vector3(_place_voxel), Vector3.ONE))
	_check("clique da guarda chegou ao jogador", _click_frame > 0,
		_click_detail if _click_frame > 0 else "a borda nunca chegou (frame %d)" % _frame)
	_check("colocar no proprio corpo recusado",
		_click_frame > 0 and over_body and int(main.stats["placed"]) == _place0
			and w.get_block(_place_voxel) == BlockDefs.Block.AIR,
		"voxel=%s  la em cima=%d  dentro do corpo=%s  colocados=%d"
		% [_place_voxel, w.get_block(_place_voxel), over_body, int(main.stats["placed"])])
	_release_click()
	get_tree().paused = false
	self.process_mode = Node.PROCESS_MODE_INHERIT
	p.process_mode = Node.PROCESS_MODE_INHERIT
	# Tecla 3 pela fila do viewport: entrega o evento ao `_unhandled_input` do
	# jogador. A assercao vive em _check_hotbar_key, tres frames adiante.
	var press := InputEventKey.new()
	press.physical_keycode = KEY_3
	press.pressed = true
	get_viewport().push_input(press)


func _check_hotbar_key() -> void:
	var p: Player = main.player
	var read := Input.is_action_pressed("hotbar_3")
	_check("tecla 3 troca o slot", p.hotbar_index == 2,
		"slot=%d  acao lida=%s  bloco=%d" % [p.hotbar_index, read, p.selected_block()])
	var release := InputEventKey.new()
	release.physical_keycode = KEY_3
	release.pressed = false
	get_viewport().push_input(release)


## Construir no meio de uma lavra. O botao esquerdo preso e a dureza da pedra
## (0,95 s) deixam uma janela larga; o clique direito cai nela e tem que virar
## bloco mesmo assim. Prepara o alvo e arma o clique; a assercao vive 20 frames
## adiante, em _check_build_while_mining.
func _check_build_setup() -> void:
	var p: Player = main.player
	var w: VoxelWorld = main.world
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	p.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	get_tree().paused = true
	p.yaw = 0.0
	_aim(p, -0.9)
	if not p.target_valid:
		_check("mira para lavar um bloco", false, "sem alvo em reach")
		return
	_lava_target = p.target_voxel
	w.set_block(_lava_target, BlockDefs.Block.STONE)
	_aim(p, -0.9)
	Input.action_press("break_block")
	for i in 20:
		p.update_local(1.0 / 60.0)
	_place_voxel = p.place_voxel
	_place_sel = p.selected_block()
	_place0 = int(main.stats["placed"])
	print("       lavar=%s  place=%s  dureza=%.2f  progresso=%.2f  bloco=%d  colocados=%d"
		% [_lava_target, _place_voxel, p.target_hardness, p.mining_progress, _place_sel, _place0])
	_arm_click(true)


func _check_build_while_mining() -> void:
	var p: Player = main.player
	var w: VoxelWorld = main.world
	Input.action_release("break_block")
	_release_click()
	get_tree().paused = false
	self.process_mode = Node.PROCESS_MODE_INHERIT
	p.process_mode = Node.PROCESS_MODE_INHERIT
	_check("clique direito chegou durante a lavra", _click_frame > 0,
		_click_detail if _click_frame > 0 else "a borda nunca chegou (frame %d)" % _frame)
	_check("construiu com o ESQ segurado",
		_click_frame > 0 and int(main.stats["placed"]) == _place0 + 1
			and w.get_block(_place_voxel) == _place_sel,
		"voxel=%s  bloco=%d  achado=%d  colocados=%d->%d"
		% [_place_voxel, _place_sel, w.get_block(_place_voxel), _place0, int(main.stats["placed"])])
	_check("a lavra ainda nao tinha comido o alvo",
		w.get_block(_lava_target) == BlockDefs.Block.STONE,
		"voxel=%s  achado=%d  progresso=%.2f" % [_lava_target, w.get_block(_lava_target), p.mining_progress])


# --------------------------------------------------------------------- memoria

func _check_memory() -> void:
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var w: Wolf = main.wolves[3]
	var p: Player = main.player
	p.feet_to_spawn(_spawn)
	var spot := _experiment_spot(w, p)
	_check("achou posicao com linha de visada", spot != Vector3.INF, "lobo=%d" % w.identity)
	if spot == Vector3.INF:
		main.process_mode = Node.PROCESS_MODE_INHERIT
		return
	var half := Wolf.MAX_HP * 0.5
	var a := _run_arm(w, spot, half, 5000.0, ARM_NONE)
	var b := _run_arm(w, spot, half, 15000.0, ARM_WOUND)
	var c := _run_arm(w, spot, half, 25000.0, ARM_NONE)
	var d := _run_arm(w, spot, half, 35000.0, ARM_REMEMBER)

	_check("A sem memoria: caca non vetada", not a["hunt_vetoed"] and a["intent"] == "hunt",
		"intencao=%s  caca=%.3f" % [a["intent"], a["hunt_score"]])
	_check("B com memoria: caca vetada", b["hunt_vetoed"],
		"intencao=%s  caca=%.3f" % [b["intent"], b["hunt_score"]])
	_check("B nao persegue o agressor", b["intent"] != "hunt", "intencao=%s" % b["intent"])
	_check("C ablar a crencia reabre a caca", not c["hunt_vetoed"] and c["intent"] == "hunt",
		"intencao=%s  caca=%.3f" % [c["intent"], c["hunt_score"]])
	_check("D regravar a crencia veto de novo", d["hunt_vetoed"] and d["intent"] != "hunt",
		"intencao=%s  caca=%.3f" % [d["intent"], d["hunt_score"]])
	_check("rumo do lobo seguiu a memoria",
		a["chasing"] and not b["chasing"] and c["chasing"] and not d["chasing"],
		"A=%s B=%s C=%s D=%s" % [a["chasing"], b["chasing"], c["chasing"], d["chasing"]])
	_check("confianca da crencia acima da soleira",
		w.mind.belief(BELIEF) >= 0.35, "confianca=%.2f  episodios=%d" % [
			w.mind.belief(BELIEF), w.mind.episodic.size()])
	_check("desconfianca do jogador registrada", w.mind.trust(Wolf.ACTOR_PLAYER) < 0.0,
		"confianca=%.2f  cautela=%.2f" % [w.mind.trust(Wolf.ACTOR_PLAYER), w.mind.temperament("caution")])
	print("       quatro bracos com hp=%.1f dist=%.1f: so a memoria mudou" % [w.hp, a["dist"]])

	w.hp = Wolf.MAX_HP
	w.mind.beliefs.erase(BELIEF)
	main.process_mode = Node.PROCESS_MODE_INHERIT


# --------------------------------------------------------------------- agua

## Acha a agua mais funda da seed, derruba um lobo nela e prova a patrulha seca
## por sorteio direto. O amostrador vive no _physics_process do harness.
func _check_swim_setup() -> void:
	var world: VoxelWorld = main.world
	var best := Vector3i.ZERO
	var best_score := -1
	for x in range(4, VoxelConfig.world_size_x() - 4, 2):
		for z in range(4, VoxelConfig.world_size_z() - 4, 2):
			var top := world.surface_height(x, z)
			if not world.is_water_xyz(x, top + 1, z):
				continue
			var depth := VoxelConfig.SEA_LEVEL - top
			var viz := 0
			for off in [Vector3i(2, 0, 0), Vector3i(-2, 0, 0), Vector3i(0, 0, 2), Vector3i(0, 0, -2)]:
				var t2 := world.surface_height(x + off.x, z + off.z)
				if world.is_water_xyz(x + off.x, t2 + 1, z + off.z):
					viz += 1
			var score := depth * 10 + viz
			if score > best_score:
				best_score = score
				best = Vector3i(x, top, z)
	var depth := VoxelConfig.SEA_LEVEL - best.y
	_lake = best
	_check("lago fundo no mapa", best_score > 0 and depth >= 2,
		"profundidade=%d  vizinhos=%d  em (%d,%d)" % [depth, (best_score % 10) if best_score > 0 else 0, best.x, best.z])
	if best_score <= 0 or depth < 2:
		_swim_wolf = null
		return
	_swim_bed_y = float(best.y)
	_swim_wolf = main.wolves[1]
	_swim_wolf.body.feet_pos = Vector3(float(best.x) + 0.5, _swim_bed_y + 0.4, float(best.z) + 0.5)
	_swim_wolf.body.velocity = Vector3.ZERO
	_swim_wolf._move_target = _swim_wolf.body.feet_pos + Vector3(6.0, 0.0, 0.0)
	_swim_start = _swim_wolf.body.feet_pos
	_swim_seen = false
	_swim_min_y = 999.0
	_swim_max_leg = 0.0
	_swim_seek = false
	var dry := 0
	for i in 200:
		_swim_wolf._wander_cd = 0.0
		_swim_wolf._leaf_wander({})
		if _swim_wolf._dry_ground(_swim_wolf._move_target):
			dry += 1
	_check("patrulha so sorteia terra seca", dry == 200, "%d/200 alvos secos" % dry)


func _check_swim_assert() -> void:
	if _swim_wolf == null:
		return
	var w := _swim_wolf
	var feet := w.body.feet_pos
	var world: VoxelWorld = main.world
	var now_dry := not w.body.in_water \
			and not world.is_water_xyz(floori(feet.x), world.surface_height(floori(feet.x), floori(feet.z)) + 1, floori(feet.z))
	var advanced := feet.distance_to(_swim_start) > 1.2
	_check("lobo boiou sem afundar ao leito", _swim_seen and _swim_min_y > _swim_bed_y + 0.3,
		"y minimo=%.2f  leito=%.2f" % [_swim_min_y, _swim_bed_y])
	_check("lobo rema na agua", _swim_seen and _swim_max_leg > 0.15,
		"pata max=%.2f rad" % _swim_max_leg)
	_check("lobo preso busca a margem", _swim_seek, "override de margem disparou")
	_check("lobo sai da agua ou avanca nadando", now_dry or advanced,
		"seco=%s  deslocamento=%.1f m" % [now_dry, feet.distance_to(_swim_start)])
	print("       nado: %.1f m desde a queda, pata max %.2f rad, y min %.2f" % [
		feet.distance_to(_swim_start), _swim_max_leg, _swim_min_y])
	w.body.feet_pos = w.home + Vector3(0.0, 1.0, 0.0)
	w.body.velocity = Vector3.ZERO


# ------------------------------------------------------------- mecanicas veloren

## Congela a arvore e deixa so o jogador receber passos do teste: mesmo contrato
## dos passos de minerar/colocar (a IA e o relogio param, a mecanica e dirigida).
func _pause_for(p: Player) -> void:
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	p.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	get_tree().paused = true


func _unpause_after(p: Player) -> void:
	get_tree().paused = false
	self.process_mode = Node.PROCESS_MODE_INHERIT
	p.process_mode = Node.PROCESS_MODE_INHERIT


## Golpe unificado (botao esquerdo): entidade primeiro, bloco depois. No lobo o
## golpe e dano fixo + atordoamento (steering suspenso) + empurrada no corpo.
func _check_attack() -> void:
	var p: Player = main.player
	var w: Wolf = main.wolves[2]
	_pause_for(p)
	p.hp = p.max_hp
	p.energy = p.max_energy
	p.feet_to_spawn(_spawn)
	_aim(p, -0.35)
	w.hp = Wolf.MAX_HP
	w.body.feet_pos = _spawn + Vector3(0.0, 0.0, -2.5)
	w.body.velocity = Vector3.ZERO
	w._move_target = w.body.feet_pos
	Input.action_press("break_block")
	var n := 0
	while absf(w.hp - Wolf.MAX_HP) < 0.01 and n < 30:
		p.update_local(1.0 / 60.0)
		n += 1
	Input.action_release("break_block")
	_check("golpe acertou o lobo", absf(w.hp - Wolf.MAX_HP) > 5.0,
		"hp %.0f -> %.1f em %d ticks" % [Wolf.MAX_HP, w.hp, n])
	_check("dano do golpe e o ataque fixo",
		absf(w.hp - (Wolf.MAX_HP - Player.ATTACK_DAMAGE)) < 0.01, "hp=%.2f" % w.hp)
	_check("golpe atordoa o lobo", w._stagger > 0.0, "stagger=%.2f s" % w._stagger)
	_check("golpe empurra o corpo", w.body.velocity.length() > 3.0,
		"velocidade=%.2f m/s" % w.body.velocity.length())
	w.body.feet_pos = w.home + Vector3(0.0, 1.0, 0.0)
	w.body.velocity = Vector3.ZERO
	w._move_target = w.home
	w._stagger = 0.0
	_unpause_after(p)


func _check_roll() -> void:
	var p: Player = main.player
	var mid := false
	for e in InputMap.action_get_events("roll"):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_MIDDLE:
			mid = true
	_check("acao rolar no botao do meio", mid)
	var ctrl := false
	for e in InputMap.action_get_events("glide"):
		if e is InputEventKey and e.physical_keycode == KEY_CTRL:
			ctrl = true
	_check("acao planar no CTRL", ctrl)
	_pause_for(p)
	p.hp = p.max_hp
	p.energy = p.max_energy
	p.feet_to_spawn(_spawn)
	_aim(p, 0.0)
	# a borda do clique do meio e o mesmo caminho do clique direito (ja provado
	# pelo pipeline de place): aqui a mecanica entra pelo buffer direto
	p._roll_buffer = Player.ROLL_BUFFER
	p.update_local(1.0 / 60.0)
	var spd := Vector3(p.body.velocity.x, 0.0, p.body.velocity.z).length()
	_check("rolamento disparou e custou vigor",
		p._roll_time > 0.0 and absf(p.energy - (Player.MAX_ENERGY - Player.ROLL_COST)) < 0.05,
		"vigor=%.1f  janela=%.2f s" % [p.energy, p._roll_time])
	_check("impulso do rolamento no corpo", spd > 8.0, "velocidade=%.2f m/s" % spd)
	p.take_damage(10.0, p.position3())
	_check("janela de invencibilidade segura o golpe", p.hp == p.max_hp,
		"hp=%.1f  iframes=%.2f" % [p.hp, p._iframes])
	for i in 40:
		p.update_local(1.0 / 60.0)
	p.take_damage(10.0, p.position3())
	_check("fora da janela o golpe entra", absf(p.hp - (p.max_hp - 10.0)) < 0.01,
		"hp=%.1f" % p.hp)
	_unpause_after(p)


## A parede de pedra da o dreno sem atravessar o mapa: correr exige desejo e pe
## no chao, e a parede mantem os dois com o corpo parado.
func _check_energy() -> void:
	var p: Player = main.player
	var w: VoxelWorld = main.world
	_pause_for(p)
	p.hp = p.max_hp
	p.energy = p.max_energy
	p.feet_to_spawn(_spawn)
	_aim(p, 0.0)
	var base := Vector3i(floori(_spawn.x), floori(_spawn.y), floori(_spawn.z))
	var cells: Array[Vector3i] = []
	var orig: Array[int] = []
	for dx in [-1, 0, 1]:
		for dy in [0, 1, 2]:
			var c := base + Vector3i(dx, dy, -2)
			cells.append(c)
			orig.append(w.get_block(c))
			w.set_block(c, BlockDefs.Block.STONE)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	for i in 240:
		p.update_local(1.0 / 60.0)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	var drained := p.energy
	_check("correr drena o vigor", drained < Player.MAX_ENERGY - 15.0,
		"vigor=%.1f apos 4 s de corrida" % drained)
	for i in 120:
		p.update_local(1.0 / 60.0)
	_check("parado recupera o vigor", p.energy > drained + 15.0,
		"%.1f -> %.1f em 2 s" % [drained, p.energy])
	Input.action_press("sprint")
	Input.action_press("move_forward")
	p.energy = 0.4
	for i in 40:
		p.update_local(1.0 / 60.0)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	_check("vigor zerado trava a corrida", p._sprint_locked,
		"vigor=%.2f  trava=%s" % [p.energy, p._sprint_locked])
	p.energy = Player.SPRINT_RECOVERY + 12.0
	for i in 20:
		p.update_local(1.0 / 60.0)
	_check("vigor recuperado libera a corrida", not p._sprint_locked,
		"vigor=%.1f  trava=%s" % [p.energy, p._sprint_locked])
	for i in cells.size():
		w.set_block(cells[i], orig[i])
	_unpause_after(p)


func _check_glide_fall() -> void:
	var p: Player = main.player
	_pause_for(p)
	p.hp = p.max_hp
	p.energy = p.max_energy
	p.feet_to_spawn(_spawn + Vector3(0.0, 4.0, 0.0))
	p.yaw = 0.0
	p.pitch = -0.9
	Input.action_press("glide")
	var seen := false
	var min_vy := 0.0
	var max_hs := 0.0
	for i in 200:
		p.update_local(1.0 / 60.0)
		seen = seen or p.gliding
		min_vy = minf(min_vy, p.body.velocity.y)
		max_hs = maxf(max_hs, Vector3(p.body.velocity.x, 0.0, p.body.velocity.z).length())
		if i > 20 and p.body.on_ground:
			break
	Input.action_release("glide")
	var cap_dive := Player.GLIDE_SINK + 0.9 * Player.GLIDE_DIVE_SINK
	_check("planou segurando CTRL no ar", seen)
	_check("planar limita a queda", seen and min_vy >= -cap_dive - 0.05,
		"vy minimo=%.2f  cap do mergulho=%.2f" % [min_vy, cap_dive])
	_check("mergulhar ganha velocidade", seen and max_hs > 7.0,
		"hs maxima=%.2f m/s" % max_hs)
	_check("planar aterra sem dano de queda", p.hp == p.max_hp,
		"hp=%.1f  no chao=%s" % [p.hp, p.body.on_ground])
	p.feet_to_spawn(_spawn + Vector3(0.0, 12.0, 0.0))
	for i in 150:
		p.update_local(1.0 / 60.0)
		if p.body.on_ground:
			break
	var esperado: float = p.max_hp \
			- (sqrt(2.0 * p.body.gravity * 12.0) - Player.FALL_SAFE_SPEED) \
			* Player.FALL_DAMAGE_PER_SPEED
	_check("queda livre machuca", absf(p.hp - esperado) < 2.0,
		"hp=%.1f (esperado ~%.1f  gravidade=%.0f)" % [p.hp, esperado, p.body.gravity])
	_unpause_after(p)


func _check_breath() -> void:
	if _lake == Vector3i.ZERO:
		return
	var p: Player = main.player
	_pause_for(p)
	p.hp = p.max_hp
	p.energy = p.max_energy
	p.feet_to_spawn(Vector3(float(_lake.x) + 0.5, float(_lake.y) + 0.3, float(_lake.z) + 0.5))
	for i in 120:
		p.update_local(1.0 / 60.0)
	_check("submerso consome ar", p.air < Player.AIR_MAX - 0.5,
		"ar=%.2f s apos 2 s submerso" % p.air)
	p.air = 0.5
	for i in 240:
		p.update_local(1.0 / 60.0)
	_check("sem ar o afogamento machuca", p.hp < p.max_hp - 15.0,
		"hp=%.1f apos 4 s sem ar" % p.hp)
	p.feet_to_spawn(_spawn + Vector3(0.0, 1.0, 0.0))
	for i in 120:
		p.update_local(1.0 / 60.0)
	_check("fora da agua o ar enche", p.air >= Player.AIR_MAX - 0.01,
		"ar=%.2f s" % p.air)
	_unpause_after(p)


func _check_regen() -> void:
	var p: Player = main.player
	_pause_for(p)
	p.energy = p.max_energy
	p._since_damage = 20.0
	var hp0 := p.hp
	for i in 120:
		p.update_local(1.0 / 60.0)
	_check("regenera fora de combate", p.hp > hp0 + 1.5,
		"hp %.1f -> %.1f em 2 s" % [hp0, p.hp])
	p._since_damage = 0.0
	var hp1 := p.hp
	for i in 120:
		p.update_local(1.0 / 60.0)
	_check("combate recente trava a regeneracao", p.hp < hp1 + 0.05,
		"hp %.1f -> %.1f apos 2 s" % [hp1, p.hp])
	_unpause_after(p)


## Contrato do docs/design/04 (camada 5): sem llama-server o oraculo entra em
## recuo, a narrativa fica vazia e a utilidade/arvore seguem decidindo sozinhas.
## A porta 1 e fechada de proposito — deterministicas mesmo com um servidor
## real na maquina.
func _check_oracle_arm() -> void:
	_oracle_probe = MindOracle.new()
	_oracle_probe.name = "OracleProbe"
	_oracle_probe.server_url = "http://127.0.0.1:1"
	_oracle_probe.request_timeout = 1.0
	_oracle_probe.roster_provider = Callable(main, "wolves_roster")
	add_child(_oracle_probe)


func _check_oracle() -> void:
	var oracle := _oracle_probe
	_oracle_probe = null
	var w: Wolf = main.wolves[0]
	_check("narrativa vazia sem servidor", oracle.narration_of(w.identity) == "",
		"narr='%s'" % oracle.narration_of(w.identity))
	_check("recuo global apos falha", oracle._server_cd > 0.0,
		"recuo=%.1f s" % oracle._server_cd)
	_check("mente segue decidindo sem narrador", w.mind != null and w.intent != "",
		"intento=%s" % w.intent)
	oracle.queue_free()


## Um braco do experimento. A posicao, o hp, o campo de Eter ao redor e a ameaca
## sao identicos em todos os bracos (reset acima); o que muda e apenas o registro
## na mente:
##   ARM_NONE     crencia apagada
##   ARM_WOUND    dano real do jogador (percepcao grava a crencia sozinha)
##   ARM_REMEMBER crencia gravada pelo mesmo delta que a percepcao usa
## Depois de ARM_STEPS decisoes mede a intengao, o veto da opcao hunt e para onde
## a arvore de comportamento mandou o lobo.
func _run_arm(w: Wolf, spot: Vector3, half: float, t: float, mode: int) -> Dictionary:
	var p: Player = main.player
	_reset_arm(w, p, spot, half)
	w.intent = "patrol"
	w.mind.beliefs.erase(BELIEF)
	match mode:
		ARM_WOUND:
			w.take_damage(9.0, Wolf.ACTOR_PLAYER, p.position3())
			w.take_damage(9.0, Wolf.ACTOR_PLAYER, p.position3())
			w.hp = half
			w._threat = 0.0
			_wipe_field(w)
		ARM_REMEMBER:
			w.mind.reinforce(BELIEF, 0.3, "perception")
			w.mind.reinforce(BELIEF, 0.3, "perception")
	for i in ARM_STEPS:
		w.sim_step(t + float(i) * DT_SIM, DT_SIM)
	var bd: Dictionary = w._scorer.breakdown()
	var target: Vector3 = w._move_target
	return {
		"intent": w.intent,
		"hunt_vetoed": bool(bd["hunt"]["vetoed"]),
		"hunt_score": float(bd["hunt"]["score"]),
		"chasing": target.distance_to(p.position3()) < 1.5,
		"dist": w.center().distance_to(p.position3()),
	}


func _reset_arm(w: Wolf, p: Player, spot: Vector3, half: float) -> void:
	w.body.feet_pos = spot
	w.body.velocity = Vector3.ZERO
	w.hp = half
	w._threat = 0.0
	w._saw_cd = 0.0
	w._bite_cd = 0.0
	w._wander_cd = 0.0
	w._move_target = spot
	# home longe do jogador: assim o alvo de patrulha nunca pode ser confundido
	# com estar caçando o jogador.
	w.home = spot + (spot - p.position3()).normalized() * 40.0
	p.yaw = 0.0
	p.pitch = 0.0
	_wipe_field(w)


## Limpa os tres canais num raio maior que o raio de faro do lobo, para que os
## bracos comecem exatamente com o mesmo ar.
func _wipe_field(w: Wolf) -> void:
	var a: AetherField = main.aether
	var c0 := a.cell_of_world(w.center())
	for dy in range(-2, 3):
		for dz in range(-4, 5):
			for dx in range(-4, 5):
				var c := c0 + Vector3i(dx, dy, dz)
				a.set_cell_value(c, AetherField.Channel.FEAR, 0.0)
				a.set_cell_value(c, AetherField.Channel.BLOOD, 0.0)
				a.set_cell_value(c, AetherField.Channel.WORK, 0.0)


func _experiment_spot(w: Wolf, p: Player) -> Vector3:
	for dist in [10.0, 12.0, 8.0, 14.0]:
		for dirv in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var dir: Vector3 = dirv
			var radius: float = dist
			var cand: Vector3 = p.position3() + dir * radius
			var y: int = main.world.surface_height(int(cand.x), int(cand.z)) + 1
			var pos := Vector3(cand.x, float(y), cand.z)
			w.body.feet_pos = pos
			if y <= VoxelConfig.SEA_LEVEL:
				continue
			var from := pos + Vector3(0.0, Wolf.DIMS.y * 0.5, 0.0)
			var to := p.position3() + Vector3(0.0, 0.9, 0.0)
			if main.world.line_of_sight(from, to):
				return pos
	return Vector3.INF


# --------------------------------------------------------------------- hud

func _check_hud() -> void:
	var hud = main.hud
	var p: Player = main.player
	_check("hotbar de 7 slots no hud", hud._slots.size() == 7, "slots=%d" % hud._slots.size())
	_check("overlay de morte comecou escondido", not hud._death.visible)
	# O painel de binds agora abre sozinho no spawn (o `DIR colocar` nao aparece em
	# lugar nenhum ate o jogador achar o botao direito) e fecha sozinho. Testado
	# pelo mecanismo, nao pelo estado do boot: o estado do boot depende de quanto
	# tempo de relogio ja passou desde o _ready do main.
	hud.preview_binds(0.5)
	_check("previsa de binds abre o painel", hud._binds.visible and hud._binds_cd > 0.0,
		"visivel=%s  cd=%.2f" % [hud._binds.visible, hud._binds_cd])
	hud._process(0.6)
	_check("previsa de binds fecha sozinha", not hud._binds.visible)
	p.toggle_debug.emit()
	_check("F3 via sinal liga o debug", hud.debug_visible())
	hud._process(0.2)
	var dbg := String(hud._debug.text)
	_check("debug mostra a decisao de IA", dbg.contains("lobo0") and dbg.contains("bt "),
		"%d linhas" % dbg.split("\n").size())
	_check("debug mostra o relogio", dbg.contains("tick"), "linhas=%d" % dbg.split("\n").size())
	p.toggle_debug.emit()
	_check("F3 via sinal desliga o debug", not hud.debug_visible())
	hud.preview_binds(0.5)
	hud.show_binds(true)
	_check("F2 abre o painel de binds", hud._binds.visible and dbg.length() > 0)
	hud._process(0.6)
	_check("F2 pinha o painel contra a previsa", hud._binds.visible, "cd=%.2f" % hud._binds_cd)
	hud.show_binds(false)

	var d0 := int(main.stats["deaths"])
	var blood0: float = main.aether.channel_totals()[AetherField.Channel.BLOOD]
	p.take_damage(1000.0, Vector3.ZERO)
	_check("dano letal mata", not p.alive and p.hp <= 0.0, "hp=%.1f" % p.hp)
	_check("overlay de morte apareceu", hud._death.visible)
	_check("contador de mortes", int(main.stats["deaths"]) == d0 + 1, "mortes=%d" % main.stats["deaths"])
	var blood1: float = main.aether.channel_totals()[AetherField.Channel.BLOOD]
	_check("morte imprinta sangue no eter", blood1 > blood0, "%.3f -> %.3f" % [blood0, blood1])
	main.respawn()
	_check("renascer devolve a vida", p.alive and p.hp >= p.max_hp, "hp=%.1f" % p.hp)
	_check("overlay some ao renascer", not hud._death.visible)
	_check("renascer no ponto de spawn",
		p.body.feet_pos.distance_to(_spawn) < 2.0, "feet=%s" % p.body.feet_pos)


# --------------------------------------------------------------------- save

func _check_save() -> void:
	var w: VoxelWorld = main.world
	var p: Player = main.player
	var wolf0: Wolf = main.wolves[0]
	# (20,20) de proposito: as 16 colunas amostradas no boot incluem (12,12), e uma
	# edicao ali faria o "relevo identico apos carregar" comparar contra si mesmo.
	var extra := Vector3i(20, w.surface_height(20, 20) + 4, 20)
	w.set_block(extra, BlockDefs.Block.WOOD)
	var before := {
		"edits": w.edits.size(), "tick": int(main.clock.tick), "hp": p.hp,
		"feet": p.body.feet_pos, "pitch": p.pitch, "yaw": p.yaw,
		"wolf_hp": wolf0.hp, "wolf_mem": wolf0.mind.episodic.size(),
		"wolf_belief": wolf0.mind.belief(BELIEF), "wolf_trust": wolf0.mind.trust(Wolf.ACTOR_PLAYER),
	}
	var before_feet: Vector3 = before["feet"]
	main.save_game()
	_check("slot escrito", SaveManager.has_slot(SLOT), "caminho=%s" % SaveManager.slot_path(SLOT))
	_check("sem .tmp sobrando", not FileAccess.file_exists(SaveManager.tmp_path(SLOT)))
	var rd := SaveManager.read_slot(SLOT)
	_check("leitura do slot", bool(rd["ok"]), "%.1f ms" % rd["ms"])
	var data: Dictionary = rd["data"]
	_check("schema e gen_version gravados",
		int(data["schema"]) == SaveManager.SCHEMA and int(data["gen_version"]) == WorldGen.GEN_VERSION,
		"schema=%d  gen=%d" % [data["schema"], data["gen_version"]])
	var f := FileAccess.open(SaveManager.slot_path(SLOT), FileAccess.READ)
	var bytes := f.get_length()
	f.close()
	_check("save com corpo", bytes > 1000, "%d bytes" % bytes)
	_check("save guarda o diario, nao os voxels",
		int(data["edits"].size()) == before["edits"], "edicoes=%d" % data["edits"].size())
	main.save_game()
	_check("segunda escrita sobrescreve atomicamente", bool(SaveManager.read_slot(SLOT)["ok"]),
		"%d bytes" % bytes)

	var after_extra := Vector3i(30, w.surface_height(30, 30) + 4, 30)
	w.set_block(after_extra, BlockDefs.Block.SNOW)
	p.take_damage(20.0, Vector3.ZERO)
	wolf0.take_damage(10.0, Wolf.ACTOR_PLAYER, p.position3())
	p.feet_to_spawn(_spawn + Vector3(4.0, 0.0, 4.0))
	_check("mundo foi mutado de proposito",
		w.edits.size() == before["edits"] + 1 and wolf0.hp != before["wolf_hp"],
		"edicoes=%d  hp lobo=%.1f" % [w.edits.size(), wolf0.hp])
	main.load_game()
	_check("diario de edicoes restaurado", w.edits.size() == int(before["edits"]),
		"%d -> %d" % [w.edits.size(), before["edits"]])
	_check("edicao pos-save desfeita",
		w.get_block(after_extra) == BlockDefs.Block.AIR, "voxel=%s" % after_extra)
	_check("edicao pre-save mantida",
		w.get_block(extra) == BlockDefs.Block.WOOD, "voxel=%s" % extra)
	var same := true
	for k in _heights:
		var parts: PackedStringArray = String(k).split(",")
		if main.world.surface_height(int(parts[0]), int(parts[1])) != int(_heights[k]):
			same = false
	_check("relevo identico apos carregar", same, "16 colunas")
	_check("jogador no lugar de antes",
		p.body.feet_pos.distance_to(before_feet) < 0.01,
		"feet=%s" % p.body.feet_pos)
	_check("camera restaurada", is_equal_approx(p.pitch, float(before["pitch"]))
		and is_equal_approx(p.yaw, float(before["yaw"])), "pitch=%.2f" % p.pitch)
	_check("vida do jogador restaurada", is_equal_approx(p.hp, float(before["hp"])), "hp=%.1f" % p.hp)
	_check("tick restaurado", int(main.clock.tick) == int(before["tick"]), "tick=%d" % main.clock.tick)
	_check("memoria do lobo voltou",
		wolf0.mind.episodic.size() == int(before["wolf_mem"])
		and is_equal_approx(wolf0.mind.trust(Wolf.ACTOR_PLAYER), float(before["wolf_trust"])),
		"episodios=%d  confianca=%.2f" % [wolf0.mind.episodic.size(), wolf0.mind.trust(Wolf.ACTOR_PLAYER)])
	_check("hp do lobo voltou", is_equal_approx(wolf0.hp, float(before["wolf_hp"])), "hp=%.1f" % wolf0.hp)


# --------------------------------------------------------------------- ciclo de vida

func _check_corpse() -> void:
	var w: Wolf = main.wolves[2]
	_corpse_n = main.wolves.size()
	var felled0 := int(main.stats["wolves_felled"])
	var blood0: float = main.aether.channel_totals()[AetherField.Channel.BLOOD]
	var fear0: float = main.aether.channel_totals()[AetherField.Channel.FEAR]
	w.die()
	_check("morte contabilizada", int(main.stats["wolves_felled"]) == felled0 + 1,
		"abatidos=%d" % main.stats["wolves_felled"])
	_check("ainda na matilha (tempo de cadaver)", main.wolves.size() == _corpse_n,
		"cadaver=%.1f s" % Wolf.CORPSE_SECONDS)
	_check("lobo morto nao decide", not w.alive and w.intent == "morto", "intencao=%s" % w.intent)
	var b: Array = main.aether.channel_totals()
	_check("morte imprinta sangue e medo no eter",
		b[AetherField.Channel.BLOOD] > blood0 and b[AetherField.Channel.FEAR] > fear0,
		"blood=%.2f  fear=%.2f" % [b[AetherField.Channel.BLOOD], b[AetherField.Channel.FEAR]])


func _check_reap() -> void:
	var n: int = main.wolves.size()
	_check("cadaver recolhido da matilha", n == _corpse_n - 1, "%d -> %d lobos" % [_corpse_n, n])
	var d: Dictionary = main.diagnostics()
	_check("reposicao enfileirada", int(d["pending_respawns"]) == 1,
		"na fila=%d  vivos=%d" % [d["pending_respawns"], d["wolves_alive"]])
	_check("sem no de malha sobrando", main.get_node("Terrain").get_child_count() == 64,
		"nos=%d" % main.get_node("Terrain").get_child_count())
	_check("nenhum tick perdido no teste inteiro", int(d["dropped_ticks"]) == 0,
		"perdidos=%d  pior passo=%.2f ms  tick=%d" % [
			d["dropped_ticks"], d["worst_sim_ms"], d["tick"]])
	_check("lobos seguem vivos e decidindo", int(d["wolves_alive"]) >= 3,
		"vivos=%d  triangulos=%d" % [d["wolves_alive"], d["triangles"]])
	print("       diagnostico final: ", JSON.stringify(d))
