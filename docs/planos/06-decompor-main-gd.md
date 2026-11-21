# 06 — Decompor `src/main.gd` pelo eixo do dono

Plano derivado de leitura; nada foi rodado por mim. Cobre o item 7 de "Falta" (`docs/melhorias-status.md:376-378`) e a linha do prompt "reduza o acoplamento de `main.gd`/`wolf.gd`/memória" (`:53`), cujo veredito publicado é "medir por linhas é proxy, o que importa é o dono único". Regras da casa aplicáveis: anti-bloat e as quatro perguntas (`AGENTS.md`, "Disciplina de otimização") e "generalize no segundo chamador, não no primeiro". O alvo arquitetural nomeia um relógio de simulação em `src/core/sim/` (`docs/design/06-godot-architecture.md:33`), `MindServer` autoload (`:112`), `MindsInspector` e `af-bench` (`:197-199`): nenhuma dessas peças existe em `src/` — `[TARGET]`, legenda em `docs/design/README.md:12`. As faixas abaixo eram da revisão de 501 linhas e foram re-lidas nesta ponta contra os 662 de hoje; nenhuma linha deste plano foi executada.

## Premissa nomeada: ônibus não é dono

`src/main.gd` tem 662 linhas (`wc -l`) e 28 membros (`9-68`: 10 referências de sistema — `world`, `aether`, `clock`, `player`, `viz`, `hud`, `oracle`, `llm_host`, `audio`, `wolves` —, 16 variáveis de controle, 1 `stats` e 1 journal). A premissa que este plano exige e que o código decide: **um bloco só merece virar dono quando já tem comprador fora de `main.gd`.** Medido por grep de chamadas dentro de `src/main.gd` (`hud.` 27 linhas, `player.` 43, `wolves` 31, `world.` 21, `clock.` 13, `tick_journal.` 10, `viz.` 6, `audio.` 5, `oracle.` 3, `_benches` 10, `_respawn_queue` 8, `llm_host` 19, `_pack_*` 23) cruzado com quem alcança estado por sessão em `tests/`: 8 arquivos (`smoke_test.gd` 116 acessos / 18 nomes, `tick_journal_test.gd` 57 / 18, `audio_test.gd` 40 / 11, `llm_server_boot_probe.gd` 18 / 8, `simulation_rng_test.gd` 17 / 11, `live_oracle_probe.gd` 5 / 3, `audio_live_probe.gd` 4 / 2 e `aether_reactions_test.gd`) — e a afirmação de antes, "**zero** em `tests/aether_reactions_test.gd`", não vale mais: ele continua montando mundo, campo e lobos próprios, mas a checagem da alcateia da perna 10 instancia a sessão (`:1320`, `:1431`, `:1480`). Consequência lida: oráculo, visualização e áudio **já têm dono** (`src/ai/mind_oracle.gd:40`, `:45`, `:96-97`; `src/rendering/aether_viz.gd:21-25`, `:40`, `:47`, `:51`; `src/audio/audio_director.gd:104-106`, `:146`, `:158`, `:166`); o que vive no `main.gd` desses três é fiação e cadência, não estado. O estado **sem dono** é a matilha (`:42`) e o trio `_benches` (`:59`), `_respawn_queue` (`:50`) e `_pack_buffers`/`_pack_cursor` (`:63-64`). Não existe `[autoload]` em `project.godot`: hoje todo acesso a subsistema passa por instanciar `src/main.tscn`.

## Inventário honesto (faixa × linhas × de quem é)

| Bloco | `src/main.gd` | Linhas | Dono real hoje |
| --- | --- | --- | --- |
| constantes + membros | `9-68` | 60 | sessão |
| `_ready` (7 nós próprios + 7 pontas de `Callable`) | `71-156` | 86 | sessão |
| host do oracle: start, attach, wire, consulta | `162-203` | 42 | `LlmServerHost` (`src/ai/llm_server_host.gd`) |
| `spawn_point` | `206-209` | 4 | mundo |
| relógios: `_physics_process`, `_sim_tick`, `_process` | `214-258` | 45 | relógio + matilha + Éter + journal |
| input e `respawn` | `261-273` | 13 | sessão |
| matilha: spawn, sorteio, volume, censo, ronda, faina | `278-411` | 134 | **nenhum** (`var wolves: Array` `:42`) |
| ecos do mundo: 10 handlers + `_imprint` + `bench_positions` + 2 toggles | `416-493` | 78 | ônibus (jogador→Éter/HUD/lobo) |
| persistência: `save_game`, `load_game`, `_rebuild_benches`, `stats_line` | `498-589` | 92 | 7 donos num só passo |
| `diagnostics` | `592-607` | 16 | leitura agregada |
| `_build_environment` (sol, céu, neblina) | `612-644` | 33 | recursos do engine |
| `state_hash`, CLI do journal, `_exit_tree` | `647-662` | 16 | journal |

