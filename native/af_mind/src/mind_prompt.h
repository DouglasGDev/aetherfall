#ifndef AF_MIND_PROMPT_H
#define AF_MIND_PROMPT_H

// Passo 3 do dossier 22 (S5.3): a fila de prompts e a decodificacao de verdade.
//
// Este header segue a mesma regra do `mind_pack.h` (e e a razao de existir separado): ele nao
// conhece o Godot. O MESMO corpo (`mind_prompt.cpp`) roda na sonda de pe (`af_pack_probe.exe`)
// e dentro do processo da engine (`af_mind.dll`), entao uma ABI errada na rota de decodificacao
// vira linha impressa na sonda antes de qualquer chamada do Godot (mandato 1).
//
// O que o S5.3 pede e o que mora aqui:
//   `enqueue(req) -> request_id`   -- valida e enfileira; NUNCA decodifica na chamada.
//   `wait(request_id, timeout_ms)` -- espera o slot ficar pronto; a decodificacao roda na
//                                     thread de trabalho, fora do thread da engine (um decode de
//                                     64 tokens e da ordem de segundos; bloquear o frame de 50 ms
//                                     por isso e o que a fila existe para nao fazer).
//   metricas                       -- `queue_depth`, `cache_hits`, `cache_misses`,
//                                     `worst_decode_us`; VRAM vem de `af_pack_vram_usado_agora`.
//
// Politica de contexto, decisao escrita do S16.5: a fila NAO cria contexto proprio. Ela exige
// `af_pack_state() >= 4` e reusa o UNICO contexto do processo -- o que o `ctx_probe` ja criou e
// cuja afirmacao de layout (primeira palavra do blob = n_ctx, confirmada por leitura) continua
// valendo. Com isso o `--ctx-size` 4096 do host continua sendo pedido de OUTRO processo e o
// numero lido continua nao-confundivel.
//
// O `req` de S5.3: `role`, `prompt`, `max_tokens`, `temperature`, `schema`, `priority`,
// `context_ids`. O que o Passo 3 honra e o que ele so registra esta escrito em cada campo
// abaixo; o que fica para o Passo 5 (cache, schema executado, prioridade, contexto multi-prompt)
// esta marcado como tal -- aceito-e-registrado nao e honrado.

#include <cstdint>

extern "C" {

// O pedido, em buffers fixos: a fila nao aloca, entao os tetos sao nomeados e a recusa de um
// pedido maior e uma recusa com motivo, nao um estouro.
typedef struct AfPromptReq {
	int64_t request_id;      // SAIDA do enqueue: o id novo entra aqui; na entrada e ignorado
	char    role[32];        // "user"/"system" viram o formato de chat do modelo (leia o cpp)
	char    prompt[2048];    // teto TETO_PROMPT: acima disso e recusa nomeada
	int32_t max_tokens;      // honrado: teto do decode (1..256; ausente/<=0 = 64, o do oraculo)
	double  temperature;     // registrado; a politica do Passo 3 e greedy (deterministica)
	char    schema[128];     // aceito e registrado; executado no Passo 5
	int32_t priority;        // aceito e registrado; a ordem de atendimento e FIFO
	int32_t context_count;   // a contagem medida do `context_ids` de entrada
	int64_t context_ids[8];  // os 8 primeiros ids; a contagem segue sendo a medida completa
} AfPromptReq;

// A saida de um pedido. `reason` segue o espaco da enum de recusa do `mind_oracle.gd`: "" no
// sucesso, e um motivo NOMEADO quando o texto nao saiu -- o gate de FORMA compara os dois
// transportes por aqui, nunca pela frase (a frase e do modelo).
typedef struct AfPromptOut {
	int64_t request_id;
	int32_t status;          // 0 = narrativa em `text`; negativo = recusa nomeada em `reason`
	char    reason[128];
	char    text[512];
	int64_t decode_us;       // a duracao medida de tokenize+feed+loop deste pedido
	int32_t tokens_out;      // tokens gerados (sem contar o parador)
} AfPromptOut;

void af_prompt_init(void); // idempotente; inicializa a secao critica e o estado de metricas

// Devolve o id (>= 1) ou um codigo negativo nomeado em `af_prompt_err_text`:
//   -1 sem contexto no processo (estado < 4), -2 pedido invalido (campo fora do teto),
//   -3 fila cheia, -4 papel fora do mapeamento.
int64_t af_prompt_enqueue(const AfPromptReq * req);

// 0 = pronto (`out` preenchido, sucesso ou recusa do decode em `out.status/out.reason`);
// 1 = timeout (reason = "timeout", o slot continua como esta); <0 = id desconhecido.
int af_prompt_wait(int64_t request_id, int32_t timeout_ms, AfPromptOut * out);

// As metricas de S5.3. `cache_hits` e 0 honesto: NAO existe cache no Passo 3 (o oracle_cache e
// do Passo 5) e um zero aqui diz a ausencia medida, nao um acerto falso. `cache_misses` conta
// cada pedido atendido sem cache -- a medida da ausencia.
int32_t af_prompt_queue_depth(void);   // na fila + rodando, lido sob a secao critica
int64_t af_prompt_cache_hits(void);
int64_t af_prompt_cache_misses(void);
int64_t af_prompt_worst_decode_us(void);

// Texto do ultimo codigo negativo (enqueue ou wait): a via de diagnostico que a ponte
// imprime, no mesmo padrao do `err_text` do pack -- o native nao imprime, devolve dado.
const char * af_prompt_err_text(void);

// A mesma funcao que o `af_pack_slots` e para o pack, agora para os simbolos de decodificacao:
// FORCA cada import a existir no binario (o /OPT:REF arranca funcao sem endereco tomado) e
// devolve o checksum dos enderecos, que a sonda compara entre exe e DLL.
int64_t af_prompt_slots(int imprimir);

} // extern "C"

#endif // AF_MIND_PROMPT_H
