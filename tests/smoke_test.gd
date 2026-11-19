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
var _place_n0 := 0
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
		["corpo encaixado se solta", 0, _check_embedded_body],
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
		["inventario, pilhas e receitas", 0, _check_items],
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
	var live_moved := 0
	for i in main.wolves.size():
		if (main.wolves[i] as Node3D).global_position.distance_to(_spawn_pos[i]) > 0.5:
			live_moved += 1
	_check("ao menos um lobo se moveu na janela real", live_moved >= 1,
		"%d/%d se moveram em %.2f s de logica" % [live_moved, main.wolves.size(), float(main.elapsed)])
	var encaixados := ""
	var n_enc := 0
	for w in main.wolves:
		var wf := w as Wolf
		if wf.alive and wf.world.aabb_hits_solid(wf.body.aabb()):
			n_enc += 1
			encaixados += " lobo%d em %s" % [wf.identity, str(wf.body.feet_pos)]
	_check("nenhum lobo com o corpo dentro do terreno", n_enc == 0,
		"encaixados=%d%s" % [n_enc, encaixados])
	_check_wolf_steering()
	var intents := ""
	var legal := true
	for w in main.wolves:
		intents += "%s " % w.intent
		if not (w.intent in ["patrol", "hunt", "investigate", "flee"]):
			legal = false
	_check("intento sempre valido", legal, intents.strip_edges())


## O gate do movimento, medido em ticks proprios e com a situacao montada. O engine
## chama _physics_process tantas vezes quanto o relogio de parede deixa, entao contar
## lobos que andaram numa janela de tempo real era sorte: a mesma suite ja mediu 1/5,
## 2/5 e 3/5. Aqui o teste da o dt e o numero de passos, e poe o corpo num ponto
## onde ele cabe (o chao onde o lobo nasceu nao e nosso -- dois dos cinco nasceram
## dentro da parede, estado em que nenhum eixo anda; coberto pelo censo acima).
##
## So o passo, nao a decisao: chamar sim_step em serie da 40 s de IA de uma vez
## para cada lobo, eles caçam o jogador parado do teste e o matam antes das
## secoes de vigor/respiracao/morte (medido: 32 falhas em cascata). A decisao de
## andar fica gated pelo censo fraco acima e pelos checks de utilidade.
func _check_wolf_steering() -> void:
	var wf: Wolf = null
	for w in main.wolves:
		if (w as Wolf).alive:
			wf = w as Wolf
			break
	if wf == null:
		_check("steering e colisao movem o lobo", false, "nenhum lobo vivo")
		return
	var spot := _clear_stand_spot(wf)
	if spot == Vector3.INF:
		_check("steering e colisao movem o lobo", false, "nenhum ponto onde o corpo caiba")
		return
	var was_feet: Vector3 = wf.body.feet_pos
	var was_vel: Vector3 = wf.body.velocity
	var was_target: Vector3 = wf._move_target
	var was_stagger: float = wf._stagger
	var was_unstick: float = wf._unstick
	wf.body.feet_pos = spot
	wf.body.velocity = Vector3.ZERO
	wf._stagger = 0.0
	wf._unstick = 0.0
	wf._speed = Wolf.SPEED_WALK
	wf._move_target = spot + Vector3(0.0, 0.0, 8.0)
	var reach := 0.0
	for _step in 200:
		wf._physics_process(0.05)
		reach = maxf(reach, spot.distance_to(wf.body.feet_pos))
	_check("steering e colisao movem o lobo", reach > 0.5,
		"lobo%d reach=%.2f m em 200 passos desde (%.1f, %.1f, %.1f)  agora em %s"
			% [wf.identity, reach, spot.x, spot.y, spot.z, str(wf.body.feet_pos)])
	wf.body.feet_pos = was_feet
	wf.body.velocity = was_vel
	wf._move_target = was_target
	wf._stagger = was_stagger
	wf._unstick = was_unstick


## Pe sobre o terreno mais alto da coluna, procurando ao redor do spawn do jogador
## ate achar um ponto onde o corpo do lobo cabe e tem chao embaixo.
func _clear_stand_spot(wf: Wolf) -> Vector3:
	var c: Vector3 = main.spawn_point()
	for ring in [0, 2, 4, 6, 8, 10, 12]:
		for dirv in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var p: Vector3 = c + dirv * float(ring)
			var y: int = main.world.surface_height(int(p.x), int(p.z)) + 1
			var cand := Vector3(p.x, float(y), p.z)
			if y > VoxelConfig.SEA_LEVEL and wf.body.can_stand_at(cand):
				return cand
	return Vector3.INF


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

	# Vidro: a unica face ALPHA do registro. Um pano sozinho mantem as 6 faces e o
	# pano colado ao lado nao acrescenta a de contato -- 20 triangulos no par, nao
	# 24. E assim que a classe de desenho e medida, nao de olho.
	var gx := cx + 6
	var glass_air := true
	for dy in 3:
		for dz in 3:
			for dx in 4:
				if _scratch.get_block(Vector3i(gx - 1 + dx, base - 1 + dy, cz - 1 + dz)) \
						!= BlockDefs.Block.AIR:
					glass_air = false
	_check("regiao do vidro estava em ar", glass_air, "voxel=(%d,%d,%d)" % [gx, base, cz])
	var pane := -1
	var pair := -1
	if glass_air:
		var g0 := _scratch.triangle_count()
		_scratch.set_block(Vector3i(gx, base, cz), BlockDefs.Block.GLASS, false)
		_scratch.generate_meshes_all()
		pane = _scratch.triangle_count() - g0
		_scratch.set_block(Vector3i(gx + 1, base, cz), BlockDefs.Block.GLASS, false)
		_scratch.generate_meshes_all()
		pair = _scratch.triangle_count() - g0
	_check("pano de vidro sozinho tem 6 faces", glass_air and pane == 12,
		"triangulos=%d  esperado=12" % pane)
	_check("vidro colado nao desenha a face de contato", glass_air and pair == 20,
		"par=%d  esperado=20  sem culling alfa=24" % pair)

	# Cada surface added tem que sair com material: os grupos (opaco, agua, vidro)
	# sao acrescentados condicionalmente, entao o indice do material nao pode ser
	# um numero fixo. Um chunk de vidro sem agua e o caso que pegava o indice 2
	# fora dos dois surfaces existentes e deixava o pano sem material.
	var sem_material := 0
	var surfaces := 0
	for ck in _scratch.chunks.values():
		var mi: MeshInstance3D = ck.mesh_instance
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			surfaces += 1
			if mi.mesh.surface_get_material(i) == null:
				sem_material += 1
	_check("todo surface de chunk tem material", surfaces > 0 and sem_material == 0,
		"surfaces=%d  sem material=%d" % [surfaces, sem_material])

	# e o pano tem que carregar o material de vidro, nao qualquer um: e isso que
	# decide transparencia e textura do atlas na janela do jogador
	var pane_key := Coords.chunk_of(Vector3i(gx, base, cz))
	var glass_mat := false
	if _scratch.chunks.has(pane_key):
		var pm: MeshInstance3D = _scratch.chunks[pane_key].mesh_instance
		if pm != null and pm.mesh != null:
			for i in pm.mesh.get_surface_count():
				if pm.mesh.surface_get_material(i) == _scratch._mat_glass:
					glass_mat = true
	_check("o pano de vidro usa o material de vidro", glass_air and glass_mat,
		"chunk=(%d,%d)" % [pane_key.x, pane_key.y])

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


