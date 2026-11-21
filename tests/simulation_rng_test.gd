extends SceneTree

const Session = preload("res://src/main.gd")
const WORLD_SEED: int = 20261116
const SPAWN := Vector3(58.0, 51.001, 62.0)
const TESTS: Array[StringName] = [
	&"_test_fixture", &"_test_population", &"_test_patrol", &"_test_detour", &"_test_world_seed",
]
const EXPECTED_CHECKS: int = 27
const TICKS: int = 240

var _checks: int = 0
var _failures: int = 0
var _completed: int = 0
var _ran: bool = false
var _started_us: int = 0
var _mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _stage: Node3D
var _world: VoxelWorld
var _player: Player
var _patrol_signature: PackedByteArray
var _population_signature: Array


func _initialize() -> void:
	_started_us = Time.get_ticks_usec()
	_mouse_mode = Input.mouse_mode
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
	_world.generate(WORLD_SEED)
	_player = Player.new()
	_stage.add_child(_player)
	_player.setup(_world, Vector3(112.0, 51.001, 112.0))
	_check(_world.gen.world_seed == WORLD_SEED and _world.chunks.size() == 64,
			"mundo real", "seed=%d chunks=%d" % [_world.gen.world_seed, _world.chunks.size()])
	_check(_player.is_node_ready() and not _player.can_process() and _world.meshes_built() == 0,
			"sem input automatico, malharia ou save", "ready=%s process=%s meshes=%d" % [
			_player.is_node_ready(), _player.can_process(), _world.meshes_built()])
	return true


func _noise() -> void:
	for i: int in 23:
		randi()
		randf()


func _population(mode: int) -> Dictionary:
	seed(7301)
	var next_global: int = randi()
	seed(7301)
	var session := Session.new()
	session.world = _world
	session.aether = AetherField.new()
	session.aether.setup(_world)
	session.clock = SimClock.new()
	session.player = _player
	session._entities = Node3D.new()
	_stage.add_child(session._entities)
	if mode == 0:
		session._spawn_wolves(5)
	else:
		for i: int in 5:
			if mode == 1:
				_noise()
			session._spawn_wolves(1)
			if mode == 3 and i < session.wolves.size():
				(session.wolves[i] as Wolf)._leaf_wander({})
	var global_untouched: bool = randi() == next_global
	var signature: Array = []
	var valid: int = 0
	for wolf: Wolf in session.wolves:
		signature.append([wolf.identity, wolf.home, wolf._heading])
		if wolf.identity == valid and session._volume_clear(wolf.home, Wolf.DIMS) \
				and not _world.is_water_xyz(int(wolf.home.x), int(wolf.home.y), int(wolf.home.z)):
			valid += 1
	var ready: bool = session.is_node_ready()
	var fila: int = session._respawn_queue.size()
	session._entities.free()
	session.free()
	return {"signature": signature, "valid": valid, "ready": ready, "fila": fila,
		"global_untouched": global_untouched}


func _test_population() -> bool:
	var arms: Array[Dictionary] = [_population(0), _population(0), _population(1), _population(2), _population(3)]
	for i: int in arms.size():
		var borna: int = (arms[i]["signature"] as Array).size()
		# Censo variavel (dossie 14 §3.5): o que este braço pinça é a assinatura da
		# sequência, não "nasceram cinco". Um ponto recusado devolve a vaga para a
		# fila, então a conta que não pode fechar é matilha + fila != teto, e um
		# lobo livre que não bate com seu índice continua sendo defeito.
		_check(arms[i]["valid"] == borna and borna + int(arms[i]["fila"]) == Session.WOLF_COUNT
				and not arms[i]["ready"],
				"spawn real sem executar boot completo",
				"braco=%d livres=%d/%d fila=%d teto=%d ready=%s" % [
				i, arms[i]["valid"], borna, arms[i]["fila"], Session.WOLF_COUNT, arms[i]["ready"]])
	_population_signature = arms[0]["signature"]
	for i: int in range(1, arms.size()):
		var labels: Array[String] = ["", "repeticao de controle", "sorteios globais", "criacao em lotes distintos", "patrulha de outro lobo"]
		_check(_population_signature == arms[i]["signature"], "populacao independente: " + labels[i],
				"base=%s braco=%s" % [_population_signature, arms[i]["signature"]])
	_check(arms[0]["global_untouched"], "spawn e setup nao consomem RNG global", "preservado=%s" % arms[0]["global_untouched"])
	return true


func _flat_ground() -> void:
	for x: int in range(40, 85):
		for z: int in range(40, 85):
			_world.set_block(Vector3i(x, 50, z), BlockDefs.Block.STONE)
			for y: int in range(51, VoxelChunk.SIZE_Y):
				_world.set_block(Vector3i(x, y, z), BlockDefs.Block.AIR)


func _wall(block: int) -> void:
	for y: int in range(51, 56):
		for z: int in range(40, 85):
			_world.set_block(Vector3i(60, y, z), block)


