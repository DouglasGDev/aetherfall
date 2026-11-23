extends SceneTree
## af-bench (dossie 07, peças b e c): dirige a SESSAO REAL com `dt` fixo e mede a unica
## coisa que o `delta` de parede nao deixa medir — se a mesma semente devolve a mesma
## sequencia de hashes da projecao do journal ao longo de 12 000 passos.
##
## O que este runner NAO e, com todas as letras (dossie 07 §3 e §8):
## - NAO e replay. `TickJournal` grava `[tick, hash]` apendice-only
##   (src/persistence/tick_journal.gd:69-87) e nao existe caminho nenhum do arquivo de
##   volta para o mundo: nada aqui refaz estado a partir do que foi gravado.
## - NAO prova determinismo da simulacao inteira. O hash cobre a projecao minima
##   (`:16-44`) e EXCLUI jogador, corpos, RNG, episodios, relacoes, timers e comandos.
##   Tres hashes iguais provam determinismo DO QUE ESTA NA PROJECAO.
## - NAO fecha gate de fase nenhum (mandato 4).
##
## Por que `dt` fixo remove a maquina do resultado: `main._physics_process(delta)` passa
## o `delta` de parede para `clock.advance` (src/main.gd:242-248) e o teto de
## `MAX_STEPS_PER_FRAME` virar `dropped_ticks` quando a maquina atrasa
## (src/core/sim_clock.gd:19-29) — ou seja, ao vivo o numero de ticks e a sequencia de
## estados dependem do relogio de parede. Chamando o metodo com `delta == STEP`, a
## subtracao `0,05 - 0,05` e exatamente zero e cada chamada devolve um passo so.
##
## A outra metade da mesma porta: `process_mode = DISABLED` entra ANTES de a sessao ir
## para a arvore, entao o motor nao chama `_physics_process`/`_process` de node nenhum
## por cima dos nossos (precedente: tests/tick_journal_test.gd:74-76). Quem locomove os
## corpos somos nos, com `STEP` — incluindo o lobo, que no jogo vivo anda por frame
## (src/entities/wolf.gd:941-989). Consequencia honesta e escrita no readback: aqui cada
## tick tem UM passo de integracao de 0,05 s, e nao ~3 passos de 16,7 ms da janela a
## 60 Hz, entao a trajetoria dos corpos e outra; o que se compara e a projecao.

const Main = preload("res://src/main.gd")
const Journal = preload("res://src/persistence/tick_journal.gd")
const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")

const SCENARIO := "boot_walk_10min"
# 600 s de logica / STEP = 1/20 s = 12 000 passos (src/core/sim_clock.gd:5-6). O numero
# E o gate da peca: corrida mais curta "so para ver" nao sustenta a premissa.
const TICKS := 12000
# Vaivem do andar: 30 s de logica para cada lado. Serve a uma premissa, nao a enfeite —
# um jogador que anda reto por 10 min sai do mundo e a matilha passa o resto da corrida
# sem alvo movel; o vai-e-vem mantem o corpo no vale e as mentes lendo reacao real.
const WALK_LEG := 600
# 15 checagens + a do proprio censo. Contar checagem e o que pega o SCRIPT ERROR que
# derruba um passo em silencio (mandato 1): quatro corridas deram 215 em vez de 219.
const EXPECTED_CHECKS := 16

