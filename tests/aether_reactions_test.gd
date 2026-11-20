extends SceneTree

const SEED: int = 20261116
const SPAWN := Vector3(58.0, 51.001, 62.0)
const SOURCE := Vector3(66.0, 50.6, 62.0)
const FAR_PLAYER := Vector3(112.0, 51.001, 112.0)
const TESTS: Array[StringName] = [
	&"_test_fixture", &"_test_work_approach", &"_test_weighted_traces",
	&"_test_fear_ab", &"_test_unseen", &"_test_last_sighting",
	&"_test_work_cycle", &"_test_blood_cycle", &"_test_fear_interrupt",
	&"_test_work_diffusion", &"_test_cache_expiry", &"_test_fear_no_feedback",
	&"_test_last_hurt_ab", &"_test_sighting_expiry",
	&"_test_dead_prey", &"_test_inspection_hit", &"_test_place_renewal", &"_test_cache_cap",
	&"_test_locomotion_flat", &"_test_locomotion_wall", &"_test_scent_cave_layer",
	&"_test_biome", &"_test_fur_colour",
]
const EXPECTED_CHECKS: int = 115

var _checks: int = 0
var _failures: int = 0
var _completed: int = 0
var _ran: bool = false
var _started_us: int = 0
var _mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _stage: Node3D
var _world: VoxelWorld
var _player: Player
var _wolf: Wolf
var _field: AetherField
var _clock: SimClock
var _steps: int = 0
var _sim_us: int = 0
var _sim_worst_us: int = 0
var _bt_us: int = 0
var _bt_worst_us: int = 0
var _bt_trips: int = 0


func _initialize() -> void:
	_started_us = Time.get_ticks_usec()
	_mouse_mode = Input.mouse_mode
	# O fechamento independe do retorno de _run: erro de script nao pode deixar a CLI aberta.
	_run.call_deferred()
	_finish.call_deferred()


func _run() -> void:
	for test_name: StringName in TESTS:
		if call(test_name) != true:
			_failures += 1
			push_error("ABORTOU %s: nao devolveu true" % test_name)
			break
		_completed += 1
	_ran = true


func _check(ok: bool, label: String, values: String) -> void:
	_checks += 1
	print("%s %s | %s" % ["OK" if ok else "FALHA", label, values])
	if not ok:
		_failures += 1


func _test_fixture() -> bool:
	BlockDefs.init_tables()
	_stage = Node3D.new()
	_stage.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_stage)
	_world = VoxelWorld.new()
	_world.setup_world(_stage)
	_world.generate(SEED)
	var bad_columns: int = 0
	for x: int in range(40, 85):
		for z: int in range(40, 85):
			_world.set_block(Vector3i(x, 50, z), BlockDefs.Block.STONE)
			for y: int in range(51, VoxelChunk.SIZE_Y):
				_world.set_block(Vector3i(x, y, z), BlockDefs.Block.AIR)
			if _world.surface_height(x, z) != 50 or _world.is_water_xyz(x, 51, z):
				bad_columns += 1
	_player = Player.new()
	_stage.add_child(_player)
	_player.setup(_world, FAR_PLAYER)
	_check(_world.gen.world_seed == SEED and _world.chunks.size() == 64,
			"geracao real", "seed=%d chunks=%d" % [_world.gen.world_seed, _world.chunks.size()])
	_check(bad_columns == 0, "2025 colunas secas, piso y=50, ar ate o teto", "invalidas=%d" % bad_columns)
	_check(_player.is_node_ready() and _world.atlas_texture() != null,
			"Player pronto com atlas real", "ready=%s atlas=%s" % [_player.is_node_ready(), _world.atlas_texture()])
	_check(not _player.can_process() and _world.meshes_built() == 0,
			"sem input automatico ou malharia", "process=%s meshes=%d" % [_player.can_process(), _world.meshes_built()])
	return true


func _arm(spawn: Vector3 = SPAWN, player_pos: Vector3 = FAR_PLAYER, wolf_id: int = 1) -> void:
	if is_instance_valid(_wolf):
		_wolf.free()
	seed(SEED)
	_clock = SimClock.new()
	_field = AetherField.new()
	_field.setup(_world)
	_player.feet_to_spawn(player_pos)
	_wolf = Wolf.new()
	_stage.add_child(_wolf)
	_wolf.setup(_world, _field, _player, spawn, wolf_id, _clock)


func _advance(ticks: int, move_body: bool = true) -> void:
	# Campo estatico por padrao isola a reacao; so o caso de difusao avanca o campo.
	for i: int in ticks:
		var trips_before: int = _wolf._guard.trips
		var start: int = Time.get_ticks_usec()
		_wolf.sim_step(float(_clock.tick + 1) * SimClock.STEP, SimClock.STEP)
		var cost: int = Time.get_ticks_usec() - start
		_sim_us += cost
		_sim_worst_us = maxi(_sim_worst_us, cost)
		_bt_us += _wolf._guard.last_us
		_bt_worst_us = maxi(_bt_worst_us, _wolf._guard.last_us)
		_bt_trips += _wolf._guard.trips - trips_before
		_steps += 1
		_clock.tick += 1
		if move_body:
			for frame: int in 3:
				_wolf._physics_process(SimClock.STEP / 3.0)


func _horizontal(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _distance(p: Vector3) -> float:
	return _horizontal(_wolf.center() - p).length()


func _motion() -> String:
	return "tick=%d intent=%s reaction=%s feet=%s speed=%.4f target=%s" % [
		_clock.tick, _wolf.intent, _wolf.get("_reaction"), _wolf.body.feet_pos,
		_horizontal(_wolf.body.velocity).length(), _wolf._move_target]


func _arrive() -> bool:
	for i: int in 160:
		_advance(1)
		if _distance(SOURCE) <= 1.2 or _wolf.get("_reaction") == "farejando":
			return _distance(SOURCE) < 1.5
	return false


func _wall(block: int) -> void:
	for y: int in range(51, 57):
		for z: int in range(40, 85):
			_world.set_block(Vector3i(63, y, z), block)


func _test_work_approach() -> bool:
	_arm()
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.42)
	_advance(1)
	_check(_wolf._dist_player > 30.0 and not _wolf._los_player,
			"WORK sem jogador perceptivel", "dist=%.3f los=%s" % [_wolf._dist_player, _wolf._los_player])
	_check(_wolf.intent == "investigate" and _horizontal(_wolf._scent_pos - SOURCE).length() < 0.01,
			"imprint WORK .42 atrai", "work=%.4f %s" % [_field.sample(SOURCE, AetherField.Channel.WORK), _motion()])
	var before: float = _distance(SOURCE)
	_advance(16)
	_check(_distance(SOURCE) < before - 0.3 and _horizontal(_wolf.body.velocity).length() > 0.1,
			"aproximacao fisica do rastro", "dist %.3f -> %.3f %s" % [before, _distance(SOURCE), _motion()])
	_check(_wolf.mind.count_kind("saw_player") == 0, "rastro nao fabrica avistamento",
			"episodios=%d" % _wolf.mind.count_kind("saw_player"))
	return true


func _test_weighted_traces() -> bool:
	var blood_pos := Vector3(58.0, 50.6, 66.0)
	for blood_wins: bool in [true, false]:
		_arm()
		var blood: float = 0.25 if blood_wins else 0.08
		var work: float = 0.42 if blood_wins else 0.84
		_field.imprint(blood_pos, AetherField.Channel.BLOOD, blood)
		_field.imprint(SOURCE, AetherField.Channel.WORK, work)
		_advance(1)
		var expected: Vector3 = blood_pos if blood_wins else SOURCE
		_check((_field.sample(blood_pos, AetherField.Channel.BLOOD)
				> _field.sample(SOURCE, AetherField.Channel.WORK) * 0.35) == blood_wins,
				"premissa dos pesos simultaneos", "blood=%.3f work*.35=%.3f" % [blood, work * 0.35])
		_check(_wolf.intent == "investigate" and _horizontal(_wolf._scent_pos - expected).length() < 0.01,
				"vence o rastro ponderado mais forte", "esperado=%s %s" % [expected, _motion()])
	return true


