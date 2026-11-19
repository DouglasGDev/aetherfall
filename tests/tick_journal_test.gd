extends SceneTree

const Journal = preload("res://src/persistence/tick_journal.gd")
const Main = preload("res://src/main.gd")
const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const TICK: int = 7
const MAIN_STEPS: int = 6
const TESTS: Array[StringName] = [
	&"_test_setup", &"_test_hash_world", &"_test_hash_field", &"_test_hash_minds",
	&"_test_observation", &"_test_journal", &"_test_main_journal",
]
# 6 setup + 14 mundo + 22 Eter + 17 mentes + 6 observacao + 34 IO + 26 main + 3 fechamento.
const EXPECTED_CHECKS: int = 128

var _checks: int = 0
var _failures: int = 0
var _completed: int = 0
var _started_us: int = 0
var _mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _temp_dir: String = ""
var _owns_dir: bool = false
var _main: Main = null
var _world: VoxelWorld = null
var _field: AetherField = null
var _roster: Array[Wolf] = []
var _journal: Journal = Journal.new()


func _initialize() -> void:
	_started_us = Time.get_ticks_usec()
	_mouse_mode = Input.mouse_mode
	# Sem await: o encerramento ja fica agendado mesmo se o runner abortar por erro.
	_run.call_deferred()
	_finish.call_deferred()


func _run() -> void:
	for test_name: StringName in TESTS:
		if call(test_name) != true:
			_failures += 1
			push_error("ABORTOU %s: nao devolveu true" % test_name)
			break
		_completed += 1


func _check(ok: bool, label: String, detail: String = "") -> bool:
	_checks += 1
	print("%s %s %s" % ["OK" if ok else "FALHA", label, detail])
	if not ok:
		_failures += 1
	return ok


func _test_setup() -> bool:
	# A CLI do main nao pode abrir um caminho externo a pasta desta corrida.
	var safe_args: bool = true
	for arg: String in OS.get_cmdline_user_args():
		safe_args = safe_args and not arg.begins_with("--tick-journal=")
	if not _check(safe_args, "runner sem --tick-journal externo"):
		return false
	var suffix: String = Crypto.new().generate_random_bytes(16).hex_encode()
	_temp_dir = ProjectSettings.globalize_path("user://tick_journal_test_%d_%s" % [
		OS.get_process_id(), suffix])
	if not _check(not DirAccess.dir_exists_absolute(_temp_dir)
			and not FileAccess.file_exists(_temp_dir), "pasta exclusiva", _temp_dir):
		return false
	var err: Error = DirAccess.make_dir_absolute(_temp_dir)
	_owns_dir = err == OK
	if not _check(_owns_dir, "criar pasta propria", error_string(err)):
		return false
	_main = MAIN_SCENE.instantiate() as Main
	if not _check(_main != null, "instanciar unica main.tscn real"):
		return false
	# Desabilitar antes de entrar na arvore impede fisica, oraculo HTTP e remalharia.
	_main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_main)
	if not _check(_main.is_node_ready() and _main.world != null and _main.clock != null
			and _main.player != null and _main.wolves.size() == Main.WOLF_COUNT,
			"boot real concluiu", "lobos=%d" % _main.wolves.size()):
		return false
	_world = _main.world
	_field = AetherField.new()
	_field.setup(_world)
	_roster = [_make_wolf(101), _make_wolf(102)]
	_check(_roster[0].alive and _roster[1].alive and _roster[0].mind.identity == 101
			and _roster[1].mind.identity == 102, "mentes criadas por Wolf.setup", "ids=101,102")
	return true


func _make_wolf(identity: int) -> Wolf:
	var wolf: Wolf = Wolf.new()
	_main.add_child(wolf)
	wolf.setup(_world, _field, _main.player, _main.spawn_point(), identity, _main.clock)
	return wolf


func _hash() -> String:
	return Journal.state_hash(TICK, _world, _field, _roster)


