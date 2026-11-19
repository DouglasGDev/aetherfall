extends Node
## Sonda viva do audio (fora da suite): roda a sessao real EM JANELA, com o driver
## de audio do sistema, e mede o que chega ao barramento. Ela existe porque o
## headless nao pode provar audibilidade: la o driver e `Dummy`, `playing` vira
## true e a posicao de playback nunca avanca -- o que o motor mistura e silencio.
## O censo das premissas (tabelas, ganhos, cadencia, consumidores) fica em
## tests/audio_test.gd; aqui se responde uma coisa so: o alto-falante recebe
## samples de um arquivo CC0 tocado pelo proprio jogo, sem nenhum input.
##
## Uso: godot --path . tests/audio_live_probe.tscn

const BOOT_SECONDS := 12.0
## Janela de escuta. Nenhum input e disparado: quem anda e a matilha.
const LISTEN_SECONDS := 6.0
## Pico abaixo disso e silencio para a medicao. O medidor do Godot devolve um dB
## muito negativo quando o barramento nao recebeu nada, e um passo a 20 m do
## ouvinte sai na casa de -30 dB -- a margem e de 30 dB.
##
## O medidor nao diferencia driver real de Dummy: na mesma arvore, uma corrida
## que caiu em Dummy marcou -12,7 dB no SFX. Por isso a checagem do driver vem
## primeiro e so o `!= "Dummy"` prova o caminho ate o dispositivo.
const AUDIBLE_DB := -60.0
## Familias que so podem vir de um corpo andando ou vocalizando: a cama ambiental
## toca num barramento proprio e nao prova o caminho 3D das vozes.
const MOVING_FAMILIES := ["step_dirt", "step_grass", "step_snow", "step_stone",
	"step_wood", "bark", "howl", "splash"]

var _main: Node3D = null
var _t0 := -1.0
var _peak_master := -999.0
var _peak_sfx := -999.0
var _peak_amb := -999.0
var _events_before := 0
var _families_before := {}
var _listening := false
var _finished := false


func _ready() -> void:
	print("driver do sistema: ", AudioServer.get_driver_name())
	_main = load("res://src/main.tscn").instantiate()
	add_child(_main)
	_t0 = float(Time.get_ticks_msec()) / 1000.0


func _process(_delta: float) -> void:
	if _finished:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	if not _listening:
		if now - _t0 >= BOOT_SECONDS:
			_listening = true
			_events_before = int(_main.audio.events_played)
			_families_before = _main.audio.family_played.duplicate()
			print("escutando %.1f s sem nenhum input..." % LISTEN_SECONDS)
		return
	_peak_master = maxf(_peak_master, _peak(0))
	_peak_sfx = maxf(_peak_sfx, _peak(AudioServer.get_bus_index("SFX")))
	_peak_amb = maxf(_peak_amb, _peak(AudioServer.get_bus_index("Ambience")))
	if now - _t0 >= BOOT_SECONDS + LISTEN_SECONDS:
		_report()


## Maior dos dois canais do bus no frame lido (o medidor e por frame de mixagem).
func _peak(bus: int) -> float:
	if bus < 0:
		return -999.0
	return maxf(AudioServer.get_bus_peak_volume_left_db(bus, 0),
			AudioServer.get_bus_peak_volume_right_db(bus, 0))


func _report() -> void:
	_finished = true
	var a = _main.audio
	var driver := AudioServer.get_driver_name()
	var played := int(a.events_played) - _events_before
	## Incremento por familia, nao familias novas: os lobos comecam a andar ainda
	## durante o boot, entao quando a escuta abre as chaves ja existem e uma
	## diferenca de chaves ficaria vazia para sempre (foi o que a primeira corrida
	## mostrou: 13 toques na janela e `familias novas: []`).
	var grown := {}
	for key in a.family_played:
		var f := String(key)
		var d := int(a.family_played[key]) - int(_families_before.get(key, 0))
		if d > 0:
			grown[f] = d
	var moving := 0
	for f in MOVING_FAMILIES:
		moving += int(grown.get(f, 0))
	print("toques na janela: %d   por familia: %s" % [played, str(grown)])
	print("cama ambiental: ", String(a.diagnostics()["bed"]))
	print("pico medido (dB)  master=%.1f  sfx=%.1f  ambience=%.1f" % [
		_peak_master, _peak_sfx, _peak_amb])
	var ok := true
	ok = _check(driver != "Dummy", "o motor abriu um driver de audio real", driver) and ok
	ok = _check(played > 0, "o jogo toca eventos sozinho, sem input", "toques=%d" % played) and ok
	ok = _check(moving > 0, "quem tocou foi um corpo (passo, latido, uivo ou splash)",
			"toques de corpo=%d" % moving) and ok
	ok = _check(_peak_sfx > AUDIBLE_DB, "o barramento SFX recebe samples audiveis",
			"pico=%.1f dB (corte %.1f)" % [_peak_sfx, AUDIBLE_DB]) and ok
	ok = _check(_peak_amb > AUDIBLE_DB, "a cama ambiental sai pelo barramento Ambience",
			"pico=%.1f dB (corte %.1f)" % [_peak_amb, AUDIBLE_DB]) and ok
	ok = _check(_peak_master > AUDIBLE_DB, "o Master entrega amostra ao dispositivo",
			"pico=%.1f dB" % _peak_master) and ok
	print("sonda viva: %s" % ("ok" if ok else "FALHOU"))
	get_tree().quit(0 if ok else 1)


func _check(condition: bool, label: String, detail: String) -> bool:
	print("%s  %s  [%s]" % ["OK   " if condition else "FALHA", label, detail])
	return condition
