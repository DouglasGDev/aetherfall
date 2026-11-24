extends Node3D
## Sessao do slice: dona do mundo, do relogio de simulacao, do jogador local e das
## matilhas. Tudo o que a rede tera que autorizar depois ja passa por aqui, e so ha
## um caminho de escrita para o mundo.
##
## Dois relogios (docs/design/06.2): locomocao e camera a 60 Hz, decisao de IA,
## difusao do Eter e tick de simulacao a 20 Hz.

const WOLF_COUNT := 5
## Teto de censo (dossie 11 §4, resposta 2): ate onde a populacao pode crescer --
## e nao a quantidade com que o mundo nasce, que e `WOLF_COUNT`. 12 porque
## 12 x 400 us = 4,8 ms dos 50 ms do passo de 20 Hz, e o gate de P1 ainda escreve
## 2,5 ms como [TARGET] para as arvores: 12 e teto de censo, nao orcamento
## liberado -- o que mantem a soma dentro do numero e o filhote pagar menos arvore
## (a porta de coragem fecha a cacada dele, dossie 11 §3.3). Vale para as duas
## portas que incham a lista, o nascimento (`_scan_breeding`) e o load (§3.6), e
## a recusa de cada uma e contada e impressa, nunca silenciosa.
const CENSUS_CAP := 12
# Distancia minima de um lobo que nasce. Os tres numeros abaixo sao os unicos que
# o definem (dossie 14 §3.4): acima dos 30 m em que o proprio lobo ja consulta a
# visada (`_sense`), acima dos 14 m do latido (`BARK_RANGE` do diretor de audio) e
# dentro dos 46 m do anel historico, para que um ponto conforme exista na primeira
# banda sem ter de varrer o mapa atras dele.
const SAFE_SPAWN_DIST := 32.0
const SEED := 20261116
const SLOT := "alpha"
const AETHER_PERIOD := 0.25        # 4 passadas de difusao por segundo de logica
const MESH_BUDGET := 2             # chunks por frame
const VIZ_PERIOD := 0.25
const RESPAWN_DELAY := 45.0
const CORPSE_CHECK_PERIOD := 1.0
# Raio de coesao da matilha (dossie 10 §3.1): quem esta dentro disto e lido como
# vizinho. O teto e o horizonte do proprio lobo -- `_sense` so roda a LOS do
# jogador ate 30 m -- entao 24 m e um vizinho que o lobo poderia ver, com folga;
# um raio maior faria a alcateia coordenar bicho que esta fora do mundo
# percebido dele. O que este numero rende na sessao real de cinco lares nao e
# suposicao: a checagem "alcateia existe na sessao real" imprime os pares e o
# tamanho da matilha lida a cada corrida da suite.
const PACK_COHESION_RADIUS := 24.0
const EMPTY_PACK: Array = []
const Journal = preload("res://src/persistence/tick_journal.gd")

var tick_journal := Journal.new()

var world: VoxelWorld = null
var aether: AetherField = null
var clock: SimClock = null
var player: Player = null
var viz: AetherViz = null
var hud: Hud = null
var oracle: MindOracle = null
## Dono do ciclo de vida do pack nativo (dossie 22 §6.3). Null em headless de
## proposito: a suite nao pode carregar 2,7 GB de modelo por rodada — quem
## exercita o runtime e o runner, que carrega o pack pela rota do §5.2.
var llm_host: AfMindRuntime = null
var audio: AudioDirector = null
## O FX da agua (dossie 23 §3.6): leitura de corpo, pool fixo, nenhuma escrita no
## mundo — `fx_nao_escreve_o_mundo` e a checagem que paga a frase.
var water_fx: WaterFx = null
var wolves: Array = []
var elapsed: float = 0.0
var stats := {"mined": 0, "placed": 0, "wolves_felled": 0, "deaths": 0}

var _terrain: Node3D = null
var _entities: Node3D = null
## Direcao para o sol deste boot, escrita por `_build_environment` e lida pela agua
## (dossie 23 §2): "caustica quando o sol esta alto" e uma pergunta sobre o no, nao
## sobre o material, entao o numero mora num lugar so.
var _sun_dir: Vector3 = Vector3.UP
var _next_identity: int = 0
var _population_rng := RandomNumberGenerator.new()
## Vagas de reposicao. Cada elemento e `[atraso_em_segundos, den]` (dossie 16 §3.3):
## a vaga carrega a TOCA de quem morreu, senao a reposicao escolheria por conta
## propria e "a toca que perdeu" nao existiria. O `.size()` lido por
## `pending_respawns` e pelo `simulation_rng_test` mantem o mesmo significado --
## e numero de vaga, nao de float.
var _respawn_queue: Array = []
## Quantos bichos o ultimo load criou e retirou, e quantas vezes o teto de censo
## disse nao (nascimento e load). Os tres numero vao para `diagnostics()` porque a
## recusa tem de ser contada e lida, nao apenas impressa uma vez: um censo que
## para no teto sem dizer nada e o mesmo fallback que o dossie 11 §3.6 recusa.
var _load_created: int = 0
var _load_retired: int = 0
var _census_refusals: int = 0
## Quantos filhotes a roda de acasalamento poe no mundo. Counter, nao log: o numero
## que a checagem do dossie 11 le e `wolves.size()` antes e depois, e o print diz
## qual par gerou -- sem o counter nao ha como a suíte de censo conferir duas
## varreduras sem reler o mundo inteiro.
var _births: int = 0
var _mate_cd: float = 0.0
var _aether_cd: float = AETHER_PERIOD
var _viz_cd: float = 0.0
var _corpse_cd: float = 0.0
var _gen_ms: float = 0.0
var _mesh_ms: float = 0.0
var _binds_on: bool = false
# Bancadas colocadas, em blocos. E a lista que o Veloren varreria por sprite
# proximo; o mundo nao e varrido porque a consulta roda a cada frame do painel.
var _benches: Array[Vector3i] = []
# Buffers da matilha (dossie 10 §4): um Array por identidade, com as entradas
# Dictionary reescritas no lugar a cada passo. A leitura e o preco que o contrato
# aceita -- construir cinco arrays novos por tick nao entraria.
var _pack_buffers: Dictionary = {}
var _pack_cursor: Dictionary = {}
# Comparacoes de par feitas no ultimo rebuild. E numero de gate, nao conversa: o
# dossie 10 §4 promete n(n-1)/2 por passo, e o rodape da suite prova isto no
# diagnostico JSON.
var _pack_pairs: int = 0
## Centros das tocas fundadas, em metros, um por indice de toca (dossie 16 §3.1).
## O dono e a sessao, pelo mesmo motivo declarado na perna 11 para `wolves` e
## `_next_identity`: quem poe bicho no mundo decide onde ele nasce, e o lobo so le.
## A COLUNA nao e guardada -- e `Vector2i(int(center.x), int(center.z))`, e uma
## lista com dois campos para o mesmo fato e um campo que pode mentir. A lista e
## criada uma vez e so cresce (ate `DEN_COUNT`); uma toca fundada nunca segue o
## jogador nem e re-sorteada, que e o corte exato com a mordaca da perna 14.
var _dens: Array = []


