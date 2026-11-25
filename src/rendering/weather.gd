class_name Weather
extends Node
## Dono visual do clima (dossie 23 §3.10a): dois numeros — `chuva` (alvo pedido) e
## `molhado` (o que o renderizador usa) — e nada mais. Chuva que escurece uma parede
## nao move pe, nao aplica dano e nao escreve no ledger, entao o dono dela e o
## renderizador, nao o `VoxelWorld` (estado autoritativo, entra na projecao do journal)
## nem o `main.gd` (o objeto deus que a casa registra como debito). Quando o clima
## tiver de mudar simulacao — lobo buscando abrigo, grama que nao cresce na tempestade
## — ele vira estado de mundo e o gate passa a ser de determinismo: isso e pauta da 20
## e da 18, nao desta perna.

## O pino da RNG **da chuva**, separado do `SEED` da geracao e do `_population_rng` do
## `main`: sorteio de coluna de gota que come a sequencia da sessao faria o censo e o
## `intent` dependerem de quantos frames choveu. A checagem
## `chuva_nao_consome_rng_da_sessao` e quem paga essa frase com numero.
const WEATHER_SEED := 20261123
## Molhar e secar nao sao a mesma reta: §3.10a exige `DECAY < RISE`. O vale encharca em
## ~1,7 s e seca em ~7 s, que e o que faz o `molhado` ser um numero continuo em vez de
## um degrau — e o degrau e o braco rejeitado do §3.10c.
const WEATHER_RISE := 0.60
const WEATHER_DECAY := 0.145
## Morto-abaixo do qual o uniforme nao e reescrito. Tem de ficar **embaixo do menor
## passo** da rampa (`DECAY / 60 = 0,0024`) para o material seguir o `molhado` dentro da
## tolerancia que a suíte le (0,001), e acima de zero para o estado parado nao escrever
## nada: num vale seco e infinito, `pedidos_aplicados` para de andar.
const WEATHER_SNAP := 0.0005

var chuva: float = 0.0
var molhado: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# O sink e um `Callable` e nao uma referencia ao mundo (§3.10a, o padrao de
# `llm_status_provider`): quem chama e o `main.gd`, entao o clima nao conhece
# `VoxelWorld`, `AetherField` nem `Player` — e `clima_e_dono_visual` conta
# `get_property_list()` justamente para isso nao virar habito.
var _sink: Callable = Callable()
var _aplicado: float = 0.0
var pedidos_aplicados: int = 0
var frames_integrados: int = 0


func _init() -> void:
	_rng.seed = WEATHER_SEED


## A unica porta de entrada: alvo 0…1, com o `molhado` chegando la pela rampa. Quem
## pede e o CLI `--weather=<alvo>` no boot e a suíte, pelo mesmo caminho — nao ha
## atalho que escreva `molhado` a mao, porque o numero que o material ve tem de ter o
## mesmo dono que o numero que a rampa integra.
func pedir_chuva(alvo: float) -> void:
	chuva = clampf(alvo, 0.0, 1.0)


## A casa integra por **frame de fisica**, nao de render, e o motivo e o gate:
## `molhado_sobe_e_desce` conta quadros e divide por `physics_ticks_per_second` para
## prever `1 - DECAY * t`. Com `_process`, a integral seria do tempo real e o numero
## passaria a medir a carga da maquina; com o passo fixo, 60 quadros sao 1 s em qualquer
## arvore. O §4 da pagina dizia "frame de render" — re-escrito no registro de pouso.
func _physics_process(delta: float) -> void:
	var alvo := clampf(chuva, 0.0, 1.0)
	if alvo > molhado:
		molhado = minf(alvo, molhado + WEATHER_RISE * delta)
	elif alvo < molhado:
		molhado = maxf(alvo, molhado - WEATHER_DECAY * delta)
	frames_integrados += 1
	# O morto-abaixo nao pode largar o material com resto: quando a rampa pousa no alvo,
	# a diferenca que falta e escrita mesmo sendo menor que o `SNAP`. Em repouso e sem
	# resto, nenhuma chamada — e o `pedidos_aplicados` parado e a testemunha de que o
	# vale seco nao custa um uniforme por quadro.
	var em_repouso := molhado == alvo
	if (em_repouso and molhado != _aplicado) or absf(molhado - _aplicado) >= WEATHER_SNAP:
		_aplicado = molhado
		pedidos_aplicados += 1
		if _sink.is_valid():
			_sink.call(molhado)


## A porta de saida do estado para quem desenha. Ligada no boot pelo `main.gd`; sem
## ela o nó existe, integra e nao chega a lugar nenhum — e e exatamente o que a
## igualdade `material=%.3f` da §5.3 impede de passar despercebido.
func apply_sink(sink: Callable) -> void:
	_sink = sink
	_aplicado = molhado
	pedidos_aplicados += 1
	if _sink.is_valid():
		_sink.call(molhado)


## A RNG da chuva, pela mesma porta do `llm_status_provider`: leitura, nunca o objeto
## do lado de la.
func rng() -> RandomNumberGenerator:
	return _rng


## Uma coluna do mundo para a gota cair, sorteado no tamanho lido do config — por isso
## o clima nao precisa de referencia nenhuma ao mundo. O `RainFx` pergunta por ela e
## entrega ao `WaterFx`, que recusa com contador se a coluna nao tem agua (§3.10d).
func sortear_coluna() -> Vector2i:
	return Vector2i(
		_rng.randi_range(0, VoxelConfig.world_size_x() - 1),
		_rng.randi_range(0, VoxelConfig.world_size_z() - 1))


func diagnostics() -> Dictionary:
	return {
		"chuva": chuva, "molhado": molhado,
		"rise": WEATHER_RISE, "decay": WEATHER_DECAY, "snap": WEATHER_SNAP,
		"pedidos_aplicados": pedidos_aplicados, "frames_integrados": frames_integrados,
	}