## Corpo com o volume dentro de solido nao anda por eixo nenhum: o primeiro
## subpasso colide, a gravidade tambem, e a velocidade morre em zero -- congelado
## para sempre (foi o que travou 2 dos 5 lobos do spawn). Montado no ar, longe do
## terreno: tres voxels de pedra ao redor do pe, e o integrador tem de devolve-lo
## ao ar em vez de deixa-la la dentro.
func _check_embedded_body() -> void:
	var bx := 40
	var bz := 40
	var y: int = mini(main.world.surface_height(bx, bz) + 12, VoxelConfig.CHUNK_SIZE_Y - 5)
	var livre_antes := true
	for dz in range(-1, 2):
		if main.world.get_block(Vector3i(bx, y, bz + dz)) != BlockDefs.Block.AIR:
			livre_antes = false
	_check("regiao do corpo encaixado estava em ar", livre_antes, "voxel=(%d,%d,%d)" % [bx, y, bz])
	for dz in range(-1, 2):
		main.world.set_block(Vector3i(bx, y, bz + dz), BlockDefs.Block.STONE, false)
	var bd := VoxelBody.new()
	bd.setup(main.world, Vector3(float(bx) + 0.5, float(y), float(bz) + 0.5), Wolf.DIMS)
	var dentro: bool = main.world.aabb_hits_solid(bd.aabb())
	for _i in 4:
		bd.move_and_collide(0.05)
	var saiu: bool = not main.world.aabb_hits_solid(bd.aabb())
	var lift: float = bd.feet_pos.y - float(y)
	_check("corpo encaixado sobe para fora do solido", dentro and saiu,
		"encaixado=%s  agora em y=%.2f" % [dentro, bd.feet_pos.y])
	_check("o resgate e curto e nao teleporta o corpo", saiu and lift > 0.0 and lift <= 1.2,
		"subiu=%.2f m  teto=1,20" % lift)
	for dz in range(-1, 2):
		main.world.set_block(Vector3i(bx, y, bz + dz), BlockDefs.Block.AIR, false)
	main.world.process(64)


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


## Pixels do quadro que o jogador ve, calculados da lente (fov vertical) e da
## resolucao do project.godot -- NAO do viewport do processo: em headless ele e
## 64x64, e medir o enquadramento nele daria um 1:1 que ninguem jogando ve.
func _screen_res() -> Vector2:
	return Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))


func _lens_px(cam: Camera3D, world: Vector3, res: Vector2) -> Vector2:
	var c := cam.global_transform.affine_inverse() * world
	var tan := tan(deg_to_rad(cam.fov) * 0.5)
	var ndc_y := (c.y / -c.z) / tan
	var ndc_x := (c.x / -c.z) / (tan * (res.x / res.y))
	return Vector2((ndc_x * 0.5 + 0.5) * res.x, (0.5 - ndc_y * 0.5) * res.y)


## Caixa projetada do cubo na mao, em pixels do quadro: [x0, y0, x1, y1]; vazia
## quando o punho esta closed ou algum canto caiu atras da lente. E o que prende
## o enquadramento do view model: os arcos ja jogaram o bloco pela borda de cima,
## e contagem de malhas nao percebe isso.
func _vm_frame(cam: Camera3D, held: MeshInstance3D) -> Array:
	if held == null or not held.visible:
		return []
	var g := held.global_transform
	var h := FPViewmodel.HELD_SIZE * 0.5
	var back := cam.global_transform.affine_inverse()
	var res := _screen_res()
	var lo := Vector2(99999.0, 99999.0)
	var hi := Vector2(-99999.0, -99999.0)
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				var w := g * Vector3(sx * h, sy * h, sz * h)
				if (back * w).z > 0.0:
					return []
				var pt := _lens_px(cam, w, res)
				lo.x = minf(lo.x, pt.x)
				lo.y = minf(lo.y, pt.y)
				hi.x = maxf(hi.x, pt.x)
				hi.y = maxf(hi.y, pt.y)
	return [lo.x, lo.y, hi.x, hi.y]


func _in_frame(fr: Array, res: Vector2) -> bool:
	return fr.size() == 4 and fr[0] >= 0.0 and fr[1] >= 0.0 \
		and fr[2] <= res.x and fr[3] <= res.y


func _fmt_frame(fr: Array) -> String:
	if fr.is_empty():
		return "punho closed"
	return "[%d..%d x %d..%d]" % [int(fr[0]), int(fr[2]), int(fr[1]), int(fr[3])]


## Malhas em cena que desenham sem teste de profundidade.
func _mesh_count_no_depth(n: Node) -> int:
	var total := 0
	if n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree():
		var mi := n as MeshInstance3D
		var m := mi.material_override as StandardMaterial3D
		if m == null:
			m = mi.mesh.material as StandardMaterial3D
		if m != null and m.no_depth_test:
			total += 1
	for c in n.get_children():
		total += _mesh_count_no_depth(c)
	return total


