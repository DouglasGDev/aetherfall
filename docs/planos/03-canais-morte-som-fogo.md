# 03 — Canais MORTE / SOM / FOGO no `AetherField`

Plano do item 4 de "Falta" (`docs/melhorias-status.md:274-278`). Nenhum número aqui é de
corrida nova: eu não rodei engine nem suíte. Onde não há log, diz "não medido".

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
| decaimento | `HALF_LIFE = [90.0, 55.0, 120.0]`, **lido** em `keep = pow(0.5, elapsed / HALF_LIFE[ch])` | `aether_field.gd:13`, uso em `:111` |
| fluxo | `DIFFUSE_RATE = [0.06, 0.16, 0.10]`; corte `MIN_VALUE 0,004` (`:16`), teto `MAX_VALUE 4,0` (`:17`) | `aether_field.gd:15` |
| cor | `CHANNEL_COLOR` com 3 entradas | `src/rendering/aether_viz.gd:12-16` |
| geometria | `_per_channel = size_x*size_y*size_z` (`:44`), dimensões de `:41-43`; `state_bytes()` confirma 196.608 B nos 3 canais | `aether_field.gd:41-48`, medida em `docs/melhorias-status.md:1015` |
| porta de escrita | `imprint(world_pos, ch, amount)` — posição primeiro, canal segundo | `aether_field.gd:81-83` |
| fontes reais | medo no spawn `main.gd:192`; lavra 0,42 / colocação 0,20 `main.gd:271-273`; sangue 0,22 `main.gd:307`; morte do jogador `main.gd:312-313`; lobo ferido `wolf.gd:587-588`; lobo morto `wolf.gd:606-607`; medo do lobo `wolf.gd:222`, sangue `wolf.gd:344` | as fontes dos 3 canais novos: **zero ocorrências** |
| passada | `diffuse_and_decay(AETHER_PERIOD)` com `AETHER_PERIOD = 0.25` → 4 passadas/s | `aether_field.gd:108-141`, chamada `src/main.gd:150`, constante `src/main.gd:12` |
| alocação | `var hot := PackedInt32Array()` **por canal por passada** (3/s de lógica → 12/s); o scratch `_nb_i`/`_nb_w` é reusado (`:34-35`, `:147-148`) | `aether_field.gd:113` |
| rastreamento | `_find_scent()`: 7×7 = 49 células × 3 `sample_cell` = 147 leituras por lobo, peso `blood + work*0,35`, camada Y vem de `cell_of_world(center())`; memória 32 células / 30 s / renovação 0,06 | `src/entities/wolf.gd:461-496` (loops `:472-473`, peso `:476`, `:481`, célula `:467`, canal `:487`), constantes `wolf.gd:27-33` |
| consumidoras | `flee`: `_fear_level` peso 1,7 e `1-_fear_level` 0,8; `investigate`: `_scent_strength` 1,6 + veto `ha rastro`; `_fear_level = fear*0,85 + threat*0,9 + blood*0,35`; amostras por tick `:442-444` | `wolf.gd:356-398`, `wolf.gd:447`; mecanismo e normalização por `weight_sum` em `src/ai/utility_scorer.gd:73-75`, histerese `min_lead 0,06` em `:41` |
| som | `AudioDirector` é leitor por contrato ("nao toca no Eter", `:3-5`); constantes `:11-44`; pool `:310-325` (`:314` é `max_distance`); posição de playback real em `_voice_index()` `:334+` | `src/audio/audio_director.gd` |

