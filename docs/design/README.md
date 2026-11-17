# Aetherfall — Design completo

Documento de visão e arquitetura. Este é o **design target**, não a documentação do
que já existe em código: o repositório tem o slice P0/P1 jogável (`project.godot` na
raiz, `src/`), e tudo aqui especifica o que ainda será construído em cima dele. Para o
que está implementado hoje, veja o [`README.md`](../../README.md) da raiz.

## Legenda de status (usada em todos os documentos)

| Marca | Significado |
|---|---|
| `[TARGET]` | Meta de design a ser alcançada; nada a implementa ainda. |
| `[CLAIMED]` | Afirmação de fonte externa (engine, lib, vendor) que não medimos. |
| `[MEASURED]` | Número obtido por medição neste repositório, com script e revisão. |
| `[DECIDED]` | Decisão tomada e vinculante para o time. |
| `[OPEN]` | Questão aberta com data-limite e critério de fechamento. |

Nenhum número de FPS, latência, custo de memória ou tempo de tick neste conjunto de
documentos é `[MEASURED]` — todos são `[TARGET]` até que o bench de P0 rode.

## Índice

| # | Documento | Entrega |
|---|---|---|
| 01 | [Pitch e nome](01-pitch-and-name.md) | Pitch, análise do nome, alternativas |
| 02 | [Inovações](02-innovations.md) | 8 inovações e por que só a IA local as permite |
| 03 | [Loop de gameplay](03-gameplay-loop.md) | Micro/meso/macro, solo e co-op 1-4 |
| 04 | [Arquitetura da IA local](04-local-ai-architecture.md) | Mentes, BT, utility, memória, adaptação, LLM offline |
| 05 | [Progressão e bosses](05-progression-and-bosses.md) | Progressão não-linear, bosses como mentes |
| 06 | [Arquitetura técnica em Godot 4](06-godot-architecture.md) | Sim, voxel, rede, persistência, orçamento |
| 07 | [Estrutura de pastas](07-project-structure.md) | Árvore completa e convenções |
| 08 | [Roadmap, riscos e licenças](08-roadmap-risks-licensing.md) | Fases com gates, riscos, MIT × GPL |

## Glossário canônico

Os nomes de mundo e de sistema são 1:1 — um conceito, dois nomes, nunca três.

| Nome no jogo | Nome no código | O que é |
|---|---|---|
| **Éter** | `AetherField` | Substrato físico da memória do mundo: um campo voxel com vestígios (sangue, magia, morte, som, fogo) que difunde, decai e é legível por entidades. |
| **Ledger / Ecos** | `EchoLedger` | Registro temporal de feitos: dívidas, rancores, juras, possessões, mortes. Não-rollbackável. Alimenta o gerador de missões. |
| **Crônica** | `Chronicle` | História do mundo consultável e scrubável pelo jogador. Formato de journal determinístico usado também pelos testes de replay. |
| **Estilhaço** | `Mind` | A mente local de uma criatura: personalidade, crenças, memória episódica, metas, BT + utility. |
| **Rumor** | `Rumor` | Crença não-verificada propagada entre mentes. Contém as saídas não-groundadas do LLM, em quarentena por credibilidade. |
| **Assinatura de Estilo** | `StyleFingerprint` | Telemetria local do comportamento do jogador (roubo, agressão, magia, economia) que a adaptação consome. |
| **Diretor** | `Director` | Agente que traduz `StyleFingerprint` + estado do mundo em pressão dramática justa, dentro de limites de fairness. |
| **Trama** | `SlowSim` | Simulação de baixo custo de facções, aldeias, economia, ecologia e rumores, rodando online em fatias e offline em catch-up limitado. |
| **Véu** | `HotSet` | Conjunto de mentes em simulação completa (perto de jogadores) vs. resumidas (longe). LOD de simulação. |
| **Sintonia / Vínculo / Gnose / Domínio / Ressonância** | `Soma`, `Bond`, `Gnosis`, `Dominion`, `Resonance` | Os 5 eixos de progressão (§05). |
| **Tecelagem** | `Weaving` | Magia: edição autorizada do `AetherField`, com custo, rastro e resposta imune do mundo. |

## Premissas inegociáveis `[DECIDED]`

1. **MIT** no código, **CC-BY-SA 4.0** nos assets. Nada de código ou asset do Veloren
   (GPL-3.0) — inspiração de idéias e sistemas, zero derivação de obra (§08).
2. **IA 100% local.** Nenhum serviço de nuvem no caminho de decisão. Sem rede, o jogo
   inteiro continua jogável e o mundo continua vivo.
3. **Solo primeiro, co-op sem emenda.** Se uma mecânica só funciona com 4 humanos, ela
   está errada; companions são mentes do mesmo tipo de jogador.
4. **Godot 4.x, GDScript + C++ GDExtension.** C# somente sob proposta com número de
   benchmark (§06).
5. **A memória do mundo é jogável.** O jogador pode ler, auditar e ser surpreendido por
   ela. Um estado que o jogador não pode descobrir de alguma forma não entra no design.
