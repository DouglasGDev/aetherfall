# Rodada convivência (dossiê 14) — o que foi lido, com o log de cada número

Motor Godot 4.7.2-stable (`ed1daf0bf`), binário `.tools/Godot_v4.7.2-stable_win64_console.exe`, md5
`daf6bba3d9c99634f146e220ce4de160` conferido nesta sessão. `.tools/` está no `.gitignore`, então
**nenhum destes logs existe num clone recém-baixado** — os arquivos deste diretório são a cópia
publicada, e `artifacts.sha256` (45 entradas) fecha sobre elas.

Árvore atual: `src` = `3eb42835a0e1f54086937d63258388f52e1db932`, `tests` =
`8b8a5e471d737d6474eb6171bab6fdbeec75c06a`. Base da branch: `a898fb2` (ponta da `main` na abertura da
perna), com `src` = `1177048d5f1c1f8068e356c30b6b8e4ca8d6f12c`, `tests` =
`8a04330bcbf91c5ac58709fef9b7c7b8c9dad60e`. Seções 1 a 5 são **árvore de trabalho**; o clone limpo
está na **seção 6**.

Nenhum exit code foi gravado nestes logs. O contrato lido é a última linha de cada corrida (`N
checagens M falhas T s` no runner, `== N checagens M falhas T s de teste ==` na suíte) e a contagem
de `SCRIPT ERROR`, que é **0 nos 45 arquivos**. Do corpus: **38** logs terminam com `0 falhas`, **6**
trazem a falha impressa (as vermelhas do §2) e um — `f_clone-import.log` — não tem contagem porque é
o `--import`. A contagem se confere **antes** de qualquer lote (mandato 1): nenhuma corrida aqui
perdeu checagens em silêncio.

## 1. A escada de contagem, com o log de cada degrau

