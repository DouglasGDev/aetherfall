class_name Recipes
## Lista de receitas do slice, no modelo do Veloren: nao ha grade de craft, ha
## uma LISTA de receitas e cada uma pede insumos do inventario (common/src/recipe.rs:
## `Recipe { output, inputs, craft_sprite }`).
##
## Estacao no Veloren e um sprite do mundo a ate `MAX_PICKUP_RANGE` = 5,0 m
## (common/src/consts.rs:2) casado com `craft_sprite`; aqui a bancada e um bloco
## e o casamento e a distancia ate o bloco mais proximo. As receitas de mao nao
## pedem estacao nenhuma.
##
## Conhecimento de receita: no Veloren a RecipeBook so mostra o que foi
## desbloqueado consumindo um item RecipeGroup (inventory_manip.rs:668). No slice
## o jogador comeca sabendo tudo e o que filtra a lista e a estacao - a
## progressao de pergaminhos fica no plano do documento 05 e nao e pedido aqui.

enum Station { HAND = 0, BENCH = 1 }

const BENCH_RANGE: float = 5.0

const STATION_NAMES: PackedStringArray = ["mao", "bancada"]

static var _list: Array = []


static func list() -> Array:
	if _list.is_empty():
		_build()
	return _list


static func _build() -> void:
	_list = [
		# abrir uma tora em prancha e o primeiro degrau: nao pede estacao porque
		# e o que se faz com a ferramenta que o jogador ja tem na mao
		_r(BlockDefs.Block.PLANK, 4, [[BlockDefs.Block.WOOD, 1]], Station.HAND),
		# a estacao sai da propria cadeia: 1 madeira -> 4 tabuas, 4 tabuas -> 1 bancada
		_r(BlockDefs.Block.BENCH, 1, [[BlockDefs.Block.PLANK, 4]], Station.HAND),
		# lapear pedra bruta em pedra assentada: o motivo de a lavra soltar bruta
		_r(BlockDefs.Block.STONE, 1, [[BlockDefs.Block.COBBLESTONE, 4]], Station.BENCH),
		# vidro de areia na bancada. No Veloren isso e forja/caldeirao; aqui a
		# bancada cobre o degrau ate existir estacao de calor (doc 10 trata de lava)
		_r(BlockDefs.Block.GLASS, 1, [[BlockDefs.Block.SAND, 2]], Station.BENCH),
	]


static func _r(out: int, n: int, inputs: Array, st: int) -> Dictionary:
	return {"out": out, "out_n": n, "in": inputs, "station": st}


## As receitas que o jogador pode ver agora: as de mao sempre, as de bancada so
## com uma bancada por perto (o filtro por sprite do Veloren).
static func visible(bench_near: bool) -> Array:
	var out: Array = []
	for r in list():
		if bench_near or int(r["station"]) == Station.HAND:
			out.append(r)
	return out


static func station_of(r: Dictionary) -> int:
	return int(r["station"])


static func station_name(st: int) -> String:
	return STATION_NAMES[clampi(st, 0, STATION_NAMES.size() - 1)]


## Falta? Cada insumo precisa estar inteiro no inventario, e a saida precisa ter
## para onde ir: o Veloren punha o resto de volta no mundo, e aqui a fabricacao
## simplesmente nao comeca sem espaco.
static func can_craft(r: Dictionary, inv: Inventory) -> bool:
	var out: int = int(r["out"])
	if inv.space_for(out, int(r["out_n"])) < int(r["out_n"]):
		return false
	for e in r["in"]:
		if inv.count_of(int(e[0])) < int(e[1]):
			return false
	return true


## Consome e produz. Devolve false sem tocar em nada quando nao da: o caminho
## inteiro passa por `can_craft` antes do primeiro `take`, entao nao existe
## meio-craft para desfazer.
static func craft(r: Dictionary, inv: Inventory) -> bool:
	if not can_craft(r, inv):
		return false
	for e in r["in"]:
		inv.take(int(e[0]), int(e[1]))
	inv.add(int(r["out"]), int(r["out_n"]))
	return true


## "4 tabua -> 1 bancada  (mao)": a linha do painel e do teste.
static func label(r: Dictionary) -> String:
	var parts: Array = []
	for e in r["in"]:
		parts.append("%d %s" % [int(e[1]), BlockDefs.display_name(int(e[0]))])
	return "%s -> %d %s  (%s)" % [
		" + ".join(parts), int(r["out_n"]),
		BlockDefs.display_name(int(r["out"])), station_name(int(r["station"])),
	]
