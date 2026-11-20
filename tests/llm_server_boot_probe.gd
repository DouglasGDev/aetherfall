extends Node
## Sonda viva do oraculo embutido no boot (dossie 15 §7, fora da suite): o proprio
## processo do jogo levanta o `llama-server`, mede o tempo ate o primeiro 200 e o
## que a janela fez enquanto o modelo carregava, e derruba o filho ao sair.
##
## Cada modo responde uma premissa diferente e nenhuma delas fica verde sem numero:
##   --mode=ci       sem runtime e sem rede: os dois motivos de falta e a linha do F3
##   --mode=boot     checagens 1, 2, 9 e 10: boot medido, janela viva, narrativa, chave
##   --mode=reuse    checagem 3: servidor nosso ja na porta => reuso, nunca segundo spawn
##   --mode=foreign  checagem 4: 401 ou alias errado => estrangeiro, e ninguem morre
##   --mode=death    checagem 5: morte externa depois do 200 => exatamente uma retentativa
##
## A checagem 6 (`fechar_janela_mata_o_filho`) nao pode ser medida por dentro: ela e
## o estado da porta depois de este processo ter saido, entao quem a mede e o runner
## externo, com o pid que o `create_process` imprimiu aqui no log.
##
## Uso (as flags vao depois do `--`):
##   godot --headless --path . tests/llm_server_boot_probe.tscn -- --mode=ci
##   godot --headless --path . tests/llm_server_boot_probe.tscn -- --mode=boot \
##       --llm-server=C:/caminho/llama-server.exe --llm-model=C:/caminho/modelo.gguf

## Criterio emprestado do probe de servidor na mao (`live_oracle_probe.gd:10`): a
## narrativa chega para dois lobos diferentes ou nao chegou.
const NEEDED_NARRATIONS := 2
## Teto da espera de narrativa, o mesmo do probe antigo: aqui o modelo ja esta no
## ar e o que se espera e a resposta do pedido.
const NARRATION_DEADLINE := 120.0
## Folga sobre o prazo do host para a sonda declarar vermelho antes de o processo
## do jogo ter virado a pagina do log.
const PROBE_SLACK := 20.0

var mode := "ci"
var keep := false
var expect := "reusado"
var url := ""
var server_flag := ""
var model_flag := ""

var main: Node3D = null
var host: LlmServerHost = null

var _phase := "boot"
var _frames := 0
var _t0 := 0
var _checks := 0
var _fails := 0
var _main_ready_ms := 0.0
var _loading_frame0 := -1
var _tick0 := -1
var _states: PackedStringArray = []
var _narr := 0
var _seen := {}
var _phase_t0 := 0
var _death_seen := false
var _ci_second: LlmServerHost = null


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--expect="):
			expect = arg.trim_prefix("--expect=")
		elif arg.begins_with("--url="):
			url = arg.trim_prefix("--url=")
		elif arg.begins_with("--llm-server="):
			server_flag = arg.trim_prefix("--llm-server=")
		elif arg.begins_with("--llm-model="):
			model_flag = arg.trim_prefix("--llm-model=")
		elif arg == "--keep":
			keep = true
	_t0 = Time.get_ticks_msec()
	print("sonda 15  modo=%s  display=%s  keep=%s  expect=%s" % [
		mode, DisplayServer.get_name(), str(keep), expect])
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	# O numero que a checagem 2 cobra: quanto custou abrir a janela. Se o modelo
	# estivesse dentro do `_ready` do mundo, este valor seria o boot inteiro.
	_main_ready_ms = float(Time.get_ticks_msec() - _t0)
	if not url.is_empty():
		main.oracle.server_url = url
	host = LlmServerHost.new()
	if mode == "ci":
		# Caminhos que nao existem de proposito: o portao do §4.4 fecha antes de
		# qualquer HTTP, entao este modo roda em arvore sem runtime e sem rede.
		host.server_path = "res://tests/sem-runtime-15.exe"
		host.model_path = "res://models/sem-modelo-15.gguf"
	if not server_flag.is_empty():
		host.server_path = server_flag
	if not model_flag.is_empty():
		host.model_path = model_flag
	host.keep_child_on_exit = keep
	host.state_changed.connect(_on_state)
	main.attach_llm_host(host)
	_states.append(host.state)
	_phase = "ci" if mode == "ci" else "boot"
	_phase_t0 = Time.get_ticks_msec()


