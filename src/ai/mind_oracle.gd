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

## Enderecos e prazos sao const para o jogo; a suite comprime os dois para
## exercer a degradacao (porta fechada -> timeout -> recuo) sem esperar 8 s.
var server_url: String = SERVER_URL
var request_timeout: float = REQUEST_TIMEOUT

var roster_provider: Callable = Callable()

var _http: HTTPRequest = null
var _busy := false
var _cursor := 0
var _server_cd := 0.0
var _pending_id := -1
var _narrations := {}
var _cooldowns := {}


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "Http"
	_http.timeout = request_timeout
	add_child(_http)
	_http.request_completed.connect(_on_response)


func _process(delta: float) -> void:
	_server_cd = maxf(_server_cd - delta, 0.0)
	for k in _cooldowns.keys():
		_cooldowns[k] = maxf(float(_cooldowns[k]) - delta, 0.0)
	if _busy or _server_cd > 0.0 or not roster_provider.is_valid():
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


func _request(w) -> void:
	_busy = true
	_pending_id = int(w.identity)
	var sys := "Voce narra o interior de um lobo de um jogo para uma linha de " \
			+ "debug. Responda com UMA frase curta em portugues, sem nomes de " \
			+ "sistemas, sem listas, sem pense em voz alta."
	var payload := {
		"model": "mind-small",
		"messages": [
			{"role": "system", "content": sys},
			{"role": "user", "content": _prompt_for(w)},
		],
		"max_tokens": 64,
		"temperature": 0.7,
	}
	var err := _http.request(server_url + "/v1/chat/completions",
			["Content-Type: application/json"], HTTPClient.METHOD_POST,
			JSON.stringify(payload))
	if err != OK:
		_busy = false
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


func _on_response(_result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray) -> void:
	_busy = false
	var text := ""
	if code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data is Dictionary:
			var choices: Array = data.get("choices", [])
			if not choices.is_empty() and choices[0] is Dictionary:
				text = _clean(String(choices[0].get("message", {}).get("content", "")))
	if text.is_empty():
		# servidor ausente, modelo ausente ou resposta inutil: recuo global
		_server_cd = RETRY_COOLDOWN
		return
	_narrations[_pending_id] = text
	_cooldowns[_pending_id] = RETRY_COOLDOWN
	narration_ready.emit(_pending_id, text)


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
