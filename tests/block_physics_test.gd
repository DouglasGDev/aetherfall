extends SceneTree
## Gate da perna 17 — física de blocos que caem (docs/planos/17-fisica-de-blocos-que-caem.md §5).
##
## Este runner nasce VERMELHO contra a árvore sem o código, e é assim que ele prova que as
## sete checagens têm dente: cada uma procura a peça pelo nome (`has_method`, `get`,
## `ResourceLoader.exists`) e imprime a assinatura da ausência na própria linha FALHA.
## Nenhuma chamada solta em função inexistente: medido nesta árvore que um `call` num nome
## ausente imprime `SCRIPT ERROR` e ABORTA o passo em curso — o mandato 1 conta checagem
## perdida como falha silenciosa, e foi exatamente assim que o probe da fase de leitura da
## própria perna ficou preso.
##
## Duas peças são de propósito diferentes do `tests/tick_journal_test.gd`, o modelo da casa:
## (a) `_run` não quebra no primeiro vermelho — as sete linhas precisam aparecer na corrida
## vermelha, uma por checagem, e (b) cada teste emite exatamente UMA `_check`, em todo
## caminho possível, para o censo (`EXPECTED_CHECKS`) valer igual no vermelho e no verde.
##
## O cenário é construído com `record = false` — anda, scaffolding não é registro de
## construção, e as chaves que o gate conta têm de ser as da QUEDA, não as do cenário. É a
## mesma cláusula que a perna 12 deixou registrada no status.

const Journal = preload("res://src/persistence/tick_journal.gd")
const Main = preload("res://src/main.gd")
const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")

const BLOCK_DEFS_PATH: String = "res://src/world/block_defs.gd"
const QUEUE_PATH: String = "res://src/world/block_update_queue.gd"
const SPAWNER_PATH: String = "res://src/entities/falling_block_spawner.gd"
const FALLING_PATH: String = "res://src/entities/falling_block.gd"

const TESTS: Array[StringName] = [
	&"_test_setup",
	&"_test_queda_sem_varredura_de_mundo",
	&"_test_queda_move_a_celula",
	&"_test_queda_cascade_em_passos",
	&"_test_bloco_em_queda_nao_sobe",
	&"_test_queda_pousa_antes_do_save",
	&"_test_queda_nao_custou_tempo_de_ninguem",
	&"_test_journal_hash_muda_so_com_movimento",
]
# 5 abertura + 7 checagens do gate + 3 fechamento. Toda checagem nova move este número.
const EXPECTED_CHECKS: int = 15

const SAND: int = BlockDefs.Block.SAND
const AIR: int = BlockDefs.Block.AIR
const STONE: int = BlockDefs.Block.STONE

const SCENE_X: int = 20      # coluna da sessao: checagens 2 e 4
const SCENE_Z: int = 20
const PILE_X: int = 30       # pilha de 6 no mundo de prova: checagens 1 e 3
const PILE_Z: int = 30
const GAP_X: int = 34        # flutuantes com folga, em B e no gemeo C: checagem 3
const GAP_Z: int = 34
const SAVE_X: int = 40       # pilha grafada do save: checagem 5
const SAVE_Z: int = 40
const ARM_X: int = 46        # coluna do braco com cascata: checagem 6
const ARM_Z: int = 46
const HASH_X: int = 50       # cena do par de hashes: checagem 7
const HASH_Z: int = 50
const PILE: int = 6
const PURE_TICKS: int = 1000
const ARM_TICKS: int = 1000
## Custo por evento que o dossiê §3.2 publica: 2 `get_block` (a célula escrita e a de cima).
## Cada resolucao do `flush` le a propria celula e o apoio dela: mais 2.
const READS_PER_EVENT: int = 2
const READS_PER_RESOLUTION: int = 2
## Critério numérico escrito ANTES da corrida (dossiê §4, quarta pergunta): nenhum passo de
## cascata acima de 25 ms dos 50 ms do budget de 20 Hz.
const STEP_CEILING_MS: float = 25.0

var _checks: int = 0
var _failures: int = 0
var _completed: int = 0
var _started_us: int = 0
var _mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _main: Main = null
var _world: VoxelWorld = null
var _stage: Node3D = null
var _log: Array = []
var _h_a: Dictionary = {}
var _h_b: Dictionary = {}
var _h_c: Dictionary = {}


func _initialize() -> void:
	_started_us = Time.get_ticks_usec()
	_mouse_mode = Input.mouse_mode
	# Sem await: o encerramento roda mesmo se um passo abortar por erro.
	_run.call_deferred()
	_finish.call_deferred()


func _run() -> void:
	for test_name: StringName in TESTS:
		if call(test_name) == true:
			_completed += 1
		else:
			print("VERMELHO %s nao devolveu true" % test_name)


func _check(ok: bool, label: String, detail: String = "") -> bool:
	_checks += 1
	print("%s %s %s" % ["OK" if ok else "FALHA", label, detail])
	if not ok:
		_failures += 1
	return ok


# ------------------------------------------------------------- abertura

