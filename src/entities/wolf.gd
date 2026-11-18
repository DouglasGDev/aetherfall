class_name Wolf
extends Node3D
## Mente local completa (docs/design/04): percepcao via campo de Eter (O(1), sem
## raycast por frame) -> utilidade escolhe a acao -> Behavior Tree executa -> memoria
## grava o que aconteceu e muda a decisao do proximo encontro.
##
## Locomocao: a patrulha so sorteia terra seca (sem agua acima do leito); se um
## estímulo levar o lobo a agua, ele boia, rema (nado como o do jogador) e depois
## de SHORE_AFTER segundos a margem mais proxima passa a mandar no rumo.
##
## Contrato com o Player: body_aabb() e target_name().

signal bit_player(wolf: Wolf, amount: float)
signal wounded(wolf: Wolf, amount: float)
signal died(wolf: Wolf, pos: Vector3)
signal acted(kind: String, pos: Vector3)

const ACTOR_PLAYER: int = 1
const MAX_HP: float = 42.0
const SPEED_WALK: float = 2.6
const SPEED_RUN: float = 5.4
const SPEED_FLEE: float = 6.1
const BITE_RANGE: float = 1.95
const BITE_DAMAGE: float = 8.5
const BITE_COOLDOWN: float = 1.15
const WANDER_RADIUS: float = 22.0
const SCENT_RADIUS: int = 3          # em celulas de Eter
const SCENT_MIN: float = 0.06
const CORPSE_SECONDS: float = 6.0
const DIMS := Vector3(0.75, 0.95, 1.35)
# agua: o lobo nao nada por lazer. A patrulha sorteia terra seca; se acabar na
# agua (fuga, perseguicao), boia e rema como o jogador nada e procura a margem.
const SWIM_SPEED_FACTOR: float = 0.55
const SWIM_BUOYANCY: float = 0.15
const SWIM_RISE: float = 1.6
const SWIM_SINK_MAX: float = -1.6
const SHORE_AFTER: float = 2.0
# golpe do jogador: empurrada + tempo sem steering (o steering normal comeria o knockback)
const STAGGER_TIME: float = 0.45
const KNOCKBACK_SPEED: float = 5.0
const KNOCKBACK_LIFT: float = 2.4

var world: VoxelWorld = null
var aether: AetherField = null
var mind: Mind = null
var body: VoxelBody = VoxelBody.new()
var identity: int = 0
var hp: float = MAX_HP
var alive: bool = true
var intent: String = "patrol"
var hunger: float = 0.35
var home := Vector3.ZERO
var kills: int = 0

var _player: Player = null
var _sim_clock: SimClock = null
var _scorer: UtilityScorer = UtilityScorer.new()
var _tree: BtTree.BtNode = null
var _guard: BtTree.SubtreeGuard = null

# percepcao: recalculada uma vez por tick de simulacao
var _dist_player: float = 999.0
var _los_player: bool = false
var _fear_here: float = 0.0
var _blood_here: float = 0.0
var _work_here: float = 0.0
var _scent_pos: Vector3 = Vector3.ZERO
var _scent_strength: float = 0.0
var _scent_found: bool = false
var _fear_level: float = 0.0
var _hp_ratio: float = 1.0
var _threat: float = 0.0
var _courage: float = 1.0
var _top_line: String = "-"

# execucao
var _move_target: Vector3 = Vector3.ZERO
var _speed: float = SPEED_WALK
var _unstick: float = 0.0
var _detour: float = 0.0
var _heading: float = 0.0
var _gait: float = 0.0
var _wander_cd: float = 0.0
var _saw_cd: float = 0.0
var _bite_cd: float = 0.0
var _corpse_timer: float = 0.0
var _swim_time: float = 0.0
var _stagger: float = 0.0
var _swim_phase: float = 0.0
var _visual: Node3D = null
var _legs: Array = []
var _fur: StandardMaterial3D = null