## Roda um arco do view model tick a tick e devolve [ombro minimo, ombro maximo,
## ticks com o cubo fora do quadro]. `punch` dispara o golpe; sem ele e a lavra,
## que precisa de alguns ticks para assentar o blend antes de medir o ciclo.
func _vm_arc(vm: FPViewmodel, cam: Camera3D, res: Vector2, ticks: int, punch: bool) -> Array:
	if punch:
		vm.swing()
	else:
		vm.mining = true
		for i in 18:
			vm.advance(1.0 / 60.0)
	var lo := 999.0
	var hi := -999.0
	var fora := 0
	for i in ticks:
		vm.advance(1.0 / 60.0)
		var a := vm.arm_angles().x
		lo = minf(lo, a)
		hi = maxf(hi, a)
		if not _in_frame(_vm_frame(cam, vm.held_mesh()), res):
			fora += 1
	return [lo, hi, fora]


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
		var was := w.get_block(tgt)
		var drop := BlockDefs.drop_of(was)
		var drop0 := p.inv.count_of(drop)
		var mined0 := int(main.stats["mined"])
		var items0 := p.inv.item_count()
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
		# o que entra no inventario e o drop do registro, nao o id que estava la:
		# pedra vira bruta, grama vira terra, folha nao vira nada
		var want := 1 if drop != BlockDefs.Block.AIR else 0
		_check("lavra entrou no inventario como drop",
			p.inv.count_of(drop) == drop0 + want and p.inv.item_count() == items0 + want,
			"bloco=%d  drop=%d  pilha=%d->%d" % [was, drop, drop0, p.inv.count_of(drop)])

	# Corpo do jogador: um modelo por vista. Em 3a pessoa o rig inteiro esta em
	# cena e o view model sai do quadro; em 1a e ao contrario — a camera mora no
	# olho, o corpo de 3a pessoa nao entra (na lente ele virava slab sobre o
	# alvo) e o que se ve e o braco direito do view model segurando o bloco
	# selecionado, com o arco de lavra e o de golpe visiveis.
	p.yaw = 0.62
	p.third_person = true
	p.update_local(1.0 / 60.0)
	var head_tp := p.avatar.head_shown()
	var drift := p.avatar.global_position.distance_to(p.body.feet_pos)
	var facing := rad_to_deg(p.avatar.rotation.y)
	var parts := _mesh_count(p.avatar)
	var parts_tp := _mesh_count_visible(p.avatar)
	var vm_tp := _mesh_count_visible(p.viewmodel)
	var span := _mesh_span(p.avatar)
	var top: float = span[1] - p.body.feet_pos.y
	var base: float = span[0] - p.body.feet_pos.y
	p.select_slot(0)
	p.third_person = false
	p.update_local(1.0 / 60.0)
	var head_fp := p.avatar.head_shown()
	var parts_fp := _mesh_count_visible(p.avatar)
	var vm_fp := _mesh_count_visible(p.viewmodel)
	_check("corpo do jogador tem malhas", parts >= 20, "caixas=%d" % parts)
	_check("silhueta fecha em ~1,8 m", top > 1.7 and top < 1.9, "altura=%.2f" % top)
	_check("nenhuma malha abaixo dos pes", base > -0.15, "base=%.2f" % base)
	_check("avatar cola nos pes", drift < 0.002, "desvio=%.5f" % drift)
	_check("avatar gira com o yaw", absf(facing - rad_to_deg(0.62)) < 0.01,
		"corpo=%.2fdeg  esperado=%.2fdeg" % [facing, rad_to_deg(0.62)])
	_check("corpo inteiro em cena na 3a pessoa",
		head_tp and p.avatar.visible and parts_tp == parts,
		"visiveis=%d de %d" % [parts_tp, parts])
	_check("view model fora de cena na 3a pessoa", vm_tp == 0, "malhas vm=%d" % vm_tp)
	_check("corpo de 3a pessoa sai inteiro na 1a", parts_fp == 0 and not head_fp,
		"malhas visiveis=%d" % parts_fp)
	_check("braco de 1a pessoa em cena", vm_fp >= 8, "malhas vm=%d" % vm_fp)

	# O braco na frente da lente: o cubo segue o slot selecionado, fica no
	# quadrante inferior direito dentro do quadro, e desenha SEM teste de
	# profundidade — encostando o nariz na parede o membro nao pode ser engolido
	# pelo muro (frame `parede` da sonda).
	var vm: FPViewmodel = p.viewmodel
	var res := _screen_res()

	# calibracao do instrumento antes de confiar nele: a formula da suite,
	# alimentada com a resolucao real do processo, bate com o unproject do motor
	# ponto a ponto nos 8 cantos do cubo. So depois disso ela recebe os
	# 1280x720 da partida, que o headless nao tem.
	var proc := Vector2(p.camera.get_viewport().size)
	var gg := vm.held_mesh().global_transform
	var hh := FPViewmodel.HELD_SIZE * 0.5
	var dev := 0.0
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				var corner := gg * Vector3(sx * hh, sy * hh, sz * hh)
				var mine := _lens_px(p.camera, corner, proc)
				var engine := p.camera.unproject_position(corner)
				dev = maxf(dev, maxf(absf(mine.x - engine.x), absf(mine.y - engine.y)))
	_check("projecao da suite bate com a do motor", dev < 0.01,
		"desvio=%.5f px no quadro %dx%d" % [dev, int(proc.x), int(proc.y)])
	# repouso de verdade antes de medir enquadramento e arcos: a lavra do passo
	# acima deixou _dig em 1, e no ciclo de picareta o braco esta erguido — o
	# quadro medido ali nao seria o do punho parado, nem o do soco sozinho
	vm.mining = false
	for i in 20:
		vm.advance(1.0 / 60.0)
	_check("bloco na mao == slot selecionado", vm.block_id == p.selected_block(),
		"vm=%d  mao=%d" % [vm.block_id, p.selected_block()])
	var fr := _vm_frame(p.camera, vm.held_mesh())
	_check("cubo na mao dentro do quadro", _in_frame(fr, res),
		"quadro=%dx%d  cubo=%s" % [int(res.x), int(res.y), _fmt_frame(fr)])
	_check("cubo no quadrante inferior direito, mira livre", fr.size() == 4
		and fr[0] > res.x * 0.5 and fr[1] > res.y * 0.5,
		"cubo=%s  mira=(%d,%d)" % [_fmt_frame(fr), int(res.x * 0.5), int(res.y * 0.5)])
	_check("membro inteiro desenhado sobre o mundo",
		_mesh_count_no_depth(p.viewmodel) == vm_fp,
		"sem depth test=%d de %d" % [_mesh_count_no_depth(p.viewmodel), vm_fp])

	# Os dois arcos, medidos no eixo que a lente ve. O de golpe sai do repouso,
	# arma com o cotovelo dobrado e corta para dentro; o de lavra e o ciclo
	# continuo enquanto o botao esta pressionado. Nenhum dos dois pode empurrar
	# o cubo para fora do quadro — a primeira versao jogava o bloco pela borda
	# de cima, e contagem de malhas nao percebe isso.
	var ang0 := vm.arm_angles()
	var arc := _vm_arc(vm, p.camera, res, 24, true)
	_check("golpe mexe o ombro", arc[1] - arc[0] > 0.30,
		"ombro repouso=%.2f  %.2f..%.2f rad" % [ang0.x, arc[0], arc[1]])
	_check("cubo do golpe sempre no quadro", int(arc[2]) == 0,
		"ticks fora=%d de 24" % int(arc[2]))
	arc = _vm_arc(vm, p.camera, res, 60, false)
	_check("lavra mexe o ombro", arc[1] - arc[0] > 0.35,
		"ombro %.2f..%.2f rad" % [arc[0], arc[1]])
	_check("cubo da lavra sempre no quadro", int(arc[2]) == 0,
		"ticks fora=%d de 60" % int(arc[2]))
	vm.mining = false
	for i in 20:
		vm.advance(1.0 / 60.0)

	# pilha sem bloco = punho closed: o cubo some, o braco fica
	vm.block_id = BlockDefs.Block.AIR
	vm.advance(1.0 / 60.0)
	_check("sem bloco = mao vazia", not vm.held_mesh().visible
		and _vm_frame(p.camera, vm.held_mesh()).is_empty(), "bloco=%d" % vm.block_id)
	vm.block_id = p.selected_block()
	vm.advance(1.0 / 60.0)

	# O corpo de 3a pessoa carrega o bloco da tecla ativa, e a pose do braco
	# direito, o ciclo de lavra e o de golpe mudam com a dureza do que ele segura.
	_check_held_tp(p)

	# Colocar exige o pipeline real de input: a borda do clique nasce em `_input` e
	# vira bloco no tick seguinte. Minerar pode continuar sintetico porque le o
	# nivel da acao, nao a borda. O mundo segue congelado e o clique arma a maquina
	# de espera: a assercao vive em _check_place.
	_aim(p, -0.9)
	_place_voxel = p.place_voxel
	_place_sel = p.selected_block()
	_place_n0 = p.inv.selected_count()
	_place0 = int(main.stats["placed"])
	print("       alvo do place: valid=%s  voxel=%s  place=%s  pos=%s  bloco=%d  pilha=%d"
		% [p.target_valid, p.target_voxel, _place_voxel, p.body.feet_pos, _place_sel, _place_n0])
	_arm_click(true)

	# kit: a hotbar de antes (7 blocos infinitos) sao os mesmos blocos com
	# quantidade, mais os dois slots de craft que comecam a 0 de proposito
	_check("tecla 1 comeca no capim com 32",
		p.inv.slot_block(p.inv.pin_of(0)) == BlockDefs.Block.GRASS
			and p.inv.slot_count(p.inv.pin_of(0)) == 32,
		"bloco=%d  qtd=%d  slots=%d" % [p.inv.slot_block(p.inv.pin_of(0)),
			p.inv.slot_count(p.inv.pin_of(0)), Inventory.SLOTS])
	_check("hotbar tem 10 teclas pinadas nos slots",
		Inventory.HOTBAR == 10 and p.inv.pin_of(9) == 9 and p.inv.pin_of(0) == 0,
		"pino9=%d  pino0=%d" % [p.inv.pin_of(9), p.inv.pin_of(0)])
	_check("pilha maxima vem do registro",
		BlockDefs.stack_max(BlockDefs.Block.GRASS) == 64
			and BlockDefs.stack_max(BlockDefs.Block.BENCH) == 16,
		"grama=%d  bancada=%d" % [BlockDefs.stack_max(BlockDefs.Block.GRASS),
			BlockDefs.stack_max(BlockDefs.Block.BENCH)])

	var ray := w.ray_voxel(p.eye_position(), Vector3(0.0, -1.0, 0.0), 8.0)
	_check("raycast DDA acerta o chao", ray.valid and ray.distance < 3.0,
		"dist=%.2f  voxel=%s" % [ray.distance, ray.voxel])
	var diag := w.ray_voxel(p.eye_position(), Vector3(0.0, -0.6, -0.8), Player.REACH)
	_check("raycast DDA em raio inclinado", diag.valid,
		"dist=%.2f  voxel=%s" % [diag.distance, diag.voxel])
	_check("linha de visada curta e limpa",
		w.line_of_sight(p.eye_position(), p.eye_position() + Vector3(0.0, 3.0, 0.0)))


