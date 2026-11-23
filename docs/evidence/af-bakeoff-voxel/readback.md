# Leitura de retorno — bake-off de voxel com o custo de edição na mesa (dossiê 07, peça c)

Branch `bench/bake-off-voxel-07c`, aberta de `main` em `166af712beced612cd3d8fd7801bbf34b43891f9`. commits
desta ponta: `3cbdd4b` (instrumento de custo de edição em `src/`) e `e486cd3` (runner `tests/af_bakeoff.gd`).
O mundo medido é o da árvore do pin em `src/` — `git rev-parse 166af71:src` =
`64f137bcb1f8e95bd9a64fe7843e4e7b72f7326e`, o hash que o AGENTS.md registra para o pouso da perna 16 — com
o instrumento do `3cbdd4b` por cima. A semente é a da casa: `SEED := 20261116` (`src/main.gd:25`, o mesmo
literal de `tests/smoke_test.gd:10`).

O braço **A** é a árvore landada (referência: um `ArrayMesh` por chunk, face-culling + AO por vértice
`src/world/voxel_world.gd:2-4`, vizinho respondido pela cópia linear global `_flat` reconstruída uma vez por
`generate()` — chamada em `:132`, corpo em `:139-152`, o precedente de ~250 ms/chunk e boot congelado ~16 s
no comentário de `:135-138`, fila de 2 chunks/frame `src/main.gd:28` → `:309-310` consumida em
`src/world/voxel_world.gd:192-200`, geometria só de cubo unitário `:14-21`). O braço **C** é o do dossiê —
"halo vizinho por chunk em vez do `_flat` global" — e **não landou**: vive como patch nesta pasta
(`arm-c-halo-por-chunk.patch`, base `e486cd3`), aplicado e corrido na árvore de trabalho. commit local do
braço, para quem quiser o objeto: branch `bench/bake-off-voxel-07c-arm-c` em `8d9dc97`. Nada de braço C
ficou em `src/` — `grep -n "_halo" src/world/voxel_world.gd` na ponta desta branch não devolve linha.

B e D não têm número aqui por motivo diferente: **B** (greedy) está `[OPEN]` porque A-vs-C acabou de ser
decidido e a seção 5 dá o número que o reabre; **D** (Voxel Tools / GDExtension) segue
`[CLAIMED — medição pendente]`, nada vendorizado.

## 1. O que está nesta pasta

| Arquivo | O que prova |
| --- | --- |
| `run-A-1.log` … `run-A-3.log` | stdout+stderr literais das três corridas do braço A |
| `run-C-1.log` … `run-C-3.log` | as três corridas do braço C, com o patch aplicado na árvore de trabalho |
| `arm-c-halo-por-chunk.patch` | o braço C inteiro (65 linhas `+`, 27 `-`, um arquivo) contra `e486cd3` |
| `suite_instrument.log` | suíte completa com o instrumento landado, antes do runner (`255 checagens 0 falhas 47,6 s`) |
| `suite_final.log` | suíte completa na ponta desta branch (`255 checagens 0 falhas 47,9 s`) |
| `artifacts.sha256` | SHA-256 de cada arquivo acima; confere com `sha256sum -c artifacts.sha256` |

## 2. O comando literal, serial, máquina livre

```sh
W="C:/Aetherfall/.qoder/worktrees/agent-general-purpose-5a650dbb"
G="C:/Aetherfall/.tools/Godot_v4.7.2-stable_win64_console.exe"   # 4.7.2.stable.official.ed1daf0bf
cd "$W" && "$G" --headless --path . --import                     # obrigatório: o worktree não traz .godot/
for i in 1 2 3; do                                               # braço A = a árvore landada
  "$G" --headless --path . --script tests/af_bakeoff.gd -- --arm=A \
       > docs/evidence/af-bakeoff-voxel/run-A-$i.log 2>&1; echo "run-A-$i exit=$?"
done
git apply docs/evidence/af-bakeoff-voxel/arm-c-halo-por-chunk.patch   # braço C, base e486cd3
for i in 1 2 3; do
  "$G" --headless --path . --script tests/af_bakeoff.gd -- --arm=C \
       > docs/evidence/af-bakeoff-voxel/run-C-$i.log 2>&1; echo "run-C-$i exit=$?"
done
git apply -R docs/evidence/af-bakeoff-voxel/arm-c-halo-por-chunk.patch  # C não landa: o patch sai da árvore
```

