class_name VoxelBody
## Integrador AABB-contra-voxel. Substitui CharacterBody3D para criaturas do mundo:
## mesmo codigo roda no cliente e no dedicado headless, e e barato o bastante para
## dezenas de corpos (docs/design/06.2).

const TERMINAL_VELOCITY: float = 42.0
const SUBSTEP: float = 0.35
const GROUND_PROBE: float = 0.06
const WALL_SHAVE: float = 0.001
const ESCAPE_LIFT: float = 2.5
const ESCAPE_STEP: float = 0.05

var world: VoxelWorld = null
var dims := Vector3(0.6, 1.8, 0.6)
var feet_pos := Vector3.ZERO
var velocity := Vector3.ZERO
var gravity: float = 24.0
var on_ground: bool = false
var step_up: float = 0.62
var in_water: bool = false
## Contato com o chao nao e obstaculo no caminho: blocked_this_frame conta qualquer
## eixo, inclusive o Y do pouso, e blocked_horizontal so os eixos de andar.
var blocked_this_frame: bool = false
var blocked_horizontal: bool = false


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
	blocked_horizontal = false
	escape_embedded()
	var disp := velocity * delta
	_collide_axis(0, disp.x)
	_collide_axis(2, disp.z)
	_collide_axis(1, disp.y)
	in_water = world.box_in_water(aabb())
	on_ground = _probe_ground()
	return blocked_this_frame


## Corpo com o volume dentro de solido nao tem para onde ir: cada eixo colide no
## primeiro subpasso, a gravidade tambem, e a velocidade morre em zero -- congelado
## para sempre no mesmo ponto (medido em 2 dos 5 lobos do spawn). Empurra pra cima
## ate a primeira altura em que o volume cabe; se nao couber em ESCAPE_LIFT, devolve
## o pe onde estava em vez de deixa-lo dentro de outra parede.
func escape_embedded() -> bool:
	if not world.aabb_hits_solid(aabb()):
		return false
	var y0: float = feet_pos.y
	var steps := int(ESCAPE_LIFT / ESCAPE_STEP)
	for i in steps:
		feet_pos.y = y0 + float(i + 1) * ESCAPE_STEP
		if not world.aabb_hits_solid(aabb()):
			velocity.y = 0.0
			return true
	feet_pos.y = y0
	return false


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
		if axis != 1:
			blocked_horizontal = true
		match axis:
			0: velocity.x = 0.0
			1: velocity.y = 0.0
			2: velocity.z = 0.0
		return


## A caixa testada tem de ser a caixa aplicada. Em X o volume era ralado
## (box.size.x -= WALL_SHAVE) para deixar o corpo encostado num solido sem o teste
## reclamar, mas o passo aplicado e a caixa inteira: aceito assim, o corpo termina
## o frame com a face de fora ate 1 mm dentro da parede. Encostado vira encaixado
## para o resgate vertical -- e o resgate nao alcanca um pilar de rocha, entao o lobo
## congela la dentro (medido no cenario da parede: encaixados=389 de 600 frames,
## encaixe_max=1,000 mm, face_x=63,0009). O contato rente de verdade ja e tolerado
## pelo epsilon de aabb_hits_solid (voxel_world.gd:305), que trata face em cima da
## divisoria como livre. Em Y o shave continua, mas do lado conservador: testar 1 mm
## mais baixo significa parar antes de cavar o chao.
func _translated(axis: int, amount: float) -> AABB:
	var box := aabb()
	match axis:
		0:
			box.position.x += amount
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


## Degrau ou penhasco? A pergunta e "a um bloco acima, na direcao dir, existe onde ficar
## de pe", e ela e o que separa o talude de um bloco -- que se sobe -- do muro de seis,
## onde saltar e desperdicio: o corpo volta ao chao no mesmo lugar.
## O +1,0 nao leva margem porque a celula do grid e de exatamente uma unidade
## (aabb_hits_solid percorre por floori, voxel_world.gd:301-312) e o pe apoiado nunca
## fica abaixo da face do solo -- o integrador so aplica o subpasso que nao colide
## (":84-88"). Uma margem de 0,05 custaria ao lobo, que mede 0,95, a propria celula de
## 1,00 em que ele cabe. Se um dia existir SLAB de meia altura (id 18 reservado no
## registro de blocos), esse 1,0 vira pergunta do BlockDefs, nao constante daqui.
## Tambem nao e teleporte: e so a resposta. Quem sobe e o salto, e o salto e animavel.
func can_step_over(dir: Vector3) -> bool:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 1e-8:
		return false
	# O alcance cai fora do corpo porque o bloco comeca na face da caixa, nao no pe.
	var reach := maxf(dims.x, dims.z) * 0.5 + 0.6
	var step := flat.normalized() * reach
	return can_stand_at(feet_pos + Vector3(step.x, 1.0, step.z))