func _test_hash_world() -> bool:
	var base: String = _hash()
	_check(base.length() == 64 and base.is_valid_hex_number(false), "SHA-256 hexadecimal", base)
	var started: int = Time.get_ticks_usec()
	var stable: bool = true
	for i: int in 10:
		var again: String = _hash()
		stable = stable and again == base
	_check(stable, "hash idempotente", "10 chamadas; %d us medidos" % (Time.get_ticks_usec() - started))
	_check(Journal.state_hash(TICK + 1, _world, _field, _roster) != base,
			"tick participa", "%d -> %d" % [TICK, TICK + 1])
	var original_seed: int = _world.gen.world_seed
	_world.gen.setup(original_seed + 1)
	_check(_hash() != base, "seed participa", "%d -> %d" % [original_seed, _world.gen.world_seed])
	_world.gen.setup(original_seed)
	_check(_hash() == base, "restaurar seed restaura hash", "seed=%d" % original_seed)

	var p: Vector3i = Vector3i(10, VoxelConfig.CHUNK_SIZE_Y - 2, 2)
	var q: Vector3i = Vector3i(2, VoxelConfig.CHUNK_SIZE_Y - 3, 10)
	var r: Vector3i = Vector3i(2, VoxelConfig.CHUNK_SIZE_Y - 2, 2)
	var edit_p: bool = _world.set_block(p, BlockDefs.Block.WOOD)
	var edit_q: bool = _world.set_block(q, BlockDefs.Block.STONE)
	var edit_r: bool = _world.set_block(r, BlockDefs.Block.SNOW)
	_check(edit_p and edit_q and edit_r and _world.edits.size() == 3,
			"tres edicoes por set_block", "edicoes=%d" % _world.edits.size())
	var edited: String = _hash()
	_check(edited != base, "edicoes participam", "0 -> %d" % _world.edits.size())
	var keys: Array = _world.edits.keys()
	var values: Dictionary = _world.edits.duplicate()
	keys.reverse()
	_world.edits.clear()
	for pos: Vector3i in keys:
		_world.edits[pos] = values[pos]
	_check(_world.edits.keys() == keys and _world.edits.keys() != values.keys(),
			"ordem Vector3i realmente invertida", str(_world.edits.keys()))
	_check(_hash() == edited, "ordem das edicoes nao participa", "3 chaves Vector3i")
	_check(_world.set_block(p, BlockDefs.Block.STONE), "trocar valor por set_block", "wood -> stone")
	_check(_hash() != edited, "valor da edicao participa", str(p))
	var restored: bool = _world.set_block(p, BlockDefs.Block.WOOD)
	_check(restored and _hash() == edited, "restaurar valor restaura hash", str(p))
	# Trocar dois valores conserva contagem e multiconjunto: isola a posicao.
	edit_p = _world.set_block(p, BlockDefs.Block.STONE)
	edit_q = _world.set_block(q, BlockDefs.Block.WOOD)
	_check(edit_p and edit_q and _world.edits.size() == 3,
			"troca conserva tres valores", "stone,wood,snow; p=%s q=%s" % [p, q])
	_check(_hash() != edited, "posicao da edicao participa", "mesmos valores, posicoes trocadas")
	return true


func _test_hash_field() -> bool:
	var base: String = _hash()
	var empty_bytes: PackedByteArray = _field.state_bytes()
	var expected_bytes: int = _field.size_x * _field.size_y * _field.size_z * AetherField.Channel.COUNT * 4
	_check(empty_bytes.size() == expected_bytes, "state_bytes contem todos os float32",
			"bytes=%d esperado=%d" % [empty_bytes.size(), expected_bytes])
	var cell: Vector3i = Vector3i(1, 1, 1)
	var neighbour: Vector3i = cell + Vector3i.RIGHT
	for channel: int in AetherField.Channel.COUNT:
		var label: String = AetherField.CHANNEL_NAMES[channel]
		_field.set_cell_value(cell, channel, 0.25)
		var first: String = _hash()
		_check(_field.sample_cell(cell, channel) == 0.25 and first != base,
				"canal participa: " + label, "valor=%.9f" % _field.sample_cell(cell, channel))
		_field.set_cell_value(cell, channel, 0.5)
		var second: String = _hash()
		_check(second != first, "amplitude participa: " + label, "0.25 -> 0.5")
		_field.set_cell_value(cell, channel, 0.0)
		_field.set_cell_value(neighbour, channel, 0.5)
		_check(_field.total_energy() == 0.5 and _hash() != second,
				"posicao da celula participa: " + label, "energia=%.9f" % _field.total_energy())
		_field.set_cell_value(neighbour, channel, 0.0)
		_field.set_cell_value(cell, channel, 0.000001)
		var tiny: float = _field.sample_cell(cell, channel)
		_check(tiny > 0.0 and tiny < 0.01, "residuo existe: " + label, "valor=%.9f" % tiny)
		var saved_cells: Array = _field.to_dict()["cells"]
		_check(saved_cells.is_empty(),
				"save esparso omite residuo: " + label, "cells=%d" % saved_cells.size())
		_check(_field.state_bytes() != empty_bytes and _hash() != base,
				"hash preserva residuo: " + label, "valor=%.9f bytes=%d" % [tiny, _field.state_bytes().size()])
		_field.set_cell_value(cell, channel, 0.0)
		_check(_hash() == base, "zerar canal restaura hash: " + label, "valor=0")
	return true


