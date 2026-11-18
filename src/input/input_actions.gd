class_name InputActions
## Registro programatico do mapa de acoes. No projeto final isso sai para
## src/input/rebinder.gd com persistencia; no slice manter em codigo evita
## serializar InputEvent no project.godot e da ao teste headless o mesmo contrato.

const HOTBAR_ACTIONS: Array = [
	"hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4",
	"hotbar_5", "hotbar_6", "hotbar_7", "hotbar_8", "hotbar_9", "hotbar_0",
]
# A fileira de cima do numero e a de baixo do teclado: `0` e a decima tecla, como
# no hotbar de 10 do Veloren (voxygen/src/hud/hotbar.rs).
const HOTBAR_KEYS: Array = [
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5,
	KEY_6, KEY_7, KEY_8, KEY_9, KEY_0,
]


static func install() -> void:
	_key_action("move_forward", [KEY_W, KEY_UP])
	_key_action("move_back", [KEY_S, KEY_DOWN])
	_key_action("move_left", [KEY_A, KEY_LEFT])
	_key_action("move_right", [KEY_D, KEY_RIGHT])
	_key_action("jump", [KEY_SPACE])
	_key_action("sprint", [KEY_SHIFT])
	_key_action("crouch", [KEY_CTRL])
	# planar mora na mesma tecla do agachar, como no Veloren: no chao e agachar,
	# caindo e planar
	_key_action("glide", [KEY_CTRL])
	_key_action("break_block", [])
	_key_action("place_block", [])
	_key_action("switch_camera", [KEY_V])
	_key_action("toggle_ether_view", [KEY_B])
	_key_action("toggle_debug", [KEY_F3])
	_key_action("save_game", [KEY_F5])
	_key_action("load_game", [KEY_F9])
	_key_action("release_cursor", [KEY_ESCAPE])
	_key_action("respawn", [KEY_R])
	_key_action("toggle_binds", [KEY_F2])
	for i in HOTBAR_ACTIONS.size():
		_key_action(HOTBAR_ACTIONS[i], [HOTBAR_KEYS[i]])
	# painel de inventario: o cursor anda na grade com o mesmo teclado que anda o
	# personagem, e o Player segura o movimento enquanto a tela esta aberta
	_key_action("toggle_inventory", [KEY_I])
	_key_action("inv_take", [KEY_E])
	_key_action("inv_split", [KEY_Q])
	_key_action("inv_up", [KEY_W, KEY_UP])
	_key_action("inv_down", [KEY_S, KEY_DOWN])
	_key_action("inv_left", [KEY_A, KEY_LEFT])
	_key_action("inv_right", [KEY_D, KEY_RIGHT])
	_key_action("craft_next", [KEY_TAB])
	_key_action("craft_do", [KEY_ENTER, KEY_KP_ENTER])
	_mouse_action("break_block", MOUSE_BUTTON_LEFT)
	_mouse_action("place_block", MOUSE_BUTTON_RIGHT)
	_mouse_action("roll", MOUSE_BUTTON_MIDDLE)


static func _ensure(name: String) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.25)


static func _key_action(name: String, keys: Array) -> void:
	_ensure(name)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = int(k)
		InputMap.action_add_event(name, e)


static func _mouse_action(name: String, button: int) -> void:
	_ensure(name)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(name, e)
