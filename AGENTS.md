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
   ([main.gd:148](src/main.gd#L148) → [hud.gd:276-277](src/ui/hud.gd#L276-L277)). O hospedeiro do
   modelo lê dois campos do oráculo — `last_reason` e `server_url`
   ([llm_server_host.gd:152-153](src/ai/llm_server_host.gd#L152-L153),
   [:189](src/ai/llm_server_host.gd#L189)) — só para montar a linha de status do F3: leitura,
   nenhuma escrita. Não existe caminho do oráculo para `Mind`, `Wolf` ou `VoxelWorld`; a decisão
   vem de BT + utilidade
   ([wolf.gd:237-265](src/entities/wolf.gd#L237-L265), [:626-628](src/entities/wolf.gd#L626-L628),
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
   ([main.gd:772-773](src/main.gd#L772-L773)); o acesso ao estado autoritativo permanece aberto.
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
   [wolf.gd:940-941](src/entities/wolf.gd#L940-L941)); agora há também colheita headless
   estreita de `sim_step` integral e `_guard.last_us`/`trips`, um lobo por cenário
   ([aether_reactions_test.gd:220-232](tests/aether_reactions_test.gd#L220-L232),
   [:2614-2617](tests/aether_reactions_test.gd#L2614-L2617)). O guard mede só BT, sem
   percepção/utilidade ([wolf.gd:263-265](src/entities/wolf.gd#L263-L265)); isso não mede
   o HOT agregado dos cinco lobos nem fecha P1.
6. **Mudanças pequenas e atômicas.** Um assunto por commit e suíte verde entre eles, com a
   medição de cada um no próprio commit. O corte da revisão do golpe é o exemplo: o conserto do passo
   de golpe e a publicação do número do clone limpo são dois commits porque cada um tem uma
   corrida que lhe responde.
7. **Comentário explica o porquê, em português.** Nunca narrar o óbvio do código. Modelos
   reais: [smoke_test.gd:269-279](tests/smoke_test.gd#L269-L279) (por que o teste dá o `dt` e os
   passos ele mesmo) e o `GEN_VERSION` [world_gen.gd:6](src/world/world_gen.gd#L6), que faz o
   save velho ser recusado com mensagem em vez de lido torto
   ([main.gd:660-661](src/main.gd#L660-L661)).
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
([main.gd:220-226](src/main.gd#L220-L226) → `update_local`): lavra e colocação escrevem
voxels fora do tick ([player.gd:667](src/entities/player.gd#L667),
[:693](src/entities/player.gd#L693)) e seus sinais também imprimem no Éter
([main.gd:547-552](src/main.gd#L547-L552)). O lobo não é só 20 Hz:
`wolf._physics_process` locomove o corpo e reduz timers de cadáver, atordoamento e desvio
por frame ([wolf.gd:804-849](src/entities/wolf.gd#L804-L849)). Decisão de IA, difusão,
recolha de cadáveres e respawns são agendados pelo tick de 20 Hz, com cadências próprias
([main.gd:229-259](src/main.gd#L229-L259), [sim_clock.gd:5-7](src/core/sim_clock.gd#L5-L7)).
`begin_step`/`end_step` cronometra esse passo em microsegundos
([main.gd:224-226](src/main.gd#L224-L226), [sim_clock.gd:32-39](src/core/sim_clock.gd#L32-L39)),
incluindo o journal ativo. Regra de bolso: o que você coloca em `_sim_tick` divide 50 ms
com 5 lobos; o que coloca em `_physics_process` divide o frame com a renderização.

**Journal sob demanda, não gravação automática.** A CLI lê, após `--`,
`--tick-journal=path` ([main.gd:776-783](src/main.gd#L776-L783)). `start()` recusa caminho
existente: cada corrida exige arquivo novo explícito, sem reabrir histórico nem criar
arquivos automaticamente entre sessões ([tick_journal.gd:47-62](src/persistence/tick_journal.gd#L47-L62)).
`record()` acrescenta JSONL `[tick,hash]` com `flush` por linha; recusa tick negativo e,
após o primeiro registro, duplicata, regressão ou salto (exige `last_tick + 1`)
([tick_journal.gd:69-87](src/persistence/tick_journal.gd#L69-L87)). A chamada ocorre após
`clock.tick += 1`, **dentro** do cronômetro da simulação
([main.gd:253-259](src/main.gd#L253-L259)); sem o modo, o tick só consulta `active()`.
O load válido encerra o arquivo antes de restaurar o mundo
([main.gd:663-665](src/main.gd#L663-L665)); sair da cena também o fecha
([main.gd:786-787](src/main.gd#L786-L787)). O arquivo cresce apenas enquanto a gravação
explícita estiver ativa; não é journal de comandos nem mecanismo de replay.

**Orçamentos que já são código**, não intenção (regra 7):

| Orçamento | Valor hoje | Onde |
| --- | --- | --- |
| Passo de simulação | 50 ms (20 Hz), teto de 5 passos por frame; o que estourar vira `dropped_ticks` à vista | [sim_clock.gd:5-7](src/core/sim_clock.gd#L5-L7), [:19-29](src/core/sim_clock.gd#L19-L29) |
| Árvore de decisão, por lobo | 400 µs no `SubtreeGuard` (a default da classe é 250 µs); só BT, não percepção/utilidade | [bt_tree.gd:117-137](src/ai/behavior/bt_tree.gd#L117-L137), [wolf.gd:263-264](src/entities/wolf.gd#L263-L264) |
| Malha | 2 chunks por frame | [main.gd:19](src/main.gd#L19), usado em [:262-263](src/main.gd#L262-L263) |
| Difusão do Éter | 4 passadas por segundo, não 20 | [main.gd:18](src/main.gd#L18), [:232-234](src/main.gd#L232-L234) |
| Recolha de cadáver, visão do Éter | 1 s e 0,25 s | [main.gd:22](src/main.gd#L22), [:20](src/main.gd#L20) |

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
  ([wolf.gd:696](src/entities/wolf.gd#L696)): com a matilha inteira viva, 5 × 20 = 100
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
([main.gd:717-732](src/main.gd#L717-L732)). A colheita estreita de reações já separa
`sim_step` integral de BT, mas não mede alocações nem o HOT agregado dos cinco lobos.
Então o primeiro passo de qualquer otimização é a colheita, não o corte.

**Leitor de rastros: custo do scan medido por ablação; alocação continua sem medição.** Cada
scan percorre `7 × 7` células na camada Y do lobo: **49 × 3 leituras** `sample_cell`
(BLOOD/WORK/FEAR) por lobo, com seleção por `BLOOD + 0,35 × WORK`
([wolf.gd:744-784](src/entities/wolf.gd#L744-L784)). Se nenhuma célula da camada própria passa
de `SCENT_MIN`, o mesmo quadrado se repete na camada de cima e na de baixo — **98 leituras por
camada vizinha aberta** (dois canais, sem FEAR), 196 por scan quando as duas abrem. A cadência
é `0,25 s`, com rescan no tick seguinte à inspeção concluída
([:394-407](src/entities/wolf.gd#L394-L407),
[:711-712](src/entities/wolf.gd#L711-L712), [:744-745](src/entities/wolf.gd#L744-L745)); cinco lobos podem fazer o scan no mesmo tick.
O `sim_step` integral de 2 768 passos no cenário estreito mede **324 159 µs** com a camada
própria, **427 537 µs** com as três camadas incondicionais e **363 680 µs** com o gate pelo
nível próprio: o escalonamento corta 64 190 das 111 132 leituras extras (567 scans, 479
entradas de camada vizinha contra o máximo de 1 134). O chão do rastro não mede nada: trocar
`surface_height()` pela busca pelo sólido na mesma camada move o total em −1,8 % (324 159 →
318 171 µs) e nas três camadas em −1,5 % (434 052 → 427 537 µs), ambos dentro do ruído das
corridas repetidas do mesmo braço
([:787-799](src/entities/wolf.gd#L787-L799); [matriz de ablação, seis braços](docs/evidence/rastro-duas-camadas/readback.log)).
Isso não conta todo o `sim_step`: há ainda três amostras locais por tick e LOS quando
pode importar ([:703-709](src/entities/wolf.gd#L703-L709)). Ao concluir os `2 s` de
inspeção, a vizinhança `3 × 3` acrescenta até duas leituras por célula válida para
registrar a força ponderada no cache, limitado a **32 células por lobo**, com expiração
em `30 s` e renovação por aumento de pelo menos `0,06` ponderado
([:27-34](src/entities/wolf.gd#L27-L34), [:437-451](src/entities/wolf.gd#L437-L451),
[:771-772](src/entities/wolf.gd#L771-L772)). `keys()` aloca um Array por scan para
recolher expirados e também nas evicções ao atingir o teto
([:746-748](src/entities/wolf.gd#L746-L748), [:449-450](src/entities/wolf.gd#L449-L450)).
O cache transitório pertence ao lobo e é limpo no load
([:965-971](src/entities/wolf.gd#L965-L971)). Esses limites de cache e de alocação são
derivados do código: a ablação mede o scan, não a alocação total, e nada aqui fecha P1.

**Cópia de estado e custo observado:** com journal ativo, `state_bytes()` copia
32 × 16 × 32 × 3 × 4 = **196 608 bytes/tick** de Float32 (tamanho conferido pelo teste),
além dos arrays de edições, lobos vivos (hoje até 5 mentes) e crenças ordenados,
serialização, SHA256 e escrita com `flush`. Não é custo total de alocação medido.
O journal expõe `records`, `last_us`, `worst_us` e `total_us` (hash + escrita + flush
concluídos) em `diagnostics()["journal"]`
([tick_journal.gd:74-98](src/persistence/tick_journal.gd#L74-L98),
[main.gd:728](src/main.gd#L728)). No candidato histórico local recém-importado, anterior
ao refinamento dos rastros, 205 registros custaram 160 000 µs ao todo, com pico de
1 646 µs; o load encerrou a gravação. Os dois smokes, sem/com journal, terminaram sem
ticks perdidos, mas não são replay pareado, prova de otimização ou medição do lobo
refinado: [fontes e logs](docs/melhorias-status.md#notas-de-medição).

**LOD (regra 6) é parcial, e se diz assim:** existe *throttle temporal* por subsistema —
difusão e visualização do Éter 4×/s, cadáveres 1×/s; o leitor de rastros tem cadência de
`0,25 s` (com rescan após inspeção) e o registro de avistamentos, `2 s`
([wolf.gd:394-407](src/entities/wolf.gd#L394-L407), [:734-736](src/entities/wolf.gd#L734-L736)).
Isso não limita a LOS a 4×/s: ela é consultada a cada tick se o jogador está vivo e a
menos de 30 m. Não existe *LOD por distância*: os lobos vivos avaliam o BT a cada tick,
perto ou longe ([wolf.gd:691-696](src/entities/wolf.gd#L691-L696)). A peça do design é o
`HotSet`/Véu (§04, §06) e pertence a P2; antes de o custo aparecer em log, ela é backlog.

**Anti-bloat, com o estado real:**

- `main.gd` é o "objeto deus" conhecido — 787 linhas nesta revisão, 510 na `main` de `eb6ec8d`, donas de mundo, relógio, matilha, HUD,
  oráculo, visualização, instância do journal, o nó de áudio e o hospedeiro do modelo ([main.gd:34-50](src/main.gd#L34-L50)). Isso está registrado como
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
existe: a lavra contínua do jogador (`player.gd:636-647`, segura `break_block`, o progresso soma
por frame e o bloco cai quando `hardness` estoura) e a coleta automática no inventário
(`:659-672`, o drop do registro entra direto) — ambas checadas em
[`tests/smoke_test.gd:903-911`](tests/smoke_test.gd#L903-L911) ("segurar break minerou", "tempo de
mineracao == dureza", "lavra entrou no inventario como drop"). Melhorar o que já passou no gate
continua vetado; o que entra é o buraco real: **nenhum bicho escreve no mundo hoje** — os únicos
dois `world.set_block` de gameplay são os do jogador (`:667`, `:693`).

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
   frases saíram, o contador de abate fica ([`src/main.gd:603-608`](src/main.gd#L603-L608)) e a
   vaga devolvida à fila de respawn não anuncia um ponto que pode ter sido recusado
   ([`src/main.gd:243-252`](src/main.gd#L243-L252)); **ronda por chão seco sem copiar o teste
   para dentro das folhas** — o alvo escrito pela árvore é filtrado depois do tick por
   `_resolve_dry_target()` ([`src/entities/wolf.gd:566-570`](src/entities/wolf.gd#L566-L570),
   chamado em [`:697`](src/entities/wolf.gd#L697), fora dos 400 µs do `SubtreeGuard`), e a água é
   último recurso com travessia comprometida por `SCENT_PERIOD` (`_demand_shore()`
   [`:545-556`](src/entities/wolf.gd#L545-L556)) mais o resgate por tempo de nado
   (`SHORE_AFTER` [`:79`](src/entities/wolf.gd#L79), aplicado em [`:686`](src/entities/wolf.gd#L686));
   **spawn a distância segura e fora da visada** — o predicado único `_spawn_point_ok()` exige
   ≥ `SAFE_SPAWN_DIST` (32 m) **e** que a linha do olho do jogador ao peito do lobo esteja bloqueada
   ([`src/main.gd:361-366`](src/main.gd#L361-L366)), dentro das bandas em torno da posição **atual**
   do jogador (`SPAWN_BANDS` [`:336`](src/main.gd#L336), busca em [`:385-436`](src/main.gd#L385-L436)),
   sem fallback mudo no centro e com a recusa impressa por motivo contado; colunas de lar distintas
   por lobo (`_home_columns()` [`:325-329`](src/main.gd#L325-L329)) e mordaca de 18 m sobre o lar de
   um irmao vivo (`PACK_LEASH` [`:345`](src/main.gd#L345), centro lido em [`:350-360`](src/main.gd#L350-L360)),
   que é o conserto do furo #16 — sem ela a alcateia nunca se formou na sessao real da suíte.
   Sustenteam isso **33 checagens em oito cenários** nomeados no runner
   ([`tests/aether_reactions_test.gd:19-23`](tests/aether_reactions_test.gd#L19-L23), censo
   [`:25`](tests/aether_reactions_test.gd#L25) de 150 para 183) e a checagem da sessão real
   ([`tests/smoke_test.gd:263-266`](tests/smoke_test.gd#L263-L266)), agora com `biggest >= 2`.
2. **Árvore genealógica de todo ser vivo, com o Éter trabalhando isso** (dossiê
   [`docs/planos/13-arvore-genealogica-e-ether.md`](docs/planos/13-arvore-genealogica-e-ether.md),
   branch `feat/arvore-genealogica-13`, dono o agente `genealogia-13`). Recorte lido antes de
   prometer nível: `src/entities/` tem `player`, `player_avatar`, `fp_viewmodel`, `voxel_body` e
   `wolf` — **nenhum NPC** e **uma única espécie animal**. Então entra o primitivo (ascendência por
   entidade viva: identidade, pais, geração) e a **escada de complexidade** — animal simples ×
   humano/NPC mais complexo — fica documentada como `[TARGET]`, sem estrutura nova antes do segundo
   comprador (regra da casa: generalize no segundo chamador, não no primeiro). Hoje a personalidade
   é sorteada da semente do próprio lobo (`Mind._init` `src/ai/mind.gd:24-32`, chamado em
   `src/entities/wolf.gd:203` com `1000 + identity`) e **nenhum pai contribui com nada**; o pelo vem
   do bioma do lar (`FUR_COLORS` `src/entities/wolf.gd:90-95`, `home_biome` `:107`), não de
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
