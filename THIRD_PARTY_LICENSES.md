# Licenças de terceiros

Pacotes que o Aetherfall usa localmente. Nenhum entra no repositório: `models/`
e `.tools/` estão no `.gitignore` e são baixados por
[tools/fetch_models.ps1](tools/fetch_models.ps1), que confere SHA256 e tamanho
antes de instalar; download parcial nunca vira modelo.

| Pacote | Origem | Licença | Destino local |
|---|---|---|---|
| Qwen3.5-4B (GGUF Q4_K_M, quantização unsloth) | [unsloth/Qwen3.5-4B-GGUF](https://huggingface.co/unsloth/Qwen3.5-4B-GGUF) | Apache-2.0 | `models/qwen3.5-4b-q4_k_m.gguf` |
| llama.cpp b12499 (build win-vulkan-x64) | [ggml-org/llama.cpp release b12499](https://github.com/ggml-org/llama.cpp/releases/tag/b12499) | MIT | `.tools/llama/runtime/` |
| Godot Engine 4.7.2-stable | [godotengine.org](https://godotengine.org/download) | MIT | `.tools/` |

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
