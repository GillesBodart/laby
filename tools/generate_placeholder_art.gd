extends SceneTree
## Generates the game's pixel art procedurally (32px tiles, detailed shading).
## Every PNG follows the final layout (sizes, atlas coords, frame grids),
## so hand-painted art can replace them later without touching gameplay code.
##
## Run from the project root, then refresh the import cache:
##   godot --headless --path . --script res://tools/generate_placeholder_art.gd
##   godot --headless --path . --editor --quit

const Catalog := preload("res://scripts/world/tile_catalog.gd")
const T := 32
const VARIANTS := 10

const C := {
	"outline": Color8(24, 22, 32),
	"void": Color8(14, 16, 22),
	"grass": Color8(84, 146, 60),
	"grass_dark": Color8(70, 130, 54),
	"grass_deep": Color8(44, 90, 42),
	"grass_light": Color8(98, 160, 68),
	"flower_y": Color8(244, 212, 92),
	"flower_w": Color8(240, 236, 220),
	"flower_r": Color8(214, 84, 76),
	"dirt": Color8(140, 108, 70),
	"dirt_dark": Color8(124, 94, 62),
	"dirt_deep": Color8(84, 62, 42),
	"dirt_light": Color8(154, 120, 80),
	"stone": Color8(70, 80, 78),
	"stone_dark": Color8(44, 51, 52),
	"stone_light": Color8(90, 102, 98),
	"wall_top": Color8(130, 144, 134),
	"wall_top_light": Color8(170, 182, 168),
	"wall_top_dark": Color8(98, 112, 104),
	"wall_face": Color8(74, 88, 83),
	"wall_face_dark": Color8(46, 56, 54),
	"wall_face_light": Color8(102, 116, 109),
	"wall_base": Color8(30, 38, 38),
	"moss": Color8(79, 122, 58),
	"moss_dark": Color8(52, 90, 46),
	"moss_light": Color8(116, 160, 76),
	"vine": Color8(50, 98, 46),
	"vine_light": Color8(96, 148, 62),
	"wood": Color8(120, 82, 50),
	"wood_dark": Color8(80, 54, 38),
	"wood_deep": Color8(56, 38, 30),
	"wood_light": Color8(160, 114, 68),
	"wood_hi": Color8(194, 150, 92),
	"iron": Color8(96, 100, 108),
	"iron_dark": Color8(60, 63, 72),
	"iron_light": Color8(150, 156, 164),
	"gold": Color8(226, 184, 72),
	"leaf_deep": Color8(30, 70, 40),
	"leaf_dark": Color8(40, 90, 46),
	"leaf": Color8(62, 122, 54),
	"leaf_light": Color8(100, 162, 68),
	"leaf_hi": Color8(150, 198, 96),
	"bark": Color8(100, 68, 44),
	"bark_dark": Color8(66, 44, 32),
	"bark_light": Color8(134, 96, 62),
	"rock_deep": Color8(58, 62, 66),
	"rock_dark": Color8(88, 92, 94),
	"rock": Color8(128, 132, 130),
	"rock_light": Color8(168, 170, 164),
	"rock_hi": Color8(204, 204, 192),
	"fire_core": Color8(255, 240, 160),
	"fire_mid": Color8(246, 168, 60),
	"fire_out": Color8(210, 76, 44),
	"fire_deep": Color8(140, 40, 36),
	"sun": Color8(255, 214, 92),
	"moon": Color8(214, 222, 240),
	"skin": Color8(240, 194, 156),
	"skin_dark": Color8(206, 146, 112),
	"skin_deep": Color8(168, 112, 88),
	"hair": Color8(112, 66, 40),
	"hair_dark": Color8(76, 42, 28),
	"hair_light": Color8(150, 96, 58),
	"tunic": Color8(82, 128, 66),
	"tunic_dark": Color8(54, 88, 48),
	"tunic_light": Color8(118, 164, 88),
	"cloth": Color8(190, 168, 120),
	"pants": Color8(112, 92, 66),
	"pants_dark": Color8(78, 62, 46),
	"boot": Color8(66, 46, 36),
	"boot_dark": Color8(42, 30, 26),
	"pack": Color8(140, 98, 58),
	"pack_dark": Color8(96, 64, 40),
}

var rng := RandomNumberGenerator.new()


