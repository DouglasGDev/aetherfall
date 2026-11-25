extends Node
## Smoke test do slice: roda a sessao real (src/main.tscn) em headless e so conta
## como prova o que foi medido nesta execucao. Nada aqui injeta tecla no desktop:
## os unicos eventos sinteticos sao Input.action_press / Input.parse_input_event
## dentro deste proprio processo sem janela.
##
## Cada passo da lista espera um numero de frames de fisica e depois emite PASS/FAIL
## com o numero medido. Qualquer FAIL faz o processo sair com codigo 1.

const SEED := 20261116
const DT_SIM := 0.05
const ARM_STEPS := 40
const BELIEF := "danger_from_actor_1"
const SLOT := "alpha"
const ARM_NONE := 0
const ARM_WOUND := 1
const ARM_REMEMBER := 2

# Assinatura do terreno da revisao anterior ao `biome_of` (main e7e30e6, mundo
# recem-gerado de seed 20261116, sem edicao nenhuma): SHA256 das 16 colunas de
# relevo que a suite ja compara, SHA256 da grade fixa de 32x32 `(x,z,altura,topo)` e
# o histograma dessa grade por id de bloco. Derivar bioma e leitura, nao escrita: se
# qualquer um dos tres se mover, o lote mudou o terreno e a premissa do dossie 09.2
# esta quebrada — nao e caso de "melhorar a assercao".
const BIOME_BASE_REL16_SHA := "f1fca48dc6d1db6e0ce0484ca5b16a8202ccedaafd0a0efcd1fc98d3ee71c9af"
const BIOME_BASE_TOP_SHA := "2b630c0085cc2e58ee280ba9edf82d91d53dd7efd6fe6faa609c8ca2436a436a"
const BIOME_BASE_TOP_HIST := "1=491 3=6 4=145 5=313 7=69"
# A grade de cima e uma amostra: com 4 em 4 blocos ela nao viu nenhuma coluna mudar
# quando o limiar de umidade foi de -0,30 para -0,50 de proposito, e passou verde
# sobre um terreno trocado. Esta e a premissa inteira, byte por byte, e e ela que
# morde.
const BIOME_BASE_FULL_SHA := "75fb058ed409b617afc03ac67444eb5f02f26dfd6c51ca81c30b22e640c147a1"

var main: Node3D = null
var _steps: Array = []
var _step := 0
var _frame := 0
var _until := 0
var _checks := 0
var _fails := 0
var _t0 := 0
var _scratch: VoxelWorld = null
var _scratch_root: Node3D = null
var _spawn := Vector3.ZERO
var _heights := {}
## Posicoes de lar por IDENTIDADE, nao por indice do array (dossie 11 §2, o nono
## sitio que tratava o censo como constante): com o nascimento na sessao o array
## cresce no meio da janela real, e `wolves[i]` contra `_spawn_pos[i]` passava a
## comparar o lobo certo contra a posicao do irmao -- ou a ler indice inexistente.
var _spawn_pos: Dictionary = {}
var _corpse_n := 0
var _place_voxel := Vector3i.ZERO
var _place_sel := 0
var _place_n0 := 0
var _place0 := 0
var _lava_target := Vector3i.ZERO
var _click_pending := false
var _click_state := false
var _armed := false
var _tick_player := false
var _click_frame := -1
var _click_detail := ""
var _swim_wolf: Wolf = null
var _swim_start := Vector3.ZERO
var _swim_bed_y := 0.0
var _swim_seen := false
var _swim_min_y := 999.0
var _swim_max_leg := 0.0
var _swim_seek := false
var _lake := Vector3i.ZERO
## Estado do FX da agua (dossie 23 §5.1): a coluna escolhida para a queda, o plano que
## o mundo devolve para ela, e as leituras de antes/depois de cada janela de 70 quadros.
var _fx_col := Vector2i.ZERO
var _fx_plane := -1.0
var _fx_home := Vector3.ZERO
var _fx_edits0 := 0
var _fx_sig := ""
var _fx_e0 := 0.0
var _fx_e1 := 0.0
var _fx_salpicos0 := 0
var _fx_seco0 := 0
var _fx_seco_e0 := 0.0
var _fx_seco_e1 := 0.0
var _fx_seco_p0 := Vector3.ZERO
var _fx_track := false
var _fx_seco_molhado := false
var _oracle_probe: MindOracle = null
## Runtime de mentira da checagem do portao (dossie 15 §7.8, semantica do §6.3
## do dossie 22): caminhos inexistentes, entao nem pack nem disco sao tocados.
var _gate_host: AfMindRuntime = null
var _gate_oracle: MindOracle = null

## Estado da Fase 2 (dossie 23 §5.3). Cada leitura vive aqui porque o gate e armado num
## passo e cobrado no seguinte — o mesmo formato das janelas de 70 quadros do FX da agua.
## A pilha de seis pedras do palco de exposicao (`CH_STACK`) existe para que o canal A
## tenha um 0, um 0,75 e um 1 dentro de um chunk de terreno real, sem depender do relevo
## que a semente resolveu desenhar naquele chunk.
const CH_STACK := 6
const CH_RNG_PIN := 7301
var _ch_scratch: VoxelWorld = null
var _ch_scratch_root: Node3D = null
var _ch_mesh: Mesh = null
var _ch_pilha := Vector3i(-1, -1, -1)
var _ch_op := {}
var _ch_fall := -1.0
var _ch_ramp_up := -1.0
var _ch_up_frame := -1
var _ch_down_frame := -1
var _ch_e0 := 0.0
var _ch_e1 := 0.0
var _ch_edits0 := 0
var _ch_sig := ""
var _ch_col := Vector2i(-1, -1)
var _ch_rings0 := -1
var _ch_refus0 := -1


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	_spawn = main.spawn_point()
	for x in [12, 44, 100, 116]:
		for z in [12, 44, 100, 116]:
			_heights["%d,%d" % [x, z]] = main.world.surface_height(x, z)
	_steps = [
		["boot do mundo", 2, _check_boot],
		["relogio real", 150, _check_live],
		["malha e face-culling", 0, _check_meshing],
		["agua: material, mascara e malha", 0, _check_water_surface],
		["agua: fx — corpo seco", 0, _check_fx_dry_setup],
		["agua: fx — indiferenca na terra", 70, _check_fx_dry_assert],
		["agua: fx — queda na coluna", 0, _check_fx_drop],
		["agua: fx — salpico e teto", 70, _check_fx_splash],
		["corpo encaixado se solta", 0, _check_embedded_body],
		["edicoes no mundo", 0, _check_edits],
		["sistema de coordenadas", 0, _check_coords],
		["campo de eter", 0, _check_aether],
		["relogio de simulacao", 0, _check_clock],
		["minerar e colocar", 0, _check_mechanics],
		["colocar com clique", 20, _check_place],
		["soltar o botao", 12, _check_click_release],
		["guarda de colocacao", 20, _check_place_guard],
		["tecla 3 no hotbar", 3, _check_hotbar_key],
		["construir enquanto lava", 0, _check_build_setup],
		["lavra + clique direito", 20, _check_build_while_mining],
		["inventario, pilhas e receitas", 0, _check_items],
		["memoria muda comportamento", 0, _check_memory],
		["lobo na agua", 0, _check_swim_setup],
		["lobo nada e busca margem", 280, _check_swim_assert],
		["golpe no lobo: dano e empurrada", 0, _check_attack],
		["rolamento e invencibilidade", 0, _check_roll],
		["vigor: dreno, recupero e trava", 0, _check_energy],
		["planar e queda", 0, _check_glide_fall],
		["respiracao e afogamento", 0, _check_breath],
		["regeneracao fora de combate", 0, _check_regen],
		["oraculo: sonda em porta fechada", 0, _check_oracle_arm],
		["oraculo degrada sem servidor", 90, _check_oracle],
		["hospedeiro: portao fechado", 0, _check_llm_gate_arm],
		["portao fechado nao pede nada", 20, _check_llm_gate_closed],
		["portao aberto volta a pedir", 20, _check_llm_gate_open],
		["recuo nomeia a porta fechada", 90, _check_llm_backoff],
		["chave do servidor e a do oraculo", 0, _check_llm_key_drift],
		["hud, morte e renascer", 0, _check_hud],
		["salvar e carregar", 0, _check_save],
		["cadaver no chao", 0, _check_corpse],
		["recolhimento e reposicao", 460, _check_reap],
		["censo do disco", 0, _check_censo_disk],
		# As linhas da Fase 2 fecham o `_steps`, nao no meio dela: cada linha com espera
		# propria empurra o indice de quadro de tudo que vem depois, e `cubo no quadrante
		# inferior direito, mira livre` e uma assercao com menos de um pixel de folga sobre
		# uma pose que respira com o numero de quadros vivos (`fp_viewmodel.gd:79` soma
		# `_phase` a cada passo do jogador, e a pose de medida em `minerar e colocar` nao
		# azera a fase nos 20 `advance` proprios). Medido: base com 300 quadros a mais antes
		# daquela linha deu `cubo=[752..938 x 357..546]` e o mesmo VERMELHO, com codigo
		# identico em todo o resto. E o **furo #49**, dono a perna do viewmodel em 1a
		# pessoa; enquanto ele nao for pago, nenhuma linha nova com espera entra na frente.
		["chuva: material opaco e fiel", 0, _check_opaque_surface],
		["chuva: exposicao de ceu por coluna", 0, _check_weather_exposure],
		["chuva: dono do clima", 0, _check_weather_owner],
		["chuva: rampa — subir", 0, _check_weather_ramp_arm],
		["chuva: rampa — descer", 150, _check_weather_ramp_down],
		["chuva: rampa — desce e chega no material", 60, _check_weather_ramp_assert],
		["chuva: rng da sessao", 0, _check_weather_rng],
		["chuva: janela molhada — armar", 0, _check_rain_window_arm],
		["chuva: anel, orcamento e nao-escrita", 90, _check_rain_window_assert],
	]
	_until = int(_steps[0][1])
	print("== aetherfall smoke test  seed %d ==" % SEED)


func _physics_process(_delta: float) -> void:
	_frame += 1
	# Mundo congelado: sem process_mode ligado quem da o passo no jogador e o teste,
	# senao a borda do clique cairia num frame em que ninguem le o input.
	if _tick_player:
		main.player.update_local(1.0 / 60.0)
	if _swim_wolf != null and is_instance_valid(_swim_wolf) and _swim_wolf.alive:
		if _swim_wolf.body.in_water:
			_swim_seen = true
			_swim_min_y = minf(_swim_min_y, _swim_wolf.body.feet_pos.y)
			for leg in _swim_wolf._legs:
				_swim_max_leg = maxf(_swim_max_leg, absf((leg as Node3D).rotation.x))
		if _swim_wolf._swim_time > Wolf.SHORE_AFTER \
				and _swim_wolf._dry_ground(_swim_wolf._move_target):
			_swim_seek = true
	if _fx_track and main.water_fx != null and main.player.body.in_water:
		# A janela seca e testemunhada quadro a quadro: `in_water` falso so porque
		# ninguem olhou no meio dela nao e prova de indiferenca.
		_fx_seco_molhado = true
	if _armed and Input.is_action_just_pressed("place_block"):
		var p: Player = main.player
		_armed = false
		# A borda chega num quadro em que o jogador NAO foi tickado de proposito: era
		# assim que o clique se perdia (medido na janela real: 163 quadros/s contra
		# 59,8 ticks -> 63,3% dos quadros sem tick). Do proximo frame em diante o
		# passo volta e o buffer de 0,22 s e obrigado a produzir o bloco.
		_tick_player = true
		_click_frame = _frame
		_click_detail = "frame=%d  alvo=%s  place=%s  no_corpo=%s  cooldown=%.3f" % [
			_frame, p.target_voxel, p.place_voxel,
			p.body.aabb().intersects(AABB(Vector3(p.place_voxel), Vector3.ONE)), p._place_cd]
	if _step >= _steps.size() or _frame < _until:
		return
	var s: Array = _steps[_step]
	print("\n--- %s ---" % s[0])
	(s[2] as Callable).call()
	_step += 1
	if _step < _steps.size():
		_until = _frame + int(_steps[_step][1])
	else:
		_finish()


func _process(_delta: float) -> void:
	## O clique sintetrico sai daqui, no tempo ocioso, como no jogo real (o evento
	## nasce antes da fisica). Medido nesta maquina, headless, o engine so drena a
	## fila de 6 a 7 iteracoes depois de `Input.parse_input_event()` -- por isso o passo
	## que arma o clique congela o mundo e segue girando o jogador ate a borda
	## aparecer, em vez de confiar num numero fixo de frames.
	if _click_pending:
		_click_pending = false
		_click(_click_state)


func _check(label: String, ok: bool, detail := "") -> void:
	_checks += 1
	if not ok:
		_fails += 1
	var tag := "PASS" if ok else "FAIL"
	# Um detalhe que devolve a propria barra de formato e o instrumento mudo: `String %`
	# do Godot nao implementa `%g` nem `%e` e nao avisa nada -- devolve a string como
	# veio, medido em `.tools/format_spec_probe.gd`. Um PASS com a barra crua nao e
	# testemunha de numero nenhum, entao a barra quebrada conta como falha.
	var quebrada := detail.contains("%s") or detail.contains("%d") or detail.contains("%f") \
			or detail.contains("%v") or detail.contains("%.")
	if quebrada:
		_fails += 1
		tag = "FAIL"
	print("  [%s] %-38s %s" % [tag, label, detail])


func _finish() -> void:
	var secs := float(Time.get_ticks_msec() - _t0) / 1000.0
	print("\n== %d checagens  %d falhas  %.1f s de teste ==" % [_checks, _fails, secs])
	get_tree().quit(1 if _fails > 0 else 0)


# --------------------------------------------------------------------- mundo

func _check_boot() -> void:
	var d: Dictionary = main.diagnostics()
	_check("64 chunks gerados", int(d["chunks"]) == 64, "chunks=%d" % d["chunks"])
	_check("64 chunks malhados", int(d["meshes"]) == 64, "meshes=%d" % d["meshes"])
	_check("mundo com triangulos", int(d["triangles"]) > 0, "triangulos=%d" % d["triangles"])
	# Censo variavel (dossie 14 §3.5): um lobo que nao acha ponto conforme nas tres
	# bandas nao nasce -- a vaga volta para a fila com o motivo impresso. O que nao
	# pode e faltar na conta ou passar do teto; "nasceram cinco" deixa de ser
	# premissa e vira invariante.
	_check("censo do boot fecha com a fila",
			int(d["wolves"]) <= main.WOLF_COUNT
			and int(d["wolves"]) + int(d["pending_respawns"]) == main.WOLF_COUNT,
			"lobos=%d fila=%d teto=%d" % [d["wolves"], d["pending_respawns"], main.WOLF_COUNT])
	_check("spawn em terra firme", _spawn.y > float(VoxelConfig.SEA_LEVEL), "y=%d" % int(_spawn.y))
	_check("jogador apoiado no chao", bool(d["on_ground"]), "feet=%s" % d["feet"])
	# Checagem 8 do gate (dossie 15 §7): a suíte inteira não pode depender de
	# modelo nem de rede, e o dono do processo filho é a primeira coisa que poderia
	# quebrar isso. Em headless o `main` não monta host nenhum — os 2,7 GB ficam do
	# lado de fora da rodada, e o número da banda de tempo continua valendo.
	_check("suite nao levanta modelo", not main.has_llm_host(),
			"display=%s  llm=%s" % [DisplayServer.get_name(), str(d["llm"])])
	print("       geracao %.1f ms   malharia %.1f ms" % [d["gen_ms"], d["mesh_ms"]])
	for w in main.wolves:
		_spawn_pos[w.identity] = w.global_position


func _check_live() -> void:
	var d: Dictionary = main.diagnostics()
	var tick := int(d["tick"])
	_check("tick de simulacao avanca", tick > 0, "tick=%d em %.2f s de logica" % [tick, float(main.elapsed)])
	_check("ritmo de 20 Hz sustentado", absf(float(tick) - float(main.elapsed) * 20.0) < 1.0,
		"tick=%d  esperado=%d" % [tick, int(float(main.elapsed) * 20.0)])
	_check("nenhum tick perdido", int(d["dropped_ticks"]) == 0,
		"perdidos=%d  pior passo=%.2f ms" % [d["dropped_ticks"], d["worst_sim_ms"]])
	_check("jogador segue no chao", bool(d["on_ground"]), "feet=%s" % d["feet"])
	var live_moved := 0
	var desde_boot := 0
	for w: Wolf in main.wolves:
		if not _spawn_pos.has(w.identity):
			continue
		desde_boot += 1
		if w.global_position.distance_to(_spawn_pos[w.identity]) > 0.5:
			live_moved += 1
	_check("ao menos um lobo se moveu na janela real", live_moved >= 1,
		"%d/%d se moveram em %.2f s de logica  nasceram_depois=%d" % [
		live_moved, desde_boot, float(main.elapsed), main.wolves.size() - desde_boot])
	var encaixados := ""
	var n_enc := 0
	for w in main.wolves:
		var wf := w as Wolf
		if wf.alive and wf.world.aabb_hits_solid(wf.body.aabb()):
			n_enc += 1
			encaixados += " lobo%d em %s" % [wf.identity, str(wf.body.feet_pos)]
	_check("nenhum lobo com o corpo dentro do terreno", n_enc == 0,
		"encaixados=%d%s" % [n_enc, encaixados])
	_check_wolf_steering()
	var intents := ""
	var legal := true
	for w in main.wolves:
		intents += "%s " % w.intent
		if not (w.intent in ["patrol", "hunt", "investigate", "flee"]):
			legal = false
	_check("intento sempre valido", legal, intents.strip_edges())
	# A matilha e injetada na sessao real, nao so no fixture do runner: o provedor tem
	# de chegar bindado na identidade de cada lobo, e a premissa da checagem de baixo e
	# mais forte que "o rebuild viu par" (furo #16): >= 2 vizinhos lidos, verde do mundo.
	var pack_ok := true
	var pack_lines := ""
	var biggest := 0
	for w: Wolf in main.wolves:
		var bound: Array = w.pack_provider.get_bound_arguments()
		pack_ok = pack_ok and w.pack_provider.is_valid() and bound.size() == 1 \
				and int(bound[0]) == w.identity
		biggest = maxi(biggest, w._pack.size())
		pack_lines += "lobo%d(%d viz) " % [w.identity, w._pack.size()]
	_check("provedor de matilha montado pela sessao real", pack_ok, pack_lines.strip_edges())
	var n_alive: int = int(d["wolves_alive"])
	var esperado: int = n_alive * (n_alive - 1) / 2
	var grupos := int(d["den_components"])
	var sep_tocas := float(d["den_min_dist"])
	# Furo #21 (dossie 16 §8), pago com numero: `pack_pairs == n(n-1)/2` e a
	# identidade aritmetica do laco duplo e valia antes com um circulo unico e com
	# tres tocas -- nao decidia coesao nenhuma, e por isso continua aqui rotulada
	# como o que e (pares TESTADOS). O que decide passou a ser `grupos`, os
	# componentes do grafo lido pela propria sessao. `biggest >= 2` fica porque ele
	# prova outra coisa: que o provedor chegou bindado ate o lobo (furo #16).
	_check("alcateia existe na sessao real",
			int(d["pack_pairs"]) == esperado and biggest >= 2 and grupos >= 2,
			"pares_testados=%d  esperado=%d  maior_matilha_lida=%d  grupos=%d  separacao_tocas=%s  lobos_vivos=%d  vizinhos=[%s]" % [
			int(d["pack_pairs"]), esperado, biggest, grupos,
			"sem_par" if sep_tocas < 0.0 else "%.1f m" % sep_tocas,
			n_alive, pack_lines.strip_edges()])


## O gate do movimento, medido em ticks proprios e com a situacao montada. O engine
## chama _physics_process tantas vezes quanto o relogio de parede deixa, entao contar
## lobos que andaram numa janela de tempo real era sorte: a mesma suite ja mediu 1/5,
## 2/5 e 3/5. Aqui o teste da o dt e o numero de passos, e poe o corpo num ponto
## onde ele cabe (o chao onde o lobo nasceu nao e nosso -- dois dos cinco nasceram
## dentro da parede, estado em que nenhum eixo anda; coberto pelo censo acima).
##
## So o passo, nao a decisao: chamar sim_step em serie da 40 s de IA de uma vez
## para cada lobo, eles caçam o jogador parado do teste e o matam antes das
## secoes de vigor/respiracao/morte (medido: 32 falhas em cascata). A decisao de
## andar fica gated pelo censo fraco acima e pelos checks de utilidade.
func _check_wolf_steering() -> void:
	var wf: Wolf = null
	for w in main.wolves:
		if (w as Wolf).alive:
			wf = w as Wolf
			break
	if wf == null:
		_check("steering e colisao movem o lobo", false, "nenhum lobo vivo")
		return
	var spot := _clear_stand_spot(wf)
	if spot == Vector3.INF:
		_check("steering e colisao movem o lobo", false, "nenhum ponto onde o corpo caiba")
		return
	var was_feet: Vector3 = wf.body.feet_pos
	var was_vel: Vector3 = wf.body.velocity
	var was_target: Vector3 = wf._move_target
	var was_stagger: float = wf._stagger
	var was_unstick: float = wf._unstick
	wf.body.feet_pos = spot
	wf.body.velocity = Vector3.ZERO
	wf._stagger = 0.0
	wf._unstick = 0.0
	wf._speed = Wolf.SPEED_WALK
	wf._move_target = spot + Vector3(0.0, 0.0, 8.0)
	var reach := 0.0
	for _step in 200:
		wf._physics_process(0.05)
		reach = maxf(reach, spot.distance_to(wf.body.feet_pos))
	_check("steering e colisao movem o lobo", reach > 0.5,
		"lobo%d reach=%.2f m em 200 passos desde (%.1f, %.1f, %.1f)  agora em %s"
			% [wf.identity, reach, spot.x, spot.y, spot.z, str(wf.body.feet_pos)])
	wf.body.feet_pos = was_feet
	wf.body.velocity = was_vel
	wf._move_target = was_target
	wf._stagger = was_stagger
	wf._unstick = was_unstick


## Pe sobre o terreno mais alto da coluna, procurando ao redor do spawn do jogador
## ate achar um ponto onde o corpo do lobo cabe e tem chao embaixo.
func _clear_stand_spot(wf: Wolf) -> Vector3:
	var c: Vector3 = main.spawn_point()
	for ring in [0, 2, 4, 6, 8, 10, 12]:
		for dirv in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var p: Vector3 = c + dirv * float(ring)
			var y: int = main.world.surface_height(int(p.x), int(p.z)) + 1
			var cand := Vector3(p.x, float(y), p.z)
			if y > VoxelConfig.SEA_LEVEL and wf.body.can_stand_at(cand):
				return cand
	return Vector3.INF


# --------------------------------------------------------------------- malha

