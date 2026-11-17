# 05 — Progressão e bosses reimaginados

## Progressão: 5 eixos, zero níveis, zero skill tree com cadeado

Não existe "nível 30". Existe um estado do mundo sobre você, e cada eixo é **derivado de
fatos registrados** (ledger + Éter), não de pontos distribuídos pelo jogador. Isso é o que
faz a progressão ser a mesma moeda que a IA usa: você sobe *em* mundo, não *fora* dele.

| Eixo | O que é | Como cresce (fonte = eventos reais) | O que destrava |
|---|---|---|---|
| **Soma** (Corpo) | memória muscular: postura, mira, timing, resistência | uso medido por competência, com *diminishing return* por método — spam de uma tática satura rápido (anti-grind natural, ligado a I3) | movimentos, armas pesadas, condições |
| **Vínculo** (Relação) | confiança e medo que cada mente/facção tem de você | deeds atribuídos + testemunhos + boatos, por **indivíduo**, com agregação em reputação | preços, acesso, escoltas, companions, perdão |
| **Gnose** (Conhecimento) | o que você *sabe* do mundo: nomes verdadeiros, fraquezas, receitas, histórias | ler Crônica, ouvir testemunhos, observar Éter, estudar corpos, aprender com quem sobreviveu | assinaturas de magia, pontos fracos de chefes, negociações |
| **Domínio** (Lugar) | sua pegada material: construções, obras, território controlado, obras que você financiou | mudanças válidas no voxel + obras coletivas + acordos | rotas, mercados, fortificações, ecologia local a seu favor |
| **Ressonância** (Éter) | quanto o mundo te *ouve* e o quanto você pode reescrever | magnitude/histórico de edições + reação imune acumulada | alcance de tecelagem, custo, risco |

**Detalhamento de Ressonância `[DECIDED]`:** os dois últimos eixos competem de propósito.
Ressonância alta abre magia poderosa e faz o mundo *registrar você como evento* — quanto
mais você dobra o Éter, mais o sistema imune te trata como patógeno (I6). O jogador
escolhe entre ser **conhecido e temido** (Vínculo/Domínio) ou **invisível e perigoso**
(Gnose/Ressonância baixa). Não existe build que maximize os cinco: tetos de custo e a
resposta imune são o balanceamento.

## Estrutura de metas: não-linear por construção

O jogo tem ~5 objetivos terminais (formas diferentes de resolver a Queda), mas **zero
ordem obrigatória**. Cada *Threshold* (portão) é uma **disjunção de ≥3 rotas independentes**,
cada uma usando um eixo diferente. Exemplo: abrir o **Vale Espinhoso**.

```
THRESHOLD: vale-espinhoso:passagem
  rota A (Soma)        sobreviver a 3 emboscadas e purgar a raiz-núcleo na força
  rota B (Vínculo)     acertar trégua com o clã dos espinhos (o que eles querem: os ossos)
  rota C (Gnose)       descobrir o nome verdadeiro do Rei-espinho na Crônica e nomeá-lo
  rota D (Domínio)     reconstruir a estrada antiga e tornar o vale economicamente irrelevante
  rota E (Ressonância) tecer a memória de crescimento da floresta (alto risco: imunidade)
```

Cada rota é implementada como um **conjunto de condições sobre o ledger/Éter**, não como
uma quest com flags próprias. Rotas nunca bloqueiam umas às outras; combinar rotas gera
*variantes de desfecho* (nomear o rei **e** queimar o núcleo = desfecho "herege"). Isso é
barato de produzir porque a condição é uma consulta sobre estruturas que já existem para a
IA.

**Midas touch de progressão:** o que você faz *conta duas vezes* — para o eixo e para o
mundo. Nada de "10 lobos para subir a espada": matar lobos sobe Soma *e* muda população
*ecológica* (I4/I3) *e* cria ressentimento se eram de alguém. grind e construção de mundo
são o mesmo ato.

## Bosses: mentes, não barras de vida

Um **Chefe** é um `Mind` com (a) metas próprias e recursos reais, (b) memória
inter-encontro, (c) capacidade de **preparação fora da luta**, (d) pelo menos uma
solução sem combate. A IA de chefe usa a pilha do §04 com prioridade de tick (HOT a 20 Hz)
e um *taskset* exclusivo de utility.

### Anatomia de um encounter

