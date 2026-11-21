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
const SCENT_Y_RADIUS: int = 1         # celulas acima/abaixo da camada do lobo
const SCENT_MIN: float = 0.06
const SCENT_PERIOD: float = 0.25
const INSPECT_SECONDS: float = 2.0
const SCENT_MEMORY_SECONDS: float = 30.0
const SCENT_MEMORY_CAP: int = 32
const SCENT_RENEWAL: float = 0.06
const SIGHT_MEMORY_SECONDS: float = 6.0
## Raio do anel de cerco (dossie 10 §3.4): `BITE_RANGE` menos a folga do corpo, para
## o assento parar a alcance de mordida em vez de subir em cima da presa -- cinco
## corpos no mesmo voxel e o mesmo mal que `_volume_clear` registra no spawn.
const ENCIRCLE_RING: float = BITE_RANGE - 0.45
const CORPSE_SECONDS: float = 6.0
## Leitura compartilhada de "estou sozinho": o lobo nunca aloca lista vazia, e sim
## aponta para esta, que ninguem escreve.
const NO_PACK: Array = []
## Contagio do medo (dossie 10 §3.6): quanto o panico de UM vizinho em `flee`,
## dentro da coesao, soma no meu proprio `_fear_level`. E uma soma por vizinho, e
## nao uma media: dois em panico somam o dobro (o que satura e a curva de terror
## do escorredor, sigmoid 9,0 em torno de 0,42 na consideracao "terror no ar").
## O valor medido do par de bracos esta em `contagio_medo_muda_intent_do_observador`:
## com um vizinho em panico o `_fear_level` do lobo 1 sai de 0 para 0,55, `flee`
## marca 0,37 contra o chao de fundo 0,22 do `patrol`, e a margem passa o
## `min_lead` de 0,05 -- a margem depende da cautela sorteada da mente, nao e um
## numero valido para qualquer lobo.
const PACK_PANIC_FEAR: float = 0.55
## Contagio de confianca (dossie 10 §3.6): a coragem contra o jogador passa a ser
## tambem a de quem esta perto. `PACK_TRUST_GATE` e a mesma soleira de
## `Mind.believes` -- so confianca acima dela amortce; abaixo, o vizinho nao conta
## para nenhum lado. `PACK_TRUST_DAMP` e o que sai do `_courage` do observador por
## unidade de confianca lida, e o leva de 1,0 para baixo da porta de 0,5 que a
## consideracao "coragem contra este ator" cobra na opcao `hunt`: um vizinho
## amansado fecha a porta do colega. O medo de apanhar (trust negativo, o que
## `take_damage` escreve) nao da coragem a quem olha.
## Medido nos tres bracos de `amortece_confianca_fecha_a_porta_de_hunt_dos_colegas`:
## vizinho com trust 0,60 da `_courage` 0,46, `hunt` vetada com score 0,0 e os dois
## colegas em `patrol` enquanto o amansado fica com a porta aberta e em `hunt`; o
## MESMO vizinho com trust 0,30 -- abaixo da soleira -- devolve `_courage` 1,0 e os
## tres caam de novo, entao e o 0,35 que decide e nao a presenca de confianca.
## Estado do codigo, nao meta: hoje nada em `src/` escreve trust positivo --
## `take_damage` e o unico chamador de `adjust_trust` e passa -0,35 -- entao esta
## porta so tem o que amortecer quando o amansamento existir (dossies 14 e 11).
const PACK_TRUST_GATE: float = 0.35
const PACK_TRUST_DAMP: float = 0.9
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
# Pelo por bioma do `home`, na ordem exata do enum `WorldGen.Biome` (0 frozen,
# 1 arid, 2 temperate, 3 wetland): o indice da tabela e o id do bioma, entao
# trocar a ordem de um dos dois lados repinta os lobos sem erro nenhum. Tabela
# na propria classe (e nao `.tres`) porque o consumidor e um so. A linha de
# temperate e a cor historica do lobo: a maioria da matilha nasce nela e sai
# visualmente igual.
const FUR_COLORS: Array[Color] = [
	Color(0.78, 0.80, 0.84),    # frozen
	Color(0.62, 0.47, 0.27),    # arid
	Color(0.40, 0.36, 0.31),    # temperate
	Color(0.24, 0.29, 0.26),    # wetland
]

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
var home_biome: int = WorldGen.Biome.TEMPERATE
var kills: int = 0

