# 06 — Arquitetura técnica em Godot 4

Base: **Godot 4.7.x estável** (4.7.2 no momento deste documento; 4.8 em beta) `[CLAIMED:
versões lidas em godotengine.org]`. Política `[DECIDED]`: fixar *minor* por milestone,
pin explícito em CI, upgrade só com a suite de replay verde.

## 1. Divisão de linguagens — e a resposta honesta sobre C#

| Onde | O quê | Linguagem |
|---|---|---|
| SceneTree, UI, gameplay, sistemas de alto nível, ferramentas de editor | 90% do código de jogo | **GDScript** (static typing obrigatório, `@export` tipado, `class_name` por arquivo) |
| Voxel (codec, meshing, difusão do Éter), nav-graph, bandit, store/ledger, codec de rede, bindings LLM/embeddings | hot loops numéricos e I/O de alto volume | **C++ via GDExtension** (`native/af_*`) |
| C# | — | **NENHUM** no plano atual |

**Por que não C# (e quando ele voltaria a ser cogitado).** O par de linguagens
GDScript+C# exige manter dois builds do engine (standard e mono) e dois runtimes na
distribuição — um custo que paga quando o time é grande e o código de gameplay é escrito
por contribuidores que já são .NET. Nosso hot path *não* é C# de qualquer forma: voxel,
difusão, pathfinding e inferência pedem C++ nativo, e GDScript cobre a camada de regra com
iteração 5× mais rápida em design. C# passaria a valer a pena **somente** com um número:
um profiler mostrando que um sistema de regra (não nativo) estoura o budget e que a
reescrevê-lo em C++ custaria mais que manter o dual-build — decisão registrada em ADR com
o profile anexado. `[DECIDED]`

## 2. Dois relógios, uma autoridade

```
Engine.physics_ticks_per_second = 60   # Controladores/colisão do jogador local
SimClock                          = 20 Hz  # simulação autoritativa: IA, mundo, ledger, rede
Render                            = vsync  # interpolação a partir de snapshots anteriores
```

`SimClock` é um acumulador determinístico (`src/core/sim/tick_clock.gd`): recebe
`delta` do `_physics_process`, consome em passos fixos, **cap de 5 passos por frame**
(ultrapassar = queda de tick visível no overlay, nunca silent catch-up). Tudo que é
autoritativo — decisão de mente, voxel, dano, ledger, adaptação — acontece **só** dentro
de um passo de `SimClock`. O tick 20 Hz é o contrato: a rede, a Crônica, o replay de teste
e a IA vivem na mesma granularidade, o que é o que torna o sistema testável.

**Movimento de NPCs:** centenas de `CharacterBody3D` por região são caros e não são
necessários. NPCs são `RefCounted` no `SimWorld` com **varredura própria de AABB/esfera**
em C++ (o mesmo código vira o servidor dedicado); um `Node3D` de visual (sprite/mesh) é
posicionado por interpolação. O jogador local (e cada par de mãos que interage fisicamente:
corpos carregáveis, alavancas) usa `CharacterBody3D` + `move_and_slide`, com predição local.

## 3. Modelo de dados: SimWorld (data-oriented) + SceneTree (visual)

Godot não tem ECS. Não vamos fingir que tem nem adotar ECS de terceiros que quebra com
`Resource`. `[DECIDED]`: **armazenamento SoA por tipo de componente, com IDs de 32 bits
(`generation:index`) e sistemas como funções sobre máscaras de query**:

```gdscript
# src/core/sim/entity_store.gd  (esqueleto; a parte quente vai para C++)
class_name EntityStore extends RefCounted
var alive: PackedInt32Array                 # generation|index por slot
var kind: PackedInt32Array                  # archetype id
var hp: PackedInt32Array
var pos_x: PackedFloat32Array                # SoA: cache-friendly, serializável em bloco
var pos_y: PackedFloat32Array
var mind_id: PackedInt32Array               # índice para MindStore (-1 = sem mente)
var query_mask: PackedInt64Array            # bitmask de componentes
func query(mask: int, out: PackedInt32Array) -> void   # filtro em C++ quando quente
```

- **`SimWorld`** = fonte da verdade lógica (host). **`VisualWorld`** = nós na SceneTree
  sincronizados por *pool* de nós reusados (`node_pool.gd`), nunca `instantiate` por frame.
- Componentes de dados são `Resource` imutáveis (`.tres` de espécie, item, receita, BT,
  curva de utility, perfil de chefe) — carregamento sob demanda com `ResourceLoader.load_threaded_*`,
  e **`duplicate(deep)` proibido no hot path** (alocação/GC é o jitter nº 1 em GDScript).
