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
## O painel de inventario abriu/fechou: quem desenha a tela (Hud) e quem trava o
## resto do input (aqui) ficam em acordo por este sinal, sem referencia cruzada.
signal panel_changed(open: bool)
## Aviso curto ao jogador (inventario cheio, slot vazio, craft sem estacao).
signal notice(text: String)

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
# vigor (a stamina do Veloren): correr drena, parar recupera, golpe acertado devolve
const MAX_ENERGY: float = 100.0
const ENERGY_REGEN: float = 12.0
const SPRINT_DRAIN: float = 8.0
const SPRINT_RECOVERY: float = 18.0
const ATTACK_ENERGY: float = 6.0
# rolamento (botao do meio no Veloren): custo fixo, janela de invencibilidade e recarga;
# atravessa a mordida do lobo sem levar dano
const ROLL_COST: float = 14.0
const ROLL_SPEED: float = 10.5
const ROLL_TIME: float = 0.35
const ROLL_IFRAMES: float = 0.45
const ROLL_CD: float = 0.9
const ROLL_BUFFER: float = 0.18
# planar (segurar CTRL no ar, como o Veloren): gravidade e o combustivel, olhar para
# baixo mergulha e ganha velocidade horizontal, olhar para cima perde; nao gasta vigor
const GLIDE_SPEED: float = 5.4
const GLIDE_DIVE_GAIN: float = 5.0
const GLIDE_STALL: float = 2.4
const GLIDE_DIVE_SPEED: float = 11.5
const GLIDE_STEER: float = 5.5
const GLIDE_GRAVITY: float = 0.16
const GLIDE_SINK: float = 1.8
const GLIDE_DIVE_SINK: float = 4.8
# respiracao: embaixo d'agua o ar acaba e o afogamento cobra por periodo;
# fora da agua enche em ~1 s, como emergir no Veloren
const AIR_MAX: float = 14.0
const AIR_REFILL: float = 14.0
const DROWN_PERIOD: float = 1.0
const DROWN_DAMAGE: float = 7.0
# queda: impacto acima da velocidade segura machuca; agua perdoa e planar nunca chega la
const FALL_SAFE_SPEED: float = 14.0
const FALL_DAMAGE_PER_SPEED: float = 3.5
const FALL_DAMAGE_MAX: float = 55.0
# regeneracao fora de combate (Veloren): quieto e com vigor sobrando
const REGEN_DELAY: float = 8.0
const REGEN_MIN_ENERGY: float = 25.0
const REGEN_RATE: float = 1.2

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
var inv: Inventory = Inventory.new()
var panel_open: bool = false
# Quem responde "tem bancada por perto": Main guarda as bancadas colocadas.
var bench_provider: Callable = Callable()
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
var energy: float = MAX_ENERGY
var max_energy: float = MAX_ENERGY
var air: float = AIR_MAX
var gliding: bool = false
var _sprint_locked: bool = false
var _iframes: float = 0.0
var _roll_cd: float = 0.0
var _roll_time: float = 0.0
var _roll_buffer: float = 0.0
var _drown_cd: float = DROWN_PERIOD
var _since_damage: float = REGEN_DELAY
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


func setup(p_world: VoxelWorld, p_spawn: Vector3) -> void:
	world = p_world
	spawn_point = p_spawn
	body.setup(p_world, p_spawn, DIMS_STAND)
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
	return inv.selected_block()


## Bancada a no maximo `Recipes.BENCH_RANGE` metros do jogador. Varrido sobre a
## lista de bancadas colocadas, nunca sobre o mundo: e a busca que o Veloren faz
## por sprite proximo (craft_sprite casado dentro de MAX_PICKUP_RANGE).
func bench_near() -> bool:
	if not bench_provider.is_valid():
		return false
	var origin := body.feet_pos
	var list: Array[Vector3i] = bench_provider.call()
	for p in list:
		var center := Vector3(float(p.x) + 0.5, float(p.y) + 0.5, float(p.z) + 0.5)
		if center.distance_to(origin) <= Recipes.BENCH_RANGE:
			return true
	return false


