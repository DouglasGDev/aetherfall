# 02 — As 8 inovações principais

Cada inovação está escrita no formato **o que é → como funciona tecnicamente → por que
exige IA local → o que o jogador sente**. A quarta coluna é o teste real: se a feature
pudesse ser feita com uma tabela SQL e um randomizador, ela não pertence a esta lista.

---

## I1 — Éter: a memória do mundo é um campo físico, não um banco de dados

**O que é.** A memória do mundo existe em dois lugares acoplados e nunca em apenas um:
um **campo espacial** (o Éter, residente nos voxels) e um **ledger temporal** (os Ecos,
estruturados por entidade, ato e consequência). Criaturas não "consultam um quest flag";
elas *sentem* o rastro onde pisaram, e *lembram* quem estava lá.

**Como funciona.** `AetherField` é um volume escalar/vetorial de baixa resolução (1 célula
a cada 4 voxels `[TARGET]`) por canal: `blood`, `magic`, `death`, `sound`, `heat`,
`fear`, `work` (pegada de construção/extração). Cada canal tem difusão anisotrópica
(barreiras reduzem), decaimento exponencial com meia-vida por tipo, e *impurezas*
(identificadores: assinatura de quem causou). O campo é a razão pela qual a percepção é
barata: um `AetherSense` lê 8 números + uma lista de IDs por célula em vez de raycast
contra a cena. O `EchoLedger` guarda o que não é espacial: atribuição de culpa, dívidas,
juramentos, posse, relação. A ponte entre os dois é `echo_id` — o vestígio no Éter é um
ponteiro para o registro no ledger.

**Por que exige IA local.** O campo é lido por *todas* as mentes em cada tick de
percepção, centenas de vezes por segundo. Uma ida por rede a cada consulta de percepção
inviabiliza o orçamento de frame; e a difusão é um job numérico contínuo que precisa estar
no mesmo processo que a simulação.

**O que o jogador sente.** Ele entra numa clareira semanas depois e o chão ainda "cheira"
a sangue — os lobos do vale não entram ali, e um rastreador NPC comenta o que sente. Ele
percebe que mentiu numa cidade e que a cidade agora tem "medo" visível (canal `fear`),
com guardas patrulhando diferente. Magia alta deixa costuras que o mundo cura — ou
reação imunológica (§I3).

---

## I2 — Estilhaços: uma mente local, orçamentada e auditável em cada criatura

**O que é.** Cada NPC, mob e facção tem uma `Mind` executando no cliente: vetor de
personalidade, crenças com *grounding*, buffer episódico, metas em stack, Behavior Tree +
Utility AI, e um agenda própria que corre mesmo quando o jogador não olha.

**Como funciona.** Quatro camadas, sempre determinísticas e sempre no mesmo processo do
jogo (detalhes em §04):

- **Core determinístico** (sempre ligado): percepção → crenças → metas → BT/utility →
  ação. Sem dependência de rede, de modelo ou de disco além do cache.
- **LOD de simulação** (`HotSet`): mentes completas perto do jogador; resumidas a
  distribuições de probabilidade longe dele, reexpandidas quando se aproximam — com
  reconstrução retroativa coerente do que fizeram no intervalo (nunca "teleporte para o último estado").
- **SlowSim** (relógio lento): facções, economia de aldeia, ecologia, rumores, em fatias
  de tempo fora do frame crítico.
- **Oráculo local** (opcional): LLM + embeddings rodando na GPU local, somente para
  *propostas* (diálogo, resumo de crenças, sugestão de meta), nunca para autoridade.

**Por que exige IA local.** São 10²–10³ mentes vivas por sessão. Uma ida por mente por
tick a um serviço remoto é 3 ordens de magnitude acima de qualquer latência aceitável; e
uma mente que para quando a internet cai não é uma mente, é um enfeite.

