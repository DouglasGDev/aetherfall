# 05 — Difusão do Éter fora do tick de decisão

Plano derivado de leitura; nada foi rodado por mim. Cobre o item 6 de "Falta" (`docs/melhorias-status.md:288-290`) e a linha não marcada do P1 (`docs/melhorias-status.md:310`), que `docs/design/08-roadmap-risks-licensing.md:68` lista como entrega de P1 e `:36` registra que nenhum gate está fechado. Marcas: `[MEASURED]` lido em log, `[TARGET]` peça que não existe em `src/`.

## Premissa nomeada: visibilidade síncrona

Hoje a difusão é a única escrita em massa do Éter dentro do passo, e o lobo vê o resultado porque a passada é síncrona antes do `sim_step`: `main._sim_tick` chama `aether.diffuse_and_decay(AETHER_PERIOD)` (`src/main.gd:148-151`) e logo depois `w.sim_step` (`src/main.gd:152-153`), que lê por `sample_cell` (`src/world/aether_field.gd:96-99`). A mesma chamada é a única escrita de `_cur` em bloco (`src/world/aether_field.gd:145-156`) — os imprints entram um a um, por callback de frame (`src/main.gd:192`, `:268-273`, `:306-307`). Premissa do plano: **o estado publicado no tick N é função só do tick N**; a cadência é fixa e em fase (o contador parte de `AETHER_PERIOD` em `src/main.gd:38` e o passo é 0,05 s, então a passada cai a cada 5 ticks — `src/core/sim_clock.gd:5-7`), e o `elapsed` é a constante 0,25 e não o `dt` (`src/main.gd:150`), o que fixa o fator de meia-vida (`src/world/aether_field.gd:120`). Qualquer thread mexe nessa premissa em três lugares: semente→mundo, a projeção do journal e a leitura do tick seguinte. Consequência dura: não existe hoje **nenhuma** medição de quanto a difusão custa — nem `src/` nem `tests/` cronometram `diffuse_and_decay`; `AGENTS.md:183` exige colheita antes do corte, e este plano obedece a ordem.

## Estado real (lido, sem rodar)

| Grandeza | Valor | Onde |
| --- | --- | --- |
| Células por canal | 32 × 16 × 32 = **16 384** | `src/world/voxel_config.gd:5-16`, `src/world/aether_field.gd:45-48` |
| Canais | **3** (WORK, BLOOD, FEAR) | `src/world/aether_field.gd:9-15` |
| Floats do campo | 49 152 → **196 608 bytes** | `src/world/aether_field.gd:49-50`, `:233-234` |
| Passadas por segundo | **4** (`AETHER_PERIOD` 0,25) | `src/main.gd:12`, `:148-151` |
| Varredura de decaimento | 3 × 16 384 leituras+escritas por passada, **incondicional** | `src/world/aether_field.gd:123-127` |
| Varredura de corte (`MIN_VALUE`) | 49 152 por passada | `src/world/aether_field.gd:146-153` |
| Alocação por passada | **1 `PackedInt32Array` por canal = 3 por passada, 12/s** | `src/world/aether_field.gd:122` (débito em `docs/melhorias-status.md:354-361`) |
| Custo da lista `hot` | 6 vizinhos por célula ativa, com `world.is_solid` no meio do laço | `src/world/aether_field.gd:130-142`, `:161-176` |
| µs de difusão, HOT agregado | **não medido** | — (o runner só cronometra `sim_step` e BT, `tests/aether_reactions_test.gd:108-115`) |

Âncora `[MEASURED]` de campo real: WORK 4,0 por 12 s deu **48 passadas**, energia 4,000000 → 2,021455, **19 células ativas** (`docs/melhorias-status.md:950-952`). Âncora `[MEASURED]` de passo: `worst_sim_ms=6,779`, `tick=359`, `dropped_ticks=0`, `chunks=64`, `aether_energy=9,67776` (`docs/evidence/third-person-carry/clone-suite.log:305`), com **232 checagens / 0 falhas / 33,7 s** (`:307`). O teto do passo é 50 ms com 5 passos por frame (`src/core/sim_clock.gd:5-7`, `:19-29`) e o cronômetro inclui o journal (`src/main.gd:140-142`, `:164-170`).

## Opções reais

**A — ficar no tick e cortar alocação** (menor diff). Reaproveitar um membro `_hot` como já se faz com `_nb_i`/`_nb_w` (`src/world/aether_field.gd:37-39`, `resize(0)` em `:162-163`): 3 arrays a menos por passada, nenhuma semântica muda, o hash por semente fica **idêntico**. Não toca as 98 304 varreduras incondicionais por passada (`:123-127`, `:146-153`). Extensão com flag de "canal frio" tem armadilha lida: pular o laço de um canal deixa `_nxt` com o miolo de duas passadas atrás, e a troca publica lixo (`:154-156`) — o skip só vale com o invariante "`_nxt` do canal frio está zerado", escrito por quem faz a limpeza (`:87-89`, `:102-105`, `:220-229`). Custo: linhas em `AetherField`; quebra: nada, se o invariante for checado.