As seis execuções foram corridas **uma por vez**, cada lote precedido de
`powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name like '%Godot%'\" | Select-Object ProcessId,ExecutablePath"`
confirmado vazio, e nenhum outro processo de medição no meio. O braço vem da CLI e o runner recusa corrida
sem braço nomeado (`braco nomeado na CLI` é a checagem 1): log sem `--arm=` não entra em tabela. Para
reproduzir o braço C a partir desta pasta: `git apply --check` e `git apply` do patch acima na árvore de
`e486cd3`, o comando do `--arm=C`, e `git apply -R` para desazer.

## 3. O runner e o que ele mede

`tests/af_bakeoff.gd` (`extends SceneTree`, `dt` fixo, `process_mode = DISABLED` antes de a sessão entrar na
árvore — o mesmo portão do af-bench, `tests/af_bench.gd:22-28`): boot real (`_ready` gera e malha os 64
chunks, `src/main.gd:129-136`), 20 frames de settling, cava a grade 5×5 ao redor do pé pousado e devolve 5
blocos (30 edições aceitas), com a fila de malharia rodando no `MESH_BUDGET` do produto entre cada edição.
São 11 checagens (`OBSERVACAO` é observação, não gate) e o rodapé é `N checagens M falhas T s`, exit 1 se
`M > 0`.

As duas checagens que sustentam a tabela, e que pegaram defeito de verdade durante a peça:

- `triangles do boot == referencia` — 214.448 no mundo recém-gerado. **Não é o 214.480 publicado**: o número
  do README, do status e do dossiê vem do diagnóstico **final** da suíte, que roda 13 edições e 147 meshes
  antes de imprimir (`suite_final.log:345` traz `"edits":13, "meshes":147, "triangles":214480`; a mesma
  linha em `suite_instrument.log` traz 13/147/214480). Os dois instantes do mesmo mundo differem em 32
  triângulos, e o lote do bake-off devolve 214.484. A tabela usa o instante do boot.
- `corpo do mundo == SHA de referencia` — SHA-256 dos 64 `data` de chunk concatenados, lidos direto do
  storage (`cz` externo, `cx` interno), depois do lote: `619e891c95dc5b44e2ebafabdf069bff…` nos seis logs.
  Nenhuma das duas testemunhas depende do caminho de leitura, então A e C mesharam o mesmo mundo; se o halo
  mentisse, o `triangles` teria caído — e caiu na primeira versão do patch (195.334, erro de passo no
  índice de y do `src`), o que é exatamente o serviço que a checagem faz.

O instrumento do custo de edição (`3cbdd4b`) carimba o chunk em `_mark` quando o `set_block` o suja
(`src/world/voxel_world.gd:294-305`), fecha a conta no fim de `build_chunk_mesh` (`:483-565`) e expõe o
aggregate da sessão por `edit_mesh_cost()` (`:326-336`) → `diagnostics()["edit_mesh"]` (`src/main.gd:1176`):
`count`, `worst_us`, `mean_us` e `pending` (carimbos abertos). Vários `set_block` no mesmo chunk antes do
mesh guardam o **primeiro** carimbo — o que se cobra é a latência até o jogador ver o bloco trocado, não a
média das chamadas. A primeira malharia do boot não entra na conta (chunk sem `mesh_instance`): ela já é o
`mesh_ms`.

## 4. As seis corridas, cada uma com o seu número

| Corrida | exit | `gen_ms` | `mesh_ms` | `triangles` boot | `triangles` lote | custo de edição: count | worst µs | mean µs | `worst_sim_ms` | rodapé wall |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `run-A-1` | 0 | 936,826 | 4.226,752 | 214.448 | 214.484 | 52 | 159.256 | 76.979,8 | 8,950 | 11 checagens 0 falhas 7,948 s |
| `run-A-2` | 0 | 953,634 | 4.369,044 | 214.448 | 214.484 | 52 | 162.843 | 78.642,6 | 8,695 | 11 · 0 · 8,163 s |
| `run-A-3` | 0 | 940,838 | 4.304,575 | 214.448 | 214.484 | 52 | 159.437 | 77.062,1 | 9,353 | 11 · 0 · 8,032 s |
| `run-C-1` | 0 | 874,352 | 5.105,775 | 214.448 | 214.484 | 52 | 214.549 | 93.104,1 | 9,627 | 11 · 0 · 9,327 s |
| `run-C-2` | 0 | 871,043 | 4.938,229 | 214.448 | 214.484 | 52 | 200.101 | 91.503,1 | 10,117 | 11 · 0 · 9,109 s |
| `run-C-3` | 0 | 866,339 | 4.949,574 | 214.448 | 214.484 | 52 | 206.364 | 94.472,4 | 9,146 | 11 · 0 · 9,189 s |