func _check_meshing() -> void:
	_scratch_root = Node3D.new()
	add_child(_scratch_root)
	_scratch = VoxelWorld.new()
	_scratch.setup_world(_scratch_root)
	var t := Time.get_ticks_usec()
	_scratch.generate(SEED)
	_scratch.generate_meshes_all()
	var ms := float(Time.get_ticks_usec() - t) / 1000.0
	var tri_a := _scratch.triangle_count()
	var tri_b := int(main.diagnostics()["triangles"])
	var same := true
	for k in _heights:
		var parts: PackedStringArray = String(k).split(",")
		if _scratch.surface_height(int(parts[0]), int(parts[1])) != int(_heights[k]):
			same = false
	_check("geracao deterministica (16 colunas)", same, "ms=%.1f" % ms)
	_check("malha identica entre mundos", tri_a == tri_b, "espelho=%d  sessao=%d" % [tri_a, tri_b])
	# O numero e a base medida ANTES da perna 23 (clone limpo de b0ed929, seed
	# 20261116, nenhuma edicao). A agua ganhou shader e deslocamento de vertice, e
	# deslocamento nao acrescenta triangulo nenhum: se este numero se mover, a perna
	# mexeu na malharia — que e justamente o terreno que o re-rome das pernas 17 e 18
	# espera encontrar no mesmo lugar (dossie 23 §5.1, `agua_nao_muda_a_malha`).
	_check("agua nao muda a malha", tri_a == 214448 and tri_b == 214448,
		"base=214448  espelho=%d  sessao=%d" % [tri_a, tri_b])
	_check_biome_nao_altera_terreno(_scratch)

	var cx := 20
	var cz := 20
	var base := mini(_scratch.surface_height(cx, cz) + 12, VoxelConfig.CHUNK_SIZE_Y - 5)
	var air := true
	for dy in 3:
		for dz in 3:
			for dx in 3:
				if _scratch.get_block(Vector3i(cx + dx, base + dy, cz + dz)) != BlockDefs.Block.AIR:
					air = false
	_check("regiao do cubo estava em ar", air, "voxel=(%d,%d,%d)" % [cx, base, cz])
	var before := _scratch.triangle_count()
	for dy in 3:
		for dz in 3:
			for dx in 3:
				_scratch.set_block(Vector3i(cx + dx, base + dy, cz + dz), BlockDefs.Block.STONE, false)
	_scratch.generate_meshes_all()
	var delta := _scratch.triangle_count() - before
	_check("face-culling exato (cubo 3x3x3)", delta == 108,
		"delta=%d  esperado=108  sem culling=324" % delta)

	# Vidro: a unica face ALPHA do registro. Um pano sozinho mantem as 6 faces e o
	# pano colado ao lado nao acrescenta a de contato -- 20 triangulos no par, nao
	# 24. E assim que a classe de desenho e medida, nao de olho.
	var gx := cx + 6
	var glass_air := true
	for dy in 3:
		for dz in 3:
			for dx in 4:
				if _scratch.get_block(Vector3i(gx - 1 + dx, base - 1 + dy, cz - 1 + dz)) \
						!= BlockDefs.Block.AIR:
					glass_air = false
	_check("regiao do vidro estava em ar", glass_air, "voxel=(%d,%d,%d)" % [gx, base, cz])
	var pane := -1
	var pair := -1
	if glass_air:
		var g0 := _scratch.triangle_count()
		_scratch.set_block(Vector3i(gx, base, cz), BlockDefs.Block.GLASS, false)
		_scratch.generate_meshes_all()
		pane = _scratch.triangle_count() - g0
		_scratch.set_block(Vector3i(gx + 1, base, cz), BlockDefs.Block.GLASS, false)
		_scratch.generate_meshes_all()
		pair = _scratch.triangle_count() - g0
	_check("pano de vidro sozinho tem 6 faces", glass_air and pane == 12,
		"triangulos=%d  esperado=12" % pane)
	_check("vidro colado nao desenha a face de contato", glass_air and pair == 20,
		"par=%d  esperado=20  sem culling alfa=24" % pair)

	# Cada surface added tem que sair com material: os grupos (opaco, agua, vidro)
	# sao acrescentados condicionalmente, entao o indice do material nao pode ser
	# um numero fixo. Um chunk de vidro sem agua e o caso que pegava o indice 2
	# fora dos dois surfaces existentes e deixava o pano sem material.
	var sem_material := 0
	var surfaces := 0
	for ck in _scratch.chunks.values():
		var mi: MeshInstance3D = ck.mesh_instance
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			surfaces += 1
			if mi.mesh.surface_get_material(i) == null:
				sem_material += 1
	_check("todo surface de chunk tem material", surfaces > 0 and sem_material == 0,
		"surfaces=%d  sem material=%d" % [surfaces, sem_material])

	# e o pano tem que carregar o material de vidro, nao qualquer um: e isso que
	# decide transparencia e textura do atlas na janela do jogador
	var pane_key := Coords.chunk_of(Vector3i(gx, base, cz))
	var glass_mat := false
	if _scratch.chunks.has(pane_key):
		var pm: MeshInstance3D = _scratch.chunks[pane_key].mesh_instance
		if pm != null and pm.mesh != null:
			for i in pm.mesh.get_surface_count():
				if pm.mesh.surface_get_material(i) == _scratch._mat_glass:
					glass_mat = true
	_check("o pano de vidro usa o material de vidro", glass_air and glass_mat,
		"chunk=(%d,%d)" % [pane_key.x, pane_key.y])

	var c: VoxelChunk = _scratch.chunks[Vector2i(3, 3)]
	var solid := 0
	for y in VoxelConfig.CHUNK_SIZE_Y:
		for z in VoxelConfig.CHUNK_SIZE_Z:
			for x in VoxelConfig.CHUNK_SIZE_X:
				if BlockDefs.is_solid(c.get_block(x, y, z)):
					solid += 1
	var naive := solid * 12
	var real := _chunk_triangles(c)
	_check("culling dentro de um chunk", real > 0 and real < naive,
		"voxel solido=%d  malha=%d  sem culling=%d  (%.1f%%)" % [solid, real, naive, 100.0 * real / float(naive)])
	# Winding: o Godot (Vulkan inverte o Y do framebuffer) trata como frontal o
	# triangulo horario visto de fora, entao a normal geometrica do indice tem de
	# apontar CONTRA a normal do vertice. Com o indice em (0,1,2) todo topo era
	# descartado e o terreno aparecia transparente.
	var wn := _winding_bad(_scratch)
	_check("winding = face frontal do Godot", wn == 0, "triangulos contra=%d" % wn)
	_scratch_root.queue_free()
	_scratch = null


# --------------------------------------------------------------------- agua

## O gate visual do dossie 23 §5.1. Headless nao tem `RenderingDevice`, entao nada
## aqui pode afirmar que o shader compila nem que a agua mudou de quadro — as duas
## perguntas sao da sonda com janela (§5.2), e escrever "compila" num verde headless
## seria o furo que a casa ja contou duas vezes. O que esta funcão decide e
## estrutura: qual material pousa no surface de água e o que os três canais do
## `COLOR` dizem vértice por vértice. Os rótulos são os identificadores da página,
## para a régua de ids achar cada um no código que os imprime.
func _check_water_surface() -> void:
	_scratch_root = Node3D.new()
	add_child(_scratch_root)
	_scratch = VoxelWorld.new()
	_scratch.setup_world(_scratch_root)
	_scratch.generate(SEED)

	var mat := _scratch.water_material()
	# Os dois lados da testemunha de uniforme: a lista que o GDScript grava e a que a
	# SOURCE declara. Nome gravado sem declaracao correspondente e um no-op
	# silencioso — e headless nao compila shader nenhum para avisar. A regex le a
	# constante em vez de repetir a lista, senao a checagem conferiria um numero
	# contra ele mesmo.
	var declarados := WaterSurface.declared_uniforms()
	var gravados := WaterSurface.written_uniforms()
	var sem_fonte := 0
	for k: String in gravados:
		if not declarados.has(k):
			sem_fonte += 1
	# `declarados` e maior que `gravados` por dois: `screen_tex` e `depth_tex` sao
	# ligados pelo engine, nao por `set_shader_parameter`, e estao fora da lista que o
	# codigo grava de proposito. O que morde e `sem_fonte`: nome gravado sem
	# declaracao.

	# Uma celula de agua no ar, longe das bordas do chunk: o `LIQUID` so culling
	# contra AIR, entao saem as 6 faces — 24 vertices, 12 triangulos. Os numeros sao
	# derivados de FACE_CORNERS e do culling, nao lembrados (§5.1).
	var x := 21
	var z := 21
	var y := VoxelConfig.CHUNK_SIZE_Y - 6
	var cell := Vector3i(x, y, z)
	# `record = false`: o teste nao pode deixar edicao no mundo (a clausula "so
	# visual" e checagem, nao declaracao), e o mesh se reconstrói aqui, uma vez, sem
	# esperar o orcamento de 2 chunks por frame.
	_scratch.set_block(cell, BlockDefs.Block.WATER, false)
	_scratch.build_chunk_mesh(_scratch.chunk_at(cell))
	var mesh: Mesh = _scratch.chunk_at(cell).mesh_instance.mesh
	var wi := _water_surface_index(mesh, mat)
	_check("material_da_agua_e_shader",
		mat != null and mat is ShaderMaterial and mat.shader != null
			and wi >= 0 and sem_fonte == 0,
		"shader=%s  surface=%d  declarados=%d  gravados=%d  sem_fonte=%d" % [
			mat != null and mat is ShaderMaterial, wi, declarados.size(), gravados.size(), sem_fonte])

	var topo := float(y) + 1.0 - VoxelWorld.WATER_TOP_DROP
	var a := _water_attrs(mesh, wi, topo)
	_check("mascara_de_onda_do_bloco_isolado",
		a["verts"] == 24 and a["tri"] == 12 and a["masc"] == 12 and a["fora"] == 0
			and a["wall"] == 16 and a["gmax"] < 0.01,
		"verts=%d  tri=%d  mascarados=%d  fora_do_plano=%d  verticais=%d  g_max=%.3f"
			% [a["verts"], a["tri"], a["masc"], a["fora"], a["wall"], a["gmax"]])

	# O segundo bloco em cima do primeiro: o de baixo passa a ter agua no vizinho de
	# cima, entao a mascara dele e zero e a onda so existe no topo da coluna. Faces:
	# 5 do de cima (fundo culling contra agua) + 5 do de baixo (topo idem) = 40
	# vertices, 20 triangulos.
	var topo2 := float(y + 1) + 1.0 - VoxelWorld.WATER_TOP_DROP
	_scratch.set_block(Vector3i(x, y + 1, z), BlockDefs.Block.WATER, false)
	_scratch.build_chunk_mesh(_scratch.chunk_at(cell))
	var malha2: Mesh = _scratch.chunk_at(cell).mesh_instance.mesh
	var b := _water_attrs(malha2, _water_surface_index(malha2, mat), topo2)
	_check("coluna_de_agua_ondula_so_no_topo",
		b["verts"] == 40 and b["tri"] == 20 and b["masc"] == 12 and b["fora"] == 0
			and b["gmax"] > 0.15 and b["gmax"] < 0.35,
		"verts=%d  tri=%d  mascarados=%d  fora_do_plano=%d  g_max=%.3f (1 bloco embaixo = 0,25)"
			% [b["verts"], b["tri"], b["masc"], b["fora"], b["gmax"]])
	_scratch_root.queue_free()
	_scratch = null


## O surface que carrega a instancia exata do material da agua; -1 quando o chunk nao
## tem agua malhada. O indice nunca e fixo: os tres grupos sao acrescentados
## condicionalmente, e e o proprio indice 2 hardcoded que a checagem de material da
## malharia ja guarda.
func _water_surface_index(mesh: Mesh, mat: Material) -> int:
	if mesh == null:
		return -1
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i) == mat:
			return i
	return -1


## Census do que a malharia escreveu nos tres canais do `COLOR` de um surface de agua.
## `topo` e o plano de topo esperado: todo vertice mascarado tem de estar exatamente
## nele, porque e o mesmo XZ que o quad de topo divide com as laterais (§3.2). O G e
## lido com tolerancia: o canal e um byte por componente, entao 1/4 chega como
## 64/255 = 0,25098.
func _water_attrs(mesh: Mesh, wi: int, topo: float) -> Dictionary:
	var out := {"verts": 0, "tri": 0, "masc": 0, "fora": 0, "wall": 0, "gmax": 0.0}
	if mesh == null or wi < 0:
		return out
	var arr := mesh.surface_get_arrays(wi)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	out["verts"] = verts.size()
	out["tri"] = int(arr[Mesh.ARRAY_INDEX].size()) / 3
	for k in verts.size():
		if cols[k].r > 0.5:
			out["masc"] = int(out["masc"]) + 1
			if absf(verts[k].y - topo) > 0.001:
				out["fora"] = int(out["fora"]) + 1
		if cols[k].b > 0.5:
			out["wall"] = int(out["wall"]) + 1
		out["gmax"] = maxf(float(out["gmax"]), cols[k].g)
	return out


# ------------------------------------------------------- fx da agua (dossie 23 §5.1)

## A janela seca abre a perna do FX e faz isso por dois motivos, e o segundo e o que
## manda: o corpo andando em terra tem de sair dela sem um salpico do jogador
## (`corpo_seco_nao_dispara`), e a deriva do Eter nos mesmos 70 quadros e o chao contra
## o qual `fx_nao_escreve_o_mundo` compara a janela do salpico. Sem essa referencia, um
## verde de nao-escrita seria lido a partir de nenhum instrumento.
func _check_fx_dry_setup() -> void:
	var p: Player = main.player
	var world: VoxelWorld = main.world
	_fx_home = p.body.feet_pos
	var sx := int(floorf(_spawn.x))
	var sz := int(floorf(_spawn.z))
	# Anda para onde o jogo anda: o `yaw` e o que `_wish_direction` (player.gd:429)
	# traduz no `move_forward`, entao a direcao sai escolhida do terreno e nenhum pe e
	# empurrado por fora de um passo do jogador. Sem a busca, uma semente com lago no
	# caminho do spawn faria a janela molhar o corpo e a indiferenca viraria vermelho
	# por geografia.
	var escolhido := -1
	for k in 4:
		var yaw := float(k) * PI / 2.0
		if _fx_caminho_seco(sx, sz, Vector3(-sin(yaw), 0.0, -cos(yaw)), 8):
			p.yaw = yaw
			escolhido = k
			break
	p.body.feet_pos = Vector3(float(sx) + 0.5, float(world.surface_height(sx, sz)) + 1.4,
		float(sz) + 0.5)
	p.body.velocity = Vector3.ZERO
	var d: Dictionary = main.water_fx.diagnostics()
	_fx_seco0 = int(d["salpicos_jogador"])
	_fx_seco_e0 = main.aether.total_energy()
	_fx_seco_p0 = p.body.feet_pos
	_fx_seco_molhado = false
	_fx_track = true
	_tick_player = true
	Input.action_press("move_forward")
	print("  seco: coluna=(%d,%d) yaw=%d  colunas_a_frente=8 secas=%s" % [
		sx, sz, escolhido, escolhido >= 0])


func _check_fx_dry_assert() -> void:
	Input.action_release("move_forward")
	_fx_track = false
	_tick_player = false
	var p: Player = main.player
	_fx_seco_e1 = main.aether.total_energy()
	var d: Dictionary = main.water_fx.diagnostics()
	var andou := Vector3(p.body.feet_pos.x - _fx_seco_p0.x, 0.0,
		p.body.feet_pos.z - _fx_seco_p0.z).length()
	# Os tres lados juntos: nenhum salpico do jogador, o corpo nunca esteve na agua em
	# quadro nenhum da janela (o laço de `_physics_process` testemunha isso), e ele
	# realmente andou — sem a ultima frase a indiferenca poderia ser um corpo parado.
	_check("corpo_seco_nao_dispara",
		int(d["salpicos_jogador"]) == _fx_seco0 and not _fx_seco_molhado and andou > 0.4,
		"salpicos_jogador=%d->%d  molhado_na_janela=%s  andado=%.2f m" % [
			_fx_seco0, int(d["salpicos_jogador"]), _fx_seco_molhado, andou])


## A coluna mais funda do mapa, lida em vez de fixa, e o corpo pousado 3,4 m acima do
## plano com velocidade zerada: quem derruba o corpo e a gravidade de 24 m/s² do próprio
## `VoxelBody`, nao um `velocity.y` escrito pelo teste — o §5.1 exige que O JOGO faça a
## queda, porque o campo escrito na mao e exatamente o que o contrato desta casa veta.
func _check_fx_drop() -> void:
	var p: Player = main.player
	var world: VoxelWorld = main.world
	var best := Vector2i(-1, -1)
	var best_n := 0
	var best_y := -1.0
	for x in range(4, VoxelConfig.world_size_x() - 4, 2):
		for z in range(4, VoxelConfig.world_size_z() - 4, 2):
			var n := _fx_coluna_agua(x, z)
			if n > best_n:
				best_n = n
				best = Vector2i(x, z)
				best_y = world.water_surface_y(x, z)
	_fx_col = best
	_fx_plane = best_y
	_check("coluna_de_queda_funda", best_n > WaterFx.BUBBLE_MIN_BLOCKS and best_y > 0.0,
		"coluna=(%d,%d)  blocos=%d  plano=%.3f" % [best.x, best.y, best_n, best_y])
	if best_n <= WaterFx.BUBBLE_MIN_BLOCKS or best_y <= 0.0:
		return
	var d0: Dictionary = main.water_fx.diagnostics()
	_fx_salpicos0 = int(d0["salpicos_disparados"])
	_fx_e0 = main.aether.total_energy()
	_fx_edits0 = world.edits.size()
	_fx_sig = _fx_assinatura_coluna(best.x, best.y)
	p.body.feet_pos = Vector3(float(best.x) + 0.5, best_y + 3.4, float(best.y) + 0.5)
	p.body.velocity = Vector3.ZERO
	_fx_seco_molhado = false
	_fx_track = true
	_tick_player = true


func _check_fx_splash() -> void:
	_fx_track = false
	_tick_player = false
	var p: Player = main.player
	var world: VoxelWorld = main.world
	var fx: WaterFx = main.water_fx
	var d: Dictionary = fx.diagnostics()
	_fx_e1 = main.aether.total_energy()
	if _fx_plane <= 0.0:
		_check("orcamento_de_particulas", false, "sem coluna de queda: a janela nao rodou")
		return

	# O teto e conferido contra a arvore de nodes, nao contra a minha memoria: os
	# emissores que existem sao os do pool, e a soma dos `amount` deles e o numero que a
	# checagem compara. Um emissor criado fora do boot aparece aqui como contagem
	# diferente — que e o modo honesto de pagar o §3.6.
	var emissores := 0
	var anis := 0
	var soma := 0
	for c in fx.get_children():
		if c is GPUParticles3D:
			emissores += 1
			soma += (c as GPUParticles3D).amount
		elif c is MeshInstance3D:
			anis += 1
			soma += 1
	var vivas := int(d["salpicos"]) * WaterFx.SPLASH_AMOUNT + int(d["anis"]) \
			+ int(d["bolhas"]) * WaterFx.BUBBLE_AMOUNT
	var teto := WaterFx.teto_particulas()
	_check("orcamento_de_particulas",
		emissores == WaterFx.SPLASH_POOL + WaterFx.BUBBLE_POOL and anis == WaterFx.RING_POOL
			and soma == teto and vivas <= teto,
		"emissores=%d  anis=%d  soma=%d  teto=%d  vivas=%d  picos=%d" % [
			emissores, anis, soma, teto, vivas, int(d["picos"])])

	var plano := world.water_surface_y(_fx_col.x, _fx_col.y)
	var jcol: Vector2i = d["jogador_col"]
	_check("queda_na_agua_dispara_salpico",
		int(d["salpicos_disparados"]) > _fx_salpicos0
			and int(d["salpicos_jogador"]) > _fx_seco0
			and float(d["jogador_vy"]) < WaterFx.SPLASH_MIN_VY
			and jcol == _fx_col
			and absf(float(d["jogador_plano"]) - plano) < 0.001,
		"disparados=%d->%d  jogador=%d->%d  vy=%.2f  col=%s  plano_fx=%.3f plano_mundo=%.3f  blocos=%d" % [
			_fx_salpicos0, int(d["salpicos_disparados"]), _fx_seco0, int(d["salpicos_jogador"]),
			float(d["jogador_vy"]), jcol, float(d["jogador_plano"]), plano,
			int(d["jogador_blocos"])])

	# Nao-escrita com as tres testemunhas do §5.1. A assinatura e por COLUNA porque o
	# lobo cava (perna 12) e a grama cresce (18): o tamanho global de `edits` muda por
	# causa legitima, e uma checagem nele daria vermelho pelo motivo errado — por isso
	# `edits=%d->%d` sai impresso sem ser assercao. A banda do Eter e 4x a deriva da
	# janela seca, medida na mesma arvore, e o numero das duas aparece na linha.
	var seca := absf(_fx_seco_e1 - _fx_seco_e0)
	var molhada := absf(_fx_e1 - _fx_e0)
	var sem_eter := true
	for prop in fx.get_property_list():
		if String(prop["class_name"]) == "AetherField":
			sem_eter = false
	_check("fx_nao_escreve_o_mundo",
		_fx_sig == _fx_assinatura_coluna(_fx_col.x, _fx_col.y) and molhada <= 4.0 * seca
			and AetherField.Channel.COUNT == 3 and sem_eter,
		"assinatura_ok=%s  edits_globais=%d->%d  eter_seco=%.6f  eter_salpico=%.6f  canais=%d  fx_sem_eter=%s" % [
			_fx_sig == _fx_assinatura_coluna(_fx_col.x, _fx_col.y), _fx_edits0, world.edits.size(),
			seca, molhada, AetherField.Channel.COUNT, sem_eter])

	# Custo colhido, nao asserido (mandato 5): o FX roda por frame de fisica, e esta e a
	# primeira vez que a casa tem um numero dele. Sem piso medido, qualquer teto escrito
	# aqui seria um chute com cara de gate — o numero vai para o status, e a checagem de
	# orcamento que morde e a de particulas.
	print("  custo do FX: quadros=%d  us_total=%d  media=%.2f us/quadro  pico=%d us" % [
		int(d["quadros"]), int(d["us_total"]), float(d["us_por_quadro"]), int(d["us_pico"])])

	# Devolve o corpo ao lugar de antes: os passos seguintes (lavra, golpe, respiracao)
	# miram a partir do spawn, e um jogador dentro de um lago mudaria o motivo de cada
	# verde deles.
	p.body.feet_pos = _fx_home
	p.body.velocity = Vector3.ZERO


## Terra seca pelos proximos `n` passos de uma direcao: coluna sem agua nenhuma, e nao
## apenas o `in_water` falso no comeco da janela.
func _fx_caminho_seco(x: int, z: int, d: Vector3, n: int) -> bool:
	for k in range(1, n + 1):
		var cx := x + int(roundf(d.x * float(k)))
		var cz := z + int(roundf(d.z * float(k)))
		if not VoxelConfig.in_world_bounds(Vector3i(cx, 1, cz)):
			return false
		if main.world.water_surface_y(cx, cz) >= 0.0:
			return false
	return true


## Quantos voxels de agua ha na coluna, do topo da agua para baixo, sem saturar: a
## premissa quer a profundidade real para escolher a mais funda, e o FX tem a sua
## contagem saturada em 6 dentro dele (`_blocos_na_coluna`).
func _fx_coluna_agua(x: int, z: int) -> int:
	var y := VoxelConfig.CHUNK_SIZE_Y - 1
	while y >= 0:
		if main.world.is_water_xyz(x, y, z):
			break
		y -= 1
	if y < 0:
		return 0
	var n := 0
	while y - n >= 0 and main.world.is_water_xyz(x, y - n, z):
		n += 1
	return n


## Assinatura das edicoes registradas numa coluna. `world.edits` e o disco do estado
## autoritativo, e e ele que a checagem de nao-escrita compara antes/depois da janela.
func _fx_assinatura_coluna(x: int, z: int) -> String:
	var partes := PackedStringArray()
	for y in VoxelConfig.CHUNK_SIZE_Y:
		var k := Vector3i(x, y, z)
		if main.world.edits.has(k):
			partes.append("%d=%d" % [y, int(main.world.edits[k])])
	return "%d,%d:%s" % [x, z, "|".join(partes)]


# ------------------------------------------- chuva e molhado (dossie 23 §5.3)

## As portas de leitura do gate da Fase 2. Nada aqui escreve `Weather`, `OpaqueSurface`
## ou `RainFx` como nome de classe, nem `VoxelWorld.EXPOSURE_FALL` como constante: uma
## referencia direta a um tipo que ainda nao existe e **erro de compilacao do script
## inteiro**, e o modo de falha que a casa ja contou — um SCRIPT ERROR dentro de um passo
## derruba checagens em silencio e a suíte passa a contar menos com o mesmo "0 falhas"
## (mandato 1). Entao o gate nasce vermelho **lendo por nome**: `ResourceLoader.exists`,
## `has_method()`, `Object.get()` e o mapa de constantes do GDScript, cada ausencia
## devolvendo um numero nomeado (-1, -99) em vez de uma excecao. Quando o codigo pousar,
## as mesmas portas devolvem o valor real e nenhuma assercao foi escrita de proposito
## "contra o null".
func _ch_script(caminho: String) -> GDScript:
	if not ResourceLoader.exists(caminho):
		return null
	var scr := load(caminho)
	return scr if scr is GDScript else null


func _ch_call(o: Object, nome: String) -> Variant:
	if o == null or not o.has_method(nome):
		return null
	return o.call(nome)


func _ch_call1(o: Object, nome: String, arg: Variant) -> Variant:
	if o == null or not o.has_method(nome):
		return null
	return o.call(nome, arg)


func _ch_dict(o: Object, nome: String) -> Dictionary:
	var v: Variant = _ch_call(o, nome)
	if v is Dictionary:
		return v
	return {}


## O numero de uma constante numerica do script, lido do mapa e nao re-digitado no teste
## — a mesma recusa de repetir um numero contra ele mesmo que a testemunha de uniformes
## da agua faz com o `SOURCE`. As chaves chegam como `StringName`, entao a comparacao e
## por `String`; constante ausente (ou que nao e numero) devolve -1, e nenhum -1 passa em
## assercao nenhuma.
func _ch_const(scr: GDScript, nome: String) -> float:
	if scr == null:
		return -1.0
	var cm: Dictionary = scr.get_script_constant_map()
	for k in cm:
		if String(k) == nome:
			var v = cm[k]
			if v is int or v is float:
				return float(v)
			return -1.0
	return -1.0