func _init() -> void:
	for dir in ["res://assets/tilesets", "res://assets/sprites", "res://assets/sprites/trees", "res://assets/sprites/rocks", "res://assets/sprites/structures", "res://assets/ui", "res://assets/ui/items"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save(_make_tileset(), Catalog.TEXTURE_PATH)
	_save(_make_player(), "res://assets/sprites/player.png")
	for v in VARIANTS:
		_save(_make_tree(v), "res://assets/sprites/trees/tree_%d.png" % v)
		_save(_make_rock(v), "res://assets/sprites/rocks/rock_%d.png" % v)
	_save(_make_tree(0), "res://assets/sprites/tree.png")
	_save(_make_rock(0), "res://assets/sprites/rock.png")
	_save(_make_campfire(), "res://assets/sprites/campfire.png")
	for s in ["workbench", "chest", "wooden_wall", "wooden_floor", "wooden_door_closed", "wooden_door_open"]:
		_save(_make_structure(s), "res://assets/sprites/structures/%s.png" % s)
	_save(_make_shadow(), "res://assets/sprites/shadow.png")
	_save(_make_time_icons(), "res://assets/ui/time_icons.png")
	_make_item_icons()
	print("Art generated.")
	quit()


func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save %s (%d)" % [path, err])


func _new_image(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


# ---------------------------------------------------------------- helpers

func _hash(x: int, y: int, s: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + s * 2147483647
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


## Tileable value noise (cell size cs must divide T).
func _tnoise(x: float, y: float, cs: float, s: int) -> float:
	var n := int(T / cs)
	var fx := x / cs
	var fy := y / cs
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - x0
	var ty := fy - y0
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _hash(posmod(x0, n), posmod(y0, n), s)
	var b := _hash(posmod(x0 + 1, n), posmod(y0, n), s)
	var c := _hash(posmod(x0, n), posmod(y0 + 1, n), s)
	var d := _hash(posmod(x0 + 1, n), posmod(y0 + 1, n), s)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## Non-tileable value noise for sprites.
func _snoise(x: float, y: float, cs: float, s: int) -> float:
	var fx := x / cs
	var fy := y / cs
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - x0
	var ty := fy - y0
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	return lerpf(lerpf(_hash(x0, y0, s), _hash(x0 + 1, y0, s), tx), lerpf(_hash(x0, y0 + 1, s), _hash(x0 + 1, y0 + 1, s), tx), ty)


func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)


func _wpx(img: Image, x: int, y: int, col: Color) -> void:
	img.set_pixel(posmod(x, img.get_width()), posmod(y, img.get_height()), col)


func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, col)


## Bevelled box: light top/left edge, dark bottom/right edge, noisy fill.
func _box(img: Image, x: int, y: int, w: int, h: int, base: Color, grain := 0.0, seed := 0) -> void:
	for yy in h:
		for xx in w:
			var col := base
			if grain > 0.0:
				col = base.lightened((_hash(x + xx, y + yy, seed) - 0.5) * grain)
			if yy == 0 or xx == 0:
				col = base.lightened(0.28)
			elif yy == h - 1 or xx == w - 1:
				col = base.darkened(0.32)
			elif yy == h - 2:
				col = base.darkened(0.14)
			_px(img, x + xx, y + yy, col)


## Cel-shaded filled ellipse; tones ordered dark -> light.
func _blob(img: Image, cx: float, cy: float, rx: float, ry: float, tones: Array, jitter := 0.12, seed := 0, clip_y := 9999.0) -> void:
	var light := Vector3(-0.5, -0.7, 0.55).normalized()
	for y in range(int(floor(cy - ry)) - 1, int(ceil(cy + ry)) + 2):
		if y >= clip_y:
			continue
		for x in range(int(floor(cx - rx)) - 1, int(ceil(cx + rx)) + 2):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			var d := nx * nx + ny * ny
			if d > 1.0:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - d))
			var lit := Vector3(nx, ny, nz).dot(light)
			lit += (_hash(x, y, seed) - 0.5) * jitter
			var t := clampf((lit + 0.45) / 1.35, 0.0, 0.999)
			_px(img, x, y, tones[int(t * tones.size())])


func _outline(img: Image, color: Color) -> void:
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < img.get_width() and n.y < img.get_height():
					if src.get_pixel(n.x, n.y).a > 0.0 and src.get_pixel(n.x, n.y) != color:
						img.set_pixel(x, y, color)
						break


func _line(img: Image, a: Vector2, b: Vector2, col: Color, width := 1) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / maxf(steps, 1))
		_rect(img, int(round(p.x)) - width / 2, int(round(p.y)) - width / 2, width, width, col)


## Thick line shaded like a cylinder (light on the upper-left side).
func _tube(img: Image, a: Vector2, b: Vector2, width: int, tones: Array) -> void:
	var dir := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var steps := int(a.distance_to(b)) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / maxf(steps, 1))
		for w in range(-width, width + 1):
			var q := p + perp * (w * 0.5)
			var side := float(w) / maxf(width, 1)
			var lit := -perp.dot(Vector2(-0.6, -0.8)) * side * -1.0
			var idx := clampi(int((lit + 1.0) * 0.5 * tones.size()), 0, tones.size() - 1)
			_px(img, int(round(q.x)), int(round(q.y)), tones[idx])


func _tint(color: Color, t: float) -> Color:
	return color.lightened(t) if t >= 0.0 else color.darkened(-t)


# ---------------------------------------------------------------- tiles

func _make_tileset() -> Image:
	var img := _new_image(Catalog.ATLAS_COLUMNS * T, Catalog.ATLAS_ROWS * T)
	var painters := {
		Catalog.Id.GRASS: _paint_grass.bind(0),
		Catalog.Id.GRASS_ALT: _paint_grass.bind(1),
		Catalog.Id.GRASS_FLOWERS: _paint_grass.bind(2),
		Catalog.Id.DIRT: _paint_dirt,
		Catalog.Id.MAZE_FLOOR: _paint_floor.bind(false),
		Catalog.Id.MAZE_FLOOR_MOSS: _paint_floor.bind(true),
		Catalog.Id.VOID: _paint_void,
		Catalog.Id.GATE_FLOOR: _paint_gate_floor,
		Catalog.Id.WALL_TOP: _paint_wall_top.bind(false),
		Catalog.Id.WALL_TOP_MOSS: _paint_wall_top.bind(true),
		Catalog.Id.WALL_FACE_HIGH: _paint_wall_face.bind(false, false),
		Catalog.Id.WALL_FACE_HIGH_VINES: _paint_wall_face.bind(false, true),
		Catalog.Id.WALL_FACE_LOW: _paint_wall_face.bind(true, false),
		Catalog.Id.WALL_FACE_LOW_VINES: _paint_wall_face.bind(true, true),
		Catalog.Id.GATE_CLOSED: _paint_gate_closed,
	}
	for id in painters:
		var origin: Vector2i = Catalog.atlas_coords(id) * T
		var tile := _new_image(T, T)
		rng.seed = 1000 + id
		painters[id].call(tile)
		img.blit_rect(tile, Rect2i(0, 0, T, T), origin)
	return img


func _paint_grass(img: Image, variant: int) -> void:
	var bias := -0.07 if variant == 1 else 0.0
	for y in T:
		for x in T:
			var n := _tnoise(x, y, 16, 11) * 0.6 + _tnoise(x, y, 8, 12) * 0.35 + _hash(x, y, 13) * 0.05 + bias
			var col: Color = C.grass
			if n < 0.2:
				col = C.grass_deep
			elif n < 0.36:
				col = C.grass_dark
			elif n > 0.74:
				col = C.grass_light
			img.set_pixel(x, y, col)
	# Grass blades: a bright tip over a dark root.
	for i in 7:
		var x := rng.randi_range(0, T - 1)
		var y := rng.randi_range(2, T - 1)
		_wpx(img, x, y, C.grass_dark)
		_wpx(img, x, y - 1, C.grass_light)
	if variant == 2:
		for i in 6:
			var x := rng.randi_range(3, T - 4)
			var y := rng.randi_range(4, T - 4)
			var petal: Color = [C.flower_y, C.flower_w, C.flower_r][i % 3]
			_wpx(img, x, y + 1, C.grass_deep)
			_wpx(img, x, y + 2, C.grass_deep)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				_wpx(img, x + d.x, y + d.y, petal)
			_wpx(img, x, y, C.flower_y if i % 3 != 0 else C.dirt_dark)


