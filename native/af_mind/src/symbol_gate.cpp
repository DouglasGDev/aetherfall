// Passo 2 (a) do dossie 22 (S1.2, S1.3, S5.1): o gate de simbolos, executado.
//
// Este programa NAO e a extensao e nao e um binding. E o gate que o S1.3 exigiu antes de
// qualquer binding existir: uma binaria minima que resolve os simbolos pelas bibliotecas de
// importacao geradas do export-set MEDIDO, chama o que o `.dll` realmente exporta e imprime
// os numeros. `af_mind.dll` so comeca a encostar no runtime depois que este gate fechar.
//
// Por que os prototipos estao escritos a mao aqui embaixo: nao ha `llama.h` nem `ggml.h` na
// arvore, e o S1.3 mediu que o export-set pinado e outro do que a documentacao de um llama.cpp
// qualquer descreve -- `llama_model_n_ctx`, por exemplo, nao existe em nenhuma das cinco DLLs;
// quem existe e `llama_model_n_ctx_train`. O dumpbin so devolve nome e ordinal, nunca
// assinatura. Entao este arquivo divide os simbolos em duas classes, e a divisao e o conteudo
// do gate:
//
//  CHAMADOS -- os dez nomes cuja assinatura a sonda da Fase 0 chamou e teve numero devolvido.
//              As assinaturas abaixo sao transcritas de
//              docs/evidence/oraculo-nativo-22/af_native_probe3.cpp:17-26, linha a linha, com
//              as tres surpresas que a transcricao obriga a ver: `reg_count`, `dev_count` e
//              `load_all_from_path` devolvem `size_t` (nao `int`); `reg_get` e `dev_get`
//              recebem o INDICE POR VALOR e devolvem o opaco por valor (nao ponteiro para); e
//              `ggml_backend_dev_description` tem UM argumento e devolve `const char *` -- nao
//              a forma `(dev, buf, size)` que a leitura de um header qualquer sugere. Copiar a
//              assinatura do documento, em vez de copiar a da sonda, e exatamente o erro que o
//              S12.2 mediu duas vezes.
//  ENDERECADOS -- os nomes que o gate forca a existir na tabela de imports sem nenhuma
//              afirmacao de assinatura. Estes estao declarados como DADO
//              (`extern "C" void *nome;`), nao como funcao: o que o linker devolve e o slot
//              `__imp_<nome>`, e um slot nao pode ser chamado por engano. De-los como funcao
//              seria afirmar uma assinatura que ninguem mediu; a afirmacao que este gate faz
//              sobre eles e a de EXISTENCIA, que e tambem a unica que o dumpbin sustenta.
//
// Os tres blocos de saida, na ordem em que rodam:
//
//  1. `[exe]` e `[simbolo]` -- o diretorio do processo lido e o slot de cada nome importado;
//     o que testemunha aqui e o ENDERECO do slot, nunca o valor: o valor de um delay-load nao
//     resolvido e lixo ate a primeira chamada, e lixo impresso pareceria "nao resolveu";
//  2. `[premissa]` -- a checagem de que o loader ve as DLLs do runtime pelo nome nu, isto e,
//     pelo diretorio do processo (S5.1 empurrou essa premissa para o Passo 2);
//  3. `[gate]` -- com o runtime alcanado, os numeros que S1.2 publicou: reg_count, o nome de
//     cada registro, dev_count, tipo/nome/descricao de cada dispositivo e o contador vk.
//
// O exe e rodado de pe, fora do Godot: e o lugar onde uma ABI errada e um achado impresso em
// vez de um `SCRIPT ERROR` que derruba checagens em silencio (mandato 1).

#include <windows.h>

#include <cstddef>
#include <cstdio>
#include <cstring>

// Os opacos do ggml: nunca interpretados aqui, apenas passados de volta para o proprio ggml.
struct ggml_backend_reg_st;
struct ggml_backend_dev_st;
typedef ggml_backend_reg_st * ggml_backend_reg_t;
typedef ggml_backend_dev_st * ggml_backend_dev_t;

