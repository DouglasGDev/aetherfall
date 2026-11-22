# Leitura de retorno — auto-pulo de bloco (dossiê 19)

O que esta pasta guarda é a corrida que sustenta o **fecho** da perna: a pontinha de código
`f843fa6` já tinha a sua própria medição, feita na branch; aqui está o que acontece **depois** —
a branch publicada, o merge `--no-ff` na `main`, e o número do pin medido num clone limpo da
`main` mergeada.

Revisão medida: `a518487` (`Merge feat/auto-pulo-de-bloco-19: auto-pulo de bloco (dossie 19)`),
merge `--no-ff` de `feat/auto-pulo-de-bloco-19` (ponta de código `f843fa6`, ponta de documento
`acb7970`) sobre a base `8ac761d`.

## 1. O que está nesta pasta

| Arquivo | Bytes | O que prova |
| --- | --- | --- |
| `branch_suite.log` / `.err` | 21 221 / 250 | suíte na ponta de documento da branch (`acb7970`) |
| `branch_runner.log` | 35 765 | runner de reações na mesma ponta |
| `merged_main_suite.log` / `.err` | 21 222 / 250 | suíte na `main` mergeada (`a518487`) |
| `clone_import.log` | 21 338 | `--import` frio do clone limpo, exit 0 |
| `clone_suite.log` | 21 223 | suíte no clone limpo, **primeira** corrida (diretório de dados virgem) |
| `clone_suite_run2.log` / `.err` | 21 223 / 250 | **segunda** corrida no mesmo clone, mesmo comando |
| `clone_runner.log` | 35 766 | runner de reações no clone limpo |
| `artifacts.sha256` | — | SHA-256 de cada arquivo acima |

Os logs são cópias literais do stdout/stderr das corridas; `artifacts.sha256` é conferível com
`sha256sum -c artifacts.sha256` a partir desta pasta.

## 2. As quatro corridas

Todas headless, máquina livre, medição serial (nenhum gate de timing roda com outra carga), e
todas com **zero** `SCRIPT ERROR` nas duas correntes (stdout e stderr).

| Corrida | Revisão | Comando | Resultado |
| --- | --- | --- | --- |
| branch, suíte | `acb7970` | `--headless --path . tests/smoke_test.tscn` | **246 checagens / 0 falhas / 39,7 s**, exit 0 |
| branch, runner | `acb7970` | `--headless --path . --script tests/aether_reactions_test.gd` | **198 checagens / 0 falhas / 12,897 s**, exit 0 |
| `main` mergeada, suíte | `a518487` | idem, na árvore do merge | **246 checagens / 0 falhas / 39,5 s**, exit 0 |
| clone limpo, suíte | `a518487` | idem, em `C:/tmp/af19-clone` | **246 checagens / 0 falhas / 39,6 s**, exit 0 |
| clone limpo, runner | `a518487` | idem, em `C:/tmp/af19-clone` | **198 checagens / 0 falhas / 12,870 s**, exit 0 |

Linhas literais:

```
== 246 checagens  0 falhas  39.7 s de teste ==      (branch_suite.log)
198 checagens 0 falhas 12.897 s                       (branch_runner.log)
== 246 checagens  0 falhas  39.5 s de teste ==      (merged_main_suite.log)
== 246 checagens  0 falhas  39.6 s de teste ==      (clone_suite.log)
== 246 checagens  0 falhas  39.5 s de teste ==      (clone_suite_run2.log)
198 checagens 0 falhas 12.870 s                       (clone_runner.log)
```

O censo do runner é `EXPECTED_CHECKS = 198` e a suíte é 246 — os dois números que o
[README](../../README.md) fixa como pin. O clone foi feito assim:

```sh
git clone --no-hardlinks C:/Aetherfall C:/tmp/af19-clone
git -C C:/tmp/af19-clone checkout a5184873c80d69609db2c2f90cbb08da3e48197d
C:/Aetherfall/.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path C:/tmp/af19-clone --import
C:/Aetherfall/.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path C:/tmp/af19-clone tests/smoke_test.tscn
```

O `--import` frio sai com **exit 0** e termina em `[ DONE ] loading_editor_layout`, sem nenhum
`SCRIPT ERROR` (`clone_import.log`). O clone não tem `.godot/` nem `.tools/` antes do import.

## 3. O par de vazamento do quit tem causa medida

O par `ObjectDB instances were leaked` / `resources still in use` aparece na árvore de trabalho
(`branch_suite.err`, `merged_main_suite.err`, 250 bytes cada) e **não** aparece na primeira
corrida do clone limpo — `clone_suite.log` tem zero `ERROR` e stderr de 0 bytes. A segunda
corrida no **mesmo** clone, mesmo comando, mesma árvore, volta a imprimir o par
(`clone_suite_run2.err`, 250 bytes):

```
WARNING: 16 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2536)
ERROR: 6 resources still in use at exit (run with `--verbose` for details).
   at: clear (core/io/resource.cpp:822)
```

A diferença entre as duas corridas é o **diretório de dados `user://`** — virgem na primeira,
com o slot que a suíte salva na segunda — e não a árvore de código. A atribuição do par em si
continua **aberta**: o que está medido aqui é o que o par acompanha, não o que o par causa.

## 4. O que o fecho não mudou

A árvore de código do pin é a da ponta `f843fa6` mais os dois commits de documento; o que o
merge acrescenta é `.md` e `.log`. Conferência por hash de árvore:

```
git rev-parse a518487:src a518487:tests
45efe977f74de550423ce59e5eb16bb2492a185f
37eb429c142d6e3af7922e38145a984feb130f8b
```

Contra o pin anterior (`d4dee0f`, perna 14), `src` era `3eb42835a0e1f…` e `tests` era
`8b8a5e471d737…`: **mudaram**, porque a perna 19 toca `src/entities/voxel_body.gd`,
`src/entities/player.gd`, `src/entities/wolf.gd` e `tests/aether_reactions_test.gd`. É a
primeira vez desde o pin da perna 14 que `src` e `tests` não são os mesmos objetos.

O diagnóstico final confere dígito a dígito entre a `main` mergeada e o clone limpo
(`aether_energy` `11,9870493914932`, `chunks` 64, `edits` 13, `triangles` 214480, `wolves` 4,
`tick` 403, `dropped_ticks` 0). Só os tempos de boot e de passo se movem, como sempre:
`gen_ms` 1 003,98 → 1 021,495, `mesh_ms` 4 875,668 → 4 914,465 e `worst_sim_ms` 11,923 → 13,541
(média e pico são corrida, não faixa).

Nada nesta pasta fecha gate de fase (mandato 4). A perna 11, que também escreve
`src/entities/wolf.gd` e o runner, re-rome o gate depois deste merge — a árvore resultante é
outra revisão.
