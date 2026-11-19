# 09 — Mecânicas do Veloren adaptadas

Veloren é a referência mais próxima do que este projeto quer ser: voxel infinito, corpo
móvel com inércia, mundo habitado por criaturas que caçam e fogem. Ele é **GPL-3.0 no
código e CC-BY-SA-4.0 nos assets** — verificado em §08. Este documento existe para deixar
registrado *o que* foi tomado de lá e *de onde* veio cada número nosso:

- **Coluna Veloren** = descrição de comportamento, marcada
  `[CLAIMED: wiki.veloren.net — Getting Started]`. Não abrimos o código deles, e não
  precisamos: idéias e sistemas não são obra protegida; expressão sim.
- **Coluna Aetherfall** = derivada do código deste repositório, com `arquivo:linha` e a
  constante real. Nada aqui é alvo de design disfarçado de implemented: o que não existe
  está na §9, marcado `[TARGET]` ou "não adaptado".

**Zero derivação**: nenhuma linha de Rust, nenhum `.ron`, nenhum mesh, nenhum nome de
arquivo de dados deles. Ver §08 "Licenças".

## 1. Corpo e locomoção

| Ação | Veloren `[CLAIMED]` | Aetherfall (código) |
|---|---|---|
| Andar | `Shift`/analógico, velocidade por espécie | `WALK_SPEED = 4,3 m/s` [player.gd:31](../../src/entities/player.gd); corpo `0,62 × 1,80 × 0,62` [player.gd:24](../../src/entities/player.gd) |
| Correr | `Shift`, drena vigor | `SPRINT_SPEED = 6,9` [player.gd:32](../../src/entities/player.gd), dreno `8,0/s` [player.gd:47](../../src/entities/player.gd) |
| Agachar | `Ctrl`, entra em buraco de 1 bloco, anda devagar | `CROUCH_SPEED = 2,1` [player.gd:33](../../src/entities/player.gd), corpo agachado `0,62 × 1,15 × 0,62` [player.gd:25](../../src/entities/player.gd), olho `1,62 → 0,98` [player.gd:26-27](../../src/entities/player.gd) |
| Pular | `Space` | `JUMP_SPEED = 8,2 m/s` [player.gd:37](../../src/entities/player.gd), coyote `0,12 s` [player.gd:39](../../src/entities/player.gd) e buffer `0,15 s` [player.gd:40](../../src/entities/player.gd) |
| Nadar | `Space` bate-perna, afunda sem ele | subida `3,6 m/s` [player.gd:38](../../src/entities/player.gd); empuxo e remada também no lobo (§8) |
| Planar | `Ctrl` no ar com capa/kit de voo, `Space` para sair | segurar `Ctrl` no ar [player.gd:489-491](../../src/entities/player.gd): afundo `1,8 m/s`, gravidade `0,16` do normal [player.gd:65-66](../../src/entities/player.gd), mergulho olhando para baixo ganha `5,0 m/s` de horizontal até `11,5` e afunda `4,8` [player.gd:60-67](../../src/entities/player.gd), estol a `2,4` [player.gd:62](../../src/entities/player.gd) |
| Rolamento | botão do meio, atravessa golpe | botão do meio [input_actions.gd](../../src/input/input_actions.gd): custo `14` de vigor, `10,5 m/s` por `0,35 s`, invencibilidade `0,45 s`, recarga `0,9 s`, buffer `0,18 s` [player.gd:52-57](../../src/entities/player.gd) |
| Escalada | `Space` contra parede, drena vigor | **não adaptado** `[TARGET]` (§9) |

Aceleramos no chão com `46 m/s²` e no ar com `11 m/s²`, com atrito `13`
[player.gd:34-36](../../src/entities/player.gd). No ar não há teto horizontal: a velocidade
só converge para a mesma meta do solo (`6,9` correndo) [player.gd:462-470](../../src/entities/player.gd),
e a queda para em `42 m/s` [voxel_body.gd:6,39-40](../../src/entities/voxel_body.gd) —
números nossos, escolhidos por sensação medida nos probes de câmera, não copiados de lá.

`Ctrl` é a mesma tecla de agachar e de planar, como no Veloren: no chão é agachar, caindo
é planar [input_actions.gd:25,28](../../src/input/input_actions.gd).

## 2. Vigor

Veloren tem *vigor* (stamina): corrida e voo gastam, golpes básicos recuperam, sem vigor
não se corre [CLAIMED]. Aqui:

- teto `100` [player.gd:45,119](../../src/entities/player.gd);
- corrida no chão drena `8/s`, e fora dela o vigor recupera `12/s`
  [player.gd:46-47,520-528](../../src/entities/player.gd);