func _on_state(next_state: String, _detail: String) -> void:
	_states.append(next_state)
	if next_state == host.LOADING and _loading_frame0 < 0:
		_loading_frame0 = _frames
		_tick0 = int(main.clock.tick)
	if next_state == host.DIED:
		_death_seen = true


func _process(_delta: float) -> void:
	_frames += 1
	match _phase:
		"ci":
			if _frames >= 6:
				_run_ci()
		"boot":
			_run_boot()
		"narrativas":
			_run_narrations()
		"morte":
			_run_death()


# ------------------------------------------------------------------- boot

func _run_boot() -> void:
	if host.state == host.IDLE or host.state == host.PROBING or host.state == host.LOADING:
		if _elapsed() > host.boot_deadline + PROBE_SLACK:
			_check(false, "o host chegou a um estado decidivel", "estado=%s  %.1f s" % [
				host.state, _elapsed()])
			_finish()
		return
	_report_window()
	if mode == "boot" and host.ready():
		_begin_narrations()
	elif mode == "reuse" and host.state == host.REUSED:
		_run_reuse()
	elif mode == "foreign":
		_run_foreign()
	elif mode == "death" and host.state == host.READY:
		_phase = "morte"
		_phase_t0 = Time.get_ticks_msec()
		print("sonda 15  esperando morte externa do pid %d  (taskkill /PID %d /F)" % [
			host.pid, host.pid])
	else:
		_check(false, "o modo %s esperava outro estado" % mode,
				"estado=%s  %s" % [host.state, host.detail])
		_finish()


## Checagem 2: a janela continuou girando enquanto o modelo carregava. Os frames e
## os ticks sao contados no braco entre o `create_process` e o primeiro 200, nao na
## sessao inteira — e o `main_ready` prova que o modelo nao entrou por la.
func _report_window() -> void:
	var d: Dictionary = main.diagnostics()
	var frames := _frames - _loading_frame0 if _loading_frame0 >= 0 else _frames
	var ticks := int(d["tick"]) - _tick0 if _tick0 >= 0 else int(d["tick"])
	var line := "janela  main_ready=%.0f ms  frames_no_braco=%d  tick_no_braco=%d" \
			+ "  pior_passo=%.2f ms  estado=%s  boot=%.0f ms  503=%d  pid=%d"
	print(line % [_main_ready_ms, frames, ticks, float(d["worst_sim_ms"]), host.state,
			host.boot_ms, host.loading_503, host.pid])
	if _loading_frame0 < 0:
		return
	_check(frames > 0, "a janela contou frames com o modelo carregando", "frames=%d" % frames)
	_check(ticks > 0, "o tick de 20 Hz andou com o modelo carregando", "tick=%d" % ticks)
	_check(int(d["dropped_ticks"]) == 0, "nenhum tick perdido durante o boot",
			"perdidos=%d  pior=%.2f ms" % [d["dropped_ticks"], float(d["worst_sim_ms"])])
	_check(_main_ready_ms < host.boot_ms, "o `_ready` do mundo nao esperou o modelo",
			"main_ready=%.0f ms  boot=%.0f ms" % [_main_ready_ms, host.boot_ms])


# ------------------------------------------------------------- reuso / estrangeiro

## Checagem 3: o servidor que sobrou do run A e reaproveitado, nao duplicado — e as
## narrativas continuam chegando, que e o outro lado da palavra "reuso".
func _run_reuse() -> void:
	_check(host.processes_spawned == 0, "reuso nao cria segundo processo",
			"spawns=%d  estados=%s" % [host.processes_spawned, ", ".join(_states)])
	_check(host.pid == -1, "reuso nao assume o pid alheio", "pid=%d" % host.pid)
	_check(host.ready(), "reuso libera o oraculo", "estado=%s" % host.state)
	_begin_narrations()