## Posicao do cubo na mao direita no quadro do proprio corpo: +x = lado direito,
## -z = para onde o personagem olha, y acima dos pes. E o que a orbita ve, sem o
## yaw do jogador no meio da conta.
func _held_local(p: Player) -> Vector3:
	return p.avatar.global_transform.affine_inverse() * p.avatar.held_mesh().global_position


## Rect projetado na moldura pelos oito cantos do AABB de uma malha. Cantos
## atras da lente saem da conta: sem isso o rect explode e a medida vira ruido.
func _proj_rect(cam: Camera3D, mi: MeshInstance3D) -> Rect2:
	var r := Rect2()
	var seen := false
	var ab: AABB = mi.mesh.get_aabb()
	for sx in [ab.position.x, ab.end.x]:
		for sy in [ab.position.y, ab.end.y]:
			for sz in [ab.position.z, ab.end.z]:
				var wp := mi.global_transform * Vector3(sx, sy, sz)
				if (cam.global_transform.affine_inverse() * wp).z >= -0.05:
					continue
				var sp := cam.unproject_position(wp)
				r = r.expand(sp) if seen else Rect2(sp, Vector2.ZERO)
				seen = true
	return r


## Fracao do cubo na mao que nenhum corpo mais proximo da camera cobre, medida
## numa malha 8x8 de pontos dentro do rect projetado do cubo. E a medida do
## defeito que a geometria sozinha nao via: o cubo correto no espaco do corpo
## podia cair inteiro atras do punho e no quadro nao havia bloco nenhum. A
## profundidade entra na conta porque o rect projetado nao diz quem esta na
## frente -- sem ela a pose velha media 0,43 de "livre" e a checagem passava
## justamente no quadro quebrado. Os dois bracos, com esta medicao e com o olho
## (sonda de pixel em janela real): 0,02 e 0,00 contra 0,062 e 0,019 na pose
## velha; 0,45 e 0,30 contra 0,405 e 0,294 na pose atual.
func _held_free(av: PlayerAvatar, cam: Camera3D) -> float:
	var cube := av.held_mesh()
	var cr := _proj_rect(cam, cube)
	if cr.size.x <= 1.0 or cr.size.y <= 1.0:
		return 0.0
	var cd := _view_depth(cam, cube)
	var nearer: Array[Rect2] = []
	for mi: MeshInstance3D in av.find_children("*", "MeshInstance3D", true, false):
		if mi == cube or not mi.visible:
			continue
		if _view_depth(cam, mi) >= cd:
			continue
		var mr := _proj_rect(cam, mi)
		if mr.size.x <= 1.0 or mr.size.y <= 1.0:
			continue
		nearer.append(mr)
	if nearer.is_empty():
		return 1.0
	var n := 0
	var free := 0
	for iy in 8:
		for ix in 8:
			var pt := Vector2(cr.position.x + cr.size.x * (float(ix) + 0.5) / 8.0,
				cr.position.y + cr.size.y * (float(iy) + 0.5) / 8.0)
			n += 1
			var covered := false
			for r in nearer:
				if r.has_point(pt):
					covered = true
					break
			if not covered:
				free += 1
	return float(free) / float(maxi(n, 1))


## Distancia da camera ao centro do AABB da malha, no espaco da lente. Menor =
## mais perto do olho, entao e ela que tapa a outra.
func _view_depth(cam: Camera3D, mi: MeshInstance3D) -> float:
	var c := cam.global_transform.affine_inverse() \
		* (mi.global_transform * mi.mesh.get_aabb().get_center())
	return -c.z


## Periodo (em frames de 1/60) e amplitude (rad) do ciclo de lavra do rig. O
## campo `mining` e escrito na fronteira do rig -- a linha que `_update_avatar`
## escreve no Player -- porque os dois ciclos precisam da MESMA pose de partida
## sem quebrar dois blocos no mundo: aqui se mede a resposta do corpo, nao a da
## lavra. Amplitude abaixo do ciclo cheio nao engana o periodo, que e a distancia
## entre topos. Devolve periodo -1 se o segundo topo nunca chegou.
func _avatar_cycle(av: PlayerAvatar, ticks: int) -> Array:
	av.mining = true
	var lo := 999.0
	var hi := -999.0
	var prev := av.arm_angles().x
	var rising := false
	var tops := 0
	var first := -1
	var second := -1
	for i in ticks:
		av.advance(1.0 / 60.0)
		var cur := av.arm_angles().x
		lo = minf(lo, cur)
		hi = maxf(hi, cur)
		if cur > prev:
			rising = true
		elif rising:
			tops += 1
			if tops == 1:
				first = i
			elif tops == 2:
				second = i
			rising = false
			if second >= 0:
				break
		prev = cur
	av.mining = false
	for i in 60:
		av.advance(1.0 / 60.0)
	return [float(second - first) if second >= 0 else -1.0, hi - lo]


## Amplitude do golpe no rig: o impulso inteiro dura 1/2,8 s, entao 26 frames de
## 1/60 cobrem armao, corte e volta; os 40 seguintes devolvem o braco ao repouso.
func _avatar_swing_span(av: PlayerAvatar) -> float:
	av.swing()
	var lo := 999.0
	var hi := -999.0
	for i in 26:
		av.advance(1.0 / 60.0)
		var a := av.arm_angles().x
		lo = minf(lo, a)
		hi = maxf(hi, a)
	for i in 40:
		av.advance(1.0 / 60.0)
	return hi - lo