func _ready() -> void:
	InputActions.install()
	BlockDefs.init_tables()
	# O dono do pack entra antes da geracao (dossie 22 §6.3): o `load_pack` do
	# gguf e uma chamada sincrona da extensao e o frame que o executa trava o
	# tempo do load — o overlap que o processo filho do dossie 15 dava com os
	# ~5,2 s de geracao + malharia acabou com o transporte HTTP, e o regresso e
	# o numero do `open_ms` da ponte, registrado na nota do Passo 4. Nada aqui
	# espera o modelo de forma sincrona ALEM do proprio load: o carregamento
	# anda um passo por frame (`AfMindRuntime.STEP_PERIOD`) para o F3 acompanhar.
	_start_llm_host()
	_terrain = Node3D.new()
	_terrain.name = "Terrain"
	add_child(_terrain)
	_entities = Node3D.new()
	_entities.name = "Entities"
	add_child(_entities)
	_build_environment()

	var t0 := Time.get_ticks_usec()
	world = VoxelWorld.new()
	world.setup_world(_terrain)
	world.set_water_sun_direction(_sun_dir)
	world.generate(SEED)
	_gen_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	world.generate_meshes_all()
	_mesh_ms = float(Time.get_ticks_usec() - t0) / 1000.0

	aether = AetherField.new()
	aether.setup(world)
	clock = SimClock.new()

	viz = AetherViz.new()
	viz.setup(aether)
	add_child(viz)

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.setup(world, spawn_point())
	player.entity_provider = Callable(self, "targets_under_crosshair")
	player.bench_provider = Callable(self, "bench_positions")
	player.block_broken.connect(_on_block_broken)
	player.block_placed.connect(_on_block_placed)
	player.acted.connect(_on_acted)
	player.attacked.connect(_on_attacked)
	player.damaged.connect(_on_damaged)
	player.died.connect(_on_player_died)
	player.toggle_debug.connect(_toggle_debug)
	player.toggle_ether.connect(_toggle_ether)
	player.request_save.connect(save_game)
	player.request_load.connect(load_game)
	player.notice.connect(_on_notice)
	player.panel_changed.connect(hud_panel_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	hud = Hud.new()
	hud.name = "Hud"
	hud.player = player
	hud.world = world
	hud.aether = aether
	hud.clock = clock
	hud.stats_provider = Callable(self, "stats_line")
	hud.wolf_provider = Callable(self, "targets_under_crosshair")
	add_child(hud)
	hud.build_hotbar()
	hud.show_message("vale reconstruido  seed %d" % SEED, 3.4)
	hud.preview_binds(7.0)

	oracle = MindOracle.new()
	oracle.name = "MindOracle"
	oracle.roster_provider = Callable(self, "wolves_roster")
	add_child(oracle)
	hud.narration_provider = Callable(oracle, "narration_of")
	# O hospedeiro pode ser anterior ao oraculo (boot normal) e o hud posterior a
	# ambos: quem liga os tres e a mesma funcao, chamada nos dois pontos.
	_wire_llm_host()

	# Ultimo a entrar e o primeiro a ser ouvido: so consome os sinais que ja
	# existiam, nao escreve mundo nem sorteia nas RNG da simulacao.
	audio = AudioDirector.new()
	audio.name = "Audio"
	audio.wolves_provider = Callable(self, "wolves_roster")
	add_child(audio)
	audio.setup(world, player)

	# O FX entra na mesma janela do audio porque le os mesmos corpos: pool criado
	# aqui, no boot, e nunca dentro de frame (dossie 23 §3.6).
	water_fx = WaterFx.new()
	water_fx.name = "WaterFx"
	water_fx.wolves_provider = Callable(self, "wolves_roster")
	add_child(water_fx)
	water_fx.setup(world, player)

	_spawn_wolves(WOLF_COUNT)
	_start_journal_from_args()


## Decisao 4.6 do dossie 15, ajustada pelo §6.3 do dossie 22: em headless o dono
## do pack nao entra na arvore, porque a suite e a corriqueira e o modelo e de
## 2,7 GB. O nome do display server e o documentado no motor
## (`DisplayServer.get_name()`).
func _start_llm_host() -> void:
	if DisplayServer.get_name() == "headless":
		return
	attach_llm_host(AfMindRuntime.new())


## Entrada do boot normal e de quem injeta um runtime por fora. O host e o unico
## que conhece o estado do pack; a sessao so empresta o oraculo e o hud para a
## ligacao.
func attach_llm_host(host: AfMindRuntime) -> void:
	if llm_host != null and llm_host != host:
		# Um dono por pack. Medido na janela real (perna 15): o boot da janela criou
		# o host dele e a cena de prova injetou o seu por cima — dois donos brigando
		# pelo mesmo recurso. O `remove_child` roda o `_exit_tree` do retiro na hora;
		# hoje nao ha processo para matar, mas dois runtimes carregariam dois packs
		# e dobrariam a VRAM.
		var retiro: AfMindRuntime = llm_host
		remove_child(retiro)
		retiro.queue_free()
	llm_host = host
	host.name = "AfMindRuntime"
	add_child(host)
	_wire_llm_host()


## Os tres pontos de ligacao nascem em momentos diferentes do `_ready`, entao a
## funcao roda duas vezes e so escreve onde a peca ja existe.
func _wire_llm_host() -> void:
	if llm_host == null:
		return
	if oracle != null:
		llm_host.oracle = oracle
		# Portao de prontidao: sem ele o primeiro pedido cairia na recusa "sem
		# contexto" (o pack ainda fora do estado de fila) e o recuo de 30 s
		# engoliria a meia-minuta seguinte (dossie 15 §4.4, semantica do §6.3).
		oracle.ready_provider = Callable(llm_host, "ready")
	if hud != null:
		hud.llm_status_provider = Callable(llm_host, "status_line")


## Checagem 8 do gate: a suíte precisa de uma forma de afirmar que a sessão
## headless não montou dono de processo nenhum.
func has_llm_host() -> bool:
	return llm_host != null


func spawn_point() -> Vector3:
	var x := int(VoxelConfig.world_size_x() * 0.5)
	var z := int(VoxelConfig.world_size_z() * 0.5)
	return Vector3(float(x) + 0.5, float(world.surface_height(x, z) + 1), float(z) + 0.5)


# ------------------------------------------------------------------ relogios

func _physics_process(delta: float) -> void:
	player.update_local(delta)
	var steps := clock.advance(delta)
	for i in steps:
		clock.begin_step()
		_sim_tick()
		clock.end_step()


func _sim_tick() -> void:
	var dt := clock.step_duration()
	elapsed += dt
	_aether_cd -= dt
	if _aether_cd <= 0.0:
		aether.diffuse_and_decay(AETHER_PERIOD)
		_aether_cd = AETHER_PERIOD
	_rebuild_packs()
	for w in wolves:
		w.sim_step(elapsed, dt)
	_corpse_cd -= dt
	if _corpse_cd <= 0.0:
		_corpse_cd = CORPSE_CHECK_PERIOD
		_reap_corpses()
	for i in range(_respawn_queue.size() - 1, -1, -1):
		var vaga: Array = _respawn_queue[i]
		vaga[0] = float(vaga[0]) - dt
		if float(vaga[0]) <= 0.0:
			_respawn_queue.remove_at(i)
			# Dossie 14 §1.3: nenhum aviso de criatura na tela -- o jogador acha a
			# matilha pelos rastros, não por um letreiro. A frase que morava aqui
			# mentia alem de tudo: `_spawn_wolves(1)` pode recusar o ponto e a vaga
			# volta para a fila, e "uma nova matilha entrou no vale" seria dita com
			# o vale vazio.
			# A toca de quem morreu vai junto (dossie 16 §3.3), e se o ponto for
			# recusado ela volta na vaga: perder a pertenca no retry seria a
			# reposicao escolher outro lugar por azar de sorteio.
			_spawn_wolves(1, int(vaga[1]))
	# Dossie 11 §3.4: a roda de acasalamento roda AQUI, e nao dentro do
	# `sim_step` do lobo, porque quem poe um bicho no mundo e dono de `wolves` e de
	# `_next_identity`. Rodar no lobo seria o spawn ter dois donos e o filhote
	# nascer de dentro de uma iteracao sobre a lista que ele esta mudando.
	_mate_cd -= dt
	if _mate_cd <= 0.0:
		_mate_cd = MATE_PERIOD
		_scan_breeding()
	clock.tick += 1
	if tick_journal.active():
		var err := tick_journal.record(clock.tick, world, aether, wolves)
		if err != OK:
			tick_journal.close()
			push_error("journal tick %d: %s" % [clock.tick, error_string(err)])
			get_tree().quit(1)


func _process(delta: float) -> void:
	world.process(MESH_BUDGET)
	if viz.showing():
		_viz_cd -= delta
		if _viz_cd <= 0.0:
			_viz_cd = VIZ_PERIOD
			viz.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("respawn") and not player.alive:
		respawn()
	elif event.is_action_pressed("toggle_binds"):
		_binds_on = not _binds_on
		hud.show_binds(_binds_on)


func respawn() -> void:
	player.respawn_at(player.spawn_point)
	_imprint(player.spawn_point, AetherField.Channel.FEAR, 0.4)
	hud.set_death(false)
	hud.show_message("a marea cobrou sua divida")


# ------------------------------------------------------------------ povoamento

func _spawn_wolves(n: int, for_den: int = -1) -> void:
	if _next_identity == 0:
		_population_rng.seed = ("population:%d" % world.gen.world_seed).hash()
	for i in n:
		# Dossie 14 §3.3.(iii): dois lobos com o mesmo lar rondam o mesmo setor e a
		# matilha parece um corpo so. O conjunto de colunas ocupadas sai dos lobos
		# vivos, entao criar cinco de uma vez e criar cinco um a um consomem a
		# mesma sequencia da `_population_rng` -- a assinatura que a suíte de RNG
		# pinça nao muda com o lote. A escolha de toca (`_place_request`) e lida do
		# mesmo conjunto vivo e de `_dens`, que so cresce, entao o lote e o um-a-um
		# veem a mesma matilha e as mesmas tocas fundadas (dossie 16 §3.2.4).
		var pedido := _place_request(for_den)
		if not bool(pedido["ok"]):
			# Dossie 14 §3.5: o motivo ja saiu impresso na funcao de busca. O lobo nao
			# nasce agora e a vaga volta para o fim da fila com o mesmo atraso -- o
			# contrario do fallback antigo, que punha o bicho no centro em silencio.
			# Com `for_den` escrito em cima, a vaga volta PARA A MESMA TOCA.
			_respawn_queue.append([RESPAWN_DELAY, for_den])
			continue
		var home: Vector3 = pedido["feet"]
		var w := _make_wolf(home, _next_identity, Wolf.Phase.ADULT,
				Wolf.JUVENILE_STEPS, int(pedido["den"]))
		_next_identity += 1
		wolves.append(w)


## O unico caminho que poe um lobo no mundo: `setup` com a identidade que a sessao
## entrega, a matilha injetada pelo `Callable` preso nessa identidade, os dois
## sinais ligados e o registro no diretor de audio.
##
## Tres portas passam por aqui -- o sorteio (`_spawn_wolves`), o nascimento
## (`_born_from`, dossie 11 §3.4) e o disco (`load_game`, §3.6). enquanto o
## construtor era privativo do sorteio, as outras duas teriam de escolher entre
## duplicar a linha do `bit_player.connect` (e o filhote nasceria mudo para o som
## e para a morte) ou nascer sem provedor de matilha (e o filhote nao veria irmao
## nenhum). `phase` e `age_ticks` entram por parametro porque o disco e o
## nascimento os conhecem antes do primeiro passo; o sorteio nao, e fica adulto.
## `p_den` entra pelo mesmo motivo de `phase`: a toca e escrita por quem poe o
## bicho no mundo e lida por ele depois, entao quem chama precisa dizer a qual
## toca o recém-chegado pertence antes do primeiro `pack_of()`.
func _make_wolf(feet: Vector3, p_identity: int, p_phase: Wolf.Phase = Wolf.Phase.ADULT,
		p_age: int = Wolf.JUVENILE_STEPS, p_den: int = -1) -> Wolf:
	var w := Wolf.new()
	_entities.add_child(w)
	w.setup(world, aether, player, feet, p_identity, clock)
	w.den = p_den
	# A matilha entra pelo mesmo caminho do `entity_provider` do jogador: o
	# Callable e montado pela sessao, com a identidade presa, e o lobo so le.
	w.pack_provider = Callable(self, "pack_of").bind(p_identity)
	if p_phase != Wolf.Phase.ADULT or p_age != Wolf.JUVENILE_STEPS:
		w.age_ticks = p_age
		w.set_phase(p_phase)
	w.bit_player.connect(_on_wolf_bit)
	w.died.connect(_on_wolf_died)
	# O diretor nasce em `_ready`, e `simulation_rng_test.gd` chama este spawn numa
	# sessao fora da arvore de proposito (o contrato la e "spawnar sem boot
	# completo"): aqui o som e opcional, a mente nao.
	if audio != null:
		audio.on_wolf_registered(w)
	return w


## A porta que tira um bicho da lista, a mesma da recolha de cadaver: o buffer de
## matilha e o cursor saem junto, sena a leitura do morto ficaria orphan no
## dicionario para sempre (a identidade nao e reutilizada).
func _retire_wolf(w: Wolf) -> void:
	wolves.erase(w)
	_pack_buffers.erase(w.identity)
	_pack_cursor.erase(w.identity)
	w.queue_free()


## O bicho esta disponivel para criar? Adulto, descansado, alimentado e inteiro.
## A fase entra porque filhote nao acasala (dossie 11 §3.3), e o `hp` e lido contra
## `max_hp()` do proprio bicho: comparar contra a constante do adulto daria ao
## filhote que virou jovem uma barra de vida que ele nunca teve.
func _breedable(w: Wolf) -> bool:
	return w.alive and w.phase == Wolf.Phase.ADULT and w.mate_cd <= 0.0 \
			and w.hunger <= MATE_HUNGER_MAX \
			and w.hp >= MATE_HP_MIN * w.max_hp()


## A roda (dossie 11 §3.4): o PRIMEIRO par adulto, saciado, sao e sem cooldown que
## se encontra a `MATE_RADIUS` metros, e desse par nasce UMA cria. Parar no
## primeiro é escolha, não descuido: com o teto de 12 no ar, varrer todos os pares
## num mesmo tick poderia nascer tres filhotes de uma passada e o censo entraria
## no teto por velocidade de natacao em vez de por tempo de sessao.
func _scan_breeding() -> void:
	for i in wolves.size():
		var a: Wolf = wolves[i]
		if not _breedable(a):
			continue
		for j in range(i + 1, wolves.size()):
			var b: Wolf = wolves[j]
			if not _breedable(b):
				continue
			if a.center().distance_squared_to(b.center()) > MATE_RADIUS * MATE_RADIUS:
				continue
			_born_from(a, b)
			return


## Quem poe o filhote no mundo e a sessao, nunca o lobo (dossie 11 §3.4): a lista
## `wolves`, o `_next_identity` e o `_home_columns()` tem um dono so, e e este.
##
## Os dois caminhos de recusa custam o cooldown ao par DE PROPOSITO. Sem isso a
## roda de 1 s imprimiria a mesma recusa 20 vezes por passo durante os 300 s em
## que o censo esta no teto, e "recusa impressa, nunca silenciosa" (mandato 1)
## viraria spam -- o numero continuaria lido em `diagnostics()`, mas o log do
## jogador seria uma linha repetida. O ponto de nascimento passa pelo MESMO
## predicado do spawn da perna 14 (`_spawn_point_ok` via `_place_request`): um
## recem-nato na frente do jogador seria o pedido "nunca spawnar na frente"
## cumprido no boot e traído no primeiro parto.
func _born_from(a: Wolf, b: Wolf) -> void:
	a.mate_cd = MATE_COOLDOWN
	b.mate_cd = MATE_COOLDOWN
	if wolves.size() >= CENSUS_CAP:
		print("nascimento RECUSADO: censo %d no teto %d (par %d+%d)" % [
				wolves.size(), CENSUS_CAP, a.identity, b.identity])
		_census_refusals += 1
		return
	# A cria herda a toca do adulto de identidade MENOR (dossie 16 §3.3) -- o mesmo
	# desempate por identidade que a ronda ja usa para ordenar assentos. O ponto
	# medio dos dois lares sai do codigo porque ele e justamente a peça que faria um
	# casal de tocas diferentes produzir um lar fora de qualquer toca: com centros a
	# `DEN_MIN_DIST` ou mais, o meio-termo de dois lugares e um terceiro lugar que
	# ninguem fundou.
	var herdando: Wolf = a if a.identity < b.identity else b
	var pedido := _place_request(herdando.den)
	if not bool(pedido["ok"]):
		# O motivo ja saiu impresso dentro da busca, com a contagem por portao.
		# Sem lar aceito nao ha filhote: a alternativa historica era cair no centro
		# em silencio, e o centro e onde o jogador acorda.
		return
	var w := _make_wolf(pedido["feet"], _next_identity, Wolf.Phase.CUB, 0,
			int(pedido["den"]))
	_next_identity += 1
	wolves.append(w)
	_births += 1
	var d: int = int(pedido["den"])
	var ancora := player.position3()
	var rotulo := "do jogador (toca -1: nenhuma fundada onde pousar)"
	if d >= 0:
		ancora = _dens[d]
		rotulo = "do centro da toca %d" % d
	print("nascimento: filhote %d dos adultos %d+%d na toca %d, %.1f m %s" % [
			w.identity, a.identity, b.identity, d, w.home.distance_to(ancora), rotulo])


## Colunas de lar já ocupadas. Dicionário pequeno (até o censo), construído uma vez
## por spawn -- o spawn é raro: cinco no boot e um por fila de 45 s (dossie 14 §4).
func _home_columns() -> Dictionary:
	var taken: Dictionary = {}
	for w: Wolf in wolves:
		taken[Vector2i(int(w.home.x), int(w.home.z))] = true
	return taken


## Bandas de spawn em torno do JOGADOR (dossie 14 §3.5), na ordem: o anel historico
## de 16-46 m, depois 46-70 m, depois 70 m ate a borda util do mapa. Cada banda
## gasta o budget de tentativas que o sorteio unico gastava, entao o pior caso custa
## quatro vezes um caminho que roda cinco vezes no boot e uma a cada fila de 45 s.
const SPAWN_BANDS: Array = [[16.0, 46.0], [46.0, 70.0]]
const SPAWN_ATTEMPTS := 24

## Raio da mordaca (furo #16): o lar de quem entra na matilha fica dentro disto do
## lar de um irmao vivo, e `PACK_COHESION_RADIUS` = 24 m e o que faz dois lobos se
## lerem. 18 m dos 24 deixa 6 m de folga para o corpo andar sem perder o vizinho.
## Sem a mordaca, cinco pontos sorteados no anel de 16-46 m em torno do jogador
## raramente deixavam dois lobos se enxergarem -- `maior_matilha_lida=1` em todas
## as corridas ate aqui, inclusive as cinco da perna 14.
const PACK_LEASH := 18.0


## Quantas tocas a sessao funda (dossie 16 §3.2.1). O pedido do dono era "2-3
## tocas"; 3 e o teto de fundacao e o que o boot escolhe porque com `WOLF_COUNT`
## = 5 a distribuicao 2/2/1 e a menor que faz um componente ter dois membros e
## ainda deixar sobra -- a checagem 1 do gate cobra exatamente isto.
const DEN_COUNT := 3
## Separacao minima ENTRE CENTRO DE TOCA, em metros, medida no chao (§3.2.6). O
## arco vem antes do codigo: para dois corpos nao se lerem basta > `PACK_COHESION_
## RADIUS` = 24 m, mas para dois COMPONENTES nao se fundirem precisa mais, porque
## o corpo anda ate 22 m do baricentro dos vizinhos que le. Geometricamente tres
## pontos cabem no quadrado util de 116 m com separacao de ate 116 m, entao 48 m
## cabe e e o ponto de partida; o numero que vale e o minimo medido na corrida,
## impresso na checagem, nao esta constante.
const DEN_MIN_DIST := 48.0


## Roda de acasalamento (dossie 11 §3.4): os cinco numeros abaixo SAO a regra, e a
## regra e da sessao -- o lobo guarda apenas o cooldown, porque a recusa tem de ser
## por animal e nao por indice do array.
##
## Cadencia de 1 s, e nao do passo: a roda olha pares, e com o teto de 12 bichos
## sao 66 pares. Sessenta e seis contas de distancia dentro dos 50 ms do
## `sim_step` seria trabalho de caminho quente para um evento que, quando
## acontece, trava o par por `MATE_COOLDOWN` segundos.
const MATE_PERIOD := 1.0
## Os dois tem de se encontrar de corpo: 8 m e menos que a coesao de matilha
## (`PACK_COHESION_RADIUS` = 24 m) e menos que o alcance em que um lobo ja le o
## outro, entao "perto" aqui e posicao, nao intencao compartilhada.
const MATE_RADIUS := 8.0
## Criar custa fome e sangue: abaixo destes limiares o bicho nao esta disponivel.
## `hunger` cresce `dt * 0,006` (fome plena a 1,0) e `hp` e lido contra o teto da
## FASE dele (`max_hp()`), nao contra a constante do adulto: um jovem de escala
## 0,72 com 25 de vida esta inteiro, e conta-lo como 60 % seria mentir pela
## constante errada.
const MATE_HUNGER_MAX := 0.55
const MATE_HP_MIN := 0.60
## 300 s = 6 000 passos de 20 Hz. O filhote vira jovem em `CUB_STEPS` = 1 200
## passos (60 s) e adulto em 4 800 (240 s): o cooldown e maior que a infancia
## inteira de proposito, senao o par voltaria a procurar cria antes de o primeiro
## filhote ter crescido e o censo estouraria o teto por velocidade de natacao.
const MATE_COOLDOWN := 300.0


## Membros vivos por toca (dossie 16 §3.2.4), lido do censo no instante do pedido.
## Um bicho com `den == -1` -- o disco anterior a perna, ou uma sessao em que
## nenhuma fundacao coube -- nao entra: ele nao e membro de lugar nenhum.
func _den_counts() -> Dictionary:
	var counts: Dictionary = {}
	for w: Wolf in wolves:
		if w.alive and w.den >= 0:
			counts[w.den] = int(counts.get(w.den, 0)) + 1
	return counts


## A toca menos populada; empate, o indice menor. Escolher por sorteio seria
## quebrar o contrato do `simulation_rng_test`: criar cinco de uma vez e criar
## cinco um a um tem de consumir a MESMA sequencia da `_population_rng`, e aqui a
## funcao e do estado vivo, nao da sequencia de `randf`.
func _emptiest_den() -> int:
	var counts := _den_counts()
	var melhor := 0
	var menor := int(counts.get(0, 0))
	for i in range(1, _dens.size()):
		var c: int = int(counts.get(i, 0))
		if c < menor:
			menor = c
			melhor = i
	return melhor


## Portao novo da fundacao (§3.2.2): o centro de uma toca fica a pelo menos
## `DEN_MIN_DIST` do centro de toda toca ja fundada, medido no chao -- dois
## centros em alturas diferentes mas a mesma distancia horizontal continuam
## sendo dois lugares que se leem um ao outro. Roda DEPOIS dos portoes velhos de
## proposito: as contagens de `perto`/`visivel`/`coluna` da perna 14 seguem
## comparaveis corrida a corrida, e o numero novo e o unico que a 16 acrescenta.
func _den_gate_ok(feet: Vector3, gate: Array) -> bool:
	for d: Vector3 in gate:
		var dx := feet.x - d.x
		var dz := feet.z - d.z
		if dx * dx + dz * dz < DEN_MIN_DIST * DEN_MIN_DIST:
			return false
	return true


## Separacao minima entre CENTROS de toca, no chao: o mesmo eixo do portao que a
## fundou, para que o numero publicado e o numero cobrado sejam a mesma conta.
## Devolve `-1,0` quando nao ha par (uma toca ou nenhuma) porque um `INF` dentro
## do `diagnostics()` viraria JSON sem um leitor que o soubesse interpretar.
func den_min_dist() -> float:
	var menor := INF
	for i in _dens.size():
		var a: Vector3 = _dens[i]
		for j in range(i + 1, _dens.size()):
			var b: Vector3 = _dens[j]
			menor = minf(menor, Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)))
	return -1.0 if is_inf(menor) else menor