func _ch_static(scr: GDScript, nome: String) -> Variant:
	if scr == null:
		return null
	var c := Callable(scr, nome)
	return c.call() if c.is_valid() else null


## O material opaco pela porta que a Fase 2 abre em `VoxelWorld` (§3.10c). Sem a porta,
## `null` — e e esse `null` que faz as duas primeiras linhas do gate nascerem vermelhas
## com o nome da ausencia impresso, nao um indice chutado.
func _ch_opaque_of(w: VoxelWorld) -> Material:
	return _ch_call(w, "opaque_material") as Material


## O surface que carrega a instancia exata do material; -1 sem material. Copia o
## instrumento da agua (`_water_surface_index`) porque o motivo e o mesmo: os grupos sao
## acrescentados condicionalmente e indice fixo ja deixou o pano sem material nenhum.
func _ch_surface_index(mesh: Mesh, mat: Material) -> int:
	if mesh == null or mat == null:
		return -1
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i) == mat:
			return i
	return -1


func _ch_weather() -> Node:
	return main.get_node_or_null("Weather")


## Varredura de `get_property_list()` pelo tipo que o renderizador nao pode segurar
## (§3.8): o mesmo instrumento do `fx_sem_eter` da Fase 1. Node nulo devolve **falso** —
## ausencia nao e indiferenca, e quem nao existe tambem nao escreve no mundo por acidente
## nenhum.
func _ch_sem_eter(o: Object) -> bool:
	if o == null:
		return false
	for prop in o.get_property_list():
		if String(prop["class_name"]) == "AetherField":
			return false
	return true


func _ch_contar_gdshader() -> int:
	return _ch_walk_shader("res://src") + _ch_walk_shader("res://tests")


## O escopo e nomeado de proposito: a cláusula do §3.1 é "mais de um `.gdshader` no
## projeto", e o que a suíte varre são as duas pastas de código rastreadas — `.tools` é
## gitignored e não é material do jogo.
func _ch_walk_shader(dir_path: String) -> int:
	var d := DirAccess.open(dir_path)
	if d == null:
		return 0
	var n := 0
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not f.begins_with("."):
			var p := dir_path + "/" + f
			if d.current_is_dir():
				n += _ch_walk_shader(p)
			elif f.ends_with(".gdshader"):
				n += 1
		f = d.get_next()
	d.list_dir_end()
	return n


## Seis pedras empilhadas **no ar**, dentro de um chunk de terreno real: o topo da coluna
## passa a ser a pilha (o `surface_height` do §3.10b é exatamente essa leitura), o ar em
## volta faz cada face existir de verdade, e os y dos vértices caem nos três pontos que a
## fórmula nomeia — `topo+1`, `topo-1`, `topo-4`. Longe das bordas do chunk (folga de 4)
## para que o culling não coma as laterais. `record = false`: o teste não escreve no
## mundo, e o mesh se reconstrói aqui, uma vez, sem esperar o orçamento de 2 chunks/frame.
func _ch_palco(w: VoxelWorld) -> Vector3i:
	for x in range(8, VoxelConfig.world_size_x() - 8, 3):
		if x % VoxelConfig.CHUNK_SIZE_X < 4 or x % VoxelConfig.CHUNK_SIZE_X > 11:
			continue
		for z in range(8, VoxelConfig.world_size_z() - 8, 3):
			if z % VoxelConfig.CHUNK_SIZE_Z < 4 or z % VoxelConfig.CHUNK_SIZE_Z > 11:
				continue
			var base := w.surface_height(x, z)
			if base + CH_STACK + 3 > VoxelConfig.CHUNK_SIZE_Y - 1:
				continue
			var y0 := base + 6
			for i in CH_STACK:
				w.set_block(Vector3i(x, y0 + i, z), BlockDefs.Block.STONE, false)
			var cell := Vector3i(x, y0, z)
			w.build_chunk_mesh(w.chunk_at(cell))
			return cell
	return Vector3i(-1, -1, -1)


## Census do grupo opaco de um surface. `so_pilha` limita aos vértices da coluna da
## pilha (o XZ e o y da caixa), porque é ali que o y do vértice determina a exposição sem
## a vizinhança; o resto do chunk entra na contagem de R=G=B e no min/max do A, que é o
## canal lido por ninguém antes desta perna.
func _ch_opaque_attrs(mesh: Mesh, oi: int, pilha: Vector3i, por_pilha: bool) -> Dictionary:
	var out := {"verts": 0, "rgb": 0, "a_min": 2.0, "a_max": -1.0, "dispersos": 0, "por_y": {}}
	if mesh == null or oi < 0:
		return out
	var arr := mesh.surface_get_arrays(oi)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	for k in verts.size():
		var v: Vector3 = verts[k]
		var c: Color = cols[k]
		var na_pilha := v.x >= float(pilha.x) - 0.001 and v.x <= float(pilha.x) + 1.001 \
				and v.z >= float(pilha.z) - 0.001 and v.z <= float(pilha.z) + 1.001 \
				and v.y >= float(pilha.y) - 0.001 and v.y <= float(pilha.y) + float(CH_STACK) + 0.001
		if por_pilha and not na_pilha:
			continue
		out["verts"] = int(out["verts"]) + 1
		if absf(c.r - c.g) < 0.0001 and absf(c.g - c.b) < 0.0001:
			out["rgb"] = int(out["rgb"]) + 1
		out["a_min"] = minf(float(out["a_min"]), c.a)
		out["a_max"] = maxf(float(out["a_max"]), c.a)
		if na_pilha:
			var y := int(roundf(v.y))
			var por: Dictionary = out["por_y"]
			if por.has(y):
				if absf(float(por[y]) - c.a) > 0.0001:
					out["dispersos"] = int(out["dispersos"]) + 1
			else:
				por[y] = c.a
	return out


## `expos = clampf(1 - (topo - y)/EXPOSURE_FALL, 0, 1)` do §3.10b, com o `FALL` lido da
## constante do mundo. `topo` é o `y` do voxel mais alto da coluna — a definição que o
## próprio `surface_height` usa, e é por isso que o vértice do topo fica em `topo+1`.
func _ch_esperada(topo: float, y: float, fall: float) -> float:
	if fall <= 0.0:
		return -1.0
	return clampf(1.0 - (topo - y) / fall, 0.0, 1.0)


func _check_opaque_surface() -> void:
	_ch_scratch_root = Node3D.new()
	add_child(_ch_scratch_root)
	_ch_scratch = VoxelWorld.new()
	_ch_scratch.setup_world(_ch_scratch_root)
	_ch_scratch.generate(SEED)
	_ch_pilha = _ch_palco(_ch_scratch)
	var mat := _ch_opaque_of(_ch_scratch)
	_ch_mesh = null
	if _ch_pilha.x >= 0:
		var chunk: VoxelChunk = _ch_scratch.chunk_at(_ch_pilha)
		if chunk != null and chunk.mesh_instance != null:
			_ch_mesh = chunk.mesh_instance.mesh
	var oi := _ch_surface_index(_ch_mesh, mat)
	_ch_op = _ch_opaque_attrs(_ch_mesh, oi, _ch_pilha, false)
	_ch_fall = _ch_const(_ch_script("res://src/world/voxel_world.gd"), "EXPOSURE_FALL")

	# O par de testemunhas que a agua ja usa: a lista que o GDScript grava e a que a
	# SOURCE declara. Nome gravado sem declaracao correspondente e um no-op silencioso,
	# e headless nao compila shader nenhum para avisar. `gdshader_em_src_tests` e o
	# numero que fecha a discussao do §3.1 — 0 antes, 0 depois.
	var scr := _ch_script("res://src/world/opaque_surface.gd")
	var declarados := PackedStringArray()
	var gravados := PackedStringArray()
	var vd: Variant = _ch_static(scr, "declared_uniforms")
	var vg: Variant = _ch_static(scr, "written_uniforms")
	if vd is PackedStringArray:
		declarados = vd
	if vg is PackedStringArray:
		gravados = vg
	var sem_fonte := 0
	for k: String in gravados:
		if not declarados.has(k):
			sem_fonte += 1
	_check("material_opaco_e_shader",
		mat != null and mat is ShaderMaterial and (mat as ShaderMaterial).shader != null
				and oi >= 0 and sem_fonte == 0 and declarados.size() > 0 and gravados.size() > 0,
		"shader=%s  surface=%d  declarados=%d  gravados=%d  sem_fonte=%d  gdshader_em_src_tests=%d  pilha=%s" % [
			mat != null and mat is ShaderMaterial, oi, declarados.size(), gravados.size(),
			sem_fonte, _ch_contar_gdshader(), _ch_pilha])

	# R=G=B e a aritmetica do `bright` intacta (§3.10b, a clausula que autoriza o A como
	# portador); o A e o canal que passou a variar. Na base a malharia escrevia `1.0` em
	# todos os vertices opacos (eb218fe:src/world/voxel_world.gd:689) e `a_min` sai 1,000
	# — o vermelho com nome, nao um crash. Hoje o `a` da exposicao entra pela mesma
	# escrita (src/world/voxel_world.gd:773).
	_check("opaco_preserva_rgb_da_face",
		oi >= 0 and int(_ch_op["verts"]) > 0 and int(_ch_op["rgb"]) == int(_ch_op["verts"])
				and float(_ch_op["a_min"]) < 0.01 and float(_ch_op["a_max"]) > 0.99,
		"verts=%d  rgb_iguais=%d  a_min=%.3f  a_max=%.3f  surface=%d" % [
			int(_ch_op["verts"]), int(_ch_op["rgb"]), float(_ch_op["a_min"]),
			float(_ch_op["a_max"]), oi])


func _check_weather_exposure() -> void:
	var pilha_p := _ch_opaque_attrs(_ch_mesh, _ch_surface_index(_ch_mesh, _ch_opaque_of(_ch_scratch)),
			_ch_pilha, true)
	var por: Dictionary = pilha_p["por_y"]
	var topo := float(_ch_pilha.y + CH_STACK - 1)
	var y_topo := int(_ch_pilha.y + CH_STACK)
	var y_abaixo := int(_ch_pilha.y + CH_STACK - 2)
	var y_fundo := int(_ch_pilha.y + 1)
	var a_topo := float(por.get(y_topo, -1.0))
	var a_abaixo := float(por.get(y_abaixo, -1.0))
	var a_fundo := float(por.get(y_fundo, -1.0))
	var e_topo := _ch_esperada(topo, float(y_topo), _ch_fall)
	var e_abaixo := _ch_esperada(topo, float(y_abaixo), _ch_fall)
	var e_fundo := _ch_esperada(topo, float(y_fundo), _ch_fall)
	# Tolerancia de 1/255 = 0,0039: o `COLOR` e um byte por canal, e os tres numeros da
	# §5.3 (1,000 / 0,750 / 0,000) sao o `FALL` de 4 blocos chegado por esse canal.
	_check("exposicao_de_ceu_por_coluna",
			_ch_fall > 0.0 and e_topo > 0.99 and int(pilha_p["verts"]) > 0
					and absf(a_topo - e_topo) < 0.004 and absf(a_abaixo - e_abaixo) < 0.004
					and absf(a_fundo - e_fundo) < 0.004 and int(pilha_p["dispersos"]) == 0,
			"EXPOSURE_FALL=%.1f  topo=%.3f/%.3f  abaixo=%.3f/%.3f  fundo=%.3f/%.3f  y_na_pilha=%d  dispersos=%d" % [
			_ch_fall, a_topo, e_topo, a_abaixo, e_abaixo, a_fundo, e_fundo,
			int(pilha_p["verts"]), int(pilha_p["dispersos"])])
	_ch_scratch_root.queue_free()
	_ch_scratch = null
	_ch_scratch_root = null
	_ch_mesh = null

	# O braço rejeitado do §3.10b (varredura por face ou por voxel) é o que esta linha
	# impede de voltar: o contador tem de fechar com **uma leitura por coluna por
	# rebuild**, e `256 = CHUNK_SIZE_X * CHUNK_SIZE_Z` sai do config, nao da memoria.
	# `chunks_lidos >= 64` porque o boot malha os 64 e a sessao real ainda pode rebuildar
	# (lobo cava — perna 12); o que morde e a proporcao, nao o numero absoluto.
	var ed := _ch_dict(main.world, "exposure_diagnostics")
	var cols_por_chunk := VoxelConfig.CHUNK_SIZE_X * VoxelConfig.CHUNK_SIZE_Z
	var chunks_lidos := int(ed.get("chunks_lidos", -1))
	var col_lidas := int(ed.get("col_lidas", -1))
	var faces_opacas := int(ed.get("faces_opacas", -1))
	var faces_por_coluna := float(faces_opacas) / float(col_lidas) if col_lidas > 0 else -1.0
	# `esperado` e impresso como texto quando nao ha leitura: `chunks_lidos * 256` com o
	# -1 da ausencia daria -256, um numero que parece medida e nao e.
	var esperado := "sem leitura" if chunks_lidos < 0 else str(chunks_lidos * cols_por_chunk)
	_check("exposicao_nao_e_varredura_por_face",
			chunks_lidos >= 64 and col_lidas == chunks_lidos * cols_por_chunk,
			"chunks_lidos=%d  col_lidas=%d  esperado=%s  cols_por_chunk=%d  faces_opacas=%d  faces_por_coluna=%.2f" % [
			chunks_lidos, col_lidas, esperado, cols_por_chunk,
			faces_opacas, faces_por_coluna])


func _check_weather_owner() -> void:
	var no := _ch_weather()
	var tem_chuva := no != null and no.get("chuva") is float
	var tem_molhado := no != null and no.get("molhado") is float
	var mundos := 0
	var eteres := 0
	var jogadores := 0
	if no != null:
		for prop in no.get_property_list():
			var t := String(prop["class_name"])
			if t == "VoxelWorld":
				mundos += 1
			elif t == "AetherField":
				eteres += 1
			elif t == "Player":
				jogadores += 1
	_check("clima_e_dono_visual",
			no != null and tem_chuva and tem_molhado and mundos == 0 and eteres == 0
					and jogadores == 0,
			"no=%s  chuva=float=%s  molhado=float=%s  world_refs=%d  eter_refs=%d  player_refs=%d" % [
			no != null, tem_chuva, tem_molhado, mundos, eteres, jogadores])


func _check_weather_ramp_arm() -> void:
	var no := _ch_weather()
	_ch_up_frame = _frame
	_ch_call1(no, "pedir_chuva", 1.0)
	print("  rampa: no=%s  pedir_chuva(1.0) chamado=%s  molhado_0=%.3f  chuva=%.3f" % [
		no != null, no != null and no.has_method("pedir_chuva"),
		float(no.get("molhado")) if no != null else -1.0,
		float(no.get("chuva")) if no != null else -1.0])


func _check_weather_ramp_down() -> void:
	var no := _ch_weather()
	_ch_ramp_up = float(no.get("molhado")) if no != null else -1.0
	_ch_down_frame = _frame
	_ch_call1(no, "pedir_chuva", 0.0)
	print("  rampa: topo_atingido=%.3f em %d frames  pedir_chuva(0.0) chamado=%s" % [
		_ch_ramp_up, _frame - _ch_up_frame, no != null and no.has_method("pedir_chuva")])


func _check_weather_ramp_assert() -> void:
	var no := _ch_weather()
	var down := float(no.get("molhado")) if no != null else -1.0
	var frames_down := _frame - _ch_down_frame
	var t := float(frames_down) / float(Engine.get_physics_ticks_per_second())
	var scr := _ch_script("res://src/rendering/weather.gd")
	var rise := _ch_const(scr, "WEATHER_RISE")
	var decay := _ch_const(scr, "WEATHER_DECAY")
	var esperado := 1.0 - decay * t if decay > 0.0 else -1.0
	# O sink do §3.10a: sem ler o `molhado` do **material**, o no poderia existir,
	# integrar a rampa e nao chegar a lugar nenhum — e o verde seria sobre um caminho
	# desligado. `get_shader_parameter` devolve o que o material esta usando agora.
	var mat := _ch_opaque_of(main.world)
	var uniform := -99.0
	if mat != null and mat is ShaderMaterial:
		var v = (mat as ShaderMaterial).get_shader_parameter("molhado")
		if v is float or v is int:
			uniform = float(v)
	_check("molhado_sobe_e_desce",
			no != null and rise > 0.0 and decay > 0.0 and decay < rise
					and _ch_ramp_up >= 0.99 and down < _ch_ramp_up
					and absf(down - esperado) <= 0.02 and absf(uniform - down) <= 0.001,
			"molhado 0.000->%.3f em %d frames  desceu=%.3f em %d frames  esperado=%.3f  material=%.3f  rise=%.3f  decay=%.3f  secs=%.3f" % [
			_ch_ramp_up, maxi(_ch_down_frame - _ch_up_frame, 0), down,
			frames_down, esperado, uniform, rise, decay, t])


func _check_weather_rng() -> void:
	# O molde da perna 12 (`aether_reactions_test.gd`), pino de `simulation_rng_test.gd:75-77`
	# entre o armamento e a leitura: seed -> `randi()` de depois -> mesma seed -> os sorteios
	# -> `randi()` tem de devolver o pino. Envolvido numa chamada **autonomica** fora da
	# arvore, nao numa janela da sessao: a simulação ao vivo nao e deterministica (mandato 3)
	# e pino algum pode prometer o que ela sorteia.
	seed(CH_RNG_PIN)
	var pino := randi()
	seed(CH_RNG_PIN)
	var scr := _ch_script("res://src/rendering/weather.gd")
	var col_a: Array = []
	var col_b: Array = []
	var w1: Object = scr.new() if scr != null else null
	var w2: Object = scr.new() if scr != null else null
	for i in 8:
		var v1: Variant = _ch_call(w1, "sortear_coluna")
		var v2: Variant = _ch_call(w2, "sortear_coluna")
		if v1 is Vector2i and v2 is Vector2i:
			col_a.append(v1)
			col_b.append(v2)
	var depois := randi()
	if w1 != null:
		(w1 as Node).free()
	if w2 != null:
		(w2 as Node).free()
	# Identidade: a chuva sorteia na RNG **dela**. Se o `rng()` do clima for o mesmo objeto
	# que `_population_rng` do `main`, o clima esta comendo a sequencia do censo e o
	# determinismo de `intent`/spawn passa a depender de quantos frames choveu.
	var no := _ch_weather()
	var rng_clima: Object = _ch_call(no, "rng")
	var rng_pop: Object = main.get("_population_rng")
	_check("chuva_nao_consome_rng_da_sessao",
			depois == pino and col_a.size() == 8 and col_a == col_b and rng_clima != null
					and rng_clima != rng_pop,
			"pino_antes=%d  pino_depois=%d  global_preservado=%s  colunas_iguais=%s  n=%d  script=%s  rng_do_clima=%s  rng_da_populacao=%s" % [
			pino, depois, depois == pino, col_a == col_b, col_a.size(), scr != null,
			rng_clima != null, rng_pop != null])


func _check_rain_window_arm() -> void:
	var no := _ch_weather()
	_ch_call1(no, "pedir_chuva", 1.0)
	# A coluna mais funda ja foi escolhida pelo passo da queda (§5.1) e e ela que a
	# assinatura de nao-escrita vigia; o resto do mundo fica impresso sem ser assercao,
	# porque lobo cava e grama cresce por causa legitima.
	_ch_col = _fx_col
	_ch_sig = _fx_assinatura_coluna(_fx_col.x, _fx_col.y)
	_ch_edits0 = main.world.edits.size()
	_ch_e0 = main.aether.total_energy()
	var d: Dictionary = main.water_fx.diagnostics()
	_ch_rings0 = int(d.get("anis_chuva", -1))
	_ch_refus0 = int(d.get("anis_recusados", -1))
	print("  janela molhada: chuva=1.0 no=%s  anis_chuva_0=%d  recusados_0=%d  edits=%d  sig=%d chars" % [
		no != null, _ch_rings0, _ch_refus0, _ch_edits0, _ch_sig.length()])


func _check_rain_window_assert() -> void:
	var d: Dictionary = main.water_fx.diagnostics()
	var anis := int(d.get("anis_chuva", -1))
	var recusos := int(d.get("anis_recusados", -1))
	var vivo_c := int(d.get("anis_vivos_chuva", -1))
	var vivo_k := int(d.get("anis_vivos_corpo", -1))
	var no_zero := int(d.get("anis_no_zero", -1))
	var col_ult := Vector2i(-9, -9)
	var plano_fx := -99.0
	if d.get("col_ultima") is Vector2i:
		col_ult = d["col_ultima"]
		plano_fx = float(d.get("plano_ultima", -99.0))
	var na_agua := col_ult.x != -9 and _fx_coluna_agua(col_ult.x, col_ult.y) > 0
	var plano_mundo := -99.0
	if col_ult.x != -9:
		plano_mundo = main.world.water_surface_y(col_ult.x, col_ult.y)
	# O anel e do pool que ja existe (§3.10d): o ultimo lugar que ele pousou tem de estar
	# no plano que o **mundo** devolve para aquela coluna, coluna sem agua recusa com
	# contador, e a cota de ~9 de 12 vagas viva e lida com os dois compradores na janela.
	_check("anel_de_chuva_so_na_agua",
			anis > _ch_rings0 and _ch_rings0 >= 0 and no_zero == 0 and vivo_c >= 0
					and vivo_k >= 0 and vivo_c + vivo_k <= WaterFx.RING_POOL and na_agua
					and absf(plano_fx - plano_mundo) < 0.001,
			"anis_chuva=%d->%d  recusados=%d->%d  col_ultima=%s  na_agua=%s  plano_fx=%.3f  plano_mundo=%.3f  vivo_chuva=%d  vivo_corpo=%d  pool=%d  no_zero=%d" % [
			_ch_rings0, anis, _ch_refus0, recusos, col_ult, na_agua, plano_fx, plano_mundo,
			vivo_c, vivo_k, WaterFx.RING_POOL, no_zero])

	# A porta do §3.10e, lida do mesmo jeito que `molhado_sobe_e_desce` le a do opaco: o
	# numero que a superficie da agua desenha tem de ser o numero que o clima pediu. Sem
	# esta linha o `chuva` poderia estar declarado na SOURCE, escrito em `params()` e nunca
	# atualizado por nadie — um uniforme congelado em zero da verde em todas as outras nove.
	# Os dois tamanhos vao impressos porque e aqui que o par 16/14 da Fase 1 vira 17/15: o
	# re-derivar tem de aparecer na corrida, nao so no documento.
	var wmat: Material = main.world.water_material()
	var water_chuva := -99.0
	if wmat != null and wmat is ShaderMaterial:
		var vc = (wmat as ShaderMaterial).get_shader_parameter("chuva")
		if vc is float or vc is int:
			water_chuva = float(vc)
	var alvo := float(_ch_weather().get("chuva")) if _ch_weather() != null else -99.0
	var wscr := _ch_script("res://src/world/water_surface.gd")
	var decl: Variant = _ch_static(wscr, "declared_uniforms")
	var writ: Variant = _ch_static(wscr, "written_uniforms")
	var nd := (decl as PackedStringArray).size() if decl is PackedStringArray else -1
	var nw := (writ as PackedStringArray).size() if writ is PackedStringArray else -1
	_check("agua_le_a_chuva",
			water_chuva > 0.0 and absf(water_chuva - alvo) <= 0.001 and nd == nw + 2,
			"chuva_no=%.3f  uniforme_agua=%.3f  declarados=%d  gravados=%d" % [
			alvo, water_chuva, nd, nw])

	# Orcamento com aritmetica, nao com adjetivo (§3.6, o teto que a Fase 1 escreveu	# prevendo este segundo comprador): `amount` x `lifetime` de cada emissor nao pode
	# passar do `amount` dele, e o soma dos `amount` da arvore e o teto declarado. Os
	# quatro numeros saem das constantes do `RainFx` — re-digit-los no teste seria a
	# assercao conferindo a si mesma.
	var rfx: Object = main.get("rain_fx")
	var scr := _ch_script("res://src/rendering/rain_fx.gd")
	var near_amount := _ch_const(scr, "NEAR_AMOUNT")
	var far_amount := _ch_const(scr, "FAR_AMOUNT")
	var near_rate := _ch_const(scr, "NEAR_RATE")
	var near_life := _ch_const(scr, "NEAR_LIFE")
	var far_rate := _ch_const(scr, "FAR_RATE")
	var far_life := _ch_const(scr, "FAR_LIFE")
	var tv: Variant = _ch_static(scr, "teto_particulas")
	var teto := int(tv) if tv is int else -1
	var emissores := 0
	var soma := 0
	var fiel_near := false
	var fiel_far := false
	if rfx != null:
		for c in rfx.get_children():
			if c is GPUParticles3D:
				emissores += 1
				var p := c as GPUParticles3D
				soma += p.amount
				if p.amount == int(near_amount):
					fiel_near = absf(p.lifetime - near_life) < 0.001
				elif p.amount == int(far_amount):
					fiel_far = absf(p.lifetime - far_life) < 0.001
	var near_viva := near_rate * near_life if near_rate > 0.0 and near_life > 0.0 else -1.0
	var far_viva := far_rate * far_life if far_rate > 0.0 and far_life > 0.0 else -1.0
	_check("orcamento_de_particulas_da_chuva",
			scr != null and rfx != null and emissores == 2 and soma == teto
					and near_amount > 0.0 and far_amount > 0.0
					and teto == int(near_amount + far_amount) and fiel_near and fiel_far
					and near_viva <= near_amount and far_viva <= far_amount,
			"emissores=%d  soma=%d  teto=%d  near=%.0f*%.1f=%.0f<=%.0f  far=%.0f*%.1f=%.0f<=%.0f  fiel_near=%s  fiel_far=%s" % [
			emissores, soma, teto, near_rate, near_life, near_viva, near_amount,
			far_rate, far_life, far_viva, far_amount, fiel_near, fiel_far])

	# A clausula do §5.1 estendida a janela inteira, com os tres nos sob a mesma
	# varredura. A banda do Eter **nao** e um ratio solto como o da Fase 1: medido nesta
	# arvore, a janela molhada de 90 quadros apanha lobo cavando (perna 12), e o cavar
	# escreve WORK no campo — entao `eter_chuva=0,37` com `eter_seco=0,00` nao e a chuva
	# escrevendo no Eter, e o lobo. O cavo tem testemunha propria: `world.edits` cresce
	# com ele, porque o `set_block` da perna 12 grava. Logo a banda so vale na janela em
	# que nada foi editado — fora dai ela nao tem dono, e o que morde passa a ser a
	# varredura estrutural: um no sem nenhuma referencia a `AetherField` nao tem por onde
	# escrever no campo. A renuncia e impressa com nome, nunca em silencio.
	_ch_e1 = main.aether.total_energy()
	var world: VoxelWorld = main.world
	var seca := absf(_fx_seco_e1 - _fx_seco_e0)
	var molhada := absf(_ch_e1 - _ch_e0)
	var edits_na_janela := world.edits.size() - _ch_edits0
	var banda_val := edits_na_janela == 0
	var fx_sem := _ch_sem_eter(main.water_fx)
	var rain_sem := _ch_sem_eter(rfx)
	var wth_sem := _ch_sem_eter(_ch_weather())
	var sig_ok := _ch_sig == _fx_assinatura_coluna(_ch_col.x, _ch_col.y)
	_check("chuva_nao_escreve_o_mundo",
			sig_ok and AetherField.Channel.COUNT == 3 and fx_sem and rain_sem and wth_sem
					and (not banda_val or molhada <= 4.0 * seca),
			"assinatura_ok=%s  edits_na_janela=%d  banda_val=%s  edits_globais=%d->%d  eter_seco=%.6f  eter_chuva=%.6f  canais=%d  fx_sem_eter=%s  rain_sem_eter=%s  weather_sem_eter=%s" % [
			sig_ok, edits_na_janela, banda_val, _ch_edits0, world.edits.size(), seca, molhada,
			AetherField.Channel.COUNT, fx_sem, rain_sem, wth_sem])


