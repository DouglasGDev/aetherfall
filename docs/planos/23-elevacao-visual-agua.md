# 23 — Água viva: o material que não existe e a partícula que nunca foi criada

Dossiê de **leitura de código**, escrito a pedido do dono em 2026-11-24, na própria conversa, como
prompt "Aetherfall: Elevação Visual (Texturas + Água + Atmosfera)" com cinco fases e a instrução
de começar pela Fase 1 e entregar o plano técnico + abordagem de shader e partículas. O registro
vem **antes** de qualquer linha de código, como exige o mandato 4 de
[`AGENTS.md`](../../AGENTS.md). **Depois do pouso**, a base dos números mudou de propósito: os
`arquivo:linha` desta página são da árvore em que a perna fecha, e as leituras da árvore de abertura
— o material que não existia, o `COLOR` que ninguém lia, o sol que não tinha variável — ficam pinadas
em `b0ed929:` onde o contraste entre o que o prompt dizia e o que o código passou a fazer é a
afirmação. Sem isso, "hoje não há um shader nenhum" viraria mentira dentro da própria página.

A autorização do dono cobre **a Fase 1 como código** (água, pousada em `05e8917`), **a Fase 2 como
código** (chuva e superfícies molhadas, cortada em §3.10 com gate em §5.3/§5.4) e **as Fases 3→5 como
pauta dentro da mesma perna**, cada uma com gate próprio e nenhuma linha escrita antes de a anterior
fechar o dela — a mesma regra que a perna 22 recebeu no prompt de cinco fases dela
([22-oraculo-nativo-gdextension.md](22-oraculo-nativo-gdextension.md)). Nada aqui reabre gate de
fase.

## 1. Premissa nomeada

**A superfície da água se move, tem profundidade, reflete e reage a quem entra nela — e continua
lendo como água de mundo de blocos.** Falsificável em headless sem afirmar nada sobre pixels: o
material dos surfaces de água passa a ser um `ShaderMaterial` cujo código declara os uniformes que
o GDScript realmente grava, a máscara que ondula só acende nos vértices do plano de superfície
(aritmética de `FACE_CORNERS`, derivada à mão no §5), o total de triângulos do mundo **não se
move** com a mudança, e um corpo que cai dentro de uma coluna de água dispara um salpico cujo
teto de partículas é número de código, não adjetivo.

Os dois sentidos que o ciclo de trabalho (item 3) exige:

