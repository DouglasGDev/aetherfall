class_name MindOracle
extends Node
## Oraculo de IA local: a AfMindOracle (llama.cpp compilado na extensao
## GDExtension) narra em uma frase o estado interno de um mob. Contrato do
## docs/design/04 (camada 5): opcional por design e nunca decide — sem pack no
## processo, o pedido e recusado pela fila, entra em recuo e a narrativa fica
## vazia; a utilidade e a arvore seguem decidindo sozinhas. O oraculo da
## superficie a decisoes ja tomadas.
##
## Passo 4 do dossie 22 (§5.4): o transporte HTTP sai daqui. O que fica e o que
## o §2.1 lista de nao-transporte — agendamento por frame, round-robin, recuo,
## chave do servidor externo, prompt, `narration_of` e o `narration_ready` — e o
## nodo de requisicao HTTP vira a ponte nativa (`AfMindOracle.enqueue`/`wait`).
## O decode roda em thread do proprio processo; este wrapper polla `wait(id, 0)`
## por frame — timeout zero e consulta nao bloqueante, status 1 preserva o slot
## (contrato do mind_prompt.h) — e nenhum `await` pendura os 50 ms do tick.
##
## Passo 5 do dossie 22 (§6.5): a cache do oraculo, opt-in via CLI
## `--oracle-cache=` (padrao da casa do `--tick-journal=`), e lida ANTES de
## inferir — com o prompt do lobo ja gravado no arquivo separado do save, a
## frase volta sem tocar a fila, e o replay de CI roda com o modelo ate fora do
## processo. Sem a flag `_cache` e null e o custo por frame e zero.
##
## Passo 5 do dossie 22 (§6.4/§7.1): o PORTAO da Camada 5. "A mente propoe, as
## regras dispoe" deixa de ser ausencia de caminho — com o modelo no MESMO heap
## esse argumento e fraco — e vira o verificador nomeado (`BeliefVerifier`) na
## unica rota de escrita: a saida que cita um id que nao existe na alcateia nao
## produz narrativa, crenca nem intencao, e a recusa nomeia o id forjado.

signal narration_ready(wolf_id: int, text: String)

## Recuo cheio: conexao caida, fila recusada por motivo que nao se resolve no
## proximo segundo. O recuo CURTO do 503 "carregando" morreu com o transporte:
## a espera pelo modelo agora e o portao fechado do `AfMindRuntime` (§6.3), que
## segura o pedido antes de o pack chegar ao estado de fila (4).
const RETRY_COOLDOWN: float = 30.0
## Chave do servidor externo, mantida pelo §2.1 (nao e transporte): quem sobe um
## llama-server na mao (tools/run_mind_server.ps1, perna 15) le as MESMAS duas
## fontes que `resolve_api_key` — o ambiente `KEY_ENV` e o arquivo `KEY_FILE` —
## e a suite confere a derivacao entre as linguagens. Ela nao mora no repositorio:
## vale o ambiente, depois o arquivo, e sem os dois a primeira execucao sorteia
## 32 hex e grava la.
const KEY_ENV := "AETHERFALL_MIND_KEY"
const KEY_FILE := "user://mind_key.txt"
## Nome do pack publicado na ponte (`load_pack`) e do alias que o llama-server
## de uma sonda publica (`--alias`): um dono so para a string, pedido e servidor
## tem de dizer o mesmo nome.
const MODEL_ALIAS := "mind-small"
## Params de geracao do prompt narrativo: entram no pedido e na chave da cache
## (§6.5 — prompt ⊕ pack ⊕ params), entao sao constantes nomeadas, nao literais
## soltos repetidos em dois lugares.
const PROMPT_MAX_TOKENS := 64
const PROMPT_TEMPERATURE := 0.7
## O k da janela de crencas do prompt (Fase 2 §20.5): o prompt imprime o top-k
## por qualidade, nao o dicionario inteiro. O runner carrega uma copia literal
## (`K_JANELA_PROVA`) porque ler-la no vermelho seria SCRIPT ERROR — padrao
## BIAS_MEDIDA.
const JANELA_CRENCAS: int = 8