func _paint_dirt(img: Image) -> void:
	for y in T:
		for x in T:
			var n := _tnoise(x, y, 16, 21) * 0.65 + _tnoise(x, y, 8, 22) * 0.3 + _hash(x, y, 23) * 0.05
			var col: Color = C.dirt
			if n < 0.36:
				col = C.dirt_dark
			elif n < 0.28:
				col = C.dirt_deep
			elif n > 0.72:
				col = C.dirt_light
			img.set_pixel(x, y, col)
	for i in 2:
		var px := rng.randi_range(2, T - 4)
		var py := rng.randi_range(2, T - 4)
		_wpx(img, px, py + 1, C.dirt_deep)
		_wpx(img, px + 1, py + 1, C.dirt_deep)
		_wpx(img, px, py, C.rock_light)
		_wpx(img, px + 1, py, C.rock)
	for i in 0:
		var cx := rng.randi_range(0, T - 1)
		var cy := rng.randi_range(0, T - 1)
		for j in 5:
			_wpx(img, cx + j, cy + (j % 2), C.dirt_deep)


## Irregular flagstones laid in two staggered rows.
func _paint_floor(img: Image, moss: bool) -> void:
	var rows := [[0, 18], [9, 25]]
	for y in T:
		var r := y / 16
		var ry := y % 16
		var bounds: Array = rows[r]
		for x in T:
			var s0: int = bounds[0]
			var s1: int = bounds[1]
			var start: int
			var width: int
			if posmod(x - s0, T) < posmod(s1 - s0, T):
				start = s0
				width = posmod(s1 - s0, T)
			else:
				start = s1
				width = posmod(s0 - s1, T)
			var rx := posmod(x - start, T)
			var slab := _hash(start, r, 31)
			var n := _tnoise(x, y, 8, 32) * 0.5 + _hash(x, y, 33) * 0.3 + slab * 0.2
			var col: Color = C.stone
			if n < 0.36:
				col = C.stone_dark.lightened(0.12)
			elif n > 0.7:
				col = C.stone_light
			if ry == 15 or rx == width - 1:
				col = C.stone_dark
			elif ry == 0 or rx == 0:
				col = C.stone_light.lightened(0.12)
			elif ry == 14 or rx == width - 2:
				col = col.darkened(0.15)
			img.set_pixel(x, y, col)
	# Hairline cracks.
	for i in 2:
		var x := rng.randi_range(4, T - 8)
		var y := rng.randi_range(2, T - 4)
		for j in rng.randi_range(4, 8):
			_wpx(img, x + j, y + (j / 2) % 3, C.stone_dark)
	if moss:
		for i in 5:
			var cx := rng.randi_range(0, T - 1)
			var cy := rng.randi_range(0, T - 1)
			for j in 16:
				var x := cx + rng.randi_range(-4, 4)
				var y := cy + rng.randi_range(-2, 2)
				var col: Color = C.moss_dark if j < 8 else C.moss
				_wpx(img, x, y, col)
				if j % 4 == 0:
					_wpx(img, x, y - 1, C.moss_light)


func _paint_void(img: Image) -> void:
	for y in T:
		for x in T:
			var n := _tnoise(x, y, 8, 41)
			img.set_pixel(x, y, C.void.lightened(0.04) if n > 0.62 else C.void)


func _paint_gate_floor(img: Image) -> void:
	_paint_floor(img, false)
	_rect(img, 3, 11, T - 6, 10, C.wall_base)
	for x in range(3, T - 3):
		_px(img, x, 11, C.iron_light)
		_px(img, x, 12, C.iron)
		_px(img, x, 20, C.iron_dark)
	for x in range(5, T - 5, 4):
		_rect(img, x, 14, 2, 4, C.iron_dark)
		_px(img, x, 14, C.iron)
	for p in [Vector2i(4, 13), Vector2i(T - 6, 13), Vector2i(4, 18), Vector2i(T - 6, 18)]:
		_px(img, p.x, p.y, C.iron_light)


## Large cap stones seen from above.
func _paint_wall_top(img: Image, moss: bool) -> void:
	for r in 2:
		var shift := 0 if r == 0 else 8
		for b in 2:
			var bx := posmod(b * 16 + shift, T)
			var tone := _hash(bx, r, 51) - 0.5
			for yy in 16:
				for xx in 16:
					var x := posmod(bx + xx, T)
					var y := r * 16 + yy
					var n := _tnoise(x, y, 8, 52) * 0.55 + _hash(x, y, 53) * 0.45
					var col: Color = C.wall_top.lightened(tone * 0.14)
					if n < 0.32:
						col = col.darkened(0.14)
					elif n > 0.72:
						col = col.lightened(0.1)
					if yy == 15 or xx == 15:
						col = C.wall_top_dark.darkened(0.12)
					elif yy == 0 or xx == 0:
						col = C.wall_top_light
					elif yy == 14 or xx == 14:
						col = col.darkened(0.12)
					img.set_pixel(x, y, col)
	if moss:
		for i in 6:
			var cx := rng.randi_range(0, T - 1)
			var cy := rng.randi_range(0, T - 1)
			for j in 18:
				var x := cx + rng.randi_range(-4, 4)
				var y := cy + rng.randi_range(-2, 2)
				_wpx(img, x, y, C.moss_dark if j < 6 else (C.moss if j < 14 else C.moss_light))


