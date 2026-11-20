# Rodada bioma (dossiê 09) — o que foi lido, com o log de cada número

Motor Godot 4.7.2-stable (`ed1daf0bf`), binário `.tools/Godot_v4.7.2-stable_win64.exe`,
md5 `2afa3142b68f7758755dc6015c54cbd8` conferido nesta sessão. `.tools/` é gitignored, então
**nenhum clone abaixo tem o binário nem `.godot/`**: cada um recebeu `--import` frio (exit 0,
zero `SCRIPT ERROR`) antes da primeira corrida, e o binário usado foi o absoluto da árvore de
trabalho. Árvore medida: `44c9d94` (ponta de `feat/bioma-e-cor-de-pelo-09`), `src` =
`9f3a952dc123…`, `tests` = `56e487343728…`. Chão: `main` = `e7e30e6`, a base exata da branch
(`git merge-base main HEAD` = `e7e30e6`, e `main` não andou desde então).

## 1. Gates de contagem — o contrato é a última linha

| # | onde rodou | suíte `tests/smoke_test.tscn` | runner `--script tests/aether_reactions_test.gd` |
|---|---|---|---|
| 1 | árvore de trabalho, conteúdo de `44c9d94` | `== 237 checagens  0 falhas  35.5 s de teste ==` exit 0, 316 linhas, `SCRIPT ERROR` 0 | `119 checagens 0 falhas 2.064 s` exit 0, `SCRIPT ERROR` 0 |
| 2 | clone limpo de `44c9d94`, `--import` frio | `== 237 checagens  0 falhas  35.5 s de teste ==` exit 0, 316 linhas, `SCRIPT ERROR` 0 | `119 checagens 0 falhas 2.044 / 2.028 / 2.017 s`, exit 0 nos três, `SCRIPT ERROR` 0 |
| 3 | clone limpo de `e7e30e6` (chão), `--import` frio | não rodou — o número desta árvore já está publicado na rodada dos rastros | `109 checagens 0 falhas 2.012 / 1.995 / 2.052 s`, exit 0 nos três, `SCRIPT ERROR` 0 |

Censo interno do runner, conferido em todas as corridas da branch: `censo de testes completos
24/24` e `censo de checagens 119/119`. Na branch, 21 cenários viraram 24 (`_test_biome`,
`_test_fur_colour`, `_test_imprint_bias`) e 109 checagens viraram 119.

Árvore de trabalho × clone, linha a linha (`worktree-44c9d94-suite.log` vs
`clone-44c9d94-suite.log`, CR normalizado): **14 linhas diferem de 316 e nenhuma é checagem** —
seis pares de tempo (`geracao`/`malharia`, `pior passo` do smoke, `ms=` da geração
determinística, `cronometro do passo`, `leitura do slot`, `pior passo` do teste inteiro) e o
`diagnostico final`, onde só `gen_ms` (946,922 → 958,011), `mesh_ms` (4 523,613 → 4 542,158) e
`worst_sim_ms` (10,027 → 9,754) mudam. Todos os outros campos batem dígito a dígito: `tick=359`,
`wolves_alive=4`, `dropped_ticks=0`, `triangles=214480`, `meshes=147`, `chunks=64`, `edits=13` e
`aether_energy = 9,44745890423656`.

O ruído do `quit()` não está entre as 14 linhas: a dupla aparece nos **três** logs de suíte desta
pasta (trabalho, clone e a sabotagem de coluna profunda do §2b), sempre em `WARNING: 8 ObjectDB
instances were leaked at exit` na linha 313 e `ERROR: 4 resources still in use at exit` na linha 315.
Dos doze runners — os dez limpos e as duas sabotagens do §2 — nenhum imprime uma linha de cada
padrão. Ver §5.

## 2. O viés existe, e as duas metades da fronteira podem ficar vermelhas

| corrida | o que a árvore fazia | última linha | primeira linha vermelha |
|---|---|---|---|
| `sab-red-linha-da-tabela.log` | um multiplicador trocado: `arid/work` 1,30 → 1,10 | `119 checagens 1 falhas 2.045 s` | `FALHA premissa: vies_lido_confirma_tabela_medida \| … arid/work=1.10 …` |
| `sab-red-vies-dentro-do-campo.log` | o multiplicador movido para dentro de `AetherField.imprint` (×1,25) | `119 checagens 7 falhas 2.031 s` | `FALHA premissa: imprint cru no campo devolve o valor do evento \| … work sem=0.5250 com=0.4462 razao=0.8500` |

