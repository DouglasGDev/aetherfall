extends SceneTree

const Session = preload("res://src/main.gd")
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
	&"_test_biome", &"_test_fur_colour", &"_test_imprint_bias", &"_test_pack_provider",
	&"_test_rondar_setor", &"_test_cercar_assentos", &"_test_ataque_escalonado",
	&"_test_contagio_medo",
]
const EXPECTED_CHECKS: int = 146
# Copia LITERAL da tabela de vies medida nesta revisao (WorldGen.IMPRINT_BIAS), e
# nao uma leitura de la: o pino da checagem 4 do dossie 09 so tem como falhar
# quando a tabela do gen e editada se o par esperado vier de outro lugar.
const BIAS_MEDIDA: Array = [
	[0.85, 1.00, 1.30],    # frozen
	[1.30, 0.90, 0.85],    # arid
	[1.00, 1.00, 1.00],    # temperate
	[0.85, 1.15, 0.90],    # wetland
]

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
# Contadores da alcateia, separados dos de um lobo so: o rodape historico do
# runner e o que a rodada anterior publicou, e misturar nele o `sim_tick` da
# sessao (difusao incluida) quebraria a comparacao pareada branch x chao.
var _session: Session = null
var _pack_steps: int = 0
var _pack_sim_us: int = 0
var _pack_sim_worst_us: int = 0
var _pack_bt_us: int = 0
var _pack_bt_worst_us: int = 0
var _pack_bt_trips: int = 0
# Mordidas colhidas pelo sinal real `bit_player` da sessao, como
# [tick, identidade, n lido, rank lido, intent]: a contagem por tick e o numero que
# o escalonamento exige, e o sinal e a unica forma de ver a mordida sem ler um campo
# escrito a mao.
var _bite_events: Array = []

# Geometria da matilha no plateau da fixture: tres lobos se enxergam (8,5 m e
# 17 m), o quarto fica a 25,6 m do vizinho mais proximo -- do lado de la do raio
# de coesao de 24 m, entao a lista dele tem de vir vazia.
const PACK_SPOTS: Array = [
	Vector3(52.0, 51.001, 56.0), Vector3(58.0, 51.001, 62.0),
	Vector3(64.0, 51.001, 68.0), Vector3(84.0, 51.001, 84.0),
]

# Geometria fechada da ronda: quatro lobos a no maximo 8,9 m um do outro, todos
# dentro do raio de coesao, entao cada um le tres vizinhos (n = 4, fatia de 90
# graus). O baricentro cai exatamente no lobo 0 -- distancia horizontal dele ao
# centro e zero, o que da ao teste um centro conferivel a lapis.
const RONDAR_SPOTS: Array = [
	Vector3(58.0, 51.001, 62.0), Vector3(54.0, 51.001, 62.0),
	Vector3(58.0, 51.001, 66.0), Vector3(62.0, 51.001, 58.0),
]

# Geometria do cerco: presa no centro do plateau e quatro participantes a 8 m em
# cruz, todos dentro dos 30 m da LOS e dentro dos 24 m de coesao (o par mais
# distante fica a 16 m). Nem um deles comeca ao alcance da mordida, senao o ramo
# `morder` engoliria o ramo `perseguir` e o assento nunca seria escrito.
const CERCAR_PLAYER := Vector3(58.0, 51.001, 62.0)
const CERCAR_SPOTS: Array = [
	Vector3(50.0, 51.001, 62.0), Vector3(66.0, 51.001, 62.0),
	Vector3(58.0, 51.001, 54.0), Vector3(58.0, 51.001, 70.0),
]

# Geometria do ataque escalonado: quatro lobos JA dentro de `BITE_RANGE` (1,5 m
# horizontal, 1,56 m na conta 3D do `_sense`), todos com visada. Sem o
# escalonamento os quatro mordem no tick zero; com ele, cada assento morde no
# proprio assento morde na sua fase de tick.
const ESCALONAR_SPOTS: Array = [
	Vector3(59.5, 51.001, 62.0), Vector3(56.5, 51.001, 62.0),
	Vector3(58.0, 51.001, 63.5), Vector3(58.0, 51.001, 60.5),
]

# Geometria do contagio de medo: 20 m separam o observador (lobo 1) do vizinho que
# foge (lobo 0) -- dentro do raio de coesao de 24 m, mas a cinco celulas de Eter
# (AETHER_CELL = 4) um do outro, o que a difusao nao cruza na janela medida (3
# passadas em 16 ticks). O jogador fica a mais de 60 m dos dois e sem visada para
# nenhum, entao a base do observador e `patrol` e a `hunt` dele esta vetada.
const MEDO_SPOTS: Array = [
	Vector3(78.0, 51.001, 62.0), Vector3(58.0, 51.001, 62.0),
]


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