## Front of a wall: staggered bricks, darker toward the ground.
func _paint_wall_face(img: Image, low: bool, vines: bool) -> void:
	for r in 4:
		var shift := 0 if r % 2 == 0 else 8
		for b in 2:
			var bx := posmod(b * 16 + shift, T)
			var tone := _hash(bx, r, 61) - 0.5
			for yy in 8:
				for xx in 16:
					var x := posmod(bx + xx, T)
					var y := r * 8 + yy
					var n := _tnoise(x, y, 4, 62) * 0.5 + _hash(x, y, 63) * 0.5
					var col: Color = C.wall_face.lightened(tone * 0.14)
					if n < 0.34:
						col = col.darkened(0.14)
					elif n > 0.74:
						col = col.lightened(0.08)
					if yy == 7 or xx == 15:
						col = C.wall_face_dark
					elif yy == 0 or xx == 0:
						col = C.wall_face_light
					col = col.darkened(float(y) / T * 0.22)
					img.set_pixel(x, y, col)
	if low:
		for x in T:
			for y in range(T - 5, T):
				var shade: float = 0.25 + (y - (T - 5)) * 0.12
				img.set_pixel(x, y, img.get_pixel(x, y).darkened(shade))
	if vines:
		for vx in [4, 13, 24]:
			var length := rng.randi_range(14, 30)
			for y in length:
				var x: int = vx + int(round(sin(y * 0.5 + vx) * 1.2))
				_wpx(img, x, y, C.vine)
				_wpx(img, x + 1, y, C.moss_dark)
				if y % 5 == 2:
					_wpx(img, x - 2, y, C.vine_light)
					_wpx(img, x - 1, y, C.vine_light)
					_wpx(img, x - 2, y + 1, C.vine)
				elif y % 5 == 4:
					_wpx(img, x + 2, y, C.vine_light)
					_wpx(img, x + 3, y, C.vine_light)
					_wpx(img, x + 3, y + 1, C.vine)


func _paint_gate_closed(img: Image) -> void:
	for p in 4:
		var x0 := p * 8
		var tone := (_hash(p, 1, 71) - 0.5) * 0.12
		for yy in T:
			for xx in 8:
				var n := _hash(x0 + xx, yy / 3, 72)
				var col: Color = C.wood.lightened(tone)
				if xx == 0:
					col = C.wood_deep
				elif xx == 1:
					col = C.wood_light
				elif xx == 7:
					col = C.wood_dark
				elif n > 0.78:
					col = C.wood_dark
				elif n < 0.18:
					col = C.wood_light
				img.set_pixel(x0 + xx, yy, col)
	for band in [5, 21]:
		for x in T:
			_px(img, x, band, C.iron_light)
			_px(img, x, band + 1, C.iron)
			_px(img, x, band + 2, C.iron)
			_px(img, x, band + 3, C.iron_dark)
		for x in [2, 10, 18, 26]:
			_px(img, x, band + 1, C.iron_light)
			_px(img, x + 1, band + 2, C.iron_dark)
	for x in T:
		_px(img, x, T - 1, C.wall_base)
		_px(img, x, 0, C.wood_light)


# ---------------------------------------------------------------- player

## dir: 0 down, 1 up, 2 side (right). step: 0 idle, 1/2 walking.
func _make_player() -> Image:
	var img := _new_image(T * 3, T * 3)
	for row in 3:
		for col in 3:
			var frame := _new_image(T, T)
			_draw_player(frame, row, col)
			_outline(frame, C.outline)
			img.blit_rect(frame, Rect2i(0, 0, T, T), Vector2i(col * T, row * T))
	return img


func _draw_player(f: Image, dir: int, step: int) -> void:
	var bob := 1 if step != 0 else 0
	var swing := 0
	if step == 1:
		swing = 2
	elif step == 2:
		swing = -2
	var cx := 16
	var side := dir == 2

	# Backpack behind the body (seen from the back and the side).
	if dir == 1:
		_box(f, 10, 13 + bob, 12, 11, C.pack, 0.1, 81)
		_rect(f, 10, 17 + bob, 12, 1, C.pack_dark)
		_box(f, 12, 22 + bob, 8, 3, C.pack_dark)
	elif side:
		_box(f, 6, 14 + bob, 6, 10, C.pack, 0.1, 81)
		_rect(f, 6, 18 + bob, 6, 1, C.pack_dark)

	# Legs.
	var leg_y := 23
	if side:
		_leg(f, 13 + swing, leg_y, bob)
		_leg(f, 16 - swing, leg_y, bob)
	else:
		_leg(f, 11, leg_y + (1 if swing > 0 else 0), bob)
		_leg(f, 17, leg_y + (1 if swing < 0 else 0), bob)

	# Torso.
	var tw := 10 if side else 14
	var tx := cx - tw / 2
	_box(f, tx, 13 + bob, tw, 11, C.tunic, 0.12, 82)
	_rect(f, tx + 1, 20 + bob, tw - 2, 2, C.pants_dark)
	_rect(f, tx + 1, 20 + bob, tw - 2, 1, C.pants)
	if not side:
		_rect(f, cx - 1, 20 + bob, 3, 2, C.gold)
		if dir == 0:
			_rect(f, cx - 2, 13 + bob, 4, 2, C.cloth)
			_px(f, cx, 15 + bob, C.cloth)
	_rect(f, tx + 2, 14 + bob, 2, 3, C.tunic_light)

	# Arms.
	if side:
		_arm(f, cx - 2, 14 + bob, swing)
	else:
		_arm(f, tx - 3, 14 + bob, -swing)
		_arm(f, tx + tw, 14 + bob, swing)

	# Head.
	var hy := 8 + bob
	_blob(f, cx, hy, 7.0, 7.0, [C.skin_deep, C.skin_dark, C.skin, C.skin], 0.0, 83)
	if dir == 0:
		_rect(f, cx - 4, hy + 1, 3, 3, C.outline)
		_rect(f, cx + 2, hy + 1, 3, 3, C.outline)
		_px(f, cx - 4, hy + 1, Color.WHITE)
		_px(f, cx + 2, hy + 1, Color.WHITE)
		_rect(f, cx - 1, hy + 4, 3, 1, C.skin_deep)
		_rect(f, cx - 6, hy + 3, 2, 1, C.flower_r.lightened(0.2))
		_rect(f, cx + 5, hy + 3, 2, 1, C.flower_r.lightened(0.2))
		_hair_cap(f, cx, hy, 0)
	elif dir == 1:
		_blob(f, cx, hy, 7.0, 7.0, [C.hair_dark, C.hair, C.hair, C.hair_light], 0.18, 84)
		_rect(f, cx - 6, hy + 4, 12, 2, C.hair_dark)
	else:
		_rect(f, cx + 2, hy + 1, 3, 3, C.outline)
		_px(f, cx + 2, hy + 1, Color.WHITE)
		_px(f, cx + 6, hy + 3, C.skin_dark)
		_rect(f, cx + 1, hy + 5, 3, 1, C.skin_deep)
		_hair_cap(f, cx - 1, hy, 1)