## O que a mao direita do rig de 3a pessoa segura muda o corpo inteiro. Blocos
## escolhidos pela tecla da hotbar (caminho real), durezas lidas do registro:
## pedra 0,95 = carga cheia, folha 0,22 = carga leve, vidro 0,10 = o ramo ALPHA.
func _check_held_tp(p: Player) -> void:
	var av: PlayerAvatar = p.avatar
	p.third_person = true
	# A orbita de atras so existe com o olhar neutro: o yaw deixado pelo passo
	# anterior gira a lente para o lado e a oclusao passa a valer para um angulo
	# que o jogo nao mostra -- foi assim que a pose velha deu 0,75 de "livre" no
	# quadro de tras-reto, onde o olho mede 0,02.
	p.yaw = 0.0
	p.pitch = 0.0
	p.select_slot(2)
	for i in 30:
		p.update_local(1.0 / 60.0)
	var heavy := av.arm_angles()
	var heavy_pos := _held_local(p)
	var heavy_free := _held_free(av, p.camera)
	var cube := av.held_mesh()
	var cube_mesh: ArrayMesh = cube.mesh as ArrayMesh
	var tex := cube.material_override as StandardMaterial3D
	_check("cubo na mao do avatar == slot selecionado",
		av.block_id == p.selected_block() and cube.visible
			and av.block_id == BlockDefs.Block.STONE,
		"avatar=%d  slot=%d  name=%s" % [av.block_id, p.selected_block(),
			BlockDefs.display_name(av.block_id)])
	_check("cubo do rig amostra o atlas do mundo no tamanho da orbita",
		tex != null and tex.albedo_texture == p.world.atlas_texture()
			and cube_mesh != null
			and absf(cube_mesh.get_aabb().size.x - PlayerAvatar.HELD_SIZE) < 0.001,
		"atlas=%s  lado=%.3f (esperado %.2f, 1a pessoa usa %.2f)" % [
			str(tex.albedo_texture != null), cube_mesh.get_aabb().size.x,
			PlayerAvatar.HELD_SIZE, FPViewmodel.HELD_SIZE])
	p.select_slot(6)
	for i in 30:
		p.update_local(1.0 / 60.0)
	var light := av.arm_angles()
	var light_pos := _held_local(p)
	var light_free := _held_free(av, p.camera)
	_check("cubo na lateral direita, a frente do tronco",
		heavy_pos.x > 0.24 and light_pos.x > 0.24 and heavy_pos.z < -0.05
			and light_pos.z < -0.05,
		"pedra=(%.2f,%.2f,%.2f)  folha=(%.2f,%.2f,%.2f)" % [heavy_pos.x, heavy_pos.y,
			heavy_pos.z, light_pos.x, light_pos.y, light_pos.z])
	_check("cubo acima do joelho e abaixo da cabeca",
		heavy_pos.y > 0.40 and heavy_pos.y < 1.50 and light_pos.y > 0.40
			and light_pos.y < 1.50, "pedra y=%.2f  folha y=%.2f" % [heavy_pos.y, light_pos.y])
	# A premissa que a pose tinha e nao estava segura: no quadro em que a orbita
	# mora -- atras do personagem -- o cubo nao pode cair inteiro atras do proprio
	# braco. Sem abertura do ombro e com o 0,16 da lente ele caia 100% coberto.
	# O corte de 0,15 nao e adjetivo: a pose velha deu 0,02 e 0,00 aqui, a atual
	# da 0,45 e 0,30, e o pior braco ainda fica duas vezes acima do minimo.
	_check("bloco na mao passa para fora do braco no quadro da orbita",
		heavy_free > 0.15 and light_free > 0.15,
		"livre pedra=%.2f  folha=%.2f" % [heavy_free, light_free])
	_check("peso do bloco muda a pose do braco",
		heavy.x < light.x - 0.15 and heavy.y < light.y - 0.60
			and light_pos.y > heavy_pos.y + 0.25,
		"ombro pedra=%.2f folha=%.2f  cotovelo pedra=%.2f folha=%.2f  cubo y %.2f->%.2f"
			% [heavy.x, light.x, heavy.y, light.y, heavy_pos.y, light_pos.y])

	# os dois ciclos de lavra: mesma pose de partida, carga diferente na mao
	p.select_slot(6)
	for i in 30:
		p.update_local(1.0 / 60.0)
	var leaf_cycle: Array = _avatar_cycle(av, 240)
	p.select_slot(2)
	for i in 30:
		p.update_local(1.0 / 60.0)
	var stone_cycle: Array = _avatar_cycle(av, 320)
	_check("ciclo de lavra do rig mexe o ombro",
		float(leaf_cycle[0]) > 0.0 and float(leaf_cycle[1]) > 0.35,
		"periodo=%.0f frames  amplitude=%.2f rad" % [leaf_cycle[0], leaf_cycle[1]])
	_check("pedra lavra mais funda e mais lenta que folha",
		float(stone_cycle[0]) > float(leaf_cycle[0]) * 1.4
			and float(stone_cycle[1]) > float(leaf_cycle[1]) * 1.15,
		"periodo folha=%.0f pedra=%.0f  amplitude folha=%.2f pedra=%.2f"
			% [leaf_cycle[0], stone_cycle[0], leaf_cycle[1], stone_cycle[1]])

	# golpe: o mesmo arco, mais fundo com a carga
	var swing_stone := _avatar_swing_span(av)
	p.select_slot(6)
	for i in 30:
		p.update_local(1.0 / 60.0)
	var swing_leaf := _avatar_swing_span(av)

	# mao vazia pelo caminho do jogo: a pilha gasta em `consume_selected` (o mesmo
	# que o place usa) e o cubo tem que sair de cena junto do `selected_block()`.
	var slot := p.inv.selected_slot()
	var had := p.inv.slot_count(slot)
	var was := p.inv.slot_block(slot)
	p.inv.consume_selected(had)
	for i in 40:
		p.update_local(1.0 / 60.0)
	var empty := av.arm_angles()
	_check("pilha zerada = mao vazia no rig",
		av.block_id == BlockDefs.Block.AIR and not av.held_mesh().visible,
		"bloco=%d  visivel=%s  pilha=%d->0" % [av.block_id, str(av.held_mesh().visible), had])
	_check("mao vazia devolve o braco ao repouso", empty.y < 0.35 and empty.y > 0.05,
		"cotovelo vazio=%.2f  folha=%.2f  pedra=%.2f" % [empty.y, light.y, heavy.y])
	var swing_empty := _avatar_swing_span(av)
	p.inv.add(was, had)
	p.select_slot(0)
	for i in 30:
		p.update_local(1.0 / 60.0)
	_check("golpe com pedra vai mais fundo que sem carga",
		swing_stone > swing_empty + 0.15 and swing_stone > swing_leaf + 0.05,
		"ombro pedra=%.2f folha=%.2f vazio=%.2f rad" % [swing_stone, swing_leaf, swing_empty])

	# o ramo ALPHA do material: vidro entra pelo caminho real da pilha e sai por
	# `take` depois. Na 1a pessoa este foi o defeito documentado (o cubo virava
	# painel leitoso); na 3a o cubo transparente tem que usar o MESMO material.
	p.inv.add(BlockDefs.Block.GLASS, 2)
	var key := -1
	for k in Inventory.HOTBAR:
		if p.inv.slot_block(p.inv.pin_of(k)) == BlockDefs.Block.GLASS:
			key = k
	if key >= 0:
		p.select_slot(key)
		for i in 30:
			p.update_local(1.0 / 60.0)
	var gm := av.held_mesh().material_override as StandardMaterial3D
	_check("vidro na mao do rig usa o material alpha",
		key >= 0 and gm != null and gm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
			and av.block_id == BlockDefs.Block.GLASS,
		"tecla=%d  bloco=%d  transparency=%d  classe=%d" % [key, av.block_id,
			gm.transparency if gm != null else -1,
			BlockDefs.draw_of(BlockDefs.Block.GLASS)])
	p.inv.take(BlockDefs.Block.GLASS, 2)
	p.select_slot(0)
	for i in 30:
		p.update_local(1.0 / 60.0)
	p.third_person = false
	for i in 10:
		p.update_local(1.0 / 60.0)


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
	# A quantidade e o preco de colocar: sem o decremento o bloco seria criativo.
	var p: Player = main.player
	_check("colocar gastou um da pilha",
		_click_frame > 0 and p.inv.selected_count() == _place_n0 - 1,
		"pilha=%d->%d  bloco=%d" % [_place_n0, p.inv.selected_count(), _place_sel])
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
	_check("tecla 3 troca o pino", p.inv.hotbar_index == 2,
		"slot=%d  acao lida=%s  bloco=%d" % [p.inv.hotbar_index, read, p.selected_block()])
	# A tecla nao e um deposito proprio: ela aponta para um slot, e o que muda e a
	# leitura. O bloco lido tem que ser o do slot 2 com a quantidade do slot 2.
	_check("tecla 3 mostra o bloco do slot 2",
		p.inv.pin_of(2) == 2 and p.selected_block() == p.inv.slot_block(2)
			and p.inv.selected_count() == p.inv.slot_count(2),
		"pino2=%d  selected=%d  qtd=%d" % [p.inv.pin_of(2), p.selected_block(), p.inv.selected_count()])
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


