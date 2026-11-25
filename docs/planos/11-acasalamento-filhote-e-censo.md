# 11 — Acasalamento, filhote que cresce e censo variável

Dossiê de **leitura de código**, não de corrida: nenhuma engine rodou aqui e nenhum número
publicado foi re-medido por este arquivo. Autorização do dono em 2026-11-20
([`AGENTS.md`](../../AGENTS.md), extensão de 2026-11-20): "tem algo que não tem no Minecraft: eles
acasalam e aparece um filhote e depois cresce". Décima primeira da série serializada
09 → 10 → **11** → 12 — ela precisa da **10** porque acasalar exige saber quem é adulto, quem está
perto e quem é de fora, e isso é estado de alcateia.

Números de `arquivo:linha` desta página são **ponteiros vivos**: apontam para o código de hoje. As
frases que dizem o que **não** existia são a leitura da `main` em `86e63c4`, antes de qualquer linha
desta perna, e o que passou a existir está anotado na mesma linha. O que a perna entregou, com as
checagens que a sustentam, está na rodada Acasalamento 11 do `docs/melhorias-status.md`.

## 1. Premissas nomeadas

1. **O censo é uma variável real do mundo se um save gravado com 7 lobos carrega 7 lobos.** Na
   leitura desta página o `load` tinha teto por índice **e** inventava sobrevivente:
   `for i in mini(saved.size(), wolves.size()): wolves[i].load_state(saved[i])`, com `wolves` já
   cheio pelos 5 do boot — [`_spawn_wolves`](../../src/main.gd#L387-L423) chamado
   com `WOLF_COUNT` em [:212](../../src/main.gd#L244), constante em
   [:9](../../src/main.gd#L9). Save com 3 lobos → os outros 2 continuavam vivos com o estado do
   boot; save com 7 → 2 filhotes desapareciam no disco. **Falsificável em headless:** gravar com N,
   recarregar, exigir N e exigir que cada identidade carregada bate com a gravada. O load que fecha
   essa premissa pareia por identidade e faz do censo do disco a autoridade
   ([`main.gd:1112-1148`](../../src/main.gd#L1162-L1198).
2. **Crescer é função do tempo de simulação, não de parede.** O relógio é o `SimClock` de 20 Hz
   ([sim_clock.gd:5-7](../../src/core/sim_clock.gd#L5-L7)) e `clock.tick` é o que o journal
   grava ([main.gd:321-327](../../src/main.gd#L352-L358). Um filhote que envelhece por
   `Time.get_ticks_*` não seria reproduzível nem sobreviveria ao `--tick-journal`.
3. **Mandar uma população nova para o disco exige decisão explícita de versão**, não adaptação
   silenciosa: o `FORMAT_VERSION = 1` do journal
   ([tick_journal.gd:4](../../src/persistence/tick_journal.gd#L4)) entra no hash junto com as
   dimensões do Éter e os lobos ordenados por identidade
   ([tick_journal.gd:36](../../src/persistence/tick_journal.gd#L36), projeção mínima descrita em
   [:16-44](../../src/persistence/tick_journal.gd#L16-L44)); o save recusa gerador velho por
   [`gen_version`](../../src/main.gd#L1095) contra [`GEN_VERSION = 4`](../../src/world/world_gen.gd#L6).

## 2. Estado real do código (lido, não medido)

Esta seção inteira é a leitura da `main` em `86e63c4`, antes de qualquer linha desta perna. Quatro
das seis afirmações dizem o que **não** existia; o que existe depois da perna está anotado na mesma
linha, com o ponteiro vivo. Os números de linha desta seção são ponteiros para o código de hoje.

- **A população era constante e só repunha.** `WOLF_COUNT := 5` ([main.gd:9](../../src/main.gd#L9);
  spawn no boot ([:212](../../src/main.gd#L244); a fila de respawn **subtrai** e chama
  `_spawn_wolves(1)` ([main.gd:299-312](../../src/main.gd#L330-L343). Cada lobo nascia com
  `home` sorteado e identidade incrementada
  ([main.gd:356-379](../../src/main.gd#L387-L410); os mortos saem pela recolha de cadáver a cada
  1 s ([`_reap_corpses`](../../src/main.gd#L958-L978), `CORPSE_CHECK_PERIOD` em
  [:31](../../src/main.gd#L31). **Naquela leitura nada nascia por causa interna do mundo.**
  **Hoje o censo é variável e tem teto:** `CENSUS_CAP := 12`
  ([main.gd:18](../../src/main.gd#L18) e o nascimento é
  [`_born_from`](../../src/main.gd#L500-L533), que imprime a recusa quando o censo está no teto
  ([main.gd:472-475](../../src/main.gd#L503-L506) em vez de truncar em silêncio. O letreiro "uma
  nova matilha entrou no vale" já não existia quando esta perna abriu — a 14 o tirou, e o motivo
  está escrito no próprio código.
- **Não existia idade, corpo menor nem fase.** `DIMS := Vector3(0.75, 0.95, 1.35)` era constante e
  ia para o colisor em [`setup`](../../src/entities/wolf.gd#L299-L318)
  ([:96](../../src/entities/wolf.gd#L96), `body.setup(world, p_spawn, dims)`); `MAX_HP = 42.0`
  idem ([:19](../../src/entities/wolf.gd#L19)); as caixas do visual eram medidas fixas em
  [`_build_visual`](../../src/entities/wolf.gd#L1448-L1477) e a animação das quatro patas em
  [`_animate`](../../src/entities/wolf.gd#L1262). Um "filhote" seria um lobo adulto com nome
  diferente. **Hoje existem os três:** `enum Phase { CUB, JUVENILE, ADULT }`
  ([wolf.gd:78](../../src/entities/wolf.gd#L78)), `age_ticks` como estado do animal
  ([:193](../../src/entities/wolf.gd#L193)) e o corpo escalado pela fase
  ([`set_phase`](../../src/entities/wolf.gd#L390-L398), escala em
  [`PHASE_SCALE`](../../src/entities/wolf.gd#L89)); vida e dano de mordida saem da mesma escala
  ([`max_hp`](../../src/entities/wolf.gd#L329-L331),
  [`bite_damage`](../../src/entities/wolf.gd#L338-L340)), e a fase entra na linha de debug
  ([`debug_line`](../../src/entities/wolf.gd#L1346-L1352)).
- **A mente já nasce por semente composta** — `Mind.new("wolf", p_identity, 1000 + p_identity)` e
  `_rng.seed = ("wolf:%d:%d" % [world.gen.world_seed, identity]).hash()`
  ([wolf.gd:311-313](../../src/entities/wolf.gd#L311-L313), o `_rng` declarado em
  [:215](../../src/entities/wolf.gd#L215)). Isso é o que permite um filhote determinístico: a
  identidade nova sorteia temperamento do mesmo jeito.
- **Persistência por lobo existe, e é uma lista fechada de chaves** —
  [`state_dict`](../../src/entities/wolf.gd#L1360-L1373) e
  [`load_state`](../../src/entities/wolf.gd#L1376-L1443). Naquela leitura idade, fase e cooldown de
  acasalamento **não** estavam lá; `load_state` limpa o cache transitório de rastros
  ([:1408](../../src/entities/wolf.gd#L1408), o cache é do lobo e morre no load) —
  comportamento que o contrato registra como transitório por projeto. **Hoje as três chaves
  entram no disco com default explícito** (`phase`, `age_ticks`, `mate_cd`,
  [wolf.gd:1372](../../src/entities/wolf.gd#L1372)), e o load aditivo mantém a ordem da escrita:
  idade, fase, `hp` — porque `set_phase` re-escala a vida, e o `hp` do disco tem de ser lido contra
  o teto novo, não contra o corpo sorteado nesta sessão
  ([wolf.gd:1390-1392](../../src/entities/wolf.gd#L1390-L1392)). Um save anterior ao lote carrega o
  animal como `ADULT`, com `age_ticks` no valor de um adulto
  ([wolf.gd:1390](../../src/entities/wolf.gd#L1390)) e `mate_cd` em 0,0 — "sem chave" não pode
  significar "casado há 300 s" ([wolf.gd:1398](../../src/entities/wolf.gd#L1398)).
- **O journal já enumera lobos** — `record()` recebe `wolves` e a projeção mínima traz os vivos
  ordenados por `wolf.identity` com `mind.identity`, `mind.kind`, `intent` e crenças
  ([tick_journal.gd:16-44](../../src/persistence/tick_journal.gd#L16-L44)). Uma nova chave por lobo
  **não** entra no hash sem decisão de `FORMAT_VERSION`; entra no **save** com default.
- **Onde a checagem antiga quebra, e isso é custo do lote:** na leitura desta página,
  `tests/tick_journal_test.gd:78` exigia `wolves.size() == Main.WOLF_COUNT`; a suíte contava a
  matilha em `smoke_test.gd:250-252` (locomoção), `smoke_test.gd:2751-2768` (cadáver e tamanho da
  matilha) e o áudio em `audio_test.gd:278-279`, `audio_test.gd:305-308`,
  `audio_test.gd:422-424` (`_body_state.size() == wolves.size() + 1`). **Nove sítios** que tratavam
  o censo como constante. Eles não são "consertáveis" com `WOLF_COUNT` maior: viram checagens de
  **invariante** (`vivos <= teto`, `identidades únicas`, `censo gravado == censo carregado`).
  **É o que eles são hoje:** a 14 já trocou a igualdade por "o que não nasce volta para a fila"
  ([tick_journal_test.gd:81-86](../../tests/tick_journal_test.gd#L81-L86),
  [smoke_test.gd:280-283](../../tests/smoke_test.gd#L280-L283)), o áudio compara contagem contra
  contagem ([audio_test.gd:278-279](../../tests/audio_test.gd#L278-L279),
  [:311-314](../../tests/audio_test.gd#L311-L314),
  [:428-430](../../tests/audio_test.gd#L428-L430)) e o cadáver guarda o censo antes e compara depois
  ([smoke_test.gd:3442-3450](../../tests/smoke_test.gd#L3442-L3450)). O censo do disco vira
  propriedade do load — e a checagem 5 do §5 é a que prova que ele fecha.

## 3. O que a peça exige

1. **Fase por lobo**: `enum Phase { CUB, JUVENILE, ADULT }` + `age_ticks`, lidos do `clock.tick`
   que já chega em `sim_step(elapsed, dt)` ([wolf.gd:875](../../src/entities/wolf.gd#L875),
   [main.gd:293-294](../../src/main.gd#L324-L325). Crescimento em **limiares de tick**, não em
   segundos de parede.
2. **Corpo que muda de verdade**: `DIMS` sai de `const` para `var` derivada da fase, com
   `body.setup` re-avaliando o colisor e `_build_visual` escalando as caixas ([:1448-1477](../../src/entities/wolf.gd#L1448-L1477))
   pela mesma razão. `MAX_HP` e dano de mordida por fase, com o número impresso no `debug_line`
   ([:1346](../../src/entities/wolf.gd#L1346)).
3. **Filhote não decide como adulto**: ou fica fora do `Selector` de caça, ou tem uma árvore própria
   (segue a matilha, brinca, não morde). O assento angular da alcateia (dossiê 10) **não** conta
   filhote. Propriedade testável: filhote nunca emite `bit_player`.
4. **Acasalamento**: dois `ADULT` a menos de um raio, ambos acima de um limiar de `hunger`/HP
   (já existem: `hunger` cresce `dt * 0,006` em [wolf.gd:886](../../src/entities/wolf.gd#L886),
   `hp`/`MAX_HP` em [:918](../../src/entities/wolf.gd#L918)), com cooldown **por lobo** e **teto de
   censo**. Quem cria o filhote é a sessão (dono de `wolves` e do `_next_identity` em
   [main.gd:339-355](../../src/main.gd#L370-L386), nunca o próprio lobo — senão o spawn deixa de
   ter um dono único e o dossiê 06 (K3) fica mais caro.
5. **Save aditivo com default explícito**: as chaves novas entram em `state_dict` e `load_state`
   aceita save sem elas (fase = `ADULT`, `age_ticks = 0`). A recusa por `gen_version`
   ([main.gd:1045](../../src/main.gd#L1095) **não** cobre isso: o terreno não mudou, só a
   entidade. O journal: **não** acrescentar chave na projeção mínima sem subir `FORMAT_VERSION`
   [tick_journal.gd:4](../../src/persistence/tick_journal.gd#L4) e escrever a decisão no status —
   os hashes de `a8967e0`/`3ab08db`/`ff347d2` são registros, não rascunho.
   **A decisão, escrita antes do código: `FORMAT_VERSION` continua 1.** A projeção mínima do
   journal monta os lobos por `identity`, `mind.identity`, `mind.kind`, `intent` e `mind.beliefs`
   ([tick_journal.gd:16-44](../../src/persistence/tick_journal.gd#L16-L44)) e **não** lê
   `state_dict()` — fase, idade e cooldown são estado do animal no disco, não projeção do hash.
   A checagem 7 do §5 é o que fecha isso por igualdade de hash, e não uma afirmação.
   **Um desvio do texto acima, com o motivo:** o default de `age_ticks` no load é
   `JUVENILE_STEPS` (4 800), não 0 — `age_ticks = 0` devolveria o animal como filhote
   ([wolf.gd:1390](../../src/entities/wolf.gd#L1390)), e o save gravado antes do lote é de um animal
   que existiu adulto. `phase_of_age(4 800)` devolve `ADULT` pela mesma tabela de limiares
   ([wolf.gd:351-357](../../src/entities/wolf.gd#L351-L357)), e uma fase fora do enum é recusada
   com mensagem em vez de indexar `PHASE_SCALE` fora da tabela
   ([`phase_of_save`](../../src/entities/wolf.gd#L362-L367)).
6. **Load que respeita o censo**: reconstruir a lista a partir do save (spawn → `load_state` por
   identidade, ou limpar e re-criar), com `identidade` como chave de pareamento em lugar de índice.
   O teto de censo tem de valer no load também: save maior que o teto é recusado com mensagem, não
   truncado em silêncio (mandato 1: nada de fallback que finja sucesso).

## 4. Custo — as quatro perguntas

- **Roda por frame, por tick ou às vezes?** Decisão de acasalamento e envelhecimento: **tick de
  20 Hz**, dentro do `sim_step` já cronometrado. O spawn do filhote é evento raro. A locomoção do
  corpo menor continua por frame ([`_physics_process`](../../src/entities/wolf.gd#L1203-L1259)) e não
  ganha trabalho novo.
- **Quantas entidades são alcançadas?** De 5 para `5 + filhotes`, **limitado por teto**. O número
  que importa: cada lobo vivo custa um dicionário de blackboard por tick
  ([:911](../../src/entities/wolf.gd#L911)), uma avaliação de BT por tick
  ([:875-904](../../src/entities/wolf.gd#L875-L904), budget 400 µs em
  [:448-449](../../src/entities/wolf.gd#L448-L449)) e um corpo no F3 (`wolves_roster` em
  [main.gd:843](../../src/main.gd#L874). Teto sugerido e escrito com o motivo: **12**, porque
  12 × 400 µs = 4,8 ms dos 50 ms do passo, e o teto que o gate de P1 ainda escreve como `[TARGET]`
  é 2,5 ms para as árvores — ou seja, **12 é teto de censo, não orçamento de BT liberado**: o
  escalonamento por fase (filhote com árvore mais barata) é o que mantém a soma dentro do número.
- **Aloco no caminho quente?** O acasalamento não aloca; o `_reap_corpses` e a fila de respawn já
  são `Array` com remoção por índice ([main.gd:293-298](../../src/main.gd#L324-L329),
  [:903-923](../../src/main.gd#L958-L978). Spawn novo cria nós em cena — o custo real é de
  `_build_visual` (um `StandardMaterial3D` + ~12 `BoxMesh` por lobo,
  [wolf.gd:1448-1477](../../src/entities/wolf.gd#L1448-L1477)) e acontece **uma vez** por nascimento.
- **Como sei que ficou melhor?** Não é "ficou melhor", é "o censo é real": as checagens do §5. O
  número que tem de continuar válido é o rodapé do runner (colheita estreita de `sim_step` e BT,
  [aether_reactions_test.gd:301-317](../../tests/aether_reactions_test.gd#L332-L348),
  [:1146-1147](../../tests/aether_reactions_test.gd#L1183-L1184) e o `trips == 0` do `SubtreeGuard`.

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
   código da leitura desta página — é o vermelho reproduzido antes do conserto, como o contrato
   pede ([`AGENTS.md`](../../AGENTS.md), ciclo 3). **Onde ela mora hoje:**
   [`_check_censo_disk`](../../tests/smoke_test.gd#L3502-L3558) na suíte, com a premissa montada
   por transições reais — o passo "salvar e carregar" abre o sexto bicho pela porta de povoamento
   da sessão e grava seis no disco. O conserto é o load que pareia por identidade
   ([`main.gd:1112-1148`](../../src/main.gd#L1162-L1198), e o teto do censo no load é recusado com
   mensagem, não truncado em silêncio
   ([main.gd:1066-1069](../../src/main.gd#L1116-L1119).
6. **`censo_respeita_teto`** — acasalamentos forçados até o teto: o censo para em 12 e a recusa é
   impressa, não silenciosa.
7. **`journal_hash_inalterado_sem_escolha`** — rodar o cenário estreito com e sem o lote e comparar
   o hash do tick: **tem de ser igual** se a projeção mínima não mudou. Se divergir, `FORMAT_VERSION`
   subiu, e isso é decisão escrita, não efeito colateral. **A checagem que entrou fecha nos dois
   sentidos** (ciclo 3): o hash **igual** depois do lote (fase, idade e cooldown mudados no animal
   real, com o corpo reescalado), o hash **diferente** quando muda o que está na projeção (mesma
   chave de crença, confiança diferente), as três chaves presentes no `state_dict` com
   `FORMAT_VERSION == 1`, e o caminho do disco reidratando fase, idade e cooldown no bicho certo
   ([`_test_journal_hash_inalterado_sem_escolha`](../../tests/aether_reactions_test.gd#L3867-L3934).

`EXPECTED_CHECKS` ([aether_reactions_test.gd:61](../../tests/aether_reactions_test.gd#L64), **119**
na leitura desta página) e as contagens de suíte (**237 / 0 falhas** na mesma leitura, pin
[`README.md`](../../README.md)) sobem com o lote e são re-medidos no clone limpo com `--import` frio
antes de virar número publicado — e as **nove** citações de censo do §2 re-derivadas no mesmo commit.

**O que o lote mediu nesta ponta:** `EXPECTED_CHECKS` é **225** (a `main` que a perna abriu trazia
198) e a suíte passou a **252 / 0 falhas** — o rodapé do runner de reações é **225 checagens / 0
falhas**. Isso foi medido na **árvore de trabalho** desta ponta. **O número publicado saiu no fecho**,
medido no clone limpo da revisão mescada (`4b858c2`, `--import` frio, exit 0): suíte **252 / 0 /
42,9 s** e runner **225 / 0 / 15,451 s**; a `main` mergeada re-rodada deu **252 / 0 / 43,1 s**, a
`main` do fecho **252 / 0 / 43,0 s** com runner **225 / 0 / 15,348 s** e journal **128 / 0 /
5,769 s**, e o runner da branch **225 / 0 / 15,343 s**. Publicar antes de medir no clone é publicar
hipótese — por isso o fecho espera o clone. O pin publicado é `5b519f8` e os logs estão em
[`docs/evidence/acasalamento-censo-11/readback.md`](../evidence/acasalamento-censo-11/readback.md).

## 6. O que NÃO fazer

- Não transformar `WOLF_COUNT` em número maior e chamar aquilo de população: é a mesma constante
  com outro valor, e o censo continua não sendo variável.
- Não mover a matilha para um `wolf_roster.gd` novo "porque o filhote pede": a posse é o dossiê 06,
  e ele abre com comprador fora de `main.gd`, não com um argumento de elegância.
- Não calcular idade com `Time.get_ticks_msec()`, `elapsed` de parede nem `delta` de frame.
- Não deixar filhote no anel de ataque nem no censo de "lobos vivos" do F3 sem rotular a fase — o
  `debug_line` ([:1346](../../src/entities/wolf.gd#L1346)) é onde a fase aparece.
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

**O que já pousou:** (a) `0850548`, (b) `52ed86a`, (c) `8ceee57`, (d) `c1ea3f9`,
(e) `3e8f9ba`, (f) `fe2fb6d`, (g) `0762b43` — e a `main` do auto-pulo entrando por `010ab25`, o
merge de `e7a5fe7` dentro da branch, porque a perna escreve os mesmos dois arquivos
(`src/entities/wolf.gd` e `tests/aether_reactions_test.gd`) que a 19 escreveu e o item 5 de
"Branches" em [`AGENTS.md`](../../AGENTS.md) obriga a re-rodar o gate na árvore resultante. Entre
(e) e (f) entrou `f33c1d4`, que tira do `state_dict` a promessa de uma medição futura: o comentário
dizia "ainda por medir" e a checagem 7 do gate já existia. O (g) é a re-derivação das nove citações
de censo, a prosa do status, do contrato e desta página.
O `README.md` re-pinado saiu no fecho e não no (g): o pin publicado é o número medido no clone limpo
da revisão **mescada**, e a revisão mescada não existe enquanto (g) não pousar. A perna pousou na
`main` pelo merge `--no-ff` **`4b858c2`** — é esse o pin publicado, e o `README.md` re-pinado aponta
para ele.

A perna pousou na `main` pelo merge `--no-ff` **`4b858c2`**, e o fecho documentado dela pelo merge
`--no-ff` **`5b519f8`** — é esse o pin publicado, e o `README.md` re-pinado aponta para ele. Os dois
merges devolvem os mesmos objetos de `src` e `tests` (`30873d664a9577bcd3e709046cc708923456c372` e
`975eac5a471dc1e064441474ef6e13866076d34f`), porque o fecho trouxe `.md` e `.log` e nenhum `.gd`.

## 8. O que este dossiê não fecha

Nenhum gate de fase. Ecologia de verdade — presa, fome populacional, migração, espécies — é P2 e
continua `[TARGET]`; aqui entra um predador que se reproduz e envelhece, com censo no disco. O
multi-semente (02) e o budget agregado (04) continuam abertos e um censo variável **aumenta** a
dívida dos dois.

## 9. Estado depois do fecho

O que o fecho mediu e o que ele atribuiu, com o número de origem em [`readback.md`](../evidence/acasalamento-censo-11/readback.md):

- **O pin publicado é `5b519f8`** — o merge `--no-ff` do fecho documentado da perna 11
  (`docs/fecho-acasalamento-censo-11`) sobre `4b858c2`, o merge `--no-ff` da branch
  `feat/acasalamento-e-censo-11` (ponta de código `0762b43`) sobre a base `e7a5fe7`. O fecho trouxe
  `.md` e `.log` e nenhum `.gd`, então `5b519f8:src` e `5b519f8:tests` são os mesmos objetos de
  `4b858c2:src` e `4b858c2:tests` — a corrida do clone limpo é também a corrida do pin. O clone
  limpo desse SHA, sem `.godot/` e com `--import` frio (exit 0), deu suíte **252 / 0 / 42,9 s**,
  runner de reações **225 / 0 / 15,451 s** e journal **128 / 0 / 5,811 s**. A `main` mergeada do
  código re-rodada deu **252 / 0 / 43,1 s**; a `main` do fecho, **252 / 0 / 43,0 s** com runner
  **225 / 0 / 15,348 s** e journal **128 / 0 / 5,769 s**; a branch, **252 / 0 / 43,0 s** e runner
  **225 / 0 / 15,343 s**.
- **O par de vazamento do quit não é desta perna.** Ele sai como `4 ObjectDB` com `2 resources` no
  stderr das três corridas e, com `--verbose`, o objeto é nomeado: `AudioStreamPlaybackOggVorbis` e
  `AudioStreamOggVorbis` de `res://assets/audio/amb/amb_birds.ogg`, vivos no instante em que o
  processo morre. O braço de controle na `main` **sem** esta perna (`e7a5fe7`) dá o **mesmo** par,
  maior (**16 ObjectDB** com **6 resources**) — logo ele **precede** a perna 11 e não é dela. Ele
  também varia entre corridas da **mesma** árvore (a primeira do clone sai, a segunda não), o que
  corrige a hipótese do `readback` da perna 19, que atribuía o par ao diretório `user://`.
- **O vermelho intermitente do runner também não é desta perna** (furo #20): a checagem de estouro
  do `SubtreeGuard` mede relógio de parede. Nos quinze braços de controle na `main` sem a perna 11
  saiu **1 vermelho**; sob carga de máquina (`carga_da_maquina.log`) foram **2 vermelhos em 3
  corridas**; em máquina livre e serial, nenhum. O tubo contra arquivo não muda nada
  (`ab_pipes.log`). A atribuição fecha nos dois sentidos: o vermelho aparece **sem** esta perna, e
  a perna sozinha não o produz.
- **O que continua aberto:** o `SubtreeGuard` mede relógio de parede, e a decisão de consertar a
  premissa é do dono; o custo de alocação do caminho quente continua sem medição própria; e o
  orçamento agregado das cinco árvores (P1) não é medido por esta perna — ela mede um runner estreito,
  um lobo por cenário.

O próximo elo da fila depois desta perna é a **16** (a dispersão da matilha em 2–3 tocas), que
depende do censo variável entregue aqui.
