# 06 — Decompor `src/main.gd` pelo eixo do dono

Plano derivado de leitura; nada foi rodado por mim. Cobre o item 7 de "Falta" (`docs/melhorias-status.md:728-730`) e a linha do prompt "reduza o acoplamento de `main.gd`/`wolf.gd`/memória" (`:53`), cujo veredito publicado é "medir por linhas é proxy, o que importa é o dono único". Regras da casa aplicáveis: anti-bloat e as quatro perguntas (`AGENTS.md`, "Disciplina de otimização") e "generalize no segundo chamador, não no primeiro". O alvo arquitetural nomeia um relógio de simulação em `src/core/sim/` (`docs/design/06-godot-architecture.md:33`), `MindServer` autoload (`:112`), `MindsInspector` e `af-bench` (`:197-199`): nenhuma dessas peças existe em `src/` — `[TARGET]`, legenda em `docs/design/README.md:12`. As faixas abaixo foram re-lidas contra `src/main.gd` de **1242 linhas** e `src/entities/wolf.gd` de **1218** (`wc -l` na árvore onde a perna 16 pousou as tocas). A versão original descrevia a revisão de 501 linhas (`4dac943`) e a primeira re-leitura, os 662 de `3fccbb2`; nenhuma linha deste plano foi executada.

## Premissa nomeada: ônibus não é dono

`src/main.gd` tem 1246 linhas (`wc -l`) e 47 declarações de topo no cabeçalho (`9-111`: 34 `var` + 13 `const`, entre elas as 10 referências de sistema — `world`, `aether`, `clock`, `player`, `viz`, `hud`, `oracle`, `llm_host`, `audio`, `wolves` —, a `Journal` pré-carregada em `:41`, `stats` e o resto dos variáveis de controle). A premissa que este plano exige e que o código decide: **um bloco só merece virar dono quando já tem comprador fora de `main.gd`.** Medido por grep de chamadas dentro de `src/main.gd` (`wolves` 54 linhas, `player.` 49, `hud.` 26, `world.` 21, `llm_host` 19, `clock.` 13, `tick_journal.` 10, `_benches` 10, `_pack_*` 23, `_dens` 22, `_respawn_queue` 9, `audio.` 6, `viz.` 6, `oracle.` 3) cruzado com quem alcança estado por sessão em `tests/`: 8 arquivos (`smoke_test.gd` 140 acessos / 21 nomes, `tick_journal_test.gd` 59 / 18, `audio_test.gd` 41 / 11, `aether_reactions_test.gd` 39 / 17, `llm_server_boot_probe.gd` 18 / 8, `simulation_rng_test.gd` 18 / 12, `live_oracle_probe.gd` 5 / 3 e `audio_live_probe.gd` 4 / 2) — e a afirmação de antes, "**zero** em `tests/aether_reactions_test.gd`", não vale mais: ele continua montando mundo, campo e lobos próprios, mas três encenações instanciam a sessão (`:191-201`, `:1767-1777`, `:3133-3142`) e é por essa porta que a alcateia e as tocas são conferidas. Consequência lida: oráculo, visualização e áudio **já têm dono** (`src/ai/mind_oracle.gd:39-40`, `:47`, `:110-111`; `src/rendering/aether_viz.gd:21-25`, `:40`, `:47`, `:51`; `src/audio/audio_director.gd:104-106`, `:146`, `:158`, `:166`); o que vive no `main.gd` desses três é fiação e cadência, não estado. O estado **sem dono** é a matilha (`:57`) e o trio `_benches` (`:92`), `_respawn_queue` (`:70`) e `_pack_buffers`/`_pack_cursor` (`:96-97`), com `_dens` (`:109`) no mesmo estado desde a perna 16. Não existe `[autoload]` em `project.godot`: hoje todo acesso a subsistema passa por instanciar `src/main.tscn`.

## Inventário honesto (faixa × linhas × de quem é)