Blocos somam 619 linhas; as 43 restantes são cabeçalho (`1-8`), comentários de seção, docstrings e separadores. Separação de **fato** só existe onde há porta nomeada consumida por terceiros: `targets_under_crosshair()` (`:327-332`) e `wolves_roster()` (`:335-336`) têm quatro portas chamadas na própria sessão (`:109` jogador, `:132` HUD, `:140` oráculo, `:151` áudio), a projeção do hash (`src/persistence/tick_journal.gd:22-27`) e dois compradores de teste (`tests/smoke_test.gd`, `tests/aether_reactions_test.gd` pela porta `pack_of` de `main.gd:343-345`). Nos outros blocos o que existe é tamanho: `_ready` separa por comentário, não por interface.

## Candidatas, da mais barata à mais cara

**K1 — índice de bancadas.** Dono de `_benches` (`:59`), das duas mutações em `_on_block_broken`/`_on_block_placed` (`:433-442`), de `bench_positions()` (`:446-447`) e de `_rebuild_benches()` (`:578-582`): ~18 linhas. Já tem segundo comprador medido: `player.bench_provider` (`:110`) e o load (`:563`). Fica no `main.gd`: a contagem `mined`/`placed` (mesmos handlers, lida por 6 checagens via `main.stats`) e `stats_line`. Prova: `tests/smoke_test.gd:1529,1623,1633,1657,2277` ("bancada tem teto menor que bloco comum", "sem bancada a lista so mostra as de mao", "a cadeia ate a bancada fecha", "vidro na bancada come 2 de areia", "sem bancada so mostra as receitas de mao"); nenhum teste alcança bancada por `main` (censo de nomes acima).

**K2 — fila de respawn e faina de cadáveres.** Dono de `_respawn_queue` (`:50`), `RESPAWN_DELAY`/`CORPSE_CHECK_PERIOD` (`:15-16`), do dreno no passo (`:237-242`) e de `_reap_corpses` (`:401-411`): ~20 linhas. Fica: a mensagem ao HUD (`:242`), porque é decisão de apresentação, e `pending_respawns` do diagnóstico (`:599`) como leitura. Custo: o `hud.show_message` do dreno vira callback do dono ou continua no `main.gd` — `[OPEN]`, decisão do dono. **Nenhuma checagem tem "respawn" no nome** (grep de `_check("` com filtro `respawn` devolve 0), mas a fila já é observada por nome próprio: "cadaver recolhido da matilha" (`tests/smoke_test.gd:2482`) e "reposicao enfileirada" (`:2484`), mais as duas de cadáver (`:2471`, `:2482`) — pré-requisito K2 reduzido a isto: uma checagem que imprima `filas_antes/depois` por faena, que ainda falta.

