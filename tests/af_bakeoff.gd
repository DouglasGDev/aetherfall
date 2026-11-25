extends SceneTree
## af-bakeoff (dossie 07, peça c): a mesa do bake-off de voxel. Roda a sessao real,
## imprime `gen_ms`, `mesh_ms`, `triangles` e — a coluna que faltava — o custo de uma
## edicao local ate o mesh dela estar pronto, e exige que o braco medido seja nomeado
## na CLI. Sem essa tabela a escolha do mesher e opiniao (dossie 07 §1).
##
## O que este runner NAO e, com todas as letras:
## - NAO e o `af-bench` do dossie 07b nem um gate de boot: o lote curto de ticks aqui
##   so existe para a edicao cair num mundo vivo, com a fila de malharia rodando no
##   orcamento de frame do produto (MESH_BUDGET = 2, src/main.gd:28).
## - NAO mede FPS nem "fluidez": nenhum numero desta saida e de janela de render, e o
##   §6 do dossie nao promete nenhum.
## - NAO troca o mesher: a saide do mesher e a mesma em todo braco, e e por isso que
##   REF_TRIANGLES e REF_BODY_SHA sao checagens e nao observacoes. Um braco que mover o
##   triangulo ou o byte do corpo nao mediu o mesmo mundo e a tabela inteira cai — o
##   runner fica vermelho, nao discreto.
##
## Por que a edicao entra por `world.set_block` e nao por tecla: a borda de input de
## minerar/colocar ja tem medicao propria, e `set_block` E a transicao que o jogador usa
## (src/entities/player.gd:685 e :711). Escrever `chunk.data` por fora seria premissa
## montada a mao; chamar o dono do estado e o caminho real, com `record = true`.
##
## `dt` fixo: mesmo argumento do af-bench (tests/af_bench.gd:15-28) — `process_mode =
## DISABLED` antes de a sessao entrar na arvore para o motor nao chamar nada por cima, e
## cada `_physics_process`/`_process` devolve um passo de `STEP`.

const Main = preload("res://src/main.gd")
const MAIN_SCENE: PackedScene = preload("res://src/main.tscn")

const SCENARIO := "voxel_bakeoff"
## Os dois bracos que a mesa aceita hoje. `B` (greedy) e `D` (GDExtension) nao tem
## braço aqui enquanto A-vs-C nao estiver de pe (dossie 07 §4).
const ARM_A := "A"
const ARM_C := "C"
## Referencia do braco A (a arvore landada): 214.448 triangulos no mundo RECEM-GERADO de
## 64 chunks da seed 20261116, contado no boot, antes de qualquer edicao. O numero
## publicado em README e status e 214.480 e vem do diagnostico FINAL da suíte, que roda
## 13-14 edicoes antes de imprimir — os dois sao instantes diferentes do mesmo mundo e a
## tabela do bake-off precisa de um so. Checar e o ponto: um braco que muda a saide do
## mesher nao e um braco de "onde lem os bytes do vizinho".
const REF_TRIANGLES := 214448
## SHA256 dos 64 `data` de chunk concatenados (cz externo, cx interno) depois do lote de
## edicoes. Nao depende do caminho de leitura — `A` responde pelo `_flat`, `C` pelo halo
## — entao os dois bracos tem de bater no mesmo byte ou a comparacao e fraude.
const REF_BODY_SHA := "619e891c95dc5b44e2ebafabdf069bff16c9213beb47108a8f3cae43bb7a32cf"
# Grade 5x5 de colunas mineradas ao redor do spawn + 5 blocos devolvidos ao mundo: o
# vaivem do jogador normal (cava um pouco, tapa um pouco) = 30 edicoes aceitas.
const GRID := 5
const PLACES := 5
# Frames de settling antes do lote: `spawn_point` poe o pe no topo da coluna
# (src/main.gd:247-250) e as colunas do lote sao lidas do pe ja pousado.
const SETTLE_FRAMES := 20
# Teto do dreno: se a fila nao esvazia em 64 frames de 2 chunks, algo esta sujando mais
# do que o lote e o numero impresso seria de uma corrida incompleta.
const MAX_DRAIN_FRAMES := 64
## 10 checagens do lote + a do proprio censo. Contar checagem e o que pega o SCRIPT ERROR
## que derruba um passo em silencio (mandato 1).
##
## A decima do lote e `corte_nao_cobra_latencia_maior_que_o_pico` (dossie 24 §5.1 gate 2) e
## ela mora AQUI, nao no runner de reacoes, por um motivo lido e nao de gosto: as tres
## grandezas que a composta precisa — `mesh_ms` do diagnostico, `mean_us` do censo de
## edicao e o teto de frames do dreno — so existem juntas numa sessao que fez o lote de 30
## edicoes. O runner de reacoes mede um frame de malharia isolado; nao tem lote, nao tem
## latencia media.
const EXPECTED_CHECKS := 12

var _checks: int = 0
var _failures: int = 0
var _ran: bool = false
var _started_us: int = 0
var _mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _main: Main = null
var _arm: String = ""
var _boot_meshes: int = 0
var _edits_done: int = 0
var _wait_frames_max: int = 0