| Bloco | `src/main.gd` | Linhas | Dono real hoje |
| --- | --- | --- | --- |
| constantes + membros | `9-111` | 103 | sessão |
| `_ready` (7 nós próprios + 7 pontas de `Callable`) | `112-199` | 88 | sessão |
| host do oracle: start, attach, wire, consulta | `200-246` | 47 | `LlmServerHost` (`src/ai/llm_server_host.gd`) |
| `spawn_point` | `247-254` | 8 | mundo |
| relógios: `_physics_process`, `_sim_tick`, `_process` | `255-317` | 63 | relógio + matilha + Éter + journal |
| input e `respawn` | `318-334` | 17 | sessão |
| matilha: spawn, sorteio, baixada | `335-410` | 76 | **nenhum** (`var wolves: Array` `:57`) |
| acasalamento: roda, idoneidade, nascimento | `411-485` | 75 | **nenhum** (mesma lista, mais `_next_identity` `:63`) |
| lares (`_home_columns`) + constantes de spawn/mate/ronda | `486-553` | 68 | **nenhum** |
| tocas: censo, portão, fundação, recusas | `554-734` | 181 | **nenhum** (`var _dens: Array` `:109`) |
| ponto de lar (`_spawn_home_point`) | `735-807` | 73 | **nenhum** |
| volume livre + portas (`targets_under_crosshair`, `wolves_roster`, `pack_of`) | `808-837` | 30 | **nenhum** |
| ronda (`_rebuild_packs`, `_pack_slot`, `_pack_put`) | `838-886` | 49 | **nenhum** (`_pack_buffers` `:96`) |
| faina de cadáveres (`_reap_corpses`) | `887-907` | 21 | **nenhum** |
| ecos do mundo: 10 handlers + `_imprint` + `bench_positions` + 2 toggles | `908-988` | 81 | ônibus (jogador→Éter/HUD/lobo) |
| persistência: `save_game`, `load_game`, `_rebuild_benches`, `stats_line` | `989-1158` | 170 | 7 donos num só passo |
| `diagnostics` | `1159-1195` | 37 | leitura agregada |
| `_build_environment` (sol, céu, neblina) | `1196-1230` | 35 | recursos do engine |
| `state_hash`, CLI do journal, `_exit_tree` | `1231-1246` | 16 | journal |

Cada faixa vai da primeira declaração do bloco até a linha antes da primeira declaração do seguinte; os docstrings que abrem um bloco caem na faixa de cima, e é por isso que a soma fecha sem sobra de comentários.

Blocos somam 1234 linhas; as 8 restantes são o cabeçalho do arquivo (`1-8`). Separação de **fato** só existe onde há porta nomeada consumida por terceiros: `targets_under_crosshair()` (`:813-820`) e `wolves_roster()` (`:821-827`) têm quatro portas chamadas na própria sessão (`:150` jogador, `:173` HUD, `:181` oráculo, `:192` áudio), a projeção do hash (`src/persistence/tick_journal.gd:36-39`) e três compradores de teste: `tests/smoke_test.gd`, `tests/aether_reactions_test.gd` pela porta `pack_of` de `main.gd:850-852` (uso em `tests/aether_reactions_test.gd:2022`, `:3899`, `:4074`) e as duas portas de observabilidade que a perna 16 abriu — `den_min_dist()` (`:679-686`) e `den_components()` (`:701-721`), lidas por `tests/smoke_test.gd:349-350` e `tests/aether_reactions_test.gd:4041-4052`. Nos outros blocos o que existe é tamanho: `_ready` separa por comentário, não por interface.

## Candidatas, da mais barata à mais cara

**K1 — índice de bancadas.** Dono de `_benches` (`:92`), das duas mutações em `_on_block_broken`/`_on_block_placed` (`:921-933`), de `bench_positions()` (`:934-936`) e de `_rebuild_benches()` (`:1145-1151`): ~18 linhas. Já tem segundo comprador medido: `player.bench_provider` (`:151`) e o load (`:1072`). Fica no `main.gd`: a contagem `mined`/`placed` (mesmos handlers, lida por 20 ocorrências de `main.stats`/`_main.stats` em `tests/`, entre as quais "segurar break minerou" `tests/smoke_test.gd:1960`) e `stats_line`. Prova: `tests/smoke_test.gd:2586,2687,2697,2721,3370` ("bancada tem teto menor que bloco comum", "sem bancada a lista so mostra as de mao", "a cadeia ate a bancada fecha", "vidro na bancada come 2 de areia", "sem bancada so mostra as receitas de mao"); nenhum teste alcança bancada por `main` (censo de nomes acima).

