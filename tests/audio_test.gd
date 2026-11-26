extends SceneTree
## Teste do audio: o set tocavel, o ganho que sai da medicao, o roteamento de buses
## e o contrato de que som nao escreve mundo.
##
## Roda com o driver Dummy do headless, medido aqui: `playing` vira true e a
## posicao de playback nao avanca. Entao a prova e de tratamento de evento e de
## estado, nao de alto-falante -- quem quer ouvir abre a janela.

const Main = preload("res://src/main.gd")
const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")
const ROOT := "res://assets/audio/"
const LEVELS_PATH := ROOT + "levels.json"
## O censo do set medido em docs/audio-provenance.md: 51 arquivos, 27 familias.
const EXPECTED_FILES: int = 51
const EXPECTED_FAMILIES: int = 27
const WALK_FRAMES: int = 120
const DIG_SECONDS: float = 1.2
const TESTS: Array[StringName] = [
	&"_test_data", &"_test_tables", &"_test_mix", &"_test_pick",
	&"_test_consumers", &"_test_cadence",
]
# 16 dados + 13 tabelas + 15 mix + 5 sorteio + 10 consumidores + 14 cadencia,
# contados na corrida que passou (a primeira mediu 69 porque o ramo de agua era
# condicional e nao existe lago na premissa que eu tinha escrito).
const EXPECTED_CHECKS: int = 73

var _checks: int = 0
var _failures: int = 0
var _completed: int = 0
var _started_us: int = 0
var _mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _data := {}
var _audio: AudioDirector = null
var _main: Main = null


func _initialize() -> void:
	_started_us = Time.get_ticks_usec()
	_mouse_mode = Input.mouse_mode
	_run.call_deferred()
	_finish.call_deferred()


func _run() -> void:
	for test_name: StringName in TESTS:
		if call(test_name) != true:
			_failures += 1
			push_error("ABORTOU %s: nao devolveu true" % test_name)
			break
		_completed += 1


func _check(ok: bool, label: String, detail: String = "") -> bool:
	_checks += 1
	print("%s %s %s" % ["OK" if ok else "FALHA", label, detail])
	if not ok:
		_failures += 1
	return ok


# ------------------------------------------------------------------ o set medido

func _test_data() -> bool:
	_audio = AudioDirector.new()
	root.add_child(_audio)
	if not _check(_audio.is_node_ready() and _audio.player == null,
			"diretor fora da sessao tambem carrega sozinho", "ready=%s" % _audio.is_node_ready()):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_PATH))
	if not _check(typeof(parsed) == TYPE_DICTIONARY, "levels.json e um objeto JSON", "tipo=%s" % typeof(parsed)):
		return false
	_data = parsed
	_check(_data.size() == EXPECTED_FILES, "%d arquivos medidos no set" % EXPECTED_FILES,
			"entradas=%d" % _data.size())
	var missing: Array = []
	var unloadable: Array = []
	for key in _data:
		var path := ROOT + String(key)
		if not ResourceLoader.exists(path):
			missing.append(String(key))
		elif load(path) == null:
			unloadable.append(String(key))
	_check(missing.is_empty(), "todo caminho medido existe em res://", "faltando=" + str(missing))
	_check(unloadable.is_empty(), "todo arquivo do set carrega", "ruim=" + str(unloadable))
	for pair in [["sfx/step_grass_2.ogg", "step_grass"], ["sfx/ui_click.ogg", "ui_click"],
			["amb/amb_birds.ogg", "amb_birds"], ["sfx/wolf_bark_1.ogg", "wolf_bark"],
			["sfx/place_1.ogg", "place"], ["sfx/hit_flesh_3.ogg", "hit_flesh"],
			["sfx/swing_2.wav", "swing"], ["sfx/dig_soft_1.ogg", "dig_soft"]]:
		_check(AudioDirector.family_of(pair[0]) == pair[1], "familia derivada de %s" % pair[0],
				"esperado=%s obtido=%s" % [pair[1], AudioDirector.family_of(pair[0])])
	var fams := _audio.families()
	_check(fams.size() == EXPECTED_FAMILIES, "%d familias derivadas do medido" % EXPECTED_FAMILIES,
			"familias=%d" % fams.size())
	var total := 0
	for f in fams:
		total += (fams[f] as Array).size()
	_check(total == EXPECTED_FILES, "as familias somam os 51 arquivos sem sobrepor", "somatorio=%d" % total)
	_check(_audio.diagnostics()["levels"] == EXPECTED_FILES and _audio.diagnostics()["voices"] == AudioDirector.VOICES,
			"diagnostico expoe censo e pool", "%s" % _audio.diagnostics())
	return true