## Portao de prontidao (dossie 15 §4.4): quando existe um dono de pack, ele diz
## quando o modelo esta no estado de fila. Sem portao — o caso da suite e o de
## quem sobe o servidor na mao — o ciclo de pedido segue como sempre.
var ready_provider: Callable = Callable()
var roster_provider: Callable = Callable()
## O LEDGER da Fase 2 (§20.6): a verdade de mundo que o portao da Camada 5 le —
## `entity_id -> vivo (bool)`, com o jogador (ACTOR_PLAYER) incluido. Sem o
## provider o portao degrada ao comportamento do Passo 5 (ids contra o roster),
## e a degradacao fica nomeada em `ultimo_portao` — nunca silenciosa.
var ledger_provider: Callable = Callable()
## O portao ativo na ultima chamada de `aceitar_saida`: "ledger" com o provider
## valido, "roster" na degradacao do Passo 5. Observabilidade do gate — quem le
## o log sabe contra QUE verdade a saida foi conferida.
var ultimo_portao := ""

## A ponte nativa, criada no `_ready` quando a ClassDB tem a classe. Num clone
## sem o dll (gitignored) ela fica null e cada pedido nomeia a ausencia — o
## degradado e checado pela suite com o motivo impresso.
var _ext: Object = null
var _busy := false
var _cursor := 0
var _server_cd := 0.0
## Identidade do lobo do pedido em voo e o id que a fila devolveu: sao numeros
## diferentes — o dicionario de narrativas e indexado pelo lobo, o `wait` pelo id.
var _pending_id := -1
var _ext_id := -1
var _narrations := {}
var _cooldowns := {}
## Cache do oraculo (§6.5), opt-in via CLI `--oracle-cache=`: null = desligada e
## o caminho do decode segue byte a byte o que era. O arquivo e SEPARADO do save
## — cache nao e memoria, e determinismo de CI, nunca um segundo ledger.
var _cache: OracleCache = null
## Acertos de cache nesta sessao — o numero que o gate do replay imprime: com a
## resposta gravada, a segunda semente NAO emite pedido (`requests_issued` fica).
var cache_hits := 0
## Prompt do pedido em voo: e a chave de conteudo quando a resposta chega — a
## frase se grava sob a chave do prompt que PRODUZIU o texto, nunca de outro.
var _ultimo_prompt := ""
## O verificador nomeado da fronteira da Camada 5 (§6.4): criado no `_ready`, e
## ele que decide se uma saida do oraculo pode entrar no mundo.
var _verificador: BeliefVerifier = null

## Numeros do caminho, para a checagem nomear a premissa em vez de adjetivar:
## quantos pedidos sairam para a fila, qual foi o ultimo status do `wait`
## (0 pronto, 1 timeout, <0 recusa) e qual motivo produziu resposta vazia.
var requests_issued := 0
var last_status := -1
var last_reason := ""


func _ready() -> void:
	if ClassDB.class_exists(&"AfMindOracle"):
		_ext = ClassDB.instantiate(&"AfMindOracle")
	_verificador = BeliefVerifier.new()


## A ponte nativa que este oraculo usa. O AfMindRuntime (dossie 22 §6.3) dirige
## nela o ciclo de vida do pack — set_runtime_dir, load_pack, ctx_probe — e le
## as metricas: UM objeto so por processo, UM pack so, a VRAM do modelo uma vez.
func ext() -> Object:
	return _ext