**K2 — fila de respawn e faina de cadáveres.** Dono de `_respawn_queue` (`:77`), `RESPAWN_DELAY`/`CORPSE_CHECK_PERIOD` (`:30-31`), do dreno no passo (`:296-313`) e de `_reap_corpses` (`:909-921`, chamado em `:299` com a cadência de `1 s` em `:296-298`): ~20 linhas. Fica como leitura: `pending_respawns` do diagnóstico (`:1194`). **O custo que esta página previa não existe mais:** o dreno não imprime nada na tela. A frase "uma nova matilha entrou no vale" saiu na perna 14 porque mentia justamente quando `_spawn_wolves(1)` recusa o ponto e a vaga volta para a fila, e o motivo está escrito no próprio bloco (`:283-287`) — não há `hud.show_message` para virar callback do dono, e a decisão `[OPEN]` se extingue com ele. **Nenhuma checagem tem "respawn" no nome** (grep de `_check("` com filtro `respawn` devolve 0 nas duas suítes), mas a fila já é observada por nome próprio: "ainda na matilha (tempo de cadaver)" (`tests/smoke_test.gd:3464`), "cadaver recolhido da matilha"
(`:2895`) e "reposicao enfileirada" (`:2897`). O pré-requisito que faltava foi **pago em parte** pela perna 16: `tests/aether_reactions_test.gd:4257-4314` ("reposicao_volta_para_a_toca_perdida") segue uma vaga de ponta a ponta — `die()` → cadáver → `_reap_corpses` → fila de 45 s → `_spawn_wolves` — dirigindo `_sim_tick()` e imprimindo `passos`, o `den` herdado e o tamanho da fila no fim. Falta o par `filas_antes/depois` por faena, que é o que a K2 exige para o dono novo não mudar a contagem sem que alguém veja.

**K3 — matilha (`[TARGET]`, arquivo novo sob `src/entities/`, nome a definir).** Dono de `wolves` (`:57`), `_next_identity` (`:63`), `_population_rng` (`:64`), `_spawn_wolves` (`:335-374`), `_make_wolf` (`:375-394`) e `_retire_wolf` (`:400-410`), do acasalamento (`:411-485`), dos lares e constantes (`:486-553`), das tocas (`:554-734`), do ponto de lar (`_spawn_home_point` `:735-807` — **era `_random_ground_point`, morto pela perna 14**), de `_volume_clear` (`:808-812`), das portas (`:813-837`), da ronda (`pack_of`/`_rebuild_packs`/`_pack_slot`/`_pack_put` `:829-886`) e de `_reap_corpses` (`:887-899`), com `WOLF_COUNT` (`:9`): **573 linhas de bloco (`335-907`)** — na ponta de 662 linhas (`3fccbb2`) o mesmo bloco ia de `278` a `411` (de `_spawn_wolves` ao fim de `_reap_corpses`), 134 linhas: um fator de **4,3**. O motivo é lido no arquivo: que a K3 teria de levar são `wolves` (`:57`), `_next_identity` (`:63`), `_population_rng` (`:64`), `_respawn_queue` (`:70`), `_census_refusals` (`:77`), `_births` (`:82`), `_mate_cd` (`:83`), `_pack_buffers`/`_pack_cursor` (`:96-97`), `_pack_pairs` (`:101`) e `_dens` (`:109`), mais as constantes `WOLF_COUNT` (`:9`), `CENSUS_CAP` (`:18`), `SAFE_SPAWN_DIST` (`:24`), `RESPAWN_DELAY`/`CORPSE_CHECK_PERIOD` (`:30-31`), `PACK_COHESION_RADIUS`/`EMPTY_PACK` (`:39-40`) e o bloco `497-548`. Fica no `main.gd`: o `var pack` e **os mesmos nomes**, porque `tests/tick_journal_test.gd:83` lê `Main.WOLF_COUNT` da constante do script, `tests/audio_test.gd:294,315` lê `main._population_rng.state`, `tests/simulation_rng_test.gd:87,92,100` chama `_spawn_wolves`/`_volume_clear` e `tests/tick_journal_test.gd:75,381,385,404` dirige `_sim_tick()` com `process_mode` desligado. Propriedade só-leitura é armadilha lida: `tests/simulation_rng_test.gd:82` **atribui** `session.clock = SimClock.new()`, então getter sem setter quebra teste de propósito. O `audio.on_wolf_registered` dentro do spawn (`main.gd:413-414`) continua atrás do mesmo `if audio != null` — o contrato do RNG (`tests/simulation_rng_test.gd` e as notas do som) não admite som obrigatório no spawn. Prova: `tests/smoke_test.gd:279-283` ("censo do boot fecha com a fila" — **substituiu** "5 lobos na matilha", que a censo variável das pernas 14/16 aposentou), `:259-260` (a colheita das posições de spawn), `:3093` ("cadaver recolhido da matilha"), `tests/audio_test.gd:278` ("cada lobo do spawn entrega seus tres sinais ao diretor"), `tests/simulation_rng_test.gd:87-100` e `tests/tick_journal_test.gd:377-430`.

