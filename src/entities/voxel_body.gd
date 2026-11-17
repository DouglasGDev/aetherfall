class_name VoxelBody
## Integrador AABB-contra-voxel. Substitui CharacterBody3D para criaturas do mundo:
## mesmo codigo roda no cliente e no dedicado headless, e e barato o bastante para
## dezenas de corpos (docs/design/06.2).

const TERMINAL_VELOCITY: float = 42.0
const SUBSTEP: float = 0.35
const GROUND_PROBE: float = 0.06
const WALL_SHAVE: float = 0.001

var world: VoxelWorld = null
var dims := Vector3(0.6, 1.8, 0.6)
var feet_pos := Vector3.ZERO
var velocity := Vector3.ZERO
var gravity: float = 24.0
var on_ground: bool = false
var step_up: float = 0.62
var in_water: bool = false
var blocked_this_frame: bool = false


func setup(p_world: VoxelWorld, p_pos: Vector3, p_dims: Vector3) -> void:
	world = p_world
	feet_pos = p_pos
	dims = p_dims


func aabb() -> AABB:
	var half := Vector3(dims.x * 0.5, 0.0, dims.z * 0.5)
	return AABB(feet_pos - half, Vector3(dims.x, dims.y, dims.z))


func center() -> Vector3:
	return feet_pos + Vector3(0.0, dims.y * 0.5, 0.0)


func apply_gravity(delta: float, factor: float = 1.0) -> void:
	velocity.y = maxf(velocity.y - gravity * delta * factor, -TERMINAL_VELOCITY)


## Mover com resolucao eixo a eixo + auto step-up. Retorna true se houve colissao.
func move_and_collide(delta: float) -> bool:
	blocked_this_frame = false
	var disp := velocity * delta
	_collide_axis(0, disp.x)
	_collide_axis(2, disp.z)
	_collide_axis(1, disp.y)
	in_water = world.box_in_water(aabb())
	on_ground = _probe_ground()
	return blocked_this_frame


func _collide_axis(axis: int, amount: float) -> void:
	if absf(amount) < 1e-6:
		return
	var steps: int = maxi(1, int(absf(amount) / SUBSTEP) + 1)
	var inc: float = amount / float(steps)
	for _s in steps:
		var test := _translated(axis, inc)
		if not world.aabb_hits_solid(test):
			_apply(axis, inc)
			continue
		# auto step-up: so em movimento horizontal, com pe no chao e espaco livre acima
		if axis != 1 and on_ground and step_up > 0.0:
			var raised := test
			raised.position.y += step_up
			if not world.aabb_hits_solid(raised):
				feet_pos.y += step_up
				if not world.aabb_hits_solid(_translated(axis, inc)):
					_apply(axis, inc)
					continue
		blocked_this_frame = true
		match axis:
			0: velocity.x = 0.0
			1: velocity.y = 0.0
			2: velocity.z = 0.0
		return


func _translated(axis: int, amount: float) -> AABB:
	var box := aabb()
	match axis:
		0:
			box.position.x += amount
			box.size.x -= WALL_SHAVE
		1:
			box.position.y += amount
			if amount < 0.0:
				box.position.y -= WALL_SHAVE
		2:
			box.position.z += amount
	return box


func _apply(axis: int, amount: float) -> void:
	match axis:
		0: feet_pos.x += amount
		1: feet_pos.y += amount
		2: feet_pos.z += amount


func _probe_ground() -> bool:
	var probe := aabb()
	probe.position.y -= GROUND_PROBE
	probe.size.y = GROUND_PROBE + 0.02
	return world.aabb_hits_solid(probe)


## Stepping usado pela IA: teste hipotetico sem mutar o corpo.
func can_stand_at(p: Vector3) -> bool:
	var box := AABB(p - Vector3(dims.x * 0.5, 0.0, dims.z * 0.5), dims)
	if world.aabb_hits_solid(box):
		return false
	var below := box
	below.position.y -= 0.12
	return world.aabb_hits_solid(below)