## Checagem 4 do dossie 09: o vies de imprint por bioma e do chamador, e os dois
## lados dessa fronteira tem de poder ficar vermelhos. A tabela esperada e a
## copia literal deste arquivo (BIAS_MEDIDA), nao uma leitura do gen: editar um
## multiplicador em WorldGen pinica vermelho. Mover o vies para dentro de
## `AetherField.imprint` pinica a fonte crua, que tem de devolver o valor do
## evento sem nada, e o helper do lobo passaria a multiplicar duas vezes. O
## numero que decide e o par sem/com por canal, a razao e o bioma da coluna.
func _test_imprint_bias() -> bool:
	var colunas := {}
	for x: int in range(6, VoxelConfig.world_size_x() - 6, 3):
		for z: int in range(6, VoxelConfig.world_size_z() - 6, 3):
			var b: int = _world.gen.biome_at(x, z)
			if not colunas.has(b):
				colunas[b] = Vector2i(x, z)
	# Pino linha a linha por leitura DIRETA da tabela, nao so pela composta: esta
	# semente nao expoe arid em nenhuma coluna do mundo, e uma linha sem casa nao
	# pode sair do gate sem conferencia. Onde existe coluna, a leitura composta
	# (biome_of -> linha -> canal) tambem tem de bater com a copia medida, senao
	# trocar a ordem das duas tabelas passaria. Guardas de forma antes de indexar
	# porque tabela encolhida tem de dar vermelho de checagem, nao de script.
	var pino_ok: bool = WorldGen.IMPRINT_BIAS.size() == BIAS_MEDIDA.size()
	var linhas_t := ""
	for bi: int in [WorldGen.Biome.FROZEN, WorldGen.Biome.ARID,
			WorldGen.Biome.TEMPERATE, WorldGen.Biome.WETLAND]:
		if bi >= WorldGen.IMPRINT_BIAS.size():
			pino_ok = false
			linhas_t += "%s sem linha; " % WorldGen.BIOME_NAMES[bi]
			continue
		var row: Array = WorldGen.IMPRINT_BIAS[bi]
		if row.size() != AetherField.Channel.COUNT:
			pino_ok = false
		var tem_casa: bool = colunas.has(bi)
		var cc: Vector2i = colunas[bi] if tem_casa else Vector2i(0, 0)
		var hh: int = _world.gen.surface_height(cc.x, cc.y) if tem_casa else 0
		for ch: int in AetherField.Channel.COUNT:
			var direto: float = float(row[ch]) if ch < row.size() else -1.0
			var medido: float = float(BIAS_MEDIDA[bi][ch])
			if absf(direto - medido) > 0.0001:
				pino_ok = false
			if tem_casa and absf(_world.gen.imprint_bias(cc.x, cc.y, hh, ch) - medido) > 0.0001:
				pino_ok = false
			linhas_t += "%s/%s=%.2f " % [WorldGen.BIOME_NAMES[bi],
					AetherField.CHANNEL_NAMES[ch], direto]
	_check(pino_ok, "premissa: vies_lido_confirma_tabela_medida", linhas_t.strip_edges())
	# A mesma fonte nos mesmos lugares, crua pelo campo e vies pelo helper do
	# lobo (o caminho real dos eventos), com as quantias lidas do proprio
	# batch: lavra WORK 0,42, morte BLOOD 1,3 e FEAR 1,0.
	var amounts: Array = [0.42, 1.3, 1.0]
	var crua_ok := true
	var ordem_ok := true
	var linhas_ab := ""
	var feitos := 0
	for bi: int in [WorldGen.Biome.FROZEN, WorldGen.Biome.ARID,
			WorldGen.Biome.TEMPERATE, WorldGen.Biome.WETLAND]:
		if not colunas.has(bi):
			continue
		var cc: Vector2i = colunas[bi]
		var hh: int = _world.gen.surface_height(cc.x, cc.y)
		var pos := Vector3(float(cc.x) + 0.5, float(hh + 1), float(cc.y) + 0.5)
		_arm()
		var bruto: Array = []
		for ch: int in AetherField.Channel.COUNT:
			_field.imprint(pos, ch, float(amounts[ch]))
			bruto.append(_field.sample(pos, ch))
		_arm()
		var vies: Array = []
		for ch: int in AetherField.Channel.COUNT:
			_wolf._imprint(pos, ch, float(amounts[ch]))
			vies.append(_field.sample(pos, ch))
		feitos += 1
		for ch: int in AetherField.Channel.COUNT:
			var medido: float = float(BIAS_MEDIDA[bi][ch])
			var b0: float = float(bruto[ch])
			var b1: float = float(vies[ch])
			var razao: float = b1 / maxf(b0, 1e-9)
			if not is_equal_approx(b0, float(amounts[ch])):
				crua_ok = false
			if not (is_equal_approx(b1, float(amounts[ch]) * medido)
					and absf(razao - medido) < 0.01
					and razao >= 0.5 and razao <= 2.0
					and b1 > 0.0 and b1 < AetherField.MAX_VALUE):
				ordem_ok = false
			linhas_ab += "bioma=%d(%s) %s sem=%.4f com=%.4f razao=%.4f  " % [
					bi, WorldGen.BIOME_NAMES[bi], AetherField.CHANNEL_NAMES[ch],
					b0, b1, razao]
	_check(crua_ok, "premissa: imprint cru no campo devolve o valor do evento",
			"esperado=%.2f/%.2f/%.2f  colhido: %s" % [
			float(amounts[0]), float(amounts[1]), float(amounts[2]), linhas_ab])
	_check(ordem_ok and feitos >= 2, "imprint_bioma_tem_mesma_ordem",
			"biomas_colhidos=%d  %s" % [feitos, linhas_ab.strip_edges()])
	# Media do vies por canal sobre as quatro linhas da tabela: o pedido e
	# redistribuicao, nao inflacao — a banda 1,00 +/- 0,10 contem os valores
	# medidos desta revisao (trabalho 1,0000; sangue e medo 1,0125), e uma linha
	# grossamente editada sai dela antes mesmo da leitura composta chegar ao
	# chamador. O pino acima e que confere multiplicador a multiplicador.
	var banda_ok: bool = WorldGen.IMPRINT_BIAS.size() == BIAS_MEDIDA.size()
	var soma_tab: Array[float] = [0.0, 0.0, 0.0]
	var linhas := 0
	for bi: int in [WorldGen.Biome.FROZEN, WorldGen.Biome.ARID,
			WorldGen.Biome.TEMPERATE, WorldGen.Biome.WETLAND]:
		if bi >= WorldGen.IMPRINT_BIAS.size() \
				or (WorldGen.IMPRINT_BIAS[bi] as Array).size() != AetherField.Channel.COUNT:
			banda_ok = false
			continue
		var rw: Array = WorldGen.IMPRINT_BIAS[bi]
		linhas += 1
		for ch: int in AetherField.Channel.COUNT:
			soma_tab[ch] += float(rw[ch]) / float(BIAS_MEDIDA.size())
	var medias := ""
	for ch: int in AetherField.Channel.COUNT:
		var m: float = soma_tab[ch]
		if m < 0.90 or m > 1.10:
			banda_ok = false
		medias += "%s=%.4f " % [AetherField.CHANNEL_NAMES[ch], m]
	_check(banda_ok, "media do vies por canal dentro da banda medida",
			"linhas=%d  %s" % [linhas, medias.strip_edges()])
	return true


# ------------------------------------------------------------------ alcateia (dossie 10)

## Sessao real (`main.gd`) fora da arvore de cenario, sobre o plateau da fixture:
## `pack_of`, `_rebuild_packs` e o `Callable` bindado sao os de `main.gd`, sem
## boot de HUD, oraculo e audio -- o mesmo truque de `simulation_rng_test.gd`. Os
## lobos vem do `_spawn_wolves` verdadeiro e sao reposicionados depois, porque a
## geometria de um gate tem de ser lida no log, nao sorteada.
func _pack_session(n: int) -> void:
	_pack_release()
	var s = Session.new()
	s.world = _world
	s.aether = _field
	s.clock = _clock
	s.player = _player
	s._entities = Node3D.new()
	_stage.add_child(s._entities)
	s._spawn_wolves(n)
	_session = s
	for i: int in mini(n, PACK_SPOTS.size()):
		_pack_place(i, PACK_SPOTS[i])


