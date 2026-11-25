class_name RainFx
extends Node3D
## O véu da chuva (dossie 23 §3.10d e §5.3): dois emissores de gota criados no boot, um
## lote de anéis por `RAIN_RING_PERIOD`, e nada mais. O nó não decide clima nenhum — lê o
## `chuva` do `Weather`, pede a coluna sorteada a ele e entrega o anel ao `WaterFx` por um
## `Callable`. É a forma que a casa usa para "um lê, ninguém escreve" (`llm_status_provider`,
## `narration_provider`) e é por isso que este arquivo não conhece o tipo `WaterFx`.
##
## Os dois braços rejeitados desta perna têm página no §3.10d: um pool de anéis próprio aqui
## dobraria o teto aritmético do §3.6 sem comprar nada, e a gota como *hitscan* por partícula
## por quadro (748 gotas vivas) alimenta uma CPU que não sabe onde está a superfície. O que
## cai é sorteado **como evento visual**, na RNG do clima — que é separada da RNG da sessão
## justamente para o censo e o `intent` não passarem a depender de quantos frames choveu.

## Aritmética do teto, e ela é o gate (§5.3 `orcamento_de_particulas_da_chuva`). O engine não
## tem taxa independente em `GPUParticles3D`: com `one_shot = false` a cadência efetiva é
## `amount / lifetime`, então a taxa pedida só vira número se o `amount` for **exatamente**
## `taxa × vida`. 520 × 0,9 = 468 e 200 × 1,4 = 280; arredondar para 500/300 deixaria a
## asserção `rate * life <= amount` verdadeira por folga, e a folga é o que esconde um
## emissor maior que o orçamento.
const NEAR_RATE := 520.0
const NEAR_LIFE := 0.9
const NEAR_AMOUNT := 468
const FAR_RATE := 200.0
const FAR_LIFE := 1.4
const FAR_AMOUNT := 280
## Queda a velocidade constante, sem gravidade no material de processo: a distância que a gota
## percorre é `velocidade × vida` e é esse número — não um chute — que fixa a altura da laje de
## nascimento abaixo. 9 × 0,9 = 8,1 m e 7 × 1,4 = 9,8 m.
const NEAR_FALL_V := 9.0
const FAR_FALL_V := 7.0
## Caixa do **véu visível**, em torno de quem joga. O anel não passa por aqui: ele é sorteado
## na coluna do mundo inteiro (§3.10d), porque é o `Weather` que sorteia e ele não conhece o
## jogador. Longe demais para ser visto é o preço dessa separação, e ele aparece em
## `P_global = 0,1248` contra `P_caixa = 0,1914` no §4.
const RAIN_NEAR_HALF := 12.0
const RAIN_FAR_HALF := 32.0
const RAIN_NEAR_SLAB_Y := 9.0
const RAIN_FAR_SLAB_Y := 12.0
## Cadência do comprador novo do pool de anéis. A página derivava `RAIN_RINGS_PER_BATCH = 1`
## assumindo que a coluna sorteada tem água; censitado neste mundo (§4 da página do pouso,
## `.tools/probe_chuva.gd`) o `P` é 0,1248 — um por lote seriam ~4 anéis vivos e o efeito não
## existe. Quatro por lote a cada 0,12 s são 33,3 sorteios/s, ~4,2 aceitos/s e ~4,6 vagas
## vivas de 12; na caixa do meio, ~6,4/s e ~7,0 vivas. Os dois números ficam abaixo da cota
## de ~9 que a página escreveu, e a testemunha é `vivo_chuva + vivo_corpo <= RING_POOL`.
const RAIN_RINGS_PER_BATCH := 4
const RAIN_RING_PERIOD := 0.12

var world: VoxelWorld = null
var weather: Weather = null
var player: Player = null
## A porta do `_anel` privado do `WaterFx` (§3.10d). Ligada no boot pelo `main.gd` com
## `Callable(water_fx, "ring_at")`; devolve `false` quando a coluna recusou, e é por essa
## resposta que `anis_recusados` existe em vez de um anel fantasma em `y = 0`.
var ring_sink: Callable = Callable()

var _near: GPUParticles3D = null
var _far: GPUParticles3D = null
var _acumulador := 0.0
var _ligado := false
## Colheita (§4, pergunta 1): o RainFx decide **uma coisa por lote**, e o que roda por frame é
## a soma deste parágrafos. Sem `us_por_quadro` na diagnóstica, "custo zero no vale seco" seria
## adjetivo; com ele, o número da janela seca e o da janela molhada se comparam.
var _lotes := 0
var _colunas_sorteadas := 0
var _anis_aceitos := 0
var _anis_recusados := 0
var _quadros := 0
var _us_total := 0
var _us_pico := 0


func setup(p_world: VoxelWorld, p_weather: Weather, p_player: Player) -> void:
	world = p_world
	weather = p_weather
	player = p_player
	_near = _emissor(NEAR_AMOUNT, NEAR_LIFE, NEAR_FALL_V, RAIN_NEAR_HALF, RAIN_NEAR_SLAB_Y)
	_far = _emissor(FAR_AMOUNT, FAR_LIFE, FAR_FALL_V, RAIN_FAR_HALF, RAIN_FAR_SLAB_Y)
	add_child(_near)
	add_child(_far)