func setup(p_world: VoxelWorld, p_aether: AetherField, p_player: Player,
		p_spawn: Vector3, p_identity: int, p_clock: SimClock) -> void:
	world = p_world
	aether = p_aether
	_player = p_player
	_sim_clock = p_clock
	identity = p_identity
	home = p_spawn
	body.setup(world, p_spawn, DIMS)
	_heading = randf() * TAU
	mind = Mind.new("wolf", p_identity, 1000 + p_identity)
	name = "Wolf%d" % p_identity
	_move_target = p_spawn
	_build_visual()
	_build_scorer()
	_build_tree()


func body_aabb() -> AABB:
	return body.aabb()


func target_name() -> String:
	if not alive:
		return "lobo morto"
	return "lobo (%s)" % intent


func center() -> Vector3:
	return body.center()


# ------------------------------------------------------------------ arvore de comportamento

func _build_tree() -> void:
	var flee := BtTree.Sequence.new().with([
		BtTree.Condition.new().init("intento=flee", _cond_intent("flee")),
		BtTree.Action.new().init("fugir", _leaf_flee),
	])
	var hunt := BtTree.Sequence.new().with([
		BtTree.Condition.new().init("intento=hunt", _cond_intent("hunt")),
		BtTree.Selector.new().with([
			BtTree.Sequence.new().with([
				BtTree.Condition.new().init("ao alcance da mordida", _cond_range),
				BtTree.Cooldown.new().init("cd mordida",
					BtTree.Action.new().init("morder", _leaf_bite), BITE_COOLDOWN),
			]),
			BtTree.Sequence.new().with([
				BtTree.Condition.new().init("lembra da presa", _cond_hunt_memory),
				BtTree.Action.new().init("vir ao ultimo avistamento", _leaf_stalk),
			]),
			BtTree.Action.new().init("perseguir", _leaf_chase),
		]),
	])
	var sniff := BtTree.Sequence.new().with([
		BtTree.Condition.new().init("intento=investigate", _cond_intent("investigate")),
		BtTree.Condition.new().init("ha rastro", _cond_scent),
		BtTree.Action.new().init("seguir rastro", _leaf_investigate),
	])
	var patrol := BtTree.Action.new().init("patrulhar", _leaf_wander)
	_guard = BtTree.SubtreeGuard.new().init("mente.lobo",
		BtTree.Selector.new().with([flee, hunt, sniff, patrol]), 400)
	_tree = _guard


func _cond_intent(p_intent: String) -> Callable:
	return func(_ctx: Dictionary) -> bool: return intent == p_intent


func _cond_range(_ctx: Dictionary) -> bool:
	return alive and _los_player and _dist_player <= BITE_RANGE


func _cond_hunt_memory(_ctx: Dictionary) -> bool:
	return mind.believes("player_visible_recent") or mind.believes("prey_wounded")


func _cond_scent(_ctx: Dictionary) -> bool:
	return _scent_found


# ------------------------------------------------------------------ folhas

func _leaf_flee(_ctx: Dictionary) -> bool:
	var away := center() - _player.position3()
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(0.0, 0.0, 1.0)
	_move_target = center() + away.normalized() * 14.0
	_speed = SPEED_FLEE
	# fugir espalha medo: e assim que um lobo avisa os outros sem nenhum canal de rede
	aether.imprint(center(), AetherField.Channel.FEAR, 0.06)
	return true


func _leaf_chase(_ctx: Dictionary) -> bool:
	_move_target = _player.position3() + Vector3(0.0, 0.4, 0.0)
	_speed = SPEED_RUN if _dist_player > 6.0 else SPEED_WALK
	return true


func _leaf_stalk(_ctx: Dictionary) -> bool:
	var atom: Dictionary = mind.last_atom("saw_player")
	if atom.is_empty():
		return false
	_move_target = atom["pos"]
	_speed = SPEED_WALK
	return center().distance_squared_to(_move_target) > 2.25


func _leaf_investigate(_ctx: Dictionary) -> bool:
	_move_target = _scent_pos
	_speed = SPEED_WALK
	return center().distance_squared_to(_move_target) > 1.44