func _pack_place(i: int, spot: Vector3) -> void:
	var w: Wolf = _session.wolves[i]
	w.body.feet_pos = spot
	w.body.velocity = Vector3.ZERO
	w.home = spot
	w._move_target = spot


func _pack_release() -> void:
	if _session == null:
		return
	if is_instance_valid(_session._entities):
		_session._entities.free()
	_session.free()
	_session = null


func _pack_wolves() -> Array:
	return _session.wolves


func _wolf_of(ws: Array, ident: int) -> Wolf:
	for w: Wolf in ws:
		if w.identity == ident:
			return w
	return null


## Um passo de 20 Hz da sessao inteira, pelo caminho real (`_sim_tick`, com o
## rebuild antes do laco de lobos). O custo vai para os contadores da alcateia:
## somar `sim_tick` (que inclui a difusao) no rodape historico de lobo solo
## quebraria a comparacao pareada branch x chao das rodadas anteriores.
func _advance_pack(ticks: int, move_body: bool = false) -> void:
	for i: int in ticks:
		var trips_delta: int = 0
		for w: Wolf in _session.wolves:
			trips_delta -= w._guard.trips
		var start: int = Time.get_ticks_usec()
		_session._sim_tick()
		var cost: int = Time.get_ticks_usec() - start
		_pack_sim_us += cost
		_pack_sim_worst_us = maxi(_pack_sim_worst_us, cost)
		for w: Wolf in _session.wolves:
			_pack_bt_us += w._guard.last_us
			_pack_bt_worst_us = maxi(_pack_bt_worst_us, w._guard.last_us)
			trips_delta += w._guard.trips
		_pack_bt_trips += trips_delta
		_pack_steps += 1
		if move_body:
			for w: Wolf in _session.wolves:
				for frame: int in 3:
					w._physics_process(SimClock.STEP / 3.0)


func _pack_lists() -> String:
	var out := ""
	for w: Wolf in _pack_wolves():
		out += "lobo%d(%d viz) " % [w.identity, w._pack.size()]
	return out.strip_edges()


## Checagem 5 do dossie 10, mais o contrato de formato da leitura. O cursor da
## RNG da populacao e colhido sem consume-la: o estado e copiado para uma
## geradora descartavel e o proximo valor dela e a assinatura do cursor.
func _rng_cursor(rng: RandomNumberGenerator) -> float:
	var probe := RandomNumberGenerator.new()
	probe.state = rng.state
	return probe.randf()


func _test_pack_provider() -> bool:
	_arm()
	_pack_session(4)
	var ws: Array = _pack_wolves()
	var mounted := true
	var binds := ""
	for w: Wolf in ws:
		var bound: Array = w.pack_provider.get_bound_arguments()
		mounted = mounted and w.pack_provider.is_valid() and bound.size() == 1 \
				and int(bound[0]) == w.identity
		binds += "lobo%d bind=%s " % [w.identity, str(bound)]
	_check(mounted, "provedor_montado_pela_sessao", binds.strip_edges())
	# O lobo da fixture, armado sem sessao, nao pode ver matilha nenhuma: e o que
	# segura os 24 cenarios anteriores inteiros com a leitura nova no caminho.
	_advance(1)
	_check(not _wolf.pack_provider.is_valid() and _wolf._pack.is_empty(),
			"lobo sem provedor nao le matilha", "provedor=%s leitura=%d" % [
			_wolf.pack_provider.is_valid(), _wolf._pack.size()])
	# Um golpe real num da matilha, pela identidade e nao por campo escrito a mao:
	# `take_damage` e o unico caminho do jogo que escreve `relations`, e e o que da
	# ao trust publicado um valor proprio antes da conferencia de abaixo.
	(ws[0] as Wolf).take_damage(8.0, Wolf.ACTOR_PLAYER, _player.position3())
	_advance_pack(1)
	_check(int(_session._pack_pairs) == 6, "par_testado_uma_vez_por_passo",
			"pares=%d esperado=4x3/2=6 buffers=%d" % [
			_session._pack_pairs, _session._pack_buffers.size()])
	# Reconstrucao seca, sem passo no meio: assim o valor lido na lista e o valor
	# atual do vizinho e a conferencia e exata, nao uma aproximacao de intencoes.
	_session._rebuild_packs()
	var keys_ok := true
	var values_ok := true
	var viu_confianca := false
	var linhas := ""
	var confiancas := ""
	for w: Wolf in ws:
		var um_linhas := ""
		for e: Dictionary in w._pack:
			if e.size() != 5 or not e.has("identity") or not e.has("pos") \
					or not e.has("intent") or not e.has("hp_ratio") or not e.has("trust"):
				keys_ok = false
				continue
			var other: Wolf = _wolf_of(ws, int(e["identity"]))
			if other == null or not (e["pos"] as Vector3).is_equal_approx(other.center()) \
					or String(e["intent"]) != other.intent \
					or not is_equal_approx(float(e["hp_ratio"]), other.hp / Wolf.MAX_HP) \
					or not is_equal_approx(float(e["trust"]), other.trust_toward_player):
				values_ok = false
			if absf(float(e["trust"])) > 0.001:
				viu_confianca = true
			um_linhas += "%d:%.3f " % [int(e["identity"]), float(e["trust"])]
		linhas += "lobo%d<-[%s] " % [w.identity, _ids_of(w._pack)]
		confiancas += "lobo%d<-[%s] " % [w.identity, um_linhas.strip_edges()]
	_check(keys_ok, "leitura_barata_com_as_cinco_chaves",
			"chaves=identity,pos,intent,hp_ratio,trust  %s" % linhas.strip_edges())
	_check(values_ok, "leitura_barata_confere_valor_do_vizinho", confiancas.strip_edges())
	# O pino do trust so pode falhar se a leitura divergir do vizinho REAL, e contra
	# 0,0 default de uma mente que ninguem tocou ele nao decide nada: por isto a
	# premissa exige um valor proprio na mesa. A transicao e `take_damage`, unico
	# escritor de `relations` no jogo (`mind.adjust_trust(from_actor, -0,35)`),
	# chamada pela identidade e nao por um campo escrito a mao.
	_check(viu_confianca, "premissa: a leitura tem trust nao zero para conferir",
			confiancas.strip_edges())
	var sizes: Array[int] = []
	for w: Wolf in ws:
		sizes.append(w._pack.size())
	_check(sizes[0] == 2 and sizes[1] == 2 and sizes[2] == 2 and sizes[3] == 0,
			"raio_de_coesao_recorta_o_lobo_isolado",
			"tamanhos=%s  esperado=[2,2,2,0]  raio=%.1f m" % [sizes, Session.PACK_COHESION_RADIUS])
	var mutual := true
	for w: Wolf in ws:
		for e: Dictionary in w._pack:
			var other: Wolf = _wolf_of(ws, int(e["identity"]))
			if other == null or not other.alive or not _pack_lists_ids(other._pack).has(w.identity):
				mutual = false
	_check(mutual, "matilha_mutua", _pack_lists())
	# Prova de que `pack_of` devolve o buffer da sessao e nao uma copia: mexer no
	# buffer aparece na leitura do lobo, e o rebuild devolve o tamanho anterior.
	var buf: Array = _session.pack_of(int((ws[0] as Wolf).identity))
	var antes: int = buf.size()
	buf.resize(antes + 1)
	var visto: int = (ws[0] as Wolf)._pack.size()
	buf.resize(antes)
	_check(visto == antes + 1 and (ws[0] as Wolf)._pack.size() == antes,
			"pack_of_devolve_o_buffer_da_sessao",
			"buffer=%d leitura=%d restaurado=%d" % [antes + 1, visto, (ws[0] as Wolf)._pack.size()])
	# Passo com matilha completa de verdade, para a checagem 5 nao ser vazia.
	_pack_place(3, Vector3(PACK_SPOTS[0].x + 6.0, PACK_SPOTS[0].y, PACK_SPOTS[0].z))
	_advance_pack(1)
	var completa := true
	for w: Wolf in ws:
		completa = completa and w._pack.size() == 3
	_check(completa, "premissa: o passo da checagem 5 tem matilha completa", _pack_lists())
	var cursor_antes: float = _rng_cursor(_session._population_rng)
	seed(4242)
	var next_global: int = randi()
	_advance_pack(20)
	seed(4242)
	var global_preservado := randi() == next_global
	var cursor_depois: float = _rng_cursor(_session._population_rng)
	_check(cursor_depois == cursor_antes and global_preservado,
			"alcateia_nao_consome_rng_da_sessao",
			"cursor_population=%.8f->%.8f global_preservado=%s passos=%d  %s" % [
			cursor_antes, cursor_depois, str(global_preservado), _pack_steps, _pack_lists()])
	_pack_release()
	return true


