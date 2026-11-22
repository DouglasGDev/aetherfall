# Leitura de retorno — acasalamento, filhote e censo (dossiê 11)

O que esta pasta guarda é a corrida que sustenta o **fecho** da perna: os sete commits de código e
de corpus já tinham as suas próprias medições, feitas na branch; aqui está o que acontece
**depois** — a branch publicada, o merge `--no-ff` na `main`, e o número do pin medido num clone
limpo da `main` mergeada.

Revisões medidas: `4b858c2` (`Merge feat/acasalamento-e-censo-11: acasalamento, censo variavel e a
fila da alcateia (dossie 11)`), o merge `--no-ff` da branch `feat/acasalamento-e-censo-11` (ponta de
código `0762b43`) sobre a base `e7a5fe7`; e a ponta de código da branch, `0762b43` (`Dossie 11 (g):
o corpus re-derivado pela ponta da perna 11, com a prosa do status, do contrato e da pagina`). A
ponta `010ab25` (merge da `main` dentro da branch) está dentro dessa história: a perna escreve os
mesmos dois arquivos que a 19 escreveu, e o item 5 de "Branches" obriga a re-rodar o gate na árvore
resultante.

## 1. O que está nesta pasta

| Arquivo | Bytes | O que prova |
| --- | --- | --- |
| `branch_suite.log` / `.err` | 22 546 / 249 | suíte na ponta de código da branch (`0762b43`) |
| `branch_runner.log` / `.err` | 41 496 / 0 | runner de reações na mesma ponta |
| `branch_journal.log` | 8 719 | teste do journal na mesma ponta |
| `merged_main_suite.log` / `.err` | 22 546 / 249 | suíte na `main` mergeada do código (`4b858c2`) |
| `clone_import.log` | 21 338 | `--import` frio do clone limpo, exit 0 |
| `clone_suite.log` / `.err` | 22 546 / 249 | suíte no clone limpo, **primeira** corrida |
| `clone_suite_run2.log` / `.err` | 22 546 / 0 | **segunda** corrida no mesmo clone, mesmo comando |
| `clone_runner.log` / `.err` | 41 497 / 0 | runner de reações no clone limpo |
| `clone_journal.log` / `.err` | 8 719 / 0 | teste do journal no clone limpo |
| `leak_tip_verbose.log` | 52 667 | suíte com `--verbose` na ponta: **quais** objetos vazam |
| `leak_main_verbose.log` | 46 316 | a mesma corrida na `main` **sem** esta perna: o braço de controle |
| `branch_flake_probe.log` | 41 581 | corrida que reproduz o vermelho intermitente do runner |
| `branch_flake_runner01..07.log` | ~41 500 cada | sete corridas do runner na branch |
| `control_main_runner01..15.log` | ~35 700 cada | quinze corridas do runner na `main` sem esta perna |
| `ab_pipes.log` | 4 398 | seis pares (arquivo × pipe) do mesmo runner |
| `branch_carga_3_corridas.log` | 124 634 | três corridas do runner com a máquina carregada |
| `carga_da_maquina.log` | 2 067 | a carga da máquina durante essas três corridas |
| `artifacts.sha256` | — | SHA-256 de cada arquivo acima |

Os logs são cópias literais do stdout/stderr das corridas; `artifacts.sha256` é conferível com
`sha256sum -c artifacts.sha256` a partir desta pasta.

## 2. As sete corridas do fecho

Todas headless, máquina livre, medição serial (nenhum gate de timing roda com outra carga), e
todas com **zero** `SCRIPT ERROR` nas duas correntes (stdout e stderr).