func _test_hash_minds() -> bool:
	var first: Wolf = _roster[0]
	var second: Wolf = _roster[1]
	var base: String = _hash()
	first.mind.reinforce("danger_from_actor_1", 0.5, "perception")
	first.mind.reinforce("player_visible_recent", 0.4, "perception")
	second.mind.reinforce("prey_wounded", 0.3, "consolidated")
	_check(first.mind.beliefs.size() == 2 and second.mind.beliefs.size() == 1,
			"crencas criadas por reinforce", "crencas=%d+%d" % [first.mind.beliefs.size(), second.mind.beliefs.size()])
	var believed: String = _hash()
	_check(believed != base, "crencas participam", "0 -> 3")
	var beliefs: Dictionary = first.mind.beliefs.duplicate(true)
	var keys: Array = beliefs.keys()
	keys.reverse()
	first.mind.beliefs.clear()
	for key: String in keys:
		first.mind.beliefs[key] = beliefs[key]
	_check(first.mind.beliefs.keys() == keys and first.mind.beliefs.keys() != beliefs.keys(),
			"ordem String realmente invertida", str(keys))
	_check(_hash() == believed, "ordem das crencas nao participa", "2 chaves String")
	_check(Journal.state_hash(TICK, _world, _field, [second, first]) == believed,
			"ordem do roster nao participa", "101,102 -> 102,101")
	first.mind.reinforce("danger_from_actor_1", 0.1, "perception")
	var confident: String = _hash()
	_check(first.mind.belief("danger_from_actor_1") > 0.5 and confident != believed,
			"confianca participa", "confianca=%.9f" % first.mind.belief("danger_from_actor_1"))
	var confidence: float = first.mind.belief("danger_from_actor_1")
	first.mind.reinforce("danger_from_actor_1", 0.0, "consolidated")
	_check(first.mind.belief("danger_from_actor_1") == confidence
			and first.mind.beliefs["danger_from_actor_1"]["source"] == "consolidated",
			"source mudou sem mudar confianca", "confianca=%.9f" % confidence)
	_check(_hash() != confident, "source participa", "perception -> consolidated")

	var other: Wolf = _make_wolf(103)
	other.mind.reinforce("prey_wounded", 0.3, "consolidated")
	_check(other.intent == second.intent and other.mind.beliefs == second.mind.beliefs
			and Journal.state_hash(TICK, _world, _field, [first, other]) != _hash(),
			"identidade participa com intencao/crencas iguais", "102 -> 103")
	first.take_damage(Wolf.MAX_HP - 2.0, Wolf.ACTOR_PLAYER, _main.player.position3())
	first._sense()
	_check(first.alive and first.hp == 2.0 and first._fear_level >= 1.0,
			"golpe real cria premissa de fuga", "hp=%.2f medo=%.3f" % [first.hp, first._fear_level])
	var before_think: String = _hash()
	var old_intent: String = first.intent
	first._think(10.0)
	_check(first.intent == "flee" and first.intent != old_intent,
			"_think muda intencao", "%s -> %s" % [old_intent, first.intent])
	_check(_hash() != before_think, "intencao participa sem novo golpe", first.intent)
	_check(Journal.state_hash(TICK, _world, _field, [second]) != _hash(),
			"remover mente viva participa", "2 -> 1")

	# die tambem imprime Eter; um campo separado isola a exclusao da mente morta.
	var fixed_field: AetherField = AetherField.new()
	fixed_field.setup(_world)
	var living: String = Journal.state_hash(TICK, _world, fixed_field, _roster)
	first.die()
	_check(not first.alive and first.intent == "morto", "morte por die", "vivos=1")
	var dead: String = Journal.state_hash(TICK, _world, fixed_field, _roster)
	_check(dead != living, "morte participa com Eter fixo", "2 -> 1 mentes vivas")
	_check(dead == Journal.state_hash(TICK, _world, fixed_field, [second]),
			"cadaver equivale a ausencia no roster", "1 vivo + 1 morto")
	first.mind.reinforce("danger_from_actor_1", 0.2, "perception")
	_check(Journal.state_hash(TICK, _world, fixed_field, _roster) == dead,
			"crenca de morto nao participa", "reforco=0.2")
	return true


