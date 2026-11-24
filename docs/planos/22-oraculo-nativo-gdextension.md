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

Nada disso é hipótese; os números abaixo são `grep -rn` desta árvore em `HEAD`.

### 2.1 `src/ai/mind_oracle.gd` — 264 linhas, e o transporte está em quatro lugares

| Papel | Onde |
|---|---|
| o nó de transporte | [`:42`](../../src/ai/mind_oracle.gd#L42) `var _http: HTTPRequest = null`, criado em [`:62`](../../src/ai/mind_oracle.gd#L62), timeout em [`:64`](../../src/ai/mind_oracle.gd#L64), conectado em [`:66`](../../src/ai/mind_oracle.gd#L66) |
| a chamada | [`:122`](../../src/ai/mind_oracle.gd#L122) `_http.request(server_url + "/v1/chat/completions", auth_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload))` |
| a resposta | [`:151`](../../src/ai/mind_oracle.gd#L151) `_on_response`, com o `_clean` de 140 caracteres em [`:199`](../../src/ai/mind_oracle.gd#L199) |
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
   [`:182`](../../src/ai/mind_oracle.gd#L182)/[` :184`](../../src/ai/mind_oracle.gd#L184) (comentários que
   nomeiam a enum `HTTPRequest.Result`, lida do registro da classe em
   [`:67`](../../src/ai/mind_oracle.gd#L67)), [`:62`](../../src/ai/mind_oracle.gd#L62) (cria o nó),
   [`:189`](../../src/ai/mind_oracle.gd#L189) (`RESULT_SUCCESS` no `_reason_of`).
2. [`src/ai/llm_server_host.gd:87`](../../src/ai/llm_server_host.gd#L87) e
   [`:99`](../../src/ai/llm_server_host.gd#L99) — o **hospedeiro** que levanta o `llama-server` no boot
   (perna 15). Ele é dono de `OS.create_process`
   ([`:311`](../../src/ai/llm_server_host.gd#L311)), do health-check de porta
   ([`:216`](../../src/ai/llm_server_host.gd#L216) `_probe()`, cujo GET usa o mesmo nó criado em
   [`:99`](../../src/ai/llm_server_host.gd#L99) contra a URL lida do oráculo em
   [`:189`](../../src/ai/llm_server_host.gd#L189)) e do encerramento do filho: **um** sítio de
   `OS.kill` ([`:414`](../../src/ai/llm_server_host.gd#L414), com `kills_issued += 1` em
   [`:413`](../../src/ai/llm_server_host.gd#L413)) alcançado por **dois** caminhos de saída —
   `_exit_tree` ([`:395`](../../src/ai/llm_server_host.gd#L395)) e `NOTIFICATION_PREDELETE`
   ([`:400`](../../src/ai/llm_server_host.gd#L400)) — ambos dentro de `_stop_child()`
   ([`:406`](../../src/ai/llm_server_host.gd#L406)) e ambos protegidos por `_owns_child`.

A mesma varredura estendida a `tests/` acha a **décima** linha, em
[`tests/llm_server_boot_probe.gd:266`](../../tests/llm_server_boot_probe.gd#L266) — a sonda da perna 15,
que a Fase 1 também aposenta (§5.4).

Consequência que o prompt não prevê e que a Fase 1 tem de decidir **antes** do código: se o oráculo
não fala mais HTTP, **o hospedeiro da Fase 15 perde a razão de existir** — o que ele resolve hoje é
porta e processo, e a porta ele lê do próprio oráculo
([`:189`](../../src/ai/llm_server_host.gd#L189) `_url()` devolve `oracle.server_url`; `_port()`
[`:196`](../../src/ai/llm_server_host.gd#L196) extrai o número dela, nunca um literal repetido), e a
linha de status do F3 ([`:133`](../../src/ai/llm_server_host.gd#L133) `status_line()`) é montada sobre
essa mesma porta. O braço escolhido está no §6.3; o rejeitado está no §8.4.

### 2.3 O contrato de quem lê o oráculo (e por isso a fronteira não pode mudar de tipo)

A saída do oráculo tem exatamente **três consumidores** em `src/`, todos de leitura:

- [`src/main.gd:183`](../../src/main.gd#L183) — injeta o `narration_provider` no HUD chamando
  `oracle.narration_of(id)`;
- [`src/ui/hud.gd:276-277`](../../src/ui/hud.gd#L276-L277) — imprime `ia:` no F3;
- o `narration_ready` ([`src/ai/mind_oracle.gd:9`](../../src/ai/mind_oracle.gd#L9)) que o lobo não
  consome: **nenhum** `connect(` a este sinal existe em `src/` hoje. Ele é a superfície para o
  futuro MindsInspector, e a Fase 5 da tabela do §5.6 é o comprador que faltava.

E a única porta de **entrada** é o roster (`roster_provider`, [`:40`](../../src/ai/mind_oracle.gd#L40),
ligado em [`src/main.gd:181`](../../src/main.gd#L181) com `Callable(self, "wolves_roster")`) mais os
campos injetáveis de `server_url`/`request_timeout`/`api_key`/`ready_provider`
([`:32-40`](../../src/ai/mind_oracle.gd#L32-L40)); o `ready_provider` é ligado pelo hospedeiro em
[`src/main.gd:236`](../../src/main.gd#L236). Nada de `Wolf`, `VoxelWorld` ou `Player` chama o oráculo.
A regra do dono — "a mente propõe, as regras dispõem" — hoje é verdadeira **por topologia**: não existe
caminho do oráculo para a intenção. A Fase 1 tem de manter a topologia, e o §7.1 registra que topologia
não é prova.

### 2.4 O que o F3 já diz sobre a IA, e o que ele não diz

`diagnostics()` de [`src/main.gd:1190`](../../src/main.gd#L1190) expõe `"llm": llm_host.diagnostics()`,
que por sua vez ([`src/ai/llm_server_host.gd:159`](../../src/ai/llm_server_host.gd#L159)) devolve
`state`, `pid`, `boot_ms`, `loading_503`, `retries`, `requests`, `kills`, `spawned`, `detail` e `url` —
dez chaves, todas de **ciclo de vida de processo**, nenhuma de **trabalho do modelo**. A outra metade
do retrato é prosa: a linha do F3 é `status_line()`
([`:133`](../../src/ai/llm_server_host.gd#L133)), e o único número do oráculo que chega a ela é
`oracle.last_reason` (lido em [`:152-153`](../../src/ai/llm_server_host.gd#L152-L153)); o `server_url`
que define a porta também é lido do oráculo ([`:189`](../../src/ai/llm_server_host.gd#L189)).

**Não há** tokens/s, µs de decodificação, profundidade de fila, taxa de cache nem memória do contexto —
e os contadores do próprio oráculo (`requests_issued`
[`:56`](../../src/ai/mind_oracle.gd#L56), `last_status` [`:57`](../../src/ai/mind_oracle.gd#L57),
`last_reason` [`:58`](../../src/ai/mind_oracle.gd#L58)) não aparecem em `diagnostics()` nem no HUD:
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
diretório de processo é premissa do Passo 2, e é lá que ela passa a ser checada.

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
([`tests/aether_reactions_test.gd:3769`](../../tests/aether_reactions_test.gd#L3769), registrada no
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
   `OS.create_process` ([`llm_server_host.gd:311`](../../src/ai/llm_server_host.gd#L311)), o
   `OS.kill` do filho ([`:414`](../../src/ai/llm_server_host.gd#L414)) e o launcher. O custo da troca
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
`passo1a_ruler_plan_ids.log` — **3 052 ponteiros / 209 rótulos / 3 177 links com 0 casos objetivos**,
**1 013 citações com número conferidas, 0 fora do arquivo** e as ausências do `verify_plan_ids` são todas
peças que esta página declara inexistentes. O manifesto da pasta,
[`artifacts.sha256`](../evidence/oraculo-nativo-22/artifacts.sha256), foi refeito com `sha256sum -b`
nesta passada — **45 entradas, `sha256sum -c` 45/45 OK** — pelo motivo do §12.4.

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
é por isso que a régua dele vale para os seguintes: o Passo 1 (b) acrescenta oito e o manifesto passa a
**53 entradas**, com a conta re-rodada por `sha256sum -c` no mesmo clone limpo. Fica como
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
([`tests/aether_reactions_test.gd:5529`](../../tests/aether_reactions_test.gd#L5529)) entrou no fim da
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
([`:60`](../../tests/aether_reactions_test.gd#L60)), porque a linha `_checks + 1 == EXPECTED_CHECKS` de
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

O manifesto da pasta acompanha: as oito evidências desta passada somam-se às quarenta e cinco do lote (a)
e a conta fecha em **45 + 8 = 53 entradas**, computada `sha256sum -b` e conferida `sha256sum -c` **num
clone limpo** — a régua do furo #36, que é exatamente o teste de que um lote (a) precisa para valer como
contrato e não como fotografia.

O que **não** fecha aqui: `native/` continua sem existir, e o verde das cinco linhas é o Passo 1 (c) —
`build.bat` com o toolset pinado (§12.1) e o gate de SHA conferindo **as duas formas** do cabeçalho
(§12.2), o cabeçalho vendorizado com a linha de licença em `THIRD_PARTY_LICENSES.md` no mesmo commit
(§6.1), e `register_types.cpp` registrando **uma** classe sem função de IA nenhuma. A `main` pousada está
em 283/0 na revisão dela; o pouso desta perna se dá com o runner em **288/0**, e enquanto a (c) não
existe o que se publica na branch é o vermelho com número — um gate verde por decreto seria exatamente o
que o mandato 4 veda.
