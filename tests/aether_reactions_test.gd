extends SceneTree

const Session = preload("res://src/main.gd")
const SEED: int = 20261116
# O MESMO pino do molde (`simulation_rng_test.gd:75`): o numero nao e uma
# preferencia, e a fita global onde o par `randi()` de antes / `randi()` de depois
# e conferido. Troca-lo nao troca o que a checagem decide.
const RNG_PIN: int = 7301
const SPAWN := Vector3(58.0, 51.001, 62.0)
const SOURCE := Vector3(66.0, 50.6, 62.0)
const FAR_PLAYER := Vector3(112.0, 51.001, 112.0)
const TESTS: Array[StringName] = [
	&"_test_fixture", &"_test_work_approach", &"_test_weighted_traces",
	&"_test_fear_ab", &"_test_unseen", &"_test_last_sighting",
	&"_test_work_cycle", &"_test_blood_cycle", &"_test_fear_interrupt",
	&"_test_work_diffusion", &"_test_cache_expiry", &"_test_fear_no_feedback",
	&"_test_last_hurt_ab", &"_test_sighting_expiry",
	&"_test_dead_prey", &"_test_inspection_hit", &"_test_place_renewal", &"_test_cache_cap",
	&"_test_locomotion_flat", &"_test_locomotion_wall",
	&"_test_degrau_de_um_bloco_lobo_sobe",
	&"_test_degrau_de_um_bloco_jogador_sobe_sem_tecla", &"_test_agachado_nao_e_arremessado",
	&"_test_predicado_degrau_recusa_teto_baixo",
	&"_test_pulo_nao_custou_passo_de_ninguem",
	&"_test_scent_cave_layer",
	&"_test_biome", &"_test_fur_colour", &"_test_imprint_bias", &"_test_pack_provider",
	&"_test_rondar_setor", &"_test_cercar_assentos", &"_test_ataque_escalonado",
	&"_test_contagio_medo", &"_test_amortece_confianca",
	&"_test_lobo_escolhe_trilha_seca", &"_test_nadar_so_sem_saida_seca",
	&"_test_resgate_de_margem_sobrevive_a_arvore",
	&"_test_dois_lobos_nao_farejam_a_mesma_celula", &"_test_alvo_estavel_por_segundo",
	&"_test_spawn_fora_da_vista_do_jogador",
	&"_test_nenhum_aviso_de_matilha_no_hud", &"_test_feedback_do_jogador_continua_no_hud",
	&"_test_filhote_cresce_por_tick",
	&"_test_acasalar_aumenta_censo", &"_test_cooldown_segunda_copula",
	&"_test_censo_respeita_teto", &"_test_filhote_nao_morde",
	&"_test_journal_hash_inalterado_sem_escolha",
	&"_test_tocas_distintas_no_boot", &"_test_nenhum_lobo_le_de_outra_toca",
	&"_test_cada_toca_e_um_lugar_valido", &"_test_toca_nao_deriva_para_unica",
	&"_test_reposicao_volta_para_a_toca_perdida",
	&"_test_nascimento_fica_na_toca_dos_pais",
	&"_test_espalhamento_nao_estoura_o_passo",
	&"_test_lobo_cava_sem_input_do_jogador",
	&"_test_cavar_respeita_a_lista", &"_test_cavar_nao_toca_construcao_alheia",
	&"_test_abrir_passagem_depois_de_bloqueio",
	&"_test_work_de_bicho_nao_confundido",
	&"_test_entrada_de_rastro_exposta_no_chao_lido",
	&"_test_cavar_nao_consome_rng_da_sessao",
	&"_test_colheita_de_malha_sem_cavar",
	&"_test_cavar_sobrevive_ao_save", &"_test_extensao_carrega_classe",
	&"_test_extensao_pack_no_processo", &"_test_contrato_igal_ao_http",
	&"_test_transporte_http_zerado",
	&"_test_af_cache_determina_replay", &"_test_verifier_recusa_id_forjado",
	&"_test_budget_do_oraculo_nao_estoura_a_arvore",
	&"_test_selecao_de_beliefs_e_pura_no_estado",
	&"_test_qualidade_nao_aparece_na_projecao_do_journal",
	&"_test_crenca_falsa_nao_vira_fato",
]
# 320 = os 283 da perna 12 mais as cinco de `extensao_carrega_classe` (dossie 22
# §5.1), o gate do esqueleto nativo: descritor no disco, extensao listada pela
# engine, biblioteca aberta no processo, classe na ClassDB e objeto vivo devolvido
# por ela -- mais as oito de `extensao_pack_no_processo` (dossie 22 §5.2), a rota do
# pack dentro do processo: runtime por caminho absoluto, pack vazio como base medida,
# gguf no processo, leitura conferida contra a meta do proprio modelo, contexto cujo
# pedido o runtime devolve e os tres numeros do §5.2 -- mais as vinte e duas de
# `contrato_igal_ao_http` (dossie 22 §5.3), o gate do contrato do prompt: o MESMO
# roster de um cenario fixo passa DUAS vezes, uma pela transporta HTTP (um CLIENTE
# DE REFERENCIA montado dentro do proprio gate, contra um llama-server que ele
# levanta e derruba pelo pid exato) e
# uma pela extensao (`AfMindOracle.enqueue`/`wait` pela rota ClassDB), e a comparacao
# e de FORMA -- as chaves e os tipos do Dictionary, o motivo nomeado, nunca a frase --
# mais as DUAS de `transporte_http_zerado` (dossie 22 §5.4), o gate do Passo 4 que e
# a frase do dono feita checagem: a varredura recursiva de `res://src` por
# "HTTPRequest" devolve VAZIO (nasce VERMELHO com as 9 ocorrencias impressas enquanto
# o wrapper nao existir) e os lancadores Rodar.bat/run_game.ps1 nao citam "llama"
# (nenhum processo de IA fora da engine). As trinta e sete contam tambem no
# vermelho -- o gate nasce vermelho de proposito (o runtime e o `.gguf` sao
# gitignored: num clone sem eles as oito e as de fila saem vermelhas com o caminho
# impresso, e sem o dll o censo inteiro e o vermelho, contrato do passo 1), e um
# censo que so vale depois do codigo existir nao decide nada. O censo se re-deriva a
# cada checagem nova porque a linha `_checks + 1 == EXPECTED_CHECKS` de `_finish` e
# o que converte passo abortado por `SCRIPT ERROR` em vermelho: um numero chutado aqui
# desarma o instrumento inteiro.
#
# Passo 5 (dossie 22 §5.5) acrescenta onze: as SETE de `af_cache_determina_replay`
# (§6.5) -- runtime e gguf no disco, o pack do wrapper no estado de fila pela rota
# do passo 2 (b), a corrida A narrada pelo wrapper com o modelo no processo, a
# chave de conteudo estavel entre as corridas, a cache escrita em ARQUIVO separado
# do save (nasceu VERMELHO: nada escrevia o arquivo antes do oracle_cache), a
# instancia FRESCA lendo a frase do arquivo pela chave de conteudo reconstruida de
# fora (§6.5 -- "lida antes de inferir") e o replay da segunda corrida devolvendo a
# mesma frase SEM consultar a fila com acertos_cache=1 (nasceu VERMELHO com
# pedidos=1 impresso: sem cache, a segunda corrida paga o decode de novo) -- mais
# as CINCO de `verifier_recusa_id_forjado` (§6.4/§7.1) -- o verificador nomeado
# existe em src/ai (nasceu VERMELHO sem o arquivo), o controle passa no
# verificador, a forja e recusada com o id NOMEADO, o portao do wrapper
# (`aceitar_saida`, a rota que o `_poll` usa) recusa a forja sem escrever
# narrativa e aceita o controle com narrativa e sinal -- mais as
# QUATRO de `budget_do_oraculo_nao_estoura_a_arvore` (§5.5) -- a regua do passo de
# 25 ms com o decode do oraculo EM VOO dentro da malha de 1 400 passos, estrutural-
# mente vermelha num clone sem runtime/gguf e com o SubtreeGuard de 400 us sem
# estouro nenhum.
#
# Fase 2 (dossie 22 §20) acrescenta dezenove: as SEIS de
# `selecao_de_beliefs_e_pura_no_estado` (§20.5) -- a janela de crencas existe no
# wrapper (nasceu VERMELHO: o `_prompt_for` imprimia TODAS as crencas na ordem do
# dicionario), o mesmo estado em duas ordens de insercao devolve a mesma janela, a
# janela nao deriva com o relogio da parede (mesma leitura apos >= 60 ms medidos),
# a janela corta em k, o desempate corre confianca -> vezes -> visto -> chave e o
# prompt de dois corpos de prova com o mesmo estado da mente e identico byte a
# byte -- mais as SEIS de `qualidade_nao_aparece_na_projecao_do_journal` (§20.5)
# -- a crenca carrega `visto_em` e `vezes` (nasceu VERMELHO: o `reinforce` so
# escrevia confidence e source), o carimbo segue o tick que confirmou com o toque
# negativo contando sem carimbar, o decay preserva a metadata enquanto a crenca
# vive, o disco (`to_dict`/`from_dict`) devolve os quatro campos, o `state_hash`
# do TickJournal e INDIFERENTE a visto_em/vezes e o controle move o hash ao mudar
# confidence (instrumento nao cego) -- mais as SETE de `crenca_falsa_nao_vira_fato`
# (§20.6) -- a rota `aceitar_ledger` existe no verificador (nasceu VERMELHO), o id
# do jogador (1, ACTOR_PLAYER) fora do roster do Passo 5 passa pelo ledger, o fato
# contradito pelo ledger e recusado com o id e o motivo nomeados, a recusa pelo
# portao do wrapper nao escreve NADA no Mind (e nomeia o portao em
# `ultimo_portao`), o fato verdadeiro sobre cadaver passa e entra no Mind do
# narrador como quarentena (source "oracle", confianca 0.10), a quarentena fica
# abaixo da soleira de `believes` e o controle (narracao pura, ids reais) passa
# sem escrever. As dezenove contam no vermelho -- cada premissa nasce vermelha
# nomeada, no padrao do passo 5, e o censo converge aborto em falha.
const EXPECTED_CHECKS: int = 355
# Copia LITERAL da tabela de vies medida nesta revisao (WorldGen.IMPRINT_BIAS), e
# nao uma leitura de la: o pino da checagem 4 do dossie 09 so tem como falhar
# quando a tabela do gen e editada se o par esperado vier de outro lugar.
const BIAS_MEDIDA: Array = [
	[0.85, 1.00, 1.30],    # frozen
	[1.30, 0.90, 0.85],    # arid
	[1.00, 1.00, 1.00],    # temperate
	[0.85, 1.15, 0.90],    # wetland
]
# Copia LITERAL de `MindOracle.JANELA_CRENCAS` (o k da janela de crencas da Fase
# 2), e nao uma leitura de la: no vermelho a constante ainda nao existe e ler-la
# seria SCRIPT ERROR — o mesmo padrao do pino `BIAS_MEDIDA` acima.
const K_JANELA_PROVA: int = 8

var _checks: int = 0
var _failures: int = 0
var _completed: int = 0
var _ran: bool = false
var _started_us: int = 0
var _mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _stage: Node3D
var _world: VoxelWorld
var _player: Player
var _wolf: Wolf
var _field: AetherField
var _clock: SimClock
var _steps: int = 0
var _sim_us: int = 0
var _sim_worst_us: int = 0
var _bt_us: int = 0
var _bt_worst_us: int = 0
var _bt_trips: int = 0
# Contadores da alcateia, separados dos de um lobo so: o rodape historico do
# runner e o que a rodada anterior publicou, e misturar nele o `sim_tick` da
# sessao (difusao incluida) quebraria a comparacao pareada branch x chao.
var _session: Session = null
var _pack_steps: int = 0
var _pack_sim_us: int = 0
var _pack_sim_worst_us: int = 0
var _pack_bt_us: int = 0
var _pack_bt_worst_us: int = 0
var _pack_bt_trips: int = 0
# Mordidas colhidas pelo sinal real `bit_player` da sessao, como
# [tick, identidade, n lido, rank lido, intent, fase]: a contagem por tick e o numero que
# o escalonamento exige, e o sinal e a unica forma de ver a mordida sem ler um campo
# escrito a mao.
var _bite_events: Array = []

# Estado do gate `contrato_igal_ao_http` (Passo 3 do dossie 22 §5.3): o pid EXATO do
# llama-server que O PROPRIO gate subiu (nunca um nome para adivinhar -- o desmanche e
# por lancamento, como o `LlmServerHost` manda) e a contagem de emissoes do sinal
# `inference_completed`, conectado antes dos decodes. O `_finish` mata o pid que
# sobrar de um aborto no meio do gate.
var _af_server_pid: int = -1
var _gate_emissoes: int = 0

# Geometria da matilha no plateau da fixture: tres lobos se enxergam (8,5 m e
# 17 m), o quarto fica a 25,6 m do vizinho mais proximo -- do lado de la do raio
# de coesao de 24 m, entao a lista dele tem de vir vazia.
const PACK_SPOTS: Array = [
	Vector3(52.0, 51.001, 56.0), Vector3(58.0, 51.001, 62.0),
	Vector3(64.0, 51.001, 68.0), Vector3(84.0, 51.001, 84.0),
]

# Geometria fechada da ronda: quatro lobos a no maximo 8,9 m um do outro, todos
# dentro do raio de coesao, entao cada um le tres vizinhos (n = 4, fatia de 90
# graus). O baricentro cai exatamente no lobo 0 -- distancia horizontal dele ao
# centro e zero, o que da ao teste um centro conferivel a lapis.
const RONDAR_SPOTS: Array = [
	Vector3(58.0, 51.001, 62.0), Vector3(54.0, 51.001, 62.0),
	Vector3(58.0, 51.001, 66.0), Vector3(62.0, 51.001, 58.0),
]

# Geometria do cerco: presa no centro do plateau e quatro participantes a 8 m em
# cruz, todos dentro dos 30 m da LOS e dentro dos 24 m de coesao (o par mais
# distante fica a 16 m). Nem um deles comeca ao alcance da mordida, senao o ramo
# `morder` engoliria o ramo `perseguir` e o assento nunca seria escrito.
const CERCAR_PLAYER := Vector3(58.0, 51.001, 62.0)
const CERCAR_SPOTS: Array = [
	Vector3(50.0, 51.001, 62.0), Vector3(66.0, 51.001, 62.0),
	Vector3(58.0, 51.001, 54.0), Vector3(58.0, 51.001, 70.0),
]

# Geometria do ataque escalonado: quatro lobos JA dentro de `BITE_RANGE` (1,5 m
# horizontal, 1,56 m na conta 3D do `_sense`), todos com visada. Sem o
# escalonamento os quatro mordem no tick zero; com ele, cada assento morde no
# proprio assento morde na sua fase de tick.
const ESCALONAR_SPOTS: Array = [
	Vector3(59.5, 51.001, 62.0), Vector3(56.5, 51.001, 62.0),
	Vector3(58.0, 51.001, 63.5), Vector3(58.0, 51.001, 60.5),
]

# Geometria da checagem 4 (dossie 11 §5): o filhote no MESMO anel de mordida dos
# quatro adultos, na diagonal -- 1,5 m horizontal do jogador (1,52 m na conta 3D
# do `_sense`, com o corpo 0,45 do filhote baixando o centro) e 1,15 m dos dois
# vizinhos de anel. Os quatro cardeais ja estao tomados, entao a unica diferenca
# entre ele e eles e a fase do corpo.
const FILHOTE_SPOT := Vector3(59.0607, 51.001, 63.0607)

# Geometria do contagio de medo: 20 m separam o observador (lobo 1) do vizinho que
# foge (lobo 0) -- dentro do raio de coesao de 24 m, mas a cinco celulas de Eter
# (AETHER_CELL = 4) um do outro, o que a difusao nao cruza na janela medida (3
# passadas em 16 ticks). O jogador fica a mais de 60 m dos dois e sem visada para
# nenhum, entao a base do observador e `patrol` e a `hunt` dele esta vetada.
const MEDO_SPOTS: Array = [
	Vector3(78.0, 51.001, 62.0), Vector3(58.0, 51.001, 62.0),
]

# Geometria do amortecimento por confianca: tres lobos a 8 m do jogador (que fica
# no centro do plateau) e a 11,3 m / 11,3 m / 16 m um do outro -- todos dentro dos
# 24 m de coesao, cada um lendo os outros dois, e todos dentro dos 30 m da LOS,
# entao a porta de `hunt` e o que decide a intencao dos tres. O lobo 0 e o
# amansado; 1 e 2 sao os colegas cuja coragem o trust dele amortce.
const AMORTECE_SPOTS: Array = [
	Vector3(58.0, 51.001, 54.0), Vector3(50.0, 51.001, 62.0),
	Vector3(66.0, 51.001, 62.0),
]


# Geometria da célula de rastro (dossie 14 §5.4): quatro lobos a 7,2 m de um unico
# imprint de WORK, todos dentro dos 12 m do nariz (SCENT_RADIUS = 3 celulas) e
# dentro dos 24 m de coesao, entao os quatro leem a MESMA celula. Sem assento, os
# quatro escrevem o mesmo centro -- e o "cinco corpos no mesmo ponto" que a
# premissa 2 declara por ausencia.
const FAREJAR_SPOTS: Array = [
	Vector3(60.0, 51.001, 58.0), Vector3(72.0, 51.001, 58.0),
	Vector3(60.0, 51.001, 66.0), Vector3(72.0, 51.001, 66.0),
]

# Geometria do acasalamento (dossie 11 §5, checagens 1 e 2): DOIS pares a 3 m um
# do outro -- dentro dos 8 m de `MATE_RADIUS` -- separados 12 m entre si, entao
# fora do raio. O segundo par nao e enfeite: sem ele "nenhum nascimento a mais"
# nao distingue cooldown que segura do caminho quente quebrado, e e o par de
# controle que a checagem 2 exige (ciclo 3 do AGENTS.md: a atribuicao fecha nos
# dois sentidos). Os 3 m deixam folga: `center()` soma meia altura do corpo nos
# dois lados e os pes estao no mesmo y, entao a distancia 3D dos pais e a
# distancia no chao.
const MATE_SPOTS: Array = [
	Vector3(46.0, 51.001, 46.0), Vector3(49.0, 51.001, 46.0),
	Vector3(46.0, 51.001, 58.0), Vector3(49.0, 51.001, 58.0),
]

# Geometria do teto (checagem 6): os mesmos dois pares mais sete adultos a no
# minimo 12 m de qualquer vizinho. TODOS os 11 sitios sao escritos pelo teste:
# deixados no sorteio, dois lares a menos de 8 m fariam o censo entrar no teto por
# velocidade de natacao em vez de pela recusa que se quer medir.
const CAP_SPOTS: Array = [
	Vector3(46.0, 51.001, 46.0), Vector3(49.0, 51.001, 46.0),
	Vector3(46.0, 51.001, 58.0), Vector3(49.0, 51.001, 58.0),
	Vector3(70.0, 51.001, 46.0), Vector3(82.0, 51.001, 46.0),
	Vector3(82.0, 51.001, 58.0), Vector3(82.0, 51.001, 70.0),
	Vector3(70.0, 51.001, 70.0), Vector3(58.0, 51.001, 82.0),
	Vector3(40.0, 51.001, 82.0),
]
# Onde o nariz da checagem 3 fica de pe, a OESTE do muro de x=56. A coluna nao e
# escolha de gosto: a celula de Eter da boca cavada (56 / 4 = 14) entra no quadrado
# de `SCENT_RADIUS = 3` celulas em torno de 46 / 4 = 11 (varre 8..14) e a celula da
# isca de WORK, em x=66 (= 16), fica FORA. Assim o braco do lobo le "WORK so do
# lobo" e o braco do jogador le "WORK so do jogador" -- duas misturas diferentes
# nao comparariam assinatura nenhuma.
const NARIZ_FEET := Vector3(46.0, 51.001, 54.0)


## Sessao de spawn puro: os cinco lobos vem do `_spawn_wolves` real e ficam onde o
## sorteados colocou, sem `_pack_place`. E o unico jeito de conferir os lares
## (dossie 14 §3.3.(iii)) pela transicao verdadeira e nao por posicao escrita a mao.
## `mating` funciona como no `_pack_session`: preso por padrao para o censo do
## spawn nao ser mexido por um parto no meio da janela.
func _spawn_session(n: int, mating: bool = false) -> void:
	_pack_release()
	var s = Session.new()
	s.world = _world
	s.aether = _field
	s.clock = _clock
	s.player = _player
	s._entities = Node3D.new()
	_stage.add_child(s._entities)
	s._spawn_wolves(n)
	if not mating:
		s._mate_cd = INF
	_session = s


func _initialize() -> void:
	_started_us = Time.get_ticks_usec()
	_mouse_mode = Input.mouse_mode
	# O fechamento independe do retorno de _run: erro de script nao pode deixar a CLI aberta.
	# Com o gate do oraculo (`contrato_igal_ao_http`) a `_run` virou corotina -- o `await` dela
	# devolve o controle ao laco de frames enquanto o servidor sobe e o modelo narra -- entao
	# quem agenda o fechamento e a `_run_all` DEPOIS do `await`. O par de `call_deferred` de
	# antes nao serve mais: ele agendaria o fechamento no MESMO quadro do comeco, antes do
	# gate ter rodado.
	_run_all.call_deferred()


func _run_all() -> void:
	await _run()
	_finish.call_deferred()


func _run() -> void:
	for test_name: StringName in TESTS:
		# `await` num teste sincrono e passagem direta (devolve o bool); na corotina do gate
		# e o que suspende o laco ate ela terminar. Um SCRIPT ERROR no meio de um teste
		# devolve null aqui -- ABORTOU + break, e o censo de `_finish` converge o vermelho.
		var resultado = await call(test_name)
		if resultado != true:
			_failures += 1
			push_error("ABORTOU %s: nao devolveu true" % test_name)
			break
		_completed += 1
	_ran = true


func _check(ok: bool, label: String, values: String) -> void:
	_checks += 1
	print("%s %s | %s" % ["OK" if ok else "FALHA", label, values])
	if not ok:
		_failures += 1


func _test_fixture() -> bool:
	BlockDefs.init_tables()
	# O InputMap deste jogo nao esta no project.godot: e o boot que o registra, na
	# linha `InputActions.install()` de main.gd:78. Este runner monta a sessao sem
	# `_ready`, entao sem esta chamada nenhum `get_action_strength` existe -- eram 15
	# erros por corrida no log verde e o auto-pulo do jogador nao teria como ser
	# pedido pelo caminho real do teclado.
	InputActions.install()
	_stage = Node3D.new()
	_stage.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_stage)
	_world = VoxelWorld.new()
	_world.setup_world(_stage)
	_world.generate(SEED)
	var bad_columns: int = 0
	for x: int in range(40, 85):
		for z: int in range(40, 85):
			_world.set_block(Vector3i(x, 50, z), BlockDefs.Block.STONE)
			for y: int in range(51, VoxelChunk.SIZE_Y):
				_world.set_block(Vector3i(x, y, z), BlockDefs.Block.AIR)
			if _world.surface_height(x, z) != 50 or _world.is_water_xyz(x, 51, z):
				bad_columns += 1
	_player = Player.new()
	_stage.add_child(_player)
	_player.setup(_world, FAR_PLAYER)
	_check(_world.gen.world_seed == SEED and _world.chunks.size() == 64,
			"geracao real", "seed=%d chunks=%d" % [_world.gen.world_seed, _world.chunks.size()])
	_check(bad_columns == 0, "2025 colunas secas, piso y=50, ar ate o teto", "invalidas=%d" % bad_columns)
	_check(_player.is_node_ready() and _world.atlas_texture() != null,
			"Player pronto com atlas real", "ready=%s atlas=%s" % [_player.is_node_ready(), _world.atlas_texture()])
	_check(not _player.can_process() and _world.meshes_built() == 0,
			"sem input automatico ou malharia", "process=%s meshes=%d" % [_player.can_process(), _world.meshes_built()])
	return true


func _arm(spawn: Vector3 = SPAWN, player_pos: Vector3 = FAR_PLAYER, wolf_id: int = 1) -> void:
	if is_instance_valid(_wolf):
		_wolf.free()
	seed(SEED)
	_clock = SimClock.new()
	_field = AetherField.new()
	_field.setup(_world)
	_player.feet_to_spawn(player_pos)
	_wolf = Wolf.new()
	_stage.add_child(_wolf)
	_wolf.setup(_world, _field, _player, spawn, wolf_id, _clock)


func _advance(ticks: int, move_body: bool = true) -> void:
	# Campo estatico por padrao isola a reacao; so o caso de difusao avanca o campo.
	for i: int in ticks:
		var trips_before: int = _wolf._guard.trips
		var start: int = Time.get_ticks_usec()
		_wolf.sim_step(float(_clock.tick + 1) * SimClock.STEP, SimClock.STEP)
		var cost: int = Time.get_ticks_usec() - start
		_sim_us += cost
		_sim_worst_us = maxi(_sim_worst_us, cost)
		_bt_us += _wolf._guard.last_us
		_bt_worst_us = maxi(_bt_worst_us, _wolf._guard.last_us)
		_bt_trips += _wolf._guard.trips - trips_before
		_steps += 1
		_clock.tick += 1
		if move_body:
			for frame: int in 3:
				_wolf._physics_process(SimClock.STEP / 3.0)


## Lancamento = o frame em que a velocidade vertical SOU. Comparar com um limiar fixo
## nao presta e ja enganou esta suite: com o impulso de 5,2 o frame seguinte caia abaixo
## de 5 e cada salto contava um, por acaso; com o de 7,6 (STEP_JUMP, o conserto do
## degrau) sete frames seguidos passariam de 5 e um unico salto viraria sete lancamentos.
## O `> 0,0` importa: o pouso zera o vy no eixo Y (voxel_body.gd:103) e isso e parar, nao
## subir. Chamar `_launch_watch` antes do laco, depois de armar o corpo.
var _vy_prev: float = 0.0

func _launch_watch(body: VoxelBody) -> void:
	_vy_prev = body.velocity.y


func _launched(body: VoxelBody) -> bool:
	var up := body.velocity.y > _vy_prev + 0.5 and body.velocity.y > 0.0
	_vy_prev = body.velocity.y
	return up


func _horizontal(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _distance(p: Vector3) -> float:
	return _horizontal(_wolf.center() - p).length()


func _motion() -> String:
	return "tick=%d intent=%s reaction=%s feet=%s speed=%.4f target=%s" % [
		_clock.tick, _wolf.intent, _wolf.get("_reaction"), _wolf.body.feet_pos,
		_horizontal(_wolf.body.velocity).length(), _wolf._move_target]


func _arrive() -> bool:
	for i: int in 160:
		_advance(1)
		if _distance(SOURCE) <= 1.2 or _wolf.get("_reaction") == "farejando":
			return _distance(SOURCE) < 1.5
	return false


func _wall(block: int) -> void:
	for y: int in range(51, 57):
		for z: int in range(40, 85):
			_world.set_block(Vector3i(63, y, z), block)


func _test_work_approach() -> bool:
	_arm()
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.42)
	_advance(1)
	_check(_wolf._dist_player > 30.0 and not _wolf._los_player,
			"WORK sem jogador perceptivel", "dist=%.3f los=%s" % [_wolf._dist_player, _wolf._los_player])
	_check(_wolf.intent == "investigate" and _horizontal(_wolf._scent_pos - SOURCE).length() < 0.01,
			"imprint WORK .42 atrai", "work=%.4f %s" % [_field.sample(SOURCE, AetherField.Channel.WORK), _motion()])
	var before: float = _distance(SOURCE)
	_advance(16)
	_check(_distance(SOURCE) < before - 0.3 and _horizontal(_wolf.body.velocity).length() > 0.1,
			"aproximacao fisica do rastro", "dist %.3f -> %.3f %s" % [before, _distance(SOURCE), _motion()])
	_check(_wolf.mind.count_kind("saw_player") == 0, "rastro nao fabrica avistamento",
			"episodios=%d" % _wolf.mind.count_kind("saw_player"))
	return true


func _test_weighted_traces() -> bool:
	var blood_pos := Vector3(58.0, 50.6, 66.0)
	for blood_wins: bool in [true, false]:
		_arm()
		var blood: float = 0.25 if blood_wins else 0.08
		var work: float = 0.42 if blood_wins else 0.84
		_field.imprint(blood_pos, AetherField.Channel.BLOOD, blood)
		_field.imprint(SOURCE, AetherField.Channel.WORK, work)
		_advance(1)
		var expected: Vector3 = blood_pos if blood_wins else SOURCE
		_check((_field.sample(blood_pos, AetherField.Channel.BLOOD)
				> _field.sample(SOURCE, AetherField.Channel.WORK) * 0.35) == blood_wins,
				"premissa dos pesos simultaneos", "blood=%.3f work*.35=%.3f" % [blood, work * 0.35])
		_check(_wolf.intent == "investigate" and _horizontal(_wolf._scent_pos - expected).length() < 0.01,
				"vence o rastro ponderado mais forte", "esperado=%s %s" % [expected, _motion()])
	return true


func _test_fear_ab() -> bool:
	var directions: Array[Vector3] = []
	var motions: Array[Vector3] = []
	var spawn := Vector3(62.0, 51.001, 62.0)
	for player_z: float in [18.0, 106.0]:
		_arm(spawn, Vector3(62.0, 51.001, player_z))
		_field.imprint(_wolf.center(), AetherField.Channel.FEAR, 0.9)
		_field.imprint(_wolf.center() + Vector3(4, 0, 0), AetherField.Channel.FEAR, 3.5)
		# Observar o vetor antes da fisica separa steering do desvio por colisao.
		_advance(1, false)
		var direction: Vector3 = _horizontal(_wolf._move_target - _wolf.center()).normalized()
		directions.append(direction)
		var east: float = _field.sample(_wolf.center() + Vector3(4, 0, 0), AetherField.Channel.FEAR)
		_check(not _wolf._los_player and _wolf._dist_player > 30.0
				and is_equal_approx(_wolf._fear_here, 0.9) and is_equal_approx(east, 3.5),
				"medo local com jogador invisivel", "player_z=%.1f fear=%.3f east=%.3f dist=%.3f" % [player_z, _wolf._fear_here, east, _wolf._dist_player])
		_check(_wolf.intent == "flee" and direction.x < -0.95,
				"fuga desce gradiente a oeste", "vetor=%s %s" % [direction, _motion()])
		_advance(6)
		var moved: Vector3 = _horizontal(_wolf.body.feet_pos - spawn)
		motions.append(moved)
		_check(moved.x < -0.2, "corpo foge a oeste", "deslocamento=%s %s" % [moved, _motion()])
	_check(directions[0].distance_to(directions[1]) < 0.0001,
			"A/B jogador oculto nao muda vetor", "A=%s B=%s" % directions)
	_check(motions[0].distance_to(motions[1]) < 0.0001,
			"A/B mesmo seed e clock conservam movimento", "A=%s B=%s" % motions)
	return true


func _test_unseen() -> bool:
	_arm(SPAWN, Vector3(66.0, 51.001, 62.0))
	_wall(BlockDefs.Block.STONE)
	_advance(1)
	_check(not _wolf._los_player and _wolf._dist_player < 10.0,
			"parede real oculta jogador proximo", "dist=%.3f los=%s" % [_wolf._dist_player, _wolf._los_player])
	var hunts: int = 0
	for i: int in 12:
		if _wolf.intent == "hunt":
			hunts += 1
		_advance(1)
	_check(hunts == 0 and _wolf.intent != "hunt", "sem avistamento nao caca", "ticks_hunt=%d %s" % [hunts, _motion()])
	_check(_wolf.mind.count_kind("saw_player") == 0, "parede nao produz memoria visual",
			"episodios=%d" % _wolf.mind.count_kind("saw_player"))
	_wall(BlockDefs.Block.AIR)
	return true


func _test_last_sighting() -> bool:
	_arm(SPAWN, Vector3(66.0, 51.001, 62.0))
	var before: float = _distance(_player.position3())
	_advance(10)
	_check(_wolf._los_player and _wolf.intent == "hunt", "presa visivel ainda provoca caca", _motion())
	_check(_distance(_player.position3()) < before - 0.3, "caca move corpo ate presa visivel",
			"dist %.3f -> %.3f" % [before, _distance(_player.position3())])
	var atom: Dictionary = _wolf.mind.last_atom("saw_player")
	var seen: Vector3 = atom.get("pos", Vector3.ZERO)
	_wall(BlockDefs.Block.STONE)
	_player.feet_to_spawn(Vector3(66.0, 51.001, 72.0))
	_advance(1)
	_check(not atom.is_empty() and not _wolf._los_player and _distance(_player.position3()) < 30.0,
			"avistamento real seguido de bloqueio e deslocamento", "visto=%s oculto=%s los=%s" % [seen, _player.position3(), _wolf._los_player])
	_check(_wolf.intent == "hunt" and _horizontal(_wolf._move_target - seen).length() < 0.05
			and _horizontal(_wolf._move_target - _player.position3()).length() > 5.0,
			"persegue ultima observacao, nao posicao oculta", _motion())
	before = _distance(seen)
	_advance(4)
	_check(_distance(seen) < before and _horizontal(_wolf._move_target - seen).length() < 0.05,
			"memoria guia movimento apos perda de LOS", "dist %.3f -> %.3f %s" % [before, _distance(seen), _motion()])
	_wall(BlockDefs.Block.AIR)
	return true


func _test_work_cycle() -> bool:
	_arm()
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.42)
	var arrived: bool = _arrive()
	_check(arrived, "WORK chega ao local em ate 8s", "dist=%.3f %s" % [_distance(SOURCE), _motion()])
	var at_arrival: Vector3 = _wolf.body.feet_pos
	_advance(12)
	var drift: float = _horizontal(_wolf.body.feet_pos - at_arrival).length()
	_check(arrived and drift < 0.4 and _horizontal(_wolf.body.velocity).length() < 0.2,
			"inspecao para corpo em vez de cair na patrulha", "drift=%.4f %s" % [drift, _motion()])
	_advance(50)
	var first: int = _wolf.mind.count_kind("scent_work")
	var episode: Dictionary = _wolf.mind.last_atom("scent_work")
	_check(first == 1 and int(episode.get("actor", -1)) == 0,
			"inspecao WORK produz episodio sem atribuir ator", "count=%d atom=%s" % [first, episode])
	# Tres segundos permitem outra inspecao, sem deixar a patrulha sair do raio de cheiro.
	_advance(60)
	_check(first == 1 and _wolf.mind.count_kind("scent_work") == first,
			"rastro estatico nao repete episodio em 3s", "antes=%d depois=%d" % [first, _wolf.mind.count_kind("scent_work")])
	var cache: Variant = _wolf.get("_checked_scents")
	_check(cache is Dictionary and cache.size() > 0 and cache.size() <= 32,
			"inspecao registra cache limitado", "cache=%s" % str(cache))
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.42)
	var reopened: bool = false
	for i: int in 200:
		_advance(1)
		reopened = reopened or (_wolf.intent == "investigate" and _horizontal(_wolf._scent_pos - SOURCE).length() < 0.01)
		if _wolf.mind.count_kind("scent_work") > first:
			break
	_check(first == 1 and reopened, "novo imprint .42 reabre local checado",
			"reabriu=%s work=%.3f %s" % [reopened, _field.sample(SOURCE, AetherField.Channel.WORK), _motion()])
	_check(first == 1 and _wolf.mind.count_kind("scent_work") == 2,
			"rastro renovado termina segunda inspecao", "count=%d" % _wolf.mind.count_kind("scent_work"))
	_wolf.load_state(_wolf.state_dict().duplicate(true))
	cache = _wolf.get("_checked_scents")
	_check(cache is Dictionary and cache.is_empty(), "load limpa cache transitorio", "cache=%s" % str(cache))
	var left: Variant = _wolf.get("_inspect_left")
	_check(left != null and float(left) == 0.0 and _wolf.get("_reaction") != "farejando",
			"load nao retoma timer de inspecao", "left=%s %s" % [left, _motion()])
	return true


func _test_blood_cycle() -> bool:
	_arm()
	_field.imprint(SOURCE, AetherField.Channel.BLOOD, 0.42)
	_check(_arrive(), "BLOOD aproxima corpo ate fonte", "dist=%.3f %s" % [_distance(SOURCE), _motion()])
	_advance(62)
	var atom: Dictionary = _wolf.mind.last_atom("scent_blood")
	_check(_wolf.mind.count_kind("scent_blood") == 1 and int(atom.get("actor", -1)) == 0,
			"inspecao BLOOD produz episodio sem ator", "atom=%s" % atom)
	_check(_wolf.mind.count_kind("saw_player") == 0 and _wolf.mind.count_kind("scent_work") == 0,
			"sangue nao vira avistamento ou trabalho", "saw=%d work=%d" % [_wolf.mind.count_kind("saw_player"), _wolf.mind.count_kind("scent_work")])
	return true


func _test_fear_interrupt() -> bool:
	_arm(Vector3(SOURCE.x, 51.001, SOURCE.z))
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.42)
	_advance(3)
	_check(_wolf.get("_reaction") == "farejando", "premissa: inspecao em andamento", _motion())
	var before: Vector3 = _wolf.body.feet_pos
	_field.imprint(_wolf.center(), AetherField.Channel.FEAR, 0.9)
	_field.imprint(_wolf.center() + Vector3(4, 0, 0), AetherField.Channel.FEAR, 3.5)
	_advance(14)
	_check(_wolf.intent == "flee" and _wolf.get("_reaction") != "farejando",
			"medo interrompe inspecao antes de 2s", _motion())
	_check(_wolf.body.feet_pos.x < before.x - 0.2 and _wolf.mind.count_kind("scent_work") == 0,
			"interrupcao move corpo sem concluir episodio", "dx=%.3f count=%d" % [_wolf.body.feet_pos.x - before.x, _wolf.mind.count_kind("scent_work")])
	return true


func _test_work_diffusion() -> bool:
	_arm()
	_field.imprint(SOURCE, AetherField.Channel.WORK, 4.0)
	var energy_before: float = _field.total_energy()
	_advance(1)
	_check(_wolf.intent == "investigate" and not _wolf._los_player and _wolf._dist_player > 30.0
			and _field.sample(SOURCE, AetherField.Channel.WORK) > 3.9,
			"premissa: WORK forte sem presa perceptivel", "energia=%.6f %s" % [energy_before, _motion()])
	var passes: int = 0
	var approach_passes: int = 0
	var inspect_passes: int = 0
	var episode: Dictionary = {}
	var episode_tick: int = -1
	var episode_distance: float = INF
	var travel: float = 0.0
	# O pico pode mudar de celula: a chegada se mede contra o episodio, nao a fonte inicial.
	for i: int in 239:
		if (_clock.tick + 1) % 5 == 0:
			_field.diffuse_and_decay(0.25)
			passes += 1
			if _wolf.get("_reaction") == "farejando":
				inspect_passes += 1
			elif _wolf.intent == "investigate":
				approach_passes += 1
		_advance(1)
		if episode.is_empty() and _wolf.mind.count_kind("scent_work") > 0:
			episode = _wolf.mind.last_atom("scent_work")
			episode_tick = _clock.tick
			episode_distance = _distance(episode.get("pos", Vector3.ZERO))
			travel = _horizontal(_wolf.body.feet_pos - SPAWN).length()
	_check(_clock.tick == 240 and passes == 48 and approach_passes > 0 and inspect_passes > 0,
			"difusao .25s durante aproximacao e inspecao", "ticks=%d passes=%d seguindo=%d farejando=%d" % [
			_clock.tick, passes, approach_passes, inspect_passes])
	var energy_after: float = _field.total_energy()
	var active: int = _field.active_cells(AetherField.MIN_VALUE).size()
	_check(energy_after > 0.0 and energy_after < energy_before and active > 1,
			"campo realmente decai e espalha", "energia %.6f -> %.6f celulas=%d" % [energy_before, energy_after, active])
	_check(episode_tick > 0 and episode_tick <= 240 and int(episode.get("actor", -1)) == 0,
			"WORK difuso conclui episodio sem ator em ate 12s", "tick=%d count=%d atom=%s" % [
			episode_tick, _wolf.mind.count_kind("scent_work"), episode])
	_check(episode_distance <= 1.5 and travel > 0.5,
			"episodio difuso exige chegada fisica ao local examinado", "dist=%.4f deslocamento=%.4f" % [episode_distance, travel])
	_check(_wolf.mind.count_kind("saw_player") == 0 and _wolf.mind.count_kind("scent_blood") == 0,
			"difusao WORK nao fabrica presa ou sangue", "saw=%d blood=%d" % [
			_wolf.mind.count_kind("saw_player"), _wolf.mind.count_kind("scent_blood")])
	return true


func _test_cache_expiry() -> bool:
	_arm(Vector3(SOURCE.x, 51.001, SOURCE.z))
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.84)
	var strength_before: float = _field.sample(SOURCE, AetherField.Channel.WORK)
	var energy_before: float = _field.total_energy()
	var first_tick: int = -1
	for i: int in 60:
		_advance(1)
		if _wolf.mind.count_kind("scent_work") > 0:
			first_tick = _clock.tick
			break
	var first: Dictionary = _wolf.mind.last_atom("scent_work")
	_check(first_tick > 0 and _wolf.mind.count_kind("scent_work") == 1
			and _distance(SOURCE) <= 1.2 and _horizontal(_wolf.body.velocity).length() < 0.01,
			"premissa: primeira inspecao com corpo real em ate 3s", "tick=%d atom=%s %s" % [first_tick, first, _motion()])
	var cell: Vector3i = _field.cell_of_world(SOURCE)
	var cache: Dictionary = _wolf.get("_checked_scents")
	var entry: Vector2 = cache.get(cell, Vector2(-1.0, -1.0))
	_check(cache.has(cell) and absf(entry.y - float(first_tick) * SimClock.STEP - 30.0) < 0.001
			and strength_before * 0.35 > 0.08,
			"premissa: cache da fonte dura 30s e WORK continua forte", "entrada=%s tick=%d work*.35=%.6f" % [entry, first_tick, strength_before * 0.35])
	# Congelar apos a visita impede que sair do raio do cheiro finja supressao pelo cache.
	var parked: Vector3 = _wolf.body.feet_pos
	var early_inspections: int = 0
	for i: int in 580:
		_advance(1, false)
		if _wolf.get("_reaction") == "farejando":
			early_inspections += 1
	_check(first_tick > 0 and _clock.tick - first_tick == 580 and early_inspections == 0
			and _wolf.mind.count_kind("scent_work") == 1 and cache.has(cell),
			"cache impede reinspecao durante os primeiros 29s", "idade=%.2f farejando=%d count=%d cached=%s" % [
			float(_clock.tick - first_tick) * SimClock.STEP, early_inspections, _wolf.mind.count_kind("scent_work"), cache.has(cell)])
	var expired_tick: int = -1
	var reopened_tick: int = -1
	for i: int in 100:
		_advance(1, false)
		if expired_tick < 0 and not cache.has(cell):
			expired_tick = _clock.tick
		if reopened_tick < 0 and _wolf.get("_reaction") == "farejando":
			reopened_tick = _clock.tick
		if _wolf.mind.count_kind("scent_work") > 1:
			break
	var expiry_age: float = float(expired_tick - first_tick) * SimClock.STEP
	var reopen_age: float = float(reopened_tick - first_tick) * SimClock.STEP
	_check(expired_tick > 0 and expiry_age >= 30.0 and expiry_age <= 30.3,
			"cache expira apos 30s na cadencia de percepcao", "idade=%.3f tick=%d" % [expiry_age, expired_tick])
	_check(reopened_tick > 0 and reopen_age >= 30.0 and reopen_age <= 31.0,
			"mesmo WORK reabre inspecao sem novo imprint", "idade=%.3f tick=%d" % [reopen_age, reopened_tick])
	var second: Dictionary = _wolf.mind.last_atom("scent_work")
	var episode_gap: int = int(second.get("tick", -1)) - int(first.get("tick", -1))
	_check(_wolf.mind.count_kind("scent_work") == 2 and episode_gap >= 600 and episode_gap <= 680
			and second.get("pos") == first.get("pos") and int(second.get("actor", -1)) == 0,
			"revisita termina segundo episodio no mesmo local", "intervalo_ticks=%d count=%d atom=%s" % [
			episode_gap, _wolf.mind.count_kind("scent_work"), second])
	_check(_wolf.body.feet_pos.distance_to(parked) < 0.0001
			and is_equal_approx(_field.sample(SOURCE, AetherField.Channel.WORK), strength_before)
			and is_equal_approx(_field.total_energy(), energy_before),
			"premissa mantida: corpo parado e campo estatico sem renovacao", "drift=%.6f work %.6f -> %.6f energia %.6f -> %.6f" % [
			_wolf.body.feet_pos.distance_to(parked), strength_before, _field.sample(SOURCE, AetherField.Channel.WORK), energy_before, _field.total_energy()])
	return true


func _test_fear_no_feedback() -> bool:
	var spawn := Vector3(62.0, 51.001, 62.0)
	_arm(spawn)
	var origin: Vector3 = _wolf.center()
	var east: Vector3 = origin + Vector3(4, 0, 0)
	var west: Vector3 = origin - Vector3(4, 0, 0)
	_field.imprint(origin, AetherField.Channel.FEAR, 0.9)
	_field.imprint(east, AetherField.Channel.FEAR, 3.5)
	var samples_before := Vector3(_field.sample(origin, AetherField.Channel.FEAR),
			_field.sample(east, AetherField.Channel.FEAR), _field.sample(west, AetherField.Channel.FEAR))
	var energy_before: float = _field.total_energy()
	_check(samples_before.is_equal_approx(Vector3(0.9, 3.5, 0.0)) and is_equal_approx(energy_before, 4.4)
			and _wolf.mind.count_kind("hurt") == 0 and _wolf.hp == Wolf.MAX_HP,
			"premissa: somente dois imprints FEAR, nenhum golpe", "amostras=%s energia=%.6f hp=%.2f" % [samples_before, energy_before, _wolf.hp])
	var flee_ticks: int = 0
	var visible_ticks: int = 0
	for i: int in 20:
		_advance(1)
		if _wolf.intent == "flee":
			flee_ticks += 1
		if _wolf._los_player:
			visible_ticks += 1
	_check(flee_ticks >= 3 and _wolf.body.feet_pos.x < spawn.x - 0.2 and visible_ticks == 0
			and _wolf.mind.count_kind("hurt") == 0 and is_zero_approx(_wolf._threat),
			"fuga fisica provocada so pelo campo", "flee=%d los=%d dx=%.4f threat=%.4f" % [
			flee_ticks, visible_ticks, _wolf.body.feet_pos.x - spawn.x, _wolf._threat])
	# As sondas ficam no mundo, nao acompanham o lobo que sai da celula quente.
	var samples_after := Vector3(_field.sample(origin, AetherField.Channel.FEAR),
			_field.sample(east, AetherField.Channel.FEAR), _field.sample(west, AetherField.Channel.FEAR))
	_check(samples_after.is_equal_approx(samples_before),
			"fugir nao amplifica FEAR nas sondas fixas", "antes=%s depois=%s" % [samples_before, samples_after])
	var totals: Array = _field.channel_totals()
	_check(is_equal_approx(_field.total_energy(), energy_before)
			and is_equal_approx(float(totals[AetherField.Channel.FEAR]), energy_before)
			and is_zero_approx(float(totals[AetherField.Channel.BLOOD])) and is_zero_approx(float(totals[AetherField.Channel.WORK])),
			"fuga sem golpe nao cria energia em outras celulas", "energia %.6f -> %.6f canais=%s" % [energy_before, _field.total_energy(), totals])
	return true


func _test_last_hurt_ab() -> bool:
	var directions: Array[Vector3] = []
	var motions: Array[Vector3] = []
	for player_z: float in [18.0, 106.0]:
		_arm(SPAWN, SPAWN + Vector3(2, 0, 0))
		var hit_from: Vector3 = _player.position3()
		_wolf.take_damage(8.0, Wolf.ACTOR_PLAYER, hit_from)
		var hurt: Dictionary = _wolf.mind.last_atom("hurt")
		_check(_wolf.alive and is_equal_approx(_wolf.hp, Wolf.MAX_HP - 8.0)
				and _wolf.mind.count_kind("hurt") == 1 and hurt.get("pos") == hit_from
				and int(hurt.get("actor", -1)) == Wolf.ACTOR_PLAYER,
				"premissa A/B: um unico take_damage real", "braco_z=%.1f hp=%.2f atom=%s" % [player_z, _wolf.hp, hurt])
		_player.feet_to_spawn(Vector3(SPAWN.x, SPAWN.y, player_z))
		# Steering antes da fisica separa a direcao escolhida do impulso do golpe.
		_advance(1, false)
		var expected: Vector3 = _horizontal(_wolf.center() - hit_from).normalized()
		var hidden_away: Vector3 = _horizontal(_wolf.center() - _player.position3()).normalized()
		var direction: Vector3 = _horizontal(_wolf._move_target - _wolf.center()).normalized()
		directions.append(direction)
		_check(not _wolf._los_player and _wolf._dist_player > 30.0 and _wolf._threat > 0.9
				and _wolf.mind.count_kind("saw_player") == 0 and absf(expected.dot(hidden_away)) < 0.1,
				"premissa A/B: jogador relocado oculto em rumo distinto do golpe", "dist=%.3f threat=%.3f golpe=%s oculto=%s" % [
				_wolf._dist_player, _wolf._threat, expected, hidden_away])
		_check(_wolf.intent == "flee" and direction.dot(expected) > 0.999
				and absf(direction.dot(hidden_away)) < 0.1,
				"fuga usa LAST hurt, nao jogador oculto", "vetor=%s esperado=%s %s" % [direction, expected, _motion()])
		_advance(19)
		_advance(1, false)
		# A direcao pertence ao centro da decisao, nao ao centro movido pelos tres frames seguintes.
		var after_direction: Vector3 = _horizontal(_wolf._move_target - _wolf.center()).normalized()
		var after_expected: Vector3 = _horizontal(_wolf.center() - hit_from).normalized()
		for frame: int in 3:
			_wolf._physics_process(SimClock.STEP / 3.0)
		var moved: Vector3 = _horizontal(_wolf.body.feet_pos - SPAWN)
		motions.append(moved)
		_check(_wolf._stagger <= 0.0 and _wolf.intent == "flee" and moved.dot(expected) > 0.5
				and after_direction.dot(after_expected) > 0.999 and not _wolf._los_player
				and _wolf.mind.count_kind("hurt") == 1,
				"apos knockback, fuga ainda aponta para longe do ultimo golpe", "stagger=%.4f deslocamento=%s vetor=%s esperado=%s" % [
				_wolf._stagger, moved, after_direction, after_expected])
	_check(directions[0].distance_to(directions[1]) < 0.0001,
			"A/B relocacao oculta nao muda steering apos golpe", "A=%s B=%s" % directions)
	_check(motions[0].distance_to(motions[1]) < 0.0001,
			"A/B mesmo golpe produz mesmo movimento", "A=%s B=%s" % motions)
	return true


func _test_sighting_expiry() -> bool:
	_arm(SPAWN, Vector3(66.0, 51.001, 62.0))
	_advance(1)
	var atom: Dictionary = _wolf.mind.last_atom("saw_player")
	var seen: Vector3 = atom.get("pos", Vector3.ZERO)
	var seen_tick: int = int(atom.get("tick", -1))
	_check(_wolf._los_player and _wolf.intent == "hunt" and _wolf.mind.count_kind("saw_player") == 1
			and seen_tick >= 0 and _horizontal(seen - _player.position3()).length() < 0.01,
			"premissa: avistamento real antes de medir os 6s", "atom=%s %s" % [atom, _motion()])
	_wall(BlockDefs.Block.STONE)
	_player.feet_to_spawn(Vector3(66.0, 51.001, 72.0))
	var parked: Vector3 = _wolf.body.feet_pos
	_advance(1, false)
	_check(not _wolf._los_player and _wolf._dist_player < 30.0 and _distance(seen) > 6.0
			and _horizontal(seen - _player.position3()).length() > 5.0 and _wolf.intent == "hunt"
			and _horizontal(_wolf._move_target - seen).length() < 0.05,
			"parede oculta presa proxima, memoria ainda guia caca", "dist_memoria=%.3f dist_player=%.3f %s" % [_distance(seen), _wolf._dist_player, _motion()])
	var at_deadline: bool = false
	var deadline_motion: String = "nao observado"
	var expired_samples: int = 0
	var hidden_hunts: int = 0
	var hidden_chases: int = 0
	var visible_ticks: int = 0
	# Corpo parado isola a expiracao por idade; a decisao precede o incremento do tick.
	for i: int in 160:
		_advance(1, false)
		var age_ticks: int = _clock.tick - 1 - seen_tick
		if _wolf._los_player:
			visible_ticks += 1
		if age_ticks == 120:
			at_deadline = _wolf.intent == "hunt" and _horizontal(_wolf._move_target - seen).length() < 0.05
			deadline_motion = _motion()
		elif age_ticks > 120:
			expired_samples += 1
			if _wolf.intent == "hunt":
				hidden_hunts += 1
			if _wolf.get("_reaction") in ["buscando ultimo avistamento", "perseguindo presa visivel"]:
				hidden_chases += 1
	_check(at_deadline, "memoria vale no ultimo tick inclusivo de 6s", "idade_ticks=120 %s" % deadline_motion)
	_check(expired_samples == 41 and hidden_hunts == 0 and hidden_chases == 0,
			"apos 6s nao ha caca oculta em nenhum tick", "amostras=%d hunt=%d chase=%d" % [expired_samples, hidden_hunts, hidden_chases])
	var last: Dictionary = _wolf.mind.last_atom("saw_player")
	_check(visible_ticks == 0 and _wolf.mind.count_kind("saw_player") == 1
			and int(last.get("tick", -1)) == seen_tick,
			"parede impede renovacao; episodio persiste mas nao autoriza caca", "los_ticks=%d count=%d tick_visto=%d ultimo=%s" % [
			visible_ticks, _wolf.mind.count_kind("saw_player"), seen_tick, last])
	_check(_wolf.body.feet_pos.distance_to(parked) < 0.0001 and _distance(seen) > 6.0
			and is_zero_approx(_field.total_energy()) and _wolf.hp == Wolf.MAX_HP,
			"premissa mantida: sem chegada, dano ou campo concorrente", "drift=%.6f dist_memoria=%.3f energia=%.6f hp=%.2f" % [
			_wolf.body.feet_pos.distance_to(parked), _distance(seen), _field.total_energy(), _wolf.hp])
	_wall(BlockDefs.Block.AIR)
	return true


func _test_dead_prey() -> bool:
	_arm(SPAWN, Vector3(66.0, 51.001, 62.0))
	_advance(1)
	_check(_wolf.intent == "hunt" and _wolf._los_player and _wolf.mind.count_kind("saw_player") == 1,
			"premissa: caca acaba de iniciar antes da morte", _motion())
	_player.take_damage(_player.max_hp, _wolf.center())
	_advance(1)
	_check(not _player.alive and _wolf.intent == "hunt" and not _wolf._los_player,
			"morte real durante histerese de caca", "hp=%.1f %s" % [_player.hp, _motion()])
	_check(_wolf.get("_reaction") == "patrulhando" and not _wolf._cond_hunt_memory({}),
			"histerese nao executa busca de presa morta", _motion())
	_player.respawn_at(FAR_PLAYER)
	return true


func _test_inspection_hit() -> bool:
	_arm(Vector3(SOURCE.x, 51.001, SOURCE.z), FAR_PLAYER, 2)
	_field.imprint(SOURCE, AetherField.Channel.WORK, 4.0)
	for i: int in 60:
		_advance(1)
		if _wolf._inspect_left > 0.0 and _wolf._inspect_left <= SimClock.STEP + 0.0001:
			break
	_check(_wolf._inspect_left > 0.0 and _wolf._inspect_left <= SimClock.STEP + 0.0001
			and _wolf.mind.count_kind("scent_work") == 0,
			"premissa: ultimo passo antes de concluir inspecao", "left=%.6f %s" % [_wolf._inspect_left, _motion()])
	_wolf.take_damage(0.1, Wolf.ACTOR_PLAYER, _wolf.center() + Vector3(2, 0, 0))
	_check(_wolf._stagger > 0.0 and _horizontal(_wolf.body.velocity).length() >= Wolf.KNOCKBACK_SPEED
			and _wolf.mind.count_kind("hurt") == 1,
			"golpe real interrompe corpo antes da conclusao", "stagger=%.3f %s" % [_wolf._stagger, _motion()])
	_advance(1)
	_check(_wolf.mind.count_kind("scent_work") == 0 and is_zero_approx(_wolf._inspect_left),
			"atordoamento cancela inspecao sem episodio", "left=%.6f count=%d %s" % [
			_wolf._inspect_left, _wolf.mind.count_kind("scent_work"), _motion()])
	return true


func _test_place_renewal() -> bool:
	_arm(Vector3(SOURCE.x, 51.001, SOURCE.z))
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.42)
	for i: int in 60:
		_advance(1)
		if _wolf.mind.count_kind("scent_work") == 1:
			break
	var first: int = _wolf.mind.count_kind("scent_work")
	_check(first == 1 and _distance(SOURCE) <= 1.2,
			"premissa: local examinado antes de nova construcao", "count=%d %s" % [first, _motion()])
	var before: float = _field.sample(SOURCE, AetherField.Channel.WORK)
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.20)
	var after: float = _field.sample(SOURCE, AetherField.Channel.WORK)
	_check(is_equal_approx(after - before, 0.20), "imprint com amplitude real de place",
			"work %.6f -> %.6f delta_ponderado=%.6f" % [before, after, (after - before) * 0.35])
	_advance(6)
	_check(_wolf._scent_found and _wolf.get("_reaction") == "farejando",
			"construcao .20 reabre local antes dos 30s", _motion())
	_advance(45)
	_check(_wolf.mind.count_kind("scent_work") == 2,
			"construcao renovada termina segunda visita", "count=%d %s" % [_wolf.mind.count_kind("scent_work"), _motion()])
	return true


func _test_cache_cap() -> bool:
	# O cache de celulas checadas tem dois limites: o teto de SCENT_MEMORY_CAP e o relogio
	# de SCENT_MEMORY_SECONDS. Nao ha escrita continua: o unico ponto de entrada e o fim de
	# uma inspecao, que grafa um bloco 3x3 em torno da celula encontrada (wolf.gd:283-293).
	# O que manda no tamanho e portanto o intervalo entre inspecoes: com o relogio de 30s
	# cabem floor(30/intervalo)+1 blocos, e o teto de 32 celulas so e tocado quando entra o
	# quarto bloco, ou seja, intervalo de 10s para baixo. A cadeia abaixo sao seis fontes
	# reais em zigue-zague, forcadas em ordem de forca decrescente, e o que se colhe e o
	# instante de cada chegada, o pico do cache, a idade de cada saida e quantos metros o
	# corpo anda por salto. Com isso a checagem diz qual dos dois limites manda hoje, e em
	# que numero a evicao deixaria de ser codigo morto.
	_arm(Vector3(46.0, 51.001, 54.0))
	var cap: int = Wolf.SCENT_MEMORY_CAP
	var ttl: float = Wolf.SCENT_MEMORY_SECONDS
	var spots: Array[Vector3] = [Vector3(46.0, 50.6, 54.0), Vector3(58.0, 50.6, 54.0),
			Vector3(70.0, 50.6, 54.0), Vector3(70.0, 50.6, 66.0), Vector3(58.0, 50.6, 66.0),
			Vector3(46.0, 50.6, 66.0)]
	var amps: Array[float] = [0.84, 0.78, 0.72, 0.66, 0.60, 0.54]
	for i: int in spots.size():
		_field.imprint(spots[i], AetherField.Channel.WORK, amps[i])
	var cache: Dictionary = _wolf.get("_checked_scents")
	var peak: int = cache.size()
	var walked: float = 0.0
	var last_feet: Vector3 = _wolf.body.feet_pos
	var exits: Dictionary = {}
	var arrivals: Array[float] = []
	var episodes: int = _wolf.mind.count_kind("scent_work")
	for i: int in 2000:
		_advance(1)
		peak = maxi(peak, cache.size())
		walked += _horizontal(_wolf.body.feet_pos - last_feet).length()
		last_feet = _wolf.body.feet_pos
		if _wolf.mind.count_kind("scent_work") > episodes:
			episodes += 1
			arrivals.append(_wolf._scent_clock)
			print("CHEGADA %d tick=%d celula=%s cache=%d" % [episodes, _clock.tick, _wolf._scent_cell, cache.size()])
		# Colher na cadencia da percepcao: a varredura de expiracao roda dentro de
		# _find_scent, entao uma saida so pode aparecer num tick em que o scan aconteceu.
		if _clock.tick % 5 == 0:
			var clock: float = _wolf._scent_clock
			for k: Vector3i in cache.keys():
				if not exits.has(k):
					exits[k] = Vector3(float(cache[k].y) - ttl, -1.0, 0.0)
			for k: Vector3i in exits.keys():
				if exits[k].y < 0.0 and not cache.has(k):
					# o tamanho do cache no frame da coleta diz de qual limite saiu:
					# no teto e evicao por FIFO; abaixo dele so o relogio cortava
					exits[k] = Vector3(exits[k].x, clock, float(cache.size()))
			if episodes == spots.size():
				break
	var min_exit: float = 1e9
	var max_exit: float = -1.0
	var gone: int = 0
	var por_evicao: int = 0
	var pico_na_saida: int = 0
	for k: Vector3i in exits.keys():
		if exits[k].y >= 0.0:
			var age: float = exits[k].y - exits[k].x
			min_exit = minf(min_exit, age)
			max_exit = maxf(max_exit, age)
			gone += 1
			if age < ttl - 0.001:
				por_evicao += 1
				pico_na_saida = maxi(pico_na_saida, int(exits[k].z))
	var idade: float = _wolf._scent_clock
	var pace: float = walked / idade
	var gaps: float = 0.0
	for i: int in range(1, arrivals.size()):
		gaps += arrivals[i] - arrivals[i - 1]
	var intervalo: float = gaps / float(maxi(arrivals.size() - 1, 1))
	var salto: float = 0.0
	for i: int in range(1, spots.size()):
		salto += _horizontal(spots[i] - spots[i - 1]).length()
	salto /= float(spots.size() - 1)
	var metros_por_salto: float = walked / float(maxi(arrivals.size() - 1, 1))
	var progressao: float = salto / maxf(intervalo, 0.001)
	# O modelo do proprio codigo: um bloco 3x3 por inspecao, vivo por ttl. Com o relogio
	# de 30s cabem floor(30/intervalo)+1 blocos, entao o pedido e 9 x blocos celulas e o
	# cache fica no menor dos dois limites. Nenhuma checagem abaixo escolhe regime: elas
	# fecham o numero contra o modelo e dizem, pelo que imprimem, qual limite mandou.
	var blocos: int = int(floorf(ttl / maxf(intervalo, 0.001))) + 1
	var predicted: float = 9.0 * float(blocos)
	var limite: float = minf(float(cap), predicted)
	_check(episodes == spots.size() and arrivals.size() >= 4 and gone > 0,
			"premissa: seis inspecoes reais e uma janela inteira de saidas colhida",
			"episodios=%d chegadas=%d saidas=%d vistas=%d idade=%.3f" % [
			episodes, arrivals.size(), gone, exits.size(), idade])
	_check(peak <= cap, "cache nunca passa do teto de 32 celulas",
			"pico=%d teto=%d vistas=%d" % [peak, cap, exits.size()])
	_check(por_evicao == 0 or pico_na_saida >= cap,
			"saida mais jovem que o relogio so existe com o teto em jogo",
			"por_relogio=%d por_evicao=%d tamanho_na_saida=%d saida_mais_jovem=%.3f mais_velha=%.3f ttl=%.1f" % [
			gone - por_evicao, por_evicao, pico_na_saida, min_exit, max_exit, ttl])
	_check(peak == int(limite), "o cache fecha no menor dos dois limites, o teto ou a janela",
			"intervalo=%.3f janela=%.3f blocos=%d pedido=%.0f teto=%d pico=%d saltocelula=%.1f metros_por_salto=%.1f progressao=%.3f m/s=%.3f" % [
			intervalo, ttl, blocos, predicted, cap, peak, salto, metros_por_salto, progressao, pace])
	_check((por_evicao > 0) == (predicted > float(cap)),
			"a evicao por FIFO roda exatamente quando a janela pede mais celulas que o teto",
			"por_evicao=%d pedido=%.0f teto=%d intervalo=%.3f" % [
			por_evicao, predicted, cap, intervalo])
	return true


func _test_locomotion_flat() -> bool:
	# O integrador resolve os tres eixos na mesma chamada e marca bloqueio em qualquer um
	# deles, inclusive no Y quando o corpo desce contra o chao onde ja esta apoiado
	# (voxel_body.gd:52-54, :98). O passo do lobo le esse flag como parede (wolf.gd:537)
	# e re-arma o desvio; se estava apoiado, ainda salta ([:538-541]). Este cenario colhe
	# o corredor sem solido: 26 m de plateu lisa, a presa a vista o tempo todo, e aqui o
	# alvo e `hunt` e nao `investigate` porque o rastro de WORK so e lido num janela de
	# 7x7 celulas em torno do corpo ([:467], [:472-474]) -- uma fonte a 32 m nunca virou
	# investigacao e o que se colheu na primeira tentativa foi o andar da patrulha.
	# Colhe-se: frames de fisica, quantos o corpo passou apoiado, quantos desses o
	# integrador chamou de bloqueio, quantos lancamentos de 5,2 m/s sairam dai e quantos
	# metros o corpo andou por metro ganho. O contador de salto nao pode ser
	# `velocity.y == 5.2`: no build oficial o Vector3 e float32 e o literal e double, e a
	# igualdade e falsa para todo salto (medido: 19 lancamentos, 0 por igualdade). Nada
	# aqui decide ainda: os numeros vao para o commit do conserto, onde a mesma colheita
	# tem de cair a zero sem apagar o desvio do cenario da parede.
	_arm(Vector3(44.0, 51.001, 54.0), Vector3(70.0, 51.001, 54.0))
	var target: Vector3 = _player.position3()
	_advance(1, false)
	var solids: int = 0
	var heights: Dictionary = {}
	for x: int in range(40, 85):
		for z: int in range(40, 85):
			heights[_world.surface_height(x, z)] = true
			for y: int in range(51, 57):
				if _world.is_solid_xyz(x, y, z):
					solids += 1
	var frames: int = 0
	var apoiados: int = 0
	var bloqueados: int = 0
	var pouso_bloqueado: int = 0
	var rearms: int = 0
	var lancamentos: int = 0
	var horizontais: int = 0
	var fora_da_plateau: int = 0
	var walked: float = 0.0
	var last: Vector3 = _wolf.body.feet_pos
	var start: Vector3 = _wolf.body.feet_pos
	var ticks: int = 0
	var hunt_ticks: int = 0
	for i: int in 600:
		ticks += 1
		_advance(1, false)
		if _wolf.intent == "hunt":
			hunt_ticks += 1
		for f: int in 3:
			var sticking_before: float = _wolf._unstick
			_wolf._physics_process(SimClock.STEP / 3.0)
			frames += 1
			walked += _horizontal(_wolf.body.feet_pos - last).length()
			last = _wolf.body.feet_pos
			if _wolf.body.on_ground:
				apoiados += 1
			if _wolf.body.blocked_this_frame:
				bloqueados += 1
			if _wolf.body.blocked_horizontal:
				horizontais += 1
			if _wolf.body.on_ground and _wolf.body.blocked_this_frame:
				pouso_bloqueado += 1
			# o re-arme acontece no mesmo frame em que o desvio expira: a linha 527 desconta
			# o ultimo pedaco e a 538 ja sorteia outro, entao a transicao por `<= 0` nao ve
			if _wolf._unstick > sticking_before + 0.05:
				rearms += 1
			if _launched(_wolf.body):
				lancamentos += 1
			var feet := _wolf.body.feet_pos
			if feet.x < 40.0 or feet.x > 84.0 or feet.z < 40.0 or feet.z > 84.0:
				fora_da_plateau += 1
		if _distance(target) < 2.5:
			break
	var ganho: float = _horizontal(_wolf.body.feet_pos - start).length()
	var razao: float = walked / maxf(ganho, 0.001)
	var tempo: float = float(frames) * (SimClock.STEP / 3.0)
	_check(solids == 0 and heights.size() == 1 and int(heights.keys()[0]) == 50
			and fora_da_plateau == 0 and _wolf._los_player and hunt_ticks >= ticks - 1,
			"premissa: plateu 45x45 sem nenhum solido acima do piso, corpo dentro dela, presa a vista",
			"solidos=%d alturas=%s fora=%d los=%s hunt=%d/%d ticks=%d" % [
			solids, heights.keys(), fora_da_plateau, _wolf._los_player, hunt_ticks, ticks, ticks])
	_check(apoiados > 0 and bloqueados > 0 and pouso_bloqueado >= int(float(apoiados) * 0.9),
			"premissa: dos frames em que o corpo esteve apoiado, quase todos o integrador chamou bloqueio",
			"apoiados=%d bloqueados=%d pouso_bloqueado=%d frames=%d lancamentos=%d rearms=%d" % [
			apoiados, bloqueados, pouso_bloqueado, frames, lancamentos, rearms])
	_check(_distance(target) < 2.5, "o corpo alcanga a presa no corredor livre",
			"percorrido=%.1f ganho=%.1f razao=%.3f rearms=%d lancamentos=%d tempo=%.1f s andamento=%.3f m/s speed=%.1f SPEED_RUN=%.1f" % [
			walked, ganho, razao, rearms, lancamentos, tempo, ganho / maxf(tempo, 0.001), _wolf._speed, Wolf.SPEED_RUN])
	_check(horizontais == 0 and rearms == 0 and lancamentos == 0,
			"contato com o chao nao e obstaculo: sem parede no caminho, nenhum desvio re-arma e nenhum corpo salta",
			"horizontais=%d rearms=%d lancamentos=%d bloqueados=%d pouso_bloqueado=%d frames=%d" % [
			horizontais, rearms, lancamentos, bloqueados, pouso_bloqueado, frames])
	return true


func _test_locomotion_wall() -> bool:
	# O outro braco da atribuicao. O conserto nao pode apagar o desvio diante de um
	# solido de verdade: com parede no caminho o integrador ainda chama bloqueio em X/Z,
	# o passo ainda re-arma e ainda salta. A parede e a mesma do cenario de avistamento
	# (_wall: x=63, seis blocos de altura, a plateau inteira em z) e o alvo e um rastro
	# de WORK atras dela -- ca o intent nao pode ser hunt, porque a linha de visada morre
	# no solido (wolf.gd:441) e sem visada nao ha caca. O que os dois bracos comparam e
	# o caminho, nao a decisao: mesmo chao plano de y=50, mesmo integrador, mesma
	# cadencia de frames, so muda o solido entre o corpo e o alvo.
	#
	# A quinta checagem deste cenario colhe outro defeito, visto pela primeira vez na
	# suite inteira depois do conserto do passo: o corpo encosta na parede e o
	# integrador aceita o passo com a face de fora 1 mm DENTRO do solido, porque o teste
	# de X rala a caixa (box.size.x -= WALL_SHAVE, o 1 mm da constante em
	# voxel_body.gd:9) e o resultado aplicado nao e a caixa testada. Encostado, para o
	# smoke ele esta encaixado
	# ("nenhum lobo com o corpo dentro do terreno" mediu encaixados=1 lobo1 em
	# (56.62563, 36.39333, 23.29462) em tres corridas seguidas), e o resgate vertical
	# nao alcanca um pillar de rocha: medido na sonda, o lift necessario era nenhum
	# (pra cima=-1, pra baixo=-1 nos 4 m varridos) e o lobo congela la dentro.
	_arm(Vector3(54.0, 51.001, 54.0), FAR_PLAYER)
	_wall(BlockDefs.Block.STONE)
	_field.imprint(Vector3(66.0, 50.6, 54.0), AetherField.Channel.WORK, 0.9)
	_advance(1, false)
	_launch_watch(_wolf.body)
	var frames: int = 0
	var apoiados: int = 0
	var bloqueados: int = 0
	var horizontais: int = 0
	var rearms: int = 0
	var lancamentos: int = 0
	var pouso_bloqueado: int = 0
	var invest_ticks: int = 0
	var x_max: float = 0.0
	var ticks: int = 0
	var encaixados: int = 0
	var encaixe_mm: float = 0.0
	for i: int in 200:
		ticks += 1
		_advance(1, false)
		if _wolf.intent == "investigate":
			invest_ticks += 1
		for f: int in 3:
			var sticking_before: float = _wolf._unstick
			_wolf._physics_process(SimClock.STEP / 3.0)
			frames += 1
			x_max = maxf(x_max, _wolf.body.feet_pos.x)
			if _wolf.body.on_ground:
				apoiados += 1
				if _wolf.body.blocked_this_frame:
					pouso_bloqueado += 1
			if _wolf.body.blocked_this_frame:
				bloqueados += 1
			if _wolf.body.blocked_horizontal:
				horizontais += 1
			if _wolf._unstick > sticking_before + 0.05:
				rearms += 1
			if _launched(_wolf.body):
				lancamentos += 1
			# Encosto ou encaixe? O que a checagem abaixo exige e o volume do corpo
			# inteiro fora de solido em todo frame. Quando ha sobreposicao, a sonda mede
			# tambem a profundidade: quanto falta empurrar o corpo de volta em -x ate
			# ele caber. No braco sem conserto a profundidade medida foi exatamente 1 mm
			# -- o WALL_SHAVE (voxel_body.gd:9) que o teste de X aplicava, nao um
			# acidente do relevo.
			if _world.aabb_hits_solid(_wolf.body.aabb()):
				encaixados += 1
				var k: float = 0.0
				while k <= 0.05:
					var box := _wolf.body.aabb()
					box.position.x -= k
					if not _world.aabb_hits_solid(box):
						break
					k += 0.001
				encaixe_mm = maxf(encaixe_mm, k * 1000.0)
	_check(_world.is_solid_xyz(63, 52, 54) and not _wolf._los_player and invest_ticks >= ticks - 2
			and x_max > 60.0,
			"premissa: parede real no caminho e o corpo encosta nela atrae pelo rastro",
			"parede=%s los=%s investigate=%d/%d x_max=%.3f alvo=%s" % [
			_world.is_solid_xyz(63, 52, 54), _wolf._los_player, invest_ticks, ticks, x_max,
			_wolf._move_target])
	_check(horizontais > 0, "na parede o integrador chama bloqueio horizontal",
			"horizontais=%d bloqueados=%d frames=%d apoiados=%d pouso_bloqueado=%d" % [
			horizontais, bloqueados, frames, apoiados, pouso_bloqueado])
	_check(rearms > 0 and lancamentos == 0,
			"contra um muro de seis o desvio re-arma, mas nenhum salto e gasto: saltar ai e so perder altura",
			"rearms=%d lancamentos=%d horizontais=%d frames=%d" % [
			rearms, lancamentos, horizontais, frames])
	_check(x_max < 63.0, "o corpo para do lado de ca da parede",
			"x_max=%.3f teto_bloqueio=63.0 percorrido=%.1f" % [x_max, x_max - 54.0])
	_check(encaixados == 0,
			"encostar na parede nao e encaixar: nenhum frame com o volume dentro de solido",
			"encaixados=%d encaixe_max=%.3f mm frames=%d x_max=%.3f face_x=%.4f" % [
			encaixados, encaixe_mm, frames, x_max, x_max + _wolf.body.dims.x * 0.5])
	_wall(BlockDefs.Block.AIR)
	return true


func _test_degrau_de_um_bloco_lobo_sobe() -> bool:
	# O braco que falta ao "ficam bugados" que o dono ve: o MESMO palco do cenario da
	# parede -- plateu liso, rastro de WORK atras do solido, jogador longe para isso nao
	# virar caca -- com um degrau de UM bloco em vez de seis. Nao entra um salto novo no
	# lobo: o que ele ja dava era baixo demais, e isso e aritmetica do codigo, nao opiniao
	# (5,2 m/s com gravidade 24 da apice de 0,563 m contra os 1,00 m da celula).
	_arm(Vector3(54.0, 51.001, 54.0), FAR_PLAYER)
	_step_column([51])
	_field.imprint(Vector3(66.0, 50.6, 54.0), AetherField.Channel.WORK, 0.9)
	_advance(1, false)
	_launch_watch(_wolf.body)
	var frames: int = 0
	var ticks: int = 0
	var invest_ticks: int = 0
	var lancamentos: int = 0
	var horizontais: int = 0
	var x_max: float = _wolf.body.feet_pos.x
	var y_max: float = _wolf.body.feet_pos.y
	var encostou: bool = false
	for i: int in 400:
		ticks += 1
		_advance(1, false)
		if _wolf.intent == "investigate":
			invest_ticks += 1
		for f: int in 3:
			_wolf._physics_process(SimClock.STEP / 3.0)
			frames += 1
			x_max = maxf(x_max, _wolf.body.feet_pos.x)
			y_max = maxf(y_max, _wolf.body.feet_pos.y)
			if _wolf.body.blocked_horizontal:
				horizontais += 1
			if _wolf.body.blocked_horizontal and _wolf.body.feet_pos.y < 51.5 \
					and _wolf.body.feet_pos.x + Wolf.DIMS.x * 0.5 > 55.9:
				encostou = true
			if _launched(_wolf.body):
				lancamentos += 1
		if x_max > 58.0:
			break
	_check(_world.is_solid_xyz(56, 51, 54) and not _world.is_solid_xyz(56, 52, 54)
			and invest_ticks >= 20 and encostou and horizontais > 0,
			"premissa: degrau de um bloco no caminho, ar livre acima dele, rastro atras e o corpo encosta apoiado",
			"degrau=%s ar_acima=%s investigate=%d/%d encostou=%s horizontais=%d x_max=%.3f y_max=%.3f alvo=%s" % [
			_world.is_solid_xyz(56, 51, 54), _world.is_solid_xyz(56, 52, 54),
			invest_ticks, ticks, encostou, horizontais, x_max, y_max, _wolf._move_target])
	_check(y_max >= 51.001 + 0.95 and x_max > 57.0 and lancamentos > 0,
			"o corpo sobe o degrau de um bloco e passa para o outro lado",
			"y_max=%.3f ganho=%.3f m x_max=%.3f lancamentos=%d frames=%d tempo=%.1f s" % [
			y_max, y_max - 51.001, x_max, lancamentos, frames,
			float(frames) * SimClock.STEP / 3.0])
	# A limpeza vem DEPOIS das checagens: apagada a coluna antes, a premissa acima
	# perguntaria por um degrau que nao existe mais e acusaria o palco, nao o corpo.
	_step_column([])
	return true


## Os dois bracos do auto-pulo do jogador (dossie 19 §3.3) no MESMO degrau de um
## bloco do cenario do lobo. O `wish` nao e escrito na mao: vem de
## `_wish_direction()` lendo a acao `move_forward`, que e o caminho que o teclado
## percorre no jogo, e a tecla `jump` fica solta o tempo todo -- exatamente o
## "quando estou andando, ter um auto pular o bloco" que o dono pediu. O segundo
## braco passa `crouch` apertado: agachar e o "nao me arremesse" do jogador.
func _walk_player_into_step(crouch_held: bool) -> Dictionary:
	_step_column([51])
	var p := _player
	p.feet_to_spawn(Vector3(52.0, 51.001, 54.0))
	# yaw = -PI/2 porque `forward = (-sin(yaw), 0, -cos(yaw))`: assim o
	# `move_forward` aponta para leste, a mesma direcao do degrau em x=56.
	p.yaw = -PI / 2.0
	_launch_watch(p.body)
	var frames := 0
	var lancamentos := 0
	var horizontais := 0
	var na_face := 0
	var predicado := false
	var x_max := p.body.feet_pos.x
	var y_max := p.body.feet_pos.y
	Input.action_press("move_forward")
	if crouch_held:
		Input.action_press("crouch")
	for i: int in 300:
		p.update_local(1.0 / 60.0)
		frames += 1
		x_max = maxf(x_max, p.body.feet_pos.x)
		y_max = maxf(y_max, p.body.feet_pos.y)
		if _launched(p.body):
			lancamentos += 1
		if p.body.blocked_horizontal:
			horizontais += 1
			# A amostra e o frame da decisao: na face do degrau, com o corpo ainda no
			# piso de baixo. Depois do lancamento nao ha mais o que perguntar -- e o pe
			# ja subiu, entao "uma celula acima" cai duas celulas acima do parapeito e
			# o predicado responde falso por construcao, nao por defeito.
			if lancamentos == 0 and p.body.feet_pos.x + Player.DIMS_STAND.x * 0.5 > 55.9:
				na_face += 1
				predicado = predicado or p.body.can_step_over(Vector3(1.0, 0.0, 0.0))
		if x_max > 58.0:
			break
	Input.action_release("move_forward")
	Input.action_release("crouch")
	return {
		"frames": frames, "lancamentos": lancamentos, "horizontais": horizontais,
		"na_face": na_face, "predicado": predicado, "x_max": x_max, "y_max": y_max,
		"dims": str(p.body.dims), "agachado": p.crouching, "painel": p.panel_open,
	}


func _test_degrau_de_um_bloco_jogador_sobe_sem_tecla() -> bool:
	var d := _walk_player_into_step(false)
	_check(not Input.is_action_pressed("jump") and not bool(d["painel"])
			and int(d["na_face"]) > 0 and bool(d["predicado"]),
			"premissa: o jogador anda contra o degrau com a tecla de salto solta",
			"jump=%s painel=%s horizontais=%d na_face=%d predicado=%s dims=%s x_max=%.3f" % [
			Input.is_action_pressed("jump"), d["painel"], d["horizontais"],
			d["na_face"], d["predicado"], d["dims"], d["x_max"]])
	_check(float(d["y_max"]) >= 51.001 + 0.95 and float(d["x_max"]) > 57.0
			and int(d["lancamentos"]) >= 1,
			"o jogador sobe o degrau de um bloco sem apertar espaco",
			"y_max=%.3f ganho=%.3f m x_max=%.3f lancamentos=%d frames=%d tempo=%.1f s" % [
			d["y_max"], float(d["y_max"]) - 51.001, d["x_max"], d["lancamentos"],
			d["frames"], float(d["frames"]) / 60.0])
	_step_column([])
	return true


func _test_agachado_nao_e_arremessado() -> bool:
	var d := _walk_player_into_step(true)
	# O dente da recusa: o mesmo degrau, o MESMO predicado aprovando, e mesmo assim
	# nenhum arremesso. Sem o `predicado=true` aqui em cima a checagem verde estaria
	# afirmando apenas que o corpo agachado nao acha degrau nenhum.
	_check(bool(d["agachado"]) and int(d["na_face"]) > 0 and bool(d["predicado"])
			and float(d["y_max"]) < 51.001 + 0.05 and int(d["lancamentos"]) == 0
			and float(d["x_max"]) < 56.0,
			"agachado encosta no degrau que o predicado aprova e continua do lado de ca",
			"agachado=%s dims=%s na_face=%d predicado=%s y_max=%.3f ganho=%.3f m lancamentos=%d x_max=%.3f frames=%d" % [
			d["agachado"], d["dims"], d["na_face"], d["predicado"], d["y_max"],
			float(d["y_max"]) - 51.001, d["lancamentos"], d["x_max"], d["frames"]])
	_step_column([])
	return true


## A coluna de teste do degrau: so as linhas de y listadas ficam solidas em x=56, o resto
## do canudo vira ar de proposito, porque o braco de teto baixo precisa de um solido
## SUSPENSO (y=53) com uma celula livre embaixo dele (y=52).
func _step_column(rows: Array) -> void:
	for z: int in range(40, 85):
		for y: int in range(51, 58):
			_world.set_block(Vector3i(56, y, z),
					BlockDefs.Block.STONE if y in rows else BlockDefs.Block.AIR)


## O pe nao e escrito a mao: e onde o integrador para o corpo. Andar para leste com a
## velocidade do lobo ate o bloqueio horizontal, e devolver o corpo parado -- o mesmo
## caminho que o jogo percorre antes de perguntar qualquer coisa sobre salto.
func _walked_into_step(dims: Vector3) -> VoxelBody:
	var b := VoxelBody.new()
	b.setup(_world, Vector3(52.0, 51.001, 54.0), dims)
	b.velocity = Vector3(Wolf.SPEED_WALK, 0.0, 0.0)
	for i: int in 200:
		b.move_and_collide(SimClock.STEP / 3.0)
		if b.blocked_horizontal:
			break
	return b


func _test_predicado_degrau_recusa_teto_baixo() -> bool:
	# O predicado sozinho, sem um salto disparado: "a um bloco acima, na direcao que eu
	# quero ir, existe onde ficar de pe?". E a pergunta que separa o talude de um bloco,
	# que se sobe, do muro onde saltar e desperdicio -- e a resposta so depende da caixa
	# do corpo, por isso os bracos usam as constantes reais dos dois (Wolf.DIMS,
	# wolf.gd:72; Player.DIMS_STAND, player.gd:25) em corpos andando de verdade contra a
	# coluna. O braco de teto e o que da dente ao "nao e pular em tudo que encosta":
	# o lobo de 0,95 cabe no vao de 1,00 e salta, o jogador de 1,80 nao cabe e recusa.
	var east := Vector3(1.0, 0.0, 0.0)
	var premise := ""
	var face_gap: float = 0.0
	# [rotulo, linhas solidas em x=56, esperado lobo, esperado jogador]
	var arms: Array = [
		["degrau de um bloco, ar acima", [51], true, true],
		["muro de dois blocos", [51, 52], false, false],
		["degrau com teto a uma celula do parapeito", [51, 53], true, false],
		["penhasco de seis", [51, 52, 53, 54, 55, 56], false, false],
	]
	for arm: Array in arms:
		var label: String = arm[0]
		_step_column(arm[1])
		var wb := _walked_into_step(Wolf.DIMS)
		var pb := _walked_into_step(Player.DIMS_STAND)
		var got_lobo: bool = wb.can_step_over(east)
		var got_jogador: bool = pb.can_step_over(east)
		if premise == "":
			# A face do corpo encosta no degrau e o corpo para antes dela, nunca dentro:
			# sem essa premissa o "parado colado no bloco" dos bracos abaixo seria um pe
			# inventado, e o predicado estaria sendo perguntado longe de qualquer bloqueio.
			face_gap = 56.0 - (wb.feet_pos.x + Wolf.DIMS.x * 0.5)
			var embedded := _world.aabb_hits_solid(wb.aabb()) or _world.aabb_hits_solid(pb.aabb())
			premise = "gap_face=%.4f m" % face_gap
			_check(wb.blocked_horizontal and pb.blocked_horizontal and not embedded
					and face_gap >= 0.0 and face_gap < 0.05,
					"premissa: o integrador para os dois corpos diante da face de x=56, sem encaixe",
					"%s bloqueio=%s/%s pe=%s/%s encaixado=%s" % [
					premise, wb.blocked_horizontal, pb.blocked_horizontal, wb.feet_pos, pb.feet_pos, embedded])
		_check(got_lobo == bool(arm[2]) and got_jogador == bool(arm[3]),
				"%s: lobo %s, jogador %s" % [label, arm[2], arm[3]],
				"obtido lobo=%s jogador=%s %s rows=%s alcance=%.3f/%.3f" % [
				got_lobo, got_jogador, premise, arm[1],
				maxf(wb.dims.x, wb.dims.z) * 0.5 + 0.6, maxf(pb.dims.x, pb.dims.z) * 0.5 + 0.6])
	_step_column([])
	var bare := VoxelBody.new()
	bare.setup(_world, Vector3(52.0, 51.001, 54.0), Wolf.DIMS)
	_check(not bare.can_step_over(Vector3.ZERO) and not bare.can_step_over(Vector3(0.0, 5.0, 0.0))
			and not bare.can_step_over(Vector3(1.0, 0.0, 0.0)),
			"sem parede no caminho e sem direcao plana o predicado nao e um convite ao salto",
			"zero=%s vertical=%s plano_coluna_limpa=%s" % [
			bare.can_step_over(Vector3.ZERO), bare.can_step_over(Vector3(0.0, 5.0, 0.0)),
			bare.can_step_over(east)])
	return true


## Os 1 000 frames de sessao de um braco de custo (dossie 19, checagem 6). O caminho
## e o frame real do jogo: `_physics_process` de `main.gd` e `player.update_local` +
## `clock.advance` + `_sim_tick` entre o `begin_step`/`end_step` do proprio relógio,
## entao `worst_sim_ms` e `dropped_ticks` que saem daqui sao os mesmos dois numeros
## que o overlay F3 mostra -- colhidos pela API publica `diagnostics()`, nao por um
## cronometro paralelo inventado aqui.
## O braco da face e o pior caso honesto: degrau com teto a uma celula do parapeito
## (o mesmo `[51, 53]` da checagem 5), onde o auto-pulo e perguntado em todo frame
## de bloqueio e responde "nao" -- o corpo encosta para sempre e gasta o predicado
## sem gastar um salto. O lobo fica do outro lado do palco, em (70, 74), para o delta
## entre os bracos ser o do jogador, nao uma ronda que atravessa a coluna.
func _cost_arm(rows: Array) -> Dictionary:
	_pack_release()
	_arm(Vector3(54.0, 51.001, 54.0), FAR_PLAYER)
	_step_column(rows)
	_pack_session(1)
	_pack_place(0, Vector3(70.0, 51.001, 74.0))
	var p := _player
	p.feet_to_spawn(Vector3(52.0, 51.001, 54.0))
	# yaw = -PI/2: `forward = (-sin(yaw), 0, -cos(yaw))` aponta para leste, a mesma
	# direcao da coluna em x=56. O `move_forward` apertado o tempo todo e o que faz o
	# passo ler `wish != ZERO` -- sem mapa de acao instalado nada andaria, e o braco
	# mediria um corpo parado chamando-se de workload.
	p.yaw = -PI / 2.0
	_launch_watch(p.body)
	var frames := 0
	var horizontais := 0
	var na_face := 0
	var lancamentos := 0
	var viradas := 0
	var total_us := 0
	var pior_us := 0
	var tick0: int = int(_session.diagnostics()["tick"])
	var para_leste := true
	Input.action_press("move_forward")
	for i: int in 1000:
		var t0: int = Time.get_ticks_usec()
		_session._physics_process(SimClock.STEP)
		var cost: int = Time.get_ticks_usec() - t0
		total_us += cost
		pior_us = maxi(pior_us, cost)
		frames += 1
		if p.body.blocked_horizontal:
			horizontais += 1
			if p.body.feet_pos.x + Player.DIMS_STAND.x * 0.5 > 55.9:
				na_face += 1
		if _launched(p.body):
			lancamentos += 1
		# O plateu da fixture vai de 40 a 85 em cada eixo: virar o corpo no fim do
		# corredor e o unico jeito de caminhar 1 000 frames sem sair do chao plano. A
		# virada e por banda, nao por frame: `velocity` tem inercia, entao testar so a
		# coordenada prendia o corpo no limiar com o yaw trocando de sinal a cada frame
		# (medido: 869 viradas em 1 000 frames, o braco "andando" parado em x=80).
		if para_leste and p.body.feet_pos.x > 78.0:
			p.yaw += PI
			para_leste = false
			viradas += 1
		elif not para_leste and p.body.feet_pos.x < 46.0:
			p.yaw += PI
			para_leste = true
			viradas += 1
	Input.action_release("move_forward")
	var d: Dictionary = _session.diagnostics()
	return {
		"frames": frames, "horizontais": horizontais, "na_face": na_face,
		"lancamentos": lancamentos, "viradas": viradas,
		"total_us": total_us, "pior_us": pior_us,
		"media_us": float(total_us) / float(maxi(frames, 1)),
		"passos": int(d["tick"]) - tick0,
		"worst_sim_ms": float(d["worst_sim_ms"]),
		"dropped": int(d["dropped_ticks"]),
		"x_max": p.body.feet_pos.x, "vivo": p.alive,
	}


func _test_pulo_nao_custou_passo_de_ninguem() -> bool:
	# O contrato de custo do dossie 19 §4: o pulo novo mora no frame de fisica, e o
	# que ele nao pode fazer e estourar a regua. Comparar os bracos por tempo absoluto
	# seria um gate de ruido da maquina -- dois processo na mesma arvore ja trocaram de
	# lugar aqui -- entao o gate e a regua dentro de cada braco (25 ms, a mesma do
	# dossie 17 para cascata) e a atribuicao e pela composicao impressa: quantos frames
	# de bloqueio, quantos pedidos de predicado na face e quantos saltos existem em um
	# e no outro. O `lancamentos == 0` da face e o dente: sem ele o braco verde poderia
	# estar dizendo apenas que o corpo andou livre.
	var flat := _cost_arm([])
	var face := _cost_arm([51, 53])
	_step_column([])
	_check(bool(flat["vivo"]) and bool(face["vivo"])
			and int(flat["frames"]) == 1000 and int(face["frames"]) == 1000
			and int(flat["passos"]) == 1000 and int(face["passos"]) == 1000
			and int(flat["horizontais"]) == 0 and int(face["na_face"]) > 0
			and int(face["lancamentos"]) == 0,
			"premissa: 1 000 frames de sessao por braco, nenhum bloqueio no plano e o predicado perguntado na face sem um salto",
			"plano: vivo=%s frames=%d passos=%d horizontais=%d | face: vivo=%s frames=%d passos=%d horizontais=%d na_face=%d lancamentos=%d x_max=%.3f viradas=%d/%d" % [
			flat["vivo"], flat["frames"], flat["passos"], flat["horizontais"],
			face["vivo"], face["frames"], face["passos"], face["horizontais"],
			face["na_face"], face["lancamentos"], face["x_max"],
			flat["viradas"], face["viradas"]])
	_check(float(flat["worst_sim_ms"]) <= 25.0 and float(face["worst_sim_ms"]) <= 25.0
			and int(flat["dropped"]) == 0 and int(face["dropped"]) == 0,
			"nenhum passo de simulacao acima da regua de 25 ms e nenhum tick perdido, nos dois bracos",
			"plano worst_sim=%.2f ms dropped=%d | face worst_sim=%.2f ms dropped=%d" % [
			flat["worst_sim_ms"], flat["dropped"], face["worst_sim_ms"], face["dropped"]])
	_check(float(flat["pior_us"]) <= 25000 and float(face["pior_us"]) <= 25000,
			"o frame integral onde o pulo mora fica abaixo da mesma regua nos dois bracos",
			"plano total=%d us media=%.1f us pior=%d us | face total=%d us media=%.1f us pior=%d us" % [
			flat["total_us"], flat["media_us"], flat["pior_us"],
			face["total_us"], face["media_us"], face["pior_us"]])
	_pack_release()
	return true


## Caverna sob o teto do palco: piso solido em y=44, ar em 45..47, teto em 48..50.
## A grade de Eter tem celula de 4 blocos (VoxelConfig.AETHER_CELL), entao o ar da
## caverna inteiro mora na camada 11 enquanto o lobo em cima do teto esta na camada 12.
func _cave_carve() -> void:
	for x: int in range(56, 74):
		for z: int in range(56, 70):
			_world.set_block(Vector3i(x, 44, z), BlockDefs.Block.STONE)
			for y: int in range(45, 48):
				_world.set_block(Vector3i(x, y, z), BlockDefs.Block.AIR)
			for y: int in range(48, 51):
				_world.set_block(Vector3i(x, y, z), BlockDefs.Block.STONE)


func _test_scent_cave_layer() -> bool:
	# O leitor varria uma camada de Eter so — a do lobo — e projetava o alvo na superficie
	# mais alta da coluna. Os dois bracos abaixo tem a mesma amplitude, o mesmo deslocamento
	# horizontal e a mesma distancia; so a camada de Y muda, entao o que separa um do outro e
	# a camada, nao a geometria do palco nem o alcance do raio.
	_cave_carve()
	var cave := Vector3(70.0, 46.0, 62.0)
	var above := Vector3(70.0, 51.0, 62.0)
	var cave_cell: Vector3i = _field.cell_of_world(cave)
	var above_cell: Vector3i = _field.cell_of_world(above)
	_arm(Vector3(62.0, 51.001, 62.0), FAR_PLAYER, 3)
	var wolf_cell: Vector3i = _field.cell_of_world(_wolf.center())
	_field.imprint(cave, AetherField.Channel.BLOOD, 0.42)
	_check(cave_cell.y == wolf_cell.y - 1
			and _horizontal(cave - _wolf.center()).length() <= float(Wolf.SCENT_RADIUS) * 4.0
			and is_equal_approx(_field.sample(cave, AetherField.Channel.BLOOD), 0.42),
			"premissa: rastro uma camada abaixo, dentro do raio horizontal",
			"lobo_cam=%d rastro_cam=%d dxz_cells=%d desloc=%.1f m amplitude=%.3f" % [
			wolf_cell.y, cave_cell.y, above_cell.x - wolf_cell.x,
			_horizontal(cave - _wolf.center()).length(),
			_field.sample(cave, AetherField.Channel.BLOOD)])
	_check(is_zero_approx(_field.sample_cell(
			Vector3i(cave_cell.x, wolf_cell.y, cave_cell.z), AetherField.Channel.BLOOD)),
			"premissa: a camada que o leitor varre esta vazia",
			"camada_do_lobo=%.4f camada_de_baixo=%.4f" % [_field.sample_cell(
			Vector3i(cave_cell.x, wolf_cell.y, cave_cell.z), AetherField.Channel.BLOOD),
			_field.sample_cell(cave_cell, AetherField.Channel.BLOOD)])
	_advance(1)
	_check(_wolf._scent_found and _wolf._scent_cell == cave_cell
			and _wolf._scent_channel == AetherField.Channel.BLOOD,
			"leitor acha o rastro uma camada abaixo",
			"found=%s celula=%s esperado=%s forca=%.4f intent=%s %s" % [
			_wolf._scent_found, _wolf._scent_cell, cave_cell, _wolf._scent_strength,
			_wolf.intent, _motion()])
	_check(_wolf._scent_pos.y < 48.0 and _wolf._scent_pos.y > 43.0,
			"alvo projetado no piso da caverna, nao no teto da superficie",
			"alvo=%s surface_height=%d" % [_wolf._scent_pos, _world.surface_height(
			int(_wolf._scent_pos.x), int(_wolf._scent_pos.z))])
	_arm(Vector3(62.0, 51.001, 62.0), FAR_PLAYER, 3)
	_field.imprint(above, AetherField.Channel.BLOOD, 0.42)
	_check(above_cell.y == wolf_cell.y
			and is_equal_approx(above.y - cave.y, 5.0)
			and is_zero_approx(_horizontal(above - cave).length()),
			"premissa do controle: mesma coluna, camada do lobo, 5 m mais alto",
			"lobo_cam=%d rastro_cam=%d vertical=%.1f m horizontal=%.3f m" % [
			wolf_cell.y, above_cell.y, above.y - cave.y, _horizontal(above - cave).length()])
	_advance(1)
	_check(_wolf._scent_found and _wolf._scent_cell == above_cell
			and absf(_wolf._scent_pos.y - 50.6) < 0.01,
			"controle: rastro na camada do lobo acha o alvo na superficie de sempre",
			"found=%s celula=%s alvo=%s forca=%.4f" % [
			_wolf._scent_found, _wolf._scent_cell, _wolf._scent_pos, _wolf._scent_strength])
	return true


## Premissa do dossie 09.1: o identificador de bioma tem de ser FUNCAO do mundo
## (seed, x, z, h), nao da instancia que o calcula. Duas `WorldGen` com a mesma
## semente, a mesma grade 16x16, e a contagem de celulas divergentes -- 0.
##
## A segunda checagem nao e enfeite: sem mais de um bioma na grade amostrada, a
## primeira passaria sobre um campo constante e "identico" nao decidiria nada.
func _test_biome() -> bool:
	var gen_a := WorldGen.new()
	var gen_b := WorldGen.new()
	gen_a.setup(SEED)
	gen_b.setup(SEED)
	var dif: int = 0
	var colunas: int = 0
	var census := {}
	for x: int in range(0, VoxelConfig.world_size_x(), 8):
		for z: int in range(0, VoxelConfig.world_size_z(), 8):
			var bi_a: int = gen_a.biome_of(x, z, gen_a.surface_height(x, z))
			var bi_b: int = gen_b.biome_of(x, z, gen_b.surface_height(x, z))
			colunas += 1
			census[bi_a] = int(census.get(bi_a, 0)) + 1
			if bi_a != bi_b:
				dif += 1
	var nomes := ""
	var biomas := 0
	for id: int in [WorldGen.Biome.FROZEN, WorldGen.Biome.ARID,
			WorldGen.Biome.TEMPERATE, WorldGen.Biome.WETLAND]:
		if int(census.get(id, 0)) > 0:
			biomas += 1
		nomes += "%s=%d " % [WorldGen.BIOME_NAMES[id], int(census.get(id, 0))]
	_check(dif == 0 and colunas == 256, "bioma_deterministico",
			"divergentes=%d  colunas=%d" % [dif, colunas])
	_check(biomas > 1, "premissa: a grade 16x16 cobre mais de um bioma",
			"biomas=%d  %s" % [biomas, nomes.strip_edges()])
	return true


## Lobo montado so para ler o pelo: casa na coluna (x, z) pela altura GERADA dela,
## sem andar e sem decidir nada.
func _lobo_na_coluna(x: int, z: int, pid: int) -> Wolf:
	var w := Wolf.new()
	_stage.add_child(w)
	w.setup(_world, _field, _player,
			Vector3(float(x), float(_world.gen.surface_height(x, z) + 1), float(z)),
			pid, _clock)
	return w


## Premissa 1 do dossie 09 no que o jogador ve: dois lobos em colunas de biomas
## diferentes tem de sair com material de pelo diferente, e dois lobos no mesmo
## bioma com a MESMA cor. As colunas nao sao sorteadas — sao a primeira e a ultima
## que o proprio `biome_at` do mundo gerado nomeia para cada bioma, porque "lobo
## no bioma X" so vale se o gen diz X. O numero que decide e o hex de cada pelo,
## impresso com o bioma do seu `home`.
func _test_fur_colour() -> bool:
	_arm()
	var primeira := {}
	var ultima := {}
	for x: int in range(6, VoxelConfig.world_size_x() - 6, 3):
		for z: int in range(6, VoxelConfig.world_size_z() - 6, 3):
			var b: int = _world.gen.biome_at(x, z)
			if not primeira.has(b):
				primeira[b] = Vector2i(x, z)
			ultima[b] = Vector2i(x, z)
	var achados: Array = []
	var nomes := ""
	for id: int in [WorldGen.Biome.FROZEN, WorldGen.Biome.ARID,
			WorldGen.Biome.TEMPERATE, WorldGen.Biome.WETLAND]:
		if primeira.has(id):
			achados.append(id)
			nomes += "%s " % WorldGen.BIOME_NAMES[id]
	_check(achados.size() >= 2, "premissa: a semente da colunas de dois biomas",
			"biomas=%d  %s" % [achados.size(), nomes.strip_edges()])
	var letras := ["a", "b", "c"]
	var lobos: Array = []
	var linhas := ""
	for i: int in range(3):
		var id: int = achados[0]
		if i == 1 and achados.size() > 1:
			id = achados[1]
		# a e c: mesmo bioma em colunas diferentes. b: o bioma seguinte da lista.
		var tabela: Dictionary = ultima if i == 2 else primeira
		var coluna: Vector2i = tabela[id]
		var lobo := _lobo_na_coluna(coluna.x, coluna.y, 90 + i)
		lobos.append(lobo)
		linhas += "%s[%s %s] " % [letras[i], WorldGen.BIOME_NAMES[id],
				lobo._fur.albedo_color.to_html(false)]
	_check(is_instance_valid(lobos[0]) and is_instance_valid(lobos[1])
			and is_instance_valid(lobos[2])
			and lobos[0]._fur.albedo_color != lobos[1]._fur.albedo_color
			and lobos[0]._fur.albedo_color == lobos[2]._fur.albedo_color,
			"cor_do_pelo_vem_do_bioma", linhas.strip_edges())
	for solto in lobos:
		solto.free()
	var cores := {}
	var tabela_hex := ""
	for cor in Wolf.FUR_COLORS:
		cores[cor.to_html(false)] = true
		tabela_hex += "%s " % cor.to_html(false)
	_check(cores.size() == Wolf.FUR_COLORS.size(),
			"premissa: os quatro pares da tabela dao quatro cores diferentes",
			"cores=%d/%d  %s" % [cores.size(), Wolf.FUR_COLORS.size(),
					tabela_hex.strip_edges()])
	_check(Wolf.FUR_COLORS[WorldGen.Biome.TEMPERATE] == Color(0.40, 0.36, 0.31),
			"temperate conserva a cor historica do lobo",
			"cor=%s" % Wolf.FUR_COLORS[WorldGen.Biome.TEMPERATE].to_html(false))
	return true


## Checagem 4 do dossie 09: o vies de imprint por bioma e do chamador, e os dois
## lados dessa fronteira tem de poder ficar vermelhos. A tabela esperada e a
## copia literal deste arquivo (BIAS_MEDIDA), nao uma leitura do gen: editar um
## multiplicador em WorldGen pinica vermelho. Mover o vies para dentro de
## `AetherField.imprint` pinica a fonte crua, que tem de devolver o valor do
## evento sem nada, e o helper do lobo passaria a multiplicar duas vezes. O
## numero que decide e o par sem/com por canal, a razao e o bioma da coluna.
func _test_imprint_bias() -> bool:
	var colunas := {}
	for x: int in range(6, VoxelConfig.world_size_x() - 6, 3):
		for z: int in range(6, VoxelConfig.world_size_z() - 6, 3):
			var b: int = _world.gen.biome_at(x, z)
			if not colunas.has(b):
				colunas[b] = Vector2i(x, z)
	# Pino linha a linha por leitura DIRETA da tabela, nao so pela composta: esta
	# semente nao expoe arid em nenhuma coluna do mundo, e uma linha sem casa nao
	# pode sair do gate sem conferencia. Onde existe coluna, a leitura composta
	# (biome_of -> linha -> canal) tambem tem de bater com a copia medida, senao
	# trocar a ordem das duas tabelas passaria. Guardas de forma antes de indexar
	# porque tabela encolhida tem de dar vermelho de checagem, nao de script.
	var pino_ok: bool = WorldGen.IMPRINT_BIAS.size() == BIAS_MEDIDA.size()
	var linhas_t := ""
	for bi: int in [WorldGen.Biome.FROZEN, WorldGen.Biome.ARID,
			WorldGen.Biome.TEMPERATE, WorldGen.Biome.WETLAND]:
		if bi >= WorldGen.IMPRINT_BIAS.size():
			pino_ok = false
			linhas_t += "%s sem linha; " % WorldGen.BIOME_NAMES[bi]
			continue
		var row: Array = WorldGen.IMPRINT_BIAS[bi]
		if row.size() != AetherField.Channel.COUNT:
			pino_ok = false
		var tem_casa: bool = colunas.has(bi)
		var cc: Vector2i = colunas[bi] if tem_casa else Vector2i(0, 0)
		var hh: int = _world.gen.surface_height(cc.x, cc.y) if tem_casa else 0
		for ch: int in AetherField.Channel.COUNT:
			var direto: float = float(row[ch]) if ch < row.size() else -1.0
			var medido: float = float(BIAS_MEDIDA[bi][ch])
			if absf(direto - medido) > 0.0001:
				pino_ok = false
			if tem_casa and absf(_world.gen.imprint_bias(cc.x, cc.y, hh, ch) - medido) > 0.0001:
				pino_ok = false
			linhas_t += "%s/%s=%.2f " % [WorldGen.BIOME_NAMES[bi],
					AetherField.CHANNEL_NAMES[ch], direto]
	_check(pino_ok, "premissa: vies_lido_confirma_tabela_medida", linhas_t.strip_edges())
	# A mesma fonte nos mesmos lugares, crua pelo campo e vies pelo helper do
	# lobo (o caminho real dos eventos), com as quantias lidas do proprio
	# batch: lavra WORK 0,42, morte BLOOD 1,3 e FEAR 1,0.
	var amounts: Array = [0.42, 1.3, 1.0]
	var crua_ok := true
	var ordem_ok := true
	var linhas_ab := ""
	var feitos := 0
	for bi: int in [WorldGen.Biome.FROZEN, WorldGen.Biome.ARID,
			WorldGen.Biome.TEMPERATE, WorldGen.Biome.WETLAND]:
		if not colunas.has(bi):
			continue
		var cc: Vector2i = colunas[bi]
		var hh: int = _world.gen.surface_height(cc.x, cc.y)
		var pos := Vector3(float(cc.x) + 0.5, float(hh + 1), float(cc.y) + 0.5)
		_arm()
		var bruto: Array = []
		for ch: int in AetherField.Channel.COUNT:
			_field.imprint(pos, ch, float(amounts[ch]))
			bruto.append(_field.sample(pos, ch))
		_arm()
		var vies: Array = []
		for ch: int in AetherField.Channel.COUNT:
			_wolf._imprint(pos, ch, float(amounts[ch]))
			vies.append(_field.sample(pos, ch))
		feitos += 1
		for ch: int in AetherField.Channel.COUNT:
			var medido: float = float(BIAS_MEDIDA[bi][ch])
			var b0: float = float(bruto[ch])
			var b1: float = float(vies[ch])
			var razao: float = b1 / maxf(b0, 1e-9)
			if not is_equal_approx(b0, float(amounts[ch])):
				crua_ok = false
			if not (is_equal_approx(b1, float(amounts[ch]) * medido)
					and absf(razao - medido) < 0.01
					and razao >= 0.5 and razao <= 2.0
					and b1 > 0.0 and b1 < AetherField.MAX_VALUE):
				ordem_ok = false
			linhas_ab += "bioma=%d(%s) %s sem=%.4f com=%.4f razao=%.4f  " % [
					bi, WorldGen.BIOME_NAMES[bi], AetherField.CHANNEL_NAMES[ch],
					b0, b1, razao]
	_check(crua_ok, "premissa: imprint cru no campo devolve o valor do evento",
			"esperado=%.2f/%.2f/%.2f  colhido: %s" % [
			float(amounts[0]), float(amounts[1]), float(amounts[2]), linhas_ab])
	_check(ordem_ok and feitos >= 2, "imprint_bioma_tem_mesma_ordem",
			"biomas_colhidos=%d  %s" % [feitos, linhas_ab.strip_edges()])
	# Media do vies por canal sobre as quatro linhas da tabela: o pedido e
	# redistribuicao, nao inflacao — a banda 1,00 +/- 0,10 contem os valores
	# medidos desta revisao (trabalho 1,0000; sangue e medo 1,0125), e uma linha
	# grossamente editada sai dela antes mesmo da leitura composta chegar ao
	# chamador. O pino acima e que confere multiplicador a multiplicador.
	var banda_ok: bool = WorldGen.IMPRINT_BIAS.size() == BIAS_MEDIDA.size()
	var soma_tab: Array[float] = [0.0, 0.0, 0.0]
	var linhas := 0
	for bi: int in [WorldGen.Biome.FROZEN, WorldGen.Biome.ARID,
			WorldGen.Biome.TEMPERATE, WorldGen.Biome.WETLAND]:
		if bi >= WorldGen.IMPRINT_BIAS.size() \
				or (WorldGen.IMPRINT_BIAS[bi] as Array).size() != AetherField.Channel.COUNT:
			banda_ok = false
			continue
		var rw: Array = WorldGen.IMPRINT_BIAS[bi]
		linhas += 1
		for ch: int in AetherField.Channel.COUNT:
			soma_tab[ch] += float(rw[ch]) / float(BIAS_MEDIDA.size())
	var medias := ""
	for ch: int in AetherField.Channel.COUNT:
		var m: float = soma_tab[ch]
		if m < 0.90 or m > 1.10:
			banda_ok = false
		medias += "%s=%.4f " % [AetherField.CHANNEL_NAMES[ch], m]
	_check(banda_ok, "media do vies por canal dentro da banda medida",
			"linhas=%d  %s" % [linhas, medias.strip_edges()])
	return true


# ------------------------------------------------------------------ alcateia (dossie 10)

## Sessao real (`main.gd`) fora da arvore de cenario, sobre o plateau da fixture:
## `pack_of`, `_rebuild_packs` e o `Callable` bindado sao os de `main.gd`, sem
## boot de HUD, oraculo e audio -- o mesmo truque de `simulation_rng_test.gd`. Os
## lobos vem do `_spawn_wolves` verdadeiro e sao reposicionados depois, porque a
## geometria de um gate tem de ser lida no log, nao sorteada.
##
## `mating` (dossie 11 §3.4) deixa a roda de acasalamento viva; parada por
## padrao, porque quatro adultos a 3 ou 4 m um do outro, saciados e inteiros,
## criariam um filhote no tick 1 e o censo dos gates de ronda, cerco, escalonamento
## e farejo deixaria de ser o numero escrito na geometria -- os indices `ws[0..3]`
## passariam a apontar para outra matilha. Prender o relogio da roda e o mesmo
## tipo de isolacao que `move_body=false` ja faz com os corpos: nenhum campo de
## animal e escrito, nenhuma transicao e pulada, e as tres checagens de acasalamento
## rodam com a roda andando. A sessao real do smoke nao prende nada -- ali os
## nascimentos acontecem sozinhos e a suíte os conta.
func _pack_session(n: int, mating: bool = false) -> void:
	_pack_release()
	var s = Session.new()
	s.world = _world
	s.aether = _field
	s.clock = _clock
	s.player = _player
	s._entities = Node3D.new()
	_stage.add_child(s._entities)
	s._spawn_wolves(n)
	if not mating:
		s._mate_cd = INF
	_session = s
	for i: int in mini(n, PACK_SPOTS.size()):
		_pack_place(i, PACK_SPOTS[i])


func _pack_place(i: int, spot: Vector3) -> void:
	var w: Wolf = _session.wolves[i]
	w.body.feet_pos = spot
	w.body.velocity = Vector3.ZERO
	w.home = spot
	w._move_target = spot


func _pack_release() -> void:
	if _session == null:
		return
	if is_instance_valid(_session._entities):
		_session._entities.free()
	# O hud e da sessao: sem libera-lo, cada `_boot_session` empilharía um Label
	# vivo no palco e a leitura do toast deixaria de apontar para o hud que a
	# sessao atual usa.
	if is_instance_valid(_session.hud):
		_session.hud.free()
	_session.free()
	_session = null


func _pack_wolves() -> Array:
	return _session.wolves


func _wolf_of(ws: Array, ident: int) -> Wolf:
	for w: Wolf in ws:
		if w.identity == ident:
			return w
	return null


## Um passo de 20 Hz da sessao inteira, pelo caminho real (`_sim_tick`, com o
## rebuild antes do laco de lobos). O custo vai para os contadores da alcateia:
## somar `sim_tick` (que inclui a difusao) no rodape historico de lobo solo
## quebraria a comparacao pareada branch x chao das rodadas anteriores.
func _advance_pack(ticks: int, move_body: bool = false) -> void:
	for i: int in ticks:
		var trips_delta: int = 0
		for w: Wolf in _session.wolves:
			trips_delta -= w._guard.trips
		var start: int = Time.get_ticks_usec()
		_session._sim_tick()
		var cost: int = Time.get_ticks_usec() - start
		_pack_sim_us += cost
		_pack_sim_worst_us = maxi(_pack_sim_worst_us, cost)
		for w: Wolf in _session.wolves:
			_pack_bt_us += w._guard.last_us
			_pack_bt_worst_us = maxi(_pack_bt_worst_us, w._guard.last_us)
			trips_delta += w._guard.trips
		_pack_bt_trips += trips_delta
		_pack_steps += 1
		if move_body:
			for w: Wolf in _session.wolves:
				for frame: int in 3:
					w._physics_process(SimClock.STEP / 3.0)


func _pack_lists() -> String:
	var out := ""
	for w: Wolf in _pack_wolves():
		out += "lobo%d(%d viz) " % [w.identity, w._pack.size()]
	return out.strip_edges()


## Checagem 5 do dossie 10, mais o contrato de formato da leitura. O cursor da
## RNG da populacao e colhido sem consume-la: o estado e copiado para uma
## geradora descartavel e o proximo valor dela e a assinatura do cursor.
func _rng_cursor(rng: RandomNumberGenerator) -> float:
	var probe := RandomNumberGenerator.new()
	probe.state = rng.state
	return probe.randf()


func _test_pack_provider() -> bool:
	_arm()
	_pack_session(4)
	var ws: Array = _pack_wolves()
	var mounted := true
	var binds := ""
	for w: Wolf in ws:
		var bound: Array = w.pack_provider.get_bound_arguments()
		mounted = mounted and w.pack_provider.is_valid() and bound.size() == 1 \
				and int(bound[0]) == w.identity
		binds += "lobo%d bind=%s " % [w.identity, str(bound)]
	_check(mounted, "provedor_montado_pela_sessao", binds.strip_edges())
	# O lobo da fixture, armado sem sessao, nao pode ver matilha nenhuma: e o que
	# segura os 24 cenarios anteriores inteiros com a leitura nova no caminho.
	_advance(1)
	_check(not _wolf.pack_provider.is_valid() and _wolf._pack.is_empty(),
			"lobo sem provedor nao le matilha", "provedor=%s leitura=%d" % [
			_wolf.pack_provider.is_valid(), _wolf._pack.size()])
	# Um golpe real num da matilha, pela identidade e nao por campo escrito a mao:
	# `take_damage` e o unico caminho do jogo que escreve `relations`, e e o que da
	# ao trust publicado um valor proprio antes da conferencia de abaixo.
	(ws[0] as Wolf).take_damage(8.0, Wolf.ACTOR_PLAYER, _player.position3())
	_advance_pack(1)
	_check(int(_session._pack_pairs) == 6, "par_testado_uma_vez_por_passo",
			"pares=%d esperado=4x3/2=6 buffers=%d" % [
			_session._pack_pairs, _session._pack_buffers.size()])
	# Reconstrucao seca, sem passo no meio: assim o valor lido na lista e o valor
	# atual do vizinho e a conferencia e exata, nao uma aproximacao de intencoes.
	_session._rebuild_packs()
	var keys_ok := true
	var values_ok := true
	var viu_confianca := false
	var linhas := ""
	var confiancas := ""
	for w: Wolf in ws:
		var um_linhas := ""
		for e: Dictionary in w._pack:
			if e.size() != 5 or not e.has("identity") or not e.has("pos") \
					or not e.has("intent") or not e.has("hp_ratio") or not e.has("trust"):
				keys_ok = false
				continue
			var other: Wolf = _wolf_of(ws, int(e["identity"]))
			if other == null or not (e["pos"] as Vector3).is_equal_approx(other.center()) \
					or String(e["intent"]) != other.intent \
					or not is_equal_approx(float(e["hp_ratio"]), other.hp / other.max_hp()) \
					or not is_equal_approx(float(e["trust"]), other.trust_toward_player):
				values_ok = false
			if absf(float(e["trust"])) > 0.001:
				viu_confianca = true
			um_linhas += "%d:%.3f " % [int(e["identity"]), float(e["trust"])]
		linhas += "lobo%d<-[%s] " % [w.identity, _ids_of(w._pack)]
		confiancas += "lobo%d<-[%s] " % [w.identity, um_linhas.strip_edges()]
	_check(keys_ok, "leitura_barata_com_as_cinco_chaves",
			"chaves=identity,pos,intent,hp_ratio,trust  %s" % linhas.strip_edges())
	_check(values_ok, "leitura_barata_confere_valor_do_vizinho", confiancas.strip_edges())
	# O pino do trust so pode falhar se a leitura divergir do vizinho REAL, e contra
	# 0,0 default de uma mente que ninguem tocou ele nao decide nada: por isto a
	# premissa exige um valor proprio na mesa. A transicao e `take_damage`, unico
	# escritor de `relations` no jogo (`mind.adjust_trust(from_actor, -0,35)`),
	# chamada pela identidade e nao por um campo escrito a mao.
	_check(viu_confianca, "premissa: a leitura tem trust nao zero para conferir",
			confiancas.strip_edges())
	var sizes: Array[int] = []
	for w: Wolf in ws:
		sizes.append(w._pack.size())
	_check(sizes[0] == 2 and sizes[1] == 2 and sizes[2] == 2 and sizes[3] == 0,
			"raio_de_coesao_recorta_o_lobo_isolado",
			"tamanhos=%s  esperado=[2,2,2,0]  raio=%.1f m" % [sizes, Session.PACK_COHESION_RADIUS])
	var mutual := true
	for w: Wolf in ws:
		for e: Dictionary in w._pack:
			var other: Wolf = _wolf_of(ws, int(e["identity"]))
			if other == null or not other.alive or not _pack_lists_ids(other._pack).has(w.identity):
				mutual = false
	_check(mutual, "matilha_mutua", _pack_lists())
	# Prova de que `pack_of` devolve o buffer da sessao e nao uma copia: mexer no
	# buffer aparece na leitura do lobo, e o rebuild devolve o tamanho anterior.
	var buf: Array = _session.pack_of(int((ws[0] as Wolf).identity))
	var antes: int = buf.size()
	buf.resize(antes + 1)
	var visto: int = (ws[0] as Wolf)._pack.size()
	buf.resize(antes)
	_check(visto == antes + 1 and (ws[0] as Wolf)._pack.size() == antes,
			"pack_of_devolve_o_buffer_da_sessao",
			"buffer=%d leitura=%d restaurado=%d" % [antes + 1, visto, (ws[0] as Wolf)._pack.size()])
	# Passo com matilha completa de verdade, para a checagem 5 nao ser vazia.
	_pack_place(3, Vector3(PACK_SPOTS[0].x + 6.0, PACK_SPOTS[0].y, PACK_SPOTS[0].z))
	_advance_pack(1)
	var completa := true
	for w: Wolf in ws:
		completa = completa and w._pack.size() == 3
	_check(completa, "premissa: o passo da checagem 5 tem matilha completa", _pack_lists())
	var cursor_antes: float = _rng_cursor(_session._population_rng)
	seed(4242)
	var next_global: int = randi()
	_advance_pack(20)
	seed(4242)
	var global_preservado := randi() == next_global
	var cursor_depois: float = _rng_cursor(_session._population_rng)
	_check(cursor_depois == cursor_antes and global_preservado,
			"alcateia_nao_consome_rng_da_sessao",
			"cursor_population=%.8f->%.8f global_preservado=%s passos=%d  %s" % [
			cursor_antes, cursor_depois, str(global_preservado), _pack_steps, _pack_lists()])
	_pack_release()
	return true


## Checagem 1 do dossie 10 (ronda por setor). Premissa nomeada: quatro lobos que se
## leem dentro do raio de coesao patrulham fatias DISTINTAS do mesmo territorio, e um
## lobo sozinho patrulha literalmente como antes (centro = o proprio lar, fatia = TAU).
## O numero que decide nao e a distancia entre os alvos -- dois setores vizinhos podem
## dar pontos proximos por sorte -- e o angulo de cada alvo em torno do baricentro cair
## dentro da fatia do proprio rank, com o raio na faixa sorteada. O segundo braço e o
## replay a lapis da formula antiga: se o lote tivesse mudado a ronda solitaria por
## meio grau, os dois lados divergem.
func _test_rondar_setor() -> bool:
	_arm(SPAWN, FAR_PLAYER, 1)
	_advance(1, false)
	var replay := RandomNumberGenerator.new()
	replay.seed = ("wolf:%d:%d" % [_world.gen.world_seed, 1]).hash()
	replay.randf()					# _heading, consumido em setup()
	replay.randf_range(4.0, 9.0)		# _wander_cd, antes do sorteio do alvo
	var esperado := Vector3.ZERO
	for _t in 8:
		var a := replay.randf() * TAU
		var rad := replay.randf_range(5.0, Wolf.WANDER_RADIUS)
		var p := _wolf.home + Vector3(cos(a) * rad, 0.0, sin(a) * rad)
		p.x = clampf(p.x, 4.0, float(VoxelConfig.world_size_x()) - 4.0)
		p.z = clampf(p.z, 4.0, float(VoxelConfig.world_size_z()) - 4.0)
		if not _wolf._dry_ground(p):
			continue
		p.y = float(_world.surface_height(int(p.x), int(p.z))) + 0.2
		esperado = p
		break
	_check(_wolf.intent == "patrol" and _wolf.get("_reaction") == "patrulhando"
			and esperado == _wolf._move_target and _wolf._pack.is_empty(),
			"um_lobo_so_ronda_identico_a_formula_anterior",
			"intent=%s reaction=%s alvo=%s replay=%s leitura=%d" % [
			_wolf.intent, _wolf.get("_reaction"), _wolf._move_target, esperado, _wolf._pack.size()])
	_pack_session(4)
	for i: int in 4:
		_pack_place(i, RONDAR_SPOTS[i])
	# Baricentro a lapis dos quatro assentos, na horizontal: e o numero que a
	# sessao devolve e o numero que o teste confere, sem nenhum dos dois vindo do
	# proprio codigo do lobo.
	var bar := Vector3.ZERO
	for s: Vector3 in RONDAR_SPOTS:
		bar += s
	bar /= float(RONDAR_SPOTS.size())
	var n := RONDAR_SPOTS.size()
	var arc := TAU / float(n)
	_advance_pack(1)
	var ws: Array = _pack_wolves()
	var premissa_ok := true
	var lists := ""
	for w: Wolf in ws:
		premissa_ok = premissa_ok and w._pack.size() == n - 1 and w.intent == "patrol"
		lists += "lobo%d(%d viz,intent=%s) " % [w.identity, w._pack.size(), w.intent]
	_check(premissa_ok, "premissa: os quatro se leem por inteiro e patrulham",
			"n=%d  %s" % [n, lists.strip_edges()])
	var assentos: Array[float] = []
	var distintos := true
	var dentro := true
	var centro_ok := true
	var linhas := ""
	var lares_fora := 0
	for w: Wolf in ws:
		var rank := w._territory_rank()
		var seat := float(rank) * arc
		assentos.append(seat)
		var c: Vector3 = w._territory_center(n)
		if _horizontal(c - bar).length() > 0.001:
			centro_ok = false
		if _horizontal(c - w.home).length() > 3.0:
			lares_fora += 1
		var v := _horizontal(w._move_target - c)
		var rel := wrapf(atan2(v.z, v.x) - seat, 0.0, TAU)
		if rel > arc or v.length() < 5.0 or v.length() > Wolf.WANDER_RADIUS \
				or w.get("_reaction") != "rondando setor da matilha":
			dentro = false
		linhas += "lobo%d rank=%d rel=%.4f raio=%.2f reaction=%s alvo=%s " % [
				w.identity, rank, rel, v.length(), w.get("_reaction"), w._move_target]
	for i in assentos.size():
		for j in range(i + 1, assentos.size()):
			if absf(assentos[i] - assentos[j]) < 1e-6:
				distintos = false
	_check(distintos and assentos.size() == n, "ronda_assentos_distintos_por_rank",
			"assentos=%s n=%d fatia=%.4f rad" % [assentos, n, arc])
	_check(dentro, "ronda_alvo_dentro_da_fatia_do_proprio_rank", linhas.strip_edges())
	# O baricentro tem de ser um so para a matilha inteira e tem de ser outro ponto
	# para quem nao nasceu nele: sem a segunda metade, "territorio compartilhado"
	# poderia estar virando `home` por outra porta.
	_check(centro_ok and lares_fora == n - 1,
			"ronda_centro_e_baricentro_e_nao_o_lar_do_lobo",
			"baricentro=%s lares_fora=%d/%d  %s" % [bar, lares_fora, n, _territory_lines(ws)])
	return true


## Linha de conferencia do territorio: o que cada lobo devolve como centro e o que
## ele chama de lar. Sem isto, "centro compartilhado" poderia estar virando home.
func _territory_lines(ws: Array) -> String:
	var out := ""
	for w: Wolf in ws:
		out += "lobo%d centro=%s home=%s " % [
				w.identity, _horizontal(w._territory_center(4)), _horizontal(w.home)]
	return out.strip_edges()


## Checagem 2 do dossie 10 (`cercar_calcula_assentos`). Premissa nomeada: n
## participantes do MESMO alvo produzem n assentos distintos, espacados por TAU/n,
## todos a alcance de mordida sem subir em cima do corpo. O angulo esperado sai
## calculado aqui, a partir da lista de lobos e da identidade de cada um, e nao de
## `_hunt_pack_rank`: conferir o codigo contra ele mesmo nao pode falhar.
func _test_cercar_assentos() -> bool:
	_arm(SPAWN, CERCAR_PLAYER)
	_pack_session(4)
	for i: int in 4:
		_pack_place(i, CERCAR_SPOTS[i])
	# Quatro passos de aquecimento: no primeiro o `intent` que a leitura devolve
	# ainda e `patrol`, e um cerco montado sobre censo zero nao e cerco nenhum.
	_advance_pack(4)
	_session._rebuild_packs()
	var ws: Array = _pack_wolves()
	var ppos: Vector3 = _player.position3()
	var hunt_ok := true
	var n_hunt := 0
	var linhas := ""
	for w: Wolf in ws:
		var vizinhos := 0
		for e: Dictionary in w._pack:
			if String(e["intent"]) == "hunt":
				vizinhos += 1
		hunt_ok = hunt_ok and w.intent == "hunt" and w._los_player and vizinhos == 3
		if w.intent == "hunt":
			n_hunt += 1
		linhas += "lobo%d intent=%s los=%s viz_hunt=%d ang=%.4f dist=%.4f " % [
				w.identity, w.intent, w._los_player, vizinhos,
				_seat_angle(w._move_target, ppos), _horizontal(w._move_target - ppos).length()]
	_check(hunt_ok and n_hunt == 4, "premissa: os quatro perseguem a presa visivel",
			"participantes=%d  %s" % [n_hunt, linhas.strip_edges()])
	var angulos: Array[float] = []
	var distancias: Array[float] = []
	var assentos_ok := true
	var anel_ok := true
	for w: Wolf in ws:
		var rank := _participantes_antes_de(w, ws)
		var ang := _seat_angle(w._move_target, ppos)
		if absf(ang - wrapf(TAU * float(rank) / 4.0, 0.0, TAU)) > 1e-4:
			assentos_ok = false
		var d := _horizontal(w._move_target - ppos).length()
		if d <= 0.9 or d > Wolf.BITE_RANGE:
			anel_ok = false
		angulos.append(ang)
		distancias.append(d)
	_check(assentos_ok, "cercar_assentos_distintos_espacados_por_tau_over_n",
			"angulos=%s n=4 espacamento=%.4f" % [angulos, TAU / 4.0])
	_check(anel_ok, "cercar_assento_a_alcance_de_mordida_sem_subir_na_presa",
			"distancias=%s ring=%.3f bite_range=%.3f" % [
			distancias, Wolf.ENCIRCLE_RING, Wolf.BITE_RANGE])
	# Contraste obrigatorio do dossie: o MESMO cenario com um lobo so nao pode
	# devolver o mesmo numero. Se o anel fosse um angulo fixo, ou se `n` fosse o
	# censo da matilha em vez dos participantes, as duas corridas concordariam.
	var alvo_matilha: float = distancias[0]
	_pack_session(1)
	_pack_place(0, CERCAR_SPOTS[0])
	_advance_pack(4)
	var solo: Wolf = _pack_wolves()[0]
	var alvo_solo: float = _horizontal(solo._move_target - _player.position3()).length()
	_check(solo.intent == "hunt" and solo._los_player \
			and solo._move_target == _player.position3() + Vector3(0.0, 0.4, 0.0) \
			and absf(alvo_matilha - alvo_solo) > 0.5,
			"cercar_contraste_um_lobo_contra_quatro_diverge",
			"dist_solo=%.4f dist_matilha=%.4f reaction_solo=%s n_lido=%d" % [
			alvo_solo, alvo_matilha, solo.get("_reaction"), solo._hunt_pack_size()])
	# Terceira checagem, a que pega o "espacamento derivado de quem participa, e nao
	# do censo": uma parede real entre o lobo 0 e a presa tira o `hunt` dele pela
	# porta do proprio codigo (sem visada nao ha caca), sem tira-lo do raio de
	# coesao. Se o angulo saida de `n = matilha`, os tres que enxergam continuariam
	# em TAU/4 e o rank do lobo 3 seria 3 -- aqui ele tem de ser 2.
	var parede: Array = [
		Vector3(70.0, 51.001, 62.0), Vector3(50.0, 51.001, 62.0),
		Vector3(58.0, 51.001, 54.0), Vector3(58.0, 51.001, 70.0),
	]
	_pack_session(4)
	_wall(BlockDefs.Block.STONE)
	for i: int in 4:
		_pack_place(i, parede[i])
	_advance_pack(6)
	_session._rebuild_packs()
	var ws2: Array = _pack_wolves()
	var vitima: Wolf = ws2[0]
	var restantes: Array = []
	var cegas := ""
	for w: Wolf in ws2:
		var viz_hunt := 0
		for e: Dictionary in w._pack:
			if String(e["intent"]) == "hunt":
				viz_hunt += 1
		cegas += "lobo%d intent=%s los=%s viz_hunt=%d ang=%.4f " % [
				w.identity, w.intent, w._los_player, viz_hunt,
				_seat_angle(w._move_target, ppos)]
		if w != vitima and w.intent == "hunt":
			restantes.append(w)
	var espac_ok := restantes.size() == 3 and not vitima._pack.is_empty()
	for k: int in restantes.size():
		var w: Wolf = restantes[k]
		if absf(_seat_angle(w._move_target, ppos) - wrapf(TAU * float(k) / 3.0, 0.0, TAU)) > 1e-4:
			espac_ok = false
	_wall(BlockDefs.Block.AIR)
	_check(not vitima._los_player and vitima.intent != "hunt" and espac_ok,
			"cercar_espacamento_segue_os_participantes",
			"sem_visada=%d restantes=%d espacamento=%.4f  %s" % [
			0 if vitima._los_player else 1, restantes.size(), TAU / 3.0, cegas.strip_edges()])
	return true


## Checagem 3 do dossie 10 (`ataque_escalonado`). Premissa nomeada: quatro lobos em
## cerco, todos a alcance de mordida e com o cooldown zerado, nao mordem no mesmo
## tick. O numero e a contagem de mordidas por tick: `pior_tick` tem de ser 1, as
## quatro mordidas tem de cair em quatro ticks seguidos, e cada uma na fase em que o
## proprio rank casa com `clock.tick % n` -- com n = 4 e os quatro caando, o rank de
## cada um e a sua identidade, entao mordida fora desta igualdade veio de outra porta.
## O segundo braco e a referencia do relogio: as duas corridas entram no alcance em
## fases de tick diferentes, decididas pelo teste e nao pelo acaso. O mapa {fase ->
## identidade} e o mesmo nas duas, e o lobo que morde no tick da entrada e o da fase
## daquela entrada (0 na primeira, 1 na segunda). Tempo de parede, ou "tempo desde
## que entrou no alcance", dariam o lobo 0 mordendo na entrada das duas corridas.
func _test_ataque_escalonado() -> bool:
	_arm(SPAWN, CERCAR_PLAYER)
	var corrida_a := _corrida_mordidas(0, 6)
	# Contraste: os quatro candidatos do primeiro tick saem do estado real deles
	# (cooldown zerado e corpo dentro do alcance), medido antes da entrada -- sem o
	# escalonamento os quatro morderiam no tick zero, como mordiam antes do lote.
	_check(corrida_a["aquecimento"] >= 0 and corrida_a["prontos"] == 4
			and corrida_a["candidatos"] == 4 and corrida_a["n_cheio"]
			and corrida_a["mordidas"] == 4 and corrida_a["no_pior_tick"] == 1
			and corrida_a["consecutivos"] and corrida_a["fora_de_fase"] == 0,
			"ataque_mordidas_nunca_no_mesmo_tick",
			"mordidas=%d pior_tick=%d consecutivos=%s candidatos=%d prontos=%d aquecimento_tick=%d fora_de_fase=%d eventos=%s" % [
			corrida_a["mordidas"], corrida_a["no_pior_tick"],
			str(corrida_a["consecutivos"]), corrida_a["candidatos"],
			corrida_a["prontos"], corrida_a["aquecimento"],
			corrida_a["fora_de_fase"], corrida_a["eventos"]])
	# O segundo braco re-arma o cenario: campo, relogio e seed voltam ao mesmo ponto
	# de partida, entao a unica diferenca declarada entre as corridas e a fase de
	# `clock.tick` em que os quatro entram no alcance -- nao o sangue e o medo que a
	# primeira corrida deixou no ar.
	_pack_release()
	_arm(SPAWN, CERCAR_PLAYER)
	var corrida_b := _corrida_mordidas(1, 6)
	var fases_iguais: bool = corrida_a["fase"].size() == 4 and corrida_b["fase"].size() == 4
	for phase: int in 4:
		if not corrida_a["fase"].has(phase) or not corrida_b["fase"].has(phase) \
				or int(corrida_a["fase"][phase]) != int(corrida_b["fase"][phase]):
			fases_iguais = false
	_check(fases_iguais and not corrida_a["fase_disputada"]
			and not corrida_b["fase_disputada"] and corrida_b["prontos"] == 4
			and corrida_b["candidatos"] == 4 and corrida_b["n_cheio"]
			and corrida_b["mordidas"] == 4 and corrida_b["no_pior_tick"] == 1
			and corrida_b["consecutivos"] and corrida_b["fora_de_fase"] == 0
			and corrida_a["tick_entrada"] % 4 != corrida_b["tick_entrada"] % 4
			and int(corrida_a["biter_entrada"]) == corrida_a["tick_entrada"] % 4
			and int(corrida_b["biter_entrada"]) == corrida_b["tick_entrada"] % 4,
			"ataque_escalonamento_funcao_do_clock_tick",
			"fases_A=%s fases_B=%s entrada_A=%d fase_A=%d biter_A=%d entrada_B=%d fase_B=%d biter_B=%d mordidas_B=%d pior_B=%d prontos_B=%d candid_B=%d n_cheio_B=%s fora_B=%d eventos_B=%s" % [
			corrida_a["fase"], corrida_b["fase"], corrida_a["tick_entrada"],
			corrida_a["tick_entrada"] % 4, corrida_a["biter_entrada"],
			corrida_b["tick_entrada"], corrida_b["tick_entrada"] % 4,
			corrida_b["biter_entrada"], corrida_b["mordidas"],
			corrida_b["no_pior_tick"], corrida_b["prontos"],
			corrida_b["candidatos"], str(corrida_b["n_cheio"]),
			corrida_b["fora_de_fase"], corrida_b["eventos"]])
	_pack_release()
	return true


## Checagem 4a do dossie 10 (`medo_contagia`). Premissa nomeada: um vizinho DENTRO
## do raio de coesao entra em panico pela transicao real (`take_damage`, o unico
## escritor de `relations` e o que poe o corpo em `flee`), e o observador -- que nao
## foi tocado, nao ve o jogador a 73 m e nao sente o campo a cinco celulas -- muda
## de intencao por causa da LEITURA, nao do mundo. O numero que decide e duplo:
## (i) `contagio_medo_soma_panic_no_fear_level` reproduz a composicao do
## `_fear_level` a lapis com os coeficientes do codigo (0,85 / 0,9 / 0,35) e o
## `0,55` por vizinho em panico escrito aqui, e exige igualdade -- se a soma saiu da
## percepcao por outra porta, ou se o `PACK_PANIC_FEAR` mudou de valor sem o teste
## mudar, os dois lados divergem; (ii) a subida de 0,55 tem de vir com o par
## `_fear_here`/`_blood_here` do observador INALTERADO entre os bracos, porque e
## exatamente isso que separa contagio de difusao. O terceiro numero e a intencao:
## `patrol` no braco sem panico, `flee` no braco com, nos mesmos 20 m.
func _test_contagio_medo() -> bool:
	_arm(SPAWN, FAR_PLAYER, 1)
	_pack_session(2)
	for i: int in 2:
		_pack_place(i, MEDO_SPOTS[i])
	_advance_pack(6)
	var ws: Array = _pack_wolves()
	var obs: Wolf = ws[1]
	var vitima: Wolf = ws[0]
	var dist_obs_vitima: float = obs.center().distance_to(vitima.center())
	var dist_obs_jogador: float = obs.center().distance_to(_player.position3())
	_check(obs._pack.size() == 1 and vitima._pack.size() == 1 \
			and int(obs._pack[0]["identity"]) == vitima.identity \
			and dist_obs_vitima <= Session.PACK_COHESION_RADIUS \
			and obs.intent == "patrol" and obs._pack_panic == 0 \
			and absf(obs._fear_level) < 0.001,
			"premissa: observador patrulha com um vizinho lido e medo zerado",
			"vizinhos=%d panic=%d fear=%.6f intent=%s dist_vitima=%.3f (raio %.1f) dist_jogador=%.3f los=%s  %s" % [
			obs._pack.size(), obs._pack_panic, obs._fear_level, obs.intent,
			dist_obs_vitima, Session.PACK_COHESION_RADIUS, dist_obs_jogador,
			str(obs._los_player), _pack_lists()])
	var fear_antes: float = obs._fear_level
	var here_antes: float = obs._fear_here
	var blood_antes: float = obs._blood_here
	var intent_antes: String = obs.intent
	# A unica diferenca declarada entre os bracos: um golpe real no VIZINHO. O
	# observador nao e tocado, nao ve o jogador e esta a cinco celulas de Eter do
	# sangue e do medo impressos.
	vitima.take_damage(8.0, Wolf.ACTOR_PLAYER, _player.position3())
	_advance_pack(16)
	var panic_lido := 0
	for e: Dictionary in obs._pack:
		if String(e["intent"]) == "flee":
			panic_lido += 1
	# Replay a lapis da composicao, com os coeficientes copiados do codigo desta
	# revisao e o 0,55 escrito aqui: conferir o lobo contra ele mesmo nao pode falhar.
	var esperado: float = clampf(obs._fear_here * 0.85 + obs._threat * 0.9
			+ obs._blood_here * 0.35 + float(obs._pack_panic) * 0.55, 0.0, 1.5)
	_check(panic_lido == 1 and vitima.intent == "flee" \
			and obs._pack_panic == panic_lido \
			and absf(esperado - obs._fear_level) < 0.0001 \
			and absf(obs._fear_here - here_antes) < 0.0001 \
			and absf(obs._blood_here - blood_antes) < 0.0001 \
			and absf(obs._fear_level - fear_antes - 0.55) < 0.0001,
			"contagio_medo_soma_panic_no_fear_level",
			"fear_antes=%.6f fear_depois=%.6f delta=%.6f replay=%.6f panic=%d  campo_antes=(medo %.6f sangue %.6f) campo_depois=(medo %.6f sangue %.6f) vitima_intent=%s" % [
			fear_antes, obs._fear_level, obs._fear_level - fear_antes, esperado,
			obs._pack_panic, here_antes, blood_antes, obs._fear_here, obs._blood_here,
			vitima.intent])
	# O `intent` e o numero que o dossie pede: sem o vizinho em panico o observador
	# estava em `patrol` com `_fear_level` 0; com ele, `flee` passa o chao de fundo
	# de 0,22 e o escorredor troca. Os dois valores de `_fear_level` saem na linha.
	_check(intent_antes == "patrol" and obs.intent == "flee" \
			and fear_antes < 0.001 and obs._fear_level >= 0.55 \
			and obs._fear_here < 0.0001,
			"contagio_medo_muda_intent_do_observador",
			"intent_antes=%s intent_depois=%s fear_antes=%.6f fear_depois=%.6f cautela=%.4f top=%s panic=%d medo_no_observador=%.6f" % [
			intent_antes, obs.intent, fear_antes, obs._fear_level,
			obs.mind.temperament("caution"), obs._top_line, obs._pack_panic,
			obs._fear_here])
	_pack_release()
	return true


## Checagem 4b do dossie 10 (`amigo_amortece`). Premissa nomeada: tres lobos a 8 m
## do jogador, todos dentro da coesao, todos lendo os outros dois e todos em `hunt`.
## O numero que decide e a PORTA e nao a media: `hunt` carrega o veto "coragem
## contra este ator" na faixa 0,5..1,0, entao `_courage` 0,46 zera a opcao inteira
## e o escorredor devolve `patrol`. Tres bracos na mesma sessao:
## - A, sem vizinho amansado: `_pack_trust` 0, `_courage` 1, porta aberta, 3 caando.
## - B, vizinho com trust 0,60 (acima de `PACK_TRUST_GATE` 0,35): `_pack_trust`
##   0,60, `_courage` 0,46 -- igual a `1 - 0,60 * 0,9` reproduzido a lapis aqui --
##   porta vetada para os DOIS colegas, e o amansado continua com porta aberta e em
##   `hunt`, porque a leitura dele devolve trust 0 para os outros dois. A assimetria
##   e o que prova que o numero veio da leitura da matilha, e nao de um global.
## - C, vizinho com trust 0,30 (abaixo da soleira): `_pack_trust` volta a 0,
##   `_courage` a 1, a porta reabre e os tres caam de novo. Sem este braco a soleira
##   seria enfeite: qualquer trust nao zero amorteceria e o 0,35 do codigo nao
##   decidia nada.
## O trust alto NAO tem caminho de gameplay hoje, e isso fica no log: `take_damage`
## e o unico chamador de `adjust_trust` em `src/` e passa -0,35. Entao o valor entra
## pelo mutador da propria mente (+0,6 / -0,3), a porta pela qual o amansamento dos
## dossies 14 e 11 chegaria -- nunca por `mind.relations` escrito a mao.
func _test_amortece_confianca() -> bool:
	_arm(SPAWN, CERCAR_PLAYER, 1)
	_pack_session(3)
	for i: int in 3:
		_pack_place(i, AMORTECE_SPOTS[i])
	# O jogador volta ao centro do plateau pela transicao real, como no cerco.
	_player.respawn_at(CERCAR_PLAYER)
	var n_antes := 0
	for _t in 40:
		_advance_pack(1)
		n_antes = _caadores(3)
		if n_antes == 3:
			break
	var ws: Array = _pack_wolves()
	var am: Wolf = ws[0]
	var c1: Wolf = ws[1]
	var c2: Wolf = ws[2]
	var leitura_tres := am._pack.size() == 2 and c1._pack.size() == 2 and c2._pack.size() == 2
	_check(n_antes == 3 and leitura_tres and absf(c1._pack_trust) < 0.0001 \
			and absf(c1._courage - 1.0) < 0.0001 and _porta_hunt_aberta(c1) \
			and _porta_hunt_aberta(c2) and absf(am.trust_toward_player) < 0.0001,
			"premissa: os tres caam com o vizinho sem confianca e a porta aberta",
			"caadores=%d leitura=[%d,%d,%d]  %s" % [
			n_antes, am._pack.size(), c1._pack.size(), c2._pack.size(),
			_confianca_linhas(ws)])
	# Braco B: o amansado ganha trust 0,60 pelo mutador da mente, e os colegas so o
	# veem quando a sessao copiar o escalar publicado no buffer do passo seguinte.
	var intent_antes_1: String = c1.intent
	var intent_antes_2: String = c2.intent
	am.mind.adjust_trust(Wolf.ACTOR_PLAYER, 0.6)
	_advance_pack(20)
	# Replay a lapis do amortecimento: `1 - 0,60 * 0,9` com os dois numeros do codigo
	# escritos aqui. Se o `PACK_TRUST_DAMP` mudar sem o teste mudar, os lados
	# divergem; se o contagio sair da percepcao por outra porta, idem.
	var coragem_esperada: float = clampf(1.0 - 0.6 * 0.9, 0.0, 1.0)
	_check(absf(am.trust_toward_player - 0.6) < 0.0001 \
			and absf(c1._pack_trust - 0.6) < 0.0001 \
			and absf(c1._courage - coragem_esperada) < 0.0001 \
			and absf(c2._courage - coragem_esperada) < 0.0001 \
			and not _porta_hunt_aberta(c1) and not _porta_hunt_aberta(c2) \
			and absf(am._pack_trust) < 0.0001 and _porta_hunt_aberta(am),
			"amortece_confianca_fecha_a_porta_de_hunt_dos_colegas",
			"coragem_replay=%.6f  %s" % [coragem_esperada, _confianca_linhas(ws)])
	_check(intent_antes_1 == "hunt" and intent_antes_2 == "hunt" \
			and c1.intent != "hunt" and c2.intent != "hunt" and am.intent == "hunt",
			"amortece_confianca_muda_intent_dos_colegas_sem_tocar_no_amansado",
			"antes=(lobo1 %s, lobo2 %s) depois=(lobo1 %s, lobo2 %s, amansado %s)  %s" % [
			intent_antes_1, intent_antes_2, c1.intent, c2.intent, am.intent,
			_confianca_linhas(ws)])
	# Braco C: 0,30 cai abaixo da soleira de 0,35 que o codigo cobra, e a porta tem
	# de reabrir sozinha -- sem isso o gate seria decoracao.
	am.mind.adjust_trust(Wolf.ACTOR_PLAYER, -0.3)
	_advance_pack(20)
	var n_depois := _caadores(3)
	_check(absf(am.trust_toward_player - 0.3) < 0.0001 \
			and absf(c1._pack_trust) < 0.0001 and absf(c1._courage - 1.0) < 0.0001 \
			and _porta_hunt_aberta(c1) and _porta_hunt_aberta(c2) and n_depois == 3,
			"amortece_confianca_soleira_de_035_decide_a_porta",
			"caadores_depois=%d soleira=0.35 confiado_agora=0.30  %s" % [
			n_depois, _confianca_linhas(ws)])
	_pack_release()
	return true


# ------------------------------------------------------- convivencia (dossie 14)

## Lago artificial sobre o plateau: `WATER` em y=51, o piso de pedra em y=50 fica
## intacto, entao `surface_height` continua 50 e a coluna passa a contar como
## molhada pelo predicado real do lobo (`_dry_ground` le a superficie atual). A
## saida seca do cenario 1 e geometrica e nao uma aposta na seed, e o mesmo
## `set_block` que a fixture ja usa para o planalto e para a parede.
func _flood(x0: int, z0: int, x1: int, z1: int) -> void:
	for x: int in range(x0, x1 + 1):
		for z: int in range(z0, z1 + 1):
			_world.set_block(Vector3i(x, 51, z), BlockDefs.Block.WATER)


## Restaura o retangulo exatamente como a fixture o deixou: pedra em y=50, ar
## acima. Sem isto a agua do cenario 1 vazaria nos cenarios seguintes.
func _unflood(x0: int, z0: int, x1: int, z1: int) -> void:
	for x: int in range(x0, x1 + 1):
		for z: int in range(z0, z1 + 1):
			_world.set_block(Vector3i(x, 51, z), BlockDefs.Block.AIR)


## Raio do primeiro ponto seco no espelho exato do anel de `_shore_point()` (os
## mesmos 5 raios, as mesmas 8 direcoes, o mesmo `+0,3`), ou -1 quando nao ha
## saida nenhuma. A premissa do cenario tem de usar o varredura da folha, e nao
## uma busca mais frouxa que deixaria passar um "quase seco".
func _exit_ring(origin: Vector3) -> float:
	for r: float in [1.6, 2.6, 4.0, 6.0, 8.0]:
		for i: int in 8:
			var a := TAU * float(i) / 8.0 + 0.3
			if _wolf._dry_ground(origin + Vector3(cos(a) * r, 0.0, sin(a) * r)):
				return r
	return -1.0


## Distancia horizontal ate a primeira coluna seca ao redor de `p` (passo de 0,5 m
## em 16 direcoes ate 20 m), 0,0 se `p` ja e seco, -1 se so ha agua nesse raio.
## Servico de report: e o numero que o cenario imprime como "distancia a margem",
## e o teto que decide comportamento continua sendo o anel de 8 m de `_shore_point`.
func _nearest_dry(p: Vector3) -> float:
	if _wolf._dry_ground(p):
		return 0.0
	for r: int in range(1, 41):
		var d := float(r) * 0.5
		for i: int in 16:
			var a := TAU * float(i) / 16.0
			if _wolf._dry_ground(p + Vector3(cos(a) * d, 0.0, sin(a) * d)):
				return d
	return -1.0


## Cenario 1 (dossie 14 §5, premissa 1 nos dois sentidos). Braco A: o alvo que a
## arvore elegeu esta na agua e ha coluna seca a <= 8 m -- nenhum tick pode
## terminar com alvo molhado. Braco B e a direcao oposta obrigatoria: no meio de
## um lago sem saida nenhuma no anel, o conserto tem de ser indiferente ao estado,
## o alvo continua molhado e o corpo ancora avanca nadando. Sem o braco B o filtro
## poderia virar "finge que achou seco" e o mandato 1 nao deixa.
func _test_lobo_escolhe_trilha_seca() -> bool:
	_flood(63, 59, 69, 65)
	_arm()
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.42)
	_advance(1)
	var alvo: Vector3 = _wolf._scent_pos
	var saida := _exit_ring(alvo)
	# A premissa se mede no rastro e nao no `_move_target` do passo: o filtro roda
	# no fim do mesmo `sim_step`, entao ler o alvo depois seria ler o conserto.
	# `_leaf_investigate` escreve `_move_target = _scent_pos` sem perguntar ao chao
	# (wolf.gd:376), entao rastro na agua e a arvore mirando a agua.
	_check(_wolf.intent == "investigate" and _wolf._scent_found
			and not _wolf._dry_ground(alvo) and saida > 0.0 and saida <= 8.0,
			"premissa A: o nariz escolhe uma coluna de agua com saida seca no anel",
			"rastro=%s seco=%s saida_do_rastro=%.1f m intent=%s forca=%.3f" % [
			alvo, _wolf._dry_ground(alvo), saida, _wolf.intent, _wolf._scent_strength])
	var molhados := 0
	var corpo_molhado := 0
	for i: int in 200:
		_advance(1)
		if not _wolf._dry_ground(_wolf._move_target):
			molhados += 1
		if _wolf.body.in_water:
			corpo_molhado += 1
	_check(molhados == 0, "ticks_com_alvo_molhado_final == 0 (200 passos)",
			"molhados=%d/200 alvo_final=%s a %.1f m de terra seca pes=%s" % [
			molhados, _wolf._move_target, _nearest_dry(_wolf._move_target),
			_wolf.body.feet_pos])
	_check(not _wolf.body.in_water and _wolf._dry_ground(_wolf.body.feet_pos),
			"o corpo nao termina dentro da agua quando havia saida",
			"in_water=%s ticks_corpo_na_agua=%d/200 pes=%s" % [
			_wolf.body.in_water, corpo_molhado, _wolf.body.feet_pos])
	# Braco B: lago de 28 x 28 colunas -- do centro ate a borda seca mais proxima
	# sao 13,5 m, entao nenhum dos cinco raios de `_shore_point` devolve terra.
	_flood(46, 49, 73, 76)
	_arm(Vector3(59.0, 51.001, 62.0), FAR_PLAYER, 2)
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.42)
	_advance(1)
	var saida_b := _exit_ring(_wolf.body.feet_pos)
	_check(not _wolf._dry_ground(_wolf._move_target) and saida_b < 0.0
			and _wolf.body.in_water and _nearest_dry(_wolf.body.feet_pos) > 8.0,
			"premissa B: lago sem nenhuma saida no anel de 8 m",
			"alvo=%s saida=%.1f m terra_real=%.1f m in_water=%s intent=%s" % [
			_wolf._move_target, saida_b, _nearest_dry(_wolf.body.feet_pos),
			_wolf.body.in_water, _wolf.intent])
	var inicio := _wolf.body.feet_pos
	var travessias := 0
	var mentirosos := 0
	for i: int in 200:
		_advance(1)
		if not _wolf._dry_ground(_wolf._move_target):
			# Um alvo molhado so e honesto se a saida nao existe: medido no mesmo
			# corpo e no mesmo passo em que o filtro decidiu, e nao depois.
			if _exit_ring(_wolf.body.feet_pos) >= 0.0:
				mentirosos += 1
			else:
				travessias += 1
	var avanco := _horizontal(_wolf.body.feet_pos - inicio).length()
	_check(mentirosos == 0, "o nado so acontece onde nao ha saida (o filtro nao mente)",
			"alvos_molhados_sem_saida=%d com_saida=%d/200 terra_real=%.1f m" % [
			travessias, mentirosos, _nearest_dry(_wolf.body.feet_pos)])
	_check(avanco > 1.2, "sem saida o corpo avanca nadando",
			"deslocamento=%.2f m (> 1,2 m) passos=200 in_water=%s pes=%s" % [
			avanco, _wolf.body.in_water, _wolf.body.feet_pos])
	_unflood(46, 49, 73, 76)
	_unflood(63, 59, 69, 65)
	return true


## A coluna de agua mais funda da seed, medida como no passo de nado do smoke
## (varredura de 2 em 2 blocos, profundidade `SEA_LEVEL - leito` mais os quatro
## vizinhos molhados como desempate). Lago REAL e nao o que a fixture inundou: o
## "nada por necessidade" tem de existir no terreno gerado, senao o conserto so
## seria indiferente a um estado que o mundo nunca produz.
func _deepest_lake() -> Dictionary:
	var best := Vector3i.ZERO
	var best_score := -1
	for x: int in range(4, VoxelConfig.world_size_x() - 4, 2):
		for z: int in range(4, VoxelConfig.world_size_z() - 4, 2):
			var top := _world.surface_height(x, z)
			if not _world.is_water_xyz(x, top + 1, z):
				continue
			var vizinhos := 0
			for off: Vector3i in [Vector3i(2, 0, 0), Vector3i(-2, 0, 0), Vector3i(0, 0, 2), Vector3i(0, 0, -2)]:
				var t2 := _world.surface_height(x + off.x, z + off.z)
				if _world.is_water_xyz(x + off.x, t2 + 1, z + off.z):
					vizinhos += 1
			var score := (VoxelConfig.SEA_LEVEL - top) * 10 + vizinhos
			if score > best_score:
				best_score = score
				best = Vector3i(x, top, z)
	return {"col": best, "leito": best.y, "pontuacao": best_score,
			"profundidade": VoxelConfig.SEA_LEVEL - best.y}


## Cenario 2 (dossie 14 §5, segundo sentido da premissa 1): o mesmo lobo no lago
## mais fundo da seed nada e avanca, e o filtro continua indiferente a esse
## estado. Braco B mede o compromisso de travessia (dossie 14 §3.2): com a presa
## visivel dentro da agua o alvo seco e re-escolhido na cadencia do nariz
## (SCENT_PERIOD = 5 passos), nao a cada passo de 50 ms -- re-escolher todo passo
## e exatamente o "parece desorganizado" do pedido.
func _test_nadar_so_sem_saida_seca() -> bool:
	var lago: Dictionary = _deepest_lake()
	var col: Vector3i = lago["col"]
	var pes := Vector3(float(col.x) + 0.5, float(col.y) + 1.05, float(col.z) + 0.5)
	_arm(pes, FAR_PLAYER, 4)
	_field.imprint(pes + Vector3(4.0, 0.0, 0.0), AetherField.Channel.WORK, 0.42)
	_advance(1)
	var saida_lago := _exit_ring(_wolf.body.feet_pos)
	_check(lago["pontuacao"] > 0 and lago["profundidade"] >= 2
			and not _wolf._dry_ground(_wolf.body.feet_pos) and _wolf.body.in_water,
			"premissa: lago fundo da seed, corpo na agua por necessidade",
			"coluna=(%d,%d) profundidade=%d leito=%d saida_anel=%.1f m terra_real=%.1f m" % [
			col.x, col.z, lago["profundidade"], lago["leito"], saida_lago,
			_nearest_dry(_wolf.body.feet_pos)])
	var inicio_lago := _wolf.body.feet_pos
	var molhados_lago := 0
	var mentirosos_lago := 0
	for i: int in 200:
		_advance(1)
		if not _wolf._dry_ground(_wolf._move_target):
			molhados_lago += 1
			if _exit_ring(_wolf.body.feet_pos) >= 0.0:
				mentirosos_lago += 1
	var avanco_lago := _horizontal(_wolf.body.feet_pos - inicio_lago).length()
	_check(avanco_lago > 1.2, "no lago da seed o corpo nada e avanca (> 1,2 m)",
			"deslocamento=%.2f m alvos_molhados=%d/200 in_water=%s pes=%s" % [
			avanco_lago, molhados_lago, _wolf.body.in_water, _wolf.body.feet_pos])
	_check(mentirosos_lago == 0, "no lago da seed tambem so nada onde nao ha saida",
			"molhados_sem_saida=%d molhados_com_saida=%d/200" % [
			molhados_lago - mentirosos_lago, mentirosos_lago])
	# Braco B: lago artificial com saida, presa visivel dentro da agua -- todo tick
	# de cauda termina com um alvo em terra, e o que se conta sao as vezes em que
	# esse rumo foi TROCADO, medida no alvo escrito e nao num campo do lobo.
	_flood(55, 59, 71, 65)
	_arm(Vector3(60.0, 51.001, 62.0), Vector3(66.0, 51.001, 62.0), 5)
	_advance(1)
	var alvo_anterior := _wolf._move_target
	var reescolhas := 0
	var passos_cauda := 0
	var secos := 0
	for i: int in 200:
		_advance(1)
		if _wolf.intent != "hunt":
			alvo_anterior = _wolf._move_target
			continue
		passos_cauda += 1
		if _wolf._dry_ground(_wolf._move_target):
			secos += 1
			if _horizontal(_wolf._move_target - alvo_anterior).length() > 0.01:
				reescolhas += 1
		alvo_anterior = _wolf._move_target
	var segundos := float(passos_cauda) * SimClock.STEP
	var taxa := float(reescolhas) / maxf(segundos, 0.001)
	_check(passos_cauda > 100 and secos == passos_cauda,
			"premissa B: a cauda na agua troca o alvo por um ponto em terra todo passo",
			"passos_hunt=%d alvos_secos=%d presa_seca=%s saida=%.1f m" % [
			passos_cauda, secos, _wolf._dry_ground(_player.position3()),
			_exit_ring(_wolf.body.feet_pos)])
	_check(taxa <= 5.0, "rumo de travessia re-escolhe na cadencia do nariz (4/s), nao todo passo",
			"reescolhas=%d em %.1f s de cauda = %.2f por passo de 20 Hz (%.1f/s, teto declarado 5/s)" % [
			reescolhas, segundos, float(reescolhas) / maxf(float(passos_cauda), 1.0), taxa])
	_unflood(55, 59, 71, 65)
	return true


## Cenario 3 (dossie 14 §5): o resgate de margem sobrevive a arvore. O comentario
## de `sim_step` jura que a margem proxima manda "acima de qualquer outra intencao
## da arvore", mas a atribuicao roda ANTES de `_sense`/`_think`/`_tree.tick` e a
## folha `perseguir` reescrevia o alvo molhado por cima dela. Aqui o lobo nada
## 6 m ate a borda (mais de 2 s de travessia, por isso `_swim_time` cruza
## `SHORE_AFTER` com a presa ainda a vista dentro da agua) e o que se colhe e o
## passo do cruzamento, nao o ultimo passo de uma janela qualquer: depois do
## conserto o corpo ate sai da agua, e `SHORE_AFTER` deixa de ser alcancavel.
func _test_resgate_de_margem_sobrevive_a_arvore() -> bool:
	_flood(55, 59, 71, 65)
	_arm(Vector3(60.0, 51.001, 62.0), Vector3(66.0, 51.001, 62.0), 3)
	var presa: Vector3 = _player.position3()
	_advance(1)
	_check(_wolf.intent == "hunt" and _wolf._los_player
			and not _wolf._dry_ground(presa) and _distance(presa) > Wolf.BITE_RANGE,
			"premissa: cauda com presa visivel dentro da agua",
			"los=%s intent=%s presa=%s presa_seca=%s dist=%.2f m saida=%.1f m" % [
			_wolf._los_player, _wolf.intent, presa, _wolf._dry_ground(presa),
			_distance(presa), _exit_ring(_wolf.body.feet_pos)])
	var tick_resgate := -1
	var swim_no_resgate := 0.0
	var alvo_no_resgate := _wolf._move_target
	var molhados_soaked := 0
	var ticks_soaked := 0
	for i: int in 160:
		_advance(1)
		if _wolf._swim_time > Wolf.SHORE_AFTER:
			ticks_soaked += 1
			if not _wolf._dry_ground(_wolf._move_target):
				molhados_soaked += 1
			if tick_resgate < 0:
				tick_resgate = _clock.tick
				swim_no_resgate = _wolf._swim_time
				alvo_no_resgate = _wolf._move_target
	_check(tick_resgate > 0 and ticks_soaked > 0,
			"o estado ensopado existe de verdade (SHORE_AFTER cruzado em passo de 20 Hz)",
			"tick=%d _swim_time=%.3f s (piso %.1f s) ticks_ensopados=%d in_water=%s" % [
			tick_resgate, swim_no_resgate, Wolf.SHORE_AFTER, ticks_soaked,
			_wolf.body.in_water])
	_check(_wolf._dry_ground(alvo_no_resgate)
			and _horizontal(alvo_no_resgate - presa).length() > 1.0,
			"resgate_de_margem_sobrevive_a_arvore: alvo do passo do resgate e seco",
			"intent=%s alvo=%s seco=%s a %.1f m da presa molhada (%.1f m de terra)" % [
			_wolf.intent, alvo_no_resgate, _wolf._dry_ground(alvo_no_resgate),
			_horizontal(alvo_no_resgate - presa).length(),
			_nearest_dry(alvo_no_resgate)])
	_check(molhados_soaked == 0, "nenhum passo ensopado termina com alvo molhado",
			"molhados=%d/%d ensopados in_water_final=%s _swim_time=%.3f s" % [
			molhados_soaked, ticks_soaked, _wolf.body.in_water, _wolf._swim_time])
	_unflood(55, 59, 71, 65)
	return true


## Fixture da checagem 8 (dossie 16 §5): marca TODAS as colunas da caixa em que o
## proprio sorteio de `_spawn_home_point` e clampado -- `6 … tamanho-6` nos dois
## eixos, lido da mesma expressao do clamp e nao de um numero escrito a mão, para
## que a porta `coluna` alcance todo ponto que o jogo pode sortear. Escreve num
## Dictionary de teste, nunca no mundo: nenhum voxel muda.
func _mark_useful_box(taken: Dictionary) -> int:
	var marcadas := 0
	for x: int in range(6, VoxelConfig.world_size_x() - 5):
		for z: int in range(6, VoxelConfig.world_size_z() - 5):
			taken[Vector2i(x, z)] = true
			marcadas += 1
	return marcadas


## Cenario 4 (dossie 14 §5, premissa 2 no espaco): quantos lobos miram a MESMA
## celula de Eter por tick e quantos param no mesmo ponto. Vermelho por ausencia:
## `_find_scent` devolve o centro da celula, entao os quatro que leem o mesmo
## rastro escrevem o mesmo alvo e cinco corpos cabem no mesmo voxel.
func _test_dois_lobos_nao_farejam_a_mesma_celula() -> bool:
	_arm()
	_pack_session(4)
	for i: int in 4:
		_pack_place(i, FAREJAR_SPOTS[i])
	var celula_rastro: Vector3i = _field.cell_of_world(SOURCE)
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.42)
	_advance_pack(1)
	var ws: Array = _pack_wolves()
	var mesma_celula := true
	var todos_investigate := true
	for w: Wolf in ws:
		mesma_celula = mesma_celula and w._scent_cell == celula_rastro
		todos_investigate = todos_investigate and w.intent == "investigate"
	_check(mesma_celula and todos_investigate,
			"premissa: os quatro leem a mesma celula de rastro",
			"celula=%s leituras=[%s] intent=[%s]" % [
			str(celula_rastro), _cels_str(ws), _intents_str(ws)])
	var pior_tick := 0
	var pior_na_celula := 0
	var pior_no_ponto := 0
	var passos_investigue := 0
	var fora_da_celula := 0
	for t: int in 150:
		_advance_pack(1)
		var na_celula := 0
		var alvos: Array = []
		for w: Wolf in ws:
			if w.intent == "investigate":
				passos_investigue += 1
				if _field.cell_of_world(w._move_target) == celula_rastro:
					na_celula += 1
				else:
					fora_da_celula += 1
			alvos.append(w._move_target)
		if na_celula > 0 and t > 5:
			pior_tick = t
		pior_na_celula = maxi(pior_na_celula, na_celula)
		pior_no_ponto = maxi(pior_no_ponto, _cluster_maximo(alvos, 1.0))
	_check(pior_na_celula <= 1, "pico de lobos mirando a mesma celula por tick",
			"pior=%d lobos na celula %s (teto 1) ultimo_tick=%d passos_investigue=%d alvos_fora_da_celula=%d" % [
			pior_na_celula, str(celula_rastro), pior_tick, passos_investigue, fora_da_celula])
	_check(pior_no_ponto <= 1, "pico de lobos com o mesmo ponto de chegada",
			"pior_cluster=%d alvos a <= 1,0 m entre si (teto 1)" % pior_no_ponto)
	# Lares em colunas diferentes (dossie 14 §3.3.(iii)): medidos no spawn real,
	# sem `_pack_place`. Se dois lobos herdam a mesma coluna, a ronda dos dois
	# setores sortea o mesmo circulo e a matilha parece um corpo so.
	_spawn_session(5)
	var colunas: Dictionary = {}
	var lares := ""
	for w: Wolf in _pack_wolves():
		var col := Vector2i(int(w.home.x), int(w.home.z))
		colunas[col] = true
		lares += "lobo%d=(%d,%d) " % [w.identity, col.x, col.y]
	# Censo variavel (dossie 14 §3.5): o que vale nao e "nasceram cinco", e "os que
	# nasceram tem colunas distintas e nada se perdeu por fora" -- o que nao nasce
	# volta para a fila, entao matilha + fila fecha o teto.
	var fila_boot := int(_session.diagnostics()["pending_respawns"])
	_check(colunas.size() == _pack_wolves().size()
			and _pack_wolves().size() + fila_boot == int(Session.WOLF_COUNT),
			"lares do spawn real em colunas diferentes, censo fechado pela fila",
			"distintas=%d de %d borna + %d na fila = teto %d | %s" % [
			colunas.size(), _pack_wolves().size(), fila_boot, Session.WOLF_COUNT, lares])
	# Mecanismo, nao sorte: um censo que pode nascer menor que cinco nao pode contar
	# com a sorte da seed, entao a checagem de cima fecha a conta e esta marca as
	# colunas ocupadas -- incluida a do centro, o ponto que o fallback antigo
	# devolvia em silencio e que hoje tem de ser recusado por distancia ou por
	# visada -- e pede lares de novo pela funcao real. Coluna ocupada nao pode
	# voltar, e recusa contada nao e violacao.
	colunas[Vector2i(int(_session.spawn_point().x), int(_session.spawn_point().z))] = true
	var violacoes := 0
	var recusados := 0
	var dadas: Dictionary = {}
	for _k: int in 8:
		var pedido: Dictionary = _session._spawn_home_point(colunas)
		if not bool(pedido["ok"]):
			recusados += 1
			continue
		var novo: Vector3 = pedido["feet"]
		var col_nova := Vector2i(int(novo.x), int(novo.z))
		if colunas.has(col_nova):
			violacoes += 1
		dadas[col_nova] = true
	_check(violacoes == 0, "mecanismo: coluna ocupada nao volta como lar",
			"violacoes=%d em 8 pedidos, recusados=%d, ocupadas=%d, colunas_devolvidas=%d" % [
			violacoes, recusados, colunas.size(), dadas.size()])
	# Checagem 8 do dossie 16 §5, o furo #18 pago com numero. A linha de cima nao
	# alcanca a recusa: com seis colunas marcadas e tres bandas que vao de 16 m ate
	# a borda util, o mundo entrega lar quase sempre, e o numero que a propria casa
	# media era `recusados=0` -- a assercao `violacoes == 0` passa identicamente sem
	# nenhuma recusa. Aqui o fixture marca TODAS as colunas da caixa em que o
	# sorteio e clampado (ainda fixture: nenhum voxel do mundo e tocado), entao o
	# esgotamento deixa de ser sorte dos oito pedidos e vira geometrico. O criterio
	# e a conta do `motivos`, que nunca teve um leitor em `tests/`: cada busca tem
	# de somar `banda x SPAWN_ATTEMPTS` leituras, e -- porque a primeira porta do
	# laco e a coluna -- todas elas tem de cair em `coluna`. Se a ordem dos portoes
	# mudar ou um `continue` passar a engolir uma tentativa sem contar, a soma fecha
	# curta e esta linha fica vermelha.
	var marcadas := _mark_useful_box(colunas)
	var forcados := 0
	var buscas := 0
	var vazias := 0
	var soma_motivos := 0
	var so_a_coluna := true
	var primeiro: Dictionary = {}
	for _k: int in 8:
		var r: Dictionary = _session._spawn_home_point(colunas)
		if bool(r["ok"]):
			continue
		forcados += 1
		buscas += int(r["banda"])
		var m: Dictionary = r["motivos"]
		if forcados == 1:
			primeiro = m
		vazias += int(m["vazia"])
		var total := 0
		for chave: String in m:
			total += int(m[chave])
		soma_motivos += total
		if int(m["coluna"]) != total:
			so_a_coluna = false
	# Premissa da conta de cima: nenhuma das tres buscas do jogador esta vazia por
	# geometria (`rmax <= rmin` acontece com o jogador encostado na borda), senao
	# `buscas x SPAWN_ATTEMPTS` e o numero errado para cobrar.
	_check(vazias == 0, "premissa: as tres bandas buscam de verdade (nenhuma vazia)",
			"vazia=%d em %d recusas, buscas=%d, banda=%d por busca, jogador em (%.0f,%.0f), borda=%.1f m" % [
			vazias, forcados, buscas, buscas / maxi(forcados, 1),
			_player.position3().x, _player.position3().z,
			_session._band_edge(_player.position3())])
	_check(forcados == 8 and soma_motivos == buscas * Session.SPAWN_ATTEMPTS
			and so_a_coluna,
			"esgotamento_de_lares_forcado",
			"recusados=%d de 8 | soma(motivos)=%d == buscas(%d) x SPAWN_ATTEMPTS(%d)=%d | so_a_coluna=%s | colunas_marcadas=%d | primeiro=%s" % [
			forcados, soma_motivos, buscas, Session.SPAWN_ATTEMPTS,
			buscas * Session.SPAWN_ATTEMPTS, so_a_coluna, marcadas, str(primeiro)])
	_pack_release()
	return true


## Cenario 5 (dossie 14 §5, premissa 2 no tempo): trocas de `_move_target` por
## lobo por segundo de logica. Organizado e numero, nao adjetivo -- a media por
## lobo e o pior segundo de um lobo saem no log com o teto declarado.
##
## De onde vem o teto: uma troca so conta quando o alvo escrito se move mais de
## 0,5 m no horizontal. Dois canais re-escrevem o alvo na mata e os dois tem
## cadencia de 4 Hz -- o nariz (`SCENT_PERIOD` 0,25 s) e o compromisso de
## travessia da perna (b) -- entao o pior segundo legitimo e a soma: 8 trocas/s,
## uma a cada dois passos de 20 Hz. A media se declara em 2/s, um quarto do pior
## caso, porque a patrulha e a cauda tambem tem de escrever o MESMO alvo por
## varios passos seguidos para o corpo chegar a algum lugar.
func _test_alvo_estavel_por_segundo() -> bool:
	_arm()
	_pack_session(4)
	for i: int in 4:
		_pack_place(i, FAREJAR_SPOTS[i])
	_field.imprint(SOURCE, AetherField.Channel.WORK, 0.42)
	var segundos := 20
	var ws: Array = _pack_wolves()
	var anterior: Array = []
	var por_segundo: Array = []
	for w: Wolf in ws:
		anterior.append(w._move_target)
		var linha: Array = []
		for s: int in segundos:
			linha.append(0)
		por_segundo.append(linha)
	var passos := 0
	for s: int in segundos:
		for t: int in 20:
			_advance_pack(1)
			passos += 1
			for i: int in ws.size():
				var w: Wolf = ws[i]
				if _horizontal(w._move_target - anterior[i]).length() > 0.5:
					por_segundo[i][s] += 1
				anterior[i] = w._move_target
	var soma := 0
	var pior_segundo := 0
	var pior_lobo := -1
	var linhas := ""
	for i: int in ws.size():
		var total := 0
		var pior_do_lobo := 0
		for s: int in segundos:
			total += por_segundo[i][s]
			pior_do_lobo = maxi(pior_do_lobo, por_segundo[i][s])
		soma += total
		if pior_do_lobo > pior_segundo:
			pior_segundo = pior_do_lobo
			pior_lobo = (ws[i] as Wolf).identity
		linhas += "lobo%d media=%.2f/s pior_segundo=%d | " % [
				(ws[i] as Wolf).identity, float(total) / float(segundos), pior_do_lobo]
	var media_geral := float(soma) / float(segundos * ws.size())
	_check(soma > 0, "premissa: a janela tem trocas suficientes para contar",
			"passos_por_lobo=%d trocas_total=%d %s" % [
			segundos * 20, soma, linhas.strip_edges()])
	_check(media_geral <= 2.0, "trocas de alvo por lobo por segundo de logica (media)",
			"media=%.3f/s por lobo (teto 2/s), trocas=%d em %d s com 4 lobos" % [
			media_geral, soma, segundos])
	_check(pior_segundo <= 8, "nenhum lobo troca o alvo acima do teto no pior segundo",
			"pior_segundo=%d trocas no lobo%d (teto 8/s) %s" % [
			pior_segundo, pior_lobo, linhas.strip_edges()])
	_pack_release()
	return true


## Maior conjunto de alvos que cae dentro de `raio` um do outro -- o "cinco corpos
## no mesmo ponto" da premissa 2, medido no alvo escrito e nao no corpo.
func _cluster_maximo(alvos: Array, raio: float) -> int:
	var pior := 0
	for a: int in alvos.size():
		var n := 0
		for b: int in alvos.size():
			if _horizontal(alvos[a] - alvos[b]).length() <= raio:
				n += 1
		pior = maxi(pior, n)
	return pior


func _cels_str(ws: Array) -> String:
	var out := ""
	for w: Wolf in ws:
		out += str(w._scent_cell) + " "
	return out.strip_edges()


func _intents_str(ws: Array) -> String:
	var out := ""
	for w: Wolf in ws:
		out += w.intent + " "
	return out.strip_edges()


## O veto `hunt` na ultima decisao colhida pelo escorredor do lobo: aberta quer
## dizer `vetoed == false` e score acima de zero. Le-se no escorredor e nao se
## deduz do `intent`, porque a histerese (`min_interval` 0,6 s) pode estar segurando
## a intencao antiga por mais alguns ticks do que a porta.
func _porta_hunt_aberta(w: Wolf) -> bool:
	var bd: Dictionary = w._scorer.breakdown()
	return bd.has("hunt") and not bool(bd["hunt"]["vetoed"]) \
			and float(bd["hunt"]["score"]) > 0.0


## Linha de conferencia do contagio de confianca: o trust publicado pelo vizinho, o
## que a leitura deixou em `_pack_trust`, o `_courage` resultante, o estado da porta
## e a intencao -- os cinco numeros de cada lobo, na ordem da sessao.
func _confianca_linhas(ws: Array) -> String:
	var out := ""
	for w: Wolf in ws:
		var bd: Dictionary = w._scorer.breakdown()
		var porta := "sem leitura"
		if bd.has("hunt"):
			porta = "%s score=%.6f" % [
					"aberta" if _porta_hunt_aberta(w) else "VETADA",
					float(bd["hunt"]["score"])]
		out += "lobo%d trust_pub=%.3f pack_trust=%.3f courage=%.6f hunt=%s intent=%s | " % [
				w.identity, w.trust_toward_player, w._pack_trust, w._courage,
				porta, w.intent]
	return out.strip_edges()


## Quantos dos lobos da sessao estao em `hunt` lendo `n_espera` caadores na leitura
## da matilha -- a condicao de entrada do cerco, medida e nao assumida.
func _caadores(n_espera: int) -> int:
	var total := 0
	for w: Wolf in _pack_wolves():
		if w.intent == "hunt" and w._hunt_pack_size() == n_espera:
			total += 1
	return total


## Desloca o relogio ate a fase pedida, com os quatro ainda a 8 m da presa e o
## cooldown zerado: e o unico modo de mudar a fase da entrada sem mudar o mundo, e
## a unica diferenca declarada entre os dois bracos do contraste.
func _advance_ate_fase(alvo: int, teto: int) -> void:
	var i := 0
	while i < teto and _clock.tick % 4 != alvo:
		_advance_pack(1)
		i += 1


## Uma corrida do cenario: monta a sessao, religa o jogador pela transicao real
## (`respawn_at`) e anda a 8 m ate os quatro estarem em `hunt` e cada um lendo os
## outros tres como caadores -- sem isto a primeira leitura devolve `patrol`, cada
## lobo se acha sozinho no cerco e todos mordem juntos por outra porta. Alinha a
## fase do relogio, so entao coloca os quatro dentro de `BITE_RANGE` e roda `passos`
## ticks de 20 Hz. O `passos` maior que as quatro mordidas mostra que a segunda rodada
## nao antecipa: com `BITE_COOLDOWN` de 23 ticks nenhuma mordida cai antes do tick 23.
func _corrida_mordidas(fase_entrada: int, passos: int) -> Dictionary:
	_pack_session(4)
	for i: int in 4:
		_pack_place(i, CERCAR_SPOTS[i])
	_player.respawn_at(CERCAR_PLAYER)
	var aquecimento := -1
	for i: int in 40:
		_advance_pack(1)
		if _caadores(4) == 4:
			aquecimento = _clock.tick
			break
	_advance_ate_fase(fase_entrada, 5)
	var prontos := _caadores(4)
	var ws: Array = _pack_wolves()
	for i: int in 4:
		_pack_place(i, ESCALONAR_SPOTS[i])
	var candidatos := 0
	for w: Wolf in ws:
		if w._bite_cd <= 0.0 and _horizontal(w.center() - _player.position3()).length() \
				<= Wolf.BITE_RANGE:
			candidatos += 1
	var tick_entrada: int = _clock.tick
	_bite_events.clear()
	for w: Wolf in ws:
		w.bit_player.connect(_on_bit_observed.bind(w.identity))
	for i: int in passos:
		_advance_pack(1)
	var por_tick := {}
	var ticks: Array = []
	var fase := {}
	var conflito := false
	var fora_de_fase := 0
	var n_cheio := true
	var ev_str := ""
	for ev: Array in _bite_events:
		var t: int = int(ev[0])
		var ident: int = int(ev[1])
		por_tick[t] = int(por_tick.get(t, 0)) + 1
		ticks.append(t)
		ev_str += "%d:%d(n%d,r%d,%s) " % [t, ident, int(ev[2]), int(ev[3]), String(ev[4])]
		if int(ev[2]) != 4:
			n_cheio = false
		var mod: int = t % 4
		if fase.has(mod) and int(fase[mod]) != ident:
			conflito = true
		fase[mod] = ident
		# O assento r so pode morder em `tick % n == r`, e com os quatro em `hunt`
		# o rank de cada um e a sua identidade: qualquer mordida fora desta
		# igualdade veio de outra porta.
		if mod != ident:
			fora_de_fase += 1
	ticks.sort()
	var pior := 0
	for t: int in por_tick:
		pior = maxi(pior, int(por_tick[t]))
	var consecutivos: bool = ticks.size() >= 2
	for i: int in range(1, ticks.size()):
		if int(ticks[i]) - int(ticks[i - 1]) != 1:
			consecutivos = false
	var biter_entrada := -1
	for ev: Array in _bite_events:
		if int(ev[0]) == tick_entrada:
			biter_entrada = int(ev[1])
	return {
		"mordidas": _bite_events.size(), "no_pior_tick": pior, "ticks": ticks,
		"fase": fase, "candidatos": candidatos, "prontos": prontos,
		"fase_disputada": conflito, "tick_entrada": tick_entrada,
		"fora_de_fase": fora_de_fase, "n_cheio": n_cheio, "eventos": ev_str,
		"aquecimento": aquecimento, "consecutivos": consecutivos,
		"biter_entrada": biter_entrada,
	}


## O sinal da sessao entregue ao runner: `[tick, identidade, n lido, rank lido,
## intent, fase]` de cada mordida. Os argumentos do `bind` vao DEPOIS dos do sinal,
## e a assinatura espelha isto. A fase entra com a checagem 4 do dossie 11: separar
## a mordida que nao deveria existir de nenhuma outra exige saber de que corpo ela
## saiu, e nao so de que identidade.
func _on_bit_observed(wolf: Wolf, _amount: float, ident: int) -> void:
	_bite_events.append([_clock.tick, ident, wolf._hunt_pack_size(),
			wolf._hunt_pack_rank(), wolf.intent, wolf.phase_name()])


## Angulo horizontal do alvo escrito pelo lobo em torno da presa, no eixo do mundo.
func _seat_angle(target: Vector3, prey: Vector3) -> float:
	var v := _horizontal(target - prey)
	return wrapf(atan2(v.z, v.x), 0.0, TAU)


## Quantos participantes de identidade menor precedem este lobo -- o rank que o teste
## exige, calculado pela lista viva e nao pelo metodo do lobo.
func _participantes_antes_de(w: Wolf, ws: Array) -> int:
	var rank := 0
	for other: Wolf in ws:
		if other.identity < w.identity and other.intent == "hunt":
			rank += 1
	return rank


func _ids_of(pack: Array) -> String:
	var out := ""
	for e: Dictionary in pack:
		out += "%d " % int(e["identity"])
	return out.strip_edges()


func _pack_lists_ids(pack: Array) -> Array:
	var out: Array = []
	for e: Dictionary in pack:
		out.append(int(e["identity"]))
	return out


func _finish() -> void:
	Input.mouse_mode = _mouse_mode
	_pack_release()
	_check(_ran, "runner retornou", "run=%s" % _ran)
	_check(_completed == TESTS.size(), "censo de testes completos", "%d/%d" % [_completed, TESTS.size()])
	# O budget de 400 us por mente e gate publicado, e com a alcateia dentro da
	# arvore ele passou a valer para duas colonias: a de lobo solo e a da sessao.
	_check(_bt_trips == 0 and _pack_bt_trips == 0, "nenhum estouro de subtree no budget",
			"trips_solo=%d trips_matilha=%d" % [_bt_trips, _pack_bt_trips])
	_check(_checks + 1 == EXPECTED_CHECKS, "censo de checagens", "%d/%d" % [_checks + 1, EXPECTED_CHECKS])
	print("CENARIO ESTREITO, NAO GATE P1: passos=%d sim_step total=%d us pico=%d us; BT last_us soma=%d pico=%d trips=%d" % [
		_steps, _sim_us, _sim_worst_us, _bt_us, _bt_worst_us, _bt_trips])
	print("PASSOS DE MATILHA (sessao real, difusao incluida), NAO GATE P1: passos=%d sim_tick total=%d us pico=%d us; BT last_us soma=%d pico=%d trips=%d" % [
		_pack_steps, _pack_sim_us, _pack_sim_worst_us, _pack_bt_us, _pack_bt_worst_us, _pack_bt_trips])
	if is_instance_valid(_stage):
		_stage.free()
	# Cinto e suspensorio do desmanche do gate (§5.3): se a corrida abortou no meio do
	# `contrato_igal_ao_http`, o filho que ELE subiu nao pode ficar orfao na porta 8791
	# com 2,7 GB residentes -- mata pelo pid exato guardado no lancamento, nunca por nome.
	if _af_server_pid > 0 and OS.is_process_running(_af_server_pid):
		OS.kill(_af_server_pid)
		print("contrato: desmanche tardio do llama-server pid %d que o gate subiu" % _af_server_pid)
		_af_server_pid = -1
	print("%d checagens %d falhas %.3f s" % [_checks, _failures, float(Time.get_ticks_usec() - _started_us) / 1000000.0])
	quit(1 if _failures > 0 else 0)


## Sessao na ordem do boot: o jogador primeiro, posto em `spawn_point()`, e a
## matilha depois -- `main._ready` faz exatamente isso (`player.setup(world,
## spawn_point())` antes de `_spawn_wolves(WOLF_COUNT)`), e o predicado de spawn e
## medido a partir dos pes dele. O hud real entra porque o caminho da reposicao
## fala com ele: sem hud, o `die()` da transicao derruba o passo com SCRIPT ERROR
## e as checagens do passo vao embora em silencio.
##
## `mating` presa por padrao pelo mesmo motivo do `_pack_session`, e aqui com um
## peso a mais: o cenario 6 da perna 14 marca `id_novo = _next_identity` antes de
## matar e espera que o PROXIMO incremento venha da fila de 45 s. Um parto no
## meio da janela daria o incremento primeiro e o lobo procurado seria a cria,
## nao o reposto -- a checagem passaria por outro caminho e o gate mentiria.
func _boot_session(n: int, mating: bool = false) -> void:
	_pack_release()
	var s = Session.new()
	s.world = _world
	s.aether = _field
	s.clock = _clock
	s.player = _player
	s._entities = Node3D.new()
	_stage.add_child(s._entities)
	s.hud = Hud.new()
	_stage.add_child(s.hud)
	s.hud.player = _player
	s.hud.world = _world
	s.hud.aether = _field
	s.hud.clock = _clock
	# A linha 127 do boot real: sem ela o aviso do jogador nao tem porta, e o
	# cenario 8 acusaria ausencia onde o instrumento e que esta incompleto.
	if not _player.notice.is_connected(s._on_notice):
		_player.notice.connect(s._on_notice)
	_player.feet_to_spawn(s.spawn_point())
	s._spawn_wolves(n)
	if not mating:
		s._mate_cd = INF
	_session = s


## Cenario 6 (dossie 14 §5): "nunca spawnar na frente do player, sempre numa
## distancia segura", medido e nao adjetivado.
##
## Duas camadas porque o pedido tem dois momentos: os lares do boot e o lobo novo
## que nasce da fila. A fila esvazia pela transicao real -- `die()` emite `died`, a
## recolha de cadaver de 1 s enfileira a reposicao e o `_sim_tick` conta os 45 s --
## nunca por um numero escrito na mao. Nasce vermelha por construcao: o anel
## historico sorteia 16-46 m em torno do MESMO ponto onde o boot poe o jogador, e as
## 24 tentativas caem em silencio no centro quando nao acham nada.
func _test_spawn_fora_da_vista_do_jogador() -> bool:
	_arm()
	_boot_session(5)
	var s: Session = _session
	var olho: Vector3 = _player.eye_position()
	var pes: Vector3 = _player.position3()
	var dentro := 0
	var visiveis := 0
	var lares := ""
	for w: Wolf in _pack_wolves():
		var d: float = w.home.distance_to(pes)
		var ve: bool = s.world.line_of_sight(olho, w.home + Vector3(0.0, Wolf.DIMS.y * 0.5, 0.0))
		if d < float(Session.SAFE_SPAWN_DIST):
			dentro += 1
		if ve:
			visiveis += 1
		lares += "lobo%d=%.1fm los=%s " % [w.identity, d, str(ve)]
	var d0: Dictionary = s.diagnostics()
	_check(int(d0["wolves"]) + int(d0["pending_respawns"]) == int(Session.WOLF_COUNT),
			"censo do boot fecha a conta: o que nao nasce volta para a fila",
			"matilha=%d fila=%d teto=%d" % [d0["wolves"], d0["pending_respawns"], Session.WOLF_COUNT])
	_check(dentro == 0 and visiveis == 0,
			"lares do boot fora da distancia segura e da visada do jogador",
			"seguro=%.0f m dentro=%d visiveis=%d de %d | %s" % [
			Session.SAFE_SPAWN_DIST, dentro, visiveis, _pack_wolves().size(), lares])
	var id_novo: int = int(s._next_identity)
	var vitima: Wolf = _pack_wolves()[0]
	vitima.die()
	var passos := 0
	while passos < 1400 and int(s._next_identity) == id_novo:
		passos += 1
		s._sim_tick()
		for w: Wolf in _pack_wolves():
			for frame: int in 3:
				w._physics_process(SimClock.STEP / 3.0)
	var novo: Wolf = null
	var ids := ""
	for w: Wolf in _pack_wolves():
		if w.identity == id_novo:
			novo = w
		ids += "%d " % w.identity
	var dn := -1.0
	var vn := true
	if novo != null:
		dn = novo.home.distance_to(pes)
		vn = s.world.line_of_sight(olho, novo.home + Vector3(0.0, Wolf.DIMS.y * 0.5, 0.0))
	_check(novo != null, "a fila de 45 s devolve um lobo pela transicao real",
			"passos=%d ids=[%s] fila=%d" % [passos, ids.strip_edges(), s._respawn_queue.size()])
	_check(novo != null and dn >= float(Session.SAFE_SPAWN_DIST) and not vn,
			"lobo reposto nasce fora da distancia segura e da visada",
			"dist=%.1f m seguro=%.0f los=%s home=%s" % [
			dn, Session.SAFE_SPAWN_DIST, str(vn), str(novo.home) if novo != null else "nenhum"])
	_pack_release()
	return true


## Verdade unica do cenario 7: uma linha de toast fala de criatura quando nomeia
## o bicho ou a matilha. "Fala de criatura" e a cláusula do pedido do dono ("nada
## de avisos na tela, simplesmente o player tem que achar, ver"), e a palavra e o
## numero que a decide -- nao uma lista de frases congeladas, que sobreviveria a
## um aviso novo com outra redacao.
func _toast_de_criatura(t: String) -> bool:
	return t.findn("lobo") >= 0 or t.findn("matilha") >= 0


## Cenario 7 (dossie 14 §1.3, §5): nenhuma string de presenca ou destino de
## criatura chega ao toast em 1 200 passos. Nasce VERMELHA porque o `main.gd` tem
## as duas frases. A janela nao e escolha de gosto: a morte abate na hora, a
## recolha de cadaver roda em cadencia de 1 s e a fila de reposicao cobra 45 s --
## 1 041 passos ate o lobo novo nascer, o numero medido no cenario 6.
##
## O par de checagens existe porque ausencia sozinha nao prova nada: a primeira
## medida aqui e que os DOIS caminhos que falavam do toast rodaram de dentro da
## janela (abatidos e repostos contados pelo estado autoritativo, nao escritos na
## mao). Sem ela, "nenhum aviso" poderia ser canal quebrado, e o cenario 8 é o
## outro lado dessa mesma moeda.
func _test_nenhum_aviso_de_matilha_no_hud() -> bool:
	_arm()
	_boot_session(5)
	var s: Session = _session
	var vistos := {}
	var abates := 0
	var repostos := 0
	var passo := 0
	while passo < 1200 and (abates < 2 or repostos < 1):
		if passo % 240 == 120:
			var vitima: Wolf = null
			for w: Wolf in _pack_wolves():
				if w.alive:
					vitima = w
					break
			if vitima != null:
				vitima.die()
		passo += 1
		s._sim_tick()
		for w: Wolf in _pack_wolves():
			for frame: int in 3:
				w._physics_process(SimClock.STEP / 3.0)
		var t: String = s.hud._toast.text
		if t != "" and not vistos.has(t):
			vistos[t] = passo
		abates = int(s.stats["wolves_felled"])
		repostos = int(s._next_identity) - int(Session.WOLF_COUNT)
	var criatura := ""
	var quantas := 0
	var todas := ""
	for t in vistos:
		todas += "'%s'@%d " % [t, vistos[t]]
		if _toast_de_criatura(String(t)):
			quantas += 1
			criatura += "'%s' " % t
	_check(abates >= 2 and repostos >= 1,
			"os dois caminhos de criatura rodaram dentro da janela",
			"abatidos=%d repostos=%d passos=%d fila=%d" % [
			abates, repostos, passo, s._respawn_queue.size()])
	_check(quantas == 0, "nenhum aviso de criatura chega ao toast do hud",
			"de_criatura=%d [%s] | visto: %s" % [
			quantas, criatura.strip_edges(), todas.strip_edges()])
	_pack_release()
	return true


## Cenario 8, o par obrigatorio do 7: as quatro portas de feedback da acao do
## jogador continuam chegando ao MESMO Label da MESMA sessao. Cada uma pela
## transicao real (`_craft()` do painel, `_try_place()` e `_mine_target()` da
## mira), nunca chamando `show_message` a mao -- o que se testa e a porta, nao a
## frase. Save/load fica de fora daqui de proposito: `load_game()` regenera o
## `_world` compartilhado deste runner, entao o par do toast de save e a suíte
## completa (`smoke_test`), nao este instrumento.
func _test_feedback_do_jogador_continua_no_hud() -> bool:
	_arm()
	_boot_session(5)
	var s: Session = _session
	var p: Player = _player
	# O jogador e vivo por transicao real de morte, nao por campo escrito na mao: a
	# suite roda uma vez e o cenario do spawn entrega o corpo no chao (os lobos agora
	# sobem o degrau de um bloco e alcancam a plataforma), e `update_local` devolve
	# cedo em corpo morto sem chamar `_update_target` -- a mira de (3) nao existiria.
	# `s.respawn()` nao serve aqui: este runner monta a sessao a mao, sem o boot, e o
	# `player.spawn_point` que ele usa so e escrito em `start()`/load (main.gd:114,
	# :681), entao o respawn da sessao teletransportaria para o canto do mundo.
	p.respawn_at(s.spawn_point())
	p.inv.reset_default()
	# (1) e (2) craft: a primeira receita de mao (1 madeira -> 4 tabuas) sem o
	# ingrediente, depois com ele -- as duas branches do `_craft()` do painel.
	p.inv.take(BlockDefs.Block.WOOD, 999)
	s.hud._craft()
	var sem_material: String = s.hud._toast.text
	p.inv.add(BlockDefs.Block.WOOD, 1)
	s.hud._craft()
	var craftado: String = s.hud._toast.text
	# (3) construir com a tecla apontando para um slot vazio: a mira acha o chao e
	# `_try_place` recusa antes de gastar bloco.
	p.inv.select(7)
	p.pitch = -0.9
	for _i: int in 2:
		p.update_local(1.0 / 60.0)
	# Premissa nomeada, com o numero que a decide: sem ela o silencio de (3) pode ser
	# "a mira nao achou chao nenhum" (`_try_place` devolve em `not target_valid`,
	# player.gd:676), que e outro defeito e merece outro letreiro.
	var aim := _world.ray_voxel(p.eye_position(),
			p.camera.global_transform.basis.z * -1.0, Player.REACH)
	_check(p.alive and p.target_valid and aim.valid and aim.distance <= Player.REACH,
			"premissa: vivo, sem entidade na mira e o raio achando o chao",
			"vivo=%s hp=%.0f alvo='%s' valid=%s d=%.2f/%.1f voxel=%s" % [
			p.alive, p.hp, p.look_target_name, p.target_valid,
			aim.distance, Player.REACH, p.target_voxel])
	p._try_place()
	var slot_vazio: String = s.hud._toast.text
	# (4) lavrar o que nao cabe: o inventario fecha antes do golpe, e `_mine_target`
	# devolve o aviso em vez de tirar o bloco do mundo.
	var drop := BlockDefs.drop_of(_world.get_block(p.target_voxel))
	var enchimentos := 0
	while p.inv.space_for(drop, 1) > 0 and enchimentos < Inventory.SLOTS:
		enchimentos += 1
		p.inv.add(drop, BlockDefs.stack_max(drop))
	var antes := _world.get_block(p.target_voxel)
	p._mine_target()
	var cheio: String = s.hud._toast.text
	_check(sem_material.begins_with("sem material"),
			"o craft sem material continua avisando", "'%s'" % sem_material)
	_check(craftado.begins_with("craftado"),
			"o craft com material continua avisando", "'%s'" % craftado)
	_check(slot_vazio.begins_with("slot vazio"),
			"construir em slot vazio continua avisando", "'%s'" % slot_vazio)
	_check(cheio.begins_with("inventario cheio")
			and _world.get_block(p.target_voxel) == antes,
			"lavra sem espaco continua avisando e nao tira o bloco",
			"'%s' voxel=%d->%d espaco=%d" % [
			cheio, antes, _world.get_block(p.target_voxel), p.inv.space_for(drop, 1)])
	_pack_release()
	return true


## Checagem 3 do dossie 11 §5: o filhote cresce com o TICK de simulacao, e o corpo
## que muda e o colisor, nao so o desenho (dossie 11 §3.2 -- `DIMS` para de ser o
## corpo de todo mundo).
##
## A premissa nomeada e a que decide o numero: os unios limiares sao
## `CUB_STEPS` e `JUVENILE_STEPS` PASSOS de 20 Hz, entao a fase tem de virar no
## passo exato em que `age_ticks` cruza -- e um passo antes ainda nao. Um
## relogio de parede (`Time.get_ticks_*`, `delta` de frame) nao teria como
## reproduzir essa fronteira, e e ela que o journal podera conferir depois.
##
## O filhote entra em cena pela porta publica `set_phase()`, a mesma que a sessao
## chama no nascimento (cenario 1, dossie 11 §3.4), e o `age_ticks = 0` e o que
## aquela porta poe: nenhum campo interno escrito a mao. O ferimento vem de
## `take_damage`, a unica transicao que fere um lobo no jogo.
func _test_filhote_cresce_por_tick() -> bool:
	_arm()
	_wolf.set_phase(Wolf.Phase.CUB)
	_wolf.age_ticks = 0
	var escala_filhote: float = Wolf.PHASE_SCALE[Wolf.Phase.CUB]
	var escala_jovem: float = Wolf.PHASE_SCALE[Wolf.Phase.JUVENILE]
	_check(is_equal_approx(_wolf.dims.x, Wolf.DIMS.x * escala_filhote)
			and is_equal_approx(_wolf.body.dims.y, Wolf.DIMS.y * escala_filhote)
			and is_equal_approx(_wolf._visual.scale.x, escala_filhote)
			and is_equal_approx(_wolf.max_hp(), Wolf.MAX_HP * escala_filhote)
			and is_equal_approx(_wolf.bite_damage(), Wolf.BITE_DAMAGE * escala_filhote),
			"premissa: filhote nasce com corpo, teto e boca da fase",
			"escala=%.2f dims=%s colisor=%s max_hp=%.2f mordida=%.2f (adulto: dims=%s hp=%.1f)" % [
			escala_filhote, _wolf.dims, _wolf.body.dims, _wolf.max_hp(), _wolf.bite_damage(),
			Wolf.DIMS, Wolf.MAX_HP])
	# Ferido de verdade, para a proporcao de vida ser um numero que nao pode
	# coincidir por constricao: 0,5 atravessa os dois crescimentos.
	_wolf.take_damage(_wolf.max_hp() * 0.5, Wolf.ACTOR_PLAYER, _wolf.center())
	var proporcao: float = _wolf.hp / _wolf.max_hp()
	_advance(Wolf.CUB_STEPS - 1, true)
	_check(_wolf.phase == Wolf.Phase.CUB and _wolf.age_ticks == Wolf.CUB_STEPS - 1,
			"um passo antes do limiar ainda e filhote",
			"age_ticks=%d limiar=%d fase=%s" % [_wolf.age_ticks, Wolf.CUB_STEPS, _wolf.phase_name()])
	_check(is_equal_approx(_wolf.body.aabb().size.y, _wolf.dims.y)
			and _wolf.body.aabb().size.y < Wolf.DIMS.y and _wolf.body.on_ground,
			"o colisor encolhe de verdade e o corpo continua apoiado",
			"altura_colisor=%.3f altura_adulto=%.3f no_chao=%s andou=%s" % [
			_wolf.body.aabb().size.y, Wolf.DIMS.y, str(_wolf.body.on_ground),
			str(_wolf.body.feet_pos.distance_to(SPAWN) > 0.05)])
	_advance(1)
	_check(_wolf.phase == Wolf.Phase.JUVENILE and _wolf.age_ticks == Wolf.CUB_STEPS
			and is_equal_approx(_wolf.dims.y, Wolf.DIMS.y * escala_jovem),
			"no passo exato do limiar vira jovem",
			"age_ticks=%d limiar=%d fase=%s dims=%s passos_andados=%d" % [
			_wolf.age_ticks, Wolf.CUB_STEPS, _wolf.phase_name(), _wolf.dims, _wolf.age_ticks])
	_advance(Wolf.JUVENILE_STEPS - Wolf.CUB_STEPS - 1)
	_check(_wolf.phase == Wolf.Phase.JUVENILE,
			"o jovem nao vira adulto antes do segundo limiar",
			"age_ticks=%d faltam=%d para=%d" % [
			_wolf.age_ticks, Wolf.JUVENILE_STEPS - _wolf.age_ticks, Wolf.JUVENILE_STEPS])
	_advance(1)
	_check(_wolf.phase == Wolf.Phase.ADULT and is_equal_approx(_wolf.dims.y, Wolf.DIMS.y)
			and is_equal_approx(_wolf._visual.scale.x, 1.0),
			"no passo do segundo limiar volta ao corpo historico medido nas rodadas 09 e 14",
			"age_ticks=%d fase=%s dims=%s escala=%.2f" % [
			_wolf.age_ticks, _wolf.phase_name(), _wolf.dims, _wolf._visual.scale.x])
	_check(is_equal_approx(_wolf.hp / _wolf.max_hp(), proporcao)
			and is_equal_approx(_wolf.max_hp(), Wolf.MAX_HP),
			"a proporcao de vida atravessa os dois crescimentos sem perder sangue",
			"proporcao %.4f -> %.4f  hp %.2f/%.2f" % [
			proporcao, _wolf.hp / _wolf.max_hp(), _wolf.hp, _wolf.max_hp()])
	return true


## Checagem 1 do dossie 11 §5: dois adultos ao alcance, cooldown zerado, e o censo
## cresce UM. O numero nao vem de um `+=` escrito pelo teste -- vem de
## `wolves.size()` lido antes e depois de um passo da sessao inteira, pela porta
## real (`_sim_tick` -> `_scan_breeding` -> `_born_from` -> `_make_wolf`).
##
## A premissa nomeada e a geometria, e ela sai impressa primeiro: se o par A
## estivesse fora dos 8 m, ou se o par B tambem estivesse dentro, "cresceu um"
## teria outra origem e nao a que o gate afirma.
##
## Nasce VERMELHA no codigo anterior ao lote: nao existia roda nenhuma --
## `WOLF_COUNT` era teto e chao ao mesmo tempo, e o unico caminho que punha bicho
## no mundo era o sorteio do boot.
func _test_acasalar_aumenta_censo() -> bool:
	_arm()
	_pack_session(4, true)  # a roda anda: este cenario e sobre populacao
	var s: Session = _session
	for i: int in 4:
		_pack_place(i, MATE_SPOTS[i])
	var ws: Array = _pack_wolves()
	var par_a: float = ws[0].center().distance_to(ws[1].center())
	var par_b: float = ws[2].center().distance_to(ws[3].center())
	var cruz: float = ws[1].center().distance_to(ws[2].center())
	_check(par_a <= float(Session.MATE_RADIUS) and par_b <= float(Session.MATE_RADIUS)
			and cruz > float(Session.MATE_RADIUS),
			"premissa: os dois pares se alcançam e nenhum dos dois alcança o vizinho",
			"par_A=%.2f m par_B=%.2f m cruz=%.2f m raio=%.1f m" % [
			par_a, par_b, cruz, Session.MATE_RADIUS])
	var d0: Dictionary = s.diagnostics()
	var ids_antes := {}
	for w: Wolf in ws:
		ids_antes[w.identity] = true
	# Um unico passo: `_mate_cd` comeca em 0,0, entao a primeira varredura e no
	# tick 1, e ela para no primeiro par encontrado -- o A (indices 0 e 1).
	_advance_pack(1)
	var d1: Dictionary = s.diagnostics()
	var novo: Wolf = null
	var ids := ""
	for w: Wolf in s.wolves:
		ids += "%d(%s) " % [w.identity, w.phase_name()]
		if not ids_antes.has(w.identity):
			novo = w
	_check(int(d1["wolves"]) == int(d0["wolves"]) + 1
			and int(d1["births"]) == int(d0["births"]) + 1,
			"acasalar aumenta o censo em um e o counter acompanha",
			"censo %d -> %d  nascimentos=%d recusas=%d teto=%d  ids=[%s]" % [
			d0["wolves"], d1["wolves"], d1["births"], d1["census_refusals"],
			d1["census_cap"], ids.strip_edges()])
	var fase := "nenhum"
	var idade := -1
	var escala := -1.0
	var boca := -1.0
	if novo != null:
		fase = novo.phase_name()
		idade = novo.age_ticks
		escala = Wolf.PHASE_SCALE[novo.phase]
		boca = novo.bite_damage()
	_check(novo != null and novo.phase == Wolf.Phase.CUB and novo.age_ticks == 0,
			"o que nasce e filhote, com idade zero e corpo da fase",
			"phase=%s age_ticks=%d escala=%.2f mordida=%.2f (adulto: %.2f)" % [
			fase, idade, escala, boca, Wolf.BITE_DAMAGE])
	# O predicado da perna 14 vale para o parto tambem: `_born_from` chama o MESMO
	# `_spawn_home_point`, e um recem-nato na frente do jogador seria a promessa
	# cumprida no boot e traída no primeiro filhote.
	var dist_lar := -1.0
	var visado := true
	if novo != null:
		dist_lar = novo.home.distance_to(_player.position3())
		visado = s.world.line_of_sight(_player.eye_position(),
				novo.home + Vector3(0.0, Wolf.DIMS.y * 0.5, 0.0))
	_check(novo != null and dist_lar >= float(Session.SAFE_SPAWN_DIST) and not visado,
			"o recem-nato passa pelo predicado do spawn: longe e fora da visada",
			"dist=%.1f m seguro=%.0f los=%s home=%s" % [
			dist_lar, Session.SAFE_SPAWN_DIST, str(visado),
			str(novo.home) if novo != null else "nenhum"])
	_pack_release()
	return true


## Checagem 2 do dossie 11 §5: o mesmo par nao cria duas vezes com o cooldown
## aberto. O que prova isso e a ARITMETICA do `mate_cd`, nao a ausencia de um
## filhote -- sem cooldown a varredura do tick 21 reencontraria o par A (ainda a
## 3 m, varrido primeiro) e resetaria o `mate_cd` dele para 300,0; com cooldown
## vale 300,0 menos os desgastes andados. O valor lido decide qual dos dois
## mundos aconteceu.
##
## O par B e o controle do outro lado da moeda: ele nunca cruzou, entao cria na
## mesma varredura. Sem ele, "nenhum parto extra" poderia ser roda quebrada.
##
## Vencer os 300 s por tempo real custaria 6 000 passos de matilha (~10 s de
## suíte) e nao acrescentaria nada: quem desgasta o cooldown e o mesmo `dt` de
## 1/20 s do passo de simulacao, entao o tempo que falta sai da divisao e vai
## impresso.
func _test_cooldown_segunda_copula() -> bool:
	_arm()
	_pack_session(4, true)  # a roda anda: este cenario e sobre populacao
	var s: Session = _session
	for i: int in 4:
		_pack_place(i, MATE_SPOTS[i])
	var ws: Array = _pack_wolves()
	_advance_pack(1)
	_check(int(s.diagnostics()["births"]) == 1
			and is_equal_approx(ws[0].mate_cd, Session.MATE_COOLDOWN)
			and is_equal_approx(ws[1].mate_cd, Session.MATE_COOLDOWN),
			"premissa: a primeira varredura cria um e trava os dois pelos 300 s",
			"nascimentos=%d mate_cd_A=%.3f mate_cd_B=%.3f cooldown=%.1f s" % [
			s._births, ws[0].mate_cd, ws[1].mate_cd, Session.MATE_COOLDOWN])
	# 20 passos ate a varredura do tick 21 (`MATE_PERIOD` = 1,0 s = 20 passos).
	_advance_pack(20)
	var esperado: float = Session.MATE_COOLDOWN - 20.0 * SimClock.STEP
	var crias := 0
	for w: Wolf in s.wolves:
		if w.phase == Wolf.Phase.CUB:
			crias += 1
	_check(int(s.diagnostics()["births"]) == 2 and crias == 2 and s.wolves.size() == 6,
			"na segunda varredura cria o par que nunca cruzou, nao o par travado",
			"nascimentos=%d crias=%d censo=%d" % [s._births, crias, s.wolves.size()])
	_check(absf(ws[0].mate_cd - esperado) < 1e-6,
			"o cooldown do par A desgastou só pelo tempo de simulacao andado",
			"mate_cd=%.4f esperado=%.4f  um segundo parto do par A o poria em %.1f  faltam %.2f s = %d passos" % [
			ws[0].mate_cd, esperado, Session.MATE_COOLDOWN, ws[0].mate_cd,
			int(ceil(ws[0].mate_cd / SimClock.STEP))])
	# Cinco varreduras depois, com os quatro adultos ainda a 3 m dos parceiros.
	_advance_pack(100)
	_check(int(s.diagnostics()["births"]) == 2 and s.wolves.size() == 6,
			"varreduras seguidas com os pares ao alcance nao passam de um parto por par",
			"nascimentos=%d censo=%d mate_cd_A=%.2f mate_cd_par_B=%.2f" % [
			s._births, s.wolves.size(), ws[0].mate_cd, ws[2].mate_cd])
	_pack_release()
	return true


## Checagem 6 do dossie 11 §5: acasalamentos ate o teto. O censo para em
## `CENSUS_CAP` e a recusa e CONTADA -- `census_refusals` sobe junto com a linha
## `nascimento RECUSADO` que sai no stdout desta corrida, entao "parou no teto"
## nunca e um bicho que desapareceu em silencio (mandato 1).
##
## O fechamento que da dente ao numero e `censo == boot + nascimentos`: uma
## tentativa que morresse sem incrementar nada e sem imprimir nada nao fecharia a
## soma. Os 11 adultos vem do `_spawn_wolves` real e a premissa de que pousaram e
## checada ANTES de qualquer posicao escrita, senao o teste mediria um censo que
## nunca existiu.
func _test_censo_respeita_teto() -> bool:
	_arm()
	_pack_session(11, true)  # a roda anda: este cenario e sobre populacao
	var s: Session = _session
	var fila: int = s._respawn_queue.size()
	_check(s.wolves.size() == 11 and fila == 0,
			"premissa: a porta do sorteio pousou 11 adultos sem sobrar vaga na fila",
			"censo=%d fila=%d recusas_de_censo=%d" % [
			s.wolves.size(), fila, int(s.diagnostics()["census_refusals"])])
	for i: int in mini(11, s.wolves.size()):
		_pack_place(i, CAP_SPOTS[i])
	var d0: Dictionary = s.diagnostics()
	# Tick 1: o par A cria e o censo encosta em 12. Tick 21: o par A esta travado,
	# o par B tenta e esbarra no teto -- a recusa e do censo, nao do ponto.
	_advance_pack(21)
	var d1: Dictionary = s.diagnostics()
	_check(int(d1["wolves"]) == int(Session.CENSUS_CAP)
			and int(d1["births"]) == int(d0["births"]) + 1,
			"o censo sobe ate o teto de 12 e para ali",
			"censo %d -> %d  teto=%d  nascimentos=%d" % [
			d0["wolves"], d1["wolves"], d1["census_cap"], d1["births"]])
	_check(int(d1["census_refusals"]) == int(d0["census_refusals"]) + 1,
			"a cria acima do teto e recusada contada, nao silenciosa",
			"recusas %d -> %d" % [d0["census_refusals"], d1["census_refusals"]])
	_advance_pack(400)
	var d2: Dictionary = s.diagnostics()
	var adultos := 0
	for w: Wolf in s.wolves:
		if w.phase == Wolf.Phase.ADULT:
			adultos += 1
	_check(int(d2["wolves"]) == int(Session.CENSUS_CAP)
			and int(d2["wolves"]) == int(d0["wolves"]) + int(d2["births"]) - int(d0["births"])
			and adultos == 11,
			"20 s de varreduras no teto: nenhum bicho a mais e a conta boot+crias fecha",
			"censo=%d nascimentos=%d recusas=%d adultos=%d fechamento=%d" % [
			d2["wolves"], d2["births"], d2["census_refusals"], adultos,
			int(d0["wolves"]) + int(d2["births"]) - int(d0["births"])])
	_pack_release()
	return true


## Checagem 4 do dossie 11 §5: o filhote nunca emite `bit_player`. A geometria e a
## do ataque escalonado, ja provada nesta suíte: quatro adultos a 1,5 m do jogador,
## todos em `hunt`, cada assento mordendo no seu `tick % 4`. O filhote entra no
## mesmo anel pela unica porta que poe um lobo no mundo -- `_make_wolf` com a fase e
## a idade que `_born_from` passa (§3.4) -- entao a diferenca entre ele e os quatro
## e so a fase do corpo: mesmo alcance, mesma visada, mesma leitura da matilha.
##
## O portao esta no scorer e nao na arvore, e a checagem 4 e o que paga essa
## escolha: travar só o `Selector` deixaria o filhote publicando `hunt`, os irmãos
## contando um assento a mais e o F3 mentindo. Aqui os quatro numeros se fecham:
## 1. premissa -- o filhote esta ao alcance, visado, vivo e lido pelos quatro;
##    sem isto "zero mordidas" e ausencia de bicho na cena, nao portao.
## 2. controle -- na MESMA janela os quatro adultos mordem; sem isto o zero poderia
##    ser o caminho da mordida quebrado (ciclo 3: a atribuicao fecha nos dois
##    sentidos).
## 3. nenhum `bit_player` do filhote em 120 passos -- cinco janelas de
##    `BITE_COOLDOWN` de 1,15 s -- e nenhum passo dele com `intent == hunt`.
## 4. o assento nao o conta: cada adulto le quatro vizinhos (tres adultos + o
##    filhote) e no tick em que os quatro caçam o cerco continua com quatro assentos
##    -- contando o filhote seriam 5, e nenhum `n` de mordida chega lá. No fim da
##    janela a conta e relida contra os cacadores daquele momento, porque o sangue
##    que as próprias mordidas imprimem puxa parte da matilha para `investigate`:
##    isso e o mundo reagindo, nao folga escondendo o numero.
func _test_filhote_nao_morde() -> bool:
	_arm()
	_pack_session(4)  # roda de acasalamento congelada: aqui o censo nao e a variavel
	for i: int in 4:
		_pack_place(i, CERCAR_SPOTS[i])
	_player.respawn_at(CERCAR_PLAYER)
	var aquecimento := -1
	for i: int in 40:
		_advance_pack(1)
		if _caadores(4) == 4:
			aquecimento = _clock.tick
			break
	var s: Session = _session
	for i: int in 4:
		_pack_place(i, ESCALONAR_SPOTS[i])
	var filhote: Wolf = s._make_wolf(FILHOTE_SPOT, s._next_identity, Wolf.Phase.CUB, 0)
	s._next_identity += 1
	s.wolves.append(filhote)
	var adultos: Array = []
	for w: Wolf in _pack_wolves():
		if w != filhote:
			adultos.append(w)
			w.bit_player.connect(_on_bit_observed.bind(w.identity))
	filhote.bit_player.connect(_on_bit_observed.bind(filhote.identity))
	_bite_events.clear()
	# Um passo antes de medir: sem ele a leitura da matilha ainda seria a do tick
	# anterior ao recem-chegado, e a premissa 1 seria conferida numa lista velha.
	_advance_pack(1)
	var lidos := 0
	for w: Wolf in adultos:
		for e: Dictionary in w._pack:
			if int(e["identity"]) == filhote.identity:
				lidos += 1
	_check(filhote.alive and filhote.phase == Wolf.Phase.CUB
			and filhote._dist_player <= Wolf.BITE_RANGE and filhote._los_player
			and lidos == 4,
			"premissa: o filhote esta no anel da mordida, visado e lido pelos quatro",
			"dist=%.2f m alcance=%.2f los=%s fase=%s lidos=%d/4 censo=%d" % [
			filhote._dist_player, Wolf.BITE_RANGE, str(filhote._los_player),
			filhote.phase_name(), lidos, s.wolves.size()])
	var n_max := 0
	var n_com_quatro := -1
	var cacadores_max := 0
	var intents := {}
	for i: int in 120:
		_advance_pack(1)
		intents[filhote.intent] = int(intents.get(filhote.intent, 0)) + 1
		var caando := 0
		var n_do_tick := 0
		for w: Wolf in adultos:
			if w.intent == "hunt":
				caando += 1
				n_do_tick = w._hunt_pack_size()
				n_max = maxi(n_max, n_do_tick)
		# O numero que importa: no tick em que os quatro cacam, com o filhote na
		# leitura de todos, o cerco tem de continuar tendo quatro assentos. Se o
		# filhote entrasse na conta, aqui seria 5.
		if caando == 4 and n_com_quatro < 0:
			n_com_quatro = n_do_tick
		cacadores_max = maxi(cacadores_max, caando)
	var mordidas_adultas := 0
	var mordidas_filhote := 0
	var mordedores := {}
	var por_n := {}
	for ev: Array in _bite_events:
		if String(ev[5]) == "filhote":
			mordidas_filhote += 1
		else:
			mordidas_adultas += 1
			mordedores[int(ev[1])] = true
		por_n[int(ev[2])] = int(por_n.get(int(ev[2]), 0)) + 1
	var n_str := ""
	for k: int in por_n:
		n_str += "n%d=%d " % [k, por_n[k]]
	var intents_str := ""
	for k: String in intents:
		intents_str += "%s:%d " % [k, intents[k]]
	_check(mordidas_adultas >= 4 and mordedores.size() == 4 and cacadores_max == 4,
			"controle: na mesma janela os quatro adultos mordem e estao no cerco",
			"mordidas_adultas=%d mordedores=%d cacadores_max=%d passos=120 cooldown=%.2f s aquecimento_tick=%d" % [
			mordidas_adultas, mordedores.size(), cacadores_max, Wolf.BITE_COOLDOWN,
			aquecimento])
	_check(mordidas_filhote == 0 and not intents.has("hunt"),
			"o filhote nunca emite bit_player e nunca intenta caar",
			"mordidas_filhote=%d intents_do_filhote=[%s] alcance=%.2f m" % [
			mordidas_filhote, intents_str.strip_edges(), filhote._dist_player])
	var primeiro: Wolf = adultos[0]
	var vizinhos := primeiro._pack.size()
	var no_cerca := primeiro._hunt_pack_size()
	var cacadores_agora := 0
	for w: Wolf in adultos:
		if w != primeiro and w.intent == "hunt":
			cacadores_agora += 1
	_check(vizinhos == 4 and n_com_quatro == 4 and n_max == 4 and not por_n.has(5)
			and no_cerca == 1 + cacadores_agora,
			"o assento angular le o filhote na matilha mas nunca o conta no cerco",
			"vizinhos_lidos=%d com_quatro_cacando_n=%d n_max=%d n_agora=%d cacadores_agora=%d esperados=%d mordidas_por_n=[%s] (contando o filhote seriam 5)" % [
			vizinhos, n_com_quatro, n_max, no_cerca, cacadores_agora,
			1 + cacadores_agora, n_str.strip_edges()])
	_pack_release()
	return true


## Checagem 7 do dossie 11 §5: o LOTE novo (fase, idade, cooldown) nao entra na
## projecao minima do journal -- o hash do tick nao muda e `FORMAT_VERSION`
## continua 1.
##
## A comparacao e nos DOIS sentidos (ciclo 3 do AGENTS.md: a atribuicao fecha
## nos dois sentidos). O hash tem de ficar IGUAL quando o lote entra e tem de
## MUDAR quando muda o que esta na projecao. Um instrumento que nao responde a
## nada provaria tanto que o lote nao mexe nele quanto que o instrumento esta
## cego -- e as duas coisas se parecem na tela.
##
## O que entra na projecao esta escrito em `tick_journal.gd:16-44`:
## `FORMAT_VERSION`, semente, `GEN_VERSION`, tick, dimensoes do mundo e do Eter,
## `Channel.COUNT`, as edicoes ordenadas e, por lobo vivo, `identity`,
## `mind.identity`, `mind.kind`, `intent` e as crencas ordenadas por chave.
## Fase, idade e cooldown NAO estao la: o lote muda o estado do animal no disco
## (`Wolf.state_dict`) e nao o hash -- por isso a decisao de formato e "nao
## muda", e nao um numero reescrito para caber.
func _test_journal_hash_inalterado_sem_escolha() -> bool:
	_arm()
	var roster: Array = [_wolf]
	var tick: int = _clock.tick
	var hash_antes: String = TickJournal.state_hash(tick, _world, _field, roster)
	# O lote: o animal vira filhote, com idade zero e cooldown cheio -- as tres
	# chaves novas do disco (dossie 11 §3.5), pelo caminho real do corpo (a fase
	# re-escala o colisor e a vida).
	_wolf.age_ticks = 0
	_wolf.set_phase(Wolf.Phase.CUB)
	_wolf.mate_cd = 300.0
	var hash_depois: String = TickJournal.state_hash(tick, _world, _field, roster)
	_check(hash_antes == hash_depois,
			"o lote (fase, idade, cooldown) nao move o hash do tick",
			"antes=%s depois=%s tick=%d FORMAT_VERSION=%d" % [
			hash_antes.substr(0, 16), hash_depois.substr(0, 16), tick,
			TickJournal.FORMAT_VERSION])
	# O outro lado: o hash tem de responder ao que ESTA na projecao. A crenca e
	# o campo mais barato -- uma linha de crenca e um float -- e a mesma chave
	# com a confianca mexida muda o conteudo sem mudar o conjunto de chaves.
	_wolf.mind.reinforce("probe_journal", 0.50, "perception")
	var hash_crenca: String = TickJournal.state_hash(tick, _world, _field, roster)
	_wolf.mind.reinforce("probe_journal", 0.60, "perception")
	var hash_crenca2: String = TickJournal.state_hash(tick, _world, _field, roster)
	_check(hash_crenca != hash_crenca2,
			"o hash responde ao que esta na projecao (mesma chave, confianca diferente)",
			"crenca_050=%s crenca_060=%s" % [
			hash_crenca.substr(0, 16), hash_crenca2.substr(0, 16)])
	# O lote esta mesmo no disco -- e chave de registro, nao campo virtual: sem
	# estas chaves o load perderia a fase e o bicho voltaria adulto.
	var d: Dictionary = _wolf.state_dict()
	_check(d.has("phase") and d.has("age_ticks") and d.has("mate_cd")
			and int(d["phase"]) == int(Wolf.Phase.CUB) and int(d["age_ticks"]) == 0
			and is_equal_approx(float(d["mate_cd"]), 300.0)
			and TickJournal.FORMAT_VERSION == 1,
			"o disco carrega o lote e o FORMAT_VERSION do journal continua 1",
			"phase=%s age_ticks=%s mate_cd=%s FORMAT_VERSION=%d" % [
			str(d.get("phase", -1)), str(d.get("age_ticks", -1)),
			str(d.get("mate_cd", -1.0)), TickJournal.FORMAT_VERSION])
	# E o caminho do disco reidrata o lote: a fase volta do disco e o corpo
	# inteiro muda com ela.
	var d2: Dictionary = d.duplicate(true)
	d2["phase"] = int(Wolf.Phase.JUVENILE)
	d2["age_ticks"] = Wolf.CUB_STEPS
	d2["mate_cd"] = 12.5
	_wolf.load_state(d2)
	_check(_wolf.phase == Wolf.Phase.JUVENILE and _wolf.age_ticks == Wolf.CUB_STEPS
			and is_equal_approx(_wolf.mate_cd, 12.5) and not _wolf.is_adult()
			and is_equal_approx(_wolf.dims.y,
					Wolf.DIMS.y * Wolf.PHASE_SCALE[Wolf.Phase.JUVENILE]),
			"o load do disco reidrata fase, idade e cooldown, e o corpo da fase vem junto",
			"fase=%s idade=%d mate_cd=%.2f dims=%s escala=%.2f" % [
			_wolf.phase_name(), _wolf.age_ticks, _wolf.mate_cd, str(_wolf.dims),
			Wolf.PHASE_SCALE[Wolf.Phase.JUVENILE]])
	return true


## ------------------------------------------------------------------ tocas (dossie 16)

## Componentes conexos do grafo que a matilha le (dossie 16 §1). Os nos sao os
## vivos da sessao e a aresta e uma entrada de `pack_of()`: nada aqui recalcula
## distancia, porque o que se quer medir e o que a alcateia **e** para o lobo, nao
## o que o sorteio tinha em mente -- separacao declarada que o lobo nao le e o
## mesmo defeito que o dossie 10 §3.2 recusou do outro lado. Devolve uma lista de
## componentes, cada um a lista de identidades.
##
## Alocar aqui e deliberado: a conta roda no gate, nunca no passo (dossie 16 §4
## prende o rebuild de componentes fora do caminho quente).
func _componentes_da_matilha(s: Session) -> Array:
	var nos: Array = []
	var arestas: Dictionary = {}
	for w: Wolf in s.wolves:
		if not w.alive:
			continue
		nos.append(w.identity)
		var viz: Array = []
		for e: Dictionary in s.pack_of(w.identity):
			viz.append(int(e["identity"]))
		arestas[w.identity] = viz
	var vistos: Dictionary = {}
	var out: Array = []
	for id: int in nos:
		if vistos.has(id):
			continue
		var pilha: Array = [id]
		var comp: Array = []
		vistos[id] = true
		while pilha.size() > 0:
			var c: int = int(pilha.pop_back())
			comp.append(c)
			for v: int in arestas[c]:
				if arestas.has(v) and not vistos.has(v):
					vistos[v] = true
					pilha.append(v)
		out.append(comp)
	return out


## Menor distancia lar-a-lar entre componentes diferentes, no chao. NAO e o
## `den_min_dist` do §3.5, e dizer isso aqui e o ponto: os dois numeros nao podem
## ser o mesmo criterio, porque a entrada de §3.2.3 poe um membro a ate
## `PACK_LEASH` (18 m) do centro da propria toca. Com tocas a 48 m, dois lares de
## tocas vizinhas podem ficar a 48-18 = 30 m, e a coesao le posicoes, nao centros.
## A medida decide algo diferente da fundacao: decide se o que se espalhou por
## lugar continua separado por leitura. Devolve `INF` com um componente so, e a
## linha impressa diz `sem_par` em vez de disfarçar o vazio de numero grande.
func _separacao_dos_componentes(s: Session, comps: Array) -> float:
	var lares: Dictionary = {}
	for w: Wolf in s.wolves:
		lares[w.identity] = w.home
	var menor := INF
	for i in comps.size():
		for j in range(i + 1, comps.size()):
			for a: int in comps[i]:
				for b: int in comps[j]:
					var p: Vector3 = lares[a]
					var q: Vector3 = lares[b]
					menor = minf(menor, Vector2(p.x, p.z).distance_to(Vector2(q.x, q.z)))
	return menor


## O `den_min_dist` de §3.5, no sentido em que a sessao o publica: minimo entre
## CENTRO de toca, no chao -- o mesmo eixo do portao `_den_gate_ok`, que tambem
## mede no chao. E este o numero que a fundacao decide; o de cima e uma
## observacao impressa ao lado, nao criterio (§5.1.(iii) pedia "separacao" sem
## dizer qual das duas, e a pagina diz agora).
func _separacao_das_tocas(s: Session) -> float:
	var menor := INF
	for i in s._dens.size():
		var a: Vector3 = s._dens[i]
		for j in range(i + 1, s._dens.size()):
			var b: Vector3 = s._dens[j]
			menor = minf(menor, _no_chao(a, b))
	return menor


## Distancia no chao (XZ), o eixo que a perna 16 usa para tudo: o portao
## `_den_gate_ok`, a mordaca `PACK_LEASH` e os dois numeros que as checagens 4 e 5
## exigem. Medir 3D aqui seria imprimir um numero que nenhuma regra pede -- os
## centros tem alturas diferentes por relevo, e a promessa e de separacao no solo.
func _no_chao(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


## O par que `_scan_breeding` acharia AGORA (main.gd:422-434), espelhado na mesma
## ordem (`i` entao `j` crescentes), no mesmo predicado (`_breedable`) e na mesma
## metrica (`center()` contra `MATE_RADIUS`), sem escrever nada em lugar nenhum.
## Devolve os INDICES de `wolves`, e sao eles que saem impressos na premissa da
## checagem 5: sem esta testemunha, "a cria ficou na toca dos pais" poderia passar
## com um par que o teste nunca nomeou -- inclusive um par que ja se alcançava no
## sorteio do boot, que e outro caminho para o mesmo `den`.
func _primeiro_par(s: Session) -> Array:
	for i in s.wolves.size():
		var a: Wolf = s.wolves[i]
		if not s._breedable(a):
			continue
		for j in range(i + 1, s.wolves.size()):
			var b: Wolf = s.wolves[j]
			if not s._breedable(b):
				continue
			var d2: float = a.center().distance_squared_to(b.center())
			if d2 <= Session.MATE_RADIUS * Session.MATE_RADIUS:
				return [i, j]
	return []


## Checagem 1 do dossie 16 §5: **nasce vermelha** e e a premissa inteira da pagina.
## `_pack_leash()` -- hoje apagada -- ancora os quatro bichos seguintes no lar do
## PRIMEIRO vivo, entao os cinco lares cabem no disco de 18 m da mordaca, o grafo de
## coesao fica com um componente so, e o dono percorreu o vale inteiro vendo um lobo.
##
## Os dois numeros do criterio vem das constantes da sessao desde o commit (b), e a
## pagina re-derivou o criterio contra elas: `componentes >= DEN_COUNT` e o espalhado
## pedido; `maior <= censo - 2` e a anti-farsa de fundo (com 5 bichos, 3 tocas e um
## componente de 4, a distribuicao e 4/1/1 e o vale continua tendo um dono); e
## `den_min_dist >= DEN_MIN_DIST` e o portao da fundacao lido entre CENTROS, que e o
## sentido publicado em §3.5 -- a distancia lar-a-lar sai impressa ao lado como
## observacao porque ela nao pode ser criterio (§3.2.3 poe membros dentro de 18 m do
## proprio centro).
func _test_tocas_distintas_no_boot() -> bool:
	_arm()
	_boot_session(5)
	var s: Session = _session
	s._rebuild_packs()
	var comps := _componentes_da_matilha(s)
	var maior := 0
	var censo := 0
	for c: Array in comps:
		maior = maxi(maior, c.size())
	for w: Wolf in _pack_wolves():
		if w.alive:
			censo += 1
	var centros := _separacao_das_tocas(s)
	var lar := _separacao_dos_componentes(s, comps)
	var lares := ""
	for w: Wolf in _pack_wolves():
		lares += "lobo%d(toca=%s,lar=(%.0f,%.0f)) " % [
				w.identity, str(w.den), w.home.x, w.home.z]
	_check(comps.size() >= Session.DEN_COUNT and maior <= censo - 2
			and centros >= Session.DEN_MIN_DIST,
			"tocas_distintas_no_boot",
			"componentes=%d maior=%d censo=%d tocas_fundadas=%d den_min_dist=%s lar_entre_componentes=%s | %s" % [
			comps.size(), maior, censo, s._dens.size(),
			"sem_par" if is_inf(centros) else "%.1f" % centros,
			"sem_par" if is_inf(lar) else "%.1f" % lar, lares.strip_edges()])
	# O furo #21 pago com numero, e a linha impressa e a cobranca: `pack_pairs` vale
	# `n(n-1)/2` sempre -- com um componente ou com tres -- entao ele nao decide
	# coesao nenhuma e continua saindo aqui como o que ele e (pares TESTADOS). O que
	# decide e `den_components`, e esta checagem exige que o numero publicado pelo
	# diagnostico seja o MESMO que o grafo lido pelo runner: se um dos dois calcula
	# componente por outro caminho, o gate perde a testemunha.
	var d: Dictionary = s.diagnostics()
	var publicado := float(d["den_min_dist"])
	var mesma_sep := false
	if is_inf(centros):
		mesma_sep = publicado < 0.0
	else:
		mesma_sep = absf(publicado - centros) < 1e-6
	var testados: int = censo * (censo - 1) / 2
	_check(int(d["den_components"]) == comps.size() and int(d["dens"]) == s._dens.size()
			and mesma_sep,
			"diagnostico_publica_a_mesma_leitura_das_tocas",
			"diagnostics dens=%d componentes=%d den_min_dist=%.3f | runner componentes=%d centros=%s | furo21 pack_pairs=%d pares_testados=%d (aritmetica sempre verdadeira, nao decide)" % [
			int(d["dens"]), int(d["den_components"]), publicado, comps.size(),
			"sem_par" if is_inf(centros) else "%.1f" % centros,
			int(d["pack_pairs"]), testados])
	_pack_release()
	return true


## Checagem 2 do dossie 16 §5, a anti-farsa do outro lado: pertenca declarada sem
## separacao lida e o mesmo defeito que a perna 10 cobrou ("cinco lares espalhados
## que nunca foram territorio"), invertido. Se um lobo do grafo le alguem de outra
## toca, o "espalhado" e nome novo para o circulo unico -- a coesao continua sendo a
## unica dona da matilha, e ela nao sabe de toca nenhuma (dossie 16 §6: a toca entra
## como LUGAR, nao como comportamento).
##
## Roda sobre o rebuild real (`pack_of`), nao sobre uma distancia recalculada no
## teste: o que se quer e exatamente o que o lobo le.
func _test_nenhum_lobo_le_de_outra_toca() -> bool:
	_arm()
	_boot_session(5)
	var s: Session = _session
	s._rebuild_packs()
	var den_de := {}
	for w: Wolf in s.wolves:
		if w.alive:
			den_de[w.identity] = w.den
	var travessias := 0
	var linhas := ""
	for id: int in den_de:
		for e: Dictionary in s.pack_of(id):
			var outro: int = int(e["identity"])
			if den_de.has(outro) and int(den_de[outro]) != int(den_de[id]):
				travessias += 1
				linhas += "lobo%d(toca %d) le lobo%d(toca %d) " % [
						id, den_de[id], outro, den_de[outro]]
	var sem_toca := 0
	for id: int in den_de:
		if int(den_de[id]) < 0:
			sem_toca += 1
	_check(travessias == 0 and sem_toca == 0, "nenhum_lobo_le_de_outra_toca",
			"arestas_entre_tocas=%d bichos_sem_toca=%d lidos=%d | %s" % [
			travessias, sem_toca, den_de.size(),
			linhas if linhas.is_empty() else linhas.strip_edges()])
	_pack_release()
	return true


## Checagem 3 do dossie 16 §5: uma toca e um LUGAR, entao o centro dela tem de ser
## um ponto onde o jogo poria um bicho -- coluna seca, volume livre, longe do
## jogador e fora da visada, os mesmos quatro portoes do spawn, lidos aqui pela
## API publica da sessao. E nenhum dois centros partilham coluna: dois centros na
## mesma coluna sao a mesma toca contada duas vezes, e a mordaca de cada uma
## apontaria para o mesmo chao.
##
## Esta checagem nao existia antes do commit (b) porque nao havia o que medir --
## `_dens` e a lista nova, e ela que carrega a promessa de que espalhar nao foi
## escrito em cima de um lugar invalido.
func _test_cada_toca_e_um_lugar_valido() -> bool:
	_arm()
	_boot_session(5)
	var s: Session = _session
	var colunas := {}
	var ruins := ""
	for i in s._dens.size():
		var c: Vector3 = s._dens[i]
		var col := Vector2i(int(c.x), int(c.z))
		if colunas.has(col):
			ruins += "toca%d divide a coluna %s com toca%d " % [i, str(col), colunas[col]]
			continue
		colunas[col] = i
		if s.world.surface_height(int(c.x), int(c.z)) <= VoxelConfig.SEA_LEVEL:
			ruins += "toca%d em coluna molhada " % i
		if not s._volume_clear(c, Wolf.DIMS):
			ruins += "toca%d sem volume livre " % i
		if not s._spawn_point_ok(c):
			ruins += "toca%d a menos de %g m ou na visada do jogador " % [
					i, Session.SAFE_SPAWN_DIST]
	_check(ruins.is_empty() and s._dens.size() >= 2, "cada_toca_e_um_lugar_valido",
			"tocas=%d colunas_distintas=%d | %s" % [
			s._dens.size(), colunas.size(),
			"todos os centros validos" if ruins.is_empty() else ruins.strip_edges()])
	_pack_release()
	return true


## Checagem 6 do dossie 16 §5, e o numero que decide o §3.4 entre os dois bracos.
## O centro de ronda e o baricentro dos vizinhos lidos, renovado a cada 4-9 s, e
## com fatias de 5-22 m ele faz passeio aleatorio sem ancora nenhuma: com uma
## matilha so isso era invisivel, com tres pode re-fundir as tocas. Exige que
## **todo** rebuild da janela leia >= 2 componentes.
##
## Nasce vermelha pelo mesmo motivo da checagem 1 -- sem tocas havia um componente
## so no passo zero -- e um vermelho dela depois do braco A pousado e o bilhete do braco
## B, nao uma falha a esconder (§3.4). A janela de 1 400 passos e a mesma do
## cenario 6 da perna 14: cadaver de 1 s + fila de 45 s cabem inteiros nela.
## O numero impresso e a distancia lar-a-lar no pior rebuild, nao `den_min_dist`: os
## centros sao fixos por construcao (§3.2.5), entao o que pode mudar aqui e a
## leitura -- e e a leitura que o braco B compra.
func _test_toca_nao_deriva_para_unica() -> bool:
	_arm()
	_boot_session(5)
	var s: Session = _session
	var pior := 0
	var pior_passo := -1
	var pior_sep := INF
	var bichos_pior := 0
	var passos := 0
	while passos < 1400:
		passos += 1
		s._sim_tick()
		for w: Wolf in _pack_wolves():
			for frame: int in 3:
				w._physics_process(SimClock.STEP / 3.0)
		var comps := _componentes_da_matilha(s)
		if passos == 1 or comps.size() < pior:
			pior = comps.size()
			pior_passo = passos
			pior_sep = _separacao_dos_componentes(s, comps)
			bichos_pior = 0
			for c: Array in comps:
				bichos_pior += c.size()
	_check(pior >= 2, "toca_nao_deriva_para_unica",
			"componentes_minimos=%d bichos_lidos=%d lar_entre_componentes=%s no passo %d de %d" % [
			pior, bichos_pior,
			"sem_par" if is_inf(pior_sep) else "%.1f" % pior_sep, pior_passo, passos])
	_pack_release()
	return true


## Checagem 4 do dossie 16 §5: a pertenca tem de sobreviver ao caminho inteiro da
## reposicao -- `die()` -> cadaver -> `_reap_corpses` -> fila de 45 s -> `_spawn_wolves`
## -> `_place_request(for_den)`. O `for_den` existe justamente para ela nao ser
## sorteada de novo, e a premissa que esta linha exige e que a vaga carregue a toca
## de quem morreu, nao "uma" toca.
##
## A segunda metade do criterio (>= `DEN_MIN_DIST` dos OUTROS centros) e a que fecha
## a regressao de hoje: um lar a 12 m do centro da toca errada passaria na primeira
## metade e seria o circulo unico com nome novo.
##
## `a_mais_vazia_diria` sai impresso e NAO e criterio, e dizer isso e o ponto da
## linha: no boot medido (2/2/1) a toca mais vazia depois da morte e a propria toca
## da vitima, entao esta checagem nao distingue "a vaga carrega" de "pede a mais
## vazia" -- quem distingue e o braco entre tocas da checagem 5. Deixar o numero
## impresso e o registro de que a checagem 4 decide o caminho da fila, nao a regra
## de desempate de §3.2.4.
func _test_reposicao_volta_para_a_toca_perdida() -> bool:
	_arm()
	_boot_session(5)
	var s: Session = _session
	var vitima: Wolf = null
	var membros := 0
	var quem := ""
	for w: Wolf in _pack_wolves():
		if w.alive and int(w.den) == 2:
			vitima = w
			membros += 1
		if w.alive:
			quem += "lobo%d(toca=%d) " % [w.identity, w.den]
	_check(vitima != null and membros == 1,
			"premissa: a toca 2 tem exatamente um membro vivo para perder",
			"membros=%d tocas=%d | %s" % [membros, s._dens.size(), quem.strip_edges()])
	if vitima == null:
		# Sem vitima nao ha o que seguir: um `null` adiante derrubaria o passo com
		# SCRIPT ERROR e as checagens do passo iriam embora em silencio (mandato 1).
		_pack_release()
		return true
	var id_novo: int = int(s._next_identity)
	var den_perdido: int = int(vitima.den)
	vitima.die()
	var mais_vazia := -99
	var passos := 0
	while passos < 1400 and int(s._next_identity) == id_novo:
		passos += 1
		if mais_vazia < 0 and s._respawn_queue.size() > 0:
			# O cadaver ja saiu de `wolves` quando a vaga nasceu (`_reap_corpses`
			# faz as duas coisas na mesma chamada), entao este e o censo que o
			# pedido vê -- o contrafactual honesto, nao um chute depois do spawn.
			mais_vazia = int(s._emptiest_den())
		s._sim_tick()
		for w: Wolf in _pack_wolves():
			for frame: int in 3:
				w._physics_process(SimClock.STEP / 3.0)
	var novo: Wolf = null
	for w: Wolf in _pack_wolves():
		if w.identity == id_novo:
			novo = w
	var propria := -1.0
	var alheia := INF
	if novo != null and int(novo.den) >= 0:
		propria = _no_chao(novo.home, s._dens[int(novo.den)])
		for i in s._dens.size():
			if i != int(novo.den):
				alheia = minf(alheia, _no_chao(novo.home, s._dens[i]))
	_check(novo != null and int(novo.den) == den_perdido
			and propria >= 0.0 and propria <= float(Session.PACK_LEASH)
			and alheia >= float(Session.DEN_MIN_DIST),
			"reposicao_volta_para_a_toca_perdida",
			"passos=%d den=%d esperado=%d do_centro_proprio=%.1f m (mordaca %.0f) do_centro_alheio=%s (portao %.0f) fila=%d a_mais_vazia_diria=%d" % [
			passos, int(novo.den) if novo != null else -99, den_perdido, propria,
			Session.PACK_LEASH, "sem_outro_centro" if is_inf(alheia) else "%.1f" % alheia,
			Session.DEN_MIN_DIST, s._respawn_queue.size(), mais_vazia])
	_pack_release()
	return true


## Checagem 5 do dossie 16 §5, os dois bracos do parto.
##
## Braco A -- casal da MESMA toca: a cria fica nela e dentro da mordaca daquele
## centro. E o braco que o codigo de antes ja faria por acaso (a ancora era o lar
## do primeiro vivo), entao sozinho ele nao prova nada; ele existe para o B nao ser
## um numero solto.
##
## Braco B -- casal de tocas DIFERENTES, e aqui esta a decisão: a ancora antiga do
## parto era o **ponto medio** dos dois lares, e o meio-termo de dois lugares a 48 m
## um do outro e um terceiro lugar que ninguem fundou. Com o medio no codigo, a cria
## nasce a ~31 m de qualquer centro: fora da mordaca de uma e dentro do portao da
## outra -- ou seja, o espalhamento da perna se desfaz pelo caminho do nascimento,
## sem que nenhuma das outras checagem veja. Trocar a ancora para o centro do adulto
## de identidade MENOR (o mesmo desempate que a ronda usa) e o que esta linha exige,
## e a premissa impressa (`_primeiro_par`) e a testemunha de que o par escolhido e o
## par que a roda realmente achou.
func _test_nascimento_fica_na_toca_dos_pais() -> bool:
	# --- braco A: mesma toca ---
	_arm()
	_boot_session(5, true)
	var sA: Session = _session
	var wsA: Array = _pack_wolves()
	var aA := -1
	var bA := -1
	for i in wsA.size():
		if aA >= 0:
			break
		for j in range(i + 1, wsA.size()):
			var x: Wolf = wsA[i]
			var y: Wolf = wsA[j]
			if x.alive and y.alive and int(x.den) >= 0 and int(x.den) == int(y.den):
				aA = i
				bA = j
				break
	if aA >= 0:
		_pack_place(aA, MATE_SPOTS[0])
		_pack_place(bA, MATE_SPOTS[1])
	var parA := _primeiro_par(sA)
	_check(aA >= 0 and parA.size() == 2 and int(parA[0]) == aA and int(parA[1]) == bA,
			"premissa (braco A): o par que a roda acha e o par da mesma toca",
			"posicionados=[%d,%d] achados=%s toca=%d raio=%.0f m" % [
			aA, bA, str(parA), int(wsA[aA].den) if aA >= 0 else -99, Session.MATE_RADIUS])
	if aA < 0 or parA.size() != 2:
		_pack_release()
		return true
	var antesA := {}
	for w: Wolf in sA.wolves:
		antesA[w.identity] = true
	_advance_pack(1)
	var criaA: Wolf = null
	for w: Wolf in sA.wolves:
		if not antesA.has(w.identity):
			criaA = w
	var denA := int((wsA[aA] as Wolf).den)
	var foraA := -1.0
	var dentroA := INF
	if criaA != null and int(criaA.den) >= 0:
		foraA = _no_chao(criaA.home, sA._dens[int(criaA.den)])
		for i in sA._dens.size():
			if i != int(criaA.den):
				dentroA = minf(dentroA, _no_chao(criaA.home, sA._dens[i]))
	_check(criaA != null and int(criaA.den) == denA
			and foraA >= 0.0 and foraA <= float(Session.PACK_LEASH),
			"nascimento_fica_na_toca_do_casal",
			"cria=%s den=%d esperado=%d do_centro=%.1f m (mordaca %.0f) do_centro_alheio=%s" % [
			str(criaA.identity) if criaA != null else "nenhuma",
			int(criaA.den) if criaA != null else -99, denA, foraA, Session.PACK_LEASH,
			"sem_outro_centro" if is_inf(dentroA) else "%.1f" % dentroA])

	# --- braco B: tocas diferentes ---
	_arm()
	_boot_session(5, true)
	var sB: Session = _session
	var wsB: Array = _pack_wolves()
	var aB := -1
	var bB := -1
	for i in wsB.size():
		if aB >= 0:
			break
		for j in range(i + 1, wsB.size()):
			var x: Wolf = wsB[i]
			var y: Wolf = wsB[j]
			if x.alive and y.alive and int(x.den) >= 0 and int(y.den) >= 0 \
					and int(x.den) != int(y.den):
				aB = i
				bB = j
				break
	if aB >= 0:
		_pack_place(aB, MATE_SPOTS[0])
		_pack_place(bB, MATE_SPOTS[1])
	var parB := _primeiro_par(sB)
	var sepB := _separacao_das_tocas(sB)
	_check(aB >= 0 and parB.size() == 2 and int(parB[0]) == aB and int(parB[1]) == bB,
			"premissa (braco B): o par que a roda acha e o par de duas tocas",
			"posicionados=[%d,%d] achados=%s tocas=%d+%d separacao=%s m" % [
			aB, bB, str(parB), int(wsB[aB].den) if aB >= 0 else -99,
			int(wsB[bB].den) if bB >= 0 else -99,
			"sem_par" if is_inf(sepB) else "%.1f" % sepB])
	if aB < 0 or parB.size() != 2:
		_pack_release()
		return true
	var antesB := {}
	for w: Wolf in sB.wolves:
		antesB[w.identity] = true
	_advance_pack(1)
	var criaB: Wolf = null
	for w: Wolf in sB.wolves:
		if not antesB.has(w.identity):
			criaB = w
	# O adulto que decide a toca e o de identidade menor -- o mesmo desempate que a
	# ronda da perna 14 ja usa para ordenar assentos, nao uma preferencia nova.
	var pai: Wolf = wsB[aB] if (wsB[aB] as Wolf).identity < (wsB[bB] as Wolf).identity \
			else wsB[bB]
	var mae: Wolf = wsB[bB] if pai == wsB[aB] else wsB[aB]
	var denB := int(pai.den)
	var propriaB := -1.0
	var alheiaB := INF
	if criaB != null and int(criaB.den) >= 0:
		propriaB = _no_chao(criaB.home, sB._dens[int(criaB.den)])
		for i in sB._dens.size():
			if i != int(criaB.den):
				alheiaB = minf(alheiaB, _no_chao(criaB.home, sB._dens[i]))
	_check(criaB != null and int(criaB.den) == denB
			and propriaB >= 0.0 and propriaB <= float(Session.PACK_LEASH)
			and alheiaB >= float(Session.DEN_MIN_DIST),
			"casal_de_tocas_diferentes_nao_cria_lar_fora_de_toca",
			"cria=%s den=%d esperado=%d do_adulto_menor(%s)=%.1f m do_adulto_maior(%s)=%.1f m | mordaca %.0f portao %.0f do_centro_proprio=%.1f do_centro_alheio=%s" % [
			str(criaB.identity) if criaB != null else "nenhuma",
			int(criaB.den) if criaB != null else -99, denB,
			str(pai.identity), _no_chao(criaB.home, pai.home) if criaB != null else -1.0,
			str(mae.identity), _no_chao(criaB.home, mae.home) if criaB != null else -1.0,
			Session.PACK_LEASH, Session.DEN_MIN_DIST, propriaB,
			"sem_outro_centro" if is_inf(alheiaB) else "%.1f" % alheiaB])
	_pack_release()
	return true


## Checagem 7 do dossie 16 §5: o espalhamento nao pode custar passo.
##
## O par pedido pela pagina e `sim_step` integral com e sem a perna, mesma cena,
## mesma semente. Ele nao pode ser montado dentro deste processo: nao existe a
## porta "sem a perna" -- `Session._dens` e a colocacao que o enche sao o codigo
## medido, e um braco que esvazia `_dens` a mao encena um estado que nenhuma
## transicao do jogo produz (a regra do ciclo 3 da casa). O par existe entao como
## duas corridas do MESMO rodape (`CENARIO ESTREITO` / `PASSOS DE MATILHA`, linhas
## que a perna nao toca) na `main` anterior e nesta ponta, e os dois numeros vao
## para o status com os dois logs.
##
## O que esta linha gates, e o que so sai impresso, sao coisas diferentes, e a
## separacao e o ponto:
## - criterio: a regua de 25 ms por passo (a mesma dos dossies 17 e 19) contra
##   `clock.worst_step_ms` lido pela API publica, e o pico dos proprios 1 400 passos
##   cronometrados aqui;
## - impresso sem ser criterio: a media por passo e o custo da colocacao. Colocar
##   toca roda no caminho raro -- spawn, fila, parto -- e e justamente onde um custo
##   se disfarca de gratis, entao o numero tem de estar na mesa mesmo sem regua
##   publicada; a janela medida e o passo de 20 Hz, e a janela nao cobra o boot.
##
## `clock.begin_step()`/`end_step()` dao a volta no `_sim_tick` exatamente como
## `main.gd:259-261`: sem isso o `worst_sim_ms` do `diagnostics()` seria o chao do
## relogio novo e a linha diria "nada acima de 25 ms" por nao ter medido nada. Os
## corpos vao pelos tres sub-passos dos irmaos de tocas (`_test_toca_nao_deriva_para_unica`),
## para a cena ser a mesma cena daquela checagem.
func _test_espalhamento_nao_estoura_o_passo() -> bool:
	_arm()
	# A colocacao vai cronometrada numa janela propria, e por um motivo que e o
	# contrario de cosmetico: `_boot_session(0)` poe o jogador e nao sorteia bicho
	# nenhum, e o `_spawn_wolves(5)` que vem em seguida e a mesma chamada, com o mesmo
	# cursor de RNG, que `_boot_session(5)` faria uma linha depois. O que muda e so
	# onde o cronometro esta, e o que ele pega e o caminho raro.
	var s0: Session = null
	_boot_session(0)
	s0 = _session
	var t_colocacao := Time.get_ticks_usec()
	s0._spawn_wolves(int(Session.WOLF_COUNT))
	var colocacao_us := Time.get_ticks_usec() - t_colocacao
	var d_boot: Dictionary = s0.diagnostics()
	var comps_boot := _componentes_da_matilha(s0)
	var sep_boot := _separacao_das_tocas(s0)
	_pack_release()
	# A janela de passo, na sessao real dos cinco bichos com as tocas fundadas.
	# Segundo `_arm()` e obrigatorio, nao limpeza: o sorteio de lar consome o RNG
	# global e `_arm` e a unica chamada que o devolve para `SEED` -- sem ele a
	# segunda matilha nasceria de um cursor ja avancado pela primeira e os dois
	# numeros impressos nao seriam a mesma cena.
	_arm()
	_boot_session(int(Session.WOLF_COUNT))
	var s: Session = _session
	var tick0 := int(s.diagnostics()["tick"])
	var total_us := 0
	var pico_us := 0
	var passos := 0
	var pior_comp := 99
	var bichos_pior := 0
	while passos < 1400:
		passos += 1
		var t0 := Time.get_ticks_usec()
		s.clock.begin_step()
		s._sim_tick()
		s.clock.end_step()
		var cost := Time.get_ticks_usec() - t0
		total_us += cost
		pico_us = maxi(pico_us, cost)
		for w: Wolf in _pack_wolves():
			for frame: int in 3:
				w._physics_process(SimClock.STEP / 3.0)
		var comps := _componentes_da_matilha(s)
		if passos == 1 or comps.size() < pior_comp:
			pior_comp = comps.size()
			bichos_pior = 0
			for c: Array in comps:
				bichos_pior += c.size()
	var d: Dictionary = s.diagnostics()
	var media_us := float(total_us) / float(maxi(passos, 1))
	_check(int(d["tick"]) - tick0 == 1400 and s._dens.size() >= 2
			and int(d_boot["dens"]) == s._dens.size() and pior_comp >= 2,
			"premissa: 1 400 passos da matilha espalhada, e a fundacao rodou pela porta do jogo",
			"passos=%d tick0=%d->%d  dens=%d componentes_min=%d bichos_lidos=%d | boot: dens=%d componentes=%d separacao=%s m matilha=%d fila=%d" % [
			passos, tick0, int(d["tick"]), s._dens.size(), pior_comp, bichos_pior,
			int(d_boot["dens"]), comps_boot.size(),
			"sem_par" if is_inf(sep_boot) else "%.1f" % sep_boot,
			int(d_boot["wolves"]), int(d_boot["pending_respawns"])])
	_check(float(d["worst_sim_ms"]) <= 25.0 and pico_us <= 25000,
			"espalhamento_nao_estoura_o_passo",
			"worst_sim_ms=%.2f ms  pico_do_passo=%d us  media=%.1f us/passo  total=%d us em %d passos  | colocacao (caminho raro, sem regua): %d us por %d lares com %d tocas fundadas" % [
			float(d["worst_sim_ms"]), pico_us, media_us, total_us, passos,
			colocacao_us, int(Session.WOLF_COUNT), s._dens.size()])
	_pack_release()
	return true


## ------------------------------------------------------------------ cavar (dossie 12)


## Palco de escavacao: a coluna de x=`x` com as `rows` solidas do `block` pedido,
## na faixa de z inteira que o runner usa (40..84). A coluna e larga de proposito:
## o entupimento da checagem 5 tem de ser um MURO, nao um pilar de cinco celulas
## que da para contornar -- se desse para contornar, "atravessou" nao diria nada
## sobre a pata.
## As duas metades do `registrada = false` nao sao cerimonia, sao a premissa do
## §1 ("um voxel que o jogador nao tocou"): a escrita sai com `record = false` E a
## chave antiga e APAGADA de `world.edits`. A plateia da fixture foi montada com
## `set_block(pos, AIR)` de `record` default (o plateau de `_test_fixture`),
## entao toda celula de ar acima do y=50 ja tem chave no registro do mundo. Sem o
## erase a parede de teste seria construcao registrada, a clausula de
## proveniencia recusaria o lote inteiro e `lobo_cava_sem_input_do_jogador`
## ficaria verde por nao haver o que cavar.
func _dig_stage(x: int, rows: Array, block: int, registrada: bool = false) -> void:
	for z: int in range(40, 85):
		for y: int in range(51, 58):
			var p := Vector3i(x, y, z)
			var b: int = block if y in rows else BlockDefs.Block.AIR
			if registrada:
				# Normaliza em ar sem registro e so depois escreve o alvo registrado:
				# `set_block` recusa no-op (`voxel_world.gd:270-271`), entao uma celula
				# que ja tinha o bloco pedido nao deixaria chave nenhuma e o braco
				# "registrado" contaria chaves por acaso do braco anterior.
				_world.edits.erase(p)
				_world.set_block(p, BlockDefs.Block.AIR, false)
				_world.set_block(p, b, true)
			else:
				_world.edits.erase(p)
				_world.set_block(p, b, false)


## As duas metades do §3.3, cada uma na sua conta, e a separacao e o que faz a
## terceira checagem poder falhar. `_opened_cells` e o estado de mundo: ar no y do
## corpo, com ou sem chave. `_dug_cells` e o registro: ar COM chave AIR em
## `world.edits`. Se as duas vivessem num predicado so, um `record = false` na
## pata derrubaria as duas contas juntas e a clausula "o mundo registra o buraco"
## ficaria verde sem medir nada -- aqui ela so passa se cada celula NOVA aberta
## carrega a chave. O erase de `_dig_stage` ainda por cima devolve a coluna ao
## estado virgem no fim do lote, entao as duas leituras tem de acontecer antes da
## limpeza.
func _opened_cells(x: int) -> Array:
	var out: Array = []
	for z: int in range(40, 85):
		var p := Vector3i(x, 51, z)
		if _world.get_block(p) == BlockDefs.Block.AIR:
			out.append(p)
	return out


func _dug_cells(x: int) -> Array:
	var out: Array = []
	for z: int in range(40, 85):
		var p := Vector3i(x, 51, z)
		if _world.get_block(p) == BlockDefs.Block.AIR and _world.edits.has(p):
			out.append(p)
	return out


## A janela do corredor (checagem 5 do dossie 12 §5): os dois numeros que o §3.2 (a)
## pede antes de `DIG_STEPS_BEFORE` valer alguma coisa -- em quantos passos um
## entupimento de neve trava um lobo SEM cavar e em quantos o mesmo lobo atravessa
## COM. Os bracos sem pata nao pedem toggle nem codigo de teste: neve REGISTRADA
## (`_dig_ok` recusa por proveniencia) e pedra FORA da lista prendem pelo mesmo
## motivo observavel -- o corpo encosta e nao passa. E por isso que a travessia do
## braco cavavel nao pode ser lida como "so esperou o tempo do desvio": o desvio
## natural nao tira ninguem de um muro de dois blocos, e o que o numero compara e o
## tempo que a pata custa contra o tempo que o muro custa.
## `degraus` conta os quadros em que o bloqueio tinha subida possivel (o ramo da
## perna 19) e `maior_run` o mais longo comprometimento consecutivo de uma unica
## celula: se o `_detour` do desemperto zerasse a obra a cada vaivem, e aqui que
## isso aparece -- o acumulo nunca chegaria ao fim e o braco novo morreria inerte.
func _dig_corridor(block: int, rows: Array, registrada: bool,
		ticks_limit: int = 200) -> Dictionary:
	_arm(Vector3(54.0, 51.001, 54.0), FAR_PLAYER)
	_dig_stage(56, rows, block, registrada)
	var abertas_0 := _opened_cells(56).size()
	_field.imprint(Vector3(66.0, 50.6, 54.0), AetherField.Channel.WORK, 0.9)
	_advance(1, false)
	var ticks := 0
	var horizontais := 0
	var degraus := 0
	var encostou := false
	var boca_tick := -1
	var cruze_tick := -1
	var encostada_tick := -1
	var x_max := _wolf.body.feet_pos.x
	var passos_visto := 0
	var comprometido := _wolf._dig_pos != Wolf.DIG_NONE
	var run := 0
	var maior_run := 0
	var runs := 0
	for i: int in ticks_limit:
		ticks += 1
		_advance(1, false)
		for f: int in 3:
			_wolf._physics_process(SimClock.STEP / 3.0)
			x_max = maxf(x_max, _wolf.body.feet_pos.x)
			if _wolf.body.blocked_horizontal:
				horizontais += 1
				if _wolf.body.feet_pos.y < 51.5 and \
						_wolf.body.feet_pos.x + Wolf.DIMS.x * 0.5 > 55.9:
					if encostada_tick < 0:
						encostada_tick = ticks
					encostou = true
				var want := _wolf._move_target - _wolf.body.feet_pos
				want.y = 0.0
				if _wolf.body.can_step_over(want):
					degraus += 1
			if cruze_tick < 0 and _wolf.body.feet_pos.x > 57.4:
				cruze_tick = ticks
		passos_visto = maxi(passos_visto, _wolf._dig_steps)
		var agora := _wolf._dig_pos != Wolf.DIG_NONE
		if agora:
			if not comprometido:
				runs += 1
				run = 0
			run += 1
			maior_run = maxi(maior_run, run)
		comprometido = agora
		if boca_tick < 0 and _opened_cells(56).size() > abertas_0:
			boca_tick = ticks
		if cruze_tick > 0:
			break
	var out := {
		"ticks": ticks, "horizontais": horizontais, "degraus": degraus,
		"encostou": encostou, "encostada_tick": encostada_tick,
		"boca_tick": boca_tick, "cruze_tick": cruze_tick, "x_max": x_max,
		"bocas": _opened_cells(56).size() - abertas_0,
		"passos_visto": passos_visto, "maior_run": maior_run, "runs": runs,
		"feet": _wolf.body.feet_pos, "alvo": _wolf._move_target,
		"dig_pos": _wolf._dig_pos,
	}
	_dig_stage(56, [], BlockDefs.Block.AIR)
	return out


## A janela de empurrao, uma so vez para as tres checagens. Nada aqui escreve
## `_move_target`, `intent` ou `_dig_pos` na mao: o rastro de WORK atras da coluna
## e o que da a intencao pela arvore real, e o integrador e que encosta o corpo na
## face -- o mesmo palco com que a perna 19 mediu o auto-pulo. `extras` poe
## construcao registrada dentro da faixa (o braco da bancada) depois do palco.
func _dig_window(block: int, rows: Array, ticks_limit: int, boca_alvo: int,
		registrada: bool = false, extras: Dictionary = {},
		pin_rng: bool = false) -> Dictionary:
	_arm(Vector3(54.0, 51.001, 54.0), FAR_PLAYER)
	_dig_stage(56, rows, block, registrada)
	for p: Vector3i in extras:
		_world.set_block(p, int(extras[p]), true)
	var edits_na_coluna := 0
	for z: int in range(40, 85):
		if _world.edits.has(Vector3i(56, 51, z)):
			edits_na_coluna += 1
	var abertas_0: Array = _opened_cells(56)
	var chaves_0: int = _dug_cells(56).size()
	_field.imprint(Vector3(66.0, 50.6, 54.0), AetherField.Channel.WORK, 0.9)
	_advance(1, false)
	# O pino do molde (`simulation_rng_test.gd:75-77`): `seed` e o primeiro `randi`
	# devolvem o valor que o PROXIMO consumo daria; o segundo `seed` re-poe o estado
	# e a janela roda com a fita no mesmo lugar. Se os N passos nao tocarem na RNG
	# global, o `randi()` do fim devolve exatamente esse numero.
	var rng_next := 0
	if pin_rng:
		seed(RNG_PIN)
		rng_next = randi()
		seed(RNG_PIN)
	var ticks := 0
	var horizontais := 0
	var encostou := false
	var boca_tick := -1
	var x_max := _wolf.body.feet_pos.x
	var rearms := 0
	var armadas := 0
	var armadas_com_rearm := 0
	var detour_min := INF
	var detour_max := -INF
	for i: int in ticks_limit:
		ticks += 1
		_advance(1, false)
		for f: int in 3:
			var unstick_0 := _wolf._unstick
			var pos_0: Vector3i = _wolf._dig_pos
			_wolf._physics_process(SimClock.STEP / 3.0)
			x_max = maxf(x_max, _wolf.body.feet_pos.x)
			if _wolf.body.blocked_horizontal:
				horizontais += 1
				if _wolf.body.feet_pos.y < 51.5 and \
						_wolf.body.feet_pos.x + Wolf.DIMS.x * 0.5 > 55.9:
					encostou = true
			# `_unstick` so tem duas escritas no arquivo inteiro: o `-= delta` do
			# passo andante e o `_rng.randf_range(0.35, 0.8)` do desemperto. Diminuir
			# e o normal, entao SUBIR so pode ser o sorteio -- e o detector nao
			# precisa de nenhum contador dentro do lobo, que e o que a casa pede de
			# um instrumento.
			var rearmou := _wolf._unstick > unstick_0 + 1e-9
			if rearmou:
				rearms += 1
				detour_min = minf(detour_min, _wolf._detour)
				detour_max = maxf(detour_max, _wolf._detour)
			if pos_0 == Wolf.DIG_NONE and _wolf._dig_pos != Wolf.DIG_NONE:
				armadas += 1
				if rearmou:
					armadas_com_rearm += 1
		var n := _opened_cells(56).size() - abertas_0.size()
		if boca_tick < 0 and n > 0:
			boca_tick = ticks
		if n >= boca_alvo:
			break
	var rng_depois := 0
	var rng_preservado := true
	if pin_rng:
		# Le DEPOIS da janela e so quando o pino foi pedido: `randi()` consome a
		# fita, e os outros bracos que chamam esta funcao nao tem de mover o estado
		# da RNG global por existir um instrumento apontando para ela.
		rng_depois = randi()
		rng_preservado = rng_depois == rng_next
	var novas: Array = []
	for p: Vector3i in _opened_cells(56):
		if not abertas_0.has(p):
			novas.append(p)
	var com_chave := 0
	for p: Vector3i in novas:
		if int(_world.edits.get(p, -1)) == int(BlockDefs.Block.AIR):
			com_chave += 1
	var inteiros := 0
	for z: int in range(40, 85):
		for y: int in rows:
			if _world.get_block(Vector3i(56, y, z)) == block:
				inteiros += 1
	# Lido ANTES da limpeza do palco: o que a checagem da bancada precisa e do
	# estado que o lote deixou, e `_dig_stage(56, [], AIR)` devolve a coluna ao ar.
	var extras_lidos := {}
	for p: Vector3i in extras:
		extras_lidos[p] = {
			"bloco": _world.get_block(p),
			"registrada": _world.edits.has(p),
			"valor": int(_world.edits.get(p, -1)),
		}
	# O WORK lido na celula de Eter de cada boca nova, antes da limpeza do palco.
	# `cell_of_world` com o mesmo offset do imprint (voxel + 0,5) e o que garante
	# que a leitura cai na celula em que a escrita caiu: pedir pelo voxel inteiro
	# arredondaria para outra celula nos voxels de borda e a checagem acusaria
	# ausencia onde o instrumento e que esta torto.
	var work_em := {}
	var work_acesos := 0
	for p: Vector3i in novas:
		var v: float = _field.sample_cell(
				_field.cell_of_world(Vector3(p) + Vector3(0.5, 0.5, 0.5)),
				AetherField.Channel.WORK)
		work_em[p] = v
		if v > 0.0:
			work_acesos += 1
	var out := {
		"ticks": ticks, "horizontais": horizontais, "encostou": encostou,
		"boca_tick": boca_tick, "novas": novas, "bocas_n": novas.size(),
		"chaves_n": _dug_cells(56).size() - chaves_0, "com_chave": com_chave,
		"edits_na_coluna": edits_na_coluna, "x_max": x_max, "inteiros": inteiros,
		"celulas": int(rows.size()) * 45, "feet": _wolf.body.feet_pos,
		"alvo": _wolf._move_target, "dig_pos": _wolf._dig_pos,
		"dig_steps": _wolf._dig_steps, "extras": extras_lidos,
		"work_em": work_em, "work_acesos": work_acesos,
		"rearms": rearms, "armadas": armadas, "armadas_com_rearm": armadas_com_rearm,
		"detour_min": detour_min, "detour_max": detour_max,
		"rng_preservado": rng_preservado, "rng_next": rng_next, "rng_depois": rng_depois,
	}
	_dig_stage(56, [], BlockDefs.Block.AIR)
	return out


## Checagem 1 do dossie 12 §5, a premissa do §1 virada em numero. Sao quatro
## clausulas e cada uma paga a sua linha: o voxel nao tinha chave em `world.edits`
## antes do lote (ninguem tocou, e nenhum botao do jogador esta apertado), a pata
## o devolve em ar depois de uma janela andando, a escrita e registrada, e o WORK
## acendeu na celula de Eter. A terceira e a que impede o cavar silencioso: sem a
## chave o buraco nao entra no save e o jogador reloga num talude que ninguem
## abriu -- e por isso que ela conta as bocas NOVAS do lote contra `world.edits`,
## uma a uma, e nao o estado final da coluna, que o `_dig_stage` do proprio palco
## devolve ao ar no fim da janela.
func _test_lobo_cava_sem_input_do_jogador() -> bool:
	var w := _dig_window(BlockDefs.Block.DIRT, [51, 52], 200, 2)
	_check(not Input.is_action_pressed("break_block")
			and not Input.is_action_pressed("place_block") and not _player.panel_open
			and int(w["edits_na_coluna"]) == 0 and int(w["horizontais"]) > 0
			and bool(w["encostou"]),
			"premissa: nenhum input do jogador, coluna sem chave no registro, corpo encostado na face",
			"break=%s place=%s painel=%s edits_na_coluna=%d horizontais=%d encostou=%s feet=%s alvo=%s" % [
			Input.is_action_pressed("break_block"), Input.is_action_pressed("place_block"),
			_player.panel_open, int(w["edits_na_coluna"]), int(w["horizontais"]),
			w["encostou"], w["feet"], w["alvo"]])
	_check(int(w["bocas_n"]) >= 1 and int(w["boca_tick"]) > 0,
			"a pata remove o voxel, atraida pelo rastro e sem um clique na mesa",
			"bocas=%d primeira_no_tick=%d janela=%d/%d horizontais=%d face_max=%.3f feet=%s" % [
			int(w["bocas_n"]), int(w["boca_tick"]), int(w["ticks"]), 200,
			int(w["horizontais"]), float(w["x_max"]) + Wolf.DIMS.x * 0.5, w["feet"]])
	_check(int(w["com_chave"]) == int(w["bocas_n"]) and int(w["bocas_n"]) >= 1,
			"o mundo registra o buraco: cada boca nova e uma chave AIR em `world.edits`",
			"chaves_air=%d bocas=%d chaves_coluna=%d celulas=%s" % [
			int(w["com_chave"]), int(w["bocas_n"]), int(w["chaves_n"]), str(w["novas"])])
	# A quarta clausula do §5.1: `o WORK apareceu na celula de Eter`. Ela conta
	# bocas com WORK > 0 e nao o valor, porque as duas celulas de z da faixa do
	# corpo (-0.5 ate +0.5 de `DIMS.z = 1,35`) caem na MESMA celula de Eter de 4
	# blocos e o `imprint` e aditivo: o valor de duas bocas e o dobro e nao e o
	# que esta em jogo aqui. O peso do imprint, esse, e a checagem 3 que decide.
	_check(int(w["work_acesos"]) == int(w["bocas_n"]) and int(w["bocas_n"]) >= 1,
			"o WORK apareceu na celula de Eter: cada boca nova acende a sua",
			"work_acesos=%d bocas=%d celulas=%s valores=%s" % [
			int(w["work_acesos"]), int(w["bocas_n"]), str(w["novas"]), str(w["work_em"])])
	return true


## Checagem 2 do dossie 12 §5: a porta e a LISTA DE MATERIAL, e nao a dureza -- a
## afirmacao que a leitura da pauta de hoje devolveu diferente do prompt original
## (dossie 12 §2, item 1). `BlockDefs.hardness` e tempo de lavra do jogador, nao
## permissao (`player.gd:663-664` soma `delta` contra `target_hardness` sem teto
## de bloco, `:685` escreve AIR em qualquer alvo), entao o braco do vidro e o que
## da dente: dureza 0,10 s, a mais baja da tabela, e ainda assim a pata nao passa.
## O braco do STONE (0,95) e o outro lado da mesma moeda, e a premissa abaixo
## exige que as recusas encostaram na face e esgotaram a janela -- sem ela
## "nao cavou" poderia significar "nao chegou".
func _test_cavar_respeita_a_lista() -> bool:
	# [rotulo, bloco, esperado cavar]
	var arms: Array = [
		["neve", BlockDefs.Block.SNOW, true],
		["areia", BlockDefs.Block.SAND, true],
		["terra", BlockDefs.Block.DIRT, true],
		["grama", BlockDefs.Block.GRASS, true],
		["pedra", BlockDefs.Block.STONE, false],
		["vidro", BlockDefs.Block.GLASS, false],
	]
	var resultados: Array = []
	for arm: Array in arms:
		var w := _dig_window(int(arm[1]), [51, 52], 200, 1)
		resultados.append([String(arm[0]), int(arm[1]), bool(arm[2]),
				int(w["bocas_n"]) >= 1, w])
	var recusas_encostadas := true
	var min_horizontais := 0
	var min_ticks := 0
	var recusas := 0
	for r: Array in resultados:
		if bool(r[2]):
			continue
		recusas += 1
		var w: Dictionary = r[4]
		if int(w["horizontais"]) == 0 or not bool(w["encostou"]):
			recusas_encostadas = false
		min_horizontais = int(w["horizontais"]) if recusas == 1 \
				else mini(min_horizontais, int(w["horizontais"]))
		min_ticks = int(w["ticks"]) if recusas == 1 else mini(min_ticks, int(w["ticks"]))
	_check(recusas_encostadas and min_ticks >= 200,
			"premissa: toda recusa encosta na face e esgota os 200 passos, nao desiste antes do muro",
			"recusas=%d encostadas=%s horizontais_min=%d ticks_min=%d" % [
			recusas, recusas_encostadas, min_horizontais, min_ticks])
	for r: Array in resultados:
		var w: Dictionary = r[4]
		_check(bool(r[2]) == bool(r[3]),
				"%s (dureza %.2f s): %s" % [r[0], BlockDefs.hardness(int(r[1])),
				"cavada" if bool(r[2]) else "recusada"],
				"bocas=%d inteiros=%d/%d primeira_no_tick=%d ticks=%d alvo=%s dig_pos=%s passos=%d" % [
				int(w["bocas_n"]), int(w["inteiros"]), int(w["celulas"]),
				int(w["boca_tick"]), int(w["ticks"]), w["alvo"], w["dig_pos"],
				int(w["dig_steps"])])
	return true


## Checagem 7 do dossie 12 §5, e o pagamento do furo #22 com o numero que a
## propria pauta pede. Os dois primeiros bracos sao os unicos que isolam a
## clausula: MESMO bloco, MESMA coluna, MESMA janela -- o que muda e so a presenca
## da chave em `world.edits`. Sem o braco B um `_dig_ok` escrito so pela lista de
## material passaria nas duas checagens acima e a clausula de proveniencia seria
## Adorno de comentario. O braco C e o caso concreto do furo: uma bancada
## registrada dentro da faixa de escavacao. Ela nao esta na lista, entao a recusa
## dela sozinha nao provara nada -- o que se exige aqui e que a pata abra a terra
## AO LADO sem tocar na construcao, e que a chave da bancada continue valendo o
## bloco que o jogador poe.
func _test_cavar_nao_toca_construcao_alheia() -> bool:
	var a := _dig_window(BlockDefs.Block.DIRT, [51, 52], 200, 1)
	var b := _dig_window(BlockDefs.Block.DIRT, [51, 52], 200, 1, true)
	var bancada := Vector3i(56, 51, 54)
	var c := _dig_window(BlockDefs.Block.DIRT, [51, 52], 200, 1, false,
			{bancada: BlockDefs.Block.BENCH})
	_check(int(a["edits_na_coluna"]) == 0 and int(b["edits_na_coluna"]) > 0
			and int(a["celulas"]) == int(b["celulas"]),
			"premissa: os dois bracos mudam SO a proveniencia, mesmo DIRT e mesma coluna",
			"edits_gerada=%d edits_registrada=%d celulas=%d/%d" % [
			int(a["edits_na_coluna"]), int(b["edits_na_coluna"]),
			int(a["celulas"]), int(b["celulas"])])
	_check(int(a["bocas_n"]) >= 1,
			"terra gerada (sem chave no registro) e cavada",
			"bocas=%d primeira_no_tick=%d alvo=%s" % [
			int(a["bocas_n"]), int(a["boca_tick"]), a["alvo"]])
	_check(int(b["bocas_n"]) == 0 and int(b["inteiros"]) == int(b["celulas"]),
			"terra escrita como construcao nao e tocada pela pata",
			"bocas=%d inteiros=%d/%d ticks=%d horizontais=%d encostou=%s" % [
			int(b["bocas_n"]), int(b["inteiros"]), int(b["celulas"]),
			int(b["ticks"]), int(b["horizontais"]), b["encostou"]])
	var leito: Dictionary = c["extras"][bancada]
	_check(int(leito["bloco"]) == int(BlockDefs.Block.BENCH)
			and bool(leito["registrada"]) and int(leito["valor"]) == int(BlockDefs.Block.BENCH)
			and int(c["bocas_n"]) >= 1 and not c["novas"].has(bancada),
			"construcao alheia na faixa fica de pe e a obra sai na terra do lado",
			"bancada=%s chave=%s valor=%d bocas=%d bocas_tem_bancada=%s dig_pos_final=%s" % [
			BlockDefs.display_name(int(leito["bloco"])), leito["registrada"],
			int(leito["valor"]), int(c["bocas_n"]), c["novas"].has(bancada), c["dig_pos"]])
	return true


## Checagem 5 do dossie 12 §5, a que decide o `DIG_STEPS_BEFORE` por numero em vez
## de deixa-lo como o `[TARGET]` provisorio com que a pauta chegou. Tres bracos sobre
## o MESMO muro de dois blocos de neve -- gerado (cavavel), registrado (recusa por
## proveniencia) e pedra (recusa por material) -- mais um sobre um muro de um bloco,
## e a comparacao que o §3.2 (a) exige e entre os tres primeiros: os 200 passos que o
## entupimento prende um lobo sem pata contra os passos que o mesmo lobo leva a
## atravessar com ela. Se a diferenca nao existir, cavar vira ruido e o ramo morre --
## e por isso que os bracos "sem pata" usam recusas que ja existem no codigo, sem
## nenhum toggle de teste: o que muda entre A, B e C e so a resposta de `_dig_ok`.
## O braco de um bloco e a escada do §3.2 na ordem escrita -- desvia, SOBE, cava. Ali
## o pulo serve, entao a pata nao deve armar nada, e `runs == 0` e o numero que diz que
## a precedencia e do degrau e nao uma coincidencia de janela.
func _test_abrir_passagem_depois_de_bloqueio() -> bool:
	var a := _dig_corridor(BlockDefs.Block.SNOW, [51, 52], false)
	var b := _dig_corridor(BlockDefs.Block.SNOW, [51, 52], true)
	var c := _dig_corridor(BlockDefs.Block.STONE, [51, 52], false)
	var d := _dig_corridor(BlockDefs.Block.SNOW, [51], false)
	_check(bool(a["encostou"]) and bool(b["encostou"]) and int(a["degraus"]) == 0
			and int(b["degraus"]) == 0 and int(a["horizontais"]) > 0,
			"premissa: nos dois bracos o corpo encosta no mesmo muro de dois blocos e o pulo nao serve em nenhum quadro",
			"encostada_a_no_tick=%d encostada_b_no_tick=%d horizontais=%d/%d degraus=%d/%d alvo=%s" % [
			int(a["encostada_tick"]), int(b["encostada_tick"]),
			int(a["horizontais"]), int(b["horizontais"]), int(a["degraus"]),
			int(b["degraus"]), a["alvo"]])
	_check(int(b["ticks"]) >= 200 and int(b["bocas"]) == 0 and float(b["x_max"]) < 56.0
			and int(b["runs"]) == 0,
			"SEM a pata o corredor de neve prende os 200 passos: o desvio natural nao da saida",
			"trava_sem_cavar=%d passos  bocas=%d face_max=%.3f runs=%d feet=%s" % [
			int(b["ticks"]), int(b["bocas"]), float(b["x_max"]), int(b["runs"]),
			b["feet"]])
	_check(int(a["cruze_tick"]) > 0 and int(a["bocas"]) >= 2,
			"COM a pata o mesmo lobo atravessa: travessia em %d passos contra os %d que o mesmo muro prende" % [
			int(a["cruze_tick"]), int(b["ticks"])],
			"cruza_no_tick=%d boca_no_tick=%d bocas=%d face_max=%.3f feet=%s" % [
			int(a["cruze_tick"]), int(a["boca_tick"]), int(a["bocas"]),
			float(a["x_max"]), a["feet"]])
	var obra := Wolf.DIG_STEPS_BEFORE \
			+ ceili(BlockDefs.hardness(BlockDefs.Block.SNOW) / SimClock.STEP)
	# `_dig_steps` zera no proprio passo que escreve o AIR, entao o pico observavel do
	# contador e `obra - 1`, e o `maior_run` conta comprometimentos, que podem emendar a
	# celula seguinte nos frames do mesmo passo. A assercao pede o pico do contador: o
	# que tem de poder falhar aqui e o vaivem do desvio trocar de celula e zerar a obra
	# antes de a dureza fechar -- ai nenhum dos dois chegaria a 12.
	_check(int(a["maior_run"]) >= obra - 1 and int(a["runs"]) >= 1,
			"o acumulador completa dentro de UM comprometimento: o desvio nao zera a obra",
			"DIG_STEPS_BEFORE=%d  obra_pedida=%d passos  maior_run=%d  runs=%d  passos_visto=%d  do empurrao a boca: %d passos" % [
			Wolf.DIG_STEPS_BEFORE, obra, int(a["maior_run"]), int(a["runs"]),
			int(a["passos_visto"]), int(a["boca_tick"]) - int(a["encostada_tick"])])
	_check(int(d["degraus"]) > 0 and int(d["bocas"]) == 0 and int(d["runs"]) == 0
			and int(d["cruze_tick"]) > 0,
			"degrau de um bloco: o pulo serve e a pata nao entra -- a escada e desvia, sobe, cava",
			"degraus=%d bocas=%d runs=%d cruza_no_tick=%d face_max=%.3f feet=%s" % [
			int(d["degraus"]), int(d["bocas"]), int(d["runs"]), int(d["cruze_tick"]),
			float(d["x_max"]), d["feet"]])
	_check(int(c["bocas"]) == 0 and int(c["degraus"]) == 0
			and int(c["ticks"]) >= 200 and int(c["runs"]) == 0,
			"controle: pedra fora da lista prende pelo MESMO numero que a neve registrada, entao a travessia do braco A e da pata e nao do tempo",
			"pedra=%d passos  neve_registrada=%d passos  travessia=%d  bocas=%d runs=%d face_max=%.3f" % [
			int(c["ticks"]), int(b["ticks"]), int(a["cruze_tick"]),
			int(c["bocas"]), int(c["runs"]), float(c["x_max"])])
	return true


## Nariz montado sobre o campo ja aceso: um lobo so para ler rastro. O corpo nao
## anda e nada e escrito na mao: `_find_scent` roda no `sim_step`, entao o que se
## colhe aqui e a leitura do caminho real, com o MESMO `identity` nos dois bracos
## para que a personalidade sorteada por `Mind` nao vire uma variavel a mais no
## par.
func _lobo_nariz(feet: Vector3, pid: int) -> Wolf:
	var w := Wolf.new()
	_stage.add_child(w)
	w.setup(_world, _field, _player, feet, pid, _clock)
	return w


## Tantos `sim_step` quantos bastam para o nariz cair na cadencia (`SCENT_PERIOD`
## = 0,25 s = 5 passos) e a arvore devolver um `intent`, sem nenhum frame de
## locomocao -- o mesmo isolamento que `_advance(ticks, false)` faz com o corpo de
## quem cava. O `_clock.tick` avanca junto porque o `elapsed` do passo vem dele.
func _nariz_lee(w: Wolf, ticks: int) -> Dictionary:
	for i: int in ticks:
		w.sim_step(float(_clock.tick + 1) * SimClock.STEP, SimClock.STEP)
		_clock.tick += 1
	return {
		"canal": w._scent_channel, "forca": w._scent_strength,
		"celula": w._scent_cell, "achou": w._scent_found,
		"pos": w._scent_pos, "intent": w.intent,
		"reaction": w.get("_reaction"), "tick": _clock.tick,
	}


## Checagem 3 do dossie 12 §5.3, a que o §3.3.(i) da perna 10 aponta como a que
## DECIDE o desenho. Os dois bracos poem WORK na mesma celula de Eter com a mesma
## assinatura (0,42 x vies de bioma) e diferem so na fonte: no L escreve a pata
## (`_dig_step` -> `_imprint`), no P escreve o echo da lavra do jogador
## (`main._on_acted("break")`, o handler que o `acted.emit` de player.gd:690 acorda
## no boot). No meio de cada braco, um nariz montado sobre o campo ja aceso le pelo
## caminho real. O numero que decide e a igualdade: se os dois dao o mesmo canal, a
## mesma celula e a mesma forca, nada no mundo distingue um WORK do outro e a frase
## "WORK e pegada do jogador" deixa de ser verdade -- o §2 desta pauta, o README e o
## status passam a dizer "pegada de quem trabalha no bloco" (fechado no commit (h)).
## Se alguem separar por canal novo ou por valor proprio, a igualdade quebra e esta
## linha fica vermelha com os dois numeros na mesa.
##
## O braco L pede UMA boca (`boca_alvo = 1`) porque o `imprint` e aditivo e as duas
## celulas de z da faixa do corpo caem na mesma celula de Eter: duas bocas dariam
## 2 x 0,42 e a diferenca seria de contagem, nao de origem. O `y` do `_scent_pos`
## entra na comparacao porque o `_dig_stage` do fim da janela devolve a coluna ao ar
## nao registrado, entao os dois bracos terminam com o mesmo estado de mundo; o `y`
## que a propria cova expoe dentro da camada e o assunto da checagem 6 (commit (e)).
## A terceira linha e a consequencia comportamental do que as duas primeiras
## medem: quem chega farejando decide `investigate` contra o rastro do que cava do
## mesmo jeito que decide contra o rastro do jogador, e e ai que o lobo que chegou
## pode cavar de novo (a auto-alimentacao que o §3.5 registra como aberta). A
## alavanca se a resposta for "loop" e a cadencia de cavar do §3.2, nao um canal
## novo -- `Channel.COUNT` e decisao de versao (§6).
func _test_work_de_bicho_nao_confundido() -> bool:
	var l := _dig_window(BlockDefs.Block.SNOW, [51, 52], 200, 1)
	var novas_l: Array = l["novas"]
	var c: Vector3i = novas_l[0] if novas_l.size() > 0 else Vector3i(56, 51, 54)
	var work_l: float = float(l["work_em"].get(c, 0.0))
	var h := _world.gen.surface_height(c.x, c.z)
	var vies: float = _world.gen.imprint_bias(
			c.x, c.z, h, AetherField.Channel.WORK)
	var esperado := Wolf.DIG_WORK * vies
	var nariz_l := _lobo_nariz(NARIZ_FEET, 7)
	var read_l := _nariz_lee(nariz_l, 6)
	nariz_l.free()
	# Braco P: campo limpo (`_arm` refaz o `AetherField`) e como unica fonte de WORK
	# a celula da boca do braco L, escrita pelo handler real do echo do jogador.
	_arm(Vector3(54.0, 51.001, 54.0), FAR_PLAYER)
	var s = Session.new()
	s.world = _world
	s.aether = _field
	s._on_acted("break", Vector3(c) + Vector3(0.5, 0.5, 0.5))
	s.free()
	var eterea := _field.cell_of_world(Vector3(c) + Vector3(0.5, 0.5, 0.5))
	var work_p := _field.sample_cell(eterea, AetherField.Channel.WORK)
	var nariz_p := _lobo_nariz(NARIZ_FEET, 7)
	var read_p := _nariz_lee(nariz_p, 6)
	var mesma_forca := absf(float(read_l["forca"]) - float(read_p["forca"])) < 1e-6
	var mesma_celula := bool(read_l["celula"] == read_p["celula"]) \
			and bool(read_l["pos"] == read_p["pos"])
	_check(int(l["bocas_n"]) == 1 and absf(work_l - esperado) < 1e-6
			and absf(work_p - esperado) < 1e-6,
			"as duas origens deixam o MESMO WORK na MESMA celula: 0,42 x vies, sem canal novo nem valor proprio",
			"voxel=%s celula_eterea=%s pata=%.6f jogador=%.6f esperado=%.6f (0,42 x vies %.4f, bioma=%s)" % [
			str(c), str(eterea), work_l, work_p, esperado, vies,
			WorldGen.BIOME_NAMES[_world.gen.biome_at(c.x, c.z)]])
	_check(bool(read_l["achou"]) and bool(read_p["achou"])
			and int(read_l["canal"]) == int(read_p["canal"])
			and int(read_l["canal"]) == int(AetherField.Channel.WORK)
			and mesma_celula and mesma_forca,
			"o nariz nao distingue a origem: mesmo canal, mesma celula, mesma forca",
			"pata canal=%s forca=%.6f celula=%s pos=%s | jogador canal=%s forca=%.6f celula=%s pos=%s" % [
			AetherField.CHANNEL_NAMES[int(read_l["canal"])], float(read_l["forca"]),
			read_l["celula"], read_l["pos"],
			AetherField.CHANNEL_NAMES[int(read_p["canal"])], float(read_p["forca"]),
			read_p["celula"], read_p["pos"]])
	_check(String(read_l["intent"]) == String(read_p["intent"]),
			"a decisao do passo seguinte e a mesma nos dois bracos",
			"intent pata=%s jogador=%s | reacao pata=%s jogador=%s | passos lidos=6/6 | tick absoluto pata=%d jogador=%d | o cavador continua=%s" % [
			read_l["intent"], read_p["intent"], read_l["reaction"], read_p["reaction"],
			int(read_l["tick"]), int(read_p["tick"]), _motion()])
	nariz_p.free()
	return true


## O palco do ramo (b): um UNICO voxel tapando a coluna que o nariz desce. As duas
## metades da proveniencia de `_dig_stage` valem aqui pelo mesmo motivo -- escrita
## com `record = false` E chave antiga apagada -- porque a plateia do fixture e
## montada com `set_block(pos, AIR)` de `record` default: sem o erase o plug seria
## construcao registrada, `_dig_ok` recusaria e a checagem verdeiria por nao haver o
## que cavar. O voxel e (58,51,54) porque `cell_center((14,12,13))` devolve
## (58,·,54) e `_scent_column_solid` desce a coluna do CENTRO da celula -- o §3.2 (b)
## diz que o alvo e "a celula do solido, lida pela MESMA coluna", entao o palco tem
## de mentir exatamente nessa coluna, nao numa vizinha.
func _dig_plug(p: Vector3i, block: int) -> void:
	_world.edits.erase(p)
	_world.set_block(p, block, false)


## A janela do faro que vira obra (checagem 6 do dossie 12 §5.6). Medido, a cena nao
## e o "lobo parado farejando o proprio buraco" que o §3.2 sugere: no tick 40 a
## inspecao termina e o nariz entrega o bloco, mas no seguinte o cache do
## `_remember_scent` aposenta a celula (`SCENT_RENEWAL` so vira a contar quando a
## obra imprime WORK), a utilidade volta para `patrol` e o corpo anda contra a
## propria tapa -- `intentos_obra={"patrol": 13}`, 13 passos com `want` vivo, 13
## quadros de `blocked_horizontal`. Entao esta cena NAO pode atribuir a boca ao
## nariz por "a pata nao encostou": aqui os dois ramos querem o mesmo buraco, que e
## justamente o caso que o comentario de `_dig_step` nomeia. O que decide que o
## compromisso nasceu do nariz sao tres numeros: `empurrao antes=0` com
## `obra_tick == exam_tick` (a pata arma no frame em que encosta, entao se o
## primeiro `_dig_pos` vivo surge no tick da entrega nada se comprometeu antes),
## `alvo_trocado == 0` e `passos_de_obra == 13` (nenhum dos 13 passos re-escolheu a
## celula, logo o acumulo do nariz correu inteiro). As duas leituras que decidem a
## boca -- o bloco que la estava e o alvo que o passo consome -- sao amostradas no
## TOPO da iteracao, antes de `_advance`, porque depois do passo o plug ja e AIR e o
## alvo ja foi zerado pelo `_dig_reset`: amostradas tarde diriam "ar" e nenhum
## compromisso, que e o que a checagem precisa distinguir. O integrador roda pelos
## mesmos tres frames por passo do `_dig_window` porque a atribuicao so vale se o
## instrumento esteve la para produzir o empurrao que ela mesma mostra.
func _scent_entry_window(block: int, ticks_limit: int = 200,
		limpar: bool = true) -> Dictionary:
	_arm(Vector3(57.4, 51.001, 54.0), FAR_PLAYER)
	var plug := Vector3i(58, 51, 54)
	_dig_plug(plug, block)
	_field.imprint(Vector3(58.0, 50.6, 54.0), AetherField.Channel.BLOOD, 0.9)
	_advance(1, false)
	var celula: Vector3i = _wolf._scent_cell
	var achou: bool = _wolf._scent_found
	var canal: int = _wolf._scent_channel
	var forca: float = _wolf._scent_strength
	var pos_antes: Vector3 = _wolf._scent_pos
	var y_antes := _wolf._scent_ground_y(celula)
	var ticks := 1
	var empurra_antes := 0
	var empurra_obra := 0
	var exam_tick := -1
	var obra_tick := -1
	var boca_tick := -1
	var arma := Wolf.DIG_NONE
	var alvo := Wolf.DIG_NONE
	var alvo_boca := Wolf.DIG_NONE
	var y_boca := -1.0
	var bloco_antes := block
	var passos_obra := -1
	var passos_andados := 0
	var alvo_trocado := 0
	var intentos_obra := {}
	for i: int in ticks_limit:
		ticks += 1
		var topo_alvo: Vector3i = _wolf._dig_pos
		var topo_bloco: int = _world.get_block(plug)
		if exam_tick > 0 and boca_tick < 0 and topo_alvo != arma and topo_alvo != Wolf.DIG_NONE:
			alvo_trocado += 1
		_advance(1, false)
		# Logo depois de `_advance` e antes dos tres frames de locomocao: e o `want`
		# que o corpo vai ver neste passo, ou seja -- a unica entrada com que o ramo
		# (a) pode armar (`_dig_cell` comeca em `want` e devolve `DIG_NONE` quando
		# ele e zero).
		if exam_tick > 0 and boca_tick < 0:
			var quer := _wolf._move_target - _wolf.body.feet_pos
			quer.y = 0.0
			if quer.length_squared() > 1e-8:
				passos_andados += 1
			var quem := String(_wolf.intent)
			intentos_obra[quem] = int(intentos_obra.get(quem, 0)) + 1
		for f: int in 3:
			_wolf._physics_process(SimClock.STEP / 3.0)
			if _wolf.body.blocked_horizontal:
				if exam_tick < 0:
					empurra_antes += 1
				else:
					empurra_obra += 1
		if exam_tick < 0 and String(_wolf.get("_reaction")) == "rastro examinado":
			exam_tick = ticks
			arma = _wolf._dig_scent
		if obra_tick < 0 and _wolf._dig_pos != Wolf.DIG_NONE:
			obra_tick = ticks
			alvo = _wolf._dig_pos
		if boca_tick < 0 and _world.get_block(plug) == BlockDefs.Block.AIR:
			boca_tick = ticks
			alvo_boca = topo_alvo
			bloco_antes = topo_bloco
			passos_obra = ticks - obra_tick
			y_boca = _wolf._scent_ground_y(celula)
		# Dez passos depois da boca = duas cadencias do nariz (SCENT_PERIOD = 5): o
		# suficiente para a releitura da mesma celula acontecer e, se a igualdade de
		# camada do §3.2 (b) nao existisse, para o bloco de baixo ser re-armado.
		if boca_tick > 0 and ticks - boca_tick >= 10:
			break
	var out := {
		"ticks": ticks, "empurra_antes": empurra_antes, "empurra_obra": empurra_obra,
		"passos_andados": passos_andados, "alvo_trocado": alvo_trocado,
		"intentos_obra": intentos_obra,
		"celula": celula, "achou": achou, "canal": canal, "forca": forca,
		"pos_antes": pos_antes, "y_antes": y_antes, "y_boca": y_boca,
		"y_fim": _wolf._scent_ground_y(celula),
		"exam_tick": exam_tick, "obra_tick": obra_tick, "boca_tick": boca_tick,
		"arma": arma, "alvo": alvo, "alvo_boca": alvo_boca, "passos_obra": passos_obra,
		"aberto": _world.get_block(plug) == BlockDefs.Block.AIR,
		"bloco": _world.get_block(plug), "bloco_antes": bloco_antes,
		"chave": _world.edits.has(plug),
		"nariz_fim": _wolf._dig_scent, "pos_fim": _wolf._scent_pos,
		"dig_pos": _wolf._dig_pos, "dig_steps": _wolf._dig_steps,
		"dig_accum": _wolf._dig_accum,
		"intent": _wolf.intent, "reaction": _wolf.get("_reaction"),
		"feet": _wolf.body.feet_pos,
	}
	# `limpar = false` e o que a checagem 8 pede: a boca tem de continuar no mundo
	# COM a chave AIR para o `save_game()` do produto gravar, e o `_dig_plug` de
	# aqui apaga a chave e escreve ar sem registro -- exatamente o que o §2 veda
	# para o palco, e exatamente o que sumiria com a cova antes da segunda escrita.
	if limpar:
		_dig_plug(plug, BlockDefs.Block.AIR)
	return out


## Checagem 6 do dossie 12 §5.6, o item (b). A promessa e uma so e e do codigo que
## existe: remover o solido que tapa a entrada muda o `y` que `_scent_ground_y`
## devolve PARA A MESMA CELULA -- o rastro passa a ser lido no chao onde o focinho
## chega, nao em cima da tapa. A frase antiga ("WORK + BLOOD difundem com menos
## barreira") nao e observavel com a permeabilidade amostrando um voxel por celula de
## Eter (furo #23, dono perna 05), entao nada aqui roda difusao nenhuma.
## Os dois bracos mudam SO o material do plug -- neve (na lista) e pedra (fora dela)
## -- e e o par que o ciclo de trabalho pede: se o chao lido tambem se movesse com a
## pedra, ele teria se movido por qualquer coisa que nao a cova, e a morte do item
## ("se o `y` nao se move, a premissa do (b) era falsa") viria vermelha pelo motivo
## errado. A terceira metade do braco de neve e a que impede o item de virar pocinho:
## aberta a boca, a coluna devolve o chao de baixo, a igualdade de camada nao casa,
## e nada re-arma.
## A atribuicao tem o teto que a propria cena mostra: entre a entrega e a boca o
## lobo patrulha e empurra o mesmo bloco, entao "a pata nao o teria cavado" nao e
## falsificavel aqui e nao e o que se afirma. Afirma-se o que os numeros decidem --
## nenhum empurrao antes, nenhum alvo re-escolhido depois, e os 13 passos inteiros
## do acumulador do nariz. Fica como leitura desta perna, e vira linha de status: o
## ramo (b) entrega o alvo, mas num cenario em que a tapa tambem esta no caminho do
## corpo os dois ramos convergem para o mesmo buraco.
func _test_entrada_de_rastro_exposta_no_chao_lido() -> bool:
	var s := _scent_entry_window(BlockDefs.Block.SNOW)
	var c := _scent_entry_window(BlockDefs.Block.STONE)
	_check(bool(s["achou"]) and int(s["canal"]) == int(AetherField.Channel.BLOOD)
			and bool(s["celula"] == Vector3i(14, 12, 13))
			and absf(float(s["y_antes"]) - 51.6) < 1e-6
			and int(s["empurra_antes"]) == 0
			and int(s["obra_tick"]) == int(s["exam_tick"]),
			"premissa: o rastro cai na celula (14,12,13), o chao lido dela e a tapa de neve na camada do corpo, e o primeiro alvo vivo da cova nasce no tick em que a inspecao termina sem um unico quadro de empurrao antes",
			"canal=%s forca=%.6f celula=%s pos=%s chao_lido=%.3f feet=%s | examinado_no_tick=%d primeiro_alvo_no_tick=%d | empurrao antes da entrega=%d quadros, passos=%d" % [
			AetherField.CHANNEL_NAMES[int(s["canal"])], float(s["forca"]), s["celula"],
			s["pos_antes"], float(s["y_antes"]), s["feet"], int(s["exam_tick"]),
			int(s["obra_tick"]), int(s["empurra_antes"]), int(s["ticks"])])
	_check(int(s["exam_tick"]) > 0 and bool(s["arma"] == Vector3i(58, 51, 54))
			and bool(s["alvo"] == Vector3i(58, 51, 54))
			and bool(s["alvo_boca"] == Vector3i(58, 51, 54))
			and int(s["alvo_trocado"]) == 0 and int(s["passos_obra"]) == 13
			and int(s["bloco_antes"]) == BlockDefs.Block.SNOW and int(s["boca_tick"]) > 0
			and bool(s["aberto"]),
			"a obra abre a MESMA celula que a coluna leu, escolhida no tick da inspecao e nunca re-escolhida: o compromisso e do nariz -- e impresso, nao escondido, que nos 13 passos o corpo patrulha e empurra o proprio bloco, entao os dois ramos queriam este buraco",
			"examinado_no_tick=%d armado=%s obra_no_tick=%d alvo=%s | boca_no_tick=%d alvo_na_boca=%s passos_de_obra=%d (DIG_STEPS_BEFORE=8 + 5 de neve), alvo trocado=%d | plug=%s virou=%s chave_no_registro=%s | fundo de obra: intentos=%s, want vivo em %d de 13, empurrao=%d quadros" % [
			int(s["exam_tick"]), s["arma"], int(s["obra_tick"]), s["alvo"],
			int(s["boca_tick"]), s["alvo_boca"], int(s["passos_obra"]),
			int(s["alvo_trocado"]),
			BlockDefs.display_name(int(s["bloco_antes"])),
			BlockDefs.display_name(int(s["bloco"])), s["chave"], s["intentos_obra"],
			int(s["passos_andados"]), int(s["empurra_obra"])])
	_check(absf(float(s["y_boca"]) - 50.6) < 1e-6
			and absf(float(s["y_antes"]) - float(s["y_fim"]) - 1.0) < 1e-6
			and String(s["intent"]) == "investigate",
			"a promessa do (b) medida no numero que ela nomeia: o chao lido da mesma celula desce exatamente um bloco, e o passo seguinte ainda e farejo",
			"y antes=%.3f depois=%.3f delta=%.3f | pos antes=%s depois=%s | intent=%s reacao=%s" % [
			float(s["y_antes"]), float(s["y_fim"]),
			float(s["y_antes"]) - float(s["y_fim"]), s["pos_antes"], s["pos_fim"],
			s["intent"], s["reaction"]])
	_check(not bool(c["aberto"]) and int(c["boca_tick"]) < 0
			and bool(c["arma"] == Wolf.DIG_NONE)
			and absf(float(c["y_fim"]) - float(c["y_antes"])) < 1e-6
			and bool(s["nariz_fim"] == Wolf.DIG_NONE),
			"controles: pedra fora da lista nao arma nada e nao move chao nenhum, e a boca aberta da neve nao re-arma o bloco de baixo -- o item se termina sozinho",
			"neve: y=%.3f->%.3f novo_alvo=%s | pedra: armado=%s boca=%d y=%.3f->%.3f feet=%s" % [
			float(s["y_antes"]), float(s["y_fim"]), s["nariz_fim"], c["arma"],
			int(c["boca_tick"]), float(c["y_antes"]), float(c["y_fim"]), c["feet"]])
	return true


## Frames de malharia pelo orcamento do produto ate a fila esvaziar (ou o teto).
## Devolve as tres testemunhas que a checagem 4 do dossie 12 exige: quantos frames a
## fila levou, qual foi a maior fila vista no comeco de um frame e o pior
## `last_mesh_ms()` de um lote. `MESH_BUDGET` e lido de `src/main.gd:28`, nao copiado
## para ca: o numero que importa e o preco do orcamento que o jogador sente, e um 2
## escrito a mao envelheceria no dia em que o budget mudar.
func _mesh_frames(frames_limit: int = 64) -> Dictionary:
	var frames := 0
	var max_pending := _world.pending_meshes()
	var worst_ms := 0.0
	while _world.pending_meshes() > 0 and frames < frames_limit:
		_world.process(int(Session.MESH_BUDGET))
		frames += 1
		max_pending = maxi(max_pending, _world.pending_meshes())
		worst_ms = maxf(worst_ms, _world.last_mesh_ms())
	return {
		"frames": frames, "max_pending": max_pending, "worst_ms": worst_ms,
		"left": _world.pending_meshes(),
	}


## Checagem 9 do dossie 12 §5.9, o outro lado do mandato 3 nesta perna: o cavar nao
## pode mexer na fita de onde a simulacao sorteia. O palco e o MESMO da checagem 5
## (o §5.5 que a pauta nomeia), com o pino do molde de
## `simulation_rng_test.gd:75-77` posto entre o armamento e os N passos e lido
## depois deles, e o braco de pedra e o que impede a conclusao de vir do acaso: la a
## pata recusa por material e o desvio sorteia do mesmo jeito.
##
## As quatro portas, cada uma com o numero que a decide. (1) A premissa: no braco de
## neve a boca abre e a pata arma ao menos uma vez, senao as tres linhas seguintes
## seriam verdade por nada ter acontecido. (2) O `randi()` de depois e o mesmo que o
## pino previu nos dois bracos -- a cadeia inteira do cavar (`_dig_arm` no corpo,
## `_dig_step` no passo, `set_block` e `imprint` na obra) nao consome RNG global.
## (3) O sorteio do desvio nao perdeu o lugar dele: em CADA quadro que arma a pata o
## `_unstick` sobe junto, e nenhum quadro de armar fica sem sorteio -- e a metade
## "continuam incondicionais" do item, porque se alguem mover os dois `randf_range`
## para dentro de um `if`, a linha 3 e a que grita primeiro. (4) O par de pedra: la
## `armadas == 0` com `rearms >= 2` e os `_detour` ocupando uma faixa, ou seja, o
## detector ve o sorteio tambem onde a pata nunca chegou a armar -- ele nao esta
## contando a pata duas vezes, e a faixa e o que impede a linha 3 de se satisfazer
## com um unico sorteio.
##
## O detector do sorteio e uma leitura de estado, nao um contador dentro do lobo:
## `_unstick` so tem duas escritas no arquivo (`-= delta` no passo andante e o
## `randf_range(0.35, 0.8)` do desemperto), entao subir so pode ser o sorteio. Isso
## e o que mantem a checagem olhando o produto em vez de olhar um espelho da propria
## instrumentacao.
func _test_cavar_nao_consome_rng_da_sessao() -> bool:
	var a := _dig_window(BlockDefs.Block.SNOW, [51, 52], 200, 1, false, {}, true)
	var b := _dig_window(BlockDefs.Block.STONE, [51, 52], 200, 1, false, {}, true)
	_check(int(a["boca_tick"]) > 0 and int(a["armadas"]) >= 1
			and int(a["horizontais"]) > 0,
			"premissa: no palco da checagem 5 a neve cava, a pata arma e o corpo encosta na face",
			"boca_no_tick=%d janela=%d armadas=%d horizontais=%d encostou=%s bocas=%d" % [
			int(a["boca_tick"]), int(a["ticks"]), int(a["armadas"]),
			int(a["horizontais"]), a["encostou"], int(a["bocas_n"])])
	_check(bool(a["rng_preservado"]) and bool(b["rng_preservado"]),
			"os N passos do cavar nao consomem RNG global -- o `randi()` depois do pino e o mesmo nos dois bracos",
			"neve: pino=%d randi_previsto=%d randi_depois=%d | pedra: randi_previsto=%d randi_depois=%d | passos_neve=%d passos_pedra=%d" % [
			RNG_PIN, int(a["rng_next"]), int(a["rng_depois"]),
			int(b["rng_next"]), int(b["rng_depois"]), int(a["ticks"]), int(b["ticks"])])
	_check(int(a["armadas_com_rearm"]) == int(a["armadas"]) and int(a["armadas"]) >= 1
			and int(a["rearms"]) >= int(a["armadas"]),
			"os dois `randf_range` do desvio continuam incondicionais: cada um dos quadros que arma a pata sorteia o desvio no mesmo quadro, e nenhum quadro de armar fica sem sorteio",
			"neve: armadas=%d armadas_com_rearm=%d rearms=%d | detour do armar=%.3f | horizontais=%d boca_no_tick=%d" % [
			int(a["armadas"]), int(a["armadas_com_rearm"]), int(a["rearms"]),
			float(a["detour_min"]), int(a["horizontais"]), int(a["boca_tick"])])
	_check(int(b["armadas"]) == 0 and int(b["rearms"]) >= 2
			and float(b["detour_max"]) > float(b["detour_min"]),
			"o detector ve o sorteio onde a pata NAO arma e ele nao vira ponto: o braco de pedra recusa por material, desemperta 2+ vezes e os `_detour` ocupam uma faixa de verdade (codigo: [-1,300, 1,300])",
			"pedra: armadas=%d rearms=%d bocas=%d detour em [%.3f, %.3f] janela=%d | neve: armadas=%d rearms=%d" % [
			int(b["armadas"]), int(b["rearms"]), int(b["bocas_n"]),
			float(b["detour_min"]), float(b["detour_max"]), int(b["ticks"]),
			int(a["armadas"]), int(a["rearms"])])
	return true


## Dossie 12 §8(a): o instrumento de malharia entra ANTES de o cavar existir, para o
## numero do estado atual chegar a mesa com a folha ainda inerte. A armadilha que ele
## desarma e do harness, nao do jogo: `_advance` nunca chama `world.process` porque o
## campo congelado e o que isola a reacao -- sem dreno a colheita mediria a fila
## crescendo para sempre, e o `count` de `edit_mesh_cost()` seria zero para sempre
## tambem, porque `_mark` so carimba um chunk que ja tem mesh
## (`voxel_world.gd:301`). Os dois numeros que a checagem `malharia_do_cavar_medida`
## vai publicar so existem depois deste, e e por isso que ele roda por ultimo: malhar
## o mundo no meio da corrida mudaria o que as checagens de passo colhem.
##
## O lote e um voxel removido por lobo do censo do boot, pela mesma escrita que o
## cavar usara (`set_block(pos, AIR)` com `record` default) e no mesmo teto de
## concorrencia que a matilha tem hoje -- `WOLF_COUNT` lido do produto, nao chutado.
func _test_colheita_de_malha_sem_cavar() -> bool:
	var meshes_0 := _world.meshes_built()
	var fila_0 := _world.pending_meshes()
	# O boot pelo caminho do produto: `main.gd:135` malha o mundo inteiro antes de o
	# primeiro tick rodar, entao o palco do cavar comeca igual ao do jogador.
	var t0 := Time.get_ticks_usec()
	_world.generate_meshes_all()
	var boot_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var meshes_1 := _world.meshes_built()
	# A fila que o palco deixou: este runner monta a plateia com `set_block` ANTES de
	# malhar, e `generate_meshes_all()` percorre os chunks sujos sem esvaziar `_dirty`
	# -- no produto isso nao acontece, porque la o `generate` deixa a fila vazia e a
	# primeira edicao so vem depois do boot. Drenar antes do lote nao e cerimonia: sem
	# esse passo o `count` do instrumento seria 5 contra 17 remeshes e o `worst_us`
	# mediria a espera atras de 16 chunks que ninguem pediu.
	var palco := _mesh_frames()
	var meshes_2 := _world.meshes_built()
	var alvos := int(Session.WOLF_COUNT)
	var feitos := 0
	var chunks_do_lote := {}
	var y_lido := -1
	for key in _world.chunks:
		if feitos >= alvos:
			break
		var c: VoxelChunk = _world.chunks[key]
		var x: int = c.coord.x * VoxelChunk.SIZE_X + VoxelChunk.SIZE_X / 2
		var z: int = c.coord.y * VoxelChunk.SIZE_Z + VoxelChunk.SIZE_Z / 2
		var y: int = _world.surface_height(x, z)
		# So o plateau da fixture: la o chao e o y=50 que o palco garante, entao a
		# recusa de um ponto nunca vira "o lote ficou curto por acaso do relevo".
		if y != 50:
			continue
		if _world.set_block(Vector3i(x, y, z), BlockDefs.Block.AIR):
			feitos += 1
			chunks_do_lote[key] = true
			y_lido = y
	var colheita := _mesh_frames()
	var meshes_3 := _world.meshes_built()
	var cost: Dictionary = _world.edit_mesh_cost()
	_check(meshes_1 == _world.chunks.size(), "boot malha o mundo inteiro pelo caminho do produto",
			"meshes=%d/%d  fila_no_boot=%d  boot_ms=%.1f  meshes_ant=%d" % [
			meshes_1, _world.chunks.size(), fila_0, boot_ms, meshes_0])
	_check(int(palco["left"]) == 0, "a fila que o palco deixou drena antes do lote",
			"fila_ini=%d remeshes=%d frames=%d fila_max=%d" % [
			fila_0, meshes_2 - meshes_1, int(palco["frames"]), int(palco["max_pending"])])
	_check(feitos == alvos and chunks_do_lote.size() == alvos,
			"o lote removeu um voxel por lobo do censo do boot, em chunks distintos",
			"aceitas=%d alvos=%d chunks=%d y=%d" % [feitos, alvos, chunks_do_lote.size(), y_lido])
	_check(int(colheita["left"]) == 0 and int(cost["pending"]) == 0,
			"fila de malharia drena e nenhum carimbo fica aberto",
			"fila=%d carimbos_abertos=%d frames=%d" % [
			int(colheita["left"]), int(cost["pending"]), int(colheita["frames"])])
	# A conta do instrumento tem de bater com o trabalho que a fila fez: todo chunk
	# remalhado depois do carimbo fecha um carimbo, e nenhum carimbo fecha sem remesh.
	_check(int(cost["count"]) == meshes_3 - meshes_2,
			"custo de edicao == chunks remalhados no lote",
			"count=%d remeshes=%d (meshes %d -> %d)" % [
			int(cost["count"]), meshes_3 - meshes_2, meshes_2, meshes_3])
	_check(int(cost["worst_us"]) > 0 and float(cost["mean_us"]) > 0.0,
			"instrumento de edicao vivo (worst e mean acima de zero)",
			"worst_us=%d mean_us=%.1f" % [int(cost["worst_us"]), float(cost["mean_us"])])
	_check(int(colheita["max_pending"]) <= 8,
			"nenhum frame com fila acima de 8 chunks",
			"fila_max=%d budget=%d frames=%d worst_lote_ms=%.1f" % [
			int(colheita["max_pending"]), int(Session.MESH_BUDGET),
			int(colheita["frames"]), float(colheita["worst_ms"])])
	print("COLHEITA DE MALHA SEM CAVAR (dossie 12 §4, estado atual), NAO GATE P1: boot chunks=%d ms=%.1f | fila do palco remeshes=%d frames=%d | lote edicoes=%d frames=%d fila_max=%d worst_lote_ms=%.1f | edit_cost count=%d worst_us=%d mean_us=%.1f pending=%d" % [
		meshes_1, boot_ms, meshes_2 - meshes_1, int(palco["frames"]),
		feitos, int(colheita["frames"]), int(colheita["max_pending"]),
		float(colheita["worst_ms"]), int(cost["count"]), int(cost["worst_us"]),
		float(cost["mean_us"]), int(cost["pending"])])
	return true


func _slot_bytes() -> int:
	var f := FileAccess.open(SaveManager.slot_path(Session.SLOT), FileAccess.READ)
	if f == null:
		return -1
	var n := f.get_length()
	f.close()
	return n


## Checagem 8 do dossie 12 §5.8, o §3.3 virado numero, e por isso roda POR ULTIMO
## no runner: a metade do load escreve no `_world` compartilhado desta casa. E
## exatamente a razao pela qual a perna 14 deixou o save/load fora deste
## instrumento de proposito (doc de `_test_feedback_do_jogador_continua_no_hud`), e
## aqui ela e paga com a boca na mesa: depois desta linha o plateau nao e mais o
## plateau, entao nenhum numero de malharia ou de passo pode vir depois dele.
##
## As quatro portas sao as quatro frases do item, cada uma com o numero que a
## decide. (1) A obra parada no meio existe de verdade -- acumulo entre zero e a
## dureza da neve, boca ainda nao aberta, alvo no plug -- e o `state_dict()` do lobo
## nao carrega chave de cova nenhuma, que e a outra metade de "o disco nao guarda a
## intencao". (2) `load_state` devolve os quatro campos ao nada: a cova comecada
## antes do save recomeca depois dele (§3.1). (3) A boca e a UNICA chave que o
## registro ganha entre as duas escritas do produto, e o `generate` + `apply_edits`
## do disco a devolve AIR com chave e `edits.size()` batendo -- o §3.3 na letra: "um
## buraco que some no load e a mentira da vez". (4) O que nao tem chave nao
## sobrevive: a tapa de neve ao lado, montada com `record = false` pelo mesmo §2,
## volta como o relevo que o gerador sorteou, e os bytes do arquivo com e sem a
## cova sao o preco que o item cobra em numero, nao em adjetivo.
##
## O load e as DUAS chamadas que `main.load_game()` faz no mundo, na mesma ordem e
## com a mesma conversao de chave (`main.gd:1050-1054`), e nao a funcao inteira:
## `load_game()` tambem chama `audio.clear_transient()` e o `audio` e nodo criado no
## `_ready` da cena (`main.gd:190`), que este runner nunca roda -- pelo caminho
## completo o passo morreria em SCRIPT ERROR e levaria as checagens dele embora em
## silencio (mandato 1). O `save_game()` e o produto inteiro, sem atalho.
## O slot volta ao que era no fim, pelo mesmo motivo escrito na suíte:
## `user://saves/world_alpha.json` e o jogo gravado pelo dono, e um instrumento que
## o deixa podre envenena a proxima sessao dele.
func _test_cavar_sobrevive_ao_save() -> bool:
	var plug := Vector3i(58, 51, 54)
	var parede := Vector3i(58, 51, 55)
	var chave := Coords.block_key(plug)
	var chave_parede := Coords.block_key(parede)
	var antes := SaveManager.read_slot(Session.SLOT)
	var havia_disco := bool(antes["ok"])
	var dados_antes: Dictionary = antes["data"]

	# (1) A janela para no passo 50: a boca da neve abre no 13º passo de obra e a
	# obra comeca no tick 40 da entrega, entao aqui o acumulo esta vivo e incompleto.
	var meio := _scent_entry_window(BlockDefs.Block.SNOW, 50, false)
	var dureza := BlockDefs.hardness(BlockDefs.Block.SNOW)
	var d_lobo: Dictionary = _wolf.state_dict()
	var chaves_dig := ""
	for k in d_lobo:
		if String(k).contains("dig"):
			chaves_dig += String(k) + " "
	_check(not bool(meio["aberto"]) and bool(meio["dig_pos"] == plug)
			and float(meio["dig_accum"]) > 0.0 and float(meio["dig_accum"]) < dureza
			and int(meio["boca_tick"]) < 0 and chaves_dig.is_empty()
			and int(meio["dig_steps"]) > Wolf.DIG_STEPS_BEFORE,
			"premissa: a cova esta parada no meio -- alvo vivo, acumulo acima de zero e abaixo da dureza da neve, boca ainda nao aberta -- e o dicionario que o save grava nao tem nenhuma chave de cova",
			"alvo=%s passos=%d (DIG_STEPS_BEFORE=%d) acumulo=%.3f de %.3f | boca=%d | chaves de dig no state_dict=[%s] | chaves no disco: plug=%s parede=%s" % [
			meio["dig_pos"], int(meio["dig_steps"]), Wolf.DIG_STEPS_BEFORE,
			float(meio["dig_accum"]), dureza, int(meio["boca_tick"]),
			chaves_dig.strip_edges(), _world.edits.has(plug), _world.edits.has(parede)])

	# (2) A transicao real do lobo carregado: `state_dict()` -> `load_state()`, a
	# mesma dupla que `main.load_game()` chama por bicho do disco.
	var alvo_antes: Vector3i = _wolf._dig_pos
	var nariz_antes: Vector3i = _wolf._dig_scent
	var passos_antes := int(_wolf._dig_steps)
	var acumulo_antes := float(_wolf._dig_accum)
	_wolf.load_state(d_lobo)
	_check(bool(_wolf._dig_pos == Wolf.DIG_NONE) and bool(_wolf._dig_scent == Wolf.DIG_NONE)
			and _wolf._dig_steps == 0 and absf(_wolf._dig_accum) < 1e-9
			and acumulo_antes > 0.0,
			"a cova comecada antes do load recomeca depois dele: os quatro campos da pata voltam ao nada pelo `_dig_reset` do load_state, e o que sobrevive e o mundo, nao a intencao (dossie 12 §3.1)",
			"antes: alvo=%s passos=%d acumulo=%.3f nariz=%s | depois: alvo=%s passos=%d acumulo=%.3f nariz=%s" % [
			alvo_antes, passos_antes, acumulo_antes, nariz_antes,
			_wolf._dig_pos, _wolf._dig_steps, _wolf._dig_accum, _wolf._dig_scent])

	# (3) As duas escritas do produto sobre a MESMA cena. O palco e re-montado
	# sem registro (chave apagada) para que a unica diferenca entre os dois discos
	# seja a chave que a pata escreve, e a sessao se monta depois do palco porque
	# `save_game()` grava o `world` compartilhado, nao uma copia.
	_dig_plug(plug, BlockDefs.Block.SNOW)
	_dig_plug(parede, BlockDefs.Block.SNOW)
	_boot_session(1)
	var s: Session = _session
	s.save_game()
	var sem := SaveManager.read_slot(Session.SLOT)
	var edits_sem: Dictionary = sem["data"]["edits"]
	var n_sem := edits_sem.size()
	var bytes_sem := _slot_bytes()
	var plug_sem := edits_sem.has(chave)
	var parede_sem := edits_sem.has(chave_parede)
	var fim := _scent_entry_window(BlockDefs.Block.SNOW, 200, false)
	s.save_game()
	var com := SaveManager.read_slot(Session.SLOT)
	var edits_com: Dictionary = com["data"]["edits"]
	var n_com := edits_com.size()
	var bytes_com := _slot_bytes()
	var novas := ""
	var n_novas := 0
	for k in edits_com:
		if not edits_sem.has(k):
			n_novas += 1
			novas += String(k) + " "
	var lista := {}
	for k in edits_com:
		lista[String(k)] = int(edits_com[k])
	_world.generate(SEED)
	_world.apply_edits(lista)
	_check(n_novas == 1 and novas.strip_edges() == chave
			and not plug_sem and bool(fim["aberto"])
			and int(edits_com[chave]) == int(BlockDefs.Block.AIR)
			and n_com == n_sem + 1 and _world.edits.size() == n_com
			and _world.get_block(plug) == BlockDefs.Block.AIR
			and _world.edits.has(plug) and not parede_sem,
			"o buraco do bicho sobrevive ao save: entre as duas escritas do produto exatamente UMA chave entra no registro -- a da boca, em AIR -- e o `generate` + `apply_edits` do disco (main.gd:1050-1054) devolvem o voxel aberto COM chave e `edits.size()` batendo",
			"chaves: disco_sem=%d disco_com=%d novas=[%s] | plug no disco antes=%s depois=%s valor=%s | no mundo apos o load: bloco=%s chave=%s | edits do mundo=%d | boca_no_tick=%d passos=%d" % [
			n_sem, n_com, novas.strip_edges(), plug_sem, edits_com.has(chave),
			str(edits_com.get(chave, -1)),
			BlockDefs.display_name(int(_world.get_block(plug))),
			_world.edits.has(plug), _world.edits.size(),
			int(fim["boca_tick"]), int(fim["passos_obra"])])

	# (4) O par que faz a (3) poder falhar pelo motivo certo: a tapa ao lado foi
	# montada com `record = false` (o §2 veda palco registrado) e nao tinha chave em
	# `edits` nem antes nem depois -- entao o load nao tem de onde a tirar, e ela
	# volta como o relevo gerado, nao como neve. Se ela voltasse neve, a (3) estaria
	# medindo o estado do mundo e nao o registro.
	_check(not _world.edits.has(parede)
			and _world.get_block(parede) != BlockDefs.Block.SNOW
			and bytes_com > bytes_sem and bytes_sem > 0,
			"o que nao tem chave nao sobrevive, e o que tem custa bytes: a neve montada sem registro volta como relevo gerado, e o disco cresce do tamanho exato de uma entrada",
			"parede sem chave: no disco plug/parede=%s/%s, bloco apos load=%s | plug apos load=%s | bytes %d -> %d (delta %+d) | chave_parede=%s" % [
			plug_sem, parede_sem,
			BlockDefs.display_name(int(_world.get_block(parede))),
			BlockDefs.display_name(int(_world.get_block(plug))),
			bytes_sem, bytes_com, bytes_com - bytes_sem, chave_parede])

	if havia_disco:
		var rest := SaveManager.write_slot(Session.SLOT, dados_antes)
		print("       disco restaurado no slot do dono: %s %d bytes" % [
				"ok" if bool(rest["ok"]) else String(rest["error"]), rest["bytes"]])
	else:
		var rm := DirAccess.remove_absolute(SaveManager.slot_path(Session.SLOT))
		print("       slot nao existia antes desta checagem: removido (%s)" % error_string(rm))
	_pack_release()
	return true


## Passo 1 (b) do dossie 22 §5.1 -- o gate do esqueleto nativo. A premissa e uma so,
## e ela nao fala de IA: existe um `.dll` de extensao que o Godot abre, e esse `.dll`
## registra a classe `AfMindOracle`. A regra de ouro do prompt ("a mente propoe, as
## regras dispoe") comeca a ser cobrada no Passo 3, quando existir prompt pra propor;
## aqui ainda nao ha o que desobedecer, e fingir que ha seria o furo #1 de volta.
##
## A checagem NASCE VERMELHA de proposito: `native/` nao existe nesta arvore, e um
## gate que so aparece junto com o codigo que ele confere nao conferiu nada. Por
## isso cada passo daqui usa somente o objeto que o passo anterior confirmou existir
## -- um `null` chamado derrubaria a funcao com `SCRIPT ERROR` e levaria as cinco
## checagens embora em silencio, que e exatamente o roubo que o censo de `_finish`
## existe para pegar.
func _test_extensao_carrega_classe() -> bool:
	var caminho := "res://native/af_mind/af_mind.gdextension"
	var classe := &"AfMindOracle"
	var mgr: Object = Engine.get_singleton(&"GDExtensionManager")
	var no_disco := FileAccess.file_exists(caminho)
	_check(no_disco, "extensao_carrega_classe: o descritor existe no disco",
			"caminho=%s existe=%s" % [caminho, str(no_disco)])
	# `load_extension` so e chamado com o descritor em disco: medido em sonda, chama-lo
	# sem arquivo faz a engine cuspir dois `ERROR` no stderr, e o vermelho passaria a
	# ser do instrumento em vez de ser da premissa. Carregada no boot tambem nao se
	# re-carrega -- a engine recusa, e a recusa nao e o fato que se quer provar.
	var ja_no_boot: bool = bool(mgr.is_extension_loaded(caminho))
	var codigo: int = -1
	if no_disco and not ja_no_boot:
		codigo = int(mgr.load_extension(caminho))
	var carregada: bool = bool(mgr.is_extension_loaded(caminho))
	var registradas: PackedStringArray = mgr.get_loaded_extensions()
	_check(carregada and (codigo == -1 or codigo == OK),
			"extensao_carrega_classe: a engine lista a extensao como carregada",
			"load_extension=%d ja_vinha_do_boot=%s agora=%s total_registradas=%d lista=%s" % [
				codigo, str(ja_no_boot), str(carregada), registradas.size(), str(registradas)])
	# O registro na lista e da engine; a biblioteca aberta e do processo. Sao fatos
	# diferentes: um `.gdextension` apontando para um `.dll` inexistente entra na lista
	# e nao abre, e e a segunda metade que o Passo 1 diz que linka.
	var ext: Object = mgr.get_extension(caminho) if carregada else null
	var valida := is_instance_valid(ext)
	var aberta: bool = valida and bool(ext.is_library_open())
	var nivel: int = int(ext.get_minimum_library_initialization_level()) if valida else -1
	_check(aberta, "extensao_carrega_classe: a biblioteca abriu dentro deste processo",
			"objeto_valido=%s is_library_open=%s nivel_minimo_de_init=%d" % [
				str(valida), str(aberta), nivel])
	var tem_classe := ClassDB.class_exists(classe)
	_check(tem_classe, "extensao_carrega_classe: a classe esta registrada na ClassDB",
			"class_exists(%s)=%s" % [String(classe), str(tem_classe)])
	# Instanciar e o que separa "a engine sabe o nome" de "existe um construtor que
	# devolve corpo": sem `class_creator` na estrutura de criacao, a classe existe e
	# `instantiate` devolve null.
	var obj: Object = ClassDB.instantiate(classe) if tem_classe else null
	var vivo := is_instance_valid(obj)
	var nome := String(obj.get_class()) if vivo else ""
	_check(vivo and nome == String(classe),
			"extensao_carrega_classe: a ClassDB devolve um objeto vivo daquela classe",
			"instantiate_valido=%s get_class=%s" % [str(vivo), nome if nome != "" else "n/d"])
	return true


## Passo 2 (b) do dossie 22 (§5.2): o pack do modelo carregado DENTRO do processo da
## engine, com os tres numeros saindo do runtime -- `af_vram_gb` com o `load_pack()`
## vazio como base medida, `af_load_ms` e `af_ctx_cells` lido do modelo. A rota e a que
## a premissa FALSA do §15.5 obriga: `set_runtime_dir` por CAMINHO ABSOLUTO antes de
## qualquer delay helper, o pack vazio primeiro (a base nao e um zero assumido), so
## depois o `.gguf` -- e o contexto nasce SO no `ctx_probe`, o unico lugar onde um
## numero escrito na primeira palavra do blob chega ao runtime e volta lido igual.
## Nasce vermelho de proposito num clone sem `models/` e sem `.tools/llama/runtime`
## (ambos gitignored): a recusa vem com o caminho impresso, nao com um numero chutado.
## O mesmo cuidado do passo 1 vale aqui: so se chama metodo no objeto que a checagem
## anterior confirmou vivo, porque um `null` chamado derrubaria as oito em silencio.
func _test_extensao_pack_no_processo() -> bool:
	var classe := &"AfMindOracle"
	if not ClassDB.class_exists(classe):
		_check(false, "extensao_pack_no_processo: a classe do esqueleto nao esta na ClassDB",
				"class_exists(%s)=false -- o passo 1 nao fechou nesta arvore" % String(classe))
		return true
	var obj: Object = ClassDB.instantiate(classe)
	if not is_instance_valid(obj):
		_check(false, "extensao_pack_no_processo: a ClassDB nao devolveu objeto vivo",
				"instantiate(%s)=null" % String(classe))
		return true
	var runtime_dir := ProjectSettings.globalize_path("res://.tools/llama/runtime")
	var gguf := ProjectSettings.globalize_path("res://models/qwen3.5-4b-q4_k_m.gguf")
	# 1) o runtime no disco, pelo diretorio gitignored: sem ele o preload nao tem o que
	# carregar e as checagens seguintes saem vermelhas com este caminho como motivo.
	var tem_llama := FileAccess.file_exists(runtime_dir + "/llama.dll")
	_check(tem_llama, "extensao_pack_no_processo: o runtime do llama esta no disco",
			"dir=%s llama_dll=%s" % [runtime_dir, str(tem_llama)])
	# 2) o `.gguf` no disco com bytes de testemunha: o corte vermelho e a existencia --
	# trocar o arquivo por outro quant e premissa nova, e o numero na linha mostra qual.
	var bytes_modelo := -1
	if FileAccess.file_exists(gguf):
		var leitor := FileAccess.open(gguf, FileAccess.READ)
		if leitor != null:
			bytes_modelo = int(leitor.get_length())
			leitor.close()
	_check(bytes_modelo > 0, "extensao_pack_no_processo: o modelo pinado esta no disco",
			"gguf=%s bytes=%d" % [gguf, bytes_modelo])
	# 3) a rota comeca pelo pack VAZIO: cinco modulos pelo caminho absoluto, base aberta
	# (estado 2) e VRAM total lida -- e o `load_pack()` vazio que o §5.2 exige como base.
	var modulos: int = int(obj.set_runtime_dir(runtime_dir))
	var codigo_base: int = int(obj.load_pack("", ""))
	var estado_base: int = int(obj.pack_state())
	var vram_total: int = int(obj.vram_total_bytes())
	var open_ms: int = int(obj.open_ms())
	_check(modulos == 5 and codigo_base == 0 and estado_base == 2 and vram_total > 0
			and open_ms >= 0,
			"extensao_pack_no_processo: o pack vazio abre a base por caminho absoluto",
			"modulos=%d codigo=%d estado=%d vram_total=%d open_ms=%d" % [
				modulos, codigo_base, estado_base, vram_total, open_ms])
	# 4) a base e honesta: no pack vazio o usado E a base -- um getter nascendo -1
	# faria o `af_vram_gb` do §5.2 um numero inventado por subtracao.
	var vram_base: int = int(obj.vram_base_bytes())
	var vram_usada_base: int = int(obj.vram_used_bytes())
	_check(vram_base > 0 and vram_usada_base == vram_base,
			"extensao_pack_no_processo: a base medida e a propria VRAM usada no pack vazio",
			"vram_base=%d vram_used_na_base=%d" % [vram_base, vram_usada_base])
	# 5) o `.gguf` entra no processo: estado 3, tempo de load medido, bytes do modelo e
	# RSS crescendo -- a testemunha de que a memoria dele esta mesmo dentro deste processo.
	# Os dois RSS sao GRANDEZAS CAPTURADAS pelo proprio load (SO sobre o mesmo instante,
	# antes e depois de mapear): ler o `antes` antes do load devolve o -1 da inicializacao,
	# medido na primeira corrida.
	var codigo_modelo: int = int(obj.load_pack("mind-small", gguf))
	var estado_modelo: int = int(obj.pack_state())
	var load_ms: int = int(obj.load_ms())
	var model_bytes: int = int(obj.model_bytes())
	var rss_antes: int = int(obj.rss_antes_bytes())
	var rss_apos: int = int(obj.rss_apos_bytes())
	_check(codigo_modelo == 0 and estado_modelo == 3 and load_ms >= 0 and model_bytes > 0
			and rss_apos > rss_antes,
			"extensao_pack_no_processo: o gguf entra no processo e cresce o RSS dele",
			"codigo=%d estado=%d load_ms=%d model_bytes=%d rss_antes=%d rss_apos=%d" % [
				codigo_modelo, estado_modelo, load_ms, model_bytes, rss_antes, rss_apos])
	# 6) a leitura vem do modelo, nao do `--ctx-size`: o treino de contexto confere com a
	# meta que o proprio `.gguf` carrega, e vocab/arquitetura saem preenchidos.
	var meta_ctx_txt := String(obj.meta_ctx())
	var ctx_train: int = int(obj.ctx_train())
	var vocab: int = int(obj.vocab_tokens())
	var arch_txt := String(obj.arch())
	var meta_ctx_num := int(meta_ctx_txt)
	_check(ctx_train > 0 and meta_ctx_num > 0 and ctx_train == meta_ctx_num
			and vocab > 0 and arch_txt != "",
			"extensao_pack_no_processo: a leitura confere com a meta do proprio modelo",
			"ctx_train=%d meta_ctx=%s vocab=%d arch=%s" % [
				ctx_train, meta_ctx_txt, vocab, arch_txt])
	# 7) o contexto SO aqui, com o pedido escrito na primeira palavra: o runtime devolve o
	# MESMO numero, e e isso que confirma o layout do blob -- a prova que o load criar o
	# contexto default deixou inatingivel (medido: probe saia 0 com NAO_CONFIRMADA). A
	# VRAM lida aqui e a DEPOIS do load, e o §5.2 exige ela antes de qualquer contexto.
	var vram_apos_load: int = int(obj.vram_used_bytes())
	var codigo_ctx: int = int(obj.ctx_probe(2048))
	var lido: int = int(obj.ctx_readback())
	var ctx_cells: int = int(obj.ctx_cells())
	var estado_ctx: int = int(obj.pack_state())
	_check(codigo_ctx == 0 and lido == 2048 and ctx_cells == 2048 and estado_ctx == 4,
			"extensao_pack_no_processo: o runtime confirma o contexto pedido por escrito",
			"probe2048=%d lido=%d ctx_cells=%d estado=%d" % [
				codigo_ctx, lido, ctx_cells, estado_ctx])
	# 8) os tres numeros do §5.2, na ordem que decide: base < depois do load < depois do
	# contexto, o estado do contexto com bytes, e a versao do runtime como string.
	var vram_apos_ctx: int = int(obj.vram_used_bytes())
	var state_bytes: int = int(obj.ctx_state_bytes())
	var versao := String(obj.runtime_version())
	_check(vram_apos_ctx > vram_apos_load and vram_apos_load > vram_base
			and state_bytes > 0 and versao != "",
			"extensao_pack_no_processo: os tres numeros do §5.2 saem na ordem certa",
			"base=%d apos_load=%d apos_ctx=%d ctx_state_bytes=%d versao=%s" % [
				vram_base, vram_apos_load, vram_apos_ctx, state_bytes, versao])
	return true


## Passo 3 do dossie 22 (§5.3), ajustado ao Passo 4 (§5.4): o gate `contrato_igal_ao_http`.
## O MESMO roster de um cenario fixo -- o lobo que o `_arm` cria, congelado no `_stage` --
## passa DUAS vezes: uma pela transporta HTTP (um CLIENTE DE REFERENCIA montado aqui
## dentro, contra um llama-server que o proprio gate levanta com o argv do antigo host e
## derruba pelo pid exato do lancamento -- tests/ pode usar HTTPRequest, o gate do §5.4
## grepa apenas src/) e uma pela extensao (`AfMindOracle.enqueue`/`wait`, a rota ClassDB
## que ate este gate nunca tinha sido exercida do GDScript), com o prompt narrativo
## EXATO que o wrapper `MindOracle` envia (`_prompt_narracao`, static). A comparacao e de
## FORMA e nunca de frase: chaves e tipos do Dictionary de saida, reason vazio no sucesso,
## motivo nomeado na recusa -- o texto da narrativa e leitura do modelo, nao contrato. As
## 22 checagens saem em TODOS os caminhos (servidor que nao sobe, gguf que falta): cada
## uma nomeia a premissa com o numero que a decide, e recusa legivel nunca e hang -- todos
## os `await` desta corotina tem prazo. A chave do servidor nao vai para o log (ele vira
## evidencia publica): so `key_source` e o COMPRIMENTO dela.
func _test_contrato_igal_ao_http() -> bool:
	var classe := &"AfMindOracle"
	if not ClassDB.class_exists(classe):
		_check(false, "contrato_igal_ao_http: a classe do esqueleto nao esta na ClassDB",
				"class_exists(%s)=false -- o passo 1 nao fechou nesta arvore" % String(classe))
		return true
	var runtime_dir := ProjectSettings.globalize_path("res://.tools/llama/runtime")
	var server_exe := runtime_dir + "/llama-server.exe"
	var gguf := ProjectSettings.globalize_path("res://models/qwen3.5-4b-q4_k_m.gguf")
	var porta := 8791
	var url := "http://127.0.0.1:%d" % porta
	var chave := MindOracle.resolve_api_key()
	var fonte_chave := MindOracle.key_source
	_arm()

	# 1) as premissas de disco do lado HTTP: sem elas o gate nao levanta nada e as
	# checagens seguintes saem vermelhas com o caminho como motivo, nunca penduradas.
	var tem_server := FileAccess.file_exists(server_exe)
	var tem_gguf := FileAccess.file_exists(gguf)
	_check(tem_server and tem_gguf, "contrato: llama-server e gguf no disco",
			"server=%s gguf=%s" % [str(tem_server), str(tem_gguf)])

	var http := HTTPRequest.new()
	http.name = "GateHttp"
	root.add_child(http)
	var cabecalhos_chave: PackedStringArray = ["Authorization: Bearer " + chave]

	# 2) a porta pergunta ANTES de qualquer lancamento (o padrao do `LlmServerHost`):
	# livre -> levantar; nosso reuso (200 com o alias) -> reusar sem matar; estrangeiro
	# (401, ou 200 sem o alias) -> nao matar, nao reusar, imprimir o motivo.
	var r0 := await _gate_http_get(http, url + "/v1/models", cabecalhos_chave, 3.0)
	var codigo_porta := int(r0[1])
	var porta_livre := int(r0[0]) != HTTPRequest.RESULT_SUCCESS or codigo_porta == 0
	var nosso_reuso := int(r0[0]) == HTTPRequest.RESULT_SUCCESS and codigo_porta == 200 \
			and _gate_body_tem_alias(r0[3])
	var motivo_porta := ""
	if porta_livre:
		motivo_porta = "sem resposta na porta %d (result %d)" % [porta, int(r0[0])]
	elif nosso_reuso:
		motivo_porta = "200 com o alias %s (reuso)" % MindOracle.MODEL_ALIAS
	elif codigo_porta == 401:
		motivo_porta = "401: servidor estrangeiro ou de outra chave"
	else:
		motivo_porta = "%d sem o alias %s" % [codigo_porta, MindOracle.MODEL_ALIAS]
	_check(nosso_reuso or porta_livre, "contrato: a porta %d esta livre ou e nosso reuso" % porta,
			"code=%d (%s)" % [codigo_porta, motivo_porta])

	# 3) o lancamento proprio, pelo pid exato: o mesmo argv do `_spawn` do
	# `LlmServerHost` (alias, reasoning off, imprint da chave) -- a chave NAO vai
	# para o log, so a fonte dela e o comprimento.
	var pid_subido := -1
	if nosso_reuso:
		pass  # reuso nao e nosso para matar: pid fica -1 e o desmanche o sabe
	elif porta_livre and tem_server and tem_gguf:
		var argv := PackedStringArray([
			"-m", gguf,
			"--host", "127.0.0.1", "--port", str(porta),
			"-c", "4096", "-ngl", "99",
			"--alias", MindOracle.MODEL_ALIAS, "--reasoning", "off",
			"--api-key", chave,
		])
		pid_subido = OS.create_process(server_exe, argv, false)
		if pid_subido > 0:
			_af_server_pid = pid_subido
	_check(pid_subido > 0 or nosso_reuso,
			"contrato: servidor levantado por lancamento proprio ou reuso nomeado",
			"pid=%d fonte_da_chave=%s len_chave=%d" % [pid_subido, fonte_chave, chave.length()])

	# 4) a saude pelo /health publico: 200 e pronto, 503 e "carregando" e conta, o
	# prazo e o BOOT_DEADLINE do hospedeiro (90 s) -- estourar e vermelho, nao hang.
	var health_ok := false
	var health_code := 0
	var health_503 := 0
	var boot_ms := -1
	if pid_subido > 0 or nosso_reuso:
		var inicio_saude := Time.get_ticks_msec()
		var prazo_saude := inicio_saude + 90000
		while Time.get_ticks_msec() < prazo_saude:
			var rh := await _gate_http_get(http, url + "/health", [], 3.0)
			health_code = int(rh[1])
			if int(rh[0]) == HTTPRequest.RESULT_SUCCESS and health_code == 200:
				health_ok = true
				boot_ms = Time.get_ticks_msec() - inicio_saude
				break
			if health_code == 503:
				health_503 += 1
			await _gate_frame_sleep(250)
	_check(health_ok, "contrato: /health 200 dentro de 90 s (503 conta como carregando)",
			"code=%d 503=%d boot_ms=%d" % [health_code, health_503, boot_ms])

	# 5) a impressao digital: com a chave, /v1/models devolve 200 e lista o alias que
	# separa O NOSSO servidor de um terceiro na mesma porta.
	var fp_ok := false
	var fp_code := 0
	if pid_subido > 0 or nosso_reuso:
		var rf := await _gate_http_get(http, url + "/v1/models", cabecalhos_chave, 3.0)
		fp_code = int(rf[1])
		fp_ok = int(rf[0]) == HTTPRequest.RESULT_SUCCESS and fp_code == 200 \
				and _gate_body_tem_alias(rf[3])
	_check(fp_ok, "contrato: /v1/models com a chave devolve 200 com o alias",
			"code=%d alias=%s" % [fp_code, MindOracle.MODEL_ALIAS])

	# --- metade HTTP: cliente de REFERENCIA dentro do gate -------------------------------
	# O Passo 4 aposenta o MindOracle que fala HTTP (§5.4); a metade HTTP do gate
	# vira um cliente cru AQUI dentro (tests/ pode usar HTTPRequest; o gate do
	# §5.4 grepa apenas src/). O payload e o MESMO formato que o wrapper antigo
	# montava: uma mensagem de system + uma de user com o prompt puro do lobo,
	# e a resposta passa pelo MESMO `_clean` antes de virar narrativa.
	var payload_ref := {
		"model": MindOracle.MODEL_ALIAS,
		"messages": [
			{"role": "system", "content": "Voce narra o interior de um lobo de um " \
					+ "jogo para uma linha de debug. Responda com UMA frase curta em " \
					+ "portugues, sem nomes de sistemas, sem listas, sem pense em voz alta."},
			{"role": "user", "content": MindOracle._prompt_for(_wolf)},
		],
		"max_tokens": 64,
		"temperature": 0.7,
	}

	# 6) a MESMA chave resolve nos dois lados: o que subiu o servidor e o que monta
	# o pedido leem a mesma resolucao estatica.
	_check(MindOracle.resolve_api_key() == chave and chave.length() > 0,
			"contrato: o oraculo le a MESMA chave que subiu o servidor",
			"len_chave=%d fonte=%s" % [chave.length(), fonte_chave])

	# 7) FORMA do sucesso HTTP: narrativa String nao vazia apos o `_clean`. O
	# prazo e 60 s de teto, e a recusa legivel e o codigo impresso.
	var narrativa := ""
	var razao_http := "sem resposta"
	var pedidos_ref := 0
	if pid_subido > 0 or nosso_reuso:
		var prazo_narr := Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < prazo_narr:
			var rr := await _gate_http_post(http, url + "/v1/chat/completions",
					cabecalhos_chave, JSON.stringify(payload_ref), 60.0)
			pedidos_ref += 1
			if int(rr[0]) == HTTPRequest.RESULT_SUCCESS and int(rr[1]) == 200:
				var data = JSON.parse_string((rr[3] as PackedByteArray).get_string_from_utf8())
				if data is Dictionary:
					var choices: Array = (data as Dictionary).get("choices", [])
					if not choices.is_empty() and choices[0] is Dictionary:
						narrativa = MindOracle._clean(String(
								(choices[0] as Dictionary).get("message", {}).get("content", "")))
						razao_http = ""
						break
			razao_http = "codigo http %d" % int(rr[1])
			await _gate_frame_sleep(500)
	_check(narrativa is String and narrativa != "" and razao_http == "",
			"contrato: FORMA do sucesso HTTP (cliente de referencia, narrativa String nao vazia)",
			"narrativa=%d chars reason='%s' pedidos=%d" % [
				narrativa.length(), razao_http, pedidos_ref])

	# 8) FORMA da recusa HTTP: chave errada e 401 NOMEADO no codigo, nenhum texto
	# aceito. O cliente de mentira morre com o gate, nao ha nodo para desmanchar.
	var narrativa_401 := ""
	var razao_401 := "sem resposta"
	if pid_subido > 0 or nosso_reuso:
		var cabecalhos_401: PackedStringArray = ["Content-Type: application/json",
				"Authorization: Bearer chave-errada-do-gate-401"]
		var rq := await _gate_http_post(http, url + "/v1/chat/completions",
				cabecalhos_401, JSON.stringify(payload_ref), 10.0)
		razao_401 = "codigo http %d" % int(rq[1]) if int(rq[0]) == HTTPRequest.RESULT_SUCCESS \
				else "sem resposta (result %d)" % int(rq[0])
	_check(narrativa_401 == "" and razao_401.contains("401"),
			"contrato: FORMA da recusa HTTP (chave errada nomeia 401)",
			"reason='%s'" % razao_401)

	# --- metade extensao: a rota ClassDB do mesmo cenario --------------------------------
	var obj: Object = ClassDB.instantiate(classe)
	var tem_obj := is_instance_valid(obj)
	# 8) o pack no estado de fila (4) pela rota do passo 2 (b), sem atalho: runtime
	# absoluto, pack vazio, gguf, ctx_probe -- e NUNCA recarregar modelo num processo
	# que ja tem um (a recusa -5 da ponte existe para isso).
	var estado_ext := -1
	var codigo_ctx := -1
	var texto_erro_pack := ""
	if tem_obj:
		int(obj.set_runtime_dir(runtime_dir))
		if tem_gguf:
			int(obj.load_pack("", ""))
			int(obj.load_pack("mind-small", gguf))
			codigo_ctx = int(obj.ctx_probe(2048))
		estado_ext = int(obj.pack_state())
		texto_erro_pack = String(obj.err_text())
	_check(estado_ext == 4 and codigo_ctx == 0,
			"contrato: o pack da extensao chega ao estado de fila (4) pela rota do passo 2 (b)",
			"estado=%d ctx_probe=%d gguf=%s err_pack='%s'" % [
				estado_ext, codigo_ctx, str(tem_gguf), texto_erro_pack])

	# 9) enqueue pela rota ClassDB: o pedido leva o MESMO prompt narrativo que o
	# wrapper envia ao jogo (`_prompt_narracao`, static, dobrado numa mensagem so)
	# -- as duas transportas levam o mesmo conteudo sem copiar o formato a mao.
	var id1 := -1
	var depth1 := -1
	var texto_erro := ""
	if tem_obj:
		var req := {
			"role": "user",
			"prompt": MindOracle._prompt_narracao(_wolf),
			"max_tokens": 64,
			"temperature": 0.7,
		}
		id1 = int(obj.enqueue(req))
		depth1 = int(obj.queue_depth())
		texto_erro = String(obj.prompt_err_text())
	_check(id1 > 0 and depth1 == 1,
			"contrato: enqueue pela rota ClassDB devolve id e a fila cresce para 1",
			"id=%d depth=%d err='%s'" % [id1, depth1, texto_erro])

	# 10) campo de tipo errado recusa -2 nomeada na superficie do prompt (a guardinha
	# da ponte), e o codigo e lido na linha do enqueue.
	var r_tipo := -99
	var texto_tipo := ""
	if tem_obj:
		r_tipo = int(obj.enqueue({"role": "user", "prompt": "ping", "max_tokens": "muito"}))
		texto_tipo = String(obj.prompt_err_text())
	_check(r_tipo == -2 and texto_tipo.contains("max_tokens"),
			"contrato: campo de tipo errado recusa -2 nomeada na superficie do prompt",
			"retorno=%d err='%s'" % [r_tipo, texto_tipo])

	# 11) papel fora do mapeamento recusa -4 na PORTA (nao so dentro da thread).
	var r_papel := -99
	var texto_papel := ""
	if tem_obj:
		r_papel = int(obj.enqueue({"role": "cozinheiro", "prompt": "ping"}))
		texto_papel = String(obj.prompt_err_text())
	_check(r_papel == -4 and texto_papel.contains("fora do mapeamento"),
			"contrato: papel fora do mapeamento recusa -4 na porta",
			"retorno=%d err='%s'" % [r_papel, texto_papel])

	# 12) os tres sinais do §5.3 existem na superficie da classe, lidos da ClassDB.
	var nomes_sinais: Array = []
	if tem_obj:
		for s in ClassDB.class_get_signal_list(classe, false):
			nomes_sinais.append(String(s["name"]))
	var tem_tres_sinais := nomes_sinais.has("inference_completed") \
			and nomes_sinais.has("pack_loaded") and nomes_sinais.has("pack_failed")
	_check(tem_tres_sinais, "contrato: os tres sinais do §5.3 estao na ClassDB",
			"sinais=%s" % [str(nomes_sinais)])

	# 13) a conexao e feita ANTES dos decodes: a contagem de emissoes que decide a
	# checagem 16 tem de estar armada antes de qualquer wait.
	_gate_emissoes = 0
	if tem_obj:
		obj.inference_completed.connect(
				func(_id: int, _saida: Dictionary) -> void: _gate_emissoes += 1)

	# 14) FORMA do wait de sucesso: as 6 chaves exatas de AfPromptOut com os tipos
	# delas, reason vazio e texto nao vazio. O prazo de 30 s e teto, nao medida.
	var out1 := {}
	if tem_obj:
		out1 = obj.wait(id1, 30000)
	var chaves1: Array = out1.keys()
	chaves1.sort()
	var forma_ok: bool = chaves1.size() == 6 \
			and typeof(out1.get("request_id", null)) == TYPE_INT \
			and typeof(out1.get("status", null)) == TYPE_INT \
			and typeof(out1.get("reason", null)) == TYPE_STRING \
			and typeof(out1.get("text", null)) == TYPE_STRING \
			and typeof(out1.get("decode_us", null)) == TYPE_INT \
			and typeof(out1.get("tokens_out", null)) == TYPE_INT
	var sucesso1 := forma_ok and int(out1.get("status", -99)) == 0 \
			and String(out1.get("reason", "?")) == "" and String(out1.get("text", "")) != ""
	_check(sucesso1,
			"contrato: FORMA do wait de sucesso (6 chaves tipadas, reason vazia, texto nao vazio)",
			"chaves=%s status=%s tokens_out=%s decode_us=%s reason='%s'" % [
				str(chaves1), str(out1.get("status", "?")), str(out1.get("tokens_out", "?")),
				str(out1.get("decode_us", "?")), String(out1.get("reason", ""))])

	# 15) FORMA do timeout: status 1, motivo nomeado, slot PRESERVADO (depth nao cai --
	# descartar no timeout seria perder trabalho pago).
	var id2 := -1
	if tem_obj:
		id2 = int(obj.enqueue({"role": "user", "prompt": MindOracle._prompt_narracao(_wolf),
				"max_tokens": 64, "temperature": 0.7}))
	var out2 := {}
	if tem_obj:
		out2 = obj.wait(id2, 1)
	var status2 := int(out2.get("status", -99))
	var reason2 := String(out2.get("reason", ""))
	var depth2 := int(obj.queue_depth()) if tem_obj else -1
	_check(status2 == 1 and reason2.begins_with("timeout") and depth2 >= 1,
			"contrato: FORMA do timeout (status 1, motivo nomeado, slot preservado)",
			"status=%d reason='%s' depth=%d" % [status2, reason2, depth2])

	# 16) o pedido que sofreu o timeout completa num wait seguinte com mais tempo:
	# e o mesmo slot, nao um pedido novo.
	var out2b := {}
	if tem_obj:
		out2b = obj.wait(id2, 30000)
	var status2b := int(out2b.get("status", -99))
	var tokens2b := int(out2b.get("tokens_out", -1))
	_check(status2b == 0 and tokens2b > 0,
			"contrato: o pedido que sofreu timeout completa no wait seguinte",
			"status=%d tokens_out=%d decode_us=%s" % [
				status2b, tokens2b, str(out2b.get("decode_us", "?"))])

	# 17) a emissao do sinal segue [ABERTA] e vai ESCRITA: conectado de verdade,
	# ZERO emissoes atraves dos dois decodes -- o header vendorado 4.7.2 nao traz
	# `object_emit_signal`, e quem emite e o Passo 4/5.
	_check(_gate_emissoes == 0,
			"contrato: a emissao do sinal segue [ABERTA] (quem emite e o Passo 4/5)",
			"emissoes=%d decodes=2" % _gate_emissoes)

	# 18) o GATE do sucesso, a forma IGUAL nas duas transportas: os campos comuns
	# text/reason com os mesmos tipos e a mesma semantica de vazio, e a extensao
	# so acrescenta os extras int {request_id, status, decode_us, tokens_out}.
	var extras_ok := forma_ok
	if extras_ok:
		for e in ["request_id", "status", "decode_us", "tokens_out"]:
			extras_ok = extras_ok and chaves1.has(e) \
					and typeof(out1.get(e, null)) == TYPE_INT
	var gate_sucesso := sucesso1 and narrativa != "" and razao_http == "" and extras_ok
	_check(gate_sucesso,
			"contrato: GATE do sucesso -- FORMA igual nas duas transportas",
			"reason_http='%s' reason_ext='%s' extras_int=%s textos=%d/%d chars" % [
				razao_http, String(out1.get("reason", "")), str(extras_ok),
				narrativa.length(), String(out1.get("text", "")).length()])

	# 19) FORMA da recusa da extensao: id desconhecido devolve o MESMO Dictionary de
	# 6 chaves com status negativo, motivo nomeado e texto vazio -- a forma nao muda
	# com o codigo.
	var outx := {}
	if tem_obj:
		outx = obj.wait(999999, 50)
	var statusx := int(outx.get("status", -99))
	var reasonx := String(outx.get("reason", ""))
	var textx := String(outx.get("text", "<ausente>"))
	_check(statusx < 0 and reasonx != "" and textx == "",
			"contrato: FORMA da recusa da extensao (id desconhecido: status<0, motivo nomeado, texto vazio)",
			"status=%d reason='%s'" % [statusx, reasonx])

	# 20) o GATE da recusa: texto vazio e motivo nomeado nas DUAS transportas.
	var gate_recusa := narrativa_401 == "" and razao_401 != "" \
			and statusx < 0 and reasonx != "" and textx == ""
	_check(gate_recusa,
			"contrato: GATE da recusa -- FORMA igual nas duas transportas",
			"reason_http_len=%d reason_ext_len=%d status_ext=%d" % [
				razao_401.length(), reasonx.length(), statusx])

	# 21) as metricas honestas da fila: a fila esvaziou pelos waits, o cache nao
	# existe no Passo 3 (hits 0 e misses = os 2 enqueues bem-sucedidos), o pior
	# decode e numero medido e a VRAM e a do contexto vivo.
	var depth_f := -1
	var hits := -1
	var misses := -1
	var worst := -1
	var vram := -1
	if tem_obj:
		depth_f = int(obj.queue_depth())
		hits = int(obj.cache_hits())
		misses = int(obj.cache_misses())
		worst = int(obj.worst_decode_us())
		vram = int(obj.vram_bytes())
	_check(depth_f == 0 and hits == 0 and misses == 2 and worst > 0 and vram > 0,
			"contrato: metricas honestas da fila (cache nao existe no Passo 3)",
			"depth=%d hits=%d misses=%d worst_decode_us=%d vram_bytes=%d" % [
				depth_f, hits, misses, worst, vram])

	# 22) o desmanche pelo pid exato do lancamento: mata, espera a morte com prazo e
	# confere `is_process_running` -- o orfao com a porta aberta e o defeito que o
	# dossie 15 §0.1 documentou.
	var derrubado := false
	if pid_subido > 0:
		OS.kill(pid_subido)
		var prazo_kill := Time.get_ticks_msec() + 5000
		while Time.get_ticks_msec() < prazo_kill and OS.is_process_running(pid_subido):
			await _gate_frame_sleep(100)
		derrubado = not OS.is_process_running(pid_subido)
		_af_server_pid = -1
	_check(derrubado or pid_subido <= 0,
			"contrato: desmanche pelo pid exato do lancamento (ou nada nosso foi levantado)",
			"pid=%d derrubado=%s reuso=%s" % [pid_subido, str(derrubado), str(nosso_reuso)])

	# O objeto e RefCounted (PARENT_NAME da ponte): quem solta e o refcount quando a
	# corotina sai, nunca um free() a mao. O nodo HTTP do cliente de referencia
	# sai da arvore; nao ha mais oraculo nenhum montado pelo gate (§5.4).
	http.queue_free()
	return true


## POST do cliente de referencia do gate: a mesma disciplina do GET sequencial --
## `await` so acontece com a requisicao aceita, e o `timeout` do nodo garante que
## ela sempre completa.
func _gate_http_post(http: HTTPRequest, url_post: String, cabecalhos: PackedStringArray,
		corpo: String, tempo_s: float) -> Array:
	http.timeout = tempo_s
	var err := http.request(url_post, cabecalhos, HTTPClient.METHOD_POST, corpo)
	if err != OK:
		return [-1, 0, PackedStringArray(), PackedByteArray()]
	return await http.request_completed


## Passo 4 do dossie 22 (§5.4) -- o gate `transporte_http_zerado`, que e a frase do
## dono virada checagem: `grep -rn HTTPRequest src` devolve VAZIO quando o
## `mind_oracle.gd` ja fala com a extensao (`AfMindOracle.enqueue`/`wait`) e o host
## HTTP saiu da cena pelo braco do §6.3. Nasce VERMELHO de proposito: enquanto o
## wrapper nao existir, a varredura imprime ARQUIVO:LINHA de cada ocorrencia, e o
## vermelho aponta o que sobra em vez de so contar. A segunda premissa do §5.4/§6.3
## (o `Rodar.bat` nao levanta processo nenhum de IA) e checada pelos dois
## lancadores sem a palavra "llama" -- fechamento da perna 15, sem tocar neles.
## A varredura e feita aqui com DirAccess/FileAccess e NAO com um subprocesso de
## grep: o instrumento roda em qualquer clone Windows sem shell externo.
func _test_transporte_http_zerado() -> bool:
	# (i) a frase do dono, literal: nenhuma ocorrencia de "HTTPRequest" em nenhum
	# .gd sob res://src (arvore recursiva, arquivos ocultos excluidos).
	var ocorrencias: PackedStringArray = []
	var arquivos_lidos: PackedStringArray = []
	var fila: Array[String] = ["res://src"]
	while not fila.is_empty():
		var caminho_dir: String = fila.pop_back()
		var dir := DirAccess.open(caminho_dir)
		if dir == null:
			continue
		dir.list_dir_begin()
		var nome := dir.get_next()
		while nome != "":
			var caminho := caminho_dir.path_join(nome)
			if dir.current_is_dir():
				if not nome.begins_with("."):
					fila.append(caminho)
			elif nome.ends_with(".gd"):
				arquivos_lidos.append(caminho)
				var f := FileAccess.open(caminho, FileAccess.READ)
				if f != null:
					var num := 0
					while not f.eof_reached():
						num += 1
						var linha := f.get_line()
						if linha.contains("HTTPRequest"):
							ocorrencias.append("%s:%d" % [caminho, num])
					f.close()
			nome = dir.get_next()
		dir.list_dir_end()
	var detalhe := "arquivos_lidos=%d ocorrencias=%d %s" % [arquivos_lidos.size(),
			ocorrencias.size(), " ".join(ocorrencias) if not ocorrencias.is_empty()
			else "(vazio)"]
	_check(ocorrencias.is_empty(),
			"transporte_http_zerado: grep -rn HTTPRequest src devolve vazio",
			detalhe)
	# (ii) nenhuma IA fora da engine: os dois lancadores sobem o jogo e NADA de
	# llama -- o host HTTP aposentado pelo §6.3 nao pode deixar rastro no boot.
	var lancadores := {"Rodar.bat": false, "tools/run_game.ps1": false}
	for lancador in lancadores.keys():
		var f := FileAccess.open(String(lancador), FileAccess.READ)
		var conteudo := f.get_as_text() if f != null else ""
		lancadores[lancador] = f != null and not conteudo.to_lower().contains("llama")
	var sem_ia := true
	for lancador in lancadores.keys():
		sem_ia = sem_ia and bool(lancadores[lancador])
	_check(sem_ia,
			"transporte_http_zerado: os lancadores nao citam llama (nenhum processo de IA)",
			str(lancadores))
	return true


## Passo 5 do dossie 22 (§5.5/§6.5) -- o gate `af_cache_determina_replay`, que e a
## frase do dono virada checagem: a mesma semente duas vezes, com o modelo
## DESLIGADO na segunda, devolve a MESMA frase. A cache do oraculo (§6.5) e
## `hash(prompt ⊕ pack ⊕ params) -> resposta` em ARQUIVO separado do save, lido
## antes de inferir -- "cache nao e memoria: e determinismo de CI" (o §7.3 fecha o
## terceiro lado do contrato do journal: com cache, o texto tem de ser o mesmo).
## Duas corridas pelo WRAPPER real: na A o modelo decoda (pack na ponte DO PROPRIO
## oraculo, pela rota medida do passo 2 (b)); na B um oraculo NOVO tem de servir a
## mesma frase sem consultar a fila nenhuma vez (`pedidos == 0` e o numero que
## decide -- e a unica forma de "modelo desligado" que a ponte oferece, porque o
## estado do pack e do PROCESSO e nao existe rota de descarga). Nasce VERMELHO de
## proposito: enquanto a cache nao existir, a corrida B nao tem de onde tirar a
## frase senao da fila, e o vermelho imprime `pedidos_b=1` -- a consulta que a
## cache existe para nao pagar. As premissas de disco nascem vermelhas num clone
## sem runtime/gguf (gitignored), no padrao do passo 2 (b). Os dois oraculos do
## gate ficam FORA da arvore e o ciclo deles e dirigido a mao (`_ready` chamado
## uma vez, `_process` so quando o gate chama): nenhum frame da engine dispara
## pedido fora da janela medida, e o roster e um metodo do proprio gate.
func _test_af_cache_determina_replay() -> bool:
	var classe := &"AfMindOracle"
	if not ClassDB.class_exists(classe):
		_check(false, "af_cache_determina_replay: a classe do esqueleto nao esta na ClassDB",
				"class_exists(%s)=false -- o passo 1 nao fechou nesta arvore" % String(classe))
		return true
	var runtime_dir := ProjectSettings.globalize_path("res://.tools/llama/runtime")
	var gguf := ProjectSettings.globalize_path("res://models/qwen3.5-4b-q4_k_m.gguf")
	# O arquivo da cache e do gate: caminho proprio, removido ANTES da corrida A
	# para a existencia medida no fim ser escrita POR ESTA corrida, nunca por uma
	# corrida anterior que deixou lixo (o determinismo do vermelho depende disso).
	var caminho_cache := "user://oracle_cache_passo5.json"
	var caminho_cache_abs := ProjectSettings.globalize_path(caminho_cache)
	if FileAccess.file_exists(caminho_cache):
		DirAccess.remove_absolute(caminho_cache_abs)
	var tem_llama := FileAccess.file_exists(runtime_dir + "/llama.dll")
	var tem_gguf := FileAccess.file_exists(gguf)
	_check(tem_llama and tem_gguf, "af_cache_determina_replay: runtime e gguf no disco",
			"runtime=%s gguf=%s llama_dll=%s" % [runtime_dir, gguf, str(tem_llama)])
	_arm()
	# Corrida A -- o modelo LIGADO. O estado do pack e do processo (a ponte reusa
	# o unico contexto dele), e a rota de carga nao tem descarga (o ponteiro do
	# modelo e substituido sem free em `af_pack_load`), entao o gate CARREGA so se
	# o processo ainda nao esta no estado de fila -- recarregar por reforco seria
	# pagar o load de novo e crescer memoria sem rota de volta.
	var o1 := MindOracle.new()
	o1._ready()
	# A corrida A e a que ALIMENTA a cache: com o caminho ligado (§6.5), o `_poll`
	# do wrapper grava a frase aceita sob a chave de conteudo no arquivo separado
	# do save — narrativa recusada ou vazia nunca entra.
	o1.set_cache_path(caminho_cache)
	var ext_a := o1.ext()
	var vivo_a := is_instance_valid(ext_a)
	var estado_a := int(ext_a.pack_state()) if vivo_a else -1
	var carregou := false
	if vivo_a and estado_a != 4 and tem_gguf:
		int(ext_a.set_runtime_dir(runtime_dir))
		int(ext_a.load_pack("", ""))
		int(ext_a.load_pack(MindOracle.MODEL_ALIAS, gguf))
		int(ext_a.ctx_probe(2048))
		carregou = true
		estado_a = int(ext_a.pack_state())
	_check(estado_a == 4,
			"af_cache_determina_replay: o pack do wrapper chega ao estado de fila (4)",
			"estado=%d carregou=%s gguf=%s err='%s'" % [estado_a, str(carregou),
				str(tem_gguf), String(ext_a.err_text()) if vivo_a else "sem ponte"])
	# O roster e o do gate: o lobo armado, estavel. O prompt dele e reconstruido
	# DEPOIS do decode e tem de ser identico -- a chave da cache (§6.5) e de
	# conteudo, e a igualdade entre as corridas e o que faz a chave valer.
	o1.roster_provider = Callable(self, "_gate_roster_solo")
	var prompt_a := MindOracle._prompt_narracao(_wolf)
	var prazo_a := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < prazo_a and o1.narration_of(_wolf.identity) == "":
		o1._process(0.05)
		await _gate_frame_sleep(50)
	var frase_a := o1.narration_of(_wolf.identity)
	_check(frase_a != "" and o1.requests_issued == 1,
			"af_cache_determina_replay: a corrida A narra pelo wrapper com o modelo no processo",
			"frase_a=%d chars pedidos=%d status=%d motivo='%s'" % [
				frase_a.length(), o1.requests_issued, o1.last_status, o1.last_reason])
	var prompt_b := MindOracle._prompt_narracao(_wolf)
	_check(prompt_a == prompt_b and prompt_a.length() > 0,
			"af_cache_determina_replay: a chave de conteudo e estavel entre as corridas",
			"prompt_a=%d chars prompt_b=%d chars iguais=%s" % [
				prompt_a.length(), prompt_b.length(), str(prompt_a == prompt_b)])
	# A cache em arquivo separado do save, escrita pela corrida A (§6.5) pelo
	# `_poll` do wrapper. Nasceu VERMELHO (commit do vermelho do passo 5): nesta
	# arvore nada escrevia o arquivo antes do `oracle_cache`.
	var cache_em_disco := FileAccess.file_exists(caminho_cache)
	_check(cache_em_disco,
			"af_cache_determina_replay: a cache ficou em arquivo separado do save",
			"caminho=%s existe=%s -- premissa do §6.5: hash de conteudo -> resposta, em arquivo" % [
				caminho_cache, str(cache_em_disco)])
	# A LEITURA e a outra metade do §6.5 ("lida antes de inferir"): uma instancia
	# FRESCA, que so conhece o arquivo, reconstrói a chave de conteudo do prompt da
	# corrida A e devolve a MESMA frase — e o que o replay de CI consome sem o
	# modelo no processo. A chave aqui e a MESMA formula do wrapper
	# (prompt ⊕ pack ⊕ params), reconstruida de fora.
	var cache_fresco := OracleCache.new(caminho_cache)
	var chave_a := OracleCache.chave(prompt_a, MindOracle.MODEL_ALIAS,
			MindOracle.PROMPT_MAX_TOKENS, MindOracle.PROMPT_TEMPERATURE)
	var lida := cache_fresco.le(chave_a)
	_check(lida == frase_a,
			"af_cache_determina_replay: uma instancia fresca le a frase do ARQUIVO pela chave de conteudo",
			"chave=%s lida=%d chars frase_a=%d chars entradas=%d err='%s'" % [
				chave_a.substr(0, 16), lida.length(), frase_a.length(),
				cache_fresco.tamanho(), cache_fresco.ultimo_erro])
	# Corrida B -- a segunda semente, SEM consulta ao modelo: oraculo novo, ponte
	# propria, roster do mesmo lobo. `pedidos == 0` decide: sem a cache lida antes
	# de inferir, o wrapper so tem o caminho da fila (e o vermelho imprime a
	# consulta que nao devia existir).
	var o2 := MindOracle.new()
	o2._ready()
	# A corrida B e a que CONSOME a cache: com o caminho ligado, o `_process` le
	# o arquivo ANTES dos portoes (§6.5 — "lida antes de inferir") e serve a frase
	# sem tocar a fila.
	o2.set_cache_path(caminho_cache)
	o2.roster_provider = Callable(self, "_gate_roster_solo")
	var prazo_b := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < prazo_b and o2.requests_issued == 0 \
			and o2.narration_of(_wolf.identity) == "":
		o2._process(0.05)
	while Time.get_ticks_msec() < prazo_b and o2.narration_of(_wolf.identity) == "":
		o2._process(0.05)
		await _gate_frame_sleep(50)
	var narr_b := o2.narration_of(_wolf.identity)
	_check(narr_b == frase_a and o2.requests_issued == 0 and o2.cache_hits == 1,
			"af_cache_determina_replay: a segunda corrida devolve a MESMA frase sem consultar a fila",
			"frase_a=%d chars narr_replay=%d chars igual=%s pedidos_b=%d acertos_cache=%d motivo_b='%s'" % [
				frase_a.length(), narr_b.length(), str(narr_b == frase_a),
				o2.requests_issued, o2.cache_hits, o2.last_reason])
	o1.free()
	o2.free()
	return true


## Passo 5 do dossie 22 (§6.4/§7.1) -- a checagem `verifier_recusa_id_forjado`.
## O mandato 2 ("mente propoe, regras dispoe") hoje e sustentado por AUSENCIA de
## caminho: nao existe conector entre o oraculo e a intencao. Com o modelo no
## MESMO heap, ausencia de caminho deixa de ser prova -- "o argumento de que ele
## nao tem para onde escrever e mais fraco quando ele e um objeto no mesmo heap"
## (§6.4). Entao o contrato ganha um verificador nomeado (`BeliefVerifier`) na
## fronteira da Camada 5: a saida que nomeia um `entity_id` que nao existe na
## alcateia nao pode produzir narrativa, crenca nem intencao. Nasceu VERMELHO
## enquanto o verificador nao existia em src/ai (commit do vermelho do passo 5);
## o fechamento e o portao de aceite no wrapper (`aceitar_saida`, a rota que o
## `_poll` passa a usar), com o controle primeiro -- o portao nao e um filtro que
## recusa tudo. O roster do gate e um lobo minimo de prova (so `.identity`), e o
## recuso fail closed: roster vazio recusa qualquer citacao.
func _test_verifier_recusa_id_forjado() -> bool:
	var caminho := "res://src/ai/belief_verifier.gd"
	var existe := FileAccess.file_exists(caminho)
	_check(existe,
			"verifier_recusa_id_forjado: o verificador nomeado existe na fronteira da Camada 5",
			"caminho=%s existe=%s -- premissa do §6.4: mesmo heap, ausencia de caminho nao e prova" % [
				caminho, str(existe)])
	if not existe:
		return true
	# O controle no verificador: a saida que so cita id do roster PASSA.
	var v := BeliefVerifier.new()
	var id_valido := 11
	var controle := v.aceitar("O lobo %d fareja o vento e acha o rastro." % id_valido, [id_valido])
	_check(controle and v.ultimo_id_forjado == -1,
			"verifier_recusa_id_forjado: o controle passa -- saida que so cita id do roster e aceita",
			"aceito=%s id_forjado=%d motivo='%s'" % [
				str(controle), v.ultimo_id_forjado, v.ultimo_motivo])
	# A forja: o id 999 nao existe no roster [11] -- e a recusa NOMEIA o numero,
	# que e o que decide no log e na checagem.
	var forjado := v.aceitar("O lobo 999 uiva para a matilha.", [id_valido])
	_check(not forjado and v.ultimo_id_forjado == 999 and v.ultimo_motivo.contains("999"),
			"verifier_recusa_id_forjado: a saida com id forjado e recusada e o numero e NOMEADO",
			"aceito=%s id_forjado=%d motivo='%s'" % [
				str(forjado), v.ultimo_id_forjado, v.ultimo_motivo])
	# O portao NO WRAPPER (a rota que o `_poll` usa): recusa = sem narrativa, sem
	# escrita nenhuma, e o motivo do wrapper e o do verificador.
	var o := MindOracle.new()
	o._ready()
	o.roster_provider = Callable(self, "_gate_roster_prova")
	var recusado := o.aceitar_saida(7, "O lobo 999 uiva para a matilha.")
	_check(not recusado and o.narration_of(7) == "" and o.last_reason.contains("999"),
			"verifier_recusa_id_forjado: o portao do wrapper recusa o id forjado sem escrever narrativa",
			"aceito=%s narrativa=%d chars motivo='%s'" % [
				str(recusado), o.narration_of(7).length(), o.last_reason])
	# E o controle pelo MESMO portao: saida valida entra, vira narrativa e dispara
	# o sinal que a Fase 5 (MindsInspector) consume.
	var sinal := [false]
	o.narration_ready.connect(func(_id: int, _t: String) -> void: sinal[0] = true)
	var texto_valido := "O lobo %d fareja o vento e acha o rastro." % id_valido
	var aceito := o.aceitar_saida(7, texto_valido)
	_check(aceito and o.narration_of(7) == texto_valido and sinal[0],
			"verifier_recusa_id_forjado: o portao do wrapper aceita o controle e escreve a narrativa",
			"aceito=%s narrativa=%d chars sinal=%s" % [
				str(aceito), o.narration_of(7).length(), str(sinal[0])])
	o.free()
	return true


## Passo 5 do dossie 22 (§5.5) -- o gate `budget_do_oraculo_nao_estoura_a_arvore`.
## A regra de bolso do contrato: o que vai em `_sim_tick` divide os 50 ms do passo
## com a matilha do momento. O Passo 5 poe o decode do modelo NO MESMO processo da
## simulacao, entao a regua do passo (25 ms, a mesma do `espalhamento`) tem de ser
## medida com o decode EM VOO dentro da malha: 1 400 passos da matilha real de
## cinco bichos, com o `_process` do wrapper DENTRO do bracket do relogio (o poll
## nao bloqueia -- `wait(id, 0)`, timeout zero e consulta nao bloqueante -- e o
## custo dele e do passo, nao de um frame fora da conta), e o `SubtreeGuard` de
## 400 us (src/entities/wolf.gd:448-449) sem estouro nenhum. O corte por
## prioridade, se um dia for preciso, vem DEPOIS do numero, nunca antes: "o numero
## primeiro, o orcamento depois". Num clone sem runtime/gguf (gitignored) as
## premissas nascem vermelhas com o caminho impresso, e a regua sem decode em voo
## nao mede o que o gate nomeia -- a checagem exige narradas >= 1 para valer.
func _test_budget_do_oraculo_nao_estoura_a_arvore() -> bool:
	var classe := &"AfMindOracle"
	if not ClassDB.class_exists(classe):
		_check(false, "budget_do_oraculo: a classe do esqueleto nao esta na ClassDB",
				"class_exists(%s)=false -- o passo 1 nao fechou nesta arvore" % String(classe))
		return true
	var runtime_dir := ProjectSettings.globalize_path("res://.tools/llama/runtime")
	var gguf := ProjectSettings.globalize_path("res://models/qwen3.5-4b-q4_k_m.gguf")
	var tem_llama := FileAccess.file_exists(runtime_dir + "/llama.dll")
	var tem_gguf := FileAccess.file_exists(gguf)
	_arm()
	_boot_session(int(Session.WOLF_COUNT))
	var s: Session = _session
	# O oraculo do cenario: o mesmo conjunto que o boot real monta (§6.3 -- wrapper
	# com roster da sessao e pack na ponte dele), dirigido a mao e fora da arvore,
	# porque o runner headless nao tem dono de pack. O estado do pack e do
	# processo e nao existe rota de descarga: carrega so se o estado ainda nao e 4.
	var o := MindOracle.new()
	o._ready()
	var ext_o := o.ext()
	var vivo_o := is_instance_valid(ext_o)
	var estado_o := int(ext_o.pack_state()) if vivo_o else -1
	var carregou := false
	if vivo_o and estado_o != 4 and tem_gguf:
		int(ext_o.set_runtime_dir(runtime_dir))
		int(ext_o.load_pack("", ""))
		int(ext_o.load_pack(MindOracle.MODEL_ALIAS, gguf))
		int(ext_o.ctx_probe(2048))
		carregou = true
		estado_o = int(ext_o.pack_state())
	_check(tem_llama and tem_gguf and estado_o == 4,
			"budget_do_oraculo: runtime, gguf e pack no estado de fila (4)",
			"runtime=%s gguf=%s estado=%d carregou=%s err='%s'" % [
				str(tem_llama), str(tem_gguf), estado_o, str(carregou),
				String(ext_o.err_text()) if vivo_o else "sem ponte"])
	o.roster_provider = Callable(s, "wolves_roster")
	var trips_antes := 0
	for w: Wolf in _pack_wolves():
		trips_antes += int(w._guard.trips)
	var tick0 := int(s.diagnostics()["tick"])
	var total_us := 0
	var pico_us := 0
	var passos := 0
	while passos < 1400:
		passos += 1
		var t0 := Time.get_ticks_usec()
		s.clock.begin_step()
		s._sim_tick()
		# O poll do oraculo DENTRO do bracket: e o que o Passo 5 poe do lado de la
		# do relogio com a matilha -- dividir os 50 ms e o contrato que o gate
		# mede, e um poll fora do bracket seria medir a regua de mentira.
		o._process(SimClock.STEP)
		s.clock.end_step()
		var cost := Time.get_ticks_usec() - t0
		total_us += cost
		pico_us = maxi(pico_us, cost)
		for w: Wolf in _pack_wolves():
			for frame: int in 3:
				w._physics_process(SimClock.STEP / 3.0)
	var d: Dictionary = s.diagnostics()
	# O desmanche nao deixa decode em voo: o round-robin pode ter enfileirado o
	# proximo pedido nos ultimos passos, e sair do processo com a thread dele
	# rodando derruba o desligamento da engine com segfault (medido na primeira
	# corrida do vermelho: o rodape saiu e o quit virou 139). O prazo e teto.
	var prazo_dreno := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < prazo_dreno and o._busy:
		o._process(0.05)
		await _gate_frame_sleep(50)
	var trips_depois := 0
	var narradas := 0
	for w: Wolf in _pack_wolves():
		trips_depois += int(w._guard.trips)
		if o.narration_of(w.identity) != "":
			narradas += 1
	var worst_us := int(ext_o.worst_decode_us()) if vivo_o else -1
	var media_us := float(total_us) / float(maxi(passos, 1))
	_check(int(d["tick"]) - tick0 == 1400,
			"budget_do_oraculo: premissa da malha medida",
			"passos=%d tick0=%d->%d matilha=%d" % [
				passos, tick0, int(d["tick"]), _pack_wolves().size()])
	_check(narradas >= 1 and worst_us > 0
			and float(d["worst_sim_ms"]) <= 25.0 and pico_us <= 25000,
			"budget_do_oraculo_nao_estoura_a_arvore",
			"narradas=%d/%d pedidos=%d worst_decode_us=%d | worst_sim_ms=%.2f ms pico_do_passo=%d us media=%.1f us/passo total=%d us em %d passos" % [
				narradas, _pack_wolves().size(), o.requests_issued, worst_us,
				float(d["worst_sim_ms"]), pico_us, media_us, total_us, passos])
	_check(trips_depois == trips_antes and narradas >= 1,
			"budget_do_oraculo: o SubtreeGuard de 400 us nao estoura com o decode em voo",
			"trips_antes=%d trips_depois=%d narradas=%d" % [trips_antes, trips_depois, narradas])
	o.free()
	_pack_release()
	return true


## Comparacao valor a valor de duas janelas de crencas: nao depende da igualdade
## profunda de Array do GDScript e falha ao primeiro elemento diferente — o que
## importa e a ORDEM, entao o auxiliar nao ordena nada antes de comparar.
func _arrays_iguais(a, b) -> bool:
	if not (a is Array) or not (b is Array):
		return false
	var aa: Array = a
	var bb: Array = b
	if aa.size() != bb.size():
		return false
	for i in aa.size():
		if aa[i] != bb[i]:
			return false
	return true


## Fase 2 do dossie 22 (§20.5) -- a premissa `selecao_de_beliefs_e_pura_no_estado`.
## Hoje o prompt do oraculo imprime TODAS as crencas na ordem do dicionario
## (laco do `_prompt_for`); a Fase 2 troca isso por uma janela top-k
## deterministica — e a selecao muda o prompt, o prompt muda a chave de conteudo
## da cache (§6.5), entao a selecao tem de ser PURA no estado da mente: mesmo
## estado -> mesma janela -> mesmo prompt -> mesma chave de cache, senao a cache
## fixa memoria velha no replay. Pura aqui e comportamento observavel: a mesma
## entrada em instantes diferentes da parede devolve a mesma saida — nenhum
## relogio, aleatoriedade ou identidade de fora pode derivar o conjunto. O
## desempate e TOTAL (confianca -> vezes -> visto -> chave), porque o dicionario
## do Godot e ordenado pela insercao: uma ordenacao com resto devolveria duas
## janelas diferentes para o mesmo estado, e o replay seria sorteio.
func _test_selecao_de_beliefs_e_pura_no_estado() -> bool:
	# A sonda e uma instancia do proprio wrapper: has_method numa instancia ve
	# metodos estaticos (sonda da Fase 2), e a chamada estatica entra por
	# `.call()` — no vermelho o metodo nao existe e o vermelho e NOMEADO aqui,
	# sem SCRIPT ERROR derrubando o censo.
	var sonda := MindOracle.new()
	var tem_janela: bool = sonda.has_method("_janela_crencas")
	_check(tem_janela,
			"selecao_de_beliefs_e_pura: a janela de crencas existe no wrapper",
			"janela=%s k=%d -- premissa do §20.5: top-k deterministico no prompt" % [
				str(tem_janela), K_JANELA_PROVA])
	if not tem_janela:
		sonda.free()
		return true
	# (2) Mesmo estado, duas ordens de insercao, mesma janela: a materia e
	# identica e so a ordem de insercao difere — uma ordenacao sem desempate
	# total falha aqui.
	var estado_a := {
		"b_beta": {"confidence": 0.5, "source": "testemunha", "visto_em": 10, "vezes": 1},
		"a_alfa": {"confidence": 0.5, "source": "testemunha", "visto_em": 10, "vezes": 1},
		"c_gama": {"confidence": 0.9, "source": "testemunha", "visto_em": 10, "vezes": 1},
	}
	var estado_b := {
		"c_gama": {"confidence": 0.9, "source": "testemunha", "visto_em": 10, "vezes": 1},
		"a_alfa": {"confidence": 0.5, "source": "testemunha", "visto_em": 10, "vezes": 1},
		"b_beta": {"confidence": 0.5, "source": "testemunha", "visto_em": 10, "vezes": 1},
	}
	var janela_a: Array = sonda.call("_janela_crencas", estado_a)
	var janela_b: Array = sonda.call("_janela_crencas", estado_b)
	_check(_arrays_iguais(janela_a, janela_b) and janela_a.size() == 3,
			"selecao_de_beliefs_e_pura: o mesmo estado em duas ordens de insercao devolve a mesma janela",
			"a=%s b=%s" % [str(janela_a), str(janela_b)])
	# (3) O relogio da parede avanca e a janela NAO deriva: duas leituras do
	# mesmo estado separadas por >= 60 ms MEDIDOS de parede — uma janela que
	# lesse o relogio (ou tick de fora) derivaria no intervalo.
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() < t0 + 60:
		await process_frame
	var decorrido := Time.get_ticks_msec() - t0
	var janela_depois: Array = sonda.call("_janela_crencas", estado_a)
	_check(_arrays_iguais(janela_a, janela_depois) and decorrido >= 60,
			"selecao_de_beliefs_e_pura: a janela nao deriva com o relogio da parede",
			"igual=%s espera=%d ms" % [
				str(_arrays_iguais(janela_a, janela_depois)), decorrido])
	# (4) A janela corta em k (copia literal `K_JANELA_PROVA`) e a melhor
	# confianca entra primeiro: doze crencas com confianca crescente, k na
	# janela, o topo e a maior.
	var estado_grande := {}
	for i in 12:
		estado_grande["crenca_%02d" % i] = {
			"confidence": 0.3 + 0.01 * i, "source": "testemunha",
			"visto_em": i, "vezes": 1}
	var janela_grande: Array = sonda.call("_janela_crencas", estado_grande)
	_check(janela_grande.size() == K_JANELA_PROVA and String(janela_grande[0]) == "crenca_11",
			"selecao_de_beliefs_e_pura: a janela corta em k com a melhor confianca primeiro",
			"tamanho=%d primeiro=%s k=%d" % [
				janela_grande.size(), str(janela_grande[0]), K_JANELA_PROVA])
	# (5) O desempate corre confianca -> vezes -> visto -> chave, exercido rung a
	# rung: c_gama ganha por confianca; d_delta e f_fi empatam em tudo e a chave
	# decide (d < f); a_alfa vence b_beta por vezes; e_eps perde por confianca.
	var estado_empate := {
		"e_eps": {"confidence": 0.30, "source": "s", "visto_em": 100, "vezes": 5},
		"c_gama": {"confidence": 0.90, "source": "s", "visto_em": 10, "vezes": 1},
		"b_beta": {"confidence": 0.50, "source": "s", "visto_em": 10, "vezes": 1},
		"a_alfa": {"confidence": 0.50, "source": "s", "visto_em": 10, "vezes": 3},
		"d_delta": {"confidence": 0.50, "source": "s", "visto_em": 20, "vezes": 3},
		"f_fi": {"confidence": 0.50, "source": "s", "visto_em": 20, "vezes": 3},
	}
	var esperado := ["c_gama", "d_delta", "f_fi", "a_alfa", "b_beta", "e_eps"]
	var janela_empate: Array = sonda.call("_janela_crencas", estado_empate)
	_check(_arrays_iguais(janela_empate, esperado),
			"selecao_de_beliefs_e_pura: o desempate corre confianca, vezes, visto e chave",
			"janela=%s esperado=%s" % [str(janela_empate), str(esperado)])
	# (6) O consumidor: dois corpos de prova com o MESMO estado da mente e o
	# MESMO corpo produzem o MESMO prompt byte a byte — e a igualdade que faz a
	# chave de conteudo da cache (§6.5) valer entre as corridas do replay.
	var p1 := _LoboProvaMind.new(5)
	var p2 := _LoboProvaMind.new(5)
	var estado_prova := {
		"danger_from_actor_1": {"confidence": 0.8, "source": "testemunha",
			"visto_em": 12, "vezes": 1},
		"player_visible_recent": {"confidence": 0.5, "source": "consolidated",
			"visto_em": 10, "vezes": 2},
	}
	p1.mind.beliefs = estado_prova
	p2.mind.beliefs = estado_prova.duplicate(true)
	var prompto_1 := MindOracle._prompt_narracao(p1)
	var prompto_2 := MindOracle._prompt_narracao(p2)
	_check(prompto_1 == prompto_2 and prompto_1.length() > 0,
			"selecao_de_beliefs_e_pura: o mesmo estado da mente produz o mesmo prompt",
			"prompto=%d chars igual=%s" % [prompto_1.length(), str(prompto_1 == prompto_2)])
	sonda.free()
	return true


## Fase 2 do dossie 22 (§20.5) -- a premissa
## `qualidade_nao_aparece_na_projecao_do_journal`. A memoria de qualidade poe
## dois numeros em cada crenca: `visto_em` (o ultimo tick que CONFIRMOU a
## crenca — reforco negativo contesta, nao confirma) e `vezes` (quantos toques
## de reinforce ela tomou). O par anti-farsa da premissa: a projecao do
## TickJournal le so (chave, confidence, source) por crenca, entao a metadata
## nova NAO pode mover um state_hash — e o controle move o hash ao mudar
## confidence, provando que o instrumento nao e cego. O disco existe para a
## qualidade sobreviver ao save/load: `to_dict` grava os quatro campos e
## `from_dict` devolve, com o source de volta "loaded" (o load nao e testemunha).
func _test_qualidade_nao_aparece_na_projecao_do_journal() -> bool:
	# (1) A metadata existe na crenca que o reinforce acabou de tocar. No
	# vermelho o dict tem so confidence e source — o vermelho e NOMEADO aqui,
	# sem chamar assinatura que ainda nao existe.
	var m := Mind.new()
	m.reinforce("crenca_prova", 0.5, "testemunha")
	var b = m.beliefs.get("crenca_prova")
	var visto_txt := "sem crenca"
	var vezes_txt := "sem crenca"
	if b != null:
		visto_txt = str((b as Dictionary).get("visto_em", "ausente"))
		vezes_txt = str((b as Dictionary).get("vezes", "ausente"))
	var tem_qualidade := b != null and (b as Dictionary).has("visto_em") \
			and (b as Dictionary).has("vezes")
	_check(tem_qualidade,
			"qualidade_na_projecao: a crenca carrega visto_em e vezes",
			"visto_em=%s vezes=%s -- premissa do §20.5: metadata de qualidade na crenca" % [
				visto_txt, vezes_txt])
	if not tem_qualidade:
		return true
	# (2) O carimbo segue o tick que CONFIRMOU: reforco negativo contesta —
	# conta em `vezes`, mas nao carimba `visto_em` — e todo toque soma. A
	# assinatura de 4 args e sondada por `get_method_list` (a sonda da Fase 2
	# mediu o shape) e as chamadas entram por `.call()`: no vermelho a
	# assinatura ainda nao existe e o parse do GDScript recusa chamada direta
	# com 4 args — o vermelho tem de ser checagem nomeada, nunca SCRIPT ERROR.
	var tem_assinatura := false
	for minfo in m.get_method_list():
		if String(minfo.get("name", "")) == "reinforce" \
				and (minfo.get("args", []) as Array).size() >= 4:
			tem_assinatura = true
			break
	var carimbou := false
	var manteve := false
	var contou_neg := false
	var recarimbou := false
	var contou := false
	if tem_assinatura:
		var m2 := Mind.new()
		m2.call("reinforce", "fato_prova", 0.4, "testemunha", 777)
		var b2 = m2.beliefs.get("fato_prova")
		if b2 != null:
			var d2: Dictionary = b2
			carimbou = int(d2.get("visto_em", -2)) == 777
			m2.call("reinforce", "fato_prova", -0.1, "testemunha", 888)
			manteve = int(d2.get("visto_em", -2)) == 777
			contou_neg = int(d2.get("vezes", -1)) == 2
			m2.call("reinforce", "fato_prova", 0.3, "testemunha", 999)
			recarimbou = int(d2.get("visto_em", -2)) == 999
			contou = int(d2.get("vezes", -1)) == 3
	_check(tem_assinatura and carimbou and manteve and contou_neg and recarimbou and contou,
			"qualidade_na_projecao: o reinforce carimba o tick que confirmou e conta todo toque",
			"assinatura4=%s carimbo=%s manteve_no_negativo=%s contou_negativo=%s recarimbo=%s vezes3=%s" % [
				str(tem_assinatura), str(carimbou), str(manteve), str(contou_neg),
				str(recarimbou), str(contou)])
	if not (tem_assinatura and carimbou and manteve and contou_neg and recarimbou and contou):
		return true
	# (3) O decay preserva a metadata enquanto a crenca vive: um minuto de decay
	# nao derruba a confianca abaixo do minimo e o carimbo segue la. Quando a
	# confianca morre, a crenca INTEIRA sai do dicionario — o esquecimento nao
	# deixa metadata orfa.
	var m3 := Mind.new()
	m3.call("reinforce", "fato_decay", 0.6, "testemunha", 500)
	m3.decay(1.0)
	var b3 = m3.beliefs.get("fato_decay")
	var conf_txt := "-1.0"
	if b3 != null:
		conf_txt = "%.4f" % float((b3 as Dictionary).get("confidence", 0.0))
	var decay_preserva := b3 != null \
			and float((b3 as Dictionary).get("confidence", 0.0)) > Mind.CONFIDENCE_MIN \
			and int((b3 as Dictionary).get("visto_em", -2)) == 500 \
			and int((b3 as Dictionary).get("vezes", -1)) == 1
	_check(decay_preserva,
			"qualidade_na_projecao: o decay preserva visto_em e vezes enquanto a crenca vive",
			"conf=%s visto=%d vezes=%d" % [conf_txt,
				int((b3 as Dictionary).get("visto_em", -2)) if b3 != null else -2,
				int((b3 as Dictionary).get("vezes", -1)) if b3 != null else -1])
	# (4) O disco: to_dict grava os quatro campos e from_dict devolve — a
	# qualidade sobrevive ao save/load. O source volta "loaded" porque o load
	# nao e testemunha (politica nomeada do from_dict).
	var d := m3.to_dict()
	var m4 := Mind.new()
	m4.from_dict(d)
	var b4 = m4.beliefs.get("fato_decay")
	var disco_sobrevive := b4 != null \
			and is_equal_approx(float((b4 as Dictionary).get("confidence", 0.0)),
					float((m3.beliefs["fato_decay"] as Dictionary)["confidence"])) \
			and String((b4 as Dictionary).get("source", "")) == "loaded" \
			and int((b4 as Dictionary).get("visto_em", -2)) == 500 \
			and int((b4 as Dictionary).get("vezes", -1)) == 1
	var disco_txt := "ausente"
	if b4 != null:
		disco_txt = "visto=%d vezes=%d source=%s" % [
			int((b4 as Dictionary).get("visto_em", -2)),
			int((b4 as Dictionary).get("vezes", -1)),
			String((b4 as Dictionary).get("source", ""))]
	_check(disco_sobrevive,
			"qualidade_na_projecao: os quatro campos sobrevivem ao to_dict/from_dict",
			"disco=%s conf_igual=%s" % [disco_txt,
				str(b4 != null and is_equal_approx(
					float((b4 as Dictionary).get("confidence", 0.0)),
					float((m3.beliefs["fato_decay"] as Dictionary)["confidence"])))])
	# (5) A projecao: o state_hash do TickJournal le so (chave, confidence,
	# source) por crenca — mover a metadata NAO move o hash. O lobo e o REAL do
	# `_arm`, e o hash e o do proprio journal (a rota que o replay consome).
	_arm()
	_wolf.mind.call("reinforce", "player_visible_recent", 0.5, "consolidated", 42)
	var bhash = _wolf.mind.beliefs.get("player_visible_recent")
	var h1 := TickJournal.state_hash(999, _world, _field, [_wolf])
	if bhash != null:
		(bhash as Dictionary)["visto_em"] = 987654
		(bhash as Dictionary)["vezes"] = 321
	var h2 := TickJournal.state_hash(999, _world, _field, [_wolf])
	_check(bhash != null and h1 == h2,
			"qualidade_na_projecao: mover visto_em e vezes NAO move o state_hash",
			"h1=%s h2=%s igual=%s" % [h1.substr(0, 12), h2.substr(0, 12), str(h1 == h2)])
	# (6) Controle do instrumento: mover confidence MOVE o hash — a projecao nao
	# e cega, ela e seletiva; o par anti-farsa da premissa.
	if bhash != null:
		(bhash as Dictionary)["confidence"] = 0.9
	var h3 := TickJournal.state_hash(999, _world, _field, [_wolf])
	_check(h3 != h2,
			"qualidade_na_projecao: controle — mover confidence move o state_hash",
			"h2=%s h3=%s diferente=%s" % [h2.substr(0, 12), h3.substr(0, 12), str(h3 != h2)])
	return true


## Fase 2 do dossie 22 (§20.6) -- o gate `crenca_falsa_nao_vira_fato`. O portao
## da Camada 5 (Passo 5) confere os ids citados contra o ROSTER; a Fase 2
## expande o MESMO portao para o LEDGER (a verdade de mundo): ids alem do roster
## — o jogador (ACTOR_PLAYER = 1, wolf.gd:18) entre eles — passam a existir, e o
## FATO declarado na saida passa a ser conferido contra o ledger: o que o
## ledger contradiz nao vira narrativa, crenca nem intencao; o que o ledger
## confirma (a morte de um cadaver) entra no Mind do narrador como crenca em
## QUARENTENA — source nomeado, confianca rebaixada abaixo da soleira de
## `believes`, nunca intencao escrita no corpo (mandato 2). O par anti-farsa:
## braco A (fato falso) recusado com id e motivo nomeados e zero escritas;
## braco B (controle, ids reais) passa identico antes e depois.
func _test_crenca_falsa_nao_vira_fato() -> bool:
	# (1) A rota do ledger existe no verificador. No vermelho o `aceitar` do
	# Passo 5 e a unica rota — o vermelho e NOMEADO aqui.
	var v := BeliefVerifier.new()
	var tem_rota: bool = v.has_method("aceitar_ledger")
	_check(tem_rota,
			"crenca_falsa_nao_vira_fato: a rota do ledger existe no verificador",
			"aceitar_ledger=%s -- premissa do §20.6: ids do ledger alem do roster" % str(tem_rota))
	if not tem_rota:
		return true
	# Braco B primeiro (controle direto no verificador): o id 1 e o JOGADOR,
	# fora do roster de lobos do Passo 5 — o portao expandido o enxerga pelo
	# ledger, e a recusa de antes vira aceite com a verdade de mundo na mao. A
	# chamada entra por `.call()` pelo mesmo motivo das outras: no vermelho o
	# metodo ainda nao existe e o parse recusa chamada direta a API ausente.
	var jogador = v.call("aceitar_ledger", "O lobo 1 fareja o vento e acha o rastro.",
			{1: true, 7: false, 11: true})
	_check(jogador and v.ultimo_id_forjado == -1,
			"crenca_falsa_nao_vira_fato: o controle passa — id do jogador fora do roster existe pelo ledger",
			"aceito=%s id_forjado=%d motivo='%s'" % [
				str(jogador), v.ultimo_id_forjado, v.ultimo_motivo])
	# Braco A: o ledger diz o lobo 11 VIVO e a saida o declara morto — recusa
	# com o id NOMEADO e o motivo do fato contradito.
	var contradito = v.call("aceitar_ledger", "O lobo 11 caiu no desfiladeiro e nao levantou.",
			{11: true})
	_check(not contradito and v.ultimo_id_forjado == 11
			and v.ultimo_motivo.contains("contradito"),
			"crenca_falsa_nao_vira_fato: o fato contradito pelo ledger e recusado com o id nomeado",
			"aceito=%s id=%d motivo='%s'" % [
				str(contradito), v.ultimo_id_forjado, v.ultimo_motivo])
	# O portao NO WRAPPER com o ledger ligado: a recusa nao escreve NADA no Mind
	# do narrador (nem crenca, nem intencao — mandato 2) e o portao ativo fica
	# nomeado em `ultimo_portao` — a degradacao "roster" e o comportamento do
	# Passo 5 para os gates que nao ligam o ledger.
	_lobo_ledger = _LoboProvaMind.new(11)
	var o := MindOracle.new()
	o._ready()
	o.roster_provider = Callable(self, "_gate_roster_ledger")
	o.set("ledger_provider", Callable(self, "_gate_ledger_prova"))
	var recusado := o.aceitar_saida(11, "O lobo 11 caiu no desfiladeiro e nao levantou.")
	var portao := String(o.get("ultimo_portao"))
	_check(not recusado and o.narration_of(11) == ""
			and _lobo_ledger.mind.beliefs.is_empty()
			and portao == "ledger" and o.last_reason.contains("contradito"),
			"crenca_falsa_nao_vira_fato: o portao do wrapper recusa o fato contradito sem escrever no Mind",
			"aceito=%s narrativa=%d chars beliefs=%d portao='%s' motivo='%s'" % [
				str(recusado), o.narration_of(11).length(),
				_lobo_ledger.mind.beliefs.size(), portao, o.last_reason])
	# (5) Fato verdadeiro sobre cadaver: o ledger diz o lobo 7 MORTO e a saida
	# declara a morte — passa, vira narrativa, e o fato entra no Mind do
	# narrador como crenca em quarentena (source "oracle", confianca 0.10 —
	# copia literal de Mind.QUARENTENA_CONFIDENCE, que ler-la no vermelho seria
	# SCRIPT ERROR, padrao BIAS_MEDIDA).
	var aceito := o.aceitar_saida(11, "O lobo 7 caiu no desfiladeiro.")
	var bq = _lobo_ledger.mind.beliefs.get("oracle_caiu_7")
	var quarentena_txt := "ausente"
	if bq != null:
		quarentena_txt = "conf=%s source=%s" % [
			str((bq as Dictionary).get("confidence", "ausente")),
			String((bq as Dictionary).get("source", "ausente"))]
	var em_quarentena := bq != null \
			and is_equal_approx(float((bq as Dictionary).get("confidence", 0.0)), 0.10) \
			and String((bq as Dictionary).get("source", "")) == "oracle"
	_check(aceito and em_quarentena and o.narration_of(11).contains("lobo 7"),
			"crenca_falsa_nao_vira_fato: o fato confirmado entra no Mind como quarentena nomeada",
			"aceito=%s narrativa=%d chars quarentena=%s" % [
				str(aceito), o.narration_of(11).length(), quarentena_txt])
	# (6) A quarentena NAO vira crenca utilizavel: 0.10 fica abaixo da soleira
	# de `believes` (0.35) — o oraculo sugere, a arvore continua sem aceitar.
	_check(not _lobo_ledger.mind.believes("oracle_caiu_7"),
			"crenca_falsa_nao_vira_fato: a quarentena fica abaixo da soleira de believes",
			"conf=%s soleira=0.35 believes=%s" % [quarentena_txt,
				str(_lobo_ledger.mind.believes("oracle_caiu_7"))])
	# (7) Controle pelo MESMO portao: narracao pura com ids reais passa, vira
	# narrativa e nao escreve crenca NENHUMA — o portao nao e um filtro que
	# recusa tudo nem um escritor que grava tudo.
	var antes: int = _lobo_ledger.mind.beliefs.size()
	var controle := o.aceitar_saida(11, "O lobo 11 fareja o vento e acha o rastro.")
	_check(controle and o.narration_of(11).contains("fareja")
			and _lobo_ledger.mind.beliefs.size() == antes,
			"crenca_falsa_nao_vira_fato: o controle passa pelo portao sem escrever no Mind",
			"aceito=%s narrativa=%d chars beliefs_antes=%d beliefs_depois=%d" % [
				str(controle), o.narration_of(11).length(), antes,
				_lobo_ledger.mind.beliefs.size()])
	o.free()
	return true


## GET sequencial com UM HTTPRequest reusado: pedido aberto com erro de abertura
## devolve o resultado -1 sem nunca pendurar -- `await` so acontece com a requisicao
## aceita, e o `timeout` do nodo garante que ela sempre completa.
func _gate_http_get(http: HTTPRequest, url_get: String, cabecalhos: PackedStringArray,
		tempo_s: float) -> Array:
	http.timeout = tempo_s
	var err := http.request(url_get, cabecalhos, HTTPClient.METHOD_GET)
	if err != OK:
		return [-1, 0, PackedStringArray(), PackedByteArray()]
	return await http.request_completed


## O corpo veio com o alias que separa o nosso servidor de um terceiro (dossie 15 §4.2).
func _gate_body_tem_alias(body: PackedByteArray) -> bool:
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary):
		return false
	for m in (data as Dictionary).get("data", []):
		if m is Dictionary and String((m as Dictionary).get("id", "")) == MindOracle.MODEL_ALIAS:
			return true
	return false


## Espera por quadros com prazo: o `await` do gate nunca fica sem saida.
func _gate_frame_sleep(ms: int) -> void:
	var prazo := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < prazo:
		await process_frame


## O roster dos gates do Passo 5: o lobo armado (`_arm`), e so ele. Metodo do
## gate e nao lambda porque o `Callable` do roster do wrapper precisa sobreviver
## ao lobo trocar de teste -- e um lobo liberado faz o wrapper receber lista
## vazia, que e recusa nomeada, nunca um ponteiro pendente.
func _gate_roster_solo() -> Array:
	return [_wolf] if is_instance_valid(_wolf) else []


## Lobo minimo de prova para o roster do gate do verificador: o portao da Camada
## 5 so le `.identity` do roster, e a logica do verificador nao precisa de mundo.
class _LoboProva:
	var identity: int
	func _init(id: int) -> void:
		identity = id


## O roster do gate do verificador: o lobo de prova 11, e so ele. O id forjado
## do gate (999) nao existe aqui por construcao.
func _gate_roster_prova() -> Array:
	return [_LoboProva.new(11)]


## Lobo de prova com mente REAL para o gate da Fase 2: o prompt narrativo le
## identity, intent, hp, max_hp(), hunger e mind — e o gate
## `crenca_falsa_nao_vira_fato` precisa de um corpo com `mind` para provar que a
## recusa nao escreve NADA nele e que o fato confirmado entra como quarentena.
## O corpo e o minimo que `_prompt_for` le: nada aqui toca a arvore.
class _LoboProvaMind:
	var identity: int
	var intent: String = "farejar"
	var hp: float = 80.0
	var hunger: float = 0.4
	var mind: Mind
	func _init(id: int) -> void:
		identity = id
		mind = Mind.new("wolf", id)
	func max_hp() -> float:
		return 100.0


## O lobo de prova do gate do ledger (identity 11, com mente): e NELE que a
## recusa tem de nao escrever e o fato confirmado tem de entrar em quarentena.
## Refrescado a cada corrida do gate — nenhum estado vaza de um teste para outro.
var _lobo_ledger: _LoboProvaMind


## O roster do gate do ledger: o lobo de prova 11 (com mente), e so ele. O id 1
## (jogador) e o id 7 (cadaver) existem so no ledger do gate — fora do roster,
## que e o ponto da expansao.
func _gate_roster_ledger() -> Array:
	return [_lobo_ledger]


## O ledger do gate da Fase 2: verdade de mundo minima — o lobo 7 esta morto, o
## lobo 11 e o jogador 1 estao vivos. Metodo do gate e nao lambda pelo mesmo
## motivo do roster: o Callable precisa sobreviver ao teste trocar de lobo.
func _gate_ledger_prova() -> Dictionary:
	return {1: true, 7: false, 11: true}