func _leaf_wander(_ctx: Dictionary) -> bool:
	_speed = SPEED_WALK
	if _wander_cd > 0.0 and center().distance_squared_to(_move_target) > 2.0:
		return true
	_wander_cd = randf_range(4.0, 9.0)
	for _t in 8:
		var a := randf() * TAU
		var r := randf_range(5.0, WANDER_RADIUS)
		var p := home + Vector3(cos(a) * r, 0.0, sin(a) * r)
		p.x = clampf(p.x, 4.0, float(VoxelConfig.world_size_x()) - 4.0)
		p.z = clampf(p.z, 4.0, float(VoxelConfig.world_size_z()) - 4.0)
		if not _dry_ground(p):
			continue
		p.y = float(world.surface_height(int(p.x), int(p.z))) + 0.2
		_move_target = p
		return true
	return true


## Terra seca neste ponto: sem agua acima do leito na coluna.
func _dry_ground(p: Vector3) -> bool:
	var b := Coords.to_block(p)
	if b.x < 1 or b.z < 1 or b.x >= VoxelConfig.world_size_x() - 1 or b.z >= VoxelConfig.world_size_z() - 1:
		return false
	return not world.is_water_xyz(b.x, world.surface_height(b.x, b.z) + 1, b.z)


## Ponto de margem mais proximo: raio crescente em 8 direcoes, primeira coluna seca.
func _shore_point() -> Vector3:
	var me := body.feet_pos
	for r in [1.6, 2.6, 4.0, 6.0, 8.0]:
		for i in 8:
			var a := TAU * float(i) / 8.0 + 0.3
			var p := me + Vector3(cos(a) * r, 0.0, sin(a) * r)
			if _dry_ground(p):
				var b := Coords.to_block(p)
				p.y = float(world.surface_height(b.x, b.z)) + 0.2
				return p
	return me


func _leaf_bite(_ctx: Dictionary) -> bool:
	if _bite_cd > 0.0:
		return false
	_bite_cd = BITE_COOLDOWN
	bit_player.emit(self, BITE_DAMAGE)
	var pp := _player.position3()
	aether.imprint(pp, AetherField.Channel.BLOOD, 0.18)
	mind.remember(_sim_clock.tick, "hit_land", pp, ACTOR_PLAYER, 0.3)
	mind.reinforce("prey_wounded", 0.22, "perception")
	return true


# ------------------------------------------------------------------ decisao por utilidade