func _test_setup() -> bool:
	var safe_args: bool = true
	for arg: String in OS.get_cmdline_user_args():
		safe_args = safe_args and not arg.begins_with("--tick-journal=")
	if not _check(safe_args, "runner sem --tick-journal externo",
			"args=%s" % str(OS.get_cmdline_user_args())):
		return false
	_main = MAIN_SCENE.instantiate() as Main
	if not _check(_main != null, "instanciar unica main.tscn real"):
		return false
	# Desabilitar antes de entrar na arvore impede fisicas e remalharia por frame.
	_main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_main)
	_world = _main.world
	var fila := int(_main.diagnostics()["pending_respawns"])
	if not _check(_main.is_node_ready() and _world != null and _main.clock != null
			and _main.player != null and _main.wolves.size() + fila == Main.WOLF_COUNT,
			"boot real concluiu", "lobos=%d fila=%d tick=%d" % [
				_main.wolves.size(), fila, _main.clock.tick]):
		return false
	_stage = Node3D.new()
	_stage.name = "PalcoFisicaBlocos17"
	root.add_child(_stage)
	_h_a = _make_harness("controle", false)
	_h_b = _make_harness("prova", true)
	_h_c = _make_harness("gemeo", true)
	# Os tres mundos de prova sao gerados sem malharia: o que o gate mede e grid e fila, e
	# o `generate_meshes_all` nao entra em nenhuma das sete checagens.
	_check(_h_a.has("world") and _h_b.has("world") and _h_c.has("world")
			and _h_a["world"] != _h_b["world"] and _h_b["world"] != _h_c["world"],
			"tres mundos de prova da mesma semente",
			"gen sem malha  seed=%d  fila_no_controle=%s  fila_na_prova=%s" % [
				Main.SEED, str(_hqueue(_h_a) != null), str(_hqueue(_h_b) != null)])
	if _world == null:
		return false
	_world.block_changed.connect(_on_block)
	# O teste e consumidor do sinal desde a abertura: sem isto nenhuma das sete linhas teria
	# como ver a ORDEM das escritas dentro de um tick, que e o que a checagem 3 exige.
	var conns: int = _world.get_signal_connection_list("block_changed").size()
	return _check(_world.has_signal("block_changed") and conns >= 1,
			"block_changed declarado e lido por este runner",
			"conexoes=%d  consumidores_antes_da_perna=%d" % [conns, conns - 1])


func _on_block(pos: Vector3i, prev: int, now: int) -> void:
	_log.append([pos, prev, now])


## Mundo de prova independente: grid + campo + fila + spawner, sem HUD, sem malha, sem lobos.
## `attach = false` e o braco que representa a rodada SEM a peca: a fila existe como objeto
## mas nunca ouve o sinal, entao o mundo dela e literalmente o mundo de hoje.
func _make_harness(label: String, attach: bool) -> Dictionary:
	if _stage == null:
		return {}
	var stage := Node3D.new()
	stage.name = label
	_stage.add_child(stage)
	var w := VoxelWorld.new()
	w.setup_world(stage)
	w.generate(Main.SEED)
	var f := AetherField.new()
	f.setup(w)
	var h := {"stage": stage, "world": w, "field": f, "log": [], "tick": 0,
		"queue": null, "spawner": null}
	if ResourceLoader.exists(SPAWNER_PATH, "GDScript"):
		var ss: GDScript = load(SPAWNER_PATH)
		var sp = ss.new()
		sp.call("setup", w, stage)
		h["spawner"] = sp
	if ResourceLoader.exists(QUEUE_PATH, "GDScript"):
		var qs: GDScript = load(QUEUE_PATH)
		var q = qs.new()
		if attach and h["spawner"] != null:
			q.call("attach", w, h["spawner"])
		h["queue"] = q
	var log: Array = h["log"]
	w.block_changed.connect(func(pos: Vector3i, prev: int, now: int) -> void:
		log.append([pos, prev, now]))
	return h


# ------------------------------------------------------------------ helpers

## Sessao viva, nunca assumed: um `_main` nulo abortaria as sete linhas.
func _session_ok() -> bool:
	return _main != null and is_instance_valid(_main) and _world != null


func _has_queue() -> bool:
	return ResourceLoader.exists(QUEUE_PATH, "GDScript")


func _has_method_in(obj: Object, m: String) -> bool:
	return obj != null and obj.has_method(m)


func _gravity_flag(b: int) -> bool:
	var bs: GDScript = load(BLOCK_DEFS_PATH)
	if bs == null or not bs.has_method("has_gravity"):
		return false
	return bool(bs.call("has_gravity", b))


func _gravity_flag_exists() -> bool:
	var bs: GDScript = load(BLOCK_DEFS_PATH)
	return bs != null and bs.has_method("has_gravity")


## Os numeros da fila da SESSAO, lidos sem depender de simbolo novo.
func _stats() -> Dictionary:
	if not _has_method_in(_main, "block_stats"):
		return {}
	var raw = _main.call("block_stats")
	if raw is Dictionary:
		return raw
	return {}


func _hqueue(h: Dictionary):
	return h.get("queue")


func _hstats(h: Dictionary) -> Dictionary:
	var q = _hqueue(h)
	if q == null:
		return {}
	var raw = q.call("stats")
	if raw is Dictionary:
		return raw
	return {}


func _hfalling(h: Dictionary) -> Array:
	var sp = h.get("spawner")
	if sp == null:
		return []
	var raw = sp.get("falling")
	if raw is Array:
		return raw
	return []


func _falling() -> Array:
	if _main == null:
		return []
	var sp = _main.get("block_spawner")
	if sp == null:
		return []
	var raw = sp.get("falling")
	if raw is Array:
		return raw
	return []