func _test_fear_ab() -> bool:
	var directions: Array[Vector3] = []
	var motions: Array[Vector3] = []
	var spawn := Vector3(62.0, 51.001, 62.0)
	for player_z: float in [18.0, 106.0]:
		_arm(spawn, Vector3(62.0, 51.001, player_z))
		_field.imprint(_wolf.center(), AetherField.Channel.FEAR, 0.9)
		_field.imprint(_wolf.center() + Vector3(4, 0, 0), AetherField.Channel.FEAR, 3.5)
		# Observar o vetor antes da fisica separa steering do desvio por colisao.
		_advance(1, false)
		var direction: Vector3 = _horizontal(_wolf._move_target - _wolf.center()).normalized()
		directions.append(direction)
		var east: float = _field.sample(_wolf.center() + Vector3(4, 0, 0), AetherField.Channel.FEAR)
		_check(not _wolf._los_player and _wolf._dist_player > 30.0
				and is_equal_approx(_wolf._fear_here, 0.9) and is_equal_approx(east, 3.5),
				"medo local com jogador invisivel", "player_z=%.1f fear=%.3f east=%.3f dist=%.3f" % [player_z, _wolf._fear_here, east, _wolf._dist_player])
		_check(_wolf.intent == "flee" and direction.x < -0.95,
				"fuga desce gradiente a oeste", "vetor=%s %s" % [direction, _motion()])
		_advance(6)
		var moved: Vector3 = _horizontal(_wolf.body.feet_pos - spawn)
		motions.append(moved)
		_check(moved.x < -0.2, "corpo foge a oeste", "deslocamento=%s %s" % [moved, _motion()])
	_check(directions[0].distance_to(directions[1]) < 0.0001,
			"A/B jogador oculto nao muda vetor", "A=%s B=%s" % directions)
	_check(motions[0].distance_to(motions[1]) < 0.0001,
			"A/B mesmo seed e clock conservam movimento", "A=%s B=%s" % motions)
	return true


func _test_unseen() -> bool:
	_arm(SPAWN, Vector3(66.0, 51.001, 62.0))
	_wall(BlockDefs.Block.STONE)
	_advance(1)
	_check(not _wolf._los_player and _wolf._dist_player < 10.0,
			"parede real oculta jogador proximo", "dist=%.3f los=%s" % [_wolf._dist_player, _wolf._los_player])
	var hunts: int = 0
	for i: int in 12:
		if _wolf.intent == "hunt":
			hunts += 1
		_advance(1)
	_check(hunts == 0 and _wolf.intent != "hunt", "sem avistamento nao caca", "ticks_hunt=%d %s" % [hunts, _motion()])
	_check(_wolf.mind.count_kind("saw_player") == 0, "parede nao produz memoria visual",
			"episodios=%d" % _wolf.mind.count_kind("saw_player"))
	_wall(BlockDefs.Block.AIR)
	return true


func _test_last_sighting() -> bool:
	_arm(SPAWN, Vector3(66.0, 51.001, 62.0))
	var before: float = _distance(_player.position3())
	_advance(10)
	_check(_wolf._los_player and _wolf.intent == "hunt", "presa visivel ainda provoca caca", _motion())
	_check(_distance(_player.position3()) < before - 0.3, "caca move corpo ate presa visivel",
			"dist %.3f -> %.3f" % [before, _distance(_player.position3())])
	var atom: Dictionary = _wolf.mind.last_atom("saw_player")
	var seen: Vector3 = atom.get("pos", Vector3.ZERO)
	_wall(BlockDefs.Block.STONE)
	_player.feet_to_spawn(Vector3(66.0, 51.001, 72.0))
	_advance(1)
	_check(not atom.is_empty() and not _wolf._los_player and _distance(_player.position3()) < 30.0,
			"avistamento real seguido de bloqueio e deslocamento", "visto=%s oculto=%s los=%s" % [seen, _player.position3(), _wolf._los_player])
	_check(_wolf.intent == "hunt" and _horizontal(_wolf._move_target - seen).length() < 0.05
			and _horizontal(_wolf._move_target - _player.position3()).length() > 5.0,
			"persegue ultima observacao, nao posicao oculta", _motion())
	before = _distance(seen)
	_advance(4)
	_check(_distance(seen) < before and _horizontal(_wolf._move_target - seen).length() < 0.05,
			"memoria guia movimento apos perda de LOS", "dist %.3f -> %.3f %s" % [before, _distance(seen), _motion()])
	_wall(BlockDefs.Block.AIR)
	return true


func _test_work_cycle() -> bool:
	_arm()
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.42)
	var arrived: bool = _arrive()
	_check(arrived, "WORK chega ao local em ate 8s", "dist=%.3f %s" % [_distance(SOURCE), _motion()])
	var at_arrival: Vector3 = _wolf.body.feet_pos
	_advance(12)
	var drift: float = _horizontal(_wolf.body.feet_pos - at_arrival).length()
	_check(arrived and drift < 0.4 and _horizontal(_wolf.body.velocity).length() < 0.2,
			"inspecao para corpo em vez de cair na patrulha", "drift=%.4f %s" % [drift, _motion()])
	_advance(50)
	var first: int = _wolf.mind.count_kind("scent_work")
	var episode: Dictionary = _wolf.mind.last_atom("scent_work")
	_check(first == 1 and int(episode.get("actor", -1)) == 0,
			"inspecao WORK produz episodio sem atribuir ator", "count=%d atom=%s" % [first, episode])
	# Tres segundos permitem outra inspecao, sem deixar a patrulha sair do raio de cheiro.
	_advance(60)
	_check(first == 1 and _wolf.mind.count_kind("scent_work") == first,
			"rastro estatico nao repete episodio em 3s", "antes=%d depois=%d" % [first, _wolf.mind.count_kind("scent_work")])
	var cache: Variant = _wolf.get("_checked_scents")
	_check(cache is Dictionary and cache.size() > 0 and cache.size() <= 32,
			"inspecao registra cache limitado", "cache=%s" % str(cache))
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.42)
	var reopened: bool = false
	for i: int in 200:
		_advance(1)
		reopened = reopened or (_wolf.intent == "investigate" and _horizontal(_wolf._scent_pos - SOURCE).length() < 0.01)
		if _wolf.mind.count_kind("scent_work") > first:
			break
	_check(first == 1 and reopened, "novo imprint .42 reabre local checado",
			"reabriu=%s work=%.3f %s" % [reopened, _field.sample(SOURCE, AetherField.Channel.WORK), _motion()])
	_check(first == 1 and _wolf.mind.count_kind("scent_work") == 2,
			"rastro renovado termina segunda inspecao", "count=%d" % _wolf.mind.count_kind("scent_work"))
	_wolf.load_state(_wolf.state_dict().duplicate(true))
	cache = _wolf.get("_checked_scents")
	_check(cache is Dictionary and cache.is_empty(), "load limpa cache transitorio", "cache=%s" % str(cache))
	var left: Variant = _wolf.get("_inspect_left")
	_check(left != null and float(left) == 0.0 and _wolf.get("_reaction") != "farejando",
			"load nao retoma timer de inspecao", "left=%s %s" % [left, _motion()])
	return true


func _test_blood_cycle() -> bool:
	_arm()
	_field.imprint(SOURCE, AetherField.Channel.BLOOD, 0.42)
	_check(_arrive(), "BLOOD aproxima corpo ate fonte", "dist=%.3f %s" % [_distance(SOURCE), _motion()])
	_advance(62)
	var atom: Dictionary = _wolf.mind.last_atom("scent_blood")
	_check(_wolf.mind.count_kind("scent_blood") == 1 and int(atom.get("actor", -1)) == 0,
			"inspecao BLOOD produz episodio sem ator", "atom=%s" % atom)
	_check(_wolf.mind.count_kind("saw_player") == 0 and _wolf.mind.count_kind("scent_work") == 0,
			"sangue nao vira avistamento ou trabalho", "saw=%d work=%d" % [_wolf.mind.count_kind("saw_player"), _wolf.mind.count_kind("scent_work")])
	return true


func _test_fear_interrupt() -> bool:
	_arm(Vector3(SOURCE.x, 51.001, SOURCE.z))
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.42)
	_advance(3)
	_check(_wolf.get("_reaction") == "farejando", "premissa: inspecao em andamento", _motion())
	var before: Vector3 = _wolf.body.feet_pos
	_field.imprint(_wolf.center(), AetherField.Channel.FEAR, 0.9)
	_field.imprint(_wolf.center() + Vector3(4, 0, 0), AetherField.Channel.FEAR, 3.5)
	_advance(14)
	_check(_wolf.intent == "flee" and _wolf.get("_reaction") != "farejando",
			"medo interrompe inspecao antes de 2s", _motion())
	_check(_wolf.body.feet_pos.x < before.x - 0.2 and _wolf.mind.count_kind("scent_work") == 0,
			"interrupcao move corpo sem concluir episodio", "dx=%.3f count=%d" % [_wolf.body.feet_pos.x - before.x, _wolf.mind.count_kind("scent_work")])
	return true


