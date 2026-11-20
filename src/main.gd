extends Node3D
## Sessao do slice: dona do mundo, do relogio de simulacao, do jogador local e das
## matilhas. Tudo o que a rede tera que autorizar depois ja passa por aqui, e so ha
## um caminho de escrita para o mundo.
##
## Dois relogios (docs/design/06.2): locomocao e camera a 60 Hz, decisao de IA,
## difusao do Eter e tick de simulacao a 20 Hz.

const WOLF_COUNT := 5
const SEED := 20261116
const SLOT := "alpha"
const AETHER_PERIOD := 0.25        # 4 passadas de difusao por segundo de logica
const MESH_BUDGET := 2             # chunks por frame
const VIZ_PERIOD := 0.25
const RESPAWN_DELAY := 45.0
const CORPSE_CHECK_PERIOD := 1.0
# Raio de coesao da matilha (dossie 10 §3.1): quem esta dentro disto e lido como
# vizinho. O teto e o horizonte do proprio lobo -- `_sense` so roda a LOS do
# jogador ate 30 m -- entao 24 m e um vizinho que o lobo poderia ver, com folga;
# um raio maior faria a alcateia coordenar bicho que esta fora do mundo
# percebido dele. O que este numero rende na sessao real de cinco lares nao e
# suposicao: a checagem "alcateia existe na sessao real" imprime os pares e o
# tamanho da matilha lida a cada corrida da suite.
const PACK_COHESION_RADIUS := 24.0
const EMPTY_PACK: Array = []
const Journal = preload("res://src/persistence/tick_journal.gd")

var tick_journal := Journal.new()

var world: VoxelWorld = null
var aether: AetherField = null
var clock: SimClock = null
var player: Player = null
var viz: AetherViz = null
var hud: Hud = null
var oracle: MindOracle = null
var audio: AudioDirector = null
var wolves: Array = []
var elapsed: float = 0.0
var stats := {"mined": 0, "placed": 0, "wolves_felled": 0, "deaths": 0}

var _terrain: Node3D = null
var _entities: Node3D = null
var _next_identity: int = 0
var _population_rng := RandomNumberGenerator.new()
var _respawn_queue: Array = []
var _aether_cd: float = AETHER_PERIOD
var _viz_cd: float = 0.0
var _corpse_cd: float = 0.0
var _gen_ms: float = 0.0
var _mesh_ms: float = 0.0
var _binds_on: bool = false
# Bancadas colocadas, em blocos. E a lista que o Veloren varreria por sprite
# proximo; o mundo nao e varrido porque a consulta roda a cada frame do painel.
var _benches: Array[Vector3i] = []
# Buffers da matilha (dossie 10 §4): um Array por identidade, com as entradas
# Dictionary reescritas no lugar a cada passo. A leitura e o preco que o contrato
# aceita -- construir cinco arrays novos por tick nao entraria.
var _pack_buffers: Dictionary = {}
var _pack_cursor: Dictionary = {}
# Comparacoes de par feitas no ultimo rebuild. E numero de gate, nao conversa: o
# dossie 10 §4 promete n(n-1)/2 por passo, e o rodape da suite prova isto no
# diagnostico JSON.
var _pack_pairs: int = 0