# ------------------------------------------------------------------ tabelas x arquivos

func _test_tables() -> bool:
	var fams := _audio.families()
	var refs: Array = _audio.referenced_families()
	var idle: Array = []
	for f in fams:
		if not refs.has(f):
			idle.append(f)
	var absent: Array = []
	for f in refs:
		if not fams.has(f):
			absent.append(f)
	_check(idle.is_empty(), "nenhuma familia medida fica sem uso", "ociosa=" + str(idle))
	_check(absent.is_empty(), "nenhuma tabela aponta familia sem arquivo",
			"sem arquivo=" + str(absent))
	for pair in [["step_grass", 3], ["step_stone", 3], ["dig_soft", 2], ["break_glass", 2],
			["hit_flesh", 3], ["swing", 2], ["amb_birds", 1], ["wolf_howl", 1]]:
		_check((fams[pair[0]] as Array).size() == pair[1],
				"%s tem %d variantes" % [pair[0], pair[1]],
				"%d" % (fams[pair[0]] as Array).size())
	var no_material: Array = []
	var no_step: Array = []
	for b in BlockDefs.Block.values():
		if b == BlockDefs.Block.AIR or b == BlockDefs.Block.WATER:
			continue
		if not _audio.MATERIAL_FAMILY.has(b):
			no_material.append(b)
		if not _audio.STEP_FAMILY.has(b):
			no_step.append(b)
	_check(no_material.is_empty(), "todo bloco solido tem classe de lavra",
			"sem classe=" + str(no_material))
	_check(no_step.is_empty(), "todo bloco solido tem familia de passo", "sem passo=" + str(no_step))
	_check(not _audio.MATERIAL_FAMILY.has(BlockDefs.Block.WATER)
			and not _audio.STEP_FAMILY.has(BlockDefs.Block.WATER),
			"agua fica fora das tabelas de bloco: quem responde e o splash", "")
	return true


# ------------------------------------------------------------------ mixagem

func _test_mix() -> bool:
	var fams := _audio.families()
	var wrong: Array = []
	var clamped_high: Array = []
	var clamped_low: Array = []
	var silent: Array = []
	for f in fams:
		for path in fams[f]:
			var rel := String(path).trim_prefix(ROOT)
			var got: float = _audio.gain_db(path)
			var want := clampf(AudioDirector.MIX_TARGET_DB - float(_data[rel]),
					-AudioDirector.GAIN_CLAMP_DB, AudioDirector.GAIN_CLAMP_DB)
			if absf(got - want) > 0.0001:
				wrong.append("%s ganho=%.2f esperado=%.2f" % [rel, got, want])
			if absf(got - AudioDirector.GAIN_CLAMP_DB) < 0.0001:
				clamped_high.append(rel)
			elif absf(got + AudioDirector.GAIN_CLAMP_DB) < 0.0001:
				clamped_low.append(rel)
			if load(path).get_length() <= 0.0:
				silent.append(rel)
	_check(wrong.is_empty(), "ganho == alvo - nivel medio medido no arquivo",
			"divergindo=" + str(wrong))
	clamped_high.sort()
	var below_cut: Array = []
	for key in _data:
		if float(_data[key]) < AudioDirector.MIX_TARGET_DB - AudioDirector.GAIN_CLAMP_DB:
			below_cut.append(String(key))
	below_cut.sort()
	# A lista esperada sai do mesmo `levels.json` que o ganho, nao de dois nomes que
	# eu decorei: na primeira corrida ela tinha `splash_1` (-33,9) dentro e o teste
	# passou a cobrar um teto que nenhum arquivo alcancar.
	_check(clamped_high == below_cut and not below_cut.is_empty(),
			"o teto de ganho so alcanca quem foi medido abaixo do corte",
			"no teto=" + str(clamped_high) + " abaixo de "
			+ str(AudioDirector.MIX_TARGET_DB - AudioDirector.GAIN_CLAMP_DB) + "=" + str(below_cut))
	_check(clamped_low.is_empty(), "nenhum arquivo e cortado por estar alto demais",
			"no chao=" + str(clamped_low))
	_check(silent.is_empty(), "todo arquivo tem duracao positiva no motor", "zerada=" + str(silent))
	var names: Array = []
	for i in AudioServer.get_bus_count():
		names.append(AudioServer.get_bus_name(i))
	for n in ["Master", "SFX", "Ambience", "UI"]:
		_check(names.has(n), "bus %s existe no layout" % n, "names=" + str(names))
	for n in ["SFX", "Ambience", "UI"]:
		var idx := AudioServer.get_bus_index(n)
		_check(AudioServer.get_bus_send(idx) == "Master", "%s envia ao Master" % n,
				"send=%s" % AudioServer.get_bus_send(idx))
	for f in ["amb_birds", "amb_wind", "amb_water"]:
		var bed: AudioStreamOggVorbis = load((fams[f] as Array)[0])
		_check(bed.get("loop") == true, "bed %s importa em loop" % f,
				"loop=%s dur=%.3f" % [bed.get("loop"), bed.get_length()])
	var looping: Array = []
	for f in fams:
		if String(f).begins_with("amb"):
			continue
		for path in fams[f]:
			var s: AudioStream = load(path)
			if s is AudioStreamOggVorbis and s.get("loop"):
				looping.append(path)
			elif s is AudioStreamWAV and s.get("loop_mode") != AudioStreamWAV.LOOP_DISABLED:
				looping.append(path)
	_check(looping.is_empty(), "nenhum sfx importa em loop", "em loop=" + str(looping))
	return true


