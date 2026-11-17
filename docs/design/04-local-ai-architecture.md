# 04 — Arquitetura da IA local

> **Tese:** a IA do Aetherfall não é um cérebro que decide tudo; é uma pilha de camadas
> com **autoridades diferentes**. Camadas baixas determinam o que é *verdade e permitido*;
> camadas altas propõem *o que dizer e o que tentar*. Nenhuma camada de linguagem nunca
> move um pé nem aplica dano. Isso é o que torna "IA local" seguro, barato e testável.

## 0. Pipeline de um tick (20 Hz `[TARGET]`)

```
  [1] INPUTS          pedidos de jogadores, colisões, clima, eventos de mundo
  [2] WORLD EVENTS    normalizados em AetherImprint + EchoDeed (append-only)
  [3] AETHER DIFFUSE  job numérico do campo (C++, fora do thread principal)
  [4] PERCEPTION      mentes do HotSet leem Éter + sensores -> BeliefDelta
  [5] MEMORY WRITE    episódico -> beliefs; embeddings em lote; consolidação dormindo
  [6] APPRAISAL       drives + personalidade + metas re-pontuadas (utility)
  [7] DECISION        BT (estrutura) x Utility (escolha entre concorrentes)
  [8] PLANS/ORDERS    formação, esquadrão, pedidos a companions, obras (SlowSim)
  [9] ACTIONS         ações atômicas emitidas como intents validados
  [10] RESOLVE        combate/física/movimento: regras determinísticas aplicam
  [11] COMMIT         journal de tick (hash de estado por sistema) -> Crônica
  [12] ADAPTATION     bandit atualiza recompensas; Diretor avalia; CounterProfile grows
  --- assíncrono, fora do tick ---
  [A] LLM ORACLE      propostas enfileiradas por prioridade, devolvidas como evento no tick
```

`[7]` e `[10]` são separados de propósito: a mente **propõe**, a regra **dispõe**. Um boss
que "decide" causar 400 de dano causa o que a tabela de material permite.

## 1. Camada 1 — Estrutura de decisão: Behavior Tree + Utility

**Runtime BT (GDScript, sem Node por nó).** Implementação em `src/ai/behavior/`:

```gdscript
class_name BtNode extends RefCounted          # base: tick(bb, ctx) -> Status
enum Status { RUNNING, SUCCESS, FAILURE }
# compósitos: Sequence, Selector, Parallel(policy), Mutate(retry)
# folhas: ActionLeaf(descriptor), ConditionLeaf(descriptor)
# decorators: Inverter, Cooldown, Timeout, SubtreeGuard, MemoryGate  <- chave
```

Regras de engenharia `[DECIDED]`:

- Nós são **instanciados por espécie/archetype, não por entidade**. Uma BT `.tres` é
  compartilhada por 1000 lobos; o estado vivo mora no `Blackboard` por entidade (dicionário
  tipado + slots fixos). Zero `Node` na SceneTree para IA.
- `Status.RUNNING` só é permitido em folhas de *movimento/tempo* (locomotion, chant,
  search). Toda folha lógica deve resolver em 1 tick — sem isso, o BT fica injogável de
  debugar.
- Cada nó tem `budget_us` medido; o `bt_debugger` mostra a trilha de um tick (árvore +
  status + tempo), e um `SubtreeGuard` aborta sub-árvore estourada e devolve FAILURE com
  motivo (*fail-visible*, nunca "escolhe a primeira" silenciosamente).
- **`MemoryGate`** é o conector entre BT e memória: um galho só abre se uma crença
  satisfaz um predicado (`believes(actor_of(DeedKind.Kill, chieftain), confidence>0.6)`).
  É assim que "lembrar" muda comportamento sem if espalhado.

**Utility AI para escolher *qual* tentativa.** A BT diz "esta criatura precisa de
segurança"; o conjunto de *como* é pontuado por utility em `src/ai/utility/`:

```
score(a) = Σ w_i · curve_i(x_i) · gate_i     (multiplicador zero = veto duro)
```

- `curve`: `linear`, `exp`, `sigmoid`, `quadratic`, `step`, `bell` (curvas de resposta
  calibradas por `.tres`, nunca hardcoded).
- `consideration`: confiança da crença, distância, energia, medo, raio de aliados,
  **histórico da tática** (saída do bandit, §4), credibilidade do boato, temperatura,
  `AetherField` local (ex.: fogo: medo de lobos queimados sobe).
- `scorer` roda por *taskset* com `refresh_hz` diferente por papel (boss 20 Hz, villager
  5 Hz, herd 1 Hz) e histerese de troca (`min_lead`, `min_interval`) para evitar
  flip-flop — o defeito clássico de utility AI.

Híbrido `[DECIDED]`: **BT dirige, Utility escolhe**. BT garante estrutura narrativa e
recuperação (fugir → esconder → regressar); utility garante que "fugir" signifique algo
específico e contextual (norte porque lá tem aliados, e não porque o vetor era o primeiro).

## 2. Camada 2 — Memória (o que torna I1–I8 possíveis)

Quatro formas, cada uma com custo O(1) amortizado no hot path:

| Forma | Conteúdo | Escrita | Leitura |
|---|---|---|---|
| **Episódica** | `MemoryAtom{tick, kind, actors[], subj, obj, where(Éter cell), affect, confidence}` | ring buffer por mente, N=256 `[TARGET]`, com *eviction por relevância ponderada* (não FIFO puro) | scan linear curto + índice semântico por embedding |
| **Semântica (crenças)** | `Belief{predicate, value, confidence, source, last_reinforced}` — "X matou Y", "fogo é perigoso", "o norte é hostil" | consolidação da episódica + testemunho + boato | predicado → slot O(1); é o que o BT lê |
| **Pessoalidade** | vetor OCEAN-like + traumas acumulados + vieses (0-1) | deriva de histórico (incremental), nunca sorteada e esquecida | pondera `w_i` do utility e limiares de medo |
| **Procedural** | táticas aprendidas (`TacticBank`) — "como", não "o quê" | bandit, §4 | score de ações |

**Consolidação.** Toda mente "dorme": quando `HotSet` reexpande ou em `SlowSim`, um passo
barato (não é LLM) comprime episódios em crenças, promove boatos, decai confiança e
*deriva personalidade* (ex.: repetidas derrotas sem apoio aumentam `cautiousness`). É o
mecanismo que permite 1000 mentes com memória de qualidade sem 1000 buffers infinitos.

**Recall semântico.** Embeddings locais (modelo pequeno, §5) indexam episódios e a
Crônica. Uma mente recupera "a última vez que vi alguém com esta cicatriz" por vizinhança
vetorial, e o resultado entra como **candidato com confiança**, não como verdade.

**Grounding `[DECIDED]`, não negociável.** Nenhuma string entra como crença sem passar por
`BeliefVerifier`: os *slots* de uma claim (atores, ato, lugar, época) são resolvidos no
ledger. Se um ator não existe ou a relação viola invariantes, o claim vira `Rumor` com
credibilidade rebaixada — e boatos *podem* ser falsos de propósito: é feature social, não
bug. O que o verifier impede é boato falso virar fato autoritativo.

**Influência.** Dois mecanismos separados: `InfluenceMap` (grade 2D por canal: ameaça,
presença, ruído, controle de facção — derivado do Éter, atualizado em job) para
táticas/rotas, e `TerritoryGraph` (grafo de vãos, §6) para decisões estratégicas de
facção. Nenhum agente "escolhe lugar aleatório"; escolhe célula com score.

## 3. Camada 3 — LOD de simulação: como 1000 mentes cabem num frame

