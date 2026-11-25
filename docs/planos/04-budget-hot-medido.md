# 04 — Budget HOT medido: a colheita para aqui, o corte depois

Plano derivado de leitura. Nada foi rodado por mim: nem engine, nem suíte, nem script. Cobre o item 5 de "Falta" (`docs/melhorias-status.md:551-555`) e o débito de colheita declarado (`docs/melhorias-status.md:780-787`). Medição de tempo é serial (`AGENTS.md`, seção "Comandos de medição"): uma corrida por número, máquina livre, e o plano não publica número nenhum porque não tem corrida.

## Premissa nomeada

O gate diz "budget HOT ≤ `[TARGET]` 2,5 ms medido" (`docs/design/08-roadmap-risks-licensing.md:71-74`; a legenda que marca o alvo como alvo está em `docs/design/README.md:12-16`, `:18-21`). A premissa embutida nessa linha é dupla e nenhuma metade está medida: **(a)** as cinco mentes decidem dentro do mesmo tick e **(b)** o que compõe o HOT é o segmento de decisão da mente (percepção + utilidade + árvore), não só a árvore. Hoje a colheita existe com **um lobo por cenário** (`tests/aether_reactions_test.gd:316-321`, soma em `:314`, rodapé rotulado "CENARIO ESTREITO, NAO GATE P1" em `:3124-3125`) e o que ela soma é `SubtreeGuard.last_us`, que cronometra apenas `child.tick` (`src/ai/behavior/bt_tree.gd:130-137`). A checagem nova nomeia a premissa (a): se nenhum tick teve as cinco mentes vivas, o agregado não existe e a checagem dá vermelho em vez de imprimir zero — o precedente é o furo das quatro checagens que somem sem nenhum vermelho (`docs/melhorias-status.md:796-800`).

## O que é HOT em código: as três cadências

| Cadência | O que roda | Onde |
| --- | --- | --- |
| frame de física, 60 Hz | jogador local; corpo, timers de cadáver/atordoamento/desvio do lobo | `src/main.gd:302-308`, `src/entities/wolf.gd:1203-1259` |
| tick de simulação, 20 Hz, teto de 5 passos por frame | difusão 4×/s, **laço das mentes**, cadáveres 1×/s, fila de respawn, journal | `src/core/sim_clock.gd:5-7`, `src/main.gd:311-345`, mentes em `:319-320` |
| frame de renderização | malha com orçamento de 2 chunks, visualização do Éter 4×/s | `src/main.gd:356-362` (orçamentos em `:28` e `:29`) |

Orçamento por árvore: 400 µs configurado no lobo (`src/entities/wolf.gd:448-449`), 250 µs é o default da classe (`src/ai/behavior/bt_tree.gd:117-120`). Estouro devolve `FAILURE` e incrementa `trips` (`src/ai/behavior/bt_tree.gd:134-136`): estourar o orçamento muda comportamento do lobo, não só o número — por isso `trips` entra na checagem. O que o guard **não** cobre, dentro do mesmo `sim_step` (`src/entities/wolf.gd:875-904`): o `Dictionary` blackboard é construído no chamador (`:911`) antes de entrar no span cronometrado; `_sense()` (`:907` → corpo em `:916-953`, com LOS em `:922` e a varredura de rastros em `:960-1000` — 49 células × 3 canais na camada própria, mais 98 por camada vizinha aberta, cadência de 0,25 s declarada em `:30` e disparada em `:927-928`, custo medido em `docs/evidence/rastro-duas-camadas/readback.log`); `_think()` (`:908` → `:861-863` → `src/ai/utility_scorer.gd:84-106` → `:54-79` → `src/ai/response_curve.gd:14-38`). `tree_stats()` expõe só `last_us`/`trips` (`src/entities/wolf.gd:1356-1357`) e o F3 consome isso pela linha do lobo (`src/ui/hud.gd:271-281`). Não existe em `src/` nenhum acumulador por matilha: grep de `last_us` devolve o guard, o `debug_line` e o journal.

## Como seria uma colheita honesta

