class_name PlayerAvatar
extends Node3D
## Corpo voxel do jogador: a geometria que existe quando a camera NAO esta dentro
## da cabeca. Sao pivots articulados (quadril, joelho, ombro, cotovelo) com uma
## caixa por segmento; o Player escreve o estado e chama advance(delta).
##
## A silhueta fecha em 1,82 m contra 1,80 m da AABB do corpo. Este rig e o unico
## corpo no quadro da 3a pessoa: em 1a pessoa ele sai inteiro (o rig fica
## oculto, nao desmontado) e quem entra e o FPViewmodel, o braco com o bloco na
## mao desenhado para a lente. Um modelo por vista -- sobrepor os dois foi o que
## fez a 1a pessoa anterior virar slab azul na frente do olho e braco solto.
##
## A mao direita carrega o bloco selecionado, do mesmo atlas e do mesmo tamanho
## do cubo da 1a pessoa, e a pose do braco sai do que ele segura: o registro nao
## tem massa, entao a dureza -- o unico gradiente fisico real por bloco, e o que
## ja manda no tempo de lavra -- decide se o cubo sobe na frente do peito ou
## pendura ao lado da coxa, de quanto o pendulo da caminhada encolhe com a carga
## e de quao fundo e quao lento e o arco de picareta.

const PACE := 4.3
const HIP_Y := 0.80
const THIGH := 0.40
const SHIN := 0.32
const CROUCH_DROP := 0.40
## Ombro: 0,30 e a linha do deltoide fora do tronco de 0,46 de largura.
const SHOULDER_X := 0.30
const SHOULDER_SPLAY := 0.07
## Tamanho do cubo na mao. Nao e o 0,16 da 1a pessoa: la o prop mora a meio
## metro da lente e parece grande; aqui o mesmo 0,16 a 4,4 m de orbita cobre
## 22 px e cai inteiro atras do punho que o segura (medido: 0,000..0,062 da
## propria area chegava ao quadro). 0,24 e o menor tamanho com que o bloco
## passa para fora da mao e se ve.
const HELD_SIZE := 0.24
## O cubo sai da mao pendurado abaixo do punho e encostado na sua face externa:
## colado no punho ele some dentro da caixa da mao, solto ele fica flutuando a
## um palmo do dedo e o braco parece nao ter segurado nada. Coordenadas do
## cotovelo direito.
const HELD_AT := Vector3(0.06, -0.46, -0.06)
## Pedra e o bloco mais duro do registro, entao e a carga cheia da escala; nao e
## uma media nem um palpite, e o maximo que `BlockDefs.hardness` devolve hoje.
const LOAD_REF := 0.95
## Braco com cubo LEVE: ombro para frente, cotovelo dobrado o bastante para o
## antebraco ficar horizontal e o punho subir ate a altura do peito.
const CARRY_SHOULDER_LIGHT := 0.45
const CARRY_ELBOW_LIGHT := 1.55
## Braco com cubo PESADO: o mesmo braco esticado para baixo, o bloco pendurado
## ao lado da coxa. Os dois extremos sao interpolados pela dureza.
const CARRY_SHOULDER_HEAVY := 0.10
const CARRY_ELBOW_HEAVY := 0.28
## Abertura do mesmo braco para fora do corpo, por carga. Sem ela o cubo fica
## atras do proprio antebraco no quadro de tras -- que e o quadro em que a
## camera de 3a pessoa quase sempre esta -- e o que ele segura nao se ve. O
## leve abre quase tanto quanto o pesado: erguido na frente do peito ele
## precisava sair da coluna do braco, nao so da do tronco.
const CARRY_SPLAY_LIGHT := 0.40
const CARRY_SPLAY_HEAVY := 0.44
## Quanto do balanco da caminhada o ombro perde segurando a carga maxima.
const CARRY_PUMP_LOSS := 0.45
## Arco de lavra, por carga: alcance do impacto e cadencia em rad/s. Sem nada na
## mao os dois ficam no leve, que e o soco curto e rapido de sempre.
const DIG_REACH_LIGHT := 0.62
const DIG_REACH_HEAVY := 1.12
const DIG_RATE_LIGHT := 9.0
const DIG_RATE_HEAVY := 4.6

var walk_speed := 0.0
var vertical := 0.0
var on_ground := true
var in_water := false
var crouching := false
var pitching := 0.0
var gliding := false
var rolling := false
var mining := false
var dead := false
## O que a mao direita segura: o Player escreve o `selected_block()` aqui, do
## mesmo jeito que escreve no FPViewmodel, e o cubo sai do atlas do mundo.
var block_id: int = BlockDefs.Block.AIR