```
  HOT      <= ~48 mentes      tick 20 Hz completo: BT + utility + episódico + LLM elegível
  WARM     <= ~256 mentes     tick 5 Hz: BT podado, crenças resumidas, sem LLM
  AMBIENT  ~2000              tick 1 Hz: só drives + rotas + herd (locomotion agregada)
  SIM      resto do mundo     SlowSim: distribuição sobre {meta, local, humor, pop}
```

- Reexpansão: ao sair de `SIM`, a mente é amostrada **da sua própria distribuição** e
  reconciliada com a Crônica do intervalo (o que o SlowSim decidiu sobre ela), gerando
  episódios coerentes em vez de estado congelado.
- Corte de HotSet por **salience** (proximidade do jogador × quem tem dívida com
  jogador × quem está em tarefa com prazo), não só por distância: o fazendeiro que te
  odeia a 600 m pode ser HOT; o porco a 8 m pode não ser.
- **Governor de budget** (`budget_governor.gd`): mede `p99` do tempo da IA por tick e
  corta por prioridade (WARM→AMBIENT→SIM), nunca o HOT de um jogador. O corte é visível no
  overlay — um sistema que silencia degradação é um sistema que apodrece.

## 4. Camada 4 — Adaptação (I3) e o Diretor

**Bandit contextual por arquétipo.** `arm = (context, tactic)`, `context =` quantizado de
 `{hora, bioma, cobertura, composição do grupo-alvo, presença de magia, alarme}`;
recompensa = dano eficaz por segundo, sobrevivência do agente, objetivo territorial.
UCB1 com *decay de memória longa* para não ficar travado em estratégia boa de um mundo que
mudou. Por que bandit e não RL: precisa aprender em **5–20 encontros**, em dezenas de
milhares de instâncias separadas, sem offline data, e ser explicável no inspector.
Policy-gradient aqui seria teatro.

**`CounterProfile` por facção.** Estatísticas de causa de morte de agentes → menu de
contramedidas com **custo em recursos da facção** (do SlowSim) e tempo de implantação.
Adaptação sem custo seria truque; com custo vira geopolítica.

**Estilo do jogador.** `StyleFingerprint` (16 dimensões, janelas de 10 min / 1 dia / era)
+ `SignatureRisk` (probabilidade de ser reconhecido: quantas testemunhas, quão
distintas, quanta notoriedade). Stealth repetido no mesmo vale *aumenta* a vigilância
local — porque as testemunhas têm memória, não porque um script liga um flag.

**Diretor (agente com metas próprias).** Entra como um `Mind` normal, mas com ações que só
ele pode emitir (spawn de patrulha, gerar boato, abrir mercado negro, mandar um emissário).
Objetivo: maximizar **tensão significativa** (eventos com escolhas de trade-off), sob
restrições duras: (a) nunca negar agência (não punir sem pista legível); (b) *histerese*
para não reagir a um único encontro; (c) teto de dificuldade por sessão; (d) nunca gastar
recurso que a facção não tem. Transparência: a lógica do Diretor é legível na Crônica como
"o senhor da guerra decidiu reforçar os desfiladeiros porque o inimigo usa fogo" — o
jogador aprende o sistema e, portanto, pode jogá-lo.

## 5. Camada 5 — Oráculo local (LLM + embeddings), opcional por design

**Papel.** Dar *superfície* a decisões já tomadas e *propostas* a estruturas já validadas.
Nunca: coordenada, dano, estado de mundo, atribuição de culpa.

**Implementação.** `native/af_mind/` = GDExtension C++ ligada a **llama.cpp** (MIT) com
GGUF, backend **Vulkan** (RDNA e NVIDIA em Windows; ROCm opcional) `[CLAIMED: llama.cpp
Vulkan funciona em RDNA; medir no rig de referência]`. Dois packs:

