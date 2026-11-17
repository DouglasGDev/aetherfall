# 08 — Roadmap, riscos e licenças

## Princípio de fase

Nenhuma fase termina por calendário; termina por **gate verificável**. Gate = comando
headless + critério numérico + documento derivado do código preenchido. Fase bloqueada =
não se começa a próxima (e a exceção é registrada *antes* de escrever o código, não depois).

```
P0  Fundação determinística      → "o mundo existe e o tick é auditável"
P1  Mentes + memória            → "o mundo lembra"
P2  Trama + facções + ecologia  → "o mundo age sem você"
P3  Adaptação + Diretor         → "o mundo joga contra você"
P4  Oráculo local (LLM)         → "o mundo fala"
P5  Co-op seamless              → "quatro causas, um mundo"
P6  Progressão + chefes + Crônica UI
P7  Conteúdo, balanceamento, plataformas, alpha público
```

### P0 — Fundação `[gate mais importante do projeto]`

Entregas: `project.godot` pinando 4.7.x; `SimClock` 20 Hz + `EntityStore` SoA + tick
journal com hash; voxel bake-off (§06.4) decidido com números; gerador determinístico de
um bioma com rios e 2 sites; `CharacterBody3D` em 1ª/3ª pessoa; combate corpo-a-corpo
feio mas real; save/load atômico de chunk+delta.

Gate: `af-bench --scenario boot_walk_10min` roda em headless com hash de estado estável
entre 3 execuções; **nenhum** número de FPS ainda prometido além da tabela do bake-off;
`docs/engine/simclock.md` escrito a partir do código.

### P1 — Mentes e memória

Entregas: BT runtime + blackboard + utility scorer; `MindStore`; episódico+crenças+
verifier; `AetherField` com 6 canais, difusão em thread, imprint de morte/dano/som/fogo;
`MindsInspector` funcional (isto é *parte de P1*, não ferramenta opcional: sem
observabilidade a IA apodrece sem que ninguém veja).

Gate: cenário "lobo vê sangue → investiga → foge se outnumber" passa em 20 sementes ×
1000 ticks com hash igual; invariante "crença com confiança 1.0 só se testemunhou" com
zero violações; budget HOT ≤ `[TARGET]` 2,5 ms medido (número real entra aqui, não no §06).

### P2 — Trama (SlowSim)

Entregas: facções com metas/recursos/obras via `EditJournal` (mesma porta do jogador);
economia de aldeia; ecologia (população, predação, migração); `Rumor` com credibilidade;
`CatchUp` offline com teto de tempo de load.

Gate: 30 dias de mundo em 60 s de wall-clock em headless; nenhuma obra de facção
invalida pathfinding (`reachability_check` verde); aldeia sem jogador cresce **ou**
mofa de forma divergente entre sementes (se tudo converge, o sim é decorativo).

### P3 — Adaptação

Entregas: `StyleFingerprint`, `TacticBank` (bandit), `CounterProfile`, `ImmunityProfile`,
`Director` + `FairnessGovernor`.

Gate: adversário que enfrenta 10 sessões scriptadas de "spam de fogo" chega em ≥6 delas a
usar contra-medidas distintas, com custo pago em recurso de facção; e o *mesmo* adversário
contra 10 sessões variadas **não** escalona dificuldade (anti-frustração mensurável);
motivo de cada decisão do Diretor legível na Crônica.

### P4 — Oráculo local

Entregas: `native/af_mind` (llama.cpp/Vulkan, `--reasoning off`), schemas+gramáticas,
`oracle_cache`, embeddings e `semantic_index`, diálogo com grounding, cartas/decretos de
facção, `degraded_templater` + toggle "IA reduzida", `ModelPackFetcher` com licença por
modelo.

Gate: `ai_eval` reporta % de saídas válidas conforme schema, % de claims groundados,
p95 de latência por prioridade, e contenção de GPU durante combate (medido no rig de
referência, não em hardware de dev alheio); jogo 100% jogável com `models/` vazio e sem
rede; nenhuma requisição de saída do processo além do fetch explícito de modelo.

### P5 — Co-op

Entregas: `NetRegistry` + delta codec + interest; predição local; `attribution`
multi-autor; late-join <2 s; migração de host; dedicado `--headless --server` idêntico.

Gate: 2 clientes + dedicado em CI; traição de um jogador registrada com autores distintos
e opiniões distintas de 3 NPCs; host morto no meio de uma batalha → novo host continua sem
perder deeds (hash do ledger igual).

### P6/P7 — Progressão, chefes, conteúdo, release

