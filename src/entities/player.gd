class_name Player
extends Node3D
## Jogador local: predicao a 60 Hz (controle do proprio corpo), mundo autoritativo a
## 20 Hz. Camara 1a/3a pessoa com efeitos gateados por modo (bob/punch so em 1a).

signal block_broken(pos: Vector3i, block: int)
signal block_placed(pos: Vector3i, block: int)
signal damaged(amount: float, from: Vector3)
signal died(at: Vector3)
signal attacked(target: Node3D, amount: float)
signal acted(kind: String, pos: Vector3)
signal toggle_debug()
signal toggle_ether()
signal request_save()
signal request_load()

const DIMS_STAND := Vector3(0.62, 1.80, 0.62)
const DIMS_CROUCH := Vector3(0.62, 1.15, 0.62)
const EYE_STAND: float = 1.62
const EYE_CROUCH: float = 0.98
const REACH: float = 5.5
const HIGHLIGHT_IDLE := Color(0.05, 0.05, 0.06, 0.9)
const HIGHLIGHT_MINING := Color(1.0, 0.62, 0.16, 1.0)
const WALK_SPEED: float = 4.3
const SPRINT_SPEED: float = 6.9
const CROUCH_SPEED: float = 2.1
const GROUND_ACCEL: float = 46.0
const AIR_ACCEL: float = 11.0
const FRICTION: float = 13.0
const JUMP_SPEED: float = 8.2
const SWIM_UP_SPEED: float = 3.6
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.15
const ATTACK_DAMAGE: float = 14.0
const MOUSE_SENS: float = 0.0026
const PLACE_BUFFER: float = 0.22

var world: VoxelWorld = null
var body: VoxelBody = VoxelBody.new()
var camera: Camera3D = Camera3D.new()
var avatar: PlayerAvatar = PlayerAvatar.new()
var entity_provider: Callable

var yaw: float = 0.0
var pitch: float = 0.0
var third_person: bool = false
var crouching: bool = false
var sprinting: bool = false
var hp: float = 100.0
var max_hp: float = 100.0
var alive: bool = true
var deaths: int = 0
var spawn_point: Vector3 = Vector3.ZERO
var hotbar: Array[int] = []
var hotbar_index: int = 0
var target_valid: bool = false
var target_voxel: Vector3i = Vector3i.ZERO
var place_voxel: Vector3i = Vector3i.ZERO
var target_hardness: float = 0.0
var mining_progress: float = 0.0
var look_target_name: String = ""

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _place_cd: float = 0.0
var _place_buffer: float = 0.0
var _attack_cd: float = 0.0
var _bob_phase: float = 0.0
var _punch: float = 0.0
var _highlight: MeshInstance3D = null
var _highlight_mat: StandardMaterial3D = null
var _cursor_captured: bool = true
var _target_entity: Node3D = null
var _mining_voxel := Vector3i(-99999, -99999, -99999)
var _mining_accum: float = 0.0


func _ready() -> void:
	camera.name = "Camera3D"
	add_child(camera)
	camera.current = true
	avatar.name = "Avatar"
	add_child(avatar)
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mat.albedo_color = HIGHLIGHT_IDLE
	_highlight = MeshInstance3D.new()
	_highlight.mesh = _wire_cube(0.502)
	_highlight.mesh.surface_set_material(0, _highlight_mat)
	_highlight.visible = false
	add_child(_highlight)


## As 12 arestas do cubo como PRIMITIVE_LINES. Um BoxMesh com alfa era um painel
## leitoso sobre o alvo: parecia bloco transparente, nao contorno de selecao.
static func _wire_cube(h: float) -> ArrayMesh:
	var c := [
		Vector3(-h, -h, -h), Vector3(h, -h, -h), Vector3(h, -h, h), Vector3(-h, -h, h),
		Vector3(-h, h, -h), Vector3(h, h, -h), Vector3(h, h, h), Vector3(-h, h, h),
	]
	var e := [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7]]
	var v := PackedVector3Array()
	for p in e:
		v.append(c[p[0]])
		v.append(c[p[1]])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	return m


func setup(p_world: VoxelWorld, p_spawn: Vector3, p_blocks: Array[int]) -> void:
	world = p_world
	spawn_point = p_spawn
	body.setup(p_world, p_spawn, DIMS_STAND)
	hotbar = p_blocks.duplicate()
	feet_to_spawn(p_spawn)


func feet_to_spawn(p: Vector3) -> void:
	body.feet_pos = p
	body.velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0


func position3() -> Vector3:
	return body.feet_pos


