# 10 — Rotinas de alcateia: rondar, farejar, procurar, cercar e atacar em grupo

Dossiê de **leitura de código**, não de corrida: nenhuma engine rodou aqui e nenhum número
publicado foi re-medido por este arquivo. Autorização do dono em 2026-11-20
([`AGENTS.md`, "Escopo autorizado agora"](../../AGENTS.md) — extensão de 2026-11-20, ordem
registrada **antes** do código: serializada 09 → 10 → 11 → 12, `wolf.gd` e `main.gd` têm escritor
único por branch). Depende do dossiê 09 porque a cor e o background de Éter por bioma mudam o que
a alcateia lê.

## 1. Premissa nomeada

**Um lobo só age em alcateia se a intenção dele mudar quando outro lobo está por perto.**
Forma falsificável, em headless: o **mesmo** cenário (mesma semente, mesma posição de jogador e de
rastro) rodado com 1 lobo e com 4 lobos tem de devolver `intent` diferente para pelo menos um dos
lobos depois de N ticks. Se a intenção é idêntica, a matilha é texto no documento, não
comportamento — e a checagem é vazia, exatamente como o dossiê 02 exige do contraste de cadência.

Segunda premissa, a que o dono pediu com nome: **a memória do predador tem de ser boa ou ruim para
o jogador de forma observável.** Hoje ela já é, mas só para quem a ganhou
([`_sense`](../../src/entities/wolf.gd#L944-L946) lê `danger_from_actor_1` e fecha a porta de
`hunt`). O que falta é o **contágio**: um lobo que viu o jogador hoje não comunica nada a ninguém,
então a lembrança de uma matilha inteira é a soma de cinco memórias isoladas.

## 2. Estado real do código (lido na abertura desta perna, não medido)

Os itens abaixo são a árvore que a perna 10 encontrou, e é no pretérito que se leem: as ausências
que ela foi autorizada a preencher. Os ponteiros `wolf.gd:NNN` estão re-derivados contra os
arquivos de hoje, então cada número aponta o lugar onde a frase mora agora; onde a própria perna
escreveu o que faltava, o itálico diz isso — a ausência deixou de ser presente, e o número de hoje
não descreve mais o estado daquele dia.

- **A árvore era de um animal solitário.**
  [`_build_tree`](../../src/entities/wolf.gd#L422-L452) monta
  `Selector[f Sequence[guard, flee], Sequence[guard, chase], ...]` sobre quatro ramos
  (`flee`, `hunt`, `sniff`, `patrol`) e embrulha tudo em `SubtreeGuard.new().init("mente.lobo", …, 400)`
  ([:422](../../src/entities/wolf.gd#L422)). Nenhum nó lia outro lobo.
  *(Relido nesta ponta: a §3.5 pôs a leitura da matilha nas folhas —
  [`_leaf_chase`](../../src/entities/wolf.gd#L503) e
  [`_leaf_investigate`](../../src/entities/wolf.gd#L567-L605) contam vizinhos por `intent` em
  [`_hunt_pack_size`](../../src/entities/wolf.gd#L525) e em
  [`_scent_seat`](../../src/entities/wolf.gd#L619-L632), e
  [`_leaf_wander`](../../src/entities/wolf.gd#L652) pega o setor pelo posto em
  [`_territory_rank`](../../src/entities/wolf.gd#L708).)*
- **O blackboard não tinha matilha.** `sim_step` chamava
  `_tree.tick({"wolf": self, "elapsed": elapsed, "tick": _sim_clock.tick, "dt": dt})` e `_think`
  passava `{"wolf": self, "elapsed": elapsed}` ao escorredor. Era o dicionário novo por lobo por
  tick que o contrato já registra como débito
  ([`AGENTS.md`](../../AGENTS.md), "Alocação no caminho quente").
  *(Relido nesta ponta: as duas chamadas seguem em
  [:911](../../src/entities/wolf.gd#L911) e [:862](../../src/entities/wolf.gd#L862) e agora
  **carregam** `"pack": _pack` — a lista que [`_read_pack`](../../src/entities/wolf.gd#L869-L870)
  renova uma vez por tick (§3.1). O dicionário continua sendo o mesmo débito, agora com uma
  `Array` a mais dentro dele, e a alocação segue sem medição própria.)*
- **A percepção só enxergava o jogador.**
  [`_sense`](../../src/entities/wolf.gd#L916-L953): distância e LOS **contra o jogador**, e a LOS só
  roda a menos de 30 m com ele vivo ([:922](../../src/entities/wolf.gd#L922)); três amostras do
  Éter no próprio ponto ([:923-925](../../src/entities/wolf.gd#L923-L925)); rastro no ritmo de
  `SCENT_PERIOD` ([:927-928](../../src/entities/wolf.gd#L927-L928) →
  [`_find_scent`](../../src/entities/wolf.gd#L960-L1000)); `_fear_level` composto (
  [:940-941](../../src/entities/wolf.gd#L940-L941)); `_courage` fechado por memória de apanhar
  ([:944-946](../../src/entities/wolf.gd#L944-L946)); `saw_player` lembrado a cada 2 s
  ([:950-952](../../src/entities/wolf.gd#L950-L952)). Não existia "outro lobo vê o quê".
  *(Relido nesta ponta: o contágio da §3.6 está em
  [:932-939](../../src/entities/wolf.gd#L932-L939) e soma o `intent` e o `trust` dos vizinhos no
  `_fear_level` ([:940-941](../../src/entities/wolf.gd#L940-L941)) e no `_courage`
  ([:946](../../src/entities/wolf.gd#L946)). O percept alheio — o que **ele** viu — continua fora
  da lista, porque o meio compartilhado entre lobos é o Éter, §3.3.)*
- **Quatro opções no escorredor, e nenhuma delas sabia de vizinho.**
  [`_build_scorer`](../../src/entities/wolf.gd#L802-L858): `flee` com 5 considerações
  ([:806-816](../../src/entities/wolf.gd#L806-L816)), `hunt` com 7 — inclusive o veto
  "presa percebida" ([:828-830](../../src/entities/wolf.gd#L828-L830)), o veto "coragem contra este
  ator" ([:831-832](../../src/entities/wolf.gd#L831-L832)) e o veto "filhote não caça"
  ([:840-842](../../src/entities/wolf.gd#L840-L842), dossiê 11 §3.3) —, `investigate` com 4 e o veto
  "há rastro" ([:851-852](../../src/entities/wolf.gd#L851-L852)), e `patrol` com o chão de fundo de
  0,22 ([:856-858](../../src/entities/wolf.gd#L856-L858)). `min_lead = 0,05` e `min_interval = 0,6`
  ([:803-804](../../src/entities/wolf.gd#L803-L804)) são a histerese que evita o flicker — e é
  nela que uma opção "circle" nova tem de caber, não em `if` solto.
  *(Relido nesta ponta: `flee` pontua "terror no ar" pelo `_fear_level` que já levou o pânico dos
  vizinhos e `hunt` pontua "coragem contra este ator" pelo `_courage` amortecido pela confiança
  deles — os dois números acima. A §3.6 entrou no escorredor pela porta da percepção, sem
  consideração nova.)*
- **Rondar já existia, mas sem área e sem coordenação.**
  [`_leaf_wander`](../../src/entities/wolf.gd#L652) sorteia até 8 tentativas de ponto seco a
  5–22 m do `home` (com [`_dry_ground`](../../src/entities/wolf.gd#L717) e
  [`_shore_point`](../../src/entities/wolf.gd#L725) como portas). O `home` vinha de
  `_random_ground_point(16.0, 46.0)` — leitura da ponta deste dossiê —, sorteado um por lobo em
  [`_spawn_wolves`](../../src/main.gd#L387-L410): cinco lares espalhados, **nenhum território
  compartilhado**, e a mensagem de respawn dizia "uma nova matilha entrou no vale"
  (`main.gd:263` naquela ponta) sem que nada no código chame aquilo de matilha.
  *(Relida nesta ponta: a perna 14 trocou o sorteio único por
  [`_spawn_home_point`](../../src/main.gd#L788), chamado por
  [`_place_request`](../../src/main.gd#L704) a partir de
  [`:399`](../../src/main.gd#L399) sobre as [`SPAWN_BANDS`](../../src/main.gd#L550), e removeu o
  letreiro — o dossiê 14 §1.3 manda nenhum aviso de criatura na tela. A área e a coordenação são
  desta perna: a folha conta o censo em
  [:653](../../src/entities/wolf.gd#L653), corta o círculo em
  [:664-666](../../src/entities/wolf.gd#L664-L666) sobre o baricentro de
  [`_territory_center`](../../src/entities/wolf.gd#L694-L701) e dá a fatia de cada um pelo
  [`_territory_rank`](../../src/entities/wolf.gd#L708-L713) — não por `identity % n`; com um lobo
  só o centro volta a ser o próprio lar e a fatia o círculo inteiro, que é a ronda de antes.)*
- **Cercar não existia.** [`_leaf_chase`](../../src/entities/wolf.gd#L503) ia direto ao alvo e
  [`_leaf_stalk`](../../src/entities/wolf.gd#L554) ia ao último avistamento
  (`mind.last_atom("saw_player")`). `_move_target` era um ponto só, e a locomoção em
  [`_physics_process`](../../src/entities/wolf.gd#L1203-L1259) só tinha desemperto + desvio
  ([:1239-1241](../../src/entities/wolf.gd#L1239-L1241)) — nada distribuía os lobos em torno de nada.
  *(Relido nesta ponta: o assento angular da §3.4 escreve o `_move_target` dos que caçam em
  [:506-514](../../src/entities/wolf.gd#L506-L514) →
  [`_seat_point`](../../src/entities/wolf.gd#L548-L551), o da ronda em
  [:665](../../src/entities/wolf.gd#L665) e o do rastro em
  [:619-632](../../src/entities/wolf.gd#L619-L632); o ramo que falta em
  [:1246-1247](../../src/entities/wolf.gd#L1246-L1247) é o pulo do degrau, perna 19, não cerco.)*
- **Atacar em grupo só existia no sentido acidental.** [`_leaf_bite`](../../src/entities/wolf.gd#L771)
  alcança `BITE_RANGE` com `_bite_cd` ([:23-25](../../src/entities/wolf.gd#L23-L25) e o cooldown em
  `sim_step` [:878](../../src/entities/wolf.gd#L878)), imprime BLOOD 0,18
  ([:781](../../src/entities/wolf.gd#L781)) e reforça `prey_wounded`. Cinco lobos podiam morder no
  mesmo tick porque nada os sincronizava — e nada os **dessedimentava** tampoco: não existia "quem
  já está em cima espera o outro chegar".
  *(Relido nesta ponta: o escalonamento da §3.5 está na porta de vez da mordida
  ([:774-777](../../src/entities/wolf.gd#L774-L777) →
  [`_bite_turn`](../../src/entities/wolf.gd#L793-L797), que conta os participantes em
  [`_hunt_pack_size`](../../src/entities/wolf.gd#L525-L530) e o posto em
  [`_hunt_pack_rank`](../../src/entities/wolf.gd#L536-L541)); os dois números acima continuam os
  mesmos de antes, porque a perna não tocou o alcance nem o cooldown.)*
- **O precedente de como se injeta visão de fora, sem acoplar:** o jogador recebe um
  `entity_provider: Callable` ([player.gd:91](../../src/entities/player.gd#L91)), montado pela
  sessão ([main.gd:170](../../src/main.gd#L170)) e lido na mira
  ([player.gd:619-631](../../src/entities/player.gd#L619-L631)). A matilha entra pelo mesmo
  caminho — `pack_provider`, não um singleton novo.
- **Memória: por ator, não por matilha.** `Mind` guarda `episodic` (cap 24), `beliefs`,
  `relations` ([mind.gd:24-26](../../src/ai/mind.gd#L24-L26)), `trust/adjust_trust` por ator
  ([:154-159](../../src/ai/mind.gd#L154-L159)), `believes()` com soleira 0,35
  ([:119-120](../../src/ai/mind.gd#L119-L120)), decaimento exponencial por minuto
  ([:133-151](../../src/ai/mind.gd#L133-L151)) e deriva de temperamento por experiência
  ([:56-64](../../src/ai/mind.gd#L56-L64)). `main` persiste cada mente por
  [`state_dict`](../../src/entities/wolf.gd#L1360)/[`load_state`](../../src/entities/wolf.gd#L1376).
  Não há canal de lobo para lobo.

## 3. O que a peça exige

1. **`pack_provider` no lobo**, montado em `main` como o do jogador, devolvendo uma leitura
   **barata e estável**: para cada lobo, `[{identity, pos, intent, hp_ratio}]` dos vivos a menos de
   um raio de coesão. A lista entra no blackboard de `sim_step` ([:911](../../src/entities/wolf.gd#L911))
   e no contexto do escorredor ([:862](../../src/entities/wolf.gd#L862)), uma vez por tick de
   20 Hz — nunca por frame.
2. **Rondar com território**: o `home` vira **centro compartilhado** com raio próprio, e o
   `_leaf_wander` escolhe setor por `identity` (o assento angular §3.4) em vez de sortear qualquer
   ponto. O RNG por lobo ([:311](../../src/entities/wolf.gd#L311)) continua sendo o sorteio; o
   `_population_rng` da sessão ([main.gd:81](../../src/main.gd#L81), sorteado em
   [:773-774](../../src/main.gd#L809-L810)) não pode ser consumido por decisão de lobo — é o que o
   dossiê de RNG isolou.
3. **Procurar com o rastro dos outros.** Na leitura da abertura, quando a inspeção
   ([`_leaf_investigate`](../../src/entities/wolf.gd#L567-L605), RUNNING por `INSPECT_SECONDS`)
   terminava, quem achava gravava **para si mesmo** (`_remember_scent`,
   `src/entities/wolf.gd:635`) e o cache era do lobo (`:646-649`, limpo no load em `:1408`). O meio
   compartilhado entre lobos já existia e é o Éter: o único canal que um lobo escreve e outro lê sem
   referência direta. Então o lote **não inventou chave nem mensagem nova** — o que achou imprime no
   ponto encontrado (BLOOD já era impresso em `src/entities/wolf.gd:781`, WORK é o canal de "tem
   alguém mexendo aqui") e os vizinhos chegam pelo `_find_scent` normal
   (`src/entities/wolf.gd:960-1000`), com a seleção `BLOOD + 0,35 × WORK`.
   Vantagem: nenhuma estrutura nova, nenhum dicionário compartilhado, e o leitor já é testado pelo
   cenário `_test_scent_cave_layer` (`tests/aether_reactions_test.gd:1531`). Custo honesto: a partir
   daqui WORK deixa de ser assinatura exclusiva do jogador, e é a checagem 3 do dossiê 12 que decide
   isso — os dois arquivos têm de ser lidos juntos antes de escrever qualquer linha.
4. **Cercar — assentos angulares com histerese.** A posição de ataque passa de "o alvo" para
   "alvo + offset angular", com `seat = identity % n_participantes` e um ângulo que **só muda**
   quando o lobo está fora da faixa do próprio setor (a mesma ideia de `min_lead`/`min_interval`
   dos `:734-735`, aplicada a ângulo). O `BITE_RANGE` de 1,95 m
   ([:23](../../src/entities/wolf.gd#L23)) é o que decide o raio do anel: o assento tem de parar a
   alcance de mordida, não em cima do corpo — era isso que punha cinco corpos no mesmo voxel, o
   mesmo problema que a nota de `_volume_clear` ([main.gd:860-862](../../src/main.gd#L860-L862))
   registrou no spawn.
   *(Escrito nesta ponta: o assento saiu por **posto de identidade**
   ([`_hunt_pack_rank`](../../src/entities/wolf.gd#L536-L541), contados em
   [`_hunt_pack_size`](../../src/entities/wolf.gd#L525-L530)) e não por `identity % n`, porque
   precedência por "quem chegou primeiro" pediria posse escrita no lobo — o mesmo motivo que a nota
   de [`_scent_seat`](../../src/entities/wolf.gd#L608-L632) dá para a célula de rastro.)*
5. **Atacar em grupo — escalonamento, não sincronia.** Quem chega primeiro mantém; quem está no
   segundo assento **espera** (`_bite_cd` já segura 1,15 s — [:25](../../src/entities/wolf.gd#L25))
   e só entra quando o alvo está `prey_wounded` ou quando o primeiro desengatou. Propriedade
   testável: nunca mais de `n_attacking` lobos a `BITE_RANGE` do alvo no mesmo tick, **e** o dano
   total da matilha num cenário fixo cai na banda medida.
6. **Contágio de memória (o "bom ou ruim para o player" observável).** Um lobo que apanhou e
   fugiu imprime FEAR; os que lêem esse FEAR já escalavam `_fear_level`
   ([:940](../../src/entities/wolf.gd#L940)) — faltava a **outra metade**: um lobo que foi
   **alimentado** pelo jogador (`feed` [:1332](../../src/entities/wolf.gd#L1332), `on_kill`
   [:1326](../../src/entities/wolf.gd#L1326)) tem de baixar a agressão de quem está perto dele,
   não só a sua. Falsificável: cenário com um lobo amigável (trust alto) + dois famintos, e o
   `intent` dos dois muda contra o mesmo jogador. Mandato 2 vale aqui: **nada** disso vem do
   oráculo — a única saída dele é `_narrations`
   ([mind_oracle.gd:47](../../src/ai/mind_oracle.gd#L47), lida em
   [:110-111](../../src/ai/mind_oracle.gd#L110-L111) e entregue ao HUD).
   *(Escrita nesta ponta: a outra metade é o `trust` publicado pelo vizinho em
   [`_pack_put`](../../src/main.gd#L940-L955) ([:899](../../src/main.gd#L954)), somado em
   [:934-939](../../src/entities/wolf.gd#L934-L939) e amortecendo o `_courage` em
   [:946](../../src/entities/wolf.gd#L946); a testemunha numérica é o cenário
   `_test_amortece_confianca` ([aether_reactions_test.gd:27](../../tests/aether_reactions_test.gd#L27)).
   Os dois métodos citados acima são os mesmos, agora lidos de fora.)*

## 4. Custo — as quatro perguntas

- **Roda por frame, por tick ou às vezes?** Tick de 20 Hz, dentro de `sim_step`, portanto dentro do
  cronômetro `begin_step`/`end_step` ([main.gd:311-313](../../src/main.gd#L311-L313),
  [sim_clock.gd:32-39](../../src/core/sim_clock.gd#L32-L39)) e dos 50 ms divididos com a difusão e a
  recolha. A lista de vizinhos é construída **uma vez por passo** na sessão, não cinco.
- **Quantas entidades são alcançadas?** `n(n-1)/2` = 10 comparações por passo com 5 lobos; hoje o
  `for w in wolves` já roda 5 ([main.gd:324-325](../../src/main.gd#L324-L325)). Com o censo do
  dossiê 11 (até ~12), vira 66 — ainda uma fração do `sim_step`, mas o número tem de sair no
  rodapé, não na conversa.
- **Aloco no caminho quente?** Era o débito registrado: o dicionário de blackboard por lobo por
  tick ([:911](../../src/entities/wolf.gd#L911)) passou a carregar a leitura da matilha. Antes de
  somar qualquer alocação nova, o lote **reaproveitou** um buffer por sessão (o mesmo array,
  reescrito a cada passo) — se a solução fosse alocar cinco arrays por tick, ela não entrava.
  *(Escrito nesta ponta: [`_read_pack`](../../src/entities/wolf.gd#L869-L870) só troca a referência
  pelo [`pack_of`](../../src/main.gd#L900-L902) da sessão, e [`_pack_put`](../../src/main.gd#L940-L955)
  reescreve a entrada no lugar, com o buffer cortado por `resize` em
  [:873-874](../../src/main.gd#L928-L929); o dicionário do blackboard continua o mesmo débito do
  contrato, sem medição de alocação própria.)*
- **Como sei que ficou melhor?** Pelo budget que já é código: `SubtreeGuard` de 400 µs por mente
  ([:448-449](../../src/entities/wolf.gd#L448-L449)) com `trips` colhido no runner
  ([aether_reactions_test.gd:345-353](../../tests/aether_reactions_test.gd#L345-L353), o par da
  matilha inteira em [:1849-1861](../../tests/aether_reactions_test.gd#L1886-L1898) e a checagem em
  [:3155-3156](../../tests/aether_reactions_test.gd#L3192-L3193)). Critério
  numérico: **`trips` continua 0** e a soma de `last_us` não sai da banda medida
  (14 551 µs de pico 40 no rodapé pin de `ff347d2`). Se estourar, a alcateia entra com menos
  considerações, não com budget maior. O agregado dos cinco lobos continua sem medição (dossiê 04)
  e nada aqui fecha P1.

## 5. Gate em headless

```sh
godot --headless --path . --check-only --script src/entities/wolf.gd
godot --headless --path . --script tests/aether_reactions_test.gd
godot --headless --path . tests/smoke_test.tscn
```

Cenários novos no runner dedicado (a lista é `TESTS`
([aether_reactions_test.gd:8-38](../../tests/aether_reactions_test.gd#L8-L38)), 21 cenários na
leitura desta página — hoje 56):

1. **`contraste_de_alcateia`** — o mesmo cenário com 1 e com 4 lobos; `intent` de pelo menos um
   lobo difere depois de N ticks, e o log imprime as duas intenções. Checagem **propositalmente
   capaz de ficar vazia**: se ela passar com as duas listas de intenção idênticas, o gate é mentira
   (critério do dossiê 02, [`02-censo-multi-semente.md`](02-censo-multi-semente.md)).
2. **`cercar_calcula_assentos`** — n lobos em `hunt` contra um alvo produzem `n` assentos
   **distintos** e todos a distância ≤ `BITE_RANGE + folga`; imprime a lista de distâncias.
3. **`ataque_escalonado`** — nunca mais de `k` mordidas no mesmo tick contra o mesmo alvo;
   imprime mordidas por tick no pior tick.
4. **`medo_contagia`** e **`amigo_amortece`** — A/B com um lobo em pânico / um lobo de trust alto
   no mesmo cenário; o `intent` dos vizinhos muda e a soleira usada é a do código (`believes()`
   0,35, [mind.gd:119-120](../../src/ai/mind.gd#L119-L120)); imprime os dois valores.
5. **`alcateia_nao_consome_rng_da_sessao`** — `_population_rng` intacta depois de um passo com
   matilha completa (o contrato do RNG isolado, registrado no status).
6. `EXPECTED_CHECKS` ([aether_reactions_test.gd:64](../../tests/aether_reactions_test.gd#L64),
   **119** na leitura desta página) sobe com o lote, e a suíte (**237** na mesma leitura) idem — os
   dois re-medidos no clone limpo com `--import` frio antes de virar número publicado.

## 6. O que NÃO fazer

- **Não criar `PackState`, `Alcateia` nem autoload novo.** O dono da matilha é `main.gd` hoje
  ([`_spawn_wolves`](../../src/main.gd#L387-L410), [`wolves`](../../src/main.gd#L70),
  [`_reap_corpses`](../../src/main.gd#L958-L970)); mover posse é o dossiê 06 (K3), e ele só abre
  com comprador fora de `main.gd`.
- **Não pôr a coordenação no oráculo** (mandato 2). Uma "estratégia de matilha" sugerida por LLM
  entra como crença em quarentena, nunca como intenção escrita no corpo.
- **Não subir o budget de 400 µs** para a alcateia caber: é o gate que o contrato escreve como
  número, e a alternativa é menos considerações.
- **Não recomendar `N == 5` fixo em lugar do `n_participantes` real**: com censo variável (11) um
  assento por índice vira buraco.
- **Não silenciar `SCRIPT ERROR`** para a contagem bater: erro dentro de um cenário derruba
  checagens em silêncio, e a suíte passa a contar menos com o mesmo "0 falhas"
  ([`AGENTS.md`](../../AGENTS.md), "O que não fazer"; medido no status).

## 7. Commits atômicos

(a) `pack_provider` + blackboard, sem comportamento novo, com a checagem 5; (b) rondar por setor
compartilhado (2 só a checagem 1 passa depois disto? não — rondar é a **segunda**; o contraste é a
primeira capable de vermelho com 4 lobos em setores diferentes); (c) assentos angulares + checagem
2; (d) mordida escalonada + 3; (e) contágio + 4; (f) status e `README.md` com o número do clone
limpo. Branch `feat/alcateia-rutinas-10`, base `main`, merge `--no-ff`, suíte verde entre eles.

## 8. O que este dossiê não fecha

Nenhum gate de fase (mandato 4). O HOT agregado dos cinco lobos continua sem medição (04), a
difusão continua síncrona (05), os canais morte/som/fogo continuam 3 (03), e `MindsInspector` não
existe (08) — sem ele, a memória compartilhada é lida no log do runner, não na tela do F3.

## 9. Citações deste arquivo

§2 a §7 foram lidos na base desta branch (`eb6ec8d`, a `main` antes do lobo de alcateia); o código
de `src/` e `tests/` nessa base é byte a byte o mesmo da revisão que o passe de citações usou como
referência, então os números de §2 são da árvore **antes** da peça. O passe `fb20707` deslocou só as
âncoras cujo conteúdo reapareceu inteiro na árvore nova. As bullets cujo código **esta branch
substituiu** — a árvore sem vizinho, o blackboard sem `pack`, o chase sem assento, o `_sense` que só
via o jogador — não passam por aquela prova, porque o trecho não sobreviveu: nelas a frase é
história, e o que existe hoje, com que número, está no status ("Feito nesta sessão").

Duas citações deste arquivo estavam com rótulo ≠ âncora **já na base**: `:382-383` com âncora
`#L383` e `:392-393` com âncora `#L547`. Conferidas uma a uma na árvore atual: as duas
considerações continuam lá, texto por texto, em [wolf.gd:831-832](../../src/entities/wolf.gd#L831-L832)
("coragem contra este ator") e [wolf.gd:851-852](../../src/entities/wolf.gd#L851-L852) ("ha rastro").
Onde a frase ainda é verdadeira na árvore, a âncora foi posta na árvore; onde ela deixou de ser, o
número antigo fica como leitura da base e está dito acima.