Thresholds com ≥3 rotas cada; 6 chefes de referência (pelo menos 3 não-combatíveis);
Crônica scrubável na UI; estilo visual final; port (Windows/Linux/macOS), itch.io e Steam;
documentação de modding; alpha público com telemetry **local** e opt-in explícito.

## Riscos e mitigação (os reais, não os educados)

| # | Risco | Prob. | Impacto | Mitigação concreta |
|---|---|---|---|---|
| R1 | **Escopo**: "Veloren + Dwarf Fortress + LLM" é 3 jogos | Alta | Fatal | Cada fase tem gate *subtrativo*: P1 não adiciona conteúdo; feature nova só entra se reduzir outra. MVP de 6 meses publicado no itch. |
| R2 | Custo de CPU de 1000 mentes | Alta | Alto | LOD + budget governor desde P1 (não como otimização tardia); benchmark de simulação em headless como teste de CI; corte por salience, não por distância. |
| R3 | Contenção de GPU entre LLM e render | Alta | Médio | Inferência fora do tick, pausa em combate de chefe, orçamentos por prioridade, modo CPU-only, modo IA reduzida. Medir, não argumentar. |
| R4 | LLM alucina e polui a memória | Média | **Alto** (corrói a confiança do jogador no sistema) | `BeliefVerifier` com grounding em ids fechados; saídas não-groundadas viram `Rumor` com credibilidade; cache + journal para replay; eval contínuo com número publicado. |
| R5 | IA "mágica" e não reproduzível | Média | Alto | Autoridade nas camadas determinísticas; LLM é *proposta*; hash de estado por tick; golden journals. |
| R6 | Player vs. adaptação: comunidade chama de "rubber-banding" | Média | Médio | `FairnessGovernor` com hysteresis, teto por sessão, e **transparência** (motivo na Crônica + setting para desligar adaptação hostil e manter a/ecologia). |
| R7 | NAT traversal em co-op | Alta | Médio | Host direto + `bouncer` de introdução (sem lógica de jogo) + dedicado; documentar port-forward; nada de servidor de jogo obrigatório (é requisito de licença e de princípio). |
| R8 | Mudança de gerador quebra saves | Média | Fatal p/ confiança | `gen_version` por região + hash comparado + migrações com teste ida-e-volta; `af_fsck` no boot. |
| R9 | Uma pessoa (você) carregando o projeto | Alta | Fatal | Módulos com README e testes próprios, superfícies pequenas, P0-P2 entregáveis independentes que um contribuidor pode assumir; docs derivados de código. |
| R10 | Licenças (MIT × GPL) | Baixa, se ignorada | **Fatal legal** | Ver §Licenças. `license-audit.yml` quebra a CI. |

## Licenças — ponto que precisa de decisão explícita

**Veloren é GPL-3.0 (código) e CC-BY-SA-4.0 (assets)** — verificado no repositório deles.
MIT **não** permite incorporar código GPL num projeto MIT. Portanto:

1. **Zero derivação.** Nem uma linha de Rust, nem `.ron` de assets, nem meshes, nem
   texturas, nem nomes de arquivos de dados deles. Inspiração de *sistemas e idéias*
   (que não são protegidos por copyright) é o que fazemos — e isso é legítimo.
2. Nada de "port" de algoritmo transcrito. Algoritmos descritos em literatura/papers são
   reimplementados a partir da descrição, com ADR dizendo a fonte.
3. **Código MIT compatível permitido** (verificado caso a caso): Godot (MIT), Voxel Tools
   (MIT), llama.cpp (MIT), SQLite (public domain), GUT (MIT). Cada um registrado em
   `THIRD_PARTY_LICENSES.md` + CI que falha em GPL/AGPL/CC-BY-NC e em modelos com
   restrição de uso não declarada.
4. **Modelos GGUF fora do repositório**, baixados explicitamente pelo usuário, com licença e
   SHA256 mostrados. Nunca "o jogo baixa sozinho sem avisar".
5. **Assets CC-BY-SA 4.0** no nosso jogo, para manter a mesma ética de compartilhamento
   que o código nos dá crédito e vice-versa. Fontes com OFL.
6. Se um dia usar algo GPL de verdade (ex.: uma lib de rede GPL), a alternativa é ou
   trocar a lib ou o projeto vira GPL-3.0 — decisão a tomar *antes*, nunca em merge.

## Critério de sucesso do design (auto-avaliação honesta)

O design está certo se, no P3, um tester conseguirá responder "o que eu fiz de mais
inesperado para o mundo?" citando três fatos **com link para o deed no ledger** e o mundo
responder com uma mudança que ele não pediu e não previu, mas consegue explicar. Se a
resposta for "o spawn de inimigos ficou mais difícil", falhamos a tese — e o culpado será
o `Director` sem transparência, não a ideia.
