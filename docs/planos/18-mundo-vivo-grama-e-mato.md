# 18 — Mundo vivo: grama que cresce e o mato decorativo

Dossiê de **leitura de código**, não de corrida: nenhuma engine rodou aqui e nenhum número
publicado foi re-medido por este arquivo. Entra na fila porque o dono pediu a pauta em
2026-11-21 no segundo dos dois prompts ("Física de Blocos + Mundo Vivo"), item B e C dele, e
o registro vem **antes** de qualquer linha de código (mandato 4 de
[`AGENTS.md`](../../AGENTS.md)). Números de `arquivo:linha` da `main` em `86e63c4`.

Diferente do dossiê 17, **a metade A deste prompt não tem especificação para conferir**: o
crescimento de grama não está em
[`docs/design/10-world-layers-and-block-physics.md`](../design/10-world-layers-and-block-physics.md)
em lugar nenhum (grep de "grama que cresce", "spread", "grass" na file devolve zero
ocorrências de espalhamento). Este arquivo é a primeira vez que a regra é escrita, e ela é
marcada `[TARGET]` até existir código. O `PLANT`, esse sim, já tem id e tile prometidos no doc
10 ([`:189`](../design/10-world-layers-and-block-physics.md#L189),
[`:218-219`](../design/10-world-layers-and-block-physics.md#L218-L219),
[`:1079-1080`](../design/10-world-layers-and-block-physics.md#L1079-L1080)).

## 1. Premissas nomeadas

**A. Uma célula de `DIRT` com ar acima e `GRASS` ao lado vira `GRASS` em tempo finito, e isso
acontece sem nenhuma varredura do mapa.** Falsificável em headless: montar a situação à mão
(coluna com `DIRT` exposto, uma célula de `GRASS` vizinha), avançar ticks e exigir
`get_block` mudando de 2 para 1, o evento `block_changed` visto, e o número de leituras
**limitado por célula candidada**, não por célula do mundo. O braço vermelho obrigatório
(ciclo 3 do contrato): sem vizinho de grama, a mesma coluna **não** muda em 10 000 ticks —
senão a checagem está apenas afirmando que `DIRT` exposto vira grama por decreto, o que não é
a regra pedida.

**B. O mato é visto, pisado e colhido, e não é um cubo.** Falsificável: `PLANT` colocado sobre
`GRASS` por geração **e** por espalhamento, `is_solid` falso (corpo atravessa), `line_of_sight`
atravessa (o ray só para em sólido,
[voxel_world.gd:365](../../src/world/voxel_world.gd#L365), [`:393`](../../src/world/voxel_world.gd#L393)),
dureza de mão nua, e um drop não-zero. A parte visual tem uma premissa própria e incômoda: o
atlas é gerado em runtime por uma função por tile
([voxel_atlas.gd:10-31](../../src/world/voxel_atlas.gd#L10-L31)), então "tem forma de mato" só é
checável por captura — e captura é janela, o que este lote **não** roda sem o dono liberar.

## 2. Estado real do código (lido, não medido)

- **Nada cresce hoje.** A única escrita de bloco de gameplay é do jogador
  ([player.gd:685](../../src/entities/player.gd#L685) quebra,
  [`:711`](../../src/entities/player.gd#L711) coloca). O mundo é estático depois da geração:
  `world_gen.gd` escreve as colunas uma vez (em [`generate_chunk`](../../src/world/world_gen.gd#L174)
  e companhia) e o [`apply_edits`](../../src/world/voxel_world.gd#L164) só reaplica o que o
  jogador já tinha feito.
- **Grama é só um bloco com drop de terra.** `GRASS` = id 1, tile 0/1, dureza 0,38, e o drop é
  `DIRT` ([`_drop[Block.GRASS] = Block.DIRT`](../../src/world/block_defs.gd#L142), com a razão
  escrita no comentário de `:141`). Isso importa para a regra A de um jeito que o prompt não
  diz: **quebrar grama já produz exatamente o substrato que a grama precisa para voltar** —
  a lavra do jogador cria o `DIRT` exposto que a propagação consome. A mecânica é o fechamento
  de um ciclo que já existe, não um sistema paralelo.
- **A superfície é decidida por bioma, e só por ruído.**
  [`surface_block(x, z, h)`](../../src/world/world_gen.gd#L165-L171): `WETLAND`/`ARID` →
  `SAND`, `FROZEN` → `SNOW` (ou `STONE` acima de 57), o resto → `GRASS`
  ([`:166-171`](../../src/world/world_gen.gd#L166-L171)). Logo a grama **não** existe em deserto
  nem em tundra: é lá que a regra A tem de ser recusada por bioma, e é por isso que o
  dossiê 09 (bioma como código) já entregue é pré-condição, não vizinhança.
- **`DIRT` exposto é uma pergunta de duas leituras**: `get_block(p + Y) == AIR` e o vizinho.
  O que **não** se faz para responder é chamar
  [`surface_height(x, z)`](../../src/world/voxel_world.gd#L402-L408): ela sobe a coluna do topo
  (`CHUNK_SIZE_Y - 1 = 63`) até achar sólido — 64 `is_solid` por coluna, por candidato. Um
  candidato por tick custa 2 + 4 leituras; uma varredura de superfície do mapa inteiro custaria
  128 × 128 × ~64 = **~1 048 576** leituras por passada. O número é aritmética sobre
  [`voxel_config.gd:5-11`](../../src/world/voxel_config.gd#L5-L11) (128 × 64 × 128), não medição.
- **`PLANT` não existe; o id e o tile estão prometidos e vazios.** O enum de
  [`block_defs.gd:10-22`](../../src/world/block_defs.gd#L10-L22) tem 0..8 e 19..22; 9..18 estão
  reservados ([`:5-8`](../../src/world/block_defs.gd#L5-L8)) e os tiles 10..18 também
  ([`:39`](../../src/world/block_defs.gd#L39)). Consequência concreta de hoje: se alguém
  colocasse `PLANT = 17` sem registrar nada, `is_solid` leria `_solid[17]` numa tabela de
  `COUNT = 23` ([`:37`](../../src/world/block_defs.gd#L37)) cujo default é **sólido e opaco**
  (o laço de `init_tables` preenche `1/1/OPAQUE/64/drop=self/0,4`,
  [`:86-92`](../../src/world/block_defs.gd#L86-L92)) e `tile_for` cairia no
  `_: return TILE_STONE` ([`:218-219`](../../src/world/block_defs.gd#L218-L219)). Ou seja:
  bloco novo **sem registro é um cubo de pedra invisível no mapa**, e é isso que a checagem
  §5.6 pega.
- **O drop não pode ser "pouco" sem um item novo.** Não há item: o inventário guarda
  **blocos** com `stack_max` ([`:161`](../../src/world/block_defs.gd#L161)) e o que cai é
  `drop_of` ([`:166`](../../src/world/block_defs.gd#L166)) — um id de bloco, não uma
  quantidade fracionada. O "dropa pouco" do prompt vira, no vocabulário que existe, `PLANT`
  caindo como `PLANT` com pilha cheia e sem semente. **Semente** é outra peça (não existe
  `sapling` — o próprio registro já admite isso para `LEAVES`:
  [`_drop[Block.LEAVES] = Block.AIR`](../../src/world/block_defs.gd#L143-L144)). Decisão deste
  dossiê: o mato cai como 1 `PLANT`, e plantar de novo é **colocar o bloco**, não item de
  agricultura.
- **O que uma célula que muda custa.** Cada conversão é um `set_block` → `edits[p] = b`
  ([voxel_world.gd:260](../../src/world/voxel_world.gd#L260)) + chunk sujo
  ([`:266-277`](../../src/world/voxel_world.gd#L266-L277)) remalhado a **2 chunks por frame**
  ([main.gd:19](../../src/main.gd#L19), [`:262-263`](../../src/main.gd#L262-L263)) ≈ 67 ms de
  boot por chunk nas medidas do contrato ([README.md:148-149](../../README.md#L148-L149)).
  O `edits` **não tem teto** ([`:42`](../../src/world/voxel_world.gd#L42) é um `Dictionary`
  puro, serializado inteiro em [main.gd:625-637](../../src/main.gd#L625-L637)); hoje cresce
  1 chave por ação do jogador, e um ecossistema que cresce sozinho o faria crescer por tempo de
  sessão, não por trabalho do jogador. Isso é o débito real desta linha, declarado antes.
- **RNG: há um riacho por dono e a suíte bate nele.** A sessão tem
  `_population_rng` ([main.gd:64](../../src/main.gd#L64), semeado por
  `("population:%d" % world_seed).hash()` em [`:320`](../../src/main.gd#L320) na perna 11) e
  cada lobo tem o `_rng` próprio. Uma propagação que sortear célula **comendo o riacho da
  população** muda a ordem de spawns e derruba a suíte de RNG isolada
  (`tests/simulation_rng_test.gd`) sem mudar uma linha de comportamento. O lote abre riacho
  próprio (`("world_growth:%d" % seed).hash()`), pelo mesmo motivo pelo qual o sorteio saiu do
  gerador global.
- **O atlas é determinístico por ordem de desenho.**
  [`build_texture()`](../../src/world/voxel_atlas.gd#L10-L31) cria uma `Image` de
  `GRID × TILE = 8 × 16` ([`:5-6`](../../src/world/voxel_atlas.gd#L5-L6)), semeia um único
  `RandomNumberGenerator` com `ATLAS_SEED = 20260116` ([`:7`](../../src/world/voxel_atlas.gd#L7),
  [`:14`](../../src/world/voxel_atlas.gd#L14)) e chama uma função por tile **em sequência**,
  terminando em `_bench` ([`:29`](../../src/world/voxel_atlas.gd#L29)). Cada `_noise_fill`
  consome o riacho. Consequência obrigatória: **o tile novo é desenhado por último** — inserir
  `_plant` no meio do bloco desloca o estado do RNG e reescreve as pixels de tudo que vem
  depois, o que é exatamente o tipo de mudança que as assinaturas pinadas da galeria e do
  relevo não perdoam.

## 3. O que a peça exige

1. **Nada de relógio de mundo, nada de varredura.** A propagação entra pela mesma porta do
   dossiê 17 — o sinal [`block_changed`](../../src/world/voxel_world.gd#L6) — com uma fila
   própria e cadência própria: quando uma célula vira `AIR` ou `DIRT`, os candidatos são **ela
   e as 4 vizinhas horizontais na mesma Y**; quando vira `GRASS`, candidata é a mesma célula
   para o `PLANT`. Cada candidato é reavaliado com atraso de `GROW_RECHECK` ticks, do lado
   **lento** do mundo: `GROW_PERIOD` ≈ alguns segundos de simulação, não o tick de 20 Hz. O
   motivo é o mesmo do doc 10 para a gravidade (
   [`:663-665`](../design/10-world-layers-and-block-physics.md#L663-L665)): o que não entrou na
   fila nunca é lido.
2. **Três números novos, nomeados e `[TARGET]` até a primeira corrida**: `GROW_PERIOD` (segundos
   entre reavaliações de um candidato), `GROW_CHANCE` (probabilidade por candidato por
   avaliação) e `GROW_MAX_PER_TICK` (teto de conversões — **1** no começo, porque uma conversão
   é um remesh e o budget de malha é 2/frame). O teto por tick é o que mantém a propagação de
   um campo inteiro de 200 células candidadas atrás do orçamento da malha.
3. **Regra A literal, com as quatro condições todas lidas no `flush`**: bloco == `DIRT`,
   acima == `AIR`, **Y abaixo não é líquido** (grama não cresce num espelho d'água — `WATER` é
   não-sólido, [`block_defs.gd:99-104`](../../src/world/block_defs.gd#L99-L104)), e ≥ 1 das 4 vizinhas horizontais == `GRASS`. A
   recusa por bioma **não** entra aqui como segunda regra: ela já é verdade por construção,
   porque `surface_block` não põe grama em deserto nem tundra
   ([world_gen.gd:166-171](../../src/world/world_gen.gd#L166-L171)) e sem grama vizinha não há
   propagação. O que tem de existir é a checagem que diz isso (§5.4), não um `if biome` novo.
4. **`PLANT` registrado, não só numerado**: id 17 (append-only, `[DECIDED]` 8 do doc 10,
   [`:1067-1070`](../design/10-world-layers-and-block-physics.md#L1067-L1070)), tile 18,
   `solido = 0`, `opaco = 0`, `draw = ALPHA` (o vidro já é o precedente de face
   não-opaca — [`block_defs.gd:133-136`](../../src/world/block_defs.gd#L133-L136)),
   dureza 0,05, drop = ele mesmo, nome "mato", e o **desenhador de tile novo por último** no
   atlas. A geometria de poste/cruzeta continua `[OPEN]` no doc
   ([`:1079-1080`](../design/10-world-layers-and-block-physics.md#L1079-L1080)); a malharia só
   conhece cubos ([`FACE_CORNERS`, voxel_world.gd:14-21](../../src/world/voxel_world.gd#L14-L21)),
   então o primeiro `PLANT` é uma **face Alpha desenhada como mato num cubo fino** — e o que
   não for isso é dito no §6, não feito.
5. **Colocação e lavra não mudam de porta**: o `PLANT` entra no inventário pelo drop, sai pela
   lavra do mesmo `_mine_target` ([player.gd:677-690](../../src/entities/player.gd#L677-L690))
   e é colocado pelo `_try_place`, **que hoje recusa qualquer célula que não seja `AIR` ou
   `WATER`** ([`:702-703`](../../src/entities/player.gd#L702-L703)). Isso significa que mato no
   chão bloqueia colocar bloco ali. A peça nova é o campo `substituivel` do doc
   ([`:159`](../design/10-world-layers-and-block-physics.md#L159)) lido por `_try_place` —
   **um campo, um comprador**, e o comprador é a colocação do jogador. Não é refatoração
   opcional: sem isso o mato é um obstáculo invisível que come o clique do jogador.
6. **Observabilidade antes de orgulho**: `diagnostics()`
   ([main.gd:717-732](../../src/main.gd#L717-L732)) ganha `growth_queued`, `growth_converted`
   e `edits.size()` já está lá (`:721`) — o par `edits` × tempo de sessão é o que mede se a
   linha é ecologia ou vazamento de disco.

## 4. Custo — as quatro perguntas

- **Roda por frame, por tick ou às vezes?** A fila de crescimento: **dentro do tick de 20 Hz**,
  mas com reavaliação a cada `GROW_PERIOD` segundos de simulação; a conversão: no máximo
  1 por tick. A malha resultante: `_process`, fora do budget do passo
  ([main.gd:262-263](../../src/main.gd#L262-L263)).
- **Quantas entidades são alcançadas?** Nenhum bicho. Células: 1 evento de bloco candidata
  **5** (ela + 4 vizinhas), e cada reavaliação custa 6 `get_block` (1 própria + 1 acima + 1
  abaixo + 4 vizinhas, menos as sobrepostas). Com `GROW_MAX_PER_TICK = 1`, o teto por segundo
  é 20 conversões = 20 remeshes pedidos — **acima** do que a malha entrega (2/frame a 60 fps
  ≈ 120/s, então cabe; a conta é a que decide, e ela é impressa na checagem §5.5).
- **Aloco no caminho quente?** Um `Dictionary` de candidatos (linha nova) e o snapshot
  ordenado por célula — a mesma classe de alocação que o dossiê 17 declara como débito. Nada
  de `Array` novo por tick quando a fila está vazia: retorna cedo.
- **Como sei que ficou melhor / quanto custa?** Medindo antes de celebrar: `worst_sim_ms` com
  crescimento ativo vs. não (a régua é a mesma das rodadas de ablação do contrato), `max
  pending_meshes()`, `edits.size()` depois de N minutos de sessão, e o tempo de boot do save
  re-carregado. Critério escrito antes da corrida: `dropped_ticks == 0` no smoke e
  `edits.size()` **limitado por conversão**, não por tempo — se a curva for linear ao tempo de
  sessão, o `GROW_CHANCE` cai, e não o budget de malha sobe.

## 5. Gate em headless

```sh
godot --headless --path . --check-only --script src/world/block_defs.gd
godot --headless --path . --script tests/aether_reactions_test.gd
godot --headless --path . tests/smoke_test.tscn
```

1. **`grama_precisa_de_vizinha`** — dois braços na mesma cena: `DIRT` exposto com uma célula
   de `GRASS` ao lado muda em tempo finito; sem vizinha, **não** muda em 10 000 ticks. Imprime
   os ticks, o número de candidatos e o de conversões. É o par que o ciclo 3 exige.
2. **`crescimento_nao_varre_nada`** — contador de `get_block` por avaliação, com o mapa
   intacto: 0 leituras sem nenhum evento de bloco em 1 000 ticks, e ≤ 6 por candidato
   reavaliado. O número que assusta (1 048 576 leituras por passada de varredura, §2) é
   impresso ao lado como o que **não** aconteceu.
3. **`crescimento_sobrevive_ao_save`** — grama crescida está no `edits` e volta no load;
   imprime `edits.size()` antes/depois e o `GEN_VERSION`
   ([world_gen.gd:6](../../src/world/world_gen.gd#L6), que **não** sobe aqui: nenhuma regra de
   geração mudou, só o que o mundo faz depois de gerado).
4. **`grama_nao_cresce_onde_nao_ha_grama`** — cenário em bioma `ARID`/`FROZEN` (mesmo seed do
   smoke, colunas lidas de `surface_block`): nenhum candidato nasce, porque não há `GRASS`
   vizinha. Sem esta checagem, a regra A é uma promessa sobre o temperate e ninguém sabe.
5. **`crescimento_nao_estoura_a_malha`** — 5 000 ticks com propagação ativa: `max
   pending_meshes()`, `worst_sim_ms`, `dropped_ticks == 0` e o número de conversões impressos
   lado a lado com o mesmo cenário com a mecânica desligada.
6. **`mato_e_nao_solidez_nem_pedra`** — `PLANT` no mundo: `is_solid` falso, `is_opaque` falso,
   `line_of_sight` atravessa uma linha com 20 cells de mato entre olho e alvo, `hardness` = a
   mão nua mais rápida do registro, `drop_of != AIR`, e `tile_for` **não** devolve
   `TILE_STONE` (o default silencioso de [`:218-219`](../../src/world/block_defs.gd#L218-L219)).
   Esta checagem existe porque as cinco primeiras propriedades viram verdade por tabela e a
   sexta **não**: errar o registro dá um cubo de pedra invisível.
7. **`mato_nao_engole_o_clique`** — com `PLANT` no chão, o `_try_place` do jogador coloca o
   bloco na célula (o `substituivel` do §3.5), e a recusa continua acontecendo contra um
   sólido. Imprime o `cur` recusado/aceito.
8. **`crescimento_nao_consome_rng_da_sessao`** — o riacho novo não toca `_population_rng`: a
   mesma semente, com e sem mecânica ligada, devolve a mesma sequência de spawns já conferida
   por `tests/simulation_rng_test.gd`. Sem ela, a perna passa a mentir sobre sorteio.
9. `EXPECTED_CHECKS` ([aether_reactions_test.gd:30](../../tests/aether_reactions_test.gd#L30),
   **183** nesta leitura) e a última linha do smoke ([smoke_test.gd:184](../../tests/smoke_test.gd#L184))
   sobem com o lote, re-medidos no clone limpo com `--import` frio.

## 6. O que NÃO fazer

- **Nenhuma varredura global, nem "só no boot", nem "só a cada 5 min"**. Se a propagação
  precisar olhar o mapa inteiro, ela perdeu a premissa e o lote volta para o §3.1.
- **Nada de luz, fluidos, neve derretendo, crescimento em altura (bambu/sapling), estações do
  ano ou fogo** — nada dos quatro tem comprador agora, e o doc 10 já manteve dois deles
  `[OPEN]` ([`:1081-1086`](../design/10-world-layers-and-block-physics.md#L1081-L1086)).
- **Nada do Veloren** (código, asset, `.ron`, áudio) — mandato 8. O que se aproveita é a
  ideia de mundo que reage.
- **Não mexer no layout do atlas nem inserir desenhador no meio da sequência** (§2, última
  linha): tile novo é por último, senão o `ATLAS_SEED` compartilhado reescreve os tiles
  existentes e as capturas pinadas deixam de ser a mesma imagem.
- **Não dar forma de poste ao mato neste lote**: a malharia só conhece cubos e a shape table é
  [doc 10 `:1079-1080`](../design/10-world-layers-and-block-physics.md#L1079-L1080) `[OPEN]`.
  Um `PLANT` meio-cubo meio-desenho é o "look wrong" que o contrato proíbe por dentro
  (mandato "sem gambiarra"): ou é face Alpha num cubo registrado, ou o item visual fica
  `[OPEN]` e dito.
- **Não subir `MESH_BUDGET`** ([main.gd:19](../../src/main.gd#L19)) para acomodar conversões.
- **Não escrever chave nova no save sem declarar o custo em `edits.size()`** — a grama que
  cresce sozinha é exatamente o caso em que o arquivo cresce sem o jogador fazer nada, e isso
  precisa aparecer em log antes de aparecer no disco do jogador.

## 7. Commits atômicos

(a) `PLANT` no registro (id 17, tile 18, as sete tabelas + `swatch` + `display_name`), com 6
do §5 **e** o desenhador de tile por último; (b) `substituivel` com um comprador, `_try_place`,
com 7; (c) fila de crescimento event-driven + regra A, com 1, 2 e 4; (d) `PLANT` nascendo sobre
`GRASS` pela mesma fila (a parte C do prompt), com 1 adaptado e 6; (e) save/hash/RNG com 3 e 8;
(f) colheita de custo com 5, publicada no status; (g) status + `README.md` + evidência em
`docs/evidence/mundo-vivo-18/`. Branch `feat/mundo-vivo-grama-e-mato-18`, merge `--no-ff`.

## 8. O que este dossiê não fecha

Nenhum gate de fase (mandato 4). Não é ecologia de população (P2), não é agricultura, não é
item de semente, não é forma geométrica nova na malharia, e não é o Éter lendo nada sobre o
que cresce — se a propagação um dia imprintar WORK ou um canal novo, isso é decisão de
`Channel.COUNT` e, portanto, de `FORMAT_VERSION`
([tick_journal.gd:4](../../src/persistence/tick_journal.gd#L4)), com re-mediação das pernas
anteriores, como o guard-rail do dossiê 13 já escreve.

## 9. Invenções do prompt, registradas aqui

- **"doc 10 já fala de crescimento de grama"**: não fala. grep por espalhamento/grama
  dinâmica na spec devolve zero. A regra A nasce neste arquivo, `[TARGET]`.
- **"`PLANT` nos ids reservados com forma de tall grass"**: o id 17 e o tile 18 estão
  reservados, mas a geometria é `[OPEN]` no próprio doc
  ([`:659`](../design/10-world-layers-and-block-physics.md#L659),
  [`:1079-1080`](../design/10-world-layers-and-block-physics.md#L1079-L1080)) porque a malharia
  só conhece cubos. O lote entrega registro + Alpha, não poste.
- **"dropa pouco"**: não existe quantidade por item fora de pilha de blocos
  (`stack_max`/`drop_of`), nem item de semente. Vira "1 bloco de mato", dito como tal.
- **"nasce sobre GRASS, não é sólido, quebrável com a mão"**: as três primeiras são
  implementáveis como estão; a quarta (**colocar bloco em cima de mato**) exige o campo
  `substituivel` lido por `_try_place`, que o prompt não menciona e sem o qual o mato trava a
  construção do jogador.