**O que o jogador sente.** Um ferreiro que *quer* algo (reconstruir a mina do pai), que
reclama quando você ignora o pedido, e que lembra que você mentiu sobre o preço do minério.
O inspector de mente (`MindsInspector`, §06) mostra a árvore, o blackboard e as crenças com
confiança — a IA é auditável, não uma caixa-preta.

---

## I3 — O mundo aprende a jogar contra você (e o seu médico é você)

**O que é.** Duas malhas de aprendizagem simultâneas: (a) **por espécie/facção**, táticas
que funcionaram contra o jogador são selecionadas e ensinadas; (b) **do jogador sobre o
mundo**, onde a violência repetida gera resistência e anticorpos — inclusive a magia, que é
edição do Éter.

**Como funciona.** `StyleFingerprint` agrega telemetria local em ~16 dimensões
(agravos: stealth, melee, ranged, fire, AoE, explosivos, roubo, negociação, craft,
construção, fuga, magia) com janelas deslizantes e *recência*. `TacticBank` por
arquétipo mantém um bandit contextual (UCB sobre `context × tactic`, onde o contexto é
`{hora, terreno, composição do grupo, presença de magia, alarma}`) e recompensa é dano
eficaz/tempo de sobrevivência. `CounterProfile` por *facção* acumula o que causou baixas e
desbloqueia: patrulhas anti-stealth (mais sensores de `sound`), totems de aviso, escolta
de bagagem, capacetes, rotas alternativas, iscas. Do lado do jogador: `ImmunityProfile`
por alvo e por região — a segunda emboscada de fogo no mesmo vale rende menos; a terceira
rende quase nada e ativa a **resposta imune**: o Éter ali passa a "rejeitar" tecelagem
(idos de falha maior) e nasce um predador especializado em teceões.

**Por que exige IA local.** Aprendizagem online contínua com feedback dentro de segundos
só é viável se o modelo de decisão, a recompensa e a memória estão no mesmo endereço de
memória da simulação. E porque precisa rodar em 100% dos jogadores sem custo de inferência
remota — um sistema adaptativo pago por sessão mata o modelo de negócio open-source.

**O que o jogador sente.** Ele fica entediado de uma tática porque o mundo ficou entediado
delas primeiro. E vê as consequências: um cartaz na aldeia descrevendo *seu* comportamento,
escrito pela IA a partir do ledger, com a recompensa certa e a rota onde foi visto.

---

## I4 — Facções com agenda, orçamento e obras construídas por elas mesmas

**O que é.** Facções são jogadores não-humanos no mesmo sistema: têm metas, economia,
recrutamento, território, rancores e a capacidade de **alterar o mundo voxel** sem o
jogador. Uma aldeia esquecida cresce, empobrece, migra ou é absorvida.

**Como funciona.** No `SlowSim`, cada facção é um agente com: reserves (comida, metal,
moral, conhecimento), uma stack de metas (`expand`, `secure`, `revenge`, `trade`,
`worship`) pontuada por utility, e um **planner de obras** que emite pedidos de
modificação de terreno (`dig`, `fill`, `build`, `burn`) validados contra regras físicas e
de propriedade. As obras entram no `EditJournal` exatamente pela mesma porta do que um
jogador faz — não há caminho privilegiado. Território é um grafo de vãos (o mesmo usado
por pathfinding), com custos de manutenção e rotas que podem ser cortadas. Offline, o
`CatchUp` roda a Trama em passos macro limitados (teto de tempo de tela de carregamento
`[TARGET]`) com *resumo*, não com simulação completa de cada indivíduo.

**Por que exige IA local.** Uma facção que decide construir um forte é uma sequência longa
de decisões de baixo nível com validação no voxel; delegar isso a um serviço externo
significaria transmitir o estado do mundo — o oposto de um jogo procedural offline.

**O que o jogador sente.** Ele volta a um posto de comércio que ignorou e ele virou uma
fortaleza de uma facção que odeia a sua guilda amiga — e a causa é rastreável na Crônica
até uma caravana que ele deixou passar.

