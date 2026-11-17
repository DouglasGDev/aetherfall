# 03 — Loop de gameplay

Três escalas de loop, todas escritas nas mesmas estruturas (Éter → Mente → Ledger →
Consequência). Se um loop não terminar *escrevendo* em alguma dessas, ele é decorativo e
não entra.

## Micro-loop — 30 segundos a 3 minutos

```
LER o mundo        sentir Éter: vestígios, sons, pegadas, medo, atividade de mentes
   ↓
DECIDIR            abordagens em paralelo: força / furtividade / troca / boato / magia
   ↓
AGIR               combater, coletar, tecer, construir, falar, mentir, fugir
   ↓
GRAVAR             todo ato vira Deed -> Consequence no Ledger + vestígio no Éter
   ↓
RECEBER            a mente afetada reordena metas (imediatas) e crenças (duráveis)
```

**O que faz o micro-loop ser bom:** as 5 abordagens sempre disponíveis e sempre com preço
diferente. Matar um bandido é grátis agora e caro depois (família, boato, recompensa).
Deixar ele ir é caro agora (ele rouba de novo) e barato depois (vira testemunha).
Um único "inimigo" deve poder ser resolvido por 4 caminhos legítimos — se só um funciona,
o loop virou checklist.

**Feedback sensorial (juice) `[TARGET]`:** hit-stop 40-80 ms, screen-shape por tipo de
dano, squash de voxels no impacto, áudio por material, partículas de Éter visíveis quando
algo *grava memória* (o jogador aprende a ler o mundo pela própria linguagem visual do
sistema de memória).

## Meso-loop — 30 a 90 minutos (uma sessão)

```
1. PARTIR        escolher/ouvir um Compromisso vindo do Ledger (não de um autor)
2. VIAJAR        traversia com ecologia viva: clima, rotas, patrulhas, outros agendas
3. LER A CENA    reconhecer padrão: quem manda aqui, o que a facção quer, o que o Éter diz
4. COMPROMETER   gastar recursos e reputação; assumir risco com consequência durável
5. CONVERTER     loot -> craft/uplink; conhecimento -> Gnose; feito -> Vínculo/Domínio
6. COLHER        a Crônica registra; a facção reage; um novo Compromisso nasce (ou morre)
```

Gate de sessão: o passo 6 **sempre** altera pelo menos uma crença de pelo menos uma mente
que o jogador não controla. Uma sessão que não muda nada no mundo é uma sessão desperdiçada
por design — e o `Director` recebe essa informação como sinal de tédio.

## Macro-loop — 10 a 40 horas (uma era)

```
VÍNCULO         você escolhe lados por interesse e afeto, não por classe
PRESSÃO         I3: o mundo aprende seu estilo; I4: facções reordenam territórios
CULMINÂNCIA     um Chefe-mente reage à sua trajetória e prepara algo específico
CUSTO           seus atos viram leis, boatos, cicatrizes no Éter, migrações
HERANÇA         você vira um nome na Crônica; a próxima era joga no mundo que você fez
```

---

## Solo: como o jogo é profundamente vivo sem ninguém

O problema de solo não é "falta de gente", é "falta de atrito social". Solução: os
**companions são mentes do mesmo tipo dos NPCs** (Estilhaços completos, com BT + crenças +
memória), não um sistema à parte. Consequências de design:

| Mecânica solo | O que produz |
|---|---|
| **Discordância com consentimento** | O companion *reclama* de atos que contradizem a personalidade/crenças dele, e pode recusar uma **abordagem** (ex.: "não minto para ela"), nunca o objetivo principal. Sem recusa = sem drama; com recusa total = sem agência do jogador. |
| **Testemunha permanente** | O que você faz na frente de um companion entra no ledger com ele como co-testemunha. Três sessões depois ele pode citar o que viu, contra você, num conselho de aldeia. |
| **Conselho do grupo** | Decisões de facção sobre você são ponderadas pelas relações com cada membro do seu grupo. Você pode ser amado pela ferreira e banido pela vila por causa dela. |
| **Ausência com memória** | Companions em campanha longa continuam participando da Trama (SlowSim) enquanto você não os usa. Eles *envelhecem*, mudam de ideia, criam rancor com quem você aliou. |
| **Nunca dois iguais** | O gerador de companions sorteia personalidade + história a partir de feitos *reais* do mundo (ex.: órfã de um evento da Crônica). Sem backstory inventada em texto morto. |

