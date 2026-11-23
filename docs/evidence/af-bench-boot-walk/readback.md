# Leitura de retorno — af-bench `boot_walk_10min` com `dt` fixo (dossiê 07, peças b e c)

Branch `bench/af-bench-boot-walk-07b`, aberta de `main` em `99d1167`. A peça entrega o runner
`tests/af_bench.gd` e as três execuções de 12 000 ticks que provam a premissa do dossiê: com o
passo alimentado por `dt` fixo, e não pelo relógio de parede, a mesma semente devolve o mesmo hash
na projeção do journal nas três corridas, cada uma em arquivo novo.

Nenhum arquivo de `src/` foi tocado. O runner é o único código novo; `SHA-256` dele, como commitado
junto desta pasta: `cb6c2aafa7ef2c728d3dd3db282a96a06ccc40729b19240a4fa072176c95058e`.

## 1. O que está nesta pasta

| Arquivo | Bytes | O que prova |
| --- | --- | --- |
| `run-1.log` / `run-2.log` / `run-3.log` | 3 577 cada | stdout+stderr literais das três corridas do gate |
| `suite_final.log` | 22 795 | suíte completa na ponta desta branch (`tests/smoke_test.tscn`) |
| `artifacts.sha256` | — | SHA-256 de cada arquivo acima; confere com `sha256sum -c artifacts.sha256` |

Os `.jsonl` gravados pelas corridas (888 894 bytes cada) **não** são versionados: são reproduzíveis
a partir do comando abaixo, e os três SHA-256 estão na tabela da seção 3 — que é justamente o que
se compara. Um clone limpo precisa do `--import` antes de qualquer `--script`, senão `class_name`
não resolve.

## 2. O comando literal das três corridas

```sh
W="C:/Aetherfall/.qoder/worktrees/agent-general-purpose-eb573c98"
G="C:/Aetherfall/.tools/Godot_v4.7.2-stable_win64_console.exe"
for i in 1 2 3; do
  rm -f .tools/af-bench/run-$i.jsonl
  "$G" --headless --path . --script tests/af_bench.gd \
       -- --scenario=boot_walk_10min --tick-journal=$W/.tools/af-bench/run-$i.jsonl \
       > .tools/af-bench/run-$i.log 2>&1
  echo "run $i exit=$?"
done
```

