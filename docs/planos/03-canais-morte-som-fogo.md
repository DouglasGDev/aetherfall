# 03 — Canais MORTE / SOM / FOGO no `AetherField`

Plano do item 4 de "Falta" (`docs/melhorias-status.md:542-550`). Nenhum número aqui é de
corrida nova: eu não rodei engine nem suíte. Onde não há log, diz "não medido".

**Estado em 2026-11-19 (mudado por execução, não por leitura):** o **passo 1 do §7** — a colheita
sem canal novo — foi rodado, medido e publicado em `9f3622b`; §5, §7, §8 e a nota de contagem do §9
foram atualizados com os números daquele clone. Nada do §2 em diante (canais MORTE/SOM/FOGO) saiu,
e `Channel.COUNT` continua 3. A nota de medição está em
`docs/melhorias-status.md:1899-1979`.

## 1. Premissa nomeada

**Um canal só existe se, na mesma revisão, houver uma chamada de `imprint` que o escreva e uma
curva que o leia.** Hoje as três fontes que o status prevê (morte de mob, tiro/passo,
lava/fogueira) não imprimem canal nenhum de morte/som/fogo, e a meia-vida por canal está viva —
logo o trabalho é ligar fonte a consumidora, não acrescentar linhas em tabelas.

## 2. Estado real do código

| Peça | O que é hoje | Onde |
| --- | --- | --- |
| enum | `Channel { WORK=0, BLOOD=1, FEAR=2, COUNT=3 }` | `src/world/aether_field.gd:9` |
| nomes | `CHANNEL_NAMES` com 3 entradas | `aether_field.gd:11` |
| decaimento | `HALF_LIFE = [90.0, 55.0, 120.0]`, **lido** em `keep = pow(0.5, elapsed / HALF_LIFE[ch])` | `aether_field.gd:13`, uso em `:120` |
| fluxo | `DIFFUSE_RATE = [0.06, 0.16, 0.10]`; corte `MIN_VALUE 0,004` (`:16`), teto `MAX_VALUE 4,0` (`:17`) | `aether_field.gd:15` |
| cor | `CHANNEL_COLOR` com 3 entradas | `src/rendering/aether_viz.gd:12-16` |
| geometria | `_per_channel = size_x*size_y*size_z` (`:48`), dimensões de `:45-47`; `state_bytes()` confirma 196.608 B nos 3 canais | `aether_field.gd:45-54`, medida em `docs/melhorias-status.md:1711` |
| porta de escrita | `imprint(world_pos, ch, amount)` — posição primeiro, canal segundo | `aether_field.gd:87-89` |
| fontes reais | medo no spawn `main.gd:295`; lavra 0,42 / colocação 0,20 `main.gd:477-479`; sangue 0,22 `main.gd:388`; morte do jogador `main.gd:544-545`; lobo ferido `wolf.gd:1291-1292`; lobo morto `wolf.gd:1310-1311`; medo do lobo `wolf.gd:490`, sangue `wolf.gd:772` | as fontes dos 3 canais novos: **zero ocorrências** |
| passada | `diffuse_and_decay(AETHER_PERIOD)` com `AETHER_PERIOD = 0.25` → 4 passadas/s | `aether_field.gd:117-156`, chamada `src/main.gd:316`, constante `src/main.gd:27` |
| alocação | `var hot := PackedInt32Array()` **por canal por passada** (3/s de lógica → 12/s); o scratch `_nb_i`/`_nb_w` é reusado (`:38-39`, `:162-163`) | `aether_field.gd:122` |
| rastreamento | `_find_scent()`: 7×7 = 49 células × 3 `sample_cell` = **147 leituras na camada própria**; se nenhuma passa de `0,06` ali, o mesmo 7×7 se repete em ±1 camada com 2 canais — **98 por camada vizinha aberta**, 196 se as duas abrem. Peso `blood + work*0,35`, camada Y vem de `cell_of_world(center())`; memória 32 células / 30 s / renovação 0,06 | `src/entities/wolf.gd:960-1000` (gate do escalonamento `:974-975`, loops `:976-977`, célula `:978`, peso `:980-981`, canal `:992`, `cell_of_world` `:965`), constantes `wolf.gd:27-34`; custo medido em `docs/evidence/rastro-duas-camadas/readback.log` |
| consumidoras | `flee`: `_fear_level` peso 1,7; `investigate`: `_scent_strength` 1,6, `1-_fear_level` 0,8 e o veto `ha rastro`; `_fear_level = fear*0,85 + threat*0,9 + blood*0,35 + panic*0,55` (`PACK_PANIC_FEAR` `:53`); amostras locais por tick `wolf.gd:923-925` | `wolf.gd:802-858`, o `_fear_level` composto em `:940-941`; mecanismo e normalização por `weight_sum` em `src/ai/utility_scorer.gd:73-75`; `min_lead` default 0,06 em `:41` e **sobrescrito para 0,05** por `wolf.gd:803` |
| som | `AudioDirector` é leitor por contrato ("nao toca no Eter", `:3-5`); constantes `:11-44`; pool `:310-325` (`:314` é `max_distance`); posição de playback real em `_voice_index()` `:334+` | `src/audio/audio_director.gd` |

