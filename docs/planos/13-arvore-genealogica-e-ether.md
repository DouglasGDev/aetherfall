# 13 — Árvore genealógica de todo ser vivo, e o Éter lendo parentesco

Dossiê de **leitura de código**, não de corrida: nenhuma engine rodou aqui e nenhum número
publicado foi re-medido por este arquivo. Autorização do dono em 2026-11-20, segunda extensão
([`AGENTS.md`, "Escopo autorizado agora"](../../AGENTS.md)): "trabalhe arvore genealogica de todo
ser vivo … animais menos complexo, npcs se tiver, mais complexo … quero fazer o ether trabalhar bem
isso". Última perna da fila serializada **09 → 10 → 14 → 11 → 12 → 13**, ordem registrada **antes**
do código: sem a 11 não há nascimento por causa interna (o que escrever na árvore), sem a 10 não há
leitura de vizinho (como parentesco vira comportamento), e deixar uma mudança de `Channel.COUNT` no
meio da fila custaria re-mediar as cinco pernas anteriores. Escopo lido antes de prometer nível:
`src/entities/` tem [player](../../src/entities/player.gd),
[player_avatar](../../src/entities/player_avatar.gd), [fp_viewmodel](../../src/entities/fp_viewmodel.gd),
[voxel_body](../../src/entities/voxel_body.gd) e [wolf](../../src/entities/wolf.gd) — **nenhum NPC**,
**uma única espécie animal** e o jogador sem `Mind` nem `identity` (grep devolve zero ocorrências dos
dois nomes em [player.gd](../../src/entities/player.gd)). "Todo ser vivo" é hoje: cinco mentes
lobinas e um corpo sem mente. As citações são contra a `main` em `eb6ec8d`; a árvore de trabalho já
trazia a 10 em curso, e o que ela moveu está registrado no §9.

## 1. Premissas nomeadas