# ------------------------------------------------------------------ sorteio de variante

func _test_pick() -> bool:
	var a := AudioDirector.new()
	var b := AudioDirector.new()
	root.add_child(a)
	root.add_child(b)
	var seq_a: Array = []
	var seq_b: Array = []
	for i in 12:
		seq_a.append(a.choose("step_grass"))
		seq_b.append(b.choose("step_grass"))
	_check(seq_a == seq_b, "a semente de audio reproduz a sequencia de variantes",
			"iguais=%s" % (seq_a == seq_b))
	var distinct := {}
	var off_pool := 0
	var pool: Array = _audio.families()["step_grass"]
	for path in seq_a:
		distinct[path] = true
		if not pool.has(path):
			off_pool += 1
	_check(off_pool == 0, "sorteio so devolve arquivo da propria familia", "fora=%d" % off_pool)
	_check(distinct.size() == 3, "12 sorteios entre 3 variantes mostram as tres",
			"distintas=%d" % distinct.size())
	var bad_gain: Array = []
	for path in seq_a:
		if not _data.has(String(path).trim_prefix(ROOT)):
			bad_gain.append(path)
	_check(bad_gain.is_empty(), "o caminho sorteado tem nivel medido", "sem nivel=" + str(bad_gain))
	_check(a.gain_db(seq_a[0]) == _audio.gain_db(seq_a[0]), "o ganho depende so do arquivo",
			"%.3f" % a.gain_db(seq_a[0]))
	a.queue_free()
	b.queue_free()
	return true


# ------------------------------------------------------------------ consumidor de eventos

