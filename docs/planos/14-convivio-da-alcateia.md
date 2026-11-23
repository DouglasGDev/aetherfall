# 14 — Convivência da alcateia: terra seca, matilha legível e spawn fora dos olhos

Dossiê de **leitura de código**, não de corrida: nenhuma engine rodou aqui e nenhum número
publicado foi re-medido por este arquivo. Autorização do dono em 2026-11-20
([`AGENTS.md`](../../AGENTS.md), extensão (2); agente `convivio-14`, branch
`feat/alcateia-convivio-14`), nas palavras dele: rondar pelos blocos de terra com a água como
último recurso; "regras pra não parecer que tá desorganizado"; "nada de avisos na tela,
simplesmente o player tem que achar, ver"; "nunca spawnar na frente do player, sempre numa
distancia segura". Terceira da fila 09 → 10 → **14** → 11 → 12 → 13: depois da 10 porque mexe nas
mesmas folhas de movimento que a alcateia reorganizou; antes da 11 porque o predicado "longe dos
olhos do jogador" tem de existir antes de alguém precisar dele para pôr um filhote no mundo.
Citações contra a `main` em `eb6ec8d`; a árvore de trabalho já trazia a 10 em curso (§2).

## 1. Premissas nomeadas

1. **Seco é regra de escolha de alvo.** Havendo coluna seca a ≤ 8 m do alvo que a árvore elegeu, o
   alvo com que o tick termina é seco — nenhum lobo nada quando há saída em seco. Direção oposta
   obrigatória (ciclo 3): sem saída no anel, o lobo **tem** de nadar e ainda avançar.
2. **Organizado é número, não adjetivo.** Com 5 lobos e um rastro, ficam sob tetos impressos os
   ticks com **dois** lobos mirando a mesma célula de Éter e as trocas de `_move_target` por lobo por
   segundo. Vermelho por ausência: hoje cinco corpos podem parar no mesmo ponto.