1. **Agregado no jogo real, onde as cinco mentes já coexistem.** No fim do laço de `src/main.gd:319-320`, somar `last_us` dos lobos que rodaram decisão naquele tick e guardar `pico`, `total`, o número de mentes que produziu o pico e a soma de `trips`. O padrão da casa para esses contadores já existe no journal (`src/persistence/tick_journal.gd:84-86`, saída em `:98`) e o relógio já tem a forma "pico + reset" (`src/core/sim_clock.gd:32-47`): dono do agregado é o tick, não o lobo — escrever em `SimClock`/`main.diagnostics()` (`src/main.gd:1206-1230`), que a suíte já lê (`tests/smoke_test.gd:272`, `:264`), em vez de criar estado solto no objeto deus (`AGENTS.md:243-246`). Custo da agregação: 5 leituras de `int` + 2 máximos por tick, sem dicionário novo; custo próprio: **não medido**.
2. **Composição no runner estreito, como checagem de aritmética, não de velocidade.** Um cenário com matilha fixa no mesmo `_stage`, onde a asserção é "o agregado do tick N é exatamente a soma dos `last_us` individuais lidos no tick N" e "mentes contadas = lobos vivos que passaram por `sim_step`" (mortos retornam em `src/entities/wolf.gd:876-877`). É isso que impede o runner de virar benchmark de uma coisa só: ele responde se a soma é correta; o valor do número vem da suíte real.
3. **Um segundo número, porque o primeiro não é o HOT do gate.** Cronometrar o segmento de decisão por lobo no laço de `main` (duas chamadas de `Time.get_ticks_usec()` por lobo por tick, 100/s no teto) e separar: árvore = soma dos `last_us`; percepção+utilidade = resto do `sim_step` do lobo. Derivado do código e medido só como `sim_step` integral: 5 lobos × 147 `sample_cell` quando o scan cai no mesmo tick, mais 98 por camada vizinha aberta quando a própria não devolve nada (`src/entities/wolf.gd:960-1000`; a matriz de ablação da rodada fechou 479 entradas de camada vizinha em 567 scans, e o escalonamento custou +39 ms sobre uma camada contra +103 ms da varredura incondicional — [logs](../evidence/rastro-duas-camadas/readback.log)), mais um `Dictionary` novo por lobo por tick (`:911`), mais o `_breakdown` do escorredor (`src/ai/utility_scorer.gd:76`). A soma por mente continua sem colheita.

## Gate do bloco (não o gate da fase)

Comandos já existentes: `godot --headless --path . tests/smoke_test.tscn` e `godot --headless --path . --script tests/aether_reactions_test.gd` (`docs/melhorias-status.md:1606-1611`). Critérios, todos capazes de falhar:

- **P (premissa)**: `pico_mente == 5` ao menos uma vez na corrida. Vermelho aqui significa que a matilha nunca esteve inteira no mesmo tick — o agregado impresso seria amostra de 4, não de 5 (`docs/evidence/third-person-carry/clone-suite.log:305` fecha com 4 vivos).
- **T (fail-visible)**: `trips` somado = 0 na corrida. Vermelho = a árvore foi cortada por orçamento e o lobo decidiu outra coisa (`src/ai/behavior/bt_tree.gd:134-136`): é defeito de comportamento, não nota de rodapé.
- **B (orçamento)**: `pico_hot_bt_us ≤ 2500` **e** `pico_decisao_us ≤ 2500`, com `dropped_ticks == 0` (`src/main.gd:1232`, já checado em `tests/smoke_test.gd:303-304`). Vermelho = o alvo de P1 já está estourado por medição real: o número vai para `docs/design/08-roadmap-risks-licensing.md:74` como medido e o gate de P1 continua aberto; ninguém corta a checagem para o verde aparecer.
- **C (censo)**: `EXPECTED_CHECKS` (`tests/aether_reactions_test.gd:61`, travado em 150 nesta ponta) e a última linha da suíte (`tests/smoke_test.gd:265`; estado atual 236 checagens / 0 falhas / 35,1 s em `docs/evidence/rastro-duas-camadas/clone-ff347d2-suite.log:311`) sobem exatamente com as checagens novas, conferidos numa corrida antes do lote (`docs/melhorias-status.md:796-800`).

O vermelho **não** fecha nem abre gate de fase: fecha o dono do repositório, com clone limpo reimportado (`godot --headless --path . --import`) e SHA pino (`AGENTS.md`, ciclo de trabalho, itens 6 e 8). O 2,5 ms continua `[TARGET]` até que a linha 74 do §08 receba um número com log; a aritmética 5 × 400 µs = 2 ms é conta de orçamento, não medição, e o status já veta somar picos de instantes distintos para declarar fechamento (`docs/melhorias-status.md:850-853`).

## Custo, em número (as quatro perguntas)

- Roda por frame, por tick ou às vezes? **Tick** a 20 Hz (`src/core/sim_clock.gd:5-7`): 5 somas + 2 máximos por tick e, no passo 3, 10 chamadas de `Time.get_ticks_usec()` por segundo no teto da matilha (`src/main.gd:9`).
- Quantas entidades alcançadas? **5 lobos** (`src/main.gd:9`, spawn em `:206`), menos os mortos que saem cedo (`src/entities/wolf.gd:645-646`); **64 chunks** e **1 jogador** nos valores do log (`docs/evidence/third-person-carry/clone-suite.log:305`).
- Aloco no caminho quente? A colheita: **não** (escalares). O que já aloca e continua sem medição própria: blackboard por lobo por tick (`src/entities/wolf.gd:911`), arrays e `_breakdown` por chamada de utilidade (`src/ai/utility_scorer.gd:55`, `:62-67`, `:76-78`) e o `String` de `top_line()` a cada tick (`src/entities/wolf.gd:863` → `src/ai/utility_scorer.gd:113-131`), `keys()` do cache de rastros (`src/entities/wolf.gd:962`, `:648`), `PackedInt32Array` por canal da difusão (`src/world/aether_field.gd:122`). Total de alocação: **não medido**.
- Como sei que ficou melhor? Pergunta errada para este bloco: aqui a saída é o número, não a melhoria. O antes/depois só vale na corrida seguinte, serial, e o piso publicado de hoje é `worst_sim_ms` 6,779 ms com `dropped_ticks = 0` (`docs/evidence/third-person-carry/clone-suite.log:303-305`).