func _has_feature() -> bool:
	return _has_queue() and ResourceLoader.exists(FALLING_PATH, "GDScript") \
			and ResourceLoader.exists(SPAWNER_PATH, "GDScript")


## Roda o corpo real de `_physics_process`, com o passo do SimClock: e ele que o
## `begin_step`/`end_step` cronometra e o que o `advance` decide perder.
func _tick(n: int) -> int:
	var t0: int = _main.clock.tick
	var guard: int = 0
	while _main.clock.tick < t0 + n and guard <= n * 3 + 8:
		_main._physics_process(SimClock.STEP)
		guard += 1
	return _main.clock.tick - t0


## Tick a tick, com a fila da sessao lida no intervalo: o pico de `queued` do braco.
func _tick_watch(n: int) -> Dictionary:
	var max_queued: int = 0
	var given: int = 0
	for _i in range(n):
		given += _tick(1)
		max_queued = maxi(max_queued, int(_stats().get("queued", 0)))
	return {"ticks": given, "max_queued": max_queued}


## flush + passo das entidades ate a fila esvaziarem, com o cursor de tick proprio do
## harness (o `RECHECK_DELAY` so encadeia se os ticks forem monotonos).
func _drive(h: Dictionary, max_ticks: int) -> Dictionary:
	var q = _hqueue(h)
	var sp = h.get("spawner")
	if q == null or sp == null:
		return {"ticks": 0, "resolutions": 0, "conversions": [], "queued": -1}
	var log: Array = h["log"]
	var conversions: Array = []
	var resolutions: int = 0
	var used: int = 0
	while used < max_ticks:
		var t: int = int(h["tick"]) + 1
		h["tick"] = t
		var before: int = log.size()
		resolutions += int(q.call("flush", t))
		var mid: int = log.size()
		var cells: Array = []
		for i in range(before, mid):
			if int(log[i][1]) == SAND and int(log[i][2]) == AIR:
				cells.append(log[i][0])
		sp.call("step", SimClock.STEP)
		used += 1
		if not cells.is_empty():
			conversions.append([t, cells])
		if int(_hstats(h).get("queued", 1)) == 0 and _hfalling(h).is_empty():
			break
	return {"ticks": used, "resolutions": resolutions, "conversions": conversions,
		"queued": int(_hstats(h).get("queued", -1))}


## Sequencia achatada das celulas convertidas, na ordem das emissoes.
func _ys(conversions: Array) -> Array:
	var out: Array = []
	for entry in conversions:
		for c in entry[1]:
			out.append(int(c.y))
	return out


func _seq(ys: Array) -> String:
	var parts: Array[String] = []
	for y in ys:
		parts.append(str(y))
	return ">".join(parts)


## A assinatura da ausencia: o que falta, e o estado lido de onde a peça deveria estar.
func _signature(extra: String) -> String:
	return ("ausencia: %s || has_gravity=%s block_update_queue=%s falling_block=%s "
		+ "spawner=%s is_supported=%s place_falling_block=%s block_stats=%s "
		+ "settle_block_updates=%s") % [
		extra,
		"sim" if _gravity_flag_exists() else "NAO",
		"sim" if _has_queue() else "NAO",
		"sim" if ResourceLoader.exists(FALLING_PATH, "GDScript") else "NAO",
		"sim" if ResourceLoader.exists(SPAWNER_PATH, "GDScript") else "NAO",
		"sim" if _has_method_in(_world, "is_supported") else "NAO",
		"sim" if _has_method_in(_world, "place_falling_block") else "NAO",
		"sim" if _has_method_in(_main, "block_stats") else "NAO",
		"sim" if _has_method_in(_main, "settle_block_updates") else "NAO",
	]


func _supported(w: VoxelWorld, p: Vector3i) -> bool:
	if not _has_method_in(w, "is_supported"):
		return false
	return bool(w.call("is_supported", p))


func _count_sand(x: int, z: int, y_lo: int, y_hi: int) -> int:
	var n: int = 0
	for y in range(y_lo, y_hi + 1):
		if _world.get_block(Vector3i(x, y, z)) == SAND:
			n += 1
	return n


## Quantas areias da coluna estao sem apoio -- o "fantasma" que o quiesce nao pode deixar.
func _floating_sands(x: int, z: int, y_lo: int, y_hi: int) -> int:
	var n: int = 0
	for y in range(y_lo, y_hi + 1):
		var c := Vector3i(x, y, z)
		if _world.get_block(c) == SAND and not _supported(_world, c):
			n += 1
	return n


# ------------------------------------------------------------------- gate
# §5.1 -- nenhuma linha daqui varre o mundo: o numero de leituras e funcao do numero de
# eventos, e com zero eventos ele e zero.

