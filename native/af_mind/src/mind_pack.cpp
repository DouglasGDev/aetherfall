// Passo 2 (b) do dossier 22 (S5.2): carregar o pack DENTRO do processo e devolver os tres numeros.
//
// O que este arquivo prova, em uma frase: os tres numeros de S5.2 -- `af_vram_gb`, `af_load_ms`,
// `af_ctx_cells` -- saem de leituras do runtime (ggml/llama) feitas no processo que carrega a
// extensao, pela rota que o S15.5 obrigou (caminho absoluto antes de qualquer delay-helper), e
// nenhuma deles e um valor pedido por fora. Onde o runtime nao devolveu a grandeza, o getter devolve
// -1 e a pagina escreve `[OPEN]` com o motivo -- nunca 999, nunca o `--ctx-size` do
// `src/ai/llm_server_host.gd:64` no lugar da leitura.
//
// Duas coisas este arquivo NAO faz, de proposito:
//
//  * nao conhece o Godot. Os ptrcalls moram em `register_types.cpp`; aqui mora a sequencia de
//    maquina, para que a sonda de pe (`pack_probe_main.cpp`) e a extensao executem o MESMO codigo.
//    Um contrato de load escrito duas vezes e um contrato que uma delas esquece (S15.1).
//  * nao adivinha layout. Nao ha `llama.h` nem `ggml.h` na arvore (S12.3), entao os dois structs de
//    params sao tratados como BLOB de capacidade fixa, preenchido pelo proprio runtime
//    (`llama_model_default_params` / `llama_context_default_params`) e passado adiante sem que
//    nenhum campo seja lido por offset. O tamanho real que o runtime escreveu e medido pela
//    surpresinha do sentinela (preencher de 0xA5, chamar, contar os bytes que mudaram) e impresso
//    como testemunha da CLASSE de ABI -- nao como afirmação sobre o conteudo dos campos.
//
// Larguras: onde a assinatura pode ser 32 ou 64 bits, a fonte declara a LARGURA MAIOR. Passar 64
// para um callee que le 32 e inofensivo (os bits baixos estao certos); o contrario le lixo. Para
// retorno, a plausibilidade faz o papel de regua: um `size_t` lido onde o runtime devolve 32 bits
// sai fora do intervalo esperado e a grandeza vira -1, nao um numero inventado.

#include <windows.h>
// K32GetProcessMemoryInfo: a memoria do NOSSO processo, medida por uma API do SO e nao pelo runtime
// que estou conferindo. E o que separa "a VRAM nao mexeu porque o pack ficou em RAM" de "a VRAM nao
// mexeu porque a leitura de VRAM esta errada".
#include <psapi.h>

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>

#include "mind_pack.h"

// Os opacos: nunca interpretados aqui. Cada ponteiro sai do runtime e volta para o runtime.
struct ggml_backend_dev_st;
struct ggml_backend_reg_st;
struct llama_model_st;
struct llama_context_st;
struct llama_vocab_st;
typedef ggml_backend_dev_st * ggml_backend_dev_t;
typedef ggml_backend_reg_st * ggml_backend_reg_t;
typedef llama_model_st * llama_model_ptr;
typedef llama_context_st * llama_context_ptr;
typedef llama_vocab_st * llama_vocab_ptr;

// --- os CHAMADOS ----------------------------------------------------------------------------
// As dez assinaturas de ggml abaixo sao as que a sonda da Fase 0 chamou e teve numero devolvido
// (transcritas de docs/evidence/oraculo-nativo-22/af_native_probe3.cpp:17-26, como no gate do
// S15.1). O resto e NOVO e só entra como chamado com assinatura conferida por numero na sonda de
// pe deste passo (`af_pack_probe.exe`, logs `passo2b_probe_*.log`): cada linha abaixo diz qual foi
// a testemunha que a sustenta, e a sonda imprime o veredito dela.
extern "C" {
// ggml.dll -- enumeracao do registro (medida na Fase 0, S1.2)
size_t ggml_backend_load_all_from_path(const char * dir_path);
size_t ggml_backend_reg_count(void);
ggml_backend_reg_t ggml_backend_reg_get(size_t index);
size_t ggml_backend_dev_count(void);
ggml_backend_dev_t ggml_backend_dev_get(size_t index);
// ggml-base.dll -- descritores do dispositivo (medidos na Fase 0)
const char * ggml_backend_dev_name(ggml_backend_dev_t dev);
const char * ggml_backend_dev_description(ggml_backend_dev_t dev);
int ggml_backend_dev_type(ggml_backend_dev_t dev);
// ggml-base.dll -- NOVO: a memoria do dispositivo. Testemunha: chamando com `free` e `total`
// pré-cheios de 0xA5, os dois saem escritos, `total` bate com a VRAM da placa lida por
// `Get-CimInstance Win32_VideoController` e `free <= total`. Assinatura menor (um argumento so)
// nao escreveria nada e a metrica viraria -1.
void ggml_backend_dev_memory(ggml_backend_dev_t dev, size_t * p_free, size_t * p_total);
// ggml-vulkan.dll (medido na Fase 0)
int ggml_backend_vk_get_device_count(void);
// llama.dll -- NOVO. A versao de runtime e STRING (`const char *`, llama.h:489 do pin) e vale
// "1.0.0" em qualquer tag de release: a string NAO carrega o build. O pino b12499 tem testemunha
// propria -- o `build_info` do /props do servidor, arquivado na perna 15 (`b12499-401563f10`) e a
// proveniencia do fetch em THIRD_PARTY_LICENSES. O que esta chamada mede e que o simbolo existe e
// devolve uma string legivel; pedir a ela o numero do build e pedir o que a superficie exportada
// nao tem (`llama_build_number` e de common/, fora da DLL).
bool llama_supports_gpu_offload(void);
bool llama_model_is_hybrid(llama_model_ptr model);
void llama_backend_init(void);
const char * llama_version(void);
void llama_model_default_params(void * p_blob_destino);
void llama_context_default_params(void * p_blob_destino);
llama_model_ptr llama_model_load_from_file(const char * path, const void * p_params_blob);
uint64_t llama_model_size(llama_model_ptr model);
int32_t llama_model_n_ctx_train(llama_model_ptr model);
int32_t llama_model_n_layer(llama_model_ptr model);
int32_t llama_model_n_head(llama_model_ptr model);
int32_t llama_model_n_head_kv(llama_model_ptr model);
int32_t llama_model_n_embd(llama_model_ptr model);
int32_t llama_model_ftype(llama_model_ptr model);
const char * llama_ftype_name(int32_t ftype);
// Escreve no buffer do CHAMADOR e devolve o tamanho (llama.h:647 do pin). Nao existe retorno de
// ponteiro aqui: a assinatura de uma linha que so passava o modelo fez o callee ler RDX como
// ponteiro de buffer e escrever nele -- o acesso de memoria que derrubou a primeira sonda.
int32_t llama_model_desc(llama_model_ptr model, char * buf, size_t buflen);
llama_vocab_ptr llama_model_get_vocab(llama_model_ptr model);
int32_t llama_vocab_n_tokens(llama_vocab_ptr vocab);
int32_t llama_model_meta_count(llama_model_ptr model);
int32_t llama_model_meta_key_by_index(llama_model_ptr model, int32_t index, char * buf, size_t buflen);
int32_t llama_model_meta_val_str(llama_model_ptr model, const char * key, char * buf, size_t buflen);
llama_context_ptr llama_init_from_model(llama_model_ptr model, const void * p_params_blob);
int32_t llama_n_ctx(llama_context_ptr ctx);
// llama.dll -- NOVO. Duas leituras do MESMO contexto por duas funcoes que nao sao a que eu escrevi:
// se `llama_n_batch` e `llama_n_ubatch` sairem plausiveis (nao zero, nao o numero que escrevi na
// primeira palavra), a escrita pousou num campo de contexto e nao destruiu os vizinhos. Testemunha
// da afirmacao de layout de `af_pack_ctx_probe`, impressa como numero.
int32_t llama_n_batch(llama_context_ptr ctx);
int32_t llama_n_ubatch(llama_context_ptr ctx);
size_t llama_state_get_size(llama_context_ptr ctx);
}