func _hair_cap(f: Image, cx: int, hy: int, mode: int) -> void:
	var tones := [C.hair_dark, C.hair, C.hair, C.hair_light]
	var light := Vector3(-0.5, -0.7, 0.55).normalized()
	for y in range(hy - 8, hy + 1):
		for x in range(cx - 8, cx + 9):
			var nx := (x + 0.5 - cx) / 7.2
			var ny := (y + 0.5 - hy) / 7.2
			var d := nx * nx + ny * ny
			if d > 1.0:
				continue
			var fringe := hy - 2 + int(round(sin(x * 0.9) * 1.2))
			var in_hair := y <= fringe or (mode == 1 and x < cx - 2 and y <= hy + 4) or absf(nx) > 0.86 and y <= hy + 3
			if not in_hair:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - d))
			var lit := Vector3(nx, ny, nz).dot(light) + (_hash(x, y, 85) - 0.5) * 0.2
			f.set_pixel(x, y, tones[clampi(int((lit + 0.45) / 1.35 * 4), 0, 3)])


func _leg(f: Image, x: int, y: int, bob: int) -> void:
	_box(f, x, y, 4, 5, C.pants, 0.08, 86)
	_box(f, x - 1, y + 5, 6, 3, C.boot, 0.06, 87)
	_rect(f, x - 1, y + 7, 6, 1, C.boot_dark)


func _arm(f: Image, x: int, y: int, swing: int) -> void:
	_box(f, x, y + swing / 2, 3, 6, C.tunic, 0.1, 88)
	_rect(f, x, y + 5 + swing / 2, 3, 3, C.skin)
	_px(f, x, y + 5 + swing / 2, C.skin_dark.lightened(0.2))
	_rect(f, x, y + 7 + swing / 2, 3, 1, C.skin_dark)


# ---------------------------------------------------------------- trees

const TREE_TINT := [0.0, 0.05, -0.06, 0.08, 0.0, -0.08, 0.1, -0.03, 0.04, 0.0]
const TREE_FRUIT := {3: Color8(210, 70, 48), 8: Color8(210, 70, 48), 5: Color8(246, 214, 96)}


func _make_tree(v: int) -> Image:
	var img := _new_image(64, 80)
	rng.seed = 5000 + v * 17
	var tint: float = TREE_TINT[v]
	var tones: Array = []
	for k in ["leaf_deep", "leaf_dark", "leaf", "leaf_light", "leaf_hi"]:
		tones.append(_tint(C[k], tint))
	var trunk_w := 8 + (v * 3) % 5
	var trunk_x := 32 - trunk_w / 2
	var base_y := 76

	# Trunk with root flare.
	for y in range(40, base_y):
		var flare := 0
		if y > base_y - 9:
			flare = (y - (base_y - 9)) / 2 + 1
		var x0 := trunk_x - flare
		var x1 := trunk_x + trunk_w + flare
		for x in range(x0, x1):
			var u := float(x - x0) / float(x1 - x0 - 1)
			var n := _snoise(x * 1.0, y * 0.35, 3.0, 91)
			var col: Color = C.bark
			if u < 0.28:
				col = C.bark_light
			elif u > 0.72:
				col = C.bark_dark
			elif n > 0.72:
				col = C.bark_dark
			elif n < 0.25:
				col = C.bark_light
			if u > 0.9:
				col = C.bark_dark.darkened(0.2)
			img.set_pixel(x, y, col)
	# Knot and bark scars.
	_rect(img, trunk_x + 2, 58, 2, 3, C.bark_dark)
	_px(img, trunk_x + 2, 58, C.bark_light)

	# Canopy lobes: back (high) first so front lobes overlap them.
	var lobes: Array = []
	var count := 7 + (v % 3)
	var cr := 21.0 + (v % 4) * 1.5
	lobes.append(Vector3(32, 30, cr * 0.78))
	for i in count:
		var a := TAU * float(i) / count + rng.randf() * 0.4
		var rr := cr * rng.randf_range(0.5, 0.64)
		lobes.append(Vector3(32 + cos(a) * cr * 0.58, 30 + sin(a) * cr * 0.46, rr))
	lobes.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.y < q.y)
	for lobe in lobes:
		_blob(img, lobe.x, lobe.y, lobe.z, lobe.z * 0.9, tones, 0.34, 100 + v)
	# Depth: lower foliage is darker; a few bright leaf flecks catch the light.
	for y in 80:
		for x in 64:
			var col := img.get_pixel(x, y)
			var idx := tones.find(col)
			if idx < 0 or y > 56:
				continue
			var shift := clampi(int((y - 16) / 12.0), 0, 2)
			if _hash(x, y, 111 + v) < 0.55:
				shift += 1
			if idx - shift >= 0 and y > 22:
				img.set_pixel(x, y, tones[idx - shift])
			elif idx < 4 and _hash(x, y, 113 + v) > 0.93:
				img.set_pixel(x, y, tones[idx + 1])
				_px(img, x + 1, y, tones[idx + 1])
	# Fruit / blossoms.
	if TREE_FRUIT.has(v):
		for i in 7:
			var fx := rng.randi_range(14, 50)
			var fy := rng.randi_range(14, 44)
			if img.get_pixel(fx, fy).a > 0.0:
				_rect(img, fx, fy, 2, 2, TREE_FRUIT[v])
				_px(img, fx, fy, Color.WHITE.darkened(0.1))
	# Shade cast by the canopy on the upper trunk.
	for y in range(40, 58):
		for x in range(trunk_x - 1, trunk_x + trunk_w + 1):
			var col := img.get_pixel(x, y)
			if col.a > 0.0 and col in [C.bark, C.bark_light, C.bark_dark]:
				img.set_pixel(x, y, col.darkened(0.3 - (y - 40) * 0.012))
	_outline(img, C.outline)
	return img