## Checagem 1 do dossie 10 (ronda por setor). Premissa nomeada: quatro lobos que se
## leem dentro do raio de coesao patrulham fatias DISTINTAS do mesmo territorio, e um
## lobo sozinho patrulha literalmente como antes (centro = o proprio lar, fatia = TAU).
## O numero que decide nao e a distancia entre os alvos -- dois setores vizinhos podem
## dar pontos proximos por sorte -- e o angulo de cada alvo em torno do baricentro cair
## dentro da fatia do proprio rank, com o raio na faixa sorteada. O segundo braço e o
## replay a lapis da formula antiga: se o lote tivesse mudado a ronda solitaria por
## meio grau, os dois lados divergem.
func _test_rondar_setor() -> bool:
	_arm(SPAWN, FAR_PLAYER, 1)
	_advance(1, false)
	var replay := RandomNumberGenerator.new()
	replay.seed = ("wolf:%d:%d" % [_world.gen.world_seed, 1]).hash()
	replay.randf()					# _heading, consumido em setup()
	replay.randf_range(4.0, 9.0)		# _wander_cd, antes do sorteio do alvo
	var esperado := Vector3.ZERO
	for _t in 8:
		var a := replay.randf() * TAU
		var rad := replay.randf_range(5.0, Wolf.WANDER_RADIUS)
		var p := _wolf.home + Vector3(cos(a) * rad, 0.0, sin(a) * rad)
		p.x = clampf(p.x, 4.0, float(VoxelConfig.world_size_x()) - 4.0)
		p.z = clampf(p.z, 4.0, float(VoxelConfig.world_size_z()) - 4.0)
		if not _wolf._dry_ground(p):
			continue
		p.y = float(_world.surface_height(int(p.x), int(p.z))) + 0.2
		esperado = p
		break
	_check(_wolf.intent == "patrol" and _wolf.get("_reaction") == "patrulhando"
			and esperado == _wolf._move_target and _wolf._pack.is_empty(),
			"um_lobo_so_ronda_identico_a_formula_anterior",
			"intent=%s reaction=%s alvo=%s replay=%s leitura=%d" % [
			_wolf.intent, _wolf.get("_reaction"), _wolf._move_target, esperado, _wolf._pack.size()])
	_pack_session(4)
	for i: int in 4:
		_pack_place(i, RONDAR_SPOTS[i])
	# Baricentro a lapis dos quatro assentos, na horizontal: e o numero que a
	# sessao devolve e o numero que o teste confere, sem nenhum dos dois vindo do
	# proprio codigo do lobo.
	var bar := Vector3.ZERO
	for s: Vector3 in RONDAR_SPOTS:
		bar += s
	bar /= float(RONDAR_SPOTS.size())
	var n := RONDAR_SPOTS.size()
	var arc := TAU / float(n)
	_advance_pack(1)
	var ws: Array = _pack_wolves()
	var premissa_ok := true
	var lists := ""
	for w: Wolf in ws:
		premissa_ok = premissa_ok and w._pack.size() == n - 1 and w.intent == "patrol"
		lists += "lobo%d(%d viz,intent=%s) " % [w.identity, w._pack.size(), w.intent]
	_check(premissa_ok, "premissa: os quatro se leem por inteiro e patrulham",
			"n=%d  %s" % [n, lists.strip_edges()])
	var assentos: Array[float] = []
	var distintos := true
	var dentro := true
	var centro_ok := true
	var linhas := ""
	var lares_fora := 0
	for w: Wolf in ws:
		var rank := w._territory_rank()
		var seat := float(rank) * arc
		assentos.append(seat)
		var c: Vector3 = w._territory_center(n)
		if _horizontal(c - bar).length() > 0.001:
			centro_ok = false
		if _horizontal(c - w.home).length() > 3.0:
			lares_fora += 1
		var v := _horizontal(w._move_target - c)
		var rel := wrapf(atan2(v.z, v.x) - seat, 0.0, TAU)
		if rel > arc or v.length() < 5.0 or v.length() > Wolf.WANDER_RADIUS \
				or w.get("_reaction") != "rondando setor da matilha":
			dentro = false
		linhas += "lobo%d rank=%d rel=%.4f raio=%.2f reaction=%s alvo=%s " % [
				w.identity, rank, rel, v.length(), w.get("_reaction"), w._move_target]
	for i in assentos.size():
		for j in range(i + 1, assentos.size()):
			if absf(assentos[i] - assentos[j]) < 1e-6:
				distintos = false
	_check(distintos and assentos.size() == n, "ronda_assentos_distintos_por_rank",
			"assentos=%s n=%d fatia=%.4f rad" % [assentos, n, arc])
	_check(dentro, "ronda_alvo_dentro_da_fatia_do_proprio_rank", linhas.strip_edges())
	# O baricentro tem de ser um so para a matilha inteira e tem de ser outro ponto
	# para quem nao nasceu nele: sem a segunda metade, "territorio compartilhado"
	# poderia estar virando `home` por outra porta.
	_check(centro_ok and lares_fora == n - 1,
			"ronda_centro_e_baricentro_e_nao_o_lar_do_lobo",
			"baricentro=%s lares_fora=%d/%d  %s" % [bar, lares_fora, n, _territory_lines(ws)])
	return true


