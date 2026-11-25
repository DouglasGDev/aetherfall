# 16 — Tocas da alcateia (o mapa que a matilha nunca ocupou)

Dossiê de **leitura de código**, não de corrida: nenhuma engine rodou aqui e nenhum número
publicado foi re-medido por este arquivo. Entra na fila porque o dono pediu, por escrito, em
2026-11-21, e o número **16 estava reservado para esta página** desde então — a reserva, a
posição escolhida por ele (logo depois da 11) e o motivo constam de
[`AGENTS.md`](../../AGENTS.md), "Extensão de 2026-11-21", e do índice
[`docs/planos/README.md`](README.md). O registro vem **antes** de qualquer linha de código, como
exige o mandato 4.

Números de `arquivo:linha` desta página são da `main` em `e0450a3` (perna 11 pousada: ponta de
código `0762b43`, merge do código `4b858c2`, fecho `5b519f8`, pin `e0450a3`).

## 1. Premissa nomeada

**A matilha nasce, reproduz e é reposta dentro de um único círculo de 18 m de raio, e o mapa tem
116 × 116 m úteis; por isso o dono percorreu o vale inteiro e viu um lobo só.** Falsificável em
headless, com o jogador longe e sem um único `action_press`: montar a sessão real de boot
(`_boot_session(5)` já existe), ler `pack_of()` de cada lobo e contar **componentes conexos do
grafo de coesão**; exigir (i) ≥ 2 componentes com lobo vivo dentro, (ii) que nenhum lobo le um
lobo de outro componente, (iii) que a menor distância entre dois lares de componentes
diferentes seja ≥ `DEN_MIN_DIST`, e (iv) que a reposição da fila e o parto devolvam o bicho para
o **componente que perdeu o membro**, não para o primeiro vivo.

O segundo sentido que o ciclo 3 do contrato exige: com a **mordaca atual** no lugar, o mesmo
cenário devolve **um** componente e `max componente == censo`. Sem esse braço, o verde pode estar
afirmando apenas que o sorteio desta semente caiu longe.

Recorte que a premissa **não** cobre, e que a frase "colocar os lobos em tocas" misturaria:

- **Geometria de toca desenhada** (a entrada, o terreno escavado, o monte de terra): a malharia
  só conhece cubos e nada aqui compra um `BlockDefs` novo. O que esta perna entrega é **lugar**
  (um centro registrado pela sessão e lido por quem decide), não **objeto**. A toca visível fica
  `[OPEN]`, dita como arte/backlog.
- **Espécies novas, NPC, outra espécie animal**: `src/entities/` tem `player`, `player_avatar`,
  `fp_viewmodel`, `voxel_body` e `wolf` — uma espécie animal, nenhum NPC (registrado no dossiê 13
  §1, §3.4). A palavra do pedido é "matilha", e matilha é lobo.