1. **Um lobo só tem ascendência registrada se dois adultos gerarem um filhote cujo `parents` aponta
   para as identidades deles, se isso sobreviver a gravar e recarregar do disco, e se mudar algo
   observável no mundo.** Forma falsificável em headless: dois filhotes no **mesmo bioma** com pais
   diferentes têm de sair com hex de pelo diferente, e um lobo que encontra um rastro tem de poder
   dizer **de quem** é aquele rastro. Hoje nenhuma frase é pronunciável:
   [`setup`](../../src/entities/wolf.gd#L240-L241) não recebe ascendência, e o
   [`imprint`](../../src/world/aether_field.gd#L87-L89) guarda um float por célula sem autor. Uma
   genealogia que não mexe em nada observável é decoração — é por isso que esta é a premissa que
   morde.
2. **Herança não é memória.** A personalidade é sorteada da semente do **próprio** lobo
   ([`Mind.new("wolf", p_identity, 1000 + p_identity)`](../../src/entities/wolf.gd#L254), sorteio em
   [mind.gd:30-32](../../src/ai/mind.gd#L30-L32)) e depois **mutada por experiência**
   ([`_drift`](../../src/ai/mind.gd#L50-L58)). Nenhum pai contribui com nada. Logo herda-se um
   genoma-base imutável, nunca o valor vivo — senão o filhote nasceria com o trauma do pai.
3. **Parentesco que o campo não registra não existe para o nariz.** É essa a decisão de versão do
   §3.3, e a única parte daqui que pode tocar
   [`Channel.COUNT`](../../src/world/aether_field.gd#L9) e
   [`FORMAT_VERSION`](../../src/persistence/tick_journal.gd#L4) — ambos **dentro** do hash
   ([tick_journal.gd:36-39](../../src/persistence/tick_journal.gd#L36-L39)).

## 2. Estado real do código (lido, não medido)

- **Não existe linhagem em lugar nenhum**: `grep -i "parent|filhote|linhagem|offspring"` em `src/`
  devolve só `cubo`. O identificador único é um inteiro solto
  ([`var identity: int = 0`](../../src/entities/wolf.gd#L130)), incrementado pela sessão
  ([`_next_identity`](../../src/main.gd#L63), em
  [`_spawn_wolves`](../../src/main.gd#L335-L375)), e a RNG do lobo vem de
  `("wolf:%d:%d" % [world.gen.world_seed, identity]).hash()`
  ([:252](../../src/entities/wolf.gd#L252)) — pai nenhum entra em nenhuma das duas contas.
- **O pelo é ambiente, não herança**: `FUR_COLORS`
  ([:119-124](../../src/entities/wolf.gd#L119-L124)) indexada pelo bioma do `home`
  ([:250](../../src/entities/wolf.gd#L250)), aplicada em
  [`_build_visual`](../../src/entities/wolf.gd#L1184) e **re-derivada no load**
  ([:1119-1121](../../src/entities/wolf.gd#L1119-L1121)). O par já tem gate da rodada 09 — dois lobos em
  biomas diferentes com cores diferentes, dois no mesmo bioma com a mesma
  ([aether_reactions_test.gd:1607-1625](../../tests/aether_reactions_test.gd#L1607-L1625)). Herança
  que mutar o pelo de **fundador** passa por cima de um gate fechado.
- **Save e projeção.** O lobo persiste oito chaves fechadas
  ([`state_dict`](../../src/entities/wolf.gd#L1099-L1104)), o `load_state` lê com default
  ([`d.get`](../../src/entities/wolf.gd#L1132-L1145)), o precedente aditivo da casa é o `inv`
  ([main.gd:1066-1071](../../src/main.gd#L1066-L1071)) e [`SCHEMA = 1`](../../src/persistence/save_manager.gd#L8)
  recusa só schema **mais novo** ([:69-71](../../src/persistence/save_manager.gd#L69-L71)). Na
  leitura deste dossiê o load ainda pareava por índice com teto
  (`mini(saved.size(), wolves.size())`): enquanto a 11 não fechasse, um censo que crescesse
  descartaria filhote em silêncio e a árvore não teria o que gravar. **A 11 já fechou isso** — o
  load pareia por identidade e faz do censo do disco a autoridade
  ([`main.gd:1091-1127`](../../src/main.gd#L1091-L1127)), e a árvore genealógica passa a ter o que
  gravar. Na projeção do
  journal, lobos vivos ordenados por `identity` com `mind.identity`, `mind.kind`, `intent` e crenças
  por chave ([tick_journal.gd:26-35](../../src/persistence/tick_journal.gd#L26-L35)): **chave nova de
  crença é dado, coluna nova de metadados é esquema**, e o journal recusa caminho existente
  ([:47-62](../../src/persistence/tick_journal.gd#L47-L62)) porque os hashes publicados são registro.
- **O Éter não sabe quem escreveu.** `_cur` é um `PackedFloat32Array` achatado
  ([aether_field.gd:31](../../src/world/aether_field.gd#L31), alocado em
  [:49-50](../../src/world/aether_field.gd#L49-L50)); a difusão empurra massa sem autoria
  ([:130-142](../../src/world/aether_field.gd#L130-L142)); `total_energy()` soma **todos** os canais
  ([:179-183](../../src/world/aether_field.gd#L179-L183)) e é o `aether_energy` pinado em
  [README.md:197](../../README.md#L197) (`9,44745890423656`) e em seis notas do status; o F3 imprime
  três canais por nome fixo ([hud.gd:260-261](../../src/ui/hud.gd#L260-L261)).
- **Ler os outros já tem precedente sem acoplamento**: o jogador recebe
  [`entity_provider`](../../src/entities/player.gd#L91) montado pela sessão
  ([main.gd:150](../../src/main.gd#L150)), e a alcateia entra pelo mesmo caminho (dossiê 10 §3.1). Para
  árvore, isso quer dizer **inteiros, nunca referências**.
- **NPC é `[TARGET]`, não lacuna a preencher**: [docs/design/06:40-41](../design/06-godot-architecture.md#L40-L41)
  descreve NPCs como `RefCounted` no `SimWorld`,
  [docs/design/06:101](../design/06-godot-architecture.md#L101) põe *sites* (aldeias) no gerador
  futuro, [docs/design/08:92](../design/08-roadmap-risks-licensing.md#L92) põe ecologia em P2.
  `BeliefVerifier` e `Rumor`, que o grounding `[DECIDED]` de
  [docs/design/04:97-99](../design/04-local-ai-architecture.md#L97-L99) exige, não existem.

## 3. O que a peça exige

1. **Primitivo mínimo com dono.** Três campos de dados no lobo: `parents: Array` (dois `int`, `-1` =
   fundador), `gen: int` (0 = fundador) e `genome: Array` (os três temperamentos-base). Quem escreve
   é a sessão **no ponto onde a 11 cria o filhote**, nunca o próprio lobo. **O que a leitura deste
   dossiê não previa:** `_spawn_wolves` era o único criador. Hoje o caminho único é
   [`_make_wolf`](../../src/main.gd#L375-L398), que serve ao sorteio
   ([`_spawn_wolves`](../../src/main.gd#L335-L358)), ao nascimento
   ([`_born_from`](../../src/main.gd#L448-L481)) e ao disco
   ([`load_game`](../../src/main.gd#L1027-L1085)) — e a ascendência entra por parâmetro nesse caminho
   único, porque os pais são sabidos no nascimento e no disco, e o sorteio não os tem. A "árvore" é
   **derivação
   sob demanda** do roster ([`wolves_roster`](../../src/main.gd#L821-L822)): nenhum objeto novo,
   nenhuma travessia por tick, e só um segundo comprador justificaria arquivo próprio (regra da casa:
   generalize no segundo chamador).
2. **Determinismo sem relógio de parede.** Genoma de um RNG **local** semeado por
   `("lineage:%d:%d:%d:%d" % [world.gen.world_seed, pai, mae, filho]).hash()`, no precedente exato de
   [wolf.gd:252](../../src/entities/wolf.gd#L252). O `_population_rng` da sessão
   ([main.gd:64](../../src/main.gd#L64), semeado em [:337-338](../../src/main.gd#L337-L338)) não pode
   ser consumido por decisão de acasalamento, e nenhum `Time.get_ticks_*` entra aí. Fundador mantém o
   sorteio atual de `Mind._init` — é o que deixa os gates de 09 e 11 verdes.
3. **O que o Éter faz com isso — as quatro opções com preço, e uma recomendada.**
   - **(a) reaproveitar BLOOD/WORK como assinatura de parentesco: rejeitada.** Mudaria a seleção
     `BLOOD + 0,35 × WORK` do nariz
     ([wolf.gd:909-922](../../src/entities/wolf.gd#L909-L922)) — o caminho exato da ablação de seis
     braços medida (324 159 / 427 537 / 363 680 µs em 2 768 passos,
     [`AGENTS.md`](../../AGENTS.md) "Leitor de rastros"): exige re-baseline de toda a evidência
     publicada **e** mente sobre a semântica, porque nada sangrou por ser parente.
   - **(b) canal novo `KIN`: tem preço explícito, não recomendado agora.** `Channel.COUNT` 3→4 leva
     `_cur`/`_nxt` de 49 152 para 65 536 floats e `state_bytes()` de **196 608 para 262 144
     bytes/tick** (+33,3 %; aritmética derivada de
     [aether_field.gd:45-50](../../src/world/aether_field.gd#L45-L50) sobre 32×16×32 células de
     [voxel_config.gd:5-16](../../src/world/voxel_config.gd#L5-L16)); pede quarta linha/coluna em
     `HALF_LIFE`, `DIFFUSE_RATE`, `CHANNEL_NAMES`
     ([:11-15](../../src/world/aether_field.gd#L11-L15)), em `IMPRINT_BIAS`
     ([world_gen.gd:45-50](../../src/world/world_gen.gd#L45-L50)), na cópia literal pinada
     `BIAS_MEDIDA` ([aether_reactions_test.gd:43-48](../../tests/aether_reactions_test.gd#L43-L48)) e
     na cor do viz ([aether_viz.gd:12-16](../../src/rendering/aether_viz.gd#L12-L16)); **e** como
     `Channel.COUNT` está no array hash-eado
     ([tick_journal.gd:38](../../src/persistence/tick_journal.gd#L38)), é subida de `FORMAT_VERSION`,
     o que quebra a comparação de hashes das cinco pernas anteriores e move todo número de
     `aether_energy`. Decisão escrita no status, não detalhe de implementação.
   - **(c) parentesco como crença (`mind.beliefs`): necessário, insuficiente como registro.** Entra
     como **dado** dentro da projeção ([:29-35](../../src/persistence/tick_journal.gd#L29-L35)),
     então `FORMAT_VERSION` **não** sobe — mas o hash de um run com nascimento se move
     legitimamente, e é isso que a checagem 6 protege. Insuficiente porque crença **decai e é
     apagada** ([`decay`](../../src/ai/mind.gd#L108-L119), `CONFIDENCE_MIN = 0,02` em
     [:9](../../src/ai/mind.gd#L9), meia-vida de `BELIEF_DECAY_PER_MIN = 0,14` em
     [:8](../../src/ai/mind.gd#L8)): parentesco não some em cinco minutos de jogo. Serve como
     **leitura**, nunca como **verdade** — e sozinha é enfeite.
   - **(d) recomendada — proveniência por célula, sem canal novo.** Um `PackedInt32Array _source` de
     `_per_channel` ints (16 384 × 4 = **65 536 bytes** residentes, +16,7 % sobre os 393 216 bytes
     atuais de `_cur` + `_nxt`), escrito pelo `imprint`
     ([aether_field.gd:87-89](../../src/world/aether_field.gd#L87-L89)) e propagado pelo laço de
     empurrão sob regra **nomeada**: "a célula passa a pertencer ao autor da maior massa recebida;
     empate, menor `identity` vence" — determinística, sem ordem de `Dictionary`. Ela **não** entra em
     [`state_bytes()`](../../src/world/aether_field.gd#L232-L234), e a consequência honesta dessa
     exclusão está dita aqui: o journal passa a não distinguir dois campos com os mesmos valores e
     autores diferentes, então **árvore genealógica nunca é provável pelo journal** — é provável pelo
     save, onde entra como sexto elemento de cada célula ativa, com default `-1` para save velho
     ([`to_dict`](../../src/world/aether_field.gd#L212-L217),
     [`from_dict`](../../src/world/aether_field.gd#L220-L229)) — aditivo, sem subida de `SCHEMA`. O
     leitor é o nariz que já existe: nas células que o scan **já visita**
     ([`_find_scent`](../../src/entities/wolf.gd#L890-L930)) o lobo consulta o autor, e só quando o
     autor é pai/filho/irmão escreve a crença de (c). Assim o Éter participa de forma observável, o
     BT continua decidido por regra (mandato 2) e `FORMAT_VERSION` fica 1.
   - Pré-condição de (d), na ordem da casa (colheita antes do corte): **nenhum µs de
     `diffuse_and_decay` existe hoje** (dossiê 05, [`docs/planos/README.md`](README.md) linha 05),
     então o commit (a) deste lote é a colheita, não a propagação.
4. **Escada de complexidade, `[TARGET]` em três dos quatro degraus.** Animal simples (lobo): `parents`
   + `gen` + `genome`, nada além. Jogador: sem `Mind` hoje, então sua ascendência exige primeiro uma
   mente — `[TARGET]`, zero código. NPC: **não existe**; linhagem, casa/linhagem e possessões ficam
   `[TARGET]` em [docs/design/06:40-41](../design/06-godot-architecture.md#L40-L41) e não recebem
   estrutura antes do segundo comprador. A escada é uma frase no documento, não uma classe.
5. **Herança de traços, com as regras que a impedem de mentir.** (i) Temperamentos: herda-se o
   `genome`, `personality` começa igual a ele e **depois** deriva como hoje; ao acasalar lê-se só
   `genome` — a checagem 4 prova isso com número. Como `from_dict` restaura a personalidade inteira
   ([mind.gd:155](../../src/ai/mind.gd#L155)), fundador sem genoma mantém o valor carregado: nada é
   re-desenhado no load. (ii) Pelo: só com `parents != [-1,-1]` a cor deixa de ser pura do bioma e
   vira mistura das cores dos pais com o bioma como prior; fundador fica 100 % na regra de 09 (a
   checagem 2 guarda isso). (iii) Corpo e HP: `DIMS`
   ([wolf.gd:96](../../src/entities/wolf.gd#L96)) e `MAX_HP` ([:19](../../src/entities/wolf.gd#L19))
   são `const` hoje — só a 11 os transforma em valor por fase, e a herança entra como **multiplicador
   limitado** em cima daquela fase, nunca como constante nova; sem a 11 pousada, este item é
   `[TARGET]`.

## 4. Custo — as quatro perguntas

- **Roda por frame, por tick ou às vezes?** Ascendência é escrita em **evento** (nascimento pela
  sessão; [`load_state`](../../src/entities/wolf.gd#L1115-L1163)) e lida na cadência que já existe:
  `_find_scent` a cada `SCENT_PERIOD = 0,25 s`
  ([:30](../../src/entities/wolf.gd#L30), gated em [:857-858](../../src/entities/wolf.gd#L857-L858))
  — 4×/s por lobo, dentro do passo de 50 ms cronometrado
  ([sim_clock.gd:5-7](../../src/core/sim_clock.gd#L5-L7),
  [main.gd:259-261](../../src/main.gd#L259-L261)). A propagação de autoria cai na passada de difusão,
  4×/s ([main.gd:27](../../src/main.gd#L27), [:267-270](../../src/main.gd#L267-L270)), não 20×.
  **Nada** novo em [`_physics_process`](../../src/entities/wolf.gd#L950-L998).
- **Quantas entidades são alcançadas?** 5 lobos hoje ([`WOLF_COUNT`](../../src/main.gd#L9)), até o
  teto de censo que a 11 escrever (12). A consulta de autoria não visita célula nova: no máximo
  **147 subscriptos de inteiro por scan** (49 da camada própria + 98 das duas vizinhas, a mesma conta
  de varredura da ablação), ≤2 940/s com a matilha inteira — **derivado do código, não medido**. A
  matriz é por célula do campo, não por lobo: 16 384 ints.
- **Aloco no caminho quente?** Zero alocação nova se `_source` nascer no `setup()` do campo, no
  precedente do scratch reusado `_nb_i`/`_nb_w`
  ([aether_field.gd:37-39](../../src/world/aether_field.gd#L37-L39), alocado em
  [:42-54](../../src/world/aether_field.gd#L42-L54)); a crença reaproveita o `Dictionary` de
  [`reinforce`](../../src/ai/mind.gd#L86-L92). O débito registrado do blackboard novo por lobo por
  tick ([wolf.gd:842](../../src/entities/wolf.gd#L842)) **não pode crescer**: se a leitura precisar de
  lista por lobo, usa o buffer único por passo que a 10 §4 mandou — se não couber aí, não entra.
- **Como sei que ficou melhor, e o log existe em headless?** Não é "melhor", é "a ascendência existe
  e é legível": checagens do §5 no runner que já existe, o rodapé de colheita
  ([aether_reactions_test.gd:1680-1684](../../tests/aether_reactions_test.gd#L1680-L1684)) e o
  `trips == 0` do `SubtreeGuard` de 400 µs
  ([wolf.gd:389-390](../../src/entities/wolf.gd#L389-L390)). O HOT agregado dos cinco lobos (04) e os
  µs de difusão (05) seguem sem medição: nada aqui fecha P1, e a checagem 6 é o trip-wire de versão.

## 5. Gate em headless

```sh
godot --headless --path . --check-only --script src/entities/wolf.gd
godot --headless --path . --script tests/aether_reactions_test.gd
godot --headless --path . tests/smoke_test.tscn
godot --headless --path . --script tests/tick_journal_test.gd
```

Cenários novos no runner dedicado (`TESTS`, hoje 24,
[aether_reactions_test.gd:7-21](../../tests/aether_reactions_test.gd#L7-L21)):

1. **`genealogia_muda_algo_observavel`** — quantos pares de lobos no mesmo bioma têm pelo diferente
   **sem** serem fundador: o API atual não permite passar pais, então o número é `pares_diferentes=0`
   e a checagem **nasce vermelha** com os dois hex impressos. Vermelho reproduzido antes do conserto
   (ciclo 3 do contrato), e é a premissa 1 dita em termos que existem hoje.
2. **`pelo_de_fundador_vem_do_bioma`** — guarda-regressão do gate de 09: fundador (pais em `-1`)
   bate a cor da tabela; imprime os dois hex e o bioma da coluna. Nasce verde e **tem de
   continuar verde**.
3. **`load_preserva_ascendencia`** — nascimento real (exige 11), gravar, recarregar, conferir
   `parents`/`gen`/`genome` identidade por identidade; imprime `chaves_de_ascendencia_no_save=N/8`.
   **Nasce vermelha** no `state_dict` de hoje, que tem oito chaves e nenhuma é linhagem.
4. **`heranca_nao_repete_deriva`** — um [`take_damage`](../../src/entities/wolf.gd#L1027) no pai antes
   do acasalamento deriva a personalidade por [`_drift`](../../src/ai/mind.gd#L50-L58): o genoma do
   filhote tem de igualar o **base** do pai, não o valor vivo. Imprime base, derivado e herdado.
5. **`eter_devolve_quem_sangrou`** — mordida real, leitura pelo `_find_scent` do filho: a autoria da
   célula escolhida tem de ser a identidade do agressor, e a crença de parentesco cruza a soleira de
   [`believes()` 0,35`](../../src/ai/mind.gd#L104-L105). Imprime
   `fonte_lida=%d esperado=%d confianca=%.2f`. Sem (d) não há o que imprimir: é o número que prova
   que (c) sozinha é enfeite.
6. **`journal_hash_inalterado_sem_nascimento`** — cenário estreito com o primitivo presente, sem
   nascimento e sem leitura de parentesco no caminho: hash por tick **igual** ao da revisão anterior.
   Divergiu, ou `Channel.COUNT` mudou ou a autoria entrou na projeção — nos dois casos é decisão de
   `FORMAT_VERSION` escrita no status, não efeito colateral. Imprime os dois hashes em hex.
7. **`genealogia_nao_consome_rng_da_sessao`** — `_population_rng` intacta depois de um nascimento;
   espelho de `alcateia_nao_consome_rng_da_sessao` (dossiê 10 §5).
8. **`ascendencia_e_int_nao_referencia`** — o filho lê os próprios pais depois de `free()` do pai
   (padrão dos lobos soltos do runner,
   [aether_reactions_test.gd:1559-1565](../../tests/aether_reactions_test.gd#L1559-L1565),
   [:1612-1613](../../tests/aether_reactions_test.gd#L1612-L1613)); imprime `pais=[..] pai_valido=false`.

`EXPECTED_CHECKS` ([aether_reactions_test.gd:39](../../tests/aether_reactions_test.gd#L39), **119**
na leitura desta página) e o rodapé da suíte (**237 checagens / 0 falhas / 35,5 s** na mesma leitura,
pin [README.md:192](../../README.md#L192)) sobem com o lote e são **re-medidos** no clone limpo com
`--import` frio antes de virar número publicado — nunca herdados.

## 6. O que NÃO fazer

- **Nenhum autoload ou singleton novo** de genealogia: a posse do roster é `main.gd`
  ([`wolves`](../../src/main.gd#L57)), e mover posse é o dossiê 06 (K3), que abre com comprador fora
  de `main.gd`.
- **Nenhum objeto deus `Species`/`Genealogy`/`FamilyTree` na árvore de cena** com travessia por tick:
  a árvore é derivação sobre três ints e três floats por lobo.
- **Nenhuma árvore antes da 11**: sem nascimento por causa interna, `parents` seria campo escrito à
  mão pela suíte — exatamente o que o contrato proíbe.
- **Nenhum canal novo por conveniência** (preço no §3.3, exige `FORMAT_VERSION` e linha no status).
- **Nenhum oráculo/LLM sugerindo ascendência** (mandato 2): a única saída de `MindOracle` é
  `_narrations` ([mind_oracle.gd:47](../../src/ai/mind_oracle.gd#L47), gravada em
  [:176](../../src/ai/mind_oracle.gd#L176)), lida por
  [`narration_of`](../../src/ai/mind_oracle.gd#L96-L97) e entregue só ao HUD.
- **Nenhum NPC inventado para preencher a escada**; degrau vazio fica `[TARGET]`.
- **Não re-herdar o adquirido**, não apagar `cor_do_pelo_vem_do_bioma` de fundador, não contar geração
  por `Time.get_ticks_*` nem por frame, e não pôr a proveniência dentro do hash sem dizer que isso
  muda os hashes publicados.

## 7. Commits atômicos

(a) colheita de `diffuse_and_decay` no runner, sem comportamento novo; (b) `parents`/`gen`/`genome`
em `state_dict` e `load_state` com defaults, com a 3 **vermelha**; (c) load que devolve a
ascendência (3 verde) + 8; (d) genoma e herança de temperamento com 4; (e) cor do pelo por herança
**só para nascidos**, com 1 (vermelho→verde) e 2; (f) proveniência por célula + leitura do nariz com
5, e a decisão de `FORMAT_VERSION` registrada se divergiu, com 6 e 7; (g) escada `[TARGET]` no
`docs/design`, status (feito/em andamento/falta/débitos/notas) e `README.md` re-pinados com o número
do clone limpo. Branch `feat/arvore-genealogica-13`, base `main`, merge `--no-ff`, suíte verde entre
eles. **A perna de implementação só abre quando a fila serializada (09 → 10 → 14 → 11 → 12) fechar
na `main` mergida**; até aqui este arquivo é plano, não fila.

## 8. O que este dossiê não fecha

Nenhum gate de fase (mandato 4). Não fecha 03 (canais morte/som/fogo continuam 3), 04 (HOT agregado
sem medição), 05 (difusão síncrona — os µs dela abrem este lote), 08 (`MindsInspector` não existe: o
que a árvore usa é a linha de [`debug_line`](../../src/entities/wolf.gd#L1085-L1090) estendida, não uma
tela nova). Ecologia com presa, migração e espécies continua P2 `[TARGET]`; jogador com mente e NPC
com casa são `[TARGET]` sem linha de código. O multi-semente (02) fica mais caro: censo variável (11)
vezes árvore variável (13) é espaço de estados maior, e nenhum número daqui o cobre.

## 9. Citações que não conferem (invenções de briefing registradas)

- `world_gen.gd:157` como "IMPRINT_BIAS": a tabela está em
  [world_gen.gd:45-50](../../src/world/world_gen.gd#L45-L50); `:156-158` é a **leitura** dentro de
  `imprint_bias()`. O status já cita `:45` certo.
- `world_gen.gd:146` como `biome_at`: a função abre em
  [world_gen.gd:145](../../src/world/world_gen.gd#L145) e `:146` é o `return`.
- `mind.gd:14-17` para `personality` (real: [13-17](../../src/ai/mind.gd#L13-L17)), `_init` em
  `:23-31` (real: [24-32](../../src/ai/mind.gd#L24-L32)) e `_drift` em linha 47 de lá (real:
  [50](../../src/ai/mind.gd#L50), doc comment em `:49`).
- `EXPECTED_CHECKS` em `aether_reactions_test.gd:21`: na revisão deste briefing a constante era
  linha 17 (linha 16 era o `]` de `TESTS`), valia **119** e `TESTS`
  tinha 24 cenários — não o 109/21 que publicam os dossiês 10 e 11. Na leitura deste dossiê a linha 25 valia **150**, 30 cenários. Na rodada 19 a constante era
  [`:39`](../../tests/aether_reactions_test.gd#L39) com **198**; **hoje é a linha
  [`:39`](../../tests/aether_reactions_test.gd#L39) com 225** (rodada 11).
- "load com `mini()` em `main.gd:621`": **esse laço não existe mais** — a 11 trocou o pareamento por
  índice pelo pareamento por identidade, e o censo do disco passou a ser a autoridade. O load que o
  substituiu está em [main.gd:1091-1127](../../src/main.gd#L1091-L1127); `save_game` é [`:989-1024`](../../src/main.gd#L989-L1024)
  e `load_game` [`:1027-1085`](../../src/main.gd#L1027-L1085). O `:504` da fila caiu em `_reap_corpses` ([`:887-907`](../../src/main.gd#L887-L907)).
- Deslocamento geral em `wolf.gd`: o briefing media +27 linhas da rodada 09 sobre uma base de
  780 linhas; hoje são 959 e os alvos vieram de releitura por conteúdo, não de translação. O
  blackboard do BT é [`:842`](../../src/entities/wolf.gd#L842) (não `:479`) e `sim_step` é
  [`:806-835`](../../src/entities/wolf.gd#L806-L835) (não `:455`); [`_sense`](../../src/entities/wolf.gd#L846-L883)
  (não `:436-459`); [`_find_scent`](../../src/entities/wolf.gd#L890-L930) (não `:508-585`);
  [`_build_tree`](../../src/entities/wolf.gd#L363-L391) com o guard de 400 µs em
  [:389-390](../../src/entities/wolf.gd#L389-L390) (não `:156-192`/`:197-199`), `debug_line`
  [:1085-1090](../../src/entities/wolf.gd#L1085-L1090) (não `:738`), `_build_visual`
  [`:1179-1208`](../../src/entities/wolf.gd#L1179-L1208) (não `:793-823`); `load_state`
  [`:1115-1163`](../../src/entities/wolf.gd#L1115-L1163) (não `:758-789`) e, em `main.gd`,
  [`state_hash`](../../src/main.gd#L1227-L1228) (não `:856-857`). Conteúdo inalterado: é re-derivação
  de linha, o que o ciclo 1 do contrato cobra.
