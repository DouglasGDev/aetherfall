# Checagem 7 do dossiê 16 — `sim_step` pareado, com e sem a perna

O pedido da página (§5.7) é um par: o `sim_step` integral da **mesma cena, mesma semente**,
medido na árvore **com** a perna e na árvore **sem** ela, mais `worst_sim_ms` e
`dropped_ticks == 0` no smoke. Este arquivo guarda os dois lados e a conta que os compara.

## 1. Por que o par é duas corridas e não dois braços do mesmo processo

Não existe, nesta árvore, a porta "sem a perna". `_dens` e a colocação que o enche **são** o
código medido: um braço que esvaziasse os `_dens` à mão encenaria um estado que nenhuma transição
do jogo produz — exatamente o que o ciclo 3 de `AGENTS.md` recusa ("não montar premissa de teste
escrevendo campo na mão"). Então o lado "sem" é a mesma suíte rodando na base da branch
(`99d1167`, a `main` de onde `feat/tocas-da-alcateia-16` foi aberta), e o lado "com" é a ponta
medida da branch.

O que torna o par comparável é que as duas linhas impressas abaixo **não foram tocadas pela
perna**: `CENARIO ESTREITO` e `PASSOS DE MATILHA` existem idênticas em `99d1167` e aqui, com as
mesmas sementes, os mesmos contadores e o mesmo instrumento. A checagem nova de custo usa
acumuladores locais justamente para não engordar esses rodapés — conferido: `passos=1341` nos
dois runs da branch, com a checagem 7 montada e desmontada.

## 2. As quatro corridas (duas por braço)

Todas headless, máquina livre, medição serial. Nenhum `SCRIPT ERROR` em stdout ou stderr.
Revisões: base `99d1167`; branch `90c152f` + as duas edições desta perna nos testes
(`EXPECTED_CHECKS` 240, checagem nova no smoke), conferíveis por md5 em §5.

| Braço | Run | `CENARIO ESTREITO` (8 579 passos) | `PASSOS DE MATILHA` |
| --- | --- | --- | --- |
| sem a perna | `base_runner_run1_99d1167.log` | total **1 906 247 µs**, pico 4 346 µs | 1 339 passos, total 3 044 738 µs, pico 12 930 µs |
| sem a perna | `base_runner_run2_99d1167.log` | total **1 914 614 µs**, pico 3 302 µs | 1 339 passos, total 3 099 659 µs, pico 13 688 µs |
| com a perna | `head_runner_run1.log` | total **1 890 169 µs**, pico 3 337 µs | 1 341 passos, total 3 059 822 µs, pico 12 709 µs |
| com a perna | `head_runner_run2.log` | total **1 903 807 µs**, pico 3 159 µs | 1 341 passos, total 3 046 903 µs, pico 12 582 µs |

O braço da matilha tem contagem de passos diferente por braço (1 339 × 1 341) porque o passo é
de uma janela que fecha por condição de censo, não por contagem fixa. A comparação é feita por
passo, nunca por total absoluto.

## 3. A conta

```
estreito  por passo: base 222,20 / 223,17   média 222,69   spread 0,98
                    head 220,33 / 221,91   média 221,12   spread 1,59   Δ −1,57 µs (−0,70 %)
matilha   por passo: base 2 273,89 / 2 314,91  média 2 294,40  spread 41,02
                    head 2 281,75 / 2 272,11  média 2 276,93  spread  9,63  Δ −17,47 µs (−0,76 %)
```

**Veredito medido: nenhum custo atribuível à perna.** A diferença nominal é *negativa* nos dois
braços e, nos dois, menor que o espalhamento de repetir o **mesmo** braço (Δ −0,70 % contra
spread de 0,44 % e 0,71 % no estreito; Δ −0,76 % contra 1,79 % e 0,42 % na matilha). Número
menor que o ruído do instrumento não é melhoria — é "não medimos diferença".

Isso é o que a página esperava, e agora tem testemunha: a colocação roda no caminho raro (spawn,
fila de 45 s, parto), não no laço de 20 Hz. O preço desse caminho raro sai impresso na checagem,
**sem régua publicada** porque não há régua para ele: **7 314 µs** (run 1) e **7 108 µs** (run 2)
pelos cinco lares com três tocas fundadas, contra um boot medido na própria suíte de
~0,98 s de geração + ~4,4 s de malharia. Duas ordens de magnitude abaixo do que o boot já gasta
em uma passada.

## 4. A janela de 1 400 passos da matilha espalhada (o gate novo)

A checagem `_test_espalhamento_nao_estoura_o_passo` roda 1 400 passos reais do `_sim_tick` com
`clock.begin_step()`/`end_step()` (o mesmo invólucro de `main.gd:259-261`), corpos nos três
sub-passos, e a premissa de que a matilha medida está mesmo espalhada:

| Run | média µs/passo | pico µs | `worst_sim_ms` | premissa |
| --- | --- | --- | --- | --- |
| 1 | 1 988,53 | 11 408 | 11,41 ms | 1 400 passos, tick 0→1 400, dens=3, componentes mínimos=3, 5 bichos lidos |
| 2 | 1 968,88 | 9 681 | 9,68 ms | idem |

Critério: 25 ms por passo (a régua dos dossiês 17 e 19). Pior passo observado 11,41 ms — 46 % da
régua, 23 % do orçamento de 50 ms. O `pico_do_passo` cronometrado aqui e o `worst_sim_ms` lido do
`diagnostics()` coincidem no mesmo run (11 408 µs ↔ 11,41 ms; 9 681 µs ↔ 9,68 ms), o que é a
prova de que o instrumento da checagem e o do F3 estão medindo a mesma grandeza.

No smoke, `espalhamento_nao_estoura_o_passo` é a metade que só o caminho real pode dizer
(`head_suite.log:343`):

```
[PASS] espalhamento_nao_estoura_o_passo  perdidos=0  pior passo=10,77 ms (regua 25)
       dens=3 componentes=3 separacao=55,9 m  tick=403
```

`dropped_ticks` é 0 **aqui** e não na janela do runner porque ele só existe se
`clock.advance()` estourar o teto de 5 passos por frame (`sim_clock.gd:23-26`), e quem chama
`advance` é o `_physics_process` da sessão. Num laço que chama `_sim_tick()` direto, a asserção
seria decorativa. A testemunha do espalhamento (`dens >= 2`, `componentes >= 2`) vai dentro do
critério: sem ela o número não seria do espalhamento.

Corridas da ponta medida: runner **240 checagens / 0 falhas / 24,586 s** (run 1) e
**24,446 s** (run 2); `simulation_rng_test` **27 / 0 / 2,762 s**; suíte **255 / 0 / 48,0 s**.

## 5. Vínculo de revisão

Identidade md5 dos arquivos que as corridas medem, calculada **antes** do run 1 e **depois** do
run 2 do braço "com", e conferida idêntica (nenhum arquivo mudou no meio de uma corrida):

| Arquivo | md5 (braço com a perna) | Bytes |
| --- | --- | --- |
| `src/main.gd` | `885aeb37d94f9a806aad10dc289b3712` | 51 694 |
| `src/entities/wolf.gd` | `c70d6906e639f697769d408962017d9e` | 52 005 |
| `tests/aether_reactions_test.gd` | `7cd3f8f336e5b53b89652142ed6d57d8` | 205 582 |
| `tests/smoke_test.gd` | `ec5a13b953f5277a7cd452fc988820f6` | 118 312 |

| Arquivo do braço base (`99d1167`) | md5 | Bytes |
| --- | --- | --- |
| `src/main.gd` | `99cdf7291437803471ec2fda4786737b` | 39 864 |
| `src/entities/wolf.gd` | `5fc2ed71d4d61c8c8fc2cc89cdd56b05` | 50 953 |
| `tests/aether_reactions_test.gd` | `d05a2f8c7f762849d3286f345fef566c` | 176 203 |

`artifacts.sha256` confere os cinco logs acima mais `docs_rerun_suite.log` — a re-corrida da suíte
feita na árvore depois da passada de documentos (`255 checagens / 0 falhas / 47,7 s`, exit 0, linha
357, sem as duas linhas de quit do `head_suite.log`) — com `sha256sum -c artifacts.sha256` dando OK
nos seis.

## 6. O que esta medição não diz

Não fecha gate de fase nenhum (mandato 4). Não é otimização: nada aqui corta custo, só o mede.
Não mede alocação no caminho quente — o blackboard novo por lobo por tick e o
`PackedInt32Array` por canal por passada continuam sem colheita própria (status, "Alocação no
caminho quente existe e não é medida"). E as duas contagens de passos diferentes por braço
lembram que a cena não é bit-a-bit idêntica: a perna muda **onde** os lobos nascem, e lobos em
lugares diferentes percorrem caminhos diferentes. O que se compara é o custo por passo da mesma
configuração de censo, não a igualdade de trace.