var _player: Player = null
var _sim_clock: SimClock = null
## A matilha chega injetada, pelo mesmo caminho do `entity_provider` do jogador
## (dossie 10 §3.1): a sessao e a dona da lista, o lobo so le. Sem provedor -- o
## fixture do runner arma lobos soltos -- a leitura e vazia e nenhuma rotina de
## grupo roda, entao o lote novo nao toca no comportamento ja gateado.
var pack_provider: Callable = Callable()
## O trust da propria mente para com o jogador, publicado como escalar para a sessao
## copiar na leitura da matilha. Um `mind.trust()` por lobo por tick de 20 Hz, e nao
## um `str(ator)` por par: ler alcateia nao pode alocar no caminho quente (dossie 10
## §4). Vale o do passo anterior, exatamente como `intent` -- mesma cadencia, mesmo
## atraso.
var trust_toward_player: float = 0.0
var _rng := RandomNumberGenerator.new()
var _scorer: UtilityScorer = UtilityScorer.new()
var _tree: BtTree.BtNode = null
var _guard: BtTree.SubtreeGuard = null

# percepcao: recalculada uma vez por tick de simulacao
var _pack: Array = NO_PACK
# Quantos vizinhos da leitura estao em `flee` neste tick, e a maior confianca no
# jogador entre eles acima de `PACK_TRUST_GATE`. Contados em `_sense()`, uma vez
# por tick, consumidos ali mesmo por `_fear_level` e `_courage`, e colhidos pelo
# runner para que os dois numeros do contagio saiam no log em vez de ficarem na
# conversa (dossie 10 §3.6).
var _pack_panic: int = 0
var _pack_trust: float = 0.0
var _dist_player: float = 999.0
var _los_player: bool = false
var _fear_here: float = 0.0
var _blood_here: float = 0.0
var _work_here: float = 0.0
var _scent_pos: Vector3 = Vector3.ZERO
var _scent_strength: float = 0.0
var _scent_found: bool = false
var _scent_cell := Vector3i.ZERO
var _scent_channel: int = AetherField.Channel.WORK
var _scent_cd: float = 0.0
var _scent_clock: float = 0.0
var _inspect_left: float = 0.0
var _checked_scents: Dictionary = {}
var _fear_away := Vector3.ZERO
var _searched_sighting_tick: int = -1
var _reaction: String = "patrulhando"
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
	# Uma pergunta por lobo, sem cadencia: o bioma de onde o lobo nasceu ja esta
	# nos ruidos que geraram aquela coluna, e nao em dado novo do mundo.
	home_biome = world.gen.biome_at(int(home.x), int(home.z))
	body.setup(world, p_spawn, DIMS)
	_rng.seed = ("wolf:%d:%d" % [world.gen.world_seed, identity]).hash()
	_heading = _rng.randf() * TAU
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


## O vies de bioma e do chamador, nao do campo: `AetherField.imprint` continua
## sem saber que existe voxel, e e a fronteira que mantem a difusao barata
## (dossie 09). So roda em evento (mordida, golpe, morte); a altura vem do
## relevo gerado, nao da superficie atual, porque cavar nao troca o clima da
## coluna.
func _imprint(pos: Vector3, ch: int, amount: float) -> void:
	var h: int = world.gen.surface_height(int(pos.x), int(pos.z))
	aether.imprint(pos, ch, amount * world.gen.imprint_bias(int(pos.x), int(pos.z), h, ch))


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
			BtTree.Action.new().init("perseguir presa visivel", _leaf_chase),
			BtTree.Sequence.new().with([
				BtTree.Condition.new().init("lembra da presa", _cond_hunt_memory),
				BtTree.Action.new().init("vir ao ultimo avistamento", _leaf_stalk),
			]),
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
	var atom := mind.last_atom("saw_player")
	return _player.alive and not atom.is_empty() and int(atom["tick"]) > _searched_sighting_tick \
			and _sim_clock.tick - int(atom["tick"]) <= int(SIGHT_MEMORY_SECONDS * SimClock.HZ)


func _hunt_distance() -> float:
	if _los_player:
		return _dist_player
	var atom := mind.last_atom("saw_player")
	return center().distance_to(atom["pos"]) if not atom.is_empty() else 999.0


