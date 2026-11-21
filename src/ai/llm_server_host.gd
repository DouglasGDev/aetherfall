class_name LlmServerHost
extends Node
## Dono do processo filho do oraculo local: levanta o `llama-server` no boot,
## derruba-o ao sair da cena e nunca toca num servidor que nao foi ele quem subiu.
##
## O pedido do dono (dossie 15): "ao startar o game, tem que carregar o modelo de
## i.a na maquina [...] sem eu ter que abrir depois". A doc do motor diz que o
## processo criado por `OS.create_process` "will not terminate when Godot
## terminates", entao o fecho aqui nao e cosmetico: sem ele o filho fica orfao,
## com a porta aberta e 2,7 GB de modelo residente ate alguem mata-lo na mao
## (dossie 15 §0.1: o b12499 nao tem `--watch-file`, e `--timeout` e timeout de
## socket, nao saida por ociosidade).
##
## Nada aqui decide estado de mundo (mandato 2): o host fala com um processo e com
## uma porta TCP local. Nada aqui roda no tick de 20 Hz: o custo pesado e de
## outro processo, e o cadenciamento e por frame com cooldown, no padrao do
## `MindOracle`.

signal server_ready
signal state_changed(state: String, detail: String)

## Estados da matriz de falha do dossie 15 §5 — cada um tem de aparecer no log e
## na linha do F3, nao no console do motor nem em popup.
const IDLE := "ocioso"
const NO_RUNTIME := "ausente (runtime)"
const NO_MODEL := "ausente (modelo)"
const PROBING := "sondando"
const LOADING := "carregando"
const READY := "pronto"
const REUSED := "reusado"
const FOREIGN := "estrangeiro"
const DIED := "caiu"
const OFF := "desligado"

## Cadencias. O teto de 1 s e o precedente da casa (`CORPSE_CHECK_PERIOD` em
## `src/main.gd`); 0,2 s e a cadencia de boot proposta pelo dossie 15 §6.
const PROBE_PERIOD := 0.2
const WATCH_PERIOD := 1.0
## Timeout curto e proprio da sonda: ela nunca herda os 8 s do oraculo, senao um
## terceiro pendurado na porta congela a cadencia do boot.
const PROBE_TIMEOUT := 1.5
## Uma unica retentativa por sessao (dossie 15 §4.3): o §0.1 garante que nada no
## servidor se autocorrige, entao a segunda morte e fim de tentativa.
const RETRY_LIMIT := 1
## Prazo de boot do modelo, em segundos. E um teto declarado, nao um numero
## medido: a corrida que produz o ms real desta maquina esta na perna 15
## (`docs/evidence/oraculo-embutido/`) e o valor dela vai na nota de status, nao
## aqui dentro — ate la, assumir o dobro do pior boot ja visto na mesa (o probe
## antigo `tests/live_oracle_probe.gd` usava 120 s para o mesmo modelo) e dizer
## que e hipotese. Estourar este prazo e vermelho no F3, nao degradacao
## silenciosa.
const BOOT_DEADLINE := 90.0
## Alias publicado pelo servidor e nomeado no pedido do oraculo: e a impressao
## digital que separa o nosso servidor do de um terceiro na mesma porta. O dono da
## string e o `MindOracle`, que e quem a escreve no corpo do pedido.
const ALIAS := MindOracle.MODEL_ALIAS

## Caminhos dos packs. `models/` e `.tools/` estao no `.gitignore`, entao o
## padrao e relativo ao diretorio do projeto e o override (export, `--llm-server=`,
## `AETHERFALL_LLM_SERVER`) existe para o probe rodar num worktree, onde so o
## checkout principal tem o runtime — sem isso a medicao real so aconteceria la.
@export var server_path: String = ""
@export var model_path: String = ""
@export var ctx_size: int = 4096
@export var gpu_layers: int = 99
@export var boot_deadline: float = BOOT_DEADLINE

## Dono da porta: o host le `server_url` do oraculo em vez de repetir o 8741
## (dossie 15 §9, "nao duplicar a porta").
var oracle: MindOracle = null
## Preserva o filho ao sair: e a flag `--keep` da cena de prova, que fabrica de
## proposito o estado "sobrou de um crash" que a checagem de reuso exige.
var keep_child_on_exit := false

var state: String = IDLE
var pid: int = -1
## Numeros da checagem, nao adjetivos: o caminho do `create_process` ate o
## primeiro 200, os 503 vistos no meio e a contagem de retentativas.
var boot_ms: float = -1.0
var loading_503 := 0
var retries := 0
var requests_issued := 0
var kills_issued := 0
var processes_spawned := 0
var detail: String = ""