func _build_scorer() -> void:
	_scorer.min_lead = 0.05
	_scorer.min_interval = 0.6

	var flee := _scorer.add_option("flee")
	flee.add("terror no ar", func(_c: Dictionary) -> float: return _fear_level,
			0.0, 1.0, ResponseCurve.Type.SIGMOID, 9.0, 0.42, 1.7, false)
	flee.add("cautela", func(_c: Dictionary) -> float: return mind.temperament("caution"),
			0.0, 1.0, ResponseCurve.Type.LINEAR, 1.0, 0.0, 0.9, false)
	flee.add("ferido", func(_c: Dictionary) -> float: return 1.0 - _hp_ratio,
			0.0, 1.0, ResponseCurve.Type.QUADRATIC, 1.0, 0.0, 1.5, false)
	flee.add("ameaca recente", func(_c: Dictionary) -> float: return _threat,
			0.0, 1.0, ResponseCurve.Type.SATURATING, 3.0, 0.0, 1.2, false)
	flee.add("ainda de pe", func(_c: Dictionary) -> float: return _hp_ratio,
			0.01, 0.02, ResponseCurve.Type.LINEAR, 1.0, 0.0, 0.0, true)

	var hunt := _scorer.add_option("hunt")
	hunt.add("fome", func(_c: Dictionary) -> float: return hunger,
			0.25, 1.0, ResponseCurve.Type.LINEAR, 1.0, 0.0, 1.4, false)
	hunt.add("agressao", func(_c: Dictionary) -> float: return mind.temperament("aggression"),
			0.0, 1.0, ResponseCurve.Type.LINEAR, 1.0, 0.0, 1.0, false)
	hunt.add("alvo a vista", func(_c: Dictionary) -> float: return 1.0 if _los_player else 0.0,
			0.0, 1.0, ResponseCurve.Type.STEP, 1.0, 0.0, 1.5, false)
	# faixa invertida (hi < lo): longe pontua zero, perto pontua 1.
	hunt.add("proximidade", func(_c: Dictionary) -> float: return _dist_player,
			26.0, 0.0, ResponseCurve.Type.LINEAR, 1.0, 0.0, 1.1, false)
	hunt.add("coragem contra este ator", func(_c: Dictionary) -> float: return _courage,
			0.5, 1.0, ResponseCurve.Type.LINEAR, 1.0, 0.0, 0.0, true)

	var sniff := _scorer.add_option("investigate")
	sniff.add("sangue no ar", func(_c: Dictionary) -> float: return _scent_strength,
			0.05, 1.0, ResponseCurve.Type.SATURATING, 2.4, 0.0, 1.6, false)
	sniff.add("curiosidade", func(_c: Dictionary) -> float: return mind.temperament("curiosity"),
			0.0, 1.0, ResponseCurve.Type.LINEAR, 1.0, 0.0, 0.9, false)
	sniff.add("sem pressa", func(_c: Dictionary) -> float: return 1.0 - _fear_level,
			0.0, 1.0, ResponseCurve.Type.LINEAR, 1.0, 0.0, 0.8, false)
	sniff.add("ha rastro", func(_c: Dictionary) -> float: return _scent_strength,
			SCENT_MIN, SCENT_MIN + 0.02, ResponseCurve.Type.LINEAR, 1.0, 0.0, 0.0, true)

	# chao de fundo: patrulha vale pouco de proposito, para perder de qualquer
	# estimulo real sem precisar de pesos negativos.
	var patrol := _scorer.add_option("patrol")
	patrol.add("nada melhor a fazer", func(_c: Dictionary) -> float: return 0.22,
			0.0, 1.0, ResponseCurve.Type.LINEAR, 1.0, 0.0, 1.0, false)


func _think(elapsed: float) -> void:
	intent = _scorer.choose(elapsed, {"wolf": self, "elapsed": elapsed}, intent)
	_top_line = _scorer.top_line()


# ------------------------------------------------------------------ tick de simulacao (20 Hz)

func sim_step(elapsed: float, dt: float) -> void:
	if not alive:
		return
	_bite_cd = maxf(_bite_cd - dt, 0.0)
	_wander_cd = maxf(_wander_cd - dt, 0.0)
	_saw_cd = maxf(_saw_cd - dt, 0.0)
	_threat = maxf(_threat - dt * 0.05, 0.0)
	hunger = clampf(hunger + dt * 0.006, 0.0, 1.0)
	mind.decay(dt / 60.0)
	if body.in_water:
		_swim_time += dt
		# preso na agua por tempo demais: a margem mais proxima manda, acima de
		# qualquer outra intencao da arvore (a mordida no jogador pode esperar)
		if _swim_time > SHORE_AFTER:
			_move_target = _shore_point()
			_speed = SPEED_WALK * SWIM_SPEED_FACTOR
	else:
		_swim_time = 0.0
	_sense()
	_think(elapsed)
	_tree.tick({"wolf": self, "elapsed": elapsed, "tick": _sim_clock.tick})


