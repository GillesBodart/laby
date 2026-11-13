class_name DirtOverlay
extends RefCounted
## Soft, organic dirt patches. Dirt cells are drawn as grass on the tile layer;
## this overlay paints the dirt on top with rounded, noisy borders (a darker
## worn rim, grass tufts poking in, a faint shadow on the grass) instead of the
## hard square tile edges.

const CHUNK := 8
## Soft mask threshold: dirt where the smoothed cell mask is above it.
const EDGE := 0.5
## Width (in mask units, about one pixel) of the anti-aliased border.
const AA := 0.045
const RIM := Color(0.24, 0.17, 0.09, 0.55)
const SHADE := Color(0.12, 0.22, 0.06, 0.28)
const TUFT := [Color8(74, 140, 44), Color8(98, 168, 58), Color8(56, 112, 36)]
## Earth tones from dark to light; noise picks the band so patches never repeat.
const SOIL := [Color8(104, 74, 46), Color8(118, 86, 54), Color8(130, 96, 60), Color8(142, 108, 68), Color8(156, 122, 78)]
const PEBBLE := [Color8(170, 158, 138), Color8(120, 110, 96)]


## Paints every chunk that holds dirt; returns [{"pos": Vector2 (px), "image": Image}].
static func build(layout: ClearingLayout, tile: int, seed_value: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.09
	noise.fractal_octaves = 2
	var soil := FastNoiseLite.new()
	soil.seed = seed_value + 7
	soil.frequency = 0.035
	soil.fractal_octaves = 3
	for cy in range(0, layout.size.y, CHUNK):
		for cx in range(0, layout.size.x, CHUNK):
			var rect := Rect2i(cx, cy, CHUNK, CHUNK).intersection(Rect2i(Vector2i.ZERO, layout.size))
			var img := _paint_chunk(layout, rect, tile, noise, soil)
			if img != null:
				out.append({"pos": Vector2(rect.position * tile), "image": img})
	return out


## 1 for dirt; non-grass ground (gate floors...) also counts so paths run into
## it squarely instead of rounding off against it.
static func _membership(layout: ClearingLayout, cell: Vector2i) -> float:
	if not layout.in_bounds(cell):
		return 0.0
	match layout.get_ground(cell):
		TileCatalog.Id.DIRT, TileCatalog.Id.GATE_FLOOR, TileCatalog.Id.MAZE_FLOOR, TileCatalog.Id.MAZE_FLOOR_MOSS:
			return 1.0
	return 0.0


static func _paintable(layout: ClearingLayout, cell: Vector2i) -> bool:
	var id := layout.get_ground(cell)
	return id == TileCatalog.Id.DIRT or id == TileCatalog.Id.GRASS \
		or id == TileCatalog.Id.GRASS_ALT or id == TileCatalog.Id.GRASS_FLOWERS


static func _paint_chunk(layout: ClearingLayout, rect: Rect2i, tile: int, noise: FastNoiseLite, soil: FastNoiseLite) -> Image:
	# Only cells next to dirt can change; skip chunks without any.
	var cells: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if not _paintable(layout, c):
				continue
			var near := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n := c + Vector2i(dx, dy)
					if layout.in_bounds(n) and layout.get_ground(n) == TileCatalog.Id.DIRT:
						near = true
			if near:
				cells.append(c)
	if cells.is_empty():
		return null
	var img := Image.create(rect.size.x * tile, rect.size.y * tile, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for c in cells:
		# Membership of the 3x3 neighbourhood, sampled at cell centres.
		var m := PackedFloat32Array()
		m.resize(9)
		for dy in 3:
			for dx in 3:
				m[dy * 3 + dx] = _membership(layout, c + Vector2i(dx - 1, dy - 1))
		var base := (c - rect.position) * tile
		for py in tile:
			for px in tile:
				var gx := c.x * tile + px
				var gy := c.y * tile + py
				var v := _sample(m, (px + 0.5) / float(tile), (py + 0.5) / float(tile))
				v += noise.get_noise_2d(gx, gy) * 0.22
				var col := Color(0, 0, 0, 0)
				# Coverage of the soil and shade bands over AA (one pixel of v) for
				# smooth, unstepped borders.
				var cover := clampf((v - EDGE) / AA + 0.5, 0.0, 1.0)
				var shade := Color(SHADE, SHADE.a * clampf((v - EDGE + 0.08) / AA + 0.5, 0.0, 1.0))
				if cover > 0.0:
					var h := _hash(gx, gy)
					col = _soil(soil, gx, gy, h)
					if v < EDGE + 0.07:
						col = col.blend(RIM)
					elif v < EDGE + 0.13 and h > 0.6:
						col = col.blend(Color(RIM, 0.3))
					# Stray blades of grass near the border.
					if v < EDGE + 0.1 and h > 0.9:
						col = TUFT[int(h * 1000) % 3]
					if cover < 1.0:
						col = shade.lerp(col, cover)
				elif shade.a > 0.0:
					col = shade
				img.set_pixel(base.x + px, base.y + py, col)
	return img


## Earth colour: banded low-frequency noise with a little dither, sparse pebbles
## (lit on top, dark underneath) and dark specks.
static func _soil(soil: FastNoiseLite, x: int, y: int, h: float) -> Color:
	var n := soil.get_noise_2d(x, y) * 0.5 + 0.5 + (h - 0.5) * 0.12
	var col: Color = SOIL[clampi(int(n * SOIL.size()), 0, SOIL.size() - 1)]
	var cell_x := x >> 3
	var cell_y := y >> 3
	var ph := _hash(cell_x * 7 + 3, cell_y * 13 + 5)
	if ph > 0.78:
		var px := (cell_x << 3) + 2 + int(ph * 997) % 4
		var py := (cell_y << 3) + 2 + int(ph * 7919) % 4
		if (x == px or x == px + 1) and y == py:
			return PEBBLE[0]
		if (x == px or x == px + 1) and y == py + 1:
			return PEBBLE[1]
	if h > 0.985:
		return SOIL[0].darkened(0.2)
	return col


## Smooth (smoothstep-weighted bilinear) interpolation of the 3x3 cell-centre mask
## at (u, v) within the middle cell.
static func _sample(m: PackedFloat32Array, u: float, v: float) -> float:
	var sx := 0 if u < 0.5 else 1
	var sy := 0 if v < 0.5 else 1
	var tx := u + 0.5 - sx
	var ty := v + 0.5 - sy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := m[sy * 3 + sx]
	var b := m[sy * 3 + sx + 1]
	var c := m[(sy + 1) * 3 + sx]
	var d := m[(sy + 1) * 3 + sx + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


static func _hash(x: int, y: int) -> float:
	var h: int = x * 374761393 + y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0