func _process(delta: float) -> void:
	_server_cd = maxf(_server_cd - delta, 0.0)
	for k in _cooldowns.keys():
		_cooldowns[k] = maxf(float(_cooldowns[k]) - delta, 0.0)
	if _busy:
		_poll()
		return
	# A cache (§6.5) e lida ANTES de inferir e antes dos portoes: com o prompt ja
	# gravado, a frase volta do arquivo sem tocar a fila — o modelo pode nem
	# estar no processo (replay de CI com "modelo desligado"). Guarda por
	# `_cache != null`, entao sem a flag de CLI este bloco nao existe em custo.
	if _cache != null and roster_provider.is_valid():
		var roster_c: Array = roster_provider.call()
		for i in roster_c.size():
			var wc = roster_c[(_cursor + i) % roster_c.size()]
			if wc != null and is_instance_valid(wc) and wc.alive \
					and float(_cooldowns.get(wc.identity, 0.0)) <= 0.0 \
					and _cache_hit(wc):
				_cursor = (_cursor + i + 1) % roster_c.size()
				return
	if _server_cd > 0.0 or not roster_provider.is_valid():
		return
	# O portao vem antes de qualquer pedido: com o dono do pack carregando o
	# modelo no boot do processo, um pedido cairia na recusa "sem contexto" e o
	# recuo de 30 s engoliria a meia-minuta seguinte (dossie 15 §2 e §4.4).
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


## O PORTAO da Camada 5 (§6.4/§7.1, expandido na Fase 2 §20.6): a UNICA rota
## pela qual uma saida do oraculo entra no mundo — narrativa gravada, crenca,
## intencao. Com o ledger ligado, a conferencia e contra a verdade de mundo
## (ids alem do roster — o jogador entre eles — e FATO declarado contra o
## ledger); sem ledger, degrada ao roster do Passo 5, nomeado em
## `ultimo_portao`. Recusa = sem narrativa, sem crenca, sem intencao, com o id
## e o motivo NOMEADOS; fato confirmado (morte de cadaver) entra no Mind do
## narrador como QUARENTENA — nunca como intencao escrita no corpo (mandato 2).
func aceitar_saida(wolf_id: int, texto: String) -> bool:
	var fatos: Array = []
	var aceito := false
	if ledger_provider.is_valid():
		ultimo_portao = "ledger"
		aceito = _verificador.aceitar_ledger(texto, ledger_provider.call())
		if aceito:
			fatos = _verificador.fatos_confirmados.duplicate()
	else:
		ultimo_portao = "roster"
		var ids: Array = []
		if roster_provider.is_valid():
			for w in roster_provider.call():
				if w != null and is_instance_valid(w):
					ids.append(int(w.identity))
		aceito = _verificador.aceitar(texto, ids)
	if not aceito:
		last_reason = _verificador.ultimo_motivo
		_cooldowns[wolf_id] = RETRY_COOLDOWN
		return false
	_narrations[wolf_id] = texto
	_cooldowns[wolf_id] = RETRY_COOLDOWN
	_quarentena(wolf_id, fatos)
	narration_ready.emit(wolf_id, texto)
	return true


## Escreve a quarentena dos fatos que o LEDGER confirmou no Mind do narrador
## (Fase 2 §20.6): a morte declarada e validada contra o ledger vira crenca
## rebaixada com a fonte "oracle" — o oraculo sugere, a arvore dispoe. Le o
## `mind` por `w.get("mind")` de proposito: o roster pode conter corpo de prova
## sem mente (o `_LoboProva` do Passo 5) e `get` devolve null onde o acesso
## direto derrubaria o gate — lobo sem mente nao escreve nada, e o narrador
## sem lobo no roster tambem nao (a quarentena e do NARRADOR do fato).
func _quarentena(wolf_id: int, fatos: Array) -> void:
	if fatos.is_empty() or not roster_provider.is_valid():
		return
	for w in roster_provider.call():
		if w != null and is_instance_valid(w) and int(w.identity) == wolf_id:
			var m = w.get("mind")
			if m != null and m.has_method("quarentena"):
				for id in fatos:
					m.quarentena("oracle_caiu_%d" % int(id))
			return


## Liga a cache (§6.5) no arquivo dado — CLI `--oracle-cache=`, padrao da casa
## do `--tick-journal=`. Sem chamada `_cache` permanece null e o custo por frame
## e zero: cache e opt-in, o jogo normal narra com decode a cada recuo.
func set_cache_path(caminho: String) -> bool:
	_cache = OracleCache.new(caminho)
	return _cache != null