## Linha de conferencia do territorio: o que cada lobo devolve como centro e o que
## ele chama de lar. Sem isto, "centro compartilhado" poderia estar virando home.
func _territory_lines(ws: Array) -> String:
	var out := ""
	for w: Wolf in ws:
		out += "lobo%d centro=%s home=%s " % [
				w.identity, _horizontal(w._territory_center(4)), _horizontal(w.home)]
	return out.strip_edges()


## Checagem 2 do dossie 10 (`cercar_calcula_assentos`). Premissa nomeada: n
## participantes do MESMO alvo produzem n assentos distintos, espacados por TAU/n,
## todos a alcance de mordida sem subir em cima do corpo. O angulo esperado sai
## calculado aqui, a partir da lista de lobos e da identidade de cada um, e nao de
## `_hunt_pack_rank`: conferir o codigo contra ele mesmo nao pode falhar.
func _test_cercar_assentos() -> bool:
	_arm(SPAWN, CERCAR_PLAYER)
	_pack_session(4)
	for i: int in 4:
		_pack_place(i, CERCAR_SPOTS[i])
	# Quatro passos de aquecimento: no primeiro o `intent` que a leitura devolve
	# ainda e `patrol`, e um cerco montado sobre censo zero nao e cerco nenhum.
	_advance_pack(4)
	_session._rebuild_packs()
	var ws: Array = _pack_wolves()
	var ppos: Vector3 = _player.position3()
	var hunt_ok := true
	var n_hunt := 0
	var linhas := ""
	for w: Wolf in ws:
		var vizinhos := 0
		for e: Dictionary in w._pack:
			if String(e["intent"]) == "hunt":
				vizinhos += 1
		hunt_ok = hunt_ok and w.intent == "hunt" and w._los_player and vizinhos == 3
		if w.intent == "hunt":
			n_hunt += 1
		linhas += "lobo%d intent=%s los=%s viz_hunt=%d ang=%.4f dist=%.4f " % [
				w.identity, w.intent, w._los_player, vizinhos,
				_seat_angle(w._move_target, ppos), _horizontal(w._move_target - ppos).length()]
	_check(hunt_ok and n_hunt == 4, "premissa: os quatro perseguem a presa visivel",
			"participantes=%d  %s" % [n_hunt, linhas.strip_edges()])
	var angulos: Array[float] = []
	var distancias: Array[float] = []
	var assentos_ok := true
	var anel_ok := true
	for w: Wolf in ws:
		var rank := _participantes_antes_de(w, ws)
		var ang := _seat_angle(w._move_target, ppos)
		if absf(ang - wrapf(TAU * float(rank) / 4.0, 0.0, TAU)) > 1e-4:
			assentos_ok = false
		var d := _horizontal(w._move_target - ppos).length()
		if d <= 0.9 or d > Wolf.BITE_RANGE:
			anel_ok = false
		angulos.append(ang)
		distancias.append(d)
	_check(assentos_ok, "cercar_assentos_distintos_espacados_por_tau_over_n",
			"angulos=%s n=4 espacamento=%.4f" % [angulos, TAU / 4.0])
	_check(anel_ok, "cercar_assento_a_alcance_de_mordida_sem_subir_na_presa",
			"distancias=%s ring=%.3f bite_range=%.3f" % [
			distancias, Wolf.ENCIRCLE_RING, Wolf.BITE_RANGE])
	# Contraste obrigatorio do dossie: o MESMO cenario com um lobo so nao pode
	# devolver o mesmo numero. Se o anel fosse um angulo fixo, ou se `n` fosse o
	# censo da matilha em vez dos participantes, as duas corridas concordariam.
	var alvo_matilha: float = distancias[0]
	_pack_session(1)
	_pack_place(0, CERCAR_SPOTS[0])
	_advance_pack(4)
	var solo: Wolf = _pack_wolves()[0]
	var alvo_solo: float = _horizontal(solo._move_target - _player.position3()).length()
	_check(solo.intent == "hunt" and solo._los_player \
			and solo._move_target == _player.position3() + Vector3(0.0, 0.4, 0.0) \
			and absf(alvo_matilha - alvo_solo) > 0.5,
			"cercar_contraste_um_lobo_contra_quatro_diverge",
			"dist_solo=%.4f dist_matilha=%.4f reaction_solo=%s n_lido=%d" % [
			alvo_solo, alvo_matilha, solo.get("_reaction"), solo._hunt_pack_size()])
	# Terceira checagem, a que pega o "espacamento derivado de quem participa, e nao
	# do censo": uma parede real entre o lobo 0 e a presa tira o `hunt` dele pela
	# porta do proprio codigo (sem visada nao ha caca), sem tira-lo do raio de
	# coesao. Se o angulo saida de `n = matilha`, os tres que enxergam continuariam
	# em TAU/4 e o rank do lobo 3 seria 3 -- aqui ele tem de ser 2.
	var parede: Array = [
		Vector3(70.0, 51.001, 62.0), Vector3(50.0, 51.001, 62.0),
		Vector3(58.0, 51.001, 54.0), Vector3(58.0, 51.001, 70.0),
	]
	_pack_session(4)
	_wall(BlockDefs.Block.STONE)
	for i: int in 4:
		_pack_place(i, parede[i])
	_advance_pack(6)
	_session._rebuild_packs()
	var ws2: Array = _pack_wolves()
	var vitima: Wolf = ws2[0]
	var restantes: Array = []
	var cegas := ""
	for w: Wolf in ws2:
		var viz_hunt := 0
		for e: Dictionary in w._pack:
			if String(e["intent"]) == "hunt":
				viz_hunt += 1
		cegas += "lobo%d intent=%s los=%s viz_hunt=%d ang=%.4f " % [
				w.identity, w.intent, w._los_player, viz_hunt,
				_seat_angle(w._move_target, ppos)]
		if w != vitima and w.intent == "hunt":
			restantes.append(w)
	var espac_ok := restantes.size() == 3 and not vitima._pack.is_empty()
	for k: int in restantes.size():
		var w: Wolf = restantes[k]
		if absf(_seat_angle(w._move_target, ppos) - wrapf(TAU * float(k) / 3.0, 0.0, TAU)) > 1e-4:
			espac_ok = false
	_wall(BlockDefs.Block.AIR)
	_check(not vitima._los_player and vitima.intent != "hunt" and espac_ok,
			"cercar_espacamento_segue_os_participantes",
			"sem_visada=%d restantes=%d espacamento=%.4f  %s" % [
			0 if vitima._los_player else 1, restantes.size(), TAU / 3.0, cegas.strip_edges()])
	return true


