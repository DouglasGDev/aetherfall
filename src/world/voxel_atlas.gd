class_name VoxelAtlas
## Atlas de texturas gerado em runtime: sem binarios no repositorio, deterministico,
## e o ponto de partida ate existir pipeline de arte real (docs/design/../art style bible).

const TILE: int = 16
const GRID: int = 8
const ATLAS_SEED: int = 20260116


static func build_texture() -> Texture2D:
	var img := Image.create(GRID * TILE, GRID * TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = ATLAS_SEED

	_grass_top(img, BlockDefs.TILE_GRASS_TOP, rng)
	_grass_side(img, BlockDefs.TILE_GRASS_SIDE, rng)
	_dirt(img, BlockDefs.TILE_DIRT, rng)
	_stone(img, BlockDefs.TILE_STONE, rng)
	_sand(img, BlockDefs.TILE_SAND, rng)
	_snow(img, BlockDefs.TILE_SNOW, rng)
	_wood_side(img, BlockDefs.TILE_WOOD_SIDE, rng)
	_wood_top(img, BlockDefs.TILE_WOOD_TOP, rng)
	_leaves(img, BlockDefs.TILE_LEAVES, rng)
	_water(img, BlockDefs.TILE_WATER, rng)
	_cobble(img, BlockDefs.TILE_COBBLE, rng)
	_plank(img, BlockDefs.TILE_PLANK, rng)
	_glass(img, BlockDefs.TILE_GLASS, rng)
	_bench(img, BlockDefs.TILE_BENCH, rng)

	# O engine nao tem formato sRGB em runtime (4.7): a textura e amostrada como
	# linear, entao os colores escritos acima (valores sRGB de tela) precisam virar
	# lineares aqui. Sem isso o tonemap devolve tudo estourado e sem saturacao --
	# o mundo cinza-claro das primeiras capturas.
	img.srgb_to_linear()
	img.generate_mipmaps(false)
	var tex := ImageTexture.create_from_image(img)
	return tex


static func _px(img: Image, tile: int, x: int, y: int, c: Color) -> void:
	var ox: int = (tile % GRID) * TILE
	var oy: int = int(tile / GRID) * TILE
	img.set_pixel(ox + x, oy + y, c)


static func _noise_fill(img: Image, tile: int, base: Color, jitter: float, rng: RandomNumberGenerator) -> void:
	for y in TILE:
		for x in TILE:
			var d: float = (rng.randf() - 0.5) * 2.0 * jitter
			_px(img, tile, x, y, Color(
				clampf(base.r + d, 0.0, 1.0),
				clampf(base.g + d * 0.9, 0.0, 1.0),
				clampf(base.b + d * 0.8, 0.0, 1.0), 1.0))


static func _grass_top(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	_noise_fill(img, tile, Color(0.34, 0.55, 0.26), 0.055, rng)
	for i in 26:
		var x: int = rng.randi_range(0, TILE - 1)
		var y: int = rng.randi_range(0, TILE - 1)
		var h: int = rng.randi_range(1, 3)
		var light: bool = rng.randf() > 0.45
		for k in h:
			if y + k < TILE:
				var c := Color(0.44, 0.66, 0.30) if light else Color(0.24, 0.42, 0.20)
				_px(img, tile, x, y + k, c)


static func _grass_side(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	_noise_fill(img, tile, Color(0.42, 0.31, 0.20), 0.05, rng)
	var fringe: Array[int] = []
	for x in TILE:
		fringe.append(rng.randi_range(3, 6))
	for y in 7:
		for x in TILE:
			if y < fringe[x]:
				_grass_px(img, tile, x, y, rng)


static func _grass_px(img: Image, tile: int, x: int, y: int, rng: RandomNumberGenerator) -> void:
	var d: float = (rng.randf() - 0.5) * 0.10
	_px(img, tile, x, y, Color(0.33 + d, 0.54 + d, 0.25 + d * 0.5, 1.0))


static func _dirt(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	_noise_fill(img, tile, Color(0.42, 0.31, 0.20), 0.06, rng)
	for i in 9:
		var x: int = rng.randi_range(1, TILE - 3)
		var y: int = rng.randi_range(1, TILE - 3)
		var s: int = rng.randi_range(1, 2)
		for dy in s:
			for dx in s:
				_px(img, tile, x + dx, y + dy, Color(0.30, 0.22, 0.14, 1.0))


static func _stone(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	_noise_fill(img, tile, Color(0.52, 0.53, 0.55), 0.05, rng)
	for c in 2:
		var x: int = rng.randi_range(2, TILE - 3)
		var y: int = rng.randi_range(0, TILE - 1)
		for step in rng.randi_range(4, 8):
			_px(img, tile, x, y, Color(0.36, 0.37, 0.39, 1.0))
			x = clampi(x + rng.randi_range(-1, 1), 0, TILE - 1)
			y = clampi(y + 1, 0, TILE - 1)


static func _sand(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	_noise_fill(img, tile, Color(0.83, 0.76, 0.52), 0.035, rng)
	for i in 20:
		_px(img, tile, rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1),
			Color(0.90, 0.85, 0.62, 1.0))


static func _snow(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	_noise_fill(img, tile, Color(0.92, 0.94, 0.97), 0.025, rng)
	for i in 14:
		_px(img, tile, rng.randi_range(0, TILE - 1), rng.randi_range(0, TILE - 1),
			Color(0.76, 0.83, 0.92, 1.0))


static func _wood_side(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	_noise_fill(img, tile, Color(0.40, 0.28, 0.16), 0.03, rng)
	var x := 1
	while x < TILE:
		var w: int = rng.randi_range(1, 2)
		var dark := rng.randf() > 0.5
		for k in w:
			if x + k < TILE:
				for y in TILE:
					_px(img, tile, x + k, y,
						Color(0.26, 0.17, 0.10, 1.0) if dark else Color(0.48, 0.35, 0.21, 1.0))
		x += w + rng.randi_range(1, 3)
	var kx: int = rng.randi_range(4, 10)
	var ky: int = rng.randi_range(4, 11)
	for dy in 3:
		for dx in 3:
			_px(img, tile, kx + dx - 1, ky + dy - 1, Color(0.30, 0.20, 0.11, 1.0))


static func _wood_top(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	var half := float(TILE) * 0.5
	for y in TILE:
		for x in TILE:
			var d: float = Vector2(float(x) - half, float(y) - half).length()
			var ring: float = fmod(d, 3.0)
			var c := Color(0.55, 0.42, 0.26, 1.0) if ring > 1.5 else Color(0.42, 0.30, 0.18, 1.0)
			c = c.lightened((rng.randf() - 0.5) * 0.06)
			_px(img, tile, x, y, c)


static func _leaves(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	_noise_fill(img, tile, Color(0.20, 0.40, 0.16), 0.06, rng)
	for i in 16:
		var x: int = rng.randi_range(0, TILE - 2)
		var y: int = rng.randi_range(0, TILE - 2)
		for dy in 2:
			for dx in 2:
				_px(img, tile, x + dx, y + dy, Color(0.10, 0.20, 0.09, 1.0))


static func _water(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	for y in TILE:
		var band := 0.0
		if y % 4 == 0:
			band = 0.08
		elif y % 4 == 2:
			band = -0.05
		for x in TILE:
			var d: float = (rng.randf() - 0.5) * 0.04
			_px(img, tile, x, y, Color(0.16 + d, 0.38 + d + band, 0.62 + band, 0.72))


## Pedra bruta: a mesma pedra lavada em lascas soltas. A base escura e a argamassa
## entre os cacos; sem ela o tile vira o tile de pedra e o jogador nao distingue
## o material que da trabalho do que ja esta pronto.
static func _cobble(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	_noise_fill(img, tile, Color(0.33, 0.33, 0.36), 0.04, rng)
	for i in 11:
		var cx: int = rng.randi_range(1, TILE - 2)
		var cy: int = rng.randi_range(1, TILE - 2)
		var r: int = rng.randi_range(1, 3)
		var tone: float = 0.50 + rng.randf() * 0.14
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy > r * r:
					continue
				var x: int = clampi(cx + dx, 0, TILE - 1)
				var y: int = clampi(cy + dy, 0, TILE - 1)
				var d: float = (rng.randf() - 0.5) * 0.07
				_px(img, tile, x, y, Color(tone + d, tone + d * 0.95, tone + 0.02 + d, 1.0))


## Tabua: sarrafiado horizontal com a emenda de cada fila deslocada, como a
## madeira cortada em prancha (a lateral do tronco e o tile de madeira).
static func _plank(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	_noise_fill(img, tile, Color(0.58, 0.44, 0.26), 0.035, rng)
	for row in 4:
		var y0: int = row * 4
		for x in TILE:
			_px(img, tile, x, clampi(y0 + 3, 0, TILE - 1), Color(0.36, 0.25, 0.13, 1.0))
		var seam: int = (row * 5 + 3) % TILE
		for y in 3:
			_px(img, tile, seam, clampi(y0 + y, 0, TILE - 1), Color(0.40, 0.28, 0.15, 1.0))
		var grain: int = rng.randi_range(0, TILE - 4)
		for x in 4:
			_px(img, tile, clampi(grain + x, 0, TILE - 1), clampi(y0 + rng.randi_range(0, 2), 0, TILE - 1),
				Color(0.50, 0.37, 0.20, 1.0))


## Vidro: quase nada de cor e um fio de borda. O alpha do pixel e o que faz a
## face ser desenhada pelo material ALPHA; sem o quadro ela desapareceria no
## mundo e o jogador construiria paredes invisiveis.
static func _glass(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	for y in TILE:
		for x in TILE:
			var edge: bool = x == 0 or y == 0 or x == TILE - 1 or y == TILE - 1
			var inner: bool = x <= 1 or y <= 1 or x >= TILE - 2 or y >= TILE - 2
			var a: float = 0.85 if edge else (0.30 if inner else 0.10)
			var c := Color(0.80, 0.90, 0.95, a) if not edge else Color(0.88, 0.95, 0.98, a)
			_px(img, tile, x, y, c)
	for i in 3:
		var o: int = rng.randi_range(2, 9)
		for k in 6:
			var x: int = clampi(o + k, 0, TILE - 2)
			var y: int = clampi(k + 1, 0, TILE - 2)
			_px(img, tile, x, y, Color(0.94, 0.98, 1.0, 0.42))


## Bancada: tampo de tabua com a marca de trabalho (esquadro e morso) desenhada
## em escuro. E o unico tile lido de cima, e precisa dizer "superficie" a 5 m.
static func _bench(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	_plank(img, tile, rng)
	for x in TILE:
		_px(img, tile, x, 0, Color(0.30, 0.20, 0.11, 1.0))
		_px(img, tile, x, TILE - 1, Color(0.30, 0.20, 0.11, 1.0))
	for y in TILE:
		_px(img, tile, 0, y, Color(0.30, 0.20, 0.11, 1.0))
		_px(img, tile, TILE - 1, y, Color(0.30, 0.20, 0.11, 1.0))
	# esquadro
	for k in 9:
		_px(img, tile, 3 + k, 4, Color(0.24, 0.16, 0.09, 1.0))
	for k in 5:
		_px(img, tile, 3, 4 + k, Color(0.24, 0.16, 0.09, 1.0))
	# morso na borda
	for dy in 4:
		for dx in 3:
			_px(img, tile, 10 + dx, 9 + dy, Color(0.42, 0.30, 0.16, 1.0))
	for dx in 3:
		_px(img, tile, 10 + dx, 8, Color(0.20, 0.13, 0.07, 1.0))
