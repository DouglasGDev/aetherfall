// Passo 3 do dossier 22 (S5.3): a fila de prompts e a rota de decodificacao.
//
// Por que este corpo existe separado do `mind_pack.cpp`: o pack carrega e o prompt DECODIFICA --
// sao duas responsabilidades com um estado em comum (o contexto que o `ctx_probe` criou). A fila
// e thread de trabalho + secao critica, porque um decode de 64 tokens custa da ordem de segundos
// e o thread da engine tem um frame de 50 ms: bloquear o frame por decode e exatamente o que o
// S5.3 manda nao fazer. `enqueue` nunca decodifica; `wait` dorme na variavel de condicao com o
// orcamento que sobrou; o worker roda FORA da secao critica (so o le/wait sob CS).
//
// Assinaturas de llama.dll: transcritas do `include/llama.h` do pin b12499-401563f10, cujo fetch
// temporario esta arquivado com o sha256 em
// docs/evidence/oraculo-nativo-22/passo3_llama_h_auditado.txt. O header NAO entra na arvore (S12.3
// -- nenhuma linha de native/ compila contra documentacao), entao cada desvio da forma do header
// abaixo e uma DECISAO de ABI com a regra escrita: os bools de argumento passam como int32 (regra
// da largura maior, a mesma que a Fase 0 mediu nos params) e os bools de RETORNO continuam bool
// (o chamado devolve no AL e a leitura de 8 bits e a que os dois chamados existentes ja usam).
//
// O que este arquivo NAO faz, escrito para nao parecer esquecido:
//  -- nao cria contexto: exige `af_pack_state() >= 4` e reusa o unico contexto do processo
//     (decisao de S16.5 -- o `ctx_probe` continua sendo a unica alocacao e a unica afirmacao
//     de layout);
//  -- nao libera o modelo/contexto/backends: os quatro frees continuam enderecados e nao
//     chamados (`mind_pack.cpp`); o processo e persistente e quem decide o fim do pack e o
//     Passo 4/5, nao um pedido de prompt;
//  -- nao implementa cache, schema executado, prioridade nem contexto multi-prompt: o
//     `oracle_cache` e o Passo 5; os campos entram, sao registrados e a pagina diz o que e
//     honrado e o que e registrado.

#include <windows.h>

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>

#include "mind_pack.h"
#include "mind_prompt.h"

// --- os CHAMADOS de decodificacao -------------------------------------------------------------
// Cada linha abaixo diz o que a sonda de pe imprime quando a chamada acontece (o bloco [prompt]
// do `pack_probe_main.cpp`); um simbolo que nao existe no export-set medido e LNK2019 no build,
// nunca um crash dentro do Godot (mandato 1).
extern "C" {
// llama_batch_ext_* -- a API de batch NAO-deprecada do pin (`llama_batch_get_one`/`llama_decode`
// sao DEPRECATED no proprio header do pin; o export-set mede os dois caminhos e este arquivo
// segue o que o upstream pede).
void * llama_batch_ext_init(void * ctx);
void llama_batch_ext_free(void * batch);
void llama_batch_ext_clear(void * batch);
// Devolve o indice do elemento (>= 0) ou -1/-2/-3 (motivo nomeado no header do pin).
int32_t llama_batch_ext_add_token(void * batch, int32_t seq_id, int32_t id);
// bools de argumento -> int32 (largura maior); bools de retorno continuam bool (AL).
bool llama_batch_ext_set_pos(void * batch, int32_t idx, const int32_t * pos);
bool llama_batch_ext_set_output_logits(void * batch, int32_t idx, int32_t value);
// enum llama_process_type -> int32; LLAMA_PROCESS_TYPE_DECODE = 1 no pin.
int32_t llama_process(void * ctx, int32_t type, void * batch);
// O KV e limpo POR PEDIDO: a fila e mono-contexto e cada pedido comeca do zero -- sem o clear,
// o segundo pedido herdaria o cache do primeiro e a narrativa dependeria da ordem da fila.
void * llama_get_memory(const void * ctx);
void llama_memory_clear(void * mem, int32_t data);
// parse_special = 1 de proposito: o formato de chat abaixo escreve `<|im_start|>` como TEXTO e e
// o tokenizer que o transforma no token de controle -- e o que o llama-server faz com o prompt
// templado, e o que faz a comparacao de FORMA do gate valer para os dois transportes.
int32_t llama_tokenize(const void * vocab, const char * text, int32_t text_len, int32_t * tokens,
		int32_t n_tokens_max, int32_t add_special, int32_t parse_special);
int32_t llama_detokenize(const void * vocab, const int32_t * tokens, int32_t n_tokens, char * text,
		int32_t text_len_max, int32_t remove_special, int32_t unparse_special);
void * llama_sampler_init_greedy(void);
int32_t llama_sampler_sample(void * smpl, void * ctx, int32_t idx);
void llama_sampler_free(void * smpl);
bool llama_vocab_is_eog(const void * vocab, int32_t token);
}

