extends Node
class_name AudioDirector
## Som do slice: consumidor dos eventos que o mundo ja emite. Nao escreve voxel,
## nao toca no Eter, nao sorteia na RNG da populacao nem na do lobo -- por isso o
## hash por tick nao muda com audio ligado (tests/audio_test.gd mede isso).
##
## O ganho de cada arquivo sai do nivel medio MEDIDO dele (docs/audio-provenance
## .md, tabela arquivo por arquivo) gravado em assets/audio/levels.json. O audio
## do Veloren esta vetado (AGENTS.md regra 8): nada aqui veio daquele repositorio.

const ROOT := "res://assets/audio/"
const LEVELS_PATH := "res://assets/audio/levels.json"
## Todo arquivo e levado ao mesmo nivel medio de mixagem; o ganho e a diferenca
## entre o que foi medido no arquivo e este alvo.
const MIX_TARGET_DB := -20.0
## Corte do ganho. Dos 51 arquivos medidos, um unico passa dele: `ui_click` a
## -34,3 dB pediria +14,3. O vizinho `splash_1` (-33,9) fica em +13,9, dentro do
## alcance. Subir o corte so empolaria o pico do clique sem gain-staging nenhum
## atras, entao o clique fica 0,3 dB abaixo do alvo por decisao medida.
const GAIN_CLAMP_DB := 14.0
## A cama ambiental mora abaixo da acao: os tres beds medidos vao de -30,8 a
## -29,1 dB e, normalizados no alvo dos SFX, brigariam com cada passo.
const AMBIENCE_TRIM_DB := -12.0

const VOICES := 12
const MAX_DISTANCE := 64.0
## Mesmo limiar de velocidade que o bob da camera usa (`_update_camera`): abaixo
## disso o corpo esta parado ou arrastando um pe.
const MIN_STEP_SPEED := 0.4
const STRIDE_METERS := 1.9
const SWIM_STROKE_METERS := 1.4
## Teleporte nao e caminhada: respawn e load movem o corpo dezenas de metros no
## mesmo frame, e o acumulador dispararia uma rajada de passos.
const MAX_STRIDE_JUMP := 10.0
## Um tick de lavra a cada 0,3 s com a barra de minerio avancando.
const DIG_TICK_SECONDS := 0.3
const AMBIENCE_PERIOD := 1.0
const AMBIENCE_FADE_SECONDS := 0.7
const AMBIENCE_SCAN_RADIUS := 3
const AMBIENCE_WATER_BLOCKS := 6
const AMBIENCE_SNOW_BLOCKS := 6
const BARK_RANGE := 14.0
const BARK_COOLDOWN := 3.0
const HOWL_COOLDOWN := 18.0
## RNG propria, com semente fixa: a sequencia de variantes e reproduzivel e nao
## compete com os sorteios da simulacao.
const AUDIO_SEED := 20261118

## Evento -> familia. Todo toque que nao depende de material passa por aqui, e e a
## mesma tabela que o teste usa para provar que nenhum arquivo do set ficou sem uso.
const EVENTS := {
	"attacked": "swing",
	"player_hurt": "hit_flesh",
	"player_died": "player_die",
	"wolf_bite": "wolf_roar",
	"wolf_hurt": "wolf_hurt",
	"wolf_died": "wolf_die",
	"bark": "wolf_bark",
	"howl": "wolf_howl",
	"place": "place",
	"ui": "ui_click",
	"splash": "splash",
}

## Bloco sob os pes -> familia de passo. Cobre o enum inteiro menos AIR e WATER:
## no ar nao ha passo, na agua quem responde e o splash.
const STEP_FAMILY := {
	BlockDefs.Block.GRASS: "step_grass",
	BlockDefs.Block.DIRT: "step_dirt",
	BlockDefs.Block.STONE: "step_stone",
	BlockDefs.Block.SAND: "step_dirt",
	BlockDefs.Block.SNOW: "step_snow",
	BlockDefs.Block.WOOD: "step_wood",
	BlockDefs.Block.LEAVES: "step_grass",
	BlockDefs.Block.COBBLESTONE: "step_stone",
	BlockDefs.Block.PLANK: "step_wood",
	BlockDefs.Block.GLASS: "step_stone",
	BlockDefs.Block.BENCH: "step_wood",
}

