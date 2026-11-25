# 19 — Pulo de bloco: o degrau de 1 m que ninguém sobe

Dossiê de **leitura de código**, escrito a pedido do dono em 2026-11-21, na própria conversa, como
defeito urgente: *"os mobs/npcs tem que saber pular os blocos, pois ficam bugados e aqui tbm fazer
quando estou andando, ter uma auto pular o bloco"*. O registro vem **antes** de qualquer linha de
código, como exige o mandato 4 de [`AGENTS.md`](../../AGENTS.md). Números de `arquivo:linha` desta
página são da `main` em `8ac761d`.

Nada aqui reabre gate de fase, e nenhuma das peças nomeadas é invenção de fato: o conserto é duas
linhas de regra sobre um integrador que já existe.

## 1. Premissa nomeada

**Um corpo que anda contra um degrau de exatamente um bloco sobe o degrau — o do jogador porque o
mundo o empurra para cima sem tecla nenhuma, o do lobo porque o salto que ele já dá tem altura
para isso — e um corpo que anda contra uma parede mais alta que um bloco não gasta salto.**
Falsificável em headless, sem janela: montar a coluna à mão (`set_block`), chamar
`_physics_process` um número fixo de vezes e exigir `feet_pos.y` uma unidade acima no fim.

Os dois sentidos que o ciclo de trabalho (item 3) exige:

- **braço vermelho de origem**: com o código de hoje, o mesmo cenário não sobe. Isso é aritmética
  do código, não opinião — ver §2;