func _test_queda_sem_varredura_de_mundo() -> bool:
	var q = _hqueue(_h_b)
	if not _session_ok() or q == null or _h_b.get("spawner") == null:
		return _check(false, "queda_sem_varredura_de_mundo", _signature(
			"nenhum dos 1.000 ticks sem edicao foi medido: sem BlockUpdateQueue nao ha "
			+ "contador de leituras, e a fila da sessao nao existe para o braco puro"))
	var cells_map: int = VoxelConfig.world_size_x() * VoxelConfig.CHUNK_SIZE_Y \
			* VoxelConfig.world_size_z()
	# braco puro: mil flushes, nenhuma escrita no grid.
	for t in range(1, PURE_TICKS + 1):
		q.call("flush", t)
		_h_b["spawner"].call("step", SimClock.STEP)
	_h_b["tick"] = PURE_TICKS
	var pure: Dictionary = _hstats(_h_b)
	var pure_reads: int = int(pure.get("reads", -1))
	var pure_queued: int = int(pure.get("queued", -1))
	var pure_res: int = int(pure.get("resolutions", 0))
	# braco coluna: 6 areias com o apoio removido, no mesmo mundo de prova.
	var w: VoxelWorld = _h_b["world"]
	var y0: int = w.surface_height(PILE_X, PILE_Z)
	_h_b["log"].clear()
	for i in range(PILE):
		w.set_block(Vector3i(PILE_X, y0 + 1 + i, PILE_Z), SAND, false)
	w.set_block(Vector3i(PILE_X, y0, PILE_Z), AIR, false)
	var col: Dictionary = _drive(_h_b, 240)
	var after: Dictionary = _hstats(_h_b)
	var col_events: int = int(after.get("events", _h_b["log"].size()))
	var col_reads: int = int(after.get("reads", 0)) - pure_reads
	var col_res: int = int(after.get("resolutions", 0)) - pure_res
	var read_ceiling: int = READS_PER_EVENT * col_events + READS_PER_RESOLUTION * col_res
	# janelinha na sessao real: a fila anexada tem de custar leituras proporcionais aos eventos
	var s0: Dictionary = _stats()
	var e0: int = _log.size()
	_tick(5)
	var s1: Dictionary = _stats()
	var sess_reads: int = int(s1.get("reads", 0)) - int(s0.get("reads", 0))
	var sess_events: int = _log.size() - e0
	var sess_res: int = int(s1.get("resolutions", 0)) - int(s0.get("resolutions", 0))
	var sess_ceiling: int = READS_PER_EVENT * sess_events \
			+ READS_PER_RESOLUTION * sess_res
	var ok: bool = pure_reads == 0 and pure_queued == 0 \
			and col_reads <= read_ceiling and int(col["queued"]) == 0 \
			and int(col["ticks"]) > 0 \
			and sess_reads <= sess_ceiling \
			and _gravity_flag(SAND) and not _gravity_flag(STONE)
	var ev: String = ("puro: ticks=%d leituras=%d queued=%d | mapa=%d celulas, varredura "
		+ "teria lido %d por segundo | coluna: eventos=%d leituras=%d resolucoes=%d teto=%d "
		+ "ticks=%d conversions=%d queued_final=%d | sessao: eventos=%d leituras=%d "
		+ "resolucoes=%d teto=%d | SAND=%s STONE=%s") % [
		PURE_TICKS, pure_reads, pure_queued, cells_map, cells_map * SimClock.HZ,
		col_events, col_reads, col_res, read_ceiling, int(col["ticks"]),
		int((col["conversions"] as Array).size()), int(col["queued"]),
		sess_events, sess_reads, sess_res, sess_ceiling,
		str(_gravity_flag(SAND)), str(_gravity_flag(STONE))]
	if not ok:
		ev = _signature(ev)
	return _check(ok, "queda_sem_varredura_de_mundo", ev)


# §5.2 -- a origem vira AIR, uma celula abaixo vira SAND, as duas chaves entram no diario,
# e a fila volta a zero. Vermelho hoje: nenhum consumidor existe, entao nada se move.

func _test_queda_move_a_celula() -> bool:
	if not _session_ok() or not _has_method_in(_main, "block_stats"):
		return _check(false, "queda_move_a_celula", _signature(
			"a pilha de teste nao desce uma celula em 120 ticks: o unico writer do grid e "
			+ "set_block (voxel_world.gd:302-313) e block_changed nao tem consumidor em src/"))
	var y0: int = _world.surface_height(SCENE_X, SCENE_Z)
	var shelf := Vector3i(SCENE_X, y0 + 1, SCENE_Z)
	var origin := Vector3i(SCENE_X, y0 + 2, SCENE_Z)
	_world.set_block(shelf, STONE, false)
	_world.set_block(origin, SAND, false)
	_tick(2)
	var edits_before: int = _world.edits.size()
	var reads_before: int = int(_stats().get("reads", 0))
	_log.clear()
	var n: int = _main.clock.tick
	# o apoio some pela porta do produto: set_block -> block_changed -> fila
	_world.set_block(shelf, AIR, false)
	var queued_at_trigger: int = int(_stats().get("queued", -1))
	var k: int = -1
	for _i in range(120):
		_tick(1)
		if _world.get_block(shelf) == SAND:
			k = _main.clock.tick - n
			break
	var st: Dictionary = _stats()
	var moved: bool = _world.get_block(origin) == AIR and _world.get_block(shelf) == SAND
	var journaled: bool = _world.edits.has(origin) and int(_world.edits[origin]) == AIR \
			and _world.edits.has(shelf) and int(_world.edits[shelf]) == SAND
	var ok: bool = moved and journaled and k > 0 and queued_at_trigger >= 1 \
			and int(st.get("queued", -1)) == 0 and int(st.get("falling", -1)) == 0 \
			and _world.edits.size() == edits_before + 2
	var ev: String = ("N=%d N+k=%d (k=%d) origem=(%d,%d,%d)->%d destino=(%d,%d,%d)->%d "
		+ "edits=%d->%d queued_no_gatilho=%d queued_final=%d em_voo=%d leituras=%d") % [
		n, n + maxi(k, 0), k,
		origin.x, origin.y, origin.z, _world.get_block(origin),
		shelf.x, shelf.y, shelf.z, _world.get_block(shelf),
		edits_before, _world.edits.size(), queued_at_trigger,
		int(st.get("queued", -1)), int(st.get("falling", -1)),
		int(st.get("reads", 0)) - reads_before]
	if not ok:
		ev = _signature(ev)
	return _check(ok, "queda_move_a_celula", ev)