var first_person := false
var _rig: Node3D = null
var _chest: Node3D = null
var _head: Node3D = null
var _thighs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _held: MeshInstance3D = null
var _atlas: Texture2D = null
var _mat_block: StandardMaterial3D = null
var _mat_block_alpha: StandardMaterial3D = null
var _mesh_for := -1
var _phase := 0.0
var _amp := 0.0
var _air := 0.0
var _rise := 0.0
var _swim := 0.0
var _glide := 0.0
var _roll := 0.0
var _crouch := 0.0
var _dig := 0.0
var _swing := 0.0
## Blend da carga (tem algo na mao?) e do peso dela (0 folha .. 1 pedra), e o
## relogio proprio do ciclo de picareta: a cadencia muda com a carga e nao pode
## emprestar o _phase do corpo, que e da passada.
var _carry := 0.0
var _load := 0.0
var _digp := 0.0


## Impulso de golpe: o braco direito faz o arco e volta sozinho.
func swing() -> void:
	_swing = 1.0


## O atlas vem do mundo: sem ele o bloco na mao seria um cubo de cor chutada.
func set_atlas(tex: Texture2D) -> void:
	_atlas = tex
	_mat_block = _atlas_mat(false)
	_mat_block_alpha = _atlas_mat(true)
	_mesh_for = -1


## O cubo que esta na mao: para quem precisa medir visibilidade e posicionamento
## sem conhecer os nomes internos do rig.
func held_mesh() -> MeshInstance3D:
	return _held


## Ombro e cotovelo direitos: o eixo que a 3a pessoa ve, e onde a carga aparece.
func arm_angles() -> Vector2:
	return Vector2(_shoulders[1].rotation.x, _elbows[1].rotation.x)


## 1a pessoa: o rig inteiro sai de cena -- a lente tem o FPViewmodel. Em 3a ele
## volta inteiro, na mesma articulacao, porque so a visibilidade muda.
func set_first_person(fp: bool) -> void:
	first_person = fp
	_rig.visible = not fp


func head_shown() -> bool:
	return _head.is_visible_in_tree()


func advance(delta: float) -> void:
	var smooth := 1.0 - exp(-13.0 * delta)
	var norm := clampf(walk_speed / PACE, 0.0, 1.35)
	_amp = lerpf(_amp, norm * (0.55 if crouching else 1.0), smooth)
	_air = lerpf(_air, 0.0 if on_ground else 1.0, smooth)
	_rise = lerpf(_rise, clampf(vertical / 10.0, -1.0, 1.0), smooth)
	_swim = lerpf(_swim, 1.0 if (in_water and not on_ground) else 0.0, smooth)
	_glide = lerpf(_glide, 1.0 if gliding else 0.0, smooth)
	_roll = lerpf(_roll, 1.0 if rolling else 0.0, smooth)
	_crouch = lerpf(_crouch, 1.0 if (crouching and on_ground) else 0.0, smooth)
	_dig = lerpf(_dig, 1.0 if mining else 0.0, smooth)
	_carry = lerpf(_carry, 1.0 if block_id != BlockDefs.Block.AIR else 0.0, smooth)
	_load = lerpf(_load, clampf(BlockDefs.hardness(block_id) / LOAD_REF, 0.0, 1.0), smooth)
	_swing = maxf(_swing - delta * 2.8, 0.0)
	_phase += delta * (2.0 + 1.05 * walk_speed)
	if _dig > 0.01:
		_digp += delta * lerpf(DIG_RATE_LIGHT, DIG_RATE_HEAVY, _load)
	_sync_held()
	if dead:
		_pose_dead(smooth)
	else:
		_pose()


func _sync_held() -> void:
	if block_id == BlockDefs.Block.AIR or _atlas == null:
		_held.visible = false
		return
	if block_id != _mesh_for:
		_held.mesh = VoxelWorld.block_cube_mesh(block_id, HELD_SIZE)
		_held.material_override = (_mat_block_alpha
			if BlockDefs.draw_of(block_id) == BlockDefs.Draw.ALPHA else _mat_block)
		_mesh_for = block_id
	_held.visible = true