var _http: HTTPRequest = null
var _cd := 0.0
var _watch_cd := 0.0
var _spawn_ms := 0
var _busy := false
var _owns_child := false
## Codigo de saido lido no instante da morte: imprimir o numero em vez de
## adivinhar e o que o `OS.get_process_exit_code` existe para fazer.
var _last_exit_code := -1


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "Probe"
	_http.timeout = PROBE_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_probe_response)


func _process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	_watch_cd = maxf(_watch_cd - delta, 0.0)
	match state:
		IDLE:
			_begin()
		PROBING, LOADING:
			if state == LOADING and _past_deadline():
				_fail("prazo de %.0f s estourou no boot do modelo" % boot_deadline)
			elif not _busy and _cd <= 0.0:
				_probe()
		READY:
			# So o que eu subi tem de ser vigiado: reuso nao da direito de matar,
			# e vigiar o processo alheio seria o mesmo erro.
			if _owns_child and _watch_cd <= 0.0:
				_watch_cd = WATCH_PERIOD
				if not OS.is_process_running(pid):
					_on_death("is_process_running falso no pid %d" % pid)


## Portao do oraculo (dossie 15 §4.4): enquanto o modelo carrega nao adianta
## pedir — um 503 de "Loading model" viraria o recuo cego de 30 s que engole a
## primeira narrativa da sessao.
func ready() -> bool:
	return state == READY or state == REUSED


func status_line() -> String:
	match state:
		NO_RUNTIME, NO_MODEL:
			return "llm: %s  rode tools\\fetch_models.ps1 -Pack %s" % [
				state, "runtime" if state == NO_RUNTIME else "mind-small"]
		FOREIGN:
			return "llm: porta %d ocupada por outro servidor  oraculo desligado" % _port()
		DIED:
			return "llm: caiu (codigo %d)  retentativa %d/%d" % [
				_last_exit_code, retries, RETRY_LIMIT]
		OFF:
			return "llm: desligado  %s" % detail
		REUSED:
			return "llm: reuso do servidor existente  porta %d" % _port()
		READY:
			var tail := ""
			# Um 401 do oraculo nao pode virar recuo anonimo no F3: o estado do
			# servidor esta certo e a falha e outra, entao as duas pontas aparecem
			# juntas (dossie 15 §9).
			if oracle != null and not oracle.last_reason.is_empty():
				tail = "  oraculo: %s" % oracle.last_reason
			return "llm: %s  porta %d  pid %d  boot %.0f ms  503=%d%s" % [
				state, _port(), pid, boot_ms, loading_503, tail]
	return "llm: %s  %s" % [state, detail]


func diagnostics() -> Dictionary:
	return {
		"state": state, "pid": pid, "boot_ms": boot_ms, "loading_503": loading_503,
		"retries": retries, "requests": requests_issued, "kills": kills_issued,
		"spawned": processes_spawned, "detail": detail, "url": _url(),
	}


# ------------------------------------------------------------------ boot

## Primeira passada: resolve os caminhos e pergunta à porta antes de criar
## qualquer coisa. Nenhum `await` aqui: o `_ready` do jogo ja congela a janela com
## geracao e malharia, e e exatamente por isso que o modelo nao entra por essa
## porta (dossie 15 §1.2).
func _begin() -> void:
	var server := _resolved_server()
	var model := _resolved_model()
	# Os dois motivos sao diferentes de proposito: "-Pack runtime" e "-Pack
	# mind-small" nao sao a mesma falta, e o mandato 1 nao permite placeholder
	# bonito no meio da frase.
	if not FileAccess.file_exists(server):
		_set_state(NO_RUNTIME, "sem llama-server em %s" % server)
		return
	if not FileAccess.file_exists(model):
		_set_state(NO_MODEL, "sem modelo em %s" % model)
		return
	_set_state(PROBING, "sonda /v1/models em %s" % _url())


func _url() -> String:
	return oracle.server_url if oracle != null else MindOracle.SERVER_URL


## Porta lida do `server_url` do oraculo, nunca repetida como literal (dossie 15
## §9). A classe `URL` nao existe no motor pinado — conferido por
## `ClassDB.class_exists("URL")` em headless nesta arvore — entao o recorte e
## feito a mao, sem tocar no dono do valor.
func _port() -> int:
	var u := _url()
	var scheme := u.find("://")
	if scheme >= 0:
		u = u.substr(scheme + 3)
	var slash := u.find("/")
	if slash >= 0:
		u = u.substr(0, slash)
	var colon := u.rfind(":")
	return int(u.substr(colon + 1)) if colon >= 0 else 80