**Anti-frustração:** companions têm um medidor de confiança que a *negligência* drena (você
mudou de plano sem avisar), não a desobediência. Recusar um método nunca custa lealdade;
isso mantém a discordância como sabor, não como pedágio.

## Co-op 1-4: impacto mútuo no mundo

**Assinatura de causalidade por jogador.** Toda entidade no ledger guarda `actor`,
`orderer`, `aider`, `witnesses`. NPCs formam crenças separadas por pessoa *e* uma crença
de grupo (a "família que fez isso"). Isso gera os momentos que só co-op produz: alguém
mentiu para a vila na sua frente, e agora a vila te evita *por associação* sem te acusar.

| Situação | Comportamento do sistema |
|---|---|
| **1 jogador** | 0-3 companions preenchem as funções sociais; o mundo continua com Trama cheia. |
| **2-4 jogadores** | Companions são *substituídos* pelas pessoas (mesmos slots de função), nunca adicionados. O jogo não fica mais fácil por plateia: o `Director` escala pressão por **contagem efetiva de agências**, não por cabeça. |
| **Late-join** | Novo jogador entra em `[TARGET]` <2 s, recebe snapshot + resumo das mentes relevantes, e começa **sem histórico** — o mundo não o conhece, o que é um recurso: anônimo é uma classe de jogabilidade. |
| **Host migration** | Outro jogador assume o host; o ledger é o estado autoritativo e está em disco no antigo host, replicado incrementalmente; a Trama reexpande resumos. Nada se perde, mas o mundo registra a interrupção (uma "pausa" na Crônica, com duração real). |
| **Desacordo de grupo** | Dois jogadores que dão ordens contraditórias a uma mente: ela pondera por relação e por *quem está mais perto* e decide, com o motivo auditável no inspector. |

**Regras de host.** Host é um jogador (listen-server) com as mesmas decisões de IA do
dedicado; nenhum cliente roda simulação autoritativa de mundo. `--headless` é o dedicado e é
também o binário de CI — uma só implementação de autoridade (`[DECIDED]`, ver §06). Em
qualquer sessão, qualquer cliente pode assumir o papel de host por migração.

---

## Loop de morte e derrota (não é respawn grátis)

Morrer **não** remove progressão (sem XP lost, sem queda de item — `[DECIDED]`) porque o
jogo é sobre consequências, não sobre punição de habilidade. O custo é **narrativo e
mécânico**: ao morrer você é "re-knitted" pelo Éter local, o que (a) deixa um vestígio
forte em `death` no ponto onde caiu — predadores e facções usam isso; (b) cobra um
`Debt to the Tide` — uma mente/entidade agora tem uma *crença verdadeira* de que lhe deve
algo, e vem cobrar em uma forma que você escolhe pagar (serviço, objeto, ato); (c) em co-op,
quem te revive vira co-autor do seu retorno no ledger, criando uma dívida real entre
jogadores. Derrotar um chefe sem matá-lo (fugir, negociar, enganar) também grava: chefe
que sobrevive **aprende** (§05).

## O que o jogador faz nos primeiros 10 minutos (primeira sessão) `[TARGET]`

1. Acorda num acampamento que **não** foi feito para ele: há vestígios (Éter visível), uma
   mente dormindo ao lado (companion real, que acorda e comenta o que *ela* viu), e uma
   dívida escrita no ledger do mundo.
2. Primeiro tutorial é leitura: seguir um rastro que leva a dois saqueadores que *já
   sabem* que alguém os caçou ali. Ele pode matar, ouvir, mentir, roubar ou tecer.
3. Primeira consequência visível em <5 min: a aldeia mais próxima recebe um boato
   (Rumor) sobre o que ele fez e uma mente muda de meta por causa dele.
4. Primeiro compromisso nasce dele, não de um autor: a vítima do roubo vai atrás dele,
   com um preço, e o `fsck` de mundo consegue apontar a causa até o ato do jogador.
