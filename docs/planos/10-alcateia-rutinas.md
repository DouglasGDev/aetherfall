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
([`_sense`](../../src/entities/wolf.gd#L612-L613) lê `danger_from_actor_1` e fecha a porta de
`hunt`). O que falta é o **contágio**: um lobo que viu o jogador hoje não comunica nada a ninguém,
então a lembrança de uma matilha inteira é a soma de cinco memórias isoladas.

## 2. Estado real do código (lido, não medido)

- **A árvore é de um animal solitário.**
  [`_build_tree`](../../src/entities/wolf.gd#L201-L227) monta
  `Selector[f Sequence[guard, flee], Sequence[guard, chase], ...]` sobre quatro ramos
  (`flee`, `hunt`, `sniff`, `patrol`) e embrulha tudo em `SubtreeGuard.new().init("mente.lobo", …, 400)`
  ([:227](../../src/entities/wolf.gd#L227)). Nenhum nó lê outro lobo.
- **O blackboard não tem matilha.** `sim_step` chama
  `_tree.tick({"wolf": self, "elapsed": elapsed, "tick": _sim_clock.tick, "dt": dt})`
  ([:594](../../src/entities/wolf.gd#L594)) e `_think` passa `{"wolf": self, "elapsed": elapsed}` ao
  escorredor ([:557](../../src/entities/wolf.gd#L557)). É o dicionário novo por lobo por tick que o
  contrato já registra como débito ([`AGENTS.md`](../../AGENTS.md), "Alocação no caminho quente").
- **A percepção só enxerga o jogador.**
  [`_sense`](../../src/entities/wolf.gd#L436-L459): distância e LOS **contra o jogador**, e a LOS só
  roda a menos de 30 m com ele vivo ([:603](../../src/entities/wolf.gd#L603)); três amostras do
  Éter no próprio ponto ([:604-606](../../src/entities/wolf.gd#L604-L606)); rastro no ritmo de
  `SCENT_PERIOD` ([:607-608](../../src/entities/wolf.gd#L607-L608) →
  [`_find_scent`](../../src/entities/wolf.gd#L466-L506)); `_fear_level` composto (
  [:609](../../src/entities/wolf.gd#L609)); `_courage` fechado por memória de apanhar
  ([:612-613](../../src/entities/wolf.gd#L612-L613)); `saw_player` lembrado a cada 2 s
  ([:618-621](../../src/entities/wolf.gd#L618-L621)). Não existe "outro lobo vê o quê".
- **Quatro opções no escorredor, e nenhuma delas sabe de vizinho.**
  [`_build_scorer`](../../src/entities/wolf.gd#L353-L399): `flee` com 5 considerações
  ([:494-504](../../src/entities/wolf.gd#L494-L504)), `hunt` com 6 — inclusive o veto
  "presa percebida" ([:533-535](../../src/entities/wolf.gd#L533-L535)) e o veto "coragem contra este
  ator" ([:382-383](../../src/entities/wolf.gd#L537)) —, `investigate` com 4 e o veto "ha rastro"
  ([:392-393](../../src/entities/wolf.gd#L547)), e `patrol` com o chão de fundo de 0,22
  ([:551-553](../../src/entities/wolf.gd#L551-L553)). `min_lead = 0,05` e `min_interval = 0,6`
  ([:491-492](../../src/entities/wolf.gd#L491-L492)) são a histerese que evita o flicker — e é
  nela que uma opção "circle" nova tem de caber, não em `if` solto.
- **Rondar já existe, mas sem área e sem coordenação.**
  [`_leaf_wander`](../../src/entities/wolf.gd#L390) sorteia até 8 tentativas de ponto seco a
  5–22 m do `home` (com [`_dry_ground`](../../src/entities/wolf.gd#L411) e
  [`_shore_point`](../../src/entities/wolf.gd#L422) como portas). O `home` vem de
  [`_random_ground_point(16.0, 46.0)`](../../src/main.gd#L240-L254), sorteado um por lobo em
  [`_spawn_wolves`](../../src/main.gd#L199-L215): cinco lares espalhados, **nenhum território
  compartilhado**, e a mensagem de respawn diz "uma nova matilha entrou no vale"
  ([main.gd:182](../../src/main.gd#L182)) sem que nada no código chame aquilo de matilha.
- **Cercar não existe.** [`_leaf_chase`](../../src/entities/wolf.gd#L281) vai direto ao alvo e
  [`_leaf_stalk`](../../src/entities/wolf.gd#L290) vai ao último avistamento
  (`mind.last_atom("saw_player")`). `_move_target` é um ponto só, e a locomoção em
  [`_physics_process`](../../src/entities/wolf.gd#L702-L747) tem desemperto + desvio
  ([:738-742](../../src/entities/wolf.gd#L738-L742)) — nada distribui os lobos em torno de nada.
- **Atacar em grupo só no sentido acidental.** [`_leaf_bite`](../../src/entities/wolf.gd#L450)
  alcança `BITE_RANGE` com `_bite_cd` ([:34-35](../../src/entities/wolf.gd#L34-L35) e o cooldown em
  `sim_step` [:566](../../src/entities/wolf.gd#L566)), imprime BLOOD 0,18
  ([:482](../../src/entities/wolf.gd#L482)) e reforça `prey_wounded`. Cinco lobos podem morder no
  mesmo tick porque nada os sincroniza — e nada os **dessedimenta** tampoco: não existe "quem já
  está em cima espera o outro chegar".
- **O precedente de como se injeta visão de fora, sem acoplar:** o jogador recebe um
  `entity_provider: Callable` ([player.gd:91](../../src/entities/player.gd#L91)), montado pela
  sessão ([main.gd:99](../../src/main.gd#L99)) e lido na mira
  ([player.gd:601-613](../../src/entities/player.gd#L601-L613)). A matilha entra pelo mesmo
  caminho — `pack_provider`, não um singleton novo.
- **Memória: por ator, não por matilha.** `Mind` guarda `episodic` (cap 24), `beliefs`,
  `relations` ([mind.gd:18-20](../../src/ai/mind.gd#L18-L20)), `trust/adjust_trust` por ator
  ([:126-131](../../src/ai/mind.gd#L126-L131)), `believes()` com soleira 0,35
  ([:104-105](../../src/ai/mind.gd#L104-L105)), decaimento exponencial por minuto
  ([:108-123](../../src/ai/mind.gd#L108-L123)) e deriva de temperamento por experiência
  ([:50-58](../../src/ai/mind.gd#L50-L58)). `main` persiste cada mente por
  [`state_dict`](../../src/entities/wolf.gd#L842)/[`load_state`](../../src/entities/wolf.gd#L850).
  Não há canal de lobo para lobo.

## 3. O que a peça exige

1. **`pack_provider` no lobo**, montado em `main` como o do jogador, devolvendo uma leitura
   **barata e estável**: para cada lobo, `[{identity, pos, intent, hp_ratio}]` dos vivos a menos de
   um raio de coesão. A lista entra no blackboard de `sim_step` ([:594](../../src/entities/wolf.gd#L594))
   e no contexto do escorredor ([:557](../../src/entities/wolf.gd#L557)), uma vez por tick de
   20 Hz — nunca por frame.
2. **Rondar com território**: o `home` vira **centro compartilhado** com raio próprio, e o
   `_leaf_wander` escolhe setor por `identity` (o assento angular §3.4) em vez de sortear qualquer
   ponto. O RNG por lobo ([:175](../../src/entities/wolf.gd#L175)) continua sendo o sorteio; o
   `_population_rng` da sessão ([main.gd:45](../../src/main.gd#L45), sorteado em
   [:243-244](../../src/main.gd#L243-L244)) não pode ser consumido por decisão de lobo — é o que o
   dossiê de RNG isolou.
3. **Procurar com o rastro dos outros.** Hoje, quando a inspeção
   ([`_leaf_investigate`](../../src/entities/wolf.gd#L249-L279), RUNNING por `INSPECT_SECONDS`)
   termina, quem achou grava **para si mesmo** (`_remember_scent`, `src/entities/wolf.gd:280`) e o
   cache é do lobo, limpo no load (`:674-705`). O meio compartilhado entre lobos já existe e é o
   Éter: o único canal que um lobo escreve e outro lê sem referência direta. Então o lote **não
   inventa chave nem mensagem nova** — o que achou imprime no ponto encontrado (BLOOD já é impresso
   em `src/entities/wolf.gd:345`, WORK é o canal de "tem alguém mexendo aqui") e os vizinhos chegam
   pelo `_find_scent` normal (`src/entities/wolf.gd:462-506`), com a seleção `BLOOD + 0,35 × WORK`.
   Vantagem: nenhuma estrutura nova, nenhum dicionário compartilhado, e o leitor já é testado pelo
   cenário `_test_scent_cave_layer` (`tests/aether_reactions_test.gd:14`). Custo honesto: a partir
   daqui WORK deixa de ser assinatura exclusiva do jogador, e é a checagem 3 do dossiê 12 que decide
   isso — os dois arquivos têm de ser lidos juntos antes de escrever qualquer linha.
4. **Cercar — assentos angulares com histerese.** A posição de ataque passa de "o alvo" para
   "alvo + offset angular", com `seat = identity % n_participantes` e um ângulo que **só muda**
   quando o lobo está fora da faixa do próprio setor (a mesma ideia de `min_lead`/`min_interval`
   dos `:354-355`, aplicada a ângulo). O `BITE_RANGE` de 1,95 m
   ([:26](../../src/entities/wolf.gd#L26)) é o que decide o raio do anel: o assento tem de parar a
   alcance de mordida, não em cima do corpo — é o que hoje causa cinco corpos no mesmo voxel, o
   mesmo problema que a nota de `_volume_clear` ([main.gd:262-264](../../src/main.gd#L262-L264))
   registrou no spawn.
5. **Atacar em grupo — escalonamento, não sincronia.** Quem chega primeiro mantém; quem está no
   segundo assento **espera** (`_bite_cd` já segura 1,15 s — [:35](../../src/entities/wolf.gd#L35))
   e só entra quando o alvo está `prey_wounded` ou quando o primeiro desengatou. Propriedade
   testável: nunca mais de `n_attacking` lobos a `BITE_RANGE` do alvo no mesmo tick, **e** o dano
   total da matilha num cenário fixo cai na banda medida.
6. **Contágio de memória (o "bom ou ruim para o player" observável).** Um lobo que apanhou e
   fugiu imprime FEAR; os que lêem esse FEAR hoje já escalam `_fear_level`
   ([:609](../../src/entities/wolf.gd#L609)) — falta a **outra metade**: um lobo que foi
   **alimentado** pelo jogador (`feed` [:820](../../src/entities/wolf.gd#L820), `on_kill`
   [:814](../../src/entities/wolf.gd#L814)) tem de baixar a agressão de quem está perto dele,
   não só a sua. Falsificável: cenário com um lobo amigável (trust alto) + dois famintos, e o
   `intent` dos dois muda contra o mesmo jogador. Mandato 2 vale aqui: **nada** disso vem do
   oráculo — a única saída dele é `_narrations`
   ([mind_oracle.gd:27](../../src/ai/mind_oracle.gd#L27), lida em
   [:59-60](../../src/ai/mind_oracle.gd#L59-L60) e entregue ao HUD).

## 4. Custo — as quatro perguntas

- **Roda por frame, por tick ou às vezes?** Tick de 20 Hz, dentro de `sim_step`, portanto dentro do
  cronômetro `begin_step`/`end_step` ([main.gd:158-160](../../src/main.gd#L158-L160),
  [sim_clock.gd:32-39](../../src/core/sim_clock.gd#L32-L39)) e dos 50 ms divididos com a difusão e a
  recolha. A lista de vizinhos é construída **uma vez por passo** na sessão, não cinco.
- **Quantas entidades são alcançadas?** `n(n-1)/2` = 10 comparações por passo com 5 lobos; hoje o
  `for w in wolves` já roda 5 ([main.gd:171-172](../../src/main.gd#L171-L172)). Com o censo do
  dossiê 11 (até ~12), vira 66 — ainda uma fração do `sim_step`, mas o número tem de sair no
  rodapé, não na conversa.
- **Aloco no caminho quente?** Sim, e é o débito registrado: o dicionário de blackboard por lobo por
  tick ([:594](../../src/entities/wolf.gd#L594)) passa a carregar uma `Array` nova por lobo. Antes
  de somar qualquer alocação nova, o lote **reaproveita** um buffer por sessão (o mesmo array,
  reescrito a cada passo) — se a solução for alocar cinco arrays por tick, ela não entra.
- **Como sei que ficou melhor?** Pelo budget que já é código: `SubtreeGuard` de 400 µs por mente
  ([:227-229](../../src/entities/wolf.gd#L227-L229)) com `trips` colhido no runner
  ([aether_reactions_test.gd:1011-1012](../../tests/aether_reactions_test.gd#L1011-L1012)). Critério
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
([aether_reactions_test.gd:7-15](../../tests/aether_reactions_test.gd#L7-L15)), hoje 21 cenários):

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
   0,35, [mind.gd:104-105](../../src/ai/mind.gd#L104-L105)); imprime os dois valores.
5. **`alcateia_nao_consome_rng_da_sessao`** — `_population_rng` intacta depois de um passo com
   matilha completa (o contrato do RNG isolado, registrado no status).
6. `EXPECTED_CHECKS` ([aether_reactions_test.gd:19](../../tests/aether_reactions_test.gd#L19), hoje
   **109**) sobe com o lote, e a suíte (hoje **236**) idem — os dois re-medidos no clone limpo com
   `--import` frio antes de virar número publicado.

## 6. O que NÃO fazer

- **Não criar `PackState`, `Alcateia` nem autoload novo.** O dono da matilha é `main.gd` hoje
  ([`_spawn_wolves`](../../src/main.gd#L199-L215), [`wolves`](../../src/main.gd#L171),
  [`_reap_corpses`](../../src/main.gd#L257-L263)); mover posse é o dossiê 06 (K3), e ele só abre
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