// --- os ENDEREÇADOS --------------------------------------------------------------------------
// Referenciados por endereco (o import existe, o gate passou) e NAO chamados: devolver memoria ao
// runtime exige assinatura medida, e o Passo 2 (b) nao descarrega pack nenhum -- o processo sai e o
// SO devolve tudo. E debito escrito do Passo 3, nao detalhe escondido. As tres listas de cima tambem
// tem enderecados sem chamada (llama_backend_free acima), e o `check_imports.py` e quem confere que
// tudo o que a fonte nomeia virou import.
extern "C" {
extern void * llama_backend_free; // llama.dll -- existe no export-set (S1.3), nao e chamado aqui
extern void * llama_model_free;   // llama.dll
extern void * llama_free;         // llama.dll
extern void * ggml_backend_free;  // ggml-base.dll
}

namespace {

// Os cinco modulos que a sonda de S1.2 abriu e que o S15.5 mediu nao serem alcancaveis por nome nu.
const char *const MODS[5] = {"libomp.dll", "ggml-base.dll", "ggml.dll", "ggml-vulkan.dll", "llama.dll"};

// Capacidade do blob onde o runtime escreve os proprios params. NAO e o tamanho das struct -- o
// tamanho medido e impresso (`[abi] ... escritos=`), e se o runtime escrever mais do que cabe a
// sonda recusa em vez de estourar a pilha.
const size_t BLOB_CAP = 512;
const unsigned char MARK = 0xA5;

// Guarda de alocacao do contexto (grandeza reportada NAO e esta): com os defaults do runtime o
// cache pode pedir o contexto inteiro do modelo. `qwen35.context_length` e 262 144 celulas, o que
// sao gigabytes de KV; a sonda mede o que o runtime devolve e o DLL so tenta abaixo do teto.
const int32_t TETO_CELULAS = 8192;

struct Estado {
	char dir[MAX_PATH];
	char pack_nome[64];
	HMODULE mods[5];
	int n_mods;
	int32_t estado; // 0..4, ver mind_pack.h
	// registro / dispositivos
	int64_t regs;
	int64_t abertos;
	int64_t devs;
	int64_t vk;
	int gpu_offload;
	int hibrido;
	ggml_backend_dev_t cpu_dev;
	ggml_backend_dev_t vulkan_dev;
	char vk_name[96];
	char vk_desc[160];
	// memoria do dispositivo
	int64_t vram_total;
	int64_t vram_free;
	int64_t vram_base;
	int64_t vram_used;
	// runtime / modelo
	char versao_txt[32]; // `llama_version` devolve a string LLAMA_VERSION ("1.0.0"), nao o build
	int64_t bytes_escritos_mp;
	int64_t bytes_escritos_cp;
	int64_t ultimo_mp;
	int64_t ultimo_cp;
	llama_model_ptr model;
	int64_t load_ms;
	int64_t open_ms;
	int64_t model_bytes;
	int64_t ctx_train;
	int64_t n_layer;
	int64_t n_head;
	int64_t n_head_kv;
	int64_t n_embd;
	int64_t vocab;
	int64_t ftype;
	char ftype_nome[32];
	char desc_modelo[96];
	char arch[48];
	char meta_ctx[32];
	char meta_key0[64];
	int64_t meta_count;
	// contexto
	llama_context_ptr ctx;
	int64_t ctx_cells;
	int64_t state_bytes;
	int64_t ctx_pedido;
	int64_t ctx_lido;
	int64_t n_batch;
	int64_t n_ubatch;
	int64_t word0_default;
	// memoria do processo (SO, nao runtime)
	int64_t rss_antes;
	int64_t rss_apos;
	// diagnostico
	int32_t err_stage;
	int64_t err_code;
	int32_t err_which;
	char err[256];
};

Estado g = {};

void limpa() {
	// Estado zerado = "nada medido". Os int64 de grandeza usam -1 para o mesmo fim, e sao postos
	// aqui explicitamente para que um getter jamais devolva 0 como se 0 fosse uma leitura.
	g = Estado{};
	g.regs = -1;
	g.devs = -1;
	g.vk = -1;
	g.abertos = -1;
	g.gpu_offload = -1;
	g.hibrido = -1;
	g.vram_total = -1;
	g.vram_free = -1;
	g.vram_base = -1;
	g.vram_used = -1;
	g.bytes_escritos_mp = -1;
	g.bytes_escritos_cp = -1;
	g.ultimo_mp = -1;
	g.ultimo_cp = -1;
	g.load_ms = -1;
	g.open_ms = -1;
	g.model_bytes = -1;
	g.ctx_train = -1;
	g.n_layer = -1;
	g.n_head = -1;
	g.n_head_kv = -1;
	g.n_embd = -1;
	g.vocab = -1;
	g.ftype = -1;
	g.ctx_cells = -1;
	g.state_bytes = -1;
	g.meta_count = -1;
	g.ctx_pedido = -1;
	g.ctx_lido = -1;
	g.n_batch = -1;
	g.n_ubatch = -1;
	g.word0_default = -1;
	g.rss_antes = -1;
	g.rss_apos = -1;
}

void falha(int stage, DWORD code, int which, const char * msg) {
	g.err_stage = stage;
	g.err_code = (int64_t) code;
	g.err_which = which;
	snprintf(g.err, sizeof(g.err), "%s", msg != nullptr ? msg : "sem mensagem");
}

// caminho absoluto de verdade: "X:\\..." ou "\\\\servidor\\...". A rota do S15.5 e o caminho
// literal; aceitar relativo aqui seria a premissa FALSA de volta pela porta dos fundos.
bool absoluto(const char * p) {
	if (p == nullptr || p[0] == '\0') {
		return false;
	}
	const size_t n = strlen(p);
	if (n >= 3 && p[1] == ':' && (p[2] == '\\' || p[2] == '/')) {
		return ((p[0] >= 'A' && p[0] <= 'Z') || (p[0] >= 'a' && p[0] <= 'z'));
	}
	return n >= 2 && p[0] == '\\' && p[1] == '\\';
}

// Quantos bytes do blob o runtime trocou, e o ultimo offset escrito. E a medicao da CLASSE de ABI
// (struct por valor = ponteiro oculto em RCX): se nada foi escrito, o callee nao usou meu buffer e
// eu nao chamo nada.
size_t escritos(const unsigned char * blob, size_t * ultimo) {
	size_t n = 0;
	size_t last = 0;
	for (size_t i = 0; i < BLOB_CAP; ++i) {
		if (blob[i] != MARK) {
			++n;
			last = i;
		}
	}
	if (ultimo != nullptr) {
		*ultimo = last;
	}
	return n;
}

// Leitura de um `const char *` que o runtime me devolve. Antes de imprimir, o VirtualQuery diz se a
// pagina esta comitada e e legivel: um ponteiro lixo de assinatura errada vira recusa impressa, nao
// um crash no processo da engine (mandato 1).
bool legivel(const char * p, size_t cap) {
	if (p == nullptr) {
		return false;
	}
	MEMORY_BASIC_INFORMATION mbi = {};
	const SIZE_T r = VirtualQuery((LPCVOID) p, &mbi, sizeof(mbi));
	if (r == 0) {
		return false;
	}
	if (mbi.State != MEM_COMMIT) {
		return false;
	}
	const DWORD ok = PAGE_READONLY | PAGE_READWRITE | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE |
			PAGE_WRITECOPY | PAGE_EXECUTE_WRITECOPY;
	if ((mbi.Protect & ok) == 0) {
		return false;
	}
	// o restante da pagina tem de cobrir o que vou ler; se nao cobre, e o fim do mapeamento e o
	// VirtualQuery da regiao seguinte diria -- entao so prometo o que a primeira pagina garante.
	const uintptr_t dentro = (uintptr_t) p - (uintptr_t) mbi.BaseAddress;
	return (dentro + cap) <= mbi.RegionSize;
}

size_t copia_texto(char * dst, size_t cap, const char * src) {
	if (src == nullptr || cap == 0) {
		if (cap > 0) {
			dst[0] = '\0';
		}
		return 0;
	}
	const int n = snprintf(dst, cap, "%s", src);
	if (n < 0 || (size_t) n >= cap) {
		dst[cap - 1] = '\0';
		return cap - 1;
	}
	return (size_t) n;
}

void preenche(unsigned char * blob) {
	memset(blob, MARK, BLOB_CAP);
}

// O blob dos params do modelo e do contexto: estaticos porque o callee so le durante a chamada, e
// o sentinela precisa sobreviver a chamada para ser contado.
alignas(16) unsigned char blob_mp[BLOB_CAP];
alignas(16) unsigned char blob_cp[BLOB_CAP];

int64_t ms_decorrido(LARGE_INTEGER a, LARGE_INTEGER b, LARGE_INTEGER freq) {
	const double t = (double) (b.QuadPart - a.QuadPart) * 1000.0 / (double) freq.QuadPart;
	return (int64_t) (t + 0.5);
}

// Le a memoria do dispositivo Vulkan (a unica fonte de VRAM que o export-set medido da -- o
// `ggml_backend_buffer_type_get_base_buffer` que a documentacao do prompt usava nao existe no pin,
// S15.6). Devolve false se o runtime nao escreveu os dois numeros.
bool le_vram(ggml_backend_dev_t dev, int64_t * total, int64_t * livre) {
	if (dev == nullptr) {
		return false;
	}
	size_t livre_raw = (size_t) 0xA5A5A5A5A5A5A5A5ull;
	size_t total_raw = (size_t) 0xA5A5A5A5A5A5A5A5ull;
	ggml_backend_dev_memory(dev, &livre_raw, &total_raw);
	const bool escritos = (livre_raw != (size_t) 0xA5A5A5A5A5A5A5A5ull) && (total_raw != (size_t) 0xA5A5A5A5A5A5A5A5ull);
	if (!escritos) {
		return false;
	}
	// plausibilidade: 1 MB .. 256 GB, e livre <= total. Um lixo de assinatura errada cai aqui.
	if (total_raw < (1ull << 20) || total_raw > (256ull << 30) || livre_raw > total_raw) {
		return false;
	}
	*total = (int64_t) total_raw;
	*livre = (int64_t) livre_raw;
	return true;
}

// A memoria do nosso proprio processo, pela via do SO (working set, em bytes). Nao e grandeza do
// dossier: e a testemunha independente que diz para onde foram os bytes do pack quando a leitura de
// VRAM nao se move. Um 0 aqui significaria "o SO nao respondeu", entao a ausencia vale -1 igual.
int64_t rss_processo() {
	PROCESS_MEMORY_COUNTERS pmc = {};
	pmc.cb = sizeof(pmc);
	if (!K32GetProcessMemoryInfo(GetCurrentProcess(), &pmc, sizeof(pmc))) {
		return -1;
	}
	return (int64_t) pmc.WorkingSetSize;
}

// O contexto em si, com o blob que o chamador preparou. `pedido` e o numero que eu escrevi na
// primeira palavra do blob. A grandeza reportada NUNCA e `pedido`: e `llama_n_ctx(ctx)`, a leitura que o runtime faz do que ele mesmo organizou,
// e por isso ela e guardada em `ctx_lido` antes de qualquer confronto.
int cria_contexto(const unsigned char * blob, int32_t pedido) {
	g.ctx = llama_init_from_model(g.model, blob);
	g.ctx_pedido = (int64_t) pedido;
	if (g.ctx == nullptr) {
		falha(5, GetLastError(), -1, "llama_init_from_model devolveu nulo");
		g.ctx_lido = -1;
		return -1;
	}
	if (g.estado < 4) {
		g.estado = 4;
	}
	const int32_t cells = llama_n_ctx(g.ctx);
	g.ctx_lido = (int64_t) cells;
	g.ctx_cells = (cells > 0) ? (int64_t) cells : -1;
	g.n_batch = (int64_t) llama_n_batch(g.ctx);
	g.n_ubatch = (int64_t) llama_n_ubatch(g.ctx);
	const size_t st = llama_state_get_size(g.ctx);
	g.state_bytes = (st > 0 && st < (1ull << 40)) ? (int64_t) st : -1;
	const size_t st2 = llama_state_get_size(g.ctx);
	if (st2 != st) {
		g.state_bytes = -1; // duas leituras que divergem nao sao grandeza, sao ruido
	}
	// O numero pedido so vira grandeza reportada se o runtime o confirmar por leitura. Se vier outro
	// valor, a AFIRMACAO de layout (primeira palavra = n_ctx) caiu, e cair ela significa que o
	// runtime alocou o proprio default: `af_ctx_cells` sai -1 e a pagina escreve `[OPEN]` com o
	// `ctx_lido` impresso ao lado, porque um numero que nao passou na leitura nao e meu para dar.
	if (pedido > 0 && g.ctx_lido != (int64_t) pedido) {
		falha(5, 0, -1, "llama_n_ctx nao confirmou a escrita no blob: o lido e outro (veja ctx_readback)");
		g.ctx_cells = -1;
		return -2;
	}
	return 0;
}

// O pack vazio: os backends no registro, o dispositivo Vulkan achado, a base de VRAM medida. E o
// `load_pack("")` que o S5.2 exige como base -- a base e uma leitura, nao um zero assumido, e o
// tempo dela e medido junto (o `open_ms` e o que separa "o runtime abriu" de "o pack entrou").
int abre_runtime() {
	LARGE_INTEGER freq = {};
	LARGE_INTEGER t0 = {};
	QueryPerformanceFrequency(&freq);
	QueryPerformanceCounter(&t0);
	const size_t carregados = ggml_backend_load_all_from_path(g.dir);
	g.abertos = (int64_t) carregados;
	g.regs = (int64_t) ggml_backend_reg_count();
	g.devs = (int64_t) ggml_backend_dev_count();
	g.vk = (int64_t) ggml_backend_vk_get_device_count();
	llama_backend_init();
	// A string de versao de runtime: `llama_version` devolve `const char *` (llama.h:489 do pin) e
	// vale "1.0.0" em qualquer tag -- o build pinado tem testemunha propria, o `build_info` do
	// /props do servidor arquivado na perna 15. A string e lida e impressa, o pino nao se confere
	// por aqui porque a superficie exportada nao o carrega.
	const char * vv = llama_version();
	copia_texto(g.versao_txt, sizeof(g.versao_txt), legivel(vv, 8) ? vv : "");
	g.gpu_offload = llama_supports_gpu_offload() ? 1 : 0;
	g.hibrido = -1; // so faz sentido com um modelo na memoria

	const size_t nd = (g.devs > 0) ? (size_t) g.devs : 0;
	for (size_t i = 0; i < nd; ++i) {
		ggml_backend_dev_t d = ggml_backend_dev_get(i);
		if (d == nullptr) {
			continue;
		}
		const int t = ggml_backend_dev_type(d);
		if (t == 1 && g.vulkan_dev == nullptr) {
			g.vulkan_dev = d;
			const char * nm = ggml_backend_dev_name(d);
			const char * ds = ggml_backend_dev_description(d);
			copia_texto(g.vk_name, sizeof(g.vk_name), legivel(nm, 32) ? nm : "");
			copia_texto(g.vk_desc, sizeof(g.vk_desc), legivel(ds, 32) ? ds : "");
		} else if (t == 0 && g.cpu_dev == nullptr) {
			g.cpu_dev = d;
		}
	}

	int64_t total = 0;
	int64_t livre = 0;
	if (le_vram(g.vulkan_dev, &total, &livre)) {
		g.vram_total = total;
		g.vram_free = livre;
		g.vram_base = total - livre;
		g.vram_used = g.vram_base; // no pack vazio, o usado E a base: o getter nao nasce -1
	} else {
		g.vram_total = -1;
		g.vram_free = -1;
		g.vram_base = -1;
		falha(3, GetLastError(), -1, "ggml_backend_dev_memory nao devolveu dois numeros plausiveis");
		return -3;
	}
	LARGE_INTEGER t1 = {};
	QueryPerformanceCounter(&t1);
	g.open_ms = ms_decorrido(t0, t1, freq);
	if (g.estado < 2) {
		g.estado = 2;
	}
	return 0;
}

} // namespace