| Corrida | Revisão | Comando | Resultado |
| --- | --- | --- | --- |
| branch, suíte | `0762b43` | `--headless --path . tests/smoke_test.tscn` | **252 checagens / 0 falhas / 43,0 s**, exit 0 |
| branch, runner | `0762b43` | `--headless --path . --script tests/aether_reactions_test.gd` | **225 checagens / 0 falhas / 15,343 s**, exit 0 |
| `main` mergeada, suíte | `4b858c2` | idem, na árvore do merge | **252 checagens / 0 falhas / 43,1 s**, exit 0 |
| clone limpo, `--import` | `4b858c2` | `--headless --path <clone> --import` | exit 0, zero `SCRIPT ERROR` |
| clone limpo, suíte | `4b858c2` | idem, em `C:/tmp/af11-clone` | **252 checagens / 0 falhas / 42,9 s**, exit 0 |
| clone limpo, suíte (2ª) | `4b858c2` | idem, mesmo clone, mesmo comando | **252 checagens / 0 falhas / 42,9 s**, exit 0 |
| clone limpo, runner | `4b858c2` | idem, em `C:/tmp/af11-clone` | **225 checagens / 0 falhas / 15,451 s**, exit 0 |
| clone limpo, journal | `4b858c2` | idem, em `C:/tmp/af11-clone` | **128 checagens / 0 falhas / 5,811 s**, exit 0 |

Linhas literais:

```
== 252 checagens  0 falhas  43.0 s de teste ==      (branch_suite.log)
225 checagens 0 falhas 15.343 s                       (branch_runner.log)
== 252 checagens  0 falhas  43.1 s de teste ==      (merged_main_suite.log)
== 252 checagens  0 falhas  42.9 s de teste ==      (clone_suite.log)
== 252 checagens  0 falhas  42.9 s de teste ==      (clone_suite_run2.log)
225 checagens 0 falhas 15.451 s                       (clone_runner.log)
128 checagens 0 falhas 7/7 testes concluidos 5.811 s (clone_journal.log)
```

