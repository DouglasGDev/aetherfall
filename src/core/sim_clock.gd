class_name SimClock
## Relogio de simulacao autoritativo. Toda decisao de IA, todo imprint de Eter e todo
## tick de rede vivem aqui (docs/design/06.2). Render e interpolado a parte.

const HZ: int = 20
const STEP: float = 1.0 / HZ
const MAX_STEPS_PER_FRAME: int = 5

var tick: int = 0
var _accumulator: float = 0.0
var _t_step: float = 0.0
var last_step_ms: float = 0.0
var worst_step_ms: float = 0.0
var dropped_ticks: int = 0


## Quantos passos devem rodar neste frame; estourar o cap conta como tick perdido
## (visivel no overlay, nunca catch-up silencioso).
func advance(delta: float) -> int:
	_accumulator += delta
	var steps: int = 0
	while _accumulator >= STEP:
		if steps >= MAX_STEPS_PER_FRAME:
			dropped_ticks += 1
			_accumulator = 0.0
			break
		_accumulator -= STEP
		steps += 1
	return steps


func begin_step() -> void:
	_t_step = float(Time.get_ticks_usec())


func end_step() -> void:
	var t := Time.get_ticks_usec()
	last_step_ms = float(t - _t_step) / 1000.0
	worst_step_ms = maxf(worst_step_ms, last_step_ms)


func step_duration() -> float:
	return STEP


func reset_worst() -> void:
	worst_step_ms = 0.0