func _test_observation() -> bool:
	var wolf: Wolf = _main.wolves[0]
	var base: String = _main.state_hash()
	var old_us: int = wolf._guard.last_us
	var old_trips: int = wolf._guard.trips
	# Perturbacoes de observacao, nao medicoes de tempo nem transicoes de gameplay.
	wolf._guard.last_us += 1234
	wolf._guard.trips += 2
	_check(wolf._guard.last_us != old_us and wolf._guard.trips != old_trips,
			"telemetria do guard perturbada", "delta_us=1234 delta_trips=2 (injetados)")
	_check(_main.state_hash() == base, "telemetria nao participa")
	wolf._guard.last_us = old_us
	wolf._guard.trips = old_trips
	_main.oracle._narrations[wolf.identity] = "narracao de teste sem chamada HTTP"
	_check(_main.oracle.narration_of(wolf.identity) == "narracao de teste sem chamada HTTP",
			"narracao de observacao mudou", "id=%d" % wolf.identity)
	_check(_main.state_hash() == base, "narracao nao participa")
	var old_rotation: Vector3 = wolf._visual.rotation
	wolf._visual.rotate_y(0.75)
	wolf._visual.hide()
	_check(wolf._visual.rotation != old_rotation and not wolf._visual.visible,
			"visual mudou sem mover corpo", "rotacao=0.75 rad; visible=false")
	_check(_main.state_hash() == base, "visual nao participa")
	return true


