# Dossiês por item da fila

Vinte e um arquivos, um por linha aberta da fila de [`docs/melhorias-status.md`](../melhorias-status.md)
("Falta", `:610-812`, e os checklists P0/P1, `:813-837`). Cada dossiê é **leitura de código, não
corrida**: nenhuma engine foi rodada aqui, nenhum número publicado foi re-medido por estes arquivos
e **nenhum gate de fase se fecha por eles** — quem abre e fecha gate é o dono
([`AGENTS.md`](../../AGENTS.md), mandato 4). Marcas `[TARGET]` / `[CLAIMED]` / `[MEASURED]` /
`[DECIDED]` / `[OPEN]` seguem a legenda de [`docs/design/README.md:10-16`](../design/README.md#L10-L16).
Os sete últimos (09 → 10 → 15 → 14 → 11 → 12 → 13) existem porque o dono ampliou o escopo em 2026-11-20 —
bioma/cor, alcateia, oráculo embutido no boot, convivência da matilha, acasalamento com filhote, bicho
cavando e a árvore genealógica com o Éter lendo parentesco — e a ordem serializada deles está escrita na
mesma seção do contrato, não deduzida depois. Os dois que faltavam chegaram em 2026-11-21, por dois
prompts do dono ("Física de Blocos + Mundo Reativo" e "Física de Blocos + Mundo Vivo"): **17** fica com a
grave dos blocos que caem e **18** com a grama que cresce e o mato. O número **16 estava reservado**
e agora **tem página** ([16-tocas-da-alcateia.md](16-tocas-da-alcateia.md)): é o pedido dele de espalhar
a matilha em 2–3 tocas depois de ter percorrido o mapa inteiro vendo um lobo só, e ela ficou na posição
que ele escolheu (logo depois da 11). A regra que o índice se dava — "antes de abrir branch, escreve-se
o dossiê" — estava cumprida naquele dia: a página existia, a branch **não**; ela abriu em 2026-11-22 e o código da perna está nela.
No mesmo dia o pedido urgente dele abre a **19**, e ela é de outro tipo: não é mecânica nova, é **defeito do
jogo em execução** — lobos pulsando encostados num talude de um bloco e o jogador parado na frente de um
degrau que ele não sobe sem apertar espaço. Por isso ela fura a fila e entra logo depois da 11, com a
exceção e o motivo escritos no §7 da própria página e no contrato antes de qualquer linha. No mesmo dia 22,
o dono manda abrir a **20**, e ela é a mais larga já registrada: sete entregas — alcance calculado, memória
de falha, tabela de espécie, três grupos de criaturas, drops, troféu colocável e os testes disso — sobre seis
arquivos que a fila já escreve. Por isso a página 20 entrega o **corte**, não a lista: cada §3 nomeia a
decisão, o braço rejeitado e o número que reabre o braço. No dia 23 o dono amplia de novo, agora só de IA —
o prompt "Aetherfall: Elevação da IA Local para Outro Nível", cinco fases — e a **22**
([22-oraculo-nativo-gdextension.md](22-oraculo-nativo-gdextension.md)) é a pauta dessa ampliação: o transporte
do oráculo sai do HTTP e passa a ser uma extensão C++ com llama.cpp dentro do processo, com a regra de ouro
dele escrita como cláusula verificável (nenhuma camada de linguagem move pé, aplica dano ou escreve no
ledger). É a primeira página do índice que **mede** alguma coisa antes de existir código: o §1 dela é a Fase 0
rodada — toolchain, as DLLs do runtime carregando in-process e vendo a RX 9060 XT, os export-sets contados e
o cabeçalho de interface gerado. Nenhuma das
páginas novas fecha escopo: elas registram a pauta, e o registro vem antes do código.

| # | Dossiê | Linha da fila | Premissa nomeada | O que decide, em headless |
|---|---|---|---|---|
| 01 | [Estado inicial, comandos, RNG e ordem autoritativa](01-estado-inicial-e-ordem-autoritativa.md) | P0 `:436`, Falta 2 `:310-319` | o diário tem duas portas: o hash do tick N não é função só do tick N | `snapshot_resta_hash`, `ordem_independente_de_quadros` (nasce **vermelho**, com o número real de ticks divergentes), `rng_restaurada_no_load`, `formato_declarado` |
| 02 | [Censo do lobo em 20 sementes × 1000 ticks](02-censo-multi-semente.md) | P1 `:446`, Falta 3 `:320-321` | cadência sintética, não relógio de parede | `repeticao_por_semente` 20/20 e `contraste_de_cadencia` (K = 1 vs K = 3 tem de **divergir**; se não divergir a checagem é vazia) |
| 03 | [Canais MORTE / SOM / FOGO](03-canais-morte-som-fogo.md) | P1 `:444`, Falta 4 `:322-330` | um canal só existe se fonte e curva leitora caírem no mesmo lote | A/B com o canal zerado mudando `intent` ou `_reaction`; recusa de índice de canal fora de faixa; `Channel.COUNT` puxa `FORMAT_VERSION`. **FOGO fica bloqueado** sem bloco/entidade de fogo |
| 04 | [Budget HOT medido](04-budget-hot-medido.md) | P1 `:445`, Falta 5 `:331-335` | "2,5 ms medido" embute duas metade não medidas: cinco mentes no mesmo tick e o segmento de decisão inteiro | checagem (a): se nenhum tick teve as cinco mentes vivas, vermelho em vez de zero; `EXPECTED_CHECKS` (`tests/aether_reactions_test.gd:60`, 119 na leitura daquele dossiê) sobe com o lote |
| 05 | [Difusão do Éter fora do tick](05-difusao-fora-do-tick.md) | P1 `:447`, Falta 6 `:336-338` | hoje a difusão é síncrona e o lobo vê o resultado por isso | primeiro a colheita (nenhum µs de `diffuse_and_decay` existe); o corte só com o hash por semente **inalterado** |
| 06 | [Decompor `main.gd` pelo eixo do dono](06-decompor-main-gd.md) | Falta 7 `:339-341` | ônibus não é dono: um bloco vira dono quando já tem comprador fora de `main.gd` | K1 bancadas → K2 fila/cadáveres → K3 matilha; K4 (persistência) fica `[OPEN]` até aparecer o segundo consumidor |
| 07 | [`af-bench`, bake-off de voxel e o doc do `SimClock`](07-af-bench-bake-off-voxel-e-doc-do-simclock.md) | P0 `:437`, `:438-439`, `:440` | três premissas, uma por peça; hash é função do passo, fps é função da máquina | ordem interna: doc → runner de `dt` fixo → 3 execuções de 12 000 ticks → bake-off com ≥ 2 braços tabelados |
| 08 | [`MindStore` e `MindsInspector`](08-mindstore-e-mindsinspector.md) | P1 `:448-449`, `:450-451` | `MindStore` muda **posse**, `MindsInspector` mostra **composição** — nenhuma das duas decide | recomendação lida: F3 estendido (reaproveita `src/main.gd:1152-1158` e `src/ui/hud.gd:273-280`) antes de qualquer `.tscn` novo |
| 09 | [Bioma, cor do pelo e fundo de Éter por bioma](09-bioma-cor-de-pelo-e-ether.md) | Falta 8 `:342-356` | bioma só existe se decidir algo observável: cor do pelo e viés de imprint; derivar **não** pode alterar terreno nem hash | `bioma_deterministico`, `bioma_nao_altera_terreno` (a que fecha o lote), `cor_do_pelo_vem_do_bioma`, `imprint_bioma_tem_mesma_ordem` |
| 10 | [Rotinas de alcateia](10-alcateia-rutinas.md) | Falta 9 `:357-363` | a intenção de um lobo muda quando outro está por perto — 1 lobo vs 4 lobos no mesmo cenário tem de **divergir** | `contraste_de_alcateia`, `cercar_calcula_assentos`, `ataque_escalonado`, `medo_contagia` / `amigo_amortece`, `alcateia_nao_consome_rng_da_sessao` |
| 11 | [Acasalamento, filhote que cresce e censo variável](11-acasalamento-filhote-e-censo.md) | Falta 10 `:364-371` | um save gravado com 7 lobos carrega 7 lobos — e crescer é função do `clock.tick`, não de parede | `acasalar_aumenta_censo`, `cooldown_segunda_copula`, `filhote_cresce_por_tick`, `filhote_nao_morde`, `load_leva_todo_o_censo` (nasceu **vermelha**, verde depois do load que pareia por identidade), `censo_respeita_teto`, `journal_hash_inalterado_sem_escolha` — **pousada**: `main` `5b519f8`, runner **225 / 0**, suíte **252 / 0** |
| 12 | [Bicho cavando voxel](12-bicho-cavando-voxel.md) | Falta 11 `:372-380` | um voxel **gerado** some por ação do lobo **sem input do jogador**, fica em `world.edits`, e a malharia disso é medida antes de ser celebrada — com a cláusula de proveniência que impede o bicho de desfazer obra alheia | `lobo_cava_sem_input_do_jogador`, `cavar_respeita_a_lista` (com braço `GLASS`: lista é material, não dureza), `work_de_bicho_nao_confundido`, `malharia_do_cavar_medida`, `abrir_passagem_depois_de_bloqueio` (é ele que decide os 8 passos do §3.2.a), `entrada_de_rastro_exposta_no_chao_lido`, `cavar_nao_toca_construcao_alheia` (paga o furo #22), `cavar_sobrevive_ao_save`, `cavar_nao_consome_rng_da_sessao` — **código escrito**: a pauta foi re-escrita em 2026-11-22 sobre a árvore da 19, a branch abriu da `main` de `dcbcbe8` e os itens (a)→(g) estão nela com ponta de código `d80ac20`; as **nove** checagens da coluna anterior estão no runner com censo **283 / 0** e a suíte parada em **255 / 0** (clone limpo de `d80ac20`, medido) — **pousada**: merge `fa94cb5` na `main`, (h) é o registro do pouso, e a árvore mergida re-rodada dá **255 / 0** duas vezes, runner **283 / 0**, RNG **27 / 0**, journal **128 / 0** |
| 13 | [Árvore genealógica de todo ser vivo, e o Éter lendo parentesco](13-arvore-genealogica-e-ether.md) | Falta 13 `:411-430` | ascendência só existe se nascer de dois adultos, sobreviver ao save e **mudar algo observável**; herdar é genoma-base, nunca a memória nem o trauma do pai | `genealogia_muda_algo_observavel` e `load_preserva_ascendencia` (nascem **vermelhas**), `pelo_de_fundador_vem_do_bioma`, `heranca_nao_repete_deriva`, `eter_devolve_quem_sangrou`, `journal_hash_inalterado_sem_nascimento`, `genealogia_nao_consome_rng_da_sessao`, `ascendencia_e_int_nao_referencia` |
| 14 | [Convivência da alcateia: terra seca, matilha legível e spawn fora dos olhos](14-convivio-da-alcateia.md) | Falta 12 `:381-410` | seco é regra de validade do **alvo** (água é último recurso); "organizado" é teto numérico, não adjetivo; criatura nunca vira texto; spawn nunca a menos de `SAFE_SPAWN_DIST` nem com LOS livre | `lobo_escolhe_trilha_seca`, `resgate_de_margem_sobrevive_a_arvore` e `spawn_fora_da_vista_do_jogador` (nascem **vermelhas**), `nadar_so_sem_saida_seca`, `dois_lobos_nao_farejam_a_mesma_celula`, `alvo_estavel_por_segundo`, `nenhum_aviso_de_matilha_no_hud` + `feedback_do_jogador_continua_no_hud` (par obrigatório), `convivio_nao_estoura_orcamento` |
| 15 | [Oráculo embutido no boot: o jogo levanta o llama-server](15-oraculo-embutido-no-boot.md) | autorização nova do dono em 2026-11-20, fora da lista `Falta` do status | com `Rodar.bat` e **nenhum** PowerShell aberto, a linha `ia:` do F3 enche dentro do prazo da cena de prova | `host_devolve_health_200`, `boot_nao_bloqueia_janela`, `reuso_nao_cria_segundo_processo`, `porta_alheia_continua_viva`, `fechar_janela_mata_o_filho`, `suite_nao_levanta_modelo` — colhidas em cena própria, nunca na suíte |
| 16 | [Tocas da alcateia: o mapa que a matilha nunca ocupou](16-tocas-da-alcateia.md) | número **reservado** pelo pedido do dono em 2026-11-21, fora da lista `Falta`; a página foi escrita **antes** de abrir branch, como o §"Uma branch por dossiê" exigia | a matilha nasce, reproduz e é reposta dentro de **um único círculo de 18 m**, e a caixa útil do mapa é 116 × 116 m — por isso ele percorreu o vale inteiro e viu um lobo só | `tocas_distintas_no_boot` (nasceu **vermelha** contra `99d1167`: `_pack_leash()` ainda ancorava tudo no primeiro vivo) e `nenhum_lobo_le_de_outra_toca` (o par anti-farsa), `cada_toca_e_um_lugar_valido`, `reposicao_volta_para_a_toca_perdida`, `nascimento_fica_na_toca_dos_pais`, `toca_nao_deriva_para_unica` (o braço A/B do §3.4 decidido por número, não por gosto), `esgotamento_de_lares_forcado` (paga o furo #18), `toca_sobrevive_ao_save`, `assinatura_de_populacao_estavel` |
| 17 | [Física de blocos que caem (o evento que ninguém assina)](17-fisica-de-blocos-que-caem.md) | autorização do dono em 2026-11-21, prompt "Física de Blocos + Mundo Reativo" item A; a especificação já estava no doc 10, o código não | um `SAND` sem apoio **some** do grid num tick e **reaparece** mais baixo noutro, `queued` volta a zero e **nenhuma varredura do mapa** aconteceu no meio | `queda_sem_varredura_de_mundo`, `queda_move_a_celula` (nasce **vermelha**: `block_changed` não tem um `.connect(` em lugar nenhum), `queda_cascade_em_passos`, `bloco_em_queda_nao_sobe` (o *auto step-up* do `VoxelBody` tem de ser zerado), `queda_pousa_antes_do_save`, `queda_nao_custou_tempo_de_ninguem`, `journal_hash_muda_so_com_movimento` |
| 18 | [Mundo vivo: grama que cresce e o mato decorativo](18-mundo-vivo-grama-e-mato.md) | autorização do dono em 2026-11-21, prompt "Física de Blocos + Mundo Vivo" itens B e C; **sem** especificação no doc 10 — esta página é a primeira vez que a regra é escrita | `DIRT` com ar acima e `GRASS` ao lado vira `GRASS` em tempo finito **sem varrer nada** — e sem vizinha não muda em 10 000 ticks | `grama_precisa_de_vizinha` (o par vermelho), `crescimento_nao_varre_nada`, `crescimento_sobrevive_ao_save`, `grama_nao_cresce_onde_nao_ha_grama`, `crescimento_nao_estoura_a_malha`, `mato_e_nao_solidez_nem_pedra`, `mato_nao_engole_o_clique` (o campo `substituivel` lido pelo `_try_place`), `crescimento_nao_consome_rng_da_sessao` |
| 19 | [Pulo de bloco: o degrau de 1 m que ninguém sobe](19-auto-pulo-de-bloco.md) | **defeito** pedido pelo dono em 2026-11-21 como urgente, fora da lista `Falta` — não é mecânica nova; a fila serializada ganha a exceção de ordem no §7 | um corpo que anda contra um degrau de **exatamente um bloco** sobe o degrau (o jogador sem tecla nenhuma), e um corpo que anda contra parede mais alta que um bloco **não** gasta salto | `degrau_de_um_bloco_lobo_sobe` e `degrau_de_um_bloco_jogador_sobe_sem_tecla` (nascem **vermelhas**: ápice 0,563 m e `step_up` 0,62 contra uma célula de 1,00 m), `penhasico_nao_gasta_salto` (a asserção que o dossiê lia em `aether_reactions_test.gd:1063`, re-derivada hoje em `:1132`, lida do outro lado), `agachado_nao_e_arremessado`, `predicado_degrau_recusa_teto_baixo`, `pulo_nao_custou_passo_de_ninguem` |
| 20 | [Mentes autônomas de mobs e o mundo que respira sem input](20-mente-autonoma-de-mobs-e-ecossistema.md) | autorização nova do dono em 2026-11-22, prompt "Inteligência Autônoma de Mobs + Ecossistema Vivo"; item 14 de `Falta` | um corpo que persegue sabe, **por número**, se a coluna à frente cabe no ápice que o próprio corpo alcança — e espécie só existe se muda um número observável por criatura; matar devolve item por **tabela**, não por sorteio escondido | 18 checagens nomeadas no §5, e **todas nascem vermelhas** porque nenhuma das peças existe: `alcance_calcula_altura` (a sonda de hoje testa `+1.0` fixo), `desistencia_vira_crenca`, `estrategia_muda_por_numero`, `especie_decide_numero`, `arvore_por_arquetype` (paga o furo **#24**), `passaro_pousa_em_copa`, `bando_tem_teto_e_o_passo_caibo`, `lobo_morto_dropa_carne` (vermelho contra a árvore de hoje: **zero** drop em `src/`), `trofeu_e_colocavel_e_nao_e_ancora`, `aves_nao_movem_o_censo_da_matilha`, `decisao_nao_vem_do_oraculo`, `journal_hash_inalterado_sem_especies_vivas` — **nenhuma linha de código escrita** |
| 22 | [Oráculo nativo em GDExtension: llama.cpp dentro do processo](22-oraculo-nativo-gdextension.md) | autorização nova do dono em 2026-11-23, prompt "Aetherfall: Elevação da IA Local para Outro Nível" (cinco fases); na fila serializada ela entra **depois da 18 e antes da 20** | o transporte do oráculo hoje é `HTTPRequest` em GDScript para um `llama-server` levantado como processo à parte — e a regra de ouro do dono é que nenhuma camada de linguagem move pé, aplica dano ou escreve no ledger | `extensao_carrega_classe` (nasce **vermelha**: `native/af_mind/` não existe), os três números do load (`af_vram_gb`, `af_load_ms`, `af_ctx_cells`), `transporte_http_zerado` (`grep -rn HTTPRequest src` devolve vazio), `af_cache_determina_replay`, `budget_do_oraculo_nao_estoura_a_arvore` e `af_sem_rede_no_tick`. A **Fase 0 está medida**, não prometida: MSVC 19.44.35207 compila C++17, as cinco DLLs do runtime carregam in-process e veem a RX 9060 XT (`reg_count` 3), e os export-sets contados são 266 · 689 · 16 · 9 · 53 — de onde sai a cláusula de *link* do §1.3 e o motivo pelo qual `model_oversave` vira `[OPEN]` |

## Uma branch por dossiê

Cada linha da fila abre na sua própria branch, e a `main` só recebe `--no-ff` — regra e
comandos em [`AGENTS.md`, "Branches: um ajuste por linha de história"](../../AGENTS.md). O nome
carrega o número do dossiê para o histórico responder sozinho o que foi feito:

| Dossiê | Branch | Base |
|---|---|---|
| 01 | `feat/estado-inicial-replay-01` | `main` |
| 02 | `test/censo-multi-semente-02` | `main` (depois de 01: o censo usa o driver de `dt` fixo) |
| 03 | `feat/canais-morte-som-fogo-03` | `main` |
| 04 | `perf/budget-hot-medido-04` | `main` |
| 05 | `perf/difusao-fora-do-tick-05` | `main` (depois de 04: colheita antes do corte) |
| 06 | `refator/donos-fora-do-main-06` | `main`, K1 → K2 → K3 |
| 07 | três branches, na ordem: `docs/engine-simclock-07a` → `bench/af-bench-boot-walk-07b` → `bench/bake-off-voxel-07c` (o nome único `bench/af-bench-bakeoff-07` era provisório) | `main`, serial: doc → runner → bake-off. **Pousada**: `c1e77ad` (07a), `166af71` (07b), `cea4379` (07c) |
| 08 | `feat/minds-inspector-f3-08` | `main` |
| 09 | `feat/bioma-e-cor-de-pelo-09` | `main` — **abre depois de 08 fechar**; nenhuma das outras cinco abre enquanto esta estiver aberta (`src/entities/wolf.gd` e `src/main.gd` são de escritor único) |
| 10 | `feat/alcateia-rutinas-10` | `main`, depois de 09 (a cor e o viés por bioma mudam o que a matilha lê) |
| 11 | `feat/acasalamento-e-censo-11` | `main`, depois de **14**: acasalar exige saber quem é adulto e quem está perto, e o filhote nasce pelo predicado de spawn seguro que a 14 entrega. **Pousada**: ponta de código `0762b43`, `main` publicada `5b519f8` (clone limpo medido, merge do código `4b858c2`), com o gate re-rodado depois do merge `010ab25` |
| 12 | `feat/bicho-cavando-12` | `main`, **depois de 16** (re-derivado em 2026-11-22): a 16 é quem decide onde os lares ficam e, como esta, escreve `src/main.gd` — que é de escritor único. Antes dela entraram também a 19, e isso muda o desenho: cavar passa a ser o **terceiro** ramo do `if` de bloqueio (desvia → sobe → cava), e quem cava se decide pelo alcance do corpo (`dims` do filhote é 0,45 do adulto), não por fase nem por uma folha nova na `Selector`. **Branch aberta** em 2026-11-23 da `main` no ponto atual (`dcbcbe8`), com o código de (a) a (g) e ponta de código `d80ac20`; **(h) é o fecho de docs desta ponta**, pousado em 2026-11-23 pelo merge `fa94cb5` |
| 13 | `feat/arvore-genealogica-13` | `main`, **por último**, depois de 18: sem a 11 não há nascimento por causa interna (o que escrever na árvore) e sem a 10 não há leitura de vizinho (como parentesco vira comportamento) — e se o Éter ganhar canal novo, re-mediar as pernas anteriores é mais barato do que deixar `Channel.COUNT` no meio da fila |
| 14 | `feat/alcateia-convivio-14` | `main`, depois de 10 e **antes** de 11: mexe nas mesmas folhas de movimento que a alcateia reorganizou, e o predicado "longe dos olhos do jogador" tem de existir antes de alguém precisar dele para pôr um filhote no mundo |
| 15 | `docs/oracle-embutido-15` (estes dois commits) → `feat/oraculo-embutido-no-boot-15` (código) | `main`, **entre 10 e 14**: a 15 não encosta em nenhuma linha do código da matilha nem das outras pernas — em `src/main.gd` só pendura um nó novo no boot — enquanto a 14 depende da ronda por setor que a perna 10 já escreveu e pousou (código `0c38489`, `main` publicada `b779cee`) |
| 16 | `feat/tocas-da-alcateia-16` | `main`, **logo depois de 19**, escolha do dono nesta fila: é a resposta a ele ter percorrido o mapa inteiro e visto um lobo só. **Dossiê escrito antes da branch** — a página existia em `e0450a3+`; a branch abriu em 2026-11-22 da `main` no ponto atual (`99d1167`) e traz o código de (a) a (g) — (h) é o fecho de docs |
| 17 | `feat/fisica-de-blocos-que-caem-17` | `main`, **depois de 12**: as duas pernas escrevem pelo mesmo `set_block` e pelo mesmo `block_changed`, e a fila de gravidade muda o custo medido do cavar — abrir a 17 antes obrigaria a 12 a re-rodar o gate dela com a fila anexada. Não encosta em `wolf.gd` |
| 18 | `feat/mundo-vivo-grama-e-mato-18` | `main`, **depois de 17**: é o segundo comprador do `BlockUpdateQueue` que a 17 escreve (regra da casa — generalizar no segundo chamador, não no primeiro), e o `PLANT` gasta o id 17 da reserva que a 17 não toca |
| 19 | `feat/auto-pulo-de-bloco-19` | `main`, **fura a fila e entra logo depois de 11** (exceção do §7 do dossiê, registrada antes do código): é o único item da lista que é defeito do jogo em execução, não mecânica nova. Encosta em `src/entities/wolf.gd` e em `tests/aether_reactions_test.gd`, os dois arquivos que a 11 também escreve — por isso a 11 re-rome o gate depois do merge desta, **e já o re-romeu** (merge `010ab25` dentro da branch, gate re-rodado na árvore resultante). **Pousada**: ponta de código `f843fa6`, `main` publicada `ab9ffa1` (clone limpo medido) — a 11 re-rome o gate a partir de `ab9ffa1` |
| 20 | `feat/mobs-autonomos-e-ecossistema-20` | `main`, **depois de 18 e antes de 13** (exceção de ordem registrada em 2026-11-22 antes de qualquer linha): as duas escrevem [`src/world/block_defs.gd`](../../src/world/block_defs.gd), a 17 gasta o id 18 e a 18 gasta o 17, e drop de criatura não pode encostar na reserva 9–18 — entra a partir de 23, na tabela que as duas acabaram de renumberar. Antes da 13 porque genealogia sobre **uma única** espécie escreveria o que já existe; a 13 continua última porque nenhuma mudança de `Channel.COUNT` cai no meio da fila. Escreve em `src/entities/wolf.gd`, `src/main.gd`, `src/items/inventory.gd`, `src/ui/hud.gd` e, se a metade sonora entrar, `src/audio/audio_director.gd`. **Dossiê escrito antes da branch** — a página existe e nenhuma linha de código dela foi escrita. **Re-derivada contra a `main` do pouso da 16** (`bb13752`): as árvores de `9b2c65a` não são as do pin `5b519f8`, o contrato de referência passa a **255 / 0** com **240 / 0** de reações, e a toca da matilha (`_dens`, `den_components`, `Wolf.den`) entra na página como fato que a 16 criou |
| 22 | `docs/pauta-oraculo-nativo-22` (esta página + o arquivo de índice + o status) → `feat/oraculo-nativo-gdextension-22` (os cinco passos de código do §5) | `main`, **depois de 18 e antes da 20** (exceção de ordem registrada em 2026-11-23 antes de qualquer linha): a 22 é transversal — escreve `src/ai/`, `native/`, `tests/` e três linhas de injeção em `src/main.gd`, e **não** escreve `src/world/block_defs.gd`, que é por onde a 17 e a 18 se empurram. Vem antes da 20 porque as duas escrevem a mesma frase de contrato sobre o oráculo e a 22 é a que tem a palavra autoritativa. **Dossiê escrito antes da branch de código** — esta branch é documento puro e nenhuma linha de `native/` existe |

A ordem 09 → 10 → 15 → 14 → 11 → 19 → 16 ✅ → 12 ✅ → 17 → 18 → 22 → 20 → 13 — a 16 cumprida em `9b2c65a` e
`bb13752`, a 12 em `fa94cb5`, e a fila viva de hoje ser **17 → 18 → 22 → 20 → 13** não é preferência: é a exceção de
serialização registrada **antes** do código em [`AGENTS.md`](../../AGENTS.md), "Escopo autorizado agora",
e reafirmada em
[`docs/melhorias-status.md`](../melhorias-status.md#em-andamento). O encadeamento é de dados, não de
cerimônia: cor depende de bioma, cercar depende de quem mais existe na matilha, a convivência reusa as
folhas que a alcateia reorganizou e entrega à 11 o ponto de spawn, acasalamento depende de dois adultos
próximos, o pulo de degrau entra depois da 11 porque é o único item da lista que é defeito do jogo que já
roda — nada depende dele e ele não espera por nada —, as tocas dependem do censo que a 11 variabilizou,
cavar entra depois da 16 porque as duas escrevem `src/main.gd` e é a 16 quem decide onde os lares ficam —
e a pauta da 12, re-escrita em 2026-11-22 contra a árvore da 19, diz que cavar **não** abre folha nova na
`Selector` nem assina `block_changed`: é o terceiro ramo do mesmo `if` de bloqueio, então a gravidade de
blocos continua sendo a **primeira** consumidora do sinal, não a segunda, o crescimento é o segundo
comprador da fila que a gravidade escreveu, o oráculo nativo entra no meio porque é transversal — escreve
`src/ai/` e `native/`, não `block_defs.gd` — e a mente autônoma e o ecossistema entram depois dele e da 18 porque
as três escrevem [`src/world/block_defs.gd`](../../src/world/block_defs.gd) e os ids baixos já foram gastos
— a 17 gasta o 18, a 18 gasta o 17, e drop de criatura só entra a partir do 23, na tabela que as duas
acabaram de renumberar — e antes da 13 porque genealogia sobre **uma única** espécie escreveria o que a 20
acaba de criar, e a árvore genealógica depende de nascimento por causa interna — e a 15 entra no meio porque
é o caminho do `Rodar.bat`, não do código da matilha. Além disso,
deixar uma mudança de `Channel.COUNT` no meio da fila custaria re-mediar as
pernas anteriores, porque o número entra no hash do journal. Duas branches abertas tocando
`wolf.gd`/`main.gd` ao mesmo tempo é exatamente o incidente do dossiê 03, que apagou uma versão já
conferida.

Nenhuma branch nasce de outra branch de trabalho, e nenhuma fecha gate de fase por si: o gate é
do dono, com comando + critério + doc.

## Como ler um dossiê

Todos seguem a mesma espinha: premissa nomeada (uma frase falsificável) → estado real do código
com `arquivo:linha` → o que a peça exige → gate em headless com comando que **já existe** → custo
pelas quatro perguntas do contrato → o que NÃO fazer → commits atômicos (um assunto, uma corrida) →
citações que não conferem.

## Verificação destas vinte e uma páginas

```sh
python .tools/verify_plan_cites.py docs/planos/01-estado-inicial-e-ordem-autoritativa.md
python .tools/verify_plan_ids.py   docs/planos/01-estado-inicial-e-ordem-autoritativa.md
```

**Medida desta rodada (as dezoito páginas, `main` em `8ac761d` + o dossiê 19 e esta página índice):**
**1 067 citações conferidas nos dezoito dossiês, 0 números fora do arquivo** — as quinze antigas somam
**935** (64 · 50 · 24 · 75 · 68 · 34 · 51 · 55 · 39 · 77 · 57 · 53 · 106 · 68 · 114), mais **54** da 17,
**50** da 18 e **28** da 19. Com esta página índice no corpus, o diretório inteiro dá **1 081** e continuam
**8** as referências a arquivos que não existem, todas peças já declaradas inexistentes
(`src/core/sim/tick_clock.gd`, `docs/engine/simclock.md`, `tests/wolf_multiseed_census_test.gd`) — a página
19 não acrescenta nenhuma. No `verify_plan_ids.py` a 19 devolve **39** identificadores em backticks, dos
quais **8** não existem em `src/` nem em `tests/`: **6** nomes de checagem proposta
(`degrau_de_um_bloco_lobo_sobe`, `degrau_de_um_bloco_jogador_sobe_sem_tecla`, `penhasico_nao_gasta_salto`,
`agachado_nao_e_arremessado`, `predicado_degrau_recusa_teto_baixo`, `pulo_nao_custou_passo_de_ninguem`), **1**
de predicado que o §3 do dossiê propõe e o §2 diz que ainda não está no código (`can_step_over`) e **1** de
bloco que o doc 10 numera e o registro não tem (`SLAB`). Somando os três documentos que governam a casa
nesta árvore — [`AGENTS.md`](../../AGENTS.md), [`README.md`](../../README.md) e
[`docs/melhorias-status.md`](../melhorias-status.md) — são **113 · 0 · 416 = 529 números, 0 fora do
arquivo**, elo a elo iguais aos da rodada 17/18 medida abaixo: esta página e o contrato ganharam prosa, não
citações numeradas novas. Nada dos parágrafos abaixo é reescrito por cima desta medida: eles dizem o que foi
medido na rodada em que foram escritos, e é essa a regra da casa.

**Medida desta rodada (o fecho da perna 11, `main` em `5b519f8` mais a prosa do fecho):**
**1 106 citações conferidas nos dezoito dossiês, 0 números fora do arquivo** — as quinze antigas somam
**973** (71 · 50 · 25 · 75 · 70 · 34 · 51 · 55 · 39 · 77 · 80 · 53 · 110 · 68 · 115), mais **54** da
17, **50** da 18 e **29** da 19. Com esta página índice no corpus, o diretório inteiro dá **1 121**,
e as **9** referências a arquivos que não existem são **3** arquivos, todos peças já declaradas
inexistentes (`src/core/sim/tick_clock.gd`, `docs/engine/simclock.md`,
`tests/wolf_multiseed_census_test.gd`) — a página 11 não acrescenta nenhuma. O salto contra a medida
da rodada anterior (1 067 → 1 106, **+39**) se divide por commit, medido arquivo a arquivo contra
`8ac761d` e contra `0762b43^`: **+10** da rodada do auto-pulo (01, 03, 05, 13, 15 e 19) e **+29**
do (g) desta perna (05, 11 e 13), sendo o maior salto isolado o da própria página 11, de **57** para
**80**. Somando os três documentos que governam a casa — [`AGENTS.md`](../../AGENTS.md),
[`README.md`](../../README.md) e [`docs/melhorias-status.md`](../melhorias-status.md) — são
**114 · 0 · 466 = 580 números, 0 fora do arquivo**: o contrato foi de 113 para 114 e o status de
416 para 466, dos quais **9** são a rodada que este fecho acrescenta ao fim do status; o `README.md`
da raiz segue em **0** porque cita por seção, não por linha. No `verify_plan_ids.py` a 11 devolve
**69** identificadores em backticks, dos quais **7** não existem em `src/` nem em `tests/`: **6**
SHAs (`a8967e0`, `c1ea3f9`, `e7a5fe7`, `f33c1d4`, `fe2fb6d`, `ff347d2`) e **1** nome de classe do
motor (`AudioStreamPlaybackOggVorbis`, o playback de Ogg que o `--verbose` nomeia no vazamento do
quit). O instrumento de âncoras ([`tools/check_doc_anchors.py`](../../tools/check_doc_anchors.py))
confere **1 963** ponteiros, **144** rótulos e **1 941** links relativos no corpus de **35**
arquivos e devolve **casos objetivos: 0**.

**O pin saiu do clone limpo e desceu para a `main` do fecho.** O clone mediu `4b858c2`, o merge
`--no-ff` do código da perna; o fecho documentado virou a `main` `5b519f8`, e o `README.md` re-pinado
passou a apontar para lá. Os dois merges devolvem os **mesmos** objetos de `src` e `tests`
(`30873d664a9577bcd3e709046cc708923456c372` e `975eac5a471dc1e064441474ef6e13866076d34f`), porque
o fecho trouxe `.md` e `.log` e nenhum `.gd` — a corrida do clone limpo e a corrida do pin são a
mesma corrida. A `main` do fecho re-rodada na própria árvore deu suíte **252 / 0 / 43,0 s**, runner
**225 / 0 / 15,348 s** e journal **128 / 0 / 5,769 s**, exit 0 e zero `SCRIPT ERROR` nas duas
correntes; os logs estão em
[`docs/evidence/acasalamento-censo-11/readback.md`](../evidence/acasalamento-censo-11/readback.md).
A contagem acima não muda por causa desse registro: os números que ele acrescenta são SHAs e
nomes de arquivo sem extensão, que nenhum dos três instrumentos conta como citação.

**O que esta rodada não re-ancorou, e por quê:** a coluna "Linha da fila" da primeira tabela ainda
carrega a numeração do dia em que cada dossiê foi escrito. A lista "Falta" do status está hoje em
`:494` e a célula da 11 ainda diz `Falta 10 :364-371` — que hoje é o item 1 do hash, não o item 10.
Re-ancorar essa coluna é a perna de docs que re-deriva o corpus inteiro, registrada no furo #14, e
não cabe num fecho de perna: transladá-la aqui mexeria em números que outras páginas usam como
registro de leitura, que é o que a regra desta casa proíbe. O item 10 da fila do status já se
declara "concluído nesta ponta (dossiê 11)", com o código lido ao lado; a numeração da fila é
mantida de propósito — o status diz isso na linha do item 1
([`docs/melhorias-status.md:496`](../melhorias-status.md#L496)).

**Medida desta rodada (o dossiê 16 escrito antes da branch; `main` em `e0450a3` mais a página nova,
esta página índice e as quatro prosas de pauta):** **1 200 citações conferidas nos dezenove dossiês, 0 números
fora do arquivo.** As dezoito páginas medidas na rodada anterior estão **elo a elo idênticas** —
71 · 50 · 25 · 75 · 70 · 34 · 51 · 55 · 39 · 77 · 80 · 53 · 110 · 68 · 115 · 54 · 50 · 29 = **1 106** —
e a diferença inteira do corpus é o elo novo: **94** citações da página 16. Com esta página índice no
corpus o diretório dá **1 215** (1 106 + 94 + os mesmos **15** desta página índice), e as **9** referências a
arquivos que não existem continuam sendo **3** arquivos, todos peças já declaradas inexistentes
(`src/core/sim/tick_clock.gd`, `docs/engine/simclock.md`, `tests/wolf_multiseed_census_test.gd`) — a 16
não acrescenta nenhuma. No `verify_plan_ids.py` a 16 devolve **88** identificadores em backticks, dos
quais **22** não existem em `src/` nem em `tests/`: **10** nomes de checagem proposta
(`tocas_distintas_no_boot`, `nenhum_lobo_le_de_outra_toca`, `esgotamento_de_lares_forcado`, …), **8**
peças/constantes/chaves que o §3 e o §3.5 do dossiê propõem (`DEN_COUNT`, `DEN_MIN_DIST`, `DEN_RANGE`,
`den_components`, `den_min_dist`, `home_of`, `pack_id` e o prefixo `DEN_`), `PLANT` (o bloco que o doc 10
numera e a perna 18 é quem gasta), **2** nomes de arquivo real que a gateira lê como identificador
(`fp_viewmodel`, `player_avatar`) e **1** SHA (`e0450a3`, a ponta em que a página foi escrita). Somando os
três documentos que governam a casa nesta árvore — [`AGENTS.md`](../../AGENTS.md),
[`README.md`](../../README.md) e [`docs/melhorias-status.md`](../melhorias-status.md) — são
**123 · 0 · 478 = 601 números, 0 fora do arquivo**: o contrato foi de 114 para **123** — os nove
ponteiros do registro de 2026-11-22 são sete URLs do `main.gd` (`:469`, `:501-505`, `:541`, `:545`,
`:559-560`, `:639`, `:640`) mais os dois rótulos numerados `main.gd:469` e `main.gd:545` — e o status foi
de 466 para **478** (**4** do furo #21 e **8** da rodada nova; o dono fixado do furo #18 não acrescenta
número nenhum), e o `README.md` da raiz segue em **0** porque cita por seção, não por linha. O
instrumento de âncoras
([`tools/check_doc_anchors.py`](../../tools/check_doc_anchors.py)) confere **2 083** ponteiros, **144**
rótulos e **2 068** links relativos em **36** arquivos e devolve **casos objetivos: 0** — mas esta rodada
teve de re-derivar **um** ponteiro para chegar lá: a linha de geometria do dossiê 03 media os 196.608
bytes na linha **1 529** deste status, e as duas inserções desta passada (o dono fixado do furo #18 e o
furo #21, **+24** linhas) deslocaram aquele conteúdo para a linha **1 553**; é para lá que a página
aponta hoje, e o instrumento foi o que disse. Nada dos parágrafos abaixo é reescrito por cima desta
medida: eles dizem o que foi medido na rodada em que foram escritos, e é essa a regra da casa.

**O que esta rodada não fecha, dito pelo índice:** nenhuma linha de `src/` nem de `tests/` foi escrita,
a branch `feat/tocas-da-alcateia-16` **não** abriu, e nenhuma das dez checagens do §5 existe. O contrato
publicado da suíte continua **252 / 0** na árvore do pin `5b519f8`; re-corrida nesta ponta deu
**252 / 0 / 42,4 s** na branch e **252 / 0 / 42,5 s** na `main` mergida `582aaef`, exit 0 e zero
`SCRIPT ERROR` nas duas, com `git diff HEAD --stat -- src tests` **vazio** contra o pin — o que muda aqui
é prosa, então as duas corridas servem para fechar o ciclo de trabalho (item 5 de "Ciclo de trabalho"),
não para publicar contagem nova.

**Medida desta rodada (a pauta 12 re-escrita contra a árvore de hoje; `main` em `e0450a3` mais a
página reescrita, esta página índice, a âncora do dossiê 17 e as prosas de pauta):** **1 286 citações
conferidas nos dezenove dossiês, 0 números fora do arquivo.** As dezoito páginas que não são a 12 estão
**elo a elo idênticas** à medida da rodada 16 — 71 · 50 · 25 · 75 · 70 · 34 · 51 · 55 · 39 · 77 · 80 · 110 ·
68 · 115 · 94 · 54 · 50 · 29 = **1 147** — e o elo que mudou é o da própria 12: de **53** para **139**,
**+86**, que é exatamente o salto do corpus (**1 200 → 1 286**). Com esta página índice no corpus o
diretório dá **1 301** (1 147 + 139 + os mesmos **15** daqui), e as **9** referências a arquivos que não
existem continuam sendo **3** arquivos, todos peças já declaradas inexistentes
(`src/core/sim/tick_clock.gd`, `docs/engine/simclock.md`, `tests/wolf_multiseed_census_test.gd`) — a
re-escrita não transformou nenhuma peça inexistente em fato. No `verify_plan_ids.py` a 12 devolve **84**
identificadores em backticks, dos quais **11** não existem em `src/` nem em `tests/`: **9** nomes de
checagem proposta do §5 e **2** campos que o §3.1 propõe (`_dig_accum`, `_dig_pos`) — nenhum
identificador de código existente foi citado em vão, e o único que a re-escrita citou torto foi o
rótulo `_drop`, que apontava para a linha de preenchimento da tabela em vez da declaração; hoje a página
cita o acessor real. Somando os três documentos que governam a casa nesta árvore —
[`AGENTS.md`](../../AGENTS.md), [`README.md`](../../README.md) e
[`docs/melhorias-status.md`](../melhorias-status.md) — são **142 · 0 · 525 = 667** números, **0** fora do
arquivo: o contrato foi de **123** para **142** (**+19**, o parágrafo de registro desta pauta) e o status
de **478** para **525** — **+22** pelas duas peças de furo (#22 e #23), pela nota do item 11 do "Falta" e
pela nota de "Em andamento", e **+25** pela seção "Rodada Docs 12", medida recortando o arquivo: sem a
seção ele dá **500**, com ela **525**. O `README.md` da raiz segue em **0** porque cita por seção, não por
linha. O instrumento de âncoras
([`tools/check_doc_anchors.py`](../../tools/check_doc_anchors.py)) confere nesta ponta **2 260** ponteiros,
**151** rótulos e **2 217** links relativos em **36** arquivos e devolve **casos objetivos: 0** — e o
único caso que a re-escrita abriu foi fechado na mesma passada: a âncora do dossiê 17 para o §9 da
página 12 media `:186-189` de um arquivo de **189** linhas; a página reescrita tem **390** e o mesmo §9
está hoje em `:384-390`, que é para onde a âncora aponta. Nenhum número deste parágrafo foi escrito
antes de o instrumento devolvê-lo nesta árvore.

**O que esta rodada não re-ancorou, e por quê (a segunda vez que isto se escreve):** a coluna "Linha da
fila" da primeira tabela continua com a numeração do dia em que cada dossiê foi escrito, e a célula da
12 continua dizendo `Falta 11 :372-380`. Re-ancorar essa coluna é a perna de docs que re-deriva o corpus
inteiro, registrada no furo #14, e não cabe numa pauta: transladá-la aqui mexeria em números que outras
páginas usam como registro de leitura.

**Medida desta rodada, re-tomada contra a árvore mergida (a pauta 20 escrita antes da branch, com a
`main` do pouso da 16 — `bb13752` — já dentro desta ponta pelo merge `16ece25`):** **1 527 citações
conferidas nos vinte dossiês, 0 números fora do arquivo.** As dezenove páginas que não são a 20 dão hoje
**1 336** e a 20 dá **191**. A lista elo a elo do registro anterior — 71 · 50 · 25 · 75 · 70 · 34 ·
51 · 55 · 39 · 77 · 80 · 139 · 110 · 68 · 115 · 94 · 54 · 50 · 29 = **1 286**, mais os **182** da própria
20, **1 468** no total — foi medida com a `main` em `99d1167` e deixou de valer **com o merge, não com
esta pauta**: `git diff --stat 99d1167 bb13752 -- docs/planos` devolve **20 arquivos, +659/−570**, porque
a perna 16 re-derivou ponteiros dentro de todas as páginas do diretório. Com esta página índice no corpus,
o diretório inteiro dá **1 548** (os 21 desta página, somados aos 1 527), e as referências a arquivos que não
existem são **11** sem o índice e **16** com ele, em **9** caminhos: cinco são artefatos gitignored de
`.tools/` (`clean_suite.log`, `af-clean-suite.log`, `af-clean-suite2.log`, `shot_gallery.tscn` e o
`pauta20-suite.log` desta rodada — a régua corre numa árvore limpa, onde `.tools/` não existe) e os outros
quatro são peças que os dossiês **declaram** inexistentes (`src/core/sim/tick_clock.gd`,
`docs/engine/simclock.md`, `tests/wolf_multiseed_census_test.gd` e `src/ai/reach.gd`, que a página 20
escreve como o Braço B **rejeitado**). Nenhuma delas virou fato nesta rodada. No
`verify_plan_ids.py` a 20 devolve **137** identificadores
em backticks, dos quais **45** não existem em `src/` nem em `tests/`: os **18** nomes de checagem proposta do
§5 (`alcance_calcula_altura`, `arvore_por_arquetype`, `lobo_morto_dropa_carne`, `especie_decide_numero`,
`desistencia_vira_crenca`, `passaro_pousa_em_copa`, …), as **14** peças/constantes/campos/blocos que o §3
propõe e o §2 diz por escrito que ainda não estão no código (`SpeciesDef`, `DropItem`, `EchoLedger`,
`SPECIES`, `BIRD_CAP`, `MEAT`, `FEATHER`, `FEATHER_COLOR`, `HEAD_WOLF`, `HEAD_CHICKEN`, `HEAD_DUCK`,
`_reach_tries`, `NavigationAgent` — classe do motor que nenhuma linha deste repositório usa — e `PLANT`, o
bloco que o doc 10 numera e a perna 18 gasta), as **12** palavras de domínio lidas com grep zero em `src/`
(`species`, `archetype`, `animals`, `habitat`, `drops`, `carne`, `feather`, `trophy`, `raio_fuga`,
`foge_de_humano`, `tentativas_ate_desistir`, `teto_por_arquetype`) e **um** que esta ponta acrescentou ao
re-derivar contra o pouso: `bb13752`, o SHA escrito em backticks — o instrumento não distingue hash de
identificador, e é ele a diferença entre os **134** da escrita e os **137** de agora. Nenhuma classe dessas é invenção de
fato: é o que a página declara comprar. Somando os três documentos que governam a casa nesta
árvore — [`AGENTS.md`](../../AGENTS.md), [`README.md`](../../README.md) e
[`docs/melhorias-status.md`](../melhorias-status.md) — a régua dá **173 · 3 · 620 = 796 números, 0 fora do
arquivo**; no mesmo recorte aplicado à base `bb13752`, **131 · 3 · 590 = 724**. O contrato subiu **+42**
(o registro de 2026-11-22 (3), que é a pauta desta rodada) e o status **+30** (o item 14 do "Falta", a nota
de "Em andamento" e os furos **#24** e **#25**); o `README.md` da raiz está em **3**, não em **0** como o
registro anterior escrevia, e as três são `#L` dentro de logs de evidência —
`docs/evidence/tocas-alcateia-16/head_suite.log#L357` (**255 / 0 / 48,0 s**),
`docs/evidence/tocas-alcateia-16/docs_rerun_suite.log#L357` (**255 / 0 / 47,7 s**) e
`docs/evidence/acasalamento-censo-11/merged_main_suite.log#L350` (**252 / 0 / 43,1 s**) — entradas do pouso
da 16 e da perna 11, nenhuma desta pauta. O instrumento de âncoras
([`tools/check_doc_anchors.py`](../../tools/check_doc_anchors.py)) confere nesta ponta **2 662** ponteiros,
**179** rótulos e **2 666** links relativos em **37** arquivos e devolve **um** caso objetivo: o ponteiro
`../.tools/_chk_labels.py` em `docs/melhorias-status.md:3231`, o mesmo que o registro do pouso aponta na
linha **3138** — os **84** de diferença são as linhas que este lote acrescentou acima dela no mesmo
arquivo, e o registro ficou com o número da corrida que sustenta. Duas coisas do instrumento valem escritas
aqui: ele deriva a raiz do **próprio arquivo**, não do diretório atual, então medir uma árvore exige rodar a
cópia daquela árvore; e o registro do passe de docs do status (`docs/melhorias-status.md:2431`) nomeia
`docs/planos/README.md:15, :90` — a linha 15 continua na linha, e o **:90** é re-derivação desta ponta:
lido pelo conteúdo, o registro da base (`bb13752:docs/melhorias-status.md:2338`) escrevia **80** numa árvore
onde a frase já estava em **75**, a linha nova da tabela de branches (a da 20) com o parágrafo acima
empurraram-na para **81**, e a linha da 22 com a frase nova do intro fazem **90** — **9** linhas, conferidas
entre as duas pontas, não transladadas. Nenhum número deste parágrafo foi escrito antes de medido.

**O que esta rodada não fecha, dito pelo índice:** nenhuma linha de `src/` nem de `tests/` foi escrita, a
branch `feat/mobs-autonomos-e-ecossistema-20` **não** abriu, e nenhuma das dezoito checagens do §5 da
página 20 existe. O contrato publicado da suíte é hoje **255 / 0** e **240 / 0** no runner de reações, na árvore do pin
`9b2c65a`: a 16 pousou depois que este parágrafo foi escrito, e `git diff --name-only 5b519f8 HEAD -- src
tests` devolve **4 arquivos** — os que ela escreveu. O número vale **por identidade de árvore**, não por
re-corrida: `git diff --name-only bb13752 HEAD -- src tests` está **vazio**, então `src/` e `tests/` desta
ponta são byte a byte os do pin. A re-corrida serial desta branch, feita antes do pouso, deu
**252 / 0 / 42,3 s** (`.tools/pauta20-suite.log:350` — arquivo local, `.tools/` está no `.gitignore`) e
fica como registro daquele dia, não como contagem vigente.

**O que esta rodada não re-ancorou, e por quê (a terceira vez que isto se escreve):** a coluna "Linha da
fila" da primeira tabela continua com a numeração do dia em que cada dossiê foi escrito — a célula da 20 é
a única que aponta por **item** (`item 14 de `Falta``) em vez de por linha, e é assim de propósito: a
perna de docs que re-deriva o corpus inteiro está registrada no furo #14 e não cabe numa pauta.

**Medida da rodada 17/18 (as dezessete páginas, `main` em `86e63c4` + aqueles dois arquivos novos):**
**1 039 citações conferidas nos dezessete dossiês, 0 números fora do arquivo** — por página, na ordem da
tabela, 64 · 50 · 24 · 75 · 68 · 34 · 51 · 55 · 39 · 77 · 57 · 53 · 106 · 68 · 114 (as quinze antigas,
**935** somadas) mais **54** da página 17 e **50** da página 18. Com esta página índice no corpus, o
diretório inteiro dá **1 053** e continuam **8** as referências a arquivos que não existem, todas elas peças
declaradas como inexistentes (`src/core/sim/tick_clock.gd`, `docs/engine/simclock.md`,
`tests/wolf_multiseed_census_test.gd`) e nenhuma delas uma citação mal escrita: a gateira **não** conta
arquivo ausente como número conferido. As duas páginas novas não acrescentam nenhum arquivo ausente.
No `verify_plan_ids.py`, a 17 devolve **98** identificadores em backticks, dos quais **38** não existem em
`src/` nem em `tests/`, e a 18 devolve **68**, dos quais **16** não existem. Nas duas páginas a totalidade
dos ausentes é de checagem proposta (7 na 17 — `queda_move_a_celula`, `bloco_em_queda_nao_sobe`, … — e 8 na
18, `grama_precisa_de_vizinha`, `mato_nao_engole_o_clique`, …), de peça/API/chave que o dossiê propõe e o §2
diz expressamente que ainda não está no código (`BlockUpdateQueue`, `FallingBlock`, `FallingBlockSpawner`,
`DropItem`, `DropSpawner`, `is_supported`, `place_falling_block`, `has_gravity`, `_due`, `_landing_cell`,
`_shatter`, `overflow`, e do lado da 18 `substituivel`, `growth_queued`, `growth_converted`), de constante
prometida (`MAX_PER_TICK`, `MAX_FALL_TICKS`, `fall_class`, `breaks_a_fall`, `blocks_air`, `is_replaceable`,
`destructible`, `sofre_gravidade`; `GROW_PERIOD`, `GROW_CHANCE`, `GROW_MAX_PER_TICK`, `GROW_RECHECK`), ou de
bloco que o doc 10 numera e o registro não tem (`ANVIL`, `BEDROCK`, `GRAVEL`, `PLANT`, `POWDER_SNOW`,
`ROCK_LOOSE`, `SLAB`, `TORCH`, mais as duas saídas de pouso `FIX`/`SHATTER`). Nenhuma classe dessas é
invenção de fato: é o que as duas páginas declaram comprar. Somando os três documentos que governam a casa
nesta árvore — [`AGENTS.md`](../../AGENTS.md), [`README.md`](../../README.md) e
[`docs/melhorias-status.md`](../melhorias-status.md) — são **113 · 0 · 416 = 529 números, 0 fora do
arquivo** — 86 → 113 no contrato e 329 → 416 no status: os saltos são as pernas 11 e 14, que escreveram
rodadas novas nesses dois arquivos, mais os quatro números que esta rodada de docs acrescentou ao status.
O `README.md` da raiz segue em **0** porque cita por seção, não por linha. Nada dos parágrafos abaixo é
reescrito por cima desta medida: eles dizem o que foi
medido na rodada em que foram escritos, e é essa a regra da casa.

O primeiro confere se todo `arquivo:linha` citado existe e se o número cabe no arquivo: nas quinze
páginas são **895 citações conferidas, 0 números fora do arquivo** (61 · 47 · 25 · 73 · 67 · 33 · 44 ·
52 · 36 · 76 · 56 · 54 · 103 · 65 · 103, na ordem da tabela), e nesta página há mais **15** — **910** no
diretório inteiro. Os três que esta página ganhou desde a medida anterior são os ponteiros que o parágrafo
de re-derivação mais abaixo escreve para registrar o README de 649 a 662 linhas, e a régua conta a página
índice no momento em que ela é somada ao corpus. Pela
regra declarada ela continua fora das
quatro somas. As catorze páginas antigas re-medem aqui **792**, e o único elo que se moveu desde os
**790** da rodada passada é o dossiê 10: **74 → 76**, dois ponteiros que a própria nota de fechamento da
perna 10 escreveu naquela página ao realinhar as citações do `README.md`. Nada mais mudou elo a elo, e a
diferença inteira deste número é o elo novo — os 103 da página 15 — e por isso o **802** antigo fica
citado onde foi medido, e não reescrito por cima do número novo. Somando os
três documentos que governam a casa — [`AGENTS.md`](../../AGENTS.md),
[`README.md`](../../README.md) e [`docs/melhorias-status.md`](../melhorias-status.md) — são mais
**415 números (86 · 0 · 329), 0 fora do arquivo** — 85 → 86 no contrato e 245 → 329 no status, e os dois
saltos são a perna 10, que re-deriveu citações do próprio `AGENTS.md` (`2e8863e`) e escreveu a sua rodada
no fim do status; a extensão 15 não acrescenta nenhuma citação numerada ao contrato. A conta anterior desta
página — 622 · 629 no
diretório e 261 (72 · 0 · 189) no trio — media **doze** páginas e deixava a página 07 em 39: os cinco
números que ela cita em `.tools/af-clean-suite*.log` só são conferidos onde `.tools/` existe, porque a
gateira **não conta** citação de arquivo ausente. Aqui `.tools/` está no `.gitignore` e está na árvore,
então 44 é o que o comando devolve; numa árvore sem os logs dos runs o mesmo comando devolve 39, e essa
é a diferença, não um erro de corpo. Os números acima são re-medidos por comando nesta árvore, com
`src/` e `tests/` na `main` em `b779cee` — o código da perna 10 já dentro — e os documentos desta rodada
por cima; não são herdados do texto. As únicas ausências que a gateira devolve são peças declaradas como
inexistentes: `src/core/sim/tick_clock.gd` (caminho que
[`docs/design/06:33`](../design/06-godot-architecture.md#L33) ainda cita), `docs/engine/simclock.md`
(entrega de P0 que ainda não existe), `tests/wolf_multiseed_census_test.gd` (o runner que o dossiê 02
propõe), `src/ai/llm_server_host.gd` e `tests/llm_server_boot_probe.tscn` (o dono de processo e a cena
de prova que o dossiê 15 propõe).

O que a gateira **não** confere é o conteúdo da linha apontada, e isso já tem nome:
[`docs/melhorias-status.md`, furo #14](../melhorias-status.md#furos-descobertos) mede as referências
numeradas que os dossiês fazem a linhas deste status e do `AGENTS.md`, e mostra que parte delas saiu
do lugar por causa das inserções de cada rodada (+31 no status, +21 no contrato na rodada que abriu os
dossiês 09 a 12) — caem em faixa, portanto invisíveis para o verificador. Re-contado nesta rodada com
**uma regra única**, declarada aqui porque as três contas antigas desta página usavam três regras:
 contam-se os **catorze dossiês** (esta página índice fica fora, porque cita os ponteiros alheios para
descrevê-los) e cada link `[rótulo](alvo)` vale **uma** referência, não duas. Sob essa regra são
**59** referências numeradas a `docs/melhorias-status.md`, **8** a `AGENTS.md` e **6** ao `README.md` da
raiz — **73** ao todo; mais **5** ao `docs/design/README.md`, que é a legenda e não um dos três que
governam a casa. **A página 15 não entra nessas quatro somas**, e a razão é de forma, não de valor: ao
contrário das catorze antigas, ela aponta para os governantes por âncora de linha — contados link a
link são 15 ao `AGENTS.md`, 7 ao `README.md` da raiz, 4 ao status e 1 à legenda — e cada um foi lido por
conteúdo ao ser escrito, que é o que o §12 do dossiê registra. Recolher os quinze sob uma só regra é a
perna separada declarada abaixo, não este parágrafo. Re-contadas por script nesta ponta, as quatro somas
das catorze páginas são **59 · 8 · 6 · 5**, elo a elo iguais às mesmas catorze medidas em `4ac5838` — a
perna 10 não mexeu em nenhuma delas. O **59** do status é o próprio número publicado acima: sobre as
catorze a régua declarada e a régua de script coincidem, e o **60** só aparece quando esta página entra no
corpus, que é exatamente o que a frase seguinte mede. A conta
publicada antes — **60 · 8 · 6 = 74** — não
se reproduce por regra nenhuma:
somando esta página ao corpus o status dá 60, mas aí o `README.md` da raiz dá 9 (collapsed) ou 12
(sem colapsar), nunca 6; sobre os doze dossiês antigos dá 59 · 8 · 3 = 70. As duas páginas novas não
adicionam nada ao status nem ao contrato (linkam-nos por nome), mas adicionam **3** ao `README.md` da
raiz: `13` aponta `:192` e `:197` e `14` aponta `:192`. Conferindo conteúdo contra a `main` em `eb6ec8d`,
quatro ponteiros estavam errados e **foram corrigidos na própria página**: `12:63` dizia
`docs/melhorias-status.md:78-78` (prosa da seção anterior; o par geração/malharia está em `:83`) e
`README.md:533` (linha de lista do Éter; os ~4,3 s de malharia dos 64 chunks estão em `:548` naquela
numeração — `:570` na de hoje), e `07:67`
e `07:137` apontavam `README.md:505-512` e `:507` — que é a seção do oráculo local — para a queda de
~16 s para ~7,5 s com a cópia linear, que está em `:546-553` (hoje `:568-575`). Cada número de README desta frase é da
numeração de `eb6ec8d`, que tem **649** linhas, e entre ela e esta ponta o arquivo mudou duas vezes —
`7cc79ce` (+14/−1, ou seja **649 → 662**) e `8cb10e7` (+11/−11, reescreve sem mover a contagem) — as
duas notas de fechamento da perna 10. Mapeado por bloco igual contra os **662** desta ponta, o mesmo
texto cai em `:546`, `:561`, `:518-525`, `:520` e `:559-566`, nesta ordem, e é para lá que as páginas já
apontam: `12:62` cita `README.md:561`, `07:67` cita `README.md:559-566` e `07:137` cita `README.md:561`,
re-derivadas no próprio `7cc79ce`. Restam **69** referências a estes três
arquivos sem conferência de conteúdo, e é por isso que nenhuma delas deve ser lida como conferida. A
perna de docs que re-derive as 69 pelo conteúdo continua aberta, registrada no furo. Este re-contado mora
aqui, e não dentro do furo #14, por um motivo que é o próprio furo: escrever no meio do status empurra
tudo abaixo da linha inserida, e as referências `:1064` e `:1066` que a página 07 já faz sairiam do lugar
por minha mão — re-derivar o corpus inteiro é uma perna, e ela roda **agora que a 10 pousou** (código
`0c38489`, `main` publicada `b779cee`), porque cada
merge desta fila move outra vez os números de `wolf.gd` e `main.gd`.
O segundo script confere
identificador: todo nome em backticks que não existe em `src/` ou `tests/` é ou nome de
checagem/peça nova declarada como tal, ou invenção registrada no próprio arquivo, ou um SHA de commit
(`a8967e0`, `ff347d2`, `eb6ec8d`), que a gateira lê como identificador e não há motivo para existir em
código. Nas três páginas novas (13, 14 e 15) todos os ausentes são da primeira ou da terceira classe:
checagens propostas, peças propostas (`FamilyTree`, `PackState`, `SAFE_SPAWN_DIST`, `ModelPackFetcher`,
`oracle_cache`) e commits. A página 15 acrescenta ainda nomes de API do **motor**, não deste repositório
(`create_process`, `is_process_running`, `get_process_exit_code`) e nomes de estado e de chave de log que
o dossiê propõe (`carregando`, `reusado`, `estrangeiro`, `ms_ate_200`, `requisicoes_emitidas`,
`retentativas`) — os três primeiros corrigem nomes que vieram do briefing como sendo Godot 3, registrados em
**15 §12** — e um nome da **PowerShell**: `throw`, palavra-chave do script
[`tools/run_mind_server.ps1`](../../tools/run_mind_server.ps1), que a gateira lê como identificador porque
ela só conhece `src/` e `tests/`. Re-contada nesta ponta, a página 15 dá **49** identificadores em backticks,
dos quais **23** não existem em `src/` nem em `tests/`: **10** nomes de checagem proposta, **3** de API do
motor, **3** de estado e **3** de chave de log propostos, **2** de peça proposta (`ModelPackFetcher`,
`oracle_cache`), **1** SHA (`b779cee`, o registro da ordem) e `throw`. As duas gateiras
moram em `.tools/`, que está no `.gitignore` — o mesmo que já se diz dos logs e do harness de
capturas: quem for conferir por clone limpo precisa recriá-los, e os números acima valem para a
árvore de trabalho que os tem.

## Invenções de briefing registradas pelos arquivos

Os prompts que geraram estes dossiês trouxeram âncoras falsas, e o código as refutou. Nada delas
entrou como fato; estão documentadas nos arquivos que as receberam:

- meia-vida "morta", "11,33% por passada", "4,8 s efetivos", `TrailReader`, `_sample_trail`,
  `_sighting_cache_cap`, `_sighting_cache_ttl`, `_scan_interval`, `DECAY_PER_SEC`, `SOURCE_RATE`,
  `SATURATION`, `imprint(channel, cell, amount)`, "três dicionários paralelos em
  `tests/aether_reactions_test.gd:78-94`", pesos WORK/BLOOD/FEAR em `src/ai/utility_scorer.gd` e
  `audio_director.gd:314` como posição de playback → **03 §9**;
- `worst_sim_us` (o nome real é `_sim_worst_us`, `tests/aether_reactions_test.gd:85`) → **03 §5**;
- deslocamento de +1 nas constantes de `src/main.gd` citadas por `AGENTS.md` → **07 §8** (as
  citações do contrato estão certas: `:12` difusão, `:13` malha, `:14` visão, `:16` cadáveres;
  `WOLF_COUNT` é `:9`);
- `src/session/`, `wolf_roster.gd`, `scene_readiness.gd` como peças esperadas → **01, "Estado real"**
  (nenhum desses nomes existe em `src/` nem em `docs/design/`);
- linhas 27-28 da tabela do prompt master (reais: `:29` e `:30`) e `MemoryGate` como código → **08 §8**;
- premissa dos dossiês da ampliação: "`EXPECTED_CHECKS` está na linha 16 do runner, com 109,
  e a suíte em 236 checagens" → conferido na época: era a linha 17, com **119**, e a suíte
  **237 / 0 falhas / 35,5 s** (pino em `README.md:192`); nesta ponta o censo travado é a
  linha 20 de `tests/aether_reactions_test.gd`, com **150**. O blackboard é um só → **14 §2**;
- "todo ser vivo" como escada já implementada: `src/entities/` tem **uma** espécie animal, **nenhum**
  NPC e o jogador sem `Mind` nem `identity` (grep devolve zero ocorrências dos dois nomes em
  `player.gd`), então os três degraus acima do lobo ficam `[TARGET]`, com zero código → **13 §1, §3.4**;
- `OS.kill_process` e `OS.is_process_valid` como API de processo, `--watch-file` como flag do
  `llama-server` e `--timeout` como saída por ociosidade, tudo vindo como premissa do dossiê 15 →
  **15 §0, §4.3 e §12**: no motor pinado os nomes são `OS.kill`, `OS.is_process_running` e
  `OS.get_process_exit_code` (os dois nomes do briefing são Godot 3 e dão zero ocorrências no `.exe`),
  `--watch-file` não existe no b12499 e `--timeout` é timeout de socket do servidor, default 3600 s —
  ou seja, o servidor **não** morre junto com o jogo por conta própria, que é o motivo de o ciclo de
  vida do §4.3 existir.
- `GRAVEL` como bloco que cai, `BlockUpdateQueue` e `FallingBlock` como peças já existentes a
  serem "ligadas", `Landing.SHATTER` como item no chão, "processar no tick com orçamento" lido como
  `MESH_BUDGET`, e a geometria `Y_MIN = -64` / `SEA_LEVEL = 64` do doc 10 como o mundo de hoje →
  **17 §6 e §9**: `GRAVEL` é o id 10 reservado e não está no registro, as três peças dão zero
  ocorrências em `src/` e `tests/`, não existe entidade de item no chão, os dois tetos são de
  subsistemas diferentes, e o código tem `CHUNK_SIZE_Y = 64` com `SEA_LEVEL = 26`;
- "a física de blocos do doc 10 cobre crescimento de grama" e "o mato decorativo é só um bloco
  novo": o grep de espalhamento no doc devolve **zero** ocorrências, e o `_try_place` recusa
  qualquer célula que não seja `AIR`/`WATER` → **18 §2, §3.5 e §9**: a regra A é escrita aqui pela
  primeira vez (por isso `[TARGET]`), e sem o campo `substituivel` lido pela colocação o mato é um
  obstáculo invisível que come o clique do jogador. "Dropa pouco" também não tem como ser dito:
  não existe item de semente nem quantidade fracionária no drop.
- "os mobs/npcs tem que saber pular os blocos, pois ficam bugados": em `src/entities/` existe **uma**
  espécie animal e **nenhum** NPC, e a causa não é o pathfinding — são três alturas que não fecham
  (§2): `step_up` 0,62 m e ápice do impulso do lobo 0,563 m contra uma célula de **1,00 m**, e o
  `blocked_horizontal` do jogador sem nenhum leitor em `src/`. "Auto pular o bloco" também não é
  "aumentar o step-up": a formulação mais curta teletransporta o corpo e mata a animação de voo
  → **19 §2, §3.4 e §9**.

As imprecisões reais achadas em `AGENTS.md` nesta rodada foram corrigidas no próprio contrato, uma por
uma, depois de lidas as duas pontas — e os números desta frase são **registro das rodadas que os
escreveram, não ponteiros vivos**: hoje `src/entities/player.gd` tem `_mine_target()` em `:677`,
`_try_place()` em `:693` e os dois `world.set_block` em `:685` e `:711`, e quem quiser o ponteiro da
árvore atual lê o contrato. Naquele fecho: `player.gd:659`/`:675` eram os cabeçalhos de
`_mine_target()` e `_try_place()`, e o `world.set_block` que escreve no mundo estava em
`:667`/`:693`; o `_on_acted` que
imprime WORK saiu de `main.gd:328-333` para `:337-342` quando o viés de imprint entrou; o teto do load
que pareia por índice é `main.gd:479`, não `:470`; as três promessas da lavra estão em
`tests/smoke_test.gd:894-902`, não `:812-822`; e a conta do "objeto deus" passa a estar pinada na
revisão medida — **510 linhas em `src/main.gd` na `main` em `eb6ec8d`** — porque a perna 10 em curso vai
mover esse número, e um número sem pino é exatamente o que estes furos cobram. Nada disso muda
mandato: é deriva de linha.

**Depois do pouso desta pauta.** Os números do bloco "Medida desta rodada" acima são os da árvore limpa da
branch. O registro da `main` mergida, no fim de `docs/melhorias-status.md`, publica
a mesma régua corrida na árvore do merge — **1 341 · 191 · 1 532 · 1 554** com **11** ausências e âncoras com
**0** casos objetivos — e nomeia o motivo da diferença: os artefatos de `.tools/` existem numa árvore e não
na outra. Nenhum dossiê mudou com isso.