## Custo da árvore × custo de percepção/utilidade

A árvore é o que o guard mede (`src/ai/behavior/bt_tree.gd:130-137` sobre o `Selector` montado em `src/entities/wolf.gd:448-449`). Percepção e utilidade rodam antes, fora de qualquer span: `_sense` (`src/entities/wolf.gd:916-953`) e `_think` (`:861-863`) são chamados em `:907-908`, e `_tree.tick` só vem em `:911`. O §08 já registra essa lacuna (`docs/design/08-roadmap-risks-licensing.md:76-86`). Consequência de redação: nenhuma linha do status ou do §08 pode dizer "budget da mente" citando `last_us`; publicam-se duas linhas — `pico_hot_bt_us` (soma da árvore no mesmo tick, com mentes contadas) e `pico_decisao_us` (segmento de decisão do mesmo tick) — e o gate de P1 fala da segunda, que é a que compete com os 50 ms do passo.

## O que NÃO fazer

Sem `HotSet`/Véu (peça de P2, `docs/melhorias-status.md:86`), sem `MindsInspector`, sem difusão em thread, sem canais novos de Éter, sem replay, sem corte de alocação antes do número. Sem otimizar "porque a soma dá 2 ms": a soma é de orçamentos, não de execuções (`docs/melhorias-status.md:87`). Sem mover estado de lobo para o `main` a pretexto de agregado: agrega-se o que o guard já expõe. Sem silenciar `SCRIPT ERROR` para o verde aparecer, sem abaixar limiar depois de medir e sem escrever em `docs/design/08-roadmap-risks-licensing.md:74` sem corrida publicada.

## Checklist de commits atômicos

1. `medir — agregado por tick da árvore`: contadores em `SimClock`/`main` + chave nova em `diagnostics()` + a linha impressa no rodapé dos dois runners; uma corrida responde com `pico_hot_bt_us`, `total` e as mentes do pico. Sem gate numérico ainda.
2. `gate — premissa e trip`: checagens P e T acima, `EXPECTED_CHECKS` conferido (`tests/aether_reactions_test.gd:61`), censo C na última linha (`:3124`). Vermelho provocado antes do merge de um jeito que não muda código shipped: limiar temporário abaixo do pico medido, corrida, linha revertida, corrida igual com contagem de checagens idêntica — os dois sentidos da atribuição.
3. `medir — segmento de decisão`: passo 3 da colheita, com `pico_decisao_us` impresso ao lado de `pico_hot_bt_us`, para o HOT do gate ter o que dizer.
4. `gate — orçamento`: critério B ligado ao valor do §08; corrida serial em clone limpo com SHA pino.
5. `documentar — número medido no item 5 e no §08`: re-derivar `docs/melhorias-status.md:551-555`, `:705`, `docs/design/08-roadmap-risks-licensing.md:74` e `:76-86`, registrar a corrida nas notas de medição; o gate de P1 permanece aberto até o dono fechar.

## Citações que não conferem

- O briefing aponta o F3 do BT em `src/entities/wolf.gd:953`; confere (`tree_stats()` definida em `:928`, consumida em `:924` dentro de `debug_line()` `:920-925`). Quem imprime é `src/ui/hud.gd:273-280`, que chama `w.debug_line()` em `:275` — `AGENTS.md` cita o corpo do overlay (`hud.gd:245-281`) sem nomear esse ponto.
- `docs/melhorias-status.md:69-69` e `docs/design/08-roadmap-risks-licensing.md:80-82` citam `src/ai/behavior/bt_tree.gd:117-120` e `src/entities/wolf.gd:664-668`: conferem (default 250 µs em `:212`, span cronometrado em `:223-225`, chamadas de percepção/utilidade em `:663-664`).
- Achei e fechei nesta ponta: os 400 µs estavam ancorados no status em `src/entities/wolf.gd:293-294`, faixa que é declaração de variáveis de estado; a construção real do guard com o orçamento é `src/entities/wolf.gd:448-449`, e a linha 371 do status agora aponta para ela.
- `docs/design/08-roadmap-risks-licensing.md:74` escreve "2,5 ms medido" numa frase de gate: o adjetivo "medido" é alvo, não fato — não há log com o agregado em `docs/` nem em `.tools/`.
- Nada em `src/` implementa 2,5 ms: o valor existe só como texto de gate. Os tetos em código são 50 ms por passo (`src/core/sim_clock.gd:5-7`), 400 µs por árvore (`src/entities/wolf.gd:448-449`), 2 chunks por frame (`src/main.gd:28`) e as cadências de 0,25 s e 1 s (`src/main.gd:29`, `:31`).
