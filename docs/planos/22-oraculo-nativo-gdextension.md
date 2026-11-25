# 22 — Oráculo nativo: o GDExtension que substitui o `HTTPRequest`, e as cinco fases da IA local

Dossiê de **pauta antes do código** (mandato 4 de [`AGENTS.md`](../../AGENTS.md)): nenhuma linha de
`native/`, `src/` ou `tests/` desta perna foi escrita aqui. A autorização é o prompt do dono desta
conversa (2026-11-23), "MASTER PROMPT — Aetherfall: Elevação da IA Local para Outro Nível", e ele
**move uma linha do contrato**: `AGENTS.md`, "Escopo autorizado agora / Fora", tinha
`oráculo nativo em GDExtension` como fora — com o pedido dele isso passa a dentro, e o registro da
extensão está no fim desta página, antes de qualquer commit. O resto do pedido dele **não** é
autorização nova: é prioridade, e prioridade sem ordem registrada é o incidente do furo #21.

A regra de ouro dele, escrita aqui com as palavras dele e como cláusula verificável:

> **Nenhuma camada de linguagem move um pé, aplica dano ou escreve diretamente no ledger. A mente
> propõe. As regras determinísticas dispõem.**

Isso não é tese nova neste repositório — é o mandato 2, e a tabela de autoridade do
[`docs/design/04-local-ai-architecture.md:237-244`](../design/04-local-ai-architecture.md#L237-L244)
já escreve `NUNCA` para `Aplicar dano / mudar voxel` na coluna da Camada 5. O que o prompt acrescenta
é **como** se prova isso depois do GDExtension, e é aí que o §6.4 e o §7.1 entram: com o modelo
dentro do processo, "o oráculo não decide" deixa de ser verdade por construção de transporte (não
existe caminho do HTTP para a física) e passa a ter de ser verdade por **verifier**. A frase
`a única saída do MindOracle que chega a quem age é narrativa`
([`AGENTS.md`](../../AGENTS.md), mandato 2) é a que este lote tem de continuar verdadeira com o
`llama.dll` carregado dentro do `Godot_v4.7.2-stable.exe`.

**Premissa nomeada, uma só:** um `llama.dll` carregado dentro do processo do jogo produz, em
headless, a mesma linha `ia:` que o `llama-server` de `127.0.0.1` produz hoje — com **zero
`HTTPRequest`** e com o orçamento de tick não-piorado. Falsificável sem abrir janela: `grep -rn
HTTPRequest src` devolvendo vazio, `tests/live_oracle_probe.tscn` verde contra a extensão, e
`worst_sim_ms` do cenário de reação dentro do budget de 400 µs da árvore depois da mudança.

---

## 0. O que o dono pediu, nas sete linhas que valem

1. **Nativo de verdade:** GDExtension C++ com `llama.cpp` (Vulkan) dentro do processo, e **não**
   "um servidor local". A metades dele: `server de llama.cpp dentro do processo do jogo`.
2. **100% local, zero nuvem**, inclusive no caminho de decisão.
3. **Cinco fases**, nesta ordem: Oráculo Nativo → Memória de Qualidade → Adaptação Real → LOD e
   Orçamento → Ferramentas e Observabilidade.
4. **A ponte não é o destino:** `llama.cpp` embutido no GDExtension, não `HTTPRequest` para um
   `llama-server`. Isto é, o que existe hoje (`src/ai/mind_oracle.gd:62`, `:122`) é a ponte.
5. **Observabilidade primeiro:** o F3 e o MindsInspector têm de dizer o que a IA fez **antes** de
   qualquer melhoria nela. É o §5.5 desta página, e é o motivo pelo qual a Fase 5 não é o fim: a
   régua dela entra na Fase 1.
6. **Medição obrigatória:** cada melhoria com número, headless, serial, em clone limpo do commit.
7. **Escopo:** foco **só na IA**; "o Sistema Operacional (Obragem) não é prioridade agora"; e
   "nada de P2 / facções / co-op / progressão agora".

---

## 1. Fase 0 (esta página): as condições de existência, medidas

Nenhuma linha de Fase 1 se escreve antes disto, porque a Fase 1 inteira depende de três coisas que
o prompt assume existir. Eu as fui procurar. O instrumento é uma sonda C++ comum, fora do Godot,
sem engine, sem modelo — [`docs/evidence/oraculo-nativo-22/af_native_probe3.cpp`](../evidence/oraculo-nativo-22/af_native_probe3.cpp),
com as três leituras arquivadas na mesma pasta (stdout, stderr e o `.bat` reprodutível).

### 1.1 O compilador existe, e a leitura antiga estava errada por minha causa

| Condição | Leitura anterior (2026-11-23, mais cedo nesta mesma conversa) | Leitura desta passada |
|---|---|---|
| MSVC / `cl.exe` | "sem toolchain — nenhum VS instalado" | **existe**: VS 2022 Community, toolset `14.44.35207`, `cl` 19.44.35228, `vcvars64.bat` — a célula anterior dizia "`cl.exe` 19.44.35207", que é o nome da **pasta** do toolset, não a versão do compilador; o §12.1 separa as duas grandezas |
| Compilar C++17 | não tentado | **compila** (`af_probe.cpp` → `.exe`, ERRORLEVEL 0) |
| Por que a primeira leitura mentiu | — | o `.bat` fazia `call vcvars64.bat >nul` e **depois** media `%ERRORLEVEL%`; o redirect engolia a saída e a porta leu o código do redirect. Tirei o `>nul`, a compilação apareceu. |

Isso é a mesma parede do mandato 1 vista do outro lado: um instrumento que imprime o código da
própria casca. Registrado como **furo #32**, com a régua no §8.

### 1.2 As DLLs do runtime carregam dentro de um processo comum, e veem a GPU

Leitura literal de `af_native_probe3.exe` (arquivo acima; stdout limpo, stderr com as linhas do
backend). A sonda faz `LoadLibraryExA(..., LOAD_WITH_ALTERED_SEARCH_PATH)` nas quatro DLLs de
`.tools/llama/runtime/` e chama o registro do ggml:

```
LoadLibrary: ggml-base=OK ggml=OK ggml-vulkan=OK llama=OK
ponteiros (ggml): load_all=00007FFC5EBB2310 reg_count=00007FFC5EBB1690 reg_get=00007FFC5EBB1720 dev_count=00007FFC5EBB19B0 dev_get=00007FFC5EBB1A40
ponteiros (base): reg_name=00007FFC461E3270 dev_name=00007FFC461E3030 dev_desc=00007FFC461E3060 dev_type=00007FFC461E30E0
ggml_backend_load_all_from_path(runtime) devolve: 0 (ve o rodape do stderr; nao e contagem de backends)
ggml_backend_reg_count(): 3
  reg[0] RPC
  reg[1] Vulkan
  reg[2] CPU
ggml_backend_dev_count(): 2
  dev[0] type=1 nome=Vulkan0
           desc=AMD Radeon RX 9060 XT
  dev[1] type=0 nome=CPU
           desc=AMD Ryzen 7 5700X3D 8-Core Processor
ggml_backend_vk_get_device_count(): 1
SONDA=OK
```

e o stderr, do próprio backend, na mesma corrida:

```
load_backend: loaded RPC backend from C:\Aetherfall\.tools\llama\runtime\ggml-rpc.dll
ggml_vulkan: Found 1 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon RX 9060 XT (AMD proprietary driver) | uma: 0 | rebar: 0 | fp16: 1 | bf16: 1 | fp4: 0 | warp size: 64 | shared memory: 32768 | int dot: 1 | matrix cores: KHR_coopmat
load_backend: loaded Vulkan backend from C:\Aetherfall\.tools\llama\runtime\ggml-vulkan.dll
load_backend: loaded CPU backend from C:\Aetherfall\.tools\llama\runtime\ggml-cpu-haswell.dll
```

As três afirmações que a Fase 1 precisa e que isto sustenta: **o Vulkan inicializa dentro de um
processo que não é o servidor** (nada de `llama-server` no meio), **a RX 9060 XT é o dispositivo
que ele escolhe** (`type=1 nome=Vulkan0`), e **a fila de backends se resolve sozinha** quando o
diretório certo é passado. O `devolve: 0` da linha de load é o número que o §1.3 explica — não é
"zero backends", é "zero backends **registrados naquela chamada**", porque os três já estavam no
registro quando `ggml-vulkan.dll` foi carregada.

### 1.3 O contrato do ggml **não** é exportado pelo `ggml.dll` do runtime — e isto muda a Fase 1

Contagem por `dumpbin /exports` nas cinco DLLs do runtime (dumps arquivados nesta pasta:
[`exports-llama.txt`](../evidence/oraculo-nativo-22/exports-llama.txt),
[`exports-ggml-base.txt`](../evidence/oraculo-nativo-22/exports-ggml-base.txt),
[`exports-ggml.txt`](../evidence/oraculo-nativo-22/exports-ggml.txt),
[`exports-ggml-vulkan.txt`](../evidence/oraculo-nativo-22/exports-ggml-vulkan.txt),
[`exports-fit-params.txt`](../evidence/oraculo-nativo-22/exports-fit-params.txt); o `.bat` que os
produz é [`af_exports_build.bat`](../evidence/oraculo-nativo-22/af_exports_build.bat)):

| DLL | exports | o que tem |
|---|---|---|
| `llama.dll` | **266** (240 C puro, 26 C++-decorados) | `llama_backend_init`, `llama_model_load_from_file`, `llama_init_from_model`, `llama_model_size`, `llama_vocab_*`, `llama_sampler_chain_*`, `llama_chat_apply_template`, `llama_print_system_info` |
| `ggml-base.dll` | **689** | o ggml inteiro: a família `ggml_backend_buft_*` (11 nomes, entre eles `ggml_backend_buft_get_alloc_size`) e `ggml_backend_buffer_get_alloc_size` |
| `ggml.dll` | **16** | só a família de **registro/carregamento** do backend; **nenhum** `buft_*` |
| `ggml-vulkan.dll` | **9** | o registro/criação do backend vk |
| `llama-fit-params-impl.dll` | **53** | o ajuste de parâmetros (`?llama_fit_params@@YAHHPEAPEAD@Z`), e **não** o `llama.dll` |

As 16 saídas do `ggml.dll` pinado aqui são, com o prefixo `ggml_backend_` omitido por legibilidade:
`dev_by_name, dev_by_type, dev_count, dev_get, device_register, init_best, init_by_name,
init_by_type, load, load_all, load_all_from_path, reg_by_name, reg_count, reg_get, register, unload`.
Ou seja: **`reg_count`, `reg_get`, `dev_count` e `dev_get` existem** — a sonda os chamou por ali, e é
por isso que o §1.2 devolve 3. O que **não** existe ali é o que a Fase 1 de verdade precisaria para a
memória fina (`ggml_backend_buffer_type_get_base_buffer`, `ggml_backend_buft_*`) — e a leitura desta
passada diz **onde** isso existe: nos 689 nomes do `ggml-base.dll`, que tem a família `buft_*` (11
símbolos, lidos de
[`exports-ggml-base.txt`](../evidence/oraculo-nativo-22/exports-ggml-base.txt)) e o
`ggml_backend_buffer_get_alloc_size`. Duas ausências a mais, e ambas contadas na mesma passada, com
o `grep` dos cinco dumps: `ggml_backend_buffer_type_get_base_buffer` **não aparece em nenhuma das
cinco DLLs** (o nome que o prompt usa para o `model_oversave` não existe neste build), e
`llama_params_get_fit_params` **não está nos 266** do `llama.dll` — a família de ajuste automático de
parâmetros mora na DLL separada `llama-fit-params-impl.dll` (**53** saídas,
[`exports-fit-params.txt`](../evidence/oraculo-nativo-22/exports-fit-params.txt)). O `llama.dll` de
b12499 foi compilado com um `ggml.dll` cujo export-set é outro do que a árvore do `ggml-base.dll` ao
lado dele mostra. Consequência dura, e é a única premissa deste lote que o prompt **não** pode
assumir:

> **Um binding escrito contra o `ggml.h` de um llama.cpp diferente do b12499 pode não linkar contra
> as DLLs que já estão no repositório.** Antes da Fase 1, a Fase 1 tem um gate de *link*: uma
> extensão mínima que chama o que o `.dll` realmente exporta, e falha na compilação se eu estiver
> escolhendo símbolo pela documentação.

O que isto **não** muda: o orçamento de contexto. A janela de memória do contexto é alocada pelo
próprio `llama.dll` (`llama_init_from_model` + os `llama_params`), não por uma buft que eu preciso
pegar na mão. A contagem de tokens e o teto de células do cache vêm do modelo e dos parâmetros de
carga, e o §5.2 mede os dois em runtime. O que a descoberta corta é o **`model_oversave`** do
prompt (§8.7) e qualquer "ler a memória do ggml pelo registro" — isso vira `[OPEN]` com o motivo,
não `[TARGET]` bonito.

### 1.4 A interface do GDExtension 4.7.2 existe, e não é downloadável como arquivo

`gdextension_interface.h` **não** está no tarball de fonte em nenhum dos três caminhos que eu tentei
(`4.5-stable`, `4.6-stable`, `4.7-stable` — os três 404). O que o SCons do Godot faz é **gerá-lo**
de `gdextension_interface.json` + `core/extension/make_interface_header.py`. Provar que a Fase 1 tem
cabeça foi isso: baixei o JSON da tag 4.7.2 (328 021 B), rodei o gerador do próprio Godot com o
Python do sistema, e a saída é um cabeçalho de **143 170 bytes**
([`gdextension_interface_472.h`](../evidence/oraculo-nativo-22/gdextension_interface_472.h)). **A testemunha
que esta página dava antes não testemunha nada:** ela citava a typedef
[`GDExtensionInitializationFunction`](../evidence/oraculo-nativo-22/gdextension_interface_472.h#L716)
"mais as enums `GDEXTENSION_VARIANT_TYPE_*` do topo" como prova de que o cabeçalho é o de 4.7.2 — e os
dois existem **idênticos** no único cabeçalho que a máquina tinha local, o `gdextension_interface.h` do
godot-cpp 4.4.1 (a mesma typedef, na linha dele `:782`; `GDEXTENSION_VARIANT_TYPE_` em **48** linhas nos
dois arquivos). A leitura que discrimina geração é outra, e está no §12.2: `GDExtensionClassCreationInfo6`
([`:402`](../evidence/oraculo-nativo-22/gdextension_interface_472.h#L402)),
`GDExtensionClassCreateInstance3` ([`:220`](../evidence/oraculo-nativo-22/gdextension_interface_472.h#L220))
e `GDExtensionInterfaceClassdbRegisterExtensionClass6`
([`:2954`](../evidence/oraculo-nativo-22/gdextension_interface_472.h#L2954)) — os três com **0** ocorrências
no cabeçalho 4.4.1. O que o arquivo **não** tem é a linha que uma leitura anterior desta página citava
(`#define GDEXTENSION_API_VERSION 5` — não existe no cabeçalho gerado), e a frase que a substituía
também estava errada: a versão da interface **não** aparece no JSON nem como `api_version` — o JSON tem
exatamente cinco chaves de topo e `format_version: 1`, que é a versão do **esquema do arquivo**, não da
interface (§12.2). Caminho de produção da Fase 1, documentado no §5.1 e medido no §12.2: **gerar o
header, não baixá-lo** — com a ressalva de que o gerador não tem CLI nenhuma.

### 1.5 A API da engine, medida da própria engine

`godot --headless --path . --dump-extension-api` escreveu `extension_api.json` de **6 965 057 B** na
raiz do projeto (movido depois para `.tools/extension_api_4.7.2.json`, fora do git; é instrumento,
não artefato do jogo). Lido dele, o que o binding tem de respeitar:

- `ClassDB.class_get_method_list("HTTPRequest")` não é necessário — mas o fato relevante é o
  contrário: **não existe nenhuma classe de engine que já faça o que a Fase 1 faz**. A extensão é
  classe nova, registrada pelo `register_types.cpp`.
- Os tipos da fronteira são os que a Fase 1 usa: `Variant`, `Array`, `Dictionary`, `String`,
  `PackedByteArray`, `Callable`, `Signal`. Nenhum tipo de engine cruzando a fronteira que o
  `godot-cpp` precise gerar em excesso: a API do prompt tem três entradas e três saídas, todas
  JSON-able.

### 1.6 O que a Fase 0 **não** prova, e por isso a Fase 1 nasce com risco nomeado

Não há corrida da extensão em si. Nada aqui abriu um `GDExtension` em Godot, carregou um `.gguf`, ou
emitiu um token. A sonda é o **piso**: as condições de existência são verdade, e o contrato de
símbolos é mais estreito do que o prompt achava. O risco que sobra e que só o primeiro commit da
Fase 1 mede é o de **carregar um modelo dentro de um processo que já tem o Vulkan da renderização
aberto** — dois drivers Vulkan no mesmo processo é uma situação que este repositório nunca exercitou
e que a sonda não cobre (a sonda não abre janela, não cria swapchain). É o gate do §5.2.

---

## 2. Estado real do código do oráculo, lido linha a linha

Nada disso é hipótese — e **este §2 é registro da Fase 0, não retrato da ponta atual**: os
números de `mind_oracle.gd` e de `llm_server_host.gd` foram lidos na `main` do pouso da 16,
`bb13752` (264 linhas, o transporte em quatro lugares), e os de `main.gd` nos §§2.3–2.4 foram
re-derivados na ponta do Passo 4, `5138549`. O Passo 4 aposentou este estado — o transporte
saiu, `grep -rn HTTPRequest src` devolve **vazio**, e o hospedeiro de processo saiu com ele —;
o que existe hoje é o que os §§5.3–5.4, o §18 e o §19 pagaram com gate.

### 2.1 `src/ai/mind_oracle.gd` — 264 linhas, e o transporte está em quatro lugares

| Papel | Onde |
|---|---|
| o nó de transporte | `mind_oracle.gd:42` `var _http: HTTPRequest = null`, criado em `mind_oracle.gd:62`, timeout em `mind_oracle.gd:64`, conectado em `mind_oracle.gd:66` |
| a chamada | [`:122`](../../src/ai/mind_oracle.gd#L122) `_http.request(server_url + "/v1/chat/completions", auth_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload))` |
| a resposta | `bb13752:src/ai/mind_oracle.gd:151` `_on_response`, com o `_clean` de 140 caracteres em `bb13752:src/ai/mind_oracle.gd:199` |
| o que **não** é transporte | o agendamento (`_process` [`:71`](../../src/ai/mind_oracle.gd#L71)), o roster round-robin ([`:85-91`](../../src/ai/mind_oracle.gd#L85-L91)), o recuo (`RETRY_COOLDOWN` [`:13`](../../src/ai/mind_oracle.gd#L13), `LOADING_COOLDOWN` [`:28`](../../src/ai/mind_oracle.gd#L28)), a chave do servidor ([`:19-20`](../../src/ai/mind_oracle.gd#L19-L20), [`:219`](../../src/ai/mind_oracle.gd#L219)), o prompt ([`:131`](../../src/ai/mind_oracle.gd#L131)), a narrativa pública ([`:96`](../../src/ai/mind_oracle.gd#L96)) e o `narration_ready` ([`:9`](../../src/ai/mind_oracle.gd#L9)) |

É esta separação que o §6.2 explora: **a ponte é ~60 linhas; os outros ~200 são a mente do
oráculo**, e ela não muda quando a ponte muda. O pedido do dono ("a camada Python precisa virar um
GDExtension C++") é uma substituição de transporte com contrato preservado, não uma reescrita.

### 2.2 Os dois arquivos de `src/` com `HTTPRequest`, e quem os consome

`grep -rn HTTPRequest src` devolve **nove** linhas em **dois** arquivos. Em `src/main.gd` o
contador é **zero** — conferido nesta árvore, e é a correção de uma afirmação que esta página trazia
de uma leitura anterior, quando o hospedeiro de processo ainda guardava parte do health-check no
`main`.

1. `src/ai/mind_oracle.gd` — sete linhas, todas do oráculo (§2.1): [`:42`](../../src/ai/mind_oracle.gd#L42)
   (`var _http: HTTPRequest = null`), [`:49`](../../src/ai/mind_oracle.gd#L49) e
   `bb13752:src/ai/mind_oracle.gd:182`/`bb13752:src/ai/mind_oracle.gd:184` (comentários que
   nomeiam a enum `HTTPRequest.Result`, lida do registro da classe em
   [`:67`](../../src/ai/mind_oracle.gd#L67)), [`:62`](../../src/ai/mind_oracle.gd#L62) (cria o nó),
   [`:189`](../../src/ai/mind_oracle.gd#L189) (`RESULT_SUCCESS` no `_reason_of`).
2. `llm_server_host.gd:87` e `llm_server_host.gd:99` (aposentado no Passo 4 do dossiê 22, commit
   5138549) — o **hospedeiro** que levanta o `llama-server` no boot (perna 15). Ele é dono de
   `OS.create_process` (`llm_server_host.gd:311`), do health-check de porta (`llm_server_host.gd:216`
   `_probe()`, cujo GET usa o mesmo nó criado em `llm_server_host.gd:99` contra a URL lida do oráculo
   em `llm_server_host.gd:189`) e do encerramento do filho: **um** sítio de `OS.kill`
   (`llm_server_host.gd:414`, com `kills_issued += 1` em `llm_server_host.gd:413`) alcançado por
   **dois** caminhos de saída — `_exit_tree` (`llm_server_host.gd:395`) e `NOTIFICATION_PREDELETE`
   (`llm_server_host.gd:400`) — ambos dentro de `_stop_child()` (`llm_server_host.gd:406`) e ambos
   protegidos por `_owns_child`.

A mesma varredura estendida a `tests/` acha a **décima** linha, em
`llm_server_boot_probe.gd:266` (aposentado no Passo 4 do dossiê 22, commit 5138549) — a sonda da perna
15, que a Fase 1 também aposenta (§5.4).

Consequência que o prompt não prevê e que a Fase 1 tem de decidir **antes** do código: se o oráculo
não fala mais HTTP, **o hospedeiro da Fase 15 perde a razão de existir** — o que ele resolve hoje é
porta e processo, e a porta ele lê do próprio oráculo
(`llm_server_host.gd:189` `_url()` devolve `oracle.server_url`; `_port()` `llm_server_host.gd:196`
extrai o número dela, nunca um literal repetido), e a linha de status do F3 (`llm_server_host.gd:133`
`status_line()`) é montada sobre
essa mesma porta. O braço escolhido está no §6.3; o rejeitado está no §8.4.

### 2.3 O contrato de quem lê o oráculo (e por isso a fronteira não pode mudar de tipo)

A saída do oráculo tem exatamente **três consumidores** em `src/`, todos de leitura:

- [`src/main.gd:193`](../../src/main.gd#L193) — injeta o `narration_provider` no HUD chamando
  `oracle.narration_of(id)`;
- [`src/ui/hud.gd:276-277`](../../src/ui/hud.gd#L276-L277) — imprime `ia:` no F3;
- o `narration_ready` ([`src/ai/mind_oracle.gd:9`](../../src/ai/mind_oracle.gd#L9)) que o lobo não
  consome: **nenhum** `connect(` a este sinal existe em `src/` hoje. Ele é a superfície para o
  futuro MindsInspector, e a Fase 5 da tabela do §5.6 é o comprador que faltava.

E a única porta de **entrada** é o roster (`roster_provider`, [`:40`](../../src/ai/mind_oracle.gd#L40),
ligado em [`src/main.gd:191`](../../src/main.gd#L191) com `Callable(self, "wolves_roster")`) mais os
campos injetáveis de `server_url`/`request_timeout`/`api_key`/`ready_provider`
([`:32-40`](../../src/ai/mind_oracle.gd#L32-L40)); o `ready_provider` é ligado pelo hospedeiro em
[`src/main.gd:257`](../../src/main.gd#L257). Nada de `Wolf`, `VoxelWorld` ou `Player` chama o oráculo.
A regra do dono — "a mente propõe, as regras dispõem" — hoje é verdadeira **por topologia**: não existe
caminho do oráculo para a intenção. A Fase 1 tem de manter a topologia, e o §7.1 registra que topologia
não é prova.

### 2.4 O que o F3 já diz sobre a IA, e o que ele não diz

`diagnostics()` de [`src/main.gd:1214`](../../src/main.gd#L1214) expõe `"llm": llm_host.diagnostics()`,
que por sua vez (`llm_server_host.gd:159` — aposentado no Passo 4 do dossiê 22, commit 5138549)
devolve
`state`, `pid`, `boot_ms`, `loading_503`, `retries`, `requests`, `kills`, `spawned`, `detail` e `url` —
dez chaves, todas de **ciclo de vida de processo**, nenhuma de **trabalho do modelo**. A outra metade
do retrato é prosa: a linha do F3 é `status_line()`
(`llm_server_host.gd:133`), e o único número do oráculo que chega a ela é `oracle.last_reason` (lido
em `llm_server_host.gd:152-153`); o `server_url` que define a porta também é lido do oráculo
(`llm_server_host.gd:189`).

**Não há** tokens/s, µs de decodificação, profundidade de fila, taxa de cache nem memória do contexto —
e os contadores do próprio oráculo (`requests_issued` `mind_oracle.gd:56`, `last_status`
`mind_oracle.gd:57`, `last_reason` `mind_oracle.gd:58`) não aparecem em `diagnostics()` nem no HUD:
`grep -n "requests_issued\|last_status\|last_reason" src/main.gd src/ui/hud.gd` devolve **vazio**. O
prompt pede isso e o mandato 5 do contrato exige — hoje a observabilidade do oráculo é uma string de
erro. O §5.5 fecha isso antes de fechar qualquer mecânica nova.

---

## 3. O que **não** é este lote, escrito para o prompt não virar escopo

O dono nomeou cinco fases e um "Sistema Operacional". As fronteiras:

| Coisa | Decisão | Motivo |
|---|---|---|
| P2 (facções, `SlowSim`) | **fora** | palavra dele: "nada de P2 / facções / co-op / progressão agora" |
| Co-op, progressão, chefes | **fora** | idem, e o contrato já os lista como fora |
| "Sistema Operacional (Obragem)" | **fora, e ele mesmo adiou** | "O Sistema Operacional (Obragem) não é prioridade agora" |
| `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` | **intocados** | nenhuma das cinco fases toca projeção de journal nem versão de mundo; mudar isso é decisão de save, não de IA |
| áudio novo (vocalização de ave, uivo) | **fora deste dossiê** | pauta da 20, e o veto GPL do Veloren continua de pé (mandato 8) |
| o launcher `Rodar.bat` | **em risco, não fora** | ver §6.3: ele é a Fase 15; se o transporte muda, ele muda com ele |
| Fase 2–5 em código | **fora desta branch** | este dossiê entrega Fase 0 + a pauta das cinco, não cinco implementações |

---

## 4. Fila serializada: onde a 22 entra, e com qual elo

Fila viva na escrita desta página: **17 → 18 → 20 → 13** (a 12 pousou em `fa94cb5`;
09→10→15→14→11→19→16→12 cumpridas). A 22 é **transversal**: ela escreve `src/ai/`, `native/`,
`tests/`, e **não** escreve `src/entities/wolf.gd` nem `src/main.gd` além de três linhas de injeção de
provider. A regra é um escritor por arquivo por branch ([`AGENTS.md`](../../AGENTS.md), "Branches"
item 6), e a regra da ordem é que a exceção se registra **antes**.

Posição escolhida na pauta, e depois **movida pelo dono**: 22 no frente da fila.

- **Como estava escrita** — depois da 18: a 18 gasta `src/main.gd` inteiro em mecânica de mundo e é o
  elo mais curto da fila; abrir a 22 antes obrigaria a 18 a re-rodar o gate com um `HTTPRequest` a
  menos na árvore — o mesmo motivo pelo qual a fila pôs a 17 depois da 12.
- **Como está desde 2026-11-23** — a frente da fila: eu expliquei ao dono que o esqueleto de `C++`
  não vinha porque a perna não abria antes da 18, e ele respondeu "pode continuar". Isso é a palavra
  dele liberando a espera, e o §10 registra a data dela antes da primeira linha de código. A razão
  antiga **não** é negada, é **aceita com preço**: 17 e 18 passam a rebaser numa árvore onde o
  transporte do oráculo mudou, e pelo item 5 de "Branches" cada uma re-rome o gate próprio.
- **Antes da 20** porque a 20 (§3.5 dela, "BT por arquétipo") e a 22 (§7.1 daqui) escrevem a mesma
  frase de contrato sobre o oráculo, e a 22 é a que tem a palavra autoritativa: se a 20 nascer
  depois, ela nasce sabendo que o modelo é nativo e pode tratar `oracle_health` como entrada.
- **Antes da 13** porque a árvore genealógica depende de `Mind`, e `Mind` depende da crença
  verificada da Fase 2; a 13 continua última pelo motivo já registrado (nenhuma mudança de
  `Channel.COUNT` no meio da fila).

Fila resultante: **22 → 17 → 18 → 20 → 13**, com a 22 na frente e as cinco fases dela morando dentro
de uma branch só — o que a Fase 1 fecha, a Fase 2 abre depois, e assim por diante. Cada fase é um
fecho separado com gate próprio; a branch não leva cinco fases.

---

## 5. A Fase 1, em commits atômicos com gate por passo

Cada passo abaixo é **um** commit, com a medição escrita no commit a que ele responde. Nenhum passo
depende de janela aberta; todos têm comando headless.

### 5.1 Passo 1 — o esqueleto linka, e o gate é "existe um `.dll` de extensão que o Godot abre"

`native/af_mind/` nasce com: `build.bat` que (a) **confere por SHA-256** o cabeçalho
`include/gdextension_interface.h` **vendorado** no diretório da extensão — gerar
`gdextension_interface.gen.h` do JSON pinado não é possível nesta árvore, porque nem o
`gdextension_interface.json` nem o `make_interface_header.py` estão aqui (§12.2), e o comando que os
produz fica escrito lá com o hash do fruto — e (b) compila `src/*.cpp` contra o **MSVC** medido no
§1.1. O Passo 1 (c) **não** encosta no llama.cpp: em `.tools/llama/runtime/` não existe nenhuma
`.lib` de import (§12.3), então nada é linkado contra o runtime, e o gate de símbolos do §1.3 passa a
ser gate do **Passo 2**, com import libs gerados do export-set medido e `/DELAYLOAD`. A extensão
registra **uma** classe, `AfMindOracle`, sem função de IA ainda.

Gate: `godot --headless --path . --import` e depois a checagem `extensao_carrega_classe`, que abre a
extensão pela API pública (`GDExtensionManager.load_extension()`), exige `ClassDB.class_exists()` e
instancia; o stdout tem de conter a linha de registro da engine e nenhuma `SCRIPT ERROR`. Ela **nasce
vermelha** (a extensão não existe ainda). O que ela prova é a premissa de que o Passo 1 é dono: que o
`.dll` carrega, registra a classe e devolve um objeto vivo. Que o `.dll` resolve as DLLs do runtime no
diretório de processo é premissa do Passo 2, e é lá que ela passa a ser checada. **Foi: o Passo 2 (a) a
mede e o veredito é FALSA nesta máquina** — §15.5. O gate de símbolos do parágrafo anterior, executado no
§15.

### 5.2 Passo 2 — carregar o modelo dentro do processo, com o Vulkan da renderização já vivo

Aqui mora o risco que a Fase 0 não cobre (§1.6). O modelo de teste é o `mind-small` já pinado
([`docs/design/04:218`](../design/04-local-ai-architecture.md#L218)); o gate mede três números antes
de qualquer frase:

- `af_vram_gb` — VRAM depois do load, com o `load_pack()` vazio como base;
- `af_load_ms` — tempo do load;
- `af_ctx_cells` — o custo real do cache de contexto do `ctx_size`, **lido do modelo**, não do
  `--ctx-size` (o §5 do doc 04 pede o valor fino, e o `model_oversave` do prompt é o §1.3 que não
  linka — logo, a métrica vem do ggml do `llama.dll`, e se ele não devolver, o número é `[OPEN]`
  com o motivo, não 999).

Critério escrito **antes** da corrida: o jogo abre com a cena de prova, o processo não morre, os três
números saem, e o passo 1 continua verde. Vermelho aqui é achado, não falha de plano — e é o que a
Fase 1 tem de descobrir cedo.

**Estado deste passo (medido 2026-11-24):** ele tem duas metades, e as duas fecharam. **Passo 2 (a)** —
o gate de símbolos do §1.3 executado, os import libs gerados do export-set medido, `/DELAYLOAD` e a
premissa do diretório de processo checada FALSA — está no §15. **Passo 2 (b)** — os três números —
fechou no §16, pela rota que a premissa FALSA obrigou: `set_runtime_dir` por **caminho absoluto** antes
de qualquer delay helper (5 módulos), o `load_pack()` vazio abrindo a **base medida** (900 079 760 B,
com `vram_used == vram_base` — um getter nascendo -1 faria o `af_vram_gb` um número inventado por
subtração), o `.gguf` entrando no processo (RSS do SO 176 MB → 3,56 GB) e `af_ctx_cells` **lido do
modelo** — `ctx_probe(2048)` e o runtime devolve `ctx_readback == 2048`
(`ESCRITA_CONFIRMADA_PELO_RUNTIME`), com `ctx_train = 262 144` igual à meta `qwen35.context_length` que
o próprio `.gguf` carrega. O gate do runner é `_test_extensao_pack_no_processo` — oito checagens,
censo 288 → **296**, nascendo vermelho num clone sem o runtime e sem o modelo (ambos gitignored).

### 5.3 Passo 3 — a API do prompt, com o contrato de tipos do §2.3

```gdscript
af.load_pack(name: String, path: String) -> int      # id de pack
af.enqueue(req: Dictionary) -> int                    # request_id
af.wait(request_id: int, timeout_ms: int) -> Dictionary
# sinais: inference_completed(request_id, output), pack_loaded(name), pack_failed(name, reason)
# métricas: queue_depth(), cache_hits(), cache_misses(), vram_bytes(), worst_decode_us()
```

`req` = `role`, `prompt`, `max_tokens`, `temperature`, `schema`, `priority`, `context_ids`. A saída
de `wait` é o que o `mind_oracle.gd` já produz hoje por HTTP: um `Dictionary` com o texto, mais o
motivo de recusa. Gate: `contrato_igal_ao_http` — o mesmo `roster` de um cenário fixo, uma vez com o
transporte de rede e uma com a extensão, comparando **a forma**, não a frase (frase é do modelo).
`EXPECTED_CHECKS` sobe com as checagens novas, como sempre.

### 5.4 Passo 4 — `mind_oracle.gd` vira wrapper, e o HTTP sai de `src/`

O arquivo mantém `_process`, round-robin, recuo, `_clean`, `narration_of` e o `narration_ready`;
troca `HTTPRequest` por `AfMindOracle`. O `llm_server_host.gd` sai de cena pelo braço do §6.3. O
gate é **exatamente a frase do dono**: `grep -rn HTTPRequest src` devolve **vazio**, e o `Rodar.bat`
não levanta processo nenhum de IA. Checagem `transporte_http_zerado` no runner, com o stdout do
`grep` arquivado.

### 5.5 Passo 5 — cache, validador e a régua do budget, na ordem do mandato 5

`oracle_cache` (hash → resposta, §6.5), `BeliefVerifier` mínimo (§7.1) e as métricas do §2.4 no F3.
Gate: `af_cache_determina_replay` (a mesma semente duas vezes, com o modelo desligado na segunda,
devolve a mesma frase) e `budget_do_oraculo_nao_estoura_a_arvore` — `worst_sim_ms` do cenário de
reação dentro do `SubtreeGuard` de **400 µs** ([`src/entities/wolf.gd:448-449`](../../src/entities/wolf.gd#L448-L449)),
porque a regra de bolso do contrato é que o que vai em `_sim_tick` divide os 50 ms do passo com a
matilha do momento ([`docs/engine/simclock.md:21`](../engine/simclock.md#L21)) — cinco lobos no boot,
teto de censo 12, e o laço percorre `wolves` e não um literal
([`docs/engine/simclock.md:161-165`](../engine/simclock.md#L161-L165)). O corte por prioridade é
**depois** da métrica, nunca antes: "o número primeiro, o orçamento depois" é a disciplina que o
mandato 3 e o item 4 do ciclo dele pedem.

### 5.6 Fases 2–5 — o que cada uma entrega, sem escrever código delas aqui

| Fase | Entrega | Gate nomeado |
|---|---|---|
| **2 — Memória de qualidade** | relevância por recência, frequência, peso emocional e centralidade no grafo; `BeliefVerifier` grounded por ids do ledger; embeddings locais; consolidação no sono | `crenca_falsa_nao_vira_fato` (mandato 2 com verifier, não com topologia) |
| **3 — Adaptação real** | bandit contextual (UCB1) por arquétipo, com a **curva** de resposta e não o braço escolhido; `StyleFingerprint`; `CounterProfile` com custo em recurso de facção | `bandit_une_numero_observavel` — a taxa de vitória da espécie tem de mudar com o bandit ligado, no par anti-farsa da casa ([`AGENTS.md`](../../AGENTS.md), "Reproduza antes de corrigir": um braço produz a assinatura, o outro mostra que o conserto é indiferente a ela) |
| **4 — LOD e orçamento** | HOT/WARM/AMBIENT/SlowSim com números medidos de verdade, governor com teto e degradação **visível** no F3 | `orcamento_medido_antes_do_governor` — a Fase 5 do prompt entra antes da 4 por isto |
| **5 — Ferramentas e observabilidade** | MindsInspector legível (árvore, blackboard por folha, crenças com confiança), cronica auditável, saúde do oráculo exposta | `inspector_ve_a_mesma_leitura_do_journal` — o F3 não pode ser a única testemunha |

A ordem **2 → 3 → 4 → 5** do prompt é mantida nos nomes e invertida em um detalhe de procedimento, e
isso é dito para ele poder rejeitar: a **métrica** da Fase 5 entra na Fase 1 (§5.5), porque "observabilidade
primeiro" é item 5 dele próprio e porque sem `queue_depth` e `worst_decode_us` o governor da Fase 4
seria o ajuste cego que o furo #18 descreve — recusa contada sem leitor, pago pela 16 com
`esgotamento_de_lares_forcado`.

---

## 6. As cinco decisões de arquitetura, com o braço escolhido

### 6.1 Fonte da interface GDExtension

**Escolhido: gerar `gdextension_interface.gen.h` do `gdextension_interface.json` pinado**, exatamente
como o SCons do Godot faz (§1.4), e tratar o header como artefato de build gitignored. O tarball
não traz o header; baixar o header gerado por outra pessoa é assumir um `api_version` que a engine
recusa com `[SLOG]` silencioso. Rejeitado: `godot-cpp` (o binding oficial) como primeiro passo — ele
traz CMake e um second toolchain para dentro de uma máquina onde o que já existe é MSVC + SCons
(usado hoje por `godot-cpp`-nenhum); a Fase 1 é uma classe, não um SDK.

**Medido depois, e isto muda a execução sem mudar a decisão:** a frase acima citava SCons como se ele
existisse nesta máquina — não existe (§12.1, aberto com `where scons` e `python -c "import SCons"`
ambos vazios), e o `gdextension_interface.json` com o gerador também não estão nesta árvore (§12.2).
Então a geração vira **procedimento documentado + cabeçalho vendorado conferido por SHA-256 no build**,
e o §12.2 traz o procedimento re-executado: as duas entradas conferidas, o shim de onze linhas que faz
as vezes do SCons, e o fruto **byte a byte** igual ao cabeçalho arquivado. A razão de manter o cabeçalho
no git é a mesma de manter os 51 `.ogg` no git: ele é MIT da própria Godot Foundation, e um clone limpo
sem ele não compila nada — o que continua **fora** do git são os artefatos de terceiros baixados
(as DLLs de `.tools/llama/runtime/` e os `.gguf`). **E aqui vai uma correção, porque a frase acima
prometia o que ainda não existe:** ela escrevia "registrado em [THIRD_PARTY_LICENSES.md](../../THIRD_PARTY_LICENSES.md)"
no presente. Não está — o arquivo hoje tem 60 linhas, com llama.cpp e Godot Engine, e nenhuma linha sobre
o cabeçalho de interface; a linha entra com o commit que vendoriza o cabeçalho (Passo 1 (c)), e ela é
**obrigatória** por um motivo que a Fase 0 não sabia: o bloco de licença existe no JSON (27 linhas, com
"MIT", "Permission is hereby granted", "AUTHORS"), mas o gerador só **valida** a chave `_copyright` e não
a escreve — no header gerado as quatro ocorrências são **0** (§12.2). Vender o cabeçalho é, literalmente,
remover a licença do arquivo; a atribuição passa a ser nossa.

### 6.2 Fronteira de tipos: dicionário, não objeto de engine

**Escolhido: `Dictionary`/`Array`/`String`/`PackedByteArray` na fronteira**, com o resto em GDScript.
É o que `mind_oracle.gd` já movimenta hoje (§2.1), e é o que impede a Fase 1 de virar refatoração de
tudo que toca mente. Rejeitado: expor `AfMind` como `Resource` com métodos tipados — nada compra com
isso antes do MindsInspector existir, e o MindsInspector é Fase 5.

### 6.3 O destino do `LlmServerHost` (a Fase 15)

**Escolhido: o hospedeiro encolhe para `AfMindRuntime`, que só cuida do ciclo de vida do pack e das
métricas, e a porta some do `status_line()`.** O processo filho, o `create_process`, o health-check e
os dois `kill` saem com o transporte. Rejeitado (§8.4): manter o `llama-server` como caminho e a
extensão como "otimização" — isso é o dual-path que o mandato 1 chama de duas fontes e o dono chama
de "a ponte não é o destino".

Consequência registrada **antes**: o `Rodar.bat` da Fase 15 deixa de fazer sentido para o oráculo
nativo; o launcher passa a **não** ter processo de IA. Isso é um fechamento de gate alheio (o da
perna 15), e por isso ele é linha de fecho desta perna, não detalhe.

### 6.4 Verifier, não topologia

**Escolhido: um `BeliefVerifier` nomeado e testado na fronteira da Camada 5**, mesmo com a Fase 2
sendo a fase da memória. Hoje `a mente propõe, as regras dispõem`
([`AGENTS.md`](../../AGENTS.md), mandato 2) é sustentado por **ausência de caminho** — não existe
conector entre `MindOracle` e `intent`. Com o modelo dentro do processo, ausência de caminho deixa
de ser prova: o argumento "ele não tem para onde escrever" é mais fraco quando ele é um objeto no
mesmo heap. Então o contrato ganha, nesta perna, uma checagem em vez de um comentário. É o §7.1.

### 6.5 Cache do oráculo: chave de conteúdo, e a cache não é memória

**Escolhido: `hash(prompt ⊕ pack ⊕ params)` → resposta, em arquivo separado do save**, lido antes de
inferir. É o que torna a Fase 1 determinística em CI sem ligar o modelo a cada checagem, e é o que
permite medir a Fase 4 sem GPU. Rejeitado: cache em `user://` como memória persistente do mundo —
confundir cache com episódico é criar um segundo ledger, e o dono proibiu escrever no ledger.

---

## 7. Os três riscos que este lote abre e não pode deixar silenciosos

### 7.1 "A mente propõe" pode virar teatro quando o modelo está dentro do processo

É o que §6.4 paga. A checagem `verifier_recusa_id_forjado` entra com o `BeliefVerifier`: um prompt
de teste cujo output nomeia um `entity_id` que não existe no ledger **não** pode produzir crença nem
intenção. Hoje essa checagem não existe porque não há entrada do oráculo na decisão; ela nasce
vermelha na Fase 2 e é o gate de entrada da Fase 3.

### 7.2 Dois Vulkan no mesmo processo

`ggml-vulkan.dll` cria device no processo que carrega o `.dll` do Godot, que já tem o device da
renderização. Números do §1.2 provam que a sonda acha a 9060 XT; não provam que os dois coexistem.
O gate é o §5.2, e o fallback honesto é carregar o pack **no CPU** (`ggml-cpu-haswell.dll`, também
no runtime) com o F3 dizendo `af_backend=cpu (vulkan recusou)`. O fallback **não** é silenciar a
degradação: é a régua do §5.5 imprimindo o motivo, na mesma disciplina do §5.2 — número ausente com
motivo, nunca um 0 que parece leitura.

### 7.3 Determinismo vs modelo

O journal hashiza `intent`, crenças e o que mais entrar na projeção
([`src/persistence/tick_journal.gd:16-44`](../../src/persistence/tick_journal.gd#L16-L44); a linha que
põe `mind.kind`, `intent` e as crenças ordenadas é [`:35`](../../src/persistence/tick_journal.gd#L35)).
Um modelo amostrado não é determinístico. A resposta é a §6.5: **CI lê cache**, e a checagem que
garante que rodar sem modelo não move hash **já existe e está verde** —
`journal_hash_inalterado_sem_escolha`
([`tests/aether_reactions_test.gd:3780`](../../tests/aether_reactions_test.gd#L3780), registrada no
runner em [`:36`](../../tests/aether_reactions_test.gd#L36)): ela prova os dois lados, o de que o
que **não** está na projeção não move o hash e o de que uma confiança mexida na mesma chave move.
O que a Fase 1 acrescenta a esse contrato é o terceiro lado: **com cache, o texto tem de ser o mesmo**
(`af_cache_determina_replay`, §5.5). Sem isso, cada corrida publicada deixa de ser reproduzível e o
contrato de referência da fila inteira apodrece.

---

## 8. O que o prompt pede e a árvore devolve diferente

Registrado antes do código porque é isto que o §0 de uma próxima re-derivação vai conferir.

1. **"A camada Python precisa virar um GDExtension C++."** Não há camada Python no oráculo. O
   transporte de hoje é `HTTPRequest` em **GDScript** (`src/ai/mind_oracle.gd:122`) apontando para um
   `llama-server` de **C++** já no disco (`.tools/llama/runtime/`, 53 arquivos, `llama.dll` 3,9 MB).
   A intenção está certa; o nome da peça está errado, e o que a Fase 1 substitui é GDScript, não
   Python. Se houvesse Python, seria o `convert_hf_to_gguf.py` do llama.cpp — que roda **uma vez**, na
   produção do `.gguf`, e não no jogo.
2. **"Onde hoje existe um HTTPRequest para o servidor de llama.cpp."** Verdade, mas em **dois**
   arquivos de `src/`, não um (§2.2), e o segundo deles é a Fase 15 inteira — com
   `OS.create_process` (`llm_server_host.gd:311` — aposentado no Passo 4 do dossiê 22, commit
   5138549), o `OS.kill` do filho (`llm_server_host.gd:414`) e o launcher. O custo da troca
   é o dobro do que o prompt calculou.
3. **"Bandit contextual por arquétipo (UCB1) aprendendo qual tática funciona."** Aqui o prompt erra
   o nome da peça **e** o sentido da falta. Não há bandit nenhum — `grep -rn "bandit\|ucb\|UCB" src/`
   devolve vazio — e também não há **contagem por estratégia**: não existe `_strategy_counts` nem
   campo equivalente em `src/entities/wolf.gd`, que declara `intent`
   ([`:174`](../../src/entities/wolf.gd#L174)), `_scorer` ([`:216`](../../src/entities/wolf.gd#L216))
   e `_guard` ([`:218`](../../src/entities/wolf.gd#L218)), e escolhe a intenção por utilidade em
   [`:862`](../../src/entities/wolf.gd#L862) `intent = _scorer.choose(...)`, com a histerese de
   `min_lead` 0,06 (`src/ai/utility_scorer.gd:41`) e o intervalo mínimo de 0,45 s (`:42`). O que já
   **registra consequência** é a mente: `Mind.remember` ([`src/ai/mind.gd:39`](../../src/ai/mind.gd#L39))
   grava o átomo e chama `_drift` ([`:50-58`](../../src/ai/mind.gd#L50-L58)), que **muda a
   personalidade a partir do histórico** — `caution` sobe com `hurt`, `aggression` sobe com `win` e
   cai com `hurt`, `curiosity` cai com `fed` — e `_consolidate`
   ([`:61-68`](../../src/ai/mind.gd#L61-L68)) converte o que transbordou do `EPISODIC_CAP` de 24
   ([`:7`](../../src/ai/mind.gd#L7)) em crença com `confidence` e `source`. Então a Fase 3 **não**
   começa do zero: o estado de "quem esta criatura virou" existe e é lido
   (`temperament()` [`:35`](../../src/ai/mind.gd#L35)), com decaimento por minuto
   (`decay` [`:108`](../../src/ai/mind.gd#L108)) e soleira de uso (`believes`
   [`:104`](../../src/ai/mind.gd#L104)). Falta exatamente uma coisa para virar UCB1: **a curva de
   resultado por opção**. Hoje o `scored()` do scorer
   ([`src/ai/utility_scorer.gd:54`](../../src/ai/utility_scorer.gd#L54)) pondera o presente e o
   temperamento, e nada nele guarda `(vitórias, tentativas, variância)` por tática — o termo de
   exploração `sqrt(2 ln N / n_i)` precisa de `N` e `n_i` por **par arquétipo × tática**, e o
   `breakdown()` ([`:109`](../../src/ai/utility_scorer.gd#L109)) é a superfície onde ele mora. Isto é
   Fase 3, é pequeno, e é **por cima do estado que já existe** — não uma estrutura nova.
4. **"Manter a opção de servidor externo como fallback."** — não vem escrito assim no prompt, mas é
   o que a leitura "substituir gradualmente" sugere, e eu recuso: dual-path é a primeira forma de
   um número publicado parar de significar o que ele mede (§6.3).
5. **"Memória com `model_oversave` / leitura fina da memória do ggml."** §1.3: o export-set do
   `ggml.dll` pinado não tem esses símbolos; a métrica vira `[OPEN]` com motivo, e a Fase 1 mede VRAM
   por outra via.
6. **"Oráculo embutido no boot (Fase 15)" como pronto.** Está pronto **como servidor** — e é a ponte.
   O gate dele continua verde enquanto o transporte for HTTP e quebra no commit do §5.4. Isto não é
   razão para não fazer; é razão para registrar que a perna 15 tem um gate que **esta** perna fecha
   por fora.
7. **"Zero nuvem."** Verdade hoje no caminho de decisão e continua; o único tráfego de saída em
   `src/` não é do oráculo (§2.2, item 3). A frase do prompt é mantida como restrição verificável,
   não como conquista: `af_sem_rede_no_tick`.

---

## 9. O que cada fase **não** fecha, e onde ela morre

- **Fase 1** não fecha gate de nenhuma fase do roadmap, não muda `Channel.COUNT`, `FORMAT_VERSION`
  nem `GEN_VERSION`, e não adiciona nenhum tipo de criatura, bloco ou mecânica. O que ela fecha é a
  premissa do transporte.
- **Fase 2** não toca projeção do journal além das crenças novas, e não introduz embedding
  sem a métrica de recall antes.
- **Fase 3** não abre a Fase 4 (LOD) e não introduz P2; `CounterProfile` com custo de facção
  **esbarra** na proibição do dono e fica `[OPEN]` até ele tirar.
- **Fase 4** não roda sem a Fase 5 ter número; se o governor vier antes da métrica, ele é o furo
  #18 com outro nome.
- **Fase 5** não substitui o F3 nem o journal; ela os lê.

---

## 10. Branch e sequência de publicação

`feat/oraculo-nativo-gdextension-22`, base `main` no ponto atual, merge `--no-ff`. Dono: o agente
**`oraculo-nativo-22`**. Ordem interna: §5.1 → §5.2 → §5.3 → §5.4 → §5.5, uma branch de docs **antes**
dos commits de código — esta página. A Fase 0 está nela; os passos 1–5 de código entram na branch
feat, cada um com o número do commit dele.

Duas datas, porque a segunda não é a primeira: a pauta é de **2026-11-23** e nenhuma linha de código
foi escrita por ela; a espera de fila caiu no mesmo dia, pela palavra do dono, e a exceção de ordem
que a move para a frente foi registrada em **2026-11-24** na branch `docs/excecao-de-ordem-fila-22`,
aberta antes do primeiro commit de `native/` — que é o que o mandato 4 cobra, a ordem escrita antes
do código, não depois do número. O que muda com ela está no §4: a fila passa a
**22 → 17 → 18 → 20 → 13** e o preço assumido é 17 e 18 rebaserem com o transporte do oráculo já
trocado.


## 11. As três réguas desta página, com o comando que as mede

```sh
python tools/check_doc_anchors.py
python tools/check_doc_anchors.py --ref HEAD
python .tools/verify_plan_cites.py AGENTS.md README.md docs/melhorias-status.md   docs/planos/README.md docs/planos/22-oraculo-nativo-gdextension.md
python .tools/verify_plan_ids.py AGENTS.md docs/planos/README.md   docs/planos/22-oraculo-nativo-gdextension.md
```

As duas primeiras aceitam argv opcional e sem argv varrem o corpus inteiro (38 arquivos em `main`,
**39** aqui); a terceira e a quarta não têm default — rodá-las sem arquivos explícitos devolve um
stdout que não decide nada, e é por isso que o comando vem escrito aqui, não na memória de quem
leu o log.

As três corridas que o gate da Fase 1 lê, com a flag que as faz existir:

```sh
godot --headless --path . tests/smoke_test.tscn
godot --headless --path . --script tests/aether_reactions_test.gd
godot --headless --path . --script tests/tick_journal_test.gd
```

O `.gd` sem `--script` não roda o teste: o motor entende o posicional como cena e sobe o projeto em
headless, imprimindo gameplay para sempre sem rodapé e sem `quit()` — é o furo **#33** do status,
aberto numa corrida de 11 minutos e 204 s de CPU que não mediu nada. A cena de smoke aceita o
posicional porque é `.tscn`.

---

## 12. O que o Passo 1 (a) mediu, e o que isso corrigiu nesta página

Quatro leituras, catorze arquivos de evidência, nenhuma linha de `native/` escrita — seis stdout das
leituras, três `.sh` e dois `.bat` que os re-executam, mais as três réguas do fim da passada. Cada § abaixo
diz o que estava escrito nesta página antes, o que a máquina devolveu, e o que passa a valer. Os stdout
literais estão em [`passo1_build_instrumentado.log`](../evidence/oraculo-nativo-22/passo1_build_instrumentado.log),
[`passo1_vcvars_onde_resolve.log`](../evidence/oraculo-nativo-22/passo1_vcvars_onde_resolve.log),
[`passo1_fora_da_casca.log`](../evidence/oraculo-nativo-22/passo1_fora_da_casca.log),
[`passo1_header_fonte_abi.log`](../evidence/oraculo-nativo-22/passo1_header_fonte_abi.log),
[`passo1_gerador_entradas.log`](../evidence/oraculo-nativo-22/passo1_gerador_entradas.log) e
[`passo1_header_reproducao.log`](../evidence/oraculo-nativo-22/passo1_header_reproducao.log); os `.sh` e
`.bat` do mesmo diretório re-executam cada um. As três réguas do §11, rodadas no fim da passada com a
página já reescrita, estão em `passo1a_ruler_doc_anchors.log`, `passo1a_ruler_plan_cites.log` e
`passo1a_ruler_plan_ids.log` — **3 052 ponteiros / 209 rótulos / 3 178 links com 0 casos objetivos**,
**1 013 citações com número conferidas, 0 fora do arquivo** e as ausências do `verify_plan_ids` eram, na
árvore daquela passada, todas peças que esta página declara inexistentes. **A frase envelheceu com o
Passo 1 (c)** e está re-lida no §14.7: a régua varre só os `.gd` de `src/` e `tests/`, e `native/` é a
quarta raiz de código do repositório desde aquele passo. O manifesto da pasta,
[`artifacts.sha256`](../evidence/oraculo-nativo-22/artifacts.sha256), foi refeito com `sha256sum -b`
naquela passada — **45 entradas, `sha256sum -c` 45/45 OK** — pelo motivo do §12.4, e refeito de novo no
Passo 1 (c) com os 38 logs novos da subseção: **92 entradas, `sha256sum -c` 92/92 OK**. O Passo 2 (a)
acrescenta **17** arquivos próprios à mesma pasta (os logs do gate, do controle negativo, da A/B do
ordinal e da sua re-execução, das quatro corridas da suíte e as três réguas) e o manifesto passa a
**109 entradas**, com a conta re-rodada na árvore do commit — **109/109 OK** e `tr -cd '\r' | wc -c` **0**
nos CR do arquivo, a forma que o furo #36 exige. A régua não mudou; mudou o lote.

### 12.1 Não existe "o MSVC da máquina": existem três, e o `link` do PATH não é um linker

O §1.1 respondeu "o compilador existe?" e ficou nisso. A pergunta que o `build.bat` da Fase 1 faz é
outra — *qual* compilador, e com qual PATH — e as duas metades da resposta são novas.

**As três instalações** (`vswhere -all -products *`): `2022\Community` 17.14.37502.11,
`2019\BuildTools` 16.11.37507.1 e `2022\BuildTools` 17.14.37502.11. Os toolsets: **14.44.35207** nos
dois 2022, **14.29.30133** no 2019. Os banners do `cl`: **19.44.35228**, **19.44.35228**,
**19.29.30159**. As três consultas `-latest` do vswhere **divergem** entre si: `-latest` devolve
`2022\Community`, `-latest -products *` devolve `2022\BuildTools`, `-latest -requires
Microsoft.VisualStudio.Component.VC.Tools.x86.x64` devolve `2022\Community`. É o **furo #34**: um
`build.bat` que resolva o VS pelo vswhere compila com um toolset que depende da ordem de consulta, e
dois toolsets diferentes significam ABI diferente no `.dll` da extensão. A regra que sai daqui é a
do Passo 1 (c): o `build.bat` **nomeia o caminho e o toolset** (`14.44.35207`) e recusa os outros, em
vez de perguntar ao vswhere qual é o mais novo.

**E a correção do §1.1:** a célula dizia `cl.exe 19.44.35207`. `14.44.35207` é o nome da **pasta** do
toolset; a versão do compilador é `19.44.35228`. São duas grandezas diferentes, e a página as somava.

**Fora da casca do vcvars** (o PATH que o dono tem hoje, `passo1_fora_da_casca.log`): `cl`, `dumpbin`,
`lib`, `scons`, `cmake` e `ninja` — exit 1, não resolvidos. `link` **resolve**:
`C:\Program Files\Git\usr\bin\link.exe`, GNU coreutils 8.32, que cria **hard link de arquivo** e não
linka nada. Isso é o **furo #35**, e a consequência é concreta: se o `build.bat` esquecer o
`call vcvars64.bat`, ele não recebe "link não encontrado" — ele chama um programa de outra suíte, que
reclama de argumentos ou cria um arquivo com o nome do output. Um build que falasse por ausência
seria diagnóstico; este falha por **presença errada**. Dentro da casca (`passo1_vcvars_onde_resolve.log`)
os quatro aparecem, `cl`/`link`/`dumpbin`/`lib` sob `14.44.35207\bin\Hostx64\x64\`, o `VCToolsInstallDir`
aponta para a mesma pasta e o `where link` lista o do Git **depois** do MSVC. Regra do Passo 1 (c): o
`build.bat` confere `VCToolsInstallDir` e a versão do `cl` antes de compilar, e **não** aceita um
`link.exe` fora daquela pasta.

**`scons` não existe, e o SCons do §6.1 também não.** `where scons` exit 1 e `python -c "import SCons"`
`ModuleNotFoundError` — a frase "exatamente como o SCons do Godot faz (§1.4)" descrevia o procedimento
da engine, não uma ferramenta desta máquina, e a célula do §1.1 tinha deixado isso lido como "MSVC +
SCons". Corrigido no §6.1.

### 12.2 O cabeçalho de interface: a testemunha antiga não discriminava, e o gerador não tem CLI

O §1.4 citava `GDExtensionInitializationFunction` e as enums `GDEXTENSION_VARIANT_TYPE_*` como prova de
que o cabeçalho gerado era o de 4.7.2. Medido contra o único cabeçalho local —
`.tools/godot-cpp-godot-4.4.1-stable/gdextension/gdextension_interface.h`, 129 768 B, 3 085 linhas,
sha256 `355ff4c6…` — os dois **existem idênticos**: a typedef na linha 782 daquele arquivo, e
`GDEXTENSION_VARIANT_TYPE_` em **48** linhas nos dois. Nenhuma das duas testemunhas separa 4.4 de 4.7.

O que separa está em `passo1_header_fonte_abi.log`, lido linha a linha do gerado:
`GDExtensionClassCreationInfo6` (`:402`), `GDExtensionClassCreateInstance3` (`:220`) e
`GDExtensionInterfaceClassdbRegisterExtensionClass6` (`:2954`). O cabeçalho 4.4.1 para em
`GDExtensionClassCreationInfo4` e `GDExtensionClassCreateInstance2`, e tem **0** ocorrências de
`RegisterExtensionClass6`. São estes três nomes que a Fase 1 assina, e é por eles que ela é 4.7.2.

**O `api_version` não está em lugar nenhum** — e a frase do §1.4 que dizia que ele "só aparece no JSON"
estava errada. O JSON (`gdextension_interface.json`, 328 021 B, 9 327 linhas, sha256 `7d8c0a03…`) tem
exatamente cinco chaves de topo — `_copyright`, `$schema`, `format_version`, `types`, `interface` —,
`format_version: 1`, **sem** `api_version`, com **147** tipos e **179** funções de interface.
`format_version` é a versão do **esquema do arquivo**. A versão da interface é o que a engine devolve
em runtime pelo `call_func`/`token` da própria `GDExtensionInitializationFunction`, e é isso — não um
`#define` — que a Fase 1 confere.

**O gerador não é um script.** `make_interface_header.py` (12 015 B, 353 linhas, sha256 `a4ed7de9…`) tem
`ocorrencias_de___main___=0`, `ocorrencias_de_argparse=0`, `ocorrencias_de_sys_argv=0`: o ponto de
entrada é `def run(target, source, env)` (`:27`), um **emissor do SCons**, que escreve dentro de
`methods.generated_wrapper(str(target[0]))` (`:38`) e lê o JSON por `methods.get_buffer` — ou seja, as
duas funções vêm do `methods.py` do build do Godot, e não do arquivo. Rodá-lo foi isso: as duas entradas
na tag `4.7.2-stable`, um shim de **11 linhas / 267 B / sha256 `7d0b6de2…`** que fornece
`get_buffer` e `generated_wrapper`, e três linhas de driver.

**E a reprodução foi re-executada, não prometida.** `passo1_header_reproducao.sh` confere as entradas
pelos hashes acima, roda o gerador num work temporário e compara com o arquivo arquivado:
gerado **143 170 B** sha256 `777a3fe517c1b29eece0646c50ec0da1c617586ea2e9ffbc1965e8fdb9149b2b` —
`cmp` exit **0**, byte a byte o mesmo fruto. As entradas ficam em
`.tools/gdextension-interface-src/` (gitignored: `.gitignore:5`), porque são arquivo de terceiro
baixado; o que entra no git é o cabeçalho gerado, como o §6.1 decide.

**Licença: o bloco existe no JSON e o gerador o descarta.** O `_copyright` do JSON tem **27 linhas** e
contém as marcações `Copyright`, `Permission is hereby granted`, `WITHOUT WARRANTY`, `MIT` e `AUTHORS`.
No cabeçalho gerado a leitura procura as contrapartidas — `GODOT ENGINE`, `Permission is hereby granted`,
`MIT`, `AUTHORS` — e devolve **False** nas quatro; `grep -ci 'licen'` no arquivo inteiro é **0**. O
gerador usa `_copyright` uma única vez, como chave **válida** no `check_allowed_keys` (`:32`), e nunca a
escreve. (A leitura anterior desta página, que contava quatro ocorrências de licença dentro do cabeçalho,
foi feita no header do godot-cpp — que tem o bloco, linha 15 em diante — e não no gerado.) Vendorizar o
cabeçalho é, portanto, distribuí-lo **sem** a licença dentro dele: a atribuição deixa de ser um efeito
colateral do arquivo e passa a ser uma linha nossa em `THIRD_PARTY_LICENSES.md`, escrita no mesmo commit
que o vendoriza.

**Forma do arquivo, porque o hash depende dela.** O fruto cru tem 3 178 linhas e **todas** terminam em
CRLF: `CR=3178`, `LF=3178`, `linhas_sem_CR=0`, e a diferença entre o cru (143 170 B) e a forma LF
(139 992 B) é exatamente 3 178 — um CR por linha. A afirmação anterior, de "24 linhas sem CR", não
reproduz. O `git check-attr` dos dois caminhos onde ele vai morar (log, linhas 32-41):
`native/af_mind/include/gdextension_interface.h` → `text: auto`, `eol: lf` (o checkout é **LF**, sha256
`4c0aac8d…`), e `docs/evidence/**` → `text: unset` (a cópia de evidência **preserva CRLF**, sha256
`777a3fe5…`). Consequência escrita antes do Passo 1 (c): o gate de SHA do `build.bat` confere **as duas
formas** — a do checkout do git e a do fruto cru — e recusa qualquer outra. Uma régua que soubesse só
um dos dois hashes passaria ou falharia conforme o `core.autocrlf` de quem clonou, que é exatamente a
classe de defeito do furo #32.

### 12.3 Nada é linkado no Passo 1: zero `.lib` na árvore inteira

**Re-lido no Passo 2 (a), porque a afirmação era sobre a árvore do Passo 1 e o Passo 2 a mudou.** O que
continua medido é o clone: `git check-ignore -v native/af_mind/bin/llama_import.lib` devolve
`.gitignore:8:bin/` com exit 0, então nenhum `.lib` entra no git e um clone limpo tem os **0** arquivos
de before. O que mudou é a árvore depois de `build.bat`: a procura por `*.lib` fora de `.git` devolve
**9** — as quatro import libs geradas do export-set, o `af_mind.lib` que o próprio `link /DLL` produz, e
as quatro do `bin\ab-ordinal` que o A/B do §15.4 escreve. A frase abaixo, escrita na Fase 0, continua
autoritativa para o Passo 1 e deixa de sê-lo para o Passo 2 (a), que é exatamente o passo ela anunciava.

A procura por `*.lib` em todo o repositório (fora `.git`) devolve **0** arquivos, e
`.tools/llama/runtime/` tem **53** entradas — **30** `.dll`, **22** `.exe` e uma linha de licença LLVM
OpenMP. Não existe biblioteca de importação do llama.cpp nesta máquina: o Passo 1 **não** linka contra
o runtime, e qualquer frase que prometesse "linkar o `llama.dll`" no passo do esqueleto estaria
descrevendo um link por `LoadLibrary` que é o Passo 2. É por isso que o gate de símbolos do §1.3 saiu do
Passo 1 e foi escrito no §5.1 como gate do **Passo 2**, com import libs gerados do export-set medido e
`/DELAYLOAD`. O que sobra no Passo 1 é compilação contra o cabeçalho de interface e o `.dll` da própria
extensão — nada de llama.cpp.

### 12.4 O manifesto da pasta estava com hash de outra forma de arquivo

`sha256sum -c artifacts.sha256`, na pasta, dava **3 FAILED em 31 entradas (28 OK)** antes desta passada:
`af_exports_build.bat`, `af_np2_build.bat`, `af_np3_build.bat`. As três linhas armazenavam o hash da
forma **LF** do conteúdo; os arquivos, no disco e em qualquer clone limpo, são CRLF, porque
[`.gitattributes:22`](../../.gitattributes#L22) tem `*.bat text eol=crlf` (o `git check-attr` dos três
devolve `text: set`, `eol: crlf`). A convenção da casa, escrita no **item 11** da lista de furos
descobertos do [status](../melhorias-status.md), é que os manifests são computados **`sha256sum -b`** —
sobre os bytes
que o checkout produz, porque a regra `* text=auto eol=lf`
([`.gitattributes:3`](../../.gitattributes#L3)) normaliza texto no add e a linha `docs/evidence/** -text`
([`:9`](../../.gitattributes#L9)) é justamente o que preserva os CR da evidência. Aqui o erro foi do
**instrumento**, não da evidência: as três linhas foram computadas sem o `-b`. Refeito com `-b` e com as
quatorze evidências desta passada dentro — 31 + 14 = **45 entradas / 45 OK** —, e as únicas linhas de
arquivo pré-existente cujo conteúdo mudou são essas três. Quarenta e cinco era a conta **daquele** lote, e
é por isso que a régua dele vale para os seguintes: o Passo 1 (b) acrescenta nove evidências e o manifesto
passa a **54 entradas**, com a conta re-rodada por `sha256sum -c` num clone limpo — onde ela dá 53/53 OK,
porque o log que registra o clone ainda não estava dentro do commit clonado. Fica como
**furo #36**, com a régua: `sha256sum -c` do manifesto de
qualquer pasta de evidência tem de ser **tudo OK num clone limpo**, e um `FAILED` em `.bat` ou `.log` é
defeito do hash, não do arquivo.

E a régua pegou um caso nosso na hora de fechar o lote: `passo1_vcvars_onde_resolve.bat` estava **LF**, e
a mesma linha 22 do `.gitattributes` que conserta os três `.bat` velhos converte todo `.bat` do checkout
para CRLF — ou seja, o arquivo que eu hash-ei não era o arquivo que o clone devolve. Convertido e
re-rodado, o corpo do stdout saiu **idêntico linha a linha** ao da corrida em LF (a nota está no topo do
próprio log), e o `sha256sum -c` refeito deu 45/45. A lição é a do furo #36 em chave invertida: a forma que
o hash tem de registrar é a do **checkout**, não a do editor.


---

## 13. O Passo 1 (b): o gate nasceu vermelho, e o vermelho é conta feita

O §5.1 prometia uma checagem que **nasce vermelha**. Ela existe, roda, e o vermelho é número, não
adjetivo. `_test_extensao_carrega_classe`
([`tests/aether_reactions_test.gd:5540`](../../tests/aether_reactions_test.gd#L5540)) entrou no fim da
lista de testes (`:49`) e imprime, nesta ordem, as cinco premissas de que o Passo 1 é dono:

1. **descritor no disco** — `FileAccess.file_exists("res://native/af_mind/af_mind.gdextension")`;
2. **extensão listada pela engine** — `GDExtensionManager.is_extension_loaded()`, e `load_extension()`
   só com o descritor presente. O `-1` impresso quando a chamada não acontece é a prova de que o passo
   não chamou API às cegas: medido em sonda, chamar sem arquivo faz a engine cuspir dois `ERROR` no
   stderr, e o vermelho passaria a ser do instrumento, não da premissa;
3. **biblioteca aberta no processo** — `GDExtension.is_library_open()`. É o fato que a lista da engine
   não dá: um descritor apontando para um `.dll` inexistente entra na lista e não abre;
4. **classe na ClassDB** — `ClassDB.class_exists("AfMindOracle")`;
5. **objeto vivo** — `ClassDB.instantiate()` devolvendo corpo, com `get_class()` batendo o nome.

A corrida está em
[`passo1b_runner_vermelho.log`](../evidence/oraculo-nativo-22/passo1b_runner_vermelho.log): cinco linhas
`FALHA` e rodapé **`288 checagens 5 falhas 33.330 s`**, e acima delas
`OK censo de testes completos | 66/66` e `OK censo de checagens | 288/288`. Os dois `OK` do censo são o
que separa este vermelho do furo **#1** do status: as cinco checagens **contaram**, então nenhuma foi
roubada por um `SCRIPT ERROR` no meio, e os três `stderr` da rodada estão em **0 0 0 bytes**
([`passo1b_stderr_conta.log`](../evidence/oraculo-nativo-22/passo1b_stderr_conta.log)).

O censo foi re-derivado na hora, não depois: `EXPECTED_CHECKS` passa de **283** a **288**
([`:65`](../../tests/aether_reactions_test.gd#L71)), porque a linha `_checks + 1 == EXPECTED_CHECKS` de
`_finish` é justamente o instrumento que converte passo abortado em vermelho. As outras duas corridas não
se moveram: suíte **255 checagens / 0 falhas / 48,7 s**
([`passo1b_suite.log`](../evidence/oraculo-nativo-22/passo1b_suite.log)) e journal **128 / 0 / 5,770 s**
([`passo1b_journal.log`](../evidence/oraculo-nativo-22/passo1b_journal.log)); o pre-gate de parseio
(`--check-only`) saiu **exit 0** ([`passo1b_pre_gate.log`](../evidence/oraculo-nativo-22/passo1b_pre_gate.log)).

**Nenhum `arquivo:linha` do repositório envelheceu com este commit, e o motivo é aritmético:** as três
edições no topo do runner substituem linha por linha (hunks `49→49`, `51-56→51-56`, `60→60`) e a função
entra **depois** da última linha do arquivo, então nada abaixo de 5 514 se moveu. As três réguas do §11,
rodadas depois da prosa desta sessão, estão em `passo1b_ruler_doc_anchors.log`,
`passo1b_ruler_plan_cites.log` e `passo1b_ruler_plan_ids.log` na mesma pasta.

O manifesto da pasta acompanha: as nove evidências desta passada somam-se às quarenta e cinco do lote (a)
e a conta fecha em **45 + 9 = 54 entradas**, computada `sha256sum -b`. A conferência não foi feita nesta
árvore: foi feita **num clone limpo** de `68416f5` — `git clone --branch` do próprio repositório, `--import`
frio antes de qualquer corrida — e lá o `sha256sum -c` devolve **53 entradas OK, 0 não-OK**. Cinquenta e
três, e não cinquenta e quatro, porque o log que registra o clone ainda não estava dentro do commit
clonado; é a mesma conta, em dois momentos, e é por isso que as duas linhas acima não se contradizem. A
régua continua sendo a do furo #36: um `FAILED` em `.log` ou `.bat` é defeito do hash, não do arquivo.

E o clone pegou o **furo #33** em quem o rodou, logo na primeira invocação. Passado o `.gd` por posição,
sem `--script`, a engine **boota o jogo** headless: 909 bytes de stdout com `spawn banda 1 ...` e
`toca 0 fundada ...`, nenhum `OK` de teste, e o processo só parou porque o `timeout 400` externo o matou —
**exit 124** e 2 060 bytes de stderr com os `ERROR: BUG: Unreferenced static string` do encerramento.
Refeita a corrida com `--script res://tests/aether_reactions_test.gd`, a mesma árvore de fora devolve
**exit 1**, **stderr 0 bytes**, as cinco linhas `FALHA extensao_carrega_classe` literais,
`OK censo de testes completos | 66/66`, `OK censo de checagens | 288/288` e rodapé **`288 checagens 5
falhas 33,629 s`** — o vermelho reproduzido fora da árvore de trabalho, em `passo1b_clone_limpo.log`.

O que **não** fecha aqui: `native/` continua sem existir, e o verde das cinco linhas é o Passo 1 (c) —
`build.bat` com o toolset pinado (§12.1) e o gate de SHA conferindo **as duas formas** do cabeçalho
(§12.2), o cabeçalho vendorizado com a linha de licença em `THIRD_PARTY_LICENSES.md` no mesmo commit
(§6.1), e `register_types.cpp` registrando **uma** classe sem função de IA nenhuma. A `main` pousada está
em 283/0 na revisão dela; o pouso desta perna se dá com o runner em **288/0**, e enquanto a (c) não
existe o que se publica na branch é o vermelho com número — um gate verde por decreto seria exatamente o
que o mandato 4 veda.

---

## 14. O Passo 1 (c): a engine abre a biblioteca e devolve um objeto vivo

Cinco arquivos entram no git; o sexto, não. `native/af_mind/af_mind.gdextension` (14 linhas, 502 B),
`native/af_mind/build.bat` (167 linhas, 7 954 B, CRLF), `native/af_mind/src/register_types.cpp` (183
linhas, 8 734 B, LF) e `native/af_mind/include/gdextension_interface.h` (139 992 B, **LF**,
`4c0aac8da3df…`) — a forma do checkout conferida por `sha256sum -b` antes do commit, porque é o valor que
o §12.2 compara e um `git config core.autocrlf` torto o mudaria em silêncio. Entra também o sidecar
`native/af_mind/af_mind.gdextension.uid` (20 B, uma linha: `uid://bnq2qg4snmnep`), que a engine escreve no
primeiro `--import` e que **fica** no commit pelo mesmo motivo que o furo #25 do status chama de sujeira
quando falta: sem ele, todo clone limpo mostra uma linha `??` depois do import, e o `uid` deixaria de ser
estável entre máquinas. Nada no repositório referencia a extensão por `uid://` — o descritor e as cinco
linhas do gate falam por `res://` — então o que se preserva aqui é a limpeza do clone, não uma ligação. O
que fica **fora** é `bin/`: a linha 8
do `.gitignore` já cobria esse caminho antes de a pasta existir, e o `git check-ignore -v` desta árvore,
rodado arquivo por arquivo, devolve `.gitignore:8:bin/` para `native/af_mind/bin/af_mind.dll`, para o
`register_types.obj` e para o `.gdignore` do item 2 do §14.4, e **nada** para os outros cinco. O §6.1 escrevia que "um clone limpo sem ele [o cabeçalho] não compila
nada"; o complemento medido agora é que o clone **com** o cabeçalho compila — é o que a conferência do
pin faz, e é o único caminho pelo qual este commit é reproduzível em outra máquina.

### 14.1 A régua do build, em stdout

`cmd //c native\af_mind\build.bat` devolve **exit 0**, **stderr 0 bytes** e oito linhas de régua, em
ordem, em [`passo1c_build_final.log`](../evidence/oraculo-nativo-22/passo1c_build_final.log) — abaixo só
as oito, porque o arquivo tem também as duas linhas de conversa do próprio `cl` e `link`
(`register_types.cpp` e `Creating library ...af_mind.lib and object ...af_mind.exp`), que o `.bat` não
filtra:

```
[regua] header_sha256=4c0aac8da3dfedc14d0e049205aeaaa11f32802bee56d4a275a466ac231fa916 forma=aceita
[regua] vcvars=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat toolset=14.44.35207
[regua] VCToolsInstallDir=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\
[regua] cl_banner=Microsoft (R) C/C++ Optimizing Compiler Version 19.44.35228 for x64
[regua] link_primeiro=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\link.exe
[regua] dll_bytes=105472
[regua] export=          1    0 00001120 af_mind_entry
[ok] build.bat: C:\Aetherfall\native\af_mind\bin\af_mind.dll
```

As três primeiras são o §12.1 e o §12.2 executados, não prometidos: as duas formas do cabeçalho
(`SHA_LF` e `SHA_CRLF`) estão escritas no `.bat` e o `goto :hash_recusado` pega qualquer outro valor; o
toolset é nomeado e a cauda de `VCToolsInstallDir` é comparada caractere a caractere, então o 2019
(14.29.30133) desta máquina é recusado com `[falha]` impressa em vez de compilar torto. O `export=` é o
`dumpbin /exports` confirmando o símbolo que o descritor nomeia — com ele, a régua 5 do `.bat` decide o
link sem depender de rodar a engine. O log arquivado é o da **última** compilação desta árvore, rodada já
com os cinco arquivos na forma em que entram no commit, e o stderr accompanyante está vazio
([`passo1c_build_final.err`](../evidence/oraculo-nativo-22/passo1c_build_final.err)).

### 14.2 O que matava o `instantiate`, decidido por A/B e não pelo comentário do header

Quatro premissas passavam e a quinta derrubava o processo com **exit 127** e **stderr 0 bytes**: o
`ClassDB.instantiate("AfMindOracle")` morria dentro do `create_instance_func`. Havia duas candidatas na
mesa (reentrância no próprio construtor, e storage de `StringName` mal dimensionado), e a segunda não
sobrevive à primeira corrida: a sonda imprimia `p3_aberta=true nivel=0` e `p4_class_exists=true` — ou
seja, a classe estava registrada com o nome certo, lido pelo próprio `StringName` que se passou ao
registro. Sobrou a primeira, e ela foi decidida por A/B na mesma sonda (`.tools/probe_af_mind.gd`, seis
linhas de print, cena nenhuma, `timeout 90` por fora — o par do furo #33).

**Braço 1 — construir pelo pai** ([`passo1c_arm1_probe.log`](../evidence/oraculo-nativo-22/passo1c_arm1_probe.log),
stderr **0 bytes** — o arquivo vazio é a régua): `construct_object3(parent_name_sn())`, e a quinta
linha sai

```
p5_get_class=AfMindOracle refcounted=true iid=-9223372010229332533
p5_metodos=66
```

**Braço 2 — construir pelo nosso nome, com um contador de profundidade instalado só para a
atribuição** ([`passo1c_arm2_probe.err`](../evidence/oraculo-nativo-22/passo1c_arm2_probe.err),
[`passo1c_arm2_probe.log`](../evidence/oraculo-nativo-22/passo1c_arm2_probe.log)): o stdout **para em
`p4_class_exists=true`** — nada depois da linha 24 da sonda roda — e o stderr, 266 bytes, tem uma única
ocorrência de

```
ERROR: af_mind: create_instance entrou de novo em si mesmo (profundidade 9)
   at: create_instance (C:\Aetherfall\native\af_mind\src\register_types.cpp:77)
       [0] _initialize (res://.tools/probe_af_mind.gd:24)
```

Nove profundidades, não uma: cada `construct_object3("AfMindOracle")` reinvoca o
`create_instance_func` registrado para "AfMindOracle", e o processo estoura antes de devolver objeto. O
`classdb_construct_object3` do header admite construir "an already-registered extension class" e **não
diz** que esse caminho reentrancia; a referência em `.tools/godot-cpp-godot-4.4.1-stable` faz o que o
braço 1 faz (`src/classes/wrapped.cpp:77` constrói pelo nome do pai e depois amarra a instância com
`object_set_instance`). A palavra aqui é a corrida, não o comentário do header — e o contador de
profundidade foi **removido** depois: o arquivo restaurado, re-compilado, e o binário de fecho saiu com
os mesmos `dll_bytes=105472` e o mesmo offset `00001120` do braço 1, o que diz que a instrumentação
temporária não ficou no que entra no git.

O que o Passo 1 (c) escreve, então: o alvo do `construct_object3` é o **pai built-in**, a instância é
amarrada com `object_set_instance(obj, class_name_sn(), inst)`, e `AfMindOracleInstance` tem um marker
`0x41464D31` ("AFM1") em vez de corpo — o `GDExtensionClassCreationInfo6` é zero-initialized e **não**
declara método nenhum, então os 66 que a sonda conta são os herdados de `RefCounted`, e a linha de
`get_class()` batendo o nome é o que prova que o objeto é da nossa classe.

### 14.3 As cinco premissas verdes, e o vermelho intermitente que não é daqui

A checagem da perna 22 (b) sai verde na árvore de fecho, com a cache de import **nova** —
[`passo1c_runner_pos_build.log`](../evidence/oraculo-nativo-22/passo1c_runner_pos_build.log), linhas
535-539, exit 0 e stderr **0 bytes**:

```
OK extensao_carrega_classe: o descritor existe no disco | caminho=res://native/af_mind/af_mind.gdextension existe=true
OK extensao_carrega_classe: a engine lista a extensao como carregada | load_extension=-1 ja_vinha_do_boot=true agora=true total_registradas=1 lista=["res://native/af_mind/af_mind.gdextension"]
OK extensao_carrega_classe: a biblioteca abriu dentro deste processo | objeto_valido=true is_library_open=true nivel_minimo_de_init=0
OK extensao_carrega_classe: a classe esta registrada na ClassDB | class_exists(AfMindOracle)=true
OK extensao_carrega_classe: a ClassDB devolve um objeto vivo daquela classe | instantiate_valido=true get_class=AfMindOracle
```

e o rodapé `288 checagens 0 falhas 33,813 s`, com `OK censo de testes completos | 66/66` e
`OK censo de checagens | 288/288` acima. Note o `load_extension=-1`: **a checagem não chamou o load**,
porque `ja_vinha_do_boot=true` — a engine já tinha aberto a extensão sozinha (o §14.4 diz o que põe ela
na lista). O `-1` é o sentinela de "não chamado", medido na (b) exatamente para não virar premissa
muda. As outras três corridas, na mesma árvore: suíte **255 checagens / 0 falhas / 49,3 s** com zero
`SCRIPT ERROR` ([`passo1c_suite_pos_build.log`](../evidence/oraculo-nativo-22/passo1c_suite_pos_build.log)),
RNG **27 / 0 / 2,703 s** e journal **128 / 0 / 7 de 7 / 5,809 s**
([`passo1c_rng.log`](../evidence/oraculo-nativo-22/passo1c_rng.log),
[`passo1c_journal.log`](../evidence/oraculo-nativo-22/passo1c_journal.log)).

A árvore do commit foi re-confirmada depois do último `build.bat`, com o `.dll` recompilado do que entra
no git: as mesmas cinco linhas, exit 0, stderr **0 bytes** e rodapé **`288 checagens 0 falhas 34,852 s`**
([`passo1c_confirm_runner.log`](../evidence/oraculo-nativo-22/passo1c_confirm_runner.log),
[`passo1c_confirm_runner.err`](../evidence/oraculo-nativo-22/passo1c_confirm_runner.err)), e suíte **255 /
0 / 48,8 s** com zero `SCRIPT ERROR`
([`passo1c_confirm_suite.log`](../evidence/oraculo-nativo-22/passo1c_confirm_suite.log)). O stderr dessa
suíte, porém, saiu com **249 bytes**, e a régua manda ler: são as duas linhas do **par de vazamento do
quit** que o status registra desde a perna 11 — `4 ObjectDB instances were leaked at exit` e `2 resources
still in use at exit`, nomeados por `--verbose` como `AudioStreamPlaybackOggVorbis` / `AudioStreamOggVorbis`
de `assets/audio/amb/amb_birds.ogg`. Ele é intermitente por medição da própria época (a segunda corrida do
mesmo clone, mesmo comando, deu **0** bytes) e nenhuma das duas linhas menciona `af_mind`, `AfMindOracle`
ou a extensão: esta perna não o atribui e não o conserta — quem o deve é o débito já escrito na seção de
débitos, e a corrida de fecho acima é testemunha nova de que ele sobrevive ao Passo 1 (c).

A primeira corrida de fecho, porém, deu **`288 checagens 1 falhas`**
([`passo1c_runner.log`](../evidence/oraculo-nativo-22/passo1c_runner.log)) e a falha não era de
extensão nenhuma: `FALHA nenhum estouro de subtree no budget | trips_solo=0 trips_matilha=1`, com o
pico de BT da matilha em 418 µs contra o `SubtreeGuard` de 400 µs. A atribuição fecha nos dois sentidos
que a casa exige:

- **o mesmo vermelho existia antes desta perna, inclusive em braço de controle sem perna nenhuma**: a
  linha `FALHA nenhum estouro de subtree no budget` está em
  `docs/evidence/alcateia-rutinas/contagio-runner-2.log:153` (`trips_solo=0 trips_matilha=1`), em
  `alcateia-rutinas/amortecimento-runner-2.log:157` (`trips_solo=1 trips_matilha=0`) e em
  `alcateia-rutinas/ataque-runner-1.log:319` com `trips_matilha=10` — as três da perna 10, quando não
  havia `native/` nem GDExtension no repositório. E o mais direto:
  `acasalamento-censo-11/control_main_runner03.log:275` e `control_main_runner10.log:276`, que são o
  **braço de controle** da perna 11 — o runner rodado na `main` sem o código daquela perna — e os dois
  deram `trips_solo=1`. A leitura registrada na época é a do **furo #20** do status: o `SubtreeGuard`
  cronometra parede de relógio e GDScript não tem relógio de CPU, então `trips == 0` é portão de
  velocidade de máquina, não de código. Amostra desta árvore, com as oito corridas do runner
  archivadas: **8 com a extensão no disco (1 vermelha, 7 verdes)** —
  `passo1c_runner.log`, `passo1c_runner_run2.log`, `passo1c_amostra_com_{1,2,3}.log`,
  `passo1c_runner_final.log`, `passo1c_confirm_runner.log` e a de fecho acima — e **2 com o descritor
  fora da árvore, as duas verdes**.
- **e a ablação do descritor não move o contador**: com `native/af_mind/af_mind.gdextension` fora da
  árvore, o rodapé volta a **`288 checagens 5 falhas`** com as cinco linhas `FALHA extensao_carrega_classe`
  literais — o vermelho da (b) reproduzido sob demanda, em
  [`passo1c_semtensa_run1.log`](../evidence/oraculo-nativo-22/passo1c_semtensa_run1.log) e
  `..._run2.log` (33,637 s e 33,739 s). As duas saem com `trips_matilha=0`, e isto **não** é atribuição:
  dois braços não distinguem 1-em-8 de 0-em-2. O que fecha a atribuição é o item de cima — a assinatura
  existe seis pernas antes desta e o `SubtreeGuard` mede parede de relógio — e o que ela diz é que o
  vermelho é o #20, não a extensão.

Um ponto que a rodada corrige em prosa antiga desta página, e ele é de consequência, não de gosto: o
`SubtreeGuard` **retorna FAILURE** quando estoura ([src/ai/behavior/bt_tree.gd:134-136](../../src/ai/behavior/bt_tree.gd#L134-L136)),
então um `trips` não é só medição — é a árvore daquela passada perdendo o nó. A colheita que falta para
fechar o #20 por dentro é o `tick`/folha onde o estouro aconteceu, que hoje não é impresso; e nenhuma
linha disso é escrita por esta perna.

### 14.4 Quem põe o descritor na lista do boot, e o `.obj` que o importador comia como malha

Duas coisas que nenhuma corrida da Fase 0 tinha olhado, e as duas mudam o que se escreve no README.

1. **O `--import` é quem registra a extensão, não a presença do arquivo.** Com a cache de import
   anterior ao `native/`, a sonda de boot em **cena real** (não `--script`) devolvia
   `b2_ja_no_boot=false`, `b2_lista=[]`, `b3_class_exists=false`
   ([`passo1c_boot_cache_velho.log`](../evidence/oraculo-nativo-22/passo1c_boot_cache_velho.log),
   stderr 0 bytes). Feito o `godot --headless --path . --import`, o `.godot/extension_list.cfg` passa a
   ter a linha `res://native/af_mind/af_mind.gdextension` e a mesma sonda devolve
   `b2_ja_no_boot=true`, `b4_total_registradas=1`, `b3_class_exists=true`
   ([`passo1c_boot_pos_import.log`](../evidence/oraculo-nativo-22/passo1c_boot_pos_import.log),
   exit 0, stderr 0 bytes). O passo já era obrigatório no protocolo de clone do README, então nada muda
   para quem segue a ordem — mas a frase "a engine abre a extensão" agora tem o antecedente certo. A
   testemunha inversa está no mesmo lote arquivado: a corrida dada com a cache antiga imprimiu
   `load_extension=0 ja_vinha_do_boot=false` na segunda linha
   ([`passo1c_runner.log`:536](../evidence/oraculo-nativo-22/passo1c_runner.log)) e as cinco premissas
   continuaram verdes, porque a checagem chamou o load ela mesma. O `-1` existe exatamente para as duas
   situações aparecerem escritas no stdout em vez de virar uma premissa muda.
2. **Furo #37, descoberto e fechado nesta perna:** o importador do editor varre `res://` e reclamou o
   `native/af_mind/bin/register_types.obj` do linker como **Wavefront**. Um `--import` desta árvore
   devolvia **464 bytes** de stderr com três `ERROR` —
   `Couldn't read OBJ file 'res://native/af_mind/bin/register_types.obj'`
   (`resource_importer_obj.cpp:236`), `Condition "meshes.size() != 1" is true. Returning: ERR_BUG`
   (`resource_importer_obj.cpp:691`) e `Error importing ...` (`editor_file_system.cpp:3093`), e deixava
   um `register_types.obj.import` ao lado do arquivo. A correção é o mecanismo da própria engine, escrito
   pelo `build.bat`: `bin/.gdignore` criado antes de compilar, com `[falha]` impressa se o arquivo não
   puder ser escrito — é o `.bat` que o cria porque `bin/` é gitignored, e num clone sem build não há
   `bin` nenhum. O `--import` seguinte devolve **exit 0 e stderr 0 bytes**
   ([`passo1c_import_com_gdignore.err`](../evidence/oraculo-nativo-22/passo1c_import_com_gdignore.err))
   mantendo a linha da extensão no `extension_list.cfg`, e a sonda de boot continua
   `ja_no_boot=true`. O que **não** foi medido, e vai escrito para não virar promessa: o descritor só
   tem as chaves `windows.*` (motivo: o §12.1 mediu **um** compilador, o MSVC do toolset 14.44.35207),
   e ninguém abriu esta extensão em Linux ou macOS — o comportamento lá é `[OPEN]`, e a perna que o
   medir é a que adiciona a chave, não esta.

### 14.5 O estado de quem clona e não compila: três `ERROR` por boot (furo #38, aberto)

Com o descritor no disco, a linha no `extension_list.cfg` e o `.dll` **ausente** — que é exatamente o
estado de todo clone deste commit cujo dono não rodou `build.bat` — a engine reclama em cada boot, na
cena real: exit 0, o jogo continua abrindo, e o stderr sai com **447 bytes**
([`passo1c_boot_sem_dll.err`](../evidence/oraculo-nativo-22/passo1c_boot_sem_dll.err)):

```
ERROR: Condition "!FileAccess::exists(path)" is true. Returning: ERR_FILE_NOT_FOUND
   at: open_dynamic_library (platform/windows/os_windows.cpp:483)
ERROR: GDExtension dynamic library not found: 'res://native/af_mind/af_mind.gdextension'.
   at: open_library (core/extension/gdextension.cpp:810)
ERROR: Error loading extension: 'res://native/af_mind/af_mind.gdextension'.
   at: load_extensions (core/extension/gdextension_manager.cpp:333)
```

Nada em `src/` consome a extensão, então o jogo está intacto nesse estado — mas reclamar três linhas por
boot de um repositório público é ruído que alguém vai ler como defeito do jogo, e a decisão de calar
isso **não** é desta passada. As duas mãos possíveis estão postas, com o custo de cada uma: **(a)** o
`.dll` de 105 472 B entrar no git (produto nosso, MIT, compilável de novo pelo `build.bat`; custo: binário
por revisão num repositório que hoje guarda só fontes e packs com licença por arquivo); **(b)** `Rodar.bat`
e o README passarem a chamar `native\af_mind\build.bat` como passo de onboarding, com o pré-gate de que a
máquina tem o toolset do §12.1 (custo: quem não tem MSVC 2022 vê a recusa impressa em vez de abrir o
jogo). Dono: o dono do repositório escolhe a mão, e enquanto ele não escolhe o furo fica aberto com este
número — que é medido, não previsto.

### 14.6 O que este commit não fecha

- **Nada de IA na extensão.** `AfMindOracle` tem construtor, destruidor e um marker; nenhum método,
  nenhum `load_pack`, nenhum enqueue. O §1.3 — o gate de **símbolos**, com as import libs geradas do
  export-set medido e `/DELAYLOAD` — é o **Passo 2**, e é nele que a premissa "o `.dll` resolve as DLLs
  do runtime no diretório do processo" passa a ser checada (§5.1).
- **O transporte continua HTTP.** `src/ai/mind_oracle.gd` não sabe que a extensão existe, e
  `grep -rn HTTPRequest src` continua devolvendo o que devolvia; isso é o Passo 4, com a checagem
  `transporte_http_zerado` dele.
- **Nenhuma linha de `src/` foi tocada por esta perna**, e a régua é `git diff --name-only main...HEAD
  -- src` devolvendo **vazio**. Disso segue, sem re-corrida: `Channel.COUNT`, `FORMAT_VERSION` e
  `GEN_VERSION` continuam intocados e os hashes de journal publicados nas rodadas anteriores valem para
  a árvore resultante. O que se move é o censo do runner, 283 → **288**, pago na (b).
- **Os três furos novos (#37 fechado, #38 e #39 abertos)** e a colheita que falta ao #20 (a folha onde o
  `SubtreeGuard` estourou) vão para o status com número, não como adjetivo.
- **Nenhum gate de fase** (mandato 4). A Fase 1 termina no §5.1 + §5.2 + §5.3 + §5.4; aqui fechou a
  perna (c) do Passo 1.

### 14.7 A quarta raiz de código é a primeira que as réguas não vêem (furo #39, aberto)

O §12 fechava a passada com "as ausências do `verify_plan_ids` são todas peças que esta página declara
inexistentes". A frase era verdadeira contra o corpus daquela passada e deixou de ser contra esta, e o
motivo não é prosa velha: é a régua. O `verify_plan_ids.py` constrói o corpus numa linha só —
`src/**/*.gd`, `tests/**/*.gd`, `tests/*.gd` — e este commit acrescenta ao repositório **3 543 linhas /
157 202 bytes em cinco arquivos de quatro extensões que nenhum dos três globos alcança** (`.cpp`, `.h`,
`.bat`, `.gdextension`; a quinta é o sidecar `.uid`). O rótulo impresso nunca mentiu — "AUSENTES **em src/
e tests/**" é exatamente o escopo daquela linha — mas a leitura que a casa faz dele, essa sim, mudou de
sentido sem aviso. O arquivo mora em `.tools/`, que a linha 5 do `.gitignore` cobre, e é por isso que ele
aparece aqui citado por nome, sem ponteiro: um link para um caminho que o clone não tem seria um caso
aberto pela própria página.

Medido na saída arquivada desta passada, rodada já com esta subseção no corpo
([`passo1c_ruler_plan_ids.log`](../evidence/oraculo-nativo-22/passo1c_ruler_plan_ids.log)): a página 22
sai com **195** identificadores em backticks, **87** deles AUSENTES, e **24** desses 87 existem agora
dentro de `native/` — a mesma regra de substring da régua, aplicada à mão sobre os cinco arquivos, com os
`bin/` de fora:

| identificador | onde existe em `native/` |
| --- | --- |
| `GDExtensionClassCreationInfo6` | `register_types.cpp` 2, `gdextension_interface.h` 8 |
| `create_instance_func` | `.cpp` 2, header 9 |
| `object_set_instance` | `.cpp` 2, header 5 |
| `classdb_construct_object3` | `.cpp` 3, header 3 |
| `construct_object3` | `.cpp` 7, header 3 |
| `AfMindOracleInstance` | `.cpp` 4 |
| `GDExtensionInterfaceClassdbRegisterExtensionClass6` | `.cpp` 2, header 1 |
| `RegisterExtensionClass6` | `.cpp` 2, header 1 |
| `GDExtensionInterfaceClassdbRegisterExtensionClassSignal` | header 1 |
| `GDExtensionClassCreateInstance2` / `…Instance3` | header 2 / header 4 |
| `GDExtensionClassCreationInfo4` | header 4 |
| `GDExtensionInitializationFunction` | header 2 |
| `GDEXTENSION_VARIANT_TYPE_` | header 48 |
| `call_func` | header 11 |
| `SHA_LF` / `SHA_CRLF` / `dumpbin` | `build.bat` 2 / 2 / 2 |
| `VCToolsInstallDir` | `build.bat` 8 |
| `HEADER_SHA` | `build.bat` 8 |

Dos 24, **20** são nomes que este commit pôs no disco: **14** símbolos de ABI pelos quais o `.dll` se
registra, **1** nome nosso (`AfMindOracleInstance`) e **5** réguas do `.bat`. Os outros **4** coincidem por
substring com palavras que existem no cabeçalho e no `.bat` e não dizem nada: `HEAD` está dentro de
`HEADER_SHA`, `Signal` dentro de
`GDExtensionInterfaceClassdbRegisterExtensionClassSignal`, e `interface` e `types` dentro de identificadores
compostos. Dois dos 20 entraram na lista **por causa desta subseção**, que precisou nomear a variável e o
símbolo para explicar a coincidência: a régua ficou dois identificadores mais cega no exato passo em que o
defeito foi escrito. É por isso que a tabela acima traz a origem por nome, não um total: ler "24 ausências
falsas" sem essa separação seria exatamente o tipo de número que o mandato 1 proíbe.

A contraprova, para a frase não virar desculpa: **63** dos 87 continuam fora de todo código do
repositório, somadas as três raízes, e são os nomes que esta página promete para as pontas seguintes —
`llama_backend_init`, `llama_model_load_from_file`, `llama_chat_apply_template`,
`llama_params_get_fit_params`, `ggml_backend_buffer_type_get_base_buffer`, `load_pack`, `AfMindRuntime`,
`transporte_http_zerado`, `_copyright` (esta última é chave do JSON do gerador, que o §6.1 mediu como
**descartada** — ela nunca vai existir em código nenhum deste repo). A régua continua útil; o que este
registro faz é escrever o limite dela antes que alguém leia `AUSENTES` como "falta no jogo".

Por que esta passada **não** conserta a régua, com as duas razões medidas: **(1)** o arquivo está fora do
git — `git check-ignore -v .tools/verify_plan_ids.py` devolve `.gitignore:5:.tools/` com exit 0, então
nenhum commit desta branch pode levar a correção junto; **(2)** alargar o corpus muda o veredito de uma
régua cujo stdout já está publicado: as rodadas da 12 e da 16 citam **84 identificadores / 11 ausentes** e
**88 / 22**, os dois medidos com o corpus de três globos, e nenhuma das duas foi re-rodada aqui —
re-derive o instrumento depois de publicar o número dele é fazer as duas gerações de rodadas falarem de
árvores diferentes (a classe do furo #36). A escolha, quando ela for feita,
é do dono do repositório, e o lugar natural é a passada que transformar `.tools/` em instrumento
versionado. Dono do furo #39: o dono do repositório. Até lá a leitura correta desta passada é a que está
na tabela: `native/` conferido à mão, nome por nome, e o `AUSENTES` da régua lido como "fora de `src/` e
`tests/`" — que é o que ele sempre disse.

### 14.8 O pouso: a `main` mergida, o clone limpo e as duas testemunhas do par de vazamento

`git merge --no-ff feat/oraculo-nativo-gdextension-22` devolve **`6b817a5`** sobre `85263d5`, **57 arquivos,
+11 949/−20**, e a régua do §14.6 fecha na árvore resultante por hash de árvore, não por diff:
`git rev-parse 6b817a5:src` = **`f77c1961bb8065ea5a78b24677a36c5840891c75`** = a mesma árvore de `85263d5:src`
e a mesma do pouso da 12. Isso é o que autoriza a frase "os hashes de journal publicados valem para a árvore
resultante" sem re-corrida. O `tests/` mudou de árvore (`4855f0e8…` → `0faee7ff…`, uma linha, o gate da (b)),
então o censo **288** é medido aqui, não herdado.

As quatro corridas da mergida e as quatro do clone limpo de `6b817a5` estão em
[`docs/evidence/registro-pouso-passo1c-22/`](../evidence/registro-pouso-passo1c-22/artifacts.sha256), cada
log com o comando gravado na segunda linha. Os números, nas duas árvores: suíte **255 / 0** (48,6 s e 48,8 s),
runner **288 / 0** com as cinco `OK extensao_carrega_classe` nas mesmas linhas 537-541 dos dois logs
(33,417 s e 33,552 s), RNG **27 / 0**, journal **128 / 0 / 7 de 7**. `trips=0` nos dois rodapés de BT, nas
quatro pernas — o que não toca o furo #20, cuja amostra da (c) continua 7 verdes e 1 vermelha.

O build dentro do clone é a parte que fecha a dúvida de forma. Sem `bin/` no git, o clone limpo executa
`cmd //c native\af_mind\build.bat` e devolve exit 0, stderr 0 bytes e as oito `[regua]` com
`forma=aceita` sobre `4c0aac8da3df…` (139 992 B — a forma LF que o §12.2 aceita e que o `eol=lf` do
`.gitattributes` produz num checkout Windows), `toolset=14.44.35207`, `dll_bytes=105472` e
`export= 1 00001120 af_mind_entry`. **Os mesmos 105 472 B e o mesmo offset `00001120` da branch** querem dizer
que o `.cpp` comitado é o `.cpp` compilado, que é a única coisa que separa "esqueleto publicado" de "esqueleto
descrito". O `git status --short` do clone é vazio, e é o sidecar `.uid` comitado que faz isso ser verdade.

Uma assimetria ficou registrada em vez de alisada: o stderr da suíte na árvore mergida é **0 bytes**
([`main_mergida_suite.err`](../evidence/registro-pouso-passo1c-22/main_mergida_suite.err)) e no clone limpo é
**249 bytes** ([`clone_limpo_suite.err`](../evidence/registro-pouso-passo1c-22/clone_limpo_suite.err)) — o par
`4 ObjectDB instances were leaked at exit` / `2 resources still in use at exit`, atribuído na época a
`AudioStreamPlaybackOggVorbis` / `AudioStreamOggVorbis` de `assets/audio/amb/amb_birds.ogg` e intermitente por
medição. As duas testemunhas ficam arquivadas porque a intermitência é a afirmação, e nenhuma das duas linhas
menciona `af_mind`: a extensão não pagou nem quitou o débito.

As três réguas do §11, rodadas com esta subseção escrita e re-rodadas depois de o manifesto existir:
**39 arquivos · 3 062 ponteiros · 209 rótulos · 3 254 links · 0 casos objetivos** (os 17 links novos são os
ponteiros desta subseção e da rodada do status para os logs e para o manifesto; o corpus não ganhou
arquivo, porque a pasta nova é `.log`), **1 024 citações conferidas / 10 arquivos inexistentes / 0 números
fora do arquivo** — os mesmos três números da (c), porque aqui se cita linha de log arquivado, não de
código — e a régua de identificadores move esta página de **195 / 87** para **196 / 88**, com **24** ainda
dentro de `native/` e **64** fora das três raízes. O identificador novo é o hash de árvore desta própria
prova, que a régua lê como nome de peça inexistente: é o §14.7 acontecendo de novo, um identificador por
vez, e é por isso que os números daquela subseção ficam escopados na árvore deles.

O §10 pedia a ordem §5.1 → §5.2 → §5.3 → §5.4 → §5.5 com docs antes de código; o que pousou aqui é o
Passo 1 (c) nessa ordem, e os passos 2, 3 e 4 da Fase 1 continuam por escrever, com o #38 e o #39 abertos
e o #20 sem colheita. Nenhum gate de fase (mandato 4), e a fila segue **22 → 17 → 18 → 20 → 13** com a 22
ainda na frente, porque a perna não fechou.

---

## 15. O Passo 2 (a): o gate de símbolos executado, e a premissa do diretório do processo medida FALSA

O §5.1 tirou duas frases do Passo 1 e as escreveu como débito do Passo 2: o gate de **símbolos** do §1.3,
"com import libs gerados do export-set medido e `/DELAYLOAD`", e a premissa de que "o `.dll` resolve as
DLLs do runtime no diretório do processo". Este passo executa as duas. As seis etapas estão no bloco do
Passo 2 (a) de [`native/af_mind/build.bat`](../../native/af_mind/build.bat#L101), na ordem — `.def` do
export-set medido, quatro import libs, o link do gate com `/DELAYLOAD`, a régua de módulos, as duas
corridas, o controle negativo — e o veredito é `BUILD_RC=0`. A régua lê
[`passo2a_build.log`](../evidence/oraculo-nativo-22/passo2a_build.log): **190 linhas** com as duas correntes
**juntas** (o `build.bat` redireciona stdout e stderr para o mesmo arquivo porque a casa conta CR, não
interleaving). Separadas por uma corrida do mesmo build, são **185** linhas de
[`passo2a_build_split_stdout.log`](../evidence/oraculo-nativo-22/passo2a_build_split_stdout.log) — os
190 menos as **5** de
[`passo2a_build_split_stderr.log`](../evidence/oraculo-nativo-22/passo2a_build_split_stderr.log), que são o
`load_backend:`/`ggml_vulkan:` do próprio runtime e **zero** ocorrências de `warning|error`.

A frase que muda a execução do Passo 2 (b) está no §15.5 e não é opinião: **a premissa do diretório do
processo é falsa nesta máquina, medida** — e o gate **recusou** (exit 5) em vez de morrer de
`STATUS_DLL_NOT_FOUND`.

### 15.1 Duas classes de símbolo, e a classe que não permite chute de assinatura

O gate ([`native/af_mind/src/symbol_gate.cpp`](../../native/af_mind/src/symbol_gate.cpp), 311 linhas)
resolve **37** nomes, e a divisão entre eles é o conteúdo do passo, não um detalhe de escrita:

- **CHAMADOS — 10.** As dez assinaturas que a sonda da Fase 0 chamou e obteve número devolvido,
  transcritas linha a linha de
  [`af_native_probe3.cpp:17-26`](../evidence/oraculo-nativo-22/af_native_probe3.cpp) — nenhum header,
  porque não há `llama.h` nem `ggml.h` na árvore (§12.3). A transcrição forçou a ver três surpresas que a
  documentação de um llama.cpp qualquer descreve ao contrário: `reg_count`, `dev_count` e
  `load_all_from_path` devolvem `size_t`; `reg_get`/`dev_get` recebem o índice **por valor** e devolvem o
  opaco **por valor**; `ggml_backend_dev_description` tem **um** argumento e devolve `const char *`.
- **ENDERECADOS — 27.** Nomes de que o Passo 2 (b) vai precisar, forçados a existir na tabela de imports
  **sem nenhuma afirmação de assinatura**: declarados como dado (`extern "C" void *nome;`), então o que o
  linker emite é o slot `__imp_<nome>`, e um slot não pode ser chamado por engano. De-los como função
  seria afirmar uma assinatura que ninguém mediu — o `dumpbin /exports` devolve nome e ordinal, nunca
  protótipo.

A testemunha impressa de cada um dos 37 é o **endereço** do slot, nunca o seu valor
([`passo2a_build.log:68`](../evidence/oraculo-nativo-22/passo2a_build.log) começa a série
`[simbolo] slot ggml_backend_load_all_from_path=00007FF761BD1D28`, e são **74** linhas no log porque cada
corrida imprime os mesmos 37 slots — `nu` e `preload`): valor de delay-load não resolvido é
lixo até a primeira chamada, e lixo impresso pareceria "não resolveu".

O endereço **não é** testemunha reprodutível e a régua não o trata como tal: re-corrida do mesmo exe na
mesma árvore devolve a série com base diferente — `00007FF761BD…` no log arquivado contra `00007FF70A9E…`
na re-colheita — e as mesmas **caudas** de offset (`…1D28`, `…1DB3`, `…1C08`). É ASLR do próprio PE, não
instabilidade do gate: o que a régua confere são os códigos de saída e as contagens (`nomes_na_tabela`,
`referenciados`), nunca o valor impresso.

### 15.2 Os `.def` nascem do dump arquivado e são re-medidos contra o runtime vivo

`gen_import_libs.py` lê os dumps arquivados do pin `b12499` (S1.3) e, havendo runtime no disco, re-mede o
export-set vivo e recusa divergência. As cinco linhas `[def]` de
[`passo2a_build.log:13-21`](../evidence/oraculo-nativo-22/passo2a_build.log) dão as duas metades:

| módulo | export-total | entradas no `.def` | C puro | C++ decorado | re-medida |
|---|---|---|---|---|---|
| `llama.dll` | 266 | 240 | 240 | 26 | `iguais (266 nomes)` |
| `ggml-base.dll` | 689 | 687 | 687 | 2 | `iguais (689 nomes)` |
| `ggml.dll` | 16 | 16 | 16 | 0 | `iguais (16 nomes)` |
| `ggml-vulkan.dll` | 9 | 9 | 9 | 0 | `iguais (9 nomes)` |
| `llama-fit-params-impl.dll` | 53 | 3 | 3 | 50 | `iguais (53 nomes)` |

O `export_total` e o `entradas` diferem por um motivo medido na Fase 0 e não por descuido: o `.def` do
Passo 2 (a) traz só os nomes **C puro** (a forma com que o gate os referencia), e os decorados ficam de
fora até alguém precisar de um. As quatro bibliotecas saem com bytes testemunhados — `llama 58 326`,
`ggml 5 288`, `ggml-base 154 094`, `ggml-vulkan 3 926` — e `lib` não tem saída em sucesso, então o
arquivo com bytes **é** a testemunha.

### 15.3 A régua de módulos não copia lista nenhuma — e as colunas alinhadas custaram um vermelho

`check_imports.py` fecha a metade que o linker não sabe: em qual dos quatro módulos mora cada nome. Três
listas, nenhuma transcrita à mão — os **referenciados** saem das linhas `AF_SLOT(nome)` do próprio
`symbol_gate.cpp`, o **dono** sai dos `.def` gerados, e o **importado** sai de `dumpbin /imports` do binário
([`passo2a_gate_imports.txt`](../evidence/oraculo-nativo-22/passo2a_gate_imports.txt), 185 linhas). Um nome
que aparecesse em dois `.def` é recusa, porque o linker pegaria o primeiro da linha e a tabela mentiria
sobre quem exporta. O resultado, com o exe em `gate_exe_bytes=157696`:

```
[referencia] gate AF_SLOT=37 nomes
[import] modulo=ggml-base.dll referenciado=10 na_tabela=10
[import] modulo=ggml-vulkan.dll referenciado=4 na_tabela=4
[import] modulo=ggml.dll referenciado=5 na_tabela=5
[import] modulo=llama.dll referenciado=18 na_tabela=18
[import] OK referenciados=37 modulos=4 nomes_na_tabela=37
```

**Esta régua nasceu vermelha e o defeito era dela, não do binário** — é o **furo #40**. A primeira corrida
imprimiu `na_tabela=0` nos quatro módulos e `BUILD_RC=7`, porque o `NAME_RE` exigia **um** espaço entre o
RVA, o hint e o nome. As duas formas medidas no binário são alinhadas por colunas: import comum
`                          E6 CreateFileW` e delay-load
`                                    0000000140001B7F    8C llama_print_system_info`. O `dumpbin`
**preenche** a largura da coluna; a régua lia o texto como se fosse CSV. Corrigido o
[`check_imports.py:69`](../../native/af_mind/check_imports.py#L69) para `\s+` entre os tokens, os 37 nomes
apareceram. O discriminador entre nome e rótulo de tabela continua sendo a **forma** — o token colado
antes do nome é hex de no máximo quatro dígitos, então `00000001 Characteristics` (8) e
`0000000140025D68 Address of HMODULE` (16) não passam — e não uma lista de palavras em inglês, que é o
erro já pago duas vezes nesta casa em Windows pt-BR.

### 15.4 O ordinal: a frase estava no comentário do código, agora está medida

A alegação — um `.def` com `nome @37` faz o `lib /def:` produzir import **por ordinal**, e aí o
`dumpbin /imports` do exe imprime `Ordinal 167` sem nome nenhum, apagando a régua do §15.3 — vivia como
comentário. [`passo2a_ordinal_ab.bat`](../evidence/oraculo-nativo-22/passo2a_ordinal_ab.bat) a mede com
**uma** variável: o MESMO `bin\symbol_gate.obj`, os MESMOS quatro módulos, os MESMOS nomes, a MESMA linha
de `/DELAYLOAD`, a MESMA régua chamada duas vezes; muda só o `@n` dentro do `.def`. Saída de
[`passo2a_ordinal_ab.log`](../evidence/oraculo-nativo-22/passo2a_ordinal_ab.log):

```
[ab] linhas_com_palavra_ordinal A=37 B=0
[ab] regua_A_codigo=1
[ab] regua_B_codigo=0
[ab] OK: com `@n` a regua recusa (codigo 1); sem `@n` ela passa (codigo 0)
```

As 37 linhas com a palavra `Ordinal` na ponta A são os 37 nomes do gate perdendo o nome na tabela, e a
recusa da régua diz o motivo por todas as quatro pontas
([`passo2a_ordinal_ab.log:29-32`](../evidence/oraculo-nativo-22/passo2a_ordinal_ab.log)):
"a tabela nao mostrou NENHUM nome deste modulo; provavel import por ordinal". O `--ordinal` do gerador
existe **só** para essa corrida — o `build.bat` nunca o passa, e é por isso que a linha `[def]` do build
traz `remedio=sim` (linhas 13-21) enquanto o A/B, que roda sem `--runtime`, traz `remedio=nao`
([`passo2a_ordinal_ab.log:3-7`](../evidence/oraculo-nativo-22/passo2a_ordinal_ab.log)).

Um instrumento deste tamanho tem de dizer onde pisou: a primeira versão contava as linhas com
`find /c /v ""` e **varria o `C:` inteiro por dez minutos**, porque dentro da casca do vcvars o `find.exe`
que resolve é o GNU find do Git — o MSVC não tem `find`, e o vcvars prepõe as pastas dele sem tirar o
`usr\bin` do PATH. É o **furo #35 outra vez**, em outro nome de ferramenta; a contagem agora é python, e o
motivo está escrito no próprio `.bat`.

E o mesmo `.bat` trouxe o **furo #36** de volta por uma borda que nenhuma das três réguas vê. Escrito no
editor, ele saiu **LF** do disco — `tr -cd '\r' | wc -c` **0** em 136 linhas — enquanto
[`.gitattributes:22`](../../.gitattributes#L22) (`*.bat text eol=crlf`, que **vince** sobre o
`docs/evidence/** -text` de [:9](../../.gitattributes#L9): `git check-attr` no arquivo devolve `text: set`
e `eol: crlf`). Um `git add` aviso na hora: *"LF will be replaced by CRLF the next time Git touches it"*.
Como o manifesto se computa `sha256sum -b` sobre os bytes do disco (a regra do §12.4), o hash do `.bat`
não bateria em clone nenhum. O arquivo foi reescrito em CRLF e a A/B **re-executada a partir da forma
arquivada**: [`passo2a_ordinal_ab_rerun.log`](../evidence/oraculo-nativo-22/passo2a_ordinal_ab_rerun.log),
**47 linhas / 47 CR**, exit 0, e `diff` contra o log original — com os CRs das duas tirados — devolve
**vazio**, ou seja, `cmd.exe` leu as duas formas e o veredito do ordinal não dependeu do final de linha.
A régua não pegou isso porque ela confere ponteiro de documento, não bytes de checkout; quem pega é o
clone limpo do §11.4, e o aviso do `git add` veio antes dele.

### 15.5 A premissa do diretório do processo: FALSA, medida, e o gate recusou em vez de morrer

A corrida `nu` chama `LoadLibraryExA` pelo nome nu, com a flag da sonda de §1.2, e imprime o que o loader
devolve ([`passo2a_build.log:105-112`](../evidence/oraculo-nativo-22/passo2a_build.log)):

```
[premissa] nome_nu llama.dll handle=0000000000000000 erro=126
[premissa] veredito=FALSA o diretorio do processo nao ve o runtime por nome nu
[recusa] nu: sem nome nu resolvido nao ha o que chamar; rode `preload <runtime>`
[corrida] nu_codigo=5
```

O exe do gate mora em `native\af_mind\bin\` e o runtime em `.tools\llama\runtime\`; `erro=126`
(`ERROR_MOD_NOT_FOUND`) nos cinco nomes — as quatro DLLs do export-set mais o `libomp.dll` que elas
pedem. O `[exe] diretorio_do_processo=` impresso logo acima
([`:66`](../evidence/oraculo-nativo-22/passo2a_build.log)) é o que a frase do §5.1 dizia, lido do
processo, não da minha prosa. A corrida `preload <runtime>` abre os mesmos nomes **por caminho absoluto**
e então os números de §1.2 saem por nome, na mesma ordem
([`:170-180`](../evidence/oraculo-nativo-22/passo2a_build.log)): `load_all_from_path=0`, `reg_count=3`
(RPC, Vulkan, CPU), `dev_count=2` com `dev[0] type=1 nome=Vulkan0 desc=AMD Radeon RX 9060 XT` e
`vk_get_device_count=1`, e a linha `confronto_s1.2 ... veredito=IGUAL` com `preload_codigo=0`.

Duas consequências, ambas escritas **antes** do Passo 2 (b):

1. O `build.bat` aceita exit **0 ou 5** na corrida `nu`, e os dois são verdes por motivos diferentes: 0 é
   a premissa verdadeira, 5 é a premissa falsa **e o gate tendo recusado**. Um código de crash do loader
   não é nenhum dos dois e derruba o build. Corrida pulada não vira verde; corrida que morre também não.
2. A extensão **não pode** depender do diretório do processo. Em `Rodar.bat` o processo é o `Godot.exe` e
   as DLLs estão em `.tools\llama\runtime\`, então o Passo 2 (b) tem de ou pré-carregar o runtime por
   caminho absoluto (o delay-helper então resolve pelo nome-base já carregado) ou co-localizar as DLLs com
   a engine. É decisão com número, e o número é este: `erro=126` em cinco de cinco.

### 15.6 O controle negativo: LNK2019 nos quatro nomes e o exe que não nasceu

Quatro nomes que a documentação do prompt usava — `ggml_backend_buffer_type_get_base_buffer`,
`llama_model_n_ctx`, `llama_new_context_with_model`, `ggml_backend_buffer_type_get_alloc_size` — não
existem no export-set pinado (S1.3), e `symbol_gate_absent.cpp` os declara como dado e os usa num `main`
real, para que **só** o linker possa recusá-los. O controle é falsificável se ele não linkar
([`passo2a_build.log:182-188`](../evidence/oraculo-nativo-22/passo2a_build.log)):

```
[controle] cl_codigo=0
[controle] link_codigo=1120
[controle] llama_model_n_ctx recusa_lida=0
[controle] OK: o gate e falsificavel -- os quatro nomes foram recusados pelo linker
```

`link_codigo=1120` é LNK2019 em contagem não-zero, e o `findstr` por nome confirma que cada um dos quatro
aparece no texto da recusa ([`passo2a_gate_absent_link.txt`](../evidence/oraculo-nativo-22/passo2a_gate_absent_link.txt))
— um LNK1561 ou um LNK1181 daria não-zero pelo motivo errado e o controle pareceria ter funcionado. As
quatro linhas `LNK4199 /DELAYLOAD:... ignored; no imports found` no topo daquele arquivo não são um aviso
perdido: são a contraprova de que o controle **não resolve nada** de nenhum módulo, porque referencia só
os quatro nomes. E o `af_symbol_gate_absent.exe` não existe no disco, deletado antes do link para uma
corrida anterior não servir de testemunha a uma recusa atual.

### 15.7 O Passo 1 continua verde, e o que este passo não fecha

O critério de §5.2 inclui "o passo 1 continua verde", e as quatro corridas foram re-medidas **nesta**
árvore, depois de o `symbol_gate.cpp` ter mudado — número publicado é número medido na revisão (mandato 3,
item 6): suíte **255 checagens / 0 falhas / 49,3 s**
([`passo2a_suite.log`](../evidence/oraculo-nativo-22/passo2a_suite.log)), runner **288 / 0 / 34,032 s**
com as cinco `OK extensao_carrega_classe` nas linhas 535-539 do log e o rodapé de BT `trips=0`, RNG
**27 / 0 / 2,698 s** e journal **128 / 0 / 5,823 s**. O stderr da suíte é **249 bytes**
([`passo2a_suite.err`](../evidence/oraculo-nativo-22/passo2a_suite.err)) — o par de vazamento conhecido,
intermitente por medição, e nenhum dele menciona `af_mind`; o do runner é **0 bytes**.

Três `warning C4996` (`strncpy`, `_snprintf`, `strcpy`) apareciam no log da primeira corrida do gate. Eles
foram **consertados na causa**, não silenciados: `_CRT_SECURE_NO_WARNINGS` é um silenciar, e um warning
dentro de um log verde é o instrumento pedindo para não ser lido. As três chamadas viraram `strcpy_s` e
`snprintf` com o mesmo comportamento e o mesmo `gate_exe_bytes=157696`, e a contagem de warnings no log
arquivado é **0**.

O que este passo **não** fecha:

- **Os três números de §5.2 não existem ainda.** `af_vram_gb`, `af_load_ms` e `af_ctx_cells` são o Passo 2
  (b), e o §15.5 já decidiu como ele tem de alcançar o runtime. Nenhum número de VRAM foi medido aqui.
- **A extensão não encosta no runtime.** `AfMindOracle` continua com construtor, destruidor e marker
  (Passo 1); o que este passo produziu é um **exe de gate**, não um binding.
- **`src/` intocado**, com a régua em `git diff --name-only main...HEAD -- src` devolvendo **vazio**, e
  `Channel.COUNT`, `FORMAT_VERSION` e `GEN_VERSION` parados — logo os hashes de journal publicados valem
  para a árvore resultante, sem re-corrida.
- **Nenhum gate de fase** (mandato 4), e os furos **#38, #39 e #20** continuam exatamente onde estavam: o
  primeiro é decisão do dono, o segundo é o limite das réguas, o terceiro é a colheita que falta.


## 16. O Passo 2 (b): o pack dentro do processo, os três números lidos do runtime, e a prova de layout que quase ficou inatingível

O critério de §5.2 — o jogo abre com a cena de prova, o processo não morre, os três números saem, e o
passo 1 continua verde — fechou na árvore desta branch
(`feat/oraculo-nativo-passo2b-22`): a rota completa do §15.5 (preload por caminho absoluto → pack vazio
como base → `.gguf` → contexto só na sonda) roda dentro do processo da engine por `AfMindOracle`, o
probe `af_pack_probe` confirma a mesma rota de pe **antes** do Godot, e os três números saem nos dois.
Duas corridas anteriores desta mesma perna são evidência também — e as duas são instrumento, não festa.

### 16.1 A primeira corrida caiu `0xC0000005`, e foi a assinatura, não o runtime

O stdout da primeira corrida do probe rota termina no `[pack] arquivo=...bytes_no_disco=2740937888`, sem
nenhum `[numero]`; o stderr termina nos `load_tensors`, com os 33/33 layers offloaded para a GPU e o
`Vulkan0 model buffer size = 2603.50 MiB` já escrito
([`passo2b_probe_crash.log`](../evidence/oraculo-nativo-22/passo2b_probe_crash.log)). O modelo carregou;
a queda veio **depois** do load, na linha do descritor: `llama_model_desc` tinha sido declarada com
argumentos trocados, e o callee leu RDX como ponteiro de buffer do chamador. `llama_version` tinha o
mesmo defeito de lado — a sonda leu `-1926548272` onde devia ler uma string — porque a função do runtime
devolve `const char *` e não um inteiro. As duas assinaturas foram re-auditadas contra o `llama.h` do
pin b12499 e corrigidas em [`mind_pack.cpp`](../../native/af_mind/src/mind_pack.cpp); a build seguinte
imprime `llama_version=1.0.0-dev` ([`passo2b_build.log:202`](../evidence/oraculo-nativo-22/passo2b_build.log)).

### 16.2 O achado: build verde, exit 0, e uma prova de layout que não podia passar

A segunda build compilou, linkou, passou as duas corridas da régua de imports e **saiu 0** — com o
veredito `NAO_CONFIRMADA` na mesma linha
([`passo2b_build_inatingivel.log`](../evidence/oraculo-nativo-22/passo2b_build_inatingivel.log)):

```
[ctx] word0_default=512 estado=4
[ctx] probe=0 pedido=2048 lido=512 n_batch=512 n_ubatch=512
[ctx] ctx_cells=512 state_bytes=606 veredito=NAO_CONFIRMADA
```

O motivo é do design, não do runtime: o **load** criava o contexto default (512 células) antes da
sonda, então `af_pack_ctx_probe(2048)` caía no "já medido", o pedido 2048 nunca chegou ao runtime, e a
afirmação de layout (primeira palavra do blob de params de contexto = `n_ctx`) ficou **inatingível** sob
um exit 0. Um `[numero]` com `NAO_CONFIRMADA` e código 0 não é número publicado — é o instrumento
dizendo que a prova dele não pôde acontecer. O conserto tirou a criação de contexto do load de vez:
`af_pack_ctx_probe` é o **único** contexto do processo (a rota de
[`mind_pack.h`](../../native/af_mind/src/mind_pack.h), passo 4), `guarda_do_contexto` saiu da árvore, e
a observação do default virou só leitura — `[ctx] word0_default=512 estado=3` na build final
([`passo2b_build.log:214`](../evidence/oraculo-nativo-22/passo2b_build.log)): o runtime **reporta** 512,
e nada é alocado com ele.

A segunda metade do achado é o código de saída, e ela fechou com a regra do próprio achado: um veredito
sob exit 0 não é número publicado. O `af_pack_probe` recusa com **exit 8** quando o runtime **aceita** o
contexto mas devolve outro `n_ctx` — a afirmação de layout caiu, os `[numero]` saem para o leitor e o
build **não** segue para o dll; o `build.bat` nomeia o exit 8 na recusa, junto do exit 7 que já dizia
"não cabe, `[OPEN]`". A corrida final da mesma árvore sai `ESCRITA_CONFIRMADA_PELO_RUNTIME` com exit 0
([`passo2b_build.log:216`](../evidence/oraculo-nativo-22/passo2b_build.log)), e os números abaixo são
dessa corrida.

### 16.3 A rota executada, com os três números

A build final executa as duas pontas no mesmo log
([`passo2b_build.log`](../evidence/oraculo-nativo-22/passo2b_build.log)). O controle de recusa continua
de pé (`probe_recusa_codigo=9`, `RECUSOU_SEM_TOCAR_O_RUNTIME`, [:186-193](../evidence/oraculo-nativo-22/passo2b_build.log)), e a rota
sai completa: `preload=5` pelo caminho absoluto
([:199](../evidence/oraculo-nativo-22/passo2b_build.log)), pack vazio abrindo a base
([:204](../evidence/oraculo-nativo-22/passo2b_build.log)), o `.gguf` entrando
([:206](../evidence/oraculo-nativo-22/passo2b_build.log)), e o confronto de layout que a 16.2 deixou
inatingível agora passa
([:215-216](../evidence/oraculo-nativo-22/passo2b_build.log)):

```
[ctx] probe=0 pedido=2048 lido=2048 n_batch=2048 n_ubatch=512
[ctx] ctx_cells=2048 state_bytes=606 veredito=ESCRITA_CONFIRMADA_PELO_RUNTIME
```

Os três números do §5.2, lidos do runtime e não de documentação
([:220-226](../evidence/oraculo-nativo-22/passo2b_build.log)):

| Grandeza | Valor medido | Linha |
| --- | --- | --- |
| `af_vram_gb` — base (pack vazio) | **0,838 GB** (900 079 760 B) | [:204](../evidence/oraculo-nativo-22/passo2b_build.log) |
| `af_vram_gb` — depois do load | **3,381 GB** (3 630 637 200 B; Δ 2,543 GB) | [:220](../evidence/oraculo-nativo-22/passo2b_build.log), [:222](../evidence/oraculo-nativo-22/passo2b_build.log) |
| `af_vram_gb` — depois do contexto | **3,988 GB** (4 282 327 184 B; Δ 0,607 GB) | idem |
| `af_load_ms` | **2 057 ms** no probe (1 939 na corrida do runner desta revisão — cache frio/quente) | [:223](../evidence/oraculo-nativo-22/passo2b_build.log), [`passo2b_runner.log:544`](../evidence/oraculo-nativo-22/passo2b_runner.log) |
| `af_ctx_cells` — lido do modelo | **2 048** (o pedido escrito; `ctx_train` 262 144 = meta `qwen35.context_length` do `.gguf`) | [:224](../evidence/oraculo-nativo-22/passo2b_build.log), [:212](../evidence/oraculo-nativo-22/passo2b_build.log) |

As testemunhas ao redor, todas do mesmo log: `vram_total=17095983104` (RX 9060 XT, 16 GB),
`estado=3` após o load e `estado=4` após o probe, `state_bytes=606` (0,3 B por célula, [:225](../evidence/oraculo-nativo-22/passo2b_build.log)),
RSS do SO no passo do contexto **0,026 GB** ([passo2b_build.log:226](../evidence/oraculo-nativo-22/passo2b_build.log)) —
a testemunha de que o contexto morou na VRAM, não no heap —, `offloaded 33/33 layers to GPU` com
`Vulkan0 compute buffer size = 507.02 MiB` no stderr da corrida, `model_bytes=2729969664` contra
2 740 937 888 no disco (a diferença é metadado; impressa, não afirmada), e `ctx_size_pedido_por_fora=4096`
([:227](../evidence/oraculo-nativo-22/passo2b_build.log), o `--ctx-size` do host) `identico_ao_lido=nao` — o número
lido **não** é confundível com o pedido por fora.

### 16.4 O gate do runner: oito checagens, censo 296, e a lição do `rss_antes`

A checagem nova é [`_test_extensao_pack_no_processo`](../../tests/aether_reactions_test.gd) — oito
verificações, cada uma nomeando a premissa que exige e imprimindo o número que a decide
([`passo2b_runner.log:540-547`](../evidence/oraculo-nativo-22/passo2b_runner.log)): runtime e modelo no
disco (com o caminho impresso — num clone sem eles, ambos gitignored, as oito nascem vermelhas com o
motivo, não com um número chutado); pack vazio abrindo a base por caminho absoluto (`modulos=5`,
`estado=2`); base honesta (`vram_used == vram_base`); o `.gguf` entrando com o RSS do SO crescendo
(174 813 184 → 3 556 532 224); a leitura conferindo com a meta do próprio modelo (`ctx_train ==
int(meta_ctx)`); o runtime confirmando o contexto pedido por escrito (`probe2048=0 lido=2048`); e os
três números do §5.2 na ordem que decide (`base < depois do load < depois do contexto`). O censo sobe
288 → **296**, o rodapé sai **296 checagens 0 falhas 44,648 s** com `67/67` testes completos e
`trips=0`, e o passo 1 continua verde — as cinco `extensao_carrega_classe` seguem OK
([`passo2b_runner.log:535-539`](../evidence/oraculo-nativo-22/passo2b_runner.log)).

A primeira corrida do runner ensinou a ordem de leitura, e a lição está escrita no próprio teste: os
dois RSS são **grandezas capturadas pelo load** (o SO, sobre o mesmo instante, antes e depois de
mapear), não leituras vivas — ler `rss_antes_bytes()` **antes** do `load_pack` devolve o `-1` da
inicialização, e a linha saía `rss_antes=-1 rss_apos=3582414848`: vermelho disfarçado de testemunha.
Lidos depois da chamada, o par impresso é o par que o load capturou
([passo2b_runner.log:544](../evidence/oraculo-nativo-22/passo2b_runner.log)).

As quatro corridas da revisão, todas nesta árvore: runner **296 / 0 / 44,648 s**
([`passo2b_runner.log`](../evidence/oraculo-nativo-22/passo2b_runner.log)), suíte **255 / 0 / 51,0 s**
([`passo2b_suite.log`](../evidence/oraculo-nativo-22/passo2b_suite.log)), RNG **27 / 0 / 2,895 s**
([`passo2b_rng.log`](../evidence/oraculo-nativo-22/passo2b_rng.log)) e journal **128 / 0 / 6,182 s**
([`passo2b_journal.log`](../evidence/oraculo-nativo-22/passo2b_journal.log)) — os dois `.err` dos
portões curtos são vazios, e nenhum `SCRIPT ERROR` aparece em log nenhum.

### 16.5 O que este passo não fecha

- **Não há API de prompt ainda** (§5.3 é o Passo 3): `enqueue`, `wait`, sinais e métricas de fila não
  existem, e `mind_oracle.gd` continua falando HTTP. O `load_pack` desta perna é a rota de carga
  medida, não o transporte de inferência.
- **`src/` intocado**, com a régua em `git diff --name-only main...HEAD -- src` devolvendo **vazio**, e
  `Channel.COUNT`, `FORMAT_VERSION` e `GEN_VERSION` parados — os hashes de journal publicados valem
  para a árvore resultante, sem re-corrida.
- **Nenhum gate de fase** (mandato 4), e os furos **#38, #39 e #20** seguem onde estavam. A premissa do
  diretório do processo continua FALSA (§15.5) — e agora com a consequência exercitada: todo acesso ao
  runtime dentro do processo passa por `set_runtime_dir` com caminho absoluto, cinco de cinco.
- O contexto medido é o **custo** (0,607 GB por 2 048 células), não a escolha do tamanho de produção:
  o `--ctx-size` do host segue 4096 até o Passo 3 decidir o que a fila de prompts pede.

## 17. O Passo 3: a API do prompt dentro do processo, a ponte de Variant cru, e o gate que compara forma — não frase

O critério de §5.3 fechou na árvore desta branch (`feat/oraculo-nativo-passo3-22`): `enqueue`, `wait`,
métricas de fila e os três sinais existem na `AfMindOracle` pela rota ClassDB, o `.gguf` decodou duas
narrativas **dentro do processo do Godot** sem tocar rede, e o gate
[`contrato_igal_ao_http`](../../tests/aether_reactions_test.gd) compara a **forma** da saída das duas
transportas — HTTP e extensão — sobre o mesmo roster, porque frase é do modelo, não do transporte. O
censo do runner sobe 296 → **318**. Três commits, um assunto cada.

### 17.1 Os três commits, com o número de cada árvore

- **(a) [`8dbc978`] a fila de prompts na porta C++** (`mind_prompt.cpp`): `enqueue`/`wait` com recusas
  **nomeadas na porta** — papel fora do mapeamento devolve `-4`
  (`enqueue: papel cozinheiro fora do mapeamento user/system`), campo fora do tipo devolve `-2`
  (`max_tokens 4096 passa do teto de 256`),
  [:232-234](../evidence/oraculo-nativo-22/passo3_build.log) —, timeout preservando o slot na fila
  ([passo3_build.log:235](../evidence/oraculo-nativo-22/passo3_build.log)) e **duas narrativas reais
  decodadas** por `ROTA_DE_PROMPT_CONFIRMADA`
  ([passo3_build.log:236-239](../evidence/oraculo-nativo-22/passo3_build.log)). Tudo de pé na sonda
  **antes** de o dll nascer, como o passo 2 (b) ensinou. Corridas da árvore: runner
  **296 / 0 / 37,480 s** ([passo3_runner_commit_a.log:576](../evidence/oraculo-nativo-22/passo3_runner_commit_a.log))
  e suíte **255 / 0 / 50,5 s** ([passo3_suite_commit_a.log:357](../evidence/oraculo-nativo-22/passo3_suite_commit_a.log)).
- **(b) [`11d13bb`] a ponte no GDScript**: `enqueue`/`wait`/métricas na `AfMindOracle` pela rota
  **Variant crua** — leitura de dicionário pelo getter por chave do cabeçalho vendorado, montagem pelo
  construtor por ponteiro + setter por ponteiro, **nenhum layout de Variant ou de Dictionary suposto**
  (o comentário de [`register_types.cpp`](../../native/af_mind/src/register_types.cpp) é o contrato);
  a régua de imports fecha com os **55 nomes** do corpo na tabela do dll, 4 módulos, e os controles
  negativos ausentes ([passo3_build_ponte_verde.log:248-253](../evidence/oraculo-nativo-22/passo3_build_ponte_verde.log)).
  Corridas: runner **296 / 0 / 37,689 s**
  ([passo3_runner_commit_b.log:576](../evidence/oraculo-nativo-22/passo3_runner_commit_b.log)),
  suíte **255 / 0 / 50,8 s**
  ([passo3_suite_commit_b.log:357](../evidence/oraculo-nativo-22/passo3_suite_commit_b.log)).
- **(c) [`e8301c0`] o gate e os dois consertos que o gate cobrou** — §17.2 e §17.3 abaixo. Runner
  **318 / 0 / 46,034 s** ([passo3_runner_commit_c.log:576](../evidence/oraculo-nativo-22/passo3_runner_commit_c.log)),
  suíte **255 / 0**, e a build final sai `ROTA_DE_PROMPT_CONFIRMADA` com exit 0 e dll
  `938e60f3a0e60bd17511198ee10810af477a5a52827b8926b8089faaf5f3f219`
  ([passo3_build_ponte_verde.log:239](../evidence/oraculo-nativo-22/passo3_build_ponte_verde.log),
  [:258](../evidence/oraculo-nativo-22/passo3_build_ponte_verde.log)).

### 17.2 O sinal 11, fechado na causa: o getter da engine **atribui** no destino

Duas corridas do runner caíram com signal 11 dentro do `enqueue` — não sempre, e o repro v2 com o mesmo
shape não reproduzia. A causa lida do protocolo do cabeçalho vendorado: o getter **por chave** e o
**por índice** da engine não escrevem em campo novo — eles **atribuem** no destino (semântica de
`operator=`, que lê o `type` **antes** de copiar). Nossos storages eram bytes crus de stack sem
inicializar: lixo de stack com um `type` que carrega ponteiro manda a engine rodar o `clear()` de um
tipo qualquer sobre memória qualquer — corrupção de heap com as quatro molduras de `ntdll`, caindo no
primeiro get de cada `enqueue`. O repro não reproduzia porque as páginas de stack novas dele estavam
zeradas (lixo benigno); a pressão do gate — dicionários de 24 chaves e strings de 60 caracteres entre
os enqueues — deixa o mesmo padrão de tamanho sujo, e é essa pressão que o repro v3 copia.

O conserto é o protocolo de teardown completo, no corpo de
[`register_types.cpp`](../../native/af_mind/src/register_types.cpp): `variant_destroy` entra na lista
de procedimentos carregados e null-checked, e todo storage cru passa por um dos dois ajudantes —
`inicia_varianto` (NIL **válido** antes da primeira escrita de qualquer getter) e `destroi_varianto`
(destrutor real + NIL de novo, porque `variant_new_nil` sobre storage viva vazaria a referência). A
mesma leitura fechou uma segunda classe de defeito que ninguém tinha contado: os storages de `String`
de argumento e de retorno vazavam a referência em ambos os caminhos — agora fecham com destrutor nos
dois. A prova de causa é o par arquivado: o repro v3 sob a pressão do gate roda **exit 0** com dez
enqueues, churning entre eles, recusas nomeadas e dois decodes reais
([passo3_minrepro3.log:18](../evidence/oraculo-nativo-22/passo3_minrepro3.log)), e o runner com o gate
inteiro sai 318/0 —
[passo3_runner_commit_c.log](../evidence/oraculo-nativo-22/passo3_runner_commit_c.log),
[passo3_gates_runner.log](../evidence/oraculo-nativo-22/passo3_gates_runner.log) — onde as duas
primeiras corridas caíam.

### 17.3 O `tokens_out` que ninguém tinha lido até o repro

O mesmo repro encontrou o segundo defeito antes de o gate nascer: `tokens_out` chegava ao GDScript com
o decode **certo** e o número **errado** — o v3 mediu `tokens_out=3066606649375`. O construtor de INT
lê um **int64 inteiro** do ponteiro de origem; um `int32_t*` passado direto deixa lixo de stack na
metade alta. O conserto dá largura nomeada a cada grandeza que cruza a ponte
([`register_types.cpp`](../../native/af_mind/src/register_types.cpp), `int64_t tokens_out64 =
tokens_out;`), e a mesma régua do repro devolve inteiros limpos — `tokens_out=31` e `tokens_out=26`
nos dois waits reais ([passo3_minrepro3.log:15-16](../evidence/oraculo-nativo-22/passo3_minrepro3.log)).
A classe fica nomeada na fonte: **toda grandeza que cruza a ponte entra como int64 de largura
escrita**, não como o `sizeof` de quem passa.

### 17.4 O gate `contrato_igal_ao_http`: 22 checagens, forma contra forma

A checagem nova é
[`_test_contrato_igal_ao_http`](../../tests/aether_reactions_test.gd) — o roster de §5.3 rodado duas
vezes sobre o mesmo cenário: uma com o transporte de rede (`llama-server` levantado por lançamento
próprio, porta 8791, chave do arquivo — o pid **exato** do lançamento é o único que o desmanche derruba:
`pid=27352 derrubado=true reuso=false`,
[passo3_runner_commit_c.log:550](../evidence/oraculo-nativo-22/passo3_runner_commit_c.log),
[:569](../evidence/oraculo-nativo-22/passo3_runner_commit_c.log)) e uma com a extensão. O que se
compara é **forma**, não frase — e as 22 checagens imprimem o número que decide cada uma
([passo3_runner_commit_c.log:548-569](../evidence/oraculo-nativo-22/passo3_runner_commit_c.log)):

| Checagem | O número que decide |
| --- | --- |
| o oráculo HTTP lê a MESMA chave que subiu o servidor | `len_oraculo=32 len_host=32 fonte=arquivo` — comprimento, nunca a chave |
| FORMA do sucesso HTTP × FORMA do wait da extensão | os **seis** mesmo nomes de chave, `status=0`, `tokens_out=64`, `reason=''` — `textos=143/144 chars` |
| FORMA da recusa nas duas transportas | `reason` não vazio nomeando o motivo, `status_ext=-2` para id desconhecido |
| recusas nomeadas na porta do prompt | `max_tokens` errado → `-2`; papel fora do mapeamento → `-4` |
| timeout preserva o slot | `status=1 reason='timeout de 1 ms' depth=1`, e o pedido completa no wait seguinte (`status=0 tokens_out=64`) |
| os três sinais de §5.3 existem na ClassDB | `["script_changed", "property_list_changed", "inference_completed", "pack_loaded", "pack_failed"]` |
| métricas honestas da fila | `depth=0 hits=0 misses=2 worst_decode_us=1510272 vram_bytes=7017017488` — cache **não existe** no Passo 3, e o getter diz isso |

A emissão do sinal segue **`[ABERTA]`** — `emissoes=0 decodes=2`
([passo3_runner_commit_c.log:564](../evidence/oraculo-nativo-22/passo3_runner_commit_c.log)): quem
emite `inference_completed` é o Passo 4/5, e o gate que fecha essa parte está nomeado lá, não aqui.

### 17.5 O que este passo não fecha

- **`mind_oracle.gd` continua HTTP** — o Passo 4 (`transporte_http_zerado`:
  `grep -rn HTTPRequest src` vazio, `Rodar.bat` sem processo de IA) é quem troca o transporte e apaga o
  host da árvore. Nada do jogo leu a extensão ainda: a ponte existe, o consumidor não.
- **Cache e validador** são o Passo 5 (§5.5); as métricas do gate contam fila, não cache.
- **`src/` intocado** — `git diff --name-only main...HEAD -- src` devolve **vazio** — e
  `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` parados: os hashes de journal publicados valem para
  a árvore resultante, sem re-corrida.
- **Nenhum gate de fase** (mandato 4); os furos **#38, #39 e #20** seguem onde estavam, e o desmanche
  do servidor de teste não é o desmanche do hospedeiro do jogo (o `llm_server_host.gd` continua dono do
  processo dele até o Passo 4).

## 18. O Passo 4: o transporte HTTP sai de `src`, o pack ganha dono no processo, e o gate varre a árvore

Branch `feat/oraculo-nativo-passo4-22`, base `74820e7`; dois commits: o gate vermelho `ba8ee22` e a
mudança `5138549`. O que a seção §5.4 (`transporte_http_zerado`) promete aqui se paga com número:
`grep -rn HTTPRequest src` devolve **vazio** no fim do passo, e o §6.3 do dossiê 15 — o hospedeiro do
modelo como dono do ciclo de vida — é reescrito sobre disco e ClassDB, sem processo filho, sem porta,
sem vigia e sem kill. Nada do jogo leu uma decisão do oráculo antes ou depois: a narrativa continua a
única saída, e a mente propõe, as regras dispõem.

### 18.1 O gate nasce vermelho com as 9 ocorrências impressas

`transporte_http_zerado` são duas checagens no runner: a varredura recursiva de `src/` por
`HTTPRequest` (32 arquivos lidos) e a dos lançadores (`Rodar.bat`, `tools/run_game.ps1` sem citação
de llama). No commit (a), antes de qualquer linha de mudança, a primeira imprime as **9 ocorrências
nos 2 arquivos** — `llm_server_host.gd:87/:99` e seis em `mind_oracle.gd` — e o runner fecha
**320 checagens 1 falhas 43,384 s** ([passo4_runner_gate_vermelho.log:572](../evidence/oraculo-nativo-passo4-22/passo4_runner_gate_vermelho.log#L572),
veredicto em [:580](../evidence/oraculo-nativo-passo4-22/passo4_runner_gate_vermelho.log#L580)). A
checagem dos lançadores já passava **no vermelho**: eles nunca citaram llama — quem subia o processo
era o `llm_server_host.gd` dentro do jogo, e é por isso que o §6.3 mora em `src/ai/`, não no
launcher.

### 18.2 O wrapper: `enqueue` + `wait(id, 0)` por frame, e o portão que ficou

`mind_oracle.gd` perde o nó HTTP e fala com a ponte nativa: `_ext.enqueue`
([mind_oracle.gd:121](../../src/ai/mind_oracle.gd#L121)) e o `wait(id, 0)` por frame
([:139](../../src/ai/mind_oracle.gd#L139)) — timeout zero, consulta não bloqueante, status 1
preserva o slot (contrato do `mind_prompt.h`), e nenhum `await` pendura os 50 ms do tick. O que
fica do §2.1: agendamento por frame, round-robin pela matilha, prompt dobrado numa mensagem só,
recusas nomeadas, recuo cheio de 30 s ([`RETRY_COOLDOWN` :24](../../src/ai/mind_oracle.gd#L24)) e a
chave externa `KEY_ENV`/`KEY_FILE` (`5138549:src/ai/mind_oracle.gd:31`) — quem sobe um
`llama-server` na mão lê as mesmas duas fontes. O que morre: o `LOADING_COOLDOWN` do `503`, porque a
espera pelo modelo deixa de ser transporte e passa a ser o portão `ready_provider`, ligado ao
`AfMindRuntime.ready()` ([af_mind_runtime.gd:68](../../src/ai/af_mind_runtime.gd#L68)) em
[main.gd:257](../../src/main.gd#L257). Num clone sem o dll gitignored, `_ext` nasce null e cada
pedido nomeia a ausência — o degradado continua checado pela suíte, agora com o motivo da fila:
"runtime sem pack nao emite chamada na ponte"
([smoke_test.gd:2539](../../tests/smoke_test.gd#L2539)) e as duas checagens da recusa que nomeia o
motivo e arma o recuo cheio ([:2558-2562](../../tests/smoke_test.gd#L2558-L2562)).

### 18.3 O `AfMindRuntime`: ciclo do pack sobre disco e ClassDB, sem processo filho, sem porta

`src/ai/af_mind_runtime.gd` é o dono do ciclo de vida do pack dentro do processo: estados da matriz
de falha nomeados sobre disco e ClassDB
([af_mind_runtime.gd:21](../../src/ai/af_mind_runtime.gd#L21) em diante — ocioso, ausente
(extensão/runtime/modelo), carregando, pronto, desligado), um passo por frame com
`STEP_PERIOD = 1.0` ([:32](../../src/ai/af_mind_runtime.gd#L32), precedente do teto de 1 s do
`CORPSE_CHECK`) para o F3 acompanhar o carregamento em vez de congelar em silêncio, e as métricas
que a ponte mede lidas por ele. Com o transporte saem da árvore `llm_server_host.gd` (433 linhas),
o processo filho, a sonda de porta, o vigia e os dois kills; a sonda da perna 15
(`tests/llm_server_boot_probe`) aposenta junto, e a metade HTTP do gate `contrato_igal_ao_http`
vira **cliente de referência dentro do runner** — as 17 ocorrências de `HTTPRequest` que sobram
vivem em `tests/aether_reactions_test.gd`, e o grep do gate mira só `src/`. A fiação em `main.gd`:
`llm_host` agora é `AfMindRuntime` ([main.gd:55](../../src/main.gd#L55)), o `diagnostics()` mantém
a chave `"llm"` ([main.gd:1214](../../src/main.gd#L1214)) e o F3 lê a linha de status por
`llm_status_provider` ([main.gd:259](../../src/main.gd#L259)), que junta estado, contexto,
`load_ms`, VRAM e o `last_reason` do oráculo
([af_mind_runtime.gd:85-87](../../src/ai/af_mind_runtime.gd#L85-L87)) — leitura, nenhuma escrita,
mandato 2 intacto.

O custo que o passo assume: o `load_pack` do gguf é chamada síncrona da extensão e o frame que a
executa trava o tempo do load — o `open_ms` que a ponte mede
([af_mind_runtime.gd:163](../../src/ai/af_mind_runtime.gd#L163)). O overlap que o processo filho
dava com a geração acabou; o regresso é registrado como o **furo #46**, não escondido.

### 18.4 Os quatro verdes na ponta

Suíte **264 checagens / 0 falhas / 52,5 s**
([passo4_suite.log:380](../evidence/oraculo-nativo-passo4-22/passo4_suite.log#L380)); runner
**320 / 0 / 42,770 s** com as duas linhas `OK transporte_http_zerado` — grep vazio
(`arquivos_lidos=32 ocorrencias=0`) e lançadores sem llama
([passo4_runner_verde.log:572-573](../evidence/oraculo-nativo-passo4-22/passo4_runner_verde.log#L572-L573),
veredicto em [:580](../evidence/oraculo-nativo-passo4-22/passo4_runner_verde.log#L580)); RNG
**27 / 0 / 2,718 s** ([passo4_rng.log:80](../evidence/oraculo-nativo-passo4-22/passo4_rng.log#L80));
journal **128 / 0 / 5,843 s**, "7/7 testes concluidos"
([passo4_journal.log:145](../evidence/oraculo-nativo-passo4-22/passo4_journal.log#L145)).

### 18.5 O que este passo não fecha

- **O Passo 5** (§5.5) — cache, validador de crença e a régua do budget — continua pauta da perna,
  cada peça com gate próprio; as métricas do gate contam fila, não cache.
- **`src/` se move pela primeira vez na perna** — a árvore resultante é outra revisão; os números
  desta seção valem para a ponta `5138549`, e o pouso re-mede na mergida e no clone limpo (mandato 3,
  item 6). `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a projeção do `TickJournal` não foram
  tocados, e a narrativa não entra na projeção.
- **Furo #46** — a travada do frame que executa o `load_pack` síncrono — fica aberto, dono Passo 5.
- **Nenhum gate de fase** (mandato 4); os furos **#38, #39, #20, #31, #41, #44 e #45** seguem onde
  estavam.
## 19. O Passo 5: a cache de conteúdo, o portão do verificador, e a régua do budget que mediu antes de cortar

### 19.1 Os gates nascem vermelhos, e o vermelho já traz a régua do budget

Commit **e7e2d59** nasce com as duas checagens de abertura do §5.5 vermelhas na mesma corrida:
a cache não existe (`FALHA af_cache_determina_replay: a cache ficou em arquivo separado do save |
caminho=user://oracle_cache_passo5.json existe=false` em
[:576](../evidence/oraculo-nativo-passo5-22/passo5_runner_vermelho.log#L576)) e a segunda corrida paga o
decode de novo (`pedidos_b=1` em
[:577](../evidence/oraculo-nativo-passo5-22/passo5_runner_vermelho.log#L577) — o sampler greedy já
devolve a mesma frase; o que a cache §6.5 compra é o replay **sem modelo**), e o verificador nomeado
não está em `src/ai` (`existe=false` em
[:578](../evidence/oraculo-nativo-passo5-22/passo5_runner_vermelho.log#L578)). Runner **331 checagens 3
falhas 49,079 s**; suíte 264/0/52,7 s. A régua do budget mede **no vermelho**, antes de qualquer
corte — a disciplina do §5.5: `worst_sim_ms=12.75 ms pico_do_passo=12 750 µs media=2 389,1 µs/passo`
com o decode em voo dentro da malha de 1 400 passos
([:589](../evidence/oraculo-nativo-passo5-22/passo5_runner_vermelho.log#L589)).

### 19.2 A cache: chave de conteúdo, arquivo separado do save, opt-in por CLI

Commit **5b06f51** fecha `af_cache_determina_replay` **verde** (runner 332/1 — a falha restante é a
do verificador, que fecha no commit seguinte): a chave é `prompt|pack|max_tokens|temperature` com as
constantes nomeadas (`PROMPT_MAX_TOKENS`/`PROMPT_TEMPERATURE`) e é **estável entre as corridas**
(`prompt_a=315 chars prompt_b=315 chars iguais=true`); a corrida A alimenta o arquivo separado do
save (`frase_a=143 chars pedidos=1 status=0`); uma instância **fresca** lê a frase do arquivo pela
chave reconstruída de fora (`chave=4b4158c18aef447d lida=143 chars entradas=1`); a segunda semente
devolve a mesma frase **sem consultar a fila** (`pedidos_b=0 acertos_cache=1`) — o vermelho imprimiu
`pedidos_b=1` e o verde zero, que é exatamente a diferença entre "o modelo responde igual" e "a
cache responde sem modelo" (§7.3). O arquivo JSON carrega número de versão e recusa nomeada — o
cuidado do `FORMAT_VERSION` em escala de cache — e narrativa recusada ou vazia nunca entra. Cache é
**opt-in** via `--oracle-cache=` no padrão da casa do `--tick-journal=`: sem a flag, `_cache` é null
e o custo por frame é zero.

### 19.3 O portão do verificador: "a mente propõe" deixa de ser ausência de caminho

Commit **824445e** fecha `verifier_recusa_id_forjado` **verde**: o verificador nomeado existe na
fronteira da Camada 5 (`res://src/ai/belief_verifier.gd existe=true`) e o **portão único**
(`MindOracle.aceitar_saida` — a única rota de escrita que o `_poll` passa a usar) recusa a saída que
cita id que não existe na alcateia, com o motivo nomeado (`verificador recusou a saida: id 999
citado nao existe na alcateia`); o controle, que só cita id do roster, entra pelo mesmo portão com
narrativa e sinal. Fail closed com roster vazio. A Fase 2 (§5.6) expande o **mesmo portão** para os
ids do ledger sem mudar quem chama. No mesmo lote, a régua do budget re-mede verde com o portão no
caminho (`worst_sim_ms=13.09 ms pico=13 094 µs trips=0→0`).

### 19.4 As métricas do §2.4 no F3 e o fecho

Commit **1b5ff5f**: a linha de pronto do F3 ganha `fila %d  decode %d us  cache %d/%d` lidos da
ponte (`_ponte()` + `_int_de()`, com `-1` como número ausente **nomeado** sem ponte — nunca um 0 que
parece leitura, §7.2), e `diagnostics()` expõe `queue_depth`/`worst_decode_us`/`cache_hits`/
`cache_misses`. As quatro corridas na ponta: suíte **266/0/52,7 s** (264 + as duas checagens novas do
F3), runner **336/0/47,970 s**, RNG **27/0/2,708 s**, journal **128/0/5,766 s**; zero `SCRIPT ERROR`
nas quatro. Os três gates do passo no runner: as sete de `af_cache_determina_replay`
([:572-578](../evidence/oraculo-nativo-passo5-22/passo5_runner_f3.log#L572-L578)), as cinco de
`verifier_recusa_id_forjado`
([:579-583](../evidence/oraculo-nativo-passo5-22/passo5_runner_f3.log#L579-L583)) e as quatro de
`budget_do_oraculo_nao_estoura_a_arvore`
([:592-595](../evidence/oraculo-nativo-passo5-22/passo5_runner_f3.log#L592-L595)), com o veredito
`worst_sim_ms=12.87 ms pico_do_passo=12 873 µs trips_antes=0 trips_depois=0`.

### 19.5 O que este passo não fecha

O **furo #46** (o `load_pack` síncrono trava o frame do load) foi avaliado neste passo e fica em
pé com motivo nomeado: o conserto pede carga assíncrona do lado da extensão — uma segunda fila de
trabalho dentro da ponte com progresso legível — e o ganho dele é só no boot (o load acontece uma
vez por processo, e o passo 2 (b) mediu o custo inteiro na mesa); a fila do oráculo já entrega
decode não-bloqueante no tick, que era o caminho quente real. O trabalho de ponte entra na Fase 4
(LOD e orçamento), onde o governor precisa de carga assíncrona de qualquer forma. Nenhum gate de
fase fecha aqui; `Channel.COUNT`, `FORMAT_VERSION`, `GEN_VERSION` e a projeção do `TickJournal`
não foram tocados por nenhum commit deste passo.