- **Tamanho de mapa ou relevo**: o mundo é 8 × 8 chunks de 16 × 64 × 16
  ([`voxel_config.gd:7-11`](../../src/world/voxel_config.gd#L7-L11)), `world_size_x()`/`world_size_z()`
  = 128 ([`:19-24`](../../src/world/voxel_config.gd#L19-L24)), e o `GEN_VERSION` não sobe aqui.
  Aumentar o mapa para caber as tocas é outra decisão, de formato de save.
- **Rotação de tocas com o jogador**: o pedido é "espalhar", não "seguir". Uma toca que anda
  atrás de quem anda recria o círculo único desta página.
- **Densidade por bioma, migração sazonal, território marcável no Éter**: nada disso tem comprador
  agora; o viés de imprint por bioma já existe (dossie 09) e não é chamado aqui.

## 2. Estado real do código (lido, não medido)

### 2.1 O mapa e o círculo

- **Área útil.** O mundo é 128 × 128 m = **16 384 m²** (`voxel_config.gd:9-11`, `:19-24`). O
  sorteio de lar clampa o ponto para `6 … W-6` ([`main.gd:807-808`](../../src/main.gd#L807-L808)),
  ou seja, **116 × 116 = 13 456 m²** de alvo possível; a ronda clampa para `4 … W-4`
  ([`wolf.gd:611-612`](../../src/entities/wolf.gd#L611-L612)).
- **O jogador acorda no centro.** `spawn_point()` devolve `(64, y, 64)`
  ([`main.gd:294-297`](../../src/main.gd#L294-L297)) e `_ready` põe o jogador ali antes do sorteio
  ([`main.gd:169`](../../src/main.gd#L169): `player.setup(world, spawn_point())`) e o sorteio da
  matilha só vem depois ([`main.gd:239`](../../src/main.gd#L239): `_spawn_wolves(WOLF_COUNT)`).
- **A banda do primeiro lobo** é 16–46, 46–70 ou 70–`_band_edge` m do jogador
  ([`main.gd:544`](../../src/main.gd#L544), tentativas em
  [`:758-760`](../../src/main.gd#L789-L791)); com o jogador no centro, `_band_edge` devolve
  `sqrt(58² + 58²) = 82,0` m ([`main.gd:767-770`](../../src/main.gd#L767-L770)).
- **Os outros quatro não usam banda nenhuma: usam a mordaca.** Na arvore que a pauta leu
  (`99d1167`), `_spawn_wolves` pedia o lar com `near = _pack_leash()` (`99d1167:src/main.gd:328`)
  e `_pack_leash()` devolvia o **lar do primeiro lobo vivo** — não um por lobo, não rotativo
  (`99d1167:src/main.gd:501-505`). Hoje a ancora é o centro da toca, e quando `near` existe a tentativa é
  o anel **4–18 m** dele ([`main.gd:788`](../../src/main.gd#L788), `PACK_LEASH = 18.0` em
  [`:522`](../../src/main.gd#L553)), e as bandas do jogador só entram se as 24 tentativas da
  mordaca se esgotarem (`SPAWN_ATTEMPTS = 24` em [`:514`](../../src/main.gd#L545), laço em
  [`:772`](../../src/main.gd#L803)).
  Consequência aritmética, **derivada das constantes, não medida**: os cinco lares do boot cabem
  num disco de raio 18 m em torno do lar do lobo 0 — **1 018 m²**, 7,6 % da área útil e 6,2 % do
  mapa. A distância máxima possível entre dois lares do boot é 36 m.
- **O parto não espalha: adensa.** `_born_from` ancora o ponto no **ponto médio dos dois lares**
  ([`main.gd:510`](../../src/main.gd#L510)) e a âncora entra pela mesma mordaca de 4–18 m
  ([`main.gd:788`](../../src/main.gd#L788)). Com dois adultos a ≤ 36 m um do outro, o médio está
  dentro do mesmo disco; cada geração pode correr o lar ≤ 18 m, e nada no código ancora um lar a
  um **lugar**.
- **A reposição também não espalha.** A fila de 45 s ([`main.gd:30`](../../src/main.gd#L30),
  esvaziada em [`:294-307`](../../src/main.gd#L325-L338), `respawn` enfileirado na recusa em
  [`:368`](../../src/main.gd#L399) e na recolha de cadáver em
  [`:915`](../../src/main.gd#L946)) chama `_spawn_wolves(1)`, que de novo ancora no **primeiro
  vivo**. Um elemento da fila é um número (`RESPAWN_DELAY`), não um par `(toca, atraso)`: hoje a
  fila não tem como dizer **de onde** veio a vaga.
- **A ronda é em torno do baricentro do que o lobo lê**, e não do seu lar: `_leaf_wander`
  ([`wolf.gd:583-601`](../../src/entities/wolf.gd#L583-L601)) sorteia 5–22 m
  (`WANDER_RADIUS = 22.0` em [`wolf.gd:26`](../../src/entities/wolf.gd#L26), raio em
  [`:609`](../../src/entities/wolf.gd#L609)) em torno de `_territory_center(n)`
  ([`wolf.gd:616-623`](../../src/entities/wolf.gd#L616-623)) — o baricentro das posições lidas,
  decidido de propósito no dossiê 10 §3.2 porque "cinco lares espalhados nunca foram território".
  Só o lobo **sozinho** ronda em torno do próprio lar ([`:593`](../../src/entities/wolf.gd#L593),
  e o mesmo retorno em [`:600`](../../src/entities/wolf.gd#L600) quando a fatia inteira é água).

### 2.2 A coesão já sabe separar — é o sorteio que não deixa

- `PACK_COHESION_RADIUS = 24.0` ([`main.gd:39`](../../src/main.gd#L39)) é o que faz dois lobos se
  lerem, e `_rebuild_packs()` ([`main.gd:885-905`](../../src/main.gd#L885-L905)) já monta um grafo
  **por distância**, uma passada por passo, sem alocar por leitura
  ([`main.gd:876-879`](../../src/main.gd#L876-L879), [`:907-926`](../../src/main.gd#L912-L931)).
  Isto significa que **não existe código de "grupo" a escrever**: se os lares ficarem a mais de
  24 m, os componentes se separam sozinhos, e a ronda de cada um passa a ser o baricentro do seu
  próprio componente — a propriedade da perna 10 sobrevive intacta, só muda a quem ela se aplica.
- **`pack_pairs` não é aresta de coesão** — é **par testado**: o contador incrementa em
  [`main.gd:899`](../../src/main.gd#L899), **antes** do teste de raio em
  [`:869`](../../src/main.gd#L900). Com 5 vivos ele é sempre C(5,2) = 10 e com 12 é sempre 66.
  A asserção `pack_pairs == n*(n-1)/2` da suíte
  ([`smoke_test.gd:357-362`](../../tests/smoke_test.gd#L357-L362)) é, portanto, **verdade
  aritmética**: o que decide aquela linha hoje é o `biggest >= 2` (o maior `_pack` lido), não o
  número de pares. Nada em `src/` nem em `tests/` conta **arestas aceitas** nem componentes.
  Registrar como **furo #21** (§8).

### 2.3 O que não existe (grep conferido nesta ponta)

`grep -i` por `toca`, `\bden\b`, `dens`, `DEN_`, `home_of`, `pack_id`, `_den` sobre `src/` e
`tests/` (`.gd`): **zero** ocorrências do conceito. Os hits são a palavra "tocando/toca" em
comentário (`llm_server_host.gd:4`, `audio_director.gd:179`, `player.gd:588`), `TREE_DENSITY` /
`BOULDER_DENSITY` (`world_gen.gd:7-8`, `:236`, `:238`) e `fog_density` (`main.gd:1003`). Não há:
lista de tocas, campo `den` no lobo, chave no save, contador de componentes em `diagnostics()`
([`main.gd:1206-1250`](../../src/main.gd#L1206-L1250) tem `wolves`, `wolves_alive`, `pack_pairs`,
`pending_respawns`, `census_cap`, `load_created`, `load_retired`, `census_refusals`, `births` —
nenhum deles diz **onde** a matilha está), nem predicado de distância mínima entre lares de grupos
diferentes.

### 2.4 O que já está gateado e esta perna encosta

| Promessa já verde | Onde | O que a 16 faz com ela |
|---|---|---|
| "lar do boot fora da distância segura e da visada" | [`aether_reactions_test.gd:3181-3184`](../../tests/aether_reactions_test.gd#L3181-L3184) | **mantida**: cada toca nova passa pelo mesmo `_spawn_point_ok` (`main.gd:730-735`) |
| "lobo reposto nasce fora da distancia segura e da visada" | [`:3202-3205`](../../tests/aether_reactions_test.gd#L3208-L3211) | mantida, e ganha a cláusula de **qual** toca |
| "lares do spawn real em colunas diferentes, censo fechado pela fila" | [`:2744-2748`](../../tests/aether_reactions_test.gd#L2750-L2754) | mantida: coluna distinta continua exigida (`_home_columns`, `main.gd:507-511`) |
| "censo do boot fecha a conta: o que nao nasce volta para a fila" | [`:3172-3174`](../../tests/aether_reactions_test.gd#L3178-L3180) | mantida, e a fila passa a carregar a toca |
| ronda de lobo único idêntica à fórmula anterior | [`:1991-1995`](../../tests/aether_reactions_test.gd#L1997-L2001) | **intacta apenas no braço A** (§3.4): ela replay-a `_pick_wander(home, …)`, e `home` continua sendo o lar do lobo |
| `ronda_centro_e_baricentro_e_nao_o_lar_do_lobo` | [`:2047-2050`](../../tests/aether_reactions_test.gd#L2053-L2056) | **intacta apenas no braço A**; o braço B re-derive esta linha e a de cima, e isso é custo declarado, não surpresa |
| spawn em lote == spawn um a um (assinatura da sequência) | [`simulation_rng_test.gd:119-127`](../../tests/simulation_rng_test.gd#L119-L127) | **tem de continuar verde**: a escolha de toca não pode ser função de sorteio extra nem de ordem de processo |
| "alcateia existe na sessao real" | [`smoke_test.gd:357-362`](../../tests/smoke_test.gd#L357-L362) | re-derivada: `biggest >= 2` passa a conviver com `componentes >= 2` |

## 3. O que a peça exige

### 3.1 Dono do estado

A toca é **lugar registrado pela sessão**, não etiqueta do lobo. O dono é `main.gd`, pelo mesmo
motivo declarado na perna 11 ([`main.gd:484-485`](../../src/main.gd#L484-L485)): `wolves`,
`_next_identity` e `_home_columns()` já têm um dono só. A peça nova é `var _dens: Array` (uma
entrada por toca, com o centro em metros e a coluna que a ocupa), construída no sorteio e lida no
sorteio. O lobo ganha **um** campo de leitura — `den: int`, o índice da toca — porque a reposição
e o parto precisam herdar pertença, e `state_dict()`/`load_state()`
([`wolf.gd:1099-1112`](../../src/entities/wolf.gd#L1099-L1112),
[`wolf.gd:1115-1146`](../../src/entities/wolf.gd#L1115-L1146)) já têm o padrão de chave aditiva
com default explícito (fase/idade/`mate_cd`, [`:1130-1138`](../../src/entities/wolf.gd#L1130-L1138)).

### 3.2 Regra de colocação (o corte real no círculo de 18 m)

1. `DEN_COUNT = 3` `[TARGET]` — o número do pedido ("2–3 tocas"); **3 é o teto de fundação e o
   boot escolhe 3** porque com `WOLF_COUNT` = 5 ( [`main.gd:9`](../../src/main.gd#L9)) a
   distribuição 2/2/1 é a menor que faz um componente ter dois membros e ainda deixar sobra.
   Fundar mais que `DEN_COUNT` é recusado e **contado**, não silencioso (mesma régua da recusa de
   censo, [`main.gd:498-502`](../../src/main.gd#L498-L502)).
2. **Fundar** usa as bandas que já existem, em torno do jogador **no instante do boot**, e acrescenta
   um portão: ≥ `DEN_MIN_DIST` do centro de **toda** toca já fundada. Os portões velhos
   (`SAFE_SPAWN_DIST`, visada, coluna ocupada, seco, volume livre) continuam os mesmos e na mesma
   ordem ([`main.gd:809-828`](../../src/main.gd#L809-L828)).
3. **Entrar** usa a mordaca de sempre, com a âncora trocada de "primeiro vivo" para "centro da
   toca escolhida", e o anel 4–18 m ([`main.gd:788`](../../src/main.gd#L788)) não muda de valor.
4. **Escolher a toca** é determinístico e sem sorteio novo: a mais vazia (menor número de membros
   vivos), desempate por índice menor. Isto é o que mantém a equivalência lote/um-a-um do
   `simulation_rng_test` (§2.4), porque a função é do estado vivo, não da sequência de `randf`.
5. A toca **não segue o jogador**: fundada, fica. É o corte com o comportamento atual, que
   refaz a banda em torno de `player.position3()` a cada recusa ([`main.gd:784`](../../src/main.gd#L784)).
6. `DEN_MIN_DIST`: o valor sai **medido** nesta perna, com o arco derivado antes do código — para
   dois corpos não se lerem é preciso > `PACK_COHESION_RADIUS` = 24 m, e para dois *componentes*
   não se fundirem é preciso mais, porque o corpo anda até 22 m do baricentro
   ([`wolf.gd:609`](../../src/entities/wolf.gd#L609)). Geometria: três pontos cabem no quadrado
   útil de 116 m com separação mínima de até 116 m, então `48.0` m **cabe** e é o ponto de partida
   `[TARGET]`; o número publicado na checagem é o mínimo medido entre tocas na corrida, não o
   palpite.

### 3.3 Pertença nos três caminhos que põem bicho no mundo

- **Sorteio** ([`main.gd:382-405`](../../src/main.gd#L382-L405)): a primeira `DEN_COUNT` crias
  fundam; o resto entra.
- **Fila** ([`main.gd:325-338`](../../src/main.gd#L325-L338), `:394`, `:941`): o elemento da fila
  passa a carregar a **toca de quem morreu**, e a reposição entra nela. Hoje a fila é uma lista de
  floats; é a mudança que faz "a toca que perdeu" existir. O `.size()` lido por
  `pending_respawns` ([`:1188`](../../src/main.gd#L1219)) e por
  `simulation_rng_test.gd:104` não muda de significado.
- **Parto** ([`main.gd:495-528`](../../src/main.gd#L495-L528)): a cria herda a toca do adulto de
  **identidade menor** — o mesmo desempate por identidade que a ronda já usa para ordenar
  assentos ([`wolf.gd:639-644`](../../src/entities/wolf.gd#L639-L644)) — e o âncora deixa de ser o
  ponto médio dos dois lares, porque um casal de tocas diferentes produzia um lar **fora de
  qualquer toca**: o caso que hoje não existe só porque a mordaca nunca deixou as tocas existirem.

### 3.4 O fork decidido por medição, registrado antes do código

O baricentro da matilha lida **não tem âncora nenhuma**: ele é a média das posições, renovada a
cada 4–9 s ([`wolf.gd:591`](../../src/entities/wolf.gd#L591)), e com fatias de 5–22 m o centro
faz um passeio aleatório. Com uma matilha só isso era invisível (o bando nunca saiu de onde
estava porque nunca houve para onde); com três, ele pode **re-fundir** as tocas.

- **Braço A (colocação, sem âncora)** — menor diff, nenhuma linha de percepção tocada, as duas
  checagens da perna 10 intactas. Aceito se a checagem §5.6 (`toca_nao_deriva_para_unica`) medir
  o componente ≥ 2 ao fim da janela.
- **Braço B (colocação + âncora)** — `DEN_RANGE` limita o centro da ronda ao próprio
  `_territory_center` **deslocado no máximo até a borda da toca**. Custo honesto: re-derivar
  `ronda_centro_e_baricentro_e_nao_o_lar_do_lobo` ([`aether_reactions_test.gd:2053-2056`](../../tests/aether_reactions_test.gd#L2053-L2056))
  e a linha do lobo único ([`:1991-1995`](../../tests/aether_reactions_test.gd#L1997-L2001)), e
  mexer em `wolf.gd` com checagem gateada da perna 10. Só entra com o vermelho do braço A na mesa.

A casa decide: **A primeiro**, e o número que escolhe entre os dois é impresso, não argumentado.

### 3.5 O que sai em observabilidade

`diagnostics()` ([`main.gd:1206-1250`](../../src/main.gd#L1206-L1250)) ganha três números, todos
derivados do que já existe, nenhum no caminho quente: `dens` (toca fundada), `den_components`
(componentes conexos do grafo lido) e `den_min_dist` (menor distância centro-a-centro). O F3 não
chama `diagnostics()` por frame — ele lê `clock.*` direto
([`hud.gd:258`](../../src/ui/hud.gd#L258)) e a linha por lobo vem do roster
([`main.gd:869`](../../src/main.gd#L869)) — então a conta roda quando o diagnóstico é pedido, e o
`stats_line()` ([`main.gd:1200-1203`](../../src/main.gd#L1200-L1203)) ganha a toca de cada lobo na
linha que já imprime por bicho.

## 4. Custo — as quatro perguntas

- **Roda por frame, por tick ou às vezes?** Colocação: **às vezes** — cinco no boot
  ([`main.gd:239`](../../src/main.gd#L239)), um por fila de 45 s
  ([`:294-307`](../../src/main.gd#L325-L338)) e um por parto com cadência de 1 s e cooldown de
  300 s por par ([`main.gd:579`](../../src/main.gd#L579), [`:590`](../../src/main.gd#L595)). O
  `O(tries × 24)` pior caso já é o de hoje; a portada nova (`≥ DEN_MIN_DIST` de toda toca) custa
  `≤ 3` contas de distância por tentativa, no caminho raro. Nada entra em `_sim_tick` nem em
  `_physics_process`. Pertença: uma atribuição no `_make_wolf`
  ([`main.gd:422-440`](../../src/main.gd#L422-L440)). O grafo já é reconstruído por passo e sua
  complexidade não muda (`≤ 66` pares com `CENSUS_CAP` = 12).
- **Quantas entidades são alcançadas?** ≤ 12 lobos vivos e ≤ 3 tocas. Componentes: `O(n +
  arestas)` sobre buffers que já existem, **dentro de `diagnostics()`** — não por tick.
- **Aloco no caminho quente?** A lista de tocas é um membro criado uma vez (`≤ 3` `Vector3`), sem
  cópia por spawn; o `den` é um `int` no lobo. A conta de componentes, **se** um dia entrasse no
  tick, aloca um `Dictionary` por passo — por isso ela vive em `diagnostics()` e a checagem §5.7
  exige `dropped_ticks == 0` e `worst_sim_ms` na banda publicada. Nada aqui justifica alocar no
  passo e é exatamente o débito que o contrato declara sem medição (blackboard e difusão).
- **Como sei que ficou melhor — e o log existe em headless?** O número que decide é o que a
  checagem imprime: `componentes=`, `max_componente=`, `den_min_dist=` e a lista de lares por
  toca, na sessão real de boot e depois de 1 400 passos de fila, no mesmo harness de
  `_boot_session` ([`aether_reactions_test.gd:3125-3148`](../../tests/aether_reactions_test.gd#L3125-L3148)).
  Consequência de versão, escrita **antes** do código: `Channel.COUNT`
  ([`aether_field.gd:9`](../../src/world/aether_field.gd#L9)) e `FORMAT_VERSION`
  ([`tick_journal.gd:4`](../../src/persistence/tick_journal.gd#L4)) não são tocados, e a
  projeção do journal **não lê** lar, toca nem posição — ela lê `identity`, `mind.identity`,
  `mind.kind`, `intent` e crenças ordenadas
  ([`tick_journal.gd:14-42`](../../src/persistence/tick_journal.gd#L14-L42)). Mas uma corrida com
  três tocas **não reproduz** os hashes das rodadas publicadas, porque `intent` muda com o tamanho
  da matilha lida: menos vizinhos, mais `patrulhando` e menos `rondando setor da matilha`. O mundo
  projetado não mudou de forma; o que ele contém mudou.

## 5. Gate em headless

```sh
godot --headless --path . --check-only --script src/main.gd
godot --headless --path . --check-only --script src/entities/wolf.gd
godot --headless --path . --script tests/aether_reactions_test.gd
godot --headless --path . --script tests/simulation_rng_test.gd
godot --headless --path . tests/smoke_test.tscn
```

1. **`tocas_distintas_no_boot`** — nasce **vermelha** contra a arvore da pauta (`99d1167`): ali
   `_pack_leash()` ainda ancorava tudo no primeiro vivo, então os cinco lares cabiam em 18 m e o grafo tinha um componente. Critério: na sessão real
   de `WOLF_COUNT` lobos, `componentes >= DEN_COUNT`, `max_componente <= censo - 2` e
   `den_min_dist >= DEN_MIN_DIST`. Imprime a lista `loboN(tocaK, lar=(x,z))`.
2. **`nenhum_lobo_le_de_outra_toca`** — a anti-farsa: para cada lobo, nenhuma entrada de
   `pack_of()` com `den` diferente. Separação declarada sem separação lida é o mesmo defeito de
   "cinco lares espalhados que nunca foram território" (dossiê 10 §3.2), só que do outro lado.
3. **`cada_toca_e_um_lugar_valido`** — todo centro de toca passa por `_volume_clear` + coluna
   seca + `_spawn_point_ok` e nenhum dois centros partilham coluna
   ([`main.gd:809-821`](../../src/main.gd#L809-L821), [`:751-756`](../../src/main.gd#L756-L761)).
4. **`reposicao_volta_para_a_toca_perdida`** — mata um lobo da toca 2, esvazia a fila pela
   transição real (cadáver 1 s + 45 s, `:265-274` e `:674-684`, passos dados pelo `_sim_tick`
   como em [`aether_reactions_test.gd:3187-3194`](../../tests/aether_reactions_test.gd#L3187-L3194))
   e exige `novo.den == 2`, lar a ≤ `PACK_LEASH` do centro da toca 2 **e** a ≥ `DEN_MIN_DIST` dos
   centros das outras. Sem a segunda metade, a checagem passa com a regressão de hoje.
5. **`nascimento_fica_na_toca_dos_pais`** — dois adultos da mesma toca produzem cria com o mesmo
   `den` e lar dentro da mordaca daquela toca; e — o braço que a Âncora não deixa mentir — dois
   adultos de tocas **diferentes** encontrando-se a `< MATE_RADIUS` geram cria com o `den` do de
   identidade menor, nunca um lar fora de toda toca.
6. **`toca_nao_deriva_para_unica`** — decide o §3.4: 1 400 passos com as tocas fundadas, exigindo
   `componentes >= 2` em **todo** rebuild lido e o mínimo impresso. Vermelho aqui é o bilhete do
   braço B, não uma falha a esconder.
7. **`espalhamento_nao_estoura_o_passo`** — `sim_step` integral pareado (mesma cena, mesma
   semente, com e sem a perna) mais `worst_sim_ms` e `dropped_ticks == 0` no smoke. O número vai
   para o status com o log, porque a colocação roda no caminho raro e é justamente onde um custo
   se disfarça de grátis.
8. **`esgotamento_de_lares_forcado`** — o furo #18 pago aqui, e este dossiê assume o dono que o
   status ofereceu à 16 ou à 11 ([`melhorias-status.md:1169`](../melhorias-status.md#L1169)): o
   palco marca **todas** as colunas da caixa útil (116 × 116 ≈ 13 456 entradas, num fixture de
   teste, não no jogo) e exige `recusados == 8` com `soma(motivos) == tries × SPAWN_ATTEMPTS × 8`.
   Para `motivos` ser lido em número — hoje ele só é **interpolado na string impressa**
   ([`main.gd:792`](../../src/main.gd#L792), `:611-613`) — o dicionário de recusa devolve a chave
   `motivos`. A asserção `violacoes == 0` de
   [`:2769-2771`](../../tests/aether_reactions_test.gd#L2775-L2777) deixa de ser a única palavra.
9. **`toca_sobrevive_ao_save`** — save com três tocas → load devolve `den` e centros; e um save
   **sem** a chave (o disco anterior à perna) carrega com default derivado, sem inventar lobo nem
   perder censo, pelo mesmo padrão aditivo de fase/idade/`mate_cd`
   ([`wolf.gd:1124-1138`](../../src/entities/wolf.gd#L1124-L1138)). `load_leva_todo_o_censo`
   continua verde.
10. **`assinatura_de_populacao_estavel`** — lote == um-a-um == outra ordem, com as tocas no meio:
    é a checagem do `simulation_rng_test` §2.4, e 16 não escreve uma nova — ela **não pode quebrar**
    as três existentes. Se quebrar, a escolha de toca virou função da sequência de sorteios.
11. `EXPECTED_CHECKS` ([`aether_reactions_test.gd:39`](../../tests/aether_reactions_test.gd#L39),
    **225** nesta leitura), o censo do runner ([`:3096`](../../tests/aether_reactions_test.gd#L3102)),
    os 27 do `simulation_rng_test` ([`:9`](../../tests/simulation_rng_test.gd#L9)) e a última
    linha da suíte ([`smoke_test.gd:265`](../../tests/smoke_test.gd#L265), **252 / 0 / 43,0 s** na
    `main` `e0450a3`) sobem com o lote e são re-medidos no clone limpo com `--import` frio.

## 6. O que NÃO fazer

- **Não encostar `PACK_COHESION_RADIUS` nem `PACK_LEASH` para a checagem passar.** Os dois são o
  que a perna 10 e o furo #16 mediram; mexer neles para fingir separação é mover a régua, não o
  mundo. A separação é feita por **lar**, não por raio.
- **Não deixar a toca seguir o jogador.** Uma fundação em `player.position3()` reavaliada a cada
  spawn é o círculo único com nome novo (§3.2, item 5).
- **Não desenhar toca neste lote.** Nada de malha nova, `BlockDefs` novo, `PLANT`, nem prop: a
  perna 18 é quem gasta id e tile, e ela não é compradora disto. A toca que se vê é `[OPEN]`.
- **Não fazer a toca decidir comportamento por `if`.** A propriedade do mundo é que o grupo que o
  lobo **lê** decide a ronda (dossiê 10); a toca entra como **lugar**, e a pertença só muda o que
  o sorteio e o parto escrevem. Se aparecer um `if den == 2` em `wolf.gd`, o lote está errado.
- **Nenhum aviso na tela sobre tocas.** A perna 14 tirou os dois letreiros de criatura
  ([`main.gd:330-334`](../../src/main.gd#L330-L334)) e a regra continua: o jogador acha a matilha
  pelos rastros. A fala de fundação é log de headless (`print`), não `hud.show_message`.
- **Não subir `Channel.COUNT` nem `FORMAT_VERSION`** para "registrar a toca no Éter". Parentesco e
  pertença por canal é a decisão de versão do dossiê 13, e ela está guardada atrás do segundo
  comprador.
- **Não tocar em `player.gd`, `world_gen.gd` nem no formato de save que já existe.** `GEN_VERSION`
  ([`world_gen.gd:6`](../../src/world/world_gen.gd#L6)) não sobe: o terreno não muda, o que muda é
  onde a sessão põe um bicho.
- **Nada do Veloren** (código, asset, `.ron`, áudio) — mandato 8.

## 7. Commits atômicos

Branch `feat/tocas-da-alcateia-16`, base `main` no ponto atual, merge `--no-ff`, um assunto por
commit, suíte verde entre eles, número de cada corrida no commit a que ele responde:

(a) as checagens **1, 2 e 6** no runner, sem nenhuma mudança de código — nascem vermelhas com o
componente único impresso, e o `EXPECTED_CHECKS` sobe;
(b) `_dens` + `Wolf.den` + a escolha determinística de toca + portão `≥ DEN_MIN_DIST` na fundação,
com 1 verde, 2 e 3;
(c) fila carregando a toca e parto herdando-a (âncora trocada do médio para o centro da toca), com
4 e 5;
(d) `diagnostics()` com `dens` / `den_components` / `den_min_dist`, fechando o furo #21 com
número;
(e) `motivos` devolvido no dicionário de recusa + checagem 8 (furo #18 pago), com a asserção
antiga re-derivada;
(f) save aditivo com 9, e 10 conferida sem mudança;
(g) colheita de custo com 7, publicada no status;
(h) status + `docs/planos/README.md` + `AGENTS.md` + evidência em `docs/evidence/tocas-alcateia-16/`.

Se o braço B for convocado pela checagem 6, ele entra como commit ** próprio** (i), com as duas
linhas da perna 10 re-derivadas no mesmo commit — não dentro de (b), porque aí o vermelho deixaria
de responder por si.

## 8. O que este dossiê não fecha

Nenhum gate de fase (mandato 4). Não é arte de toca, não é ecologia de população (P2), não é
migração, não é mapa maior, não é a árvore genealógica (dossiê 13 — a pertença a um **lugar** não
é ascendência; a 13 escreve pais e isto escreve endereço), não é o Éter lendo toca, e não é a
lava contínua do jogador nem nada que já passou no gate dele.

Fica pago por esta página, com dono: o **furo #18** do status (recusa contada sem leitor), que
assumiu a 16 ou a 11 como donas — a 11 pousou sem mexer em `_spawn_home_point`, então o dono é
esta perna, pelo §5.8.

Fica aberto, e é novo, lido aqui: **furo #21** — `pack_pairs` conta **pares testados**
([`main.gd:899`](../../src/main.gd#L899)) e não arestas aceitas, então a asserção
`pack_pairs == n(n-1)/2` de [`smoke_test.gd:358`](../../tests/smoke_test.gd#L358) não decide nada
sobre coesão; o que decide é o `biggest >= 2` da mesma linha. O §5 fecha isso com um número de
componentes, mas a linha da suíte continua afirmando igualdade aritmética enquanto a perna não
pousar, e nada aqui deve ser lido como se tivesse consertado.

## 9. Invenções da pauta, registradas aqui

- **"espalhar a matilha em 2–3 tocas" como se tocas já existissem**: não existem. Zero ocorrências
  de `toca`/`den` em `src/` e `tests/` (§2.3). Não é "ligar a toca que está lá": é escrever o
  lugar, e a única peça existente é a **mordaca**, que faz o contrário dela — ajunta.
- **"o lobo vive numa toca" como comportamento**: o lobo hoje não tem vida de toca nenhuma; ele
  ronda o baricentro dos vizinhos que lê ([`wolf.gd:616-623`](../../src/entities/wolf.gd#L616-623))
  e não há retorno ao lar fora do resgate de corpo que caiu do mundo
  ([`wolf.gd:994-996`](../../src/entities/wolf.gd#L994-L996)). Prometer "ele volta para a toca
  dormir" seria escrever um comportamento sem comprador nenhum de §5.
- **"vi um lobo só" como sorte de semente**: não é. O círculo de 18 m é consequência de duas
  constantes ([`main.gd:788`](../../src/main.gd#L788), [`:543-547`](../../src/main.gd#L548-L552)),
  e vale para toda semente; a semente muda **onde** é o círculo, nunca o tamanho dele. Isso é o que
  a checagem 1 pode exigir sem depender de sorte.
- **"colocar os lobos longe do jogador" como o pedido**: longe é a perna 14 e já está gateado
  (`SAFE_SPAWN_DIST` + visada). O que a 16 acrescenta é **entre eles**, e o portão novo não pode
  comprar segurança: cada toca continua passando pelo predicado do jogador inteiro
  ([`main.gd:756-761`](../../src/main.gd#L756-L761)).