namespace {

// --- os tetos, cada um com o motivo ----------------------------------------------------------
const int TETO_PROMPT = 2048;        // o mesmo cap do campo; a recusa e nomeada, nunca estouro
const int TETO_TOKENS_SAIDA = 256;   // 64 e o contrato do oraculo; acima de 256 e recusa
const int PADRAO_MAX_TOKENS = 64;    // o max_tokens do payload de src/ai/mind_oracle.gd
const int TETO_FILA = 16;            // slots fixos; a fila nao aloca, encher e recusa -3
const int TETO_TOKENS_ENTRADA = 512; // buffer de tokenize; o prompt do oraculo gera < 80 tokens
const int TETO_RAW = 960;            // bytes crus acumulados antes de parar (limpo cabe em 512)
const int TETO_NARRATIVA = 140;      // codepoints, o mesmo cap de `_clean` (mind_oracle.gd)

// O formato de chat do modelo. Os marcadores e o prompt de geracao sao do chat_template
// ARQUIVADO do proprio servidor na perna 15 (docs/evidence/oracle-embutido-15/
// servidor-vram-resumo-medido.log, campo `chat_template` do /props): o ramo `else` de
// `enable_thinking` escreve o bloco `<think>` VAZIO antes do conteudo, e e por isso que a
// continuacao greedy sai com a resposta e nao com rascunho. O wrap existe porque o `role` de
// S5.3 e contrato de entrada: sem ele o decode continuaria o texto do pedido em vez de responder.
const char *const IM_START = "<|im_start|>";
const char *const IM_END = "<|im_end|>";
const char *const GEN_PROMPT = "<|im_start|>assistant\n<think>\n\n</think>\n\n";

// --- a fila ------------------------------------------------------------------------------------
enum { SLOT_VAZIO = 0, SLOT_NA_FILA = 1, SLOT_RODANDO = 2, SLOT_PRONTO = 3 };

struct Slot {
	int32_t estado;
	int64_t id;
	AfPromptReq req;
	AfPromptOut out;
};

Slot fila[TETO_FILA] = {};
int64_t proximo_id = 1;

CRITICAL_SECTION cs;
CONDITION_VARIABLE cv;
INIT_ONCE once_cs = INIT_ONCE_STATIC_INIT;
HANDLE thread_trabalho = nullptr;
volatile LONG thread_pedida = 0;

int64_t cache_hits = 0;   // 0 honesto: NAO existe cache no Passo 3
int64_t cache_misses = 0; // cada pedido atendido sem cache -- a medida da ausencia
int64_t worst_decode_us = 0;
char ultimo_erro[192] = "";

void erro(const char * msg) {
	// Diagnostico como dado, nao print: a ponte nao tem `print_line` no header vendorado e a
	// sonda imprime a linha literal lendo este texto (mesmo padrao do `falha` do pack).
	EnterCriticalSection(&cs);
	snprintf(ultimo_erro, sizeof(ultimo_erro), "%s", msg != nullptr ? msg : "");
	LeaveCriticalSection(&cs);
}

// A fila em si nunca passa de um processo, entao o init roda uma vez por processo e basta.
BOOL CALLBACK inicia_cs(PINIT_ONCE, PVOID, PVOID *) {
	InitializeCriticalSection(&cs);
	InitializeConditionVariable(&cv);
	return TRUE;
}

void garantir_cs() {
	InitOnceExecuteOnce(&once_cs, inicia_cs, nullptr, nullptr);
}

// --- limpeza de narrativa ---------------------------------------------------------------------
// Replica `_clean` de src/ai/mind_oracle.gd (dossie 15): `<think>...</think>` fora (sem
// fechamento, corta do `<think>` em diante), `\n` vira espaco, teto de 140 codepoints com
// `...`. A FORMA da saida e parte do contrato do gate `contrato_igal_ao_http` -- os dois
// transportes limvam igual, e o que se compara e a forma, nunca a frase.
void limpa_narrativa(const char * raw, char * dst, size_t cap) {
	dst[0] = '\0';
	if (raw == nullptr || cap == 0) {
		return;
	}
	const char * src = raw;
	char aberto[8] = "<think>";
	const char * th = strstr(src, aberto);
	if (th != nullptr) {
		const char * fecha = strstr(th, "</think>");
		src = (fecha != nullptr) ? fecha + 8 : "";
	}
	// codepoints, nao bytes: um byte de continuacao UTF-8 (0b10xxxxxx) nao conta como char de
	// String.length() no GDScript, e o cap e comparavel so se a unidade for a mesma.
	int cps = 0;
	size_t o = 0;
	for (size_t i = 0; src[i] != '\0' && o + 1 < cap; ++i) {
		const unsigned char c = (unsigned char) src[i];
		if (c == '\n' || c == '\r') {
			if (o > 0 && dst[o - 1] == ' ') {
				continue;
			}
			dst[o++] = ' ';
			continue;
		}
		if ((c & 0xC0) != 0x80) {
			++cps;
			if (cps > TETO_NARRATIVA) {
				break;
			}
		}
		dst[o++] = (char) c;
	}
	dst[o] = '\0';
	// strip_edges das pontas, o mesmo passo final de `_clean`.
	size_t b = 0;
	while (dst[b] == ' ') {
		++b;
	}
	size_t e = o;
	while (e > b && (dst[e - 1] == ' ')) {
		--e;
	}
	if (b > 0) {
		memmove(dst, dst + b, e - b);
	}
	dst[e - b] = '\0';
	if (cps > TETO_NARRATIVA) {
		const size_t n = strlen(dst);
		snprintf(dst + n, cap - n, "%s", "...");
	}
}

// --- o formato de chat ------------------------------------------------------------------------
// Devolve false com motivo quando o papel ou o arch nao tem mapeamento -- recusa nomeada e a
// honestidade do S5.3: aceitar e escrever marcador inventado seria simulacao.
bool monta_formato_de_chat(const AfPromptReq * req, char * buf, size_t cap, char * motivo, size_t motivo_cap) {
	const char * arch = af_pack_arch();
	if (strncmp(arch, "qwen", 4) != 0) {
		snprintf(motivo, motivo_cap, "arch %s sem formato de chat mapeado ([OPEN] Passo 5)", arch);
		return false;
	}
	if (strcmp(req->role, "user") != 0 && strcmp(req->role, "system") != 0) {
		snprintf(motivo, motivo_cap, "papel %s fora do mapeamento user/system", req->role);
		return false;
	}
	const int n = snprintf(buf, cap, "%s%s\n%s%s\n%s", IM_START, req->role, req->prompt, IM_END,
			GEN_PROMPT);
	if (n < 0 || (size_t) n >= cap) {
		snprintf(motivo, motivo_cap, "prompt mais o formato de chat passa do teto de %d bytes", TETO_PROMPT);
		return false;
	}
	return true;
}

// --- a decodificacao ---------------------------------------------------------------------------
// O loop e o do exemplo do proprio header do pin (llama.h:1389): feed -> process -> sample ->
// feed do token amostrado. O batch EXT e criado UMA vez por pedido e limpo por passo
// (`llama_batch_ext_clear`), o sampler greedy e criado e LIBERADO por pedido -- e a unica rota
// do processo que devolve memoria ao runtime hoje; os quatro frees grandes continuam debito
// escrito do Passo 4/5.
bool decodifica(const AfPromptReq * req, AfPromptOut * out) {
	out->request_id = req->request_id;
	out->status = -1;
	out->reason[0] = '\0';
	out->text[0] = '\0';
	out->decode_us = 0;
	out->tokens_out = 0;

	void * ctx = af_pack_ctx();
	if (ctx == nullptr) {
		snprintf(out->reason, sizeof(out->reason), "sem contexto no processo (estado %d na hora do decode)",
				(int) af_pack_state());
		return false;
	}
	void * model = af_pack_model();
	void * vocab = af_pack_vocab();
	if (model == nullptr || vocab == nullptr) {
		snprintf(out->reason, sizeof(out->reason), "modelo/vocab ausentes na hora do decode");
		return false;
	}

	const int64_t n_batch = af_pack_n_batch();
	if (n_batch <= 0) {
		snprintf(out->reason, sizeof(out->reason), "n_batch nao medido (%lld): feed recusado",
				(long long) n_batch);
		return false;
	}

	char chat[TETO_PROMPT + 128];
	char motivo[128];
	if (!monta_formato_de_chat(req, chat, sizeof(chat), motivo, sizeof(motivo))) {
		snprintf(out->reason, sizeof(out->reason), "%s", motivo);
		return false;
	}

	LARGE_INTEGER freq = {};
	LARGE_INTEGER t0 = {};
	LARGE_INTEGER t1 = {};
	QueryPerformanceFrequency(&freq);
	QueryPerformanceCounter(&t0);

	int32_t tokens_entrada[TETO_TOKENS_ENTRADA];
	const int32_t n_prompt = llama_tokenize(vocab, chat, (int32_t) strlen(chat), tokens_entrada,
			TETO_TOKENS_ENTRADA, 0, 1);
	if (n_prompt <= 0) {
		snprintf(out->reason, sizeof(out->reason), "tokenize recusou (n=%d)", n_prompt);
		return false;
	}
	if ((int64_t) n_prompt > n_batch) {
		// O fatiamento do prompt em varios process() e do Passo 5: aceitar e cortar sem dizer
		// seria o texto truncado sem motivo.
		snprintf(out->reason, sizeof(out->reason),
				"prompt de %d tokens passa do n_batch %lld do contexto (fatiamento e do Passo 5)",
				n_prompt, (long long) n_batch);
		return false;
	}
	if (n_prompt + (int32_t) req->max_tokens > af_pack_ctx_cells()) {
		snprintf(out->reason, sizeof(out->reason),
				"pedido de %d+%d tokens nao cabe nas %lld celulas do contexto",
				n_prompt, (int) req->max_tokens, (long long) af_pack_ctx_cells());
		return false;
	}

	// KV do zero: a fila e mono-contexto e cada pedido comeca limpo (veja o comentario da
	// declaracao de `llama_memory_clear`).
	void * mem = llama_get_memory(ctx);
	llama_memory_clear(mem, 1);

	void * bext = llama_batch_ext_init(ctx);
	if (bext == nullptr) {
		snprintf(out->reason, sizeof(out->reason), "llama_batch_ext_init devolveu nulo");
		return false;
	}
	// O feed do prompt inteiro num unico process(): os prompts do oraculo sao de ~80 tokens e o
	// n_batch medido e da ordem das celulas do contexto; a recusa acima nomeia o caso contrario.
	for (int32_t i = 0; i < n_prompt; ++i) {
		const int32_t idx = llama_batch_ext_add_token(bext, 0, tokens_entrada[i]);
		if (idx < 0) {
			snprintf(out->reason, sizeof(out->reason), "add_token recusou no feed (idx=%d ret=%d)", i, idx);
			llama_batch_ext_free(bext);
			return false;
		}
		const int32_t pos = i;
		if (!llama_batch_ext_set_pos(bext, idx, &pos)) {
			snprintf(out->reason, sizeof(out->reason), "set_pos recusou no feed (idx=%d)", i);
			llama_batch_ext_free(bext);
			return false;
		}
	}
	if (!llama_batch_ext_set_output_logits(bext, n_prompt - 1, 1)) {
		snprintf(out->reason, sizeof(out->reason), "set_output_logits recusou no feed");
		llama_batch_ext_free(bext);
		return false;
	}
	if (llama_process(ctx, 1, bext) != 0) {
		snprintf(out->reason, sizeof(out->reason), "llama_process recusou o feed (n=%d)", n_prompt);
		llama_batch_ext_free(bext);
		return false;
	}

	void * smpl = llama_sampler_init_greedy();
	if (smpl == nullptr) {
		snprintf(out->reason, sizeof(out->reason), "llama_sampler_init_greedy devolveu nulo");
		llama_batch_ext_free(bext);
		return false;
	}

	// O buffer de tokens acumulados: o detokenize e incremental POR DIFERENCA -- detokenizar o
	// conjunto a cada passo e comparar com o texto do passo anterior e o que evita o caso do
	// token que so completa o UTF-8 do anterior (um token so pode devolver 0 bytes novos).
	int32_t tokens_total[TETO_TOKENS_SAIDA + TETO_TOKENS_ENTRADA];
	memcpy(tokens_total, tokens_entrada, sizeof(int32_t) * n_prompt);
	int32_t n_total = n_prompt;
	int32_t n_gen = 0;
	char raw[TETO_RAW + 64] = "";
	size_t raw_len = 0;
	bool truncado_raw = false;

	int32_t tok = llama_sampler_sample(smpl, ctx, -1);
	int32_t pos = n_prompt;
	while (tok >= 0 && n_gen < req->max_tokens && !llama_vocab_is_eog(vocab, tok)) {
		tokens_total[n_total++] = tok;
		++n_gen;
		char passo[TETO_RAW + 64];
		const int n = llama_detokenize(vocab, tokens_total + n_prompt, n_gen, passo,
				sizeof(passo) - 1, 0, 0);
		if (n < 0) {
			snprintf(out->reason, sizeof(out->reason), "detokenize recusou (n=%d, gen=%d)", n, n_gen);
			llama_sampler_free(smpl);
			llama_batch_ext_free(bext);
			return false;
		}
		passo[n] = '\0';
		if ((size_t) n > raw_len) {
			const size_t novo = (size_t) n - raw_len;
			if (raw_len + novo < sizeof(raw)) {
				memcpy(raw + raw_len, passo + raw_len, novo);
				raw_len += novo;
				raw[raw_len] = '\0';
			} else {
				truncado_raw = true;
			}
		}
		if (n_gen >= req->max_tokens || truncado_raw || raw_len >= TETO_RAW) {
			break;
		}
		llama_batch_ext_clear(bext);
		const int32_t idx = llama_batch_ext_add_token(bext, 0, tok);
		if (idx < 0 || !llama_batch_ext_set_pos(bext, idx, &pos)
				|| !llama_batch_ext_set_output_logits(bext, idx, 1)) {
			snprintf(out->reason, sizeof(out->reason), "montagem do passo recusou (gen=%d)", n_gen);
			llama_sampler_free(smpl);
			llama_batch_ext_free(bext);
			return false;
		}
		++pos;
		if (llama_process(ctx, 1, bext) != 0) {
			snprintf(out->reason, sizeof(out->reason), "llama_process recusou no passo %d", n_gen);
			llama_sampler_free(smpl);
			llama_batch_ext_free(bext);
			return false;
		}
		tok = llama_sampler_sample(smpl, ctx, -1);
	}
	llama_sampler_free(smpl);
	llama_batch_ext_free(bext);

	QueryPerformanceCounter(&t1);
	out->decode_us = (int64_t) ((double) (t1.QuadPart - t0.QuadPart) * 1000000.0
			/ (double) freq.QuadPart);
	out->tokens_out = n_gen;
	if (n_gen == 0 && tok < 0) {
		snprintf(out->reason, sizeof(out->reason), "o primeiro sample recusou (n=%d)", (int) tok);
		return false;
	}
	if (n_gen == 0) {
		snprintf(out->reason, sizeof(out->reason), "o primeiro token amostrado ja era o fim (eog)");
		return false;
	}
	limpa_narrativa(raw, out->text, sizeof(out->text));
	out->status = 0;
	return true;
}

// --- o worker ----------------------------------------------------------------------------------
DWORD WINAPI worker(LPVOID) {
	for (;;) {
		EnterCriticalSection(&cs);
		int slot_idx = -1;
		for (;;) {
			for (int i = 0; i < TETO_FILA; ++i) {
				if (fila[i].estado == SLOT_NA_FILA) {
					slot_idx = i;
					break;
				}
			}
			if (slot_idx >= 0) {
				break;
			}
			// Dorme SEM o orcamento: quem tem prazo e o `wait`, que dorme com o dele. O worker
			// acorda quando um enqueue sinaliza ou quando um wait devolve o slot.
			SleepConditionVariableCS(&cv, &cs, INFINITE);
		}
		fila[slot_idx].estado = SLOT_RODANDO;
		const AfPromptReq req = fila[slot_idx].req;
		LeaveCriticalSection(&cs);

		AfPromptOut out = {};
		decodifica(&req, &out);

		EnterCriticalSection(&cs);
		fila[slot_idx].out = out;
		fila[slot_idx].estado = SLOT_PRONTO;
		++cache_misses; // atendido sem cache -- a medida da ausencia do oracle_cache (Passo 5)
		if (out.decode_us > worst_decode_us) {
			worst_decode_us = out.decode_us;
		}
		LeaveCriticalSection(&cs);
		WakeAllConditionVariable(&cv);
	}
	return 0;
}

void garantir_thread() {
	if (InterlockedCompareExchange(&thread_pedida, 1, 0) == 0) {
		thread_trabalho = CreateThread(nullptr, 0, &worker, nullptr, 0, nullptr);
		// Um handle de thread nao fechado vive o processo -- a fila vive o processo tambem; o
		// CloseHandle prematuro seria a recusa do shutdown que o Passo 4/5 decide.
	}
}

} // namespace

