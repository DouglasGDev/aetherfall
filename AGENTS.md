# Aetherfall — instruções de trabalho (obrigatórias)

Contrato de colaboração deste repositório: **como** se muda o código daqui. O **que** falta
mudar — furos, gates, débitos e o que foi medido — está em
[`docs/melhorias-status.md`](docs/melhorias-status.md). São duas metades da mesma cobrança:
o arquivo de status audita cada promessa contra o código e contra o log e devolve um veredito;
este documento pega o veredito e o trata como regra de comportamento. Nada aqui manda fazer
o que o status marca como peça inexistente.

Motor Godot 4.7.2-stable com Vulkan Forward+ (`config/features` em
[project.godot:10](project.godot#L10)), GDScript tipado, sem C# e sem addons. Código MIT
([LICENSE](LICENSE)); modelos e packs em [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
Repositório: <https://github.com/DouglasGDev/aetherfall>.

## Os três mandatos, e o que cada um responde

| Você quer saber | Onde está |
| --- | --- |
| O que o projeto promete × o que `src/` faz hoje | [`docs/melhorias-status.md`](docs/melhorias-status.md), "Os prompts × o código" |
| Feito nesta rodada, em andamento, fila, backlog e débitos | idem, seções seguintes |
| Que corrida sustenta cada número publicado | idem, "Notas de medição" |
| Como conduzir a mudança: escopo, atomicidade, branches, medição, comentário | este arquivo |
| Custo de uma mudança: budget, alocação, LOD, o que cresce sem justificativa | este arquivo, "Disciplina de otimização", e a terceira tabela do status |
| O que é cada fase e qual é o gate dela | [docs/design/08](docs/design/08-roadmap-risks-licensing.md) |
| O que é meta de design e o que é código que existe | [docs/design/README.md](docs/design/README.md), legenda `[TARGET]`/`[MEASURED]`/`[DECIDED]`/`[OPEN]` |

## Princípios invioláveis e onde cada um já está seguro

1. **Nada simulado.** Nenhum resultado inventado, placeholder bonito ou fallback que finja
   sucesso. *Seguro por:* cada número publicado aponta um `.log` de uma corrida real, inclusive
   as que não sustentam a tese, na tabela de medição do status. *Cobrança operacional:* um
   `SCRIPT ERROR` dentro de um passo de teste derruba checagens em silêncio — medido, quatro
   corridas que deram 215 checagens em vez de 219 sem nenhum vermelho. A contagem se confere
   antes de qualquer lote, não depois.
2. **A mente propõe, as regras dispõem.** LLM/oráculo nunca decide movimento, dano, posição ou
   estado de mundo. *Seguro por construção hoje:* a única saída de `MindOracle` que chega a quem
   age é o dicionário `_narrations` ([mind_oracle.gd:86](src/ai/mind_oracle.gd#L86), gravado em
   [:196](src/ai/mind_oracle.gd#L196)), lido por `narration_of()`
   ([:164-165](src/ai/mind_oracle.gd#L164-L165)) e entregue só ao HUD
   ([main.gd:198](src/main.gd#L198) → [hud.gd:276-277](src/ui/hud.gd#L276-L277)). O dono do pack
   lê um campo do oráculo — `last_reason` na linha de status do F3
   ([af_mind_runtime.gd:85-86](src/ai/af_mind_runtime.gd#L85-L86), entregue por
   `llm_status_provider` em [main.gd:265](src/main.gd#L265)) — leitura, nenhuma escrita. Não
   existe caminho do oráculo para `Mind`, `Wolf` ou `VoxelWorld`; a decisão
   vem de BT + utilidade
   ([wolf.gd:422-450](src/entities/wolf.gd#L422-L450), [:824-826](src/entities/wolf.gd#L824-L826),
   `src/ai/utility_scorer.gd`).
   *Fica faltando:* é verdade por ausência de ligação, não por verifier. Quando o oráculo
   começar a sugerir algo, a sugestão entra como crença em quarentena (§04), nunca como
   intenção já escrita no corpo.
3. **Determinismo e medição primeiro.** Todo número citado vem de execução real, de preferência
   headless. *Estado honesto:* a geração é determinística (seed única
   [`SEED := 20261116`](tests/smoke_test.gd#L10), o mesmo mundo construído duas vezes devolve as
   mesmas 16 colunas de relevo) e a **simulação ao vivo não é** — `hp` final, Éter e pior passo
   mudaram nas corridas históricas da mesma árvore. O item 1 agora tem o primitivo
   `TickJournal`: SHA256 de uma **projeção mínima**, não hash completo nem replay
   ([tick_journal.gd:16-44](src/persistence/tick_journal.gd#L16-L44)). Inclui
   `FORMAT_VERSION = 1`, seed real (`world.gen.world_seed`), `GEN_VERSION`, tick, dimensões do
   mundo e do Éter (com tamanho de célula e canais), edições ordenadas XYZ com id de bloco,
   lobos vivos ordenados por `wolf.identity` com `mind.identity`, `mind.kind`, `intent` e
   crenças ordenadas por chave (`key/confidence/source`). O SHA256 recebe esses metadados
   via `var_to_bytes` seguidos de todos os bytes Float32 de `_cur`
   ([aether_field.gd:232-234](src/world/aether_field.gd#L232-L234)), sem o corte do save.
   **Não inclui** jogador, corpos, RNG, episódios, relações, timers ou comandos; não torna a
   simulação determinística. `main.state_hash()` expõe a consulta
   ([main.gd:1283-1284](src/main.gd#L1283-L1284)); o acesso ao estado autoritativo permanece aberto.
   O contrato foi exercitado em headless antes do refinamento dos rastros; resultados
   históricos locais e fontes medidas estão nas [notas do status](docs/melhorias-status.md#notas-de-medição).
   O candidato final com o lobo refinado também foi importado sem cache e validado;
   fontes e corridas estão nas [notas de rastros](docs/melhorias-status.md#rastros-e-reações--publicado-em-a8967e0).
   Essa árvore de alterações é o commit `a8967e0`, publicado e conferido por
   `git ls-remote --heads origin` em `42799fa`. O clone limpo dele foi reimportado sem cache e
   re-medido: 232 checagens / 0 falhas / 33,7 s, exit 0. Nenhum gate de fase se fecha com isso.
4. **Gates são sagrados.** Nenhuma fase termina por calendário; termina por comando headless +
   critério numérico + documento derivado do código. *Estado medido:* **nenhum gate fechado**, o
   slice jogável está **antes** de P1 ([docs/design/08](docs/design/08-roadmap-risks-licensing.md)).
   "Estamos em P0/P1" descreve o que existe, não uma fase encerrada. Gate travado = a próxima não
   começa; a exceção se registra **antes** de escrever o código, nunca na justificativa do commit.
5. **Observabilidade é requisito, não luxo.** *Seguro por:* o overlay de debug (F3 em
   [input_actions.gd:33](src/input/input_actions.gd#L33), corpo em
   [hud.gd:245-281](src/ui/hud.gd#L245-L281)) mostra tick, `worst_step_ms`, ticks perdidos,
   total por canal do Éter e uma linha por lobo com a narrativa do oráculo. *Falta para P1:*
   `MindsInspector` não existe. O custo de BT sai no F3 (`tree_stats()`,
   [wolf.gd:1356-1357](src/entities/wolf.gd#L1356-L1357)); agora há também colheita headless
   estreita de `sim_step` integral e `_guard.last_us`/`trips`, um lobo por cenário
   ([aether_reactions_test.gd:405-407](tests/aether_reactions_test.gd#L405-L407),
   [:1949-1950](tests/aether_reactions_test.gd#L1949-L1950)). O guard mede só BT, sem
   percepção/utilidade ([wolf.gd:448-450](src/entities/wolf.gd#L448-L450)); isso não mede
   o HOT agregado dos cinco lobos nem fecha P1.
6. **Mudanças pequenas e atômicas.** Um assunto por commit e suíte verde entre eles, com a
   medição de cada um no próprio commit. O corte da revisão do golpe é o exemplo: o conserto do passo
   de golpe e a publicação do número do clone limpo são dois commits porque cada um tem uma
   corrida que lhe responde.
7. **Comentário explica o porquê, em português.** Nunca narrar o óbvio do código. Modelos
   reais: [smoke_test.gd:407-417](tests/smoke_test.gd#L407-L417) (por que o teste dá o `dt` e os
   passos ele mesmo) e o `GEN_VERSION` [world_gen.gd:6](src/world/world_gen.gd#L6), que faz o
   save velho ser recusado com mensagem em vez de lido torto
   ([main.gd:1079-1080](src/main.gd#L1079-L1080)).
8. **Zero derivação GPL do Veloren.** Inspiração de idéias e sistemas é permitida; código e
   asset, não. *Verificado por ausência:* nenhum `.rs` e nenhum `.ron` no repositório;
   [docs/design/09](docs/design/09-veloren-mechanics-adaptation.md) separa o que veio de lá como
   idéia, o que existe em código e o que foi rejeitado. *O veto cobre áudio, e isso foi chegado
   em 2026-11-18:* o Veloren tem `assets/voxygen/audio/{sfx,ambience,soundtrack}` — **645 arquivos
   de áudio, 312,35 MB** na árvore recursiva da API de objetos do Git, mais os manifests `sfx.ron`,
   `ambience.ron`, `soundtrack.ron`. O repositório deles tem **um único `LICENSE` na raiz, GPL-3.0**
   (a FAQ do README: "we decided to license it under the GNU General Public License v3.0"), e nesses
   651 blobs de áudio não há nenhum arquivo de licença ou atribuição por pasta — os únicos 6 blobs
   não-áudio são os `.ron`. O `CONTRIBUTING.md` deles reforça: conteúdo de terceiro só entra se for
   distribuível **sob a licença deles**. Então nenhum `.ogg` do Veloren vem para cá, e "pegar o som
   do Veloren" continua sendo derivação GPL. O que se aproveita é a estrutura: categorias de sfx,
   passos por material, ambiência por bioma, trilha com transição. Som do jogo vem de domínio
   público (CC0) já dentro do repositório: 51 arquivos em `assets/audio/`, com origem e
   SHA-256 por arquivo em [docs/audio-provenance.md](docs/audio-provenance.md) e
   [docs/audio-sha256.txt](docs/audio-sha256.txt), e o ganho medido em `assets/audio/levels.json`.

## Disciplina de otimização e controle de crescimento

O terceiro mandato não pede otimização nova: pede que nenhuma mudança entre sem responder
o custo dela. Ele é aplicável porque o projeto **já** tem instrumento — e tem, com nomes:

**As duas cadências.** O jogador local roda por *frame de física*
([main.gd:282-288](src/main.gd#L282-L288) → `update_local`): lavra e colocação escrevem
voxels fora do tick ([player.gd:685](src/entities/player.gd#L685),
[:711](src/entities/player.gd#L711)) e seus sinais também imprimem no Éter
([main.gd:958-963](src/main.gd#L958-L963)). O lobo não é só 20 Hz:
`wolf._physics_process` locomove o corpo e reduz timers de cadáver, atordoamento e desvio
por frame ([wolf.gd:1203-1259](src/entities/wolf.gd#L1203-L1259)). Decisão de IA, difusão,
recolha de cadáveres e respawns são agendados pelo tick de 20 Hz, com cadências próprias
([main.gd:291-333](src/main.gd#L291-L333), [sim_clock.gd:5-7](src/core/sim_clock.gd#L5-L7)).
`begin_step`/`end_step` cronometra esse passo em microsegundos
([main.gd:285-287](src/main.gd#L285-L287), [sim_clock.gd:32-39](src/core/sim_clock.gd#L32-L39)),
incluindo o journal ativo. Regra de bolso: o que você coloca em `_sim_tick` divide 50 ms
com 5 lobos; o que coloca em `_physics_process` divide o frame com a renderização.

**Journal sob demanda, não gravação automática.** A CLI lê, após `--`,
`--tick-journal=path` ([main.gd:1287-1294](src/main.gd#L1287-L1294)). `start()` recusa caminho
existente: cada corrida exige arquivo novo explícito, sem reabrir histórico nem criar
arquivos automaticamente entre sessões ([tick_journal.gd:47-62](src/persistence/tick_journal.gd#L47-L62)).
`record()` acrescenta JSONL `[tick,hash]` com `flush` por linha; recusa tick negativo e,
após o primeiro registro, duplicata, regressão ou salto (exige `last_tick + 1`)
([tick_journal.gd:69-87](src/persistence/tick_journal.gd#L69-L87)). A chamada ocorre após
`clock.tick += 1`, **dentro** do cronômetro da simulação
([main.gd:327-333](src/main.gd#L327-L333)); sem o modo, o tick só consulta `active()`.
O load válido encerra o arquivo antes de restaurar o mundo
([main.gd:1082-1084](src/main.gd#L1082-L1084)); sair da cena também o fecha
([main.gd:1311](src/main.gd#L1311)). O arquivo cresce apenas enquanto a gravação
explícita estiver ativa; não é journal de comandos nem mecanismo de replay.

**Orçamentos que já são código**, não intenção (regra 7):

| Orçamento | Valor hoje | Onde |
| --- | --- | --- |
| Passo de simulação | 50 ms (20 Hz), teto de 5 passos por frame; o que estourar vira `dropped_ticks` à vista | [sim_clock.gd:5-7](src/core/sim_clock.gd#L5-L7), [:19-29](src/core/sim_clock.gd#L19-L29) |
| Árvore de decisão, por lobo | 400 µs no `SubtreeGuard` (a default da classe é 250 µs); só BT, não percepção/utilidade | [bt_tree.gd:117-137](src/ai/behavior/bt_tree.gd#L117-L137), [wolf.gd:448-449](src/entities/wolf.gd#L448-L449) |
| Malha | 2 chunks por frame — **contagem, não tempo**: medido 52–177 ms no pior quadro, contra um piso de instrumento de 6,0 ms; é o furo #41 | [main.gd:28](src/main.gd#L28), usado em [:332](src/main.gd#L337), [voxel_world.gd:203-212](src/world/voxel_world.gd#L203-L212) |
| Difusão do Éter | 4 passadas por segundo, não 20 | [main.gd:27](src/main.gd#L27), [:291](src/main.gd#L296) |
| Recolha de cadáver, visão do Éter | 1 s e 0,25 s | [main.gd:31](src/main.gd#L31), [:29](src/main.gd#L29) |

**O que doeu nas corridas históricas, antes do journal** (regra 2): o boot, não o tick.
Geração de 936 a 962 ms e
malharia de 4.640 a 4.886 ms com a janela congelada (`.tools/suite_fix1.log` …
`suite_fix4.log`; no clone limpo, 941 ms e 4.668 ms). O passo mais caro das cinco corridas
ficou entre 7,56 e 11,21 ms dos 50 ms disponíveis, com `dropped_ticks = 0` em todas. Quem
propuser otimizar o hot path de simulação começa a conversa por esse número — e a
conversa sobre boot já aconteceu uma vez com número na mesa: os ~16 s originais caíram para
~7,5 s quando o mesher passou a ler uma cópia linear do mundo em vez do dicionário de
chunks (README, seção "Limites conhecidos (medidos nesta máquina)").

**Alocação no caminho quente existe e não é medida** — é débito, não tarefa de otimização
ainda (regras 5 e 1, nesta ordem):

- o blackboard do BT é um `Dictionary` novo por lobo por tick
  ([wolf.gd:911](src/entities/wolf.gd#L911)): com a matilha inteira viva, 5 × 20 = 100
  dicionários por segundo (o `sim_step` retorna cedo em cadáver, então o número é teto
  derivado do código, não medição de alocação);
- a difusão aloca um `PackedInt32Array` por canal por passada
  ([aether_field.gd:122](src/world/aether_field.gd#L122)): 3 a cada 0,25 s;
- a conta das árvores (5 × 400 µs = 2 ms) cabe no teto de 2,5 ms que o gate de P1 ainda
  escreve como `[TARGET]` — e nenhum log mostra a soma real.

Essas alocações ainda não têm medição própria: os monitores do engine lidos são
`TIME_PROCESS` e `TIME_PHYSICS_PROCESS`, só no overlay F3
([hud.gd:248-251](src/ui/hud.gd#L248-L251)). Em headless, a suíte colhe o pior passo
(`worst_sim_ms`, vindo de `clock.worst_step_ms`) e `dropped_ticks` pelo `diagnostics()`
([main.gd:1205-1240](src/main.gd#L1205-L1240)). A colheita estreita de reações já separa
`sim_step` integral de BT, mas não mede alocações nem o HOT agregado dos cinco lobos.
Então o primeiro passo de qualquer otimização é a colheita, não o corte.

**Leitor de rastros: custo do scan medido por ablação; alocação continua sem medição.** Cada
scan percorre `7 × 7` células na camada Y do lobo: **49 × 3 leituras** `sample_cell`
(BLOOD/WORK/FEAR) por lobo, com seleção por `BLOOD + 0,35 × WORK`
([wolf.gd:960-1000](src/entities/wolf.gd#L960-L1000)). Se nenhuma célula da camada própria passa
de `SCENT_MIN`, o mesmo quadrado se repete na camada de cima e na de baixo — **98 leituras por
camada vizinha aberta** (dois canais, sem FEAR), 196 por scan quando as duas abrem. A cadência
é `0,25 s`, com rescan no tick seguinte à inspeção concluída
([:582-590](src/entities/wolf.gd#L582-L590),
[:927-928](src/entities/wolf.gd#L927-L928), [:960-961](src/entities/wolf.gd#L960-L961)); cinco lobos podem fazer o scan no mesmo tick.
O `sim_step` integral de 2 768 passos no cenário estreito mede **324 159 µs** com a camada
própria, **427 537 µs** com as três camadas incondicionais e **363 680 µs** com o gate pelo
nível próprio: o escalonamento corta 64 190 das 111 132 leituras extras (567 scans, 479
entradas de camada vizinha contra o máximo de 1 134). O chão do rastro não mede nada: trocar
`surface_height()` pela busca pelo sólido na mesma camada move o total em −1,8 % (324 159 →
318 171 µs) e nas três camadas em −1,5 % (434 052 → 427 537 µs), ambos dentro do ruído das
corridas repetidas do mesmo braço
([:1021-1029](src/entities/wolf.gd#L1021-L1029); [matriz de ablação, seis braços](docs/evidence/rastro-duas-camadas/readback.log)).
Os **2 768 passos** são os do cenário estreito na árvore daquela matriz, e só por isso os três números de
cima se comparam entre si: o lote da perna 12 pôs no mesmo instrumento duas checagens que avançam passos,
e na ponta dele o rodapé imprime **10 568** passos com `sim_step` total de **2 169 480 µs** — comparar o
rodapé de hoje com a matriz de 2026-11-22 seria comparar árvores diferentes.
Isso não conta todo o `sim_step`: há ainda três amostras locais por tick e LOS quando
pode importar ([:919-925](src/entities/wolf.gd#L919-L925)). Ao concluir os `2 s` de
inspeção, a vizinhança `3 × 3` acrescenta até duas leituras por célula válida para
registrar a força ponderada no cache, limitado a **32 células por lobo**, com expiração
em `30 s` e renovação por aumento de pelo menos `0,06` ponderado
([:27-34](src/entities/wolf.gd#L27-L34), [:635-649](src/entities/wolf.gd#L635-L649),
[:987-988](src/entities/wolf.gd#L987-L988)). `keys()` aloca um Array por scan para
recolher expirados e também nas evicções ao atingir o teto
([:962-964](src/entities/wolf.gd#L962-L964), [:647-648](src/entities/wolf.gd#L647-L648)).
O cache transitório pertence ao lobo e é limpo no load
([:1408](src/entities/wolf.gd#L1408)). Esses limites de cache e de alocação são
derivados do código: a ablação mede o scan, não a alocação total, e nada aqui fecha P1.

**Cópia de estado e custo observado:** com journal ativo, `state_bytes()` copia
32 × 16 × 32 × 3 × 4 = **196 608 bytes/tick** de Float32 (tamanho conferido pelo teste),
além dos arrays de edições, lobos vivos (hoje até 5 mentes) e crenças ordenados,
serialização, SHA256 e escrita com `flush`. Não é custo total de alocação medido.
O journal expõe `records`, `last_us`, `worst_us` e `total_us` (hash + escrita + flush
concluídos) em `diagnostics()["journal"]`
([tick_journal.gd:74-98](src/persistence/tick_journal.gd#L74-L98),
[main.gd:1233](src/main.gd#L1233)). No candidato histórico local recém-importado, anterior
ao refinamento dos rastros, 205 registros custaram 160 000 µs ao todo, com pico de
1 646 µs; o load encerrou a gravação. Os dois smokes, sem/com journal, terminaram sem
ticks perdidos, mas não são replay pareado, prova de otimização ou medição do lobo
refinado: [fontes e logs](docs/melhorias-status.md#notas-de-medição).

**LOD (regra 6) é parcial, e se diz assim:** existe *throttle temporal* por subsistema —
difusão e visualização do Éter 4×/s, cadáveres 1×/s; o leitor de rastros tem cadência de
`0,25 s` (com rescan após inspeção) e o registro de avistamentos, `2 s`
([wolf.gd:582-590](src/entities/wolf.gd#L582-L590), [:950-952](src/entities/wolf.gd#L950-L952)).
Isso não limita a LOS a 4×/s: ela é consultada a cada tick se o jogador está vivo e a
menos de 30 m. Não existe *LOD por distância*: os lobos vivos avaliam o BT a cada tick,
perto ou longe ([wolf.gd:906-911](src/entities/wolf.gd#L906-L911)). A peça do design é o
`HotSet`/Véu (§04, §06) e pertence a P2; antes de o custo aparecer em log, ela é backlog.

**Anti-bloat, com o estado real:**

- `main.gd` é o "objeto deus" conhecido — 1311 linhas nesta revisão (`wc -l`), 510 na `main` de `eb6ec8d`, donas de mundo, relógio, matilha, HUD,
  oráculo, visualização, instância do journal, o nó de áudio e o hospedeiro do modelo ([main.gd:43-62](src/main.gd#L43-L62)), com as tocas da perna 16 dentro do bloco da matilha (`var _dens` em [:116](src/main.gd#L116)). Isso está registrado como
  débito, não como licença: mudança que precisa de estado novo pergunta primeiro **quem é o
  dono** daquele estado.
- Generalize no segundo chamador, não no primeiro. O padrão da casa é dado no código até
  haver motivo para dado em arquivo: nomes e propriedades em
  [block_defs.gd:123-137](src/world/block_defs.gd#L123-L137), receitas em
  [recipes.gd:31-43](src/items/recipes.gd#L31-L43), ambos construídos uma vez.
- Caminho nunca exercitado se isola com nome, não se comenta: a sonda de oráculo vivo é
  cena própria ([tests/live_oracle_probe.tscn](tests/live_oracle_probe.tscn)) justamente para
  não virar fallback silencioso dentro de `MindOracle`.
- Complexidade se paga com teste: checagem nova que não pode falhar é remoção de código
  adiada. A suíte é o lugar de justificar a abstração.

**As quatro perguntas antes de escrever** (responda com número, não com adjetivo): roda por
frame, por tick ou às vezes? quantas entidades são alcançadas (hoje: 5 lobos, 64 chunks, 1
jogador)? aloco no caminho quente? como sei que ficou melhor — e o log existe em headless?
Se a resposta da última for "não existe", o trabalho do bloco é a colheita. Se uma mudança
puder degradar o budget de forma relevante, avise antes de implementar e proponha a versão
mais enxuta que mantém a correção e a mensurabilidade; pedido grande quebra em partes e diz
o que pode esperar.

## Escopo autorizado agora

Dentro, na ordem da fila do status: primitivo de hash por tick + journal apêndice-only; cenário
do lobo multi-semente em cima dele; canais morte/som/fogo no `AetherField` (são 3 hoje —
[aether_field.gd:9-15](src/world/aether_field.gd#L9-L15)); observabilidade de mente (inspector e
colheita headless do budget de BT); redução de acoplamento **quando** ela serve a uma dessas;
robustez do oráculo **nativo** — desde o Passo 4 do dossiê 22 o transporte HTTP saiu de `src/`
(`grep -rn HTTPRequest src` vazio) e [src/ai/mind_oracle.gd](src/ai/mind_oracle.gd) é wrapper da
ponte `AfMindOracle`, com [src/ai/af_mind_runtime.gd](src/ai/af_mind_runtime.gd) dono do ciclo do pack.

Fora, sem autorização explícita do dono do repositório: P2 (facções / `SlowSim`), co-op, progressão
e chefes, e qualquer "melhoria" de sistema que já passou no gate dele. Idéia boa de fase futura vira
linha de backlog no status, não código agora.

**Extensão de 2026-11-20, autorizada pelo dono na própria conversa.** Quatro linhas entram no
"dentro", na ordem dos dossiês ([`docs/planos/README.md`](docs/planos/README.md)): **bioma como
código + cor do pelo por bioma** (09), **rotinas de alcateia** — rondar, farejar, procurar, cercar
e atacar em grupo (10), **acasalamento com filhote que cresce e censo variável** (11), **bicho
cavando voxel** (12). O Éter continua o foco: a definição dele fecha pelo dossiê 03 (canais
morte/som/fogo) e pelo 05 (difusão fora do tick), e a parte nova dele é o background por bioma.
Duas recortes que a autorização **não** cobre, porque o código já os entrega e o gate deles já
existe: a lavra contínua do jogador (`player.gd:654-665`, segura `break_block`, o progresso soma
por frame e o bloco cai quando `hardness` estoura) e a coleta automática no inventário
(`:677-690`, o drop do registro entra direto) — ambas checadas em
[`tests/smoke_test.gd:2454-2462`](tests/smoke_test.gd#L2454-L2462) ("segurar break minerou", "tempo de
mineracao == dureza", "lavra entrou no inventario como drop"). Melhorar o que já passou no gate
continua vetado; o buraco real **à data daquela autorização** era nenhum bicho escrever no mundo — os
dois únicos `world.set_block` de gameplay eram os do jogador (`src/entities/player.gd:685`, `:711`); a 12 escreveu o terceiro.

A exceção de ordem registrada **antes** do código: as quatro linhas mexem todas em
`src/entities/wolf.gd` e em `src/main.gd`, que são de escritor único. Elas rodam **serializadas**
— uma branch fecha (merge + gate na `main` mergeda + publicação) antes da seguinte abrir — e a
ordem é 09 → 10 → 15 → 14 → 11 → 12 → 13 (a ordem completa, com o motivo de cada elo, está na
extensão abaixo), porque cor depende de bioma, cercar depende de quem mais existe na matilha,
convivência depende das folhas que a matilha reorganiza, acasalamento depende de dois adultos
próximos, cavar é folha da árvore já montada, e genealogia depende de existir nascimento.

**Extensão de 2026-11-20 (2), autorizada pelo dono na própria conversa — duas linhas novas, cada
uma com um agente responsável.** Elas entram no "dentro"; a posição de cada uma na fila serializada
é a que está no fim desta seção, e não é preferência.

1. **Convivência da alcateia** (dossiê
   [`docs/planos/14-convivio-da-alcateia.md`](docs/planos/14-convivio-da-alcateia.md), branch
   `feat/alcateia-convivio-14`, dono o agente `convivio-14`). O pedido do dono, em quatro regras:
   rondar pelos **blocos de terra**, com a **água como último recurso** para nadar; **regras para a
   matilha não parecer desorganizada**; **nenhum aviso na tela** sobre presença de criatura — "o
   player tem que achar, ver"; e **nunca spawnar na frente do jogador**, sempre a distância segura.
   O estado lido antes de prometer qualquer coisa — **leitura da revisão de abertura da
   perna (`f2823a8`)**: os números deste parágrafo são os daquela árvore, não os dos
   arquivos de hoje. `f2823a8:src/main.gd:242` ("uma nova matilha entrou no vale") e
   `f2823a8:src/main.gd:483` ("o lobo caiu o sangue fica no eter") eram os **únicos** avisos de
   criatura; os demais `hud.show_message` (`f2823a8:src/main.gd:135`, `:273`, `:450-451` recebendo
   `player.notice` de `f2823a8:src/entities/player.gd:309`, `:664`, `:682`, conectado em
   `f2823a8:src/main.gd:121` e em `f2823a8:src/main.gd:524`, `:526`, `:532`, `:536`, `:572`, mais
   `f2823a8:src/ui/hud.gd:603`/`:605`) eram
   feedback de ação do próprio jogador ou diagnóstico de save, e **ficam**. Na água, já havia
   teste de solo seco em `_leaf_wander`
   (`f2823a8:src/entities/wolf.gd:476-494`, via `_pick_wander` `:499-511` e `_dry_ground` `:541-545`) e resgate por tempo de nado
   (`SHORE_AFTER` `:79`, aplicado em `sim_step` `:608-614` com `_shore_point` `:490-500`); as outras
   **quatro** folhas escolhiam alvo sem nenhum teste de solo (`_leaf_flee` `:299`, `_leaf_chase`
   `:315`/`:319`, `_leaf_stalk` `:358`, `_leaf_investigate` `:376`). No spawn, `_random_ground_point`
   (`f2823a8:src/main.gd:300-314`) sorteava o anel de 16–46 m **em torno de `spawn_point()`** — que é o
   centro fixo do mundo (`:206-209`), não onde o jogador está — exigia coluna seca
   (`y > VoxelConfig.SEA_LEVEL`) e volume livre (`_volume_clear` `:322-324`), caía em silêncio no
   centro depois de 24 tentativas, e **nenhum caminho de spawn consultava a posição atual do jogador
   nem `world.line_of_sight`** (`f2823a8:src/world/voxel_world.gd:393`).
   O que a perna entregou, com os números de hoje: **nenhum letreiro de criatura** — as duas
   frases saíram, o contador de abate fica ([`src/main.gd:1014-1020`](src/main.gd#L1014-L1020)) e a
   vaga devolvida à fila de respawn não anuncia um ponto que pode ter sido recusado
   ([`src/main.gd:305-317`](src/main.gd#L305-L317)); **ronda por chão seco sem copiar o teste
   para dentro das folhas** — o alvo escrito pela árvore é filtrado depois do tick por
   `_resolve_dry_target()` ([`src/entities/wolf.gd:764-768`](src/entities/wolf.gd#L764-L768),
   chamado em [`:912`](src/entities/wolf.gd#L912), fora dos 400 µs do `SubtreeGuard`), e a água é
   último recurso com travessia comprometida por `SCENT_PERIOD` (`_demand_shore()`
   [`:743-754`](src/entities/wolf.gd#L743-L754)) mais o resgate por tempo de nado
   (`SHORE_AFTER` [`:149`](src/entities/wolf.gd#L149), aplicado em [`:901`](src/entities/wolf.gd#L901));
   **spawn a distância segura e fora da visada** — o predicado único `_spawn_point_ok()` exige
   ≥ `SAFE_SPAWN_DIST` (32 m) **e** que a linha do olho do jogador ao peito do lobo esteja bloqueada
   ([`src/main.gd:736-741`](src/main.gd#L736-L741)), dentro das bandas em torno da posição **atual**
   do jogador (`SPAWN_BANDS` [`:524`](src/main.gd#L524), busca em [`:762-826`](src/main.gd#L762-L826)),
   sem fallback mudo no centro e com a recusa impressa por motivo contado; colunas de lar distintas
   por lobo (`_home_columns()` [`:513-517`](src/main.gd#L513-L517)) e mordaca de 18 m sobre o lar de
   um irmao vivo (`PACK_LEASH` [`:533`](src/main.gd#L533), centro lido à época em `99d1167:src/main.gd:501-511`,
   hoje o centro da própria toca — `_entrada()` [`:715-719`](src/main.gd#L715-L719)),
   que é o conserto do furo #16 — sem ela a alcateia nunca se formou na sessao real da suíte.
   Sustenteam isso **33 checagens em oito cenários** nomeados no runner
   ([`tests/aether_reactions_test.gd:26-29`](tests/aether_reactions_test.gd#L26-L29); o censo
   [`:126`](tests/aether_reactions_test.gd#L126) que a 14 subiu de 150 para 183 é **355** hoje,
   depois da Fase 2 da 22) e a checagem da sessão real
   ([`tests/smoke_test.gd:315-320`](tests/smoke_test.gd#L315-L320)), agora com `biggest >= 2`.
2. **Árvore genealógica de todo ser vivo, com o Éter trabalhando isso** (dossiê
   [`docs/planos/13-arvore-genealogica-e-ether.md`](docs/planos/13-arvore-genealogica-e-ether.md),
   branch `feat/arvore-genealogica-13`, dono o agente `genealogia-13`). Recorte lido antes de
   prometer nível: `src/entities/` tem `player`, `player_avatar`, `fp_viewmodel`, `voxel_body` e
   `wolf` — **nenhum NPC** e **uma única espécie animal**. Então entra o primitivo (ascendência por
   entidade viva: identidade, pais, geração) e a **escada de complexidade** — animal simples ×
   humano/NPC mais complexo — fica documentada como `[TARGET]`, sem estrutura nova antes do segundo
   comprador (regra da casa: generalize no segundo chamador, não no primeiro). Hoje a personalidade
   é sorteada da semente do próprio lobo (`Mind._init` `src/ai/mind.gd:30-38`, chamado em
   `src/entities/wolf.gd:313` com `1000 + identity`) e **nenhum pai contribui com nada**; o pelo vem
   do bioma do lar (`FUR_COLORS` `src/entities/wolf.gd:160-165`, `home_biome` `:177`), não de
   herança. Guard-rail registrado **antes** do código: canal novo ou proveniência por célula no
   `AetherField` não é detalhe de implementação — `Channel.COUNT` (`src/world/aether_field.gd:9`) e
   `FORMAT_VERSION` (`src/persistence/tick_journal.gd:4`) entram no hash do journal
   (`src/persistence/tick_journal.gd:16-44`), então mexer aí muda os hashes registrados das rodadas
   publicadas e é decisão de versão explícita, escrita no status.

A ordem serializada **nova**, com o motivo de dependência de cada elo (registrada antes do código,
porque as duas linhas também escrevem em `src/entities/wolf.gd` e `src/main.gd`): **09 → 10 → 15 → 14 →
11 → 12 → 13**. 14 vem depois de 10 porque mexe nas mesmas folhas de movimento e nos mesmos
ajudantes de spawn que a alcateia acaba de reorganizar, e porque o predicado "ponto longe dos olhos
do jogador" tem de existir **antes** de 11 precisar dele para colocar o filhote no mundo; 11 vem
depois de 14 porque acasalar exige dois adultos próximos e agora exige também onde pôr o recém-nato;
12 fecha a sequência das quatro originais porque `dig` é folha da árvore já montada e o teto de
censo decide quantos lobos cavam; 13 é a última porque árvore genealógica só tem o que escrever
quando existe nascimento por causa interna (11), lê parentesco pela lista de vizinhos que a matilha
abriu (10), e — se o Éter ganhar canal ou proveniência nova — reimportar e re-mediar as cinco
pernas anteriores é mais barato do que deixar a mudança de `Channel.COUNT` no meio da fila.

**Extensão de 2026-11-20 (3), autorizada pelo dono na própria conversa — oráculo embutido no boot**
(dossiê [`docs/planos/15-oraculo-embutido-no-boot.md`](docs/planos/15-oraculo-embutido-no-boot.md),
branch `feat/oraculo-embutido-no-boot-15`, dono o agente `oraculo-15`). O pedido, nas palavras dele:
"ao startar o game, tem que carregar o modelo de i.a na maquina [...] sem eu ter que abrir depois...
tem que ser algo embutido", e "depois vemos como fica pra quem nao tem palca de video" — essa segunda
metade fica `[OPEN]`, não é tarefa desta perna. A fila passa a **09 → 10 → 15 → 14 → 11 → 12 → 13**,
com a 15 no meio porque não depende de nenhuma linha do código da matilha: é o caminho do `Rodar.bat`
e em `src/main.gd` só pendura um nó novo no boot, enquanto a 14 depende da ronda por setor que a perna
10 já escreveu e pousou. Registrada **antes** de qualquer código, como exige o mandato 4; nada deste
lote encosta em `src/entities/wolf.gd`, e o processo do oráculo continua fora do caminho de simulação.

**Extensão de 2026-11-21, autorizada pelo dono na própria conversa — dois prompts, dois dossiês e
uma vaga.** Ele mandou pôr em pauta o conteúdo de dois prompts seus ("Resolver Pontos Críticos do
Aetherfall — Física de Blocos + Mundo Reativo" e "Prompt Master — Física de Blocos + Mundo Vivo"),
itens A (queda de blocos), B (grama que cresce) e C (mato decorativo). Eles entram no "dentro" como
[`docs/planos/17-fisica-de-blocos-que-caem.md`](docs/planos/17-fisica-de-blocos-que-caem.md) e
[`docs/planos/18-mundo-vivo-grama-e-mato.md`](docs/planos/18-mundo-vivo-grama-e-mato.md), e o número
**16 fica reservado** ao pedido dele de espalhar a matilha em 2–3 tocas — sem página naquele dia, e
quem a escrevesse usaria o 16 e a posição que ele escolheu (logo depois da 11). Nada aqui é código: a
pauta registrada **antes** de qualquer linha escrita (mandato 4). **A reserva foi levantada em
2026-11-22** — ver o registro abaixo.

Três recortes que a autorização **não** cobre, lidos no código antes de dizer isso: o **rebase das
camadas verticais** (o prompt fala em `Y_MIN = -64`, `Y_BUILD_LIMIT = 320`, `SEA_LEVEL = 64`; o
registro tem `CHUNK_SIZE_Y = 64` e `SEA_LEVEL = 26`) porque quebra formato de save e ninguém o pediu;
**fluidos, luz/`TORCH`, biomas e cavernas novos**, que o doc 10 já mantém `[OPEN]`; e a **lavra
contínua do jogador**, que tem gate próprio verde. Consequência de versão declarada agora, não depois:
`Channel.COUNT` e `FORMAT_VERSION` não são tocados por nenhuma das duas pernas, e uma corrida com areia
caindo ou grama crescendo **não** reproduz os hashes das rodadas publicadas — não porque a projeção do
journal mudou, mas porque o mundo mudou. A fila serializada passa a **09 → 10 → 15 → 14 → 11 → 16 → 12
→ 17 → 18 → 13**: 16 logo depois de 11 porque é o censo variável da 11 que decide quantas tocas
alimentam; 12 continua depois de 16 porque `dig` é folha da árvore já montada; 17 depois de 12 porque
as duas escrevem pelo mesmo `set_block` e pelo mesmo `block_changed`, e anexar a fila de gravidade antes
obrigaria a 12 a re-rodar o gate dela; 18 depois de 17 porque o crescimento é o **segundo** comprador do
`BlockUpdateQueue` que a 17 escreve (generalizar no segundo chamador, não no primeiro); e 13 fecha por
ser a última justamente para nenhuma mudança de `Channel.COUNT` cair no meio da fila.

**Extensão de 2026-11-21 (2), autorizada pelo dono na própria conversa — o pedido urgente dele: lobos
presos diante de bloco e jogador parado na frente de um degrau.** Entra no "dentro" como
[`docs/planos/19-auto-pulo-de-bloco.md`](docs/planos/19-auto-pulo-de-bloco.md). É uma página diferente das
duas de cima por um motivo lido no código, não por gosto: **não é mecânica nova, é defeito do jogo em
execução**. O *step-up* do corpo (`step_up` em `src/entities/voxel_body.gd`) sobe 0,62 m e uma célula é 1 m;
o impulso de escape do lobo (`velocity.y = 5.2` em `src/entities/wolf.gd`, ápice 0,563 m com a gravidade de
24 m/s² do mesmo corpo) também não sobe; e `blocked_horizontal` tem **um** leitor em `src/` — o lobo, na
própria linha de locomovência. O corpo do jogador escreve a flag e ninguém a lê: por isso ele tem salto
manual suficiente e mesmo assim para na frente do degrau. Nada desta perna toca `Channel.COUNT`,
`FORMAT_VERSION` nem a projeção do `TickJournal`; o que muda é o mundo que entra nela, então uma corrida com
lobos subindo degrau **não** reproduz os hashes das rodadas publicadas — pelo mesmo motivo declarado agora
para a 17 e a 18, e não porque a projeção mudou.

A exceção de ordem, registrada **antes** do código (mandato 4) porque a perna encosta em
`src/entities/wolf.gd` e em `tests/aether_reactions_test.gd`, os dois arquivos que a 11 — ponta de código
`0762b43` — também escreve: a fila passa a **09 → 10 → 15 → 14 → 11 → 19 → 16 → 12 → 17 → 18 → 13**. A 19
entra logo depois de 11 porque um defeito em execução custa a cada sessão do dono, enquanto as pernas
restantes são mecânicas novas que ainda não existem. Consequência assumida e escrita no §7 do dossiê: quando
a 19 pousar na `main`, a 11 **re-rome o gate** — traz a `main` para dentro de si e roda a suíte de novo,
porque a árvore resultante é outra revisão (item 5 de "Branches"), e as linhas de `wolf.gd` e do runner que
a 11 cita passam a valer as depois do merge dela. **A consequência já foi cumprida:** a 19 pousou (merge
`--no-ff` `ab9ffa1`) e a 11 trouxe a `main` para dentro de si pelo merge `010ab25`, re-rodando o gate na
árvore resultante; a 11 pousou na `main` pelo merge `--no-ff` `4b858c2` e o fecho pelo `5b519f8`, o pin publicado.

**Registro de 2026-11-22 — a vaga 16 tem página. Nenhuma autorização nova: é o levantamento da reserva
que o dono fez em 2026-11-21.** Entra no "dentro" como
[`docs/planos/16-tocas-da-alcateia.md`](docs/planos/16-tocas-da-alcateia.md), branch
`feat/tocas-da-alcateia-16` (o índice trazia `feat/tocas-espalhadas-16` como nome provisório; a página
fixa o nome), e na fila serializada fica exatamente onde ele escolheu: **depois da 19 e antes da 12** — a
ordem **09 → 10 → 15 → 14 → 11 → 19 → 16 → 12 → 17 → 18 → 13** não muda. A premissa nomeada na página,
lida do código e não de corrida: os cinco lares do boot cabem num círculo de **18 m**, porque
`PACK_LEASH = 18.0` ([src/main.gd:533](src/main.gd#L533)) é a primeira tentativa
([:768](src/main.gd#L768)) e `_pack_leash()` devolvia o lar do **primeiro** lobo vivo
(`99d1167:src/main.gd:501-505`; a perna 16 apagou a função e hoje o centro lido é a própria
toca, `_entrada()` [`:715-719`](src/main.gd#L715-L719)), enquanto a caixa útil é 116 × 116 m — o clamp de `6 … W-6` em
[:787-788](src/main.gd#L787-L788) sobre um mundo de 128 × 128. É por isso que ele percorreu o vale
inteiro e viu um lobo só. A página decide o gate por **componentes conexos do grafo de coesão** lido em
`pack_of()`, não por adjetivo, e abre o par de braços (§3.4) antes do código: **A** (só colocação) é a
escolhida primeiro e só se aceita com a checagem de derivação verde; **B** (dar âncora ao centro de
ronda) custa re-derivar uma checagem gateada pela perna 10 e por isso só entra com o vermelho do A na
mesa. Duas consequências de documentação, registradas **antes** de qualquer linha: o **furo #18** (as
recusas de spawn nunca tiveram testemunha numérica — `motivos` só era interpolado na string impressa,
`99d1167:src/main.gd:545`) passa a ter dono fixo, a perna 16, e deixa de estar oferecido à 16
**ou** à 11; e esta leitura abre o **furo #21** — `pack_pairs` incrementa em
[:898](src/main.gd#L898) **antes** do teste de raio em [:899](src/main.gd#L899), então a asserção
`pack_pairs == n(n-1)/2` da suíte é verdade aritmética e só `biggest >= 2` decide coesão. Nada desta
página encosta em `Channel.COUNT`, `FORMAT_VERSION` nem `GEN_VERSION`, e nenhuma linha de código dela
foi escrita: a branch abre da `main` no ponto atual, com o gate nascendo vermelho.

**Registro de 2026-11-22 (2) — a pauta da 12 re-escrita contra a árvore de hoje. Nenhuma autorização
nova e nenhuma exceção de ordem: a fila continua 09 → 10 → 15 → 14 → 11 → 19 → 16 → 12 → 17 → 18 → 13.**
[`docs/planos/12-bicho-cavando-voxel.md`](docs/planos/12-bicho-cavando-voxel.md) tinha sido escrita em
2026-11-20 sobre uma árvore cinco pernas menor, e a regra da casa é que citação velha é hipótese: a
página foi re-linha a re-linha contra o código em que as pernas 09, 10, 14, 15, 11 e 19 já pousaram.
Quatro afirmações dela a leitura de hoje devolve diferente, e nenhuma é cosmética. (1) **Dureza é tempo,
não permissão**: o jogador soma `_mining_accum += delta` contra `target_hardness` sem teto de bloco
([src/entities/player.gd:663-664](src/entities/player.gd#L663-L664)) e escreve `AIR` em qualquer alvo
([:685](src/entities/player.gd#L685)), então `STONE 0,95` **cai** — o que limita a pata é lista de
material, não a régua. (2) **`block_changed` não tem um único consumidor** no repositório: existem só a
declaração ([src/world/voxel_world.gd:6](src/world/voxel_world.gd#L6)) e o emit
([:336](src/world/voxel_world.gd#L336)), então o gate desta perna observa estado de mundo lido
(`get_block` + [`world.edits`](src/world/voxel_world.gd#L54)) e quem assina o sinal continua sendo a 17 —
que é exatamente o motivo pelo qual a checagem `queda_move_a_celula` daquela página nasce vermelha.
(3) **O desemperto já tem dois ramos**, e o segundo é da 19 ([src/entities/wolf.gd:1239-1254](src/entities/wolf.gd#L1239-L1254)),
então cavar entra como **terceiro** ramo do mesmo `if` (fork A), e a alternativa de folha nova na
`Selector` (fork B) só se abre com o A vermelho porque `intent` é hashiado pelo journal. (4) **Quem cava
é decidido pelo alcance do corpo**, não por fase: `PHASE_SCALE` dá 0,45 ao filhote
([src/entities/wolf.gd:89](src/entities/wolf.gd#L89)) e o `reach` do degrau vem de `dims`
([src/entities/voxel_body.gd:163](src/entities/voxel_body.gd#L163)). Disso saem dois furos novos, ambos
com dono escrito antes de qualquer linha: **#22**, a lista de bancadas é alimentada só pelos sinais do
`Player`, então um bicho que removesse uma `BENCH` deixaria `bench_positions()` apontando para o ar até o
próximo load — fechado **por construção** pela cláusula `not world.edits.has(pos)` do §3.2, com a
checagem `cavar_nao_toca_construcao_alheia` pagando o número; e **#23**, a permeabilidade do Éter decide
o peso do vizinho por **um** voxel no canto da célula de 4×4×4
([src/world/aether_field.gd:174-176](src/world/aether_field.gd#L174-L176),
[src/world/voxel_config.gd:16](src/world/voxel_config.gd#L16)), então a frase antiga "difundem com menos
barreira" não é falsificável e o item (b) foi re-baseado no `y` que `_scent_ground_y` devolve
([src/entities/wolf.gd:1025-1029](src/entities/wolf.gd#L1025-L1029)) — dono perna 05. Uma consequência nova de
palco de teste, e é a que deixaria uma checagem verde pelo motivo errado: `_wall` e `_cave_carve` do
runner chamam `set_block` com `record` default, ou seja, parede de teste **é construção registrada**; o
scaffolding do cavar tem de escrever com `record = false`. Nada deste registro encosta em
`Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` nem na projeção do journal, nenhum número publicado foi
re-medido por ele, e nenhuma linha de código da perna 12 foi escrita **por esta leitura**:
`feat/bicho-cavando-12` não abria antes de a 16 pousar — pousou em `9b2c65a`, registro abaixo — e **abriu
depois, da `main` de `dcbcbe8`**; os itens (a)→(h) estão na Rodada Cavar 12 de
[`docs/melhorias-status.md`](docs/melhorias-status.md).

**Registro de 2026-11-23 — o código da perna 16 pousa na `main`, e a fila perde o elo da frente.** Nada
aqui é exceção de ordem nem gate de fase: a autorização usada é a nomeada desta rodada — `merge --no-ff`
na `main` e `push` do pouso, com gate de fase continuando do dono (mandato 4). A perna era a da vez, foi
aberta da `main` no ponto atual (`99d1167`) e pousou nele: `git merge --no-ff feat/tocas-da-alcateia-16`
→ **`9b2c65a30b74a6398fbf4f9c45560be38974fb12`**, pais `99d1167` e `edab9c8`, **41 arquivos, +5 026/−1 033**,
com o código em `src/main.gd` (+267/−29), `src/entities/wolf.gd` (+16/−1), `tests/aether_reactions_test.gd`
(+670/−1) e `tests/smoke_test.gd` (+109/−5). O número pineado é o do **clone limpo** de `9b2c65a` com
`--import` frio: **255 checagens / 0 falhas / 48,6 s**, exit 0, zero `[FAIL]` e zero `SCRIPT ERROR`, e o
runner de reações **240 / 0 / 24,138 s** com `OK censo de checagens | 240/240`; a árvore mergida re-rodada
deu **255 / 0 / 47,7 s** e **240 / 0 / 24,201 s**, e os três runners `--script` de `tests/` existem e
ficaram verdes — RNG **27 / 0 / 2,651 s** (`27/27`) e journal **128 / 0 / 5,610 s** (`7/7 testes
concluidos`). As árvores do pin são `64f137bcb1f8…` (`src`) e `88a1541c2f9f…` (`tests`), **diferentes** das
do `5b519f8` (`30873d66…` / `975eac5a…`): a perna escreve código, então o pin é o merge medido, não um
documento em cima dele. Os dois furos que a perna devia estão pagos com a checagem que paga cada um e a
linha literal arquivada — **#18** por `esgotamento_de_lares_forcado` (`soma(motivos)=576 == buscas(24) x
SPAWN_ATTEMPTS(24)`, `colunas_marcadas=13689`) e **#21** por `den_components()` lido em
`diagnostico_publica_a_mesma_leitura_das_tocas` e `nenhum_lobo_le_de_outra_toca`. As três réguas rodaram na
árvore mergida: `verify_plan_cites.py` **1 352** conferidas, **13** arquivos citados inexistentes, **0**
números fora do arquivo (a base `99d1167` dava **1 296** com as mesmas **13** — o merge acrescentou
ponteiro, não quebrou), `verify_plan_ids.py` com as **8** ausências da página 16 conferidas uma a uma como
peças que o próprio dossiê declara inexistentes, e `python tools/check_doc_anchors.py` **36 arquivos ·
2 370 ponteiros · 179 rótulos · 2 348 links** com o único caso tolerado (o ponteiro `../.tools/...`,
gitignored). A fila serializada passa a **12 → 17 → 18 → 20 → 13**: a 16 sai da frente, o elo seguinte é
`feat/bicho-cavando-12` — que **abriu depois, da `main` de `dcbcbe8`**, e pousou em `fa94cb5` no registro
abaixo — e depois dele 17, 18, 20 e 13. O motivo que esta frase dava para o vermelho estava errado, e a própria página 12 o
tinha corrigido dois registros antes: o gate do cavar observa `get_block` +
[`world.edits`](src/world/voxel_world.gd#L54), não o sinal, então a branch nasce vermelha porque nenhuma
linha do cavar existia ainda, não porque `block_changed` continua sem consumidor nenhum — esse continua
sendo débito da 17 assinar. **A fila P0/P1 continua aberta**: budget HOT sem medição, censo multi-semente
sem corrida e bake-off de AF sem número são exatamente os elos que a 16 não toca, e nada desta rodada
fecha gate. Ficam escritos como débito, não como feito, a atribuição do par de vazamento do quit e a
alocação de `_dens`/`den_components` sem colheita; `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a
projeção do journal não foram tocados por nenhuma das duas pernas.

**Registro de 2026-11-22 (3) — a pauta 20, aberta por autorização nova do dono. A autorização é para a
pauta, não para o código: nenhuma linha de `src/` foi escrita por esta leitura.** Ele mandou pôr em pauta
o prompt que ele mesmo chamou de "Prompt Master — Inteligência Autônoma de Mobs + Ecossistema Vivo", e
ele entra no "dentro" como
[`docs/planos/20-mente-autonoma-de-mobs-e-ecossistema.md`](docs/planos/20-mente-autonoma-de-mobs-e-ecossistema.md),
branch `feat/mobs-autonomos-e-ecossistema-20`, dono o agente `mente-eco-20`. É, de longe, o pedido mais
largo já registrado — sete entregas (avaliação de alcance, memória de falha, tabela de espécie, três
grupos de criaturas, drops, troféu colocável e os testes) sobre seis arquivos que a fila já escreve — e
é por isso que a página entrega o **corte**, não a lista: cada §3 nomeia a decisão, o braço rejeitado e
o número que reabre o braço. Os números de `arquivo:linha` foram **re-derivados contra a `main` de
`bb13752`**, o pouso da 16: a pauta foi escrita contra `99d1167`, cujo `src/` e `tests/` eram byte a byte
os do pin `5b519f8`, e isso **deixou de ser verdade** quando a 16 escreveu código — as árvores de
`9b2c65a` são `git rev-parse 9b2c65a:src` = `64f137bcb1f8e95bd9a64fe7843e4e7b72f7326e` e `:tests` =
`88a1541c2f9f6fc3dd0e1d237b3e5656d9eea3c9`, diferentes das do `5b519f8` (`30873d66…` / `975eac5a…`).
O contrato de referência desta pauta é portanto o do pin `9b2c65a`: **255 checagens / 0 falhas** na suíte
e **240 / 0** no runner de reações — não o **252 / 0 / 42,4 s** que a página carregava. Esta branch é
documento puro (`git diff --name-only bb13752..HEAD -- src tests` devolve vazio), então o número do pin
vale para a árvore resultante **por identidade de árvore**, não por medição nova, e não se pede re-corrida.

A posição na fila serializada é exceção de ordem registrada **antes** de qualquer linha (mandato 4): a
fila ficou **09 → 10 → 15 → 14 → 11 → 19 → 16 ✅ → 12 ✅ → 17 → 18 → 20 → 13**, e a 16 já cumpriu a sua
posição (`9b2c65a` código, `bb13752` registro) e a 12 o mesmo (ponta de código `d80ac20`, pouso `fa94cb5`),
então a **fila viva de hoje** é **17 → 18 → 20 → 13**. A 20 vem **depois** da 18
porque as duas escrevem [`src/world/block_defs.gd`](src/world/block_defs.gd): a 17 gasta o id 18 (`SLAB`),
a 18 gasta o 17 (`PLANT`), os ids 9–18 continuam reservados por documento
([src/world/block_defs.gd:10-24](src/world/block_defs.gd#L10-L24) com `COUNT = 23` em [`:37`](src/world/block_defs.gd#L37))
e drop de criatura **não pode** encostar nessa reserva — entra a partir de 23, na mesma tabela que as
duas anteriores acabam de renumberar. Vem **antes** da 13 porque árvore genealógica sobre **uma** única
espécie escreveria o que já existe; a 13 continua última pelo motivo já registrado — nenhuma mudança de
`Channel.COUNT` no meio da fila — e a 20 não toca canal nenhum: o canal de morte continua sendo débito
do dossiê 03. Consequência de versão declarada agora, não depois: nada deste registro encosta em
`Channel.COUNT` ([src/world/aether_field.gd:9](src/world/aether_field.gd#L9)), `FORMAT_VERSION`
([src/persistence/tick_journal.gd:4](src/persistence/tick_journal.gd#L4)) nem `GEN_VERSION`, e uma
corrida com espécies novas **não** reproduz os hashes publicados — porque `mind.kind`, `intent` e as
crenças ordenadas entram na projeção ([src/persistence/tick_journal.gd:35](src/persistence/tick_journal.gd#L35))
e o **estado** mudou, não a projeção.

Quatro afirmações do prompt a leitura devolve diferente, e duas metades dele a árvore já pagou. (1)
"Drops são fracos" não: **não existem**. O `die()` do lobo escreve BLOOD e FEAR
([src/entities/wolf.gd:1319-1320](src/entities/wolf.gd#L1319-L1320)), arma o timer de cadáver
([:1321](src/entities/wolf.gd#L1321)) e só então emite `died` ([:1322](src/entities/wolf.gd#L1322)).
(2) O sinal **não** é órfão — tem **dois** consumidores em `src/`, e nenhum deles é um item:
`_on_wolf_died` ([src/main.gd:415](src/main.gd#L415) conecta, corpo em [`:1020`](src/main.gd#L1020)) só
soma `stats["wolves_felled"]`, e o diretor de áudio toca `wolf_died`
([src/audio/audio_director.gd:161](src/audio/audio_director.gd#L161), corpo em [`:412`](src/audio/audio_director.gd#L412));
a conclusão do prompt fica de pé, o motivo dela não. (3) "Lobos presos diante de bloco" era a pauta da
**19**, que pousou: hoje o impulso sai em [src/entities/wolf.gd:1247](src/entities/wolf.gd#L1247). (4) O
leito `amb_birds` tocando sem nenhuma ave no mundo **não** é defeito do tipo da 19 — é cama de ambiência
de campo aberto, correta como ambiência; o que ela prova é que o mundo já promete céu vivo. O que a
re-derivação acrescentou e a pauta não citava quando foi escrita: **a 16 deu toca à matilha** — `var _dens`
([src/main.gd:116](src/main.gd#L116)), `den_components()` ([:646](src/main.gd#L646)) publicado no
`diagnostics()` ([:1217](src/main.gd#L1217)), `Wolf.den`
([src/entities/wolf.gd:186](src/entities/wolf.gd#L186)) com a chave `den` já no disco
([`:1372`](src/entities/wolf.gd#L1372), lida em [`:1405`](src/entities/wolf.gd#L1405)) — território que
mexe no §3.9 da página e em nenhuma das quatro afirmações acima.

Disso saem dois furos novos, ambos com dono escrito antes de qualquer linha. **#24**: o
[docs/design/04-local-ai-architecture.md:44](docs/design/04-local-ai-architecture.md#L44) declara
`[DECIDED]` que "nós são instanciados por espécie/archetype, não por entidade", com uma BT `.tres`
compartilhada por 1000 lobos e o estado no `Blackboard` — e na árvore não há **nenhum** `.tres` em `src/`
(o único do repositório é `default_bus_layout.tres` na raiz, layout de barramento de áudio), não existe
classe `Blackboard` — a palavra só aparece num comentário de `src/`,
[src/ai/behavior/bt_tree.gd:3](src/ai/behavior/bt_tree.gd#L3), que é justamente a promessa, não o
mecanismo; o estado chega como `Dictionary` literal inline no tick,
[src/entities/wolf.gd:911](src/entities/wolf.gd#L911) — e cada `Wolf` constrói a própria árvore: `setup()`
([:299](src/entities/wolf.gd#L299)) chama `_build_tree()` ([:318](src/entities/wolf.gd#L318)), corpo em
([:422](src/entities/wolf.gd#L422)) — e o comentário de [src/ai/behavior/bt_tree.gd:2](src/ai/behavior/bt_tree.gd#L2)
repete a promessa. Dono: perna 20 §3.5, com a checagem `arvore_por_arquetype` pagando o número. **#25**:
`tests/audio_test.gd.uid` e `tests/audio_live_probe.gd.uid` estão fora do git enquanto todos os outros
scripts estão (`src` 30/30, `tests` 7 de 9), então todo clone limpo mostra duas linhas `??` depois do
`--import`; nenhuma cena os referencia por `uid://` — [tests/audio_live_probe.tscn:3](tests/audio_live_probe.tscn#L3)
usa `path=` — então é sujeira de instrumento, não defeito de execução. Dono: arrumação do dono do repo;
esta branch **não** os comita. Nenhuma linha de código da perna 20 foi escrita:
`feat/mobs-autonomos-e-ecossistema-20` não abre antes de a 18 pousar.

**Registro de 2026-11-23 (2) — o código da perna 12 pousa na `main`, e a fila perde o elo da frente.** Nada
aqui é exceção de ordem nem gate de fase: a autorização usada é a nomeada das pernas anteriores — `merge
--no-ff` na `main` e `push`, com gate de fase continuando do dono (mandato 4). A perna era a da vez, foi
aberta da `main` no ponto atual (`dcbcbe8`) e pousou nele: `git merge --no-ff feat/bicho-cavando-12` →
**`fa94cb5`**, pais `dcbcbe8` e `d62c066`, **46 arquivos, +6 013/−793**, com o código em
`src/entities/wolf.gd` (+277/−8), `src/entities/voxel_body.gd` (+12/−4) e
`tests/aether_reactions_test.gd` (+1 119/−1). O número pineado é o do **clone limpo** de `fa94cb5` com
`--import` frio: suíte **255 checagens / 0 falhas / 61,7 s** e runner de reações **283 / 0 / 34,218 s**
(com `283/283`, `65/65` e `trips_solo=0 trips_matilha=0`); a árvore mergida re-rodada dá **255 / 0** duas
vezes, runner **283 / 0**, RNG **27 / 0** e journal **128 / 0**. As árvores do pin são `f77c1961…` (`src`)
e `4855f0e8…` (`tests`) — **diferentes** das do pouso da 16 (`64f137bc…` / `88a1541c…`), porque a 12 escreve
código, e o merge não acrescenta nada sobre a ponta medida: `git diff --name-only d62c066 fa94cb5` devolve
vazio. O que a perna entrega, lido no que corre: um voxel **gerado** some por ação do lobo sem input do
jogador, fica em `world.edits`, e a malharia disso está medida no runner antes de qualquer festa; as
**nove** checagens do cavar estão no runner (censo 240 → **283**); o **furo #22** (bancada apontando para o
ar) fica pago pela cláusula de proveniência `not world.edits.has(pos)`, com a checagem
`cavar_nao_toca_construcao_alheia` pagando o número. Duas coisas esta passada abre e não fecha. (1) O
**vermelho intermitente** do espalhamento voltou a não ter dono: a atribuição de carga que a rodada da
ponta escreveu dependia de um amostrador gitignored que filtrava `QuantumEngine` — o app de áudio da JBL —
em vez do processo Godot, e nenhuma porcentagem impressa sustenta a frase; isso é o **furo #31**, e a regra
de casa que ele violou é "filtrar por `ExecutablePath` dentro do projeto, não por nome de processo". O
critério da régua (25 ms) não se moveu e nada foi silenciado. (2) `block_changed` continua **sem consumidor
nenhum** em `src/` — a árvore do pouso tem exatamente a declaração e o emit — e quem assina o sinal é a 17.
A fila serializada passa a **17 → 18 → 20 → 13**: o elo seguinte é `feat/fisica-de-blocos-que-caem-17`, e o
gate dele nasce vermelho em `queda_move_a_celula` pelo motivo já registrado — nenhuma linha de queda existe
ainda. **A fila P0/P1 continua aberta**: budget HOT sem medição, alocação do caminho quente sem colheita e
censo multi-semente sem corrida seguem sendo exatamente os elos que a 12 não toca. `Channel.COUNT`,
`FORMAT_VERSION`, `GEN_VERSION` e a projeção do `TickJournal` não foram tocados por esta perna. A seção
`O pouso da 12` de [docs/melhorias-status.md](docs/melhorias-status.md) traz as dez corridas, o par de
testemunhas do vermelho e as três réguas com as linhas literais.

**Extensão de 2026-11-23, autorizada pelo dono na própria conversa — oráculo nativo em GDExtension.**
O pedido chega como um prompt de cinco fases ("Aetherfall: Elevação da IA Local para Outro Nível") e
entra no "dentro" como
[`docs/planos/22-oraculo-nativo-gdextension.md`](docs/planos/22-oraculo-nativo-gdextension.md), branch
`feat/oraculo-nativo-gdextension-22`, dono o agente `oraculo-nativo-22`. A regra de ouro dele, escrita
no topo da página como cláusula verificável: nenhuma camada de linguagem move pé, aplica dano ou
escreve diretamente no ledger — a mente propõe, as regras determinísticas dispõem. O escopo autorizado
é a **Fase 1** (o transporte do oráculo sai do HTTP e passa a ser uma extensão C++ com llama.cpp
embutido no processo, em `native/af_mind/`); as Fases 2–5 — memória de qualidade, adaptação por
bandit, LOD e orçamento, ferramentas e observabilidade — ficam autorizadas **como pauta dentro dessa
mesma perna**, cada uma com gate próprio e nenhuma linha escrita antes de a anterior fechar o dela.
O que o prompt nomeia e este registro **não** autoriza: P2, facções, co-op, progressão, chefes e o
"Sistema Operacional (Obragem)", que o próprio dono adiou. `Channel.COUNT`
([aether_field.gd:9](src/world/aether_field.gd#L9)), `FORMAT_VERSION`
([tick_journal.gd:4](src/persistence/tick_journal.gd#L4)) e `GEN_VERSION` continuam intocados.

A posição na fila serializada era exceção de ordem registrada **antes** de qualquer linha (mandato 4)
e **foi movida pelo dono em 2026-11-23**, com a palavra dele — "pode continuar", depois de eu explicar
que o esqueleto não vinha porque a perna não abria antes da 18. A fila passa a **22 → 17 → 18 → 20 → 13**.
A razão que punha a 22 atrás da 18 — obrigar a 18 a re-rodar o gate com um `HTTPRequest` a menos na
árvore — não sumiu; passa a **aceita**, e o preço é que 17 e 18 rebaseiam numa árvore onde o transporte
do oráculo já mudou (item 5 de "Branches": re-rome o gate). Antes da 20 porque as duas escrevem a mesma
frase de contrato sobre o oráculo; a 13 continua última: nenhuma mudança de `Channel.COUNT` na fila.

O que a Fase 0 desta perna mediu, e o que isso mudou no plano (§1 e §8 da página): o MSVC **existe** e a
leitura anterior — "nenhum VS instalado" — estava errada
porque o `.bat` da sonda fazia `call vcvars64.bat >nul` e media `%ERRORLEVEL%` **depois** do redirect;
o instrumento imprimiu o código da própria casca. Isso é o **furo #32**, e a régua dele é "um redirect
entre o `call` e o `echo %ERRORLEVEL%` lê o redirect, não o compilador". Medido também: as DLLs do
runtime carregam dentro de um processo comum e veem a GPU (`reg_count` 3 — RPC, Vulkan, CPU; `dev[0]`
Vulkan0 = RX 9060 XT), o cabeçalho de interface do GDExtension 4.7.2 é **gerado** pelo SCons do próprio
Godot (143 170 B, não baixável como arquivo) e o export-set pinado não contém
`ggml_backend_buffer_type_get_base_buffer` nem `llama_params_get_fit_params` — os dois nomes com que o
prompt descrevia a memória fina (`model_oversave`) e o ajuste automático de parâmetros. Consequência
escrita antes do código: nenhuma linha de `native/` compila contra documentação; o gate de **link** da
Fase 1 (§1.3, §5.1) é quem decide a escolha de símbolo.

O **Passo 1 (a)** da mesma perna (branch `feat/oraculo-nativo-gdextension-22`, §12 da página) reescreveu
três frases dessa medição com número na mesa, e nenhuma delas é cosmética. "VS 2022 Community,
`cl.exe` 19.44.35207" somava duas grandezas e escolhia uma entre três instalações: `14.44.35207` é o nome
da **pasta** do toolset, a versão do `cl` é `19.44.35228`, e a máquina tem **três** instalações com as três
consultas `-latest` do vswhere **divergindo** entre si — é o **furo #34**, e a regra do `build.bat` é nomear
caminho e toolset, não perguntar qual é o mais novo. Fora da casca do `vcvars64.bat` o `link` que resolve no
PATH é o `link.exe` do Git (GNU coreutils 8.32, que cria hard link de arquivo): **furo #35**. E a testemunha
de 4.7.2 que o §1.4 da página usava (`GDExtensionInitializationFunction`, `GDEXTENSION_VARIANT_TYPE_*`) existe
idêntica no cabeçalho do godot-cpp 4.4.1 — o que discrimina é `GDExtensionClassCreationInfo6`,
`GDExtensionClassCreateInstance3` e `GDExtensionInterfaceClassdbRegisterExtensionClass6`, e não há
`api_version` em lugar nenhum. O gerador do cabeçalho não tem CLI (`run(target, source, env)`, emissor do
SCons): a reprodução foi **executada** com um shim de 11 linhas e o `cmp` saiu com exit 0 contra o arquivo
arquivado, e o `_copyright` de 27 linhas do JSON **não** chega ao fruto — vendorizar o cabeçalho é
distribuí-lo sem licença dentro, então a atribuição passa a ser linha nossa em
`THIRD_PARTY_LICENSES.md`. Nada disto é código da Fase 1 — a branch desta passada é documento puro.

**Extensão de 2026-11-24, autorizada pelo dono na própria conversa — elevação visual, cinco fases, e a
regra dele: só visual.** O pedido chega como o prompt "Aetherfall: Elevação Visual (Texturas + Água +
Atmosfera)" e entra no "dentro" como
[`docs/planos/23-elevacao-visual-agua.md`](docs/planos/23-elevacao-visual-agua.md), branch
`feat/elevacao-visual-agua-23`, dono o agente `visual-agua-23`. A cláusula verificável dele, escrita no
topo da página como cláusula e não como intenção: **"Não tocar na IA ou na lógica de gameplay neste
prompt — só visual"**, e ela é a mesma forma da regra de ouro da perna 22 — nenhuma camada nova move pé,
aplica dano ou escreve no ledger. Aqui isso virou checagem com número (§5.1 `fx_nao_escreve_o_mundo`:
`world.edits` inalterado na janela com salpico, `Channel.COUNT` == 3), não declaração. O escopo
autorizado é a **Fase 1** (água: shader de superfície com ondulação procedural, refração e reflexão de
tela, cor por profundidade, Fresnel, caústicas; partículas de margem, salpico de entrada e bolhas); as
**Fases 2→5** — chuva e superfícies molhadas, vegetação viva com vento, atmosfera, materiais dos blocos —
ficam autorizadas **como pauta dentro dessa mesma perna**, cada uma com gate próprio e nenhuma linha
escrita antes de a anterior fechar o dela, exatamente como a 22 recebeu as cinco fases dela. O que o
prompt nomeia e este registro **não** autoriza: texturas 4K ou PBR completo, água hiper-complexa que
estoure o frame, mistura de estilo e abandonar a linguagem voxel — os quatro "não" do prompt, lidos como
§6 da página. `Channel.COUNT` ([aether_field.gd:9](src/world/aether_field.gd#L9)), `FORMAT_VERSION`
([tick_journal.gd:4](src/persistence/tick_journal.gd#L4)) e `GEN_VERSION` continuam intocados, e nenhuma
linha de `src/ai/`, `native/`, `src/entities/wolf.gd` ou `block_defs.gd` é escrita por esta perna.

A posição na fila serializada é exceção de ordem registrada **antes** de qualquer linha (mandato 4). A
fila viva era **22 → 17 → 18 → 20 → 13**; passa a **23 → 22 → 17 → 18 → 20 → 13**, com a **22 parada
onde está e em voo** — `feat/oraculo-nativo-passo2b-22` tem trabalho **não commitado** em
`native/af_mind/` nesta árvore, e é por isso que a 23 abre **em worktree separado**, da `main` no ponto
atual (`b0ed929`), sem tocar a árvore primária nem o trabalho da 22. O motivo de a 23 vir na frente da 17
não é preferência: o dono pediu esta perna agora e mandou aplicar. O preço é o mesmo que a 22 aceitou —
17 e 18 rebaseiam numa árvore onde o material da água e o `COLOR` dos vértices de água já mudaram, e cada
uma **re-rome o gate** na árvore resultante (item 5 de "Branches"). O choque lido antes de abrir:
`src/main.gd` é de escritor único e a 22 também o toca (o hospedeiro do modelo,
[main.gd:235-270](src/main.gd#L235-L270)); esta perna escreve **três linhas** nele — instantiate do nó de
FX e a linha de diagnóstico.

Quatro afirmações do prompt a leitura da base (`b0ed929`) devolveu diferente, e nenhuma é cosmética. É
a leitura daquele ponto, com o número daquele ponto — as três primeiras já não descrevem a árvore de
hoje, e onde cada uma caiu está no registro do pouso em [`docs/melhorias-status.md`](docs/melhorias-status.md).
(1) "A água é um bloco transparente simples" era **menos** do que a árvore fazia: `_mat_water` era um
`StandardMaterial3D` com `TRANSPARENCY_ALPHA`, sem tempo, sem normal e sem leitura de cena
(`b0ed929:src/world/voxel_world.gd:92-97`), e o único "movimento" do tile era a faixa fixa por linha
(`y % 4 == 0` clareia, `y % 4 == 2` escurece) com **alfa 0,72 escrito no pixel** do atlas
(`b0ed929:src/world/voxel_atlas.gd:162-171`). (2) Não havia **um shader nenhum** no repositório:
`grep -rn "ShaderMaterial\|Shader.new\|gdshader" src tests` devolvia **vazio** na base — e não havia
**uma partícula nenhuma**: o mesmo grep de `GPUParticles3D\|CPUParticles3D\|ParticleProcessMaterial`
devolvia **vazio**. A página 23 é a primeira vez que o projeto tem um e outra, e o gate nasceu vermelho
por isso, não por descrever peça inexistente. (3) "Refração" já tinha onde cair sem mexer no mesher: o
`COLOR` dos vértices do surface de água era **escrito e nunca lido** — a malharia o preenchia com o
`FACE_TINT` da face (`b0ed929:src/world/voxel_world.gd:528-530`, `:627-628`) e `_mat_water` não ligava
`vertex_color_use_as_albedo` (ligavam o opaco `b0ed929:...:88` e o vidro `:104`); isso era o **furo #43** —
a face lateral da água com o tint descartado — e a página escolheu esse canal como portador da máscara
(§3.3). Hoje o shader lê esse canal — [`water_surface.gd:190`](src/world/water_surface.gd#L190) e
[`:210-212`](src/world/water_surface.gd#L210-L212) — e o material que o carrega nasce em
[`voxel_world.gd:131`](src/world/voxel_world.gd#L131), com a asserção de que ele é lido na própria
suíte (§5.1). (4) "Caústicas quando o sol está alto" não tem variável: `_build_environment` escreve um sol
**parado** em `rotation_degrees (-42, 55, 0)` com elevação fixa de ~48° e uma `fog_density` de `0,006`
([main.gd:1245-1276](src/main.gd#L1245-L1276)); não existe clima no projeto, e isso é o que segura a
Fase 2 como pauta e não como código desta perna (§3.9). O que a perna fez com essa afirmação foi
**expor** o sol à água — `_sun_dir` lido do `basis` da luz ([main.gd:1256](src/main.gd#L1256), entregue em
[:141](src/main.gd#L141)) — sem tocar no `Environment`, que é da Fase 4.

Uma consequência de instrumento, escrita antes do código porque é ela que divide o gate: **headless não
exercita o `RenderingDevice`, então nenhuma corrida da suíte pode afirmar que o shader compila.** O
mandato 1 não permite publicar "shader ok" com o número de uma corrida que não compila nada, e por isso a
página separa as duas provas — **nove** checagens estruturais em `tests/smoke_test.gd` (§5.1) e uma **sonda
com janela** em `.tools/` (§5.2) que é a única que grepa `SHADER ERROR` do stdout e compara dois PNGs do
mesmo enquadramento em instantes diferentes de `TIME`. A sonda rodou, nos dois braços, e o que ela devolve
é o par que dá sentido ao número: `SHADER ERROR` **0** com a GPU real ligada, e `fracao_ge3` **0,8471** dos
9 216 pixels da caixa nesta árvore contra **0,0000** no controle em `b0ed929`, onde os dois PNGs têm o
mesmo SHA-256. `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a projeção do `TickJournal` não mudam com
esta perna; o que a cláusula `fx_nao_escreve_o_mundo` paga é o estado, porque a não-determinismo da
simulação ao vivo já está registrado no mandato 3.

**Registro de 2026-11-24 — o código da perna 23 pousa na `main`, e a fila perde o elo da frente.** Nada
aqui é exceção de ordem nem gate de fase: a autorização usada é a nomeada das pernas anteriores — `merge
--no-ff` na `main` e `push`, com gate de fase continuando do dono (mandato 4). A perna era a da vez, foi
aberta da `main` no ponto atual (`b0ed929`) e pousou sobre o que a `main` tinha entretanto — o pouso do
Passo 2 (b) da 22: `git merge --no-ff feat/elevacao-visual-agua-23` → **`05e8917`**, pais `c05f1df` e
`3c7aae9`, **57 arquivos, +4 422/−655**, com o código em dois arquivos novos
([`src/world/water_surface.gd`](src/world/water_surface.gd), 237 linhas, e
[`src/rendering/water_fx.gd`](src/rendering/water_fx.gd), 352), em `src/world/voxel_world.gd` (+71/−10),
`src/main.gd` (+22) e `tests/smoke_test.gd` (+372).

A cláusula do dono — **"só visual"** — foi conferida contra o diff, não contra a frase: os sete arquivos
que o merge escreve em `src` e `tests` são os cinco acima mais os dois `.uid`, e `git diff --name-only
c05f1df 05e8917 -- src/ai src/items native` devolve **vazio**. É a primeira vez que o repositório tem
**um** shader e **uma** partícula, e as duas coisas estavam medidas como ausentes antes de abrir branch
(§2 da página, os dois greps vazios em `b0ed929`). O que decide a cláusula em execução é
`fx_nao_escreve_o_mundo`, com a linha literal da corrida (`edits_globais=0->0  eter_seco=0.000000
eter_salpico=0.000000  canais=3`), e o que decide o furo **#43** — fechado por este pouso, com dono que
era esta perna — são `material_da_agua_e_shader` (`shader=true  surface=1  declarados=16  gravados=14
sem_fonte=0`) e `mascara_de_onda_do_bloco_isolado` (`verts=24  tri=12  mascarados=12  fora_do_plano=0`):
o `COLOR` que a malharia já escrevia passou a ser lido pelo vértice. `agua_nao_muda_a_malha` existe
justamente para o re-rome de 17 e 18 não achar o número de triângulos deslocado por causa alheia, e ela
devolve `base=214448  espelho=214448  sessao=214448`. As nove checagens, cada uma com a linha literal,
estão na seção `O pouso da perna 23 na main` de
[`docs/melhorias-status.md`](docs/melhorias-status.md).

O número pineado é o do **clone limpo** de `05e8917` com `--import` frio: suíte **264 checagens / 0
falhas / 53,6 s** (amostrado) e **53,8 s** (silencioso), runner de reações **289 / 6 / 34,988 s** com
`FALHA censo de checagens | 289/296`, RNG **27 / 0 / 2,675 s** e journal **128 / 0 / 5,983 s**. As
árvores do pin são `3c436fb6d6f3…` (`src`) e `8decf7d42e3c…` (`tests`), **iguais** às da ponta `3c7aae9`
— `git diff --name-only 3c7aae9 05e8917 -- src tests docs` devolve vazio, o merge não acrescenta nada
sobre o que foi medido. Os **seis** vermelhos do runner não são desta perna e têm controle, não adjetivo:
a corrida da base `c05f1df` num clone limpo devolve o **mesmo** rodapé com as **mesmas** cinco linhas
(`extensao_carrega_classe` ×4 e `extensao_pack_no_processo`), que são checagens da 22 falhando onde
`native/` não existe — é o **furo #38**, decisão do dono, e a suíte de lá dá **255 / 0**. A prova com
janela, que é a única que pode dizer que o shader compila, deu `SHADER ERROR` **0** dos dois lados e
`fracao_ge3` **0,8471** contra **0,0000**, com os dois PNGs da base no **mesmo** SHA-256.

Duas coisas este pouso abre e não fecha. (1) **A régua de 25 ms deu um vermelho** —
`pior passo=25,76 ms` uma vez em dez corridas da árvore mergida, com `264 checagens 1 falhas 57,8 s`. Nada
foi silenciado e nenhum teto se moveu; **a atribuição continua aberta, escrita assim**, porque nenhuma
porcentagem medida nesta passada cai sobre a janela daquela corrida — ela não foi amostrada. O
instrumento que o **furo #31** cobrava foi escrito agora, obedece a regra dele (filtrar por
`ExecutablePath` dentro do projeto) e achou um furo próprio no caminho: **#44**, a chave da tabela de
desempenho é `IDProcess`, não `ProcessId`, e o join comparava `$null` — 143 linhas de `cpu=-1` que
pareciam testemunha e eram constante. Fica como débito com dono: a próxima perna que rodar a suíte nesta
árvore roda com o amostrador ligado e arquiva o par. (2) As **Fases 2→5** do prompt continuam autorizadas
como pauta, com **nenhuma** linha escrita, e o §3.9 da página diz o que cada uma exige que hoje não existe
(`Weather` como dono de estado, `Environment` versionado, o canal livre no `COLOR` opaco, normal/roughness
por bloco). Nada encosta em `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` nem na projeção do
`TickJournal`, e `block_changed` segue sem consumidor em `src/` — débito da 17.

As três réguas rodaram na árvore dos documentos deste pouso e o ponto fixo é log arquivado:
`python tools/check_doc_anchors.py` dá **40 arquivos · 3 163 ponteiros · 209 rótulos · 3 534 links** com
**5** casos objetivos — os mesmos cinco `../.tools/...` gitignored da base, que dava **39 · 3 079 · 209 ·
3 417** com os mesmos **5**. Antes do conserto eram **22**, e os 17 novos são a **nova face do furo #28**
contada por régua: um rótulo cujo corpo se moveu 16 linhas para frente e um número de linha que hoje é
branco são invisíveis para a varredura numérica da casa, que mexe em ponteiro e não em frase.
`verify_plan_cites.py` no corpus de **51** arquivos dá **3 012 / 76 / 0** contra **2 930 / 75 / 0** da
base, e o septuagésimo sexto é a própria frase que lista as ausências contando a si mesma.
`verify_plan_ids.py` na página 23 dá **97** identificadores com **10** ausentes, conferidos um a um e
todos da classe "peça que a página declara comprar". A fila serializada passa a **22 → 17 → 18 → 20 →
13**: a 23 sai da frente, o elo seguinte é `feat/oraculo-nativo-gdextension-22`, que continua em voo na
árvore primária com trabalho não commitado em `native/af_mind/`.

**Registro de 2026-11-25 — a Fase 2 do dossiê 23 abre como código. Nenhuma autorização nova e nenhuma
posição de fila muda.** A autorização usada é a do registro de 2026-11-24, que pôs as Fases 2→5 "como
pauta dentro dessa mesma perna, cada uma com gate próprio e nenhuma linha escrita antes de a anterior
fechar o dela": a Fase 1 fechou o gate dela e pousou (`05e8917`), então a Fase 2 é a da vez. O corte está
escrito em [`docs/planos/23-elevacao-visual-agua.md`](docs/planos/23-elevacao-visual-agua.md) §3.10, o
gate em §5.3 e a sonda em §5.4, e este registro é **anterior** a qualquer linha de `src/` (mandato 4).
A fila serializada continua **22 → 17 → 18 → 20 → 13** — Fase dentro de perna não é elo novo.

Quatro coisas a leitura da árvore de abertura (`eb218fe`) devolve diferente do que a pauta dizia, e
nenhuma é cosmética. (1) A pauta (§3.9) afirmava que a Fase 2 "reabre a discussão do §3.1"; a cláusula do
§3.1 é *"quando existir mais de **um** `.gdshader` no projeto"*, e o segundo material desta fase, como o
primeiro, nasce de uma constante `.gd`. Arquivos `.gdshader`: **0 antes, 0 depois** — a discussão não
reabre, e a página corrige a si mesma com o número impresso (§5.3, primeira linha). (2) O que a Fase 2 reabre
é outra cláusula, a do §3.3 braço (a): na árvore de abertura o `COLOR` do grupo opaco escreve
`Color(bright, bright, bright, 1.0)` (`eb218fe:src/world/voxel_world.gd:689`) e o consumidor é um
`StandardMaterial3D` com `vertex_color_use_as_albedo` (`eb218fe:src/world/voxel_world.gd:93`), que
multiplica **RGB** e não tem transparência ligada — o alfa é canal escrito como constante e lido por
ninguém, do mesmo achado do furo #43, mas desta vez **usado** como portador da exposição de céu. Com o A
gasto, o vento da Fase 3 perde o canal livre que a pauta lhe oferecia e passa a ter comprador real para o
atributo custom (`ARRAY_DATA`) do §3.3. (3) O pool de anéis do §3.6 ganha o **segundo comprador** que o braço rejeitado do §3.7
registrava como inexistente: a porta é `WaterFx.ring_at()`, com origem e recusa
contadas, e não um segundo pool. (4) O choque em `src/main.gd` deixou de ser previsto e passou a ser
lido: a 22 escreveu **14 linhas** ali desde a base desta fase (`git diff --stat eb218fe..1b5ff5f --
src/main.gd` = 14 inserções, `git worktree list` dando a árvore primária em `feat/oraculo-nativo-passo5-22`),
e os dois lugares que ela tocou são os dois que esta fase usa — uma linha no bloco de nós de render em
`_ready` (~:213) e o fim de `_start_journal_from_args()` (:1270), onde o `--weather=` entra. Worktree
separado (`.qoder/worktrees/elevacao-chuva-23f2`), escritor único por arquivo por branch, e **re-rome do
gate na árvore resultante** (item 5 de "Branches") continuam sendo o preço aceito, não uma preferência.

Disso sai um furo novo, com dono escrito antes da linha: **#47** — a sonda com janela da Fase 2 produz
recortes PNG dentro do projeto, e foi exatamente assim que o **#45** nasceu (os quatro
`caixa-*.png` de `docs/evidence/elevacao-visual-agua-23` commitados sem `.png.import`, todo clone limpo
imprimindo `??` depois do `--import`). Esta fase **não repete o passo**: a pasta nova de evidência leva
um `.gdignore`, que demonstra o conserto local em uma pasta e **não** fecha o #45. A régua foi relida
nesta árvore e o escopo do #45 é **menor** do que a pauta do pouso da 22 fazia crer: dos **29** PNGs e
**1** SVG rastreados, **quatro** arquivos estão sem sidecar e os quatro estão em
`docs/evidence/elevacao-visual-agua-23`; `docs/evidence/fp-hand` tem **14** `.import` versionados,
`docs/media` **11**, `assets/` **51** e o `icon.svg` da raiz tem o dele — ou seja, o débito é de quatro
arquivos, não de três pastas, e a arrumação neles continua sendo do dono do repositório.
Consequência de versão declarada agora, não depois: `Channel.COUNT`,
`FORMAT_VERSION`, `GEN_VERSION` e a projeção do `TickJournal` não são tocados, e a expectativa explícita
desta fase é que uma corrida com chuva **reproduza** os hashes publicados — chuva visual não move
`intent`, crenças, edições nem canais; se o hash se mover, o defeito é desta perna e a testemunha é a
assinatura por coluna da checagem `chuva_nao_escreve_o_mundo`. Nenhum gate de fase se fecha aqui, e a
fila P0/P1 (budget HOT, censo multi-semente, bake-off de AF) continua aberta.

**Emenda do mesmo dia, escrita com a corrida na mesa (dossiê 23 §5.4 e a rodada "Rodada 2026-11-25 (2)"
de [`docs/melhorias-status.md`](docs/melhorias-status.md)).** A frase acima sobre reproduzir hashes estava
mais forte que o instrumento e é corrigida aqui, não no commit histórico: o mandato 3 desta casa já mediu
que **a simulação ao vivo não é determinística** — dois runs da mesma árvore, sem chuva nenhuma, dão `hp`,
Éter e pior passo diferentes — então não existe par que valide "hash igual com e sem chuva", e nenhum foi
corrido. O que existe, e foi medido, é o antecedente estrutural: os três nós novos não seguram referência
a `AetherField`, `VoxelWorld` ou `Player` (`fx_sem_eter=true rain_sem_eter=true weather_sem_eter=true`,
`world_refs=0 eter_refs=0 player_refs=0`), `Channel.COUNT` continua **3** e nenhuma linha de
`src/persistence/` foi tocada (`git diff --name-only eb218fe..78742d6 -- src/ai src/items native
src/entities/wolf.gd src/world/block_defs.gd src/persistence` devolve vazio). A corrida pareada com
`--tick-journal=` nos dois braços fica registrada como **débito**, não como feito. Duas coisas mais saem
da rodada: o **#46** desta perna virou **#50** e o **#47** escrito no `_steps` virou **#49** — colisão de
índice, o primeiro com o `load_pack` síncrono da 22 já publicado na `main`, o segundo com o próprio #47 do
parágrafo acima — e a banda de indiferença do material opaco **não** coube na banda pequena: 0,9803 contra
um chão de instrumento de 0,0000, com causa nomeada em dois instrumentos (a segunda decodificação sRGB que
o `StandardMaterial3D` fazia) e o **furo #48** aberto para o `_mat_glass`, que ficou na outra matemática.

Uma terceira coisa sai da mesma rodada e é regra de conduta, não número: **as réguas de timing desta
máquina não são comparáveis entre janelas**. A régua de 25 ms do `espalhamento_nao_estoura_o_passo` deu
12,94–15,48 ms nas sete corridas da manhã e **31,33–32,41 ms** cinco horas depois na mesma árvore — e a
base `eb218fe`, sem nenhuma linha desta fase, deu **30,80–31,26 ms** na mesma janela, com o rodapé da
corrida quase parado (+1,4% a +4,1%) e o pico do passo em ×2,1. O amostrador do **#31**, ligado agora
como o débito do pouso da Fase 1 mandava, mostra um só PID do projeto na janela vermelha e
`CrossDeviceService` a 215–291% de um núcleo. Consequência operacional: **quem publicar um número de
`worst_sim_ms` publica a janela com ele**, e um gate de timing se corre com o amostrador ligado — o
vermelho de hoje não é defeito de nenhuma das duas árvores, e o **#31** continua aberto exatamente
porque falta o par vermelha↔verde da *mesma* árvore com o CPU do Godot nos dois lados.

## Ciclo de trabalho

1. **Leia o código real do assunto antes de propor a mudança.** As citações `arquivo:linha` do
   status são o atalho; se a linha mudou, releia — não confie no número, confie no conteúdo.
2. **Prefira a solução mais simples que preserve as propriedades do sistema** (emergência,
   memória, feedback). Entre elegância e uma propriedade do mundo que lembra, a propriedade
   ganha.
3. **Reproduza antes de corrigir.** Vermelho intermitente com código idêntico é defeito de
   premissa, não do ambiente. A atribuição só fecha nos dois sentidos: um braço que produz a
   assinatura exata da falha a partir de um estado que se mede como frequente, e outro mostrando
   que o conserto é indiferente a esse mesmo estado.
4. **Toda checagem nova nomeia a premissa que exige** e imprime o número que a decide —
   `mira travada no lobo do passo` existe porque o passo anterior podia passar por sorte.
5. **Rode a suíte** (comandos abaixo) e trate a última linha como contrato: contagem de
   checagens, falhas e tempo.
6. **Número publicado = número medido nesta revisão.** Antes de dizer que uma contagem vale,
   re-meça num clone limpo do commit (o `--import` é obrigatório no clone ainda não importado) e
   pine o SHA no texto. Mudou o código depois da medição, o número volta a ser hipótese.
7. **Fim de bloco: atualize `docs/melhorias-status.md`** — feito / em andamento / falta /
   débitos / furos descobertos / notas de medição — e re-derive as citações que o bloco tornou
   velhas. A lista de documentos a re-derivar sai de `git grep -l "<arquivo-tocado>" docs AGENTS.md`,
   **não** da memória: `tools/check_doc_anchors.py` e `verify_plan_cites.py` não vêem um ponteiro de
   prosa cujo número-alvo continua dentro do arquivo e continua não-branco, então `casos objetivos: 0`
   e `fora do arquivo: 0` não significam "nenhum ponteiro velho" (furo #28, medido na 07c: 33 números
   envelheceram em três páginas que a varredura não abriu, e as duas réguas ficaram verdes). Documento
   que descreve peça inexistente se marca como alvo, não se escreve no indicativo.
8. **Commit atômico.** Push só quando o dono pedir, e publicação se confirma com
   `git ls-remote --heads origin`: este repositório já teve um `origin` apontando para ele mesmo,
   de onde o `push` saía com código 0 sem publicar nada.

## Comandos de medição

```sh
# clone recém-clonado: importa antes de qualquer outra coisa
godot --headless --path . --import
# a suíte; sai com código 1 se qualquer checagem falhar; a última linha é "N checagens M falhas T s"
godot --headless --path . tests/smoke_test.tscn
# gate curto de compilação enquanto se edita (nunca substitui a suíte)
godot --headless --path . --check-only --script src/entities/wolf.gd
# capturas da galeria, em janela 1920x1080
godot --path . .tools/shot_gallery.tscn
```

Medição de tempo é serial: lote com gate de timing não roda em paralelo com outra carga na
máquina, porque o número que sai é do concorrente. Sonda curta de compilação é sempre permitida;
corrida de 36 s espera a máquina livre.

## Branches: um ajuste por linha de história

Trabalho entra por branch e chega à `main` por merge. O motivo não é cerimônia: com um assunto por
branch, `git log --first-parent main` responde *o que foi feito* sem abrir diff, e um ajuste
posterior tem onde procurar a decisão original — que é exatamente o que se perde quando tudo é
commitado direto na `main`.

1. **Nome carrega tipo e assunto.** `feat/` mecânica nova, `fix/` defeito, `perf/` custo, `test/`
   instrumento, `refator/` dono de estado, `bench/` medição, `docs/` documento. Quando o trabalho
   vem de um item da fila, o número do dossiê fecha o nome (`perf/difusao-fora-do-tick-05`); a
   tabela de nomes por dossiê está em [`docs/planos/README.md`](docs/planos/README.md).
2. **Base é sempre a `main` no ponto atual.** `git checkout main`, `git fetch origin`,
   `git merge --ff-only origin/main`, e só então `git checkout -b <branch>`. Branch criada de outra
   branch de trabalho deixa de responder "a partir de quê" — o registro que se quer era justamente esse.
3. **Dentro da branch vale o ciclo inteiro.** Um assunto por commit, suíte verde entre eles, e o
   número de cada medição no commit a que ele responde. Branch não é rascunho: merge vermelho põe
   número errado na `main`.
4. **`--no-ff` é obrigatório no merge.** Fast-forward achata a branch dentro da `main` e apaga a
   forma do histórico; com merge commit nomeado, a primeira fila do log vira o índice das mecânicas.
5. **A `main` andou? Re-rome o gate.** Traga a branch até ela (`git rebase main` ou merge da `main`
   na branch) e rode a suíte de novo: a árvore resultante é outra revisão, e número publicado é
   número medido nesta revisão (mandato 3, item 6 do ciclo).
6. **Um escritor por arquivo por branch.** Duas branches que tocam a mesma página precisam de ordem
   decidida *antes* de abrir a segunda. O incidente dos dois agentes no dossiê 03 apagou uma versão
   já conferida — é o custo real de não ordenar.
7. **Branch não fecha gate de fase** (mandato 4), não autoriza escopo novo ("Escopo autorizado
   agora") e não dispensa a re-medição no clone limpo antes de publicar.
8. **A branch remota fica** enquanto for o registro do ajuste; apagar no GitHub é descartar a pista
   que motivou esta seção. A local sai no merge verde com `-d` — nunca `-D` sem motivo aberto.

**Sequência de um ciclo** (nada aqui substitui a suíte):

```sh
git checkout main && git fetch origin && git merge --ff-only origin/main
git checkout -b feat/exemplo-03
# ... commits atômicos, um assunto cada ...
git diff --stat main...HEAD                        # o que a branch realmente toca
godot --headless --path . tests/smoke_test.tscn    # na branch: ultima linha e o contrato
git push -u origin feat/exemplo-03
git checkout main
git merge --no-ff feat/exemplo-03 -m "Merge feat/exemplo-03: <assunto> (dossie 03)"
godot --headless --path . tests/smoke_test.tscn    # a main mergeda e outra revisao
git push origin main
git ls-remote --heads origin                       # unico prova de que publicou
git branch -d feat/exemplo-03
```

## O que não fazer (com o motivo já medido aqui)

- Não "melhorar" por gosto um sistema que já passou no próprio gate — o custo sai do gate aberto.
- Não adicionar complexidade sem necessidade clara para o gate atual.
- Não inventar dado, comportamento ou resultado de teste, nem em exemplo de documentação.
- Não silenciar `SCRIPT ERROR`/warning para o teste ficar verde: o erro que derruba um passo
  também derruba as checagens dele, e a suíte passa a contar menos com o mesmo "0 falhas".
- Não montar premissa de teste escrevendo campo na mão quando o jogo tem a transição que faz
  aquilo (`respawn_at`, `close_panel`): o campo escrito à mão cria estado que nenhum passo
  seguinte espera.
- Não expandir escopo sem pedido, e não começar fase futura "porque o esqueleto é barato".
