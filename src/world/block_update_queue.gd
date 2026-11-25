class_name BlockUpdateQueue
## Fila de eventos de bloco (dossie 17 §3.2, doc 10 §10.5). A unica porta de entrada para a
## pergunta "esta celula tem gravidade?" e o sinal `block_changed`.
##
## A garantia nao e orcamento de CPU, e contagem de leitura: posicao que ninguem colocou na
## fila nunca e lida, em nenhum frame. Uma varredura de gravidade por tick sobre o mapa de
## 128 x 64 x 128 = 1.048.576 celulas custaria 20.971.520 `get_block` por segundo a 20 Hz.
## Com a fila o preco e dois testes por edicao, e o numero de edicoes e o que o jogador e o
## bicho cavando escreveram. `queda_sem_varredura_de_mundo` e a checagem que nao deixa a
## frase virar prosa: ela conta as leituras num cenario de 1.000 ticks sem nenhuma edicao
## e exige zero.

const MAX_PER_TICK: int = 256      # teto de resolucoes por tick de fila
const MAX_QUEUED: int = 8192       # teto de memoria da fila
const RECHECK_DELAY: int = 1       # tick; e o que faz a cascada descer em passos, nao de uma vez

var world: VoxelWorld = null
var spawner: FallingBlockSpawner = null

var _pending: Dictionary = {}      # Vector3i -> int (passo interno em que testar)
## Relogio interno, monotonico de verdade. O `tick` que `flush` recebe e so diagnostico:
## o quiesce do save roda passos A FRENTE do `clock.tick` (dossie 17 §3.7) e agendar a
## fila pelo tick do mundo deixaria grao marcado para o passado, ou seja, preso.
var _step: int = 0
var _tick_arg: int = 0
var _events: int = 0
var _resolutions: int = 0
var _reads: int = 0
var _overflow: int = 0


func attach(p_world: VoxelWorld, p_spawner: FallingBlockSpawner) -> void:
	world = p_world
	spawner = p_spawner
	p_world.block_changed.connect(_on_block)


## Estado volatorio da sessao: o load restaura um mundo ja em repouso, entao nenhum grao
## pendente do disco pode sobreviver aqui. Os contadores ficam cumulativos porque sao a
## medida da sessao, nao do ultimo load.
func clear() -> void:
	_pending.clear()


func flush(tick: int) -> int:
	_tick_arg = tick
	_step += 1
	if _pending.is_empty():
		return 0
	var due: Array = _due()
	var done: int = 0
	for p: Vector3i in due:
		if done >= MAX_PER_TICK:
			break
		done += 1
		_pending.erase(p)
		_resolutions += 1
		_resolve(p)
	return done


## Os unicos numeros que a suíte e o F3 leem. `events` conta o sinal recebido e `reads` as
## leituras que a fila fez no grid do mundo: a dupla e o que permite escrever "leituras <=
## 2 x eventos + 2 x resolucoes" e conferir, em vez de afirmar que a fila e barata.
func stats() -> Dictionary:
	return {
		"queued": _pending.size(), "events": _events, "resolutions": _resolutions,
		"reads": _reads, "overflow": _overflow, "step": _step, "tick": _tick_arg,
	}


# ------------------------------------------------------------------ entrada

func _on_block(pos: Vector3i, _prev: int, now: int) -> void:
	_events += 1
	# A regra do pedido e literal: quem muda uma celula altera o apoio de duas — a de cima,
	# que pode ter perdido o chao, e a propria, que pode ter ganhado um grao.
	_try(Vector3i(pos.x, pos.y + 1, pos.z))
	if now != BlockDefs.Block.AIR:
		_try(pos)


func _try(p: Vector3i) -> void:
	if _pending.has(p):
		return
	if world == null:
		return
	_reads += 1
	if not BlockDefs.has_gravity(world.get_block(p)):
		return
	if _pending.size() >= MAX_QUEUED:
		# Expansao maior que a fila: o grao fica adiado, nunca perdido de vista.
		_overflow += 1
		return
	_pending[p] = _step + RECHECK_DELAY


# ------------------------------------------------------------------ resolucao

## Ordem Y decrescente, depois X, depois Z. Numa pilha de N areias sem apoio isso e o que
## faz a cascada resolver em N ticks de um grao cada; em ordem de dicionario a ordem sairia
## da ordem de insercao -- e a mesma semente daria hashes diferentes entre execucoes.
func _due() -> Array:
	var out: Array = []
	for p: Vector3i in _pending:
		if int(_pending[p]) <= _step:
			out.append(p)
	out.sort_custom(_mais_acima)
	return out


static func _mais_acima(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y > b.y
	if a.x != b.x:
		return a.x < b.x
	return a.z < b.z


func _resolve(p: Vector3i) -> void:
	_reads += 1
	var b: int = world.get_block(p)
	if not BlockDefs.has_gravity(b):
		return
	_reads += 1
	if world.is_supported(p):
		return
	if spawner != null:
		spawner.convert(p, b)
