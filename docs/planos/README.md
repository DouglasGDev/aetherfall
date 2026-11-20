# Dossiês por item da fila

Catorze arquivos, um por linha aberta da fila de [`docs/melhorias-status.md`](../melhorias-status.md)
("Falta", `:303-430`, e os checklists P0/P1, `:434-451`). Cada dossiê é **leitura de código, não
corrida**: nenhuma engine foi rodada aqui, nenhum número publicado foi re-medido por estes arquivos
e **nenhum gate de fase se fecha por eles** — quem abre e fecha gate é o dono
([`AGENTS.md`](../../AGENTS.md), mandato 4). Marcas `[TARGET]` / `[CLAIMED]` / `[MEASURED]` /
`[DECIDED]` / `[OPEN]` seguem a legenda de [`docs/design/README.md:10-16`](../design/README.md#L10-L16).
Os seis últimos (09 → 10 → 14 → 11 → 12 → 13) existem porque o dono ampliou o escopo em 2026-11-20 —
bioma/cor, alcateia, convivência da matilha, acasalamento com filhote, bicho cavando e a árvore
genealógica com o Éter lendo parentesco — e a ordem serializada deles está escrita na mesma seção do
contrato, não deduzida depois.

| # | Dossiê | Linha da fila | Premissa nomeada | O que decide, em headless |
|---|---|---|---|---|
| 01 | [Estado inicial, comandos, RNG e ordem autoritativa](01-estado-inicial-e-ordem-autoritativa.md) | P0 `:436`, Falta 2 `:310-319` | o diário tem duas portas: o hash do tick N não é função só do tick N | `snapshot_resta_hash`, `ordem_independente_de_quadros` (nasce **vermelho**, com o número real de ticks divergentes), `rng_restaurada_no_load`, `formato_declarado` |
| 02 | [Censo do lobo em 20 sementes × 1000 ticks](02-censo-multi-semente.md) | P1 `:446`, Falta 3 `:320-321` | cadência sintética, não relógio de parede | `repeticao_por_semente` 20/20 e `contraste_de_cadencia` (K = 1 vs K = 3 tem de **divergir**; se não divergir a checagem é vazia) |
| 03 | [Canais MORTE / SOM / FOGO](03-canais-morte-som-fogo.md) | P1 `:444`, Falta 4 `:322-330` | um canal só existe se fonte e curva leitora caírem no mesmo lote | A/B com o canal zerado mudando `intent` ou `_reaction`; recusa de índice de canal fora de faixa; `Channel.COUNT` puxa `FORMAT_VERSION`. **FOGO fica bloqueado** sem bloco/entidade de fogo |
| 04 | [Budget HOT medido](04-budget-hot-medido.md) | P1 `:445`, Falta 5 `:331-335` | "2,5 ms medido" embute duas metade não medidas: cinco mentes no mesmo tick e o segmento de decisão inteiro | checagem (a): se nenhum tick teve as cinco mentes vivas, vermelho em vez de zero; `EXPECTED_CHECKS` (`tests/aether_reactions_test.gd:17`, hoje 119) sobe com o lote |
| 05 | [Difusão do Éter fora do tick](05-difusao-fora-do-tick.md) | P1 `:447`, Falta 6 `:336-338` | hoje a difusão é síncrona e o lobo vê o resultado por isso | primeiro a colheita (nenhum µs de `diffuse_and_decay` existe); o corte só com o hash por semente **inalterado** |
| 06 | [Decompor `main.gd` pelo eixo do dono](06-decompor-main-gd.md) | Falta 7 `:339-341` | ônibus não é dono: um bloco vira dono quando já tem comprador fora de `main.gd` | K1 bancadas → K2 fila/cadáveres → K3 matilha; K4 (persistência) fica `[OPEN]` até aparecer o segundo consumidor |
| 07 | [`af-bench`, bake-off de voxel e o doc do `SimClock`](07-af-bench-bake-off-voxel-e-doc-do-simclock.md) | P0 `:437`, `:438-439`, `:440` | três premissas, uma por peça; hash é função do passo, fps é função da máquina | ordem interna: doc → runner de `dt` fixo → 3 execuções de 12 000 ticks → bake-off com ≥ 2 braços tabelados |
| 08 | [`MindStore` e `MindsInspector`](08-mindstore-e-mindsinspector.md) | P1 `:448-449`, `:450-451` | `MindStore` muda **posse**, `MindsInspector` mostra **composição** — nenhuma das duas decide | recomendação lida: F3 estendido (reaproveita `src/main.gd:245-250` e `src/ui/hud.gd:267-274`) antes de qualquer `.tscn` novo |
| 09 | [Bioma, cor do pelo e fundo de Éter por bioma](09-bioma-cor-de-pelo-e-ether.md) | Falta 8 `:342-356` | bioma só existe se decidir algo observável: cor do pelo e viés de imprint; derivar **não** pode alterar terreno nem hash | `bioma_deterministico`, `bioma_nao_altera_terreno` (a que fecha o lote), `cor_do_pelo_vem_do_bioma`, `imprint_bioma_tem_mesma_ordem` |
| 10 | [Rotinas de alcateia](10-alcateia-rutinas.md) | Falta 9 `:357-363` | a intenção de um lobo muda quando outro está por perto — 1 lobo vs 4 lobos no mesmo cenário tem de **divergir** | `contraste_de_alcateia`, `cercar_calcula_assentos`, `ataque_escalonado`, `medo_contagia` / `amigo_amortece`, `alcateia_nao_consome_rng_da_sessao` |
| 11 | [Acasalamento, filhote que cresce e censo variável](11-acasalamento-filhote-e-censo.md) | Falta 10 `:364-371` | um save gravado com 7 lobos carrega 7 lobos — e crescer é função do `clock.tick`, não de parede | `acasalar_aumenta_censo`, `filhote_cresce_por_tick`, `filhote_nao_morde`, `load_leva_todo_o_censo` (nasce **vermelha** no código atual), `censo_respeita_teto`, `journal_hash_inalterado_sem_escolha` |
| 12 | [Bicho cavando voxel](12-bicho-cavando-voxel.md) | Falta 11 `:372-380` | um voxel some por ação do lobo **sem input do jogador**, e a malharia disso é medida antes de ser celebrada | `lobo_cava_sem_input_do_jogador`, `cavar_respeita_a_lista`, `work_de_bicho_nao_confundido`, `malharia_do_cavar_medida`, `abrir_passagem_depois_de_bloqueio` |
| 13 | [Árvore genealógica de todo ser vivo, e o Éter lendo parentesco](13-arvore-genealogica-e-ether.md) | Falta 13 `:411-430` | ascendência só existe se nascer de dois adultos, sobreviver ao save e **mudar algo observável**; herdar é genoma-base, nunca a memória nem o trauma do pai | `genealogia_muda_algo_observavel` e `load_preserva_ascendencia` (nascem **vermelhas**), `pelo_de_fundador_vem_do_bioma`, `heranca_nao_repete_deriva`, `eter_devolve_quem_sangrou`, `journal_hash_inalterado_sem_nascimento`, `genealogia_nao_consome_rng_da_sessao`, `ascendencia_e_int_nao_referencia` |
| 14 | [Convivência da alcateia: terra seca, matilha legível e spawn fora dos olhos](14-convivio-da-alcateia.md) | Falta 12 `:381-410` | seco é regra de validade do **alvo** (água é último recurso); "organizado" é teto numérico, não adjetivo; criatura nunca vira texto; spawn nunca a menos de `SAFE_SPAWN_DIST` nem com LOS livre | `lobo_escolhe_trilha_seca`, `resgate_de_margem_sobrevive_a_arvore` e `spawn_fora_da_vista_do_jogador` (nascem **vermelhas**), `nadar_so_sem_saida_seca`, `dois_lobos_nao_farejam_a_mesma_celula`, `alvo_estavel_por_segundo`, `nenhum_aviso_de_matilha_no_hud` + `feedback_do_jogador_continua_no_hud` (par obrigatório), `convivio_nao_estoura_orcamento` |

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
| 13 | `feat/arvore-genealogica-13` | `main`, **por último**, depois de 12: sem a 11 não há nascimento por causa interna (o que escrever na árvore) e sem a 10 não há leitura de vizinho (como parentesco vira comportamento) |
| 14 | `feat/alcateia-convivio-14` | `main`, depois de 10 e **antes** de 11: mexe nas mesmas folhas de movimento que a alcateia reorganizou, e o predicado "longe dos olhos do jogador" tem de existir antes de alguém precisar dele para pôr um filhote no mundo |

A ordem 09 → 10 → 14 → 11 → 12 → 13 não é preferência: é a exceção de serialização registrada
**antes** do código em [`AGENTS.md`](../../AGENTS.md), "Escopo autorizado agora", e reafirmada em
[`docs/melhorias-status.md`](../melhorias-status.md#em-andamento). O encadeamento é de dados, não de
cerimônia: cor depende de bioma, cercar depende de quem mais existe na matilha, a convivência reusa as
folhas que a alcateia reorganizou e entrega à 11 o ponto de spawn, acasalamento depende de dois adultos
próximos, cavar é folha da árvore já montada, e a árvore genealógica depende de nascimento por causa
interna — além disso, deixar uma mudança de `Channel.COUNT` no meio da fila custaria re-mediar as
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

## Verificação destas catorze páginas

```sh
python .tools/verify_plan_cites.py docs/planos/01-estado-inicial-e-ordem-autoritativa.md
python .tools/verify_plan_ids.py   docs/planos/01-estado-inicial-e-ordem-autoritativa.md
```

O primeiro confere se todo `arquivo:linha` citado existe e se o número cabe no arquivo: nas catorze
páginas são **790 citações conferidas, 0 números fora do arquivo** (61 · 47 · 25 · 73 · 67 · 33 · 44 ·
52 · 36 · 74 · 56 · 54 · 103 · 65, na ordem da tabela), e nesta página há mais 12 — **802** no
diretório inteiro. Somando os três documentos que governam a casa — [`AGENTS.md`](../../AGENTS.md),
[`README.md`](../../README.md) e [`docs/melhorias-status.md`](../melhorias-status.md) — são mais
**322 números (85 · 0 · 237), 0 fora do arquivo**. A conta anterior desta página — 622 · 629 no
diretório e 261 (72 · 0 · 189) no trio — media **doze** páginas e deixava a página 07 em 39: os cinco
números que ela cita em `.tools/af-clean-suite*.log` só são conferidos onde `.tools/` existe, porque a
gateira **não conta** citação de arquivo ausente. Aqui `.tools/` está no `.gitignore` e está na árvore,
então 44 é o que o comando devolve; numa árvore sem os logs dos runs o mesmo comando devolve 39, e essa
é a diferença, não um erro de corpo. Os números acima são re-medidos por comando nesta árvore, com
`src/` e `tests/` na `main` em `eb6ec8d` e os documentos desta rodada por
cima; não são herdados do texto. As únicas ausências que a gateira devolve são peças declaradas como
inexistentes: `src/core/sim/tick_clock.gd` (caminho que
[`docs/design/06:33`](../design/06-godot-architecture.md#L33) ainda cita), `docs/engine/simclock.md`
(entrega de P0 que ainda não existe) e `tests/wolf_multiseed_census_test.gd` (o runner que o dossiê 02
propõe).

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
governam a casa. A conta publicada antes — **60 · 8 · 6 = 74** — não se reproduce por regra nenhuma:
somando esta página ao corpus o status dá 60, mas aí o `README.md` da raiz dá 9 (collapsed) ou 12
(sem colapsar), nunca 6; sobre os doze dossiês antigos dá 59 · 8 · 3 = 70. As duas páginas novas não
adicionam nada ao status nem ao contrato (linkam-nos por nome), mas adicionam **3** ao `README.md` da
raiz: `13` aponta `:192` e `:197` e `14` aponta `:192`. Conferindo conteúdo contra a `main` em `eb6ec8d`,
quatro ponteiros estavam errados e **foram corrigidos na própria página**: `12:63` dizia
`docs/melhorias-status.md:78` (prosa da seção anterior; o par geração/malharia está em `:83`) e
`README.md:533` (linha de lista do Éter; os ~4,3 s de malharia dos 64 chunks estão em `:548`), e `07:67`
e `07:137` apontavam `README.md:505-512` e `:507` — que é a seção do oráculo local — para a queda de
~16 s para ~7,5 s com a cópia linear, que está em `:546-553`. Restam **69** referências a estes três
arquivos sem conferência de conteúdo, e é por isso que nenhuma delas deve ser lida como conferida. A
perna de docs que re-derive as 69 pelo conteúdo continua aberta, registrada no furo. Este re-contado mora
aqui, e não dentro do furo #14, por um motivo que é o próprio furo: escrever no meio do status empurra
tudo abaixo da linha inserida, e as referências `:1064` e `:1066` que a página 07 já faz sairiam do lugar
por minha mão — re-derivar o corpus inteiro é uma perna, e ela roda depois de a 10 pousar, porque cada
merge desta fila move outra vez os números de `wolf.gd` e `main.gd`.
O segundo script confere
identificador: todo nome em backticks que não existe em `src/` ou `tests/` é ou nome de
checagem/peça nova declarada como tal, ou invenção registrada no próprio arquivo, ou um SHA de commit
(`a8967e0`, `ff347d2`, `eb6ec8d`), que a gateira lê como identificador e não há motivo para existir em
código. Nas duas páginas novas (13 e 14) todos os ausentes são da primeira ou da terceira classe:
checagens propostas, peças propostas (`FamilyTree`, `PackState`, `SAFE_SPAWN_DIST`) e commits. As duas gateiras
moram em `.tools/`, que está no `.gitignore` — o mesmo que já se diz dos logs e do harness de
capturas: quem for conferir por clone limpo precisa recriá-los, e os números acima valem para a
árvore de trabalho que os tem.

## Invenções de briefing registradas pelos arquivos

Os prompts que geraram estes dossiês trouxeram âncoras falsas, e o código as refutou. Nada delas
entrou como fato; estão documentadas nos arquivos que as receberam:

- meia-vida "morta", "11,33% por passada", "4,8 s efetivos", `TrailReader`, `_sample_trail`,
  `_sighting_cache_cap`, `_sighting_cache_ttl`, `_scan_interval`, `DECAY_PER_SEC`, `SOURCE_RATE`,
  `SATURATION`, `imprint(channel, cell, amount)`, "três dicionários paralelos em
  `tests/aether_reactions_test.gd:57-73`", pesos WORK/BLOOD/FEAR em `src/ai/utility_scorer.gd` e
  `audio_director.gd:314` como posição de playback → **03 §9**;
- `worst_sim_us` (o nome real é `_sim_worst_us`, `tests/aether_reactions_test.gd:32`) → **03 §5**;
- deslocamento de +1 nas constantes de `src/main.gd` citadas por `AGENTS.md` → **07 §8** (as
  citações do contrato estão certas: `:12` difusão, `:13` malha, `:14` visão, `:16` cadáveres;
  `WOLF_COUNT` é `:9`);
- `src/session/`, `wolf_roster.gd`, `scene_readiness.gd` como peças esperadas → **01, "Estado real"**
  (nenhum desses nomes existe em `src/` nem em `docs/design/`);
- linhas 27-28 da tabela do prompt master (reais: `:29` e `:30`) e `MemoryGate` como código → **08 §8**;
- `EXPECTED_CHECKS` em `tests/aether_reactions_test.gd:16` com 109, e a suíte em 236 checagens, vindos
  como premissa dos dossiês da ampliação → reais: `:17` com **119**, e **237 / 0 falhas / 35,5 s**
  (pino em `README.md:192`). E o blackboard não está em `wolf.gd:433` (linha de fim de
  `_build_scorer`): os dois dicionários por lobo por tick são `:430` e `:460` → **14 §2**;
- "todo ser vivo" como escada já implementada: `src/entities/` tem **uma** espécie animal, **nenhum**
  NPC e o jogador sem `Mind` nem `identity` (grep devolve zero ocorrências dos dois nomes em
  `player.gd`), então os três degraus acima do lobo ficam `[TARGET]`, com zero código → **13 §1, §3.4**.

As imprecisões reais achadas em `AGENTS.md` nesta rodada foram corrigidas no próprio contrato, uma por
uma, depois de lidas as duas pontas: `player.gd:659`/`:675` são os cabeçalhos de `_mine_target()` e
`_try_place()`, e o `world.set_block` que escreve no mundo está em `:667`/`:693`; o `_on_acted` que
imprime WORK saiu de `main.gd:268-273` para `:277-282` quando o viés de imprint entrou; o teto do load
que pareia por índice é `main.gd:419`, não `:410`; as três promessas da lavra estão em
`tests/smoke_test.gd:862-870`, não `:780-790`; e a conta do "objeto deus" passa a estar pinada na
revisão medida — **510 linhas em `src/main.gd` na `main` em `eb6ec8d`** — porque a perna 10 em curso vai
mover esse número, e um número sem pino é exatamente o que estes furos cobram. Nada disso muda
mandato: é deriva de linha.