func _test_consumers() -> bool:
	_main = MAIN_SCENE.instantiate() as Main
	# Congelado: quem da o passo no audio e o teste, e nada alem do audio roda entre
	# os dois hashes que comparam.
	_main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_main)
	var a := _main.audio
	if not _check(a != null and a.is_node_ready() and a.world == _main.world
			and a.player == _main.player and a.wolves_provider.is_valid(),
			"sessao real traz diretor ligado a mundo, jogador e matilha",
			"audio=%s lobos=%d" % [a, _main.wolves.size()]):
		return false
	var p := _main.player
	var wired := [
		p.block_broken.is_connected(a.on_block_broken),
		p.block_placed.is_connected(a.on_block_placed),
		p.attacked.is_connected(a._on_attacked),
		p.damaged.is_connected(a._on_player_damaged),
		p.died.is_connected(a._on_player_died),
		p.panel_changed.is_connected(a._on_panel_changed),
	]
	var unwired := 0
	for w in wired:
		if not w:
			unwired += 1
	_check(unwired == 0, "os seis sinais do jogador ja chegam ao diretor", "sem conexao=%d" % unwired)
	var wolf_wired := 0
	for w in _main.wolves:
		if w.bit_player.is_connected(a._on_wolf_bit) and w.wounded.is_connected(a._on_wolf_wounded) \
				and w.died.is_connected(a._on_wolf_died):
			wolf_wired += 1
	_check(wolf_wired == _main.wolves.size(), "cada lobo do spawn entrega seus tres sinais ao diretor",
			"ligados=%d/%d" % [wolf_wired, _main.wolves.size()])
	# Censo variavel (dossie 14 §3.5): o predicado de spawn pode recusar todos os
	# pontos e a matilha borna vir vazia. Sem corpo na matriz, os eventos abaixo
	# seriam SCRIPT ERROR -- e o erro derruba em silencio as checagens do passo.
	if _main.wolves.is_empty():
		_check(false, "o boot deixou um lobo para os consumidores", "lobos=0")
		return false

	var hash0 := _main.state_hash()
	var hp0 := p.hp
	var edits0 := _main.world.edits.size()
	var mined0 := int(_main.stats["mined"])
	var wolf_states: Array = []
	for w in _main.wolves:
		wolf_states.append(w._rng.state)
	var population_state := _main._population_rng.state
	var played0 := a.events_played
	a.on_block_broken(Vector3i(64, 30, 64), BlockDefs.Block.STONE)
	a.on_block_placed(Vector3i(64, 31, 64), BlockDefs.Block.PLANK)
	a._on_attacked(_main.wolves[0], 7.0)
	a._on_player_damaged(9.0, p.position3())
	a._on_player_died(p.position3())
	a._on_panel_changed(true)
	a._on_wolf_bit(_main.wolves[0], 8.5)
	a._on_wolf_wounded(_main.wolves[0], 5.0)
	a._on_wolf_died(_main.wolves[0], _main.wolves[0].center())
	var touched := 9
	_check(a.events_played == played0 + touched, "os nove eventos tem toque proprio",
			"antes=%d depois=%d" % [played0, a.events_played])
	_check(_main.state_hash() == hash0, "audio nao move o hash autoritativo do tick",
			"%s -> %s" % [hash0.substr(0, 12), _main.state_hash().substr(0, 12)])
	var states_ok := true
	for i in _main.wolves.size():
		if _main.wolves[i]._rng.state != wolf_states[i]:
			states_ok = false
	_check(states_ok, "audio nao consome a RNG de nenhum lobo", "lobos=%d" % _main.wolves.size())
	_check(_main._population_rng.state == population_state, "audio nao consome a RNG da populacao", "")
	_check(p.hp == hp0 and _main.world.edits.size() == edits0
			and int(_main.stats["mined"]) == mined0,
			"o consumidor nao escreve vida, voxel nem contador de lavra",
			"hp=%.1f edits=%d mined=%d" % [p.hp, _main.world.edits.size(), _main.stats["mined"]])
	var expected := {
		"break_stone": true, "place": true, "swing": true, "hit_flesh": true,
		"player_die": true, "ui_click": true, "wolf_roar": true, "wolf_hurt": true,
		"wolf_die": true,
	}
	var unheard: Array = []
	for f in expected:
		if not a.family_played.has(f):
			unheard.append(f)
	_check(unheard.is_empty(), "cada familia chamada pelo evento apareceu no registro", "muda=" + str(unheard))
	_check(not _main.world.edits.has(Vector3i(64, 30, 64)),
			"quebrar no audio nao criou edicao no mundo", "voxel=%d" % _main.world.get_block(Vector3i(64, 30, 64)))
	return true


# ------------------------------------------------------------------ cadencia de corpo

