# Dossiês por item da fila

Dezessete arquivos, um por linha aberta da fila de [`docs/melhorias-status.md`](../melhorias-status.md)
("Falta", `:303-430`, e os checklists P0/P1, `:434-451`). Cada dossiê é **leitura de código, não
corrida**: nenhuma engine foi rodada aqui, nenhum número publicado foi re-medido por estes arquivos
e **nenhum gate de fase se fecha por eles** — quem abre e fecha gate é o dono
([`AGENTS.md`](../../AGENTS.md), mandato 4). Marcas `[TARGET]` / `[CLAIMED]` / `[MEASURED]` /
`[DECIDED]` / `[OPEN]` seguem a legenda de [`docs/design/README.md:10-16`](../design/README.md#L10-L16).
Os sete últimos (09 → 10 → 15 → 14 → 11 → 12 → 13) existem porque o dono ampliou o escopo em 2026-11-20 —
bioma/cor, alcateia, oráculo embutido no boot, convivência da matilha, acasalamento com filhote, bicho
cavando e a árvore genealógica com o Éter lendo parentesco — e a ordem serializada deles está escrita na
mesma seção do contrato, não deduzida depois. Os dois que faltavam chegaram em 2026-11-21, por dois
prompts do dono ("Física de Blocos + Mundo Reativo" e "Física de Blocos + Mundo Vivo"): **17** fica com a
grave dos blocos que caem e **18** com a grama que cresce e o mato. O número **16 está reservado e não
tem página**: é o pedido dele de espalhar a matilha em 2–3 tocas depois de ter percorrido o mapa inteiro
vendo um lobo só, e quem escrever aquela página usa o 16 e a posição que ele escolheu (logo depois da 11).
Nenhuma das três páginas novas fecha escopo: elas registram a pauta, e o registro vem antes do código.

| # | Dossiê | Linha da fila | Premissa nomeada | O que decide, em headless |
|---|---|---|---|---|
| 01 | [Estado inicial, comandos, RNG e ordem autoritativa](01-estado-inicial-e-ordem-autoritativa.md) | P0 `:436`, Falta 2 `:310-319` | o diário tem duas portas: o hash do tick N não é função só do tick N | `snapshot_resta_hash`, `ordem_independente_de_quadros` (nasce **vermelho**, com o número real de ticks divergentes), `rng_restaurada_no_load`, `formato_declarado` |
| 02 | [Censo do lobo em 20 sementes × 1000 ticks](02-censo-multi-semente.md) | P1 `:446`, Falta 3 `:320-321` | cadência sintética, não relógio de parede | `repeticao_por_semente` 20/20 e `contraste_de_cadencia` (K = 1 vs K = 3 tem de **divergir**; se não divergir a checagem é vazia) |
| 03 | [Canais MORTE / SOM / FOGO](03-canais-morte-som-fogo.md) | P1 `:444`, Falta 4 `:322-330` | um canal só existe se fonte e curva leitora caírem no mesmo lote | A/B com o canal zerado mudando `intent` ou `_reaction`; recusa de índice de canal fora de faixa; `Channel.COUNT` puxa `FORMAT_VERSION`. **FOGO fica bloqueado** sem bloco/entidade de fogo |
| 04 | [Budget HOT medido](04-budget-hot-medido.md) | P1 `:445`, Falta 5 `:331-335` | "2,5 ms medido" embute duas metade não medidas: cinco mentes no mesmo tick e o segmento de decisão inteiro | checagem (a): se nenhum tick teve as cinco mentes vivas, vermelho em vez de zero; `EXPECTED_CHECKS` (`tests/aether_reactions_test.gd:17`, hoje 119) sobe com o lote |
| 05 | [Difusão do Éter fora do tick](05-difusao-fora-do-tick.md) | P1 `:447`, Falta 6 `:336-338` | hoje a difusão é síncrona e o lobo vê o resultado por isso | primeiro a colheita (nenhum µs de `diffuse_and_decay` existe); o corte só com o hash por semente **inalterado** |
| 06 | [Decompor `main.gd` pelo eixo do dono](06-decompor-main-gd.md) | Falta 7 `:339-341` | ônibus não é dono: um bloco vira dono quando já tem comprador fora de `main.gd` | K1 bancadas → K2 fila/cadáveres → K3 matilha; K4 (persistência) fica `[OPEN]` até aparecer o segundo consumidor |
| 07 | [`af-bench`, bake-off de voxel e o doc do `SimClock`](07-af-bench-bake-off-voxel-e-doc-do-simclock.md) | P0 `:437`, `:438-439`, `:440` | três premissas, uma por peça; hash é função do passo, fps é função da máquina | ordem interna: doc → runner de `dt` fixo → 3 execuções de 12 000 ticks → bake-off com ≥ 2 braços tabelados |
| 08 | [`MindStore` e `MindsInspector`](08-mindstore-e-mindsinspector.md) | P1 `:448-449`, `:450-451` | `MindStore` muda **posse**, `MindsInspector` mostra **composição** — nenhuma das duas decide | recomendação lida: F3 estendido (reaproveita `src/main.gd:710-716` e `src/ui/hud.gd:273-280`) antes de qualquer `.tscn` novo |
| 09 | [Bioma, cor do pelo e fundo de Éter por bioma](09-bioma-cor-de-pelo-e-ether.md) | Falta 8 `:342-356` | bioma só existe se decidir algo observável: cor do pelo e viés de imprint; derivar **não** pode alterar terreno nem hash | `bioma_deterministico`, `bioma_nao_altera_terreno` (a que fecha o lote), `cor_do_pelo_vem_do_bioma`, `imprint_bioma_tem_mesma_ordem` |
| 10 | [Rotinas de alcateia](10-alcateia-rutinas.md) | Falta 9 `:357-363` | a intenção de um lobo muda quando outro está por perto — 1 lobo vs 4 lobos no mesmo cenário tem de **divergir** | `contraste_de_alcateia`, `cercar_calcula_assentos`, `ataque_escalonado`, `medo_contagia` / `amigo_amortece`, `alcateia_nao_consome_rng_da_sessao` |
| 11 | [Acasalamento, filhote que cresce e censo variável](11-acasalamento-filhote-e-censo.md) | Falta 10 `:364-371` | um save gravado com 7 lobos carrega 7 lobos — e crescer é função do `clock.tick`, não de parede | `acasalar_aumenta_censo`, `filhote_cresce_por_tick`, `filhote_nao_morde`, `load_leva_todo_o_censo` (nasce **vermelha** no código atual), `censo_respeita_teto`, `journal_hash_inalterado_sem_escolha` |
| 12 | [Bicho cavando voxel](12-bicho-cavando-voxel.md) | Falta 11 `:372-380` | um voxel some por ação do lobo **sem input do jogador**, e a malharia disso é medida antes de ser celebrada | `lobo_cava_sem_input_do_jogador`, `cavar_respeita_a_lista`, `work_de_bicho_nao_confundido`, `malharia_do_cavar_medida`, `abrir_passagem_depois_de_bloqueio` |
| 13 | [Árvore genealógica de todo ser vivo, e o Éter lendo parentesco](13-arvore-genealogica-e-ether.md) | Falta 13 `:411-430` | ascendência só existe se nascer de dois adultos, sobreviver ao save e **mudar algo observável**; herdar é genoma-base, nunca a memória nem o trauma do pai | `genealogia_muda_algo_observavel` e `load_preserva_ascendencia` (nascem **vermelhas**), `pelo_de_fundador_vem_do_bioma`, `heranca_nao_repete_deriva`, `eter_devolve_quem_sangrou`, `journal_hash_inalterado_sem_nascimento`, `genealogia_nao_consome_rng_da_sessao`, `ascendencia_e_int_nao_referencia` |
| 14 | [Convivência da alcateia: terra seca, matilha legível e spawn fora dos olhos](14-convivio-da-alcateia.md) | Falta 12 `:381-410` | seco é regra de validade do **alvo** (água é último recurso); "organizado" é teto numérico, não adjetivo; criatura nunca vira texto; spawn nunca a menos de `SAFE_SPAWN_DIST` nem com LOS livre | `lobo_escolhe_trilha_seca`, `resgate_de_margem_sobrevive_a_arvore` e `spawn_fora_da_vista_do_jogador` (nascem **vermelhas**), `nadar_so_sem_saida_seca`, `dois_lobos_nao_farejam_a_mesma_celula`, `alvo_estavel_por_segundo`, `nenhum_aviso_de_matilha_no_hud` + `feedback_do_jogador_continua_no_hud` (par obrigatório), `convivio_nao_estoura_orcamento` |
| 15 | [Oráculo embutido no boot: o jogo levanta o llama-server](15-oraculo-embutido-no-boot.md) | autorização nova do dono em 2026-11-20, fora da lista `Falta` do status | com `Rodar.bat` e **nenhum** PowerShell aberto, a linha `ia:` do F3 enche dentro do prazo da cena de prova | `host_devolve_health_200`, `boot_nao_bloqueia_janela`, `reuso_nao_cria_segundo_processo`, `porta_alheia_continua_viva`, `fechar_janela_mata_o_filho`, `suite_nao_levanta_modelo` — colhidas em cena própria, nunca na suíte |
| 17 | [Física de blocos que caem (o evento que ninguém assina)](17-fisica-de-blocos-que-caem.md) | autorização do dono em 2026-11-21, prompt "Física de Blocos + Mundo Reativo" item A; a especificação já estava no doc 10, o código não | um `SAND` sem apoio **some** do grid num tick e **reaparece** mais baixo noutro, `queued` volta a zero e **nenhuma varredura do mapa** aconteceu no meio | `queda_sem_varredura_de_mundo`, `queda_move_a_celula` (nasce **vermelha**: `block_changed` não tem um `.connect(` em lugar nenhum), `queda_cascade_em_passos`, `bloco_em_queda_nao_sobe` (o *auto step-up* do `VoxelBody` tem de ser zerado), `queda_pousa_antes_do_save`, `queda_nao_custou_tempo_de_ninguem`, `journal_hash_muda_so_com_movimento` |
| 18 | [Mundo vivo: grama que cresce e o mato decorativo](18-mundo-vivo-grama-e-mato.md) | autorização do dono em 2026-11-21, prompt "Física de Blocos + Mundo Vivo" itens B e C; **sem** especificação no doc 10 — esta página é a primeira vez que a regra é escrita | `DIRT` com ar acima e `GRASS` ao lado vira `GRASS` em tempo finito **sem varrer nada** — e sem vizinha não muda em 10 000 ticks | `grama_precisa_de_vizinha` (o par vermelho), `crescimento_nao_varre_nada`, `crescimento_sobrevive_ao_save`, `grama_nao_cresce_onde_nao_ha_grama`, `crescimento_nao_estoura_a_malha`, `mato_e_nao_solidez_nem_pedra`, `mato_nao_engole_o_clique` (o campo `substituivel` lido pelo `_try_place`), `crescimento_nao_consome_rng_da_sessao` |

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
| 07 | `bench/af-bench-bakeoff-07` | `main`, doc → runner → bake-off |
| 08 | `feat/minds-inspector-f3-08` | `main` |
| 09 | `feat/bioma-e-cor-de-pelo-09` | `main` — **abre depois de 08 fechar**; nenhuma das outras cinco abre enquanto esta estiver aberta (`src/entities/wolf.gd` e `src/main.gd` são de escritor único) |
| 10 | `feat/alcateia-rutinas-10` | `main`, depois de 09 (a cor e o viés por bioma mudam o que a matilha lê) |
| 11 | `feat/acasalamento-e-censo-11` | `main`, depois de **14**: acasalar exige saber quem é adulto e quem está perto, e o filhote nasce pelo predicado de spawn seguro que a 14 entrega |
| 12 | `feat/bicho-cavando-12` | `main`, depois de 11 (a folha `dig` entra na árvore já reorganizada, e o teto de censo decide quantos lobos cavam) |
| 13 | `feat/arvore-genealogica-13` | `main`, **por último**, depois de 18: sem a 11 não há nascimento por causa interna (o que escrever na árvore) e sem a 10 não há leitura de vizinho (como parentesco vira comportamento) — e se o Éter ganhar canal novo, re-mediar as pernas anteriores é mais barato do que deixar `Channel.COUNT` no meio da fila |
| 14 | `feat/alcateia-convivio-14` | `main`, depois de 10 e **antes** de 11: mexe nas mesmas folhas de movimento que a alcateia reorganizou, e o predicado "longe dos olhos do jogador" tem de existir antes de alguém precisar dele para pôr um filhote no mundo |
| 15 | `docs/oracle-embutido-15` (estes dois commits) → `feat/oraculo-embutido-no-boot-15` (código) | `main`, **entre 10 e 14**: a 15 não encosta em nenhuma linha do código da matilha nem das outras pernas — em `src/main.gd` só pendura um nó novo no boot — enquanto a 14 depende da ronda por setor que a perna 10 já escreveu e pousou (código `0c38489`, `main` publicada `b779cee`) |
| 16 | `feat/tocas-espalhadas-16` (nome provisório — **a página ainda não existe**) | `main`, **logo depois de 11**, escolha do dono nesta fila: é a resposta a ele ter percorrido o mapa inteiro e visto um lobo só. Antes de abrir branch, escreve-se o dossiê |
| 17 | `feat/fisica-de-blocos-que-caem-17` | `main`, **depois de 12**: as duas pernas escrevem pelo mesmo `set_block` e pelo mesmo `block_changed`, e a fila de gravidade muda o custo medido do cavar — abrir a 17 antes obrigaria a 12 a re-rodar o gate dela com a fila anexada. Não encosta em `wolf.gd` |
| 18 | `feat/mundo-vivo-grama-e-mato-18` | `main`, **depois de 17**: é o segundo comprador do `BlockUpdateQueue` que a 17 escreve (regra da casa — generalizar no segundo chamador, não no primeiro), e o `PLANT` gasta o id 17 da reserva que a 17 não toca |

A ordem 09 → 10 → 15 → 14 → 11 → 16 → 12 → 17 → 18 → 13 não é preferência: é a exceção de serialização registrada
**antes** do código em [`AGENTS.md`](../../AGENTS.md), "Escopo autorizado agora", e reafirmada em
[`docs/melhorias-status.md`](../melhorias-status.md#em-andamento). O encadeamento é de dados, não de
cerimônia: cor depende de bioma, cercar depende de quem mais existe na matilha, a convivência reusa as
folhas que a alcateia reorganizou e entrega à 11 o ponto de spawn, acasalamento depende de dois adultos
próximos, as tocas dependem do censo que a 11 variabilizou, cavar é folha da árvore já montada, a gravidade
de blocos é o segundo consumidor do `block_changed` que o cavar acabou de abrir, o crescimento é o segundo
comprador da fila que a gravidade escreveu, e a árvore genealógica depende de nascimento por causa
interna — e a 15 entra no meio porque é o caminho do `Rodar.bat`, não do código da matilha. Além disso,
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

## Verificação destas dezessete páginas

```sh
python .tools/verify_plan_cites.py docs/planos/01-estado-inicial-e-ordem-autoritativa.md
python .tools/verify_plan_ids.py   docs/planos/01-estado-inicial-e-ordem-autoritativa.md
```

**Medida desta rodada (as dezessete páginas, `main` em `86e63c4` + estes dois arquivos novos):**
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
`README.md:533` (linha de lista do Éter; os ~4,3 s de malharia dos 64 chunks estão em `:548`), e `07:67`
e `07:137` apontavam `README.md:505-512` e `:507` — que é a seção do oráculo local — para a queda de
~16 s para ~7,5 s com a cópia linear, que está em `:546-553`. Cada número de README desta frase é da
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
  `tests/aether_reactions_test.gd:62-78`", pesos WORK/BLOOD/FEAR em `src/ai/utility_scorer.gd` e
  `audio_director.gd:314` como posição de playback → **03 §9**;
- `worst_sim_us` (o nome real é `_sim_worst_us`, `tests/aether_reactions_test.gd:37`) → **03 §5**;
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

As imprecisões reais achadas em `AGENTS.md` nesta rodada foram corrigidas no próprio contrato, uma por
uma, depois de lidas as duas pontas: `player.gd:659`/`:675` são os cabeçalhos de `_mine_target()` e
`_try_place()`, e o `world.set_block` que escreve no mundo está em `:667`/`:693`; o `_on_acted` que
imprime WORK saiu de `main.gd:328-333` para `:337-342` quando o viés de imprint entrou; o teto do load
que pareia por índice é `main.gd:479`, não `:470`; as três promessas da lavra estão em
`tests/smoke_test.gd:884-892`, não `:802-812`; e a conta do "objeto deus" passa a estar pinada na
revisão medida — **510 linhas em `src/main.gd` na `main` em `eb6ec8d`** — porque a perna 10 em curso vai
mover esse número, e um número sem pino é exatamente o que estes furos cobram. Nada disso muda
mandato: é deriva de linha.
