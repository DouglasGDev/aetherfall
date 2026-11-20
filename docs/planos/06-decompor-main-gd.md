# 06 — Decompor `src/main.gd` pelo eixo do dono

Plano derivado de leitura; nada foi rodado por mim. Cobre o item 7 de "Falta" (`docs/melhorias-status.md:325-327`) e a linha do prompt "reduza o acoplamento de `main.gd`/`wolf.gd`/memória" (`:35`), cujo veredito publicado é "medir por linhas é proxy, o que importa é o dono único". Regras da casa aplicáveis: anti-bloat e as quatro perguntas (`AGENTS.md`, "Disciplina de otimização") e "generalize no segundo chamador, não no primeiro". O alvo arquitetural nomeia um relógio de simulação em `src/core/sim/` (`docs/design/06-godot-architecture.md:33`), `MindServer` autoload (`:112`), `MindsInspector` e `af-bench` (`:197-199`): nenhuma dessas peças existe em `src/` — `[TARGET]`, legenda em `docs/design/README.md:12`.

## Premissa nomeada: ônibus não é dono

`src/main.gd` tem 501 linhas (`wc -l`) e 24 membros (`:19-46`: 11 referências de sistema, 12 variáveis de controle, 1 journal). A premissa que este plano exige e que o código decide: **um bloco só merece virar dono quando já tem comprador fora de `main.gd`.** Medido por grep de chamadas dentro de `src/main.gd` (`hud.` 26 linhas, `player.` 43, `wolves` 25, `world.` 19, `clock.` 13, `tick_journal.` 10, `viz.` 6, `audio.` 5, `oracle.` 2, `_benches` 10, `_respawn_queue` 8) cruzado com quem alcança estado por `main` em `tests/`: 5 arquivos (`tests/smoke_test.gd` com 17 nomes distintos, `tests/tick_journal_test.gd`, `tests/audio_test.gd`, `tests/simulation_rng_test.gd`, `tests/live_oracle_probe.gd`) e **zero** em `tests/aether_reactions_test.gd` (grep de `main.` devolve 0 ocorrências — ele monta mundo, campo e lobos próprios). Consequência lida: oráculo, visualização e áudio **já têm dono** (`src/ai/mind_oracle.gd:20,45,59`; `src/rendering/aether_viz.gd:21-25,40,47,51`; `src/audio/audio_director.gd:104-106,146,158,166`); o que vive no `main.gd` desses três é fiação e cadência, não estado. O estado **sem dono** é a matilha (`:29`) e o par de índices `_benches`/`_respawn_queue`. Não existe `[autoload]` em `project.godot`: hoje todo acesso a subsistema passa por instanciar `src/main.tscn`.

## Inventário honesto (faixa × linhas × de quem é)

| Bloco | `src/main.gd` | Linhas | Dono real hoje |
| --- | --- | --- | --- |
| constantes + membros | `9-46` | 38 | sessão |
| `_ready` (7 nós próprios + 7 pontas de `Callable`) | `49-125` | 77 | sessão |
| `spawn_point` | `128-131` | 4 | mundo |
| relógios: `_physics_process`, `_sim_tick`, `_process` | `136-179` | 44 | relógio + matilha + Éter + journal |
| input e `respawn` | `182-194` | 13 | sessão |
| matilha: spawn, sorteio, volume, censo, faina | `199-263` | 65 | **nenhum** (`var wolves: Array` `:29`) |
| ecos do mundo: 11 handlers + 2 toggles | `268-337` | 70 | ônibus (jogador→Éter/HUD/lobo) |
| persistência: `save_game`, `load_game`, `_rebuild_benches`, `stats_line` | `341-432` | 92 | 7 donos num só passo |
| `diagnostics` | `435-446` | 12 | leitura agregada |
| `_build_environment` (sol, céu, neblina) | `451-483` | 33 | recursos do engine |
| `state_hash`, CLI do journal, `_exit_tree` | `486-501` | 16 | journal |

Blocos somam 464 linhas; as 37 restantes são cabeçalho (`1-8`), comentários de seção e separadores. Separação de **fato** só existe onde há porta nomeada consumida por terceiros: `targets_under_crosshair()` (`:245-250`) e `wolves_roster()` (`:253-254`) têm 5 compradores externos (`:104` HUD, `:112` oráculo, `:120` áudio, `src/persistence/tick_journal.gd:22-27` projeção do hash, e 4 arquivos de teste). Nos outros blocos o que existe é tamanho: `_ready` separa por comentário, não por interface.

## Candidatas, da mais barata à mais cara