// --- os chamados: assinaturas transcritas de af_native_probe3.cpp:17-26 ------------------
extern "C" {
size_t ggml_backend_load_all_from_path(const char * dir_path);
size_t ggml_backend_reg_count(void);
ggml_backend_reg_t ggml_backend_reg_get(size_t index);
const char * ggml_backend_reg_name(ggml_backend_reg_t reg);
size_t ggml_backend_dev_count(void);
ggml_backend_dev_t ggml_backend_dev_get(size_t index);
const char * ggml_backend_dev_name(ggml_backend_dev_t dev);
const char * ggml_backend_dev_description(ggml_backend_dev_t dev);
int ggml_backend_dev_type(ggml_backend_dev_t dev);
int ggml_backend_vk_get_device_count(void);
}

// --- os enderecados: dados `extern "C"`, para o import existir sem assinatura afirmada ----
// Cada nome abaixo foi conferido no `.def` gerado do dumpbin arquivado, e o comentario diz em
// QUE DLL ele está -- que e justamente a testemunha que a sonda terceira precisou (um binding
// que resolve do modulo errado recebe NULL em silencio). Nomes que a documentacao do llama.cpp
// conhece e o export-set pinado nao tem (`llama_new_context_with_model`,
// `llama_backend_buffer_type_get_alloc_size`, `ggml_base_free`) NAO aparecem aqui: vao para o
// controle negativo, onde a ausencia e a afirmacao.
extern "C" {
// ggml-base.dll (689 nomes)
extern void * ggml_backend_free;
extern void * ggml_backend_dev_memory;
extern void * ggml_backend_buffer_get_type;
extern void * ggml_backend_buffer_get_alloc_size;
extern void * ggml_backend_buft_name;
extern void * ggml_backend_buft_get_alloc_size;
// ggml-vulkan.dll (9 nomes)
extern void * ggml_backend_vk_buffer_type;
extern void * ggml_backend_vk_get_device_description;
extern void * ggml_backend_vk_get_device_memory;
// llama.dll (266 nomes; 240 C-puros, os unicos que os `.def` trazem)
extern void * llama_backend_init;
extern void * llama_backend_free;
extern void * llama_model_default_params;
extern void * llama_model_load_from_file;
extern void * llama_context_default_params;
extern void * llama_init_from_model;
extern void * llama_model_meta_count;
extern void * llama_model_meta_val_str;
extern void * llama_model_n_ctx_train;
extern void * llama_n_ctx;
extern void * llama_vocab_n_tokens;
extern void * llama_batch_init;
extern void * llama_batch_free;
extern void * llama_tokenize;
extern void * llama_chat_apply_template;
extern void * llama_decode;
extern void * llama_print_system_info;
extern void * llama_supports_gpu_offload;
}

#define AF_SLOT(nome) printf("[simbolo] slot " #nome "=%p\n", (void *) &(nome))

static void simbolos() {
	// Chamados: o thunk que o delay-load preenche na primeira chamada. Enderecados: o slot
	// __imp_ do import. Nos dois casos o que se imprime e o ENDERECO do slot -- a existencia
	// do import, que o linker so deixou passar se o nome estava num dos `.def`.
	AF_SLOT(ggml_backend_load_all_from_path);
	AF_SLOT(ggml_backend_reg_count);
	AF_SLOT(ggml_backend_reg_get);
	AF_SLOT(ggml_backend_reg_name);
	AF_SLOT(ggml_backend_dev_count);
	AF_SLOT(ggml_backend_dev_get);
	AF_SLOT(ggml_backend_dev_name);
	AF_SLOT(ggml_backend_dev_description);
	AF_SLOT(ggml_backend_dev_type);
	AF_SLOT(ggml_backend_vk_get_device_count);
	AF_SLOT(ggml_backend_free);
	AF_SLOT(ggml_backend_dev_memory);
	AF_SLOT(ggml_backend_buffer_get_type);
	AF_SLOT(ggml_backend_buffer_get_alloc_size);
	AF_SLOT(ggml_backend_buft_name);
	AF_SLOT(ggml_backend_buft_get_alloc_size);
	AF_SLOT(ggml_backend_vk_buffer_type);
	AF_SLOT(ggml_backend_vk_get_device_description);
	AF_SLOT(ggml_backend_vk_get_device_memory);
	AF_SLOT(llama_backend_free);
	AF_SLOT(llama_backend_init);
	AF_SLOT(llama_model_default_params);
	AF_SLOT(llama_model_load_from_file);
	AF_SLOT(llama_context_default_params);
	AF_SLOT(llama_init_from_model);
	AF_SLOT(llama_model_meta_count);
	AF_SLOT(llama_model_meta_val_str);
	AF_SLOT(llama_model_n_ctx_train);
	AF_SLOT(llama_n_ctx);
	AF_SLOT(llama_vocab_n_tokens);
	AF_SLOT(llama_batch_init);
	AF_SLOT(llama_batch_free);
	AF_SLOT(llama_tokenize);
	AF_SLOT(llama_chat_apply_template);
	AF_SLOT(llama_decode);
	AF_SLOT(llama_print_system_info);
	AF_SLOT(llama_supports_gpu_offload);
	fflush(stdout);
}