# ------------------------------------------------------------------ inventario

## Logica pura de pilha e de receita sobre um Inventory novo: nao depende do
## mundo, dos lobos nem do relogio, entao as regras que o jogador pediu
## (quantidade, teto por bloco, mesclar, partir, craft) sao medidas sem o ruido de
## uma simulacao rodando. O inventario do jogador fica intacto.
func _check_items() -> void:
	var inv := Inventory.new()
	var dirt := BlockDefs.Block.DIRT
	var grass := BlockDefs.Block.GRASS
	var sand := BlockDefs.Block.SAND
	var snow := BlockDefs.Block.SNOW
	var wood := BlockDefs.Block.WOOD
	var leaves := BlockDefs.Block.LEAVES
	var cobble := BlockDefs.Block.COBBLESTONE
	var plank := BlockDefs.Block.PLANK
	var bench := BlockDefs.Block.BENCH
	var stone := BlockDefs.Block.STONE
	var glass := BlockDefs.Block.GLASS

	# kit: os mesmos blocos da hotbar de 7, agora com numero, e os dois slots de
	# craft comecando vazios de proposito
	_check("kit = hotbar antiga com quantidade",
		inv.count_of(grass) == 32 and inv.count_of(wood) == 8
			and inv.count_of(plank) == 0 and inv.count_of(bench) == 0,
		"grama=%d  madeira=%d  tabua=%d  bancada=%d"
			% [inv.count_of(grass), inv.count_of(wood), inv.count_of(plank), inv.count_of(bench)])

	# teto por pilha vem do registro, e um bloco pode ter teto proprio
	inv.reset_default()
	var left_bench := inv.add(bench, 100)
	var max_bench := 0
	for i in Inventory.SLOTS:
		if inv.slot_block(i) == bench:
			max_bench = maxi(max_bench, inv.slot_count(i))
	_check("bancada tem teto menor que bloco comun",
		BlockDefs.stack_max(bench) == 16 and left_bench == 0
			and max_bench == 16 and inv.count_of(bench) == 100,
		"maior pilha=%d  total=%d  sobra=%d" % [max_bench, inv.count_of(bench), left_bench])
	inv.reset_default()
	var left_dirt := inv.add(dirt, 400)
	var max_dirt := 0
	for i in Inventory.SLOTS:
		if inv.slot_block(i) == dirt:
			max_dirt = maxi(max_dirt, inv.slot_count(i))
	_check("400 de terra viram 64 em cada slot",
		BlockDefs.stack_max(dirt) == 64 and left_dirt == 0 and max_dirt == 64,
		"maior pilha=%d  total=%d" % [max_dirt, inv.count_of(dirt)])

	# inventario cheio: o que nao coube volta, e o que nao tem buraco nao entra
	inv.reset_default()
	var kit_stone := inv.count_of(stone)
	var left_stone := inv.add(stone, 100000)
	var acima := 0
	for i in Inventory.SLOTS:
		if inv.slot_block(i) != BlockDefs.Block.AIR and inv.slot_block(i) == stone:
			if inv.slot_count(i) > BlockDefs.stack_max(stone):
				acima += 1
	_check("cheio devolve a sobra e nao cria pilha fora do teto",
		left_stone > 0 and inv.count_of(stone) == kit_stone + 100000 - left_stone
			and inv.space_for(stone) == 0 and acima == 0,
		"total=%d  esperado=%d  kit=%d  sobrou=%d  espaco=%d  acima do teto=%d"
			% [inv.count_of(stone), kit_stone + 100000 - left_stone, kit_stone,
				left_stone, inv.space_for(stone), acima])
	_check("bloco sem pilha nenhuma nao entra em lugar nenhum",
		inv.add(glass, 1) == 1 and inv.count_of(glass) == 0,
		"espaco p/ vidro=%d" % inv.space_for(glass))

	# coleta do Veloren: enche TODA pilha parcial antes de abrir a primeira vazia
	inv.reset_default()
	inv.take(sand, 6)
	var left_sand := inv.add(sand, 100)
	_check("enche a pilha parcial ate o teto antes da vazia",
		inv.slot_count(3) == 64 and inv.slot_block(7) == sand and inv.slot_count(7) == 46
			and left_sand == 0,
		"slot3=%d  slot7=%d:%d" % [inv.slot_count(3), inv.slot_block(7), inv.slot_count(7)])
	_check("tirar esvazia de tras para frente",
		inv.take(sand, 50) == 50 and inv.slot_count(7) == 0 and inv.slot_count(3) == 60,
		"slot3=%d  slot7=%d" % [inv.slot_count(3), inv.slot_count(7)])

	# partir = metade por divisao inteira, e a mao precisa estar vazia
	inv.reset_default()
	_check("partir da metade inteira para a mao",
		inv.split(0) and inv.held_count == 16 and inv.slot_count(0) == 16,
		"mao=%d  slot0=%d" % [inv.held_count, inv.slot_count(0)])
	_check("mao ocupada nao parte outra pilha", not inv.split(1))
	_check("guardar a mao devolve para a mesma pilha",
		inv.stash_hand() and inv.held_count == 0 and inv.slot_count(0) == 32,
		"slot0=%d  mao=%d" % [inv.slot_count(0), inv.held_count])
	inv.take(grass, 31)
	_check("pilha de 1 nao parte", not inv.split(0) and inv.held_count == 0,
		"slot0=%d" % inv.slot_count(0))

	# pegar/soltar: pilha inteira para cima, mesclar se for o mesmo bloco e couber,
	# senao trocar (inventory_manip.rs:814)
	inv.reset_default()
	_check("pegar sobe a pilha inteira",
		inv.pick_drop(0) and inv.held_count == 32 and inv.held_id == grass
			and inv.slot_count(0) == 0,
		"mao=%d  slot0=%d" % [inv.held_count, inv.slot_count(0)])
	_check("soltar em buraco desce tudo",
		inv.pick_drop(0) and inv.held_count == 0 and inv.slot_block(0) == grass
			and inv.slot_count(0) == 32, "slot0=%d" % inv.slot_count(0))
	_check("mesmo bloco mescla ate o teto e o resto fica na mao",
		inv.pick_drop(0) and inv.add(grass, 40) == 0 and inv.slot_count(0) == 40
			and inv.pick_drop(0) and inv.slot_count(0) == 64 and inv.held_count == 8,
		"slot0=%d  mao=%d" % [inv.slot_count(0), inv.held_count])
	_check("bloco diferente troca",
		inv.pick_drop(1) and inv.slot_block(1) == grass and inv.held_id == dirt
			and inv.held_count == 32,
		"slot1=%d  mao=%d:%d" % [inv.slot_block(1), inv.held_id, inv.held_count])
	_check("guardar antes de fechar o painel devolve a mao",
		inv.stash_hand() and inv.held_count == 0, "slot0=%d" % inv.slot_count(0))

	# hotbar = dez pinos sobre os proprios slots: a tecla muda a leitura, nunca a
	# pilha
	inv.reset_default()
	inv.select(3)
	_check("pino aponta para outro slot sem mover pilha",
		inv.pin(3, 6) and inv.selected_slot() == 6 and inv.selected_block() == leaves
			and inv.selected_count() == 8 and inv.slot_count(3) == 16,
		"slot=%d  bloco=%d  qtd=%d  areia slot3=%d"
			% [inv.selected_slot(), inv.selected_block(), inv.selected_count(), inv.slot_count(3)])
	inv.select(12)
	_check("tecla depois da decima da a volta na hotbar", inv.hotbar_index == 2,
		"sel=%d" % inv.hotbar_index)

	# receitas: lista, nao grade. Estacao filtra; insumo e espaco de saida sao
	# portao antes de qualquer consumo.
	var plank_r := _recipe_for(plank)
	var bench_r := _recipe_for(bench)
	var stone_r := _recipe_for(stone)
	var hand_n := 0
	for r in Recipes.list():
		if int(r["station"]) == Recipes.Station.HAND:
			hand_n += 1
	_check("sem bancada a lista so mostra as de mao",
		Recipes.visible(false).size() == hand_n
			and Recipes.visible(true).size() == Recipes.list().size(),
		"mao=%d  com bancada=%d  total=%d"
			% [Recipes.visible(false).size(), Recipes.visible(true).size(), Recipes.list().size()])
	inv.reset_default()
	_check("1 madeira -> 4 tabuas, com o preco cobrado",
		Recipes.can_craft(plank_r, inv) and Recipes.craft(plank_r, inv)
			and inv.count_of(plank) == 4 and inv.count_of(wood) == 7,
		"tabua=%d  madeira=%d" % [inv.count_of(plank), inv.count_of(wood)])
	_check("a cadeia ate a bancada fecha",
		Recipes.can_craft(bench_r, inv) and Recipes.craft(bench_r, inv)
			and inv.count_of(bench) == 1 and inv.count_of(plank) == 0,
		"bancada=%d  tabua=%d" % [inv.count_of(bench), inv.count_of(plank)])
	_check("receita sem insumo nao abre", not Recipes.can_craft(stone_r, inv),
		"bruta=%d" % inv.count_of(cobble))

	# o espaco de saida tambem e preco: sem ele o craft nao comeca, porque nao ha
	# como desfazer um craft meio-aplicado
	var inv2 := Inventory.new()
	inv2.take(stone, 99)
	_check("sobra 4 de bruta e entope o resto",
		inv2.add(cobble, 4) == 0 and inv2.add(snow, 100000) > 0
			and inv2.count_of(cobble) == 4 and inv2.space_for(stone) == 0,
		"bruta=%d  espaco p/ pedra=%d" % [inv2.count_of(cobble), inv2.space_for(stone)])
	_check("craft recusado nao toca em nada",
		not Recipes.craft(stone_r, inv2) and inv2.count_of(cobble) == 4
			and inv2.count_of(stone) == 0,
		"bruta=%d  pedra=%d" % [inv2.count_of(cobble), inv2.count_of(stone)])
	inv2.take(dirt, 99)
	_check("aberto um buraco o mesmo craft passa",
		Recipes.can_craft(stone_r, inv2) and Recipes.craft(stone_r, inv2)
			and inv2.count_of(stone) == 1 and inv2.count_of(cobble) == 0,
		"pedra=%d  bruta=%d" % [inv2.count_of(stone), inv2.count_of(cobble)])
	_check("vidro na bancada come 2 de areia",
		Recipes.can_craft(_recipe_for(glass), inv2)
			and Recipes.craft(_recipe_for(glass), inv2)
			and inv2.count_of(glass) == 1 and inv2.count_of(sand) == 14,
		"areia=%d  vidro=%d" % [inv2.count_of(sand), inv2.count_of(glass)])