**K4 — passo de persistência.** Não extrair ainda: `save_game` (`:989-1024`) e `load_game` (`:1027-1144`) escrevem em 7 donos (`world.generate` `:1050`, `apply_edits` `:1054`, jogador `:1056-1065`, `audio.clear_transient` `:1073`, `aether.from_dict` `:1074`, `wolves[i].load_state` `:1105` e `:1120`, `clock.tick`/`elapsed` `:1136-1137`) e a perna 16 acrescentou um oitavo passo dentro do mesmo bloco: `_dens.clear()` `:1082` e o reenchimento `:1083-1084`. A limpeza de estado volátil no load é contrato publicado (`docs/melhorias-status.md:137-142` para a fila de reposição, `:1375-1380` para o estado de corpo do áudio). O único corte defensável é o dicionário do payload (`:1076-1093`) para um `SavePayload` com `to_dict()`/`from_dict()` — segundo chamador inexistente hoje, então é `[OPEN]` condicionado a aparecer o 2° consumidor, que só o replay do item 2 de "Falta" seria (`docs/melhorias-status.md:546-557`, e ele mesmo diz "isso é pré-condição de replay, não replay"). Prova se um dia mover: `tests/smoke_test.gd:3407` ("contador de mortes"), `:3453` ("slot escrito"), `:3516` ("tick restaurado"), `:3521` ("hp do lobo voltou").

## Custo — as quatro perguntas

1. **Frame, tick ou às vezes?** K1 roda no evento do jogador (`_on_block_broken`/`_on_block_placed` `:921-933`, conectados em `:152-153`) e no load (`_rebuild_benches()` chamada em `:1072`, corpo `:1145-1151`); K2 roda 1×/s no tick (`:274-277`) e drena a fila a cada passo (`:278-291`). K3 roda no boot (`_spawn_wolves(WOLF_COUNT)` `:196`), em lotes de respawn (`:291`) e no parto (`:469`), com a ronda reconstruída uma vez por passo (`:271`). K4 é tecla: F5/F9 (`src/input/input_actions.gd:34-35`) lidos pelo jogador (`src/entities/player.gd:271-273`) e conectados à sessão em `:160-161`. Nenhuma das quatro coloca código novo em `_physics_process` (`:255-263`) nem no teto de 5 passos (`src/core/sim_clock.gd:19-29`).
2. **Entidades alcançadas?** `WOLF_COUNT := 5` no boot (`:9`), e o censo é variável desde a perna 11: a corrida publicada na ponta do bioma fechou com 4 vivos dos 5 (`docs/evidence/bioma-cor-de-pelo/clone-44c9d94-suite.log:309`, `edits=13` em `:310`), e a corrida desta ponta fecha com **7 vivos** (`births=2`, `dens=3`, `pack_pairs=21`, `tick=403`, `docs/evidence/tocas-alcateia-16/head_suite.log:345`), contra o teto `CENSUS_CAP := 12` (`:18`); 1 jogador, 64 chunks. O censo de `stats_line` (`:1152-1157`) imprime bancadas, vivos/teto e recriacoes. Os compradores externos alcançados por K3 são as quatro portas da sessão (`:150` jogador, `:173` HUD, `:181` oráculo, `:192` áudio), a projeção do hash e `pack_of` do teste de alcateia.
3. **Aloco no caminho quente?** K1 e K3 não mudam alocação: `_benches` já é `Array[Vector3i]` tipado (`:92`) e `wolves` continua o mesmo objeto em memória — mover o membro não muda o `Dictionary` novo por lobo por tick (`src/entities/wolf.gd:923`), que é débito à parte, nem os buffers da ronda, que já são reescritos no lugar (`src/main.gd:940-955`). O dono novo é 1 `RefCounted` por sessão, alocado no boot.
4. **Como sei que ficou melhor?** Não é otimização, é estrutura: o critério é o censo travado e o passo não piorado (abaixo). O ganho medível declarado é `main.gd` perder N linhas por commit, com N impresso na mensagem.