func _cond_scent(_ctx: Dictionary) -> bool:
	return _scent_found


# ------------------------------------------------------------------ folhas

func _leaf_flee(_ctx: Dictionary) -> bool:
	var away := _fear_away
	_reaction = "evitando medo"
	if _los_player:
		away = center() - _player.position3()
		_reaction = "fugindo do jogador visivel"
	elif _threat > 0.0:
		var hurt := mind.last_atom("hurt")
		if not hurt.is_empty():
			away = center() - Vector3(hurt["pos"])
			_reaction = "fugindo do ultimo golpe"
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(-sin(_heading), 0.0, -cos(_heading))
	_move_target = center() + away.normalized() * 14.0
	_speed = SPEED_FLEE
	# Reagir ao medo alheio nao pode realimentar o campo para sempre.
	if _threat > 0.0:
		# Re-imprint da fuga fica sem vies: a folha roda todo tick com _threat > 0, e ruido+altura ali e o custo que o dossie 09 recusa no caminho quente.
		aether.imprint(center(), AetherField.Channel.FEAR, 0.06)
	return true


func _leaf_chase(_ctx: Dictionary) -> bool:
	if not _los_player:
		return false
	var n := _hunt_pack_size()
	if n <= 1:
		# Um participante sozinho: a perseguicao literal de antes, direto ao corpo.
		_reaction = "perseguindo presa visivel"
		_move_target = _player.position3() + Vector3(0.0, 0.4, 0.0)
	else:
		var rank := _hunt_pack_rank()
		_reaction = "fechando cerco no assento %d de %d" % [rank, n]
		_move_target = _seat_point(_player.position3(), rank, n)
	_speed = SPEED_RUN if _dist_player > 6.0 else SPEED_WALK
	return true


## Quantos lobos estao no cerco neste tick: eu mais os vizinhos que a leitura da
## sessao devolve em `hunt`. O espacamento angular sai daqui, entao o assento e
## funcao de quem caa de fato, nao do censo da matilha nem de um N fixo.
func _hunt_pack_size() -> int:
	var n := 1
	for e: Dictionary in _pack:
		if String(e["intent"]) == "hunt":
			n += 1
	return n


## Minha posicao na fila do cerco: quantos participantes de identidade menor estao
## na leitura. Como a leitura e mutua e a identidade e unica, os assentos nunca
## se repetem enquanto o conjunto de participantes for o mesmo para todos.
func _hunt_pack_rank() -> int:
	var rank := 0
	for e: Dictionary in _pack:
		if String(e["intent"]) == "hunt" and int(e["identity"]) < identity:
			rank += 1
	return rank


## Assento angular em torno da presa: `TAU/n` por participante, medido no eixo do
## mundo (a leitura da sessao e a mesma para todos, entao o angulo de cada um sai
## do rank e nao da direcao em que cada um chegou -- duas referencias dariam dois
## anis girados). O `y` fica no da presa para a locomocao nao ter de adivinhar.
func _seat_point(prey: Vector3, rank: int, n: int) -> Vector3:
	var a := TAU * float(rank) / float(n)
	return Vector3(prey.x + cos(a) * ENCIRCLE_RING, prey.y + 0.4,
			prey.z + sin(a) * ENCIRCLE_RING)


func _leaf_stalk(_ctx: Dictionary) -> bool:
	var atom: Dictionary = mind.last_atom("saw_player")
	_move_target = atom["pos"]
	var offset := _move_target - center()
	offset.y = 0.0
	if offset.length_squared() <= 2.25:
		_searched_sighting_tick = int(atom["tick"])
		return false
	_reaction = "buscando ultimo avistamento"
	_speed = SPEED_WALK
	return true


func _leaf_investigate(ctx: Dictionary) -> int:
	if _stagger > 0.0:
		_inspect_left = 0.0
		_reaction = "atordoado"
		_move_target = body.feet_pos
		_speed = 0.0
		return BtStatus.RUNNING
	_move_target = _scent_pos
	var offset := _move_target - body.feet_pos
	offset.y = 0.0
	if offset.length_squared() > 1.44:
		_reaction = "seguindo sangue" if _scent_channel == AetherField.Channel.BLOOD else "seguindo trabalho"
		_speed = SPEED_WALK
		_inspect_left = 0.0
		return BtStatus.RUNNING
	_move_target = body.feet_pos
	_speed = 0.0
	_reaction = "farejando"
	if _inspect_left <= 0.0:
		_inspect_left = INSPECT_SECONDS
	_inspect_left = maxf(0.0, _inspect_left - float(ctx["dt"]))
	if _inspect_left > 0.0:
		return BtStatus.RUNNING
	_remember_scent()
	_reaction = "rastro examinado"
	_scent_found = false
	_scent_strength = 0.0
	_scent_cd = 0.0
	return BtStatus.SUCCESS