## Checagem 4, nos dois sentidos: 401 ou alias errado => `estrangeiro`; 200 com o
## alias => `reusado`. Nos dois, nenhum kill e nenhum spawn saiu daqui.
func _run_foreign() -> void:
	var esperado := expect == host.FOREIGN or expect == host.REUSED
	_check(esperado, "a sonda sabia o que esperar do fixture", "esperado=%s" % expect)
	_check(host.state == expect, "o estado da porta e o esperado",
			"estado=%s  esperado=%s  %s" % [host.state, expect, host.detail])
	_check(host.kills_issued == 0, "nada foi morto na porta alheia",
			"kills=%d  spawns=%d" % [host.kills_issued, host.processes_spawned])
	_check(host.processes_spawned == 0, "novo processo nao e criado em porta ocupada",
			"spawns=%d" % host.processes_spawned)
	print("sonda 15  F3: %s" % host.status_line())
	_finish()


# ------------------------------------------------------------------- narrativas

func _begin_narrations() -> void:
	_phase = "narrativas"
	_phase_t0 = Time.get_ticks_msec()


func _run_narrations() -> void:
	for w in main.wolves:
		var narr := String(main.oracle.narration_of(w.identity))
		if narr.is_empty() or _seen.has(w.identity):
			continue
		_seen[w.identity] = true
		_narr += 1
		print("lobo%d  +%.1f s  ia: %s" % [w.identity, _elapsed(), narr])
	if _narr >= NEEDED_NARRATIONS:
		# Checagem 9: as duas frases sairam sem nenhum PowerShell nosso no meio.
		_check(_narr >= NEEDED_NARRATIONS, "narrativa chega sem passo manual",
				"narrativas=%d  pedidos=%d" % [_narr, main.oracle.requests_issued])
		_check(main.oracle._server_cd < MindOracle.RETRY_COOLDOWN,
				"o carregamento nao deixou recuo de 30 s no oraculo",
				"recuo=%.1f s  ultimo=%s" % [main.oracle._server_cd, main.oracle.last_reason])
		if mode == "boot":
			_run_key_check()
		else:
			_finish()
		return
	if Time.get_ticks_msec() - _phase_t0 > int(NARRATION_DEADLINE * 1000.0):
		_check(false, "narrativa chega sem passo manual", "narrativas=%d em %.0f s" % [
			_narr, NARRATION_DEADLINE])
		_finish()


## Checagem 10, nos dois sentidos e no mesmo run: a chave no servidor nao calou a
## narrativa — sem header e 401, com header e 200 com texto.
func _run_key_check() -> void:
	_phase = "chave"
	var h := HTTPRequest.new()
	h.name = "KeyCheck"
	h.timeout = 30.0
	add_child(h)
	var body := JSON.stringify({
		"model": MindOracle.MODEL_ALIAS,
		"messages": [{"role": "user", "content": "Responda apenas: ok"}],
		"max_tokens": 4,
		"temperature": 0.0,
	})
	var u := String(main.oracle.server_url) + "/v1/chat/completions"
	h.request(u, PackedStringArray(["Content-Type: application/json"]),
			HTTPClient.METHOD_POST, body)
	var out: Array = await h.request_completed
	var sem_chave := int(out[1])
	h.request(u, main.oracle.auth_headers(), HTTPClient.METHOD_POST, body)
	out = await h.request_completed
	var texto := _texto(out[3] as PackedByteArray)
	_check(sem_chave == 401, "pedido sem a chave devolve 401", "codigo=%d" % sem_chave)
	_check(int(out[1]) == 200, "pedido com a chave devolve 200", "codigo=%d" % int(out[1]))
	_check(not texto.is_empty(), "a chave nao calou a resposta", "texto='%s'" % texto)
	h.queue_free()
	_finish()


func _texto(body: PackedByteArray) -> String:
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary):
		return ""
	var choices: Array = (data as Dictionary).get("choices", [])
	if choices.is_empty() or not (choices[0] is Dictionary):
		return ""
	return String(choices[0].get("message", {}).get("content", "")).strip_edges()