## Quantos grupos separados a matilha forma, lidos do grafo que o ultimo rebuild
## escreveu (`pack_of` e leitura pura, nao mexe em buffer nenhum).
##
## Este e o numero que paga o furo #21: `pack_pairs` conta pares TESTADOS, entao a
## igualdade `n(n-1)/2` e verdade aritmetica seja qual for o espalhamento dos lares
## -- ela nunca decidiu coesao, e o `biggest >= 2` da suite e que estava segurando o
## gate sozinho. Componentes e o que o pedido do dono pede ("regras para a matilha
## nao parecer desorganizada"): grupos separados, cada um no seu lugar.
##
## Roda em `diagnostics()`, nunca por tick (dossie 16 §4). Os dois leitores do
## diagnostico sao o F3 (0,25 s) e o gate headless; nenhum dos dois e o caminho
## quente, e a conta e `O(lobos + arestas ja escritas)` com `<= CENSUS_CAP` nos.
func den_components() -> int:
	var vivos: Dictionary = {}
	for w: Wolf in wolves:
		if w.alive:
			vivos[w.identity] = true
	var vistos: Dictionary = {}
	var grupos := 0
	for id: int in vivos:
		if vistos.has(id):
			continue
		grupos += 1
		var pilha: Array = [id]
		vistos[id] = true
		while pilha.size() > 0:
			var atual: int = int(pilha.pop_back())
			for e: Dictionary in pack_of(atual):
				var v: int = int(e["identity"])
				if vivos.has(v) and not vistos.has(v):
					vistos[v] = true
					pilha.append(v)
	return grupos