## Bordas de input nascem aqui, no callback do evento, e viram acao no proximo
## tick. Lidas dentro de _physics_process elas se perdem: medido nesta maquina,
## 163 quadros desenhados por segundo contra 59,8 ticks -> 63,3% dos quadros nao
## tem tick nenhum, e o clique que cai num deles nunca e visto.
func _input(event: InputEvent) -> void:
	if not _cursor_captured or not alive or panel_open:
		return
	if event.is_action_pressed("place_block"):
		_place_buffer = PLACE_BUFFER
	elif event.is_action_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	elif event.is_action_pressed("roll"):
		_roll_buffer = ROLL_BUFFER


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _cursor_captured and alive:
		yaw -= event.relative.x * MOUSE_SENS
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -1.5, 1.5)
	# O painel e a unica coisa que abre por aqui: quem navega nele e o Hud, e o
	# Player so segura o portao do resto do input.
	if event.is_action_pressed("toggle_inventory"):
		_set_panel(not panel_open)
		return
	if panel_open:
		# ESC fecha a tela em vez de soltar o cursor: com o painel aberto o cursor
		# ja esta livre para o look, e a saida que o jogador procura e esta.
		if event.is_action_pressed("release_cursor"):
			close_panel()
		return
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
			select_slot(inv.hotbar_index - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_slot(inv.hotbar_index + 1)
	for i in InputActions.HOTBAR_ACTIONS.size():
		if event.is_action_pressed(InputActions.HOTBAR_ACTIONS[i]):
			select_slot(i)
			break


func select_slot(i: int) -> void:
	inv.select(i)


func _set_panel(v: bool) -> void:
	if panel_open == v:
		return
	panel_open = v
	if not v:
		inv.stash_hand()
		_place_buffer = 0.0
		_jump_buffer = 0.0
		_roll_buffer = 0.0
		_mining_accum = 0.0
	panel_changed.emit(v)


## Fechar com pilha na mao so quando ela tem para onde voltar: sem entidade de
## item no chao ainda, perder a pilha por um ESC seria o pior bug do inventario.
func close_panel() -> void:
	if not panel_open:
		return
	if inv.held_count > 0 and not inv.stash_hand():
		notice.emit("inventario cheio: a pilha na mao precisa de um buraco")
		return
	_set_panel(false)


func _set_captured(v: bool) -> void:
	_cursor_captured = v
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if v else Input.MOUSE_MODE_VISIBLE


func take_damage(amount: float, from: Vector3) -> void:
	if not alive or _iframes > 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	_since_damage = 0.0
	_punch = minf(_punch + amount * 0.02, 0.55)
	damaged.emit(amount, from)
	if hp <= 0.0:
		die()


func die() -> void:
	deaths += 1
	alive = false
	_place_buffer = 0.0
	_jump_buffer = 0.0
	_roll_buffer = 0.0
	_roll_time = 0.0
	_iframes = 0.0
	gliding = false
	died.emit(body.feet_pos)


func respawn_at(p: Vector3) -> void:
	hp = max_hp
	alive = true
	energy = max_energy
	air = AIR_MAX
	_sprint_locked = false
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
	_roll_cd = maxf(_roll_cd - delta, 0.0)
	_roll_time = maxf(_roll_time - delta, 0.0)
	_iframes = maxf(_iframes - delta, 0.0)
	_coyote = _coyote + delta if body.on_ground else 0.0

	var wish := _wish_direction()
	_apply_energy(delta, wish)
	_try_roll(wish)
	_apply_horizontal(wish, delta)
	_apply_vertical(wish, delta)
	var pre_vy := body.velocity.y
	body.move_and_collide(delta)
	_check_fall_impact(pre_vy)
	_update_breath(delta)
	_apply_regen(delta)
	_update_target()
	_apply_actions(delta)
	_update_camera(delta)
	_update_avatar(delta)


## O no do Player fica parado (quem anda e body.feet_pos), entao o avatar e
## reposicionado a cada tick e gira com o yaw: -Z local = para frente.
func _update_avatar(delta: float) -> void:
	var fp := not third_person
	if fp != avatar.first_person:
		avatar.set_first_person(fp)
	avatar.walk_speed = Vector3(body.velocity.x, 0.0, body.velocity.z).length()
	avatar.vertical = body.velocity.y
	avatar.on_ground = body.on_ground
	avatar.in_water = body.in_water
	avatar.crouching = crouching
	avatar.pitching = pitch
	avatar.gliding = gliding
	avatar.rolling = _roll_time > 0.0
	avatar.mining = _mining_accum > 0.0
	avatar.dead = not alive
	avatar.global_position = body.feet_pos
	avatar.global_rotation = Vector3(0.0, yaw, 0.0)
	avatar.advance(delta)


func _wish_direction() -> Vector3:
	# com o painel aberto o mesmo teclado que anda passa a mover o cursor da grade:
	# andar com as setas nao e opcao. A corrida cai, o agachar fica como esta.
	if panel_open:
		sprinting = false
		return Vector3.ZERO
	var f := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var r := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	# trava com histerese: o vigor zerado corta a corrida ate voltar a SPRINT_RECOVERY
	sprinting = Input.is_action_pressed("sprint") and f > 0.0 and not _sprint_locked
	crouching = Input.is_action_pressed("crouch")
	var dir := Vector3.ZERO
	if absf(f) > 0.01 or absf(r) > 0.01:
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		dir = (forward * f + right * r).normalized()
	return dir


func _apply_horizontal(wish: Vector3, delta: float) -> void:
	var speed := WALK_SPEED
	if crouching and body.on_ground:
		speed = CROUCH_SPEED
	elif sprinting and not body.in_water:
		speed = SPRINT_SPEED
	var v := body.velocity
	if body.on_ground:
		var horiz := Vector3(v.x, 0.0, v.z)
		if _roll_time > 0.0:
			# durante o rolamento o controle normal nao engole o impulso: so o atrito
			var drop := FRICTION * delta
			var norm := horiz.length()
			if norm <= drop:
				horiz = Vector3.ZERO
			else:
				horiz = horiz * (norm - drop) / norm
			v.x = horiz.x
			v.z = horiz.z
			body.velocity = v
			return
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
		if gliding:
			# o planar direciona o voo inteiro em _apply_vertical
			pass
		elif wish != Vector3.ZERO:
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
		if not panel_open and Input.is_action_pressed("jump"):
			body.velocity.y = SWIM_UP_SPEED
		gliding = false
		return

	# planar: cair segurando CTRL (a tecla do agachar, como no Veloren). Olhar para
	# baixo mergulha e converte altura em velocidade horizontal; olhar para cima
	# perde velocidade sem nunca subir. Soltar devolve o controle normal.
	gliding = (not body.on_ground) and not panel_open \
			and Input.is_action_pressed("glide") \
			and body.velocity.y < 0.5 and _roll_time <= 0.0
	if gliding:
		var dive := clampf(-pitch, -1.0, 1.0)
		var target_h := clampf(GLIDE_SPEED + dive * GLIDE_DIVE_GAIN, GLIDE_STALL, GLIDE_DIVE_SPEED)
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var hv := Vector3(body.velocity.x, 0.0, body.velocity.z) \
				.lerp(forward * target_h, clampf(delta * GLIDE_STEER, 0.0, 1.0))
		body.velocity.x = hv.x
		body.velocity.z = hv.z
		body.apply_gravity(delta, GLIDE_GRAVITY)
		body.velocity.y = maxf(body.velocity.y,
				-(GLIDE_SINK + maxf(dive, 0.0) * GLIDE_DIVE_SINK))
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


func _apply_energy(delta: float, wish: Vector3) -> void:
	if sprinting and body.on_ground and wish != Vector3.ZERO and not body.in_water:
		energy = maxf(energy - SPRINT_DRAIN * delta, 0.0)
		if energy <= 0.5:
			_sprint_locked = true
	else:
		energy = minf(energy + ENERGY_REGEN * delta, max_energy)
		if _sprint_locked and energy >= SPRINT_RECOVERY:
			_sprint_locked = false


## Rolamento: so no chao, custa vigor, da impulso na direcao do movimento (ou do
## olhar) e abre uma janela de invencibilidade — a esquiva do Veloren.
func _try_roll(wish: Vector3) -> void:
	if _roll_buffer <= 0.0 or _roll_cd > 0.0 or not body.on_ground:
		return
	if energy < ROLL_COST:
		return
	_roll_buffer = 0.0
	energy -= ROLL_COST
	_roll_cd = ROLL_CD
	_roll_time = ROLL_TIME
	_iframes = ROLL_IFRAMES
	var dir := wish if wish != Vector3.ZERO else Vector3(-sin(yaw), 0.0, -cos(yaw))
	body.velocity = Vector3(dir.x * ROLL_SPEED, body.velocity.y, dir.z * ROLL_SPEED)


func _update_breath(delta: float) -> void:
	var eye := Coords.to_block(eye_position())
	var submerged := world.is_water_xyz(eye.x, eye.y, eye.z)
	if submerged:
		air = maxf(air - delta, 0.0)
		if air <= 0.0:
			_drown_cd -= delta
			if _drown_cd <= 0.0:
				_drown_cd = DROWN_PERIOD
				take_damage(DROWN_DAMAGE, body.feet_pos)
	else:
		air = minf(air + delta * AIR_REFILL, AIR_MAX)
		_drown_cd = DROWN_PERIOD


## Impacto de queda: o integrador zera vy no choque vertical, e e esse numero —
## nao o instante em que o pe toca o solo — que mede o impacto. A parada em
## substep deixa o corpo ate um passo acima do solo e atrasa o on_ground: medir
## ali comeria o dano de toda queda rapida. Agua perdoa, e o planar nunca chega
## na velocidade segura.
func _check_fall_impact(pre_vy: float) -> void:
	if pre_vy >= 0.0 or body.velocity.y != 0.0 or body.in_water:
		return
	var impact := -pre_vy
	if impact > FALL_SAFE_SPEED:
		take_damage(minf((impact - FALL_SAFE_SPEED) * FALL_DAMAGE_PER_SPEED,
				FALL_DAMAGE_MAX), body.feet_pos)


func _apply_regen(delta: float) -> void:
	_since_damage += delta
	if _since_damage >= REGEN_DELAY and energy > REGEN_MIN_ENERGY and hp < max_hp:
		hp = minf(hp + REGEN_RATE * delta, max_hp)


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
	target_hardness = BlockDefs.hardness(hit.block) if target_valid else 0.0
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


func _apply_actions(delta: float) -> void:
	if panel_open:
		return
	if Input.is_action_pressed("break_block"):
		if _target_entity != null and _attack_cd <= 0.0:
			_attack_cd = 0.42
			_punch = minf(_punch + 0.10, 0.5)
			avatar.swing()
			# golpe basico devolve vigor, como o ataque basico do Veloren recupera stamina
			energy = minf(energy + ATTACK_ENERGY, max_energy)
			attacked.emit(_target_entity, ATTACK_DAMAGE)
		elif target_valid:
			_mining_accum += delta
			if _mining_accum >= target_hardness:
				_mine_target()
	# Construir e uma intencao separada da de minerar: segurar o botao esquerdo
	# (lavrando um bloco duro) nao engole o clique direito do meio da obra.
	if _place_buffer > 0.0 and _place_cd <= 0.0:
		_place_buffer = 0.0
		_try_place()


## Lavrar de verdade: o drop e o que o registro diz (`BlockDefs.drop_of`), nao o
## bloco que estava la, e ele so sai do mundo depois de o inventario prometer
## espaco. No Veloren o que nao cabia voltava para o mundo como entidade de item
## (inventory_manip.rs); sem entidade ainda, o bloco continua no lugar.
func _mine_target() -> void:
	var b := world.get_block(target_voxel)
	var drop := BlockDefs.drop_of(b)
	if drop != BlockDefs.Block.AIR and inv.space_for(drop, 1) <= 0:
		_mining_accum = 0.0
		notice.emit("inventario cheio: %s nao tem onde entrar"
			% BlockDefs.display_name(drop))
		return
	if world.set_block(target_voxel, BlockDefs.Block.AIR):
		_mining_accum = 0.0
		avatar.swing()
		inv.add(drop, 1)
		block_broken.emit(target_voxel, b)
		acted.emit("break", Vector3(target_voxel) + Vector3(0.5, 0.5, 0.5))


func _try_place() -> void:
	if not target_valid:
		return
	if not VoxelConfig.in_world_bounds(place_voxel):
		return
	var b := selected_block()
	if b == BlockDefs.Block.AIR:
		notice.emit("slot vazio: primeiro minerar ou craftar")
		return
	var cur := world.get_block(place_voxel)
	if cur != BlockDefs.Block.AIR and cur != BlockDefs.Block.WATER:
		return
	var pb := AABB(Vector3(place_voxel), Vector3.ONE)
	if body.aabb().intersects(pb):
		return
	_place_cd = 0.16
	# a quantidade e gasta junto com o sucesso: um place recusado pelo corpo ou por
	# um voxel ocupado nao pode custar um bloco do inventario
	if world.set_block(place_voxel, b):
		inv.consume_selected(1)
		avatar.swing()
		block_placed.emit(place_voxel, b)
		acted.emit("place", Vector3(place_voxel) + Vector3(0.5, 0.5, 0.5))


# ------------------------------------------------------------------ camera

func _update_camera(delta: float) -> void:
	var eye := eye_position()
	var rot := Basis.from_euler(Vector3(0.0, yaw, 0.0)) * Basis.from_euler(Vector3(pitch, 0.0, 0.0))
	# bob e punch sao exclusivos da 1a pessoa: em 3a pessoa estragariam o enquadramento
	var bob_y := 0.0
	var bob_roll := 0.0
	var bob_amp := 0.0
	if not third_person and body.on_ground:
		var planar := Vector3(body.velocity.x, 0.0, body.velocity.z)
		var speed := planar.length()
		if speed > 0.4:
			_bob_phase += delta * (4.6 + speed * 0.55)
			bob_amp = clampf(speed / SPRINT_SPEED, 0.0, 1.0)
			bob_y = sin(_bob_phase * 2.0) * 0.030 * bob_amp
			bob_roll = sin(_bob_phase) * 0.010 * bob_amp
	_punch = maxf(_punch - delta * 2.2, 0.0)
	var punch_pitch := _punch * 0.10 if not third_person else 0.0
	var final_rot := rot.rotated(rot.z, bob_roll)
	final_rot = final_rot.rotated(final_rot.x, punch_pitch)
	# Em 1a pessoa a camera recua 0,60 m pela propria direcao de visao: com o
	# tronco fora de cena, maos, cinto, coxas, canelas e pes ficam no quadro
	# mesmo com o pitch nivelado, e o olhar para baixo mostra o corpo inteiro
	# acima da hotbar. O recuo e colinear ao raio de mira: a mira segue exata
	# sob o crosshair em qualquer pitch.
	var fp_back := final_rot.z.normalized() * 0.60 if not third_person else Vector3.ZERO
	camera.global_transform = Transform3D(final_rot, eye + fp_back + Vector3(0.0, bob_y, 0.0))

	if third_person:
		# orbita na altura dos olhos, como o Minecraft: a mira passa sobre a
		# cabeca e olhar para cima/baixo nao arrasta a camera por cima do cranio
		var pivot := body.feet_pos + Vector3(0.0, 1.55, 0.0)
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
