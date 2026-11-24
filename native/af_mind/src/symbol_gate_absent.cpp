// Passo 2 (a) do dossie 22 (S1.3, S12.4): o controle negativo do gate de simbolos.
//
// Este arquivo NAO DEVE LINKAR. Ele existe para o build.bat provar que o gate de cima e uma
// afirmacao falsificavel: os nomes referenciados aqui sao as ausenciais medidas com
// `dumpbin /exports` no pin b12499 -- e cada uma e o nome que a documentacao do llama.cpp (e o
// prompt que gerou esta perna) usa para a MESMA tarefa que o `symbol_gate.cpp` resolve com um
// nome DIFERENTE, aquele que o export-set realmente tem. Quatro nomes, dois pares:
//
//  `ggml_backend_buffer_type_get_base_buffer` -- o nome com que o prompt descrevia a memoria
//              fina (`model_oversave`). O S1.3 mediu: nao esta em nenhuma das cinco DLLs.
//  `llama_model_n_ctx` -- o par falso do nome que o gate referencia de verdade,
//              `llama_model_n_ctx_train`.
//  `llama_new_context_with_model` -- o nome da documentacao para criar o contexto; nesta build
//              quem existe e `llama_init_from_model` (ordinal 86). Medido, nao deduzido: a
//              busca no `.def` gerado do dump devolve zero linhas para o nome da documentacao.
//  `ggml_backend_buffer_type_get_alloc_size` -- o nome da documentacao para o tamanho de alloc;
//              nesta build quem existe e `ggml_backend_buft_get_alloc_size` (ordinal 74).
//
// Os dois ultimos sao o achado desta passada, e sao tambem o motivo deste arquivo existir: se a
// lista do gate tivesse sido escrita de um header de outra versao, ela traria estas duas
// formas -- e o erro nao apareceria como vermelho no build, e como NULL (ou crash) dentro do
// jogo. E o mesmo erro que a terceira sonda da Fase 0 registrou, so que do lado do linker.
//
// Por que todos como DADO (`extern "C" void *nome;`) e nao como funcao: e exatamente a forma de
// declaracao que o gate usa para a classe dos enderecados, e assim o resultado deste controle
// depende so da EXISTENCIA do nome -- que e a unica coisa que o export-set sabe.
//
// Por que ha um `main`: sem ponto de entrada o linker reclamaria LNK1561 e o build leria um
// nao-zero pelo motivo errado, parecendo que o controle funcionou. Com `main`, o unico motivo
// possivel de recusa e LNK2019 nos nomes, e e o texto que a regua do build.bat procura.

extern "C" {
extern void * ggml_backend_buffer_type_get_base_buffer;
extern void * llama_model_n_ctx;
extern void * llama_new_context_with_model;
extern void * ggml_backend_buffer_type_get_alloc_size;
}

int main() {
	// Referencia real, para /O2 nao jogar fora: leio os slots e devolvo a diferenga.
	return (void *) &ggml_backend_buffer_type_get_base_buffer == (void *) &llama_model_n_ctx
		|| (void *) &llama_new_context_with_model == (void *) &ggml_backend_buffer_type_get_alloc_size;
}