func _test_work_diffusion() -> bool:
	_arm()
	_field.imprint(SOURCE, AetherField.Channel.WORK, 4.0)
	var energy_before: float = _field.total_energy()
	_advance(1)
	_check(_wolf.intent == "investigate" and not _wolf._los_player and _wolf._dist_player > 30.0
			and _field.sample(SOURCE, AetherField.Channel.WORK) > 3.9,
			"premissa: WORK forte sem presa perceptivel", "energia=%.6f %s" % [energy_before, _motion()])
	var passes: int = 0
	var approach_passes: int = 0
	var inspect_passes: int = 0
	var episode: Dictionary = {}
	var episode_tick: int = -1
	var episode_distance: float = INF
	var travel: float = 0.0
	# O pico pode mudar de celula: a chegada se mede contra o episodio, nao a fonte inicial.
	for i: int in 239:
		if (_clock.tick + 1) % 5 == 0:
			_field.diffuse_and_decay(0.25)
			passes += 1
			if _wolf.get("_reaction") == "farejando":
				inspect_passes += 1
			elif _wolf.intent == "investigate":
				approach_passes += 1
		_advance(1)
		if episode.is_empty() and _wolf.mind.count_kind("scent_work") > 0:
			episode = _wolf.mind.last_atom("scent_work")
			episode_tick = _clock.tick
			episode_distance = _distance(episode.get("pos", Vector3.ZERO))
			travel = _horizontal(_wolf.body.feet_pos - SPAWN).length()
	_check(_clock.tick == 240 and passes == 48 and approach_passes > 0 and inspect_passes > 0,
			"difusao .25s durante aproximacao e inspecao", "ticks=%d passes=%d seguindo=%d farejando=%d" % [
			_clock.tick, passes, approach_passes, inspect_passes])
	var energy_after: float = _field.total_energy()
	var active: int = _field.active_cells(AetherField.MIN_VALUE).size()
	_check(energy_after > 0.0 and energy_after < energy_before and active > 1,
			"campo realmente decai e espalha", "energia %.6f -> %.6f celulas=%d" % [energy_before, energy_after, active])
	_check(episode_tick > 0 and episode_tick <= 240 and int(episode.get("actor", -1)) == 0,
			"WORK difuso conclui episodio sem ator em ate 12s", "tick=%d count=%d atom=%s" % [
			episode_tick, _wolf.mind.count_kind("scent_work"), episode])
	_check(episode_distance <= 1.5 and travel > 0.5,
			"episodio difuso exige chegada fisica ao local examinado", "dist=%.4f deslocamento=%.4f" % [episode_distance, travel])
	_check(_wolf.mind.count_kind("saw_player") == 0 and _wolf.mind.count_kind("scent_blood") == 0,
			"difusao WORK nao fabrica presa ou sangue", "saw=%d blood=%d" % [
			_wolf.mind.count_kind("saw_player"), _wolf.mind.count_kind("scent_blood")])
	return true


func _test_cache_expiry() -> bool:
	_arm(Vector3(SOURCE.x, 51.001, SOURCE.z))
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.84)
	var strength_before: float = _field.sample(SOURCE, AetherField.Channel.WORK)
	var energy_before: float = _field.total_energy()
	var first_tick: int = -1
	for i: int in 60:
		_advance(1)
		if _wolf.mind.count_kind("scent_work") > 0:
			first_tick = _clock.tick
			break
	var first: Dictionary = _wolf.mind.last_atom("scent_work")
	_check(first_tick > 0 and _wolf.mind.count_kind("scent_work") == 1
			and _distance(SOURCE) <= 1.2 and _horizontal(_wolf.body.velocity).length() < 0.01,
			"premissa: primeira inspecao com corpo real em ate 3s", "tick=%d atom=%s %s" % [first_tick, first, _motion()])
	var cell: Vector3i = _field.cell_of_world(SOURCE)
	var cache: Dictionary = _wolf.get("_checked_scents")
	var entry: Vector2 = cache.get(cell, Vector2(-1.0, -1.0))
	_check(cache.has(cell) and absf(entry.y - float(first_tick) * SimClock.STEP - 30.0) < 0.001
			and strength_before * 0.35 > 0.08,
			"premissa: cache da fonte dura 30s e WORK continua forte", "entrada=%s tick=%d work*.35=%.6f" % [entry, first_tick, strength_before * 0.35])
	# Congelar apos a visita impede que sair do raio do cheiro finja supressao pelo cache.
	var parked: Vector3 = _wolf.body.feet_pos
	var early_inspections: int = 0
	for i: int in 580:
		_advance(1, false)
		if _wolf.get("_reaction") == "farejando":
			early_inspections += 1
	_check(first_tick > 0 and _clock.tick - first_tick == 580 and early_inspections == 0
			and _wolf.mind.count_kind("scent_work") == 1 and cache.has(cell),
			"cache impede reinspecao durante os primeiros 29s", "idade=%.2f farejando=%d count=%d cached=%s" % [
			float(_clock.tick - first_tick) * SimClock.STEP, early_inspections, _wolf.mind.count_kind("scent_work"), cache.has(cell)])
	var expired_tick: int = -1
	var reopened_tick: int = -1
	for i: int in 100:
		_advance(1, false)
		if expired_tick < 0 and not cache.has(cell):
			expired_tick = _clock.tick
		if reopened_tick < 0 and _wolf.get("_reaction") == "farejando":
			reopened_tick = _clock.tick
		if _wolf.mind.count_kind("scent_work") > 1:
			break
	var expiry_age: float = float(expired_tick - first_tick) * SimClock.STEP
	var reopen_age: float = float(reopened_tick - first_tick) * SimClock.STEP
	_check(expired_tick > 0 and expiry_age >= 30.0 and expiry_age <= 30.3,
			"cache expira apos 30s na cadencia de percepcao", "idade=%.3f tick=%d" % [expiry_age, expired_tick])
	_check(reopened_tick > 0 and reopen_age >= 30.0 and reopen_age <= 31.0,
			"mesmo WORK reabre inspecao sem novo imprint", "idade=%.3f tick=%d" % [reopen_age, reopened_tick])
	var second: Dictionary = _wolf.mind.last_atom("scent_work")
	var episode_gap: int = int(second.get("tick", -1)) - int(first.get("tick", -1))
	_check(_wolf.mind.count_kind("scent_work") == 2 and episode_gap >= 600 and episode_gap <= 680
			and second.get("pos") == first.get("pos") and int(second.get("actor", -1)) == 0,
			"revisita termina segundo episodio no mesmo local", "intervalo_ticks=%d count=%d atom=%s" % [
			episode_gap, _wolf.mind.count_kind("scent_work"), second])
	_check(_wolf.body.feet_pos.distance_to(parked) < 0.0001
			and is_equal_approx(_field.sample(SOURCE, AetherField.Channel.WORK), strength_before)
			and is_equal_approx(_field.total_energy(), energy_before),
			"premissa mantida: corpo parado e campo estatico sem renovacao", "drift=%.6f work %.6f -> %.6f energia %.6f -> %.6f" % [
			_wolf.body.feet_pos.distance_to(parked), strength_before, _field.sample(SOURCE, AetherField.Channel.WORK), energy_before, _field.total_energy()])
	return true