# §5.3 -- pilha de N resolve em N ticks, nao em 1; e a ordem de resolucao e Y decrescente,
# nao a de insercao. As duas cenas da MESMA semente recebem os tres graos em ordens opostas
# de insercao e ainda assim resolvem igual -- com `_due` em ordem de dicionario os dois
# bracos divergiriam, que e exatamente a afirmacao do doc :720-722.

func _test_queda_cascade_em_passos() -> bool:
	if not _session_ok() or _hqueue(_h_b) == null or _hqueue(_h_c) == null \
			or _h_c.get("spawner") == null:
		return _check(false, "queda_cascade_em_passos", _signature(
			"nenhuma cascata para contar: sem fila nao ha conversoes por tick e nao ha "
			+ "ordem de resolucao a comparar entre dois mundos da mesma semente"))
	# (a) pilha de 6 no gemeo C: cada conversao gera o evento do grao de cima -> um por tick
	var wc: VoxelWorld = _h_c["world"]
	var y0: int = wc.surface_height(PILE_X, PILE_Z)
	_h_c["log"].clear()
	for i in range(PILE):
		wc.set_block(Vector3i(PILE_X, y0 + 1 + i, PILE_Z), SAND, false)
	wc.set_block(Vector3i(PILE_X, y0, PILE_Z), AIR, false)
	var pile: Dictionary = _drive(_h_c, 240)
	var pile_conversions: Array = pile["conversions"]
	var pile_ticks: int = pile_conversions.size()
	var one_per_tick: bool = pile_ticks == PILE \
			and pile_ticks > 0 and int((pile_conversions[0] as Array)[1].size()) == 1
	# (b) tres flutuantes com folga: inseridas em Y CRESCENTE em B e em Y DECRESCENTE em C.
	var yc: int = wc.surface_height(GAP_X, GAP_Z) + 2
	var ins_b: Array = []
	var ins_c: Array = []
	for up in range(3):
		var cell := Vector3i(GAP_X, yc + up * 4, GAP_Z)
		ins_b.append(cell.y)
		_h_b["world"].set_block(cell, SAND, false)
	for down in range(2, -1, -1):
		var other := Vector3i(GAP_X, yc + down * 4, GAP_Z)
		ins_c.append(other.y)
		wc.set_block(other, SAND, false)
	_h_b["log"].clear()
	_h_c["log"].clear()
	var db: Dictionary = _drive(_h_b, 200)
	var dc: Dictionary = _drive(_h_c, 200)
	var order_b: Array = _ys(db["conversions"])
	var order_c: Array = _ys(dc["conversions"])
	var desc: bool = order_b.size() == 3 and order_b[0] > order_b[1] and order_b[1] > order_b[2]
	var same: bool = _seq(order_b) == _seq(order_c)
	var insertion_diverged: bool = _seq(ins_b) != _seq(ins_c)
	var order_is_not_insertion: bool = _seq(order_b) != _seq(ins_b)
	var ok: bool = one_per_tick and desc and same and insertion_diverged \
			and order_is_not_insertion and int(db["queued"]) == 0 and int(dc["queued"]) == 0
	var ev: String = ("pilha=%d: ticks_de_conversao=%d um_grao_por_tick=%s ticks_totais=%d | "
		+ "flutuantes: insercao_B=%s insercao_C=%s resolvido_B=%s resolvido_C=%s "
		+ "ordem_Y_decrescente=%s par_igual=%s ordem_diferente_da_insercao=%s") % [
		PILE, pile_ticks, str(one_per_tick), int(pile["ticks"]),
		_seq(ins_b), _seq(ins_c), _seq(order_b), _seq(order_c),
		str(desc), str(same), str(order_is_not_insertion)]
	if not ok:
		ev = _signature(ev)
	return _check(ok, "queda_cascade_em_passos", ev)


# §5.4 -- a celula de pouso vem do APOIO, e o corpo em queda nao sobe degrau nenhum:
# `step_up` zero, pe monotono, pouso AO LADO da parede de 2 e nao em cima dela.

