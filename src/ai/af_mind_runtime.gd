class_name AfMindRuntime
extends Node
## Dono do ciclo de vida do pack DENTRO do processo (dossie 22 §6.3, Passo 4):
## aponta o runtime do llama, abre o pack base, carrega o gguf e abre o contexto
## na AfMindOracle — e le as metricas que a ponte mede. O que o antigo
## `LlmServerHost` fazia e aqui MORRE com o transporte HTTP: processo filho
## (`OS.create_process`), sonda de porta, o vigia e os dois kills nao existem
## mais — nao ha servidor externo para subir, vigiar ou matar; o modelo vive no
## processo da engine e o `Rodar.bat` nao levanta processo nenhum de IA, o fecho
## da perna 15 que o §6.3 promete.
##
## Nada aqui decide estado de mundo (mandato 2): a classe fala com a ponte
## nativa e com o disco. O custo pesado agora e do proprio processo: o
## `load_pack` do gguf e uma chamada sincrona da extensao, e o frame que a
## executa trava o tempo do load (o `open_ms` da ponte mede o numero) — o
## overlap que o processo filho dava com a geracao acabou, e o regresso e
## registrado na nota do Passo 4, nao escondido.

## Estados da matriz de falha, agora sobre disco e ClassDB (dossie 22 §6.3):
## cada transicao imprime estado + numero no log, no padrao do §5 do dossie 15.
const IDLE := "ocioso"
const NO_EXT := "ausente (extensao)"
const NO_RUNTIME := "ausente (runtime)"
const NO_MODEL := "ausente (modelo)"
const LOADING := "carregando"
const READY := "pronto"
const OFF := "desligado"

## Cadencia dos passos do carregamento (o precedente da casa e o teto de 1 s do
## `CORPSE_CHECK`): cada passo do pack roda em um frame proprio para a linha do
## F3 acompanhar o progresso em vez de congelar em silencio.
const STEP_PERIOD := 1.0

@export var runtime_path: String = ""
@export var model_path: String = ""
@export var ctx_size: int = 4096

## O oraculo dono da ponte: o host dirige o ciclo de vida NO MESMO objeto
## AfMindOracle que o wrapper usa para `enqueue`/`wait` — um objeto so por
## processo, um pack so, os ~7 GB de VRAM uma vez (dossie 22 §6.3).
var oracle: MindOracle = null

var state: String = IDLE
var detail: String = ""
## Chamadas emitidas na ponte (load_pack/ctx_probe): zero quando falta disco —
## a checagem da suite confere que sem premissa nada e emitido.
var requests_issued := 0
var af_load_ms: float = -1.0
var _cd := 0.0
## Subpasso do LOADING: 1 = pack base, 2 = gguf, 3 = ctx_probe.
var _passo := 0


func _process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	match state:
		IDLE, NO_EXT:
			_begin()
		LOADING:
			if _cd <= 0.0:
				_passo_do_pack()
		READY:
			pass


## Portao do oraculo (dossie 15 §4.4, mesma semantica sobre outra base): so abre
## quando o pack esta no estado de fila (4) — antes disso pedir e recusar.
func ready() -> bool:
	return state == READY


func status_line() -> String:
	match state:
		NO_EXT:
			return "llm: %s  sem AfMindOracle na ClassDB  %s" % [state, detail]
		NO_RUNTIME, NO_MODEL:
			return "llm: %s  rode tools\\fetch_models.ps1 -Pack %s" % [
				state, "runtime" if state == NO_RUNTIME else "mind-small"]
		LOADING:
			return "llm: %s  passo %d/3  %s" % [state, _passo, detail]
		READY:
			var tail := ""
			# Um 401 no HTTP tinha o mesmo papel: a falha do oraculo nao pode virar
			# recuo anonimo no F3, entao as duas pontas aparecem juntas (dossie 15 §9).
			if oracle != null and not oracle.last_reason.is_empty():
				tail = "  oraculo: %s" % oracle.last_reason
			# As metricas de TRABALHO do modelo que o §2.4 cobrou (dossie 22): a
			# profundidade da fila, o pior decode que a ponte mediu e a taxa de
			# cache — o retrato que o dicionario do processo antigo nunca teve.
			# Sem ponte, -1 e o numero ausente NOMEADO, nao um 0 que parece
			# leitura (§7.2 do dossie 22).
			var ext_f := _ponte()
			return "llm: %s  ctx %d  load %.0f ms  vram %.1f GB  fila %d  decode %d us  cache %d/%d%s" % [
				state, ctx_size, af_load_ms, _vram_gb(),
				_int_de(ext_f, "queue_depth"), _int_de(ext_f, "worst_decode_us"),
				_int_de(ext_f, "cache_hits"), _int_de(ext_f, "cache_misses"), tail]
	return "llm: %s  %s" % [state, detail]


## Dez chaves honestas para o F3: as do processo antigo que morreram com ele
## (pid, boot_ms, 503, retries, kills, url) saem; entram as da ponte nativa.
func diagnostics() -> Dictionary:
	var ext := _ponte()
	return {
		"state": state, "detail": detail, "pack_state": _pack_state(),
		"ctx_size": ctx_size, "af_load_ms": af_load_ms,
		"vram_gb": _vram_gb(), "queue_depth": _int_de(ext, "queue_depth"),
		"worst_decode_us": _int_de(ext, "worst_decode_us"),
		"cache_hits": _int_de(ext, "cache_hits"),
		"cache_misses": _int_de(ext, "cache_misses"),
	}


# ------------------------------------------------------------------ boot

