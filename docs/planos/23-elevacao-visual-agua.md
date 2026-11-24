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

A autorização do dono cobre **a Fase 1 como código** (água) e **as Fases 2→5 como pauta dentro da
mesma perna**, cada uma com gate próprio e nenhuma linha escrita antes de a anterior fechar o dela
— a mesma regra que a perna 22 recebeu no prompt de cinco fases dela
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
([voxel_world.gd:97](../../src/world/voxel_world.gd#L97)); `StandardMaterial3D` sobrou só para o
opaco ([:91-96](../../src/world/voxel_world.gd#L91-L96)) e para o vidro
([:101-107](../../src/world/voxel_world.gd#L101-L107)), e `voxel_atlas.gd` não foi tocado.

**Quem desenha a água é o mesmo culling dos demais blocos, e ele só cede face contra AR.** Na
malharia, `Draw.LIQUID` descarta a face quando o vizinho **não é** `AIR`
([voxel_world.gd:551-553](../../src/world/voxel_world.gd#L551-L553)); o vizinho sólido **do outro
lado** desenha a face contra a água, porque a água não é opaca
(`is_opaque` 0 — [block_defs.gd:100](../../src/world/block_defs.gd#L100), teste em
[voxel_world.gd:559](../../src/world/voxel_world.gd#L559)). Consequência que o plano aproveita: a
geometria de água visível é **a superfície mais as faces laterais expostas ao ar** — o leito já é
desenhado pelo material opaco, então refração tem o que refratar. O topo afunda
`WATER_TOP_DROP = 0,12` ([`:34`](../../src/world/voxel_world.gd#L34), aplicado na chamada da água em
[`:567-569`](../../src/world/voxel_world.gd#L567-L569) e no vértice de topo dentro de
[`_emit_face:670-671`](../../src/world/voxel_world.gd#L670-L671)).

**Cada face é um quad de quatro vértices próprios, e o `COLOR` do surface de água estava livre.**
`_emit_face` acrescenta 4 vértices por face ([`:667-689`](../../src/world/voxel_world.gd#L667-L689))
e o vertex color da água **não era lido por ninguém**: `_mat_water` não ligava
`vertex_color_use_as_albedo` (o ligador era só o do opaco `b0ed929:src/world/voxel_world.gd:88` e o do
vidro, hoje [`:104`](../../src/world/voxel_world.gd#L104)), e a água entrava com o `ao` forçado em
`[1,1,1,1]` ([`:568`](../../src/world/voxel_world.gd#L568) na chamada de hoje,
`b0ed929:529-530` na leitura de abertura). É o canal que a malharia já escrevia e o jogo já
descartava — §3.3. E é um achado, não uma conveniência: a face escreve
`bright = clampf(tint * ao[k], 0.05, 1.2)` com o `tint` sendo o `FACE_TINT[f]` da face
([`:677`](../../src/world/voxel_world.gd#L677); `b0ed929:627-628` onde esta leitura o achou) — as
laterais 0,88/0,82 e o fundo 0,60 — e na árvore de abertura ninguém lia o resultado, então a água era
desenhada com a **mesma** cor em topo, lado e fundo, e o
trabalho de calcular a sombra de face ia embora. Isso é o **furo #43**, dono esta perna, e o conserto é
exatamente o canal virar lido: hoje o `COLOR` dos quatro cantos da face de água é a máscara que o
shader lê ([`:678-687`](../../src/world/voxel_world.gd#L678-L687)).

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
pela caixa ([voxel_world.gd:375-384](../../src/world/voxel_world.gd#L375-L384)). O jogador lê o campo
para nadar e para a respiração ([player.gd:486](../../src/entities/player.gd#L486),
[:537](../../src/entities/player.gd#L537), [:593](../../src/entities/player.gd#L593)) e o lobo para
empuxo, velocidade e o cronômetro de nado ([wolf.gd:1211-1212](../../src/entities/wolf.gd#L1211-L1212),
[:1230](../../src/entities/wolf.gd#L1230), [:1265](../../src/entities/wolf.gd#L1265)).

**Já existe o padrão de quem reage à transição sem escrever no mundo.** O diretor de áudio guarda
um estado por corpo e age na **borda** da mudança: `if in_water != bool(st["in_water"])`
([audio_director.gd:439-441](../../src/audio/audio_director.gd#L439-L441)), alimentado por leitura do
`body` do jogador ([`:462`](../../src/audio/audio_director.gd#L462)) e de cada lobo
([`:503`](../../src/audio/audio_director.gd#L503)), com a lista entregue por
`wolves_provider` ([`main.gd:200`](../../src/main.gd#L200)). É a mesma fiação, sem sinal novo, que o
FX de água usa (§3.7). O áudio é o **primeiro** consumidor dessa leitura; este é o segundo — e é por
isso que a regra da casa (generalizar no segundo chamador, não no primeiro) permite a peça nova sem
pedir um mecanismo novo.

**A cena tem um sol parado e uma neblina de duas linhas.** `_build_environment` monta
`DirectionalLight3D` com `rotation_degrees = (-42, 55, 0)`, `light_energy = 1,60`, sombra a 80 m,
`ProceduralSkyMaterial`, `ambient_light_energy = 0,85`, `TONE_MAPPER_FILMIC`, `fog_enabled` com
`fog_light_color = (0,55, 0,65, 0,78)` e `fog_density = 0,006`
([main.gd:1215-1251](../../src/main.gd#L1215-L1251)). Não há ciclo de dia/noite, então "caústicas
quando o sol está alto" (§ Fase 1) é hoje uma **constante**, não uma variável: a elevação do sol é
fixa em ~48°. Registrar isso é o que impõe §3.9. **O que a perna mudou aqui:** a direção parada
deixou de ser invisível ao material — `world.set_water_sun_direction(_sun_dir)` no boot
([`main.gd:139`](../../src/main.gd#L139)) grava o vetor no uniform `sun_dir`
([`voxel_world.gd:124-126`](../../src/world/voxel_world.gd#L124-L126)), e o shader decide o ganho de
caústica por ele ([`water_surface.gd:184`](../../src/world/water_surface.gd#L184)). O que continua
parado é o sol, não o canal — e é isso que deixa a Fase 2 como pauta.

**Headless não exercita o renderer, e isso é premissa do gate, não detalhe.** A suíte roda com
`DisplayServer.get_name()` impresso em [smoke_test.gd:249](../../tests/smoke_test.gd#L249) e nenhuma
checagem sua depende de pixel. Um `Shader` quebrado **não** faz a suíte vermelha: a compilação é do
`RenderingDevice`, que em headless não existe. §5 separa as duas provas por causa disso, e o mandato
1 não permite publicar "shader ok" com o número de uma corrida que não compila nada.

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
([smoke_test.gd:397-405](../../tests/smoke_test.gd#L397-L405), a checagem `malha identica entre mundos`).

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
`_surface_arrays` ([voxel_world.gd:640-650](../../src/world/voxel_world.gd#L640-L650)) para os três
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
[voxel_world.gd:463-469](../../src/world/voxel_world.gd#L463-L469)).

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

- **Fase 2 — chuva e superfícies molhadas.** Exige o que ainda não existe: um **clima**. Não há
  variável de clima no projeto (o sol é constante §2) nem uniformes de molhamento no material
  opaco, que é um `StandardMaterial3D` único por mundo ([voxel_world.gd:91-96](../../src/world/voxel_world.gd#L91-L96)).
  O corte da fase é esse: `Weather` como dono de um estado lido pelo FX **e** pelo material — e é o
  primeiro comprador de um `shader` também para o opaco, o que reabre a discussão do §3.1 com número
  na mesa. A água já tem, desta perna, o gancho honesto: o mesmo plano de superfície que decide a
  espuma decide onde uma gota cria anel.
- **Fase 3 — vegetação viva.** Vento em folhas/grama é deslocamento de vértice com a mesma forma do
  §3.2, e aqui a malharia **não** distingue a face: grama e folha entram no mesmo surface opaco, com
  um `ao` real ([`:574-577`](../../src/world/voxel_world.gd#L574-L577)) — então o que a fase precisa
  decidir primeiro é **qual canal do `COLOR` opaco** fica livre, e isso é conversa com o face-culling
  que a suíte trava hoje.
- **Fase 4 — atmosfera.** `fog_enabled` e `fog_density = 0,006` existem com **uma** curva
  ([main.gd:1242-1246](../../src/main.gd#L1242-L1246)); height fog é outra função e precisa do
  `Environment` em recurso versionado, não em código — hoje a neblina é escrita à mão dentro de
  `_build_environment`. God rays em `forward_plus` é volumetria do engine, e ninguém mediu o custo
  dela nesta máquina: a fase **começa pela colheita**, como manda o mandato 5.
- **Fase 5 — materiais dos blocos.** Normal/roughness por bloco exige mapa de normais no atlas ou
  material por id; o atlas é 8×8 de 16 px gerado com `seed` fixa
  ([voxel_atlas.gd:5-14](../../src/world/voxel_atlas.gd#L5-L14)) e **um** `StandardMaterial3D` serve
  os 23 ids. O corte é: variação por material único (canal já existe — o `COLOR` opaco com jitter
  `0,012` em [`:575`](../../src/world/voxel_world.gd#L575)) antes de qualquer atlas novo.

## 4. Custo — as quatro perguntas

1. **Roda por frame, por tick ou às vezes?** O shader roda por **pixel desenhado de água**, no passe
   transparente — é o único item novo de GPU. O FX consulta os corpos por **frame de física**
   (`_physics_process`), com o mesmo custo de leitura do `box_in_water` que o corpo já faz — ele não
   adiciona varredura de mundo: lê `body.in_water` que já foi calculado. A colocação de anel e o
   disparo de salpico são **por evento** (transição), e a busca do plano de topo percorre **uma
   coluna**: `water_surface_y` ([voxel_world.gd:477-483](../../src/world/voxel_world.gd#L477-L483))
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
   [main.gd:136-143](../../src/main.gd#L136-L143)) — custo de boot, não de tick.
4. **Como sei que ficou melhor?** Dois instrumentos, cada um respondendo o que pode: as checagens
   novas da suíte (headless: material, máscara, triângulos, orçamento, transição, não-escrita) e a
   **sonda com janela** (§5.2), que é a única que compila o shader e salva PNG do quadro. Headless
   não prova pixel, e a página não finge que prova.

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
instrumento mediu.

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

## 6. O que NÃO fazer

- Não escrever no mundo nem no Éter a partir do FX (§3.8), nem tocar `Channel.COUNT`,
  `FORMAT_VERSION`, `GEN_VERSION` ou a projeção do `TickJournal`.
- Não subdividir a malha da água (§3.2) nem mover `triangle_count()` — a checagem do espelho existe
  para isso.
- Não criar partícula por frame (§3.6); pool fixo, com teto lido.
- Não afirmar em documento nada que headless não mede: compilação e pixel são da §5.2, e o documento
  cita qual corrida sustenta qual número.
- Não adiantar Fase 2→5 (§3.9): clima, vento, `Environment` versionado e atlas novo esperam o gate
  um do outro, na ordem.

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
  [main.gd:227-260](../../src/main.gd#L227-L260)); `src/world/voxel_world.gd` e `block_defs.gd` são os
  terrenos da 17 e da 18. Esta perna **não** toca `block_defs.gd` nem `src/ai/` nem `native/`.
- **Consequência aceita e escrita agora** (item 5 de "Branches"): quem pousar depois re-rome o gate
  na árvore resultante. A 23 muda `triangle_count()`? **Não** — e é checagem (§5.1), justamente para
  que o re-rome de 17/18 não encontre o número de malha deles deslocado por causa alheia. O que muda
  é o **material** e o censo da suíte (novas checagens somam no rodapé), e o censo é re-derivado nos
  documentos por esta perna.
- **Nenhum gate de fase se fecha aqui.** A fila P0/P1 (budget HOT, censo multi-semente, bake-off de
  AF) continua aberta, exatamente como em todas as pernas anteriores.

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