func _test_bloco_em_queda_nao_sobe() -> bool:
	if not _session_ok() or not _has_method_in(_main, "block_stats") \
			or not ResourceLoader.exists(FALLING_PATH, "GDScript"):
		return _check(false, "bloco_em_queda_nao_sobe", _signature(
			"sem entidade de bloco nao ha corpo a ler: step_up continua o 0,62 do VoxelBody "
			+ "(voxel_body.gd:19) e escape_embedded empurra para cima (:65-76)"))
	var y0: int = _world.surface_height(SCENE_X, SCENE_Z)
	var wall := Vector3i(SCENE_X + 1, y0 + 1, SCENE_Z)
	for i in range(2):
		_world.set_block(Vector3i(wall.x, y0 + 1 + i, wall.z), STONE, false)
	var shelf := Vector3i(SCENE_X, y0 + 1, SCENE_Z)
	var origin := Vector3i(SCENE_X, y0 + 2, SCENE_Z)
	_world.set_block(shelf, STONE, false)
	_world.set_block(origin, SAND, false)
	_tick(2)
	_log.clear()
	_world.set_block(shelf, AIR, false)
	var ys: Array = []
	var step_up: float = -1.0
	var on_ground_seen: bool = false
	var ticks_to_land: int = 0
	for i in range(160):
		_tick(1)
		var f: Array = _falling()
		if f.is_empty():
			if ys.is_empty():
				continue
			ticks_to_land = i + 1
			break
		var body = f[0].get("body")
		if body == null:
			continue
		var feet = body.get("feet_pos")
		if feet is Vector3:
			ys.append(roundf(float(feet.y) * 1000.0) / 1000.0)
		step_up = float(body.get("step_up"))
		if bool(body.get("on_ground")):
			on_ground_seen = true
			ticks_to_land = i + 1
			break
	var monotone: bool = ys.size() >= 2
	for j in range(1, ys.size()):
		if float(ys[j]) > float(ys[j - 1]) + 1e-6:
			monotone = false
	var landed := Vector3i(SCENE_X, y0 + 1, SCENE_Z)
	var above := Vector3i(SCENE_X, y0 + 3, SCENE_Z)
	var wall_top_free := Vector3i(wall.x, y0 + 3, wall.z)
	var beside: bool = _world.get_block(landed) == SAND \
			and _world.get_block(origin) == AIR \
			and _world.get_block(above) == AIR \
			and _world.get_block(Vector3i(wall.x, y0 + 1, wall.z)) == STONE \
			and _world.get_block(Vector3i(wall.x, y0 + 2, wall.z)) == STONE \
			and _world.get_block(wall_top_free) == AIR
	var ok: bool = ys.size() >= 2 and monotone and step_up == 0.0 and beside and on_ground_seen
	var ev: String = ("amostras_do_pe=%d ticks_ate_o_pouso=%d step_up=%.3f pe_monotono=%s "
		+ "no_chao=%s pouso=(%d,%d,%d)=%d origem=%d acima_da_pilha=%d parede=(%d,%d) "
		+ "topo_livre=%d feet_y=%s") % [
		ys.size(), ticks_to_land, step_up, str(monotone), str(on_ground_seen),
		landed.x, landed.y, landed.z, _world.get_block(landed), _world.get_block(origin),
		_world.get_block(above),
		_world.get_block(Vector3i(wall.x, y0 + 1, wall.z)),
		_world.get_block(Vector3i(wall.x, y0 + 2, wall.z)),
		_world.get_block(wall_top_free), _seq(ys)]
	if not ok:
		ev = _signature(ev)
	return _check(ok, "bloco_em_queda_nao_sobe", ev)


# §5.5 -- salvar no meio de uma cascata (`queued > 0`): o disco nao pode ver um bloco "nem
# la nem la". O quiesce dentro do `save_game()` e o que fecha a janela; sem ele a contagem
# de areias nao fecha, e o tick nao pode avancar (o journal exige `tick == last + 1`).

func _test_queda_pousa_antes_do_save() -> bool:
	if not _session_ok() or not _has_method_in(_main, "block_stats"):
		return _check(false, "queda_pousa_antes_do_save", _signature(
			"save_game() nao quiesce (settle_block_updates ausente) e nao ha cascata para "
			+ "interromper: o disco veria o mundo com grao em voo"))
	var y0: int = _world.surface_height(SAVE_X, SAVE_Z)
	var y_lo: int = y0
	var y_hi: int = y0 + PILE + 2
	var window: Array = []
	for y in range(y_lo, y_hi + 1):
		window.append(Vector3i(SAVE_X, y, SAVE_Z))
	for i in range(PILE):
		_world.set_block(Vector3i(SAVE_X, y0 + 1 + i, SAVE_Z), SAND)
	_world.set_block(Vector3i(SAVE_X, y0, SAVE_Z), AIR)
	# interrompe no meio: `queued > 0` e a condicao que o dossie poe na frente do save
	var in_flight: int = 0
	var ticks: int = 0
	while ticks < 4:
		_tick(1)
		ticks += 1
		in_flight = maxi(in_flight, int(_stats().get("queued", 0)) + _falling().size())
	var sand_mid: int = _count_sand(SAVE_X, SAVE_Z, y_lo, y_hi)
	var edits_mid: int = _world.edits.size()
	var tick_before: int = _main.clock.tick
	var settle = null
	if _has_method_in(_main, "settle_block_updates"):
		settle = _main.call("settle_block_updates")
	var tick_after_settle: int = _main.clock.tick
	_main.save_game()
	var tick_after_save: int = _main.clock.tick
	var edits_after: int = _world.edits.size()
	var sand_after: int = _count_sand(SAVE_X, SAVE_Z, y_lo, y_hi)
	var floating_after: int = _floating_sands(SAVE_X, SAVE_Z, y_lo, y_hi)
	var rd: Dictionary = SaveManager.read_slot(Main.SLOT)
	var disk_ok: bool = bool(rd.get("ok", false))
	var disk_sand: int = 0
	var disk_ghost: int = 0
	if disk_ok:
		var disk: Dictionary = rd["data"].get("edits", {})
		for c: Vector3i in window:
			var key: String = Coords.block_key(c)
			if disk.has(key):
				if int(disk[key]) == SAND:
					disk_sand += 1
				elif int(disk[key]) != AIR:
					disk_ghost += 1
	_main.load_game()
	var st: Dictionary = _stats()
	var sand_loaded: int = _count_sand(SAVE_X, SAVE_Z, y_lo, y_hi)
	var floating_loaded: int = _floating_sands(SAVE_X, SAVE_Z, y_lo, y_hi)
	var at_rest: bool = int(st.get("queued", -1)) == 0 and _falling().is_empty()
	var conserved: bool = sand_mid < PILE and sand_after == PILE and sand_loaded == PILE \
			and disk_sand == PILE and disk_ghost == 0
	var tick_frozen: bool = tick_after_settle == tick_before and tick_after_save == tick_before
	var ok: bool = in_flight >= 1 and conserved and disk_ok and floating_after == 0 \
			and floating_loaded == 0 and at_rest and tick_frozen
	var ev: String = ("em_voo_no_gatilho=%d areias: durante=%d depois_do_quiesce=%d "
		+ "apos_load=%d no_disco=%d fantasma_no_disco=%d | flutuantes: depois=%d apos_load=%d | "
		+ "edits=%d->%d slot_ok=%s quiesce=%s tick=%d->%d (no save: %d) at_rest=%s") % [
		in_flight, sand_mid, sand_after, sand_loaded, disk_sand, disk_ghost,
		floating_after, floating_loaded, edits_mid, edits_after, str(disk_ok),
		"sim" if settle is Dictionary else "NAO", tick_before, tick_after_settle,
		tick_after_save, str(at_rest)]
	if not ok:
		ev = _signature(ev)
	return _check(ok, "queda_pousa_antes_do_save", ev)