As sete falhas da segunda corrida não são só a checagem nova: `medo local com jogador invisivel`
aparece vermelha com `east=4.000` — o valor do imprint estoura o `MAX_VALUE 4,0` quando o
multiplicador age dentro do campo. É a razão pela qual a fronteira é requisito, não estilo.

Verde correspondente (`clone-44c9d94-runner-1.log`):

```
OK premissa: vies_lido_confirma_tabela_medida | frozen/work=0.85 … wetland/fear=0.90
OK premissa: imprint cru no campo devolve o valor do evento | …
OK imprint_bioma_tem_mesma_ordem | biomas_colhidos=3 …
OK media do vies por canal dentro da banda medida | linhas=4  work=1.0000 blood=1.0125 fear=1.0125
```

`biomas_colhidos=3`: a semente `20261116` não expõe nenhuma coluna `arid` na varredura do
runner, por isso o pino também lê as quatro linhas direto da tabela — linha sem conferência não
passa. A média por canal (trabalho 1,0000; sangue e medo 1,0125) é redistribuição, não inflação:
a linha `temperate` é a identidade nos três canais.

## 2b. A firma do terreno tem de ver abaixo do bloco de topo

`bioma_nao_altera_terreno` (suíte) compara quatro assinaturas: relevo das 16 colunas, grade 32 × 32
de blocos de topo, histograma do topo e SHA dos 1 048 576 voxels do mundo. A corrida
`sab-red-coluna-profunda-suite.log` faz exatamente o erro que o dossiê §1.2 proíbe, mas **fora do
topo**: o `sub` de `generate_chunk` passa a depender do bioma (`FROZEN` → `STONE` nos três blocos
abaixo do de superfície). Última linha `== 237 checagens  1 falhas  35.6 s de teste ==`, exit 1, zero
`SCRIPT ERROR`, um único FAIL:

```
[FAIL] bioma_nao_altera_terreno  divergentes=1/4  voxels=1048576  full=249dd54198bc  rel16=f1fca48dc6d1  hist=1=491 3=6 4=145 5=313 7=69
```

`rel16` e `hist` continuam idênticos ao pino: as duas amostras de superfície não veem nada abaixo do
bloco de topo, e o relevo nem sente. A varredura completa do mundo está na checagem por isso — sem o
`full`, o viamento do bioma na coluna profunda passaria verde, e é ele que mudaria o hash de revisões
antigas. Verde correspondente na mesma revisão: `clone-44c9d94-suite.log`, linha 27
`divergentes=0/4 … full=75fb058ed409`.

## 3. O custo, medido pareado contra o chão

Dez corridas do runner estreito nesta janela, cinco por árvore, as duas últimas em pares
alternados (branch, chão, branch, chão) para separar deriva de ambiente:

| árvore | `sim_step total` (µs) | `pico` (µs) | `BT soma` (µs) | `trips` |
|---|---|---|---|---|
| `44c9d94` ×3 (clone) | 385 889 · 387 450 · 379 321 | 918 · 884 · 853 | 15 430 · 15 500 · 15 130 | 0 · 0 · 0 |
| `e7e30e6` ×3 (clone) | 379 938 · 372 473 · 381 320 | 809 · 777 · 654 | 15 182 · 15 024 · 15 239 | 0 · 0 · 0 |
| `44c9d94` par a/b | 380 539 · 385 278 | 737 · 972 | 15 706 · 15 476 | 0 · 0 |
| `e7e30e6` par a/b | 385 848 · 387 730 | 850 · 773 | 15 484 · 15 679 | 0 · 0 |

Média das cinco da branch: **383 695 µs**. Média das cinco do chão: **381 462 µs**. Delta
**+0,59 %**, contra uma dispersão intra-árvore de **4,05 %** no próprio chão (372 473 → 387 730)
e de **2,12 %** na branch (379 321 → 387 450). No par alternado, a branch ficou **abaixo** do
chão na primeira dupla (380 539 vs 385 848) e acima na segunda (385 278 vs 387 730).

`pico` é o único estatístico que se move de forma não-trivial: 737 · 853 · 884 · 918 · 972 (branch)
contra 654 · 773 · 777 · 809 · 850 (chão), média 872,8 vs 772,6 (+13 %); 4 dos 5 valores da
branch passam do maior valor do chão, e 21 dos 25 pares possíveis são branch > chão. Com n = 5
por árvore, e sendo o pico o máximo de um único passo (a estatística mais ruidosa do rodapé),
isso é **indício, não atribuição**. A hipótese que ele aponta é a lookup de ruído + altura do
viés caindo no passo em que o evento imprime — o que a perna `bench/` do item 5 decide.

