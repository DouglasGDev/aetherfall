class_name FPViewmodel
extends Node3D
## Braco e bloco desenhados para a lente: este no e filho da Camera3D, entao cada
## transformada abaixo esta em coordenadas de camera (-Z = para onde se olha,
## +X = direita, +Y = cima). Em 1a pessoa o rig de 3a pessoa sai de quadro e o que
## fica e somente isto; em 3a e o contrario. Um corpo por vista, nunca os dois ao
## mesmo tempo.
##
## Os comprimentos NAO sao os do rig de 3a pessoa (ali: 0,32 de braco + 0,28 de
## antebraco). O view model e encurtado de proposito: com o braco inteiro o punho
## cairia a 60 cm da lente, pequeno demais para ler o material do bloco. As
## seccoes transversais, essas sim, sao as do personagem (0,15/0,13 de braco) e as
## cores continuam as mesmas -- o membro na frente da lente e o mesmo corpo.

const PACE := 4.3
const UPPER := 0.24
const FORE := 0.22
const HELD_SIZE := 0.16
## Ombro na lente: encostado na borda direita, uma palma abaixo do olho. Ele
## mesmo fica FORA do quadro (a meio metro de profundidade a metade da altura da
## tela e 13 cm) -- o braco entra pela borda, como em Minecraft, e o que se ve
## do membro e o antebraco, a mao e o bloco.
const SHOULDER_AT := Vector3(0.46, -0.20, -0.16)
## O braco aponta para dentro, nao paralelo a lente: paralelo, todo o membro fica
## na coluna x=0,44 e so comeca a aparecer quando o tronco de visao abre o
## suficiente -- o quadro mostra uma prancha lisa vinda do canto, sem cotovelo.
## Com este yaw o ombro e a manga entram pela borda direita e o punho chega ao
## quadrante inferior direito em diagonal, com as articulacoes visiveis.
const ARM_YAW := 0.34
## O bloco sai da mao encostado nela, um dedo acima: afastado, o punho fica
## solto atras do cubo e parece que nada segura nada.
const BLOCK_AT := Vector3(-0.005, -0.015, -0.115)

var walk_speed := 0.0
var vertical := 0.0
var on_ground := true
var mining := false
var dead := false
var block_id: int = BlockDefs.Block.AIR

var _rig: Node3D = null
var _shoulder: Node3D = null
var _elbow: Node3D = null
var _hand: Node3D = null
var _grip: Node3D = null
var _held: MeshInstance3D = null
var _atlas: Texture2D = null
var _mat_block: StandardMaterial3D = null
var _mat_block_alpha: StandardMaterial3D = null
var _mesh_for := -1
var _phase := 0.0
var _amp := 0.0
var _air := 0.0
var _dig := 0.0
var _swing := 0.0
var _dead := 0.0


## Impulso de golpe: sobe e corta para frente, volta sozinho em ~1/3 s.
func swing() -> void:
	_swing = 1.0


## O atlas vem do mundo: sem ele o bloco na mao seria um cubo de cor chutada.
func set_atlas(tex: Texture2D) -> void:
	_atlas = tex
	_mat_block = _atlas_mat(false)
	_mat_block_alpha = _atlas_mat(true)
	_mesh_for = -1


func advance(delta: float) -> void:
	var smooth := 1.0 - exp(-13.0 * delta)
	_amp = lerpf(_amp, clampf(walk_speed / PACE, 0.0, 1.0), smooth)
	_air = lerpf(_air, 0.0 if on_ground else 1.0, smooth)
	_dig = lerpf(_dig, 1.0 if mining else 0.0, smooth)
	_dead = lerpf(_dead, 1.0 if dead else 0.0, smooth)
	_swing = maxf(_swing - delta * 3.0, 0.0)
	_phase += delta * (2.4 + 1.05 * walk_speed)
	_sync_held()
	_pose()


## Angulo do ombro e do cotovelo: a prova de que o arco de lavra e o de golpe
## mexem o braco, medida no mesmo eixo que a lente ve.
func arm_angles() -> Vector2:
	return Vector2(_shoulder.rotation.x, _elbow.rotation.x)


