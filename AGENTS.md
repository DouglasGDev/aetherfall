# Aetherfall — instruções de trabalho (obrigatórias)

Contrato de colaboração deste repositório: **como** se muda o código daqui. O **que** falta
mudar — furos, gates, débitos e o que foi medido — está em
[`docs/melhorias-status.md`](docs/melhorias-status.md). São duas metades da mesma cobrança:
o arquivo de status audita cada promessa contra o código e contra o log e devolve um veredito;
este documento pega o veredito e o trata como regra de comportamento. Nada aqui manda fazer
o que o status marca como peça inexistente.

Motor Godot 4.7.2-stable com Vulkan Forward+ (`config/features` em
[project.godot:10](project.godot#L10)), GDScript tipado, sem C# e sem addons. Código MIT
([LICENSE](LICENSE)); modelos e packs em [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
Repositório: <https://github.com/DouglasGDev/aetherfall>.

## Os três mandatos, e o que cada um responde

| Você quer saber | Onde está |
| --- | --- |
| O que o projeto promete × o que `src/` faz hoje | [`docs/melhorias-status.md`](docs/melhorias-status.md), "Os prompts × o código" |
| Feito nesta rodada, em andamento, fila, backlog e débitos | idem, seções seguintes |
| Que corrida sustenta cada número publicado | idem, "Notas de medição" |
| Como conduzir a mudança: escopo, atomicidade, medição, comentário | este arquivo |
| Custo de uma mudança: budget, alocação, LOD, o que cresce sem justificativa | este arquivo, "Disciplina de otimização", e a terceira tabela do status |
| O que é cada fase e qual é o gate dela | [docs/design/08](design/08-roadmap-risks-licensing.md) |
| O que é meta de design e o que é código que existe | [docs/design/README.md](design/README.md), legenda `[TARGET]`/`[MEASURED]`/`[DECIDED]`/`[OPEN]` |

## Princípios invioláveis e onde cada um já está seguro

1. **Nada simulado.** Nenhum resultado inventado, placeholder bonito ou fallback que finja
   sucesso. *Seguro por:* cada número publicado aponta um `.log` de uma corrida real, inclusive
   as que não sustentam a tese, na tabela de medição do status. *Cobrança operacional:* um
   `SCRIPT ERROR` dentro de um passo de teste derruba checagens em silêncio — medido, quatro
   corridas que deram 215 checagens em vez de 219 sem nenhum vermelho. A contagem se confere
   antes de qualquer lote, não depois.
2. **A mente propõe, as regras dispõem.** LLM/oráculo nunca decide movimento, dano, posição ou
   estado de mundo. *Seguro por construção hoje:* a única saída de `MindOracle` é o dicionário
   `_narrations` ([mind_oracle.gd:27](src/ai/mind_oracle.gd#L27), gravado em
   [:120](src/ai/mind_oracle.gd#L120)), lido por `narration_of()`
   ([:59-60](src/ai/mind_oracle.gd#L59-L60)) e entregue só ao HUD
   ([main.gd:109](src/main.gd#L109) → [hud.gd:270-271](src/ui/hud.gd#L270-L271)). Não existe
   caminho do oráculo para `Mind`, `Wolf` ou `VoxelWorld`; a decisão vem de BT + utilidade
   ([wolf.gd:129-156](src/entities/wolf.gd#L129-L156), `src/ai/utility_scorer.gd`).
   *Fica faltando:* é verdade por ausência de ligação, não por verifier. Quando o oráculo
   começar a sugerir algo, a sugestão entra como crença em quarentena (§04), nunca como
   intenção já escrita no corpo.
3. **Determinismo e medição primeiro.** Todo número citado vem de execução real, de preferência
   headless. *Estado honesto:* a geração é determinística (seed única
   [`SEED := 20261116`](tests/smoke_test.gd#L10), o mesmo mundo construído duas vezes devolve as
   mesmas 16 colunas de relevo) e a **simulação ao vivo não é** — `hp` final, Éter e pior passo
   mudam entre corridas da mesma árvore. Não existe hash de estado por tick nem journal de tick.
   Portanto "não quebrar a capacidade de hash/journal" aqui só pode significar uma coisa: não
   fechar o acesso ao estado autoritativo. Ele continua serializável por dicionário e `Callable`
   (`main.diagnostics()`, [main.gd:404](src/main.gd#L404)) exatamente para que o primitivo seja
   construído depois — e ele é o item 1 da fila.
4. **Gates são sagrados.** Nenhuma fase termina por calendário; termina por comando headless +
   critério numérico + documento derivado do código. *Estado medido:* **nenhum gate fechado**, o
   slice jogável está **antes** de P1 ([docs/design/08](design/08-roadmap-risks-licensing.md)).
   "Estamos em P0/P1" descreve o que existe, não uma fase encerrada. Gate travado = a próxima não
   começa; a exceção se registra **antes** de escrever o código, nunca na justificativa do commit.
5. **Observabilidade é requisito, não luxo.** *Seguro por:* o overlay de debug (F3 em
   [input_actions.gd:33](src/input/input_actions.gd#L33), corpo em
   [hud.gd:241-275](src/ui/hud.gd#L241-L275)) mostra tick, `worst_step_ms`, ticks perdidos,
   total por canal do Éter e uma linha por lobo com a narrativa do oráculo. *Falta para P1:*
   `MindsInspector` não existe, e o custo de BT (`tree_stats()`,
   [wolf.gd:524-525](src/entities/wolf.gd#L524-L525)) só sai em janela — enquanto não houver
   colheita em headless, "budget medido" continua sendo afirmação.
6. **Mudanças pequenas e atômicas.** Um assunto por commit e suíte verde entre eles, com a
   medição de cada um no próprio commit. O corte desta revisão é o exemplo: o conserto do passo
   de golpe e a publicação do número do clone limpo são dois commits porque cada um tem uma
   corrida que lhe responde.
7. **Comentário explica o porquê, em português.** Nunca narrar o óbvio do código. Modelos
   reais: [smoke_test.gd:215-223](tests/smoke_test.gd#L215-L223) (por que o teste dá o `dt` e os
   passos ele mesmo) e o `GEN_VERSION` [world_gen.gd:6](src/world/world_gen.gd#L6), que faz o
   save velho ser recusado com mensagem em vez de lido torto
   ([main.gd:351](src/main.gd#L351)).
8. **Zero derivação GPL do Veloren.** Inspiração de idéias e sistemas é permitida; código e
   asset, não. *Verificado por ausência:* nenhum `.rs` e nenhum `.ron` no repositório;
   [docs/design/09](design/09-veloren-mechanics-adaptation.md) separa o que veio de lá como
   idéia, o que existe em código e o que foi rejeitado.

## Disciplina de otimização e controle de crescimento

O terceiro mandato não pede otimização nova: pede que nenhuma mudança entre sem responder
o custo dela. Ele é aplicável porque o projeto **já** tem instrumento — e tem, com nomes:

**As duas cadências.** O jogador local roda por *frame*
([main.gd:123](src/main.gd#L123) → `update_local`) e é hoje a única coisa que escreve no
mundo fora do tick — o `set_block` da lavra e da colocação está em
[player.gd:660](src/entities/player.gd#L660) e [:686](src/entities/player.gd#L686). Todo o
resto (Éter, mentes, cadáveres, relógio) é autoritativo a 20 Hz
([sim_clock.gd:5-7](src/core/sim_clock.gd#L5-L7)) dentro de `begin_step`/`end_step`, que
cronometra em microsegundos ([main.gd:124-128](src/main.gd#L124-L128),
[sim_clock.gd:32-39](src/core/sim_clock.gd#L32-L39)). Regra de bolso: o que você coloca em
`_sim_tick` divide 50 ms com 5 lobos; o que coloca em `_physics_process` divide o frame com
a renderização.

**Orçamentos que já são código**, não intenção (regra 7):

| Orçamento | Valor hoje | Onde |
| --- | --- | --- |
| Passo de simulação | 50 ms (20 Hz), teto de 5 passos por frame; o que estourar vira `dropped_ticks` à vista | [sim_clock.gd:5-7](src/core/sim_clock.gd#L5-L7), [:19-29](src/core/sim_clock.gd#L19-L29) |
| Árvore de decisão, por lobo | 400 µs no `SubtreeGuard` (a default da classe é 250 µs) | [bt_tree.gd:117-120](src/ai/behavior/bt_tree.gd#L117-L120), [wolf.gd:155-156](src/entities/wolf.gd#L155-L156) |
| Malha | 2 chunks por frame | [main.gd:13](src/main.gd#L13), usado em [:154](src/main.gd#L154) |
| Difusão do Éter | 4 passadas por segundo, não 20 | [main.gd:12](src/main.gd#L12), [:134-137](src/main.gd#L134-L137) |
| Recolha de cadáver, visão do Éter | 1 s e 0,25 s | [main.gd:16](src/main.gd#L16), [:14](src/main.gd#L14) |

**O que dói hoje, medido** (regra 2): o boot, não o tick. Geração de 936 a 962 ms e
malharia de 4.640 a 4.886 ms com a janela congelada (`.tools/suite_fix1.log` …
`suite_fix4.log`; no clone limpo, 941 ms e 4.668 ms). O passo mais caro das cinco corridas
ficou entre 7,56 e 11,21 ms dos 50 ms disponíveis, com `dropped_ticks = 0` em todas. Quem
propuser otimizar o hot path de simulação começa a conversa por esse número — e a
conversa sobre boot já aconteceu uma vez com número na mesa: os ~16 s originais caíram para
~7,5 s quando o mesher passou a ler uma cópia linear do mundo em vez do dicionário de
chunks (README, seção "Limites conhecidos (medidos nesta máquina)").

**Alocação no caminho quente existe e não é medida** — é débito, não tarefa de otimização
ainda (regras 5 e 1, nesta ordem):

- o blackboard do BT é um `Dictionary` novo por lobo por tick
  ([wolf.gd:339](src/entities/wolf.gd#L339)): com a matilha inteira viva, 5 × 20 = 100
  dicionários por segundo (o `sim_step` retorna cedo em cadáver, então o número é teto);
- a difusão aloca um `PackedInt32Array` por canal por passada
  ([aether_field.gd:113](src/world/aether_field.gd#L113)): 3 a cada 0,25 s;
- a conta das árvores (5 × 400 µs = 2 ms) cabe no teto de 2,5 ms que o gate de P1 ainda
  escreve como `[TARGET]` — e nenhum log mostra a soma real.

Nada disso tem medição própria: os únicos monitores do engine lidos no repositório são
`TIME_PROCESS` e `TIME_PHYSICS_PROCESS`, e só no overlay F3
([hud.gd:244-247](src/ui/hud.gd#L244-L247)). Em headless, a suíte colhe `worst_step_ms` e
`dropped_ticks` pelo `diagnostics()` ([main.gd:404](src/main.gd#L404)). Então o primeiro
passo de qualquer otimização é a colheita, não o corte.

**LOD (regra 6) é parcial, e se diz assim:** existe *throttle temporal* por subsistema —
Éter e visão 4×/s, cadáveres 1×/s, e cooldowns de percepção dentro da árvore
([wolf.gd:83-85](src/entities/wolf.gd#L83-L85)) — e não existe *LOD por distância*: os lobos
vivos rodam a árvore inteira a cada tick, perto ou longe. A peça do design é o
`HotSet`/Véu (§04, §06) e pertence a P2; antes de o custo aparecer em log, ela é backlog.

**Anti-bloat, com o estado real:**

- `main.gd` é o "objeto deus" conhecido — 451 linhas donas de mundo, relógio, matilha, HUD,
  oráculo e visualização ([main.gd:18-24](src/main.gd#L18-L24)). Isso está registrado como
  débito, não como licença: mudança que precisa de estado novo pergunta primeiro **quem é o
  dono** daquele estado.
- Generalize no segundo chamador, não no primeiro. O padrão da casa é dado no código até
  haver motivo para dado em arquivo: nomes e propriedades em
  [block_defs.gd:123-137](src/world/block_defs.gd#L123-L137), receitas em
  [recipes.gd:31-43](src/items/recipes.gd#L31-L43), ambos construídos uma vez.
- Caminho nunca exercitado se isola com nome, não se comenta: a sonda de oráculo vivo é
  cena própria ([tests/live_oracle_probe.tscn](tests/live_oracle_probe.tscn)) justamente para
  não virar fallback silencioso dentro de `MindOracle`.
- Complexidade se paga com teste: checagem nova que não pode falhar é remoção de código
  adiada. A suíte é o lugar de justificar a abstração.

**As quatro perguntas antes de escrever** (responda com número, não com adjetivo): roda por
frame, por tick ou às vezes? quantas entidades são alcançadas (hoje: 5 lobos, 64 chunks, 1
jogador)? aloco no caminho quente? como sei que ficou melhor — e o log existe em headless?
Se a resposta da última for "não existe", o trabalho do bloco é a colheita. Se uma mudança
puder degradar o budget de forma relevante, avise antes de implementar e proponha a versão
mais enxuta que mantém a correção e a mensurabilidade; pedido grande quebra em partes e diz
o que pode esperar.

## Escopo autorizado agora

Dentro, na ordem da fila do status: primitivo de hash por tick + journal apêndice-only; cenário
do lobo multi-semente em cima dele; canais morte/som/fogo no `AetherField` (são 3 hoje —
[aether_field.gd:9-15](src/world/aether_field.gd#L9-L15)); observabilidade de mente (inspector e
colheita headless do budget de BT); redução de acoplamento **quando** ela serve a uma dessas;
robustez do oráculo **atual**, que é HTTP ([mind_oracle.gd:11-13](src/ai/mind_oracle.gd#L11-L13)).

Fora, sem autorização explícita do dono do repositório: P2 (facções / `SlowSim`), oráculo nativo
em GDExtension, co-op, progressão e chefes, e qualquer "melhoria" de sistema que já passou no
gate dele. Idéia boa de fase futura vira linha de backlog no status, não código agora.

## Ciclo de trabalho

1. **Leia o código real do assunto antes de propor a mudança.** As citações `arquivo:linha` do
   status são o atalho; se a linha mudou, releia — não confie no número, confie no conteúdo.
2. **Prefira a solução mais simples que preserve as propriedades do sistema** (emergência,
   memória, feedback). Entre elegância e uma propriedade do mundo que lembra, a propriedade
   ganha.
3. **Reproduza antes de corrigir.** Vermelho intermitente com código idêntico é defeito de
   premissa, não do ambiente. A atribuição só fecha nos dois sentidos: um braço que produz a
   assinatura exata da falha a partir de um estado que se mede como frequente, e outro mostrando
   que o conserto é indiferente a esse mesmo estado.
4. **Toda checagem nova nomeia a premissa que exige** e imprime o número que a decide —
   `mira travada no lobo do passo` existe porque o passo anterior podia passar por sorte.
5. **Rode a suíte** (comandos abaixo) e trate a última linha como contrato: contagem de
   checagens, falhas e tempo.
6. **Número publicado = número medido nesta revisão.** Antes de dizer que uma contagem vale,
   re-meça num clone limpo do commit (o `--import` é obrigatório no clone ainda não importado) e
   pine o SHA no texto. Mudou o código depois da medição, o número volta a ser hipótese.
7. **Fim de bloco: atualize `docs/melhorias-status.md`** — feito / em andamento / falta /
   débitos / furos descobertos / notas de medição — e re-derive as citações que o bloco tornou
   velhas. Documento que descreve peça inexistente se marca como alvo, não se escreve no indicativo.
8. **Commit atômico.** Push só quando o dono pedir, e publicação se confirma com
   `git ls-remote --heads origin`: este repositório já teve um `origin` apontando para ele mesmo,
   de onde o `push` saía com código 0 sem publicar nada.

## Comandos de medição

```sh
# clone recém-clonado: importa antes de qualquer outra coisa
godot --headless --path . --import
# a suíte; sai com código 1 se qualquer checagem falhar; a última linha é "N checagens M falhas T s"
godot --headless --path . tests/smoke_test.tscn
# gate curto de compilação enquanto se edita (nunca substitui a suíte)
godot --headless --path . --check-only --script src/entities/wolf.gd
# capturas da galeria, em janela 1920x1080
godot --path . .tools/shot_gallery.tscn
```

Medição de tempo é serial: lote com gate de timing não roda em paralelo com outra carga na
máquina, porque o número que sai é do concorrente. Sonda curta de compilação é sempre permitida;
corrida de 36 s espera a máquina livre.

## O que não fazer (com o motivo já medido aqui)

- Não "melhorar" por gosto um sistema que já passou no próprio gate — o custo sai do gate aberto.
- Não adicionar complexidade sem necessidade clara para o gate atual.
- Não inventar dado, comportamento ou resultado de teste, nem em exemplo de documentação.
- Não silenciar `SCRIPT ERROR`/warning para o teste ficar verde: o erro que derruba um passo
  também derruba as checagens dele, e a suíte passa a contar menos com o mesmo "0 falhas".
- Não montar premissa de teste escrevendo campo na mão quando o jogo tem a transição que faz
  aquilo (`respawn_at`, `close_panel`): o campo escrito à mão cria estado que nenhum passo
  seguinte espera.
- Não expandir escopo sem pedido, e não começar fase futura "porque o esqueleto é barato".
