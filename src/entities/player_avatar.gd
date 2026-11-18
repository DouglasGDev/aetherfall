class_name PlayerAvatar
extends Node3D
## Corpo voxel do jogador: a geometria que existe quando a camera nao esta dentro
## da cabeca. Sao pivots articulados (quadril, joelho, ombro, cotovelo) com uma
## caixa por segmento; o Player escreve o estado e chama advance(delta).
##
## A silhueta fecha em 1,76 m contra 1,80 m da AABB do corpo, e a linha dos olhos
## (1,62) fica dentro da cabeca: em 1a pessoa so a cabeca sai de cena, porque e ai
## que mora a camera. O resto do corpo continua na cena e aparece na beirada de
## baixo quando o jogador olha para os proprios pes. Nunca ha dois corpos em quadro.

const PACE := 4.3
const HIP_Y := 0.80
const THIGH := 0.40
const SHIN := 0.32
const CROUCH_DROP := 0.40

var third_person := true
var walk_speed := 0.0
var vertical := 0.0
var on_ground := true
var in_water := false
var crouching := false
var pitching := 0.0
var mining := false
var dead := false

var _rig: Node3D = null
var _chest: Node3D = null
var _head: Node3D = null
var _thighs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _phase := 0.0
var _amp := 0.0
var _air := 0.0
var _rise := 0.0
var _swim := 0.0
var _crouch := 0.0
var _dig := 0.0
var _swing := 0.0


## Impulso de golpe: o braco direito faz o arco e volta sozinho.
func swing() -> void:
	_swing = 1.0


## Leituras do estado visual, usadas pelo smoke test.
func head_shown() -> bool:
	return _head.visible


func advance(delta: float) -> void:
	_head.visible = third_person
	var smooth := 1.0 - exp(-13.0 * delta)
	var norm := clampf(walk_speed / PACE, 0.0, 1.35)
	_amp = lerpf(_amp, norm * (0.55 if crouching else 1.0), smooth)
	_air = lerpf(_air, 0.0 if on_ground else 1.0, smooth)
	_rise = lerpf(_rise, clampf(vertical / 10.0, -1.0, 1.0), smooth)
	_swim = lerpf(_swim, 1.0 if (in_water and not on_ground) else 0.0, smooth)
	_crouch = lerpf(_crouch, 1.0 if (crouching and on_ground) else 0.0, smooth)
	_dig = lerpf(_dig, 1.0 if mining else 0.0, smooth)
	_swing = maxf(_swing - delta * 2.8, 0.0)
	_phase += delta * (2.0 + 1.05 * walk_speed)
	if dead:
		_pose_dead(smooth)
	else:
		_pose()


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
	var lean := -0.05 * a
	var bob := absf(s0) * 0.035 * a
	var roll := s0 * 0.020 * a
	var breath := sin(_phase * 2.2) * (1.0 - minf(a, 1.0))

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
		var c := sin(_phase * 3.4)
		sh[1] = lerpf(sh[1], -0.95 + 0.80 * c, _dig)
		el[1] = lerpf(el[1], 0.60 - 0.40 * c, _dig)

	if _swing > 0.0:
		var t := 1.0 - _swing
		var e := t * t * (3.0 - 2.0 * t)
		var wt := minf(_swing * 2.5, 1.0)
		sh[1] = lerpf(sh[1], lerpf(-1.95, 0.95, e), wt)
		el[1] = lerpf(el[1], lerpf(1.05, 0.10, e), wt)
		lean = lerpf(lean, lerpf(-0.30, 0.14, e), wt * 0.7)

	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_thighs[i].rotation.x = thigh[i]
		_thighs[i].rotation.z = 0.0
		_knees[i].rotation.x = knee[i]
		_shoulders[i].rotation.x = sh[i]
		_shoulders[i].rotation.z = s * 0.07
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
	_box(_chest, Vector3(0.50, 0.13, 0.30), Vector3(0.0, 0.05, 0.0), leather)
	_box(_chest, Vector3(0.11, 0.09, 0.03), Vector3(0.0, 0.05, -0.16), aether)
	_box(_chest, Vector3(0.32, 0.06, 0.05), Vector3(0.0, 0.50, -0.13), aether)
	_box(_chest, Vector3(0.22, 0.30, 0.11), Vector3(0.0, 0.30, 0.17), leather)

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
		sh.position = Vector3(0.30 * side, 0.48, 0.0)
		_chest.add_child(sh)
		_box(sh, Vector3(0.17, 0.32, 0.18), Vector3(0.0, -0.16, 0.0), shirt)
		var el := Node3D.new()
		el.position = Vector3(0.0, -0.32, 0.0)
		sh.add_child(el)
		_box(el, Vector3(0.15, 0.28, 0.16), Vector3(0.0, -0.14, 0.0), skin)
		_box(el, Vector3(0.16, 0.16, 0.17), Vector3(0.0, -0.35, 0.0), skin)
		_shoulders.append(sh)
		_elbows.append(el)

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


func _box(p: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position = pos
	p.add_child(mi)
