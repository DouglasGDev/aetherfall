extends Node
## Probe vivo do oraculo (fora da suite): roda a sessao real headless com o
## llama-server ligado e imprime a narrativa de cada lobo conforme ela chega.
## Sai 0 com pelo menos duas frases (prova o round-robin e o recuo zerado);
## sai 1 se o prazo estourar. Uso:
##   1) tools\run_mind_server.ps1
##   2) godot --headless --path . tests/live_oracle_probe.tscn

const DEADLINE := 120.0
const NEEDED := 2

var _main: Node3D = null
var _t0 := -1.0
var _got := 0
var _seen := {}
var _done := false


func _ready() -> void:
	_main = load("res://src/main.tscn").instantiate()
	add_child(_main)
	_t0 = float(Time.get_ticks_msec()) / 1000.0


func _process(_delta: float) -> void:
	if _done:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	for w in _main.wolves:
		var narr := String(_main.oracle.narration_of(w.identity))
		if narr.is_empty() or _seen.has(w.identity):
			continue
		_seen[w.identity] = true
		_got += 1
		print("lobo%d  +%.1f s  ia: %s" % [w.identity, now - _t0, narr])
		if _got >= NEEDED:
			_done = true
			print("ok: %d narrativas  recuo do servidor=%.1f s" % [_got, _main.oracle._server_cd])
			get_tree().quit(0)
			return
	if now - _t0 > DEADLINE:
		print("FALHA: %d narrativas em %.0f s  recuo=%.1f s" % [_got, DEADLINE, _main.oracle._server_cd])
		get_tree().quit(1)