## O pedido de lar de um bicho novo (dossie 16 §3.3), com a pertenca decidida aqui
## e nunca pelo lobo. `for_den >= 0` e a vaga que chegou com uma toca escrita em
## cima -- reposicao de fila e parto -- e ela ENTRA nela. `for_den == -1` e o
## sorteio: FUNDA enquanto couber (`DEN_COUNT`) e, com todas fundadas ou com a
## fundacao recusada havendo ao menos uma, entra na mais vazia.
##
## Nenhum caminho cai no centro nem em toca alheia por acidente: sem lugar aceito a
## vaga volta para a fila com a mesma toca, que e o que a perna 14 ja fazia com o
## mesmo atraso e pelo mesmo motivo (mandato 1).
func _place_request(for_den: int = -1) -> Dictionary:
	var taken := _home_columns()
	if for_den < 0:
		if _dens.size() < DEN_COUNT:
			var fundacao := _spawn_home_point(taken, null, _dens)
			if bool(fundacao["ok"]):
				var idx: int = _dens.size()
				var centro: Vector3 = fundacao["feet"]
				_dens.append(centro)
				var sep := INF
				for i in idx:
					var outro: Vector3 = _dens[i]
					# No chao, como o portao: a linha impressa tem de ser o mesmo
					# numero que a regra exige, nao uma distancia 3D que ninguem pediu.
					sep = minf(sep, Vector2(outro.x, outro.z).distance_to(
							Vector2(centro.x, centro.z)))
				print("toca %d fundada: centro a %.1f m do jogador, separacao minima %s" % [
						idx, player.position3().distance_to(centro),
						"nova (e a primeira)" if is_inf(sep) else "%.1f m" % sep])
				return {"ok": true, "feet": centro, "den": idx, "motivo": ""}
			if _dens.is_empty():
				# Primeira toca do boot recusada: nao ha lugar nenhum, e o bicho
				# volta para a fila. Este e o unico caso em que a recusa da fundacao
				# e a palavra final -- com toca fundada, seguir para a entrada nao e
				# fallback de lugar, e usar o lugar que ja existe.
				return fundacao
		for_den = _emptiest_den()
	if for_den >= _dens.size():
		return _sem_toca(taken)
	return _entrada(taken, for_den)