**Meia-vida: a afirmação de quem veio antes está errada.** `diffuse_and_decay` lê `HALF_LIFE` a
cada canal (`aether_field.gd:111`) e `elapsed` é 0,25 s (`main.gd:12`, `:150`), então o fator por
passada é 0,9980764 (WORK, perda 0,192%), 0,9968542 (BLOOD, 0,315%) e 0,9985570 (FEAR, 0,144%) —
três valores distintos, razão 2,18× entre sangue e medo. O "11,33% por passada, 4,8 s efetivos,
igual para os três" não sai dessa aritmética (11,33% exigiria elapsed/HL = 0,1736, ou seja, ~20,8
s de lógica numa passada). Não há "outro mecanismo que zera o campo": `:119-120` é `if rate <= 0.0:
continue` e o único zeramento é o corte espacial de `MIN_VALUE` em `:136-138`. Marca-se
`[MEASURED]` **de leitura de código**; nenhuma corrida trava isso hoje — a checagem
`meia-vida reduziu a energia` só afirma `e2 < e1` (`tests/smoke_test.gd:660`) e o log publicado
mostra 2.500 → 2.296 (`docs/evidence/third-person-carry/clone-suite.log:68`), 8,16% de perda onde
`HALF_LIFE[FEAR]` prevê 1,15% em 8 passadas (0,9985570^8 = 0,98850 → 2,471). A causa dos 0,175 de
diferença **não foi medida** e não explico aqui.

## 3. Por canal novo

**MORTE.** Fonte: os caminhos de morte já existem e já imprimem sangue+medo
(`wolf.gd:606-607`, `main.gd:312-313`); o canal MORTE seria um quarto registro no mesmo ponto,
com `amount` e meia-vida próprios. Leitor: `investigate` (carcaça vale mais que rastro) e uma
nova consideração em `flee`. Curva que muda: `sniff` hoje soma 3,3 de peso e `flee` 5,3
(`wolf.gd:356-398`); como a pontuação é normalizada por `weight_sum` (`utility_scorer.gd:75`),
toda consideração nova **reescala as opções existentes** — com `min_lead` 0,06, isso decide
intenção sem que ninguém queira. Custo: +16.384 células (65.536 B em `_cur` + 65.536 B em `_nxt`),
+1 `PackedInt32Array` por passada, +49 leituras por scan de lobo e +1 leitura por `sim_step`
(100 reads/s para 5 lobos).
**SOM.** Fonte legítima é o evento de mundo (lavra `main.gd:271`, colocação `:273`, dano
`wolf.gd:587`, morte `:606`), **nunca** o `AudioDirector`: imprimir do diretor acoplaria áudio ao
hash por tick, e a invariância do hash com som ligado é medida (`audio_director.gd:3-5`). Passo do
jogador como evento de mundo: não verifiquei `player.gd` aqui. Leitor: `investigate` (virar o
cabeçalho atrás do barulho) e o veto de `hunt`. Não existe "tiro" no slice: sem arma de fogo, a
fonte de som mais alta hoje é lavra.
**FOGO.** Nenhuma fonte no código: `block_defs.gd:37` tem `COUNT = 23` e a lista de tiles
(`:40-53`) não tem fogo/lava; grep de `lava|burn|flame|torch|campfire|fogueira` em `src/**/*.gd`
devolve apenas comentários (`recipes.gd:41` fala de lava como doc futuro). **Não entra agora**:
sem fonte, seria a tabela do §1 violada. Fica `[TARGET]` até existir bloco ou entidade que queime.

## 4. Custo — as quatro perguntas

Roda **por passada de 0,25 s** (difusão, `main.gd:150`) e **por evento** (imprint), não por frame;
a leitura é **por tick de simulação** por lobo vivo (`wolf.gd:442-444`) e **a cada 0,25 s** no scan
(`wolf.gd:463`). Entidades alcançadas: 5 lobos (`main.gd:9`), 1 jogador, 16.384 células por canal
— com 6 canais o laço de `:114` e o de zeramento `:136` dobram (49.152 → 98.304 iterações por
passada, 4 passadas/s): contagem derivada do código, **tempo não medido**. Aloca no caminho
quente: sim, `aether_field.gd:113` passa de 3 para 6 arrays por passada, e `active_cells()`
(`:172-183`, chamado pela visualização a cada `VIZ_PERIOD 0,25` — `main.gd:14`,
`aether_viz.gd:54`) devolve um Array proporcional a `COUNT × _per_channel`. Consequência de
persistência: `state_bytes()` (`:218-219`) dobra com 6 canais e o journal grava `Channel.COUNT`
(`src/persistence/tick_journal.gd:38`), então **o hash por tick muda de domínio** — `FORMAT_VERSION`
precisa subir junto, senão `[tick,hash]` velhos e novos comparam coisas diferentes. Como sei que
ficou melhor: ainda não sei — não existe log de custo por canal; o primeiro commit é colheita.

