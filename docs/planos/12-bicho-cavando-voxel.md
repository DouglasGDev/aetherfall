# 12 — Bicho cavando voxel

Dossiê de **leitura de código**, não de corrida: nenhuma engine rodou aqui e nenhum número
publicado foi re-medido por este arquivo. Autorização do dono em 2026-11-20
([`AGENTS.md`](../../AGENTS.md), extensão de 2026-11-20), com o recorte respondido na mesma
conversa: **"os dois — lavra contínua + animal cavando"**.

Esta página foi **escrita em 2026-11-20 sobre uma árvore cinco pernas menor** e re-escrita em
**2026-11-22** contra a de hoje, porque desde então pousaram a 09, a 10, a 15, a 14, a 11 e a 19, e a
pauta da 16 já existe. Na fila serializada ela é a **oitava de onze** — **09 → 10 → 15 → 14 → 11 →
19 → 16 → 12 → 17 → 18 → 13** — e não a última da série de quatro que o texto antigo declarava. Nada
daqui é código: a branch `feat/bicho-cavando-12` não abriu.

## 0. O que a página de 2026-11-20 dizia × o que a árvore de hoje devolve

| O texto antigo afirmava | O que a leitura de hoje diz |
| --- | --- |
| "Última da série serializada 09 → 10 → 11 → **12**" | Oitava de onze: depois dela vêm 17, 18 e 13, e antes entraram a 19 (defeito em execução) e a pauta da 16 |
| O gate observava `block_changed` "dispara" | O sinal **não tem nenhum consumidor** no repositório: existem só a declaração ([voxel_world.gd:6](../../src/world/voxel_world.gd#L6)) e o emit ([`:276`](../../src/world/voxel_world.gd#L276)) — o grep de `block_changed` em `src/` e `tests/` devolve essas duas linhas. O dossiê 17 é quem o assina; o gate deste observa estado de mundo lido: `get_block` + `world.edits` |
| `EXPECTED_CHECKS` "**109** na leitura" | **283** nesta árvore ([aether_reactions_test.gd:60](../../tests/aether_reactions_test.gd#L60)). A leitura de 2026-11-22 dizia 225 porque a 16 ainda não havia pousado; a base deste lote (`dcbcbe8`) tem **240** em `:39`, e daqui para cá o lote escreveu **+43** — 247 (a) → 261 (b) → 267 (c) → 271 (d) → 275 (e) → 279 (f) → 283 (g) |
| A suíte "hoje **236**" | Contrato publicado: **255 checagens / 0 falhas**, no pin `9b2c65a` da perna 16 (clone limpo, `--import` frio). Nesta árvore a suíte re-rodou **255 / 0 / 47,9 s** — o lote não toca o `smoke_test.gd`, e é por isso que o número não sobe |
| (o runner de RNG não existia) | Hoje existe [tests/simulation_rng_test.gd](../../tests/simulation_rng_test.gd), **27** checagens (`:9`), e uma delas é que o desvio do lobo **não consome a RNG global** ([`:226`](../../tests/simulation_rng_test.gd#L226)) — é o que amarra o §5.9 |
| "`STONE 0,95`, `WOOD 0,55`, `COBBLESTONE 0,85` ficam **fora** do alcance com a mesma régua do jogador" | **Falso, lido hoje**: `hardness` é **duração**, não permissão. O jogador soma `_mining_accum += delta` e compara a `target_hardness` sem nenhum teto de bloco ([player.gd:663-664](../../src/entities/player.gd#L663-L664)), e `_mine_target` escreve `AIR` no alvo seja ele qual for ([`:685`](../../src/entities/player.gd#L685)). A pedra cai em 0,95 s de mão nua. O que limita o bicho é **lista de material**, não a dureza |
| "o desemperto atual termina em desvio geométrico e nunca em escavação" | Ainda verdade, mas o desemperto **ganhou um segundo braço** depois daquela página: a perna 19 escreveu o pulo de degrau — `STEP_JUMP 7,6` ([wolf.gd:101](../../src/entities/wolf.gd#L101)) e o discriminador `body.can_step_over(want)` ([`:992-993`](../../src/entities/wolf.gd#L992-L993), predicado em [voxel_body.gd:166-173](../../src/entities/voxel_body.gd#L166-L173)). Cavar passa a ser o **terceiro** braço do mesmo `if`, não o destino único do bloqueio |
| "a árvore tem `Selector[flee, hunt, sniff, patrol]`" | Confere, mesma linha: [wolf.gd:389-390](../../src/entities/wolf.gd#L389-L390), com os 400 µs do `SubtreeGuard` |
| `_leaf_investigate` `508-536` e `_scent_ground_y` `937-945` | Conferem por conteúdo, não só por faixa (re-derivadas na árvore da perna 16, que acrescentou linhas ao arquivo: eram `499-527` e `928-936`): o estado parado é `_move_target = body.feet_pos` / `_speed = 0,0` ([`:523-524`](../../src/entities/wolf.gd#L523-L524)) e o chão vem da varredura **para baixo** na coluna da célula ([`:941-945`](../../src/entities/wolf.gd#L941-L945)) |
| "WORK é assinatura exclusiva do jogador" | Continua verdade — o único imprint de WORK é o do `acted` do `Player` ([main.gd:913-918](../../src/main.gd#L913-L918)) — e a perna 10 já registrou que **esta** página decide a quebra: o §3.3.(i) do dossiê diz que "a partir daqui WORK deixa de ser assinatura exclusiva do jogador, e é a checagem 3 do dossiê 12 que decide isso" ([`docs/planos/10-alcateia-rutinas.md`](10-alcateia-rutinas.md)) |
| "o imprint do lobo" (não existia como caminho nomeado) | Hoje existe e já tem viés de bioma: `_imprint` do lobo ([wolf.gd:356-358](../../src/entities/wolf.gd#L356-L358), legado da perna 09), com o comentário **já escrito** de que "cavar nao troca o clima da coluna" ([`:354-355`](../../src/entities/wolf.gd#L354-L355)). O WORK do bicho usa esse caminho, não um novo |
| "5 lobos (12 com o censo do dossiê 11)" | O censo variável pousou: `CENSUS_CAP := 12` ([main.gd:18](../../src/main.gd#L18)) e idade/fase andam no relógio da sessão dentro do `sim_step` ([wolf.gd:818-823](../../src/entities/wolf.gd#L818-L823)). **Isso muda quem cava**: um filhote na fase 0 mede 0,45 do corpo adulto ([`:89`](../../src/entities/wolf.gd#L89), `DIMS` adulto em [`:96`](../../src/entities/wolf.gd#L96)) e o alcance do degrau é derivado de `dims` ([voxel_body.gd:171](../../src/entities/voxel_body.gd#L171)) — o §3.2 decide por quem o predicado fala |
| "`record := true` por decisão explícita" | Continua a decisão, mas as linhas do save mudaram: a lista é gravada em [main.gd:990-992](../../src/main.gd#L990-L992) com a chave `"edits"` em [`:1009`](../../src/main.gd#L1009) e reaplicada no load em [`:1051-1054`](../../src/main.gd#L1051-L1054) |
| (nada sobre bancadas) | As bancadas do jogador são uma **lista derivada do mundo** alimentada só pelos sinais do `Player` ([main.gd:152-153](../../src/main.gd#L152-L153), [`:921-930`](../../src/main.gd#L921-L930), lida por `bench_positions()` [`:934-935`](../../src/main.gd#L934-L935)) e só se reconstrói no load ([`:1145-1149`](../../src/main.gd#L1145-L1149), chamado em [`:1072`](../../src/main.gd#L1072)). Um lobo removendo uma bancada deixaria a lista apontando para ar na sessão viva — é o **furo #22**, e o §3.2 o fecha por construção |
| (nada sobre o journal) | As edições **entram** na projeção do hash: `world.edits.keys()` ordenados ([tick_journal.gd:17](../../src/persistence/tick_journal.gd#L17), gravados em [`:21`](../../src/persistence/tick_journal.gd#L21)) e `wolf.intent` também ([`:35`](../../src/persistence/tick_journal.gd#L35)). Uma corrida com cavar **não** reproduz os hashes publicados — §6 |

## 1. Premissa nomeada

**Um animal que cava tem de ser observado removendo um voxel que o jogador não tocou, e o mundo tem
de registrar isso.** Falsificável em headless: cenário sem nenhum input do jogador, `world.get_block`
de um voxel ocupado vira `AIR` por ação do lobo, a chave entra em `world.edits` e o imprint de WORK
aparece na célula de Éter — **tudo isso sem uma linha de lavra do jogador no meio**. Se o único
`set_block` do cenário for o do `Player`, a mecânica não existe.

O texto antigo punha `block_changed` nessa lista de observáveis. Ele **não pode** estar lá: ninguém o
escuta hoje, e um sinal sem consumidor não é evidência de nada — é a mesma razão pela qual o dossiê 17
nasce vermelho justamente por causa disso. A premissa se decide por estado de mundo lido
(`get_block` + `edits`), que é o que o save grava e o journal hashia.

Recorte que a premissa **não** cobre, e o código já entrega: a lavra contínua do jogador existe —
segurar `break_block` soma `_mining_accum` por frame até a dureza
([player.gd:654-665](../../src/entities/player.gd#L654-L665), o reset de alvo em
[`_progress_of`](../../src/entities/player.gd#L644-L648)), e o drop do registro entra direto no
inventário ([`_mine_target`](../../src/entities/player.gd#L677-L690), com a recusa de espaço em
`:680-684`). As três promessas já são checadas
([smoke_test.gd:923-931](../../tests/smoke_test.gd#L923-L931): "segurar break minerou", "tempo de
mineracao == dureza", "lavra entrou no inventario como drop"). **Mexer nisso é violar o mandato
"não melhorar um sistema que já passou no gate dele"** — este dossiê não toca `player.gd`.

## 2. Estado real do código (lido, não medido — re-lido em 2026-11-22)

- **Nenhum bicho escreve no mundo.** Os dois únicos `world.set_block` de gameplay do `src/` são do
  jogador ([player.gd:685](../../src/entities/player.gd#L685),
  [:711](../../src/entities/player.gd#L711)); os outros chamadores são a própria classe
  ([voxel_world.gd:261](../../src/world/voxel_world.gd#L261), em `_write_raw`) e a geração
  ([world_gen.gd:194](../../src/world/world_gen.gd#L194),
  [:196](../../src/world/world_gen.gd#L196), [:275](../../src/world/world_gen.gd#L275),
  [:293](../../src/world/world_gen.gd#L293), [:309](../../src/world/world_gen.gd#L309)). A perna 19
  **não** mudou isso: ela ensinou o lobo a **subir** o obstáculo, não a removê-lo.
- **A API já é a certa e já é pública**:
  [`set_block(p, b, record := true) -> bool`](../../src/world/voxel_world.gd#L266-L279) — recusa
  fora dos limites, recusa escrever o que já está lá, grava em
  [`_write_raw`](../../src/world/voxel_world.gd#L256-L265) (chunk **e** índice linear `_flat`),
  guarda a edição em [`edits[p]`](../../src/world/voxel_world.gd#L42), marca chunks sujos em
  [`_touch_chunks_of`](../../src/world/voxel_world.gd#L280-L293) e emite
  `block_changed(pos, prev, now)` **para ninguém**. O lobo já segura `world` e `aether` desde o
  [`setup`](../../src/entities/wolf.gd#L240-L259).
- **`edits` é a proveniência que faltava, e ela já existe.** `record` é o que separa "o mundo gerou
  isto" de "alguém construiu isto": a geração **não** escreve em `edits`, a colocação do jogador
  escreve ([`:273-274`](../../src/world/voxel_world.gd#L273-L274)). Então
  `not world.edits.has(pos)` é a cláusula que diz "cavar não desmonta a obra de outro" sem perguntar a
  ninguém de quem é o bloco — é o fechamento do furo #22 (§3.2) e custa uma comparação.
- **O caminho do WORK hoje é do jogador** — o sinal `acted` do `Player` é o que imprime WORK 0,42
  (quebra) e 0,20 (coloca) em [main.gd:913-918](../../src/main.gd#L913-L918). Se o lobo cavar sem
  imprimir, o rastro de trabalho continua sendo assinatura exclusiva do jogador — e é exatamente isso
  que os cenários `_test_work_approach`
  ([aether_reactions_test.gd:342](../../tests/aether_reactions_test.gd#L342)) e `_test_work_cycle`
  ([`:449`](../../tests/aether_reactions_test.gd#L449)) usam como premissa, e o que a perna 10
  declarou que **esta** página decide. **Consequência registrada:** um `WORK` vindo de bicho passa a
  ser lido como se fosse de jogador; o lote decide isso **antes** de escrever, com a checagem A/B do
  §5.3.
- **Durezas: régua de tempo, não de permissão.** A tabela
  ([block_defs.gd:116-122](../../src/world/block_defs.gd#L116-L122)) dá `SNOW 0,25`, `SAND 0,30`,
  `DIRT 0,35`, `GRASS 0,38`, `STONE 0,95` e `WOOD 0,55`, e os materiais de craft continuam nela
  (`COBBLESTONE 0,85` [`:128`](../../src/world/block_defs.gd#L128), `BENCH 0,50`
  [`:130`](../../src/world/block_defs.gd#L130), `GLASS 0,10` [`:133`](../../src/world/block_defs.gd#L133));
  o default para id sem linha é 0,4 ([`:93`](../../src/world/block_defs.gd#L93)) e `hardness()` é só o
  lookup ([`:171`](../../src/world/block_defs.gd#L171)). Repare no que isso faz com a frase antiga:
  **vidro é mais mole que neve**, e a bancada é mais mole que pedra. Lista de material, não ordenação
  por dureza, é o que decide o que uma pata cave.
- **O custo de cada voxel removido é a malharia, medida:** `set_block` → `_touch_chunks_of` → fila
  `_dirty`, consumida por [`process(p_frame_budget)`](../../src/world/voxel_world.gd#L192-L200) com
  `MESH_BUDGET := 2` chunks por frame ([main.gd:28](../../src/main.gd#L28), chamada em
  [main.gd:309-310](../../src/main.gd#L309-L310)). As duas leituras que o contrato publica: **64 chunks
  em ~4,3 s no boot** ([README.md:642-643](../../README.md#L642-L643); 4.640–4.886 ms nas cinco
  corridas históricas, [docs/melhorias-status.md:83](../../docs/melhorias-status.md#L83)) ≈ 67
  ms/chunk, e o tempo do último lote no F3 ([`ultimo %.2f ms`](../../src/ui/hud.gd#L253-L255), lido de
  [`last_mesh_ms()`](../../src/world/voxel_world.gd#L207)). Os dois números convivem porque o boot
  congela a janela, mas **a medição de um chunk sujo isolado já existe** desde o dossiê 07c: o carimbo
  posto em [`_mark`](../../src/world/voxel_world.gd#L294-L307) fecha em
  [`_record_edit_cost`](../../src/world/voxel_world.gd#L312-L320) e sai por
  [`edit_mesh_cost()`](../../src/world/voxel_world.gd#L326-L336) no `diagnostics()["edit_mesh"]` — o
  bake-off mediu 52 chunks remalhados por 30 edições com média de 77,6 ms e pico de 162,8 ms no braço A
  ([readback §4](../evidence/af-bakeoff-voxel/readback.md)). O cavar consome esse preço, não o do lote
  de boot. Instrumento que já existia e continua útil como testemunha da fila:
  [`pending_meshes()`](../../src/world/voxel_world.gd#L203) e
  [`meshes_built()`](../../src/world/voxel_world.gd#L211).
- **O desemperto tem dois braços hoje, e o segundo define o terceiro.** Em
  [wolf.gd:986-993](../../src/entities/wolf.gd#L986-L993): contato horizontal persistente arma o
  desvio (`_unstick` + `_detour`) e, **dentro do mesmo `if`**, `body.on_ground and
  body.can_step_over(want)` dá o impulso de 7,6. O predicado que decide o pulo
  ([voxel_body.gd:166-173](../../src/entities/voxel_body.gd#L166-L173)) testa se o corpo **fica de pé
  uma célula acima** na direção do contato, com alcance `max(dims.x, dims.z) * 0,5 + 0,6`. É essa
  grandeza — não uma nova — que diz **qual célula** o lobo está tentando atravessar, e o §3.2 a usa
  como alvo do cavar.
- **Os dois sorteios do desvio não podem virar condicionais.** O comentário em
  [wolf.gd:989-991](../../src/entities/wolf.gd#L989-L991) é uma regra deste lote também: mover um
  `randf()` para dentro de um `if` muda o riacho que [tests/simulation_rng_test.gd](../../tests/simulation_rng_test.gd)
  mede. Cavar **não sorteia nada**, e a checagem §5.9 é o que garante que isso continuou verdade.
- **A inspeção tem estado parado, e é dele que o (b) sai.** `_leaf_investigate`
  ([wolf.gd:508-536](../../src/entities/wolf.gd#L508-L536)) fica RUNNING por `INSPECT_SECONDS` = 2,0 s
  ([`:31`](../../src/entities/wolf.gd#L31)) e, quando chega ao alvo, zera a velocidade sobre a própria
  célula ([`:523-525`](../../src/entities/wolf.gd#L523-L525)). O ponto que ela chama de "chão da
  célula" vem de `_scent_ground_y` ([`:937-945`](../../src/entities/wolf.gd#L937-L945)), que desce a
  coluna até achar o primeiro sólido. **É essa leitura que expõe o rastro**: remover o sólido acima do
  achado muda o `y` que ela devolve para a mesma célula. A frase antiga — "WORK + BLOOD difundem com
  menos barreira" — não é observável, e o motivo está no §3.2.(b).
- **A malha do cenário grava edição.** `_wall`
  ([aether_reactions_test.gd:336-339](../../tests/aether_reactions_test.gd#L336-L339)) e `_cave_carve`
  ([`:1456-1463`](../../tests/aether_reactions_test.gd#L1456-L1463)) chamam `set_block` com `record`
  default — ou seja, o que elas põem no mundo **é construção registrada**. Um cenário que pedisse ao
  lobo "cava essa parede" com a cláusula do §3.2 receberia `false` sempre, e a checagem verdeiria por
  motivo errado. O palco de cavar tem de escrever com `record = false` — e é exatamente o que a suíte já
  faz ao montar situação de mundo ([smoke_test.gd:388](../../tests/smoke_test.gd#L388),
  [`:410`](../../tests/smoke_test.gd#L410), [`:413`](../../tests/smoke_test.gd#L413)).

## 3. O que a peça exige

### 3.1 Acumulador com estado, medido em segundos de simulação

`_dig_accum` por lobo, mesmo modelo do do jogador (`_mining_accum`,
[player.gd:137](../../src/entities/player.gd#L137)), somado com o `dt` **de simulação** dentro do
`sim_step` cronometrado ([wolf.gd:806-843](../../src/entities/wolf.gd#L806-L843)) e comparado a
`BlockDefs.hardness(block)` — a mesma régua que a HUD do jogador mostra, com os mesmos segundos. A
escrita no mundo acontece **uma vez**, quando estoura; nunca por frame. `_dig_accum` e `_dig_pos` são
transitórios como `_checked_scents`, que o load limpa
([wolf.gd:1146-1147](../../src/entities/wolf.gd#L1146-L1147)): uma cova começada antes do save
recomeça depois dele, e isso é honesto porque o que sobrevive é o mundo, não a intenção.

O `sim_step` é **o** lugar, não o `_physics_process`: os timers de cadência já vivem ali
([`:809-817`](../../src/entities/wolf.gd#L809-L817)) e a regra da casa é que o que roda em `_sim_tick`
divide os 50 ms com a matilha ([main.gd:259-261](../../src/main.gd#L259-L261),
[sim_clock.gd:32-39](../../src/core/sim_clock.gd#L32-L39)).

### 3.2 Duas razões para cavar, e só duas — com a lista de material e a cláusula de proveniência

**Alvo:** a célula lida por `get_block` na direção do contato, na altura dos pés, com o mesmo `reach`
que `can_step_over` já calcula ([voxel_body.gd:171-172](../../src/entities/voxel_body.gd#L171-L172))
— não uma raycast nova, não "o bloco na ponta do nariz".

**Material:** `SNOW`, `SAND`, `DIRT`, `GRASS` **e** `not world.edits.has(pos)`. As duas metades fazem
trabalhos diferentes e nenhuma sobra: a lista diz o que uma pata remove (terra solta); a cláusula diz
que o que **alguém construiu** não é terra solta, mesmo quando é `DIRT` — um bloco colocado pelo
jogador tem o id da lista, e sem a cláusula o lobo o desfaz. É também o que fecha o **furo #22**: uma
bancada (`BENCH`) removida por um bicho deixaria `_benches` e `bench_positions()` apontando para ar até
o próximo load ([main.gd:921-930](../../src/main.gd#L921-L930), [`:934-935`](../../src/main.gd#L934-L935),
[`:1145-1149`](../../src/main.gd#L1145-L1149)).

- **(a) abrir passagem** quando o bloqueio persiste **e o pulo não serve**: o braço entra com
  `body.blocked_horizontal` e `_unstick` armado **e** `not body.can_step_over(want)` — exatamente a
  negação da condição que hoje dá o impulso
  ([wolf.gd:992-993](../../src/entities/wolf.gd#L992-L993)). Escada de três degraus: desvia, sobe,
  cava. `[TARGET]` **8 passos** de simulação com a mesma célula-alvo antes de armar o acumulador —
  número **provisório, e medido, não decidido aqui**: o que o fixa é a checagem §5.5 contando em quantos
  ticks um corredor de neve trava um lobo sem cavar e em quantos o mesmo lobo atravessa com. Se o
  número ficar abaixo do que o desvio natural já cobre, cavar vira ruído e o braço morre.
- **(b) expor a entrada do rastro** quando a inspeção terminou sobre uma célula com sólido acima do
  achado: o alvo é a célula **do sólido**, lida pela mesma coluna que `_scent_ground_y` percorre
  ([wolf.gd:937-945](../../src/entities/wolf.gd#L937-L945)), e a consequência observável é **o `y` que
  ela devolve para aquela célula mudar** — com a entrada removida, o rastro passa a ser lido no chão
  onde o focinho chega, não dois blocos abaixo do teto. O texto antigo dizia "WORK + BLOOD difundem com
  menos barreira", e isso **não é observável hoje**: a permeabilidade da difusão amostra **um voxel por
  célula de Éter** (`mid` e o peso `0,15` contra `1,0`,
  [aether_field.gd:174-176](../../src/world/aether_field.gd#L174-L176)), e uma célula de Éter mede
  `AETHER_CELL` blocos — um buraco de um bloco numa parede de quatro não troca a leitura de nenhum
  vizinho. **É o furo #23, cujo dono é a perna 05** (difusão fora do tick), e a regra deste lote é não
  emprestar a observação dele: a checagem §5.6 mede o `y` do chão, que é código que existe.
- **NÃO entra: "pisar neve/areia patrulhando".** É cosmeticamente tentador e custa um remesh por
  passo de patrulha, sem premissa que ele decida. Vira linha de backlog no status.
- **Quem cave: quem alcança.** O predicado do degrau é derivado de `dims`
  ([voxel_body.gd:171](../../src/entities/voxel_body.gd#L171)) e o corpo de um filhote é 0,45 do adulto
  ([wolf.gd:89](../../src/entities/wolf.gd#L89)). O §3.1 não pergunta fase, e é por isso que a regra de
  quem cave tem de ser **a do alcance do corpo**, não uma exceção por idade: se o predicado diz que o
  bicho passa por cima, ele pula; se diz que não passa **e** o corpo alcança a célula, ele cava.
  Nenhuma linha `if fase == ADULTO` — seria um segundo número para a mesma grandeza.

### 3.3 `record = true`, por decisão explícita

Escrever em `edits` significa que a cova **sobrevive ao save**
([main.gd:990-992](../../src/main.gd#L990-L992) + a chave `"edits"` [`:1009`](../../src/main.gd#L1009),
reaplicada no load [`:1051-1054`](../../src/main.gd#L1051-L1054)). O lote grava — é o mundo real do lobo, e
um buraco que some no load é a mentira da vez — e imprime `edits.size()` no `diagnostics()`
([main.gd:1163](../../src/main.gd#L1163), dentro do corpo [`:1159-1191`](../../src/main.gd#L1159-L1191)) para
o crescimento do save ficar à vista. Consequência que o §5.8 cobra como número, não como adjetivo: a
diferença de bytes do arquivo entre o mesmo cenário com e sem cavar.

### 3.4 Fork A/B — onde a decisão de cavar mora, decidido por medição antes do código

- **A (escolhido primeiro): cavar é o terceiro braço do `if` de bloqueio**
  ([wolf.gd:986-993](../../src/entities/wolf.gd#L986-L993)), e o mesmo acumulador serve ao (b), armado
  pelo fim da inspeção. Custo: **zero nós novos na árvore**, nada dentro dos 400 µs do `SubtreeGuard`
  ([`:389-390`](../../src/entities/wolf.gd#L389-L390)), e o estado de cavar não compete com `intent` —
  que é **hashiado** pelo journal ([tick_journal.gd:35](../../src/persistence/tick_journal.gd#L35)), e
  uma string nova ali é mudança de projeção, não detalhe de implementação.
- **B: uma folha `dig` na `Selector`.** Custo real: ela só é alcançada por uma condição de `intent`, e
  `intent` é o que o journal grava — então B **re-deriva** uma checagem que a perna 11 já gateou
  (`journal_hash_inalterado_sem_escolha`) e abre discussão de versão que nenhuma linha deste lote quer
  ter. B existe como alternativa documentada e entra **só** se o A ficar vermelho na §5.5 por motivo que
  não seja o número de ticks.
- A regra de colocação vale nos dois braços: a pertença muda **o que o sorteio e o parto escrevem**,
  não o que o corpo sabe. Um `if intent == "dig"` espalhado por `wolf.gd` é sinal de lote errado — a
  mesma lição que a pauta da 16 escreveu para a colocação de lares.

### 3.5 WORK do bicho com assinatura própria

O imprint acontece no **lobo** pelo caminho que já existe
([`_imprint`](../../src/entities/wolf.gd#L356-L358) → `aether.imprint` com o viés de bioma), com o
mesmo valor da lavra do jogador (0,42) se a intenção for "o outro predador está trabalhando aqui".
Antes de qualquer curva de utilidade ler isso, a checagem A/B do §5.3 tem de existir — senão
`_test_work_cycle` passa a ter uma fonte que ele não declara. Consequência de auto-alimentação
registrada **agora**: o lobo imprime WORK, `BLOOD + 0,35 × WORK`
([wolf.gd:909-911](../../src/entities/wolf.gd#L909-L911)) atrai quem fareja, e o que chegou lá cave de
novo. O §5.3 decide se isso é ecologia ("o rastro do predador que trabalha") ou loop, e a alavanca se a
resposta for loop é a cadência de cavar do §3.2, **não** um canal novo — `Channel.COUNT` é decisão de
versão (§6).

### 3.6 Item nenhum

Não existe inventário de criatura nem entidade de item no chão (o drop do jogador vai direto para
`inv`, [player.gd:688](../../src/entities/player.gd#L688)). O bloco cavado **desaparece** — isso é
honesto e precisa estar escrito, não fingido. O acesso existe no registro
([`drop_of`](../../src/world/block_defs.gd#L166), lido por
[`_mine_target`](../../src/entities/player.gd#L679)) e a regra dele é "por regra o bloco cai como ele
mesmo" ([`_drop`](../../src/world/block_defs.gd#L69), preenchido em [`:92`](../../src/world/block_defs.gd#L92)) —
um **único** comprador hoje, o do jogador; dar ao bicho o segundo comprador é P2, não este lote.

## 4. Custo — as quatro perguntas

- **Roda por frame, por tick ou às vezes?** Acumulador e decisão: **tick de 20 Hz**, dentro do
  `sim_step` cronometrado ([main.gd:259-261](../../src/main.gd#L259-L261),
  [sim_clock.gd:32-39](../../src/core/sim_clock.gd#L32-L39)). A escrita no mundo: **um** evento por
  bloco removido. O remesh resultante: no `_process`
  ([main.gd:309-310](../../src/main.gd#L309-L310)), **fora** do passo de simulação, com budget próprio.
- **Quantas entidades são alcançadas?** Até 5 lobos no boot e até 12 pelo censo da perna 11
  ([main.gd:9](../../src/main.gd#L9), [`:18`](../../src/main.gd#L18)), e cada um alcança **1 voxel** por
  vez. A grande que assusta é o raio do `7×7` do rastro
  ([wolf.gd:890-930](../../src/entities/wolf.gd#L890-L930)) — cavar **não** varre nada: lê `get_block`
  da célula-alvo e, no (b), a coluna que `_scent_ground_y` já percorre
  ([`:942`](../../src/entities/wolf.gd#L942), no máximo 8 passos).
- **Aloco no caminho quente?** Não no acumulador (`float` + uma `Vector3i` + um `int`). O que aloca é a
  consequência: `edits[p] = b` ([voxel_world.gd:274](../../src/world/voxel_world.gd#L274)) e a fila
  `_dirty` (`Array` de chunk, já existente, [`:305-306`](../../src/world/voxel_world.gd#L305-L306)).
  Nada de `Array` novo por tick — que é, aliás, a única linha desta página que encosta no débito
  declarado no contrato ("Alocação no caminho quente existe e não é medida").
- **Como sei que ficou melhor / quanto custa?** Medindo, antes de celebrar: o lote **primeiro** publica
  `worst last_mesh_ms`, `pending_meshes()` máximo e `meshes_built()` com o cavar ativo, e só depois o
  número vai para o status. **Armadilha do instrumento, e ela é do harness:** `_advance` do runner de
  reações **não** chama `world.process`
  ([aether_reactions_test.gd:277-293](../../tests/aether_reactions_test.gd#L277-L293)) — o campo é
  congelado de propósito para isolar a reação. Uma colheita de malha nesse palco mediria a fila
  crescendo sem nunca esvaziá-la, ou seja, o pior caso do mundo real **sem** o trabalho real. O §5.4
  exige `process(MESH_BUDGET)` no fim do cenário, o mesmo padrão que a suíte já usa ao esgotar a fila
  com `w.process(64)` ([smoke_test.gd:745](../../tests/smoke_test.gd#L745)). Critério numérico escrito
  **antes** da corrida: **nenhum frame com `pending_meshes()` acima de 8** (4 frames de budget a 60 fps)
  e `dropped_ticks` continua **0** no smoke — se estourar, a cadência de cavar cai (mais ticks de
  bloqueio antes de armar), **não** o budget de malha sobe.

## 5. Gate em headless

```sh
godot --headless --path . --check-only --script src/entities/wolf.gd
godot --headless --path . --script tests/aether_reactions_test.gd
godot --headless --path . --script tests/simulation_rng_test.gd
godot --headless --path . tests/smoke_test.tscn
```

1. **`lobo_cava_sem_input_do_jogador`** — célula de `DIRT`/`SNOW` **gerada** (palco com
   `record = false`, §2 último item), jogador longe e sem `action_press`, N passos: `get_block` vira
   `AIR`, `world.edits` ganhou a chave e o WORK apareceu na célula de Éter. Imprime o tick em que
   estourou, a dureza do bloco e o número de passos.
2. **`cavar_respeita_a_lista`** — o mesmo cenário em `STONE`: **nada** é removido em 2× o tempo do
   braço verde. Imprime o bloco e a dureza recusada — e, para a lista não virar teorema de dureza, o
   braço `GLASS` (0,10, mais mole que a neve) **também** tem de recusar: prova que o critério é
   material, não tempo.
3. **`work_de_bicho_nao_confundido`** — A/B: cenário com WORK só do lobo, e a leitura que decide
   `investigate` (`BLOOD + 0,35 × WORK`, [wolf.gd:909-911](../../src/entities/wolf.gd#L909-L911),
   seleção de canal em [`:922`](../../src/entities/wolf.gd#L922)) é conferida contra o caso de WORK só
   do jogador. Ou a curva distingue (por canal/origem já existente), ou o texto deixa de dizer que WORK
   é pegada do jogador — **esta checagem é a que decide o desenho**, nasce antes da folha de cavar ficar
   verde, e é a ela que o §3.3.(i) do dossiê 10 aponta.
4. **`malharia_do_cavar_medida`** — a colheita: `worst last_mesh_ms`, `max pending_meshes()`,
   `meshes_built()` antes/depois do lote, `dropped_ticks == 0` e **a fila esvaziada por
   `world.process()` no fim** (§4). Sem as cinco linhas, o número publicado é hipótese.
5. **`abrir_passagem_depois_de_bloqueio`** — corredor entupido por neve, os **dois sentidos** que o
   ciclo de trabalho exige: um braço com o cavar armado atravessa, o outro **não**, e o braço de
   controle mostra que o mesmo estado é indiferente ao cavar quando a célula-alvo não está na lista.
   Este cenário é o que **decide os 8 passos** do §3.2.(a) por número, e imprime os dois.
6. **`entrada_de_rastro_exposta_no_chao_lido`** — o (b): BLOOD impresso sob uma entrada de neve;
   imprime `_scent_ground_y(c)` da célula **antes** e **depois** da cova e o `intent` do passo seguinte.
   Se o `y` não se move, a premissa do (b) era falsa e o item morre — sem importar o que a difusão
   acha (furo #23).
7. **`cavar_nao_toca_construcao_alheia`** — paga o **furo #22**: cenário com uma `BENCH` no caminho do
   lobo; `bench_positions()` continua apontando para a bancada, ela continua sólida em `get_block` e o
   craft do jogador não vê ar na célula. Imprime `_benches.size()` e o bloco antes/depois. O braço de
   controle é o mesmo cenário com `DIRT` **gerado**, onde o cava **acontece** — senão a checagem passa
   por nada acontecer nos dois.
8. **`cavar_sobrevive_ao_save`** — cova + save + load na mesma cena: `get_block` continua `AIR` depois
   do `apply_edits` ([main.gd:1051-1054](../../src/main.gd#L1051-L1054)), `edits.size()` bate, e o
   `_dig_accum` da cova incompleta **não** volta (é transitório, §3.1). Imprime `edits.size()` e os
   bytes do arquivo com e sem a cova.
9. **`cavar_nao_consome_rng_da_sessao`** — o mesmo palco do §5.5 com a RNG global pinada antes e depois
   dos N passos, no molde do `desvio nao consome RNG global`
   ([simulation_rng_test.gd:226](../../tests/simulation_rng_test.gd#L226)), e os dois `randf_range` do
   desvio continuando incondicionais ([wolf.gd:1240-1241](../../src/entities/wolf.gd#L1240-L1241)). Imprime
   os dois `randi()`.

**Contagens.** `EXPECTED_CHECKS` do runner de reações é **283** nesta árvore
([aether_reactions_test.gd:60](../../tests/aether_reactions_test.gd#L60)) e o do runner de RNG **27**
([simulation_rng_test.gd:9](../../tests/simulation_rng_test.gd#L9)); a suíte publicada é **255
checagens / 0 falhas** no pin `9b2c65a` da perna 16. As três foram re-medidas na árvore deste lote —
runner **283 / 0 / 32,742 s** com `OK censo de checagens | 283/283`, RNG **27 / 0 / 2,646 s**, suíte
**255 / 0 / 47,9 s**, zero `SCRIPT ERROR` e zero `[FAIL]` nos três. O que a checagem 9 acrescenta são
quatro linhas: a premissa de o braço de neve armar a pata (`armadas=1`, `horizontais=40`, boca no
tick 28), o `randi()` depois do pino **igual nos dois braços** (`2762692978`, com 28 passos de neve e
200 de pedra), cada quadro de armar sorteando o desvio junto (`armadas_com_rearm == armadas`) e o
detector vendo o sorteio onde a pata **não** arma (pedra: `armadas=0`, `rearms=17`, `_detour` em
`[-1,221, 1,290]`) — a faixa é o que impede a terceira linha de passar por um único sorteio. O número
que vai para o status é o do clone limpo com `--import` frio, medido em (h), com o SHA ao lado — não
antes.

## 6. Consequência de versão, declarada aqui

Nenhuma linha deste lote encosta em `Channel.COUNT`
([aether_field.gd:9](../../src/world/aether_field.gd#L9)), em `FORMAT_VERSION`
([tick_journal.gd:4](../../src/persistence/tick_journal.gd#L4)) nem em `GEN_VERSION`
([world_gen.gd:6](../../src/world/world_gen.gd#L6)), e nenhuma peça do journal é re-escrita. **Ainda
assim uma corrida com lobos cavando não reproduz os hashes das rodadas publicadas**, por um motivo que
não é mudança de projeção: as edições do mundo **estão** na projeção
([tick_journal.gd:17](../../src/persistence/tick_journal.gd#L17), [`:21`](../../src/persistence/tick_journal.gd#L21)),
então o que mudou foi o mundo. É a mesma declaração que as páginas 17 e 18 fazem, escrita antes do
código. E é por isso que o §3.4 recusa de partida a folha que precisasse de `intent` novo:
`wolf.intent` entra no hash ([`:35`](../../src/persistence/tick_journal.gd#L35)).

## 7. O que NÃO fazer

- Não tocar em `player.gd`: a lavra do jogador tem gate próprio e verde
  ([smoke_test.gd:923-931](../../tests/smoke_test.gd#L923-L931)); refatorar `set_block` "para os dois
  chamadores ficarem limpos" é generalizar no primeiro, e o contrato manda no segundo.
- Não dar ao bicho uma força de escavação maior que a mão do jogador: se o lobo quebra `STONE` em
  0,3 s, o `hardness` do registro ([block_defs.gd:116-122](../../src/world/block_defs.gd#L116-L122))
  deixa de ser a régua do mundo e os números do README passam a valer só para o jogador. A lista do
  §3.2 é o que impede isso — **e ela não é a dureza**.
- Não deixar o cavar desmontar construção: `not world.edits.has(pos)` não é otimização nem higiene
  estética, é o furo #22. Removê-la "porque a lista já basta" abre um caminho em que um bicho apaga a
  bancada do jogador no meio da sessão.
- Não montar cenário de cavar com `record = true` (`_wall`, `_cave_carve`): a cláusula de proveniência
  recusa parede de teste, e a checagem fica verde pelo motivo errado (§2, último item).
- Não fazer cópia de inventário de criatura nem entidade de item no chão: nenhuma das duas existe, e a
  segunda é P2.
- Não subir `MESH_BUDGET` ([main.gd:28](../../src/main.gd#L28)) para esconder a fila `_dirty`: o budget
  é o número do contrato, e a cadência de cavar é a alavanca.
- Não colher malha sem esvaziar a fila: `process(MESH_BUDGET)` no fim do cenário, ou o
  `pending_meshes()` publicado é a fila do harness, não o custo do mundo.
- Não imprimir WORK de bicho sem a checagem 3: é a única coisa que impede os cenários existentes de
  passarem a afirmar algo que deixou de ser verdade.
- Não assinar `block_changed` aqui: o primeiro consumidor do sinal é o objeto do dossiê 17, e um
  segundo lote chegando antes dele repete o "generalizar no primeiro chamador".

## 8. Commits atômicos

(a) instrumento primeiro: `last_mesh_ms()`, `pending_meshes()` e `meshes_built()` colhidos no runner,
com o número do estado **atual** (sem cavar) na mesa e a fila esvaziada no fim do cenário; (b) alvo +
lista de material + cláusula de proveniência, com as checagens 1, 2 e 7; (c) acumulador e o braço (a),
com o número dos 8 passos decidido, com 5; (d) WORK, com 3; (e) expor a entrada do rastro, com 6;
(f) `record = true` e save, com 8; (g) RNG e contagens, com 9 e o item "Contagens" do §5; (h) status +
`README.md` com as medições do clone limpo. Branch `feat/bicho-cavando-12`, merge `--no-ff`, e a 16
**pousa antes** de esta abrir — as duas escrevem `src/main.gd`, e a 16 é quem decide onde os lares
ficam.

## 9. O que este dossiê não fecha

Nenhum gate de fase (mandato 4). Não é ecologia (P2), não é física de blocos nem camadas verticais — a
especificação dessas ([`docs/design/10-world-layers-and-block-physics.md`](../design/10-world-layers-and-block-physics.md))
continua com os ids 9..18 reservados
([block_defs.gd:5-8](../../src/world/block_defs.gd#L5-L8), [:39](../../src/world/block_defs.gd#L39)),
e o cavar de um bicho **não** preenche essa reserva: ele usa `AIR` e o registro existente.
