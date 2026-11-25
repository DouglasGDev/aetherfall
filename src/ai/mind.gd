class_name Mind
## Mente local (docs/design/04.2): personalidade + crencas groundadas + episodios com
## consolidacao. Nenhuma string entra como crenga sem passar por um verificador de
## grounding quando o ledger existir; no slice, as crencas so sao escritas por
## percepcao direta (testemunha) ou por consolidacao de episodios reais.

const EPISODIC_CAP: int = 24
const BELIEF_DECAY_PER_MIN: float = 0.14
const CONFIDENCE_MIN: float = 0.02
## Quarentena (Fase 2 §20.6): o que o ORACULO sugere entra como crenca
## rebaixada, com a fonte nomeada, e fica abaixo da soleira de `believes` — o
## oraculo propoe, a arvore continua sem aceitar (mandato 2). Nunca intencao
## escrita no corpo.
const QUARENTENA_CONFIDENCE := 0.10
const QUARENTENA_SOURCE := "oracle"
## Curva de resultado (Fase 3 §5.6): ganho que o valor UCB1 da tatica vira de
## bônus no score do escorredor. O §8 item 3 aponta o `breakdown()` como a
## superficie — o Mind so mede e devolve o numero; quem soma e o escorredor.
const BANDIT_GAIN: float = 0.12
## Uma vitoria ja e media real — o portao do duelo (dossie 22 §5.6) exige que o
## bonus exista desde a primeira, e o termo de exploracao do UCB1 carrega a
## incerteza de n=1. Exigir n>=2 congelaria a curva exatamente no momento que
## importa: o lobo morde uma vez e foge, e nenhuma tatica volta a chegar a 2.
const BANDIT_MIN_N: int = 1
## Alpha do EWMA do estilo (StyleFingerprint por arquétipo): peso da selecao
## mais recente. 0.25 = a mistura das ultimas ~4 trocas domina a leitura.
const ESTILO_ALPHA: float = 0.25

var kind: String = "wolf"
var identity: int = 0
var personality := {
	"aggression": 0.55,
	"caution": 0.40,
	"curiosity": 0.50,
}
var episodic: Array = []          # {tick, kind, actor, pos(Vector3), magnitude}
var beliefs := {}                 # String -> {confidence, source, visto_em, vezes}
var relations := {}               # actor:int -> trust:float (-1..1)
var consolidated_events: int = 0
## Fase 3 §5.6: a LIGACAO da curva na escolha. A curva e sempre medida (o
## desligado nao apaga o que foi observado — ver `bandit_abrir`); o que o
## desligado faz e devolver bonus zero, e a escolha volta a ser a de antes.
var bandit_ligado: bool = true
## A curva em si: tatica -> {n, wins, soma, soma2, vencida}. Cada troca de
## tatica abre uma tentativa com resultado 0; a PRIMEIRA vitoria do periodo de pe
## vale 1 na resposta daquela tentativa (`vencida` fecha a conta) e as seguintes
## só sobem `wins`, o contador de eventos. Resultado binario por tentativa e o que
## o UCB1 exige — reward em [0,1] — entao `media = soma/n` E taxa de vitoria,
## nunca contagem: com 8 mortes no mesmo papel a media continua 1,0 e o que
## distingue o braco e `wins`. Para x em {0,1}, x² = x: `soma2` e um acumulador
## proprio que por identidade coincide com `soma`, e a variancia
## `soma2/n - media² = p(1-p)` sai da curva, nao de um contador disfarçado.
var _bandit := {}
## StyleFingerprint por arquétipo (§5.6): EWMA da distribuicao de selecao —
## como ESTE arquétipo vem distribuindo suas escolhas. Soma 1 por construção;
## e leitura (prompt/debug), nunca autoridade: o bônus mora na curva de
## resultado, nao no estilo.
var _estilo := {}


func _init(p_kind := "wolf", p_identity := 0, p_rng_seed := 0) -> void:
	kind = p_kind
	identity = p_identity
	if p_rng_seed != 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = p_rng_seed
		personality["aggression"] = clampf(rng.randf_range(0.35, 0.85), 0.0, 1.0)
		personality["caution"] = clampf(rng.randf_range(0.2, 0.75), 0.0, 1.0)
		personality["curiosity"] = clampf(rng.randf_range(0.25, 0.9), 0.0, 1.0)


func temperament(t: String) -> float:
	return float(personality.get(t, 0.5))


func remember(p_tick: int, p_kind: String, p_pos: Vector3, p_actor: int, p_magnitude: float) -> void:
	episodic.append({
		"tick": p_tick, "kind": p_kind, "pos": p_pos,
		"actor": p_actor, "mag": clampf(p_magnitude, -1.0, 1.0),
	})
	if episodic.size() > EPISODIC_CAP:
		_consolidate(episodic.pop_front())
	_drift(p_kind, p_magnitude)