func _headers() -> PackedStringArray:
	return ["Authorization: Bearer " + MindOracle.resolve_api_key()]


## Sonda de boot: `GET /v1/models`, nao `/health`. O `/health` e publico no
## b12499 (tools/server/README.md:487), entao um servidor estranho responde 200
## nele e a distincao "nosso x de terceiro" se perde; com a chave a resposta passa
## a carregar a impressao digital (dossie 15 §4.2).
func _probe() -> void:
	var path := "/v1/models" if state == PROBING else "/health"
	requests_issued += 1
	_busy = true
	var err := _http.request(_url() + path, _headers(), HTTPClient.METHOD_GET)
	if err != OK:
		_busy = false
		_fail("abrir sonda: %s" % error_string(err))


func _past_deadline() -> bool:
	return boot_ms < 0.0 and processes_spawned > 0 \
			and Time.get_ticks_msec() - _spawn_ms > int(boot_deadline * 1000.0)


func _on_probe_response(result: int, code: int, _hdrs: PackedStringArray,
		body: PackedByteArray) -> void:
	_busy = false
	if state == PROBING:
		_read_sonda(result, code, body)
	elif state == LOADING:
		_read_health(result, code)


func _read_sonda(result: int, code: int, body: PackedByteArray) -> void:
	if result != OK or code == 0:
		# Ninguem na porta: e o nosso espaco, e o unico caminho que cria processo.
		_spawn("sem servidor na porta %d" % _port())
		return
	if code == 401:
		# Outro `llama-server` (ou o nosso com outra chave): nao matar, nao reusar,
		# nao adivinhar porta. Rodar sem oraculo e dizer por que.
		_set_state(FOREIGN, "%d na porta %d" % [code, _port()])
		return
	if code == 200 and _has_alias(body):
		# Sobrou um servidor nosso (crash anterior ou a segunda janela): reusar sim,
		# matar nunca — por isso o pid continua -1.
		pid = -1
		_owns_child = false
		boot_ms = 0.0
		_set_state(REUSED, "200 com o alias %s na porta %d" % [ALIAS, _port()])
		server_ready.emit()
		return
	# 200 sem o nosso alias e um servidor que nao e o nosso (ou um nao-llama).
	_set_state(FOREIGN, "%d sem o alias %s na porta %d" % [code, ALIAS, _port()])


func _read_health(result: int, code: int) -> void:
	if result != OK:
		# Porta fechada de novo durante o boot: ou o processo morreu, ou o prazo
		# cuida disso. `is_process_running` e o unico teste que o motor oferece.
		if pid > 0 and not OS.is_process_running(pid):
			_on_death("sem servidor na porta e processo morto")
		return
	if code == 200:
		if boot_ms < 0.0:
			boot_ms = float(Time.get_ticks_msec() - _spawn_ms)
		_set_state(READY, "boot %.0f ms  503=%d  pid %d" % [boot_ms, loading_503, pid])
		server_ready.emit()
		return
	if code == 503:
		# "Loading model" nao e falha: e "espera mais um pouco", que e justamente o
		# que o recuo de 30 s do oraculo transformava em silencio (dossie 15 §2).
		loading_503 += 1
		_cd = PROBE_PERIOD
		return
	_fail("health devolveu %d" % code)


func _has_alias(body: PackedByteArray) -> bool:
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary):
		return false
	for m in (data as Dictionary).get("data", []):
		if m is Dictionary and String((m as Dictionary).get("id", "")) == ALIAS:
			return true
	return false


# ------------------------------------------------------------------ filho

func _spawn(reason: String) -> void:
	processes_spawned += 1
	# A assinatura do motor pinado e `create_process(path, arguments, open_console)`
	# — conferida em `OS.get_method_list()` nesta arvore, nao de memoria.
	var argv := PackedStringArray([
		"-m", _resolved_model(),
		"--host", "127.0.0.1", "--port", str(_port()),
		"-c", str(ctx_size), "-ngl", str(gpu_layers),
		"--alias", ALIAS, "--reasoning", "off",
		# O imprint que separa "nosso" de "estrangeiro" (dossie 15 §4.2) nao e
		# seguranca, e por isso ele tambem nao vai para o log que vira evidencia.
		"--api-key", MindOracle.resolve_api_key(),
	])
	print("llm_host  create_process  %s %s  (%s)" % [_resolved_server(), _redacted(argv), reason])
	pid = OS.create_process(_resolved_server(), argv, false)
	if pid <= 0:
		# `create_process` devolve -1 quando o SO recusa: sem pid nao ha o que
		# vigiar nem o que matar, e o jogo segue sem oraculo.
		pid = -1
		_fail("create_process recusou (pid %d)" % pid)
		return
	_owns_child = true
	_spawn_ms = Time.get_ticks_msec()
	boot_ms = -1.0
	_cd = PROBE_PERIOD
	_set_state(LOADING, "pid %d  boot do modelo iniciado  (%d/1 spawn)" % [
		pid, processes_spawned])


