# SimClock — o relógio de 20 Hz, lido linha a linha

Esta página deriva de um arquivo só: [src/core/sim_clock.gd](../../src/core/sim_clock.gd), que tem 47
linhas nesta revisão (`wc -l`; a revisão lida está nomeada no §7). A encomenda é o §5 de
[docs/planos/07-af-bench-bake-off-voxel-e-doc-do-simclock.md:83-93](../planos/07-af-bench-bake-off-voxel-e-doc-do-simclock.md),
e a premissa falsificável é a do §1 do mesmo dossiê
[docs/planos/07-af-bench-bake-off-voxel-e-doc-do-simclock.md:13](../planos/07-af-bench-bake-off-voxel-e-doc-do-simclock.md):
cada limite escrito aqui corresponde a uma linha de arquivo; número no indicativo sem linha
correspondente é defeito desta página, não do código.

Nada aqui foi medido. Nenhuma engine foi rodada para escrever esta página além do `--check-only` do
próprio arquivo, então não existe um único `[MEASURED]` nela. Onde o número vem de aritmética sobre
constantes, a frase diz "derivado" e aponta as linhas que a sustentam; onde o código não diz, a página
diz que ele não diz. As marcas `[TARGET]` / `[MEASURED]` / `[DECIDED]` / `[OPEN]` são as da legenda
[docs/design/README.md:8-16](../design/README.md#L8-L16).

## 1. (a) O passo: `HZ = 20` e `STEP = 1/20` s

As três constantes do relógio são `const`, então não há ajuste em tempo de execução: `HZ = 20`
[sim_clock.gd:5](../../src/core/sim_clock.gd#L5), `STEP = 1.0 / HZ` [sim_clock.gd:6](../../src/core/sim_clock.gd#L6)
— 50 ms por passo — e `MAX_STEPS_PER_FRAME = 5` [sim_clock.gd:7](../../src/core/sim_clock.gd#L7). O
estado do relógio são seis variáveis: o contador `tick` [:9](../../src/core/sim_clock.gd#L9), o
`_accumulator` [:10](../../src/core/sim_clock.gd#L10), a marca `_t_step` do cronômetro
[:11](../../src/core/sim_clock.gd#L11), `last_step_ms` [:12](../../src/core/sim_clock.gd#L12),
`worst_step_ms` [:13](../../src/core/sim_clock.gd#L13) e `dropped_ticks`
[:14](../../src/core/sim_clock.gd#L14).

`tick` conta passos e a própria classe nunca o incrementa: quem faz isso é a sessão, na última linha
útil do corpo do passo, antes do journal [src/main.gd:326](../../src/main.gd#L326. Lido junto com
[main.gd:321-327](../../src/main.gd#L326-L332, isso dá uma regra que quem escreve código dentro do
passo precisa saber: durante o `_sim_tick`, `clock.tick` ainda é o índice do passo que está
terminando, e o hash do journal entra gravado com o número seguinte. O contador atravessa o save
[main.gd:1027](../../src/main.gd#L1051 e volta do disco [main.gd:1157](../../src/main.gd#L1181; o
`_accumulator` não volta — o relógio recomeça do zero e o que estava sobrando no acumulador do
processo anterior não existe mais.

A proporção entre os dois relógios tem checagem na suíte, e ela pode falhar: 600 chamadas de
`advance(1.0 / 60.0)` somam 200 passos [tests/smoke_test.gd:1238-1241](../../tests/smoke_test.gd#L1238-L1241),
e `step_duration()` é checado igual a 0,05 [tests/smoke_test.gd:1245](../../tests/smoke_test.gd#L1245).
Dela sai a conta do bench que o dossiê pede: 600 s ÷ 0,05 s = 12 000 ticks, derivado de
[sim_clock.gd:6](../../src/core/sim_clock.gd#L6) e do texto do §3
[docs/planos/07-af-bench-bake-off-voxel-e-doc-do-simclock.md:35](../planos/07-af-bench-bake-off-voxel-e-doc-do-simclock.md)
— não é medição desta página.

Fora da classe, `HZ` tem um único leitor em `src/`: a memória de avistamento do lobo converte
segundos em passos com `SimClock.HZ` [src/entities/wolf.gd:464](../../src/entities/wolf.gd#L464) sobre
`SIGHT_MEMORY_SECONDS = 6.0` [wolf.gd:35](../../src/entities/wolf.gd#L35), ou 120 ticks, derivado das
duas linhas. [`step_duration()`](../../src/core/sim_clock.gd#L42-L43) tem um chamador em `src/`: o corpo
do tick pega `dt` dele [src/main.gd:291](../../src/main.gd#L291 e nunca lê relógio de parede. É essa a
costura que o "driver de `dt` fixo" do dossiê
[docs/planos/07-af-bench-bake-off-voxel-e-doc-do-simclock.md:37-45](../planos/07-af-bench-bake-off-voxel-e-doc-do-simclock.md)
quer exercitar, e a peça ainda é `[TARGET]`.

## 2. (b) O acumulador, o teto de passos e o `dropped_ticks`

[`advance()`](../../src/core/sim_clock.gd#L19-L29) é o corpo inteiro da disciplina de tempo: soma o
`delta` no acumulador [:20](../../src/core/sim_clock.gd#L20) e, enquanto há um passo inteiro guardado
[:22](../../src/core/sim_clock.gd#L22), consome `STEP` por vez e conta um por vez
[:27-28](../../src/core/sim_clock.gd#L27-L28). Quando os passos já consumidos batem no teto
[:23](../../src/core/sim_clock.gd#L23), três coisas acontecem na ordem: `dropped_ticks += 1`
[:24](../../src/core/sim_clock.gd#L24), `_accumulator = 0.0` [:25](../../src/core/sim_clock.gd#L25) e
`break` [:26](../../src/core/sim_clock.gd#L26).

O corte do acumulador é o detalhe que manda. O tempo que sobrou não fica para o frame seguinte: ele é
descartado. Por isso `clock.tick` não é função do tempo de parede decorrido — é função de como os
`delta` chegaram, e um travamento apaga simulação em vez de devolvê-la depois. O comentário do método
[:17-18](../../src/core/sim_clock.gd#L17-L18) nomeia a regra, "nunca catch-up silencioso", e o contador é
a metade não silenciosa dela: o estouro vira número lido no F3
[src/ui/hud.gd:256-258](../../src/ui/hud.gd#L256-L258) e no `diagnostics()`
[src/main.gd:1230](../../src/main.gd#L1230.

Uma precisão que a própria suíte já mede: `dropped_ticks` conta **eventos de estouro**, não passos
perdidos. [tests/smoke_test.gd:1242-1244](../../tests/smoke_test.gd#L1242-L1244) chama `advance(1.0)` —
vinte passos inteiros de acumulado — e espera `s == 5 and c.dropped_ticks == 1`. Cinco rodam, quinze
são descartados, o contador andou um. Quem lê o número no overlay tem de lê-lo assim: "quantos frames
estouraram o teto", e não "quantos ticks o mundo deixou de viver". O nome da variável
[:14](../../src/core/sim_clock.gd#L14) diz mais do que o código entrega, e registrar a diferença aqui é
mais barato do que renomear sem chamador novo.

O teto está longe de ser o caminho comum: 5 × 0,05 s = 0,25 s de tempo simulado consumível por
chamada, contra os ~16,7 ms que chegam num frame de 60 Hz — aritmética sobre
[sim_clock.gd:6-7](../../src/core/sim_clock.gd#L6-L7), não medição. Estourar exige um frame que ainda
deixe um passo inteiro depois de cinco. [`advance()`](../../src/core/sim_clock.gd#L19-L29) tem um
chamador em `src/`, o `_physics_process` da sessão [src/main.gd:283](../../src/main.gd#L283, e
`dropped_ticks` não tem reset nenhum: é acumulado do processo, do mesmo jeito que o pico da seção
abaixo.

## 3. (c) O cronômetro `begin_step` / `end_step` e o pico monotônico

[`begin_step()`](../../src/core/sim_clock.gd#L32-L33) grava `Time.get_ticks_usec()` em `_t_step`
[:11](../../src/core/sim_clock.gd#L11). [`end_step()`](../../src/core/sim_clock.gd#L36-L39) lê o mesmo
relógio de novo, divide a diferença por mil e guarda em `last_step_ms`
[:38](../../src/core/sim_clock.gd#L38), depois mantém o máximo em `worst_step_ms`
[:39](../../src/core/sim_clock.gd#L39). A contagem é em microssegundos, o armazenamento em
milissegundos `float`: nada se perde na escala dos 50 ms, e nada aqui é média — o número é o pior
passo, não o passo típico.

Monotônico quer dizer só sobe, e o único caminho de volta a zero é
[`reset_worst()`](../../src/core/sim_clock.gd#L46-L47). **Ele não tem chamador**: `grep` por
`reset_worst` em `src/` e `tests/` devolve apenas a definição, nas linhas
[46](../../src/core/sim_clock.gd#L46) e [47](../../src/core/sim_clock.gd#L47). O estado honesto é este:
hoje o `worst_step_ms` que sai no F3 e no `diagnostics()` é o pior passo do **processo inteiro**, não
de uma janela de observação. Quem quiser comparar dois trechos da mesma corrida precisa reiniciar o
processo ou escrever o chamador que falta — e isso é tarefa, não texto desta página.

O que está dentro do cronômetro é exatamente uma chamada: [`_sim_tick()`](../../src/main.gd#L290-L332
entre [`begin_step`/`end_step`](../../src/main.gd#L285-L287. Ficam fora do número o
`player.update_local(delta)` que roda antes [main.gd:277](../../src/main.gd#L282 e todo o
[`_process()`](../../src/main.gd#L335-L341, inclusive o malhamento. Entram nele a difusão do Éter, as
mentes, a recolha de cadáveres, a fila de respawn, a roda de acasalamento e — com o journal ativo — o
SHA256, a escrita e o `flush` do tick [main.gd:321-327](../../src/main.gd#L326-L332. Então
`worst_step_ms` não é tempo de frame: o overlay mostra os dois lado a lado, `fps` / `processo` /
`fisica` de um lado [hud.gd:248-251](../../src/ui/hud.gd#L248-L251) e `tick` / `sim` / `pior` /
`perdidos` do outro [hud.gd:256-258](../../src/ui/hud.gd#L256-L258), porque medem coisas diferentes.

Consumidores dos dois números: `last_step_ms` só aparece no F3 [hud.gd:258](../../src/ui/hud.gd#L258);
`worst_step_ms` sai no F3 e como `worst_sim_ms` no `diagnostics()` [main.gd:1205](../../src/main.gd#L1229,
onde a suíte o confere [tests/smoke_test.gd:261-262](../../tests/smoke_test.gd#L261-L262). A dupla é
exercitada direto no arquivo [tests/smoke_test.gd:1246-1249](../../tests/smoke_test.gd#L1246-L1249), que abre
e fecha um passo e exige que o pico tenha sido preenchido. E o runner de reações já colhe os mesmos
dois números pelo caminho real do frame, com `dt` fixo
[tests/aether_reactions_test.gd:1406-1411](../../tests/aether_reactions_test.gd#L1406-L1411 e
[:1406](../../tests/aether_reactions_test.gd#L1443 — precedente vivo do driver que o bench quer.

## 4. (d) As cadências montadas em cima do tick

O relógio só sabe contar passos de 50 ms. Quase tudo o mais no jogo é construído **em cima** disso:
um contador que decai de `dt` em `dt` até a porta abrir. A tabela é o corpo de
[`_sim_tick()`](../../src/main.gd#L290-L332 lido por inteiro, mais as duas constantes que o corpo não
usa.

| Subsistema | Cadência hoje | Constante | Onde decai e dispara |
| --- | --- | --- | --- |
| Difusão + decaimento do Éter | 4 passadas por segundo | `AETHER_PERIOD = 0.25` [main.gd:27](../../src/main.gd#L27 | contador [main.gd:91](../../src/main.gd#L91, porta e reset [main.gd:288-291](../../src/main.gd#L293-L296 |
| Decisão de cada lobo vivo | todo tick, com budget de 400 µs | [wolf.gd:448-449](../../src/entities/wolf.gd#L448-L449) | laço [main.gd:293-294](../../src/main.gd#L298-L299, corpo [wolf.gd:875](../../src/entities/wolf.gd#L875) |
| Grafos de coesão da matilha | todo tick | — | chamada [main.gd:292](../../src/main.gd#L297, corpo [main.gd:859](../../src/main.gd#L883 |
| Leitor de rastros do lobo | 4 varreduras por segundo | `SCENT_PERIOD = 0.25` [wolf.gd:30](../../src/entities/wolf.gd#L30) | decai [wolf.gd:884](../../src/entities/wolf.gd#L884), porta [:927](../../src/entities/wolf.gd#L927), rearma [:961](../../src/entities/wolf.gd#L961) |
| Recolha de cadáveres | 1 por segundo | `CORPSE_CHECK_PERIOD = 1.0` [main.gd:31](../../src/main.gd#L31 | contador [main.gd:93](../../src/main.gd#L93, porta [main.gd:295-298](../../src/main.gd#L300-L303 |
| Fila de respawn | contagem regressiva por tick | `RESPAWN_DELAY = 45.0` [main.gd:30](../../src/main.gd#L30 | entradas, cada uma o par `[segundos, toca]` desde a 16, [main.gd:373](../../src/main.gd#L378 e [:915](../../src/main.gd#L944, decaimento sobre `vaga[0]` [main.gd:299-303](../../src/main.gd#L304-L308 |
| Roda de acasalamento | 1 varredura por segundo | `MATE_PERIOD = 1.0` [main.gd:553](../../src/main.gd#L558 | contador [main.gd:90](../../src/main.gd#L90, porta [main.gd:317-320](../../src/main.gd#L322-L325 |
| `tick += 1` e gravação do journal | todo tick | — | [main.gd:321-327](../../src/main.gd#L326-L332 |
| Malhamento de chunks | **por frame**, não por tick: 2 chunks | `MESH_BUDGET = 2` [main.gd:28](../../src/main.gd#L28 | [`_process()`](../../src/main.gd#L335-L336 |
| Visualização do Éter | **por frame**, não por tick: 0,25 s | `VIZ_PERIOD = 0.25` [main.gd:29](../../src/main.gd#L29 | contador [main.gd:92](../../src/main.gd#L92, decaimento em `delta` de frame [main.gd:332-336](../../src/main.gd#L337-L341 |

Três leituras dessa tabela pagam a seção.

**Duas das cinco constantes que o dossiê lista como montadas em cima do tick não estão no tick.**
`MESH_BUDGET` e `VIZ_PERIOD` correm no `_process`, com o `delta` de frame
[main.gd:330-336](../../src/main.gd#L335-L341; o texto de §5 do dossiê
[docs/planos/07-af-bench-bake-off-voxel-e-doc-do-simclock.md:88-89](../planos/07-af-bench-bake-off-voxel-e-doc-do-simclock.md)
as coloca junto das outras três. Consequência: "2 chunks por frame" e "0,25 s de visualização" escalam
com o `fps`, não com os 20 Hz. Numa máquina mais lenta a malha anda mais devagar em tempo de mundo, e
o relógio não tem nada com isso.

**O difusor recebe o período, não o `dt`.** [main.gd:290](../../src/main.gd#L295 chama
`diffuse_and_decay(AETHER_PERIOD)`: a passada é quantizada em 0,25 s de lógica por design, e o próprio
campo declara a convenção no comentário do método
[src/world/aether_field.gd:108](../../src/world/aether_field.gd#L108). Lido contra
[sim_clock.gd:6](../../src/core/sim_clock.gd#L6), o contrato é 5 passos de 50 ms por passada.

**O laço do passo não é de cinco lobos.** Ele percorre `wolves`, que nasce com `WOLF_COUNT = 5`
[main.gd:9](../../src/main.gd#L9 e tem teto de censo em `CENSUS_CAP = 12` [main.gd:18](../../src/main.gd#L18;
o que a suíte imprime é `wolves` do `diagnostics()` [main.gd:1185](../../src/main.gd#L1209. O custo do
tick escala com o censo do momento, não com o número do boot. Com doze mentes a conta bruta de árvores
é 12 × 400 µs = 4,8 ms dos 50 ms, derivado de [main.gd:18](../../src/main.gd#L18 e
[wolf.gd:448-449](../../src/entities/wolf.gd#L448-L449) — e a soma real não está medida em log nenhum. O
budget é por lobo e cobre só a árvore de comportamento: o `SubtreeGuard` cronometra o filho e conta o
estouro [src/ai/behavior/bt_tree.gd:130-137](../../src/ai/behavior/bt_tree.gd#L130-L137), com default de
classe de 250 µs [:120](../../src/ai/behavior/bt_tree.gd#L120) que o lobo sobe para 400; percepção e
utilidade ficam fora dele, como o `tree_stats()` declara [wolf.gd:1356-1357](../../src/entities/wolf.gd#L1356-L1357).

## 5. (e) O que o relógio **não** é: autoridade única

O cabeçalho do arquivo afirma "Toda decisao de IA, todo imprint de Eter e todo tick de rede vivem
aqui" [src/core/sim_clock.gd:2-3](../../src/core/sim_clock.gd#L2-L3). A primeira metade é verificável e
verdadeira: `sim_step` tem um chamador em `src/` [main.gd:294](../../src/main.gd#L299. A segunda não é,
e a própria sessão documenta o motivo em [main.gd:925-928](../../src/main.gd#L949-L952, que diz que a
pergunta ao gerador roda em evento, "nunca no tick de 20 Hz".

O que anda por **frame de física**, e não por tick:

- **Locomoção e ações do jogador.** `player.update_local(delta)` é chamado antes do `advance`
  [main.gd:277](../../src/main.gd#L282, dentro do [`_physics_process`](../../src/main.gd#L281-L287 que o
  engine dispara, e o corpo dele está em
  [src/entities/player.gd:354](../../src/entities/player.gd#L354). A lavra soma `delta` de frame até
  estourar a dureza [player.gd:663-665](../../src/entities/player.gd#L663-L665) e escreve voxel direto em
  [player.gd:685](../../src/entities/player.gd#L685) e [player.gd:711](../../src/entities/player.gd#L711),
  fora de qualquer passo do relógio.
- **Os imprints do Éter causados pelo jogador.** `_on_acted` escreve WORK
  [main.gd:934-939](../../src/main.gd#L958-L963 porque o sinal `acted` é emitido dentro do `update_local`
  [player.gd:690](../../src/entities/player.gd#L690) e [:715](../../src/entities/player.gd#L715); dano e
  morte escrevem BLOOD e FEAR pelos handlers [main.gd:972-979](../../src/main.gd#L996-L1003. As ligações
  são de sinal [main.gd:162-173](../../src/main.gd#L162-L173, não de tick.
- **Locomoção e timers do lobo.** `Wolf._physics_process`
  [src/entities/wolf.gd:1203-1259](../../src/entities/wolf.gd#L1203-L1259) é callback do engine: aplica
  gravidade e empuxo, faz o steering, chama `move_and_collide` [wolf.gd:1238](../../src/entities/wolf.gd#L1238)
  e decide o auto-pulo no ramo de bloqueio [wolf.gd:1239-1254](../../src/entities/wolf.gd#L1239-L1254). Os
  timers de cadáver [wolf.gd:1205](../../src/entities/wolf.gd#L1205), atordoamento
  [:1222](../../src/entities/wolf.gd#L1222) e desemperto [:1229](../../src/entities/wolf.gd#L1229) decaem em
  segundos de frame — o corpo do lobo não obedece aos 20 Hz, só a cabeça dele.

Uma nuance de versão, porque a página é sobre este arquivo: a cadência de 60 Hz do frame de física não
está pinada neste repositório. A seção que a promete é
[docs/design/06-godot-architecture.md:25-31](../design/06-godot-architecture.md#L25-L31), mas o
arquivo de projeto tem uma seção `[physics]` com uma única linha,
`common/enable_object_picking=false` — `project.godot:27-29`. Os 60 Hz de hoje são o default do motor,
não um contrato deste repo.

Consequência direta para quem vai medir: um runner que chame só `advance()` e o corpo do tick move o
mundo e deixa os corpos parados, porque a locomoção inteira mora no `_physics_process` do lobo e no
`update_local` do jogador. O runner que já existe resolve isso alimentando o frame do próprio relógio,
com `_session._physics_process(SimClock.STEP)`
[tests/aether_reactions_test.gd:1443](../../tests/aether_reactions_test.gd#L1443 e os passos de corpo em
`SimClock.STEP / 3.0` [:321](../../tests/aether_reactions_test.gd#L358.

## 6. O que é alvo, não código `[TARGET]`

Peças que o design descreve ao redor do relógio não existem em `src/`, e entram marcadas — nunca no
indicativo.

- **`EntityStore` SoA `[TARGET]`.** A seção que o especifica é
  [docs/design/06-godot-architecture.md:46-63](../design/06-godot-architecture.md#L46-L63), com o
  esqueleto declarado na linha 53 desse mesmo arquivo de design, em
  `src/core/sim/entity_store.gd`. Nenhuma dessas
  linhas tem correspondência no repositório: `grep` por `EntityStore` em `src/` devolve vazio e o
  diretório `src/core/sim/` não existe — `src/core/` tem só o relógio. A mesma peça é listada como
  entrega de P0 em [docs/design/08-roadmap-risks-licensing.md:56](../design/08-roadmap-risks-licensing.md#L56),
  cujo estado da fase é "parcial, sem o gate"
  [docs/design/08-roadmap-risks-licensing.md:28](../design/08-roadmap-risks-licensing.md#L28). Do que o
  §2 e o §3 de `06` desenham, o `SimClock` é a peça que existe; o `EntityStore`, não.
- **`HotSet` / Véu `[TARGET]`, fase P2.** Os dois nomes estão no glossário
  [docs/design/README.md:57](../design/README.md#L57), na lista de inovações
  [docs/design/02-innovations.md:50](../design/02-innovations.md#L50) e como responsabilidade de um
  `MindServer` que também não existe em `src/`
  [docs/design/06-godot-architecture.md:112](../design/06-godot-architecture.md#L112). A fase está
  "não iniciada", com nada em `src/`
  [docs/design/08-roadmap-risks-licensing.md:30](../design/08-roadmap-risks-licensing.md#L30), e a
  entrega descrita em [docs/design/08-roadmap-risks-licensing.md:89-93](../design/08-roadmap-risks-licensing.md#L89-L93).
  O que existe hoje é throttle temporal por subsistema — a tabela da §4 — e avaliação da árvore de todo
  lobo vivo a cada tick [main.gd:293-294](../../src/main.gd#L298-L299. LOD por distância não existe.
- **`af-bench` `[TARGET]`.** O nome aparece como intenção de ferramenta própria em
  [docs/design/06-godot-architecture.md:199-201](../design/06-godot-architecture.md#L199-L201), sob um
  `src/tools/` que não existe no repositório, e é a primeira linha do gate de P0 em
  [docs/design/08-roadmap-risks-licensing.md:61-63](../design/08-roadmap-risks-licensing.md#L61-L63).
- **Um caminho morto no design.** [docs/design/06-godot-architecture.md:33](../design/06-godot-architecture.md#L33)
  aponta o relógio em `src/core/sim/tick_clock.gd`. O arquivo real é
  [src/core/sim_clock.gd](../../src/core/sim_clock.gd), sem o `sim/` no meio, e é contra ele que esta
  página foi lida.

## 7. Como esta página falha

A régua tem três passadas, todas em caminho, e a segunda e a terceira decidem as citações:

```sh
# 1. o arquivo descrito compila sozinho
godot --headless --path . --check-only --script src/core/sim_clock.gd
# 2. nenhum número de linha cai fora do arquivo citado (AETHER_ROOT apontando para a raiz medida)
AETHER_ROOT=<raiz> python .tools/verify_plan_cites.py docs/engine/simclock.md
# 3. âncoras do corpus: arquivo existe, faixa não é branca, rótulo cai no corpo da declaração
python tools/check_doc_anchors.py
```

O que as réguas **não** veem está dito no próprio instrumento: ele confere existência de arquivo,
faixa dentro do arquivo, faixa em branco, rótulo fora do corpo e link relativo quebrado, e declara que
"a prosa livre que cita um número sem nomear símbolo nenhum" fica fora
[tools/check_doc_anchors.py:29-32](../../tools/check_doc_anchors.py). É exatamente a classe que o
dossiê quer impedir, e por isso esta página foi escrita abrindo cada alvo e lendo a linha contra a
frase. A primeira escrita foi na revisão `99d1167`; os números acima foram re-derivados sobre o `src/`
de `bb13752` — a aterrissagem da 16 — porque as pernas 14, 15, 16 e 19 escreveram em `main.gd`
(1 004 → 1 242 linhas, `wc -l`) e em `wolf.gd` (1 203 → 1 218) e deslocaram quase todos os ponteiros
da página sem tocar uma linha de `sim_clock.gd`. Uma afirmação caiu de verdade no caminho, e não por
numeração: a fila de respawn já não guarda um tempo por vaga, guarda o par `[segundos, toca]` desde a
16, e por isso o decaimento lê e escreve `vaga[0]` — registrado na tabela do §4. Mudou o código depois
disto, os números voltam a ser hipótese.

Nenhum gate de fase se fecha aqui. O P0 de
[docs/design/08-roadmap-risks-licensing.md:61-63](../design/08-roadmap-risks-licensing.md#L61-L63)
pede o `af-bench` com hash estável em três execuções, o bake-off decidido com números e esta página:
dos três, só a página existe, e gate de fase fecha o dono do repositório.

**Medida nesta ponta, depois de trazer a `main` para dentro.** Esta branch funde `bb13752` e o pouso da
pauta 20 antes do seu próprio merge, e o diff de `src/` e `tests/` entre a ponta e a `main` continua
**vazio** — a página é o único arquivo novo, então a árvore que ela publica é a árvore do merge.
`verify_plan_cites.py` nesta página devolve **158** citações conferidas, **0** números fora do arquivo e
**2** arquivos citados que não existem: `src/core/sim/entity_store.gd` e `src/core/sim/tick_clock.gd`, as
duas peças que o dossiê 07 declara inexistentes e que este doc não escreve. `check_doc_anchors.py` no
corpus inteiro: **38** arquivos, **2 820** ponteiros, **190** rótulos, **2 809** links relativos e **um**
caso objetivo — o link gitignored de sempre. A engine não foi re-corrida aqui: `sim_clock.gd` não mudou
desde a re-derivação sobre o `src/` do pouso da 16, e é isso que mantém os ponteiros da tabela de §4 de pé.
