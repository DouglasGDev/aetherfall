class_name WaterFx
extends Node3D
## O FX da agua (dossie 23 §3.6 a §3.8): salpico, anel no plano da coluna e bolhas
## de fundo, tudo em **pool fixo** criado no boot. Nenhum `new()` dentro de frame ou
## tick, porque a casa ainda nao tem colheita de alocao no caminho quente (AGENTS.md,
## "Alocacao no caminho quente existe e nao e medida") — criar uma fonte nova dela sem
## instrumento e o contrario do mandato 5.
##
## O FX e LEITURA, nao escrita (§3.8): nao toca `set_block`, nem `AetherField`, nem as
## RNG da simulacao, e `fx_nao_escreve_o_mundo` e a checagem que paga essa frase, nao
## este comentario. A entrada na agua e lida por transicao do estado do corpo, no mesmo
## padrao do audio (`audio_director.gd:439`), e nao por sinal novo no `VoxelBody` — o
## braco rejeitado do §3.7 e o registro de que o segundo comprador ainda nao existe.

## Teto do FX: aritmética dos `amount` declarados aqui, lida pela checagem
## `orcamento_de_particulas` em vez de depender da minha memoria.
const SPLASH_POOL := 8
const SPLASH_AMOUNT := 24
const SPLASH_LIFE := 0.55
const RING_POOL := 12
const RING_LIFE := 1.1
const RING_DIAM := 3.2
const BUBBLE_POOL := 4
const BUBBLE_AMOUNT := 40
const BUBBLE_LIFE := 1.4
## Um corpo que entra devagar (andar para dentro do lago) faz anel; salpico e so para
## quem chega caindo. 3 m/s e o que a gravidade de 24 m/s² do corpo junta em ~0,13 s
## de queda livre, ou seja: um degrau ja basta e um nado nao.
const SPLASH_MIN_VY := -3.0
## Bolhas pedem coluna funda o bastante para ter o que subir.
const BUBBLE_MIN_BLOCKS := 2

const SOURCE_RING: String = """shader_type spatial;
// unshaded + blend_add: o anel e luz sobre a agua, nao geometria com sombra propria.
// depth_draw_never porque ele e do passe transparente e nao deve tapar a si mesmo.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 cor : source_color = vec4(0.82, 0.92, 0.98, 1.0);
uniform float largura = 0.16;
uniform float vida = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// O raio do anel e a propria vida, e o quad esta escalado com ela: aqui so se
	// desenha a faixa, sem depender do tamanho do mesh.
	float d = abs(length(p) - 0.86);
	float intens = (1.0 - smoothstep(0.0, largura, d)) * (1.0 - vida);
	ALBEDO = cor.rgb * intens * 2.4;
	ALPHA = clamp(intens, 0.0, 1.0);
}
"""

var world: VoxelWorld = null
var player: Player = null
var wolves_provider: Callable = Callable()

var _splash: Array = []
var _splash_life := PackedFloat32Array()
var _rings: Array = []
var _ring_life := PackedFloat32Array()
var _bubbles: Array = []
var _bubble_life := PackedFloat32Array()
## Estado por corpo, chave = `identity` do lobo e `-1` do jogador — o mesmo dicionario
## do audio, nunca um campo escrito no corpo (§3.7).
var _state: Dictionary = {}
var _next_splash := 0
var _next_ring := 0
var _next_bubble := 0
var _salpicos_disparados := 0
## A mesma contagem, mas so dos salpicos cujo corpo e o jogador (chave `-1`). O pool e
## compartilhado com a matilha, entao sem esta separacao a checagem de indiferenca do
## §5.1 -- "o corpo seco nao dispara" -- dependeria de nenhum lobo ter entrado na agua
## durante a janela, que e geografia, nao defeito do FX.
var _salpicos_jogador := 0
var _picos := 0
## Colheita de custo (§4, pergunta 4): frames tratados, soma e pico em microsegundos.
var _quadros := 0
var _us_total := 0
var _us_pico := 0


func setup(p_world: VoxelWorld, p_player: Player) -> void:
	world = p_world
	player = p_player
	_build_pool()


func diagnostics() -> Dictionary:
	# A entrada do jogador e lida do estado por corpo, nao de um campo global: um lobo
	# que entra na agua dois quadros depois nao pode apagar a testemunha da queda que a
	# checagem `queda_na_agua_dispara_salpico` cobra.
	var j: Dictionary = _state.get(-1, {})
	return {
		"pool": SPLASH_POOL + RING_POOL + BUBBLE_POOL,
		"salpicos": _vivos(_splash_life, SPLASH_POOL),
		"anis": _vivos(_ring_life, RING_POOL),
		"bolhas": _vivos(_bubble_life, BUBBLE_POOL),
		"teto_particulas": teto_particulas(),
		"salpicos_disparados": _salpicos_disparados,
		"salpicos_jogador": _salpicos_jogador,
		"picos": _picos,
		"jogador_vy": float(j.get("vy", 0.0)),
		# O par coluna/plano vem do mesmo evento de entrada: a checagem re-deriva o
		# plano contra `world.water_surface_y`, nao contra este numero.
		"jogador_col": j.get("col", Vector2i(-1, -1)),
		"jogador_plano": float(j.get("plano", -1.0)),
		"jogador_blocos": int(j.get("blocos", 0)),
		# O custo lido, nao o custo lembrado: media e pico do frame de fisica tratado
		# pelo FX, na arvore que esta rodando agora.
		"quadros": _quadros,
		"us_total": _us_total,
		"us_por_quadro": float(_us_total) / float(maxi(_quadros, 1)),
		"us_pico": _us_pico,
	}


