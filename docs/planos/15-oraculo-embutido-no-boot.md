# 15 — Oráculo embutido no boot: o jogo levanta o llama-server, ninguém abre PowerShell

Dossiê de **leitura de código**, não de corrida: nenhuma engine rodou aqui e nenhum número
publicado por outros arquivos foi re-medido por este. As únicas coisas medidas nesta máquina são
as sondas de CLI do §0 — nenhuma delas é corrida da suíte, e nenhuma fecha gate. Autorização do
dono em 2026-11-20, na própria conversa, nas palavras dele: *"ao startar o game, tem que carregar
o modelo de i.a na maquina, rpa ser algo ja proximo do que quereomos, sem eu ter que abrir
depois... tem que ser algo embutido. depois vemos como fica pra quem nao tem palca de video"*. A
primeira metade é o pedido e entra como `[DECIDED]`; a segunda adia a máquina sem GPU, e adiado é
`[OPEN]`, não tarefa. Citações contra a `main` em `4ac5838`.

Posição na fila serializada: **09 → 10 → 15 → 14 → 11 → 12 → 13**. A 15 não depende de nenhuma
linha do código da matilha — não encosta em `src/entities/wolf.gd`, e em `src/main.gd` só pendura
um nó novo no boot — e é o caminho do `Rodar.bat`; a 14 depende da ronda por setor que a perna 10
já escreveu e pousou (código `0c38489`, `main` publicada `b779cee`). A exceção está registrada
**antes** do código, como exige
[`AGENTS.md`, mandato 4](../../AGENTS.md#L74-L78) ("a exceção se registra **antes** de escrever o
código, nunca na justificativa do commit") — ver §11.

## 0. Sondas locais que este arquivo fez (e o que elas derrubam)

Comando e saída, nesta máquina, em 2026-11-20. Não são corrida de engine; são leitura de
interface de programa, e servem para que nenhuma decisão abaixo nasça de suposição.

```sh
.tools/llama/runtime/llama-server.exe --version
#   version: 1.0.0-dev (build 12499, commit 401563f10)
#   built with Clang 20.1.8 for Windows x86_64
.tools/llama/runtime/llama-server.exe --help | grep -c "watch-file"     # 0
.tools/llama/runtime/llama-server.exe --help | grep -- "--timeout N"
#   -to,   --timeout N   server read/write timeout in seconds (default: 3600)
grep -a -c "kill_process"     .tools/Godot_v4.7.2-stable_win64.exe      # 0
grep -a -c "is_process_valid" .tools/Godot_v4.7.2-stable_win64.exe      # 0
grep -a -c "is_process_running" .tools/Godot_v4.7.2-stable_win64.exe    # 1
grep -a -c "get_process_exit_code" .tools/Godot_v4.7.2-stable_win64.exe # 1
```

Três consequências, cada uma derrubando uma pré-suposição que este briefing trouxe:

1. **Não existe `--watch-file` no b12499**, e `--timeout` é timeout de leitura/escrita do socket
   (default 3600 s) — não é saída por ociosidade. O servidor **não tem nenhum mecanismo de
   morrer junto com o jogo**: se o processo do jogo morre, o `llama-server` fica órfão, com a
   porta aberta e o modelo residente, até alguém matá-lo. Toda a disciplina de ciclo de vida do
   §4.3 existe por causa desta linha. O que existe e não é isto: `--sleep-idle-seconds` (help, e
   tools/server/README.md:251 do b12499) põe o modelo para dormir por ociosidade — não encerra o
   processo.
2. **O stub é de 9.728 B; a lógica está ao lado.** `llama-server.exe` mede 9.728 B e
   `ggml-vulkan.dll` 42.399.232 B no mesmo diretório — nada de estranhar ao ver um `.exe`
   minúsculo, e nada de copiá-lo sozinho para lugar nenhum.
3. **Os nomes da API de processo em Godot 4.7.2 não são os do briefing.** `OS.kill_process` e
   `OS.is_process_valid` são Godot 3; no motor pinado existem `OS.kill(pid)`,
   `OS.is_process_running(pid)` e `OS.get_process_exit_code(pid)` — registrado no §12 com o resto
   das âncoras que não conferem.

`[CLAIMED]` (fonte externa, pinada no mesmo build que [`fetch_models.ps1:94`](../../tools/fetch_models.ps1#L94)
instala e [THIRD_PARTY_LICENSES.md:14](../../THIRD_PARTY_LICENSES.md#L14) registra —
`https://raw.githubusercontent.com/ggml-org/llama.cpp/b12499/tools/server/README.md`):

| Fato do servidor | Onde, no arquivo do tag |
|---|---|
| `GET /health` é **público**: "no API key check", e `/v1/health` também funciona | tools/server/README.md:487 |
| `/health` devolve **503** `{"error":{... "Loading model"}}` enquanto carrega e **200** `{"status":"ok"}` quando está pronto | tools/server/README.md:490-495 |
| `--api-key KEY` existe; erro de autenticação é `401` `"Invalid API Key"` no formato OpenAI | tools/server/README.md:217, :2587-2591 |
| `GET /v1/models` "returns information about the loaded model", lista sempre com **um** elemento | tools/server/README.md:1367-1368 |
| `-a, --alias STRING` é "model name aliases … to be used by API" — o nome que o pedido do oráculo usa | tools/server/README.md:191 |
| `/health`, `/props`, `/models`, `/metrics` **não** contam como tarefa: não acordam um modelo adormecido nem resetam o ocioso | tools/server/README.md:2603-2607 |

A última linha é a que ensina por que um "keep-alive por poll de `/health`" não funciona, e a
primeira é a que faz o `--api-key` entrar no desenho (§4.2): se `/health` é público, ele
**não** distingue o nosso servidor do servidor de outra pessoa.

## 1. Premissas nomeadas

1. **Embutido é uma frase observável, e ela é falsificável:** com `Rodar.bat` e **nenhum**
   PowerShell aberto, a linha `ia:` do F3 aparece cheia dentro do prazo da cena de prova. Se a
   frase depende de um passo manual que o dono deu antes, o item não está feito — está
   documentado. Hoje o passo manual é instrução oficial ([`README.md:501-505`](../../README.md#L501-L505)).
2. **O boot não espera o modelo.** Nada em `_ready` nem em `_physics_process` bloqueia sobre um
   processo filho: `_ready` já bloqueia a janela com geração e malharia
   ([`main.gd:91`](../../src/main.gd#L91), [`:94`](../../src/main.gd#L94); ~0,9 s + ~4,3 s
   publicados em [`README.md:561`](../../README.md#L561)) e é exatamente por isso que o modelo
   **não** entra por essa porta. Vermelho por construção: um `await` síncrono no boot é a
   assinatura do congelamento que a casa já contou no boot do mesher.
3. **Reusar é diferente de matar.** Um servidor na porta que responde 200 ao `/v1/models` **com a
   nossa chave** é presumivelmente nosso e é reaproveitado; um que responde `401`, ou que não
   expõe o alias `mind-small`, é de terceiro e continua intocado. A checagem que prova o segundo
   caso é obrigatória, porque matar processo alheio é o dano mais caro que este lote pode causar.
4. **Nada do oráculo entra no caminho de simulação.** O mandato 2 do contrato
   ([`AGENTS.md:35-50`](../../AGENTS.md#L35-L50)) é citação deste dossiê, não paráfrase: "LLM/oráculo
   nunca decide movimento, dano, posição ou estado de mundo". Embutir **processo** não muda
   **autoridade**: a única saída do oráculo continua sendo `_narrations`
   ([`mind_oracle.gd:47`](../../src/ai/mind_oracle.gd#L47)) lida por `narration_of()`
   ([`:96-97`](../../src/ai/mind_oracle.gd#L96-L97)) e entregue só ao HUD
   ([`main.gd:142`](../../src/main.gd#L142) → [`hud.gd:276-279`](../../src/ui/hud.gd#L276-L279)).
5. **A suíte não levanta 2,7 GB.** `tests/smoke_test.gd` instancia a sessão real
   ([`:2`](../../tests/smoke_test.gd#L2), [`:76`](../../tests/smoke_test.gd#L76)), então qualquer
   host que `main.gd` subir sem condição de modo põe um modelo de
   [2.740.937.888 B](../../tools/fetch_models.ps1#L111) dentro do rodapé pinado da suíte
   (35,5 s, [`README.md:192`](../../README.md#L192)). A checagem 8 do
   §7 é o que impede isso de acontecer por distração.

## 2. Estado real do código (lido, não medido)

- **O oráculo é um cliente puro: ele não é dono de processo nenhum.** `SERVER_URL` é uma constante
  de porta ([`mind_oracle.gd:11`](../../src/ai/mind_oracle.gd#L11)), `REQUEST_TIMEOUT` 8,0 s e
  `RETRY_COOLDOWN` 30,0 s ([`:12-13`](../../src/ai/mind_oracle.gd#L12-L13)); `server_url` é `var`
  ([`:32`](../../src/ai/mind_oracle.gd#L32)) — ou seja, a porta **já é injetável**, e é por aí que
  o host passa a chave sem duplicar o `8741`. A sonda de boot usa o mesmo
  `HTTPRequest` do padrão da casa ([`:61-66`](../../src/ai/mind_oracle.gd#L61-L66),
  `request()` com headers em [`:122-124`](../../src/ai/mind_oracle.gd#L122-L124) (hoje o
  `auth_headers()` de [:102-103](../../src/ai/mind_oracle.gd#L102-L103)); o ciclo de
  requisição nem roda enquanto `_busy` ou `_server_cd > 0` ([`:75-76`](../../src/ai/mind_oracle.gd#L75-L76)).
- **A recuo global de 30 s é o que faz a primeira narrativa demorar.** Resposta vazia — servidor
  ausente, modelo ausente, resposta inútil — dispara `_server_cd = RETRY_COOLDOWN`
  ([`:162-174`](../../src/ai/mind_oracle.gd#L162-L174)) e o `_process` seguinte não tenta nada por
  30 s ([`:75`](../../src/ai/mind_oracle.gd#L75)). Numa sessão em que jogo e servidor sobem
  juntos, o primeiro pedido sai **antes** de o modelo estar pronto, leva 503/`401` ou falha de
  conexão, e o recuo engole a meia-minuta seguinte. É o defeito que a decisão 4 ataca, e ele já
  está visível no log do probe atual, que imprime `recuo do servidor=`
  ([`live_oracle_probe.gd:38`](../../tests/live_oracle_probe.gd#L38)).
- **Quem sobe o servidor hoje é um script, e ele é sincero sobre isso.**
  [`run_mind_server.ps1`](../../tools/run_mind_server.ps1): parâmetros `Port 8741`, `Ctx 4096`,
  `GpuLayers 99` ([`:11-15`](../../tools/run_mind_server.ps1#L11-L15)), binário e modelo
  resolvidos em `.tools\llama\runtime\llama-server.exe` e `models\qwen3.5-4b-q4_k_m.gguf`
  ([`:19-20`](../../tools/run_mind_server.ps1#L19-L20)), `throw` se faltar qualquer um dos dois
  ([`:22-27`](../../tools/run_mind_server.ps1#L22-L27)) e as flags
  `-m --host --port -c -ngl --alias mind-small --reasoning off`
  ([`:30-37`](../../tools/run_mind_server.ps1#L30-L37)). Não há `--api-key` na linha de comando de
  hoje — é o que a decisão 2 acrescenta, com a consequência obrigatória do §4.2.
- **O caminho de 1 clique não menciona llama.** [`Rodar.bat:5`](../../Rodar.bat#L5) chama
  `tools\run_game.ps1`; o launcher resolve o motor pinado
  ([`:60-64`](../../tools/run_game.ps1#L60-L64)), roda `--import` quando falta o cache de classes
  ([`:413-421`](../../tools/run_game.ps1#L413-L421), argv em `:357`), recusa a segunda janela do
  mesmo save com exit 2 ([`:400-405`](../../tools/run_game.ps1#L400-L405), ecoado em
  [`Rodar.bat:7-13`](../../Rodar.bat#L7-L13)), tem os modos `-CheckOnly/-Editor/-Tests`
  ([`:28-33`](../../tools/run_game.ps1#L28-L33)) e abre o motor por `Start-Process` com verificação
  de 6 s ([`:313-320`](../../tools/run_game.ps1#L313-L320), usado em
  [`:431-434`](../../tools/run_game.ps1#L431-L434)). **`grep -ni llama` neste arquivo devolve zero
  ocorrências**: o botão que o dono aperta hoje abre o jogo **sem** oráculo. É isto que "embutido"
  quer dizer, em termos de arquivo.
- **Os packs ficam fora do repositório, e é decisão de licença, não de conforto.**
  `models/` e `.tools/` estão no [`.gitignore:13`](../../.gitignore#L13) e
  [`:5`](../../.gitignore#L5); os packs são baixados por
  [`fetch_models.ps1:91-101`](../../tools/fetch_models.ps1#L91-L101) (runtime b12499, 38.603.682 B,
  sha256 `84db9d18…`) e [`:106-115`](../../tools/fetch_models.ps1#L106-L115) (Qwen3.5-4B Q4_K_M,
  2.740.937.888 B, sha256 `00fe7986…`), com licença registrada em
  [THIRD_PARTY_LICENSES.md:13-14](../../THIRD_PARTY_LICENSES.md#L13-L14). Baixar modelo dentro do
  jogo é `ModelPackFetcher`, que o roadmap deixa em **P4**
  ([`docs/design/08:32`](../../docs/design/08-roadmap-risks-licensing.md#L32)) ao lado de
  `native/af_mind` **embutido** — ver §3, onde a palavra é desambiguada.
- **A degradação já tem checagem, e ela é a que não pode quebrar.** A suíte aponta uma sonda para
  a porta 1 de propósito ([`smoke_test.gd:2083-2089`](../../tests/smoke_test.gd#L2083-L2089)),
  com passo armado em `:108` e verificação em `:109`
  ([`:2092-2101`](../../tests/smoke_test.gd#L2092-L2101)): narrativa vazia, recuo global > 0 e a
  mente decidindo sem narrador. O caminho feliz, ele, depende de servidor de fora
  ([`docs/design/04:209-213`](../../docs/design/04-local-ai-architecture.md#L209-L213)) e é o único
  que este dossiê tenta tirar da mão do humano.
- **Onde o estado novo mora hoje.** `main.gd` é o objeto deus conhecido: 662 linhas donas de
  mundo, relógio, matilha, HUD, oráculo, visualização, journal, áudio e o hospedeiro do
  modelo ([`:9-68`](../../src/main.gd#L9-L68)), com `_exit_tree` já existente fechando só o
  journal ([`:661-662`](../../src/main.gd#L661-L662)). É o único ponto do boot que hoje tem ciclo de vida
  de recurso externo — e é o encaixe da decisão 1.

## 3. O que "embutido" exige — e o que a palavra não é aqui

O design usa "embutido" para outra coisa, e confundir as duas custaria um lote de GDExtension.
[`docs/design/08:32`](../../docs/design/08-roadmap-risks-licensing.md#L32) lista como gate de
**P4** `native/af_mind` **embutido**, schemas GBNF, `oracle_cache`, embeddings,
`ModelPackFetcher` dentro do jogo; [`docs/design/04:155`](../../docs/design/04-local-ai-architecture.md#L155)
abre a seção da camada 5 e [`:160-161`](../../docs/design/04-local-ai-architecture.md#L160-L161)
escreve a implementação nativa (`native/af_mind/` = GDExtension C++ ligada a llama.cpp, backend
Vulkan). Nada disso é o pedido do dono. O pedido dele é de **operador**: o
processo que hoje ele sobe na mão tem de subir com o jogo, e morrer com o jogo.

| | O que entra (15) | O que **não** entra (P4, `[TARGET]`) |
|---|---|---|
| Modelo | continua fora do repositório, baixado uma vez por `fetch_models.ps1` | `ModelPackFetcher` dentro do jogo |
| Transporte | continua HTTP local (`HTTPRequest`) | `native/af_mind` (GDExtension + llama.cpp no processo) |
| Processo | **novo:** o jogo cria e encerra o `llama-server` | — |
| Autoridade | inalterada: só narrativa no F3 | propostas validadas por schema |

Exigências mínimas, cada uma com o motivo:

1. **Zero passo manual no caminho feliz.** `Rodar.bat` → F3 com `ia:`. Se falta pack, o jogo diz
   por quê (mandato 1: nenhum fallback que finja sucesso —
   [`AGENTS.md:29-34`](../../AGENTS.md#L29-L34)).
2. **Boot assíncrono.** O servidor é levantado por `OS.create_process`, que volta com o pid
   imediatamente; o resto do `_ready` e os frames seguem correndo durante a carga do modelo.
3. **Chave compartilhada entre host e oracle** — sem ela o embutimento **quebra** a narrativa que
   já existe hoje (ver §4.2: é a única exigência deste lote que toca `mind_oracle.gd`).
4. **Higiene de ciclo de vida nos dois sentidos:** encerrar o filho que **eu** subi, nunca tocar
   num que não é meu, e detectar morte antecipada sem virar loop de reinício.
5. **Verificação em headless com log**, cena própria (§7) — o precedente é a sonda de oráculo
   vivo, isolada em cena exatamente para não virar fallback silencioso dentro de `MindOracle`
   ([`AGENTS.md:251-253`](../../AGENTS.md#L251-L253)).

## 4. As sete decisões, `[DECIDED]`

**4.1 — Dono novo: `src/ai/llm_server_host.gd`.** Uma classe `LlmServerHost extends Node` que
segura o pid, a máquina de estados e o `HTTPRequest` da sonda. `main.gd` não recebe estado novo
por gosto: ele é o objeto deus documentado como débito
([`AGENTS.md:243-246`](../../AGENTS.md#L243-L246)), e a posse de processo filho é um estado com
nome próprio. O host entra na árvore ao lado do `MindOracle` ([`main.gd:138-145`](../../src/main.gd#L138-L145))
e é o único que conhece `pid`.

**4.2 — Sonda de boot: `GET /v1/models`, três respostas, três destinos.** Antes de criar
qualquer coisa, o host pergunta à porta (timeout curto, injetado — nunca o default):

| Resposta | Leitura | Ação |
|---|---|---|
| `200` **com a nossa chave** e o alias `mind-small` presente | sobrou um servidor nosso (crash anterior, ou a segunda janela) | **reusar** — é o boot mais rápido possível, e reusar **não** dá direito a matar |
| `401` (`"Invalid API Key"`) | é um `llama-server` de terceiro, ou o nosso com outra chave | **não matar processo alheio**; rodar sem oráculo, com o motivo impresso |
| conexão recusada | ninguém na porta | subir o nosso com `OS.create_process` |

`/health` **não** serve para essa distinção: ele é público por documentação
(tools/server/README.md:487 do b12499, §0) — logo um servidor estranho responde 200 nele. É por
isto que o `--api-key` entra, e **não** por segurança: a chave local é o *imprint* que separa
"nosso" de "estrangeiro" num `localhost` compartilhado. Consequência obrigatória, no mesmo lote:
com `--api-key` no servidor, todo `/v1/chat/completions` sem o header `Authorization: Bearer` é
`401` — e `401` cai no `text.is_empty()` de
[`mind_oracle.gd:162-174`](../../src/ai/mind_oracle.gd#L162-L174), que hoje vira recuo de 30 s em
silêncio. Desde 2026-11-21 a chave **não mora no repositório**: `resolve_api_key()` lê
([`KEY_ENV` e `KEY_FILE`](../../src/ai/mind_oracle.gd#L19-L20)) e, sem as duas fontes,
sorteia 32 hex e grava o arquivo ([`:219-241`](../../src/ai/mind_oracle.gd#L219-L241));
o `run_mind_server.ps1` lê as **mesmas duas fontes** e recusa sem nenhuma
([`:35-42`](../../tools/run_mind_server.ps1#L35-L42)). O `_request` manda o header pelos
`auth_headers()` de ([`:102-103`](../../src/ai/mind_oracle.gd#L102-L103)). A porta continua
tendo **um** dono: o `server_url` do oráculo ([`:32`](../../src/ai/mind_oracle.gd#L32)); o
host lê o valor do oracle em vez de repetir `8741`, que aparece em dois lugares
([`mind_oracle.gd:11`](../../src/ai/mind_oracle.gd#L11) e [`ps1:20`](../../tools/run_mind_server.ps1#L20)).

**4.3 — Ciclo de vida nos três pontos de saída, com os nomes certos da API.** No fecho da janela
e em [`main.gd:_exit_tree`](../../src/main.gd#L661-L662) (onde o journal já é fechado — o único
precedente de liberação de recurso externo que existe na casa), `OS.kill(pid)` no filho **que o
host criou**; `pid = -1` em caso de reuso significa "nada a matar". Morte antecipada se detecta
com `OS.is_process_running(pid)` em cadência própria, **uma** retentativa por sessão — a segunda
morte é fim de tentativa, porque o §0.1 garante que nada no servidor se autocorrige. Documentado
no motor: o processo criado "It will not terminate when Godot terminates"
(`doc/classes/OS.xml` do godot 4.7, método `create_process`) — a frase é a licença para o órfão, e
o motivo de o `_exit_tree` ser obrigatório e não cosmético. `get_process_exit_code(pid)` existe
para o caso de morte por erro (imprime o código em vez de adivinhar).

**4.4 — O oráculo espera o primeiro `/health` 200 (ou um prazo explícito).** Hoje a primeira
narrativa de uma sessão que abriu o servidor junto com o jogo demora ~30 s por culpa do recuo
([`mind_oracle.gd:162-174`](../../src/ai/mind_oracle.gd#L162-L174) + [`:75`](../../src/ai/mind_oracle.gd#L75)).
O host expõe `ready()`/sinal próprio; o `MindOracle` não emite pedido nenhum antes dele, e um
`503` de "Loading model" **não** é falha — é "espera mais um pouco", que é justamente o que o
recuo de 30 s transforma em silêncio. O prazo é uma constante nomeada com o valor que a medição 1
do §8 decidir; até lá ele é `[OPEN]`, não `120 s` herdado do probe
([`live_oracle_probe.gd:9`](../../tests/live_oracle_probe.gd#L9)).

**4.5 — Nada disto entra no caminho de simulação, e a citação é do mandato.**
[`AGENTS.md:35-50`](../../AGENTS.md#L35-L50): *"**A mente propõe, as regras dispõem.**
LLM/oráculo nunca decide movimento, dano, posição ou estado de mundo"*. O host vive em
`_process`/timers próprios, **fora** de [`main.gd:_sim_tick`](../../src/main.gd#L223-L249) e fora
dos 50 ms que o passo divide com os lobos; o `--reasoning off` já é condição do servidor
([`run_mind_server.ps1:37`](../../tools/run_mind_server.ps1#L37)) e continua. A saída do oráculo
não muda de tipo: `_narrations` ([`mind_oracle.gd:47`](../../src/ai/mind_oracle.gd#L47)) →
`narration_of()` → F3 ([`hud.gd:276-279`](../../src/ui/hud.gd#L276-L279)).

**4.6 — Verificação é headless, e por uma razão que é fato de engine.** `OS.create_process` é
implementado no Windows e não depende de janela — a sonda roda em `--headless`. O boot real do
servidor é colhido por cena de prova **própria** (`tests/llm_server_boot_probe.tscn`), no estilo
de [`live_oracle_probe.tscn`](../../tests/live_oracle_probe.tscn), isolada em cena justamente
para não virar fallback silencioso dentro de `MindOracle`
([`AGENTS.md:251-253`](../../AGENTS.md#L251-L253)). A suíte **não** levanta o modelo: em
`DisplayServer.get_name() == "headless"` (nome documentado no motor) `main.gd` **não** instancia o
host, e é a cena de prova que o constrói explicitamente. O motivo é a premissa 5 do §1, e a
checagem 8 do §7 é o guarda dela.

**4.7 — O que fica `[OPEN]` e o que o dono adi.** (i) Tempo até `/health` devolver 200 com
`-ngl 99` nesta máquina; (ii) pegada real de VRAM/RAM do processo com o modelo residente — só o
alvo de design existe ([`docs/design/04:164-166`](../../docs/design/04-local-ai-architecture.md#L164-L166):
`~2–4 GB`, `[TARGET]`), nenhum número medido. (iii) Máquinas sem placa de vídeo: adiado pelo dono
na mesma frase do pedido, então nada aqui escolhe backend CPU, `--n-gpu-layers 0` ou servidor
remoto; é a primeira linha do §8 quando ele for aberto. (iv) Porta fixa ocupada por outro app:
a decisão 4.2 recusa matar e recusa adivinhar; se um dia o custo aparecer, a alternativa é porta
dinâmica + `oracle.server_url` escrito pelo host ([`:32`](../../src/ai/mind_oracle.gd#L32) já é
`var`), e isso é escolha de versão, não detalhe.

## 5. Matriz de falha

Cada linha tem de ter o estado impresso no log e na linha nova do F3 — não no console do motor,
não em popup.

| Gatilho | Como se detecta | O que o host faz | O que aparece | O que a checagem prova |
|---|---|---|---|---|
| **Sem binário** (`llama-server.exe` ausente; o `throw` do passo manual hoje é em [`run_mind_server.ps1:22-24`](../../tools/run_mind_server.ps1#L22-L24)) | `FileAccess.file_exists` no caminho resolvido, **antes** de qualquer `create_process` | estado `ausente`; nenhum pedido HTTP é emitido | `llm: ausente (runtime)  rode tools\fetch_models.ps1 -Pack runtime` | 7: nenhuma requisição saiu, narrativa vazia, jogo íntegro |
| **Sem modelo** (`.gguf` ausente — [`:25-27`](../../tools/run_mind_server.ps1#L25-L27)) | idem, caminho do `models/` | estado `ausente` com o motivo **diferente** do anterior | `llm: ausente (modelo)  rode tools\fetch_models.ps1 -Pack mind-small` | 7: os dois motivos não se confundem (mandato 1: sem placeholder bonito) |
| **Porta ocupada por terceiro** (`401`, ou 200 sem o alias `mind-small`, ou um não-llama) | a sonda de `GET /v1/models` com a nossa chave | **nada**: não mata, não reusa, não muda de porta; estado `estrangeiro` | `llm: porta 8741 ocupada por outro servidor  oraculo desligado` | 4: o listener **continua vivo** depois do run, e nenhum `OS.kill` foi chamado com pid alheio |
| **Servidor morre no meio da sessão** (crash, OOM, usuário no Task Manager) | `OS.is_process_running(pid)` na cadência do host; código por `get_process_exit_code` | **uma** retentativa; segunda morte = sessão sem oráculo, sem novo retry | `llm: caiu (codigo N)  retentativa 1/1` e depois `llm: desligado` | 5: transições impressas, contagem de retentativas == 1 (não 2, não infinito) |
| **Janela fechada** (fecha normal, `quit()`, ou morte do processo do jogo) | `_exit_tree` roda nos dois primeiros; no terceiro, não | `OS.kill` no pid **que ele criou**; pid de reuso não é tocado | nada na tela — o filho some, e a porta recusa conexão no próximo boot | 6: após o término, a porta está fechada; se estava aberta, o teste dá vermelho com o pid impresso (órfão) |
| **Duas janelas do mesmo save** (o launcher recusa exit 2 — [`run_game.ps1:400-405`](../../tools/run_game.ps1#L400-L405) — mas `-Force` e o editor existem) | a segunda janela sonda a porta antes de criar | a segunda **reusa** (estado `reusado`, pid `-1`) | `llm: reuso do servidor existente` | 3: dois boots, um processo; a janela que reusou não mata nada ao fechar |

O último caso é o único com degradação conhecida e aceita: se a janela **dona** do processo fecha
primeiro, a outra perde o oráculo no meio da partida e cai no caminho já checado pela suíte
([`smoke_test.gd:2092-2101`](../../tests/smoke_test.gd#L2092-L2101)). Registro aqui, não em
surpresa depois: o host mata o que ele subiu, e "não matar o que não é meu" tem este preço.

## 6. Custo — as quatro perguntas

- **Frame, tick ou às vezes?** O host roda **por frame** (`_process`), não por tick: é um nó I/O
  com um `HTTPRequest` em voo, no mesmo padrão do oráculo
  ([`mind_oracle.gd:71-91`](../../src/ai/mind_oracle.gd#L71-L91)), e nada do que ele faz é
  determinístico nem entra em `state_hash()` ([`main.gd:647-648`](../../src/main.gd#L647-L648)). Enquanto carrega: uma sonda por cadência
  curta (~0,2 s, **proposto**, não medido). Depois de pronto: só a verificação de vida por
  cadência de 1 s, seguindo o precedente de [`main.gd:16`](../../src/main.gd#L16). O custo pesado
  (carga do modelo, inferência) é **de outro processo**, fora dos 50 ms do passo
  ([`main.gd:214-220`](../../src/main.gd#L214-L220)) e fora dos 400 µs do `SubtreeGuard`.
- **Quantas entidades são alcançadas?** Um processo filho, uma porta TCP local, zero lobos. A
  matilha inteira é alcançada **só** pelo caminho que já existe (o round-robin do oráculo,
  [`:75-91`](../../src/ai/mind_oracle.gd#L75-L91)).
- **Aloco no caminho quente?** Não: `PackedStringArray` de argv **uma vez** por boot, um
  `HTTPRequest` filho do host, um `Dictionary` de estado. O que continua sendo débito da casa são
  os dicionários do BT e o `PackedInt32Array` da difusão
  ([`AGENTS.md:169-174`](../../AGENTS.md#L169-L174)) — este lote não melhora
  nem piora essa conta.
- **Como sei que ficou melhor?** Ainda não existe: os dois números do §8 são a resposta, e até
  eles existirem o lote não pode dizer "o boot ficou N s mais caro/barato". O que **dá** para
  afirmar agora, derivado de número publicado e não medido para este fim: subir o servidor no topo
  do `_ready` ([`main.gd:71`](../../src/main.gd#L71), antes da geração em `:91` e da malharia em
  `:66`) compra ~5,2 s de sobreposição com os ~0,9 + ~4,3 s de boot de mundo
  ([`README.md:561`](../../README.md#L561)) — **derivado**, e a checagem 2 imprime o número real.
- **Licenças e rede, para fechar o tripé:** nada novo. O runtime e o modelo já são MIT/Apache-2.0
  ([THIRD_PARTY_LICENSES.md:13-14](../../THIRD_PARTY_LICENSES.md#L13-L14)), o `.gguf` continua
  fora do repositório ([`.gitignore:13`](../../.gitignore#L13)) e o tráfego continua
  `127.0.0.1` ([`mind_oracle.gd:11`](../../src/ai/mind_oracle.gd#L11)) — nenhum dado sai da
  máquina, que é a premissa de "IA 100% local" do design
  ([`docs/design/README.md:65-66`](../../docs/design/README.md#L65-L66)).

## 7. Gate em headless

```sh
godot --headless --path . --import
godot --headless --path . --check-only --script src/ai/llm_server_host.gd
godot --headless --path . tests/llm_server_boot_probe.tscn      # a cena nova; sem ela, nada aqui foi exercitado
godot --headless --path . tests/smoke_test.tscn                  # a suíte, que não pode passar a carregar modelo
```

Cada checagem nomeia a premissa que exige e imprime o número que a decide — regra da casa
([`AGENTS.md:377-380`](../../AGENTS.md#L377-L380)):

1. **`host_devolve_health_200`** — *premissa:* `OS.create_process` com o binário pinado levanta um
   servidor que responde **200** no `/health` nesta máquina. Imprime `ms_ate_200`, contagem de
   `503` vistos, `pid`. Vermelho no prazo; `503` **não** é vermelho (é o "Loading model" do §0).
2. **`boot_nao_bloqueia_janela`** — *premissa:* nada espera o modelo de forma síncrona. Enquanto o
   host está em `carregando`, a cena conta frames e `clock.tick`
   ([`main.gd:214-220`](../../src/main.gd#L214-L220)); imprime os dois. Vermelho com `frames == 0`
   ou `worst_step_ms` fora da banda da revisão.
3. **`reuso_nao_cria_segundo_processo`** — *premissa:* servidor nosso já na porta ⇒ pid próprio
   `-1`, estado `reusado`, nenhuma narrativa perdida. Feito com a flag **da cena** `--keep` no run
   A (deixa o filho vivo de propósito) e run B sem ela; é o exercício do estado "sobrou de um
   crash", não uma simulação dele.
4. **`porta_alheia_continua_viva`** — *premissa:* `401`/alias errado **não** mata ninguém. Fixture:
   um listener HTTP **de fora do repositório** (script descartável em `.tools/`, nunca em `src/`)
   na 8741 respondendo 401; o run afirma `estrangeiro`, nenhum `OS.kill`, e o listener respondendo
   **depois** de o jogo ter terminado. Sentido oposto obrigatório (regra 3 do ciclo de trabalho) (regra 3 do ciclo de trabalho): com a chave certa e o
   alias certo, o mesmo fixture tem de ser lido como `reusado`.
5. **`morte_aceita_uma_retentativa`** — *premissa:* morte antecipada é detectada e **uma** vez.
   Mata o filho de fora (`taskkill /PID`) depois do 200; imprime a sequência de estados e
   `retentativas`. Vermelho se for 0 (não viu) ou ≥ 2 (loop).
6. **`fechar_janela_mata_o_filho`** — *premissa:* `_exit_tree` não deixa órfão — o caso que o
   §0.1 prova existir. Comando externo, depois de `quit()`, tenta a porta: recusada ⇒ verde;
   `200` ⇒ vermelho com o pid residual impresso.
7. **`sem_packs_sem_sucesso_fingido`** — *premissa:* binário/modelo ausentes dão **dois** motivos
   distintos e zero pedidos. Roda a cena com caminho apontado para arquivo inexistente via flag
   própria; imprime `requisicoes_emitidas` (tem de ser 0), estado e texto do F3.
8. **`suite_nao_levanta_modelo`** — *premissa:* em headless `main.gd` não cria o host
   (decisão 4.6). Duas metades: na suíte, `main.has_llm_host() == false`; no probe, o
   `DisplayServer.get_name()` impresso. E o rodapé de tempo da suíte fica na banda da revisão —
   se o host entrasse, não entraria nos 2,7 GB sem aparecer.
9. **`narrativa_chega_sem_passo_manual`** — *a checagem do pedido literal do dono:* nenhum
   PowerShell nosso, só o boot do jogo; duas narrativas não vazias dentro do prazo (o critério de
   [`live_oracle_probe.gd:10`](../../tests/live_oracle_probe.gd#L10), `NEEDED = 2`, reaproveitado
   como **consequência** do boot embutido, não como o caminho manual que ele documenta em
   [`:6-7`](../../tests/live_oracle_probe.gd#L6-L7)).
10. **`chave_do_oraculo_bate_com_a_do_host`** — *premissa:* `--api-key` no servidor não silenciou a
    narrativa. Dois sentidos, um só run: `POST /v1/chat/completions` **sem** header ⇒ `401` (e o
    `401` tem de ser impresso como `llm: 401`, não como recuo anônimo em
    [`mind_oracle.gd:162-174`](../../src/ai/mind_oracle.gd#L162-L174)); **com** o header ⇒ `200`.

`EXPECTED_CHECKS` (hoje 150 em [`aether_reactions_test.gd:20`](../../tests/aether_reactions_test.gd#L20)),
os censores irmãos (audio 73, simulation_rng 27, journal 128) e o rodapé da suíte **não mudam por
este lote se as checagens 1-10 viverem na cena de prova** — que é o plano. Se alguma delas entrar
na suíte, o número vira invariante no mesmo commit, anunciado antes de escrever.

## 8. Os dois números que faltam (e como cada um sai)

Nenhum dos dois existe hoje nesta árvore, e este dossiê não publica estimativa nenhuma. Quem
implementar mede, com máquina livre — medição de tempo é serial
([`AGENTS.md:404-406`](../../AGENTS.md#L404-L406)).

1. **Tempo até `/health` devolver 200 com `-ngl 99`** na RX 9060 XT: o intervalo entre
   `OS.create_process` voltar com o pid e o primeiro `200`, com a contagem de `503` no meio (a
   checagem 1 do §7 imprime os dois). O número análogo já publicado é o `boot 9,5 s` da tabela
   `[MEASURED]` de [`docs/design/04:225-226`](../../docs/design/04-local-ai-architecture.md#L225-L226)
   (mesmo valor em [`README.md:507`](../../README.md#L507)), mas **não é esta grandeza**: ele veio
   da corrida do probe com o servidor ligado na mão, e não é o que o prazo da decisão 4.4 consome.
   É a única coisa que autoriza escrever o prazo de boot como número, e o valor de hoje do prazo é
   `[OPEN]`.
2. **Pegada real de VRAM/RAM do processo filho com o modelo residente.** Só existe alvo de design:
   `~2–4 GB` de VRAM para `mind-small` ([`docs/design/04:164-166`](../../docs/design/04-local-ai-architecture.md#L164-L166),
   `[TARGET]`) e o arquivo de 2.740.937.888 B ([`fetch_models.ps1:111`](../../tools/fetch_models.ps1#L111)).
   O que está em `[OPEN]` é o processo real nesta placa (AMD, então o número não vem de
   `nvidia-smi`) e a quantificação do que o jogo perde de GPU enquanto o modelo está carregado —
   a contenção entre render e inferência é risco escrito no próprio design
   ([`docs/design/04:190-193`](../../docs/design/04-local-ai-architecture.md#L190-L193): "o GPU
   divide com render — contenção é o risco real"). A sonda que produz este número ainda **não foi
   rodada**, e por isso ele não aparece em nenhum outro arquivo deste repositório.

## 9. O que NÃO fazer

- Nenhum `await` síncrono no `_ready`, nenhum laço que trave a janela esperando o modelo. O
  congelamento de boot já foi contado uma vez nesta casa ([`README.md:561-562`](../../README.md#L561-L562)).
- Não matar processo que não foi criado por este host, sob pretexto nenhum — inclusive "era o
  nosso de ontem". Reuso sim, `kill` só em pid próprio.
- Não baixar modelo nem descompactar runtime dentro do jogo: `fetch_models.ps1` continua sendo o
  passo manual único, e o fetch embutido é P4 (`ModelPackFetcher`,
  [`docs/design/08:32`](../../docs/design/08-roadmap-risks-licensing.md#L32)).
- Não duplicar a porta: `8741` tem um dono em `src/` ([`mind_oracle.gd:11`](../../src/ai/mind_oracle.gd#L11));
  o host lê `server_url` ([`:32`](../../src/ai/mind_oracle.gd#L32)). Uma constante repetida é
  exatamente a deriva que os furos deste repositório cobram.
- Não transformar `401`/`503`/timeout num recuo anônimo de 30 s: cada estado tem de imprimir o
  código que o produziu. Silenciar a falha é o mandato 1 ao contrário.
- Não deixar o host subir em headless "para testar": a suíte é a corriqueira; o modelo é de 2,7 GB
  e o §7 tem cena própria para isso.
- Não botar nada disto em `_sim_tick`, em `_physics_process` do lobo, nem no hash do journal
  ([`main.gd:214-249`](../../src/main.gd#L214-L249), [`:647-648`](../../src/main.gd#L647-L648)):
  processo de oráculo não é estado de mundo.
- Não propor GDExtension, `native/af_mind`, GBNF, embeddings ou `oracle_cache` "porque já estamos
  mexendo no oráculo": é P4 e está fora do escopo autorizado
  ([`AGENTS.md:273-275`](../../AGENTS.md#L273-L275)).
- Não resolver "máquina sem placa de vídeo" agora: o dono adiou, e adiado é `[OPEN]`.

## 10. Commits atômicos

Branch `docs/oracle-embutido-15` primeiro (este arquivo + a ordem serializada), e a perna de
código depois, `feat/oraculo-embutido-no-boot-15`, base `main`, merge `--no-ff`, suíte verde entre
cada um, um assunto por commit com a corrida que lhe responde:

(a) `src/ai/llm_server_host.gd` com a sonda de `GET /v1/models`, a chave e o `create_process` + as
checagens 1 e 3; (b) ciclo de vida — `_exit_tree`, fecho da janela, `is_process_running` e a
retentativa única, com 5 e 6; (c) o lado do oráculo: header de autenticação e o gate de
prontidão que substitui o recuo cego no boot, com 10 e 9 — **este** é o commit que pode quebrar a
narrativa que já existe, e por isso ele tem as duas checagens; (d) `Rodar.bat` /
`run_mind_server.ps1` / texto do [`README.md:501-514`](../../README.md#L501-L514) dizendo que o
servidor agora sobe sozinho e que o passo manual virou opção; (e) as checagens 2, 4, 7 e 8 com os
fixtures fora de `src/`; (f) medição 1 e 2 do §8, publicadas com log na mesa, e só então o prazo
de boot vira constante numérica; (g) re-derivação das citações que o lote tornou velhas e o
`docs/melhorias-status.md`.

Nenhum desses commits fecha gate de fase (mandato 4), e nenhum número do §8 entra como "medido"
sem o log da corrida que o produziu.

## 11. Registro de ordem (a exceção, escrita antes do código)

A fila serializada passa a **09 → 10 → 15 → 14 → 11 → 12 → 13**: a 15 não depende do código da
matilha (é o caminho do boot, e não encosta em `wolf.gd`), enquanto a 14 depende da ronda por
setor que a perna 10 já escreveu e pousou (código `0c38489`, `main` publicada `b779cee`). Escrito **antes** de qualquer linha de `src/`, porque
é a regra do contrato — [`AGENTS.md:74-78`](../../AGENTS.md#L74-L78) e a cláusula de um escritor
por arquivo ([`AGENTS.md:430-432`](../../AGENTS.md#L430-L432)); o custo de não ordenar está
medido no incidente do dossiê 03. A fila vive em dois lugares do contrato — o parágrafo de exceção
em [`AGENTS.md:292-295`](../../AGENTS.md#L292-L295) e a ordem nova em
[`AGENTS.md:343-345`](../../AGENTS.md#L343-L345) — e a edição dos dois, com o registro no índice
([`docs/planos/README.md`](README.md)), é o commit 2 desta branch.

Fica **sabido, e corrigido no passe de status desta ponta**: as duas strings de ordem antigas
estavam em [`docs/melhorias-status.md:295`](../../docs/melhorias-status.md#L295) e
[`:2291`](../../docs/melhorias-status.md#L2291) na numeração em que este dossiê foi escrito
(`4ac5838`), e ambos os alvos eram verdadeiros ali. O que os moveu foi o crescimento do próprio
status — a perna 10 escreveu 285 linhas aqui dentro e esta nota, mais 206. Lidos pelo conteúdo na
ponta, os dois alvos são [`:329`](../../docs/melhorias-status.md#L329) e
[`:2410`](../../docs/melhorias-status.md#L2410), e cada um agora diz a ordem da época **e** a
ordem vigente, em vez de ser reescrito: o mandato 4 registrava a exceção antes do código, e o
passe de status era o mesmo commit que a fecha. Editar o meio do status empurra cada linha
abaixo dele — é o mecanismo que a página índice explica — e por isso o número novo foi achado
lendo a frase, não transladando a diferença de tamanho do arquivo.

## 12. Âncoras que não conferem (registradas, não consertadas aqui)

Achados ao ler as duas pontas, todos verificados por conteúdo nesta árvore (`4ac5838`). Nenhuma
delas muda mandato: é deriva de linha e nome de API.

- **Nomes de API que o briefing trouxe do Godot 3:** `OS.kill_process` e `OS.is_process_valid`
  não existem no motor pinado (0 ocorrências no `.exe`, §0); os nomes são `OS.kill`,
  `OS.is_process_running`, `OS.get_process_exit_code`.
- [`docs/melhorias-status.md:70`](../../docs/melhorias-status.md#L70) e
  [`:522-523`](../../docs/melhorias-status.md#L522-L523) apontam a degradação do oráculo para
  `tests/smoke_test.gd:1967-1973`, que é `_check_glide_fall` (planar e queda). Os fatos estão em
  [`smoke_test.gd:2045-2068`](../../tests/smoke_test.gd#L2045-L2068) (porta 1 armada em `:2052`),
  com os passos registrados em [`:104-105`](../../tests/smoke_test.gd#L104-L105).
- As citações de `main.gd` no contrato estão defasadas **+9** a partir do bloco de diagnóstico —
  conferidas só onde este dossiê encosta: `diagnostics()` é
  [`main.gd:444-455`](../../src/main.gd#L444-L455) (o contrato diz `435-446`), o journal em
  [`:454`](../../src/main.gd#L454) (diz `445`), `state_hash()` em
  [`:495-496`](../../src/main.gd#L495-L496) (diz `486-487`), a CLI do journal em
  [`:499-506`](../../src/main.gd#L499-L506) (diz `490-498`) e `_exit_tree` em
  [`:509-510`](../../src/main.gd#L509-L510) (diz `500-501`). As demais do contrato não foram
  relidas por mim, e é a perna de re-derivação por conteúdo que as alcança.
- **Estes números são os de `4ac5838` e ficam como foram escritos**: a seção é registro do que
  estava em pé naquela árvore, e transladá-la apagaria a medição — inclusive o `+9` do parágrafo
  acima, que é a diferença *daquela* base. Na ponta desta branch, lidos por conteúdo (a fatia de
  linha confere linha a linha, sem offset adivinhado), os alvos são `diagnostics()`
  [`:592-607`](../../src/main.gd#L592-L607), a linha do journal dentro dela
  [`:603`](../../src/main.gd#L603), `state_hash()`
  [`:647-648`](../../src/main.gd#L647-L648), a CLI [`:651-658`](../../src/main.gd#L651-L658) e
  `_exit_tree` [`:661-662`](../../src/main.gd#L661-L662); na suíte o passo de planar é
  [`:2001-2007`](../../tests/smoke_test.gd#L2001-L2007) (+34), o bloco do oráculo
  [`:2079-2102`](../../tests/smoke_test.gd#L2079-L2102) com a porta 1 armada em
  [`:2086`](../../tests/smoke_test.gd#L2086), e os dois passos em
  [`:108-109`](../../tests/smoke_test.gd#L108-L109). Dos dois ponteiros para o status, o `:70`
  continua na linha (a tabela de prompts) e já cita `smoke_test.gd:2081-2086`; o `:522-523` era o
  item de débito do gate do oráculo, que hoje está em
  [`:575-577`](../../docs/melhorias-status.md#L575-L577) e com o alvo da degradação já corrigido.
- `llama-server.exe` **não é** o programa inteiro: 9.728 B de stub com a lógica em DLLs ao lado
  (§0.2). Qualquer texto futuro que proponha "copiar o `.exe`" está errado.
- O `--timeout` do servidor não é ociosidade, e `--watch-file` não existe no b12499 (§0.1) — as
  duas pré-suposições que fariam o "ele se desliga sozinho" parecer verdade.