As três execuções foram corridas **em série**, uma por vez, sem outro processo de medição no meio.
O caminho do journal vem da CLI e é lido pelo próprio jogo
([`src/main.gd:993-1000`](../../../src/main.gd#L993-L1000)); `TickJournal.start()` recusa caminho que
já existe ([`src/persistence/tick_journal.gd:50-51`](../../../src/persistence/tick_journal.gd#L50-L51)),
então "arquivo novo por corrida" é imposto pelo código, não pela disciplina de quem rodou.

## 3. O que cada corrida devolveu

| Corrida | exit | tick final | `records` | linhas lidas do arquivo | `dropped_ticks` | hash da última linha | SHA-256 do arquivo |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `run-1` | 0 | 12 000 | 12 000 | 12 000 (ticks 1..12 000, monotônicos) | 0 | `a6addd428b7140fb978aca191a8b3c10b5f7a8a4515531aea775e1574a54dfd7` | `d4ad8992598c128b5d6d2747bce13a28c7b2d44c432f5db2132d87d82bc7ea4d` |
| `run-2` | 0 | 12 000 | 12 000 | 12 000 | 0 | `a6addd428b7140fb978aca191a8b3c10b5f7a8a4515531aea775e1574a54dfd7` | `d4ad8992598c128b5d6d2747bce13a28c7b2d44c432f5db2132d87d82bc7ea4d` |
| `run-3` | 0 | 12 000 | 12 000 | 12 000 | 0 | `a6addd428b7140fb978aca191a8b3c10b5f7a8a4515531aea775e1574a54dfd7` | `d4ad8992598c128b5d6d2747bce13a28c7b2d44c432f5db2132d87d82bc7ea4d` |

Os arquivos estão em `C:/Aetherfall/.qoder/worktrees/agent-general-purpose-eb573c98/.tools/af-bench/run-{1,2,3}.jsonl`
(diretório gitignored). Além de iguais no hash da última linha, os três são **byte-idênticos**: as
12 000 linhas de `[tick, hash]` coincidem, não só a última. `records` é lido do disco, linha por
linha, e confrontado com `journal.records` e com `main.state_hash()` — a checagem
`ultima linha == hash do estado atual` fecha o depoimento do arquivo com o estado vivo.

As três últimas linhas de cada log:

```
16 checagens 0 falhas 46.804 s     # run-1
16 checagens 0 falhas 46.933 s     # run-2
16 checagens 0 falhas 46.814 s     # run-3
```

Zero `SCRIPT ERROR`, zero `ERROR`, zero `WARNING` e zero `FALHA` nos três logs. A contagem de
checagens (16, censo incluso) é a que teria caído se um passo abortasse em silêncio.

## 4. Tempo do lote (medição serial, máquina livre)

Condições: 2026-11-23, 00 h 17 min – 00 h 20 min locais, `tasklist` confirmando nenhum outro
processo Godot/Python/llama-server antes e durante, três corridas em série.

Tempo de parede do processo (inclui o boot: mundo, 64 chunks de malha, journal):
47,447 s / 47,616 s / 47,461 s.

**tempo medio de 3 corridas: 47,5 s**

Dentro do runner (do `_initialize` ao rodapé, sem o startup do motor): 46,804 / 46,933 / 46,814 →
média 46,9 s. Isto **não** é gate e **não** é comparação com a sessão viva: 12 000 chamadas de passo
em laço fechado não são 12 000 frames de janela a 60 Hz. O número diz só quantos ticks por segundo
de CPU o lote rende (`12 000 / 46,9 ≈ 256 ticks/s`, ~12,8× o tempo real de 20 Hz), e nada além
disso. O gate da peça é binário: `records == 12000`, `dropped_ticks == 0`, hash final idêntico nas
três corridas e exit 0.

## 5. A observação que a peça deixa aberta: `estouros_guarda`

Linha impressa por cada corrida (a mesma nas três, literal do `run-1.log`):

```
OBSERVACAO estouros_guarda=4 lobos_com_guarda_lida=7 budget_us=400 last_us=2210..3397 ticks=tick 1859/lobo 6, tick 4333/lobo 6, tick 9056/lobo 6, tick 11537/lobo 6
```

(corridas 2 e 3: mesmos ticks, `last_us` 2255..3476 e 2209..3727).

O `SubtreeGuard` da mente do lobo mede o próprio passo com relógio de parede e devolve `FAILURE`
acima do orçamento ([`src/ai/behavior/bt_tree.gd:130-137`](../../../src/ai/behavior/bt_tree.gd#L130-L137),
orçamento declarado em [`src/entities/wolf.gd:380-381`](../../../src/entities/wolf.gd#L380-L381)). Isso
é um canal de relógio dentro do caminho hashado, porque há folha da subtree guardada que escreve o
que a projeção lê: o imprint de MEDO no Éter
([`src/entities/wolf.gd:431`](../../../src/entities/wolf.gd#L431)) e o `mind.remember` do rastro
examinado ([`src/entities/wolf.gd:559`](../../../src/entities/wolf.gd#L559)). `intent` em si não sai
da árvore (sai do scorer, [`src/entities/wolf.gd:784`](../../../src/entities/wolf.gd#L784)), então o
risco não é trocar de intento e sim **suprimir uma escrita**.

A medição diz que não é beira de orçamento: a própria guarda mediu 2,2 ms a 3,7 ms nesses quatro
ticks contra 400 µs, e os ticks são **os mesmos nas três corridas** e sempre do mesmo lobo (6) —
logo é um stall reprodutível naquela árvore, não ruído de carga. Uma sonda anterior, com contagem por
máximo-identidade, registrou cinco estouros (um a mais, em outro lobo) e ainda assim produziu journal
byte-idêntico: neste cenário o estouro não chegou à projeção. Isso é **observação, não prova** — um
estouro no tick em que a folha de fuga está imprimindo MEDO mudaria o Éter hashado, e em outra máquina
o conjunto de ticks pode ser outro.

Decisão registrada: o estouro **não** entra como checagem nem como gate — sai como `OBSERVACAO` com o
tick de cada disparo, para a peça não esconder o número. Fechar o canal é decisão de `src/` (subir o
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
- **Não fecha gate de fase nenhuma** (mandato 4). Entrega instrumento e a primeira medição.
- **Não mede o que a máquina faz sob carga.** O tempo da seção 4 foi medido com a máquina livre e
  serial; com outro agente no mesmo `PC` o número muda, e o `estouros_guarda` pode mudar com ele.

## 7. Como conferir de novo

```sh
cd <clone> && "$G" --headless --path . --import          # obrigatório no clone ainda não importado
# depois o loop da seção 2, com W= apontando para o clone
sha256sum .tools/af-bench/run-1.jsonl .tools/af-bench/run-2.jsonl .tools/af-bench/run-3.jsonl
```

Espera-se `d4ad8992598c128b5d6d2747bce13a28c7b2d44c432f5db2132d87d82bc7ea4d` nos três, exit 0 em cada
corrida e `16 checagens 0 falhas`. O `maior_andar=64.2 m` da linha `GATE` é o jogador andando de
verdade por input real (`Input.action_press`, vaivém de 30 s de lógica por perna) — a checagem
`o cenario anda (nao e boot parado)` existe para o lote não ser três mundos parados.

## 8. Suíte na branch

`--headless --path . tests/smoke_test.tscn` na ponta desta branch: última linha
`== 252 checagens  0 falhas  42.5 s de teste ==`, exit 0, zero `FALHA` e zero `SCRIPT ERROR` no log
(`suite_final.log`). As duas linhas de ruído de saída do motor que aparecem depois da linha final
(`4 ObjectDB instances leaked`, `2 resources still in use`) já estavam na corrida da base na mesma
branch — não vêm desta peça, que não toca `src/`.
