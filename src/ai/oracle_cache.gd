class_name OracleCache
extends RefCounted
## A cache do oraculo (dossie 22 §6.5): `hash(prompt ⊕ pack ⊕ params) -> resposta`,
## em ARQUIVO separado do save, lida ANTES de inferir. "Cache nao e memoria: e
## determinismo de CI" -- a segunda semente com a resposta gravada nem toca a fila
## (o modelo pode nem estar no processo), e e o que torna a Fase 1 reproduzivel em
## CI sem ligar o modelo a cada checagem (§7.3 fecha o terceiro lado do contrato
## do journal: com cache, o texto tem de ser o mesmo). Rejeitado no §6.5: cache
## em user:// como memoria persistente do mundo -- confundir cache com episodico
## e criar um segundo ledger, e o dono proibiu escrever no ledger.
##
## O formato e JSON com numero de versao: um arquivo de outra versao nao e lido
## como se fosse desta (recusa nomeada, entradas vazias) -- o mesmo cuidado do
## FORMAT_VERSION do journal, em escala de cache. Uma leitura falha nunca e
## silenciosa: o motivo fica em `ultimo_erro` para quem quiser imprimir.

const FORMATO := 1

## O arquivo, no caminho que quem ligou a cache escolheu (CLI `--oracle-cache=`,
## padrao da casa do `--tick-journal=`). Sem caminho nao existe cache.
var caminho: String
## Chaves de conteudo -> frase. So entra frase NAO vazia (narrativa recusada
## pelo verificador nunca se torna cache -- o que a cache devolve tem de ser o
## que o wrapper aceitou).
var entradas := {}
## O ultimo motivo de leitura ou gravacao falha, nomeado e nunca anônimo.
var ultimo_erro := ""


func _init(caminho_arquivo: String) -> void:
	caminho = caminho_arquivo
	if not FileAccess.file_exists(caminho):
		return  # primeira corrida: o arquivo nasce na primeira gravacao
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		ultimo_erro = "cache ilegivel (%s): %d" % [caminho, FileAccess.get_open_error()]
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not (data is Dictionary):
		ultimo_erro = "cache nao e um objeto JSON (%s)" % caminho
		return
	if int(data.get("formato", -1)) != FORMATO:
		ultimo_erro = "cache de formato %d, esperado %d (%s)" % [
			int(data.get("formato", -1)), FORMATO, caminho]
		return
	var brutas = data.get("entradas", {})
	if brutas is Dictionary:
		entradas = brutas


## A chave de conteudo do §6.5: prompt ⊕ pack ⊕ params, dobrados numa string e
## hasheados. Prompt igual com pack ou params diferentes e OUTRA entrada -- a
## chave nao pode colar duas perguntas que so coincidem na metade.
static func chave(prompt: String, pack: String, max_tokens: int, temperature: float) -> String:
	return ("%s|%s|%d|%s" % [prompt, pack, max_tokens, temperature]).sha256_text()


func tem(key: String) -> bool:
	return entradas.has(key) and String(entradas[key]) != ""


## Leitura antes de inferir: ausente devolve "" -- e narrativa gravada nunca e
## vazia, entao vazio e ausencia, nunca ambiguidade.
func le(key: String) -> String:
	return String(entradas.get(key, ""))


func grava(key: String, texto: String) -> bool:
	if key == "" or texto == "":
		ultimo_erro = "gravacao recusada: chave ou texto vazio"
		return false
	entradas[key] = texto
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		ultimo_erro = "cache nao gravou (%s): %d" % [caminho, FileAccess.get_open_error()]
		return false
	f.store_string(JSON.stringify({"formato": FORMATO, "entradas": entradas}, "  "))
	f.close()
	return FileAccess.file_exists(caminho)


func tamanho() -> int:
	return entradas.size()