**K1 — índice de bancadas.** Dono de `_benches` (`:46`), das duas mutações em `_on_block_broken`/`_on_block_placed` (`:276-285`), de `bench_positions()` (`:289-290`) e de `_rebuild_benches()` (`:421-425`): ~18 linhas. Já tem segundo comprador medido: `player.bench_provider` (`:82`) e o load (`:406`). Fica no `main.gd`: a contagem `mined`/`placed` (mesmos handlers, lida por 8 checagens via `main.stats`) e `stats_line`. Prova: `tests/smoke_test.gd:1507,1517,1541,2096` ("sem bancada a lista so mostra as de mao", "a cadeia ate a bancada fecha") e `:1406`; nenhum teste alcança bancada por `main` (censo de 17 nomes acima).

**K2 — fila de respawn e faina de cadáveres.** Dono de `_respawn_queue` (`:37`), `RESPAWN_DELAY`/`CORPSE_CHECK_PERIOD` (`:15-16`), do dreno no passo (`:154-163`) e de `_reap_corpses` (`:257-263`): ~20 linhas. Fica: a mensagem ao HUD (`:163`), porque é decisão de apresentação, e `pending_respawns` do diagnóstico (`:441`) como leitura. Custo: o `hud.show_message` do dreno vira callback do dono ou continua no `main.gd` — `[OPEN]`, decisão do dono. **Não há checagem com "respawn" no nome na suíte** (grep de `_check("` com filtro `respawn` devolve 0); a fila só é visível em `diagnostics()`. Pré-requisito K2: uma checagem nova que imprima `filas_antes/depois` e `lobos` por faina, antes de mover.

**K3 — matilha (`[TARGET]`, arquivo novo sob `src/entities/`, nome a definir).** Dono de `wolves`, `_next_identity` (`:35`), `_population_rng` (`:36`), `_spawn_wolves` (`:199-215`), `_random_ground_point` (`:218-232`), `_volume_clear` (`:240-242`), das duas portas (`:245-254`) e de `WOLF_COUNT` (`:9`): ~75 linhas (65 de método `:199-263` + 5 membros/constantes). Fica no `main.gd`: o `var pack` e **os mesmos nomes**, porque `tests/tick_journal_test.gd:78` lê `Main.WOLF_COUNT` da constante do script, `tests/audio_test.gd:288,309` lê `main._population_rng.state`, `tests/simulation_rng_test.gd:87,92,100` chama `_spawn_wolves`/`_volume_clear` e `tests/tick_journal_test.gd:358,363,382` dirige `_sim_tick()` com `process_mode` desligado. Propriedade só-leitura é armadilha lida: `tests/simulation_rng_test.gd:82` **atribui** `session.clock = SimClock.new()`, então getter sem setter quebra teste de propósito. O `audio.on_wolf_registered` dentro do spawn (`:213-214`) continua atrás do mesmo `if audio != null` — o contrato do RNG (`tests/simulation_rng_test.gd` e as notas do som) não admite som obrigatório no spawn. Prova: `tests/smoke_test.gd:171` ("5 lobos na matilha"), `:189-193`, `:2261`, `tests/audio_test.gd:278` ("cada lobo do spawn entrega seus tres sinais ao diretor"), `tests/simulation_rng_test.gd:87-100` e `tests/tick_journal_test.gd:357-401`.

**K4 — passo de persistência.** Não extrair ainda: `save_game`/`load_game` (`:341-415`) escrevem em 7 donos (`world.generate` `:384`, `apply_edits` `:388`, `aether.from_dict` `:408`, `wolves[i].load_state` `:411`, jogador `:390-399`, `audio.clear_transient` `:407`, `clock.tick`/`elapsed` `:412-413`) e a limpeza de estado volátil no load é contrato publicado (`docs/melhorias-status.md:656-656`). O único corte defensável é o dicionário do payload (`:342-364`) para um `SavePayload` com `to_dict()`/`from_dict()` — segundo chamador inexistente hoje, então é `[OPEN]` condicionado a aparecer o 2° consumidor (o save por região do §07). Prova se um dia mover: `tests/smoke_test.gd:2133,2113,2136,2156,2175` ("contador de mortes", "tick restaurado").

## Custo — as quatro perguntas

1. **Frame, tick ou às vezes?** K1 e K2: K1 roda no evento do jogador (`:276-290`) e no load (`:421-425`); K2 roda 1×/s no tick (`:154-163`). K3 roda no boot (`:124`) e em lotes de respawn. K4 é tecla. Nenhuma das quatro coloca código novo em `_physics_process` (`:136-142`) nem no teto de 5 passos (`src/core/sim_clock.gd:19-29`).
2. **Entidades alcançadas?** 5 lobos (`:9`; 4 vivos no fim da corrida publicada), 1 jogador, 64 chunks, 10 bancadas no censo do `stats_line` (`:431`). Os compradores externos alcançados por K3 são 3 Callables + 1 projeção de hash.
3. **Aloco no caminho quente?** K1 e K3 não mudam alocação: `_benches` já é `Array[Vector3i]` tipado (`:46`) e `wolves` continua o mesmo objeto em memória — mover o membro não muda o `Dictionary` novo por lobo por tick (`src/entities/wolf.gd:433`), que é débito à parte. O dono novo é 1 `RefCounted` por sessão, alocado no boot.
4. **Como sei que ficou melhor?** Não é otimização, é estrutura: o critério é o censo travado e o passo não piorado (abaixo). O ganho medível declarado é `main.gd` perder N linhas por commit, com N impresso na mensagem.

