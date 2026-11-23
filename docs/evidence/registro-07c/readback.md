# Leitura de retorno — os logs do registro da 07c saem do gitignored (dossiê 07c, fecho de evidência)

Branch `docs/evidencia-clone-limpo-07c`, aberta de `main` em
`b1e1dd4e5de2d04e7d2df03ade9b63f620c16040` (o pouso do registro da 07c). Esta pasta **não mede nada novo**:
ela arquiva os stdout que a seção **"Registro do pouso 07c na 'main'"** de
[`docs/melhorias-status.md`](../../melhorias-status.md) publica e que até aqui viviam em diretório
gitignored — **seis** corridas no clone limpo de `cea4379` (sob `.qoder/clones/clean-07c/`), **duas** suítes
em `.tools/`, o `--import` frio do próprio clone e a suíte re-rodada na ponta desta branch. O débito é de instrumento, não de código: o ciclo de
trabalho do [AGENTS.md](../../../AGENTS.md), item 6, diz que número publicado é número medido nesta revisão,
e um log que só existe nesta máquina não é conferível por ninguém que clone o repositório. Nenhum arquivo de
`src/` nem de `tests/` foi tocado aqui — `git diff --name-only b1e1dd4..HEAD -- src tests` devolve vazio.

Esta branch pousou na `main` pelo merge `--no-ff` **`5178c5ad9a7efe8283b67bb9cbf04da3774b73ed`**, e a pasta
cresceu **quatro** arquivos para que o pouso fique conferível do mesmo jeito: a suíte re-rodada na `main`
mergida, a suíte re-rodada na ponta do registro dela, e as duas réguas re-corridas nesta árvore. Re-rodar
aqui tem motivo próprio — o [`docs/melhorias-status.md`](../../melhorias-status.md) da `main` mergida carrega
**esta pasta** dentro do corpus das réguas, então os números publicados naquela seção não são os de
`214df5c`.

## 1. O que está nesta pasta

| Arquivo | O que é |
| --- | --- |
| `clean_import.log` | o `--import` frio do clone limpo de `cea4379` (exit 0, `[ DONE ] loading_editor_layout`, 0 `SCRIPT ERROR`) |
| `suite.log` | a suíte completa no clone limpo — `== 255 checagens  0 falhas  47.6 s de teste ==` |
| `runner_reactions.log` | o runner de reações no clone — `240 checagens 0 falhas 24.546 s` |
| `runner_rng.log` | o runner de RNG no clone — `27 checagens 0 falhas 2.673 s` |
| `runner_journal.log` | o runner do journal no clone — `128 checagens 0 falhas 7/7 testes concluidos 5.582 s` |
| `bench_clean.log` | `tests/af_bench.gd`, 12 000 ticks com journal — `16 checagens 0 falhas 45.920 s` |
| `bakeoff_A_clean.log` | `tests/af_bakeoff.gd`, braço A — `11 checagens 0 falhas 8.057 s` |
| `registro_branch_suite.log` | a suíte re-rodada na ponta da branch do registro — `255 / 0 / 47.9 s` |
| `merged_main_suite.log` | a suíte re-rodada na `main` mergida (`f7fef97`) — `255 / 0 / 47.4 s` |
| `evidence_branch_suite.log` | a suíte re-rodada nesta ponta, depois de arquivar tudo — `255 / 0 / 47.6 s` |
| `merged_main_5178c5a_suite.log` | a suíte re-rodada na `main` mergida (`5178c5a`) — `255 / 0 / 47.6 s`, exit 0 |
| `registro_tip_suite.log` | a suíte re-rodada na ponta do registro do pouso, com esta pasta já no corpus — `255 / 0 / 47.5 s`, exit 0 |
| `ruler_doc_anchors.log` | saída de `python tools/check_doc_anchors.py` na árvore desta branch |
| `ruler_plan_cites.log` | saída de `python .tools/verify_plan_cites.py …` na árvore desta branch |
| `ruler_doc_anchors_tip.log` | a mesma régua, re-corrida na ponta do registro do pouso |
| `ruler_plan_cites_tip.log` | a mesma régua, re-corrida na ponta do registro do pouso |
| `artifacts.sha256` | SHA-256 de cada arquivo acima (menos ele próprio); confere com `sha256sum -c artifacts.sha256` |