# §5.6 -- os dois bracos de sempre, lado a lado: 1.000 ticks sem areia e 1.000 ticks com a
# coluna caindo no tick 500. A atribuicao e por composicao, nao por adjetivo.

func _test_queda_nao_custou_tempo_de_ninguem() -> bool:
	if not _session_ok() or not _has_method_in(_main, "block_stats"):
		return _check(false, "queda_nao_custou_tempo_de_ninguem", _signature(
			"sem fila anexada nao ha braco com cascata: worst_sim_ms e max_queued nao existem "
			+ "como par lido do SimClock e do BlockUpdateQueue"))
	# braco A: mil ticks de sessao real sem nenhuma areia solta no grid
	_main.clock.reset_worst()
	var drop_a0: int = _main.clock.dropped_ticks
	var a: Dictionary = _tick_watch(ARM_TICKS)
	var a_worst: float = _main.clock.worst_step_ms
	var a_drop: int = _main.clock.dropped_ticks - drop_a0
	var a_st: Dictionary = _stats()
	# braco B: mesma sessao, coluna montada e o apoio arrancado no meio do braco
	var y0: int = _world.surface_height(ARM_X, ARM_Z)
	for i in range(PILE):
		_world.set_block(Vector3i(ARM_X, y0 + 1 + i, ARM_Z), SAND, false)
	_tick(2)
	_main.clock.reset_worst()
	var drop_b0: int = _main.clock.dropped_ticks
	var half: int = int(ARM_TICKS * 0.5)
	var b1: Dictionary = _tick_watch(half)
	_world.set_block(Vector3i(ARM_X, y0, ARM_Z), AIR, false)
	var b2: Dictionary = _tick_watch(ARM_TICKS - half)
	var b_worst: float = _main.clock.worst_step_ms
	var b_drop: int = _main.clock.dropped_ticks - drop_b0
	var b_st: Dictionary = _stats()
	var b_ticks: int = int(b1["ticks"]) + int(b2["ticks"])
	var maxq: int = maxi(int(b1["max_queued"]), int(b2["max_queued"]))
	var ok: bool = int(a["ticks"]) == ARM_TICKS and b_ticks == ARM_TICKS \
			and a_drop == 0 and b_drop == 0 \
			and a_worst <= STEP_CEILING_MS and b_worst <= STEP_CEILING_MS \
			and maxq >= 1 and int(a_st.get("queued", -1)) == 0 \
			and int(b_st.get("queued", -1)) == 0
	var ev: String = ("A sem areia: ticks=%d worst=%.2f ms perdidos=%d queued_final=%d | "
		+ "B cascata no tick %d: ticks=%d worst=%.2f ms max_queued=%d perdidos=%d "
		+ "queued_final=%d overflow=%d | teto do passo=%.1f ms dos %.0f ms do budget") % [
		int(a["ticks"]), a_worst, a_drop, int(a_st.get("queued", -1)),
		half, b_ticks, b_worst, maxq, b_drop, int(b_st.get("queued", -1)),
		int(b_st.get("overflow", 0)), STEP_CEILING_MS, SimClock.STEP * 1000.0]
	if not ok:
		ev = _signature(ev)
	return _check(ok, "queda_nao_custou_tempo_de_ninguem", ev)


# §5.7 -- par da mesma semente: sem movimento o hash reproduz o da rodada sem a fila; com a
# cascata ele diverge, e a divergencia e exatamente a dupla de chaves novas do diario.