static func _sha_hex(s: String) -> String:
	return _sha_bytes_hex(s.to_utf8_buffer())


static func _sha_bytes_hex(b: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(b)
	return ctx.finish().hex_encode()


## Premissa do dossie 09.2: "derivar bioma nao pode alterar o terreno". Nao e checagem
## de aparencia — ela refaz as assinaturas do mundo recem-gerado e confere contra a
## medicao da revisao anterior ao `biome_of`. O numero que decide e `divergentes`: 0,
## ou o lote escreveu bloco sem querer e o hash por tick do journal passa a responder
## por um mundo diferente do que respondia.
##
## A grade de 32x32 e legivel (da o histograma), mas e amostra: medir com ela a
## unica assinatura deixou passar o limiar de umidade trocado de -0,30 para -0,50,
## que e exatamente o tipo de mudanca que esta checagem existe para pegar. Por isso a
## varredura dos 1 048 576 voxels acompanha — um segundo de corrida, e o preco de
## uma premissa que nao depende de sorte de amostragem.
func _check_biome_nao_altera_terreno(w: VoxelWorld) -> void:
	var rel := ""
	for x in [12, 44, 100, 116]:
		for z in [12, 44, 100, 116]:
			rel += "%d,%d:%d;" % [x, z, w.surface_height(x, z)]
	var top := ""
	var hist := {}
	for x in range(0, VoxelConfig.world_size_x(), 4):
		for z in range(0, VoxelConfig.world_size_z(), 4):
			var h: int = w.surface_height(x, z)
			var b: int = w.get_block_xyz(x, h, z)
			top += "%d,%d:%d,%d;" % [x, z, h, b]
			hist[b] = int(hist.get(b, 0)) + 1
	var keys: Array = hist.keys()
	keys.sort()
	var line := ""
	for k in keys:
		line += "%s=%d " % [k, hist[k]]
	line = line.strip_edges()
	var full := PackedByteArray()
	full.resize(VoxelChunk.SIZE_Y * VoxelConfig.world_size_z() * VoxelConfig.world_size_x())
	var i := 0
	for y in VoxelChunk.SIZE_Y:
		for z in VoxelConfig.world_size_z():
			for x in VoxelConfig.world_size_x():
				full[i] = w.get_block_xyz(x, y, z)
				i += 1
	var rel_sha := _sha_hex(rel)
	var top_sha := _sha_hex(top)
	var full_sha := _sha_bytes_hex(full)
	var divergentes := 0
	if rel_sha != BIOME_BASE_REL16_SHA:
		divergentes += 1
	if top_sha != BIOME_BASE_TOP_SHA:
		divergentes += 1
	if line != BIOME_BASE_TOP_HIST:
		divergentes += 1
	if full_sha != BIOME_BASE_FULL_SHA:
		divergentes += 1
	_check("bioma_nao_altera_terreno", divergentes == 0,
		"divergentes=%d/%d  voxels=%d  full=%s  rel16=%s  hist=%s" % [
			divergentes, 4, full.size(), full_sha.substr(0, 12), rel_sha.substr(0, 12), line])


## Corpo com o volume dentro de solido nao anda por eixo nenhum: o primeiro
## subpasso colide, a gravidade tambem, e a velocidade morre em zero -- congelado
## para sempre (foi o que travou 2 dos 5 lobos do spawn). Montado no ar, longe do
## terreno: tres voxels de pedra ao redor do pe, e o integrador tem de devolve-lo
## ao ar em vez de deixa-la la dentro.
func _check_embedded_body() -> void:
	var bx := 40
	var bz := 40
	var y: int = mini(main.world.surface_height(bx, bz) + 12, VoxelConfig.CHUNK_SIZE_Y - 5)
	var livre_antes := true
	for dz in range(-1, 2):
		if main.world.get_block(Vector3i(bx, y, bz + dz)) != BlockDefs.Block.AIR:
			livre_antes = false
	_check("regiao do corpo encaixado estava em ar", livre_antes, "voxel=(%d,%d,%d)" % [bx, y, bz])
	for dz in range(-1, 2):
		main.world.set_block(Vector3i(bx, y, bz + dz), BlockDefs.Block.STONE, false)
	var bd := VoxelBody.new()
	bd.setup(main.world, Vector3(float(bx) + 0.5, float(y), float(bz) + 0.5), Wolf.DIMS)
	var dentro: bool = main.world.aabb_hits_solid(bd.aabb())
	for _i in 4:
		bd.move_and_collide(0.05)
	var saiu: bool = not main.world.aabb_hits_solid(bd.aabb())
	var lift: float = bd.feet_pos.y - float(y)
	_check("corpo encaixado sobe para fora do solido", dentro and saiu,
		"encaixado=%s  agora em y=%.2f" % [dentro, bd.feet_pos.y])
	_check("o resgate e curto e nao teleporta o corpo", saiu and lift > 0.0 and lift <= 1.2,
		"subiu=%.2f m  teto=1,20" % lift)
	for dz in range(-1, 2):
		main.world.set_block(Vector3i(bx, y, bz + dz), BlockDefs.Block.AIR, false)
	main.world.process(64)


## Triangulos cuja normal geometrica (ordem dos indices) concorda com a normal do
# vertice: winding invertido, ou seja, a face e descartada como traseira.
func _winding_bad(w: VoxelWorld) -> int:
	var bad := 0
	for key in w.chunks:
		var c: VoxelChunk = w.chunks[key]
		if c.mesh_instance == null or c.mesh_instance.mesh == null:
			continue
		for s in c.mesh_instance.mesh.get_surface_count():
			var arr: Array = c.mesh_instance.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			for t in int(idx.size() / 3):
				var a := v[idx[t * 3]]
				var geo := (v[idx[t * 3 + 1]] - a).cross(v[idx[t * 3 + 2]] - a)
				if geo.length_squared() < 1e-8:
					continue
				if geo.normalized().dot(nr[idx[t * 3]]) > 0.0:
					bad += 1
	return bad


## Caixas do avatar: conta a arvore de nodes, sem depender de nomes internos.
func _mesh_count(n: Node) -> int:
	var total := 0
	if n is MeshInstance3D:
		total += 1
	for c in n.get_children():
		total += _mesh_count(c)
	return total


## Malhas efetivamente em cena: desconta as que estao sob um no oculto.
func _mesh_count_visible(n: Node) -> int:
	var total := 0
	if n is MeshInstance3D and n.is_visible_in_tree():
		total += 1
	for c in n.get_children():
		total += _mesh_count_visible(c)
	return total


## Extensao vertical global das malhas: [base, topo] da silhueta em coordenadas
## de mundo. Pega o torso montado no lugar errado, que a contagem de caixas nao
## distingue.
func _mesh_span(n: Node) -> Array:
	var lo := 999.0
	var hi := -999.0
	for b in n.find_children("*", "MeshInstance3D", true, false):
		var mi := b as MeshInstance3D
		var ab: AABB = mi.global_transform * mi.mesh.get_aabb()
		lo = minf(lo, ab.position.y)
		hi = maxf(hi, ab.position.y + ab.size.y)
	return [lo, hi]


## Pixels do quadro que o jogador ve, calculados da lente (fov vertical) e da
## resolucao do project.godot -- NAO do viewport do processo: em headless ele e
## 64x64, e medir o enquadramento nele daria um 1:1 que ninguem jogando ve.
func _screen_res() -> Vector2:
	return Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))


func _lens_px(cam: Camera3D, world: Vector3, res: Vector2) -> Vector2:
	var c := cam.global_transform.affine_inverse() * world
	var tan := tan(deg_to_rad(cam.fov) * 0.5)
	var ndc_y := (c.y / -c.z) / tan
	var ndc_x := (c.x / -c.z) / (tan * (res.x / res.y))
	return Vector2((ndc_x * 0.5 + 0.5) * res.x, (0.5 - ndc_y * 0.5) * res.y)


## Caixa projetada do cubo na mao, em pixels do quadro: [x0, y0, x1, y1]; vazia
## quando o punho esta closed ou algum canto caiu atras da lente. E o que prende
## o enquadramento do view model: os arcos ja jogaram o bloco pela borda de cima,
## e contagem de malhas nao percebe isso.
func _vm_frame(cam: Camera3D, held: MeshInstance3D) -> Array:
	if held == null or not held.visible:
		return []
	var g := held.global_transform
	var h := FPViewmodel.HELD_SIZE * 0.5
	var back := cam.global_transform.affine_inverse()
	var res := _screen_res()
	var lo := Vector2(99999.0, 99999.0)
	var hi := Vector2(-99999.0, -99999.0)
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				var w := g * Vector3(sx * h, sy * h, sz * h)
				if (back * w).z > 0.0:
					return []
				var pt := _lens_px(cam, w, res)
				lo.x = minf(lo.x, pt.x)
				lo.y = minf(lo.y, pt.y)
				hi.x = maxf(hi.x, pt.x)
				hi.y = maxf(hi.y, pt.y)
	return [lo.x, lo.y, hi.x, hi.y]


func _in_frame(fr: Array, res: Vector2) -> bool:
	return fr.size() == 4 and fr[0] >= 0.0 and fr[1] >= 0.0 \
		and fr[2] <= res.x and fr[3] <= res.y


func _fmt_frame(fr: Array) -> String:
	if fr.is_empty():
		return "punho closed"
	return "[%d..%d x %d..%d]" % [int(fr[0]), int(fr[2]), int(fr[1]), int(fr[3])]


## Malhas em cena que desenham sem teste de profundidade.
func _mesh_count_no_depth(n: Node) -> int:
	var total := 0
	if n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree():
		var mi := n as MeshInstance3D
		var m := mi.material_override as StandardMaterial3D
		if m == null:
			m = mi.mesh.material as StandardMaterial3D
		if m != null and m.no_depth_test:
			total += 1
	for c in n.get_children():
		total += _mesh_count_no_depth(c)
	return total


## Roda um arco do view model tick a tick e devolve [ombro minimo, ombro maximo,
## ticks com o cubo fora do quadro]. `punch` dispara o golpe; sem ele e a lavra,
## que precisa de alguns ticks para assentar o blend antes de medir o ciclo.
func _vm_arc(vm: FPViewmodel, cam: Camera3D, res: Vector2, ticks: int, punch: bool) -> Array:
	if punch:
		vm.swing()
	else:
		vm.mining = true
		for i in 18:
			vm.advance(1.0 / 60.0)
	var lo := 999.0
	var hi := -999.0
	var fora := 0
	for i in ticks:
		vm.advance(1.0 / 60.0)
		var a := vm.arm_angles().x
		lo = minf(lo, a)
		hi = maxf(hi, a)
		if not _in_frame(_vm_frame(cam, vm.held_mesh()), res):
			fora += 1
	return [lo, hi, fora]


func _chunk_triangles(c: VoxelChunk) -> int:
	var n := 0
	if c.mesh_instance == null or c.mesh_instance.mesh == null:
		return 0
	for s in c.mesh_instance.mesh.get_surface_count():
		var idx: PackedInt32Array = c.mesh_instance.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		n += int(idx.size() / 3)
	return n


# --------------------------------------------------------------------- edicoes

func _check_edits() -> void:
	var w: VoxelWorld = main.world
	var p := Vector3i(6, w.surface_height(6, 6) + 6, 6)
	_check("alvo dentro dos limites", VoxelConfig.in_world_bounds(p), "voxel=%s" % p)
	_check("fora dos limites recusado", not w.set_block(Vector3i(-4, 10, -4), BlockDefs.Block.STONE))
	_check("parede invisivel solida",
		w.get_block_xyz(-1, 10, 10) == BlockDefs.Block.STONE, "bloco=%d" % w.get_block_xyz(-1, 10, 10))
	_check("acima do topo e ar",
		w.get_block_xyz(10, VoxelConfig.CHUNK_SIZE_Y, 10) == BlockDefs.Block.AIR)
	var n0 := w.edits.size()
	_check("set_block grava edicao", w.set_block(p, BlockDefs.Block.STONE), "voxel=%s" % p)
	_check("diario de edicoes cresceu", w.edits.size() == n0 + 1, "%d -> %d" % [n0, w.edits.size()])
	var queued := w.pending_meshes()
	_check("chunk sujo entrou na fila", queued >= 1, "fila=%d" % queued)
	w.process(64)
	_check("rebuild sob demanda", w.get_block(p) == BlockDefs.Block.STONE,
		"fila apos process=%d" % w.pending_meshes())
	_check("leitura igual ao escrito", w.get_block(p) == BlockDefs.Block.STONE)
	_check("repetir o mesmo valor e no-op", not w.set_block(p, BlockDefs.Block.STONE))
	_check("no-op nao polui o diario", w.edits.size() == n0 + 1, "%d" % w.edits.size())


# ------------------------------------------------------------- coordenadas

## O vocabulario canônico (Coords): piso de negativos, bordas de chunk,
## ida e volta da chave de save e a grade do Eter saem todos da mesma fonte.
func _check_coords() -> void:
	var tb := Coords.to_block(Vector3(-0.25, 3.75, 127.9))
	_check("to_block e piso com negativo", tb == Vector3i(-1, 3, 127), "to_block=%s" % tb)
	var edge_a := Vector3i(15, 31, 16)
	var edge_b := Vector3i(16, 31, 15)
	_check("chunk na borda 15/16",
		Coords.chunk_of(edge_a) == Vector2i(0, 1) and Coords.chunk_of(edge_b) == Vector2i(1, 0),
		"chunk(15,y,z16)=%s  chunk(16,y,z15)=%s" % [Coords.chunk_of(edge_a), Coords.chunk_of(edge_b)])
	var round_ok := true
	for b in [edge_a, edge_b, Vector3i.ZERO, Vector3i(127, 63, 127)]:
		var key := Coords.chunk_of(b)
		if Coords.chunk_origin(key) + Coords.local_of(b, key) != b:
			round_ok = false
	_check("origem + local devolve o bloco", round_ok, "bordas, origem e canto oposto")
	var k := Vector3i(-3, 27, 129)
	_check("chave de save ida e volta", Coords.parse_block_key(Coords.block_key(k)) == k,
		"chave=%s" % Coords.block_key(k))
	var c1 := Coords.cell_of_voxel(Vector3i(17, 3, 5))
	var c2 := Coords.cell_of_voxel(Vector3i(-1, 0, 0))
	_check("celula do eter e piso por 4", c1 == Vector3i(4, 0, 1) and c2 == Vector3i(-1, 0, 0),
		"cell(17,3,5)=%s  cell(-1,0,0)=%s" % [c1, c2])
	var co := Coords.cell_origin(Vector3i(4, 0, 1))
	_check("origem da celula devolve o canto", co == Vector3i(16, 0, 4), "cell_origin=%s" % co)


# --------------------------------------------------------------------- eter

func _check_aether() -> void:
	var a: AetherField = main.aether
	var pos := _spawn + Vector3(0.0, 6.0, 0.0)
	var cell := a.cell_of_world(pos)
	var e0 := a.total_energy()
	_check("celula comecou limpa", a.sample_cell(cell, AetherField.Channel.FEAR) < 0.01,
		"valor=%.4f" % a.sample_cell(cell, AetherField.Channel.FEAR))
	a.imprint(pos, AetherField.Channel.FEAR, 2.5)
	var peak := a.sample(pos, AetherField.Channel.FEAR)
	_check("imprint lido de volta", peak > 1.0, "amostra=%.3f" % peak)
	var e1 := a.total_energy()
	_check("energia total subiu", e1 > e0, "%.3f -> %.3f" % [e0, e1])
	var nb := cell + Vector3i(1, 0, 0)
	var v0 := a.sample_cell(nb, AetherField.Channel.FEAR)
	# Saldo medido passada a passada e canal a canal: o que sai e o decaimento previsto
	# menos o corte de MIN_VALUE (`pass_cut`). Sem essa colheita o deficit real do log
	# (2,500 -> 2,296 contra 2,471 que a meia-vida previa) fica sem dono, e numero sem
	# dono e exatamente o que o mandato 1 proibe de publicar.
	var tol := 1e-4
	var keeps: Array = []
	for ch in AetherField.Channel.COUNT:
		keeps.append(pow(0.5, 0.25 / float(AetherField.HALF_LIFE[ch])))
	var mass: Array = a.channel_totals()
	var fear_mass0 := float(mass[AetherField.Channel.FEAR])
	var keep_fear := float(keeps[AetherField.Channel.FEAR])
	var cut_fear := 0.0
	var cut_total := 0.0
	var created := 0.0
	var worst_err := 0.0
	# Previsao em cadeia, dupla e sem releitura: a cada passada o corte sai do campo e
	# nao decai mais, entao o que falta nao e (1 - keep^8) x massa menos o corte somado,
	# e o corte de cada passada vezes o keep das passadas seguintes.
	var pred_fear := fear_mass0
	for i in 8:
		a.diffuse_and_decay(0.25)
		var after: Array = a.channel_totals()
		var err := 0.0
		for ch in AetherField.Channel.COUNT:
			var decayed := float(mass[ch]) * float(keeps[ch])
			err = maxf(err, absf(float(after[ch]) - decayed + float(a.pass_cut[ch])))
			created = maxf(created, float(after[ch]) - decayed)
			cut_total += float(a.pass_cut[ch])
		var pass_cut_fear := float(a.pass_cut[AetherField.Channel.FEAR])
		cut_fear += pass_cut_fear
		pred_fear = pred_fear * keep_fear - pass_cut_fear
		mass = after
		worst_err = maxf(worst_err, err)
	var v1 := a.sample_cell(nb, AetherField.Channel.FEAR)
	_check("difusao passou para a vizinha", v1 > v0, "%.4f -> %.4f em 2 s" % [v0, v1])
	var e2 := a.total_energy()
	_check("meia-vida reduziu a energia", e2 < e1, "%.3f -> %.3f" % [e1, e2])
	_check("nenhuma passada cria massa", created <= tol,
			"pior ganho=%.8f acima do decaimento em 8 passadas x 3 canais" % created)
	_check("saldo fecha com o corte de MIN_VALUE", worst_err <= tol,
			"pior erro=%.8f corte=%.6f" % [worst_err, cut_total])
	# O numero que o dossier 03 deixou pendente: 2,500 -> 2,296 onde a meia-vida previa
	# 2,471. A cadeia acima fecha essa diferenca pelo corte medido, nao por estimativa.
	var fear_now := float(a.channel_totals()[AetherField.Channel.FEAR])
	_check("o corte da fronteira explica a perda alem da meia-vida",
			cut_fear > 0.02 and absf(fear_now - pred_fear) <= tol,
			"fear %.6f -> %.6f; so meia-vida daria %.6f; cadeia com corte da %.6f (corte %.6f)" % [
			fear_mass0, fear_now, fear_mass0 * keep_fear ** 8, pred_fear, cut_fear])
	a.imprint(pos, AetherField.Channel.FEAR, 900.0)
	_check("teto de valor aplicado",
		is_equal_approx(a.sample(pos, AetherField.Channel.FEAR), AetherField.MAX_VALUE),
		"teto=%.1f" % AetherField.MAX_VALUE)
	# A saida de massa do teto e conhecida: o excedente nao entra no campo.
	var fear_after_teto := float(a.channel_totals()[AetherField.Channel.FEAR])
	_check("teto nao injeta o excedente no campo",
			fear_after_teto <= float(mass[AetherField.Channel.FEAR]) + AetherField.MAX_VALUE + tol,
			"canal %.6f -> %.6f por imprint de 900.0 (teto %.1f)" % [
			float(mass[AetherField.Channel.FEAR]), fear_after_teto, AetherField.MAX_VALUE])
	var totals: Array = a.channel_totals()
	_check("ledger com 3 canais", totals.size() == 3,
		"work=%.2f blood=%.2f fear=%.2f" % [totals[0], totals[1], totals[2]])


# --------------------------------------------------------------------- relogio

func _check_clock() -> void:
	var c := SimClock.new()
	var total := 0
	for i in 600:
		total += c.advance(1.0 / 60.0)
	_check("60 Hz vira 20 Hz", absf(float(total) - 200.0) <= 1.0,
		"%d passos em 10 s de logica" % total)
	var s := c.advance(1.0)
	_check("cap de 5 passos por frame", s == 5 and c.dropped_ticks == 1,
		"passos=%d  perdidos=%d" % [s, c.dropped_ticks])
	_check("duracao do passo", is_equal_approx(c.step_duration(), 0.05), "step=%.3f" % c.step_duration())
	c.begin_step()
	c.end_step()
	_check("cronometro do passo preenche o pico", c.worst_step_ms >= 0.0,
		"ultimo=%.3f ms  pior=%.3f ms" % [c.last_step_ms, c.worst_step_ms])


# --------------------------------------------------------------------- mecanicas

## Apontar exige dois updates: _update_target le a base da camera que o update
## anterior escreveu, e _update_camera roda no fim do mesmo call.
func _aim(p: Player, pitch: float) -> void:
	p.pitch = pitch
	p.update_local(1.0 / 60.0)
	p.update_local(1.0 / 60.0)


