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
   age é o dicionário `_narrations` ([mind_oracle.gd:47](src/ai/mind_oracle.gd#L47), gravado em
   [:176](src/ai/mind_oracle.gd#L176)), lido por `narration_of()`
   ([:96-97](src/ai/mind_oracle.gd#L96-L97)) e entregue só ao HUD
   ([main.gd:170](src/main.gd#L170) → [hud.gd:276-277](src/ui/hud.gd#L276-L277)). O hospedeiro do
   modelo lê dois campos do oráculo — `last_reason` e `server_url`
   ([llm_server_host.gd:152-153](src/ai/llm_server_host.gd#L152-L153),
   [:189](src/ai/llm_server_host.gd#L189)) — só para montar a linha de status do F3: leitura,
   nenhuma escrita. Não existe caminho do oráculo para `Mind`, `Wolf` ou `VoxelWorld`; a decisão
   vem de BT + utilidade
   ([wolf.gd:354-382](src/entities/wolf.gd#L354-L382), [:746-748](src/entities/wolf.gd#L746-L748),
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
   ([main.gd:989-990](src/main.gd#L989-L990)); o acesso ao estado autoritativo permanece aberto.
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
   [wolf.gd:1086-1087](src/entities/wolf.gd#L1086-L1087)); agora há também colheita headless
   estreita de `sim_step` integral e `_guard.last_us`/`trips`, um lobo por cenário
   ([aether_reactions_test.gd:272-284](tests/aether_reactions_test.gd#L272-L284),
   [:3029-3032](tests/aether_reactions_test.gd#L3029-L3032)). O guard mede só BT, sem
   percepção/utilidade ([wolf.gd:380-382](src/entities/wolf.gd#L380-L382)); isso não mede
   o HOT agregado dos cinco lobos nem fecha P1.
6. **Mudanças pequenas e atômicas.** Um assunto por commit e suíte verde entre eles, com a
   medição de cada um no próprio commit. O corte da revisão do golpe é o exemplo: o conserto do passo
   de golpe e a publicação do número do clone limpo são dois commits porque cada um tem uma
   corrida que lhe responde.
7. **Comentário explica o porquê, em português.** Nunca narrar o óbvio do código. Modelos
   reais: [smoke_test.gd:279-289](tests/smoke_test.gd#L279-L289) (por que o teste dá o `dt` e os
   passos ele mesmo) e o `GEN_VERSION` [world_gen.gd:6](src/world/world_gen.gd#L6), que faz o
   save velho ser recusado com mensagem em vez de lido torto
   ([main.gd:811-812](src/main.gd#L811-L812)).
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
([main.gd:242-248](src/main.gd#L242-L248) → `update_local`): lavra e colocação escrevem
voxels fora do tick ([player.gd:685](src/entities/player.gd#L685),
[:711](src/entities/player.gd#L711)) e seus sinais também imprimem no Éter
([main.gd:698-703](src/main.gd#L698-L703)). O lobo não é só 20 Hz:
`wolf._physics_process` locomove o corpo e reduz timers de cadáver, atordoamento e desvio
por frame ([wolf.gd:941-989](src/entities/wolf.gd#L941-L989)). Decisão de IA, difusão,
recolha de cadáveres e respawns são agendados pelo tick de 20 Hz, com cadências próprias
([main.gd:251-281](src/main.gd#L251-L281), [sim_clock.gd:5-7](src/core/sim_clock.gd#L5-L7)).
`begin_step`/`end_step` cronometra esse passo em microsegundos
([main.gd:246-248](src/main.gd#L246-L248), [sim_clock.gd:32-39](src/core/sim_clock.gd#L32-L39)),
incluindo o journal ativo. Regra de bolso: o que você coloca em `_sim_tick` divide 50 ms
com 5 lobos; o que coloca em `_physics_process` divide o frame com a renderização.

**Journal sob demanda, não gravação automática.** A CLI lê, após `--`,
`--tick-journal=path` ([main.gd:993-1000](src/main.gd#L993-L1000)). `start()` recusa caminho
existente: cada corrida exige arquivo novo explícito, sem reabrir histórico nem criar
arquivos automaticamente entre sessões ([tick_journal.gd:47-62](src/persistence/tick_journal.gd#L47-L62)).
`record()` acrescenta JSONL `[tick,hash]` com `flush` por linha; recusa tick negativo e,
após o primeiro registro, duplicata, regressão ou salto (exige `last_tick + 1`)
([tick_journal.gd:69-87](src/persistence/tick_journal.gd#L69-L87)). A chamada ocorre após
`clock.tick += 1`, **dentro** do cronômetro da simulação
([main.gd:283-289](src/main.gd#L283-L289)); sem o modo, o tick só consulta `active()`.
O load válido encerra o arquivo antes de restaurar o mundo
([main.gd:814-816](src/main.gd#L814-L816)); sair da cena também o fecha
([main.gd:1003-1004](src/main.gd#L1003-L1004)). O arquivo cresce apenas enquanto a gravação
explícita estiver ativa; não é journal de comandos nem mecanismo de replay.

**Orçamentos que já são código**, não intenção (regra 7):

| Orçamento | Valor hoje | Onde |
| --- | --- | --- |
| Passo de simulação | 50 ms (20 Hz), teto de 5 passos por frame; o que estourar vira `dropped_ticks` à vista | [sim_clock.gd:5-7](src/core/sim_clock.gd#L5-L7), [:19-29](src/core/sim_clock.gd#L19-L29) |
| Árvore de decisão, por lobo | 400 µs no `SubtreeGuard` (a default da classe é 250 µs); só BT, não percepção/utilidade | [bt_tree.gd:117-137](src/ai/behavior/bt_tree.gd#L117-L137), [wolf.gd:380-381](src/entities/wolf.gd#L380-L381) |
| Malha | 2 chunks por frame | [main.gd:28](src/main.gd#L28), usado em [:292-293](src/main.gd#L292-L293) |
| Difusão do Éter | 4 passadas por segundo, não 20 | [main.gd:27](src/main.gd#L27), [:254-256](src/main.gd#L254-L256) |
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
  ([wolf.gd:833](src/entities/wolf.gd#L833)): com a matilha inteira viva, 5 × 20 = 100
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
([main.gd:927-942](src/main.gd#L927-L942)). A colheita estreita de reações já separa
`sim_step` integral de BT, mas não mede alocações nem o HOT agregado dos cinco lobos.
Então o primeiro passo de qualquer otimização é a colheita, não o corte.

**Leitor de rastros: custo do scan medido por ablação; alocação continua sem medição.** Cada
scan percorre `7 × 7` células na camada Y do lobo: **49 × 3 leituras** `sample_cell`
(BLOOD/WORK/FEAR) por lobo, com seleção por `BLOOD + 0,35 × WORK`
([wolf.gd:881-921](src/entities/wolf.gd#L881-L921)). Se nenhuma célula da camada própria passa
de `SCENT_MIN`, o mesmo quadrado se repete na camada de cima e na de baixo — **98 leituras por
camada vizinha aberta** (dois canais, sem FEAR), 196 por scan quando as duas abrem. A cadência
é `0,25 s`, com rescan no tick seguinte à inspeção concluída
([:514-527](src/entities/wolf.gd#L514-L527),
[:848-849](src/entities/wolf.gd#L848-L849), [:881-882](src/entities/wolf.gd#L881-L882)); cinco lobos podem fazer o scan no mesmo tick.
O `sim_step` integral de 2 768 passos no cenário estreito mede **324 159 µs** com a camada
própria, **427 537 µs** com as três camadas incondicionais e **363 680 µs** com o gate pelo
nível próprio: o escalonamento corta 64 190 das 111 132 leituras extras (567 scans, 479
entradas de camada vizinha contra o máximo de 1 134). O chão do rastro não mede nada: trocar
`surface_height()` pela busca pelo sólido na mesma camada move o total em −1,8 % (324 159 →
318 171 µs) e nas três camadas em −1,5 % (434 052 → 427 537 µs), ambos dentro do ruído das
corridas repetidas do mesmo braço
([:924-936](src/entities/wolf.gd#L924-L936); [matriz de ablação, seis braços](docs/evidence/rastro-duas-camadas/readback.log)).
Isso não conta todo o `sim_step`: há ainda três amostras locais por tick e LOS quando
pode importar ([:840-846](src/entities/wolf.gd#L840-L846)). Ao concluir os `2 s` de
inspeção, a vizinhança `3 × 3` acrescenta até duas leituras por célula válida para
registrar a força ponderada no cache, limitado a **32 células por lobo**, com expiração
em `30 s` e renovação por aumento de pelo menos `0,06` ponderado
([:27-34](src/entities/wolf.gd#L27-L34), [:557-571](src/entities/wolf.gd#L557-L571),
[:908-909](src/entities/wolf.gd#L908-L909)). `keys()` aloca um Array por scan para
recolher expirados e também nas evicções ao atingir o teto
([:883-885](src/entities/wolf.gd#L883-L885), [:569-570](src/entities/wolf.gd#L569-L570)).
O cache transitório pertence ao lobo e é limpo no load
([:1130-1136](src/entities/wolf.gd#L1130-L1136)). Esses limites de cache e de alocação são
derivados do código: a ablação mede o scan, não a alocação total, e nada aqui fecha P1.

**Cópia de estado e custo observado:** com journal ativo, `state_bytes()` copia
32 × 16 × 32 × 3 × 4 = **196 608 bytes/tick** de Float32 (tamanho conferido pelo teste),
além dos arrays de edições, lobos vivos (hoje até 5 mentes) e crenças ordenados,
serialização, SHA256 e escrita com `flush`. Não é custo total de alocação medido.
O journal expõe `records`, `last_us`, `worst_us` e `total_us` (hash + escrita + flush
concluídos) em `diagnostics()["journal"]`
([tick_journal.gd:74-98](src/persistence/tick_journal.gd#L74-L98),
[main.gd:945](src/main.gd#L945)). No candidato histórico local recém-importado, anterior
ao refinamento dos rastros, 205 registros custaram 160 000 µs ao todo, com pico de
1 646 µs; o load encerrou a gravação. Os dois smokes, sem/com journal, terminaram sem
ticks perdidos, mas não são replay pareado, prova de otimização ou medição do lobo
refinado: [fontes e logs](docs/melhorias-status.md#notas-de-medição).

**LOD (regra 6) é parcial, e se diz assim:** existe *throttle temporal* por subsistema —
difusão e visualização do Éter 4×/s, cadáveres 1×/s; o leitor de rastros tem cadência de
`0,25 s` (com rescan após inspeção) e o registro de avistamentos, `2 s`
([wolf.gd:514-527](src/entities/wolf.gd#L514-L527), [:871-873](src/entities/wolf.gd#L871-L873)).
Isso não limita a LOS a 4×/s: ela é consultada a cada tick se o jogador está vivo e a
menos de 30 m. Não existe *LOD por distância*: os lobos vivos avaliam o BT a cada tick,
perto ou longe ([wolf.gd:828-833](src/entities/wolf.gd#L828-L833)). A peça do design é o
`HotSet`/Véu (§04, §06) e pertence a P2; antes de o custo aparecer em log, ela é backlog.

**Anti-bloat, com o estado real:**

- `main.gd` é o "objeto deus" conhecido — 1004 linhas nesta revisão, 510 na `main` de `eb6ec8d`, donas de mundo, relógio, matilha, HUD,
  oráculo, visualização, instância do journal, o nó de áudio e o hospedeiro do modelo ([main.gd:43-59](src/main.gd#L43-L59)). Isso está registrado como
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
robustez do oráculo **atual**, que é HTTP ([mind_oracle.gd:11-13](src/ai/mind_oracle.gd#L11-L13)).

Fora, sem autorização explícita do dono do repositório: P2 (facções / `SlowSim`), oráculo nativo
em GDExtension, co-op, progressão e chefes, e qualquer "melhoria" de sistema que já passou no
gate dele. Idéia boa de fase futura vira linha de backlog no status, não código agora.

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
[`tests/smoke_test.gd:913-921`](tests/smoke_test.gd#L913-L921) ("segurar break minerou", "tempo de
mineracao == dureza", "lavra entrou no inventario como drop"). Melhorar o que já passou no gate
continua vetado; o que entra é o buraco real: **nenhum bicho escreve no mundo hoje** — os únicos
dois `world.set_block` de gameplay são os do jogador (`src/entities/player.gd:685`, `:711`).

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
   arquivos de hoje. `src/main.gd:242` ("uma nova matilha entrou no vale") e
   `src/main.gd:483` ("o lobo caiu o sangue fica no eter") eram os **únicos** avisos de
   criatura; os demais `hud.show_message` (`:135`, `:273`, `:450-451` recebendo `player.notice`
   de `src/entities/player.gd:309`/`:664`/`:682`, conectado em [`src/main.gd:121`](src/main.gd#L121),
   `:524`/`:526`/`:532`/`:536`/`:572` e [`src/ui/hud.gd:603`](src/ui/hud.gd#L603)/`:605`) eram
   feedback de ação do próprio jogador ou diagnóstico de save, e **ficam**. Na água, já havia
   teste de solo seco em `_leaf_wander`
   (`src/entities/wolf.gd:417-435`, via `_pick_wander` `:440-452` e `_dry_ground` `:482-486`) e resgate por tempo de nado
   (`SHORE_AFTER` `:79`, aplicado em `sim_step` `:608-614` com `_shore_point` `:490-500`); as outras
   **quatro** folhas escolhiam alvo sem nenhum teste de solo (`_leaf_flee` `:299`, `_leaf_chase`
   `:315`/`:319`, `_leaf_stalk` `:358`, `_leaf_investigate` `:376`). No spawn, `_random_ground_point`
   (`src/main.gd:300-314`) sorteava o anel de 16–46 m **em torno de `spawn_point()`** — que é o
   centro fixo do mundo (`:206-209`), não onde o jogador está — exigia coluna seca
   (`y > VoxelConfig.SEA_LEVEL`) e volume livre (`_volume_clear` `:322-324`), caía em silêncio no
   centro depois de 24 tentativas, e **nenhum caminho de spawn consultava a posição atual do jogador
   nem `world.line_of_sight`** (`src/world/voxel_world.gd:393`).
   O que a perna entregou, com os números de hoje: **nenhum letreiro de criatura** — as duas
   frases saíram, o contador de abate fica ([`src/main.gd:754-759`](src/main.gd#L754-L759)) e a
   vaga devolvida à fila de respawn não anuncia um ponto que pode ter sido recusado
   ([`src/main.gd:265-274`](src/main.gd#L265-L274)); **ronda por chão seco sem copiar o teste
   para dentro das folhas** — o alvo escrito pela árvore é filtrado depois do tick por
   `_resolve_dry_target()` ([`src/entities/wolf.gd:686-690`](src/entities/wolf.gd#L686-L690),
   chamado em [`:834`](src/entities/wolf.gd#L834), fora dos 400 µs do `SubtreeGuard`), e a água é
   último recurso com travessia comprometida por `SCENT_PERIOD` (`_demand_shore()`
   [`:665-676`](src/entities/wolf.gd#L665-L676)) mais o resgate por tempo de nado
   (`SHORE_AFTER` [`:108`](src/entities/wolf.gd#L108), aplicado em [`:823`](src/entities/wolf.gd#L823));
   **spawn a distância segura e fora da visada** — o predicado único `_spawn_point_ok()` exige
   ≥ `SAFE_SPAWN_DIST` (32 m) **e** que a linha do olho do jogador ao peito do lobo esteja bloqueada
   ([`src/main.gd:512-517`](src/main.gd#L512-L517)), dentro das bandas em torno da posição **atual**
   do jogador (`SPAWN_BANDS` [`:460`](src/main.gd#L460), busca em [`:536-587`](src/main.gd#L536-L587)),
   sem fallback mudo no centro e com a recusa impressa por motivo contado; colunas de lar distintas
   por lobo (`_home_columns()` [`:449-453`](src/main.gd#L449-L453)) e mordaca de 18 m sobre o lar de
   um irmao vivo (`PACK_LEASH` [`:469`](src/main.gd#L469), centro lido em [`:501-511`](src/main.gd#L501-L511)),
   que é o conserto do furo #16 — sem ela a alcateia nunca se formou na sessao real da suíte.
   Sustenteam isso **33 checagens em oito cenários** nomeados no runner
   ([`tests/aether_reactions_test.gd:24-28`](tests/aether_reactions_test.gd#L24-L28), censo
   [`:34`](tests/aether_reactions_test.gd#L34) de 150 para 183) e a checagem da sessão real
   ([`tests/smoke_test.gd:273-276`](tests/smoke_test.gd#L273-L276)), agora com `biggest >= 2`.
2. **Árvore genealógica de todo ser vivo, com o Éter trabalhando isso** (dossiê
   [`docs/planos/13-arvore-genealogica-e-ether.md`](docs/planos/13-arvore-genealogica-e-ether.md),
   branch `feat/arvore-genealogica-13`, dono o agente `genealogia-13`). Recorte lido antes de
   prometer nível: `src/entities/` tem `player`, `player_avatar`, `fp_viewmodel`, `voxel_body` e
   `wolf` — **nenhum NPC** e **uma única espécie animal**. Então entra o primitivo (ascendência por
   entidade viva: identidade, pais, geração) e a **escada de complexidade** — animal simples ×
   humano/NPC mais complexo — fica documentada como `[TARGET]`, sem estrutura nova antes do segundo
   comprador (regra da casa: generalize no segundo chamador, não no primeiro). Hoje a personalidade
   é sorteada da semente do próprio lobo (`Mind._init` `src/ai/mind.gd:24-32`, chamado em
   `src/entities/wolf.gd:245` com `1000 + identity`) e **nenhum pai contribui com nada**; o pelo vem
   do bioma do lar (`FUR_COLORS` `src/entities/wolf.gd:119-124`, `home_biome` `:136`), não de
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
`PACK_LEASH = 18.0` ([src/main.gd:469](src/main.gd#L469)) é a primeira tentativa
([:541](src/main.gd#L541)) e `_pack_leash()` devolve o lar do **primeiro** lobo vivo
([:501-505](src/main.gd#L501-L505)), enquanto a caixa útil é 116 × 116 m — o clamp de `6 … W-6` em
[:559-560](src/main.gd#L559-L560) sobre um mundo de 128 × 128. É por isso que ele percorreu o vale
inteiro e viu um lobo só. A página decide o gate por **componentes conexos do grafo de coesão** lido em
`pack_of()`, não por adjetivo, e abre o par de braços (§3.4) antes do código: **A** (só colocação) é a
escolhida primeiro e só se aceita com a checagem de derivação verde; **B** (dar âncora ao centro de
ronda) custa re-derivar uma checagem gateada pela perna 10 e por isso só entra com o vermelho do A na
mesa. Duas consequências de documentação, registradas **antes** de qualquer linha: o **furo #18** (as
recusas de spawn nunca tiveram testemunha numérica — `motivos` só é interpolado na string impressa,
[src/main.gd:545](src/main.gd#L545)) passa a ter dono fixo, a perna 16, e deixa de estar oferecido à 16
**ou** à 11; e esta leitura abre o **furo #21** — `pack_pairs` incrementa em
[:639](src/main.gd#L639) **antes** do teste de raio em [:640](src/main.gd#L640), então a asserção
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
([:262](src/world/voxel_world.gd#L262)), então o gate desta perna observa estado de mundo lido
(`get_block` + [`world.edits`](src/world/voxel_world.gd#L42)) e quem assina o sinal continua sendo a 17 —
que é exatamente o motivo pelo qual a checagem `queda_move_a_celula` daquela página nasce vermelha.
(3) **O desemperto já tem dois ramos**, e o segundo é da 19 ([src/entities/wolf.gd:977-984](src/entities/wolf.gd#L977-L984)),
então cavar entra como **terceiro** ramo do mesmo `if` (fork A), e a alternativa de folha nova na
`Selector` (fork B) só se abre com o A vermelho porque `intent` é hashiado pelo journal. (4) **Quem cava
é decidido pelo alcance do corpo**, não por fase: `PHASE_SCALE` dá 0,45 ao filhote
([src/entities/wolf.gd:89](src/entities/wolf.gd#L89)) e o `reach` do degrau vem de `dims`
([src/entities/voxel_body.gd:171](src/entities/voxel_body.gd#L171)). Disso saem dois furos novos, ambos
com dono escrito antes de qualquer linha: **#22**, a lista de bancadas é alimentada só pelos sinais do
`Player`, então um bicho que removesse uma `BENCH` deixaria `bench_positions()` apontando para o ar até o
próximo load — fechado **por construção** pela cláusula `not world.edits.has(pos)` do §3.2, com a
checagem `cavar_nao_toca_construcao_alheia` pagando o número; e **#23**, a permeabilidade do Éter decide
o peso do vizinho por **um** voxel no canto da célula de 4×4×4
([src/world/aether_field.gd:174-176](src/world/aether_field.gd#L174-L176),
[src/world/voxel_config.gd:16](src/world/voxel_config.gd#L16)), então a frase antiga "difundem com menos
barreira" não é falsificável e o item (b) foi re-baseado no `y` que `_scent_ground_y` devolve
([src/entities/wolf.gd:928-936](src/entities/wolf.gd#L928-L936)) — dono perna 05. Uma consequência nova de
palco de teste, e é a que deixaria uma checagem verde pelo motivo errado: `_wall` e `_cave_carve` do
runner chamam `set_block` com `record` default, ou seja, parede de teste **é construção registrada**; o
scaffolding do cavar tem de escrever com `record = false`. Nada deste registro encosta em
`Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` nem na projeção do journal, nenhum número publicado foi
re-medido por ele, e nenhuma linha de código da perna 12 foi escrita: `feat/bicho-cavando-12` não abre
antes de a 16 pousar, porque as duas escrevem `src/main.gd`.

**Registro de 2026-11-22 (3) — a pauta 20, aberta por autorização nova do dono. A autorização é para a
pauta, não para o código: nenhuma linha de `src/` foi escrita por esta leitura.** Ele mandou pôr em pauta
o prompt que ele mesmo chamou de "Prompt Master — Inteligência Autônoma de Mobs + Ecossistema Vivo", e
ele entra no "dentro" como
[`docs/planos/20-mente-autonoma-de-mobs-e-ecossistema.md`](docs/planos/20-mente-autonoma-de-mobs-e-ecossistema.md),
branch `feat/mobs-autonomos-e-ecossistema-20`, dono o agente `mente-eco-20`. É, de longe, o pedido mais
largo já registrado — sete entregas (avaliação de alcance, memória de falha, tabela de espécie, três
grupos de criaturas, drops, troféu colocável e os testes) sobre seis arquivos que a fila já escreve — e
é por isso que a página entrega o **corte**, não a lista: cada §3 nomeia a decisão, o braço rejeitado e
o número que reabre o braço. Números de `arquivo:linha` da `main` em `99d1167`, cujo `src/` e `tests/`
são byte a byte os do pin `5b519f8` (`git diff --stat 5b519f8 HEAD -- src tests` devolve vazio nesta
leitura): o contrato publicado continua **252 / 0 / 42,4 s** e esta pauta não pede re-corrida porque não
muda o que a suíte roda.

A posição na fila serializada é exceção de ordem registrada **antes** de qualquer linha (mandato 4): a
fila passa a **09 → 10 → 15 → 14 → 11 → 19 → 16 → 12 → 17 → 18 → 20 → 13**. A 20 vem **depois** da 18
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
([src/entities/wolf.gd:1049-1050](src/entities/wolf.gd#L1049-L1050)), arma o timer de cadáver
([:1051](src/entities/wolf.gd#L1051)) e só então emite `died` ([:1052](src/entities/wolf.gd#L1052)).
(2) O sinal **não** é órfão — tem **dois** consumidores em `src/`, e nenhum deles é um item:
`_on_wolf_died` ([src/main.gd:364](src/main.gd#L364) conecta, corpo em [`:754`](src/main.gd#L754)) só
soma `stats["wolves_felled"]`, e o diretor de áudio toca `wolf_died`
([src/audio/audio_director.gd:161](src/audio/audio_director.gd#L161), corpo em [`:412`](src/audio/audio_director.gd#L412));
a conclusão do prompt fica de pé, o motivo dela não. (3) "Lobos presos diante de bloco" era a pauta da
**19**, que pousou: hoje o impulso sai em [src/entities/wolf.gd:984](src/entities/wolf.gd#L984). (4) O
leito `amb_birds` tocando sem nenhuma ave no mundo **não** é defeito do tipo da 19 — é cama de ambiência
de campo aberto, correta como ambiência; o que ela prova é que o mundo já promete céu vivo.

Disso saem dois furos novos, ambos com dono escrito antes de qualquer linha. **#24**: o
[docs/design/04-local-ai-architecture.md:44](docs/design/04-local-ai-architecture.md#L44) declara
`[DECIDED]` que "nós são instanciados por espécie/archetype, não por entidade", com uma BT `.tres`
compartilhada por 1000 lobos e o estado no `Blackboard` — e na árvore não há **nenhum** `.tres` em `src/`
(o único do repositório é `default_bus_layout.tres` na raiz, layout de barramento de áudio), não existe
classe `Blackboard` (grep em `src/` devolve zero; o estado chega como `Dictionary` literal inline no tick,
[src/entities/wolf.gd:833](src/entities/wolf.gd#L833)) e cada `Wolf` constrói a própria árvore: `setup()`
([:231](src/entities/wolf.gd#L231)) chama `_build_tree()` ([:250](src/entities/wolf.gd#L250)), corpo em
([:354](src/entities/wolf.gd#L354)) — e o comentário de [src/ai/behavior/bt_tree.gd:2](src/ai/behavior/bt_tree.gd#L2)
repete a promessa. Dono: perna 20 §3.5, com a checagem `arvore_por_arquetype` pagando o número. **#25**:
`tests/audio_test.gd.uid` e `tests/audio_live_probe.gd.uid` estão fora do git enquanto todos os outros
scripts estão (`src` 30/30, `tests` 7 de 9), então todo clone limpo mostra duas linhas `??` depois do
`--import`; nenhuma cena os referencia por `uid://` — [tests/audio_live_probe.tscn:3](tests/audio_live_probe.tscn#L3)
usa `path=` — então é sujeira de instrumento, não defeito de execução. Dono: arrumação do dono do repo;
esta branch **não** os comita. Nenhuma linha de código da perna 20 foi escrita:
`feat/mobs-autonomos-e-ecossistema-20` não abre antes de a 18 pousar.

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
   velhas. Documento que descreve peça inexistente se marca como alvo, não se escreve no indicativo.
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
