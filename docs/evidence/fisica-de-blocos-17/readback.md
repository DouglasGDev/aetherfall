# Evidência da perna 17 — física de blocos que caem

Tudo abaixo foi **lido dos logs desta pasta**, arquivo por arquivo. Nenhum número vem de
memória ou de corrida anterior. Horários dos amostradores estão em **UTC**
(`Get-Date).ToUniversalTime()` em [tools/carga_por_janela.ps1](../../../tools/carga_por_janela.ps1)).

Árvore medida nas seções 1–6: `feat/fisica-de-blocos-que-caem-17` depois de `git merge main` →
`0a061ea` (base da branch: `8bddcab`; `main` em `114bcd2` no momento do merge). A seção 7 é o pouso:
merge **`95d519a`** na `main` e o clone limpo dele — o número pineado.

## 1. As cinco corridas na árvore mergida

| Corrida | Rodapé literal | Log |
| --- | --- | --- |
| gate da perna (`--script tests/block_physics_test.gd`) | `16 checagens 0 falhas 9/9 testes concluidos 24.392 s` | [merge_gate.log](merge_gate.log) |
| suíte (`tests/smoke_test.tscn`) | `== 278 checagens  0 falhas  65.6 s de teste ==` | [merge_suite.log](merge_suite.log) |
| runner de reações | `364 checagens 0 falhas 58.801 s` | [merge_runner.log](merge_runner.log) |
| RNG | `27 checagens 0 falhas 2.865 s` | [merge_rng.log](merge_rng.log) |
| journal | `128 checagens 0 falhas 7/7 testes concluidos 6.384 s` | [merge_journal.log](merge_journal.log) |

`SCRIPT ERROR` nas cinco: **0**, **0**, **0**, **0**, **0** (contado com `grep -c` em cada log).

## 2. A linha de contrato da base, para comparar

Medida em `8bddcab` **antes** de qualquer linha desta perna
([base_8bddcab_suite.log](base_8bddcab_suite.log), [base_8bddcab_runner.log](base_8bddcab_runner.log),
[base_8bddcab_rng.log](base_8bddcab_rng.log), [base_8bddcab_journal.log](base_8bddcab_journal.log)):

```
== 277 checagens  0 falhas  71.0 s de teste ==
355 checagens 0 falhas 53.631 s
27 checagens 0 falhas 3.029 s
128 checagens 0 falhas 7/7 testes concluidos 7.578 s
```