**Meia-vida: a afirmação de quem veio antes está errada.** `diffuse_and_decay` lê `HALF_LIFE` a
cada canal (`aether_field.gd:120`) e `elapsed` é 0,25 s (`main.gd:21`, `:210`), então o fator por
passada é 0,9980764 (WORK, perda 0,192%), 0,9968542 (BLOOD, 0,315%) e 0,9985570 (FEAR, 0,144%) —
três valores distintos, razão 2,18× entre sangue e medo. O "11,33% por passada, 4,8 s efetivos,
igual para os três" não sai dessa aritmética (11,33% exigiria elapsed/HL = 0,1736, ou seja, ~20,8
s de lógica numa passada). Não há "outro mecanismo que zera o campo": `:128-129` é `if rate <= 0.0:
continue` e o único zeramento é o corte espacial de `MIN_VALUE` em `:149-152`, com a quantia
colhida em `pass_cut[ch]` (`:153`). Isto era `[MEASURED]` **de leitura de código**, com o resto sem
corrida: a checagem `meia-vida reduziu a energia` só afirma `e2 < e1` (`tests/smoke_test.gd:1695`) e
o log da rodada do `a8967e0` mostrava 2.500 → 2.296
(`docs/evidence/third-person-carry/clone-suite.log:68`), 8,16% de perda onde `HALF_LIFE[FEAR]` prevê
1,15% em 8 passadas (0,9985570^8 = 0,98850 → 2,471). **A metade não medida saiu em `9f3622b`:** os
0,175 de diferença são `0,176129` de corte, colhidos na cadeia de `tests/smoke_test.gd:1667-1680` e
impressos por `:692-702`. O parágrafo acima deixa de ser débito e passa a ser §8.

## 3. Por canal novo

**MORTE.** Fonte: os caminhos de morte já existem e já imprimem sangue+medo
(`wolf.gd:1310-1311`, `main.gd:544-545`); o canal MORTE seria um quarto registro no mesmo ponto,
com `amount` e meia-vida próprios. Leitor: `investigate` (carcaça vale mais que rastro) e uma
nova consideração em `flee`. Curva que muda: `sniff` hoje soma 3,3 de peso e `flee` 5,3
(`wolf.gd:802-858`); como a pontuação é normalizada por `weight_sum` (`utility_scorer.gd:75`),
toda consideração nova **reescala as opções existentes** — com `min_lead` 0,05 (o valor que o lobo
põe no scorer, `wolf.gd:803`, não o default 0,06 da classe), isso decide
intenção sem que ninguém queira. Custo: +16.384 células (65.536 B em `_cur` + 65.536 B em `_nxt`),
+1 `PackedInt32Array` por passada, +49 leituras por scan de lobo e +1 leitura por `sim_step`
(100 reads/s para 5 lobos).
**SOM.** Fonte legítima é o evento de mundo (lavra `main.gd:352`, colocação `:457`, dano
`wolf.gd:1291-1292`, morte `:1310-1311`), **nunca** o `AudioDirector`: imprimir do diretor acoplaria áudio ao
hash por tick, e a invariância do hash com som ligado é medida (`audio_director.gd:3-5`). Passo do
jogador como evento de mundo: não verifiquei `player.gd` aqui. Leitor: `investigate` (virar o
cabeçalho atrás do barulho) e o veto de `hunt`. Não existe "tiro" no slice: sem arma de fogo, a
fonte de som mais alta hoje é lavra.
**FOGO.** Nenhuma fonte no código: `block_defs.gd:37` tem `COUNT = 23` e a lista de tiles
(`:40-53`) não tem fogo/lava; grep de `lava|burn|flame|torch|campfire|fogueira` em `src/**/*.gd`
devolve apenas comentários (`recipes.gd:41` fala de lava como doc futuro). **Não entra agora**:
sem fonte, seria a tabela do §1 violada. Fica `[TARGET]` até existir bloco ou entidade que queime.

