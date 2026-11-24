# Licenças de terceiros

Pacotes que o Aetherfall usa. Os três primeiros **não entram** no repositório: `models/`
e `.tools/` estão no `.gitignore` e são baixados por
[tools/fetch_models.ps1](tools/fetch_models.ps1), que confere SHA256 e tamanho
antes de instalar; download parcial nunca vira modelo.

O que **acompanha** o repositório são duas coisas: o som — 51 arquivos CC0 em `assets/audio/`,
com origem, licença lida e SHA-256 por arquivo em [`docs/audio-provenance.md`](docs/audio-provenance.md)
— e **um** arquivo de terceiro em código: o cabeçalho de interface do GDExtension vendorado em
[`native/af_mind/include/gdextension_interface.h`](native/af_mind/include/gdextension_interface.h),
linha por linha na tabela abaixo.

| Pacote | Origem | Licença | Destino local |
|---|---|---|---|
| Qwen3.5-4B (GGUF Q4_K_M, quantização unsloth) | [unsloth/Qwen3.5-4B-GGUF](https://huggingface.co/unsloth/Qwen3.5-4B-GGUF) | Apache-2.0 | `models/qwen3.5-4b-q4_k_m.gguf` |
| llama.cpp b12499 (build win-vulkan-x64) | [ggml-org/llama.cpp release b12499](https://github.com/ggml-org/llama.cpp/releases/tag/b12499) | MIT | `.tools/llama/runtime/` |
| Godot Engine 4.7.2-stable | [godotengine.org](https://godotengine.org/download) | MIT | `.tools/` |
| `gdextension_interface.h` (Godot 4.7.2-stable) | produto do gerador de interface do próprio build do Godot na tag `4.7.2-stable` — medido no dossiê 22 §12.2: não é arquivo baixável do site, é o que o SCons do engine escreve | MIT (Godot Engine) | `native/af_mind/include/`, **dentro do repositório** |

Notas:

- **Qwen3.5-4B** — pesos sob Apache-2.0; o arquivo GGUF Q4_K_M é a quantização
  publicada pela unsloth sobre o modelo oficial (trabalho derivado, mesma
  licença). Usado como `mind-small` (docs/design/04 e 08): narração do estado
  interno dos mobs via llama-server em localhost. O modelo é opcional — sem ele
  o jogo roda completo, só sem a linha de narração no debug.
- **llama.cpp** — binários pre-compilados do release oficial da ggml-org (MIT),
  backend Vulkan (AMD Radeon 9060 XT e qualquer GPU moderna).
- **Godot Engine** — engine MIT; o binário portável em `.tools/` é ferramenta
  local de validação (janela/headless) e não acompanha o projeto.
- **`gdextension_interface.h`** — é o cabeçalho de ABI contra o qual
  [`native/af_mind/src/register_types.cpp`](native/af_mind/src/register_types.cpp) compila, e o
  único arquivo de terceiro que **entra** no repositório como código. A procedência é conferida
  por SHA-256 no próprio build, não por memória: `777a3fe517c1b29eece0646c50ec0da1c617586ea2e9ffbc1965e8fdb9149b2b`
  na forma gerada (143 170 B, 3 178 linhas CRLF, arquivada em
  [`docs/evidence/oraculo-nativo-22/gdextension_interface_472.h`](docs/evidence/oraculo-nativo-22/gdextension_interface_472.h))
  e `4c0aac8da3dfedc14d0e049205aeaaa11f32802bee56d4a275a466ac231fa916` na forma do checkout
  (139 992 B, LF — é esta que está em `native/af_mind/include/`); o
  [`native/af_mind/build.bat`](native/af_mind/build.bat) recusa qualquer outro hash. O motivo de a
  licença morar **aqui** e não no arquivo é medido (dossiê 22 §6.1): o gerador valida a chave
  `_copyright` do JSON, mas nunca a escreve — o cabeçalho gerado tem **zero** marcadores de
  licença, então sem esta linha o arquivo vendorizado estaria sem atribuição.

## De onde veio a arte (e de onde ela não veio)

**Nenhum modelo 3D nem textura de terceiro entra no jogo — a imagem é 100% código.** Conferido
em 2026-11-18: `git ls-files` não devolve `.glb`, `.gltf` nem `.png` de arte. O material de
terceiro versionado no repositório é o som (`.ogg`/`.wav` em `assets/audio/`) e o cabeçalho de ABI
do GDExtension em `native/af_mind/include/` — um é domínio público CC0, arquivo por arquivo, com
origem e SHA-256 em [`docs/audio-provenance.md`](docs/audio-provenance.md); o outro é MIT do Godot,
com SHA-256 na nota acima.

| O que você vê | Como é feito |
|---|---|
| Texturas de todos os blocos | desenhadas em runtime, pixel a pixel, em [`src/world/voxel_atlas.gd`](src/world/voxel_atlas.gd) — nenhum arquivo de textura existe |
| Terreno, cubas, cavernas, árvores | [`src/world/world_gen.gd`](src/world/world_gen.gd) a partir da seed, com a malha montada em [`src/world/voxel_world.gd`](src/world/voxel_world.gd) |
| Corpo do jogador em 3ª pessoa | caixas e animação procedurais em [`src/entities/player_avatar.gd`](src/entities/player_avatar.gd) |
| Braço e bloco na mão (1ª pessoa) | [`src/entities/fp_viewmodel.gd`](src/entities/fp_viewmodel.gd) |
| Lobo | [`src/entities/wolf.gd`](src/entities/wolf.gd), `_build_visual()` |
| Véu do Éter | [`src/rendering/aether_viz.gd`](src/rendering/aether_viz.gd) |
| `icon.svg` | vetor do próprio projeto |
| `docs/media/*.png` | capturas que o jogo produziu nestas máquina (harness de galeria), não material de terceiro |
| O que você ouve | 51 arquivos CC0 em `assets/audio/`, roteados por [`src/audio/audio_director.gd`](src/audio/audio_director.gd) — origem, licença lida e SHA por arquivo em [`docs/audio-provenance.md`](docs/audio-provenance.md) |

**Inspiração é de idéias, não de arquivos.** O *que* os sistemas fazem vem em boa parte do
Veloren (lobo que patrulha e caça, golpear/planar/nadar, memória do mundo) e o feels voxel do
Minecraft — o registro linha a linha do que virou código, do que ficou como idéia e do que foi
rejeitado está em [`docs/design/09`](docs/design/09-veloren-mechanics-adaptation.md), e a regra
de conduta está no item 8 de [`AGENTS.md`](AGENTS.md). Dos dois, nenhum asset foi copiado: o
Veloren distribui tudo (código **e** `assets/voxygen/audio/**`) sob um único `LICENSE` GPL-3.0,
e os assets do Minecraft são proprietários. O que se aproveita deles é estrutura e idéia — no som,
a estrutura de categorias (passo por material, ambiência por bioma, vocalização por espécie). Os
arquivos que tocam no jogo hoje são CC0 de domínio público, cópia byte a byte do pacote de origem,
com SHA-256 conferido por `sha256sum -c docs/audio-sha256.txt`. A tabela de pacotes, os autores e
o que foi rejeitado estão em [`docs/audio-provenance.md`](docs/audio-provenance.md).