Contra a árvore mergida: smoke **277 → 278** e reações **355 → 364**. Nenhum dos dois acréscimos
é desta perna, e cada um tem nome lido no log: a 278ª é
`[PASS] slot do dono devolvido byte a byte` ([merge_suite.log:413](merge_suite.log#L413), da
perna 25), e os nove do runner são `OK bandit_une_numero:` (contagem `1×0 → 1×9`, da Fase 3 da
perna 22). O gate desta perna escreve as oito checagens dele no runner próprio
(`block_physics_test.gd`), não nos quatro contratos. RNG e journal seguem **27** e **128**.

O que **mudou** no smoke por causa desta perna é o tamanho do overlay, não o censo:

```
base:   [PASS] debug mostra o relogio                 linhas=27
mergada:[PASS] debug mostra o relogio                 linhas=28
```

A linha a mais é `blocos  fila %d  em voo %d  eventos %d  leituras %d  overflow %d`
([src/ui/hud.gd:265](../../../src/ui/hud.gd#L265)). As duas checagens que contam linhas
são de presença, não de igualdade, e continuam verdes na sessão real.


## 3. O par vermelha↔verde, com os três vermelhos que a perna pagou

### 3.1 O gate nascido vermelho, contra a árvore sem o código

A corrida está registrada na mensagem do commit `f338c91` (o log não foi preservado):
`15 checagens 8 falhas 1/8 testes concluidos 9,969 s` e `9,642 s`, exit 1, censo 15/15,
zero `SCRIPT ERROR`. Cada uma das sete checagens imprimiu a assinatura da ausência
(`has_gravity`, `BlockUpdateQueue`, `FallingBlock`, `FallingBlockSpawner`, `is_supported`,
`place_falling_block`, `block_stats`, `settle_block_updates` todos NÃO) e
`consumidores_antes_da_perna=0`.

### 3.2 O vermelho do meio, já com as peças escritas — [gate_vermelho_parcial_run1.log](gate_vermelho_parcial_run1.log)

```
FALHA queda_move_a_celula ausencia: N=7 N+k=15 (k=8) origem=(20,45,20)->0 destino=(20,44,2
15 checagens 4 falhas 5/8 testes concluidos 22.949 s
```

As três premissas corrigidas, cada uma com a linha verde:

| Checagem | Verde |
| --- | --- |
| `queda_move_a_celula` | `OK queda_move_a_celula N=7 N+k=14 (k=7) ... edits=0->2 queued_no_gatilho=1 drenagem=1 queued_final=0 em_voo=0 leituras=8` |
| `bloco_em_queda_nao_sobe` | `OK bloco_em_queda_nao_sobe amostras_do_pe=6 ticks_ate_o_pouso=7 step_up=0.000 pe_monotono=true pousou_por_apoio=true placed=1->2 stranded=0 folga_pe_sobre_apoio=0.100 m probe_do_corpo=0.060 m` |
| `journal_hash_muda_so_com_movimento` | `OK ... sem_movimento: 40 ticks ... iguais=true | com_cascata: celulas=41 ticks=8 ... divergiu=true | chaves_novas_do_diario=2` |

[gate_verde_run2.log](gate_verde_run2.log) é o 15/0 com as três premissas pagas;
[gate_verde_run3_f3.log](gate_verde_run3_f3.log) acrescenta a oitava checagem do §5.8
(`f3_e_diagnostics_mostram_a_fila`) e dá `16 checagens 0 falhas ... 23.731 s`;
[gate_verde_run4_pos_fix_no.log](gate_verde_run4_pos_fix_no.log) é a mesma corrida depois do
conserto do nó (§4.2), com `worst=14.36 ms` / `worst=14.84 ms`.

### 3.3 O vermelho do harness — [reacoes_vermelho_nil_flush.extrato.log](reacoes_vermelho_nil_flush.extrato.log)

```
  11693 Invalid call. Nonexistent function 'flush' in base 'Nil'.
     23 Invalid call. Nonexistent function 'stats' in base 'Nil'.
355 checagens 47 falhas 57.720 s
```

`11.693` + `23` = **11.716** linhas de `SCRIPT ERROR` no log bruto de 5.828.612 bytes (o bruto
ficou em `.tools/`, que é gitignored; o extrato é o que está commitado, e ele diz isso na
primeira linha). A causa é uma só: o runner de reações monta a sessão campo a campo e o
`_ready()` nunca roda, então `block_updates` e `block_spawner` eram `Nil` dentro de `_sim_tick`.
O conserto é `setup_block_physics()` como método ([src/main.gd:1274](../../../src/main.gd#L1274))
chamado nos três sítios do harness — não um guarda-de-nulo. Verde depois:
[reacoes_verde.log](reacoes_verde.log) → `355 checagens 0 falhas 55.444 s`, zero `SCRIPT ERROR`.

### 3.4 O vermelho do nó de malha — [smoke_vermelho_nos65.log](smoke_vermelho_nos65.log)

```
  [FAIL] sem no de malha sobrando               nos=65
== 277 checagens  1 falhas  68.6 s de teste ==
```

`sem no de malha sobrando` conta os filhos de `Terrain` para 64 ([tests/smoke_test.gd:3569](../../../tests/smoke_test.gd#L3569)).
Com o stage dos grãos pendurado no Terrain, a contagem virou 65. O stage passou a ser irmão —
grosso modo como `WaterFx`, `Weather` e `RainFx` já são filhos diretos do `Main` — e a checagem
da outra perna continua valendo sem ter sido tocada. Verde: [smoke_verde.log](smoke_verde.log)
→ `== 277 checagens  0 falhas  65.2 s de teste ==`.

## 4. O que as oito checagens do gate decidem, linha por linha

De [merge_gate.log](merge_gate.log), na árvore mergida:

1. `queda_sem_varredura_de_mundo` — `puro: ticks=1000 leituras=0 queued=0 | mapa=1048576
   celulas, varredura teria lido 20971520 por segundo | coluna: eventos=19 leituras=64
   resolucoes=17 teto=72 ticks=13 conversions=6 queued_final=0 | sessao: eventos=0 leituras=0`.
   Mil ticks sem edição = **zero** `get_block`. A promessa "a fila não varre" é número, não frase.
2. `queda_move_a_celula` — `origem=(20,45,20)->0 destino=(20,44,20)->4 edits=0->2`.
3. `queda_cascade_em_passos` — `pilha=6: ticks_de_conversao=6 um_grao_por_tick=true`,
   `insercao_B=52>56>60 ... ordem_Y_decrescente=true ordem_diferente_da_insercao=true`.
4. `bloco_em_queda_nao_sobe` — `step_up=0.000 pe_monotono=true pousou_por_apoio=true
   stranded=0 folga_pe_sobre_apoio=0.100 m probe_do_corpo=0.060 m
   feet_y=46.0>45.94>45.82>45.64>45.4>45.1`.
5. `queda_pousa_antes_do_save` — `em_voo_no_gatilho=5 areias: durante=2 depois_do_quiesce=6
   apos_load=6 no_disco=6 fantasma_no_disco=0 | tick=28->28 (no save: 28) at_rest=true`.
6. `queda_nao_custou_tempo_de_ninguem` — `A sem areia: worst=15.15 ms | B cascata no tick 500:
   worst=15.55 ms max_queued=1 perdidos=0 overflow=0 | teto do passo=25.0 ms dos 50 ms`.
7. `f3_e_diagnostics_mostram_a_fila` — `diagnostics: block_updates=true dropped_ticks=true
   queued=1/1 leituras=176/176 | F3: linha=true rotulos=5/5 fila=1 em_voo=1 eventos=55
   leituras=176 overflow=0`.
8. `journal_hash_muda_so_com_movimento` — `iguais=true` sem movimento, `divergiu=true` com
   cascata, `chaves_novas_do_diario=2`, `((50, 41, 50):A=-/B=0, (50, 40, 50):A=-/B=4)`.

A régua de leituras confere: na checagem 7, `eventos=55` e `leituras=176` ≤ 2×55 + 2×resoluções,
e o `queued=1/1` diz que o número do `diagnostics()` é o mesmo da fila, não outro contador.

## 5. Timing, com a janela escrita

Regra da casa (emenda de 2026-11-25 do AGENTS.md): número de `worst_sim_ms` sai com a janela.
Nos cinco amostradores desta perna (`carga_gate_1..4.log`, `carga_reacoes.log`, `carga_smoke.log`,
`carga_merge.log`) há sempre **um par Godot que não é desta perna** dentro do projeto:

```
AMOSTRA t=17:59:14 load=7% ram_livre=19139/32687 MB pid=13172 cpu=0% ram=7MB pid=23400 cpu=11% ram=96MB alheias= [QuantumEngine:14228=74%] [Qoder#4:17116=17%] [NisSrv:8444=11%]
```

Os dois PIDs estão nas **90 de 90** amostras da janela do merge (`grep -c pid=23400`), entre
**11% e 27% de um núcleo**, criados às **12:48** do mesmo dia por uma cadeia de bash de uma
sonda da perna de isolamento (`test/isolamento-user-smoke-25`) cujo comando terminava em
`tests/smoke_test.tscn ... 2>&1 | head -3`. É um vazamento de instrumento, não uma corrida
publicada: a cadeia do `head -3` morreu, o `bash` pai continua esperando, e o par fica
queimando núcleo indefinidamente. **Esta perna não encerrou o processo** — ele pertence a outra
ponta de trabalho, e a decisão é do dono do repositório.

Mesmo com o concorrente na janela, os passos do gate ficaram em 14,24–15,55 ms contra o teto de
25 ms, e o `espalhamento_nao_estoura_o_passo` do smoke mergido deu:

```
  [PASS] espalhamento_nao_estoura_o_passo       perdidos=0  pior passo=15.40 ms (regua 25)  dens=3 componentes=2 separacao=55.9 m  tick=450
```

## 6. O que a perna fecha e o que ela deixa aberto

**Fecha**, com número: o débito que o status carregava — `block_changed` sem consumidor em
`src/`. Hoje há exatamente uma conexão no diretório:
[src/world/block_update_queue.gd:35](../../../src/world/block_update_queue.gd#L35)
(`grep -rn block_changed src` devolve a declaração em [voxel_world.gd:6](../../../src/world/voxel_world.gd#L6),
o emit em [:312](../../../src/world/voxel_world.gd#L312), três comentários de `main.gd` e esta
linha). A checagem `block_changed declarado e lido por este runner` imprime
`conexoes=2 consumidores_antes_da_perna=1` na árvore com o código, contra `=0` no vermelho original.

**Deixa aberto, escrito assim:**

- Na sessão real do smoke, `diagnostics()["block_updates"]` deu
  `{"events":38,"reads":56,"conversions":0,"queued":0,"overflow":0,"resolutions":0}`: a fila ouve,
  conta, e **nenhum grão caiu** — nenhum caminho de teste da suíte tira apoio de areia gerada.
  A areia existe no mundo gerado ([src/world/world_gen.gd:168](../../../src/world/world_gen.gd#L168)),
  então a mecânica tem comprador, mas a testemunha de "cavei embaixo da praia e desceu" ainda é
  o harness do gate (`conversions=6` na pilha de 6), não uma coluna gerada.
- Nenhum `SLAB` (id 18) e nenhum `breaks_a_fall`: o destino `SHATTER` do doc 10 §10.5 continua
  sem comprador, como o dossiê §6 decide.
- Gate de fase: **nenhum** se fecha aqui (mandato 4). A fila P0/P1 — budget HOT sem medição,
  censo multi-semente, bake-off de AF — continua aberta.
- `Channel.COUNT` (3), `FORMAT_VERSION` (1), `GEN_VERSION` e a projeção do `TickJournal` não
  foram tocados por nenhuma linha desta perna; uma corrida com areia caindo não reproduz os
  hashes publicados porque o **mundo** mudou, não a projeção.

## 7. O pouso na `main` — as mesmas cinco corridas na árvore do merge e no clone limpo

`git merge --no-ff feat/fisica-de-blocos-que-caem-17` → **`95d519a`** (pais `114bcd2` da `main` e
`60150ce` da ponta de docs), **41 arquivos, +16 758/−19**. As árvores `src`/`tests` do merge são as
da ponta medida (`2e3e3622fa89…` / `0dc616493ca4…`) — `git diff --name-only 60150ce 95d519a -- src
tests` devolve vazio — e as da `main` antes do pouso eram `c0f7c9b0…` / `2f9224d0…`.

Árvore do pouso, com `--import` na frente ([pouso_import.log](pouso_import.log), exit 0):

| Corrida | Rodapé literal | Log |
| --- | --- | --- |
| gate | `16 checagens 0 falhas 9/9 testes concluidos 27.689 s` | [pouso_gate.log](pouso_gate.log) |
| suíte | `== 278 checagens  0 falhas  67.2 s de teste ==` | [pouso_suite.log](pouso_suite.log) |
| reações **sem** provisionamento | `364 checagens 29 falhas 107.683 s` | [pouso_reacoes.log](pouso_reacoes.log) |
| reações **com** provisionamento | `364 checagens 0 falhas 57.913 s` | [pouso_reacoes_provisionado.log](pouso_reacoes_provisionado.log) |
| RNG | `27 checagens 0 falhas 2.846 s` | [pouso_rng.log](pouso_rng.log) |
| journal | `128 checagens 0 falhas 7/7 testes concluidos 6.604 s` | [pouso_journal.log](pouso_journal.log) |

Clone limpo do pin com `--import` frio — **o número pineado**: gate `16 checagens 0 falhas 9/9 testes
concluidos 25.487 s` ([clone_gate.log](clone_gate.log)), suíte `== 278 checagens  0 falhas  67.5 s de
teste ==` ([clone_suite.log](clone_suite.log)), reações `364 checagens 0 falhas 68.303 s`
([clone_reacoes.log](clone_reacoes.log)), RNG `27 checagens 0 falhas 2.955 s`
([clone_rng.log](clone_rng.log)), journal `128 checagens 0 falhas 7/7 testes concluidos 7.002 s`
([clone_journal.log](clone_journal.log)). `SCRIPT ERROR`: **0** em cada um dos 13 logs desta seção
(`grep -c`, arquivo por arquivo).

O par 29 ↔ 0 é ambiente, com os nomes lidos: `contrato` ×14, `extensao_pack_no_processo` ×7,
`af_cache_determina_replay` ×5, `budget_do_oraculo` ×2, `budget_do_oraculo_nao_estoura_a_arvore` ×1,
e `grep -c "FALHA.*queda\|FALHA.*bloco"` = **0** no mesmo log. É o **furo #38** reproduzido na árvore
nova, não regressão desta perna.

As três linhas de decisão do gate, na árvore do pouso:

```
OK block_changed declarado e lido por este runner conexoes=2  consumidores_antes_da_perna=1
OK queda_sem_varredura_de_mundo puro: ticks=1000 leituras=0 queued=0 | mapa=1048576 celulas, varredura teria lido 20971520 por segundo | coluna: eventos=19 leituras=64 resolucoes=17 teto=72 ticks=13 conversions=6 queued_final=0 | sessao: eventos=0 leituras=0 resolucoes=0 teto=0 | SAND=true STONE=false
OK queda_pousa_antes_do_save em_voo_no_gatilho=5 areias: durante=2 depois_do_quiesce=6 apos_load=6 no_disco=6 fantasma_no_disco=0 | flutuantes: depois=0 apos_load=0 | edits=10->10 slot_ok=true quiesce=sim tick=28->28 (no save: 28) at_rest=true
```

### 7.1 O furo #56: nenhum amostrador desta perna viu o Godot

Os seis amostradores do pouso e os cinco do clone imprimiram `sem-godot-no-projeto` em **100 %** das
linhas — 90, 140, 140, 60, 60 e 150 na árvore primária
([carga_pouso_gate_prima.log](carga_pouso_gate_prima.log) e irmãs), 45, 95, 85, 15 e 20 no clone
([clone_carga_gate.log](clone_carga_gate.log) e irmãs). A causa é o argumento, não a máquina:
`-proj C:/Aetherfall` contra um `ExecutablePath` do `Win32_Process` que vem com barra **invertida**,
então o `StartsWith` nunca casava e a testemunha virava constante — a mesma classe do **#44**.

Depois do conserto em [tools/carga_por_janela.ps1](../../../tools/carga_por_janela.ps1) (normalizar a
barra e `TrimEnd` na raiz), a mesma chamada achou **6** PIDs do projeto em **12 das 13** linhas
([furo56_amostrador_com_barra_de_frente.log](furo56_amostrador_com_barra_de_frente.log)), às
18:44:02 UTC: `13172`, `23400`, `28668`, `5220` presentes nas **12** amostras — vivos **antes** de
qualquer corrida desta perna — e `20816`, `26256` em apenas **2**. A corrida re-medida nessa janela
deu `27 checagens 0 falhas 2.882 s`
([furo56_rng_na_janela_do_fix.log](furo56_rng_na_janela_do_fix.log)).

Consequência: os números de `worst_sim_ms` das seções 3, 5 e 7 saem **sem testemunha de janela**, e
ficam publicados como grandeza contra o teto (14,24–15,62 ms num teto de 25 ms, `perdidos=0` em todas
as corridas), não como comparação entre árvores. O par vermelha↔verde da *mesma* árvore com o CPU do
Godot nos dois lados fica como débito do elo que rodar este gate depois do conserto — que é exatamente
o que o **#31** continua cobrando.