## A mordaca em torno do centro da toca `den` (dossie 16 §3.2.3): o anel 4-18 m e
## os seis portoes contra o JOGADOR continuam os mesmos da perna 14 -- o que muda e
## so a ancora, de "lar do primeiro vivo" para "centro da toca". Trocar a ancora e
## o corte com o circulo unico; mexer nos portoes seria comprar seguranca com a
## toca, e o §6 nao deixa.
func _entrada(taken: Dictionary, den: int) -> Dictionary:
	var pedido := _spawn_home_point(taken, _dens[den])
	if bool(pedido["ok"]):
		return {"ok": true, "feet": pedido["feet"], "den": den, "motivo": ""}
	return pedido


## Sem toca onde entrar: o bicho nasce pelas bandas do jogador e fica com `den` -1,
## que e impresso e nao disfarçado (§3.1). Este caminho NAO funda, e a distincao e
## a regra: fundar e decisao do sorteio ate `DEN_COUNT`, e fila nem parto podem
## alargar o teto pela porta dos fundos.
func _sem_toca(taken: Dictionary) -> Dictionary:
	var pedido := _spawn_home_point(taken)
	pedido["den"] = -1
	return pedido


## Predicado unico dos dois compradores (dossie 14 §3.4; a 11 poe o filhote por
## aqui tambem): longe o bastante e, acima disso, nao visivel. Sem cone de camera --
## "fora da visada" e estritamente mais forte que "nao na frente" e custa uma DDA,
## por isso so roda aqui, no caminho raro, nunca por tick.
func _spawn_point_ok(feet: Vector3) -> bool:
	var seg := SAFE_SPAWN_DIST * SAFE_SPAWN_DIST
	if feet.distance_squared_to(player.position3()) < seg:
		return false
	var peito := feet + Vector3(0.0, Wolf.DIMS.y * 0.5, 0.0)
	return not world.line_of_sight(player.eye_position(), peito)


## Maior raio que ainda tem mapa dentro da caixa util (6 blocos de margem, o mesmo
## clamp do sorteio). Perto da borda a terceira banda encolhe e pode ficar vazia, e
## isso e impresso como motivo, nao disfarçado de sucesso.
func _band_edge(at: Vector3) -> float:
	var dx := maxf(at.x - 6.0, float(VoxelConfig.world_size_x()) - 6.0 - at.x)
	var dz := maxf(at.z - 6.0, float(VoxelConfig.world_size_z()) - 6.0 - at.z)
	return sqrt(dx * dx + dz * dz)