## Deriva de personalidade: experiencia muda quem a criatura e, nao so o que ela sabe.
func _drift(p_kind: String, p_magnitude: float) -> void:
	match p_kind:
		"hurt":
			personality["caution"] = clampf(temperament("caution") + 0.025 * absf(p_magnitude), 0.0, 1.0)
			personality["aggression"] = clampf(temperament("aggression") - 0.010, 0.0, 1.0)
		"win":
			personality["aggression"] = clampf(temperament("aggression") + 0.02, 0.0, 1.0)
		"fed":
			personality["curiosity"] = clampf(temperament("curiosity") - 0.01, 0.0, 1.0)


func _consolidate(atom: Dictionary) -> void:
	var k: String = atom["kind"]
	if k == "hurt":
		reinforce("danger_from_actor_%d" % int(atom["actor"]), 0.22, "consolidated")
		consolidated_events += 1
	elif k == "saw_player":
		reinforce("player_visible_recent", 0.15, "consolidated")
		consolidated_events += 1


func last_atom(p_kind: String) -> Dictionary:
	for i in range(episodic.size() - 1, -1, -1):
		if episodic[i]["kind"] == p_kind:
			return episodic[i]
	return {}


func count_kind(p_kind: String) -> int:
	var n := 0
	for a in episodic:
		if a["kind"] == p_kind:
			n += 1
	return n


## Toca a crenca: soma o delta na confianca, nomeia a fonte e CONTA o toque em
## `vezes`. O carimbo `visto_em` so segue o tick que CONFIRMOU (p_tick >= 0 e
## delta positivo): reforco negativo contesta a crenca, e contestar nao e ter
## visto de novo. Metadata da Fase 2 (§20.5) — `visto_em` e o ultimo tick que
## confirmou, `vezes` e quantos toques a crenca tomou; ambos sao leitura do que
## o prompt da janela ordena e nunca entram na projecao do TickJournal (§20.5).
func reinforce(p_id: String, p_delta: float, p_source: String, p_tick: int = -1) -> void:
	var b = beliefs.get(p_id)
	if b == null:
		b = {"confidence": 0.0, "source": p_source, "visto_em": -1, "vezes": 0}
		beliefs[p_id] = b
	b["confidence"] = clampf(float(b["confidence"]) + p_delta, 0.0, 1.0)
	b["source"] = p_source
	b["vezes"] = int(b.get("vezes", 0)) + 1
	if p_tick >= 0 and p_delta > 0.0:
		b["visto_em"] = p_tick


func belief(p_id: String) -> float:
	var b = beliefs.get(p_id)
	if b == null:
		return 0.0
	return float(b["confidence"])


## Soleira: so o que passou em percepcao direta ou consolidacao acima do minimo
## conta como crenga utilizavel pelo MemoryGate da arvore.
func believes(p_id: String) -> bool:
	return belief(p_id) >= 0.35


## Sugestao do ORACULO em quarentena (Fase 2 §20.6): a crenca entra (ou sobe
## ate) `QUARENTENA_CONFIDENCE` com a fonte `QUARENTENA_SOURCE` — rebaixada
## abaixo da soleira de `believes`, contando toque e carimbando o tick como
## qualquer reinforce. Delega ao `reinforce` porque a quarentena E um toque de
## reinforce com fonte e teto proprios, nao um caminho de escrita paralelo.
func quarentena(p_id: String, p_tick: int = -1) -> void:
	var alvo := maxf(belief(p_id), QUARENTENA_CONFIDENCE)
	reinforce(p_id, alvo - belief(p_id), QUARENTENA_SOURCE, p_tick)


func decay(elapsed_minutes: float) -> void:
	if elapsed_minutes <= 0.0:
		return
	var keep := _keep_factor(elapsed_minutes)
	var stale: Array = []
	# A metadata de qualidade (`visto_em`/`vezes`) NAO decai: e historia de
	# toques, nao confianca. Ela sai junto quando a crenca inteira morre abaixo
	# do minimo — o esquecimento apaga a crenca, nunca deixa metadata orfa.
	for id in beliefs:
		var b = beliefs[id]
		b["confidence"] = float(b["confidence"]) * keep
		if b["confidence"] < CONFIDENCE_MIN:
			stale.append(id)
	for id in stale:
		beliefs.erase(id)


static func _keep_factor(minutes: float) -> float:
	return exp(-BELIEF_DECAY_PER_MIN * minutes)