func eye_position() -> Vector3:
	return body.feet_pos + Vector3(0.0, EYE_STAND if not crouching else EYE_CROUCH, 0.0)


func selected_block() -> int:
	if hotbar.is_empty():
		return BlockDefs.Block.STONE
	return hotbar[clampi(hotbar_index, 0, hotbar.size() - 1)]


## Bordas de input nascem aqui, no callback do evento, e viram acao no proximo
## tick. Lidas dentro de _physics_process elas se perdem: medido nesta maquina,
## 163 quadros desenhados por segundo contra 59,8 ticks -> 63,3% dos quadros nao
## tem tick nenhum, e o clique que cai num deles nunca e visto.
func _input(event: InputEvent) -> void:
	if not _cursor_captured or not alive:
		return
	if event.is_action_pressed("place_block"):
		_place_buffer = PLACE_BUFFER
	elif event.is_action_pressed("jump"):
		_jump_buffer = JUMP_BUFFER


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _cursor_captured and alive:
		yaw -= event.relative.x * MOUSE_SENS
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -1.5, 1.5)
	if event.is_action_pressed("release_cursor"):
		_set_captured(not _cursor_captured)
	elif event.is_action_pressed("switch_camera"):
		third_person = not third_person
	elif event.is_action_pressed("toggle_debug"):
		toggle_debug.emit()
	elif event.is_action_pressed("toggle_ether_view"):
		toggle_ether.emit()
	elif event.is_action_pressed("save_game"):
		request_save.emit()
	elif event.is_action_pressed("load_game"):
		request_load.emit()
	elif event is InputEventMouseButton and _cursor_captured and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_slot(hotbar_index - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_slot(hotbar_index + 1)
	for i in InputActions.HOTBAR_ACTIONS.size():
		if event.is_action_pressed(InputActions.HOTBAR_ACTIONS[i]):
			select_slot(i)
			break


func select_slot(i: int) -> void:
	if hotbar.is_empty():
		return
	hotbar_index = posmod(i, hotbar.size())


func _set_captured(v: bool) -> void:
	_cursor_captured = v
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if v else Input.MOUSE_MODE_VISIBLE


func take_damage(amount: float, from: Vector3) -> void:
	if not alive:
		return
	hp = maxf(hp - amount, 0.0)
	_punch = minf(_punch + amount * 0.02, 0.55)
	damaged.emit(amount, from)
	if hp <= 0.0:
		die()


func die() -> void:
	deaths += 1
	alive = false
	_place_buffer = 0.0
	_jump_buffer = 0.0
	died.emit(body.feet_pos)


func respawn_at(p: Vector3) -> void:
	hp = max_hp
	alive = true
	feet_to_spawn(p)
	_set_captured(true)


# ------------------------------------------------------------------ passo local (60 Hz)

func update_local(delta: float) -> void:
	if not alive:
		_update_camera(delta)
		_update_avatar(delta)
		return
	_place_cd = maxf(_place_cd - delta, 0.0)
	_place_buffer = maxf(_place_buffer - delta, 0.0)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_coyote = _coyote + delta if body.on_ground else 0.0

	var wish := _wish_direction()
	_apply_horizontal(wish, delta)
	_apply_vertical(wish, delta)
	body.move_and_collide(delta)
	_update_target()
	_apply_actions(delta)
	_update_camera(delta)
	_update_avatar(delta)


## O no do Player fica parado (quem anda e body.feet_pos), entao o avatar e
## reposicionado a cada tick e gira com o yaw: -Z local = para frente.
func _update_avatar(delta: float) -> void:
	avatar.third_person = third_person
	avatar.walk_speed = Vector3(body.velocity.x, 0.0, body.velocity.z).length()
	avatar.vertical = body.velocity.y
	avatar.on_ground = body.on_ground
	avatar.in_water = body.in_water
	avatar.crouching = crouching
	avatar.pitching = pitch
	avatar.mining = _mining_accum > 0.0
	avatar.dead = not alive
	avatar.global_position = body.feet_pos
	avatar.global_rotation = Vector3(0.0, yaw, 0.0)
	avatar.advance(delta)


func _wish_direction() -> Vector3:
	var f := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var r := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	sprinting = Input.is_action_pressed("sprint") and f > 0.0
	crouching = Input.is_action_pressed("crouch")
	var dir := Vector3.ZERO
	if absf(f) > 0.01 or absf(r) > 0.01:
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		dir = (forward * f + right * r).normalized()
	return dir


func _apply_horizontal(wish: Vector3, delta: float) -> void:
	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting and not body.in_water:
		speed = SPRINT_SPEED
	var v := body.velocity
	if body.on_ground:
		var horiz := Vector3(v.x, 0.0, v.z)
		if wish == Vector3.ZERO:
			var drop := FRICTION * delta
			var norm := horiz.length()
			if norm <= drop:
				horiz = Vector3.ZERO
			else:
				horiz = horiz * (norm - drop) / norm
		else:
			horiz = horiz.lerp(wish * speed, clampf(GROUND_ACCEL * delta / speed, 0.0, 1.0))
			var mag := horiz.length()
			if mag > speed:
				horiz = horiz * speed / mag
		v.x = horiz.x
		v.z = horiz.z
	else:
		if wish != Vector3.ZERO:
			var air := Vector3(v.x, 0.0, v.z)
			air = air.lerp(wish * speed, clampf(AIR_ACCEL * delta / speed, 0.0, 1.0))
			v.x = air.x
			v.z = air.z
	body.velocity = v


func _apply_vertical(wish: Vector3, delta: float) -> void:
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_coyote = minf(_coyote, COYOTE_TIME)

	if body.in_water:
		body.apply_gravity(delta, 0.34)
		body.velocity.y = maxf(body.velocity.y, -2.4)
		if Input.is_action_pressed("jump"):
			body.velocity.y = SWIM_UP_SPEED
		return

	if _jump_buffer > 0.0 and _coyote > 0.0:
		body.velocity.y = JUMP_SPEED
		_jump_buffer = 0.0
		_coyote = 0.0
	body.apply_gravity(delta)

	# crouch so quando ha teto livre
	var want_dims := DIMS_CROUCH if crouching else DIMS_STAND
	if want_dims != body.dims:
		var test := body.aabb()
		test.size = want_dims
		if crouching or not world.aabb_hits_solid(test):
			body.dims = want_dims


func _update_target() -> void:
	# em 3a pessoa o raio sai da camera para o alvo ficar sob a mira; o alcance
	# (REACH) continua medido do corpo, como o aim_point do Veloren
	var eye := eye_position()
	var origin := camera.global_position if third_person else eye
	var dir := camera.global_transform.basis.z * -1.0
	var span := REACH + origin.distance_to(eye)
	var hit := world.ray_voxel(origin, dir, span)
	var hit_d := (origin + dir * hit.distance - eye).length() if hit.valid else span + 1.0
	var best_d := hit_d
	var best_entity: Node3D = null
	look_target_name = ""
	if entity_provider.is_valid():
		for e in entity_provider.call():
			if not (e is Node3D):
				continue
			var box: AABB = e.body_aabb()
			var d := ray_aabb(origin, dir, box)
			if d <= 0.0:
				continue
			var dp := (origin + dir * d - eye).length()
			if dp <= REACH and dp < best_d:
				best_d = dp
				best_entity = e
				look_target_name = e.target_name()
	_target_entity = best_entity
	target_valid = hit.valid and best_entity == null and hit_d <= REACH
	target_voxel = hit.voxel
	place_voxel = hit.voxel + hit.normal
	target_hardness = _hardness(hit.block) if target_valid else 0.0
	mining_progress = 0.0 if not target_valid else _progress_of(hit.voxel)
	_highlight.visible = target_valid
	if target_valid:
		_highlight.global_position = Vector3(target_voxel) + Vector3(0.5, 0.5, 0.5)
		_highlight_mat.albedo_color = HIGHLIGHT_IDLE.lerp(HIGHLIGHT_MINING, mining_progress)


func _progress_of(v: Vector3i) -> float:
	if v != _mining_voxel:
		_mining_voxel = v
		_mining_accum = 0.0
	return clampf(_mining_accum / maxf(target_hardness, 0.05), 0.0, 1.0)


static func _hardness(b: int) -> float:
	match b:
		BlockDefs.Block.STONE: return 0.95
		BlockDefs.Block.WOOD: return 0.55
		BlockDefs.Block.LEAVES: return 0.22
		BlockDefs.Block.DIRT: return 0.35
		BlockDefs.Block.GRASS: return 0.38
		BlockDefs.Block.SAND: return 0.30
		BlockDefs.Block.SNOW: return 0.25
		_: return 0.4
	return 0.4


func _apply_actions(delta: float) -> void:
	if Input.is_action_pressed("break_block"):
		if _target_entity != null and _attack_cd <= 0.0:
			_attack_cd = 0.42
			_punch = minf(_punch + 0.10, 0.5)
			avatar.swing()
			attacked.emit(_target_entity, ATTACK_DAMAGE)
		elif target_valid:
			_mining_accum += delta
			if _mining_accum >= target_hardness:
				_mining_accum = 0.0
				var b := world.get_block(target_voxel)
				if world.set_block(target_voxel, BlockDefs.Block.AIR):
					avatar.swing()
					block_broken.emit(target_voxel, b)
					acted.emit("break", Vector3(target_voxel) + Vector3(0.5, 0.5, 0.5))
	# Construir e uma intencao separada da de minerar: segurar o botao esquerdo
	# (lavrando um bloco duro) nao engole o clique direito do meio da obra.
	if _place_buffer > 0.0 and _place_cd <= 0.0:
		_place_buffer = 0.0
		_try_place()


func _try_place() -> void:
	if not target_valid:
		return
	if not VoxelConfig.in_world_bounds(place_voxel):
		return
	var b := world.get_block(place_voxel)
	if b != BlockDefs.Block.AIR and b != BlockDefs.Block.WATER:
		return
	var pb := AABB(Vector3(place_voxel), Vector3.ONE)
	if body.aabb().intersects(pb):
		return
	_place_cd = 0.16
	if world.set_block(place_voxel, selected_block()):
		block_placed.emit(place_voxel, selected_block())
		acted.emit("place", Vector3(place_voxel) + Vector3(0.5, 0.5, 0.5))


# ------------------------------------------------------------------ camera

func _update_camera(delta: float) -> void:
	var eye := eye_position()
	var rot := Basis.from_euler(Vector3(0.0, yaw, 0.0)) * Basis.from_euler(Vector3(pitch, 0.0, 0.0))
	# bob e punch sao exclusivos da 1a pessoa: em 3a pessoa estragariam o enquadramento
	var bob_y := 0.0
	var bob_roll := 0.0
	if not third_person and body.on_ground:
		var planar := Vector3(body.velocity.x, 0.0, body.velocity.z)
		var speed := planar.length()
		if speed > 0.4:
			_bob_phase += delta * (4.6 + speed * 0.55)
			var amp := clampf(speed / SPRINT_SPEED, 0.0, 1.0)
			bob_y = sin(_bob_phase * 2.0) * 0.030 * amp
			bob_roll = sin(_bob_phase) * 0.010 * amp
	_punch = maxf(_punch - delta * 2.2, 0.0)
	var punch_pitch := _punch * 0.10 if not third_person else 0.0
	var final_rot := rot.rotated(rot.z, bob_roll)
	final_rot = final_rot.rotated(final_rot.x, punch_pitch)
	camera.global_transform = Transform3D(final_rot, eye + Vector3(0.0, bob_y, 0.0))

	if third_person:
		# orbita o centro do corpo (focus do Veloren), nao a cabeca: olhar para
		# cima e para baixo nao arrasta a camera por cima do cranio
		var pivot := body.feet_pos + Vector3(0.0, 1.0, 0.0)
		var back_n := final_rot.z.normalized()
		var dist := 4.4
		var hit := world.ray_voxel(pivot, back_n, 4.4)
		if hit.valid:
			dist = maxf(hit.distance - 0.35, 0.0)
			if hit.distance > 1.1:
				dist = maxf(dist, 0.75)
		var cp := pivot + back_n * dist
		# olhar para cima encosta a camera no chao por tras e o near-plane fura
		# o terreno; levanta ate ~28 cm acima da primeira superficie abaixo dela
		var down := world.ray_voxel(cp + Vector3(0.0, 0.6, 0.0), Vector3.DOWN, 1.2)
		if down.valid and down.distance > 0.0:
			cp.y = maxf(cp.y, cp.y + 0.88 - down.distance)
		camera.global_position = cp


## Slab method: distancia de um raio a um AABB, ou -1 se nao acerta.
static func ray_aabb(origin: Vector3, dir: Vector3, box: AABB) -> float:
	var tmin := 0.0
	var tmax := 1000.0
	for axis in 3:
		var o: float = origin[axis]
		var d: float = dir[axis]
		var lo: float = box.position[axis]
		var hi: float = box.end[axis]
		if absf(d) < 1e-8:
			if o < lo or o > hi:
				return -1.0
			continue
		var t1 := (lo - o) / d
		var t2 := (hi - o) / d
		if t1 > t2:
			var tmp := t1
			t1 = t2
			t2 = tmp
		tmin = maxf(tmin, t1)
		tmax = minf(tmax, t2)
		if tmin > tmax:
			return -1.0
	return tmin
