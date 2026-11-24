// Passo 2 (b) do dossier 22 (S5.2): a ponta Godot do corpo do pack.
//
// O que mudou desde o Passo 1: aqui mora agora a PONTE, nao o corpo. O corpo (a sequencia de
// maquina que carrega o runtime por caminho absoluto, mede VRAM/tempo/celulas) esta em
// `mind_pack.cpp`, sem um include de Godot, porque e o MESMO codigo que o `af_pack_probe.exe`
// executa de pe. A ponte tem tres funcoes e nenhuma delas conhece llama.cpp:
//
//  1. registrar os metodos na ClassDB via `classdb_register_extension_class_method`, com
//     `call_func` (Variant) e `ptrcall_func` (cru) IMPLEMENTADOS OS DOIS -- o GDScript chama por
//     Variant e uma das duas rotas ficar vazia e uma recusa silenciosa que ninguem vai achar;
//  2. converter String <-> `const char *` pelas funcoes da interface (`string_new_with_utf8_chars`,
//     `string_to_utf8_chars`, que NAO termina em NUL -- o byte zero e meu) e int64 pelos
//     construtores tipo<->Variant, que sao o caminho aceito da interface, nao um palpite de layout
//     de Variant (Variant e interna da engine e nao tem layout publicado);
//  3. nao imprimir nada: nao existe `print_line` no cabecalho vendorado, entao o diagnostico sai
//     como dado (`err_text`, `err_stage`, `err_code`) e o GDScript imprime a linha literal.
//
// A rotina obrigatoria continua valendo: o load do pack so acontece depois de
// `set_runtime_dir(caminho_absoluto)` -- que chama `af_pack_preload_runtime` -- porque o S15.5 mediu
// o nome nu com `erro=126` em cinco de cinco, e qualquer outro acesso antes disso toca o
// delay-helper com o nome errado no lugar errado.
//
// Passo 3 (S5.3): a ponte ganha a API do prompt -- `enqueue(req: Dictionary) -> int`,
// `wait(request_id, timeout_ms) -> Dictionary`, as metricas (`queue_depth`, `cache_hits`,
// `cache_misses`, `vram_bytes`, `worst_decode_us`), `prompt_err_text` e o registro dos tres
// sinais. Ler e montar Dictionary mora AQUI (o corpo segue sem conhecer Godot): o valor de
// `dicto[chave]` sai do getter por ponteiro do TIPO Dictionary com a chave como Variant cru, a
// existencia da chave da checker por chave (que le VARIANTS) e a montagem usa o construtor por
// ponteiro + o setter por ponteiro -- nenhum layout de Variant ou de Dictionary e suposto. Cada
// Variant cru temporario e fechado com `variant_new_nil` e cada String temporaria com o
// destrutor por ponteiro do tipo, porque o header vendorado nao expoe destrutor de Variant e o
// vazamento de ref e o defeito silencioso que ninguem conta.
//
// A EMISSAO dos sinais e [ABERTA] e vai escrita: o registro existe (a conexao ainda nao tem
// medicao -- o gate `contrato_igal_ao_http`, no commit seguinte, e quem a exerce), mas o header
// vendorado 4.7.2 nao traz `object_emit_signal` nem `object_callp`, e
// `classdb_get_method_bind` exige hashes que so o extension_api.json da engine teria (S12.2) --
// quem emite e o Passo 4/5, pela rota que essa perna medir.

#include <cstdint>
#include <cstdio>
#include <cstring>

#include "gdextension_interface.h"

#include "mind_pack.h"
#include "mind_prompt.h"