## Gate headless (comando e critério numérico)

```sh
godot --headless --path . --import
godot --headless --path . --check-only --script src/main.gd
godot --headless --path . tests/smoke_test.tscn
godot --headless --path . --script tests/tick_journal_test.gd
```

Critérios: a última linha do smoke (`tests/smoke_test.gd:160`) continua no censo publicado da
revisão — hoje **236 checagens / 0 falhas**
(`docs/evidence/ether-massa-conservada/clone-suite.log:311`, nota em
`docs/melhorias-status.md:1236-1316`) — e `dropped_ticks=0` (`:2278-2280`).

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
(`docs/melhorias-status.md:1293-1305`).

O contrato do journal trava **128 checagens** (`tests/tick_journal_test.gd:13`) e as 6 linhas de `[tick,hash]` do caminho dirigido por `_sim_tick()` (`:379-394`) têm de bater entre antes e depois do commit: a checagem de repetibilidade **não existe hoje**, então o primeiro passo de K3 roda a suíte duas vezes e publica as sequências; se divergirem na própria árvore antes da mudança, o critério de hash é retirado do gate e fica só censo + `dropped_ticks` + passo. Áudio: **73 checagens** (`tests/audio_test.gd`). Contagem conferida **antes** do lote (`AGENTS.md`, "Nada simulado"): um `SCRIPT ERROR` derruba passos em silêncio.

## O que NÃO fazer

Não reorganizar por gosto: mover `_build_environment` (`:451-483`) para arquivo novo é generalização no primeiro chamador — 1 comprador (`:58`), zero estado, zero teste. Criar autoload sem segundo chamador: não há `[autoload]` em `project.godot` hoje, e cada autoload novo é estado global com dono invisível. Mover estado sem dono: `elapsed` (`:30`) e `stats` (`:31`) não têm comprador fora do `main.gd` além do HUD e do smoke. Esconder o que o `TickJournal` e os testes leem: `world`, `aether`, `wolves`, `clock`, `player`, `stats`, `_population_rng`, `state_hash()`, `diagnostics()`, `tick_journal`, `oracle`, `audio`, `hud`, `_sim_tick`, `_spawn_wolves`, `_volume_clear`, `save_game`, `load_game`, `respawn`, `spawn_point`, `targets_under_crosshair` continuam alcançáveis por `main` — o plano não redefine o contrato do hash (`docs/melhorias-status.md:592-615`). E a decomposição **não** fecha o item de autoridade temporal (`:292-293`): jogador, corpos e timers continuam mudando por frame (`src/entities/wolf.gd:526-571`), e isso é o plano 01, não este.

## Checklist de commits atômicos (um assunto, uma corrida)

1. Checagem nova de respawn/cadáver impressa (K2 pré-requisito), produção intocada; censo sobe de
   236 (base `9f3622b`) para 236+K com K declarado.
2. K1: índice de bancadas com dono; `main.gd` mantém `bench_positions()` como porta.
3. K2: fila e faina com dono; mensagem ao HUD permanece no `main.gd`.
4. K3: dono da matilha; nenhuma linha de `_sim_tick` (`:145-170`) reordenada no mesmo commit.
5. Atualizar `docs/melhorias-status.md` (item 7, débitos de dono, censos de `main.gd:NNN` envelhecidos) e re-derive as citações.
6. Re-medida no clone limpo do SHA final com `--import`, SHA pinado no texto (`AGENTS.md`, ciclo de trabalho 6).

## Citações que não conferem

`docs/melhorias-status.md:35-35` afirma "`main.gd` 501 linhas" e `[main.gd:30-38](../src/main.gd#L30-L38)` como os sete domínios: confere hoje (`wc -l` = 501), mas é o número que apodrece primeiro (`:399-400` registra o risco). `AGENTS.md` cita `main.gd:486-487` para `state_hash()` (real: `:486-487`), `:435-446` para `diagnostics()` (real: `:435-446`), `:490-498` para a CLI (real: `:490-497`) e `:19-31` como "501 linhas donas de..." (as portas de leitura vão de `:19` a `:46` e `:9-16` traz 8 constantes). `docs/design/06-godot-architecture.md:33` aponta um relógio dentro de `src/core/sim/`, diretório que não existe — o real é `src/core/sim_clock.gd` (47 linhas). `docs/melhorias-status.md:368-368` cita `main.gd:435-447`; o arquivo tem 501 e o `diagnostics()` fecha em `:446`. Nada deste plano foi executado: os números de checagem e de passo vêm do log publicado, não de corrida minha.
