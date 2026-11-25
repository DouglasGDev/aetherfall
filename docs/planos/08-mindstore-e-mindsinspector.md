# 08 — `MindStore` e `MindsInspector`

Duas linhas não marcadas do checklist P1 (docs/melhorias-status.md:692-695), decididas pelas linhas docs/melhorias-status.md:47-47 e :48 da tabela do prompt master. Nada aqui roda engine; nenhum número de desempenho é publicado.

## 1. Premissa nomeada por peça

- `MindStore`: muda de dono a **posse das coleções** — hoje `mind` é campo do lobo (src/entities/wolf.gd:169) e nasce em `setup()` (:313). Só vale se `episodic`/`beliefs`/`relations` (src/ai/mind.gd:18-20) passarem a ser indexados por `Mind.identity` (:12) fora da entidade, com o contrato de save (`to_dict`/`from_dict`, :134-167) e a soleira que o BT obedece, `believes() >= 0,35` (:104-105, consultada em src/entities/wolf.gd:944) intactos.
- `MindsInspector`: torna visível a **composição da pontuação**, não o resultado. O `UtilityScorer` já calcula por consideração e guarda em `_breakdown` (src/ai/utility_scorer.gd:44, preenchido em :76), mas o F3 só imprime `top_line()`, cortado em 3 partes (:123-129), via `_top_line` (src/entities/wolf.gd:250, gravado em :863 e impresso em :1350).

## 2. Estado real (lido, não medido)

- `Mind`: `EPISODIC_CAP = 24` (src/ai/mind.gd:7), FIFO com consolidação do átomo mais velho (:44-45). `_consolidate` converte só `hurt` e `saw_player` (:61-68); `hit_land`, `win` e `fed` (src/entities/wolf.gd:782, :1329, :1334) nunca viram crença. Decaimento `exp(-0,14 × min)` com corte em `0,02` (src/ai/mind.gd:8, :108-119). O save perde a origem da crença: `to_dict` grava só `confidence` (:142-144) e `from_dict` escreve `"loaded"` (:167).
- Transitório por lobo, e fora da projeção do hash (mandato 3 do AGENTS.md): cache de rastros `_checked_scents` (src/entities/wolf.gd:242) com teto de 32 células, 30 s e renovação 0,06 (:32-34), limpo no load (:1408), além de episódios e relações. Mover posse não muda isso sem re-medição.
- Quem lê hoje: o lobo (`last_atom` src/entities/wolf.gd:462, :470, :487, :555; `temperament` nas curvas :809, :821, :847; `decay` por tick :893), o oráculo via `w.mind.to_dict()` (src/ai/mind_oracle.gd:132), o HUD via `debug_line()` (src/entities/wolf.gd:1346-1351) e o save (src/main.gd:1014-1016, src/entities/wolf.gd:1360). Nenhuma outra classe segura uma `Mind`.
- Caminho exato do F3: src/main.gd:182-183 injeta `stats_provider` e `wolf_provider` = `targets_under_crosshair` (:813-818, os vivos dos 5 de :9) → src/ui/hud.gd:273-281 imprime um `w.debug_line()` por mente e anexa `ia: ` + `narration_provider(w.identity)` → src/main.gd:193 → `narration_of()` (src/ai/mind_oracle.gd:96-97). Corpo do overlay: src/ui/hud.gd:245-281 (37 linhas); flag :45, liga/desliga :164-169.

## 3. Por que os vereditos estão corretos hoje

- `MindStore` = "metade feito": a consolidação existe e é persistida (src/ai/mind.gd:44-45, :61-68, contador :148 e :157), mas vive dentro da entidade; `MindStore`/`mind_store` não ocorre em `src/` — só como intenção de design (docs/design/07-project-structure.md:124, docs/design/06-godot-architecture.md:60, docs/design/08-roadmap-risks-licensing.md:67).
- `MindsInspector` = "não existe": nenhum `.gd`/`.tscn` com esse nome; o arquivo planejado está em docs/design/07-project-structure.md:155. O que cobre é texto do F3, não inspector.
- O que tornaria os vereditos falsos: (a) coleções vivas fora do `Wolf`, com round-trip de save preservado; (b) linha por consideração (cru→moldado→peso→veto) e trilha do BT — hoje o guard só devolve `last_us`/`trips` (src/entities/wolf.gd:1356-1357) e a trilha por nó prometida em docs/design/04-local-ai-architecture.md:50-52 não existe.

## 4. As duas formas de inspector, com custo