func _pose() -> void:
	var a := _amp
	var s0 := sin(_phase)
	var s1 := -s0
	# indice 0 = esquerdo, 1 = direito; rotacao +x no quadril/ombro manda a
	# extremidade para -Z, que e a frente do modelo
	var thigh := [0.46 * a * s0, 0.46 * a * s1]
	var knee := [-0.36 * a * maxf(0.0, -s0) - 0.06 * a, -0.36 * a * maxf(0.0, s0) - 0.06 * a]
	var sh := [0.34 * a * s1, 0.34 * a * s0]
	var el := [0.20 + 0.18 * a * maxf(0.0, s1), 0.20 + 0.18 * a * maxf(0.0, s0)]
	var shz := [-SHOULDER_SPLAY, SHOULDER_SPLAY]
	var lean := -0.05 * a
	var bob := absf(s0) * 0.035 * a
	var roll := s0 * 0.020 * a
	var breath := sin(_phase * 2.2) * (1.0 - minf(a, 1.0))

	if _carry > 0.01:
		# O braco direito passa a existir para o que ele segura: cubo leve sobe na
		# frente do peito, cubo pesado pendura ao lado da coxa, e o pendulo da
		# caminhada encolhe com a carga -- pedra nao balanca como folha seca. O
		# tronco inclina um dedo para o lado vazio, e por isso a 3a pessoa muda ate
		# parado. Vem antes dos estilos de corpo: no ar, nadando, planando, rolando
		# ou agachado as maos estao ocupadas com outra coisa e a carga nao manda.
		var w := _load
		sh[1] = lerpf(sh[1], lerpf(CARRY_SHOULDER_LIGHT, CARRY_SHOULDER_HEAVY, w)
			+ 0.34 * a * s0 * (1.0 - CARRY_PUMP_LOSS * w), _carry)
		el[1] = lerpf(el[1], lerpf(CARRY_ELBOW_LIGHT, CARRY_ELBOW_HEAVY, w), _carry)
		shz[1] = lerpf(shz[1], SHOULDER_SPLAY + lerpf(CARRY_SPLAY_LIGHT,
				CARRY_SPLAY_HEAVY, w), _carry)
		roll += 0.030 * w * _carry

	var up := clampf(0.5 + 0.5 * _rise, 0.0, 1.0)
	if _air > 0.01:
		thigh[0] = lerpf(thigh[0], lerpf(0.34, 0.66, up), _air)
		thigh[1] = lerpf(thigh[1], lerpf(-0.20, 0.14, up), _air)
		knee[0] = lerpf(knee[0], lerpf(-0.90, -0.30, up), _air)
		knee[1] = lerpf(knee[1], lerpf(-0.26, -1.00, up), _air)
		sh[0] = lerpf(sh[0], lerpf(-1.70, -0.30, up), _air)
		sh[1] = lerpf(sh[1], lerpf(-1.40, -0.10, up), _air)
		el[0] = lerpf(el[0], 0.70, _air)
		el[1] = lerpf(el[1], 0.50, _air)
		lean = lerpf(lean, -0.05, _air)
		bob = lerpf(bob, 0.0, _air)

	if _swim > 0.01:
		var f := sin(_phase * 2.1)
		thigh[0] = lerpf(thigh[0], 0.30 + 0.22 * f, _swim)
		thigh[1] = lerpf(thigh[1], 0.30 - 0.22 * f, _swim)
		knee[0] = lerpf(knee[0], -0.40, _swim)
		knee[1] = lerpf(knee[1], -0.40, _swim)
		sh[0] = lerpf(sh[0], -1.30 + 0.95 * f, _swim)
		sh[1] = lerpf(sh[1], -1.30 - 0.95 * f, _swim)
		el[0] = lerpf(el[0], 0.30, _swim)
		el[1] = lerpf(el[1], 0.30, _swim)
		lean = lerpf(lean, 0.48, _swim)
		bob = lerpf(bob, 0.05, _swim)

	if _glide > 0.01:
		# planar: pendurado de bracos erguidos segurando a vela, pernas esticadas
		# pra tras e o tronco quase deitado no ar
		thigh[0] = lerpf(thigh[0], 0.16, _glide)
		thigh[1] = lerpf(thigh[1], 0.08, _glide)
		knee[0] = lerpf(knee[0], -0.14, _glide)
		knee[1] = lerpf(knee[1], -0.10, _glide)
		sh[0] = lerpf(sh[0], -1.45, _glide)
		sh[1] = lerpf(sh[1], -1.45, _glide)
		el[0] = lerpf(el[0], 0.25, _glide)
		el[1] = lerpf(el[1], 0.25, _glide)
		lean = lerpf(lean, 0.90, _glide)
		bob = lerpf(bob, 0.0, _glide)

	if _roll > 0.01:
		# rolamento: encolher e mergulhar o tronco pra frente enquanto o impulso carrega
		thigh[0] = lerpf(thigh[0], 1.35, _roll)
		thigh[1] = lerpf(thigh[1], 1.30, _roll)
		knee[0] = lerpf(knee[0], -2.10, _roll)
		knee[1] = lerpf(knee[1], -2.15, _roll)
		sh[0] = lerpf(sh[0], 0.85, _roll)
		sh[1] = lerpf(sh[1], 0.95, _roll)
		el[0] = lerpf(el[0], 1.10, _roll)
		el[1] = lerpf(el[1], 1.20, _roll)
		lean = lerpf(lean, 1.00, _roll)

	if _crouch > 0.01:
		thigh[0] = lerpf(thigh[0], 1.22, _crouch)
		thigh[1] = lerpf(thigh[1], 1.14, _crouch)
		knee[0] = lerpf(knee[0], -1.95, _crouch)
		knee[1] = lerpf(knee[1], -2.02, _crouch)
		sh[0] = lerpf(sh[0], 0.62, _crouch)
		sh[1] = lerpf(sh[1], 0.68, _crouch)
		el[0] = lerpf(el[0], 0.40, _crouch)
		el[1] = lerpf(el[1], 0.40, _crouch)
		lean = lerpf(lean, -0.30, _crouch)

	if _dig > 0.01:
		# Ciclo de picareta com o que a mao segura: no alto o braco recolhe o
		# cotovelo, no impacto o ombro desce ate a frente do corpo, em direcao ao
		# bloco minerado. O arco antigo passava o ciclo inteiro atras do corpo
		# (-1,75 .. -0,15 rad) e nunca chegava no alvo; agora o alcance e o
		# relogio do ciclo sao da carga (_digp, nao o da passada): pedra pesada
		# desce mais fundo e mais devagar que folha.
		var c := 0.5 + 0.5 * sin(_digp)
		var reach := lerpf(DIG_REACH_LIGHT, DIG_REACH_HEAVY, _load)
		sh[1] = lerpf(sh[1], lerpf(-0.10, reach, c), _dig)
		el[1] = lerpf(el[1], lerpf(1.30, 0.30, c), _dig)
		lean = lerpf(lean, lerpf(-0.10, -0.32, c), _dig * (0.4 + 0.6 * _load))

	if _swing > 0.0:
		var t := 1.0 - _swing
		var e := t * t * (3.0 - 2.0 * t)
		var wt := minf(_swing * 2.5, 1.0)
		# Com carga o mesmo arco fica mais fundo: arma atras do corpo e acompanha
		# ate a frente. Sem nada na mao _load e 0 e os numeros sao os de sempre.
		var wind := -1.95 - 0.30 * _load
		var strike := 0.95 + 0.30 * _load
		sh[1] = lerpf(sh[1], lerpf(wind, strike, e), wt)
		el[1] = lerpf(el[1], lerpf(1.05, 0.10, e), wt)
		lean = lerpf(lean, lerpf(-0.30, 0.14, e), wt * 0.7)

	for i in 2:
		_thighs[i].rotation.x = thigh[i]
		_thighs[i].rotation.z = 0.0
		_knees[i].rotation.x = knee[i]
		_shoulders[i].rotation.x = sh[i]
		_shoulders[i].rotation.z = shz[i]
		_elbows[i].rotation.x = el[i]
	_rig.rotation.z = roll
	_rig.position.y = -CROUCH_DROP * _crouch + bob + breath * 0.01
	_chest.rotation.x = lean
	_head.rotation.x = clampf(pitching, -0.85, 0.85) * 0.55 - lean
	_head.rotation.z = -roll * 0.5 + breath * 0.025