## Checagem 3 do dossie 10 (`ataque_escalonado`). Premissa nomeada: quatro lobos em
## cerco, todos a alcance de mordida e com o cooldown zerado, nao mordem no mesmo
## tick. O numero e a contagem de mordidas por tick: `pior_tick` tem de ser 1, as
## quatro mordidas tem de cair em quatro ticks seguidos, e cada uma na fase em que o
## proprio rank casa com `clock.tick % n` -- com n = 4 e os quatro caando, o rank de
## cada um e a sua identidade, entao mordida fora desta igualdade veio de outra porta.
## O segundo braco e a referencia do relogio: as duas corridas entram no alcance em
## fases de tick diferentes, decididas pelo teste e nao pelo acaso. O mapa {fase ->
## identidade} e o mesmo nas duas, e o lobo que morde no tick da entrada e o da fase
## daquela entrada (0 na primeira, 1 na segunda). Tempo de parede, ou "tempo desde
## que entrou no alcance", dariam o lobo 0 mordendo na entrada das duas corridas.
func _test_ataque_escalonado() -> bool:
	_arm(SPAWN, CERCAR_PLAYER)
	var corrida_a := _corrida_mordidas(0, 6)
	# Contraste: os quatro candidatos do primeiro tick saem do estado real deles
	# (cooldown zerado e corpo dentro do alcance), medido antes da entrada -- sem o
	# escalonamento os quatro morderiam no tick zero, como mordiam antes do lote.
	_check(corrida_a["aquecimento"] >= 0 and corrida_a["prontos"] == 4
			and corrida_a["candidatos"] == 4 and corrida_a["n_cheio"]
			and corrida_a["mordidas"] == 4 and corrida_a["no_pior_tick"] == 1
			and corrida_a["consecutivos"] and corrida_a["fora_de_fase"] == 0,
			"ataque_mordidas_nunca_no_mesmo_tick",
			"mordidas=%d pior_tick=%d consecutivos=%s candidatos=%d prontos=%d aquecimento_tick=%d fora_de_fase=%d eventos=%s" % [
			corrida_a["mordidas"], corrida_a["no_pior_tick"],
			str(corrida_a["consecutivos"]), corrida_a["candidatos"],
			corrida_a["prontos"], corrida_a["aquecimento"],
			corrida_a["fora_de_fase"], corrida_a["eventos"]])
	# O segundo braco re-arma o cenario: campo, relogio e seed voltam ao mesmo ponto
	# de partida, entao a unica diferenca declarada entre as corridas e a fase de
	# `clock.tick` em que os quatro entram no alcance -- nao o sangue e o medo que a
	# primeira corrida deixou no ar.
	_pack_release()
	_arm(SPAWN, CERCAR_PLAYER)
	var corrida_b := _corrida_mordidas(1, 6)
	var fases_iguais: bool = corrida_a["fase"].size() == 4 and corrida_b["fase"].size() == 4
	for phase: int in 4:
		if not corrida_a["fase"].has(phase) or not corrida_b["fase"].has(phase) \
				or int(corrida_a["fase"][phase]) != int(corrida_b["fase"][phase]):
			fases_iguais = false
	_check(fases_iguais and not corrida_a["fase_disputada"]
			and not corrida_b["fase_disputada"] and corrida_b["prontos"] == 4
			and corrida_b["candidatos"] == 4 and corrida_b["n_cheio"]
			and corrida_b["mordidas"] == 4 and corrida_b["no_pior_tick"] == 1
			and corrida_b["consecutivos"] and corrida_b["fora_de_fase"] == 0
			and corrida_a["tick_entrada"] % 4 != corrida_b["tick_entrada"] % 4
			and int(corrida_a["biter_entrada"]) == corrida_a["tick_entrada"] % 4
			and int(corrida_b["biter_entrada"]) == corrida_b["tick_entrada"] % 4,
			"ataque_escalonamento_funcao_do_clock_tick",
			"fases_A=%s fases_B=%s entrada_A=%d fase_A=%d biter_A=%d entrada_B=%d fase_B=%d biter_B=%d mordidas_B=%d pior_B=%d prontos_B=%d candid_B=%d n_cheio_B=%s fora_B=%d eventos_B=%s" % [
			corrida_a["fase"], corrida_b["fase"], corrida_a["tick_entrada"],
			corrida_a["tick_entrada"] % 4, corrida_a["biter_entrada"],
			corrida_b["tick_entrada"], corrida_b["tick_entrada"] % 4,
			corrida_b["biter_entrada"], corrida_b["mordidas"],
			corrida_b["no_pior_tick"], corrida_b["prontos"],
			corrida_b["candidatos"], str(corrida_b["n_cheio"]),
			corrida_b["fora_de_fase"], corrida_b["eventos"]])
	_pack_release()
	return true