3. **Presença de criatura não vira texto.** Em 900 ticks nenhuma string de presença ou destino de
   criatura chega ao toast, e o feedback da ação do próprio jogador continua chegando. **Nasce
   vermelha**: `main.gd:242` e `:511` daquela ponta — os dois letreiros — existem.
   *(Entregue: os dois saíram da tela. A fila de respawn é hoje só o comentário em
   [main.gd:283-291](../../src/main.gd#L283-L291) e a morte imprime apenas o contador em
   [`_on_wolf_died`](../../src/main.gd#L969-L974).)*
4. **Spawn não aparece na frente do jogador.** Criar lobo (boot [main.gd:196](../../src/main.gd#L196),
   fila [:291](../../src/main.gd#L291)) a menos de `SAFE_SPAWN_DIST` do jogador ou com LOS
   livre do olho até o ponto não o coloca ali, e a recusa é impressa — nunca revertida em silêncio ao
   centro. **Nasce vermelha por construção**: na ponta do dossiê, `_random_ground_point`
   (`main.gd:301-315` de `eb6ec8d`) não menciona o jogador em nenhuma linha.
   *(Entregue: quem sorteia é [`_spawn_home_point`](../../src/main.gd#L735-L807) sobre as
   [`SPAWN_BANDS`](../../src/main.gd#L497), e cada candidata passa antes por
   [`_spawn_point_ok`](../../src/main.gd#L709-L714) — distância e visada contra o olho do jogador;
   a recusa conta os motivos e imprime "spawn RECUSADO:" em
   [:792-794](../../src/main.gd#L792-L794), sem fallback para o centro.)*

## 2. Estado real do código (lido, não medido)

- **A água tem três peças e uma delas mente.**
  [`_leaf_wander`](../../src/entities/wolf.gd#L583-L605) sorteia até 8 pontos secos a 5–22 m
  (`continue` se `not _dry_ground`, [`:648-652`](../../src/entities/wolf.gd#L648-L652), que lê a
  superfície **atual**); [`_shore_point`](../../src/entities/wolf.gd#L656-L666) varre 5 raios
  (1,6→8 m) × 8 direções; [`sim_step`](../../src/entities/wolf.gd#L825-L836) acumula `_swim_time` em
  `dt` — já tick-based (`SHORE_AFTER` 2,0 s = 40 passos, [:108](../../src/entities/wolf.gd#L108)).
  **Achado:** o comentário `:454-455` jura que a margem manda "acima de qualquer outra intenção da
  árvore", mas a atribuição em [`:742`](../../src/entities/wolf.gd#L742) roda **antes** de
  `_sense`/`_think`/`_tree.tick` ([:838-842](../../src/entities/wolf.gd#L838-L842)) e é sobrescrita
  por qualquer folha com alvo — inclusive na 10 em curso, que só acrescentou `_read_pack()`.
- **Quatro folhas sem teste de solo:** [`_leaf_flee`](../../src/entities/wolf.gd#L421-L441),
  [`_leaf_chase`](../../src/entities/wolf.gd#L444-L462),
  [`_leaf_stalk`](../../src/entities/wolf.gd#L495-L505),
  [`_leaf_investigate`](../../src/entities/wolf.gd#L508-L536) → `_scent_pos` de
  [`_find_scent`](../../src/entities/wolf.gd#L890-L930) com o chão de
  [`_scent_ground_y`](../../src/entities/wolf.gd#L937-L945). O corpo já nada: `SWIM_SPEED_FACTOR`
  [:977](../../src/entities/wolf.gd#L977), flutuabilidade `:760-766`, remo `:815-826`, e o
  `feet_pos.y < -6,0` → `home` [:994-996](../../src/entities/wolf.gd#L994-L996).
- **Spawn seco, desencaixado e indiferente ao jogador.** `spawn_point()` é a **coluna central**
  ([`:247-250`](../../src/main.gd#L247-L250)) — onde o próprio jogador é posto
  ([`:149`](../../src/main.gd#L149)) — e o anel 16–46 m gira em torno **dele**
  ([`:330`](../../src/main.gd#L330)), exigindo `y > SEA_LEVEL` (26,
  [voxel_config.gd:13](../../src/world/voxel_config.gd#L13)) e volume inteiro livre
  ([`_volume_clear`](../../src/main.gd#L808-L810): encaixado, o corpo congela — diz o comentário);
  após 24 tentativas cai **em silêncio** no centro ([`:388-389`](../../src/main.gd#L388-L389)), o
  pior ponto possível num 128×128 ([`:10-11`](../../src/world/voxel_config.gd#L10-L11)) com margem
  sobrando. O `load` põe o jogador onde estava ([`:1065`](../../src/main.gd#L1065)) e a matilha segue
  no centro fixo. [`line_of_sight`](../../src/world/voxel_world.gd#L442-L448) (DDA) só é lida pelo
  portão de 30 m da percepção ([wolf.gd:852](../../src/entities/wolf.gd#L852)) — nunca no spawn.
- **Dois tipos de aviso numa fila só**
  ([`show_message`](../../src/ui/hud.gd#L154-L157), fade `:212-214`): anúncio de criatura —
  [main.gd:277](../../src/main.gd#L277) e `:853` (dispara para **qualquer** morte, vista ou não) — e
  feedback/diagnóstico: boot `:107`, morte do jogador `:194`, `player.notice` →
  [`_on_notice`](../../src/main.gd#L938-L939) (emissores
  [player.gd:309](../../src/entities/player.gd#L309)/[:682](../../src/entities/player.gd#L682)/[:700](../../src/entities/player.gd#L700)),
  save/load `:377`/`:379`/`:385`/`:389`/`:425`, craft [hud.gd:603](../../src/ui/hud.gd#L603)/`:605`.
- **O que substitui o texto, lido e não assumido:** passos posicionais
  ([`_wolves_stride`](../../src/audio/audio_director.gd#L495-L508)), latido ≤ 14 m em `hunt` e uivo
  com cooldown global de 18 s ([`_vocalize`](../../src/audio/audio_director.gd#L513-L531);
  `BARK_RANGE`/`HOWL_COOLDOWN`/alcance 64 m [:26-44](../../src/audio/audio_director.gd#L26-L44)),
  sfx espacializado de mordida/dano/morte (`:404-413`), BLOOD 1,1 + FEAR 0,55 do
  [`die()`](../../src/entities/wolf.gd#L1051-L1062) (lidos por qualquer nariz, vistos no F4) e o
  cadáver por 6 s ([wolf.gd:40](../../src/entities/wolf.gd#L40)) até a recolha de 1 s
  ([`_reap_corpses`](../../src/main.gd#L887-L907)). Roster e narrativa só com F3.
- **A 10 em curso é fronteira, não concorrente:** `pack_provider` no lobo,
  `PACK_COHESION_RADIUS` 24, `_rebuild_packs()` uma vez por passo e `pack` já no contexto do
  escorredor e do `_tree.tick`. Nenhum item do §3 reabre isso; o filtro de alvo entra **depois** do
  `_tree.tick`, que é onde a 10 escreve `_move_target`.
- **Sítios que tratam censo/spawn como fixos:**
  [smoke_test.gd:200-201](../../tests/smoke_test.gd#L200-L201), posições indexadas `:217-218` e
  `:204-208`, recolha/fila [`:2511-2540`](../../tests/smoke_test.gd#L2511-L2540), o lago do passo de
  nado [`:1747-1769`](../../tests/smoke_test.gd#L1747-L1769) com `patrulha so sorteia terra seca`
  `:1725` e `lobo preso busca a margem` `:1741`;
  [tick_journal_test.gd:77-79](../../tests/tick_journal_test.gd#L77-L79) (`== WOLF_COUNT`);
  [audio_test.gd:422-424](../../tests/audio_test.gd#L422-L424); e
  [simulation_rng_test.gd:87-102](../../tests/simulation_rng_test.gd#L87-L102), que chama
  `_spawn_wolves` **fora da árvore**, exige `valid == 5` e assinatura estável — é o primeiro a cair
  se a política de spawn consumir `_population_rng` de jeito diferente por braço ou deixar de criar
  os cinco.
- **Deriva de citação:** o contrato apontava o blackboard para `wolf.gd:553`, fim de
  `_build_scorer`; re-ancorado, hoje é **um** `Dictionary` por lobo por tick, na chamada da
  árvore ([`wolf.gd:842`](../../src/entities/wolf.gd#L842)) e no `_breakdown` do escorredor ([`utility_scorer.gd:76`](../../src/ai/utility_scorer.gd#L76)).
  `EXPECTED_CHECKS` é [`:39`](../../tests/aether_reactions_test.gd#L39) (150 na leitura deste dossiê) e os
  30 cenários vão de [`:8-29`](../../tests/aether_reactions_test.gd#L8-L29).

## 3. O que a peça exige

1. **Um filtro de validade de alvo, depois da árvore.** No fim de `sim_step`, após
   `_tree.tick(...)`: `_resolve_dry_target()` testa `_dry_ground(_move_target)`; se molhado,
   `_shore_point()` substitui; sem saída no anel o alvo molhado fica e o nado segue o caminho que já
   existe. Alternativas recusadas: nas folhas seriam cinco cópias (e a quinta já acerta); no
   escorredor é erro de camada — a histerese `min_lead`/`min_interval`
   ([:734-735](../../src/entities/wolf.gd#L734-L735)) decide **intenção**, não geometria, e "a caça
   está encharcada" não pode trocar `hunt` por `patrol`. Efeito colateral obrigatório: o filtro
   cumpre a supremacia que `:454-455` promete.
2. **Nado como último recurso, compromisso em tick.** `SHORE_AFTER` vira piso do estado ensopado,
   não porta de tudo: o filtro roda todo tick, mas o **rumo de travessia** só re-escolhe na cadência
   do nariz (`SCENT_PERIOD` 0,25 s = 5 passos) ou quando muda de folha — re-escolher a cada 50 ms é
   exatamente o "parece desorganizado" do pedido. Nada de `Time.get_ticks_*`.
3. **Ordem sem invadir a 10.** Da 10 são, e não se reabre: assentos angulares do anel de mordida,
   escalonamento por `_bite_cd`, `pack_provider`, território compartilhado, contágio. Sobram: (i)
   `_scent_pos` é o **centro da célula** ([`:929-930`](../../src/entities/wolf.gd#L929-L930)) — N
   lobos no mesmo rastro recebem o mesmo ponto; quem chega primeiro mantém, os demais param em offset
   determinístico por `identity` fora da célula (4 blocos,
   [voxel_config.gd:16](../../src/world/voxel_config.gd#L16)); (ii) **alvo estável** sob teto de
   trocas por segundo; (iii) **lares em colunas diferentes** enquanto a 10 não fundir o `home` em
   território.
4. **Higiene de spawn em uma função, dois compradores.** `_spawn_point_ok(p)` em `main.gd`:
   `p.distance_squared_to(player.position3()) >= SAFE_SPAWN_DIST²` **e** `not
   line_of_sight(player.eye_position(), p + Vector3(0, Wolf.DIMS.y * 0.5, 0))`
   ([eye_position, player.gd:203-204](../../src/entities/player.gd#L203-L204)). `SAFE_SPAWN_DIST`
   **proposto** 32 m, com o motivo impresso: acima do portão de 30 m em que o lobo já consulta LOS,
   acima dos 14 m de latido, dentro dos 46 m do anel para que um ponto conforme exista normalmente.
   Sem cone de câmera: "não visível" é estritamente mais forte que "não na frente" e custa uma DDA.
   A 11 é a segunda compradora — o filhote nasce por esta mesma função.
5. **Recusa que não mente.** O retorno silencioso ao centro é o fallback que o mandato 1 proíbe.
   Busca em **bandas** determinísticas (16–46, 46–70, até a borda), banda e motivo impressos; se
   todas falharem o lobo **não nasce agora** — volta à fila com o motivo no log, o censo passa a ser
   `wolves.size() <= WOLF_COUNT`, e os sítios do §2 viram invariante no mesmo commit, anunciados
   antes de escrever.
6. **Política de aviso como classificação.** Saem só as duas chamadas de anúncio de criatura; ficam
   notice de inventário/slot, craft, save/load, boot e respawn do jogador.
   `stats["wolves_felled"]` ([`:974`](../../src/main.gd#L974)) continua contando: sai o texto, não o
   fato.

## 4. Custo — as quatro perguntas

- **Frame, tick ou às vezes?** Filtro: **tick de 20 Hz**, uma pergunta por lobo vivo (100/s), dentro
  de `begin_step`/`end_step` ([main.gd:259-261](../../src/main.gd#L259-L261)) e **fora** dos 400 µs
  do `SubtreeGuard` ([`:389-390`](../../src/entities/wolf.gd#L389-L390)) — o custo novo sai no
  `sim_step` do runner, não no `last_us`. Re-escolha de travessia: 4×/s. Offset de célula: só na
  folha de investigação. Higiene de spawn: **rara** — 5 no boot, 1 por fila de 45 s
  ([main.gd:30](../../src/main.gd#L30)).
- **Barato × caro.** Barato para todo tick: `_dry_ground` (uma `surface_height` + uma leitura de
  água) e a distância ao quadrado. **Caro demais para todo tick:** `line_of_sight` (DDA de até 46
  blocos), que por isso vive só no caminho de spawn, e o anel de `_shore_point` (até 40
  `_dry_ground`), que só roda no ramo molhado. A ablação dos rastros mediu que trocar
  `surface_height` pela busca na camada move o total em −1,8 % (ruído): 1 chamada/tick não é o
  problema; 40 × 100/s seria.
- **Quantas entidades?** 5 lobos (até o censo da 11), 1 jogador, 64 chunks. Nenhuma varredura de
  mapa: o teste é sobre o alvo, um ponto.
- **Aloco no caminho quente?** Não: lê e reatribui um `Vector3` por valor, sobre o `_move_target` que
  a 10 já escreve. O débito continua sendo os dicionários `:430`/`:460` e o `PackedInt32Array` por
  canal por passada ([aether_field.gd:122](../../src/world/aether_field.gd#L122)); se este lote
  acrescentar alocação, a checagem 8 do §5 pega.

## 5. Gate em headless

```sh
godot --headless --path . --import
godot --headless --path . --check-only --script src/entities/wolf.gd
godot --headless --path . tests/smoke_test.tscn
```

Cenários novos no runner dedicado, sobre `_arm`/`_advance` já existentes
([`:264-288`](../../tests/aether_reactions_test.gd#L264-L288)):

1. **`lobo_escolhe_trilha_seca`** — alvo molhado com margem seca a < 8 m, 200 passos:
   `ticks_com_alvo_molhado_final == 0`, com a distância à margem. **Nasce vermelha.**
2. **`nadar_so_sem_saida_seca`** — o mesmo lobo no lago mais fundo da seed: nada e avança > 1,2 m.
   Segundo sentido da atribuição: o conserto tem de ser indiferente a esse estado.
3. **`resgate_de_margem_sobrevive_a_arvore`** — `hunt` com alvo visível e `_swim_time > SHORE_AFTER`:
   o alvo do último passo é seco; imprime `intent` e alvo.
4. **`dois_lobos_nao_farejam_a_mesma_celula`** — máximo de lobos com `_move_target` na mesma célula
   por tick, sob teto declarado; imprime o pior tick.
5. **`alvo_estavel_por_segundo`** — trocas de `_move_target` por lobo por segundo de lógica; imprime
   média e pior lobo.
6. **`spawn_fora_da_vista_do_jogador`** — pela transição real (matar lobo e esvaziar
   `_respawn_queue`, não escrever campo na mão): casa nova a ≥ `SAFE_SPAWN_DIST` e sem LOS do olho;
   imprime distância e LOS. **Nasce vermelha por construção.**
7. **`nenhum_aviso_de_matilha_no_hud`** — 900 ticks com boot, respawn e mortes: o toast nunca carrega
   string de criatura; imprime o conjunto visto.
8. **`feedback_do_jogador_continua_no_hud`** — par obrigatório do 7: inventário cheio, slot vazio,
   craft e save/load seguem chegando. Sem ela, o 7 é remoção silenciosa de feedback.
9. **`convivio_nao_estoura_orcamento`** — `trips == 0` **e** o rodapé de `sim_step`/`_bt_us`
   ([`:3097-3098`](../../tests/aether_reactions_test.gd#L3097-L3098)) na banda da revisão; nenhuma
   banda absoluta se publica aqui — µs não transferem de janela e a medição é serial.

`EXPECTED_CHECKS` (119), os censores irmãos (audio 73, simulation_rng 27, journal 128) e o rodapé da
suíte (237, [README.md:192](../../README.md#L192)) sobem com o lote e só viram número **publicado**
re-medidos em clone limpo do commit com `--import` frio, SHA pino no texto e `git ls-remote --heads
origin` conferido.

## 6. O que NÃO fazer

- Nenhum `PackState`, `Alcateia`, autoload ou `.tres`: a matilha é de `main.gd`; mover posse é 06.
- Nenhuma varredura de água do mapa por frame ou por tick: o teste é sobre **o alvo**.
- Nenhum `if` de geometria dentro do escorredor brigando com a histerese — ela decide intenção, o
  filtro decide ponto.
- Não remover toast que é a única resposta a uma ação do jogador (inventário, slot, craft, save/load).
- Higiene de spawn não é teleporte: mover um lobo que o jogador já viu para "cumprir" a distância é a
  mentira mais cara possível; o `y < -6,0` → `home` não é mecanismo de discrição.
- Nada de `Time.get_ticks_*` para tempo na água, cooldown de travessia ou cadência de re-escolha.
- Nenhum fallback silencioso que reporte sucesso — nem o do centro, nem um "finge que achou seco".
- Não aproximar o `home` do jogador "para a matilha aparecer": é o oposto exato do pedido.

## 7. Commits atômicos

Branch `feat/alcateia-convivio-14`, base `main`, merge `--no-ff`, suíte verde entre eles:
(a) `_resolve_dry_target()` pós-árvore com 1 e 3 — a 1 **vermelha** e o número do vermelho no commit;
(b) compromisso de travessia em tick com 2; (c) offset determinístico de célula de rastro e lares
separados com 4 e 5; (d) `SAFE_SPAWN_DIST`, predicado e bandas com recusa impressa com 6, convertendo
os sítios de censo a invariante no mesmo commit; (e) política de aviso: as duas remoções com 7 e 8;
(f) re-derivação das citações velhas (inclusive as do contrato), status e `README.md` com o número do
clone limpo.

## 8. O que este dossiê não fecha

Nenhum gate de fase (mandato 4): P0/P1 seguem abertos, `MindsInspector` não existe (08), o HOT
agregado dos cinco lobos segue sem medição (04) e a difusão segue síncrona (05). Devolve à **10**
toda coordenação de ataque (assentos, escalonamento de mordida, contágio, território) — se ela fundir
os `home` em território, a exigência 3.(iii) morre por obsolescência, não por falha. Entrega à **11**
o `_spawn_point_ok` com dois compradores e o censo como invariante. Para a **12**, o cavar é folha da
árvore montada e um túnel seco pode ser o ponto válido do filtro — nada aqui decide o custo de malhar
isso. Escada de nível e parentesco ficam na **13**.