func _ready() -> void:
	InputActions.install()
	BlockDefs.init_tables()
	_terrain = Node3D.new()
	_terrain.name = "Terrain"
	add_child(_terrain)
	_entities = Node3D.new()
	_entities.name = "Entities"
	add_child(_entities)
	_build_environment()

	var t0 := Time.get_ticks_usec()
	world = VoxelWorld.new()
	world.setup_world(_terrain)
	world.generate(SEED)
	_gen_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	world.generate_meshes_all()
	_mesh_ms = float(Time.get_ticks_usec() - t0) / 1000.0

	aether = AetherField.new()
	aether.setup(world)
	clock = SimClock.new()

	viz = AetherViz.new()
	viz.setup(aether)
	add_child(viz)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.setup(world, spawn_point())
	player.entity_provider = Callable(self, "targets_under_crosshair")
	player.bench_provider = Callable(self, "bench_positions")
	player.block_broken.connect(_on_block_broken)
	player.block_placed.connect(_on_block_placed)
	player.acted.connect(_on_acted)
	player.attacked.connect(_on_attacked)
	player.damaged.connect(_on_damaged)
	player.died.connect(_on_player_died)
	player.toggle_debug.connect(_toggle_debug)
	player.toggle_ether.connect(_toggle_ether)
	player.request_save.connect(save_game)
	player.request_load.connect(load_game)
	player.notice.connect(_on_notice)
	player.panel_changed.connect(hud_panel_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	hud = Hud.new()
	hud.name = "Hud"
	hud.player = player
	hud.world = world
	hud.aether = aether
	hud.clock = clock
	hud.stats_provider = Callable(self, "stats_line")
	hud.wolf_provider = Callable(self, "targets_under_crosshair")
	add_child(hud)
	hud.build_hotbar()
	hud.show_message("vale reconstruido  seed %d" % SEED, 3.4)
	hud.preview_binds(7.0)

	oracle = MindOracle.new()
	oracle.name = "MindOracle"
	oracle.roster_provider = Callable(self, "wolves_roster")
	add_child(oracle)
	hud.narration_provider = Callable(oracle, "narration_of")

	# Ultimo a entrar e o primeiro a ser ouvido: so consome os sinais que ja
	# existiam, nao escreve mundo nem sorteia nas RNG da simulacao.
	audio = AudioDirector.new()
	audio.name = "Audio"
	audio.wolves_provider = Callable(self, "wolves_roster")
	add_child(audio)
	audio.setup(world, player)

	_spawn_wolves(WOLF_COUNT)
	_start_journal_from_args()


func spawn_point() -> Vector3:
	var x := int(VoxelConfig.world_size_x() * 0.5)
	var z := int(VoxelConfig.world_size_z() * 0.5)
	return Vector3(float(x) + 0.5, float(world.surface_height(x, z) + 1), float(z) + 0.5)


# ------------------------------------------------------------------ relogios

func _physics_process(delta: float) -> void:
	player.update_local(delta)
	var steps := clock.advance(delta)
	for i in steps:
		clock.begin_step()
		_sim_tick()
		clock.end_step()


func _sim_tick() -> void:
	var dt := clock.step_duration()
	elapsed += dt
	_aether_cd -= dt
	if _aether_cd <= 0.0:
		aether.diffuse_and_decay(AETHER_PERIOD)
		_aether_cd = AETHER_PERIOD
	_rebuild_packs()
	for w in wolves:
		w.sim_step(elapsed, dt)
	_corpse_cd -= dt
	if _corpse_cd <= 0.0:
		_corpse_cd = CORPSE_CHECK_PERIOD
		_reap_corpses()
	for i in range(_respawn_queue.size() - 1, -1, -1):
		_respawn_queue[i] -= dt
		if _respawn_queue[i] <= 0.0:
			_respawn_queue.remove_at(i)
			_spawn_wolves(1)
			hud.show_message("uma nova matilha entrou no vale")
	clock.tick += 1
	if tick_journal.active():
		var err := tick_journal.record(clock.tick, world, aether, wolves)
		if err != OK:
			tick_journal.close()
			push_error("journal tick %d: %s" % [clock.tick, error_string(err)])
			get_tree().quit(1)


func _process(delta: float) -> void:
	world.process(MESH_BUDGET)
	if viz.showing():
		_viz_cd -= delta
		if _viz_cd <= 0.0:
			_viz_cd = VIZ_PERIOD
			viz.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("respawn") and not player.alive:
		respawn()
	elif event.is_action_pressed("toggle_binds"):
		_binds_on = not _binds_on
		hud.show_binds(_binds_on)


func respawn() -> void:
	player.respawn_at(player.spawn_point)
	_imprint(player.spawn_point, AetherField.Channel.FEAR, 0.4)
	hud.set_death(false)
	hud.show_message("a marea cobrou sua divida")


# ------------------------------------------------------------------ povoamento

func _spawn_wolves(n: int) -> void:
	if _next_identity == 0:
		_population_rng.seed = ("population:%d" % world.gen.world_seed).hash()
	for i in n:
		var w := Wolf.new()
		var home := _random_ground_point(16.0, 46.0)
		_entities.add_child(w)
		w.setup(world, aether, player, home, _next_identity, clock)
		# A matilha entra pelo mesmo caminho do `entity_provider` do jogador: o
		# Callable e montado pela sessao, com a identidade presa, e o lobo so le.
		w.pack_provider = Callable(self, "pack_of").bind(_next_identity)
		_next_identity += 1
		w.bit_player.connect(_on_wolf_bit)
		w.died.connect(_on_wolf_died)
		# O diretor nasce em `_ready`, e `simulation_rng_test.gd` chama este spawn numa
		# sessao fora da arvore de proposito (o contrato la e "spawnar sem boot
		# completo"): aqui o som e opcional, a mente nao.
		if audio != null:
			audio.on_wolf_registered(w)
		wolves.append(w)


func _random_ground_point(rmin: float, rmax: float) -> Vector3:
	var c := spawn_point()
	for _attempt in 24:
		var a := _population_rng.randf() * TAU
		var r := _population_rng.randf_range(rmin, rmax)
		var p := Vector3(c.x + cos(a) * r, 0.0, c.z + sin(a) * r)
		p.x = clampf(p.x, 6.0, float(VoxelConfig.world_size_x()) - 6.0)
		p.z = clampf(p.z, 6.0, float(VoxelConfig.world_size_z()) - 6.0)
		var y := world.surface_height(int(p.x), int(p.z))
		if y > VoxelConfig.SEA_LEVEL:
			var feet := Vector3(p.x, float(y + 1), p.z)
			if _volume_clear(feet, Wolf.DIMS):
				return feet
	var fallback_y := world.surface_height(int(c.x), int(c.z))
	return Vector3(c.x, float(fallback_y + 1), c.z)


## Pe em cima do voxel mais alto da coluna nao basta: o corpo do lobo faz 1,35 m
## de profundidade e 0,75 de largura, entao num ponto encostado na parede do degrau
## vizinho a AABB ja nasce dentro do solido -- e encaixado, todo eixo do integrador
## colide e o bicho congela ali (medido em 2 dos 5 lobos do spawn). O ponto so vale
## com o volume inteiro livre.
func _volume_clear(feet: Vector3, dims: Vector3) -> bool:
	var box := AABB(feet - Vector3(dims.x * 0.5, 0.0, dims.z * 0.5), dims)
	return not world.aabb_hits_solid(box)


func targets_under_crosshair() -> Array:
	var out: Array = []
	for w in wolves:
		if w.alive:
			out.append(w)
	return out


func wolves_roster() -> Array:
	return wolves


## A matilha do lobo, no formato do dossie 10 §3.1: os vivos a menos do raio de
## coesao, cada um como `{identity, pos, intent, hp_ratio, trust}`. Devolve o
## buffer da sessao, nunca uma copia -- e o que permite a leitura de 20 Hz sem
## alocar.
func pack_of(identity: int) -> Array:
	var buf: Variant = _pack_buffers.get(identity)
	return EMPTY_PACK if not (buf is Array) else buf


## Uma passada por passo, aqui e nao cinco vezes dentro dos lobos: cada par i<j e
## testado uma unica vez (10 comparacoes com cinco lobos) e escrito nos dois
## buffers. O cursor e o proprio tamanho do buffer no passo anterior, cortado no
## fim para a lista nunca mostrar um vizinho fantasma.
func _rebuild_packs() -> void:
	for w: Wolf in wolves:
		_pack_cursor[w.identity] = 0
	_pack_pairs = 0
	var r2: float = PACK_COHESION_RADIUS * PACK_COHESION_RADIUS
	for i in wolves.size():
		var a: Wolf = wolves[i]
		if not a.alive:
			continue
		var ca: Vector3 = a.center()
		for j in range(i + 1, wolves.size()):
			var b: Wolf = wolves[j]
			if not b.alive:
				continue
			_pack_pairs += 1
			if ca.distance_squared_to(b.center()) > r2:
				continue
			_pack_put(a.identity, b)
			_pack_put(b.identity, a)
	for w: Wolf in wolves:
		_pack_slot(w.identity).resize(int(_pack_cursor[w.identity]))


func _pack_slot(identity: int) -> Array:
	if not _pack_buffers.has(identity):
		_pack_buffers[identity] = []
	return _pack_buffers[identity]


## A entrada e reescrita no lugar: depois do primeiro passo aquecido o lote copia
## cinco campos por vizinho e nao cria nenhum contenedor novo.
func _pack_put(identity: int, other: Wolf) -> void:
	var buf: Array = _pack_slot(identity)
	var n: int = int(_pack_cursor[identity])
	var e: Dictionary = {}
	if n < buf.size():
		e = buf[n]
	else:
		buf.append(e)
	e["identity"] = other.identity
	e["pos"] = other.center()
	e["intent"] = other.intent
	e["hp_ratio"] = other.hp / Wolf.MAX_HP
	# O trust vem como escalar ja publicado pelo lobo: um `mind.trust()` por par
	# custaria um `str(ator)` novo por comparacao no caminho quente (dossie 10 §4).
	e["trust"] = other.trust_toward_player
	_pack_cursor[identity] = n + 1


func _reap_corpses() -> void:
	for i in range(wolves.size() - 1, -1, -1):
		var w: Wolf = wolves[i]
		if w.finished():
			wolves.remove_at(i)
			# O buffer do morto sairia do rebuild e ficaria orphan no Dictionary para
			# sempre; a identidade nao e reutilizada, entao a limpeza e aqui.
			_pack_buffers.erase(w.identity)
			_pack_cursor.erase(w.identity)
			w.queue_free()
			_respawn_queue.append(RESPAWN_DELAY)


# ------------------------------------------------------------------ ecos do mundo

## O vies de bioma e do chamador, nao do campo: `AetherField.imprint` continua
## sem saber que existe voxel, e e a fronteira que mantem a difusao barata
## (dossie 09). A pergunta ao gen so roda em evento (lavra, colocacao, dano,
## morte, respawn), nunca no tick de 20 Hz.
func _imprint(pos: Vector3, ch: int, amount: float) -> void:
	var h: int = world.gen.surface_height(int(pos.x), int(pos.z))
	aether.imprint(pos, ch, amount * world.gen.imprint_bias(int(pos.x), int(pos.z), h, ch))


func _on_acted(kind: String, pos: Vector3) -> void:
	match kind:
		"break":
			_imprint(pos, AetherField.Channel.WORK, 0.42)
		"place":
			_imprint(pos, AetherField.Channel.WORK, 0.20)


func _on_block_broken(pos: Vector3i, block: int) -> void:
	stats["mined"] += 1
	if block == BlockDefs.Block.BENCH:
		_benches.erase(pos)


func _on_block_placed(pos: Vector3i, block: int) -> void:
	stats["placed"] += 1
	if block == BlockDefs.Block.BENCH and not _benches.has(pos):
		_benches.append(pos)


## As bancadas do jogador, em blocos: a lista que `Player.bench_near()` varre.
func bench_positions() -> Array[Vector3i]:
	return _benches


func _on_notice(text: String) -> void:
	hud.show_message(text)


func hud_panel_changed(open: bool) -> void:
	hud.show_panel(open)


func _on_attacked(target: Node3D, amount: float) -> void:
	if target is Wolf:
		(target as Wolf).take_damage(amount, Wolf.ACTOR_PLAYER, player.position3())


func _on_damaged(_amount: float, _from: Vector3) -> void:
	_imprint(player.position3(), AetherField.Channel.BLOOD, 0.22)


func _on_player_died(at: Vector3) -> void:
	stats["deaths"] += 1
	_imprint(at, AetherField.Channel.BLOOD, 1.3)
	_imprint(at, AetherField.Channel.FEAR, 1.0)
	hud.set_death(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_wolf_bit(w: Wolf, amount: float) -> void:
	player.take_damage(amount, w.center())
	if not player.alive:
		w.on_kill(Wolf.ACTOR_PLAYER)


func _on_wolf_died(_w: Wolf, _pos: Vector3) -> void:
	stats["wolves_felled"] += 1
	hud.show_message("o lobo caiu  o sangue fica no eter")


func _toggle_debug() -> void:
	hud.show_debug(not hud.debug_visible())


func _toggle_ether() -> void:
	viz.show_view(not viz.showing())
	if viz.showing():
		viz.refresh()


# ------------------------------------------------------------------ persistencia

func save_game() -> void:
	var edit_list := {}
	for k in world.edits:
		edit_list[Coords.block_key(k)] = int(world.edits[k])
	var minds: Array = []
	for w in wolves:
		minds.append(w.state_dict())
	var data := {
		"schema": SaveManager.SCHEMA,
		"gen_version": WorldGen.GEN_VERSION,
		"seed": SEED,
		"tick": clock.tick,
		"elapsed": elapsed,
		"stats": stats,
		"edits": edit_list,
		"aether": aether.to_dict(),
		"inv": player.inv.to_dict(),
		"player": {
			"feet": [player.body.feet_pos.x, player.body.feet_pos.y, player.body.feet_pos.z],
			"yaw": player.yaw, "pitch": player.pitch, "hp": player.hp,
			"deaths": player.deaths,
		},
		"wolves": minds,
	}
	var res := SaveManager.write_slot(SLOT, data)
	if res["ok"]:
		hud.show_message("mundo gravado  %d bytes  %.1f ms" % [res["bytes"], res["ms"]])
	else:
		hud.show_message("falha ao gravar: %s" % res["error"])


func load_game() -> void:
	var res := SaveManager.read_slot(SLOT)
	if not res["ok"]:
		hud.show_message("carregar: %s" % res["error"])
		return
	var d: Dictionary = res["data"]
	if int(d.get("gen_version", -1)) != WorldGen.GEN_VERSION:
		hud.show_message("save de gerador antigo: recrie o mundo")
		return
	if tick_journal.active():
		tick_journal.close()
		print("journal encerrado antes do load: ", tick_journal.path)
	world.generate(SEED)
	var edit_list := {}
	for k in d.get("edits", {}):
		edit_list[String(k)] = int(d["edits"][k])
	world.apply_edits(edit_list)
	var p: Dictionary = d.get("player", {})
	player.feet_to_spawn(Vector3(float(p["feet"][0]), float(p["feet"][1]), float(p["feet"][2])))
	player.yaw = float(p.get("yaw", 0.0))
	player.pitch = float(p.get("pitch", 0.0))
	player.hp = float(p.get("hp", player.max_hp))
	player.deaths = int(p.get("deaths", 0))
	if player.hp <= 0.0:
		player.hp = player.max_hp
	player.alive = true
	hud.set_death(false)
	player.spawn_point = player.position3()
	# `inv` e aditivo: save de antes nao tem o campo, e quem nao tem fica com o kit
	# em vez de um inventario vazio (o jogador nao acordaria sem blocos).
	if d.has("inv"):
		player.inv.from_dict(d["inv"])
	else:
		player.inv.reset_default()
	_rebuild_benches()
	audio.clear_transient()
	aether.from_dict(d.get("aether", {}))
	var saved: Array = d.get("wolves", [])
	for i in mini(saved.size(), wolves.size()):
		wolves[i].load_state(saved[i])
	clock.tick = int(d.get("tick", 0))
	elapsed = float(d.get("elapsed", 0.0))
	world.generate_meshes_all()
	hud.show_message("mundo reload  tick %d  %.1f ms" % [clock.tick, res["ms"]])


## Revarre as edicoes atrás das bancadas depois de um load: a lista e derivada do
## mundo, e um mundo recarregado sem ela deixaria o jogador craftar "na mao" do
## outro lado do mapa.
func _rebuild_benches() -> void:
	_benches.clear()
	for k in world.edits:
		if int(world.edits[k]) == BlockDefs.Block.BENCH:
			_benches.append(k)


func stats_line() -> String:
	return "jogador  minerado %d  colocado %d  mortes %d   inventario %d itens  %d bancadas   lobos vivos %d/%d   recriacoes %d" % [
		stats["mined"], stats["placed"], stats["deaths"],
		player.inv.item_count(), _benches.size(),
		targets_under_crosshair().size(), wolves.size(), _respawn_queue.size()]


func diagnostics() -> Dictionary:
	return {
		"gen_ms": _gen_ms, "mesh_ms": _mesh_ms,
		"chunks": world.chunks.size(), "meshes": world.meshes_built(),
		"edits": world.edits.size(), "aether_energy": aether.total_energy(),
		"wolves": wolves.size(), "wolves_alive": targets_under_crosshair().size(),
		"pack_pairs": _pack_pairs,
		"pending_respawns": _respawn_queue.size(), "triangles": world.triangle_count(),
		"tick": clock.tick, "worst_sim_ms": clock.worst_step_ms,
		"dropped_ticks": clock.dropped_ticks, "hp": player.hp,
		"on_ground": player.body.on_ground, "feet": player.body.feet_pos,
		"journal": tick_journal.diagnostics(),
	}


# ------------------------------------------------------------------ ceu & luz

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42.0, 55.0, 0.0)
	sun.light_energy = 1.60
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

	var prog := ProceduralSkyMaterial.new()
	prog.sky_top_color = Color(0.30, 0.50, 0.82)
	prog.sky_horizon_color = Color(0.70, 0.79, 0.87)
	prog.ground_bottom_color = Color(0.20, 0.22, 0.26)
	prog.ground_horizon_color = Color(0.70, 0.79, 0.87)
	var sky := Sky.new()
	sky.sky_material = prog

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	# Neblina mais densa e mais escura que o ceu: A/B na pose do spawn (bandas de
	# luminancia) mostrou mais contraste no terreno sem lavar o horizonte.
	env.fog_light_color = Color(0.55, 0.65, 0.78)
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)


func state_hash() -> String:
	return Journal.state_hash(clock.tick, world, aether, wolves)


func _start_journal_from_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tick-journal="):
			var err := tick_journal.start(arg.trim_prefix("--tick-journal="))
			if err != OK:
				push_error("abrir journal: %s" % error_string(err))
				get_tree().quit(1)
			return


func _exit_tree() -> void:
	tick_journal.close()