// --- a API C --------------------------------------------------------------------------------

// Toda grandeza nao medida vale -1, inclusive antes de qualquer chamada: sem este init um getter
// devolveria 0, e zero parece leitura.
extern "C" void af_pack_init(void) {
	limpa();
}

extern "C" int af_pack_preload_runtime(const char * dir_utf8) {
	if (g.estado >= 1 && strlen(g.dir) > 0 && strcmp(g.dir, dir_utf8 != nullptr ? dir_utf8 : "") == 0) {
		return g.n_mods; // o mesmo caminho, ja aberto: nao ha que reabrir
	}
	if (g.mods[0] != nullptr) {
		falha(1, 0, -1, "runtime pre-carregado por outro caminho neste processo");
		return -1;
	}
	if (!absoluto(dir_utf8)) {
		falha(1, ERROR_INVALID_NAME, -1, "o caminho do runtime nao e absoluto (S15.5: nome nu da erro=126)");
		return -1;
	}
	limpa();
	copia_texto(g.dir, sizeof(g.dir), dir_utf8);
	for (int i = 0; i < 5; ++i) {
		char caminho[MAX_PATH] = {0};
		snprintf(caminho, sizeof(caminho), "%s\\%s", g.dir, MODS[i]);
	 SetLastError(0);
		HMODULE h = LoadLibraryExA(caminho, nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
		g.mods[i] = h;
		if (h == nullptr) {
			const DWORD e = GetLastError();
			char msg[192] = {0};
			snprintf(msg, sizeof(msg), "LoadLibraryExA(%s) falhou com %lu", MODS[i], (unsigned long) e);
			falha(2, e, i, msg);
			return -2;
		}
		++g.n_mods;
	}
	g.estado = 1;
	return g.n_mods;
}

extern "C" int af_pack_load(const char * pack_nome, const char * path_utf8) {
	copia_texto(g.pack_nome, sizeof(g.pack_nome), pack_nome != nullptr ? pack_nome : "");
	if (g.estado < 1) {
		// A recusa e o ponto: nenhum nome do runtime foi tocado antes do preload por caminho
		// absoluto. E isto que o runner checa, e o que impede o `STATUS_DLL_NOT_FOUND` de S15.5 de
		// virar um crash dentro do processo da engine.
		falha(1, ERROR_MOD_NOT_FOUND, -1, "sem runtime pre-carregado: chame set_runtime_dir antes");
		return -1;
	}
	if (path_utf8 == nullptr || path_utf8[0] == '\0') {
		return abre_runtime();
	}
	if (!absoluto(path_utf8)) {
		falha(4, ERROR_INVALID_NAME, -1, "o caminho do pack nao e absoluto");
		return -4;
	}
	if (g.estado < 2) {
		const int r = abre_runtime();
		if (r != 0) {
			return r;
		}
	}

	preenche(blob_mp);
	llama_model_default_params(blob_mp);
	size_t ultimo = 0;
	g.bytes_escritos_mp = (int64_t) escritos(blob_mp, &ultimo);
	g.ultimo_mp = (int64_t) ultimo;
	if (g.bytes_escritos_mp <= 0 || ultimo + 1 > BLOB_CAP) {
		falha(4, 0, -1, "llama_model_default_params nao escreveu no blob: a classe de ABI nao e a medida");
		return -5;
	}

	LARGE_INTEGER freq = {};
	LARGE_INTEGER t0 = {};
	LARGE_INTEGER t1 = {};
	QueryPerformanceFrequency(&freq);
	// A memoria do processo ANTES do pack entrar: o `af_vram_gb` de S5.2 e uma leitura do
	// dispositivo, e esta e a leitura do SO sobre o mesmo instante. As duas juntas dizem onde o
	// pack morou; nenhuma das duas e afirmacao sobre a interna do runtime.
	g.rss_antes = rss_processo();
	QueryPerformanceCounter(&t0);
	g.model = llama_model_load_from_file(path_utf8, blob_mp);
	QueryPerformanceCounter(&t1);
	g.rss_apos = rss_processo();
	if (g.model == nullptr) {
		const DWORD e = GetLastError();
		falha(4, e, -1, "llama_model_load_from_file devolveu nulo (veja o stderr do runtime)");
		return -6;
	}
	g.load_ms = ms_decorrido(t0, t1, freq);
	if (g.estado < 3) {
		g.estado = 3;
	}

	g.model_bytes = (int64_t) llama_model_size(g.model);
	g.ctx_train = (int64_t) llama_model_n_ctx_train(g.model);
	g.n_layer = (int64_t) llama_model_n_layer(g.model);
	g.n_head = (int64_t) llama_model_n_head(g.model);
	g.n_head_kv = (int64_t) llama_model_n_head_kv(g.model);
	g.n_embd = (int64_t) llama_model_n_embd(g.model);
	g.ftype = (int64_t) llama_model_ftype(g.model);
	const char * fn = llama_ftype_name((int32_t) g.ftype);
	copia_texto(g.ftype_nome, sizeof(g.ftype_nome), legivel(fn, 8) ? fn : "");
	// Escreve no buffer do CHAMADOR e devolve o tamanho (llama.h:647 do pin). A assinatura de uma
	// linha que so passava o modelo fez o callee ler RDX como ponteiro de buffer e escrever nele --
	// o acesso de memoria que derrubou a primeira sonda; a leitura agora tem onde cair.
	char desc_buf[128] = {0};
	const int32_t dl = llama_model_desc(g.model, desc_buf, sizeof(desc_buf));
	copia_texto(g.desc_modelo, sizeof(g.desc_modelo), dl > 0 ? desc_buf : "");
	g.hibrido = llama_model_is_hybrid(g.model) ? 1 : 0;

	llama_vocab_ptr voc = llama_model_get_vocab(g.model);
	g.vocab = (int64_t) llama_vocab_n_tokens(voc);
	const int32_t metas = llama_model_meta_count(g.model);
	g.meta_count = (int64_t) metas;
	char chave[64] = {0};
	const int32_t kn = llama_model_meta_key_by_index(g.model, 0, chave, sizeof(chave));
	if (kn > 0) {
		// a primeira chave e testemunha de que o acesso por indice anda; o conteudo que importa sao
		// as duas leituras abaixo, do modelo, nao de um --ctx-size pedido por fora.
		copia_texto(g.meta_key0, sizeof(g.meta_key0), chave);
	} else {
		g.meta_key0[0] = '\0';
	}
	const int32_t an = llama_model_meta_val_str(g.model, "general.architecture", g.arch, sizeof(g.arch));
	if (an <= 0) {
		g.arch[0] = '\0';
	}
	char ctxkey[96] = {0};
	snprintf(ctxkey, sizeof(ctxkey), "%s.context_length", g.arch[0] != '\0' ? g.arch : "qwen35");
	const int32_t cn = llama_model_meta_val_str(g.model, ctxkey, g.meta_ctx, sizeof(g.meta_ctx));
	if (cn <= 0) {
		g.meta_ctx[0] = '\0';
	}

	// Os params do contexto, medidos antes de qualquer decisao: `llama_context_default_params`
	// escreve o blob, e a contagem de bytes trocados e a testemunha da CLASSE de ABI (struct >8
	// bytes vai por endereco no slot de registro -- e e o que os dois `escritos=` impressos provam
	// para este pin, nao o que a documentacao diz).
	preenche(blob_cp);
	llama_context_default_params(blob_cp);
	g.bytes_escritos_cp = (int64_t) escritos(blob_cp, &ultimo);
	g.ultimo_cp = (int64_t) ultimo;
	if (g.bytes_escritos_cp <= 0 || ultimo + 1 > BLOB_CAP) {
		falha(5, 0, -1, "llama_context_default_params nao escreveu no blob: a classe de ABI nao e a medida");
		return -7;
	}
	// A primeira palavra do blob, OBSERVADA (dado, nao afirmacao): so registra o default que o
	// runtime po e imprime na linha `[ctx] word0_default=`. O load NAO aloca contexto nenhum -- o
	// unico contexto do processo nasce em `af_pack_ctx_probe`, com o pedido que a leitura confirma.
	// Foi o load criar o default (512) antes que deixou a prova de layout inatingivel: a sonda caia
	// no "ja medido" e o pedido 2048 nunca chegou ao runtime, com o probe a sair 0 e o veredito
	// NAO_CONFIRMADA na mesma linha. O teto de alocacao mora so no `ctx_probe` (1..TETO_CELULAS),
	// que e o unico lugar onde um numero meu poderia virar alocacao.
	uint32_t word0 = 0;
	memcpy(&word0, blob_cp, sizeof(word0));
	g.word0_default = (int64_t) word0;

	// a leitura DEPOIS do load, com a base ja medida em cima
	int64_t total = 0;
	int64_t livre = 0;
	if (le_vram(g.vulkan_dev, &total, &livre)) {
		g.vram_used = total - livre;
		g.vram_total = total;
		g.vram_free = livre;
	} else {
		g.vram_used = -1;
	}
	return 0;
}

// --- o passo 4 da rota: o contexto medido -----------------------------------------------------
// O `af_ctx_cells` de S5.2 e o custo real do cache de contexto, e o custo de um contexto e tudo que
// o runtime aloca para ele: as celulas que ele entrega (`llama_n_ctx`) e os bytes que ele mesmo
// conta (`llama_state_get_size`). Os dois sao leituras; nenhum dos dois e o `--ctx-size` pedido por
// fora (que no `src/ai/llm_server_host.gd:64` vale 4096 e e citado aqui justamente para nao ser
// confundido com leitura).
//
// A unica afirmacao de layout deste arquivo mora nesta funcao: "a primeira palavra u32 do blob que
// `llama_context_default_params` escreveu e o n_ctx". Ela nao vem de header nem de documentacao --
// vem do confronto que a propria funcao imprime: escrevo N, o runtime devolve `llama_n_ctx`, e se os
// dois nao baterem a grandeza volta como -1 (`[OPEN]`) com o lido ao lado. Um contexto nunca e
// alocado com um numero meu sem a guarda do teto acima.
extern "C" int af_pack_ctx_probe(int32_t celulas) {
	if (g.estado < 3 || g.model == nullptr) {
		falha(5, ERROR_INVALID_FUNCTION, -1, "sem modelo no processo: ctx_probe so existe depois do load");
		return -1;
	}
	if (g.ctx != nullptr) {
		return 0; // ja medido: a sonda nao aloca um segundo cache por chamada repetida
	}
	if (celulas < 1 || celulas > TETO_CELULAS) {
		char msg[128] = {0};
		snprintf(msg, sizeof(msg), "o pedido (%ld celulas) esta fora do teto da sonda (%d): nao alocado",
				(long) celulas, TETO_CELULAS);
		falha(5, 0, -1, msg);
		return -2;
	}
	// blob fresco, cheio pelo runtime, e so ENTAO a primeira palavra trocada pelo pedido -- o resto
	// dos campos continua sendo o que o proprio runtime pos, que e o que faz a leitura significar
	// "contexto de `celulas` com os defaults do resto" em vez de "struct que eu inventei".
	preenche(blob_cp);
	llama_context_default_params(blob_cp);
	size_t ultimo = 0;
	g.bytes_escritos_cp = (int64_t) escritos(blob_cp, &ultimo);
	g.ultimo_cp = (int64_t) ultimo;
	if (g.bytes_escritos_cp < 4 || ultimo + 1 > BLOB_CAP) {
		falha(5, 0, -1, "llama_context_default_params nao escreveu a primeira palavra: sem onde escrever");
		return -3;
	}
	const uint32_t pedido = (uint32_t) celulas;
	memcpy(blob_cp, &pedido, sizeof(pedido));
	if (memcmp(blob_cp, &pedido, sizeof(pedido)) != 0) {
		falha(5, 0, -1, "a escrita na primeira palavra do blob nao pousou");
		return -4;
	}
	g.rss_antes = rss_processo();
	const int r = cria_contexto(blob_cp, celulas);
	g.rss_apos = rss_processo();
	if (r != 0) {
		return r;
	}
	// a VRAM depois do contexto, porque o cache pode morar no dispositivo e o numero de S5.2 e o
	// estado do dispositivo DEPOIS de tudo que o pack pe.
	int64_t total = 0;
	int64_t livre = 0;
	if (le_vram(g.vulkan_dev, &total, &livre)) {
		g.vram_used = total - livre;
		g.vram_total = total;
		g.vram_free = livre;
	} else {
		g.vram_used = -1;
	}
	return 0;
}

#define AF_REF(nome) acc = (acc ^ (uint64_t) (uintptr_t) & (nome)) * 0x100000001b3ull

extern "C" int64_t af_pack_slots(int imprimir) {
	// Duas funcoes numa linha so: (a) FORCA o import de cada nome a existir no binario -- sem isto,
	// o `/OPT:REF` do linker arranca uma funcao que ninguem chama e a tabela de imports do
	// `af_mind.dll` perderia os nomes que o `check_imports.py` conta; (b) e a testemunha impressa do
	// gate, o endereco do slot, nunca o valor (S15.1). A lista e a unica do arquivo: o que a fonte
	// nomeia e o que o binario importa, e a regua e quem confere os dois sentidos.
	uint64_t acc = 0xcbf29ce484222325ull;
	if (imprimir) {
		printf("[simbolo] AF_MIND slots\n");
	}
	// ggml.dll
	AF_REF(ggml_backend_load_all_from_path);
	AF_REF(ggml_backend_reg_count);
	AF_REF(ggml_backend_reg_get);
	AF_REF(ggml_backend_dev_count);
	AF_REF(ggml_backend_dev_get);
	// ggml-base.dll
	AF_REF(ggml_backend_dev_name);
	AF_REF(ggml_backend_dev_description);
	AF_REF(ggml_backend_dev_type);
	AF_REF(ggml_backend_dev_memory);
	AF_REF(ggml_backend_free);
	// ggml-vulkan.dll
	AF_REF(ggml_backend_vk_get_device_count);
	// llama.dll -- chamados
	AF_REF(llama_backend_init);
	AF_REF(llama_version);
	AF_REF(llama_supports_gpu_offload);
	AF_REF(llama_model_default_params);
	AF_REF(llama_context_default_params);
	AF_REF(llama_model_load_from_file);
	AF_REF(llama_model_size);
	AF_REF(llama_model_n_ctx_train);
	AF_REF(llama_model_n_layer);
	AF_REF(llama_model_n_head);
	AF_REF(llama_model_n_head_kv);
	AF_REF(llama_model_n_embd);
	AF_REF(llama_model_ftype);
	AF_REF(llama_ftype_name);
	AF_REF(llama_model_desc);
	AF_REF(llama_model_get_vocab);
	AF_REF(llama_vocab_n_tokens);
	AF_REF(llama_model_meta_count);
	AF_REF(llama_model_meta_key_by_index);
	AF_REF(llama_model_meta_val_str);
	AF_REF(llama_init_from_model);
	AF_REF(llama_n_ctx);
	AF_REF(llama_n_batch);
	AF_REF(llama_n_ubatch);
	AF_REF(llama_state_get_size);
	AF_REF(llama_model_is_hybrid);
	// llama.dll -- enderecados, nao chamados (debito do Passo 3)
	AF_REF(llama_backend_free);
	AF_REF(llama_model_free);
	AF_REF(llama_free);
#undef AF_REF
	return (int64_t) acc;
}

extern "C" int64_t af_pack_vram_total(void) {
	return g.vram_total;
}
extern "C" int64_t af_pack_vram_base(void) {
	return g.vram_base;
}
extern "C" int64_t af_pack_vram_used(void) {
	return g.vram_used;
}

// --- os ponteiros do runtime, para a fila de prompts (Passo 3) -------------------------------
// Nada aqui alocou, carregou ou liberou nada: os ponteiros sao os que a rota ja criou, e a
// guardinha de estado existe para o chamador receber nullptr em vez de um ponteiro para uma
// rota que ainda nao passou por ali. O vocabulario (`af_pack_state`) e o mesmo da maquina de
// estados de S5.3 -- quem recusa, recusa nomeando o estado lido.
extern "C" void * af_pack_model(void) {
	return (g.estado >= 3) ? (void *) g.model : nullptr;
}
extern "C" void * af_pack_ctx(void) {
	return (g.estado >= 4) ? (void *) g.ctx : nullptr;
}
extern "C" void * af_pack_vocab(void) {
	// `llama_model_get_vocab` e chamada de novo aqui de proposito: a leitura e barata e o vocab
	// e do modelo, nao meu para guardar copiado. Se o modelo sumiu, o runtime e quem recusa.
	return (g.estado >= 3 && g.model != nullptr) ? (void *) llama_model_get_vocab(g.model) : nullptr;
}
extern "C" int64_t af_pack_vram_usado_agora(void) {
	// Metrica viva: re-mede o dispositivo AGORA e atualiza as grandezas de S5.2 em cima da
	// leitura nova. O getter de cima (`af_pack_vram_used`) continua devolvendo o instante da
	// rota -- os dois numeros tem donos diferentes e propositos diferentes.
	if (g.vulkan_dev == nullptr) {
		return -1;
	}
	int64_t total = 0;
	int64_t livre = 0;
	if (!le_vram(g.vulkan_dev, &total, &livre)) {
		return -1;
	}
	g.vram_total = total;
	g.vram_free = livre;
	g.vram_used = total - livre;
	return g.vram_used;
}

extern "C" int64_t af_pack_load_ms(void) {
	return g.load_ms;
}
extern "C" int64_t af_pack_open_ms(void) {
	return g.open_ms;
}
extern "C" int64_t af_pack_backends_loaded(void) {
	return g.abertos;
}
extern "C" int64_t af_pack_ctx_cells(void) {
	return g.ctx_cells;
}
extern "C" int64_t af_pack_model_bytes(void) {
	return g.model_bytes;
}
extern "C" int64_t af_pack_ctx_train(void) {
	return g.ctx_train;
}
extern "C" int64_t af_pack_state_bytes(void) {
	return g.state_bytes;
}
extern "C" int64_t af_pack_vocab_tokens(void) {
	return g.vocab;
}
extern "C" int64_t af_pack_n_layer(void) {
	return g.n_layer;
}
extern "C" int64_t af_pack_n_head(void) {
	return g.n_head;
}
extern "C" int64_t af_pack_n_head_kv(void) {
	return g.n_head_kv;
}
extern "C" int64_t af_pack_n_embd(void) {
	return g.n_embd;
}
extern "C" int64_t af_pack_ftype(void) {
	return g.ftype;
}
extern "C" int64_t af_pack_vram_free(void) {
	return g.vram_free;
}
extern "C" const char * af_pack_model_desc(void) {
	return g.desc_modelo;
}
extern "C" const char * af_pack_meta_ctx(void) {
	return g.meta_ctx;
}
extern "C" const char * af_pack_version_texto(void) {
	return g.versao_txt;
}
extern "C" int64_t af_pack_reg_count(void) {
	return g.regs;
}
extern "C" int64_t af_pack_dev_count(void) {
	return g.devs;
}
extern "C" int64_t af_pack_vk_count(void) {
	return g.vk;
}
extern "C" int64_t af_pack_gpu_offload(void) {
	return g.gpu_offload;
}
extern "C" int64_t af_pack_hybrid(void) {
	return g.hibrido;
}
extern "C" int64_t af_pack_mods_open(void) {
	return g.n_mods;
}
extern "C" int64_t af_pack_params_written(int qual) {
	return (qual == 0) ? g.bytes_escritos_mp : g.bytes_escritos_cp;
}
extern "C" int64_t af_pack_params_last(int qual) {
	return (qual == 0) ? g.ultimo_mp : g.ultimo_cp;
}
extern "C" int32_t af_pack_state(void) {
	return g.estado;
}
extern "C" int32_t af_pack_err_stage(void) {
	return g.err_stage;
}
extern "C" int64_t af_pack_err_code(void) {
	return g.err_code;
}
extern "C" int32_t af_pack_err_which(void) {
	return g.err_which;
}
extern "C" const char * af_pack_err_text(void) {
	return g.err;
}
extern "C" const char * af_pack_pack_name(void) {
	return g.pack_nome;
}
extern "C" const char * af_pack_runtime_dir(void) {
	return g.dir;
}
extern "C" const char * af_pack_ftype_name(void) {
	return g.ftype_nome;
}
extern "C" const char * af_pack_arch(void) {
	return g.arch;
}
extern "C" const char * af_pack_vk_name(void) {
	return g.vk_name;
}
extern "C" const char * af_pack_vk_desc(void) {
	return g.vk_desc;
}
extern "C" int64_t af_pack_ctx_readback(void) {
	return g.ctx_lido;
}
extern "C" int64_t af_pack_ctx_pedido(void) {
	return g.ctx_pedido;
}
extern "C" int64_t af_pack_n_batch(void) {
	return g.n_batch;
}
extern "C" int64_t af_pack_n_ubatch(void) {
	return g.n_ubatch;
}
extern "C" int64_t af_pack_ctx_word0(void) {
	return g.word0_default;
}
extern "C" int64_t af_pack_rss_antes(void) {
	return g.rss_antes;
}
extern "C" int64_t af_pack_rss_apos(void) {
	return g.rss_apos;
}
extern "C" int64_t af_pack_rss_atual(void) {
	return rss_processo();
}
extern "C" int64_t af_pack_meta_count(void) {
	return g.meta_count;
}
extern "C" const char * af_pack_meta_key0(void) {
	return g.meta_key0;
}