- **F3 estendida**: reaproveita o roster (src/main.gd:842-843), o laço por mente (src/ui/hud.gd:273-281) e a linha de narrativa. Custo em código que já existe: uma função ao lado de `debug_line()` (src/entities/wolf.gd:1346-1351) devolvendo o `_breakdown` inteiro (src/ai/utility_scorer.gd:109-110), mais 1 a 3 linhas no laço do HUD. Nada é jogado fora.
- **UI nova** (`minds_inspector.tscn`): cena + tecla + três providers injetados (src/main.gd:183, :189, :191) + render, duplicando o que `debug_line()` já imprime. Linhas reaproveitáveis: nenhuma, porque o arquivo não existe para medir.
- **Recomendação: F3 estendida** — é a mais barata que não desperdiça o existente e a única que fecha dentro de `--check-only` + suíte sem cena nova. A UI só se justifica se a trilha por nó do BT for exigida.

## 5. Constraint do mandato 2

A peça que garante a separação hoje é `_narrations` (src/ai/mind_oracle.gd:47), escrita em :176 e lida só por `narration_of()` (:96-97) → HUD (src/main.gd:193 → src/ui/hud.gd:276-277). É verdade por fiação, não por verifier (docs/melhorias-status.md:68-68). O inspector **mostra, não decide**: pode ler `narration_of()` e as coleções; não pode chamar `reinforce()`/`remember()` (src/ai/mind.gd:86, :39) nem tocar `intent`. A escrita continua só nas transições do lobo (src/entities/wolf.gd:637, :782-783, :948-953, :1302-1304, :1329, :1334).

## 6. Gate em headless

- Compilação: `godot --headless --path . --check-only --script src/ai/mind.gd` (e por arquivo alterado). Suíte: `godot --headless --path . tests/smoke_test.tscn`. Contagem publicada na revisão atual (`9f3622b`): **236 checagens / 0 falhas / 37,1 s** (docs/evidence/ether-massa-conservada/clone-suite.log:311, idem docs/evidence/ether-massa-conservada/readback.log:9 e as contagens de erro em :37). A rodada anterior, do `a8967e0`, é a de 232 / 0 / 33,7 s (docs/evidence/third-person-carry/clone-suite.log:307, readback.log:6 e :22).
- Runner dedicado em `tests/`, no formato de tests/aether_reactions_test.gd, com critérios que PODEM falhar: (i) no round-trip de save, episódios (≤ 24), crenças e `trust` dos 5 lobos iguais aos valores antes do dump — checagem já existente em tests/smoke_test.gd:2832-2835, que o store não pode regredir; (ii) número de linhas de mente impressas == número de lobos vivos; (iii) considerações impressas == tamanho do `_breakdown` da opção escolhida, com veto valendo zero e não pontuando (src/ai/utility_scorer.gd:68-75).
- Toda checagem nova **soma** na última linha: queda de contagem é `SCRIPT ERROR` matando passo, não sucesso.

## 7. Custo — as quatro perguntas

- Roda por quê? O F3 monta, por invocação do refresh (cadência não verificada neste plano), uma string de 3 linhas por mente (src/entities/wolf.gd:1346-1353). O `to_dict()` do oráculo aloca Array+Dictionary por mente por pedido, com 1 pedido em voo e recuo de 30 s (src/ai/mind_oracle.gd:13, :64-71, :131).
- Quantas entidades? 5 lobos (src/main.gd:9), só os vivos (:813-818), 1 jogador.
- Aloco no caminho quente? `mind.decay()` varre `beliefs` a cada tick (src/entities/wolf.gd:893) e o tamanho dessas coleções **não medido**; o indexamento extra de um store fora da entidade também não.
- Como sei que ficou melhor? Pelo log do runner de §6 — que ainda não existe. Este plano não publica número de custo.

## 8. O que NÃO fazer, commits atômicos, citações que não conferem

Não: `MindStore` como *pass-through* que só repassa à `Mind` do lobo (muda o acesso, não a posse); episódios dentro da projeção do hash sem re-medição; oráculo escrevendo crença ou intenção; `.tscn` de inspector antes de estender o F3; `BeliefVerifier`, embeddings, `HotSet`, facções, `SlowSim`, replay — nada disso existe em `src/`.

Commits atômicos: (1) F3 com o `_breakdown` completo + checagem (iii) de §6; (2) extrair o resumo de mente de `debug_line()` sem mudar comportamento; (3) `MindStore` dono das coleções com round-trip de save checado; (4) atualizar docs/melhorias-status.md:47-48 e :668-671 com o veredito novo. Um número por commit.

Citações que não conferem: o briefing apontava as linhas 27-28 da tabela do prompt master — as reais eram `docs/melhorias-status.md:29-29` e `:30` na numeração em que este dossiê foi escrito (a `:27` é a linha de separação do cabeçalho); hoje as mesmas duas linhas são `:47-48`. Naquela numeração, `docs/melhorias-status.md:30-30` — hoje `:48` — cita a tecla F3 em src/input/input_actions.gd:33, arquivo não aberto neste plano; o nó `MemoryGate` prometido em docs/design/04-local-ai-architecture.md:53-55 não existe em `src/` — a única ocorrência é o comentário de src/ai/mind.gd:103, e o veto por memória é feito por `believes()` direto em src/entities/wolf.gd:944.