## 4. Custo — as quatro perguntas

Roda **por passada de 0,25 s** (difusão, `main.gd:229`) e **por evento** (imprint), não por frame;
a leitura é **por tick de simulação** por lobo vivo (`wolf.gd:907`, corpo em `:916-925`) e **a cada 0,25 s** no scan
(`wolf.gd:927-928`). Entidades alcançadas: 5 lobos (`main.gd:9`), 1 jogador, 16.384 células por canal
— com 6 canais o laço de `src/world/aether_field.gd:123` e o de zeramento `:149` dobram (49.152 → 98.304 iterações por
passada, 4 passadas/s): contagem derivada do código, **tempo não medido**. Aloca no caminho
quente: sim, `aether_field.gd:122` passa de 3 para 6 arrays por passada, e `active_cells()`
(`aether_field.gd:187-198`, chamado pela visualização a cada `VIZ_PERIOD 0,25` — `main.gd:23`,
`aether_viz.gd:54`) devolve um Array proporcional a `COUNT × _per_channel`. Consequência de
persistência: `state_bytes()` (`:233-234`) dobra com 6 canais e o journal grava `Channel.COUNT`
(`src/persistence/tick_journal.gd:38`), então **o hash por tick muda de domínio** — `FORMAT_VERSION`
precisa subir junto, senão `[tick,hash]` velhos e novos comparam coisas diferentes. Como sei que
ficou melhor: ainda não sei — não existe log de custo por canal; o primeiro commit é colheita.

## 5. Gate de fechamento (headless)

Contagem hoje: **236 checagens / 0 falhas / 37,1 s** no clone limpo de `9f3622b`
(`docs/evidence/ether-massa-conservada/clone-suite.log:311`; as quatro ocorrências antigas de 232
em `melhorias-status.md` (91, 249, 665 e 702 na numeração da época) são da rodada do `a8967e0` e continuam
certas porque mediram o clone daquele commit). O runner dedicado é `godot --headless --path . --script
tests/aether_reactions_test.gd`, hoje **109 checagens** (`EXPECTED_CHECKS`,
`tests/aether_reactions_test.gd:20`, 21 cenários `:7-15`), medida no clone limpo de `ff347d2`:
**109 / 0 falhas / 2,003 s**, exit 0 (`docs/evidence/rastro-duas-camadas/clone-ff347d2-runner.log`).

1. `godot --headless --path . tests/smoke_test.tscn` → última linha **exatamente** o censo da
   revisão acrescido das checagens novas, exit 0. As três checagens previstas, como ficaram:
   (a) coerência de contagem: `Channel.COUNT == CHANNEL_NAMES.size() == HALF_LIFE.size() ==
   DIFFUSE_RATE.size() == CHANNEL_COLOR.size()` — falha na hora se alguém adicionar enumeração
   sem preencher as tabelas; **não entrou**, porque não há canal novo nesta revisão e o passo 1
   era colheita;
   (b) meia-vida por canal: com um imprint isolado, **uma** passada de `diffuse_and_decay(0.25)`
   deve devolver `keep` dentro de ±0,0002 do previsto (`0,9980764 / 0,9968542 / 0,9985570`) e os
   três `keep` distintos — hoje nada no repositório distingue sangue de medo; **entrou em parte**:
   os três `keep` por canal agora são calculados (`smoke_test.gd:1058-1060`) e comparados nas 8
   passadas (`:674-687`) com tolerância de `1e-4` sobre a massa, não ±0,0002 sobre o fator — o
   cenário de imprint isolado com uma única passada, esse não foi rodado;
   (c) conservação de massa: `channel_totals()` após 8 passadas ≥ 0,985 × imprint — **esta
   fórmula estava errada e é o achado do passo 1**: o teto de 0,985 só vale se o decaimento for a
   única saída de massa, e não é. Medido, 8 passadas devolvem 0,9184 do imprint (2,296/2,500) e a
   diferença é o corte de `MIN_VALUE`, hoje colhido em `pass_cut`. O que entrou no lugar é a cadeia
   `nenhuma passada cria massa` / `saldo fecha com o corte de MIN_VALUE` /
   `o corte da fronteira explica a perda alem da meia-vida` (`smoke_test.gd:1091-1101`), mais
   `teto nao injeta o excedente no campo` (`:709-712`) — quatro checagens, não três.
   A existente `ledger com 3 canais` (`smoke_test.gd:1111`) tem o `3` literal e precisa passar a
   ler `Channel.COUNT`.