var _checks: int = 0
var _failures: int = 0
var _ran: bool = false
var _started_us: int = 0
var _mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _main: Main = null
var _journal: Journal = null
var _step_anomalies: int = 0
var _first_anomaly: int = -1
var _anomaly_reason: String = ""
## Estouro do `SubtreeGuard` por identidade (ultimo valor lido do contador do lobo).
## Guarda porque premissa: `tick()` lee `Time.get_ticks_usec()` e devolve FAILURE quando
## o passo passa de 400 us (src/ai/behavior/bt_tree.gd:130-137, orcamento declarado em
## src/entities/wolf.gd:380-381). Dentro da subtree guardada ha folha que escreve o que a
## projecao lee: o imprint de MEDO no Eter (src/entities/wolf.gd:431) e o
## `mind.remember` do rastro examinado (:559). Um estouro e, portanto, um ramo decidido por
## relogio de parede dentro do caminho hashado. `intent` em si nao sai da arvore (e do
## scorer, :784), entao o risco nao e a troca de intento e sim a escrita suprimida.
var _bt_trips: Dictionary = {}
## Onde o estouro aconteceu. Contar sem localizar deixaria o numero mudo: se todos os
## estouros caem nos primeiros ticks, a causa e aquecimento da arvore; se espalhados pelo
## lote, e carga da maquina no meio da corrida. Os dois sao riscos diferentes e o
## readback precisa dizer qual deles aconteceu.
var _trip_total: int = 0
var _trip_where: Array[String] = []
## Microssegundos que a PROPRIA guarda mediu no tick do estouro (`last_us`,
## src/ai/behavior/bt_tree.gd:133-135). Serve a uma coisa: dizer ao dono se o estouro e
## de beira de orcamento (decisao de budget) ou spike de varios ms (decisao de busca de
## causa). Nao e gate e nao e numero de performance da maquina.
var _trip_us_min: int = 0
var _trip_us_max: int = 0
var _walk_forward: bool = true
var _spawn := Vector3.ZERO
var _walk_max: float = 0.0


func _initialize() -> void:
	_started_us = Time.get_ticks_usec()
	_mouse_mode = Input.mouse_mode
	# Sem `await`: o rodape sai mesmo se a sessao abortar no meio do laco.
	_run.call_deferred()
	_finish.call_deferred()


func _check(ok: bool, label: String, detail: String) -> bool:
	_checks += 1
	print("%s %-42s %s" % ["OK" if ok else "FALHA", label, detail])
	if not ok:
		_failures += 1
	return ok