func _pose_dead(smooth: float) -> void:
	_rig.rotation.z = lerpf(_rig.rotation.z, 1.42, smooth)
	_rig.position.y = lerpf(_rig.position.y, 0.24, smooth)
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_thighs[i].rotation.x = lerpf(_thighs[i].rotation.x, 0.45 * s, smooth)
		_thighs[i].rotation.z = lerpf(_thighs[i].rotation.z, 0.20 * s, smooth)
		_knees[i].rotation.x = lerpf(_knees[i].rotation.x, -0.65, smooth)
		_shoulders[i].rotation.x = lerpf(_shoulders[i].rotation.x, -0.55 * s, smooth)
		_shoulders[i].rotation.z = lerpf(_shoulders[i].rotation.z, 0.75 * s, smooth)
		_elbows[i].rotation.x = lerpf(_elbows[i].rotation.x, 0.35, smooth)
	_head.rotation.x = lerpf(_head.rotation.x, -0.35, smooth)


func _ready() -> void:
	var skin := _mat(Color(0.74, 0.58, 0.45), 0.88)
	var shirt := _mat(Color(0.22, 0.34, 0.50), 0.92)
	var pants := _mat(Color(0.19, 0.20, 0.25), 0.95)
	var leather := _mat(Color(0.28, 0.19, 0.13), 0.90)
	var hair := _mat(Color(0.14, 0.11, 0.09), 0.95)
	var eye := _mat(Color(0.07, 0.08, 0.10), 0.55)
	var aether := _mat(Color(0.32, 0.80, 0.90), 0.35)
	aether.emission_enabled = true
	aether.emission = Color(0.14, 0.52, 0.66)
	aether.emission_energy_multiplier = 1.5

	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)

	_chest = Node3D.new()
	_chest.name = "Chest"
	_chest.position = Vector3(0.0, HIP_Y, 0.0)
	_rig.add_child(_chest)
	_box(_chest, Vector3(0.46, 0.54, 0.26), Vector3(0.0, 0.27, 0.0), shirt)
	_box(_chest, Vector3(0.11, 0.09, 0.03), Vector3(0.0, 0.05, -0.16), aether)
	_box(_chest, Vector3(0.32, 0.06, 0.05), Vector3(0.0, 0.50, -0.13), aether)
	# a mochila nas costas da 3a pessoa: o que da volume ao personagem
	_box(_chest, Vector3(0.22, 0.30, 0.11), Vector3(0.0, 0.30, 0.17), leather)
	_box(_chest, Vector3(0.50, 0.13, 0.30), Vector3(0.0, 0.05, 0.0), leather)

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0, 0.54, 0.0)
	_chest.add_child(_head)
	_box(_head, Vector3(0.15, 0.10, 0.15), Vector3(0.0, 0.02, 0.0), skin)
	_box(_head, Vector3(0.40, 0.38, 0.40), Vector3(0.0, 0.24, 0.0), skin)
	_box(_head, Vector3(0.42, 0.13, 0.42), Vector3(0.0, 0.42, 0.006), hair)
	_box(_head, Vector3(0.42, 0.30, 0.09), Vector3(0.0, 0.27, 0.185), hair)
	_box(_head, Vector3(0.08, 0.06, 0.03), Vector3(-0.09, 0.27, -0.203), eye)
	_box(_head, Vector3(0.08, 0.06, 0.03), Vector3(0.09, 0.27, -0.203), eye)

	for side in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(SHOULDER_X * side, 0.48, 0.0)
		_chest.add_child(sh)
		# deltoides de camisa na linha do tronco: o braco e continuo ate o ombro
		_box(sh, Vector3(0.17, 0.32, 0.18), Vector3(0.0, -0.16, 0.0), shirt)
		var el := Node3D.new()
		el.position = Vector3(0.0, -0.32, 0.0)
		sh.add_child(el)
		_box(el, Vector3(0.15, 0.28, 0.16), Vector3(0.0, -0.14, 0.0), skin)
		_box(el, Vector3(0.16, 0.16, 0.17), Vector3(0.0, -0.35, 0.0), skin)
		_shoulders.append(sh)
		_elbows.append(el)

	# A mao do lado direito (indice 1) e a que carrega: o cubo e irmao da caixa
	# da mao sob o MESMO cotovelo, entao cada arco do braco leva o bloco junto.
	_held = MeshInstance3D.new()
	_held.name = "HeldBlock"
	_held.position = HELD_AT
	_held.rotation.y = 0.62
	_held.visible = false
	_elbows[1].add_child(_held)

	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.155 * side, HIP_Y, 0.0)
		_rig.add_child(hip)
		_box(hip, Vector3(0.22, THIGH, 0.25), Vector3(0.0, -THIGH * 0.5, 0.0), pants)
		var kn := Node3D.new()
		kn.position = Vector3(0.0, -THIGH, 0.0)
		hip.add_child(kn)
		_box(kn, Vector3(0.20, SHIN, 0.22), Vector3(0.0, -SHIN * 0.5, 0.0), pants)
		_box(kn, Vector3(0.23, 0.12, 0.31), Vector3(0.0, -SHIN - 0.02, -0.05), leather)
		_thighs.append(hip)
		_knees.append(kn)


func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## O material do cubo na mao e o material do mundo: atlas, tint por face, filtro
## nearest e o SOL do cenario acertando ele. Diferente do FPViewmodel de proposito
## -- la o membro mora na frente da lente e precisa de render_priority sem depth
## test para nao ser engolido pelo muro; aqui o bloco esta a dois metros da camera
## e um cubo que ignore profundidade flutuaria sobre a paisagem.
func _atlas_mat(alpha: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _atlas
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.85
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _box(p: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position = pos
	p.add_child(mi)
	return mi