## O teto que a checagem compara com a aritmética dos `amount`: nenhuma particula
## viva pode passar daqui, porque nao existe emissor fora do pool.
static func teto_particulas() -> int:
	return SPLASH_POOL * SPLASH_AMOUNT + RING_POOL + BUBBLE_POOL * BUBBLE_AMOUNT


func _physics_process(delta: float) -> void:
	# Colheita antes de otimizacao (mandato 5): o FX roda por frame de fisica, e o unico
	# instrumento que existe para ele e esta soma -- sem `us_por_quadro` na diagnostica,
	# o custo do §4 seria adjetivo. Headless nao tem vsync, entao o numero e custo de
	# CPU por frame de fisica, nao tempo de tela.
	var t0 := Time.get_ticks_usec()
	_decair(delta)
	if world != null and player != null:
		var viu := {}
		_corpo(-1, player.body, viu)
		if wolves_provider.is_valid():
			for w in wolves_provider.call():
				var wolf: Wolf = w
				_corpo(wolf.identity, wolf.body, viu)
		# Corpos que sairam da matilha (morte, cadaver) perdem a vaga de estado, senao o
		# dicionario cresce com a historia e a transicao de um lobo novo herda o "dentro".
		for key in _state.keys():
			if int(key) != -1 and not viu.has(key):
				_state.erase(key)
	_quadros += 1
	var gasto := Time.get_ticks_usec() - t0
	_us_total += gasto
	_us_pico = maxi(_us_pico, gasto)


# ------------------------------------------------------------------ transicao

## A unica porta de disparo: `fora → dentro` lido do corpo, com o `vy` da entrada
## impresso depois. Andar para dentro faz anel; cair faz salpico + anel + bolhas.
func _corpo(key: int, body: VoxelBody, viu: Dictionary) -> void:
	viu[key] = true
	var st: Dictionary
	if not _state.has(key):
		_state[key] = {"in_water": false}
	st = _state[key]
	var dentro: bool = body.in_water
	if dentro == bool(st["in_water"]):
		return
	st["in_water"] = dentro
	if not dentro:
		return
	var x := floori(body.feet_pos.x)
	var z := floori(body.feet_pos.z)
	var plano := world.water_surface_y(x, z)
	if plano < 0.0:
		# `in_water` e volume sobrepostos; pode ser agua de uma coluna vizinha. Sem
		# plano proprio nao ha onde pousar o anel, e a recusa e silenciosa de
		# proposito: nao e evento do mundo, é leitura que nao achou alvo.
		return
	_anel(x, z, plano)
	var vy: float = body.velocity.y
	var blocos := _blocos_na_coluna(x, z)
	# O registro da entrada e por corpo, no mesmo dicionario que ja guarda o "dentro":
	# nada aqui e campo escrito no `VoxelBody` (§3.7).
	st["vy"] = vy
	st["col"] = Vector2i(x, z)
	st["plano"] = plano
	st["blocos"] = blocos
	if vy < SPLASH_MIN_VY:
		_salpico(x, z, plano, vy, key)
	if blocos >= BUBBLE_MIN_BLOCKS:
		_bolhas(x, z, plano, blocos)


## Quantos voxels de agua ha na coluna, do plano para baixo. Custo de COLUNA e por
## evento (§4), e saturado em 6 porque acima de 6 a resposta de bolhas nao muda.
func _blocos_na_coluna(x: int, z: int) -> int:
	var y := VoxelConfig.CHUNK_SIZE_Y - 1
	while y >= 0:
		if world.is_water_xyz(x, y, z):
			break
		y -= 1
	if y < 0:
		return 0
	var n := 0
	while n < 6 and y - n >= 0 and world.is_water_xyz(x, y - n, z):
		n += 1
	return n


# ------------------------------------------------------------------ pool

func _build_pool() -> void:
	_splash_life.resize(SPLASH_POOL)
	_ring_life.resize(RING_POOL)
	_bubble_life.resize(BUBBLE_POOL)
	for i in SPLASH_POOL:
		var p := _emissor(0.05, SPLASH_AMOUNT, SPLASH_LIFE, 1.0, Vector3(0.0, 6.5, 0.0),
			2.6, 5.2, Color(0.78, 0.88, 0.96))
		p.one_shot = true
		p.emitting = false
		_splash.append(p)
		add_child(p)
	for i in RING_POOL:
		var r := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2(1.0, 1.0)
		r.mesh = quad
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.material_override = _ring_material()
		_rings.append(r)
		add_child(r)
	for i in BUBBLE_POOL:
		var b := _emissor(0.09, BUBBLE_AMOUNT, BUBBLE_LIFE, 0.0, Vector3(0.0, 1.6, 0.0),
			0.3, 0.9, Color(0.86, 0.95, 1.0))
		b.one_shot = true
		b.emitting = false
		_bubbles.append(b)
		add_child(b)


