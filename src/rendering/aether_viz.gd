class_name AetherViz
extends MeshInstance3D
## Camada de visualizacao do Eter (tecla B): um quad por celula ativa, cor por canal,
## alfa pela intensidade. Malha unica com vertex color = 1 draw call e nada de
## MultiMesh com semantica de cor instanciada duvidosa.

const QUAD_CORNERS: Array = [
	Vector3(-0.5, 0.0, -0.5), Vector3(-0.5, 0.0, 0.5),
	Vector3(0.5, 0.0, 0.5), Vector3(0.5, 0.0, -0.5),
]
const QUAD_INDEX: Array = [0, 1, 2, 0, 2, 3]
const CHANNEL_COLOR: Array = [
	Color(1.00, 0.72, 0.22),   # trabalho: amber
	Color(0.92, 0.18, 0.16),   # sangue: vermelho
	Color(0.55, 0.34, 1.00),   # medo: violeta
]
const THRESHOLD: float = 0.03
const LIFT: float = 0.35


var aether: AetherField = null
var _show: bool = false


func setup(p_aether: AetherField) -> void:
	aether = p_aether
	name = "AetherViz"
	mesh = ArrayMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	material_override = mat
	visible = false


func show_view(v: bool) -> void:
	_show = v
	visible = v
	if visible:
		refresh()


func showing() -> bool:
	return _show


func refresh() -> void:
	if not _show or aether == null:
		return
	var cells: Array = aether.active_cells(THRESHOLD)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for entry in cells:
		var c: Vector3i = entry[0]
		var ch: int = int(entry[1])
		var v: float = float(entry[2])
		var center := aether.cell_center(c) + Vector3(0.0, LIFT, 0.0)
		var size := float(aether.cell)
		var col: Color = CHANNEL_COLOR[ch]
		col.a = clampf(v / 1.1, 0.05, 0.62)
		for k in 6:
			var corner: Vector3 = QUAD_CORNERS[QUAD_INDEX[k]]
			st.set_color(col)
			st.add_vertex(center + Vector3(corner.x * size, 0.0, corner.z * size))
	if cells.is_empty():
		mesh = ArrayMesh.new()
	else:
		mesh = st.commit()