func _recipe_for(out: int) -> Dictionary:
	for r in Recipes.list():
		if int(r["out"]) == out:
			return r
	return {}


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


## Passo cujo alvo e "um lobo VIVO" escolhe por aqui, em ordem de indice, e nao
## por numero fixo. `targets_under_crosshair` so devolve vivos e o corpo fica na
## matriz ate a faina de recolher, entao um indice caido aqui e mira sem alvo --
## sintoma que forcar `main.wolves[2].die()` reproduziu linha por linha. Nao foi
## o que a corrida natural tinha (abatidos=1, ou seja, nenhum lobo morto ainda),
## mas era um buraco do mesmo tamanho parado no caminho.
func _alive_wolf() -> Wolf:
	for w in main.wolves:
		if (w as Wolf).alive:
			return w
	return null


## Distancia do lobo vivo mais proximo do olho que nao seja o alvo do passo;
## -1 quando a matilha inteira se resumiu a ele. E o numero que diz se o golpe
## poderia cair em outro corpo.
func _nearest_other_alive(p: Player, w: Wolf) -> float:
	var best := -1.0
	for other in main.wolves:
		if other == w or not (other as Wolf).alive:
			continue
		var d: float = (other as Wolf).body.feet_pos.distance_to(p.eye_position())
		if best < 0.0 or d < best:
			best = d
	return best


