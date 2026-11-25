class_name Hud
extends CanvasLayer
## HUD do slice: estado + controles, sem prosa explicativa (regra do projeto).
## Overlay de debug (F3) mostra a decisao da IA linha por linha: uma IA local que
## nao se explica e indistinguivel de um rand() na cara do jogador.

const SLOT_W: float = 46.0
const SLOT_H: float = 46.0
const SLOT_GAP: float = 6.0
const HP_W: float = 210.0
const MINE_W: float = 128.0
const REFRESH: float = 0.1
# grade do painel: mesmo COLS/ROWS do inventario, 4 linhas de 9 slots
const CELL: float = 44.0
const CELL_GAP: float = 4.0

var player: Player = null
var world: VoxelWorld = null
var aether: AetherField = null
var clock: SimClock = null
## Fila de queda de bloco (dossie 17 §3.6): estourar o teto da fila adia grao em vez de
## perder, e isso tem de aparecer no F3 e nao num log que ninguem abre. Provider, nao referencia:
## o HUD nao e dono do estado do mundo.
var block_provider: Callable = Callable()
var stats_provider: Callable = Callable()
var wolf_provider: Callable = Callable()
var narration_provider: Callable = Callable()
## Linha do hospedeiro do servidor de modelo no overlay de debug: cada estado da
## matriz de falha do dossie 15 §5 tem de aparecer aqui, nao no console do motor
## nem em popup.
var llm_status_provider: Callable = Callable()

var _root: Control = null
var _slots: Array = []
var _hp_fill: ColorRect = null
var _hp_text: Label = null
var _energy_fill: ColorRect = null
var _air_bg: ColorRect = null
var _air_fill: ColorRect = null
var _target_label: Label = null
var _mine_bg: ColorRect = null
var _mine_fill: ColorRect = null
var _toast: Label = null
var _toast_cd: float = 0.0
var _death: Control = null
var _debug: Label = null
var _binds: Label = null
var _binds_cd: float = 0.0
var _debug_on: bool = false
var _refresh_cd: float = 0.0

var _panel: Control = null
var _cells: Array = []
var _cursor: int = 0
var _recipe: int = 0
var _head_label: Label = null
var _info_label: Label = null
var _hand_label: Label = null
var _recipe_labels: Array = []
var _footer_label: Label = null

const BINDS_TEXT := """WASD   mover
mouse  olhar
1-9,0  hotbar
ESQ    minerar / atacar
DIR    colocar
MMID   rolar
ESPACO pular
SHIFT  correr
CTRL   agachar / planar
V      camera 1a/3a
B      visao do eter
I      inventario / craft
F5     salvar
F9     carregar
R      renascer
ESC    cursor
F2     binds
F3     debug"""

const PANEL_FOOTER := """WASD/setas cursor   E pegar-soltar   Q partir
1-9,0 fixar tecla   TAB receita   ENTER craftar   I fechar"""

const INVENTORY_KEY_LABELS: PackedStringArray = [
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
]


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_crosshair()
	_build_target()
	_build_vitals()
	_build_toast()
	_build_debug()
	_build_binds()
	_build_death()
	_build_panel()


