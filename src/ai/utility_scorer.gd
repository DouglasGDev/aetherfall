class_name UtilityScorer
## Escolha de acao por utilidade com veto duro e histerese anti flip-flop.
## O resultado inclui o detalhamento por consideracao: e o que torna a decisao
## legivel no overlay de debug (premissa inegociavel do projeto).

class Consideration:
	var id: String = ""
	var getter: Callable
	var lo: float = 0.0
	var hi: float = 1.0
	var curve: int = ResponseCurve.Type.LINEAR
	var a: float = 1.0
	var b: float = 0.5
	var weight: float = 1.0
	# veto=true: portao, nao componente. Passa ou zera a opcao; nunca pontua,
	# senao um gate satisfeito inflaria a media e a opcao ganharia por existir.
	var veto: bool = false


class Option:
	var id: String = ""
	var considerations: Array = []   # Consideration

	func add(p_id: String, p_getter: Callable, p_lo: float, p_hi: float,
			p_curve: int, p_a: float, p_b: float, p_weight: float, p_veto: bool) -> Option:
		var c := Consideration.new()
		c.id = p_id
		c.getter = p_getter
		c.lo = p_lo
		c.hi = p_hi
		c.curve = p_curve
		c.a = p_a
		c.b = p_b
		c.weight = p_weight
		c.veto = p_veto
		considerations.append(c)
		return self


var options: Array = []
var min_lead: float = 0.06
var min_interval: float = 0.45
var _last_switch: float = -99.0
var _breakdown: Dictionary = {}


func add_option(id: String) -> Option:
	var o := Option.new()
	o.id = id
	options.append(o)
	return o


func scored(elapsed: float, ctx: Dictionary) -> Array:
	var results: Array = []
	_breakdown.clear()
	# A curva de resultado (Fase 3 §5.6) mora AQUI, onde o dossie aponta: quem
	# trouxer um Mind no contexto ("bandit") empresta o numero UCB1 da tatica e
	# o escorredor soma ao score — so isso. O bônus entra DEPOIS do veto
	# (`not vetoed`): portao fechado e portao fechado, o bandit nao atravessa.
	# Contexto sem "bandit" (quem monta escorredor a mao) e bônus zero: a
	# superficie e optica por construcao, e o caminho OFF e o de antes da Fase 3.
	var bandit = ctx.get("bandit")
	for o in options:
		var total := 1.0
		var additive := 0.0
		var weight_sum := 0.0
		var vetoed := false
		var parts: Array = []
		for c in o.considerations:
			var raw: float = float(c.getter.call(ctx))
			var shaped: float = ResponseCurve.evaluate_range(
				raw, c.lo, c.hi, c.curve, c.a, c.b)
			parts.append([c.id, raw, shaped, c.weight, c.veto])
			# veto = portao: nao pontua. Se nao passa, a opcao inteira vale zero.
			if c.veto:
				if shaped <= 0.0001:
					vetoed = true
				continue
			additive += shaped * c.weight
			weight_sum += c.weight
		var score := 0.0 if (vetoed or weight_sum <= 0.0) else additive / weight_sum
		var bonus := 0.0
		if bandit != null and not vetoed and bandit.has_method("bandit_bonus"):
			bonus = float(bandit.call("bandit_bonus", o.id))
			if bonus > 0.0:
				score += bonus
		_breakdown[o.id] = {"score": score, "vetoed": vetoed, "parts": parts, "bandit": bonus}
		results.append([o.id, score])
	results.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) > float(y[1]))
	return results


## Histerese: so troca se a nova opcao liderar por min_lead e se passaram
## min_interval segundos desde a ultima troca.
func choose(elapsed: float, ctx: Dictionary, current: String) -> String:
	var results := scored(elapsed, ctx)
	if results.is_empty():
		return current
	var best: String = results[0][0]
	var best_score: float = results[0][1]
	if current == best:
		return current
	var current_score := 0.0
	var found := false
	for r in results:
		if r[0] == current:
			current_score = r[1]
			found = true
			break
	if not found:
		return best
	if elapsed - _last_switch < min_interval:
		return current
	if best_score > current_score + min_lead:
		_last_switch = elapsed
		return best
	return current


func breakdown() -> Dictionary:
	return _breakdown


func top_line() -> String:
	if _breakdown.is_empty():
		return "-"
	var best_id := ""
	var best_score := -1.0
	for k in _breakdown:
		var s: float = _breakdown[k]["score"]
		if s > best_score:
			best_score = s
			best_id = k
	var parts: Array = _breakdown[best_id]["parts"]
	var out := best_id + " " + "%.2f" % best_score
	var shown := 0
	for p in parts:
		if shown >= 3:
			break
		out += " | %s=%.2f" % [p[0], p[2]]
		shown += 1
	return out