| Pack | Papel | Tamanho alvo `[TARGET]` | VRAM `[TARGET]` |
|---|---|---|---|
| `mind-small` | sempre ligado: resumo de memórias, rótulos de boato, falas curtas de ambient | 1.5–4B Q4_K_M | ~2–4 GB |
| `mind-voice` | diálogo com jogador, negociação, cartas/decretos de facção | 7–9B Q4_K_M | ~6–8 GB |

Configuração obrigatória: `--reasoning off` / `thinking_budget=0` `[DECIDED]` (raciocínio
ligado triplica latência por token e é inútil aqui — a decisão estrutural já veio das
camadas 1–4; a tarefa do modelo é *verbalizar*). Sem `--chat-template-kwargs` como
mecanismo: a flag de reasoning entra na carga do template em C++, não por argumento
de chat-template.

**Contrato de saída.** Decode gramatical (GBNF/JSON schema) contra um `MindSchema` por
papel:

```jsonc
// proposta de meta (não autoritativa)
{"goal":"secure_revenge","target_actor":"p:3f2a","method":"petition_elders",
 "confidence":0.62,"reason_key":"witnessed_kill_of:chief","urgency":0.4}
// fala
{"line":"...","intent":"warn","price":"a favour","truth_tags":["saw:deed#1842"]}
```

Validação: `actor_id`/`deed_id` **devem** existir no ledger (ids fechados, o modelo escolhe
entre candidatos *fornecidos* — nunca gera id). Fora do schema → descartado e contado no
`oracle_health` (métrica visível, não log escondido).

**Budget de inferência.** Fila com prioridades (`player-dialogue` > `faction-letter` >
`ambient-line` > `consolidation`); preempção em `frame_budget`; no máximo N jobs por
segundo; **nenhuma inferência durante chefes** (o GPU divide com render — contenção é o
risco real, §6). Se a fila estourar, cai item por prioridade e a camada degrade para
*template slots preenchidos por memória*, rotulado no menu como **"modo de IA reduzida"**
(`[DECIDED]`: sem fingir que é a mesma experiência).

**Determinismo em mundo determinístico.** LLM não é bit-exactamente reproduzível. Saída
vai para o `oracle_cache` indexado por hash de (prompt, modelo, params, seed) **e é
gravada no journal do tick** como evento. Replay/CI sempre lêem o cache — o modelo é
substituível sem quebrar teste, e o co-op não precisa de modelo no cliente.

**Privacidade e licensing.** Pesos **nunca** entram no repositório: `ModelPackFetcher`
baixa por URL+SHA256, exibe a licença por modelo (muitos são Apache/MIT, alguns têm
restrição de uso — exibir é requisito), e o jogo funciona com packs ausentes. Nenhuma
inferência envia dados de rede; telemetria de estilo fica em disco local com toggle.

## 6. O que cada camada é autorizada a fazer (tabela de autoridade)

| Pedido | Camada 1 BT/Utility | Camada 2 Memória | Camada 4 Adaptação | Camada 5 LLM |
|---|---|---|---|---|
| Mover-se, mirar, timing de esquiva | **SIM** | fornece contexto | não | **NUNCA** |
| Escolher tática entre candidatas | **SIM** (score) | — | **SIM** (prior via bandit) | propõe *narrativa* da tática |
| Criar/alterar crença | não | **SIM** (via verifier) | não | propõe, verifier decide |
| Aplicar dano / mudar voxel | **NUNCA** (regras de resolução) | não | não | nunca |
| Gerar texto para o jogador | não | fornece fatos | fornece motivo | **SIM** (schema) |
| Emitir obra de facção | não | não | **SIM** (com custo) | nunca |

**Testes da IA** (mesmos formatos do §08): `sim` determinístico (20 lobos × 1000 ticks com
seed → hash de estado), `replay` contra journal golden, invariantes do ledger no commit,
propriedade ("crença com confiança 1 só se witnessou"), e um *eval* de LLM offline
(precisão de grounding de ids, % de saídas fora do schema) rodando só quando o modelo está
presente — reportado como número, não como "pareceu bom".