namespace {

// Toda funcao da interface chega por `p_get_proc_address`: nao ha linking estatico com o
// Godot, e um nome ausente e diagnostico, nao crash. Os tres nomes discriminantes da ABI
// 4.7.2 (S12.2) sao `classdb_register_extension_class6`, `classdb_construct_object3` e a
// struct `GDExtensionClassCreationInfo6`.
GDExtensionInterfacePrintError print_error_fn = nullptr;
GDExtensionInterfaceStringNameNewWithLatin1Chars string_name_new = nullptr;
GDExtensionInterfaceClassdbRegisterExtensionClass6 register_extension_class6 = nullptr;
GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_extension_class = nullptr;
GDExtensionInterfaceClassdbConstructObject3 construct_object3 = nullptr;
GDExtensionInterfaceObjectSetInstance set_instance = nullptr;
GDExtensionInterfaceGetGodotVersion2 get_godot_version2 = nullptr;

// Passo 2 (b): os nomes que a ponte de metodos precisa. A ausencia de qualquer um deles e a
// mesma prova de engine errada do bloco de cima, e o tratamento e o mesmo: recusa, nao crash.
GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_extension_class_method = nullptr;
GDExtensionInterfaceStringNewWithUtf8Chars string_new_utf8 = nullptr;
GDExtensionInterfaceStringToUtf8Chars string_to_utf8_chars = nullptr;
GDExtensionInterfaceGetVariantFromTypeConstructor variant_from_type = nullptr;
GDExtensionInterfaceGetVariantToTypeConstructor variant_to_type = nullptr;
GDExtensionInterfaceVariantGetType variant_get_type = nullptr;

// Passo 3: leitura de Dictionary (getter/setter/checker por chave), construcao e destruicao de
// tipos crus por ponteiro, leitura de Array por indice, fechamento de Variant temporario e o
// registro dos sinais. A ausencia de qualquer um deles e a mesma prova de engine errada.
GDExtensionInterfaceVariantGetPtrKeyedGetter keyed_getter = nullptr;
GDExtensionInterfaceVariantGetPtrKeyedSetter keyed_setter = nullptr;
GDExtensionInterfaceVariantGetPtrKeyedChecker keyed_checker = nullptr;
GDExtensionInterfaceVariantGetPtrConstructor variant_ptr_constructor = nullptr;
GDExtensionInterfaceVariantGetPtrDestructor variant_ptr_destructor = nullptr;
GDExtensionInterfaceVariantGetIndexed variant_get_indexed = nullptr;
GDExtensionInterfaceVariantNewNil variant_new_nil = nullptr;
GDExtensionInterfaceClassdbRegisterExtensionClassSignal register_extension_class_signal = nullptr;

GDExtensionClassLibraryPtr library = nullptr;
bool class_registered = false;

const char *const CLASS_NAME = "AfMindOracle";
const char *const PARENT_NAME = "RefCounted";

// `r_dest` e "uninitialized storage, into which the newly created StringName is
// constructed": a engine escreve o StringName dela (16 bytes) dentro da storage que
// passamos. A interface 4.7.2 nao expoe destrutor de StringName, entao os dois nomes vivem
// o que o processo viver -- que e o ciclo de uma classe registrada no level CORE. 32 bytes
// alinhados a 8 e folga sobre os 16 da engine, nao um palpite de layout.
alignas(8) unsigned char sn_class_storage[32];
alignas(8) unsigned char sn_parent_storage[32];
// Os nomes vazios que toda PropertyInfo precisa (`class_name` de tipo simples e `hint_string`
// vazio): UMA storage compartilhada, porque o `classdb_register_extension_class_method` copia a
// struct no ato do registro ("Provided struct can be safely freed once the function returns") e
// ninguem mais le depois.
alignas(8) unsigned char sn_empty_storage[32];
alignas(8) unsigned char str_empty_storage[32];

GDExtensionConstStringNamePtr class_name_sn() {
	return reinterpret_cast<GDExtensionConstStringNamePtr>(sn_class_storage);
}

GDExtensionConstStringNamePtr parent_name_sn() {
	return reinterpret_cast<GDExtensionConstStringNamePtr>(sn_parent_storage);
}

// O corpo nativo guarda o estado dele em `mind_pack.cpp` (global do processo): a instancia da
// engine e so o amarrador. O marker existe para o `free_instance` ter o que deletar e para o
// `set_instance` ter um ponteiro nao-nulo.
struct AfMindOracleInstance {
	uint32_t marker;
};

GDExtensionObjectPtr create_instance(void *p_class_userdata, GDExtensionBool p_notify_postinitialize) {
	(void)p_class_userdata;
	// O alvo do construct e o PAI built-in, nao o nosso nome. Medido na sonda de
	// atribuicao (arm2, log em docs/evidence/oraculo-nativo-22/passo1c_arm2_probe.err):
	// pedir a engine que construa "AfMindOracle" de dentro do `create_instance_func` de
	// "AfMindOracle" faz a engine chamar este mesmo funcionario outra vez, e o processo
	// morria no instantiate (exit 127) sem nenhuma linha do probe depois de
	// `p4_class_exists`. O doc de
	// `classdb_construct_object3` admite "an already-registered extension class" sem
	// dizer que esse caminho reentrancia -- entao a palavra aqui e a corrida, nao o
	// comentario do header.
	GDExtensionObjectPtr obj = construct_object3(parent_name_sn());
	if (obj == nullptr) {
		return nullptr;
	}
	AfMindOracleInstance *inst = new AfMindOracleInstance{ 0x41464D31u };
	set_instance(obj, class_name_sn(), inst);
	// `NOTIFICATION_POSTINITIALIZE` nao e despachado, e isso vai escrito em vez de escondido:
	// a classe nao sobrescreve notificacao, nao tem script herdando dela e no Passo 1 nao tinha
	// metodo nenhum -- nao ha o que avisar.
	(void)p_notify_postinitialize;
	return obj;
}

void free_instance(void *p_class_userdata, GDExtensionClassInstancePtr p_instance) {
	(void)p_class_userdata;
	delete static_cast<AfMindOracleInstance *>(p_instance);
}

// ==============================================================================================
// Os metodos da ponte: uma tabela, um dispatcher, zero if por metodo.
//
// `method_userdata` e o INDICE na tabela. As duas rotas (Variant e ptrcall) caem no mesmo
// `executa`, que recebe os argumentos JA em forma crua (int64 / char *), porque a rota Variant
// converte antes com `get_variant_to_type_constructor` -- o conversor aceito da interface, que e o
// que evita que este arquivo precise de layout de Variant.
// ==============================================================================================

enum {
	M_SET_RUNTIME_DIR,
	M_LOAD_PACK,
	M_CTX_PROBE,
	M_PACK_STATE,
	M_PACK_NAME,
	M_RUNTIME_DIR,
	M_VRAM_TOTAL,
	M_VRAM_BASE,
	M_VRAM_USED,
	M_VRAM_FREE,
	M_LOAD_MS,
	M_OPEN_MS,
	M_BACKENDS,
	M_CTX_CELLS,
	M_CTX_READBACK,
	M_CTX_STATE,
	M_CTX_TRAIN,
	M_CTX_WORD0,
	M_N_BATCH,
	M_N_UBATCH,
	M_MODEL_BYTES,
	M_VOCAB,
	M_N_LAYER,
	M_N_HEAD,
	M_N_HEAD_KV,
	M_N_EMBD,
	M_FTYPE,
	M_FTYPE_NAME,
	M_ARCH,
	M_MODEL_DESC,
	M_META_CTX,
	M_META_COUNT,
	M_META_KEY0,
	M_VERSION,
	M_REG_COUNT,
	M_DEV_COUNT,
	M_VK_COUNT,
	M_GPU_OFFLOAD,
	M_HYBRID,
	M_MODS_OPEN,
	M_RSS_ANTES,
	M_RSS_APOS,
	M_ERR_STAGE,
	M_ERR_CODE,
	M_ERR_WHICH,
	M_ERR_TEXT,
	M_VK_NAME,
	M_VK_DESC,
	M_SLOT_CHECKSUM,
	M_ENQUEUE,
	M_WAIT,
	M_QUEUE_DEPTH,
	M_CACHE_HITS,
	M_CACHE_MISSES,
	M_VRAM_BYTES,
	M_WORST_DECODE_US,
	M_PROMPT_ERR_TEXT,
	M_TOTAL
};

struct MetodoArg {
	GDExtensionVariantType tipo;
	const char * nome;
};

struct Metodo {
	const char * nome;
	bool retorna_texto; // false = int64; com retorna_dicto true, o Dictionary vence
	uint8_t n_args;
	MetodoArg args[2];
	bool retorna_dicto; // Passo 3: so o wait devolve Dictionary; os inicializadores antigos
	                    // ficam sem o campo e o C++ o completa com false
};

// `pack_name`/`path` sao os nomes de S5.3: o mesmo vocabulario que a pagina do dossier usa, para
// que o GDScript e a pagina contem a mesma coisa.
const Metodo METODOS[M_TOTAL] = {
	{ "set_runtime_dir", false, 1, { { GDEXTENSION_VARIANT_TYPE_STRING, "path" }, { GDEXTENSION_VARIANT_TYPE_NIL, "" } } },
	{ "load_pack", false, 2, { { GDEXTENSION_VARIANT_TYPE_STRING, "pack_name" }, { GDEXTENSION_VARIANT_TYPE_STRING, "path" } } },
	{ "ctx_probe", false, 1, { { GDEXTENSION_VARIANT_TYPE_INT, "cells" }, { GDEXTENSION_VARIANT_TYPE_NIL, "" } } },
	{ "pack_state", false, 0, {} },
	{ "pack_name", true, 0, {} },
	{ "runtime_dir", true, 0, {} },
	{ "vram_total_bytes", false, 0, {} },
	{ "vram_base_bytes", false, 0, {} },
	{ "vram_used_bytes", false, 0, {} },
	{ "vram_free_bytes", false, 0, {} },
	{ "load_ms", false, 0, {} },
	{ "open_ms", false, 0, {} },
	{ "backends_loaded", false, 0, {} },
	{ "ctx_cells", false, 0, {} },
	{ "ctx_readback", false, 0, {} },
	{ "ctx_state_bytes", false, 0, {} },
	{ "ctx_train", false, 0, {} },
	{ "ctx_word0", false, 0, {} },
	{ "n_batch", false, 0, {} },
	{ "n_ubatch", false, 0, {} },
	{ "model_bytes", false, 0, {} },
	{ "vocab_tokens", false, 0, {} },
	{ "n_layer", false, 0, {} },
	{ "n_head", false, 0, {} },
	{ "n_head_kv", false, 0, {} },
	{ "n_embd", false, 0, {} },
	{ "ftype", false, 0, {} },
	{ "ftype_name", true, 0, {} },
	{ "arch", true, 0, {} },
	{ "model_desc", true, 0, {} },
	{ "meta_ctx", true, 0, {} },
	{ "meta_count", false, 0, {} },
	{ "meta_key0", true, 0, {} },
	{ "runtime_version", true, 0, {} },
	{ "reg_count", false, 0, {} },
	{ "dev_count", false, 0, {} },
	{ "vk_count", false, 0, {} },
	{ "gpu_offload", false, 0, {} },
	{ "hybrid", false, 0, {} },
	{ "mods_open", false, 0, {} },
	{ "rss_antes_bytes", false, 0, {} },
	{ "rss_apos_bytes", false, 0, {} },
	{ "err_stage", false, 0, {} },
	{ "err_code", false, 0, {} },
	{ "err_which", false, 0, {} },
	{ "err_text", true, 0, {} },
	{ "vk_name", true, 0, {} },
	{ "vk_desc", true, 0, {} },
	{ "slot_checksum", false, 0, {} },
	// --- Passo 3 (S5.3): a API do prompt --------------------------------------------------
	// `enqueue` recebe o Dictionary de req (os campos e os defaults ausentes estao no comentario
	// de `monta_req_de_dicto`); `wait` devolve o Dictionary de saida na FORMA que o gate de S5.3
	// compara com o transporte HTTP. `vram_bytes` re-medida live (o getter do pack refaz a
	// leitura do Vulkan e atualiza o estado), nao o numero congelado do load.
	{ "enqueue", false, 1, { { GDEXTENSION_VARIANT_TYPE_DICTIONARY, "req" }, { GDEXTENSION_VARIANT_TYPE_NIL, "" } } },
	{ "wait", false, 2, { { GDEXTENSION_VARIANT_TYPE_INT, "request_id" }, { GDEXTENSION_VARIANT_TYPE_INT, "timeout_ms" } }, true },
	{ "queue_depth", false, 0, {} },
	{ "cache_hits", false, 0, {} },
	{ "cache_misses", false, 0, {} },
	{ "vram_bytes", false, 0, {} },
	{ "worst_decode_us", false, 0, {} },
	{ "prompt_err_text", true, 0, {} },
};

// O resultado de um metodo: um numero OU um texto curto. O texto e copiado para ca para que o
// `executa` nao precise de dois caminhos de retorno e para que nenhum `const char *` do pack
// sobreviva a chamada (a copia e quem protege contra a pagina sumir no meio do print).
struct Resultado {
	int64_t numero;
	char texto[384];
	bool e_dicto; // Passo 3: a saida e o Dictionary do wait, montado em `dicto_destino` do executa
};

// Capacidade de leitura de um argumento String. Os dois argumentos de texto sao caminhos: MAX_PATH
// de 260 cobre o que a rota absoluta aceita (`absoluto()` recusa o resto antes de qualquer load).
const int ARG_CAP = 300;

// As storages crua de conversao da rota Variant: duas Strings (caminho 1 e 2), dois int64 e o
// Dictionary do req do enqueue (Passo 3). A conversao e "construa o tipo cru a partir do
// Variant", e o resultado vive aqui durante a chamada -- que e todo o tempo de vida que a rota
// Variant garante.
alignas(8) unsigned char arg_str_storage[2][32];
int64_t arg_int_storage[2];
alignas(8) unsigned char arg_dict_storage[32];
// O Dictionary de saida do wait na rota Variant: o executa monta aqui, a rota converte para o
// Variant de retorno e destrói o cru (a referencia fica so do Variant). Dictionary e um ponteiro
// para o dado interno; 32 bytes e folga, nao palpite.
alignas(8) unsigned char dicto_saida_storage[32];
char arg_str_texto[2][ARG_CAP];

// Um String cru de retorno: a rota Variant precisa de um VALOR de String para o
// `get_variant_from_type_constructor` transformar em Variant, e a storage fica aqui porque a copia
// para o Variant acontece antes de `executa` voltar.
alignas(8) unsigned char ret_str_storage[32];

// A copia do texto devolvido pelo pack para o `Resultado` -- declarada antes de `executa` porque e
// o que os casos de texto do switch usam.
void copia_do_pack(const char * src, Resultado * r, bool * e_texto) {
	snprintf(r->texto, sizeof(r->texto), "%s", src != nullptr ? src : "");
	*e_texto = true;
}

// Declarada AQUI porque as duas rotas de chamada (abaixo) a usam: a definicao mora no fim do
// namespace, junto das outras rotinas de recusa, e sem esta linha o ponto de uso nao ve o nome.
void refuse(const char * p_message, const char * p_function);

// Le um String cru (rota ptrcall) ou um Variant de String (rota Variant, ja convertido) para
// `dst` TERMINADO em NUL: `string_to_utf8_chars` devolve a contagem de bytes e NAO termina em NUL,
// e um caminho sem byte zero e exatamente o que a checagem de `absoluto()` nao pode ver.
bool le_string(const unsigned char * str_storage, char * dst, size_t cap) {
	if (str_storage == nullptr || dst == nullptr || cap == 0) {
		return false;
	}
	dst[0] = '\0';
	const GDExtensionInt n = string_to_utf8_chars(reinterpret_cast<GDExtensionConstStringPtr>(str_storage),
			dst, (GDExtensionInt) (cap - 1));
	if (n < 0) {
		return false;
	}
	if ((size_t) n >= cap) {
		dst[cap - 1] = '\0';
		return true;
	}
	dst[n] = '\0';
	return true;
}

// ==============================================================================================
// Passo 3: as chaves crua e as leitoras de Dictionary.
//
// Cada chave e um Variant cru de String construido UMA vez no registro e vivido pelo processo --
// o mesmo contrato de vida das storages de StringName (a interface nao expoe destrutor para
// eles). O getter/setter por chave do tipo Dictionary pede a chave como Variant; a checker por
// chave le VARIANTS dos dois lados. As storages de 32 bytes tem folga sobre o tamanho real dos
// tipos (Variant 24, String 16), nao um palpite de layout.
// ==============================================================================================
struct ChaveDicto {
	const char * nome;
	alignas(8) unsigned char stringo[32];
	alignas(8) unsigned char varianto[32];
};

ChaveDicto chaves_dicto[] = {
	{ "role", {}, {} },          { "prompt", {}, {} },       { "max_tokens", {}, {} },
	{ "temperature", {}, {} },   { "schema", {}, {} },       { "priority", {}, {} },
	{ "context_ids", {}, {} },
	// as chaves do Dictionary de saida do wait (a FORMA de S5.3):
	{ "text", {}, {} },          { "reason", {}, {} },       { "request_id", {}, {} },
	{ "status", {}, {} },        { "decode_us", {}, {} },    { "tokens_out", {}, {} },
};
const int N_CHAVES = (int) (sizeof(chaves_dicto) / sizeof(chaves_dicto[0]));

bool constroi_chaves() {
	GDExtensionVariantFromTypeConstructorFunc conv = variant_from_type(GDEXTENSION_VARIANT_TYPE_STRING);
	if (conv == nullptr) {
		return false;
	}
	for (int i = 0; i < N_CHAVES; ++i) {
		string_new_utf8(reinterpret_cast<GDExtensionUninitializedStringPtr>(chaves_dicto[i].stringo),
				chaves_dicto[i].nome);
		conv(reinterpret_cast<GDExtensionUninitializedVariantPtr>(chaves_dicto[i].varianto),
				chaves_dicto[i].stringo);
	}
	return true;
}

const unsigned char * chave(const char * nome) {
	for (int i = 0; i < N_CHAVES; ++i) {
		if (strcmp(chaves_dicto[i].nome, nome) == 0) {
			return chaves_dicto[i].varianto;
		}
	}
	return nullptr;
}

// Fecha um Variant cru temporario: `variant_new_nil` escreve nil NO LUGAR, soltando a referencia
// que o valor tinha -- sem isso, cada leitura de campo de String vaza uma ref (o defeito que
// ninguem conta, porque o proceso continua de pe).
void nil_varianto(unsigned char * v) {
	if (variant_new_nil != nullptr) {
		variant_new_nil(reinterpret_cast<GDExtensionUninitializedVariantPtr>(v));
	}
}

// Destroi uma String crua temporaria pelo destrutor por ponteiro do tipo.
void destroi_stringo(unsigned char * s) {
	GDExtensionPtrDestructor d = variant_ptr_destructor != nullptr
			? variant_ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING) : nullptr;
	if (d != nullptr) {
		d(s);
	}
}