- `WorldRoot.tscn` é o único lugar onde `Node` representa estado de mundo; UI e cena de
  jogador são trees separadas (`CanvasLayer` persistentes) para não serem afetadas por
  streaming de região.

## 4. Voxel: o que usar e com qual critério trocar

`[CLAIMED — medição pendente]` **Voxel Tools (Zylann), MIT, GDExtension C++ para Godot 4**
provê: armazenamento chunkado + streaming + LOD (Transvoxel), terreno "Minecraft-like" e
"smooth", instancing de folhagem, integração de física e colisões rápidas tipo voxel. É o
nosso backend de partida: ele resolve os 80% caros (streaming, LOD, malharia, formato).

Plano de decisão em P0 (**voxel bake-off**, 1 semana, critérios fixados antes de medir):

| Critério | Pesos |
|---|---|
| FPS em render-distance alvo com `AetherField` + 50 mentes HOT | 35% |
| Custo de edição local (write → mesh pronto) e por região suja | 25% |
| VRAM por região carregada / formato em disco | 20% |
| Suporte a "shapes" não-cúbicos por bloco (troncos/ruínas estilo Veloren) | 15% |
| Complexidade de build multi-plataforma | 5% |

Saída esperada: **Voxel Tools para terreno/stone/água** + **camada própria `BlockShapes`**
(C++/`.tres`) para blocos com geometria não-cúbica + folhagem via instancing; o
`AetherField` **não** é o voxel de terreno: é um volume paralelo de baixa resolução
(1/4 da grade), em `native/af_aether`, com difusão em `WorkerThreadPool` e *snapshots* por
região no save. Se o bake-off reprovar o meshing, o substituto é um mesher próprio em
`native/af_voxel` atrás da mesma interface `VoxelBackend` — por isso `src/world/chunks/
voxel_backend/` é uma **porta**, não um conjunto de chamadas espalhadas.

**Terreno procedural = Veloren-like, sem copiar.** Gerador determinístico a partir de
`(world_seed, gen_version, params)`: ruído domínios (continente/elevação/umidade/temperatura)
→ biomas → grafo de drenos e rios → *sites* (aldeias, ruínas, masmorras, minas) com
planner de layout paramétrico → estruturas → flora/fauna/população inicial → pré-generação
offline por região (`tools/af_pregen`) + validação de conectividade (todo site alcançável).
**`gen_version` é gravada por região**: mudar o gerador não invalida saves, porque só
delta é armazenado e o hash do chunk gerado é comparado (regiões inalteradas com hash
divergente disparam migração, nunca releitura silenciosa).

## 5. IA no motor, sem quebrar o motor

Detalhes de decisão em §04; aqui só o encaixe Godot:

- **`MindServer` (autoload)** = dono do scheduler: HotSet, LOD, budget governor, fila de
  oráculo, jobs. Mentes são dados + uma BT compartilhada, **não nós**.
- Nenhum acesso a `Node`/`get_tree()` dentro do passo de simulação de uma mente — a mente
  só lê/estrutura lógica. Toda emissão visual (animação, som, partículas) é **comando
  derivado** consumido pela `VisualWorld` depois. Isso é o que permite rodar a mesma IA em
  `--headless` e em teste de 10 000 ticks em segundos.
- Thread-safety: difusão, embeddings, meshing, bandit-update e *consolidation* rodam em
  `WorkerThreadPool` e só devolvem `Variant` imutável; nada de tocar o `SimWorld` a partir
  de thread — resultados entram por fila no próximo tick.
- **Oráculo:** `native/af_mind` (llama.cpp, Vulkan) com N slots e `n_gpu_layers` limitado
  por perfil de hardware; inferência nunca dentro de um tick (fila + evento de
  conclusão); contenção de GPU com render é o risco: durante chefe, `mind-voice` é
  pausado e o `mind-small` fica com orçamento mínimo. Sem GPU: modo CPU-only (mais lento,
  ainda local) ou `AI reduzida` (templates preenchidos por memória, rotulado como tal).

## 6. Networking co-op 1-4 (seamless, host-authoritative)

```
Transporte  ENet (SceneMultiplayer)  |  opcional: broker de introdução "af-bouncer"
                                       (sem lógica de jogo) p/ NAT; Steam transport
                                       GDExtension como opção futura
Autoridade  host único: SimClock 20Hz decide voxel, IA, dano, ledger
Canais      reliable: pedidos, deeds, eventos de mente, inventário, spawn/death
            unreliable: snapshot de estado (posição, anim, orientação) 3-10 Hz por prioridade
```

