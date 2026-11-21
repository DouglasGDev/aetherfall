class_name MindOracle
extends Node
## Oraculo de IA local: um llama-server (llama.cpp, MIT) rodando em localhost
## narra em uma frase o estado interno de um mob. Contrato do docs/design/04
## (camada 5): opcional por design e nunca decide — sem servidor, o pedido
## falha, entra em recuo e a narrativa fica vazia; a utilidade e a arvore
## seguem decidindo sozinhas. O oraculo da superficie a decisoes ja tomadas.

signal narration_ready(wolf_id: int, text: String)

const SERVER_URL := "http://127.0.0.1:8741"
const REQUEST_TIMEOUT: float = 8.0
const RETRY_COOLDOWN: float = 30.0
## Chave do servidor local: o imprint que separa "o nosso servidor sobrou de um
## crash" de "um llama-server de terceiro na porta" (dossie 15 §4.2), e nao
## seguranca — o trafego continua 127.0.0.1. Ela nao mora no repositorio: vale o
## ambiente `KEY_ENV`, depois o arquivo `KEY_FILE`, e sem os dois a primeira
## execucao sorteia 32 hex e grava la. O lancador le as mesmas duas fontes.
const KEY_ENV := "AETHERFALL_MIND_KEY"
const KEY_FILE := "user://mind_key.txt"
## Nome publicado pelo servidor (`--alias` no lancador e no `LlmServerHost`). Um
## dono so para a string: pedido e servidor tem de dizer o mesmo nome, e o
## `404 model not found` do b12499 nao aparece no F3 de outra forma.
const MODEL_ALIAS := "mind-small"
## 503 e "Loading model", nao falha: 30 s de recuo sobre um modelo que ainda esta
## carregando engoliria a primeira narrativa da sessao inteira (dossie 15 §2). O
## tempo real desta maquina e o numero da perna 15, nao um estimativo aqui.
const LOADING_COOLDOWN: float = 2.0

## Enderecos e prazos sao const para o jogo; a suite comprime os dois para
## exercer a degradacao (porta fechada -> timeout -> recuo) sem esperar 8 s.
var server_url: String = SERVER_URL
var request_timeout: float = REQUEST_TIMEOUT
var api_key: String = resolve_api_key()

## Portao de prontidao (dossie 15 §4.4): quando existe um hospedeiro de processo,
## ele diz quando o modelo esta no ar. Sem portao — o caso da suite e o de quem
## sobe o servidor na mao — o ciclo de requisicao segue como sempre.
var ready_provider: Callable = Callable()
var roster_provider: Callable = Callable()

var _http: HTTPRequest = null
var _busy := false
var _cursor := 0
var _server_cd := 0.0
var _pending_id := -1
var _narrations := {}
var _cooldowns := {}
## Nomes da enum `HTTPRequest.Result`, lidos uma vez do registro da classe: a
## traducao do `result` nao vem de tabela escrita a mao, vem do proprio engine.
var _result_names: PackedStringArray = PackedStringArray()

## Numeros do caminho, para a checagem nomear a premissa em vez de adjetivar:
## quantas requisicoes sairam, e qual foi o ultimo codigo ou erro que produziu
## resposta vazia. Um 401 silencioso e o mandato 1 ao contrario.
var requests_issued := 0
var last_status := -1
var last_reason := ""


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "Http"
	_http.timeout = request_timeout
	add_child(_http)
	_http.request_completed.connect(_on_response)
	for n in ClassDB.class_get_enum_constants("HTTPRequest", "Result"):
		_result_names.append(String(n))


func _process(delta: float) -> void:
	_server_cd = maxf(_server_cd - delta, 0.0)
	for k in _cooldowns.keys():
		_cooldowns[k] = maxf(float(_cooldowns[k]) - delta, 0.0)
	if _busy or _server_cd > 0.0 or not roster_provider.is_valid():
		return
	# O portao vem antes de qualquer pedido: com o hospedeiro levantando o modelo
	# junto do jogo, a primeira requisicao cairia num 503 e o recuo de 30 s
	# engoliria a meia-minuta seguinte (dossie 15 §2 e §4.4).
	if ready_provider.is_valid() and not bool(ready_provider.call()):
		return
	var roster: Array = roster_provider.call()
	if roster.is_empty():
		return
	for i in roster.size():
		var w = roster[(_cursor + i) % roster.size()]
		if w != null and is_instance_valid(w) and w.alive \
				and float(_cooldowns.get(w.identity, 0.0)) <= 0.0:
			_cursor = (_cursor + i + 1) % roster.size()
			_request(w)
			return


## O servidor narra o que a utilidade ja decidiu — a narrativa e leitura do
## estado interno, nao entrada do sistema de decisao.
func narration_of(wolf_id: int) -> String:
	return String(_narrations.get(wolf_id, ""))


## Cabecalhos do pedido. Um dono para a chave: quem levanta o servidor e quem o
## procura leem a mesma constante, e a checagem da suite confere o launcher.
func auth_headers() -> PackedStringArray:
	return ["Content-Type: application/json", "Authorization: Bearer " + api_key]


func _request(w) -> void:
	_busy = true
	requests_issued += 1
	_pending_id = int(w.identity)
	var sys := "Voce narra o interior de um lobo de um jogo para uma linha de " \
			+ "debug. Responda com UMA frase curta em portugues, sem nomes de " \
			+ "sistemas, sem listas, sem pense em voz alta."
	var payload := {
		"model": MODEL_ALIAS,
		"messages": [
			{"role": "system", "content": sys},
			{"role": "user", "content": _prompt_for(w)},
		],
		"max_tokens": 64,
		"temperature": 0.7,
	}
	var err := _http.request(server_url + "/v1/chat/completions",
			auth_headers(), HTTPClient.METHOD_POST,
			JSON.stringify(payload))
	if err != OK:
		_busy = false
		last_reason = "abrir pedido: %s" % error_string(err)
		_server_cd = RETRY_COOLDOWN