## 5. Gate de fechamento (headless)

Contagem hoje: **232 checagens / 0 falhas / 33,7 s** (`clone-suite.log:307`, mesmo número em
`melhorias-status.md:249` e `:654`). O runner dedicado é `godot --headless --path . --script
tests/aether_reactions_test.gd`, hoje **89 checagens** (`EXPECTED_CHECKS`,
`tests/aether_reactions_test.gd:15`, 17 cenários `:7-14`).

1. `godot --headless --path . tests/smoke_test.tscn` → última linha **exatamente** "235 checagens
   0 falhas", exit 0. As três checagens novas, todas capazes de falhar:
   (a) coerência de contagem: `Channel.COUNT == CHANNEL_NAMES.size() == HALF_LIFE.size() ==
   DIFFUSE_RATE.size() == CHANNEL_COLOR.size()` — falha na hora se alguém adicionar enumeração
   sem preencher as tabelas;
   (b) meia-vida por canal: com um imprint isolado, **uma** passada de `diffuse_and_decay(0.25)`
   deve devolver `keep` dentro de ±0,0002 do previsto (`0,9980764 / 0,9968542 / 0,9985570`) e os
   três `keep` distintos — hoje nada no repositório distingue sangue de medo;
   (c) conservação de massa: `channel_totals()` após 8 passadas ≥ 0,985 × imprint, o que **falha
   hoje** se a perda de 8,16% do log for real, e é exatamente o número que falta medir.
   A existente `ledger com 3 canais` (`smoke_test.gd:666`) tem o `3` literal e precisa passar a
   ler `Channel.COUNT`.
2. Runner dedicado: 89 → o número dos cenários acrescentados, exit 0, com um cenário por canal
   novo que nomeia a premissa (imprint → leitura → mudança de intenção) e imprime o `keep` e o
   o `_sim_worst_us` e o `_bt_worst_us` já colhidos (`aether_reactions_test.gd:112-114`, impressos em `:645`).
3. Sonda curta apenas enquanto se edita: `godot --headless --path . --check-only --script
   src/world/aether_field.gd` (não substitui os dois acima).
Gate de fase quem fecha é o dono; este item não fecha P1.

## 6. O que NÃO fazer

Nenhum `HotSet`, Véu, `SlowSim`, `MindsInspector`, `MindStore`, replay, fita de comandos,
`af-bench`, `docs/engine/simclock.md`, facções, LOD por distância ou arma de fogo: nada disso
existe. Nada de tocar a difusão para "acomodar" canais novos, nada de mudar os pesos existentes
das curvas na mesma mudança do imprint, nada de ler o canal no `AudioDirector`.

## 7. Commits atômicos

1. Colheita: checagens (a), (b), (c) **sem canal novo** — 232 → 235, e o resultado de (c) é o
   número que diz se há vazamento real. 2. `FORMAT_VERSION`/dimensão do journal conferidos com a
   contagem de canais parametrizada. 3. Canal MORTE: enum + 5 estruturas + imprint nas duas
   mortes + uma curva + cenário dedicado. 4. Canal SOM: imprint nos eventos de mundo (lavra,
   dano, morte) + uma curva + cenário. 5. FOGO: só abre quando existir fonte; enquanto não
   existir, é linha de backlog. Suíte verde entre cada um; o número do item 5 e 6 volta a ser
   hipótese se o código mudar depois da medição — re-medir em clone limpo do SHA final com
   `godot --headless --path . --import` e pinar o SHA na linha publicada.

## 8. Citações que não conferem no repositório

- `docs/melhorias-status.md:274-277`: "três tabelas paralelas de `aether_field.gd:11-15`" e "uma
  cor em `aether_viz.gd:12-16"`. No arquivo há duas tabelas (`:13`, `:15`), mais `CHANNEL_NAMES`
  (`:11`) e o `enum Channel` (`:9`); a cor é a quinta superfície com largura e a sexta é
  `Channel.COUNT` dentro da projeção do journal (`src/persistence/tick_journal.gd:38`) — abrir
  canal muda todo hash publicado.