# ---------------------------------------------------------------- rocks

const ROCK_P := [2.6, 3.0, 2.2, 2.8, 3.2, 2.4, 2.6, 2.1, 2.9, 3.4]
const ROCK_W := [13.0, 11.0, 14.0, 9.0, 12.0, 14.0, 8.0, 12.5, 10.0, 13.0]
const ROCK_H := [11.0, 9.0, 9.0, 11.0, 10.0, 10.0, 7.0, 12.0, 8.0, 11.0]
const ROCK_MOSS := [1, 0, 0, 1, 0, 0, 1, 0, 0, 1]
const ROCK_TINT := [0.0, 0.04, -0.05, 0.02, 0.07, -0.03, 0.0, 0.05, -0.07, 0.03]


func _make_rock(v: int, icon := false) -> Image:
	var img := _new_image(T, T)
	rng.seed = 7000 + v * 31
	var w: float = ROCK_W[v] * (1.1 if icon else 1.0)
	var h: float = ROCK_H[v] * (1.1 if icon else 1.0)
	var p: float = ROCK_P[v]
	var cx := 16.0
	var base := 28.0 if not icon else 24.0
	var cy := base - h * 0.55
	var tint: float = ROCK_TINT[v]
	var tones: Array = []
	for k in ["rock_deep", "rock_dark", "rock", "rock_light", "rock_hi"]:
		tones.append(_tint(C[k], tint))
	var light := Vector3(-0.5, -0.75, 0.5).normalized()
	var phase1 := rng.randf() * TAU
	var phase2 := rng.randf() * TAU
	for y in T:
		for x in T:
			var dx := (x + 0.5 - cx) / w
			var dy := (y + 0.5 - cy) / h
			var ang := atan2(dy, dx)
			var lump := 1.0 + 0.09 * sin(ang * 3.0 + phase1) + 0.06 * sin(ang * 5.0 + phase2)
			var m := pow(absf(dx), p) + pow(absf(dy), p)
			if m > pow(lump, p) or y > base:
				continue
			var nx := dx / lump
			var ny := dy / lump
			var d := minf(pow(absf(nx), p) + pow(absf(ny), p), 1.0)
			var nz := pow(maxf(0.0, 1.0 - d), 1.0 / p)
			var lit := Vector3(nx * 0.9, ny * 0.9, nz + 0.25).normalized().dot(light)
			lit += (_hash(x, y, 121 + v) - 0.5) * 0.28
			var t := clampf((lit + 0.1) / 1.0, 0.0, 0.999)
			img.set_pixel(x, y, tones[int(t * tones.size())])
	# Facet cracks.
	for i in 2:
		var x := cx + rng.randf_range(-w * 0.4, w * 0.3)
		var y := cy + rng.randf_range(-h * 0.5, 0.0)
		for j in rng.randi_range(5, 9):
			var px := int(x) + j / 2
			var py := int(y) + j
			if px >= 0 and py >= 0 and px < T and py < T and img.get_pixel(px, py).a > 0.0:
				img.set_pixel(px, py, tones[0])
	if ROCK_MOSS[v] == 1 and not icon:
		for y in T:
			for x in T:
				var col := img.get_pixel(x, y)
				if col.a > 0.0 and y < cy and _snoise(x, y, 4.0, 131) > 0.66:
					img.set_pixel(x, y, C.moss_dark if col == tones[0] or col == tones[1] else C.moss)
					if _hash(x, y, 132) > 0.7:
						img.set_pixel(x, y, C.moss_light)
	if not icon:
		for i in 7:
			var gx := int(cx - w + rng.randf() * w * 2.0)
			var gy := int(base)
			if img.get_pixel(clampi(gx, 0, T - 1), gy).a == 0.0:
				_px(img, gx, gy, C.grass_deep)
				_px(img, gx, gy - 1, C.grass)
				_px(img, gx, gy - 2, C.grass_light)
				if i % 2 == 0:
					_px(img, gx + 1, gy - 1, C.grass_light)
	_outline(img, C.outline)
	return img


# ---------------------------------------------------------------- props

func _make_campfire() -> Image:
	var img := _new_image(T * 3, T)
	for frame in 3:
		var f := _new_image(T, T)
		rng.seed = 77 + frame
		# Ember bed.
		_blob(f, 16, 24, 9, 3.5, [C.fire_deep, C.fire_out, C.fire_mid], 0.2, 140 + frame)
		# Crossed logs.
		_tube(f, Vector2(7, 26), Vector2(24, 20), 3, [C.wood_deep, C.wood_dark, C.wood, C.wood_light])
		_tube(f, Vector2(25, 26), Vector2(8, 20), 3, [C.wood_deep, C.wood_dark, C.wood, C.wood_light])
		_rect(f, 7, 25, 2, 3, C.wood_hi)
		# Flames: three nested tongues that sway per frame.
		var layers := [[C.fire_out, 17, 6.5], [C.fire_mid, 13, 4.8], [C.fire_core, 8, 2.8]]
		for layer in layers:
			var h: int = layer[1] + rng.randi_range(-1, 1)
			var wmax: float = layer[2]
			for y in h:
				var fr := float(y) / h
				var half := wmax * pow(1.0 - fr, 0.75) * (1.0 + 0.22 * sin(y * 0.8 + frame * 2.1))
				var sway := sin(fr * 3.2 + frame * 2.1) * 2.0 * fr
				for x in range(int(16 + sway - half), int(16 + sway + half) + 1):
					_px(f, x, 23 - y, layer[0])
		# Sparks.
		for i in 3:
			_px(f, rng.randi_range(10, 22), rng.randi_range(0, 6), C.fire_core)
		# Stone ring on top of everything.
		for i in 9:
			var a := PI * (0.05 + 0.9 * float(i) / 8.0)
			var sx := 16.0 + cos(a) * 12.0
			var sy := 25.0 + sin(a) * 4.5
			_blob(f, sx, sy, 3.2, 2.6, [C.rock_deep, C.rock_dark, C.rock, C.rock_light], 0.2, 150 + i)
		_outline(f, C.outline)
		img.blit_rect(f, Rect2i(0, 0, T, T), Vector2i(frame * T, 0))
	return img


