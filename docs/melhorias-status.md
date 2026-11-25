# Melhorias — status real

Arquivo de trabalho. **Não é design**: cada linha abaixo ou cita código que existe, ou
cita um log medido, ou declara explicitamente que não existe ainda. A fonte das cobranças
são três prompts que se completam, todos com as afirmações de estado conferidas aqui e o
comportamento prescrito em [`AGENTS.md`](../AGENTS.md) (raiz): o "Prompt Master de Correção
de Furos e Fechamento de Gates", que diz *o que falta*; as "Instruções de Trabalho
(obrigatórias)", que dizem *como* mexer; e a "Disciplina de Otimização e Controle de
Crescimento", que diz *quanto custa*. Este arquivo tem uma tabela por prompt, na mesma
ordem.

Referência histórica das medições de golpe: `9c6b722` (furo #6 abaixo).
Bloco atual: o bioma passou a existir como código. `WorldGen.biome_of(x, z, h)` devolve um de quatro
identificadores (`FROZEN`, `ARID`, `TEMPERATE`, `WETLAND`) a partir das mesmas duas ruídos e da mesma
altura que a regra de superfície já consultava, e `surface_block` agora **pergunta** em vez de repetir
as comparações. A premissa do dossiê — derivar bioma não pode alterar o terreno — virou checagem
headless auto-contida: quatro assinaturas pinadas da revisão anterior (`e7e30e6`), 16 colunas de
relevo, histograma de blocos de topo e os 1 048 576 voxels do mundo. O pelo de cada lobo sai do bioma
do seu `home` (tabela de quatro cores na classe, uma pergunta por lobo no `setup`), e o imprint do
Éter ganhou viés por bioma aplicado **pelo chamador do evento** — o campo continua sem conhecer voxel
nenhum, e a sabotagem que move o multiplicador para dentro de `AetherField.imprint` está vermelha em
log (7 falhas, inclusive saturação em `MAX_VALUE 4,0`), e a que viamenta o bioma abaixo do bloco de
topo fica vermelha na checagem de 1 048 576 voxels (1 falha em 237). Publicado em `9fe5e45` pelo merge
`--no-ff` de `feat/bioma-e-cor-de-pelo-09` (base `e7e30e6`, ponta de código `44c9d94`, quatro commits,
um assunto cada): suíte
**237 checagens / 0 falhas / 35,5 s** e runner dedicado **119 checagens / 0 falhas / 2,044 s** em 24
cenários, exit 0 nos dois, repetidos na árvore de trabalho e no clone limpo com `--import` frio, e a
suíte re-rodada na `main` mergida (237 / 0, exit 0) — as
79 fontes conferidas dentro do clone, 79 `OK` / 0 divergências. O custo do viés não aparece no
`sim_step`: pareado contra o chão na mesma janela, `+0,59 %` contra `4,05 %` de dispersão do próprio
chão; o `pico` sobe `+13 %` e é indício, não atribuição — a perna `bench/` decide. O efeito no mundo,
que é o que a peça existe para ter, é mensurável: `aether_energy` do cenário da suíte sai de
`9,36133219487965` para `9,44745890423656` (`+0,92 %`), idêntico entre trabalho e clone, em
[readback.md](evidence/bioma-cor-de-pelo/readback.md).
Rodadas anteriores do Éter, cada uma com sua seção no fim: o nariz que desce e sobe (`cbaaef5`,
publicado em `ff347d2`), o saldo da difusão medido (`9f3622b`), o teto do cache de inspeções
(`297685b`) e o passo do lobo em plano livre (`520c3b4` + `a1405e4`).
Motor: Godot 4.7.2-stable (`ed1daf0bf`), Vulkan Forward+, AMD Radeon RX 9060 XT.

## Os prompts × o código

### O prompt master de furos e gates × o código

| O que o prompt afirma | O que está em `src/` hoje | Veredicto |
|---|---|---|
| "AetherField de **6 canais** (trabalho, sangue, medo, morte, som, fogo)" | 3 canais: `enum Channel { WORK, BLOOD, FEAR, COUNT }` com `HALF_LIFE = [90, 55, 120]` e `DIFFUSE_RATE = [0.06, 0.16, 0.10]` — [aether_field.gd:9-15](../src/world/aether_field.gd#L9-L15). A `CHANNEL_COLOR` da visualização também tem 3 entradas — [aether_viz.gd:12-16](../src/rendering/aether_viz.gd#L12-L16) | **falso hoje**; é meta de P1 (§08 linha "falta") |
| "`MindStore` + consolidação" | A **consolidação já existe** dentro de `Mind`: ao estourar `EPISODIC_CAP = 24` o átomo mais velho sai da fila e vira reforço de crença, com contador persistido — [mind.gd:7](../src/ai/mind.gd#L7), [:50-51](../src/ai/mind.gd#L50-L51), `:_consolidate` em [:67-74](../src/ai/mind.gd#L67-L74), save/load em [:183](../src/ai/mind.gd#L183) e [:192](../src/ai/mind.gd#L192). Não há tipo `MindStore` (grep em `src/`: zero ocorrências) | **metade feito**; o nome `MindStore` aponta para um store fora da entidade, que não existe |
| "`MindsInspector`" | Não existe. O que existe é o overlay de debug em texto: fps/processo/física, chunks e fila de malha, tick/`worst_step_ms`/ticks perdidos, totais por canal do Éter, posição e mira, e uma linha por lobo com a narrativa do oráculo — [hud.gd:245-281](../src/ui/hud.gd#L245-L281), tecla em [input_actions.gd:33](../src/input/input_actions.gd#L33) | **não existe**; a observabilidade mínima exigida por P1 está coberta em texto, não em inspector |
| "**hash de estado** e journal de tick são sagrados" | Agora há `TickJournal.state_hash()` e gravação JSONL de `[tick, hash]`, sob demanda ([tick_journal.gd](../src/persistence/tick_journal.gd)). A projeção mínima cobre semente/versão/dimensões, tick, edições, bytes completos do Éter e identidades/intenções/crenças das mentes vivas. `main._sim_tick` registra após incrementar o tick e dentro do cronômetro ([main.gd:378-384](../src/main.gd#L378-L384), cronometrado em [:280-282](../src/main.gd#L342-L344)) | **primitivo implementado, validação abaixo**; não cobre todo o estado da simulação nem registra comandos: replay permanece item 2 |
| "testes de determinismo: 20 sementes × 1000 ticks no cenário do lobo" | A suíte roda **uma** semente (`const SEED := 20261116` — [smoke_test.gd:10](../tests/smoke_test.gd#L10)) e a checagem determinística é uma só: 16 colunas de altura geradas duas vezes e comparadas — [smoke_test.gd:478-488](../tests/smoke_test.gd#L478-L488). Não há harness multi-semente em `tests/` | **falso hoje**; só faz sentido depois do hash |
| "budget HOT medido" | `SubtreeGuard` mede só a árvore e retorna falha no estouro — [bt_tree.gd:117-134](../src/ai/behavior/bt_tree.gd#L117-L134), default 250 µs; o lobo usa **400 µs** — [wolf.gd:448-449](../src/entities/wolf.gd#L448-L449). O F3 mostra custo/estouros — [wolf.gd:953](../src/entities/wolf.gd#L953). O teste de rastros agora colhe `sim_step` integral e `last_us`/`trips`, com um lobo por cenário; não mede o agregado simultâneo da matilha | **parcial**; há colheita estreita, mas o HOT de cinco lobos e o gate P1 continuam abertos |
| "oráculo ainda é HTTP, não nativo — fortaleça sem fingir que é nativo" | O transporte HTTP **saiu** no Passo 4 do dossiê 22: o nó de requisição é a ponte nativa — `_ext.enqueue` ([mind_oracle.gd:270](../src/ai/mind_oracle.gd#L270)) e `wait(id, 0)` por frame ([:288](../src/ai/mind_oracle.gd#L288)), timeout zero que não pendura os 50 ms do tick — e `grep -rn HTTPRequest src` devolve **vazio** (gate `transporte_http_zerado` no runner, 32 arquivos lidos, 0 ocorrências). Ficam o recuo cheio de 30 s (`RETRY_COOLDOWN`, [mind_oracle.gd:36](../src/ai/mind_oracle.gd#L36)), o round-robin pela matilha, o prompt dobrado numa mensagem só e a chave externa `KEY_ENV`/`KEY_FILE` ([:43](../src/ai/mind_oracle.gd#L43), §2.1). O recuo curto do `503` morreu com o transporte: a espera pelo modelo é o portão do `AfMindRuntime` ([af_mind_runtime.gd:68](../src/ai/af_mind_runtime.gd#L68)). Não há cache nem embeddings | **correto no diagnóstico, e o diagnóstico foi pago**; a robustez agora é de disco e ClassDB, não de porta |
| "reduza o acoplamento de `main.gd` / `wolf.gd` / memória" | Os números reais hoje (medidos nesta ponta com `wc -l`): `main.gd` 1246 linhas, `wolf.gd` 1218, `player.gd` 787, `voxel_world.gd` 687, `mind.gd` 167, `aether_field.gd` 234, `smoke_test.gd` 2681; o journal é dono de seu arquivo e contadores. O acoplamento é estrutural, não de tamanho: `main.gd` é dono de mundo, relógio, matilha, HUD, oráculo, visualização, o nó de áudio, o hospedeiro do modelo e as tocas ao mesmo tempo — [main.gd:45-70](../src/main.gd#L45-L70), `var _dens` em [:126](../src/main.gd#L126) | **válido**; medir por linhas é proxy, o que importa é o dono único |
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
| "Não quebrar determinismo ou a capacidade de hash/journal sem avisar" | O primitivo agora existe: ordenação de edições, identidades e crenças; Float32 integral do Éter; versão do formato; ticks consecutivos em arquivo novo. O save é deliberadamente diferente: filtra Éter e não conserva a origem das crenças. `diagnostics()` expõe custo e última assinatura ([main.gd:1230-1273](../src/main.gd#L1230-L1273)) | **salvaguarda do contrato mínimo**; preservar a projeção não equivale a tornar o jogo determinístico |
| "A mente propõe, as regras dispõem — LLM nunca decide movimento, dano, posição ou estado" | Verdade hoje por fiação, não por verifier: a única saída de `MindOracle` é `_narrations` — [mind_oracle.gd:86](../src/ai/mind_oracle.gd#L86), [:196](../src/ai/mind_oracle.gd#L196) — lida por `narration_of()` ([:164-165](../src/ai/mind_oracle.gd#L164-L165)) e entregue só ao HUD ([main.gd:208](../src/main.gd#L208) → [hud.gd:276-277](../src/ui/hud.gd#L276-L277)). Grep de `oracle`/`narration` em `src/` não acha nenhum outro consumidor: nem `Mind`, nem `Wolf`, nem o mundo leem o oráculo | **correto hoje**; o dia em que o oráculo *sugerir*, a sugestão entra como crença em quarentena (§04), não como intenção escrita |
| "Completar o mínimo de P1: AetherField, Mind, consolidação, observabilidade, testes de hash, budget" | Três dos seis existem: `AetherField` (com 3 dos 6 canais), `Mind` e a **consolidação** — mas esta vive dentro de `Mind`, não num `MindStore` à parte. Observabilidade há em texto (F3), inspector não; o primitivo de hash mínimo tem suíte própria, mas o cenário multi-semente ainda não existe; "budget" tem mecanismo e colheita estreita de um lobo, não do agregado HOT | **metade feito**; item por item nas linhas acima e na fila "Falta" |
| "Melhorar a degradação e a robustez do oráculo atual (ainda HTTP)" | Correto no diagnóstico, e a degradação segue checada sem rede — agora contra a ponte: o runtime sem pack não emite chamada ([smoke_test.gd:3119-3122](../tests/smoke_test.gd#L3119-L3122)) e a recusa da fila nomeia o motivo e arma o recuo cheio ([:3154-3157](../tests/smoke_test.gd#L3154-L3157)). O caminho feliz não depende mais de `llama-server` de fora: o pack abre dentro do processo, e num clone sem o dll gitignored o wrapper nomeia a ausência no pedido | **correto**; o transporte saiu no Passo 4 do dossiê 22 e a robustez do pack é o §6.3 |
| "Repositório: github.com/DouglasGDev/aetherfall" | `origin` confere. Publicação re-confirmada em `42799fa` — o `push` devolveu `1db00cf..42799fa main -> main` e `git ls-remote --heads origin` respondeu `42799fa0f0987b20d58902b4b2f7a4927a93cfd2 refs/heads/main` em 2026-11-19, o mesmo SHA do `HEAD` local. Os seis blocos desta revisão (som, journal, RNG, rastros, mão e porte em 3ª pessoa) estão todos no remoto; a confirmação anterior, de 2026-11-18, parava em `1db00cf` com hash/journal e rastros ainda locais | **correto**; publicação se confirma por `ls-remote`, nunca pelo código 0 do `push` |
| "Ao final de um bloco, atualize ou proponha atualização de `docs/melhorias-status.md`" | É este arquivo, com as seções que o prompt pede (feito / em andamento / falta / backlog / débitos / furos / notas) | **correto**; já é a prática da casa, e agora está escrita em [`AGENTS.md`](../AGENTS.md) |

### O prompt de disciplina de otimização × o código

Terceiro mandato, aplicado com as duas regras da casa: nada de adjetivo onde cabe número, e
nada de otimização onde ainda não há medição. As regras anti-bloat não são afirmações de
estado, então não têm linha aqui — o que tem linha é o instrumento e o custo que ele mostra.

| O que o prompt afirma | O que está em `src/` hoje | Veredicto |
|---|---|---|
| "Meça antes de otimizar: use dados reais (Profiler, tempo de tick, contagem de objetos, alocações)" | Tempo de tick: medido e publicado — `last_step_ms`/`worst_step_ms`/`dropped_ticks` ([sim_clock.gd:12-14](../src/core/sim_clock.gd#L12-L14)) cronometrados em µs dentro de [main.gd:337-339](../src/main.gd#L337-L339). Tempo de frame: `TIME_PROCESS` e `TIME_PHYSICS_PROCESS` só no F3 ([hud.gd:248-251](../src/ui/hud.gd#L248-L251)). **Contagem de objetos e de alocações: nenhum monitor do engine é lido no repositório inteiro** (grep de `Performance.`: duas linhas, as duas acima) | **parcial**; o "Profiler" da casa é SimClock + `SubtreeGuard` + F3, e a coluna de alocação não existe como número |
| "Otimize o que dói agora" | A dor está medida e é o boot: geração 936-962 ms e malharia 4.640-4.886 ms com a janela congelada, contra **pior passo de 7,56 a 11,21 ms num orçamento de 50 ms** e `dropped_ticks = 0` nas cinco corridas (`.tools/suite_fix1.log` … `suite_fix4.log`, `.tools/pub-suite.log`) | **correto, e já respondido**: o hot path de simulação não é a dor de hoje; o precedente medido é o mesher, que caiu de ~16 s para ~7,5 s com índice linear |
| "Hot path tem regra diferente: o que roda a cada tick (20 Hz) precisa ser barato" | Decisão/difusão são agendadas pelo relógio de 20 Hz ([sim_clock.gd:5-7](../src/core/sim_clock.gd#L5-L7)); o jogador atualiza por frame de física ([main.gd:334](../src/main.gd#L334)) e lavra/colocação alteram mundo e Éter fora do tick. Locomoção e timers dos lobos também mudam por frame ([wolf.gd:1203-1259](../src/entities/wolf.gd#L1203-L1259)). Com gravação ativa, cópia/ordenação/hash/escrita/flush entram no tick e têm custo medido nas notas abaixo; "só o tick toca o mundo" ainda não é verdade | **correto no relógio, incompleto na autoridade**; é o §06 (dedicado) que cobra essa conta |
| "Alocação é cara: evite arrays, dicionários, objetos e strings no tick quente" | O blackboard é um `Dictionary` novo por lobo por tick ([wolf.gd:911](../src/entities/wolf.gd#L911), 100/s no teto de matilha viva); a difusão aloca um `PackedInt32Array` por canal por passada ([aether_field.gd:122](../src/world/aether_field.gd#L122), 3 a cada 0,25 s). O cache novo chama `keys()` a cada scan e nas expulsões ([wolf.gd:962](../src/entities/wolf.gd#L962), [:648](../src/entities/wolf.gd#L648)). Os tempos de `sim_step` não isolam essas alocações | **válido como restrição**; primeiro a colheita de alocação, não otimização alegada por contagem teórica |
| "LOD é obrigatório em sistemas de IA/simulação" | Não há LOD por distância: os lobos vivos rodam a árvore inteira a cada tick. O que há é throttle temporal — difusão e visão 4×/s, cadáveres 1×/s ([main.gd:27-31](../src/main.gd#L27-L31)) — e varredura de rastros a cada 0,25 s ([wolf.gd:681-682](../src/entities/wolf.gd#L681-L682)), com nova leitura após inspeção | **falso hoje**; a peça tem nome no design (`HotSet`/Véu, §04 e §06) e é P2: sem custo em log, é backlog, não tarefa |
| "Budget explícito: defina e respeite orçamentos de tempo (ex.: HOT minds ≤ X ms)" | Quatro orçamentos são código: 50 ms por passo com teto de 5 passos por frame ([sim_clock.gd:19-29](../src/core/sim_clock.gd#L19-L29)), 400 µs por árvore ([wolf.gd:448-449](../src/entities/wolf.gd#L448-L449); default da classe, 250 µs, em [bt_tree.gd:117-120](../src/ai/behavior/bt_tree.gd#L117-L120)), 2 chunks de malha por frame ([main.gd:28](../src/main.gd#L28)) e 0,25 s de difusão. O "≤ 2,5 ms" do gate de P1 continua `[TARGET]` no §08, e a aritmética (5 × 400 µs = 2 ms) cabe nele sem que nenhum log mostre a soma | **parcial**; orçamento por peça existe, o agregado do gate é alvo sem medição |
| "Observabilidade > micro-otimização cega: se não dá para medir, não dá para saber se melhorou" | Para o tick, dá: a última linha do diagnóstico da suíte publica `pior passo` e `perdidos` ([smoke_test.gd:3482-3484](../tests/smoke_test.gd#L3482-L3484)). Frame e fila de malha só aparecem em janela; BT agora tem colheita no cenário estreito de rastros, sem equivaler ao agregado HOT; custo de alocação não é medido. Hash/escrita/flush agora têm contadores próprios no diagnóstico do journal | **é o débito da colheita de custo**, e é o que trava as cinco linhas acima de virarem otimização |

## Feito nesta sessão

- **Chuva tem dono, a pedra fica molhada só onde vê o céu, e o material opaco virou shader — com a
  banda de indiferença explicada por dois instrumentos em vez de estreitada (dossiê 23 Fase 2, branch
  `feat/elevacao-visual-chuva-23f2`, base `eb218fe`, ponta `78742d6`, **em branch, pouso no registro
  seguinte**).** [`src/rendering/weather.gd`](../src/rendering/weather.gd) é o único dono de
  `chuva`/`molhado`, integra em `_physics_process` com RNG própria (`WEATHER_SEED = 20261123`) e entrega
  o número ao material por `Callable` — a cláusula "só visual" sai do diff (`git diff --name-only
  eb218fe..78742d6 -- src/ai src/items native src/entities/wolf.gd src/world/block_defs.gd
  src/persistence` devolve **vazio**) e da varredura estrutural (`world_refs=0 eter_refs=0
  player_refs=0`). [`src/world/opaque_surface.gd`](../src/world/opaque_surface.gd) é o primeiro
  `ShaderMaterial` opaco do projeto e o alfa do vértice, que a Fase 1 deixou sem comprador, passou a
  carregar a **exposição de céu por coluna** (`EXPOSURE_FALL = 4`, lida uma vez por coluna por rebuild
  — `chunks_lidos=287 col_lidas=73472 esperado=73472 faces_por_coluna=6.24`), de modo que
  `molhamento = molhado × COLOR.a` escurece o beiral e deixa o leito da ravina intocado. Onze checagens
  novas, censo **264 → 275**, e **cinco derivações feitas à mão antes da corrida caíram** com o motivo
  publicado ao lado do número (6→5 uniforme, 64→287 rebuilds, 0,854→0,855, 900/600/300→748/468/280, e a
  banda do Éter que a janela apanha o lobo cavando). A sonda de janela responde as três perguntas do
  §5.4: `SHADER ERROR` **0** em nove stdout, com a testemunha de que o contador vê erro quando ele
  existe (os **4** do `specular_schlick_blurry` de Godot 3); o par fiel **não** coube na banda
  (`topo fracao_ge3=0,9803` contra chão de **0,0000**), o braço (c) voltou à mesa com o número e a mesa
  decidiu contra ele — a causa é a **segunda decodificação sRGB** que o `StandardMaterial3D` fazia,
  medida na cena sintética (+33/255 decodificando o vértice contra **+0,24/255** decodificando a
  amostra) e na cena real (`topo 0,9803 → 0,0000` com o decode devolvido ao tile), e o shader é
  publicado **como está** com o **furo #48** aberto para o `_mat_glass` que ficou na outra matemática; e
  a assinatura pedida sai exata — `topo muda 0,1293 >> abrigo muda 0,0000`, com os 3 136 pixels da caixa
  abrigada sem mudar **um byte**. **O que isso NÃO fecha:** nenhum gate de fase (mandato 4); o boot
  subiu ~200 ms e o que se publica é o **intervalo** 4 907–5 094 ms contra 4 711–4 725 ms da base, porque
  duas corridas da mesma árvore já diferem em 187 ms; a expectativa de "reproduzir os hashes" da abertura
  precisou de correção lida — a simulação ao vivo não é determinística (mandato 3), então o que se mede
  é que a chuva não acrescenta **entrada** à projeção, não o hash igual; e a corrida pareada com
  `--tick-journal=` fica como débito.


- **A água tem o primeiro shader e a primeira partícula do projeto: a onda desloca o vértice do topo,
  o que a malharia sabe viaja no `COLOR`, e o salpico cai onde o corpo cai (dossiê 23, branch
  `feat/elevacao-visual-agua-23`, base `b0ed929`, ponta de código `3c7aae9`, merge `05e8917` —
  **pousada** na `main`).** O pedido é o prompt "Aetherfall: Elevação Visual (Texturas + Água +
  Atmosfera)" com uma cláusula dura — *"Não tocar na IA ou na lógica de gameplay neste prompt — só
  visual"* — e o corte dele: Fase 1 escrita, Fases 2→5 só pauta.
  [src/world/water_surface.gd](../src/world/water_surface.gd) (237 linhas) monta em runtime um
  `ShaderMaterial` cujo GLSL vive numa constante de GDScript (nada importado, por causa do `#25`):
  `vertex()` desloca `VERTEX.y` pela soma de três harmônicas onde `COLOR.r` manda, `fragment()` lê a
  cena por `hint_screen_texture` (refração de uma amostra + reflexão de um passo, Schlick com
  `f0 = 0,02`) e por `hint_depth_texture` a espessura que decide a absorção, com espuma de margem e
  caustica quando o sol está alto. [src/rendering/water_fx.gd](../src/rendering/water_fx.gd) (352
  linhas) põe os dois pools de `GPUParticles3D` (8 salpicos de 24 + 4 bolhas de 40) e os 12 anéis de
  ondulação, com o teto aritmético `8×24 + 12 + 4×40 = 364` impresso e conferido: `soma=364
  teto=364 vivas=41`. **O mesher não se moveu** — `agua nao muda a malha` devolve `base=214448
  espelho=214448 sessao=214448`, e é por isso que a cláusula "só visual" é checagem e não frase:
  `git diff --name-only c05f1df 05e8917 -- src tests` devolve sete arquivos e nada em `src/ai/`,
  `src/entities/` ou `native/`, com `fx_nao_escreve_o_mundo` a fechar a porta do Éter
  (`canais=3  edits_globais=0->0`). Nove checagens novas, censo **255 → 264**, e o pin medido no
  clone limpo com `--import` frio dá **264 / 0 / 53,6 s** (amostrado) e **264 / 0 / 53,8 s**
  (silencioso); a compilação do shader **não** é da suíte — headless não exercita o
  `RenderingDevice` — e o §5.2 é a sonda com janela: `SHADER ERROR` **0** na RX 9060 XT e a fração de
  água na caixa **0,8471** contra **0,0000** no controle da base, com os dois PNGs de controle de
  byte-idênticos. **O que isso NÃO fecha:** nenhum gate de fase (mandato 4); o `SSR`/`ReflectionProbe`
  continuam o braço rejeitado do §3.4; e o vermelho único da régua de 25 ms ficou **com atribuição
  aberta, escrita assim** — as dez corridas, o amostrador do `#31` e o furo `#44` que ele abriu estão
  na seção "O pouso da perna 23 na `main`" abaixo.

- **af-bench re-medido na árvore do pin: a mesma semente devolve o mesmo hash nas 3 execuções, agora
  contra o mundo das pernas 16 e 19 (dossiê 07b, branch `bench/af-bench-boot-walk-07b`, merge
  `35959e0`).** A peça já existia, medida na base `99d1167` (hash `a6addd…`); o AGENTS.md manda
  re-medir quando a `main` andou, e as pernas 16 (tocas) e 19 (auto-pulo) mexeram em `src/` depois
  daquilo. Trazida a `main` para dentro do bench (`git merge main --no-ff`, merge `35959e0`) com o `src/`
  ficando **byte-idêntico ao pin `9b2c65a`** (`git rev-parse HEAD:src` = `64f137bcb1f8…`), as três
  corridas serial de 12 000 ticks deram exit 0, `records == 12000`, `dropped_ticks == 0` e o **mesmo
  hash final `fd9b41e0dc3ae2eb5f4c76cd6467ffc8d6204134354e5f765fbc1f6f6d604a32`** nas três — com os três
  `.jsonl` byte-idênticos (`3e6aaf49b88fc37c…`, 888 894 bytes cada). O hash mudou de `a6addd…` para
  `fd9b41e0…` **porque o mundo mudou** (tocas/spawn na projeção de Éter+lobos), não o instrumento: o
  valor antigo fica como registro da base `99d1167`, não reescrito. Nesta rodada o runner ganhou uma
  linha de `OBSERVACAO` com `gen_ms`/`mesh_ms`/`worst_sim_ms` (o `diagnostics()` de
  [`src/main.gd:1232`](../src/main.gd#L1232)/[:1256](../src/main.gd#L1256) já os tinha, o log não os
  mostrava); é `print`, não gate, e a rodada dupla confirmou que ele **não move o hash**. Tempo: parede
  46,4 s médios, dentro do runner 45,8 s (~262 ticks/s), `gen_ms≈940`/`mesh_ms≈4317`/`worst_sim_ms 13–15`
  por corrida. **O que isso NÃO fecha:** (a) gate de fase fecha o dono do repositório, não esta peça
  (mandato 4); (b) o braço do **bake-off** (dossiê 07 §4) continua faltando — um braço só é medido aqui,
  não dois com `triangles`; (c) o **relógio da guarda** (`estouros_guarda`) segue defeito aberto — agora
  16 estouros nos **mesmos** 8 pares tick/lobo nas três corridas, o que deixa a triplicata "a mesma
  sorte", não prova limpa do determinismo da projeção. Suíte re-rodada na ponta: **255 / 0 / 47,4 s**,
  exit 0. Evidência e as âncoras re-derivadas por conteúdo:
  [readback.md](evidence/af-bench-boot-walk/readback.md), artefatos conferidos por
  [artifacts.sha256](evidence/af-bench-boot-walk/artifacts.sha256) (`sha256sum -c` — os quatro OK).
- **Tocas da alcateia: a matilha nasce espalhada em grupos e o censo diz em quantas tocas cada
  grupo mora (dossiê 16, branch `feat/tocas-da-alcateia-16`, base `99d1167`, ponta de código
  `90c152f`, docs `edab9c8` — **pousada** na `main` pelo merge `--no-ff` `9b2c65a` de 2026-11-23, o pin novo).** O pedido do dono, de
  2026-11-21, foi espalhar a matilha em **2–3 tocas** depois de ele ter percorrido o vale inteiro e
  visto um lobo só; a premissa lida antes do código é a mordaca: os cinco lares do boot cabiam num
  círculo de `PACK_LEASH = 18 m` porque `_pack_leash()` devolvia o lar do **primeiro** lobo vivo,
  enquanto a caixa útil é 116 × 116 m. **O que o código faz hoje:** `_dens`
  ([main.gd:126](../src/main.gd#L126)) é a lista de centros fundados, com teto `DEN_COUNT := 3`
  ([:566](../src/main.gd#L566)), e a pertenca é do lobo (`Wolf.den`,
  [wolf.gd:186](../src/entities/wolf.gd#L186)) mas decidida pela sessão, nunca pelo bicho. `_place_request`
  ([main.gd:730-769](../src/main.gd#L730-L769)) **funda** enquanto couber e, com todas fundadas — ou
  com a fundação recusada havendo ao menos uma — **entra na mais vazia**; fundar exige
  `DEN_MIN_DIST := 48.0` ([:574](../src/main.gd#L574)), cobrado pelo portão `_den_gate_ok`
  ([:605-611](../src/main.gd#L641-L647)) e impresso como separação mínima no chão do centro novo
  ([:681-690](../src/main.gd#L717-L726)); passa pelo mesmo `_spawn_home_point` dos portões da
  perna 14 ([:756-821](../src/main.gd#L792-L857)) com o `gate` novo, então entrar numa toca **não**
  compra segurança: `>= SAFE_SPAWN_DIST` e a visada contra o jogador continuam os dois primeiros.
  A fila de reposição volta **para a mesma toca** ([:373](../src/main.gd#L435)) e o filhote herda a
  do adulto de menor identidade ([:483-484](../src/main.gd#L545-L546)); sem toca onde entrar o bicho
  fica `den = -1` impresso, não disfarçado ([:720-723](../src/main.gd#L782-L785)). O disco ganhou
  chave **aditiva**: `dens` no save ([:1020-1039](../src/main.gd#L1101-L1120)) e `den` no registro do
  animal ([wolf.gd:1372](../src/entities/wolf.gd#L1372), lido em `:1405`), e o default não inventa —
  disco anterior à perna devolve `_dens` vazio e todos `-1`
  ([main.gd:1149-1155](../src/main.gd#L1149-L1155)). A observabilidade é `dens`, `den_min_dist`
  ([:618-625](../src/main.gd#L654-L661)) e `den_components` ([:640-660](../src/main.gd#L676-L696))
  dentro de `diagnostics()` ([:1242-1243](../src/main.gd#L1242-L1243)) — nada no caminho quente — e é
  aí que os furos **#18** e **#21**, ambos com dono escrito antes da primeira linha, foram pagos com
  número (ver as entradas). **Medido nesta árvore:** 3 tocas fundadas no boot com separação mínima
  lida **55,9 m** contra a régua de 48 m, `componentes=3` e `arestas_entre_tocas=0`; o custo do
  espalhamento é pareado contra a base `99d1167` e **não acha diferença atribuível à perna** —
  **−0,70 %** por passo no cenário estreito e **−0,76 %** na janela de matilha, os dois menores que o
  espalhamento de repetir o próprio braço
  ([custo-pareado.md](evidence/tocas-alcateia-16/custo-pareado.md), [Rodada Tocas 16](#rodada-tocas-16--o-custo-do-espalhamento-pareado-medido-com-e-sem-a-perna-2026-11-22-feattocas-da-alcateia-16-base-99d1167-ponta-de-código-90c152f)).
  Contagens: runner de reações **225 → 240** ([aether_reactions_test.gd:64](../tests/aether_reactions_test.gd#L64))
  e suíte **252 → 255 checagens / 0 falhas / 48,0 s**, exit 0
  ([head_suite.log:357](evidence/tocas-alcateia-16/head_suite.log#L357)). **Pin publicado: o merge
  `--no-ff` `9b2c65a`**, com **255 / 0 / 48,6 s** no clone limpo e `--import` frio
  ([pouso_clone_suite.log:357](evidence/tocas-alcateia-16/pouso_clone_suite.log#L357)); substitui o `5b519f8`
  (perna 11, **252 / 0**) como número da `main`; as cinco corridas do pouso estão na seção final.
- **Acasalamento, filhote que cresce e censo variável: o bicho nasce de dois adultos, envelhece,
  e o disco deixa de ser uma lista truncada (dossiê 11, branch `feat/acasalamento-e-censo-11`,
  merge `4b858c2` e fecho `5b519f8` na `main`).** O que estava em aberto quando a página foi escrita: a população
  era a constante `WOLF_COUNT := 5` ([main.gd:9](../src/main.gd#L9)), não existia fase, idade
  nem corpo menor (`DIMS` era constante, [wolf.gd:96](../src/entities/wolf.gd#L96)) e o load
  pareava **por índice** com teto — `for i in mini(saved.size(), wolves.size())`, `main.gd:713`
  da `main` de antes —, de modo que um censo que crescesse **descartaria filhote em silêncio** e
  o bicho que chegava recebia a memória do vizinho. **O que o código faz hoje:** fase, idade e
  cooldown são chaves de registro do animal no disco
  ([wolf.gd:1372](../src/entities/wolf.gd#L1372)), a idade conta um passo por tick
  ([:891](../src/entities/wolf.gd#L891)) e a fase re-escala o corpo inteiro
  (`dims = DIMS * PHASE_SCALE[p_phase]`, [:393](../src/entities/wolf.gd#L393)); o censo tem teto
  próprio ([main.gd:18](../src/main.gd#L18) `CENSUS_CAP := 12`) e o load **recusa** um censo
  acima do teto **antes de qualquer escrita no mundo**
  ([:1066-1070](../src/main.gd#L1147-L1151)), contando a recusa; o pareamento é **por identidade**
  ([:1112-1123](../src/main.gd#L1193-L1204)) — o bicho do disco que a sessão não tem entra no mundo
  ([:1139-1143](../src/main.gd#L1220-L1224)), o bicho da sessão que o disco não tem é aposentado
  ([:1131-1132](../src/main.gd#L1186-L1187)) e a fila de reposição é limpa para o censo gravado
  mandar ([:1152](../src/main.gd#L1233)). O nascimento é procurado no tick
  ([:320](../src/main.gd#L382), `_scan_breeding` [:443](../src/main.gd#L505)), o par entra em
  cooldown de 300 s ([`MATE_COOLDOWN` :564](../src/main.gd#L626)) e o teto recusado é **contado**,
  não mudo ([:472-475](../src/main.gd#L534-L537)). **O journal não se moveu:** o lote novo é
  chave de registro, não campo da projeção mínima, então `FORMAT_VERSION` continua **1** e os
  hashes publicados das rodadas anteriores valem — a checagem 7 fecha nos dois sentidos: o hash
  fica **igual** depois do lote e **muda** quando muda o que está na projeção
  ([aether_reactions_test.gd:3806-3860](../tests/aether_reactions_test.gd#L3806-L3860)).
  `EXPECTED_CHECKS` **221 → 225**
  ([aether_reactions_test.gd:64](../tests/aether_reactions_test.gd#L64)), suíte **252 / 0 falhas**.
  Medido no clone limpo da revisão mescada (`4b858c2`, `--import` frio): runner estreito
  **225 / 0 / 15,451 s** e suíte **252 / 0 / 42,9 s**, exit 0. O vermelho intermitente do runner
  é a checagem "nenhum estouro de subtree no budget" e ele **não** é desta perna — a atribuição
  fecha nos dois braços e está no furo #20. O pin publicado é `5b519f8`; o par de vazamento do
  quit que aparece no stderr é o do som, já debitado abaixo, e ele sai também sem esta perna.
- **Auto-pulo do degrau de um bloco: o lobo sobe, e quem anda com o jogador também sobe
  (dossiê 19, branch `feat/auto-pulo-de-bloco-19`, merge `ab9ffa1` na `main`).** O pedido do dono é
  um defeito em execução, não uma mecânica nova: "os mobs/npcs tem que saber pular os blocos, pois
  ficam bugados e aqui tbm fazer quando estou andando, ter um auto pular o bloco". Lido no código,
  são três causas e nenhuma é pathfinding. **(a) A pergunta mora no integrador:**
  `can_step_over(dir)` ([voxel_body.gd:176-181](../src/entities/voxel_body.gd#L176-L181)) responde
  "a um bloco acima, na direção que eu quero ir, existe onde ficar de pé?" em cima do
  `can_stand_at` que a IA do lobo já chama — um predicado para os dois corpos porque os dois usam o
  mesmo integrador. Cinco braços medidos na grade, com o pé onde o integrador para o corpo
  ([aether_reactions_test.gd:1352](../tests/aether_reactions_test.gd#L1352)): degrau de um bloco
  `true/true`, muro de dois `false/false`, degrau com teto a uma célula do parapeito `true` para o
  lobo e `false` para o jogador de 1,80 m, penhasco de seis `false/false`, direção zero `false`.
  Nenhuma margem no `+1,0`: a célula é exatamente 1,00 m e 0,05 tiraria do lobo de 0,95 m a própria
  célula em que ele cabe. **(b) O lobo:** `STEP_JUMP = 7,6`
  ([wolf.gd:101](../src/entities/wolf.gd#L101)) só é escrito com o corpo no chão **e** o predicado
  aprovando ([:1246-1247](../src/entities/wolf.gd#L1246-L1247)). O impulso antigo de 5,2 dava ápice de
  0,563 m contra os 1,00 m da célula — é aritmética, não teimosia. Vermelho no cenário novo (degrau
  de um bloco no palco da parede): 20 s encostado, `x_max=55,625`, **31 lançamentos**, do lado de
  cá. Verde: `ganho=1,140 m`, `x_max=58,103`, **1 lançamento**, 2,1 s. O braço de indiferença mudou
  de lado como o dossiê previa: contra o muro de seis blocos é `rearms=12 lancamentos=0` (antes
  `lancamentos > 0`) — saltar contra um penhasco é só perder altura. Os dois sorteios de `_rng` do
  desvio continuam incondicionais, senão `tests/simulation_rng_test.gd` passaria a medir outro
  riacho. **(c) O jogador:** `_request_step_jump(wish)`
  ([player.gd:536-542](../src/entities/player.gd#L536-L542)) escreve o **mesmo** `_jump_buffer` que a
  barra de espaço escreve em `_input`, chamado de dentro do `update_local`
  ([:374](../src/entities/player.gd#L374)) — tecla e auto-pulo no mesmo frame somam um salto, nunca
  dois, porque `_apply_vertical` é o único caminho que vira `JUMP_SPEED`. As recusas são as que já
  seguram outros comportamentos daqui: painel, água, planar, rolamento, agachar. Vermelho por
  ablação de runtime (um toggle, nenhum arquivo de gameplay editado): `y_max=51,001 ganho=-0,000 m
  lancamentos=0 frames=300` com `na_face=1 predicado=true` — falta o lançamento, não o chão. Verde
  no mesmo palco com a tecla solta: `y_max=52,334 ganho=1,333 m lancamentos=1 frames=114` (1,9 s).
  O dente da recusa: agachado encosta no **mesmo** degrau que o predicado aprova e não sai do lugar
  — `na_face=191 predicado=true y_max=51,001 lancamentos=0`. **(d) O custo, colhido antes de
  qualquer corte:** os dois braços rodam os mesmos 1 000 frames pelo caminho real do jogo
  (`_physics_process` de [main.gd:333-339](../src/main.gd#L333-L339)) e os números de orçamento
  saem da API pública `diagnostics()` — plano `pior frame 11 302 µs / média 1 386,8 µs / worst_sim
  11,16 ms`, face `8 694 µs / 1 387,7 µs / 8,62 ms` com **982 frames encostado e `lancamentos=0`**,
  `dropped_ticks=0` nos dois. A média não se move (0,9 µs em 1 387) e o passo mais caro continua
  sendo o boot, não o pulo; o braço da face é o pior caso honesto porque ali o predicado é
  perguntado em todo frame de bloqueio e responde "não". Censo: `EXPECTED_CHECKS` **183 → 198**
  ([aether_reactions_test.gd:64](../tests/aether_reactions_test.gd#L64), conferido em
  [:3130](../tests/aether_reactions_test.gd#L3167)), suíte **246 checagens / 0 falhas**. Nada aqui
  fecha gate de fase (mandato 4), e o §8 da rodada está na seção "Rodada Auto-pulo 19" no fim deste
  arquivo.
- **Convivência da alcateia: o chão vale o alvo, o lar não fica na frente do jogador e a matilha
  não se anuncia (dossiê 14).** Três regras do dono — rondar pelo seco com a água como último
  recurso, nenhum aviso de criatura na tela, spawn sempre a distância segura. **(a) Filtro de
  validade do alvo:** `_resolve_dry_target()` ([wolf.gd:764-768](../src/entities/wolf.gd#L764-L768))
  no fim de `sim_step` ([`:912`](../src/entities/wolf.gd#L912)), depois do `_tree.tick`, cobre com
  uma pergunta `_dry_ground` ([:717-724](../src/entities/wolf.gd#L717-L724)) por lobo por passo de
  20 Hz as **quatro** folhas que escreviam alvo sem consultar o solo — `_leaf_flee`
  ([:480](../src/entities/wolf.gd#L480)), `_leaf_chase` ([:503](../src/entities/wolf.gd#L503)),
  `_leaf_stalk` ([:554](../src/entities/wolf.gd#L554)), `_leaf_investigate`
  ([:567](../src/entities/wolf.gd#L567)) — em vez de copiar o teste para dentro de cada uma. Sem
  saída seca no anel o alvo molhado **fica onde está** e o nado segue o caminho que já existe: não
  há fallback que finja ter achado terra (mandato 1). **(b) Travessia com compromisso:**
  `_demand_shore()` ([:743-754](../src/entities/wolf.gd#L743-L754)) reusa `_cross_target`
  ([:289-291](../src/entities/wolf.gd#L289-L291)) enquanto o alvo está de pé e dentro de
  `SCENT_PERIOD` de 0,25 s ([:30](../src/entities/wolf.gd#L30)); `SHORE_AFTER` de 2,0 s
  ([:149](../src/entities/wolf.gd#L149), aplicado em [:901](../src/entities/wolf.gd#L901)) deixou de
  ser porta de tudo e virou chão do estado ensopado. Medido no mesmo cenário: o anel de
  `_shore_point()` rodava **185 vezes em 10,0 s** de água (18,5/s, 0,93 por passo) com
  `trips_solo=3`, e passou a **33** (3,3/s, teto declarado 5/s) com `trips=0`. **(c) Assento de
  célula:** `_scent_seat()` ([:619-632](../src/entities/wolf.gd#L619-L632)) deixa o centro da célula
  farejada com quem tem a menor identidade e espalha os demais em ângulo determinístico do rank a
  uma célula de Éter (4 blocos). Vermelho do chão: **4 lobos** miravam a mesma célula `(16, 12, 15)`
  e o `pior_cluster` era **4** alvos a ≤ 1,0 m entre si, com `alvos_fora_da_celula=0` nos 376 passos
  de investigate; verde: `pior=1`, `cluster=1`, `alvos_fora_da_celula=282`. No mesmo commit, lares
  em colunas distintas — `_home_columns()` ([main.gd:564-574](../src/main.gd#L564-L574)) e a recusa
  da coluna ocupada ([:783-786](../src/main.gd#L845-L848)). **(d) Spawn em bandas com recusa
  impressa:** `SAFE_SPAWN_DIST = 32 m` ([:24](../src/main.gd#L24)) e o predicado único
  `_spawn_point_ok()` ([:730-735](../src/main.gd#L792-L797)) exigem distância **e** visada bloqueada
  por relevo contra a posição **atual** do jogador; bandas 16-46 / 46-70 / 70-borda
  (`SPAWN_BANDS` [:518](../src/main.gd#L580), busca em [:756-828](../src/main.gd#L818-L909)) e a
  vaga recusando para a fila com os motivos contados (`perto`/`visivel`/`coluna`/`molhado`/
  `encaixado`/`vazia`, [:813-815](../src/main.gd#L875-L877)); o centro do mundo — onde o jogador
  nasce — deixou de ser fallback silencioso. Vermelho do sorteio velho: `dentro=1 visiveis=3 de 5`
  (lobo1 a 16,8 m com `los=true`) e reposto a 25,9 m visível; verde: `dentro=0 visiveis=0 de 5`,
  reposto a 39,3 m com `los=false`. O censo passou de premissa a invariante
  (`lobos + fila == teto`, [smoke_test.gd:322](../tests/smoke_test.gd#L322)) e os sítios que
  indexavam `wolves[i]` a mão ganharam guarda com nome — índice caído é checagem vermelha, não
  `SCRIPT ERROR`. **(e) Política de aviso:** saem as duas únicas frases de criatura que existiam
  ("uma nova matilha entrou no vale", "o lobo caiu o sangue fica no eter"); fica
  `stats["wolves_felled"]` ([:990-995](../src/main.gd#L1071-L1076)), que é o que a suíte e o F3 leem,
  e as quatro portas do jogador continuam avisando no mesmo `Label` (craft sem e com material, slot
  vazio, lavra sem espaço — esta confirmando `voxel=3->3`). **(f) Mordaca de matilha:**
  `PACK_LEASH = 18 m` ([:527](../src/main.gd#L589)) sobre o lar de um irmão vivo
  (`_pack_leash()` em `99d1167:src/main.gd:501-505`, hoje `_entrada()` `[:709-713](../src/main.gd#L771-L775)`) era a primeira tentativa de quem chega
  ([:762](../src/main.gd#L824)); os quatro portões continuam medidos contra o **JOGADOR**, então
  chegar perto da matilha nunca compra proximidade — os lares aceitos pela mordaca ficaram a
  **42,5–55,1 m**. É o conserto do furo **#16**: `maior_matilha_lida` **1 → 4** na sessão real com a
  asserção trocada para `biggest >= 2` ([smoke_test.gd:399-404](../tests/smoke_test.gd#L399-L404)).

  Runner de **150 para 183 checagens** e de **30 para 38 cenários**
  ([aether_reactions_test.gd:64](../tests/aether_reactions_test.gd#L64)); a suíte fica em **246**
  porque o furo #16 se paga com a asserção mais forte, não com checagem nova. Vermelhas e verdes,
  com log: [evidence/alcateia-convivio-14/](evidence/alcateia-convivio-14/).

- **Rotinas de alcateia: a matilha entra na decisão do lobo (dossiê 10).** O lobo lê a matilha por um
  `pack_provider` injetado pela sessão ([wolf.gd:208](../src/entities/wolf.gd#L208), montado em
  [main.gd:461](../src/main.gd#L461) com a identidade presa) e a sessão faz **uma** passada por
  passo: cada par `i<j` testado uma vez contra `PACK_COHESION_RADIUS` de 24 m
  ([main.gd:39](../src/main.gd#L39), `_rebuild_packs` [[:859-879](../src/main.gd#L940-L960)]) e
  escrito nos dois buffers; `pack_of` ([:850-852](../src/main.gd#L931-L933)) devolve a lista e o lobo
  só lê (`_read_pack` em [wolf.gd:869-870](../src/entities/wolf.gd#L869-L870), chamado em
  [:906](../src/entities/wolf.gd#L906)). Cinco comportamentos mudam com essa leitura: **ronda** em
  torno do baricentro da matilha com uma fatia angular por rank
  (`_leaf_wander` [[:652-670](../src/entities/wolf.gd#L652-L670)], `_territory_center`
  [[:694](../src/entities/wolf.gd#L694)], `_territory_rank` [[:708](../src/entities/wolf.gd#L708)]);
  **cerco** com assento `TAU/n`, em que `n` conta quem está em `hunt` de fato
  (`_hunt_pack_size` [[:525](../src/entities/wolf.gd#L525)], `_seat_point`
  [[:548-551](../src/entities/wolf.gd#L548-L551)] a 1,50 m da presa por `ENCIRCLE_RING`
  [[:39](../src/entities/wolf.gd#L39)]); **mordida escalonada** por `clock.tick % n == rank`
  (`_bite_turn` [[:793-797](../src/entities/wolf.gd#L793-L797)], chamada em
  [:774](../src/entities/wolf.gd#L774)); **contágio do medo** — vizinho em `flee` soma `0,55` no
  `_fear_level` do observador ([`_sense` 862-871](../src/entities/wolf.gd#L932-L941),
  `PACK_PANIC_FEAR` [[:53](../src/entities/wolf.gd#L53)]); e **amortecimento por confiança** —
  vizinho com `trust ≥ 0,35` corta `0,9` do `_courage` e fecha a porta de `hunt`
  ([:937-946](../src/entities/wolf.gd#L937-L946); a confiança vem de `take_damage`, único chamador de
  `adjust_trust(-0,35)` [:1303](../src/entities/wolf.gd#L1303)). O vizinho **não escreve** no lobo: cada
  um soma o que a sessão devolve, e sem provedor a lista é `NO_PACK`
  ([[:43](../src/entities/wolf.gd#L43)]) — os números do lobo solitário são literalmente os de antes,
  que é o que a checagem `lobo sem provedor nao le matilha` exige. Runner de **119 para 150
  checagens** e de **24 para 30 cenários**
  ([aether_reactions_test.gd:64](../tests/aether_reactions_test.gd#L64)); suíte de **237 para 239**
  com duas checagens novas na sessão real ([smoke_test.gd:388](../tests/smoke_test.gd#L388),
  [:376](../tests/smoke_test.gd#L376)). Verdes, vermelhas e limites, com log por número:
  [evidence/alcateia-rutinas/](evidence/alcateia-rutinas/). **O que a sessão real ainda não exercita
  é o furo #16**: com cinco lares espalhados o raio de coesão devolve no máximo um vizinho
  (`maior_matilha_lida=1`), então cerco, contágio e ronda por setor estão provados em fixture de
  quatro lobos próximos, não no vale — e isso é trabalho da perna 14. **Pago pela perna 14**
  (`6e35b64`): com a mordaca de 18 m sobre o lar de um irmao vivo a mesma linha da sessão real
  devolve `maior_matilha_lida=4`, e a asserção passou a `biggest >= 2` — números e logs em
  [evidence/alcateia-convivio-14/](evidence/alcateia-convivio-14/).

- **Bioma como código, pelo por bioma e viés de imprint (dossiê 09).** `WorldGen` ganha
  `enum Biome` + `biome_of(x, z, h)` ([world_gen.gd](../src/world/world_gen.gd)) e
  `surface_block` passa a consultá-la — a regra fica uma vez só, e nenhum bloco muda de byte: é o
  que a checagem nova da suíte (`bioma_nao_altera_terreno`) confere contra quatro assinaturas
  pinadas de `e7e30e6`, incluindo os 1 048 576 voxels do mundo, porque a amostra de 32 × 32 passou
  verde sobre uma sabotagem de umidade deliberada. O lobo pergunta o bioma do `home` uma vez no
  `setup` ([:309](../src/entities/wolf.gd#L309), re-derivado no `load_state` [:1380](../src/entities/wolf.gd#L1380))
  e pinta o pelo da tabela `FUR_COLORS` ([:160](../src/entities/wolf.gd#L160)) antes de montar o visual. O terceiro
  item da peça — "fundo de Éter por bioma" — entra como **viés de imprint**: o chamador do evento
  multiplica pelo valor lido de `IMPRINT_BIAS`
  (`_imprint` em [wolf.gd:415-417](../src/entities/wolf.gd#L415-L417) e
  [main.gd:1005-1007](../src/main.gd#L1005-L1007)), em 11 sítios; a folha de fuga fica **de fora** por
  custo, com o motivo escrito no código ([:444](../src/entities/wolf.gd#L444)) porque roda todo tick
  com `_threat > 0`. O runner sobe de 109 para **119 checagens** e de 21 para **24 cenários**, com
  o pino literal da tabela linha a linha; a fronteira é checada dos dois lados (viés dentro do
  campo dá 7 falhas e satura `MAX_VALUE 4,0`). Efeitos e limites, com log por número:
  [evidence/bioma-cor-de-pelo/readback.md](evidence/bioma-cor-de-pelo/readback.md).

- **O corpo de 3ª pessoa muda de porte com o que está na mão.** `PlayerAvatar` lê o bloco
  segurado e interpola o braço direito entre porte leve e pesado: `HELD_SIZE 0.24`,
  `HELD_AT (0.06, -0.46, -0.06)`, `LOAD_REF 0.95` e
  `CARRY_SPLAY_LIGHT 0.40` / `CARRY_SPLAY_HEAVY 0.44`
  ([player_avatar.gd:33-56](../src/entities/player_avatar.gd#L33-L56), aplicados em
  `_pose` [:208-211](../src/entities/player_avatar.gd#L208-L211)); o peso vem de
  `BlockDefs.hardness()`, não de uma tabela nova. A mão é a do `Inventory`: `player.gd` escreve
  `avatar.block_id = selected_block()` ([player.gd:403](../src/entities/player.gd#L403)) e o
  atlas vem do mundo, o mesmo do view model ([:187-188](../src/entities/player.gd#L187-L188)),
  então o cubo na mão é o bloco selecionado — a checagem confere `vm=1 mao=1`.
  **A reclamação virou checagem headless**: `bloco na mao passa para fora do braco no quadro da
  orbita` mede a fração da face do cubo que nenhum outro corpo do avatar tapa, no enquadramento
  real da órbita (pivot `feet + (0,1.55,0)`, `dist 4.40`, e com `yaw`/`pitch` zerados porque a
  órbita de trás só existe com o olhar neutro). A atribuição fecha nos dois sentidos: sobre a
  pose anterior **0,02 pedra / 0,00 folha** (vermelho, 1 falha), sobre a atual
  **0,45 / 0,30** (verde), com o corte de 0,15 a meio caminho do pior braço. Instrumento
  independente em janela, por pixels reais: fração visível do cubo passou de
  0,000–0,062 para 0,288–0,405. Suíte final **232 checagens / 0 falhas / 33,7 s**, exit 0.
  Galeria recapturada numa corrida só com a pose nova (11 frames, 1920×1080) e a legenda da
  3ª pessoa no README passou a dizer o que o frame mostra. Nada aqui fecha gate: é corpo e
  câmera, não IA.
  [Notas completas](#porte-do-corpo-em-terceira-pessoa--publicado-em-a8967e0).

- **O jogo tem som, e o som não manda no mundo.** `AudioDirector`
  ([audio_director.gd](../src/audio/audio_director.gd), 619 linhas) nasce com a sessão
  ([main.gd:225-244](../src/main.gd#L225-L244)), assina seis sinais do jogador no `setup`
  ([:146-155](../src/audio/audio_director.gd#L146-L155)) e três por lobo no spawn
  ([:158-162](../src/audio/audio_director.gd#L158-L162), chamado em
  [main.gd:470-471](../src/main.gd#L470-L471)). É a metade "consumidor" do pedido: o
  [set CC0](audio-provenance.md) já estava no repositório com SHA-256 por arquivo; faltava
  ele tocar. **Prova de que toca, medida em janela** (fora da suíte, porque o driver
  headless é `Dummy`): [audio_live_probe.tscn](../tests/audio_live_probe.tscn) rodou a sessão
  real com WASAPI e contou **13 toques em 6 s sem nenhum input** — `step_grass` 6,
  `step_snow` 6, `splash` 1, cama `amb_birds` — com pico de **-7,4 dB no Master**, -9,9 no SFX
  e -7,4 no Ambience ([live-3-green.log](evidence/audio/live-3-green.log)). As três checagens de
  pico e a do driver caem em vermelho se o caminho até o dispositivo não existir; a corrida que
  caiu em Dummy por falha de endpoint foi pega por elas
  ([live-2-red-dummy.log](evidence/audio/live-2-red-dummy.log)).
  **Prova de que não manda em nada**, headless: o hash autoritativo do tick atravessa os nove
  eventos inalterado (`98313688c61a -> 98313688c61a`), a RNG de cada um dos cinco lobos e a da
  população não consomem nada, e `hp=100.0 edits=0 mined=0` depois de morder, minerar e quebrar
  bloco ([audio_test.gd](../tests/audio_test.gd): **73 checagens / 0 falhas**, 6/6 testes,
  [suite-audio.log](evidence/audio/suite-audio.log)). Regressões na mesma árvore: journal **128 / 0**,
  RNG **27 / 0**, rastros **89 / 0** e smoke **220 / 0** — todos com `dropped_ticks = 0`.
  Custo colhido, não prometido: 743 µs de build+setup, ~3 µs por update de
  corpo (1 831 µs em 600 updates), 100 µs por avaliação de ambiência (1/s), 1 627 µs no
  primeiro evento com o cache frio e 665 µs nos 99 seguintes
  ([cost.log](evidence/audio/cost.log)). Dois defeitos de premissa meus, ambos corrigidos no causa:
  o passo de knockback do `simulation_rng_test` chamava o spawn com `audio` ainda nulo e o
  erro derrubava passos em silêncio (corrida vermelha: **9 checagens / 7 falhas**,
  `SCRIPT ERROR: ... 'on_wolf_registered' in base 'Nil'` — hoje o gancho é guardado em
  [main.gd:470-471](../src/main.gd#L470-L471) e a corrida refaz **27 / 0**), e a sonda viva
  contava *famílias novas*, sempre vazio porque os lobos já andavam durante o boot — hoje conta
  incremento por família. O que **não** foi feito de propósito: nenhum som escreve no Éter,
  então o canal SOM do item 4 continua aberto, e o `stop()` de saída não apaga a mensagem de
  vazamento do engine no quit (débito abaixo, com a causa medida em dois braços).
  [Notas completas](#som--publicado-em-a8967e0).

- **Item 2, primeiro recorte — o sorteio tem dono.** `main.gd` e `wolf.gd` eram os únicos
  consumidores do gerador global do Godot; hoje o grep de `randf`/`randi`/`randi_range` sem
  receptor em `src/` devolve zero ocorrências. A matilha é sorteada por `_population_rng`
  ([main.gd:91](../src/main.gd#L91), semeado em [:357-358](../src/main.gd#L419-L420), usado em
  [:321-322](../src/main.gd#L383-L384)) e cada lobo por `_rng`
  ([wolf.gd:215](../src/entities/wolf.gd#L215), semeado em [:311](../src/entities/wolf.gd#L311),
  usado na patrulha ([:660](../src/entities/wolf.gd#L660) e [:677-678](../src/entities/wolf.gd#L677-L678))
  e no desvio ([:1240-1241](../src/entities/wolf.gd#L1240-L1241)); a semente dos dois vem da semente real do
  mundo (`world.gen.world_seed`), não do `SEED` de 32 bits do engine. Suíte nova
  [simulation_rng_test.gd](../tests/simulation_rng_test.gd): vermelho **27 checagens / 11 falhas**
  antes, **27 / 0** depois, em candidato recém-importado; regressões **89 / 0** (rastros),
  **128 / 0** (contrato do journal) e **220 / 0** em cada smoke OFF/ON, todos com
  `dropped_ticks = 0`. [Fontes, premissa e os dois sentidos](#rng-da-matilha--publicado-em-a8967e0).
  O teste também achou uma premissa errada no passo de knockback e ela foi corrigida no instante
  da decisão, não na tolerância — ver as notas. Não é replay nem fecha o item 2: estado inicial
  completo, comandos e ordem autoritativa continuam na fila. O
  [README](../README.md#o-sorteio-da-matilha-tem-dono) traz o comando, o que muda e esses limites.
- **Bloco na mão sem pele sobreposta.** O material do item agora desenha após os dedos:
  prioridade 15 contra 14, conservando atlas, nove segmentos da mão e transparência do
  vidro. Teste com pixels reais: **21 / 0**, repetido em candidato recém-importado;
  smoke **220 / 0**. [Antes/depois e fontes](#bloco-na-mão--publicado-em-a8967e0).
- **Rastros e reações dos três canais atuais.** Lobos aproximam, param por 2 s,
  registram o cheiro sem inventar autoria e suprimem visitas repetidas num cache limitado;
  aumento da força ou expiração permite revisita. Fuga usa campo percebido, visão ou último
  golpe; caça oculta só vai ao avistamento real recente. Golpe interrompe a inspeção, e
  morte da presa fecha a busca mesmo durante a histerese. Candidato final: **89 / 0** no
  teste específico, **128 / 0** no contrato do journal e **220 / 0** em cada smoke OFF/ON.
  Fontes e logs [preservados abaixo](#rastros-e-reações--publicado-em-a8967e0).
  Validação física headless, não aprovação visual em janela nem fechamento de P1.
- **Item 1 — hash mínimo e journal sob demanda.** `TickJournal` assina a projeção
  canônica, preserva todos os Float32 do Éter, recusa arquivo existente e ticks fora de
  sequência, e fecha no load/saída. Teste próprio: 128 checagens; smoke OFF/ON: 220 em
  cada corrida, todos sem falhas. Fontes, limites, custos e logs nas notas abaixo.
  Entrega local; replay e gates de fase continuam abertos.
- **1ª pessoa view model**: braço direito próprio da lente (ombro/cotovelo/punho/dedos),
  ombro em `(0.46, -0.20, -0.16)`, `ARM_YAW 0.34`, arco de lavra e de golpe com três fases,
  bloco segurado na mão. A profundidade é resolvida por camada, não por escalar o braço:
  `no_depth_test` + `render_priority` crescente (braço 10 < manga 11 < antebraço 11 < punho
  12 < dedos 14 < bloco 15) — [fp_viewmodel.gd:232-240](../src/entities/fp_viewmodel.gd#L232-L240),
  251 linhas. A antiga ordem desenhava pele sobre faces opacas; corrigida na medição abaixo.
- **Corpo de 3ª pessoa fora do quadro em 1ª pessoa**, sem FloatingLimb: os membros continuam
  contínuos ao torso quando a câmera está no olho ([player_avatar.gd](../src/entities/player_avatar.gd)).
- **Galeria refeita de uma corrida só** (os 11 PNG publicados hoje vêm da corrida desta sessão,
  [gallery.log](evidence/third-person-carry/gallery.log), 1920×1080, seed 20261116; refeita
  porque o braço de 3ª pessoa mudou de porte — a anterior era `gallery25.log`)
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
  o real é `KNOCKBACK_SPEED = 5.0`, [wolf.gd:46-48](../src/entities/wolf.gd#L46-L48)) e o binding
  de CTRL, que apontava para um intervalo que não continha nenhuma das duas ações.
- **Suíte deixada de ser rolagem de dados** (furo #6 abaixo, agora com causa medida). O passo de
  golpe herdava estado da simulação ao vivo por três portas, e as três foram fechadas: o alvo é
  escolhido entre os vivos ([smoke_test.gd:3370-3371](../tests/smoke_test.gd#L3370-L3371),
  `_alive_wolf()`), a premissa do jogador é montada pelas transições do próprio jogo —
  `respawn_at` e `close_panel`, não campo escrito à mão
  ([smoke_test.gd:3422-3429](../tests/smoke_test.gd#L3422-L3429)) — e o resto da matilha é
  estacionado fora da linha de mira
  ([smoke_test.gd:3436-3450](../tests/smoke_test.gd#L3436-L3450)). A checagem nova
  `mira travada no lobo do passo` ([smoke_test.gd:3451-3457](../tests/smoke_test.gd#L3451-L3457))
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

**Correção visual solicitada em 2026-11-18, antes de editar produção:** a captura do
jogador mostra pele sobre a face do bloco na mão. O material dos dedos usa prioridade 14,
o bloco 13, ambos sem teste de profundidade. Recorte: corrigir a sobreposição no view model,
preservando atlas, animações, vidro transparente e proteção contra paredes; sem mudar IA
ou adicionar outro renderer. Reprodução por comparação de pixels do bloco com/sem a mão.
Concluída com renderização Vulkan isolada e smoke; a avaliação visual dos rastros continua
pendente e não foi substituída por este teste da mão.

**Exceção de ordem autorizada em 2026-11-18, antes de editar produção:** o pedido
“concordo, vamos focar em rastros e reações” prioriza aprofundar WORK/BLOOD/FEAR antes
do item 2. Recorte: investigar, parar no rastro, reconhecer uma visita e reagir ao perigo
percebido sem conhecer a posição oculta do jogador. Sem novos canais, replay ou fases.
A sequência foi cumprida: reprodução vermelha, implementação e regressões headless.

**Exceção de atomicidade registrada em 2026-11-19, antes de criar os commits:** a regra 6
pede um assunto por commit. `src/main.gd` (journal + som + RNG da população) e
`src/entities/wolf.gd` (rastros + RNG por lobo) trazem hunks de assuntos diferentes dentro do
mesmo arquivo, e cortar por hunk exige staging interativo (`git add -i` / `git add -p`), que
não é permitido aqui. Os commits, então, são por arquivo: os assuntos de simulação entram
juntos no commit de código, a mão em 1ª pessoa no seu, o porte em 3ª pessoa junto com a suíte
no dele, e a documentação por último. O que a exceção registra é também a medição: a suíte
verde que se publica é a da árvore completa, re-medida no clone limpo do SHA final; os estados
intermediários dos commits por arquivo não têm log próprio — cada um é consistente em API com
`HEAD` mais o que ele mesmo traz, mas nenhum foi rodado isolado. Os números seguem atrelados
ao assunto de cada um nas notas de medição, não ao commit.

Item 1, refinamento dos rastros e primeiro recorte do item 2 (propriedade dos geradores)
concluídos e validados nesta máquina; falta avaliação visual em janela, que é do dono. A árvore
virou o commit `a8967e0`, publicado em `42799fa`, e o clone limpo dele foi reimportado sem cache e
re-medido: **232 checagens / 0 falhas / 33,7 s**, exit 0 — o mesmo número da árvore de trabalho,
com as 79 fontes e as assinaturas de artefatos conferidas dentro do clone. Os logs de hash anteriores
continuam vinculados ao manifesto histórico; a validação do recorte de RNG tem manifesto próprio
nas notas abaixo. O resto do item 2 — estado inicial completo, comandos, restauração de RNG no
load e ordem autoritativa — não foi iniciado.

**Exceção de ordem autorizada em 2026-11-20 (2), registrada antes de qualquer linha de código:** o
dono pediu duas linhas novas — convivência da alcateia (item 12, dossiê 14) e árvore genealógica de
todo ser vivo com o Éter trabalhando isso (item 13, dossiê 13) — e cada uma com um agente
responsável. As duas escrevem nos mesmos `src/entities/wolf.gd` e `src/main.gd` de escritor único,
então a fila serializada passa a **09 → 10 → 14 → 11 → 12 → 13** (hoje **09 → 10 → 15 → 14 →
11 → 12 → 13**: a perna 15 entrou antes da 14, e a ordem vigente está na Rodada Oráculo 15): o 14
vai logo depois do 10 porque
mexe nas folhas de movimento e nos ajudantes de spawn que a alcateia reorganiza, e porque o
predicado "ponto longe dos olhos do jogador" tem de existir antes de o 11 precisar dele para pôr o
filhote no mundo; o 13 fecha a fila porque ascendência só tem o que gravar depois de existir
nascimento por causa interna. Nada aqui é código: as duas pernas estão abertas como dossiê e nenhum
gate delas foi fechado. A fila acima é a que `5108229` escreveu e `4ac5838` publica, já substituída
pela extensão (3), abaixo deste parágrafo e no contrato. Desde aquela nota, concluídas são **quatro**
— 09, 10, 15 e 14 (a 14 publicada na ponta `630c25a`, pin `d4dee0f`), e o elo aberto seguinte da fila é
a 11.

**Exceção de ordem autorizada em 2026-11-21 (2), registrada antes de qualquer linha de código:** o
defeito em execução do dono (lobos pulsando diante de bloco, jogador parado na frente de um degrau)
abre a perna 19 e ela **fura a fila** para entrar logo depois da 11, porque defeito custa a cada
sessão enquanto as pernas restantes são mecânicas que ainda não existem. A fila passa a **09 → 10 →
15 → 14 → 11 → 19 → 16 → 12 → 17 → 18 → 13** (dossiê
[19](planos/19-auto-pulo-de-bloco.md), branch `feat/auto-pulo-de-bloco-19`, base `8ac761d`). Como as
duas escrevem em `src/entities/wolf.gd` e no runner, a consequência está assumida no §7 do dossiê:
**quando a 19 pousar na `main`, a 11 re-rome o gate** — traz a `main` para dentro de si e roda a
suíte de novo, porque a árvore resultante é outra revisão (item 5 de "Branches"). Estado agora: a
19 pousou na `main` (merge `--no-ff` `ab9ffa1`, clone limpo medido), e a 11 **já re-romeu o gate**
e **pousou**: trouxe a `main` para dentro de si pelo merge `010ab25` (ponta `f33c1d4`) e mediu a
árvore resultante, mergeada na `main` em `4b858c2`; o fecho dela virou a `main` `5b519f8`, que é o
pin publicado, porque o número medido é o da revisão **mescada** — o clone limpo dela, com
`--import` frio, está em [`docs/evidence/acasalamento-censo-11/readback.md`](evidence/acasalamento-censo-11/readback.md).

**Pauta re-escrita em 2026-11-22, sem exceção de ordem:** a perna 12 (bicho cavando voxel) tinha uma
página escrita em 2026-11-20 sobre uma árvore cinco pernas menor, e ela foi re-escrita contra a de hoje
([`docs/planos/12-bicho-cavando-voxel.md`](planos/12-bicho-cavando-voxel.md)). A fila **não** muda —
continua **09 → 10 → 15 → 14 → 11 → 19 → 16 → 12 → 17 → 18 → 13**, com a 12 depois da 16 porque as duas
escrevem `src/main.gd` e é a 16 quem decide onde os lares ficam — e o que muda é o **conteúdo** da
pauta, lido no código de hoje: o elo (a) de cavar passa a ser o **terceiro** ramo do `if` de bloqueio
que a 19 escreveu ([wolf.gd:1239-1254](../src/entities/wolf.gd#L1239-L1254)) em vez de folha nova, a lista de
material substitui a dureza como critério (dureza é tempo, não permissão), o gate deixa de observar
`block_changed` — que não tem consumidor nenhum — e passa a observar `get_block` + `world.edits`, o
fork A/B é decidido por `intent` entrar no hash do journal, quem cava se decide pelo alcance do corpo
(`PHASE_SCALE` 0,45 do filhote) e o palco de teste tem de escrever com `record = false`, porque parede
de `_wall` é construção registrada. Disso nascem os furos **#22** (fechado por construção pela cláusula
`not world.edits.has(pos)`) e **#23** (dono perna 05). Nenhuma linha de código foi escrita **por esta
leitura**, nenhuma constante de versão foi tocada e a branch ainda não tinha aberto; os três números
publicados naquele dia eram os da perna 11 (**252 / 0** na suíte no pin `5b519f8`, **225** no runner de
reações, **27** no de RNG). **O lote escreveu o código depois disso:** `feat/bicho-cavando-12` abriu da
`main` de `dcbcbe8` e os itens (a)→(g) pousaram nela um assunto por commit — a conta do §5 do dossiê e a
Rodada Cavar 12 no fim deste arquivo trazem os números de hoje, com o runner em **283**.

**Perna 16: aberta 2026-11-22, pousada 2026-11-23, sem exceção de ordem.** A fila não mudou: **09 → 10 →
15 → 14 → 11 → 19 → 16 → 12 → 17 → 18 → 13**, porque a 16 foi aberta da `main` no ponto atual (`99d1167`)
e a 12 vem depois dela justamente porque as duas escrevem `src/main.gd` e é a 16 quem decide onde os lares
ficam. A branch `feat/tocas-da-alcateia-16` fechou com seis commits de código (`af04504` → `90c152f`, um
assunto cada, com a suíte verde entre eles), um de medição pareada (`ab4d4c3`) e a passada de docs
(`edab9c8`, citações re-derivadas nos 28 arquivos que o crescimento de `main.gd` e `wolf.gd` alcançou), e
entrou na `main` pelo merge `--no-ff` `9b2c65a`, que é o pin medido no clone limpo: **255 / 0 / 48,6 s** de
suíte e **240 / 0 / 24,138 s** de runner. Os dois débitos que a perna abriu seguem abertos e escritos: a
atribuição do par de vazamento do quit, que saiu num run e não saiu no outro, e a alocação do `_dens`/das
travessias de `den_components`, que colheita nenhuma mede. O que muda para a frente é a posição da 12:
`block_changed` continua sem consumidor nenhum, e quem o assina é a 17 — a pauta re-escrita da 12 tinha
deixado o gate dela observando `get_block` + `world.edits` justamente por isso.
`feat/bicho-cavando-12`, que esperava o pouso da 16, abriu da `main` de `dcbcbe8` e é o elo que esta
rodada fecha.

**Pauta aberta em 2026-11-22 (3), com exceção de ordem registrada antes de qualquer linha:** o dono
mandou pôr em pauta o prompt que ele mesmo chamou de "Prompt Master — Inteligência Autônoma de Mobs +
Ecossistema Vivo". A autorização é para a **pauta**, não para o código:
[`docs/planos/20-mente-autonoma-de-mobs-e-ecossistema.md`](planos/20-mente-autonoma-de-mobs-e-ecossistema.md)
existe, e existem no contrato a branch `feat/mobs-autonomos-e-ecossistema-20` e o agente responsável
`mente-eco-20`; **nenhuma linha de `src/` foi escrita por esta leitura**. A fila serializada passou a
**09 → 10 → 15 → 14 → 11 → 19 → 16 ✅ → 12 ✅ → 17 → 18 → 20 → 13**, e a 16 já cumpriu a sua posição — a
fila **viva de hoje** é **17 → 18 → 20 → 13**: depois da 18 porque as duas escrevem
[`src/world/block_defs.gd`](../src/world/block_defs.gd), a 17 gasta o id 18 e a 18 o id 17, e drop de
criatura **não pode** encostar na reserva 9–18 — entra a partir de 23; antes da 13 porque árvore
genealógica sobre **uma única** espécie escreveria o que já existe, e a 13 continua última pelo motivo
de sempre: nenhuma mudança de `Channel.COUNT` no meio da fila. Nada deste lote encosta em
`Channel.COUNT`, `FORMAT_VERSION` nem `GEN_VERSION`. A pauta foi escrita contra a `main` de `99d1167`, e
**a 16 pousou depois disso**: as árvores de `9b2c65a` (`src` = `64f137bc…`, `tests` = `88a1541c…`) **não
são** as do `5b519f8` (`30873d66…` / `975eac5a…`), então o contrato de referência desta pauta é o da main
do pouso — **255 / 0** na suíte, **240 / 0** no runner de reações — e não o **252 / 0 / 42,4 s** que a
página carregava. O que passou a existir e a pauta ainda não citava: **tocas** — `var _dens`
([main.gd:136](../src/main.gd#L136)), `den_components()` ([`:692`](../src/main.gd#L697)),
`Wolf.den` ([wolf.gd:186](../src/entities/wolf.gd#L186)) e a chave `den` no disco. Da leitura saem os
furos **#24** e **#25** abaixo, e três frases do prompt devolvem diferente: drops não são "fracos", **não
existem**; `died` **não** é sinal órfão — tem dois consumidores em `src/`, nenhum dos dois um item; e o
leito `amb_birds` tocando sem ave nenhuma no mundo é ambiência de campo aberto correta, não defeito do
tipo da 19.

**Pauta autorizada em 2026-11-24, Fase 1 pousada e Fase 2 com código e docs na branch: o prompt
"Elevação Visual (Texturas + Água + Atmosfera)", cinco fases.** A página é
[`docs/planos/23-elevacao-visual-agua.md`](planos/23-elevacao-visual-agua.md), o código da Fase 1 está no
merge `05e8917` e a rodada "O pouso da perna 23" abaixo traz as corridas. A **Fase 2** (chuva e
superfícies molhadas) abriu como código em `feat/elevacao-visual-chuva-23f2`, base `eb218fe`, worktree
separado `.qoder/worktrees/elevacao-chuva-23f2`, corte no §3.10, gate no §5.3 e sonda no §5.4; o registro
de abertura, com as quatro frases que a leitura da árvore devolveu diferente, está no
[`AGENTS.md`](../AGENTS.md) como "Registro de 2026-11-25". **O que está fechado na branch e ainda não
pousou:** os onze passos novos com censo **264 → 275**, o `Weather` como dono de `chuva`/`molhado`, o
material opaco virando `ShaderMaterial` com a exposição de céu no alfa do vértice, os dois emissores de
chuva com teto 748, a água lendo o mesmo termômetro, e a sonda de janela respondendo as três perguntas
do §5.4 — tudo na rodada "Rodada 2026-11-25 (2)" abaixo, com o pin em `78742d6` (suíte **275/2**, runner
**292/7** com os mesmos sete vermelhos da base, RNG **27/0**, journal **128/0**). O que **continua em
andamento** são três coisas: (1) as **Fases 3→5** — vegetação viva, `Environment` de névoa/Glow e os
materiais dos blocos — autorizadas **como pauta dentro da mesma perna**, cada uma com gate próprio e na
dependência da anterior (§3.9); (2) a **atribuição do vermelho de 25,76 ms**, que ficou aberta
escrita assim, com o dono de pagar a dívida sendo a próxima perna que rodar a suíte nesta árvore com
o amostrador ligado; (3) a fila serializada, que volta a **22 → 17 → 18 → 20 → 13** no pouso da 23 — a
23 entrou na frente de todas por decisão do dono, e a 22 ainda está em voo na árvore primária.

## Falta

Por dependência, não por preferência (cada item aberto tem um dossiê de leitura em [`docs/planos/`](planos/README.md): premissa nomeada, estado do código com `arquivo:linha`, gate headless e custo pelas quatro perguntas — nenhum dossiê rodou a engine e nenhum fecha gate):

1. **Primitivo de hash de estado por tick — concluído e validado nesta máquina.** Implementado em
   [tick_journal.gd](../src/persistence/tick_journal.gd), com contrato, testes e medições abaixo.
   Mantida a numeração original para não mudar as dependências da fila.
2. **Diário de tick sobre a simulação — um recorte concluído e validado nesta máquina.** O journal mínimo
   registra somente `[tick, hash]`. O sorteio deixou de ser o gerador global: a sessão tem
   `_population_rng` ([main.gd:91](../src/main.gd#L91), semeada em
   [:357-358](../src/main.gd#L419-L420) e sorteada em
   [:778-779](../src/main.gd#L840-L841)) e cada lobo tem `_rng`
   ([wolf.gd:215](../src/entities/wolf.gd#L215), semeado em
   [:311](../src/entities/wolf.gd#L311), usado na ronda
   ([:660](../src/entities/wolf.gd#L660), [:677-678](../src/entities/wolf.gd#L677-L678)) e no
   desvio ([:1240-1241](../src/entities/wolf.gd#L1240-L1241)).
   Isso é pré-condição de replay, não replay: faltam estado inicial completo, comandos e
   ordem autoritativa — o jogador e os corpos ainda mudam por frame. O save continua
   guardando edições para reconstruir terreno, não para reproduzir uma tarde.
3. **Cenário do lobo em 20 sementes × 1000 ticks** — headless, com a mesma semente gerando o
   mesmo hash 1000 ticks à frente. Pressupõe 1 e 2.
4. **Canais morte / som / fogo** em `AetherField`: entram como mais uma entrada nas três
   tabelas paralelas de [aether_field.gd:11-15](../src/world/aether_field.gd#L11-L15) e uma cor
   em [aether_viz.gd:12-16](../src/rendering/aether_viz.gd#L12-L16), com imprint em cada fonte
   (morte de mob, tiro/passo, lava/fogueira) e leitura nas curvas de utilidade. Não é cosmético:
   os três canais já guiam investigação e fuga sem visão do jogador, e `pass_cut` mede só eles.
   **O som que entrou nesta sessão não fecha nada daqui:** o diretor é puro leitor — grep de
   `aether`/`imprint` em [audio_director.gd](../src/audio/audio_director.gd) devolve zero
   ocorrências, nenhum passo de áudio escreve no campo. O canal SOM continua sendo imprint de
   fonte (morte, tiro, passo) lido por curva de utilidade, e não existe ainda.
5. **Budget HOT medido e publicado.** Estender a colheita estreita de `_guard.last_us` e
   `_guard.trips` para cada lobo simultaneamente na suíte headless, imprimir o agregado e
   gatear. Distinguir custo da árvore de percepção/utilidade; 250 µs é o default da classe,
   400 µs é o configurado em [wolf.gd:448-449](../src/entities/wolf.gd#L448-L449). Gate subtrativo: nenhuma mente nova entra
   antes do budget da existente estar escrito.
6. **Difusão do Éter fora do tick de decisão.** Hoje a difusão roda na passada do relógio
   ([main.gd:27](../src/main.gd#L27) `AETHER_PERIOD 0.25`); com 6 canais e a malha competindo,
   é o primeiro candidato a thread.
7. **Decompor `main.gd`** pelo eixo certo: um dono por sistema (sessão, matilha, HUD, oráculo,
   visualização), preservando o acesso ao estado. A autoridade temporal ainda não é única:
   jogador, corpos dos lobos e timers também mudam por frame.
8. **Bioma como código, cor do pelo por bioma e fundo de Éter por bioma — concluído nesta máquina
   (dossiê 09; mantida a numeração para não mexer nas dependências da fila).** O identificador existe:
   `enum Biome` ([world_gen.gd:32](../src/world/world_gen.gd#L32)) e `biome_of(x, z, h)`
   ([:129](../src/world/world_gen.gd#L129)) decidem a partir das mesmas duas ruídos e da altura, e
   `surface_block` ([:165-166](../src/world/world_gen.gd#L165-L166)) consulta em vez de repetir a
   regra — nenhum byte de bloco muda, e a suíte confere isso contra as assinaturas pinadas de
   `e7e30e6`. A cor do pelo vem do bioma do `home` ([wolf.gd:160](../src/entities/wolf.gd#L160),
   aplicada em [:1453](../src/entities/wolf.gd#L1453)). O "fundo" entrou como **viés de imprint**
   (`IMPRINT_BIAS` em [world_gen.gd:45](../src/world/world_gen.gd#L45), lido em
   [:156-157](../src/world/world_gen.gd#L156-L157), multiplicado pelo chamador), que é a forma que o
   dossiê §3.3 escolheu: o campo continua sem saber de mundo. Fica **de fora** e aberto: a avaliação
   visual em janela (a galeria não foi re-bakeada, e o dossiê §6 proíbe prometer "bioma deserto" sem
   re-bake), o bioma lido por outras peças além do pelo e do imprint, e o cenário multi-semente (item
   3). Medição, sabotagens e limites:
   [evidence/bioma-cor-de-pelo/readback.md](evidence/bioma-cor-de-pelo/readback.md).
9. **Rotinas de alcateia — concluído nesta máquina (dossiê 10; mantida a numeração para não mexer
   nas dependências da fila).** A árvore deixou de ser de um lobo solitário: o `Selector[flee, hunt,
   sniff, patrol]` ([wolf.gd:448-449](../src/entities/wolf.gd#L448-L449)) continua a mesma forma, e o
   que mudou é o que entra nas folhas. O lobo recebe a matilha por `pack_provider`
   ([wolf.gd:208](../src/entities/wolf.gd#L208), montado em [main.gd:461](../src/main.gd#L461)), lê
   uma vez por passo ([:869-870](../src/entities/wolf.gd#L869-L870), chamado em
   [:906](../src/entities/wolf.gd#L906)) e o contexto do escorredor leva o pacote
   ([:862](../src/entities/wolf.gd#L862), `["_pack", "pack_panic", "pack_trust", ...]`). Ronda sai do
   `home` individual e vai para o baricentro com fatia por rank
   ([:652-670](../src/entities/wolf.gd#L652-L670), [:694](../src/entities/wolf.gd#L694),
   [:708](../src/entities/wolf.gd#L708)); o cerco tem assento angular função de quem caa
   ([:525](../src/entities/wolf.gd#L525), [:548-551](../src/entities/wolf.gd#L548-L551)); a mordida é
   escalonada pelo `clock.tick` ([:793-797](../src/entities/wolf.gd#L793-L797)); o medo do vizinho
   soma no `_fear_level` ([:932-941](../src/entities/wolf.gd#L932-L941)) e a confiança do vizinho
   amansa o `_courage` ([:937-946](../src/entities/wolf.gd#L937-L946)). Continua **aberto** e não é
   deste item: a memória compartilhada *entre matilhas* — `Mind.relations` ainda é confiança por
   **ator** ([mind.gd:26](../src/ai/mind.gd#L26), [:154-159](../src/ai/mind.gd#L154-L159)), não por
   matilha, e nada decide se a lembrança de um vizinho ajuda o jogador; o HOT agregado dos cinco
   lobos (item 5); a água como último recurso, o spawn fora dos olhos do jogador e os avisos de
   criatura na tela (item 12, dossiê 14); e `MindsInspector`, que não existe (dossiê 08) — sem ele a
   matilha lida se lê no log do runner, não no F3. E a sessão real ainda não exerce o que a fixture
   prova: furo #16.
10. **Acasalamento, filhote que cresce e censo variável — concluído nesta ponta (dossiê 11).** O que
    estava em aberto quando a página foi escrita: a população era uma constante
    ([main.gd:9](../src/main.gd#L9) `WOLF_COUNT := 5`), não existia idade, filhote nem corpo menor
    (`DIMS` é constante, [wolf.gd:96](../src/entities/wolf.gd#L96)) e o load pareava por índice com
    teto — `for i in mini(saved.size(), wolves.size())` —, de modo que um
    censo que crescesse **descartaria filhote em silêncio**. **É o que o código faz hoje:** fase,
    idade e cooldown são chaves de registro do animal
    ([wolf.gd:1372](../src/entities/wolf.gd#L1372)), o censo tem teto próprio
    ([main.gd:18](../src/main.gd#L18) `CENSUS_CAP := 12`) e o load pareia **por identidade**
    ([main.gd:1182-1224](../src/main.gd#L1182-L1224)) — o bicho do disco que a sessão não tem entra no
    mundo, o bicho da sessão que o disco não tem é aposentado, e a fila de reposição é limpa para
    o censo gravado mandar. A conta do boot também mudou de forma: o journal exige
    `wolves.size() + fila == Main.WOLF_COUNT`
    ([tests/tick_journal_test.gd:80-85](../tests/tick_journal_test.gd#L80-L85)), porque o spawn real
    pode recusar ponto e devolver a vaga. As checagens que sustentam isso estão em §"Feito nesta
    sessão" e em [`planos/11-acasalamento-filhote-e-censo.md`](planos/11-acasalamento-filhote-e-censo.md).
11. **Bicho cavando voxel — concluído nesta ponta (dossiê 12).** A lavra contínua do jogador **já existe
    e já tem gate**:
    segurar `break_block` soma progresso por frame até a dureza
    ([player.gd:654-665](../src/entities/player.gd#L654-L665)), o drop do registro entra direto no
    inventário ([player.gd:677-690](../src/entities/player.gd#L677-L690)), e a suíte confere as três
    promessas ([tests/smoke_test.gd:2454-2462](../tests/smoke_test.gd#L2454-L2462) — "segurar break
    minerou", "tempo de mineracao == dureza", "lavra entrou no inventario como drop"). O buraco real
    **era** do outro lado: até este lote os únicos dois `world.set_block` de gameplay no `src/` eram os
    do jogador (`:685`, `:711`) e o único WORK impresso vinha do `acted` do jogador
    ([main.gd:1010-1015](../src/main.gd#L1010-L1015)). Nenhum animal escrevia no mundo — e a perna 19, que
    pousou depois, ensinou o lobo a **subir** o obstáculo, não a removê-lo. **Há um terceiro
    `set_block`, o da pata** ([wolf.gd:1192](../src/entities/wolf.gd#L1192)), com a mesma pegada WORK do
    jogador ([`:1197`](../src/entities/wolf.gd#L1197)).
    **Pauta re-escrita em 2026-11-22** contra a árvore em que as pernas 09, 10, 14, 15, 11 e 19 já
    pousaram e a 16 já tem página: o número desta linha é o da fila de 2026-11-20 e fica (furo #14),
    mas o conteúdo mudou de estado. Três coisas que a página antiga afirmava e a leitura de hoje
    devolve diferente: `hardness` é **duração**, não permissão, então `STONE 0,95` cai em 0,95 s de mão
    nua e o que limita a pata é **lista de material** ([`:663-664`](../src/entities/player.gd#L663-L664),
    [`:685`](../src/entities/player.gd#L685)); `block_changed` **não tem consumidor**
    ([voxel_world.gd:6](../src/world/voxel_world.gd#L6), [`:336`](../src/world/voxel_world.gd#L336)),
    então o gate observa `get_block` + `world.edits` e quem assina o sinal continua sendo a 17; e o
    desemperto ganhou o segundo ramo da 19
    ([wolf.gd:1239-1254](../src/entities/wolf.gd#L1239-L1254)), então cavar é o **terceiro** ramo do mesmo
    `if`, não uma folha nova na `Selector`. A re-escrita abre os furos **#22** (bancada removida por
    bicho deixaria `_benches` apontando para o ar) e **#23** (permeabilidade amostra um voxel por célula
    de Éter, e "menos barreira" não é observável) e fecha o #22 por construção com
    `not world.edits.has(pos)`. **A perna escreveu o código depois desta leitura:** os itens (a)→(g)
    pousaram em `feat/bicho-cavando-12` sobre a `main` de `dcbcbe8`, com nove checagens novas no runner
    de reações (censo **283**) e a suíte parada em **255** porque o lote não toca `smoke_test.gd`; a
    rodada está escrita no fim deste arquivo.
12. **Convivência da alcateia: ronda em terra, nenhum aviso de criatura na tela, spawn fora dos
    olhos do jogador — concluído nesta ponta (dossiê 14; **executava entre o item 9 e o item 10**
    pela ordem serializada registrada em [`AGENTS.md`](../AGENTS.md), e a numeração fica no fim para
    não renumerar a fila).** O que ela deixou no código, com as 33 checagens dos oito cenários que a
    sustentam, está
    em §"Feito nesta sessão" e em [`planos/14-convivio-da-alcateia.md`](planos/14-convivio-da-alcateia.md).
    Os três buracos continuam escritos aqui como foram lidos **na revisão de abertura da perna
    (`f2823a8`)** — os números deste parágrafo são os daquela árvore, não os de hoje. (a) Aviso de
    criatura **existia**: `f2823a8:src/main.gd:242` (`hud.show_message("uma nova matilha entrou no vale")`) e
    `f2823a8:src/main.gd:483` (`hud.show_message("o lobo caiu  o sangue fica no eter")`) eram os únicos
    dois textos que noticiavam *quem está no mundo* — os outros dez sítios de `show_message`
    (`f2823a8:src/main.gd:135`, `:273`, `:451` repassando `player.notice` de
    `f2823a8:src/entities/player.gd:309`, `:664`, `:682`, conectado em
    `f2823a8:src/main.gd:121`, `:524`, `:526`, `:532`, `:536`, `:572` e
    `f2823a8:src/ui/hud.gd:603`/`:605`) são feedback de ação do próprio jogador ou
    diagnóstico de save, e ficaram. (b) O spawn **não sabia onde o jogador estava**:
    `_random_ground_point(16.0, 46.0)` (`f2823a8:src/main.gd:300-314`) sorteava o anel
    em torno de `spawn_point()` (`f2823a8:src/main.gd:206-209`), o centro fixo do mundo, e não
    o ponto onde o jogador acordou nem para onde ele caminhou; exigia coluna seca
    (`y > VoxelConfig.SEA_LEVEL`) e volume livre (`_volume_clear`
    `f2823a8:src/main.gd:322-324`), **não** consultava posição atual nem
    `world.line_of_sight` (`f2823a8:src/world/voxel_world.gd:393`), e depois de 24
    tentativas caía em silêncio no centro. A distância de 16 m era, ali, acidental no boot — o
    jogador nasce no centro — e inexistente depois que ele anda. (c) A água era evitada por **uma
    folha de cinco**: `_leaf_wander` (`f2823a8:src/entities/wolf.gd:476-494`) rejeitava
    ponto molhado via `_dry_ground` (`f2823a8:src/entities/wolf.gd:541-545`) e `SHORE_AFTER`
    de 2,0 s (`f2823a8:src/entities/wolf.gd:79`, aplicado em `sim_step`
    `f2823a8:src/entities/wolf.gd:677-683` com `_shore_point`
    `f2823a8:src/entities/wolf.gd:549-559`) resgatava quem ficou nadando, mas `_leaf_flee`
    (`f2823a8:src/entities/wolf.gd:358`), `_leaf_chase` (`f2823a8:src/entities/wolf.gd:374`/`:378`),
    `_leaf_stalk` (`f2823a8:src/entities/wolf.gd:417`) e `_leaf_investigate`
    (`f2823a8:src/entities/wolf.gd:435`) escolhiam alvo sem nenhum teste de solo — correr atrás do
    jogador através do lago e farejar no leito eram alcançáveis. O "não parecer desorganizado"
    **não** foi comportamento novo: assento angular e mordida escalonada são do dossiê 10, e esta
    perna não reabriu o que ele fecha.
13. **Árvore genealógica de todo ser vivo, com o Éter trabalhando isso** (dossiê 13; **executa por
    último**, depois do item 12). O recorte lido antes de prometer nível: `src/entities/` são
    [`player.gd`](../src/entities/player.gd),
    [`player_avatar.gd`](../src/entities/player_avatar.gd),
    [`fp_viewmodel.gd`](../src/entities/fp_viewmodel.gd),
    [`voxel_body.gd`](../src/entities/voxel_body.gd) e
    [`wolf.gd`](../src/entities/wolf.gd) — **nenhum NPC** e **uma única
    espécie animal**, então a escada animal→humano fica `[TARGET]` até existir o segundo comprador.
    O que falta é o primitivo: a personalidade de cada lobo é sorteada da semente **dele mesmo**
    (`Mind._init` [mind.gd:30-38](../src/ai/mind.gd#L30-L38), chamado com `1000 + identity` em
    [wolf.gd:313](../src/entities/wolf.gd#L313)) e nenhum pai contribui com um valor; o pelo vem do
    bioma do lar ([wolf.gd:160-165](../src/entities/wolf.gd#L160-L165), `home_biome`
    [:309](../src/entities/wolf.gd#L309), re-derivado no load [:1380](../src/entities/wolf.gd#L1380)),
    não de herança; `state_dict` ([:1360-1365](../src/entities/wolf.gd#L1360-L1365)) não tem chave de
    ascendência e nada em `src/` guarda quem é filho de quem. O guard-rail do Éter vai registrado
    junto do dossiê, não descoberto depois: canal novo no campo (`Channel.COUNT` em
    [aether_field.gd:9](../src/world/aether_field.gd#L9)) ou campo novo na projeção do journal
    ([tick_journal.gd:16-44](../src/persistence/tick_journal.gd#L16-L44), `FORMAT_VERSION`
    [:4](../src/persistence/tick_journal.gd#L4)) muda os hashes que as rodadas publicadas registram
    — é decisão de versão, não detalhe de implementação.
14. **Mentes autônomas de mobs e o mundo que respira sem input** (dossiê 20; **pauta autorizada pelo
    dono em 2026-11-22**, na fila depois da 18 e antes da 13 — nenhuma linha de código escrita). O pedido
    chega em sete entregas — avaliação de alcance, memória de falha, tabela de espécie, três grupos de
    criaturas, drops, troféu colocável e os testes disso — e o que a página entrega é o **corte**: cada
    §3 nomeia a decisão, o braço rejeitado e o número que reabre o braço. O estado lido, pelo que faz o
    gate nascer vermelho: **nenhum item nasce de nenhuma morte** — o `die()` do lobo escreve BLOOD e FEAR
    ([wolf.gd:1319-1320](../src/entities/wolf.gd#L1319-L1320)), arma o timer de cadáver
    ([:1321](../src/entities/wolf.gd#L1321)) e só então emite `died` ([:1322](../src/entities/wolf.gd#L1322)),
    cujos **dois** consumidores somam um contador de abate ([main.gd:1046](../src/main.gd#L1046)) e tocam um
    som ([audio_director.gd:412](../src/audio/audio_director.gd#L412)); a sonda de alcance do pulo é
    **fixa de uma célula** — `can_step_over` testa `feet + (x, 1.0, z)` em
    [voxel_body.gd:176-181](../src/entities/voxel_body.gd#L176-L181) — enquanto o ápice do impulso é
    1,203 m (`STEP_JUMP` 7,6 em [wolf.gd:101](../src/entities/wolf.gd#L101) contra gravidade 24 em
    [voxel_body.gd:17](../src/entities/voxel_body.gd#L17)); **não existe tabela de espécie** — `SPECIES`,
    `archetype` e `species` dão zero ocorrências em `src/`, e o que há é a string `mind.kind = "wolf"`
    ([mind.gd:17](../src/ai/mind.gd#L17)); **item é id de bloco**
    ([inventory.gd:29](../src/items/inventory.gd#L29)), com 9–18 reservados por documento
    ([block_defs.gd:10-24](../src/world/block_defs.gd#L10-L24), `COUNT = 23` em
    [`:37`](../src/world/block_defs.gd#L37)) e **nenhum pathfinding** (grep de `NavigationAgent` em
    `src/` devolve zero — "contornar" é steering + reeleição de alvo). O que a perna **não** faz, escrito
    antes: folha nova na `Selector`, classe `Blackboard`, canal novo no Éter (é débito do dossiê 03) e
    `SpeciesDef` como `.tres` — o predado de espécie entra como dados construídos uma vez, no padrão de
    [`block_defs.gd:123-137`](../src/world/block_defs.gd#L123-L137).
15. **As Fases 3→5 do prompt visual** (dossiê 23; **autorizadas como pauta dentro da mesma perna**, com
    a Fase 1 pousada em `05e8917` e a **Fase 2 em voo** — o que cada uma exige, lido no §3.9 e, para a
    Fase 2, no §3.10 da página: a **Fase 2** (chuva e superfícies molhadas) não tinha o que ligar — não
    existia variável de clima (o sol é constante) e o material opaco era um `StandardMaterial3D` único
    por mundo
    (`eb218fe:src/world/voxel_world.gd:91-96`, a árvore desta leitura), então ela é `Weather` como dono
    um estado lido pelo FX **e** pelo material, e o primeiro comprador de `shader` no opaco; a
    **Fase 3** (vegetação viva) **perdeu o canal livre** que a pauta lhe oferecia — a Fase 2 gasta o
    alfa do `COLOR` opaco, que era constante `1.0` e não tinha leitor
    (`eb218fe:src/world/voxel_world.gd:689`), e grama e folha entram no mesmo surface com
    o jitter `0,012` de
    [voxel_world.gd:600](../src/world/voxel_world.gd#L600), então o portador dela passa a ser o atributo
    custom (`ARRAY_DATA`) do §3.3, que a Fase 2 transforma em peça com comprador real em vez de
    hipótese; a **Fase 4** (atmosfera) tem hoje
    `fog_enabled` e `fog_density = 0,006` escritos à mão dentro de `_build_environment`
    ([main.gd:1365-1369](../src/main.gd#L1365-L1369)) — height fog pede `Environment` em recurso
    versionado, e god rays em `forward_plus` é volumetria cujo custo **ninguém mediu nesta máquina**: a
    fase começa pela colheita (mandato 5); a **Fase 5** (materiais dos blocos) tem um atlas 8×8 de
    16 px com `seed` fixa ([voxel_atlas.gd:5-14](../src/world/voxel_atlas.gd#L5-L14)) servindo os 23
    ids por **um** material, e o corte manda esgotar a variação pelo canal que já existe antes de
    qualquer atlas novo.

## Backlog priorizado (P0 → P1)

**P0 — fundação determinística** (gate atual: nenhum fechado)
- [x] `state_hash()` mínimo + JSONL `[tick,hash]` sob demanda (item 1, validado nesta máquina).
- [ ] Estado inicial completo, comandos/RNG e ordem autoritativa para replay (item 2).
- [x] `af-bench --scenario boot_walk_10min` com hash estável em 3 execuções — re-medido na árvore do
      pin `9b2c65a` (merge `35959e0`): hash final `fd9b41e0…` nas três, exit 0, `records == 12000`,
      `dropped_ticks == 0` ([readback](evidence/af-bench-boot-walk/readback.md)). **Não fecha gate de
      fase** (mandato 4, fecha o dono do repo) e o relógio da guarda (`estouros_guarda=16`, nos mesmos
      8 pares tick/lobo) segue canal aberto — a triplicata é "a mesma sorte", não prova limpa.
- [x] bake-off de voxel decidido com números — A × C, três corridas serial de cada na árvore do pin: a métrica
      `mesh_ms + 52·mean_us` deu A 8.333,32 ms × C 9.835,24 ms (+18,02 %): A fica como default, C segue só como patch, B reabre a ≤ 7.500,0 ms ([readback](evidence/af-bakeoff-voxel/readback.md)). Não fecha gate de fase (mandato 4), e o par "942 ms / 4682 ms" que esta linha afirmava como altura certa nunca teve corrida publicada que o sustentasse.
- [x] `docs/engine/simclock.md` derivado de [sim_clock.gd](../src/core/sim_clock.gd) — pousou pelo 07a (`779d19b`, âncoras re-derivadas sobre o `src/` da perna 16); marcado aqui porque o checklist é o alvo do dossiê 07, não por conta desta rodada.

**P1 — mentes e memória**
- [x] Refinar rastros e reações dos três canais atuais — comportamento validado em headless; inspeção visual em janela pendente.
- [ ] canais morte/som/fogo (item 4) — adiados enquanto trabalho/sangue/medo são aprofundados.
- [ ] budget HOT medido (item 5) e o número no §08.
- [ ] multi-semente do cenário do lobo (item 3).
- [ ] difusão em thread (item 6).
- [ ] `MindStore`: só vale se mover a memória para fora da entidade; a consolidação que o
      prompt pedia já está feita dentro de `Mind`, então o item é o *store*, não a *consolidação*.
- [ ] `MindsInspector`: decidir se é uma UI nova ou o F3 atual estendido — hoje o F3 já expõe
      intenção, medo, sangue, trabalho, `mem`, `crencas` e o custo da árvore.

## Débitos

- **Sair com um stream tocando vaza no engine, e agora isso aparece nos logs.** Desde que o
  diretor entrou, o smoke e o `audio_test` encerram com as linhas de vazamento do quit; as
  corridas históricas anteriores ao som não imprimiam nada. Medido nos logs publicados:
  **8 instâncias / 4 recursos** no smoke, **12 / 6** no `audio_test`, **6 / 2** na colheita de
  custo. Isolado em [leak-probe.gd.txt](evidence/audio/leak-probe.gd.txt), sem código de jogo: um
  `AudioStreamPlayer` tocando no quit vaza **4 instâncias e 2 recursos por stream**; `stop()` no
  mesmo tick **não** resolve (volta o mesmo vazamento); `stop()` seguido de mais 20 frames limpa.
  A deleção da playback é adiada para o próximo tick de mix do `AudioServer`
  (`AudioServer::stop_playback_stream` só marca `FADE_OUT_TO_DELETION`), e o processo morre
  antes disso. Não há conserto honesto do lado do jogo — atrasar o quit para o motor liberar
  referência alheia seria maquiar a medição. Contagem de checagens e exit code não mudam:
  **220 / 0** e **73 / 0** seguem valendo com a linha de aviso presente
  ([smoke.log](evidence/audio/smoke.log), [suite-audio.log](evidence/audio/suite-audio.log)).
- **O som não tem linha no F3 nem chave no diagnóstico.** O diretor já devolve
  `diagnostics()` com driver, níveis, famílias, vozes, toques e cama
  ([:284-300](../src/audio/audio_director.gd#L284-L300)), mas nada em `src/` consome: nem o F3,
  nem `main.diagnostics()` ([:1180-1205](../src/main.gd#L1261-L1294)), que tem `journal` e não tem
  `audio`. Só o teste headless e a sonda em janela leem esses números hoje.
- **A sonda viva de áudio não é testável em CI:** `audio_live_probe.tscn` exige janela e um
  endpoint de render aberto. A mesma árvore, na mesma máquina, deu WASAPI em uma corrida e
  `ERR_CANT_OPEN` → `Dummy` em outra ([live-2-red-dummy.log](evidence/audio/live-2-red-dummy.log)), e a checagem do driver pegou a
  diferença. É o mesmo formato de débito do gate do oráculo: caminho feliz existe, mas não é
  reproduzível sem o hardware de quem executa.

- **O smoke usa o slot real `alpha` e não o preserva**
  ([smoke_test.gd:3173-3195](../tests/smoke_test.gd#L3173-L3195)). Nesta validação, os
  smokes finais rodaram em cópia com `user://` isolado por override; o runner de contrato
  cria/remove apenas sua pasta exclusiva e não salva o mundo. Falta incorporar isolamento
  ao próprio smoke, sem depender do cuidado de quem executa.
- **O journal mínimo não é transacional nem multiwriter.** `flush` por linha não promete
  recuperação de linha parcial após falha de disco/processo. A recusa de arquivo existente
  supõe um único escritor: não há lock exclusivo entre o teste de existência e o open.
  Caminho novo e exclusivo por corrida é o contrato; não é ledger tolerante a falhas.
- **`docs/design/08` tem um link quebrado**: `:34` aponta para
  `09-veloren-mecanics-adaptation.md`; o arquivo é
  `09-veloren-mechanics-adaptation.md` (falta um "s"). Corrigido junto deste arquivo.
- **A colheita de BT ainda não é o agregado HOT**: o runner de rastros mede um lobo por
  cenário, `sim_step` inteiro e custo/estouros da árvore separadamente. Não mede as cinco
  mentes simultâneas contra 2,5 ms, nem frame renderizado. `TIME_PROCESS`/
  `TIME_PHYSICS_PROCESS` e fila de malha seguem só no F3; **alocação** não tem medição.
  O blackboard por tick ([wolf.gd:911](../src/entities/wolf.gd#L911)), as listas temporárias
  do scorer, `keys()` do cache de rastros e o array por canal da difusão
  ([aether_field.gd:122](../src/world/aether_field.gd#L122)) continuam débitos de colheita,
  não justificativa para otimização cega.
- **Rastros são amostras, não eventos atribuídos.** A busca usa a camada Y atual e projeta
  o alvo na superfície mais alta; não resolve cavernas, rotas bloqueadas ou múltiplas
  alturas. Uma inspeção lembra até 32 células por 30 s; a expiração e a renovação são
  testadas, mas a expulsão da 33ª célula não tem cenário dedicado. Difusão real foi
  exercitada com WORK 4,0; isso não promete que um único imprint fraco dure até a chegada.
  Saturação pode ocultar um novo imprint; não há autoria nem timestamp no campo.
  A parada/movimento foi medida em headless; legibilidade visual e F3 não foram aprovados
  em janela neste bloco. O hash mínimo não inclui cache nem timer da inspeção.
- **O passo de nado sabe sumir sem deixar rastro**: se a seed não tiver lago fundo,
  `_swim_wolf` fica nulo e `_check_swim_assert` retorna antes de checar qualquer coisa —
  quatro checagens somem e a contagem cai de 220 para 216 sem nenhum vermelho. A contagem
  publicada por revisão é o que pega isso hoje; o certo é o passo falhar quando a premissa
  que ele mesmo pediu não existe.
- **Dois scripts de áudio não têm o `.uid` no índice.** `src/` + `tests/` somam **39** `.gd` e o
  índice rastreia **37** `.uid` (contados hoje com `git ls-files`, não herdadas da rodada do áudio,
  que media 37 / 35); faltam exatamente `tests/audio_test.gd.uid` e
  `tests/audio_live_probe.gd.uid`, que na rodada do áudio **nem existiam** e hoje existem na árvore
  de trabalho como não-rastreados — o que falta é stagear os dois, nada os cria de volta. No clone limpo o
  `--import` os cria e o `git status` os mostra como não-rastreados
  (linha `clone_sidecars` da [conferência](evidence/third-person-carry/readback.log)). Nada
  quebra: nenhum `.tscn` de `tests/` referencia script por `uid://` —
  `audio_live_probe.tscn` usa `path="res://tests/audio_live_probe.gd"` — e o `--script` resolve
  por caminho. Não entraram neste commit porque o manifesto pinado descreve **79 arquivos** e
  re-pinar sem corrida nova em cima do conjunto re-pinado é o que a regra 6 proíbe; a correção
  pertence ao próximo bloco que já tiver de re-medir por outro motivo.
- **O gate do oráculo depende de um servidor local de fora**: `live_oracle_probe.tscn` exige o
  `llama-server` de pé; a degradação é testada sem rede ([smoke_test.gd:3074-3079](../tests/smoke_test.gd#L3074-L3079),
  sonda apontada para a porta 1), o caminho feliz não é testável em CI.
- **A suíte rodou uma vez com a régua de 25 ms estourada e a janela não foi amostrada** (dossiê 23,
  árvore do merge `05e8917`): `264 checagens 1 falhas 57,8 s` com `pior passo=25,76 ms`
  ([suite_main_vermelho.log](evidence/elevacao-visual-agua-23/suite_main_vermelho.log)), e as outras
  nove corridas da mesma árvore deram 11,40–16,49 ms. O débito é de instrumento, não de código:
  quem rodar a suíte nesta árvore roda com `.tools/carga_23.ps1` ligado desde antes do `--import` e
  arquiva o par (log da corrida + log de carga com o PID nomeado), porque sem essa testemunha a
  frase "carga na máquina" continua sendo o **furo #31** de sempre — e o amostrador que a casa
  exigiu para pagar o #31 abriu o **#44** (a coluna de PID lia uma chave inexistente).
- **A forma forte da expectativa de hash da Fase 2 nunca foi corrida, e não é testável do jeito que foi
  escrita** (dossiê 23, branch `feat/elevacao-visual-chuva-23f2`): a §de abertura prometeu que uma
  corrida com chuva **reproduz** os hashes publicados, mas o mandato 3 já mediu que dois runs da mesma
  árvore **sem** chuva dão `hp`, Éter e pior passo diferentes — logo não existe par que valide hash
  igual. O que existe medido é o antecedente estrutural (os três nós novos não têm referência a mundo,
  Éter ou jogador, `Channel.COUNT == 3`, `FORMAT_VERSION`/`GEN_VERSION` intocados). O débito é a corrida
  pareada com `--tick-journal=` nos dois braços (`--weather=0` × `--weather=1`), publicando a **distribuição**
  de divergência com e sem chuva em vez de exigir igualdade — sem ela, a frase da abertura continua mais
  forte que o instrumento.
- **O `--weather=<alvo>` não chegou ao `Rodar.bat`** (dossiê 23 §3.10a pedia a bandeira na CLI, não no
  launcher): a porta existe em [`src/main.gd:1334`](../src/main.gd#L1334) e é o caminho que a suíte e a
  sonda usam, mas o atalho do dono continua sem a linha. Não é código desta perna: o launcher não tem
  autorização.
- **Os ~200 ms de boot que a Fase 2 acrescentou não têm atribuição por perna dentro dela** (mesma
  branch): `mesh_ms` vai de 4 711–4 725 ms na base para **4 907–5 094 ms** na ponta, e três coisas
  entraram juntas — o `_scan_col_tops()` por rebuild, o material opaco como `ShaderMaterial` e o
  `Weather`/`RainFx` no boot. Duas corridas da **mesma** árvore já diferem em 187 ms, então o que se
  publica é o intervalo e não um custo. O débito é uma ablação de três braços no mesmo instrumento
  (scan ligado/desligado com o shader no lugar; shader trocado de volta por `StandardMaterial3D` com o
  scan ligado) antes de qualquer frase sobre "custo do material opaco".

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
4. **`SubtreeGuard` default 250 µs × uso real 400 µs × HOT 2,5 ms**: são limites de escopos
   diferentes, não três medições. O runner de rastros agora mede a árvore e o passo completo
   de um lobo; a soma simultânea da matilha continua faltando. Não somar picos de instantes
   distintos para declarar fechado o gate.
5. **O prompt tratava hash/journal como peça existente antes de ela existir.** A auditoria
   original expôs a lacuna; este bloco implementa a projeção mínima e o registro de hashes.
   Não confundir essa entrega com estado completo reproduzível ou journal de comandos.
6. **A suíte tinha um passo que era rolagem de dados, e o clone limpo foi o que mostrou.** Na
   primeira corrida do clone limpo esta árvore deu **4 falhas** (`golpe acertou o lobo
   hp 42 -> 42.0 em 30 ticks` + as três consequentes); a segunda corrida do mesmo clone, na
   mesma máquina, sem tocar em nada, deu **219 checagens / 0 falhas**. Vermelho intermitente em
   código idêntico é defeito de premissa, não do ambiente.

   Causa procurada em duas direções. A primeira era um buraco real, mas não era a causa; a
   segunda é, e está reproduzida nos dois sentidos:

   - **Braço A (código antigo + cadáver forçado no índice):** `main.wolves[2].die()` antes do
     passo devolve as **mesmas quatro linhas**, com os **mesmos valores** — é um buraco da porta
     do alvo (`targets_under_crosshair()` só devolve vivos — [main.gd:910-915](../src/main.gd#L910-L915) —
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
     [player.gd:607-643](../src/entities/player.gd#L607-L643)) e o golpe foi no lobo que a
     simulação ao vivo deixou ali. A corrida vermelha natural tem a mesma digital:
     `intento=... hunt` no passo de mente e `hp=66.0` no diagnóstico final — matilha em cima do
     jogador parado, estado que o próprio suíte já documentava
     ([smoke_test.gd:365-373](../tests/smoke_test.gd#L365-L373)).
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
   `if not alive: return` ([wolf.gd:1313-1314](../src/entities/wolf.gd#L1313-L1314)) — um lobo já
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

7. **Reações confundiam percepção com posição disponível.** A reprodução inicial mostrou
   fuga mudando de rumo quando só o jogador oculto mudava de lado, caça atrás da parede
   sem avistamento e chegada ao rastro caindo em patrulha sem inspeção. O dedicado passou
   de 46 para 89 checagens para cobrir difusão, expiração e três bordas reais: histerese
   mantinha busca de presa morta; identidade 2 concluía inspeção durante knockback; WORK
   0,20 não superava a renovação ponderada de 0,08. O braço vermelho completo deu 4 falhas,
   o candidato final deu 0 com as mesmas premissas; fontes e logs nas notas de rastros.
8. **A primeira sonda de vazamento não tocava som nenhum, e dizia "sem vazamento".** Os três
   braços criavam o `AudioStreamPlayer` dentro de `_initialize()` e chamavam `play()` — que o
   engine recusa fora da árvore (`Playback can only happen when a node is inside the scene
   tree`), mas a linha impressa era só `playing=false pos=0.0`. Ela passou perto de virar
   "conclusão": esperava-se vazamento, o log não mostrou, e a explicação confortável seria o
   driver. Com `await process_frame` antes de dar `add_child`, o `play()` funcionou
   (`pos=0.186`) e **todos** os braços vazaram os mesmos 4 instâncias/2 recursos por stream, que
   é o fato que o débito acima publica. Sonda que não toca não mede audibilidade nem ausência
   dela; o que salvou a corrida foi imprimir o estado do stream, não só o vazamento.
9. **Contar chave nova em vez de incremento enganou a sonda de áudio.** A primeira corrida viva
   deu `toques na janela: 13` com `familias novas: []` e vermelhou "quem tocou foi um corpo":
   os lobos começam a andar durante os ~12 s de boot, então o snapshot inicial de famílias já
   continha os passos e o *delta* de chaves era sempre vazio. A checagem certa é o incremento
   por família ([live-1-red-premissa.log](evidence/audio/live-1-red-premissa.log) →
   [live-3-green.log](evidence/audio/live-3-green.log)). É o mesmo formato do furo #1: a
   gate passou por medir a coisa errada, não por o som não existir.
10. **"No headless o stream nunca termina sozinho" era crença, não medição.** Estava no
   comentário de `_voice_index`, na tabela de cadência da procedência e no contrato do status, e
   decidia a forma como o pool de vozes é lido por quem chega. A
   [sonda de progresso](evidence/audio/dummy-progress.log) pôs um `step_grass_1` (0,778 s) e a
   cama `amb_birds` (30,688 s) tocando lado a lado em `--headless`: a posição anda
   (0,189 → 1,395 s em 200 frames) e o SFX não-looping vira `playing=false` sozinho entre os
   frames 100 e 120. A regra do pool continua certa — liberar pela duração do arquivo, e não
   pelo flag, porque o flag só muda no tick de mix seguinte — mas a justificativa escrita era
   falsa nas três páginas e no código, e foi substituída pelo número medido. Uma premissa que
   alguém repete sem corrida vira defeito de documento, não de engine.
11. **A regra de linha do repositório reescreveria a evidência e falsificaria cada SHA
    publicado.** [`AGENTS.md`](../AGENTS.md) manda publicar número só com log real, e os logs de
    console do engine saem com CRLF; a primeira linha de
    [`.gitattributes`](../.gitattributes) é `* text=auto eol=lf`, que normaliza texto no add e no
    checkout. Reproduzido num repositório sob controle: um `.gitattributes` só com a regra da
    casa e um arquivo de 2 CR — o blob entra com **0** CR e o Git avisa
    "CRLF will be replaced by LF"; acrescentada a linha `docs/evidence/** -text` e refeito o
    `add`, o mesmo arquivo sai do índice com os **2** CR originais. Na árvore de verdade,
    51 dos 108 arquivos de texto de `docs/evidence` têm CR — `clone-suite.log` são 311,
    `arm-red-suite.log` 361 — e os manifests foram computados com `sha256sum -b`, ou seja, sobre
    esses bytes. Sem o conserto, todo `artifacts.sha256` daria FAILED no primeiro clone e nenhum
    SHA pinado em tabela bateria nunca. O que a linha não toca é o que já estava protegido:
    `.png` e `.wav` são `binary` e nunca foram normalizados.

12. **O `--import` frio do clone limpo deu *segmentation fault* uma vez em três, e a medição
    anterior não tinha como mostrar isso.** Nenhum `readback.log` de rodada passada grava o código
    de saída do `--import` — só o das duas gateiras. Na rodada do passo, a primeira importação fria
    do clone de `520c3b4` terminou com exit 139 depois de `[ DONE ] loading_editor_layout`; as duas
    repetições frias no mesmo clone e três tentativas frias num clone da árvore anterior (`297685b`)
    deram exit 0, com os quatro logs byte idênticos (299 linhas, zero erro) e o cache completo — as
    duas gateiras rodaram nesse clone e saem 0. Não atribuído, e é o tipo de coisa que a receita do
    README entrega para quem só clonou: se repetir, é defeito nosso de processo de import; se não
    repetir, é ruído de engine que precisava estar escrito em algum lugar.
    Detalhe e números na rodada do passo.

13. **Rótulo de citação e âncora da URL envelhecem separados, e nada no repositório confere os
    dois.** A conferência por máquina da rodada de rastros achou **5 ocorrências** em que o
    `:NN-MM` escrito no texto é diferente do `#LNN-MM` da URL — das **79** citações com âncora do
    repositório, todas neste arquivo, três rótulos distintos (dois escritos duas vezes). Em duas o
    caso é banal: a âncora foi re-derivada quando `wolf.gd` cresceu e o rótulo ficou 1 ou 25 linhas
    para trás. A terceira é a pior porque **nenhuma** das duas janelas cobre o que a frase afirma —
    `:301-304` com âncora `#L302-L305` diz "as chamadas de `_rng` na patrulha", e as três chamadas
    estão em `303`, `305` e `306`. É o furo #3 com o motivo invertido: lá o número do texto era
    inventado, aqui ele foi verdadeiro e a linha mudou depois. Nada em `tests/` derruba vermelho
    por isso (grep: `docs/` aparece em `tests/` só em comentário), então a única defesa é o script
    que compara os dois, e ele não estava sendo rodado. Detalhe na seção de re-derivação da rodada.

14. **Os dossiês apontam para linhas deste arquivo e do `AGENTS.md`, e a gateira que confere os
    números não lê o que está nesses números.** São **59** referências no formato
    `docs/melhorias-status.md:NNN` dentro de [`docs/planos/`](planos/README.md) e **8** no formato
    `AGENTS.md:NNN`. `verify_plan_cites.py` confere se o arquivo existe e se o número cabe nele — e
    devolve **"0 números fora do arquivo"** para as 67, porque o documento só cresceu: um ponteiro
    que hoje cai em cima de prosa de outra seção continua dentro da faixa. Conferindo o conteúdo de
    quatro deles contra o texto que os dossiês afirmam: `01:3` chama `:262-271` de "item 2 de Falta"
    (o item 2 está em `275-284`; `262-271` é o fim de "Em andamento" mais o cabeçalho da seção);
    `01:46` e `02:27` citam `:370-374` para "a contagem cai de 220 para 216 sem nenhum vermelho"
    (a frase está em `416`); `02:36` cita `:401-404` para o veto de somar picos de instantes
    distintos (está em `447`); `02:9` cita `:32` para "não há harness multi-semente em `tests/`"
    (está na tabela de prompts, `:45`). Os quatro estavam errados **antes** desta rodada e continuam
    errados: a deriva não é um deslocamento único, são épocas diferentes sobrepostas (a rodada de
    rastros empurrou a seção "Falta" de `255` para `268`, e esta rodada, que acrescentou os itens
    8 a 11, empurrou tudo abaixo de `307` em **+31** — **32** das 59 referências — e o `AGENTS.md`
    recebeu **+21** em `271`, o que moveu **3** das 8). As quatro páginas novas (09 a 12) não
    adicionam dívida: 09, 10 e 11 não fazem nenhuma referência numerada a estes dois arquivos, e a
    única de 12 aponta para o `README.md` da raiz. Rodada 2026-11-20: o instrumento saiu de
    `.tools/` e virou `tools/check_doc_anchors.py`, que existe no clone; a passada re-derivou
    o corpus inteiro pelo conteúdo, e a régua com o resíduo semântico está na última seção deste arquivo.

15. **O gate de custo do dossiê 09 era uma digitalidade de janela, não um gate.** §4 pedia: o
    `sim_step` do runner estreito "tem de sair na banda das oito árvores medidas
    (361 464–375 216 µs em 2 768 passos); se sair, o imprint com bioma não custou nada". Medido na
    janela desta perna, **o chão** — `e7e30e6`, a base exata da branch, que contém aquelas oito
    árvores — devolve 372 473 / 379 938 / 381 320 / 385 848 / 387 730 µs: quatro dos cinco valores
    **fora** da banda publicada, e a branch na mesma faixa (379 321–387 450). Corrida absolutas de
    janelas diferentes não se comparam, e a regra I da sessão anterior já tinha dito isso — o que o
    furo acrescenta é que **um dossiê pode escrever um critério que a própria máquina do dia seguinte
    não consegue satisfazer com o código velho**. A leitura substituta é pareada (branch e chão
    intercalados, mesma janela), é o que está em
    [evidence/bioma-cor-de-pelo/readback.md](evidence/bioma-cor-de-pelo/readback.md) §3, e vale para
    10, 11 e 12: nenhuma banda absoluta de µs como gate.

16. **A suíte real aprova a alcateia sem nunca ter visto uma alcateia.** As duas checagens que a
    perna 10 pôs na sessão verdadeira ([smoke_test.gd:388](../tests/smoke_test.gd#L388),
    [:376-379](../tests/smoke_test.gd#L376-L379)) dão verde com o vale inteiro assim:
    `pares=10 esperado=10 maior_matilha_lida=1 lobos_vivos=5`
    ([evidence/alcateia-rutinas/pos-merge-suite.log:23-24](evidence/alcateia-rutinas/pos-merge-suite.log)).
    Duas leituras erradas cabem nessa linha. A primeira: `pares=10` **não** são pares coesos, são as
    **comparações** `i<j` que a passada da sessão avalia — `_pack_pairs += 1` roda em todo par
    testado, dentro ou fora do raio ([main.gd:924](../src/main.gd#L924), dentro de `_rebuild_packs`
    [:859-879](../src/main.gd#L914-L934)), e `10 = 5·4/2` é justamente o total de combinações de
    cinco lobos, ou seja: o número é teto de trabalho, nunca de matilha formada. A segunda, e é o
    furo: `maior_matilha_lida` é o maior `_pack.size()` entre os lobos, e `_pack` **não** conta o
    próprio lobo — então `1` significa "um lobo viu **um** vizinho", e a asserção é `biggest >= 1`
    ([:400](../tests/smoke_test.gd#L400)). Com os cinco lares espalhados como o spawn os sorteia,
    `PACK_COHESION_RADIUS = 24 m` nunca entregou dois vizinhos a ninguém. Consequência direta:
    cerco, contágio do medo e ronda por setor estão provados no fixture do runner, que põe quatro
    lobos a distância um do outro de propósito
    ([evidence/alcateia-rutinas/cerco-runner-2.log](evidence/alcateia-rutinas/cerco-runner-2.log),
    `angulos=[0.0, 1.5708, 3.1416, 4.7124] n=4`), e **não** no vale. O que a regra 4 do ciclo cobra
    e aqui faltou: a checagem nomeia "o rebuild viu par", mas a premissa que se quer garantir é
    "**a sessão real monta matilha de tamanho ≥ 2**", e nenhuma linha hoje a exige. Não se conserta
    escrevendo `biggest >= 2` — com spawn em anel de 16–46 m em torno do centro fixo, isso é vermelho
    legítimo e o conserto certo é o da perna 14, que é quem mexe em lares, spawn e distância segura.
    Registro antes do código, como manda a regra 6: **a perna 14 troca o `>= 1` por `>= 2` e exige
    que o verde venha do mundo, não do fixture.**

    Rodada 2026-11-21 (`6e35b64`): cumprido os dois sentidos. Com a mordaca fora do lugar a mesma
    corrida da suíte devolve `maior_matilha_lida=1`
    (`vizinhos=[lobo0(1 viz) lobo1(1 viz) lobo2(0 viz) lobo3(1 viz) lobo4(1 viz)]`) e **1 falha**;
    com ela, `maior_matilha_lida=4` (`lobo0(4 viz) … lobo4(3 viz)`) e **0 falhas** — o verde passou a
    vir dos lares que o mundo montou, não do `>= 1` que aceitava a dispersão. A asserção é hoje
    `biggest >= 2` ([smoke_test.gd:399-404](../tests/smoke_test.gd#L399-L404)), e a segurança não foi
    trocada por coesão: os quatro lares aceitos pela mordaca estão a 42,5–55,1 m do jogador, lidos
    nas linhas literais do log.

17. **Este arquivo também é alvo de citação por linha, e a passada de re-derivação não olhava
    para ele.** O corpus guarda **60** referências no formato `docs/melhorias-status.md:NNN`
    (dossiês e páginas de design que citam uma seção deste arquivo pelo número da linha), e a
    perna 10 escreveu **285** linhas aqui dentro — de 2 326 a 2 611. `fb20707` e `cb96493`
    conferiram `src/` e `tests/` e deixaram o próprio status apodrecer: é o risco do furo #3
    (`"main.gd cresce e todo doc que cita main.gd:NNN apodrece em silêncio"`) aplicado ao
    documento que registra a regra. Medido contra `HEAD` pela linha inicial de cada uma, **16** já
    caíam no lugar certo e **44** estavam **+34**, **+49** ou **+92** adiante; como faixa conta pelos dois
    topos, o realinhamento tocou **52** referências e mudou **49** números, cada um com prova de conteúdo: a linha nova é a
    mesma linha antiga, byte a byte, lida pelo alinhamento `difflib` entre `HEAD` e a árvore — não por
    offset adivinhado, e a conferência refeita pelo mapa ao contrário devolve **52/52**.
    **8 ficaram para trás por motivo legítimo** — e é justamente o grupo que a passada de
    2026-11-20 teve de consertar à mão, porque deslocar prova vazia só enfeita o erro com
    número novo (a mesma regra que devolveu as 11 faixas em `cb09015`): 04:27 passou a ler as
    linhas de comandos da rodada do RNG, 05:3 as do item 6 de "Falta" e da linha não marcada de P1,
    05:23 e 05:45 a âncora de campo WORK 4,0, 07:68 a linha da dor do boot, 07:131 as alturas
    certas e 02:32 e 05:19 o débito de alocação — cada alvo aberto contra a frase que o cita.

18. **A recusa de lar no boot não tem corrida própria, e nem o mecanismo que devia exercitá-la a
    exercita.** A linha `"spawn RECUSADO: "` de [main.gd:871](../src/main.gd#L871) é a única
    testemunha de que as três bandas esgotaram, e a perna 14 a publicou como parte do que entregou
    ("sem fallback mudo no centro e com a recusa impressa por motivo contado"). Medido: ela aparece
    **zero** vezes nos 51 logs do corpus
    ([`readback.md:289`](evidence/alcateia-convivio-14/readback.md)) — a string é lida em
    `f_smoke.log`, no log do clone e no do fecho, e não é achada. Até aqui isso era lido como "o
    spawn foi sempre bem-sucedido", o que é verdade e não é o furo. O furo está no `test/` que a
    casa escreveu para cobri-la: a checagem
    "mecanismo: coluna ocupada nao volta como lar" ([aether_reactions_test.gd:2814-2836](../tests/aether_reactions_test.gd#L2814-L2836))
    marca o centro como ocupado, pede **8** lares pela função real e comenta que "o ponto que o
    fallback antigo devolvia em silêncio … hoje tem de ser recusado por distância ou por visada".
    O número que a mesma linha imprime é `recusados=0`:
    `violacoes=0 em 8 pedidos, recusados=0, ocupadas=6, colunas_devolvidas=7`. Ou seja: a asserção
    é `violacoes == 0`, e ela passa **identicamente** se nenhuma recusa acontecer — o `recusados`
    entra na mensagem, não no critério. O dicionário `motivos`
    ([main.gd:823-824](../src/main.gd#L823-L824), incrementado em `vazia` `:811`, `coluna` `:821`,
    `molhado` `:768`, `encaixado` `:772`, `perto` `:778`, `visivel` `:780` e `perto_de_toca` `:786`)
    também não tinha **um** leitor em `tests/`: a separação por motivo, que é justamente a promessa,
    nunca foi conferida por número.
    Consequência (regra 4 do ciclo): o verde desta checagem não prova o comportamento recusado,
    prova só que a coluna ocupada não volta. O conserto não é escrever `recusados > 0` no mesmo
    palco — com seis colunas ocupadas e três bandas que vão de 16 m até a borda útil do mapa, o
    mundo entrega lar conforme quase sempre, e seria vermelho legítimo. É montar o estado que
    **força** o esgotamento — censo de colunas ocupadas acima do que as três bandas conseguem furar —
    e exigir ali `recusados == 8`, com os seis motivos somando as 8 buscas. Registro antes do código,
    e o dono do arquivo é a perna 16 (tocas e censo) ou a 11
    (censo variável), não esta: nada do dossiê 19 encosta em `src/main.gd`.
    **A oferta tem dono desde 2026-11-22:** a perna 16, sem a alternativa — o item 8 de §5 de
    [`docs/planos/16-tocas-da-alcateia.md`](planos/16-tocas-da-alcateia.md) assume este furo pelo
    nome (`esgotamento_de_lares_forcado`), e a 11 não o leva porque o censo variável dela já fechou
    e re-romar gate de perna publicada custa uma re-medição do número que está aqui em cima.

    Rodada 2026-11-22 (`0bd3ea7`, ponta `feat/tocas-da-alcateia-16`), pousada em `9b2c65a`: pago nos dois
    sentidos que a regra 3 do ciclo cobra. **O estado forçado** é a checagem
    `esgotamento_de_lares_forcado` ([aether_reactions_test.gd:2849-2885](../tests/aether_reactions_test.gd#L2849-L2885)):
    o `_mark_useful_box` de `:2784` marca **todas** as 13 689 colunas da caixa em que o sorteio é
    clampado (fixture, nenhum voxel do mundo é tocado) e os mesmos 8 lares são pedidos pela função
    real — o esgotamento deixa de ser sorte da semente e passa a ser geometria. **A cobrança** não é
    `recusados > 0`: é `forcados == 8` **e** `soma(motivos) == buscas × SPAWN_ATTEMPTS` **e** a soma
    inteira cair em `coluna` (`so_a_coluna`). Literal medido, igual nos dois runs:
    `recusados=8 de 8 | soma(motivos)=576 == buscas(24) x SPAWN_ATTEMPTS(24)=576 | so_a_coluna=true | colunas_marcadas=13689 | primeiro={ "perto": 0, "visivel": 0, "coluna": 72, "molhado": 0, "encaixado": 0, "vazia": 0, "perto_de_toca": 0 }`
    ([head_runner_run1.log:279](evidence/tocas-alcateia-16/head_runner_run1.log#L279), idem
    [run 2 `:279`](evidence/tocas-alcateia-16/head_runner_run2.log#L279)). Se a ordem dos portões
    mudar, ou se um `continue` passar a engolir tentativa sem contar, a soma fecha curta e a linha
    fica vermelha — o que a asserção antiga nunca pôde. A premissa aritmética da própria conta tem
    testemunha separada, `premissa: as tres bandas buscam de verdade (nenhuma vazia)`
    ([:2844-2848](../tests/aether_reactions_test.gd#L2881-L2885)), porque com uma banda vazia por
    geometria (`rmax <= rmin`, [main.gd:829-833](../src/main.gd#L829-L833)) o produto
    `buscas × SPAWN_ATTEMPTS` seria o número errado a cobrar. Do lado do código, `motivos` agora
    **sai** como chave do dicionário devolvido
    ([main.gd:897](../src/main.gd#L897), com a razão escrita em [:815-819](../src/main.gd#L877-L900))
    além de continuar dentro da string impressa em `:793`. Duas diferenças honestas para com o texto
    de cima: o conserto proposto ali dizia "os **seis** motivos" e hoje são **sete** chaves, porque a
    16 abriu `perto_de_toca` (`:786`); e a checagem de mecanismo continua exatamente onde estava,
    ainda com `recusados=0`, só que agora com `colunas_devolvidas=8`
    ([head_runner_run1.log:269](evidence/tocas-alcateia-16/head_runner_run1.log#L269)) — que é o
    retrato do furo: ela segue sem alcançar a recusa, e quem a alcança é a checagem nova.

19. **Três classes de citação ficavam fora de qualquer régua, e é nelas que a podridão morava.** O
    instrumento versionado ([tools/check_doc_anchors.py](../tools/check_doc_anchors.py)) cobre
    ponteiro com `#L`, rótulo de função, conteúdo de linha, link relativo e ausência de arquivo.
    Nesta passada apareceram, cada uma com número medido contra os mesmos arquivos: **(a) citação
    curta sem diretório** — `` `wolf.gd:1236` `` em prosa de dossiê. Na base resolviam-se **782** pelo
    basename contra `src/`, `tests/` e os `.md` da raiz; com a raiz fora do conjunto de resolução
    elas davam **52** falsas "ambíguas", e passaram a dar **0**. Re-medido nesta ponta: **843**
    conferidas e **3** ocorrências de uma só ambígua — o `readback.md:289` que o furo #18 acima cita. O arquivo existe
    (`docs/evidence/alcateia-convivio-14/readback.md`, 292 linhas, a linha 289 está dentro); o que
    falta é o conjunto de busca do script descartável, que varre `src/`, `tests/` e a raiz e não
    varre `docs/evidence/`. É artefato da régua, não ponteiro podre. **(b) número solto `:NNN`** cujo doador
    é o último caminho **da linha** — não o que a frase nomeia. **262** casos herdam doador por
    posição e **4** desses ponteiros vivos estavam simplesmente errados, todos em
    [`docs/planos/03`](planos/03-canais-morte-som-fogo.md), o dossiê de uma perna nunca executada
    que lê uma árvore três pernas menor; nesta ponta são **260** soltos, os mesmos quatro seguem
    errados porque o dono é a 03, e o único caso que a classe devolve é `sim_clock.gd:200` em
    [`planos/07:144`](planos/07-af-bench-bake-off-voxel-e-doc-do-simclock.md) — número que a própria
    frase cita para dizer que está fora do arquivo de 48 linhas. Um deles é o defeito de conteúdo que a régua nenhuma via:
    `planos/01:20` dava as duas portas da matilha como `targets_under_crosshair()` `:449-454` e
    `wolves_roster()` `:457-458` sem nomear o dono, e o doador posicional passava a linha inteira
    para `wolf.gd`, onde as duas faixas não existem. **(c) citação prefixada por revisão**
    (`a1405e4:src/…`): o instrumento conferia o número contra a árvore de trabalho e acusava um
    **registro** histórico de quebrado — foi o caso de `status:1910` que abriu esta linha. O conserto
    é da régua, não do número: ponteiro com SHA prefixado não é ponteiro vivo, e a guarda agora o
    declara no docstring e o ignora. Somando as três: nesta ponta o corpus dá **35 arquivos /
    1 903 ponteiros / 131 rótulos / 1 866 links relativos / 0 casos objetivos, exit 0**; na base
    `8ac761d`, lida contra a mesma árvore de código, eram **34 / 1 835 / 131 / 1 791 / 53 casos,
    exit 1** — 25 BRANCO e 28 ROTULO-FORA-DO-CORPO espalhados por 12 documentos (19 dentro deste
    arquivo, 11 no dossiê 10, 7 no 13). Os 68 ponteiros a mais se decompõem assim, cada parte conferida
    pelo próprio instrumento rodado por arquivo: a página 19 entra com **29**, **16** são as linhas da
    tabela de controles do [doc 09](design/09-veloren-mechanics-adaptation.md) que ganharam `#L` e
    portanto entraram na régua (44 → 60), e os **23** restantes são as re-ancoragens desta passada
    neste arquivo e nos dossiês 05/06/07/08/15 e no índice. A lição, e é a regra 1 do ciclo com número: **transladar delta abençoa a podridão**. Como
    a perna 19 não tocou em `src/main.gd` nem em `src/world/aether_field.gd` (diff `BASE→HEAD` vazio
    nos dois), todo `main.gd:NNN` errado que a passada achou já estava errado **antes** da perna —
    deslocar pelos +N da linha empurraria o erro para a frente com aparência de atualizado. Só a
    re-ancoragem por conteúdo, abrindo o alvo e lendo contra a frase, decide.

    O saldo da varredura, lido caso a caso (a régua das classes (a) e (b) é script descartável desta
    passada, `.tools/prose_cites.py`, e por isso o número abaixo não é reproduzível por quem chega pelo
    clone — o que versionou foi a guarda da classe (c)): na base foram **50 casos**, e nesta ponta
    **49** — nenhum deles é desta perna. **23** são a régua acertando o número e errando o rótulo — a prosa cita a tabela que a função lê
    (`block_defs.gd:116-122` dito `hardness`, `block_defs.gd:31-35` dito `draw_of`), o sítio da chamada
    (`main.gd:354` é o `_respawn_queue.append` da fila, nomeado pelo predicado `_spawn_home_point`), o
    `var` na faixa onde ele é lido (`voxel_body.gd:99-101` para `blocked_horizontal`, `main.gd:71` para
    `_population_rng`, `player.gd:688` para `inv`), uma linha de tabela com dois ponteiros
    (`AGENTS.md`: `sim_clock.gd:5-7` **e** `:19-29` para o mesmo orçamento), uma célula que afirma duas
    coisas (`planos/03:28`: a geometria em `:45-54` e `state_bytes()` medida em outro lugar) ou o nome
    de um arquivo que a busca por basename não alcança (`readback.md:289`) — a regra só sabe comparar
    faixa com o corpo de uma função. **15** são registros que declaram a revisão
    em que valeram (`f2823a8`, `eb6ec8d`, `40ca4fb`, `4ac5838`, `27800eb`, "na revisão deste briefing",
    as linhas de auditoria que
    citam o número errado de propósito — inclusive as linhas da tabela logo abaixo, que citam um
    número exatamente para julgá-lo, e a nota das dez ocorrências). **11**
    estão simplesmente errados, todos em arquivos que o diff
    `BASE→HEAD` desta perna não toca — e são doze na tabela abaixo, porque um deles era deste arquivo e
    foi consertado aqui:

    | ondre | diz | hoje |
    | --- | --- | --- |
    | [`design/10:655`](design/10-world-layers-and-block-physics.md) | `main.gd:703-705` é `_on_block_broken` | na ponta da 16 `:698-700` cai no corpo de `_sem_toca()` `:699-702`; `_on_acted` é `:913-918` e o corpo de `_on_block_broken` é `:921-924` |
    | [`design/10:812`](design/10-world-layers-and-block-physics.md) | `world_gen.gd:41-60` é `setup()` | 41-60 é `IMPRINT_BIAS` e a lista de ruídos; o corpo é `:64-85` |
    | a linha da sonda da porta 1 na tabela "Cinco âncoras já estavam tortas na base" **deste arquivo** | `smoke_test.gd:2092-2097` é `_check_oracle_arm` | `:2102` é `_check_regen`; a sonda começa em `:2125` — e foi re-ancorada nas duas pernas, porque a coluna do "agora" é ponteiro vivo |
    | [`planos/03:30`](planos/03-canais-morte-som-fogo.md) | `main.gd:372` é o sangue de 0,22 | `:367` é comentário do bloco que documenta `_make_wolf`; o sangue de 0,22 é `:952` — a linha do 03 continua de dona 03 |
    | [`planos/03:38`](planos/03-canais-morte-som-fogo.md) | `main.gd:21` e `:210` definem os 0,25 s de `elapsed` | `:21` e `:210` seguem comentários (`:210` é o doc de `attach_llm_host`); `var elapsed` é `:58` e os 0,25 s vêm de `AETHER_PERIOD` `:27`, gastos em `:267-269` — a linha do 03 continua de dona 03 |
    | [`planos/03:63`](planos/03-canais-morte-som-fogo.md) | `main.gd:336`/`:457` são lavra e colocação | `:331` é branco e `:457` é comentário da ronda; os imprints WORK são `:916`/`:918` — a linha do 03 continua de dona 03 |
    | [`planos/03:76`](planos/03-canais-morte-som-fogo.md) | `main.gd:212` é a difusão | `:210` é o doc de `attach_llm_host`; o período é `:27` e a chamada é `:269` — a linha do 03 continua de dona 03 |
    | [`planos/03:157`](planos/03-canais-morte-som-fogo.md) | `main.gd:542` | `:537` é o doc de "criar custa fome e sangue" (536 é `MATE_RADIUS`) |
    | [`planos/03:191`](planos/03-canais-morte-som-fogo.md) | `aether_field.gd:50-60` é a assinatura de `imprint` | 50-60 é o `setup` do campo; a assinatura é `:87-89` |
    | [`planos/06:26`](planos/06-decompor-main-gd.md) | `main.gd:456-461`/`:459-460`/`:467-469` são as portas e a ronda | hoje `targets_under_crosshair()` `:813`, `wolves_roster()` `:821`, `pack_of()` `:829` — e a linha 26 daquele dossiê foi re-escrita nesta perna para a faixa `808-837` |
    | [`planos/11:36`](planos/11-acasalamento-filhote-e-censo.md) | `_spawn_wolves(1)` em `main.gd:264-269` **com a mensagem "uma nova matilha entrou no vale"** | a mensagem saiu na perna 14; a chamada é `:291` e o corpo `:335-359` — é defeito de conteúdo, e o dono é a 11, que re-rome o gate |
    | [`planos/18:96`](planos/18-mundo-vivo-grama-e-mato.md) | `main.gd:86` é `_population_rng` | `:86` é `var _corpse_cd` e o RNG da população é `:64` — a linha 96 do dossiê foi re-ancorada em `:64` nesta perna |

    Dono de cada um é a perna do arquivo, não esta: os seis do dossiê 03 e o do 06 são de uma perna
    nunca executada sobre uma árvore três pernas menor, os dois do doc 10 são deriva de merge alheio,
    o do 18 é pauta que ainda não tem código, e o do dossiê 11 é conteúdo — a 11 está em voo e re-rome
    o gate quando esta perna pousar, e é nela que a linha se lê. O décimo segundo da lista era deste
    arquivo e foi consertado aqui, porque a coluna "agora" daquela linha é ponteiro vivo, não registro.
    Esta perna abre o furo e não escreve nos outros onze.

    **E a coluna "hoje" da tabela acima voltou a envelhecer, e desta vez por causa desta perna.** A 16
    cresceu `src/main.gd` de 1004 para **1242** linhas (`wc -l`) e `src/entities/wolf.gd` de 1203 para
    **1218**, e pelo mesmo argumento que a 19 usou para si — o arquivo não encostou nesses ponteiros,
    então deslocar por +N empurraria o erro para a frente com aparência de atualizado — cada célula foi
    reaberta no alvo e lida contra a frase. Na ponta da 16, `main.gd:703-705` é o corpo de
    `_sem_toca()` [`:699-702`], `_on_acted` é `:913-918` (imprints WORK `:916`/`:918`) e
    `_on_block_broken` `:921-924`; `:367` é linha de comentário do bloco que documenta `_make_wolf`
    e o sangue de `0,22` é `:952`; `:21` e `:210` seguem comentários (`:210` é o doc de
    `attach_llm_host`), `var elapsed` é `:58` e os 0,25 s de `AETHER_PERIOD` `:27` gastam-se em
    `:267-269`; `:331` é branco e `:457` é comentário da ronda; `:537` é o doc de "criar custa fome e
    sangue". As portas são `targets_under_crosshair()` `:813`, `wolves_roster()` `:821`, `pack_of()`
    `:829`; a chamada de respawn é `:291` e o corpo de `_spawn_wolves` `:335-359`; `:86` é
    `var _corpse_cd`, com `_population_rng` `:64` e `_benches` `:92`. Fora dos arquivos desta perna, o
    único que a coluna citava e que também anda é o `tests/smoke_test.gd`: `_check_regen` `:2102` e a
    sonda `_check_oracle_arm` começa em `:2125`. Os dois do `world_gen.gd`/`aether_field.gd` ficaram
    como estão: a 16 não os tocou e o dono deles continua sendo a 03 e o doc 10.

    A coluna foi reescrita com esses números porque ela é ponteiro vivo, não registro — é a mesma
    regra que a 19 aplicou à célula duodécima. O que **esta** perna escreveu nos arquivos citantes é
    outro inventário, e ele cabe numa linha: [`planos/15:255`](planos/15-oraculo-embutido-no-boot.md)
    passou a ler `_sim_tick` em `main.gd#L269-L311`, [`planos/07:108`](planos/07-af-bench-bake-off-voxel-e-doc-do-simclock.md)
    aponta o `advance` para `main.gd:276-282`, [`planos/07:153`](planos/07-af-bench-bake-off-voxel-e-doc-do-simclock.md)
    re-ancorou as duas células deste arquivo (`:1888` e `:1894-1897`, depois dos +17), [`planos/18:96`](planos/18-mundo-vivo-grama-e-mato.md)
    lê `_population_rng` em `main.gd:71`, `AGENTS.md:129` levou o corpo do tick a `:264-299`,
    `AGENTS.md:342` a busca de spawn a `:735-800` e `AGENTS.md:350` declara que o censo do runner é
    **240** hoje. As linhas citantes dos dossiês 03, 10 e 11 não foram tocadas: os números acima são
    o veredito desta perna sobre elas, e a escrita nelas é de quem as possui.

20. **O gate do orçamento da árvore mede relógio de parede, e por isso ele é um gate de velocidade
    da máquina, não um gate de código.** O `SubtreeGuard` mede o tempo de relógio em volta da
    chamada do filho ([bt_tree.gd:130-137](../src/ai/behavior/bt_tree.gd#L130-L137)) e compara
    com 400 µs — o valor que o lobo passa ([wolf.gd:448-449](../src/entities/wolf.gd#L448-L449)).
    GDScript **não expõe relógio de CPU**: a única leitura é `Time.get_ticks_usec()`, que conta
    o tempo em que o processo esteve fora do seu fluxo. A checagem que consome esse contador
    ("nenhum estouro de subtree no budget",
    [aether_reactions_test.gd:3192-3193](../tests/aether_reactions_test.gd#L3192-L3193)) pode
    então reprovar por uma preempção do sistema operacional sem que a árvore tenha ficado mais
    cara. **A atribuição fecha nos dois braços:** na branch da perna 11, **2 de 7** corridas do
    runner reprovaram nessa linha (`branch_flake_runner02` e `:05`), e na `main` **sem** a perna 11
    — a mesma árvore, o mesmo runner, a mesma checagem — **2 de 15** reprovaram
    (`control_main_runner03` e `:10`); o vermelho é **anterior** a esta perna e não nasce dela.
    Sob carga medida (2 de 3 corridas vermelhas com `process_pct≈1500-1600`, ou seja 15-16
    núcleos ocupados), a mesma linha cai; e o A/B **ARQUIVO** contra **PIPE** reprova nos **dois**
    braços nos **seis** pares, de modo que a redireção da saída não é a causa. O custo real da
    árvore está longe do orçamento: a soma do `last_us` do guard sobre 8 579 passos do cenário
    estreito fica entre **56 045 µs e 63 564 µs** — **6,5 a 7,4 µs por passo** contra o teto de
    400 µs —, e os picos medidos (229 a 802 µs) são a mesma leitura de parede, não trabalho de
    árvore. **Não há correção de código aqui:** trocar o relógio por um contador de trabalho é
    desenhar outro instrumento, e o dono do furo decide se isso entra. O que fica escrito é que a
    linha é uma **premissa de velocidade da máquina**, e os logs dos dois braços ficam em
    `docs/evidence/acasalamento-censo-11/`.

21. **Uma cláusula do gate de alcateia da suíte é verdade aritmética, e do modo como está escrita
    não gateia nada.** A checagem "alcateia existe na sessao real" ([smoke_test.gd:399-404](../tests/smoke_test.gd#L399-L404))
    exige `pack_pairs == n(n-1)/2` **e** `biggest >= 2`. O contador é incrementado em
    [main.gd:924](../src/main.gd#L924) **antes** do teste de raio em
    [main.gd:925](../src/main.gd#L925) — ele conta **pares examinados**, não arestas de coesão —,
    então a **primeira** cláusula é verdadeira por construção para qualquer censo vivo, com matilha
    formada ou não: é `n·(n-1)/2` contra `n·(n-1)/2`. Quem decide a coesão é **só** `biggest >= 2`,
    lida do buffer reconstruído ([main.gd:952-953](../src/main.gd#L952-L953)). O fato não é novo — o
    furo #16 acima já o nomeou com número ("`pares=10` não são pares coesos, são as comparações", e
    o número ali é teto de trabalho, nunca de matilha formada) — e o que ele **não** fez foi tirar a
    cláusula da asserção: o conserto de 14 foi o teto de `biggest`, e a conjunção ficou com um lado
    sempre verdadeiro. O defeito é de **gate**, não de conta, e tem duas consequências práticas: a
    linha pode ficar vermelha por motivo nenhum (se `esperado` for re-derivado errado, ela reprova
    uma coesão que está boa) e ela **não** pode pegar o estado que a perna 16 quer mudar — com três
    tocas, `pack_pairs` continua exatamente `n(n-1)/2` enquanto a matilha se divide. **Dono:** a
    perna 16, que escreveu [`docs/planos/16-tocas-da-alcateia.md`](planos/16-tocas-da-alcateia.md)
    antes de abrir branch e assume no §5.1 e §8 daquela página a cláusula de **componentes conexos**
    do grafo lido — que é a grandeza que a contagem de pares nunca foi. Esta passada de pauta
    **não escreve** na suíte nem em `src/main.gd`: registro antes do código (mandato 4).

    Rodada 2026-11-22 (`2c6597b`, ponta `feat/tocas-da-alcateia-16`), pousada em `9b2c65a`: pago, e pago pela
    grandeza certa. `den_components()` ([main.gd:697-717](../src/main.gd#L697-L717)) faz a travessia
    do grafo que o último rebuild escreveu (`pack_of`, leitura pura, não mexe em buffer) e devolve
    **quantos grupos separados a matilha forma**; roda só dentro de `diagnostics()`
    ([:1192](../src/main.gd#L1281), ao lado de `dens` e `den_min_dist`), nunca por tick, e o
    comentário de [:631-635](../src/main.gd#L693-L697) aponta para este furo. A suíte passou a exigir
    `grupos >= 2` **dentro** do critério ([smoke_test.gd:400](../tests/smoke_test.gd#L400), com
    `grupos := int(d["den_components"])` em `:273`); a cláusula aritmética não foi apagada e agora se
    rotula sozinha na mensagem impressa —
    `pares_testados=15  esperado=15  maior_matilha_lida=2  grupos=3  separacao_tocas=55.9 m  lobos_vivos=6`
    ([head_suite.log:35](evidence/tocas-alcateia-16/head_suite.log#L35)). O runner cobre os dois lados
    da moeda: `diagnostico_publica_a_mesma_leitura_das_tocas`
    ([aether_reactions_test.gd:4025-4031](../tests/aether_reactions_test.gd#L4025-L4031)) amarra o
    número publicado contra uma travessia independente feita dentro do teste e imprime o furo como
    testemunha —
    `diagnostics dens=3 componentes=3 den_min_dist=49.662 | runner componentes=3 centros=49.7 | furo21 pack_pairs=10 pares_testados=10 (aritmetica sempre verdadeira, nao decide)`
    ([head_runner_run1.log:407](evidence/tocas-alcateia-16/head_runner_run1.log#L407), idem
    [run 2 `:407`](evidence/tocas-alcateia-16/head_runner_run2.log#L407)) — e
    `nenhum_lobo_le_de_outra_toca` ([:4036-4039](../tests/aether_reactions_test.gd#L4073-L4076))
    exige `arestas_entre_tocas == 0`, nenhuma aresta de coesão cruzando toca:
    `arestas_entre_tocas=0 bichos_sem_toca=0 lidos=5`
    ([head_runner_run1.log:416](evidence/tocas-alcateia-16/head_runner_run1.log#L416)). O que o furo
    previa é o que a linha mostra: com três tocas `pack_pairs` continua `n(n-1)/2` — 10 no fixture,
    15 na sessão real — enquanto a matilha se divide, e quem decide a coesão é `grupos`.

22. **A lista de bancadas é derivada do mundo por um único comprador, e um segundo comprador que
    remova bloco deixaria a lista apontando para o ar.** `_benches` é alimentada só pelos sinais do
    `Player`: `player.block_broken.connect(_on_block_broken)` e
    `player.block_placed.connect(_on_block_placed)` ([main.gd:182-183](../src/main.gd#L182-L183)), com
    os corpos em [`:937-946`](../src/main.gd#L1018-L1027); a leitura é `bench_positions()`
    ([`:950-951`](../src/main.gd#L1031-L1032)) e nada no caminho de `world.set_block` toca a lista —
    [`_write_raw`](../src/world/voxel_world.gd#L292-L301) e [`set_block`](../src/world/voxel_world.gd#L302-L315)
    escrevem voxel, `edits` e a fila de malha, não `_benches`. A única reconstrução é
    `_rebuild_benches()` ([`:1161-1165`](../src/main.gd#L1242-L1246)), chamada no load
    ([`:1088`](../src/main.gd#L1169)). Então **qualquer** agente que remova uma `BENCH` no mundo vivo
    deixa a lista e o `get_block` em desacordo até o próximo save/load, e o que consome
    `bench_positions()` (a HUD e o craft) vê uma bancada onde há ar. Hoje ninguém remove bancada por
    causa interna — os dois únicos `set_block` de gameplay são do jogador
    ([player.gd:685](../src/entities/player.gd#L685), [`:711`](../src/entities/player.gd#L711)) —, por
    isso o furo nasce **com** a pauta da 12 e não com código em execução. **Dono:** a perna 12, que o
    fecha **por construção** no §3.2 de [`docs/planos/12-bicho-cavando-voxel.md`](planos/12-bicho-cavando-voxel.md):
    o alvo do cavar exige `not world.edits.has(pos)`, e uma bancada colocada pelo jogador **é** edição
    registrada ([`edits[p]`](../src/world/voxel_world.gd#L54)), então ela não é terra solta para a pata
    de ninguém. O número que impede a cláusula de virar higiene estética é a checagem `cavar_nao_toca_construcao_alheia`
    (§5.7 da mesma página), que imprime `_benches.size()` e o bloco antes/depois com uma `BENCH` no
    caminho do lobo. Esta passada **não escreve** em `src/main.gd` nem na suíte.

23. **A permeabilidade do Éter é decidida por **um** voxel no canto da célula vizinha, e nenhuma
    leitura de "menos barreira" sobrevive a essa granularidade.** Na difusão, o peso do vizinho é
    `0.15 if world.is_solid(mid) else 1.0`, com `mid` = **origem** da célula vizinha
    ([`Vector3i((x + nx) * cell, …)`](../src/world/aether_field.gd#L174-L176)) e `cell =
    VoxelConfig.AETHER_CELL = 4` ([voxel_config.gd:16](../src/world/voxel_config.gd#L16),
    [aether_field.gd:24](../src/world/aether_field.gd#L24)). Consequência medida pela leitura: abrir ou
    fechar **um** buraco numa parede muda o fluxo **só** se esse buraco cair exatamente no voxel de
    canto da célula; uma célula de Éter é 4 × 4 × 4 voxels e os outros 63 não são consultados. É por
    isso que a frase do dossiê 12 de 2026-11-20 — "WORK + BLOOD difundem com menos barreira" como
    consequência observável de um bicho abrir a entrada de um rastro — **não é falsificável**, e a
    página re-escrita em 2026-11-22 re-baseou o item (b) em outra grandeza: o `y` que
    [`_scent_ground_y`](../src/entities/wolf.gd#L1025-L1029) devolve para a célula do achado, que é código
    que existe e lê cada voxel da coluna. **Nada aqui pede mudança de formato nem de canal:**
    `Channel.COUNT` ([aether_field.gd:9](../src/world/aether_field.gd#L9)) e
    `FORMAT_VERSION` ([tick_journal.gd:4](../src/persistence/tick_journal.gd#L4)) ficam intactos, então
    o furo é de **instrumento de leitura do mundo**, não de versão. **Dono:** a perna 05 (difusão fora
    do tick), porque qualquer amostragem por múltiplos voxels da célula — centro, média, ou "qualquer
    sólido na fatia" — é mudança de comportamento de difusão e tem de ser medida contra o hash por
    semente da própria 05, não emprestada de uma perna de IA. Esta passada registra e não escreve em
    `src/world/aether_field.gd`.

24. **O design declara `[DECIDED]` a árvore por arquétipo compartilhada, e o código monta uma árvore por
    entidade — a frase não é alvo, está marcada como decidida.** [docs/design/04-local-ai-architecture.md:44](design/04-local-ai-architecture.md#L44)
    escreve que "nós são **instanciados por espécie/archetype, não por entidade**", que "uma BT `.tres` é
    compartilhada por 1000 lobos" e que o estado vivo mora no `Blackboard` por entidade. Nada dos três
    nomes existe: não há **nenhum** `.tres` em `src/` — o único `.tres` rastreado no repositório é
    [`default_bus_layout.tres`](../default_bus_layout.tres), layout de barramento de áudio — não há classe
    `Blackboard` (a classe não existe — o único `blackboard` de `src/` é o comentário que promete o
    mecanismo, [src/ai/behavior/bt_tree.gd:3](../src/ai/behavior/bt_tree.gd#L3); o contexto chega como
    `Dictionary` literal inline no tick,
    [src/entities/wolf.gd:911](../src/entities/wolf.gd#L911)) e cada lobo constrói a própria árvore:
    `setup()` ([:299](../src/entities/wolf.gd#L299)) chama `_build_tree()` ([:318](../src/entities/wolf.gd#L318)),
    corpo em ([:422](../src/entities/wolf.gd#L422)). O comentário de topo do runtime repete a promessa
    ([src/ai/behavior/bt_tree.gd:2](../src/ai/behavior/bt_tree.gd#L2)), e é ela — não a linha do doc — que
    a pauta 20 §3.5 declara como **primeira compradora**: `SpeciesDef` existe para que a árvore deixe de
    ser por entidade. **Por que isto não é cosmético:** o custo da casa hoje é censo × orçamento, e a
    conta escrita no comentário de [src/main.gd:10-17](../src/main.gd#L10-L17) é 12 mentes × 400 µs =
    4,8 ms dos 50 ms do passo **com doze árvores vivas**; compartilhada de verdade, a árvore deixaria de
    crescer com o censo e o `HotSet` do mesmo doc (linha 108 em diante) deixaria de ser a peça cara que é.
    **Dono:** a perna 20, §3.5, e o número que impede a cláusula de virar prose é a checagem
    `arvore_por_arquetype` (§5 da mesma página), que imprime quantos objetos de árvore existem com dois
    lobos da mesma espécie. Esta passada **não escreve** em `src/ai/behavior/` nem em `src/entities/`.

25. **Dois `.uid` de teste estão fora do git, e todo clone limpo aparece sujo depois do `--import`.**
    `src/` tem 30 scripts `.gd` e 30 `.uid` rastreados; `tests/` tem **9** scripts
    ([tests/audio_test.gd](../tests/audio_test.gd), [tests/audio_live_probe.gd](../tests/audio_live_probe.gd)
    e os outros sete) e só **7** `.uid` no índice — faltam `tests/audio_test.gd.uid` e
    `tests/audio_live_probe.gd.uid`, que o `--import` volta a gerar e o `git status` volta a listar como
    `??`. Não é defeito de execução: nenhuma cena os referencia por `uid://` — o único consumidor é
    [tests/audio_live_probe.tscn:3](../tests/audio_live_probe.tscn#L3), e ele resolve por `path=` — e
    nenhum teste lê os dois arquivos. É **sujeira de instrumento**, e custa caro num lugar específico: o
    ciclo de trabalho exige re-medir no clone limpo (item 6) e a validade de uma corrida se declara por
    `git status` limpo, então duas linhas `??` permanentes obrigam a escrever, a cada leitura, que aquelas
    duas não são trabalho em andamento. **Dono:** arrumação do dono do repositório — `git add` dos dois
    `.uid` num commit de instrumentação próprio. Esta branch de pauta **não** os comita: ela não toca
    `tests/`, e commitar artefato alheio dentro de um commit de documento é exatamente o que a regra 6
    (um assunto por commit) proíbe.

## Contrato dos rastros e reações

- O estado novo pertence a `Wolf`; os três canais e a difusão de `AetherField` não foram
  alterados neste recorte. Detalhamento do ciclo em [§09.8](design/09-veloren-mechanics-adaptation.md#8-criaturas-o-que-virou-comportamento).
- Cada scan visita **49 células na camada do lobo × 3 canais = 147 leituras**, nominalmente a
  cada **0,25 s**, além de três amostras locais por tick. Se nenhuma devolve força acima de
  `SCENT_MIN`, o mesmo quadrado se repete na camada de cima e na de baixo: **cada camada
  vizinha aberta custa 98 leituras a mais** (dois canais por célula, sem FEAR) — **196 por
  scan** quando as duas abrem. Medido com contadores temporários: 567 scans e 479 entradas de
  camada vizinha contra o máximo possível de 1 134, isto é 46 942 das 111 132 leituras extras
  pagas; o escalonamento pelo nível próprio corta as outras 64 190 e devolve o `sim_step`
  integral de 2 768 passos de 427 537 µs (três camadas incondicionais) para 363 680 µs, sobre a
  base de 324 159 µs de uma camada
  ([evidence/rastro-duas-camadas/readback.log](evidence/rastro-duas-camadas/readback.log)).
  Ao terminar uma inspeção, há rescan no tick seguinte. Cinco lobos podem fazer essa leitura no
  mesmo tick; não há LOD por distância
  ([wolf.gd:875-904](../src/entities/wolf.gd#L875-L904)).
- O alvo do rastro é a **primeira superfície sólida descendo do topo da camada
  encontrada**, e não o topo da coluna: `surface_height()` dentro de caverna devolveria o
  teto, e o episódio lembrado diria que o sangue estava na superfície
  ([wolf.gd:980-988](../src/entities/wolf.gd#L980-L988)).
- A folha retorna `RUNNING` durante aproximação e inspeção, para a até **1,2 m**
  horizontais e exige **2 s** de inspeção antes do episódio. Troca de alvo, perda do
  rastro, outra intenção ou atordoamento cancelam o timer
  ([wolf.gd:444-472](../src/entities/wolf.gd#L444-L472)).
- Cache de **32 células/lobo**, força ponderada e validade de **30 s**: uma visita grava
  até nove células vizinhas **da camada encontrada**, com duas leituras por célula válida.
  Novo aumento de **0,06** ponderado ou expiração reabre a célula. `keys()` aloca no scan e
  na expulsão; esse custo de alocação não foi isolado
  ([wolf.gd:571-585](../src/entities/wolf.gd#L571-L585),
  [:701-774](../src/entities/wolf.gd#L701-L774)).
- O F3 expõe reação, canal, célula, força e tamanho do cache
  ([wolf.gd:1315-1320](../src/entities/wolf.gd#L1315-L1320)). O episódio usa ator **0**;
  nenhum consumidor deve interpretá-lo como autoria do jogador. Cache e timer não são
  persistidos nem cobertos pelo hash mínimo; load os limpa.

## Contrato do hash e journal mínimo

- `main.state_hash()` calcula SHA-256 de uma projeção versionada, não de `diagnostics()`:
  formato 1, semente real, `GEN_VERSION`, dimensões, tick, edições ordenadas por coordenada,
  mentes vivas ordenadas por identidade e suas crenças ordenadas por chave (confiança e
  origem incluídas), mais os bytes integrais dos três canais do Éter.
- O hash usa arrays canônicos e serialização binária do Godot, sem arredondamento de texto.
  A garantia é para o motor/plataforma fixados; compatibilidade binária entre versões ou
  arquiteturas diferentes não foi demonstrada.
- Não inclui corpos, jogador/inventário, episódios, personalidade, relações, cooldowns,
  fila de respawn ou RNG. Igualdade dessa projeção **não prova igualdade de toda a simulação**.
  Há locomoção e timers de lobo por frame ([wolf.gd:1203-1259](../src/entities/wolf.gd#L1203-L1259)),
  além do jogador; coletar hashes não muda essa autoridade nem elimina o RNG global.
- Gravação explícita: `-- --tick-journal=user://tick-run.jsonl`. O diretório deve existir e
  o arquivo deve ser novo; arquivo existente é recusado, nunca truncado. Cada linha é
  `[tick, "sha256"]`, escrita ao fim do tick, com `flush()` e erro propagado. Depois da
  primeira, só é aceita a próxima numeração, sem duplicata, regressão ou salto.
- Load válido encerra o journal **antes** de restaurar o estado; não reescreve a história nem
  mistura timelines. Nova gravação exige novo arquivo. Sem gravação não há hash por tick
  nem histórico crescente em RAM; com gravação a cópia do Éter tem **196.608 bytes/tick**
  (32 × 16 × 32 × 3 × 4, cálculo do layout), além das listas de edições/mentes/crenças.
- `diagnostics()["journal"]` expõe arquivo, atividade, registros, último tick/hash e
  `last_us`, `worst_us`, `total_us` do hash + escrita + flush; esse custo também entra em
  `worst_sim_ms`. Não há teto novo de performance declarado sem medição.

## Contrato do som

- **Consumidor, não produtor.** O diretor só lê o que o mundo já emite: seis sinais do jogador
  ([audio_director.gd:146-155](../src/audio/audio_director.gd#L146-L155)), três por lobo
  ([:158-162](../src/audio/audio_director.gd#L158-L162)) e o bloco sob os pés / sob a mira.
  Grep de `aether`, `imprint` e `AetherField` no arquivo devolve **zero** ocorrências, e o teste
  fecha quatro checagens no indicativo: hash do tick `98313688c61a -> 98313688c61a` com os nove
  eventos, RNG dos cinco lobos e da população intactas, `hp=100.0 edits=0 mined=0` depois de
  morder/minerar/quebrar, e `voxel=1` no mundo depois do `break` sonoro
  ([audio_test.gd](../tests/audio_test.gd)).
- **Ganho é derivação, não fader.** Cada arquivo é levado ao alvo de mixagem
  `MIX_TARGET_DB -20,0` subtraindo o nível médio **medido no próprio arquivo**
  (`assets/audio/levels.json`), com corte de ±14 dB
  ([:15-20](../src/audio/audio_director.gd#L15-L20), [ganho em :252](../src/audio/audio_director.gd#L252)).
  Dos 51 arquivos, um único encosta no corte — `ui_click` a -34,3 dB pediria +14,3 e fica em
  +14,0, 0,3 dB abaixo do alvo por decisão medida, não por falta. As camas recebem
  `AMBIENCE_TRIM_DB -12,0` ([amortecimento em :21-23](../src/audio/audio_director.gd#L21-L23)).
- **Famílias vêm do disco.** 27 famílias derivadas dos caminhos de `levels.json`, somando os 51
  arquivos sem sobrepor; o teste exige que nenhuma família medida fique sem uso e que nenhuma
  tabela aponte para arquivo inexistente. Passo e lavra são tabelas por bloco
  ([:67-95](../src/audio/audio_director.gd#L67-L95)) — o que se ouve é o material, não o id do
  save; água fica fora das duas porque quem responde é o `splash`.
- **Pool por duração, não por `playing`.** 12 vozes `AudioStreamPlayer3D` no barramento SFX com
  `max_distance 64`, uma no UI e duas camas no Ambience
  ([:25-26](../src/audio/audio_director.gd#L25-L26), [:307-325](../src/audio/audio_director.gd#L307-L325)).
  A liberação é o instante de relógio em que o arquivo acaba (`_busy`), porque `playing` só
  vira `false` no próximo tick de mix depois do fim. **Não** é um arranjo para o `Dummy` do
  headless: medido em [dummy-progress.log](evidence/audio/dummy-progress.log), com Dummy ativo
  a posição anda (0,189 → 1,395 s em 200 frames) e o `step_grass_1` de 0,778 s termina sozinho
  — a afirmação contrária estava escrita aqui e no comentário do código; ambas corrigidas.
- **Cadências são do corpo, não do frame.** Passo por distância (1,9 m andando, 1,4 m nadando,
  abaixo de 0,4 m/s não é passo — o mesmo limiar do bob da câmera), teleporte não é caminhada
  (`MAX_STRIDE_JUMP 10,0`), tick de lavra a cada 0,3 s com intervalo reiniciado por alvo novo,
  ambiência 1×/s com 98 leituras por avaliação (7×7 na camada do pé e na de baixo),
  latido até 14 m com cooldown de 3 s, uivo raro com cooldown de 18 s e gate global
  ([:27-44](../src/audio/audio_director.gd#L27-L44), [:433-534](../src/audio/audio_director.gd#L433-L534)).
- **RNG própria e estado volátil.** `_rng` semeada por `AUDIO_SEED 20261118`
  ([:45-47](../src/audio/audio_director.gd#L45-L47)) sorteia variante dentro da família, reproduz
  a mesma sequência e não disputa com os sorteios da simulação. O estado de corpo é keyed por
  `wolf.identity` e limpo no load ([main.gd:1170](../src/main.gd#L1170),
  [clear_transient em :166-169](../src/audio/audio_director.gd#L166-L169)): posição antiga não
  diz nada sobre o mundo carregado. Nada do áudio entra no save nem no hash por tick.
- **Audibilidade não é headless.** O driver do headless é `Dummy`: `playing` liga e o que sai do
  mixer é silêncio — mas a posição **anda** e o stream não-looping termina (números acima). O
  medidor de pico do barramento também **não discrimina**: a corrida que caiu em Dummy marcou
  -12,7 dB no SFX. A prova de que o som chega ao aparelho é a sonda em
  janela ([audio_live_probe.tscn](../tests/audio_live_probe.tscn)), que checa
  `driver != "Dummy"` **antes** dos picos.

## Notas de medição

**Pins de fonte × clone publicado.** Cada bloco abaixo pinou as fontes do *seu* candidato, e a
casa mexeu nesses arquivos depois: conferido agora, na árvore de trabalho, o
[manifesto de fp-hand](evidence/fp-hand/sources.sha256) diverge em **8** arquivos,
[o de rastros](evidence/aether-reactions/sources.sha256) em **9**,
[o de RNG](evidence/simulation-rng/sources.sha256) em **6**,
[o de journal](evidence/tick-journal/sources.sha256) em **8** e
[o de som](evidence/audio/sources.sha256) em **4** — é histórico por construção, e linha de
tabela que hoje não confere não se vende como conferindo. O pin vivo é o
[manifesto de 79 fontes](evidence/third-person-carry/sources.sha256) desta revisão, que confere
**79/79 dentro do clone limpo de `a8967e0`** (linha `clone_verify` da
[conferência](evidence/third-person-carry/readback.log)). As assinaturas de artefatos, essas sim,
são todas atuais e conferem no clone: rastros 15/15, som 16/16, mão 25/25, RNG 19/19, journal
15/15, porte 10/10 lá e 12/12 na árvore (os dois logs do clone nasceram depois da corrida que os
registra). Isso só é verdade porque [`.gitattributes`](../.gitattributes) congela `docs/evidence`
com `-text`: sem essa linha o `* text=auto eol=lf` do mesmo arquivo reescreveria os 51 arquivos
de texto da pasta que carregam CR e nenhum SHA publicado bateria (furo #11).

### af-bench `boot_walk_10min` — re-medido na árvore do pin `9b2c65a` (2026-11-23, `bench/af-bench-boot-walk-07b`)

Medição serial, máquina livre, engine `4.7.2.stable.official.ed1daf0bf`. Três corridas de 12 000 ticks
com `dt` fixo, cada uma em `.jsonl` novo (o `TickJournal.start()` recusa caminho existente). Critério do
dossiê 07 §6: `records == 12000`, `dropped_ticks == 0`, hash da última linha idêntico nas três, exit 0.

| Corrida | exit | `records` | `dropped_ticks` | hash última linha | SHA-256 do `.jsonl` | `gen_ms` | `mesh_ms` | `worst_sim_ms` | runner (s) | parede (s) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `run-1` | 0 | 12 000 | 0 | `fd9b41e0…6d604a32` | `3e6aaf49…8684661f` | 942,5 | 4 314,3 | 13,09 | 45,978 | 46,619 |
| `run-2` | 0 | 12 000 | 0 | `fd9b41e0…6d604a32` | `3e6aaf49…8684661f` | 945,9 | 4 318,9 | 14,60 | 45,719 | 46,324 |
| `run-3` | 0 | 12 000 | 0 | `fd9b41e0…6d604a32` | `3e6aaf49…8684661f` | 939,5 | 4 319,2 | 14,70 | 45,724 | 46,331 |

Os três `.jsonl` são byte-idênticos (as 12 000 linhas, não só a última): `3e6aaf49b88fc37c34a619ed6d957604b07b674d90a10ea0b6137c238684661f`,
888 894 bytes cada. O hash cheio é `fd9b41e0dc3ae2eb5f4c76cd6467ffc8d6204134354e5f765fbc1f6f6d604a32`. O
`gen_ms`/`mesh_ms`/`worst_sim_ms` vêm da linha nova de `OBSERVACAO` que o runner passou a imprimir do
`diagnostics()` — a rodada dupla (com e sem a linha) deu o mesmo hash, prova de que `print` não entra no
estado. O `estouros_guarda` foi 16 nas três, nos mesmos oito pares tick/lobo (só o `last_us` oscila), o
que mantém o argumento honesto: "a mesma sorte", não prova limpa — o canal do relógio da guarda
([`src/ai/behavior/bt_tree.gd:130-137`](../src/ai/behavior/bt_tree.gd#L130-L137)) segue aberto.

O hash desta árvore (`fd9b41e0…`) **não** é o da base `99d1167` (`a6addd…`) nem deve ser confundido com
ele: entre as duas pontas entraram as pernas 16 e 19, que mudaram spawn/tocas na projeção. A roda mede
`src/` idêntico ao pin `9b2c65a` (`64f137bcb1f8…`), e a suíte re-rodada dá **255 / 0 / 47,4 s**, exit 0.
Nada aqui fecha gate de fase nem o bake-off (§4) — só o instrumento e a medição nesta revisão. Prosa e
âncoras por extenso: [readback.md](evidence/af-bench-boot-walk/readback.md).

### Porte do corpo em terceira pessoa — publicado em a8967e0

Base Git `1db00cf0cdcbfbdac88dc980127c1720b4b6e4ef` + as alterações locais desta árvore (som,
journal, RNG, rastros, mão e agora o porte em 3ª pessoa), que são o commit `a8967e0`. Os braços
vermelho e verde rodam **na árvore de trabalho**; as duas últimas linhas da tabela rodam num
**clone limpo** de `a8967e0`, sem `.godot/` e sem `.tools/`, importado pela receita do README. As
fontes estão pinadas por
[manifesto](evidence/third-person-carry/sources.sha256) — **79 arquivos** de código, cenas, UIDs,
ícone, configuração e `assets/audio/levels.json`, SHA-256 do manifesto
`17ddce7fc2017bbc1442d9e6f4581b29012b567636240f239115305be29ebd7d`. A
[conferência](evidence/third-person-carry/readback.log) extrai as duas contagens, as duas linhas
da checagem e as quatro frações visíveis de cada braço de janela. A pose anterior está copiada
por inteiro em
[player_avatar.before.gd.txt](evidence/third-person-carry/player_avatar.before.gd.txt)
(SHA-256 `238809d34e9df62952b7019e4c8303af53eb26f587d75f7b986e4e708f9df4b3`): o braço vermelho
volta exatamente ela, reescrevendo as três consts, e o verde é o arquivo que está na árvore.
Engine 4.7.2-stable `ed1daf0bf`, Windows, AMD Radeon RX 9060 XT, corridas seriais com a máquina
livre, sem tecla sintética e sem captura de desktop — a sonda de janela desenha e lê os próprios
pixels, o jogo nunca recebeu input dela.

| Corrida | Resultado observado | Evidência |
|---|---|---|
| Braço vermelho — a checagem nova sobre a pose anterior | **232 checagens / 1 falha**, 33,8 s, exit 1: `[FAIL] bloco na mao passa para fora do braco no quadro da orbita livre pedra=0.02  folha=0.00` | [arm-red-suite.log](evidence/third-person-carry/arm-red-suite.log) |
| Braço verde — a mesma checagem sobre a pose atual | **232 checagens / 0 falhas**, 33,7 s, exit 0: `livre pedra=0.45  folha=0.30`; uma linha de `ERROR:` no quit, a dupla de vazamento já debitada na seção do som | [arm-green-suite.log](evidence/third-person-carry/arm-green-suite.log) |
| Enquadramento da órbita dentro da suíte (corrida instrumentada, com as linhas `DBG` que depois saíram do arquivo; a suíte publicada continua 232/0) | `cam=(64.5, 32.55, 68.9)`, `dist_pivot=4.40`, `av=(64.5, 31.0, 64.5)`, `vp=(64,64)` — e a checagem permanente `projecao da suite bate com a do motor` marca desvio 0,00046 px | [framing-debug.log](evidence/third-person-carry/framing-debug.log) |
| Fração de pixels reais do cubo visível, pose anterior (janela 1280×720) | grama **0,000**, pedra **0,062**, folhas **0,019**, neve **0,000**; recorte projetado do cubo entre 21 e 26 px de lado | [pixel-probe-before.log](evidence/third-person-carry/pixel-probe-before.log) |
| Fração de pixels reais do cubo visível, pose atual | grama **0,288**, pedra **0,405**, folhas **0,294**, neve **0,304**; recorte 31–41 px | [pixel-probe-after.log](evidence/third-person-carry/pixel-probe-after.log), [código da sonda](evidence/third-person-carry/held_tp_probe.gd.txt) |
| Galeria completa com a pose nova | 11 frames de uma única corrida, `GALERIA ok`, zero `SCRIPT ERROR`, zero `ERROR:` | [gallery.log](evidence/third-person-carry/gallery.log) |
| Clone limpo de `a8967e0`, `--import` sem cache | exit 0, 299 linhas, **zero** `ERROR`, `WARNING` e `SCRIPT ERROR` | [clone-import.log](evidence/third-person-carry/clone-import.log) |
| Suíte no mesmo clone | **232 checagens / 0 falhas**, 33,7 s, exit 0; `tick=359`, `dropped_ticks=0`, `worst_sim_ms=6,78`, geração 926,4 ms, malharia 4.134,9 ms, `projecao da suite bate com a do motor` com desvio 0,00046 px; as duas linhas de vazamento do quit, já debitadas | [clone-suite.log](evidence/third-person-carry/clone-suite.log) |
| Assinaturas conferidas **dentro** do clone | 79/79 fontes do manifesto; `artifacts.sha256` das seis pastas OK (aether-reactions 15/15, audio 16/16, fp-hand 25/25, simulation-rng 19/19, tick-journal 15/15, third-person-carry 10/10 — os dois logs desta corrida ainda não estavam no manifesto do clone) | [readback.log](evidence/third-person-carry/readback.log), linhas `clone_*` |

**O que foi observado além do contador**, tudo impresso nos próprios logs:

- **A queixa do dono virou unidade própria.** "faltou animar em relação ao que ele está
  segurando" foi medida como a fração da face do cubo que nenhum outro corpo do avatar tapa, no
  enquadramento que a órbita realmente mostra — não como "o braço mudou de ângulo". Os dois
  sentidos da atribuição usam o mesmo instrumento: a pose velha devolve 0,02/0,00 e cai em
  vermelho, a nova devolve 0,45/0,30 e passa — o corte de 0,15 fica abaixo do pior braço novo
  (0,30) e acima do que a pose velha media (0,02 e 0,00), então nem é ajuste posterior nem
  tolerância folgada.
- **Conferido em dois instrumentos, sem exigir que sejam iguais.** O número da suíte é
  geometria: 64 pontos da face projetada do cubo, contados como cobertos quando o retângulo
  projetado de um corpo *mais próximo* os contém. O da sonda de janela é pixel: renderiza o
  quadro com o bloco, renderiza sem, e conta os pixels do mesmo recorte que mudaram de verdade
  (soma > 0,08 em RGB). Cada um erra para um lado — o primeiro trata braço como caixa, não como
  silhueta; o segundo conta como "não visível" o pixel do retângulo que o próprio cubo girado
  também não pinta. Mesmo assim os dois têm a mesma direção e a mesma ordem: pedra
  0,02 → 0,45 e folha 0,00 → 0,30 na geometria, 0,062 → 0,405 e 0,019 → 0,294 no pixel. É
  sanidade de instrumento, não igualdade medida.
- **Premissa montada pelo jogo, não escrita à mão.** O `yaw`/`pitch` são zerados no passo
  ([smoke_test.gd:2754-2758](../tests/smoke_test.gd#L2754-L2758)) porque a órbita de trás só
  existe com o olhar neutro: herdado do passo anterior, o ângulo girado fez a pose velha marcar
  0,75 "livre" num quadro que o olho mede 0,02. É o mesmo formato de furo do #6 (mira herdada),
  agora do lado da câmera.
- **O peso vem da regra, não de tabela nova.** `_load = hardness(block_id) / LOAD_REF` com
  `LOAD_REF = 0.95` — o máximo que `BlockDefs.hardness` devolve hoje — então pedra vale 1,00 e
  folha 0,23 no mesmo braço; a sonda impressa mostra o cubo de pedra pendurado em y 0,70 e o de
  folha no peito em y 1,14, com cotovelo 0,28 contra 1,26.
- **O que a checagem NÃO prova:** que o porte ficou bom a olho em toda pose e todo bloco — a
  galeria é a única testemunha disso, conferida por mim e não por gate; e nada aqui toca IA,
  determinismo ou custo do caminho quente (o braço se move em `_physics_process`, não em
  `_sim_tick`).

Nenhum gate de fase se fecha com isto: P0 e P1 continuam abertos, e a aprovação a olho do
porte é do dono. O que fechou foi o bloco de medição — a árvore virou commit `a8967e0`, o clone
limpo dele foi reimportado sem cache e devolveu o mesmo **232 / 0 / 33,7 s** da árvore de
trabalho, com as assinaturas conferidas dentro do próprio clone. Faltava só isto para o número
publicado deixar de ser hipótese.

### Som — publicado em a8967e0

Base Git `1db00cf0cdcbfbdac88dc980127c1720b4b6e4ef` + alterações locais de som, docs e das
sondas de diagnóstico. As corridas abaixo rodam **na árvore de trabalho**, não em clone: as fontes
estão pinadas por [manifesto](evidence/audio/sources.sha256) — **79 arquivos** de código, cenas,
UIDs, ícone, configuração e o `assets/audio/levels.json` que deriva o ganho, SHA-256 do manifesto
`62456b0b6e84a87f3ab6d792bdc85f6fe5ed37f7834d3032da7416455e108a20`. A
[conferência](evidence/audio/readback.log) extrai cada contagem dos logs e exige que a única
linha de erro presente seja a dupla de vazamento do quit nos quatro logs onde ela é esperada
(censo, smoke, custo e a própria sonda de progresso).
Estas corridas são da árvore de trabalho, e o código que elas medem é o do commit `a8967e0`:
dentro do clone limpo dele as 79 fontes conferem byte a byte e as 16 assinaturas desta pasta
também, mas a suíte re-rodada no clone **não contém nenhuma linha de som** — os 232 passos são
mundo, corpo, IA, persistência e HUD. O runner dedicado `audio_test` ficou na árvore, e a
sonda viva exige janela. Nenhum número daqui é prova de custo de commit. Engine 4.7.2-stable `ed1daf0bf`, Windows, corridas seriais com a máquina livre, sem
captura de desktop e sem entrada sintética. A sonda viva abre janela própria porque em headless
o driver `Dummy` não entrega som a nenhum aparelho — os outros números do headless são medidos
de verdade, inclusive a posição de playback. Nenhuma tecla foi enviada à sonda: os 13 toques
saem do jogo sozinho.

| Corrida | Resultado observado | Evidência |
|---|---|---|
| Suíte do áudio (novo runner, 6 testes) | **73 / 0**, 6/6, exit 0, **5,404 s**; duas linhas de vazamento no quit (12 instâncias / 6 recursos) | [suite-audio.log](evidence/audio/suite-audio.log) |
| Smoke completo com o diretor ligado | **220 / 0**, exit 0, **33,7 s**; tick 359, `dropped_ticks=0`, pior passo **8,44 ms**; boot gen 932,2 ms / malha 4.116,9 ms; 64 chunks, 14 edições, 149 meshes, 214.480 triângulos, 4 lobos vivos; journal inativo; vazamento no quit de 8 / 4 | [smoke.log](evidence/audio/smoke.log) |
| Regressões na mesma árvore | journal **128 / 0** em 5,353 s; RNG **27 / 0** em 2,719 s; rastros **89 / 0** em 1,617 s — os três **sem** nenhuma linha de vazamento | [regression-journal.log](evidence/audio/regression-journal.log), [regression-rng.log](evidence/audio/regression-rng.log), [regression-reactions.log](evidence/audio/regression-reactions.log) |
| Colheita de custo do diretor | setup 743 µs; 10 avaliações de ambiência 1.000 µs; 600 updates de corpo 1.831 µs; 1º evento frio 1.627 µs; 99 seguintes com cache quente 65.856 µs | [cost.log](evidence/audio/cost.log) |
| Sonda viva, corrida 1 | exit 1: 13 toques, `-0,5 dB` no Master, mas `familias novas: []` derrubou "quem tocou foi um corpo" — premissa errada do meu instrumento, não do som (furo #9) | [live-1-red-premissa.log](evidence/audio/live-1-red-premissa.log) |
| Sonda viva, corrida 2 | exit 1: WASAPI `ERR_CANT_OPEN` em `audio_driver_wasapi.cpp:275` → fallback `Dummy`; **mesmo assim** o medidor marcou -12,7 dB no SFX e a checagem do driver foi a única que pegou | [live-2-red-dummy.log](evidence/audio/live-2-red-dummy.log) |
| Sonda viva, corrida 3 | exit 0, **WASAPI**: 13 toques em 6 s sem input (`step_grass` 6, `step_snow` 6, `splash` 1), cama `amb_birds`, picos **master -7,4 / sfx -9,9 / ambience -7,4 dB** | [live-3-green.log](evidence/audio/live-3-green.log) |
| Sonda de vazamento, seis braços | todo braço que sai com stream tocando vaza 4 instâncias/2 recursos; `stop()` no mesmo tick **não** muda nada; `stop()` + 20 frames limpa. `pos=0.186` prova que o stream tocou de fato | [leak-probe.log](evidence/audio/leak-probe.log), [código do braço](evidence/audio/leak-probe.gd.txt) |
| Sonda de progresso em headless | com o driver `Dummy` a posição **anda** (0,189 → 1,395 s em 200 frames) e o `step_grass_1` de 0,778 s **termina sozinho** (`playing=true` no frame 100, `false` no 120); a cama de 30,688 s continua tocando porque só 1,4 s dela se passaram. Desfez a frase "no headless o stream nunca termina", que estava no código e em dois docs | [dummy-progress.log](evidence/audio/dummy-progress.log), [código da sonda](evidence/audio/dummy-progress.gd.txt) |
| Vermelho de premissa do RNG | 9 checagens / 7 falhas com `SCRIPT ERROR: ... 'on_wolf_registered' in base 'Nil'` — o passo chamava o spawn sem o diretor criado; hoje o gancho é guardado e a corrida verde acima refaz 27/0 | [red-rng-audio-nulo.log](evidence/audio/red-rng-audio-nulo.log) |

**O que foi observado além do contador**, tudo impresso nos próprios logs:

- **O som não move o estado autoritativo:** os nove eventos dão `events_played` 0 → 9 e o hash do
  tick atravessa igual (`98313688c61a -> 98313688c61a`); a RNG dos cinco lobos e a da população
  não consomem nada; depois de morder, minerar e quebrar bloco o mundo continua
  `hp=100.0 edits=0 mined=0` e o voxel quebrado de verdade no teste de áudio é um (`voxel=1`,
  conferido no mundo, não no contador do diretor).
- **Cadência é de distância, não de frame:** 4 passos para 7,95 m andados, esperado 4,18 pelo
  quociente `metros / 1,9`; parado, zero passos novos; lavra deu 3 ticks em 1,20 s com o teto de
  5 respeitado — o intervalo de 0,3 s não encolhe sozinho.
- **Água existe no mapa e é ela que toca:** o lago da corrida está em (73, 26, 55), o corpo dentro
  da coluna fica `feet=(73.5, 26.002, 55.5)`, entrar produz `splash=1` e a cama troca para
  `amb_water` com as duas camas tocando durante o crossfade (`tocando=2`).
- **Estado volátil tem dono e tem limpeza:** 6 registros de corpo (5 lobos + jogador) e
  `clear_transient` devolve `chaves=0` depois do load.

**Limites do que estas corridas sustentam:** audibilidade só existe em janela, e janela exige
endpoint de render aberto — a corrida 2 mostra o mesmo código mudando de verde para vermelho por
causa do dispositivo. Não há linha de áudio no F3 nem chave `audio` em `diagnostics()`. O
vazamento do quit é do engine e fica nos logs enquanto houver stream tocando na saída. O canal
SOM do Éter (item 4) não foi escrito por nada daqui. E os 51 arquivos em si não dependem destas
corridas: a procedência e o SHA por arquivo estão em [audio-provenance.md](audio-provenance.md),
conferíveis com `sha256sum -c docs/audio-sha256.txt`.


### RNG da matilha — publicado em a8967e0

Base Git `1db00cf0cdcbfbdac88dc980127c1720b4b6e4ef` + alterações locais de hash/journal,
rastros, mão e deste recorte. Um clone novo recebeu as fontes atuais sem `.godot/` e passou pelo
`--import` antes das corridas. Os **73 arquivos** de código, cenas, UIDs, ícone e configuração
conferem byte a byte entre raiz e candidato no
[manifesto de fontes](evidence/simulation-rng/sources.sha256), SHA-256
`e5fc11fd1ab673c2fd84e669df0e9bbec963f8ef2888183999c8bb290e1d2cf5`; a
[conferência](evidence/simulation-rng/readback.log) refaz a comparação, verifica as 205 linhas do
journal contra o diagnóstico e conta as 220 linhas PASS de cada smoke — pin histórico do
candidato, ver a nota dos pins acima. As
[assinaturas dos artefatos](evidence/simulation-rng/artifacts.sha256) conferem cada um dos
outros 19 arquivos da pasta, todos os logs incluídos. O `user://` das corridas
foi isolado ([isolation.cfg](evidence/simulation-rng/isolation.cfg)); o caminho efetivo aparece
no log do contrato como `.../Aetherfall-rng-validation-20261118-cf727d40` e foi lá que o smoke
escreveu `saves/world_alpha.json` — o slot do jogador não foi tocado.

| Corrida | Resultado | Evidência |
|---|---|---|
| Vermelho: teste novo sobre a produção anterior | 27 checagens / **11 falhas**, exit 1, 3,636 s | [log](evidence/simulation-rng/red-baseline.log), [main.gd](evidence/simulation-rng/before-main.gd.txt), [wolf.gd](evidence/simulation-rng/before-wolf.gd.txt), [teste](evidence/simulation-rng/before-simulation_rng_test.gd.txt) |
| Verde: candidato recém-importado | 27 / 0, exit 0, 3,419 s | [log](evidence/simulation-rng/rng.log), [import](evidence/simulation-rng/import.log), [clone](evidence/simulation-rng/clone.log) |
| Regressão de rastros no candidato | 89 / 0, exit 0, 1,964 s | [log](evidence/simulation-rng/reactions.log) |
| Contrato do journal no candidato | 128 / 0, 7/7 testes, 6,576 s | [log](evidence/simulation-rng/contract.log) |
| Smoke sem journal | 220 / 0, exit 0, 38,4 s; pior passo 10,71 ms, `dropped_ticks=0` | [log](evidence/simulation-rng/smoke-off.log) |
| Smoke com journal | 220 / 0, exit 0, 35,5 s; 205 registros, 152 125 µs somados, pico 1 479 µs, pior passo 7,89 ms, `dropped_ticks=0` | [log](evidence/simulation-rng/smoke-on.log), [journal](evidence/simulation-rng/ticks.jsonl) |

As onze linhas vermelhas nomeiam cada premissa, e nenhuma delas é sorte: população reagindo a
sorteios globais estranhos (2), spawn/setup, patrulha e desvio consumindo o gerador global (3),
o rastro da patrulha mudando entre braços e identidades distintas devolvendo a **mesma**
sequência (3), o desvio repetindo o mesmo acoplamento (2), e outra semente de mundo não alterar
o lobo de mesma identidade (1). No verde, as mesmas linhas fecham com os números da corrida:
`patrulha real renova destino | ticks=240 destinos=2`,
`rastro leva a colisao e desvio reais | frames_bloqueados=679 desvios=22`,
`identidades distintas tem sequencias distintas | id1=7abb06aa… id2=70f725c5…`.

**O corte, em três decisões.** `_population_rng` ([main.gd:91](../src/main.gd#L91)) sorteia as
casas da matilha; `_rng` ([wolf.gd:215](../src/entities/wolf.gd#L215)) sorteia patrulha e desvio.
As sementes vêm de `("population:%d" % world.gen.world_seed).hash()` e
`("wolf:%d:%d" % [world.gen.world_seed, identity]).hash()` — a semente *real* do mundo, de 64
bits, em vez do inteiro de 32 bits do engine. O gerador da população só é semeado quando
`_next_identity == 0` ([main.gd:338-339](../src/main.gd#L338-L339)), para que um lote de respawn
continue o fluxo em vez de repetir as primeiras casas. O grep de `randf`/`randi`/`randf_range`
sem receptor em `src/` devolve zero ocorrências; sobram dois locais com gerador próprio
([mind.gd:36-38](../src/ai/mind.gd#L36-L38), [voxel_atlas.gd:50-63](../src/world/voxel_atlas.gd#L50-L63))
e o `seed(SEED)` de [tests/aether_reactions_test.gd:322](../tests/aether_reactions_test.gd#L322),
que desde este corte não muda mais decisão nenhuma — é exatamente o que a checagem
"não consome RNG global" mede.

**As quatro perguntas do mandato de otimização, respondidas.** Roda na criação (uma semeadura por
sessão e uma por lobo) e dentro das decisões que já sorteavam: um sorteio por renovação de
patrulha (cooldown de 4–9 s) e até três por evento de bloqueio. Entidades alcançadas: 5 lobos e
1 jogador. Alocação no caminho quente: nenhuma por sorteio — seis `RandomNumberGenerator` vivos
por sessão, o resto é substituição de chamada. Como sei que ficou melhor: não sei, e não preciso
— a mudança é de propriedade, não de velocidade; o que se colhe é o custo do passo, que não
subiu (`sim_step` do cenário de rastros: passos=1939, total 288 208 µs, pico 699 µs; BT soma
13 796 µs, pico 106 µs contra os 400 µs do orçamento, **estouros 0**), e o pior passo dos smokes
continua dentro dos 50 ms com `dropped_ticks = 0`. O agregado HOT das cinco mentes simultâneas
segue sem medição e segue gate aberto.

**A premissa errada que o corte revelou, nos dois sentidos.** Com o RNG isolado, o passo de
knockback das reações falhou duas vezes com `vetor=(-0.927964, 0.0, 0.37267)` contra
`esperado=(-0.905916, 0.0, 0.423457)`. A [sonda de atribuição](evidence/simulation-rng/attribution.log)
([código](evidence/simulation-rng/attribution-probe.gd.txt), 9 checagens)
mediu o ângulo no instante da decisão e no instante da checagem: `dot=1.000000000` contra
`dot_original=0.998467147`, e o `dot_previsto` a partir do deslocamento do centro
(`delta=(-0.113979, 0.0, 0.279793)`) é **o mesmo 0.998467147** — o erro era inteiramente
explicado por os três frames de física seguintes moverem o corpo, com `original_passaria=false`.
O outro sentido: o passo corrigido rodando contra a **produção anterior** ao corte deu
**89 / 0** ([log](evidence/simulation-rng/reactions-corrected-old-production.log)), então o RNG é
indiferente àquela diferença. Corrigiu-se o instante da asserção
([aether_reactions_test.gd](../tests/aether_reactions_test.gd),
[código anterior](evidence/simulation-rng/before-aether_reactions_test.gd.txt)), não a tolerância
e não o comportamento do lobo, porque a regra da casa é a checagem nomear a premissa que exige.

**Limites, emprestando nada.** (1) Isto não é replay: a projeção do hash continua sem RNG, corpos
ou jogador, e o `last_hash` do smoke (`a969dac5…`) é a assinatura de uma corrida, não um par
reproduzido. (2) O load **não** restaura geradores: `_population_rng` só é semeado no primeiro
lote e `_rng` só no `setup()` do spawn, e `load_state()` não re-semeia — depois de um load o
fluxo é o que a sessão deixou, que é justamente a "restauração de RNG" pendente do item 2.
(3) O cenário cobre 240 ticks de patrulha e um de colisão; não cobre save/load de gerador nem
consumidores futuros. (4) A simulação ao vivo continua não determinística por outro motivo:
jogador e corpos dos lobos mudam por frame. (5) Candidato local identificado por SHA-256, não
clone de um commit publicado; nenhum gate de fase se fecha aqui.

Comandos da corrida, com o `user://` isolado aplicado na árvore que roda e a máquina livre:

```sh
godot --headless --path . --import
godot --headless --path . --script tests/simulation_rng_test.gd
godot --headless --path . --script tests/aether_reactions_test.gd
godot --headless --path . --script tests/tick_journal_test.gd
godot --headless --path . tests/smoke_test.tscn
godot --headless --path . tests/smoke_test.tscn -- --tick-journal=CAMINHO-NOVO.jsonl
```

### Bloco na mão — publicado em a8967e0

Causa reproduzida na GPU: o bloco era opaco, mas os dedos desenhavam depois dele com
`no_depth_test`. Mudança funcional única: prioridade do material do item de 13 para 15
([fp_viewmodel.gd:232-240](../src/entities/fp_viewmodel.gd#L232-L240)); nenhuma geometria,
textura, animação ou alocação por frame acrescentada. É ordenação das camadas existentes,
não teste de profundidade interno novo nem otimização de desempenho medida.

O [teste de renderização](../tests/fp_viewmodel_render_test.gd) usa o view model e atlas
reais, câmera 1280×720, Forward+ na RX 9060 XT, sem MSAA/TAA. Compara o interior da
silhueta do bloco isolado com o mesmo bloco junto da mão; exclui um pixel de borda e
exige mais de 500 pixels interiores, impedindo aprovação de imagem vazia. Uma pose de
repouso, uma de golpe, uma de lavra, pedra e uma parede a 0,10 m exercitam a sobreposição;
vidro e slot vazio também são renderizados. As sete imagens finais foram inspecionadas.

| Corrida | Resultado | Evidência |
|---|---|---|
| Antes, mesmo teste | 21 checagens / 10 falhas, exit 1; grama 5.319 pixels sobrescritos de 19.616 | [log](evidence/fp-hand/before.log), [imagem](evidence/fp-hand/before-grama.png) |
| Após a correção, árvore local | 21 / 0, exit 0; zero pixels sobrescritos nos cinco casos opacos | [log](evidence/fp-hand/after.log), [imagem](evidence/fp-hand/after-grama.png) |
| Candidato novo, após importação sem cache | 21 / 0, exit 0; mesmos censos e pixels | [import](evidence/fp-hand/import.log), [render](evidence/fp-hand/candidate-render.log) |
| Smoke do candidato, journal desligado | 220 / 0, exit 0, 35,2 s; nenhuma perda de tick | [log integral](evidence/fp-hand/smoke.log) |

O candidato é clone de `1db00cf` com fontes locais sobrepostas — o mesmo conteúdo que hoje é o
commit `a8967e0`. No clone limpo publicado as **25** assinaturas de artefatos desta pasta
conferem OK; o teste de render em janela, que exige dispositivo de renderização, não foi
re-rodado nele, e o pin de fontes desta seção é histórico (ver a nota dos pins acima).
[Manifesto de 71 arquivos](evidence/fp-hand/sources.sha256), SHA-256
`57a2afde872e27ffec2e123b34ffb0ad2a27e68b12073c65e0f11b330ef5c017`;
[conferência](evidence/fp-hand/readback.log) confirma identidade byte a byte com a árvore
local e 220 linhas PASS. O [isolamento](evidence/fp-hand/isolation.cfg) direcionou o save
para `Aetherfall-hand-validation-20261118-cf727d40`, sem usar o slot do jogador.
[Fontes anteriores](evidence/fp-hand/before-fp_viewmodel.gd.txt) e
[cópia do teste](evidence/fp-hand/render-test.gd.txt) permitem repetir o braço vermelho;
[assinaturas dos artefatos](evidence/fp-hand/artifacts.sha256) incluem logs e PNGs.

Reprodução no Windows, com a máquina livre e janela fora da área visível:

```sh
godot --path . --display-driver windows --rendering-driver vulkan --rendering-method forward_plus --audio-driver Dummy --position 6000,6000 --resolution 1280x720 --max-fps 60 --quit-after 900 --script tests/fp_viewmodel_render_test.gd
```

A posição da janela precisa ficar fora dos monitores locais. Não usa captura do desktop
nem entrada sintética. `--headless` não substitui este teste de pixels: sem dispositivo de
renderização ele falha explicitamente. O teste tem watchdog de 15 s, contagem de cenários
e checagens; `--output-prefix=CAMINHO` após `--` grava PNGs novos, sem sobrescrever.
Não cobre todas as fases das animações nem outros renderers; a suíte geral mede os arcos.
As medições de rastros/journal abaixo continuam históricas, anteriores a esta mudança.

### Rastros e reações — publicado em a8967e0

Base Git `1db00cf0cdcbfbdac88dc980127c1720b4b6e4ef` + alterações locais de hash/journal
e rastros. Um novo clone recebeu as fontes atuais, sem copiar `.godot/`, e passou pelo
`--import` antes das corridas. Os **69 arquivos** de código, cenas, UIDs, ícone e
configuração conferem byte a byte entre raiz e candidato no
[manifesto de fontes](evidence/aether-reactions/sources.sha256), cujo SHA-256 é
`3160ed29ef8e8e63029cb5e7d0f168f03c27d167f4c679ed7d86d65386ce2911`.
Isso identifica o candidato da época. O clone limpo de `a8967e0` existe e re-mediu a suíte
completa (232 / 0 / 33,7 s, tabela do porte), e as **15** assinaturas de artefatos desta pasta
conferem OK dentro dele; o runner dedicado de rastros e os smokes com gravação ficaram no
candidato, e o pin de 69 fontes é histórico (nota dos pins, acima).

O [override](evidence/aether-reactions/isolation.cfg) existe somente no candidato e
isola `user://` em `Aetherfall-trails-validation-20261118-cf727d40`; o contrato imprime
o caminho real. Ambos os smokes escrevem seu `alpha` de teste, sem tocar no save normal.
As corridas finais foram seriais, sem outro Godot em execução, no 4.7.2-stable `ed1daf0bf`,
headless. Nenhuma janela foi aberta nem houve captura ou entrada sintética no desktop.

| Corrida | Resultado observado | Evidência |
|---|---|---|
| Histórico exploratório, runner inicial de 9 cenários | 46 checagens / 18 falhas antes; 46 / 0 após a primeira implementação, exit 1 / 0; 1,308 / 1,207 s | [initial-before.log](evidence/aether-reactions/initial-before.log), [initial-after.log](evidence/aether-reactions/initial-after.log) |
| Três bordas reproduzidas, runner ampliado | 89 / 4, 17/17 funções, exit 1, 1,693 s: busca de presa morta, episódio durante golpe e duas falhas de renovação por WORK 0,20 | [edge-red.log](evidence/aether-reactions/edge-red.log) |
| Importação final sem cache | exit 0, sem `ERROR`/`WARNING` | [candidate-clone.log](evidence/aether-reactions/candidate-clone.log), [candidate-import.log](evidence/aether-reactions/candidate-import.log) |
| Reações no candidato final | **89 / 0**, 17/17 funções, exit 0, **1,724 s** | [candidate-reactions.log](evidence/aether-reactions/candidate-reactions.log) |
| Contrato de hash/journal final | **128 / 0**, 7/7 funções, exit 0, **5,733 s**; Float32 completo: 196.608 bytes | [candidate-contract.log](evidence/aether-reactions/candidate-contract.log) |
| Smoke OFF | **220 / 0**, exit 0, **34,9 s**; geração 989,665 ms, malha 4508,381 ms; pior passo **6,877 ms**; journal inativo, zero registros | [candidate-off.log](evidence/aether-reactions/candidate-off.log) |
| Smoke ON até o load | **220 / 0**, exit 0, **35,0 s**; geração 998,846 ms, malha 4436,554 ms; pior passo **7,787 ms**; 205 registros, hash/escrita/flush: total **143.408 µs**, pico **1.138 µs** | [candidate-on.log](evidence/aether-reactions/candidate-on.log) |
| Leitura independente do JSONL | 205 pares válidos, ticks **1..205**, **14.857 bytes**, newline final; último hash igual ao diagnóstico, inativo com a simulação no tick **359** | [smoke-on.jsonl](evidence/aether-reactions/smoke-on.jsonl), [readback.log](evidence/aether-reactions/readback.log) |

Os smokes finais conservaram **359 ticks / 0 perdidos / 64 chunks / 14 edições /
149 meshes / 214.480 triângulos / 4 lobos vivos**. Censo de nado, golpe, memória A/B/C/D,
HUD e save/load completo nos dois logs. Nenhum `ERROR`/`WARNING` nos cinco logs finais de
importação/teste. CLI avulsa e recusa de arquivo existente foram exercitadas no bloco
histórico de hash abaixo; não foram repetidas como corrida avulsa neste candidato.

**Identidade dos braços.** O runner inicial de 46 checagens foi ampliado; seu snapshot
exato não foi preservado, portanto os dois primeiros logs são histórico exploratório,
não receita byte a byte. Para as quatro falhas finais foram preservados o
[lobo vermelho](evidence/aether-reactions/edge-red-wolf.gd.txt) e o
[runner vermelho](evidence/aether-reactions/edge-red-test.gd.txt). Em cópia descartável do
candidato final, substituí-los nos respectivos caminhos de `src/` e `tests/` recompõe
o braço vermelho; o `.txt` impede registrar outra classe no projeto normal. O runner
final só difere desse runner vermelho por comentários encurtados. A produção final
acrescenta a guarda de presa viva, cancela inspeção durante `stagger` e reduz a renovação
ponderada de 0,08 para 0,06. Os arquivos da evidência têm
[manifesto próprio](evidence/aether-reactions/artifacts.sha256).

**O que foi observado no ciclo, não só no contador:**

- WORK 0,42 e BLOOD 0,42 levaram o corpo a **1,154 m** do local em 108 ticks; a inspeção
  parou o corpo (deriva **0,0000 m** na janela medida), gerou episódio no tick 147 com
  **ator 0** e não inventou avistamento. WORK renovado completou segunda visita; load
  limpou o cache/timer transitórios.
- Com WORK **4,0** e difusão real por 12 s: **48 passadas** de 0,25 s, 21 durante a
  aproximação e 8 durante a inspeção. Energia **4,000000 → 2,021455**, 19 células ativas,
  episódio concluído após deslocamento de **7,3442 m**. Não generaliza para imprint fraco.
- Cache com campo estático: nenhuma reinspeção nos primeiros 29 s; expiração e reabertura
  aos **30,050 s**, seguida de segundo episódio. Congelar apenas a física depois da
  primeira visita isolou expiração de afastamento; a decisão continuou rodando.
- Mover o jogador oculto entre os braços norte/sul não alterou vetor nem deslocamento da
  fuga por campo ou por último golpe. Fuga só por campo manteve energia FEAR em **4,4**,
  sem gerar medo novo. Parede real bloqueou caça sem avistamento; perda de visão usou a
  posição observada, não a posição atual oculta. Aos 120 ticks de idade o avistamento
  ainda vale; depois, **41 amostras** não caçaram nem perseguiram ocultamente.
- Presa morta durante a histerese ainda deixou `intent=hunt`, mas a ação executada foi
  patrulha. No golpe durante o último passo de inspeção, a identidade **2**, criada por
  `Wolf.setup`, mantinha investigação no braço vermelho e gravava um episódio durante o
  empurrão; no verde, **0 episódios**, timer zerado e reação `atordoado`. Isso testa o
  cancelamento, não toda a recuperação após o golpe.
- WORK **0,20**, amplitude de uma colocação, acrescentou **0,07 ponderado**: antes não
  reabria o local; agora iniciou nova inspeção até o tick 46 e completou segunda visita
  até o 91. O dedicado aplica o imprint, não simula o clique de construção.

**Custo observado, sem alegação de otimização:** em **1.907 passos** do runner final,
`sim_step` integral somou **233.484 µs**, pico **581 µs**; a árvore somou **10.620 µs**,
pico **39 µs**, **0 estouros**. São cenários com um lobo, não cinco simultâneos;
`sim_step` não inclui a física subsequente e o guard não inclui percepção/utilidade.
O histórico de 46 checks executou quantidades diferentes de passos, logo seus tempos não
formam A/B de performance. OFF/ON também não são replay pareado: RNG e estado vivo variam.
Nenhuma medição de alocação, aprovação visual ou fechamento de gate P1 é alegado.

Receita final executada no candidato isolado, com arquivo de journal novo:

```sh
godot --headless --path . --import
godot --headless --path . --script tests/aether_reactions_test.gd
godot --headless --path . --script tests/tick_journal_test.gd
godot --headless --path . tests/smoke_test.tscn
godot --headless --path . tests/smoke_test.tscn -- --tick-journal=res://aether-final-smoke.jsonl
```

### Hash e journal — publicado em a8967e0

Base Git `1db00cf0cdcbfbdac88dc980127c1720b4b6e4ef` + alterações locais, copiadas sobre
um clone sem `.godot/` e importadas antes dos testes. Os 67 arquivos de código, cenas,
UIDs, ícone e configuração conferiam byte a byte com a árvore de trabalho ao encerrar
o bloco de hash, antes do refinamento dos rastros, no [manifesto SHA-256](evidence/tick-journal/sources.sha256); SHA-256 do manifesto:
`f38ba83ebbc1650c7a6141d6a6801478e89864c45af3affd0a82435195ba9603`.
As [assinaturas dos artefatos](evidence/tick-journal/artifacts.sha256) cobrem os outros 15
arquivos da pasta, manifesto incluído, e foram conferidas depois de o bloco entrar no
repositório: `sha256sum -c` devolve 15/15 OK.
O commit publicado é `a8967e0`: dentro do clone limpo dele estas 15 assinaturas conferem e a
suíte completa re-medida (232 / 0 / 33,7 s) está na tabela do porte. O que **não** se re-rodou
no clone foi o contrato dedicado de 128 checagens nem os smokes com `--tick-journal`, e o pin de
67 fontes é histórico (nota dos pins, acima). Docs podem mudar sem alterar esse conjunto.

O [override de isolamento](evidence/tick-journal/isolation.cfg) foi copiado somente para
`override.cfg` do candidato: muda o diretório `user://`, não gameplay. O teste de contrato
imprime esse diretório. Assim, os dois smokes do candidato escrevem o slot `alpha` de
teste, não o save normal. Baseline e primeira corrida local anteriores ao isolamento
usaram o diretório normal; o smoke existente não preserva o slot (débito abaixo).
Motor em todos os logs: Godot 4.7.2-stable `ed1daf0bf`, headless. Candidato OFF e ON
executados em série, depois do término dos agentes e sem outro Godot em execução.

| Corrida | Resultado observado | Evidência preservada |
|---|---|---|
| Baseline antes da alteração (`1db00cf`) | 220 checagens / 0 falhas / 35,6 s; pior passo 8,035 ms; 0 ticks perdidos | [baseline.log](evidence/tick-journal/baseline.log) |
| Importação sem cache do candidato | exit 0; nenhum `ERROR`/`WARNING` | [candidate-import.log](evidence/tick-journal/candidate-import.log) |
| Contrato na árvore / no candidato | 128 checagens / 0 falhas, 7/7 funções concluídas, exit 0; 5,882 / 5,807 s; 196.608 bytes de Éter conferidos | [contract1.log](evidence/tick-journal/contract1.log), [candidate-contract.log](evidence/tick-journal/candidate-contract.log) |
| Smoke candidato OFF | 220 / 0, exit 0, 35,4 s; geração 951,723 ms, malha 4709,853 ms; pior passo 10,574 ms; journal inativo e 0 registros | [candidate-off.log](evidence/tick-journal/candidate-off.log) |
| Smoke candidato ON até o load | 220 / 0, exit 0, 35,2 s; geração 941,571 ms, malha 4518,204 ms; pior passo 9,738 ms; 205 registros, 160.000 µs totais, 1.646 µs de pico de hash/escrita/flush | [candidate-on.log](evidence/tick-journal/candidate-on.log) |
| Encerramento no load e leitura independente | 205 linhas, ticks 1..205, 14.857 bytes; último hash igual ao diagnóstico; journal inativo com simulação já no tick 359 | [smoke-on.jsonl](evidence/tick-journal/smoke-on.jsonl), [readback.log](evidence/tick-journal/readback.log) |
| CLI do README: `--fixed-fps 60 --quit-after 300` | exit 0; 100 linhas, ticks 1..100, 7.192 bytes; arquivo com newline final e pares válidos | [candidate-cli.log](evidence/tick-journal/candidate-cli.log), [cli.jsonl](evidence/tick-journal/cli.jsonl) |
| Repetir CLI com o mesmo arquivo | exit **1**, erro esperado `Already exists`; SHA-256 e bytes anteriores preservados | [candidate-refusal.log](evidence/tick-journal/candidate-refusal.log), [readback.log](evidence/tick-journal/readback.log) |

Os dois smokes do candidato fecharam em 359 ticks, zero perdidos, 64 chunks, 14 edições,
149 meshes, 214.480 triângulos e 4 lobos vivos. Não houve `ERROR`/`WARNING` nos testes;
o único erro da CLI foi a recusa deliberada. A primeira corrida local OFF (220 / 0,
38,5 s) também foi [preservada](evidence/tick-journal/smoke-off.log), mas não fundamenta
comparação de custo: pode ter coincidido com o check-only do agente.

**Não é otimização nem comparação pareada de estados:** o pior passo ON menor que OFF
não significa que gravar acelera o jogo; RNG e cadências ainda variam. A medida direta é
a do journal (160.000 µs / 205 registros, média derivada de 780,49 µs). O pico de
1,646 ms é observação desta corrida, não teto garantido. Não foi medido custo total de
alocação. O teste dedicado cobre hash/append/saída de cena; load foi exercitado pelo
smoke ON e conferido por leitura do JSONL, não pelas 128 checagens do dedicado.

Receita executada no candidato, com o override acima e um arquivo novo por corrida:

```sh
godot --headless --path . --import
godot --headless --path . --script tests/tick_journal_test.gd
godot --headless --path . tests/smoke_test.tscn
godot --headless --path . tests/smoke_test.tscn -- --tick-journal=res://smoke-on.jsonl
godot --headless --path . --fixed-fps 60 --quit-after 300 -- --tick-journal=user://tick-run.jsonl
```

### Histórico anterior ao hash/journal

| Número | Valor medido | De onde |
|---|---|---|
| Suíte headless histórica (`9c6b722`, premissa montada) | **220 checagens, 0 falhas**, 35,6 / 35,9 / 36,3 / 36,4 s em **quatro** corridas, exit 0, zero `ERROR` | `.tools/suite_fix1.log` … `suite_fix4.log` |
| Mira do passo de golpe (`9c6b722`) | `alvo=true na_lista=true d_alvo=2.98 rival_mais_proximo=8.02 m`, nas quatro | os quatro logs, linha `mira travada` |
| Árvore sem a premissa montada (três corridas) | 219 checagens, 0 falhas, 35,4 s | `.tools/suite_flake1.log` … `suite_flake3.log` |
| Tick (idêntico nas quatro novas) | 359 ticks, **0 perdidos**, 64 chunks, 14 edições, 149 meshes, 214.480 triângulos, 4 vivos | `suite_fix1.log` … `suite_fix4.log`, diagnóstico final |
| Boot do mundo (nas quatro novas) | geração 936,0 / 944,5 / 952,3 / 961,9 ms · malha 4640,6 / 4847,6 / 4885,8 / 4724,2 ms · pior passo 7,68 / 8,66 / 9,01 / 11,21 ms | os quatro logs |
| Estado vivo (mesma seed, mesma árvore) | `hp` final **0,0 / 0,0 / 0,0 / 6,5** · Éter final 9,94 / 9,58 / 9,73 / 7,27 — nas quatro a matilha machuca o jogador parado, e em três o mata | os quatro logs |
| Estado vivo (árvore antiga, três corridas) | `hp` do jogador **40,5 / 15,0 / 100,0** · Éter final **5,78 / 7,23 / 3,16** · geração 929,7 / 967,7 / 932,9 ms · malha 4684,0 / 4661,6 / 4675,9 ms · pior passo 7,607 / 7,55 / 7,997 ms | `suite_flake1.log` … `suite_flake3.log` |
| Corridas anteriores da árvore sem o seletor | 35,5 s · 35,7 s · Éter final 11,484 e 11,371 | `.tools/suite_final4.log`, `.tools/suite_status1.log` |
| Clone limpo de `88d1c19` (código antigo), corrida 1 / corrida 2 | **4 falhas** (golpe) / 219 checagens, 0 falhas, 35,4 s | `.tools/af-clean-suite.log`, `.tools/af-clean-suite2.log` (receita abaixo) |
| **Clone limpo histórico de `9c6b722`**, recém-importado com o `--import` | **220 checagens, 0 falhas, 35,4 s**, exit 0, zero `ERROR` · `d_alvo=2.98 rival_mais_proximo=8.02 m` · geração 941,1 ms · malha 4.667,6 ms · pior passo 7,561 ms · Éter 9,780 | `.tools/pub-import.log`, `.tools/pub-suite.log` |
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
o motivo de ter construído o item 1. O hash mínimo permite comparar sua projeção, mas o
cenário completo dos lobos ainda exige estado inicial/RNG/cadências controlados no item 2;
esses logs históricos continuam sendo provas de invariantes, não de replay.

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

Os números históricos da suíte e da galeria valem para as revisões indicadas, não para
alterações posteriores. A árvore de trabalho requer nova execução; a publicação de uma
contagem por commit requer clone limpo recém-importado e SHA explícito.

## Rodada de branches (2026-11-19)

O trabalho desta rodada entrou por branch, duas vezes, cada uma com um assunto:
`docs/dossies-de-leitura` (os oito dossiês de [`docs/planos/`](planos/README.md) e as pontas nos
índices deste status e de `docs/design/`) e `docs/fluxo-de-branches` (a regra nova de
[`AGENTS.md`](../AGENTS.md), "Branches: um ajuste por linha de história"). Os dois merges são
`--no-ff` na `main`, então `git log --first-parent main` lista os assuntos sem abrir diff — é isso
que a regra compra, e é por isso que a branch remota fica.

Nenhuma das duas branches toca `src/` ou `tests/`: `git diff --name-only main...HEAD` devolve zero
arquivos de código em ambas, e por isso a contagem da suíte não muda de revisão para revisão. A
execução na `main` mergida (`2fdbb1b`) fecha **232 checagens / 0 falhas**, exit 0, zero
`SCRIPT ERROR`. O tempo dessa corrida (41,4 s) **não** entra como número publicado: é árvore de
trabalho, sem clone limpo reimportado, e o par publicado continua sendo o do clone de `a8967e0`
(232 / 0 / 33,7 s). As duas linhas de ruído de saída (`4 ObjectDB instances` e
`2 resources still in use`) já estavam no log do clone (`evidence/third-person-carry/clone-suite.log:308,310`)
— não são desta rodada.

Nenhum gate de fase se fechou aqui, e nenhum item da fila acima mudou de veredito: os dossiês são
leitura que prepara os itens 1 a 8, não execução deles.

## Rodada Éter — o saldo da difusão medido (2026-11-19, publicado em `9f3622b`)

### O que estava em aberto

O dossiê [`docs/planos/03-canais-morte-som-fogo.md`](planos/03-canais-morte-som-fogo.md), §8,
registrava que o log publicado não fechava conta com `HALF_LIFE`: o smoke dava `2,500 → 2,296`
(8,16% em 8 passadas de `diffuse_and_decay(0.25)`) contra `2,471` que a meia-vida do canal FEAR
prevê, e os `0,175` restantes não tinham causa medida — o único zeramento do código é o corte de
`MIN_VALUE` ([aether_field.gd:146-153](../src/world/aether_field.gd#L146-L153)). Déficit sem dono
é o que o mandato 1 proíbe de publicar. O bloco começou pela colheita, não pelo corte.

### O que entrou

`pass_cut` é um `PackedFloat32Array` por canal ([aether_field.gd:36](../src/world/aether_field.gd#L36)),
dimensionado em `setup()` ([:51-52](../src/world/aether_field.gd#L51-L52)), zerado no topo de cada
passada e escrito com a massa cortada no fim da varredura
([:145-153](../src/world/aether_field.gd#L145-L153)); a docstring nomeia as duas saídas
([:115-116](../src/world/aether_field.gd#L115-L116)). Quatro checagens novas na suíte
([smoke_test.gd:2250-2253](../tests/smoke_test.gd#L2250-L2253), :810-813, :820-823; o `teto de
valor aplicado` de :704-706, que já existia, fica fora): `nenhuma passada cria massa`, `saldo
fecha com o corte de MIN_VALUE`, `o corte da fronteira explica a perda alem da meia-vida`, `teto
nao injeta o excedente no campo`. A previsão é em cadeia, passada a passada, sem releitura
([:2251-2264](../tests/smoke_test.gd#L2251-L2264)): o que sai no corte não decai mais, então o saldo
é `m·keep^8 − Σ cut_k·keep^(7−k)` — o termo que faltava na conta; a diferença sai impressa.

### O que foi medido

| Corrida | Censo | Última linha | Log |
| --- | --- | --- | --- |
| clone limpo do `main` publicado (`9f3622b`, do próprio `origin`) | 236 | **236 / 0 falhas / 37,1 s**, exit 0, zero `SCRIPT ERROR` | [clone-suite.log](evidence/ether-massa-conservada/clone-suite.log) |
| `--import` obrigatório antes de qualquer corrida no clone | — | 299 linhas, zero `ERROR`/`WARNING` | [clone-import.log](evidence/ether-massa-conservada/clone-import.log) |
| runner estreito no mesmo clone | 89 | **89 / 0 / 1,734 s**, censo `17/17` testes | [clone-reactions.log](evidence/ether-massa-conservada/clone-reactions.log) |
| ponta da branch (`98f1d63` + `28884ff`), árvore de trabalho | 236 | **236 / 0 / 42,2 s**, exit 0 | [worktree-branch-suite.log](evidence/ether-massa-conservada/worktree-branch-suite.log) |
| `main` depois do merge `--no-ff`, árvore de trabalho | 236 + 89 | **236 / 0 / 42,1 s** + reações **89 / 0 / 1,740 s** | [worktree-main-suite.log](evidence/ether-massa-conservada/worktree-main-suite.log), [worktree-main-reactions.log](evidence/ether-massa-conservada/worktree-main-reactions.log) |

O número publicado é o do clone limpo; os `42.x s` das duas árvores de trabalho ficam aqui como
execução do gate, não como referência. Assinaturas: `sources.sha256` tem as 79 fontes do commit e
foi recalculado na árvore de trabalho — 79/79 bytes idênticos; `artifacts.sha256` cobre os nove
arquivos que a precedem na pasta.

Os números do saldo, idênticos byte a byte nas três corridas de suíte (linhas 68-73 do log do
clone): `pior ganho=0,00000000` em 8 passadas × 3 canais; `pior erro=0,00000046` com
`corte=0,176129`; a cadeia do FEAR `2,500000 → 2,296008`, onde só a meia-vida daria `2,471285`; e
o teto — um `imprint` de `900,0` numa célula eleva o total do canal de `2,296008` para `5,170020`,
ou seja, entrou no campo o que o teto de `4,0` comporta e o excedente ficou fora. Os `0,175` que o
dossiê deixou pendentes são, medidos, `0,176129` de corte, com tolerância de `1e-4` por passada.
Os dois recortes impressos coincidem: a linha do saldo soma os três canais (`corte=0.176129`) e a
linha da cadeia imprime o corte só do FEAR, também `0,176129` — porque neste cenário o ledger fecha
`work=0.00 blood=0.00 fear=5.17` (log `:74`).

O instrumento não moveu nenhum número de mundo: `aether_energy` final é `9,67776005901396` nas
quatro corridas de suíte citadas aqui, incluindo o clone de `a8967e0`
([third-person-carry/clone-suite.log:305](evidence/third-person-carry/clone-suite.log)), e o
`2,296` de agora é o mesmo `2,296` daquela linha 68. `state_bytes()` serializa `_cur`
([aether_field.gd:233-234](../src/world/aether_field.gd#L233-L234)), não `pass_cut`, então
`FORMAT_VERSION` e os hashes publicados continuam comparáveis.

### Furo descoberto: o teto do passo não era teto

O critério do dossiê 06 ([`docs/planos/06-decompor-main-gd.md`:53](planos/06-decompor-main-gd.md))
diz que `worst_sim_ms` fora de 20% do publicado `6,78 ms` é vermelho. Não é operacional assim.
Lendo os logs desta máquina no mesmo dia: antes da colheita a mesma estatística deu `8,436` /
`13,106` / `14,474` ms (rodada do som, 220 checagens) e depois dela `12,929` (clone) / `13,186`
(branch) / `13,898` (`main` mergida). São máximas de corrida de uma distribuição larga, não um
teto: o `6,78` é uma amostra dela, e a amostra de antes da
colheita já chegava a `14,47` ms — o que refuta a leitura de que a varredura nova dobrou o custo.
Nenhuma das seis corridas perdeu tick (`dropped_ticks=0`), e o orçamento continua 50 ms por passo
([sim_clock.gd:5-7](../src/core/sim_clock.gd#L5-L7)). Fica debitado: o critério precisa de uma
banda medida em N execuções da mesma árvore, não de um pico solitário; atribuição por ablação da
varredura de corte não foi rodada porque as amostras antes e depois se sobrepõem.

### O que nada disso fecha

Nenhum gate de fase. O item 4 da fila (canais MORTE/SOM/FOGO) continua com `Channel.COUNT = 3`
([aether_field.gd:9-15](../src/world/aether_field.gd#L9-L15)) — esta rodada fecha o **passo 1** do
dossiê 03 (colheita sem canal novo), que era pré-condição do passo 2 (`FORMAT_VERSION` conferido
com a contagem de canais parametrizada). O item 5 (HOT agregado dos cinco lobos) não foi tocado: o
runner estreito continua um lobo por cenário, com `sim_step total=224134 us`, pico `360 us` e BT
`last_us soma=10295 pico=44 trips=0` na corrida do clone (log `:92`) — colheita, não gate. E o débito antigo
de alocação no caminho quente permanece: `pass_cut` é realocado uma vez em `setup()`, não por
passada, e as demais alocações listadas na "Disciplina de otimização" estão como estavam.

## Rodada Éter — o que limita o cache de inspeções, medido (2026-11-20, publicado em `297685b` pelo merge de `test/cache-rastro-evicao-03`)

### O que estava em aberto

A memória de rastros é publicada por dois números derivados do código — o teto de 32 células por lobo
([wolf.gd:33](../src/entities/wolf.gd#L33)) e o relógio de 30 s
([:32](../src/entities/wolf.gd#L32)) — e nenhuma corrida dizia **qual dos dois limita o jogo**. A
evicção FIFO que corta a célula mais antiga quando a 33ª entra
([:647-648](../src/entities/wolf.gd#L647-L648)) é caminho nunca exercitado, e cobertura de rastros é
promessa do slice: "o cache está limitado a 32" só quer dizer alguma coisa depois de medir se ele
chega lá. O bloco começou pela colheita.

### O que entrou

Décimo oitavo cenário do runner dedicado, `_test_cache_cap`
([aether_reactions_test.gd:885-985](../tests/aether_reactions_test.gd#L885-L985)): seis fontes reais
de WORK na grade de células 11/14/17 × 13/16, 12 m por salto, com amplitudes decrescentes
`0,84 → 0,54` para que a ordem de visita saia da regra de seleção — o máximo de
`BLOOD + 0,35 × WORK` entre as células não cacheadas
([:701-774](../src/entities/wolf.gd#L701-L774)) — e não de uma imposição do teste. O cenário colhe,
com produção intocada: o instante em que cada inspeção **conclui**, a célula inspecionada, o pico do
cache, a idade de cada saída (escrita → remoção), os metros andados por salto e a velocidade do
corpo. Cinco checagens novas, `EXPECTED_CHECKS` de 89 para 94 e censo de cenários `18/18`.

### O que foi medido

| Corrida | Censo | Última linha | Log |
| --- | --- | --- | --- |
| runner dedicado no commit do instrumento | 94 | **94 / 0 falhas / 2,293 s**, `18/18` | [worktree-branch-reactions.log](evidence/ether-cache-limite/worktree-branch-reactions.log) |
| runner dedicado na ponta da branch, com as seis linhas `CHEGADA` | 94 | **94 / 0 / 2,034 s** | [worktree-branch-tip-reactions.log](evidence/ether-cache-limite/worktree-branch-tip-reactions.log) |
| suíte na ponta da branch | 236 | **236 / 0 / 35,4 s**, zero `SCRIPT ERROR`, zero `FALHA` | [worktree-branch-suite.log](evidence/ether-cache-limite/worktree-branch-suite.log) |
| `main` depois do merge `--no-ff` `297685b`, árvore de trabalho | 236 + 94 | **236 / 0 / 34,7 s** + runner **94 / 0 / 2,023 s** | [worktree-main-suite.log](evidence/ether-cache-limite/worktree-main-suite.log), [worktree-main-reactions.log](evidence/ether-cache-limite/worktree-main-reactions.log) |
| clone limpo do `main` publicado (`297685b`, do próprio `origin`) | 236 + 94 | **236 / 0 falhas / 34,3 s** + runner **94 / 0 / 2,056 s**, censo `18/18`, exit 0, zero `SCRIPT ERROR` | [clone-suite.log](evidence/ether-cache-limite/clone-suite.log), [clone-reactions.log](evidence/ether-cache-limite/clone-reactions.log) |
| `--import` obrigatório antes de qualquer corrida no clone | — | 299 linhas, zero `ERROR`/`WARNING` | [clone-import.log](evidence/ether-cache-limite/clone-import.log) |

O número publicado é o do clone limpo; as corridas de árvore de trabalho ficam aqui como execução
do gate, não como referência. Assinaturas: `sources.sha256` tem as 79 fontes do commit e foi
recalculado na árvore de trabalho em `297685b` — 79/79 linhas idênticas, diff vazio;
`artifacts.sha256` cobre os onze arquivos que o precedem na pasta, e `readback.log` pinha o SHA do
manifesto (`41a2362…`) com os números de cada log. As cinco linhas do cenário do cache são byte a
byte idênticas entre o clone e a ponta da branch, incluindo as seis `CHEGADA` com os mesmos ticks e
as mesmas células.

O que decide a pergunta, impresso nos logs acima: `pico=27 teto=32 vistas=36`; as 36 saídas colhidas
com idade `30,250 s` (a mais jovem e a mais velha — todas pelo relógio, nenhuma por evicção,
`saida_mais_jovem=30.250 mais_velha=30.250 ttl=30.0`); `intervalo=12.540 janela=30.000 blocos=3
preencheria=27`; `pico=27 previsto=27`; `salto=12.0 metros_por_salto=24.8 progressao=0.957
m/s=1.914`.

**Veredito: a evicção não roda no jogo de hoje.** Com 12,54 s entre inspeções a janela de 30 s
comporta três blocos 3×3; o quarto só entraria com intervalo ≤ 10 s, e é o quarto que ultrapassa o
teto (`9 × 4 = 36 > 32`). O `previsto` é o modelo lido do próprio código — um bloco por inspeção
concluída, cada um vivo por 30 s — e ele fecha com o `pico` medido célula por célula. A checagem
`evicao nao roda` é o tripé: se o intervalo cair abaixo de 10 s ela vai a vermelho, e é aí, não
antes, que o braço da evicção (ordem FIFO e reabertura depois da remoção) passa a ter código a
testar.

**Este veredito vale para a revisão `297685b`, e o tripé já disparou.** Na árvore do conserto do
passo o mesmo cenário dá `intervalo=6.810`, `blocos=5`, `pedido=45` e `pico=32` com 22 saídas por
evicção: o limitante passou a ser o teto, não o relógio. Os números estão na rodada do passo, ao
fim deste documento; a linha de `94` aqui em cima é histórico daquela corrida, não o estado atual.

### Propriedade medida: a expirada mais forte passa na frente da nunca visitada

As seis linhas `CHEGADA` do log da ponta dão as células `(11,12,13)`, `(14,12,13)`, `(17,12,13)`,
`(17,12,16)`, `(11,12,13)`, `(14,12,13)` — **quatro** células distintas em seis inspeções. As
chegadas 5 e 6 voltaram às fontes 1 e 2, já vencidas pelo relógio, em vez de caminhar até as fontes
5 e 6, que o lobo nunca inspecionou: é a regra de seleção funcionando como está escrita, célula
expirada volta a ser elegível e a mais forte entre elas (`0,84` ponderado em `0,294`) ganha da nunca
vista (`0,60` em `0,21`). Daí os `vistas=36` em lugar de 54 — dezoito escritas renovaram célula já
cacheada. **Não se registra como defeito sem corrida que o refute**: com fontes estáticas o leitor
cicla nas duas mais fortes; no jogo o WORK nasce, decai (meia-vida de 90 s) e se move, e essa ordem
não foi medida aqui. Fica como pergunta para a fila do refinamento de rastros.

### Furo descoberto: o contato com o chão conta como obstáculo

**Estado hoje: consertado**, na branch `fix/passo-do-lobo-pouso-nao-e-obstaculo` — ver a
[rodada do passo](#rodada-éter--o-passo-do-lobo-em-plano-livre-medido-2026-11-20-branch-fixpasso-do-lobo-pouso-nao-e-obstaculo).
O texto abaixo é o descoberto, publicado em `297685b`, com a premissa que ele deixou em aberto.

Mecanismo lido no código: `move_and_collide` resolve os três eixos e o Y desce contra o chão em
todo frame ([voxel_body.gd:54](../src/entities/voxel_body.gd#L54)), e `_collide_axis` marca
`blocked_this_frame` para **qualquer** eixo, inclusive o pouso
([:98](../src/entities/voxel_body.gd#L98)). O passo do lobo tratava o flag como parede
([wolf.gd:715-719](../src/entities/wolf.gd#L715-L719)): re-arma `_unstick` (0,35–0,8 s) e `_detour`
(±0,7–1,3 rad) e ainda salta (`velocity.y = 5,2`) estando no chão. Em plateau plano, sem nenhum
obstáculo entre o corpo e a fonte, o steering roda girado — daí os `24,8` metros andados para
`12,0` metros de ganho (2,07×) e a progressão líquida de `0,957 m/s` contra
`SPEED_WALK = 2,6` ([:20](../src/entities/wolf.gd#L20)).

Atribuição pedida nos dois sentidos (ciclo de trabalho, item 3) e linha de base declarada ali —
`metros_por_salto=24.8 progressao=0.957` — foram medidas na rodada seguinte, com os dois braços
rodados e um segundo furo aparendo no meio do caminho. A conta que importa para os rastros era
derivada do código, não corrida: com o caminho tortuoso de hoje e `2,6 m/s` nominais o intervalo
seria `24,8/2,6 + 2,0 = 11,5 s` — ainda acima dos 10 s; só com o caminho limpo (`12/2,6 + 2,0 =
6,6 s`) o quinto bloco entraria na janela. Ou seja: o que hoje segura o cache abaixo do teto é o
**desvio**, não a velocidade. Isso era hipótese; a rodada do passo mediu `intervalo=6.810` e o
previsão se cumpriu — o quinto bloco entrou e o teto de 32 passou a limitar.

### Nota de ruído: o µs do rodapé é amostra

Quatro corridas do runner com o mesmo conjunto de cenários e `passos=3234`, todas arquivadas
acima, deram `sim_step total=437350 µs, pico=812 µs` (commit do instrumento), `376723 µs, pico=431`
(ponta da branch), `368969 µs, pico=387` (`main` mergida) e `371383 µs, pico=366` (clone limpo) —
18,5% de spread entre o pior e o melhor, com as três últimas na mesma árvore. O rodapé continua
colheita estreita (um lobo por cenário, `trips=0` nas quatro); comparar revisões por esse número
exige mais de uma corrida de cada, exatamente o que a rodada anterior pediu para o `worst_sim_ms`
da suíte — que aqui se repetiu: `9,092` / `9,219` / `9,289` ms, spread de 0,2 ms.

### Re-derivações desta rodada

O rodapé do runner, que a colheita empurrou: `:640-641` → `:736-737` em `AGENTS.md`,
`docs/design/08` e `docs/design/09` (a antiga apontava para o `_check(_ran…)` de
`_finish()`, não para a linha colhida — corrigida pelo conteúdo); `:645` → `:737` e `:648` → `:740`
nos dossiês 03 e 04; `:644-645` → `:736-737` no dossiê 04. Censo nos mesmos três lugares:
`EXPECTED_CHECKS` 89 → 94 e cenários 17 → 18. `README.md` mantém os `89 checagens` da rodada
anterior porque aquela frase responde por um candidato nomeado, não pelo estado atual.

### O que nada disso fecha

Nenhum gate de fase. O teto de 32 células ficou sem instrumento de evicção **nesta** revisão — ele
dependia do `fix/` do passo, que rodou depois e mudou o regime (ver a rodada seguinte: `pico=32`,
`por_evicao=22`). O item 4 da fila (canais MORTE/SOM/FOGO) está intocado, e o item 5 (HOT agregado dos
cinco lobos) também. Aqui `SCENT_MEMORY_CAP` ainda não era o limitante: na medição de `297685b` as 36
saídas deram todas em `30,250 s`, pelo relógio. Com o passo consertado o limitante passou a ser o
teto — o veredito do cenário do cache, escrito ali em cima, vale para aquela árvore, não para a
atual; a rodada do passo mediu o regime novo.

## Rodada Éter — o passo do lobo em plano livre, medido (2026-11-20, branch `fix/passo-do-lobo-pouso-nao-e-obstaculo`)

### O que estava em aberto

A rodada do cache deixou duas coisas pendentes no mesmo parágrafo: uma **conta derivada do código**
(`24,8/2,6 + 2,0 = 11,5 s` com o caminho tortuoso contra `6,6 s` com caminho limpo, e portanto o
quinto bloco fora da janela de 30 s) e um **furo lido no código e nunca reproduzido** — o pouso em
Y contado como obstáculo ([voxel_body.gd:54](../src/entities/voxel_body.gd#L54) →
[:98](../src/entities/voxel_body.gd#L98) → [wolf.gd:1239](../src/entities/wolf.gd#L1239)). Nada
disso era corrida. O ciclo de trabalho (item 3) exige os dois sentidos da atribuição antes do
conserto, e a linha de base estava declarada: `metros_por_salto=24.8 progressao=0.957`.

### O que entrou

Décimo nono e vigésimo cenários do runner dedicado — `_test_locomotion_flat`
([aether_reactions_test.gd:998-1088](../tests/aether_reactions_test.gd#L998-L1088), quatro
checagens) e `_test_locomotion_wall`
([:1059-1154](../tests/aether_reactions_test.gd#L1096-L1191), cinco) — mais os dois consertos que
eles decidem:

- **o flag dividido**: `blocked_horizontal` nasce ao lado de `blocked_this_frame`
  ([voxel_body.gd:21-24](../src/entities/voxel_body.gd#L21-L24)), é marcado só nos eixos de andar
  ([`:99-100`](../src/entities/voxel_body.gd#L99-L100)) e é **esse** que o passo do lobo lê para
  re-armar o desvio ([wolf.gd:1239](../src/entities/wolf.gd#L1239));
- **a caixa testada volta a ser a caixa aplicada**: o `box.size.x -= WALL_SHAVE` saiu de
  `_translated` ([voxel_body.gd:118-129](../src/entities/voxel_body.gd#L118-L129)), com o porquê
  e o número measured na linha de cima ([`:108-117`](../src/entities/voxel_body.gd#L108-L117)). O
  shave de Y continua ([`:126`](../src/entities/voxel_body.gd#L126)) porque ali ele é o lado
  conservador.

`EXPECTED_CHECKS` de 94 para 103 ([`tests/aether_reactions_test.gd:64`](../tests/aether_reactions_test.gd#L64)),
censo de cenários `20/20`.

### O que foi medido

| Corrida | Censo | Última linha | Log |
| --- | --- | --- | --- |
| braço A — só o cenário, árvore do `eced18e` (sem conserto) | 97 | **97 / 0 / 2,118 s**, colheita `rearms=19 lancamentos=19` | [instrumento-reactions.log](evidence/passo-lobo-plano/instrumento-reactions.log) |
| braço A — premissa reproduzida com o conserto de (a) **ausente** | 103 | **103 / 1 falha / 2,165 s**, `horizontais=0` | [braco-pouso-reactions.log](evidence/passo-lobo-plano/braco-pouso-reactions.log) |
| braço B — (a) consertado, rasante de X ainda aplicado | 103 | **103 / 1 falha / 1,941 s**, `encaixados=389` | [braco-encaixe-reactions.log](evidence/passo-lobo-plano/braco-encaixe-reactions.log) |
| suíte inteira no mesmo braço B, três vezes seguidas | 236 | **236 / 1 falha / 34,7–35,1 s**, sempre `encaixados=1` na **mesma** coordenada | [suite-vermelho-1.log](evidence/passo-lobo-plano/suite-vermelho-1.log), [suite-vermelho-2.log](evidence/passo-lobo-plano/suite-vermelho-2.log), [suite-vermelho-3.log](evidence/passo-lobo-plano/suite-vermelho-3.log) |
| árvore final na branch (os dois consertos) | 103 + 236 | runner **103 / 0 / 1,901 s** (censo `20/20`), suíte **236 / 0 / 34,7 s**, exit 0, zero `SCRIPT ERROR` | [branch-runner.log](evidence/passo-lobo-plano/branch-runner.log), [branch-suite.log](evidence/passo-lobo-plano/branch-suite.log) |
| `main` depois do merge `--no-ff` (`520c3b4`) | 103 + 236 | runner **103 / 0 / 1,920 s** (`20/20`), suíte **236 / 0 / 34,9 s**, exit 0, zero `SCRIPT ERROR` | [main-runner.log](evidence/passo-lobo-plano/main-runner.log), [main-suite.log](evidence/passo-lobo-plano/main-suite.log) |
| clone limpo de `520c3b4`, recém-importado | 103 + 236 | runner **103 / 0 / 1,912 s**, suíte **236 / 0 / 34,0 s**, exit 0 nas duas | [clone.log](evidence/passo-lobo-plano/clone.log), [clone-import.log](evidence/passo-lobo-plano/clone-import.log), [clone-reactions.log](evidence/passo-lobo-plano/clone-reactions.log), [clone-suite.log](evidence/passo-lobo-plano/clone-suite.log), [readback.log](evidence/passo-lobo-plano/readback.log) |

Rodapé da árvore final: `passos=2766 sim_step total=319714 µs pico=354 µs; BT last_us soma=14443
pico=49 trips=0` ([`tests/aether_reactions_test.gd:1183-1184`](../tests/aether_reactions_test.gd#L1183-L1184)).
Diagnóstico da suíte: `worst_sim_ms=8,646`, `dropped_ticks=0`, `tick=359`, 4 lobos vivos no fim.

O rodapé foi colhido quatro vezes na mesma mecânica (commit do conserto, ponta da branch, `main`
mergida e clone limpo — três árvores que diferem só em documentação): `total` em 317 747 / 319 714 /
322 419 / 317 556 µs, `pico` em 442 / 354 / 400 / 463 µs, `trips=0` nas quatro. O `worst_sim_ms` da
suíte deu 11,692 / 8,646 / 11,107 / 9,237 ms. O que **não** variou foi o estado:
`aether_energy=9.36133219487965`, `lobo0 reach=7.83 m`, `passos=2766`, `tick=359`, `edits=13`,
`meshes=147`, `dropped_ticks=0` idênticos nas quatro corridas, e as 111 linhas de resultado do runner
do clone são byte idênticas às da árvore de trabalho. É a nota de ruído da rodada anterior valendo de
novo, agora com quatro amostras: o µs do rodapé é amostra, não assinatura; o número de estado é.

### Sentido 1 da atribuição: o estado é frequente e a assinatura é exata

No plateu 45×45 verificado sem nenhum sólido acima do piso, com a presa a 23,5 m e visada limpa,
a colheita diz `apoiados=184 bloqueados=166 pouso_bloqueado=166 frames=627` — **100% dos bloqueios
chamados são o pouso**, e `horizontais=0`: nenhum eixo de andar esbarrou em nada no caminho. O
corpo ainda assim re-armou o desvio 19 vezes e foi lançado a 5,2 m/s 19 vezes, e andou `44,8 m`
para ganhar `24,4` (`razao=1.833`), andamento `2,336 m/s` contra `SPEED_WALK = 2,6` nominais, em
`10,4 s`. Com a linha lida trocada para `blocked_horizontal`, a mesma colheita dá
`apoiados=300 bloqueados=300 pouso_bloqueado=300 lancamentos=0 rearms=0` e
`percorrido=23.5 ganho=23.5 razao=1.000` em `5,0 s` — `andamento=4.707 m/s`. Os `300` frames são
menos que os `627` porque o corpo chega: a colheita encerra no alcance, não no teto de ticks.

### Sentido 2: o conserto é indiferente ao obstáculo de verdade

Com a mesma parede do cenário de avistamento (x=63, seis blocos, `los=false` porque a visada morre
no sólido) e um rastro de WORK atrás dela, o integrador ainda chama bloqueio horizontal
(`horizontais=340`), o desvio ainda re-arma (`rearms=12`) e o corpo ainda salta (`lancamentos=11`),
e para do lado de cá: `x_max=62.625` contra `teto_bloqueio=63.0`. O que mudou foi o que o contato
**não** era: `encaixados=0 encaixe_max=0.000 mm face_x=62.9995` em 600 frames.

### Furo descoberto nesta corrida: o rasante de 1 mm virava encaixe

Esse só apareceu **depois** do conserto de (a) — enquanto o corpo saltava ao encostar, ele nunca
ficava o tempo bastante pressionado contra a face para o defeito se ver. Com (a) consertado e o
shave de X no lugar, a mesma parede produz `encaixados=389` de 600 frames com
`encaixe_max=1.000 mm` e `face_x=63.0009`: exatamente o `WALL_SHAVE`
([`voxel_body.gd:9`](../src/entities/voxel_body.gd#L9)), não um acidente do relevo. Na suíte
inteira a checagem antiga ("nenhum lobo com o corpo dentro do terreno",
[`tests/smoke_test.gd:331`](../tests/smoke_test.gd#L331)) passou a cair em
`encaixados=1 lobo1 em (56.62563, 36.39333, 23.29462)` — **três corridas, a mesma coordenada**, o
que a torna premissa de teste e não maré. E o resgate não alcança: `escape_embedded()`
([`voxel_body.gd:65-76`](../src/entities/voxel_body.gd#L65-L76)) só varre para cima, com
`ESCAPE_LIFT = 2,5`, numa parede de rocha de 6 blocos — a sonda mediu lift necessário nenhum
(`pra cima=-1, pra baixo=-1` nos 4 m varridos). Corpo congelado dentro do sólido, que é a
assinatura que o próprio comentário de `escape_embedded` descreve.

O conserto não relaxa o teste nem aperta o corpo: a caixa testada passa a ser a caixa aplicada. O
contato rente já era tolerado pelo epsilon de `aabb_hits_solid`
([`voxel_world.gd:414`](../src/world/voxel_world.gd#L414)), que trata face em cima da divisória
como livre — foi medido `face_x=62.9995`, encostado e não encaixado.

### O que isso muda nos rastros

A conta que a rodada do cache deixou como hipótese se cumpriu: `intervalo=12.540` → `6.810 s` com
o caminho limpo, `metros_por_salto=24.8` → `12.3`, `progressao=0.957` → `1.762 m/s`. As seis
inspeções concluíram nos ticks 40/165/300/426/551/721 (células (11,12,13) → (14,12,13) →
(17,12,13) → (17,12,16) → (14,12,16) → (11,12,13)), e o cache encostou no teto no quarto bloco:
`pico=32 teto=32 vistas=45`, `por_relogio=0 por_evicao=22`, com as saídas por evicção idades
`19,500 s` (a mais jovem) e `28,000 s` (a mais velha). **`SCENT_MEMORY_CAP` é, desde aqui, o
limitante publicado** — a pergunta que a rodada anterior disse não poder ser feita foi respondida
pelos dois números.

### O que o passo consertado mudou dentro da suíte

A suíte lê lobos vivos, então um conserto de passo mexe nos números dela por consequência, não por
regressão. Na mesma semente, comparando a árvore `297685b` (rodada do cache) com esta:
`lobo0 reach` cai de `8,85 m` para `7,83 m` em 200 passos, `morte imprinta sangue e medo` dá
`fear` `4,21` → `4,23` (`blood` `4,16` igual), `save com corpo` passa de `11 902` para `12 237`
bytes e `aether_energy_final` de `9,67776005901396` para `9,36133219487965`. O que não se moveu é o
que a suíte cobra: os 236 nomes de checagem, `tick=359`, `edits=13`, `meshes=147`,
`triangles=214480`, 4 lobos vivos, `dropped_ticks=0`. Os quatro valores novos estão pinados como
estado desta árvore (quatro corridas, mesmo valor em todas).

### Duas observações do clone limpo, ambas registradas sem atribuição

**O `--import` frio deu 139 uma vez.** No clone recém-clonado de `520c3b4`, a primeira
`--headless --path . --import` terminou com *segmentation fault* (exit 139) depois de
`[ DONE ] loading_editor_layout`. As duas repetições frias no mesmo clone, e as três tentativas frias
num clone de `297685b`, deram exit 0 — e os **quatro logs são byte idênticos**, 299 linhas, zero
linhas de erro. O cache ficou completo de qualquer jeito: `sha256sum -c` nos 79 arquivos do manifesto
dá 79/79 OK, 154 assets importados, as classes `VoxelWorld`/`AetherField`/`Wolf`/`SimClock`/
`VoxelBody` resolvidas, e as duas gateiras rodaram **neste mesmo clone** e saem exit 0. Não se
atribui: uma amostra vermelha em três não separa "o conserto do passo trouxe o crash" de "o crash é
intermitente de sempre e as rodadas anteriores não gravavam o exit do `--import`" — e de fato nenhum
`readback.log` anterior grava. O que fecha isso é N tentativas frias de cada árvore com o exit
anotado, ou a pilha do engine.

**O ruído de quit dobrou.** Onde o stderr foi capturado (`2>&1`), a dupla de linhas de saída dá
`8 ObjectDB instances leaked` + `4 resources still in use` nas quatro corridas desta árvore (conserto,
ponta da branch, `main` mergida, clone limpo) e deu `4/2` nas três da árvore `297685b`. A rodada do
som (`docs/evidence/audio/smoke.log`, 220 checagens) também dava `8/4`, então o valor não é novidade
nem é fixo de árvore: ele oscila conforme como a simulação termina. `instrumento-suite.log` e
`branch-suite.log` desta rodada não têm a linha porque foram capturados só em stdout — presença é
efeito do comando, contagem é do processo. Nenhuma checagem depende desse número e o exit segue 0; a
dívida do quit já estava debitada na rodada do som, e aqui ela ganha mais um par de números.

### Re-derivações desta rodada

O runner ganhou 202 linhas (741 → 943) e o censo mudou de lugar: `_arm` `:91` → `:92` (e o `seed(SEED)` citado
no §RNG, `:94` → `:95`), as variáveis de colheita `:31` → `:32`, `_advance` `:104-121` → `:105-121`,
`TESTS` `:7-14` → `:7-15` (18 → 20 cenários), `EXPECTED_CHECKS` `:15` → `:16` (94 → 103), o rodapé
colhido `:736-737` → `:938-939` e a linha de contrato `:740` → `:942`. Corrigidos pelo conteúdo em
`AGENTS.md:82-83`, `docs/design/08:78-79`, `docs/design/09:266`, `:268-269`, `:274-275`,
`docs/planos/02:6`, `docs/planos/03:95-96`, `:119`, `:121`, `docs/planos/04:32`, `:54` e
`docs/planos/README.md:15`, `:90`. Os `103` do dossiê 03 §"Como medir" são o número de hoje, não o
do plano original: o item que ele numera (canais MORTE/SOM/FOGO) continua não feito. Pin de revisão
trocado de `9f3622b` para `520c3b4` no README (§"Como rodar a suíte", com o manifesto de 79 arquivos
agora em `docs/evidence/passo-lobo-plano/sources.sha256`) e em `docs/planos/04:32`.

### O que nada disso fecha

Nenhum gate de fase. O item 4 da fila (canais MORTE/SOM/FOGO) e o item 5 (HOT agregado dos cinco
lobos) estão intocados — o rodapé desta corrida é colheita estreita de um lobo por cenário,
`trips=0`. A dívida que a rodada anterior apontou (falta instrumento de evicção para o teto de 32)
foi paga por ela mesma, ali em cima. Fica em aberto a **ordem** de evicção: 22 saídas cortaram a
mais jovem com `19,5 s`, e a pergunta de `:1296-1298` (a mais forte deveria passar na frente?) não
tem corrida. R3, o rastro em duas camadas, foi fechado depois, na seção seguinte: o vermelho
que faltava — o scan de uma camada só perdendo um rastro em caverna — foi reproduzido e o
varredor hoje lê ±1 andar (`cbaaef5`). Do `worst_sim_ms` há agora quatro amostras desta árvore
(`11,692 / 8,646 / 11,107 / 9,237 ms`) e nenhuma banda publicada: as duas checagens que o imprimem
([`tests/smoke_test.gd:345`](../tests/smoke_test.gd#L345) e
[`tests/smoke_test.gd:3465`](../tests/smoke_test.gd#L3465)) cobram `perdidos=0`, não a distribuição do passo. Somam-se
à fila as duas observações do clone limpo lá em cima — o exit do `--import` frio e a contagem de
objetos vazados no quit, ambas precisando de N corridas com o exit anotado para virar coisa que se
possa chamar de defeito. A primeira ganhou uma terceira, uma quarta e uma quinta amostra nas
seções seguintes (exit 0 nas três, com o log do `--import` byte a byte igual entre os três
clones); a segunda ganhou oito, seis delas `8 ObjectDB / 4 resources`, uma `4/2` e uma em que o
processo não imprimiu nenhuma das duas linhas — e elas se movem entre corridas da mesma árvore,
inclusive com o mesmo comando de captura.

## Rodada Éter — o nariz desce e sobe, medido (2026-11-20, publicado em `cbaaef5` pelo merge de `feat/rastro-em-duas-camadas`, ponta `f89041b`)

O código é o de `cbaaef5`; a conta dele, as citações re-derivadas e as assinaturas desta página
entraram depois, pelos merges de `docs/medicao-rastro-duas-camadas` (`3ab08db`), de
`docs/medicao-merge-e-clone-3ab08db` (`ff347d2`) e da perna que mede este último, cada um com suas
duas gateiras corridas na revisão que resultou dele.

### O que estava em aberto

Duas afirmações lidas no código e nunca corridas, ambas no mesmo varredor:

1. **uma camada só.** O scan visitava `7 × 7` células no Y do lobo
   (`a1405e4:src/entities/wolf.gd:540-542`) e o alvo vinha de `surface_height()` da coluna
   (`a1405e4:src/entities/wolf.gd:563-564`). Consequência derivada, não medida: sangue escorrido
   para dentro de uma boca de caverna mora na célula de Éter **abaixo** do teto, e um lobo em
   cima dele lê 0,0000 onde existe 0,4200.
2. **nenhum número para o custo.** O parágrafo de otimização deste repo dizia "49 × 3 leituras"
   e ficava por aí. Abrir mais andares multiplica essa conta, e ninguém sabia quanto.

### O vermelho, nos dois sentidos que o ciclo de trabalho cobra

Cenário novo `_test_scent_cave_layer`
([:1490-1542](../tests/aether_reactions_test.gd#L1527-L1579)) com `_cave_carve()`
([:1150-1487](../tests/aether_reactions_test.gd#L1187-L1524)): piso sólido em `y=44`, ar em
`45..47`, teto em `48..50`. Como a célula do Éter mede 4 blocos, todo o ar da caverna fica na
camada 11 enquanto o lobo, em cima do teto, está na camada 12 — e o rastro impresso a 0,42
está **dentro** do raio horizontal de 3 células.

**Sentido 1 — o estado é frequente e a assinatura é exata.** Braço A = leitor antigo
(`a1405e4:src/entities/wolf.gd`, md5 `0f70274e`) com o cenário novo em cima, corridas de
[vermelho-camada-unica-1.log](evidence/rastro-duas-camadas/vermelho-camada-unica-1.log) e
[2.log](evidence/rastro-duas-camadas/vermelho-camada-unica-2.log), linhas literais:

```
FALHA leitor acha o rastro uma camada abaixo | found=false celula=(15, 12, 15) esperado=(17, 11, 15) forca=0.0000 intent=patrol tick=1 ...
FALHA alvo projetado no piso da caverna, nao no teto da superficie | alvo=(62.0, 50.6, 62.0) surface_height=50
109 checagens 2 falhas 1.919 s        (e 1.921 s na segunda corrida)
```

A premissa é impressa antes do veredito — `camada_do_lobo=0.0000 camada_de_baixo=0.4200` — então
o vermelho não é geometria de palco nem alcance: é a camada. O `alvo=(62.0, 50.6, 62.0)` com
`surface_height=50` é o teto jogado em cima do próprio lobo.

**Sentido 2 — o conserto é indiferente ao estado que não é o defeito.** O controle do mesmo
eixo, mesma coluna e mesma amplitude, 5 m acima (`above_cell.y == wolf_cell.y`), acha o rastro
na camada do lobo e projeta em `y=50,6` **nos dois braços**: as duas linhas acima são o único
delta entre A e F. Nem o caminho de descida nem o escalonamento mudam o que já funcionava.

### O que entrou

- **`SCENT_Y_RADIUS = 1`** ([wolf.gd:28](../src/entities/wolf.gd#L28)) e o laço escalonado
  ([wolf.gd:713-733](../src/entities/wolf.gd#L713-L733)): camada própria primeiro, e as
  vizinhas só abrem quando ela não devolve nada acima de `SCENT_MIN`. FEAR continua lendo só
  na camada do lobo — o empurrão da fuga é horizontal e a suíte já o mede ali. O porquê do
  gate está na linha de cima, não no diff: cada camada vizinha são 98 leituras num scan que
  roda 4×/s.
- **`_scent_ground_y()`** ([wolf.gd:1025-1029](../src/entities/wolf.gd#L1025-L1029)): o chão do
  rastro é a primeira célula sólida descendo do topo da camada encontrada, não o topo da
  coluna.
- Runner: 103 → **109 checagens**, censo `20/20` → **`21/21`**
  ([`EXPECTED_CHECKS`:60](../tests/aether_reactions_test.gd#L64),
  [TESTS:19](../tests/aether_reactions_test.gd#L19)).

### Matriz de ablação: o que é o chão e o que é a varredura

Um processo por config, mesma árvore de trabalho, **mesmo arquivo de teste nas 11 corridas de
braço** (md5 `6179200c`, impresso antes e depois de cada run); só `wolf.gd` muda. Números do
rodapé `CENARIO ESTREITO` (2 768 passos, `sim_step` integral de um lobo por cenário):

| braço | wolf.gd | o que é | `sim_step total` µs | pico µs | contrato |
| --- | --- | --- | --- | --- | --- |
| A | `0f70274e` | camada própria + `surface_height` | 326 189 / 322 128 | 440 / 409 | 109 / **2 falhas** |
| D | `4b2f5110` | camada própria + chão novo | 318 171 | 409 | 109 / **2 falhas** |
| C | `89e07cd5` | três camadas **sem gate** + `surface_height` | 434 052 | 723 | 109 / 1 falha |
| B | `5fcab371` | três camadas sem gate + chão novo | 427 940 / 427 134 | 622 / 693 | 109 / 0 |
| E | com contadores | escalonado + chão novo, colher frequência | 363 038 / 363 089 | 540 / 543 | 109 / 0; `scans=567 varredura-vertical=479` |
| F | `885362e8` = `f89041b` | **publicado** | 364 589 / 364 987 / 361 464 | 619 / 609 / 545 | 109 / 0 |

**D == A dentro do ruído do instrumento e C == B.** O chão do rastro não custa nada mensurável:
o delta inteiro mora na varredura das camadas vizinhas. E o escalonamento pelo nível próprio não
é economia de gosto — é a diferença entre **+32 % e +12 %** sobre a base de uma camada
(324 159 → 427 537 sem gate, → 363 680 com gate, médias dos runs de cada braço).

### A colheita que decide o gate (e a correção do que o commit diz)

Os contadores temporários — dois `static var` no lobo e um `print` no teste, **revertidos antes
do commit**, por isso o hash do teste neles não é `6179200c` — deram o mesmo par nas duas
corridas ([colheita-contadores-1.log](evidence/rastro-duas-camadas/colheita-contadores-1.log),
[2.log](evidence/rastro-duas-camadas/colheita-contadores-2.log)):

```
COLHEITA TEMPORARIA: scans=567 varredura-vertical=479
```

O contador é **por camada percorrida**, não por scan: a primeira vizinha que sobe acima de
`SCENT_MIN` fecha a segunda no mesmo scan, então um scan paga zero, uma ou duas camadas extras.
O máximo seria 567 × 2 = 1 134 entradas; pagou 479 — **46 942 das 111 132 leituras extras**, e
o gate corta as outras 64 190 (~64 ms dos 103 ms). A cena é determinística: os dois runs de
colheita concordam dígito a dígito.

Registrado porque a mensagem de `f89041b` diz duas coisas que estes mesmos logs não sustentam:
"479 **dos 567 scans**" (479 é contagem de camada, contra 1 134 possíveis) e "o gate só alcança
os **16 %** em que há rastro" (a fração lida é 42 % das camadas abertas). O texto do commit está
publicado e não se reescreve; a leitura conferida é a da tabela acima e a do
[readback.log](evidence/rastro-duas-camadas/readback.log), que já traz a correção.

### O que o jogo real custa

Oito árvores, mesma receita, cada uma com as duas gateiras. A suíte larga em 4 lobos neste
`SEED` e o `aether_energy` não se moveu em nenhuma delas — o varredor em camadas troca o custo
do scan, não o estado do mundo:

| Árvore | runner estreito | suíte | `worst_sim_ms` | Log |
| --- | --- | --- | --- | --- |
| ponta da branch (`f89041b`) | 109 / 0 / 1,950 s, `total=361 464 pico=545` | 236 / 0 / 34,8 s | 9,921 | [publicado-3.log](evidence/rastro-duas-camadas/publicado-3.log), [branch-suite.log](evidence/rastro-duas-camadas/branch-suite.log) |
| `main` mergida (`cbaaef5`) | 109 / 0 / 1,941 s, `total=366 192 pico=553` | 236 / 0 / 34,8 s | 10,031 | [main-runner.log](evidence/rastro-duas-camadas/main-runner.log), [main-suite.log](evidence/rastro-duas-camadas/main-suite.log) |
| clone limpo de `cbaaef5`, `--import` frio | 109 / 0 / 1,969 s, `total=367 690 pico=775` | 236 / 0 / 34,3 s | 12,939 | [clone-reactions.log](evidence/rastro-duas-camadas/clone-reactions.log), [clone-suite.log](evidence/rastro-duas-camadas/clone-suite.log) |
| árvore de docs desta rodada, `src/` e `tests/` byte a byte iguais a `cbaaef5` | 109 / 0 / 1,963 s, `total=368 658 pico=666` | 236 / 0 / 35,1 s | 11,426 | [docs-runner.log](evidence/rastro-duas-camadas/docs-runner.log), [docs-suite.log](evidence/rastro-duas-camadas/docs-suite.log) |
| `main` mergida (`3ab08db`), depois do merge da perna de docs | 109 / 0 / 1,959 s, `total=367 176 pico=624` | 236 / 0 / 34,8 s | 10,887 | [merge-main-runner.log](evidence/rastro-duas-camadas/merge-main-runner.log), [merge-main-suite.log](evidence/rastro-duas-camadas/merge-main-suite.log) |
| clone limpo de `3ab08db`, `--import` frio | 109 / 0 / 1,953 s, `total=363 658 pico=610` | 236 / 0 / 34,7 s | 9,655 | [clone-3ab08db-runner.log](evidence/rastro-duas-camadas/clone-3ab08db-runner.log), [clone-3ab08db-suite.log](evidence/rastro-duas-camadas/clone-3ab08db-suite.log), [clone-3ab08db-import.log](evidence/rastro-duas-camadas/clone-3ab08db-import.log) |
| `main` mergida (`ff347d2`), depois do merge da perna que levou a medição do clone | 109 / 0 / 1,967 s, `total=364 657 pico=596` | 236 / 0 / 34,7 s | 9,644 | [merge-ff347d2-runner.log](evidence/rastro-duas-camadas/merge-ff347d2-runner.log), [merge-ff347d2-suite.log](evidence/rastro-duas-camadas/merge-ff347d2-suite.log) |
| clone limpo de `ff347d2`, `--import` frio | 109 / 0 / 2,003 s, `total=375 216 pico=647` | 236 / 0 / 35,1 s | 10,988 | [clone-ff347d2-runner.log](evidence/rastro-duas-camadas/clone-ff347d2-runner.log), [clone-ff347d2-suite.log](evidence/rastro-duas-camadas/clone-ff347d2-suite.log), [clone-ff347d2-import.log](evidence/rastro-duas-camadas/clone-ff347d2-import.log), [clone-ff347d2.log](evidence/rastro-duas-camadas/clone-ff347d2.log) |

As oito dão `tick=359`, `edits=13`, `meshes=147`, `dropped_ticks=0`, `wolves_alive=4` e
`aether_energy=9,36133219487965` — a assinatura de estado é idêntica, o µs é amostra, e a banda
das oito linhas é 361 464 a 375 216 (4 % de ponta a ponta, e nenhum dos lados do `git diff` das
revisões toca `src/`). As quatro últimas linhas existem porque o contrato diz que número publicado é
número medido na revisão, e estas revisões são feitas de markdown: conferido, não afirmado —
`git rev-parse cbaaef5:src 3ab08db:src ff347d2:src` devolve `9a8dbdf…` nos três e `…:tests` devolve
`7bcbde9…` nos três; `git diff --name-only cbaaef5 3ab08db -- src tests project.godot assets tools`
conta **zero** arquivos contra 37 no total, e o mesmo `--name-only 3ab08db ff347d2` com o mesmo
pathset conta **zero** contra 10. Os dois clones dão o mesmo `sha256sum -c sources.sha256`:
**79/79 OK, exit 0** em cada um. Quem quiser conferir uma revisão de docs não roda nada: lê
`git rev-parse <rev>:src <rev>:tests` e vê os dois hashes repetidos.

O [artifacts.sha256](evidence/rastro-duas-camadas/artifacts.sha256) desta página acompanhou: 20
entradas na perna de código, 22 com os dois logs da árvore de docs, 27 com os cinco da perna
anterior e **33** com os seis desta (dois da `main` mergida, três do clone e o log de procedência
dele). Cada regravação foi conferida antes e depois — **20/20**, **22/22**, **27/27** e **33/33 OK,
exit 0** na árvore de trabalho, e **27/27 OK, exit 0 dentro do clone limpo de `ff347d2`**, contra o
manifesto que aquele commit carrega — que é onde o número vale. O `diff` entre os manifestos é
exatamente as linhas novas, nenhum artefato antigo mudou de hash: `grep -F -x -f` do manifesto
velho contra o novo devolve **27 de 27** linhas reproduzidas byte a byte. O
`clone-ff347d2-import.log` tem o mesmo SHA do `clone-import.log` de `cbaaef5` e do
`clone-3ab08db-import.log` (`6778e5a…`), ou seja, a saída do `--import` frio byte a byte igual
entre as três revisões. Os `.log` ficam fora da normalização de fim de linha
(`docs/evidence/** -text` no [.gitattributes](../.gitattributes)), que é o que faz o hash do
manifesto bater em qualquer clone — e foi isso que se provou acima, rodando o `-c` do lado de dentro.

### Furo desta perna: a evidência da rodada não estava no repositório

Contado arquivo por arquivo contra `cbaaef5`: das dez pastas de
[`docs/evidence/`](evidence/), nove entraram com suas rodadas (`aether-reactions` 16, `audio` 17,
`ether-cache-limite` 12, `ether-massa-conservada` 10, `fp-hand` 40, `passo-lobo-plano` 20,
`simulation-rng` 20, `third-person-carry` 13, `tick-journal` 16). `rastro-duas-camadas` tinha
**zero** — os 23 arquivos desta rodada existiam só na árvore de trabalho, enquanto o README, o
AGENTS.md e o status já citavam `evidence/rastro-duas-camadas/…` desde `cbaaef5`. Quem clonasse a
`main` receberia citações de tabela apontando para arquivos inexistentes: exatamente o defeito que
a rodada do passo do lobo registrou e consertou para a pasta anterior.

Não é vermelho de suíte — nenhuma checagem lê o manifesto — e por isso passou: o contrato de
"número publicado aponta um `.log` real" se cumpre no clone, não na máquina de quem mediu. A
correção entrou com `3ab08db` (merge de `docs/medicao-rastro-duas-camadas`), que trouxe as
23 assinaturas; a re-confência que faltava é a das duas últimas linhas da tabela acima — clone
limpo de `3ab08db`, `--import` frio exit 0, duas gateiras verdes e `sha256sum -c` **27/27** dos
artefatos e **79/79** das fontes rodados **dentro do clone**. Fica fechado, com log.

### Prosa que a medição obrigou a reescrever

Não foram números de linha: foram afirmações que o próprio braço A desmentiu.

- `AGENTS.md`, o parágrafo do leitor de rastros: o título era "custo limitado por código, não
  otimização medida" e o corpo só derivava a conta. Agora são três números medidos e o título
  diz o que continua sem medição — a alocação.
- `docs/design/09`, a linha "**O leitor é horizontal, embora o campo seja 3D**": falsa desde
  `f89041b`. Reescrita como o que o código faz — escalonado, de uma célula, mandando a camada
  própria — com o limite real no lugar: o alvo horizontal ainda é achatado em `offset.y = 0.0`
  ([wolf.gd:453](../src/entities/wolf.gd#L453)), então o cheiro é lembrado no andar
  certo e perseguido no andar do lobo.
- O mesmo §"Limites" dizia "o destino usa a altura de superfície da coluna": também falso, e
  troca-se pela primeira célula sólida descendo do topo da camada encontrada.
- `docs/planos/03` e `04`: as linhas internas do varredor (`:472-477`, peso `:476`, canal `:487`)
  e a frase "5 lobos × 147 `sample_cell`" viraram a conta escalonada, com o número da matriz.
- `docs/planos/05`: a nota "citações herdadas, **não relidas** nesta revisão" saiu — `wolf.gd:521-565`
  e `player.gd:659`/`:675` foram reconferidas na árvore do merge, e o risco de fase que o dossiê
  descreve é real (0,25 s em `:30`, disparado em `:446-447`).

### Re-derivações desta rodada

`src/entities/wolf.gd` foi de 724 a 749 linhas em quatro blocos (`@@ -25,6 +25,7 @@`,
`@@ -458,7 +459,10 @@`, `@@ -469,22 +473,29 @@`, `@@ -492,8 +503,22 @@`): +1 constante, +3 de
docstring, +7 do laço escalonado, +14 do chão. O mapa old→new saiu dos **blocos iguais** dos
opcodes do `difflib`, não de deslocamento uniforme — por isso as citações dentro de 460-530 e
26-36 foram tratadas uma a uma. Aplicado em `AGENTS.md`, `README.md`, `docs/melhorias-status.md`,
os 7 dossiês com citação do lobo e os 5 documentos de design: **178 alvos mudados de 214
citações `wolf.gd`** (AGENTS 21, status 51, planos 46, design 60), **25 rótulos abreviados
trazidos de volta ao alvo** e **15 citações corrigidas pelo conteúdo**, entre elas
`461-496` → `462-506`, `27-33` → `27-34`, `482-483` → `493-494`, `435-463` → `436-467`,
`472-480` → `482-492`, `494-496` → `505-506` e `472-477` → `478-489`. Conferência final: cada
citação do varredor impressa contra o arquivo — `462-506` abre no docstring do quadrado,
`478-489` é o `for k`, `493-494` é a renovação, `505-506` é `cell_center` + `_scent_ground_y`,
`513-521` é o chão, `654-659` é a linha do F3 e `257-258` é o achatamento do `offset`. Zero
rótulos fora do alvo **entre as citações que aquele bloco tocou** — a frase não vale para o arquivo
inteiro, e a perna que mede `ff347d2` foi ver isso acontecendo.

Fechado nesta ponta: `docs/design/10-world-layers-and-block-physics.md:1046` citava
`smoke_test.gd:2403-2405` como a impressão do piso de pior passo, e aquelas linhas são
o fim do cenário de planar e o reposicionamento da queda livre. As duas linhas que
imprimem `worst_sim_ms` são [`smoke_test.gd:346`](../tests/smoke_test.gd#L346) e
[`:2893`](../tests/smoke_test.gd#L3467), e o próprio design/10 foi re-ancorado nelas. A
passada anterior não alcançava a citação (as duas de design10, `501-546` → `526-571` e `130-131` → `131-132`, conferidas
conteúdo a conteúdo). Registramos onde está; consertá-la é um commit de assunto próprio.

O mesmo vale para três rótulos deste arquivo que ficaram para trás quando o `wolf.gd` cresceu — e
aqui a conferência é por máquina, não por leitura: das **79** citações com número de linha que têm
âncora no repositório **à época desta passada**, **5 ocorrências** (três rótulos distintos, dois deles escritos duas vezes)
têm rótulo ≠ âncora, todas neste arquivo. As cinco estão fechadas na tabela de **"Rodada Alcateia"**
no fim deste arquivo, e os números do parágrafo anterior valem pela corrida em que foram medidos. O caso é sempre o mesmo: a âncora foi re-derivada, o
rótulo não. `:538-539` com âncora `#L563-L564` (linhas 152 e 281) aponta para `563-564`, que é
`_unstick = _rng.randf_range(…)` e `_detour = … _rng.randf()` — a âncora está certa, o rótulo está
25 linhas velho, do deslocamento do bloco do chão. `:291-292` com âncora `#L292-L293` (linha 1261)
aponta para `292-293`, que é o `if _checked_scents.size() >= SCENT_MEMORY_CAP:` e o
`erase(_checked_scents.keys()[0])` da evicção — de novo a âncora certa, rótulo +1 velho. E
`:301-304` com âncora `#L302-L305` (linhas 151 e 281) é o pior dos três: nem o rótulo nem a âncora
são o que a frase afirma — as três chamadas de `_rng` na patrulha estão em `303`, `305` e `306`,
então a janela honesta é `303-306` e nenhuma das duas janelas atuais a cobre. Não se corrige aqui:
é assunto de citação, não de medição, e a lição registrada é que conferir rótulo contra âncora é
checagem de máquina (o par `rótulo:NN-MM` do texto contra o `#LNN-MM` da URL, arquivo a arquivo),
e ela não estava sendo feita.

**Esta nota envelheceu na Rodada Alcateia, e o que ela dizia sobre as âncoras era a árvore da nota,
não a da branch.** Conferidas uma a uma contra `eb6ec8d` (a base, código byte a byte igual ao de
`4ac5838`): `_unstick`/`_detour` estão em `590-591`, não em `563-564` — aquela faixa é o bloco do
boiar na água; a evicção por `SCENT_MEMORY_CAP` está em `319-320`, não em `292-293`; e as chamadas
de `_rng` da patrulha em `303`, `305` e `306` eram do lobo solitário de uma revisão anterior — na
base aquelas três linhas são o fim de `_leaf_investigate` (`_scent_found = false`,
`_scent_strength = 0.0`, `_scent_cd = 0.0`) e os sorteios estão em `329`, `331` e `332`. Ou seja:
das cinco, **zero** tinham âncora certa na base. O caso a mais que a checagem de rótulo não pega é
do mesmo tamanho e estava na mesma frase: a declaração `_rng` citada como `wolf.gd:164` (real: `123`,
em `eb6ec8d` era `77`) e a semente citada como `:175` (real: `191`, em `eb6ec8d` era `137`) — rótulo
e âncora batiam entre si e os dois apontavam para código que a frase não afirma. **Dez ocorrências**
em quatro lugares deste arquivo — as duas frases que descrevem o `_rng` (o recorte do sorteio em
"Feito nesta sessão" e o item 2 da fila), a frase do corte em "Notas de medição" e a da evicção na
rodada do cache de inspeções — foram postas na árvore atual nesta rodada, cada alvo lido: cinco são da classe rótulo ≠
âncora e cinco da classe rótulo = âncora com alvo errado. **A conta fechada é doze âncoras novas,
não onze**, e a nota anterior desta mesma seção dizia **seis** para a primeira classe: as cinco
ocorrências viraram **sete**, porque `:301-304` e `:538-539` aparecem **duas** vezes cada (uma em
cada frase que descreve o `_rng`) — a primeira faixa virou duas (`:425` e `:442-443`) em cada
aparência, o que dá quatro âncoras, e o desvio virou `:766-767` em cada, o que dá duas; com a
evicção `:412-413`, são sete. A tabela, âncora por âncora, está em "Rodada Alcateia".

### Observações registradas, sem atribuição

**O `--import` frio do clone limpo deu exit 0 também em `ff347d2`** — quinta amostra depois do 139
isolado da rodada do passo, 299 linhas em 7 s de relógio, zero linhas de erro, e a saída de novo
byte a byte a dos dois clones anteriores (mesmo SHA de log, `6778e5a…`). Continua sem atribuição:
cinco zeros seguidos em árvores diferentes não separam "o 139 era intermitente" de "a árvore nova
não o dispara" — o que fecharia é N tentativas frias da mesma árvore com o exit anotado, ou a pilha
do engine.

**A contagem de quit voltou a se mover entre árvores de conteúdo idêntico, e agora com mais
amostras:** `branch-suite.log` dá `4 ObjectDB instances` + `2 resources still in use`;
`main-suite.log`, `clone-suite.log`, `docs-suite.log`, `merge-main-suite.log`,
`clone-3ab08db-suite.log` e `merge-ff347d2-suite.log` dão `8` + `4`; e `clone-ff347d2-suite.log`
não dá **nenhuma** das duas linhas. As seis primeiras árvores são iguais em `src/` e `tests/`
(`git rev-parse cbaaef5:src` = `3ab08db:src` = `ff347d2:src`), mesmo binário, mesma máquina,
corrida serial. A leitura de que a contagem é do processo no `quit()`, não da árvore, fica mais
forte e o par `4/2` passa a ser a exceção da amostra. O log sem linha nenhuma obriga a corrigir o
que se tinha dito: ele foi capturado com `2>&1`, igual ao da `main` mergida que encheu as duas —
então a ausência não é explicada pelo modo de captura, e sim pelo processo ter saído antes de
imprimir. Nenhuma checagem depende dela e o exit segue 0 nas duas.

### O que nada disso fecha

Nenhum gate de fase. O que a rodada fecha é uma pergunta de custo e uma de alcance: o leitor
alcança a camada vizinha quando a própria não devolve nada, e isso custa +12 % medidos, não
+32 %. Fica em aberto:

- o **HOT agregado dos cinco lobos** (dossiê 04) — o rodapé daqui é um lobo por cenário;
- a **ordem de evicção** do cache de 32, deixada pela rodada anterior;
- se o gate de um andar basta: `SCENT_Y_RADIUS = 1` é escolha derivada do custo medido, não
  varrida em rampa. Ninguém mediu 2 ou 3 andares, nem o caso em que o rastro está dois andares
  abaixo — o cenário de caverna põe o sangue exatamente uma célula abaixo;
- o achatamento horizontal do destino (`offset.y = 0.0`): o lobo fareja no andar certo e anda
  no dele. Não é defeito reproduzido, é limite registrado em §09;
- as alocações do cache (`keys()`) continuam sem colheita própria, e o `Dictionary` do
  blackboard também;
- **citações fora do alvo medidas por máquina**: das 79 citações com âncora do repositório, 5
  ocorrências têm rótulo ≠ âncora (três rótulos, dois escritos duas vezes — ver a seção de
  re-derivação), mais a mis-citação de `docs/design/10:1046`. O contador existe como conta de
  rodada, não como checagem da suíte: nada em `tests/` derruba vermelho quando um rótulo envelhece.

## Rodada de escopo — as corridas da branch e da `main` mergida, e o que elas não medem (2026-11-20, `docs/escopo-alcateia-bioma-reproducao` → `633e653`)

### O que rodou

- `tests/smoke_test.tscn` na branch → **236 checagens / 0 falhas / 38,7 s**, exit 0, 311 linhas de
  saída com zero `SCRIPT ERROR`; ruído de quit `8 ObjectDB instances` + `4 resources still in use`
  (a família majoritária da nota anterior, não a exceção `4/2`).
- `--script tests/aether_reactions_test.gd` na branch → **109 checagens / 0 falhas / 2,167 s**,
  exit 0, censo `109/109`, zero `SCRIPT ERROR`.

As duas contagens valem como execução do gate da branch: são determinísticas e nada aqui toca
`src/` nem `tests/`. A prova é por árvore, não por palavra — `git rev-parse HEAD:src` =
`cbaaef5:src` = `9f5256b:src` = `9a8dbdfc01f1…` e `HEAD:tests` = `cbaaef5:tests` = `7bcbde99b7d8…`,
com `git status --porcelain src tests` devolvendo zero linhas. O engine é o mesmo
build (`.tools/Godot_v4.7.2-stable_win64.exe`, `4.7.2.stable.official.ed1daf0bf`, exatamente a
string do cabeçalho dos logs da rodada dos rastros); o md5 dele medido agora é `2afa3142b68f…`, e
a rodada anterior não publicou md5 nenhum do binário, então isso é coincide por versão, não por
hash conferido entre sessões.

### O que os µs desta sessão não são

A linha do cenário estreito saiu assim, quatro corridas seguidas, todas com `passos=2768`:

| Corrida | `sim_step` total | pico | BT `last_us` soma | trips |
| --- | --- | --- | --- | --- |
| 1 | 420 595 µs | 894 µs | 17 670 µs | 0 |
| 2 | 439 265 µs | 958 µs | 18 703 µs | 0 |
| 3 | 445 745 µs | 877 µs | 19 121 µs | 1 |
| 4 | 466 263 µs | 989 µs | 19 255 µs | 0 |

Nenhuma das quatro cai na banda do **mesmo código** na rodada dos rastros: as 12 corridas gateadas
de [`docs/evidence/rastro-duas-camadas/`](evidence/rastro-duas-camadas/)
(`publicado-1/2/3`, `colheita-contadores-1/2`, `main-runner`, `merge-main-runner`,
`merge-ff347d2-runner`, `docs-runner`, `clone-reactions`, `clone-3ab08db-runner`,
`clone-ff347d2-runner` — todas na linha 118 de cada log) vão de **361 464 a 375 216 µs** com o
mesmo `passos=2768`, e o BT `soma` delas é **14 409 a 14 859 µs** contra 17 670–19 255 daqui. A
média das quatro contaminadas é **442 967 µs**, +21,8 % sobre os `363 680` do braço F
([readback.log](evidence/rastro-duas-camadas/readback.log), linha 28), e o `pico` acompanha: a
linha 21 do mesmo arquivo dá 619 / 609 / 545 µs para os três runs publicados e a linha 39 dá 775
no clone limpo, contra **877–989** aqui.

O `trips=1` da terceira corrida é a peça mais direta dessa atribuição: o `SubtreeGuard` compara
400 µs de **tempo de parede**, e nas 12 corridas da banda publicada ele nunca disparou. Aqui ele
disparou uma vez em quatro — e as 109 checagens continuaram 0 falhas, porque a contagem de trips é
colhida, não gateada. Um disparo que só aparece sob concorrência é o instrumento medindo o
concorrente, não a árvore.

Deslocamento de +16 % a +27 % no total das quatro corridas da branch, e +20 % no BT, com a árvore
medida byte a byte a mesma, não é de código: é da máquina. Duas amostras instantâneas na janela
das corridas, ambas com a máquina longe de ociosa: `Win32_PerfFormattedData_PerfOS_Processor`
(`Name='_Total'`) deu **28 %** de uso,
e `Win32_PerfFormattedData_PerfProc_Process` deu `_Total=1562` contra `Idle=1380` (**11,7 %** de
uso) com os maiores consumidores reais sendo `Qoder#2` (38), **`MsMpEng` (27 — o Defender em tempo
real, que varre exatamente os arquivos que uma corrida headless escreve)**, `QuantumEngine` (16),
**`obs64` (16 — o OBS aberto)** e `dwm` (16). Não confunda com a lista que um
`Get-Process | Sort CPU` devolve nesta máquina: ela ordena segundos de CPU **acumulados desde o
start**, que não dizem nada da janela; o que sustenta a atribuição são os dois contadores
formatados acima. Pelo contrato (medição de tempo é serial com a máquina livre, e número publicado
é número medido em clone limpo com `--import` frio), estes µs entram como **teto sob carga, não
como medição**: o `363 680` publicado no AGENTS.md e a ablação de +12 % da rodada dos rastros
continuam sendo o par de referência, e nenhuma das duas tabelas muda por esta sessão.

Um indício que fica registrado sem virar conclusão: os valores desta sessão encostam ou passam do
braço de **três camadas incondicionais** da ablação (427 940 / 427 134, linha 19 do readback), e a
média das quatro corridas da branch (442 967 µs) passa. As duas hipóteses que isso não separa são
"a máquina agora está mais lenta" e "o gate abre camada vizinha mais vezes do que a ablação media".
O que decide é uma perna `bench/` com a máquina ociosa, na mesma revisão, medindo o braço do gate na
mesma janela — e ela pertence ao item 5 da fila (dossiê 04, HOT agregado), não a esta branch de docs.

### As duas corridas da `main` mergida são a peça que faltava

`633e653` (merge `--no-ff` da branch do escopo) roda suíte **236 checagens / 0 falhas / 38,3 s**,
exit 0, zero `SCRIPT ERROR`, ruído `8/4` de quit; e o runner estreito, **109 checagens / 0 falhas /
2,052 s**, exit 0, com `passos=2768 sim_step total=389 885 µs pico=897 µs; BT soma=16 042 µs
trips=0`. A igualdade de código é conferida por árvore: `git rev-parse HEAD:src` =
`9a8dbdfc01f1…` e `HEAD:tests` = `7bcbde99b7d8…`, os mesmos dois hashes do parágrafo anterior.

`017340a`, o merge desta nota, repete o gate na mesma árvore de código: suíte **236 / 0 / 38,3 s**,
exit 0, zero `SCRIPT ERROR`; runner **109 / 0 / 2,194 s**, exit 0, `total=428 373 µs pico=958 µs;
BT soma=17 812 µs trips=0`. O `git diff --name-only 633e653...HEAD -- src tests project.godot assets
tools` desta revisão devolve zero arquivos.

O primeiro `total` da `main` cai **entre** as duas bandas — acima dos 361 464–375 216 publicados,
abaixo dos 420 595–466 263 das quatro da branch — e é isso que fecha a atribuição sem precisar de
mais nada: **seis execuções da mesma árvore de código** nesta sessão deram, em ordem crescente,
389 885 / 420 595 / 428 373 / 439 265 / 445 745 / 466 263 µs — chão de **−9,7 % a +8,0 %** em torno
da média delas (431 688), contra uma banda de **±2 %** em doze execuções da rodada dos rastros. O
instrumento não está cego por acaso: ele está sendo lido em cima de carga. Quatro desses seis
valores passam do braço de três camadas incondicionais (427 940 / 427 134, linha 19 do readback), e o
menor deles — 428 373 — está a 0,1 % da linha de cima desse braço.

O rol das seis é o estado da janela no momento da escrita, não uma contagem gateada: cada nova
execução enquanto esta sessão viver acrescenta um valor e não muda a conclusão. O que muda é o
número publicado, e ele continua sendo o da rodada dos rastros.

Consequência registrada, e é ela que vale para as próximas pernas: **nenhuma medição de µs desta
máquina entra como número enquanto houver sessão de agente rodando**, e o que separa um deslocamento
de código de um deslocamento de ambiente não é uma corrida a mais na mesma janela — é uma corrida
com a máquina ociosa. As quatro pernas `feat/` de 09 a 12 vão esbarar nisso, porque as três primeiras
tocam o caminho quente do lobo e a quarta o mesher; cada uma precisa do seu par de corridas com o
chão medido, ou o delta sai como foi aqui: imprestável para atribuir.

Nenhum gate de fase se fechou aqui, e nenhum item da fila mudou de veredito.

## Rodada Bioma — o bioma decide algo, medido (2026-11-20, publicado em `9fe5e45` pelo merge de `feat/bioma-e-cor-de-pelo-09`, base `e7e30e6`, ponta de código `44c9d94`)

### O que estava em aberto

Dossiê [09](planos/09-bioma-cor-de-pelo-e-ether.md), três peças e duas premissas: (1) um bioma só
existe como código se decidir algo que o jogador vê ou o lobo sente; (2) derivar bioma **não pode**
alterar o terreno, porque o terreno é o que o `GEN_VERSION = 4` e a projeção do hash assinam. O
[`README.md`](../README.md) e este arquivo descreviam a realidade anterior: nenhum identificador
em `src/`, todos os lobos com `Color(0.40, 0.36, 0.31)` e os imprints passando o mesmo número numa
coluna de gelo e numa de savana.

### O que entrou (quatro commits, um assunto cada)

- `0111a9a` — `enum Biome` + `biome_of(x, z, h)` em [world_gen.gd:32](../src/world/world_gen.gd#L32)
  e [:129](../src/world/world_gen.gd#L129); `surface_block` passa a consultar
  ([:165-166](../src/world/world_gen.gd#L165-L166)) em vez de repetir as comparações. Gate da
  premissa 2: checagem nova `bioma_nao_altera_terreno` em
  [tests/smoke_test.gd](../tests/smoke_test.gd), auto-contida contra quatro assinaturas pinadas da
  base `e7e30e6` (relevo das 16 colunas, SHA do topo de uma grade 32×32, histograma de blocos de
  topo e SHA dos 1 048 576 voxels do mundo).
- `2f6ca26` — `FUR_COLORS` [:155](../src/entities/wolf.gd#L155), `home_biome` perguntado uma vez no
  `setup` ([:309](../src/entities/wolf.gd#L309)) e re-derivado no `load_state`
  ([:1378-1382](../src/entities/wolf.gd#L1378-L1382)), porque o load move o `home` sem reconstruir o
  visual. Checagens 3 no runner: dois lobos em biomas diferentes saem com `albedo_color` diferente,
  dois no mesmo bioma saem com a mesma.
- `f9b63b3` — `IMPRINT_BIAS` [:45](../src/world/world_gen.gd#L45) lida por
  `imprint_bias` ([:156-157](../src/world/world_gen.gd#L156-L157)) e aplicada **pelo chamador** do
  evento: `_imprint` em [wolf.gd:415-417](../src/entities/wolf.gd#L415-L417) e
  [main.gd:943-945](../src/main.gd#L943-L945) cobrem os 11 sítios de imprint que já existiam. A
  folha de fuga fica de fora, com o motivo no código ([:444](../src/entities/wolf.gd#L444)): ela roda
  todo tick com `_threat > 0`, e ruído + altura ali é exatamente o custo que o dossiê recusa no
  caminho quente. Checagens 4: pino literal da tabela linha a linha, campo cru devolvendo o valor do
  evento sem viés (a fronteira), ordem de grandeza preservada e média por canal na banda.
- `44c9d94` — a guarda inalcansável que o commit anterior deixou em `imprint_bias` (`push_error` +
  `return 1,0` para índice fora da tabela) sai: um `1,0` devolvido em silêncio disfarça de "nenhum
  viés" um erro de ligação entre bioma e canal, e o runner já conta um teste que estoura como falha.
  É também o commit que conserta o `const` — `Array[PackedFloat32Array]` com construtores embutidos
  **não é expressão constante** em GDScript 4, e a branch não compilava antes disso.

### Gates de contagem, com o clone limpo

| onde | suíte | runner (`--script tests/aether_reactions_test.gd`) |
|---|---|---|
| árvore de trabalho, conteúdo de `44c9d94` | 237 / 0 / 35,5 s, exit 0, `SCRIPT ERROR` 0 | 119 / 0 / 2,064 s, exit 0 |
| clone limpo de `44c9d94`, `--import` frio | 237 / 0 / 35,5 s, exit 0, `SCRIPT ERROR` 0 | 119 / 0 / 2,044 · 2,028 · 2,017 s, exit 0 nos três |
| clone limpo do chão `e7e30e6` | não rodou — o número daquela árvore já está publicado | 109 / 0 / 2,012 · 1,995 · 2,052 s, exit 0 nos três |
| `main` mergida `9fe5e45` (`--no-ff`; 20 arquivos acima de `44c9d94`, todos `README.md` e `docs/`, com `src` = `9f3a952dc123…` e `tests` = `56e487343728…` idênticos) | 237 / 0, exit 0, `SCRIPT ERROR` 0 — `35,8 s` é o tempo desta janela, não entra como custo | não rodou — nada em `tests/` mudou na merge |

Censo interno conferido em todas as corridas da branch: `24/24` cenários e `119/119` checagens — 21→24
e 109→119 é a conta do lote. O `diff` trabalho × clone tem 14 linhas e **nenhuma é checagem**; os dois
logs batem `aether_energy`, `tick=359`, `wolves_alive=4`, `dropped_ticks=0`, `triangles=214480`,
`chunks=64` e `edits=13` dígito a dígito — e o `diff` da `main` mergida × clone tem as mesmas 14 linhas
pela mesma razão. Manifestos: `sources.sha256` (79 fontes, conferidas dentro do clone, 79 `OK` / 0
divergências) e `artifacts.sha256` (16 logs, 16 `OK`).

### As três sabotagens, e o que cada uma decide

Não bastava o verde: `sab-red-linha-da-tabela.log` troca um multiplicador (`arid/work` 1,30 → 1,10) e
devolve **119 / 1**; `sab-red-vies-dentro-do-campo.log` move o multiplicador para dentro de
`AetherField.imprint` e devolve **119 / 7** — inclusive `medo local com jogador invisivel`, porque o
valor estoura o `MAX_VALUE 4,0` quando o viés age no campo. A fronteira é requisito, não estilo, e é
isso que as duas corridas dizem. A terceira é da suíte: `sab-red-coluna-profunda-suite.log` faz o
erro que o dossiê §1.2 proíbe **abaixo** do bloco de topo (o `sub` de `generate_chunk` passa a
depender do bioma) e devolve **237 / 1 / 35,6 s**, exit 1, um único FAIL —
`bioma_nao_altera_terreno | divergentes=1/4 voxels=1048576 full=249dd54198bc`, com `rel16` e `hist`
idênticos ao pino. Ou seja: as duas amostras de superfície não veem a coluna profunda, e a varredura
dos 1 048 576 voxels é o que segura o viamento.

### O custo: pareado, e a banda do dossiê não vale (furo #15)

Dez corridas do runner estreito nesta janela, cinco por árvore, as últimas quatro em pares alternados.
`sim_step total` médio **383 695 µs** na branch contra **381 462 µs** no chão: **+0,59 %** contra uma
dispersão intra-chão de **4,05 %**. No par alternado a branch ficou abaixo do chão numa dupla e acima
na outra. O `pico` é o único que se move de forma não-trivial (média 872,8 vs 772,6, +13 %; 21 dos 25
pares possíveis branch > chão) e, com n = 5 e sendo máximo de um único passo, **é indício, não
atribuição** — a hipótese que ele aponta é a consulta de ruído + altura caindo no passo em que o
evento imprime, e a perna `bench/` do item 5 é quem decide.

A banda que o dossiê §4 escreveu como gate (361 464–375 216 µs) não é alcançada nem pelo chão desta
janela: `e7e30e6` dá 372 473–387 730. É a segunda vez que banda de µs não é portátil entre janelas, e
o motivo agora tem nome na lista de furos.

### O efeito no mundo, que é a razão da peça

`aether_energy` do diagnóstico final, mesmo cenário, campo e revisão:

| árvores até `e7e30e6` (sem viés) | `44c9d94` (com viés), trabalho **e** clone |
|---|---|
| `9,36133219487965` | `9,44745890423656` |

Δ **+0,086 126 709 356 91 (+0,92 %)**, direção esperada: a média do multiplicador é 1,0000 em trabalho
e 1,0125 em sangue e medo, com a linha `temperate` sendo a identidade nos três canais — redistribuição
entre biomas, não inflação global. É o primeiro número desta linha de história que mostra o mundo
mudando, não só a contagem de checagens subindo.

### Re-derivações desta rodada

Crescimento dos arquivos citados: `world_gen.gd` 249→309, `wolf.gd` 748→780, `main.gd` 501→510,
`smoke_test.gd` 2 283→2 365, `aether_reactions_test.gd` 1 011→1 248. Toda âncora `arquivo:linha` deste
registro foi re-derivada contra `44c9d94` e lida no alvo, não conferida por faixa. A varredura por
conteúdo desta sessão (`ponteiros conferidos: 217 | alvos drifted: 96`) rodou com um script em
`.tools/`, **não versionado** — o número é da sessão, não reproduzível do repositório, e a perna de
`docs/` que fecha o furo #14 tem de trazer o instrumento para `tools/` junto com as re-derivações de
[`AGENTS.md`](../AGENTS.md) e [`docs/planos/`](planos/README.md). As citações desta seção e do bloco
de topo, ao contrário, foram lidas uma a uma nesta árvore.

### O que nada disso fecha

- Nenhum gate de fase. P0/P1 continua sem gate fechado, o runner é um lobo por cenário e não é o HOT
  agregado dos cinco.
- O item 8 da fila muda de veredito (concluído nesta máquina); os itens 9, 10 e 11 não.
- Falta a avaliação visual em janela — cor de pelo por bioma e a galeria re-bakeada são do dono, e o
  dossiê §6 proíbe prometer "bioma deserto" em texto de captura sem re-bake.
- Multi-semente (item 3) continua aberto: as checagens novas rodam com a semente fixa `20261116`.
- O `pico` de +13 % não tem dono ainda, e nada aqui autoriza tocar no mesher ou na difusão.

## Rodada Docs — dois dossiês novos, o índice das catorze páginas e a re-derivacão das citações (2026-11-20, `docs/escopo-convivio-e-genealogia` → `f47b61f`)

### O que estava em aberto

Dois pedidos do dono na própria conversa e nenhuma peça de código que os nomeasse: a **árvore
genealógica** de todo ser vivo com o Éter lendo parentesco, e a **convivência da alcateia** — rondar
pelos blocos de terra, água como último recurso, nada de aviso na tela e spawn sempre a uma distância
segura. Somaram-se a isso duas dívidas deste arquivo: a página-índice de
[`docs/planos/`](planos/README.md) publicava contagens medidas por **regras diferentes entre si** (a
mesma página dava 622/629 para doze arquivos e 74 referências cruzadas contando duas vezes o mesmo
link), e quatro ponteiros de dossiê caíam em faixa mas em prosa de outra seção — o defeito que o furo
#14 descreve e que a gateira de existência não vê.

### O que entrou (quatro commits, um assunto cada)

- `c8c50f4` — dossiê [13](planos/13-arvore-genealogica-e-ether.md): a premissa falsificável é que
  **ascendência só existe se nascer de dois adultos, sobreviver ao save e mudar algo observável**, e
  que herdar é genoma-base — nunca a memória nem o trauma do pai. Oito checagens em headless, o custo
  pelas quatro perguntas, e o degrau real do código: `src/entities/` tem **uma** espécie animal,
  nenhum NPC e o jogador sem `Mind` nem `identity` (grep devolve zero ocorrências dos dois nomes em
  [`player.gd`](../src/entities/player.gd)). Os três degraus acima do lobo ficam `[TARGET]`.
- `58aa1b7` — dossiê [14](planos/14-convivio-da-alcateia.md): seco é regra de validade do **alvo**
  (água é último recurso, não obstáculo), "organizado" é teto numérico e não adjetivo, criatura nunca
  vira texto no HUD e nenhum bicho nasce a menos de `SAFE_SPAWN_DIST` do jogador com linha de visão
  livre. Nove checagens, inclusive a que exige que o resgate de margem continue funcionando depois da
  árvore de decisões mudada.
- `40ca4fb` — re-derivacão por conteúdo, com as duas pontas lidas contra `eb6ec8d`: os dois
  `world.set_block` de gameplay são `player.gd:667` e `:693` (eram `:659`/`:675`, que são os
  cabeçalhos de `_mine_target()` e `_try_place()`); o `_on_acted` que imprime WORK está em
  `main.gd:703-708` (saiu de `:309-313` quando o viés de imprint entrou); o teto do load que pareia
  por índice é `main.gd:697`, não `:504`; as três promessas da lavra estão em
  `smoke_test.gd:891-899`, não `:780-790`; `EXPECTED_CHECKS` é `aether_reactions_test.gd:21`
  com **119**, não `:16` com 109. Nos dossiês: `07:67` e `07:137` apontavam
  `README.md:505-512` (a seção do oráculo local — os três números de README desta
  frase são da numeração de `eb6ec8d`, e o README tem 13 linhas a mais nesta ponta; os de status, `:78`
  e `:83`, não se moveram) para a queda de ~16 s para ~7,5 s, que está em `:546-553`, e `12:63` apontava
  `README.md:533` (linha de lista do Éter) e o par geração/malharia em `:78` quando está em `:83`.
  Os números acima são **texto, não link**: é a leitura de `eb6ec8d` gravada naquele commit, e um
  link diria "leia agora". Relida **naquela** ponta, três dos cinco alvos continuavam nos mesmos
  números (`player.gd:667`/`:693`, [`main.gd:994-999`](../src/main.gd#L994-L999),
  [`main.gd:1172-1208`](../src/main.gd#L1172-L1208)); os dois que apodreceram eram as promessas da lavra,
  hoje [`smoke_test.gd:2082-2091`](../tests/smoke_test.gd#L2082-L2091), e o pino da contagem, que naquela
  árvore era a linha 25 do runner com **183** e era [`:60`](../tests/aether_reactions_test.gd#L64)
  com **198**. **Hoje, depois da 19 e da 11, dois dos cinco se moveram:** os dois `world.set_block`
  do jogador estão em [`player.gd:685`](../src/entities/player.gd#L685) e
  [`:711`](../src/entities/player.gd#L711) — a 19 cresceu o arquivo —, e o load que pareava por índice
  (`main.gd:697` na leitura de `eb6ec8d`) foi **substituído** pelo pareamento por identidade
  ([`main.gd:1166-1208`](../src/main.gd#L1166-L1208)); o `_on_acted` e as promessas da lavra continuam onde
  estavam, e o pino da contagem é [`:60`](../tests/aether_reactions_test.gd#L64) com **225**.
- `91409af` — a página-índice passa a ter **uma regra declarada**: contam-se os catorze dossiês, esta
  página fica fora (ela cita os ponteiros alheios para descrevê-los) e cada link
  `[rótulo](alvo)` vale uma referência, não duas. Sob essa regra: 59 ao status, 8 ao contrato, 6 ao
  `README.md` da raiz — **73**, mais 5 ao `README.md` de design.

### A corrida que sustenta os números

Nenhuma engine foi rodada pelos dossiês: eles são leitura de código, como diz o topo daquela página. O
que foi rodado é a verificação das duas gateiras, e ela tem método — `git archive eb6ec8d` extraído em
`/tmp/cite-eb6`, os **documentos** desta árvore por cima (é o corpo que se publica), `src/` e `tests/`
do archive intocados, e `.tools/` copiado para dentro porque está no `.gitignore` e os logs que a
página 07 cita só existem lá. Com `CITE_ROOT` apontando para essa árvore montada:

| Conta | Valor | Como se confere |
| --- | --- | --- |
| Citações dos catorze dossiês | **790**, 0 fora do arquivo | `python .tools/verify_plan_cites.py docs/planos/<arquivo>` por página (61 · 47 · 25 · 73 · 67 · 33 · 44 · 52 · 36 · 74 · 56 · 54 · 103 · 65) |
| Diretório `docs/planos/` inteiro | **802** (790 + 12 desta página-índice) | idem, somando `README.md` |
| Trio que governa a casa | **322** (85 · 0 · 237), 0 fora | `AGENTS.md`, `README.md` da raiz, `docs/melhorias-status.md` |
| Referências cruzadas do corpus | **73** pela regra nova | links colapsados, índice fora; a conta velha (74) misturava duas regras |

Os quatro números acima **se reproduzem na árvore mergida**, sem o rig: rodados em
`C:/Aetherfall` com `src/` e `tests/` exatamente em `eb6ec8d` (árvores `9f3a952` e `56e4873`), dão
802 · 322 · 0 fora. A página-índice registra também que a contagem da página 07 é 44 **porque**
`.tools/` existe nesta árvore: a gateira não conta citação de arquivo ausente, então numa máquina sem
os logs de run o mesmo comando devolve 39. Não é erro de corpo — é a diferença entre ter e não ter o
que está no `.gitignore`.

A suíte na `main` mergida: **237 checagens / 0 falhas / 36,4 s**, exit 0, zero `SCRIPT ERROR` no log
(`.tools/main-merge-docs-suite.log`, `:312`). O pino publicado de 35,5 s vale para `eb6ec8d`; os 36,4 s
são desta corrida e não re-pinam nada, porque o merge não toca uma linha de código.

### O que nada disso fecha

- Nenhum gate de fase, e nenhum dossiê vira código por ser escrito. A fila serializada daquela
  ponta era 09 → 10 → 14 → 11 → 12 → 13; hoje é **09 → 10 → 15 → 14 → 11 → 12 → 13**, e 09, 10
  e 15 já pousaram.
- **A perna 10 morreu no meio, e este item está fechado: ela voltou.** O agente de
  `feat/alcateia-rutinas-10` chegou a commitar `6e670c3` (matilha injetada: `pack_provider` no lobo,
  leitura da sessão uma vez por passo) e ficou com **57 linhas** de diferença não commitada em
  [`wolf.gd`](../src/entities/wolf.gd) e
  [`aether_reactions_test.gd`](../tests/aether_reactions_test.gd) — assentos de cerco, `_pick_wander`
  por rank de território e o centro da matilha — quando bateu o limite de turnos. O trabalho não foi
  jogado fora: esteve preservado em `/tmp/leg10-backup/` (cópia dos quatro arquivos, `md5` conferido, o
  patch `wip-vs-eb6ec8d.patch` e os dois logs que ele mesmo rodou). A perna voltou, os `md5` do backup
  foram conferidos contra a ponta e o resto do dossiê foi commitado na própria branch — veja
  **"Rodada Alcateia"** no fim deste arquivo. É exatamente o cenário que a regra 6 de
  [`AGENTS.md`](../AGENTS.md) protege: um escritor por arquivo, e a ordem decidida **antes**.
- Restavam **69** referências numeradas do corpus a `wolf.gd`, `main.gd` e `smoke_test.gd` sem conferência de
  conteúdo (régua daquela passada, não reproduzível pelo comando de hoje; re-medido: **234** suspeitas no corpus
  pelo `verify_cite_content.py` — 848 citações em faixa, alegação colhida para 445 — e **78** no trio da casa). A
  perna que as lê pelo que a linha diz roda depois de a 10 pousar; o que mudou aqui está no furo #17.
- Os dois dossiês novos não têm runner, nem branch de código, nem captura. `FamilyTree`, `PackState`,
  `SAFE_SPAWN_DIST` e as dezessete checagens propostas são `[TARGET]`, declarados como tais no
  `verify_plan_ids.py`.

## Rodada Alcateia — a matilha entra na decisão do lobo, com contagem e citações re-derivadas (2026-11-20, `feat/alcateia-rutinas-10`, base `eb6ec8d`, ponta de código `c42250c`, mergida na `main` em `0c38489` e publicada em `252f1e7`)

### O que estava em aberto

A perna tinha morrido no meio: o agente de `feat/alcateia-rutinas-10` chegou a commitar
`6e670c3` e ficou com **57 linhas** não commitadas em [`src/entities/wolf.gd`](../src/entities/wolf.gd)
e [`tests/aether_reactions_test.gd`](../tests/aether_reactions_test.gd) quando bateu o limite de
turnos. O trabalho estava preservado em `/tmp/leg10-backup/` e foi retomado na própria branch, não
reescrito de memória: dos quatro arquivos do backup, [`tests/smoke_test.gd`](../tests/smoke_test.gd)
chegou à ponta com `md5` **idêntico** ao do backup (`2f3e6eeb11a2…`), e os outros três cresceram
depois dele (`wolf.gd` `fc63f2521883…` → `655d8660bcb2…`, `main.gd` `235e23157cef…` →
`da91fc6216e8…`, runner `a0e9de309954…` → `9b90b61d1847…`). O item correspondente na Rodada Docs
envelheceu com isso e está marcado como fechado ali mesmo.

O pedido do dossiê era uma frase com cinco verbos: a alcateia **ronda**, **fareja**, **procura**,
**cerca** e **ataca em grupo**. O estado lido antes de escrever: a árvore de decisão era de um lobo
solitário — o `Selector[flee, hunt, sniff, patrol]` não recebia nenhum outro lobo, e o único lugar
onde "matilha" existia era o `WOLF_COUNT := 5` do spawn e a frase do HUD.

### O que entrou (sete commits de código, um assunto cada)

- `6e670c3` — a sessão monta a matilha e o lobo **só lê**: `pack_provider`
  ([wolf.gd:208](../src/entities/wolf.gd#L208)) preso à identidade em
  [main.gd:461](../src/main.gd#L461), uma passada por passo (`_rebuild_packs`
  [:859-879](../src/main.gd#L940-L960)) que testa cada par `i<j` contra
  `PACK_COHESION_RADIUS = 24 m` ([:39](../src/main.gd#L39)), escreve nos dois buffers e trunca o
  cursor para não deixar vizinho fantasma; `pack_of` ([:850-852](../src/main.gd#L931-L933)). Sem
  provedor a lista é `NO_PACK` ([wolf.gd:43](../src/entities/wolf.gd#L43)) e o lobo solitário é
  literalmente o de antes.
- `79882d2` — **ronda por setor**: centro compartilhado (baricentro, `_territory_center`
  [:694-701](../src/entities/wolf.gd#L694-L701)) e fatia angular por rank (`_territory_rank`
  [:708-713](../src/entities/wolf.gd#L708-L713)) em `_leaf_wander`
  ([:652-670](../src/entities/wolf.gd#L652-L670)); com um lobo só, o centro é o próprio lar e a fatia
  é o círculo inteiro, que é a ronda antiga.
- `8e334e3` — **cerco**: assento `TAU/n` onde `n` conta quem está em `hunt` de fato
  (`_hunt_pack_size` [:525](../src/entities/wolf.gd#L525)), ponto a 1,50 m da presa
  (`_seat_point` [:548-551](../src/entities/wolf.gd#L548-L551), `ENCIRCLE_RING`
  [:39](../src/entities/wolf.gd#L39)).
- `89df566` — **mordida escalonada**: `_bite_turn` [:793-797](../src/entities/wolf.gd#L793-L797)
  devolve `clock.tick % n == rank`, chamada em [:774](../src/entities/wolf.gd#L774) — dois lobos não
  mordem o mesmo tick.
- `4888818` — a leitura da matilha ganha **quinta chave conferida**: `trust` vem de
  `_pack_put` ([main.gd:980](../src/main.gd#L980), `e["trust"] = other.trust_toward_player`), o
  contexto do escorredor leva o pacote ([wolf.gd:862](../src/entities/wolf.gd#L862)) e o
  `_sense()` agrega `_pack_trust` ([:937-946](../src/entities/wolf.gd#L937-L946)).
- `2e4ff65` — **contágio do medo**: vizinho em `flee` soma `0,55` no `_fear_level` do observador
  ([:932-941](../src/entities/wolf.gd#L932-L941), `PACK_PANIC_FEAR`
  [:53](../src/entities/wolf.gd#L53)). O vizinho **não escreve** no lobo — cada um soma o que a
  sessão devolve.
- `c42250c` — **amortecimento por confiança**: vizinho com `trust ≥ 0,35` corta o `_courage` e fecha
  a porta de `hunt` ([:937-946](../src/entities/wolf.gd#L937-L946)); a única fonte de confiança é
  `take_damage` → `adjust_trust(from_actor, -0,35)` ([:1303](../src/entities/wolf.gd#L1303)), e o
  limiar é o mesmo `0,35` de `Mind.believes()` ([mind.gd:119-120](../src/ai/mind.gd#L119-L120)).

### A corrida que sustenta os números

Contagem só, em árvore de trabalho; os logs estão em
[`evidence/alcateia-rutinas/`](evidence/alcateia-rutinas/) (`readback.md` §1) e nenhum deles é clone
limpo. `src` e `tests` de `c42250c` são **byte a byte** os de `HEAD` (`c36ab6cd2380…` /
`03f8da29fce0…`), então o runner de 150 vale para a árvore atual sem re-corrida.

| corrida | suíte `tests/smoke_test.tscn` | runner `--script tests/aether_reactions_test.gd` | cenários |
| --- | --- | --- | --- |
| chão (`eb6ec8d`, publicado na Rodada Bioma) | `237 / 0 / 35,5 s` | `119 / 0` | 24 |
| WIP preservado (backup) | `239 / 0 / 36,2 s` | `130 / 0` | 25 |
| `79882d2` ronda | `239 / 0 / 36,9 s` | `135 / 0` | 26 |
| `8e334e3` cerco | `239 / 0 / 37,4 s` | `140 / 1` → `140 / 0` | 27 |
| `89df566` mordida | `239 / 0 / 35,8 s` | `142 / 3` → `/ 2` → `/ 2` → `/ 2` → `/ 1` → `142 / 0` | 28 |
| `4888818` confiança | `239 / 0 / 45,1 s` | `143 / 0` | 28 |
| `2e4ff65` contágio | `239 / 0 / 45,1 s` | `146 / 0` → `146 / 1` → `146 / 0` | 29 |
| `c42250c` amortecimento | `239 / 0 / 40,1 s` | `150 / 0` → `150 / 1` → `150 / 0` | **30** |
| pós-merge + docs (a ponta atual) | `239 / 0 / 41,3 s`, 318 linhas, `SCRIPT ERROR` 0 | não re-rodado — `src`/`tests` idênticos | **30** |

O teto publicado do runner é `EXPECTED_CHECKS` ([aether_reactions_test.gd:64](../tests/aether_reactions_test.gd#L64)),
que saiu de **119** (na base, linha 17) para **150**. Suíte: **237 → 239**, com as duas checagens da
sessão real ([smoke_test.gd:388](../tests/smoke_test.gd#L388),
[:376-379](../tests/smoke_test.gd#L376-L379)). Em todos os 28 logs arquivados, `SCRIPT ERROR` é
zero — e as sete vermelhas nomeiam a premissa que quebraram, uma por uma, no `readback.md` §2. A
mais instructiva é `ataque-runner-1.log`: `mordidas=0` com `candidatos_no_primeiro_tick=4` e
`trips_matilha=10`, ou seja, antes do escalonamento quatro lobos em alcance e nenhum morde porque o
`SubtreeGuard` estoura antes de chegar na folha.

**µs não são gate nesta perna** (regra I do furo #15), e não há chão pareado: o cenário estreito roda
os mesmos 2 770 passos em todos os braços e o `sim_step` integral saiu de ~378–405 kµs (ronda/cerco)
para ~557–570 kµs (contágio/amortecimento) na mesma janela de trabalho, com a máquina em uso pelo
dono. Duas leituras possíveis — a leitura da matilha mais o contágio custam ~45 %, ou a janela estava
carregada — e esta perna não tem como separá-las. Fica como débito, tabela completa no `readback.md`
§4.

### O censo da sessão real, e o furo que ele abre

`pos-merge-suite.log:23-24` diz `pares=10 esperado=10 maior_matilha_lida=1 lobos_vivos=5`. É verde,
e é o furo **#16**: `pares=10` conta **comparações** `i<j`
([main.gd:949](../src/main.gd#L949)), não vizinhos coesos; `maior_matilha_lida=1` é o maior
`_pack.size()` entre os lobos, e `_pack` exclui o próprio lobo. No vale real, com os cinco lares
espalhados, ninguém teve dois vizinhos — cerco, contágio e ronda por setor estão provados no fixture
de quatro lobos colocados a propósito uns dos outros
(`cerco-runner-2.log:141`, `angulos=[0.0, 1.5708, 3.1416, 4.7124] n=4`), não no mundo. A asserção
`biggest >= 1` não barra esse estado; a perna 14 é quem troca por `>= 2` quando o spawn mudar, e isso
está registrado **antes** do código. **Pago:** o `>= 2` está em
[smoke_test.gd:357-362](../tests/smoke_test.gd#L357-L362) e quem muda o spawn é a mordaca de 18 m
([`PACK_LEASH`](../src/main.gd#L559)).

### A tabela que a nota das dez ocorrências prometeu

`cb96493` pôs na árvore **dez ocorrências** em quatro lugares deste arquivo. Cada alvo foi lido na
linha; nada aqui é troca automática. A coluna "afirmava" é o registro do que aquela revisão dizia;
a última é o **ponteiro vivo** re-derivado na rodada 19 — os dois números da mesma linha diferem
por +5 porque `wolf.gd` cresceu desde então, e é por isso que uma coluna é registro e a outra é link.

| # | onde está | afirmava | classe | âncora posta na árvore |
| --- | --- | --- | --- | --- |
| 1 | linha 207 deste arquivo, em "Feito nesta sessão" — recorte do sorteio | `wolf.gd:145` / `#L99` | rótulo = âncora, alvo errado | [`wolf.gd:215`](../src/entities/wolf.gd#L215) (`var _rng := RandomNumberGenerator.new()`); na base era `77` |
| 2 | idem | `:175` / `#L175` | idem | [`wolf.gd:311`](../src/entities/wolf.gd#L311) (`_rng.seed = ("wolf:%d:%d" % …)`); na base era `137` |
| 3 | idem | `:301-304` / `#L302-L305` | rótulo ≠ âncora | [`wolf.gd:660`](../src/entities/wolf.gd#L660) **e** [`wolf.gd:677-678`](../src/entities/wolf.gd#L677-L678) — a faixa virou duas |
| 4 | idem | `:538-539` / `#L563-L564` | rótulo ≠ âncora | [`wolf.gd:1240-1241`](../src/entities/wolf.gd#L1240-L1241) (`_unstick` / `_detour`) |
| 5-8 | linhas 348-351 deste arquivo, em "Falta" — item 2 da fila, as mesmas quatro frases | idem a 1–4 | idem | idem a 1–4 |
| 9 | "Notas de medição", frase do corte | `wolf.gd:169` / `#L99` | rótulo = âncora, alvo errado | [`wolf.gd:215`](../src/entities/wolf.gd#L215) |
| 10 | rodada do cache de inspeções, evicção | `:291-292` / `#L292-L293` | rótulo ≠ âncora | [`wolf.gd:647-648`](../src/entities/wolf.gd#L647-L648) (`SCENT_MEMORY_CAP` e o `keys()[0]`) |

Cinco ocorrências por classe rótulo ≠ âncora viram **sete** âncoras (as faixas 3 e 7 aparecem duas
vezes cada e cada uma corta em duas), e cinco por classe alvo errado viram cinco: **doze** âncoras
novas por **dez** ocorrências.

**O que ficou de fora** e por quê: as 11 citações que a passada mecânica tinha escrito sobre faixa em
branco ou só comentário voltaram ao número da `main` em `cb09015` — branco casa com branco em
qualquer lugar, a prova é vazia, e o número errado de antes é conhecido, não um número novo inventado.
Em `fb20707` outras **18** re-derivações foram desfeitas pelo mesmo motivo, e as **15** âncoras
escritas com travessão nu (`#L173-174`) foram normalizadas sem tocar no número — **8** delas já
apontavam para código que a frase não afirma, e deslocar isso seria embelezar mis-citação com um
número saído de uma prova que não confere.

### Prosa que esta perna obrigou a reescrever

- A Rodada Docs escreveu "**A perna 10 morreu no meio**" no tempo em que ainda era verdade; ela voltou
  e fechou. O texto ali foi corrigido no tempo e mantém o registro do backup.
- A nota das dez ocorrências dizia que "as cinco primeiras viraram **seis** âncoras". Conferidas uma a
  uma na árvore: são **sete** (e o total, doze). Corrigido na própria nota.
- [`AGENTS.md`](../AGENTS.md) tinha **42** ponteiros sobre os quatro arquivos que a branch fez
  crescer, escritos contra a `main` anterior à perna — inclusive a descrição das pernas 13 e 14, que
  citava `main.gd:173`/`:459` (agora `:264`/`:634`), `wolf.gd:500-518` (agora `:601-619`), o
  `Mind.new` de `wolf.gd:222` (agora `:234`) e as quatro folhas em `:435`, `:451`/`:454`, `:497`
  e `:515`. Cada um dos 42 foi lido no alvo, e o conteúdo da frase
  re-conferido: as quatro folhas que "escolhem alvo sem nenhum teste de solo" continuam sendo as
  quatro ([`_leaf_flee`](../src/entities/wolf.gd#L494),
  [`_leaf_chase`](../src/entities/wolf.gd#L510)/[`_leaf_chase`](../src/entities/wolf.gd#L514),
  [`_leaf_stalk`](../src/entities/wolf.gd#L556),
  [`_leaf_investigate`](../src/entities/wolf.gd#L574)) — a perna 14 fechou o buraco **depois** do
  tick, com `_resolve_dry_target()`
  ([wolf.gd:764-768](../src/entities/wolf.gd#L764-L768)), e não copiando o teste para dentro delas.

### Contagem de citações, pela regra declarada aqui

`python .tools/verify_plan_cites.py <cada .md rastreado>` sobre o corpus: **1 311** citações com
número de linha conferidas, **0** números fora do arquivo, **27** arquivos citados que não existem
(todos `[TARGET]` dos dossiês 13 e 14 — `FamilyTree`, `PackState`, `SAFE_SPAWN_DIST` e cia.; a perna
14 tirou `SAFE_SPAWN_DIST` dessa lista, ele é [`main.gd:24`](../src/main.gd#L24) desde `9fa8c6c`). O trio
que governa a casa (`AGENTS.md`, `README.md` da raiz, este arquivo) dá **415**, 0 fora, com a mesma
falta de `docs/engine/simclock.md` que já estava registrada. A checagem de rótulo contra âncora
([`_chk_labels.py`](../.tools/_chk_labels.py), corpus `.md` **sem** `.tools/`) dá **848** links com
`#L`, **97** rótulos sem número e **7** sinalizados — os sete lidos: seis são literal de código na
etiqueta (`SEED := 20261116`, `_random_ground_point(16.0, 46.0)`, `GEN_VERSION = 4`,
`Mind.new(..., 1000 + p_identity)`, `var identity: int = 0`, `SCHEMA = 1`) e um é a soleira
`0,35` de `believes()`; **nenhum** é citação errada, e as sete âncoras foram conferidas no conteúdo.
Os dois verificadores vivem em `.tools/`, que está no `.gitignore` — é o furo #14 alcançando a
própria régua: quem chega por clone não tem a ferramenta, então estas quatro contagens são medição de
árvore de trabalho desta máquina, não comando reproduzível de fora.

Dois números desta conta não se reproduzem, e isso é a lição, não o erro: a mensagem de `cb96493`
publicou "2 446 links de código" e a mesma passada sobre o corpus rastreado devolve **848**. A
diferença é `.tools/`: incluído, a contagem sobe para **2 529** porque o diretório tem 131 `.md` de
trabalho. É o furo #14 em outro dígito — o que está em `.tools/` não existe no clone de quem chega, e
uma contagem que o inclui não é reproduzível por fora.

Falta uma régua e ela não estava em lugar nenhum: o corpus também cita **este arquivo** por linha. São
**60** referências `docs/melhorias-status.md:NNN`, e as 285 linhas que a perna escreveu aqui dentro
deslocaram **44** delas (16 já caíam no lugar) — registro no **furo #17**, e a passada que as realinha é
`python .tools/_rederive_status_refs.py`, com prova de conteúdo linha a linha (o mapa `difflib`
`HEAD` → árvore só reescreve onde o texto é idêntico) e conferência refeita ao contrário: **52/52**.

A régua é genérica (`python .tools/_rederive_doc_refs.py <alvo>`) e esta nota a passou no `README.md`
da raiz, que ela mesma fez crescer 13 linhas. O corpus guarda **9** referências numeradas a ele pela
regra da casa — 12 contando a página-índice, que se exclui — e quem cita linha posterior a 213 desloca
+13. **3** ponteiros vivos mudaram de número com prova de conteúdo: `07:67` → `README.md:559-566`, e
`07:137` e `12:62` → `:561`. As três de `13` e `14` (`:192`, `:197`) apontam para antes do ponto de
inserção e não se moveram. Os **4** números que vivem em **prosa histórica** — os ponteiros errados de
`eb6ec8d` que esta página e a página-índice registram como corrigidos — **não** foram deslocados: a
frase descreve o que estava errado naquela numeração, então recebeu o rótulo da numeração em vez de um
número novo. Armadilha achada no caminho: duas páginas se chamam `README.md`, e sem lookbehind o padrão
casava `docs/design/README.md:12-16` contra o da raiz; aí nenhuma linha foi de fato reescrita (offset
zero ou ponta em branco), e a guarda agora está na ferramenta.

### O que nada disso fecha

- **Nenhum gate de fase**, mas a perna pousou e está publicada: o clone limpo de `188490b` deu
  **239 / 0 / 38,6 s** com `--import` frio exit 0 (`clone-gate-*.log`), a `main` mergida `0c38489`
  re-rodou **239 / 0 / 38,2 s** (`merge-0c38489-suite.log`) e a `main` com esta nota, `252f1e7`, deu
  **239 / 0 / 38,4 s** (`merge-252f1e7-suite.log`) — §6 a §8 de [`readback.md`](evidence/alcateia-rutinas/readback.md).
- **Furo #16**: a sessão real nunca montou matilha de dois. Era a primeira peça da perna 14, e é
  onde ela foi paga: a mesma linha da sessão real devolve `maior_matilha_lida=4` com a asserção em
  `biggest >= 2` ([smoke_test.gd:399-404](../tests/smoke_test.gd#L399-L404)).
- **Furo #17**: **8** das 60 referências a linhas deste arquivo ficaram para trás de propósito — seis
  já apontavam para linha em branco (mis-citação pré-existente, prova vazia) e duas caem dentro de um
  bloco que esta passada reescreveu. Consertar é ler a frase, não mexer o número.
- O HOT agregado dos cinco lobos continua sem medição (dossiê 08, item 5) e `MindsInspector` não
  existe: a matilha lida hoje se lê no log do runner, não no F3.
- Memória compartilhada **entre** matilhas continua `[TARGET]`: `Mind.relations` é confiança por ator
  ([mind.gd:26](../src/ai/mind.gd#L26), [:154-159](../src/ai/mind.gd#L154-L159)).

## Rodada Docs 15 — o índice das quinze páginas re-medido depois de a perna 10 pousar (2026-11-20, `docs/oracle-embutido-15`, base `b779cee`, ponta anterior `abf2c07`)

### O que estava em aberto

A página-índice e o dossiê 15 nasceram enquanto a perna 10 ainda mexia em `src/entities/wolf.gd` e em
`src/main.gd`. Pousada ela (código `0c38489`, `main` publicada `b779cee`), sobravam quatro frases que
descreviam como futuro o que já tinha acontecido, e uma série de números medidos contra `4ac5838` — a
ponta de antes do merge. Nada de código: o assunto desta ponta é documento e régua.

### O que entrou (quatro commits, um assunto cada)

1. **Dossiê 15** — oráculo embutido no boot: o jogo levanta o servidor local do modelo e o derruba ao
   fechar a janela, sem passo manual e sem depender de quem aperta botão. Ponta `43a3329`.
2. **Registro de ordem + página-índice das quinze** — a fila serializada reescrita **antes** de qualquer
   linha de código, agora 09 → 10 → 15 → 14 → 11 → 12 → 13, com o motivo de dependência de cada elo.
   Ponta `abf2c07`.
3. **Contrato + dossiê: a perna 10 pousou** — as duas frases que diziam "a perna 10 está escrevendo
   agora" viram passado em `AGENTS.md` e no § de estado do dossiê 15, e a extensão (3) da fila passou a
   nomear as pernas já concluídas.
4. **Índice re-medido + esta nota** — os números do índice passados contra a ponta atual, o mapa do
   `README.md` da raiz entre a numeração antiga e esta, a classe que faltava na taxonomia de
   identificadores e a correção de uma soma que o próprio índice publicava errada.

### A corrida que sustenta os números

Esta ponta não escreve uma linha de `src` nem de `tests`: o diff entre a `main` e aqui nesses dois
diretórios é vazio, e as duas árvores de diretório são byte-idênticas às da `main` publicada — `src` em
`c36ab6cd2380b3dc7d584b7b4ebbd009ec445b5a`, `tests` em `03f8da29fce069ce25dac5ddad4fe49ce7bbb3e8`. Por
identidade de árvore, o número da suíte desta ponta é o da `main` doc-only `99fa0f3`: **239 checagens /
0 falhas / 39,1 s**, exit 0, em `merge-99fa0f3-suite.log` (33ª entrada de `artifacts.sha256`). A corrida
da `main` mergida recebe nota própria abaixo desta, como fez a perna 10: ela só existe depois do merge.

### As quatro correções de prosa, e o que cada uma custava

- **O README da raiz mudou duas vezes** entre a numeração que as páginas citavam (649 linhas) e esta ponta
  (662): o primeiro commit moveu linhas, o segundo reescreveu sem mover. Mapeado por bloco igual, o texto
  que três páginas buscavam caiu em outros lugares, e os três ponteiros vivos foram re-derivados. A frase
  antiga, que dizia que o arquivo não tinha mudado, estava falsa — e a régua conta ponteiros que a própria
  nota de correção escreve, o que fez o total desta página subir por causa do texto que explicava a subida.
- **A soma das catorze páginas antigas** estava publicada como 60 · 8 · 6 · 5; a régua sobre as catorze dá
  **59 · 8 · 6 · 5**, e 60 só aparece quando esta página entra no corpus. Número publicado que não se
  reproduz por regra nenhuma é defeito de número, não de régua.
- **A taxonomia de identificadores** não tinha classe para `throw`, palavra-chave do script de lançamento
  do servidor de mente, que a gateira lê como nome de código porque só conhece `src` e `tests`.
- **A atribuição da fila histórica** do parágrafo de exceção (2) foi feita pelo commit que a escreveu e
  pelo que a publica, não por um único SHA.

### Contagem conferida nesta ponta

- Citações com número de linha nas quinze páginas dos dossiês: **895**; nesta página-índice: **15**; no
  diretório inteiro: **910**. As catorze páginas antigas, sozinhas: **792**.
- Trio que governa a casa — `AGENTS.md`, `README.md` da raiz e este arquivo: **415** números, por documento
  **86 · 0 · 329**, zero número fora do arquivo. A extensão do dossiê 15 não acrescentou citação numerada
  nenhuma ao contrato.
- Corpus rastreado inteiro: **1 417** citações conferidas, **31** arquivos citados que não existem, **0**
  números fora do arquivo. Na `main` desta base a mesma régua deu **1 311 · 27 · 0**; a diferença é o
  escopo desta ponta, não um regresso.
- Links de código por âncora de linha: **907**, rótulo sem número: **99**, rótulo diferente do alvo: **7**
  — as mesmas sete linhas de código literal de sempre, nenhuma nova.
- Página 15: **49** identificadores em backticks, **23** ausentes em `src` e `tests`, classificados em
  **10** checagens propostas, **3** de API do motor, **3** de estado, **3** de chave de log, **2** de peça
  proposta, **1** SHA e `throw`.
- Os quatro sumidos governantes das catorze páginas: **59 · 8 · 6 · 5**, elo a elo iguais aos medidos em
  `4ac5838`.

### O que nada disso fecha

- **Nenhum gate de fase.** A perna 15 continua só dossiê: o hospedeiro do servidor de modelo proposto, o
  probe de boot proposto e as checagens que o dossiê nomeia não existem em código nesta ponta, e a dupla
  que os declara fica marcada como alvo no dossiê 15 e nesta página-índice.
  *(Estado seguinte: a rodada Oráculo 15, abaixo, escreve o hospedeiro, a sonda de boot em cinco modos
  e as sete checagens — 239 → 246.)*
- **[OPEN] medir tempo até health e VRAM** — pedido do dono, ainda sem número. O dossiê declara a medição
  como gate da perna de código; ninguém mediu nada aqui.
  *(Estado seguinte: a mesma rodada fecha os dois números — `/health`/200 aos ~12,5 s da janela e
  ~3,0 GiB lidos das linhas do próprio servidor.)*
- As quatro frases corrigidas moravam em documento, não em código; nenhuma re-derivação de `wolf.gd` ou
  `main.gd` foi precisada por esta ponta, e as **69** referências sem conferência de conteúdo continuam
  devendo a perna que as relê.
- O HOT agregado dos cinco lobos e `MindsInspector` seguem sem peça e sem medição; esta rodada é
  contagem de documento, não coluna de desempenho.

### A corrida da `main` mergida (2026-11-20, ponta `2bf0854`)

O merge desta ponta em `main` — base `b779cee`, merge commit `2bf0854` — rodou a suíte headless com a
máquina livre, com nenhum outro processo do motor aberto e **nenhuma janela de jogo**: **239 checagens /
0 falhas / 39,7 s**, exit 0, `SCRIPT ERROR` **0** nas duas correntes (o arquivo de stderr publicado tem
**0 bytes**, e é esse o número). O log está em `docs/evidence/oracle-embutido-docs/merge-2bf0854-suite.log`
e o hash dos dois arquivos no `artifacts.sha256` ao lado; `.tools/` segue fora do repositório, então a
cópia publicada é o que existe para quem chega por clone limpo.

As duas árvores conferem com a nota acima, byte a byte: `src` = `c36ab6cd2380b3dc7d584b7b4ebbd009ec445b5a`,
`tests` = `03f8da29fce069ce25dac5ddad4fe49ce7bbb3e8`. O número desta corrida é o mesmo número, medido de
novo — não herdado. E o diagnóstico final do run fecha com `wolves` = 4 e `pending_respawns` = 1 depois de
a checagem do censo ter passado com `lobos` = 5 no ponto dela: é o estado conhecido desta suíte, não um
censo que este merge recusou, e nenhuma linha de código mudou entre as duas medições.

Na mesma ponta mergida as três réguas foram passadas de novo no checkout real, com `.tools/` presente:
corpus **1 417 / 31 / 0**, trio **415**, âncoras **907 · 99 · 7** — os três números que a nota da rodada
publica, conferidos depois do merge, não antes. A mesma régua numa worktree sem `.tools/` devolve
**1 407 / 61 / 0**: dez citações a menos deixam de ser contadas e trinta arquivos entram na lista de
ausentes, e todos são logs de run. É o furo #14 com outro dígito — contagem que depende de `.tools/`
não é reproduzível por clone.

## Rodada Oráculo 15 — o jogo levanta o modelo sozinho, medido na janela (2026-11-20, `feat/oraculo-embutido-no-boot-15`, base `27800eb`, ponta de código `09780c4`, evidência `a6b83d7`)

### O que estava em aberto

A rodada anterior (Docs 15) descrevia a perna como documento e régua: hospedeiro, probe e checagens
**não existiam** em código, e `[OPEN] medir tempo até health e VRAM` não tinha número. Esta ponta
escreve o código e fecha a medição. O pedido do dono, literal: *"ao startar o game, tem que carregar o
modelo de i.a na máquina [...] sem eu ter que abrir depois... tem que ser algo embutido"*, e depois,
quando a primeira versão já rodava: *"ao abrir o jogo, sem eu fazer nenhum procedimento na mão [...] ele
já sobe o llama-server sozinho? ta tudo pronto? o modelo carrega e fica pronto na abertura do jogo?"*.
A segunda metade do pedido original — *"depois vemos como fica pra quem não tem placa de vídeo"* —
continua `[OPEN]` e não é desta perna.

### O que entrou (dez commits, um assunto cada)

1. `61d2612` — **oráculo** ganha chave, alias único, portão de prontidão e recuo próprio do 503
   ([mind_oracle.gd](../src/ai/mind_oracle.gd)).
2. `db9afd5` — **hospedeiro** do `llama-server`: o próprio processo do jogo levanta e derruba o modelo
   (`llm_server_host.gd`, 417 linhas novas; aposentado no Passo 4 do dossiê 22, commit 5138549).
3. `a09c2eb` — **F3** mostra a linha do hospedeiro por provider, não por referência
   ([hud.gd](../src/ui/hud.gd)).
4. `7d9c8a9` — **`main`** monta o hospedeiro antes da geração e fecha o portão do oráculo; em headless
   o hospedeiro não entra na árvore ([main.gd](../src/main.gd)).
5. `3cb0c16` — o **lançador** do oráculo aceita a mesma chave do jogo e vira caso de uso
   ([run_mind_server.ps1](../tools/run_mind_server.ps1)).
6. `74ad670` — **sonda de boot** com cinco modos, cada um imprimindo número ou vermelho
   (`llm_server_boot_probe.gd`, 385 linhas, + `.tscn`; aposentado no Passo 4 do dossiê 22, commit
   5138549).
7. `f8b42a5` — a **suíte** cobra portão, derivação da chave e recuo nomeado: **7 checagens novas**,
   239 → **246**.
8. `fae0b40` — a sonda `ci` **não reentra** mais: o braço vira a página antes de esperar frames.
9. `09780c4` — **um dono por porta**: a janela real revelou o segundo `llama-server`.
10. `a6b83d7` — **evidência**: 36 arquivos com `readback.md` e `artifacts.sha256` em
    [`docs/evidence/oracle-embutido-15/`](evidence/oracle-embutido-15/readback.md).

### A resposta à pergunta do dono, em linhas literais

Jogo aberto em janela, sem `--headless`, sem passo manual, sem sonda (`janela-produto-log-do-jogo.log`):

```
llm_host  sondando  sonda /v1/models em http://127.0.0.1:8741
llm_host  carregando  pid 26852  boot do modelo iniciado  (1/1 spawn)
llm_host  pronto  boot 2762 ms  503=11  pid 26852
llm_host  encerrando pid 26852  OK
```

Vista de fora do processo, com `GET /v1/models` autenticado a cada segundo: `porta=sem conexao` em
t+ 8519 ms, `http 503` em t+10165 ms, `200 mind-small` em t+12536 ms. Ou seja: **sim** — abrir o jogo
sobe o servidor, carrega o modelo e ele fica pronto antes de o jogador fazer qualquer coisa; fechar a
janela derruba o filho ( Checagem 6, `encerrando pid 26852  OK` + porta fechada depois).

### As cinco sondas, e os dois vermelhos pagos

| Modo | Veredito em `09780c4` | O que nega |
| --- | --- | --- |
| `ci` | 9 / 0, 6.6 s | sem runtime e sem rede: motivos diferentes, zero pedido HTTP, zero processo, portão fechado |
| `boot` (janela) | 9 / 0, 12.4 s | boot medido com ticks andando, narrativa chegando sem passo manual, chave |
| `reuse` | 5 / 0, 9.2 s | servidor nosso na porta ⇒ reuso, sem segundo spawn, sem assumir pid alheio |
| `foreign` | 4 / 0, 6.4 s | 401 de terceiro ⇒ `estrangeiro`, ninguém morre, nada é duplicado |
| `death` | 7 / 0, 14.2 s | morte externa depois do 200 ⇒ exatamente uma retentativa |

Dois vermelhos ficaram arquivados de propósito, porque sem eles a atribuição seria conversa:

- **reentrada** — `sonda-ci-antes-do-corte-reentrada.log`: 9 / **2**, 7.2 s, com as duas checagens do
  segundo host em `estado=ocioso` e **30 linhas** `ausente (modelo)`. O `_run_ci` era chamado a cada
  frame enquanto `_phase` valia `ci` e trocava o host injetado por um novo. Cortado em `fae0b40`.
- **dois donos na porta** — `sonda-boot-janela-antes-do-dono-unico.log`: 9 / **1**, 18.5 s, com **dois**
  `create_process` (pids `2556` e `27328`, os dois `pronto`) e dois `encerrando`. O `_ready` do mundo já
  criava o host dele e a sonda injetava o segundo por cima. Consertado nos dois lados em `09780c4`:
  `attach_llm_host` aposenta o anterior (`remove_child` roda o `_exit_tree` na hora) e a sonda adota o
  hospedeiro da janela. Nesta a sonda passou a imprimir um único spawn, pid `13924`.

A checagem 4 também estava errada de conceito, não de número: ela comparava `main_ready` (duração do
`_ready` do mundo, 6 149 ms) com `boot_ms` (duração do boot do modelo, 2 792 ms) como se fossem a mesma
grandeza, e dava vermelho sem nada bloquear. Agora ela nega uma **sequência** com dois timestamps do
mesmo relógio — se a carga estivesse dentro do `_ready`, o primeiro 200 teria chegado antes de ele
voltar. Medido: `main_ready=6149 ms  primeiro_200=10521 ms  duracao_do_boot=2792 ms`.

### Tempo até o `/health` (fechado o `[OPEN]` da rodada anterior)

Dois relógios por amostra, no mesmo argv do `_spawn` (`servidor-saude-*.log` e `servidor-manual-*.log`):
o laço de polling vê o primeiro 200 em **2 740 ms** e **2 709 ms**, e o próprio servidor anuncia
`model loaded` em **2 538 ms** e **2 471 ms** — 99 a 238 ms de diferença, uma a duas voltas do `sleep
0.25`. O servidor de terceiro chega ao 200 em 2 571 ms **e devolve 401 para a chave do jogo**, que é
justamente por que o hospedeiro sonda `/v1/models` antes de decidir `reusado` ou `estrangeiro`. A amostra
de 3 864,7 ms é de uma corrida com `-lv 7` (4 348 linhas impressas durante a carga) e vale como teto de
servidor verboso. O número do produto continua sendo o `boot_ms` lido dentro da janela: **2 762 ms** e
**2 792 ms**.

### VRAM, lida das linhas do próprio servidor

`servidor-vram-linhas-do-llama.log` (`-lv 7`, 466 372 B, 4 348 linhas, o arquivo é o stderr da corrida):
placa de **16 304 MiB**, **15 445 MiB** livres no boot, ajuste projetando **3 015 MiB** de memória de
dispositivo (2 603 de pesos + 329 de contexto + 83 de compute), `will leave 12429 >= 1024 MiB [...] no
changes needed`, com o `fitting` custando **0.96 s**. Os buffers da segunda passada (`no_alloc = 0`)
batem com o projetado: 2 603,50 MiB de pesos + 128,00 de KV + 201,00 de estado recorrente + 83,02 de
compute na placa, mais 497,31 de pesos e 24,02 de compute no host. As duas extrações exatas estão no
`readback.md` — o grep que a primeira versão publicava misturava a passada `no_alloc = 1`, que imprime
os buffers como `0.00 MiB`, e não reproduzia os números ao lado dele.

`Win32_VideoController.AdapterRAM` devolve `4293918720` nesta máquina: é o **teto de 4 GiB da WMI**, não
a placa. Não há contador de VRAM por processo aqui (`nvidia-smi` enxerga só a 4060 secundária, `rocm-smi`
não está instalado, não há conjunto PDH de contadores de GPU), então a fonte publicável é o device string
do servidor e o valor do WMI fica registrado como o que ele **não** é.

### Contagem e custo, na ordem em que aconteceram

| Ponta | Suíte | Última linha |
| --- | --- | --- |
| `27800eb` (base, `main`) | headless | `== 239 checagens  0 falhas  38.1 s de teste ==` |
| `f8b42a5` | headless | `== 246 checagens  0 falhas  40.0 s de teste ==` |
| `fae0b40` | headless | `== 246 checagens  0 falhas  40.4 s de teste ==` |
| `09780c4` | headless | `== 246 checagens  0 falhas  40.2 s de teste ==` |
| `a6b83d7` (docs) | headless, duas corridas | `== 246 checagens  0 falhas  46.9 s ==` e `== 246 checagens  0 falhas  46.2 s ==` |

A conta nova do caminho quente: o hospedeiro **não roda no tick**. Ele tem um `_process` de máquina de
estados que sonda a porta e polila o `/health` só enquanto carrega, e em headless o `main` não o monta
(`suite nao levanta modelo` passa com `display=headless  llm={  }`). O pedido do oráculo continua o
mesmo de antes: um `POST /v1/chat/completions` por requisição, com o portão de prontidão segurando o
primeiro pedido até o 200. O custo real do modelo é o do processo filho, fora do processo do jogo:
2,7 GB de disco, ~3,0 GiB de placa, e é por isso que a janela responde 200 em ~12,5 s e não em 2,7 s.

### Furos abertos ou agravados por esta ponta

- **Vazamento de saída já era da casa, não é desta perna.** As quatro suítes e as duas corridas de
  evidência fecham com `WARNING: 12 ObjectDB instances were leaked at exit` — inclusive a base `main`
  `27800eb`, que não tem nada daqui. Os stderr estão arquivados com sufixo `-err`.
- **`ERROR: N resources still in use at exit` caiu de 6 (base `main`) para 4 (três corridas da branch).**
  Não atribuído: esta perna não mediu por quê, e nenhuma peça escrita aqui segura recurso. Registrado
  para a perna que fechar o vazamento de saída.
- **O "stderr de 0 bytes" publicado para `2bf0854` não se reproduz nesta máquina.** A base desta ponta
  (`main-suite-base-err.log`) tem **250 bytes** com os dois avisos acima. A régua de 0 bytes daquela
  rodada era de outra árvore ou de outro estado do motor — nenhuma das duas explicações foi medida.
- **Dois `.uid` órfãos**: `tests/audio_test.gd.uid` e `tests/audio_live_probe.gd.uid` estão fora do git
  enquanto os `.gd` correspondentes estão dentro (37 `.uid` rastreados no resto do repo). É por isso que
  `tests/llm_server_boot_probe.gd.uid` entrou neste lote e os dois do áudio não: ninguém os criou no
  commit certo. Conserto é um commit `test/` pequeno, não parte desta ponta.
- **41 ms de `worst_sim_ms` numa corrida com a máquina ocupada** (`branch-suite-evidencia-2.log`, contra
  14,194 ms em `09780c4` quieto), com `dropped_ticks = 0` nas três. Não é defeito provado: é o que o
  contrato diz — timing em máquina concorrente é número do concorrente — e fica registrado para não
  virar baseline de otimização.
- **[OPEN] quem não tem placa de vídeo** continua sem peça: nenhuma corrida acima toca esse caminho.
  O hospedeiro hoje trata "sem runtime", "sem modelo" e "porta ocupada por terceiro"; não trata
  "Vulkan ausente" nem "carga que não cabe", e isso é decisão de projeto, não de implementação.

### Re-derivações desta ponta (os documentos, depois do código)

Quatro arquivos cresceram e cada `arquivo:linha` vivo dos documentos teve de acompanhar:
`src/main.gd` 599 → **662**, `src/ai/mind_oracle.gd` 140 → **212**, `src/ui/hud.gd` 658 → **664**,
`tests/smoke_test.gd` 2384 → **2464**. `src/entities/wolf.gd` (959), `src/entities/player.gd` (769),
`src/world/voxel_world.gd` (637) e `src/ai/mind.gd` (167) não mudaram de tamanho e foram só
reconferidos por conteúdo. A régua, que vale para as rodadas seguintes:

- **seção de estado atual** (as tabelas de promessas, os orçamentos, o "objeto deus", o estado lido
  dos dossiês ainda não abertos) recebe o número re-derivado;
- **seção de rodada histórica** ("Rodada …, publicado em `<sha>`") conserva os números da revisão que
  documenta — reescrevê-los apagaria justamente o registro do que estava em pé naquele commit.

O deslocamento, em linhas da base `27800eb` → linhas de `a6b83d7`, lido dos cabeçalhos de hunk de
`git diff -U0 27800eb...HEAD` e conferido âncora a âncora por grep de conteúdo:

| Arquivo | faixa na base → deslocamento |
| --- | --- |
| `src/main.gd` | ≤36 **+0** · 37–69 **+4** · 70–132 **+10** · 133–145 **+13** · 146–543 **+60** · ≥544 **+63** |
| `src/ai/mind_oracle.gd` | ≤13 **+0** · 14–18 **+15** · 19 **+16** · 20–28 **+20** · 29–36 **+30** · 37–44 **+32** · 45–62 **+37** · 63–64 **+43** · 65–82 **+44** · 83–107 **+45** · 108–117 **+46** · 118–119 **+55** · 120–124 **+56** · ≥125 **+72** |
| `src/ui/hud.gd` | ≤23 **+0** · 24–257 **+4** · ≥258 **+6** |
| `tests/smoke_test.gd` | ≤67 **+0** · 68–105 **+4** · 106–188 **+9** · 189–2089 **+15** · ≥2090 **+80** |

Cinco âncoras **já estavam tortas na base** — a translação cega as teria deixado tortas com números
novos, então cada uma foi reancorada pelo que o texto afirma:

| Citação nos documentos | O que havia naquele número em `27800eb` | Agora, em `a6b83d7` |
| --- | --- | --- |
| `main.gd:528-540` como `diagnostics()` | 523–531 eram brancos mais `stats_line()`; `func diagnostics` começava em **532** | [`main.gd:1240-1273`](../src/main.gd#L1240-L1273) |
| `main.gd:500` como `audio.clear_transient()` | 495 era `hud.set_death(false)` dentro do load; a limpeza estava em **504** | [`main.gd:1154`](../src/main.gd#L1154) |
| `smoke_test.gd:1986-1992` como a sonda da porta 1 | 1986–1992 é o passo de planar (`p.pitch = -0.9`, `action_press("glide")`); `_check_oracle_arm` começava em **2066** | `smoke_test.gd:2125-2131` |
| a lista de `hud.show_message` do estado lido da perna 14 (`main.gd:107`, `:194`, `:303`, `:376`, `:378`, `:384`, `:388`, `:424`) | nenhum desses números tinha `show_message` na base; os sites reais eram 125, 213, 391, 464, 466, 472, 476, 512 | `main.gd` **135**, **273**, **450-451** (conectado em **121**), **524**, **526**, **532**, **536**, **572**, mais [`hud.gd:603`](../src/ui/hud.gd#L603)/`:605`; os dois avisos de criatura ficam em **242** e **483** |
| as cinco âncoras de passo da suíte: `smoke_test.gd:1709-1713` por `_alive_wolf`, `:1752-1759` pela premissa do jogador, `:1767-1778` pela matilha estacionada, `:1781-1788` por `mira travada`, `:1098-1103` pelo zera-yaw | na base esses números continham outra coisa: varredura do leito (1709–1713), checagens de nado (1752–1759), `_pause_for`/`_unpause_for` (1767–1788) e a amostragem de oclusão (1098–1103); os conteúdos estavam em 1791, 1834–1841, 1849, 1863 e 1184 | por conteúdo, com o +15 do mapa: **1806-1810**, **1849-1856**, **1863-1877**, **1878-1884** e **1196-1200** |

Duas frases do [mandato 2](../AGENTS.md) precisaram de qualificação com o hospedeiro dentro: a saída
que chega a quem age continua sendo `_narrations`, e `last_reason` / `server_url` são lidos pelo
hospedeiro (`llm_server_host.gd:152-153`, `$:189` — aposentado no Passo 4 do dossiê 22, commit
5138549) **só** para a linha de status do F3 — leitura, nenhuma
escrita. O mesmo vale para a conta do "objeto deus": 599 → 662 linhas e um dono a mais na lista (o
hospedeiro do modelo), em [`AGENTS.md`](../AGENTS.md) e aqui na linha do acoplamento. Desde aquela
ponta a conta subiu de novo — 759 em [`src/main.gd`](../src/main.gd) — sem que o dono mudasse.
Relida na ponta da perna 14: **787**, e o acréscimo é o spawn —
[`_home_columns`](../src/main.gd#L539-L543), [`SPAWN_BANDS`](../src/main.gd#L550),
[`PACK_LEASH`](../src/main.gd#L559), [`_spawn_point_ok`](../src/main.gd#L762-L767) e
[`_spawn_home_point`](../src/main.gd#L788-L860) — não um dono novo.
Relida na ponta da perna 16: **1242** linhas, e o acréscimo é a toca dentro do bloco da matilha —
[`var _dens`](../src/main.gd#L136), [`_den_counts`](../src/main.gd#L607-L618),
[`_emptiest_den`](../src/main.gd#L619-L636), [`_den_gate_ok`](../src/main.gd#L637-L649),
[`den_min_dist`](../src/main.gd#L650-L671), [`den_components`](../src/main.gd#L672-L703),
[`DEN_COUNT`](../src/main.gd#L566-L573) e [`DEN_MIN_DIST`](../src/main.gd#L574-L584) — a nona linha da conta,
não um décimo dono: a lista de donos continua a mesma, e é justamente isso que o dossiê 06 cobra.
**Os dois parágrafos de cima são contagens das pontas daquelas pernas** — 787 e 1242 são números
da árvore de cada uma, lidos nela, e continuam escritos como foram. Os ponteiros por símbolo é que
são vivos, e foram re-derivados na perna 23, que moveu `src/main.gd` de 1246 para **1268** linhas: a
varredura numérica desta casa mexe em link, não em frase, e os **treze** números acima são os de hoje,
conferidos um a um contra o corpo que o rótulo nomeia.

### O que nada disso fecha

- **Nenhum gate de fase.** A perna 15 tem hospedeiro, sonda, evidência e os dois números que o dossiê
  cobrava; o gate de P1 continua aberto por `MindsInspector`, pelo HOT agregado dos cinco lobos e pelo
  resto das checagens do dossiê 08.
- `boot_ms` é tempo **desta** máquina, com modelo e runtime já em disco. Primeiro boot com
  `fetch_models.ps1` não foi medido, e a janela de teste foi aberta por mim para medir, com
  `--quit-after` — nenhuma das narrativas citadas veio de input de jogador.
- A mente continua sem caminho para o mundo: o oráculo só escreve `_narrations`, lido pelo HUD. O que
  mudou aqui é **quem levanta o servidor**, não quem decide o movimento.
- As citações de `main.gd`, `mind_oracle.gd`, `hud.gd` e `smoke_test.gd` nos documentos vivos estão
  re-derivadas pela seção acima; a passada do corpus inteiro, com o resíduo dela, é a seção seguinte.

### O corpus inteiro de âncoras, conferido por instrumento (2026-11-20)

O furo #14 registrava duas coisas: a gateira que conferia os `arquivo:linha` dos dossiês não lia o
que está nesses números, e os verificadores viviam em `.tools/` — pasta do `.gitignore`, portanto
inexistente no clone de quem chega. Saíram de lá e viraram
[`tools/check_doc_anchors.py`](../tools/check_doc_anchors.py), rastreável, com o contrato escrito no
cabeçalho do próprio arquivo. São **quatro classes objetivas**: arquivo que não existe, número
**fora do arquivo**, faixa **em branco** e — desde esta volta — **rótulo fora da definição ou do
corpo**. As três primeiras só sabiam se o número existia; a quarta confere uma afirmação que o
próprio link faz: um rótulo entre backticks, seguido do `#LNNN`, promete que aquela linha é aquele
símbolo, e o arquivo diz onde o símbolo vive. É a forma mais frequente de âncora do corpus, e era
a que passava com a linha cheia de texto e o número certo em cima de outra função. O que continua
fora da régua: a prosa livre que cita um número sem nomear símbolo — essa exige abrir o alvo e ler
contra a frase, e a docstring declara isso em vez de fingir um "docs ok". Roda com
`python tools/check_doc_anchors.py [pasta…]` e com `--ref <revisão>`, que confere os **documentos
de outra revisão contra o código desta** — é assim que o par abaixo é reproduzível e não memória. É
régua de documento, não de engine: não entra em gate de fase nenhum.

Corrida nesta árvore, depois da passada, e a mesma régua sobre os documentos exatamente como
estavam em `a6b83d7` (a revisão em que a passada começou), com os alvos lidos do disco:

```text
corpus em a6b83d7             arquivos: 32  ponteiros conferidos: 1579  rotulos conferidos: 86
casos objetivos: 82

corpus na arvore de trabalho  arquivos: 32  ponteiros conferidos: 1634  rotulos conferidos: 91
casos objetivos: 0
```

Os 82 se decompõem em **40 de posição** — 37 faixas em branco e 3 fora do arquivo — e **42 de
rótulo**: o nome citado não morava naquelas linhas. A contagem de ponteiros sobe de 1 579 para
1 634 porque número sem caminho na mesma linha não entra na conta de ninguém: a regra que esta
passada escreveu manda escrever o caminho por extenso em toda continuação, e cada caminho que
voltou é um ponteiro que passou a ser conferível — os 9 últimos são os que esta própria nota cita.
As classes que a passada consertou — cada alvo novo obtido abrindo a linha de definição no
arquivo, nunca somando um deslocamento:

- **`src/entities/wolf.gd` deslocado pela perna 10.** A função de simulação, a construção do
  blackboard, o processo de física, a varredura de rastros e a estatística da árvore saíram todas
  das linhas que os dossiês 01, 02, 04, 11, 12, 14 e as páginas de design citavam. Aqui entrou
  também o grupo que **já nasceu torto**: as duas linhas do `SubtreeGuard` eram apontadas como o
  orçamento de 400 µs do lobo quando são declaração de variáveis de estado — a construção com o
  número é outras duas linhas adiante, e o status foi corrigido nas três vezes que repete a
  afirmação (linhas 51, 87 e 371) e nos dossiês 04 e 11 e no `docs/design/08`.
- **`main.gd`, `hud.gd`, `mind_oracle.gd` e `tests/smoke_test.gd` deslocados pela perna 15**, com o
  mapa de faixas publicado na seção acima e as cinco âncoras que já estavam tortas na base
  `27800eb` — translação cega as deixaria tortas com número novo.
- **continuação mal resolvida.** Um `NNN` entre backticks, sem caminho, herda o último arquivo
  citado **na mesma linha**; se outro arquivo vem antes, o conferidor lê o número contra o vizinho
  errado. Três casos eram isso e a regra passou a ser escrever o caminho em toda âncora de
  continuação — nos dossiês 01, 04 e 07 há linhas que nesta saída passaram a citar o caminho por
  extenso justamente por isso.
- **prova vazia não se desloca.** As 11 faixas devolvidas em `cb09015` e os oito alvos do furo #17,
  cada um re-ancorado pela frase que o cita.
- **rótulo caindo fora da própria definição.** [`_temp`](../src/world/world_gen.gd#L57) estava
  apontado para a linha 34, que hoje é comentário; [`_build_visual()`](../src/entities/wolf.gd#L1448)
  para 885; [`_spawn_wolves`](../src/main.gd#L388-L428) para 259-275;
  [`load_state`](../src/entities/wolf.gd#L1376) para 701-736; [`take_damage`](../src/entities/wolf.gd#L1288)
  para 817. Nenhum desses dava "fora do arquivo" nem "em branco": linha com texto, número dentro, e
  a frase mentindo.
- **ponteiro de dossiê que descreve o estado lido ANTES da perna 10.** Em `a6b83d7` os dossiês 10 a
  14 tinham **39** ponteiros `wolf.gd` caindo na faixa 400–599, onde a perna escreveu as funções
  novas; hoje são **26**, e a faixa perdeu o valor de sinal justamente porque é ali que moram
  `_remember_scent` (`src/entities/wolf.gd:635`), `_leaf_wander` (`src/entities/wolf.gd:652`),
  `_shore_point` (`src/entities/wolf.gd:725`) e `_build_scorer` (`src/entities/wolf.gd:802`). Cada um dos que a passada abriu saiu com o número de hoje — a lista da matilha no
  blackboard e no contexto do escorredor (10), o `sim_step`, o `hunger` por `dt` e a razão
  `hp/MAX_HP` (11), a varredura de rastro de `7×7` citada duas vezes como se fosse o território
  (12), o débito do `Dictionary` por tick (13) e a escolha de solo seco (14). Os **26** restantes
  não foram re-afirmados um por um, e é neles que mora a maior parte do resíduo.
- **número de código citado como âncora de documento.** O censo travado do runner mudou de linha e
  de valor com as pernas 09 e 10, e o censo de cenários idem; os dossiês 02, 04, 14 e o índice de
  `docs/planos` citavam a linha e o valor de uma época anterior. Onde a frase é sobre a época, o
  número virou prosa ("na linha 20 do runner, com 150") em vez de ponteiro que a máquina resolve.

O resíduo, com o tamanho dele — é isto que separa "zero casos objetivos" de "citações conferidas":

- **semântica doc→código.** 1 634 ponteiros e 91 rótulos passaram pela régua objetiva e a régua
  humana continua sendo leitura: cada alvo **mudado** nesta passada foi aberto e lido, a massa
  antiga do corpus não foi re-afirmada por essa régua, e um ponteiro pode continuar dentro do
  arquivo e do corpo dizendo outra coisa que a frase não afirma.
- **semântica doc→doc.** Em `docs/planos/` há hoje **82** menções ao caminho completo do status —
  **72** delas com número de linha — e **101** ao do `AGENTS.md`, destas **40** com número. As 112
  ponteiros numerados passam pela régua de posição (alvo existe, linha não é branca, número está
  dentro do arquivo) e cada um dos que esta partida tocou foi conferido contra a frase. Os outros
  **71** alvos citados sem número não são conferíveis por instrumento nenhum: é aí que um número
  pode estar certo de posição e errado de sentido.
- **números de corrida.** Checagens (232, 236, 237, 239), µs de `sim_step` e ms de boot pertencem à
  revisão que os mediu. A régua da casa, escrita nesta nota: seção de **estado atual** recebe o
  número re-derivado, seção de **rodada histórica** conserva o que documenta — reescrevê-la
  apagaria o registro do commit que ela prova.
- **contagem por instrumento, não por memória.** O que sustentava a classe do rótulo era a lista
  impressa volta a volta, não um "docs ok": a suíte já contou 215 checagens em vez de 219 com o
  mesmo "0 falhas" (mandato 1), e uma régua que imprime só o total tem exatamente esse defeito.
  O par `--ref a6b83d7` / árvore de trabalho existe para que o antes e o depois de hoje sejam
  um comando, não esta nota.
- **o que a régua não alcança, medido.** Ela resolve caminho `src/`, `tests/` e `docs/` terminado
  em `.gd` ou `.md`. Fora desse alfabeto há hoje **32** ponteiros com número nos documentos —
  **28** para `.ps1` e **4** para `.bat` — e nenhum deles passa por nenhuma das quatro classes;
  `tools/` é citado **21** vezes, com ou sem número. Pior: o corpus ainda aponta **92** vezes para
  caminhos em `.tools/` — a pasta do `.gitignore`, portanto inexistente no clone de quem chega.
  São registros de corrida histórica, não promessa de arquivo, e é por isso que ficam: a régua não
  os vê, e esta nota os conta.

Nada disso fecha gate de fase. O HOT agregado dos cinco lobos continua por colher (dossiê 04, item 5
de "Falta"), e o instrumento entra na fila como o primeiro comando a rodar depois de qualquer
arquivo que cresce — que é o jeito de a régua não voltar a ser dívida.

## A `main` mergida da perna 15 (2026-11-21, ponta `3ae8e71`)

O merge — base `27800eb`, `feat/oraculo-embutido-no-boot-15` na ponta `3fccbb2`, `--no-ff`, merge
commit `3ae8e71` — rodou a suíte headless no checkout real da `main`, com a máquina livre, nenhum
processo do motor aberto e **nenhuma janela de jogo**: **246 checagens / 0 falhas / 38,2 s**, exit 0,
`SCRIPT ERROR` **0** nas duas correntes. O stderr publicado tem **250 bytes** e são os dois avisos de
término do motor (12 instâncias ObjectDB vazando e 4 recursos ainda em uso), **byte a byte o mesmo das
corridas da branch**: `merge-3ae8e71-suite-err.log` e `branch-suite-dono-unico-err.log` têm o mesmo
SHA-256 `6d256047…`. Os três arquivos desta corrida estão em `docs/evidence/oracle-embutido-15/`
(`merge-3ae8e71-suite.log`, `merge-3ae8e71-suite-err.log`, `merge-3ae8e71-anchors.log`) e no
`artifacts.sha256` ao lado.

A árvore do merge é a árvore da branch: `git diff --stat 3fccbb2 3ae8e71` é **vazio** e os dois hashes
de diretório coincidem — `src` = `854c4793cacb7c2a1ce82ddaf560e0bd4a285441`, `tests` =
`2f47fdc645307d1bdf6e90e998d11de76cd88f09`. A base `27800eb` continua
`c36ab6cd2380b3dc7d584b7b4ebbd009ec445b5a` / `03f8da29fce069ce25dac5ddad4fe49ce7bbb3e8`, os mesmos que
a nota da ponta `2bf0854` publicou: este merge não reescreveu nada da perna anterior.

O diagnóstico final dessa corrida fecha com `worst_sim_ms` **11,914** dos 50 ms do passo,
`dropped_ticks` **0**, `gen_ms` **991,3** e `mesh_ms` **4 539,0** — em tick 403. Continua sendo o boot
o caro, não o caminho quente. E o censo do fim de corrida é `wolves` = 4 com `pending_respawns` = 1
depois de a checagem do censo ter passado com 5 no ponto dela: estado conhecido desta suíte, não uma
recusa deste merge.

Na mesma ponta mergida o instrumento de âncoras passou de novo no checkout real e devolveu
**1 634 ponteiros conferidos, 91 rótulos, 0 casos objetivos**, exit 0 — os três números da seção
anterior, medidos depois do merge. A diferença para a rodada `2bf0854` é que a régua agora é arquivo
do repositório: `tools/check_doc_anchors.py` entrou versionado em `b86c360`, então quem chega por
clone limpo roda a mesma conferência, e é assim que o furo #14 deixa de ser dívida.

Nada disso fecha gate de fase. A perna 15 é o hospedeiro do modelo no boot; o próximo elo da fila
serializada era a 14 (convivência da alcateia), que fechou depois desta nota e hoje tem pin próprio
(`d4dee0f`), e o elo seguinte passou a ser a 11 (acasalamento, filhote que cresce e censo variável).
O HOT agregado dos cinco lobos continua por colher.

## A chave do oráculo sai do repositório (2026-11-21, ponta `f4ca1bb` em `fix/chave-do-oraculo-fora-do-git-15`)

**O furo tem duas camadas, e a segunda é a que doeu.** O scan de credenciais antes do push da perna 15
barrou o push: a chave do servidor local vivia como literal em três arquivos — o `const API_KEY` do
oráculo, o default do parâmetro no lançador PowerShell e a checagem da suíte, que imprimia as duas
pontas no log. Nada foi publicado no GitHub e a chave nunca saiu desta máquina, então não há
vazamento a registrar. O problema é de desenho: **(a)** o repositório é público, e uma "chave" que todo
clone lê não separa "o nosso servidor sobrou de um crash" de "um `llama-server` de terceiro na porta"
para quem chega de fora — era um imprint decorativo; **(b)** `_check_llm_key_drift` comparava o
literal do `.ps1` com o literal do `.gd`, ou seja, provava que os dois lados do *mesmo* repositório
concordavam. Uma checagem assim não pode falhar pelo motivo que importa, e é exatamente o tipo de
verde que o mandato 1 cobra: conforto, não régua. A decisão do dono em 2026-11-21 foi tirar a
credencial do git antes de publicar, e o que segue é o que ela custou.

**Resolução, não string.** `MindOracle.resolve_api_key()`
([mind_oracle.gd:265-287](../src/ai/mind_oracle.gd#L265-L287)) vale, nesta ordem, o ambiente
`AETHERFALL_MIND_KEY`, o arquivo `user://mind_key.txt` e, sem as duas fontes, 32 hex sorteados por
`Crypto.generate_random_bytes(16)` gravados no arquivo ([`:19-20`](../src/ai/mind_oracle.gd#L19-L20)
para as duas constantes, leitura em [:290-296](../src/ai/mind_oracle.gd#L290-L296), escrita em
`mind_oracle.gd:253-259` — linhas da árvore de antes do Passo 4, que encurtou o arquivo). A origem
fica nomeada em `key_source` — `ambiente`,
`arquivo`, `sorteada`, `sorteada-sem-gravar`, `sem-entropia` — porque gravação que falha tem de ser
estado visível e não chave silenciosa: sem arquivo, quem roda o lançador por fora não tem como bater a
mesma chave e o `401` que vem depois é dele. O lançador lê as **mesmas duas fontes** e recusa sem
nenhuma ([tools/run_mind_server.ps1:34-41](../tools/run_mind_server.ps1#L34-L41)). O host passou a
imprimir a linha de comando com `<chave>` no lugar do valor
(`llm_server_host.gd:310`, `_redacted` em `llm_server_host.gd:423-433` — aposentado no Passo 4 do
dossiê 22, commit 5138549): o imprint continua vivo no processo e fora do
log. A checagem da suíte ([smoke_test.gd:3148-3159](../tests/smoke_test.gd#L3148-L3159)) deixou de
conferir string e passou a conferir **fonte**: o `.ps1` nomeia `KEY_ENV`, nomeia `mind_key.txt`, nomeia
a pasta real do `user://` lida de `application/config/name`, tem `--api-key` na linha de comando, e a
chave resolvida pelo oráculo é não-vazia.

**Medido, por fonte.** Sondinha `SceneTree` (`extends SceneTree` + `resolve_api_key()` estático, sem
jogo aberto) nas quatro situações, na mesma revisão: com ambiente apontado e arquivo presente →
`origem=ambiente`, 28 chars, o ambiente vence; sem ambiente com arquivo → `origem=arquivo`, 32 chars;
sem ambiente e arquivo fora do caminho → `origem=sorteada`, 32 chars novos e o arquivo criado com 33
bytes (32 hex + `\n`); segunda execução depois do sorteio → `origem=arquivo` com o **mesmo** valor,
que é o que torna o lançador externo compatível. O bloco de resolução do `.ps1`, rodado sozinho,
devolveu `origem=arquivo  bytes=32  prefixo=6850` — o mesmo prefixo que a sondinha leu do arquivo
naquele momento. O arquivo de chave real do jogo foi copiado antes do teste e restaurado depois
(`cmp` idêntico); o sorteio nunca foi escrito no caminho definitivo fora deste teste.

**Verde da ponta.** Suíte headless em `0da1391`: **246 checagens / 0 falhas / 37,5 s**, exit 0,
**0** `SCRIPT ERROR` nas duas correntes, stderr de 250 bytes com SHA-256
`6d256047fb3a05293fbb83004eaf0f1183e6371544c030ef2200f9e8fe9cd9b0` — o mesmo hash da corrida da
`main` mergida `3ae8e71`, ou seja, o mesmo ruído de engine e nada novo. A linha da checagem reescrita
é `[PASS] chave do servidor bate com a do oraculo fontes_lidas=true pasta=Aetherfall origem=arquivo`.
Diagnóstico final: `worst_sim_ms` **13,797** dos 50 ms, `dropped_ticks` **0**, `gen_ms` **935,81**,
`mesh_ms` **4 358,2**, tick 403, `wolves` 4 com `pending_respawns` 1. Os três scripts tocados passaram
no `--check-only` com exit 0. Antes do verde houve um vermelho honesto: `Crypto.random_bytes` não
existe no 4.7 (o método é `generate_random_bytes`) e o `SCRIPT ERROR` derrubou a resolução em três
passos da suíte — o que só não virou "0 falhas" com contagem menor porque a checagem confere também a
chave resolvida, e foi assim que o erro apareceu em vez de virar sucesso silencioso.

**Âncoras e evidência.** O bloco de chave empurrou 15 linhas no `.ps1`, e os ponteiros `:11-15`,
`:19-20`, `:22-27`, `:30-37`, `:37`, `:22-24` e `:25-27` do dossiê 15 estavam caindo em comentário de
cabeçalho e em `param`: cada um foi lido no alvo e re-escrito contra a árvore atual
(`:19-21`, `:27-28`, `:43-48`, `:51-59`, `:58`, `:43-45`, `:46-48`), inclusive a frase que dizia "não
há `--api-key` na linha de comando de hoje" — hoje há, e sem literal. `python tools/check_doc_anchors.py`
na ponta: **1 634 ponteiros conferidos, 91 rótulos, 0 casos objetivos**, exit 0. Varredura separada
dos 36 ponteiros que apontam para os quatro arquivos tocados: nenhum alvo em branco e nenhum caindo
além do crescimento de fim de arquivo, o que é o motivo de os deslocamentos serem só no `.ps1`.
`git grep` do valor que a constante antiga tinha, sobre conteúdo rastreado, devolve **0 arquivos**. A máscara da
evidência (`a39005d`) troca as **27** ocorrências por `<chave-redactada>` em **15** arquivos — e o
número publicado aqui é o de ocorrências (`grep -ro | wc -l`), não o de linhas (`grep -c`, que dá
**21**): as duas grandezas se confundem fácil e a régua é a primeira.

**Fica aberto.** O mandamento 2 não mudou de natureza: a chave continua sendo imprint de localhost,
não segurança, e o tráfego é `127.0.0.1`. A quarentena de sugestões do oráculo segue por escrever. O
furo dos dois `.uid` órfãos (`tests/audio_test.gd.uid`, `tests/audio_live_probe.gd.uid`) continua
registrado acima e não foi tocado neste lote. Nada aqui fecha gate de fase.

## A `main` mergida da chave do oráculo (2026-11-21, ponta `f2823a8`)

A árvore do merge é a árvore da branch: `git diff --stat 1e24df1 f2823a8` é **vazio**, e o merge não
trouxe arquivo novo — por isso não houve `--import` antes da corrida.

Na `main` mergida, suíte headless: **246 checagens / 0 falhas / 37,1 s**, exit 0, **0** `SCRIPT ERROR`
nas duas correntes, stderr de 250 bytes com SHA-256 `6d256047…` — o mesmo hash das duas corridas
anteriores desta linha (a da `main` `3ae8e71` e a da ponta `0da1391`), o que é a assinatura de sempre
do engine, não um ruído novo. Diagnóstico final: `worst_sim_ms` **11,181** dos 50 ms, `dropped_ticks`
**0**, `gen_ms` **939,996**, `mesh_ms` **4 290,5**, tick 403, `wolves` 4 com `pending_respawns` 1. O
instrumento de âncoras na mesma ponta: **1 641 ponteiros, 91 rótulos, 0 casos objetivos**, exit 0 — os
sete ponteiros a mais são os que a seção anterior abriu, conferidos um a um no alvo.

Os três logs desta corrida estão em `docs/evidence/oracle-embutido-15/` (`merge-f2823a8-suite.log`,
`merge-f2823a8-suite-err.log`, `merge-f2823a8-anchors.log`) e no `artifacts.sha256`, agora com 42
entradas; `sha256sum -c artifacts.sha256` devolve OK em todas, e as 39 anteriores não mudaram de hash
— a máscara de `a39005d` continua sendo o conteúdo publicado daqueles arquivos. O que se conferiu
antes de arquivar: a chave viva desta máquina (`grep -o` do valor do arquivo) aparece **0** vezes nos
três logs, e não há nenhuma linha `--api-key` / `Bearer` no stdout, porque em headless o hospedeiro
não levanta. Ou seja: a evidência desta perna é publicável sem nada mascarar, que é exatamente a
diferença para a rodada anterior.

## Rodada Convivência 14 — terra seca, matilha legível e spawn fora dos olhos (2026-11-21, `feat/alcateia-convivio-14`, base `a898fb2`, ponta `6e35b64`)

### O que estava em aberto

As quatro regras do dono, autorizadas na extensão (2) do escopo, e o furo #16 da perna 10: a sessão
real nunca montou matilha de dois. Nada tinha sido lido ainda sobre quantos avisos de criatura
existiam, sobre o que as folhas de movimento escolhiam como alvo dentro d'água, ou sobre onde o
reposto punha um lobo.

### O que entrou (seis commits de código, um assunto cada)

| degrau | assunto | `src` | `tests` |
| --- | --- | --- | --- |
| `28afdda` | filtro de alvo depois da árvore — o lobo só nada sem saída seca | +21/−1 | +180/−1 |
| `5c3cde0` | travessia comprometida: o rumo de saída re-escolhe 4×/s, não todo passo | +41/−9 | +100/−2 |
| `b65066f` | assento de célula de rastro e lares em colunas diferentes | +28/−1 (`main.gd` +19/−2) | +206/−1 |
| `9fa8c6c` | spawn em bandas com recusa impressa | +91/−18 | +198/−28 (cinco arquivos) |
| `ba99bee` | política de aviso: nenhuma frase de criatura chega ao toast | +11/−4 | +131/−1 |
| `6e35b64` | mordaca de matilha no lar do recém-chegado | +41/−13 | +6/−6 |

A mecânica nova, pelo que roda hoje: o alvo escrito pela árvore é filtrado por
[`_resolve_dry_target()`](../src/entities/wolf.gd#L764-L768), chamado em
[:912](../src/entities/wolf.gd#L912) — depois dos 400 µs do `SubtreeGuard`, então a rondagem não
custou budget de BT; o rumo de saída da água é pedido por
[`_demand_shore()`](../src/entities/wolf.gd#L743-L754) na cadência do nariz e o resgate por tempo de
nado continua em [`SHORE_AFTER`](../src/entities/wolf.gd#L149), aplicado em
[:901](../src/entities/wolf.gd#L901); o lar sai de [`_spawn_home_point`](../src/main.gd#L788-L860)
sobre as [`SPAWN_BANDS`](../src/main.gd#L550) em torno da posição **atual** do jogador, passa pelo
predicado único [`_spawn_point_ok`](../src/main.gd#L762-L767) (≥ `SAFE_SPAWN_DIST` **e** visada
bloqueada) e, quando recusa, imprime o motivo em [`:846`](../src/main.gd#L846) em vez de cair no
centro; quem nasce por mordaca usa [`PACK_LEASH`](../src/main.gd#L559) = 18 m sobre o lar de um
irmão vivo. Os dois letreiros de criatura saíram; o contador de abate fica.

### A corrida que sustenta os números

Runner de reações: censo declarado [`EXPECTED_CHECKS`](../tests/aether_reactions_test.gd#L126)
**150 → 183** com **oito cenários novos** nomeados em
[:28-32](../tests/aether_reactions_test.gd#L28-L32). A suíte ficou em **246 checagens** do primeiro
ao último degrau — o degrau (f) mudou uma asserção
([`biggest >= 2`](../tests/smoke_test.gd#L399-L404)), não o censo. Irmãos verdes em todos os degraus:
áudio **73**, RNG **27**, journal **128**. Zero `SCRIPT ERROR` nos 47 logs arquivados.

- Base `a898fb2`: suíte `246 / 0 / 37,4 s`; runner `150 / 0`.
- Ponto mais carregado da escada: `246 / 0 / 37,6 s` (`e_smoke2`); clone limpo:
  **`246 / 0 / 37,0 s`** com `--import` frio exit 0.
- Boot por degrau: `gen_ms` 927,8–949,2, `mesh_ms` 4 225,5–4 621,7, `worst_sim_ms` 10,338–12,971,
  `dropped_ticks` **0** em todas. Nenhum arquivo desta perna encosta no mesher ou no gerador.
- µs do caminho quente: **não comparáveis entre degraus** — a janela do cenário estreito mudou de
  2 770 para 3 333 e depois 3 735 passos dentro da própria perna. Dentro da mesma janela (b→f) os
  cinco braços dão 1 009 298–1 044 201 µs e o pico de BT fica entre 175 e 217 µs dos 400 declarados,
  com `trips = 0` em todas as corridas, inclusive nas vermelhas. `[NAO GATE P1]`, como impresso no log.

Linhas literais de cada vermelho pago, e o verde do degrau seguinte, estão em
[`readback.md`](evidence/alcateia-convivio-14/readback.md) §2, com o corpus de 51 logs e
`artifacts.sha256` (51 entradas, `sha256sum -c` OK em todas) ao lado.

### O censo da sessão real — furo #16 pago

O boot de `f_smoke.log` e o do clone imprimem os mesmos cinco lares: **42,5 / 48,3 / 50,4 / 51,6 /
55,1 m** do jogador, `spawn RECUSADO:` **zero** vezes nos dois, `maior_matilha_lida=4` com
`lobos_vivos=5`. Jogo e suíte partilham `SEED := 20261116`
([`src/main.gd:25`](../src/main.gd#L25), [`tests/smoke_test.gd:10`](../tests/smoke_test.gd#L10)),
então são os mesmos cinco pontos do vale real. O que mudou o número não foi o raio de coesão: foi a
mordaca. E o que o dono pediu — "nada de avisos na tela, simplesmente o player tem que achar, ver" —
significa que um lobo a 42 m não se anuncia: o observável é o F3, uma linha por lobo
([`hud.gd:273-280`](../src/ui/hud.gd#L273-L280)).

### Furo #18 aberto por esta ponta

O caminho de recusa no boot existe, foi escrito nesta perna e **nenhuma corrida do corpus o exerceu**:
se `_spawn_home_point` recusar, a vaga vai para a fila em [main.gd:430](../src/main.gd#L430) e só
volta com `RESPAWN_DELAY` — e como a política de aviso é nenhuma frase de criatura na tela, um vale
com um lobo a menos fica silencioso. O predicado está provado; a recuperação depois de uma recusa no
primeiro tick, não. É débito de corrida, não de código.

### O instrumento de âncoras, com duas classes novas

`tools/check_doc_anchors.py` ganhou a **classe 6** — todo link relativo do corpus é resolvido pelo
caminho normalizado, e um ponteiro que não aterrissa em arquivo existe entra na lista. É a classe que
o `furo #14` tinha deixado de fora: um link `](oracle-embutido-15/readback.md)` escrito de
`docs/melhorias-status.md` não achava `evidence/` e a gateira só olhava `#LNN` de `.gd`. Span de
código inline é descartado antes do casamento, porque `` `[rótulo](alvo)` `` é exemplo de sintaxe,
não link. O corpus inteiro, medido na ponta `b7a0120` desta branch (`python tools/check_doc_anchors.py
--ref b7a0120`): **1 723 ponteiros, 117 rótulos, 1 623 links relativos, 0 casos objetivos**, exit 0. A
escada do corpus, no mesmo instrumento: `a898fb2` e `6e35b64` dão 1 641 / 95 / 1 542 com **99** casos
(as citações que a perna deixou velhas), `c4b48d1` dá 1 672 / 103 / 1 566 com **18** (as re-derivações
de (i), antes da nota da rodada) e `b7a0120` zera. O `readback.md` desta rodada, conferido por chamada
explícita no instrumento (a regra do furo #14 mantém `docs/evidence/` fora do corpus varrido, porque
prova pinada descreve a revisão em que foi medida): 24 ponteiros, 2 rótulos, 16 links, 0 casos.

### O que nada disso fecha

- **Nenhum gate de fase** (mandato 4). A perna pousou e está medida na `main` mergida
  (`d4dee0f`: **246 / 0 / 38,9 s**, §9 e §10 do readback), e nenhum número dela encerra P0 ou P1.
- HOT agregado dos cinco lobos continua sem medição; a colheita do runner é um lobo por cenário e o
  `SubtreeGuard` cronometra só a árvore.
- O `[OPEN]` de "como fica para quem não tem placa de vídeo" (extensão (3)) não é desta perna.
- Fica do lado de fora, e continua sendo a próxima da fila: acasalamento com filhote que cresce e
  censo variável (11), bicho cavando voxel (12), árvore genealógica (13).

## A `main` mergida da convivência (2026-11-21, ponta `e7e0a1f`)

`git merge --no-ff feat/alcateia-convivio-14` trouxe a perna inteira: 7 arquivos de `src`/`tests`
(`+1 028 / −42`), um de `tools/` (`+45 / −7`) e 72 de documentos, contrato e logs (`+10 361 / −668`),
80 ao todo. A árvore de código da `main` mergida é a árvore da ponta
da branch — `git rev-parse e7e0a1f:src 6e35b64:src` devolve o mesmo
`3eb42835a0e1f54086937d63258388f52e1db932`, idem `tests` (`8b8a5e471d737d6474eb6171bab6fdbeec75c06a`)
— então o clone limpo do §6 da evidência vale byte a byte para esta revisão, e o que se re-rodou aqui
foi a suíte, não a confiança.

Suíte headless em `e7e0a1f`: **246 checagens / 0 falhas / 39,8 s**, zero `SCRIPT ERROR` nas duas
correntes, stderr de 249 bytes com o par de sempre (8 ObjectDB + 4 resources). Os cinco lares do boot
são os mesmos valores da branch e do clone (48,3 / 50,4 / 42,5 / 55,1 / 51,6 m, linha
`spawn RECUSADO:` zero vezes) e `maior_matilha_lida=4`. Diagnóstico: `gen_ms` **949,919**,
`mesh_ms` **4 609,266**, `worst_sim_ms` **15,768**, `dropped_ticks` **0**.

O `worst_sim_ms` é o maior número da perna e é uma corrida só, não uma faixa. A re-corrida deste fecho,
na **mesma árvore de código**, deu **16,127** ms de pior passo com `gen_ms` 1 017,212 e `mesh_ms`
4 977,391 (§9 do readback): entre as duas, o delta de `src` e `tests` é zero, então o que as duas
medições dizem é o tamanho da variação desta máquina de corrida a corrida — maior que qualquer
delta que a convivência pudesse introduzir, e sem atribuir custo a sistema nenhum. Os degraus da escada
ficaram em 10,338–12,971 ms com a mesma janela de 20 Hz e nenhum tick perdido.

Instrumento de âncoras na ponta mergida, agora com corrida arquivada em
`merge-e7e0a1f-anchors.log`: o corpus pinado com `python tools/check_doc_anchors.py --ref e7e0a1f` dá
**1 723 ponteiros, 117 rótulos, 1 623 links relativos, 0 casos objetivos**, exit 0 — os três mesmos
números de `b7a0120`, e era isso que a merge tinha de devolver: `git rev-parse e7e0a1f^{tree}` e
`b7a0120^{tree}` são o mesmo objeto `f50f0aa0`, porque o que a merge trouxe além de `.gd` foi só `.md`
e `.log`. A leitura na árvore de trabalho deste fecho (a nota acima e o pin do README já dentro) é a
mesma, e é a seção 2 do log.

`artifacts.sha256` chegou a **50 entradas**: às 45 da branch somaram-se as duas correntes da suíte
mergida, o log das âncoras e as duas correntes da re-corrida do fecho. `sha256sum -c` dá OK nas 50 e
nenhuma das 45 anteriores mudou de hash. Antes de arquivar, os cinco foram varridos para conteúdo de
credencial: nenhuma linha `--api-key`, `Bearer` ou `sk-` com valor, porque em headless o hospedeiro do
modelo não levanta. O corpus, naquele fecho, era 50 `.log` + `readback.md` + os dois manifestos; a
entrada 51 é `registro-d4dee0f-anchors.log`, o log das âncoras do registro do pin.

A re-corrida do fecho (`fecho-suite.log`) é **verificação, não pin**: 246 checagens / 0 falhas /
38,9 s, exit 0, zero `SCRIPT ERROR`, os mesmos cinco lares e `spawn RECUSADO:` zero, com
`git rev-parse HEAD:src HEAD:tests` devolvendo os mesmos `3eb42835…` e `8b8a5e47…` da ponta de código
`6e35b64`. O pin do README saiu de `252f1e7` (239 / 0 / 38,4 s, perna 10) e nomeia `e7e0a1f` com
**246 / 0 / 39,8 s**. Nada aqui fecha gate de fase (mandato 4), e o furo #18 — a recusa de lar no boot
sem corrida própria — continua aberto do lado da corrida.

## O pin da convivência fica no fecho (2026-11-21, ponta `d4dee0f`)

O pin do README saiu de `e7e0a1f` e nomeia `d4dee0f`, a `main` do merge `--no-ff` de
`docs/fecho-convivio-14`. Não é corrida nova nem medição a mais: é o `fecho-suite.log` do §9 lido como
número do pin, e o que autoriza a leitura é o hash da árvore inteira — `git rev-parse d4dee0f^{tree}` e
`857c8e6^{tree}` são o mesmo objeto `45890848547997c1e6ecf3322851489af6fe7721`, porque o commit do
fecho já estava dentro da merge e o que ela trouxe sobre `e7e0a1f` são 10 arquivos de `.md` e `.log`
(`+873 / −47`), nenhum `.gd`. Em código as três pontas são uma só: `git rev-parse d4dee0f:src e7e0a1f:src
6e35b64:src` devolve `3eb42835a0e1f54086937d63258388f52e1db932` e idem `tests`
(`8b8a5e471d737d6474eb6171bab6fdbeec75c06a`).

O número registrado: **246 checagens / 0 falhas / 38,9 s**, exit 0, zero `SCRIPT ERROR` nas duas
correntes, `dropped_ticks` **0**, `gen_ms` **1 017,212**, `mesh_ms` **4 977,391**, `worst_sim_ms`
**16,127**, os cinco lares de sempre (48,3 / 50,4 / 42,5 / 55,1 / 51,6 m), `spawn RECUSADO:` zero vezes
e `maior_matilha_lida=4`. Esse `worst_sim_ms` é agora o maior da perna, e por 359 µs sobre o
**15,768** do `e7e0a1f` — duas corridas na mesma árvore, `dropped_ticks = 0` nelas duas, o que mede a
variação desta máquina e não atribui custo a sistema nenhum.

Publicação: `origin/main` estava em `a898fb2`, a base da branch, **11 commits** atrás da ponta local —
a perna inteira, código e evidência, ainda não tinha subido. O que publica é o push desta ponta, e a
prova continua sendo `git ls-remote --heads origin`, nunca o código de saída do push (memória do
repositório: o `origin` já apontou para o próprio repositório, de onde um push saía 0 sem publicar
nada).

## Rodada Docs 17/18 — a pauta dos dois prompts do dono, registrada antes do código (2026-11-21)

### O que estava em aberto

O dono mandou pôr em pauta o conteúdo de dois prompts seus, por escrito, e pediu que a pauta fosse de
agentes — não implementação deste bloco. Nada dos itens dele tinha página: **queda de blocos** (item A do
primeiro prompt, e do segundo) estava especificada no doc 10 e sem consumidor nenhum no código; **grama que
cresce** (B) e **mato decorativo** (C) nem especificação tinham. Havia também uma decisão dele sem número
de dossiê: espalhar a matilha em 2–3 tocas, depois de ele ter percorrido o mapa inteiro e visto um lobo só.

### O que entrou (dois arquivos novos, um por assunto, e o índice e o contrato atualizados)

- [`docs/planos/17-fisica-de-blocos-que-caem.md`](planos/17-fisica-de-blocos-que-caem.md): a premissa
  falsificável (um `SAND` sem apoio some num tick e reaparece mais baixo noutro, com `queued` voltando a
  zero e nenhuma varredura do mapa), o estado real lido — `block_changed` declarado em
  [`voxel_world.gd:6`](../src/world/voxel_world.gd#L6) e emitido em [`:336`](../src/world/voxel_world.gd#L336),
  com **zero** `.connect(` em `src/` e `tests/` — as sete checagens nomeadas e os sete commits atômicos na
  branch `feat/fisica-de-blocos-que-caem-17`;
- [`docs/planos/18-mundo-vivo-grama-e-mato.md`](planos/18-mundo-vivo-grama-e-mato.md): as duas premissas
  (A sem especificação nenhuma, escrita aqui pela primeira vez e portanto `[TARGET]`; B/C gastando o id 17
  e o tile 18 já prometidos no doc 10), o par vermelho `grama_precisa_de_vizinha`, o campo `substituivel`
  como único jeito de o mato não engolir o clique do `_try_place`
  ([`player.gd:702-703`](../src/entities/player.gd#L702-L703) só aceita `AIR`/`WATER`), e o riacho de RNG
  próprio para não derrubar `tests/simulation_rng_test.gd`;
- o índice [`docs/planos/README.md`](planos/README.md) passou de quinze para **dezessete** páginas, com as
  duas linhas novas nas duas tabelas e a fila serializada reescrita;
- [`AGENTS.md`](../AGENTS.md) ganhou a **Extensão de 2026-11-21**: os dois dossiês entram no "dentro", o
  número **16 fica reservado** às tocas (página ainda não escrita — e o 16 da fila não é o furo #16 do
  status, que a perna 14 já pagou), e a fila passa a **09 → 10 → 15 → 14 → 11 → 16 → 12 → 17 → 18 → 13**
  com o motivo de dados de cada elo. A consequência de versão está declarada antes do código:
  `Channel.COUNT` e `FORMAT_VERSION`
  ([`tick_journal.gd:4`](../src/persistence/tick_journal.gd#L4)) não são tocados, e uma corrida com areia
  caindo ou grama crescendo **não** reproduz os hashes das rodadas publicadas, porque o que muda é o mundo,
  não a projeção.

### A contagem conferida nesta ponta

`python .tools/verify_plan_cites.py docs/planos/*.md` sobre as dezessete páginas: **1 039 citações
conferidas nos dossiês** (as quinze antigas somam **935**; a 17 traz **54** e a 18 **50**), **0 números
fora do arquivo** e as mesmas **8** referências a arquivos inexistentes, todas peças declaradas como
inexistentes (`src/core/sim/tick_clock.gd`, `docs/engine/simclock.md`, `tests/wolf_multiseed_census_test.gd`)
— com esta página índice no corpus, o diretório dá **1 053**. Pelo `verify_plan_ids.py`, a 17 devolve
**98** identificadores em backticks, dos quais **38** não existem em `src/` nem em `tests/`, e a 18
**68**, dos quais **16**; cada ausente é checagem proposta, peça/flag/constante que o dossiê propõe ou
bloco que o doc 10 numera e o registro não tem — nenhuma virou fato. Os três governantes, medidos nesta
árvore com estes dois arquivos em cima: **113 · 0 · 416 = 529** números (`AGENTS.md` 113, `README.md` da
raiz 0, este status 416), 0 fora do arquivo. Na primeira medida desta ponta o status dava **412**, e os
quatro números que ele ganhou são exatamente as quatro âncoras que a seção acima escreveu.

### O que nada disso fecha

Nenhum gate de fase (mandato 4) e nenhuma linha de código: as duas pernas ainda não abriram branch, e
nenhuma das peças nomeadas (`BlockUpdateQueue`, `FallingBlock`, `PLANT`, `substituivel`) existe. O que a
rodada entrega é a pauta com premissa, custo e gate escritos contra o código de hoje — e a proibição de
varredura global, que é o ponto dos dois prompts que o código ainda não tem como garantir.

## Rodada Auto-pulo 19 — o degrau de um bloco, medido nos dois corpos e no frame real (2026-11-21, `feat/auto-pulo-de-bloco-19`, base `8ac761d`, ponta de código `f843fa6`, merge `a518487`)

### O que estava em aberto

O dono trouxe um defeito que dói a cada sessão dele, não uma mecânica: "os mobs/npcs tem que saber
pular os blocos, pois ficam bugados e aqui tbm fazer quando estou andando, ter um auto pular o
bloco". Nada no repositório respondia a isso. Lido antes de escrever (regra 1 do ciclo), o "bugado"
tem **três** causas e nenhuma é pathfinding: `step_up = 0,62` m
([voxel_body.gd:19](../src/entities/voxel_body.gd#L19)) contra uma célula de 1,00 m; o ápice do
impulso de escape do lobo, 5,2 m/s com gravidade 24 → **0,563 m**, ou 44 % do bloco; e
`blocked_horizontal` com **um** leitor em `src/` — o lobo, na própria linha de locomovência. O corpo
do jogador escreve a flag e ninguém a lê, por isso ele tem salto manual suficiente e mesmo assim
para na frente do degrau. O registro veio antes da linha (mandato 4): o
[dossiê 19](planos/19-auto-pulo-de-bloco.md) nomeia a premissa, o estado real com `arquivo:linha`,
as sete checagens de headless e os cinco commits atômicos, e a exceção de ordem está na seção
"Em andamento" acima.

### O que entrou (oito commits, um assunto cada)

| Commit | Assunto | O que ele mediu |
| --- | --- | --- |
| `a534e23` | dossiê + exceção de fila | suíte 246 / 0 / 37,4 s na árvore dos dezoito dossiês |
| `c313544` | `can_step_over` no integrador | cinco braços na grade; runner **183 → 189** / 0 / 9,338 s |
| `c0659fd` | lobo: `STEP_JUMP` + gate | vermelho 20 s / verde 2,1 s; runner **192** / 0 / 9,374 s |
| `2a20843` | jogador: auto-pulo no buffer da tecla | vermelho 300 frames / verde 114; runner **195** / 0 / 8,858 s |
| `f843fa6` | custo colhido no frame real | braços plano × face; runner **198** / 0 / 11,656 s, suíte 246 / 0 / 37,2 s |
| `1e1f792` | instrumento: ponteiro com SHA não é ponteiro vivo | classe (c) corrigida e coberta; corpus inalterado |
| `acb7970` | re-derivação das citações | 49 casos adjudicados um a um; corpus **0** casos, exit 0 |
| `a1143b0` | fecho documentado | clone limpo medido; logs e `artifacts.sha256` arquivados |

Duas receitas escritas no dossiê caíram antes do código, pela régua da grade: a **margem de 0,05**
(o pé apoiado nunca fica abaixo da face do solo, e 0,05 custaria ao lobo de 0,95 a própria célula em
que ele cabe) e o **vão de 0,95 m** (não existe meio bloco: o vão é de uma célula e a resposta passa
a depender da altura do corpo). Corrigido também o comando do gate do dossiê: sem `--script res://`
o `.gd` é lido como cena e a engine abre o jogo headless e não sai.

### A corrida que sustenta os números

Tudo abaixo é headless, máquina livre, medição serial (nenhum gate de timing roda com outra carga).
Na ponta de código `f843fa6`: runner de reações **198 checagens / 0 falhas / 11,656 s**, suíte
**246 checagens / 0 falhas / 37,2 s**, exit 0 nos dois, zero `SCRIPT ERROR` nas duas correntes. O
número do pin — clone limpo reimportado com `--import` e o SHA no README — só existe depois do merge,
e é o que a seção de fecho publica; nada aqui se chama de pin.

### O fecho: merge, clone limpo e pin

O merge `--no-ff` da branch `feat/auto-pulo-de-bloco-19` é `a518487` (ponta de documento
`acb7970` sobre a ponta de código `f843fa6`), e o merge `--no-ff` do fecho
`docs/fecho-auto-pulo-19` é `ab9ffa1` — a `main` publicada. Medido de novo na árvore mergeada e
num clone limpo de `a518487`, reimportado com `--import` frio:

| Corrida | Revisão | Suíte | Runner de reações |
| --- | --- | --- | --- |
| branch, ponta de documento | `acb7970` | **246 / 0 / 39,7 s** | **198 / 0 / 12,897 s** |
| `main` mergeada do código | `a518487` | **246 / 0 / 39,5 s** | — |
| clone limpo | `a518487` | **246 / 0 / 39,6 s** | **198 / 0 / 12,870 s** |
| `main` mergeada do fecho | `ab9ffa1` | **246 / 0 / 39,5 s** | — |

Exit 0 nas quatro suítes e nos dois runners, zero `SCRIPT ERROR` em stdout e stderr. Os logs e o
`artifacts.sha256` estão em [docs/evidence/auto-pulo-19](evidence/auto-pulo-19/readback.md), e o
README fixa `ab9ffa1` como pin: `ab9ffa1:src` e `ab9ffa1:tests` são os mesmos objetos de
`a518487:src` e `a518487:tests` (`45efe977f74de…` e `37eb429c142d…`), porque o fecho trouxe `.md` e
`.log` e nenhum `.gd` — a corrida do clone é a corrida do pin. A árvore de código do pin muda em
`src` e `tests` pela primeira vez desde o pin da perna 14 (`3eb42835a0e1f…` → `45efe977f74de…` em
`src`, `8b8a5e471d737…` → `37eb429c142d…` em `tests`), porque a perna toca três `.gd` de corpo e o
runner.

Um achado de fecho, medido e não atribuído: o par `ObjectDB instances were leaked` / `resources
still in use` **não** sai na primeira corrida do clone (stderr de 0 bytes) e sai na segunda, no
mesmo clone e com o mesmo comando — o que o par acompanha é o diretório de dados `user://`, não a
árvore.

### Os braços vermelhos e verdes

- **Predicado (cinco braços na grade, pé onde o integrador para o corpo, nada encaixado):** degrau
  de um bloco `true/true`; muro de dois `false/false`; degrau com teto a uma célula do parapeito
  `true` para o lobo e `false` para o jogador de 1,80; penhasco de seis `false/false`; direção zero
  `false`. O alcance sai do corpo porque o bloco começa na face da caixa, não no pé.
- **Lobo — vermelho reproduzido antes do conserto:** 20 s encostado, `x_max=55,625`,
  **31 lançamentos**, do lado de cá. **Verde:** `ganho=1,140 m`, `x_max=58,103`, **1 lançamento**,
  2,1 s. **Indiferença (o outro lado do mesmo palco):** contra o muro de seis blocos,
  `rearms=12 lancamentos=0` — a asserção era `lancamentos > 0` e **virou** `rearms > 0 and
  lancamentos == 0`, porque saltar contra um penhasco de 6 m é só perder altura. O lançamento passou
  a ser lido como subida (`_launched`: `vy` acima do frame anterior e `> 0`), não como limiar — com
  7,6, o limiar `vy > 5,0` contaria sete frames por salto.
- **Jogador — vermelho por ablação** (um toggle de runtime, nenhum arquivo de gameplay editado): com
  a chamada desligada e o `InputMap` já instalado, o corpo anda até a face e para —
  `y_max=51,001 ganho=-0,000 m x_max=55,677 lancamentos=0 frames=300`, e a premissa continua verde
  porque o degrau é legítimo (`na_face=1 predicado=true`): falta o lançamento, não o chão. **Verde,
  mesmo palco, tecla solta:** `y_max=52,334 ganho=1,333 m lancamentos=1 frames=114` (1,9 s).
  **Recusa:** agachado encosta no **mesmo** degrau que o predicado aprova e não sai do lugar —
  `na_face=191 predicado=true y_max=51,001 lancamentos=0`.
- **Custo (colheita antes do corte; os dois braços rodam os mesmos 1 000 frames pelo caminho do
  jogo):** plano `pior frame 11 302 µs / média 1 386,8 µs / worst_sim 11,16 ms / dropped 0`; face
  (o pior caso que existe: degrau com teto a uma célula do parapeito, onde o predicado é perguntado
  em todo frame de bloqueio e responde "não") `8 694 µs / 1 387,7 µs / 8,62 ms / dropped 0`, com
  **982 frames encostado e `lancamentos=0`**. A **média** é o que atribui: 0,9 µs de diferença entre
  um braço que nunca pergunta e um que pergunta 982 vezes. O `worst_sim` inverteu entre os braços
  (11,16 × 8,62) porque a máquina não é constante — é por isso que o gate do dossiê 17 (25 ms) vale
  dentro de cada braço, e nenhum ranking de tempo absoluto decide nada aqui. A virada do corredor é
  por **banda** (78/46), não por frame: medir só a coordenada prendia o jogador no limiar com o yaw
  trocando de sinal a cada frame — medido, **869 viradas** em 1 000 frames num braço que dizia
  "andando".

### O censo 183 → 198 e o que cada elo do salto é

`EXPECTED_CHECKS` ([aether_reactions_test.gd:64](../tests/aether_reactions_test.gd#L64)) passou de
183 para 189 (`c313544`), 192 (`c0659fd`), 195 (`2a20843`) e 198 (`f843fa6`), conferido a cada
corrida em [:3130](../tests/aether_reactions_test.gd#L3167). A suíte de 246 não se moveu: as
checagens novas são do runner, não do smoke. O `189` ganhou três além do degrau, e uma delas é um
defeito de premissa **achado por este lote**: o cenário do spawn agora mata o jogador (os lobos
alcançam a plataforma), e como a suíte roda uma vez, o teste de feedback herdava um corpo morto —
`update_local` devolve cedo em morto sem chamar `_update_target`, `_try_place` sai em
`not target_valid` e o letreiro de "slot vazio" virava o do craft. Entrou a transição real
(`respawn_at`) mais uma checagem de premissa com o número que a decide: `d=2,15/5,5 m`,
`voxel=(64,50,63)`. E o runner precisou chamar `InputActions.install()` no fixture: o mapa de ação é
montado só pelo boot ([main.gd:140](../src/main.gd#L140)), então sob `--script` o `move_forward` não
existia e o jogador nunca andava — efeito colateral medido, as **15** linhas
`ERROR: The InputMap action "..." doesn't exist` que a suíte já imprimia por checagem de input
calaram. Isso é conserto de causa, não silenciamento: o erro era o próprio sintoma.

### Re-derivações desta rodada

A régua versionada deu o par antes/depois com os mesmos documentos lidos contra a mesma árvore de
código: na base `8ac761d` eram **34 arquivos / 1 835 ponteiros / 131 rótulos / 1 791 links /
53 casos objetivos, exit 1** (25 BRANCO + 28 ROTULO-FORA-DO-CORPO, em 12 documentos: 19 dentro deste
arquivo, 11 no dossiê 10, 7 no 13, 3+3 nos 11 e 12, 2 cada nos 04/09/18, 1 cada nos 02/03/08/14);
nesta ponta, **35 arquivos / 1 903 ponteiros / 131 rótulos / 1 866 links / 0 casos, exit 0**. Os
53 casos da base estavam em 12 documentos: **19 dentro deste arquivo**, 11 no dossiê 10, 7 no 13,
3 no 11 e 3 no 12, 2 no 04, 2 no 09 e 2 no 18, 1 no 02, 1 no 03, 1 no 08 e 1 no 14. O arquivo a mais
é a página 19, que a régua confere com **29** ponteiros próprios; **16** dos 68 ponteiros a mais são
a tabela de controles do [doc 09](design/09-veloren-mechanics-adaptation.md), que era citação muda e
passou a ter `#L` (44 → 60 ocorrências), e os **23** restantes são as re-ancoragens desta passada
neste arquivo e nos dossiês 05/06/07/08/15 e no índice. Contado por outro instrumento, descartável como
esta régua (`.tools/count_moved_numbers.py`: a diferença de multiconjuntos dos números de ponteiro entre
as linhas removidas e adicionadas do diff `8ac761d→árvore de trabalho`, fora o próprio status), a passada
moveu **493 números que saíram e 542 que entraram em 24 documentos**, com `saíram == entraram` em **18**
deles — os seis que não fecham são justamente onde esta passada escreveu frase além do número: a página 19
(0 → 34, é ela que nasceu), o índice (3 → 11), 07 (14 → 18), 08 (32 → 34), 13 (27 → 25) e 15 (3 → 6). Nos
dezoito que fecham, o que entrou é **re-ancoragem**, não prosa — é o critério que separa esta passada de
um lote de texto novo. As três classes fora da régua, com a raiz de `.md` no conjunto de resolução, deram
**843** curtas conferidas, **260** soltos com doador e **49** casos — um por um: 23 artefatos da régua, 15
registros e 11 podres, todos em arquivos que esta perna não tocou; a lista dos doze está no furo #19
acima, e um deles era deste arquivo — a coluna "agora" da tabela das cinco âncoras tortas — e foi
consertado aqui, o que é o motivo de 11 e não 12. O #18 é o outro registro novo desta passada: a recusa
de lar nunca foi exercida por nenhuma corrida, nem pelo teste que dizia exercitá-la (`recusados=0`).

O critério que fez a passada ser **por conteúdo** e não por delta: esta perna não toca em
`src/main.gd` nem em `src/world/aether_field.gd` (diff `BASE→HEAD` vazio nos dois), então todo
ponteiro errado que ela achou nesses arquivos já estava errado **antes** da perna. Transladar pelos
+N deslocaria a podridão com aparência de atualizado — é a regra 6 do ciclo lida ao contrário. Por
isso [planos/01](planos/01-estado-inicial-e-ordem-autoritativa.md) teve **46 números em 16 linhas**
re-ancorados abrindo o alvo (as duas portas da matilha, `save_game()`, `load_game`, `_benches`, o
comentário do hash e os quatro doadores soltos da tabela de quem escreve, entre outros), e os registros
que afirmam o que **uma revisão passada leu** ficaram como texto, não como link: é o precedente desta
casa, e o motivo pelo qual as linhas de auditoria deste arquivo e o item de `planos/07` que declara os
quatro ponteiros fora de posição já em `f843fa6` mantiveram números que a régua chamaria de velhos.

### O que nada disso fecha

Nenhum gate de fase (mandato 4). O auto-pulo é o fim de um defeito em execução, não um slice novo:
ele não aproxima P1, não conta no agregado HOT dos cinco lobos e não valida o `HotSet` do §04/§06. O
que fica explicitamente de fora, lido e escrito no dossiê: a **altura do vão continua uma célula** —
um bloco e meio ainda é parede para os dois corpos — e o jogador **não** sobe escada por predição,
ele sobe a célula que o integrador já disse que existe onde ficar de pé. O custo de alocação do
caminho quente continua sem medição própria, e o débito de `main.gd` como objeto de Deus também:
esta perna escreveu em `voxel_body.gd`, `player.gd`, `wolf.gd` e no runner, e **nenhuma linha** em
`src/main.gd`.

## Rodada Acasalamento 11 — o filhote que nasce, cresce e vai para o disco (2026-11-21, `feat/acasalamento-e-censo-11`, base `e7a5fe7`, ponta de código `0762b43`, merge `4b858c2`)

### O que estava em aberto

O item 10 da fila, e o motivo do dono na conversa: "tem algo que não tem no Minecraft: eles
acasalam e aparece um filhote e depois cresce". A leitura do dossiê
([`planos/11`](planos/11-acasalamento-filhote-e-censo.md)) achou quatro ausências e uma delas era
silenciosa: a população era uma constante (`WOLF_COUNT := 5`), não existia idade, filhote nem corpo
menor, e o load pareava **por índice** com teto — `for i in mini(saved.size(), wolves.size())` —, de
modo que um censo que crescesse **descartaria filhote em silêncio**. Um save com 7 lobos carregava
5, e os 2 que sumiam eram os novos. Era esse o vermelho que a premissa pedia: uma checagem que
**nasce vermelha** no código da leitura.

### O que entrou (sete commits de código, um assunto cada, e a `main` do auto-pulo entrando)

| Commit | Assunto |
| --- | --- |
| `0850548` | (a) fase do lobo, corpo por fase e crescimento por tick de simulação |
| `52ed86a` | (b) fase e idade vão para o disco, e o censo gravado **nasce vermelho** |
| `8ceee57` | (c) o load pareia por identidade e o censo do disco é a autoridade |
| `c1ea3f9` | (d) a roda de acasalamento cria, o cooldown trava e o teto recusa contado |
| `3e8f9ba` | (e) o filhote fica fora da caçada e o cerco não ganha assento vazio |
| `f33c1d4` | o comentário do `state_dict` deixa de dizer "ainda por medir" |
| `fe2fb6d` | (f) o lote novo **não move** o hash do tick, e a decisão do `FORMAT_VERSION` fica escrita |
| `010ab25` | merge da `main` (`e7a5fe7`) dentro da branch — a perna escreve os mesmos dois arquivos que a 19 |
| `0762b43` | (g) o corpus re-derivado pela ponta da perna, com a prosa do status, do contrato e da página |

O que o código faz hoje, lido: fase, idade e cooldown são chaves do registro do animal
([`wolf.gd:1372`](../src/entities/wolf.gd#L1372)) e `Phase { CUB, JUVENILE, ADULT }` é estado real
([`wolf.gd:78`](../src/entities/wolf.gd#L78)); o censo tem teto próprio e a recusa é **impressa**,
não truncada em silêncio (`CENSUS_CAP := 12`,
[`main.gd:18`](../src/main.gd#L18), a recusa em
[`main.gd:529-532`](../src/main.gd#L529-L532)); e o load pareia **por identidade** — o bicho do disco
que a sessão não tem entra no mundo, o bicho da sessão que o disco não tem é aposentado, e a fila de
reposição é limpa para o censo gravado mandar
([`main.gd:1188-1224`](../src/main.gd#L1188-L1224)). O dono do nascimento é a **sessão**
(`_born_from`, [`main.gd:526`](../src/main.gd#L526)), nunca o próprio lobo: rodando no lobo o spawn
teria dois donos e o filhote nasceria dentro da iteração sobre a lista que ele está mudando.

### A corrida que sustenta os números

O pin publicado é **`5b519f8`**, o merge `--no-ff` do fecho da perna 11
(`docs/fecho-acasalamento-censo-11`) sobre `4b858c2`, o merge `--no-ff` da branch sobre a base
`e7a5fe7`. O fecho trouxe `.md` e `.log` e nenhum `.gd`, então `5b519f8:src` e `5b519f8:tests`
são os mesmos objetos de `4b858c2:src` e `4b858c2:tests`
(`30873d664a9577bcd3e709046cc708923456c372` e `975eac5a471dc1e064441474ef6e13866076d34f`) — a
corrida do clone limpo e a corrida do pin são a mesma corrida. Medido no clone limpo de
`4b858c2` — sem `.godot/`, com `--import` frio **exit 0**:

| Corrida | Resultado |
| --- | --- |
| clone limpo, suíte (1ª) | **252 checagens / 0 falhas / 42,9 s**, exit 0 |
| clone limpo, suíte (2ª, mesmo clone, mesmo comando) | **252 / 0 / 42,9 s**, exit 0 |
| clone limpo, runner de reações | **225 / 0 / 15,451 s**, exit 0 |
| clone limpo, teste do journal | **128 / 0 / 5,811 s**, exit 0 |
| `main` mergeada do código (`4b858c2`), suíte | **252 / 0 / 43,1 s**, exit 0 |
| `main` do fecho (`5b519f8`), suíte | **252 / 0 / 43,0 s**, exit 0 |
| `main` do fecho (`5b519f8`), runner de reações | **225 / 0 / 15,348 s**, exit 0 |
| `main` do fecho (`5b519f8`), teste do journal | **128 / 0 / 5,769 s**, exit 0 |
| branch, suíte | **252 / 0 / 43,0 s**, exit 0 |
| branch, runner de reações | **225 / 0 / 15,343 s**, exit 0 |

O censo do runner é `EXPECTED_CHECKS = 225`
([`aether_reactions_test.gd:64`](../tests/aether_reactions_test.gd#L64)) e o da suíte é **252**. O
diagnóstico final confere dígito a dígito entre a `main` mergeada e o clone: `births` **2**,
`census_cap` **12**, `census_refusals` **0**, `wolves` **7**, `wolves_alive` **7**, `chunks` **64**,
`meshes` **147**, `triangles` **214 480**, `edits` **13**, `pack_pairs` **21**, `pending_respawns` **1**,
`load_created` **0**, `load_retired` **0**, `dropped_ticks` **0**. Só os tempos de boot e de passo se
movem, como sempre: `gen_ms` 993,754 → 980,145, `mesh_ms` 4 414,338 → 4 428,196 e `worst_sim_ms`
11,629 → 13,684 — média e pico são corrida, não faixa. Logs, `artifacts.sha256` e a receita do clone
estão em [`evidence/acasalamento-censo-11/readback.md`](evidence/acasalamento-censo-11/readback.md).

O journal **não se moveu**: fase, idade e cooldown são chave de registro do animal no disco, não
campo da projeção mínima do `TickJournal`
([`tick_journal.gd:16-44`](../src/persistence/tick_journal.gd#L16-L44)), então `FORMAT_VERSION`
continua **1** ([`tick_journal.gd:4`](../src/persistence/tick_journal.gd#L4)) e os hashes publicados
das rodadas anteriores valem. A checagem 7 fecha nos dois sentidos — o hash **igual** depois do lote
e **diferente** quando muda o que está na projeção.

### O par de vazamento do quit: ele precede esta perna

O stderr das três corridas de suíte (ponta, `main` mergeada e **primeira** corrida do clone) traz
`4 ObjectDB` com `2 resources`; a **segunda** corrida do mesmo clone, mesmo comando, mesma árvore,
**não** traz (stderr de **0** bytes). Com `--verbose` o objeto é nomeado: `AudioStreamPlaybackOggVorbis`
e `AudioStreamOggVorbis` de `res://assets/audio/amb/amb_birds.ogg`, vivos no instante em que o
processo morre. O braço de controle — a mesma corrida na `main` **sem** esta perna (`e7a5fe7`) — dá
o **mesmo** par, **maior**: **16 ObjectDB** com **6 resources**, com o mesmo arquivo de som. Logo ele
**precede** a perna 11 e não é dela; e o que ele acompanha é a ambiência de pássaros ainda tocando na
saída, que é o débito já medido e escrito na seção "Débitos" deste arquivo, com a sonda de seis
braços que mostrou que `stop()` no mesmo tick não resolve e que `stop()` seguido de mais 20 frames
limpa. Isso corrige a hipótese da leitura de retorno da perna 19, que atribuía o par ao diretório
`user://`: o par não acompanha o diretório, acompanha a ambiência tocando.

### O vermelho intermitente do runner também não é desta perna

A checagem "nenhum estouro de subtree no budget" é a que falha intermitentemente, e a atribuição
fecha nos dois sentidos: o braço de controle — quinze corridas do runner na `main` **sem** esta perna
— deu o mesmo vermelho **uma** vez, com a mesma assinatura (`trips` no cenário estreito ou no de
matilha); as três corridas com a máquina carregada deram vermelho em **duas**, e a carga está
registrada segundo a segundo; com a máquina livre e as corridas em série, **nenhuma** falha; e o
desvio de I/O não muda nada — seis pares de arquivo × pipe deram o mesmo `trips` com o mesmo formato.
A leitura é a que o furo #20 já registra: o `SubtreeGuard` cronometra **parede de relógio**, e
GDScript não tem relógio de CPU, então `trips == 0` é um portão de velocidade de máquina, não um
portão de código. Nenhuma linha de código mudou por causa disso.

### O que nada disso fecha

Nenhum gate de fase (mandato 4). Ecologia de verdade — presa, fome populacional, migração, espécies
— é P2 e continua `[TARGET]`; aqui entra um predador que se reproduz e envelhece, com censo no disco.
O multi-semente (02) e o budget agregado (04) continuam abertos, e um censo variável **aumenta** a
dívida dos dois: o `SubtreeGuard` mede 400 µs **por lobo**, e o teto de censo é 12. O custo de
alocação do caminho quente continua sem medição própria. A perna seguinte da fila é a **16** (as
tocas do dono), que precisa do censo variável desta perna para decidir quantas alimentam.

## Rodada Docs 16 — a pauta das tocas, escrita antes de a branch abrir (2026-11-22, `docs/tocas-da-alcateia-16`)

### O que estava em aberto

O dono pediu em 2026-11-21, por escrito, que a matilha fosse espalhada em **2–3 tocas**, depois de ter
percorrido o mapa inteiro e visto **um lobo só**. O número **16 ficou reservado** àquela decisão, mas
a página não existia — a reserva vivia numa frase da extensão, sem premissa, sem custo e sem gate. A
fila serializada já a punha no lugar (**09 → 10 → 15 → 14 → 11 → 19 → 16 → 12 → 17 → 18 → 13**), a
perna 11 tinha pousado com o pin publicado, e 12, 17, 18 e 13 estão atrás dela.

### O que entrou (um arquivo novo, três documentos de pauta atualizados, nenhuma linha de código)

- [`docs/planos/16-tocas-da-alcateia.md`](planos/16-tocas-da-alcateia.md): a premissa falsificável —
  **a matilha nasce, reproduz e é reposta dentro de um único círculo de 18 m de raio, e a caixa útil é
  116 × 116 m** — decidida por **componentes conexos do grafo de coesão** lidos por `pack_of()`, não
  por contagem de pares; o estado real lido na árvore daquele dia (`99d1167`, com `PACK_LEASH = 18.0`
  ([`main.gd:584`](../src/main.gd#L584)) como primeira tentativa de cada lar
  ([`:757`](../src/main.gd#L819)), `_pack_leash()` devolvendo o lar do **primeiro** irmão vivo
  (`99d1167:src/main.gd:501-505`, função apagada pela perna 16), o clamp `6 … W-6` sobre o mundo de 128
  ([`:776-777`](../src/main.gd#L838-L839))); a regra de colocação (§3.2), que é **lugar**, não
  comportamento — a pertença só muda o que o sorteio e o parto escrevem, e um `if den == 2` em
  `wolf.gd` é sinal de lote errado; o fork **A/B decidido por medição** (§3.4), registrado antes do
  código porque o braço B custa re-derivar uma checagem já gateada da perna 10
  ([`tests/aether_reactions_test.gd:2112-2115`](../tests/aether_reactions_test.gd#L2112-L2115)) e entra
  **só** se o braço A ficar vermelho; dez checagens nomeadas no §5, das quais `tocas_distintas_no_boot`
  nasce **vermelha** e `esgotamento_de_lares_forcado` paga o furo #18 desta mesma seção;
- o índice [`docs/planos/README.md`](planos/README.md) passou de dezoito para **dezenove** páginas, com
  a linha 16 nas duas tabelas, a reserva levantada no texto e o nome da branch de código (`feat/…-16`)
  registrado com a nota de que **a página existe e a branch não**;
- [`AGENTS.md`](../AGENTS.md) ganhou o **registro de 2026-11-22**: é levantamento de reserva, **não**
  autorização nova; a fila não se move; e a declaração de versão continua a mesma — nada deste lote
  encosta em `Channel.COUNT`, `FORMAT_VERSION` nem `GEN_VERSION`, e nenhuma linha de código foi escrita;
- este status ganhou o **furo #21** (a cláusula `pack_pairs == n(n-1)/2` do gate de alcateia
  ([`smoke_test.gd:399-404`](../tests/smoke_test.gd#L399-L404)) é verdadeira por construção, porque o
  contador incrementa **antes** do teste de raio em [`main.gd:949-950`](../src/main.gd#L949-L950)) e o
  dono fixado do **furo #18** (a perna 16, pelo item 8 do §5 do dossiê, não mais "16 ou 11").

### A contagem conferida nesta ponta

`python .tools/verify_plan_cites.py docs/planos/<cada>.md` sobre as **dezenove** páginas: **1 200
citações com número de linha conferidas, 0 números fora do arquivo**, elo a elo
**71 · 50 · 25 · 75 · 70 · 34 · 51 · 55 · 39 · 77 · 80 · 53 · 110 · 68 · 115 · 94 · 54 · 50 · 29** na
ordem da tabela — a página 16 traz **94** delas. Com a página índice no corpus, o diretório dá
**1 215**. As ausências de arquivo são **9**, todas peças já declaradas como inexistentes (`tick_clock.gd`
em 01 e 06, `simclock.md` em 03, 07 e índice, `wolf_multiseed_census_test.gd` em 02 e índice, e as duas
peças do dossiê 15 no índice) — nenhuma virou fato. Pelo `verify_plan_ids.py`, a página 16 devolve **88**
identificadores em backticks, dos quais **22** não existem em `src/` nem em `tests/`: **10** nomes de
checagem proposta, **8** peças/constantes/flags que o dossiê propõe (`DEN_COUNT`, `DEN_MIN_DIST`,
`den_components`, `den_min_dist`, `home_of`, `pack_id` e afins), `PLANT` (o bloco que o doc 10 numera e
a perna 18 é quem gasta), **2** nomes de arquivo real que a gateira lê como identificador
(`fp_viewmodel`, `player_avatar`) e **1** SHA (`e0450a3`, a ponta em que a página foi escrita). Os três
governantes, medidos nesta árvore **antes** desta seção: **123 · 0 · 470 = 593** números, 0 fora do
arquivo; o salto do status em relação à medida anterior (**466**) é o furo #21 e o dono do furo #18.
Com esta seção em cima o mesmo comando devolve **123 · 0 · 478 = 601**: os **8** números que ela traz
são as oito âncoras do parágrafo do dossiê — cinco do `main.gd`, duas do runner (rótulo e URL da mesma
linha) e uma do `smoke_test.gd`.

### O que nada disso fecha

Nenhum gate de fase (mandato 4) e nenhuma linha de código: a branch `feat/tocas-da-alcateia-16` não
abriu, `toca`/`den`/`home_of`/`pack_id` não existem em `src/` nem em `tests/` (grep conferido no §2.3 da
página), e nenhuma das dez checagens nomeadas roda. O último contrato publicado — **252 checagens / 0
falhas** na suíte — é o da perna 11 na árvore do pin `5b519f8`. Nesta ponta a suíte foi re-corrida só
para o item 5 do ciclo de trabalho e deu **252 / 0 / 42,4 s**, exit 0, zero `SCRIPT ERROR` nas duas
correntes, com `git diff HEAD --stat -- src tests` **vazio**: o que mudou aqui é prosa, e número
publicado é número medido na revisão que o publica. O que a rodada entrega é a pauta com premissa, custo
e gate escritos contra o código de hoje — e o dono do furo #18 e do #21 nominado **antes** de qualquer
delas virar linha em `src/main.gd` ou na suíte.

**Registro da `main` mergida (2026-11-22).** O merge `--no-ff` desta branch na `main` (ponta `582aaef`)
foi re-corrido na árvore resultante e devolveu suíte **252 / 0 / 42,5 s**, exit 0, zero `SCRIPT ERROR`
nas duas correntes, e o `git diff` de `src/` e `tests/` contra o pin `5b519f8` continua **vazio**: os
mesmos dois objetos de sempre. Por isso nenhum número novo é publicado aqui — o contrato da suíte é o
do pin da perna 11, e as duas corridas desta passada (branch **42,4 s**, `main` mergida **42,5 s**)
existem para fechar o item 5 e o item 6 do ciclo de trabalho, não para abrir contagem.

## Rodada Docs 12 — a pauta do bicho cavando re-escrita contra a árvore de hoje (2026-11-22, `docs/pauta-do-cavar-12`)

### O que estava em aberto

[`docs/planos/12-bicho-cavando-voxel.md`](planos/12-bicho-cavando-voxel.md) foi escrita em 2026-11-20,
antes de pousarem 09, 10, 15, 14, 11 e 19, e antes de a 16 ter página. Desde então a árvore ganhou o
degrau pulado da 19, o censo variável e a fase por `clock.tick` da 11, o `_resolve_dry_target()` e o
predicado de spawn da 14, o viés de bioma no imprint da 09 e a folha de rondas da 10 — e uma pauta que
descreve onde uma peça se encaixa vale o que valia no dia em que foi lida. Nada aqui é código: a branch
`feat/bicho-cavando-12` continua sem abrir, e a fila serializada **não** se moveu
(**09 → 10 → 15 → 14 → 11 → 19 → 16 → 12 → 17 → 18 → 13**).

### O que entrou (uma página re-escrita, três documentos de pauta atualizados, nenhuma linha de código)

- a dossiê 12 inteira, agora com um §0 novo de **16 linhas** "o que a página de 2026-11-20 dizia × o que
  a árvore de hoje devolve" e os gates do §2 re-lidos por conteúdo, não por faixa de linha. As quatro
  correções que mudam o desenho, e não a prosa:
  1. **dureza é duração, não permissão** — `_mining_accum += delta` comparado a `target_hardness` sem
     teto de bloco ([src/entities/player.gd:663-664](../src/entities/player.gd#L663-L664)) e `AIR`
     escrito em qualquer alvo ([`:685`](../src/entities/player.gd#L685)); `STONE 0,95` cai em 0,95 s, e
     a afirmação antiga de que pedra, madeira e `COBBLESTONE` "ficam fora do alcance com a régua do
     jogador" está **falsa**. O que decide é lista de material, e a checagem 2 ganhou um braço `GLASS`
     (0,10 — mais mole que a neve) justamente para a lista não virar teorema de dureza;
  2. **`block_changed` não tem consumidor** — só a declaração
     ([src/world/voxel_world.gd:6](../src/world/voxel_world.gd#L6)) e o emit
     ([`:336`](../src/world/voxel_world.gd#L336)); o gate observa `get_block` + `world.edits`, que é o
     que o save grava e o journal hashia, e a 17 continua sendo a primeira a assinar o sinal — com a
     checagem `queda_move_a_celula` nascendo vermelha por isso mesmo;
  3. **cavar é o terceiro ramo do `if` de bloqueio**, não folha nova: o segundo ramo é da 19
     ([src/entities/wolf.gd:1239-1254](../src/entities/wolf.gd#L1239-L1254)), e o fork A/B (§3.4) é decidido
     por `intent` entrar no hash do journal — o braço B re-derivaria uma checagem já gateada da 11;
  4. **quem cava é decidido pelo alcance do corpo**: `PHASE_SCALE` 0,45 no filhote
     ([src/entities/wolf.gd:89](../src/entities/wolf.gd#L89)) e o `reach` derivado de `dims`
     ([src/entities/voxel_body.gd:163](../src/entities/voxel_body.gd#L163)); nenhuma linha
     `if fase == ADULTO`.
  E o item (b) da página antiga foi re-baseado: "WORK + BLOOD difundem com menos barreira" não é
  falsificável, então o observável passou a ser o `y` que
  [`_scent_ground_y`](../src/entities/wolf.gd#L1025-L1029) devolve para a célula do achado.
- duas armadilhas de palco nomeadas no §2 e no §4, as duas lidas do runner de hoje: `_wall`
  ([tests/aether_reactions_test.gd:401-404](../tests/aether_reactions_test.gd#L401-L404)) e `_cave_carve`
  ([`:1484-1491`](../tests/aether_reactions_test.gd#L1521-L1528)) escrevem com `record` default — parede
  de teste **é** construção registrada, e a cláusula de proveniência recusaria o alvo — e `_advance`
  ([`:305-321`](../tests/aether_reactions_test.gd#L342-L358)) **não** chama `world.process`, então a
  colheita de malha tem de esvaziar a fila no fim do cenário, no molde de `w.process(64)`
  ([tests/smoke_test.gd:1696](../tests/smoke_test.gd#L1696));
- o índice [`docs/planos/README.md`](planos/README.md): a linha 12 das duas tabelas (as **nove** checagens
  nomeadas no §5, com a base da branch passando a **depois da 16** e o motivo re-derivado), e a prosa do
  encadeamento, que dizia "a gravidade de blocos é o segundo consumidor do `block_changed` que o cavar
  acabou de abrir" — com o cavar **não** abrindo sinal nenhum, a gravidade continua sendo a **primeira**;
- [`AGENTS.md`](../AGENTS.md) ganhou o registro de 2026-11-22 (2), declarado como re-escrita de pauta:
  nenhuma autorização nova, nenhuma exceção de ordem, nenhuma constante de versão tocada;
- este status: os furos **#22** e **#23**, o parágrafo do item 11 do "Falta" com o que a leitura de hoje
  devolve diferente, e a nota de "Em andamento" de que a fila não se moveu.

### A contagem conferida nesta ponta

`python .tools/verify_plan_cites.py` sobre as **dezenove** páginas: **1 301 citações com número de linha
conferidas, 0 números fora do arquivo** — elo a elo **71 · 50 · 25 · 75 · 70 · 34 · 51 · 55 · 39 · 77 ·
80 · 139 · 110 · 68 · 115 · 94 · 54 · 50 · 29**, com a página 12 subindo de **53** para **139** e as
outras dezoito **idênticas** à medida da rodada 16. Com a página índice no diretório, o total é **1 301**
(1 286 nas dossiês + **15** do índice, que ganhou prosa e nenhuma citação numerada nova). As ausências de
arquivo continuam **9**, os mesmos **3** arquivos já declarados inexistentes (`tick_clock.gd`,
`simclock.md`, `wolf_multiseed_census_test.gd`) — a re-escrita não transformou nenhuma peça em fato. Pelo
`verify_plan_ids.py` a página 12 devolve **84** identificadores em backticks, dos quais **11** não existem
em `src/` nem em `tests/`: **9** nomes de checagem proposta e **2** campos que o §3.1 propõe
(`_dig_accum`, `_dig_pos`) — nenhum identificador de código existente citado em vão. No
`tools/check_doc_anchors.py` o corpus dá **2 260 ponteiros conferidos, 151 rótulos, 2 217 links
relativos** em **36** arquivos e **0** casos objetivos; o único que a re-escrita abriu foi um rótulo
`_drop` apontando para
a linha de preenchimento da tabela em vez da declaração, e foi corrigido na mesma passada, com o
`drop_of` real ([src/world/block_defs.gd:166](../src/world/block_defs.gd#L166)) entrando no lugar. Os três
governantes, medidos nesta árvore **antes** desta seção: **142 · 0 · 500 = 642** números, 0 fora do
arquivo — o salto contra a última medida publicada (rodada 16: **123 · 0 · 478 = 601**) é **+19** no
contrato, pelo parágrafo de registro, e **+22** aqui, pelos dois furos novos, a nota do item 11 do
"Falta" e a nota de "Em andamento". Com esta seção em cima o mesmo comando devolve **142 · 0 ·
525 = 667**: os **25** números que ela traz são os **15** links âncora (4 no runner de reações, 3 em
`wolf.gd`, 2 em `voxel_world.gd`, 2 em `player.gd` e um cada em `smoke_test.gd`,
`simulation_rng_test.gd`, `block_defs.gd` e `voxel_body.gd`) mais os **10** `arquivo:linha` que esses
links repetem no rótulo. A soma foi conferida recortando: o status sem a seção mede **500**, com ela
**525** — 25 é a diferença, não uma conta feita de cabeça.

### O que nada disso fecha

Nenhum gate de fase (mandato 4) e nenhuma linha de código: `feat/bicho-cavando-12` não abriu — abre da
`main` depois de a 16 pousar, porque as duas escrevem `src/main.gd` —, `_dig_accum`, `_dig_pos` e as nove
checagens nomeadas não existem em `src/` nem em `tests/`, e nenhum bicho escreve no mundo. Os números
publicados continuam os da perna 11: **252 checagens / 0 falhas** na suíte no pin `5b519f8`, **225** no
runner de reações ([tests/aether_reactions_test.gd:64](../tests/aether_reactions_test.gd#L64)) e **27** no
de RNG ([tests/simulation_rng_test.gd:9](../tests/simulation_rng_test.gd#L9)). Esta passada é docs:
`git diff HEAD --stat -- src tests` **vazio**.

**Registro da `main` mergida (2026-11-22).** O merge `--no-ff` desta branch na `main` (ponta `d1fc226`)
foi re-corrido na árvore resultante e devolveu suíte **252 / 0 / 42,4 s**, exit 0, zero `SCRIPT ERROR`
nas duas correntes, e o `git diff` de `src/` e `tests/` contra o pin `5b519f8` continua **vazio**: os
mesmos dois objetos de sempre. Os dois runners, medidos na ponta da branch sobre a mesma árvore de
código, deram **225 / 0 / 14,993 s** e **27 / 0 / 2,709 s**, exit 0 cada. Por isso nenhum número novo é
publicado aqui: o contrato da suíte é o do pin da perna 11, e as corridas desta passada existem para
fechar o item 5 e o item 6 do ciclo de trabalho, não para abrir contagem. A contagem do corpus não se
moveu com este parágrafo — **1 301** citações no diretório, **15** nesta página índice, governantes em
**142 · 0 · 525 = 667** e âncoras com **0** casos objetivos —, porque aqui se citou SHA e nomes de
arquivo sem número de linha.

## Rodada Tocas 16 — o custo do espalhamento pareado, medido com e sem a perna (2026-11-22, `feat/tocas-da-alcateia-16`, base `99d1167`, ponta de código `90c152f`)

A checagem 7 do dossiê ([`16-tocas-da-alcateia.md:285-288`](planos/16-tocas-da-alcateia.md#L285-L288)) pedia
um par — o `sim_step` integral da mesma cena e da mesma semente **com** a perna e **sem** ela, mais
`worst_sim_ms` e `dropped_ticks == 0` no smoke. O par não coube num processo só, e o motivo é de contrato,
não de conveniência: esvaziar `_dens` à mão encenaria um estado que nenhuma transição do jogo produz, e o
ciclo 3 de [`AGENTS.md`](../AGENTS.md) recusa exatamente isso. Então o lado "sem" é a base da branch
(`99d1167`) exportada, reimportada sem cache e corrida duas vezes; o lado "com" é a ponta medida, também
duas vezes. As quatro corridas, os logs arquivados e o vínculo de md5 estão em
[custo-pareado.md](evidence/tocas-alcateia-16/custo-pareado.md).

**Veredito medido: nenhum custo atribuível à perna.** Por passo, o `CENARIO ESTREITO` (8 579 passos) deu
**222,69 µs** na base contra **221,12 µs** na ponta — Δ **−1,57 µs (−0,70 %)** — e a janela de matilha deu
**2 294,40** contra **2 276,93 µs** — Δ **−17,47 µs (−0,76 %)**. Nos dois braços a diferença nominal é
*negativa* e menor que o espalhamento de repetir o **mesmo** braço (0,44 % e 0,71 % no estreito; 1,79 % e
0,42 % na matilha). Número menor que o ruído do instrumento não é melhoria: é "não medimos diferença". A
comparação é por passo porque a janela de matilha fecha por condição de censo e saiu 1 339 × 1 341 passos —
o total absoluto não seria comparável.

O caminho raro agora tem número, e não tem régua porque régua para ele não existe: fundar os cinco lares com
três tocas custou **7 314 µs** (run 1) e **7 108 µs** (run 2), contra um boot medido no mesmo log de suíte
com **993,314 ms** de geração e **4 368,851 ms** de malharia
([`head_suite.log:345`](evidence/tocas-alcateia-16/head_suite.log#L345)) — duas ordens de grandeza abaixo do
que o boot já gasta numa passada.

A checagem nova ([`aether_reactions_test.gd:4396-4461`](../tests/aether_reactions_test.gd#L4396-L4461),
declarada em [`:41`](../tests/aether_reactions_test.gd#L41) e no censo de [`:63`](../tests/aether_reactions_test.gd#L64),
que sobe de 238 para **240**) roda 1 400 passos reais com `clock.begin_step()`/`end_step()` e amarra a
premissa do espalhamento (`dens=3`, componentes mínimos `3`, cinco bichos lidos) na primeira asserção, para
o segundo número não poder vir de uma matilha que não foi espalhada. Pior passo **11,41 ms** (run 1) e
**9,68 ms** (run 2) contra a régua de **25 ms** dos dossiês 17 e 19; média **1 988,53** e **1 968,88**
µs/passo. O pico cronometrado dentro da checagem e o `worst_sim_ms` lido do `diagnostics()` coincidem no
mesmo run (11 408 µs ↔ 11,41 ms; 9 681 µs ↔ 9,68 ms), que é a prova de que os dois instrumentos medem a
mesma grandeza.

`dropped_ticks == 0` foi para o smoke ([`smoke_test.gd:3477-3483`](../tests/smoke_test.gd#L3477-L3483)) e não
para a janela do runner por um motivo lido no relógio, não por gosto: o contador só incrementa quando
`clock.advance()` estoura o teto de 5 passos por frame ([`sim_clock.gd:23-26`](../src/core/sim_clock.gd#L23-L26)),
e quem chama `advance` é o `_physics_process` da sessão — num laço que chama `_sim_tick()` direto a asserção
seria decorativa. A testemunha do espalhamento (`dens >= 2`, `componentes >= 2`) entrou **dentro** do
critério, porque sem ela o número não seria do espalhamento. Medido na sessão real: `perdidos=0`, pior passo
**10,77 ms**, `dens=3`, `componentes=3`, separação mínima lida **55,9 m** com `tick=403`
([`head_suite.log:343`](evidence/tocas-alcateia-16/head_suite.log#L343)).

Contagens medidas nesta árvore, todas exit 0 e sem `SCRIPT ERROR`: runner **240 / 0 / 24,586 s** (run 1) e
**240 / 0 / 24,446 s** (run 2), `simulation_rng_test` **27 / 0 / 2,762 s** e suíte **255 / 0 / 48,0 s**
([`head_suite.log:357`](evidence/tocas-alcateia-16/head_suite.log#L357)). Os acumuladores da checagem são
locais de propósito: os dois rodapés que sustentam o pareamento — `CENARIO ESTREITO` e `PASSOS DE MATILHA` —
precisam continuar existindo idênticos nos dois braços, e engordá-los com a colheita nova destruiria o
instrumento que faz o par ser par.

## Rodada Docs 16 (h) — o corpus re-derivado contra a árvore da perna, medido com as réguas na mão (2026-11-22, `feat/tocas-da-alcateia-16`, código `90c152f` + medição `ab4d4c3`)

**O que esta passada é.** Trinta e dois arquivos: [`AGENTS.md`](../AGENTS.md),
[`README.md`](../README.md), [`docs/audio-provenance.md`](audio-provenance.md), cinco páginas de
`docs/design/`, este status, as vinte de `docs/planos/` e o par de evidência que a re-corrida pede —
[custo-pareado.md](evidence/tocas-alcateia-16/custo-pareado.md), com a linha que dizia "os cinco logs"
re-escrita, e [`artifacts.sha256`](evidence/tocas-alcateia-16/artifacts.sha256) na sexta entrada, o novo
[`docs_rerun_suite.log`](evidence/tocas-alcateia-16/docs_rerun_suite.log) — **1 763 linhas inseridas,
998 removidas**, contadas por `git diff --shortstat` com o log já em intent-to-add. Nenhuma linha de código: `git diff HEAD --stat -- src tests`
**vazio**, e os seis commits de código da perna (`af04504` … `90c152f`) mais o de medição (`ab4d4c3`)
seguem sendo todo o diff desta branch contra a `main`.

**Por que o corpus inteiro se moveu junto.** A perna cresceu exatamente onde o corpus aponta, e isso se
mede: `git show 99d1167:<arquivo> | wc -l` contra a árvore de trabalho dá [`src/main.gd`](../src/main.gd)
**1 004 → 1 242** linhas, [`src/entities/wolf.gd`](../src/entities/wolf.gd) **1 203 → 1 218**,
[`tests/aether_reactions_test.gd`](../tests/aether_reactions_test.gd) **3 727 → 4 396** e
[`tests/smoke_test.gd`](../tests/smoke_test.gd) **2 577 → 2 681** — **1 062 inserções e 36 remoções** em
quatro arquivos. Ponteiro `arquivo:linha` que caía depois da linha 1 004 de `main.gd` deixou, por
construção, de apontar para o que a frase diz; o item 7 do ciclo de trabalho manda re-derivá-lo, não
herdá-lo da rodada anterior.

**As quatro réguas, todas rodadas nesta árvore depois das edições.**

- `python tools/check_doc_anchors.py` — o instrumento versionado da furo #14/#17: **36 arquivos**,
  **2 338 ponteiros** doc→doc conferidos, **179 rótulos**, **2 300 links relativos**, **0 casos
  objetivos**. A última medida publicada (rodada do registro da `main` mergida) era **2 260 · 151 · 2 217**
  em 36 arquivos com 0 casos. O corpus subiu **+78 ponteiros, +28 rótulos, +83 links** sem abrir um caso
  sequer — que é o resultado que se quer: mais ponteiro, nenhum quebrado.
- `python .tools/verify_plan_cites.py docs/planos/*.md` — **1 357 citações com número de linha
  conferidas**, **0 números fora do arquivo**, **9 ausências** de arquivo, que são os mesmos **3** já
  declarados inexistentes e continua sendo 3 (`src/core/sim/tick_clock.gd` quatro vezes,
  `docs/engine/simclock.md` três, `tests/wolf_multiseed_census_test.gd` duas). Elo a elo, as dezenove
  páginas numeradas dão **71 · 50 · 25 · 75 · 70 · 53 · 51 · 55 · 39 · 116 · 80 · 139 · 110 · 68 · 115 ·
  92 · 54 · 50 · 29** = **1 342**, mais **15** do índice. A rodada anterior publicou
  **71 · 50 · 25 · 75 · 70 · 34 · 51 · 55 · 39 · 77 · 80 · 139 · 110 · 68 · 115 · 94 · 54 · 50 · 29** =
  **1 286** (+ 15 = **1 301**). **Três páginas se moveram e dezesseis ficaram idênticas**: **06**
  (decompor `main.gd`) **34 → 53**, **10** (rotinas da alcateia) **77 → 116** — as duas que mais citam
  `main.gd` e `wolf.gd`, precisamente as duas que a perna alongou — e **16** (tocas) **94 → 92**.
- O **−2 da página 16 não é ponteiro perdido**, e a prova é uma medição, não uma leitura: os **dois**
  ponteiros que saíram da régua são `main.gd:349` e `main.gd:522`, hoje escritos na forma histórica
  `99d1167:src/main.gd:328` e `99d1167:src/main.gd:501` porque a frase que os usa descreve a árvore-base
  que a perna leu antes de existir, e a régua exclui o prefixo de revisão por design. Rodando a mesma
  contagem sobre o arquivo com os prefixos despidos, a página devolve **94** — o número publicado. O
  mesmo se fez no [`AGENTS.md`](../AGENTS.md), que a régua conta **142 → 131**: **13** ponteiros passaram
  à forma com prefixo (`10` com `f2823a8:` no parágrafo de leitura da perna 14 e `3` com `99d1167:` na
  leitura da premissa das tocas); despido o prefixo, o documento devolve **144**, ou seja, **subiu 2**
  contra a base. Nenhum ponteiro vivo foi apagado em nenhum dos dois.
- Os **três governantes** juntos, na mesma régua e **antes** desta seção: **131 · 0 · 552 = 683**
  citações conferidas, 0 números fora do arquivo. A base de comparação não foi herdada: os três blobs de
  `HEAD` foram copiados para `.tools/_head_agents.md`, `.tools/_head_readme.md` e `.tools/_head_status.md`
  — `.tools/` é o único lugar de onde o `../` dos governantes resolve — e medidos ali, dão
  **142 · 0 · 530 = 672**. O **README é 0 → 0** porque a página não cita número de linha nenhum
  (`grep -oE "[a-zA-Z_/]+\.gd:[0-9]+" README.md` devolve **0** ocorrências): as seis mudanças que ela
  recebeu nesta passada são prosa e números de corrida, não ponteiros.
- `python .tools/verify_plan_ids.py` sobre a página 16: **88** identificadores em backticks, dos quais
  **8** não existem em `src/` nem em `tests/` — `DEN_RANGE` (linha 202, braço B **não escolhido**),
  `assinatura_de_populacao_estavel` (linha 302, item 10 da lista de checagens propostas), `PLANT`
  (linha 318, citada justamente dentro do "não desenhar"), o SHA `e0450a3` e quatro nomes de alvo ou de
  outro projeto (`fp_viewmodel`, `player_avatar`, `home_of`, `pack_id`). **Nenhum identificador de código
  existente citado em vão** — os oito são, um por um, peças que a própria página declara inexistentes.

**O que este status recebeu de prosa, item por item.** (1) O primeiro bullet de "Feito nesta sessão" agora
é a perna 16 inteira: premissa lida no código (`PACK_LEASH = 18,0` em
[src/main.gd:584](../src/main.gd#L584) como primeira tentativa em [:762](../src/main.gd#L824) contra a
caixa útil de 116 × 116 m), o que o código faz hoje com ponteiro re-derivado (`_dens`
[:136](../src/main.gd#L136), `DEN_COUNT` [:534](../src/main.gd#L596), `Wolf.den`
[wolf.gd:186](../src/entities/wolf.gd#L186), `_place_request` [:672-701](../src/main.gd#L734-L763), o
portão `DEN_MIN_DIST`/`_den_gate_ok` [:605-611](../src/main.gd#L667-L673), a separação medida no chão
[:681-690](../src/main.gd#L743-L752), `_spawn_home_point` [:756-821](../src/main.gd#L818-L902), a fila
carregando a toca [:373](../src/main.gd#L435), o parto herdando [:483-484](../src/main.gd#L545-L546), a
sentinela `_sem_toca` [:720-723](../src/main.gd#L782-L785), o disco [:1020-1039](../src/main.gd#L1101-L1120)
e a leitura no load [:1099-1105](../src/main.gd#L1180-L1186)) e o que foi medido (3 tocas, 55,9 m,
`componentes=3`, `arestas_entre_tocas=0`). (2) O **furo #18** saiu do presente do indicativo — "nenhuma
recusa tinha testemunha numérica" — e passou a **pago**: a régua foi re-ancorada no dicionário de **sete**
motivos declarado em [src/main.gd:823-824](../src/main.gd#L823-L824) e incrementado um por linha
(`vazia` [:775](../src/main.gd#L837), `coluna` [:785](../src/main.gd#L847),
`molhado` [:789](../src/main.gd#L851), `encaixado` [:793](../src/main.gd#L829),
`perto` [:799](../src/main.gd#L861), `visivel` [:801](../src/main.gd#L863),
`perto_de_toca` [:807](../src/main.gd#L869)), com as chaves saindo no dicionário de recusa em
[:821](../src/main.gd#L902) e o número na checagem `esgotamento_de_lares_forcado`
([tests/aether_reactions_test.gd:2849-2885](../tests/aether_reactions_test.gd#L2849-L2885)).
(3) O **furo #21** deixou de ser identidade aritmética: a coesão agora é `den_components()`
[src/main.gd:697-717](../src/main.gd#L697-L717), publicada em
[:1192](../src/main.gd#L1281) e lida no smoke por `grupos >= 2` em
[tests/smoke_test.gd:400](../tests/smoke_test.gd#L400). (4) "Em andamento" passou a dizer o que a perna é
hoje — seis commits de código, um de medição, esta passada de documento, **nenhum** merge, **nenhum** pin,
**nenhuma** publicação — e registrou os dois débitos que ela mesma abriu (atribuição do par de quit e a
alocação não medida das travessias de `_dens`/`den_components`). (5) A linha de débitos dos `.uid` foi
conferida contra `git ls-files`, não contra a rodada do áudio: **39** `.gd` rastreados, índice com **37**
`.uid`, faltando `tests/audio_test.gd.uid` e `tests/audio_live_probe.gd.uid`, que naquela rodada **nem
existiam** — o que falta é stagear os dois, nada os cria de volta. (6) As cinco páginas de `docs/design/`,
o índice de `docs/planos/` e os dossiês que apontam para spawn, matilha e disco trocaram número na mesma
passada, e o [`README.md`](../README.md) ganhou o parágrafo de que a 16 ainda não pousava **naquela leitura**, com os números
da ponta de branch marcados como tal.

**Com esta seção em cima, as mesmas réguas devolvem** — e a conta foi conferida recortando a seção e
medindo o recorte, não de cabeça: os três governantes passam a **131 · 0 · 584 = 715** citações conferidas
(os **32** números novos são 27 ponteiros em `src/main.gd`, 2 em `tests/aether_reactions_test.gd`, 2 em
`tests/smoke_test.gd` e 1 em `src/entities/wolf.gd`, cada um com linha que existe no arquivo);
`tools/check_doc_anchors.py` sobe para **2 370 ponteiros · 179 rótulos · 2 348 links relativos** em **36**
arquivos e continua com **0** casos objetivos; as vinte páginas de `docs/planos/` ficam em **1 357** com
**9** ausências e **0** fora do arquivo, porque nenhuma linha desta seção é dossiê; e o corpus inteiro
(governantes + dossiês) fecha em **2 072** citações conferidas, **12** ausências — os mesmos **3** arquivos
inexistentes, 9 ocorrências contadas nas dossiês e 3 neste status — e **0** números fora do arquivo.

**A suíte re-rodada nesta árvore de documentos** — serial, máquina livre,
`godot --headless --path . tests/smoke_test.tscn`: **255 checagens / 0 falhas / 47,7 s**, exit 0, com **255**
linhas `[PASS]`, **0** `[FAIL]` e **0** `SCRIPT ERROR` (contados por `grep` no log, agora arquivado em
[docs_rerun_suite.log:357](evidence/tocas-alcateia-16/docs_rerun_suite.log#L357)). Bate com a
corrida arquivada da perna — 255 / 0 / 48,0 s, [head_suite.log:357](evidence/tocas-alcateia-16/head_suite.log#L357)
— porque os arquivos medidos são os mesmos: esta passada é documento, e `src/` e `tests/` não se mexeram
desde `ab4d4c3`. A única diferença visível entre as duas corridas é o par de quit: a arquivada traz
`4 ObjectDB instances were leaked` ([linha 358](evidence/tocas-alcateia-16/head_suite.log#L358)) com
`2 resources still in use` ([linha 360](evidence/tocas-alcateia-16/head_suite.log#L360)); esta não traz
nenhum dos dois. Isso não abre defeito novo nem fecha o velho — a mesma assinatura já sai na **base** da
perna 14, com `12 ObjectDB` e `4 resources still in use`
([base_smoke.log:333](evidence/alcateia-convivio-14/base_smoke.log#L333), [:335](evidence/alcateia-convivio-14/base_smoke.log#L335)),
e no clone limpo da perna 11 ([clone_suite.err:1](evidence/acasalamento-censo-11/clone_suite.err#L1),
[:3](evidence/acasalamento-censo-11/clone_suite.err#L3)). É intermitente, é anterior à 16 e continua como
débito de atribuição, fora do escopo desta perna.

**O que nada disso fecha.** Nenhum gate de fase (mandato 4). Nesta leitura (2026-11-22) a perna 16 ainda
**não tinha pousado**: nenhum `merge --no-ff`, nenhum `git push`, porque nada disso tinha sido pedido pelo dono,
e o pin publicado era o `5b519f8` da perna 11 (**252 / 0 / 42,4 s**): os 255 desta ponta eram número de
branch, não de `main`. O pouso veio em 2026-11-23 pelo merge `--no-ff` `9b2c65a` — seção final daqui.
Nenhuma das duas encosta em `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` ou na projeção do journal,
e a 12 continua nascendo vermelha em `block_changed` (zero consumidores): é o elo aberto seguinte da fila.

## O pouso da 16 — o merge, o pin medido no clone limpo e as cinco corridas serializadas (2026-11-23, base `99d1167`, ponta `edab9c8`, merge `9b2c65a`)

**O que o dono autorizou e o que continua fechado.** A autorização desta rodada é nomeada: subir o que
terminar com `push`, e cada agente faz o próprio `merge --no-ff` na `main` e o push. Isso vale para o
pouso do código da 16 e nada mais — **mandato 4**: gate de fase fecha só o dono, e nenhum gate foi fechado
aqui. A fila serializada não sofreu exceção de ordem: a 16 era a perna da vez, foi aberta da `main` no
ponto atual, e pousou nele.

**Pré-gate, conferido antes de encostar em `main`.** `git status --porcelain` vazio na base; `origin/main`
e `main` locais no mesmo commit (`99d1167`); `git merge-base main feat/tocas-da-alcateia-16` devolvendo
`99d11673576beba7689033f867851627d63dadad`, que é a `main` — logo a branch é descendente direta e o merge
não carrega nada de fora da perna. `godot --headless --path . --import` no worktree antes das corridas:
exit 0, e foi essa árvore importada que mediu.

**O merge.** `git merge --no-ff feat/tocas-da-alcateia-16` → **`9b2c65a30b74a6398fbf4f9c45560be38974fb12`**,
pais `99d1167` e `edab9c8` (`git log --format=%P -1`), sem conflito e sem toque em `src/` feito aqui: o
código é exatamente o que a branch trouxe. `git show --stat` do merge: **41 files changed, 5026 insertions(+),
1033 deletions(-)**, sendo o código `src/main.gd` **+267/−29**, `src/entities/wolf.gd` **+16/−1**,
`tests/aether_reactions_test.gd` **+670/−1**, `tests/smoke_test.gd` **+109/−5**.

**As cinco corridas, seriais, uma por número, máquina livre conferida antes de cada uma** (`tasklist` sem
nada do Godot nem carga de chat rodando). Todas exit 0, com **0** `[FAIL]` e **0** `SCRIPT ERROR` contados
por `grep` no log, e o par de vazamento do quit (`4 ObjectDB instances` / `2 resources still in use`) na
assinatura intermitente já registrada como débito de atribuição:

- suíte na árvore mergida — **`== 255 checagens  0 falhas  47.7 s de teste ==`**
  ([pouso_merged_main_suite.log:357](evidence/tocas-alcateia-16/pouso_merged_main_suite.log#L357));
- runner de reações na árvore mergida — **`240 checagens 0 falhas 24.201 s`** com o censo
  **`OK censo de checagens | 240/240`**
  ([pouso_merged_main_runner_reactions.log:494](evidence/tocas-alcateia-16/pouso_merged_main_runner_reactions.log#L494),
  [:491](evidence/tocas-alcateia-16/pouso_merged_main_runner_reactions.log#L491));
- **clone limpo** de `9b2c65a` fora da árvore, com `--import` frio — suíte
  **`== 255 checagens  0 falhas  48.6 s de teste ==`**
  ([pouso_clone_suite.log:357](evidence/tocas-alcateia-16/pouso_clone_suite.log#L357)) e runner
  **`240 checagens 0 falhas 24.138 s`** com **`OK censo de checagens | 240/240`**
  ([pouso_clone_runner_reactions.log:494](evidence/tocas-alcateia-16/pouso_clone_runner_reactions.log#L494),
  [:491](evidence/tocas-alcateia-16/pouso_clone_runner_reactions.log#L491)); o import está em
  [pouso_clone_import.log](evidence/tocas-alcateia-16/pouso_clone_import.log);
- runner de RNG da sessão — **`27 checagens 0 falhas 2.651 s`** com
  **`OK censo de checagens | 27/27`**
  ([pouso_merged_main_runner_rng.log:78](evidence/tocas-alcateia-16/pouso_merged_main_runner_rng.log#L78),
  [:77](evidence/tocas-alcateia-16/pouso_merged_main_runner_rng.log#L77));
- runner do journal — **`128 checagens 0 falhas 7/7 testes concluidos 5.610 s`** com
  **`OK contagem completa de checagens 128/128`**
  ([pouso_merged_main_runner_journal.log:143](evidence/tocas-alcateia-16/pouso_merged_main_runner_journal.log#L143),
  [:142](evidence/tocas-alcateia-16/pouso_merged_main_runner_journal.log#L142)).

**O pin.** O número que vale para a `main` é o do **clone limpo**: **255 / 0 / 48,6 s**, com o runner em
240 / 0 / 24,138 s. O clone foi feito fora de qualquer árvore de trabalho, checkout de `9b2c65a`
(`git rev-parse HEAD` no clone), `--import` frio antes da suíte, e as árvores batem com as da árvore
mergida: `git rev-parse 9b2c65a:src` = **`64f137bcb1f8e95bd9a64fe7843e4e7b72f7326e`**,
`9b2c65a:tests` = **`88a1541c2f9f6fc3dd0e1d237b3e5656d9eea3c9`**. Contra o pin anterior (`5b519f8`:
`30873d664a9577bcd3e709046cc708923456c372` e `975eac5a471dc1e064441474ef6e13866076d34f`) as duas árvores
**mudaram** — a 16 escreve em `src/` e em `tests/`, então o pin é o merge medido, não um commit de
documento em cima dele. A suíte substitui o número da perna 11 (**252 / 0**) como leitura da `main`; as
contagens novas são as três checagens que a perna abriu (`espalhamento_nao_estoura_o_passo`,
`tocas e pertenca sobrevivem ao save`, `default derivado: disco sem a chave nao toca nem inventa`), e o
diagnóstico do clone traz `dens` e `den_components` juntos na mesma linha:
`"den_components":3,"den_min_dist":55.8567733764648,"dens":3,"dropped_ticks":0` … `"worst_sim_ms":11.726`
([pouso_clone_suite.log:345](evidence/tocas-alcateia-16/pouso_clone_suite.log#L345)), com a árvore mergida
medindo o mesmo par em 10,97 ms ([pouso_merged_main_suite.log:343](evidence/tocas-alcateia-16/pouso_merged_main_suite.log#L343))
e o clone em 11,73 ms ([pouso_clone_suite.log:343](evidence/tocas-alcateia-16/pouso_clone_suite.log#L343)).

**As três réguas do corpus, rodadas contra a árvore mergida.** `.tools/verify_plan_cites.py` com
`AETHER_ROOT` na árvore medida: **`citacoes com numero de linha conferidas: 1352`**,
**`arquivos citados que nao existem: 13`**, **`numeros de linha fora do arquivo: 0`**
([pouso_ruler_plan_cites.log:1](evidence/tocas-alcateia-16/pouso_ruler_plan_cites.log#L1),
[:2](evidence/tocas-alcateia-16/pouso_ruler_plan_cites.log#L2),
[:16](evidence/tocas-alcateia-16/pouso_ruler_plan_cites.log#L16)); a régua rodou igual contra a **base**
`99d1167` — **1 296** conferidas, mesmas **13** ausências, **0** fora do arquivo
([pouso_ruler_plan_cites_base99d1167.log:1](evidence/tocas-alcateia-16/pouso_ruler_plan_cites_base99d1167.log#L1),
[:16](evidence/tocas-alcateia-16/pouso_ruler_plan_cites_base99d1167.log#L16)) — o que é a prova de que o
merge não quebrou ponteiro nenhum: só acrescentou os 56 novos da própria perna. `.tools/verify_plan_ids.py`:
a página 16 em **88** identificadores citados e **8** ausências
([pouso_ruler_plan_ids.log:31](evidence/tocas-alcateia-16/pouso_ruler_plan_ids.log#L31),
[:32](evidence/tocas-alcateia-16/pouso_ruler_plan_ids.log#L32)) — conferidas uma a uma: `DEN_RANGE`,
`PLANT`, `assinatura_de_populacao_estavel`, `fp_viewmodel`, `home_of`, `pack_id`, `player_avatar` e o hash
`e0450a3` (commit de outra fila, não desta árvore) são peças que o dossiê **declara** inexistentes, não
ponteiros podres.
`python tools/check_doc_anchors.py`: **`arquivos: 36  ponteiros conferidos: 2370  rotulos conferidos: 179
links relativos conferidos: 2348`** com **`casos objetivos: 1`**
([pouso_ruler_doc_anchors.log:1](evidence/tocas-alcateia-16/pouso_ruler_doc_anchors.log#L1),
[:3](evidence/tocas-alcateia-16/pouso_ruler_doc_anchors.log#L3)) — o único caso é o ponteiro
`../.tools/_chk_labels.py` em `docs/melhorias-status.md:3203`
([:2](evidence/tocas-alcateia-16/pouso_ruler_doc_anchors.log#L2)), instrumento gitignored que a casa já
tolera aqui. As três contagens são as mesmas publicadas pela ponta da branch: o merge é código, e o
código não move documento.

**Os dois furos que a 16 paga, cada um com a checagem que o paga.** O **#18** (motivo legível no dicionário
de recusa) fecha pela `esgotamento_de_lares_forcado`, que força o esgotamento de lares e soma os motivos
impressos: **`OK esgotamento_de_lares_forcado | recusados=8 de 8 | soma(motivos)=576 == buscas(24) x
SPAWN_ATTEMPTS(24)=576 | so_a_coluna=true | colunas_marcadas=13689`**
([pouso_merged_main_runner_reactions.log:279](evidence/tocas-alcateia-16/pouso_merged_main_runner_reactions.log#L279))
— a aritmética fecha, a coluna é a única marcada e os 13 689 são o tamanho real da caixa sorteada. O
**#21** (coesão dos lares, antes identidade aritmética sempre verdadeira) fecha pela grandeza:
`den_components()` ([main.gd:697-717](../src/main.gd#L697-L717)) travessando o grafo do último rebuild,
publicado em `diagnostics()` ([main.gd:1242](../src/main.gd#L1242)) e lido no smoke por `grupos >= 2`
([smoke_test.gd:400](../tests/smoke_test.gd#L400)); as três linhas que sustentam a afirmação no runner são
**`OK diagnostico_publica_a_mesma_leitura_das_tocas | diagnostics dens=3 componentes=3 den_min_dist=49.662
| runner componentes=3 centros=49.7 | furo21 pack_pairs=10 pares_testados=10`**
([:407](evidence/tocas-alcateia-16/pouso_merged_main_runner_reactions.log#L407)) e
**`OK nenhum_lobo_le_de_outra_toca | arestas_entre_tocas=0 bichos_sem_toca=0 lidos=5`**
([:416](evidence/tocas-alcateia-16/pouso_merged_main_runner_reactions.log#L416)), com o par de save no
clone em [pouso_clone_suite.log:353](evidence/tocas-alcateia-16/pouso_clone_suite.log#L353) e o default
derivado em [:354](evidence/tocas-alcateia-16/pouso_clone_suite.log#L354). Os dois furos estavam escritos
na seção de furos com a rodada da branch; aqui eles ganham o SHA do pouso junto.

**O que nada disso fecha.** A fila **P0/P1 continua aberta**: budget HOT continua sem medição, o censo
multi-semente continua sem corrida e o bake-off de AF continua sem número — nada dos três foi tocado pela
16, que é espalhamento de lar e disco, não orçamento nem semente. Os canais do dossiê 03
(morte, som, fogo) e a difusão fora do tick continuam como pauta. **Nenhum gate de fase foi fechado**
(mandato 4), nenhum limiar foi abaixado e nada em `src/` foi consertado nesta passada: o vermelho que a 16
não reproduz não foi escondido. Os dois débitos que a perna abriu seguem em aberto — a atribuição do par
de vazamento do quit e a alocação de `_dens`/`den_components` sem colheita. Na fila serializada a 16 sai
da frente: o elo seguinte é **12** (`feat/bicho-cavando-12`, que esperava exatamente este pouso e nasce
vermelha em `block_changed`), depois **17 → 18 → 20 → 13**.

**A suíte e as réguas re-rodadas na árvore deste registro**, que só acrescenta `.md` e `.log`:
`git diff --name-only 9b2c65a -- src tests` **vazio**, então as árvores de código continuam
`64f137bc…` e `88a1541c…` e o número do pin vale para esta árvore por identidade de árvore, não por
memória. As duas corridas, uma por vez e com a máquina livre conferida antes de cada:
**`== 255 checagens  0 falhas 47.5 s de teste ==`**
([registro_rerun_suite_a.log:357](evidence/tocas-alcateia-16/registro_rerun_suite_a.log#L357)) e
**`== 255 checagens  0 falhas 47.7 s de teste ==`**
([registro_rerun_suite_b.log:357](evidence/tocas-alcateia-16/registro_rerun_suite_b.log#L357)), as duas
exit 0, com **255** linhas `[PASS]`, **0** `[FAIL]` e **0** `SCRIPT ERROR`; a primeira fecha em 357
linhas sem nenhum par de vazamento no rodapé e a segunda imprime `4 ObjectDB` (linha 358) com
`2 resources still in use` (linha 360) — o mesmo par, em duas corridas seguidas da mesma árvore, o que
reforça o débito de atribuição em vez de contá-lo como resolvido. As três réguas na
mesma árvore: `verify_plan_cites.py` **1 352 conferidas · 13 arquivos ausentes · 0 fora do arquivo**
([registro_ruler_plan_cites.log:1](evidence/tocas-alcateia-16/registro_ruler_plan_cites.log#L1)), iguais
às da árvore mergida porque nenhuma linha de `docs/planos/` foi editada aqui; `verify_plan_ids.py` com a
página 16 em **88 identificadores · 8 ausências**
([registro_ruler_plan_ids.log:31](evidence/tocas-alcateia-16/registro_ruler_plan_ids.log#L31)); e
`python tools/check_doc_anchors.py` **36 arquivos · 2 374 ponteiros · 179 rótulos · 2 389 links**, ainda
**1** caso objetivo, o mesmo `../.tools/_chk_labels.py` deste status
([registro_ruler_doc_anchors.log:1](evidence/tocas-alcateia-16/registro_ruler_doc_anchors.log#L1),
[:3](evidence/tocas-alcateia-16/registro_ruler_doc_anchors.log#L3)). O acréscimo de ponteiros e links é
esta seção e o parágrafo novo do README, não deriva de linha: as edições do registro foram medidas para
serem linha-neutras onde há apontamento — `git diff --numstat` dá **44/44** no README, com o parágrafo do
pin e o da perna trocando dentro do mesmo número de linhas, o que deixa no lugar os `README.md:501-514`,
`:533` e `:559-575` que os dossiês apontam — e onde não dá para ser neutro a inserção cai depois da
última linha que alguém cita: o registro do `AGENTS.md` entra após `AGENTS.md:475-477` e esta seção após
a maior linha deste arquivo que o corpus aponta (`4326`).

**Publicação provada, não afirmada.** As três refs do pouso ficam no origin, conferidas por `git
ls-remote --heads origin` depois do push: `main` com este registro por cima de `9b2c65a`,
`feat/tocas-da-alcateia-16` = `edab9c8` e `docs/registro-pouso-do-codigo-16` nesta ponta; **nenhuma
branch foi deletada** — a `main` local também não se apaga. O merge do registro move a ponta da `main`
e não move o pin: `git diff --name-only 9b2c65a..docs/registro-pouso-do-codigo-16 -- src tests` devolve
vazio, então `64f137bc…` e `88a1541c…` continuam sendo as árvores de código medidas de que cada número
acima sai — o pin é identidade de árvore, não SHA de documento.
Os artefatos da pasta têm `artifacts.sha256` com **22** entradas, regenerado por `sha256sum` e conferido
por `sha256sum -c`, todos **OK**; nele, `pouso_ruler_plan_cites.log` e `registro_ruler_plan_cites.log`
carregam o **mesmo hash**, e o mesmo par se repete entre os dois logs de identificadores — a igualdade de
bytes é a prova material de que este registro não encosta em `docs/planos/` nem em `src/` nem em `tests/`.

**Registro da `main` mergida (2026-11-23, pauta 20).** O merge `--no-ff` da `docs/pauta-mente-eco-20` na
`main` dá `575215de0daac8589d5020ef151c1fca6fdae9dd`, pais `bb13752` e `2a4b296`, com **14 arquivos,
+885/−52** e nenhuma linha de `src/` nem de `tests/` — é documento puro, a pauta de uma perna que ainda
não abriu. A identidade de árvore está medida, não afirmada: o diff de `src/` e `tests/` entre `bb13752` e
esta `main` devolve **vazio**, e os dois objetos de árvore são `64f137bcb1f8e95bd9a64fe7843e4e7b72f7326e`
e `88a1541c2f9f6fc3dd0e1d237b3e5656d9eea3c9` — os mesmos dois do pin `9b2c65a`, byte a byte. Por isso o
contrato publicado da pauta continua **255 checagens / 0 falhas** na suíte e **240 / 0** no runner de
reações: é o número do pin, e a suíte roda exatamente o código do pin.

**Esta passada não re-correu a engine, e o motivo é um fato da máquina.** O binário do pin é
`D:\Godot\Godot_v4.7.2-stable_win64.exe`, o caminho que o launcher deste repositório usa, e a unidade
`D:` não está montada nesta sessão — há só `C:`, `E:` e `F:`. A regra da casa é não caçar executável pela
máquina, então a corrida não roda; o que sustenta o número na ausência dela é a identidade de árvore do
parágrafo acima, escrita no índice e no contrato antes deste registro. Voltando o pin, a re-corrida serial
na `main` fecha o item 5 do ciclo de trabalho sem abrir contagem nova.

**As réguas, corridas na árvore mergida — e elas diferem da ponta da branch por um motivo nomeado.** O
instrumento de citações dá aqui **1 341** nas dezenove páginas que não são a 20 e **191** na 20, **1 532**
nos vinte dossiês, **1 554** com esta página índice no corpus, **0** números fora do arquivo e **11**
arquivos citados que não existem; na ponta da branch, numa árvore limpa, a mesma régua devolveu **1 336**,
**1 527** e **1 548** com **16** ausências. A diferença é o `.tools/`: os cinco caminhos que somem na árvore
limpa (`clean_suite.log`, `af-clean-suite.log`, `af-clean-suite2.log`, `shot_gallery.tscn` e o log da
re-corrida desta pauta) estão nesta árvore, então viram citação conferida em vez de ausência — gitignore,
não ponteiro podre. Os identificadores da 20 não se movem: **137** citados, **45** ausentes, nos dois lados.
O instrumento de âncoras dá **37 arquivos · 2 662 ponteiros · 179 rótulos · 2 666 links** com **0** casos
objetivos nesta árvore, contra **1** na ponta — o único caso é o link para o verificador de rótulos, que só
quebra onde o `.tools/` não está. O recorte dos três documentos que governam fecha em **173 · 3 · 620 =
796 números, 0 fora do arquivo**, igual à ponta. Nada deste parágrafo cita arquivo com número de linha, e é
por isso que o **620** acima continua sendo o número medido depois de escrevê-lo.

**Publicação provada, não afirmada.** `git ls-remote --heads origin` depois do push: `main` com este
registro por cima de `575215d`, `docs/pauta-mente-eco-20` em `2a4b29676dde596fdba5bc1001c0d7936d7a2b37` e
`docs/registro-merged-main-20` nesta ponta. **Nenhuma branch foi deletada** — nem a local, nem a remota,
nem a `main`.

**Em andamento/pouso (2026-11-23, pauta 21 — a apresentação do `README.md`).** Nada de código:
`git diff --name-only c1e77ad..HEAD -- src tests` devolve vazio, e o objeto da perna é a página que o
resto do mundo lê primeiro. Branch `docs/apresentacao-readme-21`, aberta da `main` em `c1e77ad`, com
seis commits antes deste registro — `f5dcb1d` (introdução + o clique), `44087b0` (seção do oráculo),
`0fd7f79` (índice de pastas), `fc559a3` ("O que existe"), `fa9059b` (mapa do código) e `1240489` (a
re-derivação dos ponteiros). O README sai de 708 para 746 linhas: as duas reescritas acima de `:197`
foram feitas frase por frase dentro do mesmo número de linhas, então `README.md:148-149`, `:192` e `:197`
seguem na mesma linha com o mesmo texto.

**O que a página passou a dizer, cada afirmação lida no arquivo antes de escrita.** (1) A introdução
vendia "personalidade e memória de NPCs, facções e eventos nascem de simulação local" no indicativo;
`src/entities/` tem `player`, `player_avatar`, `fp_viewmodel`, `voxel_body` e `wolf` — **nenhum NPC,
uma espécie** — então a frase agora afirma o que já decide, que é a matilha, e marca NPCs, facções e
eventos como `[TARGET]`,
que é o que a legenda de `docs/design/README.md` exige e o que a seção "alvo de design" já dizia três
páginas abaixo. (2) O parágrafo que resolvia o oráculo em "é opcional" passou a dizer que **com os
pacotes no disco o boot levanta o servidor sozinho**, sem linha de comando com credencial na página —
o mecanismo é descrito, a argv não. (3) `## IA local (opcional)` (`:552-587`) ganhou o hospedeiro
inteiro: `_start_llm_host()` no `_ready` (`src/main.gd:149`), antes da geração (`:152`) e da malharia
(`:135`); cria filho só com a porta vazia (`llm_server_host.gd:240-244` — aposentado no Passo 4 do
dossiê 22, commit 5138549); reusa servidor nosso
que sobrou de outra janela, com o `pid` ficando −1 e matando nunca (`:250-258`); processo alheio vira
`estrangeiro` e o jogo roda sem oráculo (`:245-249`, `:260`); `kill` só em pid próprio (`:407`,
`:413-414`); em headless nenhum hospedeiro é montado (`src/main.gd:279-281`), que é o que tira o pacote
do modelo do rodapé de tempo da suíte. A cena nova da 15, `tests/llm_server_boot_probe.tscn`, entrou no
bloco ao lado da que já era citada. (4) O índice de pastas (`:528-550`) e o mapa do código ganharam
`src/items/` — `inventory` com `SLOTS` 36 e `recipes` com estação `mao`/`bancada` existiam em código e
não existiam na lista —, trocaram "mente do NPC" por mente da criatura e escreveram `MindOracle` e
`LlmServerHost`, e a linha de `tests/` passou a contar as duas sondas de oráculo. (5) `## O que existe`
(`:590-631`) alcançou as pernas 10, 11, 14, 16 e 19: auto-pulo (`STEP_JUMP` 7,6 em
`src/entities/wolf.gd:101`, ápice 1,203 m contra a célula de 1,00 m, ramo em `:1239-1254`, e o mesmo
`_jump_buffer` do `Espaço` em `src/entities/player.gd:536-542`, por isso os dois no mesmo quadro somam
um salto), rondar o setor e cercar em assento próprio (`ENCIRCLE_RING`, `src/entities/wolf.gd:39`),
acasalamento com filhote que cresce (`MATE_RADIUS` 8 m, um par por varredura, `MATE_COOLDOWN` 300 s,
`PHASE_NAMES`/`PHASE_SCALE`, recusa contada em `census_refusals`), o grafo de coesão publicado como
`den_components` no `diagnostics()`, o spawn a 32 m **e** fora da visada (`_spawn_point_ok` em
`src/main.gd:787-792`, bandas de 16 a 70 m da posição atual) e o oráculo que o próprio boot levanta.

**Ponteiros re-derivados por conteúdo — e é aqui que a perna encontra o furo.** O registro do pouso da
16, neste arquivo, escreveu que suas edições foram medidas para serem linha-neutras, "o que deixa no
lugar os `README.md:501-514`, `:533` e `:559-575`". Contra o git isso não é verdade: o merge `9b2c65a`
tocou o README em **+42/−6 = +36 linhas** (`git diff --numstat 99d1167 9b2c65a -- README.md`), com
`## IA local` saindo de 517 para 549 e `## Limites` de 569 para 605, e o `44/44` citado é o do commit de
registro, não o do merge. Nove ponteiros apodreceram aí e passaram verdes por três réguas. A leitura de
chegada, linha a linha, devolve:

| onde estava | o que afirmava | para onde vai |
| --- | --- | --- |
| `README.md:570-575` (planos 07:67) | ~16 s → ~7,5 s pela cópia linear | `README.md:642-647` |
| `README.md:570` (planos 07:142) | "diz ~4,3 s de malharia" | `README.md:642` |
| `README.md:571-573` (planos 12:102) | 64 chunks em ~4,3 s no boot | `README.md:642-643` |
| `README.md:561` (planos 15:81 e 15:323) | ~0,9 s + ~4,3 s publicados | `README.md:642` |
| `README.md:561-562` (planos 15:414) | congelamento de boot já contado | `README.md:642-643` |
| `README.md:501-505` (planos 15:77) | bloco que documenta o passo manual | `README.md:572-577` |
| `README.md:507` (planos 15:397) | "boot do modelo em 9,5 s" | `README.md:579` |
| `README.md:501-514` (planos 15:446) | texto da seção do oráculo | `README.md:552-568` |

Nenhum número da tabela veio de somar deslocamento: cada um foi conferido no texto da linha de chegada.
Ficam onde estavam, porque os dois primeiros commits foram escritos frase por frase com net-linha zero
acima de `:197`: `README.md:148-149` (planos 17:124 e 18:90), `:192` (13:250, 14:200, 15:99) e `:197`
(13:78). Duas re-derivações mudam de moldura, não só de número — a 15:77 achava o passo manual como
único caminho e hoje acha o mesmo bloco de comandos rebaixado a opção, e a 15:446 apontava o texto
antigo da seção. As frases do dossiê são registro da leitura de época e por isso não foram reescritas.

**Furo #26 — as três réguas são cegas a ponteiro de arquivo-raiz, e foi por isso que o dano da 16
passou.** O instrumento de âncoras casa apenas caminhos que comecem em `src/`, `tests/` ou `docs/`
([`tools/check_doc_anchors.py:61-62`](../tools/check_doc_anchors.py#L61-L62)): um `README.md:570-575`
escrito num dossiê não entra na régua 1 nem na 2, e a classe 6 só confere que o arquivo do link existe.
O verificador de citações vê o `README.md:561` pela sua segunda expressão, mas só pergunta se o número
cabe no arquivo — 561 cabe em 708 e em 746, então apodrece em silêncio. Dono: o elo seguinte da fila,
`feat/bicho-cavando-12`, que é quem vai escrever na `main` de novo e vai precisar re-derivar por conta
própria; a correção de instrumento (uma sétima classe, ou estender as duas expressões ao trio
`AGENTS|README|THIRD_PARTY_LICENSES` conferindo a faixa por conteúdo lido) fica com o dono do
repositório, porque mexer no verificador mexe no que toda perna reporta.

**Furo #27 — o status guarda ponteiros de README que são registro de corrida passada e hoje estão fora
de posição.** `:2993`, `:2996`, `:3246` e `:4826` deste arquivo apontam `README.md:505-512`, `:533`,
`:559-566` e `:501-514`, números válidos para a revisão em que aquela corrida foi contada, não para a de
hoje. A regra da casa é não reescrever registro de corrida passada, então ficaram como estavam, e o
instrumento de âncoras não os vê pelo motivo do furo #26. Falta uma convenção — a mesma que já vale para
"prefixo de revisão não é ponteiro vivo" no cabeçalho do instrumento, que é exatamente o que um
`a1405e4:src/entities/wolf.gd` registra. Dono: o dono do repositório escolhe a marca; nenhuma
perna de documento deve reescrever histórico por conta própria.

**As três réguas, medidas nesta ponta.** O instrumento de âncoras, rodado de dentro do worktree — a
raiz sai do caminho do próprio arquivo, então a cópia da raiz mediria a árvore errada:

```
corpus na arvore de trabalho  arquivos: 38  ponteiros conferidos: 2830  rotulos conferidos: 190  links relativos conferidos: 2810
docs/melhorias-status.md:3352  ../.tools/_chk_labels.py  LINK QUEBRADO
casos objetivos: 1
```

O mesmo único caso tolerado de sempre, o link para o verificador de rótulos, que é gitignored. Os dez
ponteiros e o link que faltam para a medida do pouso da 16 são os que este registro escreve: a tabela de
re-derivação acima e o link para o `tools/check_doc_anchors.py`, único lugar do corpus onde um ponteiro de
raiz é conferido por instrumento — e só de existência, que é justamente o furo #26. As citações e os
identificadores, com `AETHER_ROOT` apontando para o worktree e o corpus dos 24 documentos (os 21 dossiês,
este status, `AGENTS.md` e o `README.md`):

```
citacoes com numero de linha conferidas: 2374
arquivos citados que nao existem: 43
numeros de linha fora do arquivo: 0
```

As 43 ausências são o `.tools/` que não existe nesta árvore (gitignore, não ponteiro podre) mais os
caminhos de pernas que ainda não pousaram, como src/ai/reach.gd e
`tests/wolf_multiseed_census_test.gd` — declarados inexistentes pelos próprios dossiês. Nenhuma ausência de
código nova em lugar nenhum: o `README.md` foi de 76 a 90 nomes citados com as mesmas 17 ausências
históricas (nomes de arquivo e SHA, não símbolos de código), os três dossiês alterados têm conjunto de
identificadores **idêntico** ao de `c1e77ad`, conferido por diferença de conjuntos e não por memória, e
este status, de 474 a 490 nomes, ganha quatro ausências que são SHA desta branch — `c1e77ad`, `f5dcb1d`,
`fc559a3` e `fa9059b`, os únicos dos sete que começam por letra — mais nada.

**Esta passada não re-correu a engine, e o motivo é um fato da máquina.** O binário do pin é
`D:\Godot\Godot_v4.7.2-stable_win64.exe`, o caminho que o launcher deste repositório usa, e a
unidade `D:` não está montada nesta sessão — há só `C:`, `E:` e `F:`, e a regra da casa é não caçar
executável. O contrato publicado continua **255 checagens / 0 falhas** na suíte e **240 / 0** no runner
de reações, e vale por **identidade de árvore**: `git rev-parse 9b2c65a:src` =
`64f137bcb1f8e95bd9a64fe7843e4e7b72f7326e` e `:tests` = `88a1541c2f9f6fc3dd0e1d237b3e5656d9eea3c9`, e o
diff de `src/` e `tests/` entre `9b2c65a` e esta ponta devolve vazio — nada desta perna escreve código,
então o número do pin é o número da árvore resultante. **Nenhum gate de fase se fecha aqui**: nada desta
perna toca P0, P1 ou gate nenhum, e o que mudou é apresentação — cujo custo real são os dois furos
abertos acima, não o texto novo.

**Publicação.** Os seis commits acima vão ao `origin` como `docs/apresentacao-readme-21`, e a branch
fica: nenhuma branch é deletada nesta casa sem motivo aberto. O pouso é o `git merge --no-ff` na `main`,
cujo SHA aparece na primeira fila de `git log --first-parent main`, com a régua de âncoras re-corrida na
árvore mergida antes do push e a prova de publicação em `git ls-remote --heads origin` — não no código
de saída do push, que já mentiu aqui.

## Régua da rodada af-bench 07b — saída literal (2026-11-23, worktree `bench/af-bench-boot-walk-07b`)

Publicada no fim do arquivo de propósito: status.md é longo e cheio de ponteiros por número de linha, e
inserir texto no meio desloca tudo abaixo deles. As três réguas foram corridas DENTRO deste worktree
(árvore do pin 9b2c65a), que é a árvore que a rodada mede.

- check_doc_anchors.py: `casos objetivos: 1`. O único caso é um ponteiro relativo que só resolve na árvore
  primária; na árvore primária esta mesma régua devolve 0 casos, então este é o único caso tolerado dentro
  de um worktree. Na primeira passada havia um caso a mais — um ponteiro de doc para doc, do dossiê 01,
  que a nota desta rodada empurrou para uma linha em branco; foi re-derivado por conteúdo antes do publish,
  e agora só o caso tolerado resta.
- verify_plan_cites.py (com AETHER_ROOT apontando para este worktree e o comando rodado de dentro dele,
  contra a readback, este status e o dossiê 07): `numeros de linha fora do arquivo: 0`, exit 0. Os
  arquivos que ela lista como ausentes são o diretório gitignored dos artefatos locais (jornais e logs que
  não são versionados) e os caminhos-armadilha que os próprios dossiês nomeiam como inexistentes.
- verify_plan_ids.py (sobre a readback, este status e os dossiês 01 e 07): exit 0. Os identificadores de
  código que a nota desta rodada cita resolvem em src/; os tokens que ela lista como ausentes são SHAs de
  commit e nomes de ferramenta, a mesma classe que já percorre todo o status.

Nada aqui fecha gate de fase. A rodada só repõe o instrumento e a medição na árvore nova; a prova do
empurrão de hash (da base antiga para a de hoje) está na seção própria da readback e na nota acima.

## Rodada bake-off de voxel 07c — as seis corridas, a decisão e o que não fecha (2026-11-23, `bench/bake-off-voxel-07c`)

Publicada no fim do arquivo pelo mesmo motivo da nota 07b: este status é comprido e cheio de ponteiros por
número de linha, e inserir texto no meio desloca todos abaixo deles. Branch aberta de `main` em `166af71`,
base do contrato `9b2c65a`.

**Feito nesta ponta.** Três commits de substância e nenhuma malharia nova em `src/`:

- `3cbdd4b` — instrumento do custo de edição local: carimbo aberto em
  [`_mark`](../src/world/voxel_world.gd#L330-L342), conta fechada no fim da malha por
  [`_record_edit_cost`](../src/world/voxel_world.gd#L348-L355), agregado por
  [`edit_mesh_cost`](../src/world/voxel_world.gd#L362-L371) e a coluna `edit_mesh` do
  [`diagnostics()`](../src/main.gd#L1231-L1278).
- `e486cd3` — [`tests/af_bakeoff.gd`](../tests/af_bakeoff.gd): braço nomeado na CLI (corrida sem `--arm=`
  não entra em tabela), 11 checagens, rodapé `N checagens M falhas T s`, exit 1 se `M > 0`.
- `9e636ad` — a evidência: [`readback.md`](evidence/af-bakeoff-voxel/readback.md), os seis logs, o patch do
  braço C e `artifacts.sha256` conferido por `sha256sum -c`.
- Docs — o `+50` linhas em `src/world/voxel_world.gd` e o `+4` em `src/main.gd` envelheceram 66 ponteiros em
  18 arquivos (AGENTS.md, os design 07/08/09, `docs/engine/simclock.md`, este status e os dossiês
  01/02/04/07/12/13/14/15/16/17/18/19). Todos re-derivados abrindo o arquivo citado e lendo a declaração,
  nunca somando o delta do diff.

**As seis corridas** (números lidos dos logs, um braço por corrida, serial, máquina livre, engine
`4.7.2.stable.official.ed1daf0bf`, semente `SEED := 20261116`; invariants iguais nos seis: `chunks=64`,
`edits_aceitas=30`, `remeshes=52`, `dropped_ticks=0`, `tick=54`, `corpo=619e891c95dc5b44…`):

| Corrida | exit | `gen_ms` | `mesh_ms` | `triangles` boot | `triangles` lote | count | `worst_us` | `mean_us` | `worst_sim_ms` | rodapé |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `run-A-1` | 0 | 936,826 | 4.226,752 | 214.448 | 214.484 | 52 | 159.256 | 76.979,8 | 8,950 | 11 checagens 0 falhas 7,948 s |
| `run-A-2` | 0 | 953,634 | 4.369,044 | 214.448 | 214.484 | 52 | 162.843 | 78.642,6 | 8,695 | 11 · 0 · 8,163 s |
| `run-A-3` | 0 | 940,838 | 4.304,575 | 214.448 | 214.484 | 52 | 159.437 | 77.062,1 | 9,353 | 11 · 0 · 8,032 s |
| `run-C-1` | 0 | 874,352 | 5.105,775 | 214.448 | 214.484 | 52 | 214.549 | 93.104,1 | 9,627 | 11 · 0 · 9,327 s |
| `run-C-2` | 0 | 871,043 | 4.938,229 | 214.448 | 214.484 | 52 | 200.101 | 91.503,1 | 10,117 | 11 · 0 · 9,109 s |
| `run-C-3` | 0 | 866,339 | 4.949,574 | 214.448 | 214.484 | 52 | 206.364 | 94.472,4 | 9,146 | 11 · 0 · 9,189 s |

Médias **dentro de cada braço** (nunca entre braços): `gen_ms` A 943,77 × C 870,58 (−73,19 ms, −7,75 %);
`mesh_ms` A 4.300,12 × C 4.997,86 (+697,74 ms, +16,23 %); boot `gen+mesh` A 5.243,89 × C 5.868,44
(+11,91 %); custo de edição `mean_us` A 77.561,5 × C 93.026,5 (+15.465 ms, +19,94 %) com pico das três
corridas 162.843 × 214.549 µs (+31,75 %); `worst_sim_ms` 9,00 × 9,63 (+7,0 %). A métrica do gate do dossiê
`mesh_ms + 52·mean_us` dá, corrida a corrida, A 8.229,702 / 8.458,459 / 8.311,804 e C 9.947,188 / 9.696,390 /
9.862,139 ms — médias 8.333,32 × 9.835,24 (+1.501,92 ms, +18,02 %), e as duas distribuições não se tocam: o
pior A fica 14,63 % abaixo do melhor C.

**Decisão:** o braço A continua sendo o default. C não passa da régua — ganha em bytes e em `gen_ms` (o
casaco é `18×66×18` = 21.384 bytes por chunk contra a cópia global de `128×64×128` = 1.048.576) e perde em
tudo que o jogador sente. Vive só como [`arm-c-halo-por-chunk.patch`](evidence/af-bakeoff-voxel/arm-c-halo-por-chunk.patch)
(65 linhas `+`, 27 `-`, base `e486cd3`; branch local `8d9dc97`), e a prova de que nada landou é
`grep -c "_halo" src/world/voxel_world.gd` = 0. B (greedy) segue `[OPEN]` e reabre com ≤ 7.500,0 ms na
mesma métrica em três corridas, o que pede `mesh_ms` ≤ 3.870,1 ms; D segue `[CLAIMED — medição pendente]`.

**O que não fecha.** (1) Gate de fase fecha o dono do repositório, mandato 4 — nada aqui fecha gate nenhum.
(2) `gen_ms`, `mesh_ms` e `worst_sim_ms` desta tabela são do cenário do bake-off (boot + 20 frames de
settling + 30 edições com a fila no `MESH_BUDGET` do produto), não o contrato do boot vivo nem o do
`af-bench` de 12 000 ticks. (3) O instrumento cobra o agregado dos chunks carimbados — 30 edições sujam 52
chunks (`count == remeshes - fila_inicial`) — e não todo caminho de edição: `apply_edits`
([`:238-249`](../src/world/voxel_world.gd#L238-L249)) no boot e no load cai em `mesh_ms`, e a primeira
malharia de um chunk sem `mesh_instance` fica fora da conta porque já é o `mesh_ms`. `pending` foi 0 nos
seis logs; sair com `pending > 0` descartaria latência real. (4) O `triangles` publicado (214.480) é o
diagnóstico **final** da suíte, depois de 13 edições e 147 meshes — o mundo recém-gerado dá 214.448, e os
32 triângulos são o instante, não a discrepância. (5) As alturas que a linha P0 chamava de "certas" (942 ms
de geração, 4682 ms de malha) continuam sem corrida publicada que as sustente; a mesa de hoje dá
936,8–953,6 e 4.226,8–4.369,0 no braço A. (6) A variação "halo só da borda" (4.488 bytes por chunk, 68 das
324 colunas) **não foi medida**, e é ela — não o casaco inteiro — que teria de ser corrida se o mundo
crescesse além de `128×64×128`. (7) Nenhum FPS foi prometido em nenhuma linha desta rodada, e as duas
colunas do critério que continuam sem instrumento são "FPS com 50 mentes HOT" e "shapes não-cúbicos".

**Suíte na ponta da branch:** `255 checagens 0 falhas` — 47,6 s com o instrumento landado
(`suite_instrument.log`) e 47,9 s na ponta (`suite_final.log`), exit 0, e a coluna nova aparece no
diagnóstico final (`suite_final.log:345`: `"edit_mesh":{"count":14,"mean_us":123838.0,"pending":0,"worst_us":226908}`
com `"edits":13, "meshes":147, "triangles":214480`). `src/` da base confere com o pin (`166af71:src` =
`64f137bcb1f8e95bd9a64fe7843e4e7b72f7326e`); `tests/` **não** confere com o `9b2c65a` (`8fbffd907e708c03…`
contra `88a1541c2f9f6fc3…`), diferença que é `tests/af_bench.gd` (+344) e seu `.uid`, do merge do 07b — a
frase do briefing de que `tests/` estava idêntico ao pin não segurou, e o contrato de identidade de
`tests/` com o pin não existe.

## Registro do pouso 07c na `main` — o pin medido no clone limpo e o corpus que a varredura deixou de fora (2026-11-23, `docs/registro-merged-main-07c`, base `cea4379`)

Publicada no fim do arquivo pelo mesmo motivo das duas notas anteriores. A perna é código, então o número
pineado é o do merge medido, não o de um documento em cima dele.

**O pouso.** `git merge --no-ff bench/bake-off-voxel-07c` na `main` → **`cea437959fd0867f65a2d2e2b40663df8dcd753e`**,
pais `166af71` (o pouso do 07b) e `4355935` (a rodada da mesa), **33 arquivos, +1 747/−106**. As árvores:
`git rev-parse cea4379:src` = `100af75ded6d50b6a26120be352cf72770f97e80` e `:tests` =
`77fcb0510525a82d39bb799ff1376ff0fb6eb17b` — diferentes das do `9b2c65a` (`64f137bc…` / `88a1541c…`), como
se esperava de uma perna que escreve instrumento. O código da perna em `src/` são **+4 linhas em
`src/main.gd`** (um bloco `@@ -1172,0 +1173,4 @@`, dentro de `diagnostics()`) e **+50 em
`src/world/voxel_world.gd`** (cinco blocos: `+9 @58`, `+5 @154`, `+6 @284`, `+29 @288`, `+1 @515`), mais o
runner novo `tests/af_bakeoff.gd` (237 linhas) e mais nada em `tests/`. Consequência lida antes de dizer
"testado": `git diff --name-only 166af71 cea4379` fora de `docs/` devolve **5 arquivos** — `AGENTS.md`,
os dois de `src/`, o runner e seu `.uid` — e `tests/smoke_test.gd` **não** está entre eles, então a suíte
continuou em **255** checagens: a coluna nova é checada só dentro do bake-off, em
[`tests/af_bakeoff.gd:152`](../tests/af_bakeoff.gd#L152) (`var cost: Dictionary = diag["edit_mesh"]`), e a
suíte apenas a publica no `diagnostics()`.

**O pin, medido num clone limpo de `cea4379` com `--import` frio, serial, máquina livre** (engine
`4.7.2.stable.official.ed1daf0bf`; nenhum `[FAIL]`, nenhum `SCRIPT ERROR` em nenhuma das seis corridas). As
nove corridas desta mesa e das duas que a seguem estão **versionadas** em
[`docs/evidence/registro-07c/`](evidence/registro-07c/readback.md) — antes cada stdout vivia num diretório
gitignored (`.tools/` ou o clone sob `.qoder/`) e nenhuma pessoa que clonasse o repositório poderia
conferir um número:

| Corrida | saída literal do rodapé | log na branch `docs/evidencia-clone-limpo-07c` |
| --- | --- | --- |
| `--import` frio do clone | exit 0, `[ DONE ] loading_editor_layout`, 0 `SCRIPT ERROR` | [`clean_import.log`](evidence/registro-07c/clean_import.log) |
| suíte | `== 255 checagens  0 falhas  47.6 s de teste ==`, exit 0 | [`suite.log`](evidence/registro-07c/suite.log) |
| runner de reações | `OK censo de checagens \| 240/240` → `240 checagens 0 falhas 24.546 s` | [`runner_reactions.log`](evidence/registro-07c/runner_reactions.log) |
| runner RNG | `OK censo de checagens \| 27/27` → `27 checagens 0 falhas 2.673 s` | [`runner_rng.log`](evidence/registro-07c/runner_rng.log) |
| runner journal | `128 checagens 0 falhas 7/7 testes concluidos 5.582 s` | [`runner_journal.log`](evidence/registro-07c/runner_journal.log) |
| `af_bench` (12 000 ticks) | `16 checagens 0 falhas 45.920 s` | [`bench_clean.log`](evidence/registro-07c/bench_clean.log) |
| `af_bakeoff` braço A | `11 checagens 0 falhas 8.057 s` | [`bakeoff_A_clean.log`](evidence/registro-07c/bakeoff_A_clean.log) |
| suíte na ponta do registro | `== 255 checagens  0 falhas  47.9 s de teste ==` | [`registro_branch_suite.log`](evidence/registro-07c/registro_branch_suite.log) |
| suíte na `main` mergida | `== 255 checagens  0 falhas  47.4 s de teste ==` | [`merged_main_suite.log`](evidence/registro-07c/merged_main_suite.log) |

Duas coisas essa mesa do clone limpo prova, e nenhuma delas é desempenho:

- **o instrumento não moveu a projeção do journal.** A linha de gate do `af_bench` devolve
  `hash_ultima_linha=fd9b41e0dc3ae2eb5f4c76cd6467ffc8d6204134354e5f765fbc1f6f6d604a32` com
  `hashes_distintos=12000/12000` — **o mesmo hash final** das três corridas publicadas na readback do 07b
  ([`docs/evidence/af-bench-boot-walk/readback.md`](evidence/af-bench-boot-walk/readback.md) linhas 65–67).
  O `edit_mesh` novo do `diagnostics()` entra no F3 e no log, não na projeção; `Channel.COUNT`,
  `FORMAT_VERSION`, `GEN_VERSION` e `state_hash()` seguem intocados.
- **a coluna nova aparece no diagnóstico e no clone.** [`docs/evidence/registro-07c/suite.log:345`](evidence/registro-07c/suite.log):
  `"edit_mesh":{"count":14,"mean_us":121496.857,"pending":0,"worst_us":221932}` com
  `"edits":13, "meshes":147, "triangles":214480`. No bake-off do mesmo clone, o braço A deu
  `gen_ms=945.836 mesh_ms=4269.300` e `edit_cost count=52 worst_us=163290 mean_us=78621.4 pending=0` com
  `corpo=619e891c95dc5b44…` — dentro das faixas das três corridas A da mesa da ponta
  (936,8–953,6 ms / 4.226,8–4.369,0 ms / 76.979,8–78.642,6 µs), então a publicação do número não dependeu
  do worktree onde ele foi gerado.

**O que esta passada conserta: o furo #28.** A varredura de 66 ponteiros que a 07c registrou percorreu
[AGENTS.md](../AGENTS.md), os design 07/08/09, [`docs/engine/simclock.md`](engine/simclock.md), este status
e os dossiês 01/02/04/07/12/13/14/15/16/17/18/19 — e **não abriu** [`docs/design/10`](design/10-world-layers-and-block-physics.md),
[`docs/design/11`](design/11-inventory-crafting.md) nem [`docs/planos/06`](planos/06-decompor-main-gd.md).
Como os dois arquivos de `src/` que a perna alongou são justamente os mais citados dessas três páginas,
33 números envelheceram ali e passaram verdes por todas as réguas. Re-derivados **por conteúdo**, abrindo
o arquivo citado e lendo a declaração — nunca somando o delta do diff:

- [`docs/design/10-world-layers-and-block-physics.md`](design/10-world-layers-and-block-physics.md) — 23 linhas.
  Entre elas `set_block` `:251-262`→`:266-277`, o `emit` `:261`→`:276`, `aabb_hits_solid`
  `:300-310`→`:350-360`, o loop de `build_chunk_mesh` `:455-488`→`:504-537`, os materiais
  `:77-82`/`:499-502`/`:503-506`→`:86-91`/`:549-551`/`:553-555`, `_emit_face` `:569-570`→`:619-620`,
  `apply_edits` `:163-173`→`:178-188`, `surface_height` `:401-407`→`:451-457`, e o ponteiro de
  `main.gd` `1152-1163`→`1159-1185`.
- [`docs/design/11-inventory-crafting.md`](design/11-inventory-crafting.md) — 2 linhas (face opaca
  `:463-483`→`:512-532`; vidro `:92-98 … aplicada em :505`→`:101-107 … :555`).
- [`docs/planos/06-decompor-main-gd.md`](planos/06-decompor-main-gd.md) — 5 linhas: a contagem do arquivo
  (`1242`→**1246**, em dois lugares) e as três faixas do bloco de cauda (`diagnostics` `1159-1191`→
  `1159-1195` com 37 linhas, `_build_environment`→`1196-1230`, `state_hash`/CLI/`_exit_tree`→`1231-1246`),
  que a perna 16 já havia deslocado e aqui se re-alignou contra o corpo lido hoje.
- [AGENTS.md](../AGENTS.md) — 1 linha: "`main.gd` é o objeto deus conhecido — **1246** linhas nesta revisão".
- este status — 2 linhas: a tabela de tamanho de arquivos (`main.gd` 1242→**1246**, `voxel_world.gd`
  637→**687**; os outros seis da linha conferidos por `wc -l` na hora) e o ponteiro de `diagnostics()`
  (`1159-1184`→`1159-1191`).

**As réguas, com esta seção já dentro do corpus** (comando literal, número lido da saída):

- `python tools/check_doc_anchors.py` → `corpus na arvore de trabalho  arquivos: 38  ponteiros conferidos:
  2850  rotulos conferidos: 197  links relativos conferidos: 2845` / **`casos objetivos: 0`**. A mesma
  régua, corrida num worktree descartável de `cea4379` **antes** das correções desta passada, devolveu
  `38 · 2844 · 197 · 2830` com **`casos objetivos: 1`** — o `docs/melhorias-status.md:3340 →
  ../.tools/_chk_labels.py`, gitignored, que só resolve na árvore primária. Os dois números importam
  juntos: entre a árvore-base e a corrigida, **com esta seção ainda fora**, as contagens não se mexeram —
  `2844 · 197 · 2830` dos dois lados, porque trocar número não cria nem destrói ponteiro — e o caso que
  sumiu é o de sempre, explicado pela árvore, **não** por esta passada. As 33 re-derivações abaixo passaram
  pelas duas réguas sem que nenhuma dissesse nada: é o furo #28. Os **+6 ponteiros e +15 links** de agora
  são os desta seção.
- `python .tools/verify_plan_cites.py docs/planos/*.md docs/design/*.md docs/engine/*.md
  docs/melhorias-status.md AGENTS.md README.md` → **2 661** citações com número de linha conferidas,
  **34** arquivos citados que não existem, **`numeros de linha fora do arquivo: 0`**, exit 0. Rodada na
  árvore-base, com `AETHER_ROOT` no worktree: **2 643** conferidas, **64** arquivos ausentes e **o mesmo
  `fora do arquivo: 0`** — a segunda metade da prova de que o instrumento não vê o defeito. As duas listas
  de ausentes foram postas lado a lado (`comm` sobre os `FALTA` das duas corridas): a base tem **31** a mais
  e os 31 são `.tools/` — **27** linhas de log de corrida e **4** de `shot_gallery.gd`/`.tscn` — que existem
  no disco desta árvore (o `.tools/` é gitignored, mas esta máquina carrega **703** `.log` e os
  `shot_gallery.*` dele — 1 247 entradas no total) e não existem num worktree limpo. Restam **3** aqui: os `_head_{agents,readme,status}.md` que o pouso da 16 copiou para
  medir e depois removeu, citados no parágrafo que diz exatamente isso. Como nada de `.tools/` é versionado,
  um **clone limpo** reportaria os 34 inteiros. Esta árvore tem **1** a mais que a base e é artefato desta
  página: ao listar os nomes ausentes, o parágrafo os cita. Os outros **33** são 20 caminhos `[TARGET]` que
  os próprios dossiês declaram inexistentes (`src/core/sim/tick_clock.gd` ×7,
  `tests/wolf_multiseed_census_test.gd` ×3, `src/ai/reach.gd` ×3, `src/core/sim/entity_store.gd` ×3 e 13
  avulsos do design 07) mais os **3** `_head_*.md` de cima. O `README.md` e a linha 07 do índice de dossiês
  entraram no corpus desta vez.
- `docs/planos/README.md`: a linha 07 trazia o nome único provisório `bench/af-bench-bakeoff-07`; passa a
  listar as três branches reais na ordem em que pousaram — `docs/engine-simclock-07a` (`c1e77ad`),
  `bench/af-bench-boot-walk-07b` (`166af71`), `bench/bake-off-voxel-07c` (`cea4379`).

**Furo #28 — a régua não vê ponteiro de prosa em faixa, e a varredura de perna não lista os documentos.**
Duas falhas de instrumento, uma só consequência. (a) Das seis classes objetivas de
[`tools/check_doc_anchors.py`](../tools/check_doc_anchors.py), nenhuma marca um ponteiro escrito como prosa
(`voxel_world.gd:273`) quando o número-alvo **continua dentro do arquivo e continua não-branco**: um `+N`
desloca a declaração, o ponteiro passa a apontar para outra linha válida, a régua fica verde e o documento
mente. É outra face do #26 — aquele é a **base de arquivos** (a régua só percorre `src|tests|docs`); este é
a **classe de defeito**, e vale dentro do corpus. (b) A lista de documentos a re-derivar saiu do que a perna
lembrou de abrir, não de `git grep -l "voxel_world.gd" docs` — por isso as três páginas ficaram de fora.
Dono: `tools/check_doc_anchors.py`, arquivo que nenhuma perna da fila escreve; entra como débito de
instrumento, não como tarefa de gameplay. A metade (b) é rotina e vale desde já: quem escreve `+N` em `src/`
re-deriva por conteúdo **todos** os documentos que citam o arquivo, com a lista saindo do `git grep`, não da
memória. A metade (a) pede um corredor de teste que não existe: conferir que a linha `N` contém o
identificador backticado do próprio ponteiro — e um instrumento sem teste é o que o mandato 6 cobra antes
de virar código. Enquanto (a) não existir, nenhum `casos objetivos: 0` quer dizer "nenhum ponteiro velho".

**O que nada disso fecha.** (0) Primeiro, a identidade de árvore que faz o número acima valer para este
registro: `docs/registro-merged-main-07c` é documento puro, e `git rev-parse HEAD:src` / `HEAD:tests` nela
devolvem `100af75d…` / `77fcb051…` — as mesmas do `cea4379` medido no clone limpo. Nenhuma linha de código
desta branch, portanto o contrato **255 / 0** se transmite por identidade de árvore e não por corrida nova.
A suíte foi re-rodada na ponta ainda assim: **`== 255 checagens  0 falhas  47.9 s de teste ==`**, exit 0,
zero `[FAIL]` e zero `SCRIPT ERROR` — o stdout inteiro está em
[`docs/evidence/registro-07c/registro_branch_suite.log`](evidence/registro-07c/registro_branch_suite.log)
(copiado de `.tools/_reg07c_suite.log`, que por ser gitignored não sobreviveria a nenhum clone). (1) Gate
de fase fecha o dono do repositório (mandato 4). (2) A 07c não troca
malhador nenhum: o braço A continua o default, C vive só como patch, B e D seguem `[OPEN]`/`[CLAIMED]`.
(3) `edit_mesh` é o remesh referenciado por edição, não o caminho de edição inteiro — `apply_edits`
([`:238-248`](../src/world/voxel_world.gd#L238-L248)) no boot e no load cai em `mesh_ms`, e a primeira
malharia de um chunk sem `mesh_instance` fica fora da conta. (4) As alturas que a linha P0 chamava de
"certas" (942 ms / 4.682 ms) continuam sem corrida publicada que as sustente. (5) Nenhum FPS em nenhuma
linha. (6) `tests/audio_test.gd.uid` e `tests/audio_live_probe.gd.uid` continuam fora do git (#25, decisão
do dono) — e são os dois `??` que todo clone limpo mostra. (7) O #28 fica **aberto**: as 33 correções desta
passada foram achadas por leitura humana, não pelo instrumento, e a régua continuava verde antes delas.
(8) A fila viva passa a **12 → 17 → 18 → 20 → 13**; o elo da frente, `feat/bicho-cavando-12`, nasce vermelho
porque `block_changed` ([`:6`](../src/world/voxel_world.gd#L6), emit em
[`:336`](../src/world/voxel_world.gd#L336)) ainda não tem consumidor nenhum em `src/`.

**A `main` mergida.** `git merge --no-ff docs/registro-merged-main-07c` →
**`f7fef9774b545aeec53dee3fb09f9a63340d0f8f`**, pais `cea4379` e `9a2c510`, **6 arquivos, +178/−35**, todos
`.md`. As árvores da resultante são `git rev-parse HEAD:src` = `100af75ded6d50b6a26120be352cf72770f97e80` e
`HEAD:tests` = `77fcb0510525a82d39bb799ff1376ff0fb6eb17b` — **as mesmas do `cea4379`**, porque esta perna não
escreve uma linha de código: o contrato do clone limpo (255 / 0) vale para `f7fef97` por identidade de
árvore, e não por herança de prosa. Ainda assim a suíte foi re-rodada na `main` mergida, com a máquina
livre e nenhum processo do engine antes dela: **`== 255 checagens  0 falhas  47.4 s de teste ==`**, exit 0,
zero `[FAIL]`, zero `SCRIPT ERROR` — o stdout está versionado em
[`docs/evidence/registro-07c/merged_main_suite.log`](evidence/registro-07c/merged_main_suite.log), copiado de
`.tools/_reg07c_main_suite.log`. As duas réguas, corridas na mesma árvore, devolvem o número desta
seção sem tremedeira: `python tools/check_doc_anchors.py` → `38 arquivos · 2 850 ponteiros · 197 rótulos ·
2 845 links · casos objetivos: 0`, e `python .tools/verify_plan_cites.py docs/planos/*.md docs/design/*.md
docs/engine/*.md docs/melhorias-status.md AGENTS.md README.md` → **2 661** conferidas, **34** ausentes,
**`numeros de linha fora do arquivo: 0`**. Publicação conferida com `git ls-remote --heads origin`:
`refs/heads/main` = `f7fef9774b545aeec53dee3fb09f9a63340d0f8f` e
`refs/heads/docs/registro-merged-main-07c` = `9a2c51008ca394b60396a1ff5efa46d447d06588` — nenhuma branch
apagada, local ou remota. O **#28 continua aberto**: o `casos objetivos: 0` de cima é a régua que não vê o
defeito que esta seção documenta, e a metade (a) dele — conferir que a linha apontada contém o identificador
do ponteiro — ainda não tem instrumento nem corredor de teste.

**Os stdout do registro viram artefato versionado.** A branch `docs/evidencia-clone-limpo-07c`, aberta de
`b1e1dd4`, acrescenta **14 arquivos** em
[`docs/evidence/registro-07c/`](evidence/registro-07c/readback.md): os **dez** stdout literais que as três
mesas acima citavam (seis do clone limpo de `cea4379`, o `--import` frio dele, as duas suítes que estavam
em `.tools/` e a suíte re-rodada nesta ponta — `== 255 checagens  0 falhas  47.6 s de teste ==`, exit 0, com
a máquina checada livre antes dela), as **duas** réguas re-corridas nesta árvore, a `readback.md` com o
comando e os rodapés, e o `artifacts.sha256`. O motivo é o mandato 1 e o item 6 do ciclo: até aqui cada um
desses logs morava num
diretório gitignored (`.tools/` ou o clone sob `.qoder/`), então nenhum clone do repositório poderia
conferir um número desta seção — a mesa estava *publicada* mas não estava *checkável*. Na prosa isto muda
quatro ponteiros: a tabela do pin ganha a coluna do arquivo arquivado, `suite.log:345` passa
[`docs/evidence/registro-07c/suite.log:345`](evidence/registro-07c/suite.log) (linha conferida: a coluna
`edit_mesh` está lá, `count=14 mean_us=121496.857 worst_us=221932`), e as duas menções a
`.tools/_reg07c{,_main}_suite.log` apontam para a cópia versionada, com o log original nomeado ao lado.

Nada de código: `git diff --name-only b1e1dd4..HEAD -- src tests` devolve vazio e as árvores desta ponta são
`100af75ded6d50b6a26120be352cf72770f97e80` / `77fcb0510525a82d39bb799ff1376ff0fb6eb17b` — as mesmas do pin
medido no clone, logo o contrato **255 / 0** se transmite por identidade de árvore. As duas réguas, corridas
**com esta pasta e este parágrafo já dentro da árvore** (o comando é o de sempre, literal na `readback.md`):
`python tools/check_doc_anchors.py` → `38 arquivos · 2 850 ponteiros · 197 rótulos · 2 860 links · casos
objetivos: 0`, e `python .tools/verify_plan_cites.py docs/planos/*.md docs/design/*.md docs/engine/*.md
docs/melhorias-status.md AGENTS.md README.md` → **2 663** conferidas, **34** ausentes,
**`numeros de linha fora do arquivo: 0`**, exit 0. Os deltas contra a `main` de cima (2 845 / 2 661) são os
desta passada e têm explicação lida nos regulares: **+15 links relativos** porque os arquivos agora existem
como alvo de link, **+2 citações conferidas** (os dois caminhos `…/registro-07c/suite.log:345` que eram
prosa solta e passaram a caminho resolvível) e **zero** em ponteiros e rótulos — as duas classes do
instrumento só aceitam alvo `.gd`/`.md`, então um link para `.log` é conferido como *arquivo*, nunca como
*linha*. O `34` de ausentes não cai: as dez cópias desta
pasta não substituem os logs de rodadas antigas que continuam citados por `.tools/` (`suite_fix1.log` …
`suite_fix4.log`, `shot_gallery.*`, os três `_head_*.md`) e esses **não** foram arquiveados aqui — ficam
como o resto do débito de instrumento. O **#28 continua aberto**, com a mesma cara: `casos objetivos: 0`
nesta árvore verde não diz que não há ponteiro velho, diz que a régua não procura esse caso.

## A `main` mergida da evidência — o pouso re-medido e a régua que não entra na pasta que ela versiona (2026-11-23, `docs/registro-evidencia-merge-07c`, base `5178c5a`)

**O pouso.** `git merge --no-ff docs/evidencia-clone-limpo-07c` →
**`5178c5ad9a7efe8283b67bb9cbf04da3774b73ed`**, pais `b1e1dd4` (o registro da `main` mergida do `f7fef97`) e
`214df5c` (a ponta da evidência), **15 arquivos, +2 738/−12**, todos `docs/`: os **14** de
[`docs/evidence/registro-07c/`](evidence/registro-07c/readback.md) mais as 69 linhas desta página. Nenhuma
linha de código — `git diff --name-only b1e1dd4..5178c5a -- src tests` devolve vazio e
`git rev-parse 5178c5a:src` / `5178c5a:tests` respondem `100af75ded6d50b6a26120be352cf72770f97e80` /
`77fcb0510525a82d39bb799ff1376ff0fb6eb17b`, **as mesmas duas árvores** do pin `cea4379` medido no clone limpo
e as mesmas do `f7fef97`. O contrato **255 / 0** chega a `5178c5a` por identidade de árvore, não por herança
de prosa, e nada nesta perna pede re-corrida de gate.

**A suíte re-rodada no pouso — agora versionada.** Comando da casa, máquina livre conferida antes do
`spawn banda 1` e com nenhum processo do engine vivo:
`godot --headless --path . tests/smoke_test.tscn` na `main` em `5178c5a` devolve
**`== 255 checagens  0 falhas  47.6 s de teste ==`**, exit 0, **zero** `[FAIL]`, **zero** `SCRIPT ERROR`. O
stdout inteiro está em
[`docs/evidence/registro-07c/merged_main_5178c5a_suite.log`](evidence/registro-07c/merged_main_5178c5a_suite.log),
copiado de `.tools/_evid07c_main_suite.log` (os mesmos 24 024 bytes dos dois lados; o rodapé é a linha 357).
É a primeira vez que um rodapé de `main` mergida sai de `.tools/`: o `merged_main_suite.log` do parágrafo
anterior veio de uma corrida gravada **só com stdout**, e por isso o par do quit aparece aqui —
[`:358`](evidence/registro-07c/merged_main_5178c5a_suite.log)
`WARNING: 4 ObjectDB instances were leaked at exit`, [`:360`](evidence/registro-07c/merged_main_5178c5a_suite.log)
`ERROR: 2 resources still in use at exit` — e não aparece lá. O par não se mexeu entre as três ocorrências
versionadas (clone limpo `suite.log:358-360`, ponta da evidência `evidence_branch_suite.log:358-360`, pouso
`:358-360`): mesmo `4`, mesmo `2`. Isso não atribui nada — a atribuição continua débito aberto — mas deixa de
ser uma afirmação sobre a máquina desta casa: `sha256sum -c artifacts.sha256` dentro da pasta confere os
quatro arquivos antes de qualquer um dos dois números.

**As réguas, na base e na ponta, com as duas corridas arquivadas.** Na `main` de `5178c5a`, **antes** desta
seção: `python tools/check_doc_anchors.py` → `38 arquivos · 2 850 ponteiros · 197 rótulos · 2 860 links ·
casos objetivos: 0` e `python .tools/verify_plan_cites.py docs/planos/*.md docs/design/*.md docs/engine/*.md
docs/melhorias-status.md AGENTS.md README.md` → **2 663** conferidas, **34** ausentes, **`numeros de linha
fora do arquivo: 0`** — as duas, exatamente os números de `214df5c`, e isso é conferível sem memória:
`git rev-parse 5178c5a^{tree}` e `git rev-parse 214df5c^{tree}` respondem o mesmo
`efa873e67553817a01687780a1898f4f8a136580`, porque o merge não reescreve documento nenhum. Na ponta desta branch, com esta seção e os quatro arquivos novos dentro
do corpus: `python tools/check_doc_anchors.py` → **`38 arquivos · 2 854 ponteiros · 197 rótulos · 2 871
links · casos objetivos: 0`**, exit 0, e a régua de citações → **2 669** conferidas, **34** ausentes,
**`numeros de linha fora do arquivo: 0`**, exit 0. Os dois stdout estão versionados em
[`ruler_doc_anchors_tip.log`](evidence/registro-07c/ruler_doc_anchors_tip.log) e
[`ruler_plan_cites_tip.log`](evidence/registro-07c/ruler_plan_cites_tip.log). Cada delta tem a lista que o
produz, obtida rodando as próprias expressões da régua sobre o texto desta seção:
**+4 ponteiros** = os dois `LINK` (`../src/world/voxel_world.gd#L6`, `../src/world/voxel_world.gd#L288`) e as
duas ocorrências de `tests/af_bakeoff.gd:152` no `BARE`; **+11 links** = os onze `\[…\]\(…\)` que a seção
abre (três para os logs novos da ponta, três para o `merged_main_5178c5a_suite.log` — o caminho e as duas
faixas `:358`/`:360` —, dois para a `readback.md`, um para a régua, um para cada faixa de `voxel_world.gd`);
**+0 rótulos** porque nenhum dos onze rótulos é símbolo de código —
são `:6`, `:276`, `:358`, `:360`, `:89` e caminhos; **+6 citações** = as duas âncoras do `voxel_world.gd`
contadas cada uma em **dois** lugares — a lista aqui e o item (8) do fecho — mais as duas de
`af_bakeoff.gd:152` (a lista e o parágrafo do #29). A régua de citações aceita a forma `#L` também em código
inline, onde a de âncoras só conta o `:NNN` solto ou o link `\](…#L…)`: a frase que explica o delta é ela
mesma dois dos seis números que explica. Duas coisas ficam claras com a lista na mão: o `tools/check_doc_anchors.py:89` que
esta seção escreve **não é conferido por nenhuma das duas** — o conjunto de prefixos aceito é
`src|tests|docs|assets|.tools` com sufixo `.gd|md|log|…`, e `.py` está fora — e o `casos objetivos: 0` desta
ponta foi **um** na primeira corrida das réguas: o link para `ruler_plan_cites_tip.log` apontava para um
arquivo que o `>` do próprio redirecionamento ainda não tinha escrito. A régua pegou, a segunda corrida
deixou de pegar, e o caso só sumiu porque o arquivo passou a existir — verde por sequenciamento, não por
construção. A suíte re-rodada nesta ponta, depois de arquivar os quatro arquivos, fecha com
**`== 255 checagens  0 falhas  47.5 s de teste ==`** e exit 0
([`registro_tip_suite.log`](evidence/registro-07c/registro_tip_suite.log)), com o par do quit outra vez em
`:358`/`:360` — quarta testemunha, mesmos `4` e `2`.

**Furo #29 — nenhuma das duas réguas entra em `docs/evidence/`.** A pasta versionada por esta rodada é
justamente a que o instrumento ignora: [`tools/check_doc_anchors.py:89`](../tools/check_doc_anchors.py#L89)
faz `dirnames[:] = [d for d in dirnames if d != "evidence"]` antes de caminhar `docs/`, e o corpus da régua
de citações é a lista passada na linha de comando — `docs/planos`, `docs/design`, `docs/engine`, o status,
`AGENTS.md`, `README.md` — onde `docs/evidence` nunca aparece. Consequência medida nesta árvore: os
[`docs/evidence/registro-07c/`](evidence/registro-07c/readback.md) arquivados carregam **dois** ponteiros de
código que **nenhum** instrumento conferiu — `tests/af_bakeoff.gd:152` e `bt_tree.gd:130-137`. Ambos foram
abertos e lidos nesta passada e conferem (`diag["edit_mesh"]` na primeira, o `tick()` com
`Time.get_ticks_usec()` e o `return BtStatus.FAILURE` na faixa), mas isso é leitura humana, exatamente o
de que o #28 trata, agora com a dimensão de **corpus** além da dimensão de **classe**: o `38 arquivos`
de cima é o corpus *sem* a evidência. Dono: `tools/check_doc_anchors.py`, o mesmo arquivo do #28, e o corte
é dele decidir — incluir `docs/evidence/**/readback.md` no walk custa poucos segundos de régua e faria os
dois ponteiros acima passarem a ser conferidos a cada corrida. Enquanto isso, todo número publicado dentro de
uma `readback.md` vale o que vale uma citação lida à mão.

**Publicação.** `git ls-remote --heads origin` confere, nesta ordem: `refs/heads/main` =
`5178c5ad9a7efe8283b67bb9cbf04da3774b73ed` (o pouso da evidência, já no ar antes desta seção ser escrita) e
`refs/heads/docs/evidencia-clone-limpo-07c` = `214df5c4a8e26c6b81f5d2e5a83aa7fb46c85884`. Nenhuma branch foi
apagada, local ou remota. O `merge --no-ff`
desta ponta é o último commit da 07c na primeira fila do log: depois dele,
`git log --first-parent main` responde o que a rodada fez sem abrir diff nenhum, que é o motivo do item 4 de
**Branches**, e o SHA dele fica lá — esta seção descreve a revisão em que foi medida, não a que ela produz.

**O que nada disso fecha.** (0) Gate de fase fecha o dono do repositório (mandato 4); nenhum dos números
desta seção encerra P0 ou P1. (1) A 07c não troca malhador nenhum: braço **A** continua o default, **C**
vive só como patch, **B** e **D** seguem `[OPEN]`/`[CLAIMED]`. (2) `edit_mesh` continua sendo o remesh
referenciado por edição, não o caminho de edição inteiro. (3) As alturas da linha P0 (942 ms / 4.682 ms)
continuam sem corrida publicada. (4) Nenhum FPS em nenhuma linha. (5) Os `.uid` de `tests/` continuam fora do
git (#25, decisão do dono) e são os dois `??` que todo clone limpo mostra. (6) O **#28** fica aberto, com o
par do #29 ao lado: as réguas desta seção passam verdes numa árvore onde a evidência não é corpus. (7) A
atribuição do par de vazamento do quit continua aberta, agora com quatro testemunhas versionadas. (8) A fila
viva continua **12 → 17 → 18 → 20 → 13**, com `feat/bicho-cavando-12` na frente e nascendo vermelha porque
`block_changed` ([`:6`](../src/world/voxel_world.gd#L6), emit em
[`:336`](../src/world/voxel_world.gd#L336)) não tem consumidor nenhum em `src/`.


## Rodada Cavar 12 — a pata que escreve no mundo, medida commit a commit e no clone limpo (2026-11-23, `feat/bicho-cavando-12`, base `dcbcbe8`, ponta de código `d80ac20`)

Publicada no fim do arquivo pelo mesmo motivo das notas 07b e 07c: este status é comprido e cheio de
ponteiros por número de linha, e inserir texto no meio desloca todos os abaixo deles. Branch aberta da
`main` em **`dcbcbe823e6202750803cbfb3e84420553fc8185`** (o registro do pouso da evidência 07c), ponta de
código **`d80ac207e9c33021944752ab9535e723c95b8bbc`**.

**O que a perna muda no mundo.** Antes dela, os únicos dois `set_block` de gameplay do repositório eram os
do jogador ([src/entities/player.gd:685](../src/entities/player.gd#L685) e
[`:711`](../src/entities/player.gd#L711)) — nenhum bicho escrevia no mundo, e era exatamente esse o buraco
que a extensão de 2026-11-20 autorizou. Hoje há um **terceiro** caminho de escrita, e ele não nasce de
nenhum input: a pata do lobo abre voxel. A cláusula do §1 do dossiê — "o mundo tem de registrar isso" — é
o que a checagem 8 paga por número, não por intenção.

**Feito: sete commits de código, um assunto cada, com a corrida do próprio commit na mensagem dele.**

| commit | o que entra | censo do runner | runner medido | código (`+`/`−`) |
| --- | --- | --- | --- | --- |
| base `dcbcbe8` | — | 240 | 240 / 0 no pin `9b2c65a` | — |
| `3d5cdcf` (a) | a colheita de malha entra no runner, **sem** cavar | 247 | 247 / 0 / 30,0 s | tests +114/−1 |
| `e312f58` (b) | a pata existe: alvo pela geografia do corpo, lista de material, procedência | 261 | 261 / 0 / 31,408 s | voxel_body +12/−4, wolf +151/−1, tests +266/−3 |
| `ca88f75` (c) | a checagem 5 decide `DIG_STEPS_BEFORE` por número | 267 | 267 / 0 / 31,686 s | wolf +11/−4, tests +152/−5 |
| `24d64a8` (d) | a pata deixa o MESMO `WORK` da lavra | 271 | 271 / 0 / 31,361 s | wolf +14/−0, tests +151/−14 |
| `ea78b1a` (e) | quem chega farejando entrega o bloco à pata (ramo (b) do nariz) | 275 | 275 / 0 / 31,583 s | wolf +101/−11, tests +198/−6 |
| `51fc386` (f) | o buraco atravessa o save: 4 178 chaves viram 4 179 | 279 | 279 / 0 / 32,531 s | wolf +8/−0, tests +171/−8 |
| `d80ac20` (g) | a pata não custa um `randi()` da sessão | 283 | 283 / 0 / 32,742 s | tests +111/−8 |
| fecho (h) | clone limpo, evidência versionada, corpus re-derivado | 283 | 283 / 0 / 33,194 s | **nenhuma linha** |

Somando os sete: `src/entities/wolf.gd` **+277/−8** (1 218 → 1 487 linhas), `src/entities/voxel_body.gd`
**+12/−4** e `tests/aether_reactions_test.gd` **+1 119/−1** (4 396 → 5 514) — conferido por
`git diff --numstat dcbcbe8..d80ac20 -- src tests`, que é a conta do lote inteiro, não a de um commit.
O censo sobe 240 → 247 → 261 → 267 → 271 → 275 → 279 → 283 (**+43**), e a **suíte continua 255** porque o
lote escreve no runner de reações, não em `tests/smoke_test.gd`: mudar um número de censo sem re-medir é
exatamente o que o mandato 3 proíbe, e por isso cada linha acima tem a corrida do próprio commit.

**O que o código faz hoje, com os ponteiros re-derivados nesta árvore.**

- O alvo tem **dois ramos** e um só acumulador. O do empurrao é re-derivado pela geometria do corpo em
  [`_dig_cell`](../src/entities/wolf.gd#L1090), armado pelo terceiro ramo do `if` de bloqueio
  ([`:1239-1254`](../src/entities/wolf.gd#L1239-L1254), o `_dig_arm()` em `:1254`); o do nariz é **entregue**
  no fim da inspeção ([`:599-600`](../src/entities/wolf.gd#L599-L600)) e vive em `_dig_scent`
  ([`:274`](../src/entities/wolf.gd#L274)) separado de `_dig_pos`
  ([`:262`](../src/entities/wolf.gd#L262)) porque no tick da entrega o `want` está zerado e re-derivá-lo
  pela faixa do corpo descartaria o compromisso no passo em que ele nasce.
- A validade é **lista de material + procedência**:
  [`_dig_ok`](../src/entities/wolf.gd#L1065-L1066) exige `DIG_MATERIALS`
  ([`:110-115`](../src/entities/wolf.gd#L110-L115): neve, areia, terra, grama) **e**
  `not world.edits.has(p)`. É por essa segunda cláusula que o **furo #22** (a lista de bancadas tem um
  único comprador, e um bicho que removesse uma `BENCH` deixaria `bench_positions()` apontando para o ar)
  fica fechado **por construção**, sem permissão nova e sem linha `if kind == BENCH`.
- Dureza é **tempo, não permissão**: depois dos 8 passos de empurrão (`DIG_STEPS_BEFORE`
  [`:129`](../src/entities/wolf.gd#L129)) o [`_dig_step`](../src/entities/wolf.gd#L1147-L1198) soma `dt`
  contra `BlockDefs.hardness`, a mesma grandeza que o jogador soma contra `target_hardness`
  ([player.gd:663-664](../src/entities/player.gd#L663-L664)). Por isso `STONE 0,95` **cai** se estiver na
  lista — e não está.
- A escrita é registrada: `world.set_block(_dig_pos, AIR, true)`
  ([`:1192`](../src/entities/wolf.gd#L1192)) e o imprint vai para o **centro do voxel**
  ([`:1197`](../src/entities/wolf.gd#L1197)), o mesmo offset do `acted.emit` do jogador
  ([player.gd:690](../src/entities/player.gd#L690)), para que as duas origens caiam na MESMA célula de
  Éter — `DIG_WORK` é 0,42 ([`:138`](../src/entities/wolf.gd#L138)), nenhum canal novo, nenhum valor próprio.
- Roda no **fim do `sim_step`** ([`:913`](../src/entities/wolf.gd#L913)), depois de
  `_resolve_dry_target()` e **fora** dos 400 µs do `SubtreeGuard`: o orçamento é da árvore, não do corpo, e
  escrever no mundo dentro dele mudaria o número que `tree_stats()` publica.
- A obra é transitória, o mundo não: os quatro campos voltam ao nada pelo
  [`_dig_reset()`](../src/entities/wolf.gd#L1132-L1136) chamado no `load_state`
  ([`:1416`](../src/entities/wolf.gd#L1416)) — o disco grava a cova, não a intenção de cavá-la.
- Quem cava é **quem alcança**: o predicado vem de `step_reach()`
  ([voxel_body.gd:161-162](../src/entities/voxel_body.gd#L161-L162)), derivado de `dims`, então filhote e
  adulto sobem e escavam na mesma distância. Nenhuma linha `if fase == ADULTO`.

**As nove checagens e o número que cada uma paga** (linhas literais de
[`clone_runner_reactions.log`](evidence/bicho-cavando-12/clone_runner_reactions.log), corrida do clone limpo
do fecho):

1. `lobo_cava_sem_input_do_jogador` — `chaves_air=2 bocas=2` e `work_acesos=2` com valor
   `0.83999997377396` nas duas células [`:490-491`](evidence/bicho-cavando-12/clone_runner_reactions.log#L490-L491).
2. `cavar_respeita_a_lista` — quatro materiais cavados (neve no tick 28, areia 30, terra 30, grama 31) e
   **dois recusados por material, não por tempo**: pedra (`0,95`) e **vidro (`0,10`, mais mole que a neve)**
   com `bocas=0 ticks=200` [`:493-498`](evidence/bicho-cavando-12/clone_runner_reactions.log#L493-L498).
   A premissa ao lado exige `recusas=2 encostadas=true horizontais_min=555 ticks_min=200` — recusa que
   encosta no muro, não desistência antes dele.
3. `work_de_bicho_nao_confundido` — `pata=0.420000 jogador=0.420000 esperado=0.420000` na MESMA célula
   etérea `(14, 12, 13)`, e o nariz lendo a mesma força dos dois lados (`0.147000`)
   [`:509-511`](evidence/bicho-cavando-12/clone_runner_reactions.log#L509-L511). É a checagem que decide o
   desenho: ou a curva distingue por canal/origem já existente, ou o texto deixaria de dizer que WORK é
   pegada do jogador.
4. `colheita_de_malha_sem_cavar` — as sete linhas do instrumento [`:520-526`](evidence/bicho-cavando-12/clone_runner_reactions.log#L520-L526)
   e o rodapé da mesa, discutidos abaixo na tabela das três corridas.
5. `abrir_passagem_depois_de_bloqueio` — os dois sentidos do ciclo de trabalho: **sem** a pata o corredor de
   neve prende os 200 passos; **com** a pata o mesmo lobo atravessa em 76 (`boca_no_tick=28`)
   [`:504-508`](evidence/bicho-cavando-12/clone_runner_reactions.log#L504-L508). O controle de pedra fora da
   lista prende pelo MESMO número (`pedra=200 passos neve_registrada=200 passos travessia=76`), então a
   travessia é da pata e não do tempo; e o `maior_run=13` dentro de `runs=3` é o que decide
   `DIG_STEPS_BEFORE = 8` por número.
6. `entrada_de_rastro_exposta_no_chao_lido` — `primeiro_alvo_no_tick=40 == examinado_no_tick=40` com
   `empurrao antes da entrega=0 quadros`, a boca no tick 53, `alvo trocado=0`, e o chão lido descendo
   **exatamente um bloco** (`y antes=51.600 depois=50.600 delta=1.000`) com o passo seguinte ainda
   `investigate` [`:512-515`](evidence/bicho-cavando-12/clone_runner_reactions.log#L512-L515). O fundo de obra
   imprime, sem esconder, que nos 13 passos o corpo patrulha e empurra a própria tampa: os dois ramos queriam
   o mesmo buraco.
7. `cavar_nao_toca_construcao_alheia` — `bancada=... chave=true valor=22 bocas=1 bocas_tem_bancada=false`
   com a obra saindo na terra do lado, e o par de proveniência `edits_gerada=0 edits_registrada=45`
   [`:499-502`](evidence/bicho-cavando-12/clone_runner_reactions.log#L499-L502): os dois braços mudam **só** a
   procedência, mesmo `DIRT`, mesma coluna.
8. `cavar_sobrevive_ao_save` — entre as duas escritas do produto, `disco_sem=4178 disco_com=4179 novas=[58,51,54]`:
   exatamente **uma** chave, a da boca, e `edits do mundo=4179` batendo com o disco
   [`:532-533`](evidence/bicho-cavando-12/clone_runner_reactions.log#L532-L533). O preço em bytes é o tamanho
   de uma entrada: `82753 -> 82786 (delta +33)`. A obra começada **não** volta (`antes: alvo=(58,51,54)
   passos=11 acumulo=0.150` → `depois: (-999,-999,-999) 0 0.000`), e a premissa [`:528`](evidence/bicho-cavando-12/clone_runner_reactions.log#L528)
   mostra `chaves de dig no state_dict=[]`. O par que faz a terceira linha poder falhar pelo motivo certo é a
   tampa de neve ao lado, montada com `record = false`: sem chave no disco, volta como relevo gerado.
9. `cavar_nao_consome_rng_da_sessao` — `randi_previsto=2762692978 == randi_depois=2762692978` nos **dois**
   braços (`passos_neve=28`, `passos_pedra=200`), `armadas_com_rearm == armadas == 1` com o detour do armar
   lido junto (`0.871`), e o braço de pedra mostrando o sorteio **sem nenhuma pata armada**
   (`armadas=0 rearms=17 detour em [-1.221, 1.290]`)
   [`:516-519`](evidence/bicho-cavando-12/clone_runner_reactions.log#L516-L519). A faixa é exigência do braço
   de pedra: na neve a parede de duas filas desemperta uma vez, e "faixa, não ponto" simplesmente não existe
   lá — empurrar a exigência de um braço para o outro resolveria o vermelho sem medir nada.

**A colheita de malha do §4, três corridas do mesmo instrumento.** O palco remove um voxel por lobo do censo
do boot, em chunks distintos, e drena a fila pelo caminho do produto:

| corrida | boot | fila do palco | lote | `edit_cost` |
| --- | --- | --- | --- | --- |
| clone `d80ac20` [`:527`](evidence/bicho-cavando-12/clone_runner_reactions.log#L527) | 64 chunks / 4 624,1 ms | 26 remeshes em 13 frames | 5 edições em 3 frames, `fila_max=5`, pior lote 166,2 ms | count=5, pior 369 599 µs, média 228 712,0 µs |
| ponta run 1 [`:527`](evidence/bicho-cavando-12/head_runner_run1.log#L527) | 64 / 4 533,9 ms | 26 em 13 | 5 em 3, `fila_max=5`, 164,0 ms | count=5, 363 793 µs, 225 256,6 µs |
| ponta run 2 [`:527`](evidence/bicho-cavando-12/head_runner_run2.log#L527) | 64 / 4 476,7 ms | 26 em 13 | 5 em 3, `fila_max=5`, 166,2 ms | count=5, 369 599 µs, 228 712,0 µs |

O que se move de corrida para corrida é o `boot ms` (4 624,1 / 4 533,9 / 4 476,7); o lote e o `edit_cost`
repetem dígito a dígito entre o clone e a run 2, que é o que se espera de um palco de edições determinístico
e é também o que torna o `boot` a única linha destes três números que precisa de mais de uma corrida. O
commit (a) mediu o instrumento na ponta da perna 16, antes do cavar: 64 chunks em 4 351,9 ms, fila de **16**
chunks drenada em 8 frames, pior lote 166,8 ms e carimbo de edição em 368 016 µs no pior / 228 503 µs de
média. O rótulo é `colheita_de_malha_sem_cavar` de propósito: o §5 pedia `malharia_do_cavar_medida`, e o par
antes/depois do cavar continua alvo — o instrumento entra primeiro com o estado atual na mesa, porque um
`count` zero para sempre não refuta ninguém.

**O clone limpo e a série do fecho, dez corridas.** `git clone` + `git checkout d80ac20`, sem `.godot/`,
`--import` frio exit 0 ([`clone_import.log`](evidence/bicho-cavando-12/clone_import.log): 0 `SCRIPT ERROR`,
0 linhas começadas por `ERROR`, rodapé `[ DONE ] loading_editor_layout`), engine
`4.7.2.stable.official.ed1daf0bf` em todos os dez stdout, semente `SEED := 20261116`:

- suíte: **`== 255 checagens  0 falhas  48.0 s de teste ==`** exit 0
  ([`clone_suite.log:357`](evidence/bicho-cavando-12/clone_suite.log#L357));
- runner de reações: **283 checagens / 0 falhas / 33,194 s**, `OK censo de checagens | 283/283`,
  `OK censo de testes completos | 65/65`, `trips_solo=0 trips_matilha=0`;
- cenário estreito: `passos=10568 sim_step total=2169480 us pico=3979 us`, BT `soma=55907 pico=245`;
- passos de matilha: `passos=1341 sim_tick total=3098370 us pico=12329 us`, BT `soma=53693 pico=136`;
- runner de RNG **27 / 0 / 2,668 s** (`27/27`), runner do journal **128 / 0 / 5,645 s** (`7/7 testes concluidos`);
- na árvore de trabalho da ponta, as mesmas quatro: **283 / 0 / 32,776 s** e **283 / 0 / 32,782 s** (duas
  corridas serializadas), suíte **255 / 0 / 48,0 s**, RNG **27 / 0 / 2,668 s**, journal **128 / 0 / 5,672 s**.

Zero `[FAIL]` e zero `SCRIPT ERROR` nos dez. O pé do `clone_suite.log` e do `head_suite.log` traz o par já
debitado das pernas anteriores — `WARNING: 4 ObjectDB instances were leaked at exit` na linha 358 com
`ERROR: 2 resources still in use at exit` na 360 — com os mesmos `4` e `2` das testemunhas versionadas da
07c: **sexta** e **sétima** testemunhas, e a atribuição continua aberta. O `sim_step` integral de 10 568
passos é a conta deste lote, e não os 2 768 passos que o contrato citava: a árvore de 2 768 é de antes das
pernas 11 e 16, e o número foi re-derivado aqui porque o lote avançou o mesmo instrumento duas vezes
(checagens 8 e 9). As árvores pineadas, conferíveis sem memória:
`git rev-parse dcbcbe8:src dcbcbe8:tests` = `100af75ded6d50b6a26120be352cf72770f97e80` /
`77fcb0510525a82d39bb799ff1376ff0fb6eb17b` (as mesmas duas do pin `9b2c65a`), e
`git rev-parse d80ac20:src d80ac20:tests` = `f77c1961bb8065ea5a78b24677a36c5840891c75` /
`4855f0e85c883573bc374125b4b016ad1e775711` — **diferentes** das da base, porque a perna escreve código e o
pin é o commit medido, não um documento em cima dele. O fecho (h) não toca `src/` nem `tests/`:
`git diff --name-only d80ac20 -- src tests` devolve vazio, então o clone limpo de `d80ac20` cobre a ponta da
branch **por identidade de árvore**. Pasta de evidência com os dez stdout, a `readback.md` e as três réguas:
[`docs/evidence/bicho-cavando-12/`](evidence/bicho-cavando-12/readback.md).

**O corpus re-derivado, medido com as réguas na mão.** Este fecho moveu o corpus inteiro, e o motivo é o
mesmo da rodada Docs 16 (h): a perna cresceu exatamente onde o corpus aponta. `git show dcbcbe8:<arquivo>`
contra a árvore de trabalho dá [`src/entities/wolf.gd`](../src/entities/wolf.gd) **1 218 → 1 487** linhas e
[`tests/aether_reactions_test.gd`](../tests/aether_reactions_test.gd) **4 396 → 5 514** — ponteiro que caía
depois da linha 1 218 de `wolf.gd` ou da 4 396 do runner deixou, por construção, de apontar para o que a
frase diz. A re-dervação foi feita **por conteúdo**, não por aritmética de diff: cada número velho foi
aberto no arquivo citado e conferido contra a frase que o usa, porque somar o deslocamento do diff produz
número dentro do arquivo e errado — é o formato do furo #28. Contas desta passada:
`git diff --shortstat d80ac20 d62c066 -- docs README.md AGENTS.md` do lote de docs dá **42 arquivos,
+4 585/−773** — aí estão os 17 stdout da pasta de evidência; `git diff --shortstat d80ac20 d62c066 --
'*.md'` sobre o mesmo par dá **26 arquivos, +1 210/−773**, e as **773** deleções são as mesmas dos dois
lados porque os 16 arquivos que faltam na prosa são novos. O 43º arquivo do lote é
`tools/check_doc_anchors.py` (**+7/−2**), o aperto da isenção que o furo #30 pede, e o código de (a) a (g)
fecha em `git diff --shortstat dcbcbe8 d80ac20` = **4 arquivos, +1 424/−21** — nenhum deles `src/main.gd`.

- `python tools/check_doc_anchors.py` → **38 arquivos · 2 924 ponteiros · 209 rótulos · 2 939 links ·
  casos objetivos: 0**, exit 0, medido **com esta seção dentro do corpus**. A mesma régua sobre o mesmo
  corpus sem esta seção: **2 900 · 205 · 2 898** — ou seja, a passada acrescentou **+24 ponteiros, +4 rótulos e +41 links**
  sem abrir caso nenhum, que é o resultado que se quer. Contra a régua velha no corpus da ponta de código
  (`--ref d80ac20`): **2 855** ponteiros com a isenção larga e **2 878** com a de hoje (+23), com
  os **107** casos objetivos **idênticos** nos dois lados — é o furo #30, abaixo.
- `python .tools/verify_plan_cites.py docs/planos/*.md docs/design/*.md docs/engine/*.md docs/melhorias-status.md AGENTS.md README.md`
  → **2 720 citações com número de linha conferidas**, **34** arquivos citados que não existem,
  **`numeros de linha fora do arquivo: 0`**, exit 0. Sem esta seção no mesmo corpus: **2 697** com as
  mesmas **34** — **+23 citações**, nenhum número fora do arquivo. As 34 ausências são a mesma família já
  declarada inexistente (`src/core/sim/tick_clock.gd`, `docs/engine/simclock.md`,
  `tests/wolf_multiseed_census_test.gd`, `src/ai/reach.gd`, `src/core/sim/entity_store.gd`) — peça `[TARGET]`
  citada como alvo, não ponteiro podre.
- `python .tools/verify_plan_ids.py docs/planos/12-bicho-cavando-voxel.md` → **105** identificadores em
  backticks, **5** ausentes em `src/` e `tests/`: `ca88f75`, `d80ac20`, `dcbcbe8`, `e312f58`, `ea78b1a` —
  **todos SHA de commit**, um por um citados justamente como revisão, e nenhum identificador de código
  existente citado em vão.

**Furo #30 — a isenção de continuação da régua de âncoras fechava sobre `)` e tirava números do corpus sem
nenhum vermelho.** [`tools/check_doc_anchors.py:173`](../tools/check_doc_anchors.py#L173) isentava o que vem
depois de um `:NNN-NNN` quando o caractere seguinte era `](` (rótulo de link, que tem o alvo no próprio URL)
**ou** `)`. A segunda forma é o problema: `(:142-144)` é a **forma dominante de continuação em prosa** nos
dossiês — o número vem dentro do parênteses, o arquivo doador vem antes na linha, e nada nele é link. Ao
isentar o `)`, a varredura descartava ponteiro vivo e o `casos objetivos` ficava verde por cegueira de
classe. Medido, pareado, na mesma régua sobre o corpus pineado em `d80ac20` (`--ref d80ac20`) dá **2 855** ponteiros com a isenção larga e
**2 878** com ela apertada (**+23 números que nenhum instrumento conferia**), os **107** casos objetivos são
**idênticos** nos dois lados (nenhum virou vermelho — o dano é **cobertura**, não falsificação), a página
inteira do dossiê 08 sai de **79** para **102** ponteiros e a linha 12 dela de **4** para **10**. O corte é
a linha `if line[m.end():m.end() + 2] == "](":`, uma exceção a menos, e o comentário no próprio arquivo diz
por quê. Dono: `tools/check_doc_anchors.py`, o mesmo arquivo do #28 e do #29; os dois ficam abertos, e o
#30 **fecha nesta passada** — o que continua aberto é o hábito que os três têm em comum, que é conferir
cobertura de régua rodando a régua contra si mesma e não contra o texto.

**Backlog que esta perna abre e não paga** (linha escrita aqui, no fim do arquivo, pelo motivo de topo: a
seção "Backlog" lá em cima é antes de ~4 600 linhas de ponteiros por número, e inseri-la ali deslocaria
todos). **"pisar neve/areia patrulhando"** — o recorte do §3.2 do dossiê
([`docs/planos/12-bicho-cavando-voxel.md`](planos/12-bicho-cavando-voxel.md)) diz **NÃO entra**, e o motivo é
custo, não gosto: é cosmeticamente tentador e custa **um remesh por passo de patrulha**, sem premissa que
ele decida. A régua que o mostra é a colheita do §4 acima: cinco edições de superfície em um lote já dão
pior lote de 164,0–166,8 ms com `fila_max=5` contra o budget de 2 chunks por frame
([src/main.gd:28](../src/main.gd#L28)); um buraco por lobo por passo de ronda seria outro número de outro
tamanho. Entra como linha de backlog, não como código.

**O que nada disso fecha.** (0) Gate de fase fecha o dono do repositório (mandato 4); nenhum número desta
seção encerra P0 ou P1. (1) A colheita do §4 é o estado **sem** cavar: o par antes/depois do `remesh`
gerado pela pata continua débito, e é ele que decide se o cavar custa frame. (2) `block_changed` continua
sem consumidor nenhum em `src/` — o gate desta perna observa `get_block` + `world.edits`, e quem assina o
sinal é a 17; o item (8) do fecho da 07c, que dizia que a 12 "nasce vermelha" por isso, é agora histórico no
sentido exato: a perna fechou sem tocar no sinal. (3) Alocação no caminho quente continua sem medição
própria: o dicionário do blackboard por lobo por tick e o `PackedInt32Array` da difusão seguem derivados
do código, não colhidos. (4) O par de vazamento do quit segue aberto, agora com sete testemunhas
versionadas. (5) Os `.uid` de `tests/` seguem fora do git (#25) e são os dois `??` que todo clone limpo
mostra. (6) O **#28** e o **#29** ficam abertos; o **#30** fecha com a linha apertada, e a cobertura que
ele devolve (+23) está medida acima. (7) `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a projeção do
`TickJournal` não foram tocados por nenhuma das sete linhas; uma corrida com lobos cavando **não** reproduz
os hashes publicados — porque o mundo mudou, não a projeção (dossiê 12 §6). (8) A fila viva passou de
**12 → 17 → 18 → 20 → 13** para **17 → 18 → 20 → 13** com o pouso `fa94cb5`, registrado na seção seguinte:
o elo seguinte é `feat/fisica-de-blocos-que-caem-17`, que é justamente quem assina `block_changed`.

## O pouso da 12 — o merge, o pin medido no clone limpo, as dez corridas serializadas e a atribuição de carga retirada (2026-11-23, base `dcbcbe8`, ponta `d62c066`, merge `fa94cb5`)

**O que o dono autorizou e o que continua fechado.** A autorização é a nomeada das pernas anteriores, e
nada além dela: subir o que terminar com `push`, e cada agente faz o próprio `merge --no-ff` na `main` e o
push. Cobre o pouso do código da 12 e este registro. **Mandato 4**: gate de fase fecha só o dono do
repositório — nenhum gate foi fechado aqui, e a fila serializada não sofreu exceção de ordem. A 12 era a
perna da vez, foi aberta da `main` no ponto atual (`dcbcbe8`) e pousou sobre esse ponto.

**Pré-gate, conferido antes de encostar em `main`.** Quatro arquivos, um `--check-only` por arquivo, porque
a sonda só valida o arquivo que recebe — `src/entities/wolf.gd`, `src/entities/voxel_body.gd`,
`tests/aether_reactions_test.gd` e `tests/smoke_test.gd` deram os quatro `exit=0` com a engine
`4.7.2.stable.official.ed1daf0bf` impressa em cada um
([pouso_pregate_check_only.log:3](evidence/bicho-cavando-12/pouso_pregate_check_only.log#L3),
[:5](evidence/bicho-cavando-12/pouso_pregate_check_only.log#L5),
[:7](evidence/bicho-cavando-12/pouso_pregate_check_only.log#L7),
[:9](evidence/bicho-cavando-12/pouso_pregate_check_only.log#L9)). As duas contas que dizem que o merge não
traz nada além da ponta medida: `git diff --name-only d62c066 fa94cb5` devolve **0 arquivos**
([:11](evidence/bicho-cavando-12/pouso_pregate_check_only.log#L11)) e as árvores de `fa94cb5` são
byte a byte as de `d80ac20` — `f77c1961bb8065ea5a78b24677a36c5840891c75` em `src`,
`4855f0e85c883573bc374125b4b016ad1e775711` em `tests`
([:13-14](evidence/bicho-cavando-12/pouso_pregate_check_only.log#L13-L14),
[:16-17](evidence/bicho-cavando-12/pouso_pregate_check_only.log#L16-L17)). O lote inteiro, contra a base:
**46 arquivos, +6 013/−793**
([:19](evidence/bicho-cavando-12/pouso_pregate_check_only.log#L19)).

**O merge.** `git merge --no-ff feat/bicho-cavando-12` → **`fa94cb5ddf60bc360aa662715d3d98d17f5d6d1c`**,
pais `dcbcbe823e6202750803cbfb3e84420553fc8185` e `d62c066e36ef45893d76861b22a7f9b78c188a61`
(`git log --format=%P -1`), sem conflito. A conta dos 46 arquivos, por área: **3 de código**
(`src/entities/voxel_body.gd` +12/−4, `src/entities/wolf.gd` +277/−8,
`tests/aether_reactions_test.gd` +1 119/−1 = **+1 408/−13**, conferido por
`git diff --numstat dcbcbe8 fa94cb5 -- src tests`), **18 de `docs/planos/`**, **17 de stdout** em
`docs/evidence/bicho-cavando-12/`, **4** de `docs/design/` + `docs/engine/`, `docs/melhorias-status.md`,
`AGENTS.md`, `README.md` e `tools/check_doc_anchors.py` — o instrumento do furo #30, que viaja com a perna
porque foi ela que o apertou. Nenhum `src/main.gd` no lote, e a base continua com as árvores
`100af75ded6d50b6a26120be352cf72770f97e80` / `77fcb0510525a82d39bb799ff1376ff0fb6eb17b`, **diferentes** das
do pouso: a perna escreve código, então o pin é o merge medido, não um documento em cima dele.

**As dez corridas, seriais, uma por número, nenhuma em paralelo com outro lote de timing.** Todas exit 0,
com **0** `[FAIL]` e **0** `SCRIPT ERROR` contados por `grep` nos dez stdout:

- suíte na árvore mergida — **`== 255 checagens  0 falhas  51.2 s de teste ==`**
  ([pouso_merged_main_suite.log:357](evidence/bicho-cavando-12/pouso_merged_main_suite.log#L357)) e, na
  segunda corrida da mesma árvore, **`51.2 → 48.3 s`** com o mesmo censo
  ([pouso_merged_main_suite_b.log:357](evidence/bicho-cavando-12/pouso_merged_main_suite_b.log#L357));
- runner de reações na árvore mergida — **`283 checagens 0 falhas 45.392 s`** com
  **`OK censo de checagens | 283/283`** e **`OK censo de testes completos | 65/65`**
  ([pouso_merged_main_runner_reactions.log:541](evidence/bicho-cavando-12/pouso_merged_main_runner_reactions.log#L541),
  [:538](evidence/bicho-cavando-12/pouso_merged_main_runner_reactions.log#L538),
  [:536](evidence/bicho-cavando-12/pouso_merged_main_runner_reactions.log#L536));
- **clone limpo** de `fa94cb5` (`.qoder/clones/clean-pouso12`, `git rev-parse HEAD` no clone =
  `fa94cb5ddf60bc360aa662715d3d98d17f5d6d1c`, `git rev-parse HEAD:src HEAD:tests` = as duas árvores
  acima), sem `.godot/`, com `--import` frio exit 0 e rodapé `[ DONE ] loading_editor_layout`
  ([pouso_clone_import.log:302](evidence/bicho-cavando-12/pouso_clone_import.log#L302)) — suíte
  **`== 255 checagens  0 falhas  61.7 s de teste ==`**
  ([pouso_clone_suite.log:357](evidence/bicho-cavando-12/pouso_clone_suite.log#L357)) e
  **`60.4 s`** ([pouso_clone_suite_b.log:357](evidence/bicho-cavando-12/pouso_clone_suite_b.log#L357));
- runner de reações no clone — **`283 checagens 0 falhas 34.218 s`** com **`283/283`**, **`65/65`** e
  `trips_solo=0 trips_matilha=0`
  ([pouso_clone_runner_reactions.log:541](evidence/bicho-cavando-12/pouso_clone_runner_reactions.log#L541),
  [:538](evidence/bicho-cavando-12/pouso_clone_runner_reactions.log#L538),
  [:537](evidence/bicho-cavando-12/pouso_clone_runner_reactions.log#L537));
- runner de RNG — **`27 checagens 0 falhas 2.818 s`** no clone
  ([pouso_clone_runner_rng.log:78](evidence/bicho-cavando-12/pouso_clone_runner_rng.log#L78)) e
  **`2.921 s`** na mergida ([pouso_merged_main_runner_rng.log:78](evidence/bicho-cavando-12/pouso_merged_main_runner_rng.log#L78)),
  as duas com `OK censo de checagens | 27/27` ([:77](evidence/bicho-cavando-12/pouso_clone_runner_rng.log#L77));
- runner do journal — **`128 checagens 0 falhas 7/7 testes concluidos 6.840 s`** no clone
  ([pouso_clone_runner_journal.log:143](evidence/bicho-cavando-12/pouso_clone_runner_journal.log#L143)) e
  **`7.598 s`** na mergida ([pouso_merged_main_runner_journal.log:143](evidence/bicho-cavando-12/pouso_merged_main_runner_journal.log#L143)),
  os dois com `OK contagem completa de checagens 128/128` ([:142](evidence/bicho-cavando-12/pouso_clone_runner_journal.log#L142)).

**O pin.** O número que vale para a `main` é o do **clone limpo**: **255 / 0 / 61,7 s** de suíte, com o
runner de reações em **283 / 0 / 34,218 s**. A suíte fica em 255 porque o lote escreve no runner, não em
`tests/smoke_test.gd`; o censo que cresce é o do runner, 240 → 283 (+43), exatamente a conta publicada na
rodada acima. As duas colheitas do runner, impressas literalmente nas duas árvores — clone
([pouso_clone_runner_reactions.log:539](evidence/bicho-cavando-12/pouso_clone_runner_reactions.log#L539),
[:540](evidence/bicho-cavando-12/pouso_clone_runner_reactions.log#L540)) e mergida
([pouso_merged_main_runner_reactions.log:539](evidence/bicho-cavando-12/pouso_merged_main_runner_reactions.log#L539),
[:540](evidence/bicho-cavando-12/pouso_merged_main_runner_reactions.log#L540)):

- `CENARIO ESTREITO, NAO GATE P1: passos=10568 sim_step total=2213150 us pico=3442 us; BT last_us
  soma=56812 pico=193 trips=0` (clone) contra `total=3074495 us pico=5860 us; ... soma=73627 pico=308`
  (mergida);
- `PASSOS DE MATILHA (sessao real, difusao incluida), NAO GATE P1: passos=1341 sim_tick total=3088657 us
  pico=12816 us; BT last_us soma=54195 pico=84 trips=0` (clone) contra `total=4400919 us pico=19620 us;
  ... soma=77398 pico=210` (mergida).

Os **passos** são idênticos nas duas árvores (10 568 e 1 341) — o palco é determinístico — e os
**microssegundos** não: a mergida gasta +38,7 % no estreito e +42,5 % na matilha sobre o clone, com o
`pico` quase dobrando nos dois. O pé do `pouso_clone_suite.log` traz o diagnóstico da mesma corrida
([:345](evidence/bicho-cavando-12/pouso_clone_suite.log#L345)): `"worst_sim_ms":16.119`, `dropped_ticks":0`,
`"edits":16`, `"den_components":2` e o bloco `"edit_mesh":{"count":17,"mean_us":163549.5,"worst_us":303602}`.
Nenhum desses números fecha P1 e nenhum é budget agregado dos cinco lobos.

**As três réguas do corpus, rodadas contra a árvore mergida.** `python tools/check_doc_anchors.py` →
**`arquivos: 38  ponteiros conferidos: 2924  rotulos conferidos: 209  links relativos conferidos: 2939`**
com **`casos objetivos: 0`**
([pouso_ruler_doc_anchors.log:1](evidence/bicho-cavando-12/pouso_ruler_doc_anchors.log#L1),
[:2](evidence/bicho-cavando-12/pouso_ruler_doc_anchors.log#L2)). O zero não é novidade desta passada e não
é crédito dela: é o mesmo caso que a rodada da 07c já explicou — o `../.tools/_chk_labels.py` deste
arquivo só resolve na árvore primária, porque `.tools/` existe aqui e é gitignored, e num worktree de
`cea4379` a mesma régua deu **1** caso objetivo com o resto das contagens idêntico. O que o **#29** continua
dizendo continua valendo: nenhuma das duas réguas entra em `docs/evidence/`, então os **38 arquivos** são o
corpus *sem* a evidência que esta seção aponta.
`python .tools/verify_plan_cites.py docs/planos/*.md docs/design/*.md docs/engine/*.md
docs/melhorias-status.md AGENTS.md README.md` → **2 720 citações com número de linha conferidas**, **34**
arquivos citados que não existem, **`numeros de linha fora do arquivo: 0`**
([pouso_ruler_plan_cites.log:1](evidence/bicho-cavando-12/pouso_ruler_plan_cites.log#L1),
[:2](evidence/bicho-cavando-12/pouso_ruler_plan_cites.log#L2),
[:37](evidence/bicho-cavando-12/pouso_ruler_plan_cites.log#L37)); das 34 ausências, **três** são nomes de
rascunho que a rodada da 16 criou em `.tools/` para conferir o `HEAD` da época
(`.tools/_head_agents.md`, `.tools/_head_readme.md`, `.tools/_head_status.md`, linhas
[:22-24](evidence/bicho-cavando-12/pouso_ruler_plan_cites.log#L22-L24) do mesmo stdout) — sujeira de
instrumento gitignored que nenhum passo seguinte limpou, não promessa de peça; as **31** restantes são a
família `[TARGET]` declarada como peça que não existe: `src/core/sim/tick_clock.gd`, `src/ai/reach.gd`,
`tests/wolf_multiseed_census_test.gd` e as páginas de estrutura do doc 07
([:3](evidence/bicho-cavando-12/pouso_ruler_plan_cites.log#L3) em diante). Nenhuma é ponteiro podre de um
código que existiu e sumiu.
`python .tools/verify_plan_ids.py docs/planos/12-bicho-cavando-voxel.md` → **105** identificadores em
backticks, **5** ausentes em `src/` e `tests/`: `ca88f75`, `d80ac20`, `dcbcbe8`, `e312f58`, `ea78b1a`
([pouso_ruler_plan_ids.log:1](evidence/bicho-cavando-12/pouso_ruler_plan_ids.log#L1),
[:2](evidence/bicho-cavando-12/pouso_ruler_plan_ids.log#L2)) — conferidos um a um: os cinco são **SHA de
commit** desta perna e da sua base, citados justamente como revisão, e nenhum identificador de código
existente foi escrito em vão.

**O vermelho intermitente do espalhamento, as duas testemunhas, e a atribuição de carga retirada.** A
checagem é `espalhamento_nao_estoura_o_passo`, régua 25 ms, e ela já deu os dois lados na **mesma árvore de
código** (`f77c1961…`/`4855f0e8…`), no **mesmo tick** e com a **mesma testemunha de palco**
(`dens=3 componentes=2 separacao=55.9 m`):

- vermelho — `[FAIL] espalhamento_nao_estoura_o_passo  perdidos=0  pior passo=96.48 ms (regua 25) ...
  tick=403` com `== 255 checagens  1 falhas  59.9 s de teste ==`
  ([fecho_ponta_espalhamento_vermelho.log:343](evidence/bicho-cavando-12/fecho_ponta_espalhamento_vermelho.log#L343),
  [:357](evidence/bicho-cavando-12/fecho_ponta_espalhamento_vermelho.log#L357));
- verde — o mesmo `[PASS]` em `15.81 ms` com `255 / 0 / 59.0 s` na corrida seguinte da mesma ponta
  ([fecho_ponta_espalhamento_verde.log:343](evidence/bicho-cavando-12/fecho_ponta_espalhamento_verde.log#L343),
  [:357](evidence/bicho-cavando-12/fecho_ponta_espalhamento_verde.log#L357));
- e as quatro corridas deste pouso, todas verdes, em `16.12` / `15.69` ms no clone e `11.44` / `12.90` ms
  na mergida ([pouso_clone_suite.log:343](evidence/bicho-cavando-12/pouso_clone_suite.log#L343),
  [pouso_clone_suite_b.log:343](evidence/bicho-cavando-12/pouso_clone_suite_b.log#L343),
  [pouso_merged_main_suite.log:343](evidence/bicho-cavando-12/pouso_merged_main_suite.log#L343),
  [pouso_merged_main_suite_b.log:343](evidence/bicho-cavando-12/pouso_merged_main_suite_b.log#L343)).

A rodada da ponta tinha uma explicação escrita para o vermelho: **carga na máquina, medida segundo a
segundo**. Ela sai **retirada** aqui, e o motivo é o instrumento, não a dúvida. Quem gerou os três stdout
de carga é [`.tools/_p12_load_sampler.ps1`](../.tools/_p12_load_sampler.ps1) (gitignored), e a linha que
escolhe o processo é `$qe = Get-Process -Name QuantumEngine -ErrorAction SilentlyContinue` — conferido
agora nesta máquina: `QuantumEngine` resolve para
`C:\Program Files\JBL\QuantumENGINE\QuantumEngine.exe`, o app de áudio da JBL. O amostrador **nunca
filtrou o processo Godot**, nem por nome nem por `ExecutablePath`, e o analisador de janela
[`.tools/_carga_por_janela.py`](../.tools/_carga_por_janela.py) divide o CPU acumulado **desse** processo
pela duração da janela e imprime `% de um nucleo`. A coluna de carga do sistema, essa, não chegou: nos
três stdout arquivados ela tem três formas diferentes — `fecho_ponta_carga.log` são **90** linhas com
`load=%` vazio (o `PercentProcessorTime` do CIM devolveu nada em 90 de 90) e sem `qe_cpu=`
([:1](evidence/bicho-cavando-12/fecho_ponta_carga.log#L1)); `pouso_carga_merged_main_a.log` são **95**
linhas com só `qe_delta`, nenhuma coluna `load=`
([:1](evidence/bicho-cavando-12/pouso_carga_merged_main_a.log#L1)); `pouso_carga_merged_main_b.log` são
**63** linhas completas, com `load=` entre 5 % e 22 % e `qe_cpu=37160,44s`
([:1](evidence/bicho-cavando-12/pouso_carga_merged_main_b.log#L1)). Logo nenhum número impresso sustenta a
frase "a carga está registrada segundo a segundo" — e o vermelho volta a estar **sem atribuição**, escrito
assim, com as duas testemunhas versionadas e a régua em 25 ms intocada. Nada foi silenciado: o `1 falhas`
do log vermelho continua no log, o `[FAIL]` continua na linha 343 e o critério não foi abaixado.

Isso vale para a mesa do §4 pelo mesmo motivo. A linha `COLHEITA DE MALHA SEM CAVAR` repetiu **a
estrutura** dígito a dígito nas cinco corridas do mesmo instrumento (fila do palco `remeshes=26 frames=13`,
lote `edicoes=5 frames=3 fila_max=5`) e **não repetiu o tempo**: `worst_lote_ms` dá 166,2 / 165,8 / 164,0
ms nas três da ponta
([clone_runner_reactions.log:527](evidence/bicho-cavando-12/clone_runner_reactions.log#L527),
[head_runner_run1.log:527](evidence/bicho-cavando-12/head_runner_run1.log#L527),
[head_runner_run2.log:527](evidence/bicho-cavando-12/head_runner_run2.log#L527)) e 261,7 / 247,7 ms nas
duas deste pouso ([pouso_clone_runner_reactions.log:527](evidence/bicho-cavando-12/pouso_clone_runner_reactions.log#L527),
[pouso_merged_main_runner_reactions.log:527](evidence/bicho-cavando-12/pouso_merged_main_runner_reactions.log#L527)),
com `worst_us` de 363 793 → 555 136 µs. É a mesma direção do pico do espalhamento e do `sim_step` da
mergida: **o que é determinístico neste lote é a contagem, não o microssegundo** — e a frase da rodada
anterior ("o lote e o `edit_cost` repetem dígito a dígito") só é verdadeira para as três corridas da ponta,
não para o lote todo. Ela fica como está, com esta correção ao lado; re-escrevê-la sem corrida nova seria
trocar número por preferência.

**Furo #31 — o amostrador de carga filtrou o processo errado, e a régua de janela herdou o número dele.**
Aberto por esta passada, com dono escrito antes de qualquer conserto. O defeito não mora em código
versionado: mora no instrumento gitignored [`.tools/_p12_load_sampler.ps1`](../.tools/_p12_load_sampler.ps1),
linha 6 (o filtro por nome de processo), e no seu leitor
[`.tools/_carga_por_janela.py`](../.tools/_carga_por_janela.py), que imprime a fração daquele processo como
se fosse a máquina. A casa já
tem a regra que o proíbe, registrada na atribuição de pico: **filtrar por `ExecutablePath` dentro do
projeto, não por nome de processo**, e não confundir headless de outro projeto com contaminação. O que
fecha o #31 é um número, não uma frase: um amostrador que nomeie o PID do `godot_headless` da corrida,
imprima o CPU dele por janela e rode **pareado** com uma janela vermelha e uma verde da mesma árvore — se
o CPU do próprio Godot não separar as duas, a atribuição é outra e procura-se em outro lugar. Enquanto
isso, a leitura honesta do `96.48 ms` é a do furo #20, que a perna 19 já escreveu para o `trips`: o passo é
cronometrado em **parede de relógio**, então um pico de 96 ms com `perdidos=0` e `tick=403` idêntico é um
portão de velocidade de máquina, e portão de velocidade de máquina não se atribui a um processo que não é
o medido. E o inverso também fica escrito: o que esta passada **não** pode afirmar é que a máquina estava
livre nas dez janelas acima, porque a guarda que provaria isso é justamente o instrumento que o #31
retira. As corridas foram uma por vez e sem outro lote de timing em paralelo — isso é como elas foram
rodadas; "e nada mais consumia a máquina" é o que falta.

**Testemunha nova, 2026-11-25, pela perna 23 Fase 2 (o amostrador do #44 consertado, ligado nas
corridas).** O que ela acrescenta é o lado que faltava da pergunta, e não a resposta: a **mesma** régua de
25 ms do `espalhamento_nao_estoura_o_passo` deu **31,33–32,41 ms** em cinco corridas da ponta e
**30,80–31,26 ms** em três corridas da base `eb218fe` na mesma janela de relógio, com o rodapé da
corrida quase parado (+1,4% a +4,1% na ponta, +5,3% a +5,7% na base) e o pico do passo em ×2,1 dos dois
lados — ou seja, o vermelho não separa as duas árvores e o total não acusa custo novo. Na janela em que
não havia outro Godot do projeto (um só PID, o da corrida), a régua ainda deu 31,33 ms. O que continua
faltando é exatamente o que este parágrafo sempre exigiu: o par **vermelha↔verde da mesma árvore** com o
CPU do próprio Godot amostrado nos dois lados, porque a janela verde desta árvore foi corrida sem
amostrador. Arquivado em
[`regua25_ponta_recorrencia.log`](evidence/elevacao-visual-chuva-23/regua25_ponta_recorrencia.log),
[`regua25_base-eb218fe_controle.log`](evidence/elevacao-visual-chuva-23/regua25_base-eb218fe_controle.log)
e as três janelas `carga_janela_*.log`. O #31 continua aberto, sem dono novo.

**O que nada disso fecha.** (0) Gate de fase fecha o dono (mandato 4); nenhum número desta seção encerra
P0 ou P1. (1) `block_changed` continua **sem consumidor nenhum** em `src/`: a árvore do pouso tem exatamente
duas ocorrências, a declaração ([src/world/voxel_world.gd:6](../src/world/voxel_world.gd#L6)) e o emit
([:336](../src/world/voxel_world.gd#L336)), e quem assina o sinal é a 17 — o elo seguinte da fila. (2) O
par antes/depois do `remesh` gerado pela pata continua débito: a mesa do §4 é o estado **sem** cavar, e
acabou de ganhar um segundo motivo para ser re-medida (a coluna de tempo acima). (3) O vermelho do
espalhamento voltou a estar **sem dono**, e o #31 é o que impede que ele volte a ter um dono de mentira.
(4) O par de vazamento do quit segue aberto: as **quatro** corridas de suíte deste pouso imprimem
`WARNING: 4 ObjectDB instances were leaked at exit` na linha 358 com `ERROR: 2 resources still in use at
exit` na 360 — os mesmos `4` e `2` das pernas anteriores, agora também no clone e na mergida, duas vezes
cada ([:358](evidence/bicho-cavando-12/pouso_clone_suite.log#L358),
[:360](evidence/bicho-cavando-12/pouso_clone_suite.log#L360)) — e as duas testemunhas do vermelho/verde da
ponta não imprimem nenhum dos dois. (5) Alocação no caminho quente continua sem medição própria. (6) Os
`.uid` de `tests/` seguem fora do git (#25): o `git status` desta árvore mostra exatamente os dois `??`,
`tests/audio_test.gd.uid` e `tests/audio_live_probe.gd.uid`, e nada nesta perna os comita. (7) **#28** e
**#29** continuam abertos, **#30** fechou com a isenção apertada, e **#31** nasce aqui. (8)
`Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a projeção do `TickJournal` não foram tocados: o lote
não encosta em `src/world/aether_field.gd`, `src/persistence/tick_journal.gd` nem `src/world/world_gen.gd`
(`git diff --name-only dcbcbe8 fa94cb5` sobre os três devolve vazio), e o journal do clone está desligado
no diagnóstico (`"journal":{"active":false,...,"records":0}`). (9) A fila viva é **17 → 18 → 20 → 13**.

**A suíte e as três réguas re-rodadas na árvore deste registro**, que só acrescenta `.md` e `.log`:
`git diff --name-only fa94cb5 -- src tests` devolve **0 arquivos** nesta árvore antes do commit, então as
árvores de código continuam `f77c1961bb8065ea5a78b24677a36c5840891c75` e
`4855f0e85c883573bc374125b4b016ad1e775711` e o número do pin vale para cá por **identidade de árvore**, não
por memória. As duas corridas, uma por vez, exit 0: **`== 255 checagens  0 falhas  62.0 s de teste ==`**
([registro_rerun_suite_a.log:357](evidence/bicho-cavando-12/registro_rerun_suite_a.log#L357)) e **`== 255
checagens  0 falhas  62.2 s de teste ==`**
([registro_rerun_suite_b.log:357](evidence/bicho-cavando-12/registro_rerun_suite_b.log#L357)), com **0**
`[FAIL]` e **0** `SCRIPT ERROR` contados por `grep -c` nos dois stdout, e as duas imprimindo o par de
vazamento no rodapé — `WARNING: 4 ObjectDB instances were leaked at exit`
([:358](evidence/bicho-cavando-12/registro_rerun_suite_a.log#L358)) com `ERROR: 2 resources still in use at
exit` ([:360](evidence/bicho-cavando-12/registro_rerun_suite_a.log#L360)) — o que deixa o item (4) acima
ainda aberto em vez de contá-lo resolvido. A testemunha de palco se repete nas **oito** corridas desta
checagem (`dens=3 componentes=2 separacao=55.9 m`, sempre no `tick=403`), e o pior passo sai **17.01 ms**
([registro_rerun_suite_a.log:343](evidence/bicho-cavando-12/registro_rerun_suite_a.log#L343)) e **15.61 ms**
([registro_rerun_suite_b.log:343](evidence/bicho-cavando-12/registro_rerun_suite_b.log#L343)), somando-se
aos cinco verdes de 11,44 a 16,12 ms e ao único vermelho de 96,48 ms da rodada da ponta. Uma amostra só de
`PercentProcessorTime` de `_Total`, lida antes da segunda corrida, devolveu **8 %** — e é a mesma chamada
CIM que no stdout de carga da ponta não devolveu nada em **90** de **90** linhas
([fecho_ponta_carga.log:1](evidence/bicho-cavando-12/fecho_ponta_carga.log#L1)), o que diz que a coluna
vazia do amostrador era falha de amostragem, não ausência de carga. O que essa amostra **não** diz é nada
sobre as janelas das dez corridas acima: uma leitura solta não é a guarda pareada que o furo #31 pede, e
continua sendo ela a única atribuição que falta ao `96.48`.

As três réguas, na árvore deste registro, cada uma rodada duas vezes — a segunda depois de escrever os
números da primeira, para que "escrever número" não mova contagem: `python tools/check_doc_anchors.py` dá
**38 arquivos · 2 927 ponteiros · 209 rótulos · 3 023 links** com `casos objetivos: 0`
([registro_ruler_doc_anchors.log:1](evidence/bicho-cavando-12/registro_ruler_doc_anchors.log#L1),
[:2](evidence/bicho-cavando-12/registro_ruler_doc_anchors.log#L2)) e, na segunda rodada, os mesmos
**38 · 2 927 · 209 · 3 023** com o mesmo `casos objetivos: 0`
([registro_ruler_doc_anchors_b.log:1](evidence/bicho-cavando-12/registro_ruler_doc_anchors_b.log#L1),
[:2](evidence/bicho-cavando-12/registro_ruler_doc_anchors_b.log#L2)); o acréscimo sobre a árvore do pouso
(**2 924 · 209 · 2 939** em [pouso_ruler_doc_anchors.log:1](evidence/bicho-cavando-12/pouso_ruler_doc_anchors.log#L1))
é este registro, que aponta para os stdout novos, e não linha velha que se moveu.
`python .tools/verify_plan_cites.py docs/planos/*.md docs/design/*.md docs/engine/*.md
docs/melhorias-status.md AGENTS.md README.md` → **2 723 citações com número de linha conferidas**, **34**
arquivos citados que não existem, `numeros de linha fora do arquivo: 0`
([registro_ruler_plan_cites.log:1](evidence/bicho-cavando-12/registro_ruler_plan_cites.log#L1),
[:2](evidence/bicho-cavando-12/registro_ruler_plan_cites.log#L2),
[:37](evidence/bicho-cavando-12/registro_ruler_plan_cites.log#L37)) e idem na segunda
([registro_ruler_plan_cites_b.log:1](evidence/bicho-cavando-12/registro_ruler_plan_cites_b.log#L1),
[:37](evidence/bicho-cavando-12/registro_ruler_plan_cites_b.log#L37)). Que nenhum ponteiro velho se moveu
com este registro é conferido, não supuesto: a maior linha deste arquivo que o corpus aponta é **4495**,
contada por `grep -rhoE "melhorias-status\.md(:[0-9]+(-[0-9]+)?|#L[0-9]+(-[0-9]+)?)" docs AGENTS.md
README.md | grep -oE "[0-9]+" | sort -n | tail -1` (as formas `:` e `#L` juntas, intervalos incluídos), e a
maior linha do `AGENTS.md` que alguém aponta é **477** pelo mesmo padrão com o nome trocado; as três edições
do `AGENTS.md` caem em `:533`, `:564-566` e `:619` em diante, e as deste arquivo em `:592` (neutra: duas
linhas por duas), `:5643` e `:5705` em diante — todas **depois** do maior número citado em cada um, então
quem aponta para antes de 477/4495 continua apontando para a mesma linha. É o furo **#28**
pelo lado inverso: a régua não veria um ponteiro velho cujo alvo continua dentro do arquivo, por isso a
conta é feita à mão e arquivada aqui. `python .tools/verify_plan_ids.py
docs/planos/12-bicho-cavando-voxel.md` → **105** identificadores em backticks com os mesmos **5** SHA
ausentes — `ca88f75`, `d80ac20`, `dcbcbe8`, `e312f58`, `ea78b1a`
([registro_ruler_plan_ids.log:1](evidence/bicho-cavando-12/registro_ruler_plan_ids.log#L1),
[:2](evidence/bicho-cavando-12/registro_ruler_plan_ids.log#L2), idem em
[registro_ruler_plan_ids_b.log:1](evidence/bicho-cavando-12/registro_ruler_plan_ids_b.log#L1)).

**Publicação provada, não afirmada.** Conferido nesta passada, **antes** de qualquer push:
`git ls-remote --heads origin` trazia `main` em `dcbcbe823e6202750803cbfb3e84420553fc8185` e **nenhuma**
linha para `feat/bicho-cavando-12` — nem o merge do código (`fa94cb5`) nem a branch da perna tinham subido,
enquanto a 16, a 11 e a 19 têm as branches remotas delas. É débito desta rodada de pouso, não do gate, e a
casa exige o `ls-remote` como única prova exatamente porque este repositório já teve um `origin` apontando
para ele mesmo. Sobe agora, nesta ordem: a `feat/bicho-cavando-12` na ponta `d62c066`, esta branch de
registro, o merge do registro na `main` por cima de `fa94cb5`, e o `git ls-remote --heads origin` depois
disso conferindo as três refs. **Nenhuma branch foi deletada** — nem a local, nem a remota, nem a `main`. O
merge do registro move a ponta da `main` e não move o pin: `git diff --name-only fa94cb5 -- src tests`
devolve vazio nesta árvore, então `f77c1961…` e `4855f0e8…` continuam sendo as árvores de código medidas de
que cada número acima sai — pin é identidade de árvore, não SHA de documento. Os artefatos da pasta têm
`artifacts.sha256` regenerado com **44** entradas e conferido por `sha256sum -c`, que devolve 44 linhas `OK`
e nenhuma falha, exit 0 — as 44 são o manifest tal como pousou em `6a9447e`; a conta da ponta de registro
depois dela está no parágrafo seguinte.

**A `main` mergida do registro, re-medida.** O merge do registro na `main` é `56485fb`, pais `fa94cb5` e
`6a9447e`. `git diff --name-only fa94cb5 56485fb` devolve **32 arquivos, nenhum em `src/` ou `tests/`** —
medido com os dois `wc -l` separados (32 no diff todo, **0** no recorte `-- src tests`), então a árvore
resultante tem o mesmo `src` e os mesmos `tests` do pin e os números dele valem aqui **por identidade de
árvore**. O pré-gate na árvore mergida é uma linha de banner e exit **0**
([registro_merge_pregate_check_only.log:1](evidence/bicho-cavando-12/registro_merge_pregate_check_only.log#L1)),
e a suíte re-rodada nela sai **`== 255 checagens  0 falhas  48.4 s de teste ==`**, exit **0**, com **0**
`[FAIL]` e **0** `SCRIPT ERROR` contados por `grep -cE` no mesmo stdout
([registro_merged_main_suite.log:357](evidence/bicho-cavando-12/registro_merged_main_suite.log#L357)) — a
testemunha de palco na linha **343** (mesmo `dens=3 componentes=2 separacao=55.9 m`, mesmo `tick=403`, pior
passo **11.14 ms** abaixo dos 25 ms da régua) e o par de vazamento no rodapé, `WARNING: 4 ObjectDB instances
were leaked at exit` ([:358](evidence/bicho-cavando-12/registro_merged_main_suite.log#L358)) com `ERROR: 2
resources still in use at exit`
([:360](evidence/bicho-cavando-12/registro_merged_main_suite.log#L360)). As três réguas na árvore mergida,
uma corrida cada: `check_doc_anchors.py` **38 arquivos · 2 927 ponteiros · 209 rótulos · 3 023 links** com
`casos objetivos: 0`
([registro_merged_main_ruler_doc_anchors.log:1](evidence/bicho-cavando-12/registro_merged_main_ruler_doc_anchors.log#L1),
[:2](evidence/bicho-cavando-12/registro_merged_main_ruler_doc_anchors.log#L2)); `verify_plan_cites.py` **2
723 citações com número de linha conferidas**, **34** arquivos citados que não existem, `numeros de linha
fora do arquivo: 0`
([registro_merged_main_ruler_plan_cites.log:1](evidence/bicho-cavando-12/registro_merged_main_ruler_plan_cites.log#L1),
[:2](evidence/bicho-cavando-12/registro_merged_main_ruler_plan_cites.log#L2),
[:37](evidence/bicho-cavando-12/registro_merged_main_ruler_plan_cites.log#L37)); `verify_plan_ids.py` **105**
identificadores em backticks com os mesmos **5** SHA ausentes — `ca88f75`, `d80ac20`, `dcbcbe8`, `e312f58`,
`ea78b1a`
([registro_merged_main_ruler_plan_ids.log:1](evidence/bicho-cavando-12/registro_merged_main_ruler_plan_ids.log#L1),
[:2](evidence/bicho-cavando-12/registro_merged_main_ruler_plan_ids.log#L2)). Os quatro números são os
mesmos das duas rodadas da árvore do registro, o que era o esperado: um merge que não escreve `.gd` nem
move linha citada não muda régua nenhuma. Aqueles três stdout de régua foram lidos **antes** de este bloco
existir, portanto não contam os próprios ponteiros. Re-rodadas com a árvore final desta ponta, as três dão
`check_doc_anchors.py` **38 · 2 927 · 209 · 3 046** com `casos objetivos: 0`
([registro_merged_main_ruler_doc_anchors_pos_escrita.log:1](evidence/bicho-cavando-12/registro_merged_main_ruler_doc_anchors_pos_escrita.log#L1),
[:2](evidence/bicho-cavando-12/registro_merged_main_ruler_doc_anchors_pos_escrita.log#L2));
`verify_plan_cites.py` **2 723 · 34 · 0**
([registro_merged_main_ruler_plan_cites_pos_escrita.log:1](evidence/bicho-cavando-12/registro_merged_main_ruler_plan_cites_pos_escrita.log#L1),
[:2](evidence/bicho-cavando-12/registro_merged_main_ruler_plan_cites_pos_escrita.log#L2),
[:37](evidence/bicho-cavando-12/registro_merged_main_ruler_plan_cites_pos_escrita.log#L37));
`verify_plan_ids.py` **105 · 5**
([registro_merged_main_ruler_plan_ids_pos_escrita.log:1](evidence/bicho-cavando-12/registro_merged_main_ruler_plan_ids_pos_escrita.log#L1),
[:2](evidence/bicho-cavando-12/registro_merged_main_ruler_plan_ids_pos_escrita.log#L2)) — a coluna de links
sobe dos `3 023` de cima para `3 046`, e os **23** da diferença são os ponteiros que este bloco abriu,
conferido entre as duas leituras arquivadas, não declarado. Nenhuma das outras colunas se move, e nenhuma
das três réguas vê ponteiro de prosa cujo alvo continua dentro do arquivo, que é o furo **#28**.

**Os stdout desta ponta e o manifest.** Entram na pasta oito arquivos novos: os cinco stdout do merge da 12
— o pré-gate
([registro_merge_pregate_check_only.log:1](evidence/bicho-cavando-12/registro_merge_pregate_check_only.log#L1)),
a suíte da árvore mergida
([registro_merged_main_suite.log:357](evidence/bicho-cavando-12/registro_merged_main_suite.log#L357)) e as
três réguas lidas antes da escrita deste bloco
([registro_merged_main_ruler_doc_anchors.log:1](evidence/bicho-cavando-12/registro_merged_main_ruler_doc_anchors.log#L1),
[registro_merged_main_ruler_plan_cites.log:1](evidence/bicho-cavando-12/registro_merged_main_ruler_plan_cites.log#L1),
[registro_merged_main_ruler_plan_ids.log:1](evidence/bicho-cavando-12/registro_merged_main_ruler_plan_ids.log#L1))
— mais as três re-leituras de cima, já com o bloco escrito, nos três `*_pos_escrita.log`. O
[artifacts.sha256](evidence/bicho-cavando-12/artifacts.sha256) sai regenerado com **52** entradas e
`sha256sum -c artifacts.sha256`, rodado dentro da pasta, devolve **52** linhas `OK`, nenhuma falha, exit
**0**. As 44 entradas que pousaram em `6a9447e` continuam todas no manifest novo com o mesmo hash: o
`git show 56485fb:…/artifacts.sha256` comparado linha a linha com o da árvore de trabalho devolve **0**
linhas só-no-antigo, então nenhum artefato já publicado mudou de bytes.

Depois do push do registro, `git ls-remote --heads origin` trouxe as três refs, e é isso que fecha a
promessa da seção acima: `main` em `56485fb2de824c73ddcee247e5be116e8e666c0f`, `feat/bicho-cavando-12` em
`d62c066e36ef45893d76861b22a7f9b78c188a61` (a branch do código da perna, que **não estava** lá antes) e
`docs/registro-pouso-do-codigo-12` em `6a9447e18520ebd8b6c125e4d553c6bad50c616c`. **Nenhuma branch foi
deletada** — nem a local da perna, nem a remota, nem a de registro, nem a `main`. Esta ponta do registro da
`main` mergida sobe por cima de `56485fb` e o `ls-remote` depois disso é a prova da quarta ref. O que a
árvore mergida **não** mede continua sendo o que a perna deixou: `block_changed` sem consumidor nenhum em
`src/`, o `96.48 ms` sem atribuição depois do furo #31, o par de vazamento do quit, e nenhum gate de fase
fechado.

## Rodada Oráculo Nativo 22 — a pauta dos cinco níveis de IA local, com a Fase 0 medida antes de qualquer linha (2026-11-23, `docs/pauta-oraculo-nativo-22`, base `e7c9f64`)

### A extensão de escopo, registrada antes de qualquer linha de código

O dono manda elevar a IA local — o prompt "Aetherfall: Elevação da IA Local para Outro Nível", cinco
fases, 100 % na máquina dele, com a regra de ouro escrita por ele mesmo: nenhuma camada de linguagem
move um pé, aplica dano ou escreve diretamente no ledger; a mente propõe, as regras determinísticas
dispõem. A pauta vira
[`docs/planos/22-oraculo-nativo-gdextension.md`](planos/22-oraculo-nativo-gdextension.md), a fila
serializada passa a **17 → 18 → 22 → 20 → 13** e o "fora" do contrato perde uma linha: `oráculo nativo
em GDExtension` deixa de estar proibido. O que ele **não** autoriza, e está escrito na página: P2,
facções, co-op, progressão, chefes e o Sistema Operacional (Ob-ragem), que ele mesmo adiou. A Fase 1 é
o escopo autorizado; as Fases 2–5 entram autorizadas **como pauta dentro da mesma perna**, cada uma com
gate próprio e nenhuma linha escrita antes de a anterior fechar o dela. Nada deste lote encosta em
`Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` nem na projeção do `TickJournal`, e **nenhuma linha de
`native/` foi escrita** — a branch é documento puro.

Esta seção fecha no fim do arquivo, e não dentro do "Em andamento" onde o fato também caberia, por um
motivo medido e não por gosto: um parágrafo de 17 linhas inserido na linha 610 empurra para baixo cada
número-alvo abaixo dele, e este status é o arquivo mais citado por linha do repositório — **64**
ponteiros vivos de outras páginas caem entre as linhas 610 e 4420. É exatamente o mecanismo do furo
**#28** (trinta e três números envelheceram em três páginas que a varredura não abriu, e as duas réguas
ficaram verdes). As duas inserções de [`AGENTS.md`](../AGENTS.md) foram desenhadas pela mesma régua: a
linha do "fora" reescrita com o mesmo número de linhas, e o bloco da extensão colocado depois da linha
650, ou seja, depois do maior número de `AGENTS.md` que qualquer página cita hoje (**475**). Assim o
lote não abre trabalho de re-ancoragem para si mesmo nem para as pernas seguintes.

### O que a Fase 0 mede, porque a Fase 1 depende disso e o prompt assume do contrário

- O compilador existe e compila C++17: `cl.exe` **19.44.35207** (MSVC), lido em
  `docs/evidence/oraculo-nativo-22/probe-run-stdout.txt` — não por "tem Visual Studio instalado".
- As cinco DLLs do runtime carregam **dentro de um processo comum** e veem a placa: as linhas 1 a 5 de
  `docs/evidence/oraculo-nativo-22/probe3-stderr.txt` mostram RPC, Vulkan e CPU carregados do
  `.tools/llama/runtime/`, e a linha 5 de `docs/evidence/oraculo-nativo-22/probe3-stdout.txt` devolve
  `ggml_backend_reg_count(): 3`, com `ggml_backend_dev_count(): 2` (linha 9), `dev[0] type=1
  nome=Vulkan0` (linha 10) e `desc=AMD Radeon RX 9060 XT` (linha 11) — a 9060 XT, não a 4060, e o
  `dev[1]` da linha 12 é o Ryzen 7 5700X3D. O rodapé que já confundiu uma leitura vem anotado na própria
  sonda: `ggml_backend_load_all_from_path(runtime) devolve: 0` (linha 4) é código de sucesso, **não**
  contagem de backends.
- O cabeçalho de interface do 4.7.2 é **gerado**, não baixável:
  `docs/evidence/oraculo-nativo-22/gdextension_interface_472.h`, **143 170 B**, com o
  `GDExtensionInitializationFunction` conferido dentro dele (§1.4 da página).
- Os export-sets contados um a um: `llama.dll` **266**, `ggml-base.dll` **689**, `ggml.dll` **16**,
  `ggml-vulkan.dll` **9**, `llama-fit-params-impl.dll` **53** — os cinco dumps em
  `docs/evidence/oraculo-nativo-22/exports-*.txt`. Duas ausências saem dessa contagem e viram
  consequência escrita: `ggml_backend_buffer_type_get_base_buffer` e `llama_params_get_fit_params`
  **não** estão no set pinado, então o `model_oversave` do §8 da página fica `[OPEN]` em vez de virar
  código, e a família `buft_*` mora no `ggml-base.dll`, não no `ggml.dll`.

### Furo #32 — o instrumento leu o próprio redirect e declarou o compilador ausente

**Furo #32 — a sonda de toolchain media o código do `>nul`, não o do `cl.exe`.** A primeira leitura
desta rodada foi "nenhum Visual Studio instalado na máquina", e ela é falsa. O `.bat` da sonda fazia
`call vcvars64.bat >nul` e imprimia `%ERRORLEVEL%` na linha seguinte: o valor lido é o do **redirect**,
nunca o do compilador. A régua que fecha o furo, escrita antes de qualquer sonda nova: nenhum
`echo %ERRORLEVEL%` depois de um redirect na mesma cadeia — ou o teste é `where cl.exe` mais a
compilação de um `.cpp` real com a saída inteira no log, ou o `%ERRORLEVEL%` é lido na mesma instrução
que o chama. Não é detalhe de instrumentação: é a diferença entre "a Fase 1 depende de uma instalação
que não existe" e "a Fase 1 roda hoje nesta máquina", e a primeira frase ia virar premissa de dossiê. O
mesmo mecanismo do `[PASS]` que imprimia `%.3f` sem medir nada e do `grep -c` que conta linhas, não
ocorrências.

### A contagem conferida nesta ponta

Duas corridas na árvore deste lote — `src/` e `tests/` intactos, então o contrato não se move, e ele é
re-medido em vez de declarado:

- suíte: `docs/evidence/oraculo-nativo-22/pauta_22_suite.log:357` devolve
  `== 255 checagens  0 falhas  48.1 s de teste ==`, exit **0**, com **0** `[FAIL]` e **0** `SCRIPT
  ERROR` contados no arquivo, e o par de vazamento do quit na assinatura de sempre — linha 358
  `4 ObjectDB instances were leaked at exit` e linha 360 `2 resources still in use at exit`.
- runner de reações: `docs/evidence/oraculo-nativo-22/pauta_22_runner.log:541` devolve
  `283 checagens 0 falhas 32.901 s`, com o censo `283/283` da linha 538, `65/65` de testes completos na
  536 e `trips_solo=0 trips_matilha=0` na 537. Os dois rodapés de cadência, linhas 539 e 540, são a
  prova de que esta árvore roda **10 568** passos no cenário estreito (`sim_step total=2226134 us`,
  pico `3154 us`) e **1 341** na sessão de matilha (`sim_tick total=3024384 us`, pico `13095 us`) — e é
  por isso que a matriz de ablação de 2026-11-22, feita com **2 768** passos, não se compara a estes
  números.

As três réguas na leitura feita antes de esta seção existir, com o stdout arquivado na mesma pasta:

- âncoras: `docs/evidence/oraculo-nativo-22/pauta_22_ruler_doc_anchors.log:1` e a linha 2 — **39**
  arquivos, **3 039** ponteiros, **209** rótulos, **3 144** links relativos e **0** casos objetivos. O
  zero não é sorte: a leitura que a própria inserção provocou devolvia **2**, e os dois casos são
  deste arquivo — `docs/planos/07-af-bench-bake-off-voxel-e-doc-do-simclock.md:136` cita a linha 626
  desta página e `docs/planos/README.md:308` cita a 3231, e um bloco de **17** linhas posto acima das
  duas deixa as duas em branco. O número não é memória: a inserção foi refeita sob encomenda e o
  stdout está em `docs/evidence/oraculo-nativo-22/pauta_22_ruler_deriva_reproduzida.log`, os dois
  casos nas linhas 2 e 3, `casos objetivos: 2` na 4 e os mesmos **3 050** ponteiros na 1; desfeita a
  inserção, os dois somem e a única âncora que continua sem resolver é a gitignored, que o corpus do
  instrumento exclui. É o furo **#28** medido duas vezes na mesma semana.
- citações: `docs/evidence/oraculo-nativo-22/pauta_22_ruler_plan_cites.log:1` e as linhas 2 e 13 —
  **996** citações com número de linha conferidas, **10** arquivos citados que não existem e **0**
  números fora do arquivo. As dez ausências não são defeito novo: sete são peças que as próprias páginas
  declaram inexistentes (`src/ai/reach.gd`, `src/core/sim/entity_store.gd`, `src/core/sim/tick_clock.gd`,
  `tests/wolf_multiseed_census_test.gd` e as repetições do índice sobre as mesmas) e três são os
  `.tools/_head_*.md` gitignored. Rodar a régua **sem argv** devolve 0/0/0 vazio — a linha de comando
  com os arquivos explícitos está no §11 da página 22.
- identificadores: `docs/evidence/oraculo-nativo-22/pauta_22_ruler_plan_ids.log` nas linhas 1, 3 e 5 —
  **127 · 260 · 141** nomes em backticks conferidos em `AGENTS.md`, no índice e na página 22. As
  ausências de `AfMind`, `mind_oracle.cpp`, `extensao_carrega_classe` e `transporte_http_zerado` são a
  lista do que **ainda não existe**: é o que uma pauta antes do código devolve, e é por isso que a página
  22 não pode ser lida como se o gate dela já estivesse verde.

Uma re-ancoragem este lote exige e paga: a tabela de branches do índice ganhou a linha da 22 e o intro
ganhou a frase da 22, **9** linhas acima da frase da fila; quem lia `docs/planos/README.md:81` lê hoje
`docs/planos/README.md:90`, conferido pelo conteúdo (a frase "A ordem 09 → 10 → … não é preferência") e
não por translação. Os dois lugares que citavam o número velho estão corrigidos: `docs/melhorias-status.md:2614`
e a frase do índice que re-deriva os próprios ponteiros, em `docs/planos/README.md:313`.

As três réguas voltaram a rodar com toda a prosa desta seção escrita, cada uma com o comando
arquivado dentro do próprio log. Âncoras
`docs/evidence/oraculo-nativo-22/pauta_22_ruler_final_doc_anchors.log`: a linha 2 é o stdout de
`python tools/check_doc_anchors.py` nesta árvore — **39** arquivos, **3 052** ponteiros, **209**
rótulos, **3 153** links relativos — e a linha 3, `casos objetivos: 0`; a linha 5 é o mesmo
instrumento com `--ref HEAD`, devolvendo a `main` publicada com **38** arquivos, **2 927** ponteiros,
os mesmos **209** rótulos e **3 046** links, com **0** casos na linha 6. A diferença entre as duas
linhas é o que este lote acrescentou ao corpus: **+1** arquivo (a página 22), **+125** ponteiros e
**+107** links, e nenhum caso novo nos dois lados. Citações
`docs/evidence/oraculo-nativo-22/pauta_22_ruler_final_plan_cites.log` — o comando na linha 1, as
**1 013** conferidas na 2, as **10** arquivos que não existem na 3 (as mesmas peças declaradas
ausentes e os três `.tools/_head_*.md`) e o **0** fora do arquivo na 14, tudo com os cinco documentos
que esta perna toca no comando.
Contra as duas leituras intermediárias do mesmo comando — **996** antes desta seção, **1 011** com
ela escrita — os **+2** de agora são exatamente as duas âncoras do parágrafo da deriva acima.
Identificadores `docs/evidence/oraculo-nativo-22/pauta_22_ruler_final_plan_ids.log` nas linhas 2, 4
e 6, com o comando na 1: **127 · 260 · 141**, os três números inalterados contra a leitura
intermediária, porque esta seção não apresentou nome novo em backticks que a régua tivesse de
procurar. O ponto fixo do lote é este: depois destas três leituras a única escrita foi a dos próprios
dígitos, e dígitos não acrescentam nem removem citação — a régua rodou de novo depois deles e
devolve os mesmos números.

### O que nada disso fecha

Nenhum gate de fase, e a Fase 1 não começou: `HTTPRequest` continua em `src/ai/mind_oracle.gd`
([:42](../src/ai/mind_oracle.gd#L42), [:76](../src/ai/mind_oracle.gd#L76),
[:81](../src/ai/mind_oracle.gd#L81), [:235](../src/ai/mind_oracle.gd#L235)) e em
`llm_server_host.gd` (aposentado no Passo 4 do dossiê 22, commit 5138549)
(`llm_server_host.gd:87`, `llm_server_host.gd:99`, `llm_server_host.gd:184`); nenhuma linha de
`native/` existe; `model_oversave` está `[OPEN]` pela contagem de exports; a VRAM e a latência que o
prompt pede medidas ainda não têm número, porque ainda não há o que medir; e o `MindsInspector`
continua não existindo. A fila era **17 → 18 → 22 → 20 → 13** com a 17 na frente e a perna 22 sem
abrir a branch de código antes de a 18 pousar; o dono liberou essa espera, e o registro está no fim.


## O pouso da pauta 22 na `main` — as quatro corridas da árvore mergida, as três réguas no ponto fixo e o furo #33 do `--script` (2026-11-23, `docs/registro-da-main-mergida-22`, base `8e0fc3b`)

### O que o merge toca, e por que o número pinado da ponta vale aqui

`git merge --no-ff docs/pauta-oraculo-nativo-22` devolve **`8e0fc3b`** sobre **`e7c9f64`**, e
`git diff --name-only e0902ef 8e0fc3b -- src tests` devolve **vazio**: a perna escreve documento, não
engine, então as árvores de `src/` e `tests/` da ponta medida são as da main mergida por identidade.
Mesmo assim as quatro corridas rodaram nela, com a máquina livre — nenhuma linha em `Get-Process`
com `Path` dentro de `C:\Aetherfall` antes da primeira invocação, e medição de tempo serial.

### As quatro corridas da árvore mergida, com o stdout arquivado

- Suíte: `docs/evidence/registro-main-mergida-22/main_mergida_suite.log` — a linha 357 é o contrato
  `== 255 checagens  0 falhas  48.2 s de teste ==`, **exit 0**, zero `[FAIL]` e zero `SCRIPT ERROR`
  nas 361 linhas, e o par de vazamento do quit continua aberto: linha 358
  `WARNING: 4 ObjectDB instances were leaked at exit` e linha 360
  `ERROR: 2 resources still in use at exit`.
- Runner de reações: `docs/evidence/registro-main-mergida-22/main_mergida_runner.log` — linha 536
  `65/65` de testes completos, linha 537 `trips_solo=0 trips_matilha=0`, linha 538 `283/283`, linha
  539 o cenário estreito com **10 568** passos (`sim_step total=2247621 us`, pico `3282 us`), linha
  540 a sessão de matilha com **1 341** passos (`sim_tick total=3120235 us`, pico `14399 us`) e linha
  541 `283 checagens 0 falhas 33.269 s`.
- Journal: `docs/evidence/registro-main-mergida-22/main_mergida_tick_journal_test.log` — linha 142
  `128/128` e linha 143 `128 checagens 0 falhas 7/7 testes concluidos 5.775 s`.
- RNG da sessão: `docs/evidence/registro-main-mergida-22/main_mergida_rng.log` — linha 76 `5/5`,
  linha 77 `27/27` e linha 78 `27 checagens 0 falhas 2.785 s`.

O **48,2 s** e o **33,269 s** de agora contra o **48,1 s** e o **32,901 s** da ponta não são dois
contratos: são a mesma contagem corrida duas vezes, e o gate lê a contagem, não o tempo. Os dois
tempos ficam publicados porque cada um responde a um stdout.

### As três réguas, no ponto fixo, re-derivadas depois do merge

`python tools/check_doc_anchors.py` nesta árvore: **39** arquivos, **3 052** ponteiros, **209**
rótulos, **3 153** links relativos e **0** casos objetivos — os mesmos números da leitura final da
seção anterior, porque este registro é acréscimo no fim do arquivo e não empurra linha nenhuma para
baixo. `--ref HEAD` continua devolvendo a `main` publicada com **38** arquivos, **2 927** ponteiros,
os mesmos **209** rótulos, **3 046** links e **0** casos.
`python .tools/verify_plan_cites.py` com os cinco documentos da perna: **1 013** citações conferidas,
**10** arquivos que não existem, **0** fora do arquivo. `python .tools/verify_plan_ids.py` com os três:
**127 · 260 · 141**. O stdout das três, com o comando escrito dentro do arquivo, está em
`docs/evidence/oraculo-nativo-22/pauta_22_ruler_final_doc_anchors.log`,
`pauta_22_ruler_final_plan_cites.log` e `pauta_22_ruler_final_plan_ids.log` na mesma pasta.

### Furo #33 — o runner chamado sem `--script` não roda teste nenhum: sobe o jogo headless e nunca sai

A primeira tentativa desta rodada foi `godot --headless --path . tests/aether_reactions_test.gd` — o
`.gd` como posicional, sem a flag. O processo não imprimiu rodapé nem encerrou: em **11 minutos** de
wall clock tinha **204 s** de CPU consumidos e um stdout de **14** linhas que era gameplay puro
(`spawn banda 1 (16-46 m de jogador): lar aceito a 48.3 m do jogador`, `toca 0 fundada`,
`nascimento: filhote 6 dos adultos 1+4 na toca 1`). É o projeto rodando a própria cena principal em
headless, não o teste — a forma correta é `--headless --path . --script tests/aether_reactions_test.gd`,
e foi só com ela que as linhas 536 a 541 do log acima existiram. O órfão foi morto por quem o abriu,
na mesma sessão e no mesmo dono, e o log de 14 linhas não virou evidência de nada: foi descartado
antes deste parágrafo. **Dono:** este registro, com a forma correta escrita aqui e no §11 da página
22 — é defeito de instrumento, não de execução, e nada foi silenciado para a corrida ficar verde.

### O que este pouso não fecha

Nenhum gate de fase, e nenhuma linha de `native/` existe. A pauta 22 pousa como o documento que a
Fase 1 tem de cumprir: `HTTPRequest` continua em `src/ai/mind_oracle.gd`, o par de vazamento do quit
continuava aberto, o furo **#31** (a atribuição de carga do espalhamento sem testemunha) continua sem
dono, e `block_changed` continua sem assinante nenhum — quem o assina é a 17, elo logo atrás da
**22 → 17 → 18 → 20 → 13**, a fila com a 22 na frente desde a liberação do dono registrada no fim.


## Rodada 2026-11-24 — a espera da perna 22 liberada pelo dono, a fila movida para `22 → 17 → 18 → 20 → 13` e o que isso custa às pernas 17 e 18 (branch `docs/excecao-de-ordem-fila-22`, base `f387034`)

Nenhuma linha de `native/`, `src/` ou `tests/` foi escrita por esta passada, e ela não é código: é a
**exceção de ordem escrita antes do código**, que o mandato 4 de [`AGENTS.md`](../AGENTS.md) exige. O
que aconteceu, na ordem em que aconteceu:

1. A pauta 22 pousou em `e0902ef` (merge `8e0fc3b`) com a fila **17 → 18 → 22 → 20 → 13** — a 22 atrás
   da 18 pelo motivo então vigente: abrir o oráculo nativo antes obrigaria a 18 a re-rodar o gate dela
   com um `HTTPRequest` a menos na árvore.
2. Na entrega do pouso eu escrevi, como item 3, que o esqueleto de `C++` não vinha porque nenhuma
   linha da Fase 1 podia ser escrita antes de a perna abrir a branch. O dono respondeu
   `pode continuar`, e a frase anterior dele no mesmo prompt já mandava `ajuste pra essas prioridades`.
3. Isso é a palavra dele **liberando a espera** — não a minha. Registada aqui e no §4 e §10 da
   [`página 22`](planos/22-oraculo-nativo-gdextension.md) antes de qualquer commit de código, e a
   branch de código abre da `main` já com este registro dentro.

A fila serializada passa a **22 → 17 → 18 → 20 → 13**. O que muda para quem vem atrás, e é preço real,
não burocracia:

- A **17** (física de blocos que caem) e a **18** (mundo vivo: grama e mato) rebasam numa árvore onde
  o transporte do oráculo pode já ter saído do HTTP. O argumento que as punha na frente deixa de
  evitar o problema e passa a **aceitá-lo**: pelo item 5 de "Branches", cada uma re-rome o gate na
  árvore resultante, e o número publicado volta a ser número medido naquela revisão.
- A **20** continua atrás da 22 pelo motivo original: as duas escrevem a mesma frase de contrato sobre
  o oráculo, e a 22 é a que tem a palavra autoritativa — com a 22 na frente, ela nasce sabendo que o
  modelo é nativo e pode tratar a saúde do oráculo como entrada.
- A **13** continua última: nenhuma mudança de `Channel.COUNT` cai no meio da fila.

O que **não** muda com este registro: nenhum gate de fase se fechou, nenhuma checagem nova nasceu,
nenhum número de corrida foi re-medido aqui (a passada é documento puro — `git diff --name-only
f387034..HEAD -- src tests` devolve vazio), e o contrato publicado continua **255 / 0** na suíte com
**283 / 0** de reações. O que a Fase 1 tem de provar no primeiro commit continua sendo o gate do §5.1
da página: `extensao_carrega_classe` — existe um `.dll` de extensão que o Godot abre, e a classe
registra — com o vermelho de "nenhuma extensão existe" já pago pela Fase 0 e o de "o símbolo não está
no export-set" ainda em aberto.


## Rodada 2026-11-24 (2) — Passo 1 (a) do dossiê 22: quatro leituras que corrigiram a própria página, e os furos #34, #35 e #36 (branch `feat/oraculo-nativo-gdextension-22`, base `e781e38`)

Nenhuma linha de `native/`, `src/` ou `tests/` foi escrita por esta passada, e nenhuma linha de gameplay
foi tocada: `git diff --name-only e781e38..HEAD -- src tests native` devolve vazio. Ela é o
**Passo 1 (a)** do §11 da [`página 22`](planos/22-oraculo-nativo-gdextension.md) — as leituras que têm de
estar na mesa antes de o primeiro `.cpp` do oráculo nativo existir. O produto é o **§12** daquela página,
mais catorze arquivos em [`docs/evidence/oraculo-nativo-22/`](evidence/oraculo-nativo-22/) — seis stdout
literais das leituras, três `.sh` e dois `.bat` que os re-executam, três `.log` das réguas do fim — e o
manifesto da pasta refeito com `-b`: **45 entradas, `sha256sum -c` 45/45 OK**.

Quatro afirmações da página caíram, e cada uma caiu por número lido no comando ou no arquivo:

1. **"o compilador existe" era resposta incompleta.** A pergunta do `build.bat` é *qual* compilador, e a
   máquina tem **três** instalações (VS 2022 Community 17.14.37502.11, VS 2019 BuildTools 16.11.37507.1,
   VS 2022 BuildTools 17.14.37502.11), **dois toolsets** (14.44.35207 e 14.29.30133) e **duas versões de
   `cl`** (19.44.35228 ×2, 19.29.30159). Além disso o §1.1 somava duas grandezas na mesma célula:
   `14.44.35207` é o nome da **pasta** do toolset, não a versão do compilador. Correção e regra no §12.1.
2. **A testemunha de 4.7.2 não discriminava.** `GDExtensionInitializationFunction` e
   `GDEXTENSION_VARIANT_TYPE_*` existem **idênticas** no único cabeçalho local (o do godot-cpp 4.4.1,
   129 768 B / 3 085 linhas / sha `355ff4c6…` — typedef na linha 782, `GDEXTENSION_VARIANT_TYPE_` em
   **48** linhas nos dois). O que separa é `GDExtensionClassCreationInfo6` (`:402`),
   `GDExtensionClassCreateInstance3` (`:220`) e `GDExtensionInterfaceClassdbRegisterExtensionClass6`
   (`:2954`) — e o 4.4.1 tem **0** ocorrências do terceiro. Também não existe `api_version` no JSON (cinco
   chaves de topo, `format_version: 1`): a versão da interface é o que a engine devolve em runtime, não um
   `#define`. §12.2.
3. **O gerador do cabeçalho não tem CLI, e a reprodução foi executada.** `make_interface_header.py`
   (12 015 B, 353 linhas, sha `a4ed7de9…`) tem `__main__`, `argparse` e `sys.argv` em **zero** ocorrências:
   o ponto de entrada é `def run(target, source, env)` (`:27`), um emissor do SCons. Rodá-lo pediu um shim
   de **11 linhas / 267 B / sha `7d0b6de2…`** com as duas funções do `methods.py` da engine e três linhas de
   driver. O fruto — **143 170 B**, sha `777a3fe5…` — foi re-gerado neste passo e comparado com o arquivo
   arquivado: `cmp` exit **0**. §12.2 e `passo1_header_reproducao.log`.
4. **Licença: o bloco está no JSON e o gerador o descarta.** O `_copyright` do JSON (328 021 B,
   9 327 linhas, sha `7d8c0a03…`) tem **27 linhas** com as cinco marcações MIT; no cabeçalho gerado as
   quatro contrapartidas procuradas devolvem **False** e `grep -ci licen` é **0** — o gerador usa
   `_copyright` só como chave válida no `check_allowed_keys` (`:32`) e nunca o escreve. A leitura anterior,
   que contava quatro ocorrências dentro do cabeçalho, tinha sido feita no header do godot-cpp (que tem o
   bloco) e não no gerado. Vendorizar o arquivo é distribuí-lo **sem** licença dentro: a atribuição passa a
   ser linha nossa em `THIRD_PARTY_LICENSES.md`, no mesmo commit que o vendoriza. §12.2 e o §6.1 corrigido.

Duas coisas que a leitura acrescentou e não estavam em lugar nenhum: **zero `.lib`** na árvore inteira e
53 entradas em `.tools/llama/runtime/` (30 `.dll`, 22 `.exe`, uma linha de licença LLVM OpenMP) — ou seja,
o Passo 1 **não linka** o llama.cpp, e o gate de símbolos é do Passo 2 (§12.3); e a **forma do arquivo**,
que é o que o hash mede: as 3 178 linhas do fruto cru terminam todas em CRLF (a forma LF tem 139 992 B; a
diferença é exatamente 3 178, um CR por linha), `native/af_mind/include/**` cai como `text: auto eol: lf`
e `docs/evidence/**` como `text: unset`, então o gate de SHA do `build.bat` confere **as duas formas**
(§12.2, último parágrafo).

As três réguas do §11 foram rodadas com a página já reescrita, e a saída literal está nos três `.log`
`passo1a_ruler_*`: `check_doc_anchors.py` com **39 arquivos, 3 052 ponteiros, 209 rótulos, 3 178 links
relativos e 0 casos objetivos**; `verify_plan_cites.py` com **1 013 citações com número conferidas, 10
arquivos citados que não existem** — os mesmos dez de antes, todos peças que as páginas declaram
inexistentes ou scratch gitignored — e **0 números fora do arquivo**; `verify_plan_ids.py` com as ausências
de costume, nenhuma delas um identificador que alguma página prometa como código que existe. É esse o
número que prova que a página 22 ganhou **186 linhas líquidas** (`git diff --numstat main`: 205 acrescentadas,
19 removidas) sem quebrar nenhum ponteiro que apontava para dentro dela.

### Furo #34 — "o MSVC da máquina" não é único: três instalações e três consultas `-latest` que divergem

`vswhere -latest` devolve `2022\Community`; `vswhere -latest -products *` devolve `2022\BuildTools`;
`vswhere -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64` devolve `2022\Community`. As
três consultas "mais novo" da mesma ferramenta apontam para instalações diferentes, e as duas de 2022
partilham o toolset `14.44.35207` enquanto a de 2019 traz `14.29.30133` — compilador de outra geração, ABI
de outro gerador. Um `build.bat` que resolvesse o VS perguntando ao vswhere "qual é o mais novo" compila
com um toolset que depende da **ordem da consulta**, e o `.dll` da extensão não declara isso em lugar
nenhum. **Dono:** Passo 1 (c) — o `build.bat` nomeia caminho e toolset (`14.44.35207`), confere o banner do
`cl` (`19.44.35228`) e o `VCToolsInstallDir` antes de compilar, e recusa os outros. Testemunha:
[`passo1_build_instrumentado.log`](evidence/oraculo-nativo-22/passo1_build_instrumentado.log) e
[`passo1_vcvars_onde_resolve.log`](evidence/oraculo-nativo-22/passo1_vcvars_onde_resolve.log).

### Furo #35 — o `link` que resolve fora da casca do vcvars é o coreutils do Git, não um linker

No PATH que a máquina tem hoje, sem `vcvars64.bat`, `cl`, `dumpbin`, `lib`, `scons`, `cmake` e `ninja`
saem com exit 1 e nenhuma linha impressa — mas `link` **resolve**:
`C:\Program Files\Git\usr\bin\link.exe`, GNU coreutils 8.32, que cria *hard link de arquivo* e não linka
binário nenhum. O build não falhariaria por ausência com um diagnóstico limpo: falharia (ou pior — criaria
um arquivo com o nome do output) por **presença errada**. Dentro da casca os quatro aparecem sob
`14.44.35207\bin\Hostx64\x64\`, e o `where link` lista o MSVC **antes** do do Git, que continua lá.
**Dono:** Passo 1 (c) — o `build.bat` não aceita um `link.exe` fora de `VCToolsInstallDir`. Testemunha:
[`passo1_fora_da_casca.log`](evidence/oraculo-nativo-22/passo1_fora_da_casca.log) com o
`.bat` do mesmo nome. É a mesma classe do furo #32: o instrumento leu uma coisa e a página escreveu outra.
**Reincidente duas vezes no Passo 2 (a)**, em 2026-11-24, pela borda inversa: dentro da casca do
`vcvars64.bat` foi o `find` que resolveu no `usr\bin` do Git e saiu percorrendo `C:\`, e o `cmd` do Git
Bash comeu a contra-barra do caminho do `build.bat`. As duas instâncias e o corte estão em
"Furo #35 reincidente" adiante, na rodada do passo.

### Furo #36 — manifesto de evidência com hash da forma errada do arquivo: 3 FAILED em 31 entradas

`sha256sum -c artifacts.sha256`, na pasta do dossiê 22, dava **28 OK / 3 FAILED** — os três `.bat`
(`af_exports_build.bat`, `af_np2_build.bat`, `af_np3_build.bat`). As linhas armazenavam o hash da forma
**LF** do conteúdo; os arquivos, no disco e em qualquer clone limpo, são CRLF porque
[`.gitattributes:22`](../.gitattributes#L22) tem `*.bat text eol=crlf` (o `git check-attr` dos três devolve
`text: set`, `eol: crlf`). A convenção da casa — item 11 da lista de furos descobertos desta mesma página —
é que manifesto se computa **`sha256sum -b`**, sobre os bytes que o checkout produz; aqui o erro foi do
instrumento, não da evidência. Refeito com `-b` e com as catorze evidências novas dentro (31 + 14), o
manifesto passou a **45 entradas / 45 OK**, e as únicas linhas de arquivo pré-existente cujo conteúdo
mudou são essas três. **Dono:** este registro, com a régua: `sha256sum -c` de
qualquer manifesto de evidência tem de ser **tudo OK num clone limpo**, e um `FAILED` em `.bat` ou `.log` é
defeito do hash, não do arquivo. Testemunha: [`artifacts.sha256`](evidence/oraculo-nativo-22/artifacts.sha256).

A régua pegou um caso nosso antes do lote fechar: `passo1_vcvars_onde_resolve.bat` tinha sido gravado em
**LF**, e a mesma linha 22 que converte os três `.bat` velhos vale para todo `.bat` do checkout — o hash
registrava bytes que nenhum clone devolve. Convertido e **re-rodado**, o stdout saiu idêntico linha a linha
(nota no topo do próprio [`passo1_vcvars_onde_resolve.log`](evidence/oraculo-nativo-22/passo1_vcvars_onde_resolve.log)),
e o manifesto refeito deu 45/45. Forma que se hash-a é a do checkout, não a do editor.

### O que esta passada não fecha

Nenhum gate de fase e nenhum código: `native/af_mind/` não existe, `HTTPRequest` continua em
`src/ai/mind_oracle.gd`, e `extensao_carrega_classe` — o gate do §5.1 — ainda não nasceu (é o Passo 1 (b),
e nasce vermelho). O contrato publicado não foi re-medido aqui porque a árvore de `src/` e `tests/` não
mudou: **255 / 0** na suíte e **283 / 0** de reações. Dos quatro furos que esta rodada abre, nenhum tem
consequência em runtime hoje — são defeitos de instrumento e de leitura, com dono escrito antes do código —
e a fila continua **22 → 17 → 18 → 20 → 13**.

---

## Rodada 2026-11-24 (3) — Passo 1 (b) do dossiê 22: o gate do esqueleto nativo nasce vermelho, com a conta feita (branch `feat/oraculo-nativo-gdextension-22`, base `85263d5`)

**Puridade medida, não afirmada:** `git diff --name-only 85263d5..HEAD -- src native models` devolve **vazio**.
O que muda é um arquivo de teste ([`tests/aether_reactions_test.gd`](../tests/aether_reactions_test.gd)), a
página do dossiê (§13 dela), esta rodada e a evidência nova em
[`docs/evidence/oraculo-nativo-22/`](evidence/oraculo-nativo-22/). Nenhum arquivo de `native/` existe ainda — e
é justamente isso que faz o vermelho ser honesto: não há `.dll` nenhum para a checagem acusar por engano.

**O que entrou.** `_test_extensao_carrega_classe`
([`tests/aether_reactions_test.gd:5566`](../tests/aether_reactions_test.gd#L5566)) fechou o §5.1 da página 22,
que até aqui prometia a checagem no futuro. São **cinco** premissas impressas em ordem, cada uma chamada só
depois de a anterior confirmar que o objeto existe: **descritor no disco**
(`FileAccess.file_exists("res://native/af_mind/af_mind.gdextension")`), **extensão listada pela engine**
(`GDExtensionManager.is_extension_loaded()`, com `load_extension()` só quando o descritor está presente),
**biblioteca aberta no processo** (`GDExtension.is_library_open()` — a lista da engine não dá esse fato: um
descritor apontando para um `.dll` inexistente entra na lista e não abre), **classe na ClassDB**
(`ClassDB.class_exists("AfMindOracle")`) e **objeto vivo** (`ClassDB.instantiate()` com `get_class()` batendo
o nome). O `-1` impresso na segunda linha é a marca de que a API não foi chamada às cegas: medido em sonda,
`load_extension` sem arquivo faz a engine cuspir dois `ERROR` no stderr, e o vermelho passaria a ser do
instrumento, não da premissa.

**O vermelho medido.** Runner de reações: [`passo1b_runner_vermelho.log`](evidence/oraculo-nativo-22/passo1b_runner_vermelho.log)
traz as cinco linhas `FALHA` e o rodapé **`288 checagens 5 falhas 33.330 s`**, com
`OK censo de testes completos | 66/66` e `OK censo de checagens | 288/288` **acima** delas. Os dois `OK` do
censo são o que separa este vermelho do furo **#1** desta página: as cinco checagens contaram, logo nenhuma
foi roubada por um `SCRIPT ERROR` no meio do passo. As outras duas corridas não se moveram — suíte
**255 checagens / 0 falhas / 48,7 s** ([`passo1b_suite.log`](evidence/oraculo-nativo-22/passo1b_suite.log)) e
journal **128 / 0 / 5,770 s** ([`passo1b_journal.log`](evidence/oraculo-nativo-22/passo1b_journal.log)) — e o
pre-gate de parseio do runner editado saiu **exit 0** ([`passo1b_pre_gate.log`](evidence/oraculo-nativo-22/passo1b_pre_gate.log)).
Os três `stderr` da rodada estão em **0 0 0 bytes** ([`passo1b_stderr_conta.log`](evidence/oraculo-nativo-22/passo1b_stderr_conta.log)):
nenhum `ERROR` de engine, nenhum `SCRIPT ERROR`.

**Censo re-derivado na hora:** `EXPECTED_CHECKS` passa de **283** a **288**
([`:60`](../tests/aether_reactions_test.gd#L64)), e o comentário da linha traz a conta (os 283 da perna 12
mais as cinco deste gate). A régua que confere o censo é a própria linha `_checks + 1 == EXPECTED_CHECKS` de
`_finish`, e é por isso que o número não podia ser estimado: um chute aqui desarma o instrumento inteiro.

**Nenhum `arquivo:linha` do repositório envelheceu com este commit, e o motivo é aritmético, não sorte:** as
três edições no topo do runner substituem linha por linha (hunks `49→49`, `51-56→51-56`, `60→60`) e a função
entrou **depois** da última linha do arquivo (`@@ -5514,0 +5515,58 @@`), então nada abaixo da linha 5 514 se
moveu. Foi decisão de escrita, tomada contra o furo **#28** (trinta e três números envelheceram em três
páginas que a varredura não abriu): mexer no fim do arquivo quando o topo pode ficar do mesmo tamanho.

**As três réguas do §11 do dossiê, na árvore desta rodada:** `python tools/check_doc_anchors.py` deu
**39 arquivos · 3 058 ponteiros · 209 rótulos · 3 194 links · 0 casos objetivos** (eram 3 052 e 3 178 antes
dos links desta passada; exit 0); `python .tools/verify_plan_cites.py AGENTS.md README.md
docs/melhorias-status.md docs/planos/README.md docs/planos/22-oraculo-nativo-gdextension.md` deu **1 019
citações conferidas, 10 arquivos citados inexistentes, 0 números fora do arquivo** (exit 0); e
`python .tools/verify_plan_ids.py AGENTS.md docs/planos/README.md docs/planos/22-oraculo-nativo-gdextension.md`
saiu **exit 0** com as ausências de sempre, todas peças que os próprios dossiês declaram inexistentes
(`AfMindRuntime`, `GDExtensionClassCreationInfo6`, `_copyright`, `model_oversave`). Logs arquivados como
`passo1b_ruler_doc_anchors.log`, `passo1b_ruler_plan_cites.log` e `passo1b_ruler_plan_ids.log`. O dossiê
cresceu **69 linhas** (813 → 882), esta página ganhou uma rodada, e o manifesto da pasta de evidência passa
de 45 a **54 entradas** com os nove logs novos.

**Clone limpo, e o furo #33 pegando esta passada.** `git clone --branch feat/oraculo-nativo-gdextension-22`
do próprio repositório, `--import` frio (exit 0) e, na pasta de evidência, `sha256sum -c artifacts.sha256`
dando **53 entradas OK / 0 não-OK** — cinquenta e três porque o log que registra o clone ainda não estava
dentro do commit clonado, e é a mesma régua do furo #36 em outra árvore. A primeira corrida, porém, foi
convocada errada: `.gd` passado por posição, **sem `--script`**, e a engine boota o jogo headless em vez de
rodar o teste — 909 bytes de stdout com `spawn banda 1 (16-46 m de jogador): lar aceito a 48.3 m do
jogador` e `toca 0 fundada: centro a 48.3 m do jogador, separacao minima nova (e a primeira)`, nenhum `OK`
de teste, e o processo só parou porque o `timeout 400` externo o matou: **exit 124**, 2 060 bytes de stderr
com os `ERROR: BUG: Unreferenced static string` do encerramento. Refeita com
`--script res://tests/aether_reactions_test.gd`, a árvore de fora devolve **exit 1**, **stderr 0 bytes**, as
cinco linhas `FALHA extensao_carrega_classe` literais, `66/66`, `288/288` e rodapé **`288 checagens 5 falhas
33,629 s`** — o vermelho reproduzido fora da árvore de trabalho, em `passo1b_clone_limpo.log`. Que a regra
`--script` continue sendo cobrada é exatamente o motivo de o furo existir.

**Nota de instrumento, com o par medido.** A primeira sonda de API desta rodada **pendurou**: ela lia
`m["return_class"]` do dicionário de `ClassDB.class_get_method_list`, a chave não existe na 4.7.2, o
`SCRIPT ERROR` derrubou `_initialize` antes do `quit()` e o `SceneTree` ficou vivo — órfão PID 24080, morto
por quem o criou, e a corrida não mediu nada. O par que fecha a atribuição rodou nesta máquina: o mesmo
script com `--check-only` devolve **exit 0** (a régua de parseio não vê erro de chave em runtime), e o mesmo
script sob `timeout 60` devolve **exit 124** (foi o `timeout` que matou, não o teste). Ou seja: a defesa não
é o pre-gate — é o `timeout` externo em **toda** corrida headless, inclusive nas sondas, regra que a casa já
escreveu e que aqui foi violada por mim antes de ser conferida. Toda corrida desta rodada, a partir da
segunda sonda, rodou sob `timeout 90/300/400` com o código do processo lido.

### O que esta passada não fecha

Nenhum gate de fase, e nenhum `.dll`: `native/af_mind/` continua inexistente, `HTTPRequest` continua em
`src/ai/mind_oracle.gd`, e as cinco linhas de `extensao_carrega_classe` seguem vermelhas até o Passo 1 (c) —
`build.bat` com o toolset pinado (§12.1 da página 22) e o gate de SHA nas **duas formas** do cabeçalho
(§12.2), o cabeçalho vendorizado com a linha de licença em `THIRD_PARTY_LICENSES.md` no mesmo commit (§6.1) e
`register_types.cpp` registrando **uma** classe sem função de IA. A `main` pousada continua em **255 / 0** e
**283 / 0** na revisão dela; o pouso desta perna se dá com o runner em **288 / 0**, e a regra de ouro do
prompt ("a mente propõe, as regras dispõem") continua sem testemunha de runtime porque ainda não existe
prompt nenhum para desobedecer — ela é cobrada no Passo 3. A fila continua **22 → 17 → 18 → 20 → 13**.

## Rodada 2026-11-24 (4) — Passo 1 (c) do dossiê 22: `native/af_mind/` existe, a engine abre a biblioteca e devolve um objeto vivo (branch `feat/oraculo-nativo-gdextension-22`, ponta anterior `6cfa469`)

**O que entrou, e onde cada arquivo está.** Cinco arquivos novos em `native/af_mind/` e um documento
mexido: [`af_mind.gdextension`](../native/af_mind/af_mind.gdextension) (14 linhas, 502 B),
[`build.bat`](../native/af_mind/build.bat) (167 linhas, 7 954 B, CRLF),
[`src/register_types.cpp`](../native/af_mind/src/register_types.cpp) (183 linhas, 8 734 B, LF),
[`include/gdextension_interface.h`](../native/af_mind/include/gdextension_interface.h) (139 992 B, LF,
`4c0aac8da3df…`) e o sidecar [`af_mind.gdextension.uid`](../native/af_mind/af_mind.gdextension.uid) (20 B),
que a engine escreve no primeiro `--import` e que entra no git para o clone limpo não aparecer sujo — a
mesma lição do furo **#25**, lida ao contrário. O `bin/` fica fora pela linha 8 do `.gitignore`, conferida
arquivo por arquivo com `git check-ignore -v`. A linha de licença do cabeçalho vendorizado está em
[`THIRD_PARTY_LICENSES.md`](../THIRD_PARTY_LICENSES.md) **no mesmo commit**, que é o que o §6.1 da página 22
exige: o gerador de interface valida a chave `_copyright` do JSON e nunca a escreve, então o arquivo
chegaria sem atribuição nenhum sem ela.

**A régua do build, executada.** `cmd //c native\af_mind\build.bat` devolve exit 0, stderr 0 bytes e oito
linhas de `[regua]`, com `header_sha256=4c0aac8da3df… forma=aceita`, `toolset=14.44.35207`,
`cl_banner=… 19.44.35228 for x64`, `dll_bytes=105472` e `export= 1 00001120 af_mind_entry`
([`passo1c_build_final.log`](evidence/oraculo-nativo-22/passo1c_build_final.log)). O §12.1 e o §12.2 da
página deixaram de ser promessa: as duas formas do cabeçalho estão escritas no `.bat`, o toolset é comparado
caractere a caractere e o 2019 desta máquina é recusado com `[falha]` impressa.

**O `instantiate` foi decidido por A/B, não pelo header.** Quatro premissas passavam e a quinta derrubava o
processo com **exit 127** e **stderr 0 bytes**. Das duas candidatas na mesa, a sonda eliminou a primeira
corrida: `p3_aberta=true` e `p4_class_exists=true` diziam que o nome estava certo no registro. O par que
fecha a atribuição está arquivado: construir pelo **pai built-in** devolve
`p5_get_class=AfMindOracle refcounted=true iid=-9223372010229332533` e `p5_metodos=66` com stderr vazio
([`passo1c_arm1_probe.log`](evidence/oraculo-nativo-22/passo1c_arm1_probe.log)), e construir pelo **nosso
nome**, com um contador de profundidade instalado só para a medição, para o stdout em
`p4_class_exists=true` e cospe no stderr
`ERROR: af_mind: create_instance entrou de novo em si mesmo (profundidade 9)`
([`passo1c_arm2_probe.err`](evidence/oraculo-nativo-22/passo1c_arm2_probe.err),
[`passo1c_arm2_probe.log`](evidence/oraculo-nativo-22/passo1c_arm2_probe.log)). O contador foi **removido**
depois: arquivo restaurado, re-compilado, e os mesmos 105 472 B e o mesmo offset `00001120` do braço 1. Os
66 métodos são os herdados de `RefCounted` — o `GDExtensionClassCreationInfo6` é zero-initialized e não
declara método nenhum, que é o recorte do Passo 1.

**O gate verde, com as cinco linhas literais.** Runner de reações **`288 checagens 0 falhas 33,813 s`**,
exit 0, stderr 0 bytes, com as cinco `OK extensao_carrega_classe` em ordem
([`passo1c_runner_pos_build.log`](evidence/oraculo-nativo-22/passo1c_runner_pos_build.log), linhas 535-539)
e os dois censo acima delas (`66/66`, `288/288`). A árvore do commit foi re-confirmada depois da última
compilação: as mesmas cinco linhas, **`288 0 34,852 s`**, exit 0 e stderr 0 bytes
([`passo1c_confirm_runner.log`](evidence/oraculo-nativo-22/passo1c_confirm_runner.log)). As outras três
corridas na mesma árvore: suíte **255 checagens / 0 falhas / 49,3 s**
([`passo1c_suite_pos_build.log`](evidence/oraculo-nativo-22/passo1c_suite_pos_build.log)), RNG
**27 / 0 / 2,703 s** e journal **128 / 0 / 7 de 7 / 5,809 s**. A suíte de confirmação deu **255 / 0 / 48,8 s**
com zero `SCRIPT ERROR` e stderr de **249 bytes** — e os 249 bytes são as duas linhas do par de vazamento do
quit (`4 ObjectDB instances were leaked at exit`, `2 resources still in use at exit`), nomeadas por
`--verbose` na seção da perna 11 como `AudioStreamPlaybackOggVorbis` / `AudioStreamOggVorbis` de
`assets/audio/amb/amb_birds.ogg`, intermitentes por medição da época. Nenhuma das duas menciona `af_mind`;
o débito continua o mesmo e esta corrida é testemunha nova de que ele sobrevive à extensão.

**O vermelho intermitente voltou uma vez nesta árvore, e a atribuição não é daqui.** A primeira corrida de
fecho deu `FALHA nenhum estouro de subtree no budget | trips_solo=0 trips_matilha=1` com o pico de BT da
matilha em 418 µs contra o `SubtreeGuard` de 400 µs
([`passo1c_runner.log`](evidence/oraculo-nativo-22/passo1c_runner.log), linha 542). Amostra arquivada desta
árvore: **8 corridas com a extensão no disco — 1 vermelha, 7 verdes — e 2 com o descritor fora da árvore, as
duas verdes**. A ablação reproduz o vermelho da (b) sob demanda (288 / **5** falhas, as cinco
`FALHA extensao_carrega_classe` literais) e não move o contador de `trips`; dois braços não distinguem
1-em-8 de 0-em-2, então o que fecha a atribuição é a assinatura existir **antes** desta perna, em cinco
corridas arquivadas das pernas 10 e 11 —
`alcateia-rutinas/contagio-runner-2.log:153`, `amortecimento-runner-2.log:157`,
`ataque-runner-1.log:319` e, no **braço de controle** da perna 11, `acasalamento-censo-11/control_main_runner03.log:275`
e `..._runner10.log:276` — e o **furo #20**: o guard cronometra parede de relógio. Um ponto que esta passada
corrige em prosa antiga da página 22: o guard **retorna FAILURE** ao estoura
([src/ai/behavior/bt_tree.gd:134-136](../src/ai/behavior/bt_tree.gd#L134-L136)), então `trips` não é só
medição — é a árvore daquela passada perdendo o nó. A colheita que falta para fechar o #20 por dentro (qual
folha, em qual tick) continua em aberto e nenhuma linha dela é escrita aqui.

### Furo #37 — o importador do editor comia o `.obj` do linker como malha Wavefront

Descoberto e **fechado** nesta perna. Um `--import` desta árvore devolvia **464 bytes** de stderr com três
`ERROR`: `Couldn't read OBJ file 'res://native/af_mind/bin/register_types.obj'`
(`resource_importer_obj.cpp:236`), `Condition "meshes.size() != 1" is true. Returning: ERR_BUG`
(`resource_importer_obj.cpp:691`) e `Error importing ...` (`editor_file_system.cpp:3093`), e deixava um
`register_types.obj.import` ao lado do arquivo
([`passo1c_import_sem_gdignore.err`](evidence/oraculo-nativo-22/passo1c_import_sem_gdignore.err)). O
`build.bat` agora escreve `bin/.gdignore` antes de compilar — o mecanismo da própria engine para tirar a
pasta da varredura — e imprime `[falha]` se não conseguir criá-lo; o `--import` seguinte devolve **exit 0 e
stderr 0 bytes** ([`passo1c_import_com_gdignore.err`](evidence/oraculo-nativo-22/passo1c_import_com_gdignore.err)),
re-confirmado nesta passada ([`passo1c_confirm_import.err`](evidence/oraculo-nativo-22/passo1c_confirm_import.err)).
A régua que fica: **um artefato de build dentro de `res://` entra no escrutínio do importador do editor**, e
`bin/` gitignored não é proteção nenhuma — é o `.gdignore` que protege.

### Furo #38 — quem clona e não compila vê três `ERROR` em cada boot (aberto, decisão do dono)

Com o descritor no disco, a linha no `.godot/extension_list.cfg` e o `.dll` **ausente** — o estado de todo
clone deste commit cujo dono não rodou `build.bat` — a engine reclama em cada boot na cena real: exit 0, o
jogo abre, e o stderr sai com **447 bytes**
([`passo1c_boot_sem_dll.err`](evidence/oraculo-nativo-22/passo1c_boot_sem_dll.err)): `!FileAccess::exists`
em `open_dynamic_library` (`platform/windows/os_windows.cpp:483`), `GDExtension dynamic library not found`
(`core/extension/gdextension.cpp:810`) e `Error loading extension` (`gdextension_manager.cpp:333`). Nada em
`src/` consome a extensão, então o jogo está intacto, mas ruído de três linhas por boot num repositório
público vai ser lido como defeito do jogo. As duas mãos estão postas com o custo de cada uma: **(a)** o
`.dll` de 105 472 B entrar no git (produto nosso, MIT, recompilável pelo `build.bat`; custo: binário por
revisão num repositório que hoje só guarda fontes e packs com licença por arquivo); **(b)** `Rodar.bat` e o
README chamarem `native\af_mind\build.bat` como passo de onboarding, com pré-gate do toolset (§12.1; custo:
quem não tem MSVC 2022 vê recusa em vez de abrir o jogo). **Dono: o dono do repositório escolhe a mão.**
Enquanto ele não escolhe, o furo fica aberto com este número medido, e esta perna não decide por ele.

### Furo #39 — a régua de identificadores não vê a quarta raiz de código (aberto, decisão do dono)

`verify_plan_ids.py` monta o corpus com três globos — `src/**/*.gd`, `tests/**/*.gd`, `tests/*.gd` — e
`native/` não é nenhum deles. Com os cinco arquivos deste commit no disco, a régua rodando na árvore final
([`passo1c_ruler_plan_ids.log`](evidence/oraculo-nativo-22/passo1c_ruler_plan_ids.log)) diz que a página 22
tem **195** identificadores em backticks e **87** AUSENTES — e **24** desses 87 existem agora dentro de
`native/`. Conferidos à mão, nome por nome, com a mesma regra de substring da régua: **20** são reais (14
símbolos de ABI pelos quais o `.dll` se registra, `AfMindOracleInstance` e as cinco réguas do `.bat`), **4**
coincidem por substring com palavras maiores (`HEAD` dentro de `HEADER_SHA`, `Signal` dentro de
`GDExtensionInterfaceClassdbRegisterExtensionClassSignal`, `interface` e `types` dentro de identificadores
compostos) e **63** continuam fora das três raízes. A tabela com a origem de cada um está no §14.7 da
página, junto da contraprova: dois dos 20 entraram na lista **por causa do próprio §14.7**, que precisou
nomear a variável e o símbolo para explicar a coincidência — a régua ficou dois identificadores mais cega no
passo em que o defeito foi escrito. O rótulo impresso nunca mentiu ("AUSENTES **em src/ e tests/**"), mas a
leitura que a casa faz dele, sim, e por isso o §12 da página 22 foi reescrito com esta subseção como
antecedente. Esta passada não conserta: **(1)** `.tools/` é gitignored — `git check-ignore -v
.tools/verify_plan_ids.py` devolve `.gitignore:5:.tools/` com exit 0, então nenhum commit leva a correção
junto — e **(2)** alargar o corpus muda o veredito de uma régua já publicada (as rodadas da 12 e da 16
citam **84 / 11** e **88 / 22**, medidos com três globos), que é a classe do furo #36. **Dono: o dono do
repositório**, no passo que transformar `.tools/` em instrumento versionado.

### Uma frase que a rodada escreve porque a corrida obrigou

**O `--import` é quem põe a extensão na lista do boot, não a presença do arquivo.** Com a cache anterior ao
`native/`, a sonda em cena real devolvia `b2_ja_no_boot=false`, `b2_lista=[]`, `b3_class_exists=false`
([`passo1c_boot_cache_velho.log`](evidence/oraculo-nativo-22/passo1c_boot_cache_velho.log)); feito o
`--import`, o `.godot/extension_list.cfg` ganha a linha do descritor e a mesma sonda devolve
`b2_ja_no_boot=true`, `b4_total_registradas=1`, `b3_class_exists=true`
([`passo1c_boot_pos_import.log`](evidence/oraculo-nativo-22/passo1c_boot_pos_import.log), exit 0, stderr 0
bytes). O passo já era obrigatório no protocolo de clone do README, então nada muda para quem segue a ordem
— mas o `load_extension=-1 ja_vinha_do_boot=true` da segunda linha do gate agora tem antecedente certo, e a
corrida com cache antiga imprimiu `load_extension=0 ja_vinha_do_boot=false` com as cinco premissas verdes:
o sentinela existe exatamente para as duas situações aparecerem escritas.

### O que esta passada não fecha

Nenhum gate de fase (mandato 4), e nada de IA dentro da extensão: `AfMindOracle` tem construtor, destruidor
e um marker `0x41464D31` ("AFM1"), nenhum método, nenhum `load_pack`, nenhum enqueue. O §1.3 — gate de
**símbolos** com as import libs geradas do export-set medido e `/DELAYLOAD` — é o **Passo 2**, e é nele que
a premissa "o `.dll` resolve as DLLs do runtime no diretório do processo" passa a ser checada (§5.1). O
transporte continua HTTP: `src/ai/mind_oracle.gd` não sabe que a extensão existe, e a régua
`git diff --name-only main...HEAD -- src` devolve **vazio** nesta ponta — de que segue, sem re-corrida, que
`Channel.COUNT`, `FORMAT_VERSION` e `GEN_VERSION` continuam intocados e os hashes de journal publicados nas
rodadas anteriores valem para a árvore resultante. O descritor só tem chaves `windows.*`, porque o §12.1
mediu **um** compilador; o comportamento em Linux ou macOS é `[OPEN]` e a perna que o medir é a que adiciona
a chave. O censo do runner é 283 → **288**, pago na (b). A página 22 cresceu **322 linhas** (882 → 1 204)
com o §14 inteiro, esta rodada entra no histórico, e o manifesto da pasta de evidência passa de 54 a **92
entradas** — os 38 logs novos desta passada, `sha256sum -c` conferido no fim. As três réguas, rodadas com a
página e esta rodada já reescritas, estão em `passo1c_ruler_doc_anchors.log` (**39 arquivos · 3 062
ponteiros · 209 rótulos · 3 237 links · 0 casos objetivos**), `passo1c_ruler_plan_cites.log` (**1 024
citações conferidas, 10 arquivos inexistentes, 0 números fora do arquivo**) e `passo1c_ruler_plan_ids.log`
(**195 identificadores na página 22, 87 AUSENTES**) — e é o **furo #39** o número que esta passada abre e
não fecha: 24 dos 87 existem hoje dentro de `native/`, que a régua não alcança. A fila continua
**22 → 17 → 18 → 20 → 13**.

## O pouso do Passo 1 (c) na `main` — o `src` provado por hash de árvore, as quatro corridas da mergida, o build dentro do clone limpo e as réguas no ponto fixo (2026-11-24, `docs/registro-pouso-passo1c-22`, base `6b817a5`)

### O que o merge toca, com o número em cada régua

`git merge --no-ff feat/oraculo-nativo-gdextension-22` devolve **`6b817a5`** sobre **`85263d5`** (pais
da ponta: `cd7fd7c`), **57 arquivos, +11 949/−20**. A régua que o §14.6 da página 22 escreveu como
`git diff --name-only main...HEAD -- src` vazio foi re-fechada na árvore mergida, e o número é mais
forte que o diff: `git rev-parse 6b817a5:src` = **`f77c1961bb8065ea5a78b24677a36c5840891c75`** =
`git rev-parse 85263d5:src` — a mesma árvore do pouso da 12. Disso segue, sem re-corrida e sem adjetivo,
que `Channel.COUNT`, `FORMAT_VERSION` e `GEN_VERSION` continuam intocados e que os hashes de journal
publicados nas rodadas anteriores valem para a árvore resultante. `tests/` **não** vale por identidade:
`4855f0e85c88…` → **`0faee7ff5b26…`**, uma linha (`tests/aether_reactions_test.gd`, o gate nascido na
(b)) — e é por isso que o censo 283 → **288** é medição nesta árvore, não herança. Em `native/` entram os
cinco arquivos do esqueleto, mais `THIRD_PARTY_LICENSES.md` no mesmo commit de código: a quarta raiz do
repositório, cujo efeito sobre as réguas é o **furo #39**, escrito no §14.7 da página.

Publicação conferida com `git ls-remote --heads origin`: `refs/heads/main` =
**`6b817a59180d43ff0d6b8cb6d9c016fac40d82eb`**, `refs/heads/feat/oraculo-nativo-gdextension-22` =
`cd7fd7c4f4a778e2b1ee76a75414e46e7f0fe2f4`. É a única prova de que saiu; o exit 0 do `push` não prova.

### As quatro corridas da árvore mergida, com a máquina livre

Antes delas, `--import` na árvore mergida: exit 0, stderr **0 bytes**, e o `.godot/extension_list.cfg`
com a linha `res://native/af_mind/af_mind.gdextension`
([`main_mergida_import.log`](evidence/registro-pouso-passo1c-22/main_mergida_import.log)). Nenhuma linha
em `Get-Process -Name Godot*` antes da primeira invocação, e as corridas de tempo rodaram serial.

- Suíte: [`main_mergida_suite.log`](evidence/registro-pouso-passo1c-22/main_mergida_suite.log) — linha
  **359** `== 255 checagens  0 falhas  48.6 s de teste ==`, exit 0, zero `SCRIPT ERROR`, e
  [`main_mergida_suite.err`](evidence/registro-pouso-passo1c-22/main_mergida_suite.err) com **0 bytes**:
  nesta corrida o par de vazamento do quit não apareceu. Ele volta no clone limpo, logo abaixo, com as
  duas linhas nomeadas — as duas testemunhas ficam arquivadas porque a intermitência é a afirmação.
- Runner de reações: [`main_mergida_runner.log`](evidence/registro-pouso-passo1c-22/main_mergida_runner.log)
  — linhas **537-541** as cinco `OK extensao_carrega_classe` em ordem, descritor no disco, extensão
  carregada no boot, `is_library_open=true`, `class_exists(AfMindOracle)=true` e
  `instantiate_valido=true get_class=AfMindOracle`; **543** `66/66`, **545** `288/288`, **546** cenário
  estreito com **10 568** passos (`sim_step total=2 220 787 µs`, pico `3 478 µs`, `trips=0`), **547**
  matilha com **1 341** passos (`sim_tick total=3 080 492 µs`, pico `13 169 µs`, `trips=0`) e **548**
  `288 checagens 0 falhas 33,417 s`. Exit 0, stderr de 0 bytes
  ([`main_mergida_runner.err`](evidence/registro-pouso-passo1c-22/main_mergida_runner.err)).
- RNG da sessão: [`main_mergida_rng.log`](evidence/registro-pouso-passo1c-22/main_mergida_rng.log) — **79**
  `27/27`, **80** `27 checagens 0 falhas 2,682 s`.
- Journal por tick: [`main_mergida_journal.log`](evidence/registro-pouso-passo1c-22/main_mergida_journal.log)
  — **144** `128/128`, **145** `128 checagens 0 falhas 7/7 testes concluidos 5,881 s`.

Os dois `trips=0` não fecham o **furo #20**: o guard mede parede de relógio, a amostra arquivada da (c)
continua em 7 verdes e 1 vermelha com a extensão no disco, e a colheita que diria qual folha estoura em
qual tick segue por escrever.

### O pin: clone limpo de `6b817a5`, com o `build.bat` rodando dentro dele

`git clone` do repositório local, HEAD `6b817a59180d43ff0d6b8cb6d9c016fac40d82eb` e `git status --short`
**vazio** — é o sidecar `af_mind.gdextension.uid` comitado que faz um clone limpo não aparecer sujo, o
furo #25 lido ao contrário. O `bin/` não vem (linha 8 do `.gitignore`), então o build faz parte do pin.

- Cabeçalho no clone: `4c0aac8da3dfedc14d0e049205aeaaa11f32802bee56d4a275a466ac231fa916`, **139 992 B** —
  a forma LF que o §12.2 da página aceita e que o `eol=lf` do `.gitattributes` devolve num checkout
  Windows. O gate do toolset lê o mesmo número da branch.
- `cmd //c native\af_mind\build.bat` no clone
  ([`clone_limpo_build.log`](evidence/registro-pouso-passo1c-22/clone_limpo_build.log), stderr 0 bytes):
  exit 0 e as oito `[regua]` com `forma=aceita`, `toolset=14.44.35207`,
  `cl_banner=… 19.44.35228 for x64`, `dll_bytes=105472` e `export= 1 00001120 af_mind_entry` — os mesmos
  **105 472 B** e o mesmo offset `00001120` medidos na branch, o que é a prova de que o `.cpp` comitado é
  o `.cpp` compilado.
- `--import` frio ([`clone_limpo_import.log`](evidence/registro-pouso-passo1c-22/clone_limpo_import.log),
  303 linhas, exit 0, stderr 0 bytes) escreve o `extension_list.cfg` com o descritor.
- Runner: [`clone_limpo_runner.log`](evidence/registro-pouso-passo1c-22/clone_limpo_runner.log) — as cinco
  `OK extensao_carrega_classe` nas mesmas linhas **537-541**, `66/66` em 543, `288/288` em 545, cenário
  estreito `sim_step total=2 249 042 µs` pico `4 110 µs` e matilha `sim_tick total=3 087 998 µs` pico
  `13 569 µs`, ambos `trips=0`, e **548** `288 checagens 0 falhas 33,552 s`; exit 0, stderr 0 bytes.
- Suíte: [`clone_limpo_suite.log`](evidence/registro-pouso-passo1c-22/clone_limpo_suite.log) linha **359**
  `== 255 checagens  0 falhas  48.8 s de teste ==`, exit 0, zero `SCRIPT ERROR` e
  [`clone_limpo_suite.err`](evidence/registro-pouso-passo1c-22/clone_limpo_suite.err) com **249 bytes**: as
  duas linhas do par de vazamento do quit (`4 ObjectDB instances were leaked at exit`,
  `2 resources still in use at exit`). Nenhuma das duas menciona `af_mind`; o débito continua o mesmo.
- RNG **27 / 0 / 2,701 s** e journal **128 / 0 / 7 de 7 / 5,758 s**, exit 0 e stderr 0 bytes nas duas
  ([`clone_limpo_rng.log`](evidence/registro-pouso-passo1c-22/clone_limpo_rng.log),
  [`clone_limpo_journal.log`](evidence/registro-pouso-passo1c-22/clone_limpo_journal.log)).

O número pineado para esta árvore é, na ordem das quatro corridas: suíte **255 / 0**, runner **288 / 0**
com as cinco premissas da extensão, RNG **27 / 0**, journal **128 / 0**.

### As três réguas no ponto fixo desta passada

Rodadas com o §14.8 da página e esta rodada escritos, e re-rodadas depois de o manifesto existir:
`pouso_ruler_doc_anchors.log` devolve **39 arquivos · 3 062 ponteiros · 209 rótulos · 3 254 links ·
0 casos objetivos** — os 17 links novos são os ponteiros do §14.8 para os logs e para o manifesto, e o
corpus não ganhou arquivo porque a pasta nova é `.log`, não `.md`. `pouso_ruler_plan_cites.log` segue com
**1 024 citações conferidas, 10 arquivos inexistentes, 0 números fora do arquivo**, exatamente os três
números da (c): esta rodada cita linha de log arquivado, não de código. E `pouso_ruler_plan_ids.log` move
a página 22 de **195 / 87** para **196 / 88** — com **24** ainda dentro de `native/` e **64** fora das três
raízes. O identificador novo é `f77c1961bb8065ea5a78b24677a36c5840891c75`, o hash de árvore que o §14.8
citou em backticks para provar que o `src/` não mudou: a régua ficou um identificador mais cega no exato
passo em que a prova do pouso foi escrita, que é a mecânica do **furo #39** repetida em vez de resolvida.

### O que o pouso deixa aberto

Nenhum gate de fase (mandato 4). Dentro da perna faltam o **Passo 2** (gate de símbolos com as import libs
do export-set medido e `/DELAYLOAD`, §1.3 e §5.1), o **Passo 3** (testemunha da regra de ouro) e o
**Passo 4** (`transporte_http_zerado`). Dos furos, **#38** e **#39** continuam abertos e são decisão do
dono, e o **#20** continua sem a colheita que nomeia a folha. A fila serializada não muda:
**22 → 17 → 18 → 20 → 13**, e a 22 segue na frente porque a perna não fechou.

*(Estado re-derivado em 2026-11-24, rodada (5) abaixo: deste parágrafo o **Passo 2** partiu-se em duas
metades e a **(a)** rodou — faltam a **(b)** (os três números de §5.2), o Passo 3 e o Passo 4. O resto da
frase continua válido, e o **#40** é novo.)*

## Rodada 2026-11-24 (5) — Passo 2 (a) do dossiê 22: o gate de símbolos executado, os import libs do export-set medido, e a premissa do diretório do processo medida **FALSA** (branch `feat/oraculo-nativo-passo2-22`, base `fa5ea79`)

**O que o §5.1 cobrava e o que este lote executa.** A página 22 tirou duas frases do Passo 1 e as escreveu
como débito do Passo 2: o gate de **símbolos** do §1.3, "com import libs gerados do export-set medido e
`/DELAYLOAD`", e a premissa de que "o `.dll` resolve as DLLs do runtime no diretório do processo". As duas
foram executadas. O bloco tem seis etapas, na ordem, dentro do [`native/af_mind/build.bat`](../native/af_mind/build.bat#L113)
(355 linhas, 17 371 B, CRLF; **+188** sobre a base): `.def` do export-set medido, os quatro import libs, o
link do gate com `/DELAYLOAD`, a régua de posse de módulo, as duas corridas (`nu` e `preload <runtime>`) e o
controle negativo. O veredito é `BUILD_RC=0` sobre **190 linhas** de stdout+stderr mesclados
([`passo2a_build.log`](evidence/oraculo-nativo-22/passo2a_build.log)), `grep -c -i warning` **0**
([`passo2a_build_split_stderr.log`](evidence/oraculo-nativo-22/passo2a_build_split_stderr.log) tem a mesma
varredura: **0** linhas com `warning` ou `error`). Nada do que o gate faz chega a `src/`: o fruto é um
**exe de gate**, não um binding — `AfMindOracle` continua com construtor, destruidor e o marker
`0x41464D31`.

**A forma do log foi medida separada, e o que o stderr tem é informação do runtime.** Uma re-corrida com as
duas correntes em arquivos distintos devolve **185 linhas / 10 557 B** de stdout
([`passo2a_build_split_stdout.log`](evidence/oraculo-nativo-22/passo2a_build_split_stdout.log)) e
**5 linhas / 507 B** de stderr — e as cinco linhas são o `load_backend: loaded RPC/Vulkan/CPU backend` e o
`ggml_vulkan: Found 1 Vulkan devices` que o próprio llama.cpp escreve na hora do load, não aviso do build.
Por isso o log arquivado mesclado tem 190 linhas e o separado tem 185: a diferença é exatamente esse bloco,
e as duas formas estão no repositório para que o número de linhas de uma não se leia como o da outra.

**O endereço impresso do slot não é estável entre corridas — e é por isso que a régua não é endereço.** Na
re-corrida, os 37 slots saem com a base `00007FF70A9E…` contra `00007FF761BD…` do log arquivado: é o
*image base* do exe mudando a cada processo (ASLR). A cauda — o deslocamento dentro da imagem, `…1D28`,
`…1DB3`, `…1C08` — é idêntica nas duas. O que o gate checa são códigos de saída e contagens, nunca endereço,
e a testemunha que importa é `[exe] diretorio_do_processo=` e a existência do slot, não o valor.

**Os `.def` nascem do dump arquivado e a re-medida contra o runtime vivo recusa divergência.**
`gen_import_libs.py` (217 linhas, 10 604 B, LF) lê os dumps do pin `b12499` e, havendo runtime em
`.tools\llama\runtime`, compara nome a nome: as cinco `[remedio]` do log dizem `iguais` nos cinco módulos
(53, 689, 9, 16, 266 nomes). As linhas `[def]` (13-21) dão o par export-total × entradas — `llama.dll`
**266 / 240** (240 C puro, 26 C++ decorado), `ggml-base.dll` **689 / 687**, `ggml.dll` **16 / 16**,
`ggml-vulkan.dll` **9 / 9**, `llama-fit-params-impl.dll` **53 / 3** — e a diferença é medida, não descuido:
o `.def` desta etapa só traz os nomes C puro, que é a forma com que o gate os referencia. Os quatro import
libs saem com bytes testemunhados — `llama 58 326`, `ggml 5 288`, `ggml-base 154 094`, `ggml-vulkan 3 926`
— e `lib` não imprime nada em sucesso, então o arquivo com bytes **é** a testemunha.

**A régua de posse não copia lista nenhuma, e os 37 nomes fecham.** [`check_imports.py`](../native/af_mind/check_imports.py)
(192 linhas, 8 852 B, LF) cruza três listas geradas — os **referenciados** saem das linhas `AF_SLOT(nome)`
do próprio [`symbol_gate.cpp`](../native/af_mind/src/symbol_gate.cpp) (311 linhas, 13 725 B), o **dono** sai
dos `.def`, o **importado** sai de `dumpbin /imports` do binário
([`passo2a_gate_imports.txt`](evidence/oraculo-nativo-22/passo2a_gate_imports.txt), 185 linhas) — e recusa
nome que apareça em dois `.def`. Com o exe em `gate_exe_bytes=157696`:

```
[referencia] gate AF_SLOT=37 nomes
[import] modulo=ggml-base.dll referenciado=10 na_tabela=10
[import] modulo=ggml-vulkan.dll referenciado=4 na_tabela=4
[import] modulo=ggml.dll referenciado=5 na_tabela=5
[import] modulo=llama.dll referenciado=18 na_tabela=18
[import] OK referenciados=37 modulos=4 nomes_na_tabela=37
```

**A premissa do diretório do processo é FALSA nesta máquina, medida, e o gate recusou em vez de morrer.**
As cinco linhas `[premissa] nome_nu … handle=0000000000000000 erro=126`
([`passo2a_build.log:105-110`](evidence/oraculo-nativo-22/passo2a_build.log)) são as quatro DLLs do
export-set mais o `libomp.dll` que elas pedem; o veredito impresso é
`[premissa] veredito=FALSA o diretorio do processo nao ve o runtime por nome nu` e a saída é
`[corrida] nu_codigo=5`. O `[exe] diretorio_do_processo=C:\Aetherfall\native\af_mind\bin` da linha **66** é
a frase do §5.1 lida do processo, não da minha prosa — o exe mora em `bin\`, o runtime em
`.tools\llama\runtime\`. A corrida `preload <runtime>` abre os mesmos nomes **por caminho absoluto** (cinco
`[branco] LoadLibraryExA(…)=… erro=0`, linhas 160-164) e os números da Fase 0 §1.2 saem na mesma ordem e
fecham iguais: `load_all_from_path=0`, `reg_count=3` (RPC, Vulkan, CPU), `dev_count=2` com
`dev[0] type=1 nome=Vulkan0 desc=AMD Radeon RX 9060 XT`, `vk_get_device_count=1` e
`confronto_s1.2 … veredito=IGUAL` com `preload_codigo=0`. Duas consequências, ambas escritas antes da (b):
o `build.bat` aceita exit **0 ou 5** na corrida `nu` — 0 é a premissa verdadeira, 5 é a falsa **com recusa**;
código de crash do loader não é nenhum dos dois e derruba o build — e **a extensão não pode depender do
diretório do processo**: em `Rodar.bat` o processo é o `Godot.exe`, então o Passo 2 (b) pré-carrega o
runtime por caminho absoluto ou co-localiza as DLLs com a engine. A segunda é a que decide como os três
números de §5.2 serão alcançados.

**O controle negativo é falsificável, e tem contraprova.** [`symbol_gate_absent.cpp`](../native/af_mind/src/symbol_gate_absent.cpp)
(43 linhas) declara como dado os quatro nomes que a documentação do prompt usava e não existem no export-set
pinado (`ggml_backend_buffer_type_get_base_buffer`, `llama_model_n_ctx`,
`llama_new_context_with_model`, `ggml_backend_buffer_type_get_alloc_size`) e os usa num `main` real, para
que **só** o linker possa recusá-los: `[controle] cl_codigo=0`, `[controle] link_codigo=1120`, as quatro
`recusa_lida=0` e `OK: o gate e falsificavel` (linhas 182-188). O código é lido **e** o nome é conferido no
texto da recusa ([`passo2a_gate_absent_link.txt`](evidence/oraculo-nativo-22/passo2a_gate_absent_link.txt),
9 linhas) — um LNK1561 ou LNK1181 daria não-zero pelo motivo errado e o controle pareceria ter funcionado.
As quatro `LNK4199 /DELAYLOAD:… ignored; no imports found` do topo daquele arquivo não são aviso perdido:
são a contraprova de que o controle não resolve nada de módulo nenhum. O `af_symbol_gate_absent.exe` não
existe no disco.

**O ordinal deixou de ser comentário e virou A/B medido.** A alegação — um `.def` com `nome @37` faz o
`lib /def:` produzir import **por ordinal**, e aí o `dumpbin /imports` imprime `Ordinal 167` sem nome,
apagando a régua de posse — vivia escrita no cabeçalho do gerador.
[`passo2a_ordinal_ab.bat`](evidence/oraculo-nativo-22/passo2a_ordinal_ab.bat) (136 linhas) a mede com
**uma** variável: o MESMO `bin\symbol_gate.obj`, os MESMOS quatro módulos, nomes e linha de `/DELAYLOAD`, a
MESMA régua chamada duas vezes. [`passo2a_ordinal_ab.log`](evidence/oraculo-nativo-22/passo2a_ordinal_ab.log)
(47 linhas) devolve `linhas_com_palavra_ordinal A=37 B=0`, `regua_A_codigo=1`, `regua_B_codigo=0` e
`OK: com \`@n\` a regua recusa (codigo 1); sem \`@n\` ela passa (codigo 0)`; as quatro `[recusa]` de
[`:29-32`](evidence/oraculo-nativo-22/passo2a_ordinal_ab.log) dizem o motivo por módulo inteiro — "a tabela
nao mostrou NENHUM nome deste modulo; provavel import por ordinal". O `--ordinal` do gerador existe **só**
para essa corrida e o `build.bat` nunca o passa, e é por isso que a linha `[def]` do build traz
`remedio=sim` enquanto o A/B, que roda sem `--runtime`, traz `remedio=nao`
([`:3-7`](evidence/oraculo-nativo-22/passo2a_ordinal_ab.log)). Uma assimetria de instrumento fica
registrada, não alisada: as mesmas cinco linhas `[def]`, com um campo diferente porque uma ponta re-mede e a
outra não.

**O Passo 1 continua verde, re-medido nesta árvore depois de o código do gate ter mudado.** O critério do
§5.2 inclui "o passo 1 continua verde", e número publicado é número medido na revisão (mandato 3, item 6):
suíte **255 checagens / 0 falhas / 49,3 s** ([`passo2a_suite.log:357`](evidence/oraculo-nativo-22/passo2a_suite.log)),
runner de reações **288 / 0 / 34,032 s** ([`passo2a_runner.log:546`](evidence/oraculo-nativo-22/passo2a_runner.log))
com as cinco `OK extensao_carrega_classe` nas linhas **535-539** — descritor no disco, `is_library_open=true`,
`class_exists(AfMindOracle)=true`, `instantiate_valido=true get_class=AfMindOracle` — os dois censo
(`66/66` em 541, `288/288` em 543), o cenário estreito com **10 568** passos
(`sim_step total=2 226 037 µs`, pico `4 341 µs`) e a matilha com **1 341** passos
(`sim_tick total=3 208 778 µs`, pico `16 569 µs`), ambos `trips=0`; RNG **27 / 0 / 2,698 s**
([`passo2a_rng.log:78`](evidence/oraculo-nativo-22/passo2a_rng.log)) e journal **128 / 0 / 7 de 7 / 5,823 s**
([`passo2a_journal.log:143`](evidence/oraculo-nativo-22/passo2a_journal.log)). Exit 0 nos quatro. O stderr da
suíte é **249 bytes** — o par de vazamento do quit (`4 ObjectDB instances were leaked at exit` /
`2 resources still in use at exit`), intermitente por medição e alheio à extensão; o do runner é **0 bytes**.

**Três `warning C4996` consertados na causa, não silenciados.** A primeira corrida do gate imprimiu
`strncpy`, `_snprintf` e `strcpy` marcados como inseguros. A casa não usa
`_CRT_SECURE_NO_WARNINGS` — a flag é um silenciar, e warning dentro de log verde é o instrumento pedindo
para não ser lido. As três chamadas viraram `strcpy_s` e `snprintf` no
[`symbol_gate.cpp:166-168`](../native/af_mind/src/symbol_gate.cpp#L166-L168) e
[`:185`](../native/af_mind/src/symbol_gate.cpp#L185), com o mesmo comportamento e o mesmo
`gate_exe_bytes=157696`; as quatro corridas acima e o A/B foram re-rodidos **depois** da mudança, e o log
arquivado tem **0** warnings.

### Furo #40 — a régua de imports lia `dumpbin` como se fosse CSV, e os 37 nomes sumiram da tabela

Descoberto e **fechado** nesta perna. A primeira execução do `check_imports.py` devolveu
`na_tabela=0` nos **quatro** módulos — com o binário linkando e os 37 slots presentes — e o `build.bat`
saiu com o código de recusa **7**. O defeito era da régua: o `NAME_RE` exigia **um** espaço entre o RVA, o
hint e o nome, e o `dumpbin` **preenche a largura da coluna**. As duas formas medidas no binário são
`                          E6 CreateFileW` (import comum) e
`                                    0000000140001B7F    8C llama_print_system_info` (delay-load). Corrigido
o [`check_imports.py:59`](../native/af_mind/check_imports.py#L59) para `\s+` entre os tokens, os 37 apareceram.
O discriminador entre nome e rótulo de tabela continua sendo a **forma** — o token colado antes do nome é hex
de no máximo quatro dígitos, então `00000001 Characteristics` (8) e `0000000140025D68 Address of HMODULE` (16)
não passam — e não uma lista de rótulos em inglês, que é o erro já pago duas vezes nesta casa em Windows
pt-BR. A régua que fica: **formatar saída de ferramenta é hipótese sobre o layout, e a hipótese se confere
com o texto cru no disco antes de qualquer contagem** — aqui,
[`passo2a_gate_imports.txt`](evidence/oraculo-nativo-22/passo2a_gate_imports.txt).

### Furo #35 reincidente — agora foi o `find`, e o `cmd` do Git Bash comeu a contra-barra

Dois casos novos na mesma classe, ambos de instrumento e ambos arquivados. **(1)** A primeira versão do A/B
contava linhas com `find /c /v ""` e, dentro da casca do `vcvars64.bat`, o `find.exe` que resolve é o **GNU
find** do Git — o MSVC não tem `find`, e o vcvars **prepõe** as pastas dele sem tirar `usr\bin` do PATH. O
resultado não é um erro: é uma varredura do `C:` inteiro (`find: '/c/Config.Msi': Permission denied`, dez
minutos sem fim). A contagem passou a ser python e o motivo está escrito no próprio `.bat`
([`passo2a_ordinal_ab.bat`](evidence/oraculo-nativo-22/passo2a_ordinal_ab.bat), bloco antes das corridas A e
B). **(2)** A invocação `cmd //c native\\af_mind\\build.bat` a partir do Git Bash **não** é a mesma
invocação de dentro do `cmd`: com `MSYS_NO_PATHCONV=1` o `//c` virou caminho e o `cmd` abriu interativo
(log de quatro linhas com um `BUILD_RC=0` falso); sem aspas, `native\af_mind\build.bat` foi reescrito para
`nativeaf_mindbuild.bat`. A forma que funciona é `cmd //c 'C:\Aetherfall\native\af_mind\build.bat'` —
caminho absoluto entre aspas simples. Os dois logs afetados eram de `/tmp` e nenhum deles foi commitado; a
build log arquivada é a da forma correta, com `BUILD_RC=0` e as 190 linhas. É a mesma lição do #32 e do #35
em outra camada: **o nome que você digita não é o programa que executa**, e agora vale também para o shell
que interpreta o nome.

### Furo #36 reincidente — o `.bat` novo saiu LF do editor, e quem pegou foi o aviso do `git add`

O A/B do ordinal foi escrito com final de linha **LF**: `wc -l` **136** e `tr -cd '\r' | wc -c` **0**. A
pasta de evidência é `-text` ([`.gitattributes:9`](../.gitattributes#L9)) para que o log saia do clone byte
a byte, mas a regra de [`:22`](../.gitattributes#L22) — `*.bat text eol=crlf` — **vence** sobre ela, e
`git check-attr text eol` no arquivo devolve `text: set` / `eol: crlf`. Como o manifesto se computa
`sha256sum -b` sobre os bytes **do disco** (§12.4 da página 22), o hash daquele `.bat` seria o da forma que
nenhum clone produz — exatamente a shape dos **3 FAILED em 31** que o #36 registrou. Quem avisou foi o
próprio `git add`: *"in the working copy of 'docs/evidence/oraculo-nativo-22/passo2a_ordinal_ab.bat', LF
will be replaced by CRLF the next time Git touches it"* — a única linha desta casa que imprime a
dissociação antes do commit. O arquivo foi reescrito em CRLF (**136** CR) e a A/B **re-executada a partir
da forma arquivada**: [`passo2a_ordinal_ab_rerun.log`](evidence/oraculo-nativo-22/passo2a_ordinal_ab_rerun.log)
tem **47 linhas / 47 CR**, exit 0, e o `diff` contra o log original — com os CRs tirados dos dois — devolve
**vazio**, o que também responde uma pergunta que o #36 não respondia: `cmd.exe` leu as duas formas e o
veredito do ordinal não dependeu do final de linha. O que fica aberto é o alcance do instrumento: nenhuma
das três réguas vê forma de bytes — ponteiro, rótulo e identificador são texto — então quem pega isso é o
`sha256sum -c` dentro do clone limpo (mandato 3, item 6), e o manifesto re-gerado com as
**109** entradas é o que paga.

### O que esta passada não fecha

- **Os três números de §5.2 não existem.** `af_vram_gb`, `af_load_ms` e `af_ctx_cells` são o **Passo 2 (b)**,
  e ela já nasce com a rota decidida pelo §15.5 acima: pre-load por caminho absoluto ou DLLs
  co-localizadas. Nenhuma medida de VRAM foi feita aqui.
- **A extensão não encosta no runtime.** O fruto deste lote é o exe do gate, o `.def` e os import libs; o
  `af_mind.dll` continua os mesmos **105 472 B** e o mesmo offset `00001120` do Passo 1 (c).
- **`src/` intocado**: `git diff --name-only main...HEAD -- src` devolve **vazio**, então
  `Channel.COUNT`, `FORMAT_VERSION` e `GEN_VERSION` seguem parados e os hashes de journal das rodadas
  publicadas valem para a árvore resultante sem re-corrida.
- **Nenhum gate de fase** (mandato 4), e **#38, #39 e #20** continuam onde estavam — o primeiro é decisão do
  dono, o segundo é o limite das réguas, o terceiro é a colheita que nomeia a folha.

A página 22 cresceu **252 linhas** (1 252 → **1 504**) com o §15 inteiro e a re-derivação de três frases que
este passo tornou velhas — o manifesto da evidência (92 → **109** entradas, conta re-rodada na árvore do
commit com `sha256sum -c` **109/109 OK** e `tr -cd '\r' | wc -c` **0**), a afirmação de "nenhum `.lib` no
clone" do §12.3 (o `.gitignore:8:bin/` foi conferido arquivo por arquivo; a árvore construída tem **9**
`.lib`: os quatro import libs, `af_mind.lib` e os quatro do `bin\ab-ordinal`) e a premissa do §5.1, que agora
aponta para o §15.5. A linha `__pycache__/` no `.gitignore` (**:13**) existe porque a árvore de fato ganhou
um `native/af_mind/__pycache__/gen_import_libs.cpython-310.pyc`: o `build.bat` chama os dois instrumentos
como **script** (`python …\gen_import_libs.py`), o que não grava `.pyc` de `__main__`, então o arquivo vem de
um import feito por sonda durante a construção da régua — e sem a linha, todo clone mostraria um `??` depois
de mexer nos instrumentos. As três réguas, rodadas com esta rodada escrita e arquivadas em
[passo2a_ruler_doc_anchors.log](evidence/oraculo-nativo-22/passo2a_ruler_doc_anchors.log),
[passo2a_ruler_plan_cites.log](evidence/oraculo-nativo-22/passo2a_ruler_plan_cites.log) e
[passo2a_ruler_plan_ids.log](evidence/oraculo-nativo-22/passo2a_ruler_plan_ids.log):
`python tools/check_doc_anchors.py` deu **39 arquivos · 3 062 ponteiros · 209 rótulos · 3 307 links
relativos · 0 casos objetivos** (exit 0);
`python .tools/verify_plan_cites.py AGENTS.md README.md docs/melhorias-status.md docs/planos/README.md
docs/planos/22-oraculo-nativo-gdextension.md` deu **1 024** citações com número conferidas, **10**
arquivos citados inexistentes — os dez de sempre, os três scratch `.tools/_head_*.md` e as peças
`[TARGET]` que as páginas declaram não existirem — e **0** números fora do arquivo (exit 0);
`python .tools/verify_plan_ids.py` no corpus da perna saiu **exit 0** com as ausências de sempre, e aqui
elas têm uma classe a mais desde o Passo 1 (c): os nomes de `native/` que a régua não varre, porque ela
monta o corpus com `src/**/*.gd` e `tests/**/*.gd` (furo **#39**). A fila
serializada não muda: **22 → 17 → 18 → 20 → 13**, e a 22 segue na frente.

*(Estado re-derivado pelo pouso abaixo: as quatro corridas e as três réguas deste bloco valem para a
ponta `007a32b`; a `main` mergida é `8a53b56` e foi re-medida, com o `build.bat` re-executado dentro do
clone limpo. O **Passo 2 (b)** continua por rodar, e a rodada (6) logo abaixo abre os **furos #41 e #42**
— nenhum deles é da perna.)*

## O pouso do Passo 2 (a) na `main` — o `src` e o `tests` provados por hash de árvore, as quatro corridas da mergida e o `build.bat` re-executado dentro do clone limpo (2026-11-24, `docs/registro-pouso-passo2a-22`, base `fa5ea79`, ponta `007a32b`, merge `8a53b56`)

### O que o merge toca, com o número em cada régua

`git merge --no-ff feat/oraculo-nativo-passo2-22` devolve **`8a53b56`** sobre **`fa5ea79`** (pais da
ponta: `007a32b`), **26 arquivos, +3 408/−2**, em `native/af_mind/` (quatro arquivos: `build.bat`,
`gen_import_libs.py`, `check_imports.py`, dois `.cpp` do gate), `docs/evidence/oraculo-nativo-22/`
(17 artefatos + o manifesto re-gerado), `docs/melhorias-status.md`, a página 22 e três linhas de
`.gitignore`. A régua que a perna escreveu como `git diff --name-only main...HEAD -- src` vazio sai mais
forte que o diff, e desta vez cobre duas raízes:

| Árvore | `fa5ea79` | `007a32b` | `8a53b56` |
| --- | --- | --- | --- |
| `src` | `f77c1961bb8065ea5a78b24677a36c5840891c75` | idem | **idem** |
| `tests` | `0faee7ff5b26d6ef978c9aa20b91dab3254d4491` | idem | **idem** |
| `native` | `babfad2a6de4fb0c8de8c27af4aa74e92c3e2b88` | `bec0fc7ac4089c40da10c2e25bddaa538b270fc8` | **`bec0fc7a…`** |

É a primeira perna desta casa em que o `tests` também não se move: o Passo 2 (a) escreve instrumento de
`native/`, não checagem de `src/`. Disso segue, sem re-corrida e sem adjetivo, que `Channel.COUNT`,
`FORMAT_VERSION`, `GEN_VERSION` e a projeção do journal continuam intocados **e** que os hashes de journal
publicados nas rodadas anteriores valem para a árvore resultante. As quatro corridas abaixo são re-medição
de contrato, não herança — número publicado é número medido na revisão.

Publicação conferida com `git ls-remote --heads origin`: `refs/heads/main` =
**`8a53b56bd7d905758173f2ce597361dbb8023d2d`**, `refs/heads/feat/oraculo-nativo-passo2-22` =
`007a32b38e1474cb152f508ec68270a5fd8d4603`. É a única prova de que saiu; o exit 0 do `push` não prova.

### As quatro corridas da árvore mergida, com a máquina livre

Antes delas, `--import` na árvore mergida ([`main_mergida_import.log`](evidence/registro-pouso-passo2a-22/main_mergida_import.log),
18 linhas, exit 0, stderr **0 bytes**) e o `.godot/extension_list.cfg` com a única linha
`res://native/af_mind/af_mind.gdextension`. Nenhum processo `Godot*` na máquina antes da primeira
invocação; as quatro rodaram serial.

- Suíte: [`main_mergida_suite.log`](evidence/registro-pouso-passo2a-22/main_mergida_suite.log) — linha
  **359** `== 255 checagens  0 falhas  51.2 s de teste ==`, exit 0, zero `SCRIPT ERROR`;
  [`main_mergida_suite.err`](evidence/registro-pouso-passo2a-22/main_mergida_suite.err) com **249 bytes**
  = o par de vazamento do quit (`4 ObjectDB instances were leaked at exit`,
  `2 resources still in use at exit`), a intermitência já registrada, nenhuma das duas linhas menciona
  `af_mind`.
- Runner de reações: [`main_mergida_runner.log`](evidence/registro-pouso-passo2a-22/main_mergida_runner.log)
  — as cinco `OK extensao_carrega_classe` nas linhas **537-541** (descritor no disco,
  `ja_vinha_do_boot=true agora=true total_registradas=1`, `is_library_open=true`,
  `class_exists(AfMindOracle)=true`, `instantiate_valido=true get_class=AfMindOracle`), **543** `66/66`,
  **545** `288/288`, **546** cenário estreito com **10 568** passos (`sim_step total=2 423 290 µs`, pico
  `4 120 µs`, `trips=0`), **547** matilha com **1 341** passos (`sim_tick total=3 367 492 µs`, pico
  `15 010 µs`, `trips=0`) e **548** `288 checagens 0 falhas 36,531 s`. Exit 0, stderr **0 bytes**.
- RNG da sessão: [`main_mergida_rng.log`](evidence/registro-pouso-passo2a-22/main_mergida_rng.log) — **79**
  `27/27`, **80** `27 checagens 0 falhas 2,713 s`.
- Journal por tick: [`main_mergida_journal.log`](evidence/registro-pouso-passo2a-22/main_mergida_journal.log)
  — **144** `128/128`, **145** `128 checagens 0 falhas 7/7 testes concluidos 6,143 s`.

Os dois `trips=0` não fecham o **furo #20**, pelo motivo já escrito na (c): o guard mede parede de relógio
e a colheita que nomearia a folha que estoura continua por escrever.

### O pin: clone limpo de `8a53b56`, com o `build.bat` rodando dentro dele

`git clone` do repositório local, HEAD `8a53b56…`. O `git status --short` do clone devolve **exatamente
duas** linhas: `?? tests/audio_live_probe.gd.uid` e `?? tests/audio_test.gd.uid` — é o **furo #25**
impresso, na forma esperada, e é o que separa um clone sujo de um clone honesto. O `bin/` não vem
([`.gitignore:8`](../.gitignore#L8)), então o build faz parte do pin.

- `cmd //c '…\afclean22d\native\af_mind\build.bat'` no clone
  ([`clone_limpo_build.log`](evidence/registro-pouso-passo2a-22/clone_limpo_build.log), 187 linhas,
  `== codigo=0 ==` no rodapé): `header_sha256=4c0aac8d… forma=aceita`, `toolset=14.44.35207`,
  `cl_banner=… 19.44.35228 for x64`, `dll_bytes=105472`, `export= 1 00001120 af_mind_entry`. Os cinco
  `[def]` com `remedio=sim` e `entradas=` **3 / 687 / 9 / 16 / 240**, os quatro import libs
  (`llama 58 326 B`, `ggml 5 288 B`, `ggml-base 154 094 B`, `ggml-vulkan 3 926 B`), o
  `gate_exe_bytes=157696` e — o número que é o gate da (a) — `[referencia] gate AF_SLOT=37 nomes` com as
  quatro linhas `[import] modulo=… referenciado=N na_tabela=N` (**10/10, 4/4, 5/5, 18/18**, somando os 37).
  A premissa do diretório do processo sai impressa como **FALSA**: `[premissa] veredito=FALSA o diretorio
  do processo nao ve o runtime por nome nu`, cinco `handle=0000000000000000 erro=126` e
  `[corrida] nu_codigo=5` contra `[corrida] preload_codigo=0`, com o `confronto_s1.2` em `veredito=IGUAL`
  (`reg_count=3`, `dev_count=2`, `vk=1`). O controle negativo falsificável roda no clone também:
  `[controle] link_codigo=1120`, as quatro `recusa_lida=0` e `OK: o gate e falsificavel`.
- O stderr do build no clone tem **507 bytes** e nenhuma linha de erro: é o `af_symbol_gate.exe` falando
  no stdout de terceiro — `load_backend: loaded RPC/Vulkan/CPU backend from C:\Aetherfall\.tools\llama\runtime\…`
  e `ggml_vulkan: 0 = AMD Radeon RX 9060 XT (AMD proprietary driver)`. Consequência de onboarding que vale
  escrever: o **runtime não está no clone** (`.gitignore:17 models/` e `.tools/` na linha 5), então o
  `preload` do gate aponta para a árvore de trabalho de quem rodou o pin. Um clone em outra máquina chega
  ao `[ok] build.bat` e não chega ao `preload_codigo=0`.
- `--import` frio ([`clone_limpo_import.log`](evidence/registro-pouso-passo2a-22/clone_limpo_import.log),
  exit 0) escreve o mesmo `extension_list.cfg` com o descritor. O `.err` desta corrida tem **602 bytes**
  — quatro `ERROR: GDExtension dynamic library not found: 'res://native/af_mind/af_mind.gdextension'`,
  duas passadas do escaneamento. É o **furo #38** se repetindo no clone, antes do build existir: na (c) o
  import do clone saiu com stderr 0 porque a pasta `bin/` já tinha sido preenchida na ordem errada da
  medição. A ordem honesta é import → build → re-import, e é por isso que o runner do clone passa.
- Runner: [`clone_limpo_runner.log`](evidence/registro-pouso-passo2a-22/clone_limpo_runner.log) — as cinco
  `OK extensao_carrega_classe` nas **mesmas** linhas **537-541**, `66/66` em 543, `288/288` em 545,
  **546** `sim_step total=2 256 913 µs` pico `4 855 µs`, **547** `sim_tick total=3 219 023 µs` pico
  `13 420 µs`, ambos `trips=0`, e **548** `288 checagens 0 falhas 34,330 s`; exit 0, stderr 0 bytes.
- Suíte: [`clone_limpo_suite.log`](evidence/registro-pouso-passo2a-22/clone_limpo_suite.log) linha **359**
  `== 255 checagens  0 falhas  49.8 s de teste ==`, exit 0, zero `SCRIPT ERROR`, `.err` com os mesmos
  **249 bytes** do par de vazamento.
- RNG **27 / 0 / 2,750 s** e journal **128 / 0 / 7 de 7 / 5,829 s**, exit 0 e stderr 0 bytes nas duas.

O `af_mind.dll` do clone tem **105 472 B** e md5 `25df3f33b301705ea6a603d3b46062ee`; o da árvore de
trabalho, **105 472 B** e md5 `e60bb78e6f7cd12d9f3bf5d445c5e63e`. Os dois têm o mesmo tamanho e o mesmo
offset `00001120` do Passo 1 (c), e os md5 **não** batem — o PE embute caminho e timestamp do link. A
régua que compara é tamanho + offset + export nomeado, não hash: é o que a casa pode afirmar entre clones.

O número pineado para `8a53b56` é, na ordem das quatro corridas: suíte **255 / 0**, runner **288 / 0** com
as cinco premissas da extensão, RNG **27 / 0**, journal **128 / 0**.

### As três réguas no ponto fixo desta passada

Elas rodam **depois** da prosa existir, não antes — item 7 do ciclo de trabalho. As três primeiras
capturas desta branch foram descartadas: duas saíram sem corpus (a ferramenta recebe os arquivos em
`sys.argv[1:]`; sem argumento ela varre um conjunto que não é o da perna) e uma sem as duas linhas de
cabeçalho que todo log daqui carrega. O que está arquivado é a re-execução.

- [`pouso_ruler_doc_anchors.log`](evidence/registro-pouso-passo2a-22/pouso_ruler_doc_anchors.log):
  **39 arquivos · 3 077 ponteiros conferidos · 209 rótulos · 3 343 links relativos · 0 casos objetivos**,
  exit 0. Contra os **3 062 / 3 307** que a ponta `007a32b` media
  ([`passo2a_ruler_doc_anchors.log`](evidence/oraculo-nativo-22/passo2a_ruler_doc_anchors.log)), o acréscimo
  de **15** ponteiros e **36** links é desta passada — a página do pouso, a Rodada (6) e a linha da Malha
  no AGENTS.md — e não abriu caso nenhum. Um caso **abriu** no primeiro re-run e foi corrigido antes deste:
  um ponteiro meu escreveu `src/main.gd` onde o arquivo-pedido é `../src/main.gd` (a régua resolve
  relativo ao `docs/`), e a régua devolveu `LINK QUEBRADO` com exit 1. O único caso tolerado continua
  sendo o ponteiro `../.tools/...`, gitignored.
- [`pouso_ruler_plan_cites.log`](evidence/registro-pouso-passo2a-22/pouso_ruler_plan_cites.log):
  **1 039** citações com número de linha conferidas, **10** arquivos citados que não existem, **0** números
  fora do arquivo, exit 0. Os dez são os de sempre — os três rascunhos `.tools/_head_*.md` e as peças
  `[TARGET]` que as próprias páginas declaram inexistentes (`src/ai/reach.gd`,
  `src/core/sim/entity_store.gd`, `src/core/sim/tick_clock.gd`, `tests/wolf_multiseed_census_test.gd`) — e
  nenhum deles é afirmação de que o arquivo está lá. A régua passou de **1 024** para **1 039** com a
  prosa desta escrita: ponteiro acrescentado, nenhum número fora do arquivo.
- [`pouso_ruler_plan_ids.log`](evidence/registro-pouso-passo2a-22/pouso_ruler_plan_ids.log): exit 0 com as
  ausências de sempre, e nelas continua **uma** classe a mais desde o Passo 1 (c): os nomes de `native/`,
  porque a régua monta o corpus com `src/**/*.gd` e `tests/**/*.gd` e nunca abriu um `.cpp` — é o
  **furo #39**, e é por ele que
  `GDExtensionClassCreationInfo6`, `llama_model_load_from_file` e os outros símbolos da Fase 1 aparecem
  aqui sem serem defeito. E há uma leitura que esta régua **não** faz: o corpus de ids é de três arquivos —
  este documento fica fora dele — então nenhuma linha da Rodada (6) foi conferida por ela; conferiu-a a de
  ponteiros, acima. O que se confere aqui é `MESH_BUDGET` existir em código ([main.gd:28](../src/main.gd#L28));
  o furo **#41** é justamente o que não existe: um teto de **contagem** sem teto de **tempo**. Nada nesta
  linha autoriza o código do #41.

As duas pastas de evidência desta passada fecham com manifesto: [`artifacts.sha256`](evidence/registro-pouso-passo2a-22/artifacts.sha256)
com **25** entradas e [`artifacts.sha256`](evidence/microtravadas-20261124/artifacts.sha256) com **12**,
ambos gerados com `sha256sum -b` (o `-b` importa: sem ele o `git add` avisa de CR, e o `.gitattributes:9`
marca `docs/evidence/**` como `-text` justamente para o log sair byte a byte). `sha256sum -c artifacts.sha256`
rodado dentro de cada pasta devolve **25 OK** e **12 OK**, nenhuma falha, e o manifesto tem **0** bytes de
CR — conferido com `tr -cd '\r' | wc -c`, não com `head`.

### O que o pouso deixa aberto

Nenhum gate de fase (mandato 4). Dentro da perna faltam o **Passo 2 (b)** (os três números de §5.2 —
`af_vram_gb`, `af_load_ms`, `af_ctx_cells` — lidos do modelo, não do `--ctx-size`), o **Passo 3**
(testemunha da regra de ouro) e o **Passo 4** (`transporte_http_zerado`). Dos furos, **#38** e **#39**
continuam abertos e são decisão do dono, e o **#20** continua sem a colheita que nomeia a folha. A fila
serializada não muda: **22 → 17 → 18 → 20 → 13**.

O dono, lida a (a), pediu duas coisas que não eram código da perna: achar o porquê das microtravadas e
analisar se o oráculo está fazendo o que ele quer. As duas foram medidas na árvore deste pouso, e estão na
rodada abaixo.

## Rodada 2026-11-24 (6) — as microtravadas atribuídas no jogo em execução, e o oráculo lido pela frase que ele escreve (árvore `8a53b56`, dez corridas, máquina livre)

O pedido do dono foi em duas partes: *"ficou dando umas microtravadas, tem que ver o pq disso"* e
*"analisar realmente o llm se ta do jeito que estamso querendo"*. As duas saíram com número, na mesma
árvore do pouso acima, serial, com a máquina livre (nenhum processo `Godot*` antes da primeira
invocação). **Nenhuma linha de `src/` foi escrita nesta rodada** — o instrumento é a sonda gitignored
`.tools/hitch_probe.gd`, e os dez logs arquivados têm vínculo de revisão em
[`leitura.log`](evidence/microtravadas-20261124/leitura.log): `HEAD` = `8a53b56`, `src` =
`f77c1961…`, `tests` = `0faee7ff…`, `git diff --name-only HEAD -- src tests` = **0 arquivos**, e o `.gd`
mais novo da árvore tem mtime **2026-11-24 03:53** contra a primeira corrida às **09:12**.

### 1. Por que sonda em janela e não headless

A suíte é headless: não existe `RenderingServer`, então ela **não pode ver** um custo de desenho. A
primeira calibração foi a do instrumento, não a do jogo — braço `floor`, a sonda sozinha (`main=false`),
20 s, **3 282** amostras, **p50 = 6,06 ms**, p99 = 6,29, **max = 6,73**, `>=2×p50 = 0 (0,00 %)`,
`>=33,3 ms = 0`, 165,0 Hz. Dois números seguem daí e mudam a régua da casa:

- **O piso do quadro nesta máquina é 6,0 ms, não 16,7.** O motor está em janela 1 280 × 720 com vsync do
  próprio motor e a tela do dono bate ~165 Hz. Um corte absoluto em 33,3 ms é **cinco** quadros perdidos;
  o corte relevante é **múltiplo do p50 medido**. As pontas de jogo deram p50 entre **6,01 e 6,04**.
- **O instrumento não trava nada.** `floor` com zero travadas é o que autoriza chamar de travada o que
  aparece nos outros braços.

### 2. A matriz: oito braços, uma variável por processo

Cada braço liga/desliga **uma** coisa pela API pública, sem tocar arquivo de gameplay: `idle` é o jogo
parado; `walk` anda com `Input.action_press` (input de engine, não sintético de SO); `mine` segura a
lavra; `viz` liga a visualização do Éter; `f3` liga o overlay; `llm` deixa o hospedeiro do modelo vivo;
`all` é tudo junto. Como o boot acontece uma vez por processo, são **oito processos**.

| braço | p50 | ≥2×p50 | ≥3×p50 | ≥33,3 ms | ≥100 ms | chunks remalhados | quadros com malha | malha total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| floor | 6,06 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| idle | 6,03 | 146 (2,33 %) | 19 | 19 (0,30 %) | 6 | 25 | 19 | 1 949,5 ms |
| walk | 6,04 | 140 (2,16 %) | 8 | 8 (0,12 %) | 1 | 9 | 8 | 619,2 ms |
| mine | 6,03 | 149 (2,42 %) | 30 | 30 (0,49 %) | 15 | 50 | 30 | 2 629,4 ms |
| viz | 6,03 | 138 (2,13 %) | 8 | 8 (0,12 %) | 1 | 9 | 8 | 605,0 ms |
| f3 | 6,03 | 139 (2,15 %) | 8 | 8 (0,12 %) | 1 | 9 | 8 | 610,7 ms |
| llm | 6,01 | 139 (2,15 %) | 10 | 10 (0,15 %) | 1 | 11 | 10 | 751,1 ms |
| all | 6,02 | 151 (2,42 %) | 26 | 25 (0,40 %) | 12 | 41 | 25 | 2 258,1 ms |
| all (re-corrida) | 6,02 | 155 (2,51 %) | 30 | 29 (0,47 %) | 15 | 48 | 29 | 2 586,6 ms |

O cruzamento é a linha que decide, e é a mesma forma em nove braços — o par `{com_remalha, sem_origem}`
não muda de leitura entre configuracoes, e a re-corrida com stderr separado reproduz o veredito
([`hitch_all_rerun.log`](evidence/microtravadas-20261124/hitch_all_rerun.log), `.err` de **0 bytes**):

```
idle  travadas=146 | com_remalha=19 com_compilacao=0 com_tick=127 sem_origem=0 | remalharam_sem_travar=0
mine  travadas=149 | com_remalha=30 com_compilacao=0 com_tick=119 sem_origem=0 | remalharam_sem_travar=0
llm   travadas=139 | com_remalha=10 com_compilacao=0 com_tick=129 sem_origem=0 | remalharam_sem_travar=0
all   travadas=151 | com_remalha=25 com_compilacao=0 com_tick=126 sem_origem=0 | remalharam_sem_travar=0
```

`com_remalha + com_tick = travadas` em todos os braços, `sem_origem = 0` em todos, e
`remalharam_sem_travar = 0` em todos: **não existe quadro que remalhe sem travar e não existe travada sem
origem nomeada**. A tabela `PIORES_SEM_MESH` — os piores quadros que **não** tinham malha naquele frame —
sai com **0 linhas de corpo** nos dez logs.

### 3. Causa 1: `VoxelWorld.process()` remalha até `MESH_BUDGET` chunks **no mesmo frame**

[`voxel_world.gd:251-260`](../src/world/voxel_world.gd#L251-L260) faz
`var count := mini(p_frame_budget, _dirty.size())` e **roda `build_chunk_mesh(c)` `count` vezes seguidas**,
sem olhar o relógio entre um chunk e o próximo. [`main.gd:28`](../src/main.gd#L28) dá `MESH_BUDGET := 2` e
[`main.gd:388`](../src/main.gd#L388) chama `world.process(MESH_BUDGET)` dentro de `_process`. O orçamento é
**de contagem, não de tempo**. Os quadros piores medidos:

| braço | idx | período do quadro | malha no quadro | chunks no quadro | `req` do oráculo |
| --- | --- | --- | --- | --- | --- |
| idle | #4607 | **192,20 ms** | 177,37 ms | 2 | 0 |
| mine | #1182 | 152,85 ms | 144,85 ms | 2 | 0 |
| llm | #582 | 158,24 ms | 151,32 ms | 2 | 0 |
| all | #502 | 153,55 ms | 147,63 ms | 2 | 0 |
| all (re) | #5099 | 170,58 ms | 156,19 ms | 2 | 0 |

`QUADRO_US max process=178 654 / mesh=177 368` no idle: a malha é **99 %** do quadro. Por chunk, a conta
sai **52,6–78 ms** (`mesh_total_ms / chunks_remalhados`: 1 949,5/25 = 78,0 no idle; 2 629,4/50 = 52,6 no
mine; 2 586,6/48 = 53,9 na re-corrida) — e isso bate, por caminhos independentes, o número publicado do
boot no clone limpo (**4 668 ms / 64 chunks ≈ 73 ms/chunk**). Dois braços mostram o **frame seguinte**
daquele par (`#1251 93,75 ms built=1`, `#583 92,56 ms built=1`): a fila suja é consumida em lotes de dois,
e o segundo chunk do lote ainda custa 70–80 ms sozinho.

O que torna isso "microtravada" e não "travão": a malha só roda quando há `world.edits` ou chunk novo.
`mine` é o braço que mais remalha (**50** chunks em 40 s, 3,6× o `idle`) porque cada bloco quebrado suja a
malha vizinha — e é o braço com mais `≥100 ms` (**15**). O `PREMISSA_MINE` do braço prova que a lavra
aconteceu de verdade, não que o botão foi apertado no vazio: `quadros_alvo_valido=3835 de 6169`,
`quadros_botao_press=4115`, `progresso_max=0.96`, `pitch=-0.60`, `terceira_pessoa=false`,
`edits_finais=29`.

### 4. Causa 2: a banda "micro" é o passo de 20 Hz caindo num quadro de 6 ms

`com_tick` é **119–131** de ~146 travadas em cada braço, e é a única origem dos `≥2×p50` que não são
malha: um passo de simulação de **9,2–11,4 ms** (coluna `step` dos piores quadros; `physics` 7,9–12,8 ms)
dentro de um quadro cujo piso é **6,0 ms** estoura o período para 12,1–18 ms. É a faixa 2–3×p50 da
distribuição — `HIST_P50 2-3x=119…132` contra `>15x=2…21`. `dropped_ticks = 0` em **todos** os braços: o
`SimClock` está absorvendo, e o que o olho pega é o ritmo de desenho ficando irregular, não a simulação
atrasando. A coluna `ticks` diz `~0,1/quadro` (802–885 ticks em ~6 200 quadros), que é o esperado de
20 Hz sobre 165 Hz.

Isso não é defeito novo nem conserto pedido: é a consequência de o quadro correr a ~165 Hz enquanto a
simulação foi calibrada para 60 Hz. Onde ela dói está no **furo #41**, não aqui.

### 5. O que a medição exime, com o número

- **O oráculo e o hospedeiro do modelo.** `llm` é estatisticamente igual a `viz`/`f3`: 139 vs 138/139
  travadas, 10 vs 8/8 quadros com malha, **p50 6,01** (o menor da mesa). Os quatro braços sem `llm`
  imprimem `pedidos=0 narracoes=0 estado_final=ocioso`; `llm` e `all` imprimem `pedidos=12 narracoes=12
  estado_final=pronto` — e `req=0` em **todas** as linhas de pior quadro. `HTTPClient` num
  `HTTPRequest` não bloqueia o quadro; o custo do modelo é no processo filho.
- **A visualização do Éter a 4 Hz** (`viz`: 138 travadas, 8 com malha — os mesmos 9 chunks do `idle`,
  porque a cena é a mesma) e **o overlay F3** (`f3`: 139/8, `mesh_total_ms` 610,7 contra 605,0 do `viz` —
  bit a bit o mesmo trabalho).
- **Compilação de pipelines.** `com_compilacao = 0` nos braços com 19–22 compilações no log; o único
  caso é `walk` com **1**. Os monitores `PIPELINE_COMPILATIONS_*` foram lidos como delta por quadro, e a
  coluna `pipe` dos piores quadros é **0** em todas as linhas.
- **O instrumento.** `floor`: 3 282 amostras, 0 travadas.
- **O próprio engine, no agregado:** os 10 braços têm `pend_final=0` (a fila de malha esvazia) e
  `dropped=0`.

Fica declarado no `FORA` de cada log: a sonda **não** separa o custo do compositor do Windows nem de outro
app, roda em janela 1 280 × 720 com o vsync do motor — a tela cheia do dono tem outro custo de draw — e
nada aqui mede alocação. É o limite do instrumento, não uma ressalva de cortesia.

### Furo #41 — o orçamento de malha é contagem, não tempo: 2 chunks = 52–177 ms no mesmo quadro

Aberto e **atribuído** por esta rodada, **sem conserto escrito** porque a perna da vez é a 22 e o
mandato de escopo não autoriza tocar `src/` agora. A afirmação que a casa vinha tratando como segura —
"Malha: 2 chunks por frame", a linha da tabela de orçamentos do AGENTS.md — é verdadeira no código
([`main.gd:28`](../src/main.gd#L28)) e **falsa como orçamento**: o teto é de **itens**, o loop de
[`voxel_world.gd:256-259`](../src/world/voxel_world.gd#L256-L259) não consulta `Time.get_ticks_usec()`
entre um chunk e o próximo, então o que entra no quadro é `2 × chunk_us`, e `chunk_us` é medido entre
**52,6 e 78 ms**. Contra um piso de quadro de **6,0 ms** isso é **8,8× a 13×** o budget de frame, e é a
origem dos 19–30 quadros ≥33,3 ms por 40 s dos braços parados e dos 29–30 do `mine`. O corte tem forma
conhecida e é pequeno: orçar **tempo** no `process()` — o loop para quando a soma das malhas passou de
um teto (o `_last_mesh_ms` que a própria função já calcula em
[`voxel_world.gd:260`](../src/world/voxel_world.gd#L260) é a grandeza), e a fila continua no próximo
frame. Dono proposto: perna `perf/malha-orcamento-de-tempo`, atrás da fila viva. O que **não** se resolve
assim: o chunk isolado continua custando ~50–80 ms, então um quadro ainda vai estourar — a banda
"micro" do §4 é outra conversa, de cadência de tela, e ela não tem `dropped_ticks`.

A régua que fecha o furo já existe na forma: o runner de reações colhe `sim_step` e `trips`, e a sonda
desta rodada cruza `quadro` com `mesh` por índice. O que falta é uma checagem que **nasça vermelha** com
o teto de tempo escrito, no estilo das outras pernas.

### 6. O oráculo: o transporte faz exatamente o que foi pedido

Lido no braço `llm` com a testemunha do ciclo de vida inteiro
([`hitch_llm_narr.log`](evidence/microtravadas-20261124/hitch_llm_narr.log)):

```
llm_host  sondando  sonda /v1/models em http://127.0.0.1:8741
llm_host  create_process  C:/Aetherfall/.tools/llama/runtime/llama-server.exe -m … -c 4096 -ngl 99
                          --alias mind-small --reasoning off --api-key <chave>  (sem servidor na porta 8741)
llm_host  carregando  pid 9520  boot do modelo iniciado  (1/1 spawn)
llm_host  pronto  boot 2539 ms  503=10  pid 9520
llm_estado=pronto  boot_ms=2539  aguardado=9.5 s  pid=9520
…
ORACULO pedidos=12 narracoes=12 estado_final=pronto
OBSERVACAO pid_do_filho=9520 (o `_exit_tree` do hospedeiro mata)
llm_host  encerrando pid 9520  OK
```

Os cinco pontos do pedido do dono estão verdes por medição: **levanta sozinho** no boot (o `create_process`
vem sem ninguém ter aberto nada), **não pede** ao dono (`aguardado=9,5 s` antes da primeira requisição, com
os dez `503` tratados como "carregando" e não como falha — o `LOADING_COOLDOWN` de 2 s do
[`mind_oracle.gd:34`](../src/ai/mind_oracle.gd#L34)), **12 pedidos → 12 narrativas** (zero perda),
**termina o filho** (`encerrando pid 9520 OK`, nenhum processo órfão depois das corridas — as três
pontas com `llm` mostram `pid_do_filho` morto), e **a chave não sai no log** (`--api-key <chave>`
redigido na própria linha). A **regra de ouro** continua valendo por construção e foi re-conferida nesta
árvore: a única saída do oráculo é `_narrations` lida por `narration_of()` e entregue ao HUD; o único
chamador de `adjust_trust` em `src/` é `take_damage` ([`wolf.gd:1303`](../src/entities/wolf.gd#L1303)),
e `AfMindOracle` **não é usado por nada em `src/`** — aparece só no runner
([`aether_reactions_test.gd:5556`](../tests/aether_reactions_test.gd#L5556)). `hp=100 %` nas 12 narrativas
prova que nenhum caminho de dano rodou, então nenhuma escrita de estado veio do modelo.

### Furo #42 — a frase narrada não é fiel ao estado lido: seis defeitos nas 12 linhas literais

O outro lado do "está do jeito que a gente quer". Aqui o veredito é **não**, e a testemunha é o texto: a
sonda imprime, junto de cada narrativa, os mesmos campos que o prompt mandou
(`intent`, `hp`, `fome`, `confianca`, `episodios`, nº de `crencas`). As 12 linhas estão em
[`leitura.log`](evidence/microtravadas-20261124/leitura.log). Seis classes, com a linha que as mostra:

1. **`confianca=0,00` narrado como desconfiança.** `Mind.trust()` devolve `0.0` quando **não há registro**
   ([`mind.gd:154-155`](../src/ai/mind.gd#L154-L155)) e o único caminho que o torna negativo é mordida
   (`adjust_trust(-0.35)`), que não aconteceu em nenhum dos 12 quadros (`hp=100 %`). Mesmo assim: **#7**
   *"o seu zero absoluto de confiança no jogador"*, **#8** *"impede de confiar em nenhum som novo"*,
   **#10** *"a desconfiança em relação ao jogador se intensifica"*. É o **mandato 2** ao contrário na
   saída: o jogador lê hostilidade onde o estado diz "nunca se viram".
2. **Memória inventada.** **#2** *"sua mente recruta memórias de caças fer..."* e **#3** *"o eco de seus
   passos preenche a floresta"* com `episodios=[]`. **7 das 12** linhas têm `episodios=[]` — o prompt
   manda a string vazia e o modelo preenche.
3. **Grandeza que o prompt não envia.** **#1** *"o jogador ainda está longe"* e **#3** *"calculando a
   distância até o jogador"*: `_prompt_for` ([`mind_oracle.gd:145-162`](../src/ai/mind_oracle.gd#L145-L162))
   manda identidade, intenção, vida, fome, confiança, memórias e crenças — **distância não está lá**.
4. **Nomear o sistema em vez de narrar o interior**, contra a instrução explícita
   ([`:124-126`](../src/ai/mind_oracle.gd#L124-L126) "sem nomes de sistemas"): **#7** *"a sua intenção de
   patrulhar"* é o valor de `intent`; **#4** *"um padrão de varredura"* e **#2** *"uma vigilância apática"*
   são rótulos de mecanismo, não de estado.
5. **Truncamento pelo corte de 140 caracteres** (`_clean`,
   [`:262-265`](../src/ai/mind_oracle.gd#L262-L265)): **4 das 12** terminam em `...` (143 caracteres
   = 140 + corte) e uma para exatamente em 140. A frase prometida é "UMA frase curta"; o que chega ao
   HUD às vezes é meio período dela.
6. **Cadência em rajada.** Os 12 pedidos saem em duas rajadas de 6 — t=**0,9 / 1,7 / 2,4 / 3,1 / 3,6 /
   4,2 s** e t=**31,7 / 32,4 / 33,1 / 33,7 / 34,3 / 35,0 s** — porque `RETRY_COOLDOWN = 30 s` por
   identidade é alinhado: o lobo 0 responde em 0,9 s e o próximo pedido dele cai em 31,7 s
   (30,8 s depois). A matilha fala em bloco, cala em bloco. Não é defeito de rede, é desenho do recuo.

Duas linhas são **fiéis**, e elas mostram que o modelo está lendo o que chega: **#9**
(`intent=investigate`, `episodios=[scent_work/0.02]`) → *"varre o chão buscando rastros"*; **#11**
(`intent=hunt`, `episodios=[saw_player/0.40, hit_land/0.30, saw_player/0.40]`) → *"filtrando a visão do
jogador como uma ameaça iminente enquanto calcula a melhor rota para o ataque"*. E **#6**
(*"as memórias que nunca foram registradas"*) é honesta sobre o `episodios=[]`. O problema não é o modelo
recusar o estado — é o prompt deixar ambíguo o que `0,00`, `[]` e a ausência de distância **querem dizer**,
e o `max_tokens=64`/corte de 140 competir com "uma frase curta".

Dono e recorte: isto é **Fase 1 da perna 22** (o transporte) e o §9 do dossiê 15, não uma nova perna — a
correção é de prompt e de exibição (dizer "sem histórico" em vez de mandar vazio, explicitar que
confiança 0 é ausência, levar a distância no prompt se ela deve aparecer, e escolher se o teto é
`max_tokens` ou os 140 caracteres), com a checagem de fidelidade nascendo vermelha no mesmo estilo das
outras. Escrita como débito abaixo, não como feito.

### O que esta passada não fecha

- **Nenhum código de `src/` mudou** — os dois furos ficam por consertar, e o #41 tem dono proposto mas não
  tem branch aberta (a fila serializada manda: **22 → 17 → 18 → 20 → 13**).
- **A banda de 12,1–18 ms não foi cortada**: ela é a simulação de 20 Hz num quadro de ~6 ms, e mexer nela
  é mexer em cadência — decisão de gate, não de sonda.
- **Os três números de §5.2 não existem** (Passo 2 (b)); nenhuma VRAM foi medida aqui.
- **#38, #39, #20 e #25** continuam onde estavam; o #25 foi visto de novo, impresso no `git status` do
  clone limpo do pouso acima.
- A régua de tempo desta rodada **não mede alocação** e não substitui a colheita do budget HOT (regras 3
  e 5 do AGENTS.md): o que ela mede é período de quadro e o que estava ligado nele.

## Rodada 2026-11-24 (7) — Passo 2 (b) do dossiê 22: o pack dentro do processo, os três números lidos do runtime, e a prova de layout que quase ficou inatingível (branch `feat/oraculo-nativo-passo2b-22`, base `b0ed929`)

O critério de §5.2 fechou: o jogo abre com a cena de prova, o processo não morre, os três números saem,
e o passo 1 continua verde. O §16 da [`página 22`](planos/22-oraculo-nativo-gdextension.md) guarda a
história completa; aqui ficam o número e a regra que a perna deixa.

**A rota que a premissa FALSA (§15.5) obrigou, executada nas duas pontas.** `set_runtime_dir` com
caminho **absoluto** (cinco de cinco módulos) abre o pack vazio como base medida, o `.gguf` entra
dentro do processo do Godot por `AfMindOracle`, e o contexto só existe dentro de `ctx_probe(2048)` — o
pedido é propositalmente diferente do `--ctx-size` 4096 do host
(`llm_server_host.gd:64` — aposentado no Passo 4 do dossiê 22, commit 5138549), para o número lido não ser
confundível com o pedido por fora. A sonda de PE (`af_pack_probe`) roda a mesma rota, do mesmo corpo
(`mind_pack.cpp`), fora da engine antes — nada é copiado entre sonda e extensão.

**Os três números de §5.2, lidos do runtime** — o bloco `[numero]` da build
([`passo2b_build.log:220-227`](evidence/oraculo-nativo-22/passo2b_build.log)) e as oito checagens do
runner ([`passo2b_runner.log:540-547`](evidence/oraculo-nativo-22/passo2b_runner.log)):

| Grandeza | Valor medido |
| --- | --- |
| `af_vram_gb` — base (pack vazio) | **0,838 GB** (900 079 760 B), com `vram_used == vram_base` |
| `af_vram_gb` — depois do load | **3,381 GB** (3 630 637 200 B; Δ 2,543 GB) |
| `af_vram_gb` — depois do contexto | **3,988 GB** (4 282 327 184 B; Δ 0,607 GB) |
| `af_load_ms` | **2 057** no probe ([passo2b_build.log:223](evidence/oraculo-nativo-22/passo2b_build.log)), **1 939** na corrida do runner |
| `af_ctx_cells` — lido do modelo | **2 048** com `ESCRITA_CONFIRMADA_PELO_RUNTIME`; `ctx_train` 262 144 = meta `qwen35.context_length` do próprio `.gguf` |

Testemunhas ao redor: `vram_total=17095983104` (RX 9060 XT), RSS do SO crescendo no load
(174 813 184 → 3 556 532 224 B) e apenas 0,027 GB no passo do contexto — o cache morou na VRAM, não no
heap —, `state_bytes=606` (0,3 B por célula), `model_bytes=2729969664` contra 2 740 937 888 no disco,
e 33/33 layers offloaded para a Vulkan0.

**Duas corridas anteriores são instrumento, não festa.** A primeira caiu `0xC0000005` **depois** do
load, na linha do descritor: `llama_model_desc` tinha argumentos trocados e `llama_version` foi lida
como inteiro onde o runtime devolve `const char *` — assinaturas re-auditadas contra o `llama.h` do pin
b12499, que não entra na árvore (a cópia verificada foi apagada depois do confronto; S12.3 segue de
pé), e o log do crash está arquivado
([`passo2b_probe_crash.log`](evidence/oraculo-nativo-22/passo2b_probe_crash.log)). A segunda compilou,
linkou e saiu **exit 0** com o veredito `NAO_CONFIRMADA` na mesa
([`passo2b_build_inatingivel.log`](evidence/oraculo-nativo-22/passo2b_build_inatingivel.log)): o
**load** criava um contexto default de 512 células, o pedido 2048 nunca chegava ao runtime, e a
afirmação de layout (primeira palavra do blob de params de contexto = `n_ctx`) ficava inatingível sob
um exit 0.

**A regra que a perna deixa, fechada na causa:** um veredito de instrumento sob exit 0 não é número
publicado. O conserto tirou a criação de contexto do load de vez (`ctx_probe` é o único contexto do
processo), e o probe hoje recusa com **exit 8** quando o runtime aceita o contexto mas devolve outro
`n_ctx` — o [`build.bat`](../native/af_mind/build.bat) nomeia o exit 8 na recusa, e o dll não nasce sem
a testemunha. A build final sai `ESCRITA_CONFIRMADA_PELO_RUNTIME` com exit 0
([`passo2b_build.log:216`](evidence/oraculo-nativo-22/passo2b_build.log)) e os números acima são dela.

**O gate do runner** (`_test_extensao_pack_no_processo`,
[`tests/aether_reactions_test.gd`](../tests/aether_reactions_test.gd)): oito checagens, cada uma
nomeando a premissa que exige, censo **288 → 296**. Num clone sem o runtime e sem o `.gguf` (ambos
gitignored), as oito nascem vermelhas com o caminho impresso. A primeira corrida ensinou a ordem de
leitura: os dois RSS são grandezas **capturadas pelo load**, não leituras vivas — ler
`rss_antes_bytes()` antes do `load_pack` devolve o `-1` da inicialização, e a lição está escrita no
comentário do próprio teste.

**As quatro corridas da revisão, todas nesta árvore:** runner **296 / 0 / 44,648 s**
([`passo2b_runner.log`](evidence/oraculo-nativo-22/passo2b_runner.log)), suíte **255 / 0 / 51,0 s**
([`passo2b_suite.log`](evidence/oraculo-nativo-22/passo2b_suite.log)), RNG **27 / 0 / 2,895 s**
([`passo2b_rng.log`](evidence/oraculo-nativo-22/passo2b_rng.log)), journal **128 / 0 / 6,182 s**
([`passo2b_journal.log`](evidence/oraculo-nativo-22/passo2b_journal.log)). Nenhum `SCRIPT ERROR`; o
`.err` do runner é o chatter do ggml/Vulkan (a extensão carrega os backends dentro do processo), e o
da suíte é o par de vazamento conhecido do quit. O [`artifacts.sha256`](evidence/oraculo-nativo-22/artifacts.sha256)
do diretório foi regenerado com os 12 arquivos `passo2b` (121 entradas) e conferido com
`sha256sum -c` na pasta dele.

**O que esta passada não fecha:**

- **Não há API de prompt** (§5.3 é o Passo 3): `enqueue`, `wait`, sinais e métricas de fila não
  existem, e `mind_oracle.gd` continua HTTP. O `load_pack` é a rota de carga medida, não o transporte
  de inferência.
- **`src/` intocado** — `git diff --name-only main...HEAD -- src` devolve **vazio** — e
  `Channel.COUNT`, `FORMAT_VERSION` e `GEN_VERSION` parados; os hashes de journal publicados valem
  para a árvore resultante sem re-corrida.
- **Nenhum gate de fase** (mandato 4), e os furos **#38, #39 e #20** seguem onde estavam. O contexto
  medido é o **custo** (0,607 GB por 2 048 células), não a escolha do tamanho de produção.
- **Clone limpo:** os números acima são da árvore da branch; o pouso re-mede no clone limpo do merge
  (mandato 3, item 6) e o registro do pouso pina os dois lados, como o pouso do Passo 2 (a) fez.

*(Estado re-derivado pelo pouso abaixo: as quatro corridas e a régua de âncoras da (7) valem para a
ponta `e674d8d`; a `main` mergida é `a637ee9` e foi re-medida nas quatro corridas, com o `build.bat`
re-executado dentro do clone limpo. A fila serializada não muda: **22 → 17 → 18 → 20 → 13**.)*

## O pouso do Passo 2 (b) na `main` — o `src` parado e o `tests` que se move, as quatro corridas da mergida, os dois vermelhos nascidos do clone e a trip marginal de 3 µs (2026-11-24, `docs/registro-pouso-passo2b-22`, base `b0ed929`, ponta `e674d8d`, merge `a637ee9`)

### O que o merge toca, com o número em cada árvore

`git merge --no-ff feat/oraculo-nativo-passo2b-22` devolve **`a637ee9`** sobre **`b0ed929`** (ponta da
branch: `e674d8d`), **28 arquivos, +7 954/−63**: em `native/af_mind/`, o corpo do pack
[`mind_pack.cpp`](../native/af_mind/src/mind_pack.cpp) novo com **928** linhas e
[`mind_pack.h`](../native/af_mind/src/mind_pack.h) com 114, a sonda de pé
[`pack_probe_main.cpp`](../native/af_mind/src/pack_probe_main.cpp) com 214, a ponte em
[`register_types.cpp`](../native/af_mind/src/register_types.cpp) **+519**, o
[`build.bat`](../native/af_mind/build.bat) **+123** e o
[`check_imports.py`](../native/af_mind/check_imports.py) **+18**; no `tests/`, o runner com as oito
checagens novas (`tests/aether_reactions_test.gd` +129); e a prosa de três documentos.

| Árvore | `b0ed929` | `e674d8d` | `a637ee9` |
| --- | --- | --- | --- |
| `src` | `f77c1961bb8065ea…` | idem | **idem** |
| `tests` | `0faee7ff5b26d6ef…` | `acd872ebcd69fb8f…` | **`acd872eb…`** |
| `native` | `bec0fc7ac4089c40…` | `94dbd12e8ba73113…` | **`94dbd12e…`** |

Diferente do pouso do (a), onde `tests` também não se moveu, este passo escreve checagem: o `tests`
**mexe** — são as oito checagens `_test_extensao_pack_no_processo` do censo 288 → **296** — e por isso
os números de runner abaixo são **re-medição de contrato**, não herança por identidade. O `src` continua
parado desde o merge do (a): `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a projeção do journal
não têm o que mudar, e os hashes publicados nas rodadas anteriores valem para a árvore resultante.

Publicação da branch conferida com `git ls-remote --heads origin`:
`refs/heads/feat/oraculo-nativo-passo2b-22` = `e674d8d5ec05d5238c343333f2e1a8e8b5e89a5e`. A da `main`
desta passada é conferida pelo mesmo comando no fecho deste registro — é a única prova de que saiu; o
exit 0 do `push` não prova.

### As quatro corridas da árvore mergida, com a máquina livre

Antes delas, `--import` na árvore mergida
([`main_mergida_import.log`](evidence/registro-pouso-passo2b-22/main_mergida_import.log), 16 linhas,
exit 0, stderr **0 bytes**). Nenhum processo `Godot*` antes da primeira invocação; as quatro rodaram
serial.

- Runner de reações: [`main_mergida_runner.log`](evidence/registro-pouso-passo2b-22/main_mergida_runner.log)
  — as cinco `OK extensao_carrega_classe` nas linhas **535-539** (mesmas posições do (a): descritor no
  disco, `ja_vinha_do_boot=true agora=true total_registradas=1`, `is_library_open=true`,
  `class_exists(AfMindOracle)=true`, `instantiate_valido=true get_class=AfMindOracle`), as oito
  `OK extensao_pack_no_processo` em **542-547** com os três números de §5.2 na **547**
  (`base=900079760 apos_load=3630637200 apos_ctx=4282327184 ctx_state_bytes=606 versao=1.0.0-dev`),
  `load_ms=2145`, `model_bytes=2729969664`, RSS do SO 174 501 888 → 3 556 454 400 B, `67/67` em 549,
  `trips_solo=0 trips_matilha=0` em 550, `296/296` em 551, cenário estreito com **10 568** passos
  (`sim_step total=2 727 389 µs`, pico `5 945 µs`) em 552, matilha com **1 341** passos
  (`sim_tick total=3 800 821 µs`, pico `19 349 µs`) em 553, e **554** `296 checagens 0 falhas 45.955 s`.
  Exit 0; o `.err` de **183 717 bytes** é o chatter do ggml/Vulkan — a extensão carrega os backends
  dentro do processo (`loaded RPC backend`, `0 = AMD Radeon RX 9060 XT`).
- Suíte: [`main_mergida_suite.log`](evidence/registro-pouso-passo2b-22/main_mergida_suite.log) — linha
  **357** `== 255 checagens  0 falhas  60.3 s de teste ==`, exit 0, zero `SCRIPT ERROR`, e o `.err` saiu
  com **0 bytes**: o par de vazamento do quit (249 B quando aparece) não apareceu nesta corrida — é a
  intermitência já registrada, e a ausência não é conserto.
- RNG da sessão: [`main_mergida_rng.log`](evidence/registro-pouso-passo2b-22/main_mergida_rng.log) —
  **78** `27 checagens 0 falhas 2.948 s`.
- Journal por tick:
  [`main_mergida_journal.log`](evidence/registro-pouso-passo2b-22/main_mergida_journal.log) — **143**
  `128 checagens 0 falhas 7/7 testes concluidos 7.325 s`.

### O pin: clone limpo de `a637ee9`, com o `build.bat` rodando dentro dele

`git clone` do repositório local, HEAD `a637ee9…`. O `git status --short` do clone devolve **exatamente
duas** linhas — `?? tests/audio_live_probe.gd.uid` e `?? tests/audio_test.gd.uid` — é o **furo #25**
impresso, na forma esperada. O `bin/` não vem ([`.gitignore:8`](../.gitignore#L8)), então o build faz
parte do pin.

- `--import` frio ([`clone_limpo_import.log`](evidence/registro-pouso-passo2b-22/clone_limpo_import.log),
  exit 0): o `.err` de **602 bytes** traz as quatro linhas `GDExtension dynamic library not found:
  'res://native/af_mind/af_mind.gdextension'` — o **furo #38** se repetindo no clone, antes do build
  existir, pela mesma razão do (a): o import roda sem `bin/`, e a ordem honesta é import → build →
  runner.
- `build.bat` no clone
  ([`clone_limpo_build.log`](evidence/registro-pouso-passo2b-22/clone_limpo_build.log), 246 linhas,
  exit 0): a sonda de pé roda a rota completa antes de o dll existir (`probe_rota_codigo=0` em **228**),
  a ponte linka (`link_codigo=0` em **230**), o dll sai com **165 376 B** e
  `export= 1 00001EF0 af_mind_entry` (**232**) e a régua de imports lê **40/40** —
  `[import] OK referenciados=40 modulos=4 nomes_na_tabela=40` (**244**), a tabela nova do Passo 2 (b)
  (`AF_SLOT` **e** `AF_REF`) confirmada inteira dentro do clone. O `.err` de 184 224 bytes é o chatter
  dos backends de terceiro no stderr da build (`load_backend: loaded RPC backend from
  C:\Aetherfall\.tools\llama\runtime\…`), a mesma forma do (a).
- Os dois recursos que a checagem resolve pelo diretório do projeto —
  `res://.tools/llama/runtime` e `res://models/qwen3.5-4b-q4_k_m.gguf` — são gitignored
  ([`.gitignore:5`](../.gitignore#L5) e [`.gitignore:16`](../.gitignore#L16)), e o clone nasce sem os
  dois **por design**. O provisionamento do clone desta medição é **junção** (`…\.tools\llama` apontando
  para a árvore de trabalho) mais **hardlink** do `.gguf` de 2 740 937 888 B — ambiente de máquina, não
  mudança de árvore; um clone em outra máquina chega aos vermelhos abaixo, que são o comportamento
  esperado dele.
- A sequência de vermelhos do clone é instrumento arquivado, não fracasso. **Sem nada**, as oito
  nascem vermelhas com os dois caminhos impressos como motivo, nunca número chutado
  ([`clone_limpo_runner_sem_recursos.log`](evidence/registro-pouso-passo2b-22/clone_limpo_runner_sem_recursos.log)
  540-547: `llama_dll=false`, `bytes=-1`, `modulos=-2 codigo=-1`; rodapé `296 checagens 8 falhas
  37.098 s`). **Com runtime e sem modelo**, cinco falhas e o load recusa com `codigo=-6`
  ([`clone_limpo_runner_sem_modelo.log`](evidence/registro-pouso-passo2b-22/clone_limpo_runner_sem_modelo.log)
  **544**, `estado=2`; a **542** `OK … modulos=5 codigo=0 estado=2` prova que a base abre sem modelo —
  rodapé `296 checagens 5 falhas 37.219 s`). E **com tudo**, uma corrida saiu `trips_matilha=1` com
  `pico=403` — **3 µs** sobre o teto de 400 µs — em árvore byte-idêntica
  ([`clone_limpo_runner_trips_red.log`](evidence/registro-pouso-passo2b-22/clone_limpo_runner_trips_red.log)
  **550**, rodapé `296 checagens 1 falhas 41.614 s`); a re-corrida imediatamente depois saiu verde com
  `trips=0`, e **as duas ficam arquivadas** — a regra já medida: trip marginal em 3 µs é ruído de
  máquina na borda do teto e não se atribui a causa sem re-corrida.
- O pin verde: runner
  [`clone_limpo_runner.log`](evidence/registro-pouso-passo2b-22/clone_limpo_runner.log) — as cinco
  `OK extensao_carrega_classe` nas mesmas linhas **535-539**, as oito pack em **541-547** com
  `load_ms=2251` no clone (2 145 na mergida, 1 963 no probe da build — grandezas distintas entre
  corridas, os três números de §5.2 idênticos), RSS 175 210 496 → 3 556 106 240 B, `trips=0`,
  `296/296`, cenário estreito `sim_step total=2 954 399 µs` pico `6 094 µs`, matilha
  `sim_tick total=4 224 149 µs` pico `20 044 µs`, e **554** `296 checagens 0 falhas 45.278 s`; exit 0.
  Suíte: [`clone_limpo_suite.log`](evidence/registro-pouso-passo2b-22/clone_limpo_suite.log) linha
  **357** `== 255 checagens  0 falhas  56.1 s de teste ==`, exit 0, zero `SCRIPT ERROR`, `.err` com os
  mesmos **249 bytes** do par de vazamento. RNG e journal não rodaram no clone — o que o clone renova
  aqui é a suíte e o runner com a extensão nova; o journal tem a árvore `src` parada como garantia.

O número pineado para `a637ee9` é: runner **296 / 0 / 45,955 s** na mergida e **296 / 0 / 45,278 s** no
clone, suíte **255 / 0 / 60,3 s** e **255 / 0 / 56,1 s**, RNG **27 / 0 / 2,948 s** e journal
**128 / 0 / 7,325 s** — as duas últimas só na mergida.

### As três réguas no ponto fixo desta passada, e o manifesto

Elas rodam **depois** da prosa existir, não antes — item 7 do ciclo de trabalho.

- [`pouso_ruler_doc_anchors.log`](evidence/registro-pouso-passo2b-22/pouso_ruler_doc_anchors.log):
  39 arquivos · **3 079 ponteiros conferidos · 209 rótulos · 3 415 links · 0 casos objetivos**, exit 0.
  Contra os **3 079 / 3 390** que a ponta `e674d8d` media
  ([`passo2b_ruler_anchors.log`](evidence/oraculo-nativo-22/passo2b_ruler_anchors.log)), o acréscimo de
  **27 links** é desta escrita — a prosa do pouso referencia a pasta de evidência nova — e não abriu
  caso nenhum. A primeira captura desta régua abriu três `LINK QUEBRADO`, e os três são a ordem das
  coisas, não defeito: a prosa cita os dois logs de régua restantes e o manifesto **antes** de os três
  existirem; re-rodou verde depois de os três serem criados. O único caso tolerado continua sendo o
  ponteiro `../.tools/...`, gitignored.
- [`pouso_ruler_plan_cites.log`](evidence/registro-pouso-passo2b-22/pouso_ruler_plan_cites.log):
  **1 041** citações com número de linha conferidas, **10** arquivos citados que não existem, **0**
  números fora do arquivo, exit 0. Os dez são os de sempre — os três rascunhos `.tools/_head_*.md` e as
  peças `[TARGET]` que as próprias páginas declaram inexistentes (`src/ai/reach.gd`,
  `src/core/sim/entity_store.gd`, `src/core/sim/tick_clock.gd`,
  `tests/wolf_multiseed_census_test.gd`) — e nenhum deles é afirmação de que o arquivo está lá. Contra
  o **1 039** do pouso do (a), o acréscimo é da prosa da (7) mais a desta — e uma testemunha deste
  pouso precisa dizer a verdade sobre a (7): o
  [`passo2b_ruler_cites.log`](evidence/oraculo-nativo-22/passo2b_ruler_cites.log) arquivado por ela saiu
  **0 citações conferidas** porque rodou **sem corpus** — a ferramenta recebe os arquivos em
  `sys.argv[1:]`, a mesma armadilha que o pouso do (a) registrou —, e nenhuma prosa da (7) cita esse
  número como medição. A régua certa é esta daqui.
- [`pouso_ruler_plan_ids.log`](evidence/registro-pouso-passo2b-22/pouso_ruler_plan_ids.log): exit 0 com
  as ausências de sempre, e nelas a classe do **furo #39** — a régua monta o corpus com `src/**/*.gd` e
  `tests/**/*.gd` e nunca abriu um `.cpp`, então os nomes de `native/` aparecem aqui sem serem defeito.

A pasta de evidência deste pouso fecha com manifesto:
[`artifacts.sha256`](evidence/registro-pouso-passo2b-22/artifacts.sha256) com **27** entradas, gerado
com `sha256sum -b` a partir de dentro da pasta (o `-b` importa: `.gitattributes:9` marca
`docs/evidence/**` como `-text` justamente para o log sair byte a byte) e conferido com
`sha256sum -c --quiet` na pasta dele, **27 OK** e **0** bytes de CR no manifesto.

### O que o pouso deixa aberto

Nenhum gate de fase (mandato 4). Dentro da perna faltam o **Passo 3** (testemunha da regra de ouro —
nenhuma camada de linguagem move pé) e o **Passo 4** (`transporte_http_zerado`); não há API de prompt
(§5.3 é o Passo 3) e `mind_oracle.gd` continua HTTP. O `src` da mergida é o mesmo do merge do (a), então
nenhuma rodada anterior tem número invalidado por este merge. Dos furos, **#38** (clone sem build) e
**#39** (réguas cegas a `native/`) continuam abertos como decisão do dono, o **#20** continua sem a
colheita que nomeia a folha, e a **alocação** do caminho quente (dicionário por lobo por tick, `keys()`
do cache de rastros) segue sem colheita própria — o que este passo mediu é **custo de memória e
contexto**, não custo de alocação. A fila serializada não muda: **22 → 17 → 18 → 20 → 13**.

## O pouso da perna 23 na `main` — a água tem o primeiro shader e a primeira partícula do projeto, a malha não se moveu, e a régua de 25 ms deu um vermelho que voltou a não ter dono (2026-11-24, `feat/elevacao-visual-agua-23`, base `b0ed929`, ponta `3c7aae9`, merge `05e8917`)

A cláusula do dono era **só visual**: "Não tocar na IA ou na lógica de gameplay neste prompt". Lida
contra o que o merge escreve, ela fechou: `git diff --name-only c05f1df 05e8917 -- src tests` devolve
sete arquivos — [src/main.gd](../src/main.gd) (+22), [src/world/voxel_world.gd](../src/world/voxel_world.gd)
(+71/−10), os dois novos ([src/world/water_surface.gd](../src/world/water_surface.gd) 237 linhas,
[src/rendering/water_fx.gd](../src/rendering/water_fx.gd) 352) com os `.uid`, e
[tests/smoke_test.gd](../tests/smoke_test.gd) (+372) — e nada em `src/ai/`, `src/entities/`,
`native/` ou `block_defs.gd`. `Channel.COUNT`, `FORMAT_VERSION` e `GEN_VERSION` não foram tocados.

### As nove checagens da água, lidas da corrida da árvore mergida

Censo: **264 checagens / 0 falhas / 57,6 s** ([suite23-merged.log:378](evidence/elevacao-visual-agua-23/suite23-merged.log#L378)),
sobre a base de **255** do pin da 22 — as nove novas são estas, com a linha literal:

| :40 | `agua nao muda a malha` | `base=214448  espelho=214448  sessao=214448` |
| :53 | `material_da_agua_e_shader` | `shader=true  surface=1  declarados=16  gravados=14  sem_fonte=0` |
| :54 | `mascara_de_onda_do_bloco_isolado` | `verts=24  tri=12  mascarados=12  fora_do_plano=0  verticais=16  g_max=0.000` |
| :55 | `coluna_de_agua_ondula_so_no_topo` | `verts=40  tri=20  mascarados=12  fora_do_plano=0  g_max=0.247 (1 bloco embaixo = 0,25)` |
| :61 | `corpo_seco_nao_dispara` | `salpicos_jogador=0->0  molhado_na_janela=false  andado=9.36 m` |
| :64 | `coluna_de_queda_funda` | `coluna=(100,52)  blocos=12  plano=26.880` |
| :67 | `orcamento_de_particulas` | `emissores=12  anis=12  soma=364  teto=364  vivas=41  picos=1` |
| :68 | `queda_na_agua_dispara_salpico` | `disparados=0->1  jogador=0->1  vy=-12.40  col=(100, 52)  plano_fx=26.880 plano_mundo=26.880  blocos=6` |
| :69 | `fx_nao_escreve_o_mundo` | `assinatura_ok=true  edits_globais=0->0  eter_seco=0.000000  eter_salpico=0.000000  canais=3  fx_sem_eter=true` |

A linha :70 imprime o custo do FX como leitura, não como gate: `custo do FX: quadros=295  us_total=5452
media=18.48 us/quadro  pico=124 us`. O `plano_fx=26.880` do salpico e o `plano_mundo=26.880` da
consulta do mundo são o mesmo número vindo de dois caminhos — é o §3.7 do dossiê pago por igualdade
de float, e a premissa da janela (`coluna_de_queda_funda`, 12 blocos acima de `BUBBLE_MIN_BLOCKS`)
está na mesa justamente para o verde de :68 não ser sorte.

**O furo #43 fecha aqui, com a checagem que o paga**, e o que ele era está escrito na seção própria
abaixo: o `COLOR` que a malharia já preenchia com o `FACE_TINT` da face não era lido por ninguém; hoje
o vértice do shader desloca `VERTEX.y` por `COLOR.r`
([src/world/water_surface.gd:190](../src/world/water_surface.gd#L190),
[:193](../src/world/water_surface.gd#L193)) e o fragment lê `COLOR.b`/`COLOR.g` como parede e altura
de coluna ([:210-212](../src/world/water_surface.gd#L210-L212)); quem liga o material é
[src/world/voxel_world.gd:131](../src/world/voxel_world.gd#L131). O que decide a cláusula não é a
frase: é `material_da_agua_e_shader` (:53) e `mascara_de_onda_do_bloco_isolado` (:54).

### A prova com janela, e o chão de controle que a tornava falsa sem ele

O par do §5.2, nas duas árvores: `SHADER ERROR` **0 / 0**; a caixa de água sobre a superfície da
coluna `(100,52)` dá **0,8471** de fração `ge3` na perna e **0,0000** na base; o quadro inteiro dá
**0,3999** contra **0,0468** ([sonda-23.log](evidence/elevacao-visual-agua-23/sonda-23.log),
[sonda-base-b0ed929.log](evidence/elevacao-visual-agua-23/sonda-base-b0ed929.log)). As quatro
salvaguardas estão arquivadas: os dois enquadramentos são byte a byte o mesmo
(`coluna=(100,52)`, `olho=(101.50, 29.62, 39.50)`, `pitch=-0.198`, `camera_deslocou=0.0000 m`);
nenhum slot de FX vivo na cena da sonda (`vivas_pool=0/0/0`, `salpicos_disparados=0`, `picos=0`);
os dois PNGs de controle da base têm o **mesmo** SHA-256 `ae3d7dc4…` — t1 e t2 da água parada não se
movem, enquanto t1/t2 da perna são `520c3d5f…` / `551455ad…`; e a caixa foi re-derivada **sem Godot
nem GPU** a partir dos próprios PNGs e devolve 0,8471 e 0,0000
([confere_caixa.log](evidence/elevacao-visual-agua-23/confere_caixa.log)).

Os `.err` das duas corridas **não** são iguais, e a diferença não é da água: a base imprime **3**
linhas `ERROR:` ([sonda-base-b0ed929.err](evidence/elevacao-visual-agua-23/sonda-base-b0ed929.err#L1))
e a perna imprime **0** ([sonda-23.err](evidence/elevacao-visual-agua-23/sonda-23.err)) — as três da
base são `!FileAccess::exists`, `GDExtension dynamic library not found: 'res://native/af_mind/…'` e
`Error loading extension`, todas da extensão da perna 22, que no worktree da 23 estava presente e na
árvore de controle não. **Zero** erros de shader dos dois lados, e é isso que a cláusula "compila"
exige.

### A régua de 25 ms: um vermelho, dez corridas, e o instrumento que faltava para falar dele

`espalhamento_nao_estoura_o_passo` ([tests/smoke_test.gd:3468-3484](../tests/smoke_test.gd#L3468-L3484))
deu **vermelho uma vez** na árvore mergida: `264 checagens 1 falhas 57,8 s`, com
`pior passo=25,76 ms (regua 25)`
([suite_main_vermelho.log](evidence/elevacao-visual-agua-23/suite_main_vermelho.log)). Não foi
silenciado e a régua não foi abaixada. As nove outras corridas, na mesma árvore:

| corrida | pior passo | rodapé |
|---|---|---|
| mergida, logo após o merge (a vermelha) | 25,76 ms | 264 / **1** / 57,8 s |
| mergida, verde a / b / c | 15,69 / 16,25 / 16,49 ms | 264 / 0 / 54,5 · 56,7 · 60,4 s |
| mergida, churn do palco reproduzido | 16,32 ms | 264 / 0 / 53,9 s |
| mergida, com o amostrador ligado | 13,87 ms | 264 / 0 / 54,4 s |
| clone limpo do pin `05e8917`, `--import` frio | 12,99 ms | 264 / 0 / 54,3 s |
| clone limpo da base `c05f1df`, `--import` frio (controle) | 12,61 ms | **255** / 0 / 50,3 s |
| clone do pin, amostrado / silencioso | 12,75 / 11,40 ms | 264 / 0 / 53,6 · 53,8 s |

Três coisas se podem dizer com log na mesa:

1. **Nada que a 23 acrescentou está dentro da região cronometrada.** `worst_sim_ms` vem de
   `clock.begin_step()`/`end_step()` dentro de `_physics_process`
   ([src/main.gd:333-339](../src/main.gd#L333-L339), [:330-331](../src/main.gd#L392-L393)); a
   malharia (`world.process(MESH_BUDGET)`) e o FX rodam em `_process`, **fora** dela. A 23 também não
   mudou `triangle_count()` — é a checagem :40, e o número da base é o mesmo.
2. **O vermelho tem a assinatura do furo #31**, que a perna 12 já tinha medido na mesma árvore e no
   mesmo tick (`dens=3 componentes=2 separacao=55.9 m`): lá, 96,48 ms contra 15,81 ms; aqui, 25,76 ms
   contra 13,87 e 11,40 ms. Palco, código e régua idênticos dos dois lados em ambas as pernas.
3. **O que a casa exigia e não existia era o instrumento.** O `#31` cobrava "filtrar por
   `ExecutablePath` dentro do projeto, não por nome de processo"; o amostrador que obedece está
   arquivado ([carga_23.ps1.txt](evidence/elevacao-visual-agua-23/carga_23.ps1.txt)) e abriu um furo
   próprio — ver **#44**. Nos 40 samples ligados durante a corrida verde da mergida: `load` do
   sistema **0 / 10 / 37 %** (mín / med / máx), `QuantumEngine` (o app de áudio da JBL, PID 14228)
   entre **45 % e 78 % em toda amostra**, `MsMpEng` (Defender) entre 11 % e 61 %, e o processo Godot
   desta corrida visto pelo amostrador em até **109 % de um núcleo**. O runner concorrente da perna
   22 (PID 26828) estava vivo desde 16:26:34 com **7 MB e 1 thread**, `cpu=0%` — parado, não
   competindo.

Então: **a atribuição continua aberta, escrita assim.** O vermelho aconteceu uma vez em dez corridas
na árvore mergida, a régua não se moveu, nada foi calado, e nenhuma porcentagem medida nesta passada
cai sobre a janela da corrida vermelha — ela não foi amostrada. Dizer "carga na máquina" sem o número
daquela janela é exatamente a frase que o `#31` já retirou. Fica como débito com dono: a próxima
perna que rodar a suíte nesta árvore roda com `carga_23.ps1` ligado e arquiva o par.

### Clone limpo, censo, e os seis vermelhos que não são desta perna

O pin é o merge medido, `05e8917` (pais `c05f1df` e `3c7aae9`); as árvores são `3c436fb6d6f3…`
(`src`) e `8decf7d42e3c…` (`tests`), **iguais** às da ponta `3c7aae9` —
`git diff --name-only 3c7aae9 05e8917 -- src tests docs` devolve vazio, o merge não acrescenta nada
sobre o que foi medido. No clone limpo com `--import` frio: suíte **264 / 0 / 53,6 s** (amostrado) e
**264 / 0 / 53,8 s** (silencioso); runner de reações **289 checagens / 6 falhas / 34,988 s** com
`FALHA censo de checagens | 289/296`; RNG **27 / 0 / 2,675 s** (`27/27`); journal **128 / 0 / 5,983 s**
(`7/7 testes concluidos`).

Os seis vermelhos do runner **não são da água**, e isso tem controle, não adjetivo: as cinco linhas
são `extensao_carrega_classe` ×4 e `extensao_pack_no_processo` — checagens da perna 22, que falham
num clone limpo porque `native/` é gitignored e o `.dll` não vem com o `git clone` (é o **furo #38**,
decisão do dono). A corrida de controle na árvore **anterior** a esta perna (`c05f1df`, clone limpo)
devolve **o mesmo rodapé 289 / 6 / 34,831 s e as mesmas cinco linhas**
([base-runner_pre23_frio.log](evidence/elevacao-visual-agua-23/base-runner_pre23_frio.log) contra
[clone_amostrado_runner.log](evidence/elevacao-visual-agua-23/clone_amostrado_runner.log)).

### As três réguas, e o que a de âncoras viu que a minha varredura não viu

- `python tools/check_doc_anchors.py`
  ([regua_anchors_final.log](evidence/elevacao-visual-agua-23/regua_anchors_final.log)):
  **40 arquivos · 3 163 ponteiros conferidos · 209 rótulos ·
  3 534 links relativos**, com **5** casos objetivos — os cinco `../.tools/...` gitignored que a base
  já tinha, conferidos na árvore de controle
  ([regua_anchors_base_c05f1df.log](evidence/elevacao-visual-agua-23/regua_anchors_base_c05f1df.log):
  **39 arquivos · 3 079 ponteiros · 209 rótulos · 3 417 links**, também **5** casos). Os **3** links a
  mais que esta árvore tem contra a medição da passada anterior, nesta mesma ponta, são os três que o
  registro do pouso
  no `AGENTS.md` abriu: os dois arquivos novos da água e este arquivo. **Na árvore desta perna, antes do conserto, eram 22.** Os 17 novos eram todos
  `src/main.gd` e `tests/smoke_test.gd` depois do shift: **11** ROTULO FORA DO CORPO (o rótulo nomeia
  `_home_columns`, `SPAWN_BANDS`, `PACK_LEASH`, `_spawn_point_ok`, `_spawn_home_point`,
  `_den_counts`, `_emptiest_den`, `_den_gate_ok`, `den_min_dist`, `DEN_COUNT`, `DEN_MIN_DIST` e o
  corpo está 16 linhas adiante), **4** BRANCO nos dossiês 01, 02, 08 e 16 e **2** BRANCO no próprio
  status. Cada um foi conferido contra o corpo que o rótulo nomeia, não contra o deslocamento médio.
  **E a régua apanhou mais um depois de aquilo estar escrito**: a página 15 apontava para as linhas
  502 e 3059 deste arquivo — a 3059 caiu em linha branca, que é o caso que ela
  vê, e a 502 tinha caído em prosa de *outra* exceção de ordem, que é o caso que ela não vê
  (face do **#28**). Os três ponteiros foram re-lidos pela frase para as linhas 553, 3169 e
  566-567,
  e a passada que os corrigiu é esta; a página 15 conta o caso no §11 dela.
- `verify_plan_cites.py` com os **51** arquivos versionados de `docs/` + `AGENTS.md` + `README.md` e
  `AETHER_ROOT` apontando para a árvore auditada
  ([regua_cites_final.log](evidence/elevacao-visual-agua-23/regua_cites_final.log)): **3 012**
  citações com número conferidas, **76**
  arquivos citados que não existem, **0** números fora do arquivo. A base (`c05f1df`, 50 arquivos —
  falta a página 23), medida no clone de controle com o log próprio
  ([regua_cites_base_c05f1df.log](evidence/elevacao-visual-agua-23/regua_cites_base_c05f1df.log)), dava
  **2 930 / 75 / 0**: o conjunto de ausências não mudou de espécie, e os 76
  são as peças que os dossiê declaram como alvo (as 32 fora de `.tools/` incluem
  `src/core/sim/tick_clock.gd`, `src/ai/reach.gd`, `src/entities/falling_block.gd`,
  `tests/wolf_multiseed_census_test.gd` e as dezesseis linhas de arquitetura de `docs/design/07`).
  **O septuagésimo sexto é desta página**: a frase que lista as ausências cita
  `src/entities/falling_block.gd`, e para a régua uma citação é uma citação mesmo quando o que ela
  faz é nomear o que não existe — ela contou a si mesma. Registramos o número em vez de reescrever a
  frase, porque baixá-lo exigiria apagar o nome da peça que a perna 17 declara inexistente.
- `verify_plan_ids.py docs/planos/23-elevacao-visual-agua.md`
  ([regua_ids_23_final.log](evidence/elevacao-visual-agua-23/regua_ids_23_final.log)): **97** identificadores em backticks,
  **10** ausentes em `src/` e `tests/`, conferidos um a um: `ARRAY_DATA`, `LINEAR_WITH_MIPMAPS`,
  `forward_plus`, `ReflectionProbe` e `gdshader` são API do engine citada como escolha;
  `CPUParticles3D` é citada na sonda que prova a **ausência** de partícula na base (§2), e o que
  pousou é `GPUParticles3D`; `Weather` é a Fase 2 `[TARGET]`; `entered_water` é o **braço rejeitado**
  do §3.6; `grep` é
  comando; e `ae3d7dc4…` é o SHA do PNG de controle. **Nenhum é identificador de código escrito em
  vão.** Dois estavam, e saíram: a tabela do §5.1 prometia `surfaces_com_shader`,
  `uniformes_sem_fonte` e `salpicos_vivos` quando a corrida imprime `surface=1`, `sem_fonte=0` e
  `vivas=41` — reescrita com a linha literal e com a aritmética do teto à vista (8×24 + 12 + 4×40 =
  364).

### Furo #43 — fechado por este pouso: o `COLOR` que a malharia escrevia e ninguém lia

O §2 do dossiê prometeu a checagem antes da linha, e ela veio: `material_da_agua_e_shader` (:53)
prova que a superfície é uma `ShaderMaterial` com `shader` carregado e que nenhum uniforme gravado
está sem declaração (`sem_fonte=0`; `declarados=16` contra `gravados=14` porque `screen_tex` e
`depth_tex` liga o engine, não o código), com `surface=1` — o índice da água dentro da malha do
chunk. `mascara_de_onda_do_bloco_isolado` (:54) conta os vértices com `COLOR.r > 0,5` dentro daquela
superfície e exige `verts=24  tri=12  mascarados=12  fora_do_plano=0  verticais=16  g_max=0.000`: os
24/12 são derivados de `FACE_CORNERS` e do culling contra `AIR` (seis faces de uma célula no ar), o
`fora_do_plano=0` diz que todo vértice mascarado está exatamente no plano do topo, e `g_max=0,000`
que nenhuma coluna foi fingida — números conferidos por conteúdo, não lembrados
([tests/smoke_test.gd:630-656](../tests/smoke_test.gd#L630-L656),
[:694-711](../tests/smoke_test.gd#L694-L711)). O resto é a linha do parágrafo acima: `VERTEX.y`
deslocado por `COLOR.r`
([src/world/water_surface.gd:190](../src/world/water_surface.gd#L190),
[:193](../src/world/water_surface.gd#L193)) e `COLOR.b`/`COLOR.g` lidos como parede e altura de
coluna ([:210-212](../src/world/water_surface.gd#L210-L212)).

### Furo #44 — novo: a coluna do amostrador estava presente no stdout e não media nada

A regra que ele quebra é a mesma do **#31**. O amostrador escrito para dar ao `#31` a coluna que
faltava imprimiu `cpu=-1` e PID vazio em **todas as 143 linhas de processo das duas primeiras
corridas**
([carga_coluna_pid_morta.log](evidence/elevacao-visual-agua-23/carga_coluna_pid_morta.log),
[carga_clone_a.log](evidence/elevacao-visual-agua-23/carga_clone_a.log)): em
`Win32_PerfFormattedData_PerfProc_Process` a chave é **`IDProcess`**, não `ProcessId`, e o join
`{ $_.ProcessId -eq $p.ProcessId }` compara `$null` com o PID e nunca casa — o que era para ser a
testemunha da carga virou uma constante. É o padrão que esta casa já contou no `#31` (filtrar por
nome em vez de `ExecutablePath`), no `#32` (o `ERRORLEVEL` lido depois do redirect) e no `#35` (o
`link` do Git). Dono: quem rodar a próxima janela amostrada nesta árvore; o instrumento consertado
está versionado como evidência, e a corrida verde de `13,87 ms` foi feita com ele já consertado.

### O mais que esta passada abre, e o que deixa onde estava

- **Nova face do #28**, medida e não inferida: a varredura numérica da casa **mexe em ponteiro, não
  em frase**, e por isso não vê um rótulo cujo corpo se moveu 16 linhas para frente, nem um número de
  linha que hoje é branco. As duas faces só aparecem quando a régua compara o **conteúdo** do alvo —
  quem contou os 17 foi o `check_doc_anchors.py`, não a minha leitura.
- Continuam abertos, sem dono novo: **#31** (a atribuição do vermelho intermitente), **#38** e
  **#39** (clone sem build, réguas cegas a `native/`), **#20** (colheita do budget por folha) e a
  **alocação do caminho quente**.

### O que nada disso fecha

Nenhum gate de fase. A fila P0/P1 continua exatamente como estava: budget HOT sem medição, censo
multi-semente sem corrida, bake-off de AF sem número. Das cinco fases do prompt visual, **só a Fase 1
foi pedida e só ela foi escrita**; clima/vento (`Weather`), `Environment` versionado, superfícies
molhadas e o atlas novo esperam o gate um do outro, na ordem do §3.9 do dossiê. A refração de uma
amostra e a reflexão espelhada de um passo estão escritas e rodam (§3.4); o que continua **de fora** é
o `SSR` do `Environment` e a `ReflectionProbe` por bioma — o braço rejeitado da mesma página, cujo
número que o reabre (a reflexão de tela mostrando o **chão** no lugar do céu em mais de um quadro da
sonda) **não** foi medido por esta passada: a sonda contou a fração de água na caixa, não o conteúdo
do raio espelhado. `block_changed` segue sem consumidor em `src/` (débito da 17). A fila serializada
volta a **22 → 17 → 18 → 20 → 13**, com a 23 fora da frente e a 22 ainda em voo na árvore primária.

**O fecho de docs desta ponta não re-rodou a suíte, e o motivo é de árvore, não de pressa.** O merge do
registro toca apenas `AGENTS.md`, este arquivo, o índice dos dossiês, as cinco páginas que a varredura
re-derivou e a pasta de evidência: `git diff --name-only main docs/registro-pouso-23 -- src tests` devolve
**vazio**, então `src/` e `tests/` da árvore resultante são byte a byte os do pin `05e8917`, e os números
publicados acima — **264 / 0** e **289 / 6** — valem por identidade de árvore, a mesma regra que a pauta
da 20 declarou. Rodar a suíte aqui seria, além de tudo, uma corrida de timing concorrente com o trabalho
não commitado da perna 22 na árvore primária, e a casa não faz isso ("Medição de tempo é serial").
## Rodada 2026-11-24 (8) — Passo 3 do dossiê 22: a API do prompt dentro do processo, o gate de forma contra forma, e o sinal 11 fechado na causa (branch `feat/oraculo-nativo-passo3-22`, base `c05f1df`)

O §5.3 fechou: `enqueue`/`wait`/métricas/sinais existem na `AfMindOracle`, duas narrativas reais
decodaram **dentro do processo do Godot**, e o gate
[`contrato_igal_ao_http`](../tests/aether_reactions_test.gd) compara a **forma** da saída das duas
transportas — HTTP e extensão — porque frase é do modelo, não do transporte. O §17 da
[`página 22`](planos/22-oraculo-nativo-gdextension.md) guarda a história completa; aqui ficam o número
e a regra que a perna deixa.

**Três commits, um assunto cada.** (a) [`8dbc978`] a fila na porta C++ (`mind_prompt.cpp`) com recusas
nomeadas e duas narrativas decodadas de pe na sonda — runner **296 / 0 / 37,480 s**;
(b) [`11d13bb`] a ponte no GDScript pela rota Variant crua, 55 nomes na tabela de imports do dll —
runner **296 / 0 / 37,689 s**; (c) [`e8301c0`] o gate (22 checagens, censo 296 → **318**) mais os dois
consertos que ele cobrou — runner **318 / 0 / 46,034 s**
([passo3_runner_commit_c.log:576](evidence/oraculo-nativo-22/passo3_runner_commit_c.log)). As quatro
corridas do fecho na ponta [`e8301c0`]: suíte **255 / 0 / 49,7 s**, runner **318 / 0 / 44,153 s**
(`68/68` testes, `trips=0`),
[RNG](evidence/oraculo-nativo-22/passo3_gates_rng.log) **27 / 0 / 2,734 s** e
[journal](evidence/oraculo-nativo-22/passo3_gates_journal.log) **128 / 0 / 6,720 s** (`7/7 testes
concluidos`), todas com `.err` limpo e zero `SCRIPT ERROR`.

**O que o gate compara, e o que decide cada forma** — as 22 checagens imprimem o número
([passo3_runner_commit_c.log:548-569](evidence/oraculo-nativo-22/passo3_runner_commit_c.log)): os seis
mesmos nomes de chave com `status=0 tokens_out=64` (`textos=143/144 chars`); recusas nomeadas nas duas
transportas (`-2` por tipo, `-4` por papel); timeout preservando o slot (`status=1
reason='timeout de 1 ms' depth=1`, e o pedido completa no wait seguinte); os três sinais de §5.3 na
ClassDB; métricas honestas (`depth=0 hits=0 misses=2 worst_decode_us=1510272` — cache **não existe** no
Passo 3); desmanche pelo **pid exato** do lançamento (`pid=27352 derrubado=true reuso=false`). A
emissão do sinal segue **`[ABERTA]`** (`emissoes=0 decodes=2`): quem emite é o Passo 4/5.

**O sinal 11 fechou na causa, com o repro pagando a atribuição.** O getter por chave e o por índice da
engine **atribuem** no destino (semântica de `operator=`, lê o `type` antes de copiar): storage cru de
stack sem inicializar com lixo de tipo que carrega ponteiro = wild `clear()` = corrupção de heap. O
conserto é o protocolo de teardown completo em
[`register_types.cpp`](../native/af_mind/src/register_types.cpp) — `variant_destroy` carregado e
null-checked, `inicia_varianto` (NIL válido antes da primeira escrita) e `destroi_varianto` (destrutor
real + NIL de novo) em todo storage cru — e fechou de quebra a classe de vazamento de `String` de
argumento/retorno. A prova é o par arquivado: o
[repro v3](evidence/oraculo-nativo-22/passo3_minrepro3.log) sob a pressão do gate (churn entre os
enqueues) sai **exit 0** com dez enqueues e dois decodes reais, e o runner com o gate sai 318/0 onde as
duas primeiras corridas caíam.

**A segunda grandeza que o repro achou antes do gate:** `tokens_out` chegava com o decode certo e o
número errado — o construtor de INT lê um **int64 inteiro** do ponteiro, e o `int32_t` deixava lixo de
stack na metade alta (`3066606649375` medido na depuração; a largura errada está nomeada no comentário
do próprio código). Depois do conserto (`int64_t tokens_out64`), a régua do repro devolve inteiros
limpos — `tokens_out=31` e `26`
([passo3_minrepro3.log:15-16](evidence/oraculo-nativo-22/passo3_minrepro3.log)). A regra que a perna
deixa: **toda grandeza que cruza a ponte entra como int64 de largura escrita**, não como o `sizeof` de
quem passa.

**Réguas e citações no ponto fixo** — a régua de âncoras abriu **4 casos** na primeira captura
([passo3_ruler_anchors.err](evidence/oraculo-nativo-22/passo3_ruler_anchors.err)), todos do runner que
cresceu +455 linhas: dois ponteiros do `estouro de subtree` (3122-3123 → **3155-3156**, no status e na
página 10), o `:281` da fixture da página 02 (**→ 310**) e o `EXPECTED_CHECKS` do status (65 → **72**)
— re-derivados um a um contra o conteúdo, re-rodados com **`casos objetivos: 0`** em 39 arquivos ·
3 079 ponteiros · 209 rótulos
([passo3_ruler_anchors.log](evidence/oraculo-nativo-22/passo3_ruler_anchors.log));
[plan_cites](evidence/oraculo-nativo-22/passo3_ruler_cites.log) com **1 041** citações conferidas, 10
arquivos citados que não existem (os de sempre — rascunhos e peças `[TARGET]` declaradas) e **0**
números fora do arquivo; [plan_ids](evidence/oraculo-nativo-22/passo3_ruler_ids.log) exit 0 com as
ausências de sempre.

### O que a rodada deixa aberto

Nenhum gate de fase (mandato 4). Dentro da perna faltam o **Passo 4** (`mind_oracle.gd` vira wrapper e
`grep -rn HTTPRequest src` devolve vazio) e o **Passo 5** (cache, validador e a régua do budget); a
ponte existe, **nenhum consumidor do jogo a lê ainda**, e `mind_oracle.gd` continua HTTP.
`git diff --name-only main...HEAD -- src` devolve **vazio** e `Channel.COUNT`, `FORMAT_VERSION`,
`GEN_VERSION` ficam parados — nenhum hash publicado é invalidado. Dos furos, **#38** (clone sem build)
e **#39** (réguas cegas a `native/`) seguem como decisão do dono, o **#20** sem a colheita que nomeia a
folha, e a alocação do caminho quente segue sem colheita própria. A fila serializada não muda:
**22 → 17 → 18 → 20 → 13**.

## O pouso do Passo 3 na `main` — o `src` parado provado por diff contra a main, a suíte da mergida que parseia antes de correr sem re-import, e o pin com o `build.bat` rodando dentro do clone (2026-11-24, `docs/registro-pouso-passo3-22`, base `3989217`, ponta `4a68174`, merge `7262d7e`)

### O que o merge toca, com o número em cada árvore

O merge `--no-ff` tem pais **`3989217`** (a `main` com o pouso da perna 23) e **`4a68174`** (a ponta da
branch deste passo) e fecha em **`7262d7e`** — **51 arquivos, +30 333/−56**. Duas frentes paralelas
escreveram na mesma janela (a 23 e este passo), e o merge veio com conflito em **dois** documentos, os
dois da mesma forma: o fim do `melhorias-status.md` (as duas seções novas juntas) e a
[`docs/planos/02-censo-multi-semente.md`](planos/02-censo-multi-semente.md), onde **os dois lados
consertaram a mesma âncora velha contra árvores diferentes**. A resolução foi por conteúdo, não por
lado: a página 02 ficou com **os dois** consertos verificados na árvore mergida — as âncoras do runner
desta perna (`285-317`/`:310`) **e** a da derivação da população que a 23 re-derivou
(`src/main.gd:835-836`) — e o status ficou com a seção do pouso da 23 seguida da Rodada (8) deste
passo, na ordem em que pousaram.

A prova de que este merge não move código vem por árvore, não por promessa: `git rev-parse 7262d7e:src`
= `3c436fb6d6f3392b36f054ed36a5e0846b8c74b4`, `:tests` = `7b2d2f1d2fe49c8ce0bb55b99bc659cdb095cfd3`, e
`git diff --name-only 3989217 7262d7e -- src` devolve **vazio** — contra a `main`, o merge não trouxe
nenhuma linha de `src`; os 6 arquivos de `src` que diferem da ponta da branch
(`git diff 4a68174 7262d7e -- src`) são **exatamente** os da água que a perna 23 pousou na `main` antes
deste merge, não nada deste passo.

### O vermelho nascido no pouso: a suíte da mergida parseia antes de correr

A primeira suíte na árvore mergida **nem abriu a cena**: 16 `SCRIPT ERROR` de parse —
`WaterSurface` não declarado na [:1](evidence/registro-pouso-passo3-22/main_mergida_suite_pre_import.err#L1)
e `WaterFx` na [:9](evidence/registro-pouso-passo3-22/main_mergida_suite_pre_import.err#L9), fechando
com `Failed to load script "res://tests/smoke_test.gd"` na
[:33](evidence/registro-pouso-passo3-22/main_mergida_suite_pre_import.err#L33). O motivo é o mesmo da
classe "clone precisa `--import`": o cache global de classes (`.godot/`) era da árvore **pré-merge**, o
merge trouxe as duas `class_name` novas da perna 23, e o parse do `smoke_test.gd` resolve `class_name`
pelo cache — que só o import reconstrói. O par vermelho fica arquivado
([`.log`](evidence/registro-pouso-passo3-22/main_mergida_suite_pre_import.log) de 2 linhas — só o
cabeçalho da engine; todo o conteúdo foi para o `.err` de 34 linhas). Duas consequências escritas: a
regra do clone vale também para a **árvore de trabalho** depois de um merge que traz `class_name`
novo — import antes de qualquer corrida; e a corrida vermelha desse formato **fica viva headless para
sempre** (a cena não abre, nada chama `quit()`, o orfão queima núcleo) — os dois processos desta
tentativa só saíram por `taskkill` do dono do probe, com o comando de cada um provando que eram da
leg.

### As quatro corridas da árvore mergida, com a máquina livre

- Suíte: [`main_mergida_suite.log`](evidence/registro-pouso-passo3-22/main_mergida_suite.log) linha
  **378** `== 264 checagens  0 falhas  54.7 s de teste ==`, exit 0 — censo **255 + as 9 da água** da
  perna 23; o `.err` de 4 linhas é o par de vazamento conhecido do quit.
- Runner:
  [`main_mergida_runner.log`](evidence/registro-pouso-passo3-22/main_mergida_runner.log) — as cinco
  `OK extensao_carrega_classe` em **535-539**, o pack em **544** com `load_ms=1937` e RSS
  `176 754 688 → 3 558 457 344` B, o gate do contrato em **564**
  (`emissoes=0 decodes=2`) e **569** (`pid=8008 derrubado=true reuso=false`), `trips_solo=0
  trips_matilha=0` em **572**, cenário estreito em **574** (`passos=10568 sim_step total=2 316 362 µs
  pico=4 762 µs`), matilha em **575** (`passos=1341 sim_tick total=3 253 271 µs pico=16 469 µs`), e
  **576** `318 checagens 0 falhas 44.332 s`; exit 0.
- RNG: **27 checagens 0 falhas 2.755 s**. Journal: **128 checagens 0 falhas 7/7 testes concluidos
  5.930 s**.

### O pin: clone limpo de `7262d7e`, com o `build.bat` rodando dentro dele

`git clone` do repositório local, HEAD `7262d7e…`. O `--import` frio sai exit 0 com o **furo #38**
impresso na mesma forma de sempre — 602 bytes de `.err` com os dois pares `FileAccess::exists` +
`GDExtension dynamic library not found: 'res://native/af_mind/af_mind.gdextension'`
([clone_limpo_import.err](evidence/registro-pouso-passo3-22/clone_limpo_import.err), a ordem honesta é
import → build → runner). O `git status --short` do clone **depois** do import devolve **seis** linhas
`??` — as duas do furo #25 (`tests/audio_test.gd.uid`, `tests/audio_live_probe.gd.uid`) e **quatro
novas**: `caixa-23-t1.png.import`, `caixa-23-t2.png.import`, `caixa-base-t1.png.import`,
`caixa-base-t2.png.import`. É um **furo #45** da mesma classe do #25: a perna 23 commitou os quatro
PNGs da água **sem** os `.png.import` versionados, então todo clone limpo gera os sidecars no import e
os imprime como lixo não-rastreado; nenhum problema de execução — as cenas os referenciam por `path`,
não por `uid://` — e este pouso **não os comita**. Dono: arrumação do dono do repositório.

`build.bat` no clone
([clone_limpo_build.log](evidence/registro-pouso-passo3-22/clone_limpo_build.log), exit 0): a sonda de
pé roda a rota do prompt completa antes de qualquer jogo (`[prompt] veredito=ROTA_DE_PROMPT_CONFIRMADA`
em **239**, `[corrida] probe_rota_codigo=0` em **240**), a ponte linka (`[ponte] link_codigo=0` em
**242**), o dll sai com **184 320 B** e `export= 1 00002FD0 af_mind_entry` (**244**) e a régua de
imports lê **55/55** — `[import] OK referenciados=55 modulos=4 nomes_na_tabela=55` (**256**), a tabela
nova do Passo 3 confirmada inteira dentro do clone. O dll do passo 2 (b) tinha **165 376 B**: a API do
prompt cresceu a extensão em **~19 KB**. O `.err` de 184 224 bytes é o chatter dos backends de
terceiro no stderr da build — o mesmo tamanho byte a byte do `.err` do pouso do passo 2 (b).

Os dois recursos que a checagem resolve pelo diretório do projeto são gitignored e o clone nasce sem
eles **por design**; o provisionamento desta medição é **junção** (`.tools\llama` apontando para a
árvore de trabalho) mais **hardlink** do `.gguf` de 2 740 937 888 B — ambiente de máquina, não mudança
de árvore.

- Runner no clone:
  [`clone_limpo_runner.log`](evidence/registro-pouso-passo3-22/clone_limpo_runner.log) — as cinco
  `OK extensao_carrega_classe` nas mesmas linhas **535-539**, os recursos no disco com os **caminhos do
  clone** impressos em **540** (`C:/aetherfall_pin_pouso3/.tools/llama/runtime llama_dll=true`) e
  **541** (`bytes=2740937888`), o pack em **544** com `load_ms=1922` e RSS
  `177 131 520 → 3 558 600 704` B, o gate do contrato em **564** (`emissoes=0 decodes=2`) e **569**
  (`pid=28588 derrubado=true reuso=false`) — a dupla HTTP × extensão corre inteira **dentro do
  clone**, com o `llama-server` subindo da junção —, `trips_solo=0 trips_matilha=0` em **572**,
  estreito em **574** (`sim_step total=2 421 221 µs pico=4 857 µs`), matilha em **575**
  (`sim_tick total=3 449 678 µs pico=16 228 µs`), e **576** `318 checagens 0 falhas 51.776 s`; exit 0.
- Suíte no clone:
  [`clone_limpo_suite.log`](evidence/registro-pouso-passo3-22/clone_limpo_suite.log) linha **378**
  `== 264 checagens  0 falhas  53.5 s de teste ==`, exit 0, zero `SCRIPT ERROR`.
- RNG e journal não rodaram no clone — o que o clone renova aqui é a suíte e o runner com a ponte e o
  gate novos; o journal tem a árvore `src` parada como garantia.

O número pineado para `7262d7e` é: runner **318 / 0** (44,332 s na mergida; **51,776 s** no clone),
suíte **264 / 0** (54,7 s; **53,5 s**), RNG **27 / 0 / 2,755 s** e journal **128 / 0 / 5,930 s** — as
duas últimas só na mergida.

### As três réguas no ponto fixo desta passada

- Âncoras ([pouso_ruler_doc_anchors.log](evidence/registro-pouso-passo3-22/pouso_ruler_doc_anchors.log)):
  **40 arquivos · 3 164 ponteiros · 209 rótulos · 3 587 links relativos**, `casos objetivos: 0`.
- Citações
  ([pouso_ruler_plan_cites.log](evidence/registro-pouso-passo3-22/pouso_ruler_plan_cites.log), exit 0):
  `numeros de linha fora do arquivo: 0`, com **11** arquivos citados inexistentes — os **10** da
  passada (d) conferidos um a um como pauta declarada, mais **um** que entrou no corpus com o merge:
  `src/entities/falling_block.gd`, citado pela prosa da perna 23 em
  [melhorias-status.md:7865](melhorias-status.md#L7865) e
  [:7868](melhorias-status.md#L7868) (a própria seção dela sobre a régua cega a arquivo futuro), mesma
  classe de pauta declarada pelo dossiê 17.
- IDs ([pouso_ruler_plan_ids.log](evidence/registro-pouso-passo3-22/pouso_ruler_plan_ids.log)): as
  listas `AUSENTES` dos dois documentos seguem sendo as peças que os próprios dossiês declaram
  inexistentes — pauta dos passos 4/5, dos dossiês 17/18/20/13 e dos nomes medidos que vivem só em
  `native/`, que a régua não alcança (furo #39).

### O que o pouso deixa aberto

Nenhum gate de fase (mandato 4). Dentro da perna 22 continuam o **Passo 4** (`transporte_http_zerado`:
`mind_oracle.gd` vira wrapper e `grep -rn HTTPRequest src` devolve vazio) e o **Passo 5** (cache,
`BeliefVerifier` e a régua do budget) — a ponte do Passo 3 está na `main` e **nenhum consumidor do
jogo a lê ainda**. Dos furos, **#38** (o import continua reclamando antes do build) e **#39** (réguas
cegas a `native/`) seguem como decisão do dono; o **#20** sem a colheita que nomeia a folha; o **#31**
sem atribuição; o **#41** como furo da contagem de malha; o **#44** fica onde a 23 o deixou; o **#45**
é novo e não tem conserto nesta perna. `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a projeção
do `TickJournal` não foram tocados. A fila serializada não muda: **22 → 17 → 18 → 20 → 13**.

## Rodada 2026-11-24 (9) — Passo 4 do dossiê 22: o transporte HTTP sai de `src`, o pack ganha dono no processo, e o gate varre a árvore (branch `feat/oraculo-nativo-passo4-22`, base `74820e7`, gate `ba8ee22`, ponta `5138549`)

**O gate foi nomeado antes de qualquer linha (mandato 4)** e nasceu vermelho no commit (a)
`ba8ee22`: `transporte_http_zerado` são **duas** checagens no runner — a varredura recursiva de
`src/` por `HTTPRequest` (32 arquivos lidos) e a dos lançadores (`Rodar.bat` e `tools/run_game.ps1`
sem citação de llama). O vermelho tem testemunha arquivada:
[passo4_runner_gate_vermelho.log:572](evidence/oraculo-nativo-passo4-22/passo4_runner_gate_vermelho.log#L572)
imprime as **9 ocorrências nos 2 arquivos** (`llm_server_host.gd:87/:99` e `mind_oracle.gd` em seis
linhas), veredicto **320 checagens 1 falhas 43,384 s** em
[:580](evidence/oraculo-nativo-passo4-22/passo4_runner_gate_vermelho.log#L580); a checagem dos
lançadores já passava **no vermelho** — eles nunca citaram llama, porque quem subia o processo era o
`llm_server_host.gd` dentro do jogo, não o launcher.

**O que o commit (b) `5138549` entrega.** `mind_oracle.gd` (§5.4) é wrapper da ponte: o nó de
requisição é `_ext.enqueue` ([mind_oracle.gd:270](../src/ai/mind_oracle.gd#L270)) e o
`wait(id, 0)` por frame ([:288](../src/ai/mind_oracle.gd#L288)) — timeout zero, consulta não
bloqueante, status 1 preserva o slot, nenhum `await` pendura os 50 ms do tick. O `LOADING_COOLDOWN`
do `503` **morreu com o transporte**: a espera pelo modelo é o portão `ready_provider`, ligado ao
`AfMindRuntime.ready()` ([af_mind_runtime.gd:68](../src/ai/af_mind_runtime.gd#L68)) em
[main.gd:289](../src/main.gd#L289); o recuo cheio de 30 s fica
([`RETRY_COOLDOWN` :36](../src/ai/mind_oracle.gd#L36)), e a chave externa também — `KEY_ENV`/`KEY_FILE`
([:43](../src/ai/mind_oracle.gd#L43), §2.1: quem sobe um `llama-server` na mão lê as mesmas fontes).
A narrativa continua sendo a única saída: gravada em
([:196](../src/ai/mind_oracle.gd#L196)), lida por `narration_of()`
([:164-165](../src/ai/mind_oracle.gd#L164-L165)); num clone sem o dll gitignored, `_ext` nasce
null e cada pedido nomeia a ausência. `src/ai/af_mind_runtime.gd` (§6.3, novo) é o dono do ciclo do
pack sobre disco e ClassDB: estados da matriz de falha nomeados ([:21](../src/ai/af_mind_runtime.gd#L21)
em diante), `STEP_PERIOD = 1.0` — um passo por frame para o F3 acompanhar
([:32](../src/ai/af_mind_runtime.gd#L32)). Com ele **saiem da árvore** `llm_server_host.gd` (433
linhas) e, com o transporte, morrem o processo filho, a sonda de porta, o vigia e os dois kills; a
sonda da perna 15 (`tests/llm_server_boot_probe`) aposenta junto. A fiação em `main.gd`:
`llm_host` agora é `AfMindRuntime` ([main.gd:55](../src/main.gd#L55)), o `diagnostics()` mantém a
chave `"llm"` ([main.gd:1273](../src/main.gd#L1273)) e o F3 lê a linha de status por
`llm_status_provider` ([main.gd:291](../src/main.gd#L291)), que imprime o `last_reason` do oráculo
([af_mind_runtime.gd:85-86](../src/ai/af_mind_runtime.gd#L85-L86)) — leitura, nenhuma escrita. A
metade HTTP do gate `contrato_igal_ao_http` virou **cliente de referência dentro do runner**: as 17
ocorrências de `HTTPRequest` que sobram vivem em `tests/aether_reactions_test.gd`, e o grep do gate
mira só `src/`.

**O custo que o passo assume e não esconde:** o `load_pack` do gguf é chamada síncrona da extensão e
o frame que a executa trava o tempo do load — o `open_ms` que a ponte mede
([af_mind_runtime.gd:171](../src/ai/af_mind_runtime.gd#L171)); o overlap que o processo filho dava
com a geração **acabou**. É o **furo #46**, aberto nesta rodada com o número na mesa e sem conserto
nela.

**Os quatro instrumentos, na ponta `5138549`** (evidência em
[docs/evidence/oraculo-nativo-passo4-22/](evidence/oraculo-nativo-passo4-22/)): suíte
**264 checagens / 0 falhas / 52,5 s**
([passo4_suite.log:380](evidence/oraculo-nativo-passo4-22/passo4_suite.log#L380)); runner
**320 / 0 / 42,770 s** com as duas linhas `OK transporte_http_zerado` — grep vazio
(`arquivos_lidos=32 ocorrencias=0`) e lançadores sem llama — em
([:572-573](evidence/oraculo-nativo-passo4-22/passo4_runner_verde.log#L572-L573)) e veredicto em
[:580](evidence/oraculo-nativo-passo4-22/passo4_runner_verde.log#L580); RNG **27 / 0 / 2,718 s**
([passo4_rng.log:80](evidence/oraculo-nativo-passo4-22/passo4_rng.log#L80)); journal
**128 / 0 / 5,843 s**, "7/7 testes concluidos"
([passo4_journal.log:145](evidence/oraculo-nativo-passo4-22/passo4_journal.log#L145)). No smoke, as
checagens do degradado foram renomeadas para a ponte: "runtime sem pack nao emite chamada na ponte"
([smoke_test.gd:3119](../tests/smoke_test.gd#L3119)) e as duas da recusa nomeada
([:3154-3157](../tests/smoke_test.gd#L3154-L3157)).

**O que a rodada deixa aberto.** Dentro da perna falta o **Passo 5** (cache §5.5, validador e a
régua do budget), cada peça com gate próprio. O `src/` **se move** nesta rodada — é a primeira
perna da 22 que escreve em `src/` — então a árvore resultante é outra revisão: os números acima valem
para a ponta `5138549`, e o pouso re-mede na mergida e no clone limpo (mandato 3, item 6).
`Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a projeção do `TickJournal` não foram tocados.
Dos furos, **#38** (o import continua reclamando antes do build) e **#39** (réguas cegas a
`native/`) seguem como decisão do dono; o **#20** sem a colheita que nomeia a folha; o **#31** sem
atribuição; o **#41** como furo da contagem de malha; o **#44** fica onde a 23 o deixou; o **#45**
é arrumação do dono; o **#46** é novo e não tem conserto nesta perna. A fila serializada não muda:
**22 → 17 → 18 → 20 → 13**.


## O pouso do Passo 4 na `main` — o primeiro pouso da perna que move `src`, o `llama-server` sobrevive só como cliente de referência do runner, e as quatro corridas da mergida saem limpas desde o primeiro import (2026-11-24, `docs/registro-pouso-passo4-22`, base `74820e7`, ponta `96e4abe`, merge `d71385f`)

### O que o merge toca — `src` se move pela primeira vez num pouso desta perna

O merge `--no-ff` tem pais **`74820e7`** (a `main` com o pouso do Passo 3) e **`96e4abe`** (a ponta da
branch do Passo 4) e fecha em **`d71385f`** — **62 arquivos, +9 920/−1 737**. Os pousos do 2 (b) e do 3
provaram `src` parado por diff; este é o primeiro que move: `git diff --name-only 74820e7 d71385f -- src`
devolve **exatamente seis** entradas —
[`src/ai/af_mind_runtime.gd`](../src/ai/af_mind_runtime.gd) (novo, com o `.uid`),
`src/ai/llm_server_host.gd` (apagado, com o `.uid` — o hospedeiro de
processo da perna 15 sai da árvore),
[`src/ai/mind_oracle.gd`](../src/ai/mind_oracle.gd) (reescrito como wrapper da ponte) e
[`src/main.gd`](../src/main.gd) (anexa o `AfMindRuntime`, liga `ready_provider` e publica `llm` no
`diagnostics()`). As árvores do pin: `git rev-parse d71385f:src` =
`65b5d3904b81fcf377a01d66a5f5d48fda5f5b03`, `:tests` =
`f25ed2f1e6b0a49ff0e6fee31c0fcbcb2faed032`.

### As quatro corridas da árvore mergida — a regra do import aplicada antes da primeira

A lição do pouso do Passo 3 virou procedimento: o merge traz `class_name` novo
(`AfMindRuntime`), então `--import` correu **antes** de qualquer runner — e desta vez o
`.err` saiu **0 bytes**, sem nenhuma queixa de cache
([`main_mergida_import.log`](evidence/registro-pouso-passo4-22/main_mergida_import.log), exit 0).

- Suíte:
  [`main_mergida_suite.log`](evidence/registro-pouso-passo4-22/main_mergida_suite.log) linha
  **378** `== 264 checagens  0 falhas  52.6 s de teste ==`, exit 0; o `.err` de **249 bytes** é o
  par de vazamento benigno do quit, o mesmo tamanho das corridas anteriores.
- Runner:
  [`main_mergida_runner.log`](evidence/registro-pouso-passo4-22/main_mergida_runner.log) — o gate novo
  fecha em **570** (`grep -rn HTTPRequest src devolve vazio | arquivos_lidos=32 ocorrencias=0 (vazio)`)
  e **571** (`os lancadores nao citam llama` com os dois `true`). O gate de contrato segue exercendo
  **as duas transportas dentro do runner**: o `llama-server` continua existindo em `tests/` — mas só
  como **cliente de referência** levantado pelo próprio runner (`pid=25508` em **550**,
  `/health 200` em **551**, desmanche pelo pid exato em **566** com `derrubado=true reuso=false`) —
  porque é ele que dá a forma contra a qual a extensão é comparada (`GATE do sucesso` em **565**,
  `textos=142/143 chars`); do lado da extensão, o wait de sucesso com as 6 chaves tipadas em **561**
  e o timeout com slot preservado em **562**. `trips_solo=0 trips_matilha=0` em **574**; matilha em
  **577** (`passos=1341 sim_tick total=3 215 934 µs pico=18 175 µs; BT last_us soma=56 681 pico=194
  trips=0`); e **578** `320 checagens 0 falhas 42.891 s`; exit 0, zero `SCRIPT ERROR`.
- RNG:
  [`main_mergida_rng.log`](evidence/registro-pouso-passo4-22/main_mergida_rng.log) linha **78**
  `27 checagens 0 falhas 2.689 s`.
- Journal:
  [`main_mergida_journal.log`](evidence/registro-pouso-passo4-22/main_mergida_journal.log) linha
  **143** `128 checagens 0 falhas 7/7 testes concluidos 5.808 s`.

### O pin: clone limpo de `d71385f`, com o `build.bat` rodando dentro dele

`git clone` do repositório local, HEAD `d71385f…`. O `--import` frio sai exit 0 com o **furo #38**
impresso na mesma forma de sempre — `.err` de **602 bytes**, byte a byte o mesmo tamanho do `.err`
do pin do Passo 3, com os dois pares `FileAccess::exists` +
`GDExtension dynamic library not found: 'res://native/af_mind/af_mind.gdextension'`
([`pin_import.err`](evidence/registro-pouso-passo4-22/pin_import.err); a ordem honesta é
import → build → runner). O `git status --short` do clone **depois** do import devolve **seis** linhas
`??` — as duas do furo #25 (`tests/audio_test.gd.uid`, `tests/audio_live_probe.gd.uid`) e as quatro do
furo #45 (os `.png.import` da água) — e este pouso **não as comita**.

`build.bat` no clone
([`pin_build.log`](evidence/registro-pouso-passo4-22/pin_build.log), exit 0): a régua do cabeçalho
nomeia vcvars e toolset na linha **2** (`toolset=14.44.35207`, `cl_banner` **19.44.35228** na linha
**4** — o conserto do furo #34 rodando dentro do clone), o probe da rota de prompt fecha
`ROTA_DE_PROMPT_CONFIRMADA` em **2293** com `probe_rota_codigo=0` em **2294**, a ponte linka
(`[ponte] link_codigo=0` em **2296**), o dll sai com **184 320 B** em **2297** e
`af_mind_entry` em **2298**, e a régua de imports lê **55/55** em **2310**
(`[import] OK referenciados=55 modulos=4 nomes_na_tabela=55`) antes do `[ok]` em **2312**. Mesmo
tamanho de dll e mesma tabela do pin do Passo 3 — a branch do Passo 4 não tocou `native/`, e a régua
do build prova por bytes, não por frase.

Os dois recursos que a checagem resolve pelo diretório do projeto são gitignored e o clone nasce sem
eles **por design**; o provisionamento desta medição é **junção** (`.tools\llama` apontando para a
árvore de trabalho) mais **hardlink** do `.gguf` de 2 740 937 888 B (2 links) — ambiente de máquina,
não mudança de árvore.

- Runner no clone:
  [`pin_runner.log`](evidence/registro-pouso-passo4-22/pin_runner.log) — o gate novo fecha nas mesmas
  linhas **570/571**, as duas transportas correm inteiras **dentro do clone** (`pid=17624` em **550**,
  desmanche em **566** com `derrubado=true reuso=false`), `trips_solo=0 trips_matilha=0` em **574**,
  matilha em **577** (`passos=1341 sim_tick total=3 267 124 µs pico=14 950 µs; BT last_us soma=58 102
  pico=270 trips=0`), e **578** `320 checagens 0 falhas 49.107 s`; exit 0, zero `SCRIPT ERROR`.
- Suíte no clone:
  [`pin_suite.log`](evidence/registro-pouso-passo4-22/pin_suite.log) linha **378**
  `== 264 checagens  0 falhas  52.3 s de teste ==`, exit 0, zero `SCRIPT ERROR`.
- RNG e journal ficam nas quatro corridas da mergida: o que o clone renova aqui é o par que exerce o
  jogo real e o gate novo — suíte + runner.

O número pineado para `d71385f` é: runner **320 / 0** (42,891 s na mergida; **49,107 s** no clone),
suíte **264 / 0** (52,6 s; **52,3 s**), RNG **27 / 0 / 2,689 s** e journal **128 / 0 / 5,808 s** — as
duas últimas só na mergida.

### O que o pouso deixa aberto

Nenhum gate de fase (mandato 4). Dentro da perna 22 a fila viva é o **Passo 5** (cache §5.5,
validador de crença, régua do budget), que é também o dono do **furo #46** — o `load_pack` é uma
chamada síncrona da extensão e o frame que o roda trava o tempo do load, sem mais o overlap que o
processo filho dava com a geração. O `llama-server` do jogo morreu com o transporte: o que sobrou
dele em `tests/` é o cliente de referência do contrato, o único lugar onde o nome dele ainda sobe em
processo vivo. Dos furos, **#38** (o import continua reclamando antes do build) e **#39** (réguas
cegas a `native/`) seguem como decisão do dono; o **#20** sem a colheita que nomeia a folha; o **#31**
sem atribuição; o **#41** como furo da contagem de malha; o **#44** fica onde a 23 o deixou; o **#45**
é arrumação do dono. `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a projeção do `TickJournal`
não foram tocados por este pouso. A fila serializada não muda: **22 → 17 → 18 → 20 → 13**.


## Rodada 2026-11-24 (10) — Passo 5 do dossiê 22: a cache de conteúdo devolve a frase sem modelo, o portão do verificador checa o que a mente propõe, e a régua do budget mediu antes de cortar (branch `feat/oraculo-nativo-passo5-22`, base `eb218fe`, vermelho `e7e2d59`, ponta `1b5ff5f`)

O que o passo entrega, na ordem dos commits: **`e7e2d59`** — os dois gates de abertura nascem
vermelhos na mesma corrida (runner **331 checagens 3 falhas 49,079 s**; a cache não existe com
`existe=false` impresso, a segunda semente paga decode de novo com `pedidos_b=1`, o verificador
nomeado não está em `src/ai`; suíte 264/0/52,7 s) e a régua do budget **mede no vermelho**, antes de
qualquer corte — `worst_sim_ms=12.75 ms pico=12 750 µs` com o decode em voo dentro da malha de
1 400 passos. **`5b06f51`** — `af_cache_determina_replay` fecha verde (runner 332/1; a falha
restante é a do verificador, que fecha no commit seguinte): chave de conteúdo
`prompt|pack|max_tokens|temperature` estável entre corridas (`315/315 chars iguais=true`), instância
fresca lendo do arquivo separado do save pela chave reconstruída de fora (`lida=143 chars`), segunda
semente com `pedidos_b=0 acertos_cache=1` — zero consultas à fila é a diferença entre "o modelo
responde igual" e "a cache responde sem modelo". Cache **opt-in** via `--oracle-cache=`, JSON com
versão e recusa nomeada; narrativa recusada ou vazia nunca entra. **`824445e`** —
`verifier_recusa_id_forjado` fecha verde: o portão único `MindOracle.aceitar_saida` recusa a saída
que cita id inexistente na alcateia com o motivo nomeado, o controle entra pelo mesmo portão, fail
closed com roster vazio; a régua do budget re-mede com o portão no caminho
(`worst_sim_ms=13.09 ms trips=0→0`; runner **336/0/48,429 s**). **`e8c41f5`** — o `.uid` do
`oracle_cache.gd` versionado (mesma classe do furo #25: um clone re-derivaria uid diferente do
histórico). **`1b5ff5f`** — as métricas do §2.4 no F3: a linha de pronto ganha
`fila/decode/cache` lidos da ponte com `-1` como ausente **nomeado** sem ponte, e o
`diagnostics()` expõe as quatro chaves; suíte **266/0/52,7 s** (264 + 2), runner
**336/0/47,970 s**, RNG **27/0/2,708 s**, journal **128/0/5,766 s**, zero `SCRIPT ERROR` nas quatro.

Evidência em [`docs/evidence/oraculo-nativo-passo5-22/`](evidence/oraculo-nativo-passo5-22/) — os
doze logs dos três estágios (vermelho/cache/verifier, runner × suíte) mais os quatro da ponta com o
F3. O §19 do [dossiê 22](planos/22-oraculo-nativo-gdextension.md) carrega a narrativa completa; o
**furo #46** foi avaliado e fica em pé com motivo nomeado (carga assíncrona da extensão é trabalho
da Fase 4, onde o governor precisa dela de qualquer forma). A re-derivação de citações vivas desta
rodada cobriu os **cinco documentos donos do bloco** (`AGENTS.md`, este status, o dossiê 22, o
índice dos planos e o README) — e fica registrado o que ela **não** cobriu: **27 documentos** fora
desse lote também citam os arquivos tocados (pautas 01–20 e 23, cinco docs de design e o
`simclock.md`). As pautas citam números pineados às suas próprias árvores de medição e os designs
descrevem alvo, mas a classe é a do **furo #28**: a régua não vê prosa cujo número-alvo continua
dentro do arquivo. O §2 do dossiê 22 foi tratado à mão por isso — pinado a `bb13752` (Fase 0) e
`5138549` (Passo 4) porque `mind_oracle.gd` mudou de forma sob a prosa dele. `Channel.COUNT`,
`FORMAT_VERSION`, `GEN_VERSION` e a projeção do `TickJournal` intocados. Nenhum gate de fase fecha.
A fila serializada não muda: **22 → 17 → 18 → 20 → 13**.

## O pouso do Passo 5 na `main` — a cache e o verificador chegam à Camada 5, as quatro corridas da mergida saem limpas desde o primeiro import e o build reproduz byte a byte dentro do clone (2026-11-25, `docs/registro-pouso-passo5-22`, base `eb218fe`, ponta `d14c066`, merge `1d3f36c`)

### O que o merge toca — duas classes novas na fronteira da Camada 5

O merge `--no-ff` tem pais **`eb218fe`** (a `main` com o registro do pouso do Passo 4) e
**`d14c066`** (a ponta da branch do Passo 5, com os 41 casos de âncora re-derivados) e fecha em
**`1d3f36c`** — **54 arquivos, +18 347/−122**. Em `src`, o diff toca **exatamente sete** entradas:
[`src/ai/oracle_cache.gd`](../src/ai/oracle_cache.gd) (novo, com o `.uid` — a cache de conteúdo,
dono do §6.5), [`src/ai/belief_verifier.gd`](../src/ai/belief_verifier.gd) (novo, com o `.uid` — o
portão da Camada 5, §6.4), [`src/ai/mind_oracle.gd`](../src/ai/mind_oracle.gd) (o `aceitar_saida`
como portão único e a escrita da cache), [`src/ai/af_mind_runtime.gd`](../src/ai/af_mind_runtime.gd)
(as métricas do §2.4 lidas da ponte) e [`src/main.gd`](../src/main.gd) (a linha do F3 ganha
`fila/decode/cache` e o `diagnostics()` publica as quatro chaves). As árvores do pin:
`git rev-parse 1d3f36c:src` = `827c7eeb810cff462ed02d77cf45d7bdfc19f50f`, `:tests` =
`c1efd81a19b2d8b7b6954124829c0bd41dbaeaed`.

### As quatro corridas da árvore mergida — o import antes de qualquer runner, de novo

O merge traz **duas** `class_name` novas (`OracleCache`, `BeliefVerifier`), então `--import` correu
antes de qualquer runner e o `.err` saiu **0 bytes**, exit 0
([`main_mergida_import.log`](evidence/registro-pouso-passo5-22/main_mergida_import.log)).

- Suíte:
  [`main_mergida_suite.log`](evidence/registro-pouso-passo5-22/main_mergida_suite.log) linha
  **380** `== 266 checagens  0 falhas  52.8 s de teste ==`, exit 0; o `.err` de **249 bytes** é o
  par de vazamento benigno do quit, o mesmo tamanho das corridas anteriores.
- Runner:
  [`main_mergida_runner.log`](evidence/registro-pouso-passo5-22/main_mergida_runner.log) — os dois
  gates do Passo 5 fecham nas linhas **572–578** (`af_cache_determina_replay`: a corrida A narra
  pelo wrapper com o modelo no processo `frase_a=143 chars pedidos=1`, chave de conteúdo estável
  `315/315 chars iguais=true`, cache em `user://oracle_cache_passo5.json` **separado do save**,
  instância fresca lendo do arquivo pela chave reconstruída de fora com
  `chave=4b4158c18aef447d lida=143 chars`, segunda semente com `pedidos_b=0 acertos_cache=1`) e
  **579–583** (`verifier_recusa_id_forjado`: o verificador nomeado existe em
  `res://src/ai/belief_verifier.gd`, o controle passa com `id_forjado=-1`, o id 999 sai recusado
  com o motivo nomeado, e o portão do wrapper recusa sem escrever narrativa — `narrativa=0 chars` —
  mas aceita o controle e escreve `narrativa=41 chars`). Rodapé do cenário estreito em **600**
  (`passos=10568 sim_step total=2 288 197 µs pico=4 202 µs`) e da matilha em **601**
  (`passos=1341 sim_tick total=3 302 184 µs pico=17 955 µs; BT last_us soma=57 470 pico=64
  trips=0`), e **602** `336 checagens 0 falhas 48.797 s`; exit 0, zero `SCRIPT ERROR`.
- RNG:
  [`main_mergida_rng.log`](evidence/registro-pouso-passo5-22/main_mergida_rng.log) linha **78**
  `27 checagens 0 falhas 2.712 s`.
- Journal:
  [`main_mergida_journal.log`](evidence/registro-pouso-passo5-22/main_mergida_journal.log) linha
  **143** `128 checagens 0 falhas 7/7 testes concluidos 5.903 s`.

### O pin: clone limpo de `1d3f36c`, com o `build.bat` rodando dentro dele

`git clone` do repositório local, HEAD `1d3f36c…`. O `--import` frio sai exit 0 com o **furo #38**
impresso na mesma forma de sempre — `.err` de **602 bytes**, byte a byte o mesmo tamanho do `.err`
do pin do Passo 4, com os dois pares `FileAccess::exists` +
`GDExtension dynamic library not found: 'res://native/af_mind/af_mind.gdextension'`
([`pin_import.err`](evidence/registro-pouso-passo5-22/pin_import.err); a ordem honesta é
import → build → runner). O `git status --short` do clone **depois** do import devolve **seis** linhas
`??` — as duas do furo #25 (`tests/audio_test.gd.uid`, `tests/audio_live_probe.gd.uid`) e as quatro do
furo #45 (os `.png.import` da água) — e este pouso **não as comita**.

`build.bat` no clone
([`pin_build.log`](evidence/registro-pouso-passo5-22/pin_build.log), exit 0, **2 312 linhas**): a
régua do cabeçalho nomeia vcvars e toolset na linha **2** (`toolset=14.44.35207`, `cl_banner`
**19.44.35228** na linha **4**), o probe da rota de prompt fecha `ROTA_DE_PROMPT_CONFIRMADA` em
**2293** com `probe_rota_codigo=0` em **2294**, a ponte linka (`[ponte] link_codigo=0` em **2296**),
o dll sai com **184 320 B** em **2297** (`[regua] dll_bytes=184320`) e `af_mind_entry` em **2298**,
e a régua de imports lê **55/55** em **2310** antes do `[ok]` em **2312**. Mesmo tamanho de dll,
mesma tabela e mesmo número de linhas do pin do Passo 4 — a branch do Passo 5 não tocou `native/`,
e a régua do build prova por bytes, não por frase.

Os dois recursos que a checagem resolve pelo diretório do projeto são gitignored e o clone nasce sem
eles **por design**; o provisionamento desta medição é **junção** (`.tools\llama` apontando para a
árvore de trabalho) mais **hardlink** do `.gguf` de 2 740 937 888 B (2 links confirmados dos dois
lados) — ambiente de máquina, não mudança de árvore.

- Runner no clone:
  [`pin_runner.log`](evidence/registro-pouso-passo5-22/pin_runner.log) — os dois gates do Passo 5
  fecham nas mesmas linhas **572–578** e **579–583**, com os caminhos do clone impressos dentro
  (`runtime=C:/tmp/aetherfall-pin-passo5/.tools/llama/runtime
  gguf=C:/tmp/aetherfall-pin-passo5/models/qwen3.5-4b-q4_k_m.gguf llama_dll=true`), rodapé do
  cenário estreito em **600** (`passos=10568 sim_step total=2 383 801 µs pico=4 735 µs`) e da
  matilha em **601** (`passos=1341 sim_tick total=3 253 750 µs pico=13 902 µs`), e **602**
  `336 checagens 0 falhas 56.279 s`; exit 0, zero `SCRIPT ERROR`.
- Suíte no clone:
  [`pin_suite.log`](evidence/registro-pouso-passo5-22/pin_suite.log) linha **380**
  `== 266 checagens  0 falhas  53.9 s de teste ==`, exit 0, zero `SCRIPT ERROR`.
- RNG e journal ficam nas quatro corridas da mergida: o que o clone renova aqui é o par que exerce o
  jogo real e os dois gates novos — suíte + runner.

O número pineado para `1d3f36c` é: runner **336 / 0** (48,797 s na mergida; **56,279 s** no clone),
suíte **266 / 0** (52,8 s; **53,9 s**), RNG **27 / 0 / 2,712 s** e journal **128 / 0 / 5,903 s** — as
duas últimas só na mergida.

### O que o pouso deixa aberto

Nenhum gate de fase (mandato 4). Dentro da perna 22, o **Passo 5 fechou o dele**: cache de conteúdo,
verificador de crença e a régua do budget medindo antes de cortar. A fila viva da perna é o que o
escopo de 2026-11-23 deixou como pauta com gate próprio — a **Fase 2** (memória de qualidade) é a
seguinte, e o **furo #46** (o `load_pack` síncrono trava o frame do load) continua dono da Fase 4,
onde o governor precisa dele de qualquer forma. Dos furos, **#38** (o import continua reclamando
antes do build) e **#39** (réguas cegas a `native/`) seguem como decisão do dono; o **#20** sem a
colheita que nomeia a folha; o **#31** sem atribuição; o **#41** como furo da contagem de malha; o
**#44** fica onde a 23 o deixou; o **#45** é arrumação do dono. `Channel.COUNT`,
`FORMAT_VERSION`, `GEN_VERSION` e a projeção do `TickJournal` não foram tocados por este pouso. A
fila serializada não muda: **22 → 17 → 18 → 20 → 13**.


## Abertura da Fase 2 do dossiê 23 — chuva e superfícies molhadas como código (2026-11-25, documento puro)

**Nenhuma linha de `src/` ou `tests/` foi escrita por esta rodada, e nenhum número dela é medição.** O
que existe é o corte (§3.10), o gate (§5.3) e a sonda (§5.4) da Fase 2 em
[`docs/planos/23-elevacao-visual-agua.md`](planos/23-elevacao-visual-agua.md), o registro com as quatro
frases que a leitura da árvore de abertura devolveu diferente no
[`AGENTS.md`](../AGENTS.md) ("Registro de 2026-11-25"), e as três linhas deste arquivo que apontam para
lá. Branch `feat/elevacao-visual-chuva-23f2`, base `eb218fe`, worktree `.qoder/worktrees/elevacao-chuva-23f2`
— a 22 continua em voo na árvore primária com trabalho não commitado em `native/af_mind/`, e é por isso
que a Fase 2 não abre ali.

**O que a leitura da base nomeia, e é o que o gate vai pagar** (derivação aritmética dos constantes, não
corrida — os números aparecem escritos assim para o vermelho nascer conferível):

- o canal do `COLOR` opaco que a Fase 2 usa é o **alfa**, constante `1.0` na base em
  `eb218fe:src/world/voxel_world.gd:689`, lido por ninguém porque
  `vertex_color_use_as_albedo` multiplica RGB
  (`eb218fe:src/world/voxel_world.gd:93`);
- o material opaco é um `StandardMaterial3D` de oito linhas
  (`eb218fe:src/world/voxel_world.gd:91-96`) e vira `ShaderMaterial` gerado em `.gd`
  — `git ls-files '*.gdshader'` dá **0** antes e **0** depois, então a cláusula do §3.1 (mais de um
  arquivo importado) **não** reabre, ao contrário do que o §3.9 dizia;
- o pool de anéis passa a ter **dois** compradores (`WaterFx._anel`,
  `eb218fe:src/rendering/water_fx.gd:299-310`), com origem e recusa contadas pela porta
  nova `ring_at()`; o orçamento de `RING_POOL` deixa de ser cota do salpico;
- a lista de uniformes do material da água, hoje `declarados=16  gravados=14` na linha literal do pouso
  da Fase 1, passa a **17/15** com o `chuva`, e os três lugares do repositório que citam os dois números
  são re-derivados no commit final;
- o clima entra por CLI `--weather=<alvo>` no mesmo laço que já lê `--tick-journal=`
  (`eb218fe:src/main.gd:1262-1269`) — sem input sintético, e sem nenhum caminho do FX para
  o mundo: a cláusula do dono continua sendo a mesma da Fase 1, e a testemunha dela é a checagem de
  não-escrita por coluna.

**#47 (novo, dono esta fase):** a sonda com janela produz recortes PNG **dentro** do projeto, que é
exatamente como o **#45** nasceu (os quatro `caixa-*.png` de
[`docs/evidence/elevacao-visual-agua-23/`](evidence/elevacao-visual-agua-23/) commitados sem
`.png.import`, todo clone limpo imprimindo `??` depois do `--import`). A pasta nova de evidência leva um
`.gdignore`, mecanismo que já tem número na casa: o `build.bat` da perna 22 escreve `bin/.gdignore` e o
`--import` que devolvia 464 B de stderr passou a devolver exit 0 com 0 bytes
(`docs/melhorias-status.md:6679-6682` acima). Isso demonstra o conserto **em uma pasta** e não fecha o #45, e a
régua do #45 foi relida nesta árvore: dos **29** PNGs e **1** SVG rastreados, **quatro** estão sem
sidecar e os quatro estão naquela pasta — `docs/evidence/fp-hand` tem **14** `.import` versionados,
`docs/media` **11**, `assets/` **51** e o `icon.svg` da raiz tem o dele. O débito é de quatro arquivos,
não de três pastas, e a arrumação neles continua sendo do dono do repositório.

**Consequência de versão, declarada agora:** `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a projeção
do `TickJournal` não são tocados, e a expectativa desta fase é que uma corrida com chuva **reproduza** os
hashes publicados — chuva visual não move `intent`, crenças, edições nem canais. Se o hash se mover, o
defeito é desta perna. Nenhum gate de fase se fecha aqui; a fila serializada não muda:
**22 → 17 → 18 → 20 → 13**.

## Rodada 2026-11-25 (2) — Fase 2 do dossiê 23 em código: um dono para `chuva`/`molhado`, o material
opaco virando shader, exposição de céu no alfa do vértice, e a banda de indiferença explicada por dois
instrumentos (branch `feat/elevacao-visual-chuva-23f2`, **worktree separado**, base `eb218fe`, ponta `78742d6`)

Esta rodada escreve a Fase 2 do dossiê 23 — a pauta que a abertura desta mesma página (§3.9 e o registro
de 2026-11-24) manteve como **pauta**, e que o dono mandou aplicar. Ela roda em
`C:/Aetherfall/.qoder/worktrees/elevacao-chuva-23f2`, **não** na árvore primária: a perna 22 tem
trabalho em voo em `native/af_mind/` e escreve `src/main.gd`, que é de escritor único. Nada aqui toca
aquela árvore.

### O que a perna toca, e a cláusula conferida contra o diff

`git diff --stat eb218fe..78742d6 -- src tests` → **11 arquivos, +1 281 / −17**:

| Arquivo | Linhas | O que é |
|---|---|---|
| [`src/rendering/weather.gd`](../src/rendering/weather.gd) | +120 (novo) | dono de `chuva`/`molhado`, integrate em `_physics_process` ([:62](../src/rendering/weather.gd#L62)), RNG **próprio** (`WEATHER_SEED = 20261123`, [:16](../src/rendering/weather.gd#L16)), sink por `Callable` |
| [`src/world/opaque_surface.gd`](../src/world/opaque_surface.gd) | +119 (novo) | o primeiro `ShaderMaterial` opaco do projeto: `diffuse_burley, specular_schlick_ggx`, `molhamento = molhado × COLOR.a` |
| [`src/rendering/rain_fx.gd`](../src/rendering/rain_fx.gd) | +201 (novo) | dois emissores, teto 748, anel de gota **pelo comprador** (`ring_sink` → `water_fx.ring_at`) |
| [`src/world/voxel_world.gd`](../src/world/voxel_world.gd) | +104/−? | `_scan_col_tops()` ([:655](../src/world/voxel_world.gd#L655)), `EXPOSURE_FALL = 4` ([:41](../src/world/voxel_world.gd#L41)), o alfa escrito no vértice ([:772](../src/world/voxel_world.gd#L772)), `_mat_opaque` ([:113](../src/world/voxel_world.gd#L113)) |
| [`src/world/water_surface.gd`](../src/world/water_surface.gd) | +49 | o uniforme `chuva` do §3.10e — a água lê o mesmo termômetro que escurece a pedra |
| [`src/rendering/water_fx.gd`](../src/rendering/water_fx.gd) | +63 | `ring_at()`: o pool de anéis passa a ter **dois** compradores, com origem e recusa contadas |
| [`src/main.gd`](../src/main.gd) | +60 | os três nós pendurados no boot ([:231-246](../src/main.gd#L231-L246)), `--weather=<alvo>` ([:1334](../src/main.gd#L1334)) e as duas linhas de `diagnostics()` ([:1265](../src/main.gd#L1265), [:1268](../src/main.gd#L1268)) |
| [`tests/smoke_test.gd`](../tests/smoke_test.gd) | +579 | os passos novos no `_steps` e as **onze** checagens |

A cláusula do dono — **"só visual"** — conferida contra o diff, não contra a frase:

```
$ git diff --name-only eb218fe..78742d6 -- src/ai src/items native src/entities/wolf.gd \
      src/world/block_defs.gd src/persistence
(vazio)
```

Árvores da ponta: `git rev-parse 78742d6:src` = `daf0da611408ac2ad0ef5ec20773e98e9d038163`,
`:tests` = `bdad323fb02a7868ea7f7781f66d37fbeccc7b63`.

### O censo por corrida: 264 → 274 → 275, e o que cada vermelho tinha de nome

Onze checagens novas, e o censo da suíte se move com elas em dois degraus — dez no gate, a décima
(`agua_le_a_chuva`) só existe quando o uniforme da água existe. Cada linha abaixo é a última linha do
log arquivado em
[`docs/evidence/elevacao-visual-chuva-23/`](evidence/elevacao-visual-chuva-23/), com a contagem de
`SHADER ERROR` e `SCRIPT ERROR` do próprio arquivo:

| Log | Corrida | Checagens | Falhas | `SHADER ERR` | `SCRIPT ERR` |
|---|---|---|---|---|---|
| `chuva23-controle-base.log` | base `eb218fe`, sem a perna | **264** | 2 | 0 | 0 |
| `chuva23-braco-300-quadros.log` | base, janela de 300 quadros | 264 | 3 | 0 | 0 |
| `chuva23-gate-vermelho.log` | as dez checagens nascendo vermelhas | **274** | **12** | 0 | 0 |
| `chuva23-codigo-a.log` | Weather + material opaco + exposição | 274 | 5 | **4** | 0 |
| `chuva23-rendermode-conserto.log` | idem, com `specular_schlick_ggx` | 274 | 5 | **0** | 0 |
| `chuva23-codigo-b.log` | RainFx, anel pelo comprador, orçamento, RNG | 274 | 2 | 0 | 0 |
| `chuva23-codigo-c-vermelho.log` | a água lendo a chuva, antes do uniforme | 275 | 3 | 0 | 0 |
| `chuva23-codigo-c.log` | idem, depois | **275** | 2 | 0 | 0 |
| `chuva23-codigo-c-sombra-4-erros.log` | a sombra do `blurry`, re-producida de propósito | 275 | 2 | **4** | 0 |
| `pin-suite.log` | clone limpo de `78742d6`, `--import` frio | **275** | 2 | 0 | 0 |

Os **dois** vermelhos que ficam são os da perna 22 e não desta: `portao aberto volta a pedir` e
`recusa da fila nomeia o motivo`, ambos com `motivo=extensao ausente: AfMindOracle nao esta na ClassDB
nesta arvore` ([`pin-suite.log:300,303`](evidence/elevacao-visual-chuva-23/pin-suite.log)). É o
**furo #38**, decisão do dono, e a testemunha é o controle: o mesmo binário roda a base e devolve os
mesmos dois. O que a Fase 2 **fechou** do gate vermelho foram dez (o gate imprimiu `-1`, `false` e
`sem_fonte=0` em cada uma delas, nunca um número emprestado), e o `codigo-c-vermelho` imprimiu um
onzeavo à parte: `agua_le_a_chuva chuva_no=1.000 uniforme_agua=-99.000 declarados=16 gravados=14` — o
`-99,000` é o "não há uniforme", e `16/14` é o par antigo provando que o `chuva` ainda não existia.

### As cinco derivações que a corrida derrubou

A tabela do §5.3 da página foi escrita **antes** da corrida, à mão, a partir das constantes nomeadas do
§3.10. Cinco números dela estavam errados, e os cinco estão publicados com o motivo ao lado do valor
medido (nada foi re-escrito em silêncio):

1. `material_opaco_e_shader` — derivado `declarados=6`, medido **`declarados=5 gravados=5`**: o sexto
   nome que eu contava era `METALLIC`, que é constante do shader, não uniforme.
2. `exposicao_nao_e_varredura_por_face` — derivado `chunks_lidos=64 col_lidas<=16384`, medido
   **`chunks_lidos=287 col_lidas=73472 esperado=73472`**: o 64 era o censo de chunks **do boot**, e a
   sessão inteira faz 287 rebuilds. A asserção estrutural verdadeira é `col_lidas == chunks_lidos ×
   256`, e ela é exata; o braço por face que ela descarta custa **6,24 leituras por coluna**.
3. `molhado_sobe_e_desce` — derivado `esperado=0,854`, medido **`esperado=0.855` com
   `desceu=0.855 material=0.855`**: `1 − 0,145 × 1 = 0,855`. Conta minha errada, não fórmula do código.
4. `orcamento_de_particulas_da_chuva` — derivado `soma=900 teto=900 … <=600 … <=300`, medido
   **`emissores=2 soma=748 teto=748 near=520*0.9=468<=468 far=200*1.4=280<=280`**: o 900 e os tetos
   600/300 **não existem** no §3.10d; o teto de cada emissor é o `amount` dele próprio.
5. `chuva_nao_escreve_o_mundo` — derivado `edits_globais=E->E` com a banda `eter_chuva ≤ 4·eter_seco`
   decidindo, medido **`edits_globais=16->17 banda_val=false eter_seco=0.000000 eter_chuva=0.369156`**:
   a janela molhada de 90 quadros apanha o **lobo cavando** (perna 12), que escreve WORK no campo e é
   dono da edição. A banda não é avaliável com `eter_seco = 0`; o que decide a cláusula é a varredura
   estrutural dos três nós (`fx_sem_eter=true rain_sem_eter=true weather_sem_eter=true`) mais a
   assinatura da coluna, e a renúncia à banda sai **impressa por nome**, não silenciada.

O `exposicao_de_ceu_por_coluna` imprime `abaixo=0.749/0.750` contra o 0,750 derivado — e isso **não** é
uma sexta derivação errada: 0,749 é o **byte** do `PackedColorArray` (191/255) do vértice lido de volta,
e o 0,750 é o valor pedido; a fórmula do código aparece na testemunha `y_na_pilha=104 dispersos=0`.

### A régua do boot: sete corridas, um intervalo, nenhum número único

`mesh_ms` e `gen_ms` do `diagnostico final` de cada um dos sete logs da suíte desta perna, na mesma
máquina e com a máquina livre:

| Corrida | `gen_ms` | `mesh_ms` | `worst_sim_ms` | `triangles` |
|---|---|---|---|---|
| controle-base (sem a perna) | 943,108 | **4 711,061** | 14,655 | 214 512 |
| gate-vermelho | 943,453 | 4 724,786 | 13,531 | 214 512 |
| código-a | 975,565 | 4 906,768 | 12,946 | 214 512 |
| rendermode-conserto | 975,369 | 4 973,712 | 14,406 | 214 512 |
| código-b | 954,060 | 4 998,780 | 15,480 | 214 512 |
| código-c | 968,278 | 4 914,629 | 12,935 | 214 512 |
| **pin (clone limpo de `78742d6`)** | 954,359 | **5 093,917** | 14,774 | 214 512 |

Duas coisas se leem aí e as duas são publicadas assim. (1) **O triângulo não se moveu em nenhuma
corrida**: 214 512 em todas, inclusive na base — é o que a cláusula `agua_nao_muda_a_malha`
(`base=214448 espelho=214448 sessao=214448`) garante do lado do mesher, e a exposição entrou como
**canal**, não como geometria (§3.2). (2) **O boot subiu ~200 ms e o número individual não é publicável
como custo**: entre `código-a` (4 906) e o `pin` (5 094) há **187 ms** de diferença **na mesma árvore
com o mesmo código**, que é o chão do instrumento aqui; o que se publica é o intervalo 4 907–5 094 ms
contra a base 4 711–4 725 ms, e a causa plausível é uma só leitura por coluna por rebuild
(`col_lidas=73 472` na sessão inteira, §5.3), não por face. **Nas sete corridas desta tabela** nada disso
encosta no orçamento do passo de simulação: `worst_sim_ms` fica entre **12,94 e 15,48 ms** dos 50 ms, com
`dropped_ticks = 0` em todas, e a régua de 25 ms está verde — `espalhamento_nao_estoura_o_passo …
pior passo=14.77 ms (regua 25)` no pin. Que a **mesma árvore**, oito horas depois e com o mesmo comando,
dê **31,33 a 32,41 ms** nessa régua — e que a base dê o mesmo vermelho na mesma faixa — está medido na
seção "A re-corrida das réguas de timing no fechamento", mais adiante nesta rodada; ela é o motivo por
que as duas frases acima valem para a janela em que foram medidas, e não para a máquina em geral. O custo por quadro do FX é lido, não derivado:
`rain_fx.us_por_quadro = 0,429` sobre 1 352 quadros com a chuva **desligada**, e `water_fx` (Fase 1)
17,18 µs/quadro.

### A prova com janela (§5.4): as três perguntas, e a banda grande com causa nomeada em dois instrumentos

Nenhum braço é gate de fase; é sonda, e o log é
[`readback.log`](evidence/elevacao-visual-chuva-23/readback.log). A moldura é 1920×1080, seed
`20261116`, coluna de água `(100,52)`, e a identidade de enquadramento entre as duas árvores é medida
(`camera_deslocou=0.0000 m` em todos os braços, `mirante coluna=(101,39) … yaw=3.06482 pitch=-0.19830`
caractere por caractere igual em A, A2, A3, B3, B5, B5fps, B6, B7 e C6).

- **O que compila**: `SHADER ERROR` **0** em todos os nove stdout arquivados — com **dois** shaders
  spatial próprios no processo (`opaque_surface.gd`, `water_surface.gd`) mais o do anel. A testemunha
  de que o contador **vê** um erro quando ele existe é o par desta própria perna:
  `chuva23-codigo-a.log` e `chuva23-codigo-c-sombra-4-erros.log` dão **4** cada um (o
  `specular_schlick_blurry` de Godot 3 recusado pelo front-end do 4.7, um por mundo construído) e
  `chuva23-rendermode-conserto.log` devolve **0** depois da troca por `specular_schlick_ggx`. Isso é
  headless, e é o **furo #50** consertando a frase da página que dizia que headless era cego ao shader.
- **O braço de indiferença não coube na banda, e o §5.4 diz o que fazer nisso**: com o chão do
  instrumento medido em **0,0000** (duas corridas do mesmo código, caixas de relevo), o par
  base↔perna-seca dá `topo fracao_ge3=0.9803`, `abrigo 0.9244`, `agua 0.7194`. A regra da casa mandava
  o braço (c) do §3.10b voltar à mesa **com o número**; ele voltou e a mesa decidiu contra ele, com
  atribuição em dois instrumentos: uma sonda de cena sintética (`rocha_fiel_tile.log`, os **dois**
  materiais no mesmo quadro, sob a mesma luz/neblina/tonemap a 45 m, dez placas de 3×3, variante por
  token) mostra que decodificar o `COLOR` do vértice deixa a média a **+33/255** do material velho
  enquanto decodificar a **amostra** do atlas deixa a **+0,24/255** — dentro do chão do próprio
  instrumento (`std_near`, +0,79/−0,96/−1,13 por uma troca de filtro); a ablação de uma linha na cena
  real confirma com o número: **`A2-vs-B5 topo fracao_ge3=0.1236 → 0.0000`**, `abrigo 0.0067`, `agua`
  abaixo do chão da caixa. A causa é o atlas: `voxel_atlas.gd:35` já chama `srgb_to_linear()` antes do
  `create_from_image`, o formato é `FORMAT_RGBA8` (o 4.7 não tem formato sRGB em runtime) e o `tile`
  chega **linear**; o `StandardMaterial3D` decodificava o albedo **duas vezes**, o shader escrito à mão
  decodifica uma. Decisão publicada: **o shader fica como está** (o §3.10c escolheu "sem
  `source_color`" de propósito), e a diferença vira o **furo #48**. O falso conserto também fica
  registrado: `SPECULAR = 0.5;` não comprou diferença nenhuma — `A-vs-B3 topo` e `A2-vs-B6 topo` dão
  os **mesmos quatro números** (`ge1=9216 ge3=9034 fracao=0.9803 r=0.020878 g=0.020078 b=0.010213`),
  porque o F0 de um shader spatial já vale 0,5; e a limitação vai escrita: o par **direto** B3-vs-B6
  não foi rodado, quem decide a inércia são as seis testemunhas, não uma diff que não existe.
- **O molhado aparece, na assinatura pedida**: `B6-vs-C6 topo fracao_ge3=0.1293` contra **`abrigo
  0.0000` com `ge1=0` nos 3 136 pixels** — a caixa abrigada não mudou **um byte** quando o `molhado`
  passou de 0 a 1. O `a=[0.000..0.000]` da caixa abrigada é a razão, e é a primeira vez que o canal do
  §3.10b é lido pelo material: sem ele, o braço (c) — um filtro global — escureceria as duas caixas por
  igual, e é exatamente o teste que o (c) não passa. A caixa d'água **não** é régua deste braço: o
  chão dentro do mesmo braço é 0,7538 e o par seco↔molhado dá 0,7925 — o pixel da superfície não
  discrimina chuva de `TIME`; quem decide a reação da água é `uniforme_chuva=1.000` lido de volta na
  testemunha do `C6` mais a checagem headless `agua_le_a_chuva`.
- **Como as caixas foram escolhidas**, para a escolha não virar ad-hocismo: duas estratégias recusadas
  estão arquivadas (sem penhasco visível no enquadramento; uma pilha de `drop=10` com `px_por_bloco=17,4`
  e caixa de 14 px sobre 256 amostras) e a régua de hoje é a varredura `160×90` com **quatro** motivos
  de recusa contados por nome — `parede`, `submerso` (7 283 células: o `ray_voxel` para no primeiro
  SÓLIDO e água não é sólida, então o fundo de um lago passava por topo exposto), `estreitas`,
  `impuras`. O par primitivo de caixas de 16×16 px dava `abrigo fracao_ge3=0.0117` em vez de 0,0000 —
  quase verde, e verde **pelo motivo errado**.

### O pin: clone limpo de `78742d6`, as quatro corridas, e o que o pin prova sobre a rotulagem

Clone novo em `C:/tmp/aetherfall-pin2-23f2`, `git status` 0 linhas antes de qualquer coisa, `--import`
frio exit 0 ([`pin-import.log`](evidence/elevacao-visual-chuva-23/pin-import.log)), máquina livre,
corridas serializadas:

| Runner | Resultado (linha literal) |
|---|---|
| suíte | `== 275 checagens  2 falhas  62.8 s de teste ==`, exit 1, `SHADER ERROR` 0, `SCRIPT ERROR` 0 |
| reações | `292 checagens 7 falhas 37.381 s` com `FALHA censo de checagens \| 292/320` |
| RNG | `27 checagens 0 falhas 2.707 s` com `OK censo de checagens \| 27/27` |
| journal | `128 checagens 0 falhas 7/7 testes concluidos 6.293 s` com `OK contagem completa de checagens 128/128` |

Os **sete** vermelhos do runner não são desta perna e têm controle, não adjetivo: a corrida da base
`eb218fe` num clone limpo ([`base-runner-23f2.log`](evidence/elevacao-visual-chuva-23/base-runner-23f2.log))
devolve `292 checagens 7 falhas 36.683 s` com o **mesmo** `FALHA censo de checagens | 292/320` e as
**mesmas sete linhas**, byte a byte (`extensao_carrega_classe` ×4, `extensao_pack_no_processo`,
`contrato_igal_ao_http` + o censo) — é o **furo #38**, a extensão ausente onde `native/` não foi
construído. E o runner **não** ganhou checagens desta fase: as onze novas são todas da suíte, o que é
exatamente por que o censo do runner é 292 na base e na ponta.

Um segundo pin foi rodado **antes** da rotulagem nova, na ponta `c56c01f`, e dá o **mesmo veredito** com
outros números de relógio: suíte `275 / 2 / 62,6 s`, runner `292 / 7 / 37,453 s`, RNG `27 / 0 / 2,786 s`,
journal `128 / 0 / 6,341 s`. Os dois pins existem porque o commit entre eles (`78742d6`) é de **rótulo**:
se ele tivesse movido comportamento, os censo/veredito teriam de se mover. Não se moveram.

### A re-corrida das réguas de timing no fechamento, e o par com o amostrador que o débito da Fase 1 pedia

O registro do pouso da Fase 1 deixou uma dívida de instrumento com dono nomeado: **"a próxima perna que
rodar a suíte nesta árvore roda com o amostrador ligado e arquiva o par"**. Esta perna rodou a suíte
**nove** vezes nesta árvore e o par está arquivado:
[`regua25_ponta_recorrencia.log`](evidence/elevacao-visual-chuva-23/regua25_ponta_recorrencia.log),
[`regua25_base-eb218fe_controle.log`](evidence/elevacao-visual-chuva-23/regua25_base-eb218fe_controle.log)
e as três janelas do amostrador
([`carga_janela_ponta.log`](evidence/elevacao-visual-chuva-23/carga_janela_ponta.log),
[`carga_janela_base.log`](evidence/elevacao-visual-chuva-23/carga_janela_base.log),
[`carga_janela_ponta_sem_concorrente.log`](evidence/elevacao-visual-chuva-23/carga_janela_ponta_sem_concorrente.log)),
mais o par do runner ([`runner_incompleto_2026-11-25.log`](evidence/elevacao-visual-chuva-23/runner_incompleto_2026-11-25.log)).
O amostrador é o do **#31 já consertado pelo #44** (copia gitignored de
`docs/evidence/elevacao-visual-agua-23/carga_23.ps1.txt`: join por `IDProcess`, filtro por
`ExecutablePath` dentro de `C:\Aetherfall`), rodado `-step 2`.

A re-corrida devolveu um vermelho que a tabela acima tinha como verde, e ele não é desta perna:

| Janela | Árvore | Rodapé (linha literal) | `worst_sim_ms` | `mesh_ms` | `edit_mesh.mean_us` |
|---|---|---|---|---|---|
| 05h–06h, livre | base `eb218fe` | `264 checagens 2 falhas 54.9 s` | 14,65 | 4 711 | 114 096 |
| 05h–06h, livre | ponta antes do código | `274 checagens 12 falhas 61.7 s` | 13,53 | 4 725 | 114 649 |
| 05h–06h, livre | ponta `78742d6` | `275 checagens 2 falhas 62.8 s` | 12,94–14,77 | 4 907–5 094 | 115 957–121 983 |
| 08h15–08h35 | ponta, 5 corridas | `275 checagens 3 falhas` · 63,7 / 65,3 / 65,5 / 64,9 / 65,4 s | **31,33–32,41** | 4 691–5 064 | 197 605–230 954 |
| 08h15–08h35 | base `eb218fe`, 3 corridas | `264 checagens 3 falhas` · 57,8 / 57,9 / 58,0 s | **30,80–31,26** | 4 739–4 786 | 177 381–195 914 |

As **três** falhas de hoje são as mesmas linhas nas duas árvores: as duas do **#38** (`portao aberto volta a
pedir`, `recusa da fila nomeia o motivo`) e `espalhamento_nao_estoura_o_passo`, com `perdidos=0` e
`tick=450` idênticos dos dois lados. **A base — sem `Weather`, sem `RainFx`, sem material opaco de shader e
sem canal de exposição, lida no mesmo clone limpo de sempre — dá o mesmo vermelho na mesma faixa**: a
diferença de medianas ponta−base é **+0,40 ms** contra uma dispersão da **própria base** de 0,46 ms em três
corridas seguidas. Então o pin publicado acima (`275 / 2`, régua em 14,77 ms) continua sendo o número da
janela em que foi medido, e o que esta seção acrescenta é a falsificação da leitura forte: **a régua de
25 ms não é reprodutível nesta máquina sob carga** — ela dobra nas duas árvores entre as duas janelas com
o mesmo código.

Quatro leituras que o par autoriza, e uma que ele não autoriza:

- **O total da corrida quase não se moveu; o pior passo sim.** A ponta foi de 62,8 s para 63,7–65,4 s
  (+1,4% a +4,1%) e a base de 54,9 s para 57,8–58,0 s (+5,3% a +5,7%), enquanto `worst_sim_ms` foi
  **×2,1** nos dois lados. Custo novo de mesher ou de FX aparece no total; o que aparece só no máximo é
  passo isolado preemptado — a leitura que o **#31** já escreveu para o `96,48 ms` ("portão de velocidade
  de máquina"), agora com o número dos dois lados.
- **Não é outra perna rodando junto.** Na terceira janela havia exatamente **um** PID do projeto
  (`23696`, 99% de um núcleo — a própria corrida) e a régua ainda deu 31,33 ms. Na primeira havia **seis**
  PIDs de engine simultâneos a ~100% cada, porque as pernas desta casa correm na mesma máquina. As cargas
  estrangeiras de pico têm nome nas duas janelas: `CrossDeviceService` 215–291%, `Qoder#4` 243% e
  `Qoder#5` 138–171%, `Qoder` 114–119%, `QuantumEngine` 86–100%, `RadeonSoftware` 99%, `MsMpEng` 34–68% —
  sobre **16** processadores lógicos, com carga total média de 10,7–12,2% e pico de 31%. Nenhum desses
  processos é nosso para fechar, e esta página não fecha.
- **O runner conta a mesma história com outro sintoma.** O pin dele é `292 checagens 7 falhas 37.381 s` na
  ponta e `36.683 s` na base; hoje **nenhuma das duas** fechou em 260 s — a base saiu com exit 124 do
  `timeout`, 55 linhas e nenhum rodapé, e a ponta foi encerrada por mim com 2 min 16 s de CPU e 20 linhas.
  A coluna do tempo é do concorrente, e o concorrente aqui não é uma árvore.
- **O custo que esta perna acrescenta fica com o número da janela livre**, porque só ela compara:
  `edit_mesh.mean_us` 114 096 / 114 649 µs sem o código contra 115 957 / 121 708 / 121 983 µs com ele
  (**+1,3 a +7,9 ms por rebuild, +1,1% a +6,9%**) e `mesh_ms` 4 711/4 725 → 4 907–5 094
  (**+0,18 a +0,38 s nos 157 meshes do boot, +3,9% a +8,1%**), com `triangles` parado em 214 512 em todas
  as corridas. Na janela de hoje a própria base foi de 114 para 177–196 ms **no mesmo código**, e é por
  isso que o par dela não é publicável como custo da perna. A testemunha do que entra no rebuild é o bloco
  novo do `diagnostics()`: `exposure = {chunks_lidos 157, col_lidas 40 192, faces_opacas 243 597, fall 4}`
  no passo final e `col_lidas=72 960` na sessão inteira de hoje (73 472 no pin) — leitura por coluna, não
  por face, como a régua do boot antecipou.
- **O que o par NÃO decide**: qual processo da máquina move o pior passo. O **#31** pedia o parelha
  "uma janela vermelha e uma verde da mesma árvore" com o CPU do próprio Godot nas duas, e a janela verde
  desta árvore (o pin das 05h) foi corrida **sem** amostrador. A dívida fica paga pela metade, escrita
  assim: o par vermelho↔vermelho entre árvores está arquivado com as cinco e três corridas; o
  vermelho↔verde da **mesma** árvore com amostrador nos dois lados continua devendo, e o **#31** continua
  aberto com o dono que já tem.

O manifesto da pasta fecha com as testemunhas: [`artifacts.sha256`](evidence/elevacao-visual-chuva-23/artifacts.sha256)
sobe de **88** para **101** entradas, e as **13** novas são exatamente estas: as **seis** testemunhas da
re-corrida de timing (`regua25_ponta_recorrencia`, `regua25_base-eb218fe_controle`, as três
`carga_janela_*` e o `runner_incompleto_2026-11-25`), os **quatro** logs de régua relidos no fechamento,
os **dois** varredores de instrumento (`citas_nuas.py.txt`, `rotulos_drift.py.txt`) e o `.gdignore` do
**#49**. Re-gerado sobre os bytes do checkout — a forma que o **furo #36** fixou — e conferido dentro da
pasta com `sha256sum -c artifacts.sha256`: **101 linhas `OK`, nenhuma falha, exit 0**. Dos **88** hashes
anteriores, **0** se moveram: nenhuma testemunha já arquivada foi reescrita por esta passada, o que é
exatamente o que a rotulagem forward-only do **#49/#50** prometia.

### Furo #48 — novo, dono esta perna: o mundo tem hoje duas matemáticas de cor, e o vidro ficou na outra

A atribuição do §5.4 acima tem uma consequência que **não** é da água nem do relevo: `_mat_glass`
([src/world/voxel_world.gd:118-124](../src/world/voxel_world.gd#L118-L124)) continua
`StandardMaterial3D` com `albedo_texture = _atlas` + `vertex_color_use_as_albedo`, e portanto continua
decodificando duas vezes o que o opaco agora decodifica uma. **Derivado do código, ainda não medido em
pixel:** vidro e bloco opaco adjacente estão a um decode de distância, e o efeito seco **medido** nesta
passada sobre o relevo exposto é **+5/255 em R e +5/255 em G** (0,0209/0,0201 lineares) — clareia, não
escurece. O número que paga o furo é uma caixa sobre uma parede de vidro ao lado de uma de pedra no
mesmo quadro, e a página (§3.10f) decide **não** levar o vidro a shader nesta fase: o alfa do vidro é o
`topo < 0` do opaco, sem comprador de molhamento, e mexer nele seria pagar o #48 com uma mudança de
material que nenhum gate desta perna pede.

### Furos #49 e #50 — rotulagem: os números desta perna colidiram, uma vez com a `main` e uma vez consigo mesma, e a colisão é de índice, não de conta

A perna abriu com **#46** (o probe que atribuía `sh.code` sem prender o `Shader` a um
`ShaderMaterial`, e os três comentários que dele derivam: o `specular_schlick_blurry` de Godot 3, o
`EMISSION_BOX3D` de Godot 3 no `RainFx` e o parâmetro `chuva` que escondia o global no `WaterSurface`)
e **#47** (a fase do `fp_viewmodel` que não zera, no `_steps` da suíte). Os dois números estavam
tomados, por caminhos diferentes. **#46 já estava na `main` de `eb218fe`**: é o `load_pack` síncrono da
perna 22, aberto com número na mesa em `docs/melhorias-status.md:8198` daquela árvore e relido em
`:8224` e `:8321` — e ele chegou primeiro ao número. A `main` não tem **#47**: esse foi
tomado **dentro desta própria perna**, pela seção de abertura da Fase 2 nesta mesma página
(`docs/melhorias-status.md:8372`), que abriu o #47 para as casas PNG dos recortes da sonda. Dois assuntos, um número, na mesma branch — é
a forma que o índice de furos tem de um escritor-only-eu mesmo, e é por isso que a régua dele é o
`grep` antes de atribuir. O conserto é **de rótulo, forward-only**: #46 → **#50** em
[`opaque_surface.gd:53`](../src/world/opaque_surface.gd#L53),
[`water_surface.gd:103`](../src/world/water_surface.gd#L103),
[`rain_fx.gd:184`](../src/rendering/rain_fx.gd#L184),
[`probe_rendermode.gd.txt:4`](evidence/elevacao-visual-chuva-23/probe_rendermode.gd.txt) e no
[`readback.log:27-30`](evidence/elevacao-visual-chuva-23/readback.log) (que agora nomeia #50 **e escreve
por que o número mudou**); #47 → **#49** em [`smoke_test.gd:176`](../tests/smoke_test.gd#L176).
Nenhum commit anterior e nenhum log arquivado foi reescrito — o que está em `c56c01f` e nos logs continua
dizendo #46, e a linha do readback é o que amarra os dois. `--check-only` nos quatro `.gd` devolve exit 0
com zero `SCRIPT ERROR`, e os dois pins acima são a prova de que o rótulo não moveu comportamento.

### As três réguas no ponto fixo, e as duas classes que nenhuma delas lê

**Âncoras.** `python tools/check_doc_anchors.py` nesta árvore: **40** arquivos · **3 193** ponteiros
conferidos · **212** rótulos · **3 692** links relativos · **`casos objetivos: 5`**, exit 1 pelos cinco
casos — os mesmos cinco `../.tools/...` gitignored que a base devolvia (`_chk_labels.py`,
`_p12_load_sampler.ps1` ×2,
`_carga_por_janela.py` ×2). O controle do próprio instrumento contra a revisão de abertura —
`python tools/check_doc_anchors.py --ref eb218fe`, que lê os **documentos** de `eb218fe` e os **alvos**
do disco — devolve **`casos objetivos: 122`** (era 123 antes dos dois consertos de comentário abaixo: o
controle lê alvos do disco, então ele se move junto com a árvore, e isso está escrito no log). A
diferença de 122 para 5 é o que esta perna quebrou ao
crescer três arquivos: `src/main.gd` +60, `src/world/voxel_world.gd` +94/−10,
`tests/smoke_test.gd` +579 ([`ruler-anchors-apos-23f2.log`](evidence/elevacao-visual-chuva-23/ruler-anchors-apos-23f2.log),
[`ruler-anchors-base-23f2.log`](evidence/elevacao-visual-chuva-23/ruler-anchors-base-23f2.log)).

**A re-derivação foi por mapa de linhas, não por procura.** O instrumento da passada — rascunho em
`C:/tmp/mapa_cites.py`, gitignored porque é desta conversa, não do repositório — lê
`git diff -U0 eb218fe -- <arquivo>` e dá a cada ponteiro um de três veredictos: **IDENTICO** (a linha
alvo não mudou de conteúdo → troca-se só o número), **EDITADA** (o alvo caiu dentro do que a perna
reescreveu → troca-se o número **e relê-se a frase**) e **SEM ALVO** (o alvo não existe mais → a prosa
é que está velha, e quem decide é leitura humana). Aplicados **904** IDENTICO e **13** EDITADA em **32**
documentos. A prova de que nenhuma frase foi reescrita sob pretexto de re-derivação: normalizar os
dígitos (`re.sub(r"\d+", "§")`) de cada um dos 32 arquivos antes e depois devolve **0** mudanças fora de
dígitos.

O instrumento precisou de três consertos próprios, e cada um é uma classe que a régua da casa não via:

1. **o `[:NNN]` que herda o caminho do ponteiro anterior na mesma linha** — a forma como o próprio
   dossiê e o status citam depois do primeiro; varrido por um passe separado com a lista de âncoras da
   linha, e era a maior parte do dano nas páginas 09, 12, 14, 16 e 23;
2. **a escrita com revisão** — `` `eb218fe:src/world/voxel_world.gd:689` `` é como a casa nomeia "a
   leitura daquela árvore", e esses ponteiros são **exemptos por desenho**: quem os vê como velhos
   apagaria a data da medição. Onde a frase desta perna descreve a **base**, ela passou a essa forma (o
   §3.10b da página 23, o §2 do registro de abertura, o parágrafo do `AGENTS.md`), com o tempo do verbo
   corrigido junto — "de hoje" virou "da base";
3. **a escrita adiada** — um documento alvo de si mesmo muda de conteúdo enquanto é reescrito, e o mapa
   lido do disco passava a depender da ordem dos arquivos; os writes foram adiados para o fim e a
   segunda passada passou a dar o mesmo número da primeira (era 904/13 contra 811 de um mapa
   auto-contaminado).

**O que a régua de âncoras não lê, medido em vez de afirmado.** Duas classes, cada uma com o par
base/ponta:

- **rótulo numérico cujo URL aponta para outro número** (`[main.gd:331](src/main.gd#L367)`, a forma que
  o `AGENTS.md` usa desde as pernas antigas): **116** divergentes hoje sobre **1 403** rótulos com número
  conferidos, e **115** sobre **1 376** na base relida pelo mesmo script
  ([`rotulos_drift.py.txt`](evidence/elevacao-visual-chuva-23/rotulos_drift.py.txt)). O 116º é **esta
  frase contando a si mesma** — o exemplo entre parênteses acima é um rótulo divergente legítimo —, e sem
  ele a passada fica em **115**, exatamente o número da base: **0** introduzidos, com a distribuição por
  arquivo idêntica nas duas árvores: status 76 (75 descontada a própria frase), `AGENTS.md` 10,
  página 10 6, páginas 11 e design-09 4 cada, `engine/simclock.md`, página 13 e design-07 e design-08 3
  cada, páginas 09 e 14 2 cada. É o **furo #28** na forma que a casa ainda não varre, com dono **fora**
  desta perna: consertar 115 rótulos de prosa alheia numa perna autorizada a mexer "só visual" custaria
  mais revisão do que vale, e nada do que eles descrevem foi tocado aqui.
- **citação nua em comentário de código** (`(voxel_world.gd:689)`, sem `src/` e sem `#L`): escapa das
  duas réguas porque nenhuma delas tem o prefixo de diretório para casar. Varredura própria
  ([`citas_nuas.py.txt`](evidence/elevacao-visual-chuva-23/citas_nuas.py.txt)): esta passada **abriu**
  com **52** citações nuas e **4** delas caindo em linha branca, contra **44** e **1** na base; os três
  consertos abaixo deixam a árvore em **50** e **2**. Consertados os que vivem em arquivo que esta perna
  escreve:
  [`opaque_surface.gd:57-60`](../src/world/opaque_surface.gd#L57-L60) (`voxel_world.gd:94` →
  `eb218fe:src/world/voxel_world.gd:94`, e o `voxel_atlas.gd:36` que descrevia o `srgb_to_linear()` de
  [:35](../src/world/voxel_atlas.gd#L35)) e
  [`smoke_test.gd:1121-1125`](../tests/smoke_test.gd#L1121-L1125) (a base com prefixo de revisão e o
  `a` de hoje em [voxel_world.gd:773](../src/world/voxel_world.gd#L773)). Os outros dois ficam em
  arquivo que a cláusula do dono proíbe esta perna de escrever — é o **furo #51**, abaixo.

**Citações de arquivo.** `verify_plan_cites.py` com `AGENTS.md`, `README.md`, o status e as
**23** páginas de `docs/planos/`: **2 718** citações com número de linha conferidas, **60** arquivos
citados que não existem, **0** números de linha fora do arquivo, exit 0. A base relida pelo mesmo
instrumento e o mesmo corpus dá **2 664 / 60 / 0**: esta perna acrescentou **54** citações conferidas e
**nenhum** arquivo inexistente novo ([`ruler-cites-23f2.log`](evidence/elevacao-visual-chuva-23/ruler-cites-23f2.log)).
Os 60 são a lista de sempre — peças que as páginas 02, 06, 07, 15, 20 e 22 declaram comprar
(`src/core/sim/tick_clock.gd`, `src/ai/llm_server_host.gd`, `src/entities/falling_block.gd`,
`tests/wolf_multiseed_census_test.gd`, `.tools/*.log`) e logs gitignored.

**Identificadores.** `verify_plan_ids.py` na página 23
([`ruler-ids-23f2.log`](evidence/elevacao-visual-chuva-23/ruler-ids-23f2.log)): **172** identificadores em backticks, **14**
ausentes de `src/` e `tests/` — todos de classe declarada: nome de API da engine (`CPUParticles3D`,
`ReflectionProbe`, `forward_plus`, os dois filtros), braço **rejeitado** por nome
(`material_switch`, `albedo_modulate`, `entered_water`), rótulo de braço da sonda (existe no
[`readback.log:76`](evidence/elevacao-visual-chuva-23/readback.log), não em código), SHA de commit e a
palavra `builds`. Antes do conserto eram **173 / 20**, e os **6** que saíram não eram dessa classe: eram
prosa errada desta própria perna, e é isso que a régua de identificadores vê que a de âncoras não vê.
`AGENTS.md` dá **170 / 41** e o status **822 / 268**, ambos com a base em **161 / 41** e **762 / 252** —
a lista grande é o índice de peças que as outras pernas devem, mais nomes de instrumento (`.tools/` e os
rascunhos desta conversa: `ARRAY_DATA`, `BARE`, `LINK`, `CONT`, `DEFPAT`, `REL`, `CODE`,
`citas_nuas.py`, `rotulos_drift.py`), SHA e, desde a re-corrida de timing, os **quatro** nomes de
testemunha que a janela carregou (`CrossDeviceService`, `Qoder`, `RadeonSoftware` e o próprio
`regua25_ponta_recorrencia`) — a mesma classe de `QuantumEngine` e `MsMpEng`, que já estavam: o
instrumento só conhece `src/` e `tests/`, então tudo que não é código daqui entra na lista de ausentes
por construção, e é isso que a linha de controle acima declara. Os **4** novos são a régua lendo a
testemunha, não prosa nova desta perna: os três primeiros saem das cargas de janela com o `pid` e a
porcentagem da amostra que os imprimiu, e o quarto é o nome do log que esta seção linka.

**Os seis nomes que a régua de identificadores devolveu como prosa errada, e o que cada um é no
código.** (1) `set_weather` aparecia em dois lugares da página 23 como peça escrita em
`src/world/voxel_world.gd`: não existe nem esse nome nem esse portador — o mundo entrega o material por
[`opaque_material()`](../src/world/voxel_world.gd#L144) e quem pede chuva é
[`Weather.pedir_chuva()`](../src/rendering/weather.gd#L53), com o sink
[`apply_sink()`](../src/rendering/weather.gd#L91) aplicado em
[`main.gd:1351-1353`](../src/main.gd#L1351-L1353). (2) `topo_da_coluna` era o nome que a fórmula do
§3.10b dava à variável: a linha real escreve `topo`
([voxel_world.gd:772](../src/world/voxel_world.gd#L772)), e a página passou a citar a fórmula literal.
(3) `filter_nearest_with_mipmaps` era o filtro que o §3.10c dizia reproduzido: a base escrevia
`BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS` (`eb218fe:src/world/voxel_world.gd:94`) e o shader
declara `filter_nearest_mipmap` ([opaque_surface.gd:61](../src/world/opaque_surface.gd#L61)) — a página
agora nomeia as duas grafias e quem é de onde. (4) "as dez checagens de §5.3" eram **onze**, com o censo
264 → **275** que a própria rodada publica. (5) "`src/main.gd` (quatro linhas)" era o plano antes do
código; medido no `git diff --numstat` da ponta são **60**. (6) "hoje a malharia escreve `1.0`" no
comentário do `_steps` descrevia a base como presente — o conserto está no parágrafo das citações nuas
acima.

### Furo #51 — novo, dono fora desta perna: a citação nua em comentário de código é invisível às três réguas

Cinquenta citações de arquivo vivem hoje em comentários de `src/` e `tests/` **sem** o prefixo de
diretório (`(voxel_world.gd:689)`) e **sem** a forma `#L`, que é o que `check_doc_anchors.py` casa — e
**nenhum** dos três instrumentos abre arquivo de código: a régua de âncoras tem corpus de `docs/`, e as
duas de citação exigem o prefixo. A consequência medida nesta passada: a perna cresceu
`src/world/voxel_world.gd` em +94/−10 e `src/main.gd` em +60, e **quatro** ponteiros assim caíram em
linha branca sem que **nenhuma** régua dissesse nada. Dois foram consertados aqui, porque moram em
arquivo desta perna (`opaque_surface.gd:57`, `smoke_test.gd:1123` — o par no parágrafo acima). Restam
dois, e nenhum dos dois é desta perna:
`src/entities/wolf.gd:131` → `main.gd:913-918` (o `_on_acted("break")` está hoje em
[`src/main.gd:984-987`](../src/main.gd#L984-L987); na base já estava em `:960-962`, ou seja, o ponteiro
estava errado **antes** desta perna e a régua nunca viu nem uma coisa nem outra) e
`tests/aether_reactions_test.gd:5360` → `voxel_world.gd:301` (a cláusula "só visual" de `src/entities/`
e o fato de o runner estar em voo na perna 22 tiram este arquivo do alcance desta passada; o alvo
correto é a guarda de carimbo em [`src/world/voxel_world.gd:339`](../src/world/voxel_world.gd#L339)).
**O que fecha o furo:** a varredura de citações nuas entrar no `check_doc_anchors.py` como sétima classe
(o mesmo `CONT`-estilo: resolver o nome pelos diretórios `src/`/`tests/` e exigir conteúdo na linha
alvo), e os dois ponteiros restantes irem com quem escreve aqueles arquivos — a perna que abrir `wolf.gd`
paga o de lá, e a que abrir o runner paga o `:301 → :339`. Dono: o dono do instrumento de réguas, não
esta perna. Nada disto é código de jogo: os consertos que esta passada fez nos dois arquivos próprios
são comentário, e o par de pins acima cobre a árvore.

### Furo #52 — novo, medido nesta passada: a deriva de número é invisível à régua em 572 dos 659 ponteiros

Um merge que traz duas famílias de linhas para a mesma árvore envelhece ponteiro para uma linha
**cheia**, e é aí que a régua não olha: [`tools/check_doc_anchors.py`](../tools/check_doc_anchors.py)
confere o rótulo contra o **conteúdo** da linha-alvo e o URL contra o **arquivo**, e só acusa quando o
alvo cai em branco, quando o rótulo nomeia um símbolo fora da faixa, ou quando o arquivo não existe.
Medido na árvore do segundo merge: com os documentos de `822a6ea` (antes desta re-derivação) contra o
código da árvore, a régua imprime **92** casos objetivos; com os documentos desta passada, **5** — os
cinco `../.tools/...` gitignored da classe já tolerada. A régua via, portanto, **87** casos; o mapa
linha-a-linha moveu **659** ponteiros (627 derivados de `4ceb1a5`, 32 de `2f46368`) em **32**
documentos. A diferença — **572** — não é subtração de conjuntos (os 87 incluem os onze consertos
lidos à mão), é a ordem de grandeza que passa verde: um ponteiro que se moveu 26 linhas e caiu em
linha cheia é indistinguível, para a casa, de um ponteiro certo.

A classe não é teórica, e o exemplo é desta passada: a página 13 citava `EXPECTED_CHECKS` na linha 60
de [tests/aether_reactions_test.gd](../tests/aether_reactions_test.gd) e o mapa, que desloca **posição**
e não **símbolo**, a teria movido para 64 — onde mora um comentário de cabeçalho. A constante vive hoje
em [`:126`](../tests/aether_reactions_test.gd#L126) com o valor **355**, e nem `check_doc_anchors.py`
nem `verify_plan_cites.py` (que lê o número do rótulo e ignora o do URL) diriam uma palavra sobre as
duas versões.

**O que fecha o furo:** uma classe nova no `check_doc_anchors.py` que resolva o **símbolo** citado pelo
rótulo e exija que a linha-alvo caia dentro da faixa dele — o que `verify_plan_ids.py` já faz com
identificadores, mas em `src/`/`tests/` e não em ponteiro de prosa. Dono: o dono do instrumento de
réguas, como no #51. Esta perna não escreve em `tools/`: a cláusula do prompt dela é visual, e o
`check_doc_anchors.py` é compartilhado com as pernas que estão em voo.

### O que esta passada abre e não fecha

- **A expectativa de hash da abertura precisava de uma leitura melhor, e ela é publicada corrigida.** A
  §de abertura escreveu "espera-se que uma corrida com chuva **reproduza** os hashes publicados". O
  mandato 3 desta página já mediu que **a simulação ao vivo não é determinística** — dois runs da mesma
  árvore, sem chuva nenhuma, já deram `hp`, Éter e pior passo diferentes. Então "reproduzir o hash"
  nunca foi testável na forma forte, e não há corrida pareada com/sem chuva arquivada aqui. O que é
  testável — e o que **foi** medido — é que a chuva não acrescenta **entrada** alguma à projeção: os
  três nós novos não seguram referência a `AetherField`, `VoxelWorld` ou `Player`
  (`fx_sem_eter=true rain_sem_eter=true weather_sem_eter=true`, `world_refs=0 eter_refs=0
  player_refs=0`), `Channel.COUNT` continua **3**, `FORMAT_VERSION` e `GEN_VERSION` seguem intocados, e
  `edits_globais=16->17` tem dono nomeado (o cavar da perna 12), não a chuva. Fica como **débito** a
  corrida pareada com `--tick-journal=` nos dois braços, se alguém quiser o número na forma forte.
- **Nada do budget agregado do Éter mudou nem foi medido aqui**: o `eter_chuva=0,369156` da janela é o
  lobo cavando, não a chuva, e a régua dele continua sendo a do §de orçamento da Fase 1.
- O **`--weather=<alvo>`** é a porta da sonda e da suíte; o `Rodar.bat` ainda não a expõe — a página
  §3.10a pedia a bandeira na CLI, não no launcher, e o launcher continua sem autorização.
- **Os 115 rótulos cujo URL aponta para outro número ficam como débito, não como tarefa desta
  perna.** Medido acima (115 hoje × 115 na base, mesma distribuição por arquivo), com o script
  arquivado: são prosa das pernas 02, 09, 10, 11, 13, 14, design 07/08/09 e `engine/simclock.md`, mais
  o `AGENTS.md` e o próprio status. Quem os conserta é quem abrir cada página, ou o dono do instrumento
  se a classe entrar na régua (a sétima classe do furo #51 resolve as duas coisas de uma vez, porque o
  mesmo mapa linha-a-linha serve para rótulo e para URL).
- **A régua de âncoras não tem corpus em `src/`/`tests/`**, e é por isso que o furo #51 nasceu dela e
  não do código: `tools/check_doc_anchors.py:80` (`doc_files`) varre `AGENTS.md`, `README.md` e `docs/`;
  nada nele abre um `.gd`. Registrar assim para a próxima perna não refazer a varredura de rascunho.
- **A régua de 25 ms do `espalhamento_nao_estoura_o_passo` está vermelha nesta máquina desde as ~08h15 de
  2026-11-25, nas duas árvores, e o pin publicado (`275 / 2`, 14,77 ms) é da janela livre.** Medido e
  arquivado acima. Consequência prática para quem vem depois: **nenhum número de `worst_sim_ms` desta
  máquina é comparável entre janelas**, e um gate que dependa dele tem de ser corrido com o amostrador
  ligado e com a janela registrada — não com o rodapé de uma corrida de outra hora. O **#31** continua
  aberto com essa cobrança, e a dívida específica dele (o par vermelha↔verde da mesma árvore com o CPU do
  Godot nos dois lados) fica escrita na seção acima, paga pela metade.
- A **Fase 2 não fecha gate de fase nenhum** (mandato 4): o gate da Fase 2 é o do dossiê 23 e ele
  continua aberto; a fila serializada continua **22 → 17 → 18 → 20 → 13**, e o pouso desta branch vem no
  registro seguinte.

## Rodada 2026-11-25 (11) — Fase 2 do dossiê 22: a memória de qualidade chega ao `Mind`, o prompt do oráculo passa a mostrar o top-k puro no estado, e o portão da Camada 5 passa a ler o ledger (branch `feat/oraculo-nativo-fase2-22`, base `7cd3ff2`, vermelho `094dbe9`, ponta de código `f9c5cbe`)

O que a fase entrega, na ordem dos commits do §21 do [dossiê 22](planos/22-oraculo-nativo-gdextension.md):
**`094dbe9`** — as três premissas nascem vermelhas na mesma corrida (runner **339 checagens 4 falhas
49,462 s**: `janela=false`, `visto_em=ausente vezes=ausente`, `aceitar_ledger=false` e o censo
**339/355**; os três gates do Passo 5 verdes e a régua do budget já medindo `worst_sim_ms=13.02 ms`
no vermelho). Todo acesso à API que ainda não existe entra por `.call()`/`get`/`set` dinâmicos e a
assinatura de 4 args é sondada por `get_method_list` — o parse do GDScript recusa chamada direta a
método ausente, e o vermelho é checagem nomeada, nunca `SCRIPT ERROR`. **`2e946a2`** — o `reinforce`
ganha `p_tick` e conta todo toque em `vezes`, carimbando `visto_em` só quando o delta confirma; o
`to_dict` grava os quatro campos e o `from_dict` lê o formato novo **e** o float dos saves antigos
com `source` de volta `"loaded"`; o **mesmo commit** atualiza a leitura do `_prompt_for` para
`["confidence"]` (o formato mudou em memória — o texto do prompt fica byte a byte o mesmo, e as
chaves de conteúdo da cache não mudam neste commit). O par anti-farsa fecha na corrida: mover a
metadata não move o `state_hash` (`5380ea58470b` → igual) e mover confiança move
(`→ 2aab3ac9680b`); runner **344/3/50,213 s**, suíte **266/0/53,1 s**. **`8cc3351`** —
`_janela_crencas` (estática, pura) ordena confiança → vezes → visto → chave com desempate **total**
e `JANELA_CRENCAS = 8` constante nomeada; mesmo estado em duas ordens de inserção devolve a mesma
janela, nada deriva com 61 ms de parede, e o mesmo estado da mente produz o mesmo prompt
(`366 chars igual=true`) com o gate do replay verde (`315/315 iguais=true`); runner
**349/2/48,726 s**. **`f9c5cbe`** — o portão fecha o gate `crenca_falsa_nao_vira_fato`:
`aceitar_ledger` recusa id fora do ledger e **fato contradito** (`o lobo 11 e vivo e a saida o
declara morto`) com id e motivo nomeados, confirma a morte declarada sobre cadáver em
`fatos_confirmados`, e o wrapper ganha `ledger_provider`/`ultimo_portao` (sem provider, degrada ao
roster do Passo 5, nomeado) e `_quarentena` → `Mind.quarentena` (`oracle_caiu_N`,
`QUARENTENA_CONFIDENCE = 0.10`, fonte `"oracle"`, abaixo da soleira de `believes` — nunca intenção
escrita no corpo). O main liga `ledger_do_mundo()` com o id 1 compartilhado lobo/jogador e a escolha
conservadora nomeada; runner **355/0/49,235 s**, suíte **266/0/53,6 s**.

As quatro corridas da ponta: suíte **266/0/53,9 s**, runner **355/0/50,681 s**, RNG **27/0/2,732 s**,
journal **128/0/6,007 s** — zero `SCRIPT ERROR` nas quatro. A régua do budget re-medida com o top-k
no caminho de todo prompt e o portão expandido no caminho de toda saída: **`worst_sim_ms=15.97 ms
pico_do_passo=15 973 µs media=2 381,3 µs/passo worst_decode_us=791 373 narradas=5/5`** com o decode
em voo dentro da malha de 1 400 passos, `trips=0→0`.

Evidência em [`docs/evidence/oraculo-nativo-fase2-22/`](evidence/oraculo-nativo-fase2-22/) — os dez
logs da fase (abertura vermelha, runner após cada commit, suíte intermediária e as quatro da ponta)
mais o manifesto. O §21 do dossiê carrega a narrativa completa. As três decisões de corte do §20.4
permanecem fechadas; `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a projeção do `TickJournal`
não foram tocados (a projeção provada indiferente pela checagem, não por frase). Nenhum gate de fase
fecha. A fila serializada não muda: **22 → 17 → 18 → 20 → 13**.

## O pouso da Fase 2 na `main` — as quatro corridas da mergida, o clone limpo com o `build.bat` rodando dentro dele e a régua do budget medindo duas vezes abaixo do teto (2026-11-25, `docs/registro-pouso-fase2-22`, base `7cd3ff2`, ponta `610ba00`, merge `4ceb1a5`)

### O que o merge toca, com o número em cada árvore

`git merge --no-ff feat/oraculo-nativo-fase2-22` devolve **`4ceb1a5`** sobre **`7cd3ff2`** (ponta da
branch: `610ba00`, o commit de docs que fecha a re-derivação de 31 páginas), **54 arquivos,
+22 946/−730**: em `src/ai/`, [`belief_verifier.gd`](../src/ai/belief_verifier.gd) +65 (a rota do
ledger: `aceitar_ledger` recusa id fora do ledger e fato contradito, confirma morte sobre cadáver),
[`mind.gd`](../src/ai/mind.gd) +65 (`visto_em`/`vezes` na crença, `_janela_crencas` pura com
`JANELA_CRENCAS = 8`, `Mind.quarentena`), [`mind_oracle.gd`](../src/ai/mind_oracle.gd) +111
(`ledger_provider`/`ultimo_portao`, `_quarentena` → `Mind.quarentena`); em
[`src/main.gd`](../src/main.gd) +24 (`ledger_do_mundo()` ligado, id 1 compartilhado lobo/jogador); no
[`tests/aether_reactions_test.gd`](../tests/aether_reactions_test.gd) +430 (o gate
`crenca_falsa_nao_vira_fato` fechando, censo 344 → **355**); e a prosa re-ancorada (commit `610ba00`).

| Árvore | `7cd3ff2` | `610ba00` | `4ceb1a5` |
| --- | --- | --- | --- |
| `src` | `827c7eeb810cff46…` | `2f2f21571a0a2a0d…` | **`2f2f2157…`** |
| `tests` | `c1efd81a19b2d8b7…` | `d2af7ae3a932619d…` | **`d2af7ae3…`** |
| `native` | `2c2baea7df22865f…` | **idem** | **idem** |

O `native` fica parado nas três revisões: a Fase 2 é GDScript puro — nenhuma linha da extensão, do
`build.bat` ou do gate de símbolos se move, e os números de build abaixo são re-medição de
ferramenta, não de código. O `src` e o `tests` mudam, e por isso os números de runner e suíte abaixo
são re-medição de contrato, não herança por identidade.

Publicação da branch conferida com `git ls-remote --heads origin`:
`refs/heads/feat/oraculo-nativo-fase2-22` = `610ba006a1fffe77d7649c914d3fc6e3604fcd3b`. A da `main`
desta passada é conferida pelo mesmo comando no fecho deste registro — é a única prova de que saiu; o
exit 0 do `push` não prova.

### As quatro corridas da árvore mergida, com a máquina livre

Antes delas, `--import` na árvore mergida
([`main_mergida_import.log`](evidence/registro-pouso-fase2-22/main_mergida_import.log), exit 0) com a
assinatura esperada da classe do **furo #38**: exatamente **4** linhas `ERROR` nas **7, 9, 147, 149**
(2× `Condition "!FileAccess::exists(path)"` + 2× `GDExtension dynamic library not found`) — a dll é
construída depois do import — e `git status` imprimindo as **6** linhas `??` esperadas (2×
`tests/audio_*.gd.uid`, furo #25; 4× `caixa-*.png.import` da perna 23, furo #45). O provisionamento
da junção `.tools\llama` e do hardlink do gguf é ambiente de máquina, não mudança de árvore. As
quatro rodaram serial.

- `build.bat` na árvore mergida
  ([`main_mergida_build.log`](evidence/registro-pouso-fase2-22/main_mergida_build.log)): exit 0,
  `[gate] link_codigo=0`, a régua de dll em **243** (`dll_bytes=184320`), o export em **244**
  (`export= 1 00002FD0 af_mind_entry`), a tabela de imports do dll em **256**
  (`[import] OK referenciados=55 modulos=4 nomes_na_tabela=55`) e a rota do prompt fechando em
  **240** (`[corrida] probe_rota_codigo=0`) com o veredito `ROTA_DE_PROMPT_CONFIRMADA`.
- Runner de reações:
  [`main_mergida_runner.log`](evidence/registro-pouso-fase2-22/main_mergida_runner.log) — as cinco
  `OK extensao_carrega_classe` nas linhas **535–539** (descritor no disco, `ja_vinha_do_boot=true
  agora=true`, `is_library_open=true`, `class_exists(AfMindOracle)=true`,
  `instantiate_valido=true get_class=AfMindOracle`), os três números do §5.2 em **2596**
  (`base=900079760 apos_load=3630637200 apos_ctx=4282327184 ctx_state_bytes=606
  versao=1.0.0-dev`), a régua do budget da Fase 2 em **3917** (`OK
  budget_do_oraculo_nao_estoura_a_arvore | narradas=5/5 pedidos=8 worst_decode_us=791650 |
  worst_sim_ms=15.59 ms pico_do_passo=15588 us media=2669.7 us/passo total=3737631 us em 1400
  passos`), `trips_solo=0 trips_matilha=0` em **3940**, censo **355/355** em **3941** e
  **3944** `355 checagens 0 falhas 59.911 s`. Exit 0, zero `SCRIPT ERROR`. O cenário estreito
  imprime **10 568** passos (`sim_step total=2 523 835 µs`, pico `5 625 µs`) e a matilha
  **1 341** (`sim_tick total=3 443 871 µs`, pico `14 930 µs`).
- Suíte: [`main_mergida_suite.log`](evidence/registro-pouso-fase2-22/main_mergida_suite.log)
  linha **380** `== 266 checagens  0 falhas  60.8 s de teste ==`, exit 0, zero `SCRIPT ERROR`.
- RNG e journal na mergida:
  [`main_mergida_rng.log`](evidence/registro-pouso-fase2-22/main_mergida_rng.log) **77–78**
  (`27/27`, `27 checagens 0 falhas 2.858 s`) e
  [`main_mergida_journal.log`](evidence/registro-pouso-fase2-22/main_mergida_journal.log)
  **142–143** (`128/128`, `128 checagens 0 falhas 7/7 testes concluidos 6.975 s`).

### O pin: clone limpo de `4ceb1a5`, com o `build.bat` rodando dentro dele

Clone de `C:/Aetherfall` com `git checkout 4ceb1a5` em HEAD desanexado (árvores conferidas: `src`
`2f2f2157…`, `tests` `d2af7ae3…`), provisionado com a junção e o hardlink, `--import` frio com a
**mesma** assinatura de 4 `ERROR` nas mesmas linhas **7, 9, 147, 149** e as mesmas **6** `??`, e
`git status --porcelain` com exatamente 6 linhas antes do build.

- `build.bat` dentro do clone
  ([`clone_limpo_build.log`](evidence/registro-pouso-fase2-22/clone_limpo_build.log)): exit 0, e as
  quatro réguas saem com os **mesmos** valores da mergida — `dll_bytes=184320` em **243**,
  `export= 1 00002FD0 af_mind_entry`, `[import] OK referenciados=55 modulos=4 nomes_na_tabela=55`
  em **256**, `[corrida] probe_rota_codigo=0` em **240** com
  `[prompt] veredito=ROTA_DE_PROMPT_CONFIRMADA`.
- Runner no clone:
  [`clone_limpo_runner.log`](evidence/registro-pouso-fase2-22/clone_limpo_runner.log) — as cinco
  `OK extensao_carrega_classe` nas mesmas linhas **535–539**, os três números do §5.2 em **2596**
  iguais, o gguf impresso pelo caminho do clone em **541**
  (`gguf=C:/aetherfall_pin_fase2/models/qwen3.5-4b-q4_k_m.gguf bytes=2740937888`), a régua do
  budget em **3917** (`narradas=5/5 pedidos=7 worst_decode_us=796414 | worst_sim_ms=13.82 ms
  pico_do_passo=13823 us media=2503.8 us/passo total=3505323 us em 1400 passos`) — segunda
  medição da mesma régua em outra árvore-física, ambos os piores passos abaixo do teto de 50 ms,
  com a variação de `pedidos` (8→7) e de `worst_decode_us` já coberta pela não-determinismo da
  simulação ao vivo registrada no mandato 3 —, censo **355/355** em **3941** e **3944**
  `355 checagens 0 falhas 64.063 s`. Exit 0, zero `SCRIPT ERROR`.
- Suíte no clone:
  [`clone_limpo_suite.log`](evidence/registro-pouso-fase2-22/clone_limpo_suite.log) linha **380**
  `== 266 checagens  0 falhas  54.4 s de teste ==`, exit 0, zero `SCRIPT ERROR`.
- RNG e journal ficam nas quatro corridas da mergida: o que o clone renova aqui é o par que exerce
  o jogo real e o gate novo — suíte + runner.

O número pineado para `4ceb1a5` é: runner **355 / 0** (59,911 s na mergida; **64,063 s** no clone),
suíte **266 / 0** (60,8 s; **54,4 s**), RNG **27 / 0 / 2,858 s** e journal **128 / 0 / 6,975 s** — as
duas últimas só na mergida; a régua do budget oraculo mediu **15,59 ms** (mergida) e **13,82 ms**
(clone), ambos abaixo do teto de 50 ms do passo, com decode em voo dentro da malha de 1 400 passos.

### O que o pouso deixa aberto

Nenhum gate de fase (mandato 4). Dentro da perna 22, a **Fase 2 fechou o dela**: memória de
qualidade no `Mind`, janela top-k pura no prompt, portão lendo o ledger com quarentena rebaixada.
Seguem as fases autorizadas como pauta, cada uma com gate próprio e nenhuma linha antes de a
anterior fechar o dela: a **Fase 3** (adaptação por bandit, gate `bandit_une_numero_observavel`), a
**Fase 4** (ferramentas e observabilidade; dona do **furo #46** — o `load_pack` síncrono que trava o
frame do load — e do consumidor da quarentena no inspector) e a **Fase 5** (LOD e orçamento; o
`inspector_ve_a_mesma_leitura_do_journal`). Dos furos, **#38** (o import continua reclamando antes
do build) e **#39** (réguas cegas a `native/`) seguem como decisão do dono; o **#20** sem a colheita
que nomeia a folha; o **#31** sem atribuição; o **#41** como furo da contagem de malha; o **#44**
fica onde a 23 o deixou; o **#45** é arrumação do dono. A atribuição do par de vazamento do quit
(e o `ERROR: 2 resources still in use at exit` que o clone imprime no fecho) segue sem dono. O
**#25** e o **#45** seguem uncommitted por decisão registrada. `Channel.COUNT`,
`FORMAT_VERSION`, `GEN_VERSION` e a projeção do `TickJournal` não foram tocados por este pouso. A
fila serializada não muda: **22 → 17 → 18 → 20 → 13**.

## A integração das duas Fase 2 na `main` — a leg chuva pousada por documentos, o par vermelho→verde do guard arquivado e as quatro corridas medidas na árvore integrada (2026-11-25, `feat/elevacao-visual-chuva-23f2` ponta `955dc47`, merge `aea325a`)

### O que os dois merges tocam, com a árvore em cada um

Dois merges fecham a Fase 2 nas duas pernas da vez. O primeiro, `3919bbb`, trouxe a `origin/main`
(o código da chuva, pousado pelo PR #1 `e0a558c`, e a re-derivação `2f46368`) para dentro da linha
da Fase 2 do oráculo — o `src` e o `tests` resultantes são a **combinação dos dois pousos de
código**, uma árvore que nenhum dos pais tinha. O segundo, `aea325a`, trouxe a ponta final da
branch da leg chuva (`955dc47`), e ela é **docs+evidências apenas** sobre essa árvore:
`git diff --cached` contra os dois pais em `src tests` devolve vazio nos dois sentidos, e
`git rev-parse <sha>:src`/`:tests` imprime a mesma dupla nos três commits —
**`9b5dc8ec7847a24f7e77db4518b9cf90aa055ef2`** e **`d534212a0061b368ee41b4dd8c222886ef0915fe`**.
Consequência registrada como regra e não como esperança: os números abaixo, medidos na árvore de
`aea325a`, valem para `3919bbb` por identidade de árvore — e **não** valem para `4ceb1a5` nem para
`e0a558c`, cujas árvores são outras (`2f2f2157…`/`d2af7ae3…` e `81608c2f…`/`b3349a19…`).

Os 30 conflitos de documentação foram resolvidos ficando com a re-derivação conferida linha a linha
no conteúdo (a desta linha); a varredura mecânica da leg chuva entra como contribuição documentada,
não como alvo: o **Furo #52** dela (572 dos 659 ponteiros envelhecidos invisíveis à régua) está
portado verbatim na seção acima, os três re-ancoramentos de
[`docs/audio-provenance.md`](../docs/audio-provenance.md) do commit `e4c5b31` foram conferidos e
**dois estavam errados nesta árvore** — o que entrou são dois consertos de fora-por-um da linha de
cá, `on_wolf_registered` apontando a chamada real
([`src/main.gd:445-446`](../src/main.gd#L445-L446), ao `444-445`) e `clear_transient()` em
[`src/main.gd:1145`](../src/main.gd#L1145), ao `1144` — e o automerge de
[`docs/planos/06-decompor-main-gd.md`](../docs/planos/06-decompor-main-gd.md) re-marca dois alvos
que conferem nesta árvore (`docs/melhorias-status.md:728-730` é o item 7 de "Falta";
`:1052-1053` é a regra do apodrecimento). As evidências da leg chuva entram inteiras
(`elevacao-visual-chuva-23`, `clone-limpo-23f2-pin`, `rederivacao-23f2-merge2`).

### As quatro corridas da árvore integrada, com a máquina livre — e o par vermelho→verde do guard

Corridas serial na árvore de `aea325a`, sem outra carga, dll de `native/af_mind/bin/` presente,
evidência em [`docs/evidence/registro-integracao-fase2-22-23/`](evidence/registro-integracao-fase2-22-23/)
com manifesto `artifacts.sha256`:

- Suíte: [`suite.log`](evidence/registro-integracao-fase2-22-23/suite.log) linha **412**
  `== 277 checagens  0 falhas  60.2 s de teste ==` — o censo **266** medido no pouso da Fase 2-22
  (`4ceb1a5`) mais as **11** checagens que a leg chuva acrescentou —, exit 0, zero `SCRIPT ERROR`.
  O fecho imprime `ERROR: 4 resources still in use at exit` (`object.cpp:2536`): o par de vazamento
  do quit segue sem dono, e o número observado nesta árvore é **4**.
- Runner, primeira corrida:
  [`runner_vermelho.log`](evidence/registro-integracao-fase2-22-23/runner_vermelho.log) linha **3918**
  `FALHA budget_do_oraculo: o SubtreeGuard de 400 us nao estoura com o decode em voo |
  trips_antes=0 trips_depois=1 narradas=5`, rodapé `355 checagens 1 falhas 48.913 s`. Re-corrida em
  seguida, árvore idêntica, nada mudado:
  [`runner_verde.log`](evidence/registro-integracao-fase2-22-23/runner_verde.log) linha **3918**
  `OK budget_do_oraculo: o SubtreeGuard de 400 us nao estoura com o decode em voo |
  trips_antes=0 trips_depois=0 narradas=5`, rodapé **3944** `355 checagens 0 falhas 49.089 s`,
  exit 0. **O par fica arquivado como está e nada foi silenciado**: o trip é marginal de tempo — o
  decode (`worst_decode_us` ≈ **780–787**, linha **3917** em ambas) caindo dentro da janela de
  400 µs do guard num único tick — e não reproduz com o código idêntico; a regra de reprodução
  (mandato do ciclo, item 3) fecha o vermelho como sensibilidade do instrumento, não como defeito
  de árvore, e nenhuma linha é escrita por causa dele.
- RNG: [`rng.log`](evidence/registro-integracao-fase2-22-23/rng.log) linha **78**
  (`27/27`, `27 checagens 0 falhas 2.704 s`).
- Journal: [`journal.log`](evidence/registro-integracao-fase2-22-23/journal.log) linha **143**
  (`128/128`, `128 checagens 0 falhas 7/7 testes concluidos 6.079 s`).

O número pineado para `aea325a` — e, por identidade de árvore, para `3919bbb` — é: suíte
**277/0/60,2 s**, runner **355/0/49,089 s** com o par do guard arquivado acima, RNG **27/0/2,704 s**
e journal **128/0/6,079 s**. As cinco `extensao_carrega_classe` saem verde em
[`runner_verde.log`](evidence/registro-integracao-fase2-22-23/runner_verde.log) **535–539** (o
descritor no disco, `is_library_open=true`, `class_exists(AfMindOracle)=true`,
`instantiate_valido=true`), os três números do §5.2 em **2596** e a régua do budget em **3917**
(`worst_sim_ms=14.04 ms`, média **2 496,3 µs/passo**, ambos abaixo do teto de 50 ms do passo) — a
mesma régua que fechou o pouso da Fase 2-22, agora na árvore que tem as duas pernas. O censo estreito
imprime **10 568** passos (`sim_step total=2 360 099 µs`, pico **5 134 µs**) e a matilha **1 341**
(`sim_tick total=3 300 436 µs`, pico **14 294 µs**, `trips=0`).

As três réguas rodaram na árvore composta (os docs combinados + a seção acima): a de âncoras dá
**40 arquivos · 3 280 ponteiros · 212 rótulos · 3 779 links** com **casos objetivos: 0**; a de
citações dá **1 191 conferidas · 0 fora do arquivo** no corpus de cinco páginas, exit 0; a de
identificadores, exit 0.

O scan de credencial no tip sai limpo (`git grep` pela chave do oráculo não encontra nada) e a
publicação é conferida por `git ls-remote --heads origin`:
`refs/heads/main = aea325ae15e3aa39ec68c09b868cbf8a92776d0b`. A branch remota da leg chuva fica
(`refs/heads/feat/elevacao-visual-chuva-23f2 = 955dc47…`) — é o registro do ajuste.

### O que a integração deixa aberto

Nenhum gate de fase fecha (mandato 4). O vermelho não-reprodutível do guard fica **registrado como
sensibilidade medida do instrumento**, com o par arquivado — e a janela de 400 µs contra um decode de
~780 µs é exatamente o material que a **Fase 5** (LOD e orçamento da perna 22) vai re-ler quando
escrever o `inspector_ve_a_mesma_leitura_do_journal`. Seguem as fases autorizadas como pauta, cada
uma com gate próprio e nenhuma linha antes de a anterior fechar o dela: **Fase 3** (adaptação por
bandit, gate `bandit_une_numero_observavel`), **Fase 4** (dona do **furo #46** e do consumidor da
quarentena no inspector) e **Fase 5**. Dos furos, **#38**, **#39**, **#20**, **#31**, **#41**,
**#44** e **#45** seguem como estão registrados; o par de vazamento do quit segue sem dono, agora
observado também nesta árvore com o número **4**. `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e
a projeção do `TickJournal` não foram tocados por nenhum dos dois merges. A fila serializada não
muda: **22 → 17 → 18 → 20 → 13**.