**B — fatias de varredura dentro do próprio passo** (work-stealing determinístico, uma linha só). Dividir as 16 384 células em K fatias, uma por tick, publicando a troca só na K-ésima. Não aloca thread nem toca o voxel de outra linha: o `world.is_solid` de `:161` continua no mesmo thread do `edits` que o jogador escreve por frame (`src/entities/player.gd:659`, `:675`). Determinismo preservado (a fatia é função do tick), mas **o campo visível muda de fase**: o lobo pode ler um campo que não avançou no tick em que a cadência de rastros pede leitura (0,25 s — linha herdada de `AGENTS.md`, não relida aqui). O `elapsed` continua 0,25 por passada completa (`src/main.gd:150`), senão a meia-vida (`:111`) muda de valor. Quebra: o hash por semente **muda** contra a base, porque a projeção lê `_cur` no fim do passo (`src/persistence/tick_journal.gd:43`) e passaria a ver um estado meio-avançado; exige regravar a âncora literal da checagem nova.

**C — thread dedicada com dupla troca** `[TARGET]`. Não há nenhum `Thread`/`WorkerThreadPool` em `src/` (o único threaded do repositório é o `HTTPRequest` do oráculo, `src/ai/mind_oracle.gd:22`, `:32`); a promessa é de design: `docs/design/06-godot-architecture.md:94` põe a difusão em `native/af_aether` (C++/GDExtension, `:12`) com budget 1,0 ms/thread (`:184`) e `:118-120` dá a regra — a thread **nunca** toca o `SimWorld` e o resultado entra por fila no próximo tick. Em GDScript puro isso quebra as três coisas do enunciado: (1) *determinismo* — o tick de publicação vira função de quando a thread acaba, então a mesma semente dá hashes diferentes; o conserto é um atraso fixo K carimbado por tick, que é mudança de contrato, não de performance; (2) *projeção do journal* — `state_hash` chama `_cur.to_byte_array()` (`src/persistence/tick_journal.gd:43`, `src/world/aether_field.gd:233-234`) dentro do cronômetro do passo (`src/main.gd:164-170`): com a thread escrevendo e trocando a referência (`:154-156`) em paralelo, o SHA256 testemunha bytes rasgados ou um estado que nunca existiu; (3) *visibilidade* — os imprints de frame (`src/main.gd:192`, `:268-273`, `:306-307`) e a leitura dos lobos (`:152-153`) são hoje a mesma variável sem dono; a thread precisaria de fila para os dois lados e de cópia do campo (196 608 bytes/troca) e do volume de solidez que `_neighbours` consulta (`src/world/aether_field.gd:176`). Custo: a própria fila + um `AetherField` que não é mais dono único de `_cur`. **C na forma do design precisa de autorização explícita do dono** (`AGENTS.md`, "Escopo autorizado agora": GDExtension nativo está fora) e não é este plano que a pede.

## Gate de fechamento

Comandos existentes (`AGENTS.md:287-298`), e nada de `--check-only` como substituto da suíte:

```sh
godot --headless --path . --import
godot --headless --path . tests/smoke_test.tscn
godot --headless --path . tests/aether_reactions_test.gd
godot --headless --path . tests/smoke_test.tscn -- --tick-journal=CAMINHO-NOVO.jsonl
```

1. **Colheita antes do corte** (pré-gate de A/B/C): o runner imprime por cenário `diffuse_us_media`, `diffuse_us_pico`, `passes`, `hot_max_por_canal`, medidos com `Time.get_ticks_usec()` em volta de `diffuse_and_decay` (padrão já usado em `tests/aether_reactions_test.gd:108-112`) — código de produção intocado. Sem esse número, A/B/C são hipótese.
2. **`difusao_hash_inalterado_por_semente`** (checagem nova, em `tests/aether_reactions_test.gd`, que já controla as cadências): monta o campo, imprint WORK 4,0, N passadas fixas, e compara `Journal.state_hash()` contra um **literal gravado na base**, antes e depois da mudança, junto da âncora lida 4,000000 → 2,021455 e 19 células ativas (`docs/melhorias-status.md:950-952`). Imprime `passes=N hash_antes=... hash_depois=... energia=...`. Em A a igualdade é obrigatória; em B/C a checagem existe para mostrar **onde** o hash mudou, com o novo literal e o commit que o declara. Nota honesta: comparar journal entre duas corridas ao vivo não serve — a simulação ao vivo não é determinística (`AGENTS.md`, mandato 3), e a suíte roda sem journal (`docs/evidence/third-person-carry/clone-suite.log:305`: `journal.records=0`).
3. **Custo sem regressão**: `dropped_ticks=0` e `worst_sim_ms` contra 6,779 ms `[MEASURED]` (`docs/evidence/third-person-carry/clone-suite.log:305`), com a contagem de checagens conferida **antes** do lote (`AGENTS.md`: um `SCRIPT ERROR` dentro de um passo derruba checagens em silêncio).
4. Gate de fase não se fecha aqui: P1 segue aberto (`docs/design/08-roadmap-risks-licensing.md:72-74`, `:85`), e quem fecha é o dono do repositório.