- `:276` lista "tiro/passo" e "lava/fogueira" como fontes. Não há projétil nem fogo: `Block`
  (`src/world/block_defs.gd:10-23`) tem 13 entradas, `COUNT = 23` (`:37`) e nenhum tile de fogo
  (`:40-53`); grep de `lava|burn|flame|fogueira` em `src/` devolve só comentários e o verbo lavar
  (`recipes.gd:41`, `main.gd:477`, `voxel_atlas.gd:174`). "Passo" existe apenas como leitor de
  corpo no diretor (`audio_director.gd:435-457`), que o contrato proíbe de escrever.
- `:277` ("leitura nas curvas de utilidade") não diz que a leitura é hoje fixa nos três canais
  (`wolf.gd:442-444`) nem que a escolha de canal do rastro descarta o medo (`wolf.gd:487`).
- `docs/design/08-roadmap-risks-licensing.md:29` publica "AetherField de **3** canais" e `:68`
  promete 6 no gate de P1 — as duas frases envelhecem juntas no dia em que `COUNT` mudar, e
  nenhuma delas é o gate (`:72-74`).
- `AGENTS.md` publica 196 608 B/tick e 3 canais: os dois valores caem com o commit 2.
- O log publicado não fecha conta com `HALF_LIFE`: `docs/evidence/third-person-carry/clone-suite.log:68`
  mostra 2.500 → 2.296 (8,16%) em 8 passadas de `diffuse_and_decay(0.25)` (`tests/smoke_test.gd:657-660`),
  onde `HALF_LIFE[FEAR] = 120` prevê 0,9985570^8 = 0,98850 → 2,471. Faltam 0,175 de massa, a causa
  não foi medida, e o único zeramento do código é o corte de `MIN_VALUE` (`aether_field.gd:136-138`).

## 9. O que chegou a este plano por briefing e não existe no repositório

Nada abaixo aparece em `docs/`, `src/` ou `tests/` — conferido por grep nesta máquina. São
afirmações que vieram do prompt que produziu este dossiê; o código as refuta e o registro fica
aqui porque a regra 1 do contrato não permite herdar número sem fonte.

- Meia-vida "morta", "11,33% por passada", "4,8 s efetivos", "igual para os três": `HALF_LIFE` é
  lido por canal em `aether_field.gd:111` e os três `keep` são distintos (0,9980764 / 0,9968542 /
  0,9985570 com `elapsed = 0,25`).
- `TrailReader`, `_sample_trail`, `_sighting_cache_cap`, `_sighting_cache_ttl`, `_scan_interval`:
  nenhum nome existe. O scanner é `_find_scent()` (`wolf.gd:461-496`) com `SCENT_PERIOD 0,25`
  (`:29`), `SCENT_MEMORY_SECONDS 30,0` (`:31`), `SCENT_MEMORY_CAP 32` (`:32`) e `SCENT_RENEWAL
  0,06` (`:33`); "TTL de 3000 ms" erra nome, unidade e linha.
- `DECAY_PER_SEC`, `SOURCE_RATE`, `SATURATION` e os "três dicionários paralelos em
  `tests/aether_reactions_test.gd:57-73`": zero ocorrências no repositório; `:55-60` é `_check` e
  `:62-88` é `_test_fixture`.
- `imprint(channel, cell, amount)` em `aether_field.gd:46-54`: a assinatura real é
  `imprint(world_pos, ch, amount)` (`:81-83`); `:44-48` é o `setup()`.
- Pesos WORK/BLOOD/FEAR em `src/ai/utility_scorer.gd:11-27` e `:46-61`: o arquivo é mecanismo
  (`Consideration` `:6-17`, `scored` `:54-79`, normalização por `weight_sum` `:75`, `min_lead
  0,06` `:41`) e não cita canal nenhum; as considerações com peso estão em `wolf.gd:356-398`.
- `audio_director.gd:314` como leitura de posição de playback: `:314` é
  `v.max_distance = MAX_DISTANCE`; a posição real vem de `_voice_index()` (`:334+`).
- "a contagem de checagens mora em `docs/melhorias-status.md:14-17`": não mora — 232 aparece em
  `:91`, `:249`, `:654` e `:691`.