func _prompt_for(w) -> String:
	var d: Dictionary = w.mind.to_dict()
	var eps: Array = d.get("episodic", [])
	var recent: Array = []
	for i in range(maxi(eps.size() - 3, 0), eps.size()):
		recent.append("%s (forca %.2f)" % [eps[i]["kind"], float(eps[i]["mag"])])
	var bl := ""
	for id in d.get("beliefs", {}):
		bl += "%s=%.2f " % [id, float(d["beliefs"][id])]
	return (
		"lobo %d; intencao atual: %s; vida %.0f%%; fome %.0f%%; "
		+ "confianca no jogador %.2f; memorias recentes: %s; crencas: %s. "
		+ "O que passa na cabeca dele agora?"
	) % [
		w.identity, w.intent, w.hp / w.MAX_HP * 100.0,
		w.hunger * 100.0, float(w.mind.trust(0)),
		", ".join(recent), bl.strip_edges(),
	]


func _on_response(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray) -> void:
	_busy = false
	last_status = code
	var text := ""
	if code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data is Dictionary:
			var choices: Array = data.get("choices", [])
			if not choices.is_empty() and choices[0] is Dictionary:
				text = _clean(String(choices[0].get("message", {}).get("content", "")))
	if text.is_empty():
		# Sem narrativa o recuo muda de tamanho conforme a assinatura do erro, e
		# cada ramo nomeia o codigo que o produziu: 503 e "carregando" (espera
		# curta), conexao recusada e o caminho degradado ja checado pela suite
		# (recuo cheio), e 401/400/`resposta inutil` tambem recuo cheio — so que
		# impresso, nao anonimizado (dossie 15 §9).
		if code == 503:
			last_reason = "503 carregando o modelo"
			_server_cd = LOADING_COOLDOWN
			return
		last_reason = "sem resposta (%s)" % _reason_of(result, code)
		_server_cd = RETRY_COOLDOWN
		return
	last_reason = ""
	_narrations[_pending_id] = text
	_cooldowns[_pending_id] = RETRY_COOLDOWN
	narration_ready.emit(_pending_id, text)


## Nomeia o numero em vez de devolver a enum crua: `result` e o codigo de
## `HTTPRequest.Result` (nao o `Error` do motor), entao o nome vem do registro da
## classe. Nao e `get_result_string`: medido em headless nesta arvore,
## `ClassDB.class_has_method("HTTPRequest", "get_result_string")` devolve false e
## a chamada derrubava este ramo no meio — sem `last_reason` e sem o recuo de 30 s,
## que e o mandato 1 ao contrario. Um 401 ou um timeout anonimizados num recuo
## silencioso tambem seriam.
func _reason_of(result: int, code: int) -> String:
	if result == HTTPRequest.RESULT_SUCCESS:
		return "codigo http %d" % code
	var nome := "result %d" % result
	if result >= 0 and result < _result_names.size():
		nome = _result_names[result]
	return "%s (codigo http %d)" % [nome, code]


## Modelos de raciocinio podem cuspir <think> antes da resposta; a narrativa
## e uma frase, nunca o rascunho.
static func _clean(raw: String) -> String:
	var s := raw
	var open := s.find("<think>")
	while open >= 0:
		var close := s.find("</think>", open)
		if close < 0:
			s = s.substr(0, open)
			break
		s = s.substr(0, open) + s.substr(close + 8)
		open = s.find("<think>")
	s = s.replace("\n", " ").strip_edges()
	if s.length() > 140:
		s = s.substr(0, 140).strip_edges() + "..."
	return s


## Chave do servidor local, resolvida uma vez por processo. Ordem: ambiente
## `KEY_ENV`, arquivo `KEY_FILE`, e na falta dos dois 32 hex sorteados e gravados
## — quem roda o lancador por fora le as mesmas duas fontes, entao a divergencia
## que a suite confere e de fonte, nao de string.
static func resolve_api_key() -> String:
	if _key != "":
		return _key
	var from_env := OS.get_environment(KEY_ENV)
	if from_env != "":
		_key = from_env
		key_source = "ambiente"
		return _key
	var stored := _read_key_file()
	if stored != "":
		_key = stored
		key_source = "arquivo"
		return _key
	_key = Crypto.new().generate_random_bytes(16).hex_encode()
	if _key == "":
		# Sem entropia nao ha imprint, e imprint vazio e o mesmo que nenhum: o
		# host passa a tratar o servidor da porta como estrangeiro.
		key_source = "sem-entropia"
		return _key
	# Gravar falha e estado nomeado, nao chave silenciosa: sem arquivo o lancador
	# de fora nao tem como bater a mesma chave, e o `401` que vem depois e dele.
	key_source = "sorteada" if _write_key_file(_key) else "sorteada-sem-gravar"
	return _key


static func _read_key_file() -> String:
	if not FileAccess.file_exists(KEY_FILE):
		return ""
	var f := FileAccess.open(KEY_FILE, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text().strip_edges()


static func _write_key_file(key: String) -> bool:
	var f := FileAccess.open(KEY_FILE, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(key + "\n")
	f.close()
	return FileAccess.file_exists(KEY_FILE)


static var _key: String = ""
## De onde a chave veio — `ambiente`, `arquivo`, `sorteada`, `sorteada-sem-gravar`.
static var key_source: String = ""
