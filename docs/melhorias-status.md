# Melhorias — status real

Arquivo de trabalho. **Não é design**: cada linha abaixo ou cita código que existe, ou
cita um log medido, ou declara explicitamente que não existe ainda. A fonte das cobranças
são três prompts que se completam, todos com as afirmações de estado conferidas aqui e o
comportamento prescrito em [`AGENTS.md`](../AGENTS.md) (raiz): o "Prompt Master de Correção
de Furos e Fechamento de Gates", que diz *o que falta*; as "Instruções de Trabalho
(obrigatórias)", que dizem *como* mexer; e a "Disciplina de Otimização e Controle de
Crescimento", que diz *quanto custa*. Este arquivo tem uma tabela por prompt, na mesma
ordem.

Revisão de referência: `9c6b722` — a premissa montada no passo de golpe (furo #6 abaixo).
Motor: Godot 4.7.2-stable (`ed1daf0bf`), Vulkan Forward+, AMD Radeon RX 9060 XT.

## Os prompts × o código

### O prompt master de furos e gates × o código

| O que o prompt afirma | O que está em `src/` hoje | Veredicto |
|---|---|---|
| "AetherField de **6 canais** (trabalho, sangue, medo, morte, som, fogo)" | 3 canais: `enum Channel { WORK, BLOOD, FEAR, COUNT }` com `HALF_LIFE = [90, 55, 120]` e `DIFFUSE_RATE = [0.06, 0.16, 0.10]` — [aether_field.gd:9-15](../src/world/aether_field.gd#L9-L15). A `CHANNEL_COLOR` da visualização também tem 3 entradas — [aether_viz.gd:12-16](../src/rendering/aether_viz.gd#L12-L16) | **falso hoje**; é meta de P1 (§08 linha "falta") |
| "`MindStore` + consolidação" | A **consolidação já existe** dentro de `Mind`: ao estourar `EPISODIC_CAP = 24` o átomo mais velho sai da fila e vira reforço de crença, com contador persistido — [mind.gd:7](../src/ai/mind.gd#L7), [:44-45](../src/ai/mind.gd#L44-L45), `:_consolidate` em [:61-68](../src/ai/mind.gd#L61-L68), save/load em [:148](../src/ai/mind.gd#L148) e [:157](../src/ai/mind.gd#L157). Não há tipo `MindStore` (grep em `src/`: zero ocorrências) | **metade feito**; o nome `MindStore` aponta para um store fora da entidade, que não existe |
| "`MindsInspector`" | Não existe. O que existe é o overlay de debug em texto: fps/processo/física, chunks e fila de malha, tick/`worst_step_ms`/ticks perdidos, totais por canal do Éter, posição e mira, e uma linha por lobo com a narrativa do oráculo — [hud.gd:241-275](../src/ui/hud.gd#L241-L275), tecla em [input_actions.gd:33](../src/input/input_actions.gd#L33) | **não existe**; a observabilidade mínima exigida por P1 está coberta em texto, não em inspector |
| "**hash de estado** e journal de tick são sagrados" | Não existe nem hash nem journal de tick. `SimClock` guarda `tick`, `last_step_ms`, `worst_step_ms`, `dropped_ticks` — [sim_clock.gd:9-14](../src/core/sim_clock.gd#L9-L14) — e não serializa nada por tick. A persistência guarda semente + diário de edições do voxel ([save_manager.gd:5-6](../src/persistence/save_manager.gd#L5-L6), [main.gd:316-328](../src/main.gd#L316-L328)), que é outra coisa: reconstrução de mundo, não replay auditável. As únicas ocorrências de `hash` no código são helpers de ruído do gerador — [voxel_world.gd:589](../src/world/voxel_world.gd#L589), [world_gen.gd:200](../src/world/world_gen.gd#L200) | **falso hoje**; o princípio está certo, a peça é pré-requisito de tudo que depende dele |
| "testes de determinismo: 20 sementes × 1000 ticks no cenário do lobo" | A suíte roda **uma** semente (`const SEED := 20261116` — [smoke_test.gd:10](../tests/smoke_test.gd#L10)) e a checagem determinística é uma só: 16 colunas de altura geradas duas vezes e comparadas — [smoke_test.gd:288-295](../tests/smoke_test.gd#L288-L295). Não há harness multi-semente em `tests/` | **falso hoje**; só faz sentido depois do hash |
| "budget HOT medido" | Existe o mecanismo e existe o número vivo, mas nenhum log o captura. `SubtreeGuard` estoura com fail-visível — [bt_tree.gd:117-134](../src/ai/behavior/bt_tree.gd#L117-L134) (default 250 µs) — e o lobo instancia o guard com **400 µs** — [wolf.gd:155-156](../src/entities/wolf.gd#L155-L156). O custo sai no F3 como `bt N us (estouros N)` — [wolf.gd:524-525](../src/entities/wolf.gd#L524-L525) — e nenhuma checagem da suíte o lê. O único orçamento de frame publicado é o de malha: `MESH_BUDGET := 2` chunks por frame — [main.gd:13](../src/main.gd#L13), usado em [:154](../src/main.gd#L154) | **parcial**; o prompt cita 250, o código roda 400. E "medido" ainda não é verdade |
| "oráculo ainda é HTTP, não nativo — fortaleça sem fingir que é nativo" | Correto e verificado: `HTTPRequest` contra `http://127.0.0.1:8741`, timeout 8 s, recuo de 30 s, resposta vazia → recuo global sem tocar a decisão — [mind_oracle.gd:11-13](../src/ai/mind_oracle.gd#L11-L13), [:106-122](../src/ai/mind_oracle.gd#L106-L122). Um pedido em voo, round-robin pela matilha, prompt montado do estado interno — [:43-54](../src/ai/mind_oracle.gd#L43-L54), `:_prompt_for` em [:86-103](../src/ai/mind_oracle.gd#L86-L103). Não há cache nem embeddings | **falso no projeto, certo no diagnóstico** |
| "reduza o acoplamento de `main.gd` / `wolf.gd` / memória" | Os números reais hoje: `main.gd` 451 linhas, `wolf.gd` 601, `player.gd` 762, `voxel_world.gd` 636, `mind.gd` 167, `aether_field.gd` 214, `smoke_test.gd` 1963. O acoplamento é estrutural, não de tamanho: `main.gd` é dono de mundo, relógio, matilha, HUD, oráculo e visualização ao mesmo tempo — [main.gd:18-24](../src/main.gd#L18-L24) | **válido**; medir por linhas é proxy, o que importa é o dono único |
| "zero derivação GPL do Veloren" | Verificado por ausência: nenhum `.rs` e nenhum `.ron` no repositório. As menções a Veloren são comentários de idéia e de origem em 12 pontos de `src/` (ex.: [inventory.gd:5-17](../src/items/inventory.gd#L5-L17), que inclusive separa "o que não veio do Veloren") e o link do §09 | **correto**; nada a corrigir |
| "números medidos, gates subtrativos, docs derivados de código" | Já é a prática da casa: §08 tem a tabela "Estado real do roadmap" com o que existe e o que falta por fase — [08-roadmap-risks-licensing.md:20-38](design/08-roadmap-risks-licensing.md) | **correto**; o §08 já carrega o estado real, não precisa de nova edição |

### O prompt de instruções de trabalho × o código

O segundo mandato chegou como texto de colaboração ("Instruções de Trabalho (obrigatórias)") e
virou [`AGENTS.md`](../AGENTS.md) na raiz, para valer em toda sessão que abrir o repositório.
As regras de comportamento estão lá; o que segue é a auditoria das **afirmações de estado** que
o mesmo texto traz, no mesmo espírito da tabela acima.

| O que o prompt afirma | O que está em `src/` hoje | Veredicto |
|---|---|---|
| "Estamos em P0/P1" | O §08 diz outra coisa, e a suíte confirma: o projeto está **antes** de P1 e **sem nenhum gate fechado** — [08-roadmap-risks-licensing.md:36-38](design/08-roadmap-risks-licensing.md). Existe um slice P0/P1 jogável, não uma fase encerrada | **verdade como ponto de partida, falso como fase**; ler "P0/P1" como "o que existe", nunca como "o que está aprovado" |
| "Não quebrar determinismo ou a capacidade de hash/journal sem avisar" | Não há capacidade instalada para quebrar: nem hash de estado por tick nem journal de tick existem (linha 4 da tabela acima). O que dá para quebrar de verdade é o acesso serializável ao estado autoritativo — `main.diagnostics()` em [main.gd:404](../src/main.gd#L404) e o carimbo de versão do gerador recusando save velho em [:351](../src/main.gd#L351) — que é justamente o que o primitivo vai consumir | **falso como salvaguarda**; vale como restrição de design: nada de esconder estado atrás de interface opaca |
| "A mente propõe, as regras dispõem — LLM nunca decide movimento, dano, posição ou estado" | Verdade hoje por fiação, não por verifier: a única saída de `MindOracle` é `_narrations` — [mind_oracle.gd:27](../src/ai/mind_oracle.gd#L27), [:120](../src/ai/mind_oracle.gd#L120) — lida por `narration_of()` ([:59-60](../src/ai/mind_oracle.gd#L59-L60)) e entregue só ao HUD ([main.gd:109](../src/main.gd#L109) → [hud.gd:270-271](../src/ui/hud.gd#L270-L271)). Grep de `oracle`/`narration` em `src/` não acha nenhum outro consumidor: nem `Mind`, nem `Wolf`, nem o mundo leem o oráculo | **correto hoje**; o dia em que o oráculo *sugerir*, a sugestão entra como crença em quarentena (§04), não como intenção escrita |
| "Completar o mínimo de P1: AetherField, Mind, consolidação, observabilidade, testes de hash, budget" | Três dos seis existem: `AetherField` (com 3 dos 6 canais), `Mind` e a **consolidação** — mas esta vive dentro de `Mind`, não num `MindStore` à parte. Observabilidade há em texto (F3), inspector não; "testes de hash" pressupõem a peça ausente; "budget" tem mecanismo e nenhuma colheita em log | **metade feito**; item por item nas linhas acima e na fila "Falta" |
| "Melhorar a degradação e a robustez do oráculo atual (ainda HTTP)" | Correto no diagnóstico, e a degradação já é checada sem rede — sonda apontada para a porta 1 em [smoke_test.gd:1647-1651](../tests/smoke_test.gd#L1647-L1651). O caminho feliz depende de `llama-server` de fora e não é testável em headless | **correto**; está dentro do escopo autorizado |
| "Repositório: github.com/DouglasGDev/aetherfall" | `origin` confere. O que está publicado é `00538b3` (`git ls-remote --heads origin`, lido em 2026-11-18); `88d1c19`, `9c6b722` e `53eba15` são locais até o push ser pedido | **correto**; publicação se confirma por `ls-remote`, nunca pelo código 0 do `push` |
| "Ao final de um bloco, atualize ou proponha atualização de `docs/melhorias-status.md`" | É este arquivo, com as seções que o prompt pede (feito / em andamento / falta / backlog / débitos / furos / notas) | **correto**; já é a prática da casa, e agora está escrita em [`AGENTS.md`](../AGENTS.md) |

### O prompt de disciplina de otimização × o código

Terceiro mandato, aplicado com as duas regras da casa: nada de adjetivo onde cabe número, e
nada de otimização onde ainda não há medição. As regras anti-bloat não são afirmações de
estado, então não têm linha aqui — o que tem linha é o instrumento e o custo que ele mostra.

| O que o prompt afirma | O que está em `src/` hoje | Veredicto |
|---|---|---|
| "Meça antes de otimizar: use dados reais (Profiler, tempo de tick, contagem de objetos, alocações)" | Tempo de tick: medido e publicado — `last_step_ms`/`worst_step_ms`/`dropped_ticks` ([sim_clock.gd:12-14](../src/core/sim_clock.gd#L12-L14)) cronometrados em µs dentro de [main.gd:124-128](../src/main.gd#L124-L128). Tempo de frame: `TIME_PROCESS` e `TIME_PHYSICS_PROCESS` só no F3 ([hud.gd:244-247](../src/ui/hud.gd#L244-L247)). **Contagem de objetos e de alocações: nenhum monitor do engine é lido no repositório inteiro** (grep de `Performance.`: duas linhas, as duas acima) | **parcial**; o "Profiler" da casa é SimClock + `SubtreeGuard` + F3, e a coluna de alocação não existe como número |
| "Otimize o que dói agora" | A dor está medida e é o boot: geração 936-962 ms e malharia 4.640-4.886 ms com a janela congelada, contra **pior passo de 7,56 a 11,21 ms num orçamento de 50 ms** e `dropped_ticks = 0` nas cinco corridas (`.tools/suite_fix1.log` … `suite_fix4.log`, `.tools/pub-suite.log`) | **correto, e já respondido**: o hot path de simulação não é a dor de hoje; o precedente medido é o mesher, que caiu de ~16 s para ~7,5 s com índice linear |
| "Hot path tem regra diferente: o que roda a cada tick (20 Hz) precisa ser barato" | As duas cadências existem e estão separadas: 20 Hz autoritativo ([sim_clock.gd:5-7](../src/core/sim_clock.gd#L5-L7)) e jogador local por frame ([main.gd:123](../src/main.gd#L123)). Ressalva honesta: o jogador **muda estado do mundo por frame** — `set_block` da lavra e da colocação em [player.gd:660](../src/entities/player.gd#L660) e [:686](../src/entities/player.gd#L686) —, então "só o tick toca o mundo" ainda não é verdade | **correto no relógio, incompleto na autoridade**; é o §06 (dedicado) que cobra essa conta |
| "Alocação é cara: evite arrays, dicionários, objetos e strings no tick quente" | Acontece hoje em dois lugares conhecidos: o blackboard é um `Dictionary` novo por lobo por tick ([wolf.gd:339](../src/entities/wolf.gd#L339), 100/s no teto de matilha viva) e a difusão aloca um `PackedInt32Array` por canal por passada ([aether_field.gd:113](../src/world/aether_field.gd#L113), 3 a cada 0,25 s). **Nenhum dos dois tem custo medido** | **válido como restrição**; como tarefa de otimização cai na regra 1 — primeiro a colheita (débito abaixo) |
| "LOD é obrigatório em sistemas de IA/simulação" | Não há LOD por distância: os lobos vivos rodam a árvore inteira a cada tick. O que há é throttle temporal — difusão e visão 4×/s, cadáveres 1×/s ([main.gd:12-16](../src/main.gd#L12-L16)) — e cooldowns de percepção dentro da árvore ([wolf.gd:83-85](../src/entities/wolf.gd#L83-L85)) | **falso hoje**; a peça tem nome no design (`HotSet`/Véu, §04 e §06) e é P2: sem custo em log, é backlog, não tarefa |
| "Budget explícito: defina e respeite orçamentos de tempo (ex.: HOT minds ≤ X ms)" | Quatro orçamentos são código: 50 ms por passo com teto de 5 passos por frame ([sim_clock.gd:19-29](../src/core/sim_clock.gd#L19-L29)), 400 µs por árvore ([wolf.gd:155-156](../src/entities/wolf.gd#L155-L156); default da classe, 250 µs, em [bt_tree.gd:117-120](../src/ai/behavior/bt_tree.gd#L117-L120)), 2 chunks de malha por frame ([main.gd:13](../src/main.gd#L13)) e 0,25 s de difusão. O "≤ 2,5 ms" do gate de P1 continua `[TARGET]` no §08, e a aritmética (5 × 400 µs = 2 ms) cabe nele sem que nenhum log mostre a soma | **parcial**; orçamento por peça existe, o agregado do gate é alvo sem medição |
| "Observabilidade > micro-otimização cega: se não dá para medir, não dá para saber se melhorou" | Para o tick, dá: a última linha do diagnóstico da suíte publica `pior passo` e `perdidos` ([smoke_test.gd:1958-1960](../tests/smoke_test.gd#L1958-L1960)). Para frame, fila de malha, custo de BT e alocação, o número só existe em janela | **é o débito da colheita de custo**, e é o que trava as cinco linhas acima de virarem otimização |

## Feito nesta sessão

- **1ª pessoa view model**: braço direito próprio da lente (ombro/cotovelo/punho/dedos),
  ombro em `(0.46, -0.20, -0.16)`, `ARM_YAW 0.34`, arco de lavra e de golpe com três fases,
  bloco segurado na mão. A profundidade é resolvida por camada, não por escalar o braço:
  `no_depth_test` + `render_priority` crescente (braço 10 < manga 11 < antebraço 11 < punho
  12 < bloco 13 < dedos 14) — [fp_viewmodel.gd](../src/entities/fp_viewmodel.gd), 263 linhas.
- **Corpo de 3ª pessoa fora do quadro em 1ª pessoa**, sem FloatingLimb: os membros continuam
  contínuos ao torso quando a câmera está no olho ([player_avatar.gd](../src/entities/player_avatar.gd)).
- **Galeria refeita de uma corrida só** (`gallery25.log`, 11 frames, 1920×1080, seed 20261116)
  e o harness de capturas consertado: o slot 09 chamava `p.hotbar.find(...)`, API que não
  existe mais, e morria em silêncio entregando PNG velho. Agora procura o slot com pedra e
  pina na tecla 0, como o `Inventory` realmente funciona. O harness (`shot_gallery.gd`) mora
  em `.tools/`, no `.gitignore`: quem for reproibir um frame precisa recriá-lo.
- **Duas gates de quadro recalibradas na unidade do defeito**, não em proxy: a do Éter tinha
  piso 0,02 e admitiu um frame invisível a olho (0,029 reprovado) contra um aprovado (0,094)
  → piso 0,05, o meio-termo entre as duas medidas. A da lavra só gateava progresso (0,15) e
  admitiu a boca de uma caverna escura → agora mede a luminância de um quadrado de 96 px sob a
  cruz (`_patch_lum`, gate ≥ 0,22); a corrida boa marca 0,39.
- **Citações de doc conferidas contra o código** em §09, §10 e §11: 15 intervalos `arquivo:linha`
  re-derivados (`main.gd` mudou de tamanho e os ponteiros estavam todos deslocados), um
  **número falso corrigido** (knockback do lobo estava escrito 8,5 — que é o dano da mordida;
  o real é `KNOCKBACK_SPEED = 5.0`, [wolf.gd:39-41](../src/entities/wolf.gd#L39-L41)) e o binding
  de CTRL, que apontava para um intervalo que não continha nenhuma das duas ações.
- **Suíte deixada de ser rolagem de dados** (furo #6 abaixo, agora com causa medida). O passo de
  golpe herdava estado da simulação ao vivo por três portas, e as três foram fechadas: o alvo é
  escolhido entre os vivos ([smoke_test.gd:1364-1374](../tests/smoke_test.gd#L1364-L1374),
  `_alive_wolf()`), a premissa do jogador é montada pelas transições do próprio jogo —
  `respawn_at` e `close_panel`, não campo escrito à mão
  ([smoke_test.gd:1410-1421](../tests/smoke_test.gd#L1410-L1421)) — e o resto da matilha é
  estacionado fora da linha de mira
  ([smoke_test.gd:1428-1439](../tests/smoke_test.gd#L1428-L1439)). A checagem nova
  `mira travada no lobo do passo` ([smoke_test.gd:1442-1447](../tests/smoke_test.gd#L1442-L1447))
  diz em voz alta se algum dia a mira não estiver no lobo do passo, com a distância do rival mais
  próximo. A suíte passou de 219 para **220 checagens**.
- **Clone limpo re-medido e publicado.** O README prometia o número do clone para a árvore
  anterior; re-medido no commit que carrega o conserto (`9c6b722`), clonado sem `.godot/` nem
  `.tools/`, `--import` e suíte: **220 checagens / 0 falhas / 35,4 s**, exit 0, zero `ERROR` nos
  dois logs, com a mira do passo nos mesmos 2,98 m e o rival a 8,02 m
  (`.tools/pub-import.log`, `.tools/pub-suite.log`). Aproveitou e trouxe os logs dos braços do
  furo #6 da pasta temporária para `.tools/` — linha de tabela que aponta para arquivo apagado
  não é evidência.
- **Os três mandatos viraram uma coisa só lida por quem chega.** As "Instruções de Trabalho
  (obrigatórias)" e a "Disciplina de Otimização e Controle de Crescimento" estão em
  [`AGENTS.md`](../AGENTS.md), na raiz, com uma tabela de auditoria para cada um acima. O que
  aqueles textos davam por existente — capacidade de hash/journal a preservar, "estamos em
  P0/P1" como fase encerrada, "Profiler" e contagem de alocações como dado disponível, LOD de
  IA como regra já seguida — não existe ou é parcial, e está escrito lá com a linha de código
  que mostra; o que eles mandam e já é verdade foi conferido por fiação e por grep, não por
  suposição (oráculo → só o HUD; `Performance.` lido em duas linhas, ambas de tempo).

## Em andamento

Nada aberto. Esta sessão fecha a 1ª pessoa e o estado do prompt; o que sobe para a fila
está em "Falta".

## Falta

Por dependência, não por preferência:

1. **Primitivo de hash de estado por tick.** Sem ele, as quatro linhas abaixo não têm o que
   verificar. Escopo mínimo: uma função determinística sobre o estado autoritativo (edições do
   voxel, canais do Éter, `tick`, intenções/crenças das mentes vivas) e um journal apêndice-only
   de `(tick, hash)`. O `SimClock` já tem o relógio para carimbar — falta o que carimbar.
2. **Diário de tick sobre a simulação** (o que o save guarda hoje é o diário de *edições* do
   mundo, e serve para reconstruir terreno, não para reproduzir uma tarde).
3. **Cenário do lobo em 20 sementes × 1000 ticks** — headless, com a mesma semente gerando o
   mesmo hash 1000 ticks à frente. Pressupõe 1 e 2.
4. **Canais morte / som / fogo** em `AetherField`: entram como mais uma entrada nas três
   tabelas paralelas de [aether_field.gd:11-15](../src/world/aether_field.gd#L11-L15) e uma cor
   em [aether_viz.gd:12-16](../src/rendering/aether_viz.gd#L12-L16), com imprint em cada fonte
   (morte de mob, tiro/passo, lava/fogueira) e leitura nas curvas de utilidade. Não é
   cosmético: sem canal de medo-morto o lobo só reage ao que vê.
5. **Budget HOT medido e publicado.** Colher `_guard.last_us` e `_guard.trips` de cada lobo
   dentro da suíte headless, imprimir no log e gatear. E resolver a discordância 250 vs 400:
   ou o default do `SubtreeGuard` vira o número alvo, ou o `400` de `wolf.gd:156` passa a ser
   uma constante nomeada com justificativa medida. Gate subtrativo: nenhuma mente nova entra
   antes do budget da existente estar escrito.
6. **Difusão do Éter fora do tick de decisão.** Hoje a difusão roda na passada do relógio
   ([main.gd:12](../src/main.gd#L12) `AETHER_PERIOD 0.25`); com 6 canais e a malha competindo,
   é o primeiro candidato a thread.
7. **Decompor `main.gd`** pelo eixo certo: um dono por sistema (sessão, matilha, HUD, oráculo,
   visualização), mantendo a autoridade única de escrita no mundo — que hoje já é o caso e é o
   que precisa continuar verdade depois do corte.

## Backlog priorizado (P0 → P1)

**P0 — fundação determinística** (gate atual: nenhum fechado)
- [ ] `state_hash()` + journal de tick (itens 1 e 2 de "Falta").
- [ ] `af-bench --scenario boot_walk_10min` com hash estável em 3 execuções.
- [ ] bake-off de voxel decidido com números (as alturas já estão certas: geração 942 ms e
      malha 4682 ms no boot medido; falta a comparação entre abordagens, não o número).
- [ ] `docs/engine/simclock.md` derivado de [sim_clock.gd](../src/core/sim_clock.gd).

**P1 — mentes e memória**
- [ ] canais morte/som/fogo (item 4) — maior valor de gameplay por linha escrita.
- [ ] budget HOT medido (item 5) e o número no §08.
- [ ] multi-semente do cenário do lobo (item 3).
- [ ] difusão em thread (item 6).
- [ ] `MindStore`: só vale se mover a memória para fora da entidade; a consolidação que o
      prompt pedia já está feita dentro de `Mind`, então o item é o *store*, não a *consolidação*.
- [ ] `MindsInspector`: decidir se é uma UI nova ou o F3 atual estendido — hoje o F3 já expõe
      intenção, medo, sangue, trabalho, `mem`, `crencas` e o custo da árvore.

## Débitos

- **`docs/design/08` tem um link quebrado**: `:34` aponta para
  `09-veloren-mecanics-adaptation.md`; o arquivo é
  `09-veloren-mechanics-adaptation.md` (falta um "s"). Corrigido junto deste arquivo.
- **Nenhum log do `bt N us` existe**: a linha é impressa só no overlay em janela. O débito não
  é do código, é da evidência — enquanto não houver colheita em headless, "budget medido"
  continua sendo afirmação. É o mesmo balde que segura as outras três colunas que o terceiro
  prompt pede: `TIME_PROCESS`/`TIME_PHYSICS_PROCESS` e a fila de malha (hoje só em janela), a
  soma das cinco árvores contra o teto de 2,5 ms do gate, e qualquer número de **alocação** —
  que não existe em lugar nenhum, porque o repositório lê dois monitores do engine e são os
  dois de tempo. Antes de cortar o `Dictionary` do blackboard por tick
  ([wolf.gd:339](../src/entities/wolf.gd#L339)) ou o array por canal da difusão
  ([aether_field.gd:113](../src/world/aether_field.gd#L113)), a tarefa é essa colheita.
- **O passo de nado sabe sumir sem deixar rastro**: se a seed não tiver lago fundo,
  `_swim_wolf` fica nulo e `_check_swim_assert` retorna antes de checar qualquer coisa —
  quatro checagens somem e a contagem cai de 220 para 216 sem nenhum vermelho. A contagem
  publicada por revisão é o que pega isso hoje; o certo é o passo falhar quando a premissa
  que ele mesmo pediu não existe.
- **O gate do oráculo depende de um servidor local de fora**: `live_oracle_probe.tscn` exige o
  `llama-server` de pé; a degradação é testada sem rede ([smoke_test.gd:1647-1651](../tests/smoke_test.gd#L1647-L1651),
  sonda apontada para a porta 1), o caminho feliz não é testável em CI.

## Furos descobertos

1. **O harness de capturas estava morto havia várias sessões** e ninguém viu, porque o erro de
   script (`Invalid access to 'hotbar' on Player`) não impedia a escrita dos PNGs antigos: a
   gate de "arquivo existe" passava. Uma gate de captura precisa gatear a *corrida*, não o
   arquivo em disco.
2. **Duas gates de quadro mediam proxy**: progresso de lavra ≥ 0,15 não diz se o bloco aparece
   no quadro; `eter ≥ 0,02` não diz se a heatmap é visível. As duas agora medem o que a
   reclamação mede (luminância sob a cruz; fração de célula pintada e valor do canal).
3. **§09 tinha um número inventado** (knockback 8,5) e um intervalo de binding errado. Ambos
   foram re-derivados do código. O risco geral: `main.gd` cresce e todo doc que cita `main.gd:NNN`
   apodrece em silêncio — por isso a revisão de citações é procedimento, não favor.
4. **`SubtreeGuard` default 250 µs × uso real 400 µs**: o documento de design fala em 2,5 ms de
   budget HOT, o guard do lobo devolve 250 µs por padrão mas roda com 400 µs, e nenhum dos
   números é medido. Três números diferentes para a mesma ideia é o tipo de furo que só fecha
   com um log.
5. **"hash de estado e journal são sagrados" descreve uma peça que não existe.** O princípio é
   bom; o prompt, porém, está escrito como se ele fosse uma checagem a manter verde. Não é: é
   uma linha de construção. Registrar isso evita "validar" algo ausente.
6. **A suíte tinha um passo que era rolagem de dados, e o clone limpo foi o que mostrou.** Na
   primeira corrida do clone limpo esta árvore deu **4 falhas** (`golpe acertou o lobo
   hp 42 -> 42.0 em 30 ticks` + as três consequentes); a segunda corrida do mesmo clone, na
   mesma máquina, sem tocar em nada, deu **219 checagens / 0 falhas**. Vermelho intermitente em
   código idêntico é defeito de premissa, não do ambiente.

   Causa procurada em duas direções. A primeira era um buraco real, mas não era a causa; a
   segunda é, e está reproduzida nos dois sentidos:

   - **Braço A (código antigo + cadáver forçado no índice):** `main.wolves[2].die()` antes do
     passo devolve as **mesmas quatro linhas**, com os **mesmos valores** — é um buraco da porta
     do alvo (`targets_under_crosshair()` só devolve vivos — [main.gd:218-223](../src/main.gd#L218-L223) —
     e o corpo fica na matriz até a faina de recolher). **Descartado como causa natural** pelo
     próprio log da corrida vermelha: `abatidos=1` e `5 -> 4 lobos` aparecem *depois* do passo,
     ou seja, nenhum lobo estava caído quando o golpe falhou.
   - **Censo da linha de mira (seis corridas do código antigo com a geometria impressa):** o
     passo põe seu alvo a **3,0 m** do olho, e em **duas das seis** havia um lobo vivo a
     **1,6 m** — mais perto que o alvo. As seis passaram porque o raio não cruzava a caixa desse
     lobo (`raio=fora`): quem chegou perto não estava sobre a mira. O passo dependia dessa sorte.
   - **Braço D (código antigo + um rival posto sobre a mira a 1,6 m):** as **quatro linhas do
     vermelho natural voltam exatamente** (`hp 42 -> 42.0 em 30 ticks`, `hp=42.00`,
     `stagger=0.00 s`, `velocidade=0.00 m/s`) e o instrumento diz o motivo:
     `alvo=true mesmo=false d_ate_alvo=1.97` contra `d_center=2.75` do alvo do passo.
     `_update_target` escolhe o mais próximo ao longo da mira (`dp < best_d`,
     [player.gd:582-608](../src/entities/player.gd#L582-L608)) e o golpe foi no lobo que a
     simulação ao vivo deixou ali. A corrida vermelha natural tem a mesma digital:
     `intento=... hunt` no passo de mente e `hp=66.0` no diagnóstico final — matilha em cima do
     jogador parado, estado que o próprio suíte já documentava
     ([smoke_test.gd:215-223](../tests/smoke_test.gd#L215-L223)).
   - **Braço E (código novo + a mesma injeção):** o rival é estacionado pelo próprio passo
     (`rival_mais_proximo=8.02 m`), os cinco checks do golpe passam e a suíte fecha
     **220 checagens / 0 falhas**.

   As outras portas caem por leitura da corrida vermelha, não por suposição: o passo seguinte ao
   golpe é o de rolamento, que exige jogador vivo (sem isso `update_local` retorna antes de
   rolar), painel fechado (sem isso `_input` descarta o buffer) e cadência drenada — e ele passou
   com `vigor=86.0`, `janela=0.35 s`, `iframes=0.45`; nada entre os dois passos mexe em `alive`
   nem em `panel_open`. A cadência sozinha também não explica: 0,42 s cabe nos 0,5 s dos 30 ticks
   do laço. Restava a porta do alvo, e foi ela que fechou.

   O mesmo índice fixo existia no passo de cadáver, cujo `die()` é guardado por
   `if not alive: return` ([wolf.gd:487-490](../src/entities/wolf.gd#L487-L490)) — um lobo já
   caído ali derrubaria "morte contabilizada" pela mesma razão. Os dois agora compartilham o
   seletor. O passo de nado (`main.wolves[1]`) e o de memória (`main.wolves[3]`) ficaram como
   estavam: a premissa de cada um não passa pelo filtro de vivos e os dois falham à vista se o
   escolhido estiver caído.

   O vermelho natural não foi mais observado com o instrumento montado — **17 corridas do código
   antigo** (11 com a mensagem ampliada + 6 com o censo da mira) deram todas 0 falhas, contra a
   única corrida vermelha que o clone limpo mostrou. O que fecha o caso não é ter pego a corrida
   vermelha de novo: é o Braço D reproduzi-la deterministicamente a partir de um estado que o
   censo mede como frequente, e o Braço E mostrar que o passo novo é indiferente a esse estado.
   Ligação direta com o item 1 de "Falta": sem hash por tick a suíte não sabe nem se rodou o
   mesmo mundo duas vezes — resta ao passo montar a própria premissa, que é o que ele agora faz.

## Notas de medição

| Número | Valor medido | De onde |
|---|---|---|
| Suíte headless (árvore deste commit, premissa montada) | **220 checagens, 0 falhas**, 35,6 / 35,9 / 36,3 / 36,4 s em **quatro** corridas, exit 0, zero `ERROR` | `.tools/suite_fix1.log` … `suite_fix4.log` |
| Mira do passo de golpe (neste commit) | `alvo=true na_lista=true d_alvo=2.98 rival_mais_proximo=8.02 m`, nas quatro | os quatro logs, linha `mira travada` |
| Árvore sem a premissa montada (três corridas) | 219 checagens, 0 falhas, 35,4 s | `.tools/suite_flake1.log` … `suite_flake3.log` |
| Tick (idêntico nas quatro novas) | 359 ticks, **0 perdidos**, 64 chunks, 14 edições, 149 meshes, 214.480 triângulos, 4 vivos | `suite_fix1.log` … `suite_fix4.log`, diagnóstico final |
| Boot do mundo (nas quatro novas) | geração 936,0 / 944,5 / 952,3 / 961,9 ms · malha 4640,6 / 4847,6 / 4885,8 / 4724,2 ms · pior passo 7,68 / 8,66 / 9,01 / 11,21 ms | os quatro logs |
| Estado vivo (mesma seed, mesma árvore) | `hp` final **0,0 / 0,0 / 0,0 / 6,5** · Éter final 9,94 / 9,58 / 9,73 / 7,27 — nas quatro a matilha machuca o jogador parado, e em três o mata | os quatro logs |
| Estado vivo (árvore antiga, três corridas) | `hp` do jogador **40,5 / 15,0 / 100,0** · Éter final **5,78 / 7,23 / 3,16** · geração 929,7 / 967,7 / 932,9 ms · malha 4684,0 / 4661,6 / 4675,9 ms · pior passo 7,607 / 7,55 / 7,997 ms | `suite_flake1.log` … `suite_flake3.log` |
| Corridas anteriores da árvore sem o seletor | 35,5 s · 35,7 s · Éter final 11,484 e 11,371 | `.tools/suite_final4.log`, `.tools/suite_status1.log` |
| Clone limpo de `88d1c19` (código antigo), corrida 1 / corrida 2 | **4 falhas** (golpe) / 219 checagens, 0 falhas, 35,4 s | `.tools/af-clean-suite.log`, `.tools/af-clean-suite2.log` (receita abaixo) |
| **Clone limpo de `9c6b722`** (este commit), recém-importado com o `--import` | **220 checagens, 0 falhas, 35,4 s**, exit 0, zero `ERROR` · `d_alvo=2.98 rival_mais_proximo=8.02 m` · geração 941,1 ms · malha 4.667,6 ms · pior passo 7,561 ms · Éter 9,780 | `.tools/pub-import.log`, `.tools/pub-suite.log` |
| Código antigo com o instrumento, 11 + 6 corridas | **219 checagens, 0 falhas nas 17** — o vermelho natural não voltou a aparecer | `.tools/ins1.log` … `.tools/ins10.log` + `.tools/rtest.log`; `.tools/mira1.log` … `.tools/mira6.log` |
| As quatro primeiras corridas do instrumento | **215 checagens**, 0 falhas, 36,2 / 35,9 / 36,2 / 36,7 s — o probe chamava `body_aabb()`, que `VoxelBody` não tem; o `SCRIPT ERROR` abortava `_check_attack` sem vermelho e a suíte perdia quatro checks em silêncio. Por isso a contagem foi conferida numa corrida antes do lote | `.tools/red1.log` … `.tools/red4.log` |
| Censo da linha de mira (6 corridas antigas) | alvo do passo a **3,0 m** do olho; em **2 das 6** um lobo vivo a **1,6 m**, com o raio fora da caixa dele (`raio=fora`) | `.tools/mira1.log` … `.tools/mira6.log`, linha `mira antes do giro` |
| Braço A — índice forçado a cadáver | mesmas 4 linhas do golpe, mesmos valores; 6 falhas no total (as 4 + 2 do censo que o probe derrubou: `abatidos=1`, `blood=3.25 fear=2.07`) | `.tools/probeA.log` |
| Braço B — seletor novo, dois cadáveres na frente | golpe passa (`hp 42 -> 28.0 em 1 ticks`, `stagger=0,45 s`, `5,55 m/s`); as 5 falhas que sobram são efeito dos cadáveres (`5 -> 2 lobos`, `vivos=2`, `debug ... 12 linhas`) | `.tools/probeB.log` |
| **Braço D — código antigo + rival sobre a mira a 1,6 m** | **as mesmas quatro linhas da corrida natural**, com `alvo=true mesmo=false na_lista=true d_ate_alvo=1.97` contra `d_center=2.75`; 219 checagens / 4 falhas | `.tools/armD.log` |
| **Braço E — código novo + a mesma injeção** | rival estacionado a **8,02 m**, `mira travada` passa, golpe passa, **220 checagens / 0 falhas** | `.tools/armE.log` |
| Galeria | 11 frames, 1920×1080, seed **20261116**, Vulkan Forward+ RX 9060 XT | `.tools/gallery25.log` |
| Éter no frame 11 | canal trabalho 40 células, valor **0,079**, pinta 0,06, fundo 20,0, estouro 0,00 | `gallery25.log`, linha `SHOT 11` |
| Mira no frame 05 | progresso 0,57, luminância do alvo **0,39** | `gallery25.log`, linha `SHOT 05` |
| Oráculo local (sessão anterior, rig de referência) | boot 9,5 s · prompt 52,7 tok/s · geração 45,1 tok/s | README "IA local (opcional)" |

A comparação entre corridas da mesma árvore não é enfeite: contagem de checagens, ticks, chunks,
edições, meshes e triângulos batem exatamente nas quatro (`220 · 359 · 64 · 14 · 149 · 214.480`),
e `aether_energy` (9,94 · 9,58 · 9,73 · 7,27), o pior passo (7,68 · 8,66 · 9,01 · 11,21 ms) e o
`hp` final (0,0 · 0,0 · 0,0 · 6,5) não batem. Ou seja, a geração é determinística e a
**simulação ao vivo não é** — que é,
literalmente, o motivo do item 1 de "Falta". Enquanto não houver hash por tick, nada que
envolva lobos pode ser gateado por igualdade de estado, só por invariante.

Toda linha acima foi lida do log, não lembrada da corrida. Os logs ficam em `.tools/`, que
está no `.gitignore` — para reproduzir as duas medições:

```sh
godot --headless --path . tests/smoke_test.tscn        # a suíte; a última linha é a contagem
godot --path . .tools/shot_gallery.tscn                # a galeria em janela, 1920x1080
```

A receita dos braços do furo #6, para quem quiser refazer a prova num clone descartável (os
quatro rodam a suíte inteira em ~36 s):

```sh
git clone file:///C:/Aetherfall /tmp/af && cd /tmp/af     # clone sem .godot/ nem .tools/
godot --headless --path . --import                        # obrigatório no clone novo
godot --headless --path . tests/smoke_test.tscn
```

- **A** — `88d1c19`, inserir `main.wolves[2].die()` antes de `_pause_for` no `_check_attack`:
  quatro linhas do golpe caem (e mais duas do censo, que o próprio probe derruba).
- **B** — código novo, `main.wolves[0].die()` e `main.wolves[1].die()` no mesmo lugar: o golpe
  passa; as falhas que sobram são efeito dos dois cadáveres, não defeito novo.
- **D** — `88d1c19`, pôr um lobo vivo que não seja o alvo sobre a mira, a 1,6 m do olho
  (`feet_pos = _spawn + Vector3(0, 0, -1.6)` e `_move_target` igual), antes de
  `Input.action_press("break_block")`: é a assinatura natural, e o instrumento aponta o rival
  (`mesmo=false`, `d_ate_alvo` menor que `d_center`).
- **E** — código novo com a mesma injeção, antes do estacionamento: passa, porque o passo agora é
  indiferente a onde a matilha estava.

Os números da suíte e da galeria valem para esta árvore; se o código mudar, a gate é
re-medida antes de qualquer doc citar o valor — inclusive este arquivo.