A suíte ficou em **246 checagens** do começo ao fim da perna: as 33 checagens novas da convivência
nasceram no runner de reações, e o degrau (f) mudou uma **asserção** da suíte, não o censo dela. O
teto declarado em código é `EXPECTED_CHECKS`
([tests/aether_reactions_test.gd:25](../../../tests/aether_reactions_test.gd#L25)), de **150** em
`a898fb2` para **183** na ponta.

| degrau | commit | runner (censo / falhas) | log do runner | suíte | log da suíte |
| --- | --- | --- | --- | --- | --- |
| base da perna | `a898fb2` | `150 / 0` | `base_reactions.log` | `246 / 0 / 37,4 s` | `base_smoke.log` |
| (a) filtro de alvo depois da árvore | `28afdda` | `160 / 5` → `160 / 0` | `a_red_reactions.log`, `a_green_reactions.log` | `246 / 0 / 37,0 s` | `a_smoke.log` |
| (b) travessia comprometida, 4 re-escolhas/s | `5c3cde0` | `165 / 3` → `165 / 0` | `b_red_reactions.log`, `b_green_reactions.log` | `246 / 0 / 36,9 s` | `b_smoke.log` |
| (c) assento de célula e lares em colunas distintas | `b65066f` | `172 / 2` → `172 / 0` → `173 / 0` | `c_red_reactions.log`, `c_green_try1_reactions.log`, `c_green_reactions.log` | `246 / 0 / 37,0 s` | `c_smoke.log` |
| (d) spawn em bandas com recusa impressa | `9fa8c6c` | `177 / 2` → `177 / 0` | `d_red.log`, `d_green.log` | `246 / 0 / 37,1 s` | `d_smoke.log` |
| (e) nenhuma frase de criatura no toast | `ba99bee` | `183 / 1` → `183 / 0` ×2 | `e_red.log`, `e_green.log`, `e_green2.log` | `246 / 0 / 37,0 s` e `37,6 s` | `e_smoke.log`, `e_smoke2.log` |
| (f) mordaca de matilha no lar do recém-chegado | `6e35b64` | `183 / 0` | `f_aether_reactions.log` | `246 / 1` → `246 / 0 / 37,2 s` | `f_red.log`, `f_smoke.log` |

Irmãos, verdes em todos os degraus: `*_audio*` **73 checagens**, `*_simulation_rng*` **27**,
`*_tick_journal*` **128** / `7/7 testes concluidos`.

## 2. As vermelhas, e o que cada uma decidiu

Nenhuma falha abaixo é de ambiente: todas têm `SCRIPT ERROR` 0, a checagem nomeia a premissa, e o par
verde está no log do degrau seguinte.

**(a) `28afdda` — o filtro não pode mentir.** `a_red_reactions.log:156-164` devolve
`molhados=106/200`, `in_water=true ticks_corpo_na_agua=164/200`, `molhados=123/200 saida_ainda=-1.0`,
`resgate_de_margem_sobrevive_a_arvore | intent=hunt alvo=(66.0, 51.401, 62.0) seco=false` e
`molhados=116/121 ensopados`. Cinco falhas da mesma premissa: o alvo escrito pela árvore terminava o
passo dentro d'água mesmo com terra a 10,5 m. Verde em `a_green_reactions.log`, com a direção oposta
também impressa — `o nado so acontece onde nao ha saida (o filtro nao mente) |
alvos_molhados_sem_saida=123 com_saida=0/200 terra_real=10.5 m` e, no cenário forçado sem saída,
`sem saida o corpo avanca nadando | deslocamento=4.79 m (> 1,2 m)`. O filtro está **depois** da
árvore (`_resolve_dry_target()`, [src/entities/wolf.gd:566-570](../../../src/entities/wolf.gd#L566-L570),
chamado em [:697](../../../src/entities/wolf.gd#L697), fora dos 400 µs do `SubtreeGuard`), então o
cado não copiou o teste de solo para dentro de cada folha, e o nado continua alcançável quando não há
saída.

**(b) `5c3cde0` — cadência, não adjetivo.** `b_red_reactions.log:165` →
`reescolhas=185 em 10.0 s de cauda = 0.93 por passo de 20 Hz (18.5/s, teto declarado 5/s)`: o rumo de
saída da água era re-escolhido **todo passo**. As outras duas do lote (`:172-173`) são
`trips_solo=3` — o `SubtreeGuard` de 400 µs estourando porque o trabalho estava **dentro** da árvore
— e `censo de checagens | 165/164`, o teto que ainda não tinha sido declarado em código. Verde em
`b_green_reactions.log`: `reescolhas=33 … = 0.17 por passo (3.3/s, teto declarado 5/s)` e
`trips_solo=0`. O compromisso mora em `_demand_shore()`
([:545-556](../../../src/entities/wolf.gd#L545-L556)) na cadência do nariz, e o resgate por tempo de
nado (`SHORE_AFTER` [:79](../../../src/entities/wolf.gd#L79), aplicado em
[:686](../../../src/entities/wolf.gd#L686)) continua como última linha.

**(c) `b65066f` — "organizado" é número.** `c_red_reactions.log:171-172` →
`pior=4 lobos na celula (16, 12, 15) (teto 1) … alvos_fora_da_celula=0` e `pior_cluster=4 alvos a
<= 1,0 m entre si (teto 1)`: quatro corpos podem terminar o tick mirando a mesma célula de Éter e o
mesmo ponto de chegada, porque o sorteio de lar não olhava coluna. O primeiro verde (`c_green_try1`)
deu `172/172`; a corrida seguinte acrescentou a checagem que conta os alvos **fora** da célula e deu
`173/173` com `pior=1 … alvos_fora_da_celula=282` e `pior_cluster=1`. Ou seja: o teto é cumprido sem
que a matilha congele num ponto — 282 passos com alvos distintos.

**(d) `9fa8c6c` — nenhum lobo nasce na frente do jogador.** `d_red.log:179-181` →
`seguro=32 m dentro=1 visiveis=3 de 5 | lobo0=44.4m lobo1=16.8m los=true lobo2=46.1m lobo3=36.5m
los=true lobo4=33.0m los=true` e `dist=25.9 m seguro=32 los=true`. Um lar a 16,8 m com visada livre é
exatamente o que o dono vetou. Verde em `d_green.log`: `dentro=0 visiveis=0 de 5`, os cinco lares
entre 35,7 e 46,1 m com `los=false`, e o reposto a `dist=39.3 m … los=false`. A recusa é impressa por
motivo e contada ([`_spawn_point_ok`](../../../src/main.gd#L361-L366),
[`_spawn_home_point`](../../../src/main.gd#L385-L436), a linha `"spawn RECUSADO: "` em
[:435](../../../src/main.gd#L435)) — **não** existe fallback mudo para o centro.

**(e) `ba99bee` — presença de criatura não vira texto.** `e_red.log:246` →
`de_criatura=2 ['o lobo caiu  o sangue fica no eter' 'uma nova matilha entrou no vale'] | visto:
'o lobo caiu  o sangue fica no eter'@121 'uma nova matilha entrou no vale'@1161`. Verde em
`e_green.log`: `de_criatura=0 []`, e a checagem do degrau vizinho garante que o outro lado continua
vivo — `os dois caminhos de criatura rodaram dentro da janela | abatidos=5 repostos=1 passos=1161`.
O feedback da ação do próprio jogador não foi tocado.

**(f) `6e35b64` — a alcateia existe na sessão real (furo #16).** `f_red.log:30` →
`[FAIL] alcateia existe na sessao real  pares=10  esperado=10  maior_matilha_lida=1 lobos_vivos=5
vizinhos=[lobo0(1 viz) lobo1(1 viz) lobo2(0 viz) lobo3(1 viz) lobo4(1 viz)]`. Cinco lares aceitos,
todos ≥ 32 m, e nenhum lobo com dois vizinhos: o cercou, o contágio e a ronda por setor estavam
provados em fixture, não no vale. Verde em `f_smoke.log` → `maior_matilha_lida=4 lobos_vivos=5`,
`lobo0(4 viz) … lobo4(3 viz)`, com a asserção `biggest >= 2` já no lugar
([tests/smoke_test.gd:263-266](../../../tests/smoke_test.gd#L263-L266)). O que mudou o número não foi
o raio de coesão, foi a **mordaca de 18 m sobre o lar de um irmão vivo**
(`PACK_LEASH` [src/main.gd:345](../../../src/main.gd#L345), lida em
[:350](../../../src/main.gd#L350)): o recém-chegado nasce perto de alguém, não perto do centro.

## 3. O censo da sessão real, medido na suíte

O `diagnostico final` é a mesma linha em todos os onze arquivos de suíte: `wolves_alive=4`,
`pack_pairs=6`, `pending_respawns=1`, `dropped_ticks=0` — com a checagem da matilha lendo
`lobos_vivos=5` (`pares=10 = 5·4/2`). Os cinco lares aceitos impressos no boot de `f_smoke.log` e de
`f_clone-suite.log`, literais e idênticos entre os dois:

```
spawn banda 1 (16-46 m de jogador): lar aceito a 48.3 m do jogador
spawn mordaca (4-18 m de irmao): lar aceito a 50.4 m do jogador
spawn mordaca (4-18 m de irmao): lar aceito a 42.5 m do jogador
spawn mordaca (4-18 m de irmao): lar aceito a 55.1 m do jogador
spawn mordaca (4-18 m de irmao): lar aceito a 51.6 m do jogador
```

Distâncias: **42,5 a 55,1 m**, todas acima de `SAFE_SPAWN_DIST = 32 m`, e `spawn RECUSADO` **zero**
vezes em cada um dos dois arquivos. O jogo e a suíte partilham a semente (`SEED := 20261116` em
[src/main.gd:16](../../../src/main.gd#L16) e [tests/smoke_test.gd:10](../../../tests/smoke_test.gd#L10)),
então os lares do boot no jogo são estes cinco pontos. Nada disso aparece na tela por ordem do dono —
o observável é o F3, que imprime uma linha por lobo
([src/ui/hud.gd:273-280](../../../src/ui/hud.gd#L273-L280)).

Existe um caminho de código que produz "nenhum lobo no vale": se o `_spawn_home_point` do boot
recusar, a vaga vai para a fila ([src/main.gd:303](../../../src/main.gd#L303)) e só volta com
`RESPAWN_DELAY`. Nas duas corridas de suíte desta perna isso **não** aconteceu (zero recusas), e o
número de lares aceitos é 5 = `WOLF_COUNT`. Fica registrado como risco conhecido, não como defeito
reproduzido.

## 4. µs: declarados não-gate, e **não comparáveis** entre degraus

A contagem de passos do cenário estreito **mudou** dentro da perna: `2 770` na base, `3 333` no
degrau (a), `3 735` de (b) em diante — porque o cenário passou a rodar as novas cadências. Somar
µs sobre janelas de passos diferentes não mede custo. A coluna de passos está aqui para isso.

| log | passos | `sim_step` total / pico | BT soma / pico / trips | passos de matilha · total · pico |
| --- | --- | --- | --- | --- |
| `base_reactions.log` | 2 770 | 380 762 / 694 µs | 15 583 / 201 / 0 | 122 · 167 956 · 8 191 |
| `a_green_reactions.log` | 3 333 | 654 509 / 1 228 | 22 250 / 184 / 0 | 122 · 172 973 · 8 046 |
| `b_green_reactions.log` | 3 735 | 1 044 201 / 3 793 | 21 336 / 217 / 0 | 122 · 173 092 · 8 397 |
| `c_green_reactions.log` | 3 735 | 1 011 848 / 4 061 | 21 666 / 179 / 0 | 673 · 1 141 414 · 9 304 |
| `d_green.log` | 3 735 | 1 009 298 / 3 721 | 21 773 / 175 / 0 | 673 · 1 145 115 · 10 104 |
| `e_green.log` | 3 735 | 1 029 107 / 4 098 | 22 922 / 198 / 0 | idem acima |
| `f_aether_reactions.log` | 3 735 | 1 021 571 / 3 279 | 21 992 / 180 / 0 | idem acima |

O que dá comparar é o **mesmo degrau com a mesma janela**: de (b) a (f), cinco braços com 3 735
passos dão 1 009 298 a 1 044 201 µs (±3,5 %), e o pico de BT fica entre 175 e 218 µs contra o teto
declarado de 400 µs por lobo — com `trips=0` em todas as corridas, inclusive as vermelhas. O
`sim_step` integral e os passos de matilha continuam **[NAO GATE P1]**, como impresso no próprio
log, e nada aqui fecha o budget agregado dos cinco lobos (a colheita mede um lobo por cenário, e o
`SubtreeGuard` cronometra a árvore, não percepção nem utilidade).

## 5. Boot, medido em cada degrau

Os números que a regra de boot cobra, lidos do `diagnostico final` de cada suíte:

| log | `gen_ms` | `mesh_ms` | `worst_sim_ms` |
| --- | --- | --- | --- |
| `base_smoke.log` | 939,384 | 4 308,677 | 11,057 |
| `a_smoke.log` | 928,326 | 4 242,176 | 12,791 |
| `b_smoke.log` | 927,751 | 4 225,541 | 11,927 |
| `c_smoke.log` | 932,633 | 4 272,941 | 11,452 |
| `d_smoke.log` | 949,223 | 4 282,090 | 10,338 |
| `e_smoke.log` / `e_smoke2.log` | 928,166 / 940,761 | 4 307,539 / 4 621,729 | 10,807 / 11,169 |
| `f_smoke.log` | 940,939 | 4 428,586 | 11,610 |
| `f_clone-suite.log` | 933,136 | 4 300,714 | 11,360 |

Geração estável (927,8–949,2 ms) e malharia em 4 225–4 622 ms, mesma família das medições históricas
(4 640–4 886 ms antes do índice linear; 4 300 ms no clone da perna 10). Nenhum degrau desta perna
mexe no mesher nem no gerador: o que se está conferindo aqui é que a convivência **não** encareceu o
boot, e ela não encareceu. `dropped_ticks = 0` em todas.

## 6. O clone limpo da ponta, com `--import` frio

Comando e revisão, na ordem em que rodaram (caminhos literais desta máquina):

```sh
git clone --no-hardlinks C:/Aetherfall C:/tmp/af14-clone
git -C C:/tmp/af14-clone checkout 6e35b64
C:/Aetherfall/.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path C:/tmp/af14-clone --import
C:/Aetherfall/.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path C:/tmp/af14-clone tests/smoke_test.tscn
```

| passo | resultado | log |
| --- | --- | --- |
| `--import` frio | exit **0**, `[ DONE ] loading_editor_layout` no fim, zero `SCRIPT ERROR` | `f_clone-import.log` |
| suíte no clone | **246 checagens / 0 falhas / 37,0 s**, zero `SCRIPT ERROR`, ruído de saída **8** ObjectDB + **4** resources | `f_clone-suite.log` |

O clone rodou **sem abrir janela** — headless, como todo o resto da perna. Os cinco lares aceitos do
§3 estão no log do clone, byte a byte iguais aos da árvore de trabalho, o que é a confirmação de que
o spawn não depende de estado local desta máquina.

## 7. O que estes logs não fecham

- **Nenhum gate de fase** (mandato 4). Nada aqui encerra P0 ou P1.
- A suíte da **`main` mergida** ainda não está neste diretório: ela roda depois do `--no-ff` e entra
  como registro de fecho, com o log e a entrada nova de `artifacts.sha256`, como fez a perna 10.
  Este corpus é a base, os seis degraus e o clone da ponta.
- A regra da casa de medição serial foi respeitada no sentido estrito onde ela importa (contagem e
  exit code), mas **um** log desta collection é atípico de propósito: `b_smoke.log` termina na linha
  do contrato, sem as duas linhas de ruído de saída que os outros dez têm. É truncamento de captura,
  não um estado novo do mundo — e por isso não se afirma nada sobre o ruído daquele degrau.
- O ruído de saída das suíte desta perna tem **três** famílias: `base`/`a` dão 12 ObjectDB, `c`/`f`
  dão 8, `d`/`e`/`f_red` dão 10 — todas com 4 resources. Nenhuma corrida foi feita com `--verbose`,
  então a contagem fica registrada sem atribuição, como no furo #15.
- O caminho de recusa no boot (§3) não tem corrida própria: nenhuma das 45 execuções exerceu a
  fila de `RESPAWN_DELAY` vinda de uma recusa de lar. O que está provado é o predicado, não a
  recuperação depois de uma recusa no primeiro tick.