## Checagem 4a do dossie 10 (`medo_contagia`). Premissa nomeada: um vizinho DENTRO
## do raio de coesao entra em panico pela transicao real (`take_damage`, o unico
## escritor de `relations` e o que poe o corpo em `flee`), e o observador -- que nao
## foi tocado, nao ve o jogador a 73 m e nao sente o campo a cinco celulas -- muda
## de intencao por causa da LEITURA, nao do mundo. O numero que decide e duplo:
## (i) `contagio_medo_soma_panic_no_fear_level` reproduz a composicao do
## `_fear_level` a lapis com os coeficientes do codigo (0,85 / 0,9 / 0,35) e o
## `0,55` por vizinho em panico escrito aqui, e exige igualdade -- se a soma saiu da
## percepcao por outra porta, ou se o `PACK_PANIC_FEAR` mudou de valor sem o teste
## mudar, os dois lados divergem; (ii) a subida de 0,55 tem de vir com o par
## `_fear_here`/`_blood_here` do observador INALTERADO entre os bracos, porque e
## exatamente isso que separa contagio de difusao. O terceiro numero e a intencao:
## `patrol` no braco sem panico, `flee` no braco com, nos mesmos 20 m.
func _test_contagio_medo() -> bool:
	_arm(SPAWN, FAR_PLAYER, 1)
	_pack_session(2)
	for i: int in 2:
		_pack_place(i, MEDO_SPOTS[i])
	_advance_pack(6)
	var ws: Array = _pack_wolves()
	var obs: Wolf = ws[1]
	var vitima: Wolf = ws[0]
	var dist_obs_vitima: float = obs.center().distance_to(vitima.center())
	var dist_obs_jogador: float = obs.center().distance_to(_player.position3())
	_check(obs._pack.size() == 1 and vitima._pack.size() == 1 \
			and int(obs._pack[0]["identity"]) == vitima.identity \
			and dist_obs_vitima <= Session.PACK_COHESION_RADIUS \
			and obs.intent == "patrol" and obs._pack_panic == 0 \
			and absf(obs._fear_level) < 0.001,
			"premissa: observador patrulha com um vizinho lido e medo zerado",
			"vizinhos=%d panic=%d fear=%.6f intent=%s dist_vitima=%.3f (raio %.1f) dist_jogador=%.3f los=%s  %s" % [
			obs._pack.size(), obs._pack_panic, obs._fear_level, obs.intent,
			dist_obs_vitima, Session.PACK_COHESION_RADIUS, dist_obs_jogador,
			str(obs._los_player), _pack_lists()])
	var fear_antes: float = obs._fear_level
	var here_antes: float = obs._fear_here
	var blood_antes: float = obs._blood_here
	var intent_antes: String = obs.intent
	# A unica diferenca declarada entre os bracos: um golpe real no VIZINHO. O
	# observador nao e tocado, nao ve o jogador e esta a cinco celulas de Eter do
	# sangue e do medo impressos.
	vitima.take_damage(8.0, Wolf.ACTOR_PLAYER, _player.position3())
	_advance_pack(16)
	var panic_lido := 0
	for e: Dictionary in obs._pack:
		if String(e["intent"]) == "flee":
			panic_lido += 1
	# Replay a lapis da composicao, com os coeficientes copiados do codigo desta
	# revisao e o 0,55 escrito aqui: conferir o lobo contra ele mesmo nao pode falhar.
	var esperado: float = clampf(obs._fear_here * 0.85 + obs._threat * 0.9
			+ obs._blood_here * 0.35 + float(obs._pack_panic) * 0.55, 0.0, 1.5)
	_check(panic_lido == 1 and vitima.intent == "flee" \
			and obs._pack_panic == panic_lido \
			and absf(esperado - obs._fear_level) < 0.0001 \
			and absf(obs._fear_here - here_antes) < 0.0001 \
			and absf(obs._blood_here - blood_antes) < 0.0001 \
			and absf(obs._fear_level - fear_antes - 0.55) < 0.0001,
			"contagio_medo_soma_panic_no_fear_level",
			"fear_antes=%.6f fear_depois=%.6f delta=%.6f replay=%.6f panic=%d  campo_antes=(medo %.6f sangue %.6f) campo_depois=(medo %.6f sangue %.6f) vitima_intent=%s" % [
			fear_antes, obs._fear_level, obs._fear_level - fear_antes, esperado,
			obs._pack_panic, here_antes, blood_antes, obs._fear_here, obs._blood_here,
			vitima.intent])
	# O `intent` e o numero que o dossie pede: sem o vizinho em panico o observador
	# estava em `patrol` com `_fear_level` 0; com ele, `flee` passa o chao de fundo
	# de 0,22 e o escorredor troca. Os dois valores de `_fear_level` saem na linha.
	_check(intent_antes == "patrol" and obs.intent == "flee" \
			and fear_antes < 0.001 and obs._fear_level >= 0.55 \
			and obs._fear_here < 0.0001,
			"contagio_medo_muda_intent_do_observador",
			"intent_antes=%s intent_depois=%s fear_antes=%.6f fear_depois=%.6f cautela=%.4f top=%s panic=%d medo_no_observador=%.6f" % [
			intent_antes, obs.intent, fear_antes, obs._fear_level,
			obs.mind.temperament("caution"), obs._top_line, obs._pack_panic,
			obs._fear_here])
	_pack_release()
	return true


## Quantos dos lobos da sessao estao em `hunt` lendo `n_espera` caadores na leitura
## da matilha -- a condicao de entrada do cerco, medida e nao assumida.
func _caadores(n_espera: int) -> int:
	var total := 0
	for w: Wolf in _pack_wolves():
		if w.intent == "hunt" and w._hunt_pack_size() == n_espera:
			total += 1
	return total


## Desloca o relogio ate a fase pedida, com os quatro ainda a 8 m da presa e o
## cooldown zerado: e o unico modo de mudar a fase da entrada sem mudar o mundo, e
## a unica diferenca declarada entre os dois bracos do contraste.
func _advance_ate_fase(alvo: int, teto: int) -> void:
	var i := 0
	while i < teto and _clock.tick % 4 != alvo:
		_advance_pack(1)
		i += 1