func _test_fear_no_feedback() -> bool:
	var spawn := Vector3(62.0, 51.001, 62.0)
	_arm(spawn)
	var origin: Vector3 = _wolf.center()
	var east: Vector3 = origin + Vector3(4, 0, 0)
	var west: Vector3 = origin - Vector3(4, 0, 0)
	_field.imprint(origin, AetherField.Channel.FEAR, 0.9)
	_field.imprint(east, AetherField.Channel.FEAR, 3.5)
	var samples_before := Vector3(_field.sample(origin, AetherField.Channel.FEAR),
			_field.sample(east, AetherField.Channel.FEAR), _field.sample(west, AetherField.Channel.FEAR))
	var energy_before: float = _field.total_energy()
	_check(samples_before.is_equal_approx(Vector3(0.9, 3.5, 0.0)) and is_equal_approx(energy_before, 4.4)
			and _wolf.mind.count_kind("hurt") == 0 and _wolf.hp == Wolf.MAX_HP,
			"premissa: somente dois imprints FEAR, nenhum golpe", "amostras=%s energia=%.6f hp=%.2f" % [samples_before, energy_before, _wolf.hp])
	var flee_ticks: int = 0
	var visible_ticks: int = 0
	for i: int in 20:
		_advance(1)
		if _wolf.intent == "flee":
			flee_ticks += 1
		if _wolf._los_player:
			visible_ticks += 1
	_check(flee_ticks >= 3 and _wolf.body.feet_pos.x < spawn.x - 0.2 and visible_ticks == 0
			and _wolf.mind.count_kind("hurt") == 0 and is_zero_approx(_wolf._threat),
			"fuga fisica provocada so pelo campo", "flee=%d los=%d dx=%.4f threat=%.4f" % [
			flee_ticks, visible_ticks, _wolf.body.feet_pos.x - spawn.x, _wolf._threat])
	# As sondas ficam no mundo, nao acompanham o lobo que sai da celula quente.
	var samples_after := Vector3(_field.sample(origin, AetherField.Channel.FEAR),
			_field.sample(east, AetherField.Channel.FEAR), _field.sample(west, AetherField.Channel.FEAR))
	_check(samples_after.is_equal_approx(samples_before),
			"fugir nao amplifica FEAR nas sondas fixas", "antes=%s depois=%s" % [samples_before, samples_after])
	var totals: Array = _field.channel_totals()
	_check(is_equal_approx(_field.total_energy(), energy_before)
			and is_equal_approx(float(totals[AetherField.Channel.FEAR]), energy_before)
			and is_zero_approx(float(totals[AetherField.Channel.BLOOD])) and is_zero_approx(float(totals[AetherField.Channel.WORK])),
			"fuga sem golpe nao cria energia em outras celulas", "energia %.6f -> %.6f canais=%s" % [energy_before, _field.total_energy(), totals])
	return true


func _test_last_hurt_ab() -> bool:
	var directions: Array[Vector3] = []
	var motions: Array[Vector3] = []
	for player_z: float in [18.0, 106.0]:
		_arm(SPAWN, SPAWN + Vector3(2, 0, 0))
		var hit_from: Vector3 = _player.position3()
		_wolf.take_damage(8.0, Wolf.ACTOR_PLAYER, hit_from)
		var hurt: Dictionary = _wolf.mind.last_atom("hurt")
		_check(_wolf.alive and is_equal_approx(_wolf.hp, Wolf.MAX_HP - 8.0)
				and _wolf.mind.count_kind("hurt") == 1 and hurt.get("pos") == hit_from
				and int(hurt.get("actor", -1)) == Wolf.ACTOR_PLAYER,
				"premissa A/B: um unico take_damage real", "braco_z=%.1f hp=%.2f atom=%s" % [player_z, _wolf.hp, hurt])
		_player.feet_to_spawn(Vector3(SPAWN.x, SPAWN.y, player_z))
		# Steering antes da fisica separa a direcao escolhida do impulso do golpe.
		_advance(1, false)
		var expected: Vector3 = _horizontal(_wolf.center() - hit_from).normalized()
		var hidden_away: Vector3 = _horizontal(_wolf.center() - _player.position3()).normalized()
		var direction: Vector3 = _horizontal(_wolf._move_target - _wolf.center()).normalized()
		directions.append(direction)
		_check(not _wolf._los_player and _wolf._dist_player > 30.0 and _wolf._threat > 0.9
				and _wolf.mind.count_kind("saw_player") == 0 and absf(expected.dot(hidden_away)) < 0.1,
				"premissa A/B: jogador relocado oculto em rumo distinto do golpe", "dist=%.3f threat=%.3f golpe=%s oculto=%s" % [
				_wolf._dist_player, _wolf._threat, expected, hidden_away])
		_check(_wolf.intent == "flee" and direction.dot(expected) > 0.999
				and absf(direction.dot(hidden_away)) < 0.1,
				"fuga usa LAST hurt, nao jogador oculto", "vetor=%s esperado=%s %s" % [direction, expected, _motion()])
		_advance(19)
		_advance(1, false)
		# A direcao pertence ao centro da decisao, nao ao centro movido pelos tres frames seguintes.
		var after_direction: Vector3 = _horizontal(_wolf._move_target - _wolf.center()).normalized()
		var after_expected: Vector3 = _horizontal(_wolf.center() - hit_from).normalized()
		for frame: int in 3:
			_wolf._physics_process(SimClock.STEP / 3.0)
		var moved: Vector3 = _horizontal(_wolf.body.feet_pos - SPAWN)
		motions.append(moved)
		_check(_wolf._stagger <= 0.0 and _wolf.intent == "flee" and moved.dot(expected) > 0.5
				and after_direction.dot(after_expected) > 0.999 and not _wolf._los_player
				and _wolf.mind.count_kind("hurt") == 1,
				"apos knockback, fuga ainda aponta para longe do ultimo golpe", "stagger=%.4f deslocamento=%s vetor=%s esperado=%s" % [
				_wolf._stagger, moved, after_direction, after_expected])
	_check(directions[0].distance_to(directions[1]) < 0.0001,
			"A/B relocacao oculta nao muda steering apos golpe", "A=%s B=%s" % directions)
	_check(motions[0].distance_to(motions[1]) < 0.0001,
			"A/B mesmo golpe produz mesmo movimento", "A=%s B=%s" % motions)
	return true


func _test_sighting_expiry() -> bool:
	_arm(SPAWN, Vector3(66.0, 51.001, 62.0))
	_advance(1)
	var atom: Dictionary = _wolf.mind.last_atom("saw_player")
	var seen: Vector3 = atom.get("pos", Vector3.ZERO)
	var seen_tick: int = int(atom.get("tick", -1))
	_check(_wolf._los_player and _wolf.intent == "hunt" and _wolf.mind.count_kind("saw_player") == 1
			and seen_tick >= 0 and _horizontal(seen - _player.position3()).length() < 0.01,
			"premissa: avistamento real antes de medir os 6s", "atom=%s %s" % [atom, _motion()])
	_wall(BlockDefs.Block.STONE)
	_player.feet_to_spawn(Vector3(66.0, 51.001, 72.0))
	var parked: Vector3 = _wolf.body.feet_pos
	_advance(1, false)
	_check(not _wolf._los_player and _wolf._dist_player < 30.0 and _distance(seen) > 6.0
			and _horizontal(seen - _player.position3()).length() > 5.0 and _wolf.intent == "hunt"
			and _horizontal(_wolf._move_target - seen).length() < 0.05,
			"parede oculta presa proxima, memoria ainda guia caca", "dist_memoria=%.3f dist_player=%.3f %s" % [_distance(seen), _wolf._dist_player, _motion()])
	var at_deadline: bool = false
	var deadline_motion: String = "nao observado"
	var expired_samples: int = 0
	var hidden_hunts: int = 0
	var hidden_chases: int = 0
	var visible_ticks: int = 0
	# Corpo parado isola a expiracao por idade; a decisao precede o incremento do tick.
	for i: int in 160:
		_advance(1, false)
		var age_ticks: int = _clock.tick - 1 - seen_tick
		if _wolf._los_player:
			visible_ticks += 1
		if age_ticks == 120:
			at_deadline = _wolf.intent == "hunt" and _horizontal(_wolf._move_target - seen).length() < 0.05
			deadline_motion = _motion()
		elif age_ticks > 120:
			expired_samples += 1
			if _wolf.intent == "hunt":
				hidden_hunts += 1
			if _wolf.get("_reaction") in ["buscando ultimo avistamento", "perseguindo presa visivel"]:
				hidden_chases += 1
	_check(at_deadline, "memoria vale no ultimo tick inclusivo de 6s", "idade_ticks=120 %s" % deadline_motion)
	_check(expired_samples == 41 and hidden_hunts == 0 and hidden_chases == 0,
			"apos 6s nao ha caca oculta em nenhum tick", "amostras=%d hunt=%d chase=%d" % [expired_samples, hidden_hunts, hidden_chases])
	var last: Dictionary = _wolf.mind.last_atom("saw_player")
	_check(visible_ticks == 0 and _wolf.mind.count_kind("saw_player") == 1
			and int(last.get("tick", -1)) == seen_tick,
			"parede impede renovacao; episodio persiste mas nao autoriza caca", "los_ticks=%d count=%d tick_visto=%d ultimo=%s" % [
			visible_ticks, _wolf.mind.count_kind("saw_player"), seen_tick, last])
	_check(_wolf.body.feet_pos.distance_to(parked) < 0.0001 and _distance(seen) > 6.0
			and is_zero_approx(_field.total_energy()) and _wolf.hp == Wolf.MAX_HP,
			"premissa mantida: sem chegada, dano ou campo concorrente", "drift=%.6f dist_memoria=%.3f energia=%.6f hp=%.2f" % [
			_wolf.body.feet_pos.distance_to(parked), _distance(seen), _field.total_energy(), _wolf.hp])
	_wall(BlockDefs.Block.AIR)
	return true