func _test_journal_hash_muda_so_com_movimento() -> bool:
	if _hqueue(_h_a) == null or _hqueue(_h_b) == null or _h_b.get("spawner") == null:
		return _check(false, "journal_hash_muda_so_com_movimento", _signature(
			"par nao rodado: sem fila anexada nao ha o que comparar, e o state_hash so projeta "
			+ "world.edits (tick_journal.gd:16-21)"))
	var wa: VoxelWorld = _h_a["world"]
	var wb: VoxelWorld = _h_b["world"]
	var y0: int = wb.surface_height(HASH_X, HASH_Z)
	var shelf := Vector3i(HASH_X, y0, HASH_Z)
	var origin := Vector3i(HASH_X, y0 + 2, HASH_Z)
	# o cenario e todo ele `record = false`: invisivel ao diario nos dois mundos, entao as
	# unicas chaves registradas da cena inteira sao as DUAS que a queda escreve.
	for w: VoxelWorld in [wa, wb]:
		w.set_block(shelf, STONE, false)
		w.set_block(origin, SAND, false)
	var runs: int = 40
	# A nunca ouviu o sinal (fila criada, nunca anexada): e a rodada sem a peca.
	for t in range(1, runs + 1):
		_h_b["queue"].call("flush", t)
		_h_b["spawner"].call("step", SimClock.STEP)
	_h_a["tick"] = runs
	_h_b["tick"] = runs
	var ha_quiet: String = Journal.state_hash(runs, wa, _h_a["field"], [])
	var hb_quiet: String = Journal.state_hash(runs, wb, _h_b["field"], [])
	var equal_quiet: bool = ha_quiet == hb_quiet and ha_quiet.length() == 64
	# agora o apoio sai so no B, com a cascata andando ate o repouso
	var diff_before: Array = _edits_diff(wa, wb)
	wb.set_block(shelf, AIR, false)
	var pair: Dictionary = _drive(_h_b, 200)
	var moved: Array = _ys(pair["conversions"])
	var diff_after: Array = _edits_diff(wa, wb)
	var hb_moved: String = Journal.state_hash(int(_h_b["tick"]), wb, _h_b["field"], [])
	var ha_after: String = Journal.state_hash(int(_h_b["tick"]), wa, _h_a["field"], [])
	var diverged: bool = hb_moved != ha_quiet and ha_after == ha_quiet
	var attributed: bool = diff_before.is_empty() and diff_after.size() == 2
	var ok: bool = equal_quiet and diverged and attributed and int(pair["queued"]) == 0 \
			and _hfalling(_h_b).is_empty() and not moved.is_empty()
	var ev: String = ("sem_movimento: %d ticks hash_A=%.10s hash_B=%.10s iguais=%s | "
		+ "com_cascata: celulas=%s ticks=%d hash_A=%.10s hash_B=%.10s divergiu=%s | "
		+ "chaves_novas_do_diario=%d (%s) queued_final=%d em_voo=%d") % [
		runs, ha_quiet, hb_quiet, str(equal_quiet), _seq(moved), int(pair["ticks"]),
		ha_after, hb_moved, str(diverged), diff_after.size(), ", ".join(diff_after),
		int(pair["queued"]), _hfalling(_h_b).size()]
	if not ok:
		ev = _signature(ev)
	return _check(ok, "journal_hash_muda_so_com_movimento", ev)


## As chaves de `edits` em que os dois mundos da mesma semente discordam.
func _edits_diff(a: VoxelWorld, b: VoxelWorld) -> Array:
	var out: Array = []
	for k in a.edits:
		if not b.edits.has(k) or int(b.edits[k]) != int(a.edits[k]):
			out.append("%s:A=%d/B=%d" % [str(k), int(a.edits[k]), int(b.edits.get(k, -1))])
	for k in b.edits:
		if not a.edits.has(k):
			out.append("%s:A=-/B=%d" % [str(k), int(b.edits[k])])
	return out


# ------------------------------------------------------------- fechamento

func _cleanup() -> bool:
	# Lista fechada: este runner nao escreve arquivo proprio alem do slot do produto, e nao
	# varre user:// atras de nada. VoxelWorld e AetherField sao RefCounted: soltos por
	# referencia, nunca por free() -- `free` num RefCounted imprime SCRIPT ERROR e aborta o
	# passo, que e exatamente como uma checagem se perde em silencio.
	var main_ok: bool = is_instance_valid(_main)
	if main_ok:
		_world.block_changed.disconnect(_on_block)
		_main.free()
	_main = null
	if is_instance_valid(_stage):
		_stage.free()
	_stage = null
	_world = null
	_h_a = {}
	_h_b = {}
	_h_c = {}
	Input.mouse_mode = _mouse_mode
	return main_ok and not is_instance_valid(_stage)


func _finish() -> void:
	_check(_cleanup(), "limpeza somente dos nos deste runner",
			"palco_livre=%s" % str(_stage == null))
	_check(_completed == TESTS.size(), "todos os testes devolveram true",
			"%d/%d" % [_completed, TESTS.size()])
	_check(_checks + 1 == EXPECTED_CHECKS, "censo de checagens",
			"%d/%d" % [_checks + 1, EXPECTED_CHECKS])
	print("%d checagens %d falhas %d/%d testes concluidos %.3f s" % [
		_checks, _failures, _completed, TESTS.size(),
		float(Time.get_ticks_usec() - _started_us) / 1000000.0])
	quit(1 if _failures > 0 else 0)