func _test_journal() -> bool:
	var path: String = _temp_dir.path_join("records.jsonl")
	var busy_path: String = _temp_dir.path_join("busy.jsonl")
	_check(_journal.record(0, _world, _field, _roster) == ERR_UNCONFIGURED
			and _journal.records == 0, "record sem start recusado", "records=%d" % _journal.records)
	if not _check(_journal.start(path) == OK, "start em arquivo novo", path):
		return false
	_check(_journal.active() and _journal.records == 0 and _journal.last_tick == -1
			and _journal.last_hash.is_empty() and _journal.total_us == 0,
			"start zera contadores", str(_journal.diagnostics()))
	_check(_journal.start(busy_path) == ERR_ALREADY_IN_USE and _journal.path == path
			and not FileAccess.file_exists(busy_path), "instancia ativa recusa outro start")
	var initial_bytes: PackedByteArray = _read_bytes(path)
	_check(initial_bytes.is_empty(), "start nao escreve registro", "bytes=%d" % initial_bytes.size())
	var pristine: Dictionary = _journal.diagnostics()
	var negative_err: Error = _journal.record(-1, _world, _field, _roster)
	var rejected_bytes: PackedByteArray = _read_bytes(path)
	_check(negative_err == ERR_INVALID_DATA and _journal.diagnostics() == pristine and rejected_bytes.is_empty(),
			"tick negativo inicial recusado sem append", "tick=-1 bytes=%d" % rejected_bytes.size())
	_check(_journal.record(TICK, _world, _field, _roster) == OK,
			"primeiro tick nao precisa ser zero", "tick=%d" % TICK)
	var prefix: PackedByteArray = _read_bytes(path)
	var first_hash: String = _hash()
	var first_us: int = _journal.last_us
	_check(_journal.records == 1 and _journal.last_tick == TICK and _journal.last_hash == first_hash
			and first_us >= 0 and _journal.total_us == first_us and _journal.worst_us == first_us,
			"primeiro registro atualiza diagnostico", str(_journal.diagnostics()))
	_check(_jsonl_matches(prefix, [TICK], [first_hash]),
			"JSONL legivel antes do close (flush)", "bytes=%d" % prefix.size())
	for invalid_tick: int in [TICK, TICK - 1, TICK + 2, -1]:
		var before: Dictionary = _journal.diagnostics()
		_check(_journal.record(invalid_tick, _world, _field, _roster) == ERR_INVALID_DATA,
				"duplicata/recuo/salto/negativo recusado", "tick=%d ultimo=%d" % [invalid_tick, TICK])
		_check(_read_bytes(path) == prefix, "recusa nao altera bytes", "tick=%d bytes=%d" % [invalid_tick, prefix.size()])
		_check(_journal.diagnostics() == before, "recusa nao altera diagnostico", "tick=%d" % invalid_tick)
	_check(_journal.record(TICK + 1, _world, _field, _roster) == OK,
			"consecutivo aceito depois das recusas", "tick=%d" % (TICK + 1))
	var bytes: PackedByteArray = _read_bytes(path)
	var second_hash: String = Journal.state_hash(TICK + 1, _world, _field, _roster)
	_check(bytes.size() > prefix.size() and bytes.slice(0, prefix.size()) == prefix,
			"append preserva prefixo byte a byte", "%d -> %d bytes" % [prefix.size(), bytes.size()])
	_check(_jsonl_matches(bytes, [TICK, TICK + 1], [first_hash, second_hash]),
			"readback exato de dois pares [tick,sha256]", "linhas=2 bytes=%d" % bytes.size())
	_check(_journal.records == 2 and _journal.last_tick == TICK + 1 and _journal.last_hash == second_hash
			and _journal.last_us >= 0 and _journal.total_us == first_us + _journal.last_us
			and _journal.worst_us == maxi(first_us, _journal.last_us),
			"tempos agregados correspondem aos registros", str(_journal.diagnostics()))
	print("journal medido: records=%d bytes=%d last_us=%d worst_us=%d total_us=%d" % [
		_journal.records, bytes.size(), _journal.last_us, _journal.worst_us, _journal.total_us])
	var closed: Dictionary = _journal.diagnostics()
	closed["active"] = false
	_journal.close()
	_check(not _journal.active() and _journal.diagnostics() == closed, "close conserva historico")
	_check(_journal.record(TICK + 2, _world, _field, _roster) == ERR_UNCONFIGURED,
			"record depois de close recusado")
	_check(_read_bytes(path) == bytes and _journal.diagnostics() == closed,
			"record fechado nao altera arquivo nem diagnostico", "bytes=%d" % bytes.size())
	_check(_journal.start(path) == ERR_ALREADY_EXISTS and _read_bytes(path) == bytes
			and _journal.diagnostics() == closed, "arquivo existente recusado sem truncar")
	_check(_journal.start(_temp_dir) == ERR_ALREADY_EXISTS and not _journal.active(),
			"diretorio nao e arquivo novo")
	var missing: String = _temp_dir.path_join("missing")
	var err: Error = _journal.start(missing.path_join("refused.jsonl"))
	_check(err != OK and not _journal.active() and not DirAccess.dir_exists_absolute(missing)
			and not FileAccess.file_exists(missing.path_join("refused.jsonl")),
			"pai inexistente recusado sem criar diretorio", error_string(err))
	var restart_path: String = _temp_dir.path_join("restart.jsonl")
	_check(_journal.start(restart_path) == OK and _journal.records == 0 and _journal.last_tick == -1
			and _journal.last_hash.is_empty() and _journal.last_us == 0
			and _journal.worst_us == 0 and _journal.total_us == 0,
			"nova sessao apos close zera historico", str(_journal.diagnostics()))
	_check(_journal.record(0, _world, _field, _roster) == OK, "zero aceito como primeiro tick", "tick=0")
	_journal.close()
	_journal.close()
	_check(not _journal.active() and _jsonl_matches(_read_bytes(restart_path), [0],
			[Journal.state_hash(0, _world, _field, _roster)]), "close idempotente preserva registro zero")
	return true


