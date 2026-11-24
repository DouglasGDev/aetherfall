// Passo 2 (b) do dossier 22 (S5.2): a sonda de PE que roda a mesma sequencia da extensao, fora do
// Godot.
//
// Por que ela existe se o numero tem de sair do processo da engine: porque e aqui que uma ABI errada
// vira linha impressa em vez de um `SCRIPT ERROR` que derruba checagens em silencio (mandato 1, e o
// mesmo motivo pelo qual o gate do S15 roda de pe). O `af_pack_probe.exe` chama o MESMO
// `mind_pack.cpp` que o `af_mind.dll` chama -- nenhuma sequencia copiada -- entao o que a sonda
// mede e o que a extensao executa. Os tres numeros de S5.2 saem nos dois lugares e a pagina escreve
// os dois.
//
// Modos:
//   af_pack_probe recusa [dir]     -- chama `af_pack_load` sem preload e `af_prompt_enqueue`
//                                     sem contexto. As duas recusas (codigo -1, estado 0) sao a
//                                     prova de que nenhum delay-helper roda antes do caminho
//                                     absoluto e de que a fila recusa sem contexto (S16.5), e de
//                                     que recusar nao e crash: o exit 9 e do programa, nao do
//                                     loader.
//   af_pack_probe <dir> <gguf|"">  -- a rota inteira, com as testemunhas de cada assinatura nova.
//                                     Sai 0 saindo toda a rota com a escrita confirmada; sai 7
//                                     quando o runtime RECUSA o contexto (nao cabe), 8 quando
//                                     ACEITA mas o readback difere do pedido, e 12 quando a rota
//                                     de prompt do S5.3 recusa (o build mapeia 12 -> codigo 14).
//                                     O NAO_CONFIRMADA medido nesta perna saiu com exit 0, e um
//                                     veredito sob exit 0 nao e numero publicado, e a recusa do
//                                     build.
//
// Toda linha `[abi]`, `[modelo]`, `[cache]` e `[numero]` abaixo existe para responder a uma
// grandeza com um numero e uma testemunha independente ao lado: o tamanho do arquivo no disco
// confere `llama_model_size`, a chave `<arch>.context_length` do proprio modelo confere
// `llama_model_n_ctx_train`, o nome do quant confere `llama_model_ftype`. A versao de runtime e
// STRING ("1.0.0" em qualquer tag de release) e nao carrega o build: a testemunha do pino b12499
// e o `build_info` do /props do servidor arquivado na perna 15 (`b12499-401563f10`). Sem par
// conferido, a grandeza e `-1` e a pagina escreve `[OPEN]`.

#include <windows.h>

#include <cstdio>
#include <cstring>

#include "mind_pack.h"
#include "mind_prompt.h"

static void onde_estou() {
	char exe[MAX_PATH] = {0};
	DWORD n = GetModuleFileNameA(nullptr, exe, MAX_PATH - 1);
	char dir[MAX_PATH] = {0};
	if (n > 0) {
		strcpy_s(dir, MAX_PATH, exe);
		char * corte = strrchr(dir, '\\');
		if (corte != nullptr) {
			*corte = '\0';
		}
	}
	printf("[exe] diretorio_do_processo=%s\n", n > 0 ? dir : "<sem diretorio>");
	printf("[exe] caminho=%s\n", n > 0 ? exe : "<sem nome>");
	fflush(stdout);
}

static double gb(int64_t bytes) {
	return (bytes < 0) ? -1.0 : (double) bytes / 1073741824.0;
}

// O tamanho do `.gguf` no disco: a testemunha independente de `llama_model_size`, lida por uma API
// do SO e nao pelo runtime que estou medindo.
static int64_t bytes_do_arquivo(const char * path) {
	WIN32_FILE_ATTRIBUTE_DATA d = {};
	if (!GetFileAttributesExA(path, GetFileExInfoStandard, &d)) {
		return -1;
	}
	return ((int64_t) d.nFileSizeHigh << 32) | (int64_t) d.nFileSizeLow;
}