Invariants iguais nos seis logs, por construção e por checagem: `chunks=64`, `meshes=64` no boot,
`edits_aceitas=30`, `remeshes=52`, `fila_inicial=0`, `esper_max_frames=2`, `dropped_ticks=0`, `tick=54`,
`corpo=619e891c95dc5b44…`. Os 52 remeshes são os 30 blocos do lote sujando 52 chunks — quem edita a borda
de um chunk suja também o vizinho (`_touch_chunks_of` `src/world/voxel_world.gd:280-291`), e é o vizinho que
paga a face a mais.

Médias **dentro de cada braço** (nunca entre braços), para a diferença fazer conta:

| Grandeza | A (3 corridas) | C (3 corridas) | Δ C−A |
| --- | --- | --- | --- |
| `gen_ms` | 943,77 | 870,58 | −73,19 ms (−7,75 %) |
| `mesh_ms` | 4.300,12 | 4.997,86 | +697,74 ms (+16,23 %) |
| boot `gen+mesh` | 5.243,89 | 5.868,44 | +624,55 ms (+11,91 %) |
| custo de edição `mean_us` | 77.561,5 | 93.026,5 | +15.465 ms (+19,94 %) |
| custo de edição `worst_us` (pico das 3) | 162.843 | 214.549 | +51,71 ms (+31,75 %) |
| `mesh_ms + 52 · mean` (métrica do §6) | 8.333,32 ms | 9.835,24 ms | +1.501,92 ms (+18,02 %) |

## 5. Decisão, com a régua do dossiê

O critério do §6 é: trocar de mesher só se o braço novo ganhar por **> 10 %** em `mesh_ms` somado ao custo de
edição. Aplicado às seis corridas, a soma `mesh_ms + 52 · mean_us` por corrida dá:

```
A: 8.229,702 · 8.458,459 · 8.311,804 ms
C: 9.947,188 · 9.696,390 · 9.862,139 ms
```

**As duas distribuições não se tocam**: o pior A (`run-A-2`, 8.458,5 ms) fica 14,63 % abaixo do melhor C
(`run-C-2`, 9.696,4 ms). C perde a régua em vez de ganhá-la, e perde também em cada coluna isolada que
importa para o jogador (`mesh_ms` +16,23 %, custo de edição +19,94 % em média, pico +31,75 %). Onde C ganha:

- `gen_ms` −7,75 % — a alocação de `128×64×128` bytes (1.048.576) e a varredura do mundo inteiro por
  `generate()` desaparecem, substituídas por um casaco de `18×66×18` = **21.384 bytes** reutilizado por
  chunk (1/49 das bytes). É o ganho de *memória e de escalabilidade do mundo*, não de tempo.
- e ele cobra um terceiro preço que a tabela do dossiê não tinha pedido e o log trouxe: `worst_sim_ms` sobe
  de 9,00 ms (média A) para 9,63 ms (média C, +7,0 %), porque sem o `_flat` toda consulta de vizinhança
  fora da malharia — DDA do raycast, AABB do corpo, sondas do áudio — volta a pagar o dicionário de chunks
  (`get_block_xyz` `src/world/voxel_world.gd:240-253`), que é justamente o custo que o comentário de
  `:135-138` registra.

**Decisão: o braço A continua sendo o default. Nenhum braço landou em `src/` como malharia nova.** O patch C
fica versionado aqui com o número da derrota, e a razão de ele existir mesmo perdendo é a coluna de bytes: se
o mundo crescer além de `128×64×128` (streaming por região), a cópia global deixa de ser opção e o custo de
C passa a ser o preço de entrada — re-derivar esta decisão nessa hora, com a variação "halo só da borda"
(4.488 bytes por chunk, copiar só as 68 colunas do anel em vez das 324) ainda **não medida**.

**O número que reabre o braço B (greedy meshing)**, hoje `[OPEN]`: pela régua do §6, B só entra na mesa se
`mesh_ms + 52 · mean_us` cair a ≤ **7.500,0 ms** em três corridas (0,9 × 8.333,3 ms de A), o que exige
`mesh_ms` ≤ 3.870,1 ms com o custo de edição no lugar. Duas coisas mudam de natureza quando B chegar, e o
runner precisa ser re-derivado junto: `triangles` deixa de ser invariante (greedy emite menos triângulos *por
construção*, e o `REF_TRIANGLES := 214448` de `tests/af_bakeoff.gd:41` vira literal novo, não defeito), e só
o `REF_BODY_SHA` continua sendo a testemunha dura de que o mundo é o mesmo. Nenhum FPS foi prometido em
nenhuma linha desta pasta.

