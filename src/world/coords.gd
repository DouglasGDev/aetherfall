class_name Coords
## Sistema de coordenadas canônico do slice: UMA fonte de verdade para as
## conversões entre os espacos que o jogo usa. Nenhuma conversao nova deve
## nascer fora daqui — rede, pathfinding e streaming vão depender deste
## vocabulario (docs/design/06).
##
## Convencao:
##   bloco  — celula inteira identificada pelo canto minimo; posicao continua
##            p cai no bloco floor(p), inclusive para negativos;
##   chunk  — 16x64x16 (VoxelConfig), identificado por (cx,cz) = floor(x/16),
##            floor(z/16); a coordenada local guarda X/Z deslocados e Y global;
##   eter   — grade grosseira de AETHER_CELL voxels por lado, mesmo criterio
##            de canto minimo;
##   chave  — bloco serializa como "x,y,z" (diario de edicoes do save).
## Tamanhos e limites do mundo ficam no VoxelConfig; aqui so conversao.

const BLOCK_KEY_FMT := "%d,%d,%d"


## Posicao continua -> bloco que a contem (piso, negativo inclusive).
static func to_block(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x), floori(p.y), floori(p.z))


## Centro do bloco no espaco continuo (mira, spawn de efeitos).
static func block_center(b: Vector3i) -> Vector3:
	return Vector3(b) + Vector3(0.5, 0.5, 0.5)


## Bloco -> chunk que o contem.
static func chunk_of(b: Vector3i) -> Vector2i:
	return Vector2i(
		floori(float(b.x) / VoxelConfig.CHUNK_SIZE_X),
		floori(float(b.z) / VoxelConfig.CHUNK_SIZE_Z))


## Canto minimo do chunk no espaco de blocos (Y sempre 0: altura e global).
static func chunk_origin(key: Vector2i) -> Vector3i:
	return Vector3i(key.x * VoxelConfig.CHUNK_SIZE_X, 0, key.y * VoxelConfig.CHUNK_SIZE_Z)


## Bloco -> coordenada local do chunk (X/Z deslocados, Y global).
static func local_of(b: Vector3i, key: Vector2i) -> Vector3i:
	var o := chunk_origin(key)
	return Vector3i(b.x - o.x, b.y, b.z - o.z)


## Bloco -> chave estavel no save (diario de edicoes).
static func block_key(b: Vector3i) -> String:
	return BLOCK_KEY_FMT % [b.x, b.y, b.z]


## Chave do save -> bloco.
static func parse_block_key(s: String) -> Vector3i:
	var parts := s.split(",")
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))


## Voxel -> celula do Éter (canto minimo, mesmo criterio de piso).
static func cell_of_voxel(v: Vector3i, cell_size: int = VoxelConfig.AETHER_CELL) -> Vector3i:
	return Vector3i(
		floori(float(v.x) / cell_size),
		floori(float(v.y) / cell_size),
		floori(float(v.z) / cell_size))


## Celula do Éter -> canto minimo em voxels.
static func cell_origin(c: Vector3i, cell_size: int = VoxelConfig.AETHER_CELL) -> Vector3i:
	return Vector3i(c.x * cell_size, c.y * cell_size, c.z * cell_size)