```
FASE 0  CONHECIMENTO   você ouve falar dele (Rumor, Crônica, sobreviventes) — fraquezas
                       reais, mas possivelmente falsas se o boato degradou
FASE 1  PREPARAÇÃO     ele prepara: contra-medidas do seu CounterProfile, fortifica,
                       move família/tesouro, manda emissário, oferece acordo
FASE 2  ENCONTRO       luta que ensina mecânica; ele fugir é um resultado válido
FASE 3  CONSEQUÊNCIA   memória inter-luta: aprendeu, adaptou, mudou de tática e de lugar,
                       e te puniu por onde você mora / por quem você ajudou
FASE 4  RESOLUÇÃO      matar, subornar, converter, exiliar, tornar irrelevante, ou
                       ser derrotado permanentemente POR ELE
```

**Regra de design `[DECIDED]`:** um chefe pode ser resolvido *sem* vitória em combate e
*sem* repetição de tentativa. Se o único caminho é "tente 8 vezes até decorar", a IA do
chefe é decorativa e erramos o jogo.

**Anti-HP-sponge:** a dificuldade de um chefe vem de *restrições que ele impõe* (rotas de
fuga, invocação, terreno, refém de ecologia, desinformação), não de um multiplicador de
vida. Vida alta é o recurso de um chefe **que você precisa convencer primeiro** (um
colosso que só se importa se você destruir o que ele protege).

**Interação de adaptatividade:** o chefe lê o *seu* `StyleFingerprint` e o
`CounterProfile` da facção. Você venceu com fogo na primeira vez → na segunda há
máscaras, panos molhados, corredores de escape e uma zona de fumaça contra você.
Isso é I3 em escala máxima, e por isso a terceira tentativa tende a *piorar* se você
não mudar o repertório — o texto de morte explica o que mudou ("as máscaras foram
feitas depois do incêndio do vale", com link para o deed no ledger).

### Os seis chefes de referência `[TARGET]` (não-sequenciais)

| Chefe | Natureza | O que ele quer | Como ele aprende | Rotas não-violentas |
|---|---|---|---|---|
| **Rei-Espinho (Raiz do Espinho)** | mente da floresta, agente druídico | reverter a clareira onde sua espécie foi queimada | resiste a fogo que ele sobreviveu; passa a esporo/afogamento; planta espinhos nos seus caminhos de fuga | entregar os ossos; tecer a memória de crescimento; torná-lo irrelevante reflorestando você mesmo |
| **O Cartógrafo Faminto** | líder de facção comercial | mapas das suas bases e rotas (compra de *informação* do ledger!) | se você ataca caravanas, ele compra seus segredos; se você negocia, ele te precifica | arruinar seu mercado; tornar seus dados sem valor; virar sócio |
| **Coro de Vidro** | colmeia de mentes (grupo, não indivíduo) | silêncio: odeia `sound` imprint | adapta-se a spoofing sonoro; aprende a te identificar pela assinatura de Éter, não pelo rosto | destruir o material do coro; negociar por frequência; calar-se de verdade (jogo furtivo puro) |
| **A viúva que espera** | NPC comum, sem poderes de combate | sua cabeça, legalmente | lembra de cada testemunho; processa, não ataca: vira recompensa oficial, contratos, traições | indenização pública, apelo a quem te ama, provar culpa de outro | lembra de cada testemunho; processa, não ataca: vira recompensa oficial, contratos, traições | indenização pública, apelo a quem te ama, provar culpa de outro |
| **Queda-Viva** | evento emergente endgame | reestilhaçar o que você juntou | escala com `Domínio` + `Ressonância` — é a sua pegada voltando contra você | dissolver seu próprio domínio (fim "anônimo" da era) |
| **O Nome que Sobrou** | o último fragmento da mente celestial | continuar existindo | propõe acordos com linguagem real (LLM sobre fatos do ledger) | recusa, fragmentação, simbiose, apagamento |

 Note que **três dos seis não são monstros** — e o jogo continua sendo um RPG de ação
por isso: um chefe jurídico, um chefe econômico e um chefe burocrático geram a mesma
tensão de um chefe de combate, porque a *IA os leva a agir no mundo* enquanto você decide.

### Escalonamento em co-op (1-4)

Nada de "multiplicar HP por 4". O mundo escala por **agência**: mais jogadores = mais
mentes hostis com metas, mais frentes (ele ataca sua base enquanto você luta), mais
testemunhas (melhor para Vínculo, pior para furtividade), e **preparação mais rápida**
porque a assinatura de estilo agregada do grupo é mais distinta. Companions preenchem os
slots de agência vazios, então um jogador solo enfrenta o mesmo *tipo* de mundo, com menos
mãos. Consequência compartilhada: quem deu a ordem, quem executou e quem emprestou a arma
ficam no ledger do chefe — e ele cobra de quem for mais vulnerável, o que em co-op cria
drama real entre jogadores sem nenhum sistema de "punição de grupo".
