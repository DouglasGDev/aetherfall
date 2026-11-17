class_name ResponseCurve
## Curvas de resposta da utility AI (docs/design/04.1). Nada de curva hardcoded no
## codigo de comportamento: as opcoes apontam para uma curva + parametros em .tres/dict.

enum Type { LINEAR, EXPONENTIAL, QUADRATIC, SIGMOID, STEP, BELL, INVERSE_BELL, SATURATING }

static func normalize(v: float, lo: float, hi: float) -> float:
	if absf(hi - lo) < 1e-9:
		return 1.0 if v >= hi else 0.0
	return clampf((v - lo) / (hi - lo), 0.0, 1.0)


## x ja normalizado em [0,1]. a/b sao parametros da curva.
static func evaluate(x: float, type: int, a: float, b: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	match type:
		Type.LINEAR:
			return t
		Type.EXPONENTIAL:
			return pow(t, maxf(a, 0.01))
		Type.QUADRATIC:
			return t * t * (3.0 - 2.0 * t) * a
		Type.SIGMOID:
			return 1.0 / (1.0 + exp(-a * (t - b)))
		Type.STEP:
			return 1.0 if t >= a else 0.0
		Type.BELL:
			var d := t - a
			var w := maxf(b, 0.01)
			return exp(-(d * d) / (2.0 * w * w))
		Type.INVERSE_BELL:
			var d2 := t - a
			var w2 := maxf(b, 0.01)
			return 1.0 - exp(-(d2 * d2) / (2.0 * w2 * w2))
		Type.SATURATING:
			return 1.0 - exp(-maxf(a, 0.01) * t)
		_:
			return t


static func evaluate_range(v: float, lo: float, hi: float, type: int, a: float, b: float) -> float:
	return evaluate(normalize(v, lo, hi), type, a, b)


static func type_name(type: int) -> String:
	match type:
		Type.LINEAR: return "linear"
		Type.EXPONENTIAL: return "exp"
		Type.QUADRATIC: return "smoothstep"
		Type.SIGMOID: return "sigmoid"
		Type.STEP: return "step"
		Type.BELL: return "bell"
		Type.INVERSE_BELL: return "inv_bell"
		Type.SATURATING: return "saturating"
		_: return "?"