O censo do runner é `EXPECTED_CHECKS = 225` ([`tests/aether_reactions_test.gd:34`](../../tests/aether_reactions_test.gd#L34))
e a suíte é 252 — os dois números que o [README](../../README.md) fixa como pin. O clone foi feito
assim:

```sh
git clone --no-hardlinks C:/Aetherfall C:/tmp/af11-clone
git -C C:/tmp/af11-clone checkout 4b858c2
C:/Aetherfall/.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path C:/tmp/af11-clone --import
C:/Aetherfall/.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path C:/tmp/af11-clone tests/smoke_test.tscn
```

O `--import` frio sai com **exit 0** e termina em `[ DONE ] loading_editor_layout`, sem nenhum
`SCRIPT ERROR` (`clone_import.log`). O clone não tem `.godot/` nem `.tools/` antes do import.

O diagnóstico final confere dígito a dígito entre a `main` mergeada e o clone limpo:
`aether_energy` `11,7803441542201`, `births` 2, `census_cap` 12, `census_refusals` 0, `chunks` 64,
`edits` 13, `feet` `(64.5, 31.0, 64.5)`, `meshes` 147, `pack_pairs` 21, `pending_respawns` 1,
`tick` 403, `triangles` 214 480, `wolves` 7, `wolves_alive` 7, `load_created` 0, `load_retired` 0,
`dropped_ticks` 0. Só os tempos de boot e de passo se movem, como sempre: `gen_ms` 993,754 →
980,145, `mesh_ms` 4 414,338 → 4 428,196 e `worst_sim_ms` 11,629 → 13,684 (média e pico são
corrida, não faixa).

## 3. O par de vazamento do quit: o objeto é nomeado

O par `ObjectDB instances were leaked` / `resources still in use` aparece no stderr da ponta
(`branch_suite.err`), da `main` mergeada (`merged_main_suite.err`) e da **primeira** corrida do
clone (`clone_suite.err`, 249 bytes) — e **não** aparece na segunda corrida do mesmo clone, mesmo
comando, mesma árvore (`clone_suite_run2.err`, **0** bytes). A leitura de retorno da perna 19 tinha
deixado esse par como "o que o par acompanha, não o que o par causa"; aqui o par foi pursued até o
objeto, com `--verbose`:

```
WARNING: 4 ObjectDB instances were leaked at exit (run with `--verbose` for details).
Leaked instance: AudioStreamPlaybackOggVorbis:9223372205264472872 - Reference count: 1
Leaked instance: OggPacketSequencePlayback:9223372205281250089 - Reference count: 1
Leaked instance: OggPacketSequence:9223372205180586794 - Reference count: 3
Leaked instance: AudioStreamOggVorbis:9223372205197364011 - Reference count: 1
Resource still in use: res://assets/audio/amb/amb_birds.ogg (AudioStreamOggVorbis)
```

O braço de controle é a mesma corrida na `main` **sem** esta perna (`e7a5fe7`, `leak_main_verbose.log`):
lá o par sai **maior** — **16 ObjectDB instances** e **6 resources** — e com o **mesmo** objeto:
`res://assets/audio/amb/amb_birds.ogg`. Ou seja: o par **precede** a perna 11, ele não é desta
perna, e o que ele acompanha é a ambiência de pássaros tocando no instante em que o processo morre —
o débito já medido e escrito na seção "Débitos" deste arquivo, com a sonda de seis braços que
mostrou que `stop()` no mesmo tick não resolve e que `stop()` seguido de mais 20 frames limpa. O que
varia entre corrida e corrida é **se a ambiência ainda estava tocando na saída** — por isso a
primeira corrida do clone imprime o par e a segunda não, e por isso o número de instâncias é 4 no
clone e 16 na `main`.

## 4. O vermelho intermitente do runner fecha nos dois braços

A checagem "nenhum estouro de subtree no budget" é a que falha intermitentemente
(`branch_flake_probe.log`: `225 checagens 1 falhas 17.534 s`, com `trips=1` no cenário estreito). A
atribuição fecha nos dois sentidos:

- **a perna não é a causa** — o braço de controle, quinze corridas do runner na `main` **sem** esta
  perna (`control_main_runner01..15.log`), deu o mesmo vermelho uma vez
  (`control_main_runner10.log`), com a mesma assinatura (`trips` no cenário estreito ou no de
  matilha, conforme a corrida);
- **a carga da máquina é a causa** — as três corridas com a máquina carregada
  (`branch_carga_3_corridas.log`) deram vermelho em duas, e a carga está registrada segundo a
  segundo em `carga_da_maquina.log` (`proc_pct` entre 19 e 35, `process_pct` em torno de 1 550);
  com a máquina livre e as corridas em série, nenhuma das corridas desta pasta falha essa
  checagem;
- **o desvio de I/O não muda nada** — os seis pares de `ab_pipes.log` (mesma corrida, uma gravando
  em arquivo e outra por pipe) deram o mesmo `trips` com o mesmo formato, com `trips_solo` e
  `trips_matilha` alternando de braço em braço.

A leitura é a que o furo #20 já registra: o `SubtreeGuard` cronometra **parede de relógio**, e
GDScript não tem relógio de CPU, então `trips == 0` é um portão de velocidade de máquina, não um
portão de código. Nenhuma linha de código mudou por causa disso nesta perna.

## 5. O que o fecho não mudou

A árvore de código do pin é a da ponta `0762b43` mais o merge; o que o merge acrescenta é `.md` e
`.log`. Conferência por hash de árvore:

```
git rev-parse 4b858c2:src 4b858c2:tests
30873d664a9577bcd3e709046cc708923456c372
975eac5a471dc1e064441474ef6e13866076d34f
```

Contra o pin anterior (`ab9ffa1`, perna 19), `src` era `45efe977f74de…` e `tests` era
`37eb429c142d…`: **mudaram**, porque a perna 11 escreve em `src/entities/wolf.gd`, `src/main.gd`,
`src/ai/mind_oracle.gd` e nos dois runners.

O journal **não se moveu**: o lote novo (fase, idade, cooldown) é chave de registro do animal no
disco, não campo da projeção mínima do `TickJournal`
([`src/persistence/tick_journal.gd:16-44`](../../src/persistence/tick_journal.gd#L16-L44)), então
`FORMAT_VERSION` continua **1** e os hashes publicados das rodadas anteriores valem. A checagem 7
fecha nos dois sentidos — o hash **igual** depois do lote e **diferente** quando muda o que está na
projeção — e está no runner desta pasta.

## 6. O que esta pasta não fecha

Nenhum gate de fase (mandato 4). Ecologia de verdade — presa, fome populacional, migração,
espécies — é P2 e continua `[TARGET]`; aqui entra um predador que se reproduz e envelhece, com
censo no disco. O multi-semente (02) e o budget agregado (04) continuam abertos, e um censo
variável **aumenta** a dívida dos dois. A perna seguinte da fila é a **16** (as tocas do dono), que
precisa do censo variável desta perna para decidir quantas alimentam.