## Custo — as quatro perguntas (`AGENTS.md:242`)

- **Roda por frame, por tick ou às vezes?** Às vezes: 4 passadas por segundo dentro do passo de 50 ms (`src/main.gd:12`, `:148-151`; `src/core/sim_clock.gd:5-7`) — não é 20 Hz.
- **Quantas entidades são alcançadas?** 16 384 células × 3 canais por passada (`src/world/aether_field.gd:45-50`) e 6 `is_solid` por célula ativa (`:130-142`, `:176`); 5 lobos consomem o resultado (`src/main.gd:152-153`), 64 chunks no mundo (`docs/evidence/third-person-carry/clone-suite.log:305`).
- **Aloco no caminho quente?** Hoje sim: 3 `PackedInt32Array` por passada (`src/world/aether_field.gd:122`) — A zera isso, B mantém, C acrescenta a cópia de 196 608 bytes por troca (`:233-234`).
- **Como sei que ficou melhor?** Ainda não existe log que responda: nenhum `src/` ou `tests/` cronometra a difusão. O primeiro commit deste bloco é a colheita do item 1 do gate.

## O que NÃO fazer

- Não é "melhorar um sistema que já passou no gate": o gate de P1 está aberto (`docs/design/08-roadmap-risks-licensing.md:72-85`) e o item segue não marcado (`docs/melhorias-status.md:310`). O que veta o corte agora é a ordem colheita→corte (`AGENTS.md:183`) e a regra de complexidade sem necessidade de gate.
- Não abrir thread sem a fila de publicação no tick (`docs/design/06-godot-architecture.md:118-120`) nem sem mover o `is_solid` para uma cópia lida (`src/world/aether_field.gd:176`).
- Não aproveitar para levar o campo a 6 canais: é o item 4 (`docs/melhorias-status.md:274-282`, adiado em `:307`) e `Channel.COUNT` entra na projeção (`src/persistence/tick_journal.gd:36-39`) — dois assuntos, dois hashes, dois commits.
- Não tocar `HALF_LIFE`/`DIFFUSE_RATE` (`src/world/aether_field.gd:13-15`) nem o `elapsed` fixo (`src/main.gd:150`): muda Éter e hash por decreto, não por evidência.
- Não assumir `HotSet`, `SlowSim`, facções, `MindsInspector`, replay nem fita de comandos: nada disso existe em `src/`.
- Não somar estado novo em `main.gd` (débito de objeto deus reconhecido): a colheita mora no runner, e os contadores ficam em `AetherField`.
- Não reabrir journal automaticamente: `start()` recusa caminho existente (`src/persistence/tick_journal.gd:47-62`).

## Checklist de commits atômicos

1. `tests` — colheita: `diffuse_us_media/pico`, `passes`, `hot_max_por_canal` no runner de reações; número publicado no commit. Só `tests/`.
2. `docs` — decisão de braço (A, B ou fica parado) registrada em `docs/melhorias-status.md` com a colheita da linha 1; nenhum código.
3. `src` — A: `_hot` reutilizável; checagem `difusao_hash_inalterado_por_semente` já no commit 1 ou aqui, com igualdade exigida.
4. `src` + `tests` — B, **somente se** a colheita do 1 colocar a difusão acima do que 5 lobos + BT deixam do passo: fatias com troca na K-ésima, novo literal de hash declarado como mudança de contrato, `dropped_ticks=0` reconferido.
5. C não entra sem autorização explícita do dono (fila + cópia de volume + GDExtension).
Entre cada commit: contagem de checagens conferida antes do lote, suíte verde, `worst_sim_ms` no commit. Push e publicação só quando o dono pedir, conferindo `git ls-remote --heads origin`.

## Citações que não conferem

- `src/entities/wolf.gd:461-496` e `src/entities/player.gd:659`, `:675` são herdadas de `AGENTS.md` e do briefing: **não relidas** nesta revisão — reconferir antes do commit 3.
- `AGENTS.md:183` ("colheita, não corte"), `:242` (quatro perguntas) e `:287-298` (comandos) lidos por grep; os números históricos de boot (936–962 ms, 4 640–4 886 ms) citados por `AGENTS.md` não foram re-medidos aqui — a única âncora usada é o log do clone limpo (`docs/evidence/third-person-carry/clone-suite.log:305`, `:307`).
- Nenhum custo de difusão foi medido: todo valor de µs neste arquivo está ausente por projeto, não por esquecimento.