func _remember_scent() -> void:
	var kind := "scent_blood" if _scent_channel == AetherField.Channel.BLOOD else "scent_work"
	mind.remember(_sim_clock.tick, kind, _scent_pos, 0, _scent_strength / (AetherField.MAX_VALUE * 1.35))
	# Inclui a borda difusa: o mesmo cheiro nao deve provocar uma volta por celula.
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := _scent_cell + Vector3i(dx, 0, dz)
			if not aether.in_bounds(c):
				continue
			var strength := aether.sample_cell(c, AetherField.Channel.BLOOD) \
					+ aether.sample_cell(c, AetherField.Channel.WORK) * 0.35
			_checked_scents.erase(c)
			if _checked_scents.size() >= SCENT_MEMORY_CAP:
				_checked_scents.erase(_checked_scents.keys()[0])
			_checked_scents[c] = Vector2(strength, _scent_clock + SCENT_MEMORY_SECONDS)


func _leaf_wander(_ctx: Dictionary) -> bool:
	var n: int = _pack.size() + 1
	# Com um lobo so a ronda e exatamente a de antes: o centro e o proprio lar e a
	# fatia e o circulo inteiro. Nada aqui depende de provedor para funcionar.
	_reaction = "patrulhando" if n <= 1 else "rondando setor da matilha"
	_speed = SPEED_WALK
	if _wander_cd > 0.0 and center().distance_squared_to(_move_target) > 2.0:
		return true
	_wander_cd = _rng.randf_range(4.0, 9.0)
	if n <= 1:
		_pick_wander(home, 0.0, TAU)
		return true
	var arc := TAU / float(n)
	var seat := float(_territory_rank()) * arc
	if not _pick_wander(_territory_center(n), seat, arc):
		# Setor inteiro em agua nao e prisao: o lobo volta a sortear o circulo
		# completo em torno do proprio lar, que e a ronda de um lobo so.
		_pick_wander(home, 0.0, TAU)
	return true


## Sorteia ate oito pontos na fatia dada do territorio e grava o primeiro que tem
## terra seca. Devolve falso so quando a agua ganhou as oito tentativas.
func _pick_wander(origin: Vector3, seat: float, arc: float) -> bool:
	for _t in 8:
		var a := seat + _rng.randf() * arc
		var r := _rng.randf_range(5.0, WANDER_RADIUS)
		var p := origin + Vector3(cos(a) * r, 0.0, sin(a) * r)
		p.x = clampf(p.x, 4.0, float(VoxelConfig.world_size_x()) - 4.0)
		p.z = clampf(p.z, 4.0, float(VoxelConfig.world_size_z()) - 4.0)
		if not _dry_ground(p):
			continue
		p.y = float(world.surface_height(int(p.x), int(p.z))) + 0.2
		_move_target = p
		return true
	return false


## Centro compartilhado da ronda (dossie 10 §3.2): o baricentro das posicoes que a
## matilha le, e nao o `home` sorteado um por lobo -- cinco lares espalhados nunca
## foram territorio. A leitura da sessao e mutua, entao todos os membros chegam no
## mesmo numero e cada um particiona o circulo do seu proprio ponto de vista.
func _territory_center(n: int) -> Vector3:
	if n <= 1:
		return home
	var sum := center()
	for e: Dictionary in _pack:
		var pos: Vector3 = e["pos"]
		sum += pos
	return sum / float(n)


## Qual fatia do circulo este lobo patrulha: quantos vizinhos tem identidade menor
## que a dele. `identity % n` daria a mesma fatia a identidades nao consecutivas e
## nao distribui nada; o rank comparado e sempre distinto dentro da matilha e nao
## aloca lista nenhuma (dossie 10 §4).
func _territory_rank() -> int:
	var rank := 0
	for e: Dictionary in _pack:
		if int(e["identity"]) < identity:
			rank += 1
	return rank


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