func _check_mechanics() -> void:
	var p: Player = main.player
	var w: VoxelWorld = main.world
	# Congela o mundo: um lobo que atravesse a mira entre o minerar e o colocar
	# trocaria o alvo, e o passo passaria a medir a IA em vez da mecanica. Pause,
	# e nao process_mode DISABLED em main: congelado assim o node nao recebe input
	# nenhum, e e no `_input` do jogador que a borda do clique agora nasce.
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	p.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	get_tree().paused = true
	p.feet_to_spawn(_spawn)
	p.yaw = 0.0
	_aim(p, -0.9)
	var dirv: Vector3 = p.camera.global_transform.basis.z * -1.0
	var probe := w.ray_voxel(p.eye_position(), dirv, Player.REACH)
	print("       mira: olho=%s  dir=(%.3f, %.3f, %.3f)  dda=%.2f m em %s"
		% [p.eye_position(), dirv.x, dirv.y, dirv.z, probe.distance, probe.voxel])
	_check("mira encontrou um bloco", p.target_valid,
		"voxel=%s  dureza=%.2f  name=%s" % [p.target_voxel, p.target_hardness, p.look_target_name])
	if p.target_valid:
		var tgt := p.target_voxel
		var h := p.target_hardness
		var was := w.get_block(tgt)
		var drop := BlockDefs.drop_of(was)
		var drop0 := p.inv.count_of(drop)
		var mined0 := int(main.stats["mined"])
		var items0 := p.inv.item_count()
		Input.action_press("break_block")
		var n := 0
		while int(main.stats["mined"]) == mined0 and n < 400:
			p.update_local(1.0 / 60.0)
			n += 1
		Input.action_release("break_block")
		_check("segurar break minerou", int(main.stats["mined"]) == mined0 + 1,
			"%d atualizacoes" % n)
		_check("tempo de mineracao == dureza", absf(float(n) / 60.0 - h) < 0.034,
			"dureza=%.3f  medido=%.3f" % [h, float(n) / 60.0])
		_check("voxel virou ar", w.get_block(tgt) == BlockDefs.Block.AIR, "voxel=%s" % tgt)
		# o que entra no inventario e o drop do registro, nao o id que estava la:
		# pedra vira bruta, grama vira terra, folha nao vira nada
		var want := 1 if drop != BlockDefs.Block.AIR else 0
		_check("lavra entrou no inventario como drop",
			p.inv.count_of(drop) == drop0 + want and p.inv.item_count() == items0 + want,
			"bloco=%d  drop=%d  pilha=%d->%d" % [was, drop, drop0, p.inv.count_of(drop)])

	# Corpo do jogador: um modelo por vista. Em 3a pessoa o rig inteiro esta em
	# cena e o view model sai do quadro; em 1a e ao contrario — a camera mora no
	# olho, o corpo de 3a pessoa nao entra (na lente ele virava slab sobre o
	# alvo) e o que se ve e o braco direito do view model segurando o bloco
	# selecionado, com o arco de lavra e o de golpe visiveis.
	p.yaw = 0.62
	p.third_person = true
	p.update_local(1.0 / 60.0)
	var head_tp := p.avatar.head_shown()
	var drift := p.avatar.global_position.distance_to(p.body.feet_pos)
	var facing := rad_to_deg(p.avatar.rotation.y)
	var parts := _mesh_count(p.avatar)
	var parts_tp := _mesh_count_visible(p.avatar)
	var vm_tp := _mesh_count_visible(p.viewmodel)
	var span := _mesh_span(p.avatar)
	var top: float = span[1] - p.body.feet_pos.y
	var base: float = span[0] - p.body.feet_pos.y
	p.select_slot(0)
	p.third_person = false
	p.update_local(1.0 / 60.0)
	var head_fp := p.avatar.head_shown()
	var parts_fp := _mesh_count_visible(p.avatar)
	var vm_fp := _mesh_count_visible(p.viewmodel)
	_check("corpo do jogador tem malhas", parts >= 20, "caixas=%d" % parts)
	_check("silhueta fecha em ~1,8 m", top > 1.7 and top < 1.9, "altura=%.2f" % top)
	_check("nenhuma malha abaixo dos pes", base > -0.15, "base=%.2f" % base)
	_check("avatar cola nos pes", drift < 0.002, "desvio=%.5f" % drift)
	_check("avatar gira com o yaw", absf(facing - rad_to_deg(0.62)) < 0.01,
		"corpo=%.2fdeg  esperado=%.2fdeg" % [facing, rad_to_deg(0.62)])
	_check("corpo inteiro em cena na 3a pessoa",
		head_tp and p.avatar.visible and parts_tp == parts,
		"visiveis=%d de %d" % [parts_tp, parts])
	_check("view model fora de cena na 3a pessoa", vm_tp == 0, "malhas vm=%d" % vm_tp)
	_check("corpo de 3a pessoa sai inteiro na 1a", parts_fp == 0 and not head_fp,
		"malhas visiveis=%d" % parts_fp)
	_check("braco de 1a pessoa em cena", vm_fp >= 8, "malhas vm=%d" % vm_fp)

	# O braco na frente da lente: o cubo segue o slot selecionado, fica no
	# quadrante inferior direito dentro do quadro, e desenha SEM teste de
	# profundidade — encostando o nariz na parede o membro nao pode ser engolido
	# pelo muro (frame `parede` da sonda).
	var vm: FPViewmodel = p.viewmodel
	var res := _screen_res()

	# calibracao do instrumento antes de confiar nele: a formula da suite,
	# alimentada com a resolucao real do processo, bate com o unproject do motor
	# ponto a ponto nos 8 cantos do cubo. So depois disso ela recebe os
	# 1280x720 da partida, que o headless nao tem.
	var proc := Vector2(p.camera.get_viewport().size)
	var gg := vm.held_mesh().global_transform
	var hh := FPViewmodel.HELD_SIZE * 0.5
	var dev := 0.0
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				var corner := gg * Vector3(sx * hh, sy * hh, sz * hh)
				var mine := _lens_px(p.camera, corner, proc)
				var engine := p.camera.unproject_position(corner)
				dev = maxf(dev, maxf(absf(mine.x - engine.x), absf(mine.y - engine.y)))
	_check("projecao da suite bate com a do motor", dev < 0.01,
		"desvio=%.5f px no quadro %dx%d" % [dev, int(proc.x), int(proc.y)])
	# repouso de verdade antes de medir enquadramento e arcos: a lavra do passo
	# acima deixou _dig em 1, e no ciclo de picareta o braco esta erguido — o
	# quadro medido ali nao seria o do punho parado, nem o do soco sozinho
	vm.mining = false
	for i in 20:
		vm.advance(1.0 / 60.0)
	_check("bloco na mao == slot selecionado", vm.block_id == p.selected_block(),
		"vm=%d  mao=%d" % [vm.block_id, p.selected_block()])
	var fr := _vm_frame(p.camera, vm.held_mesh())
	_check("cubo na mao dentro do quadro", _in_frame(fr, res),
		"quadro=%dx%d  cubo=%s" % [int(res.x), int(res.y), _fmt_frame(fr)])
	_check("cubo no quadrante inferior direito, mira livre", fr.size() == 4
		and fr[0] > res.x * 0.5 and fr[1] > res.y * 0.5,
		"cubo=%s  mira=(%d,%d)" % [_fmt_frame(fr), int(res.x * 0.5), int(res.y * 0.5)])
	_check("membro inteiro desenhado sobre o mundo",
		_mesh_count_no_depth(p.viewmodel) == vm_fp,
		"sem depth test=%d de %d" % [_mesh_count_no_depth(p.viewmodel), vm_fp])

	# Os dois arcos, medidos no eixo que a lente ve. O de golpe sai do repouso,
	# arma com o cotovelo dobrado e corta para dentro; o de lavra e o ciclo
	# continuo enquanto o botao esta pressionado. Nenhum dos dois pode empurrar
	# o cubo para fora do quadro — a primeira versao jogava o bloco pela borda
	# de cima, e contagem de malhas nao percebe isso.
	var ang0 := vm.arm_angles()
	var arc := _vm_arc(vm, p.camera, res, 24, true)
	_check("golpe mexe o ombro", arc[1] - arc[0] > 0.30,
		"ombro repouso=%.2f  %.2f..%.2f rad" % [ang0.x, arc[0], arc[1]])
	_check("cubo do golpe sempre no quadro", int(arc[2]) == 0,
		"ticks fora=%d de 24" % int(arc[2]))
	arc = _vm_arc(vm, p.camera, res, 60, false)
	_check("lavra mexe o ombro", arc[1] - arc[0] > 0.35,
		"ombro %.2f..%.2f rad" % [arc[0], arc[1]])
	_check("cubo da lavra sempre no quadro", int(arc[2]) == 0,
		"ticks fora=%d de 60" % int(arc[2]))
	vm.mining = false
	for i in 20:
		vm.advance(1.0 / 60.0)

	# pilha sem bloco = punho closed: o cubo some, o braco fica
	vm.block_id = BlockDefs.Block.AIR
	vm.advance(1.0 / 60.0)
	_check("sem bloco = mao vazia", not vm.held_mesh().visible
		and _vm_frame(p.camera, vm.held_mesh()).is_empty(), "bloco=%d" % vm.block_id)
	vm.block_id = p.selected_block()
	vm.advance(1.0 / 60.0)

	# O corpo de 3a pessoa carrega o bloco da tecla ativa, e a pose do braco
	# direito, o ciclo de lavra e o de golpe mudam com a dureza do que ele segura.
	_check_held_tp(p)

	# Colocar exige o pipeline real de input: a borda do clique nasce em `_input` e
	# vira bloco no tick seguinte. Minerar pode continuar sintetico porque le o
	# nivel da acao, nao a borda. O mundo segue congelado e o clique arma a maquina
	# de espera: a assercao vive em _check_place.
	_aim(p, -0.9)
	_place_voxel = p.place_voxel
	_place_sel = p.selected_block()
	_place_n0 = p.inv.selected_count()
	_place0 = int(main.stats["placed"])
	print("       alvo do place: valid=%s  voxel=%s  place=%s  pos=%s  bloco=%d  pilha=%d"
		% [p.target_valid, p.target_voxel, _place_voxel, p.body.feet_pos, _place_sel, _place_n0])
	_arm_click(true)

	# kit: a hotbar de antes (7 blocos infinitos) sao os mesmos blocos com
	# quantidade, mais os dois slots de craft que comecam a 0 de proposito
	_check("tecla 1 comeca no capim com 32",
		p.inv.slot_block(p.inv.pin_of(0)) == BlockDefs.Block.GRASS
			and p.inv.slot_count(p.inv.pin_of(0)) == 32,
		"bloco=%d  qtd=%d  slots=%d" % [p.inv.slot_block(p.inv.pin_of(0)),
			p.inv.slot_count(p.inv.pin_of(0)), Inventory.SLOTS])
	_check("hotbar tem 10 teclas pinadas nos slots",
		Inventory.HOTBAR == 10 and p.inv.pin_of(9) == 9 and p.inv.pin_of(0) == 0,
		"pino9=%d  pino0=%d" % [p.inv.pin_of(9), p.inv.pin_of(0)])
	_check("pilha maxima vem do registro",
		BlockDefs.stack_max(BlockDefs.Block.GRASS) == 64
			and BlockDefs.stack_max(BlockDefs.Block.BENCH) == 16,
		"grama=%d  bancada=%d" % [BlockDefs.stack_max(BlockDefs.Block.GRASS),
			BlockDefs.stack_max(BlockDefs.Block.BENCH)])

	var ray := w.ray_voxel(p.eye_position(), Vector3(0.0, -1.0, 0.0), 8.0)
	_check("raycast DDA acerta o chao", ray.valid and ray.distance < 3.0,
		"dist=%.2f  voxel=%s" % [ray.distance, ray.voxel])
	var diag := w.ray_voxel(p.eye_position(), Vector3(0.0, -0.6, -0.8), Player.REACH)
	_check("raycast DDA em raio inclinado", diag.valid,
		"dist=%.2f  voxel=%s" % [diag.distance, diag.voxel])
	_check("linha de visada curta e limpa",
		w.line_of_sight(p.eye_position(), p.eye_position() + Vector3(0.0, 3.0, 0.0)))


## Posicao do cubo na mao direita no quadro do proprio corpo: +x = lado direito,
## -z = para onde o personagem olha, y acima dos pes. E o que a orbita ve, sem o
## yaw do jogador no meio da conta.
func _held_local(p: Player) -> Vector3:
	return p.avatar.global_transform.affine_inverse() * p.avatar.held_mesh().global_position


## Rect projetado na moldura pelos oito cantos do AABB de uma malha. Cantos
## atras da lente saem da conta: sem isso o rect explode e a medida vira ruido.
func _proj_rect(cam: Camera3D, mi: MeshInstance3D) -> Rect2:
	var r := Rect2()
	var seen := false
	var ab: AABB = mi.mesh.get_aabb()
	for sx in [ab.position.x, ab.end.x]:
		for sy in [ab.position.y, ab.end.y]:
			for sz in [ab.position.z, ab.end.z]:
				var wp := mi.global_transform * Vector3(sx, sy, sz)
				if (cam.global_transform.affine_inverse() * wp).z >= -0.05:
					continue
				var sp := cam.unproject_position(wp)
				r = r.expand(sp) if seen else Rect2(sp, Vector2.ZERO)
				seen = true
	return r


## Fracao do cubo na mao que nenhum corpo mais proximo da camera cobre, medida
## numa malha 8x8 de pontos dentro do rect projetado do cubo. E a medida do
## defeito que a geometria sozinha nao via: o cubo correto no espaco do corpo
## podia cair inteiro atras do punho e no quadro nao havia bloco nenhum. A
## profundidade entra na conta porque o rect projetado nao diz quem esta na
## frente -- sem ela a pose velha media 0,43 de "livre" e a checagem passava
## justamente no quadro quebrado. Os dois bracos, com esta medicao e com o olho
## (sonda de pixel em janela real): 0,02 e 0,00 contra 0,062 e 0,019 na pose
## velha; 0,45 e 0,30 contra 0,405 e 0,294 na pose atual.
func _held_free(av: PlayerAvatar, cam: Camera3D) -> float:
	var cube := av.held_mesh()
	var cr := _proj_rect(cam, cube)
	if cr.size.x <= 1.0 or cr.size.y <= 1.0:
		return 0.0
	var cd := _view_depth(cam, cube)
	var nearer: Array[Rect2] = []
	for mi: MeshInstance3D in av.find_children("*", "MeshInstance3D", true, false):
		if mi == cube or not mi.visible:
			continue
		if _view_depth(cam, mi) >= cd:
			continue
		var mr := _proj_rect(cam, mi)
		if mr.size.x <= 1.0 or mr.size.y <= 1.0:
			continue
		nearer.append(mr)
	if nearer.is_empty():
		return 1.0
	var n := 0
	var free := 0
	for iy in 8:
		for ix in 8:
			var pt := Vector2(cr.position.x + cr.size.x * (float(ix) + 0.5) / 8.0,
				cr.position.y + cr.size.y * (float(iy) + 0.5) / 8.0)
			n += 1
			var covered := false
			for r in nearer:
				if r.has_point(pt):
					covered = true
					break
			if not covered:
				free += 1
	return float(free) / float(maxi(n, 1))


## Distancia da camera ao centro do AABB da malha, no espaco da lente. Menor =
## mais perto do olho, entao e ela que tapa a outra.
func _view_depth(cam: Camera3D, mi: MeshInstance3D) -> float:
	var c := cam.global_transform.affine_inverse() \
		* (mi.global_transform * mi.mesh.get_aabb().get_center())
	return -c.z


## Periodo (em frames de 1/60) e amplitude (rad) do ciclo de lavra do rig. O
## campo `mining` e escrito na fronteira do rig -- a linha que `_update_avatar`
## escreve no Player -- porque os dois ciclos precisam da MESMA pose de partida
## sem quebrar dois blocos no mundo: aqui se mede a resposta do corpo, nao a da
## lavra. Amplitude abaixo do ciclo cheio nao engana o periodo, que e a distancia
## entre topos. Devolve periodo -1 se o segundo topo nunca chegou.
func _avatar_cycle(av: PlayerAvatar, ticks: int) -> Array:
	av.mining = true
	var lo := 999.0
	var hi := -999.0
	var prev := av.arm_angles().x
	var rising := false
	var tops := 0
	var first := -1
	var second := -1
	for i in ticks:
		av.advance(1.0 / 60.0)
		var cur := av.arm_angles().x
		lo = minf(lo, cur)
		hi = maxf(hi, cur)
		if cur > prev:
			rising = true
		elif rising:
			tops += 1
			if tops == 1:
				first = i
			elif tops == 2:
				second = i
			rising = false
			if second >= 0:
				break
		prev = cur
	av.mining = false
	for i in 60:
		av.advance(1.0 / 60.0)
	return [float(second - first) if second >= 0 else -1.0, hi - lo]


## Amplitude do golpe no rig: o impulso inteiro dura 1/2,8 s, entao 26 frames de
## 1/60 cobrem armao, corte e volta; os 40 seguintes devolvem o braco ao repouso.
func _avatar_swing_span(av: PlayerAvatar) -> float:
	av.swing()
	var lo := 999.0
	var hi := -999.0
	for i in 26:
		av.advance(1.0 / 60.0)
		var a := av.arm_angles().x
		lo = minf(lo, a)
		hi = maxf(hi, a)
	for i in 40:
		av.advance(1.0 / 60.0)
	return hi - lo


## O que a mao direita do rig de 3a pessoa segura muda o corpo inteiro. Blocos
## escolhidos pela tecla da hotbar (caminho real), durezas lidas do registro:
## pedra 0,95 = carga cheia, folha 0,22 = carga leve, vidro 0,10 = o ramo ALPHA.
func _check_held_tp(p: Player) -> void:
	var av: PlayerAvatar = p.avatar
	p.third_person = true
	# A orbita de atras so existe com o olhar neutro: o yaw deixado pelo passo
	# anterior gira a lente para o lado e a oclusao passa a valer para um angulo
	# que o jogo nao mostra -- foi assim que a pose velha deu 0,75 de "livre" no
	# quadro de tras-reto, onde o olho mede 0,02.
	p.yaw = 0.0
	p.pitch = 0.0
	p.select_slot(2)
	for i in 30:
		p.update_local(1.0 / 60.0)
	var heavy := av.arm_angles()
	var heavy_pos := _held_local(p)
	var heavy_free := _held_free(av, p.camera)
	var cube := av.held_mesh()
	var cube_mesh: ArrayMesh = cube.mesh as ArrayMesh
	var tex := cube.material_override as StandardMaterial3D
	_check("cubo na mao do avatar == slot selecionado",
		av.block_id == p.selected_block() and cube.visible
			and av.block_id == BlockDefs.Block.STONE,
		"avatar=%d  slot=%d  name=%s" % [av.block_id, p.selected_block(),
			BlockDefs.display_name(av.block_id)])
	_check("cubo do rig amostra o atlas do mundo no tamanho da orbita",
		tex != null and tex.albedo_texture == p.world.atlas_texture()
			and cube_mesh != null
			and absf(cube_mesh.get_aabb().size.x - PlayerAvatar.HELD_SIZE) < 0.001,
		"atlas=%s  lado=%.3f (esperado %.2f, 1a pessoa usa %.2f)" % [
			str(tex.albedo_texture != null), cube_mesh.get_aabb().size.x,
			PlayerAvatar.HELD_SIZE, FPViewmodel.HELD_SIZE])
	p.select_slot(6)
	for i in 30:
		p.update_local(1.0 / 60.0)
	var light := av.arm_angles()
	var light_pos := _held_local(p)
	var light_free := _held_free(av, p.camera)
	_check("cubo na lateral direita, a frente do tronco",
		heavy_pos.x > 0.24 and light_pos.x > 0.24 and heavy_pos.z < -0.05
			and light_pos.z < -0.05,
		"pedra=(%.2f,%.2f,%.2f)  folha=(%.2f,%.2f,%.2f)" % [heavy_pos.x, heavy_pos.y,
			heavy_pos.z, light_pos.x, light_pos.y, light_pos.z])
	_check("cubo acima do joelho e abaixo da cabeca",
		heavy_pos.y > 0.40 and heavy_pos.y < 1.50 and light_pos.y > 0.40
			and light_pos.y < 1.50, "pedra y=%.2f  folha y=%.2f" % [heavy_pos.y, light_pos.y])
	# A premissa que a pose tinha e nao estava segura: no quadro em que a orbita
	# mora -- atras do personagem -- o cubo nao pode cair inteiro atras do proprio
	# braco. Sem abertura do ombro e com o 0,16 da lente ele caia 100% coberto.
	# O corte de 0,15 nao e adjetivo: a pose velha deu 0,02 e 0,00 aqui, a atual
	# da 0,45 e 0,30, e o pior braco ainda fica duas vezes acima do minimo.
	_check("bloco na mao passa para fora do braco no quadro da orbita",
		heavy_free > 0.15 and light_free > 0.15,
		"livre pedra=%.2f  folha=%.2f" % [heavy_free, light_free])
	_check("peso do bloco muda a pose do braco",
		heavy.x < light.x - 0.15 and heavy.y < light.y - 0.60
			and light_pos.y > heavy_pos.y + 0.25,
		"ombro pedra=%.2f folha=%.2f  cotovelo pedra=%.2f folha=%.2f  cubo y %.2f->%.2f"
			% [heavy.x, light.x, heavy.y, light.y, heavy_pos.y, light_pos.y])

	# os dois ciclos de lavra: mesma pose de partida, carga diferente na mao
	p.select_slot(6)
	for i in 30:
		p.update_local(1.0 / 60.0)
	var leaf_cycle: Array = _avatar_cycle(av, 240)
	p.select_slot(2)
	for i in 30:
		p.update_local(1.0 / 60.0)
	var stone_cycle: Array = _avatar_cycle(av, 320)
	_check("ciclo de lavra do rig mexe o ombro",
		float(leaf_cycle[0]) > 0.0 and float(leaf_cycle[1]) > 0.35,
		"periodo=%.0f frames  amplitude=%.2f rad" % [leaf_cycle[0], leaf_cycle[1]])
	_check("pedra lavra mais funda e mais lenta que folha",
		float(stone_cycle[0]) > float(leaf_cycle[0]) * 1.4
			and float(stone_cycle[1]) > float(leaf_cycle[1]) * 1.15,
		"periodo folha=%.0f pedra=%.0f  amplitude folha=%.2f pedra=%.2f"
			% [leaf_cycle[0], stone_cycle[0], leaf_cycle[1], stone_cycle[1]])

	# golpe: o mesmo arco, mais fundo com a carga
	var swing_stone := _avatar_swing_span(av)
	p.select_slot(6)
	for i in 30:
		p.update_local(1.0 / 60.0)
	var swing_leaf := _avatar_swing_span(av)

	# mao vazia pelo caminho do jogo: a pilha gasta em `consume_selected` (o mesmo
	# que o place usa) e o cubo tem que sair de cena junto do `selected_block()`.
	var slot := p.inv.selected_slot()
	var had := p.inv.slot_count(slot)
	var was := p.inv.slot_block(slot)
	p.inv.consume_selected(had)
	for i in 40:
		p.update_local(1.0 / 60.0)
	var empty := av.arm_angles()
	_check("pilha zerada = mao vazia no rig",
		av.block_id == BlockDefs.Block.AIR and not av.held_mesh().visible,
		"bloco=%d  visivel=%s  pilha=%d->0" % [av.block_id, str(av.held_mesh().visible), had])
	_check("mao vazia devolve o braco ao repouso", empty.y < 0.35 and empty.y > 0.05,
		"cotovelo vazio=%.2f  folha=%.2f  pedra=%.2f" % [empty.y, light.y, heavy.y])
	var swing_empty := _avatar_swing_span(av)
	p.inv.add(was, had)
	p.select_slot(0)
	for i in 30:
		p.update_local(1.0 / 60.0)
	_check("golpe com pedra vai mais fundo que sem carga",
		swing_stone > swing_empty + 0.15 and swing_stone > swing_leaf + 0.05,
		"ombro pedra=%.2f folha=%.2f vazio=%.2f rad" % [swing_stone, swing_leaf, swing_empty])

	# o ramo ALPHA do material: vidro entra pelo caminho real da pilha e sai por
	# `take` depois. Na 1a pessoa este foi o defeito documentado (o cubo virava
	# painel leitoso); na 3a o cubo transparente tem que usar o MESMO material.
	p.inv.add(BlockDefs.Block.GLASS, 2)
	var key := -1
	for k in Inventory.HOTBAR:
		if p.inv.slot_block(p.inv.pin_of(k)) == BlockDefs.Block.GLASS:
			key = k
	if key >= 0:
		p.select_slot(key)
		for i in 30:
			p.update_local(1.0 / 60.0)
	var gm := av.held_mesh().material_override as StandardMaterial3D
	_check("vidro na mao do rig usa o material alpha",
		key >= 0 and gm != null and gm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
			and av.block_id == BlockDefs.Block.GLASS,
		"tecla=%d  bloco=%d  transparency=%d  classe=%d" % [key, av.block_id,
			gm.transparency if gm != null else -1,
			BlockDefs.draw_of(BlockDefs.Block.GLASS)])
	p.inv.take(BlockDefs.Block.GLASS, 2)
	p.select_slot(0)
	for i in 30:
		p.update_local(1.0 / 60.0)
	p.third_person = false
	for i in 10:
		p.update_local(1.0 / 60.0)