func _test_dead_prey() -> bool:
	_arm(SPAWN, Vector3(66.0, 51.001, 62.0))
	_advance(1)
	_check(_wolf.intent == "hunt" and _wolf._los_player and _wolf.mind.count_kind("saw_player") == 1,
			"premissa: caca acaba de iniciar antes da morte", _motion())
	_player.take_damage(_player.max_hp, _wolf.center())
	_advance(1)
	_check(not _player.alive and _wolf.intent == "hunt" and not _wolf._los_player,
			"morte real durante histerese de caca", "hp=%.1f %s" % [_player.hp, _motion()])
	_check(_wolf.get("_reaction") == "patrulhando" and not _wolf._cond_hunt_memory({}),
			"histerese nao executa busca de presa morta", _motion())
	_player.respawn_at(FAR_PLAYER)
	return true


func _test_inspection_hit() -> bool:
	_arm(Vector3(SOURCE.x, 51.001, SOURCE.z), FAR_PLAYER, 2)
	_field.imprint(SOURCE, AetherField.Channel.WORK, 4.0)
	for i: int in 60:
		_advance(1)
		if _wolf._inspect_left > 0.0 and _wolf._inspect_left <= SimClock.STEP + 0.0001:
			break
	_check(_wolf._inspect_left > 0.0 and _wolf._inspect_left <= SimClock.STEP + 0.0001
			and _wolf.mind.count_kind("scent_work") == 0,
			"premissa: ultimo passo antes de concluir inspecao", "left=%.6f %s" % [_wolf._inspect_left, _motion()])
	_wolf.take_damage(0.1, Wolf.ACTOR_PLAYER, _wolf.center() + Vector3(2, 0, 0))
	_check(_wolf._stagger > 0.0 and _horizontal(_wolf.body.velocity).length() >= Wolf.KNOCKBACK_SPEED
			and _wolf.mind.count_kind("hurt") == 1,
			"golpe real interrompe corpo antes da conclusao", "stagger=%.3f %s" % [_wolf._stagger, _motion()])
	_advance(1)
	_check(_wolf.mind.count_kind("scent_work") == 0 and is_zero_approx(_wolf._inspect_left),
			"atordoamento cancela inspecao sem episodio", "left=%.6f count=%d %s" % [
			_wolf._inspect_left, _wolf.mind.count_kind("scent_work"), _motion()])
	return true


func _test_place_renewal() -> bool:
	_arm(Vector3(SOURCE.x, 51.001, SOURCE.z))
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.42)
	for i: int in 60:
		_advance(1)
		if _wolf.mind.count_kind("scent_work") == 1:
			break
	var first: int = _wolf.mind.count_kind("scent_work")
	_check(first == 1 and _distance(SOURCE) <= 1.2,
			"premissa: local examinado antes de nova construcao", "count=%d %s" % [first, _motion()])
	var before: float = _field.sample(SOURCE, AetherField.Channel.WORK)
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.20)
	var after: float = _field.sample(SOURCE, AetherField.Channel.WORK)
	_check(is_equal_approx(after - before, 0.20), "imprint com amplitude real de place",
			"work %.6f -> %.6f delta_ponderado=%.6f" % [before, after, (after - before) * 0.35])
	_advance(6)
	_check(_wolf._scent_found and _wolf.get("_reaction") == "farejando",
			"construcao .20 reabre local antes dos 30s", _motion())
	_advance(45)
	_check(_wolf.mind.count_kind("scent_work") == 2,
			"construcao renovada termina segunda visita", "count=%d %s" % [_wolf.mind.count_kind("scent_work"), _motion()])
	return true


func _test_cache_cap() -> bool:
	# O cache de celulas checadas tem dois limites: o teto de SCENT_MEMORY_CAP e o relogio
	# de SCENT_MEMORY_SECONDS. Nao ha escrita continua: o unico ponto de entrada e o fim de
	# uma inspecao, que grafa um bloco 3x3 em torno da celula encontrada (wolf.gd:283-293).
	# O que manda no tamanho e portanto o intervalo entre inspecoes: com o relogio de 30s
	# cabem floor(30/intervalo)+1 blocos, e o teto de 32 celulas so e tocado quando entra o
	# quarto bloco, ou seja, intervalo de 10s para baixo. A cadeia abaixo sao seis fontes
	# reais em zigue-zague, forcadas em ordem de forca decrescente, e o que se colhe e o
	# instante de cada chegada, o pico do cache, a idade de cada saida e quantos metros o
	# corpo anda por salto. Com isso a checagem diz qual dos dois limites manda hoje, e em
	# que numero a evicao deixaria de ser codigo morto.
	_arm(Vector3(46.0, 51.001, 54.0))
	var cap: int = Wolf.SCENT_MEMORY_CAP
	var ttl: float = Wolf.SCENT_MEMORY_SECONDS
	var spots: Array[Vector3] = [Vector3(46.0, 50.6, 54.0), Vector3(58.0, 50.6, 54.0),
			Vector3(70.0, 50.6, 54.0), Vector3(70.0, 50.6, 66.0), Vector3(58.0, 50.6, 66.0),
			Vector3(46.0, 50.6, 66.0)]
	var amps: Array[float] = [0.84, 0.78, 0.72, 0.66, 0.60, 0.54]
	for i: int in spots.size():
		_field.imprint(spots[i], AetherField.Channel.WORK, amps[i])
	var cache: Dictionary = _wolf.get("_checked_scents")
	var peak: int = cache.size()
	var walked: float = 0.0
	var last_feet: Vector3 = _wolf.body.feet_pos
	var exits: Dictionary = {}
	var arrivals: Array[float] = []
	var episodes: int = _wolf.mind.count_kind("scent_work")
	for i: int in 2000:
		_advance(1)
		peak = maxi(peak, cache.size())
		walked += _horizontal(_wolf.body.feet_pos - last_feet).length()
		last_feet = _wolf.body.feet_pos
		if _wolf.mind.count_kind("scent_work") > episodes:
			episodes += 1
			arrivals.append(_wolf._scent_clock)
			print("CHEGADA %d tick=%d celula=%s cache=%d" % [episodes, _clock.tick, _wolf._scent_cell, cache.size()])
		# Colher na cadencia da percepcao: a varredura de expiracao roda dentro de
		# _find_scent, entao uma saida so pode aparecer num tick em que o scan aconteceu.
		if _clock.tick % 5 == 0:
			var clock: float = _wolf._scent_clock
			for k: Vector3i in cache.keys():
				if not exits.has(k):
					exits[k] = Vector3(float(cache[k].y) - ttl, -1.0, 0.0)
			for k: Vector3i in exits.keys():
				if exits[k].y < 0.0 and not cache.has(k):
					# o tamanho do cache no frame da coleta diz de qual limite saiu:
					# no teto e evicao por FIFO; abaixo dele so o relogio cortava
					exits[k] = Vector3(exits[k].x, clock, float(cache.size()))
			if episodes == spots.size():
				break
	var min_exit: float = 1e9
	var max_exit: float = -1.0
	var gone: int = 0
	var por_evicao: int = 0
	var pico_na_saida: int = 0
	for k: Vector3i in exits.keys():
		if exits[k].y >= 0.0:
			var age: float = exits[k].y - exits[k].x
			min_exit = minf(min_exit, age)
			max_exit = maxf(max_exit, age)
			gone += 1
			if age < ttl - 0.001:
				por_evicao += 1
				pico_na_saida = maxi(pico_na_saida, int(exits[k].z))
	var idade: float = _wolf._scent_clock
	var pace: float = walked / idade
	var gaps: float = 0.0
	for i: int in range(1, arrivals.size()):
		gaps += arrivals[i] - arrivals[i - 1]
	var intervalo: float = gaps / float(maxi(arrivals.size() - 1, 1))
	var salto: float = 0.0
	for i: int in range(1, spots.size()):
		salto += _horizontal(spots[i] - spots[i - 1]).length()
	salto /= float(spots.size() - 1)
	var metros_por_salto: float = walked / float(maxi(arrivals.size() - 1, 1))
	var progressao: float = salto / maxf(intervalo, 0.001)
	# O modelo do proprio codigo: um bloco 3x3 por inspecao, vivo por ttl. Com o relogio
	# de 30s cabem floor(30/intervalo)+1 blocos, entao o pedido e 9 x blocos celulas e o
	# cache fica no menor dos dois limites. Nenhuma checagem abaixo escolhe regime: elas
	# fecham o numero contra o modelo e dizem, pelo que imprimem, qual limite mandou.
	var blocos: int = int(floorf(ttl / maxf(intervalo, 0.001))) + 1
	var predicted: float = 9.0 * float(blocos)
	var limite: float = minf(float(cap), predicted)
	_check(episodes == spots.size() and arrivals.size() >= 4 and gone > 0,
			"premissa: seis inspecoes reais e uma janela inteira de saidas colhida",
			"episodios=%d chegadas=%d saidas=%d vistas=%d idade=%.3f" % [
			episodes, arrivals.size(), gone, exits.size(), idade])
	_check(peak <= cap, "cache nunca passa do teto de 32 celulas",
			"pico=%d teto=%d vistas=%d" % [peak, cap, exits.size()])
	_check(por_evicao == 0 or pico_na_saida >= cap,
			"saida mais jovem que o relogio so existe com o teto em jogo",
			"por_relogio=%d por_evicao=%d tamanho_na_saida=%d saida_mais_jovem=%.3f mais_velha=%.3f ttl=%.1f" % [
			gone - por_evicao, por_evicao, pico_na_saida, min_exit, max_exit, ttl])
	_check(peak == int(limite), "o cache fecha no menor dos dois limites, o teto ou a janela",
			"intervalo=%.3f janela=%.3f blocos=%d pedido=%.0f teto=%d pico=%d saltocelula=%.1f metros_por_salto=%.1f progressao=%.3f m/s=%.3f" % [
			intervalo, ttl, blocos, predicted, cap, peak, salto, metros_por_salto, progressao, pace])
	_check((por_evicao > 0) == (predicted > float(cap)),
			"a evicao por FIFO roda exatamente quando a janela pede mais celulas que o teto",
			"por_evicao=%d pedido=%.0f teto=%d intervalo=%.3f" % [
			por_evicao, predicted, cap, intervalo])
	return true