func _on_death(reason: String) -> void:
	_last_exit_code = OS.get_process_exit_code(pid) if pid > 0 else -1
	if retries >= RETRY_LIMIT:
		# Segunda morte = fim de tentativa, sem novo retry: o §0.1 disse que nada no
		# servidor se autocorrige, entao insistir so esconde o custo.
		_set_state(OFF, "%s  (codigo %d)  sem mais retentativas" % [reason, _last_exit_code])
		return
	retries += 1
	# O estado `caiu` e impresso antes do respawn porque a matriz de falha do
	# dossie 15 §5 cobra a frase no F3 e no log: sem este registro, um respawn do
	# tamanho de um boot apagaria a morte do historico da sessao.
	_set_state(DIED, "%s  (codigo %d)  retentativa %d/%d" % [
		reason, _last_exit_code, retries, RETRY_LIMIT])
	_spawn("retentativa %d/%d apos %s" % [retries, RETRY_LIMIT, reason])


## Toda transicao imprime o estado e o numero que o produziu: a matriz de falha do
## dossie 15 §5 exige o estado no log, e o log da cena de prova e a evidencia.
func _set_state(next_state: String, next_detail: String) -> void:
	state = next_state
	detail = next_detail
	print("llm_host  %s  %s" % [state, detail])
	state_changed.emit(state, detail)


## Estado terminal de tentativa: sem prazo estourado, sem recusa do SO e sem
## segunda retentativa, o caminho e o mesmo — sair da cena e o oraculo seguir sem
## narrador, que e o degradado ja checado pela suite.
func _fail(reason: String) -> void:
	_set_state(OFF, reason)


# ------------------------------------------------------------------ caminhos

func _resolved_server() -> String:
	return _resolve(server_path, _project_root() + "/.tools/llama/runtime/llama-server.exe",
			"AETHERFALL_LLM_SERVER", "--llm-server=")


func _resolved_model() -> String:
	return _resolve(model_path, _project_root() + "/models/qwen3.5-4b-q4_k_m.gguf",
			"AETHERFALL_LLM_MODEL", "--llm-model=")


## Tres camadas, na ordem: export do nodo < variavel de ambiente < CLI apos `--`.
## A CLI vence porque e o que o runner do gate passa, e o override existe porque
## o runtime nao esta no git: sem ele a medição real so aconteceria no checkout
## principal.
func _resolve(exported: String, fallback: String, env_name: String, flag: String) -> String:
	var chosen := exported
	var from_env := OS.get_environment(env_name)
	if not from_env.is_empty():
		chosen = from_env
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(flag):
			chosen = arg.trim_prefix(flag)
	return chosen if not chosen.is_empty() else fallback


func _project_root() -> String:
	return ProjectSettings.globalize_path("res://").replace("\\", "/").rstrip("/")


# ------------------------------------------------------------------ cebo

## Os tres pontos de saida do dossie 15 §4.3: sair da cena (o `_exit_tree` que ja
## fecha o journal em `main.gd`), fecho da janela e `queue_free` sem saida da
## arvore, que cai no NOTIFICATION_PREDELETE.
func _exit_tree() -> void:
	_stop_child()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_stop_child()


## Mata o que ele subiu, e so isso. O preco deste desenho esta registrado no
## dossie 15 §5: se a janela dona do processo fechar primeiro, a outra que reusou
## perde o oraculo no meio da partida.
func _stop_child() -> void:
	if not _owns_child or pid <= 0:
		return
	if keep_child_on_exit:
		print("llm_host  filho preservado por --keep  pid %d" % pid)
		return
	if OS.is_process_running(pid):
		kills_issued += 1
		var err := OS.kill(pid)
		print("llm_host  encerrando pid %d  %s" % [pid, error_string(err)])
	pid = -1
	_owns_child = false


## A linha de `create_process` e a assinatura da corrida, e ela nao pode carregar
## a chave: log de headless vira `docs/evidence/` e evidencia vira repo publico.
## O resto do comando continua literal — so o valor da chave sai mascarado.
func _redacted(argv: PackedStringArray) -> String:
	var out := PackedStringArray()
	var mask := false
	for a in argv:
		if mask:
			out.append("<chave>")
			mask = false
			continue
		out.append(a)
		mask = a == "--api-key"
	return " ".join(out)
