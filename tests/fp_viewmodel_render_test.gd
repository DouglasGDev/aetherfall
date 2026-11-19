extends SceneTree

const SIZE := Vector2i(1280, 720)
const CASES: Array[String] = ["grama", "golpe", "lavra", "pedra", "parede"]
const EXPECTED_CHECKS: int = 21

var _stage: Node3D
var _camera: Camera3D
var _vm: FPViewmodel
var _atlas: Texture2D
var _checks: int = 0
var _failures: int = 0
var _completed: int = 0
var _prefix: String = ""
var _finished: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("%s %s | %s" % ["OK" if ok else "FALHA", label, detail])


func _run() -> void:
	create_timer(15.0).timeout.connect(_timeout)
	if RenderingServer.get_rendering_device() == null:
		_check(false, "renderer real obrigatorio", "use Vulkan; --headless nao produz pixels")
		_finish()
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output-prefix="):
			_prefix = arg.trim_prefix("--output-prefix=")
	root.size = SIZE
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	root.use_taa = false
	BlockDefs.init_tables()
	_atlas = VoxelAtlas.build_texture()
	_stage = Node3D.new()
	root.add_child(_stage)
	_camera = Camera3D.new()
	_stage.add_child(_camera)
	_camera.make_current()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.18, 0.27, 0.36)
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_camera.environment = environment
	_check(_atlas != null and _camera.is_current(), "atlas real e camera ativa",
		"%dx%d GPU=%s" % [SIZE.x, SIZE.y, RenderingServer.get_video_adapter_name()])
	for case_name: String in CASES:
		if await _case(case_name) != true:
			_check(false, "cenario abortou", case_name)
			break
		_completed += 1
	if await _glass_and_empty() == true:
		_completed += 1
	_finish()


func _new_viewmodel(block: int) -> void:
	if is_instance_valid(_vm):
		_vm.free()
	_vm = FPViewmodel.new()
	_camera.add_child(_vm)
	_vm.set_atlas(_atlas)
	_vm.block_id = block
	_vm.advance(0.0)


func _frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _case(case_name: String) -> bool:
	_new_viewmodel(BlockDefs.Block.STONE if case_name == "pedra" else BlockDefs.Block.GRASS)
	if case_name == "golpe":
		_vm.swing()
		_vm.advance(0.12)
	elif case_name == "lavra":
		_vm.mining = true
		for i in 20:
			_vm.advance(1.0 / 60.0)
	var meshes: Array[Node] = _vm.find_children("*", "MeshInstance3D", true, false)
	var held := _vm.held_mesh()
	var material := held.material_override as StandardMaterial3D
	var highest_hand_priority: int = -128
	for mesh: MeshInstance3D in meshes:
		if mesh != held:
			var hand_material := mesh.get_active_material(0) as StandardMaterial3D
			highest_hand_priority = maxi(highest_hand_priority, hand_material.render_priority)
	_check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
		and material.render_priority > highest_hand_priority,
		case_name + " bloco opaco apos a mao",
		"bloco=%d mao=%d alpha=%d" % [material.render_priority,
			highest_hand_priority, material.transparency])
	var full := await _frame()
	for mesh: MeshInstance3D in meshes:
		mesh.visible = mesh == held
	var isolated := await _frame()
	var wall: MeshInstance3D = null
	if case_name == "parede":
		for mesh: MeshInstance3D in meshes:
			mesh.visible = true
		wall = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.0, 2.0, 0.02)
		wall.mesh = box
		wall.position.z = -0.10
		var wall_material := StandardMaterial3D.new()
		wall_material.albedo_color = Color(0.8, 0.1, 0.1)
		wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wall.material_override = wall_material
		_stage.add_child(wall)
		full = await _frame()
	var background := isolated.get_pixel(0, 0)
	var interior: int = 0
	var changed: int = 0
	for y in range(1, SIZE.y - 1):
		for x in range(1, SIZE.x - 1):
			if isolated.get_pixel(x, y).is_equal_approx(background):
				continue
			var edge: bool = false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if isolated.get_pixel(x + dx, y + dy).is_equal_approx(background):
						edge = true
			if edge:
				continue
			interior += 1
			if not full.get_pixel(x, y).is_equal_approx(isolated.get_pixel(x, y)):
				changed += 1
	_check(interior > 500, case_name + " pixels reais do bloco", "interior=%d" % interior)
	_check(changed == 0, case_name + " face sem pele sobreposta",
		"pixels diferentes=%d de %d" % [changed, interior])
	_save(full, case_name)
	if wall != null:
		wall.free()
	return true


func _glass_and_empty() -> bool:
	_new_viewmodel(BlockDefs.Block.GLASS)
	var glass := _vm.held_mesh().material_override as StandardMaterial3D
	_check(glass.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
		"vidro conserva transparencia", "alpha=%d" % glass.transparency)
	_save(await _frame(), "vidro")
	_vm.block_id = BlockDefs.Block.AIR
	_vm.advance(0.0)
	_check(not _vm.held_mesh().visible, "slot vazio esconde bloco", "id=%d" % _vm.block_id)
	var visible_parts: int = 0
	for mesh: MeshInstance3D in _vm.find_children("*", "MeshInstance3D", true, false):
		if mesh.is_visible_in_tree():
			visible_parts += 1
	_check(visible_parts == 9, "mao vazia preserva todos os segmentos", "malhas=%d" % visible_parts)
	_save(await _frame(), "vazio")
	return true


func _save(image: Image, suffix: String) -> void:
	if _prefix.is_empty():
		return
	var output := _prefix + "-" + suffix + ".png"
	if FileAccess.file_exists(output) or image.save_png(output) != OK:
		_failures += 1
		push_error("Nao foi possivel gravar captura nova: " + output)


func _timeout() -> void:
	if not _finished:
		_check(false, "watchdog", "runner nao concluiu em 15 s")
		_finish()


func _finish() -> void:
	_finished = true
	_check(_completed == CASES.size() + 1, "censo de cenarios", "%d/%d" % [_completed, CASES.size() + 1])
	_check(_checks + 1 == EXPECTED_CHECKS, "censo de checagens", "%d/%d" % [_checks + 1, EXPECTED_CHECKS])
	if is_instance_valid(_stage):
		_stage.free()
	print("%d checagens %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