Os doze stdout de corrida e as quatro saídas de régua são **stdout+stderr literais** de cada execução, sem recorte: a linha citada no status está na
linha que o status diz, e o rodapé é o rodapé real do processo. Os dois caminhos absolutos que aparecem
dentro de `bench_clean.log` e `runner_journal.log` (`C:/Aetherfall/.qoder/clones/clean-07c/.tools/af-check/…`
e a pasta de `user://` do teste do journal) são o que o processo imprimiu na hora — não são instruções nem
promessa de que o diretório exista para quem clona.

## 2. A revisão pineada e as árvores

| | |
| --- | --- |
| pin medido | **`cea437959fd0867f65a2d2e2b40663df8dcd753e`** — merge `--no-ff` de `bench/bake-off-voxel-07c`, pais `166af71` e `4355935`, **33 arquivos, +1 747/−106** |
| árvores do pin | `git rev-parse cea4379:src` = `100af75ded6d50b6a26120be352cf72770f97e80` · `:tests` = `77fcb0510525a82d39bb799ff1376ff0fb6eb17b` |
| base desta branch | `b1e1dd4e5de2d04e7d2df03ade9b63f620c16040` — `:src`/`:tests` **idênticos** aos do pin (documento puro), então o contrato 255 / 0 se transmite por identidade de árvore |
| `main` mergida | **`5178c5ad9a7efe8283b67bb9cbf04da3774b73ed`** — merge `--no-ff` desta branch, pais `b1e1dd4` e `214df5c`, **15 arquivos, +2 738/−12**, todos `docs/`; `git rev-parse 5178c5a:src` / `:tests` devolvem `100af75d…` / `77fcb051…`, **as mesmas duas árvores do pin** |
| engine | `Godot Engine v4.7.2.stable.official.ed1daf0bf` — a primeira linha de **todos** os doze stdout |
| semente | a da casa, `SEED := 20261116` |

## 3. O comando, serial, máquina livre

```sh
git clone --no-hardlinks C:/Aetherfall C:/Aetherfall/.qoder/clones/clean-07c
git -C C:/Aetherfall/.qoder/clones/clean-07c checkout cea437959fd0867f65a2d2e2b40663df8dcd753e
G="C:/Aetherfall/.tools/Godot_v4.7.2-stable_win64_console.exe"   # 4.7.2.stable.official.ed1daf0bf
K="C:/Aetherfall/.qoder/clones/clean-07c"
"$G" --headless --path "$K" --import                             # clean_import.log
"$G" --headless --path "$K" tests/smoke_test.tscn                # suite.log
"$G" --headless --path "$K" --script res://tests/aether_reactions_test.gd   # runner_reactions.log
"$G" --headless --path "$K" --script res://tests/simulation_rng_test.gd     # runner_rng.log
"$G" --headless --path "$K" --script res://tests/tick_journal_test.gd       # runner_journal.log
"$G" --headless --path "$K" --script res://tests/af_bench.gd -- --scenario=boot_walk_10min --tick-journal="$K/.tools/af-check/bench.jsonl"
"$G" --headless --path "$K" --script res://tests/af_bakeoff.gd -- --arm=A
```

Antes da primeira corrida e entre cada uma delas, a guarda de contaminação: nenhum processo do engine vivo
além do próprio run (`Get-CimInstance Win32_Process -Filter "Name like '%Godot%'"`). As cinco linhas do
rodapé da mesa estão transcritas na seção 1; a de `af_bench` e a do bake-off também aparecem no
[registro](../../melhorias-status.md) com os números da linha de gate. As suítes dos parágrafos finais são o
mesmo `--headless --path <árvore> tests/smoke_test.tscn` rodado em cada árvore dele — clone limpo, ponta do
registro, `main` mergida (`5178c5a`) e ponta do registro do pouso — e nas duas últimas `<árvore>` é
`C:/Aetherfall` com a branch checkoutada (`docs/evidencia-clone-limpo-07c`, depois
`docs/registro-evidencia-merge-07c`). As réguas, na mesma ordem das árvores do registro e do pouso:

```sh
python tools/check_doc_anchors.py                                   # ruler_doc_anchors.log / ruler_doc_anchors_tip.log
python .tools/verify_plan_cites.py docs/planos/*.md docs/design/*.md \
  docs/engine/*.md docs/melhorias-status.md AGENTS.md README.md     # ruler_plan_cites.log / ruler_plan_cites_tip.log
```

## 4. As linhas que a mesa do registro cita, conferidas no arquivo

