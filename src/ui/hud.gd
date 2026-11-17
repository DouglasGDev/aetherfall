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

var player: Player = null
var world: VoxelWorld = null
var aether: AetherField = null
var clock: SimClock = null
var stats_provider: Callable = Callable()
var wolf_provider: Callable = Callable()

var _root: Control = null
var _slots: Array = []
var _hp_fill: ColorRect = null
var _hp_text: Label = null
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

const BINDS_TEXT := """WASD   mover
mouse  olhar
1-7    bloco
ESQ    minerar / morder
DIR    colocar
ESPACO pular
SHIFT  correr
CTRL   agachar
V      camera 1a/3a
B      visao do eter
F5     salvar
F9     carregar
R      renascer
ESC    cursor
F2     binds
F3     debug"""


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


func build_hotbar(blocks: Array[int]) -> void:
	for s in _slots:
		(s["node"] as Control).queue_free()
	_slots.clear()
	var n := blocks.size()
	if n == 0:
		return
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
		sw.color = BlockDefs.swatch(blocks[i])
		sw.set_anchors_preset(Control.PRESET_TOP_LEFT)
		sw.offset_left = 6.0
		sw.offset_top = 13.0
		sw.offset_right = SLOT_W - 6.0
		sw.offset_bottom = 31.0
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(sw)
		var idx := _label(str(i + 1), 10, Color(1, 1, 1, 0.75))
		idx.set_anchors_preset(Control.PRESET_TOP_LEFT)
		idx.offset_left = 4.0
		p.add_child(idx)
		var nm := _label(BlockDefs.display_name(blocks[i]), 9, Color(1, 1, 1, 0.88))
		nm.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		nm.offset_top = -13.0
		nm.offset_bottom = -1.0
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(nm)
		_root.add_child(p)
		_slots.append({"node": p, "box": box})
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
	for i in _slots.size():
		var sel: bool = i == player.hotbar_index
		var box: StyleBoxFlat = _slots[i]["box"]
		box.border_color = Color(1.0, 0.92, 0.55, 0.95) if sel else Color(1, 1, 1, 0.20)


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
	if aether != null:
		var t: Array = aether.channel_totals()
		lines.append("eter  trabalho %.2f  sangue %.2f  medo %.2f" % [t[0], t[1], t[2]])
	if stats_provider.is_valid():
		lines.append(String(stats_provider.call()))
	if wolf_provider.is_valid():
		for w in wolf_provider.call():
			lines.append(w.debug_line())
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


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