func _sense() -> void:
	var me := center()
	_hp_ratio = hp / MAX_HP
	var pp := _player.position3() + Vector3(0.0, 0.9, 0.0)
	_dist_player = me.distance_to(pp)
	# LOS e a unica leitura cara da percepcao: so roda quando pode importar.
	_los_player = _dist_player < 30.0 and _player.alive and world.line_of_sight(me, pp)
	_fear_here = aether.sample(me, AetherField.Channel.FEAR)
	_blood_here = aether.sample(me, AetherField.Channel.BLOOD)
	_work_here = aether.sample(me, AetherField.Channel.WORK)
	_find_scent()
	_fear_level = clampf(_fear_here * 0.85 + _threat * 0.9 + _blood_here * 0.35, 0.0, 1.5)
	# Memoria vira comportamento: quem ja apanhou deste ator evita ca-lo enquanto estiver
	# ferido. A porta de coragem da opcao "hunt" e exatamente este numero.
	var fears_actor: bool = mind.believes("danger_from_actor_%d" % ACTOR_PLAYER)
	_courage = 0.0 if (fears_actor and _hp_ratio < 0.62) else 1.0
	if not _los_player:
		mind.reinforce("player_visible_recent", -0.02, "perception")
		mind.reinforce("prey_wounded", -0.01, "perception")
	elif _saw_cd <= 0.0:
		_saw_cd = 2.0
		mind.remember(_sim_clock.tick, "saw_player", pp, ACTOR_PLAYER, 0.4)
		mind.reinforce("player_visible_recent", 0.12, "perception")


## Varre a vizinhanca de celulas de Eter atras do rastro mais forte (custo fixo).
func _find_scent() -> void:
	var c0 := aether.cell_of_world(center())
	var best := 0.0
	var best_cell := c0
	for dz in range(-SCENT_RADIUS, SCENT_RADIUS + 1):
		for dx in range(-SCENT_RADIUS, SCENT_RADIUS + 1):
			var c := Vector3i(c0.x + dx, c0.y, c0.z + dz)
			var v: float = aether.sample_cell(c, AetherField.Channel.BLOOD) \
					+ aether.sample_cell(c, AetherField.Channel.WORK) * 0.35
			if v > best:
				best = v
				best_cell = c
	_scent_strength = best
	_scent_found = best > SCENT_MIN
	var cell_pos := aether.cell_center(best_cell)
	_scent_pos = Vector3(cell_pos.x, float(world.surface_height(
		int(cell_pos.x), int(cell_pos.z))) + 0.6, cell_pos.z)


# ------------------------------------------------------------------ locomocao (60 Hz)

func _physics_process(delta: float) -> void:
	if not alive:
		_corpse_timer -= delta
		if _visual:
			_visual.rotation.z = lerpf(_visual.rotation.z, 1.45, clampf(delta * 6.0, 0.0, 1.0))
			if _corpse_timer <= 0.0:
				_visual.visible = false
		return
	body.apply_gravity(delta, SWIM_BUOYANCY if body.in_water else 1.0)
	if body.in_water:
		# boia: a cabeca empurra pra cima quando mergulha e o afundar e limitado
		var head := Coords.to_block(body.feet_pos + Vector3(0.0, DIMS.y - 0.15, 0.0))
		if world.is_water_xyz(head.x, head.y, head.z):
			body.velocity.y = lerpf(body.velocity.y, SWIM_RISE, clampf(delta * 12.0, 0.0, 1.0))
		body.velocity.y = maxf(body.velocity.y, SWIM_SINK_MAX)
	var want := _move_target - body.feet_pos
	want.y = 0.0
	if _stagger > 0.0:
		# atordoado pelo golpe: sem steering, a empurrada do knockback carrega o corpo
		_stagger -= delta
		body.velocity.x = lerpf(body.velocity.x, 0.0, clampf(delta * 2.5, 0.0, 1.0))
		body.velocity.z = lerpf(body.velocity.z, 0.0, clampf(delta * 2.5, 0.0, 1.0))
	elif want.length_squared() > 0.04:
		var dir := want.normalized()
		if _unstick > 0.0:
			dir = dir.rotated(Vector3.UP, _detour)
			_unstick -= delta
		var swim_speed := _speed * (SWIM_SPEED_FACTOR if body.in_water else 1.0)
		var target_v := dir * swim_speed
		body.velocity.x = lerpf(body.velocity.x, target_v.x, clampf(delta * 9.0, 0.0, 1.0))
		body.velocity.z = lerpf(body.velocity.z, target_v.z, clampf(delta * 9.0, 0.0, 1.0))
		_heading = atan2(-body.velocity.x, -body.velocity.z)
	else:
		body.velocity.x = 0.0
		body.velocity.z = 0.0
	body.move_and_collide(delta)
	if body.blocked_this_frame and _unstick <= 0.0:
		_unstick = randf_range(0.35, 0.8)
		_detour = (1.0 if randf() < 0.5 else -1.0) * randf_range(0.7, 1.3)
		if body.on_ground:
			body.velocity.y = 5.2
	if body.feet_pos.y < -6.0:
		body.feet_pos = home
		body.velocity = Vector3.ZERO
	_animate(delta)
	global_position = body.feet_pos