## A fileira de baixo da tela: dez teclas, cada uma um pino sobre um slot do
## inventario (o hotbar do Veloren e exatamente isto, e nao um deposito proprio).
func build_hotbar() -> void:
	for s in _slots:
		(s["node"] as Control).queue_free()
	_slots.clear()
	var n := Inventory.HOTBAR
	var total := float(n) * SLOT_W + float(n - 1) * SLOT_GAP
	for i in n:
		var base := -total * 0.5 + float(i) * (SLOT_W + SLOT_GAP)
		var p := Panel.new()
		p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		p.offset_left = base
		p.offset_right = base + SLOT_W
		p.offset_top = -SLOT_H - 18.0
		p.offset_bottom = -18.0
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.06, 0.07, 0.09, 0.72)
		box.set_border_width_all(2)
		box.border_color = Color(1, 1, 1, 0.22)
		p.add_theme_stylebox_override("panel", box)
		var sw := ColorRect.new()
		sw.set_anchors_preset(Control.PRESET_TOP_LEFT)
		sw.offset_left = 6.0
		sw.offset_top = 13.0
		sw.offset_right = SLOT_W - 6.0
		sw.offset_bottom = 31.0
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(sw)
		var idx := _label(INVENTORY_KEY_LABELS[i], 10, Color(1, 1, 1, 0.75))
		idx.set_anchors_preset(Control.PRESET_TOP_LEFT)
		idx.offset_left = 4.0
		p.add_child(idx)
		var ct := _label("", 11, Color(1, 1, 1, 0.95))
		ct.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		ct.offset_left = -SLOT_W + 10.0
		ct.offset_right = -3.0
		ct.offset_top = 1.0
		ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		p.add_child(ct)
		var nm := _label("", 9, Color(1, 1, 1, 0.88))
		nm.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		nm.offset_top = -13.0
		nm.offset_bottom = -1.0
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(nm)
		_root.add_child(p)
		_slots.append({"node": p, "box": box, "sw": sw, "nm": nm, "ct": ct})
	_refresh_slots()


func show_message(text: String, seconds: float = 2.6) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_cd = seconds


func set_death(v: bool) -> void:
	_death.visible = v


func show_debug(v: bool) -> void:
	_debug_on = v
	_debug.visible = v


func debug_visible() -> bool:
	return _debug_on


func show_binds(v: bool) -> void:
	# Qualquer chamada explicita (F2) cancela a prévia do spawn: quem abriu o
	# painel quer vê-lo, não quer que ele feche sozinho.
	_binds_cd = 0.0
	_binds.visible = v


## Abre o painel de binds por um tempo no spawn: `DIR colocar` e a mecânica que
## nao aparece em lugar nenhum ate o jogador descobrir o botao direito.
func preview_binds(seconds: float) -> void:
	_binds.visible = true
	_binds_cd = seconds


func _process(delta: float) -> void:
	if player == null:
		return
	var ratio := clampf(player.hp / player.max_hp, 0.0, 1.0)
	_hp_fill.size.x = HP_W * ratio
	_hp_text.text = "%d / %d" % [int(round(player.hp)), int(player.max_hp)]
	var vigor := clampf(player.energy / player.max_energy, 0.0, 1.0)
	_energy_fill.size.x = HP_W * vigor
	var air_ratio := clampf(player.air / Player.AIR_MAX, 0.0, 1.0)
	var air_show := air_ratio < 0.999
	_air_bg.visible = air_show
	_air_fill.visible = air_show
	_air_fill.size.x = HP_W * air_ratio
	var mining := clampf(player.mining_progress, 0.0, 1.0)
	_mine_bg.visible = mining > 0.0
	_mine_fill.visible = mining > 0.0
	_mine_fill.size.x = MINE_W * mining
	_target_label.text = player.look_target_name
	_refresh_cd -= delta
	if _refresh_cd <= 0.0:
		_refresh_cd = REFRESH
		_refresh_slots()
		_refresh_state()
		if _panel.visible:
			_refresh_panel()
	if _toast_cd > 0.0:
		_toast_cd -= delta
		_toast.modulate.a = clampf(_toast_cd / 0.6, 0.0, 1.0)
	if _binds_cd > 0.0:
		_binds_cd -= delta
		if _binds_cd <= 0.0:
			_binds.visible = false


func _refresh_slots() -> void:
	if player == null:
		return
	var inv := player.inv
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var slot := inv.pin_of(i)
		var cnt := inv.slot_count(slot)
		var b := inv.slot_block(slot) if cnt > 0 else BlockDefs.Block.AIR
		var sel: bool = i == inv.hotbar_index
		var box: StyleBoxFlat = s["box"]
		# pilha vazia nao e "slot sem bloco": e buraco livre, e o contorno some para
		# o jogador contar com os olhos onde ainda cabe material
		if sel:
			box.border_color = Color(1.0, 0.92, 0.55, 0.95)
		elif cnt > 0:
			box.border_color = Color(1, 1, 1, 0.20)
		else:
			box.border_color = Color(1, 1, 1, 0.07)
		(s["sw"] as ColorRect).color = BlockDefs.swatch(b)
		(s["nm"] as Label).text = BlockDefs.display_name(b) if cnt > 0 else ""
		(s["ct"] as Label).text = str(cnt) if cnt > 1 else ""


