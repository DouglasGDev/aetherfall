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
| Andar | `Shift`/analógico, velocidade por espécie | `WALK_SPEED = 4,3 m/s` [player.gd:24](../../src/entities/player.gd); corpo `0,62 × 1,80 × 0,62` [player.gd:17](../../src/entities/player.gd) |
| Correr | `Shift`, drena vigor | `SPRINT_SPEED = 6,9` [player.gd:25](../../src/entities/player.gd), dreno `8,0/s` [player.gd:40](../../src/entities/player.gd) |
| Agachar | `Ctrl`, entra em buraco de 1 bloco, anda devagar | `CROUCH_SPEED = 2,1` [player.gd:26](../../src/entities/player.gd), corpo agachado `0,62 × 1,15 × 0,62` [player.gd:18](../../src/entities/player.gd), olho `1,62 → 0,98` [player.gd:19-20](../../src/entities/player.gd) |
| Pular | `Space` | `JUMP_SPEED = 8,2 m/s` [player.gd:30](../../src/entities/player.gd), coyote `0,12 s` [player.gd:32](../../src/entities/player.gd) e buffer `0,15 s` [player.gd:33](../../src/entities/player.gd) |
| Nadar | `Space` bate-perna, afunda sem ele | subida `3,6 m/s` [player.gd:31](../../src/entities/player.gd); empuxo e remada também no lobo (§8) |
| Planar | `Ctrl` no ar com capa/kit de voo, `Space` para sair | segurar `Ctrl` no ar [player.gd:408-420](../../src/entities/player.gd): afundo `1,8 m/s`, gravidade `0,16` do normal [player.gd:58-59](../../src/entities/player.gd), mergulho olhando para baixo ganha `5,0 m/s` de horizontal até `11,5` e afunda `4,8` [player.gd:54-60](../../src/entities/player.gd), estol a `2,4` [player.gd:55](../../src/entities/player.gd) |
| Rolamento | botão do meio, atravessa golpe | botão do meio [input_actions.gd](../../src/input/input_actions.gd): custo `14` de vigor, `10,5 m/s` por `0,35 s`, invencibilidade `0,45 s`, recarga `0,9 s`, buffer `0,18 s` [player.gd:45-50](../../src/entities/player.gd) |
| Escalada | `Space` contra parede, drena vigor | **não adaptado** `[TARGET]` (§9) |

Aceleramos no chão com `46 m/s²` e no ar com `11 m/s²`, com atrito `13`
[player.gd:27-29](../../src/entities/player.gd) e teto de `14 m/s` no ar
[player.gd:63](../../src/entities/player.gd) — números nossos, escolhidos por sensação
medida nos probes de câmera, não copiados de lá.

`Ctrl` é a mesma tecla de agachar e de planar, como no Veloren: no chão é agachar, caindo
é planar [input_actions.gd:19-22](../../src/input/input_actions.gd).

## 2. Vigor

Veloren tem *vigor* (stamina): corrida e voo gastam, golpes básicos recuperam, sem vigor
não se corre [CLAIMED]. Aqui:

- teto `100` [player.gd:38](../../src/entities/player.gd);
- corrida no chão drena `8/s`, e fora dela o vigor recupera `12/s`
  [player.gd:39-40,438-446](../../src/entities/player.gd);
- golpe que acerta **devolve** `6` [player.gd:42,564](../../src/entities/player.gd) — a
  mesma economia do ataque básico deles;
- rolamento custa `14` fixo [player.gd:45](../../src/entities/player.gd);
- zerou, a corrida trava (`_sprint_locked`) e só volta quando o vigor subir de novo aos
  `18` [player.gd:41,441-445](../../src/entities/player.gd) — `18` é soleira de
  reentrada, não taxa de recuperação;
- planar **não** gasta vigor no nosso slice `[DECIDED]`: é o que permite o loop de queda
  alto sem transformar travessia em contagem de segundos.

## 3. Combate corpo-a-corpo

Eles têm combo `LMB`+`RMB`, bloqueio/parry com `Left Alt`, *poise* (resistência a
interromper), habilidades por tipo de arma, arcos, cetros `[CLAIMED]`. O nosso slice tem
um golpe só, e é honesto sobre isso:

| Item | Aetherfall |
|---|---|
| Dano | `14` [player.gd:34](../../src/entities/player.gd) |
| Recarga | `0,42 s` [player.gd:560](../../src/entities/player.gd) |
| Alcance | `5,5 m` medidos do corpo, mira saindo da câmera em 3ª pessoa [player.gd:21,500-534](../../src/entities/player.gd) — o alcance no corpo é a mesma decisão do `aim_point` deles |
| Recuo de câmera no golpe | `_punch` `+0,10` limitado a `0,5` [player.gd:561](../../src/entities/player.gd), só em 1ª pessoa [player.gd:605-620](../../src/entities/player.gd) |
| Alvo vivo vs. bloco | o raio testa entidades antes do voxel: mira em criatura não lavra [player.gd:512-526](../../src/entities/player.gd) |
| Efeito no lobo | `8,5` de empurrada horizontal + `2,4` vertical e `0,45 s` sem steering [wolf.gd:39-41,463-476](../../src/entities/wolf.gd) |