// O valor lido do getter por chave e um Variant cru; esta leitora exige o tipo INT e devolve o
// int64 pelo conversor aceito. Devolve false em tipo errado ou conversor ausente. O ponteiro
// nao-e-const porque o getter POR CHAVE ESCREVE no espaco (e a leitora so le depois dele).
bool valor_como_int64(unsigned char * valor, int64_t * dst) {
	if (variant_get_type(reinterpret_cast<GDExtensionConstVariantPtr>(valor)) !=
			GDEXTENSION_VARIANT_TYPE_INT) {
		return false;
	}
	GDExtensionTypeFromVariantConstructorFunc conv = variant_to_type(GDEXTENSION_VARIANT_TYPE_INT);
	if (conv == nullptr) {
		return false;
	}
	// O construtor da interface recebe `GDExtensionVariantPtr` nao-const embora so leia (mesma
	// assimetria ja assumida na rota de String); o tipo ja foi exigido acima antes da conversao.
	conv(dst, reinterpret_cast<GDExtensionVariantPtr>(valor));
	return true;
}

// O mesmo para o campo de temperatura: exige FLOAT (o payload do oraculo manda 0.7) e devolve o
// double pelo conversor aceito.
bool valor_como_double(unsigned char * valor, double * dst) {
	if (variant_get_type(reinterpret_cast<GDExtensionConstVariantPtr>(valor)) !=
			GDEXTENSION_VARIANT_TYPE_FLOAT) {
		return false;
	}
	GDExtensionTypeFromVariantConstructorFunc conv = variant_to_type(GDEXTENSION_VARIANT_TYPE_FLOAT);
	if (conv == nullptr) {
		return false;
	}
	// O construtor da interface recebe `GDExtensionVariantPtr` nao-const embora so leia (mesma
	// assimetria ja assumida na rota de String); o tipo ja foi exigido acima antes da conversao.
	conv(dst, reinterpret_cast<GDExtensionVariantPtr>(valor));
	return true;
}

// Exige o tipo STRING, converte para String crua, copia terminada em NUL e destrói a String
// temporaria (o destrutor por ponteiro solta a alocacao interna).
bool valor_como_texto(unsigned char * valor, char * dst, size_t cap) {
	if (variant_get_type(reinterpret_cast<GDExtensionConstVariantPtr>(valor)) !=
			GDEXTENSION_VARIANT_TYPE_STRING) {
		return false;
	}
	GDExtensionTypeFromVariantConstructorFunc conv = variant_to_type(GDEXTENSION_VARIANT_TYPE_STRING);
	if (conv == nullptr) {
		return false;
	}
	alignas(8) unsigned char stringo[32];
	// Mesma assimetria nao-const do construtor (so leitura); a String crua e destruida abaixo.
	conv(stringo, reinterpret_cast<GDExtensionVariantPtr>(valor));
	const bool ok = le_string(stringo, dst, cap);
	destroi_stringo(stringo);
	return ok;
}