- **`NetRegistry`**: mapeia `SimEntityId` ↔ `net_id` ↔ nó visual; `MultiplayerSpawner`
  só para objetos de cena/UI/discutivelmente raros; entidades de mundo usam nosso codec
  delta (mais compacto que RPC por entidade e permite *interest management* por região +
  relevância: uma mente longe de todos os jogadores não é replicada, mas continua no host).
- **Predição:** apenas do próprio jogador (movimento, animação, intenção de interação) com
  reconciliação por snapshot e *lag compensation* limitada a hitscan curto; NPCs nunca são
  previstos — interpolados com buffer de 100 ms `[TARGET]`.
- **Pedidos validados no host**: propriedade, alcance, LOS/ouvido, cooldown, estado do
  ledger ("você não pode entregar um item que não tem"), limite por segundo. Erro de
  validação volta como *motivo* estruturado (o UI mostra por que foi bloqueado — transparência
  que também ajuda anti-cheat).
- **Late-join/host migration:** snapshot comprimido (zstd) por fatia (chunks relevantes +
  estado autoritativo + resumo de mentes + ledger recent + perfil de jogador) com
  descarregamento gradual; alvo `[TARGET]` <2 s até render. Migração: o ledger é o mundo,
  é replicado incrementalmente a todos os peers (cada um tem réplica em disco) — o novo
  host assume sem "perder" nada; a interrupção entra na Crônica com duração real.
- **Dedicated server = o mesmo binário**: `aetherfall --headless --server --world X`, que é
  também o alvo dos testes de integração de 2 clientes na CI.

## 7. Persistência

```
saves/<world_id>/
  manifest.json          schema_version, gen_version, seed, horas de mundo, hashes
  chunks/                delta journal por região (zstd), só edições
  aether/                snapshots por região + journal de imprints
  chronicle.sqlite3      Deed / Consequence / Commitment / Rumor / índice de embeddings
  minds.sqlite3          beliefs, episódios consolidados, personalidade, tactic_bank
  sim/journal/           tick journal (para Crônica + replay determinístico + migração)
  players/<uid>.afp      jogador, inventário, progressão, fingerprint
  experiments/           o que a IA tentou e falhou (bandit stats, p/ debug humano)
```

Escritas **atômicas** (tmp + rename) por arquivo; fsync nos commit-points; nunca `delete`
de journal ativo (compactação é *swap* com verificação). `af_fsck` valida o ledger contra
invariantes (morto não testemunha; atribuição com `actor` válido; confiança ∈ [0,1];
hash de tick consistente) e roda na CI e no boot de save com `--verify`. Migrações de
schema versionadas, uma por arquivo, com teste de ida-e-volta por versão.

## 8. Orçamento de performance `[TARGET — nada medido ainda]`

| Subsistema | Budget/frame (60 fps, 1 host solo) | Como medimos |
|---|---|---|
| Render + voxel streaming | 8,0 ms | profiler + bench de cena padronizada |
| `SimClock` (física/lógica/regras) | 3,0 ms | hash+tempo por sistema no journal |
| IA HOT (48 mentes) | 2,5 ms | `MindServer` stats, p99 por tick |
| Difusão do Éter + influence maps | 1,0 ms (thread) | job timing |
| Rede (codec+envio, host) | 1,0 ms | contadores por canal |
| Salva/carrega em background | sem spike >20 ms | janela de autosave no overlay |
| Oráculo LLM | fora do frame; fila ≤200 ms/job | `oracle_health` |

Alvo de imagem: 60 fps solo em `[TARGET: RX 9060 XT 16 GB / RTX 4060]`, 96–160 blocos de
render-distance com LOD + névoa/atmosfera; 30 fps como *floor* em máquina de 6 GB VRAM sem
modelos carregados. **Nenhum desses números é medição** — a primeira coluna `MEASURED` é
preenchida no gate de P0 e a tabela vira documento derivado de código.

## 9. Ferramentas próprias (sem elas, o design não é ajustável)

`af-gen-preview` (mapa de biomas e sites antes de carregar o mundo), `af-balance-editor`
(curvas de utility, receitas, tables de loot, com hot-reload), `MindsInspector` (BT em
execução, blackboard, crenças com confiança, episódios, motivo do Diretor), `af-chronicle-scrub`
(time-lapse do mundo), `af-bench` (cenários de simulação com hash por tick),
`af-pregen`, `af-fsck`. Todas as ferramentas são cenas normais sob `src/tools/` para que
mods possam usar a mesma superfície.