## Primeira passada: disco primeiro (runtime, modelo), ponte depois. A ordem e a
## do host antigo — a falta de runtime vence a de modelo, e as duas frases sao
## diferentes de proposito porque "-Pack runtime" e "-Pack mind-small" nao sao a
## mesma falta (mandato 1: nada de placeholder bonito no meio do motivo).
func _begin() -> void:
	var runtime := _resolved_runtime()
	if not FileAccess.file_exists(runtime + "/llama.dll"):
		_set_state(NO_RUNTIME, "sem runtime do llama em %s" % runtime)
		return
	var model := _resolved_model()
	if not FileAccess.file_exists(model):
		_set_state(NO_MODEL, "sem modelo em %s" % model)
		return
	var ext := _ponte()
	if ext == null:
		# A ClassDB sem AfMindOracle e terminal-recuperavel: a extensao pode nem
		# existir neste clone (o dll e gitignored), e a frase carrega o caminho.
		_set_state(NO_EXT, "AfMindOracle nao esta na ClassDB nesta arvore")
		return
	var modulos := int(ext.set_runtime_dir(runtime))
	if modulos <= 0:
		_fail("set_runtime_dir(%s) devolveu %d  err='%s'" % [runtime, modulos,
				String(ext.err_text())])
		return
	requests_issued += 1
	_passo = 0
	_cd = STEP_PERIOD
	_set_state(LOADING, "runtime %d modulos  gguf %s" % [modulos, model])


## Os tres passos do §5.2, um por frame, na ordem medida (a rota do passo 2 (b)
## e a unica que os numeros da ponte ja conferem): pack vazio, gguf, ctx_probe.
func _passo_do_pack() -> void:
	var ext := _ponte()
	if ext == null:
		_fail("a ponte sumiu no meio do carregamento")
		return
	_cd = STEP_PERIOD
	match _passo:
		0:
			var r := int(ext.load_pack("", ""))
			requests_issued += 1
			if r != 0:
				_fail("load_pack base devolveu %d  err='%s'" % [r, String(ext.err_text())])
				return
			_passo = 1
			detail = "pack base aberto (estado %d)" % int(ext.pack_state())
			print("af_mind_runtime  %s  %s" % [state, detail])
		1:
			var r := int(ext.load_pack(MindOracle.MODEL_ALIAS, _resolved_model()))
			requests_issued += 1
			if r != 0:
				_fail("load_pack(%s) devolveu %d  err='%s'" % [
					MindOracle.MODEL_ALIAS, r, String(ext.err_text())])
				return
			af_load_ms = float(ext.open_ms())
			_passo = 2
			detail = "gguf carregado (estado %d)  load %.0f ms" % [
				int(ext.pack_state()), af_load_ms]
			print("af_mind_runtime  %s  %s" % [state, detail])
		2:
			var r := int(ext.ctx_probe(ctx_size))
			requests_issued += 1
			if r != 0:
				_fail("ctx_probe(%d) devolveu %d  err='%s'" % [ctx_size, r,
						String(ext.err_text())])
				return
			_passo = 3
			_set_state(READY, "estado de fila %d  ctx %d  load %.0f ms" % [
				int(ext.pack_state()), ctx_size, af_load_ms])


# ------------------------------------------------------------------ ponte

## A ponte do oraculo, com guardinha de validade: `ext()` e o objeto que o
## wrapper criou no `_ready`, e quem chama antes de ele existir recebe null.
func _ponte() -> Object:
	if oracle == null or not is_instance_valid(oracle):
		return null
	return oracle.ext()


func _pack_state() -> int:
	return _int_de(_ponte(), "pack_state")


func _vram_gb() -> float:
	var b := _int_de(_ponte(), "vram_used_bytes")
	return float(b) / (1024.0 * 1024.0 * 1024.0) if b > 0 else -1.0


func _int_de(ext: Object, metodo: String) -> int:
	return int(ext.call(metodo)) if ext != null else -1


# ------------------------------------------------------------------ estados

## Toda transicao imprime o estado e o numero que o produziu: a matriz de falha
## do dossie 15 §5 cobra a frase no log, e o log headless vira evidencia.
func _set_state(next_state: String, next_detail: String) -> void:
	state = next_state
	detail = next_detail
	print("af_mind_runtime  %s  %s" % [state, detail])


func _fail(reason: String) -> void:
	_set_state(OFF, reason)


# ------------------------------------------------------------------ caminhos

func _resolved_runtime() -> String:
	return _resolve(runtime_path, _project_root() + "/.tools/llama/runtime",
			"AETHERFALL_LLM_RUNTIME", "--llm-runtime=")


func _resolved_model() -> String:
	return _resolve(model_path, _project_root() + "/models/qwen3.5-4b-q4_k_m.gguf",
			"AETHERFALL_LLM_MODEL", "--llm-model=")


## Tres camadas, na ordem: export do nodo < variavel de ambiente < CLI apos `--`.
## O override existe porque runtime e modelo nao estao no git: sem ele a medicao
## real so aconteceria no checkout principal (mesma regra do host antigo).
func _resolve(exported: String, fallback: String, env_name: String, flag: String) -> String:
	var chosen := exported
	var from_env := OS.get_environment(env_name)
	if not from_env.is_empty():
		chosen = from_env
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(flag):
			chosen = arg.trim_prefix(flag)
	return chosen if not chosen.is_empty() else fallback


func _project_root() -> String:
	return ProjectSettings.globalize_path("res://").replace("\\", "/").rstrip("/")