- **braço de indiferença**: com a parede de 6 blocos do cenário que já existe
  ([`aether_reactions_test.gd:1146`](../../tests/aether_reactions_test.gd#L1146)), o corpo **não**
  é lançado para cima, e ainda assim re-arma o desvio. Sem esse lado, a checagem verde estaria
  afirmando apenas que atiramos o corpo para o alto sempre que ele encosta em alguma coisa.

## 2. Estado real do código (lido, não medido)

**O grid tem célula de 1 unidade de mundo**, e nada no mundo tem altura intermediária: o teste de
colisão percorre as células cobertas pela caixa com `floori` em cada eixo
([voxel_world.gd:410-421](../../src/world/voxel_world.gd#L410-L421)), e a conversão contínua→bloco é
o mesmo `floori` ([coords.gd:21-22](../../src/world/coords.gd#L21-L22)). Então "subir um bloco" é
**subir 1,00 m**, e essa é a régua contra a qual os três números abaixo falham.

- **`step_up` não alcança um bloco.** O integrador faz auto step-up: em colisão horizontal, com pé
  no chão, ele ergue o corpo por `step_up` e repete o teste
  ([voxel_body.gd:89-97](../../src/entities/voxel_body.gd#L89-L97)). O valor é **0,62**
  ([`:19`](../../src/entities/voxel_body.gd#L19)). Contra um bloco de 1,00 m isso nunca limpa o
  degrau: com o pé na cota do solo e o obstáculo ocupando a célula inteira de 1 m acima, erguer
  0,62 deixa a caixa ainda sobreposta à célula sólida, o teste refeito continua batendo, e o corpo
  cai no ramo de bloqueio, que zera a velocidade daquele eixo
  ([`:98-105`](../../src/entities/voxel_body.gd#L98-L105)). Não há spec nenhuma para 0,62: grep de
  `step-up`, `degrau` e `0,6 m` em `docs/design/` devolve **zero** ocorrências. É constante de
  implementação, não promessa de design.
- **O lobo salta baixo demais para o degrau.** Quando o integrador chama bloqueio horizontal e o
  desvio expirou, o passo sorteia um novo desvio **e** dá um impulso vertical de **5,2 m/s** se
  estava apoiado ([wolf.gd:840-844](../../src/entities/wolf.gd#L840-L844) — o literal está em
  `:844`). A gravidade é a default do integrador, 24,0
  ([voxel_body.gd:17](../../src/entities/voxel_body.gd#L17)), e os dois corpos a usam com fator 1
  fora d'água ([player.gd:516](../../src/entities/player.gd#L516),
  [wolf.gd:958](../../src/entities/wolf.gd#L958)). O ápice de um lançamento vertical é
  `v² / (2g)`: **5,2² / 48 = 0,563 m** — 44 % de um bloco. O corpo sobe, torna a descer, e com
  `blocked_horizontal` persistindo re-arma a cada 0,35–0,8 s
  ([`:987`](../../src/entities/wolf.gd#L987)): o "ficam bugados" que o dono vê é este loop, e ele é
  visível de fora como um lobo pulsando encostado num talude de um bloco.
- **O jogador só sobe se apertar espaço.** O impulso manual existe e é suficiente —
  `JUMP_SPEED 8,2` ([player.gd:38](../../src/entities/player.gd#L38)), ápice **8,2²/48 = 1,401 m**,
  que limpa o bloco com folga — mas ele só sai do papel pelo buffer de tecla: `_jump_buffer > 0` e
  coyote ([`:512-515`](../../src/entities/player.gd#L512-L515)), alimentado por
  `event.is_action_pressed("jump")` ([`:242-243`](../../src/entities/player.gd#L242-L243)). No passo
  de movimento não há nenhuma leitura de "estou bloqueado contra coisa de um bloco":
  `body.move_and_collide(delta)` ([`:373`](../../src/entities/player.gd#L373)) marca
  `blocked_horizontal` ([voxel_body.gd:99-101](../../src/entities/voxel_body.gd#L99-L101)) e
  **ninguém lê esse flag no jogador** — grep de `blocked_horizontal` em `src/` devolve o
  declarador, o gravador no integrador e um único leitor, o lobo.
- **A pergunta que falta já tem primitivo no corpo.** O stepping da IA testa altura hipotética sem
  mutar nada: `can_stand_at(p)` exige caixa livre em `p` e sólido 0,12 abaixo
  ([voxel_body.gd:147-153](../../src/entities/voxel_body.gd#L147-L153)). É exatamente "existe
  parapeito a um bloco acima, na direção em que eu quero ir" — o predicado que separa degrau de
  penhasco. Ele já é chamado por dois lugares da IA do lobo, então adicioná-lo ao jogador e ao salto
  do lobo é o segundo comprador da regra, não abstração no primeiro.
- **Os dois cenários que a suíte já tem apontam para direções opostas.** No corredor liso o contrato
  é **nenhum** lançamento: `horizontais == 0 and rearms == 0 and lancamentos == 0`
  ([aether_reactions_test.gd:1055](../../tests/aether_reactions_test.gd#L1055)) — e ele continuaria
  verde com o conserto, porque sem bloqueio horizontal nenhum dos dois caminhos é pego. Na parede de
  6 blocos o contrato era **tem lançamento**: `rearms > 0 and lancamentos > 0`, na linha `:1035` da
  leitura desta página. Essa asserção **muda de lado** com este dossiê — hoje é `rearms > 0 and
  lancamentos == 0` ([`:1109`](../../tests/aether_reactions_test.gd#L1146)) —: contra um muro de seis
  blocos, saltar é desperdício, e é ela que o braço de indiferença do §1 vira de cabeça para baixo.
  Registrar isso antes do código é o ponto: o verde antigo não era errado, era a melhor afirmação
  possível antes de existir o predicado que distingue os dois casos.
- **O resto do corpo do lobo importa para o pouso.** `DIMS = (0,75, 0,95, 1,35)`
  ([wolf.gd:96](../../src/entities/wolf.gd#L96)): 0,95 m de altura, e a caixa do `can_stand_at` na
  cota +1,0 tem de caber inteira sobre o bloco — cabe, com 1,0 m de ar livre exigido acima do
  parapeito. O do jogador é 1,80 ([player.gd:25](../../src/entities/player.gd#L25)), e por isso o
  mesmo predicado recusa degrau com teto baixo, o que é a resposta certa e não um defeito.

## 3. O que a peça exige

1. **Um predicado compartilhado, não duas cópias.** `VoxelBody.can_step_over(dir)` — resposta
   honesta à pergunta "a um bloco acima, na direção `dir`, existe onde ficar de pé?", construída
   sobre `can_stand_at` com o pé horizontal fora do corpo (`maxf(dims.x, dims.z) * 0,5 + 0,6`) e a
   altura **exatamente `+1,0`, sem margem**: a margem de 0,05 que a primeira formulação desta página
   pedia negaria ao lobo (0,95 de altura) a própria célula de 1,00 em que ele cabe, e o `floori` do
   `aabb_hits_solid` já trata a face encostada como livre. Duas chamadas `aabb_hits_solid` no pior
   caso, e só quando já houve bloqueio.
2. **O salto do lobo limpa o degrau, e só limpa degrau.** Trocar o literal `5,2` por constante
   nomeada com o ápice escrito ao lado, e exigir o predicado antes de gastar o impulso. Os sorteios
   de `_rng` de `src/entities/wolf.gd:987-988` **continuam na mesma ordem e na mesma quantidade**: a regra nova decide
   apenas se a velocidade vertical é escrita. mover o sorteio para dentro de um `if` mudaria o
   riacho e o cenário `simulation_rng_test` deixaria de medir a mesma coisa que mede hoje.
3. **Auto-pulo do jogador, com as recusas escritas.** Depois de `move_and_collide`, quando
   `blocked_horizontal`, `on_ground`, `wish != ZERO` e o predicado aprova, dar ao corpo o mesmo
   `JUMP_SPEED` que a tecla dá — um caminho de salto, não dois. Recusa explícita: painel aberto,
   dentro d'água, planando, rolamento e **agachado** (agachar é o "não me arremesse" do jogador, e
   é o que hoje já segura outros comportamentos, [player.gd:436-437](../../src/entities/player.gd#L436-L437)
   e [`:528`](../../src/entities/player.gd#L528)). A tecla física continua funcionando idêntica:
   o auto-pulo escreve a mesma velocidade, não um segundo impulsor.
4. **Nada de mexer em `step_up`.** Deixar 0,62 como está e passar o bloco a limpo por salto é a
   metade mais barata e a mais visível: um corpo que *pula* é animável (o `_animate(delta)` do lobo
   e o rig do jogador já têm voo para ler), um corpo que *teleporta* 1,02 m para cima no meio de um
   frame horizontal não é. Se alguém propuser `step_up = 1,02` depois, o argumento é de custo de
   linha, não de propriedade — e a propriedade perde.
5. **Altura de célula é 1 unidade, e isso é premissa, não constante nomeada.** O predicado usa
   `+1,0` porque o grid é de 1 — `aabb_hits_solid` percorre células por `floori`
   ([`voxel_world.gd:410-421`](../../src/world/voxel_world.gd#L410-L421)). Se um dia
   existir `SLAB` de meia altura — o id 18 já está reservado no registro de blocos — o número vira
   pergunta do `BlockDefs`, e é aí, no segundo comprador, que ele sobe de degrau.

## 4. Custo — as quatro perguntas

- **Roda por frame, por tick ou às vezes?** Por frame de física, **dentro do ramo que hoje já roda**
  (o `blocked_horizontal` do lobo; no jogador o ramo é novo e só pega quando há colisão). No passo
  normal, andando em terreno livre, o custo adicional é a leitura de um boolean que já foi escrito.
- **Quantas entidades são alcançadas?** 5 lobos no máximo e 1 jogador. O pior caso é um lobo
  encostado num talude: uma vez por janela de desvio (0,35–0,8 s), duas `aabb_hits_solid`.
- **Aloco no caminho quente?** `can_step_over` constrói `AABB` por valor e `Vector3` aritmético;
  `can_stand_at`, que ele chama, já faz isso hoje em cada teste de stepping da IA. Nenhuma `Array`,
  nenhum `Dictionary`, nenhum closure.
- **Como sei que ficou melhor?** Número antes da corrida: no cenário do degrau,
  `Δy ≥ 0,95 m` e a mesma corrida sem o predicado novo devolve `Δy < 0,1`; na parede de 6 blocos,
  `lancamentos == 0` com `rearms > 0`; no corredor liso, `lancamentos == 0` continua. O custo
  Temporal é `worst_sim_ms` ( [`sim_clock.gd:37-39`](../../src/core/sim_clock.gd#L37-L39) ) sem
  passo acima dos 25 ms que o dossiê 17 pinou como régua de cascata, e `dropped_ticks` continua 0.

## 5. Gate em headless

```sh
godot --headless --path . --check-only --script src/entities/wolf.gd
godot --headless --path . --check-only --script src/entities/player.gd
godot --headless --path . --script res://tests/aether_reactions_test.gd
godot --headless --path . tests/smoke_test.tscn
```

O runner de reações é um script `SceneTree`, não uma cena: sem o `--script res://` a linha vira
caminho de cena, o `main.tscn` do projeto assume, e a corrida abre o jogo headless e nunca sai —
medido nesta perna, um `timeout 300` matou um boot de jogo que não estava testando nada.

1. **`degrau_de_um_bloco_lobo_sobe`** — coluna de 1 bloco à frente do alvo, corpo a 2 m dela,
   `_move_target` do outro lado; avança frames e exige `feet_pos.y` ≥ `y0 + 0,95` e que o corpo
   atravesse a linha do degrau. Nasce **vermelha** no código atual (ápice 0,563).
2. **`degrau_de_um_bloco_jogador_sobe_sem_tecla`** — mesmo cenário com o jogador, `wish` injetado
   pelo caminho real do passo, **nenhum** `is_action_pressed("jump")`: exige o mesmo `Δy`. Também
   nasce vermelha.
3. **`penhasico_nao_gasta_salto`** — o braço de indiferença: a parede de 6 blocos do cenário que já
   existe, agora com `lancamentos == 0` e `rearms > 0`. É a asserção que esta página lia em `:1035`
   — re-derivada hoje em [`aether_reactions_test.gd:1146`](../../tests/aether_reactions_test.gd#L1146),
   lida do outro lado — e é por isso que ela é re-derivada neste lote em vez de apagada.
4. **`agachado_nao_e_arremessado`** — o mesmo degrau com `crouching` true: corpo continua do lado de
   cá, `Δy == 0`. A checagem que dá dente à recusa do §3.3.
5. **`predicado_degrau_recusa_teto_baixo`** — o predicado sozinho, em cinco braços montados com a
   régua do grid (célula inteira, sem meio bloco), lidos da caixa real de cada corpo: degrau de um
   bloco com ar acima → **true** nos dois; muro de dois → **false**; degrau encimado por um sólido a
   uma célula do parapeito → **true para o lobo** (0,95 cabe no vão de 1,00) e **false para o
   jogador** (1,80 não cabe) — é este braço que impede o auto-pulo de virar "pular em tudo que é
   parede", e a resposta depende da altura do corpo por design, não por sorteio; penhasco de seis →
   **false**; direção zero → **false**.
6. **`pulo_nao_custou_passo_de_ninguem`** — 1 000 ticks andando em plano sem bloqueio e 1 000 ticks
   com um degrau no caminho, `worst_sim_ms` e `dropped_ticks` lado a lado; atribuição por
   composição, como o contrato exige.
7. `EXPECTED_CHECKS` ([`aether_reactions_test.gd:39`](../../tests/aether_reactions_test.gd#L39),
   **183** nesta leitura, na `main` mergida da perna 14) sobe com o lote e é re-medido no clone
   limpo com `--import` frio, com o SHA pinado.

## 6. O que NÃO fazer

- **Não** transformar `step_up` em 1,02 para "resolver sem pulo" — §3.4.
- **Não** dar salto automático ao jogador quando a tecla está livre: quem aperta espaço faz isso
  melhor e com intenção, e o auto-pulo tem de ser indiferente ao input manual, nunca somar os dois
  impulsos no mesmo frame.
- **Não** mexer no riacho de `_rng` do lobo nem no `_population_rng` da sessão
  ([`main.gd:91`](../../src/main.gd#L91)): o conserto é regra geométrica, não sorteio novo, e um
  riacho novo derrubaria `tests/simulation_rng_test.gd` sem consertar nada.
- **Não** tocar em `FORMAT_VERSION`, `Channel.COUNT` nem na projeção do `TickJournal`: nenhum bloco
  se move por esta perna, e o `state_hash` continua função do que já era.
- **Não** generalizar para "todos os NPC" — `src/entities/` tem jogador e lobo, e o humano/NPC do
  dossiê 13 ainda não existe. A regra mora no `VoxelBody`, que é o integrador dos dois, e é só.

## 7. Ordem, e a exceção registrada antes do código

A fila serializada vigente (extensão de 2026-11-21 de
[`AGENTS.md`](../../AGENTS.md)) é **09 → 10 → 15 → 14 → 11 → 16 → 12 → 17 → 18 → 13**, e a perna 11
está **em voo** (`feat/acasalamento-e-censo-11`, ponta `3e8f9ba`, faltam os commits (f) e (g)). Esta
perna 19 encosta em `src/entities/wolf.gd` e em `tests/aether_reactions_test.gd`, os dois arquivos
que a 11 também escreve — é exatamente o caso de **um escritor por arquivo**, e a ordem tem de ser
decidida agora, não no conflito.

A exceção, com o motivo, e pedida pelo dono como urgente: **19 fura a fila e vai antes**, na
posição **11 → 19 → 16 → 12 → 17 → 18 → 13** dos que restam, porque é defeito de jogo em execução
(lobos presos em talude, jogador parado na frente de um degrau) e as pernas da fila são mecânicas
novas. Consequência assumida: quando a 19 pousar na `main`, a 11 **re-rome o gate** — traz a `main`
para dentro de si e roda a suíte de novo, porque a árvore resultante é outra revisão (item 5 de
*"Branches"*), e as linhas de `wolf.gd`/`aether_reactions_test.gd` que a 11 cita passam a valer as
depois do merge dela, não as desta página.

## 8. Commits atômicos previstos

Branch `feat/auto-pulo-de-bloco-19`, um assunto por commit, suíte verde entre eles:

- **(a)** este dossiê, registrado antes de qualquer linha (§7 é a exceção de ordem);
- **(b)** `VoxelBody.can_step_over` + a checagem 5 (o predicado sozinho, com o teste que o recusa);
- **(c)** lobo: impulso nomeado com ápice, gate pelo predicado, checagem 1 e re-derivação da
  checagem 3 na parede que já existe;
- **(d)** jogador: auto-pulo com as recusas do §3.3, checagens 2 e 4;
- **(e)** checagem 6 de custo, censo de `EXPECTED_CHECKS`, `docs/melhorias-status.md` com a rodada,
  as citações de `wolf.gd`/`player.gd`/`voxel_body.gd` que este lote moveu re-derivadas, e o
  [`README.md`](README.md) índice re-pinado com a 19 dentro.

## 9. O que o briefing do dono continha e o código desmentiu

- **"os mobs/npcs"**: hoje existe **uma** espécie animal (`wolf.gd`) e nenhum NPC. A regra entra no
  integrador que os dois usam, mas prometer "todos os mobs" seria escrever sobre arquivo inexistente.
- **"ficam bugados"** é exato e tem causa medida: não é falta de pathfinding, é **altura de lançamento
  menor que a altura do bloco** (§2). Um pathfinder novo não consertaria isso.
- O pedido de auto-pulo do jogador **não** é "aumentar o step-up": a primeira formulação que
  parecerá mais curta (`step_up = 1,02`) mata a animação de voo e é recusada em §3.4 com motivo.
- Duas receitas **desta página** caíram antes do código, contra a régua do grid. A margem do §3.1
  ("`+1,0` + margem"): com 0,05 de margem o lobo de 0,95 perde a célula de 1,00 em que ele cabe, e o
  `floori` de `aabb_hits_solid` já trata a face encostada como livre — o predicado ficou em `+1,0`
  cru. E o "vão de 0,95 m" da checagem 5: não existe meio bloco no mundo, o vão é de **uma célula**,
  e aí a resposta é por corpo — o lobo cabe e salta, o jogador de 1,80 não cabe e recusa. Medido com
  sonda descartável (cinco braços, as mesmas caixas de `wolf.gd:96` e `player.gd:25`), não presumido.

## 10. Estado depois do fecho

A perna pousou. Os oito commits são `a534e23` (esta página e a exceção), `c313544` (o predicado no
integrador), `c0659fd` (o lobo), `2a20843` (o jogador), `f843fa6` (a checagem 6 e o custo colhido no
frame real), `1e1f792` (o instrumento de âncoras, classe (c)) e `acb7970` (a re-derivação das
citações) e `a1143b0` (o fecho) — merge `--no-ff` `a518487` na `main` e `ab9ffa1` no fecho, publicado e medido num clone limpo: **246
checagens / 0 falhas / 39,6 s** na suíte e **198 / 0 / 12,870 s** no runner de reações, exit 0 nos
dois, zero `SCRIPT ERROR`. Os logs, o `artifacts.sha256` e a conferência do clone estão em
[`docs/evidence/auto-pulo-19/readback.md`](../evidence/auto-pulo-19/readback.md).

O que a página previa e a medição confirma: o degrau de um bloco sobe, o muro de dois não, o penhasco
de seis não gasta salto, o agachado não é arremessado e o degrau com teto baixo é recusado pelo
jogador. O que ela **não** previa, e o fecho mediu: o par de vazamento do quit não sai na primeira
corrida do clone e sai na segunda, no mesmo clone e com o mesmo comando — o que o par acompanha é o
diretório de dados `user://`, não a árvore.

Fica em aberto para a perna 11, que escreve os mesmos dois arquivos: re-rometer o gate a partir de
`ab9ffa1`, porque a árvore resultante é outra revisão (item 5 de "Branches" em
[`AGENTS.md`](../../AGENTS.md)).
