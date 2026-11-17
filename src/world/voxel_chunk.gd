class_name VoxelChunk
## Storage puro de um chunk. Malharia e queries vivem em VoxelWorld (precisam de vizinhos).

const SIZE_X: int = VoxelConfig.CHUNK_SIZE_X
const SIZE_Y: int = VoxelConfig.CHUNK_SIZE_Y
const SIZE_Z: int = VoxelConfig.CHUNK_SIZE_Z
const VOL: int = SIZE_X * SIZE_Y * SIZE_Z

var coord := Vector2i.ZERO
var data := PackedByteArray()
var dirty: bool = true
var mesh_instance: MeshInstance3D = null


func _init(p_coord := Vector2i.ZERO) -> void:
	coord = p_coord
	data.resize(VOL)
	data.fill(BlockDefs.Block.AIR)


static func local_index(x: int, y: int, z: int) -> int:
	return (y * SIZE_Z + z) * SIZE_X + x


func get_block(x: int, y: int, z: int) -> int:
	return data[local_index(x, y, z)]


func set_block(x: int, y: int, z: int, b: int) -> void:
	data[local_index(x, y, z)] = b


func set_all(b: int) -> void:
	data.fill(b)


func origin_xz() -> Vector2i:
	return Vector2i(coord.x * SIZE_X, coord.y * SIZE_Z)