## Clique direito de verdade: um InputEventMouseButton novo por chamada (o engine
## recusa o mesmo objeto duas vezes no mesmo frame). Vai por
## `Input.parse_input_event()`, que e o caminho que atualiza o estado das acoes do
## InputMap; `Viewport.push_input()` entrega o evento aos callbacks dos nodes mas
## nao acende a acao, e `_apply_actions` le a acao.
func _click(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
	ev.global_position = Vector2(640.0, 360.0)
	ev.position = ev.global_position
	Input.parse_input_event(ev)


## Enfileira um clique e congela o passo do jogador ate a borda aparecer no input
## do engine: e o quadro em que o jogo real nao tinha tick de fisica. A assercao
## vive em _check_place. `soltar` nao arma: sem borda para esperar, basta o frame.
func _arm_click(pressed: bool) -> void:
	_click_frame = -1
	_click_detail = ""
	_armed = pressed
	_tick_player = false
	_click_pending = true
	_click_state = pressed


func _release_click() -> void:
	_armed = false
	_tick_player = false
	_click_pending = true
	_click_state = false


func _check_place() -> void:
	var w: VoxelWorld = main.world
	_check("clique do mouse virou acao no jogador", _click_frame > 0,
		_click_detail if _click_frame > 0 else "a borda nunca chegou (frame %d)" % _frame)
	_check("place_block colocou", _click_frame > 0 and int(main.stats["placed"]) == _place0 + 1,
		"voxel=%s  bloco=%d  achado=%d  colocados=%d->%d"
		% [_place_voxel, _place_sel, w.get_block(_place_voxel), _place0, int(main.stats["placed"])])
	_check("bloco certo no voxel certo", w.get_block(_place_voxel) == _place_sel,
		"esperado=%d  achado=%d" % [_place_sel, w.get_block(_place_voxel)])
	# A quantidade e o preco de colocar: sem o decremento o bloco seria criativo.
	var p: Player = main.player
	_check("colocar gastou um da pilha",
		_click_frame > 0 and p.inv.selected_count() == _place_n0 - 1,
		"pilha=%d->%d  bloco=%d" % [_place_n0, p.inv.selected_count(), _place_sel])
	_release_click()


## Antes de apontar para os pes o botao precisa ser lido como solto: se a acao
## continuasse presa, o proximo clique nao produziria borda nenhuma. Depois
## disto o mesmo clique cai numa celula que intersecta a AABB do corpo.
func _check_click_release() -> void:
	var p: Player = main.player
	_check("soltar o botao limpou a acao", not Input.is_action_pressed("place_block"),
		"frame=%d  presa=%s" % [_frame, Input.is_action_pressed("place_block")])
	# Gira o jogador ate o cooldown de colocacao (0,16 s) expirar: sem isto a recusa
	# da guarda poderia ser atribuida ao cooldown e nao a guarda em si.
	var n := 0
	while p._place_cd > 0.0 and n < 60:
		p.update_local(1.0 / 60.0)
		n += 1
	_aim(p, -1.4)
	_place_voxel = p.place_voxel
	_place0 = int(main.stats["placed"])
	print("       mira nos pes: place=%s  pos=%s  cooldown=%.3f  giros=%d"
		% [_place_voxel, p.body.feet_pos, p._place_cd, n])
	_arm_click(true)


func _check_place_guard() -> void:
	var p: Player = main.player
	var w: VoxelWorld = main.world
	var over_body := p.body.aabb().intersects(AABB(Vector3(_place_voxel), Vector3.ONE))
	_check("clique da guarda chegou ao jogador", _click_frame > 0,
		_click_detail if _click_frame > 0 else "a borda nunca chegou (frame %d)" % _frame)
	_check("colocar no proprio corpo recusado",
		_click_frame > 0 and over_body and int(main.stats["placed"]) == _place0
			and w.get_block(_place_voxel) == BlockDefs.Block.AIR,
		"voxel=%s  la em cima=%d  dentro do corpo=%s  colocados=%d"
		% [_place_voxel, w.get_block(_place_voxel), over_body, int(main.stats["placed"])])
	_release_click()
	get_tree().paused = false
	self.process_mode = Node.PROCESS_MODE_INHERIT
	p.process_mode = Node.PROCESS_MODE_INHERIT
	# Tecla 3 pela fila do viewport: entrega o evento ao `_unhandled_input` do
	# jogador. A assercao vive em _check_hotbar_key, tres frames adiante.
	var press := InputEventKey.new()
	press.physical_keycode = KEY_3
	press.pressed = true
	get_viewport().push_input(press)


func _check_hotbar_key() -> void:
	var p: Player = main.player
	var read := Input.is_action_pressed("hotbar_3")
	_check("tecla 3 troca o pino", p.inv.hotbar_index == 2,
		"slot=%d  acao lida=%s  bloco=%d" % [p.inv.hotbar_index, read, p.selected_block()])
	# A tecla nao e um deposito proprio: ela aponta para um slot, e o que muda e a
	# leitura. O bloco lido tem que ser o do slot 2 com a quantidade do slot 2.
	_check("tecla 3 mostra o bloco do slot 2",
		p.inv.pin_of(2) == 2 and p.selected_block() == p.inv.slot_block(2)
			and p.inv.selected_count() == p.inv.slot_count(2),
		"pino2=%d  selected=%d  qtd=%d" % [p.inv.pin_of(2), p.selected_block(), p.inv.selected_count()])
	var release := InputEventKey.new()
	release.physical_keycode = KEY_3
	release.pressed = false
	get_viewport().push_input(release)


## Construir no meio de uma lavra. O botao esquerdo preso e a dureza da pedra
## (0,95 s) deixam uma janela larga; o clique direito cai nela e tem que virar
## bloco mesmo assim. Prepara o alvo e arma o clique; a assercao vive 20 frames
## adiante, em _check_build_while_mining.
func _check_build_setup() -> void:
	var p: Player = main.player
	var w: VoxelWorld = main.world
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	p.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	get_tree().paused = true
	p.yaw = 0.0
	_aim(p, -0.9)
	if not p.target_valid:
		_check("mira para lavar um bloco", false, "sem alvo em reach")
		return
	_lava_target = p.target_voxel
	w.set_block(_lava_target, BlockDefs.Block.STONE)
	_aim(p, -0.9)
	Input.action_press("break_block")
	for i in 20:
		p.update_local(1.0 / 60.0)
	_place_voxel = p.place_voxel
	_place_sel = p.selected_block()
	_place0 = int(main.stats["placed"])
	print("       lavar=%s  place=%s  dureza=%.2f  progresso=%.2f  bloco=%d  colocados=%d"
		% [_lava_target, _place_voxel, p.target_hardness, p.mining_progress, _place_sel, _place0])
	_arm_click(true)


func _check_build_while_mining() -> void:
	var p: Player = main.player
	var w: VoxelWorld = main.world
	Input.action_release("break_block")
	_release_click()
	get_tree().paused = false
	self.process_mode = Node.PROCESS_MODE_INHERIT
	p.process_mode = Node.PROCESS_MODE_INHERIT
	_check("clique direito chegou durante a lavra", _click_frame > 0,
		_click_detail if _click_frame > 0 else "a borda nunca chegou (frame %d)" % _frame)
	_check("construiu com o ESQ segurado",
		_click_frame > 0 and int(main.stats["placed"]) == _place0 + 1
			and w.get_block(_place_voxel) == _place_sel,
		"voxel=%s  bloco=%d  achado=%d  colocados=%d->%d"
		% [_place_voxel, _place_sel, w.get_block(_place_voxel), _place0, int(main.stats["placed"])])
	_check("a lavra ainda nao tinha comido o alvo",
		w.get_block(_lava_target) == BlockDefs.Block.STONE,
		"voxel=%s  achado=%d  progresso=%.2f" % [_lava_target, w.get_block(_lava_target), p.mining_progress])


# ------------------------------------------------------------------ inventario

## Logica pura de pilha e de receita sobre um Inventory novo: nao depende do
## mundo, dos lobos nem do relogio, entao as regras que o jogador pediu
## (quantidade, teto por bloco, mesclar, partir, craft) sao medidas sem o ruido de
## uma simulacao rodando. O inventario do jogador fica intacto.
func _check_items() -> void:
	var inv := Inventory.new()
	var dirt := BlockDefs.Block.DIRT
	var grass := BlockDefs.Block.GRASS
	var sand := BlockDefs.Block.SAND
	var snow := BlockDefs.Block.SNOW
	var wood := BlockDefs.Block.WOOD
	var leaves := BlockDefs.Block.LEAVES
	var cobble := BlockDefs.Block.COBBLESTONE
	var plank := BlockDefs.Block.PLANK
	var bench := BlockDefs.Block.BENCH
	var stone := BlockDefs.Block.STONE
	var glass := BlockDefs.Block.GLASS

	# kit: os mesmos blocos da hotbar de 7, agora com numero, e os dois slots de
	# craft comecando vazios de proposito
	_check("kit = hotbar antiga com quantidade",
		inv.count_of(grass) == 32 and inv.count_of(wood) == 8
			and inv.count_of(plank) == 0 and inv.count_of(bench) == 0,
		"grama=%d  madeira=%d  tabua=%d  bancada=%d"
			% [inv.count_of(grass), inv.count_of(wood), inv.count_of(plank), inv.count_of(bench)])

	# teto por pilha vem do registro, e um bloco pode ter teto proprio
	inv.reset_default()
	var left_bench := inv.add(bench, 100)
	var max_bench := 0
	for i in Inventory.SLOTS:
		if inv.slot_block(i) == bench:
			max_bench = maxi(max_bench, inv.slot_count(i))
	_check("bancada tem teto menor que bloco comun",
		BlockDefs.stack_max(bench) == 16 and left_bench == 0
			and max_bench == 16 and inv.count_of(bench) == 100,
		"maior pilha=%d  total=%d  sobra=%d" % [max_bench, inv.count_of(bench), left_bench])
	inv.reset_default()
	var left_dirt := inv.add(dirt, 400)
	var max_dirt := 0
	for i in Inventory.SLOTS:
		if inv.slot_block(i) == dirt:
			max_dirt = maxi(max_dirt, inv.slot_count(i))
	_check("400 de terra viram 64 em cada slot",
		BlockDefs.stack_max(dirt) == 64 and left_dirt == 0 and max_dirt == 64,
		"maior pilha=%d  total=%d" % [max_dirt, inv.count_of(dirt)])

	# inventario cheio: o que nao coube volta, e o que nao tem buraco nao entra
	inv.reset_default()
	var kit_stone := inv.count_of(stone)
	var left_stone := inv.add(stone, 100000)
	var acima := 0
	for i in Inventory.SLOTS:
		if inv.slot_block(i) != BlockDefs.Block.AIR and inv.slot_block(i) == stone:
			if inv.slot_count(i) > BlockDefs.stack_max(stone):
				acima += 1
	_check("cheio devolve a sobra e nao cria pilha fora do teto",
		left_stone > 0 and inv.count_of(stone) == kit_stone + 100000 - left_stone
			and inv.space_for(stone) == 0 and acima == 0,
		"total=%d  esperado=%d  kit=%d  sobrou=%d  espaco=%d  acima do teto=%d"
			% [inv.count_of(stone), kit_stone + 100000 - left_stone, kit_stone,
				left_stone, inv.space_for(stone), acima])
	_check("bloco sem pilha nenhuma nao entra em lugar nenhum",
		inv.add(glass, 1) == 1 and inv.count_of(glass) == 0,
		"espaco p/ vidro=%d" % inv.space_for(glass))

	# coleta do Veloren: enche TODA pilha parcial antes de abrir a primeira vazia
	inv.reset_default()
	inv.take(sand, 6)
	var left_sand := inv.add(sand, 100)
	_check("enche a pilha parcial ate o teto antes da vazia",
		inv.slot_count(3) == 64 and inv.slot_block(7) == sand and inv.slot_count(7) == 46
			and left_sand == 0,
		"slot3=%d  slot7=%d:%d" % [inv.slot_count(3), inv.slot_block(7), inv.slot_count(7)])
	_check("tirar esvazia de tras para frente",
		inv.take(sand, 50) == 50 and inv.slot_count(7) == 0 and inv.slot_count(3) == 60,
		"slot3=%d  slot7=%d" % [inv.slot_count(3), inv.slot_count(7)])

	# partir = metade por divisao inteira, e a mao precisa estar vazia
	inv.reset_default()
	_check("partir da metade inteira para a mao",
		inv.split(0) and inv.held_count == 16 and inv.slot_count(0) == 16,
		"mao=%d  slot0=%d" % [inv.held_count, inv.slot_count(0)])
	_check("mao ocupada nao parte outra pilha", not inv.split(1))
	_check("guardar a mao devolve para a mesma pilha",
		inv.stash_hand() and inv.held_count == 0 and inv.slot_count(0) == 32,
		"slot0=%d  mao=%d" % [inv.slot_count(0), inv.held_count])
	inv.take(grass, 31)
	_check("pilha de 1 nao parte", not inv.split(0) and inv.held_count == 0,
		"slot0=%d" % inv.slot_count(0))

	# pegar/soltar: pilha inteira para cima, mesclar se for o mesmo bloco e couber,
	# senao trocar (inventory_manip.rs:814)
	inv.reset_default()
	_check("pegar sobe a pilha inteira",
		inv.pick_drop(0) and inv.held_count == 32 and inv.held_id == grass
			and inv.slot_count(0) == 0,
		"mao=%d  slot0=%d" % [inv.held_count, inv.slot_count(0)])
	_check("soltar em buraco desce tudo",
		inv.pick_drop(0) and inv.held_count == 0 and inv.slot_block(0) == grass
			and inv.slot_count(0) == 32, "slot0=%d" % inv.slot_count(0))
	_check("mesmo bloco mescla ate o teto e o resto fica na mao",
		inv.pick_drop(0) and inv.add(grass, 40) == 0 and inv.slot_count(0) == 40
			and inv.pick_drop(0) and inv.slot_count(0) == 64 and inv.held_count == 8,
		"slot0=%d  mao=%d" % [inv.slot_count(0), inv.held_count])
	_check("bloco diferente troca",
		inv.pick_drop(1) and inv.slot_block(1) == grass and inv.held_id == dirt
			and inv.held_count == 32,
		"slot1=%d  mao=%d:%d" % [inv.slot_block(1), inv.held_id, inv.held_count])
	_check("guardar antes de fechar o painel devolve a mao",
		inv.stash_hand() and inv.held_count == 0, "slot0=%d" % inv.slot_count(0))

	# hotbar = dez pinos sobre os proprios slots: a tecla muda a leitura, nunca a
	# pilha
	inv.reset_default()
	inv.select(3)
	_check("pino aponta para outro slot sem mover pilha",
		inv.pin(3, 6) and inv.selected_slot() == 6 and inv.selected_block() == leaves
			and inv.selected_count() == 8 and inv.slot_count(3) == 16,
		"slot=%d  bloco=%d  qtd=%d  areia slot3=%d"
			% [inv.selected_slot(), inv.selected_block(), inv.selected_count(), inv.slot_count(3)])
	inv.select(12)
	_check("tecla depois da decima da a volta na hotbar", inv.hotbar_index == 2,
		"sel=%d" % inv.hotbar_index)

	# receitas: lista, nao grade. Estacao filtra; insumo e espaco de saida sao
	# portao antes de qualquer consumo.
	var plank_r := _recipe_for(plank)
	var bench_r := _recipe_for(bench)
	var stone_r := _recipe_for(stone)
	var hand_n := 0
	for r in Recipes.list():
		if int(r["station"]) == Recipes.Station.HAND:
			hand_n += 1
	_check("sem bancada a lista so mostra as de mao",
		Recipes.visible(false).size() == hand_n
			and Recipes.visible(true).size() == Recipes.list().size(),
		"mao=%d  com bancada=%d  total=%d"
			% [Recipes.visible(false).size(), Recipes.visible(true).size(), Recipes.list().size()])
	inv.reset_default()
	_check("1 madeira -> 4 tabuas, com o preco cobrado",
		Recipes.can_craft(plank_r, inv) and Recipes.craft(plank_r, inv)
			and inv.count_of(plank) == 4 and inv.count_of(wood) == 7,
		"tabua=%d  madeira=%d" % [inv.count_of(plank), inv.count_of(wood)])
	_check("a cadeia ate a bancada fecha",
		Recipes.can_craft(bench_r, inv) and Recipes.craft(bench_r, inv)
			and inv.count_of(bench) == 1 and inv.count_of(plank) == 0,
		"bancada=%d  tabua=%d" % [inv.count_of(bench), inv.count_of(plank)])
	_check("receita sem insumo nao abre", not Recipes.can_craft(stone_r, inv),
		"bruta=%d" % inv.count_of(cobble))

	# o espaco de saida tambem e preco: sem ele o craft nao comeca, porque nao ha
	# como desfazer um craft meio-aplicado
	var inv2 := Inventory.new()
	inv2.take(stone, 99)
	_check("sobra 4 de bruta e entope o resto",
		inv2.add(cobble, 4) == 0 and inv2.add(snow, 100000) > 0
			and inv2.count_of(cobble) == 4 and inv2.space_for(stone) == 0,
		"bruta=%d  espaco p/ pedra=%d" % [inv2.count_of(cobble), inv2.space_for(stone)])
	_check("craft recusado nao toca em nada",
		not Recipes.craft(stone_r, inv2) and inv2.count_of(cobble) == 4
			and inv2.count_of(stone) == 0,
		"bruta=%d  pedra=%d" % [inv2.count_of(cobble), inv2.count_of(stone)])
	inv2.take(dirt, 99)
	_check("aberto um buraco o mesmo craft passa",
		Recipes.can_craft(stone_r, inv2) and Recipes.craft(stone_r, inv2)
			and inv2.count_of(stone) == 1 and inv2.count_of(cobble) == 0,
		"pedra=%d  bruta=%d" % [inv2.count_of(stone), inv2.count_of(cobble)])
	_check("vidro na bancada come 2 de areia",
		Recipes.can_craft(_recipe_for(glass), inv2)
			and Recipes.craft(_recipe_for(glass), inv2)
			and inv2.count_of(glass) == 1 and inv2.count_of(sand) == 14,
		"areia=%d  vidro=%d" % [inv2.count_of(sand), inv2.count_of(glass)])


func _recipe_for(out: int) -> Dictionary:
	for r in Recipes.list():
		if int(r["out"]) == out:
			return r
	return {}


# --------------------------------------------------------------------- memoria

func _check_memory() -> void:
	var w: Wolf = _wolf_vivo(3)
	if w == null:
		_check("ha quatro lobos vivos para a memoria", false, "matilha=%d" % main.wolves.size())
		return
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var p: Player = main.player
	p.feet_to_spawn(_spawn)
	var spot := _experiment_spot(w, p)
	_check("achou posicao com linha de visada", spot != Vector3.INF, "lobo=%d" % w.identity)
	if spot == Vector3.INF:
		main.process_mode = Node.PROCESS_MODE_INHERIT
		return
	var half := Wolf.MAX_HP * 0.5
	var a := _run_arm(w, spot, half, 5000.0, ARM_NONE)
	var b := _run_arm(w, spot, half, 15000.0, ARM_WOUND)
	var c := _run_arm(w, spot, half, 25000.0, ARM_NONE)
	var d := _run_arm(w, spot, half, 35000.0, ARM_REMEMBER)

	_check("A sem memoria: caca non vetada", not a["hunt_vetoed"] and a["intent"] == "hunt",
		"intencao=%s  caca=%.3f" % [a["intent"], a["hunt_score"]])
	_check("B com memoria: caca vetada", b["hunt_vetoed"],
		"intencao=%s  caca=%.3f" % [b["intent"], b["hunt_score"]])
	_check("B nao persegue o agressor", b["intent"] != "hunt", "intencao=%s" % b["intent"])
	_check("C ablar a crencia reabre a caca", not c["hunt_vetoed"] and c["intent"] == "hunt",
		"intencao=%s  caca=%.3f" % [c["intent"], c["hunt_score"]])
	_check("D regravar a crencia veto de novo", d["hunt_vetoed"] and d["intent"] != "hunt",
		"intencao=%s  caca=%.3f" % [d["intent"], d["hunt_score"]])
	_check("rumo do lobo seguiu a memoria",
		a["chasing"] and not b["chasing"] and c["chasing"] and not d["chasing"],
		"A=%s B=%s C=%s D=%s" % [a["chasing"], b["chasing"], c["chasing"], d["chasing"]])
	_check("confianca da crencia acima da soleira",
		w.mind.belief(BELIEF) >= 0.35, "confianca=%.2f  episodios=%d" % [
			w.mind.belief(BELIEF), w.mind.episodic.size()])
	_check("desconfianca do jogador registrada", w.mind.trust(Wolf.ACTOR_PLAYER) < 0.0,
		"confianca=%.2f  cautela=%.2f" % [w.mind.trust(Wolf.ACTOR_PLAYER), w.mind.temperament("caution")])
	print("       quatro bracos com hp=%.1f dist=%.1f: so a memoria mudou" % [w.hp, a["dist"]])

	w.hp = Wolf.MAX_HP
	w.mind.beliefs.erase(BELIEF)
	main.process_mode = Node.PROCESS_MODE_INHERIT


# --------------------------------------------------------------------- agua

## Acha a agua mais funda da seed, derruba um lobo nela e prova a patrulha seca
## por sorteio direto. O amostrador vive no _physics_process do harness.
func _check_swim_setup() -> void:
	var world: VoxelWorld = main.world
	var best := Vector3i.ZERO
	var best_score := -1
	for x in range(4, VoxelConfig.world_size_x() - 4, 2):
		for z in range(4, VoxelConfig.world_size_z() - 4, 2):
			var top := world.surface_height(x, z)
			if not world.is_water_xyz(x, top + 1, z):
				continue
			var depth := VoxelConfig.SEA_LEVEL - top
			var viz := 0
			for off in [Vector3i(2, 0, 0), Vector3i(-2, 0, 0), Vector3i(0, 0, 2), Vector3i(0, 0, -2)]:
				var t2 := world.surface_height(x + off.x, z + off.z)
				if world.is_water_xyz(x + off.x, t2 + 1, z + off.z):
					viz += 1
			var score := depth * 10 + viz
			if score > best_score:
				best_score = score
				best = Vector3i(x, top, z)
	var depth := VoxelConfig.SEA_LEVEL - best.y
	_lake = best
	_check("lago fundo no mapa", best_score > 0 and depth >= 2,
		"profundidade=%d  vizinhos=%d  em (%d,%d)" % [depth, (best_score % 10) if best_score > 0 else 0, best.x, best.z])
	if best_score <= 0 or depth < 2:
		_swim_wolf = null
		return
	_swim_bed_y = float(best.y)
	_swim_wolf = _wolf_vivo(1)
	if _swim_wolf == null:
		_check("ha dois lobos vivos para o lago", false, "matilha=%d" % main.wolves.size())
		return
	_swim_wolf.body.feet_pos = Vector3(float(best.x) + 0.5, _swim_bed_y + 0.4, float(best.z) + 0.5)
	_swim_wolf.body.velocity = Vector3.ZERO
	_swim_wolf._move_target = _swim_wolf.body.feet_pos + Vector3(6.0, 0.0, 0.0)
	_swim_start = _swim_wolf.body.feet_pos
	_swim_seen = false
	_swim_min_y = 999.0
	_swim_max_leg = 0.0
	_swim_seek = false
	var dry := 0
	for i in 200:
		_swim_wolf._wander_cd = 0.0
		_swim_wolf._leaf_wander({})
		if _swim_wolf._dry_ground(_swim_wolf._move_target):
			dry += 1
	_check("patrulha so sorteia terra seca", dry == 200, "%d/200 alvos secos" % dry)


func _check_swim_assert() -> void:
	if _swim_wolf == null:
		return
	var w := _swim_wolf
	var feet := w.body.feet_pos
	var world: VoxelWorld = main.world
	var now_dry := not w.body.in_water \
			and not world.is_water_xyz(floori(feet.x), world.surface_height(floori(feet.x), floori(feet.z)) + 1, floori(feet.z))
	var advanced := feet.distance_to(_swim_start) > 1.2
	_check("lobo boiou sem afundar ao leito", _swim_seen and _swim_min_y > _swim_bed_y + 0.3,
		"y minimo=%.2f  leito=%.2f" % [_swim_min_y, _swim_bed_y])
	_check("lobo rema na agua", _swim_seen and _swim_max_leg > 0.15,
		"pata max=%.2f rad" % _swim_max_leg)
	_check("lobo preso busca a margem", _swim_seek, "override de margem disparou")
	_check("lobo sai da agua ou avanca nadando", now_dry or advanced,
		"seco=%s  deslocamento=%.1f m" % [now_dry, feet.distance_to(_swim_start)])
	print("       nado: %.1f m desde a queda, pata max %.2f rad, y min %.2f" % [
		feet.distance_to(_swim_start), _swim_max_leg, _swim_min_y])
	w.body.feet_pos = w.home + Vector3(0.0, 1.0, 0.0)
	w.body.velocity = Vector3.ZERO


# ------------------------------------------------------------- mecanicas veloren

## Congela a arvore e deixa so o jogador receber passos do teste: mesmo contrato
## dos passos de minerar/colocar (a IA e o relogio param, a mecanica e dirigida).
func _pause_for(p: Player) -> void:
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	p.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	get_tree().paused = true


func _unpause_after(p: Player) -> void:
	get_tree().paused = false
	self.process_mode = Node.PROCESS_MODE_INHERIT
	p.process_mode = Node.PROCESS_MODE_INHERIT


## Passo cujo alvo e "um lobo VIVO" escolhe por aqui, em ordem de indice, e nao
## por numero fixo. `targets_under_crosshair` so devolve vivos e o corpo fica na
## matriz ate a faina de recolher, entao um indice caido aqui e mira sem alvo --
## sintoma que forcar `main.wolves[2].die()` reproduziu linha por linha. Nao foi
## o que a corrida natural tinha (abatidos=1, ou seja, nenhum lobo morto ainda),
## mas era um buraco do mesmo tamanho parado no caminho.
func _alive_wolf() -> Wolf:
	return _wolf_vivo(0)


## I-esimo lobo VIVO do censo atual, ou null quando a matilha borna e menor que i.
## Com o spawn em bandas e recusa honesta (dossie 14 §3.5) o censo do boot pode
## vir abaixo de `WOLF_COUNT`, entao indexar `main.wolves[i]` a mao e SCRIPT ERROR
## -- e o erro derruba em silencio todas as checagens do passo, sem vermelho.
func _wolf_vivo(i: int) -> Wolf:
	var vivos: Array[Wolf] = []
	for w in main.wolves:
		if (w as Wolf).alive:
			vivos.append(w)
	return vivos[i] if i < vivos.size() else null


## Distancia do lobo vivo mais proximo do olho que nao seja o alvo do passo;
## -1 quando a matilha inteira se resumiu a ele. E o numero que diz se o golpe
## poderia cair em outro corpo.
func _nearest_other_alive(p: Player, w: Wolf) -> float:
	var best := -1.0
	for other in main.wolves:
		if other == w or not (other as Wolf).alive:
			continue
		var d: float = (other as Wolf).body.feet_pos.distance_to(p.eye_position())
		if best < 0.0 or d < best:
			best = d
	return best


## Golpe unificado (botao esquerdo): entidade primeiro, bloco depois. No lobo o
## golpe e dano fixo + atordoamento (steering suspenso) + empurrada no corpo.
func _check_attack() -> void:
	var p: Player = main.player
	var w: Wolf = _alive_wolf()
	if w == null:
		_check("ha um lobo vivo para o golpe", false, "matilha=%d" % main.wolves.size())
		return
	_pause_for(p)
	p.hp = p.max_hp
	p.energy = p.max_energy
	# A premissa do passo e "jogador vivo, sem painel na frente, braco livre".
	# Os tres sao estado que a simulacao ao vivo deixa pelo caminho, e cada um
	# engole o clique: `update_local` retorna antes de mirar se o jogador caiu,
	# `_apply_actions` retorna se o painel esta aberto, e a cadencia de 0,42 s
	# adia o giro. Sem montar a premissa o passo mede a sorte -- a primeira
	# corrida de um clone limpo desta arvore deu 4 falhas com `em 30 ticks` e a
	# segunda, nada mudado, deu 0. `chegada` e o estado herdado, para a proxima
	# falha ja nascer explicada.
	var chegada := "vivo=%s painel=%s cad=%.2f" % [str(p.alive), str(p.panel_open),
			p._attack_cd]
	# Cada porta e fechada pela transicao do proprio jogo, nao por um campo
	# escrito a mao: `respawn_at` devolve hp, vigor, ar e o travamento de sprint
	# junto com `alive`, e `close_panel` so fecha se a pilha na mao tiver para
	# onde voltar -- forcar `panel_open = false` ali deixaria o painel visivel no
	# HUD com o jogador ja livre, estado que nenhum passo seguinte espera.
	if not p.alive:
		p.respawn_at(_spawn)
	if p.panel_open:
		p.close_panel()
	p._attack_cd = 0.0
	p.feet_to_spawn(_spawn)
	_aim(p, -0.35)
	w.hp = Wolf.MAX_HP
	w.body.feet_pos = _spawn + Vector3(0.0, 0.0, -2.5)
	w.body.velocity = Vector3.ZERO
	w._move_target = w.body.feet_pos
	# O resto da matilha sai da frente da mira. Com a arvore pausada os lobos
	# congelam onde a simulacao ao vivo os deixou, e a janela de 280 ticks do
	# passo de nado acaba com eles caçando o jogador: medido no clone de
	# 88d1c19, um lobo vivo a 1,6 m do olho contra 3,0 m do alvo colocado -- o
	# que salvou o golpe foi ele nao estar sobre o raio, por sorte. Como
	# `_update_target` pega o mais proximo ao longo da mira (`dp < best_d`),
	# sem isto o passo mediria a IA em vez do golpe, e vermelho intermitente
	# seria a assinatura: `hp` do alvo intacto, stagger 0, velocidade 0.
	for other in main.wolves:
		if other != w:
			other.body.feet_pos = _spawn + Vector3(0.0, 1.0, 8.0)
			other.body.velocity = Vector3.ZERO
	Input.action_press("break_block")
	p.update_local(1.0 / 60.0)
	_check("mira travada no lobo do passo", p._target_entity == w,
		("alvo=%s na_lista=%s d_alvo=%.2f  rival_mais_proximo=%.2f m") % [
			str(p._target_entity != null),
			str(main.targets_under_crosshair().has(w)),
			w.body.feet_pos.distance_to(p.eye_position()),
			_nearest_other_alive(p, w)])
	var n := 1
	while absf(w.hp - Wolf.MAX_HP) < 0.01 and n < 30:
		p.update_local(1.0 / 60.0)
		n += 1
	Input.action_release("break_block")
	_check("golpe acertou o lobo", absf(w.hp - Wolf.MAX_HP) > 5.0,
		("hp %.0f -> %.1f em %d ticks  chegada[%s]  alvo=%s  olho_a_alvo=%.2f m") % [
			Wolf.MAX_HP, w.hp, n, chegada,
			str(p._target_entity != null),
			p.eye_position().distance_to(w.body.feet_pos)])
	_check("dano do golpe e o ataque fixo",
		absf(w.hp - (Wolf.MAX_HP - Player.ATTACK_DAMAGE)) < 0.01, "hp=%.2f" % w.hp)
	_check("golpe atordoa o lobo", w._stagger > 0.0, "stagger=%.2f s" % w._stagger)
	_check("golpe empurra o corpo", w.body.velocity.length() > 3.0,
		"velocidade=%.2f m/s" % w.body.velocity.length())
	w.body.feet_pos = w.home + Vector3(0.0, 1.0, 0.0)
	w.body.velocity = Vector3.ZERO
	w._move_target = w.home
	w._stagger = 0.0
	_unpause_after(p)


func _check_roll() -> void:
	var p: Player = main.player
	var mid := false
	for e in InputMap.action_get_events("roll"):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_MIDDLE:
			mid = true
	_check("acao rolar no botao do meio", mid)
	var ctrl := false
	for e in InputMap.action_get_events("glide"):
		if e is InputEventKey and e.physical_keycode == KEY_CTRL:
			ctrl = true
	_check("acao planar no CTRL", ctrl)
	_pause_for(p)
	p.hp = p.max_hp
	p.energy = p.max_energy
	p.feet_to_spawn(_spawn)
	_aim(p, 0.0)
	# a borda do clique do meio e o mesmo caminho do clique direito (ja provado
	# pelo pipeline de place): aqui a mecanica entra pelo buffer direto
	p._roll_buffer = Player.ROLL_BUFFER
	p.update_local(1.0 / 60.0)
	var spd := Vector3(p.body.velocity.x, 0.0, p.body.velocity.z).length()
	_check("rolamento disparou e custou vigor",
		p._roll_time > 0.0 and absf(p.energy - (Player.MAX_ENERGY - Player.ROLL_COST)) < 0.05,
		"vigor=%.1f  janela=%.2f s" % [p.energy, p._roll_time])
	_check("impulso do rolamento no corpo", spd > 8.0, "velocidade=%.2f m/s" % spd)
	p.take_damage(10.0, p.position3())
	_check("janela de invencibilidade segura o golpe", p.hp == p.max_hp,
		"hp=%.1f  iframes=%.2f" % [p.hp, p._iframes])
	for i in 40:
		p.update_local(1.0 / 60.0)
	p.take_damage(10.0, p.position3())
	_check("fora da janela o golpe entra", absf(p.hp - (p.max_hp - 10.0)) < 0.01,
		"hp=%.1f" % p.hp)
	_unpause_after(p)


## A parede de pedra da o dreno sem atravessar o mapa: correr exige desejo e pe
## no chao, e a parede mantem os dois com o corpo parado.
func _check_energy() -> void:
	var p: Player = main.player
	var w: VoxelWorld = main.world
	_pause_for(p)
	p.hp = p.max_hp
	p.energy = p.max_energy
	p.feet_to_spawn(_spawn)
	_aim(p, 0.0)
	var base := Vector3i(floori(_spawn.x), floori(_spawn.y), floori(_spawn.z))
	var cells: Array[Vector3i] = []
	var orig: Array[int] = []
	for dx in [-1, 0, 1]:
		for dy in [0, 1, 2]:
			var c := base + Vector3i(dx, dy, -2)
			cells.append(c)
			orig.append(w.get_block(c))
			w.set_block(c, BlockDefs.Block.STONE)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	for i in 240:
		p.update_local(1.0 / 60.0)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	var drained := p.energy
	_check("correr drena o vigor", drained < Player.MAX_ENERGY - 15.0,
		"vigor=%.1f apos 4 s de corrida" % drained)
	for i in 120:
		p.update_local(1.0 / 60.0)
	_check("parado recupera o vigor", p.energy > drained + 15.0,
		"%.1f -> %.1f em 2 s" % [drained, p.energy])
	Input.action_press("sprint")
	Input.action_press("move_forward")
	p.energy = 0.4
	for i in 40:
		p.update_local(1.0 / 60.0)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	_check("vigor zerado trava a corrida", p._sprint_locked,
		"vigor=%.2f  trava=%s" % [p.energy, p._sprint_locked])
	p.energy = Player.SPRINT_RECOVERY + 12.0
	for i in 20:
		p.update_local(1.0 / 60.0)
	_check("vigor recuperado libera a corrida", not p._sprint_locked,
		"vigor=%.1f  trava=%s" % [p.energy, p._sprint_locked])
	for i in cells.size():
		w.set_block(cells[i], orig[i])
	_unpause_after(p)


func _check_glide_fall() -> void:
	var p: Player = main.player
	_pause_for(p)
	p.hp = p.max_hp
	p.energy = p.max_energy
	p.feet_to_spawn(_spawn + Vector3(0.0, 4.0, 0.0))
	p.yaw = 0.0
	p.pitch = -0.9
	Input.action_press("glide")
	var seen := false
	var min_vy := 0.0
	var max_hs := 0.0
	for i in 200:
		p.update_local(1.0 / 60.0)
		seen = seen or p.gliding
		min_vy = minf(min_vy, p.body.velocity.y)
		max_hs = maxf(max_hs, Vector3(p.body.velocity.x, 0.0, p.body.velocity.z).length())
		if i > 20 and p.body.on_ground:
			break
	Input.action_release("glide")
	var cap_dive := Player.GLIDE_SINK + 0.9 * Player.GLIDE_DIVE_SINK
	_check("planou segurando CTRL no ar", seen)
	_check("planar limita a queda", seen and min_vy >= -cap_dive - 0.05,
		"vy minimo=%.2f  cap do mergulho=%.2f" % [min_vy, cap_dive])
	_check("mergulhar ganha velocidade", seen and max_hs > 7.0,
		"hs maxima=%.2f m/s" % max_hs)
	_check("planar aterra sem dano de queda", p.hp == p.max_hp,
		"hp=%.1f  no chao=%s" % [p.hp, p.body.on_ground])
	p.feet_to_spawn(_spawn + Vector3(0.0, 12.0, 0.0))
	for i in 150:
		p.update_local(1.0 / 60.0)
		if p.body.on_ground:
			break
	var esperado: float = p.max_hp \
			- (sqrt(2.0 * p.body.gravity * 12.0) - Player.FALL_SAFE_SPEED) \
			* Player.FALL_DAMAGE_PER_SPEED
	_check("queda livre machuca", absf(p.hp - esperado) < 2.0,
		"hp=%.1f (esperado ~%.1f  gravidade=%.0f)" % [p.hp, esperado, p.body.gravity])
	_unpause_after(p)


func _check_breath() -> void:
	if _lake == Vector3i.ZERO:
		return
	var p: Player = main.player
	_pause_for(p)
	p.hp = p.max_hp
	p.energy = p.max_energy
	p.feet_to_spawn(Vector3(float(_lake.x) + 0.5, float(_lake.y) + 0.3, float(_lake.z) + 0.5))
	for i in 120:
		p.update_local(1.0 / 60.0)
	_check("submerso consome ar", p.air < Player.AIR_MAX - 0.5,
		"ar=%.2f s apos 2 s submerso" % p.air)
	p.air = 0.5
	for i in 240:
		p.update_local(1.0 / 60.0)
	_check("sem ar o afogamento machuca", p.hp < p.max_hp - 15.0,
		"hp=%.1f apos 4 s sem ar" % p.hp)
	p.feet_to_spawn(_spawn + Vector3(0.0, 1.0, 0.0))
	for i in 120:
		p.update_local(1.0 / 60.0)
	_check("fora da agua o ar enche", p.air >= Player.AIR_MAX - 0.01,
		"ar=%.2f s" % p.air)
	_unpause_after(p)


func _check_regen() -> void:
	var p: Player = main.player
	_pause_for(p)
	p.energy = p.max_energy
	p._since_damage = 20.0
	var hp0 := p.hp
	for i in 120:
		p.update_local(1.0 / 60.0)
	_check("regenera fora de combate", p.hp > hp0 + 1.5,
		"hp %.1f -> %.1f em 2 s" % [hp0, p.hp])
	p._since_damage = 0.0
	var hp1 := p.hp
	for i in 120:
		p.update_local(1.0 / 60.0)
	_check("combate recente trava a regeneracao", p.hp < hp1 + 0.05,
		"hp %.1f -> %.1f apos 2 s" % [hp1, p.hp])
	_unpause_after(p)


## Contrato do docs/design/04 (camada 5): sem llama-server o oraculo entra em
## recuo, a narrativa fica vazia e a utilidade/arvore seguem decidindo sozinhas.
## A porta 1 e fechada de proposito — deterministicas mesmo com um servidor
## real na maquina.
func _check_oracle_arm() -> void:
	_oracle_probe = MindOracle.new()
	_oracle_probe.name = "OracleProbe"
	_oracle_probe.roster_provider = Callable(main, "wolves_roster")
	add_child(_oracle_probe)


func _check_oracle() -> void:
	var oracle := _oracle_probe
	_oracle_probe = null
	var w: Wolf = _wolf_vivo(0)
	if w == null:
		_check("ha um lobo vivo para o oraculo", false, "matilha=%d" % main.wolves.size())
		oracle.queue_free()
		return
	_check("narrativa vazia sem servidor", oracle.narration_of(w.identity) == "",
		"narr='%s'" % oracle.narration_of(w.identity))
	_check("recuo global apos falha", oracle._server_cd > 0.0,
		"recuo=%.1f s" % oracle._server_cd)
	_check("mente segue decidindo sem narrador", w.mind != null and w.intent != "",
		"intento=%s" % w.intent)
	oracle.queue_free()


## Premissa da decisao 4.4 (dossie 15), ajustada ao §6.3 do dossie 22: com um
## dono de pack no processo, o portao segura o pedido enquanto o pack nao chega
## ao estado de fila. Os caminhos falsos garantem que o runtime nunca chega a
## tocar a ponte: nem disco, nem pack, nem VRAM.
func _check_llm_gate_arm() -> void:
	_gate_host = AfMindRuntime.new()
	_gate_host.name = "GateHost"
	_gate_host.runtime_path = "res://.tools/sem-runtime-22"
	_gate_host.model_path = "res://models/sem-modelo-22.gguf"
	add_child(_gate_host)
	_gate_oracle = MindOracle.new()
	_gate_oracle.name = "GateOracle"
	_gate_oracle.roster_provider = Callable(main, "wolves_roster")
	_gate_oracle.ready_provider = Callable(_gate_host, "ready")
	add_child(_gate_oracle)


func _check_llm_gate_closed() -> void:
	_check("runtime sem pack nao emite chamada na ponte",
			_gate_host.requests_issued == 0 and _gate_host.state == _gate_host.NO_RUNTIME,
			"estado=%s  chamadas=%d" % [_gate_host.state, _gate_host.requests_issued])
	_check("portao fechado: oraculo nao emite pedido", _gate_oracle.requests_issued == 0,
			"pedidos=%d  recuo=%.1f s" % [_gate_oracle.requests_issued, _gate_oracle._server_cd])
	# Sentido oposto no mesmo par de passos (regra 3 do ciclo): sem o portao aberto
	# o pedido ate sai, entao o zero acima nao e o oraculo quebrado.
	_gate_host.state = _gate_host.READY
	# As metricas de trabalho do §2.4 (dossie 22) na linha do F3: fila, pior
	# decode e taxa de cache. Nesta suite a ponte nao tem pack (o modelo e de
	# 2,7 GB e headless nao carrega), entao os numeros honestos sao -1 — numero
	# ausente NOMEADO, nunca um 0 que parece leitura (§7.2).
	var linha_f3 := _gate_host.status_line()
	_check("F3 de pronto traz fila, decode e cache", linha_f3.contains("fila")
			and linha_f3.contains("decode") and linha_f3.contains("cache"),
			"linha='%s'" % linha_f3)
	var d_f3: Dictionary = _gate_host.diagnostics()
	_check("diagnostics expoe as chaves da ponte", d_f3.has("queue_depth")
			and d_f3.has("worst_decode_us") and d_f3.has("cache_hits")
			and d_f3.has("cache_misses"),
			"fila=%d decode_us=%d cache=%s/%s" % [
				int(d_f3.get("queue_depth", 0)), int(d_f3.get("worst_decode_us", 0)),
				str(d_f3.get("cache_hits", "?")), str(d_f3.get("cache_misses", "?"))])


func _check_llm_gate_open() -> void:
	_check("portao aberto volta a pedir", _gate_oracle.requests_issued > 0,
			"pedidos=%d  motivo=%s" % [_gate_oracle.requests_issued, _gate_oracle.last_reason])


## Contra-prova do ramo de recusa: a fila da ponte recusa com o motivo NOMEADO
## ("fila recusou o pedido: ..."), e a suíte segue com o recuo cheio armado —
## os dois numeros abaixo sao o que sobra quando o ramo chega ao fim.
func _check_llm_backoff() -> void:
	_check("recusa da fila nomeia o motivo", _gate_oracle.last_reason.contains("recusou"),
			"motivo=%s  status=%d" % [_gate_oracle.last_reason, _gate_oracle.last_status])
	_check("recusa da fila arma o recuo cheio", _gate_oracle._server_cd > 20.0,
			"recuo=%.1f s  teto=%.0f s" % [_gate_oracle._server_cd, MindOracle.RETRY_COOLDOWN])
	_gate_oracle.queue_free()
	_gate_host.queue_free()


## Derivacao entre linguagem: o lancador e o oraculo nao partilham uma string de
## chave — partilham as duas FONTES: o ambiente `AETHERFALL_MIND_KEY` e o
## `mind_key.txt` da pasta de dados nomeada por `application/config/name`.
func _check_llm_key_drift() -> void:
	var f := FileAccess.open("res://tools/run_mind_server.ps1", FileAccess.READ)
	if f == null:
		_check("chave do servidor bate com a do oraculo", false,
				"sem tools/run_mind_server.ps1 nesta arvore")
		return
	var src := f.get_as_text()
	var app := str(ProjectSettings.get_setting("application/config/name"))
	var ok := src.contains(MindOracle.KEY_ENV) and src.contains("mind_key.txt")
	ok = ok and src.contains(app) and src.contains("--api-key") and MindOracle.resolve_api_key() != ""
	_check("chave do servidor bate com a do oraculo", ok,
			"fontes_lidas=%s  pasta=%s  origem=%s" % [ok, app, MindOracle.key_source])


## Um braco do experimento. A posicao, o hp, o campo de Eter ao redor e a ameaca
## sao identicos em todos os bracos (reset acima); o que muda e apenas o registro
## na mente:
##   ARM_NONE     crencia apagada
##   ARM_WOUND    dano real do jogador (percepcao grava a crencia sozinha)
##   ARM_REMEMBER crencia gravada pelo mesmo delta que a percepcao usa
## Depois de ARM_STEPS decisoes mede a intengao, o veto da opcao hunt e para onde
## a arvore de comportamento mandou o lobo.
func _run_arm(w: Wolf, spot: Vector3, half: float, t: float, mode: int) -> Dictionary:
	var p: Player = main.player
	_reset_arm(w, p, spot, half)
	w.intent = "patrol"
	w.mind.beliefs.erase(BELIEF)
	match mode:
		ARM_WOUND:
			w.take_damage(9.0, Wolf.ACTOR_PLAYER, p.position3())
			w.take_damage(9.0, Wolf.ACTOR_PLAYER, p.position3())
			w.hp = half
			w._threat = 0.0
			_wipe_field(w)
		ARM_REMEMBER:
			w.mind.reinforce(BELIEF, 0.3, "perception")
			w.mind.reinforce(BELIEF, 0.3, "perception")
	for i in ARM_STEPS:
		w.sim_step(t + float(i) * DT_SIM, DT_SIM)
	var bd: Dictionary = w._scorer.breakdown()
	var target: Vector3 = w._move_target
	return {
		"intent": w.intent,
		"hunt_vetoed": bool(bd["hunt"]["vetoed"]),
		"hunt_score": float(bd["hunt"]["score"]),
		"chasing": target.distance_to(p.position3()) < 1.5,
		"dist": w.center().distance_to(p.position3()),
	}


func _reset_arm(w: Wolf, p: Player, spot: Vector3, half: float) -> void:
	w.body.feet_pos = spot
	w.body.velocity = Vector3.ZERO
	w.hp = half
	w._threat = 0.0
	w._saw_cd = 0.0
	w._bite_cd = 0.0
	w._wander_cd = 0.0
	w._move_target = spot
	# home longe do jogador: assim o alvo de patrulha nunca pode ser confundido
	# com estar caçando o jogador.
	w.home = spot + (spot - p.position3()).normalized() * 40.0
	p.yaw = 0.0
	p.pitch = 0.0
	_wipe_field(w)


## Limpa os tres canais num raio maior que o raio de faro do lobo, para que os
## bracos comecem exatamente com o mesmo ar.
func _wipe_field(w: Wolf) -> void:
	var a: AetherField = main.aether
	var c0 := a.cell_of_world(w.center())
	for dy in range(-2, 3):
		for dz in range(-4, 5):
			for dx in range(-4, 5):
				var c := c0 + Vector3i(dx, dy, dz)
				a.set_cell_value(c, AetherField.Channel.FEAR, 0.0)
				a.set_cell_value(c, AetherField.Channel.BLOOD, 0.0)
				a.set_cell_value(c, AetherField.Channel.WORK, 0.0)


func _experiment_spot(w: Wolf, p: Player) -> Vector3:
	for dist in [10.0, 12.0, 8.0, 14.0]:
		for dirv in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var dir: Vector3 = dirv
			var radius: float = dist
			var cand: Vector3 = p.position3() + dir * radius
			var y: int = main.world.surface_height(int(cand.x), int(cand.z)) + 1
			var pos := Vector3(cand.x, float(y), cand.z)
			w.body.feet_pos = pos
			if y <= VoxelConfig.SEA_LEVEL:
				continue
			var from := pos + Vector3(0.0, Wolf.DIMS.y * 0.5, 0.0)
			var to := p.position3() + Vector3(0.0, 0.9, 0.0)
			if main.world.line_of_sight(from, to):
				return pos
	return Vector3.INF


# --------------------------------------------------------------------- hud

func _check_hud() -> void:
	var hud = main.hud
	var p: Player = main.player
	_check("hotbar com 10 pinos no hud", hud._slots.size() == Inventory.HOTBAR,
		"slots=%d" % hud._slots.size())
	_check("painel com 36 celulas", hud._cells.size() == Inventory.SLOTS \
		and Inventory.ROWS * Inventory.COLS == Inventory.SLOTS,
		"celulas=%d" % hud._cells.size())
	# O painel abre por sinal do jogador, nao por decisao do HUD: quem abre e o
	# `toggle_inventory` do Player, o HUD so empresta a visibilidade.
	p._set_panel(true)
	_check("abrir o inventario mostra o painel", hud.panel_visible() and p.panel_open)
	_check("cabecalho mostra a contagem real", String(hud._head_label.text).contains("INVENTARIO") \
		and String(hud._head_label.text).contains(str(p.inv.item_count())),
		"'%s'" % hud._head_label.text)
	_check("quantidade aparece na celula do slot",
		(hud._cells[0]["ct"] as Label).text == str(p.inv.slot_count(0)),
		"celula0='%s'  slot0=%d" % [(hud._cells[0]["ct"] as Label).text, p.inv.slot_count(0)])
	# Sem bancada por perto a lista encolhe: e o filtro por estacao do Veloren (o
	# sprite a 5,0 m) aplicado ao bloco de bancada.
	_check("sem bancada so mostra as receitas de mao", not p.bench_near() \
		and Recipes.visible(false).size() < Recipes.list().size() \
		and String(hud._head_label.text).contains("sem bancada"),
		"visiveis=%d de %d" % [Recipes.visible(false).size(), Recipes.list().size()])
	p._set_panel(false)
	_check("fechar o inventario esconde o painel", not hud.panel_visible() and not p.panel_open)
	_check("overlay de morte comecou escondido", not hud._death.visible)
	# O painel de binds agora abre sozinho no spawn (o `DIR colocar` nao aparece em
	# lugar nenhum ate o jogador achar o botao direito) e fecha sozinho. Testado
	# pelo mecanismo, nao pelo estado do boot: o estado do boot depende de quanto
	# tempo de relogio ja passou desde o _ready do main.
	hud.preview_binds(0.5)
	_check("previsa de binds abre o painel", hud._binds.visible and hud._binds_cd > 0.0,
		"visivel=%s  cd=%.2f" % [hud._binds.visible, hud._binds_cd])
	hud._process(0.6)
	_check("previsa de binds fecha sozinha", not hud._binds.visible)
	p.toggle_debug.emit()
	_check("F3 via sinal liga o debug", hud.debug_visible())
	hud._process(0.2)
	var dbg := String(hud._debug.text)
	_check("debug mostra a decisao de IA", dbg.contains("lobo0") and dbg.contains("bt "),
		"%d linhas" % dbg.split("\n").size())
	_check("debug mostra o relogio", dbg.contains("tick"), "linhas=%d" % dbg.split("\n").size())
	p.toggle_debug.emit()
	_check("F3 via sinal desliga o debug", not hud.debug_visible())
	hud.preview_binds(0.5)
	hud.show_binds(true)
	_check("F2 abre o painel de binds", hud._binds.visible and dbg.length() > 0)
	hud._process(0.6)
	_check("F2 pinha o painel contra a previsa", hud._binds.visible, "cd=%.2f" % hud._binds_cd)
	hud.show_binds(false)

	var d0 := int(main.stats["deaths"])
	var blood0: float = main.aether.channel_totals()[AetherField.Channel.BLOOD]
	p.take_damage(1000.0, Vector3.ZERO)
	_check("dano letal mata", not p.alive and p.hp <= 0.0, "hp=%.1f" % p.hp)
	_check("overlay de morte apareceu", hud._death.visible)
	_check("contador de mortes", int(main.stats["deaths"]) == d0 + 1, "mortes=%d" % main.stats["deaths"])
	var blood1: float = main.aether.channel_totals()[AetherField.Channel.BLOOD]
	_check("morte imprinta sangue no eter", blood1 > blood0, "%.3f -> %.3f" % [blood0, blood1])
	main.respawn()
	_check("renascer devolve a vida", p.alive and p.hp >= p.max_hp, "hp=%.1f" % p.hp)
	_check("overlay some ao renascer", not hud._death.visible)
	_check("renascer no ponto de spawn",
		p.body.feet_pos.distance_to(_spawn) < 2.0, "feet=%s" % p.body.feet_pos)


# --------------------------------------------------------------------- save

func _check_save() -> void:
	var w: VoxelWorld = main.world
	var p: Player = main.player
	var wolf0: Wolf = _wolf_vivo(0)
	if wolf0 == null:
		_check("ha um lobo vivo para o save", false, "matilha=%d" % main.wolves.size())
		return
	# Dossie 11 §5, cena do censo: para o disco ter MAIS bichos do que a matilha
	# viva de uma sessao nova, a populacao tem de variar. A porta e a da sessao
	# (`_spawn_wolves`, a mesma que o filhote do cenario 1 vai usar -- dossie 11
	# §3.4 poe o nascimento na sessao e nao no lobo), porque um lobo inventado por
	# um dicionario escrito a mao nao provaria nada contra o load.
	var censo_antes: int = main.wolves.size()
	main._spawn_wolves(1)
	_check("a porta de povoamento da sessao abre um bicho novo",
			main.wolves.size() == censo_antes + 1,
			"censo %d -> %d  WOLF_COUNT=%d (o teto de censo e outro numero)" % [
			censo_antes, main.wolves.size(), main.WOLF_COUNT])
	# (20,20) de proposito: as 16 colunas amostradas no boot incluem (12,12), e uma
	# edicao ali faria o "relevo identico apos carregar" comparar contra si mesmo.
	var extra := Vector3i(20, w.surface_height(20, 20) + 4, 20)
	w.set_block(extra, BlockDefs.Block.WOOD)
	var before := {
		"edits": w.edits.size(), "tick": int(main.clock.tick), "hp": p.hp,
		"feet": p.body.feet_pos, "pitch": p.pitch, "yaw": p.yaw,
		"wolf_hp": wolf0.hp, "wolf_mem": wolf0.mind.episodic.size(),
		"wolf_belief": wolf0.mind.belief(BELIEF), "wolf_trust": wolf0.mind.trust(Wolf.ACTOR_PLAYER),
		"inv": _inv_signature(p), "items": p.inv.item_count(),
	}
	var before_feet: Vector3 = before["feet"]
	main.save_game()
	_check("slot escrito", SaveManager.has_slot(SLOT), "caminho=%s" % SaveManager.slot_path(SLOT))
	_check("sem .tmp sobrando", not FileAccess.file_exists(SaveManager.tmp_path(SLOT)))
	var rd := SaveManager.read_slot(SLOT)
	_check("leitura do slot", bool(rd["ok"]), "%.1f ms" % rd["ms"])
	var data: Dictionary = rd["data"]
	_check("schema e gen_version gravados",
		int(data["schema"]) == SaveManager.SCHEMA and int(data["gen_version"]) == WorldGen.GEN_VERSION,
		"schema=%d  gen=%d" % [data["schema"], data["gen_version"]])
	var f := FileAccess.open(SaveManager.slot_path(SLOT), FileAccess.READ)
	var bytes := f.get_length()
	f.close()
	_check("save com corpo", bytes > 1000, "%d bytes" % bytes)
	_check("save guarda o diario, nao os voxels",
		int(data["edits"].size()) == before["edits"], "edicoes=%d" % data["edits"].size())
	# `inv` e aditivo no mesmo schema: um save antigo nao tem a chave e o load cai
	# no kit, um save novo tem as 36 pilhas, os 10 pinos e a tecla ativa.
	var inv_saved: Dictionary = data.get("inv", {})
	_check("save guarda as pilhas e os pinos",
		int(inv_saved.get("slots", []).size()) > 0 \
		and (inv_saved.get("pins", []) as Array).size() == Inventory.HOTBAR,
		"slots=%d  pins=%d" % [inv_saved.get("slots", []).size(),
			(inv_saved.get("pins", []) as Array).size()])
	main.save_game()
	_check("segunda escrita sobrescreve atomicamente", bool(SaveManager.read_slot(SLOT)["ok"]),
		"%d bytes" % bytes)

	var after_extra := Vector3i(30, w.surface_height(30, 30) + 4, 30)
	w.set_block(after_extra, BlockDefs.Block.SNOW)
	p.take_damage(20.0, Vector3.ZERO)
	wolf0.take_damage(10.0, Wolf.ACTOR_PLAYER, p.position3())
	p.feet_to_spawn(_spawn + Vector3(4.0, 0.0, 4.0))
	# Inventario mutado de proposito junto com o resto: gasta a pilha da tecla
	# ativa, recebe um bloco novo e troca de tecla. Nada disso voltaria se o load
	# ignorasse a chave `inv`.
	p.inv.consume_selected(3)
	p.inv.add(BlockDefs.Block.GLASS, 5)
	p.inv.select(6)
	_check("mundo foi mutado de proposito",
		w.edits.size() == before["edits"] + 1 and wolf0.hp != before["wolf_hp"],
		"edicoes=%d  hp lobo=%.1f" % [w.edits.size(), wolf0.hp])
	_check("inventario foi mutado de proposito",
		_inv_signature(p) != String(before["inv"]), "assinatura mudou")
	main.load_game()
	_check("diario de edicoes restaurado", w.edits.size() == int(before["edits"]),
		"%d -> %d" % [w.edits.size(), before["edits"]])
	_check("edicao pos-save desfeita",
		w.get_block(after_extra) == BlockDefs.Block.AIR, "voxel=%s" % after_extra)
	_check("edicao pre-save mantida",
		w.get_block(extra) == BlockDefs.Block.WOOD, "voxel=%s" % extra)
	var same := true
	for k in _heights:
		var parts: PackedStringArray = String(k).split(",")
		if main.world.surface_height(int(parts[0]), int(parts[1])) != int(_heights[k]):
			same = false
	_check("relevo identico apos carregar", same, "16 colunas")
	_check("jogador no lugar de antes",
		p.body.feet_pos.distance_to(before_feet) < 0.01,
		"feet=%s" % p.body.feet_pos)
	_check("camera restaurada", is_equal_approx(p.pitch, float(before["pitch"]))
		and is_equal_approx(p.yaw, float(before["yaw"])), "pitch=%.2f" % p.pitch)
	_check("vida do jogador restaurada", is_equal_approx(p.hp, float(before["hp"])), "hp=%.1f" % p.hp)
	_check("tick restaurado", int(main.clock.tick) == int(before["tick"]), "tick=%d" % main.clock.tick)
	_check("memoria do lobo voltou",
		wolf0.mind.episodic.size() == int(before["wolf_mem"])
		and is_equal_approx(wolf0.mind.trust(Wolf.ACTOR_PLAYER), float(before["wolf_trust"])),
		"episodios=%d  confianca=%.2f" % [wolf0.mind.episodic.size(), wolf0.mind.trust(Wolf.ACTOR_PLAYER)])
	_check("hp do lobo voltou", is_equal_approx(wolf0.hp, float(before["wolf_hp"])), "hp=%.1f" % wolf0.hp)
	_check("inventario restaurado pilha por pilha",
		_inv_signature(p) == String(before["inv"]) and p.inv.item_count() == int(before["items"]),
		"itens=%d->%d" % [p.inv.item_count(), before["items"]])


## Assinatura das 36 pilhas, dos 10 pinos e da tecla ativa. Comparar a assinatura
## em vez de um total pega pilha movida e hotbar reordenada, que um `item_count`
## identico esconderia.
func _inv_signature(p: Player) -> String:
	var parts: Array = []
	for i in Inventory.SLOTS:
		parts.append("%d:%d" % [p.inv.slot_block(i), p.inv.slot_count(i)])
	for k in Inventory.HOTBAR:
		parts.append("p%d" % p.inv.pin_of(k))
	parts.append("s%d" % p.inv.hotbar_index)
	return ",".join(parts)


# --------------------------------------------------------------------- ciclo de vida

func _check_corpse() -> void:
	var w: Wolf = _alive_wolf()
	if w == null:
		_check("ha um lobo vivo para abater", false, "matilha=%d" % main.wolves.size())
		return
	_corpse_n = main.wolves.size()
	var felled0 := int(main.stats["wolves_felled"])
	var blood0: float = main.aether.channel_totals()[AetherField.Channel.BLOOD]
	var fear0: float = main.aether.channel_totals()[AetherField.Channel.FEAR]
	w.die()
	_check("morte contabilizada", int(main.stats["wolves_felled"]) == felled0 + 1,
		"abatidos=%d" % main.stats["wolves_felled"])
	_check("ainda na matilha (tempo de cadaver)", main.wolves.size() == _corpse_n,
		"cadaver=%.1f s" % Wolf.CORPSE_SECONDS)
	_check("lobo morto nao decide", not w.alive and w.intent == "morto", "intencao=%s" % w.intent)
	var b: Array = main.aether.channel_totals()
	_check("morte imprinta sangue e medo no eter",
		b[AetherField.Channel.BLOOD] > blood0 and b[AetherField.Channel.FEAR] > fear0,
		"blood=%.2f  fear=%.2f" % [b[AetherField.Channel.BLOOD], b[AetherField.Channel.FEAR]])


func _check_reap() -> void:
	var n: int = main.wolves.size()
	_check("cadaver recolhido da matilha", n == _corpse_n - 1, "%d -> %d lobos" % [_corpse_n, n])
	var d: Dictionary = main.diagnostics()
	_check("reposicao enfileirada", int(d["pending_respawns"]) == 1,
		"na fila=%d  vivos=%d" % [d["pending_respawns"], d["wolves_alive"]])
	_check("sem no de malha sobrando", main.get_node("Terrain").get_child_count() == 64,
		"nos=%d" % main.get_node("Terrain").get_child_count())
	_check("nenhum tick perdido no teste inteiro", int(d["dropped_ticks"]) == 0,
		"perdidos=%d  pior passo=%.2f ms  tick=%d" % [
			d["dropped_ticks"], d["worst_sim_ms"], d["tick"]])
	# Checagem 7 do dossie 16 §5, posta no unico caminho onde os dois numeros dela
	# podem falhar: `dropped_ticks` so existe se `clock.advance()` estourar o teto de
	# 5 passos por frame (sim_clock.gd:23-26), e quem chama `advance` e o
	# `_physics_process` da sessao. Num laco de `_sim_tick()` chamado a mao -- como o
	# braco de colheita do runner -- o contador fica 0 por construcao e a assercao nao
	# decidia nada. Aqui a sessao medida e a real deste teste, com as tocas do boot,
	# entao a testemunha do espalhamento vai DENTRO do criterio: sem >= 2 tocas e >= 2
	# componentes, o numero nao seria do espalhamento, e a regua de 25 ms e a mesma
	# dos dossies 17 e 19, nao um numero escolhido para passar.
	_check("espalhamento_nao_estoura_o_passo",
		int(d["dropped_ticks"]) == 0 and float(d["worst_sim_ms"]) <= 25.0
			and int(d["dens"]) >= 2 and int(d["den_components"]) >= 2,
		"perdidos=%d  pior passo=%.2f ms (regua 25)  dens=%d componentes=%d separacao=%s m  tick=%d" % [
			d["dropped_ticks"], d["worst_sim_ms"], int(d["dens"]),
			int(d["den_components"]),
			"sem_par" if float(d["den_min_dist"]) < 0.0 else "%.1f" % float(d["den_min_dist"]),
			d["tick"]])
	_check("lobos seguem vivos e decidindo", int(d["wolves_alive"]) >= 3,
		"vivos=%d  triangulos=%d" % [d["wolves_alive"], d["triangles"]])
	print("       diagnostico final: ", JSON.stringify(d))


## Checagem 5 do dossie 11 §5 (`load_leva_todo_o_censo`), e nasce VERMELHA por
## projeto: o contrato (AGENTS.md ciclo 3, dossie 11 §3.6) quer o furo impresso
## antes do conserto, nao um conserto antecipado que faria o verde dizer pouco.
##
## A premissa e montada por transicoes reais, nenhuma delas escrita a mao: o passo
## `salvar e carregar` abriu o sexto bicho pela porta de povoamento da sessao e
## gravou o disco com seis; depois dai a matilha viva so encolheu pela unica porta
## que existe para isso -- a recolha de cadaver do passo anterior. Um load que
## pareia por indice (`mini(saved.size(), wolves.size())`) devolve quantos lobos a
## sessao ja tinha e joga o resto do disco fora em silencio: e o exato numero que
## faz o censo nao ser variavel de mundo (dossie 11 §2, premissa 1).
func _check_censo_disk() -> void:
	var rd := SaveManager.read_slot(SLOT)
	var saved: Array = (rd["data"] as Dictionary).get("wolves", [])
	var ids_disco := ""
	var chaves_ok := true
	for e: Dictionary in saved:
		ids_disco += "%d " % int(e["identity"])
		if not e.has("phase") or not e.has("age_ticks"):
			chaves_ok = false
	var ids_antes := ""
	var n_antes: int = main.wolves.size()
	for w: Wolf in main.wolves:
		ids_antes += "%d " % w.identity
	main.load_game()
	var d: Dictionary = main.diagnostics()
	var ids_vivos := ""
	var mentes := ""
	var mente_ok := true
	var fases_ok := true
	var fases_vivas := ""
	for w: Wolf in main.wolves:
		ids_vivos += "%d " % w.identity
		fases_vivas += "%d:%s/%d " % [w.identity, w.phase_name(), w.age_ticks]
		# A identidade da mente e a do bicho tem de bater: se o pareamento for por
		# posicao do array, o lobo 1 acorda com a memoria do lobo 0 e o journal
		# passa a hash de um no corpo do outro -- e e a mente que o disco traz.
		if int(w.mind.identity) != w.identity:
			mente_ok = false
		mentes += "%d<-%d " % [w.identity, int(w.mind.identity)]
		for e: Dictionary in saved:
			if int(e["identity"]) != w.identity:
				continue
			if int(w.phase) != int(e["phase"]) or int(w.age_ticks) != int(e["age_ticks"]):
				fases_ok = false
	var fila := int(d["pending_respawns"])
	# A lista de chaves e lida do proprio disco, nao digitada aqui: ela ja estava
	# velha (`mate_cd` entrou na perna 11 e nada reprintou a linha), e um rotulo
	# escrito a mao e justamente o tipo de citacao que o ciclo 7 manda re-derivar.
	var chaves_disco := ""
	if saved.size() > 0:
		for k: String in (saved[0] as Dictionary).keys():
			chaves_disco += k + ","
	_check("o save carrega fase e idade como chaves aditivas", chaves_ok,
			"bichos_no_disco=%d chaves=%s  ids=[%s]" % [
			saved.size(), chaves_disco, ids_disco.strip_edges()])
	_check("censo do disco carrega inteiro (load_leva_todo_o_censo)",
			int(d["wolves"]) == saved.size(),
			"disco=%d antes=%d depois=%d  disco_ids=[%s] vivo_ids=[%s]" % [
			saved.size(), n_antes, int(d["wolves"]), ids_disco.strip_edges(),
			ids_vivos.strip_edges()])
	_check("cada identidade do disco confere com a mente carregada", mente_ok,
			"antes=[%s] agora=[%s] mentes=[%s]" % [
			ids_antes.strip_edges(), ids_vivos.strip_edges(), mentes.strip_edges()])
	_check("fase e idade do disco voltam para o bicho certo", fases_ok,
			"vivos=[%s]" % fases_vivas.strip_edges())
	_check("a fila de reposicao nao inventa bicho fora do censo gravado", fila == 0,
			"fila=%d  disco=%d  vivos=%d" % [fila, saved.size(), int(d["wolves"])])
	# Checagem 9 do dossie 16 §5: a toca e LUGAR, e lugar e estado da sessao -- se o
	# disco nao o devolve, o load fundaria tocas novas sobre colunas que ja tem dono
	# e o bicho carregado acordaria sem toca num mapa com tres lugares gravados. Os
	# dois numeros saem da mesma leitura: o `dens` gravado contra o `_dens`
	# restaurado, com a derivacao do round-trip JSON impressa (e o unico motivo
	# plausivel para um centro voltar torto, e `home`/`feet` dos bichos ja fazem o
	# mesmo caminho), e o `den` de cada entrada do disco contra o `den` do bicho de
	# mesma identidade -- que e exatamente onde o pareamento por indice mentiria.
	var data_disco: Dictionary = rd["data"]
	var dens_disco: Array = data_disco.get("dens", [])
	var maior_derivacao := 0.0
	var centros := ""
	for i in mini(main._dens.size(), dens_disco.size()):
		var um_centro: Array = dens_disco[i]
		maior_derivacao = maxf(maior_derivacao, main._dens[i].distance_to(
				Vector3(float(um_centro[0]), float(um_centro[1]), float(um_centro[2]))))
		centros += "(%.1f,%.1f) " % [main._dens[i].x, main._dens[i].z]
	var den_do_disco := {}
	for e: Dictionary in saved:
		den_do_disco[int(e["identity"])] = int(e.get("den", -99))
	var pertencas_ok := true
	var pertencas := ""
	for w: Wolf in main.wolves:
		var no_disco: int = int(den_do_disco.get(w.identity, -98))
		if int(w.den) != no_disco:
			pertencas_ok = false
		pertencas += "lobo%d(toca=%d do disco=%d) " % [w.identity, w.den, no_disco]
	_check("tocas e pertenca sobrevivem ao save (toca_sobrevive_ao_save)",
			main._dens.size() == dens_disco.size() and dens_disco.size() >= 2
			and pertencas_ok and maior_derivacao < 0.01,
			"dens disco=%d carregadas=%d  maior_derivacao=%.6f m  separacao=%s m  centros=[%s]  pertencas=[%s]" % [
			dens_disco.size(), main._dens.size(), maior_derivacao,
			"sem par" if float(d["den_min_dist"]) < 0.0 else "%.1f" % float(d["den_min_dist"]),
			centros.strip_edges(), pertencas.strip_edges()])
	# A segunda metade do §5.9, que e para o que o padrao aditivo existe: o MESMO
	# disco, sem as duas chaves que a perna acrescentou -- um save anterior a perna
	# -- carrega com default DERIVADO. Nenhuma transicao do jogo produz um save de
	# antes, entao o palco e o proprio JSON que o jogo gravou com as chaves
	# removidas, num Dictionary parseado de novo para nao tocar no `data_disco` da
	# checagem de cima. Nada mais muda: a comparacao e A/B do leitor, nao do mundo,
	# e `load_leva_todo_o_censo` continua sendo a mesma conta com o disco velho.
	var velho: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(SaveManager.slot_path(SLOT)))
	velho.erase("dens")
	for e: Dictionary in velho.get("wolves", []):
		e.erase("den")
	var res_v := SaveManager.write_slot(SLOT, velho)
	main.load_game()
	var d_velho: Dictionary = main.diagnostics()
	var sem_toca := true
	var ids_velho := ""
	for w: Wolf in main.wolves:
		if int(w.den) != -1:
			sem_toca = false
		ids_velho += "%d " % w.identity
	_check("default derivado: disco sem a chave nao toca nem inventa",
			bool(res_v["ok"]) and int(d_velho["dens"]) == 0 and sem_toca
			and main.wolves.size() == saved.size(),
			"dens=%d  todos_em_sem_toca=%s  disco=%d carregados=%d  ids=[%s]  escrita=%s" % [
			int(d_velho["dens"]), sem_toca, saved.size(), main.wolves.size(),
			ids_velho.strip_edges(),
			"ok" if bool(res_v["ok"]) else String(res_v["error"])])
	# O slot volta ao formato que o proprio jogo escreve. Nao re-load: esta e a
	# ultima checagem do ultimo passo, nada le a sessao depois dela, e recarregar
	# custaria os ~5,2 s de geracao + malharia medidos no boot por nenhum numero
	# novo. A restauracao e impressa porque um slot podre aqui envenena a proxima
	# sessao do dono.
	var restaurada := SaveManager.write_slot(SLOT, data_disco)
	print("       disco restaurado no formato atual: %s %d bytes" % [
			"ok" if restaurada["ok"] else String(restaurada["error"]), restaurada["bytes"]])