// --- o Dictionary de req -> AfPromptReq --------------------------------------------------------
// Os campos de S5.3, o tipo aceito de cada um e o que acontece com campo AUSENTE (o
// zero-init do pedido e o que os tetos do corpo recusam nomeado):
//   role         String  -- ausente = "" = a recusa -4 nomeada do corpo;
//   prompt       String  -- ausente = "" = a recusa -2 nomeada do corpo;
//   max_tokens   INT     -- ausente = 0 = o padrao 64 do corpo (o payload do oraculo manda 64);
//   temperature  FLOAT   -- ausente = 0.0 (registrado; o Passo 3 decodifica greedy);
//   schema       String  -- ausente = ""; aceito e registrado, executado no Passo 5;
//   priority     INT     -- ausente = 0; aceito e registrado, a ordem de atendimento e FIFO;
//   context_ids  Array   -- ausente = contagem 0; a contagem completa e registrada e os 8
//                           primeiros ids sao copiados (o campo do AfPromptReq); a varredura
//                           tem teto 64 nomeado -- acima disso e recusa -2, porque um Array
//                           maior que isso e erro do chamador, nao um contexto.
// Tipo errado num campo PRESENTE e recusa -2 da ponte com o texto nomeado na superficie do
// prompt (`af_prompt_err_define`), para o GDScript ler um motivo so.
int64_t monta_req_de_dicto(const void * dicto_cru, GDExtensionConstVariantPtr dicto_variante) {
	if (dicto_cru == nullptr || dicto_variante == nullptr) {
		af_prompt_err_define("enqueue: o req chegou sem Dictionary legivel nas duas rotas");
		return -2;
	}
	GDExtensionPtrKeyedChecker check_fn = keyed_checker(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
	GDExtensionPtrKeyedGetter get_fn = keyed_getter(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
	if (check_fn == nullptr || get_fn == nullptr || variant_get_indexed == nullptr ||
			variant_new_nil == nullptr || variant_ptr_destructor == nullptr) {
		af_prompt_err_define("enqueue: a interface nao tem getter/checker/indice do Dictionary");
		return -2;
	}
	AfPromptReq req;
	memset(&req, 0, sizeof(req));
	alignas(8) unsigned char valor[32];
	bool ok = true;

	// Campos String: presente-errado recusa; ausente deixa o zero-init (que o corpo recusa
	// nomeado na porta).
	const unsigned char * k = chave("role");
	if (k != nullptr && check_fn(dicto_variante, k) != 0) {
		get_fn(dicto_cru, k, valor);
		ok = valor_como_texto(valor, req.role, sizeof(req.role));
		nil_varianto(valor);
		if (!ok) {
			af_prompt_err_define("enqueue: campo role tem de ser String");
			return -2;
		}
	}
	k = chave("prompt");
	if (k != nullptr && check_fn(dicto_variante, k) != 0) {
		get_fn(dicto_cru, k, valor);
		ok = valor_como_texto(valor, req.prompt, sizeof(req.prompt));
		nil_varianto(valor);
		if (!ok) {
			af_prompt_err_define("enqueue: campo prompt tem de ser String");
			return -2;
		}
	}
	k = chave("schema");
	if (k != nullptr && check_fn(dicto_variante, k) != 0) {
		get_fn(dicto_cru, k, valor);
		ok = valor_como_texto(valor, req.schema, sizeof(req.schema));
		nil_varianto(valor);
		if (!ok) {
			af_prompt_err_define("enqueue: campo schema tem de ser String");
			return -2;
		}
	}
	// Campos numericos.
	k = chave("max_tokens");
	if (k != nullptr && check_fn(dicto_variante, k) != 0) {
		get_fn(dicto_cru, k, valor);
		int64_t v = 0;
		ok = valor_como_int64(valor, &v);
		nil_varianto(valor);
		if (!ok) {
			af_prompt_err_define("enqueue: campo max_tokens tem de ser int");
			return -2;
		}
		req.max_tokens = (int32_t) v;
	}
	k = chave("temperature");
	if (k != nullptr && check_fn(dicto_variante, k) != 0) {
		get_fn(dicto_cru, k, valor);
		double v = 0.0;
		ok = valor_como_double(valor, &v);
		nil_varianto(valor);
		if (!ok) {
			af_prompt_err_define("enqueue: campo temperature tem de ser float");
			return -2;
		}
		req.temperature = v;
	}
	k = chave("priority");
	if (k != nullptr && check_fn(dicto_variante, k) != 0) {
		get_fn(dicto_cru, k, valor);
		int64_t v = 0;
		ok = valor_como_int64(valor, &v);
		nil_varianto(valor);
		if (!ok) {
			af_prompt_err_define("enqueue: campo priority tem de ser int");
			return -2;
		}
		req.priority = (int32_t) v;
	}
	// context_ids: Array de int. A contagem completa e registrada (o AfPromptReq guarda os 8
	// primeiros e a contagem, contrato do mind_prompt.h); acima do teto de varredura, recusa.
	k = chave("context_ids");
	if (k != nullptr && check_fn(dicto_variante, k) != 0) {
		get_fn(dicto_cru, k, valor);
		if (variant_get_type(reinterpret_cast<GDExtensionConstVariantPtr>(valor)) !=
				GDEXTENSION_VARIANT_TYPE_ARRAY) {
			nil_varianto(valor);
			af_prompt_err_define("enqueue: campo context_ids tem de ser Array de int");
			return -2;
		}
		const int TETO_VARREDURA_IDS = 64;
		alignas(8) unsigned char elemento[32];
		for (int i = 0; i < TETO_VARREDURA_IDS; ++i) {
			GDExtensionBool valido = 0;
			GDExtensionBool oob = 0;
			variant_get_indexed(reinterpret_cast<GDExtensionConstVariantPtr>(valor), i,
					reinterpret_cast<GDExtensionUninitializedVariantPtr>(elemento), &valido, &oob);
			if (oob) {
				break;
			}
			int64_t v = 0;
			if (valido) {
				ok = valor_como_int64(elemento, &v);
				if (!ok) {
					nil_varianto(elemento);
					nil_varianto(valor);
					char msg[96];
					snprintf(msg, sizeof(msg), "enqueue: context_ids so aceita int (indice %d)", i);
					af_prompt_err_define(msg);
					return -2;
				}
				if (req.context_count < 8) {
					req.context_ids[req.context_count] = v;
				}
				++req.context_count;
			}
			nil_varianto(elemento);
		}
		nil_varianto(valor);
		if (req.context_count > TETO_VARREDURA_IDS) {
			af_prompt_err_define("enqueue: context_ids passa do teto de 64 ids");
			return -2;
		}
	}
	return af_prompt_enqueue(&req);
}

// --- o Dictionary de saida do wait -------------------------------------------------------------
// Monta DIRETO no espaco do retorno (cru): o construtor por ponteiro inicializa a memoria crua
// e os setters por chave preenchem -- na rota Variant o chamador converte o Dictionary para o
// Variant de retorno e destrói o cru (a ref fica so do Variant), e na rota ptrcall o destino e
// o proprio retorno da engine, que passa a ser o dono. Os valores sao Variant cru temporario,
// fechado com nil apos o set.
bool monta_saida(void * destino, int64_t id, int64_t status, const char * motivo, const char * texto,
		int64_t decode_us, int32_t tokens_out) {
	GDExtensionPtrConstructor ctor = variant_ptr_constructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY, 0);
	GDExtensionPtrKeyedSetter set_fn = keyed_setter(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
	if (ctor == nullptr || set_fn == nullptr) {
		refuse("af_mind: sem construtor/setter por chave do Dictionary na interface", "monta_saida");
		return false;
	}
	// Sem as chaves crua (constroi_chaves falhou na inicializacao) o set por chave nula e crash
	// no processo da engine: recusa com motivo antes.
	if (chave("request_id") == nullptr || chave("status") == nullptr || chave("reason") == nullptr ||
			chave("text") == nullptr || chave("decode_us") == nullptr || chave("tokens_out") == nullptr) {
		refuse("af_mind: chaves do Dictionary de saida ausentes (constroi_chaves falhou)", "monta_saida");
		return false;
	}
	alignas(8) unsigned char vstr_local[32];
	alignas(8) unsigned char vv[32];
	GDExtensionVariantFromTypeConstructorFunc vint = variant_from_type(GDEXTENSION_VARIANT_TYPE_INT);
	GDExtensionVariantFromTypeConstructorFunc vstr = variant_from_type(GDEXTENSION_VARIANT_TYPE_STRING);
	if (vint == nullptr || vstr == nullptr || string_new_utf8 == nullptr) {
		refuse("af_mind: sem construtor Variant de int/String na interface", "monta_saida");
		return false;
	}
	ctor(reinterpret_cast<GDExtensionUninitializedTypePtr>(destino), nullptr);
	const unsigned char * k = nullptr;
	k = chave("request_id");
	vint(reinterpret_cast<GDExtensionUninitializedVariantPtr>(vv), &id);
	set_fn(destino, k, vv);
	nil_varianto(vv);
	k = chave("status");
	vint(reinterpret_cast<GDExtensionUninitializedVariantPtr>(vv), &status);
	set_fn(destino, k, vv);
	nil_varianto(vv);
	k = chave("decode_us");
	vint(reinterpret_cast<GDExtensionUninitializedVariantPtr>(vv), &decode_us);
	set_fn(destino, k, vv);
	nil_varianto(vv);
	k = chave("tokens_out");
	vint(reinterpret_cast<GDExtensionUninitializedVariantPtr>(vv), &tokens_out);
	set_fn(destino, k, vv);
	nil_varianto(vv);
	k = chave("reason");
	string_new_utf8(reinterpret_cast<GDExtensionUninitializedStringPtr>(vstr_local), motivo);
	vstr(reinterpret_cast<GDExtensionUninitializedVariantPtr>(vv), vstr_local);
	set_fn(destino, k, vv);
	nil_varianto(vv);
	destroi_stringo(vstr_local);
	k = chave("text");
	string_new_utf8(reinterpret_cast<GDExtensionUninitializedStringPtr>(vstr_local), texto);
	vstr(reinterpret_cast<GDExtensionUninitializedVariantPtr>(vv), vstr_local);
	set_fn(destino, k, vv);
	nil_varianto(vv);
	destroi_stringo(vstr_local);
	return true;
}

// O corpo do dispatch: `idx` na tabela, `args` sao ponteiros PARA AS STORAGENS CRUAS (String
// terminada em NUL ou int64) na ordem dos argumentos da tabela. Devolve o resultado e deixa em
// `e_texto` qual das duas metades vale. Um metodo novo entra na tabela e no switch, e o resto da
// ponte nao muda. `dicto_destino` e onde o wait monta o Dictionary de saida: a rota Variant
// passa a storage estatica e converte depois; a rota ptrcall passa o proprio r_ret da engine.
void executa(int32_t idx, const void * const * args, Resultado * r, bool * e_texto, void * dicto_destino) {
	r->numero = -1;
	r->texto[0] = '\0';
	r->e_dicto = false;
	*e_texto = false;
	switch (idx) {
		case M_SET_RUNTIME_DIR: r->numero = af_pack_preload_runtime((const char *) args[0]); break;
		case M_LOAD_PACK:
			// A troca de pack com pedidos na fila ou decodando faz o worker rodar o proximo
			// pedido contra o pack NOVO que nem era o dele, e descartar um ctx que a fila ainda
			// usa. A recusa e da ponte (o af_pack_load nao conhece a fila), o -5 nao existe no
			// codigo do pack, e o motivo nomeado sai na superficie do prompt.
			if (af_prompt_queue_depth() != 0) {
				af_prompt_err_define(
						"load_pack: ha pedidos na fila/decodando (queue_depth > 0); wait() o que existe antes de trocar o pack");
				r->numero = -5;
				break;
			}
			r->numero = af_pack_load((const char *) args[0], (const char *) args[1]);
			break;
		case M_CTX_PROBE: r->numero = af_pack_ctx_probe((int32_t) *(const int64_t *) args[0]); break;
		case M_PACK_STATE: r->numero = af_pack_state(); break;
		case M_PACK_NAME: copia_do_pack(af_pack_pack_name(), r, e_texto); return;
		case M_RUNTIME_DIR: copia_do_pack(af_pack_runtime_dir(), r, e_texto); return;
		case M_VRAM_TOTAL: r->numero = af_pack_vram_total(); break;
		case M_VRAM_BASE: r->numero = af_pack_vram_base(); break;
		case M_VRAM_USED: r->numero = af_pack_vram_used(); break;
		case M_VRAM_FREE: r->numero = af_pack_vram_free(); break;
		case M_LOAD_MS: r->numero = af_pack_load_ms(); break;
		case M_OPEN_MS: r->numero = af_pack_open_ms(); break;
		case M_BACKENDS: r->numero = af_pack_backends_loaded(); break;
		case M_CTX_CELLS: r->numero = af_pack_ctx_cells(); break;
		case M_CTX_READBACK: r->numero = af_pack_ctx_readback(); break;
		case M_CTX_STATE: r->numero = af_pack_state_bytes(); break;
		case M_CTX_TRAIN: r->numero = af_pack_ctx_train(); break;
		case M_CTX_WORD0: r->numero = af_pack_ctx_word0(); break;
		case M_N_BATCH: r->numero = af_pack_n_batch(); break;
		case M_N_UBATCH: r->numero = af_pack_n_ubatch(); break;
		case M_MODEL_BYTES: r->numero = af_pack_model_bytes(); break;
		case M_VOCAB: r->numero = af_pack_vocab_tokens(); break;
		case M_N_LAYER: r->numero = af_pack_n_layer(); break;
		case M_N_HEAD: r->numero = af_pack_n_head(); break;
		case M_N_HEAD_KV: r->numero = af_pack_n_head_kv(); break;
		case M_N_EMBD: r->numero = af_pack_n_embd(); break;
		case M_FTYPE: r->numero = af_pack_ftype(); break;
		case M_FTYPE_NAME: copia_do_pack(af_pack_ftype_name(), r, e_texto); return;
		case M_ARCH: copia_do_pack(af_pack_arch(), r, e_texto); return;
		case M_MODEL_DESC: copia_do_pack(af_pack_model_desc(), r, e_texto); return;
		case M_META_CTX: copia_do_pack(af_pack_meta_ctx(), r, e_texto); return;
		case M_META_COUNT: r->numero = af_pack_meta_count(); break;
		case M_META_KEY0: copia_do_pack(af_pack_meta_key0(), r, e_texto); return;
		case M_VERSION: copia_do_pack(af_pack_version_texto(), r, e_texto); return;
		case M_REG_COUNT: r->numero = af_pack_reg_count(); break;
		case M_DEV_COUNT: r->numero = af_pack_dev_count(); break;
		case M_VK_COUNT: r->numero = af_pack_vk_count(); break;
		case M_GPU_OFFLOAD: r->numero = af_pack_gpu_offload(); break;
		case M_HYBRID: r->numero = af_pack_hybrid(); break;
		case M_MODS_OPEN: r->numero = af_pack_mods_open(); break;
		case M_RSS_ANTES: r->numero = af_pack_rss_antes(); break;
		case M_RSS_APOS: r->numero = af_pack_rss_apos(); break;
		case M_ERR_STAGE: r->numero = af_pack_err_stage(); break;
		case M_ERR_CODE: r->numero = af_pack_err_code(); break;
		case M_ERR_WHICH: r->numero = af_pack_err_which(); break;
		case M_ERR_TEXT: copia_do_pack(af_pack_err_text(), r, e_texto); return;
		case M_VK_NAME: copia_do_pack(af_pack_vk_name(), r, e_texto); return;
		case M_VK_DESC: copia_do_pack(af_pack_vk_desc(), r, e_texto); return;
		case M_SLOT_CHECKSUM:
			// O bind que mantem `af_pack_slots` vivo no binario, e `af_pack_slots` e quem mantem a
			// tabela de imports inteira quando o linker esta sem `/OPT:REF` (S15.3). Devolve o
			// checksum, que o probe compara entre exe e DLL: MESMO checksum, MESMA lista nomeada.
			r->numero = af_pack_slots(0);
			break;
		// --- Passo 3 (S5.3): a API do prompt ------------------------------------------------
		case M_ENQUEUE:
			// args[0] = o Dictionary cru (base do getter por chave); args[1] = o Variant do
			// Dictionary (base da checker, que le VARIANTS). As duas rotas preenchem os dois.
			r->numero = monta_req_de_dicto(args[0], reinterpret_cast<GDExtensionConstVariantPtr>(args[1]));
			break;
		case M_WAIT: {
			// A FORMA de saida: request_id, status, reason, text, decode_us, tokens_out -- as
			// chaves de AfPromptOut, com o motivo no espaco da enum do mind_oracle.gd ("" no
			// sucesso, nomeada na recusa). O id desconhecido (ret < 0) tambem devolve Dictionary:
			// a forma nao muda com o codigo, e o motivo sai da superficie do prompt.
			const int64_t id = *(const int64_t *) args[0];
			AfPromptOut out_espaco;
			memset(&out_espaco, 0, sizeof(out_espaco));
			out_espaco.request_id = id;
			const int ret = af_prompt_wait(id, (int32_t) *(const int64_t *) args[1], &out_espaco);
			const int64_t status = (ret == 0) ? (int64_t) out_espaco.status : (int64_t) ret;
			const char * motivo = (ret == 0 || ret == 1) ? out_espaco.reason : af_prompt_err_text();
			if (monta_saida(dicto_destino, out_espaco.request_id, status, motivo, out_espaco.text,
						out_espaco.decode_us, out_espaco.tokens_out)) {
				r->e_dicto = true;
			} else {
				r->numero = -1;
			}
			break;
		}
		case M_QUEUE_DEPTH: r->numero = af_prompt_queue_depth(); break;
		case M_CACHE_HITS: r->numero = af_prompt_cache_hits(); break;
		case M_CACHE_MISSES: r->numero = af_prompt_cache_misses(); break;
		case M_VRAM_BYTES: r->numero = af_pack_vram_usado_agora(); break;
		case M_WORST_DECODE_US: r->numero = af_prompt_worst_decode_us(); break;
		case M_PROMPT_ERR_TEXT: copia_do_pack(af_prompt_err_text(), r, e_texto); return;
		default: break;
	}
}

// --- a rota Variant ---------------------------------------------------------------------------
// E a rota que o GDScript usa de fato (Object.callp). Cada argumento passa por
// `get_variant_to_type_constructor`, que e o conversor aceito da interface; tipo errado vira
// GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT com o indice, e nunca um cast cego.
void call_variant(void *method_userdata, GDExtensionClassInstancePtr p_instance,
		const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count,
		GDExtensionVariantPtr r_return, GDExtensionCallError *r_error) {
	(void)p_instance;
	const int32_t idx = (int32_t) (intptr_t) method_userdata;
	const Metodo & m = METODOS[idx];
	if (p_argument_count < (GDExtensionInt) m.n_args) {
		r_error->error = GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS;
		r_error->argument = (int32_t) p_argument_count;
		r_error->expected = m.n_args;
		return;
	}
	if (p_argument_count > (GDExtensionInt) m.n_args) {
		r_error->error = GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
		r_error->argument = m.n_args;
		r_error->expected = m.n_args;
		return;
	}
	const void * args[2] = { nullptr, nullptr };
	for (uint8_t i = 0; i < m.n_args; ++i) {
		if (variant_get_type(p_args[i]) != m.args[i].tipo) {
			r_error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
			r_error->argument = i;
			r_error->expected = (int32_t) m.args[i].tipo;
			return;
		}
		if (m.args[i].tipo == GDEXTENSION_VARIANT_TYPE_STRING) {
			GDExtensionTypeFromVariantConstructorFunc conv = variant_to_type(GDEXTENSION_VARIANT_TYPE_STRING);
			if (conv == nullptr) {
				refuse("af_mind: sem conversor Variant->String na interface", "call_variant");
				r_error->error = GDEXTENSION_CALL_ERROR_INVALID_METHOD;
				return;
			}
			// O construtor da interface recebe `GDExtensionVariantPtr` nao-const embora so leia:
			// e o que o proprio cabecalho declara, e a leitura do argumento Original fica sob
			// contrato da engine. O cast e o custo de chamar a via aceita.
			conv(arg_str_storage[i], (GDExtensionVariantPtr) p_args[i]);
			if (!le_string(arg_str_storage[i], arg_str_texto[i], ARG_CAP)) {
				r_error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
				r_error->argument = i;
				r_error->expected = (int32_t) GDEXTENSION_VARIANT_TYPE_STRING;
				return;
			}
			args[i] = arg_str_texto[i];
		} else if (m.args[i].tipo == GDEXTENSION_VARIANT_TYPE_INT) {
			GDExtensionTypeFromVariantConstructorFunc conv = variant_to_type(GDEXTENSION_VARIANT_TYPE_INT);
			if (conv == nullptr) {
				refuse("af_mind: sem conversor Variant->int64 na interface", "call_variant");
				r_error->error = GDEXTENSION_CALL_ERROR_INVALID_METHOD;
				return;
			}
			conv(&arg_int_storage[i], (GDExtensionVariantPtr) p_args[i]);
			args[i] = &arg_int_storage[i];
		} else if (m.args[i].tipo == GDEXTENSION_VARIANT_TYPE_DICTIONARY) {
			// Passo 3: o Dictionary cru vai para a storage (base do getter por chave) e o Variant
			// ORIGINAL segue para o slot vizinho, que e o que a checker por chave le -- nenhum
			// metodo daqui tem dois Dictionary, e o slot vizinho de um metodo de 1 argumento nao
			// e lido pelo executa.
			GDExtensionTypeFromVariantConstructorFunc conv = variant_to_type(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
			if (conv == nullptr) {
				refuse("af_mind: sem conversor Variant->Dictionary na interface", "call_variant");
				r_error->error = GDEXTENSION_CALL_ERROR_INVALID_METHOD;
				return;
			}
			conv(arg_dict_storage, (GDExtensionVariantPtr) p_args[i]);
			args[i] = arg_dict_storage;
			args[i == 0 ? 1 : 0] = (const void *) p_args[i];
		}
	}
	Resultado res = {};
	bool e_texto = false;
	executa(idx, args, &res, &e_texto, dicto_saida_storage);
	if (res.e_dicto) {
		// O Dictionary cru montado no executa vira Variant pelo construtor tipo->Variant e o cru
		// e destruido pelo destrutor por ponteiro: a referencia fica so do Variant de retorno.
		GDExtensionVariantFromTypeConstructorFunc conv = variant_from_type(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
		if (conv == nullptr) {
			refuse("af_mind: sem construtor Variant de Dictionary na interface", "call_variant");
			r_error->error = GDEXTENSION_CALL_ERROR_INVALID_METHOD;
			return;
		}
		conv(r_return, dicto_saida_storage);
		GDExtensionPtrDestructor d = variant_ptr_destructor != nullptr
				? variant_ptr_destructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY) : nullptr;
		if (d != nullptr) {
			d(dicto_saida_storage);
		}
	} else if (e_texto) {
		// String crua na storage de retorno, e o construtor tipo->Variant a copia para dentro do
		// Variant de retorno. O construtor e a via aceita da interface; montar a Variant a mao
		// seria palpite de layout da engine.
		string_new_utf8(reinterpret_cast<GDExtensionUninitializedStringPtr>(ret_str_storage), res.texto);
		GDExtensionVariantFromTypeConstructorFunc conv = variant_from_type(GDEXTENSION_VARIANT_TYPE_STRING);
		if (conv == nullptr) {
			refuse("af_mind: sem construtor Variant de String na interface", "call_variant");
			r_error->error = GDEXTENSION_CALL_ERROR_INVALID_METHOD;
			return;
		}
		conv(r_return, ret_str_storage);
	} else {
		int64_t num = res.numero;
		GDExtensionVariantFromTypeConstructorFunc conv = variant_from_type(GDEXTENSION_VARIANT_TYPE_INT);
		if (conv == nullptr) {
			refuse("af_mind: sem construtor Variant de int64 na interface", "call_variant");
			r_error->error = GDEXTENSION_CALL_ERROR_INVALID_METHOD;
			return;
		}
		conv(r_return, &num);
	}
	r_error->error = GDEXTENSION_CALL_OK;
}

// --- a rota ptrcall ---------------------------------------------------------------------------
// Os argumentos chegam JA em forma crua (`GDExtensionConstTypePtr` = ponteiro para o tipo), porque
// quem chama por aqui e a engine com os tipos ja sabidos. String arg = ponteiro para String da
// engine; int arg = ponteiro para int64; retorno int = escrever int64; retorno String = CONSTRUIR
// String no lugar (`string_new_with_utf8_chars` constroi em storage nao inicializada, e uma String
// vazia pre-construida na storage nao tem alocacao nenhuma, entao as duas hipoteses sao seguras).
void ptrcall(void *method_userdata, GDExtensionClassInstancePtr p_instance,
		const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret) {
	(void)p_instance;
	const int32_t idx = (int32_t) (intptr_t) method_userdata;
	const Metodo & m = METODOS[idx];
	const void * args[2] = { nullptr, nullptr };
	char texto_local[2][ARG_CAP];
	int64_t numero_local[2] = { 0, 0 };
	// Passo 3: o Variant cru construido sobre o Dictionary cru do argumento (o que a checker por
	// chave le). Storage local, inicializada a cada chamada, fechada com nil depois do executa.
	alignas(8) unsigned char dicto_variante_local[2][32];
	bool dicto_no_slot[2] = { false, false };
	for (uint8_t i = 0; i < m.n_args; ++i) {
		if (m.args[i].tipo == GDEXTENSION_VARIANT_TYPE_STRING) {
			if (le_string(reinterpret_cast<const unsigned char *>(p_args[i]), texto_local[i], ARG_CAP)) {
				args[i] = texto_local[i];
			} else {
				args[i] = "";
			}
		} else if (m.args[i].tipo == GDEXTENSION_VARIANT_TYPE_INT) {
			if (p_args[i] != nullptr) {
				numero_local[i] = *(const int64_t *) p_args[i];
			}
			args[i] = &numero_local[i];
		} else if (m.args[i].tipo == GDEXTENSION_VARIANT_TYPE_DICTIONARY) {
			// Na rota ptrcall o argumento JA e o Dictionary cru: ele e o proprio base do getter,
			// e o Variant que a checker le nasce do construtor tipo->Variant aceito.
			GDExtensionVariantFromTypeConstructorFunc conv = variant_from_type(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
			if (conv == nullptr) {
				// Sem canal de erro aqui: a recusa fica impressa e o executa le os ponteiros
				// nulos, que e a recusa -2 nomeada do monta_req.
				refuse("af_mind: sem construtor Variant de Dictionary na interface", "ptrcall");
				args[i] = nullptr;
				continue;
			}
			conv(reinterpret_cast<GDExtensionUninitializedVariantPtr>(dicto_variante_local[i]),
					const_cast<GDExtensionTypePtr>(p_args[i]));
			args[i] = p_args[i];
			args[i == 0 ? 1 : 0] = dicto_variante_local[i];
			dicto_no_slot[i] = true;
		}
	}
	Resultado res = {};
	bool e_texto = false;
	// O Dictionary de saida do wait e montado DIRETO no espaco do retorno: na rota ptrcall o
	// destino e o proprio r_ret da engine, que passa a ser o dono dele.
	executa(idx, args, &res, &e_texto, r_ret);
	for (uint8_t i = 0; i < m.n_args; ++i) {
		if (dicto_no_slot[i]) {
			nil_varianto(dicto_variante_local[i]);
		}
	}
	if (res.e_dicto) {
		// O executa ja montou o Dictionary de saida DENTRO do r_ret: nada a converter aqui.
	} else if (e_texto) {
		string_new_utf8(reinterpret_cast<GDExtensionUninitializedStringPtr>(r_ret), res.texto);
	} else {
		*(int64_t *) r_ret = res.numero;
	}
}

// As storages ESTATICAS dos infos de registro: o `classdb_register_extension_class_method` copia o
// que precisa no ato (doc do proprio metodo), entao static e o contrato documentado, nao um risco.
// `usage = 6` e STORAGE|EDITOR do enum `PropertyUsageFlags` da engine -- o cabecalho vendorado nao
// traz as constantes (`GDEXTENSION_PROPERTY_USAGE_*` nao existe nele), e o literal e o que o
// godot-cpp manda para uma propriedade de script exposta.
GDExtensionPropertyInfo ret_infos[M_TOTAL];
GDExtensionPropertyInfo arg_infos[M_TOTAL][2];
GDExtensionClassMethodArgumentMetadata ret_meta[M_TOTAL];
GDExtensionClassMethodArgumentMetadata arg_meta[M_TOTAL][2];
alignas(8) unsigned char sn_method_storage[M_TOTAL][32];
alignas(8) unsigned char sn_arg_storage[M_TOTAL][2][32];

void register_methods() {
	for (int32_t i = 0; i < M_TOTAL; ++i) {
		const Metodo & m = METODOS[i];
		string_name_new(sn_method_storage[i], m.nome, 1);
		for (uint8_t a = 0; a < m.n_args; ++a) {
			string_name_new(sn_arg_storage[i][a], m.args[a].nome, 1);
			arg_infos[i][a].type = m.args[a].tipo;
			arg_infos[i][a].name = reinterpret_cast<GDExtensionStringNamePtr>(sn_arg_storage[i][a]);
			arg_infos[i][a].class_name = reinterpret_cast<GDExtensionStringNamePtr>(sn_empty_storage);
			arg_infos[i][a].hint = 0;
			arg_infos[i][a].hint_string = reinterpret_cast<GDExtensionStringPtr>(str_empty_storage);
			arg_infos[i][a].usage = 6; // STORAGE|EDITOR: o literal, porque o header nao traz o enum
			arg_meta[i][a] = (m.args[a].tipo == GDEXTENSION_VARIANT_TYPE_INT)
					? GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64
					: GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
		}
		ret_infos[i].type = m.retorna_dicto ? GDEXTENSION_VARIANT_TYPE_DICTIONARY
				: (m.retorna_texto ? GDEXTENSION_VARIANT_TYPE_STRING : GDEXTENSION_VARIANT_TYPE_INT);
		ret_infos[i].name = reinterpret_cast<GDExtensionStringNamePtr>(sn_method_storage[i]);
		ret_infos[i].class_name = reinterpret_cast<GDExtensionStringNamePtr>(sn_empty_storage);
		ret_infos[i].hint = 0;
		ret_infos[i].hint_string = reinterpret_cast<GDExtensionStringPtr>(str_empty_storage);
		ret_infos[i].usage = 6; // STORAGE|EDITOR
		ret_meta[i] = (m.retorna_dicto || m.retorna_texto) ? GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE
				: GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64;

		GDExtensionClassMethodInfo mi = {};
		mi.name = reinterpret_cast<GDExtensionStringNamePtr>(sn_method_storage[i]);
		mi.method_userdata = (void *) (intptr_t) i;
		mi.call_func = &call_variant;
		mi.ptrcall_func = &ptrcall;
		mi.method_flags = GDEXTENSION_METHOD_FLAGS_DEFAULT;
		mi.has_return_value = 1;
		mi.return_value_info = &ret_infos[i];
		mi.return_value_metadata = ret_meta[i];
		mi.argument_count = m.n_args;
		mi.arguments_info = m.n_args > 0 ? arg_infos[i] : nullptr;
		mi.arguments_metadata = m.n_args > 0 ? arg_meta[i] : nullptr;
		mi.default_argument_count = 0;
		mi.default_arguments = nullptr;
		register_extension_class_method(library, class_name_sn(), &mi);
	}
}

// --- Passo 3: o registro dos tres sinais de S5.3 ----------------------------------------------
// Os sinais EXISTEM na superficie da classe (conectar e medido no runner), mas a EMISSAO e
// [ABERTA]: o header vendorado 4.7.2 nao traz `object_emit_signal` nem `object_callp`, e o bind
// que emitiria exige hashes que so o extension_api.json da engine teria (S12.2). O registro vai
// aqui para o contrato de S5.3 existir inteiro na ClassDB e para a rota de emissao do Passo 4/5
// encontrar a classe pronta.
alignas(8) unsigned char sn_sinal_storage[3][32];
alignas(8) unsigned char sn_sinal_arg_storage[5][32];

void registra_sinais() {
	struct ArgSinal {
		GDExtensionVariantType tipo;
		const char * nome;
	};
	struct Sinal {
		const char * nome;
		int n_args;
		ArgSinal args[2];
	};
	const Sinal SINAIS[3] = {
		{ "inference_completed", 2, { { GDEXTENSION_VARIANT_TYPE_INT, "request_id" }, { GDEXTENSION_VARIANT_TYPE_DICTIONARY, "output" } } },
		{ "pack_loaded", 1, { { GDEXTENSION_VARIANT_TYPE_STRING, "name" }, { GDEXTENSION_VARIANT_TYPE_NIL, "" } } },
		{ "pack_failed", 2, { { GDEXTENSION_VARIANT_TYPE_STRING, "name" }, { GDEXTENSION_VARIANT_TYPE_STRING, "reason" } } },
	};
	GDExtensionPropertyInfo infos[3][2];
	int arg_slot = 0;
	for (int s = 0; s < 3; ++s) {
		string_name_new(sn_sinal_storage[s], SINAIS[s].nome, 1);
		for (int a = 0; a < SINAIS[s].n_args; ++a) {
			const int slot = arg_slot++;
			string_name_new(sn_sinal_arg_storage[slot], SINAIS[s].args[a].nome, 1);
			infos[s][a].type = SINAIS[s].args[a].tipo;
			infos[s][a].name = reinterpret_cast<GDExtensionStringNamePtr>(sn_sinal_arg_storage[slot]);
			infos[s][a].class_name = reinterpret_cast<GDExtensionStringNamePtr>(sn_empty_storage);
			infos[s][a].hint = 0;
			infos[s][a].hint_string = reinterpret_cast<GDExtensionStringPtr>(str_empty_storage);
			infos[s][a].usage = 6; // STORAGE|EDITOR: o mesmo literal dos metodos
		}
		register_extension_class_signal(library, class_name_sn(), sn_sinal_storage[s], infos[s],
				SINAIS[s].n_args);
	}
}

void initialize_cb(void *p_userdata, GDExtensionInitializationLevel p_level) {
	(void)p_userdata;
	if (p_level != GDEXTENSION_INITIALIZATION_CORE || class_registered) {
		return;
	}
	GDExtensionClassCreationInfo6 info = {};
	info.is_exposed = 1;
	info.is_runtime = 1;
	info.create_instance_func = &create_instance;
	info.free_instance_func = &free_instance;
	register_extension_class6(library, class_name_sn(), parent_name_sn(), &info);
	class_registered = true;
	// As grandezas comecam em -1 ("nao medido") e nao em 0 (que parece leitura): sem o init, um
	// getter chamado antes de qualquer load devolveria 0 e a pagina teria que adivinhar se 0 e
	// medicao ou acaso.
	af_pack_init();
	register_methods();
	registra_sinais();
	// As chaves crua do req/saida do enqueue/wait: construidas UMA vez aqui, vividas pelo
	// processo. Se faltarem, o enqueue recusa nomeado em runtime (a chave vira "campo ausente")
	// e a recusa de carga imprime o motivo agora, na inicializacao.
	if (!constroi_chaves()) {
		refuse("af_mind: sem construtor Variant de String para as chaves do req do enqueue", "initialize_cb");
	}
}

void deinitialize_cb(void *p_userdata, GDExtensionInitializationLevel p_level) {
	(void)p_userdata;
	if (p_level == GDEXTENSION_INITIALIZATION_CORE && class_registered) {
		unregister_extension_class(library, class_name_sn());
		class_registered = false;
	}
}

template <typename T>
T load_proc(GDExtensionInterfaceGetProcAddress p_get_proc_address, const char *p_name) {
	return reinterpret_cast<T>(p_get_proc_address(p_name));
}

// `print_error` e a saida de recusa desta extensao: um `printf` no stderr do
// processo ia para o lugar errado quando a engine roda dentro do editor. Nada de log de
// conteudo: as linhas daqui sao de arquitetura (sem proc, sem conversor), nunca de dado.
void refuse(const char *p_message, const char *p_function) {
	if (print_error_fn != nullptr) {
		print_error_fn(p_message, p_function, __FILE__, __LINE__, 0);
	}
}

} // namespace

// O nome tem de bater com `entry_symbol` do `af_mind.gdextension`: e assim que a engine
// acha o ponto de entrada. O `#if` existe porque exportar simbolo e do PE, nao do C++.
#if defined(_WIN32)
#define AF_MIND_EXPORT extern "C" __declspec(dllexport)
#else
#define AF_MIND_EXPORT extern "C"
#endif

AF_MIND_EXPORT GDExtensionBool af_mind_entry(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	library = p_library;

	print_error_fn = load_proc<GDExtensionInterfacePrintError>(p_get_proc_address, "print_error");
	string_name_new = load_proc<GDExtensionInterfaceStringNameNewWithLatin1Chars>(p_get_proc_address, "string_name_new_with_latin1_chars");
	register_extension_class6 = load_proc<GDExtensionInterfaceClassdbRegisterExtensionClass6>(p_get_proc_address, "classdb_register_extension_class6");
	unregister_extension_class = load_proc<GDExtensionInterfaceClassdbUnregisterExtensionClass>(p_get_proc_address, "classdb_unregister_extension_class");
	construct_object3 = load_proc<GDExtensionInterfaceClassdbConstructObject3>(p_get_proc_address, "classdb_construct_object3");
	set_instance = load_proc<GDExtensionInterfaceObjectSetInstance>(p_get_proc_address, "object_set_instance");
	get_godot_version2 = load_proc<GDExtensionInterfaceGetGodotVersion2>(p_get_proc_address, "get_godot_version2");

	register_extension_class_method = load_proc<GDExtensionInterfaceClassdbRegisterExtensionClassMethod>(p_get_proc_address, "classdb_register_extension_class_method");
	string_new_utf8 = load_proc<GDExtensionInterfaceStringNewWithUtf8Chars>(p_get_proc_address, "string_new_with_utf8_chars");
	string_to_utf8_chars = load_proc<GDExtensionInterfaceStringToUtf8Chars>(p_get_proc_address, "string_to_utf8_chars");
	variant_from_type = load_proc<GDExtensionInterfaceGetVariantFromTypeConstructor>(p_get_proc_address, "get_variant_from_type_constructor");
	variant_to_type = load_proc<GDExtensionInterfaceGetVariantToTypeConstructor>(p_get_proc_address, "get_variant_to_type_constructor");
	variant_get_type = load_proc<GDExtensionInterfaceVariantGetType>(p_get_proc_address, "variant_get_type");

	// Passo 3: leitura e montagem de Dictionary, indice de Array, fechamento de Variant
	// temporario e o registro dos sinais de S5.3.
	keyed_getter = load_proc<GDExtensionInterfaceVariantGetPtrKeyedGetter>(p_get_proc_address, "variant_get_ptr_keyed_getter");
	keyed_setter = load_proc<GDExtensionInterfaceVariantGetPtrKeyedSetter>(p_get_proc_address, "variant_get_ptr_keyed_setter");
	keyed_checker = load_proc<GDExtensionInterfaceVariantGetPtrKeyedChecker>(p_get_proc_address, "variant_get_ptr_keyed_checker");
	variant_ptr_constructor = load_proc<GDExtensionInterfaceVariantGetPtrConstructor>(p_get_proc_address, "variant_get_ptr_constructor");
	variant_ptr_destructor = load_proc<GDExtensionInterfaceVariantGetPtrDestructor>(p_get_proc_address, "variant_get_ptr_destructor");
	variant_get_indexed = load_proc<GDExtensionInterfaceVariantGetIndexed>(p_get_proc_address, "variant_get_indexed");
	variant_new_nil = load_proc<GDExtensionInterfaceVariantNewNil>(p_get_proc_address, "variant_new_nil");
	register_extension_class_signal = load_proc<GDExtensionInterfaceClassdbRegisterExtensionClassSignal>(p_get_proc_address, "classdb_register_extension_class_signal");

	// S12.2: a versao da interface nao e um `#define` do cabecalho -- e o que a engine devolve
	// em runtime. Estes nomes so existem a partir da 4.7, entao a ausencia de qualquer um
	// deles e a prova de que esta engine nao e a que o `build.bat` conferiu, e a extensao
	// recusa carregar em vez de chamar ponteiro nulo.
	if (string_name_new == nullptr || register_extension_class6 == nullptr ||
			unregister_extension_class == nullptr || construct_object3 == nullptr || set_instance == nullptr ||
			register_extension_class_method == nullptr || string_new_utf8 == nullptr ||
			string_to_utf8_chars == nullptr || variant_from_type == nullptr || variant_to_type == nullptr ||
			variant_get_type == nullptr || keyed_getter == nullptr || keyed_setter == nullptr ||
			keyed_checker == nullptr || variant_ptr_constructor == nullptr || variant_ptr_destructor == nullptr ||
			variant_get_indexed == nullptr || variant_new_nil == nullptr ||
			register_extension_class_signal == nullptr) {
		refuse("af_mind: a engine nao e a ABI 4.7.2 cuja interface esta em include/", "af_mind_entry");
		return 0;
	}

	if (get_godot_version2 != nullptr) {
		GDExtensionGodotVersion2 v = {};
		get_godot_version2(&v);
		if (v.major != 4 || v.minor < 7) {
			refuse("af_mind: get_godot_version2 devolve uma engine menor que 4.7", "af_mind_entry");
			return 0;
		}
	}

	// `p_is_static = 1` porque as literais vivem o quanto o processo viver -- a condicao que
	// o proprio doc da funcao exige de quem a usa. O par vazio existe porque toda
	// PropertyInfo pede `class_name` e `hint_string`, e os infos sao copiados no ato.
	string_name_new(sn_class_storage, CLASS_NAME, 1);
	string_name_new(sn_parent_storage, PARENT_NAME, 1);
	string_name_new(sn_empty_storage, "", 1);
	string_new_utf8(reinterpret_cast<GDExtensionUninitializedStringPtr>(str_empty_storage), "");

	r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_CORE;
	r_initialization->userdata = p_library;
	r_initialization->initialize = &initialize_cb;
	r_initialization->deinitialize = &deinitialize_cb;

	return 1;
}