// --- a API C ------------------------------------------------------------------------------------

extern "C" void af_prompt_init(void) {
	garantir_cs();
	EnterCriticalSection(&cs);
	proximo_id = 1;
	cache_hits = 0;
	cache_misses = 0;
	worst_decode_us = 0;
	ultimo_erro[0] = '\0';
	// Os slots JA em uso ficam como estao: `af_prompt_init` roda no registro da classe (CORE) e
	// de proposito nao apaga pedidos que possam existir de uma inicializacao anterior.
	LeaveCriticalSection(&cs);
}

extern "C" int64_t af_prompt_enqueue(const AfPromptReq * req) {
	garantir_cs();
	if (req == nullptr) {
		erro("enqueue: pedido nulo");
		return -2;
	}
	// A guardinha de contexto e a DECISAO de S16.5 em codigo: a fila nao cria contexto, ela
	// reusa o que o `ctx_probe` confirmou; sem ele a recusa nomeia o estado lido.
	if (af_pack_ctx() == nullptr) {
		erro("enqueue: sem contexto no processo (a rota do pack nao chegou ao passo 4)");
		return -1;
	}
	size_t n_prompt = 0;
	for (; n_prompt < sizeof(req->prompt); ++n_prompt) {
		if (req->prompt[n_prompt] == '\0') {
			break;
		}
	}
	if (n_prompt == 0 || n_prompt >= sizeof(req->prompt)) {
		erro("enqueue: prompt vazio ou sem terminador dentro do teto de 2048");
		return -2;
	}
	if (req->max_tokens > TETO_TOKENS_SAIDA) {
		char msg[128];
		snprintf(msg, sizeof(msg), "enqueue: max_tokens %d passa do teto de %d", (int) req->max_tokens,
				TETO_TOKENS_SAIDA);
		erro(msg);
		return -2;
	}
	// O papel recusa na PORTA (-4, contrato do mind_prompt.h) e nao so dentro da thread: o
	// chamador tem de ler a recusa na linha do enqueue, no mesmo lugar onde os outros tetos
	// de pedido recusam, em vez de descobrir o motivo so no wait. O strcmp exige terminador,
	// entao o campo vem cercado antes.
	size_t n_role = 0;
	for (; n_role < sizeof(req->role); ++n_role) {
		if (req->role[n_role] == '\0') {
			break;
		}
	}
	if (n_role == sizeof(req->role)) {
		erro("enqueue: papel sem terminador dentro de 32 bytes");
		return -2;
	}
	if (strcmp(req->role, "user") != 0 && strcmp(req->role, "system") != 0) {
		char msg[128];
		snprintf(msg, sizeof(msg), "enqueue: papel %s fora do mapeamento user/system", req->role);
		erro(msg);
		return -4;
	}

	EnterCriticalSection(&cs);
	int slot_idx = -1;
	for (int i = 0; i < TETO_FILA; ++i) {
		if (fila[i].estado == SLOT_VAZIO) {
			slot_idx = i;
			break;
		}
	}
	if (slot_idx < 0) {
		char msg[128];
		snprintf(msg, sizeof(msg), "enqueue: fila cheia (%d pedidos sem wait)", TETO_FILA);
		erro(msg);
		LeaveCriticalSection(&cs);
		return -3;
	}
	Slot * s = &fila[slot_idx];
	s->req = *req;
	s->req.max_tokens = (req->max_tokens > 0) ? req->max_tokens : PADRAO_MAX_TOKENS;
	s->req.request_id = proximo_id;
	s->out.status = 0;
	s->out.text[0] = '\0';
	s->out.reason[0] = '\0';
	s->out.decode_us = 0;
	s->out.tokens_out = 0;
	s->id = proximo_id;
	s->estado = SLOT_NA_FILA;
	const int64_t id = proximo_id;
	++proximo_id;
	LeaveCriticalSection(&cs);
	garantir_thread();
	WakeAllConditionVariable(&cv);
	return id;
}