// Abre pelo caminho literal (dir nao vazio) ou pelo nome nu (dir vazio), sempre com a busca
// alterada -- a mesma flag com que a sonda de S1.2 abriu as quatro DLLs. Devolve o handle; em
// falha escreve o codigo do loader no ponteiro indicado.
// Os tres `_s`/`snprintf` aqui sao a forma segura DA CASA para este exe: o `build.bat` nao passa
// `_CRT_SECURE_NO_WARNINGS` porque a flag e um silenciar, e o warning C4996 no log verde seria o
// instrumento pedindo para nao ser lido. `snprintf` garante o NUL, os `_s` recusam estouro.
static HMODULE abrir(const char * dir, const char * nome, unsigned long * erro) {
	char caminho[MAX_PATH] = {0};
	if (dir == nullptr || dir[0] == '\0') {
		strcpy_s(caminho, MAX_PATH, nome);
	} else {
		snprintf(caminho, MAX_PATH, "%s\\%s", dir, nome);
	}
	*erro = 0;
	HMODULE h = LoadLibraryExA(caminho, nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
	if (h == nullptr) {
		*erro = GetLastError();
	}
	return h;
}

// Onde este exe esta. A premissa do S5.1 e sobre o DIRETORIO DO PROCESSO, entao o log tem de
// dizer qual diretorio o loader procurou, nao so se ele achou.
static char g_exe_dir[MAX_PATH] = {0};
static void onde_estou() {
	char exe[MAX_PATH] = {0};
	DWORD n = GetModuleFileNameA(nullptr, exe, MAX_PATH - 1);
	if (n > 0) {
		strcpy_s(g_exe_dir, MAX_PATH, exe);
		char * corte = strrchr(g_exe_dir, '\\');
		if (corte != nullptr) {
			*corte = '\0';
		}
	}
	char cwd[MAX_PATH] = {0};
	DWORD c = GetCurrentDirectoryA(MAX_PATH - 1, cwd);
	printf("[exe] caminho=%s\n", n > 0 ? exe : "<sem nome>");
	printf("[exe] diretorio_do_processo=%s\n", n > 0 ? g_exe_dir : "<sem diretorio>");
	printf("[exe] cwd=%s\n", c > 0 ? cwd : "<sem cwd>");
	fflush(stdout);
}

// Os numeros que S1.2 publicou, chamando so o que a sonda chamou.
static int gate(const char * runtime) {
	const size_t carregados = ggml_backend_load_all_from_path(runtime);
	// S1.2 mediu 0 aqui, e o proprio S1.2 explica: nao e "zero backends", e "zero backends
	// REGISTRADOS NAQUELA CHAMADA", porque os tres ja estavam no registro quando o
	// ggml-vulkan.dll foi carregado. O numero continua impresso como testemunha.
	printf("[gate] load_all_from_path=%zu\n", carregados);

	const size_t regs = ggml_backend_reg_count();
	printf("[gate] reg_count=%zu\n", regs);
	for (size_t i = 0; i < regs; ++i) {
		const ggml_backend_reg_t r = ggml_backend_reg_get(i);
		printf("[gate]   reg[%zu] nome=%s\n", i, r != nullptr ? ggml_backend_reg_name(r) : "<nulo>");
	}

	const size_t devs = ggml_backend_dev_count();
	printf("[gate] dev_count=%zu\n", devs);
	for (size_t i = 0; i < devs; ++i) {
		const ggml_backend_dev_t d = ggml_backend_dev_get(i);
		if (d == nullptr) {
			printf("[gate]   dev[%zu] <nulo>\n", i);
			continue;
		}
		// Um argumento, devolve `const char *`: a forma que a sonda mediu (probe3:24 e :50).
		// Se a assinatura fosse outra, isto e o ponto que devolveria lixo -- e lixo impresso e
		// achado, nao crash.
		const char * desc = ggml_backend_dev_description(d);
		printf("[gate]   dev[%zu] type=%d nome=%s desc=%s\n", i, ggml_backend_dev_type(d), ggml_backend_dev_name(d),
			desc != nullptr ? desc : "<nulo>");
	}

	const int vk = ggml_backend_vk_get_device_count();
	printf("[gate] vk_get_device_count=%d\n", vk);

	// Comparacao com S1.2 como numero, nao como adjetivo: la estavam reg_count=3 (RPC, Vulkan,
	// CPU), dev_count=2 com dev[0] type=1 Vulkan0 / dev[1] type=0 CPU, e vk=1.
	const bool igual_s12 = (regs == 3) && (devs == 2) && (vk == 1);
	printf("[gate] confronto_s1.2 reg_count=%zu esperado=3 dev_count=%zu esperado=2 vk=%d esperado=1 veredito=%s\n",
		regs, devs, vk, igual_s12 ? "IGUAL" : "DIFERE");
	fflush(stdout);
	return igual_s12 ? 0 : 4;
}

int main(int argc, char * * argv) {
	setvbuf(stdout, nullptr, _IONBF, 0);
	onde_estou();
	if (argc < 2) {
		printf("[recusa] uso: af_symbol_gate <nu|preload> [caminho-do-runtime]\n");
		return 2;
	}
	simbolos();

	const char * modo = argv[1];

	// --- `[premissa]`: o loader ve as DLLs do runtime pelo NOME NU? -------------------------
	// Nome nu cai no diretorio do processo, que e a premissa que S5.1 escreveu e o Passo 2
	// passou a checar. A checagem roda nos dois modos: em `nu` ela E o resultado, e em
	// `preload` ela e a testemunha de que o diretorio deste exe nao tem runtime nenhum -- a
	// diferenca entre as duas corridas e o que diz onde a responsa esta.
	static const char * const RUNTIME[5] = {"libomp.dll", "ggml-base.dll", "ggml.dll", "ggml-vulkan.dll", "llama.dll"};
	bool nu_ok = true;
	{
		unsigned long erro = 0;
		for (int i = 0; i < 5; ++i) {
			HMODULE h = abrir("", RUNTIME[i], &erro);
			printf("[premissa] nome_nu %s handle=%p erro=%lu\n", RUNTIME[i], (void *) h, erro);
			if (h == nullptr) {
				nu_ok = false;
			}
		}
		fflush(stdout);
	}

	if (strcmp(modo, "nu") == 0) {
		// Sem pre-carga: as chamadas abaixo sao a resolucao pura do diretorio do processo. Se a
		// premissa for falsa, nada e chamado -- o gate recusa em vez de morrer, e o codigo da
		// recusa e o numero que vai para o log.
		if (!nu_ok) {
			printf("[premissa] veredito=FALSA o diretorio do processo nao ve o runtime por nome nu\n");
			printf("[recusa] nu: sem nome nu resolvido nao ha o que chamar; rode `preload <runtime>`\n");
			fflush(stdout);
			return 5;
		}
		printf("[premissa] veredito=VERDADEIRA chamo o registro sem pre-carga, pelo diretorio do exe\n");
		fflush(stdout);
		return gate(g_exe_dir);
	}

	if (strcmp(modo, "preload") != 0) {
		printf("[recusa] modo desconhecido: %s\n", modo);
		return 2;
	}
	if (argc < 3) {
		printf("[recusa] preload precisa do caminho do runtime\n");
		return 2;
	}
	const char * runtime = argv[2];

	// --- preload: o caminho literal, como a sonda de S1.2 fez -------------------------------
	printf("[branco] preload do runtime=%s\n", runtime);
	for (int i = 0; i < 5; ++i) {
		unsigned long erro = 0;
		HMODULE h = abrir(runtime, RUNTIME[i], &erro);
		printf("[branco] LoadLibraryExA(%s)=%p erro=%lu\n", RUNTIME[i], (void *) h, erro);
		if (h == nullptr) {
			fflush(stdout);
			return 3;
		}
	}
	fflush(stdout);

	return gate(runtime);
}