func _test_main_journal() -> bool:
	var wolf: Wolf = _main.wolves[0]
	_check(_main.process_mode == Node.PROCESS_MODE_DISABLED and not _main.player.can_process()
			and not wolf.can_process() and not _main.oracle.can_process() and _main.clock.tick == 0,
			"integracao sem processos automaticos", "tick=%d" % _main.clock.tick)
	for i: int in 2:
		_main._sim_tick()
		_check(_main.clock.tick == i + 1 and not _main.tick_journal.active() and _main.tick_journal.records == 0,
				"_sim_tick sem start nao registra", "tick=%d records=%d" % [_main.clock.tick, _main.tick_journal.records])
	_check(_main.state_hash() == Journal.state_hash(_main.clock.tick, _main.world, _main.aether, _main.wolves),
			"main.state_hash usa estado e tick atuais", "tick=%d" % _main.clock.tick)
	var path: String = _temp_dir.path_join("main.jsonl")
	var journal: Journal = _main.tick_journal
	if not _check(journal.start(path) == OK, "iniciar journal do main", path):
		return false
	var initial_bytes: PackedByteArray = _read_bytes(path)
	_check(journal.records == 0 and initial_bytes.is_empty(), "main sem registro antecipado",
			"bytes=%d records=%d" % [initial_bytes.size(), journal.records])
	var ticks: Array[int] = []
	var hashes: Array[String] = []
	var prefix: PackedByteArray = PackedByteArray()
	var sim_us: int = 0
	for i: int in MAIN_STEPS:
		var previous_tick: int = _main.clock.tick
		var started: int = Time.get_ticks_usec()
		_main._sim_tick()
		sim_us += Time.get_ticks_usec() - started
		_check(_main.clock.tick == previous_tick + 1 and journal.records == i + 1
				and journal.last_tick == _main.clock.tick, "um registro apos incremento do tick",
				"tick=%d records=%d" % [_main.clock.tick, journal.records])
		_check(journal.last_hash == _main.state_hash() and _main.diagnostics()["journal"] == journal.diagnostics(),
				"hash e diagnostico coincidem no fim do passo", "tick=%d" % _main.clock.tick)
		ticks.append(_main.clock.tick)
		hashes.append(_main.state_hash())
		var bytes: PackedByteArray = _read_bytes(path)
		_check(bytes.size() > prefix.size() and bytes.slice(0, prefix.size()) == prefix
				and _jsonl_matches(bytes, ticks, hashes), "main faz append e flush do estado final",
				"linhas=%d bytes=%d" % [ticks.size(), bytes.size()])
		prefix = bytes
	print("main medido: passos=%d sim_total_us=%d bytes=%d journal_last_us=%d journal_worst_us=%d journal_total_us=%d" % [
		MAIN_STEPS, sim_us, prefix.size(), journal.last_us, journal.worst_us, journal.total_us])
	# free exercita _exit_tree real; manter o RefCounted permite observar o fechamento.
	_main.free()
	_main = null
	_check(not journal.active(), "_exit_tree fecha journal", "records=%d" % journal.records)
	_check(journal.record(ticks[-1] + 1, _world, _field, []) == ERR_UNCONFIGURED
			and journal.records == MAIN_STEPS and _read_bytes(path) == prefix,
			"saida impede append e preserva arquivo", "bytes=%d" % prefix.size())
	return true


func _read_bytes(path: String) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures += 1
		push_error("leitura falhou: %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return bytes


func _jsonl_matches(bytes: PackedByteArray, ticks: Array[int], hashes: Array[String]) -> bool:
	var text: String = bytes.get_string_from_utf8()
	if not text.ends_with("\n") or ticks.size() != hashes.size():
		return false
	var lines: PackedStringArray = text.trim_suffix("\n").split("\n", true)
	if lines.size() != ticks.size():
		return false
	for i: int in lines.size():
		var parser: JSON = JSON.new()
		if parser.parse(lines[i]) != OK or not parser.data is Array:
			return false
		var row: Array = parser.data
		if row.size() != 2:
			return false
		if (not row[0] is float and not row[0] is int) or row[0] != ticks[i] or row[1] != hashes[i]:
			return false
	return true


func _cleanup() -> bool:
	_journal.close()
	if is_instance_valid(_main):
		_main.free()
		_main = null
	Input.mouse_mode = _mouse_mode
	var ok: bool = true
	if _owns_dir:
		# Lista fechada: jamais varrer/apagar saves ou arquivos de outra corrida.
		for name: String in ["records.jsonl", "busy.jsonl", "restart.jsonl", "main.jsonl"]:
			var path: String = _temp_dir.path_join(name)
			if FileAccess.file_exists(path):
				var err: Error = DirAccess.remove_absolute(path)
				ok = ok and err == OK
		var err: Error = DirAccess.remove_absolute(_temp_dir)
		ok = ok and err == OK
		_owns_dir = err != OK
	return ok


func _finish() -> void:
	_check(_cleanup(), "limpeza somente dos arquivos proprios", _temp_dir)
	_check(_completed == TESTS.size(), "todos os testes devolveram true", "%d/%d" % [_completed, TESTS.size()])
	_check(_checks + 1 == EXPECTED_CHECKS, "contagem completa de checagens", "%d/%d" % [_checks + 1, EXPECTED_CHECKS])
	print("%d checagens %d falhas %d/%d testes concluidos %.3f s" % [
		_checks, _failures, _completed, TESTS.size(), float(Time.get_ticks_usec() - _started_us) / 1000000.0])
	quit(1 if _failures > 0 else 0)