extern "C" int af_prompt_wait(int64_t request_id, int32_t timeout_ms, AfPromptOut * out) {
	garantir_cs();
	if (out == nullptr) {
		erro("wait: saida nula");
		return -1;
	}
	EnterCriticalSection(&cs);
	int slot_idx = -1;
	for (int i = 0; i < TETO_FILA; ++i) {
		if (fila[i].estado != SLOT_VAZIO && fila[i].id == request_id) {
			slot_idx = i;
			break;
		}
	}
	if (slot_idx < 0) {
		LeaveCriticalSection(&cs);
		erro("wait: id desconhecido (ja consumido por outro wait, ou enqueue recusado)");
		return -2;
	}
	LARGE_INTEGER freq = {};
	LARGE_INTEGER t0 = {};
	QueryPerformanceFrequency(&freq);
	QueryPerformanceCounter(&t0);
	int64_t restante_us = (int64_t) timeout_ms * 1000;
	while (fila[slot_idx].estado != SLOT_PRONTO && restante_us > 0) {
		SleepConditionVariableCS(&cv, &cs, (DWORD) (restante_us / 1000));
		LARGE_INTEGER agora = {};
		QueryPerformanceCounter(&agora);
		restante_us = (int64_t) timeout_ms * 1000
				- (int64_t) ((double) (agora.QuadPart - t0.QuadPart) * 1000000.0 / (double) freq.QuadPart);
	}
	if (fila[slot_idx].estado != SLOT_PRONTO) {
		LeaveCriticalSection(&cs);
		// O slot fica como esta: um wait seguinte com mais tempo pode achar o pedido pronto --
		// descartar aqui seria perder trabalho pago por um timeout do chamador.
		char msg[96];
		snprintf(msg, sizeof(msg), "timeout de %d ms", (int) timeout_ms);
		erro(msg);
		if (out != nullptr) {
			out->request_id = request_id;
			out->status = 1;
			snprintf(out->reason, sizeof(out->reason), "timeout de %d ms", (int) timeout_ms);
			out->text[0] = '\0';
			out->decode_us = 0;
			out->tokens_out = 0;
		}
		return 1;
	}
	*out = fila[slot_idx].out;
	fila[slot_idx].estado = SLOT_VAZIO; // consumido: o slot volta para o enqueue
	fila[slot_idx].id = 0;
	LeaveCriticalSection(&cs);
	return 0;
}