## Bloco -> classe de material. Dai saem `dig_<classe>` e `break_<classe>`: o que
## se ouve e o material, nao o id gravado no save.
const MATERIAL_FAMILY := {
	BlockDefs.Block.GRASS: "soft",
	BlockDefs.Block.DIRT: "soft",
	BlockDefs.Block.SAND: "soft",
	BlockDefs.Block.SNOW: "soft",
	BlockDefs.Block.LEAVES: "soft",
	BlockDefs.Block.STONE: "stone",
	BlockDefs.Block.COBBLESTONE: "stone",
	BlockDefs.Block.WOOD: "wood",
	BlockDefs.Block.PLANK: "wood",
	BlockDefs.Block.BENCH: "wood",
	BlockDefs.Block.GLASS: "glass",
}

## Regra da cama ambiental -> familia do bed.
const AMBIENCE := {
	"water": "amb_water",
	"snow": "amb_wind",
	"open": "amb_birds",
}

var world: VoxelWorld = null
var player: Player = null
var wolves_provider: Callable = Callable()
## Contador de toques, para o censo do teste e para a linha de diagnostico.
var events_played: int = 0
## Último toque e o total por familia: sem isso o teste teria que confiar que um
## `_sfx` qualquer rodou, e "rodou" e justamente a premissa que se cobra.
var last_event := ""
var last_asset := ""
var family_played := {}

var _families := {}
var _levels := {}
var _rng := RandomNumberGenerator.new()
var _voices: Array[AudioStreamPlayer3D] = []
var _busy: Array[float] = []
var _ui_voice: AudioStreamPlayer = null
var _beds: Array[AudioStreamPlayer] = []
var _bed := ""
var _pending := ""
var _bed_slot := -1
var _bed_out := -1
var _fade_left := 0.0
var _bed_gain_in := 0.0
var _bed_gain_out := 0.0
var _amb_cd := 0.0
var _howl_cd := 0.0
var _dig_cd := DIG_TICK_SECONDS
var _dig_target := Vector3i.ZERO
## Transitorio por corpo, chaveado por `wolf.identity` (o jogador e -1): posicao
## anterior, acumulador de passo, agua e cooldown de vocalizacao. Nunca vira save,
## e o load limpa.
var _body_state := {}


func _ready() -> void:
	_rng.seed = AUDIO_SEED
	_howl_cd = _rng.randf_range(4.0, 10.0)
	_load_levels()
	_build_voices()


func setup(p_world: VoxelWorld, p_player: Player) -> void:
	world = p_world
	player = p_player
	player.block_broken.connect(on_block_broken)
	player.block_placed.connect(on_block_placed)
	player.attacked.connect(_on_attacked)
	player.damaged.connect(_on_player_damaged)
	player.died.connect(_on_player_died)
	player.panel_changed.connect(_on_panel_changed)


## Main chama no spawn de cada lobo, ao lado das conexoes que ja faz.
func on_wolf_registered(w: Wolf) -> void:
	w.bit_player.connect(_on_wolf_bit)
	w.wounded.connect(_on_wolf_wounded)
	w.died.connect(_on_wolf_died)


## Load troca o mundo inteiro: as posicoes antigas nao dizem nada sobre as novas,
## entao o passo recomeca do zero em vez de somar o salto.
func clear_transient() -> void:
	_body_state.clear()
	_dig_cd = DIG_TICK_SECONDS
	_dig_target = Vector3i.ZERO


func _physics_process(delta: float) -> void:
	update_audio(delta)