---

## I5 — Ledger de consequências: missões nascem do que você fez, não de um autor

**O que é.** Feitos são registrados como objetos duráveis (dívida, rancor, jura, posse,
testemunho, boato) com regras de propagação, expiração e *credibilidade*. O sistema de
missões é um **leitor** desse ledger: gera compromissos a partir de estados de desejos não
satisfeitos de mentes que têm razão para falar com você. Não há fila de quests designadas.

**Como funciona.** `EchoLedger` é append-only e versionado: um ato entra como `Deed`,
expande para `Consequence` records por relacionamento (quem viu, quem perdeu, quem lucrou)
e para `Commitment` records (promessas feitas, prazos, quebras). `Rumor` é a forma degradada
e propagável de uma crença: cada hop aplica desconto de credibilidade e mutação controlada
por *resumo*, não por improviso livre. Regras de consistência (ex.: morto não testemunha;
co-autores podem divergir) são verificadas por validadores no commit do tick, e um `fsck`
de save audita o ledger contra invariantes.

**Por que exige IA local.** A cadeia ato→memória→crença→boato→meta→convite só é interessante
se acontecer em centenas de mentes continuamente, incluindo as que o jogador nunca visitou.
Ela precisa estar na mesma caixa que o mundo.

**O que o jogador sente.** Você matou um chefe por ganho próprio e três sessões depois o
filho dele não te ataca: ele *oferece* algo, porque mede consequências melhor que você. A
missão que você aceita é o problema real de alguém, com prazo real, que pode falhar sem você.

---

## I6 — Tecelagem: magia é edição da memória do mundo, com sistema imune

**O que é.** A escola de magia do jogo *não* é um conjunto de spells com cooldown: é
acesso autorizado a escrever no `AetherField`. Curar é reescrever o vestígio de dano.
Iludir é plantar uma crença falsa com credibilidade limitada. Invocar é convencer uma mente
distante. E tudo deixa rastro — o mundo tem um sistema imune contra edição abusiva.

**Como funciona.** Toda magia é uma **assinatura** (padrão de nós sobre canais do Éter)
compilada do que o jogador fez com as mãos, não escolhida de um menu fixo; o custo é
função de *quanta* de campo disponível, distância, e quanto a edição **contradiz o
ledger** (reescrever um feito registrado é caro e visível). A resposta imune é o
`ScarTissue` local: regiões tecidas demais ganham resistência crescente por assinatura,
e o Diretor pode gerar anticorpos (anomalias que caçam teceões, §I3). Conhecimento
(*Gnose*, §05) é o que libera assinaturas mais profundas — você aprende nomes verdadeiros
lendo a Crônica, não subindo de nível.

**Por que exige IA local.** A magia interage com as mesmas estruturas que as mentes leem:
se a IA do mundo não estivesse no mesmo lugar, a magia seria decorativa. E a
"validade" de uma edição exige grounded check contra memórias que outras mentes têm.

**O que o jogador sente.** Ele escolhe entre suborno, boato e milagres com consequências
do mesmo tipo. E pode ser punido por ser poderoso demais num vale — que passa a rejeitá-lo.

---

## I7 — Co-op 1-4 com causalidade compartilhada: o mundo sabe *quem* fez

**O que é.** Até 4 humanos num mundo host-authoritative, sem tela de carregamento entre
sessões, onde cada um dos quatro escreve no mesmo ledger com identidade separada — e mentes
NPC formam opiniões distintas sobre cada um, inclusive opiniões *sobre o grupo*
(quorum, culpa por associação, dissidência).