func _initialize() -> void:
	_started_us = Time.get_ticks_usec()
	_mouse_mode = Input.mouse_mode
	# Sem `await`: o rodape sai mesmo se o lote abortar no meio.
	_run.call_deferred()
	_finish.call_deferred()


func _check(ok: bool, label: String, detail: String) -> bool:
	_checks += 1
	print("%s %-42s %s" % ["OK" if ok else "FALHA", label, detail])
	if not ok:
		_failures += 1
	return ok


func _arg(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


func _run() -> void:
	# --- premissa 1: o braco vem da CLI. Log sem braco nomeado nao entra em tabela:
	# seis arquivos parecidos sao indistinguidos depois, e a mesa e feita deles.
	_arm = _arg("--arm=")
	if not _check(_arm == ARM_A or _arm == ARM_C, "braco nomeado na CLI",
			"pedido=%s aceitos=%s,%s" % [_arm, ARM_A, ARM_C]):
		_ran = true
		return

	# --- boot real: `_ready` gera o mundo e malha os 64 chunks (src/main.gd:129-136),
	# entao `gen_ms`/`mesh_ms`/`triangles` que saem daqui sao os do produto.
	_main = MAIN_SCENE.instantiate() as Main
	_main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_main)
	var diag: Dictionary = _main.diagnostics()
	_boot_meshes = int(diag["meshes"])
	var tri_boot: int = int(diag["triangles"])
	_check(_main.world != null and _main.clock != null and _main.player != null
			and _boot_meshes == int(diag["chunks"]), "boot real malhou todos os chunks",
			"chunks=%d meshes=%d gen_ms=%.1f mesh_ms=%.1f" % [
			diag["chunks"], _boot_meshes, diag["gen_ms"], diag["mesh_ms"]])
	_check(_main.process_mode == Node.PROCESS_MODE_DISABLED and not _main.can_process(),
			"motor sem processo automatico", "main=%s" % str(not _main.can_process()))
	_check(tri_boot == REF_TRIANGLES, "triangles do boot == referencia",
			"%d/%d" % [tri_boot, REF_TRIANGLES])
	# Parenteses obrigatorios no `%` (a liesao do af-bench): sem eles o formatador so
	# pega o ultimo fragmento e o print vira literal com ERROR no log.
	print(("OBSERVACAO braco=%s cenario=%s gen_ms=%.3f mesh_ms=%.3f chunks=%d meshes=%d "
			+ "triangles=%d") % [
			_arm, SCENARIO, diag["gen_ms"], diag["mesh_ms"], diag["chunks"],
			_boot_meshes, tri_boot])

	var dt: float = _main.clock.step_duration()
	for _i: int in SETTLE_FRAMES:
		_main._physics_process(dt)
		_main._process(dt)
	var feet := _main.player.body.feet_pos
	var ox := int(floor(feet.x)) - int(GRID / 2)
	var oz := int(floor(feet.z)) - int(GRID / 2)
	# A fila pode ter algo do settling; o censo do instrumento compara `count` com os
	# remeshes DO LOTE, entao a fila inicial sai como numero, nao como suposicao.
	var pending_before: int = _main.world.pending_meshes()

	# --- o lote: cava a grade 5x5 e devolve `PLACES` blocos, cada edicao seguida dos
	# frames reais de logica + malharia para o carimbo fechar no orcamento do produto.
	for dz: int in GRID:
		for dx: int in GRID:
			var x: int = ox + dx
			var z: int = oz + dz
			var y: int = _main.world.surface_height(x, z)
			if _main.world.set_block(Vector3i(x, y, z), BlockDefs.Block.AIR):
				_edits_done += 1
			_wait_frames_max = maxi(_wait_frames_max, _drain(dt))
	_edits_done += _restore_places(dt, ox, oz)

	# --- as testemunhas saem do objeto vivo, nao de um Nil.
	diag = _main.diagnostics()
	var cost: Dictionary = diag["edit_mesh"]
	var remeshes: int = int(diag["meshes"]) - _boot_meshes
	_check(_edits_done == GRID * GRID + PLACES, "o lote editou o mundo inteiro",
			"aceitas=%d/esperadas=%d edits_dic=%d" % [
			_edits_done, GRID * GRID + PLACES, diag["edits"]])
	_check(_main.world.pending_meshes() == 0 and int(cost["pending"]) == 0,
			"fila de malharia drena", "pendentes=%d carimbos_abertos=%d" % [
			_main.world.pending_meshes(), cost["pending"]])
	# A conta do instrumento tem de bater com o trabalho que a fila fez: todo chunk
	# remalhado por edicao fecha um carimbo, e nenhum carimbo fecha sem remesh.
	_check(int(cost["count"]) == remeshes - pending_before,
			"custo de edicao == chunks remalhados", "count=%d remeshes=%d fila_ini=%d" % [
			cost["count"], remeshes, pending_before])
	_check(int(cost["worst_us"]) > 0 and float(cost["mean_us"]) > 0.0,
			"instrumento vivo (worst e mean > 0)", "worst_us=%d mean_us=%.1f" % [
			cost["worst_us"], cost["mean_us"]])
	# Checagem 2 do gate do dossie 24 §5.1, no unico lugar onde os dois numeros dela existem
	# na mesma sessao: a composta `mesh_ms + 52*mean_us` que o dossie 07:72 definiu como regua
	# de mesher. O teto e a base medida nesta arvore (10 285,48 ms, media de tres corridas de
	# §2.2.1) vezes a tolerancia de 10 % que o dossie 07:101 ja usa para trocar de mesher: um
	# corte de frame que mover a composta para cima nao cortou nada, trocou de victima --
	# comprou quadro devolvendo fila, que e a unica maneira de o §3.3.1 errado acontecer.
	var composta := float(diag["mesh_ms"]) + (52.0 * float(cost["mean_us"]) / 1000.0)
	_check(composta <= 11313.03 and _wait_frames_max <= MAX_DRAIN_FRAMES,
			"corte_nao_cobra_latencia_maior_que_o_pico",
			"composta=%.2f teto=11313.03 mesh_ms=%.2f mean_us=%.1f esper_max_frames=%d/%d" % [
			composta, float(diag["mesh_ms"]), float(cost["mean_us"]),
			_wait_frames_max, MAX_DRAIN_FRAMES])
	var sha := _body_sha(_main.world)
	_check(sha == REF_BODY_SHA, "corpo do mundo == SHA de referencia", sha.left(32))
	print(("OBSERVACAO edits_aceitas=%d remeshes=%d fila_inicial=%d esper_max_frames=%d "
			+ "worst_sim_ms=%.3f dropped_ticks=%d tick=%d") % [
			_edits_done, remeshes, pending_before, _wait_frames_max,
			diag["worst_sim_ms"], diag["dropped_ticks"], diag["tick"]])
	print(("OBSERVACAO edit_cost count=%d worst_us=%d mean_us=%.1f pending=%d") % [
			cost["count"], cost["worst_us"], cost["mean_us"], cost["pending"]])
	print("OBSERVACAO corpo_sha256=%s" % sha)
	print("escopo: custo de edicao e do carimbo posto em `_mark` ao fim de "
			+ "`build_chunk_mesh` (src/world/voxel_world.gd), aggregate da SESSAO; "
			+ "load/regenerar fecha os carimbos abertos sem cobra-los")
	print("NAO fecha: gate de fase nenhum (mandato 4), nenhum FPS, nenhuma troca de "
			+ "mesher — a troca e do §6 do dossie e pede > 10% em mesh_ms somado ao "
			+ "custo de edicao")
	print(("GATE braco=%s gen_ms=%.3f mesh_ms=%.3f triangles_boot=%d edit_count=%d "
			% [_arm, diag["gen_ms"], diag["mesh_ms"], tri_boot, cost["count"]]
			+ "edit_worst_us=%d edit_mean_us=%.1f triangles_lote=%d corpo=%s") % [
			cost["worst_us"], cost["mean_us"], diag["triangles"], sha.left(16)])
	_ran = true


