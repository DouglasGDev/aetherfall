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
## O id forjado da ultima recusa (-1 quando nenhuma): o numero que decide, na
## checagem e no log — "verificador recusou" sem o id e adjetivo, nao leitura.
var ultimo_id_forjado := -1


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
	for id in ids_citados(texto):
		if not ids_validos.has(id):
			ultimo_id_forjado = int(id)
			ultimo_motivo = "verificador recusou a saida: id %d citado nao existe na alcateia" % int(id)
			return false
	return true
