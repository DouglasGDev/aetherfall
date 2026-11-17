# 01 — Pitch e nome

## Pitch

> **Aetherfall** é um RPG de mundo aberto voxel em que o mundo tem memória — e usa ela
> contra você. Cada árvore derrubada, cada aldeão morto, cada feitiço lançado grava um
> vestígio no **Éter**, um campo físico que os NPCs e as criaturas *enxergam* e *lembram*:
> lobos que sobreviveram a uma emboscada com fogo param de entrar em clareiras e passam a
> caçar você pelo vento; a viúva de um guarda reconhece sua voz três semanas depois e
> contrata um assassino; uma facção que você humilhou reordena suas rotas comerciais,
> fortifica vãos e te oferece um acordo — porque tem metas próprias, um exército que treina
> sozinha e um orçamento que você pode quebrar. Tudo isso roda **inteiramente na sua
> máquina**: mentes locais com Behavior Trees, utility AI, memória episódica, um simulador
> de facções e ecologia em relógio lento e, opcionalmente, um LLM local que dá voz,
> crenças e boatos a cada personagem, sem um único byte enviado para a nuvem. Não há
> trilha de quests: há um **Ledger de consequências** que gera compromissos a partir do que
> você realmente fez, e **bosses que aprendem com a luta anterior** — se você matou o Rei
> espinho com fogo, ele queima menos na segunda vez e mandou construir máscaras de respiração.
> Solo, você nunca está sozinho: seus companions têm opinião, medo e memória, e discordam
> de você. Em co-op de 1 a 4 jogadores, cada um dos quatro escreve no mesmo mundo, e o
> mundo sabe *quem* fez o quê.

**Elevator de uma frase:** *"Veloren encontrou Dwarf Fortress: um voxel sandbox onde uma IA
local lembra de tudo que você fez — e adapta o mundo para te punir ou te respeitar por isso."*

## Nome: manter `Aetherfall` `[DECIDED]`

O nome atual não só é bom como é **literalmente o nome da tecnologia central**, e isso é
raro. Justificativa em três camadas:

1. **Diegética.** "Éter" é o substrato de memória do mundo (campo voxel + ledger). Toda a
   IA — percepção, memória, magia, boatos, adaptação — lê e escreve nesse campo. O nome do
   jogo descreve o sistema, não um adjetivo genérico de fantasia.
2. **Catártica.** "A Queda" (*the Fall*) é o evento fundacional: a mente celestial que
   governava o mundo se estilhaçou, e cada estilhaço virou uma mente local — em cada
   lobo, aldeão, facção e ruína. Isso explica *dentro do jogo* por que a IA é distribuída e
   local em vez de um Céu onisciente central: não há servidor de deus, há cacos de deus em
   cada cabeça. É o pitch técnico contado como mitologia.
3. **Mecânica.** A progressão final do jogador é decidir o que a Queda deixou de ser:
   recolher estilhaços (dominar mentes), religar o Éter (magia) ou cair de novo
   (endgame emergente, §05). O título é também o nome do clímax.

Riscos honestos do nome: (a) "aether" é um topônimo saturado em fantasia; (b) soa parecido
com *Aether* (SkyChildren), *Ether*, *Ashfall*, *Godfall*; (c) não comunica "voxel" nem
"RPG". Mitigação: a marca sempre carrega o descritor **"Aetherfall — a living voxel world
that remembers"**, e o ícone/identidade visual é o Éter (partícula + voxel), não espadas.

### Alternativas consideradas

| Nome | Ideia | Por que ficou atrás |
|---|---|---|
| **Splintered Sky** | Os estilhaços do céu = mentes locais | Bonito e único, mas não nomeia o *campo* nem o sistema de memória; não há clímax homônimo. |
| **Mnemic / Mneme** | Memória como matéria (grego) | Conceito perfeito, impronunciável para o público-alvo, ilegível em busca; soa a quebra-cabeça, não a sandbox. |
| **Rootfall** | Ecologia + queda | Ótimo para um jogo sobre raízes e florestas; o nosso jogo é sobre memória. Colide sonoramente com Aetherfall de qualquer forma. |
| **Anamnesis** | "Recordar" platônico | Literário demais para marketing; difícil de digitar; já existe em uso (jogo/roguelike indie). |
| **Kindred World** | Facções e relações | Descreve um feature, não a tese; frágil como marca; genérico demais para registrar. |

**Recomendação:** `Aetherfall`, com o sub-slogan *"...that remembers"*. Nome do
repositório/binário: `aetherfall` (snake/lower, sem maiúsculas em artefatos para evitar
bugs de case-sensitivity entre NTFS/ext4).