2. Runner dedicado: 109 → o número dos cenários acrescentados, exit 0, com um cenário por canal
   novo que nomeia a premissa (imprint → leitura → mudança de intenção) e imprime o `keep` e o
   `_sim_worst_us` e o `_bt_worst_us` já colhidos (`aether_reactions_test.gd:319-321`, impressos em `:3058`).
3. Sonda curta apenas enquanto se edita: `godot --headless --path . --check-only --script
   src/world/aether_field.gd` (não substitui os dois acima).
Gate de fase quem fecha é o dono; este item não fecha P1.

## 6. O que NÃO fazer

Nenhum `HotSet`, Véu, `SlowSim`, `MindsInspector`, `MindStore`, replay, fita de comandos,
`af-bench`, `docs/engine/simclock.md`, facções, LOD por distância ou arma de fogo: nada disso
existe. Nada de tocar a difusão para "acomodar" canais novos, nada de mudar os pesos existentes
das curvas na mesma mudança do imprint, nada de ler o canal no `AudioDirector`.

## 7. Commits atômicos

1. Colheita: checagens (a), (b), (c) **sem canal novo** — **feito em `9f3622b`**, e o resultado de
   (c) foi o número pedido: não há vazamento, há uma segunda saída de massa que ninguém colhia
   (`pass_cut`), medida em `0,176129`. O censo foi de 232 a **236**, não a 235 — quatro checagens,
   não três (ver §5). 2. `FORMAT_VERSION`/dimensão do journal conferidos com a
   contagem de canais parametrizada. 3. Canal MORTE: enum + 5 estruturas + imprint nas duas
   mortes + uma curva + cenário dedicado. 4. Canal SOM: imprint nos eventos de mundo (lavra,
   dano, morte) + uma curva + cenário. 5. FOGO: só abre quando existir fonte; enquanto não
   existir, é linha de backlog. Suíte verde entre cada um; o número do item 5 e 6 volta a ser
   hipótese se o código mudar depois da medição — re-medir em clone limpo do SHA final com
   `godot --headless --path . --import` e pinar o SHA na linha publicada.

## 8. Citações que não conferem no repositório

- `docs/melhorias-status.md:542-543`: "três tabelas paralelas de `aether_field.gd:11-15`" e "uma
  cor em `aether_viz.gd:12-16"`. No arquivo há duas tabelas (`:13`, `:15`), mais `CHANNEL_NAMES`
  (`:11`) e o `enum Channel` (`:9`); a cor é a quinta superfície com largura e a sexta é
  `Channel.COUNT` dentro da projeção do journal (`src/persistence/tick_journal.gd:38`) — abrir
  canal muda todo hash publicado.
- `:276` lista "tiro/passo" e "lava/fogueira" como fontes. Não há projétil nem fogo: `Block`
  (`src/world/block_defs.gd:10-23`) tem 13 entradas, `COUNT = 23` (`:37`) e nenhum tile de fogo
  (`:40-53`); grep de `lava|burn|flame|fogueira` em `src/` devolve só comentários e o verbo lavar
  (`recipes.gd:41`, `main.gd:558`, `voxel_atlas.gd:174`). "Passo" existe apenas como leitor de
  corpo no diretor (`audio_director.gd:435-457`), que o contrato proíbe de escrever.
- `:277` ("leitura nas curvas de utilidade") não diz que a leitura é hoje fixa nos três canais
  (`wolf.gd:923-925`) nem que a escolha de canal do rastro descarta o medo (`wolf.gd:983`).