## Filtro de validade do alvo (dossie 14 §3.1): a arvore decide PARA ONDE e o chao
## decide se esse para onde existe. Depois do `_tree.tick` e o unico ponto que
## cobre as quatro folhas que escrevem alvo sem perguntar pelo solo (`_leaf_flee`,
## `_leaf_chase`, `_leaf_stalk`, `_leaf_investigate`) sem copiar o teste cinco
## vezes -- e sem brigar com o escorredor, que decide intencao e nao geometria.
## Uma pergunta por lobo por passo de 20 Hz, fora dos 400 us do `SubtreeGuard`.
## Sem saida seca no anel o alvo molhado fica onde esta e o nado segue o caminho
## que ja existe: nao ha aqui fallback que finja ter achado terra (mandato 1).
func _resolve_dry_target() -> void:
	if _dry_ground(_move_target):
		return
	var shore := _shore_point()
	if _dry_ground(shore):
		_move_target = shore


func _leaf_bite(_ctx: Dictionary) -> bool:
	if _bite_cd > 0.0:
		return false
	if not _bite_turn():
		# Assento esperando: a folha devolve falso, a arvore cai em `perseguir` e o
		# lobo continua circundando a presa ate ser a sua vez.
		return false
	_bite_cd = BITE_COOLDOWN
	bit_player.emit(self, BITE_DAMAGE)
	var pp := _player.position3()
	_imprint(pp, AetherField.Channel.BLOOD, 0.18)
	mind.remember(_sim_clock.tick, "hit_land", pp, ACTOR_PLAYER, 0.3)
	mind.reinforce("prey_wounded", 0.22, "perception")
	return true