**Como funciona.** O host roda o único `SimWorld` autoritativo; decisão de IA, voxel e
ledger acontecem **só no host** e viram eventos determinísticos no tick, enviados como
delta-state. Clientes fazem predição local do próprio jogador (movimento, animação,
intenção) e *solicitam* ações do mundo; pedidos são validados no host com checagem de
propriedade, proximidade e rate-limit. `AttributionSet`: uma ação pode ter múltiplos
autores (quem deu a ordem, quem executou, quem emprestou a arma) e as crenças dos NPCs
pesam esses papéis por personalidade (um pacifista culpa o mandante; um mercenário culpa o
executor). `Council`: quando a ação envolve o grupo, a mente aplica weighting entre as
relações com cada membro — daí "a vila confia em você, mas teme seu amigo". Late-join
restitui estado por snapshot + resumo de mentes (não por replay completo), com alvo
`[TARGET]` de <2 s para entrar e estar renderizado, e migração de host reexpande
distribuições resumidas do `SlowSim` (nunca perde o mundo; o ledger é o mundo).

**Por que exige IA local.** Cada jogador tem uma cópia sua do motor de simulação; se a IA
fosse um serviço externo, o custo e a latência multiplicariam por 4 e o design "cada um
tem personalidade própria" não sobreviveria. Co-op seamless aqui significa literalmente
*uma mente compartilhada* — o host é a autoridade e qualquer cliente pode virá-lo.

**O que o jogador sente.** Ele trai o grupo e o grupo não precisa saber: a aldeia sabe, e
o companion que viu comenta. Nada de "o mundo esqueceu tudo porque você desconectou".

---

## I8 — Crônica scrubável: o tempo do mundo é uma UI (e um banco de testes)

**O que é.** Toda a história do mundo — obras, mortes, migrações, leis, boatos, suas ações —
é consultável como uma linha do tempo navegável com filtros por lugar, facção, entidade e
canal do Éter. É a materialização do "mundo vivo": o jogador pode *ver* o que a IA fez
sem ele, e entender causa e efeito.

**Como funciona.** A Crônica é o journal de commits do ledger + do `EditJournal` de
voxel, indexado por (tick, região, entidade, tipo). A UI faz **time-lapse do estado**:
reconstruir um chunk num tick passado é viável porque o voxel guarda deltas por região,
então "como era este vale há 20 dias" é uma consulta, não uma renderização de replay.
O mesmo formato serve de *golden journal* nos testes: um cenário de simulação grava o
journal, e a regressão compara hash de estado por tick — ou seja, a feature que o jogador
usa é o harness que impede a IA de quebrar silenciosamente.

**Por que exige IA local.** Um histórico consultável por estado de centenas de mentes é um
volumo de dados que só faz sentido existir junto da simulação que o produziu.

**O que o jogador sente.** Ele abre a Crônica, clica na ruína fumegante e vê a sequência:
caravana perdida → boato → retaliação → fortaleza → fome. Isso transforma "sistemas
invisíveis" em narrativa jogável — e é o que torna um sandbox narrável em vez de ruidoso.

---

## Matriz de dependência (por que as 8 são um sistema, não um check-list)

```
I1 Éter (campo) ──┬──> I2 Mentes (percepção/crença)
                  ├──> I3 Aprendizagem (contexto barato)
                  ├──> I6 Magia = escrever aqui ──> resposta imune
                  └──> I8 Crônica (indexar vestígio + feito)
I2 Mentes ──┬──> I4 Facções/SlowSim (agenda agregada)
            ├──> I5 Ledger -> missões geradas de desejos
            └──> I7 Co-op (cada mente tem N opiniões, uma por autor)
I4 + I5 ──> I3 (o mundo pode se preparar, não só reagir)
I8 ──> gate de qualidade de tudo (replay determinístico nos CI)
```

**Anti-objetivo declarado.** Nenhuma das oito depende de gerar texto livre "bonito". O
LLM local é uma camada de *expressão* sobre I1/I2/I5 — se ele for removido, as oito
inovações continuam de pé (o diálogo degrada para templates preenchidos por memória, e isso
é rotulado no menu como "modo de IA reduzida", sem fingir que é a mesma experiência).
