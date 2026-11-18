# Melhorias — status real

Arquivo de trabalho. **Não é design**: cada linha abaixo ou cita código que existe, ou
cita um log medido, ou declara explicitamente que não existe ainda. A fonte das cobranças
é o "Prompt Master de Correção de Furos e Fechamento de Gates"; a primeira seção diz onde
ele está certo e onde ele descreve um projeto que ainda não é este.

Revisão de referência: `00538b3` + a área de trabalho de 1ª pessoa (view model).
Motor: Godot 4.7.2-stable (`ed1daf0bf`), Vulkan Forward+, AMD Radeon RX 9060 XT.

## O prompt × o código

| O que o prompt afirma | O que está em `src/` hoje | Veredicto |
|---|---|---|
| "AetherField de **6 canais** (trabalho, sangue, medo, morte, som, fogo)" | 3 canais: `enum Channel { WORK, BLOOD, FEAR, COUNT }` com `HALF_LIFE = [90, 55, 120]` e `DIFFUSE_RATE = [0.06, 0.16, 0.10]` — [aether_field.gd:9-15](../src/world/aether_field.gd#L9-L15). A `CHANNEL_COLOR` da visualização também tem 3 entradas — [aether_viz.gd:12-16](../src/rendering/aether_viz.gd#L12-L16) | **falso hoje**; é meta de P1 (§08 linha "falta") |
| "`MindStore` + consolidação" | A **consolidação já existe** dentro de `Mind`: ao estourar `EPISODIC_CAP = 24` o átomo mais velho sai da fila e vira reforço de crença, com contador persistido — [mind.gd:7](../src/ai/mind.gd#L7), [:44-45](../src/ai/mind.gd#L44-L45), `:_consolidate` em [:61-68](../src/ai/mind.gd#L61-L68), save/load em [:148](../src/ai/mind.gd#L148) e [:157](../src/ai/mind.gd#L157). Não há tipo `MindStore` (grep em `src/`: zero ocorrências) | **metade feito**; o nome `MindStore` aponta para um store fora da entidade, que não existe |
| "`MindsInspector`" | Não existe. O que existe é o overlay de debug em texto: fps/processo/física, chunks e fila de malha, tick/`worst_step_ms`/ticks perdidos, totais por canal do Éter, posição e mira, e uma linha por lobo com a narrativa do oráculo — [hud.gd:241-275](../src/ui/hud.gd#L241-L275), tecla em [input_actions.gd:33](../src/input/input_actions.gd#L33) | **não existe**; a observabilidade mínima exigida por P1 está coberta em texto, não em inspector |
| "**hash de estado** e journal de tick são sagrados" | Não existe nem hash nem journal de tick. `SimClock` guarda `tick`, `last_step_ms`, `worst_step_ms`, `dropped_ticks` — [sim_clock.gd:9-14](../src/core/sim_clock.gd#L9-L14) — e não serializa nada por tick. A persistência guarda semente + diário de edições do voxel ([save_manager.gd:5-6](../src/persistence/save_manager.gd#L5-L6), [main.gd:316-328](../src/main.gd#L316-L328)), que é outra coisa: reconstrução de mundo, não replay auditável. As únicas ocorrências de `hash` no código são helpers de ruído do gerador — [voxel_world.gd:589](../src/world/voxel_world.gd#L589), [world_gen.gd:200](../src/world/world_gen.gd#L200) | **falso hoje**; o princípio está certo, a peça é pré-requisito de tudo que depende dele |
| "testes de determinismo: 20 sementes × 1000 ticks no cenário do lobo" | A suíte roda **uma** semente (`const SEED := 20261116` — [smoke_test.gd:10](../tests/smoke_test.gd#L10)) e a checagem determinística é uma só: 16 colunas de altura geradas duas vezes e comparadas — [smoke_test.gd:288-295](../tests/smoke_test.gd#L288-L295). Não há harness multi-semente em `tests/` | **falso hoje**; só faz sentido depois do hash |
| "budget HOT medido" | Existe o mecanismo e existe o número vivo, mas nenhum log o captura. `SubtreeGuard` estoura com fail-visível — [bt_tree.gd:117-134](../src/ai/behavior/bt_tree.gd#L117-L134) (default 250 µs) — e o lobo instancia o guard com **400 µs** — [wolf.gd:155-156](../src/entities/wolf.gd#L155-L156). O custo sai no F3 como `bt N us (estouros N)` — [wolf.gd:524-525](../src/entities/wolf.gd#L524-L525) — e nenhuma checagem da suíte o lê. O único orçamento de frame publicado é o de malha: `MESH_BUDGET := 2` chunks por frame — [main.gd:13](../src/main.gd#L13), usado em [:154](../src/main.gd#L154) | **parcial**; o prompt cita 250, o código roda 400. E "medido" ainda não é verdade |
| "oráculo ainda é HTTP, não nativo — fortaleça sem fingir que é nativo" | Correto e verificado: `HTTPRequest` contra `http://127.0.0.1:8741`, timeout 8 s, recuo de 30 s, resposta vazia → recuo global sem tocar a decisão — [mind_oracle.gd:11-13](../src/ai/mind_oracle.gd#L11-L13), [:106-122](../src/ai/mind_oracle.gd#L106-L122). Um pedido em voo, round-robin pela matilha, prompt montado do estado interno — [:43-54](../src/ai/mind_oracle.gd#L43-L54), `:_prompt_for` em [:86-103](../src/ai/mind_oracle.gd#L86-L103). Não há cache nem embeddings | **falso no projeto, certo no diagnóstico** |
| "reduza o acoplamento de `main.gd` / `wolf.gd` / memória" | Os números reais hoje: `main.gd` 451 linhas, `wolf.gd` 601, `player.gd` 762, `voxel_world.gd` 636, `mind.gd` 167, `aether_field.gd` 214, `smoke_test.gd` 1888. O acoplamento é estrutural, não de tamanho: `main.gd` é dono de mundo, relógio, matilha, HUD, oráculo e visualização ao mesmo tempo — [main.gd:18-24](../src/main.gd#L18-L24) | **válido**; medir por linhas é proxy, o que importa é o dono único |
| "zero derivação GPL do Veloren" | Verificado por ausência: nenhum `.rs` e nenhum `.ron` no repositório. As menções a Veloren são comentários de idéia e de origem em 12 pontos de `src/` (ex.: [inventory.gd:5-17](../src/items/inventory.gd#L5-L17), que inclusive separa "o que não veio do Veloren") e o link do §09 | **correto**; nada a corrigir |
| "números medidos, gates subtrativos, docs derivados de código" | Já é a prática da casa: §08 tem a tabela "Estado real do roadmap" com o que existe e o que falta por fase — [08-roadmap-risks-licensing.md:20-38](design/08-roadmap-risks-licensing.md) | **correto**; o §08 já carrega o estado real, não precisa de nova edição |

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
  continua sendo afirmação.
- **O gate do oráculo depende de um servidor local de fora**: `live_oracle_probe.tscn` exige o
  `llama-server` de pé; a degradação é testada sem rede ([smoke_test.gd:1573](../tests/smoke_test.gd#L1573),
  porta fechada determinística), o caminho feliz não é testável em CI.

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

## Notas de medição

| Número | Valor medido | De onde |
|---|---|---|
| Suíte headless | **219 checagens, 0 falhas, 35,7 s**, exit 0, zero linhas `ERROR` | `.tools/suite_status1.log` (esta árvore, antes do commit) |
| Tick | 359 ticks, **0 perdidos**, pior passo **8,363 ms** | mesmo log, diagnóstico final |
| Boot do mundo | geração 944,417 ms · malha 4803,554 ms · 149 meshes · 64 chunks · 214.480 triângulos | mesmo log |
| Edições persistidas no fim da suíte | 14 | mesmo log |
| Corrida anterior da mesma árvore | 35,5 s · pior passo 8,884 ms · geração 942,389 ms · malha 4682,411 ms · Éter final 11,484 contra 11,371 | `.tools/suite_final4.log` |
| Galeria | 11 frames, 1920×1080, seed **20261116**, Vulkan Forward+ RX 9060 XT | `.tools/gallery25.log` |
| Éter no frame 11 | canal trabalho 40 células, valor **0,079**, pinta 0,06, fundo 20,0, estouro 0,00 | `gallery25.log`, linha `SHOT 11` |
| Mira no frame 05 | progresso 0,57, luminância do alvo **0,39** | `gallery25.log`, linha `SHOT 05` |
| Oráculo local (sessão anterior, rig de referência) | boot 9,5 s · prompt 52,7 tok/s · geração 45,1 tok/s | README "IA local (opcional)" |

A comparação das duas corridas da mesma árvore não é enfeite: contagem de checagens, ticks e
triângulos batem exatamente, e `aether_energy` final (11,484 × 11,371), o pior passo e o `hp`
não batem. Ou seja, a geração é determinística e a **simulação ao vivo não é** — que é,
literalmente, o motivo do item 1 de "Falta". Enquanto não houver hash por tick, nada que
envolva lobos pode ser gateado por igualdade de estado, só por invariante.

Toda linha acima foi lida do log, não lembrada da corrida. Os logs ficam em `.tools/`, que
está no `.gitignore` — para reproduzir as duas medições:

```sh
godot --headless --path . tests/smoke_test.tscn        # a suíte; a última linha é a contagem
godot --path . .tools/shot_gallery.tscn                # a galeria em janela, 1920x1080
```

Os números da suíte e da galeria valem para esta árvore; se o código mudar, a gate é
re-medida antes de qualquer doc citar o valor — inclusive este arquivo.