## Lar de um lobo novo, ou a recusa com os motivos contados. Nao ha fallback para o
## centro: o centro e justamente onde o jogador e posto no boot ([_ready] chama
## `spawn_point()` para os dois), e cair ali em silencio era um sucesso fingido --
## o que o mandato 1 proibe, nao apenas um aviso a menos na tela.
## Com `near` (o centro da toca onde o bicho vai entrar, dossie 16 §3.2.3) a
## mordaca e a primeira tentativa: os portoes continuam os mesmos, inclusive o
## `>= SAFE_SPAWN_DIST` e a visada contra o JOGADOR, entao entrar numa toca nunca
## compra seguranca. Com `gate` (as tocas ja fundadas) a fundacao acrescenta o
## portao `>= DEN_MIN_DIST` entre centros -- nenhum valor dos outros seis muda.
func _spawn_home_point(taken: Dictionary, near: Variant = null,
		gate: Array = []) -> Dictionary:
	var c := player.position3()
	var edge := _band_edge(c)
	var tries: Array = []
	if near is Vector3:
		tries.append([near, 4.0, PACK_LEASH, "mordaca"])
	tries.append([c, float(SPAWN_BANDS[0][0]), float(SPAWN_BANDS[0][1]), "banda 1"])
	tries.append([c, float(SPAWN_BANDS[1][0]), float(SPAWN_BANDS[1][1]), "banda 2"])
	tries.append([c, float(SPAWN_BANDS[1][1]), edge, "banda 3"])
	var motivos := {"perto": 0, "visivel": 0, "coluna": 0, "molhado": 0, "encaixado": 0,
			"vazia": 0, "perto_de_toca": 0}
	for t in tries.size():
		var at: Vector3 = tries[t][0]
		var rmin := float(tries[t][1])
		var rmax := float(tries[t][2])
		if rmax <= rmin:
			# Jogador encostado na borda: nao ha mapa alem de `rmin`, e a banda que
			# sobra e vazia por geometria, nao por azar. Vai para a contagem.
			motivos["vazia"] += 1
			continue
		for _attempt in SPAWN_ATTEMPTS:
			var a := _population_rng.randf() * TAU
			var r := _population_rng.randf_range(rmin, rmax)
			var p := Vector3(at.x + cos(a) * r, 0.0, at.z + sin(a) * r)
			p.x = clampf(p.x, 6.0, float(VoxelConfig.world_size_x()) - 6.0)
			p.z = clampf(p.z, 6.0, float(VoxelConfig.world_size_z()) - 6.0)
			var column := Vector2i(int(p.x), int(p.z))
			if taken.has(column):
				motivos["coluna"] += 1
				continue
			var y := world.surface_height(int(p.x), int(p.z))
			if y <= VoxelConfig.SEA_LEVEL:
				motivos["molhado"] += 1
				continue
			var feet := Vector3(p.x, float(y + 1), p.z)
			if not _volume_clear(feet, Wolf.DIMS):
				motivos["encaixado"] += 1
				continue
			if not _spawn_point_ok(feet):
				# Os dois portoes separam-se na contagem porque pedem coisas
				# diferentes: um e geometria do mapa, o outro e relevo.
				if feet.distance_squared_to(c) < SAFE_SPAWN_DIST * SAFE_SPAWN_DIST:
					motivos["perto"] += 1
				else:
					motivos["visivel"] += 1
				continue
			if not _den_gate_ok(feet, gate):
				# Oitavo portao, e so a fundacao o ve: o lugar existe, esta longe do
				# jogador e fora da visada, mas fica dentro do alcance de uma toca ja
				# fundada -- que e justamente o circulo unico esta perna veio quebrar.
				motivos["perto_de_toca"] += 1
				continue
			var d := feet.distance_to(c)
			print("spawn %s (%.0f-%.0f m de %s): lar aceito a %.1f m do jogador" % [
					tries[t][3], rmin, rmax, "toca" if at != c else "jogador", d])
			return {"ok": true, "feet": feet, "banda": t + 1, "motivo": ""}
	var recusa := "nenhum ponto em %d buscas (%s)" % [tries.size(), str(motivos)]
	print("spawn RECUSADO: " + recusa)
	# `motivos` sai como numero, nao só dentro da string: o furo #18 do status mediu
	# que o dicionario nao tinha UM leitor em `tests/`, entao a separacao por motivo
	# -- que e a promessa da recusa impressa e contada -- nunca foi conferida por
	# ninguem. A string continua (e ela que aparece no log); a chave nova e o que o
	# gate le.
	return {"ok": false, "feet": Vector3.ZERO, "banda": tries.size(),
			"motivo": recusa, "motivos": motivos}


## Pe em cima do voxel mais alto da coluna nao basta: o corpo do lobo faz 1,35 m
## de profundidade e 0,75 de largura, entao num ponto encostado na parede do degrau
## vizinho a AABB ja nasce dentro do solido -- e encaixado, todo eixo do integrador
## colide e o bicho congela ali (medido em 2 dos 5 lobos do spawn). O ponto so vale
## com o volume inteiro livre.
func _volume_clear(feet: Vector3, dims: Vector3) -> bool:
	var box := AABB(feet - Vector3(dims.x * 0.5, 0.0, dims.z * 0.5), dims)
	return not world.aabb_hits_solid(box)


func targets_under_crosshair() -> Array:
	var out: Array = []
	for w in wolves:
		if w.alive:
			out.append(w)
	return out


func wolves_roster() -> Array:
	return wolves


## A matilha do lobo, no formato do dossie 10 §3.1: os vivos a menos do raio de
## coesao, cada um como `{identity, pos, intent, hp_ratio, trust}`. Devolve o
## buffer da sessao, nunca uma copia -- e o que permite a leitura de 20 Hz sem
## alocar.
func pack_of(identity: int) -> Array:
	var buf: Variant = _pack_buffers.get(identity)
	return EMPTY_PACK if not (buf is Array) else buf


## Uma passada por passo, aqui e nao cinco vezes dentro dos lobos: cada par i<j e
## testado uma unica vez (10 comparacoes com cinco lobos) e escrito nos dois
## buffers. O cursor e o proprio tamanho do buffer no passo anterior, cortado no
## fim para a lista nunca mostrar um vizinho fantasma.
func _rebuild_packs() -> void:
	for w: Wolf in wolves:
		_pack_cursor[w.identity] = 0
	_pack_pairs = 0
	var r2: float = PACK_COHESION_RADIUS * PACK_COHESION_RADIUS
	for i in wolves.size():
		var a: Wolf = wolves[i]
		if not a.alive:
			continue
		var ca: Vector3 = a.center()
		for j in range(i + 1, wolves.size()):
			var b: Wolf = wolves[j]
			if not b.alive:
				continue
			_pack_pairs += 1
			if ca.distance_squared_to(b.center()) > r2:
				continue
			_pack_put(a.identity, b)
			_pack_put(b.identity, a)
	for w: Wolf in wolves:
		_pack_slot(w.identity).resize(int(_pack_cursor[w.identity]))


func _pack_slot(identity: int) -> Array:
	if not _pack_buffers.has(identity):
		_pack_buffers[identity] = []
	return _pack_buffers[identity]


## A entrada e reescrita no lugar: depois do primeiro passo aquecido o lote copia
## cinco campos por vizinho e nao cria nenhum contenedor novo.
func _pack_put(identity: int, other: Wolf) -> void:
	var buf: Array = _pack_slot(identity)
	var n: int = int(_pack_cursor[identity])
	var e: Dictionary = {}
	if n < buf.size():
		e = buf[n]
	else:
		buf.append(e)
	e["identity"] = other.identity
	e["pos"] = other.center()
	e["intent"] = other.intent
	e["hp_ratio"] = other.hp / other.max_hp()
	# O trust vem como escalar ja publicado pelo lobo: um `mind.trust()` por par
	# custaria um `str(ator)` novo por comparacao no caminho quente (dossie 10 §4).
	e["trust"] = other.trust_toward_player
	_pack_cursor[identity] = n + 1


func _reap_corpses() -> void:
	for i in range(wolves.size() - 1, -1, -1):
		var w: Wolf = wolves[i]
		if w.finished():
			wolves.remove_at(i)
			# O buffer do morto sairia do rebuild e ficaria orphan no Dictionary para
			# sempre; a identidade nao e reutilizada, entao a limpeza e aqui.
			_pack_buffers.erase(w.identity)
			_pack_cursor.erase(w.identity)
			w.queue_free()
			# A vaga nasce com a toca do morto (dossie 16 §3.3): e aqui, e nao no
			# momento do spawn, que "a toca que perdeu" passa a existir.
			_respawn_queue.append([RESPAWN_DELAY, w.den])