func _test_locomotion_flat() -> bool:
	# O integrador resolve os tres eixos na mesma chamada e marca bloqueio em qualquer um
	# deles, inclusive no Y quando o corpo desce contra o chao onde ja esta apoiado
	# (voxel_body.gd:52-54, :98). O passo do lobo le esse flag como parede (wolf.gd:537)
	# e re-arma o desvio; se estava apoiado, ainda salta ([:538-541]). Este cenario colhe
	# o corredor sem solido: 26 m de plateu lisa, a presa a vista o tempo todo, e aqui o
	# alvo e `hunt` e nao `investigate` porque o rastro de WORK so e lido num janela de
	# 7x7 celulas em torno do corpo ([:467], [:472-474]) -- uma fonte a 32 m nunca virou
	# investigacao e o que se colheu na primeira tentativa foi o andar da patrulha.
	# Colhe-se: frames de fisica, quantos o corpo passou apoiado, quantos desses o
	# integrador chamou de bloqueio, quantos lancamentos de 5,2 m/s sairam dai e quantos
	# metros o corpo andou por metro ganho. O contador de salto nao pode ser
	# `velocity.y == 5.2`: no build oficial o Vector3 e float32 e o literal e double, e a
	# igualdade e falsa para todo salto (medido: 19 lancamentos, 0 por igualdade). Nada
	# aqui decide ainda: os numeros vao para o commit do conserto, onde a mesma colheita
	# tem de cair a zero sem apagar o desvio do cenario da parede.
	_arm(Vector3(44.0, 51.001, 54.0), Vector3(70.0, 51.001, 54.0))
	var target: Vector3 = _player.position3()
	_advance(1, false)
	var solids: int = 0
	var heights: Dictionary = {}
	for x: int in range(40, 85):
		for z: int in range(40, 85):
			heights[_world.surface_height(x, z)] = true
			for y: int in range(51, 57):
				if _world.is_solid_xyz(x, y, z):
					solids += 1
	var frames: int = 0
	var apoiados: int = 0
	var bloqueados: int = 0
	var pouso_bloqueado: int = 0
	var rearms: int = 0
	var lancamentos: int = 0
	var horizontais: int = 0
	var fora_da_plateau: int = 0
	var walked: float = 0.0
	var last: Vector3 = _wolf.body.feet_pos
	var start: Vector3 = _wolf.body.feet_pos
	var ticks: int = 0
	var hunt_ticks: int = 0
	for i: int in 600:
		ticks += 1
		_advance(1, false)
		if _wolf.intent == "hunt":
			hunt_ticks += 1
		for f: int in 3:
			var sticking_before: float = _wolf._unstick
			_wolf._physics_process(SimClock.STEP / 3.0)
			frames += 1
			walked += _horizontal(_wolf.body.feet_pos - last).length()
			last = _wolf.body.feet_pos
			if _wolf.body.on_ground:
				apoiados += 1
			if _wolf.body.blocked_this_frame:
				bloqueados += 1
			if _wolf.body.blocked_horizontal:
				horizontais += 1
			if _wolf.body.on_ground and _wolf.body.blocked_this_frame:
				pouso_bloqueado += 1
			# o re-arme acontece no mesmo frame em que o desvio expira: a linha 527 desconta
			# o ultimo pedaco e a 538 ja sorteia outro, entao a transicao por `<= 0` nao ve
			if _wolf._unstick > sticking_before + 0.05:
				rearms += 1
			# 5,2 e o impulso do salto (wolf.gd:541); no frame seguinte a gravidade ja o
			# levou abaixo de 5, entao cada frame acima disso e um lancamento novo
			if _wolf.body.velocity.y > 5.0:
				lancamentos += 1
			var feet := _wolf.body.feet_pos
			if feet.x < 40.0 or feet.x > 84.0 or feet.z < 40.0 or feet.z > 84.0:
				fora_da_plateau += 1
		if _distance(target) < 2.5:
			break
	var ganho: float = _horizontal(_wolf.body.feet_pos - start).length()
	var razao: float = walked / maxf(ganho, 0.001)
	var tempo: float = float(frames) * (SimClock.STEP / 3.0)
	_check(solids == 0 and heights.size() == 1 and int(heights.keys()[0]) == 50
			and fora_da_plateau == 0 and _wolf._los_player and hunt_ticks >= ticks - 1,
			"premissa: plateu 45x45 sem nenhum solido acima do piso, corpo dentro dela, presa a vista",
			"solidos=%d alturas=%s fora=%d los=%s hunt=%d/%d ticks=%d" % [
			solids, heights.keys(), fora_da_plateau, _wolf._los_player, hunt_ticks, ticks, ticks])
	_check(apoiados > 0 and bloqueados > 0 and pouso_bloqueado >= int(float(apoiados) * 0.9),
			"premissa: dos frames em que o corpo esteve apoiado, quase todos o integrador chamou bloqueio",
			"apoiados=%d bloqueados=%d pouso_bloqueado=%d frames=%d lancamentos=%d rearms=%d" % [
			apoiados, bloqueados, pouso_bloqueado, frames, lancamentos, rearms])
	_check(_distance(target) < 2.5, "o corpo alcanga a presa no corredor livre",
			"percorrido=%.1f ganho=%.1f razao=%.3f rearms=%d lancamentos=%d tempo=%.1f s andamento=%.3f m/s speed=%.1f SPEED_RUN=%.1f" % [
			walked, ganho, razao, rearms, lancamentos, tempo, ganho / maxf(tempo, 0.001), _wolf._speed, Wolf.SPEED_RUN])
	_check(horizontais == 0 and rearms == 0 and lancamentos == 0,
			"contato com o chao nao e obstaculo: sem parede no caminho, nenhum desvio re-arma e nenhum corpo salta",
			"horizontais=%d rearms=%d lancamentos=%d bloqueados=%d pouso_bloqueado=%d frames=%d" % [
			horizontais, rearms, lancamentos, bloqueados, pouso_bloqueado, frames])
	return true