## O cubo que esta na mao, para quem precisa medir o enquadramento sem conhecer
## os nomes internos do rig.
func held_mesh() -> MeshInstance3D:
	return _held


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
	var s0 := sin(_phase)
	var breath := sin(_phase * 1.1) * (1.0 - minf(_amp, 1.0))
	# base: braco pendurado para frente, antebraco dobrado para cima -- o bloco
	# fica embaixo e a direita, com a face de cima e duas laterais legiveis
	var sh := -0.30 + breath * 0.04
	var el := 0.75
	var sway := Vector3.ZERO
	var rz := 0.0

	if _amp > 0.01:
		sway = Vector3(s0 * 0.012 * _amp, sin(_phase * 2.0) * 0.018 * _amp, 0.0)
		sh += s0 * 0.18 * _amp
		el += 0.08 * _amp * absf(s0)
		rz = -s0 * 0.05 * _amp
	if _air > 0.01:
		sh = lerpf(sh, 0.20, _air)
		el = lerpf(el, 0.40, _air)
	if _dig > 0.01:
		var c := sin(_phase * 3.4)
		sh = lerpf(sh, -0.05 + 0.30 * c, _dig)
		el = lerpf(el, 0.55 + 0.20 * c, _dig)
	if _swing > 0.0:
		# tres tempos ATRIBUIDOS, nao buscados: como meta de um amortecimento de
		# 13/s o impulso de 1/3 s mal comeca a mover o braco e o soco vira
		# tremida. O arco sai da pose que o braco ja tinha (andando, minerando,
		# parado) e volta para ela.
		var s0p := sh
		var e0p := el
		var t := 1.0 - _swing
		if t < 0.20:
			var k := _ease(t / 0.20)
			sh = lerpf(s0p, s0p + 0.30, k)
			el = lerpf(e0p, e0p + 0.30, k)
			sway.z = lerpf(sway.z, 0.05, k)
		elif t < 0.55:
			var k := _ease((t - 0.20) / 0.35)
			sh = lerpf(s0p + 0.30, s0p - 0.15, k)
			el = lerpf(e0p + 0.30, e0p - 0.45, k)
			sway.z = lerpf(0.05, -0.10, k)
			sway.x = lerpf(sway.x, -0.03, k)
		else:
			var k := _ease((t - 0.55) / 0.45)
			sh = lerpf(s0p - 0.15, s0p, k)
			el = lerpf(e0p - 0.45, e0p, k)
			sway.z = lerpf(-0.10, sway.z, k)
			sway.x = lerpf(-0.03, sway.x, k)
	if _dead > 0.01:
		sh = lerpf(sh, -0.95, _dead)
		el = lerpf(el, 0.10, _dead)
		sway.y = lerpf(sway.y, -0.08, _dead)

	_rig.position = sway
	_rig.rotation.z = rz
	_shoulder.rotation = Vector3(sh, ARM_YAW, -0.06)
	_elbow.rotation.x = el


func _ease(x: float) -> float:
	var v := clampf(x, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


func _ready() -> void:
	var skin := Color(0.74, 0.58, 0.45)
	var fist := Color(0.66, 0.51, 0.40)
	var shirt := _vm_mat(Color(0.22, 0.34, 0.50), 10)
	var hem := _vm_mat(Color(0.26, 0.39, 0.56), 11)
	var skin_arm := _vm_mat(skin, 11)
	var skin_hand := _vm_mat(fist, 12)
	var finger := _vm_mat(Color(0.60, 0.46, 0.36), 14)

	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_shoulder = Node3D.new()
	_shoulder.name = "Shoulder"
	_shoulder.position = SHOULDER_AT
	_rig.add_child(_shoulder)
	_box(_shoulder, Vector3(0.15, 0.15, 0.17), Vector3(0.0, 0.01, -0.05), shirt)
	_box(_shoulder, Vector3(0.13, 0.13, UPPER), Vector3(0.0, 0.0, -UPPER * 0.5), shirt)

	_elbow = Node3D.new()
	_elbow.name = "Elbow"
	_elbow.position = Vector3(0.0, 0.0, -UPPER)
	_shoulder.add_child(_elbow)
	# barra da manga no cotovelo: o personagem de 3a pessoa tem manga curta, e sem
	# a barra o braco seria um tubo de uma cor so ate a mao
	_box(_elbow, Vector3(0.145, 0.145, 0.06), Vector3(0.0, 0.0, 0.005), hem)
	_box(_elbow, Vector3(0.115, 0.115, FORE), Vector3(0.0, 0.0, -FORE * 0.5), skin_arm)

	_hand = Node3D.new()
	_hand.name = "Hand"
	_hand.position = Vector3(0.0, 0.0, -FORE)
	_elbow.add_child(_hand)
	_box(_hand, Vector3(0.125, 0.115, 0.12), Vector3(0.0, -0.015, -0.05), skin_hand)

	_grip = Node3D.new()
	_grip.name = "Grip"
	_hand.add_child(_grip)
	# folga de 1,2 cm entre os dedos: colados, eles viram uma luva so e o bloco
	# parece prensado contra um osso, nao segurado por uma mao
	for y in [-0.062, -0.030, 0.002]:
		_box(_grip, Vector3(0.088, 0.018, 0.03), Vector3(-0.005, y, -0.075), finger)
	_box(_grip, Vector3(0.026, 0.026, 0.085), Vector3(-0.066, 0.022, -0.09), finger)

	_held = MeshInstance3D.new()
	_held.name = "HeldBlock"
	_held.position = BLOCK_AT
	_held.rotation.y = 0.62
	_held.visible = false
	_hand.add_child(_held)


# Camadas sem depth test impedem que paredes escondam o membro junto da lente.
func _vm_mat(c: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.render_priority = priority
	return m


func _atlas_mat(alpha: bool) -> StandardMaterial3D:
	# Sem depth test, o bloco precisa cobrir os dedos para nao parecer furado.
	var m := _vm_mat(Color(1.0, 1.0, 1.0), 15)
	m.albedo_texture = _atlas
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
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