func trust(p_actor: int) -> float:
	return float(relations.get(str(p_actor), 0.0))


func adjust_trust(p_actor: int, p_delta: float) -> void:
	relations[str(p_actor)] = clampf(trust(p_actor) + p_delta, -1.0, 1.0)


## Abre uma tentativa na curva de resultado (Fase 3 §5.6): a TROCA de tatica e
## o evento — cada entrada numa tatica e uma pergunta "esta tatica me levou a
## vitoria?" com resposta provisoria 0. A vitoria sobe a resposta depois
## (`bandit_vitoria`). A curva e medida SEMPRE, ligado ou desligado: o que o
## desligado nao faz e aplicar o bônus — apagar a observacao seria punir quem
## desligou o bônus com amnesia do que o duelo já mostrou.
func bandit_abrir(p_tatica: String) -> void:
	var h: Dictionary = _bandit.get(p_tatica,
			{"n": 0, "wins": 0, "soma": 0.0, "soma2": 0.0, "vencida": 0})
	h["n"] = int(h["n"]) + 1
	h["vencida"] = 0
	_bandit[p_tatica] = h
	_estilo_anota(p_tatica)


## Fecha a conta da vitoria na tatica que a produziu. Vitoria sem tentativa
## aberta e dado solto: recusada, porque a curva mede perguntas que a escolha
## realmente fez, nao eventos que chegam soltos. A tentativa ja vencida nao
## conta de novo: quem entra em `soma` e a TENTATIVA, nao o golpe, e o reward de
## um UCB1 tem de ficar em [0,1] — sem essa trava a media passa de 1 (o braco on
## do duelo fechou com 8 mortes em 1 tentativa: media 8), o termo de exploracao
## deixa de somar na mesma escala e o `clampf` esconde tudo atras do teto. A
## intensidade nao se perde: ela fica em `wins`, que conta todo golpe.
func bandit_vitoria(p_tatica: String) -> void:
	if not _bandit.has(p_tatica):
		return
	var h: Dictionary = _bandit[p_tatica]
	h["wins"] = int(h["wins"]) + 1
	if int(h.get("vencida", 0)) == 0:
		h["vencida"] = 1
		h["soma"] = float(h["soma"]) + 1.0
		h["soma2"] = float(h["soma2"]) + 1.0


## O numero que o escorredor soma ao score da tatica: UCB1 sobre a TAXA de
## vitoria por tentativa (media + sqrt(2 ln N / n)), escalado por BANDIT_GAIN.
## Com o reward binario, media e `exploracao` vivem na mesma escala e o
## `clampf` e só a tranca do teto (2,0 * 0,12 = 0,24 de score), nao o lugar onde
## a conta desanda. Duas guardas mandam no que existe: braco com menos de
## BANDIT_MIN_N tentativas nao tem media que prestes, e braco SEM VITORIA nenhuma
## (media 0) nao ganha bonus — o termo de exploracao empurraria a escolha de
## volta para o que NAO funcionou; explorar bracos novos e trabalho das regras
## deterministicas e dos vetoes, nao do bônus. Com `bandit_ligado` falso o numero
## e zero: mesmo seed, mesmo duelo, escolha de antes da Fase 3.
func bandit_bonus(p_tatica: String) -> float:
	if not bandit_ligado:
		return 0.0
	var h: Dictionary = _bandit.get(p_tatica, {})
	var n := int(h.get("n", 0))
	if n < BANDIT_MIN_N:
		return 0.0
	var media := float(h.get("soma", 0.0)) / float(n)
	if media <= 0.0:
		return 0.0
	var total_n := 0
	for k in _bandit:
		total_n += int(_bandit[k]["n"])
	var exploracao := sqrt(2.0 * log(max(float(total_n), 2.0)) / float(n))
	return BANDIT_GAIN * clampf(media + exploracao, 0.0, 2.0)


## Leitura da curva para debug/prompt (§5.6: "a curva de resultado por opcao"
## precisa ser legivel). Copia profunda: quem le nao pode mutar o estado.
func leitura_bandit() -> Dictionary:
	return _bandit.duplicate(true)