- `docs/design/08-roadmap-risks-licensing.md:29` publica "AetherField de **3** canais" e `:68`
  promete 6 no gate de P1 — as duas frases envelhecem juntas no dia em que `COUNT` mudar, e
  nenhuma delas é o gate (`:72-74`).
- `AGENTS.md` publica 196 608 B/tick e 3 canais: os dois valores caem com o commit 2.
- ~~O log publicado não fecha conta com `HALF_LIFE`~~ — **fechado por medição em `9f3622b`**:
  `docs/evidence/third-person-carry/clone-suite.log:68` mostrava 2.500 → 2.296 (8,16%) em 8 passadas
  de `diffuse_and_decay(0.25)` — hoje o laço está em `tests/smoke_test.gd:1667-1680` e o par
  `2.500 -> 2.296` é impresso por `:690-691` — onde `HALF_LIFE[FEAR] = 120` prevê
  0,9985570^8 = 0,98850 → 2,471. Os 0,175 que faltavam
  são, medidos, **`0,176129` de corte de `MIN_VALUE`** (`aether_field.gd:146-153`, colhidos em
  `pass_cut` `:36`), e a cadeia `m·keep^8 − Σ cut_k·keep^(7−k)` fecha com erro máximo de
  `4,6e-7` (`docs/evidence/ether-massa-conservada/clone-suite.log:70-71`). O débito de número sem
  dono não existe mais; o que sobra deste item é o §2 (canais novos).

## 9. O que chegou a este plano por briefing e não existe no repositório

Nada abaixo aparece em `docs/`, `src/` ou `tests/` — conferido por grep nesta máquina. São
afirmações que vieram do prompt que produziu este dossiê; o código as refuta e o registro fica
aqui porque a regra 1 do contrato não permite herdar número sem fonte.

- Meia-vida "morta", "11,33% por passada", "4,8 s efetivos", "igual para os três": `HALF_LIFE` é
  lido por canal em `aether_field.gd:120` e os três `keep` são distintos (0,9980764 / 0,9968542 /
  0,9985570 com `elapsed = 0,25`).
- `TrailReader`, `_sample_trail`, `_sighting_cache_cap`, `_sighting_cache_ttl`, `_scan_interval`:
  nenhum nome existe. O scanner é `_find_scent()` (`wolf.gd:960-1000`) com `SCENT_PERIOD 0,25`
  (`:30`), `SCENT_MEMORY_SECONDS 30,0` (`:32`), `SCENT_MEMORY_CAP 32` (`:33`) e `SCENT_RENEWAL
  0,06` (`:34`); "TTL de 3000 ms" erra nome, unidade e linha.
- `DECAY_PER_SEC`, `SOURCE_RATE`, `SATURATION` e os "três dicionários paralelos em
  `tests/aether_reactions_test.gd:84-100`" — assemblado do prompt que produziu este dossiê, e é
  assim que ele fica registrado, com o número que o prompt escreveu: nenhum dos três nomes e
  nenhum dos três dicionários ocorre em `src/` ou `tests/`. Na árvore de hoje `:222` é `_check` e
  `:229` é `_test_fixture`.
- `imprint(channel, cell, amount)` em `aether_field.gd:50-60`: a assinatura real é
  `imprint(world_pos, ch, amount)` (`:87-89`); `:42-54` é o `setup()`.
- Pesos WORK/BLOOD/FEAR em `src/ai/utility_scorer.gd:11-27` e `:46-61`: o arquivo é mecanismo
  (`Consideration` `:6-17`, `scored` `:54-79`, normalização por `weight_sum` `:75`, `min_lead
  0,06` `:41`) e não cita canal nenhum; as considerações com peso estão em `wolf.gd:802-858`.
- `audio_director.gd:314` como leitura de posição de playback: `:314` é
  `v.max_distance = MAX_DISTANCE`; a posição real vem de `_voice_index()` (`:334+`).
- "a contagem de checagens mora nas linhas 14 a 17 do cabeçalho do status": não morava — as quatro
  ocorrências de 232 estavam nas linhas 91, 249, 665 e 702 daquela numeração, todas da rodada do
  `a8967e0`. Hoje o número da ponta publicada está na linha 26 do cabeçalho do status, e cada
  rodada tem a sua nota a partir de "Notas de medição", linha 910; as quatro antigas continuam.