Bloqueio, parry, combos, *poise* e dano por arma: **não adaptados** (§9).

## 4. Lavrar e construir

Eles exigem ferramenta por minério e dão XP de mineração `[CLAIMED]`. Aqui a dureza é do
bloco, sem ferramenta e sem XP:

- `STONE 0,95 · WOOD 0,55 · GRASS 0,38 · DIRT 0,35 · SAND 0,30 · SNOW 0,25 · LEAVES 0,22`,
  padrão `0,4`. A tabela é o registro de blocos, não do jogador
  ([block_defs.gd:93,114-122](../../src/world/block_defs.gd)); o `Player` pergunta
  `BlockDefs.hardness()` [player.gd:587](../../src/entities/player.gd). Os materiais de
  craft do documento 11 já chegam com dureza própria (bruta `0,85` · tabua `0,45` ·
  bancada `0,50` · vidro `0,10`);
- o acumulador anda em segundos reais: `≈1 s` por unidade de dureza, então pedra leva
  `0,95 s` e folha `0,22 s` [player.gd:605-616](../../src/entities/player.gd);
- progresso por voxel guardado ao trocar de alvo [player.gd:595-599](../../src/entities/player.gd);
- colocar bloco: buffer de `0,22 s`, recarga `0,16 s`, recusa se o bloco cair dentro do
  próprio corpo [player.gd:41,619-621,659](../../src/entities/player.gd);
- **lava tem drop e o drop tem número**: o que sai do mundo é o que o registro diz
  (pedra → bruta, grama → terra, folha → nada)
  [block_defs.gd:140-144](../../src/world/block_defs.gd), e entra como **1 item** no
  inventário — que recusou antes, quando não havia onde pôr
  [player.gd:628-641](../../src/entities/player.gd);
- inventário de 36 slots com pilha por bloco, e a hotbar são **10 teclas** (`1-9,0`)
  pinadas nesses slots, não um depósito separado
  [inventory.gd:24-33](../../src/items/inventory.gd),
  [input_actions.gd:6-15](../../src/input/input_actions.gd). O resto da mecânica —
  quantidade, teto por bloco, partir, craft — está no
  [documento 11](11-inventory-crafting.md).

Cada bloco lavrado injeta **0,42 no canal de trabalho** do Éter e cada colocação `0,20`
[main.gd:226-228](../../src/main.gd) — nada disso existe no Veloren; é a nossa trilha
auditável (§8).

## 5. Respiração e afogamento

Ar `14 s` [player.gd:63](../../src/entities/player.gd), `7` de dano por período de `1 s`
sob água [player.gd:65-66,465-483](../../src/entities/player.gd), e recarga de `14/s` ao
emergir — ou seja, ~1 s para encher, como emergir neles `[CLAIMED]`.

## 6. Queda

Impacto acima de `14 m/s` machuca: `3,5` de dano por `m/s` excedente, teto de `55`
[player.gd:68-70,485-492](../../src/entities/player.gd). Água perdoa e planar nunca chega
à velocidade de corte. Sem queda no Veloren? Não — eles têm dano de queda; os números são
nossos.

## 7. Regeneração fora de combate

`8 s` sem dano, exigindo vigor acima de `25`, regenerando `1,2 hp/s`
[player.gd:72-74,494-498](../../src/entities/player.gd). Comida e poção como fonte de cura
são **não adaptadas** (§9).

## 8. Criaturas: o que virou comportamento

O lobo deles caça, persegue e foge quando ferido `[CLAIMED]`. O nosso tem a mesma
superfície de comportamento por uma rota diferente — utilidade escolhe a intenção, a
árvore executa, a memória veta:

- intenções `patrol / hunt / investigate / flee` escolhidas pelo
  `UtilityScorer` [wolf.gd:313](../../src/entities/wolf.gd);
- árvore: `fugir → caçar[morder | ir ao último avistamento | perseguir] → seguir rastro →
  patrulhar`, sob um `SubtreeGuard` de 400 operações
  [wolf.gd:129-157](../../src/entities/wolf.gd);
- percepção pelo **Éter**, não por linha de visão só: varre `3` células de raio e ignora
  abaixo de `0,06` [wolf.gd:27-28](../../src/entities/wolf.gd);
- memória episódica de `24` átomos, crenças decaem `0,14/min`, soleira de uso `0,02`
  [mind.gd:7-9](../../src/ai/mind.gd); uma derrota registrada **veta** a caçada
  (check `memoria muda comportamento` na suíte);
- HP `42`, mordida `8,5` a `1,95 m` com recarga `1,15 s`, raio de patrulha `22 m`
  [wolf.gd:19-26](../../src/entities/wolf.gd);
- água: patrulha sorteia terra seca; se acabar nela, boia, rema e procura a margem em
  `2 s` [wolf.gd:31-37](../../src/entities/wolf.gd).

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
| Ciclo dia/noite e clima | **não existe no código**: a luz é uma `DirectionalLight3D` estática [main.gd:367](../../src/main.gd). `[TARGET]` P7 |
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