func _animate(delta: float) -> void:
	if _visual:
		_visual.rotation.y = _heading
	if body.in_water:
		# nado: patas remando em pares e o corpo sobe e desce com a flutuacao,
		# mesmo parado na agua (o gait de terra depende da velocidade horizontal)
		_swim_phase += delta * 6.5
		for i in _legs.size():
			var phase: float = _swim_phase + (PI if (i == 1 or i == 2) else 0.0)
			(_legs[i] as Node3D).rotation.x = sin(phase) * 0.38
		_visual.position.y = sin(_swim_phase * 0.5) * 0.05
		return
	_visual.position.y = 0.0
	var sp := Vector3(body.velocity.x, 0.0, body.velocity.z).length()
	if sp > 0.2:
		_gait += delta * (2.6 + sp * 1.5)
		for i in _legs.size():
			var phase: float = _gait + (PI if (i == 1 or i == 2) else 0.0)
			(_legs[i] as Node3D).rotation.x = sin(phase) * minf(0.7, 0.18 + sp * 0.08)
	elif _visual:
		for leg in _legs:
			leg.rotation.x = lerpf(leg.rotation.x, 0.0, clampf(delta * 8.0, 0.0, 1.0))


# ------------------------------------------------------------------ combate & memoria

func take_damage(amount: float, from_actor: int, hit_from: Vector3) -> void:
	if not alive:
		return
	hp = maxf(hp - amount, 0.0)
	_threat = 1.0
	_stagger = STAGGER_TIME
	var me := center()
	var push := me - hit_from
	push.y = 0.0
	if push.length_squared() > 0.0001:
		body.velocity += push.normalized() * KNOCKBACK_SPEED
		body.velocity.y = maxf(body.velocity.y, KNOCKBACK_LIFT)
	aether.imprint(me, AetherField.Channel.BLOOD, amount * 0.05)
	aether.imprint(me, AetherField.Channel.FEAR, amount * 0.035)
	mind.remember(_sim_clock.tick, "hurt", hit_from, from_actor, amount / MAX_HP)
	mind.adjust_trust(from_actor, -0.35)
	mind.reinforce("danger_from_actor_%d" % from_actor, 0.3, "perception")
	if hp > 0.0:
		wounded.emit(self, amount)
		acted.emit("blood", me)
	else:
		die()


func die() -> void:
	if not alive:
		return
	alive = false
	intent = "morto"
	_speed = 0.0
	var me := center()
	aether.imprint(me, AetherField.Channel.BLOOD, 1.1)
	aether.imprint(me, AetherField.Channel.FEAR, 0.55)
	_corpse_timer = CORPSE_SECONDS
	died.emit(self, me)
	acted.emit("kill", me)


func on_kill(p_actor: int) -> void:
	kills += 1
	feed(_player.position3())
	mind.remember(_sim_clock.tick, "win", _player.position3(), p_actor, 0.6)


func feed(p_pos: Vector3) -> void:
	hunger = maxf(hunger - 0.45, 0.0)
	mind.remember(_sim_clock.tick, "fed", p_pos, 0, 0.3)