## Gate headless (comando e critério numérico)

```sh
godot --headless --path . --import
godot --headless --path . --check-only --script src/main.gd
godot --headless --path . tests/smoke_test.tscn
godot --headless --path . --script tests/tick_journal_test.gd
godot --headless --path . --script tests/aether_reactions_test.gd
godot --headless --path . --script tests/audio_test.gd
godot --headless --path . --script tests/simulation_rng_test.gd
```

Critérios: a última linha do smoke (`tests/smoke_test.gd:265`) continua no censo publicado da
revisão — nesta ponta **255 checagens / 0 falhas / 48,0 s**
(`docs/evidence/tocas-alcateia-16/head_suite.log:357`, nota em
`docs/melhorias-status.md:4485-4487`) — e `dropped_ticks=0`, com `tick=403` (idem `:377`). A
pontagem anterior desta página (`237 / 0 / 35,5 s`, `tick=359`) era o censo da ponta do bioma
(`docs/evidence/bioma-cor-de-pelo/clone-44c9d94-suite.log:312`, `:309`) e continua válida **só**
para aquele SHA.

**O terceiro critério desta linha estava errado e foi retirado.** Ele pedia `worst_sim_ms` dentro
do publicado `6,78 ms` (`docs/evidence/third-person-carry/clone-suite.log:303,305,307`) com
"desvio > 20% sem medição concorrente é vermelho, não ruído". `worst_sim_ms` é máximo de corrida de
uma distribuição larga, não teto: na mesma máquina e no mesmo dia, antes da colheita do corte, a
mesma estatística deu `8,436` / `13,106` / `14,474` ms (220 checagens) e depois dela `12,929`
(clone) / `13,186` (branch) / `13,898` (`main` mergida). Os `6,78` são uma amostra dessa
distribuição, e a amostra de antes da colheita já chegava a `14,47` — ou seja, o critério daria
vermelho para corridas que não perderam um tick sequer (`dropped_ticks=0` nas seis). O que entra no
lugar: nenhuma mudança de K1/K2/K3 pode perder tick, e a comparação de passo exige **banda medida
em N execuções da mesma árvore antes e depois**, não um pico solitário. Atribuição por ablação da
varredura de corte não foi rodada e fica debitada
(`docs/melhorias-status.md:2067-2068`).

O contrato do journal trava **128 checagens** (`tests/tick_journal_test.gd:13`) e as 6 linhas de `[tick,hash]` do caminho dirigido por `_sim_tick()` (`:401-412`, `MAIN_STEPS = 6` em `:7`) têm de bater entre antes e depois do commit: a checagem de repetibilidade **não existe hoje** (grep de `repetib` em `tests/` e no status devolve zero), então o primeiro passo de K3 roda a suíte duas vezes e publica as sequências; se divergirem na própria árvore antes da mudança, o critério de hash é retirado do gate e fica só censo + `dropped_ticks` + passo. Áudio: **73 checagens** (`tests/audio_test.gd:25`); reações: **240** (`tests/aether_reactions_test.gd:65`), já medidas duas vezes nesta ponta com o mesmo censo (`docs/melhorias-status.md:4485-4487`); RNG: **27** (`tests/simulation_rng_test.gd:9`). Contagem conferida **antes** do lote (`AGENTS.md`, "Nada simulado"): um `SCRIPT ERROR` derruba passos em silêncio.

## O que NÃO fazer