O `total` desta janela (372 473–387 730 no chão) também não é a banda publicada da rodada dos
rastros (361 464–375 216): a máquina está visivelmente mais lenta agora do que naquele par de
corridas. É a segunda vez que a banda não é portátil entre janelas, e é por isso que o número
de cima é pareado, não comparado com texto antigo.

Conclusão honesta da perna: **o viés de imprint não aparece no `sim_step` total** — o que o
dossiê 09 §4 pedia como "como sei que não ficou pior". O que ele mudou de mensurável foi o
estado do Éter, abaixo.

## 4. O efeito no mundo, que é o que a peça existe para ter

`aether_energy` do diagnóstico final da suíte, mesmo campo, mesma revisão, clone e trabalho
idênticos:

| revisão | `aether_energy` |
|---|---|
| árvores até `e7e30e6` (sem viés), em `readback.log` da rodada dos rastros, 6 logs | `9,36133219487965` |
| `44c9d94` (com viés), árvore de trabalho e clone | `9,44745890423656` |

Δ **+0,086 126 709 356 91 (+0,92 %)**. Direção esperada: a média do multiplicador é 1,0000 em
trabalho e 1,0125 em sangue e medo, então o mesmo cenário fecha com um pouco mais de campo. O
número é o que a checagem 4 chama de "redistribuição, não inflação" — e é a primeira vez nesta
rodada que uma mudança do dossiê 09 produz um efeito mensurável, não só uma checagem a mais.

## 5. Ruído do `quit()`

Medido nesta pasta com os dois padrões literais (`ObjectDB instances were leaked`,
`resources still in use at exit`): os **dois** logs de suíte carregam a dupla, idêntica,
`WARNING: 8 ObjectDB instances were leaked at exit` (linha 313) e `ERROR: 4 resources still in
use at exit` (linha 315); os **doze** outros logs — todos runners, incluídas as duas sabotagens
vermelhas — carregam zero de cada padrão. Nada aqui foi descartado por ruído: ele não é
`SCRIPT ERROR`, nenhuma checagem depende dele, e as 14 corridas têm exit coerente com a última
linha.

A comparação com a rodada anterior é do que foi capturado com stderr lá:
`rastro-duas-camadas/merge-ff347d2-suite.log` e `main-suite.log` dão **8/4**, os mesmos dois
números desta revisão; `branch-suite.log` da mesma rodada dá **4/2**. Então a dupla não é
introduzida por esta branch. O histórico do par está debitado na rodada do som
(`audio/readback.log:3-4`, `leaked_or_inuse_lines=2` nos dois logs de suíte daquela revisão), e
aquela rodada tem uma sonda que nomeia objetos de playback de OGG
(`AudioStreamPlaybackOggVorbis`, `OggPacketSequence` de `amb_birds.ogg`, `audio/leak-probe.log`)
— mas a sonda é um braço de cena própria, não os 8 da suíte. A atribuição dos 8/4 da suíte
continua aberta, e nada neste recorte depende dela. Os SHA-256 de cada log e de cada fonte da
revisão medida estão na seção seguinte.

## 6. Manifestos desta pasta

- [`artifacts.sha256`](artifacts.sha256): os 15 logs acima, byte a byte, computados depois de
  copiados para cá; `sha256sum -c` na pasta devolve 15 `OK`, zero divergências.
- [`sources.sha256`](sources.sha256): as mesmas 79 fontes da rodada dos rastros (o conjunto de
  paths é idêntico, conferido por `diff`), verificadas dentro do clone limpo de `44c9d94`: 79
  `OK`, 0 falhas. Conferenzas da rodada anterior permanecem vinculadas ao manifesto delas.
- Este arquivo não se auto-lista em nenhum dos dois.

## 7. Limites desta evidência

- Nada aqui fecha gate de fase, e nada é HOT agregado dos cinco lobos: o runner é um lobo por
  cenário.
- Os µs desta janela não são comparáveis aos publicados na rodada dos rastros; só os pares
  branch/chão da mesma tabela §3 se comparam entre si.
- O `pico` de §3 não tem poder de decisão com n = 5 e é a única coisa que se moveu.
- As checagens de bioma determinístico, cor do pelo e firma do terreno rodam em `44c9d94` com a
  semente fixa `20261116`; multi-semente continua sendo item 3 da fila.