func _trace(wolf_id: int, mode: int, blocked: bool = false) -> Dictionary:
	seed(921)
	var next_global: int = randi()
	seed(921)
	var field := AetherField.new()
	field.setup(_world)
	if blocked:
		field.imprint(Vector3(66.0, 50.6, 62.0), AetherField.Channel.WORK, 0.42)
	var clock := SimClock.new()
	var wolf := Wolf.new()
	_stage.add_child(wolf)
	wolf.setup(_world, field, _player, SPAWN, wolf_id, clock)
	var other: Wolf
	if mode == 2:
		var other_field := AetherField.new()
		other_field.setup(_world)
		other = Wolf.new()
		_stage.add_child(other)
		other.setup(_world, other_field, _player, SPAWN, 999, clock)
	var samples: Array = [[wolf._heading]]
	var blocked_frames: int = 0
	var detours: int = 0
	var targets: Dictionary = {}
	for tick: int in TICKS:
		if mode == 1:
			_noise()
		if other != null:
			other.sim_step(float(tick + 1) * SimClock.STEP, SimClock.STEP)
		wolf.sim_step(float(tick + 1) * SimClock.STEP, SimClock.STEP)
		clock.tick += 1
		targets[wolf._move_target] = true
		for frame: int in 3:
			if other != null:
				other._physics_process(SimClock.STEP / 3.0)
			var prior_detour: float = wolf._detour
			wolf._physics_process(SimClock.STEP / 3.0)
			if wolf.body.blocked_this_frame:
				blocked_frames += 1
			if wolf._detour != prior_detour:
				detours += 1
			samples.append([wolf.body.feet_pos, wolf.body.velocity, wolf._heading,
					wolf._move_target, wolf._wander_cd, wolf._unstick, wolf._detour, wolf.intent])
	var global_untouched: bool = randi() == next_global
	wolf.free()
	if other != null:
		other.free()
	var bytes: PackedByteArray = var_to_bytes(samples)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	return {"bytes": bytes, "hash": digest.finish().hex_encode(), "targets": targets.size(),
			"blocked": blocked_frames, "detours": detours, "global_untouched": global_untouched}


func _test_patrol() -> bool:
	_flat_ground()
	var base := _trace(1, 0)
	_patrol_signature = base["bytes"]
	_check(base["targets"] >= 2, "patrulha real renova destino", "ticks=%d destinos=%d" % [TICKS, base["targets"]])
	for mode: int in [0, 1, 2]:
		var arm := _trace(1, mode)
		_check(base["bytes"] == arm["bytes"], "patrulha independente por frame",
				"modo=%d base=%s braco=%s" % [mode, base["hash"], arm["hash"]])
	var different := _trace(2, 0)
	_check(base["bytes"] != different["bytes"], "identidades distintas tem sequencias distintas",
			"id1=%s id2=%s" % [base["hash"], different["hash"]])
	_check(base["global_untouched"], "patrulha nao consome RNG global", "preservado=%s" % base["global_untouched"])
	return true


func _test_detour() -> bool:
	_wall(BlockDefs.Block.STONE)
	var base := _trace(1, 0, true)
	_check(base["blocked"] > 0 and base["detours"] > 0, "rastro leva a colisao e desvio reais",
			"frames_bloqueados=%d desvios=%d" % [base["blocked"], base["detours"]])
	for mode: int in [1, 2]:
		var arm := _trace(1, mode, true)
		_check(base["bytes"] == arm["bytes"] and arm["detours"] > 0, "desvio independente por frame",
				"modo=%d desvios=%d base=%s braco=%s" % [mode, arm["detours"], base["hash"], arm["hash"]])
	_check(base["global_untouched"], "desvio nao consome RNG global", "preservado=%s" % base["global_untouched"])
	_wall(BlockDefs.Block.AIR)
	return true


func _test_world_seed() -> bool:
	_world.generate(WORLD_SEED + 1)
	var population := _population(0)
	_check(population["signature"] != _population_signature, "outra semente altera populacao",
			"seed=%d populacao=%s" % [_world.gen.world_seed, population["signature"]])
	_flat_ground()
	var trace := _trace(1, 0)
	_check(trace["bytes"] != _patrol_signature, "outra semente altera lobo de mesma identidade no mesmo piso",
			"seed=%d id=1 hash=%s" % [_world.gen.world_seed, trace["hash"]])
	return true


func _finish() -> void:
	Input.mouse_mode = _mouse_mode
	_check(_ran, "runner retornou", "run=%s" % _ran)
	_check(_completed == TESTS.size(), "censo de testes completos", "%d/%d" % [_completed, TESTS.size()])
	_check(_checks + 1 == EXPECTED_CHECKS, "censo de checagens", "%d/%d" % [_checks + 1, EXPECTED_CHECKS])
	if is_instance_valid(_stage):
		_stage.free()
	print("%d checagens %d falhas %.3f s" % [_checks, _failures, float(Time.get_ticks_usec() - _started_us) / 1000000.0])
	quit(1 if _failures > 0 else 0)