## Fecha as vozes na saida para o player nao segurar mais o stream. Medido em
## docs/evidence/audio/leak-probe.log: `stop()` no mesmo tick do quit nao limpa a
## playback -- o AudioServer so libera o playback no proximo tick de mix, e o
## processo morre antes. Sair com um stream tocando deixa 4 instancias e 2 recursos
## por stream nos logs de saida do engine; `stop()` seguido de mais frames limpa.
func _exit_tree() -> void:
	for v in _voices:
		v.stop()
	for b in _beds:
		b.stop()
	_ui_voice.stop()


func update_audio(delta: float) -> void:
	if world == null or player == null:
		return
	_howl_cd -= delta
	_amb_cd -= delta
	if _amb_cd <= 0.0:
		_amb_cd = AMBIENCE_PERIOD
		_pick_ambience()
	_update_bed(delta)
	_player_stride()
	_mining_ticks(delta)
	_wolves_stride(delta)


# ------------------------------------------------------------------ dados

func _load_levels() -> void:
	if not FileAccess.file_exists(LEVELS_PATH):
		push_error("audio: %s nao existe, entao o ganho nao tem de onde sair" % LEVELS_PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("audio: %s nao e um objeto JSON" % LEVELS_PATH)
		return
	# A chave e guardada ja como caminho de recurso: `levels.json` usa o caminho
	# relativo ao repositorio, e o resto do diretor so sabe falar `res://`. Uma
	# chave em cada forma foi o primeiro defeito medido aqui (o passo morria em
	# `gain_db` antes do `play`).
	for key in parsed:
		_levels[ROOT + String(key)] = float(parsed[key])


## As familias sao DERIVADAS do que foi medido: nenhum arquivo entra no set tocavel
## sem nivel medido, e nenhum nivel medido fica fora do set.
func families() -> Dictionary:
	if _families.is_empty() and not _levels.is_empty():
		_scan_families()
	return _families


func _scan_families() -> void:
	for key in _levels:
		var path := String(key)
		var family := family_of(path)
		if not _families.has(family):
			_families[family] = []
		(_families[family] as Array).append(path)
	for family in _families:
		(_families[family] as Array).sort()


## `step_grass_2` -> `step_grass`: sufixo `_` + digitos e o numero da variante.
static func family_of(path: String) -> String:
	var base := path.get_file().get_basename()
	var cut := base.rfind("_")
	if cut <= 0:
		return base
	var suffix := base.substr(cut + 1)
	if suffix.is_empty():
		return base
	for i in suffix.length():
		if not suffix[i] in "0123456789":
			return base
	return base.substr(0, cut)


func gain_db(path: String) -> float:
	return clampf(MIX_TARGET_DB - float(_levels[path]), -GAIN_CLAMP_DB, GAIN_CLAMP_DB)


## A variante sorteada vem da RNG do diretor, nunca da do lobo ou da populacao:
## audio nao pode empurrar a simulacao para outro lugar.
func choose(family: String) -> String:
	var pool: Array = families().get(family, [])
	if pool.is_empty():
		push_error("audio: familia %s nao existe em levels.json" % family)
		return ""
	return pool[_rng.randi_range(0, pool.size() - 1)]


## Familias que o codigo nomeia, nos tres mapas. O teste difere isso das familias
## derivadas de levels.json nos dois sentidos: tabela sem arquivo e arquivo sem
## tabela.
func referenced_families() -> Array:
	var out: Array = []
	for v in EVENTS.values():
		out.append(String(v))
	for v in STEP_FAMILY.values():
		out.append(String(v))
	for v in MATERIAL_FAMILY.values():
		out.append("dig_%s" % v)
		out.append("break_%s" % v)
	for v in AMBIENCE.values():
		out.append(String(v))
	out.sort()
	return out


func diagnostics() -> Dictionary:
	return {
		"driver": AudioServer.get_driver_name(),
		"levels": _levels.size(),
		"families": families().size(),
		"voices": VOICES,
		"events_played": events_played,
		"families_played": family_played.size(),
		"last_event": last_event,
		"bed": _bed,
	}


## Um ponto unico de registro: o que tocou, com que arquivo e quantas vezes.
func _record(family: String, path: String) -> void:
	last_event = family
	last_asset = path
	family_played[family] = int(family_played.get(family, 0)) + 1
	events_played += 1


# ------------------------------------------------------------------ vozes

func _build_voices() -> void:
	for i in VOICES:
		var v := AudioStreamPlayer3D.new()
		v.bus = "SFX"
		v.max_distance = MAX_DISTANCE
		add_child(v)
		_voices.append(v)
		_busy.append(0.0)
	_ui_voice = AudioStreamPlayer.new()
	_ui_voice.bus = "UI"
	add_child(_ui_voice)
	for i in 2:
		var b := AudioStreamPlayer.new()
		b.bus = "Ambience"
		add_child(b)
		_beds.append(b)


## Voz livre pela duracao do arquivo no relogio de parede, nao por `playing`: o
## flag so vira falso no proximo tick de mix depois do fim, entao o tempo gravado
## libera a voz no instante exato sem depender de poll do engine. Medido em
## headless com o driver Dummy (docs/evidence/audio/dummy-progress.log): a posicao
## anda e `step_grass_1` (0,778 s) termina sozinho -- `playing=false` entre os
## frames 100 e 120, quando a cama ao lado marca 0,744 s e 0,837 s.
func _voice_index() -> int:
	var now := Time.get_ticks_msec() / 1000.0
	var best := 0
	var best_busy := INF
	for i in _voices.size():
		if _busy[i] <= now:
			return i
		if _busy[i] < best_busy:
			best_busy = _busy[i]
			best = i
	return best


func _sfx(family: String, pos: Vector3) -> void:
	var path := choose(family)
	if path == "":
		return
	var i := _voice_index()
	var v := _voices[i]
	var stream: AudioStream = load(path)
	v.stream = stream
	v.volume_db = gain_db(path)
	v.global_position = pos
	v.play()
	_busy[i] = Time.get_ticks_msec() / 1000.0 + stream.get_length()
	_record(family, path)


func _ui(family: String) -> void:
	var path := choose(family)
	if path == "":
		return
	var stream: AudioStream = load(path)
	_ui_voice.stream = stream
	_ui_voice.volume_db = gain_db(path)
	_ui_voice.play()
	_record(family, path)


# ------------------------------------------------------------------ eventos do mundo

func on_block_broken(pos: Vector3i, block: int) -> void:
	var material := _material_of(block)
	if material == "":
		return
	_sfx("break_%s" % material, _center(pos))


## Colocar bloco tem uma familia unica: o set nao tem `place_<material>`, entao o
## som nao finge que distingue madeira de pedra.
func on_block_placed(pos: Vector3i, _block: int) -> void:
	_sfx(String(EVENTS["place"]), _center(pos))


func _on_attacked(_target: Node3D, _amount: float) -> void:
	_sfx(String(EVENTS["attacked"]), player.eye_position())


func _on_player_damaged(_amount: float, from: Vector3) -> void:
	_sfx(String(EVENTS["player_hurt"]), from)


func _on_player_died(at: Vector3) -> void:
	_sfx(String(EVENTS["player_died"]), at)


func _on_panel_changed(_open: bool) -> void:
	_ui(String(EVENTS["ui"]))


func _on_wolf_bit(w: Wolf, _amount: float) -> void:
	_sfx(String(EVENTS["wolf_bite"]), w.center())


func _on_wolf_wounded(w: Wolf, _amount: float) -> void:
	_sfx(String(EVENTS["wolf_hurt"]), w.center())


func _on_wolf_died(_w: Wolf, pos: Vector3) -> void:
	_sfx(String(EVENTS["wolf_died"]), pos)


static func _center(v: Vector3i) -> Vector3:
	return Vector3(v) + Vector3(0.5, 0.5, 0.5)


func _material_of(block: int) -> String:
	return String(MATERIAL_FAMILY.get(block, ""))


## O bloco logo abaixo dos pes: `feet_pos` mora na face de cima do solido, entao o
## voxel da propria coluna e ar e o chao e o de baixo.
func _surface_block(feet: Vector3) -> int:
	return world.get_block_xyz(
		int(floorf(feet.x)), int(floorf(feet.y)) - 1, int(floorf(feet.z)))


# ------------------------------------------------------------------ cadencia de corpo

## Distancia percorrida vira passo: a cadencia e o passo do corpo, nao o numero de
## frames. A mesma conta vale para o jogador e para cada lobo.
func _stride(st: Dictionary, feet: Vector3, speed: float, in_water: bool, on_ground: bool) -> void:
	var previous: Vector3 = st["pos"]
	st["pos"] = feet
	var dist := Vector3(feet.x - previous.x, 0.0, feet.z - previous.z).length()
	if in_water != bool(st["in_water"]):
		st["in_water"] = in_water
		if in_water:
			_sfx(String(EVENTS["splash"]), feet)
	if dist > MAX_STRIDE_JUMP or speed < MIN_STEP_SPEED:
		st["accum"] = 0.0
		return
	st["accum"] = float(st["accum"]) + dist
	var stride := SWIM_STROKE_METERS if in_water else STRIDE_METERS
	if not in_water and not on_ground:
		return
	while float(st["accum"]) >= stride:
		st["accum"] = float(st["accum"]) - stride
		if in_water:
			_sfx(String(EVENTS["splash"]), feet)
			continue
		var family := String(STEP_FAMILY.get(_surface_block(feet), ""))
		if family != "":
			_sfx(family, feet + Vector3(0.0, 0.1, 0.0))


func _player_stride() -> void:
	var st := _state_for(-1, player.body.feet_pos)
	_stride(st, player.body.feet_pos, _planar_speed(player.body), player.body.in_water,
		player.body.on_ground)


func _state_for(key: int, feet: Vector3) -> Dictionary:
	if not _body_state.has(key):
		_body_state[key] = {"pos": feet, "accum": 0.0, "in_water": false, "cd": 0.0}
	return _body_state[key]


static func _planar_speed(body: VoxelBody) -> float:
	return Vector3(body.velocity.x, 0.0, body.velocity.z).length()


## Um tick de lavra a cada 0,3 s de barra andando; trocar de alvo recomeca o
## intervalo, senao o segundo bloco herdaria o resto do som do primeiro.
func _mining_ticks(delta: float) -> void:
	if not player.target_valid or player.mining_progress <= 0.0:
		_dig_cd = DIG_TICK_SECONDS
		_dig_target = player.target_voxel
		return
	if player.target_voxel != _dig_target:
		_dig_target = player.target_voxel
		_dig_cd = DIG_TICK_SECONDS
	_dig_cd -= delta
	if _dig_cd > 0.0:
		return
	_dig_cd = DIG_TICK_SECONDS
	var material := _material_of(world.get_block(player.target_voxel))
	if material != "":
		_sfx("dig_%s" % material, _center(player.target_voxel))


func _wolves_stride(delta: float) -> void:
	if not wolves_provider.is_valid():
		return
	var live := {}
	for w in wolves_provider.call():
		var wolf: Wolf = w
		var st := _state_for(wolf.identity, wolf.body.feet_pos)
		live[wolf.identity] = true
		_stride(st, wolf.body.feet_pos, _planar_speed(wolf.body), wolf.body.in_water,
			wolf.body.on_ground)
		_vocalize(wolf, st, delta)
	for key in _body_state.keys():
		if int(key) != -1 and not live.has(key):
			_body_state.erase(key)


## Uivo e latido vem do intent real do lobo, com cooldown proprio: o latido e perto
## e curto, o uivo e raro e unico por janela -- a matriz global evita o coro.
func _vocalize(wolf: Wolf, st: Dictionary, delta: float) -> void:
	if not wolf.alive:
		return
	st["cd"] = maxf(float(st["cd"]) - delta, 0.0)
	var here := wolf.center()
	if wolf.intent == "hunt":
		if here.distance_to(player.position3()) > BARK_RANGE or float(st["cd"]) > 0.0:
			return
		st["cd"] = BARK_COOLDOWN * _rng.randf_range(0.7, 1.4)
		_sfx(String(EVENTS["bark"]), here)
		return
	if wolf.intent != "patrol" and wolf.intent != "investigate":
		return
	if _howl_cd > 0.0 or float(st["cd"]) > 0.0:
		return
	st["cd"] = HOWL_COOLDOWN * 0.5
	_howl_cd = HOWL_COOLDOWN * _rng.randf_range(0.6, 1.0)
	_sfx(String(EVENTS["howl"]), here)


# ------------------------------------------------------------------ cama ambiental

## Uma vez por segundo, 7x7 blocos ao redor dos pes, na camada que o corpo ocupa e
## na de baixo: flutuando a agua esta na camada do pe, na margem ela esta embaixo.
## Sao 98 leituras por avaliacao, nao por frame.
func _pick_ambience() -> void:
	var feet := player.body.feet_pos
	var cx := int(floorf(feet.x))
	var cz := int(floorf(feet.z))
	var cy := int(floorf(feet.y))
	var here := _count_blocks(cx, cy, cz)
	var below := _count_blocks(cx, cy - 1, cz)
	var water := maxi(here[0], below[0])
	var snow := maxi(here[1], below[1])
	if water >= AMBIENCE_WATER_BLOCKS:
		_set_bed(String(AMBIENCE["water"]))
	elif snow >= AMBIENCE_SNOW_BLOCKS:
		_set_bed(String(AMBIENCE["snow"]))
	else:
		_set_bed(String(AMBIENCE["open"]))


## [agua, neve] na camada y ao redor de (x,z).
func _count_blocks(cx: int, cy: int, cz: int) -> Array:
	var water := 0
	var snow := 0
	for dx in range(-AMBIENCE_SCAN_RADIUS, AMBIENCE_SCAN_RADIUS + 1):
		for dz in range(-AMBIENCE_SCAN_RADIUS, AMBIENCE_SCAN_RADIUS + 1):
			var b := world.get_block_xyz(cx + dx, cy, cz + dz)
			if b == BlockDefs.Block.WATER:
				water += 1
			elif b == BlockDefs.Block.SNOW:
				snow += 1
	return [water, snow]


func _set_bed(family: String) -> void:
	if family == _bed or family == _pending:
		return
	if _fade_left > 0.0:
		_pending = family
		return
	_switch_bed(family)


func _switch_bed(family: String) -> void:
	var slot := 0
	if _bed_slot >= 0:
		_bed_out = _bed_slot
		_bed_gain_out = _beds[_bed_out].volume_db
		_fade_left = AMBIENCE_FADE_SECONDS
		slot = 1 - _bed_out
	_begin_bed(family, slot)


func _begin_bed(family: String, slot: int) -> void:
	var path := choose(family)
	if path == "":
		return
	var stream: AudioStream = load(path)
	var b := _beds[slot]
	b.stream = stream
	_bed_gain_in = gain_db(path) + AMBIENCE_TRIM_DB
	b.volume_db = _bed_gain_in if _bed_out < 0 else -80.0
	b.play()
	_bed = family
	_bed_slot = slot
	_record(family, path)


## Crossfade de 0,7 s entre as duas camas: um corte seco num loop de ~6 s seria
## audivel como clique.
func _update_bed(delta: float) -> void:
	if _fade_left <= 0.0:
		return
	_fade_left = maxf(_fade_left - delta, 0.0)
	var t := 1.0 - _fade_left / AMBIENCE_FADE_SECONDS
	_beds[_bed_out].volume_db = lerpf(_bed_gain_out, -80.0, t)
	_beds[_bed_slot].volume_db = lerpf(-80.0, _bed_gain_in, t)
	if _fade_left > 0.0:
		return
	_beds[_bed_out].stop()
	_bed_out = -1
	if _pending != "" and _pending != _bed:
		var target := _pending
		_pending = ""
		_switch_bed(target)
