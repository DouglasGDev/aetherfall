# Leitura de retorno — af-bench `boot_walk_10min` com `dt` fixo (dossiê 07, peças b e c)

Branch `bench/af-bench-boot-walk-07b`. Aberta de `main` em `99d1167` e trazida, nesta rodada, para dentro
da árvore de hoje com `git merge main --no-ff` (merge `35959e0`, `main` em `1a00f7a`). O que se re-mede
aqui é a peça que o AGENTS.md manda re-medir quando a `main` andou: as pernas 16 (tocas da alcateia) e 19
(auto-pulo de bloco) escreveram `src/` depois do `99d1167`, e o gate de determinismo é justamente sensível
a isso. A roda de hoje é a mesma medição na nova árvore, com o `a6addd…` antigo guardado como registro da
base, não reescrito.

O mundo medido é **byte-idêntico ao pin `9b2c65a`**: a árvore `src/` deste HEAD (`git rev-parse HEAD:src`)
é `64f137bcb1f8e95bd9a64fe7843e4e7b72f7326e`, o mesmo hash que o AGENTS.md registra para o pouso da perna
16. `tests/` deste HEAD (`8fbffd907e708c03cb1c5bb89518c6a7a619c5ec`) difere do pin
(`88a1541c2f9f6fc3dd0e1d237b3e5656d9eea3c9`) **só** pelo `tests/af_bench.gd` e seu `.uid`, que vivem nesta
branch; nada que a suíte executa mudou. Por isso o contrato da suíte (255/0) transfere por identidade de
`src/` — e ainda assim a re-rodamos, seção 8.

O runner é o único código novo. Nesta rodada ele ganhou **uma linha de `OBSERVACAO`** que imprime os três
diagnósticos de boot/passo que `diagnostics()` já expõe (`src/main.gd:1161` traz `gen_ms` e `mesh_ms`,
`src/main.gd:1180` traz `worst_sim_ms`) — a seção 4 os pede e antes eles só existiam na memória do objeto,
nunca chegavam ao log publicado. É `print` de stdout, não checagem nem gate: não toca estado do mundo (ver
seção 3 — o hash não se moveu). `SHA-256` do runner como commitado junto desta pasta:
`87498b66d6872ada6c59311d80238fb3369648f0f791580999487588d806618f` (o da base era
`cb6c2aafa7ef2c728d3dd3db282a96a06ccc40729b19240a4fa072176c95058e`, mantido como registro na seção 9).

## 1. O que está nesta pasta

| Arquivo | Bytes | O que prova |
| --- | --- | --- |
| `run-1.log` / `run-2.log` / `run-3.log` | 3 811 cada | stdout+stderr literais das três corridas do gate nesta árvore |
| `suite_final.log` | 23 942 | suíte completa na ponta desta branch (`tests/smoke_test.tscn`) |
| `artifacts.sha256` | — | SHA-256 de cada arquivo acima; confere com `sha256sum -c artifacts.sha256` |

Os `.jsonl` gravados pelas corridas (888 894 bytes cada) **não** são versionados: são reproduzíveis
a partir do comando abaixo, e os três SHA-256 estão na tabela da seção 3 — que é justamente o que
se compara. Um clone limpo precisa do `--import` antes de qualquer `--script`, senão `class_name`
não resolve.

## 2. O comando literal das três corridas

```sh
W="C:/Aetherfall/.qoder/worktrees/agent-general-purpose-8bf6db13"
G="C:/Aetherfall/.tools/Godot_v4.7.2-stable_win64_console.exe"   # 4.7.2.stable.official.ed1daf0bf
cd "$W" && "$G" --headless --path . --import                     # obrigatório, o worktree não traz .godot/
for i in 1 2 3; do
  rm -f .tools/af-bench/run-$i.jsonl                             # caminho novo por corrida, nunca reusado
  "$G" --headless --path . --script tests/af_bench.gd \
       -- --scenario=boot_walk_10min --tick-journal=$W/.tools/af-bench/run-$i.jsonl \
       > .tools/af-bench/run-$i.log 2>&1
  echo "run $i exit=$?"
done
```