- **braço vermelho de origem**: com o código de hoje as quatro primeiras asserções não têm o que
  checar — `grep -rn "ShaderMaterial\|Shader.new\|gdshader" src tests` devolve **vazio** e
  `grep -rn "GPUParticles3D\|CPUParticles3D\|ParticleProcessMaterial" src tests` devolve **vazio**
  (a única palavra `MultiMesh` no repositório está num comentário que a **rejeita**,
  [aether_viz.gd:5](../../src/rendering/aether_viz.gd#L5)). Não há um shader e não há uma partícula
  no projeto inteiro; a página não descreve peça inexistente porque ela nasce vermelha por isso.
- **braço de indiferença**: um corpo que **não** entra na água (anda em terra seca, ou flutua
  sem cruzar o plano) não pode disparar salpico nenhum, e a coluna de dois blocos §5 tem de
  mostrar que o bloco de baixo — que tem água em cima — **não** ondula. Sem esse lado, a checagem
  verde afirmaria apenas que atiramos partículas sempre que existe água perto.

## 2. Estado real do código (lido, não medido)

**A água de hoje era um `StandardMaterial3D` com o tile do atlas.** `_build_materials` criava
`_mat_water` com `TRANSPARENCY_ALPHA`, `albedo_texture = _atlas`, `CULL_DISABLED`, `roughness = 0,3`
e filtro `LINEAR_WITH_MIPMAPS` (`b0ed929:src/world/voxel_world.gd:92-97`, a árvore desta leitura) —
nada de tempo, nada de normal, nada de cena. O tile é 16×16 com **faixa fixa por linha**
(`y % 4 == 0` clareia, `y % 4 == 2` escurece) e alfa **0,72 escrito no pixel**
([voxel_atlas.gd:162-171](../../src/world/voxel_atlas.gd#L162-L171)). Isso é o que o prompt chama
de "bloco transparente simples", e é exato. **O que a perna pôs no lugar:** `_mat_water` agora vem de
`WaterSurface.build_material(_atlas, _water_sun)`
([voxel_world.gd:154](../../src/world/voxel_world.gd#L154) no HEAD de hoje, com o acessor
`water_material()` em [`:177-178`](../../src/world/voxel_world.gd#L177-L178); o ponteiro desta linha
dizia `:131`, que na árvore do próprio pouso (`05e8917`) era `_flat_ready = false` dentro de `generate()`
— face do furo #28: em-range não é correto); `StandardMaterial3D` sobrou só para o
opaco (`eb218fe:src/world/voxel_world.gd:91-96`, a árvore desta leitura) e para o vidro
(`eb218fe:src/world/voxel_world.gd:101-107`), e `voxel_atlas.gd` não foi tocado. **O parágrafo
anterior é o estado de abertura da Fase 2 também**: o que restou de `StandardMaterial3D` é justamente o
que a Fase 2 troca por shader — o opaco passou a `OpaqueSurface.build_material(_atlas)`
([:153](../../src/world/voxel_world.gd#L153)) e o vidro continua `StandardMaterial3D`, hoje em
[:158-164](../../src/world/voxel_world.gd#L158-L164) —, e o `COLOR` do grupo opaco, que a água
aprendeu a ler, continua tendo um
canal que ninguém lê — a leitura com número está no §3.10b.

**Quem desenha a água é o mesmo culling dos demais blocos, e ele só cede face contra AR.** Na
malharia, `Draw.LIQUID` descarta a face quando o vizinho **não é** `AIR`
([voxel_world.gd:432-434](../../src/world/voxel_world.gd#L432-L434)); o vizinho sólido **do outro
lado** desenha a face contra a água, porque a água não é opaca
(`is_opaque` 0 — [block_defs.gd:100](../../src/world/block_defs.gd#L100), teste em
[voxel_world.gd:438](../../src/world/voxel_world.gd#L438)). Consequência que o plano aproveita: a
geometria de água visível é **a superfície mais as faces laterais expostas ao ar** — o leito já é
desenhado pelo material opaco, então refração tem o que refratar. O topo afunda
`WATER_TOP_DROP = 0,12` ([`:34`](../../src/world/voxel_world.gd#L34), aplicado na chamada da água em
[`:448-450`](../../src/world/voxel_world.gd#L448-L450) e no vértice de topo dentro de
[`_emit_face:966-967`](../../src/world/voxel_world.gd#L966-L967)).

**Cada face é um quad de quatro vértices próprios, e o `COLOR` do surface de água estava livre.**
`_emit_face` acrescenta 4 vértices por face ([`:963-968`](../../src/world/voxel_world.gd#L963-L968))
e o vertex color da água **não era lido por ninguém**: `_mat_water` não ligava
`vertex_color_use_as_albedo` (o ligador era só o do opaco `b0ed929:src/world/voxel_world.gd:88` e o do
vidro, hoje [`:161`](../../src/world/voxel_world.gd#L161)), e a água entrava com o `ao` forçado em
`[1,1,1,1]` ([`:449`](../../src/world/voxel_world.gd#L449) na chamada de hoje,
`b0ed929:529-530` na leitura de abertura). É o canal que a malharia já escrevia e o jogo já
descartava — §3.3. E é um achado, não uma conveniência: a face escreve
`bright = clampf(tint * ao[k], 0.05, 1.2)` com o `tint` sendo o `FACE_TINT[f]` da face
([`:973`](../../src/world/voxel_world.gd#L973); `b0ed929:627-628` onde esta leitura o achou) — as
laterais 0,88/0,82 e o fundo 0,60 — e na árvore de abertura ninguém lia o resultado, então a água era
desenhada com a **mesma** cor em topo, lado e fundo, e o
trabalho de calcular a sombra de face ia embora. Isso é o **furo #43**, dono esta perna, e o conserto é
exatamente o canal virar lido: hoje o `COLOR` dos quatro cantos da face de água é a máscara que o
shader lê ([`:979-983`](../../src/world/voxel_world.gd#L979-L983)).

**Não há shader nenhum no repositório, e o atlas é gerado em runtime de propósito.** A regra está
escrita no cabeçalho do próprio atlas: "sem binarios no repositorio, deterministico"
([voxel_atlas.gd:2-3](../../src/world/voxel_atlas.gd#L2-L3)). `grep` de `ShaderMaterial`,
`Shader.new` e `gdshader` em `src/` e `tests/`: **zero ocorrências**. `project.godot` declara
`forward_plus` com `msaa_3d = 2`.

**Não há partícula nenhuma.** `GPUParticles3D`, `CPUParticles3D` e `ParticleProcessMaterial` não
aparecem em `src/` nem em `tests/`. A primeira partícula do projeto entra aqui, com teto escrito
como código (§3.6, §4).

**Quem sabe que um corpo está na água é o próprio corpo, a cada frame de física.**
`VoxelBody.move_and_collide` grava `in_water = world.box_in_water(aabb())`
([voxel_body.gd:55](../../src/entities/voxel_body.gd#L55)), e `box_in_water` varre as células cobertas
pela caixa ([voxel_world.gd:723-732](../../src/world/voxel_world.gd#L723-L732)). O jogador lê o campo
para nadar e para a respiração ([player.gd:486](../../src/entities/player.gd#L486),
[:537](../../src/entities/player.gd#L537), [:593](../../src/entities/player.gd#L593)) e o lobo para
empuxo, velocidade e o cronômetro de nado ([wolf.gd:1223-1224](../../src/entities/wolf.gd#L1223-L1224),
[:1230](../../src/entities/wolf.gd#L1230), [:1265](../../src/entities/wolf.gd#L1265)).

**Já existe o padrão de quem reage à transição sem escrever no mundo.** O diretor de áudio guarda
um estado por corpo e age na **borda** da mudança: `if in_water != bool(st["in_water"])`
([audio_director.gd:439-441](../../src/audio/audio_director.gd#L439-L441)), alimentado por leitura do
`body` do jogador ([`:462`](../../src/audio/audio_director.gd#L462)) e de cada lobo
([`:503`](../../src/audio/audio_director.gd#L503)), com a lista entregue por
`wolves_provider` ([`main.gd:227`](../../src/main.gd#L227)). É a mesma fiação, sem sinal novo, que o
FX de água usa (§3.7). O áudio é o **primeiro** consumidor dessa leitura; este é o segundo — e é por
isso que a regra da casa (generalizar no segundo chamador, não no primeiro) permite a peça nova sem
pedir um mecanismo novo.

**A cena tem um sol parado e uma neblina de duas linhas.** `_build_environment` monta
`DirectionalLight3D` com `rotation_degrees = (-42, 55, 0)`, `light_energy = 1,60`, sombra a 80 m,
`ProceduralSkyMaterial`, `ambient_light_energy = 0,85`, `TONE_MAPPER_FILMIC`, `fog_enabled` com
`fog_light_color = (0,55, 0,65, 0,78)` e `fog_density = 0,006`
([main.gd:1278-1314](../../src/main.gd#L1278-L1314)). Não há ciclo de dia/noite, então "caústicas
quando o sol está alto" (§ Fase 1) é hoje uma **constante**, não uma variável: a elevação do sol é
fixa em ~48°. Registrar isso é o que impõe §3.9. **O que a perna mudou aqui:** a direção parada
deixou de ser invisível ao material — `world.set_water_sun_direction(_sun_dir)` no boot
([`main.gd:151`](../../src/main.gd#L151)) grava o vetor no uniform `sun_dir`
([`voxel_world.gd:188-190`](../../src/world/voxel_world.gd#L188-L190)), e o shader decide o ganho de
caústica por ele ([`water_surface.gd:258`](../../src/world/water_surface.gd#L258)). O que continua
parado é o sol, não o canal — e é isso que deixa a Fase 2 como pauta.

**Headless não exercita o renderer, e isso é premissa do gate, não detalhe.** A suíte roda com
`DisplayServer.get_name()` impresso em [smoke_test.gd:375](../../tests/smoke_test.gd#L375) e nenhuma
checagem sua depende de pixel. Um `Shader` quebrado **não** faz a suíte vermelha: a compilação é do
`RenderingDevice`, que em headless não existe. §5 separa as duas provas por causa disso, e o mandato
1 não permite publicar "shader ok" com o número de uma corrida que não compila nada.

**Emenda medida na Fase 2 (`0bce05d`), e ela aperta a cláusula em vez de afrouxá-la:** headless **não**
é cego ao shader — ele não desenha nem gera SPIR-V, mas o front-end GLSL roda quando o
`ShaderMaterial` toma o `Shader`, e a recusa sai no stdout como `SHADER ERROR`. Medido com o caso que
esta emenda corrige: a primeira versão do `OpaqueSurface` escrevia `render_mode
specular_schlick_blurry`, que é de Godot 3, e a corrida do código A ([`chuva23-codigo-a.log`](../evidence/elevacao-visual-chuva-23/chuva23-codigo-a.log))
saiu com **4** `SHADER ERROR` e **4** `Shader compilation failed` (um por mundo construído no palco),
com o backtrace apontando `build_material (res://src/world/opaque_surface.gd:...)` — e o veredito da
suíte continuou **274 checagens / 5 falhas**, nenhuma delas de shader. Depois do conserto
([`chuva23-rendermode-conserto.log`](../evidence/elevacao-visual-chuva-23/chuva23-rendermode-conserto.log)),
o mesmo instrumento devolve **0** e **0**, com as mesmas cinco falhas de outro dono. Duas consequências:
o número `SHADER ERROR=0` lido do log de suíte arquivado passa a ser testemunha de compilação do
front-end, e a sonda com janela deixa de ser a única testemunha de shader para ser a única de
**pixel**. O furo está no instrumento, não no shader — é o **#50**: montar o `Shader` sem prender nada
a um `ShaderMaterial` não imprime erro nenhum, porque a parse acontece no `set_shader()`.

## 3. O que a peça exige — decisão, braço rejeitado, número que reabre o braço

### 3.1 O material da água é um `ShaderMaterial` gerado em runtime, de um arquivo `.gd`

**Decisão:** um módulo novo, `src/world/water_surface.gd`, com a fonte GLSL como constante e
`build_material(atlas) -> ShaderMaterial`. `_mat_water` do mesher passa a ser **esta** peça, e o
restante da malharia não muda.

**Braço rejeitado:** um arquivo `water.gdshader` importado. Custo medido antes de escolher: a
família de artefatos de import que este repositório já não controla é o **furo #25** — dois `.uid`
fora do git fazem todo clone limpo mostrar duas linhas `??` depois do `--import`
([`AGENTS.md`](../../AGENTS.md), registro da pauta 20). Acrescentar um recurso importado novo é
acrescentar superfície de import para ganhar lint de editor.

**Número que reabre o braço:** quando existir mais de **um** `.gdshader` no projeto, ou quando um
deles precisar de `render_mode`/`code` dependente de dados de import (texture arrays, material
compilado). Aí o arquivo passa a ser o lugar certo e o `.uid` entra versionado, com a linha do furo
#25 reescrita.

### 3.2 A onda é deslocamento de vértice, não malha nova

**Decisão:** `VERTEX.y` deslocado pela altura de onda avaliada na posição **de mundo XZ** do
vértice, e `NORMAL` reconstruído a partir das derivadas da mesma função. Como o deslocamento é
função só de XZ, dois quads que dividem o mesmo canto dividem o mesmo número: **não existe costura
por construção**, e um quad de topo de 1 m com 4 cantos vira um plano inclinado — que é exatamente
o "continua lendo como bloco" que o princípio 1 do prompt pede.

**Braço rejeitado:** subdividir o topo da água em grade N×N dentro do mesher. Custa vértices e
índices no mesmo lugar que já é o furo **#41** (malharia medida em 52–177 ms no pior quadro, com
orçamento de 2 chunks por frame — [`AGENTS.md`](../../AGENTS.md), tabela de orçamentos) e moveria o
`triangle_count()` que a suíte hoje compara entre dois mundos gerados
([smoke_test.gd:481-489](../../tests/smoke_test.gd#L481-L489), a checagem `malha identica entre mundos`).

**Número que reabre o braço:** se a onda de 4 cantos por célula precisar de mais de **uma** harmônica
a mais para não virar rampa plana, o caminho passa por subdivisão do **topo da água** com formato
próprio, e o gate da malharia tem de ser re-medido com o número novo na mesa — não aceito em silêncio.

### 3.3 O que o shader precisa saber sobre o vértice viaja no `COLOR`, escrito pela malharia

**Decisão:** três canais por vértice dos surfaces de água, derivados do estado real do mundo no
momento da face:

- **R — máscara de onda (1,0 / 0,0):** vale 1 se o canto está **no plano de topo** de um bloco de
  água cujo vizinho de cima é `AIR`. É isso que une o quad de topo aos cantos de topo das faces
  laterais do mesmo bloco, e é por isso que a margem não abre.
- **G — profundidade da coluna (0…1):** quantos blocos de água contíguos existem **abaixo** deste
  bloco antes de achar não-água, saturada em 4. É a cor de corpo (raso esverdeado → fundo azul
  escuro) e a absorção que não depende de ler a cena.
- **B — face vertical (1,0 / 0,0):** a linha d'água nas laterais é outra coisa visualmente; sem
  este canal a espuma de margem subiria pela parede da cachoeira.

**Braço rejeitado (a):** atributo custom do `ArrayMesh` (`ARRAY_DATA`). Não há precedente nenhum no
repositório e a suíte teria de aprender um caminho de leitura novo; o `COLOR` já é enviado por
`_surface_arrays` ([voxel_world.gd:936-946](../../src/world/voxel_world.gd#L936-L946)) para os três
grupos.
**Braço rejeitado (b):** deduzir tudo no shader a partir de `NORMAL` e da posição. Isso **não**
distingue o canto de topo da face lateral do canto de baixo — e é justamente a costura que abre.

**Número que reabre (a):** se um quarto canal for necessário, o `COLOR` fica cheio e aí o atributo
custom tem comprador real.

### 3.4 Refração e reflexão vêm da `hint_screen_texture`

**Decisão:** uma amostra da textura de tela deslocada pela normal em perspectiva
(refração — vê o leito que **já foi desenhado** no passe opaco) e uma amostra na direção
especularmente espelhada (reflexão — vê o céu, que também está no framebuffer), misturadas por
Fresnel (Schlick, com `f0 = 0,02`). O próprio `ALPHA` do material faz o resto da composição.

**Braço rejeitado:** sonda de reflexão / `ReflectionProbe` por bioma, ou `SSR` do
`Environment`. O SSR do engine em `forward_plus` é um passe global cujo custo ninguém mediu nesta
máquina, e uma sonda por cuba exigiria saber onde as cubas estão — o mundo é 128×128 e a água é
gerada ([world_gen.gd:195-196](../../src/world/world_gen.gd#L195-L196)), ninguém a indexa.

**Número que reabre:** se a reflexão de tela mostrar o **chão** no lugar do céu em mais de um quadro
da sonda com janela (§5.2), a alternativa com `sky` no `ALBEDO` pela direção do raio volta à mesa.

### 3.5 Espuma de margem e absorção por pixel vêm da `hint_depth_texture`, com a coluna geométrica ao lado

**Decisão:** a distância linear do plano da água até a geometria atrás (trecho documentado:
`texture(depth, SCREEN_UV)` → `INV_PROJECTION_MATRIX` → `-view.z`) dá a **espessura real** do lençol
de água na vertical daquele pixel: espuma onde é raso, corpo onde é fundo. O canal G do §3.3 é o
que continua desenhando a cor quando essa leitura não alcança (longe do far plane).

**Braço rejeitado:** só a coluna geométrica (sem depth). Ela é quantizada em 1 m e a linha de espuma
sairia em degraus na praia — o prompt pede água que "convence" justamente aí.

**Número que reabre:** se a leitura de depth custar mais que o ganho, o corte se decide pelo
número da sonda com janela (§5.2: ms/frame com e sem o `uniform sampler2D … : hint_depth_texture`),
e a G continua cobrindo a cor.

### 3.6 Partículas existem com teto escrito, em pool, e o teto é diagnóstico

**Decisão:** um nó `src/rendering/water_fx.gd` com **pool fixo** — emissores criados no boot,
reaproveitados, nenhum `new()` dentro de frame ou tick. Salpico (`one_shot` com `explosive`),
anel na superfície e bolhas de fundo. `diagnostics()` do nó devolve `pool`, `salpicos`,
`anis`, `bolhas` e `teto_particulas`; o **teto** é a soma aritmética dos `amount` declarados, e a
checagem de orçamento lê esse número, não minha memória.

**Braço rejeitado:** um emissor por bloco de água, ou spawn de `GPUParticles3D.new()` a cada
entrada. O primeiro multiplica draw call pelo que o mundo gera; o segundo é alocação no caminho
quente — a casa ainda **não tem colheita de alocação** (registro de débito em
[`AGENTS.md`](../../AGENTS.md), "Alocação no caminho quente existe e não é medida"), então criar
uma fonte nova dela sem instrumento é o contrário do mandato 5.

**Número que reabre:** o teto que este corte aceita está no §4 e é impresso. Se um cenário real
estourar o teto (`salpicos_cortados > 0` na sonda), a discussão é **teto maior ou recusa visível**,
não pool dinâmico.

### 3.7 A entrada na água é lida, não sinalizada

**Decisão:** o FX guarda um estado por corpo (chave = `identity`, como `_body_state` do áudio) e
dispara na **transição** `fora → dentro` com `velocity.y` negativo acima de um limiar; a posição do
salpico é o plano de topo da coluna de água sob o corpo, obtido por uma consulta nova ao mundo
(`water_surface_y(x, z)` — a mesma família de `surface_height`,
[voxel_world.gd:811-817](../../src/world/voxel_world.gd#L811-L817)).

**Braço rejeitado:** um sinal `entered_water` no `VoxelBody`. Seria o **primeiro** chamador de um
mecanismo de transição que o áudio já resolve por leitura (`audio_director.gd:439`), e a regra da
casa generaliza no segundo.

**Número que reabre:** quando aparecer o terceiro consumidor da transição, o estado por corpo sai do
áudio e do FX e vira uma peça só — aí o sinal ou o registro compartilhado têm dois compradores.

### 3.8 FX é leitura, não escrita

Nenhum `set_block`, nenhum `AetherField`, nenhuma RNG da simulação tocada por esta perna. O Éter não
ganha canal (`Channel.COUNT` em [aether_field.gd:9](../../src/world/aether_field.gd#L9) continua
intocado, como exige a cláusula da pauta 13), `FORMAT_VERSION`
([tick_journal.gd:4](../../src/persistence/tick_journal.gd#L4)) e `GEN_VERSION` ficam onde estão. A
prova disso é checagem (§5.1), não declaração.

### 3.9 O que as Fases 2→5 exigem, e o que ainda não tem número

Estas linhas entram na fila da perna, **sem nenhuma linha escrita agora**:

- **Fase 2 — chuva e superfícies molhadas.** A decisão está em **§3.10**, o gate em **§5.3** e a sonda
  em **§5.4**. O que a pauta pedia e não tinha número — um clima, um portador de molhamento no opaco,
  um segundo comprador para o anel — passou a ter dono, canal e custo lido.
- **Fase 3 — vegetação viva.** Vento em folhas/grama é deslocamento de vértice com a mesma forma do
  §3.2, e aqui a malharia **não** distingue a face: grama e folha entram no mesmo surface opaco, com
  um `ao` real ([`:455`](../../src/world/voxel_world.gd#L455)) — então o que a fase precisa
  decidir primeiro é **qual canal do `COLOR` opaco** fica livre, e isso é conversa com o face-culling
  que a suíte trava hoje. **A Fase 2 gasta o último canal livre daquele grupo (§3.10c)** e a Fase 3
  herda a consequência escrita lá: o portador dela é o atributo custom do §3.3, cujo número que
  reabria o braço ("se um quarto canal for necessário") agora está satisfeito.
- **Fase 4 — atmosfera.** `fog_enabled` e `fog_density = 0,006` existem com **uma** curva
  ([main.gd:1365-1369](../../src/main.gd#L1365-L1369)); height fog é outra função e precisa do
  `Environment` em recurso versionado, não em código — hoje a neblina é escrita à mão dentro de
  `_build_environment`. God rays em `forward_plus` é volumetria do engine, e ninguém mediu o custo
  dela nesta máquina: a fase **começa pela colheita**, como manda o mandato 5.
- **Fase 5 — materiais dos blocos.** Normal/roughness por bloco exige mapa de normais no atlas ou
  material por id; o atlas é 8×8 de 16 px gerado com `seed` fixa
  ([voxel_atlas.gd:5-14](../../src/world/voxel_atlas.gd#L5-L14)) e **um** `StandardMaterial3D` serve
  os 23 ids. O corte é: variação por material único (canal já existe — o `COLOR` opaco com jitter
  `0,012` em [`:456`](../../src/world/voxel_world.gd#L456)) antes de qualquer atlas novo.

### 3.10 Fase 2 — chuva e superfícies molhadas: decisão, braço rejeitado, número

A pauta do §3.9 dizia que a Fase 2 "reabre a discussão do §3.1 com número na mesa". Relida contra a
cláusula do próprio §3.1, ela **não** reabre, e o motivo é o número (c) abaixo. O resto do corte é o que
estava escrito lá: `Weather` como dono de um estado lido pelo FX **e** pelo material, e o plano de
superfície da água como gancho honesto — a mesma consulta que decide a espuma decide onde a gota cria
anel ([`water_surface_y`](../../src/world/voxel_world.gd#L825-L831)).

**(a) Dono do estado: um nó visual novo, com RNG própria.**

**Decisão:** `src/rendering/weather.gd` (`class_name Weather extends Node`) é dono de exatamente dois
números — `chuva` (alvo, 0…1) e `molhado` (0…1, integrado por `WEATHER_RISE` / `WEATHER_DECAY`
nomeados, com `DECAY < RISE`: o vale seca mais devagar do que molha) — e a única porta de entrada é
`pedir_chuva(alvo)`, chamada no boot pelo CLI `--weather=<alvo>` e pela suíte pelo mesmo caminho. O
estado sai por `apply_sink(Callable)` — o padrão da casa para "um lê, ninguém escreve", o mesmo de
`llm_status_provider` ([main.gd:290](../../src/main.gd#L290)) e `narration_provider` — e por
`diagnostics()`. Quem sorteia colunas de gota sorteia numa `RandomNumberGenerator` **sua**, com
`WEATHER_SEED` nomeada.

**Braço rejeitado:** `chuva` como campo do `VoxelWorld` ou do `main.gd`. O mundo é o estado autoritativo
que entra na projeção do journal (§3.8) e `main.gd` é o objeto deus que a casa registra como débito, não
como licença ([`AGENTS.md`](../../AGENTS.md), "Anti-bloat"). Chuva que escurece uma parede não move pé,
não aplica dano e não escreve no ledger: enquanto for só visual, o dono dela é o renderizador.

**Número que reabre:** quando o clima tiver de mudar **simulação** — lobo buscando abrigo, grama que não
cresce na tempestade —, ele vira estado de mundo, `FORMAT_VERSION` sobe de propósito e o gate passa a
ser de determinismo, não de pixel. Isso é pauta da 20 e da 18, não desta perna.

**(b) O portador do molhamento no opaco é o `COLOR.a`, e a exposição vem de coluna, não de face.**

**Decisão:** a malharia escreve no alfa dos vértices do grupo opaco
`a = clampf(1.0 - float(topo - int(py)) / float(EXPOSURE_FALL), 0.0, 1.0)` — o `topo` é o topo da
coluna —, com `EXPOSURE_FALL = 4` nomeado no mundo
([voxel_world.gd:995](../../src/world/voxel_world.gd#L995), [:41](../../src/world/voxel_world.gd#L41)).
O canal está livre **por leitura, não por intuição**:
`eb218fe:src/world/voxel_world.gd:689` (a árvore desta leitura) escreve `Color(bright, bright, bright, 1.0)`
— alfa constante — e o consumidor da base era um `StandardMaterial3D` com
`vertex_color_use_as_albedo` (`eb218fe:src/world/voxel_world.gd:93`), que multiplica **RGB** no albedo e não tem transparência
ligada, então o alfa do vértice não chega a lugar nenhum. É o achado do furo #43 do outro lado da
mesma mesa: lá, um canal escrito e lido por ninguém virou o portador da onda; aqui, o portador é o alfa
que ninguém lê. O `topo` vem de uma varredura de coluna feita **uma vez por rebuild de chunk**
(um `PackedInt32Array` de 16×16, a mesma família de `surface_height`
[voxel_world.gd:878](../../src/world/voxel_world.gd#L878)), com contador lido e impresso.

**Braço rejeitado (a):** re-malhar quando o molhamento muda. Ele muda a cada quadro de chuva, e a
malharia é o furo #41 (52–177 ms no pior quadro, orçamento de 2 chunks por frame).
**Braço rejeitado (b):** varredura de coluna por face ou por voxel — 6 faces × até 64 leituras, no
exato lugar onde a casa já teve de aprender a não varrer o mundo por triângulo.
**Braço rejeitado (c):** um molhamento global sem canal por vértice: custa zero shader nenhum e perde a
única propriedade pedida, que é o contraste entre o topo do morro e o fundo da ravina.

**Número que reabre (a):** se a exposição por coluna errar na sonda (§5.4 — beiral molhando, ravina
seca onde devia brilhar), a alternativa é varredura por face com cache amortecido, e o `mesh_ms` do boot
volta à mesa com o número novo. **Número que reabre (c):** o ms/quadro do braço com e sem o molhamento
no `fragment()`, e a fração da caixa "abrigo" que muda com a chuva.

**Consequência para a Fase 3, escrita agora porque é desta linha que ela nasce:** o `COLOR` do grupo
opaco passa a ter R, G e B amarrados ao mesmo `bright`
([:996](../../src/world/voxel_world.gd#L996)) e o A gasto. O §3.3 dava como número que reabria o seu
braço (a) — *"se um quarto canal for necessário, o `COLOR` fica cheio e aí o atributo custom tem
comprador real"* — e a Fase 2 é exatamente esse quarto canal. O portador do vento na Fase 3 deixa de
ser o `COLOR` e passa a ser o `ARRAY_DATA`, com a leitura de custo re-escrita lá.

**(c) O material opaco vira `ShaderMaterial` gerado em runtime, e o braço do `.gdshader` continua fechado.**

**Decisão:** `src/world/opaque_surface.gd` (`class_name OpaqueSurface`), GLSL como constante,
`build_material(atlas) -> ShaderMaterial`, espelhando `water_surface.gd` peça por peça — inclusive o par
`written_uniforms()` / `declared_uniforms()`, que é o que impede um uniforme gravado sem declaração de
virar no-op silencioso. O shader **reproduz** o que o `StandardMaterial3D` de
`eb218fe:src/world/voxel_world.gd:91-96` (a árvore desta leitura) fazia na base, e a lista é a fidelidade:
tile amostrado com o filtro do material da base — `BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS`
(`eb218fe:src/world/voxel_world.gd:94`) — e no shader pela declaração equivalente
`filter_nearest_mipmap` ([opaque_surface.gd:61](../../src/world/opaque_surface.gd#L61)) (o atlas gera mips de verdade —
[voxel_atlas.gd:36](../../src/world/voxel_atlas.gd#L36) `generate_mipmaps(false)` — e já vem linear,
[:35](../../src/world/voxel_atlas.gd#L35) `srgb_to_linear()`, então **sem** `source_color`), `COLOR.rgb`
multiplicando o albedo, `ROUGHNESS = 0.92`, `METALLIC = 0.0`, alfa 1 (o passe continua opaco), e as
sombras da `DirectionalLight3D` (`sun.shadow_enabled = true`,
[main.gd:1284](../../src/main.gd#L1284)) recebidas pelo próprio engine — um shader spatial sem
`render_mode unshaded` entra no loop de luz normal. Sobre isso a fase acrescenta o molhamento:
`molhado × COLOR.a` escurece o albedo para o `wet_tint` e baixa a rugosidade de `dry_roughness` para
`wet_roughness`.

**Braço rejeitado:** manter o opaco em `StandardMaterial3D` e molhar por `material_switch` de dois
materiais, ou por `albedo_modulate` global. O primeiro troca o mundo inteiro por um degrau (sem
interpolar nada entre seco e molhado, e o `molhado` é um número contínuo); o segundo é o braço (c) do
(b) com outro nome.

**Número que fecha a discussão do §3.1:** o §3.9 dizia que esta fase "reabre a discussão do §3.1"; a
cláusula dele é *"quando existir mais de **um** `.gdshader` no projeto"*, e o segundo material desta
perna, como o primeiro, nasce de um `.gd`. Arquivos `.gdshader` no repositório: **0 antes, 0 depois**
(`git ls-files '*.gdshader'` vazio, impresso na corrida de §5.3). O braço do arquivo importado continua
sem comprador e o furo #25 continua cobrando duas linhas `??` em todo clone limpo. O que a Fase 2 abre
de novo, com número, é o §3.3 — ver a consequência do (b).

**(d) O anel da gota é o segundo comprador do pool que já existe.**

**Decisão:** `WaterFx.ring_at(x, z, plano)` é a porta pública do `_anel` privado
([water_fx.gd:299-310](../../src/rendering/water_fx.gd#L299-L310)), e quem a chama é o `RainFx` por um
`ring_sink: Callable` ligado no boot pelo `main.gd` — o mesmo formato dos provedores da casa, e por
isso o RainFx não conhece o tipo do WaterFx. O anel passa a ter dono de **origem** (`corpo` ou `chuva`)
num slot do pool, e a testemunha é a soma: `anis_vivos_chuva + anis_vivos_corpo <= RING_POOL`. A
cadência da chuva é escrita para **não** comer o pool: `RAIN_RINGS_PER_BATCH = 1` a cada
`RAIN_RING_PERIOD = 0,12 s` com `RING_LIFE = 1,1 s` dá no máximo ~9 vagas vivas de 12. Coluna sem plano
(`water_surface_y < 0`) **recusa com contador** (`anis_recusados`), nunca com partícula em `y = 0`.

**Braço rejeitado:** um pool de anéis próprio do RainFx. Seriam dois pools desenhando o mesmo anel, e o
teto aritmético do §3.6 dobraria sem compra nenhuma — o §3.6 foi escrito prevendo exatamente este
segundo comprador.
**Braço rejeitado:** a gota como *hitscan* — saber onde cada partícula cai. São as ~750 gotas vivas dos
dois emissores (468 + 280, a aritmética da §5.3) simuladas na GPU por quadro para alimentar uma CPU que
não sabe onde está a superfície; o §4 cobra
cadência e o número seria um desastre anunciado. O que cai é sorteado **como evento visual** pela RNG do
`Weather`, na mesma régua que a espuma já usa.

**Número que reabre:** `anis_cortados > 0` na sonda (§5.4) com a chuva no teto. Aí a escolha é pool
maior ou período maior, e o teto novo é publicado — nunca pool dinâmico (§3.6).

**(e) A água reage à chuva no material, com a mesma forma do §3.2.**

**Decisão:** um uniforme `chuva` no `WaterSurface`, somando à altura de onda uma harmônica de frequência
mais alta e amplitude menor, avaliada **só no XZ de mundo** e ainda multiplicada pela máscara `COLOR.r`.
É isso que mantém a cláusula do §3.2 de pé — "deslocamento função exclusiva de XZ ⇒ não existe costura
por construção" — e é por isso que a reação não entra como ruído por fragmento. Custo: `declarados` e
`gravados` do par de testemunhas sobem de 16/14 para **17/15**, e os três lugares que publicam esse
par (esta tabela, o status e o `AGENTS.md`) são re-derivados no commit final, porque um uniforme escrito
sem declaração é o no-op silencioso que a checagem existe para pegar.

**Braço rejeitado:** bolhas/anéis *só* de partícula para dizer que chove na água. É o que o (d) já faz
no plano certo; no material faltaria o aspecto contínuo — a superfície picada — que é o que a pessoa vê
de longe.

**(f) O que a Fase 2 não toca, e por nome.**

`Environment`, `fog_*`, `sky` e `ProceduralSkyMaterial` ([main.gd:1291-1309](../../src/main.gd#L1291-L1309))
são da **Fase 4** — o §3.9 já os tinha deixado lá e nada desta perna os move. **Som de chuva** não é
desta perna: a cláusula do dono é "só visual", o `AudioDirector` tem dono próprio e a fila dele não é
esta. `block_defs.gd` (reserva de ids 9–18), `src/ai/`, `native/`, `Channel.COUNT`, `FORMAT_VERSION`,
`GEN_VERSION` e a projeção do journal continuam intocados, e `fx_nao_escreve_o_mundo` estendida à janela
de chuva (§5.3) é quem paga a frase, não este parágrafo. O `COLOR.a` dos grupos de **água** e de
**vidro** continua `1.0` e lido por ninguém: a água já encheu R, G e B com as máscaras do §3.3 e o vidro
não tem comprador de molhamento nesta fase.

## 4. Custo — as quatro perguntas

1. **Roda por frame, por tick ou às vezes?** O shader roda por **pixel desenhado de água**, no passe
   transparente — é o único item novo de GPU. O FX consulta os corpos por **frame de física**
   (`_physics_process`), com o mesmo custo de leitura do `box_in_water` que o corpo já faz — ele não
   adiciona varredura de mundo: lê `body.in_water` que já foi calculado. A colocação de anel e o
   disparo de salpico são **por evento** (transição), e a busca do plano de topo percorre **uma
   coluna**: `water_surface_y` ([voxel_world.gd:825-831](../../src/world/voxel_world.gd#L825-L831))
   desce de `CHUNK_SIZE_Y - 1` e **sai no primeiro voxel de água** — que já é o topo da coluna, por
   construção — então são no máximo 64 leituras e a coluna seca paga as 64 inteiras para devolver
   `-1,0`. Não é varredura de mapa.
2. **Quantas entidades são alcançadas?** Corpos: **1 jogador + até 5 lobos** (`WOLF_COUNT = 5`,
   [main.gd:9](../../src/main.gd#L9); censo até `CENSUS_CAP = 12`, [`:18`](../../src/main.gd#L18));
   o FX itera sobre a lista que o `wolves_provider` já devolve. Superfície de água: a área dos surfaces de água dos 64
   chunks, que **não muda** com esta perna (§3.2, §5.1). Teto de partículas: **impresso na suíte** e
   igual a `pool × amount` por sistema, com o valor na linha da checagem — não no adjetivo.
3. **Aloco no caminho quente?** Não. Pool fixo, `Dictionary` de estado por corpo criado **uma vez**
   por identidade (padrão `audio_director.gd:468`), sem `new()` por frame e sem `Array` novo por
   tick. O que esta perna **acrescenta** ao caminho quente é uma `ShaderMaterial` única, construída
   em `_build_materials`, que já roda no boot (os ~4,7 s de malharia medida,
   [main.gd:158-165](../../src/main.gd#L158-L165)) — custo de boot, não de tick.
4. **Como sei que ficou melhor?** Dois instrumentos, cada um respondendo o que pode: as checagens
   novas da suíte (headless: material, máscara, triângulos, orçamento, transição, não-escrita) e a
   **sonda com janela** (§5.2), que é a única que compila o shader e salva PNG do quadro. Headless
   não prova pixel, e a página não finge que prova.

**As mesmas quatro perguntas, respondidas pela Fase 2** (cada resposta com o número que a paga em
§5.3 ou §5.4, porque a pergunta sem número é o mandato 5 virou adjetivo):

1. **Roda por frame, por tick ou às vezes?** Nenhum item da Fase 2 roda no `_sim_tick`. `Weather`
   integra duas retas por **frame de física** (`_physics_process`, 60 Hz — a frase escrita antes do
   código dizia "frame de render (`_process`)", e o medido obrigou a trocá-la: com `_process` o
   `em 150 frames` da checagem `molhado_sobe_e_desce` mediria a carga da máquina, não o clima; com
   `_physics_process` a cadência é a do corpo do jogo e `secs=1,000` sai exato) e só escreve uniforme
   quando o estado se moveu mais que `WEATHER_SNAP` — o contador `pedidos_aplicados` diz quantas vezes
   isso aconteceu na janela (**1** no boot com `--weather=`, `frames_integrados=1352`), e o teto dele é
   o número de frames, não o contrário. `RainFx` decide uma coisa por **lote** (`RAIN_RING_PERIOD`,
   ~8/s) e o resto é a GPU simulando partículas contínuas. A exposição de céu é **por rebuild de
   chunk**: 256 varreduras de coluna no pior caso, e o contador `col_lidas` é asserido contra
   `chunks × 256` (§3.10b) — medido exato nos dois níveis: `chunks_lidos=287 col_lidas=73472
   esperado=73472` no palco da suíte e `157 / 40192` no boot do mundo inteiro. É a linha que impede a
   varredura por face de entrar de novo pela janela, e o número dela é `faces_por_coluna=6,24` — o
   braço rejeitado custaria 6,24 leituras onde hoje custa uma.
2. **Quantas entidades são alcançadas?** 1 jogador + até 5 lobos para o anel (o pool continua 12, com
   a cota da chuva ~9 e a dos corpos no resto — medido `vivo_chuva=4 vivo_corpo=0 pool=12`, com a
   recusa contada em vez de anel em `y=0`: `no_zero=0`), 64 chunks × 256 colunas para a exposição
   (**287 rebuilds** de 256 colunas na janela da suíte, porque rebuild não é censo de chunk: o mesmo
   chunk malha mais de uma vez quando a lavra e o cavar chamam), e **nenhuma
   lista nova por frame**: o cache do chunk é um `PackedInt32Array` alocado no rebuild, no mesmo
   endereço de custo do `_flat` que a malharia já usa.
3. **Aloco no caminho quente?** Não: pool fixo (a regra do §3.6 não mudou, o que mudou é o número de
   compradores dele), `Callable` em vez de referência cruzada, e a GPU pagando as gotas. O que entra
   de custo novo é de **boot** (o cache de colunas dentro dos ~4,7 s de malharia já medida,
   impresso como `mesh_ms` no passo do `_check_boot`) e de **fragment** (uma lerp a mais no opaco,
   que a sonda §5.4 mede com e sem).
   **Medido, e o par é a régua — não um número único:** `mesh_ms` **4 711,061** na base `eb218fe`
   contra **4 906,768** com a varredura de coluna, em 157 `builds` do mesmo mundo, ou **+195 ms
   (+4,2 %)** de boot — exatamente o que esta pergunta autorizou como custo dentro da janela já
   medida do furo #41. A primeira versão da varredura lia o `_flat` global com stride de 16 384 e deu
   **5 163,32** (+439 ms): o caro não era a leitura, era o índice global, e passar a ler o `data` do
   próprio chunk — a mesma aritmética linear que `c.get_block` já usa, com a coluna inteira dentro dos
   16 KB do chunk — cortou 257 ms. As outras duas leituras da série, na mesma árvore com concorrente
   de disco diferente, são **4 973,712** (depois do conserto do `render_mode`) e **4 920,146** (o pin).
   Os contadores do boot no `diagnostics()` fecham a conta sem Godot na mão: `exposure`
   `chunks_lidos=157 col_lidas=40192 faces_opacas=243597 fall=4`, e a igualdade `40192 = 157 × 256` é
   a asserção da pergunta 1 lida no mundo inteiro, não só no palco do teste.
4. **Como sei que ficou melhor?** Três braços no **mesmo enquadramento** (§5.4): a base com
   `StandardMaterial3D`, esta perna **seca** com o shader, e esta perna **molhada**. O par
   base↔seco **não** provou o que esta frase prometia — ele abriu a discussão, e o §5.4 é quem fecha
   com o número: o par sai `fracao_ge3` **0,9803** no topo e **0,9244** no abrigo contra um piso de
   instrumento de **zero exato**, com causa nomeada em dois instrumentos (a segunda decodificação de
   sRGB que o `StandardMaterial3D` fazia de um atlas que já chega linear) e decisão publicada de
   manter o shader como está e abrir o **furo #48** para o `StandardMaterial3D` que sobrou no mundo
   (`_mat_glass`). O par seco↔molhado, sim, prova que o efeito existe: `fracao_ge3` **0,1293** na
   caixa exposta contra **0,0000** exato na abrigada. Em headless, a testemunha estrutural é que o
   `COLOR.rgb` do opaco **não se move** (R=G=B por vértice, §5.3: `verts=4284 rgb_iguais=4284`)
   enquanto o `A` passou a carregar a exposição (`a_min=0.000 a_max=1.000`).

## 5. Gate

### 5.1 headless (suíte `tests/smoke_test.gd`, passos novos no `_steps`)

Números derivados **à mão** de `FACE_CORNERS` ([voxel_world.gd:14-21](../../src/world/voxel_world.gd#L14-L21))
e do culling `LIQUID` (`nb != AIR` → descarta), não lembrados:

| Checagem | O que exige | Número que decide |
|---|---|---|
| `material_da_agua_e_shader` | o surface de água de um chunk real carrega `_mat_water`, e este é um `ShaderMaterial` | `shader=true` com `surface=1`, e o código do shader **declara** cada uniforme que o GDScript grava (lista lida dos dois lados: `declarados=16`, `gravados=14`, `sem_fonte=0`) |
| `mascara_de_onda_do_bloco_isolado` | um bloco de água no ar: 6 faces, 12 triângulos | 24 vértices, **12** com máscara 1 (4 do topo + 4 faces × 2 cantos de topo) e 12 com 0 |
| `coluna_de_agua_ondula_so_no_topo` | dois blocos empilhados no ar | 20 triângulos, 40 vértices, **12** mascarados — o bloco de baixo tem **0**, porque tem água em cima |
| `agua_nao_muda_a_malha` | o total de triângulos do mundo gerado e as 16 colunas de relevo não se movem com a perna | `triangulos` idêntico entre o mundo espelho e o da sessão, e igual ao da base antes da mudança (número impresso na corrida) |
| `orcamento_de_particulas` | o teto do FX é aritmética dos `amount` declarados, e nenhum disparo passa dele | a árvore de nós conta os emissores — `emissores=12` (`SPLASH_POOL` 8 + `BUBBLE_POOL` 4) e `anis=12` — e `soma=364` == `teto=364` (8×24 + 12 + 4×40, lido de `teto_particulas()`), com `vivas=41` ≤ teto e `picos=1` na janela |
| `queda_na_agua_dispara_salpico` | o **jogo** derruba o corpo na coluna (nada de campo escrito à mão — §"O que não fazer" do contrato) | `salpicos` ≥ 1 com o `vy` da entrada impresso, e o anel pousado no plano `y` que `water_surface_y` devolve |
| `corpo_seco_nao_dispara` (braço de indiferença) | o mesmo corpo andando em terra seca, mesma janela | `salpicos` == 0 **e** `in_water` false na janela inteira |
| `coluna_de_queda_funda` (premissa da janela de queda) | a coluna mais funda lida no mapa, não fixa em banco, tem mais blocos que `BUBBLE_MIN_BLOCKS` e plano > 0 | `coluna=(x,z) blocos=N plano=P` impresso — sem esta linha a checagem de salpico poderia estar caindo sobre rocha e dando verde pelo motivo errado |
| `fx_nao_escreve_o_mundo` | a janela com salpico não toca estado autoritativo | `world.edits` inalterado, `aether_energy` dentro da banda da corrida de referência, `Channel.COUNT` == 3 |

A suíte **não** pode afirmar "o shader compila", e é por isso que §5.2 existe. Escrever a asserção
de compilação em headless seria o furo que a casa já contou duas vezes: um verde que nenhum
instrumento mediu. **Emendado pela Fase 2, e a emenda é de alcance, não de sinal** (o parágrafo do §2
com o número das duas corridas está acima): o front-end GLSL roda em headless e imprime `SHADER ERROR`
quando o `ShaderMaterial` toma o `Shader`, então o stdout da **sonda** ganhou essa testemunha — mas
continua sem compradora dentro da suíte, porque nenhuma checagem sua pode depender de stderr do
`DisplayServer` dummy sem virar o verde pelo motivo errado. A assersão publicada é a da corrida
arquivada (`SHADER ERROR=0` na suíte do pin e na da sonda), não uma checagem.

### 5.2 sonda com janela (`.tools`, não entra como gate de fase)

Cena própria que instancia `src/main.tscn`, enquadra a coluna de água mais funda da seed, salva
quadros PNG em instantes diferentes e sai. Ela responde as duas perguntas que headless não responde:

- o shader **compila** (prova: `grep` de `SHADER ERROR` / `ERROR: ` no stdout da corrida, com o
  número de ocorrências impresso — não com "rodou sem erro visível");
- a água **muda de quadro** (prova: dois PNGs do mesmo enquadramento em dois instantes de `TIME`
  têm pixels diferentes; e a diferença média por canal é impressa). O `mascara`/`triangulos` da
  suíte garante a estrutura; isto garante o pixel.

**Medido nesta perna** (2026-11-24, dois braços na mesma máquina, mesma seed `20261116`, moldura
1920×1080 com a GPU real ligada — RX 9060 XT, Vulkan 1.4.359 Forward+ nos dois stdout). As dezessete
peças estão em [`docs/evidence/elevacao-visual-agua-23/`](../evidence/elevacao-visual-agua-23/), e o
[`readback.log`](../evidence/elevacao-visual-agua-23/readback.log) é o índice delas:

| | `SHADER ERROR` / `ERROR:` | caixa de 192 px com passo 2 → **9 216 amostras** | quadro inteiro (518 400) — testemunho, não régua |
|---|---|---|---|
| esta perna (`2903ea0`), `dt = 1 519 ms` | **0 / 0** | `ge1=8867  ge3=7807` → **`fracao_ge3 = 0,8471`**, média por canal r 0,032264 · g 0,031319 · b 0,026414 | `fracao_ge3 = 0,3999` |
| controle (`b0ed929`, sem a perna), `dt = 1 503 ms` | **0 / 0** no stdout; no stderr há 3 `ERROR: `, nenhum de shader — é o `af_mind.gdextension` que não existe no clone da base, e esta perna não toca `native/` | `ge1=0  ge3=0` → **`fracao_ge3 = 0,0000`**, média 0,000000 nos três canais | `fracao_ge3 = 0,0468` |

Quatro frases sustentam o número, e cada uma fecha uma rota para o verde errado:

- **o enquadramento é idêntico nos dois braços**, e é isso que autoriza comparar: `coluna=(100,52)
  blocos=12 topo=26 plano=27.00` (a coluna mais funda da seed), mirante `coluna=(101,39) chao=27
  dist=14 olho=(101.50, 29.62, 39.50) pitch=-0,198`, `centro_agua=(960.0,540.0) dentro=1`,
  `camera_deslocou=0,0000 m`, `lobos_na_caixa=0`. São os mesmos nove números impressos nas duas
  corridas;
- **nenhuma partícula credita a diferença**: a linha do próprio probe imprime, no braço desta perna,
  `fx_presente vivas_pool=0/0/0 salpicos_disparados=0 picos=0` — nenhum slot vivo na janela entre os
  dois quadros — e `fx=ausente` no controle. O que mudou de quadro foi a superfície, não o FX;
- **o chão do instrumento dentro da régua é zero exato**: `caixa-base-t1.png` e `caixa-base-t2.png`
  têm o mesmo SHA-256 (`ae3d7dc4199b997b52008ec316d4a5f7a6f738277af9792d6b54e2efe073a0b0`), então
  nenhum byte dos dois quadros do controle difere dentro da caixa. Os 7 807 pixels desta perna não
  têm outro candidato além do shader;
- **a régua é re-derivada sem Godot e sem GPU**: [`confere_caixa.py.txt`](../evidence/elevacao-visual-agua-23/confere_caixa.py.txt),
  rodado sobre os quatro recortes arquivados, devolve as duas linhas na ordem — `0,8471` e `0,0000`
  (`confere_caixa.log`). O número não mora só no log do motor.

Duas precisões que mentiriam se fossem puladas. O `0,0468` do controle **fora** da caixa é o corpo,
a matilha e o céu animando na base de igual modo — medir o quadro inteiro daria verde ao controle, e
é por isso que o corte mora na caixa. E a comparação é em float, não em byte: o float32 mais próximo
de `1/255` vale `0,0039215689` e a subtração de dois bytes vizinhos vale `0,0039215686`, então uma
diferença de exatamente um byte não passa no `>=`, e a mesma caixa em byte puro daria `ge1=9141
ge3=8402`. O `0,8471` publicado é o que o instrumento imprimiu — piso, não teto.

Nada da §5.2 é gate de fase: é sonda, e o mandato 4 continua aberto. O que fecha a perna é o número
headless — **264 checagens / 0 falhas / 57,6 s** com as nove linhas de água da tabela acima, arquivado
em `suite23-merged.log`.

### 5.3 headless da Fase 2 (mesma suíte, passos novos no `_steps`)

Os números da terceira coluna são **derivados à mão** das constantes nomeadas em §3.10 e do `bright` de
[voxel_world.gd:973](../../src/world/voxel_world.gd#L973), do mesmo modo que a tabela de §5.1 foi
derivada de `FACE_CORNERS` e do culling `LIQUID`; foram escritos assim para o vermelho nascer
conferível. A quarta coluna é o que a corrida imprimiu, na ponta de código `1a676fa` lida do clone
limpo do pin ([`pin-suite.log:385-414`](../evidence/elevacao-visual-chuva-23/pin-suite.log)), e **cinco
derivações erram** — as cinco em negrito na última coluna, cada uma com o motivo escrito ao lado do
número. O censo sai de **264** para **275** checagens.

| Checagem | O que exige | Número derivado antes da corrida | Número medido na corrida |
|---|---|---|---|
| `material_opaco_e_shader` | o surface opaco de um chunk real carrega `_mat_opaque`, ele é um `ShaderMaterial`, e **cada** nome gravado tem declaração na SOURCE | `shader=true` com o surface achado por identidade de material (nunca índice fixo), `declarados=6 gravados=6 sem_fonte=0`, e `gdshader_files=0` — o número que fecha a discussão do §3.1 (item c) | `shader=true  surface=0  declarados=5  gravados=5  sem_fonte=0  gdshader_em_src_tests=0  pilha=(8, 50, 8)` — **o 6 derivado contava o `METALLIC`, que é constante do shader, não uniforme**: seis é o número do nome que existe na SOURCE com `uniform`, cinco é o que o material grava |
| `opaco_preserva_rgb_da_face` | esta perna **não** mexeu na aritmética do `bright`: em todo vértice do grupo opaco R = G = B, e o único canal que passou a variar é o A | `verts=N  rgb_iguais=N  a_min=0.000  a_max=1.000` com `rgb_iguais == verts` — a asserção estrutural que autoriza o A como portador (b) | `verts=4284  rgb_iguais=4284  a_min=0.000  a_max=1.000  surface=0` — a igualdade é exata no palco inteiro, e `a_max=1.000` com `a_min=0.000` é o canal vivo nas duas pontas |
| `exposicao_de_ceu_por_coluna` | duas pedras empilhadas no ar: a de cima tem exposição 1, a de baixo `1 - 1/EXPOSURE_FALL`, e a `EXPOSURE_FALL` blocos do topo a exposição é 0 | `topo_a=1.000  abaixo_a=0.750  fundo_a=0.000` — `EXPOSURE_FALL = 4`, os mesmos três lidos de um `PackedColorArray` real, não de uma fórmula repetida no teste | `EXPOSURE_FALL=4.0  topo=1.000/1.000  abaixo=0.749/0.750  fundo=0.000/0.000  y_na_pilha=104  dispersos=0` — o 0,749 é o **byte** do `PackedColorArray` (191/255) arredondando o 0,750, não outra fórmula; `dispersos=0` diz que todo vértice da mesma `y` carrega o mesmo número |
| `exposicao_nao_e_varredura_por_face` | o topo de coluna é lido **uma vez por coluna por rebuild**, não por face nem por voxel (braço (b) rejeitado) | `chunks_lidos=64  col_lidas<=16384` como asserção estrutural, e `faces_opacas=F  faces_por_coluna=F/col` impresso — a razão real é o número publicado no §4 | `chunks_lidos=287  col_lidas=73472  esperado=73472  cols_por_chunk=256  faces_opacas=458260  faces_por_coluna=6.24` — **o 64 derivado era o censo de chunks do boot; a asserção estrutural verdadeira é `col_lidas == chunks_lidos × 256`**, e ela é exata nos 287 rebuilds da sessão, com o braço por face custando 6,24 leituras por coluna |
| `clima_e_dono_visual` | o `Weather` está na árvore do jogo, é dono de `chuva` e `molhado`, e não tem nenhuma propriedade tipada de mundo, Éter ou jogador | `no=true  chuva=float  molhado=float  world_refs=0  eter_refs=0  player_refs=0` (varredura de `get_property_list()`, o mesmo instrumento do `fx_sem_eter`) | `no=true  chuva=float=true  molhado=float=true  world_refs=0  eter_refs=0  player_refs=0` |
| `molhado_sobe_e_desce` | `pedir_chuva(1.0)` integra para cima e `pedir_chuva(0.0)` integra para baixo **mais devagar**, e o número chega ao material — não só ao nó | `molhado 0.000->1.000 em K frames  seco=0.855 esperado=1-WEATHER_DECAY*t=0.854  material=0.855` — sem a última igualdade o sink do §3.10a poderia estar desligado e o nó sozinho daria verde | `molhado 0.000->1.000 em 150 frames  desceu=0.855 em 60 frames  esperado=0.855  material=0.855  rise=0.600  decay=0.145  secs=1.000` — **o 0,854 derivado é conta minha errada: 1 − 0,145 × 1 = 0,855**; `material=0.855` é o uniforme lido de volta do `ShaderMaterial`, não o número do nó |
| `chuva_nao_consome_rng_da_sessao` | a chuva sorteia coluna na RNG **dela**, e a RNG global da sessão não anda um passo na janela | `pino_antes=X  pino_depois=X  global_preservado=true`, o instrumento da perna 10/12 copiado para dentro da suíte | `pino_antes=2762692978  pino_depois=2762692978  global_preservado=true  colunas_iguais=true  n=8  script=true  rng_do_clima=true  rng_da_populacao=true` |
| `anel_de_chuva_so_na_agua` | o anel da gota pousa no plano que `world.water_surface_y()` devolve para **aquela** coluna, e coluna sem água recusa com contador em vez de pôr anel em `y = 0` | `anis_chuva=N>0  recusados=R  plano_fx=%.3f  plano_mundo=%.3f  vivo_chuva=C  vivo_corpo=K  C+K<=12` — a última desigualdade é a cota do §3.10d, lida com os dois compradores na janela | `anis_chuva=9->15  recusados=63->105  col_ultima=(80, 73)  na_agua=true  plano_fx=26.880  plano_mundo=26.880  vivo_chuva=4  vivo_corpo=0  pool=12  no_zero=0` — os dois planos iguais na terceira decimal e o `no_zero=0` são a recusa contada, não o anel em `y = 0` |
| `agua_le_a_chuva` | **degrau 5, não do gate**: o número que a superfície da água desenha é o número que o clima pediu, e o par de uniformes da Fase 1 aparece re-derivado na corrida | `chuva_no=1.000  uniforme_agua=1.000  declarados=17  gravados=15` — os dois tamanhos são o §3.10e prometendo que `16/14 → 17/15` sai impresso, e `declarados == gravados + 2` é a asserção estrutural do par | `chuva_no=1.000  uniforme_agua=1.000  declarados=17  gravados=15`. O vermelho que a antecedeu está arquivado (`chuva23-codigo-c-vermelho.log`: `uniforme_agua=-99.000  declarados=16  gravados=14`) — o `-99,000` é o "não há uniforme", e os dois números velhos provam que o `chuva` ainda não existia |
| `orcamento_de_particulas_da_chuva` | o teto do `RainFx` é aritmética dos `amount` criados no boot, contados na árvore, e **taxa × vida não passa do amount** de cada emissor | `emissores=2  soma=900  teto=900  near=520*0.9=468<=600  far=200*1.4=280<=300` — headless não tem contagem viva de partícula, e é por isso que a asserção é a aritmética e o vivo é da §5.4 | `emissores=2  soma=748  teto=748  near=520*0.9=468<=468  far=200*1.4=280<=280  fiel_near=true  fiel_far=true` — **o 900 e os tetos 600/300 não existem no §3.10d: o teto de cada emissor é o `amount` dele próprio**, 468 e 280, e a soma é 748 (a mesma aritmética que o braço rejeitado do §3.10d já citava) |
| `chuva_nao_escreve_o_mundo` | a cláusula `fx_nao_escreve_o_mundo` do §5.1 estendida à janela molhada inteira, com o `Weather` e o `RainFx` sob a mesma varredura | `assinatura_ok=true  edits_globais=E->E  eter_chuva<=4*eter_seco  canais=3  fx_sem_eter=true  rain_sem_eter=true  weather_sem_eter=true` | `assinatura_ok=true  edits_na_janela=1  banda_val=false  edits_globais=16->17  eter_seco=0.000000  eter_chuva=0.369156  canais=3  fx_sem_eter=true  rain_sem_eter=true  weather_sem_eter=true` — **a banda `eter_chuva<=4*eter_seco` não é avaliável com `eter_seco=0` e a janela de 90 quadros apanha o lobo cavando (perna 12)**, que escreve WORK no campo: a banda vale só na janela em que nada foi editado, e a renúncia sai impressa por nome (`banda_val=false`), não silenciada |

Duas linhas **não são novas** e continuam mordendo a Fase 2 pelo lado de fora: `agua_nao_muda_a_malha`
com `triangulos=214448` (a exposição é canal, não geometria — §3.2), que na corrida do pin devolve
`base=214448  espelho=214448  sessao=214448`, e `material_da_agua_e_shader`, que deixa de ser
`declarados=16 gravados=14` para `declarados=17 gravados=15` com o uniforme `chuva` do §3.10e — medido
`shader=true  surface=1  declarados=17  gravados=15  sem_fonte=0`. As duas somas aparecem na linha
impressa justamente para o re-derivar ser visível em vez de silencioso. O censo da suíte cresce com as
onze linhas acima, e em dois degraus: **264 → 274** com as dez do gate (degrau 2) e **274 → 275**
quando entra a `agua_le_a_chuva` do degrau 5. O valor publicado é o da corrida.

### 5.4 sonda com janela da Fase 2 (`.tools`, também não é gate de fase)

A sonda da Fase 1 (§5.2) respondia duas perguntas. A da Fase 2 responde três, e a segunda é a que
autoriza a primeira a existir:

- **o que compila**: `grep` de `SHADER ERROR` / `ERROR:` no stdout, agora com **dois** shaders
  spatial próprios no processo (`opaque_surface.gd` e `water_surface.gd`) mais o do anel, com a
  contagem por shader impressa;
- **o material opaco novo desenha o que o `StandardMaterial3D` desenhava**: dois braços, o da **base**
  (sem esta perna) e o desta perna com `--weather=0`, no **mesmo enquadramento**, mesma seed, mesma
  moldura. A régua é a diferença média por canal e a fração de pixels ≥ 3 dentro de uma caixa sobre o
  relevo. É o braço de **indiferença** do ciclo de trabalho item 3: se o par fiel não couber numa
  banda pequena, o shader está errado e o braço (c) do §3.10b volta à mesa com o número, **não** a
  banda;
- **o molhado aparece**: um terceiro braço, desta perna com `--weather=1`, mesma câmera, e a diferença
  medida **em duas caixas separadas** — o topo exposto da coluna e o fundo abrigado. A assinatura do
  efeito é `topo muda >> abrigo muda`; se as duas caixas mudarem igual, a exposição não está sendo
  lida pelo material e o `a_max=1.000` da §5.3 descrevia um canal que ninguém usa. O valor aceito sai
  da corrida, e o §5.4 publica a banda com o log arquivado.

Nenhum braço usa tecla sintética: a chuva entra por `--weather=<alvo>`, que é o mesmo caminho que o
`Rodar.bat` vai expor, e o enquadramento é o do §5.2 (coluna de água mais funda da seed) com uma caixa
adicional sobre o morro visível dele.

**Medido na ponta `1a676fa`, com 83 peças arquivadas** em
[`docs/evidence/elevacao-visual-chuva-23/`](../evidence/elevacao-visual-chuva-23/) e o
[`readback.log`](../evidence/elevacao-visual-chuva-23/readback.log) como índice delas. As três
perguntas, na ordem:

- **compila**: `SHADER ERROR` **0** em todos os stdout arquivados — três da base
  (`base-sonda-23f2-{A,A2,A3}`), os seis braços desta perna com os **dois** shaders spatial próprios
  mais o do anel no mesmo processo (`sonda-23f2-{B3,B5,B5fps,B6,B7,C6}`), e a cena sintética de dez
  variantes (`rocha_fiel_tile.log`). A testemunha de que o contador **vê** o erro quando ele existe é
  o par do furo **#50**: `chuva23-codigo-a.log` e `chuva23-codigo-c-sombra-4-erros.log` dão **4** cada
  (um por mundo construído) e `chuva23-rendermode-conserto.log` devolve **0** depois da troca. A
  emenda do §2 vale aqui: o que a janela continua sendo a única testemunha é o **pixel**.
- **indiferença**: o par fiel **não** coube na banda, e o §5.4 diz o que fazer nesse caso — o braço
  (c) do §3.10b volta à mesa **com o número**. O número foi levado e a mesa decidiu contra o (c), com
  atribuição em dois instrumentos: `A2`-vs-`B6` (base `eb218fe` contra esta perna com `--weather=0`,
  mesmo enquadramento caractere por caractere, `camera_deslocou=0,0000 m`) dá
  `topo ge1=9216 ge3=9034 fracao_ge3=0,9803` e `abrigo ge1=3124 ge3=2899 fracao_ge3=0,9244` contra um
  **piso do instrumento de zero exato** (`B6`-vs-`B7`, duas corridas do mesmo código com
  `--fixed-fps=60`, dão `ge1=0 ge3=0` nas duas caixas de relevo). A causa não é o `COLOR` nem o
  `SPECULAR`: é a **segunda decodificação** que o `StandardMaterial3D` fazia de um atlas que já chega
  linear ([`voxel_atlas.gd:35`](../../src/world/voxel_atlas.gd#L35), tile `TILE_GRASS_TOP` guardando
  `(0.0941, 0.2667, 0.0549)` contra a base escrita `Color(0.34, 0.55, 0.26)` em
  [`:58`](../../src/world/voxel_atlas.gd#L58), `FORMAT_RGBA8` — o 4.7 não tem formato sRGB em runtime).
  Medido na cena sintética (`rocha_fiel_tile.log`, dez variantes de **um** token cada): devolver o
  decode à **amostra** leva a média a `−0,24/255` do material velho (`sh_tile_s2l`, `fracao_ge3`
  `1,0000` → `0,3524`), devolver o decode ao **vértice** deixa a média a `+33/255` (`sh_s2l`) — o
  termo é a amostra, não o `COLOR`. Na cena real, a mesma ablação de uma linha no `fragment()` fecha o
  par em `A2`-vs-`B5 topo ge1=0 ge3=0 fracao_ge3=0,0000` e `abrigo ge1=28 ge3=21 fracao_ge3=0,0067`.
  **Decisão publicada: o shader fica como está — sem `source_color`, §3.10c de propósito — e o
  desvio de +5/255 em R e +5/255 em G no relevo exposto é a diferença entre um material que decodifica
  uma vez e o resto do mundo que decodifica duas.** Isso abre o **furo #48**: `_mat_glass`
  ([`voxel_world.gd:158-164`](../../src/world/voxel_world.gd#L158-L164)) continua
  `StandardMaterial3D` com `albedo_texture = _atlas` e, portanto, continua com o decode duplo; vidro e
  pedra vizinhos estão hoje a um decode de distância, e o número que paga isso é uma caixa sobre uma
  parede de vidro ao lado de uma de pedra no mesmo quadro — consequência **derivada do código, ainda
  não medida em pixel**, e por isso fica escrita como débito e não como feito. O braço (c) do §3.10b
  (molhamento global, sem canal por vértice) não volta, porque é exatamente o teste que ele não passa
  na pergunta 3.
- **o molhado aparece**: `B6`-vs-`C6` (mesma câmera, `--weather=0` contra `--weather=1`) dá
  `topo ge1=9202 ge3=1192 fracao_ge3=0,1293` (média r 0,005351 · g 0,006975 · b 0,011968 — o azul é o
  maior dos três, como o `wet_tint` e a lâmina d'água mandam) contra
  `abrigo ge1=0 ge3=0 fracao_ge3=0,0000` **com zero exato**: os 3 136 pixels da caixa abrigada não
  mudaram um byte quando o `molhado` passou de 0 a 1, e o motivo é o `a=[0.000..0.000]` lido do
  próprio vértice naquela caixa. A assinatura `topo muda >> abrigo muda` saiu como o §5.4 pediu, e é
  ela que fecha o braço (c) pelo pixel: um filtro global escureceria as duas caixas por igual. A caixa
  d'água **não** é régua deste braço — `B6`-vs-`C6 agua fracao_ge3=0,7925` contra um piso de `0,7538`
  medido dentro do **mesmo** braço —, então o que decide a reação da água à chuva é o
  `uniforme_chuva=1,000` lido de volta mais a checagem headless `agua_le_a_chuva`, não o pixel.

Como as duas caixas de relevo foram escolhidas está no mesmo log, com os **quatro** motivos de recusa
contados por nome (`parede=0 submerso=7283 estreitas=0 impuras=0`), porque três premissas falsas foram
medidas antes de a régua fechar: uma face de muro no fundo da imagem não é abrigo, o `ray_voxel` para
no primeiro **sólido** e água não é sólida (os 7 283), e a caixa anterior de 16×16 px dava
`fracao_ge3=0,0117` no abrigo molhado em vez de zero — quase verde, e verde pelo motivo errado.

Nenhum braço desta seção é gate de fase: §5.4 é sonda. O gate de fase continua aberto (mandato 4).

## 6. O que NÃO fazer

- Não escrever no mundo nem no Éter a partir do FX (§3.8), nem tocar `Channel.COUNT`,
  `FORMAT_VERSION`, `GEN_VERSION` ou a projeção do `TickJournal`.
- Não subdividir a malha da água (§3.2) nem mover `triangle_count()` — a checagem do espelho existe
  para isso.
- Não criar partícula por frame (§3.6); pool fixo, com teto lido.
- Não afirmar em documento nada que headless não mede: compilação e pixel são da §5.2, e o documento
  cita qual corrida sustenta qual número.
- Não adiantar Fase 3→5 (§3.9): vento, `Environment` versionado e atlas novo esperam o gate um do
  outro, na ordem. A Fase 2 tinha essa mesma frase e saiu dela com gate próprio (§5.3, §5.4) — o que
  vale para a próxima é o que valeu para ela.

## 7. Ordem, e a exceção registrada antes do código

A fila serializada estava **22 → 17 → 18 → 20 → 13** (registro do dono em 2026-11-23, movida por ele
em 2026-11-23). A 23 entra **na frente de todas** porque o dono pediu esta perna agora e mandou aplicar:
a fila passa a **23 → 22 → 17 → 18 → 20 → 13**. A 22 **continua onde está** — está em voo, e não é só
branch: `feat/oraculo-nativo-passo2b-22` tem trabalho **não commitado** em `native/af_mind/` na árvore
primária. É por isso que esta perna abre **num `git worktree` separado** (`.qoder/worktrees/
elevacao-visual-23`) da `main` em `b0ed929`: a alternativa seria trocar de branch na árvore onde o
processo da 22 está escrevendo, e "um escritor por arquivo por branch" (item 6 de "Branches") não é
cerimônia — o incidente do dossiê 03 apagou uma versão já conferida.

- **Furo com dono escrito antes da linha:** **#43** — o `COLOR` dos vértices de água é escrito com o
  `FACE_TINT` da face e lido por ninguém (§2). Esta perna é quem o fecha, pela mesma mudança que precisa
  do canal: o material passa a ler o `COLOR`, e a asserção de que ele é lido é a `material_da_agua_e_shader`
  (§5.1), não uma frase.
- **Arquivos que a 23 escreve:** `src/world/voxel_world.gd` (material, máscara na face, consulta da
  coluna), `src/world/water_surface.gd` **novo**, `src/rendering/water_fx.gd` **novo**,
  `src/main.gd` (instantiate o nó e a linha de diagnóstico), `tests/smoke_test.gd` (os passos novos)
  e os documentos.
- **Choque real:** `src/main.gd` é de escritor único e a 22 também o toca (o hospedeiro do modelo,
  `attach_llm_host` / `_wire_llm_host` em
  [main.gd:287-322](../../src/main.gd#L287-L322)); `src/world/voxel_world.gd` e `block_defs.gd` são os
  terrenos da 17 e da 18. Esta perna **não** toca `block_defs.gd` nem `src/ai/` nem `native/`.
- **Consequência aceita e escrita agora** (item 5 de "Branches"): quem pousar depois re-rome o gate
  na árvore resultante. A 23 muda `triangle_count()`? **Não** — e é checagem (§5.1), justamente para
  que o re-rome de 17/18 não encontre o número de malha deles deslocado por causa alheia. O que muda
  é o **material** e o censo da suíte (novas checagens somam no rodapé), e o censo é re-derivado nos
  documentos por esta perna.
- **Nenhum gate de fase se fecha aqui.** A fila P0/P1 (budget HOT, censo multi-semente, bake-off de
  AF) continua aberta, exatamente como em todas as pernas anteriores.

### 7.1 A Fase 2 abre depois do pouso da Fase 1, e a exceção é esta

A Fase 1 pousou na `main` em `05e8917` e a fila voltou a ser **22 → 17 → 18 → 20 → 13**. A Fase 2 é
**a mesma perna**, autorizada pelo dono como pauta dentro dela (registro de 2026-11-24), então **nenhuma
posição de fila muda** — o que muda é o ponto de abertura e o choque, e os dois precisam estar escritos
antes da primeira linha de `src/` (mandato 4):

- **Abertura:** branch `feat/elevacao-visual-chuva-23f2`, worktree
  `.qoder/worktrees/elevacao-chuva-23f2`, base `main` em **`eb218fe`** (o pouso do Passo 4 da 22, que
  andou desde o `05e8917` da Fase 1). Worktree e não árvore primária pelo mesmo motivo da Fase 1, agora
  com nome: a árvore primária está em `feat/oraculo-nativo-passo5-22`, escrevendo `src/main.gd` neste
  momento (as métricas de fila/decode/cache da linha F3 e do `diagnostics()`).
- **Choque real e medido, não previsto:** `src/main.gd` é de escritor único e a 22 **já** o escreveu
  depois da base da Fase 1 — `diagnostics()` ([main.gd:1230-1273](../../src/main.gd#L1230-L1273)) é o
  mesmo bloco onde esta fase acrescenta a linha do `weather`/`rain_fx`. Esta Fase 2 escreve ali
  **quatro coisas**: o nó do `Weather`, o nó do `RainFx`, o `apply_sink` para o mundo e a linha de
  diagnóstico — nenhuma delas toca host de modelo, ponte ou journal. O merge resolve por posição (linhas
  vizinhas, blocos diferentes) e **re-rome o gate** na árvore resultante, como exige o item 5 de
  "Branches".
- **Furo com dono escrito antes da linha:** **#47** — a sonda com janela da Fase 2 (`§5.4`) produz
  recortes PNG dentro do projeto, e é exatamente assim que o **furo #45** nasceu: a Fase 1 commitou os
  quatro `caixa-*.png` de `docs/evidence/` sem os `.png.import`, e todo clone limpo imprime linhas `??`.
  A régua do #45 foi relida nesta árvore e o escopo dele é **menor** do que a pauta do pouso da 22 fazia
  crer: dos **29** PNGs e **1** SVG rastreados, **quatro** arquivos estão sem sidecar, e os quatro estão
  em `docs/evidence/elevacao-visual-agua-23/` — `docs/evidence/fp-hand` tem **14** `.import` versionados,
  `docs/media` tem **11**, `assets/` **51** e o `icon.svg` da raiz tem o dele. Esta fase **não repete o
  passo**: a pasta nova de evidência leva um `.gdignore` — mecanismo que **já tem número nesta casa**,
  porque o `build.bat` da perna 22 escreve `bin/.gdignore` e o `--import` que antes devolvia 464 B de
  stderr passou a devolver **exit 0 com 0 bytes**
  ([`docs/melhorias-status.md:6801-6804`](../melhorias-status.md#L6801-L6804)) — e é o conserto local do
  #45 demonstrado em uma pasta, e **não** fecha o #45 — os quatro `caixa-*.png` continuam gerando sidecar
  em todo clone, e a arrumação neles continua sendo do dono do repositório, não desta perna.
- **Arquivos que a Fase 2 escreve:** `src/rendering/weather.gd` **novo**, `src/rendering/rain_fx.gd`
  **novo**, `src/world/opaque_surface.gd` **novo**, `src/world/voxel_world.gd` (material opaco, canal
  de exposição, cache de coluna, o acesso `opaque_material()`), `src/rendering/water_fx.gd` (a porta `ring_at` e os
  contadores de origem), `src/world/water_surface.gd` (o uniforme `chuva`), `src/main.gd` (**60**
  linhas, medidas no `git diff --numstat` da ponta), `tests/smoke_test.gd` (os passos novos), `.tools/`
  (gitignored, a sonda) e os
  documentos.
  Nada de `src/ai/`, `native/`, `src/entities/`, `block_defs.gd` ou `src/audio/`.
- **Consequência de versão, declarada agora:** `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a
  projeção do `TickJournal` não são tocados, e a expectativa desta fase é **reproduzir** os hashes das
  rodadas publicadas: nem o `intent`, nem as crenças, nem as edições nem os canais mudam com o clima
  visual, e o canal de exposição mora no `COLOR` da malharia, que não entra na projeção. Se
  o hash se mover, isso é defeito desta perna e a checagem `fx_nao_escreve_o_mundo` estendida (a
  assinatura por coluna) é quem pega; o journal pareado fica como conferência extra do commit final.

## 8. Commits atômicos previstos

Um assunto por commit, suíte verde entre eles, número no commit a que responde (mandato 6):

1. **`docs/`** esta página + a extensão no `AGENTS.md` + a linha no índice `docs/planos/README.md`
   — escrita antes do código.
2. **`feat/`** `water_surface.gd` + `_mat_water` no mesher + máscara nos vértices; gate das
   checagens de material/máscara/malha.
3. **`feat/`** `water_fx.gd` (pool, transição, anéis, bolhas) + fiação no `main.gd` + a linha de
   diagnóstico; gate das checagens de orçamento/transição/não-escrita.
4. **`test/`** a sonda com janela e a corrida A/B do mesmo enquadramento.
5. **`docs/`** re-derivação: status (feito / falta / débitos / furos / notas), censo novo em todo
   lugar que o citava, e as três réguas.

**A mesma escada para a Fase 2** (cada degrau com a corrida que lhe responde, e o gate nascendo
vermelho antes do código que o fecha — o padrão das pernas 22 e 23 nesta casa):

1. **`docs/`** §3.10, §4, §5.3, §5.4, §6, §7.1 — escrita antes de qualquer linha de `src/` (mandato 4).
2. **`test/`** as **onze** checagens de §5.3 no `_steps` — o plano escrevia dez e a entrega tem
   onze, com o nome de cada uma na lista do próprio §5.3 —, **vermelhas**, com a assinatura de cada ausência
   impressa (sem material opaco de shader, sem canal de exposição, sem `Weather`, sem `RainFx`) e o
   censo novo já contando nelas.
3. **`feat/`** `opaque_surface.gd` + `_mat_opaque` no mesher + canal de exposição + cache de coluna +
   `weather.gd` com `pedir_chuva()` e o sink `apply_sink()`, e o `--weather=` no `main.gd`; fecha
   material, canal, coluna, custo de
   varredura, dono visual e rampa.
4. **`feat/`** `rain_fx.gd` + `ring_at` no `WaterFx` com origem e recusa + fiação no `main.gd`; fecha
   anel-na-água, orçamento, RNG da sessão e não-escrita.
5. **`feat/`** o uniforme `chuva` no `WaterSurface` e a re-derivação do par `16/14 → 17/15` na suíte.
6. **`test/`** a sonda §5.4 com os três braços no mesmo enquadramento, `.gdignore` na pasta nova e a
   evidência arquivada.
7. **`docs/`** re-derivação final: censo, números medidos nos lugares que publicavam os antigos,
   status, clone limpo com o pin e as três réguas.

**A escada cumprida, com o commit de cada degrau** (a ponta medida é `78742d6`; o pin — clone limpo com
`--import` frio — está na rodada "Rodada 2026-11-25 (2)" de
[`docs/melhorias-status.md`](../melhorias-status.md), com os quatro runners e as dez corridas da suíte
arquivadas em [`docs/evidence/elevacao-visual-chuva-23/`](../evidence/elevacao-visual-chuva-23/)):

| Degrau | Commit | O que a corrida dele imprimiu |
|---|---|---|
| 1 (docs) | `91fe5fc` | nenhuma — é documento antes do código (mandato 4) |
| 2 (test) | `2112be1` | `274 checagens 12 falhas 61,7 s`, as dez assinaturas de ausência + os dois do **furo #38**; controle da base `264/2` e o braço de 300 quadros `264/3` |
| 3 (feat) | `7750ea1` | `274 / 5 / 61,5 s`, com **4** `SHADER ERROR` e `mesh_ms` 4 711 → 4 907 |
| 3′ (correction) | `0bce05d` | `274 / 5 / 62,7 s` com **0** `SHADER ERROR` — o `specular_schlick_blurry` era de Godot 3; o **furo #50** nasce aqui |
| 4 (feat) | `7db4d0b` | `274 / 2 / 62,1 s` — só sobram os dois da 22 |
| 5 (test→feat) | `734e34c` → `1a676fa` | o vermelho nomeado `uniforme_agua=-99.000 declarados=16 gravados=14` e o verde `275 / 2 / 62,0 s` com `17/15` |
| 6 (test) | `c56c01f` | as três perguntas do §5.4 com nove stdout arquivados, `SHADER ERROR` **0**, `topo 0,9803 → 0,0000` na ablação e `abrigo 0,0000` no braço molhado |
| 6′ (rótulo) | `78742d6` | nenhum byte de código: #46→#50, #47→#49, e o **segundo pin** provando o mesmo veredito (`275/2`, `292/7`, `27/0`, `128/0`) |
| 7 (docs) | este commit | o censo novo em todo lugar que publicava o velho, as cinco derivações derrubadas com o motivo, os três pins e as três réguas |