- golpe que acerta **devolve** `6` [player.gd:49,635](../../src/entities/player.gd) — a
  mesma economia do ataque básico deles;
- rolamento custa `14` fixo [player.gd:52](../../src/entities/player.gd);
- zerou, a corrida trava (`_sprint_locked`) e só volta quando o vigor subir de novo aos
  `18` [player.gd:48,527-528](../../src/entities/player.gd) — `18` é soleira de
  reentrada, não taxa de recuperação;
- planar **não** gasta vigor no nosso slice `[DECIDED]`: é o que permite o loop de queda
  alto sem transformar travessia em contagem de segundos.

## 3. Combate corpo-a-corpo

Eles têm combo `LMB`+`RMB`, bloqueio/parry com `Left Alt`, *poise* (resistência a
interromper), habilidades por tipo de arma, arcos, cetros `[CLAIMED]`. O nosso slice tem
um golpe só, e é honesto sobre isso:

| Item | Aetherfall |
|---|---|
| Dano | `14` [player.gd:41](../../src/entities/player.gd) |
| Recarga | `0,42 s` [player.gd:631](../../src/entities/player.gd) |
| Alcance | `5,5 m` medidos do corpo, mira saindo do olho em 1ª pessoa e da câmera em 3ª [player.gd:28,582-608](../../src/entities/player.gd) — o alcance no corpo é a mesma decisão do `aim_point` deles |
| Recuo de câmera no golpe | `_punch` `+0,10` limitado a `0,5` [player.gd:632](../../src/entities/player.gd), aplicado só em 1ª pessoa [player.gd:710-711](../../src/entities/player.gd) |
| Arco visível do golpe | view model de 1ª pessoa: ombro `+0,30` no arma e `-0,15` no corte, cotovelo `+0,30`/`-0,45`, punho `+0,05 m`→`-0,10 m` ao longo do eixo da lente [fp_viewmodel.gd:130-153](../../src/entities/fp_viewmodel.gd); o mesmo impulso gira também o rig de 3ª pessoa [player.gd:206-210](../../src/entities/player.gd) |
| Alvo vivo vs. bloco | o raio testa entidades antes do voxel: mira em criatura não lavra [player.gd:592-608](../../src/entities/player.gd) |
| Efeito no lobo | `5,0` de empurrada horizontal + `2,4` vertical e `0,45 s` sem steering [wolf.gd:45-47](../../src/entities/wolf.gd#L45-L47), [:575-586](../../src/entities/wolf.gd#L575-L586); a inspeção é suspensa e seu timer zerado durante o atordoamento [:248-254](../../src/entities/wolf.gd#L248-L254) |

Bloqueio, parry, combos, *poise* e dano por arma: **não adaptados** (§9).

## 4. Lavrar e construir

Eles exigem ferramenta por minério e dão XP de mineração `[CLAIMED]`. Aqui a dureza é do
bloco, sem ferramenta e sem XP:

- `STONE 0,95 · WOOD 0,55 · GRASS 0,38 · DIRT 0,35 · SAND 0,30 · SNOW 0,25 · LEAVES 0,22`,
  padrão `0,4`. A tabela é o registro de blocos, não do jogador
  ([block_defs.gd:93,114-122](../../src/world/block_defs.gd)); o `Player` pergunta
  `BlockDefs.hardness()` [player.gd:611](../../src/entities/player.gd). Os materiais de
  craft do documento 11 já chegam com dureza própria (bruta `0,85` · tabua `0,45` ·
  bancada `0,50` · vidro `0,10`);
- o acumulador anda em segundos reais: `≈1 s` por unidade de dureza, então pedra leva
  `0,95 s` e folha `0,22 s` [player.gd:637-640](../../src/entities/player.gd);
- progresso por voxel guardado ao trocar de alvo [player.gd:619-623](../../src/entities/player.gd);
- colocar bloco: buffer de `0,22 s`, recarga `0,16 s`, recusa se o bloco cair dentro do
  próprio corpo [player.gd:43,680-683](../../src/entities/player.gd);
- **lava tem drop e o drop tem número**: o que sai do mundo é o que o registro diz
  (pedra → bruta, grama → terra, folha → nada)
  [block_defs.gd:140-144](../../src/world/block_defs.gd), e entra como **1 item** no
  inventário — que recusou antes, quando não havia onde pôr
  [player.gd:652-665](../../src/entities/player.gd);
- inventário de 36 slots com pilha por bloco, e a hotbar são **10 teclas** (`1-9,0`)
  pinadas nesses slots, não um depósito separado
  [inventory.gd:24-33](../../src/items/inventory.gd),
  [input_actions.gd:6-15](../../src/input/input_actions.gd). O resto da mecânica —
  quantidade, teto por bloco, partir, craft — está no
  [documento 11](11-inventory-crafting.md).

Cada bloco lavrado injeta **0,42 no canal de trabalho** do Éter e cada colocação `0,20`
[main.gd:268-273](../../src/main.gd#L268-L273) — nada disso existe no Veloren; é a nossa trilha
auditável (§8).

## 5. Respiração e afogamento

Ar `14 s` [player.gd:70](../../src/entities/player.gd), `7` de dano por período de `1 s`
sob água [player.gd:72-73,547-559](../../src/entities/player.gd), e recarga de `14/s` ao
emergir — ou seja, ~1 s para encher, como emergir neles `[CLAIMED]`.

## 6. Queda

Impacto acima de `14 m/s` machuca: `3,5` de dano por `m/s` excedente, teto de `55`
[player.gd:74-77,567-573](../../src/entities/player.gd). Água perdoa e planar nunca chega
à velocidade de corte. Sem queda no Veloren? Não — eles têm dano de queda; os números são
nossos.

## 7. Regeneração fora de combate

`8 s` sem dano, exigindo vigor acima de `25`, regenerando `1,2 hp/s`
[player.gd:79-81,576-579](../../src/entities/player.gd). Comida e poção como fonte de cura
são **não adaptadas** (§9).

## 8. Criaturas: o que virou comportamento

O lobo deles caça, persegue e foge quando ferido `[CLAIMED]`. O nosso tem a mesma
superfície de comportamento por uma rota diferente — utilidade escolhe a intenção, a
árvore executa, a memória veta:

- intenções `patrol / hunt / investigate / flee` escolhidas pelo `UtilityScorer`
  [wolf.gd:352-403](../../src/entities/wolf.gd#L352-L403);
- árvore: `fugir → caçar[morder | perseguir presa visível | último avistamento] → investigar →
  patrulhar`, sob um `SubtreeGuard` de 400 µs (só a árvore, não a percepção/utilidade)
  [wolf.gd:146-174](../../src/entities/wolf.gd#L146-L174);
- memória episódica de `24` átomos, crenças decaem `0,14/min`, descarte abaixo de `0,02`
  [mind.gd:7-9](../../src/ai/mind.gd#L7-L9), [:108-119](../../src/ai/mind.gd#L108-L119).
  O veto à caça exige crença `danger_from_actor_1` utilizável (`>= 0,35`) e HP abaixo
  de `0,62` do máximo [mind.gd:104-105](../../src/ai/mind.gd#L104-L105),
  [wolf.gd:448-451](../../src/entities/wolf.gd#L448-L451);
- HP `42`, mordida `8,5` a `1,95 m` com recarga `1,15 s`, raio de patrulha `22 m`
  [wolf.gd:19-26](../../src/entities/wolf.gd#L19-L26);
- água: patrulha sorteia terra seca; se acabar nela, boia/rema e, após `2 s`, consulta
  a margem [wolf.gd:39-43](../../src/entities/wolf.gd#L39-L43),
  [:296-335](../../src/entities/wolf.gd#L296-L335), [:419-427](../../src/entities/wolf.gd#L419-L427),
  [:509-515](../../src/entities/wolf.gd#L509-L515).

**Rastro: aproxima → para → registra → suprime → renova.** O leitor varre `7 × 7`
células na camada Y atual do Éter (raio `3`), a cada `0,25 s`, com novo scan no tick
seguinte à inspeção concluída. Seleciona o maior `BLOOD + 0,35 × WORK`, exigindo valor
`> 0,06`; o canal nomeado é o maior dos dois componentes ponderados
([wolf.gd:27-34](../../src/entities/wolf.gd#L27-L34),
[:461-496](../../src/entities/wolf.gd#L461-L496)).

A folha aproxima até `1,2 m` horizontais do alvo e então para o corpo para farejar por
`2 s` de `dt`. Aproximação e inspeção retornam `RUNNING`, sem cair em patrulha no mesmo
tick; só ao concluir retorna `SUCCESS` e grava `scent_blood` ou `scent_work`, com
**ator 0**, sem atribuir o rastro ao jogador
([wolf.gd:248-281](../../src/entities/wolf.gd#L248-L281)). A visita guarda a força
ponderada da vizinhança `3 × 3`, na mesma camada, num cache por lobo de até `32` células
por `30 s`; a borda difusa também é suprimida. Antes da expiração, um aumento de pelo
menos `0,06` **na soma ponderada** reabre a célula; a expiração é recolhida no scan e
permite revisita mesmo sem imprint novo
([wolf.gd:279-293](../../src/entities/wolf.gd#L279-L293),
[:462-493](../../src/entities/wolf.gd#L462-L493)). Não é identificação de uma causa nova.
Trocar de alvo, perder o rastro ou sair de `investigate` zera a inspeção; durante
`stagger`, a folha suspende a inspeção e zera seu timer, sem concluir episódio
([wolf.gd:248-262](../../src/entities/wolf.gd#L248-L262),
[:430-432](../../src/entities/wolf.gd#L430-L432), [:488-489](../../src/entities/wolf.gd#L488-L489)).
O load limpa cache e estado transitório de inspeção
([wolf.gd:649-670](../../src/entities/wolf.gd#L649-L670)).

**Perigo percebido, não coordenada oculta como rumo.** A fuga usa o jogador visível;
sem visão, usa a posição do último `hurt` enquanto há ameaça recente; sem isso, usa o
vetor de afastamento do FEAR vizinho (ou o rumo oposto ao atual se o vetor for quase nulo).
Só a ameaça de golpe autoriza reimprimir medo durante a fuga, evitando realimentação
por medo alheio ([wolf.gd:204-223](../../src/entities/wolf.gd#L204-L223),
[:472-480](../../src/entities/wolf.gd#L472-L480), [:575-591](../../src/entities/wolf.gd#L575-L591)).
A caça exige jogador vivo e visão real ou episódio `saw_player` de até `6 s`, ainda
não consumido pela chegada ao último local visto. A condição da própria busca também
exige jogador vivo, mesmo se a histerese mantiver `intent = hunt`; a distância sem visão
é a do episódio, não a da posição oculta
([wolf.gd:185-195](../../src/entities/wolf.gd#L185-L195),
[:226-245](../../src/entities/wolf.gd#L226-L245), [:368-382](../../src/entities/wolf.gd#L368-L382)).
A LOS é consultada a cada tick quando o jogador está vivo e a menos de `30 m`; o registro
de avistamento tem intervalo de `2 s`
([wolf.gd:435-458](../../src/entities/wolf.gd#L435-L458)).

**Limites.** O refinamento de produção está somente em `Wolf`: `AetherField` permanece
com **3 canais**, mesmas meias-vidas e difusão
([aether_field.gd:9-17](../../src/world/aether_field.gd#L9-L17)). O leitor é horizontal,
embora o campo seja 3D; o destino usa a altura de superfície da coluna, não pathfinding
nem prova de alcançabilidade ([wolf.gd:494-496](../../src/entities/wolf.gd#L494-L496)).
Inspeção não atribui autoria/causalidade, e cache transitório e episódios não fazem
parte da projeção mínima do journal: não há replay deste ciclo. O contrato e as
execuções históricas do journal estão nas [notas do status](../melhorias-status.md#notas-de-medição),
não são validação automática deste refinamento.

A decisão roda no tick de 20 Hz (`sim_step`), mas corpo e timers de cadáver,
atordoamento e desvio mudam por frame em `_physics_process`
([wolf.gd:408-432](../../src/entities/wolf.gd#L408-L432),
[:501-546](../../src/entities/wolf.gd#L501-L546)); não é simulação inteira a 20 Hz.
O F3 inclui reação, canal/força/célula escolhidos, tamanho do cache e custo do BT
([wolf.gd:629-638](../../src/entities/wolf.gd#L629-L638)).

## 9. Não adaptado — lista explícita

Nada aqui está em código — menos as linhas que o
[documento 11](11-inventory-crafting.md) já pagou, marcadas em cada caso. Cada uma é
`[TARGET]` com destino, ou rejeitada:

| Mecânica Veloren `[CLAIMED]` | Situação aqui |
|---|---|
| Estações de craft (bigorna, caldeirão, tear, forja) e receitas por pergaminho | em parte: **uma** estação existe — a bancada, um bloco casado por distância como o sprite do Veloren — com quatro receitas em lista (§4 do doc 11). Pergaminho de conhecimento e estações de calor continuam `[TARGET]` P6 |
| Ferramenta por minério + XP de mineração e árvore de habilidades | `[TARGET]` P6; a dureza atual é absoluta (§4) |
| Armaduras com raridade e bolsas que acrescente slots | `[TARGET]` P6; a **grade** saiu do "não adaptado": 36 slots com pilha por bloco e 10 pinos de hotbar existem no doc 11 |
| Comida, buff de comida, fogueira que cura | **não adaptado** — cura aqui é regeneração por tempo (§7) |
| Domesticar com coleira, montaria em `F` | `[TARGET]` P3 — depende de mentes aliadas, não de item |
| Mercadores (`T`) em cidades, economia de aldeia | `[TARGET]` P2 (`SlowSim`) |
| Missões/contratos | `[TARGET]` P6, geradas pelo `EchoLedger` (§05) |
| Bloqueio, parry, *poise*, combos, habilidades de arma | `[TARGET]` P6 — combate de 1 golpe só (§3) |
| Arcos, lanças arremessadas, cetros e magia de projétil | `[TARGET]` P6; magia existe como **Tecelagem** editando o Éter (§02), não como cast bar |
| 6 espécies, personagens, opção *hardcore* | fora de escopo — solo humano + mentes locais (premissa 3 do README) |
| Multiplayer | `[TARGET]` P5 |
| Ciclo dia/noite e clima | **não existe no código**: a luz é uma `DirectionalLight3D` estática [main.gd:451-459](../../src/main.gd#L451-L459). `[TARGET]` P7 |
| Agricultura/plantação | **não existe no código**: só `_plant_tree` no gerador. `[TARGET]` P7 |

O que **não** existe no Veloren e é o centro daqui: o Éter como substrato físico de
memória (células que difuem e decaem, legíveis por criatura e pelo jogador com `B`)
[aether_field.gd:108-146](../../src/world/aether_field.gd), e a mente local que consome
esse rastro. Essa inversão é a inovação §02, não uma adaptação.

## 10. Teclas hoje

`WASD` mover · `Space` pular/nadar · `Shift` correr · `Ctrl` agachar/planar ·
`LMB` lavrar/golpear · `RMB` construir · `MMB` rolamento · `1-9,0` pinos da hotbar ·
`I` inventário e craft (por dentro dele: `WASD` cursor, `E` pegar/soltar, `Q` partir,
`1-9,0` repinar, `TAB` receita, `ENTER` craftar) · `V` câmera
1ª/3ª · `B` visão do Éter · `R` renascer · `F5/F9` salvar/carregar · `F3` debug ·
`F2` binds · `Esc` soltar cursor (e fechar o painel)
[actions](../../src/input/input_actions.gd).

## 11. Como validar

```
godot --headless --path . tests/smoke_test.tscn
```

Os passos que cobrem este documento, por nome na suíte: `minerar e colocar`,
`colocar com clique`, `guarda de colocacao`, `construir enquanto lava`,
`tecla 3 no hotbar`, `inventario, pilhas e receitas`, `hud, morte e renascer`,
`salvar e carregar`, `sistema de coordenadas`, `golpe no lobo: dano e empurrada`,
`rolamento e invencibilidade`, `vigor: dreno, recupero e trava`, `planar e queda`,
`respiracao e afogamento`, `regeneracao fora de combate`, `lobo nada e busca margem`,
`corpo encaixado se solta` (resgate do integrador) e `relogio real`, onde mora o
gate `steering e colisao movem o lobo`, `memoria muda comportamento`
[smoke_test.gd:63-95](../../tests/smoke_test.gd). A contagem de checagens e o tempo são
publicados no [`README.md`](../../README.md) da raiz, derivados da corrida — não deste
documento.

O runner específico `tests/aether_reactions_test.gd` cobre aproximação, pesos dos rastros,
inspeção/renovação, expiração do cache, difusão, fuga por FEAR/último golpe, perda de visão,
expiração do avistamento, presa morta e golpe durante inspeção
([aether_reactions_test.gd:7-14](../../tests/aether_reactions_test.gd#L7-L14)). Ele usa
uma semente e **um lobo por cenário**, com decisão a 20 Hz e corpo a 60 Hz controlados;
o campo é estático por padrão, com difusão explícita no cenário dedicado
([:91-121](../../tests/aether_reactions_test.gd#L91-L121),
[:329-374](../../tests/aether_reactions_test.gd#L329-L374)).

A colheita cronometra `sim_step` integral e lê `_guard.last_us`/`trips`, imprimindo
soma/pico de ambos e estouros do guard
([:104-121](../../tests/aether_reactions_test.gd#L104-L121),
[:640-641](../../tests/aether_reactions_test.gd#L640-L641)). O guard mede só BT, não
percepção/utilidade; `sim_step` não inclui a física executada depois pelo runner.
Isso não é medição do HOT agregado de cinco lobos, teste multi-semente ou replay, nem
fecha P1. O candidato local passou nas 89 checagens específicas e nas regressões de
hash/smoke; manifesto e logs nas [notas de rastros](../melhorias-status.md#rastros-e-reações--candidato-local-de-2026-11-18).
Movimento e parada foram medidos em headless; não houve aprovação visual em janela.