Não reorganizar por gosto: mover `_build_environment` (`:1192-1226`) para arquivo novo é generalização no primeiro chamador — 1 comprador (`:127`), zero estado, zero teste. Criar autoload sem segundo chamador: não há `[autoload]` em `project.godot` hoje, e cada autoload novo é estado global com dono invisível. Mover estado sem dono: `elapsed` (`:58`) e `stats` (`:59`) não têm comprador fora do `main.gd` além do HUD e do smoke. Esconder o que o `TickJournal` e os testes leem: `world`, `aether`, `wolves`, `clock`, `player`, `stats`, `_population_rng`, `state_hash()`, `diagnostics()`, `tick_journal`, `oracle`, `audio`, `hud`, `_sim_tick`, `_spawn_wolves`, `_volume_clear`, `save_game`, `load_game`, `respawn`, `spawn_point`, `targets_under_crosshair`, `wolves_roster`, `pack_of`, `_dens` (alcançado por nome em `tests/aether_reactions_test.gd:4018`, `:4092`, `:4175`, `:4189`) e as duas portas de toca que a perna 16 abriu — `den_min_dist()` (`:673-680`) e `den_components()` (`:695-715`), lidas em `tests/aether_reactions_test.gd:4102` e `:4109` — continuam alcançáveis por `main`; o plano não redefine o contrato do hash (`docs/melhorias-status.md:49` e `:543-557`). E a decomposição **não** fecha o item de autoridade temporal (`docs/melhorias-status.md:577-578`): jogador, corpos e timers continuam mudando por frame (`src/entities/wolf.gd:1215-1271`), e isso é o plano 01, não este.

## Checklist de commits atômicos (um assunto, uma corrida)

1. Checagem nova de respawn/cadáver impressa (K2 pré-requisito), produção intocada. **Pago em
   parte pela perna 16** (`tests/aether_reactions_test.gd:4196-4253`); o que falta é o par
   `filas_antes/depois` por faena. O censo desta ponta é **255** (`docs/evidence/tocas-alcateia-16/head_suite.log:357`)
   e sobe para 255+K com K declarado.
2. K1: índice de bancadas com dono; `main.gd` mantém `bench_positions()` como porta.
3. K2: fila e faina com dono; a única frase que o dreno imprimia saiu na perna 14, então o commit
   não move apresentação nenhuma.
4. K3: dono da matilha; nenhuma linha de `_sim_tick` (`:264-306`) reordenada no mesmo commit.
5. Atualizar `docs/melhorias-status.md` (item 7, débitos de dono, censos de `main.gd:NNN` envelhecidos) e re-derive as citações.
6. Re-medida no clone limpo do SHA final com `--import`, SHA pinado no texto (`AGENTS.md`, ciclo de trabalho 6).

## Citações que não conferem

`docs/melhorias-status.md:53` publicava `main.gd` 662 linhas e `wolf.gd` 959 na ponta em que esta linha foi escrita (`3fccbb2`) — re-medido naquela ponta com `wc -l`, confere —; passou a 1004 e 1203 na ponta da 19 e publica **1246** e **1218** nesta (`wc -l` de hoje), e é o número que apodrece primeiro (`:1052-1053` registra o risco e a regra). As faixas deste plano eram da revisão de 501 linhas (`4dac943`): `_ready` era `49-125` (naquela ponta, `71-156`; nesta, `112-199`), a matilha era `199-263` (naquela ponta, `278-411`, porque a ronda e os buffers da perna 10 entraram aí; nesta, `335-410` com as tocas `554-734` logo depois), `diagnostics` era `435-446` (naquela ponta, `592-607`; nesta, `1159-1195`) e a CLI do journal era `486-501` (naquela ponta, `647-662`; nesta, `1235-1242`). O bloco do hospedeiro do oráculo (`162-203`, 42 linhas) não existia quando o plano foi lido e entrou como linha nova do inventário, onde hoje lê `200-246`. `AGENTS.md` citava `main.gd:668-669` para `state_hash()`, `:624-639` para `diagnostics()` e `:691-698` para a CLI — os três conferem naquela ponta; nesta ponta citam `:1296-1297`, `:1159-1185` e `:1300-1307`, e os três conferem aqui. `docs/design/06-godot-architecture.md:33` aponta `src/core/sim/tick_clock.gd`, caminho que não existe — o real é `src/core/sim_clock.gd` (47 linhas). Nada deste plano foi executado: os números de checagem e de passo vêm do log publicado, não de corrida minha.