## Frames de logica + malharia depois de uma edicao, ate a fila esvaziar (ou o teto).
## Devolve quantos frames a edicao esperou: a latencia que o jogador sente, e o
## `worst_us` do instrumento e o mesmo numero em microsegundos.
func _drain(dt: float) -> int:
	var frames := 0
	while _main.world.pending_meshes() > 0 and frames < MAX_DRAIN_FRAMES:
		_main._physics_process(dt)
		_main._process(dt)
		frames += 1
	return frames


## Devolve os `PLACES` primeiros blocos cavados (ar -> pedra) e conta o que entrou.
func _restore_places(dt: float, ox: int, oz: int) -> int:
	var done := 0
	for dz: int in GRID:
		for dx: int in GRID:
			if done >= PLACES:
				break
			var x: int = ox + dx
			var z: int = oz + dz
			var y: int = _main.world.surface_height(x, z) + 1
			if _main.world.set_block(Vector3i(x, y, z), BlockDefs.Block.STONE):
				done += 1
			_wait_frames_max = maxi(_wait_frames_max, _drain(dt))
	return done


## SHA256 do corpo voxel na ordem estrutural, lida direto do storage do chunk: nem
## `_flat` nem halo participam, entao o byte e a mesma testemunha para qualquer braco.
func _body_sha(w: VoxelWorld) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for cz: int in VoxelConfig.WORLD_CHUNKS_Z:
		for cx: int in VoxelConfig.WORLD_CHUNKS_X:
			var c: VoxelChunk = w.chunks[Vector2i(cx, cz)]
			ctx.update(c.data)
	return ctx.finish().hex_encode()


func _finish() -> void:
	Input.mouse_mode = _mouse_mode
	_check(_ran, "runner chegou ao fim do lote", "run=%s" % str(_ran))
	_check(_checks + 1 == EXPECTED_CHECKS, "censo de checagens",
			"%d/%d" % [_checks + 1, EXPECTED_CHECKS])
	print("%d checagens %d falhas %.3f s" % [
		_checks, _failures, float(Time.get_ticks_usec() - _started_us) / 1000000.0])
	quit(1 if _failures > 0 else 0)