extern "C" int32_t af_prompt_queue_depth(void) {
	garantir_cs();
	EnterCriticalSection(&cs);
	int32_t n = 0;
	for (int i = 0; i < TETO_FILA; ++i) {
		if (fila[i].estado == SLOT_NA_FILA || fila[i].estado == SLOT_RODANDO) {
			++n;
		}
	}
	LeaveCriticalSection(&cs);
	return n;
}

extern "C" int64_t af_prompt_cache_hits(void) {
	garantir_cs();
	EnterCriticalSection(&cs);
	const int64_t n = cache_hits;
	LeaveCriticalSection(&cs);
	return n;
}

extern "C" int64_t af_prompt_cache_misses(void) {
	garantir_cs();
	EnterCriticalSection(&cs);
	const int64_t n = cache_misses;
	LeaveCriticalSection(&cs);
	return n;
}

extern "C" int64_t af_prompt_worst_decode_us(void) {
	garantir_cs();
	EnterCriticalSection(&cs);
	const int64_t n = worst_decode_us;
	LeaveCriticalSection(&cs);
	return n;
}

extern "C" const char * af_prompt_err_text(void) {
	garantir_cs();
	EnterCriticalSection(&cs);
	static char copia[192];
	snprintf(copia, sizeof(copia), "%s", ultimo_erro);
	LeaveCriticalSection(&cs);
	return copia;
}

