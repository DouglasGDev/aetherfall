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
   estado de mundo. *Seguro por construção hoje:* a única saída de `MindOracle` é o dicionário
   `_narrations` ([mind_oracle.gd:27](src/ai/mind_oracle.gd#L27), gravado em
   [:120](src/ai/mind_oracle.gd#L120)), lido por `narration_of()`
   ([:59-60](src/ai/mind_oracle.gd#L59-L60)) e entregue só ao HUD
   ([main.gd:132](src/main.gd#L132) → [hud.gd:270-271](src/ui/hud.gd#L270-L271)). Não existe
   caminho do oráculo para `Mind`, `Wolf` ou `VoxelWorld`; a decisão vem de BT + utilidade
   ([wolf.gd:201-229](src/entities/wolf.gd#L201-L229), [:556-558](src/entities/wolf.gd#L556-L558),
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
   ([main.gd:575-576](src/main.gd#L575-L576)); o acesso ao estado autoritativo permanece aberto.
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
   [hud.gd:241-275](src/ui/hud.gd#L241-L275)) mostra tick, `worst_step_ms`, ticks perdidos,
   total por canal do Éter e uma linha por lobo com a narrativa do oráculo. *Falta para P1:*
   `MindsInspector` não existe. O custo de BT sai no F3 (`tree_stats()`,
   [wolf.gd:838-839](src/entities/wolf.gd#L838-L839)); agora há também colheita headless
   estreita de `sim_step` integral e `_guard.last_us`/`trips`, um lobo por cenário
   ([aether_reactions_test.gd:178-194](tests/aether_reactions_test.gd#L178-L194),
   [:1011-1012](tests/aether_reactions_test.gd#L1011-L1012)). O guard mede só BT, sem
   percepção/utilidade ([wolf.gd:429-433](src/entities/wolf.gd#L429-L433)); isso não mede
   o HOT agregado dos cinco lobos nem fecha P1.
6. **Mudanças pequenas e atômicas.** Um assunto por commit e suíte verde entre eles, com a
   medição de cada um no próprio commit. O corte da revisão do golpe é o exemplo: o conserto do passo
   de golpe e a publicação do número do clone limpo são dois commits porque cada um tem uma
   corrida que lhe responde.
7. **Comentário explica o porquê, em português.** Nunca narrar o óbvio do código. Modelos
   reais: [smoke_test.gd:215-223](tests/smoke_test.gd#L215-L223) (por que o teste dá o `dt` e os
   passos ele mesmo) e o `GEN_VERSION` [world_gen.gd:6](src/world/world_gen.gd#L6), que faz o
   save velho ser recusado com mensagem em vez de lido torto
   ([main.gd:466-468](src/main.gd#L466-L468)).
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
([main.gd:154-160](src/main.gd#L154-L160) → `update_local`): lavra e colocação escrevem
voxels fora do tick ([player.gd:659](src/entities/player.gd#L659),
[:675](src/entities/player.gd#L675)) e seus sinais também imprimem no Éter
([main.gd:356-361](src/main.gd#L356-L361)). O lobo não é só 20 Hz:
`wolf._physics_process` locomove o corpo e reduz timers de cadáver, atordoamento e desvio
por frame ([wolf.gd:702-747](src/entities/wolf.gd#L702-L747)). Decisão de IA, difusão,
recolha de cadáveres e respawns são agendados pelo tick de 20 Hz, com cadências próprias
([main.gd:145-170](src/main.gd#L145-L170), [sim_clock.gd:5-7](src/core/sim_clock.gd#L5-L7)).
`begin_step`/`end_step` cronometra esse passo em microsegundos
([main.gd:158-160](src/main.gd#L158-L160), [sim_clock.gd:32-39](src/core/sim_clock.gd#L32-L39)),
incluindo o journal ativo. Regra de bolso: o que você coloca em `_sim_tick` divide 50 ms
com 5 lobos; o que coloca em `_physics_process` divide o frame com a renderização.

**Journal sob demanda, não gravação automática.** A CLI lê, após `--`,
`--tick-journal=path` ([main.gd:579-587](src/main.gd#L579-L587)). `start()` recusa caminho
existente: cada corrida exige arquivo novo explícito, sem reabrir histórico nem criar
arquivos automaticamente entre sessões ([tick_journal.gd:47-62](src/persistence/tick_journal.gd#L47-L62)).
`record()` acrescenta JSONL `[tick,hash]` com `flush` por linha; recusa tick negativo e,
após o primeiro registro, duplicata, regressão ou salto (exige `last_tick + 1`)
([tick_journal.gd:69-87](src/persistence/tick_journal.gd#L69-L87)). A chamada ocorre após
`clock.tick += 1`, **dentro** do cronômetro da simulação
([main.gd:183-189](src/main.gd#L183-L189)); sem o modo, o tick só consulta `active()`.
O load válido encerra o arquivo antes de restaurar o mundo
([main.gd:469-471](src/main.gd#L469-L471)); sair da cena também o fecha
([main.gd:589-590](src/main.gd#L589-L590)). O arquivo cresce apenas enquanto a gravação
explícita estiver ativa; não é journal de comandos nem mecanismo de replay.

**Orçamentos que já são código**, não intenção (regra 7):

| Orçamento | Valor hoje | Onde |
| --- | --- | --- |
| Passo de simulação | 50 ms (20 Hz), teto de 5 passos por frame; o que estourar vira `dropped_ticks` à vista | [sim_clock.gd:5-7](src/core/sim_clock.gd#L5-L7), [:19-29](src/core/sim_clock.gd#L19-L29) |
| Árvore de decisão, por lobo | 400 µs no `SubtreeGuard` (a default da classe é 250 µs); só BT, não percepção/utilidade | [bt_tree.gd:117-137](src/ai/behavior/bt_tree.gd#L117-L137), [wolf.gd:227-229](src/entities/wolf.gd#L227-L229) |
| Malha | 2 chunks por frame | [main.gd:13](src/main.gd#L13), usado em [:192-193](src/main.gd#L192-L193) |
| Difusão do Éter | 4 passadas por segundo, não 20 | [main.gd:12](src/main.gd#L12), [:166-168](src/main.gd#L166-L168) |
| Recolha de cadáver, visão do Éter | 1 s e 0,25 s | [main.gd:16](src/main.gd#L16), [:14](src/main.gd#L14) |

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
  ([wolf.gd:594](src/entities/wolf.gd#L594)): com a matilha inteira viva, 5 × 20 = 100
  dicionários por segundo (o `sim_step` retorna cedo em cadáver, então o número é teto
  derivado do código, não medição de alocação);
- a difusão aloca um `PackedInt32Array` por canal por passada
  ([aether_field.gd:122](src/world/aether_field.gd#L122)): 3 a cada 0,25 s;
- a conta das árvores (5 × 400 µs = 2 ms) cabe no teto de 2,5 ms que o gate de P1 ainda
  escreve como `[TARGET]` — e nenhum log mostra a soma real.

Essas alocações ainda não têm medição própria: os monitores do engine lidos são
`TIME_PROCESS` e `TIME_PHYSICS_PROCESS`, só no overlay F3
([hud.gd:244-247](src/ui/hud.gd#L244-L247)). Em headless, a suíte colhe o pior passo
(`worst_sim_ms`, vindo de `clock.worst_step_ms`) e `dropped_ticks` pelo `diagnostics()`
([main.gd:523-534](src/main.gd#L523-L534)). A colheita estreita de reações já separa
`sim_step` integral de BT, mas não mede alocações nem o HOT agregado dos cinco lobos.
Então o primeiro passo de qualquer otimização é a colheita, não o corte.

**Leitor de rastros: custo do scan medido por ablação; alocação continua sem medição.** Cada
scan percorre `7 × 7` células na camada Y do lobo: **49 × 3 leituras** `sample_cell`
(BLOOD/WORK/FEAR) por lobo, com seleção por `BLOOD + 0,35 × WORK`
([wolf.gd:462-506](src/entities/wolf.gd#L462-L506)). Se nenhuma célula da camada própria passa
de `SCENT_MIN`, o mesmo quadrado se repete na camada de cima e na de baixo — **98 leituras por
camada vizinha aberta** (dois canais, sem FEAR), 196 por scan quando as duas abrem. A cadência
é `0,25 s`, com rescan no tick seguinte à inspeção concluída
([:365-370](src/entities/wolf.gd#L365-L370),
[:409-447](src/entities/wolf.gd#L409-L447)); cinco lobos podem fazer o scan no mesmo tick.
O `sim_step` integral de 2 768 passos no cenário estreito mede **324 159 µs** com a camada
própria, **427 537 µs** com as três camadas incondicionais e **363 680 µs** com o gate pelo
nível próprio: o escalonamento corta 64 190 das 111 132 leituras extras (567 scans, 479
entradas de camada vizinha contra o máximo de 1 134). O chão do rastro não mede nada: trocar
`surface_height()` pela busca pelo sólido na mesma camada move o total em −1,8 % (324 159 →
318 171 µs) e nas três camadas em −1,5 % (434 052 → 427 537 µs), ambos dentro do ruído das
corridas repetidas do mesmo braço
([:689-697](src/entities/wolf.gd#L689-L697); [matriz de ablação, seis braços](docs/evidence/rastro-duas-camadas/readback.log)).
Isso não conta todo o `sim_step`: há ainda três amostras locais por tick e LOS quando
pode importar ([:597-606](src/entities/wolf.gd#L597-L606)). Ao concluir os `2 s` de
inspeção, a vizinhança `3 × 3` acrescenta até duas leituras por célula válida para
registrar a força ponderada no cache, limitado a **32 células por lobo**, com expiração
em `30 s` e renovação por aumento de pelo menos `0,06` ponderado
([:27-34](src/entities/wolf.gd#L27-L34), [:249-294](src/entities/wolf.gd#L249-L294),
[:669-670](src/entities/wolf.gd#L669-L670)). `keys()` aloca um Array por scan para
recolher expirados e também nas evicções ao atingir o teto
([:385-387](src/entities/wolf.gd#L385-L387), [:628-632](src/entities/wolf.gd#L628-L632)).
O cache transitório pertence ao lobo e é limpo no load
([:850-871](src/entities/wolf.gd#L850-L871)). Esses limites de cache e de alocação são
derivados do código: a ablação mede o scan, não a alocação total, e nada aqui fecha P1.

**Cópia de estado e custo observado:** com journal ativo, `state_bytes()` copia
32 × 16 × 32 × 3 × 4 = **196 608 bytes/tick** de Float32 (tamanho conferido pelo teste),
além dos arrays de edições, lobos vivos (hoje até 5 mentes) e crenças ordenados,
serialização, SHA256 e escrita com `flush`. Não é custo total de alocação medido.
O journal expõe `records`, `last_us`, `worst_us` e `total_us` (hash + escrita + flush
concluídos) em `diagnostics()["journal"]`
([tick_journal.gd:74-98](src/persistence/tick_journal.gd#L74-L98),
[main.gd:533](src/main.gd#L533)). No candidato histórico local recém-importado, anterior
ao refinamento dos rastros, 205 registros custaram 160 000 µs ao todo, com pico de
1 646 µs; o load encerrou a gravação. Os dois smokes, sem/com journal, terminaram sem
ticks perdidos, mas não são replay pareado, prova de otimização ou medição do lobo
refinado: [fontes e logs](docs/melhorias-status.md#notas-de-medição).

**LOD (regra 6) é parcial, e se diz assim:** existe *throttle temporal* por subsistema —
difusão e visualização do Éter 4×/s, cadáveres 1×/s; o leitor de rastros tem cadência de
`0,25 s` (com rescan após inspeção) e o registro de avistamentos, `2 s`
([wolf.gd:365-370](src/entities/wolf.gd#L365-L370), [:436-467](src/entities/wolf.gd#L436-L467)).
Isso não limita a LOS a 4×/s: ela é consultada a cada tick se o jogador está vivo e a
menos de 30 m. Não existe *LOD por distância*: os lobos vivos avaliam o BT a cada tick,
perto ou longe ([wolf.gd:409-433](src/entities/wolf.gd#L409-L433)). A peça do design é o
`HotSet`/Véu (§04, §06) e pertence a P2; antes de o custo aparecer em log, ela é backlog.

**Anti-bloat, com o estado real:**

- `main.gd` é o "objeto deus" conhecido — 501 linhas donas de mundo, relógio, matilha, HUD,
  oráculo, visualização, instância do journal e o nó de áudio ([main.gd:28-40](src/main.gd#L28-L40)). Isso está registrado como
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
[`tests/smoke_test.gd:799-809`](tests/smoke_test.gd#L799-L809) ("segurar break minerou", "tempo de
mineracao == dureza", "lavra entrou no inventario como drop"). Melhorar o que já passou no gate
continua vetado; o que entra é o buraco real: **nenhum bicho escreve no mundo hoje** — os únicos
dois `world.set_block` de gameplay são os do jogador (`:667`, `:693`).

A exceção de ordem registrada **antes** do código: as quatro linhas mexem todas em
`src/entities/wolf.gd` e em `src/main.gd`, que são de escritor único. Elas rodam **serializadas**
— uma branch fecha (merge + gate na `main` mergeda + publicação) antes da seguinte abrir — e a
ordem é 09 → 10 → 11 → 12, porque cor depende de bioma, cercar depende de quem mais existe na
matilha, acasalamento depende de dois adultos próximos, e cavar é folha da árvore já montada.

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