**K3 — matilha (`[TARGET]`, arquivo novo sob `src/entities/`, nome a definir).** Dono de `wolves` (`:42`), `_next_identity` (`:48`), `_population_rng` (`:49`), `_spawn_wolves` (`:278-297`), `_random_ground_point` (`:300-314`), `_volume_clear` (`:322-324`), das duas portas (`:327-336`), da ronda (`pack_of`/`_rebuild_packs`/`_pack_slot`/`_pack_put` `:343-398`) e de `WOLF_COUNT` (`:9`): ~128 linhas (121 de método `:278-398` + 7 membros/constantes). Fica no `main.gd`: o `var pack` e **os mesmos nomes**, porque `tests/tick_journal_test.gd:78` lê `Main.WOLF_COUNT` da constante do script, `tests/audio_test.gd:288,309` lê `main._population_rng.state`, `tests/simulation_rng_test.gd:87,92,100` chama `_spawn_wolves`/`_volume_clear` e `tests/tick_journal_test.gd:359,363,382` dirige `_sim_tick()` com `process_mode` desligado. Propriedade só-leitura é armadilha lida: `tests/simulation_rng_test.gd:82` **atribui** `session.clock = SimClock.new()`, então getter sem setter quebra teste de propósito. O `audio.on_wolf_registered` dentro do spawn (`main.gd:295-296`) continua atrás do mesmo `if audio != null` — o contrato do RNG (`tests/simulation_rng_test.gd` e as notas do som) não admite som obrigatório no spawn. Prova: `tests/smoke_test.gd:195` ("5 lobos na matilha"), `:212-213` (a colheita das posições de spawn), `:2482` ("cadaver recolhido da matilha"), `tests/audio_test.gd:278` ("cada lobo do spawn entrega seus tres sinais ao diretor"), `tests/simulation_rng_test.gd:87-100` e `tests/tick_journal_test.gd:357-405`.

**K4 — passo de persistência.** Não extrair ainda: `save_game`/`load_game` (`:498-572`) escrevem em 7 donos (`world.generate` `:541`, `apply_edits` `:545`, `aether.from_dict` `:565`, `wolves[i].load_state` `:568`, jogador `:547-556`, `audio.clear_transient` `:564`, `clock.tick`/`elapsed` `:569-570`) e a limpeza de estado volátil no load é contrato publicado (`docs/melhorias-status.md:1045`). O único corte defensável é o dicionário do payload (`:505-521`) para um `SavePayload` com `to_dict()`/`from_dict()` — segundo chamador inexistente hoje, então é `[OPEN]` condicionado a aparecer o 2° consumidor (o save por região do §07). Prova se um dia mover: `tests/smoke_test.gd:2340` ("contador de mortes"), `:2372` ("slot escrito"), `:2433` ("tick restaurado"), `:2438` ("hp do lobo voltou").

## Custo — as quatro perguntas

1. **Frame, tick ou às vezes?** K1 roda no evento do jogador (`:425-442`) e no load (`:563`, `:578-582`); K2 roda 1×/s no tick (`:233-236`) e drena a cada passo (`:237-242`). K3 roda no boot (`:155`) e em lotes de respawn (`:241`), com a ronda reconstruída uma vez por passo (`:230`). K4 é tecla. Nenhuma das quatro coloca código novo em `_physics_process` (`:214-220`) nem no teto de 5 passos (`src/core/sim_clock.gd:19-29`).
2. **Entidades alcançadas?** 5 lobos (`:9`; 4 vivos no fim da corrida publicada, `docs/evidence/bioma-cor-de-pelo/clone-44c9d94-suite.log:309`), 1 jogador, 64 chunks; o censo de `stats_line` (`:585-589`) imprime bancadas e recriacoes, e o diagnóstico publicado fecha com `edits=13` (idem `:310`). Os compradores externos alcançados por K3 são as quatro portas da sessão (`:109`, `:132`, `:140`, `:151`), a projeção do hash e `pack_of` do teste de alcateia.
3. **Aloco no caminho quente?** K1 e K3 não mudam alocação: `_benches` já é `Array[Vector3i]` tipado (`:59`) e `wolves` continua o mesmo objeto em memória — mover o membro não muda o `Dictionary` novo por lobo por tick (`src/entities/wolf.gd:696`), que é débito à parte, nem os buffers da ronda, que já são reescritos no lugar (`src/main.gd:505-520`). O dono novo é 1 `RefCounted` por sessão, alocado no boot.
4. **Como sei que ficou melhor?** Não é otimização, é estrutura: o critério é o censo travado e o passo não piorado (abaixo). O ganho medível declarado é `main.gd` perder N linhas por commit, com N impresso na mensagem.

## Gate headless (comando e critério numérico)

```sh
godot --headless --path . --import
godot --headless --path . --check-only --script src/main.gd
godot --headless --path . tests/smoke_test.tscn
godot --headless --path . --script tests/tick_journal_test.gd
```

Critérios: a última linha do smoke (`tests/smoke_test.gd:184`) continua no censo publicado da
revisão — hoje **237 checagens / 0 falhas / 35,5 s**
(`docs/evidence/bioma-cor-de-pelo/clone-44c9d94-suite.log:312`, nota em
`docs/melhorias-status.md:2221-2274`) — e `dropped_ticks=0` (`:2271-2272`), com `tick=359`.

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
(`docs/melhorias-status.md:1505-1506`).