## Uma corrida do cenario: monta a sessao, religa o jogador pela transicao real
## (`respawn_at`) e anda a 8 m ate os quatro estarem em `hunt` e cada um lendo os
## outros tres como caadores -- sem isto a primeira leitura devolve `patrol`, cada
## lobo se acha sozinho no cerco e todos mordem juntos por outra porta. Alinha a
## fase do relogio, so entao coloca os quatro dentro de `BITE_RANGE` e roda `passos`
## ticks de 20 Hz. O `passos` maior que as quatro mordidas mostra que a segunda rodada
## nao antecipa: com `BITE_COOLDOWN` de 23 ticks nenhuma mordida cai antes do tick 23.
func _corrida_mordidas(fase_entrada: int, passos: int) -> Dictionary:
	_pack_session(4)
	for i: int in 4:
		_pack_place(i, CERCAR_SPOTS[i])
	_player.respawn_at(CERCAR_PLAYER)
	var aquecimento := -1
	for i: int in 40:
		_advance_pack(1)
		if _caadores(4) == 4:
			aquecimento = _clock.tick
			break
	_advance_ate_fase(fase_entrada, 5)
	var prontos := _caadores(4)
	var ws: Array = _pack_wolves()
	for i: int in 4:
		_pack_place(i, ESCALONAR_SPOTS[i])
	var candidatos := 0
	for w: Wolf in ws:
		if w._bite_cd <= 0.0 and _horizontal(w.center() - _player.position3()).length() \
				<= Wolf.BITE_RANGE:
			candidatos += 1
	var tick_entrada: int = _clock.tick
	_bite_events.clear()
	for w: Wolf in ws:
		w.bit_player.connect(_on_bit_observed.bind(w.identity))
	for i: int in passos:
		_advance_pack(1)
	var por_tick := {}
	var ticks: Array = []
	var fase := {}
	var conflito := false
	var fora_de_fase := 0
	var n_cheio := true
	var ev_str := ""
	for ev: Array in _bite_events:
		var t: int = int(ev[0])
		var ident: int = int(ev[1])
		por_tick[t] = int(por_tick.get(t, 0)) + 1
		ticks.append(t)
		ev_str += "%d:%d(n%d,r%d,%s) " % [t, ident, int(ev[2]), int(ev[3]), String(ev[4])]
		if int(ev[2]) != 4:
			n_cheio = false
		var mod: int = t % 4
		if fase.has(mod) and int(fase[mod]) != ident:
			conflito = true
		fase[mod] = ident
		# O assento r so pode morder em `tick % n == r`, e com os quatro em `hunt`
		# o rank de cada um e a sua identidade: qualquer mordida fora desta
		# igualdade veio de outra porta.
		if mod != ident:
			fora_de_fase += 1
	ticks.sort()
	var pior := 0
	for t: int in por_tick:
		pior = maxi(pior, int(por_tick[t]))
	var consecutivos: bool = ticks.size() >= 2
	for i: int in range(1, ticks.size()):
		if int(ticks[i]) - int(ticks[i - 1]) != 1:
			consecutivos = false
	var biter_entrada := -1
	for ev: Array in _bite_events:
		if int(ev[0]) == tick_entrada:
			biter_entrada = int(ev[1])
	return {
		"mordidas": _bite_events.size(), "no_pior_tick": pior, "ticks": ticks,
		"fase": fase, "candidatos": candidatos, "prontos": prontos,
		"fase_disputada": conflito, "tick_entrada": tick_entrada,
		"fora_de_fase": fora_de_fase, "n_cheio": n_cheio, "eventos": ev_str,
		"aquecimento": aquecimento, "consecutivos": consecutivos,
		"biter_entrada": biter_entrada,
	}


## O sinal da sessao entregue ao runner: `[tick, identidade]` de cada mordida.
## Os argumentos do `bind` vao DEPOIS dos do sinal, e a assinatura espelha isto.
func _on_bit_observed(wolf: Wolf, _amount: float, ident: int) -> void:
	_bite_events.append([_clock.tick, ident, wolf._hunt_pack_size(),
			wolf._hunt_pack_rank(), wolf.intent])


## Angulo horizontal do alvo escrito pelo lobo em torno da presa, no eixo do mundo.
func _seat_angle(target: Vector3, prey: Vector3) -> float:
	var v := _horizontal(target - prey)
	return wrapf(atan2(v.z, v.x), 0.0, TAU)


## Quantos participantes de identidade menor precedem este lobo -- o rank que o teste
## exige, calculado pela lista viva e nao pelo metodo do lobo.
func _participantes_antes_de(w: Wolf, ws: Array) -> int:
	var rank := 0
	for other: Wolf in ws:
		if other.identity < w.identity and other.intent == "hunt":
			rank += 1
	return rank


func _ids_of(pack: Array) -> String:
	var out := ""
	for e: Dictionary in pack:
		out += "%d " % int(e["identity"])
	return out.strip_edges()


func _pack_lists_ids(pack: Array) -> Array:
	var out: Array = []
	for e: Dictionary in pack:
		out.append(int(e["identity"]))
	return out


func _finish() -> void:
	Input.mouse_mode = _mouse_mode
	_pack_release()
	_check(_ran, "runner retornou", "run=%s" % _ran)
	_check(_completed == TESTS.size(), "censo de testes completos", "%d/%d" % [_completed, TESTS.size()])
	# O budget de 400 us por mente e gate publicado, e com a alcateia dentro da
	# arvore ele passou a valer para duas colonias: a de lobo solo e a da sessao.
	_check(_bt_trips == 0 and _pack_bt_trips == 0, "nenhum estouro de subtree no budget",
			"trips_solo=%d trips_matilha=%d" % [_bt_trips, _pack_bt_trips])
	_check(_checks + 1 == EXPECTED_CHECKS, "censo de checagens", "%d/%d" % [_checks + 1, EXPECTED_CHECKS])
	print("CENARIO ESTREITO, NAO GATE P1: passos=%d sim_step total=%d us pico=%d us; BT last_us soma=%d pico=%d trips=%d" % [
		_steps, _sim_us, _sim_worst_us, _bt_us, _bt_worst_us, _bt_trips])
	print("PASSOS DE MATILHA (sessao real, difusao incluida), NAO GATE P1: passos=%d sim_tick total=%d us pico=%d us; BT last_us soma=%d pico=%d trips=%d" % [
		_pack_steps, _pack_sim_us, _pack_sim_worst_us, _pack_bt_us, _pack_bt_worst_us, _pack_bt_trips])
	if is_instance_valid(_stage):
		_stage.free()
	print("%d checagens %d falhas %.3f s" % [_checks, _failures, float(Time.get_ticks_usec() - _started_us) / 1000000.0])
	quit(1 if _failures > 0 else 0)