# ------------------------------------------------------------------- morte

func _run_death() -> void:
	if _death_seen and host.ready():
		# Checagem 5: viu a morte, voltou uma vez e nao virou loop.
		_check(_death_seen, "morte externa vista pelo host", "estados=%s" % ", ".join(_states))
		_check(host.retries == 1, "uma unica retentativa", "retentativas=%d" % host.retries)
		_check(host.processes_spawned == 2, "dois spawns: o boot e a retentativa",
				"spawns=%d" % host.processes_spawned)
		_finish()
		return
	if _death_seen and host.state == host.OFF:
		_check(false, "a primeira morte deveria tentar de novo",
				"estados=%s" % ", ".join(_states))
		_finish()
		return
	if Time.get_ticks_msec() - _phase_t0 > int((host.boot_deadline + PROBE_SLACK) * 1000.0):
		_check(false, "morte externa nao chegou ao host", "estados=%s" % ", ".join(_states))
		_finish()


# ------------------------------------------------------------------- ci

## Checagem 7 sem runtime e sem rede: os dois motivos sao diferentes, nenhum pedido
## sai, e a linha do F3 diz qual pack falta.
func _run_ci() -> void:
	_ci_second = LlmServerHost.new()
	# Executavel que existe (este proprio script) e modelo que nao existe: o
	# segundo motivo sem levantar processo nem porta nenhum.
	_ci_second.server_path = "res://tests/llm_server_boot_probe.gd"
	_ci_second.model_path = "res://models/sem-modelo-15.gguf"
	add_child(_ci_second)
	await get_tree().process_frame
	await get_tree().process_frame
	var l1 := host.status_line()
	var l2 := _ci_second.status_line()
	_check(host.state == host.NO_RUNTIME, "binario ausente da o motivo do runtime",
			"estado=%s" % host.state)
	_check(_ci_second.state == host.NO_MODEL, "modelo ausente da o motivo do modelo",
			"estado=%s" % _ci_second.state)
	_check(l1.contains("fetch_models.ps1") and l1.contains("-Pack runtime"),
			"o F3 do runtime diz qual pack rodar", l1)
	_check(l2.contains("-Pack mind-small"), "o F3 do modelo diz qual pack rodar", l2)
	_check(l1 != l2, "os dois motivos nao sao a mesma frase", "runtime x modelo")
	_check(host.requests_issued == 0 and _ci_second.requests_issued == 0,
			"sem packs, zero pedidos HTTP", "pedidos=%d+%d" % [
				host.requests_issued, _ci_second.requests_issued])
	_check(host.processes_spawned == 0 and _ci_second.processes_spawned == 0,
			"sem packs, zero processos criados", "spawns=%d+%d" % [
				host.processes_spawned, _ci_second.processes_spawned])
	_check(main.oracle.requests_issued == 0, "o portao fecha o oraculo do jogo",
			"pedidos=%d  estado=%s" % [main.oracle.requests_issued, host.state])
	var llm: Dictionary = main.diagnostics()["llm"]
	_check(not llm.is_empty(), "o diagnostico do jogo traz o bloco llm", str(llm.keys()))
	_finish()


# ------------------------------------------------------------------- saida

func _elapsed() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0


## Sair daqui e o que a checagem 6 mede de fora: o `_exit_tree` do host roda nesta
## hora, e a porta tem de recusar conexao logo depois (exceto com `--keep`).
func _finish() -> void:
	_phase = "fim"
	print("sonda 15  modo=%s  %d checagens  %d falhas  %.1f s  llm=%s" % [
		mode, _checks, _fails, _elapsed(), host.status_line()])
	get_tree().quit(0 if _fails == 0 else 1)


func _check(condition: bool, label: String, detail: String) -> bool:
	_checks += 1
	if not condition:
		_fails += 1
	print("%s  %s  [%s]" % ["OK   " if condition else "FALHA", label, detail])
	return condition
