class_name Inventory
## Inventario do jogador: slots de (bloco, quantidade), pilha por bloco, e a
## hotbar como uma fila de pinos sobre os proprios slots.
##
## Modelo vindo do Veloren, verificado no codigo-fonte (branch master):
## - `DEFAULT_INVENTORY_SLOTS = 36` para o personagem, sem contar os slots que
##   bolsas equipadas acresceriam (common/src/comp/inventory/mod.rs:44);
## - a hotbar e do cliente: 10 teclas mapeadas sobre slots do inventario
##   (voxygen/src/hud/hotbar.rs), nao um deposito separado;
## - coletar preenche TODA pilha parcial do mesmo item antes de usar o primeiro
##   slot vazio (`push_prefer_slot` + `insert`, mod.rs);
## - empurrar uma pilha sobre outra do mesmo item mescla, senao troca
##   (server/src/events/inventory_manip.rs:814);
## - partir = metade por divisao inteira (`take_amount(amount / 2)`,
##   voxygen/src/ui/widgets/slot.rs:250).
##
## O que nao veio do Veloren: o teto numerico por bloco. La `max_amount()` devolve
## u32::MAX para qualquer item empilhavel e a pilha depende da CLASSE do item
## (item/mod.rs:873,889). Aqui o limite e por bloco (`BlockDefs.stack_max`) porque
## o mundo e feito de blocos, e o pedido foi explicito sobre trabalhar com quantidade.

signal changed()

const SLOTS: int = 36
const HOTBAR: int = 10
const COLS: int = 9
const ROWS: int = 4

var _ids := PackedInt32Array()
var _counts := PackedInt32Array()
# Pinos da hotbar: `_pins[k]` e o indice de slot que a tecla k mostra. -1 = livre.
var _pins := PackedInt32Array()
var hotbar_index: int = 0
# A pilha na "mao" do painel. No Veloren e o item em drag; aqui e teclado, e a
# regra de mesclar/trocar e a mesma.
var held_id: int = BlockDefs.Block.AIR
var held_count: int = 0


func _init() -> void:
	_ids.resize(SLOTS)
	_counts.resize(SLOTS)
	_pins.resize(HOTBAR)
	reset_default()


## Kit com que a sessao abre, na ordem de `BlockDefs.default_hotbar_blocks()`.
## Nao e inventario criativo: os blocos cheios sao o que ja existia na hotbar de
## 7 (agora com quantidade), e os dois slots de craft vem a 0 de proposito para
## a cadeia madeira -> tabua -> bancada continuar sendo o caminho real ate eles.
static func kit_counts() -> Dictionary:
	return {
		BlockDefs.Block.GRASS: 32,
		BlockDefs.Block.DIRT: 32,
		BlockDefs.Block.STONE: 16,
		BlockDefs.Block.SAND: 16,
		BlockDefs.Block.SNOW: 16,
		BlockDefs.Block.WOOD: 8,
		BlockDefs.Block.LEAVES: 8,
		BlockDefs.Block.PLANK: 0,
		BlockDefs.Block.BENCH: 0,
	}


func reset_default() -> void:
	_ids.fill(BlockDefs.Block.AIR)
	_counts.fill(0)
	var kit := kit_counts()
	var slot := 0
	for b in BlockDefs.default_hotbar_blocks():
		var n: int = int(kit.get(b, 0))
		if n > 0:
			_ids[slot] = b
			_counts[slot] = mini(n, BlockDefs.stack_max(b))
		slot += 1
	for k in HOTBAR:
		_pins[k] = k
	hotbar_index = 0
	held_id = BlockDefs.Block.AIR
	held_count = 0
	changed.emit()


# ------------------------------------------------------------------ leitura

func _valid(i: int) -> bool:
	return i >= 0 and i < SLOTS


func slot_block(i: int) -> int:
	return int(_ids[i]) if _valid(i) else BlockDefs.Block.AIR