# ------------------------------------------------------------------ ecos do mundo

## O vies de bioma e do chamador, nao do campo: `AetherField.imprint` continua
## sem saber que existe voxel, e e a fronteira que mantem a difusao barata
## (dossie 09). A pergunta ao gen so roda em evento (lavra, colocacao, dano,
## morte, respawn), nunca no tick de 20 Hz.
func _imprint(pos: Vector3, ch: int, amount: float) -> void:
	var h: int = world.gen.surface_height(int(pos.x), int(pos.z))
	aether.imprint(pos, ch, amount * world.gen.imprint_bias(int(pos.x), int(pos.z), h, ch))


func _on_acted(kind: String, pos: Vector3) -> void:
	match kind:
		"break":
			_imprint(pos, AetherField.Channel.WORK, 0.42)
		"place":
			_imprint(pos, AetherField.Channel.WORK, 0.20)


func _on_block_broken(pos: Vector3i, block: int) -> void:
	stats["mined"] += 1
	if block == BlockDefs.Block.BENCH:
		_benches.erase(pos)


func _on_block_placed(pos: Vector3i, block: int) -> void:
	stats["placed"] += 1
	if block == BlockDefs.Block.BENCH and not _benches.has(pos):
		_benches.append(pos)


## As bancadas do jogador, em blocos: a lista que `Player.bench_near()` varre.
func bench_positions() -> Array[Vector3i]:
	return _benches


func _on_notice(text: String) -> void:
	hud.show_message(text)


func hud_panel_changed(open: bool) -> void:
	hud.show_panel(open)


func _on_attacked(target: Node3D, amount: float) -> void:
	if target is Wolf:
		(target as Wolf).take_damage(amount, Wolf.ACTOR_PLAYER, player.position3())


func _on_damaged(_amount: float, _from: Vector3) -> void:
	_imprint(player.position3(), AetherField.Channel.BLOOD, 0.22)


