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
| "`MindStore` + consolidação" | A **consolidação já existe** dentro de `Mind`: ao estourar `EPISODIC_CAP = 24` o átomo mais velho sai da fila e vira reforço de crença, com contador persistido — [mind.gd:7](../src/ai/mind.gd#L7), [:44-45](../src/ai/mind.gd#L44-L45), `:_consolidate` em [:61-68](../src/ai/mind.gd#L61-L68), save/load em [:148](../src/ai/mind.gd#L148) e [:157](../src/ai/mind.gd#L157). Não há tipo `MindStore` (grep em `src/`: zero ocorrências) | **metade feito**; o nome `MindStore` aponta para um store fora da entidade, que não existe |
| "`MindsInspector`" | Não existe. O que existe é o overlay de debug em texto: fps/processo/física, chunks e fila de malha, tick/`worst_step_ms`/ticks perdidos, totais por canal do Éter, posição e mira, e uma linha por lobo com a narrativa do oráculo — [hud.gd:245-281](../src/ui/hud.gd#L245-L281), tecla em [input_actions.gd:33](../src/input/input_actions.gd#L33) | **não existe**; a observabilidade mínima exigida por P1 está coberta em texto, não em inspector |
| "**hash de estado** e journal de tick são sagrados" | Agora há `TickJournal.state_hash()` e gravação JSONL de `[tick, hash]`, sob demanda ([tick_journal.gd](../src/persistence/tick_journal.gd)). A projeção mínima cobre semente/versão/dimensões, tick, edições, bytes completos do Éter e identidades/intenções/crenças das mentes vivas. `main._sim_tick` registra após incrementar o tick e dentro do cronômetro ([main.gd:243-249](../src/main.gd#L243-L249), cronometrado em [:218-220](../src/main.gd#L218-L220)) | **primitivo implementado, validação abaixo**; não cobre todo o estado da simulação nem registra comandos: replay permanece item 2 |
| "testes de determinismo: 20 sementes × 1000 ticks no cenário do lobo" | A suíte roda **uma** semente (`const SEED := 20261116` — [smoke_test.gd:10](../tests/smoke_test.gd#L10)) e a checagem determinística é uma só: 16 colunas de altura geradas duas vezes e comparadas — [smoke_test.gd:333-343](../tests/smoke_test.gd#L333-L343). Não há harness multi-semente em `tests/` | **falso hoje**; só faz sentido depois do hash |
| "budget HOT medido" | `SubtreeGuard` mede só a árvore e retorna falha no estouro — [bt_tree.gd:117-134](../src/ai/behavior/bt_tree.gd#L117-L134), default 250 µs; o lobo usa **400 µs** — [wolf.gd:253-254](../src/entities/wolf.gd#L253-L254). O F3 mostra custo/estouros — [wolf.gd:662-663](../src/entities/wolf.gd#L662-L663). O teste de rastros agora colhe `sim_step` integral e `last_us`/`trips`, com um lobo por cenário; não mede o agregado simultâneo da matilha | **parcial**; há colheita estreita, mas o HOT de cinco lobos e o gate P1 continuam abertos |
| "oráculo ainda é HTTP, não nativo — fortaleça sem fingir que é nativo" | Correto e verificado: `HTTPRequest` contra `http://127.0.0.1:8741`, timeout 8 s, recuo de 30 s, resposta vazia → recuo global sem tocar a decisão — [mind_oracle.gd:11-13](../src/ai/mind_oracle.gd#L11-L13), [:162-174](../src/ai/mind_oracle.gd#L162-L174). Desde a perna 15 o `503` de "carregando" tem recuo próprio de 2 s — `LOADING_COOLDOWN` ([:28](../src/ai/mind_oracle.gd#L28), aplicado em [:168-171](../src/ai/mind_oracle.gd#L168-L171)) — e um portão de prontidão que segura o pedido antes de o modelo estar no ar ([:39](../src/ai/mind_oracle.gd#L39), cobrado em [:77-81](../src/ai/mind_oracle.gd#L77-L81)). Um pedido em voo, round-robin pela matilha, prompt montado do estado interno — [:75-91](../src/ai/mind_oracle.gd#L75-L91), `_prompt_for` em [:131-148](../src/ai/mind_oracle.gd#L131-L148). Não há cache nem embeddings | **falso no projeto, certo no diagnóstico** |
| "reduza o acoplamento de `main.gd` / `wolf.gd` / memória" | Os números reais hoje (medidos nesta ponta): `main.gd` 662 linhas, `wolf.gd` 959, `player.gd` 769, `voxel_world.gd` 637, `mind.gd` 167, `aether_field.gd` 234, `smoke_test.gd` 2464; o journal é dono de seu arquivo e contadores. O acoplamento é estrutural, não de tamanho: `main.gd` é dono de mundo, relógio, matilha, HUD, oráculo, visualização, o nó de áudio e o hospedeiro do modelo ao mesmo tempo — [main.gd:30-42](../src/main.gd#L30-L42) | **válido**; medir por linhas é proxy, o que importa é o dono único |
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
| "Não quebrar determinismo ou a capacidade de hash/journal sem avisar" | O primitivo agora existe: ordenação de edições, identidades e crenças; Float32 integral do Éter; versão do formato; ticks consecutivos em arquivo novo. O save é deliberadamente diferente: filtra Éter e não conserva a origem das crenças. `diagnostics()` expõe custo e última assinatura ([main.gd:592-607](../src/main.gd#L592-L607)) | **salvaguarda do contrato mínimo**; preservar a projeção não equivale a tornar o jogo determinístico |
| "A mente propõe, as regras dispõem — LLM nunca decide movimento, dano, posição ou estado" | Verdade hoje por fiação, não por verifier: a única saída de `MindOracle` é `_narrations` — [mind_oracle.gd:47](../src/ai/mind_oracle.gd#L47), [:176](../src/ai/mind_oracle.gd#L176) — lida por `narration_of()` ([:96-97](../src/ai/mind_oracle.gd#L96-L97)) e entregue só ao HUD ([main.gd:142](../src/main.gd#L142) → [hud.gd:276-277](../src/ui/hud.gd#L276-L277)). Grep de `oracle`/`narration` em `src/` não acha nenhum outro consumidor: nem `Mind`, nem `Wolf`, nem o mundo leem o oráculo | **correto hoje**; o dia em que o oráculo *sugerir*, a sugestão entra como crença em quarentena (§04), não como intenção escrita |
| "Completar o mínimo de P1: AetherField, Mind, consolidação, observabilidade, testes de hash, budget" | Três dos seis existem: `AetherField` (com 3 dos 6 canais), `Mind` e a **consolidação** — mas esta vive dentro de `Mind`, não num `MindStore` à parte. Observabilidade há em texto (F3), inspector não; o primitivo de hash mínimo tem suíte própria, mas o cenário multi-semente ainda não existe; "budget" tem mecanismo e colheita estreita de um lobo, não do agregado HOT | **metade feito**; item por item nas linhas acima e na fila "Falta" |
| "Melhorar a degradação e a robustez do oráculo atual (ainda HTTP)" | Correto no diagnóstico, e a degradação já é checada sem rede — sonda apontada para a porta 1 em [smoke_test.gd:2081-2086](../tests/smoke_test.gd#L2081-L2086). O caminho feliz depende de `llama-server` de fora e não é testável em headless | **correto**; está dentro do escopo autorizado |
| "Repositório: github.com/DouglasGDev/aetherfall" | `origin` confere. Publicação re-confirmada em `42799fa` — o `push` devolveu `1db00cf..42799fa main -> main` e `git ls-remote --heads origin` respondeu `42799fa0f0987b20d58902b4b2f7a4927a93cfd2 refs/heads/main` em 2026-11-19, o mesmo SHA do `HEAD` local. Os seis blocos desta revisão (som, journal, RNG, rastros, mão e porte em 3ª pessoa) estão todos no remoto; a confirmação anterior, de 2026-11-18, parava em `1db00cf` com hash/journal e rastros ainda locais | **correto**; publicação se confirma por `ls-remote`, nunca pelo código 0 do `push` |
| "Ao final de um bloco, atualize ou proponha atualização de `docs/melhorias-status.md`" | É este arquivo, com as seções que o prompt pede (feito / em andamento / falta / backlog / débitos / furos / notas) | **correto**; já é a prática da casa, e agora está escrita em [`AGENTS.md`](../AGENTS.md) |

### O prompt de disciplina de otimização × o código

Terceiro mandato, aplicado com as duas regras da casa: nada de adjetivo onde cabe número, e
nada de otimização onde ainda não há medição. As regras anti-bloat não são afirmações de
estado, então não têm linha aqui — o que tem linha é o instrumento e o custo que ele mostra.

| O que o prompt afirma | O que está em `src/` hoje | Veredicto |
|---|---|---|
| "Meça antes de otimizar: use dados reais (Profiler, tempo de tick, contagem de objetos, alocações)" | Tempo de tick: medido e publicado — `last_step_ms`/`worst_step_ms`/`dropped_ticks` ([sim_clock.gd:12-14](../src/core/sim_clock.gd#L12-L14)) cronometrados em µs dentro de [main.gd:218-220](../src/main.gd#L218-L220). Tempo de frame: `TIME_PROCESS` e `TIME_PHYSICS_PROCESS` só no F3 ([hud.gd:248-251](../src/ui/hud.gd#L248-L251)). **Contagem de objetos e de alocações: nenhum monitor do engine é lido no repositório inteiro** (grep de `Performance.`: duas linhas, as duas acima) | **parcial**; o "Profiler" da casa é SimClock + `SubtreeGuard` + F3, e a coluna de alocação não existe como número |
| "Otimize o que dói agora" | A dor está medida e é o boot: geração 936-962 ms e malharia 4.640-4.886 ms com a janela congelada, contra **pior passo de 7,56 a 11,21 ms num orçamento de 50 ms** e `dropped_ticks = 0` nas cinco corridas (`.tools/suite_fix1.log` … `suite_fix4.log`, `.tools/pub-suite.log`) | **correto, e já respondido**: o hot path de simulação não é a dor de hoje; o precedente medido é o mesher, que caiu de ~16 s para ~7,5 s com índice linear |
| "Hot path tem regra diferente: o que roda a cada tick (20 Hz) precisa ser barato" | Decisão/difusão são agendadas pelo relógio de 20 Hz ([sim_clock.gd:5-7](../src/core/sim_clock.gd#L5-L7)); o jogador atualiza por frame de física ([main.gd:215](../src/main.gd#L215)) e lavra/colocação alteram mundo e Éter fora do tick. Locomoção e timers dos lobos também mudam por frame ([wolf.gd:526-571](../src/entities/wolf.gd#L526-L571)). Com gravação ativa, cópia/ordenação/hash/escrita/flush entram no tick e têm custo medido nas notas abaixo; "só o tick toca o mundo" ainda não é verdade | **correto no relógio, incompleto na autoridade**; é o §06 (dedicado) que cobra essa conta |
| "Alocação é cara: evite arrays, dicionários, objetos e strings no tick quente" | O blackboard é um `Dictionary` novo por lobo por tick ([wolf.gd:622](../src/entities/wolf.gd#L622), 100/s no teto de matilha viva); a difusão aloca um `PackedInt32Array` por canal por passada ([aether_field.gd:122](../src/world/aether_field.gd#L122), 3 a cada 0,25 s). O cache novo chama `keys()` a cada scan e nas expulsões ([wolf.gd:671](../src/entities/wolf.gd#L671), [:413](../src/entities/wolf.gd#L413)). Os tempos de `sim_step` não isolam essas alocações | **válido como restrição**; primeiro a colheita de alocação, não otimização alegada por contagem teórica |
| "LOD é obrigatório em sistemas de IA/simulação" | Não há LOD por distância: os lobos vivos rodam a árvore inteira a cada tick. O que há é throttle temporal — difusão e visão 4×/s, cadáveres 1×/s ([main.gd:12-16](../src/main.gd#L12-L16)) — e varredura de rastros a cada 0,25 s ([wolf.gd:446-447](../src/entities/wolf.gd#L446-L447)), com nova leitura após inspeção | **falso hoje**; a peça tem nome no design (`HotSet`/Véu, §04 e §06) e é P2: sem custo em log, é backlog, não tarefa |
| "Budget explícito: defina e respeite orçamentos de tempo (ex.: HOT minds ≤ X ms)" | Quatro orçamentos são código: 50 ms por passo com teto de 5 passos por frame ([sim_clock.gd:19-29](../src/core/sim_clock.gd#L19-L29)), 400 µs por árvore ([wolf.gd:253-254](../src/entities/wolf.gd#L253-L254); default da classe, 250 µs, em [bt_tree.gd:117-120](../src/ai/behavior/bt_tree.gd#L117-L120)), 2 chunks de malha por frame ([main.gd:13](../src/main.gd#L13)) e 0,25 s de difusão. O "≤ 2,5 ms" do gate de P1 continua `[TARGET]` no §08, e a aritmética (5 × 400 µs = 2 ms) cabe nele sem que nenhum log mostre a soma | **parcial**; orçamento por peça existe, o agregado do gate é alvo sem medição |
| "Observabilidade > micro-otimização cega: se não dá para medir, não dá para saber se melhorou" | Para o tick, dá: a última linha do diagnóstico da suíte publica `pior passo` e `perdidos` ([smoke_test.gd:2297-2299](../tests/smoke_test.gd#L2297-L2299)). Frame e fila de malha só aparecem em janela; BT agora tem colheita no cenário estreito de rastros, sem equivaler ao agregado HOT; custo de alocação não é medido. Hash/escrita/flush agora têm contadores próprios no diagnóstico do journal | **é o débito da colheita de custo**, e é o que trava as cinco linhas acima de virarem otimização |

## Feito nesta sessão

- **Rotinas de alcateia: a matilha entra na decisão do lobo (dossiê 10).** O lobo lê a matilha por um
  `pack_provider` injetado pela sessão ([wolf.gd:116](../src/entities/wolf.gd#L116), montado em
  [main.gd:288](../src/main.gd#L288) com a identidade presa) e a sessão faz **uma** passada por
  passo: cada par `i<j` testado uma vez contra `PACK_COHESION_RADIUS` de 24 m
  ([main.gd:24](../src/main.gd#L24), `_rebuild_packs` [[:352-372](../src/main.gd#L352-L372)]) e
  escrito nos dois buffers; `pack_of` ([:283-285](../src/main.gd#L283-L285)) devolve a lista e o lobo
  só lê (`_read_pack` em [wolf.gd:591-592](../src/entities/wolf.gd#L591-L592), chamado em
  [:617](../src/entities/wolf.gd#L617)). Cinco comportamentos mudam com essa leitura: **ronda** em
  torno do baricentro da matilha com uma fatia angular por rank
  (`_leaf_wander` [[:417-435](../src/entities/wolf.gd#L417-L435)], `_territory_center`
  [[:459](../src/entities/wolf.gd#L459)], `_territory_rank` [[:473](../src/entities/wolf.gd#L473)]);
  **cerco** com assento `TAU/n`, em que `n` conta quem está em `hunt` de fato
  (`_hunt_pack_size` [[:327](../src/entities/wolf.gd#L327)], `_seat_point`
  [[:350-353](../src/entities/wolf.gd#L350-L353)] a 1,50 m da presa por `ENCIRCLE_RING`
  [[:39](../src/entities/wolf.gd#L39)]); **mordida escalonada** por `clock.tick % n == rank`
  (`_bite_turn` [[:525-529](../src/entities/wolf.gd#L525-L529)], chamada em
  [:506](../src/entities/wolf.gd#L506)); **contágio do medo** — vizinho em `flee` soma `0,55` no
  `_fear_level` do observador ([`_sense` 641-650](../src/entities/wolf.gd#L641-L650),
  `PACK_PANIC_FEAR` [[:53](../src/entities/wolf.gd#L53)]); e **amortecimento por confiança** —
  vizinho com `trust ≥ 0,35` corta `0,9` do `_courage` e fecha a porta de `hunt`
  ([:646-655](../src/entities/wolf.gd#L646-L655); a confiança vem de `take_damage`, único chamador de
  `adjust_trust(-0,35)` [:818](../src/entities/wolf.gd#L818)). O vizinho **não escreve** no lobo: cada
  um soma o que a sessão devolve, e sem provedor a lista é `NO_PACK`
  ([[:43](../src/entities/wolf.gd#L43)]) — os números do lobo solitário são literalmente os de antes,
  que é o que a checagem `lobo sem provedor nao le matilha` exige. Runner de **119 para 150
  checagens** e de **24 para 30 cenários**
  ([aether_reactions_test.gd:20](../tests/aether_reactions_test.gd#L20)); suíte de **237 para 239**
  com duas checagens novas na sessão real ([smoke_test.gd:253](../tests/smoke_test.gd#L253),
  [:241](../tests/smoke_test.gd#L241)). Verdes, vermelhas e limites, com log por número:
  [evidence/alcateia-rutinas/](evidence/alcateia-rutinas/). **O que a sessão real ainda não exercita
  é o furo #16**: com cinco lares espalhados o raio de coesão devolve no máximo um vizinho
  (`maior_matilha_lida=1`), então cerco, contágio e ronda por setor estão provados em fixture de
  quatro lobos próximos, não no vale — e isso é trabalho da perna 14.

- **Bioma como código, pelo por bioma e viés de imprint (dossiê 09).** `WorldGen` ganha
  `enum Biome` + `biome_of(x, z, h)` ([world_gen.gd](../src/world/world_gen.gd)) e
  `surface_block` passa a consultá-la — a regra fica uma vez só, e nenhum bloco muda de byte: é o
  que a checagem nova da suíte (`bioma_nao_altera_terreno`) confere contra quatro assinaturas
  pinadas de `e7e30e6`, incluindo os 1 048 576 voxels do mundo, porque a amostra de 32 × 32 passou
  verde sobre uma sabotagem de umidade deliberada. O lobo pergunta o bioma do `home` uma vez no
  `setup` ([:189](../src/entities/wolf.gd#L189), re-derivado no `load_state` [:881](../src/entities/wolf.gd#L881))
  e pinta o pelo da tabela `FUR_COLORS` ([:90](../src/entities/wolf.gd#L90)) antes de montar o visual. O terceiro
  item da peça — "fundo de Éter por bioma" — entra como **viés de imprint**: o chamador do evento
  multiplica pelo valor lido de `IMPRINT_BIAS`
  (`_imprint` em [wolf.gd:220-222](../src/entities/wolf.gd#L220-L222) e
  [main.gd:420-422](../src/main.gd#L420-L422)), em 11 sítios; a folha de fuga fica **de fora** por
  custo, com o motivo escrito no código ([:249](../src/entities/wolf.gd#L249)) porque roda todo tick
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
  `avatar.block_id = selected_block()` ([player.gd:402](../src/entities/player.gd#L402)) e o
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
  ([main.gd:149-153](../src/main.gd#L149-L153)), assina seis sinais do jogador no `setup`
  ([:146-155](../src/audio/audio_director.gd#L146-L155)) e três por lobo no spawn
  ([:158-162](../src/audio/audio_director.gd#L158-L162), chamado em
  [main.gd:295-296](../src/main.gd#L295-L296)). É a metade "consumidor" do pedido: o
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
  [main.gd:295-296](../src/main.gd#L295-L296) e a corrida refaz **27 / 0**), e a sonda viva
  contava *famílias novas*, sempre vazio porque os lobos já andavam durante o boot — hoje conta
  incremento por família. O que **não** foi feito de propósito: nenhum som escreve no Éter,
  então o canal SOM do item 4 continua aberto, e o `stop()` de saída não apaga a mensagem de
  vazamento do engine no quit (débito abaixo, com a causa medida em dois braços).
  [Notas completas](#som--publicado-em-a8967e0).

- **Item 2, primeiro recorte — o sorteio tem dono.** `main.gd` e `wolf.gd` eram os únicos
  consumidores do gerador global do Godot; hoje o grep de `randf`/`randi`/`randi_range` sem
  receptor em `src/` devolve zero ocorrências. A matilha é sorteada por `_population_rng`
  ([main.gd:49](../src/main.gd#L49), semeado em [:279-280](../src/main.gd#L279-L280), usado em
  [:243-244](../src/main.gd#L243-L244)) e cada lobo por `_rng`
  ([wolf.gd:123](../src/entities/wolf.gd#L123), semeado em [:191](../src/entities/wolf.gd#L191),
  usado na patrulha ([:425](../src/entities/wolf.gd#L425) e [:442-443](../src/entities/wolf.gd#L442-L443))
  e no desvio ([:766-767](../src/entities/wolf.gd#L766-L767)); a semente dos dois vem da semente real do
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
  escolhido entre os vivos ([smoke_test.gd:1806-1810](../tests/smoke_test.gd#L1806-L1810),
  `_alive_wolf()`), a premissa do jogador é montada pelas transições do próprio jogo —
  `respawn_at` e `close_panel`, não campo escrito à mão
  ([smoke_test.gd:1849-1856](../tests/smoke_test.gd#L1849-L1856)) — e o resto da matilha é
  estacionado fora da linha de mira
  ([smoke_test.gd:1863-1877](../tests/smoke_test.gd#L1863-L1877)). A checagem nova
  `mira travada no lobo do passo` ([smoke_test.gd:1878-1884](../tests/smoke_test.gd#L1878-L1884))
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
pela extensão (3), abaixo deste parágrafo e no contrato; nesta ponta, concluídas são **duas** — 09 e 10.

## Falta

Por dependência, não por preferência (cada item aberto tem um dossiê de leitura em [`docs/planos/`](planos/README.md): premissa nomeada, estado do código com `arquivo:linha`, gate headless e custo pelas quatro perguntas — nenhum dossiê rodou a engine e nenhum fecha gate):

1. **Primitivo de hash de estado por tick — concluído e validado nesta máquina.** Implementado em
   [tick_journal.gd](../src/persistence/tick_journal.gd), com contrato, testes e medições abaixo.
   Mantida a numeração original para não mudar as dependências da fila.
2. **Diário de tick sobre a simulação — um recorte concluído e validado nesta máquina.** O journal mínimo
   registra somente `[tick, hash]`. O sorteio deixou de ser o gerador global: a sessão tem
   `_population_rng` ([main.gd:49](../src/main.gd#L49), sorteado em
   [:243-244](../src/main.gd#L243-L244)) e cada lobo tem `_rng`
   ([wolf.gd:123](../src/entities/wolf.gd#L123), semeado em
   [:191](../src/entities/wolf.gd#L191), usado na ronda
   ([:425](../src/entities/wolf.gd#L425), [:442-443](../src/entities/wolf.gd#L442-L443)) e no
   desvio ([:766-767](../src/entities/wolf.gd#L766-L767)).
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
   400 µs é o configurado em [wolf.gd:253-254](../src/entities/wolf.gd#L253-L254). Gate subtrativo: nenhuma mente nova entra
   antes do budget da existente estar escrito.
6. **Difusão do Éter fora do tick de decisão.** Hoje a difusão roda na passada do relógio
   ([main.gd:12](../src/main.gd#L12) `AETHER_PERIOD 0.25`); com 6 canais e a malha competindo,
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
   `e7e30e6`. A cor do pelo vem do bioma do `home` ([wolf.gd:90](../src/entities/wolf.gd#L90),
   aplicada em [:925](../src/entities/wolf.gd#L925)). O "fundo" entrou como **viés de imprint**
   (`IMPRINT_BIAS` em [world_gen.gd:45](../src/world/world_gen.gd#L45), lido em
   [:156-157](../src/world/world_gen.gd#L156-L157), multiplicado pelo chamador), que é a forma que o
   dossiê §3.3 escolheu: o campo continua sem saber de mundo. Fica **de fora** e aberto: a avaliação
   visual em janela (a galeria não foi re-bakeada, e o dossiê §6 proíbe prometer "bioma deserto" sem
   re-bake), o bioma lido por outras peças além do pelo e do imprint, e o cenário multi-semente (item
   3). Medição, sabotagens e limites:
   [evidence/bioma-cor-de-pelo/readback.md](evidence/bioma-cor-de-pelo/readback.md).
9. **Rotinas de alcateia — concluído nesta máquina (dossiê 10; mantida a numeração para não mexer
   nas dependências da fila).** A árvore deixou de ser de um lobo solitário: o `Selector[flee, hunt,
   sniff, patrol]` ([wolf.gd:253-254](../src/entities/wolf.gd#L253-L254)) continua a mesma forma, e o
   que mudou é o que entra nas folhas. O lobo recebe a matilha por `pack_provider`
   ([wolf.gd:116](../src/entities/wolf.gd#L116), montado em [main.gd:288](../src/main.gd#L288)), lê
   uma vez por passo ([:591-592](../src/entities/wolf.gd#L591-L592), chamado em
   [:617](../src/entities/wolf.gd#L617)) e o contexto do escorredor leva o pacote
   ([:584](../src/entities/wolf.gd#L584), `["_pack", "pack_panic", "pack_trust", ...]`). Ronda sai do
   `home` individual e vai para o baricentro com fatia por rank
   ([:417-435](../src/entities/wolf.gd#L417-L435), [:459](../src/entities/wolf.gd#L459),
   [:473](../src/entities/wolf.gd#L473)); o cerco tem assento angular função de quem caa
   ([:327](../src/entities/wolf.gd#L327), [:350-353](../src/entities/wolf.gd#L350-L353)); a mordida é
   escalonada pelo `clock.tick` ([:525-529](../src/entities/wolf.gd#L525-L529)); o medo do vizinho
   soma no `_fear_level` ([:641-650](../src/entities/wolf.gd#L641-L650)) e a confiança do vizinho
   amansa o `_courage` ([:646-655](../src/entities/wolf.gd#L646-L655)). Continua **aberto** e não é
   deste item: a memória compartilhada *entre matilhas* — `Mind.relations` ainda é confiança por
   **ator** ([mind.gd:20](../src/ai/mind.gd#L20), [:126-131](../src/ai/mind.gd#L126-L131)), não por
   matilha, e nada decide se a lembrança de um vizinho ajuda o jogador; o HOT agregado dos cinco
   lobos (item 5); a água como último recurso, o spawn fora dos olhos do jogador e os avisos de
   criatura na tela (item 12, dossiê 14); e `MindsInspector`, que não existe (dossiê 08) — sem ele a
   matilha lida se lê no log do runner, não no F3. E a sessão real ainda não exerce o que a fixture
   prova: furo #16.
10. **Acasalamento, filhote que cresce e censo variável** (dossiê 11). A população é uma constante
    ([main.gd:9](../src/main.gd#L9) `WOLF_COUNT := 5`) e a fila de respawns só repõe
    ([main.gd:241](../src/main.gd#L241) `_spawn_wolves(1)`). Não existe idade, filhote nem corpo
    menor: `DIMS` é constante ([wolf.gd:72](../src/entities/wolf.gd#L72)). O load pareia por índice
    com teto — [`for i in mini(saved.size(), wolves.size())`](../src/main.gd#L507) — então um censo
    que cresce hoje **descartaria filhote em silêncio**, e
    [tests/tick_journal_test.gd:78](../tests/tick_journal_test.gd#L78) exige
    `wolves.size() == Main.WOLF_COUNT`: as duas peças são re-derivadas junto, não depois.
11. **Bicho cavando voxel** (dossiê 12). A lavra contínua do jogador **já existe e já tem gate**:
    segurar `break_block` soma progresso por frame até a dureza
    ([player.gd:636-647](../src/entities/player.gd#L636-L647)), o drop do registro entra direto no
    inventário ([player.gd:659-672](../src/entities/player.gd#L659-L672)), e a suíte confere as três
    promessas ([tests/smoke_test.gd:896-904](../tests/smoke_test.gd#L896-L904) — "segurar break
    minerou", "tempo de mineracao == dureza", "lavra entrou no inventario como drop"). O buraco real
    é do outro lado: os únicos dois `world.set_block` de gameplay no `src/` são os do jogador
    (`:667`, `:693`) e o `_on_acted` que imprime WORK é sinal do jogador
    ([main.gd:425-430](../src/main.gd#L425-L430)). Nenhum animal escreve no mundo.
12. **Convivência da alcateia: ronda em terra, nenhum aviso de criatura na tela, spawn fora dos
    olhos do jogador** (dossiê 14; **executa entre o item 9 e o item 10** pela ordem serializada
    registrada em [`AGENTS.md`](../AGENTS.md), e a numeração fica no fim para não renumerar a fila).
    Três buracos lidos, cada um com o número que o define. (a) Aviso de criatura **existe**:
    [`hud.show_message("uma nova matilha entrou no vale")`](../src/main.gd#L242) e
    [`hud.show_message("o lobo caiu  o sangue fica no eter")`](../src/main.gd#L483) são os únicos
    dois textos que noticiam *quem está no mundo* — os outros dez sítios de `show_message`
    (`:135`, `:273`, `:451` repassando `player.notice` de
    [player.gd:309](../src/entities/player.gd#L309)/`:664`/`:682`, conectado em
    [main.gd:121](../src/main.gd#L121), `:524`, `:526`, `:532`, `:536`, `:572` e
    [hud.gd:603](../src/ui/hud.gd#L603)/`:605`) são feedback de ação do próprio jogador ou
    diagnóstico de save, e ficam. (b) O spawn **não sabe onde o jogador está**:
    `_random_ground_point(16.0, 46.0)` ([main.gd:300-314](../src/main.gd#L300-L314)) sorteia o anel
    em torno de `spawn_point()` ([:206-209](../src/main.gd#L206-L209)), o centro fixo do mundo, e não
    o ponto onde o jogador acordou nem para onde ele caminhou; exige coluna seca
    (`y > VoxelConfig.SEA_LEVEL`) e volume livre (`_volume_clear`
    [:322-324](../src/main.gd#L322-L324)), **não** consulta posição atual nem
    `world.line_of_sight` ([voxel_world.gd:393](../src/world/voxel_world.gd#L393)), e depois de 24
    tentativas cai em silêncio no centro. A distância de 16 m é, hoje, acidental no boot — o
    jogador nasce no centro — e inexistente depois que ele anda. (c) A água é evitada por **uma
    folha de cinco**: `_leaf_wander` ([wolf.gd:324-342](../src/entities/wolf.gd#L324-L342)) rejeita
    ponto molhado via `_dry_ground` ([:482-487](../src/entities/wolf.gd#L482-L487)) e `SHORE_AFTER`
    de 2,0 s ([:79](../src/entities/wolf.gd#L79), aplicado em `sim_step`
    [:608-616](../src/entities/wolf.gd#L608-L616) com `_shore_point`
    [:490](../src/entities/wolf.gd#L490)) resgata quem ficou nadando, mas `_leaf_flee`
    ([:285](../src/entities/wolf.gd#L285)), `_leaf_chase` ([:308](../src/entities/wolf.gd#L308)),
    `_leaf_stalk` ([:356](../src/entities/wolf.gd#L356)) e `_leaf_investigate`
    ([:369](../src/entities/wolf.gd#L369)) escolhem alvo sem nenhum teste de solo — correr atrás do
    jogador através do lago e farejar no leito são alcançáveis hoje. O "não parecer desorganizado"
    **não** é comportamento novo: assento angular e mordida escalonada são do dossiê 10, e esta
    perna não reabre o que ele fecha.
13. **Árvore genealógica de todo ser vivo, com o Éter trabalhando isso** (dossiê 13; **executa por
    último**, depois do item 12). O recorte lido antes de prometer nível: `src/entities/` são
    [`player.gd`](../src/entities/player.gd),
    [`player_avatar.gd`](../src/entities/player_avatar.gd),
    [`fp_viewmodel.gd`](../src/entities/fp_viewmodel.gd),
    [`voxel_body.gd`](../src/entities/voxel_body.gd) e
    [`wolf.gd`](../src/entities/wolf.gd) — **nenhum NPC** e **uma única
    espécie animal**, então a escada animal→humano fica `[TARGET]` até existir o segundo comprador.
    O que falta é o primitivo: a personalidade de cada lobo é sorteada da semente **dele mesmo**
    (`Mind._init` [mind.gd:24-32](../src/ai/mind.gd#L24-L32), chamado com `1000 + identity` em
    [wolf.gd:193](../src/entities/wolf.gd#L193)) e nenhum pai contribui com um valor; o pelo vem do
    bioma do lar ([wolf.gd:90-95](../src/entities/wolf.gd#L90-L95), `home_biome`
    [:189](../src/entities/wolf.gd#L189), re-derivado no load [:881](../src/entities/wolf.gd#L881)),
    não de herança; `state_dict` ([:869-874](../src/entities/wolf.gd#L869-L874)) não tem chave de
    ascendência e nada em `src/` guarda quem é filho de quem. O guard-rail do Éter vai registrado
    junto do dossiê, não descoberto depois: canal novo no campo (`Channel.COUNT` em
    [aether_field.gd:9](../src/world/aether_field.gd#L9)) ou campo novo na projeção do journal
    ([tick_journal.gd:16-44](../src/persistence/tick_journal.gd#L16-L44), `FORMAT_VERSION`
    [:4](../src/persistence/tick_journal.gd#L4)) muda os hashes que as rodadas publicadas registram
    — é decisão de versão, não detalhe de implementação.

## Backlog priorizado (P0 → P1)

**P0 — fundação determinística** (gate atual: nenhum fechado)
- [x] `state_hash()` mínimo + JSONL `[tick,hash]` sob demanda (item 1, validado nesta máquina).
- [ ] Estado inicial completo, comandos/RNG e ordem autoritativa para replay (item 2).
- [ ] `af-bench --scenario boot_walk_10min` com hash estável em 3 execuções.
- [ ] bake-off de voxel decidido com números (as alturas já estão certas: geração 942 ms e
      malha 4682 ms no boot medido; falta a comparação entre abordagens, não o número).
- [ ] `docs/engine/simclock.md` derivado de [sim_clock.gd](../src/core/sim_clock.gd).

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
  nem `main.diagnostics()` ([:592-607](../src/main.gd#L592-L607)), que tem `journal` e não tem
  `audio`. Só o teste headless e a sonda em janela leem esses números hoje.
- **A sonda viva de áudio não é testável em CI:** `audio_live_probe.tscn` exige janela e um
  endpoint de render aberto. A mesma árvore, na mesma máquina, deu WASAPI em uma corrida e
  `ERR_CANT_OPEN` → `Dummy` em outra ([live-2-red-dummy.log](evidence/audio/live-2-red-dummy.log)), e a checagem do driver pegou a
  diferença. É o mesmo formato de débito do gate do oráculo: caminho feliz existe, mas não é
  reproduzível sem o hardware de quem executa.

- **O smoke usa o slot real `alpha` e não o preserva**
  ([smoke_test.gd:2181-2204](../tests/smoke_test.gd#L2181-L2204)). Nesta validação, os
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
  O blackboard por tick ([wolf.gd:622](../src/entities/wolf.gd#L622)), as listas temporárias
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
- **Dois scripts de áudio não têm o `.uid` no índice.** `src/` + `tests/` somam 37 `.gd` e o
  índice rastreia 35 `.uid`; faltam exatamente `tests/audio_test.gd.uid` e
  `tests/audio_live_probe.gd.uid`, que na árvore de trabalho nem existem. No clone limpo o
  `--import` os cria e o `git status` os mostra como não-rastreados
  (linha `clone_sidecars` da [conferência](evidence/third-person-carry/readback.log)). Nada
  quebra: nenhum `.tscn` de `tests/` referencia script por `uid://` —
  `audio_live_probe.tscn` usa `path="res://tests/audio_live_probe.gd"` — e o `--script` resolve
  por caminho. Não entraram neste commit porque o manifesto pinado descreve **79 arquivos** e
  re-pinar sem corrida nova em cima do conjunto re-pinado é o que a regra 6 proíbe; a correção
  pertence ao próximo bloco que já tiver de re-medir por outro motivo.
- **O gate do oráculo depende de um servidor local de fora**: `live_oracle_probe.tscn` exige o
  `llama-server` de pé; a degradação é testada sem rede ([smoke_test.gd:2081-2086](../tests/smoke_test.gd#L2081-L2086),
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
     do alvo (`targets_under_crosshair()` só devolve vivos — [main.gd:327-332](../src/main.gd#L327-L332) —
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
     [player.gd:589-625](../src/entities/player.gd#L589-L625)) e o golpe foi no lobo que a
     simulação ao vivo deixou ali. A corrida vermelha natural tem a mesma digital:
     `intento=... hunt` no passo de mente e `hp=66.0` no diagnóstico final — matilha em cima do
     jogador parado, estado que o próprio suíte já documentava
     ([smoke_test.gd:230-238](../tests/smoke_test.gd#L230-L238)).
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
   `if not alive: return` ([wolf.gd:624-626](../src/entities/wolf.gd#L624-L626)) — um lobo já
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
    perna 10 pôs na sessão verdadeira ([smoke_test.gd:253](../tests/smoke_test.gd#L253),
    [:241-244](../tests/smoke_test.gd#L241-L244)) dão verde com o vale inteiro assim:
    `pares=10 esperado=10 maior_matilha_lida=1 lobos_vivos=5`
    ([evidence/alcateia-rutinas/pos-merge-suite.log:23-24](evidence/alcateia-rutinas/pos-merge-suite.log)).
    Duas leituras erradas cabem nessa linha. A primeira: `pares=10` **não** são pares coesos, são as
    **comparações** `i<j` que a passada da sessão avalia — `_pack_pairs += 1` roda em todo par
    testado, dentro ou fora do raio ([main.gd:366](../src/main.gd#L366), dentro de `_rebuild_packs`
    [:292-313](../src/main.gd#L292-L313)), e `10 = 5·4/2` é justamente o total de combinações de
    cinco lobos, ou seja: o número é teto de trabalho, nunca de matilha formada. A segunda, e é o
    furo: `maior_matilha_lida` é o maior `_pack.size()` entre os lobos, e `_pack` **não** conta o
    próprio lobo — então `1` significa "um lobo viu **um** vizinho", e a asserção é `biggest >= 1`
    ([:242](../tests/smoke_test.gd#L242)). Com os cinco lares espalhados como o spawn os sorteia,
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
  ([wolf.gd:597-622](../src/entities/wolf.gd#L597-L622)).
- O alvo do rastro é a **primeira superfície sólida descendo do topo da camada
  encontrada**, e não o topo da coluna: `surface_height()` dentro de caverna devolveria o
  teto, e o episódio lembrado diria que o sangue estava na superfície
  ([wolf.gd:689-697](../src/entities/wolf.gd#L689-L697)).
- A folha retorna `RUNNING` durante aproximação e inspeção, para a até **1,2 m**
  horizontais e exige **2 s** de inspeção antes do episódio. Troca de alvo, perda do
  rastro, outra intenção ou atordoamento cancelam o timer
  ([wolf.gd:249-277](../src/entities/wolf.gd#L249-L277)).
- Cache de **32 células/lobo**, força ponderada e validade de **30 s**: uma visita grava
  até nove células vizinhas **da camada encontrada**, com duas leituras por célula válida.
  Novo aumento de **0,06** ponderado ou expiração reabre a célula. `keys()` aloca no scan e
  na expulsão; esse custo de alocação não foi isolado
  ([wolf.gd:373-387](../src/entities/wolf.gd#L373-L387),
  [:466-506](../src/entities/wolf.gd#L466-L506)).
- O F3 expõe reação, canal, célula, força e tamanho do cache
  ([wolf.gd:830-835](../src/entities/wolf.gd#L830-L835)). O episódio usa ator **0**;
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
  Há locomoção e timers de lobo por frame ([wolf.gd:526-571](../src/entities/wolf.gd#L526-L571)),
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
  `wolf.identity` e limpo no load ([main.gd:564](../src/main.gd#L564),
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
  ([smoke_test.gd:1196-1200](../tests/smoke_test.gd#L1196-L1200)) porque a órbita de trás só
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

**O corte, em três decisões.** `_population_rng` ([main.gd:49](../src/main.gd#L49)) sorteia as
casas da matilha; `_rng` ([wolf.gd:123](../src/entities/wolf.gd#L123)) sorteia patrulha e desvio.
As sementes vêm de `("population:%d" % world.gen.world_seed).hash()` e
`("wolf:%d:%d" % [world.gen.world_seed, identity]).hash()` — a semente *real* do mundo, de 64
bits, em vez do inteiro de 32 bits do engine. O gerador da população só é semeado quando
`_next_identity == 0` ([main.gd:219-220](../src/main.gd#L219-L220)), para que um lote de respawn
continue o fluxo em vez de repetir as primeiras casas. O grep de `randf`/`randi`/`randf_range`
sem receptor em `src/` devolve zero ocorrências; sobram dois locais com gerador próprio
([mind.gd:30-32](../src/ai/mind.gd#L30-L32), [voxel_atlas.gd:50-63](../src/world/voxel_atlas.gd#L50-L63))
e o `seed(SEED)` de [tests/aether_reactions_test.gd:168](../tests/aether_reactions_test.gd#L168),
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
([smoke_test.gd:692-695](../tests/smoke_test.gd#L692-L695), :699-702, :709-712; o `teto de
valor aplicado` de :704-706, que já existia, fica fora): `nenhuma passada cria massa`, `saldo
fecha com o corte de MIN_VALUE`, `o corte da fronteira explica a perda alem da meia-vida`, `teto
nao injeta o excedente no campo`. A previsão é em cadeia, passada a passada, sem releitura
([:693-706](../tests/smoke_test.gd#L693-L706)): o que sai no corte não decai mais, então o saldo
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
([:412-413](../src/entities/wolf.gd#L412-L413)) é caminho nunca exercitado, e cobertura de rastros é
promessa do slice: "o cache está limitado a 32" só quer dizer alguma coisa depois de medir se ele
chega lá. O bloco começou pela colheita.

### O que entrou

Décimo oitavo cenário do runner dedicado, `_test_cache_cap`
([aether_reactions_test.gd:713-813](../tests/aether_reactions_test.gd#L713-L813)): seis fontes reais
de WORK na grade de células 11/14/17 × 13/16, 12 m por salto, com amplitudes decrescentes
`0,84 → 0,54` para que a ordem de visita saia da regra de seleção — o máximo de
`BLOOD + 0,35 × WORK` entre as células não cacheadas
([:466-506](../src/entities/wolf.gd#L466-L506)) — e não de uma imposição do teste. O cenário colhe,
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
([wolf.gd:562-566](../src/entities/wolf.gd#L562-L566)): re-arma `_unstick` (0,35–0,8 s) e `_detour`
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
[:98](../src/entities/voxel_body.gd#L98) → [wolf.gd:738](../src/entities/wolf.gd#L738)). Nada
disso era corrida. O ciclo de trabalho (item 3) exige os dois sentidos da atribuição antes do
conserto, e a linha de base estava declarada: `metros_por_salto=24.8 progressao=0.957`.

### O que entrou

Décimo nono e vigésimo cenários do runner dedicado — `_test_locomotion_flat`
([aether_reactions_test.gd:816-906](../tests/aether_reactions_test.gd#L816-L906), quatro
checagens) e `_test_locomotion_wall`
([:910-1003](../tests/aether_reactions_test.gd#L910-L1003), cinco) — mais os dois consertos que
eles decidem:

- **o flag dividido**: `blocked_horizontal` nasce ao lado de `blocked_this_frame`
  ([voxel_body.gd:21-24](../src/entities/voxel_body.gd#L21-L24)), é marcado só nos eixos de andar
  ([`:99-100`](../src/entities/voxel_body.gd#L99-L100)) e é **esse** que o passo do lobo lê para
  re-armar o desvio ([wolf.gd:738](../src/entities/wolf.gd#L738));
- **a caixa testada volta a ser a caixa aplicada**: o `box.size.x -= WALL_SHAVE` saiu de
  `_translated` ([voxel_body.gd:118-129](../src/entities/voxel_body.gd#L118-L129)), com o porquê
  e o número measured na linha de cima ([`:108-117`](../src/entities/voxel_body.gd#L108-L117)). O
  shave de Y continua ([`:126`](../src/entities/voxel_body.gd#L126)) porque ali ele é o lado
  conservador.

`EXPECTED_CHECKS` de 94 para 103 ([`tests/aether_reactions_test.gd:19`](../tests/aether_reactions_test.gd#L19)),
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
pico=49 trips=0` ([`tests/aether_reactions_test.gd:1011-1012`](../tests/aether_reactions_test.gd#L1011-L1012)).
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
[`tests/smoke_test.gd:201`](../tests/smoke_test.gd#L201)) passou a cair em
`encaixados=1 lobo1 em (56.62563, 36.39333, 23.29462)` — **três corridas, a mesma coordenada**, o
que a torna premissa de teste e não maré. E o resgate não alcança: `escape_embedded()`
([`voxel_body.gd:65-76`](../src/entities/voxel_body.gd#L65-L76)) só varre para cima, com
`ESCAPE_LIFT = 2,5`, numa parede de rocha de 6 blocos — a sonda mediu lift necessário nenhum
(`pra cima=-1, pra baixo=-1` nos 4 m varridos). Corpo congelado dentro do sólido, que é a
assinatura que o próprio comentário de `escape_embedded` descreve.

O conserto não relaxa o teste nem aperta o corpo: a caixa testada passa a ser a caixa aplicada. O
contato rente já era tolerado pelo epsilon de `aabb_hits_solid`
([`voxel_world.gd:305`](../src/world/voxel_world.gd#L305)), que trata face em cima da divisória
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
`docs/planos/README.md:15`, `:80`. Os `103` do dossiê 03 §"Como medir" são o número de hoje, não o
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
([`tests/smoke_test.gd:215`](../tests/smoke_test.gd#L215) e
[`tests/smoke_test.gd:2459`](../tests/smoke_test.gd#L2459)) cobram `perdidos=0`, não a distribuição do passo. Somam-se
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
   (`a1405e4:src/entities/wolf.gd:472`) e o alvo vinha de `surface_height()` da coluna
   (`a1405e4:src/entities/wolf.gd:495`). Consequência derivada, não medida: sangue escorrido
   para dentro de uma boca de caverna mora na célula de Éter **abaixo** do teto, e um lobo em
   cima dele lê 0,0000 onde existe 0,4200.
2. **nenhum número para o custo.** O parágrafo de otimização deste repo dizia "49 × 3 leituras"
   e ficava por aí. Abrir mais andares multiplica essa conta, e ninguém sabia quanto.

### O vermelho, nos dois sentidos que o ciclo de trabalho cobra

Cenário novo `_test_scent_cave_layer`
([:1019-1071](../tests/aether_reactions_test.gd#L1019-L1071)) com `_cave_carve()`
([:1009-1016](../tests/aether_reactions_test.gd#L1009-L1016)): piso sólido em `y=44`, ar em
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
  ([wolf.gd:478-498](../src/entities/wolf.gd#L478-L498)): camada própria primeiro, e as
  vizinhas só abrem quando ela não devolve nada acima de `SCENT_MIN`. FEAR continua lendo só
  na camada do lobo — o empurrão da fuga é horizontal e a suíte já o mede ali. O porquê do
  gate está na linha de cima, não no diff: cada camada vizinha são 98 leituras num scan que
  roda 4×/s.
- **`_scent_ground_y()`** ([wolf.gd:689-697](../src/entities/wolf.gd#L689-L697)): o chão do
  rastro é a primeira célula sólida descendo do topo da camada encontrada, não o topo da
  coluna.
- Runner: 103 → **109 checagens**, censo `20/20` → **`21/21`**
  ([`EXPECTED_CHECKS`:19](../tests/aether_reactions_test.gd#L19),
  [TESTS:15](../tests/aether_reactions_test.gd#L15)).

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
  ([wolf.gd:257-258](../src/entities/wolf.gd#L257-L258)), então o cheiro é lembrado no andar
  certo e perseguido no andar do lobo.
- O mesmo §"Limites" dizia "o destino usa a altura de superfície da coluna": também falso, e
  troca-se pela primeira célula sólida descendo do topo da camada encontrada.
- `docs/planos/03` e `04`: as linhas internas do varredor (`:472-477`, peso `:476`, canal `:487`)
  e a frase "5 lobos × 147 `sample_cell`" viraram a conta escalonada, com o número da matriz.
- `docs/planos/05`: a nota "citações herdadas, **não relidas** nesta revisão" saiu — `wolf.gd:462-506`
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
`smoke_test.gd:2021-2023` como a impressão do piso de pior passo, e aquelas linhas são
o fim do cenário de planar e o reposicionamento da queda livre. As duas linhas que
imprimem `worst_sim_ms` são [`smoke_test.gd:216`](../tests/smoke_test.gd#L216) e
[`2461`](../tests/smoke_test.gd#L2461), e o próprio design/10 foi re-ancorado nelas. A
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
do mesmo tamanho e estava na mesma frase: a declaração `_rng` citada como `wolf.gd:99` (real: `123`,
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
[`README.md`](../../README.md) e este arquivo descreviam a realidade anterior: nenhum identificador
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
- `2f6ca26` — `FUR_COLORS` [:90](../src/entities/wolf.gd#L90), `home_biome` perguntado uma vez no
  `setup` ([:189](../src/entities/wolf.gd#L189)) e re-derivado no `load_state`
  ([:879-883](../src/entities/wolf.gd#L879-L883)), porque o load move o `home` sem reconstruir o
  visual. Checagens 3 no runner: dois lobos em biomas diferentes saem com `albedo_color` diferente,
  dois no mesmo bioma saem com a mesma.
- `f9b63b3` — `IMPRINT_BIAS` [:45](../src/world/world_gen.gd#L45) lida por
  `imprint_bias` ([:156-157](../src/world/world_gen.gd#L156-L157)) e aplicada **pelo chamador** do
  evento: `_imprint` em [wolf.gd:220-222](../src/entities/wolf.gd#L220-L222) e
  [main.gd:360-362](../src/main.gd#L360-L362) cobrem os 11 sítios de imprint que já existiam. A
  folha de fuga fica de fora, com o motivo no código ([:249](../src/entities/wolf.gd#L249)): ela roda
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
  `world.set_block` de gameplay são [`player.gd:667`](../src/entities/player.gd#L667) e
  [`:693`](../src/entities/player.gd#L693) (eram `:659`/`:675`, que são os cabeçalhos de
  `_mine_target()` e `_try_place()`); o `_on_acted` que imprime WORK está em
  [`main.gd:425-430`](../src/main.gd#L425-L430) (saiu de `:268-273` quando o viés de imprint entrou);
  o teto do load que pareia por índice é [`main.gd:567`](../src/main.gd#L567), não `:410`; as três
  promessas da lavra estão em [`smoke_test.gd:881-889`](../tests/smoke_test.gd#L881-L889), não
  `:780-790`; `EXPECTED_CHECKS` é [`aether_reactions_test.gd:17`](../tests/aether_reactions_test.gd#L17)
  com **119**, não `:16` com 109. Nos dossiês: `07:67` e `07:137` apontavam
  [`README.md:505-512`](../../README.md) (a seção do oráculo local — os três números de README desta
  frase são da numeração de `eb6ec8d`, e o README tem 13 linhas a mais nesta ponta; os de status, `:78`
  e `:83`, não se moveram) para a queda de ~16 s para ~7,5 s, que está em `:546-553`, e `12:63` apontava
  `README.md:533` (linha de lista do Éter) e o par geração/malharia em `:78` quando está em `:83`.
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
  ([wolf.gd:116](../src/entities/wolf.gd#L116)) preso à identidade em
  [main.gd:228](../src/main.gd#L228), uma passada por passo (`_rebuild_packs`
  [:292-313](../src/main.gd#L292-L313)) que testa cada par `i<j` contra
  `PACK_COHESION_RADIUS = 24 m` ([:24](../src/main.gd#L24)), escreve nos dois buffers e trunca o
  cursor para não deixar vizinho fantasma; `pack_of` ([:283-285](../src/main.gd#L283-L285)). Sem
  provedor a lista é `NO_PACK` ([wolf.gd:43](../src/entities/wolf.gd#L43)) e o lobo solitário é
  literalmente o de antes.
- `79882d2` — **ronda por setor**: centro compartilhado (baricentro, `_territory_center`
  [:459-466](../src/entities/wolf.gd#L459-L466)) e fatia angular por rank (`_territory_rank`
  [:473-478](../src/entities/wolf.gd#L473-L478)) em `_leaf_wander`
  ([:417-435](../src/entities/wolf.gd#L417-L435)); com um lobo só, o centro é o próprio lar e a fatia
  é o círculo inteiro, que é a ronda antiga.
- `8e334e3` — **cerco**: assento `TAU/n` onde `n` conta quem está em `hunt` de fato
  (`_hunt_pack_size` [:327](../src/entities/wolf.gd#L327)), ponto a 1,50 m da presa
  (`_seat_point` [:350-353](../src/entities/wolf.gd#L350-L353), `ENCIRCLE_RING`
  [:39](../src/entities/wolf.gd#L39)).
- `89df566` — **mordida escalonada**: `_bite_turn` [:525-529](../src/entities/wolf.gd#L525-L529)
  devolve `clock.tick % n == rank`, chamada em [:506](../src/entities/wolf.gd#L506) — dois lobos não
  mordem o mesmo tick.
- `4888818` — a leitura da matilha ganha **quinta chave conferida**: `trust` vem de
  `_pack_put` ([main.gd:397](../src/main.gd#L397), `e["trust"] = other.trust_toward_player`), o
  contexto do escorredor leva o pacote ([wolf.gd:584](../src/entities/wolf.gd#L584)) e o
  `_sense()` agrega `_pack_trust` ([:646-655](../src/entities/wolf.gd#L646-L655)).
- `2e4ff65` — **contágio do medo**: vizinho em `flee` soma `0,55` no `_fear_level` do observador
  ([:641-650](../src/entities/wolf.gd#L641-L650), `PACK_PANIC_FEAR`
  [:53](../src/entities/wolf.gd#L53)). O vizinho **não escreve** no lobo — cada um soma o que a
  sessão devolve.
- `c42250c` — **amortecimento por confiança**: vizinho com `trust ≥ 0,35` corta o `_courage` e fecha
  a porta de `hunt` ([:646-655](../src/entities/wolf.gd#L646-L655)); a única fonte de confiança é
  `take_damage` → `adjust_trust(from_actor, -0,35)` ([:818](../src/entities/wolf.gd#L818)), e o
  limiar é o mesmo `0,35` de `Mind.believes()` ([mind.gd:104-105](../src/ai/mind.gd#L104-L105)).

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

O teto publicado do runner é `EXPECTED_CHECKS` ([aether_reactions_test.gd:20](../tests/aether_reactions_test.gd#L20)),
que saiu de **119** (na base, linha 17) para **150**. Suíte: **237 → 239**, com as duas checagens da
sessão real ([smoke_test.gd:238](../tests/smoke_test.gd#L238),
[:241-244](../tests/smoke_test.gd#L241-L244)). Em todos os 28 logs arquivados, `SCRIPT ERROR` é
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
([main.gd:366](../src/main.gd#L366)), não vizinhos coesos; `maior_matilha_lida=1` é o maior
`_pack.size()` entre os lobos, e `_pack` exclui o próprio lobo. No vale real, com os cinco lares
espalhados, ninguém teve dois vizinhos — cerco, contágio e ronda por setor estão provados no fixture
de quatro lobos colocados a propósito uns dos outros
(`cerco-runner-2.log:141`, `angulos=[0.0, 1.5708, 3.1416, 4.7124] n=4`), não no mundo. A asserção
`biggest >= 1` não barra esse estado; a perna 14 é quem troca por `>= 2` quando o spawn mudar, e isso
está registrado **antes** do código.

### A tabela que a nota das dez ocorrências prometeu

`cb96493` pôs na árvore **dez ocorrências** em quatro lugares deste arquivo. Cada alvo foi lido na
linha; nada aqui é troca automática.

| # | onde está | afirmava | classe | âncora posta na árvore |
| --- | --- | --- | --- | --- |
| 1 | linha 207 deste arquivo, em "Feito nesta sessão" — recorte do sorteio | `wolf.gd:99` / `#L99` | rótulo = âncora, alvo errado | [`:123`](../src/entities/wolf.gd#L123) (`var _rng := RandomNumberGenerator.new()`); na base era `77` |
| 2 | idem | `:175` / `#L175` | idem | [`:191`](../src/entities/wolf.gd#L191) (`_rng.seed = ("wolf:%d:%d" % …)`); na base era `137` |
| 3 | idem | `:301-304` / `#L302-L305` | rótulo ≠ âncora | [`:425`](../src/entities/wolf.gd#L425) **e** [`:442-443`](../src/entities/wolf.gd#L442-L443) — a faixa virou duas |
| 4 | idem | `:538-539` / `#L563-L564` | rótulo ≠ âncora | [`:766-767`](../src/entities/wolf.gd#L766-L767) (`_unstick` / `_detour`) |
| 5-8 | linhas 348-351 deste arquivo, em "Falta" — item 2 da fila, as mesmas quatro frases | idem a 1–4 | idem | idem a 1–4 |
| 9 | "Notas de medição", frase do corte | `wolf.gd:99` / `#L99` | rótulo = âncora, alvo errado | [`:123`](../src/entities/wolf.gd#L123) |
| 10 | rodada do cache de inspeções, evicção | `:291-292` / `#L292-L293` | rótulo ≠ âncora | [`:412-413`](../src/entities/wolf.gd#L412-L413) (`SCENT_MEMORY_CAP` e o `keys()[0]`) |

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
  citava `main.gd:163`/`:335` (agora `:242`/`:483`), `wolf.gd:324-342` (agora `:417-435`) e o
  `Mind.new` de `wolf.gd:139` (agora `:193`). Cada um dos 42 foi lido no alvo, e o conteúdo da frase
  re-conferido: as quatro folhas que "escolhem alvo sem nenhum teste de solo" continuam sendo as
  quatro ([_leaf_flee:299](../src/entities/wolf.gd#L299),
  [_leaf_chase:315](../src/entities/wolf.gd#L315)/[:319](../src/entities/wolf.gd#L319),
  [_leaf_stalk:358](../src/entities/wolf.gd#L358),
  [_leaf_investigate:376](../src/entities/wolf.gd#L376)).

### Contagem de citações, pela regra declarada aqui

`python .tools/verify_plan_cites.py <cada .md rastreado>` sobre o corpus: **1 311** citações com
número de linha conferidas, **0** números fora do arquivo, **27** arquivos citados que não existem
(todos `[TARGET]` dos dossiês 13 e 14 — `FamilyTree`, `PackState`, `SAFE_SPAWN_DIST` e cia.). O trio
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
- **Furo #16**: a sessão real nunca montou matilha de dois. É a primeira peça da perna 14.
- **Furo #17**: **8** das 60 referências a linhas deste arquivo ficaram para trás de propósito — seis
  já apontavam para linha em branco (mis-citação pré-existente, prova vazia) e duas caem dentro de um
  bloco que esta passada reescreveu. Consertar é ler a frase, não mexer o número.
- O HOT agregado dos cinco lobos continua sem medição (dossiê 08, item 5) e `MindsInspector` não
  existe: a matilha lida hoje se lê no log do runner, não no F3.
- Memória compartilhada **entre** matilhas continua `[TARGET]`: `Mind.relations` é confiança por ator
  ([mind.gd:20](../src/ai/mind.gd#L20), [:126-131](../src/ai/mind.gd#L126-L131)).

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
   ([llm_server_host.gd](../src/ai/llm_server_host.gd), 417 linhas novas).
3. `a09c2eb` — **F3** mostra a linha do hospedeiro por provider, não por referência
   ([hud.gd](../src/ui/hud.gd)).
4. `7d9c8a9` — **`main`** monta o hospedeiro antes da geração e fecha o portão do oráculo; em headless
   o hospedeiro não entra na árvore ([main.gd](../src/main.gd)).
5. `3cb0c16` — o **lançador** do oráculo aceita a mesma chave do jogo e vira caso de uso
   ([run_mind_server.ps1](../tools/run_mind_server.ps1)).
6. `74ad670` — **sonda de boot** com cinco modos, cada um imprimindo número ou vermelho
   ([llm_server_boot_probe.gd](../tests/llm_server_boot_probe.gd), 385 linhas, + `.tscn`).
7. `f8b42a5` — a **suíte** cobra portão, derivação da chave e recuo nomeado: **7 checagens novas**,
   239 → **246**.
8. `fae0b40` — a sonda `ci` **não reentra** mais: o braço vira a página antes de esperar frames.
9. `09780c4` — **um dono por porta**: a janela real revelou o segundo `llama-server`.
10. `a6b83d7` — **evidência**: 36 arquivos com `readback.md` e `artifacts.sha256` em
    [`docs/evidence/oracle-embutido-15/`](oracle-embutido-15/readback.md).

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
| `main.gd:523-535` como `diagnostics()` | 523–531 eram brancos mais `stats_line()`; `func diagnostics` começava em **532** | [`main.gd:592-607`](../src/main.gd#L592-L607) |
| `main.gd:495` como `audio.clear_transient()` | 495 era `hud.set_death(false)` dentro do load; a limpeza estava em **504** | [`main.gd:564`](../src/main.gd#L564) |
| `smoke_test.gd:1986-1992` como a sonda da porta 1 | 1986–1992 é o passo de planar (`p.pitch = -0.9`, `action_press("glide")`); `_check_oracle_arm` começava em **2066** | [`smoke_test.gd:2081-2086`](../tests/smoke_test.gd#L2081-L2086) |
| a lista de `hud.show_message` do estado lido da perna 14 (`main.gd:107`, `:194`, `:303`, `:376`, `:378`, `:384`, `:388`, `:424`) | nenhum desses números tinha `show_message` na base; os sites reais eram 125, 213, 391, 464, 466, 472, 476, 512 | `main.gd` **135**, **273**, **450-451** (conectado em **121**), **524**, **526**, **532**, **536**, **572**, mais [`hud.gd:603`](../src/ui/hud.gd#L603)/`:605`; os dois avisos de criatura ficam em **242** e **483** |
| as cinco âncoras de passo da suíte: `smoke_test.gd:1709-1713` por `_alive_wolf`, `:1752-1759` pela premissa do jogador, `:1767-1778` pela matilha estacionada, `:1781-1788` por `mira travada`, `:1098-1103` pelo zera-yaw | na base esses números continham outra coisa: varredura do leito (1709–1713), checagens de nado (1752–1759), `_pause_for`/`_unpause_for` (1767–1788) e a amostragem de oclusão (1098–1103); os conteúdos estavam em 1791, 1834–1841, 1849, 1863 e 1184 | por conteúdo, com o +15 do mapa: **1806-1810**, **1849-1856**, **1863-1877**, **1878-1884** e **1196-1200** |

Duas frases do [mandato 2](../AGENTS.md) precisaram de qualificação com o hospedeiro dentro: a saída
que chega a quem age continua sendo `_narrations`, e `last_reason` / `server_url` são lidos pelo
hospedeiro ([`llm_server_host.gd:152-153`](../src/ai/llm_server_host.gd#L152-L153),
[`$:189`](../src/ai/llm_server_host.gd#L189)) **só** para a linha de status do F3 — leitura, nenhuma
escrita. O mesmo vale para a conta do "objeto deus": 599 → 662 linhas e um dono a mais na lista (o
hospedeiro do modelo), em [`AGENTS.md`](../AGENTS.md) e aqui na linha do acoplamento.

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
  apontado para a linha 34, que hoje é comentário; [`_build_visual()`](../src/entities/wolf.gd#L920)
  para 885; [`_spawn_wolves`](../src/main.gd#L278-L299) para 259-275;
  [`load_state`](../src/entities/wolf.gd#L877) para 701-736; [`take_damage`](../src/entities/wolf.gd#L803)
  para 817. Nenhum desses dava "fora do arquivo" nem "em branco": linha com texto, número dentro, e
  a frase mentindo.
- **ponteiro de dossiê que descreve o estado lido ANTES da perna 10.** Em `a6b83d7` os dossiês 10 a
  14 tinham **39** ponteiros `wolf.gd` caindo na faixa 400–599, onde a perna escreveu as funções
  novas; hoje são **26**, e a faixa perdeu o valor de sinal justamente porque é ali que moram
  `_remember_scent` (`src/entities/wolf.gd:400`), `_leaf_wander` (`src/entities/wolf.gd:417`),
  `_shore_point` (`src/entities/wolf.gd:490`) e `_build_scorer` (`src/entities/wolf.gd:534`). Cada um dos que a passada abriu saiu com o número de hoje — a lista da matilha no
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
serializada é a 14 (convivência da alcateia), e o HOT agregado dos cinco lobos continua por colher.

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
([mind_oracle.gd:219-241](../src/ai/mind_oracle.gd#L219-L241)) vale, nesta ordem, o ambiente
`AETHERFALL_MIND_KEY`, o arquivo `user://mind_key.txt` e, sem as duas fontes, 32 hex sorteados por
`Crypto.generate_random_bytes(16)` gravados no arquivo ([`:19-20`](../src/ai/mind_oracle.gd#L19-L20)
para as duas constantes, leitura em [:244-250](../src/ai/mind_oracle.gd#L244-L250), escrita em
[:253-259](../src/ai/mind_oracle.gd#L253-L259)). A origem fica nomeada em `key_source` — `ambiente`,
`arquivo`, `sorteada`, `sorteada-sem-gravar`, `sem-entropia` — porque gravação que falha tem de ser
estado visível e não chave silenciosa: sem arquivo, quem roda o lançador por fora não tem como bater a
mesma chave e o `401` que vem depois é dele. O lançador lê as **mesmas duas fontes** e recusa sem
nenhuma ([tools/run_mind_server.ps1:34-41](../tools/run_mind_server.ps1#L34-L41)). O host passou a
imprimir a linha de comando com `<chave>` no lugar do valor
([llm_server_host.gd:310](../src/ai/llm_server_host.gd#L310), `_redacted` em
[:423-433](../src/ai/llm_server_host.gd#L423-L433)): o imprint continua vivo no processo e fora do
log. A checagem da suíte ([smoke_test.gd:2156-2167](../tests/smoke_test.gd#L2156-L2167)) deixou de
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