func _test_locomotion_wall() -> bool:
	# O outro braco da atribuicao. O conserto nao pode apagar o desvio diante de um
	# solido de verdade: com parede no caminho o integrador ainda chama bloqueio em X/Z,
	# o passo ainda re-arma e ainda salta. A parede e a mesma do cenario de avistamento
	# (_wall: x=63, seis blocos de altura, a plateau inteira em z) e o alvo e um rastro
	# de WORK atras dela -- ca o intent nao pode ser hunt, porque a linha de visada morre
	# no solido (wolf.gd:441) e sem visada nao ha caca. O que os dois bracos comparam e
	# o caminho, nao a decisao: mesmo chao plano de y=50, mesmo integrador, mesma
	# cadencia de frames, so muda o solido entre o corpo e o alvo.
	#
	# A quinta checagem deste cenario colhe outro defeito, visto pela primeira vez na
	# suite inteira depois do conserto do passo: o corpo encosta na parede e o
	# integrador aceita o passo com a face de fora 1 mm DENTRO do solido, porque o teste
	# de X rala a caixa (box.size.x -= WALL_SHAVE, o 1 mm da constante em
	# voxel_body.gd:9) e o resultado aplicado nao e a caixa testada. Encostado, para o
	# smoke ele esta encaixado
	# ("nenhum lobo com o corpo dentro do terreno" mediu encaixados=1 lobo1 em
	# (56.62563, 36.39333, 23.29462) em tres corridas seguidas), e o resgate vertical
	# nao alcanca um pillar de rocha: medido na sonda, o lift necessario era nenhum
	# (pra cima=-1, pra baixo=-1 nos 4 m varridos) e o lobo congela la dentro.
	_arm(Vector3(54.0, 51.001, 54.0), FAR_PLAYER)
	_wall(BlockDefs.Block.STONE)
	_field.imprint(Vector3(66.0, 50.6, 54.0), AetherField.Channel.WORK, 0.9)
	_advance(1, false)
	var frames: int = 0
	var apoiados: int = 0
	var bloqueados: int = 0
	var horizontais: int = 0
	var rearms: int = 0
	var lancamentos: int = 0
	var pouso_bloqueado: int = 0
	var invest_ticks: int = 0
	var x_max: float = 0.0
	var ticks: int = 0
	var encaixados: int = 0
	var encaixe_mm: float = 0.0
	for i: int in 200:
		ticks += 1
		_advance(1, false)
		if _wolf.intent == "investigate":
			invest_ticks += 1
		for f: int in 3:
			var sticking_before: float = _wolf._unstick
			_wolf._physics_process(SimClock.STEP / 3.0)
			frames += 1
			x_max = maxf(x_max, _wolf.body.feet_pos.x)
			if _wolf.body.on_ground:
				apoiados += 1
				if _wolf.body.blocked_this_frame:
					pouso_bloqueado += 1
			if _wolf.body.blocked_this_frame:
				bloqueados += 1
			if _wolf.body.blocked_horizontal:
				horizontais += 1
			if _wolf._unstick > sticking_before + 0.05:
				rearms += 1
			if _wolf.body.velocity.y > 5.0:
				lancamentos += 1
			# Encosto ou encaixe? O que a checagem abaixo exige e o volume do corpo
			# inteiro fora de solido em todo frame. Quando ha sobreposicao, a sonda mede
			# tambem a profundidade: quanto falta empurrar o corpo de volta em -x ate
			# ele caber. No braco sem conserto a profundidade medida foi exatamente 1 mm
			# -- o WALL_SHAVE (voxel_body.gd:9) que o teste de X aplicava, nao um
			# acidente do relevo.
			if _world.aabb_hits_solid(_wolf.body.aabb()):
				encaixados += 1
				var k: float = 0.0
				while k <= 0.05:
					var box := _wolf.body.aabb()
					box.position.x -= k
					if not _world.aabb_hits_solid(box):
						break
					k += 0.001
				encaixe_mm = maxf(encaixe_mm, k * 1000.0)
	_check(_world.is_solid_xyz(63, 52, 54) and not _wolf._los_player and invest_ticks >= ticks - 2
			and x_max > 60.0,
			"premissa: parede real no caminho e o corpo encosta nela atrae pelo rastro",
			"parede=%s los=%s investigate=%d/%d x_max=%.3f alvo=%s" % [
			_world.is_solid_xyz(63, 52, 54), _wolf._los_player, invest_ticks, ticks, x_max,
			_wolf._move_target])
	_check(horizontais > 0, "na parede o integrador chama bloqueio horizontal",
			"horizontais=%d bloqueados=%d frames=%d apoiados=%d pouso_bloqueado=%d" % [
			horizontais, bloqueados, frames, apoiados, pouso_bloqueado])
	_check(rearms > 0 and lancamentos > 0, "com parede de verdade o desvio re-arma e o corpo salta",
			"rearms=%d lancamentos=%d horizontais=%d frames=%d" % [
			rearms, lancamentos, horizontais, frames])
	_check(x_max < 63.0, "o corpo para do lado de ca da parede",
			"x_max=%.3f teto_bloqueio=63.0 percorrido=%.1f" % [x_max, x_max - 54.0])
	_check(encaixados == 0,
			"encostar na parede nao e encaixar: nenhum frame com o volume dentro de solido",
			"encaixados=%d encaixe_max=%.3f mm frames=%d x_max=%.3f face_x=%.4f" % [
			encaixados, encaixe_mm, frames, x_max, x_max + _wolf.body.dims.x * 0.5])
	_wall(BlockDefs.Block.AIR)
	return true


## Caverna sob o teto do palco: piso solido em y=44, ar em 45..47, teto em 48..50.
## A grade de Eter tem celula de 4 blocos (VoxelConfig.AETHER_CELL), entao o ar da
## caverna inteiro mora na camada 11 enquanto o lobo em cima do teto esta na camada 12.
func _cave_carve() -> void:
	for x: int in range(56, 74):
		for z: int in range(56, 70):
			_world.set_block(Vector3i(x, 44, z), BlockDefs.Block.STONE)
			for y: int in range(45, 48):
				_world.set_block(Vector3i(x, y, z), BlockDefs.Block.AIR)
			for y: int in range(48, 51):
				_world.set_block(Vector3i(x, y, z), BlockDefs.Block.STONE)


func _test_scent_cave_layer() -> bool:
	# O leitor varria uma camada de Eter so — a do lobo — e projetava o alvo na superficie
	# mais alta da coluna. Os dois bracos abaixo tem a mesma amplitude, o mesmo deslocamento
	# horizontal e a mesma distancia; so a camada de Y muda, entao o que separa um do outro e
	# a camada, nao a geometria do palco nem o alcance do raio.
	_cave_carve()
	var cave := Vector3(70.0, 46.0, 62.0)
	var above := Vector3(70.0, 51.0, 62.0)
	var cave_cell: Vector3i = _field.cell_of_world(cave)
	var above_cell: Vector3i = _field.cell_of_world(above)
	_arm(Vector3(62.0, 51.001, 62.0), FAR_PLAYER, 3)
	var wolf_cell: Vector3i = _field.cell_of_world(_wolf.center())
	_field.imprint(cave, AetherField.Channel.BLOOD, 0.42)
	_check(cave_cell.y == wolf_cell.y - 1
			and _horizontal(cave - _wolf.center()).length() <= float(Wolf.SCENT_RADIUS) * 4.0
			and is_equal_approx(_field.sample(cave, AetherField.Channel.BLOOD), 0.42),
			"premissa: rastro uma camada abaixo, dentro do raio horizontal",
			"lobo_cam=%d rastro_cam=%d dxz_cells=%d desloc=%.1f m amplitude=%.3f" % [
			wolf_cell.y, cave_cell.y, above_cell.x - wolf_cell.x,
			_horizontal(cave - _wolf.center()).length(),
			_field.sample(cave, AetherField.Channel.BLOOD)])
	_check(is_zero_approx(_field.sample_cell(
			Vector3i(cave_cell.x, wolf_cell.y, cave_cell.z), AetherField.Channel.BLOOD)),
			"premissa: a camada que o leitor varre esta vazia",
			"camada_do_lobo=%.4f camada_de_baixo=%.4f" % [_field.sample_cell(
			Vector3i(cave_cell.x, wolf_cell.y, cave_cell.z), AetherField.Channel.BLOOD),
			_field.sample_cell(cave_cell, AetherField.Channel.BLOOD)])
	_advance(1)
	_check(_wolf._scent_found and _wolf._scent_cell == cave_cell
			and _wolf._scent_channel == AetherField.Channel.BLOOD,
			"leitor acha o rastro uma camada abaixo",
			"found=%s celula=%s esperado=%s forca=%.4f intent=%s %s" % [
			_wolf._scent_found, _wolf._scent_cell, cave_cell, _wolf._scent_strength,
			_wolf.intent, _motion()])
	_check(_wolf._scent_pos.y < 48.0 and _wolf._scent_pos.y > 43.0,
			"alvo projetado no piso da caverna, nao no teto da superficie",
			"alvo=%s surface_height=%d" % [_wolf._scent_pos, _world.surface_height(
			int(_wolf._scent_pos.x), int(_wolf._scent_pos.z))])
	_arm(Vector3(62.0, 51.001, 62.0), FAR_PLAYER, 3)
	_field.imprint(above, AetherField.Channel.BLOOD, 0.42)
	_check(above_cell.y == wolf_cell.y
			and is_equal_approx(above.y - cave.y, 5.0)
			and is_zero_approx(_horizontal(above - cave).length()),
			"premissa do controle: mesma coluna, camada do lobo, 5 m mais alto",
			"lobo_cam=%d rastro_cam=%d vertical=%.1f m horizontal=%.3f m" % [
			wolf_cell.y, above_cell.y, above.y - cave.y, _horizontal(above - cave).length()])
	_advance(1)
	_check(_wolf._scent_found and _wolf._scent_cell == above_cell
			and absf(_wolf._scent_pos.y - 50.6) < 0.01,
			"controle: rastro na camada do lobo acha o alvo na superficie de sempre",
			"found=%s celula=%s alvo=%s forca=%.4f" % [
			_wolf._scent_found, _wolf._scent_cell, _wolf._scent_pos, _wolf._scent_strength])
	return true