## StyleFingerprint (§5.6): EWMA da distribuicao de selecao do arquétipo. Cada
## `bandit_abrir` e uma selecao observada: todos os pesos decaem (1 - alpha) e
## a tatica escolhida ganha alpha — a mistura recente domina, o passado demora
## a sumir. A PRIMEIRA selecao de uma impressao fria entra valendo 1.0, nao
## alpha: uma observacao unica E a distribuicao inteira que existe, e a soma
## tem de comecar em 1 (o decaimento guarda a soma; alpha frio faria a soma
## subir de 0.25 a 1 ao longo de ~11 selecoes, e a leitura mentira nesse meio
## tempo). Soma 1 por construção.
func _estilo_anota(p_tatica: String) -> void:
	if _estilo.is_empty():
		_estilo[p_tatica] = 1.0
		return
	var decai := 1.0 - ESTILO_ALPHA
	for k in _estilo:
		_estilo[k] = float(_estilo[k]) * decai
	_estilo[p_tatica] = float(_estilo.get(p_tatica, 0.0)) + ESTILO_ALPHA


## Leitura do estilo. Vazio enquanto nada foi selecionado — "sem dados" e um
## estado honesto, e nao um dicionario de zeros fingindo medicao.
func estilo() -> Dictionary:
	return _estilo.duplicate(true)


func to_dict() -> Dictionary:
	var ep: Array = []
	for a in episodic:
		var p: Vector3 = a["pos"]
		ep.append({
			"tick": a["tick"], "kind": a["kind"], "actor": a["actor"], "mag": a["mag"],
			"pos": [p.x, p.y, p.z],
		})
	var bl := {}
	for id in beliefs:
		# Os quatro campos vao ao disco (Fase 2 §20.5): a qualidade sobrevive ao
		# save/load. O `get` com default tolera dict montado a mao sem metadata.
		bl[id] = {
			"confidence": beliefs[id]["confidence"],
			"source": beliefs[id]["source"],
			"visto_em": int(beliefs[id].get("visto_em", -1)),
			"vezes": int(beliefs[id].get("vezes", 0)),
		}
	return {
		"kind": kind, "identity": identity, "personality": personality,
		"episodic": ep, "beliefs": bl, "relations": relations,
		"consolidated": consolidated_events,
		# Fase 3 §5.6: a curva e o estilo vao ao disco — o lobo que sobreviveu ao
		# save nao volta a pagar a mesma aula. A ligacao vai junto: carregar com
		# o bandit desligado nao pode religar por conta do load.
		"bandit": _bandit, "estilo": _estilo, "bandit_ligado": bandit_ligado,
	}


func from_dict(d: Dictionary) -> void:
	kind = String(d.get("kind", kind))
	identity = int(d.get("identity", identity))
	personality = d.get("personality", personality)
	relations = d.get("relations", {})
	consolidated_events = int(d.get("consolidated", 0))
	episodic.clear()
	for a in d.get("episodic", []):
		var p = a.get("pos", [0.0, 0.0, 0.0])
		episodic.append({
			"tick": int(a["tick"]), "kind": String(a["kind"]), "actor": int(a["actor"]),
			"mag": float(a["mag"]), "pos": Vector3(float(p[0]), float(p[1]), float(p[2])),
		})
	beliefs.clear()
	for id in d.get("beliefs", {}):
		# Formato novo (Fase 2 §20.5): dict com os quatro campos. Formato velho
		# (float solto, saves de antes da Fase 2): reconstruido sem metadata —
		# `visto_em` -1 e `vezes` 0 dizem "nenhum toque confirmado desde o
		# load". O source volta "loaded" nos dois: o load nao e testemunha — a
		# crenca gravada vale, mas nao conta como percepcao direta desta vida
		# (politica do gate; mudar isso e decisao de versao, nao desta fase).
		var vb = d["beliefs"][id]
		if vb is Dictionary:
			beliefs[id] = {
				"confidence": float(vb.get("confidence", 0.0)),
				"source": "loaded",
				"visto_em": int(vb.get("visto_em", -1)),
				"vezes": int(vb.get("vezes", 0)),
			}
		else:
			beliefs[id] = {
				"confidence": float(vb),
				"source": "loaded",
				"visto_em": -1,
				"vezes": 0,
			}
	# Fase 3 §5.6: saves de antes da Fase 3 nao tem as chaves — mente fria nasce
	# do load antigo, e nao de um load que finge que a curva existia.
	_bandit = {}
	var b_disco = d.get("bandit", {})
	if b_disco is Dictionary:
		for t in b_disco:
			var hb = b_disco[t]
			if hb is Dictionary:
				_bandit[String(t)] = {
					"n": int(hb.get("n", 0)), "wins": int(hb.get("wins", 0)),
					"soma": float(hb.get("soma", 0.0)), "soma2": float(hb.get("soma2", 0.0)),
					"vencida": int(hb.get("vencida", 0)),
				}
	_estilo = {}
	var e_disco = d.get("estilo", {})
	if e_disco is Dictionary:
		for t in e_disco:
			_estilo[String(t)] = float(e_disco[t])
	bandit_ligado = bool(d.get("bandit_ligado", true))