func _on_player_died(at: Vector3) -> void:
	stats["deaths"] += 1
	_imprint(at, AetherField.Channel.BLOOD, 1.3)
	_imprint(at, AetherField.Channel.FEAR, 1.0)
	hud.set_death(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_wolf_bit(w: Wolf, amount: float) -> void:
	player.take_damage(amount, w.center())
	if not player.alive:
		w.on_kill(Wolf.ACTOR_PLAYER)


func _on_wolf_died(_w: Wolf, _pos: Vector3) -> void:
	# O contador fica: e ele que a suíte e o F3 leem (`stats["wolves_felled"]`), e
	# nenhuma das duas precisa de um letreiro para existir. Sai só a frase
	# (dossie 14 §1.3) -- o sangue no Éter é o aviso, e quem tem que vê-lo é o
	# jogador, não a HUD.
	stats["wolves_felled"] += 1


func _toggle_debug() -> void:
	hud.show_debug(not hud.debug_visible())


func _toggle_ether() -> void:
	viz.show_view(not viz.showing())
	if viz.showing():
		viz.refresh()


# ------------------------------------------------------------------ persistencia

func save_game() -> void:
	var edit_list := {}
	for k in world.edits:
		edit_list[Coords.block_key(k)] = int(world.edits[k])
	var minds: Array = []
	for w in wolves:
		minds.append(w.state_dict())
	# As tocas vao como triplet de numeros, nao como Vector3: o disco e JSON
	# (`JSON.stringify`), e um objeto sem leitor no JSON e lido como null. `home` e
	# `feet` dos bichos ja seguem esse formato.
	var dens: Array = []
	for dc: Vector3 in _dens:
		dens.append([dc.x, dc.y, dc.z])
	var data := {
		"schema": SaveManager.SCHEMA,
		"gen_version": WorldGen.GEN_VERSION,
		"seed": SEED,
		"tick": clock.tick,
		"elapsed": elapsed,
		"stats": stats,
		"edits": edit_list,
		"aether": aether.to_dict(),
		"inv": player.inv.to_dict(),
		"player": {
			"feet": [player.body.feet_pos.x, player.body.feet_pos.y, player.body.feet_pos.z],
			"yaw": player.yaw, "pitch": player.pitch, "hp": player.hp,
			"deaths": player.deaths,
		},
		"wolves": minds,
		"dens": dens,
	}
	var res := SaveManager.write_slot(SLOT, data)
	if res["ok"]:
		hud.show_message("mundo gravado  %d bytes  %.1f ms" % [res["bytes"], res["ms"]])
	else:
		hud.show_message("falha ao gravar: %s" % res["error"])


func load_game() -> void:
	var res := SaveManager.read_slot(SLOT)
	if not res["ok"]:
		hud.show_message("carregar: %s" % res["error"])
		return
	var d: Dictionary = res["data"]
	if int(d.get("gen_version", -1)) != WorldGen.GEN_VERSION:
		hud.show_message("save de gerador antigo: recrie o mundo")
		return
	if tick_journal.active():
		tick_journal.close()
		print("journal encerrado antes do load: ", tick_journal.path)
	# Dossie 11 §3.6: o teto de censo vale no load tambem, e a recusa vem antes de
	# qualquer escrita no mundo -- metade do load aplicada seria pior que nenhum
	# load, e truncar o excedente em silencio e o mandato 1 violado (nada de
	# fallback que finja sucesso). A conta e so `size()`: nenhuma chave do disco e
	# tocada aqui, senao o mundo seria regenerado para uma sessao recusada.
	var saved: Array = d.get("wolves", [])
	if saved.size() > CENSUS_CAP:
		print("load RECUSADO: censo %d acima do teto %d" % [saved.size(), CENSUS_CAP])
		_census_refusals += 1
		hud.show_message("save com %d bichos: teto %d, nada mudado" % [saved.size(), CENSUS_CAP])
		return
	world.generate(SEED)
	var edit_list := {}
	for k in d.get("edits", {}):
		edit_list[String(k)] = int(d["edits"][k])
	world.apply_edits(edit_list)
	var p: Dictionary = d.get("player", {})
	player.feet_to_spawn(Vector3(float(p["feet"][0]), float(p["feet"][1]), float(p["feet"][2])))
	player.yaw = float(p.get("yaw", 0.0))
	player.pitch = float(p.get("pitch", 0.0))
	player.hp = float(p.get("hp", player.max_hp))
	player.deaths = int(p.get("deaths", 0))
	if player.hp <= 0.0:
		player.hp = player.max_hp
	player.alive = true
	hud.set_death(false)
	player.spawn_point = player.position3()
	# `inv` e aditivo: save de antes nao tem o campo, e quem nao tem fica com o kit
	# em vez de um inventario vazio (o jogador nao acordaria sem blocos).
	if d.has("inv"):
		player.inv.from_dict(d["inv"])
	else:
		player.inv.reset_default()
	_rebuild_benches()
	audio.clear_transient()
	aether.from_dict(d.get("aether", {}))
	# Dossie 16 §5.9: a toca e lugar, e lugar e estado da sessao. Sem esta chave no
	# disco o load fundaria tocas NOVAS sobre as colunas que ja tem dono, e o lobo
	# carregado acordaria sem toca num mapa com tres lugares gravados. O default
	# aditivo e o contrario do inventado: disco anterior a perna nao tinha toca,
	# entao `_dens` fica vazio e cada bicho vem `den = -1` (`load_state`), sem que
	# nenhum lobo nasca de fora do censo gravado. Vem antes do pareamento porque a
	# pertenca lida do disco so faz sentido contra os centros restaurados.
	_dens.clear()
	for a: Array in d.get("dens", []):
		_dens.append(Vector3(float(a[0]), float(a[1]), float(a[2])))
	# Dossie 11 §3.6: o censo do disco e a autoridade, e o pareamento e por
	# identidade. Eram `mini(saved.size(), wolves.size())` -- dois erros no mesmo
	# numero, os dois impressos em `censo do disco`: sobrava bicho no disco que
	# nunca chegava ao mundo (`disco=6 depois=5`), e o que chegava era posto no
	# corpo do vizinho pela posicao do array (`mentes=[1<-0 2<-1 ...]`), com a
	# memoria de outro lobo dentro e o journal hashando um no corpo do outro.
	var vivos := {}
	for w: Wolf in wolves:
		vivos[w.identity] = w
	var lidos := {}
	var maior_id := -1
	for e: Dictionary in saved:
		var id: int = int(e["identity"])
		lidos[id] = e
		maior_id = maxi(maior_id, id)
	_load_retired = 0
	_load_created = 0
	for i in range(wolves.size() - 1, -1, -1):
		var w: Wolf = wolves[i]
		if lidos.has(w.identity):
			w.load_state(lidos[w.identity])
			continue
		# O bicho que a sessao tem e o disco nao tem nao pode ficar: ele voltaria
		# como um nascimento nao registrado, e o censo carregado deixaria de ser o
		# censo gravado -- a mesma conta que a premissa 1 do dossie recusa.
		_retire_wolf(w)
		_load_retired += 1
	for e: Dictionary in saved:
		var id: int = int(e["identity"])
		if vivos.has(id):
			continue
		var feet := Vector3(
				float(e["feet"][0]), float(e["feet"][1]), float(e["feet"][2]))
		var w := _make_wolf(feet, id, Wolf.phase_of_save(int(e.get("phase", Wolf.Phase.ADULT))),
				int(e.get("age_ticks", Wolf.JUVENILE_STEPS)))
		w.load_state(e)
		wolves.append(w)
		_load_created += 1
	# A ordem do array e so a ordem de criacao; o que a checagem confere e o
	# conjunto de identidades, entao ordenar por identidade nao muda nenhum numero
	# medido e faz o F3 e o `wolves_roster` do audio lerem a matilha na mesma ordem
	# com que o disco a gravou.
	wolves.sort_custom(func(a: Wolf, b: Wolf) -> bool: return a.identity < b.identity)
	# A vaga de reposicao e da sessao que gravou, nao desta: deixar um pedido na
	# fila seria inventar um setimo bicho contra o censo do disco (medido em
	# `censo do disco`: fila=1 com o mundo ja recarregado, teto=6 no disco).
	_respawn_queue.clear()
	# A identidade mais alta do disco nao pode ser sorteada de novo: dois bichos
	# com a mesma identidade quebrariam o pareamento do proximo load e o journal
	# (que ordena minds por identidade) deixaria de ser uma funcao do estado.
	_next_identity = maxi(_next_identity, maior_id + 1)
	clock.tick = int(d.get("tick", 0))
	elapsed = float(d.get("elapsed", 0.0))
	world.generate_meshes_all()
	hud.show_message("mundo reload  tick %d  %.1f ms" % [clock.tick, res["ms"]])


## Revarre as edicoes atrás das bancadas depois de um load: a lista e derivada do
## mundo, e um mundo recarregado sem ela deixaria o jogador craftar "na mao" do
## outro lado do mapa.
func _rebuild_benches() -> void:
	_benches.clear()
	for k in world.edits:
		if int(world.edits[k]) == BlockDefs.Block.BENCH:
			_benches.append(k)


func stats_line() -> String:
	return "jogador  minerado %d  colocado %d  mortes %d   inventario %d itens  %d bancadas   lobos vivos %d/%d   recriacoes %d" % [
		stats["mined"], stats["placed"], stats["deaths"],
		player.inv.item_count(), _benches.size(),
		targets_under_crosshair().size(), wolves.size(), _respawn_queue.size()]


func diagnostics() -> Dictionary:
	return {
		"gen_ms": _gen_ms, "mesh_ms": _mesh_ms,
		"chunks": world.chunks.size(), "meshes": world.meshes_built(),
		"edits": world.edits.size(), "aether_energy": aether.total_energy(),
		"wolves": wolves.size(), "wolves_alive": targets_under_crosshair().size(),
		"pack_pairs": _pack_pairs,
		# Dossie 16 §7d: a toca sai como lugar (quantos centros, a separacao entre
		# eles) e como leitura (quantos grupos o grafo de coesao realmente forma).
		# `den_components` e o numero que substitui a igualdade aritmetica de
		# `pack_pairs` como palavra sobre coesao -- ver o furo #21 no status.
		"dens": _dens.size(), "den_min_dist": den_min_dist(),
		"den_components": den_components(),
		"pending_respawns": _respawn_queue.size(), "triangles": world.triangle_count(),
		# Dossie 07 §4: o preco de uma edicao local ate o mesh pronto dela. Sem essa
		# coluna a tabela do bake-off teria so o custo do lote de boot e decidiria o
		# mesher sem o lado do jogador na mesa.
		"edit_mesh": world.edit_mesh_cost(),
		# Dossie 11 §3.6: o censo que o disco trouxe, quantos nasceram dele e quantos
		# sairam, e quantas vezes o teto disse nao. Sem esses tres numeros a recusa
		# seria uma linha impressa uma vez e nada lido -- o mandato 1 nao aceita
		# "censo parado no teto" como estado silencioso.
		"census_cap": CENSUS_CAP, "load_created": _load_created,
		"load_retired": _load_retired, "census_refusals": _census_refusals,
		"births": _births,
		"tick": clock.tick, "worst_sim_ms": clock.worst_step_ms,
		"dropped_ticks": clock.dropped_ticks, "hp": player.hp,
		"on_ground": player.body.on_ground, "feet": player.body.feet_pos,
		"journal": tick_journal.diagnostics(),
		# Dossie 23 §3.6: o teto do FX e aritmética dos `amount` declarados e os
		# vivos da janela sao lidos aqui — sem esta linha o orcamento seria adjetivo.
		"water_fx": water_fx.diagnostics() if water_fx != null else {},
		# O host so existe fora de headless (dossie 15 §4.6): na suíte a linha e
		# vazia, e e exatamente esse o numero que a checagem 8 espera.
		"llm": llm_host.diagnostics() if llm_host != null else {},
	}


# ------------------------------------------------------------------ ceu & luz

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42.0, 55.0, 0.0)
	sun.light_energy = 1.60
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	# A luz direcional viaja pelo -Z do no, entao o +Z e a direcao PARA o sol. O `.y`
	# dela e o seno da elevacao, e e isso que a agua pergunta (dossie 23 §2).
	_sun_dir = sun.global_transform.basis.z

	var prog := ProceduralSkyMaterial.new()
	prog.sky_top_color = Color(0.30, 0.50, 0.82)
	prog.sky_horizon_color = Color(0.70, 0.79, 0.87)
	prog.ground_bottom_color = Color(0.20, 0.22, 0.26)
	prog.ground_horizon_color = Color(0.70, 0.79, 0.87)
	var sky := Sky.new()
	sky.sky_material = prog

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	# Neblina mais densa e mais escura que o ceu: A/B na pose do spawn (bandas de
	# luminancia) mostrou mais contraste no terreno sem lavar o horizonte.
	env.fog_light_color = Color(0.55, 0.65, 0.78)
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)


func state_hash() -> String:
	return Journal.state_hash(clock.tick, world, aether, wolves)


func _start_journal_from_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tick-journal="):
			var err := tick_journal.start(arg.trim_prefix("--tick-journal="))
			if err != OK:
				push_error("abrir journal: %s" % error_string(err))
				get_tree().quit(1)
			return


func _exit_tree() -> void:
	tick_journal.close()
