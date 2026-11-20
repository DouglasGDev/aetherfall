# 11 — Acasalamento, filhote que cresce e censo variável

Dossiê de **leitura de código**, não de corrida: nenhuma engine rodou aqui e nenhum número
publicado foi re-medido por este arquivo. Autorização do dono em 2026-11-20
([`AGENTS.md`](../../AGENTS.md), extensão de 2026-11-20): "tem algo que não tem no Minecraft: eles
acasalam e aparece um filhote e depois cresce". Décima primeira da série serializada
09 → 10 → **11** → 12 — ela precisa da **10** porque acasalar exige saber quem é adulto, quem está
perto e quem é de fora, e isso é estado de alcateia.

## 1. Premissas nomeadas

1. **O censo é uma variável real do mundo se um save gravado com 7 lobos carrega 7 lobos.** Hoje o
   `load` tem teto por índice **e** inventa sobrevivente:
   [`for i in mini(saved.size(), wolves.size()): wolves[i].load_state(saved[i])`](../../src/main.gd#L498)
   com `wolves` já cheio pelos 5 do boot
   ([`_spawn_wolves(WOLF_COUNT)`](../../src/main.gd#L142), constante em
   [:9](../../src/main.gd#L9)). Save com 3 lobos → os outros 2 continuam vivos com o estado do
   boot; save com 7 → 2 filhotes desaparecem no disco. **Falsificável em headless:** gravar com N,
   recarregar, exigir N e exigir que cada identidade carregada bate com a gravada.
2. **Crescer é função do tempo de simulação, não de parede.** O relógio é o `SimClock` de 20 Hz
   ([sim_clock.gd:5-7](../../src/core/sim_clock.gd#L5-L7)) e `clock.tick` é o que o journal
   grava ([main.gd:183-189](../../src/main.gd#L183-L189)). Um filhote que envelhece por
   `Time.get_ticks_*` não seria reproduzível nem sobreviveria ao `--tick-journal`.
3. **Mandar uma população nova para o disco exige decisão explícita de versão**, não adaptação
   silenciosa: o `FORMAT_VERSION = 1` do journal
   ([tick_journal.gd:4](../../src/persistence/tick_journal.gd#L4)) entra no hash junto com as
   dimensões do Éter e os lobos ordenados por identidade
   ([tick_journal.gd:36](../../src/persistence/tick_journal.gd#L36), projeção mínima descrita em
   [:16-44](../../src/persistence/tick_journal.gd#L16-L44)); o save recusa gerador velho por
   [`gen_version`](../../src/main.gd#L466) contra [`GEN_VERSION = 4`](../../src/world/world_gen.gd#L6).

## 2. Estado real do código (lido, não medido)

- **População é constante e só repõe.** `WOLF_COUNT := 5` ([main.gd:9](../../src/main.gd#L9));
  spawn no boot ([:142](../../src/main.gd#L142)); a fila de respawn **subtrai** e chama
  `_spawn_wolves(1)` ([main.gd:177-182](../../src/main.gd#L177-L182)) com a mensagem "uma nova
  matilha entrou no vale" ([:182](../../src/main.gd#L182)). Cada lobo nasce com
  `home = _random_ground_point(16.0, 46.0)` e identidade incrementada
  ([main.gd:199-215](../../src/main.gd#L199-L215)); os mortos saem pela recolha de cadáver a cada
  1 s ([`_reap_corpses`](../../src/main.gd#L257-L263), `CORPSE_CHECK_PERIOD` em
  [:16](../../src/main.gd#L16)). **Nada nasce por causa interna do mundo.**
- **Não existe idade, corpo menor nem fase.** `DIMS := Vector3(0.75, 0.95, 1.35)` é constante e vai
  para o colisor em [`setup`](../../src/entities/wolf.gd#L166-L182)
  ([:72](../../src/entities/wolf.gd#L72), `body.setup(world, p_spawn, DIMS)`); `MAX_HP = 42.0`
  idem ([:19](../../src/entities/wolf.gd#L19)); as caixas do visual são medidas fixas em
  [`_build_visual`](../../src/entities/wolf.gd#L709-L739) e a animação das quatro patas em
  [`_animate`](../../src/entities/wolf.gd#L750). Um "filhote" hoje seria um lobo adulto com nome
  diferente.
- **A mente já nasce por semente composta** — `Mind.new("wolf", p_identity, 1000 + p_identity)` e
  `_rng.seed = ("wolf:%d:%d" % [world.gen.world_seed, identity]).hash()`
  ([wolf.gd:175-182](../../src/entities/wolf.gd#L175-L182), o `_rng` declarado em
  [:99](../../src/entities/wolf.gd#L99)). Isso é o que permite um filhote determinístico: a
  identidade nova sorteia temperamento do mesmo jeito.
- **Persistência por lobo existe, e é uma lista fechada de chaves** —
  [`state_dict`](../../src/entities/wolf.gd#L842-L847) e
  [`load_state`](../../src/entities/wolf.gd#L850-L881). Idade, fase e cooldown de acasalamento não
  estão lá; `load_state` hoje limpa o cache transitório de rastros
  ([:850-881](../../src/entities/wolf.gd#L850-L881), o cache é do lobo e morre no load) —
  comportamento que o contrato registra como transitório por projeto.
- **O journal já enumera lobos** — `record()` recebe `wolves` e a projeção mínima traz os vivos
  ordenados por `wolf.identity` com `mind.identity`, `mind.kind`, `intent` e crenças
  ([tick_journal.gd:16-44](../../src/persistence/tick_journal.gd#L16-L44)). Uma nova chave por lobo
  **não** entra no hash sem decisão de `FORMAT_VERSION`; entra no **save** com default.
- **Onde a checagem antiga quebra, e isso é custo do lote:**
  [tests/tick_journal_test.gd:78](../../tests/tick_journal_test.gd#L78) exige
  `wolves.size() == Main.WOLF_COUNT`; a suíte conta a matilha em
  [smoke_test.gd:189-193](../../tests/smoke_test.gd#L189-L193) (locomoção), `:2254-2271` (cadáver e
  tamanho da matilha) e o áudio em
  [audio_test.gd:278-279](../../tests/audio_test.gd#L278-L279), `:305-308`,
  [:422-424](../../tests/audio_test.gd#L422-L424) (`_body_state.size() == wolves.size() + 1`).
  **Nove sítios** que tratam o censo como constante. Eles não são "consertáveis" com `WOLF_COUNT`
  maior: viram checagens de **invariante** (`vivos <= teto`, `identidades únicas`, `censo gravado ==
  censo carregado`).

## 3. O que a peça exige

1. **Fase por lobo**: `enum Phase { CUB, JUVENILE, ADULT }` + `age_ticks`, lidos do `clock.tick`
   que já chega em `sim_step(elapsed, dt)` ([wolf.gd:563](../../src/entities/wolf.gd#L563),
   [main.gd:171-172](../../src/main.gd#L171-L172)). Crescimento em **limiares de tick**, não em
   segundos de parede.
2. **Corpo que muda de verdade**: `DIMS` sai de `const` para `var` derivada da fase, com
   `body.setup` re-avaliando o colisor e `_build_visual` escalando as caixas ([:709-739](../../src/entities/wolf.gd#L709-L739))
   pela mesma razão. `MAX_HP` e dano de mordida por fase, com o número impresso no `debug_line`
   ([:830](../../src/entities/wolf.gd#L830)).
3. **Filhote não decide como adulto**: ou fica fora do `Selector` de caça, ou tem uma árvore própria
   (segue a matilha, brinca, não morde). O assento angular da alcateia (dossiê 10) **não** conta
   filhote. Propriedade testável: filhote nunca emite `bit_player`.
4. **Acasalamento**: dois `ADULT` a menos de um raio, ambos acima de um limiar de `hunger`/HP
   (já existem: `hunger` cresce `dt * 0,006` em [wolf.gd:572](../../src/entities/wolf.gd#L572),
   `hp`/`MAX_HP` em [:599](../../src/entities/wolf.gd#L599)), com cooldown **por lobo** e **teto de
   censo**. Quem cria o filhote é a sessão (dono de `wolves` e do `_next_identity` em
   [main.gd:199-215](../../src/main.gd#L199-L215)), nunca o próprio lobo — senão o spawn deixa de
   ter um dono único e o dossiê 06 (K3) fica mais caro.
5. **Save aditivo com default explícito**: as chaves novas entram em `state_dict` e `load_state`
   aceita save sem elas (fase = `ADULT`, `age_ticks = 0`). A recusa por `gen_version`
   ([main.gd:466-468](../../src/main.gd#L466-L468)) **não** cobre isso: o terreno não mudou, só a
   entidade. O journal: **não** acrescentar chave na projeção mínima sem subir `FORMAT_VERSION`
   [tick_journal.gd:4](../../src/persistence/tick_journal.gd#L4) e escrever a decisão no status —
   os hashes de `a8967e0`/`3ab08db`/`ff347d2` são registros, não rascunho.
6. **Load que respeita o censo**: reconstruir a lista a partir do save (spawn → `load_state` por
   identidade, ou limpar e re-criar), com `identidade` como chave de pareamento em lugar de índice.
   O teto de censo tem de valer no load também: save maior que o teto é recusado com mensagem, não
   truncado em silêncio (mandato 1: nada de fallback que finja sucesso).

## 4. Custo — as quatro perguntas

- **Roda por frame, por tick ou às vezes?** Decisão de acasalamento e envelhecimento: **tick de
  20 Hz**, dentro do `sim_step` já cronometrado. O spawn do filhote é evento raro. A locomoção do
  corpo menor continua por frame ([`_physics_process`](../../src/entities/wolf.gd#L702-L747)) e não
  ganha trabalho novo.
- **Quantas entidades são alcançadas?** De 5 para `5 + filhotes`, **limitado por teto**. O número
  que importa: cada lobo vivo custa um dicionário de blackboard por tick
  ([:594](../../src/entities/wolf.gd#L594)), uma avaliação de BT por tick
  ([:409-433](../../src/entities/wolf.gd#L409-L433), budget 400 µs em
  [:227-229](../../src/entities/wolf.gd#L227-L229)) e um corpo no F3 (`wolves_roster` em
  [main.gd:275](../../src/main.gd#L275)). Teto sugerido e escrito com o motivo: **12**, porque
  12 × 400 µs = 4,8 ms dos 50 ms do passo, e o teto que o gate de P1 ainda escreve como `[TARGET]`
  é 2,5 ms para as árvores — ou seja, **12 é teto de censo, não orçamento de BT liberado**: o
  escalonamento por fase (filhote com árvore mais barata) é o que mantém a soma dentro do número.
- **Aloco no caminho quente?** O acasalamento não aloca; o `_reap_corpses` e a fila de respawn já
  são `Array` com remoção por índice ([main.gd:177-182](../../src/main.gd#L177-L182),
  [:257-263](../../src/main.gd#L257-L263)). Spawn novo cria nós em cena — o custo real é de
  `_build_visual` (um `StandardMaterial3D` + ~12 `BoxMesh` por lobo,
  [wolf.gd:709-748](../../src/entities/wolf.gd#L709-L748)) e acontece **uma vez** por nascimento.
- **Como sei que ficou melhor?** Não é "ficou melhor", é "o censo é real": as checagens do §5. O
  número que tem de continuar válido é o rodapé do runner (colheita estreita de `sim_step` e BT,
  [aether_reactions_test.gd:178-194](../../tests/aether_reactions_test.gd#L178-L194),
  [:1011-1012](../../tests/aether_reactions_test.gd#L1011-L1012)) e o `trips == 0` do `SubtreeGuard`.

## 5. Gate em headless

```sh
godot --headless --path . --check-only --script src/entities/wolf.gd
godot --headless --path . tests/smoke_test.tscn
godot --headless --path . --script tests/tick_journal_test.gd
```

Checagens:

1. **`acasalar_aumenta_censo`** — dois adultos próximos, cooldown zerado, N passos: `wolves.size()`
   cresce **1** e o novo é `CUB`. Imprime censo antes/depois e a fase.
2. **`cooldown_segunda_copula`** — o mesmo par não gera duas vezes seguidas sem o cooldown
   vencer. Imprime o valor do cooldown.
3. **`filhote_cresce_por_tick`** — avançar ticks cruza os limiares `CUB → JUVENILE → ADULT`, e a
   `DIMS` colide com a fase. Imprime `age_ticks`, fase e dimensões.
4. **`filhote_nao_morde`** — cenário com filhote e jogador ao alcance: nenhuma emissão de
   `bit_player` vinda dele.
5. **`load_leva_todo_o_censo`** — gravar com N (inclusive N > 5), recarregar, `wolves.size() == N`
   e cada `identity` do disco confere com a mente carregada. **Esta checagem nasce vermelha** no
   código atual (`:410` tem teto) — é o vermelho reproduzido antes do conserto, como o contrato
   pede ([`AGENTS.md`](../../AGENTS.md), ciclo 3).
6. **`censo_respeita_teto`** — acasalamentos forçados até o teto: o censo para em 12 e a recusa é
   impressa, não silenciosa.
7. **`journal_hash_inalterado_sem_escolha`** — rodar o cenário estreito com e sem o lote e comparar
   o hash do tick: **tem de ser igual** se a projeção mínima não mudou. Se divergir, `FORMAT_VERSION`
   subiu, e isso é decisão escrita, não efeito colateral.

`EXPECTED_CHECKS` ([aether_reactions_test.gd:19](../../tests/aether_reactions_test.gd#L19), hoje
**109**) e as contagens de suíte (hoje **236 / 0 falhas**, pin [`README.md`](../../README.md)) sobem
com o lote e são re-medidos no clone limpo com `--import` frio antes de virar número publicado — e
as **nove** citações de censo do §2 re-derivadas no mesmo commit.

## 6. O que NÃO fazer

- Não transformar `WOLF_COUNT` em número maior e chamar aquilo de população: é a mesma constante
  com outro valor, e o censo continua não sendo variável.
- Não mover a matilha para um `wolf_roster.gd` novo "porque o filhote pede": a posse é o dossiê 06,
  e ele abre com comprador fora de `main.gd`, não com um argumento de elegância.
- Não calcular idade com `Time.get_ticks_msec()`, `elapsed` de parede nem `delta` de frame.
- Não deixar filhote no anel de ataque nem no censo de "lobos vivos" do F3 sem rotular a fase — o
  `debug_line` ([:830](../../src/entities/wolf.gd#L830)) é onde a fase aparece.
- Não gravar idade nova no hash do journal por conveniência. O journal é apêndice-only e recusa
  caminho existente ([tick_journal.gd:47-62](../../src/persistence/tick_journal.gd#L47-L62),
  [:69-87](../../src/persistence/tick_journal.gd#L69-L87)): mudar a projeção é mudar o registro
  histórico das rodadas publicadas.

## 7. Commits atômicos

(a) fase + `DIMS` por fase com a checagem 3; (b) `state_dict`/`load_state` com as chaves novas e a
5 **vermelha**; (c) load que respeita censo, com a 5 verde; (d) acasalamento + cooldown + teto com
1, 2 e 6; (e) filhote fora da árvore de caça com 4; (f) journal: decisão de `FORMAT_VERSION`
registrada, com 7; (g) re-derivação das nove citações de censo + status + `README.md` re-pinado.
Branch `feat/acasalamento-e-censo-11`, merge `--no-ff`.

## 8. O que este dossiê não fecha

Nenhum gate de fase. Ecologia de verdade — presa, fome populacional, migração, espécies — é P2 e
continua `[TARGET]`; aqui entra um predador que se reproduz e envelhece, com censo no disco. O
multi-semente (02) e o budget agregado (04) continuam abertos e um censo variável **aumenta** a
dívida dos dois.
