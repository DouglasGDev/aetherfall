class_name BeliefVerifier
extends RefCounted
## O verificador nomeado na fronteira da Camada 5 (dossie 22 §6.4/§7.1): "a mente
## propoe, as regras dispoe" deixa de ser AUSENCIA de caminho e vira um portao
## checado. Com o modelo dentro do processo (mesmo heap), o argumento de que ele
## "nao tem para onde escrever" fica mais fraco — entao a saida que nomeia um
## `entity_id` que nao existe na alcateia NAO pode produzir narrativa, crenca nem
## intencao. O minimo do Passo 5 confere os ids de lobo citados no texto contra o
## roster da sessao; a Fase 2 (§5.6) expande o MESMO portao para os ids do ledger
## (grounded), sem mudar quem chama nem onde a fronteira fica.

## Motivo nomeado da ultima recusa — "" quando nada foi recusado. Imprimivel,
## nunca anonimo (dossie 15 §9).
var ultimo_motivo := ""
## O id apontado pela ultima recusa (-1 quando nenhuma): o numero que decide, na
## checagem e no log — "verificador recusou" sem o id e adjetivo, nao leitura.
## No modo roster (Passo 5) e o id forjado; no modo ledger (Fase 2 §20.6) e o id
## do fato contradito — nos dois casos o numero impresso explica a recusa.
var ultimo_id_forjado := -1
## Os ids cuja morte declarada o LEDGER confirmou na ultima saida aceite
## (Fase 2 §20.6): a saida declarou a morte de quem o ledger diz morto — fato
## verdadeiro, e a materia que o wrapper transforma em quarentena no Mind do
## narrador. Recusa limpa a lista; saida sem fato confirmado devolve vazia.
var fatos_confirmados: Array = []
## O que o verificador entende por DECLARAR MORTE (Fase 2 §20.6). O recorte e
## conservador de proposito: "matou o lobo N" fica FORA — associar a morte ao
## objeto pede um parser de papéis que o gate nao tem, e um falso positivo aqui
## custa uma narrativa recusada com o motivo impresso, nunca uma escrita
## errada no mundo (o portao e fail closed).
const RX_MORTE := "(?i)(esta\\s+mort[oa]|morreu|caiu|foi\\s+abatid[oa]|foi\\s+mort[oa])"


## Os ids de lobo que o texto cita, deduplicados na ordem do texto. A ponta da
## Fase 2 entra aqui (a mesma funcao, com os ids do ledger), sem mudar quem chama.
static func ids_citados(texto: String) -> Array:
	var ids: Array = []
	var rx := RegEx.create_from_string("(?i)lobo\\s+(\\d+)")
	if rx == null:
		return ids
	for m in rx.search_all(texto):
		var id := int(m.get_string(1))
		if not ids.has(id):
			ids.append(id)
	return ids


## A regra do §6.4: TODO id citado tem de existir na alcateia. `true` = a saida
## pode entrar (narrativa, crenca, intencao); `false` = citacao forjada, e o id
## e o motivo ficam gravados para quem imprime — recusa sem numero nao decide.
func aceitar(texto: String, ids_validos: Array) -> bool:
	ultimo_motivo = ""
	ultimo_id_forjado = -1
	fatos_confirmados = []
	for id in ids_citados(texto):
		if not ids_validos.has(id):
			ultimo_id_forjado = int(id)
			ultimo_motivo = "verificador recusou a saida: id %d citado nao existe na alcateia" % int(id)
			return false
	return true


## A regra da Fase 2 (§20.6): o LEDGER e a verdade de mundo e o portao o le —
## ids alem do roster (o jogador, ACTOR_PLAYER = 1, entre eles) existem pelo
## ledger, e o FATO declarado na saida e conferido contra ele:
##  - id fora do ledger -> recusa (a forja do Passo 5, agora contra o ledger);
##  - morte declarada sobre quem o ledger diz MORTO -> fato confirmado, vai em
##    `fatos_confirmados` para o wrapper escrever a quarentena;
##  - morte declarada sobre quem o ledger diz VIVO -> recusa com o id e o
##    motivo nomeados: o que o ledger contradiz nao vira narrativa, crenca nem
##    intencao.
func aceitar_ledger(texto: String, ledger: Dictionary) -> bool:
	ultimo_motivo = ""
	ultimo_id_forjado = -1
	fatos_confirmados = []
	for id in ids_citados(texto):
		if not ledger.has(id):
			ultimo_id_forjado = int(id)
			ultimo_motivo = "verificador recusou a saida: id %d citado nao existe no ledger" % int(id)
			return false
		if not bool(ledger[id]):
			# O ledger diz morto: a saida que DECLARA a morte nomeia um fato
			# verdadeiro — a morte do cadaver ja e verdade de mundo, e o que
			# entra no Mind e uma quarentena rebaixada, nunca fato novo.
			if _declara_morte(texto, int(id)):
				fatos_confirmados.append(int(id))
		elif _declara_morte(texto, int(id)):
			ultimo_id_forjado = int(id)
			ultimo_motivo = "verificador recusou a saida: fato contradito pelo ledger — o lobo %d e vivo e a saida o declara morto" % int(id)
			return false
	return true


## A saida declara a morte de `id` NA MESMA FRASE em que o cita: normaliza os
## pontos-fim (`!`, `?`, `;` viram `.`), fatia por frase e exige citacao e
## padrao de morte compartilhando a frase — "o lobo 1" nao pode casar "lobo 11"
## (lookahead no digito) e a morte de um fraseado nao contamina a de outro.
static func _declara_morte(texto: String, id: int) -> bool:
	var normalizado := texto
	for ch in ["!", "?", ";"]:
		normalizado = normalizado.replace(ch, ".")
	var rx_id := RegEx.create_from_string("(?i)lobo\\s+%d(?!\\d)" % id)
	var rx_morte := RegEx.create_from_string(RX_MORTE)
	if rx_id == null or rx_morte == null:
		return false
	for frase in normalizado.split(".", false):
		if rx_id.search(frase) != null and rx_morte.search(frase) != null:
			return true
	return false
