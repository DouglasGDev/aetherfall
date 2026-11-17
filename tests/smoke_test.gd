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
var _click_pending := false
var _click_state := false
var _armed := false
var _tick_player := false
var _click_frame := -1
var _click_detail := ""


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
		["campo de eter", 0, _check_aether],
		["relogio de simulacao", 0, _check_clock],
		["minerar e colocar", 0, _check_mechanics],
		["colocar com clique", 20, _check_place],
		["soltar o botao", 12, _check_click_release],
		["guarda de colocacao", 20, _check_place_guard],
		["tecla 3 no hotbar", 3, _check_hotbar_key],
		["memoria muda comportamento", 0, _check_memory],
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
	if _armed and Input.is_action_just_pressed("place_block"):
		var p: Player = main.player
		_armed = false
		_tick_player = false
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
	_scratch_root.queue_free()
	_scratch = null


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
	# trocaria o alvo, e o passo passaria a medir a IA em vez da mecanica.
	main.process_mode = Node.PROCESS_MODE_DISABLED
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

	# Colocar exige o pipeline real de input: `Input.action_press()` so escreve o
	# estado da acao, enquanto `_apply_actions` procura a borda
	# (`is_action_just_pressed`). Minerar pode continuar sintetico porque le o
	# nivel, nao a borda. O mundo segue congelado e o clique arma a maquina de
	# espera: a assercao vive em _check_place.
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


## Enfileira um clique e passa a girar o jogador ate a borda aparecer no input do
## `player`. `soltar` nao arma: sem borda para esperar, basta o proximo frame.
func _arm_click(pressed: bool) -> void:
	_click_frame = -1
	_click_detail = ""
	_armed = pressed
	_tick_player = true
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
	main.process_mode = Node.PROCESS_MODE_INHERIT
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
	_check("painel de binds comecou escondido", not hud._binds.visible)
	p.toggle_debug.emit()
	_check("F3 via sinal liga o debug", hud.debug_visible())
	hud._process(0.2)
	var dbg := String(hud._debug.text)
	_check("debug mostra a decisao de IA", dbg.contains("lobo0") and dbg.contains("bt "),
		"%d linhas" % dbg.split("\n").size())
	_check("debug mostra o relogio", dbg.contains("tick"), "linhas=%d" % dbg.split("\n").size())
	p.toggle_debug.emit()
	_check("F3 via sinal desliga o debug", not hud.debug_visible())
	hud.show_binds(true)
	_check("F2 abre o painel de binds", hud._binds.visible and dbg.length() > 0)
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
