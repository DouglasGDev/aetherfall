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
Bloco atual: o Éter passou a medir o próprio saldo. A difusão tem duas saídas de massa — decaimento
e corte da fronteira de `MIN_VALUE` — e só a primeira tinha número; `pass_cut` devolve a quantia
cortada por canal em cada passada e a suíte confere, passada a passada, que nenhum canal ganha massa
e que a cadeia `2,500 → 2,471 → 2,296` fecha pelo corte medido de `0,176129`. O código (branch
`test/ether-massa-conservada`, `98f1d63` + `28884ff`) entrou como `9f3622b`; a re-derivação das
citações que aquele bloco deixou velhas entrou como `6007809`. Os dois conferidos em `ls-remote`
— o clone limpo do primeiro deu 236 checagens / 0 falhas / 37,1 s, exit 0; ver a seção final.
Motor: Godot 4.7.2-stable (`ed1daf0bf`), Vulkan Forward+, AMD Radeon RX 9060 XT.

## Os prompts × o código

### O prompt master de furos e gates × o código

| O que o prompt afirma | O que está em `src/` hoje | Veredicto |
|---|---|---|
| "AetherField de **6 canais** (trabalho, sangue, medo, morte, som, fogo)" | 3 canais: `enum Channel { WORK, BLOOD, FEAR, COUNT }` com `HALF_LIFE = [90, 55, 120]` e `DIFFUSE_RATE = [0.06, 0.16, 0.10]` — [aether_field.gd:9-15](../src/world/aether_field.gd#L9-L15). A `CHANNEL_COLOR` da visualização também tem 3 entradas — [aether_viz.gd:12-16](../src/rendering/aether_viz.gd#L12-L16) | **falso hoje**; é meta de P1 (§08 linha "falta") |
| "`MindStore` + consolidação" | A **consolidação já existe** dentro de `Mind`: ao estourar `EPISODIC_CAP = 24` o átomo mais velho sai da fila e vira reforço de crença, com contador persistido — [mind.gd:7](../src/ai/mind.gd#L7), [:44-45](../src/ai/mind.gd#L44-L45), `:_consolidate` em [:61-68](../src/ai/mind.gd#L61-L68), save/load em [:148](../src/ai/mind.gd#L148) e [:157](../src/ai/mind.gd#L157). Não há tipo `MindStore` (grep em `src/`: zero ocorrências) | **metade feito**; o nome `MindStore` aponta para um store fora da entidade, que não existe |
| "`MindsInspector`" | Não existe. O que existe é o overlay de debug em texto: fps/processo/física, chunks e fila de malha, tick/`worst_step_ms`/ticks perdidos, totais por canal do Éter, posição e mira, e uma linha por lobo com a narrativa do oráculo — [hud.gd:241-275](../src/ui/hud.gd#L241-L275), tecla em [input_actions.gd:33](../src/input/input_actions.gd#L33) | **não existe**; a observabilidade mínima exigida por P1 está coberta em texto, não em inspector |
| "**hash de estado** e journal de tick são sagrados" | Agora há `TickJournal.state_hash()` e gravação JSONL de `[tick, hash]`, sob demanda ([tick_journal.gd](../src/persistence/tick_journal.gd)). A projeção mínima cobre semente/versão/dimensões, tick, edições, bytes completos do Éter e identidades/intenções/crenças das mentes vivas. `main._sim_tick` registra após incrementar o tick e dentro do cronômetro ([main.gd:164-170](../src/main.gd#L164-L170), cronometrado em [:140-142](../src/main.gd#L140-L142)) | **primitivo implementado, validação abaixo**; não cobre todo o estado da simulação nem registra comandos: replay permanece item 2 |
| "testes de determinismo: 20 sementes × 1000 ticks no cenário do lobo" | A suíte roda **uma** semente (`const SEED := 20261116` — [smoke_test.gd:10](../tests/smoke_test.gd#L10)) e a checagem determinística é uma só: 16 colunas de altura geradas duas vezes e comparadas — [smoke_test.gd:288-295](../tests/smoke_test.gd#L288-L295). Não há harness multi-semente em `tests/` | **falso hoje**; só faz sentido depois do hash |
| "budget HOT medido" | `SubtreeGuard` mede só a árvore e retorna falha no estouro — [bt_tree.gd:117-134](../src/ai/behavior/bt_tree.gd#L117-L134), default 250 µs; o lobo usa **400 µs** — [wolf.gd:172-173](../src/entities/wolf.gd#L172-L173). O F3 mostra custo/estouros — [wolf.gd:637-638](../src/entities/wolf.gd#L637-L638). O teste de rastros agora colhe `sim_step` integral e `last_us`/`trips`, com um lobo por cenário; não mede o agregado simultâneo da matilha | **parcial**; há colheita estreita, mas o HOT de cinco lobos e o gate P1 continuam abertos |
| "oráculo ainda é HTTP, não nativo — fortaleça sem fingir que é nativo" | Correto e verificado: `HTTPRequest` contra `http://127.0.0.1:8741`, timeout 8 s, recuo de 30 s, resposta vazia → recuo global sem tocar a decisão — [mind_oracle.gd:11-13](../src/ai/mind_oracle.gd#L11-L13), [:106-122](../src/ai/mind_oracle.gd#L106-L122). Um pedido em voo, round-robin pela matilha, prompt montado do estado interno — [:43-54](../src/ai/mind_oracle.gd#L43-L54), `:_prompt_for` em [:86-103](../src/ai/mind_oracle.gd#L86-L103). Não há cache nem embeddings | **falso no projeto, certo no diagnóstico** |
| "reduza o acoplamento de `main.gd` / `wolf.gd` / memória" | Os números reais hoje (até a última linha de código): `main.gd` 501 linhas, `wolf.gd` 723, `player.gd` 769, `voxel_world.gd` 637, `mind.gd` 167, `aether_field.gd` 234, `smoke_test.gd` 2283; o journal é dono de seu arquivo e contadores. O acoplamento é estrutural, não de tamanho: `main.gd` é dono de mundo, relógio, matilha, HUD, oráculo, visualização e o nó de áudio ao mesmo tempo — [main.gd:21-29](../src/main.gd#L21-L29) | **válido**; medir por linhas é proxy, o que importa é o dono único |
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
| "Não quebrar determinismo ou a capacidade de hash/journal sem avisar" | O primitivo agora existe: ordenação de edições, identidades e crenças; Float32 integral do Éter; versão do formato; ticks consecutivos em arquivo novo. O save é deliberadamente diferente: filtra Éter e não conserva a origem das crenças. `diagnostics()` expõe custo e última assinatura ([main.gd:435-446](../src/main.gd#L435-L446)) | **salvaguarda do contrato mínimo**; preservar a projeção não equivale a tornar o jogo determinístico |
| "A mente propõe, as regras dispõem — LLM nunca decide movimento, dano, posição ou estado" | Verdade hoje por fiação, não por verifier: a única saída de `MindOracle` é `_narrations` — [mind_oracle.gd:27](../src/ai/mind_oracle.gd#L27), [:120](../src/ai/mind_oracle.gd#L120) — lida por `narration_of()` ([:59-60](../src/ai/mind_oracle.gd#L59-L60)) e entregue só ao HUD ([main.gd:114](../src/main.gd#L114) → [hud.gd:270-271](../src/ui/hud.gd#L270-L271)). Grep de `oracle`/`narration` em `src/` não acha nenhum outro consumidor: nem `Mind`, nem `Wolf`, nem o mundo leem o oráculo | **correto hoje**; o dia em que o oráculo *sugerir*, a sugestão entra como crença em quarentena (§04), não como intenção escrita |
| "Completar o mínimo de P1: AetherField, Mind, consolidação, observabilidade, testes de hash, budget" | Três dos seis existem: `AetherField` (com 3 dos 6 canais), `Mind` e a **consolidação** — mas esta vive dentro de `Mind`, não num `MindStore` à parte. Observabilidade há em texto (F3), inspector não; o primitivo de hash mínimo tem suíte própria, mas o cenário multi-semente ainda não existe; "budget" tem mecanismo e colheita estreita de um lobo, não do agregado HOT | **metade feito**; item por item nas linhas acima e na fila "Falta" |
| "Melhorar a degradação e a robustez do oráculo atual (ainda HTTP)" | Correto no diagnóstico, e a degradação já é checada sem rede — sonda apontada para a porta 1 em [smoke_test.gd:1967-1973](../tests/smoke_test.gd#L1967-L1973). O caminho feliz depende de `llama-server` de fora e não é testável em headless | **correto**; está dentro do escopo autorizado |
| "Repositório: github.com/DouglasGDev/aetherfall" | `origin` confere. Publicação re-confirmada em `42799fa` — o `push` devolveu `1db00cf..42799fa main -> main` e `git ls-remote --heads origin` respondeu `42799fa0f0987b20d58902b4b2f7a4927a93cfd2 refs/heads/main` em 2026-11-19, o mesmo SHA do `HEAD` local. Os seis blocos desta revisão (som, journal, RNG, rastros, mão e porte em 3ª pessoa) estão todos no remoto; a confirmação anterior, de 2026-11-18, parava em `1db00cf` com hash/journal e rastros ainda locais | **correto**; publicação se confirma por `ls-remote`, nunca pelo código 0 do `push` |
| "Ao final de um bloco, atualize ou proponha atualização de `docs/melhorias-status.md`" | É este arquivo, com as seções que o prompt pede (feito / em andamento / falta / backlog / débitos / furos / notas) | **correto**; já é a prática da casa, e agora está escrita em [`AGENTS.md`](../AGENTS.md) |

### O prompt de disciplina de otimização × o código

Terceiro mandato, aplicado com as duas regras da casa: nada de adjetivo onde cabe número, e
nada de otimização onde ainda não há medição. As regras anti-bloat não são afirmações de
estado, então não têm linha aqui — o que tem linha é o instrumento e o custo que ele mostra.

| O que o prompt afirma | O que está em `src/` hoje | Veredicto |
|---|---|---|
| "Meça antes de otimizar: use dados reais (Profiler, tempo de tick, contagem de objetos, alocações)" | Tempo de tick: medido e publicado — `last_step_ms`/`worst_step_ms`/`dropped_ticks` ([sim_clock.gd:12-14](../src/core/sim_clock.gd#L12-L14)) cronometrados em µs dentro de [main.gd:140-142](../src/main.gd#L140-L142). Tempo de frame: `TIME_PROCESS` e `TIME_PHYSICS_PROCESS` só no F3 ([hud.gd:244-247](../src/ui/hud.gd#L244-L247)). **Contagem de objetos e de alocações: nenhum monitor do engine é lido no repositório inteiro** (grep de `Performance.`: duas linhas, as duas acima) | **parcial**; o "Profiler" da casa é SimClock + `SubtreeGuard` + F3, e a coluna de alocação não existe como número |
| "Otimize o que dói agora" | A dor está medida e é o boot: geração 936-962 ms e malharia 4.640-4.886 ms com a janela congelada, contra **pior passo de 7,56 a 11,21 ms num orçamento de 50 ms** e `dropped_ticks = 0` nas cinco corridas (`.tools/suite_fix1.log` … `suite_fix4.log`, `.tools/pub-suite.log`) | **correto, e já respondido**: o hot path de simulação não é a dor de hoje; o precedente medido é o mesher, que caiu de ~16 s para ~7,5 s com índice linear |
| "Hot path tem regra diferente: o que roda a cada tick (20 Hz) precisa ser barato" | Decisão/difusão são agendadas pelo relógio de 20 Hz ([sim_clock.gd:5-7](../src/core/sim_clock.gd#L5-L7)); o jogador atualiza por frame de física ([main.gd:137](../src/main.gd#L137)) e lavra/colocação alteram mundo e Éter fora do tick. Locomoção e timers dos lobos também mudam por frame ([wolf.gd:501-546](../src/entities/wolf.gd#L501-L546)). Com gravação ativa, cópia/ordenação/hash/escrita/flush entram no tick e têm custo medido nas notas abaixo; "só o tick toca o mundo" ainda não é verdade | **correto no relógio, incompleto na autoridade**; é o §06 (dedicado) que cobra essa conta |
| "Alocação é cara: evite arrays, dicionários, objetos e strings no tick quente" | O blackboard é um `Dictionary` novo por lobo por tick ([wolf.gd:432](../src/entities/wolf.gd#L432), 100/s no teto de matilha viva); a difusão aloca um `PackedInt32Array` por canal por passada ([aether_field.gd:122](../src/world/aether_field.gd#L122), 3 a cada 0,25 s). O cache novo chama `keys()` a cada scan e nas expulsões ([wolf.gd:464](../src/entities/wolf.gd#L464), [:292](../src/entities/wolf.gd#L292)). Os tempos de `sim_step` não isolam essas alocações | **válido como restrição**; primeiro a colheita de alocação, não otimização alegada por contagem teórica |
| "LOD é obrigatório em sistemas de IA/simulação" | Não há LOD por distância: os lobos vivos rodam a árvore inteira a cada tick. O que há é throttle temporal — difusão e visão 4×/s, cadáveres 1×/s ([main.gd:12-16](../src/main.gd#L12-L16)) — e varredura de rastros a cada 0,25 s ([wolf.gd:445-446](../src/entities/wolf.gd#L445-L446)), com nova leitura após inspeção | **falso hoje**; a peça tem nome no design (`HotSet`/Véu, §04 e §06) e é P2: sem custo em log, é backlog, não tarefa |
| "Budget explícito: defina e respeite orçamentos de tempo (ex.: HOT minds ≤ X ms)" | Quatro orçamentos são código: 50 ms por passo com teto de 5 passos por frame ([sim_clock.gd:19-29](../src/core/sim_clock.gd#L19-L29)), 400 µs por árvore ([wolf.gd:172-173](../src/entities/wolf.gd#L172-L173); default da classe, 250 µs, em [bt_tree.gd:117-120](../src/ai/behavior/bt_tree.gd#L117-L120)), 2 chunks de malha por frame ([main.gd:13](../src/main.gd#L13)) e 0,25 s de difusão. O "≤ 2,5 ms" do gate de P1 continua `[TARGET]` no §08, e a aritmética (5 × 400 µs = 2 ms) cabe nele sem que nenhum log mostre a soma | **parcial**; orçamento por peça existe, o agregado do gate é alvo sem medição |
| "Observabilidade > micro-otimização cega: se não dá para medir, não dá para saber se melhorou" | Para o tick, dá: a última linha do diagnóstico da suíte publica `pior passo` e `perdidos` ([smoke_test.gd:2278-2280](../tests/smoke_test.gd#L2278-L2280)). Frame e fila de malha só aparecem em janela; BT agora tem colheita no cenário estreito de rastros, sem equivaler ao agregado HOT; custo de alocação não é medido. Hash/escrita/flush agora têm contadores próprios no diagnóstico do journal | **é o débito da colheita de custo**, e é o que trava as cinco linhas acima de virarem otimização |

## Feito nesta sessão

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
  ([main.gd:118-122](../src/main.gd#L118-L122)), assina seis sinais do jogador no `setup`
  ([:146-155](../src/audio/audio_director.gd#L146-L155)) e três por lobo no spawn
  ([:158-162](../src/audio/audio_director.gd#L158-L162), chamado em
  [main.gd:213-214](../src/main.gd#L213-L214)). É a metade "consumidor" do pedido: o
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
  [main.gd:213-214](../src/main.gd#L213-L214) e a corrida refaz **27 / 0**), e a sonda viva
  contava *famílias novas*, sempre vazio porque os lobos já andavam durante o boot — hoje conta
  incremento por família. O que **não** foi feito de propósito: nenhum som escreve no Éter,
  então o canal SOM do item 4 continua aberto, e o `stop()` de saída não apaga a mensagem de
  vazamento do engine no quit (débito abaixo, com a causa medida em dois braços).
  [Notas completas](#som--publicado-em-a8967e0).

- **Item 2, primeiro recorte — o sorteio tem dono.** `main.gd` e `wolf.gd` eram os únicos
  consumidores do gerador global do Godot; hoje o grep de `randf`/`randi`/`randi_range` sem
  receptor em `src/` devolve zero ocorrências. A matilha é sorteada por `_population_rng`
  ([main.gd:36](../src/main.gd#L36), semeado em [:200-201](../src/main.gd#L200-L201), usado em
  [:221-222](../src/main.gd#L221-L222)) e cada lobo por `_rng`
  ([wolf.gd:63](../src/entities/wolf.gd#L63), semeado em [:120](../src/entities/wolf.gd#L120),
  usado na patrulha [:301-304](../src/entities/wolf.gd#L301-L304) e no desvio
  [:538-539](../src/entities/wolf.gd#L538-L539)); a semente dos dois vem da semente real do
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
  o real é `KNOCKBACK_SPEED = 5.0`, [wolf.gd:45-47](../src/entities/wolf.gd#L45-L47)) e o binding
  de CTRL, que apontava para um intervalo que não continha nenhuma das duas ações.
- **Suíte deixada de ser rolagem de dados** (furo #6 abaixo, agora com causa medida). O passo de
  golpe herdava estado da simulação ao vivo por três portas, e as três foram fechadas: o alvo é
  escolhido entre os vivos ([smoke_test.gd:1690-1694](../tests/smoke_test.gd#L1690-L1694),
  `_alive_wolf()`), a premissa do jogador é montada pelas transições do próprio jogo —
  `respawn_at` e `close_panel`, não campo escrito à mão
  ([smoke_test.gd:1733-1740](../tests/smoke_test.gd#L1733-L1740)) — e o resto da matilha é
  estacionado fora da linha de mira
  ([smoke_test.gd:1748-1759](../tests/smoke_test.gd#L1748-L1759)). A checagem nova
  `mira travada no lobo do passo` ([smoke_test.gd:1762-1769](../tests/smoke_test.gd#L1762-L1769))
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

## Falta

Por dependência, não por preferência (cada item aberto tem um dossiê de leitura em [`docs/planos/`](planos/README.md): premissa nomeada, estado do código com `arquivo:linha`, gate headless e custo pelas quatro perguntas — nenhum dossiê rodou a engine e nenhum fecha gate):

1. **Primitivo de hash de estado por tick — concluído e validado nesta máquina.** Implementado em
   [tick_journal.gd](../src/persistence/tick_journal.gd), com contrato, testes e medições abaixo.
   Mantida a numeração original para não mudar as dependências da fila.
2. **Diário de tick sobre a simulação — um recorte concluído e validado nesta máquina.** O journal mínimo
   registra somente `[tick, hash]`. O sorteio deixou de ser o gerador global: a sessão tem
   `_population_rng` ([main.gd:36](../src/main.gd#L36), sorteado em
   [:221-222](../src/main.gd#L221-L222)) e cada lobo tem `_rng`
   ([wolf.gd:63](../src/entities/wolf.gd#L63), semeado em
   [:120](../src/entities/wolf.gd#L120), usado em
   [:301-304](../src/entities/wolf.gd#L301-L304) e [:538-539](../src/entities/wolf.gd#L538-L539)).
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
   400 µs é o configurado em [wolf.gd:172-173](../src/entities/wolf.gd#L172-L173). Gate subtrativo: nenhuma mente nova entra
   antes do budget da existente estar escrito.
6. **Difusão do Éter fora do tick de decisão.** Hoje a difusão roda na passada do relógio
   ([main.gd:12](../src/main.gd#L12) `AETHER_PERIOD 0.25`); com 6 canais e a malha competindo,
   é o primeiro candidato a thread.
7. **Decompor `main.gd`** pelo eixo certo: um dono por sistema (sessão, matilha, HUD, oráculo,
   visualização), preservando o acesso ao estado. A autoridade temporal ainda não é única:
   jogador, corpos dos lobos e timers também mudam por frame.

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
  nem `main.diagnostics()` ([:435-447](../src/main.gd#L435-L447)), que tem `journal` e não tem
  `audio`. Só o teste headless e a sonda em janela leem esses números hoje.
- **A sonda viva de áudio não é testável em CI:** `audio_live_probe.tscn` exige janela e um
  endpoint de render aberto. A mesma árvore, na mesma máquina, deu WASAPI em uma corrida e
  `ERR_CANT_OPEN` → `Dummy` em outra ([live-2-red-dummy.log](evidence/audio/live-2-red-dummy.log)), e a checagem do driver pegou a
  diferença. É o mesmo formato de débito do gate do oráculo: caminho feliz existe, mas não é
  reproduzível sem o hardware de quem executa.

- **O smoke usa o slot real `alpha` e não o preserva**
  ([smoke_test.gd:2162-2185](../tests/smoke_test.gd#L2162-L2185)). Nesta validação, os
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
  O blackboard por tick ([wolf.gd:432](../src/entities/wolf.gd#L432)), as listas temporárias
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
  `llama-server` de pé; a degradação é testada sem rede ([smoke_test.gd:1967-1973](../tests/smoke_test.gd#L1967-L1973),
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
     do alvo (`targets_under_crosshair()` só devolve vivos — [main.gd:245-250](../src/main.gd#L245-L250) —
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
   `if not alive: return` ([wolf.gd:599-601](../src/entities/wolf.gd#L599-L601)) — um lobo já
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

## Contrato dos rastros e reações

- O estado novo pertence a `Wolf`; os três canais e a difusão de `AetherField` não foram
  alterados neste recorte. Detalhamento do ciclo em [§09.8](design/09-veloren-mechanics-adaptation.md#8-criaturas-o-que-virou-comportamento).
- Cada scan visita **49 células × 3 canais**, nominalmente a cada **0,25 s**, além de
  três amostras locais por tick. Ao terminar uma inspeção, há rescan no tick seguinte.
  Cinco lobos podem fazer essa leitura no mesmo tick; não há LOD por distância
  ([wolf.gd:408-496](../src/entities/wolf.gd#L408-L496)).
- A folha retorna `RUNNING` durante aproximação e inspeção, para a até **1,2 m**
  horizontais e exige **2 s** de inspeção antes do episódio. Troca de alvo, perda do
  rastro, outra intenção ou atordoamento cancelam o timer
  ([wolf.gd:248-276](../src/entities/wolf.gd#L248-L276)).
- Cache de **32 células/lobo**, força ponderada e validade de **30 s**: uma visita grava
  até nove células vizinhas, com duas leituras por célula válida. Novo aumento de **0,06**
  ponderado ou expiração reabre a célula. `keys()` aloca no scan e na expulsão; esse custo
  de alocação não foi isolado ([wolf.gd:279-293](../src/entities/wolf.gd#L279-L293),
  [:462-496](../src/entities/wolf.gd#L462-L496)).
- O F3 expõe reação, canal, célula, força e tamanho do cache
  ([wolf.gd:629-634](../src/entities/wolf.gd#L629-L634)). O episódio usa ator **0**;
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
  Há locomoção e timers de lobo por frame ([wolf.gd:501-546](../src/entities/wolf.gd#L501-L546)),
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
  `wolf.identity` e limpo no load ([main.gd:407](../src/main.gd#L407),
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
  ([smoke_test.gd:1079-1084](../tests/smoke_test.gd#L1079-L1084)) porque a órbita de trás só
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

**O corte, em três decisões.** `_population_rng` ([main.gd:36](../src/main.gd#L36)) sorteia as
casas da matilha; `_rng` ([wolf.gd:63](../src/entities/wolf.gd#L63)) sorteia patrulha e desvio.
As sementes vêm de `("population:%d" % world.gen.world_seed).hash()` e
`("wolf:%d:%d" % [world.gen.world_seed, identity]).hash()` — a semente *real* do mundo, de 64
bits, em vez do inteiro de 32 bits do engine. O gerador da população só é semeado quando
`_next_identity == 0` ([main.gd:200-201](../src/main.gd#L200-L201)), para que um lote de respawn
continue o fluxo em vez de repetir as primeiras casas. O grep de `randf`/`randi`/`randf_range`
sem receptor em `src/` devolve zero ocorrências; sobram dois locais com gerador próprio
([mind.gd:30-32](../src/ai/mind.gd#L30-L32), [voxel_atlas.gd:50-63](../src/world/voxel_atlas.gd#L50-L63))
e o `seed(SEED)` de [tests/aether_reactions_test.gd:94](../tests/aether_reactions_test.gd#L94),
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
([:674-687](../tests/smoke_test.gd#L674-L687)): o que sai no corte não decai mais, então o saldo
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