func _refresh_state() -> void:
	if not _debug_on:
		return
	var lines: Array = ["fps %d  processo %.2f ms  fisica %.2f ms" % [
			int(Engine.get_frames_per_second()),
			Performance.get_monitor(Performance.TIME_PROCESS),
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)]]
	if world != null:
		lines.append("chunks %d  malhas %d  fila %d  ultimo %.2f ms" % [
			world.chunks.size(), world.meshes_built(), world.pending_meshes(),
			world.last_mesh_ms()])
	if clock != null:
		lines.append("tick %d  sim %.2f ms  pior %.2f ms  perdidos %d" % [
			clock.tick, clock.last_step_ms, clock.worst_step_ms, clock.dropped_ticks])
	if block_provider.is_valid():
		var bq: Dictionary = block_provider.call()
		lines.append("blocos  fila %d  em voo %d  eventos %d  leituras %d  overflow %d" % [
			int(bq.get("queued", 0)), int(bq.get("falling", 0)), int(bq.get("events", 0)),
			int(bq.get("reads", 0)), int(bq.get("overflow", 0))])
	if aether != null:
		var t: Array = aether.channel_totals()
		lines.append("eter  trabalho %.2f  sangue %.2f  medo %.2f" % [t[0], t[1], t[2]])
	if llm_status_provider.is_valid():
		lines.append(String(llm_status_provider.call()))
	if stats_provider.is_valid():
		lines.append(String(stats_provider.call()))
	if player != null:
		var pb := Coords.to_block(player.position3())
		var mira := "-"
		if player.target_valid:
			var tv := player.target_voxel
			mira = "%d,%d,%d" % [tv.x, tv.y, tv.z]
		lines.append("pos %d,%d,%d  mira %s" % [pb.x, pb.y, pb.z, mira])
	if wolf_provider.is_valid():
		for w in wolf_provider.call():
			var line := String(w.debug_line())
			if narration_provider.is_valid():
				var narr := String(narration_provider.call(w.identity))
				if not narr.is_empty():
					line += "  ia: " + narr
			lines.append(line)
	_debug.text = "\n".join(lines)


func _centered(text: String, size: int, color: Color, top: float, half_w: float) -> Label:
	var l := _label(text, size, color)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -half_w
	l.offset_right = half_w
	l.offset_top = top
	l.offset_bottom = top + float(size) + 6.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _build_crosshair() -> void:
	var bars := [
		[-9.0, -1.0, 0.0, 1.0], [1.0, -1.0, 9.0, 1.0],
		[-1.0, -9.0, 1.0, -1.0], [-1.0, 1.0, 1.0, 9.0],
	]
	for b in bars:
		var r := ColorRect.new()
		r.color = Color(1, 1, 1, 0.7)
		r.set_anchors_preset(Control.PRESET_CENTER)
		r.offset_left = b[0]
		r.offset_top = b[1]
		r.offset_right = b[2]
		r.offset_bottom = b[3]
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(r)


func _build_target() -> void:
	_target_label = _centered("", 12, Color(1, 1, 1, 0.85), 44.0, 160.0)
	_root.add_child(_target_label)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bg.offset_left = -MINE_W * 0.5
	bg.offset_right = MINE_W * 0.5
	bg.offset_top = 64.0
	bg.offset_bottom = 69.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A trilha vazia nao e informacao: sem lavrar nada, a barra e um risco preto
	# no ceu. So aparece com progresso real de mineracao.
	bg.visible = false
	_mine_bg = bg
	_root.add_child(bg)
	_mine_fill = ColorRect.new()
	_mine_fill.color = Color(0.95, 0.85, 0.35, 0.95)
	_mine_fill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_mine_fill.offset_left = -MINE_W * 0.5
	_mine_fill.offset_top = 64.0
	_mine_fill.offset_bottom = 69.0
	_mine_fill.size.x = 0.0
	_mine_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_mine_fill)