## O dono da sessao so libera o corpo depois que ele sai de cena.
func finished() -> bool:
	return not alive and _corpse_timer <= 0.0


func debug_line() -> String:
	var fmt := "lobo%d %-12s hp %3.0f  %s\n     medo %.2f  sangue %.2f  trabalho %.2f  "\
			+ "mem %d  crencas %d  %s"
	return fmt % [identity, intent, hp, _top_line, _fear_level, _blood_here, _work_here,
			mind.episodic.size(), mind.beliefs.size(), tree_stats()]


func tree_stats() -> String:
	return "bt %d us (estouros %d)" % [_guard.last_us, _guard.trips]


func state_dict() -> Dictionary:
	return {
		"identity": identity, "home": [home.x, home.y, home.z],
		"feet": [body.feet_pos.x, body.feet_pos.y, body.feet_pos.z],
		"hp": hp, "alive": alive, "hunger": hunger, "kills": kills, "mind": mind.to_dict(),
	}


func load_state(d: Dictionary) -> void:
	home = Vector3(float(d["home"][0]), float(d["home"][1]), float(d["home"][2]))
	body.feet_pos = Vector3(float(d["feet"][0]), float(d["feet"][1]), float(d["feet"][2]))
	body.velocity = Vector3.ZERO
	hp = float(d.get("hp", MAX_HP))
	alive = bool(d.get("alive", true))
	hunger = float(d.get("hunger", 0.35))
	kills = int(d.get("kills", 0))
	mind.from_dict(d.get("mind", {}))
	_move_target = home
	_swim_time = 0.0
	_swim_phase = 0.0
	_stagger = 0.0
	if _visual:
		_visual.rotation.z = 0.0
	if not alive:
		intent = "morto"
		_speed = 0.0
		_corpse_timer = CORPSE_SECONDS
		if _visual:
			_visual.rotation.z = 1.45
			_visual.visible = true


# ------------------------------------------------------------------ visual (sem assets binarios)

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_fur = StandardMaterial3D.new()
	_fur.albedo_color = Color(0.40, 0.36, 0.31)
	_fur.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.16, 0.15, 0.14)
	dark.roughness = 0.95
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.95, 0.72, 0.22)
	eye.emission_enabled = true
	eye.emission = Color(0.9, 0.65, 0.2)
	_box(_visual, Vector3(0.55, 0.44, 1.05), Vector3(0, 0.74, 0.05), _fur)
	_box(_visual, Vector3(0.36, 0.34, 0.34), Vector3(0, 0.92, -0.62), _fur)
	_box(_visual, Vector3(0.18, 0.15, 0.24), Vector3(0, 0.84, -0.88), dark)
	_box(_visual, Vector3(0.10, 0.15, 0.06), Vector3(-0.13, 1.12, -0.60), dark)
	_box(_visual, Vector3(0.10, 0.15, 0.06), Vector3(0.13, 1.12, -0.60), dark)
	_box(_visual, Vector3(0.06, 0.06, 0.05), Vector3(-0.11, 0.97, -0.79), eye)
	_box(_visual, Vector3(0.06, 0.06, 0.05), Vector3(0.11, 0.97, -0.79), eye)
	_box(_visual, Vector3(0.12, 0.12, 0.50), Vector3(0, 0.88, 0.72), dark)
	# Perna = pivot no quadril + malha deslocada para baixo: o balanco gira no lugar certo.
	for p in [Vector3(-0.20, 0.52, -0.34), Vector3(0.20, 0.52, -0.34),
			Vector3(-0.20, 0.52, 0.42), Vector3(0.20, 0.52, 0.42)]:
		var pivot := Node3D.new()
		pivot.position = p
		_visual.add_child(pivot)
		_box(pivot, Vector3(0.16, 0.52, 0.16), Vector3(0, -0.26, 0), dark)
		_legs.append(pivot)


func _box(p_parent: Node, size: Vector3, pos: Vector3, mat: Material) -> void:
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	p_parent.add_child(mi)