## Premissa do dossie 09.1: o identificador de bioma tem de ser FUNCAO do mundo
## (seed, x, z, h), nao da instancia que o calcula. Duas `WorldGen` com a mesma
## semente, a mesma grade 16x16, e a contagem de celulas divergentes -- 0.
##
## A segunda checagem nao e enfeite: sem mais de um bioma na grade amostrada, a
## primeira passaria sobre um campo constante e "identico" nao decidiria nada.
func _test_biome() -> bool:
	var gen_a := WorldGen.new()
	var gen_b := WorldGen.new()
	gen_a.setup(SEED)
	gen_b.setup(SEED)
	var dif: int = 0
	var colunas: int = 0
	var census := {}
	for x: int in range(0, VoxelConfig.world_size_x(), 8):
		for z: int in range(0, VoxelConfig.world_size_z(), 8):
			var bi_a: int = gen_a.biome_of(x, z, gen_a.surface_height(x, z))
			var bi_b: int = gen_b.biome_of(x, z, gen_b.surface_height(x, z))
			colunas += 1
			census[bi_a] = int(census.get(bi_a, 0)) + 1
			if bi_a != bi_b:
				dif += 1
	var nomes := ""
	var biomas := 0
	for id: int in [WorldGen.Biome.FROZEN, WorldGen.Biome.ARID,
			WorldGen.Biome.TEMPERATE, WorldGen.Biome.WETLAND]:
		if int(census.get(id, 0)) > 0:
			biomas += 1
		nomes += "%s=%d " % [WorldGen.BIOME_NAMES[id], int(census.get(id, 0))]
	_check(dif == 0 and colunas == 256, "bioma_deterministico",
			"divergentes=%d  colunas=%d" % [dif, colunas])
	_check(biomas > 1, "premissa: a grade 16x16 cobre mais de um bioma",
			"biomas=%d  %s" % [biomas, nomes.strip_edges()])
	return true


## Lobo montado so para ler o pelo: casa na coluna (x, z) pela altura GERADA dela,
## sem andar e sem decidir nada.
func _lobo_na_coluna(x: int, z: int, pid: int) -> Wolf:
	var w := Wolf.new()
	_stage.add_child(w)
	w.setup(_world, _field, _player,
			Vector3(float(x), float(_world.gen.surface_height(x, z) + 1), float(z)),
			pid, _clock)
	return w


## Premissa 1 do dossie 09 no que o jogador ve: dois lobos em colunas de biomas
## diferentes tem de sair com material de pelo diferente, e dois lobos no mesmo
## bioma com a MESMA cor. As colunas nao sao sorteadas — sao a primeira e a ultima
## que o proprio `biome_at` do mundo gerado nomeia para cada bioma, porque "lobo
## no bioma X" so vale se o gen diz X. O numero que decide e o hex de cada pelo,
## impresso com o bioma do seu `home`.
func _test_fur_colour() -> bool:
	_arm()
	var primeira := {}
	var ultima := {}
	for x: int in range(6, VoxelConfig.world_size_x() - 6, 3):
		for z: int in range(6, VoxelConfig.world_size_z() - 6, 3):
			var b: int = _world.gen.biome_at(x, z)
			if not primeira.has(b):
				primeira[b] = Vector2i(x, z)
			ultima[b] = Vector2i(x, z)
	var achados: Array = []
	var nomes := ""
	for id: int in [WorldGen.Biome.FROZEN, WorldGen.Biome.ARID,
			WorldGen.Biome.TEMPERATE, WorldGen.Biome.WETLAND]:
		if primeira.has(id):
			achados.append(id)
			nomes += "%s " % WorldGen.BIOME_NAMES[id]
	_check(achados.size() >= 2, "premissa: a semente da colunas de dois biomas",
			"biomas=%d  %s" % [achados.size(), nomes.strip_edges()])
	var letras := ["a", "b", "c"]
	var lobos: Array = []
	var linhas := ""
	for i: int in range(3):
		var id: int = achados[0]
		if i == 1 and achados.size() > 1:
			id = achados[1]
		# a e c: mesmo bioma em colunas diferentes. b: o bioma seguinte da lista.
		var tabela: Dictionary = ultima if i == 2 else primeira
		var coluna: Vector2i = tabela[id]
		var lobo := _lobo_na_coluna(coluna.x, coluna.y, 90 + i)
		lobos.append(lobo)
		linhas += "%s[%s %s] " % [letras[i], WorldGen.BIOME_NAMES[id],
				lobo._fur.albedo_color.to_html(false)]
	_check(is_instance_valid(lobos[0]) and is_instance_valid(lobos[1])
			and is_instance_valid(lobos[2])
			and lobos[0]._fur.albedo_color != lobos[1]._fur.albedo_color
			and lobos[0]._fur.albedo_color == lobos[2]._fur.albedo_color,
			"cor_do_pelo_vem_do_bioma", linhas.strip_edges())
	for solto in lobos:
		solto.free()
	var cores := {}
	var tabela_hex := ""
	for cor in Wolf.FUR_COLORS:
		cores[cor.to_html(false)] = true
		tabela_hex += "%s " % cor.to_html(false)
	_check(cores.size() == Wolf.FUR_COLORS.size(),
			"premissa: os quatro pares da tabela dao quatro cores diferentes",
			"cores=%d/%d  %s" % [cores.size(), Wolf.FUR_COLORS.size(),
					tabela_hex.strip_edges()])
	_check(Wolf.FUR_COLORS[WorldGen.Biome.TEMPERATE] == Color(0.40, 0.36, 0.31),
			"temperate conserva a cor historica do lobo",
			"cor=%s" % Wolf.FUR_COLORS[WorldGen.Biome.TEMPERATE].to_html(false))
	return true


func _finish() -> void:
	Input.mouse_mode = _mouse_mode
	_check(_ran, "runner retornou", "run=%s" % _ran)
	_check(_completed == TESTS.size(), "censo de testes completos", "%d/%d" % [_completed, TESTS.size()])
	_check(_checks + 1 == EXPECTED_CHECKS, "censo de checagens", "%d/%d" % [_checks + 1, EXPECTED_CHECKS])
	print("CENARIO ESTREITO, NAO GATE P1: passos=%d sim_step total=%d us pico=%d us; BT last_us soma=%d pico=%d trips=%d" % [
		_steps, _sim_us, _sim_worst_us, _bt_us, _bt_worst_us, _bt_trips])
	if is_instance_valid(_stage):
		_stage.free()
	print("%d checagens %d falhas %.3f s" % [_checks, _failures, float(Time.get_ticks_usec() - _started_us) / 1000000.0])
	quit(1 if _failures > 0 else 0)
