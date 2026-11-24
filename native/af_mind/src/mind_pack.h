#ifndef AF_MIND_PACK_H
#define AF_MIND_PACK_H

// Passo 2 (b) do dossier 22 (S5.2): o corpo que carrega o pack DENTRO do processo.
//
// Este header e deliberadamente estreito: ele nao conhece o Godot. Morar aqui e o que permite as
// duas pontas chamarem o MESMO codigo de maquina -- o exe de sonda (`pack_probe_main.cpp`, de pe,
// fora da engine, onde uma ABI errada e um achado impresso) e a extensao (`register_types.cpp`,
// dentro do `Godot_v4.7.2-stable_win64.exe`). Copiar a sequencia para os dois seria exatamente o
// erro que o S15.1 descreve: dois lugares para a mesma assinatura, e um deles fica velho.
//
// Nenhuma grandeza sai daqui como adjective: os getters devolvem o numero lido do runtime, e o
// numero `-1` e reservado para "esta grandeza nao foi medida neste processo" -- nunca 999, nunca o
// valor pedido por fora no lugar da leitura (S5.2).

#include <cstdint>

extern "C" {

// --- a rota, na ordem em que tem de acontecer ---------------------------------------------
// 1) `af_pack_preload_runtime`: os cinco modulos pelo CAMINHO ABSOLUTO. E a rota que o S15.5
//    escreveu como obrigatoria (nome nu: `erro=126` em cinco de cinco), e tem de acontecer antes
//    de qualquer delay-helper -- por isso nenhum outro nome deste arquivo pode ser chamado antes.
// 2) `af_pack_load("", "")`: o pack VAZIO, que e a base do `af_vram_gb` (S5.2 pede a base medida
//    antes, nao um zero assumido).
// 3) `af_pack_load(nome, path)`: o `.gguf`; depois disto e que as tres grandezas existem.
// 4) `af_pack_ctx_probe(celulas)`: o contexto SO do passo 4, separado do load de proposito. O
//    motivo e um risco medido, nao cerimonia: os params do contexto sao um blob que eu nao sei
//    organizar (nao ha `llama.h` na arvore, S12.3), entao escrever o numero pedido na primeira
//    palavra e uma AFIRMACAO de layout que so o proprio runtime pode confirmar -- e ela confirma
//    devolvendo `llama_n_ctx == pedido`. Se um dia nao confirmar, a grandeza fica `-1` e a pagina
//    escreve `[OPEN]`; ate la, a sonda de pe corre este ponto antes do Godot, porque uma afirmacao
//    errada aqui cobra o contexto inteiro do modelo (o `qwen35.context_length` e 262 144 celulas)
//    e isso e um aborto de processo, nao um numero errado.
void af_pack_init(void);
int af_pack_preload_runtime(const char * dir_utf8);
// `pack_nome` e o identificador do S5.3; `path_utf8` vazio = o pack VAZIO (a base).
int af_pack_load(const char * pack_nome, const char * path_utf8);

int af_pack_ctx_probe(int32_t celulas);

// Maquina de estados da rota: 0 = nada tocado, 1 = runtime pre-carregado por caminho absoluto,
// 2 = backends no registro e pack vazio medido (a base), 3 = modelo no processo,
// 4 = contexto criado. As checagens de recusa do runner leem este numero: ele e a prova de que
// nenhum nome do runtime foi chamado antes do preload (S15.5), e nao uma frase sobre intencao.
int32_t af_pack_state(void);

// --- as tres grandezas do S5.2, e as testemunhas ao redor ----------------------------------
// `-1` = "o runtime nao devolveu esta grandeza", que e o que vira `[OPEN]` na pagina.
int64_t af_pack_vram_total(void);
int64_t af_pack_vram_base(void);
int64_t af_pack_vram_used(void);
int64_t af_pack_load_ms(void);
int64_t af_pack_open_ms(void);
int64_t af_pack_backends_loaded(void);
int64_t af_pack_ctx_cells(void);
// O que `llama_n_ctx` devolveu, mesmo quando nao e o numero pedido: e a testemunha da afirmacao
// de layout acima, e por isso vive separada do numero reportado.
int64_t af_pack_ctx_readback(void);
int64_t af_pack_ctx_pedido(void);
int64_t af_pack_n_batch(void);
int64_t af_pack_n_ubatch(void);
// A primeira palavra do blob de params do contexto, como dado observado -- ler o blob que
// o proprio runtime escreveu nao e afirmar qual campo ele e.
int64_t af_pack_ctx_word0(void);
// A memoria do NOSSO processo, lida do SO (K32GetProcessMemoryInfo), nao do runtime: e a
// testemunha independente de para onde foram os bytes do pack quando a VRAM nao se moveu.
int64_t af_pack_rss_antes(void);
int64_t af_pack_rss_apos(void);
int64_t af_pack_rss_atual(void);

// --- as leituras independentes com que as tres acima sao conferidas -------------------------
int64_t af_pack_model_bytes(void);
int64_t af_pack_ctx_train(void);
int64_t af_pack_state_bytes(void);
int64_t af_pack_vocab_tokens(void);
int64_t af_pack_n_layer(void);
int64_t af_pack_n_head(void);
int64_t af_pack_n_head_kv(void);
int64_t af_pack_n_embd(void);
int64_t af_pack_ftype(void);
int64_t af_pack_vram_free(void);
const char * af_pack_version_texto(void);
int64_t af_pack_reg_count(void);
int64_t af_pack_dev_count(void);
int64_t af_pack_vk_count(void);
int64_t af_pack_gpu_offload(void);
int64_t af_pack_hybrid(void);
int64_t af_pack_mods_open(void);
int64_t af_pack_params_written(int qual);
int64_t af_pack_params_last(int qual);
int64_t af_pack_slots(int imprimir);
// as duas leituras de metadata do modelo, contadas e nomeadas pelo proprio runtime (a contagem e
// quem diz se o acesso por indice anda antes de eu confiar nas duas chaves que importam)
int64_t af_pack_meta_count(void);
const char * af_pack_meta_key0(void);

// --- diagnostico ----------------------------------------------------------------------------
int32_t af_pack_err_stage(void);
int64_t af_pack_err_code(void);
int32_t af_pack_err_which(void);
const char * af_pack_err_text(void);
const char * af_pack_runtime_dir(void);
const char * af_pack_pack_name(void);
const char * af_pack_ftype_name(void);
const char * af_pack_arch(void);
const char * af_pack_vk_name(void);
const char * af_pack_vk_desc(void);
const char * af_pack_model_desc(void);
const char * af_pack_meta_ctx(void);

} // extern "C"

#endif // AF_MIND_PACK_H