func _build_vitals() -> void:
	# pilha: ar (so quando falta) acima, vigor no meio, vida embaixo
	_air_bg = ColorRect.new()
	_air_bg.color = Color(0, 0, 0, 0.55)
	_air_bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_air_bg.offset_left = 16.0
	_air_bg.offset_top = -74.0
	_air_bg.offset_right = 16.0 + HP_W + 4.0
	_air_bg.offset_bottom = -56.0
	_air_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_air_bg.visible = false
	_root.add_child(_air_bg)
	_air_fill = ColorRect.new()
	_air_fill.color = Color(0.38, 0.70, 0.95, 0.95)
	_air_fill.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_air_fill.offset_left = 18.0
	_air_fill.offset_top = -72.0
	_air_fill.offset_right = 18.0 + HP_W
	_air_fill.offset_bottom = -58.0
	_air_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_air_fill.visible = false
	_root.add_child(_air_fill)
	var energy_bg := ColorRect.new()
	energy_bg.color = Color(0, 0, 0, 0.55)
	energy_bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	energy_bg.offset_left = 16.0
	energy_bg.offset_top = -54.0
	energy_bg.offset_right = 16.0 + HP_W + 4.0
	energy_bg.offset_bottom = -36.0
	energy_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(energy_bg)
	_energy_fill = ColorRect.new()
	_energy_fill.color = Color(0.92, 0.78, 0.28, 0.95)
	_energy_fill.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_energy_fill.offset_left = 18.0
	_energy_fill.offset_top = -52.0
	_energy_fill.offset_right = 18.0 + HP_W
	_energy_fill.offset_bottom = -38.0
	_energy_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_energy_fill)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bg.offset_left = 16.0
	bg.offset_top = -34.0
	bg.offset_right = 16.0 + HP_W + 4.0
	bg.offset_bottom = -16.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.72, 0.16, 0.18, 0.95)
	_hp_fill.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hp_fill.offset_left = 18.0
	_hp_fill.offset_top = -32.0
	_hp_fill.offset_right = 18.0 + HP_W
	_hp_fill.offset_bottom = -18.0
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hp_fill)
	_hp_text = _label("", 11, Color(1, 1, 1, 0.95))
	_hp_text.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hp_text.offset_left = 24.0
	_hp_text.offset_top = -32.0
	_root.add_child(_hp_text)


func _build_toast() -> void:
	_toast = _centered("", 14, Color(1, 1, 1, 0.95), 96.0, 320.0)
	_toast.modulate.a = 0.0
	_root.add_child(_toast)


func _build_debug() -> void:
	_debug = _label("", 11, Color(0.85, 0.95, 1.0, 0.95))
	_debug.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_debug.offset_left = 14.0
	_debug.offset_top = 12.0
	_debug.visible = false
	_root.add_child(_debug)


func _build_binds() -> void:
	_binds = _label(BINDS_TEXT, 11, Color(1, 1, 1, 0.9))
	_binds.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_binds.offset_left = -210.0
	_binds.offset_top = 12.0
	_binds.offset_right = -12.0
	_binds.visible = false
	_root.add_child(_binds)


func _build_death() -> void:
	_death = Control.new()
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.add_child(dim)
	_death.add_child(_centered("VOCE MORREU", 34, Color(0.95, 0.35, 0.3, 1), 200.0, 320.0))
	_death.add_child(_centered("R  renascer no ultimo ponto", 15,
			Color(1, 1, 1, 0.85), 252.0, 320.0))
	_death.visible = false
	_root.add_child(_death)


# --------------------------------------------------------------------- painel

