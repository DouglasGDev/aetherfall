class_name VoxelConfig
## Constantes estruturais do mundo voxel. Mudar qualquer tamanho aqui invalida saves
## existentes (o formato de chunk e a chave de region derivam destes valores).

const CHUNK_SIZE_X: int = 16
const CHUNK_SIZE_Y: int = 64
const CHUNK_SIZE_Z: int = 16

# Mundo finito no slice P0: 8x8 chunks = 128 x 128 de area, 64 de altura.
const WORLD_CHUNKS_X: int = 8
const WORLD_CHUNKS_Z: int = 8

const SEA_LEVEL: int = 26

# Eter: grade grosseira acoplada ao voxel (1 celula para cada N voxels).
const AETHER_CELL: int = 4

static func world_size_x() -> int:
	return WORLD_CHUNKS_X * CHUNK_SIZE_X


static func world_size_z() -> int:
	return WORLD_CHUNKS_Z * CHUNK_SIZE_Z


static func in_world_bounds(p: Vector3i) -> bool:
	return (
		p.x >= 0 and p.x < world_size_x()
		and p.z >= 0 and p.z < world_size_z()
		and p.y >= 0 and p.y < CHUNK_SIZE_Y
	)


static func chunk_key(p: Vector3i) -> Vector2i:
	return Vector2i(floori(float(p.x) / CHUNK_SIZE_X), floori(float(p.z) / CHUNK_SIZE_Z))