As três execuções foram corridas **em série**, uma por vez, com `Get-CimInstance Win32_Process -Filter
"Name like '%Godot%'"` confirmado vazio antes de cada lote e nenhum outro processo de medição no meio. O
caminho do journal vem da CLI e é lido pelo próprio jogo
([`src/main.gd:1231-1238`](../../../src/main.gd#L1231-L1238)); `TickJournal.start()` recusa caminho que já
existe
([`src/persistence/tick_journal.gd:50-51`](../../../src/persistence/tick_journal.gd#L50-L51)), então
"arquivo novo por corrida" é imposto pelo código, não pela disciplina de quem rodou.

## 3. O que cada corrida devolveu

| Corrida | exit | tick final | `records` | linhas lidas do arquivo | `dropped_ticks` | hash da última linha | SHA-256 do arquivo |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `run-1` | 0 | 12 000 | 12 000 | 12 000 (ticks 1..12 000, monotônicos) | 0 | `fd9b41e0dc3ae2eb5f4c76cd6467ffc8d6204134354e5f765fbc1f6f6d604a32` | `3e6aaf49b88fc37c34a619ed6d957604b07b674d90a10ea0b6137c238684661f` |
| `run-2` | 0 | 12 000 | 12 000 | 12 000 | 0 | `fd9b41e0dc3ae2eb5f4c76cd6467ffc8d6204134354e5f765fbc1f6f6d604a32` | `3e6aaf49b88fc37c34a619ed6d957604b07b674d90a10ea0b6137c238684661f` |
| `run-3` | 0 | 12 000 | 12 000 | 12 000 | 0 | `fd9b41e0dc3ae2eb5f4c76cd6467ffc8d6204134354e5f765fbc1f6f6d604a32` | `3e6aaf49b88fc37c34a619ed6d957604b07b674d90a10ea0b6137c238684661f` |

Os arquivos estão em `C:/Aetherfall/.qoder/worktrees/agent-general-purpose-8bf6db13/.tools/af-bench/run-{1,2,3}.jsonl`
(diretório gitignored). Além de iguais no hash da última linha, os três são **byte-idênticos**: as 12 000
linhas de `[tick, hash]` coincidem, não só a última. `records` é lido do disco, linha por linha, e
confrontado com `journal.records` e com `main.state_hash()` — a checagem `ultima linha == hash do estado
atual` fecha o depoimento do arquivo com o estado vivo. A projeção andou de verdade durante o lote: primeiro
hash `7edbdd3c87603bfe…`, último `fd9b41e0dc3ae2eb…`, 12 000 hashes distintos de 12 000
(`a projecao moveu durante a corrida`).

As três últimas linhas de cada log:

```
16 checagens 0 falhas 45.978 s     # run-1
16 checagens 0 falhas 45.719 s     # run-2
16 checagens 0 falhas 45.724 s     # run-3
```

Zero `SCRIPT ERROR`, zero `ERROR`, zero `WARNING` e zero `FALHA` nos três logs. A contagem de checagens
(16, censo incluso) é a que teria caído se um passo abortasse em silêncio.

**A linha de `OBSERVACAO` do rodapé não moveu o hash.** A rodada foi feita duas vezes: primeiro com o
runner antigo (`cb6c2aa…`), sem a linha nova, e depois com o runner que a imprime (`87498b66…`). Os dois
lotes deram o MESMO hash final `fd9b41e0dc3ae2eb…` e o MESMO SHA-256 de arquivo `3e6aaf49b88fc37c…`. Isso é
corroboração direta do argumento do dossiê §3: um `print` de stdout não entra no estado, então não pode ser
a razão de um hash se mover.

## 4. Tempo do lote (medição serial, máquina livre)

Condições: 2026-11-23, madrugada, `Get-CimInstance` confirmando nenhum outro processo Godot antes e entre
cada corrida, três corridas em série.

Tempo de parede do processo (inclui o startup do motor e o boot: mundo, 64 chunks de malha, journal):
**46,619 s / 46,324 s / 46,331 s** → média **46,4 s**.

Dentro do runner (do `_initialize` ao rodapé, sem o startup do motor): **45,978 / 45,719 / 45,724 s** →
média 45,8 s. Isto **não** é gate e **não** é comparação com a sessão viva: 12 000 chamadas de passo em laço
fechado não são 12 000 frames de janela a 60 Hz. O número diz só quantos ticks por segundo de CPU o lote
rende (`12 000 / 45,8 ≈ 262 ticks/s`, ~13× o tempo real de 20 Hz), e nada além disso. O gate da peça é
binário: `records == 12000`, `dropped_ticks == 0`, hash final idêntico nas três corridas e exit 0.

Os três diagnósticos que a linha nova passou a publicar, por corrida (lidos do mesmo `diagnostics()` de
`src/main.gd:1161` e `src/main.gd:1180`, e não de uma corrida separada):

| Corrida | `gen_ms` (boot: geração do mundo) | `mesh_ms` (boot: 64 chunks de malha) | `worst_sim_ms` (pior passo do lote) |
| --- | --- | --- | --- |
| `run-1` | 942,5 | 4 314,3 | 13,09 |
| `run-2` | 945,9 | 4 318,9 | 14,60 |
| `run-3` | 939,5 | 4 319,2 | 14,70 |

Estes três são **observação, não gate**: o `dt` fixo remove a máquina do hash, mas não da parede que o
`clock` cronometra, então `worst_sim_ms` ainda é função da carga do PC. Nenhum deles fecha o bake-off do
dossiê §4 — um braço só é medido aqui, não dois.

## 5. A observação que a peça deixa aberta: `estouros_guarda`

Linha impressa por cada corrida (literal do `run-1.log`; corridas 2 e 3 abaixo):

```
OBSERVACAO estouros_guarda=16 lobos_com_guarda_lida=6 budget_us=400 last_us=991..3407 ticks=tick 305/lobo 2, tick 328/lobo 2, tick 1295/lobo 4, tick 1852/lobo 2, tick 1881/lobo 1, tick 3081/lobo 1, tick 3091/lobo 2, tick 3115/lobo 2
```

Corridas 2 e 3: **mesmo total (16) e os mesmos oito pares tick/lobo**, só `last_us` variando — 995..3383
(run-2) e 963..3362 (run-3). É esta a razão de o hash final bater mesmo com estouros: os estouros recaem
nos mesmos ticks nas três corridas, e o `fd9b41e0…` que fecha o lote é idêntico. Isso é "a mesma sorte",
**não** prova limpa — ver abaixo.

O `SubtreeGuard` da mente do lobo mede o próprio passo com relógio de parede e devolve `FAILURE` acima do
orçamento
([`src/ai/behavior/bt_tree.gd:130-137`](../../../src/ai/behavior/bt_tree.gd#L130-L137), orçamento de 400 µs
declarado em [`src/entities/wolf.gd:393-394`](../../../src/entities/wolf.gd#L393-394)). Isso é um canal de
relógio dentro do caminho hashado, porque há folha da subtree guardada que escreve o que a projeção lê: o
imprint de MEDO no Éter
([`src/entities/wolf.gd:444`](../../../src/entities/wolf.gd#L444), dentro da folha `fugir` quando
`_threat > 0`) e o `mind.remember` do rastro examinado
([`src/entities/wolf.gd:572`](../../../src/entities/wolf.gd#L572)). `intent` em si não sai da árvore (sai
do scorer, [`src/entities/wolf.gd:797`](../../../src/entities/wolf.gd#L797)), então o risco não é trocar de
intento e sim **suprimir uma escrita**.

A medição diz que não é beira de orçamento: a própria guarda mediu ~1,0 ms a ~3,4 ms nesses oito pares
contra 400 µs, e os pares são **os mesmos nas três corridas** — logo é um stall reprodutível naquela árvore,
não ruído de carga. Um estouro no tick em que a folha de fuga está imprimindo MEDO, ou em que
`_remember_scent` grava crença, mudaria o Éter/crença hashados; aqui o hash fechou igual, então neste
cenário o estouro não chegou à projeção — é **observação, não prova**, e em outra máquina o conjunto de
pares pode ser outro.

Nota honesta sobre o número ter subido: na base `99d1167` esta mesma peça registrou `estouros_guarda=4`
(sempre o mesmo lobo 6). Agora são 16 em seis lobos. A causa não é esta peça (não toca `src/`): é o mundo da
perna 16 ter mudado a matilha — o censo do log foi de `7/7, pares=21` para `6/6, pares=15`, com tocas
fundadas no boot e um filhote nascendo na toca 0. Mais mentes vivas lendo a árvore, outros ticks de estouro.
Decisão registrada do dono: o estouro **não** entra como checagem nem como gate — sai como `OBSERVACAO` com
o tick de cada disparo, para a peça não esconder o número. Fechar o canal é decisão de `src/` (subir o
orçamento, ou mover a escrita de Éter/crença para fora da subtree guardada) e não pertence a esta peça.

## 6. O que esta peça NÃO prova

- **Não é replay.** `TickJournal` grava `[tick, hash]` em apêndice
  ([`src/persistence/tick_journal.gd:69-87`](../../../src/persistence/tick_journal.gd#L69-L87)) e não
  existe caminho nenhum do arquivo de volta para o mundo. A frase impressa em cada log:
  `NAO e replay: o arquivo e apendice-only e nenhum byte dele volta para o mundo`.
- **Não prova determinismo da simulação inteira.** O hash cobre a projeção mínima
  ([`src/persistence/tick_journal.gd:16-44`](../../../src/persistence/tick_journal.gd#L16-L44)) e
  EXCLUI jogador, corpos, RNG, episódios, relações, timers e comandos. Três hashes iguais provam
  determinismo **do que está na projeção**.
- **Não é a trajetória da sessão viva.** Cada tick tem um passo de integração de 0,05 s, e não os
  ~3 passos de 16,7 ms da janela a 60 Hz; o caminho dos corpos é outro. O que se compara é a projeção.
- **Não fecha gate de fase nenhuma** (mandato 4). Entrega instrumento e a medição nesta árvore.
- **Não mede o que a máquina faz sob carga.** O tempo da seção 4 foi medido com a máquina livre e
  serial; com outro agente no mesmo `PC` o número muda, e o `estouros_guarda` pode mudar com ele.

## 7. Como conferir de novo

```sh
cd <clone> && "$G" --headless --path . --import          # obrigatório no clone ainda não importado
# depois o loop da seção 2, com W= apontando para o clone
sha256sum .tools/af-bench/run-1.jsonl .tools/af-bench/run-2.jsonl .tools/af-bench/run-3.jsonl
```

Espera-se `3e6aaf49b88fc37c34a619ed6d957604b07b674d90a10ea0b6137c238684661f` nos três, exit 0 em cada corrida
e `16 checagens 0 falhas`. O `maior_andar=64.2 m` da linha `GATE` é o jogador andando de verdade por input
real (`Input.action_press`, vaivém de 30 s de lógica por perna) — a checagem `o cenario anda (nao e boot
parado)` existe para o lote não ser três mundos parados.

## 8. Suíte na branch

`--headless --path . tests/smoke_test.tscn` na ponta desta branch (após o merge): última linha
`== 255 checagens  0 falhas  47.4 s de teste ==`, exit 0, zero `FALHA` e zero `SCRIPT ERROR` no log
(`suite_final.log`). As duas linhas de ruído de saída do motor que aparecem depois da linha final
(`4 ObjectDB instances leaked`, `2 resources still in use`) são do `cleanup` do próprio motor, já vistas na
corrida da base nesta mesma branch — não vêm desta peça. O 255/0 confere, por identidade de `src/`
(`64f137bcb1f8…`), com o registro do pouso da perna 16.

## 9. Registro da base anterior (`99d1167`) — o que mudou e por quê o número antigo era outro

Mantido como registro, **não** reescrito. Na abertura desta branch, a medição da mesma peça contra o `src/`
de `99d1167` (árvore `30873d664a9577bc…`) deu:

| Item | `99d1167` (base, registro) | `9b2c65a`/HEAD (rodada atual) |
| --- | --- | --- |
| hash da última linha ×3 | `a6addd428b7140fb978aca191a8b3c10b5f7a8a4515531aea775e1574a54dfd7` | `fd9b41e0dc3ae2eb5f4c76cd6467ffc8d6204134354e5f765fbc1f6f6d604a32` |
| SHA-256 do `.jsonl` ×3 | `d4ad8992598c128b5d6d2747bce13a28c7b2d44c432f5db2132d87d82bc7ea4d` | `3e6aaf49b88fc37c34a619ed6d957604b07b674d90a10ea0b6137c238684661f` |
| SHA-256 do runner | `cb6c2aafa7ef2c728d3dd3db282a96a06ccc40729b19240a4fa072176c95058e` | `87498b66d6872ada6c59311d80238fb3369648f0f791580999487588d806618f` |
| `estouros_guarda` | 4 (sempre lobo 6) | 16 (seis lobos, oito pares) |
| censo do log | `7/7, nascimentos=2, pares=21` | `6/6, nascimentos=1, pares=15` |
| suíte | 252 checagens / 0 falhas / 42,5 s | 255 checagens / 0 falhas / 47,4 s |
| runner checa | 16 / 0 | 16 / 0 |

O `records == 12000`, `dropped_ticks == 0`, hash idêntico ×3 e exit 0 valem nos dois registros — a premissa
do dossiê não furou. O que **mudou** entre eles é o mundo, não o instrumento: entre `99d1167` e `9b2c65a`
entraram em `src/` a perna 16 (tocas: `_dens`, `Wolf.den`, bandas de spawn com portão de separação —
`src/main.gd` com +296/−30 na comparação das duas árvores) e a perna 19 (auto-pulo). Como a projeção do hash
cobre Éter, edições e a mente dos lobos por identidade, qualquer mudança de spawn/dens muda o hash final —
e foi isso que aconteceu, de `a6addd…` para `fd9b41e0…`. Publicar o número da base como se fosse o de hoje
seria o "número publicado ≠ número medido nesta revisão" que o AGENTS.md veta; por isso os dois ficam, cada
um com sua árvore nomeada.