## Tela de inventario e craft. Sem mouse: o cursor anda na grade com o mesmo
## teclado que anda o personagem e o Player congela o movimento enquanto ela esta
## aberta. E o modelo do Veloren (lista de receitas, nao grade de craft) trazido
## para teclado porque o slice nao tem arrastar-e-soltar.
func _build_panel() -> void:
	_panel = Control.new()
	_panel.name = "InvPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -384.0
	_panel.offset_right = 384.0
	_panel.offset_top = -170.0
	_panel.offset_bottom = 170.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.06, 0.90)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(bg)
	_head_label = _label("", 12, Color(0.85, 0.95, 1.0, 0.95))
	_head_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_head_label.offset_left = 16.0
	_head_label.offset_top = 6.0
	_head_label.offset_right = 752.0
	_panel.add_child(_head_label)
	for r in Inventory.ROWS:
		for c in Inventory.COLS:
			var i: int = r * Inventory.COLS + c
			var x0 := 16.0 + float(c) * (CELL + CELL_GAP)
			var y0 := 30.0 + float(r) * (CELL + CELL_GAP)
			var p := Panel.new()
			p.set_anchors_preset(Control.PRESET_TOP_LEFT)
			p.offset_left = x0
			p.offset_top = y0
			p.offset_right = x0 + CELL
			p.offset_bottom = y0 + CELL
			var box := StyleBoxFlat.new()
			box.bg_color = Color(0.08, 0.09, 0.12, 0.9)
			box.set_border_width_all(2)
			box.border_color = Color(1, 1, 1, 0.14)
			p.add_theme_stylebox_override("panel", box)
			var sw := ColorRect.new()
			sw.set_anchors_preset(Control.PRESET_TOP_LEFT)
			sw.offset_left = 5.0
			sw.offset_top = 11.0
			sw.offset_right = CELL - 5.0
			sw.offset_bottom = 29.0
			sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.add_child(sw)
			var ct := _label("", 11, Color(1, 1, 1, 0.95))
			ct.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			ct.offset_left = -CELL + 8.0
			ct.offset_right = -2.0
			ct.offset_top = 0.0
			ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			p.add_child(ct)
			var pn := _label("", 9, Color(1.0, 0.92, 0.55, 0.9))
			pn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			pn.offset_left = 3.0
			pn.offset_top = -12.0
			pn.offset_bottom = 0.0
			p.add_child(pn)
			_panel.add_child(p)
			_cells.append({"box": box, "sw": sw, "ct": ct, "pn": pn})
	_info_label = _label("", 11, Color(1, 1, 1, 0.9))
	_info_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_info_label.offset_left = 16.0
	_info_label.offset_top = 232.0
	_info_label.offset_right = 440.0
	_panel.add_child(_info_label)
	_hand_label = _label("", 11, Color(1.0, 0.85, 0.45, 0.95))
	_hand_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hand_label.offset_left = 16.0
	_hand_label.offset_top = 254.0
	_hand_label.offset_right = 440.0
	_panel.add_child(_hand_label)
	_footer_label = _label(PANEL_FOOTER, 10, Color(1, 1, 1, 0.62))
	_footer_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_footer_label.offset_left = 16.0
	_footer_label.offset_top = 288.0
	_footer_label.offset_right = 440.0
	_panel.add_child(_footer_label)
	var rh := _label("receitas", 12, Color(0.85, 0.95, 1.0, 0.95))
	rh.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rh.offset_left = 452.0
	rh.offset_top = 6.0
	rh.offset_right = 752.0
	_panel.add_child(rh)
	for k in Recipes.list().size():
		var rl := _label("", 11, Color(1, 1, 1, 0.9))
		rl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		rl.offset_left = 452.0
		rl.offset_top = 30.0 + float(k) * 22.0
		rl.offset_right = 752.0
		_panel.add_child(rl)
		_recipe_labels.append(rl)
	_panel.visible = false
	_root.add_child(_panel)


func show_panel(v: bool) -> void:
	_panel.visible = v
	if v:
		_refresh_panel()


func panel_visible() -> bool:
	return _panel.visible