O contrato do journal trava **128 checagens** (`tests/tick_journal_test.gd:13`) e as 6 linhas de `[tick,hash]` do caminho dirigido por `_sim_tick()` (`:379-394`) têm de bater entre antes e depois do commit: a checagem de repetibilidade **não existe hoje**, então o primeiro passo de K3 roda a suíte duas vezes e publica as sequências; se divergirem na própria árvore antes da mudança, o critério de hash é retirado do gate e fica só censo + `dropped_ticks` + passo. Áudio: **73 checagens** (`tests/audio_test.gd`). Contagem conferida **antes** do lote (`AGENTS.md`, "Nada simulado"): um `SCRIPT ERROR` derruba passos em silêncio.

## O que NÃO fazer

Não reorganizar por gosto: mover `_build_environment` (`:612-644`) para arquivo novo é generalização no primeiro chamador — 1 comprador (`:86`), zero estado, zero teste. Criar autoload sem segundo chamador: não há `[autoload]` em `project.godot` hoje, e cada autoload novo é estado global com dono invisível. Mover estado sem dono: `elapsed` (`:43`) e `stats` (`:44`) não têm comprador fora do `main.gd` além do HUD e do smoke. Esconder o que o `TickJournal` e os testes leem: `world`, `aether`, `wolves`, `clock`, `player`, `stats`, `_population_rng`, `state_hash()`, `diagnostics()`, `tick_journal`, `oracle`, `audio`, `hud`, `_sim_tick`, `_spawn_wolves`, `_volume_clear`, `save_game`, `load_game`, `respawn`, `spawn_point`, `targets_under_crosshair`, `wolves_roster` e `pack_of` continuam alcançáveis por `main` — o plano não redefine o contrato do hash (`docs/melhorias-status.md:836`). E a decomposição **não** fecha o item de autoridade temporal (`:377-378`): jogador, corpos e timers continuam mudando por frame (`src/entities/wolf.gd:804-849`), e isso é o plano 01, não este.

## Checklist de commits atômicos (um assunto, uma corrida)

1. Checagem nova de respawn/cadáver impressa (K2 pré-requisito), produção intocada; censo sobe de
   237 (base `9fe5e45`) para 237+K com K declarado.
2. K1: índice de bancadas com dono; `main.gd` mantém `bench_positions()` como porta.
3. K2: fila e faina com dono; mensagem ao HUD permanece no `main.gd`.
4. K3: dono da matilha; nenhuma linha de `_sim_tick` (`:223-249`) reordenada no mesmo commit.
5. Atualizar `docs/melhorias-status.md` (item 7, débitos de dono, censos de `main.gd:NNN` envelhecidos) e re-derive as citações.
6. Re-medida no clone limpo do SHA final com `--import`, SHA pinado no texto (`AGENTS.md`, ciclo de trabalho 6).

## Citações que não conferem

`docs/melhorias-status.md:53` registra hoje `main.gd` 662 linhas e `wolf.gd` 959 — re-medido nesta ponta com `wc -l`, confere —, mas é o número que apodrece primeiro (`:590` registra o risco e a regra). As faixas deste plano eram da revisão de 501 linhas: `_ready` era `49-125` (real hoje `71-156`), a matilha era `199-263` (hoje `278-411`, porque a ronda e os buffers da perna 10 entraram aí), `diagnostics` era `435-446` (`592-607`) e a CLI do journal era `486-501` (`647-662`). O bloco do hospedeiro do oráculo (`162-203`, 42 linhas) não existia quando o plano foi lido e entrou como linha nova do inventário. `AGENTS.md` cita `main.gd:647-648` para `state_hash()` (real: `:647-648`), `:592-607` para `diagnostics()` (real: `:592-607`) e `:651-658` para a CLI (real: `:651-658`) — os três conferem nesta revisão. `docs/design/06-godot-architecture.md:33` aponta um relógio dentro de `src/core/sim/`, diretório que não existe — o real é `src/core/sim_clock.gd` (47 linhas). Nada deste plano foi executado: os números de checagem e de passo vêm do log publicado, não de corrida minha.