func _test_cadence() -> bool:
	var a := _main.audio
	var p := _main.player
	var w := _main.world
	# Passos: andar de verdade, com input e integrador do jogador -- nao escrever
	# posicao na mao, que e justamente o que a regra de premissa proibe.
	p.feet_to_spawn(_main.spawn_point())
	p.yaw = 0.62
	var st := a._state_for(-1, p.body.feet_pos)
	st["pos"] = p.body.feet_pos
	st["accum"] = 0.0
	st["in_water"] = false
	var steps0 := _count_steps(a)
	var walked := 0.0
	var grounded := 0
	Input.action_press("move_forward")
	for i in WALK_FRAMES:
		# `before` ANTES de `update_local`: quem move o corpo e o jogador, e o audio
		# so le a posicao resultante no mesmo frame.
		var before := p.body.feet_pos
		p.update_local(1.0 / 60.0)
		a.update_audio(1.0 / 60.0)
		grounded += int(p.body.on_ground)
		walked += Vector3(p.body.feet_pos.x - before.x, 0.0, p.body.feet_pos.z - before.z).length()
	Input.action_release("move_forward")
	var steps := _count_steps(a) - steps0
	var surface := a._surface_block(p.body.feet_pos)
	var expect_family := String(a.STEP_FAMILY.get(surface, ""))
	# A premissa e "andou apoiado", nao "no ultimo frame do lote o corpo estava
	# apoiado": desde o auto-pulo do degrau (dossie 19) caminhar do spawn para frente
	# salta uma celula no meio do caminho, e a amostra de um frame so media paridade
	# de frame -- na base desta branch ela dava `no_chao=false` com quatro passos
	# tocados (docs/evidence/audio/cadence-red-on-base-7d44230.log). Medido na
	# corrida que qutou o verde: 112 de 120 quadros com o corpo apoiado
	# (docs/evidence/audio/cadence-green-on-fix.log).
	_check(steps > 0 and grounded > WALK_FRAMES / 2, "andar no chao produz passo",
			"passos=%d no_chao=%d/%d" % [steps, grounded, WALK_FRAMES])
	_check(absf(float(steps) - walked / AudioDirector.STRIDE_METERS) <= 1.0,
			"cadencia do passo == distancia / passo", "passos=%d metros=%.2f esperado=%.2f" % [
			steps, walked, walked / AudioDirector.STRIDE_METERS])
	_check(a.family_played.has(expect_family) or expect_family == "",
			"o passo sorteado vem do bloco sob os pes", "bloco=%d familia=%s" % [surface, expect_family])
	var still0 := _count_steps(a)
	for i in 30:
		p.update_local(1.0 / 60.0)
		a.update_audio(1.0 / 60.0)
	_check(_count_steps(a) == still0, "parar de andar calca os passos", "novos=%d" % (_count_steps(a) - still0))

	# Lavra: o tick sai da barra de progresso real do jogador. O bloco pode quebrar
	# no meio da janela -- a dureza e do terreno, nao minha -- entao a cadencia se
	# cobra por faixa, nao por numero exato.
	p.yaw = 0.0
	_aim(p, -0.9)
	_check(p.target_valid, "mira travada num bloco para a lavra", "voxel=%s dureza=%.2f" % [
		p.target_voxel, p.target_hardness])
	var dig_family := "dig_%s" % a._material_of(w.get_block(p.target_voxel))
	var dig0 := _family_count(a, dig_family)
	Input.action_press("break_block")
	var dig_frames := int(DIG_SECONDS * 60.0)
	for i in dig_frames:
		p.update_local(1.0 / 60.0)
		a.update_audio(1.0 / 60.0)
	Input.action_release("break_block")
	var dig_ticks := _family_count(a, dig_family) - dig0
	var cadence := DIG_SECONDS / AudioDirector.DIG_TICK_SECONDS
	_check(dig_ticks >= 2 and dig_ticks <= ceilf(cadence),
			"lavrando produz tick de lavra na cadencia, nao por frame", "ticks=%d em %.2f s (%s)" % [
			dig_ticks, DIG_SECONDS, dig_family])
	_check(dig_ticks <= int(cadence) + 1, "o intervalo de 0,3 s nao encolhe sozinho",
			"ticks=%d teto=%d" % [dig_ticks, int(cadence) + 1])

	# Agua: uma coluna alagada DO mapa gerado, e o corpo deixado assentar por
	# `update_local` -- `in_water` sai do integrador, nao da coordenada.
	var spot := _find_water_column(w)
	_check(not spot.is_empty(), "o mapa gerado tem lago para o teste de splash", str(spot))
	p.feet_to_spawn(Vector3(float(spot["x"]) + 0.5, float(spot["y"]) + 0.5, float(spot["z"]) + 0.5))
	var splash0 := _family_count(a, "splash")
	for i in 24:
		p.update_local(1.0 / 60.0)
		a.update_audio(1.0 / 60.0)
	_check(p.body.in_water, "corpo dentro da coluna fica em agua", "feet=%s" % p.body.feet_pos)
	_check(_family_count(a, "splash") > splash0, "entrar na agua toca splash", "splash=%d" % (
		_family_count(a, "splash") - splash0))
	a._pick_ambience()
	_check(a.diagnostics()["bed"] == "amb_water", "a cama troca para agua perto de agua",
			"bed=%s contagem=%s" % [a.diagnostics()["bed"],
			str(a._count_blocks(int(floorf(p.body.feet_pos.x)), int(floorf(p.body.feet_pos.y)),
					int(floorf(p.body.feet_pos.z))))])
	var sounding := 0
	for b in a._beds:
		if b.playing:
			sounding += 1
	_check(sounding == 2, "crossfade deixa as duas camas vivas durante a troca", "tocando=%d" % sounding)

	# Matilha: passo e vocalizacao andam com o corpo e com o intent reais.
	Input.action_press("move_forward")
	for i in 120:
		for wolf in _main.wolves:
			wolf._physics_process(1.0 / 60.0)
		a.update_audio(1.0 / 60.0)
	Input.action_release("move_forward")
	_check(a._body_state.size() == _main.wolves.size() + 1,
			"um registro de corpo por lobo da lista mais o jogador", "registros=%d lobos=%d" % [
			a._body_state.size(), _main.wolves.size()])
	a.clear_transient()
	_check(a._body_state.is_empty(), "clear_transient limpa o transitorio no load",
			"chaves=%d" % a._body_state.size())
	return true


