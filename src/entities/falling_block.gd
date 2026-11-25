class_name FallingBlock
extends Node3D
## Bloco em voo (dossie 17 §3.3, §7d, doc 10 §10.5). Não existe nenhum antes de um evento de
## vizinho dizer que o apoio sumiu, então o número de entidades deste tipo é sempre <= o
## número de edições de bloco do último tick.
##
## O `step_up` vai a ZERO de propósito: o corpo do lobo sobe 0,62 m (`voxel_body.gd:19`) e a
## célula tem 1 m, então com o valor herdado um graio de areia subiria um degrau na parede do
## lado e pousaria em cima dela. `bloco_em_queda_nao_sobe` é a checagem que vigia isso, com a
## leitura do pé monotônico e do `step_up` lido no próprio corpo.

const SIZE: float = 0.98
const MAX_FALL_TICKS: int = 400        # 20 s a 20 Hz; a queda máxima real é ~11 s (doc 10 :465)

var world: VoxelWorld = null
var block: int = BlockDefs.Block.AIR
var origin_y: int = 0
var done: bool = false
## true até o primeiro passo do dono: quem nasceu neste tick integra no seguinte, que é o
## contrato do `flush` vir antes das entidades (dossie 17 §3.5).
var fresh: bool = true
## O grao que não coube em lugar nenhum. Não some em silêncio: o spawner conta e o F3 lê.
var stranded: bool = false
var body: VoxelBody = VoxelBody.new()

var _mesh: MeshInstance3D = null
var _ticks: int = 0


func setup(p_world: VoxelWorld, cell: Vector3i, p_block: int) -> void:
	world = p_world
	block = p_block
	origin_y = cell.y
	# `feet_pos` é o canto INFERIOR da AABB, então o cubo nasce exatamente na célula que
	# ocupava no grid.
	body.setup(world, Vector3(float(cell.x) + 0.5, float(cell.y), float(cell.z) + 0.5),
			Vector3(SIZE, SIZE, SIZE))
	body.step_up = 0.0
	_mesh = _make_mesh(p_block)
	add_child(_mesh)


func sim_step(dt: float) -> void:
	if done:
		return
	_ticks += 1
	body.apply_gravity(dt)
	var caindo: bool = body.velocity.y < 0.0
	body.move_and_collide(dt)		# zera vy no choque vertical
	# `velocity.y` volta a zero SEM deslocamento == o eixo Y barrou: e o unico instante em que
	# o grao conhece o proprio apoio, e e ele que fixa a celula.
	if caindo and body.velocity.y == 0.0:
		var support := _support_cell()
		if BlockDefs.is_solid(world.get_block(support)):
			_fix(support + Vector3i.UP)
			return
	if _ticks >= MAX_FALL_TICKS:
		_strand(Coords.to_block(body.feet_pos))


## A celula do apoio vem do CHOQUE, nao de uma folga chutada: o integrador subdivide o
## deslocamento em passos de no maximo `SUBSTEP` e devolve o primeiro que colide, entao o pe
## parado fica a menos de `SUBSTEP` da face que o barrou -- `feet - SUBSTEP` cai sempre na
## celula do solido. Medido na primeira corrida do gate: o grao parou com pe em 45,1 tendo o
## topo do apoio em 45,0, e o probe de chao do corpo (`GROUND_PROBE` = 0,06 m,
## voxel_body.gd:17) alcanca so ate 45,04 -- `on_ground` nunca acordou e o pouso viraria
## expiracao de `MAX_FALL_TICKS`. Trocar a folga por um numero maior consertaria a cena e
## mentiria na próxima: o teto honesto e o passo do proprio integrador.
## A saida `SHATTER` do doc nao entra: `breaks_a_fall` nao tem comprador enquanto nao existir
## bloco que quebra queda, e o destino do estilhaco seria um item no chao que nao existe
## (dossie 17 §6).
func _support_cell() -> Vector3i:
	return Vector3i(int(floorf(body.feet_pos.x)),
			int(floorf(body.feet_pos.y - VoxelBody.SUBSTEP)),
			int(floorf(body.feet_pos.z)))


func _fix(cell: Vector3i) -> void:
	done = true
	if not world.place_falling_block(cell, block):
		_strand(cell)


func _strand(cell: Vector3i) -> void:
	done = true
	stranded = true
	if _mesh != null:
		_mesh.visible = false


## Visual da entidade: cubo com a cor de referência do bloco. `BlockDefs.swatch()` já é a
## fonte de cor por tipo sem textura de atlas; uma BoxMesh com o atlas precisaria de UV por
## face, que é o trabalho de malharia do doc 10 §10.3, não pré-requisito da física.
func _make_mesh(b: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SIZE, SIZE, SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BlockDefs.swatch(b)
	mat.roughness = 0.9
	box.material = mat
	mi.mesh = box
	# A AABB começa no pé, e a BoxMesh é centrada no próprio origem.
	mi.position = Vector3(0.0, SIZE * 0.5, 0.0)
	return mi


func _process(_delta: float) -> void:
	position = body.feet_pos