func _make_shadow() -> Image:
	var img := _new_image(T, 12)
	for y in 12:
		for x in T:
			var nx := (x + 0.5 - 16.0) / 15.0
			var ny := (y + 0.5 - 6.0) / 5.0
			var d := nx * nx + ny * ny
			if d <= 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.42 if d < 0.55 else 0.24))
	return img


func _make_time_icons() -> Image:
	var img := _new_image(18, 9)
	for y in 9:
		for x in 9:
			var d := Vector2(x - 4, y - 4)
			if d.length() <= 2.6:
				img.set_pixel(x, y, C.sun)
			elif (x == 4 or y == 4 or absi(x - 4) == absi(y - 4)) and d.length() <= 4.3 and d.length() > 3.2:
				img.set_pixel(x, y, C.sun)
			var m := Vector2(x - 4, y - 4)
			var cut := Vector2(x - 6, y - 3)
			if m.length() <= 3.6 and cut.length() > 2.8:
				img.set_pixel(9 + x, y, C.moon)
	return img


# ---------------------------------------------------------------- structures

func _planks_h(img: Image, x: int, y: int, w: int, h: int, plank_h: int, seed: int) -> void:
	var rows := h / plank_h
	for r in rows:
		var py := y + r * plank_h
		var joint := int(_hash(r, seed, 5) * (w - 8)) + 4
		var tone := (_hash(r, seed, 6) - 0.5) * 0.14
		for yy in plank_h:
			for xx in w:
				var n := _hash(xx / 3, py + yy, seed)
				var col: Color = C.wood_light.lightened(tone)
				if yy == 0:
					col = C.wood_hi.lightened(tone)
				elif yy == plank_h - 1:
					col = C.wood_dark
				elif n > 0.74:
					col = C.wood
				elif n < 0.12:
					col = C.wood_hi
				if xx == joint:
					col = C.wood_deep
				_px(img, x + xx, py + yy, col)
		_px(img, x + 2, py + plank_h / 2, C.iron_dark)
		_px(img, x + w - 3, py + plank_h / 2, C.iron_dark)


func _make_structure(kind: String) -> Image:
	var img := _new_image(T, T)
	match kind:
		"wooden_floor":
			_planks_h(img, 0, 0, T, T, 8, 201)
			return img
		"wooden_wall":
			# Cap on top, vertical planks below.
			_planks_h(img, 1, 1, T - 2, 7, 7, 211)
			for p in 4:
				var x0 := 1 + p * 8
				var tone := (_hash(p, 2, 212) - 0.5) * 0.12
				for yy in range(8, T - 1):
					for xx in 8:
						var col: Color = C.wood.lightened(tone)
						if xx == 0:
							col = C.wood_deep
						elif xx == 1:
							col = C.wood_light
						elif xx >= 6:
							col = C.wood_dark
						elif _hash(x0 + xx, yy / 3, 213) > 0.8:
							col = C.wood_dark
						_px(img, x0 + xx, yy, col)
			_rect(img, 1, T - 3, T - 2, 2, C.wood_deep)
			for x in [4, 12, 20, 28]:
				_px(img, x, 12, C.iron_light)
				_px(img, x, 24, C.iron_light)
		"wooden_door_closed":
			_box(img, 2, 1, 5, T - 2, C.wood_dark, 0.1, 221)
			_box(img, T - 7, 1, 5, T - 2, C.wood_dark, 0.1, 222)
			_box(img, 2, 1, T - 4, 5, C.wood_dark, 0.1, 223)
			for p in 3:
				var x0 := 7 + p * 6
				for yy in range(6, T - 1):
					for xx in 6:
						var col: Color = C.wood
						if xx == 0:
							col = C.wood_deep
						elif xx == 1:
							col = C.wood_light
						elif xx == 5:
							col = C.wood_dark
						elif _hash(x0 + xx, yy / 3, 224) > 0.82:
							col = C.wood_dark
						_px(img, x0 + xx, yy, col)
			for y in [9, 24]:
				_rect(img, 7, y, 18, 3, C.iron)
				_rect(img, 7, y, 18, 1, C.iron_light)
				_rect(img, 7, y + 2, 18, 1, C.iron_dark)
			_blob(img, 22, 17, 2.4, 2.4, [C.iron_dark, C.gold, C.gold, C.wood_hi])
		"wooden_door_open":
			_box(img, 2, 1, 5, T - 2, C.wood_dark, 0.1, 221)
			_box(img, T - 7, 1, 5, T - 2, C.wood_dark, 0.1, 222)
			_box(img, 2, 1, T - 4, 5, C.wood_dark, 0.1, 223)
			# Door leaf swung open against the left post.
			for yy in range(6, T - 1):
				for xx in range(7, 12):
					var col: Color = C.wood
					if xx == 7:
						col = C.wood_light
					elif xx == 11:
						col = C.wood_deep
					_px(img, xx, yy, col)
			for y in [9, 24]:
				_rect(img, 7, y, 5, 2, C.iron)
			_rect(img, 12, 6, T - 19, T - 7, Color(0.1, 0.07, 0.05, 0.35))
		"workbench":
			for lx in [4, T - 8]:
				_box(img, lx, 17, 4, 12, C.wood_dark, 0.1, 231)
			_box(img, 6, 20, T - 12, 3, C.wood_dark)
			_planks_h(img, 2, 8, T - 4, 6, 6, 232)
			_box(img, 2, 14, T - 4, 5, C.wood, 0.1, 233)
			# Tools on the bench: saw, hammer, planks.
			_rect(img, 5, 5, 10, 3, C.iron_light)
			_rect(img, 5, 7, 10, 1, C.iron_dark)
			for tx in range(6, 15, 2):
				_px(img, tx, 8, C.iron_dark)
			_rect(img, 4, 5, 2, 3, C.wood)
			_tube(img, Vector2(19, 7), Vector2(26, 4), 1, [C.wood_dark, C.wood, C.wood_light])
			_rect(img, 24, 1, 5, 4, C.iron)
			_rect(img, 24, 1, 5, 1, C.iron_light)
		"chest":
			# Body.
			_box(img, 3, 14, T - 6, 15, C.wood, 0.12, 241)
			for y in [18, 23]:
				_rect(img, 4, y, T - 8, 1, C.wood_dark)
			# Curved lid.
			_blob(img, 16, 15, 13.0, 8.0, [C.wood_dark, C.wood, C.wood_light, C.wood_hi], 0.1, 242, 15.0)
			# Iron straps and lock.
			for sx in [6, T - 10]:
				_box(img, sx, 8, 4, 21, C.iron, 0.06, 243)
			_box(img, 13, 13, 6, 7, C.gold, 0.05, 244)
			_rect(img, 15, 15, 2, 3, C.outline)
			_rect(img, 3, 27, T - 6, 2, C.wood_deep)
	_outline(img, C.outline)
	return img