## Leitura ANTES de inferir: se o prompt do lobo ja tem resposta gravada, a
## frase volta do arquivo sem tocar a fila. Arma o MESMO recuo por lobo do
## decode (a frase servida e resposta completa — nao reemite todo frame) e
## conta o acerto, que e o numero que o gate do replay imprime.
func _cache_hit(w) -> bool:
	var key := OracleCache.chave(_prompt_narracao(w), MODEL_ALIAS,
			PROMPT_MAX_TOKENS, PROMPT_TEMPERATURE)
	if not _cache.tem(key):
		return false
	var text := _cache.le(key)
	_narrations[int(w.identity)] = text
	_cooldowns[int(w.identity)] = RETRY_COOLDOWN
	cache_hits += 1
	narration_ready.emit(int(w.identity), text)
	return true


## Gravacao apos o wrapper ACEITAR a saida (status 0, texto nao vazio): o que a
## cache devolve tem de ser o que o wrapper aceitou — narrativa recusada nunca
## se torna cache. Falha de gravacao nao derruba o decode: nomeia o motivo em
## `ultimo_erro` da cache e segue.
func _cache_grava(prompt: String, text: String) -> void:
	if _cache == null:
		return
	_cache.grava(OracleCache.chave(prompt, MODEL_ALIAS,
			PROMPT_MAX_TOKENS, PROMPT_TEMPERATURE), text)


## Enfileira o pedido na ponte e devolve a palavra ao frame. A fila pode recusar
## (-1 sem contexto, -2 campo, -3 fila cheia, -4 papel): cada recusa imprime o
## motivo NOMEADO que a propria ponte escreveu, nunca um numero solto.
func _request(w) -> void:
	if _ext == null:
		last_reason = "extensao ausente: AfMindOracle nao esta na ClassDB nesta arvore"
		_server_cd = RETRY_COOLDOWN
		return
	_busy = true
	requests_issued += 1
	_pending_id = int(w.identity)
	_ultimo_prompt = _prompt_narracao(w)
	var id := int(_ext.enqueue({
		"role": "user",
		"prompt": _ultimo_prompt,
		"max_tokens": PROMPT_MAX_TOKENS,
		"temperature": PROMPT_TEMPERATURE,
	}))
	if id < 0:
		_busy = false
		last_reason = "fila recusou o pedido: %s" % String(_ext.prompt_err_text())
		_server_cd = RETRY_COOLDOWN
		return
	_ext_id = id


## Poll nao bloqueante do pedido em voo: `wait(id, 0)` devolve status 1 enquanto
## o decode corre (slot preservado, proximo frame pergunta de novo), 0 quando o
## texto chegou (e CONSOME o slot), <0 quando o slot nao existe mais.
func _poll() -> void:
	var out: Dictionary = _ext.wait(_ext_id, 0)
	var status := int(out.get("status", -99))
	if status == 1:
		return
	_busy = false
	last_status = status
	var text := _clean(String(out.get("text", "")))
	if status == 0 and text != "":
		last_reason = ""
		# O portao da Camada 5 decide ANTES de qualquer escrita (§6.4): narrativa,
		# cache e sinal so existem com a saida aceita — a saida que nomeia um id
		# que nao existe na alcateia nao produz nada, e a recusa nomeia o id
		# forjado. Recusada tambem nao vira cache: o que a cache devolve e o que
		# o wrapper ACEITOU.
		if not aceitar_saida(_pending_id, text):
			return
		_cache_grava(_ultimo_prompt, text)
		return
	# Decode concluido sem texto ou slot perdido: recuo cheio com o motivo que a
	# ponte escreveu — impresso, nao anonimizado (dossie 15 §9).
	last_reason = "fila recusou o pedido: %s" % String(out.get("reason", ""))
	_server_cd = RETRY_COOLDOWN


