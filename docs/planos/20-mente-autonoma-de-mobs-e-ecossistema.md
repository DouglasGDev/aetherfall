# 20 — Mentes autônomas de mobs e o mundo que respira sem input

Dossiê de **leitura de código**, não de corrida: nenhuma engine rodou aqui e nenhum número
publicado foi re-medido por este arquivo. Entra na fila porque o dono pediu a pauta em
2026-11-22 no prompt que ele mesmo chamou de "Prompt Master — Inteligência Autônoma de Mobs +
Ecossistema Vivo", e o registro vem **antes** de qualquer linha de código (mandato 4 de
[`AGENTS.md`](../../AGENTS.md)). A página foi **escrita** contra a `main` de `99d1167` e
**re-derivada** contra a `main` de `bb13752`, o registro do pouso da 16: os dois `arquivo:linha`
que carregavam a árvore antiga foram re-lidos no arquivo de hoje, e o resto fica da leitura
original porque os arquivos citados não mudaram. A re-derivação é obrigatória porque a 16
**escreveu código**: as árvores de `9b2c65a` são `git rev-parse 9b2c65a:src` =
`64f137bcb1f8e95bd9a64fe7843e4e7b72f7326e` e `:tests` = `88a1541c2f9f6fc3dd0e1d237b3e5656d9eea3c9`,
**diferentes** das do pin `5b519f8` (`30873d664a9577…` e `975eac5a471dc1…`) — a frase desta página,
antes, dizia que eram byte a byte iguais, e isso deixou de ser verdade. O contrato de referência
passa a ser o do pin `9b2c65a`: **255 / 0** na suíte e **240 / 0** no runner de reações. Esta
página continua sem pedir re-corrida, mas por outro motivo, e é ele que se confere: ela não toca
`src/` nem `tests/` — `git diff --name-only bb13752..HEAD -- src tests` devolve vazio —, então o
número do pin vale para a árvore resultante **por identidade de árvore**, não por medição nova.

Este é, de longe, o pedido mais largo já registrado: sete entregas (avaliação de alcance,
memória de falha, tabela de espécie, três grupos de criaturas novos, drops, troféu colocável e
os testes disso) tocando seis arquivos que a fila já escreve — `src/entities/wolf.gd`,
`src/main.gd`, `src/world/block_defs.gd`, `src/items/inventory.gd`, `src/ui/hud.gd` e, se a
metade sonora entrar, `src/audio/audio_director.gd`. O que esta página entrega, então, **não é
a lista de desejos**: é o corte. Cada §3 abaixo nomeia a decisão, o braço rejeitado e o número
que reabre o braço. Nada aqui foi escrito para agradar o prompt: três afirmações dele a leitura
devolve diferente (§9), e duas já foram pagas por pernas que pousaram.