## Escalonamento da mordida (dossie 10 §3.5): com n participantes do cerco, o
## assento r morde nos ticks `tick % n == r`. A janela de `BITE_COOLDOWN` sao 23
## ticks e o periodo e no maximo n, entao dois assentos nunca chegam ao alcance no
## mesmo tick e a matilha distribui a pressao em vez de morder toda junto. A
## referencia e o `clock.tick` da sessao: `Time.get_ticks_*` daria outro padrao
## conforme a maquina, e o journal nao e reproduzivel com relogio de parede.
func _bite_turn() -> bool:
	var n := _hunt_pack_size()
	if n <= 1:
		return true
	return _sim_clock.tick % n == _hunt_pack_rank()


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
	hunt.add("proximidade percebida", func(_c: Dictionary) -> float: return _hunt_distance(),
			26.0, 0.0, ResponseCurve.Type.LINEAR, 1.0, 0.0, 1.1, false)
	hunt.add("presa percebida", func(c: Dictionary) -> float:
		return 1.0 if (_player.alive and (_los_player or _cond_hunt_memory(c))) else 0.0,
			0.0, 1.0, ResponseCurve.Type.LINEAR, 1.0, 0.0, 0.0, true)
	hunt.add("coragem contra este ator", func(_c: Dictionary) -> float: return _courage,
			0.5, 1.0, ResponseCurve.Type.LINEAR, 1.0, 0.0, 0.0, true)

	var sniff := _scorer.add_option("investigate")
	sniff.add("rastro no ar", func(_c: Dictionary) -> float: return _scent_strength,
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
	intent = _scorer.choose(elapsed, {"wolf": self, "elapsed": elapsed, "pack": _pack}, intent)
	_top_line = _scorer.top_line()


## A leitura da matilha e uma chamada por tick de 20 Hz, nunca por frame: o Array
## devolvido e o buffer da sessao, reescrito no lugar a cada passo, entao ler nao
## aloca nada (dossie 10 §4 -- se fosse cinco arrays novos por tick, nao entraria).
func _read_pack() -> void:
	_pack = pack_provider.call() if pack_provider.is_valid() else NO_PACK


# ------------------------------------------------------------------ tick de simulacao (20 Hz)

func sim_step(elapsed: float, dt: float) -> void:
	if not alive:
		return
	_bite_cd = maxf(_bite_cd - dt, 0.0)
	_wander_cd = maxf(_wander_cd - dt, 0.0)
	_saw_cd = maxf(_saw_cd - dt, 0.0)
	_scent_clock += dt
	_scent_cd = maxf(_scent_cd - dt, 0.0)
	_threat = maxf(_threat - dt * 0.05, 0.0)
	hunger = clampf(hunger + dt * 0.006, 0.0, 1.0)
	mind.decay(dt / 60.0)
	if body.in_water:
		_swim_time += dt
		# preso na agua por tempo demais: a margem mais proxima manda, acima de
		# qualquer outra intencao da arvore (a mordida no jogador pode esperar).
		# A promessa e cumprida no fim do passo por `_resolve_dry_target()` (dossie
		# 14 §3.1) -- aqui mesmo a atribuicao e sobrescrita por qualquer folha com
		# alvo, porque roda antes de `_sense`, `_think` e `_tree.tick`.
		if _swim_time > SHORE_AFTER:
			_move_target = _shore_point()
			_speed = SPEED_WALK * SWIM_SPEED_FACTOR
	else:
		_swim_time = 0.0
	_read_pack()
	_sense()
	_think(elapsed)
	if intent != "investigate":
		_inspect_left = 0.0
	_tree.tick({"wolf": self, "elapsed": elapsed, "tick": _sim_clock.tick, "dt": dt, "pack": _pack})
	_resolve_dry_target()


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
	trust_toward_player = mind.trust(ACTOR_PLAYER)
	if _scent_cd <= 0.00001:
		_find_scent()
	# Contagio (dossie 10 §3.6): a fuga e a confianca de quem esta perto sao leitura,
	# nao corpo -- o vizinho nao escreve em mim, eu somo o que a sessao devolve. Sem
	# provedor a lista e vazia e o numero e literalmente o de antes.
	_pack_panic = 0
	_pack_trust = 0.0
	for e: Dictionary in _pack:
		if String(e["intent"]) == "flee":
			_pack_panic += 1
		var t: float = float(e["trust"])
		if t >= PACK_TRUST_GATE:
			_pack_trust = maxf(_pack_trust, t)
	_fear_level = clampf(_fear_here * 0.85 + _threat * 0.9 + _blood_here * 0.35
			+ float(_pack_panic) * PACK_PANIC_FEAR, 0.0, 1.5)
	# Memoria vira comportamento: quem ja apanhou deste ator evita ca-lo enquanto estiver
	# ferido. A porta de coragem da opcao "hunt" e exatamente este numero.
	var fears_actor: bool = mind.believes("danger_from_actor_%d" % ACTOR_PLAYER)
	_courage = 0.0 if (fears_actor and _hp_ratio < 0.62) else 1.0
	_courage = clampf(_courage - _pack_trust * PACK_TRUST_DAMP, 0.0, 1.0)
	if not _los_player:
		mind.reinforce("player_visible_recent", -0.02, "perception")
		mind.reinforce("prey_wounded", -0.01, "perception")
	elif _saw_cd <= 0.0:
		_saw_cd = 2.0
		mind.remember(_sim_clock.tick, "saw_player", pp, ACTOR_PLAYER, 0.4)
		mind.reinforce("player_visible_recent", 0.12, "perception")


## Varre o quadrado de SCENT_RADIUS na camada do lobo atras do rastro mais forte e, se ela
## nao devolve nada utilizavel, repete o quadrado nas SCENT_Y_RADIUS camadas acima e abaixo.
## BLOOD e WORK sao lidos em toda camada varrida; FEAR so na do lobo, porque o empurrao da
## fuga e horizontal e a suite ja o mede ali.
func _find_scent() -> void:
	_scent_cd = SCENT_PERIOD
	for c: Vector3i in _checked_scents.keys():
		if _checked_scents[c].y <= _scent_clock:
			_checked_scents.erase(c)
	var c0 := aether.cell_of_world(center())
	var best := 0.0
	var best_cell := c0
	var channel: int = AetherField.Channel.WORK
	_fear_away = Vector3.ZERO
	# Camada propria primeiro, vizinhas depois: com rastro no nivel do lobo o nariz nao desce
	# nem sobe, e cada camada vizinha custa 49 leituras a mais num scan que roda 4x por segundo.
	for k in (2 * SCENT_Y_RADIUS + 1):
		var dy: int = 0 if k == 0 else (-1 if k % 2 == 1 else k / 2)
		if dy != 0 and best > SCENT_MIN:
			continue
		for dz in range(-SCENT_RADIUS, SCENT_RADIUS + 1):
			for dx in range(-SCENT_RADIUS, SCENT_RADIUS + 1):
				var c := Vector3i(c0.x + dx, c0.y + dy, c0.z + dz)
				var blood := aether.sample_cell(c, AetherField.Channel.BLOOD)
				var work := aether.sample_cell(c, AetherField.Channel.WORK) * 0.35
				var v := blood + work
				if dy == 0:
					var fear := aether.sample_cell(c, AetherField.Channel.FEAR)
					var offset := Vector3(dx, 0.0, dz)
					if offset.length_squared() > 0.0:
						_fear_away -= offset * maxf(fear - _fear_here, 0.0) / offset.length_squared()
				if _checked_scents.has(c) and v < _checked_scents[c].x + SCENT_RENEWAL:
					continue
				if v > best:
					best = v
					best_cell = c
					channel = AetherField.Channel.BLOOD if blood > work else AetherField.Channel.WORK
	if best_cell != _scent_cell or best <= SCENT_MIN:
		_inspect_left = 0.0
	_scent_cell = best_cell
	_scent_channel = channel
	_scent_strength = best
	_scent_found = best > SCENT_MIN
	var cell_pos := aether.cell_center(best_cell)
	_scent_pos = Vector3(cell_pos.x, _scent_ground_y(best_cell), cell_pos.z)


## Chao do rastro: a primeira superficie solida descendo do topo da camada encontrada.
## surface_height() nao serve aqui porque devolve o topo da coluna inteira — para um
## rastro dentro de caverna isso e o teto, e o episodio lembrado diria que o sangue
## estava na superficie. Sem solido na janela, fica no topo da propria camada.
func _scent_ground_y(c: Vector3i) -> float:
	var cell_pos := aether.cell_center(c)
	var bx := int(cell_pos.x)
	var bz := int(cell_pos.z)
	var top := c.y * aether.cell + aether.cell - 1
	for y: int in range(top, top - 2 * aether.cell, -1):
		if world.is_solid_xyz(bx, y, bz):
			return float(y) + 0.6
	return float(top)


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
	if body.blocked_horizontal and _unstick <= 0.0:
		_unstick = _rng.randf_range(0.35, 0.8)
		_detour = (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(0.7, 1.3)
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
	_imprint(me, AetherField.Channel.BLOOD, amount * 0.05)
	_imprint(me, AetherField.Channel.FEAR, amount * 0.035)
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
	_imprint(me, AetherField.Channel.BLOOD, 1.1)
	_imprint(me, AetherField.Channel.FEAR, 0.55)
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
			+ "mem %d  crencas %d  %s\n     %s | %s %.2f em %s | checadas %d"
	return fmt % [identity, intent, hp, _top_line, _fear_level, _blood_here, _work_here,
			mind.episodic.size(), mind.beliefs.size(), tree_stats(), _reaction,
			AetherField.CHANNEL_NAMES[_scent_channel], _scent_strength, _scent_cell, _checked_scents.size()]


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
	# O load move o `home` sem reconstruir o visual: sem re-derivar o bioma aqui,
	# o lobo voltaria com a cor do ponto sorteado nesta sessao e nao do seu lar.
	home_biome = world.gen.biome_at(int(home.x), int(home.z))
	if _fur:
		_fur.albedo_color = FUR_COLORS[home_biome]
	body.feet_pos = Vector3(float(d["feet"][0]), float(d["feet"][1]), float(d["feet"][2]))
	body.velocity = Vector3.ZERO
	hp = float(d.get("hp", MAX_HP))
	alive = bool(d.get("alive", true))
	hunger = float(d.get("hunger", 0.35))
	kills = int(d.get("kills", 0))
	mind.from_dict(d.get("mind", {}))
	_move_target = home
	_checked_scents.clear()
	# A leitura da matilha e do passo: depois do load o mundo em volta mudou, entao
	# ela volta a vazia ate o proximo rebuild da sessao.
	_pack = NO_PACK
	_scent_cd = 0.0
	_scent_clock = 0.0
	_scent_found = false
	_scent_strength = 0.0
	_inspect_left = 0.0
	_fear_away = Vector3.ZERO
	_searched_sighting_tick = -1
	_reaction = "patrulhando"
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
	_fur.albedo_color = FUR_COLORS[home_biome]
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