func _arg(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


func _run() -> void:
	# --- premissa 1: o cenario vem da CLI e e nomeado. Sem isso o runner estaria
	# inventando um lote de ticks que nenhum gate pediu.
	var pedido: String = _arg("--scenario=")
	var caminho: String = _arg("--tick-journal=")
	var cli_ok: bool = _check(pedido == SCENARIO, "cenario nomeado na CLI",
			"pedido=%s gate=%s ticks=%d" % [pedido, SCENARIO, TICKS])
	cli_ok = _check(not caminho.is_empty(), "caminho de journal na CLI", caminho) \
			and cli_ok
	if not cli_ok:
		_ran = true
		return

	# --- boot real. `_ready` gera o mundo, malha os 64 chunks e abre o journal pela
	# mesma porta do jogo (`_start_journal_from_args`, src/main.gd:993-1000), entao o
	# que se roda aqui e a sessao do produto, nao uma maquete de estado.
	_main = MAIN_SCENE.instantiate() as Main
	_main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_main)
	_journal = _main.tick_journal
	# `start()` recusa caminho existente (src/persistence/tick_journal.gd:50-51): se o
	# journal abriu, o arquivo E novo por execucao — sem reabrir historico.
	_check(_journal.active() and _journal.path == caminho and _journal.records == 0
			and _journal.last_tick == -1, "journal novo aberto pelo main",
			"ativo=%s path=%s records=%d last_tick=%d" % [
			str(_journal.active()), _journal.path, _journal.records, _journal.last_tick])
	var fila: int = int(_main.diagnostics()["pending_respawns"])
	_check(_main.is_node_ready() and _main.world != null and _main.clock != null
			and _main.aether != null and _main.player != null
			and _main.wolves.size() + fila == Main.WOLF_COUNT,
			"boot real concluiu", "lobos=%d fila=%d teto=%d tick=%d" % [
			_main.wolves.size(), fila, Main.WOLF_COUNT, _main.clock.tick])
	# O motor nao pode adicionar passo nenhum por cima do nosso: se algum node ainda
	# processa, a contagem de frames e da maquina e a premissa inteira cai.
	var primeiro_lobo: Wolf = null if _main.wolves.is_empty() else _main.wolves[0] as Wolf
	_check(_main.process_mode == Node.PROCESS_MODE_DISABLED
			and not _main.can_process() and not _main.player.can_process()
			and not _main.oracle.can_process()
			and (primeiro_lobo == null or not primeiro_lobo.can_process()),
			"motor sem processo automatico", "main=%s player=%s oracle=%s lobo=%s" % [
			str(not _main.can_process()), str(not _main.player.can_process()),
			str(not _main.oracle.can_process()),
			str(primeiro_lobo == null or not primeiro_lobo.can_process())])

	# --- o andar e input real (`Input.action_press`), nao campo escrito a mao: e o
	# mesmo estado que `player._wish_direction()` lee na janela viva (mandato: nao
	# montar premissa escrevendo campo quando o jogo tem a transicao).
	_spawn = _main.player.body.feet_pos
	Input.action_press(&"move_forward")
	var dt: float = _main.clock.step_duration()
	for i: int in TICKS:
		var tick_antes: int = _main.clock.tick
		_main._physics_process(dt)
		# Locomocao do lobo no lugar do motor, com o mesmo `dt` do passo de decisao.
		for w: Wolf in _main.wolves:
			w._physics_process(dt)
			if w._guard != null:
				# Guarda por identidade: um lobo retirado leva o `_guard` dele para o
				# `queue_free`, entao contar so o roster do fim deixaria estouro de fora
				# sem testemunha. O incremento e lido no tick em que aconteceu.
				var vistos: int = int(_bt_trips.get(w.identity, 0))
				if w._guard.trips > vistos:
					_trip_total += w._guard.trips - vistos
					if _trip_where.size() < 8:
						_trip_where.append("tick %d/lobo %d" % [i, w.identity])
					if _trip_us_min == 0 or w._guard.last_us < _trip_us_min:
						_trip_us_min = w._guard.last_us
					_trip_us_max = maxi(_trip_us_max, w._guard.last_us)
					_bt_trips[w.identity] = w._guard.trips
				else:
					_bt_trips[w.identity] = vistos
		# Fila de malharia com o orcamento de frame do jogo (2 chunks); nao entra na
		# projecao, mas roda para o lote nao ser "so IA sem mundo".
		_main._process(dt)
		var d: float = Vector2(_main.player.body.feet_pos.x - _spawn.x,
				_main.player.body.feet_pos.z - _spawn.z).length()
		if d > _walk_max:
			_walk_max = d
		# Duas contas que so podem fechar juntas: um passo por chamada e um registro
		# por passo. O `quit(1)` de `_sim_tick` (:286-289) so tem efeito na volta
		# ao motor, entao o laco precisa cortar sozinho — senao seguem-se 12 000
		# chamadas num journal ja fechado e o rodape mentiria.
		if _main.clock.tick != tick_antes + 1 or _journal.records != _main.clock.tick:
			_step_anomalies += 1
			_anomaly_reason = "tick %d->%d records=%d" % [tick_antes, _main.clock.tick, _journal.records]
			if _first_anomaly < 0:
				_first_anomaly = i
			break
		if i % WALK_LEG == WALK_LEG - 1:
			_toggle_walk()
	Input.action_release(&"move_forward")
	Input.action_release(&"move_back")
	_ran = true

	# A checagem do passo e separada da do total de proposito: se um chamada quebrar a
	# cadencia, o motivo (tick e records fora da linha, com o passo do primeiro desvio)
	# tem de aparecer vermelho sozinho, e nao engolido pela contagem final do lote.
	_check(_step_anomalies == 0, "cada chamada avanca um tick e grava um registro",
			"anomalias=%d%s" % [_step_anomalies,
			("" if _first_anomaly < 0 else " primeiro desvio no passo %d: %s" % [
			_first_anomaly, _anomaly_reason])])
	_check(_main.clock.tick == TICKS, "o lote fecha em TICKS ticks",
			"tick=%d/%d passos_chamados=%d" % [_main.clock.tick, TICKS, TICKS])
	var diag: Dictionary = _main.diagnostics()
	# Colhido antes do `free`: as observacoes do rodape tem de sair do objeto vivo, e
	# nao de um Nil — erro de script dentro de um passo derruba checagem em silencio.
	var deaths: int = int(_main.stats["deaths"])
	_check(int(diag["dropped_ticks"]) == 0, "nenhum tick perdido",
			"perdidos=%d passos_pedidos=%d" % [diag["dropped_ticks"], TICKS])
	_check(_journal.records == TICKS and _journal.last_tick == TICKS,
			"um registro por tick, sem buraco", "records=%d last_tick=%d" % [
			_journal.records, _journal.last_tick])
	_check(_walk_max > 1.0, "o cenario anda (nao e boot parado)",
			"maior_distancia_do_spawn=%.2f m" % _walk_max)

	# --- re-leitura do arquivo: o gate conta `records` a partir do disco, nao da
	# memoria do objeto, senao seria a vitima confirmando o proprio depoimento.
	var lido: Dictionary = _read_back(_journal.path)
	if not bool(lido["ok"]):
		_check(false, "arquivo do journal relido", String(lido["erro"]))
		return
	_check(int(lido["lines"]) == TICKS and bool(lido["monotonic"]),
			"arquivo tem TICKS linhas com tick 1..N", "linhas=%d monotonicas=%s bytes=%d" % [
			lido["lines"], str(lido["monotonic"]), lido["bytes"]])
	_check(String(lido["last"]) == _journal.last_hash
			and _journal.last_hash == _main.state_hash(),
			"ultima linha == hash do estado atual",
			"arquivo=%s memoria=%s" % [String(lido["last"]).left(16), _journal.last_hash.left(16)])
	# Sem esta, tres hashes iguais poderiam ser tres execucoes de um mundo parado.
	_check(int(lido["distinct"]) > 1, "a projecao moveu durante a corrida",
			"hashes_distintos=%d/%d primeiro=%s ultimo=%s" % [
			lido["distinct"], TICKS, String(lido["first"]).left(16), String(lido["last"]).left(16)])
	# O estouro da guarda SAI como observacao, nao como checagem (decisao do dono do
	# registro depois da revisão desta peça): o gate da peca e `records`, `dropped_ticks`,
	# hash identico e exit code. Esconder o numero seria o outro erro — ele e a testemunha
	# de que ainda existe um canal de relogio de parede dentro do caminho hashado, entao
	# fica impresso com o tick de cada disparo e com a linha que o explica.
	print(("OBSERVACAO estouros_guarda=%d lobos_com_guarda_lida=%d budget_us=400 "
			+ "last_us=%s ticks=%s") % [
			_trip_total, _bt_trips.size(),
			("(sem estouro)" if _trip_total == 0 else "%d..%d" % [_trip_us_min, _trip_us_max]),
			("(nenhum)" if _trip_where.is_empty() else ", ".join(_trip_where))])
	if _trip_total > 0:
		print("POR QUE IMPORTA: a guarda devolve FAILURE pelo relogio de parede "
				+ "(src/ai/behavior/bt_tree.gd:130-137) e a folha suprimida pode escrever "
				+ "Eter (src/entities/wolf.gd:431) ou crenga (:559), que entram na projecao "
				+ "-- corridas com estouros diferentes nao sao prova limpa de determinismo, "
				+ "sao a mesma sorte.")

	# `free()` exercita o `_exit_tree` real (src/main.gd:1003-1004), que fecha o
	# arquivo; o byte-final nao pode ter crescido, senao "fechar" e ficcao.
	var bytes_antes: int = int(lido["bytes"])
	_main.free()
	_main = null
	var depois: Dictionary = _read_back(_journal.path)
	_check(not _journal.active() and int(depois["bytes"]) == bytes_antes,
			"sair da sessao fecha o journal", "ativo=%s bytes=%d->%d" % [
			str(_journal.active()), bytes_antes, depois["bytes"]])

	# O que a checagem NAO prova, impresso junto do numero: nada de FPS, nada de
	# replay, nada de determinismo do que a projecao nao cobre.
	print("escopo: hash cobre Eter(Float32), edicoes, lobos por identidade com mente/"
			+ "intent/crencas e metadados; exclui jogador, corpos, RNG, episodios, "
			+ "relacoes, timers e comandos")
	print("NAO e replay: o arquivo e apendice-only e nenhum byte dele volta para o mundo")
	print("NAO fecha: determinismo da PROJECAO nesta maquina; corpo, RNG, jogador, "
			+ "episodios e relacoes estao fora do hash, e o canal de relogio da guarda "
			+ "segue aberto (veja OBSERVACAO estouros_guarda acima)")
	# Parenteses obrigatorios: sem eles o `%` so pega o ultimo fragmento concatenado e o
	# print viram "%d" literais com ERROR de formatacao no log — exatamente o erro
	# silencioso que o mandato 1 diz para nao deixar passar.
	print(("OBSERVACAO lobos_vivos=%d/%d nascimentos=%d mortes_jogador=%d edits=%d "
			+ "eter_energia=%.4f pares=%d") % [
			diag["wolves_alive"], diag["wolves"], diag["births"], deaths,
			diag["edits"], diag["aether_energy"], diag["pack_pairs"]])
	# As quatro testemunhas do gate numa linha so, com o nome do cenario e o tamanho do
	# lote: records lidos do arquivo, dropped_ticks do relogio, tick final e o hash da
	# ultima linha. Nenhum tempo de parede entra aqui (mandato 5).
	print("GATE cenario=%s ticks_lote=%d tick_final=%d records=%d linhas_arquivo=%d "
			% [SCENARIO, TICKS, diag["tick"], _journal.records, lido["lines"]]
			+ "dropped_ticks=%d maior_andar=%.1f m hash_ultima_linha=%s" % [
			diag["dropped_ticks"], _walk_max, String(lido["last"])])
	print("ARQUIVO %s bytes=%d sha256=%s" % [
		_journal.path, lido["bytes"], FileAccess.get_sha256(_journal.path)])