func slot_count(i: int) -> int:
	return int(_counts[i]) if _valid(i) else 0


func selected_slot() -> int:
	return int(_pins[clampi(hotbar_index, 0, HOTBAR - 1)])


func selected_block() -> int:
	var s := selected_slot()
	if s < 0 or slot_count(s) <= 0:
		return BlockDefs.Block.AIR
	return slot_block(s)


func selected_count() -> int:
	var s := selected_slot()
	return slot_count(s) if s >= 0 else 0


func count_of(b: int) -> int:
	var total := 0
	for i in SLOTS:
		if _ids[i] == b:
			total += int(_counts[i])
	return total


func item_count() -> int:
	var total := 0
	for i in SLOTS:
		total += int(_counts[i])
	return total


## Quantos de `b` ainda entrariam. Lido ANTES de quebrar o bloco: no Veloren o
## que nao coube voltava para o mundo como entidade de item; sem entidade ainda,
## o que nao cabe simplesmente nao e minerado.
func space_for(b: int, want: int = 2147483647) -> int:
	if b == BlockDefs.Block.AIR or BlockDefs.stack_max(b) <= 0:
		return 0
	var free := 0
	for i in SLOTS:
		if _ids[i] == b and _counts[i] > 0:
			free += maxi(BlockDefs.stack_max(b) - int(_counts[i]), 0)
		elif _counts[i] <= 0:
			free += BlockDefs.stack_max(b)
		if free >= want:
			return want
	return free


# ------------------------------------------------------------------ escrita

func select(i: int) -> void:
	hotbar_index = posmod(i, HOTBAR)
	changed.emit()


## Pina o slot `i` na tecla `key`: e exatamente o modelo do Veloren, dez teclas
## do cliente apontando para slots. Um slot pode estar em mais de uma tecla; o
## que muda e a leitura, nunca a pilha.
func pin(key: int, i: int) -> bool:
	if key < 0 or key >= HOTBAR or not _valid(i):
		return false
	_pins[key] = i
	changed.emit()
	return true


func pin_of(key: int) -> int:
	return int(_pins[clampi(key, 0, HOTBAR - 1)])


## Adiciona ate `n` do bloco `b`; devolve o que NAO entrou.
func add(b: int, n: int) -> int:
	if b == BlockDefs.Block.AIR or n <= 0:
		return n
	var max_n := BlockDefs.stack_max(b)
	if max_n <= 0:
		return n
	var left := n
	# primeiro toda pilha parcial do mesmo bloco, na ordem dos slots
	for i in SLOTS:
		if left <= 0:
			break
		if _ids[i] != b or _counts[i] <= 0:
			continue
		var room: int = max_n - int(_counts[i])
		if room <= 0:
			continue
		var move: int = mini(room, left)
		_counts[i] = int(_counts[i]) + move
		left -= move
	for i in SLOTS:
		if left <= 0:
			break
		if _counts[i] > 0:
			continue
		var put: int = mini(max_n, left)
		_ids[i] = b
		_counts[i] = put
		left -= put
	if left < n:
		changed.emit()
	return left


## Remove ate `n` do bloco `b`, do ultimo slot para tras: as pilhas cheias da
## frente sao as ultimas a baixar. Devolve o que realmente saiu.
func take(b: int, n: int) -> int:
	var left := n
	for i in range(SLOTS - 1, -1, -1):
		if left <= 0:
			break
		if _ids[i] != b or _counts[i] <= 0:
			continue
		var out: int = mini(int(_counts[i]), left)
		_counts[i] = int(_counts[i]) - out
		left -= out
		if _counts[i] <= 0:
			_ids[i] = BlockDefs.Block.AIR
	if left < n:
		changed.emit()
	return n - left