func _count_steps(a: AudioDirector) -> int:
	var n := 0
	for f in a.family_played:
		if String(f).begins_with("step_"):
			n += int(a.family_played[f])
	return n


func _family_count(a: AudioDirector, family: String) -> int:
	return int(a.family_played.get(family, 0))


func _aim(p: Player, pitch: float) -> void:
	p.pitch = pitch
	p.update_local(1.0 / 60.0)
	p.update_local(1.0 / 60.0)


## Coluna alagada do mapa gerado, escolhida pela mesma janela que `_pick_ambience`
## varre: a camada do mar ali tem que ter agua suficiente para a cama de agua, senao
## a premissa do teste nao existe. A agua do gen v3 vai do leito ate SEA_LEVEL
## INCLUSIVE -- medir no seed da sessao deu 12.418 voxels em 2.044 colunas; cobrar
## `y > SEA_LEVEL` nunca acharia nada, e foi o que aconteceu na primeira corrida.
func _find_water_column(w: VoxelWorld) -> Dictionary:
	var y := VoxelConfig.SEA_LEVEL
	var half: int = int(VoxelConfig.world_size_x() * 0.5)
	for radius in range(2, half - 2):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dz) != radius:
					continue
				var x := half + dx
				var z := half + dz
				if w.get_block_xyz(x, y, z) != BlockDefs.Block.WATER:
					continue
				if _water_patch(w, x, y, z) < AudioDirector.AMBIENCE_WATER_BLOCKS:
					continue
				# Duas camadas continuas: o corpo afunda um pouco ao assentar e a
				# premissa da cama de agua tem de valer na camada em que ele parar.
				if _water_patch(w, x, y - 1, z) < AudioDirector.AMBIENCE_WATER_BLOCKS:
					continue
				return {"x": x, "y": y, "z": z}
	return {}


func _water_patch(w: VoxelWorld, cx: int, cy: int, cz: int) -> int:
	var n := 0
	for dx in range(-AudioDirector.AMBIENCE_SCAN_RADIUS, AudioDirector.AMBIENCE_SCAN_RADIUS + 1):
		for dz in range(-AudioDirector.AMBIENCE_SCAN_RADIUS, AudioDirector.AMBIENCE_SCAN_RADIUS + 1):
			if w.get_block_xyz(cx + dx, cy, cz + dz) == BlockDefs.Block.WATER:
				n += 1
	return n


func _finish() -> void:
	Input.mouse_mode = _mouse_mode
	var elapsed := float(Time.get_ticks_usec() - _started_us) / 1000000.0
	print("== testes completos %d/%d ==" % [_completed, TESTS.size()])
	if _completed < TESTS.size():
		_failures += 1
		push_error("runner parou no teste %d de %d" % [_completed, TESTS.size()])
	if _checks != EXPECTED_CHECKS:
		_failures += 1
		push_error("censo de checagens: %d em vez de %d" % [_checks, EXPECTED_CHECKS])
	print("%d checagens  %d falhas  %.3f s" % [_checks, _failures, elapsed])
	quit(1 if _failures > 0 else 0)