func _toggle_walk() -> void:
	Input.action_release(&"move_forward" if _walk_forward else &"move_back")
	_walk_forward = not _walk_forward
	Input.action_press(&"move_forward" if _walk_forward else &"move_back")


## Le o arquivo de volta e devolve as testemunhas: linhas, monotonicidade dos ticks,
## bytes, primeiro/ultimo hash e quantos hashes distintos a corrida produziu.
func _read_back(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "erro": "abrir %s: %s" % [path, error_string(FileAccess.get_open_error())]}
	var lines: int = 0
	var distinct: int = 0
	var monotonic: bool = true
	var previous: String = ""
	var first: String = ""
	var last: String = ""
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.strip_edges().is_empty():
			continue
		var parser: JSON = JSON.new()
		if parser.parse(line) != OK or not (parser.data is Array) or (parser.data as Array).size() != 2:
			monotonic = false
			last = "linha %d nao e JSON [tick,hash]" % (lines + 1)
			break
		var row: Array = parser.data
		lines += 1
		if int(row[0]) != lines:
			monotonic = false
		var h: String = String(row[1])
		if h != previous:
			distinct += 1
			previous = h
		if first.is_empty():
			first = h
		last = h
	var bytes: int = file.get_length()
	file.close()
	return {"ok": true, "lines": lines, "monotonic": monotonic, "distinct": distinct,
		"first": first, "last": last, "bytes": bytes}


func _finish() -> void:
	Input.mouse_mode = _mouse_mode
	_check(_ran, "runner chegou ao fim do lote", "run=%s" % str(_ran))
	_check(_checks + 1 == EXPECTED_CHECKS, "censo de checagens",
			"%d/%d" % [_checks + 1, EXPECTED_CHECKS])
	print("%d checagens %d falhas %.3f s" % [
		_checks, _failures, float(Time.get_ticks_usec() - _started_us) / 1000000.0])
	quit(1 if _failures > 0 else 0)
