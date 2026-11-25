class_name Mind
## Mente local (docs/design/04.2): personalidade + crencas groundadas + episodios com
## consolidacao. Nenhuma string entra como crenga sem passar por um verificador de
## grounding quando o ledger existir; no slice, as crencas so sao escritas por
## percepcao direta (testemunha) ou por consolidacao de episodios reais.

const EPISODIC_CAP: int = 24
const BELIEF_DECAY_PER_MIN: float = 0.14
const CONFIDENCE_MIN: float = 0.02

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