func consume_selected(n: int) -> bool:
	var s := selected_slot()
	if s < 0 or slot_count(s) < n:
		return false
	_counts[s] = int(_counts[s]) - n
	if _counts[s] <= 0:
		_ids[s] = BlockDefs.Block.AIR
		_counts[s] = 0
	changed.emit()
	return true


## Pegar/soltar do painel. Mao vazia: a pilha inteira sobe. Mao cheia: mescla se
## for o mesmo bloco e couber, senao troca (inventory_manip.rs:814).
func pick_drop(i: int) -> bool:
	if not _valid(i):
		return false
	if held_count > 0:
		if slot_block(i) == held_id and slot_count(i) > 0:
			var room: int = BlockDefs.stack_max(held_id) - int(_counts[i])
			if room >= held_count:
				_counts[i] = int(_counts[i]) + held_count
				_clear_hand()
				changed.emit()
				return true
			if room > 0:
				_counts[i] = int(_counts[i]) + room
				held_count -= room
				changed.emit()
				return true
			return false
		var tmp_id: int = int(_ids[i])
		var tmp_n: int = int(_counts[i])
		_ids[i] = held_id
		_counts[i] = held_count
		held_id = tmp_id
		held_count = tmp_n
		if held_count <= 0:
			_clear_hand()
		changed.emit()
		return true
	if slot_count(i) <= 0:
		return false
	held_id = int(_ids[i])
	held_count = int(_counts[i])
	_ids[i] = BlockDefs.Block.AIR
	_counts[i] = 0
	changed.emit()
	return true


## Metade para a mao, divisao inteira como o `take_half` do Veloren: pilha de 1
## nao parte, e a mao precisa estar vazia.
func split(i: int) -> bool:
	if not _valid(i) or held_count > 0:
		return false
	var n: int = int(_counts[i]) / 2
	if n <= 0:
		return false
	held_id = int(_ids[i])
	held_count = n
	_counts[i] = int(_counts[i]) - n
	changed.emit()
	return true


func _clear_hand() -> void:
	held_id = BlockDefs.Block.AIR
	held_count = 0


## Guarda a mao ao fechar o painel: primeiro nas pilhas do mesmo bloco, depois no
## primeiro buraco. Devolve false se nao coube tudo (a pilha continua na mao para
## o jogador ver que ainda precisa de espaco).
func stash_hand() -> bool:
	if held_count <= 0:
		return true
	var left := add(held_id, held_count)
	if left > 0:
		held_count = left
		return false
	_clear_hand()
	return true


# ------------------------------------------------------------------ persistencia

func to_dict() -> Dictionary:
	var slots: Array = []
	for i in SLOTS:
		if _counts[i] > 0:
			slots.append([i, int(_ids[i]), int(_counts[i])])
	var pins: Array = []
	for k in HOTBAR:
		pins.append(int(_pins[k]))
	return {
		"slots": slots,
		"pins": pins,
		"sel": hotbar_index,
		"hand": [held_id, held_count],
	}


func from_dict(d: Dictionary) -> void:
	_ids.fill(BlockDefs.Block.AIR)
	_counts.fill(0)
	for e in d.get("slots", []):
		var i: int = clampi(int(e[0]), 0, SLOTS - 1)
		var b: int = clampi(int(e[1]), 0, BlockDefs.COUNT - 1)
		var n: int = clampi(int(e[2]), 0, BlockDefs.stack_max(b))
		if b == BlockDefs.Block.AIR or n <= 0:
			continue
		_ids[i] = b
		_counts[i] = n
	var pins: Array = d.get("pins", [])
	for k in HOTBAR:
		_pins[k] = clampi(int(pins[k]), -1, SLOTS - 1) if k < pins.size() else k
	hotbar_index = clampi(int(d.get("sel", 0)), 0, HOTBAR - 1)
	var hand: Array = d.get("hand", [])
	held_id = int(hand[0]) if hand.size() == 2 else BlockDefs.Block.AIR
	held_count = int(hand[1]) if hand.size() == 2 else 0
	changed.emit()