## 6. O que não segurou

- **O `triangles` publicado não é o do boot.** README `## Limites conhecidos`, status e o §4 do dossiê dizem
  214.480 ao lado de "~0,9 s de geração + ~4,3 s de malharia dos 64 chunks"; o boot do mundo recém-gerado dá
  214.448. Os 32 triângulos de diferença são as 13 edições que a suíte faz antes de imprimir o diagnóstico
  final. Não é contradição entre medidas, é dois instantes diferentes chamados pelo mesmo nome.
- **A "altura certa" do boot que o status fixava (942 ms / 4.682 ms) continua sem corrida publicada que a
  sustente**, e a mesa de hoje dá outra faixa: `gen_ms` 936,8–953,6 e `mesh_ms` 4.226,8–4.369,0 no braço A.
  O §4 do dossiê (`mesh_ms` 4.677,9 ms) é o log local `.tools/af-clean-suite2.log:12` do plano, árvore
  anterior às pernas 16 e 19 — não é o que a árvore do pin devolve.
- **O briefing deste registro afirmou que `src/` e `tests/` estavam byte-idênticos ao pin `9b2c65a`.** Em
  `src/` confere (`64f137bcb1f8e95bd9a64fe7843e4e7b72f7326e`); em `tests/` não: `166af71:tests` =
  `8fbffd907e708c03cb1c5bb89518c6a7a619c5ec` contra `88a1541c2f9f6fc3dd0e1d237b3e5656d9eea3c9` do pin, e a
  diferença é `tests/af_bench.gd` (+344) e seu `.uid` (+1), que entraram com o merge do 07b. Nada que a
  suíte executa mudou, mas a frase do briefing estava errada e o contrato de identidade de `tests/` com o
  pin não existe.
- `apply_edits()` (`src/world/voxel_world.gd:178-189`) suja chunks pelo mesmo `_mark` do `set_block`, mas
  durante o boot/carregamento os chunks ainda não têm malha, então o custo do lote de edições vindas do disco
  entra em `mesh_ms`, não em `edit_mesh`. É o desenho do instrumento, não um buraco: `pending` existe para
  dizer quantos carimbos ficaram abertos (0 nos seis logs).
- `count` do aggregate é por **chunk remalhado**, não por bloco editado: 30 edições → 52 chunks. Os dois
  números aparecem no log (`edits_aceitas`, `edit_cost count`) e a checagem
  `custo de edicao == chunks remalhados` é justamente a igualdade `count == remeshes - fila_inicial`.
- A contagem da suíte não se moveu: **255 checagens** com e sem o instrumento, porque a peça não acrescentou
  checagem em `tests/smoke_test.gd` — o contrato de 255 está citado no AGENTS.md (linhas 122, 511, 513 e 548
  da regra atual de medição) que não é meu para editar nesta rodada. O instrumento aparece no diagnóstico
  final da própria suíte (`"edit_mesh":{"count":14,"mean_us":123838.0,"pending":0,"worst_us":226908}` em
  `suite_final.log:345`), que é o caminho real do jogador: 13 edições da suíte remalharam 14 chunks, pior
  espera 226,9 ms.
- Os `.uid` de `tests/audio_test.gd` e `tests/audio_live_probe.gd` continuam fora do commit (furo #25, decisão
  do dono do registro); `tests/af_bakeoff.gd.uid` (`uid://d4etqe78vbj3`) entrou com o runner.

## 7. Estado das portas do dossiê

| Peça | Estado |
| --- | --- |
| doc `docs/engine/simclock.md` | landado pelo 07a (`779d19b`, re-derivado sobre o `src/` da perna 16) |
| `af-bench boot_walk_10min` | landado pelo 07b, 3 × 12.000 ticks re-mediados na árvore do pin (`docs/evidence/af-bench-boot-walk/`) |
| bake-off A vs C | **medido e decidido nesta pasta** — A fica, C não passa da régua, patch versionado |
| bake-off B (greedy) | `[OPEN]` — reabre com ≤ 7.500,0 ms na métrica do §6 (seção 5) |
| bake-off D (GDExtension) | `[CLAIMED — medição pendente]` — nada vendorizado |
| "custo de edição local" sem clock | **fechado**: instrumento em `src/world/voxel_world.gd:294-336`, coluna `edit_mesh` no `diagnostics()` (`src/main.gd:1176`), lido de volta pelo runner e pela suíte |