#define AF_PROMPT_REF(nome) acc = (acc ^ (uint64_t) (uintptr_t) & (nome)) * 0x100000001b3ull

extern "C" int64_t af_prompt_slots(int imprimir) {
	// A mesma funcao que o `af_pack_slots` e para o pack, agora para a rota de decodificacao:
	// o endereco tomado de cada nome FORCA o import a existir no binario (o /OPT:REF arranca
	// funcao sem endereco tomado), e o checksum devolvido e o que a sonda compara entre o exe
	// de pe e o DLL -- MESMO checksum, MESMA lista de chamados da rota de prompt.
	uint64_t acc = 0xcbf29ce484222325ull;
	if (imprimir) {
		printf("[simbolo] AF_MIND slots_prompt\n");
	}
	AF_PROMPT_REF(llama_batch_ext_init);
	AF_PROMPT_REF(llama_batch_ext_free);
	AF_PROMPT_REF(llama_batch_ext_clear);
	AF_PROMPT_REF(llama_batch_ext_add_token);
	AF_PROMPT_REF(llama_batch_ext_set_pos);
	AF_PROMPT_REF(llama_batch_ext_set_output_logits);
	AF_PROMPT_REF(llama_process);
	AF_PROMPT_REF(llama_get_memory);
	AF_PROMPT_REF(llama_memory_clear);
	AF_PROMPT_REF(llama_tokenize);
	AF_PROMPT_REF(llama_detokenize);
	AF_PROMPT_REF(llama_sampler_init_greedy);
	AF_PROMPT_REF(llama_sampler_sample);
	AF_PROMPT_REF(llama_sampler_free);
	AF_PROMPT_REF(llama_vocab_is_eog);
#undef AF_PROMPT_REF
	return (int64_t) acc;
}
