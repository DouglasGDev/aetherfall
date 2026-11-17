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

var world: VoxelWorld = null
var aether: AetherField = null
var clock: SimClock = null
var player: Player = null
var viz: AetherViz = null
var hud: Hud = null
var wolves: Array = []
var elapsed: float = 0.0
var stats := {"mined": 0, "placed": 0, "wolves_felled": 0, "deaths": 0}

var _terrain: Node3D = null
var _entities: Node3D = null
var _next_identity: int = 0
var _respawn_queue: Array = []
var _aether_cd: float = AETHER_PERIOD
var _viz_cd: float = 0.0
var _corpse_cd: float = 0.0
var _gen_ms: float = 0.0
var _mesh_ms: float = 0.0
var _binds_on: bool = false


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
	player.setup(world, spawn_point(), BlockDefs.placeable_blocks())
	player.entity_provider = Callable(self, "targets_under_crosshair")
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
	hud.build_hotbar(player.hotbar)
	hud.show_message("vale reconstruido  seed %d" % SEED, 3.4)
	hud.preview_binds(7.0)

	_spawn_wolves(WOLF_COUNT)


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
	aether.imprint(player.spawn_point, AetherField.Channel.FEAR, 0.4)
	hud.set_death(false)
	hud.show_message("a marea cobrou sua divida")


# ------------------------------------------------------------------ povoamento

func _spawn_wolves(n: int) -> void:
	for i in n:
		var w := Wolf.new()
		var home := _random_ground_point(16.0, 46.0)
		_entities.add_child(w)
		w.setup(world, aether, player, home, _next_identity, clock)
		_next_identity += 1
		w.bit_player.connect(_on_wolf_bit)
		w.died.connect(_on_wolf_died)
		wolves.append(w)


func _random_ground_point(rmin: float, rmax: float) -> Vector3:
	var c := spawn_point()
	for _attempt in 24:
		var a := randf() * TAU
		var r := randf_range(rmin, rmax)
		var p := Vector3(c.x + cos(a) * r, 0.0, c.z + sin(a) * r)
		p.x = clampf(p.x, 6.0, float(VoxelConfig.world_size_x()) - 6.0)
		p.z = clampf(p.z, 6.0, float(VoxelConfig.world_size_z()) - 6.0)
		var y := world.surface_height(int(p.x), int(p.z))
		if y > VoxelConfig.SEA_LEVEL:
			return Vector3(p.x, float(y + 1), p.z)
	var fallback_y := world.surface_height(int(c.x), int(c.z))
	return Vector3(c.x, float(fallback_y + 1), c.z)


func targets_under_crosshair() -> Array:
	var out: Array = []
	for w in wolves:
		if w.alive:
			out.append(w)
	return out


func _reap_corpses() -> void:
	for i in range(wolves.size() - 1, -1, -1):
		var w: Wolf = wolves[i]
		if w.finished():
			wolves.remove_at(i)
			w.queue_free()
			_respawn_queue.append(RESPAWN_DELAY)


# ------------------------------------------------------------------ ecos do mundo

func _on_acted(kind: String, pos: Vector3) -> void:
	match kind:
		"break":
			aether.imprint(pos, AetherField.Channel.WORK, 0.42)
		"place":
			aether.imprint(pos, AetherField.Channel.WORK, 0.20)


func _on_block_broken(_pos: Vector3i, _block: int) -> void:
	stats["mined"] += 1


func _on_block_placed(_pos: Vector3i, _block: int) -> void:
	stats["placed"] += 1


func _on_attacked(target: Node3D, amount: float) -> void:
	if target is Wolf:
		(target as Wolf).take_damage(amount, Wolf.ACTOR_PLAYER, player.position3())


func _on_damaged(_amount: float, _from: Vector3) -> void:
	aether.imprint(player.position3(), AetherField.Channel.BLOOD, 0.22)


func _on_player_died(at: Vector3) -> void:
	stats["deaths"] += 1
	aether.imprint(at, AetherField.Channel.BLOOD, 1.3)
	aether.imprint(at, AetherField.Channel.FEAR, 1.0)
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
		edit_list["%d,%d,%d" % [k.x, k.y, k.z]] = int(world.edits[k])
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
		"player": {
			"feet": [player.body.feet_pos.x, player.body.feet_pos.y, player.body.feet_pos.z],
			"yaw": player.yaw, "pitch": player.pitch, "hp": player.hp,
			"deaths": player.deaths, "slot": player.hotbar_index,
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
	player.select_slot(int(p.get("slot", 0)))
	aether.from_dict(d.get("aether", {}))
	var saved: Array = d.get("wolves", [])
	for i in mini(saved.size(), wolves.size()):
		wolves[i].load_state(saved[i])
	clock.tick = int(d.get("tick", 0))
	elapsed = float(d.get("elapsed", 0.0))
	world.generate_meshes_all()
	hud.show_message("mundo reload  tick %d  %.1f ms" % [clock.tick, res["ms"]])


func stats_line() -> String:
	return "jogador  minerado %d  colocado %d  mortes %d   lobos vivos %d/%d   recriacoes %d" % [
		stats["mined"], stats["placed"], stats["deaths"],
		targets_under_crosshair().size(), wolves.size(), _respawn_queue.size()]


func diagnostics() -> Dictionary:
	return {
		"gen_ms": _gen_ms, "mesh_ms": _mesh_ms,
		"chunks": world.chunks.size(), "meshes": world.meshes_built(),
		"edits": world.edits.size(), "aether_energy": aether.total_energy(),
		"wolves": wolves.size(), "wolves_alive": targets_under_crosshair().size(),
		"pending_respawns": _respawn_queue.size(), "triangles": world.triangle_count(),
		"tick": clock.tick, "worst_sim_ms": clock.worst_step_ms,
		"dropped_ticks": clock.dropped_ticks, "hp": player.hp,
		"on_ground": player.body.on_ground, "feet": player.body.feet_pos,
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