func panel_cursor() -> int:
	return _cursor


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible or player == null:
		return
	if event.is_action_pressed("inv_up"):
		_move(-Inventory.COLS)
	elif event.is_action_pressed("inv_down"):
		_move(Inventory.COLS)
	elif event.is_action_pressed("inv_left"):
		_move(-1)
	elif event.is_action_pressed("inv_right"):
		_move(1)
	elif event.is_action_pressed("inv_take"):
		player.inv.pick_drop(_cursor)
	elif event.is_action_pressed("inv_split"):
		player.inv.split(_cursor)
	elif event.is_action_pressed("craft_next"):
		_recipe = 0 if _visible_recipes().size() <= 1 else posmod(_recipe + 1, _visible_recipes().size())
	elif event.is_action_pressed("craft_do"):
		_craft()
		return
	else:
		for i in InputActions.HOTBAR_ACTIONS.size():
			if event.is_action_pressed(InputActions.HOTBAR_ACTIONS[i]):
				player.inv.pin(i, _cursor)
				break
		return
	_refresh_panel()


func _move(d: int) -> void:
	_cursor = clampi(_cursor + d, 0, Inventory.SLOTS - 1)


func _visible_recipes() -> Array:
	return Recipes.visible(player.bench_near())


func _craft() -> void:
	var list := _visible_recipes()
	if list.is_empty():
		return
	var r: Dictionary = list[clampi(_recipe, 0, list.size() - 1)]
	if Recipes.craft(r, player.inv):
		show_message("craftado  %s" % Recipes.label(r))
	else:
		show_message("sem material ou sem espaco  %s" % Recipes.label(r))
	_refresh_panel()


func _refresh_panel() -> void:
	var inv := player.inv
	var bench := player.bench_near()
	_head_label.text = "INVENTARIO   %d itens em %d slots   %s" % [
		inv.item_count(), Inventory.SLOTS,
		"bancada por perto" if bench else "sem bancada por perto (so as de mao)",
	]
	for i in _cells.size():
		var cell: Dictionary = _cells[i]
		var cnt := inv.slot_count(i)
		var b := inv.slot_block(i) if cnt > 0 else BlockDefs.Block.AIR
		var on: bool = i == _cursor
		var box: StyleBoxFlat = cell["box"]
		if on:
			box.border_color = Color(1.0, 0.92, 0.55, 0.95)
		elif cnt > 0:
			box.border_color = Color(1, 1, 1, 0.22)
		else:
			box.border_color = Color(1, 1, 1, 0.08)
		(cell["sw"] as ColorRect).color = BlockDefs.swatch(b)
		(cell["ct"] as Label).text = str(cnt) if cnt > 0 else ""
		var pin_key := -1
		for k in Inventory.HOTBAR:
			if inv.pin_of(k) == i:
				pin_key = k
				break
		(cell["pn"] as Label).text = INVENTORY_KEY_LABELS[pin_key] if pin_key >= 0 else ""
	var cb := inv.slot_block(_cursor)
	var cn := inv.slot_count(_cursor)
	_info_label.text = ("slot %d   %d %s" % [_cursor + 1, cn, BlockDefs.display_name(cb)]) \
			if cn > 0 else "slot %d   vazio" % (_cursor + 1)
	_hand_label.text = ("na mao   %d %s" % [inv.held_count, BlockDefs.display_name(inv.held_id)]) \
			if inv.held_count > 0 else "na mao   nada"
	var list := Recipes.visible(bench)
	for k in _recipe_labels.size():
		var l: Label = _recipe_labels[k]
		if k >= list.size():
			l.text = ""
			continue
		var r: Dictionary = list[k]
		var head := ">" if k == _recipe else " "
		l.text = "%s %s" % [head, Recipes.label(r)]
		l.add_theme_color_override("font_color",
			Color(1.0, 0.92, 0.55, 0.95) if (k == _recipe and Recipes.can_craft(r, inv))
			else Color(0.75, 0.78, 0.84, 0.55) if k == _recipe
			else Color(1, 1, 1, 0.62) if Recipes.can_craft(r, inv)
			else Color(1, 1, 1, 0.28))


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
