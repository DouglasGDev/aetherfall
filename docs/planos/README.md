# Dossiês por item da fila

Doze arquivos, um por linha aberta da fila de [`docs/melhorias-status.md`](../melhorias-status.md)
("Falta", `:268-337`, e os checklists P0/P1, `:341-358`). Cada dossiê é **leitura de código, não
corrida**: nenhuma engine foi rodada aqui, nenhum número publicado foi re-medido por estes arquivos
e **nenhum gate de fase se fecha por eles** — quem abre e fecha gate é o dono
([`AGENTS.md`](../../AGENTS.md), mandato 4). Marcas `[TARGET]` / `[CLAIMED]` / `[MEASURED]` /
`[DECIDED]` / `[OPEN]` seguem a legenda de [`docs/design/README.md:10-16`](../design/README.md#L10-L16).
Os quatro últimos (09 → 12) existem porque o dono ampliou o escopo em 2026-11-20 — bioma/cor,
alcateia, acasalamento com filhote e bicho cavando — e a ordem serializada deles está escrita na
mesma seção do contrato, não deduzida depois.

| # | Dossiê | Linha da fila | Premissa nomeada | O que decide, em headless |
|---|---|---|---|---|
| 01 | [Estado inicial, comandos, RNG e ordem autoritativa](01-estado-inicial-e-ordem-autoritativa.md) | P0 `:343`, Falta 2 `:275-284` | o diário tem duas portas: o hash do tick N não é função só do tick N | `snapshot_resta_hash`, `ordem_independente_de_quadros` (nasce **vermelho**, com o número real de ticks divergentes), `rng_restaurada_no_load`, `formato_declarado` |
| 02 | [Censo do lobo em 20 sementes × 1000 ticks](02-censo-multi-semente.md) | P1 `:353`, Falta 3 `:285-286` | cadência sintética, não relógio de parede | `repeticao_por_semente` 20/20 e `contraste_de_cadencia` (K = 1 vs K = 3 tem de **divergir**; se não divergir a checagem é vazia) |
| 03 | [Canais MORTE / SOM / FOGO](03-canais-morte-som-fogo.md) | P1 `:351`, Falta 4 `:287-295` | um canal só existe se fonte e curva leitora caírem no mesmo lote | A/B com o canal zerado mudando `intent` ou `_reaction`; recusa de índice de canal fora de faixa; `Channel.COUNT` puxa `FORMAT_VERSION`. **FOGO fica bloqueado** sem bloco/entidade de fogo |
| 04 | [Budget HOT medido](04-budget-hot-medido.md) | P1 `:352`, Falta 5 `:296-300` | "2,5 ms medido" embute duas metade não medidas: cinco mentes no mesmo tick e o segmento de decisão inteiro | checagem (a): se nenhum tick teve as cinco mentes vivas, vermelho em vez de zero; `EXPECTED_CHECKS` (`tests/aether_reactions_test.gd:16`, hoje 109) sobe com o lote |
| 05 | [Difusão do Éter fora do tick](05-difusao-fora-do-tick.md) | P1 `:354`, Falta 6 `:301-303` | hoje a difusão é síncrona e o lobo vê o resultado por isso | primeiro a colheita (nenhum µs de `diffuse_and_decay` existe); o corte só com o hash por semente **inalterado** |
| 06 | [Decompor `main.gd` pelo eixo do dono](06-decompor-main-gd.md) | Falta 7 `:304-306` | ônibus não é dono: um bloco vira dono quando já tem comprador fora de `main.gd` | K1 bancadas → K2 fila/cadáveres → K3 matilha; K4 (persistência) fica `[OPEN]` até aparecer o segundo consumidor |
| 07 | [`af-bench`, bake-off de voxel e o doc do `SimClock`](07-af-bench-bake-off-voxel-e-doc-do-simclock.md) | P0 `:344`, `:345-346`, `:347` | três premissas, uma por peça; hash é função do passo, fps é função da máquina | ordem interna: doc → runner de `dt` fixo → 3 execuções de 12 000 ticks → bake-off com ≥ 2 braços tabelados |
| 08 | [`MindStore` e `MindsInspector`](08-mindstore-e-mindsinspector.md) | P1 `:355-356`, `:357-358` | `MindStore` muda **posse**, `MindsInspector` mostra **composição** — nenhuma das duas decide | recomendação lida: F3 estendido (reaproveita `src/main.gd:245-250` e `src/ui/hud.gd:267-274`) antes de qualquer `.tscn` novo |
| 09 | [Bioma, cor do pelo e fundo de Éter por bioma](09-bioma-cor-de-pelo-e-ether.md) | Falta 8 `:307-313` | bioma só existe se decidir algo observável: cor do pelo e viés de imprint; derivar **não** pode alterar terreno nem hash | `bioma_deterministico`, `bioma_nao_altera_terreno` (a que fecha o lote), `cor_do_pelo_vem_do_bioma`, `imprint_bioma_tem_mesma_ordem` |
| 10 | [Rotinas de alcateia](10-alcateia-rutinas.md) | Falta 9 `:314-320` | a intenção de um lobo muda quando outro está por perto — 1 lobo vs 4 lobos no mesmo cenário tem de **divergir** | `contraste_de_alcateia`, `cercar_calcula_assentos`, `ataque_escalonado`, `medo_contagia` / `amigo_amortece`, `alcateia_nao_consome_rng_da_sessao` |
| 11 | [Acasalamento, filhote que cresce e censo variável](11-acasalamento-filhote-e-censo.md) | Falta 10 `:321-328` | um save gravado com 7 lobos carrega 7 lobos — e crescer é função do `clock.tick`, não de parede | `acasalar_aumenta_censo`, `filhote_cresce_por_tick`, `filhote_nao_morde`, `load_leva_todo_o_censo` (nasce **vermelha** no código atual), `censo_respeita_teto`, `journal_hash_inalterado_sem_escolha` |
| 12 | [Bicho cavando voxel](12-bicho-cavando-voxel.md) | Falta 11 `:329-337` | um voxel some por ação do lobo **sem input do jogador**, e a malharia disso é medida antes de ser celebrada | `lobo_cava_sem_input_do_jogador`, `cavar_respeita_a_lista`, `work_de_bicho_nao_confundido`, `malharia_do_cavar_medida`, `abrir_passagem_depois_de_bloqueio` |

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
| 09 | `feat/bioma-e-cor-de-pelo-09` | `main` — **abre depois de 08 fechar**; nenhuma das outras três abre enquanto esta estiver aberta (`src/entities/wolf.gd` e `src/main.gd` são de escritor único) |
| 10 | `feat/alcateia-rutinas-10` | `main`, depois de 09 (a cor e o viés por bioma mudam o que a matilha lê) |
| 11 | `feat/acasalamento-e-censo-11` | `main`, depois de 10 (acasalar exige saber quem é adulto e quem está perto) |
| 12 | `feat/bicho-cavando-12` | `main`, depois de 11 (a folha `dig` entra na árvore já reorganizada, e o teto de censo decide quantos lobos cavam) |

A ordem 09 → 10 → 11 → 12 não é preferência: é a exceção de serialização registrada **antes** do
código em [`AGENTS.md`](../../AGENTS.md), "Escopo autorizado agora". Duas branches abertas tocando
`wolf.gd`/`main.gd` ao mesmo tempo é exatamente o incidente do dossiê 03, que apagou uma versão já
conferida.

Nenhuma branch nasce de outra branch de trabalho, e nenhuma fecha gate de fase por si: o gate é
do dono, com comando + critério + doc.

## Como ler um dossiê

Todos seguem a mesma espinha: premissa nomeada (uma frase falsificável) → estado real do código
com `arquivo:linha` → o que a peça exige → gate em headless com comando que **já existe** → custo
pelas quatro perguntas do contrato → o que NÃO fazer → commits atômicos (um assunto, uma corrida) →
citações que não conferem.

## Verificação destas doze páginas

```sh
python .tools/verify_plan_cites.py docs/planos/01-estado-inicial-e-ordem-autoritativa.md
python .tools/verify_plan_ids.py   docs/planos/01-estado-inicial-e-ordem-autoritativa.md
```

O primeiro confere se todo `arquivo:linha` citado existe e se o número cabe no arquivo: nas doze
páginas são **622 citações conferidas, 0 números fora do arquivo** (61 · 47 · 25 · 73 · 67 · 33 · 44 ·
52 · 36 · 74 · 56 · 54, na ordem da tabela), e nesta página há mais 7 — **629** no diretório inteiro.
Somando os três documentos que governam a casa — [`AGENTS.md`](../../AGENTS.md),
[`README.md`](../../README.md) e [`docs/melhorias-status.md`](../melhorias-status.md) — são mais
**261 números (72 · 0 · 189), 0 fora do arquivo**. Os **392 / 399 / 70** publicados aqui na rodada
anterior estavam velhos: as páginas 03, 05, 06 e 08 mudaram de corpo depois da contagem, e os quatro
dossiês novos somam 220 citações — a conta acima é re-medida por comando, não herdada do texto.

O que a gateira **não** confere é o conteúdo da linha apontada, e isso já tem nome:
[`docs/melhorias-status.md`, furo #14](../melhorias-status.md#furos-descobertos) mede as **59**
referências que os dossiês fazem a linhas deste status e as **8** que fazem ao `AGENTS.md`, mostra
que 32 e 3 delas saíram do lugar por causa das inserções desta rodada (+31 e +21 linhas) e que pelo
menos quatro já estavam erradas antes dela — caias em faixa, portanto invisíveis para o verificador.
Os únicos arquivos apontados como inexistentes seguem sendo peças marcadas como inexistentes:
`src/core/sim/tick_clock.gd` (caminho que [`docs/design/06:33`](../design/06-godot-architecture.md#L33)
ainda cita), `docs/engine/simclock.md` (entrega de P0 que ainda não existe) e
`tests/wolf_multiseed_census_test.gd` (o runner que o dossiê 02 propõe). O segundo script confere
identificador: todo nome em backticks que não existe em `src/` ou `tests/` é ou nome de
checagem/peça nova declarada como tal, ou invenção registrada no próprio arquivo. As duas gateiras
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
- linhas 27-28 da tabela do prompt master (reais: `:29` e `:30`) e `MemoryGate` como código → **08 §8**.

A única imprecisão real achada em `AGENTS.md` é `src/entities/player.gd:659`/`:675`: as duas linhas
são os cabeçalhos de `_mine_target()` e `_try_place()`, e o `world.set_block` que escreve no mundo
está em `:667` e `:693`. Isso não muda nenhum mandato e não é motivo para reescrever o contrato.