## Golpe unificado (botao esquerdo): entidade primeiro, bloco depois. No lobo o
## golpe e dano fixo + atordoamento (steering suspenso) + empurrada no corpo.
func _check_attack() -> void:
	var p: Player = main.player
	var w: Wolf = _alive_wolf()
	if w == null:
		_check("ha um lobo vivo para o golpe", false, "matilha=%d" % main.wolves.size())
		return
	_pause_for(p)
	p.hp = p.max_hp
	p.energy = p.max_energy
	# A premissa do passo e "jogador vivo, sem painel na frente, braco livre".
	# Os tres sao estado que a simulacao ao vivo deixa pelo caminho, e cada um
	# engole o clique: `update_local` retorna antes de mirar se o jogador caiu,
	# `_apply_actions` retorna se o painel esta aberto, e a cadencia de 0,42 s
	# adia o giro. Sem montar a premissa o passo mede a sorte -- a primeira
	# corrida de um clone limpo desta arvore deu 4 falhas com `em 30 ticks` e a
	# segunda, nada mudado, deu 0. `chegada` e o estado herdado, para a proxima
	# falha ja nascer explicada.
	var chegada := "vivo=%s painel=%s cad=%.2f" % [str(p.alive), str(p.panel_open),
			p._attack_cd]
	# Cada porta e fechada pela transicao do proprio jogo, nao por um campo
	# escrito a mao: `respawn_at` devolve hp, vigor, ar e o travamento de sprint
	# junto com `alive`, e `close_panel` so fecha se a pilha na mao tiver para
	# onde voltar -- forcar `panel_open = false` ali deixaria o painel visivel no
	# HUD com o jogador ja livre, estado que nenhum passo seguinte espera.
	if not p.alive:
		p.respawn_at(_spawn)
	if p.panel_open:
		p.close_panel()
	p._attack_cd = 0.0
	p.feet_to_spawn(_spawn)
	_aim(p, -0.35)
	w.hp = Wolf.MAX_HP
	w.body.feet_pos = _spawn + Vector3(0.0, 0.0, -2.5)
	w.body.velocity = Vector3.ZERO
	w._move_target = w.body.feet_pos
	# O resto da matilha sai da frente da mira. Com a arvore pausada os lobos
	# congelam onde a simulacao ao vivo os deixou, e a janela de 280 ticks do
	# passo de nado acaba com eles caçando o jogador: medido no clone de
	# 88d1c19, um lobo vivo a 1,6 m do olho contra 3,0 m do alvo colocado -- o
	# que salvou o golpe foi ele nao estar sobre o raio, por sorte. Como
	# `_update_target` pega o mais proximo ao longo da mira (`dp < best_d`),
	# sem isto o passo mediria a IA em vez do golpe, e vermelho intermitente
	# seria a assinatura: `hp` do alvo intacto, stagger 0, velocidade 0.
	for other in main.wolves:
		if other != w:
			other.body.feet_pos = _spawn + Vector3(0.0, 1.0, 8.0)
			other.body.velocity = Vector3.ZERO
	Input.action_press("break_block")
	p.update_local(1.0 / 60.0)
	_check("mira travada no lobo do passo", p._target_entity == w,
		("alvo=%s na_lista=%s d_alvo=%.2f  rival_mais_proximo=%.2f m") % [
			str(p._target_entity != null),
			str(main.targets_under_crosshair().has(w)),
			w.body.feet_pos.distance_to(p.eye_position()),
			_nearest_other_alive(p, w)])
	var n := 1
	while absf(w.hp - Wolf.MAX_HP) < 0.01 and n < 30:
		p.update_local(1.0 / 60.0)
		n += 1
	Input.action_release("break_block")
	_check("golpe acertou o lobo", absf(w.hp - Wolf.MAX_HP) > 5.0,
		("hp %.0f -> %.1f em %d ticks  chegada[%s]  alvo=%s  olho_a_alvo=%.2f m") % [
			Wolf.MAX_HP, w.hp, n, chegada,
			str(p._target_entity != null),
			p.eye_position().distance_to(w.body.feet_pos)])
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
	_check("hotbar com 10 pinos no hud", hud._slots.size() == Inventory.HOTBAR,
		"slots=%d" % hud._slots.size())
	_check("painel com 36 celulas", hud._cells.size() == Inventory.SLOTS \
		and Inventory.ROWS * Inventory.COLS == Inventory.SLOTS,
		"celulas=%d" % hud._cells.size())
	# O painel abre por sinal do jogador, nao por decisao do HUD: quem abre e o
	# `toggle_inventory` do Player, o HUD so empresta a visibilidade.
	p._set_panel(true)
	_check("abrir o inventario mostra o painel", hud.panel_visible() and p.panel_open)
	_check("cabecalho mostra a contagem real", String(hud._head_label.text).contains("INVENTARIO") \
		and String(hud._head_label.text).contains(str(p.inv.item_count())),
		"'%s'" % hud._head_label.text)
	_check("quantidade aparece na celula do slot",
		(hud._cells[0]["ct"] as Label).text == str(p.inv.slot_count(0)),
		"celula0='%s'  slot0=%d" % [(hud._cells[0]["ct"] as Label).text, p.inv.slot_count(0)])
	# Sem bancada por perto a lista encolhe: e o filtro por estacao do Veloren (o
	# sprite a 5,0 m) aplicado ao bloco de bancada.
	_check("sem bancada so mostra as receitas de mao", not p.bench_near() \
		and Recipes.visible(false).size() < Recipes.list().size() \
		and String(hud._head_label.text).contains("sem bancada"),
		"visiveis=%d de %d" % [Recipes.visible(false).size(), Recipes.list().size()])
	p._set_panel(false)
	_check("fechar o inventario esconde o painel", not hud.panel_visible() and not p.panel_open)
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
		"inv": _inv_signature(p), "items": p.inv.item_count(),
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
	# `inv` e aditivo no mesmo schema: um save antigo nao tem a chave e o load cai
	# no kit, um save novo tem as 36 pilhas, os 10 pinos e a tecla ativa.
	var inv_saved: Dictionary = data.get("inv", {})
	_check("save guarda as pilhas e os pinos",
		int(inv_saved.get("slots", []).size()) > 0 \
		and (inv_saved.get("pins", []) as Array).size() == Inventory.HOTBAR,
		"slots=%d  pins=%d" % [inv_saved.get("slots", []).size(),
			(inv_saved.get("pins", []) as Array).size()])
	main.save_game()
	_check("segunda escrita sobrescreve atomicamente", bool(SaveManager.read_slot(SLOT)["ok"]),
		"%d bytes" % bytes)

	var after_extra := Vector3i(30, w.surface_height(30, 30) + 4, 30)
	w.set_block(after_extra, BlockDefs.Block.SNOW)
	p.take_damage(20.0, Vector3.ZERO)
	wolf0.take_damage(10.0, Wolf.ACTOR_PLAYER, p.position3())
	p.feet_to_spawn(_spawn + Vector3(4.0, 0.0, 4.0))
	# Inventario mutado de proposito junto com o resto: gasta a pilha da tecla
	# ativa, recebe um bloco novo e troca de tecla. Nada disso voltaria se o load
	# ignorasse a chave `inv`.
	p.inv.consume_selected(3)
	p.inv.add(BlockDefs.Block.GLASS, 5)
	p.inv.select(6)
	_check("mundo foi mutado de proposito",
		w.edits.size() == before["edits"] + 1 and wolf0.hp != before["wolf_hp"],
		"edicoes=%d  hp lobo=%.1f" % [w.edits.size(), wolf0.hp])
	_check("inventario foi mutado de proposito",
		_inv_signature(p) != String(before["inv"]), "assinatura mudou")
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
	_check("inventario restaurado pilha por pilha",
		_inv_signature(p) == String(before["inv"]) and p.inv.item_count() == int(before["items"]),
		"itens=%d->%d" % [p.inv.item_count(), before["items"]])


## Assinatura das 36 pilhas, dos 10 pinos e da tecla ativa. Comparar a assinatura
## em vez de um total pega pilha movida e hotbar reordenada, que um `item_count`
## identico esconderia.
func _inv_signature(p: Player) -> String:
	var parts: Array = []
	for i in Inventory.SLOTS:
		parts.append("%d:%d" % [p.inv.slot_block(i), p.inv.slot_count(i)])
	for k in Inventory.HOTBAR:
		parts.append("p%d" % p.inv.pin_of(k))
	parts.append("s%d" % p.inv.hotbar_index)
	return ",".join(parts)


# --------------------------------------------------------------------- ciclo de vida

func _check_corpse() -> void:
	var w: Wolf = _alive_wolf()
	if w == null:
		_check("ha um lobo vivo para abater", false, "matilha=%d" % main.wolves.size())
		return
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