# ---------------------------------------------------------------- item icons

func _make_item_icons() -> void:
	var icons := {}
	icons["wood"] = _icon_log()
	icons["stone"] = _make_rock(5, true)
	icons["plank"] = _icon_planks()
	icons["stick"] = _icon_sticks()
	icons["torch"] = _icon_torch()
	icons["stone_axe"] = _icon_tool(true)
	icons["stone_pickaxe"] = _icon_tool(false)
	for id in ["wooden_wall", "wooden_floor", "workbench", "chest"]:
		icons[id] = _make_structure(id)
	icons["wooden_door"] = _make_structure("wooden_door_closed")
	for id in icons:
		var big: Image = icons[id]
		_save(big, "res://assets/ui/items/%s.png" % id)
		var small := big.duplicate() as Image
		small.resize(16, 16, Image.INTERPOLATE_LANCZOS)
		_save(small, "res://assets/ui/items/%s_s.png" % id)


func _icon_log() -> Image:
	var img := _new_image(T, T)
	_tube(img, Vector2(8, 22), Vector2(25, 12), 6, [C.bark_dark, C.bark, C.bark_light, C.bark_light])
	for i in 3:
		var t := float(i) / 2.0
		var p := Vector2(12, 20).lerp(Vector2(22, 14), t)
		_px(img, int(p.x), int(p.y), C.bark_dark)
	_blob(img, 8, 22, 4.6, 6.2, [C.wood, C.wood_light, C.wood_hi, C.wood_hi], 0.0, 301)
	for r in [1.6, 3.2]:
		for a in 24:
			var ang := TAU * a / 24.0
			_px(img, int(8 + cos(ang) * r * 0.75), int(22 + sin(ang) * r * 1.0), C.wood_dark)
	_px(img, 8, 22, C.wood_deep)
	_outline(img, C.outline)
	return img


func _icon_planks() -> Image:
	var img := _new_image(T, T)
	for i in 3:
		var y := 8 + i * 6
		_tube(img, Vector2(4 + i, y + 6), Vector2(26 + i, y), 3, [C.wood_dark, C.wood, C.wood_light, C.wood_hi])
		_px(img, 6 + i, y + 5, C.iron_dark)
		_px(img, 24 + i, y + 1, C.iron_dark)
	_outline(img, C.outline)
	return img


func _icon_sticks() -> Image:
	var img := _new_image(T, T)
	_tube(img, Vector2(6, 26), Vector2(26, 6), 2, [C.bark_dark, C.bark, C.bark_light, C.bark_light])
	_tube(img, Vector2(8, 8), Vector2(25, 25), 2, [C.bark_dark, C.bark, C.bark_light, C.bark_light])
	_line(img, Vector2(15, 17), Vector2(21, 11), C.bark_light, 1)
	_line(img, Vector2(18, 20), Vector2(24, 18), C.bark, 1)
	_outline(img, C.outline)
	return img


func _icon_torch() -> Image:
	var img := _new_image(T, T)
	_tube(img, Vector2(10, 28), Vector2(18, 14), 2, [C.wood_dark, C.wood, C.wood_light, C.wood_light])
	_blob(img, 19, 12, 4.0, 4.5, [C.pants_dark, C.pants, C.cloth, C.cloth], 0.1, 311)
	for y in 11:
		var half := 4.5 * pow(1.0 - float(y) / 11.0, 0.7)
		for x in range(int(19 - half), int(19 + half) + 1):
			_px(img, x, 9 - y, C.fire_out)
		for x in range(int(19 - half * 0.6), int(19 + half * 0.6) + 1):
			if y < 8:
				_px(img, x, 9 - y, C.fire_mid)
		if y < 5:
			_px(img, 19, 9 - y, C.fire_core)
	_outline(img, C.outline)
	return img


func _icon_tool(axe: bool) -> Image:
	var img := _new_image(T, T)
	_tube(img, Vector2(8, 27), Vector2(22, 8), 2, [C.wood_dark, C.wood, C.wood_light, C.wood_hi])
	var tones := [C.rock_deep, C.rock_dark, C.rock, C.rock_light, C.rock_hi]
	if axe:
		var pts := PackedVector2Array([Vector2(16, 6), Vector2(27, 5), Vector2(29, 14), Vector2(22, 14), Vector2(20, 11)])
		_fill_poly(img, pts, tones)
	else:
		var pts := PackedVector2Array([Vector2(10, 9), Vector2(17, 4), Vector2(26, 6), Vector2(30, 13), Vector2(27, 11), Vector2(19, 9), Vector2(13, 12)])
		_fill_poly(img, pts, tones)
	_rect(img, 18, 11, 4, 2, C.cloth)
	_rect(img, 18, 12, 4, 1, C.pants_dark)
	_outline(img, C.outline)
	return img


## Fills a polygon with a top-left to bottom-right stone gradient.
func _fill_poly(img: Image, pts: PackedVector2Array, tones: Array) -> void:
	var rect := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		rect = rect.expand(p)
	for y in range(int(rect.position.y), int(rect.end.y) + 1):
		for x in range(int(rect.position.x), int(rect.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				var t := ((x - rect.position.x) / maxf(rect.size.x, 1.0) * 0.45 + (y - rect.position.y) / maxf(rect.size.y, 1.0) * 0.55)
				t = clampf(1.0 - t + (_hash(x, y, 321) - 0.5) * 0.3, 0.0, 0.999)
				_px(img, x, y, tones[int(t * tones.size())])