**O que o prompt acerta, e é mais grave do que ele diz.** "Drops são fracos / inexistentes":
não são fracos — **não existem**. O `die()` do lobo ([wolf.gd:1312](../../src/entities/wolf.gd#L1312))
escreve BLOOD e FEAR no Éter ([`:1319-1320`](../../src/entities/wolf.gd#L1319-L1320)), arma o timer
de cadáver ([`:1321`](../../src/entities/wolf.gd#L1321), `const CORPSE_SECONDS: float = 6.0` em
[`:40`](../../src/entities/wolf.gd#L40)) e só **então** emite `died` ([`:1322`](../../src/entities/wolf.gd#L1322)).
O sinal tem **dois** consumidores em `src/`, e nenhum deles é um item: `_on_wolf_died`
([main.gd:415](../../src/main.gd#L415) conecta, corpo em [`:1015-1020`](../../src/main.gd#L1015-L1020)) faz
**uma** coisa — `stats["wolves_felled"] += 1` — e o diretor de áudio toca `wolf_died`
([audio_director.gd:161](../../src/audio/audio_director.gd#L161), corpo em
[` :412`](../../src/audio/audio_director.gd#L412)). É isso que o §3.8 cobra.

**O que o prompt pede e a árvore já entregou.** "Lobos presos diante de bloco" era a pauta da
**19**, que pousou: hoje o lobo salta contra obstáculo com `body.velocity.y = STEP_JUMP`
([wolf.gd:1247](../../src/entities/wolf.gd#L1247)), com `STEP_JUMP = 7.6` ([`:101`](../../src/entities/wolf.gd#L101))
e o ápice de 1,203 m **escrito no comentário de [`:97-100`](../../src/entities/wolf.gd#L97-L100)**;
e "variedade de vida pelo bioma" tem a metade de baixo pronta desde a **09** — `enum Biome`
([world_gen.gd:32](../../src/world/world_gen.gd#L32)) e `surface_block`
([`:165`](../../src/world/world_gen.gd#L165)) — que é exatamente onde a "preferência de habitat"
do §3.5 vai buscar o número em vez de inventar um campo.

## 1. Premissas nomeadas

**A. Um corpo que persegue sabe, por número, se a coluna à frente está dentro do seu ápice —
e quando não está, ele para de gastar salto.** Falsificável em headless: montar o jogador sobre
um plinto de duas células e exigir que o lobo (i) **não** dispare o impulso, (ii) conte as
tentativas que fez, (iii) escreva uma crença com o motivo, (iv) mude de estratégia visível em vez
de continuar empurrando a parede. O par anti-farsa (ciclo 3 do contrato) é o degrau de **uma**
célula, que a 19 já verdeou: se a aritmética nova recusar o que a 19 aceita, ela está errada, não
o cenário.

**B. Espécie só existe se muda um número observável por criatura.** Com duas espécies no mundo,
a tabela tem de decidir alcance, cadência, tentativas e drop — e nenhuma das duas pode ser "um
lobo com outro nome". Falsificável: o mesmo cenário com arquétipos diferentes tem de **divergir**
no número de saltos, no raio de fuga e no ledger de drop; se convergir, a tabela é enfeite.

**C. O leito sonoro de pássaro toca sem nenhuma criatura no mundo.** Medido, não lido:
`const AMBIENCE` mapeia `"open": "amb_birds"` ([audio_director.gd:101](../../src/audio/audio_director.gd#L101)),
a cama é escolhida por `_pick_ambience()` ([`:538`](../../src/audio/audio_director.gd#L538)) a cada
`AMBIENCE_PERIOD := 1.0` ([`:37`](../../src/audio/audio_director.gd#L37), aplicado em
[` :193-196`](../../src/audio/audio_director.gd#L193-L196)) e a proveniência é CC0 conferida por SHA
([`docs/audio-provenance.md:27`](../audio-provenance.md#L27), [`:98`](../audio-provenance.md#L98)).
Isto **não** é um defeito do tipo da 19: é uma cama de ambiência, correta como ambiência de campo
aberto. O que ela prova é que o mundo já **promete** céu vivo, e hoje `src/entities/` tem
[wolf.gd](../../src/entities/wolf.gd), [player.gd](../../src/entities/player.gd),
[player_avatar.gd](../../src/entities/player_avatar.gd),
[fp_viewmodel.gd](../../src/entities/fp_viewmodel.gd) e [voxel_body.gd](../../src/entities/voxel_body.gd)
— nenhuma ave, nenhum outro animal.

**D. Matar devolve algo para o inventário, e o que devolve é tabela, não sorteio escondido.**
Falsificável: N mortes de uma espécie produzem um ledger com contagem por item e a chance rara
impressa (não "caiu uma cabeça porque sim"). A premissa incômoda que o prompt não diz: hoje
**item é id de bloco** — `_ids := PackedInt32Array()` ([inventory.gd:29](../../src/items/inventory.gd#L29))
— e não existe entidade de item no chão; os comentários do próprio registro declaram isso
([player.gd:676](../../src/entities/player.gd#L676),
[inventory.gd:130](../../src/items/inventory.gd#L130)).

**E. A mente propõe, as regras dispõem — inclusive para as espécies novas.** Nenhuma decisão de
movimento, alcance, voo ou dano vem do oráculo; a única saída do `MindOracle` que chega a quem
age é narrativa (mandato 2). Falsificável sem tocar no oráculo: o mesmo cenário com o oráculo
nunca consultado devolve a **mesma** sequência de `intent`, e isso já é cobrado hoje porque
`intent` entra no hash do journal ([tick_journal.gd:35](../../src/persistence/tick_journal.gd#L35)).

## 2. Estado real do código (lido, não medido)

- **O pulo já existe e já é condicionado — mas por uma sonda binária, não por aritmética.** A
  árvore de decisão do lobo corre em `_physics_process`
  ([wolf.gd:1203](../../src/entities/wolf.gd#L1203)) e o ramo é `if body.blocked_horizontal and
  _unstick <= 0.0:` ([`:1239`](../../src/entities/wolf.gd#L1239)) → `if body.on_ground and
  body.can_step_over(want):` ([`:1245`](../../src/entities/wolf.gd#L1245)) → impulso
  ([`:1247`](../../src/entities/wolf.gd#L1247)). `can_step_over()`
  ([voxel_body.gd:176-181](../../src/entities/voxel_body.gd#L176-L181)) pergunta
  `can_stand_at(feet + (x, 1.0, z))` — altura **fixa de uma célula**, sem ápice, sem gravidade,
  sem `step_up`. O `STEP_JUMP` é 7,6 com gravidade 24
  ([voxel_body.gd:17](../../src/entities/voxel_body.gd#L17)), o que dá 1,203 m; `step_up` do
  integrador é 0,62 ([`:19`](../../src/entities/voxel_body.gd#L19)). Ou seja: hoje o lobo **acerta
  o degrau de um bloco e recusa parede de duas** — o que falta é a conta que generalize para
  qualquer corpo, mais a contagem de tentativas, mais a memória, mais a troca de estratégia.
- **Contador de tentativas: não existe.** `_unstick` ([wolf.gd:255](../../src/entities/wolf.gd#L255),
  decrementado por frame em [`:1227-1229`](../../src/entities/wolf.gd#L1227-L1229)) é um atraso
  anti-ritmo sorteado em [`:1240`](../../src/entities/wolf.gd#L1240), não uma memória de falha: não
  soma, não expira, não é lido por ninguém além do próprio ramo.
- **Crenças existem, e nenhuma delas é de alcance.** `Mind` tem `episodic`
  ([mind.gd:24](../../src/ai/mind.gd#L24), `beliefs` ([`:25`](../../src/ai/mind.gd#L25)) e
  `relations` ([`:26`](../../src/ai/mind.gd#L26)); o lobo grava `scent_blood`/`scent_work`
  ([wolf.gd:636](../../src/entities/wolf.gd#L636)), `hit_land` ([`:782`](../../src/entities/wolf.gd#L782)),
  `saw_player` ([`:952`](../../src/entities/wolf.gd#L952)), `hurt`
  ([`:1302`](../../src/entities/wolf.gd#L1302)), `win` ([`:1329`](../../src/entities/wolf.gd#L1329))
  e `fed` ([`:1334`](../../src/entities/wolf.gd#L1334)). Nenhum desses `kind` fala de altura nem de
  lugar impossível, e a chave `alvo_inalcancavel` do §3.3 não existe em `src/`.
- **Não há tabela de espécie nenhuma.** `SPECIES`, `archetype`, `species` dão **zero** ocorrências
  em `src/`. O que existe é a string `mind.kind = "wolf"` ([mind.gd:17](../../src/ai/mind.gd#L17)),
  semeada em `Mind.new("wolf", p_identity, 1000 + p_identity)`
  ([wolf.gd:313](../../src/entities/wolf.gd#L313)), e o comentário do motor de BT que **promete**
  a regra sem a implementar: "arvore instanciada por arquetype"
  ([bt_tree.gd:2](../../src/ai/behavior/bt_tree.gd#L2)). A promessa documentada está em
  [`docs/design/04-local-ai-architecture.md:44`](../design/04-local-ai-architecture.md#L44)
  ("Nós são instanciados por espécie/archetype, não por entidade") — esta página é a **primeira
  compradora** dela, e é por isso que a tabela entra aqui e não antes.
- **Personalidade já pondera, mas só dentro de quatro opções.** `_scorer.add_option` existe para
  `flee` ([wolf.gd:806](../../src/entities/wolf.gd#L806)), `hunt` ([`:818`](../../src/entities/wolf.gd#L818)),
  `investigate` ([`:844`](../../src/entities/wolf.gd#L844)) e `patrol`
  ([`:856`](../../src/entities/wolf.gd#L856)); a árvore tem seis Actions e seis Conditions
  construídas uma vez em `_build_tree()` ([`:422-450`](../../src/entities/wolf.gd#L422-L450)) e
  o orçamento é o `SubtreeGuard` de **400 µs** ([`:448-449`](../../src/entities/wolf.gd#L448-L449),
  classe em [bt_tree.gd:117](../../src/ai/behavior/bt_tree.gd#L117), default 250 µs em
  [`:120`](../../src/ai/behavior/bt_tree.gd#L120)). Cercar **não** é folha: sai de `_seat_point()`
  ([wolf.gd:548](../../src/entities/wolf.gd#L548)) dentro da perseguição
  ([`:503`](../../src/entities/wolf.gd#L503)) — o que importa para o §3.4, porque a "mudança de
  estratégia" pedida pelo prompt já tem onde morar.
- **Os insumos da aritmética de alcance já estão no código, lidos para outra coisa.** O topo da
  coluna é consultado por `world.gen.surface_height(...)` em
  [wolf.gd:416](../../src/entities/wolf.gd#L416), [`:684`](../../src/entities/wolf.gd#L684) e
  [`:733`](../../src/entities/wolf.gd#L733), com o aviso escrito em
  [`:1022`](../../src/entities/wolf.gd#L1022) de quando ele **não** serve; a visada custa e por isso
  é condicionada a 30 m ([`:922`](../../src/entities/wolf.gd#L922)). Não existe **pathfinding**
  nenhum: grep de `NavigationAgent` / A\* em `src/` devolve zero, e o comentário de
  [coords.gd:4](../../src/world/coords.gd#L4) diz que a rede e o pathfinding *vão* depender do
  sistema de coordenadas, não que dependem hoje. "Contornar", portanto, é steering + reeleição de
  alvo, não rota.
- **Censo e RNG da sessão são da matilha, e só dela.** `WOLF_COUNT := 5`
  ([main.gd:9](../../src/main.gd#L9)), `CENSUS_CAP := 12`
  ([`:18`](../../src/main.gd#L18)) com a conta da casa escrita no comentário de
  [`:10-17`](../../src/main.gd#L10-L17) — **12 × 400 µs = 4,8 ms dos 50 ms do passo** —, a fila de
  respawn `_respawn_queue` com `RESPAWN_DELAY := 45.0` ([`:30`](../../src/main.gd#L30)), o sorteio
  por `_population_rng` ([`:71`](../../src/main.gd#L71)), as bandas
  `SPAWN_BANDS` ([`:513`](../../src/main.gd#L523)) e o predicado `_spawn_point_ok()`
  ([`:725`](../../src/main.gd#L735)) com `SAFE_SPAWN_DIST := 32.0` ([`:24`](../../src/main.gd#L24)).
- **Desde a 16, a matilha tem toca — e isso muda o §3.9, não o resto.** O que não existia quando a
  página foi escrita e existe agora: `var _dens: Array = []` ([main.gd:116](../../src/main.gd#L116),
  "criada uma vez e só cresce"), `den_components()` ([`:635`](../../src/main.gd#L645)) exposto em
  `diagnostics()["den_components"]` ([`:1187`](../../src/main.gd#L1216)), o pedido de spawn carrying
  a toca (`_place_request(for_den)` [`:667`](../../src/main.gd#L677), `_entrada()`
  [`:704`](../../src/main.gd#L714)) e a pertença por entidade — `var den: int = -1`
  ([wolf.gd:186](../../src/entities/wolf.gd#L186)), gravado e lido no disco
  ([`:1372`](../../src/entities/wolf.gd#L1372), [`:1405`](../../src/entities/wolf.gd#L1405)). Consequência
  para esta perna: **espécie nova não pode herdar o censo da matilha por cima das tocas** — o teto de
  aves nasce ao lado de `_dens`, não dentro dele, e a `BIRD_CAP` do §3.6 é checada contra
  `den_components()` e não contra um número de lobos. Consequência para a leitura antiga: a mordaca
  `PACK_LEASH` de 18 m ([`:522`](../../src/main.gd#L532)) deixou de ter `_pack_leash()` como centro —
  a função não existe mais em `src/`, e o centro lido hoje é a própria entrada da toca.
- **Item é id de bloco, e o espaço livre do registro é conhecido.** `enum Block` cobre 0–8 e
  19–22 ([block_defs.gd:10-24](../../src/world/block_defs.gd#L10-L24)), `COUNT = 23`
  ([`:37`](../../src/world/block_defs.gd#L37)); ids **9–18 estão reservados por documento**, com
  nomes e tiles na tabela de [`docs/design/10:230-231`](../design/10-world-layers-and-block-physics.md#L230-L231)
  (DEEPSLATE 9, GRAVEL 10, LAVA 11, BEDROCK 12, POWDER_SNOW 13, ANVIL 14, ROCK_LOOSE 15,
  TORCH 16, PLANT 17, SLAB 18) — e a perna 18 é quem gasta o 17. Drop de criatura, se vier como
  bloco, **não pode** ocupar essa reserva: entra a partir de 23.
- **A forma de um item não-cúbico não existe.** A malharia emite cubos; o atlas é gerado por uma
  função por tile com `ATLAS_SEED = 20260116` ([voxel_atlas.gd:7](../../src/world/voxel_atlas.gd#L7),
  [`:14`](../../src/world/voxel_atlas.gd#L14)), e a tabela de shapes para poste/cruzeta está
  declarada `[OPEN]` no próprio doc
  ([`docs/design/10:218`](../design/10-world-layers-and-block-physics.md#L218)). É a mesma parede
  que o dossiê 18 já escreveu para o `PLANT`: ou o troféu é face Alpha num cubo registrado, ou a
  forma fica `[OPEN]` e dita.
- **O Éter tem três canais, e a morte já usa dois deles.** `enum Channel { WORK, BLOOD, FEAR,
  COUNT = 3 }` ([aether_field.gd:9](../../src/world/aether_field.gd#L9)); **canal de morte não
  existe** e é a pauta do dossiê 03. `EchoLedger`, que o prompt trata como peça a "registrar", é
  `[TARGET]` de P6: aparece em [`docs/design/02-innovations.md:22`](../design/02-innovations.md#L22)
  e [`:132`](../design/02-innovations.md#L132), zero ocorrências em `src/`.
- **O que muda sozinho hoje é o Éter e os corpos, não o mundo.** Difusão a 4 passadas/s
  (`AETHER_PERIOD := 0.25`, [main.gd:27](../../src/main.gd#L27)), recolha de cadáver 1×/s
  (`CORPSE_CHECK_PERIOD := 1.0`, [`:31`](../../src/main.gd#L31), corpo
  [`:909`](../../src/main.gd#L933)) e malha com `MESH_BUDGET := 2`
  ([`:28`](../../src/main.gd#L28), usado em [`:332`](../../src/main.gd#L337)). Nenhuma célula de
  mundo é escrita por criatura: os dois `set_block` de gameplay são os do jogador
  ([player.gd:685](../../src/entities/player.gd#L685), [`:711`](../../src/entities/player.gd#L711)).
- **O HotSet/LOD do doc 04 é alvo, não orçamento.** A escada HOT ≤48 / WARM ≤256 / AMBIENT ~2000
  está em [`docs/design/04:108-125`](../design/04-local-ai-architecture.md#L108-L125) e o corte por
  salience em [`:120`](../design/04-local-ai-architecture.md#L120); o `budget_governor.gd` que a
  seção nomeia não existe, e o contrato registra que **não há LOD por distância** — os lobos
  vivos avaliam a árvore a cada tick, perto ou longe. Quem paga o custo hoje é o teto de censo
  (12) e o `SubtreeGuard` de 400 µs.

## 3. O que a peça exige

### 3.1 O predicado de alcance, e onde ele mora

Exigência: uma função que responda, com número, "a coluna que eu quero alcançar está dentro do
que este corpo sobe?". Entradas que já existem: topo da coluna (`surface_height`), pés do corpo,
`STEP_JUMP`, gravidade do integrador e o `reach` derivado de `dims`
([voxel_body.gd:163](../../src/entities/voxel_body.gd#L163)). Saída: `alturas` (quantas células),
`apice` (m), e um booleano com folga de pouso explícita.

- **Braço A (escolhido primeiro): predicado nomeado dentro de `Wolf`** — `_reach_estimate()` —,
  consumido pelo ramo que já existe em [`:1239-1254`](../../src/entities/wolf.gd#L1239-L1254) no lugar
  da sonda fixa de `1.0`. Um comprador, zero arquivos novos.
- **Braço B: módulo reutilizável novo (`src/ai/reach.gd`) na primeira passada.** Rejeitado por
  regra da casa — *generalize no segundo chamador, não no primeiro*
  ([`AGENTS.md`](../../AGENTS.md), "Anti-bloat"). O prompt pedia o módulo primeiro; o que o
  contrato permite é o predicado, e ele sobe para o módulo **no commit da ave**, que é o segundo
  comprador real.
- **O número que reabre o B antes da ave:** se o mesmo predicado for chamado de dois corpos
  diferentes na mesma passada (lobo adulto e filhote com `PHASE_SCALE` 0,45
  [wolf.gd:89](../../src/entities/wolf.gd#L89) em corpos distintos), o segundo chamador já
  aconteceu e a extração é obrigatória — não adiada.

### 3.2 As três alturas, e o que a aritmética muda de fato

Hoje a sonda responde "cabe uma célula?" e o comentário sabe que o ápice é 1,203 m
([wolf.gd:97-100](../../src/entities/wolf.gd#L97-L100)). A aritmética não muda o degrau de 1 m —
a 19 já verdeou isso — e sim **três casos** que hoje são decisão por sorte de geometria:

1. **plinto de duas células** (2,00 m > 1,203 m): recusa calculada, sem impulso gasto;
2. **degrau com altura entre as duas** (talude com bloco solto a 1,5 m): hoje o `can_step_over`
   de `+1.0` devolve falso e o lobo **empurra a parede** sem nunca saber que não alcança;
3. **corpo menor** (filhote, ave em pouso): o `reach` muda com `dims`
   ([voxel_body.gd:163](../../src/entities/voxel_body.gd#L163)) mas a sonda não — e é isso que
   torna a conta dependente de espécie, não de lobo.

### 3.3 Tentativas, desistência legível e memória

- **Contador por alvo, não por corpo:** `_reach_tries` zera quando o alvo muda de coluna. Teto por
  arquétipo (lobo adulto: 3; criatura cautelosa: 1; curiosa: 5), lido de `personality`
  ([mind.gd:19-23](../../src/ai/mind.gd#L19-L23)) com os três eixos já sorteados da semente
  ([`:36-38`](../../src/ai/mind.gd#L36-L38)) — sem RNG nova, porque o riacho é um débito lido, não
  um convite.
- **Desistência escrita como crença**, não como log: `mind.beliefs` recebe a chave
  `"alvo_inalcancavel:<celula>"` com `confidence` e `source` — o formato já existe
  ([mind.gd:25](../../src/ai/mind.gd#L25)) e o journal já hashiza crenças ordenadas por chave
  ([tick_journal.gd:29-35](../../src/persistence/tick_journal.gd#L29-L35)). Isso é o que o prompt
  chama de "ali é alto demais", e é a única forma de ele sobreviver ao tick seguinte.
- **A crença tem de fechar o comportamento**, senão é decoração: com ela ativa, a *utilidade* de
  `hunt` contra aquele alvo cai — o que é um braço do §3.4, não um campo novo.

### 3.4 Troca de estratégia sem folha nova

O prompt lista "cercar, esperar, uivar para a alcateia". O que a árvore já faz: cercar
(`_seat_point` [wolf.gd:548](../../src/entities/wolf.gd#L548)), vir ao último avistamento
(`_leaf_stalk` [`:554`](../../src/entities/wolf.gd#L554)), seguir rastro
([`:567`](../../src/entities/wolf.gd#L567)) e patrulhar
([`:652`](../../src/entities/wolf.gd#L652)). Uivo existe como **som** (EVENTS `"howl"`
[audio_director.gd:59](../../src/audio/audio_director.gd#L59)) e como asset `wolf_howl.ogg`, mas
**não** existe como sinal de chamada entre lobos. Decisão escrita antes do código:

- **A (escolhido): reeleição de alvo pela utilidade**, sem `Selector` nova. A crença de
  inalcançabilidade entra como fator nas quatro opções existentes
  ([`:806`](../../src/entities/wolf.gd#L806), [`:818`](../../src/entities/wolf.gd#L818),
  [`:844`](../../src/entities/wolf.gd#L844), [`:856`](../../src/entities/wolf.gd#L856)) e o lobo
  passa de `hunt` para `stalk`/`patrol` **por número**, visível em `intent` — que é exatamente o
  campo que o journal hashiza, então a mudança é observável sem HUD.
- **B (não escolhido agora): o uivo como convocação** — custo: sinal novo entre lobos, e
  `intent` novo entra no hash. Só reabre com o A verde e o dono pedindo alcateia auditiva.

### 3.5 A tabela de espécie entra com o segundo comprador

`SpeciesDef` — nome da casa, no estilo de [`block_defs.gd:123-137`](../../src/world/block_defs.gd#L123-L137)
e [`recipes.gd:31-43`](../../src/items/recipes.gd#L31-L43): dados construídos **uma vez**, nomes e
propriedades em código, sem arquivo `.tres` novo. Campos, todos derivados do que a árvore já
lida:

| Campo | De onde sai hoje |
|---|---|
| `dims`, `speed`, `step_jump`, `apice` | `DIMS` [wolf.gd:96](../../src/entities/wolf.gd#L96), `STEP_JUMP` [`:101`](../../src/entities/wolf.gd#L101), gravidade [voxel_body.gd:17](../../src/entities/voxel_body.gd#L17) |
| `reach`, altura da sonda | `reach` [voxel_body.gd:163](../../src/entities/voxel_body.gd#L163) |
| `tries`, `cautela` | `personality` [mind.gd:19-23](../../src/ai/mind.gd#L19-L23) |
| `habitat` | `biome_of` [world_gen.gd:129](../../src/world/world_gen.gd#L129), `surface_block` [`:165`](../../src/world/world_gen.gd#L165) |
| `drops` | nada — é o §3.8 |
| flags `voa`/`nada`/`pousa`/`foge_de_humano` | nado do lobo existe ([wolf.gd:1216-1217](../../src/entities/wolf.gd#L1216-L1217), `SWIM_RISE` [`:147`](../../src/entities/wolf.gd#L147)); voo não existe em lugar nenhum |

A regra de instanciação é a do doc 04 [`:44`](../design/04-local-ai-architecture.md#L44): a
**árvore é por arquétipo**, o estado é por entidade. Medir isso é o gate
`arvore_por_arquetype` do §5 — contar nós criados por spawn contra nós criados por tick, porque
o `Dictionary` do blackboard já é alocado por lobo por tick
([wolf.gd:911](../../src/entities/wolf.gd#L911)) e é justamente o débito que o contrato registra.

### 3.6 Aves: bando com teto, mente só quando acorda

- **Teto numérico antes de qualquer folha:** o passo de simulação divide 50 ms
  ([sim_clock.gd:5-7](../../src/core/sim_clock.gd#L5-L7)) e a conta da casa é 12 mentes × 400 µs =
  4,8 ms ([main.gd:10-17](../../src/main.gd#L10-L17)). Um bando de 24 aves rodando BT + utilidade
  **dobraria a soma com o censo de lobos parado**. A decisão é explícita: ave fora do horizonte
  corre **steering apenas**, sem `_tree.tick`, sem `_scorer`; dentro do horizonte (o mesmo 30 m já
  usado na visada, [wolf.gd:922](../../src/entities/wolf.gd#L922)) acorda e passa a ter mente. Isso
  é o HotSet do doc 04 [`:108-125`](../design/04-local-ai-architecture.md#L108-L125) **em versão
  mínima e com número**, não o HotSet prometido — o agregado continua `[TARGET]` e pertence ao
  dossiê 04.
- **Voo não é física nova:** corpo no chão existe; nada voa. `voa` quer dizer "y alvo acima do
  topo da coluna + altura de voo, sem colisão de apoio" e é decidido no §3.6.a com a checagem
  `passaro_nao_anda_no_chao`. Sem gravidade própria por corpo, a ave é um corpo que cai — então o
  caminho mínimo é a ave não usar `VoxelBody` no ar, e isso **tem de ser dito antes**, não depois
  de ver a galinha quicando.
- **Pouso:** `LEAVES` é id 7 ([block_defs.gd:18](../../src/world/block_defs.gd#L18)) e a copa é
  gerada; o poleiro é uma célula de `LEAVES` lida, não um ponto sorteado no ar.
- **Som:** não há asset de vocalização de ave. `assets/audio/sfx/` tem passo, lavra, quebra,
  colocação, `hit_flesh`, `splash`, `swing`, `ui` e o conjunto de lobo; o único pássaro do
  repositório é a **cama** `amb_birds` ([`docs/audio-provenance.md:98`](../audio-provenance.md#L98)).
  Ave que chia exige compra CC0 com SHA no registro de proveniência e ganho medido em
  `assets/audio/levels.json` (mandato 8) — **não é decisão de código** e por isso a metade sonora
  da entrega fica `[OPEN]` nesta pauta. O que a ave entrega **agora** é presença, voo, fuga e
  drop; o silêncio dela é honesto, o som inventado não seria.

### 3.7 Itens: ou o registro ganha ids, ou o inventário ganha um tipo

- **Braço A (escolhido primeiro): ids novos a partir de 23** — `MEAT`, `FEATHER`,
  `FEATHER_COLOR`, `HEAD_WOLF`, `HEAD_CHICKEN`, `HEAD_DUCK` —, com as sete tabelas do registro
  preenchidas (`hardness`, `drop_of`, `display_name`, `tile_for`, `stack_max`, `is_solid`,
  `swatch`). Vem com a propriedade que o prompt quer de graça: **é colocável**, porque colocar é
  `set_block` do slot selecionado ([player.gd:711](../../src/entities/player.gd#L711)). Custo
  declarado: um bife no mundo é um cubo de 1 m, e a forma correta depende da tabela de shapes
  `[OPEN]` do doc 10 [`:218`](../design/10-world-layers-and-block-physics.md#L218) — então
  `is_solid` falso + face Alpha é o máximo honesto, e o tile novo entra **por último** no atlas,
  senão o `ATLAS_SEED` compartilhado ([voxel_atlas.gd:7](../../src/world/voxel_atlas.gd#L7))
  reescreve os tiles pinados das capturas.
- **Braço B (rejeitado agora): tipo de item fora do mundo.** Custo: `inventory.gd` inteiro troca
  a identidade de `int` para uma chave própria, `kit_counts()` ([inventory.gd:51](../../src/items/inventory.gd#L51))
  muda, o HUD e o painel de craft mudam, e a chave do save muda de forma — `FORMAT_VERSION`
  ([tick_journal.gd:4](../../src/persistence/tick_journal.gd#L4)) é conversa de versão, não de
  implementação. Reabre **só** se o dono pedir item que não é lugar-none no mundo (poção, semente,
  comida que se come com `hp`), que é um comprador novo, não este.
- **O número que decide A vs B** está no §5: se com A o item colocado no chão **bloqueia o
  clique** ou vira apoio de passo (o `can_step_over` do §3.2 enxergando um bife como parede), A
  está errado e a forma vai para `[OPEN]` explícito, não para B silencioso.

### 3.8 Drops: direto no inventário, sem entidade no chão

- **Braço A (escolhido): a morte escreve no inventário de quem matou**, do mesmo jeito que a
  lavra já faz — `drop := BlockDefs.drop_of(b)` e `inv.add(drop, 1)`
  ([player.gd:679](../../src/entities/player.gd#L679), [`:688`](../../src/entities/player.gd#L688))
  — com a recusa de espaço existing (`space_for` [inventory.gd:132](../../src/items/inventory.gd#L132))
  e o "não coube" **impresso**, não perdido: os comentários de
  [player.gd:303](../../src/entities/player.gd#L303) e
  [inventory.gd:130](../../src/items/inventory.gd#L130) são a casa dizendo que hoje o que não coube
  simplesmente fica no lugar.
- **Braço B: `DropItem` no mundo** (entidade física, coleta por proximidade, persistência no
  save). Rejeitado porque nada no pedido depende dele, e porque introduz estado de mundo novo sem
  gate — e o mundo que muda sozinho é a pauta das pernas 17/18, que já têm fila própria.
- A tabela pedida pelo prompt, com os números escritos **antes** do sorteio: lobo → 1–2 `MEAT` +
  2 % `HEAD_WOLF`; galinha → 1 `MEAT` + 2–3 `FEATHER` + 1 % `HEAD_CHICKEN`; pato → 1 `MEAT` +
  2–4 `FEATHER`; ave → 1–2 `FEATHER`/`FEATHER_COLOR` + 0,5 % cabeça. Chance rara **com semente**:
  o sorteio usa o riacho do próprio lobo/espécie, nunca `_population_rng`
  ([main.gd:81](../../src/main.gd#L81)) — a checagem `drop_nao_consome_rng_da_sessao` existe por
  isso, e o riacho novo é contado em `tests/simulation_rng_test.gd`.

### 3.9 Censo, respawn e a matilha não podem ser compartilhados

A fila de respawn, o teto e as bandas do §2 são da matilha. Se a ave entrar por cima deles, três
checagens publicadas param de dizer o que dizem (censo, spawn seguro, convivência). Decisão:
**as aves têm censo próprio** (`BIRD_CAP`, número do §4) e **não** tocam `_respawn_queue` nem
`_population_rng`; o lobo continua as 5–12 mentes que o contrato já soma. Consequência honesta:
o F3 e o `diagnostics()` ([main.gd:1205](../../src/main.gd#L1205)) passam a ter de dizer quantos
lobos e quantas aves — separados, nunca um `animals` único, que é o jeito como um censo compartilhado
vira mentira.

### 3.10 Éter e journal: o que não se mexe, e o que muda sozinho

- **Nenhum canal novo.** A morte já imprinta BLOOD+FEAR
  ([wolf.gd:1319-1320](../../src/entities/wolf.gd#L1319-L1320)); canal de morte é o dossiê 03 e
  `Channel.COUNT` ([aether_field.gd:9](../../src/world/aether_field.gd#L9)) entra no hash
  ([tick_journal.gd:16-44](../../src/persistence/tick_journal.gd#L16-L44)). Esta perna **não**
  encosta em `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` nem na projeção do journal.
- **O que muda sem ninguém querer:** a projeção hashiza os vivos ordenados por `identity` com
  `mind.identity`, `mind.kind`, `intent` e crenças
  ([tick_journal.gd:26](../../src/persistence/tick_journal.gd#L26),
  [`:35`](../../src/persistence/tick_journal.gd#L35)). Então qualquer `kind` novo, qualquer
  `intent` novo (voar, pousar, pastar) e qualquer crença nova **mudem os hashes de uma corrida
  com a árvore nova** — não porque a projeção mudou, mas porque o estado mudou. As checagens que
  juram hash inalterado *sem escolha nenhuma* (`journal_hash_inalterado_sem_escolha`, da 11) continuam
  valendo pelo que dizem: com zero aves e zero crença de alcance, o hash é o mesmo.

## 4. Custo — as quatro perguntas

- **Roda por frame, por tick ou às vezes?** A decisão de alcance: no **ramo de frame** que já
  existe ([wolf.gd:1239-1254](../../src/entities/wolf.gd#L1239-L1254)), então é uma leitura de coluna
  por tentativa, não por tick. A mente das aves: no **tick de 20 Hz** (50 ms divididos
  — [sim_clock.gd:5-7](../../src/core/sim_clock.gd#L5-L7)) **só dentro do horizonte**; fora dele,
  steering de frame. A crença de inalcançabilidade: escrita uma vez por alvo perdido, lida pela
  utilidade no mesmo tick.
- **Quantas entidades são alcançadas?** Hoje: 5 lobos no boot (`WOLF_COUNT`
  [main.gd:9](../../src/main.gd#L9)) com teto de 12 ([`:18`](../../src/main.gd#L18)). A soma nova
  é o teto de aves, e ele **nasce da régua, não do gosto**: `BIRD_CAP` só é aprovado com o
  `worst_sim_ms` do lote ao lado do `worst_sim_ms` do mesmo cenário com as aves desligadas, e com
  `dropped_ticks == 0` nos dois. O número da casa que limita a conversa é 4,8 ms das 12 mentes
  ([`:10-17`](../../src/main.gd#L10-L17)) — aves não podem empurrar a soma para fora do passo.
- **Aloco no caminho quente?** A tabela de espécies: construída **uma vez**, no padrão do registro
  ([block_defs.gd:123-137](../../src/world/block_defs.gd#L123-L137)). A árvore por arquétipo:
  construída no spawn, nunca por tick — e isso é checagem (`arvore_por_arquetype`), não intenção,
  porque o `Dictionary` do blackboard já aloca por mente por tick
  ([wolf.gd:911](../../src/entities/wolf.gd#L911)) e é débito declarado no contrato. O ledger de
  drop: um `Dictionary` por morte, fora do caminho quente.
- **Como sei que ficou melhor — e o log existe?** Não existe log dessa régua ainda, então o
  primeiro passo da perna é **colheita**: contar por espécie decisões/tick, µs de árvore por
  arquétipo (o `tree_stats()` [wolf.gd:1356](../../src/entities/wolf.gd#L1356) já imprime µs e
  estouros, hoje só para o lobo), tentativas de alcance e drops por corrida, em headless. Só
  depois disso o corte de quem voa é discutível. Pedir "otimizar o voo" sem esse número é o que o
  terceiro mandato recusa.

## 5. Gate em headless

```sh
godot --headless --path . --check-only --script src/entities/wolf.gd
godot --headless --path . --script tests/aether_reactions_test.gd
godot --headless --path . tests/smoke_test.tscn
```

1. **`alcance_calcula_altura`** — nasce **vermelho**: plinto de 2 células com o jogador em cima;
   exige `saltos_gastos == 0` **e** a linha impressa com `apice=1,203 m` contra `altura=2,00 m`.
   A sonda atual de `+1.0` ([voxel_body.gd:176-181](../../src/entities/voxel_body.gd#L176-L181))
   recusa por geometria e **não** por conta, então a checagem pede o número, não o booleano.
2. **`degrau_de_um_bloco_continua_subindo`** — o par anti-farsa: a mesma cena da 19 com uma
   célula, verde e indisponível a regredir. Se 1 verdear e 2 vermelho, a aritmética está errada.
3. **`tentativas_ate_desistir`** — imprime `tentativas`, `teto_por_arquetype` e o tick em que a
   desistência aconteceu; o teto vem da tabela, não de um literal do ramo.
4. **`desistencia_vira_crenca`** — a chave de crença existe em `mind.beliefs` com
   `confidence`/`source` ([mind.gd:25](../../src/ai/mind.gd#L25)) e sobrevive ao tick seguinte
   (a memória é lida, não reescrita).
5. **`desistir_nao_e_empurrar_parede`** — depois de desistir, `blocked_horizontal` não pode
   acontecer mais que K vezes em 200 ticks **com o mesmo alvo**; imprime os dois contadores. É a
   checagem que o furo #18 ensinou: recusa sem número é recusa muda.
6. **`estrategia_muda_por_numero`** — distribuição de `intent` antes/depois da desistência, com o
   `hunt → stalk/patrol` visível. `intent` é campo hashiado
   ([tick_journal.gd:35](../../src/persistence/tick_journal.gd#L35)), então a mudança é medida pelo
   journal, não por log de conveniência.
7. **`especie_decide_numero`** — nasce **vermelho** (não existe segunda espécie): dois arquétipos
   no mesmo cenário, exigindo `saltos`, `raio_fuga` e `drops` **diferentes**. Convergir = tabela
   decorativa.
8. **`arvore_por_arquetype`** — conta nós de BT criados no spawn contra criados no tick; o teto
   do segundo é **zero**. Referencia o `Dictionary` por tick já registrado
   ([wolf.gd:911](../../src/entities/wolf.gd#L911)) como o que não se pode repetir.
9. **`passaro_nao_anda_no_chao`** e **`passaro_pousa_em_copa`** — `y` médio acima do topo da
   coluna (`surface_height` [world_gen.gd:94](../../src/world/world_gen.gd#L94) como régua de
   chão) e o poleiro é célula de `LEAVES` id 7.
10. **`passaro_foge_na_aproximacao`** — distância em que a fuga dispara, impressa ao lado dos
    30 m da visada ([wolf.gd:922](../../src/entities/wolf.gd#L922)); o número é da tabela, não do
    `if`.
11. **`bando_tem_teto_e_o_passo_caibo`** — `worst_sim_ms` e `dropped_ticks` com `BIRD_CAP` aves
    vs as mesmas aves desligadas, na mesma semente; critério escrito antes da corrida:
    `dropped_ticks == 0` e a soma das árvores dentro do que o teto de 12 mentes já compromete
    ([main.gd:10-17](../../src/main.gd#L10-L17)).
12. **`lobo_morto_dropa_carne`** — nasce **vermelho contra a árvore de hoje** (zero drop em
    [`:991`](../../src/main.gd#L1015)): N mortes produzem o ledger impresso, com a recusa de espaço
    contando junto (`space_for` [inventory.gd:132](../../src/items/inventory.gd#L132)).
13. **`trofeu_e_colocavel_e_nao_e_ancora`** — a cabeça colocada vira célula no mundo
    ([player.gd:711](../../src/entities/player.gd#L711)), **não** é sólida, **não** entra em lista
    de gravidade nem em substrato de crescimento (cláusula que protege as pernas 17/18), e o
    `can_step_over` do lobo não pode ler um bife ou um troféu como parede. Paga o número do §3.7.
14. **`drop_nao_consome_rng_da_sessao`** — o riacho novo não toca `_population_rng`
    ([main.gd:81](../../src/main.gd#L81)); a mesma semente devolve a mesma sequência de spawns já
    conferida por `tests/simulation_rng_test.gd`.
15. **`aves_nao_movem_o_censo_da_matilha`** — `WOLF_COUNT`, `CENSUS_CAP` e as contagens publicadas
    da matilha inalterados com aves vivas no mapa, e `diagnostics()`
    ([main.gd:1205](../../src/main.gd#L1205)) dizendo lobos e aves **separados**.
16. **`decisao_nao_vem_do_oraculo`** — o cenário de alcance rodado com o oráculo nunca consultado
    devolve a mesma sequência de `intent` (mandato 2; a cena de prova do oráculo é própria,
    `tests/live_oracle_probe.tscn`, e não entra aqui).
17. **`journal_hash_inalterado_sem_especies_vivas`** — com aves fora do cenário e nenhuma crença
    de alcance, os hashes do lote anterior se reproduzem; com aves vivas, a checagem **declara** a
    divergência em vez de escondê-la (§3.10).
18. `EXPECTED_CHECKS` ([aether_reactions_test.gd:64](../../tests/aether_reactions_test.gd#L64),
    **240** nesta leitura — a 16 subiu o censo de 225 para 240 e moveu a constante da linha 34 para a
    39) e o censo do runner
    ([`:3124`](../../tests/aether_reactions_test.gd#L3161)) sobem com o lote, e o `EXPECTED_CHECKS`
    do áudio ([audio_test.gd:25](../../tests/audio_test.gd#L25), **73**) só se a metade sonora for
    aprovada com asset novo.

## 6. O que NÃO fazer

- **Nenhum `Channel.COUNT`, `FORMAT_VERSION` ou `GEN_VERSION`**
  ([aether_field.gd:9](../../src/world/aether_field.gd#L9),
  [tick_journal.gd:4](../../src/persistence/tick_journal.gd#L4),
  [world_gen.gd:6](../../src/world/world_gen.gd#L6)). Canal de morte é dossiê 03; árvore de
  parentesco é 13, que é última por causa disso.
- **Nada de LLM ou oráculo em movimento, alcance, voo, dano ou drop** — mandato 2, inegociável
  aqui e em qualquer espécie nova.
- **Nenhum `DropItem` no mundo nesta perna** (§3.8 B) e **nenhum tipo de item paralelo**
  (§3.7 B) sem o comprador que o justifique.
- **Nenhuma varredura de mapa para bando, poleiro ou habitat.** Habitat é `biome_of` lido pela
  coluna do ponto sorteado, não uma passada no mundo.
- **Nenhuma rota/A\* nova**: não existe pathfinding em `src/` (§2) e "contornar" é reeleição de
  alvo. Introduzir um navmesh aqui seria escopo de outra linha inteira.
- **Nenhuma facção humana, NPC, aldeia, domesticação ou "parede de troféus" como sistema** — o
  próprio prompt adiaria isso; aqui o troféu é item colocável, e a decoração com lógica é
  `[TARGET]`.
- **Nenhum som de criatura sem asset CC0 comprado, com SHA na proveniência e ganho em
  `levels.json`** (mandato 8; `docs/audio-provenance.md` é o registro). E nenhum asset do Veloren,
  que tem 645 arquivos de áudio sob GPL-3.0.
- **Não subir `MESH_BUDGET` ([main.gd:28](../../src/main.gd#L28)), o teto do `SubtreeGuard`
  ([wolf.gd:448-449](../../src/entities/wolf.gd#L448-L449)) nem o `CENSUS_CAP`
  ([`:18`](../../src/main.gd#L18)) para acomodar as aves.** Se o número não cabe, o que desce é
  `BIRD_CAP`.
- **Não transladar os ids reservados 9–18** do doc 10
  ([`:230-231`](../design/10-world-layers-and-block-physics.md#L230-L231)) — drop de criatura
  começa em 23, e o 17 já é da perna 18.
- **Não inserir tile no meio do atlas** ([voxel_atlas.gd:7](../../src/world/voxel_atlas.gd#L7),
  [`:14`](../../src/world/voxel_atlas.gd#L14)): por último, ou as capturas pinadas deixam de ser a
  mesma imagem.

## 7. Commits atômicos

Um assunto por commit, suíte verde entre eles, número no commit a que ele responde.

(a) Colheita: contadores por espécie/decisão e a publicação do `worst_sim_ms` de referência — sem
peça nova de gameplay; (b) §3.1 + §3.2 com 1, 2 e o predicado `_reach_estimate()` dentro do
lobo; (c) §3.3 com 3 e 4; (d) §3.4 com 5 e 6; (e) a tabela do §3.5 **com o segundo comprador
real** (a ave), mais 7 e 8; (f) aves do §3.6 com 9, 10 e 11; (g) itens do §3.7 com ids ≥ 23 e o
registro completo, mais 13; (h) drops do §3.8 com 12 e 14; (i) censo separado do §3.9 com 15;
(j) a recusa-de-espelho do §3.10 com 16 e 17; (k) status, `README.md`, índice de `docs/planos/` e
evidência em `docs/evidence/mobs-autonomos-20/` — a mesma pasta em que esta rodada de documento já
arquivou as três réguas (`ruler_plan_cites.log`, `ruler_plan_ids.log`, `ruler_doc_anchors.log` e o
`artifacts.sha256` conferido por `sha256sum -c`), no padrão das pernas pousadas: uma pasta por linha
de história, não uma por commit.

Branch `feat/mobs-autonomos-e-ecossistema-20`, base `main` no ponto atual, merge `--no-ff`. Dono:
o agente **`mente-eco-20`**. O dossiê 13 ("todo ser vivo") re-ancora a premissa de espécie única
dele quando a vez dele chegar — é por isso que 13 continua último.

## 8. O que este dossiê não fecha

Nenhum gate de fase (mandato 4). Não é o HotSet do doc 04
([`:108-125`](../design/04-local-ai-architecture.md#L108-L125)) — é um teto por espécie com número,
e o agregado continua `[TARGET]` do dossiê 04. Não é `EchoLedger` (P6, `[TARGET]` em
[`docs/design/02:22`](../design/02-innovations.md#L22)), não é canal de morte (03), não é
parentesco (13), não é pathfinding, não é domesticação, não é NPC humano, não é vocalização de ave.
Não re-mede nenhum número publicado: o contrato de referência é o do pin `9b2c65a` — **255 / 0** na
suíte e **240 / 0** no runner de reações, medidos no clone limpo e na `main` mergida pela perna 16 —
e esta página chega a ele **por identidade de árvore**, não por corrida: `src/` e `tests/` da ponta
desta branch são os do pin, o que se confere com `git diff --name-only 9b2c65a..HEAD -- src tests`
vazio. O **252 / 0 / 42,4 s** do `5b519f8` que esta página citava é o contrato da árvore **anterior**
à 16: continua verdade histórica, deixou de ser o número da `main`.

## 9. Invenções do prompt, registradas aqui

- **"Não calcula se consegue alcançar com pulo"** — pela metade. O pulo existe, é condicionado a
  `on_ground and can_step_over(want)` ([wolf.gd:1246-1247](../../src/entities/wolf.gd#L1246-L1247)) e
  a 19 verdeou o degrau de um bloco. O que **não** existe é a aritmética (a sonda é `+1.0` fixo,
  [voxel_body.gd:181](../../src/entities/voxel_body.gd#L181)), o contador de tentativas, a
  desistência e a memória — e é isso que a página cobra, não o pulo.
- **"Drops são fracos"** — são **zero**: dos dois consumidores de `died`, um só incrementa contador
  ([main.gd:1015](../../src/main.gd#L1015)) e o outro só toca um som
  ([audio_director.gd:412](../../src/audio/audio_director.gd#L412)); nenhum escreve no inventário.
- **"Drops como carne, pena e troféu"** — não há item fora de id de bloco: `item == bloco`
  ([inventory.gd:29](../../src/items/inventory.gd#L29)) e os grep de `MEAT`, `FEATHER`, `feather`,
  `carne` e `trophy` em `src/` devolvem **zero**. As outras duas palavras do prompt só aparecem
  coladas em outra coisa — `pena` dentro de "apenas" (4 ocorrências) e `cabeca` em texto de prompt,
  cabeçalho HTTP e comentário de anatomia/câmera (5) — e nenhuma delas é item. Vira ids 23+ ou
  `[OPEN]` de forma, com o braço B do §3.7 registrado como o que seria preciso pagar.
- **"Registrar no Éter / `EchoLedger` a morte (já é o espírito do projeto)"** — o registro já é
  código: BLOOD 1,1 + FEAR 0,55 ([wolf.gd:1319-1320](../../src/entities/wolf.gd#L1319-L1320)).
  `EchoLedger` não existe em `src/` e é `[TARGET]`
  ([`docs/design/02:132`](../design/02-innovations.md#L132)); canal de morte é o dossiê 03, e esta
  perna não o toca.
- **"Respeitar o HotSet/LOD já previsto no doc 04"** — previsto, sim; em código, não. O contrato
  registra "não existe LOD por distância" e os orçamentos que são código hoje são o passo de
  50 ms ([sim_clock.gd:5-7](../../src/core/sim_clock.gd#L5-L7)), o `SubtreeGuard` de 400 µs
  ([wolf.gd:448-449](../../src/entities/wolf.gd#L448-L449)) e o teto de 12 mentes cujo produto já
  está escrito no comentário de [main.gd:10-17](../../src/main.gd#L10-L17).
- **"Já existe som de pássaros, então a imersão está quebrada"** — o som existe
  ([audio_director.gd:101](../../src/audio/audio_director.gd#L101),
  [`docs/audio-provenance.md:98`](../audio-provenance.md#L98)) e é **cama de ambiência**, escolhida
  pela regra `"open"` a cada 1 s — não um evento de criatura. É contexto legítimo para priorizar
  a ave, mas não é o tipo de defeito em execução que furou a fila para a 19, e por isso a 20
  **não** fura a fila.
- **"BT compartilhado por arquétipo, estado no Blackboard/Mind"** — é a regra documentada do doc 04
  [`:44`](../design/04-local-ai-architecture.md#L44) e o comentário de
  [bt_tree.gd:2](../../src/ai/behavior/bt_tree.gd#L2), e é por isso que a tabela do §3.5 entra com
  esta perna: ela é a primeira compradora. Não é peça a "ligar", é peça a escrever.
- **"O mundo ainda não respira sozinho"** — verdade sobre o **mundo de blocos** (só o jogador
  escreve: [player.gd:685](../../src/entities/player.gd#L685),
  [`:711`](../../src/entities/player.gd#L711)), falsa sobre o Éter, que difunde 4×/s
  ([main.gd:27](../../src/main.gd#L27)) e sobre os corpos, que são recolhidos 1×/s
  ([`:31`](../../src/main.gd#L31), [`:909`](../../src/main.gd#L933)). O que falta respirar é vida
  com input zero, e é isso — e só isso — que a pauta compra.

**Nenhuma linha de código desta perna foi escrita e a branch não abre agora:** a fila serializada
([`AGENTS.md`](../../AGENTS.md), "Escopo autorizado agora") tem a 16 **pousada** — `9b2c65a`, registro
`bb13752` — e o elo aberto seguinte é a 12, com a 17 e a 18 antes desta. A fila completa, com os
pousos já cumpridos, é **09 → 10 → 15 → 14 → 11 → 19 → 16 ✅ → 12 → 17 → 18 → 20 → 13**; a fila
**restante** de hoje é **12 → 17 → 18 → 20 → 13**. Duas branches abertas em `src/entities/wolf.gd` é
o incidente do dossiê 03, que apagou uma versão já conferida.