int main(int argc, char * * argv) {
	setvbuf(stdout, nullptr, _IONBF, 0);
	onde_estou();
	af_pack_init();
	af_pack_slots(1);

	if (argc >= 2 && strcmp(argv[1], "recusa") == 0) {
		const int c = af_pack_load("", "");
		printf("[recusa] load_sem_preload=%d estado=%lld stage=%d code=%lld qual=%d\n", c,
				(long long) af_pack_state(), (int) af_pack_err_stage(), (long long) af_pack_err_code(),
				(int) af_pack_err_which());
		printf("[recusa] texto=%s\n", af_pack_err_text());
		printf("[recusa] veredito=%s\n", (c == -1 && af_pack_state() == 0) ? "RECUSOU_SEM_TOCAR_O_RUNTIME" : "NAO_RECUSOU");
		// A recusa da fila sem contexto (S16.5): `enqueue` com estado 0 recusa -1 e nao toca no
		// runtime -- e a mesma guardinha que o runner vai ler, medida de pe antes de o Godot.
		AfPromptReq r0 = {};
		snprintf(r0.role, sizeof(r0.role), "%s", "user");
		snprintf(r0.prompt, sizeof(r0.prompt), "%s", "recusa sem contexto");
		r0.max_tokens = 4;
		const int64_t ep0 = af_prompt_enqueue(&r0);
		printf("[recusa] enqueue_sem_contexto=%lld estado=%lld texto=%s veredito=%s\n",
				(long long) ep0, (long long) af_pack_state(), af_prompt_err_text(),
				(ep0 == -1 && af_pack_state() == 0) ? "RECUSOU_SEM_CONTEXTO" : "NAO_RECUSOU");
		const int recusou_tudo = (c == -1 && af_pack_state() == 0 && ep0 == -1) ? 1 : 0;
		fflush(stdout);
		return recusou_tudo ? 9 : 10;
	}
	if (argc < 3) {
		printf("[recusa] uso: af_pack_probe <dir-runtime> <path-gguf|vazio> | recusa\n");
		return 2;
	}

	printf("[rota] preload_absoluto dir=%s\n", argv[1]);
	const int n = af_pack_preload_runtime(argv[1]);
	printf("[rota] preload=%d estado=%d mods=%lld stage=%d code=%lld qual=%d texto=%s\n", n,
			(int) af_pack_state(), (long long) af_pack_mods_open(), (int) af_pack_err_stage(),
			(long long) af_pack_err_code(), (int) af_pack_err_which(), af_pack_err_text());
	if (n != 5) {
		return 3;
	}

	// --- a BASE: o load_pack() vazio que S5.2 exige medido antes -------------------------------
	const int base = af_pack_load("", "");
	printf("[base] load_pack_vazio=%d open_ms=%lld backends_loaded=%lld reg_count=%lld dev_count=%lld vk=%lld\n",
			base, (long long) af_pack_open_ms(), (long long) af_pack_backends_loaded(),
			(long long) af_pack_reg_count(), (long long) af_pack_dev_count(), (long long) af_pack_vk_count());
	printf("[base] dispositivo_vulkan nome=%s descricao=%s\n", af_pack_vk_name(), af_pack_vk_desc());
	printf("[base] llama_version=%s (string de runtime; o build pinado tem testemunha no /props arquivado)\n",
			af_pack_version_texto());
	printf("[base] gpu_offload=%lld\n", (long long) af_pack_gpu_offload());
	const int64_t base_usada = af_pack_vram_used();
	printf("[base] vram_total=%lld (%.3f GB) livre=%lld usada=%lld (%.3f GB)\n", (long long) af_pack_vram_total(),
			gb(af_pack_vram_total()), (long long) af_pack_vram_free(), (long long) base_usada, gb(base_usada));
	fflush(stdout);
	if (base != 0) {
		return 4;
	}

	// --- O PACK --------------------------------------------------------------------------------
	const char * gguf = (strcmp(argv[2], "vazio") == 0) ? "" : argv[2];
	const int64_t no_disco = (gguf[0] != '\0') ? bytes_do_arquivo(gguf) : -1;
	printf("[pack] arquivo=%s bytes_no_disco=%lld\n", gguf, (long long) no_disco);
	const int c = af_pack_load("mind-small", gguf);
	printf("[pack] load=%d load_ms=%lld estado=%d stage=%d code=%lld texto=%s\n", c,
			(long long) af_pack_load_ms(), (int) af_pack_state(), (int) af_pack_err_stage(),
			(long long) af_pack_err_code(), af_pack_err_text());
	fflush(stdout);

	// --- as testemunhas de assinatura: uma linha por chamada nova desta passada ---------------
	printf("[abi] llama_model_default_params escritos=%lld ultimo_offset=%lld\n",
			(long long) af_pack_params_written(0), (long long) af_pack_params_last(0));
	printf("[abi] llama_context_default_params escritos=%lld ultimo_offset=%lld\n",
			(long long) af_pack_params_written(1), (long long) af_pack_params_last(1));
	const int64_t mb = af_pack_model_bytes();
	printf("[abi] llama_model_size bytes=%lld disco=%lld veredito=%s\n", (long long) mb, (long long) no_disco,
			(no_disco > 0 && mb == no_disco) ? "IGUAL" : ((no_disco > 0) ? "DIFERE" : "sem arquivo"));
	printf("[modelo] n_layer=%lld n_head=%lld n_head_kv=%lld n_embd=%lld vocab=%lld ftype=%lld\n",
			(long long) af_pack_n_layer(), (long long) af_pack_n_head(), (long long) af_pack_n_head_kv(),
			(long long) af_pack_n_embd(), (long long) af_pack_vocab_tokens(), (long long) af_pack_ftype());
	printf("[modelo] arch=%s ftype_nome=%s desc=%s hibrido=%lld\n", af_pack_arch(), af_pack_ftype_name(),
			af_pack_model_desc(), (long long) af_pack_hybrid());
	printf("[modelo] ctx_train=%lld meta_%s.context_length=%s\n", (long long) af_pack_ctx_train(),
			af_pack_arch(), af_pack_meta_ctx());
	printf("[modelo] meta_count=%lld meta_key0=%s\n", (long long) af_pack_meta_count(), af_pack_meta_key0());
	fflush(stdout);

	// --- o passo 4 da rota: o contexto, com o numero pedido que NAO e o do host ----------------
	// O pedido aqui e 2048 de proposito: o `--ctx-size` do host e 4096 (src/ai/llm_server_host.gd:64)
	// e pedir um valor DIFERENTE e o que impede o numero lido de ser confundido com o pedido por fora.
	// A grandeza reportada e sempre `llama_n_ctx`, e o confronto pedido==lido e a testemunha de que a
	// afirmacao de layout (primeira palavra do blob = n_ctx) ficou de pe.
	const int32_t PEDIDO_CELULAS = 2048;
	printf("[ctx] word0_default=%lld estado=%d\n", (long long) af_pack_ctx_word0(), (int) af_pack_state());
	// VRAM depois do load e ANTES do contexto: e o `af_vram_gb` de S5.2 ("VRAM depois do load").
	// Depois do probe a leitura passa a incluir o cache de contexto, e os dois momentos sao
	// impressos separados no bloco [numero].
	const int64_t apos_load = af_pack_vram_used();
	const int cx = af_pack_ctx_probe(PEDIDO_CELULAS);
	printf("[ctx] probe=%d pedido=%d lido=%lld n_batch=%lld n_ubatch=%lld\n", cx, PEDIDO_CELULAS,
			(long long) af_pack_ctx_readback(), (long long) af_pack_n_batch(),
			(long long) af_pack_n_ubatch());
	printf("[ctx] ctx_cells=%lld state_bytes=%lld veredito=%s\n", (long long) af_pack_ctx_cells(),
			(long long) af_pack_state_bytes(),
			(af_pack_ctx_readback() == PEDIDO_CELULAS) ? "ESCRITA_CONFIRMADA_PELO_RUNTIME" : "NAO_CONFIRMADA");
	printf("[ctx] rss_antes_do_ctx=%lld rss_apos_do_ctx=%lld (%.3f GB)\n",
			(long long) af_pack_rss_antes(), (long long) af_pack_rss_apos(), gb(af_pack_rss_apos()));
	printf("[ctx] vram_apos_ctx_total=%lld usada=%lld\n", (long long) af_pack_vram_total(),
			(long long) af_pack_vram_used());
	fflush(stdout);
	if (cx != 0) {
		printf("[ctx] recusa_texto=%s stage=%d code=%lld\n", af_pack_err_text(), (int) af_pack_err_stage(),
				(long long) af_pack_err_code());
		// recusa AQUI nao e vermelho do build: e o achado (o runtime nao confirmou a escrita, ou o
		// modelo nao cabe), e a pagina escreve `[OPEN]` com esta linha como motivo. O que e vermelho
		// e seguir para o Godot sem esta testemunha.
		return 7;
	}

	printf("[cache] ctx_cells=%lld state_bytes=%lld\n", (long long) af_pack_ctx_cells(),
			(long long) af_pack_state_bytes());
	fflush(stdout);

	// --- OS TRES NUMEROS DE S5.2 --------------------------------------------------------------
	const int64_t depois = af_pack_vram_used();
	printf("[numero] af_vram_base_gb=%.3f af_vram_apos_load_gb=%.3f af_vram_apos_ctx_gb=%.3f\n",
			gb(base_usada), gb(apos_load), gb(depois));
	printf("[numero] af_vram_apos_load_bytes=%lld af_vram_apos_ctx_bytes=%lld\n",
			(long long) apos_load, (long long) depois);
	printf("[numero] af_vram_delta_load_gb=%.3f af_vram_delta_ctx_gb=%.3f\n",
			gb(apos_load - base_usada), gb(depois - apos_load));
	printf("[numero] af_load_ms=%lld\n", (long long) af_pack_load_ms());
	printf("[numero] af_ctx_cells=%lld ctx_train=%lld\n", (long long) af_pack_ctx_cells(),
			(long long) af_pack_ctx_train());
	printf("[numero] ctx_state_bytes=%lld bytes_por_celula=%.1f\n", (long long) af_pack_state_bytes(),
			(af_pack_ctx_cells() > 0 && af_pack_state_bytes() > 0)
					? (double) af_pack_state_bytes() / (double) af_pack_ctx_cells() : -1.0);
	printf("[numero] rss_antes=%lld rss_apos=%lld delta=%.3f GB (testemunha do SO, nao do runtime)\n",
			(long long) af_pack_rss_antes(), (long long) af_pack_rss_apos(),
			(af_pack_rss_antes() >= 0 && af_pack_rss_apos() >= 0)
					? gb(af_pack_rss_apos() - af_pack_rss_antes()) : -1.0);
	printf("[numero] ctx_size_pedido_por_fora=4096 (src/ai/llm_server_host.gd:64) identico_ao_lido=%s\n",
			(af_pack_ctx_cells() == 4096) ? "sim" : "nao");
	fflush(stdout);

	// A prova de layout decide por codigo de saida tambem: o NAO_CONFIRMADA medido nesta perna
	// (o load criava o contexto default e o pedido nunca chegou ao runtime) saiu com exit 0, e
	// o build aceitou. Um veredito sob exit 0 nao e numero publicado: o runtime ACEITOU o
	// contexto mas devolveu outro n_ctx, entao a afirmacao de layout (word0 = n_ctx) caiu, e a
	// recusa e aqui -- os [numero] acima saem para o leitor, o build nao segue para o dll.
	if (af_pack_ctx_readback() != PEDIDO_CELULAS) {
		return 8;
	}

	// --- a rota de prompt do Passo 3 (S5.3), de pe, antes de o Godot chamar qualquer metodo ----
	// A sequencia mede: as recusas nomeadas do enqueue (papel fora do mapeamento, max_tokens fora
	// do teto), a fila com depth 2 enquanto o primeiro decode roda, o timeout de wait com o slot
	// PRESERVADO (o wait seguinte acha o pedido pronto), as duas narrativas com reason vazio e
	// as metricas com o cache_hit em 0 honesto (nao existe cache no Passo 3). Qualquer recusa
	// aqui e exit 12 e o build recusa (codigo 14) -- o dll nao nasce sem a rota de prompt de pe.
	// O slots(1) nao e so medida: e o que mantem as 15 referencias AF_PROMPT_REF VIVAS neste
	// exe -- sem consumo, o /OPT:REF as retira e a tabela de imports perde os nomes (medido na
	// primeira corrida deste passo: o dll sem ponte ficou com 29 nomes do pack e ZERO do prompt).
	af_prompt_init();
	const int64_t slots_prompt = af_prompt_slots(1);

	AfPromptReq rq = {};
	snprintf(rq.role, sizeof(rq.role), "%s", "user");
	snprintf(rq.prompt, sizeof(rq.prompt),
			"lobo 7; intencao atual: seguir; vida 92%%; fome 34%%; confianca no jogador 0.80; "
			"memorias recentes: achou rastro (forca 0.62); crencas: jogador_confiavel=0.80. "
			"O que passa na cabeca dele agora?");
	rq.max_tokens = 64;
	rq.temperature = 0.7;
	snprintf(rq.schema, sizeof(rq.schema), "%s", "");
	rq.priority = 0;
	rq.context_count = 0;

	// as duas recusas nomeadas do enqueue, cada uma com o codigo esperado
	{
		AfPromptReq bad = rq;
		snprintf(bad.role, sizeof(bad.role), "%s", "cozinheiro");
		const int64_t e1 = af_prompt_enqueue(&bad);
		printf("[prompt] recusa_papel=%lld texto=%s veredito=%s\n", (long long) e1,
				af_prompt_err_text(), (e1 == -4) ? "RECUSOU_PAPEL" : "NAO_RECUSOU");
		AfPromptReq big = rq;
		big.max_tokens = 4096;
		const int64_t e2 = af_prompt_enqueue(&big);
		printf("[prompt] recusa_teto=%lld texto=%s veredito=%s\n", (long long) e2,
				af_prompt_err_text(), (e2 == -2) ? "RECUSOU_TETO" : "NAO_RECUSOU");
		if (e1 != -4 || e2 != -2) {
			return 12;
		}
	}

	const int64_t id1 = af_prompt_enqueue(&rq);
	rq.temperature = 0.7;
	rq.priority = 1;
	const int64_t id2 = af_prompt_enqueue(&rq); // o segundo entra enquanto o primeiro decodifica
	printf("[prompt] ids=%lld,%lld depth_apos_2=%d slots_checksum=%lld\n",
			(long long) id1, (long long) id2, (int) af_prompt_queue_depth(), (long long) slots_prompt);
	if (id1 < 1 || id2 < 1 || id1 == id2) {
		return 12;
	}
	const int32_t depth_antes = af_prompt_queue_depth();

	// o timeout curto num pedido com decode em curso: recusa 1 e o slot PRESERVADO
	AfPromptOut o1 = {};
	const int w0 = af_prompt_wait(id1, 1, &o1);
	printf("[prompt] wait_timeout_ms1=%d reason=%s depth=%d (pedido continua na fila/rodando)\n",
			w0, o1.reason, (int) af_prompt_queue_depth());
	if (w0 != 1 || af_prompt_queue_depth() > depth_antes) {
		return 12;
	}

	// os dois waits de verdade, com orcamento generoso (um decode de 64 tokens e de segundos)
	const int32_t WAIT_MS = 180000;
	const int w1 = af_prompt_wait(id1, WAIT_MS, &o1);
	AfPromptOut o2 = {};
	const int w2 = af_prompt_wait(id2, WAIT_MS, &o2);
	printf("[prompt] wait1=%d status=%d tokens_out=%d decode_us=%lld texto=%s\n", w1, (int) o1.status,
			(int) o1.tokens_out, (long long) o1.decode_us, o1.text);
	printf("[prompt] wait2=%d status=%d tokens_out=%d decode_us=%lld texto=%s\n", w2, (int) o2.status,
			(int) o2.tokens_out, (long long) o2.decode_us, o2.text);
	printf("[prompt] metricas depth=%d cache_hits=%lld cache_misses=%lld worst_decode_us=%lld "
			"vram_usada_agora=%lld (%.3f GB)\n", (int) af_prompt_queue_depth(),
			(long long) af_prompt_cache_hits(), (long long) af_prompt_cache_misses(),
			(long long) af_prompt_worst_decode_us(), (long long) af_pack_vram_usado_agora(),
			gb(af_pack_vram_usado_agora()));
	printf("[prompt] veredito=%s\n",
			(w1 == 0 && w2 == 0 && o1.status == 0 && o2.status == 0 && o1.reason[0] == '\0'
					&& o2.reason[0] == '\0' && o1.text[0] != '\0' && o2.text[0] != '\0'
					&& af_prompt_cache_hits() == 0 && af_prompt_cache_misses() >= 2
					&& o1.decode_us > 0 && o2.decode_us > 0)
					? "ROTA_DE_PROMPT_CONFIRMADA" : "ROTA_DE_PROMPT_RECUSADA");
	if (!(w1 == 0 && w2 == 0 && o1.status == 0 && o2.status == 0 && o1.reason[0] == '\0'
			&& o2.reason[0] == '\0' && o1.text[0] != '\0' && o2.text[0] != '\0'
			&& af_prompt_cache_hits() == 0 && af_prompt_cache_misses() >= 2
			&& o1.decode_us > 0 && o2.decode_us > 0)) {
		return 12;
	}

	if (c != 0) {
		return 5;
	}
	return (af_pack_load_ms() >= 0 && af_pack_vram_total() > 0) ? 0 : 6;
}