- [`suite.log:345`](suite.log) — `"edit_mesh":{"count":14,"mean_us":121496.857142857,"pending":0,"worst_us":221932}`
  na mesma linha `"edits":13, "meshes":147, "triangles":214480, "dropped_ticks":0`. A coluna é lida por um
  único consumidor: [`tests/af_bakeoff.gd:152`](../../../tests/af_bakeoff.gd#L152).
- [`bench_clean.log:34`](bench_clean.log) — a linha de gate:
  `hash_ultima_linha=fd9b41e0dc3ae2eb5f4c76cd6467ffc8d6204134354e5f765fbc1f6f6d604a32` com
  `records=12000 linhas_arquivo=12000 dropped_ticks=0 maior_andar=64.2 m`, e na linha
  [`:25`](bench_clean.log) `hashes_distintos=12000/12000 primeiro=7edbdd3c87603bfe ultimo=fd9b41e0dc3ae2eb`
  — **o mesmo hash final** das três corridas publicadas em
  [`docs/evidence/af-bench-boot-walk/readback.md`](../af-bench-boot-walk/readback.md) (linhas 65–67). É a
  prova de que o instrumento de `edit_mesh` não entrou na projeção do journal.
- A mesma corrida registra o débito do relógio da guarda, [`bench_clean.log:26-27`](bench_clean.log):
  `estouros_guarda=16 lobos_com_guarda_lida=6 budget_us=400 last_us=1004..4821`, com o porquê de importar
  logo abaixo (`bt_tree.gd:130-137` devolve `FAILURE` pelo relógio de parede e a folha suprimida pode
  escrever Éter ou crença, que entram na projeção). Este log não conserta isso; deixa o número versionado.

Contagem feita sobre os doze stdout: **zero** linhas `[FAIL]`, **zero** `SCRIPT ERROR`, e a coluna
`"llm":{}` vazia nas **quatro** suítes — nenhuma credencial entra aqui. O par do quit aparece nos **quatro**
stdout que foram capturados com `2>&1`: `suite.log:358` `WARNING: 4 ObjectDB instances were leaked at exit`
e `:360` `ERROR: 2 resources still in use at exit`, e os mesmos `:358`/`:360` em
`evidence_branch_suite.log`, `merged_main_5178c5a_suite.log` e `registro_tip_suite.log`. De
`registro_branch_suite.log` e `merged_main_suite.log` — copiados de `.tools/`, onde a corrida foi gravada só
com stdout — **não** sai nenhuma linha `WARNING` nem `ERROR`, então a ausência do par neles é do
redirecionamento, não medida. É o par cuja atribuição continua **aberta** no
[status](../../melhorias-status.md) — arquivar o log não fecha o débito: as **quatro** ocorrências têm o
mesmo `4` e o mesmo `2`, o que só reforça que é determinístico e não carga da máquina.

## 5. As réguas da ponta, e o caso que a primeira corrida pegou

Os dois arquivos `ruler_*_tip.log` são a corrida **final**, na árvore que já tem os quatro logs novos e a
seção do status que os cita: `38 arquivos · 2 854 ponteiros · 197 rótulos · 2 871 links · casos objetivos: 0`
e `2 669 citações conferidas · 34 arquivos ausentes · numeros de linha fora do arquivo: 0`, exit 0 dos dois.
A corrida **anterior** das mesmas réguas, feita quando o `>` do redirecimento ainda não tinha escrito
`ruler_plan_cites_tip.log`, devolveu **`casos objetivos: 1`** com exit 1 — `LINK QUEBRADO` na linha 5398 do
status. É o instrumento funcionando: um link para um arquivo que ainda não existe é um defeito do documento
naquele instante, e o verde seguinte veio do redirecionamento ter escrito o arquivo antes, não de construção.

## 6. O que nada disso fecha

(0) Nada: esta branch arquiva medições que já estavam publicadas. (1) **Gate de fase fecha o dono do
repositório** (mandato 4) — nenhum dos números acima encerra P0 ou P1. (2) O **furo #28** continua aberto:
as réguas desta árvore passam verdes exatamente como passavam antes das 33 re-derivações, porque nenhuma
classe delas enxerga ponteiro de prosa cujo alvo continua em faixa. (3) Os logs de rodadas antigas que o
status cita por `.tools/` (o `suite_fix1.log` … `suite_fix4.log`, os `shot_gallery.*`, os
`_head_{agents,readme,status}.md` do pouso da 16) **não** foram arquiveados aqui — ficaram fora do escopo
desta passada e continuam sendo o motivo das 34 linhas `FALTA` da régua de citações. Quem os quiser
versionados precisa reabri-los na máquina, e alguns já não existem.