static func _ring_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SOURCE_RING
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Um emissor do pool: `one_shot` com `explosiveness` 1 para o salpico (tudo de uma
## vez) e 0 para as bolhas (a mesma contagem espalhada pela vida). Os tres nomes de
## cadencia -- `lifetime`, `one_shot`, `explosiveness` -- moram no NO, nao no
## `ParticleProcessMaterial` (medido em `.tools/particle_props_probe.gd`: `pm.lifetime`
## devolve false na lista do engine); escrever neles no material derrubava o `_emissor`
## inteiro e o pool nascia vazio, com a checagem de orcamento acusando zero emissores.
## A particula desenha uma esfera minima sem textura -- nada de atlas novo, e
## `local_coords` para o FX mover o no em vez de re-simular o mundo.
func _emissor(r: float, amt: int, life: float, explosive: float, grav: Vector3,
	vmin: float, vmax: float, cor: Color) -> GPUParticles3D:
	var node := GPUParticles3D.new()
	node.amount = amt
	node.lifetime = life
	node.one_shot = true
	node.explosiveness = explosive
	node.preprocess = 0.0
	node.local_coords = true
	node.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 5.0, 4.0))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 58.0
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = grav
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	node.process_material = pm
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = cor
	mesh.material = mat
	node.draw_pass_1 = mesh
	return node


func _salpico(x: int, z: int, plano: float, vy: float, key: int) -> void:
	var i := _next_splash
	_next_splash = (_next_splash + 1) % SPLASH_POOL
	var node: GPUParticles3D = _splash[i]
	node.position = Vector3(float(x) + 0.5, plano, float(z) + 0.5)
	var pm := node.process_material as ParticleProcessMaterial
	# A escala do chuto vem do `vy` da entrada, lida — nao de um numero de roteiro.
	pm.initial_velocity_min = clampf(absf(vy) * 0.22, 1.2, 7.0)
	pm.initial_velocity_max = clampf(absf(vy) * 0.42, 2.2, 11.0)
	node.restart()
	_splash_life[i] = SPLASH_LIFE
	_salpicos_disparados += 1
	if key == -1:
		_salpicos_jogador += 1
	_picos = maxi(_picos, _vivos(_splash_life, SPLASH_POOL))


func _anel(x: int, z: int, plano: float) -> void:
	var i := _next_ring
	_next_ring = (_next_ring + 1) % RING_POOL
	var node: MeshInstance3D = _rings[i]
	node.position = Vector3(float(x) + 0.5, plano, float(z) + 0.5)
	node.scale = Vector3(0.6, 1.0, 0.6)
	node.visible = true
	# Recomeca o fade: sem isto o anel reaproveitado do pool nasceria com o `vida` do
	# ultimo uso e apareceria ja desbotado.
	(node.material_override as ShaderMaterial).set_shader_parameter(&"vida", 0.0)
	_ring_life[i] = RING_LIFE


func _bolhas(x: int, z: int, plano: float, blocos: int) -> void:
	var i := _next_bubble
	_next_bubble = (_next_bubble + 1) % BUBBLE_POOL
	var node: GPUParticles3D = _bubbles[i]
	# As bolhas nascem no leito e sobem ate o plano: a vida do emissor e a coluna.
	node.position = Vector3(float(x) + 0.5, plano - float(blocos) + 0.25, float(z) + 0.5)
	node.restart()
	_bubble_life[i] = BUBBLE_LIFE


func _decair(delta: float) -> void:
	for i in _splash_life.size():
		if _splash_life[i] > 0.0:
			_splash_life[i] -= delta
	for i in _ring_life.size():
		if _ring_life[i] > 0.0:
			_ring_life[i] -= delta
			if _ring_life[i] <= 0.0:
				(_rings[i] as MeshInstance3D).visible = false
			else:
				var vida := 1.0 - _ring_life[i] / RING_LIFE
				var node: MeshInstance3D = _rings[i]
				var d := lerpf(0.6, RING_DIAM, vida)
				node.scale = Vector3(d, 1.0, d)
				# O uniforme mora no material do node, nao no node: `MeshInstance3D` nao tem
				# `set_shader_parameter` (medido em `.tools/shader_param_probe.gd`, onde a
				# busca devolve `mat=true mi=false`; com a chamada errada a corrida headless
				# imprimia um SCRIPT ERROR por frame de anel vivo). Cada anel do pool tem o
				# proprio `ShaderMaterial`, entao escrever ali e escrever naquele anel.
				(node.material_override as ShaderMaterial).set_shader_parameter(&"vida", vida)
	for i in _bubble_life.size():
		if _bubble_life[i] > 0.0:
			_bubble_life[i] -= delta


static func _vivos(arr: PackedFloat32Array, n: int) -> int:
	var k := 0
	for i in n:
		if arr[i] > 0.0:
			k += 1
	return k