## O teto que a checagem compara com a árvore: nenhum outro emissor de chuva existe, porque os
## dois nascem aqui e o pool é fixo (§3.6).
static func teto_particulas() -> int:
	return NEAR_AMOUNT + FAR_AMOUNT


func diagnostics() -> Dictionary:
	return {
		"emissores": 2 if _near != null and _far != null else 0,
		"teto_particulas": teto_particulas(),
		"ligado": _ligado,
		"chuva": weather.chuva if weather != null else 0.0,
		"lotes": _lotes,
		"colunas_sorteadas": _colunas_sorteadas,
		"anis_aceitos": _anis_aceitos,
		"anis_recusados": _anis_recusados,
		"quadros": _quadros,
		"us_total": _us_total,
		"us_por_quadro": float(_us_total) / float(maxi(_quadros, 1)),
		"us_pico": _us_pico,
	}


func _physics_process(delta: float) -> void:
	if weather == null or world == null:
		return
	var t0 := Time.get_ticks_usec()
	var on: bool = weather.chuva > 0.0
	if on != _ligado:
		_ligado = on
		# Só no flanco. Escrever `emitting` todo frame não reinicia o emissor, mas também não
		# é preciso: num vale seco o caminho quente deste nó tem de ser a comparação acima.
		_near.emitting = on
		_far.emitting = on
	if on:
		# O véu segue quem joga; com `local_coords` as gotas vivem no espaço do nó, então
		# mover o nó move a cortina inteira e não há re-simulação de mundo.
		global_position = _ancora()
		_acumulador += delta
		if _acumulador >= RAIN_RING_PERIOD:
			# Um lote por frame de física, no máximo. Se a janela estourar (o furo #41 é
			# justamente o pior quadro de malharia), o ciclo **perde o lote atrasado em vez de
			# disparar uma fila dele** — dívida acumulada apareceria como um trote de anéis
			# depois de um engasgo, e nada no mundo faz isso.
			_acumulador = 0.0
			_lote()
	_quadros += 1
	var gasto := Time.get_ticks_usec() - t0
	_us_total += gasto
	_us_pico = maxi(_us_pico, gasto)


## A coluna de cima da cortina perto: os pés do jogador, lidos pelo mesmo `feet_pos` que o
## `WaterFx` usa para achar a coluna da entrada — nenhum campo escrito no corpo, nenhum
## varredor de cena por frame.
func _ancora() -> Vector3:
	if player != null and player.body != null:
		return Vector3(player.body.feet_pos.x, 0.0, player.body.feet_pos.z)
	return Vector3.ZERO


func _lote() -> void:
	for i in RAIN_RINGS_PER_BATCH:
		var col := weather.sortear_coluna()
		_colunas_sorteadas += 1
		var plano := world.water_surface_y(col.x, col.y)
		if ring_sink.is_valid():
			if bool(ring_sink.call(col.x, col.y, plano)):
				_anis_aceitos += 1
			else:
				_anis_recusados += 1


## Um dos dois emissores: laje fina no topo, queda a velocidade constante, gota como caixa
## estreita e sem luz. `amount` é o produto `taxa × vida` do cabeçalho, e é ele — não um teto
## escolhido à mão — que a suíte confere contra a árvore.
func _emissor(amount: int, life: float, fall_v: float, half: float, slab_y: float) -> GPUParticles3D:
	var node := GPUParticles3D.new()
	node.amount = amount
	node.lifetime = life
	node.one_shot = false
	node.preprocess = life
	node.local_coords = true
	# A AABB de visibilidade tem de conter a laje **e** a queda inteira, senão o frustum culling
	# corta a cortina quando o nó fica na borda da tela.
	node.visibility_aabb = AABB(Vector3(-half, -fall_v * life - 1.0, -half),
		Vector3(half * 2.0, fall_v * life + 2.0, half * 2.0))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, -1.0, 0.0)
	# 4° de abertura: chuva vertical demais vira grade, aberta demais vira neblina. Não é
	# física, é o ângulo que a sonda §5.4 vê; a cadência continua sendo a do `amount`.
	pm.spread = 4.0
	pm.initial_velocity_min = fall_v * 0.92
	pm.initial_velocity_max = fall_v * 1.08
	# Gravidade zero **de propósito**: com ela a distância percorrida deixa de ser o produto
	# `velocidade × vida` que fixa a laje, e o véu passaria a depender de um número que nada
	# nesta página declara.
	pm.gravity = Vector3.ZERO
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# O nome e `EMISSION_SHAPE_BOX`, medido por `ClassDB.class_get_enum_constants` em
	# `.tools/probe_emission_shape.gd`; `EMISSION_BOX3D` e de Godot 3 e o `--check-only` devolve
	# parse error — o mesmo chao do `specular_schlick_blurry` do furo #46, com o prenome trocado.
	pm.emission_box_extents = Vector3(half, 0.35, half)
	node.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018, 0.30, 0.018)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# O alfa da gota é a única transparência desta perna. `vertex_color_use_as_albedo` fica
	# desligado de propósito: a gota não tem `COLOR`, ela **é** a cor, e ligá-lo sobre um mesh
	# sem o atributo multiplicaria por branco.
	mat.albedo_color = Color(0.72, 0.82, 0.92, 0.55)
	mesh.material = mat
	node.draw_pass_1 = mesh
	node.position = Vector3(0.0, slab_y, 0.0)
	node.emitting = false
	return node