## O prompt narrativo e o system + o estado interno, DOBRADOS numa mensagem so:
## o formato de chat da ponte e de mensagem UNICA (qwen), entao nao existe
## papel "system" para escrever — a instrucao de uma linha entra no mesmo texto.
static func _prompt_narracao(w) -> String:
	return "Voce narra o interior de um lobo de um jogo para uma linha de " \
			+ "debug. Responda com UMA frase curta em portugues, sem nomes de " \
			+ "sistemas, sem listas, sem pense em voz alta. " + _prompt_for(w)


## A janela de crencas: PURA no estado da mente — a premissa
## `selecao_de_beliefs_e_pura_no_estado` (§20.5) como codigo. Ordena por
## confianca desc, depois `vezes` desc, depois `visto_em` desc, e fecha com o
## desempate TOTAL pela chave: o dicionario do Godot e ordenado pela insercao,
## e sem o desempate final o mesmo estado em duas ordens de insercao
## devolveria duas janelas. Nao le relogio, aleatoriedade nem identidade de
## fora — mesmo estado -> mesma janela -> mesmo prompt -> mesma chave de
## conteudo da cache (§6.5), senao a cache fixa memoria velha no replay.
## Devolve os ids na ordem em que o prompt os imprime.
static func _janela_crencas(beliefs: Dictionary) -> Array:
	var itens: Array = []
	for id in beliefs:
		var b = beliefs[id]
		itens.append({
			"id": id,
			"conf": float(b.get("confidence", 0.0)),
			"vezes": int(b.get("vezes", 0)),
			"visto": int(b.get("visto_em", -1)),
		})
	itens.sort_custom(func(a: Dictionary, c: Dictionary) -> bool:
		if float(a["conf"]) != float(c["conf"]):
			return float(a["conf"]) > float(c["conf"])
		if int(a["vezes"]) != int(c["vezes"]):
			return int(a["vezes"]) > int(c["vezes"])
		if int(a["visto"]) != int(c["visto"]):
			return int(a["visto"]) > int(c["visto"])
		return String(a["id"]) < String(c["id"]))
	var janela: Array = []
	for i in mini(JANELA_CRENCAS, itens.size()):
		janela.append(itens[i]["id"])
	return janela


## Funcao PURA do lobo: nao le instancia nenhuma, por isso e static — o gate do
## contrato monta o MESMO prompt que o wrapper envia, sem copiar o formato a mao.
static func _prompt_for(w) -> String:
	var d: Dictionary = w.mind.to_dict()
	var eps: Array = d.get("episodic", [])
	var recent: Array = []
	for i in range(maxi(eps.size() - 3, 0), eps.size()):
		recent.append("%s (forca %.2f)" % [eps[i]["kind"], float(eps[i]["mag"])])
	# A janela top-k (Fase 2 §20.5) substitui o dicionario inteiro: o prompt
	# mostra as crencas que a QUALIDADE ordenou, nao a ordem de insercao — e a
	# selecao e pura no estado da mente, entao o mesmo estado produz o mesmo
	# texto e a chave de conteudo da cache continua valendo entre as corridas.
	var bl := ""
	for id in _janela_crencas(d.get("beliefs", {})):
		bl += "%s=%.2f " % [id, float(d["beliefs"][id]["confidence"])]
	return (
		"lobo %d; intencao atual: %s; vida %.0f%%; fome %.0f%%; "
		+ "confianca no jogador %.2f; memorias recentes: %s; crencas: %s. "
		+ "O que passa na cabeca dele agora?"
	) % [
		w.identity, w.intent, w.hp / w.max_hp() * 100.0,
		w.hunger * 100.0, float(w.mind.trust(0)),
		", ".join(recent), bl.strip_edges(),
	]


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


## Chave do servidor externo, resolvida uma vez por processo. Ordem: ambiente
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
		# Sem entropia nao ha imprint, e imprint vazio e o mesmo que nenhum.
		key_source = "sem-entropia"
		return _key
	# Gravar falha e estado nomeado, nao chave silenciosa: sem arquivo o lancador
	# de fora nao tem como bater a mesma chave.
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
