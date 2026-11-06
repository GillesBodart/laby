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
	for dir in ["res://assets/tilesets", "res://assets/sprites", "res://assets/sprites/trees", "res://assets/sprites/rocks", "res://assets/sprites/structures", "res://assets/ui", "res://assets/ui/items", "res://assets/sprites/enemies", "res://assets/sprites/resources"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save(_make_tileset(), Catalog.TEXTURE_PATH)
	_save(_make_player(), "res://assets/sprites/player.png")
	for v in VARIANTS:
		_save(_make_tree(v), "res://assets/sprites/trees/tree_%d.png" % v)
		_save(_make_rock(v), "res://assets/sprites/rocks/rock_%d.png" % v)
	_save(_make_tree(0), "res://assets/sprites/tree.png")
	_save(_make_rock(0), "res://assets/sprites/rock.png")
	_save(_make_campfire(), "res://assets/sprites/campfire.png")
	for s in ["workbench", "chest", "wooden_wall", "wooden_floor", "wooden_door_closed", "wooden_door_open", "furnace", "stone_wall", "brick_wall", "stone_floor", "farm_plot_0", "farm_plot_1", "farm_plot_2", "anvil", "cooking_pot", "tanning_rack", "stonecutter"]:
		_save(_make_structure(s), "res://assets/sprites/structures/%s.png" % s)
	_save(_make_shadow(), "res://assets/sprites/shadow.png")
	_save(_make_time_icons(), "res://assets/ui/time_icons.png")
	_make_item_icons()
	_save(_make_bush(), "res://assets/sprites/bush.png")
	_save(_make_grass_tuft(), "res://assets/sprites/resources/grass.png")
	_save(_make_clay(), "res://assets/sprites/resources/clay.png")
	_save(_make_mushrooms(), "res://assets/sprites/resources/mushroom.png")
	_save(_make_ore([Color8(20, 20, 26), Color8(52, 52, 60), Color8(80, 80, 92)], 1), "res://assets/sprites/resources/ore_coal.png")
	_save(_make_ore([MAT["copper"][2], MAT["copper"][3], Color8(80, 170, 120)], 2), "res://assets/sprites/resources/ore_copper.png")
	_save(_make_ore([Color8(196, 160, 140), Color8(150, 110, 96), Color8(220, 190, 170)], 3), "res://assets/sprites/resources/ore_iron.png")
	_save(_make_ore([MAT["crystal"][2], MAT["crystal"][3], MAT["crystal"][4]], 4), "res://assets/sprites/resources/ore_crystal.png")
	for e in ["grub", "stalker", "warden"]:
		_save(_make_enemy(e), "res://assets/sprites/enemies/%s.png" % e)
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
		"furnace":
			_box(img, 3, 8, T - 6, 21, C.rock, 0.14, 251)
			_rect(img, 3, 8, T - 6, 3, C.rock_light)
			for y in [14, 20, 26]:
				_rect(img, 3, y, T - 6, 1, C.rock_dark)
			_box(img, 10, 17, 12, 10, C.outline)
			_rect(img, 11, 22, 10, 5, C.fire_deep)
			_rect(img, 12, 21, 8, 5, C.fire_out)
			_rect(img, 14, 20, 4, 5, C.fire_mid)
			_rect(img, 15, 22, 2, 3, C.fire_core)
			_box(img, 12, 1, 8, 8, C.rock_dark, 0.1, 252)
			_rect(img, 14, 1, 4, 2, C.outline)
		"stone_wall":
			_wall_blocks(img, MAT["stone"], 261, false)
		"brick_wall":
			_wall_blocks(img, MAT["brick"], 271, true)
		"stone_floor":
			for y in T:
				for x in T:
					var h := _hash(x / 8, y / 8, 282)
					var base: Color = C.rock.lightened((h - 0.5) * 0.18)
					var gx := (x + (y / 8 % 2) * 4) % 8
					if gx == 7 or y % 8 == 7:
						base = C.rock_dark
					elif gx == 0 or y % 8 == 0:
						base = C.rock_light
					_px(img, x, y, base)
			return img
		"anvil":
			return _st_anvil()
		"cooking_pot":
			return _st_cooking_pot()
		"tanning_rack":
			return _st_tanning_rack()
		"stonecutter":
			return _st_stonecutter()
		"farm_plot_0":
			return _make_farm_plot(0)
		"farm_plot_1":
			return _make_farm_plot(1)
		"farm_plot_2":
			return _make_farm_plot(2)
	_outline(img, C.outline)
	return img


## Masonry wall: a lighter cap on top and offset blocks below.
func _wall_blocks(img: Image, tones: Array, seed: int, brick: bool) -> void:
	var bh := 6 if brick else 8
	var bw := 10 if brick else 15
	for y in range(8, T - 1):
		var row := (y - 8) / bh
		var ox := (row % 2) * (bw / 2)
		for x in range(1, T - 1):
			var gx := (x + ox) % bw
			var gy := (y - 8) % bh
			var col: Color = tones[2].lightened((_hash((x + ox) / bw, row, seed) - 0.5) * 0.14)
			if gx == bw - 1 or gy == bh - 1:
				col = tones[0]
			elif gy == 0:
				col = tones[3]
			elif gx == 0:
				col = tones[3]
			_px(img, x, y, col)
	_rect(img, 1, 1, T - 2, 7, tones[3])
	_rect(img, 1, 1, T - 2, 1, tones[4])
	_rect(img, 1, 7, T - 2, 1, tones[1])
	for x in range(1, T - 1, 4):
		_px(img, x + int(_hash(x, 0, seed) * 3.0), 3, tones[2])


# ---------------------------------------------------------------- item icons

func _make_item_icons() -> void:
	var icons := {}
	icons["wood"] = _icon_log()
	icons["stone"] = _make_rock(5, true)
	icons["plank"] = _icon_planks()
	icons["stick"] = _ic_stick()
	icons["torch"] = _icon_torch()
	icons["stone_axe"] = _ic_axe(MAT["stone"])
	icons["stone_pickaxe"] = _ic_pickaxe(MAT["stone"])
	for id in ["wooden_wall", "wooden_floor", "workbench", "chest"]:
		icons[id] = _make_structure(id)
	icons["wooden_door"] = _make_structure("wooden_door_closed")
	icons["berry"] = _icon_berries()
	for id in ["furnace", "stone_wall", "stone_floor", "brick_wall"]:
		icons[id] = _make_structure(id)
	icons["farm_plot"] = _icon_farm_plot()
	icons["fiber"] = _icon_fiber()
	icons["rope"] = _ic_rope()
	icons["bone"] = _icon_bone()
	icons["hide"] = _ic_hide()
	icons["leather"] = _ic_leather()
	icons["crystal"] = _icon_crystal()
	icons["berry_jam"] = _icon_jam()
	icons["clay"] = _ic_clay()
	icons["coal"] = _ic_coal()
	icons["copper_ore"] = _ic_ore(MAT["stone"], MAT["copper"], 731)
	icons["iron_ore"] = _ic_ore(MAT["stone"], [Color8(110, 60, 44), Color8(150, 92, 70), Color8(196, 150, 120), Color8(220, 186, 160), Color8(240, 220, 200)], 732)
	icons["brick"] = _ic_ingots(MAT["brick"])
	icons["copper_ingot"] = _ic_ingots(MAT["copper"])
	icons["iron_ingot"] = _ic_ingots(MAT["iron"])
	for m in ["copper", "iron"]:
		icons[m + "_axe"] = _ic_axe(MAT[m])
		icons[m + "_pickaxe"] = _ic_pickaxe(MAT[m])
		icons[m + "_sword"] = _icon_sword(MAT[m])
		icons[m + "_armor"] = _ic_armor(MAT[m], false)
		icons[m + "_helm"] = _ic_helm(MAT[m], m)
		icons[m + "_boots"] = _ic_boots(MAT[m], MAT["leather"])
	icons["stone_sword"] = _icon_sword(MAT["stone"])
	icons["bone_sword"] = _icon_sword(MAT["bone"])
	icons["crystal_blade"] = _icon_sword(MAT["crystal"])
	icons["leather_armor"] = _ic_armor(MAT["leather"], true)
	icons["leather_cap"] = _ic_helm(MAT["leather"], "leather")
	icons["leather_boots"] = _ic_boots(MAT["leather"], [Color8(150, 104, 70), Color8(182, 138, 96), Color8(206, 170, 126), Color8(226, 196, 156), Color8(240, 220, 186)])
	icons["copper_ring"] = _ic_ring(MAT["copper"], RUBY5)
	icons["crystal_ring"] = _ic_ring(MAT["iron"], MAT["crystal"])
	icons["bone_charm"] = _ic_amulet("bone")
	icons["crystal_amulet"] = _ic_amulet("crystal")
	for id in ["anvil", "cooking_pot", "tanning_rack", "stonecutter"]:
		icons[id] = _make_structure(id)
	icons["mushroom"] = _ic_mushroom()
	icons["raw_meat"] = _ic_raw_meat()
	icons["cooked_meat"] = _ic_cooked_meat()
	icons["roasted_mushroom"] = _ic_roasted_mushroom()
	icons["mushroom_soup"] = _ic_bowl([Color8(226, 196, 150), Color8(196, 160, 112)], [CAP5[2], CAP5[3], LEAF5[3]], true)
	icons["meat_stew"] = _ic_bowl([Color8(170, 100, 56), Color8(132, 72, 40)], [COOK5[0], Color8(232, 150, 60), LEAF5[3]], true)
	icons["forest_salad"] = _ic_bowl([LEAF5[3], LEAF5[2]], [BERRY[2], LEAF5[4], CAP5[3], BERRY[1]], false)
	for id in icons:
		var big: Image = icons[id]
		_save(big, "res://assets/ui/items/%s.png" % id)
		var small := big.duplicate() as Image
		small.resize(16, 16, Image.INTERPOLATE_LANCZOS)
		_save(small, "res://assets/ui/items/%s_s.png" % id)


const BERRY := [Color8(110, 24, 52), Color8(168, 36, 70), Color8(214, 70, 96), Color8(250, 150, 160)]


func _berry(img: Image, x: int, y: int) -> void:
	_rect(img, x, y, 3, 3, BERRY[1])
	_px(img, x, y + 2, BERRY[0])
	_px(img, x + 1, y + 2, BERRY[0])
	_px(img, x + 2, y + 1, BERRY[0])
	_px(img, x, y, BERRY[2])
	_px(img, x + 1, y, BERRY[3])


## Low berry bush (feet at the bottom center of a 32x32 frame).
func _make_bush() -> Image:
	var img := _new_image(T, T)
	var greens := [C.grass_deep, C.grass_dark, C.grass, C.grass_light]
	_blob(img, 9, 20, 8, 7, greens, 0.2, 401)
	_blob(img, 22, 20, 8, 7, greens, 0.2, 402)
	_blob(img, 16, 15, 10, 9, greens, 0.2, 403)
	_outline(img, C.outline)
	for p in [Vector2i(10, 15), Vector2i(19, 12), Vector2i(23, 19), Vector2i(14, 20), Vector2i(7, 21), Vector2i(17, 17)]:
		_berry(img, p.x, p.y)
	return img


func _icon_berries() -> Image:
	var img := _new_image(T, T)
	for p in [Vector2i(8, 17), Vector2i(15, 12), Vector2i(17, 19), Vector2i(11, 22)]:
		_blob(img, p.x + 3, p.y + 3, 4.5, 4.5, [BERRY[0], BERRY[1], BERRY[2], BERRY[2]], 0.0, p.x)
		_px(img, p.x + 1, p.y + 1, BERRY[3])
		_px(img, p.x + 2, p.y + 1, BERRY[3])
	_tube(img, Vector2(15, 12), Vector2(19, 6), 2, [C.grass_deep, C.grass_dark, C.grass, C.grass])
	_blob(img, 22, 7, 4, 2.6, [C.grass_deep, C.grass_dark, C.grass, C.grass_light], 0.0, 411)
	_outline(img, C.outline)
	return img


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


const MAT := {
	"copper": [Color8(110, 56, 34), Color8(160, 86, 50), Color8(206, 122, 72), Color8(236, 160, 100), Color8(250, 204, 154)],
	"iron": [Color8(70, 74, 84), Color8(110, 116, 128), Color8(160, 166, 176), Color8(200, 205, 212), Color8(236, 240, 244)],
	"crystal": [Color8(30, 90, 130), Color8(60, 160, 200), Color8(110, 220, 240), Color8(170, 240, 250), Color8(235, 255, 255)],
	"bone": [Color8(150, 140, 118), Color8(196, 186, 160), Color8(232, 224, 200), Color8(246, 240, 224), Color8(255, 252, 240)],
	"leather": [Color8(70, 42, 26), Color8(104, 64, 38), Color8(140, 90, 54), Color8(172, 118, 74), Color8(200, 146, 96)],
	"brick": [Color8(96, 38, 30), Color8(140, 58, 44), Color8(184, 82, 60), Color8(212, 112, 84), Color8(232, 146, 112)],
	"coal": [Color8(14, 14, 18), Color8(30, 30, 36), Color8(52, 52, 60), Color8(80, 80, 92), Color8(120, 120, 134)],
	"clay": [Color8(104, 60, 44), Color8(140, 84, 58), Color8(176, 112, 80), Color8(204, 142, 104), Color8(224, 170, 132)],
	"stone": [Color8(58, 62, 66), Color8(88, 92, 94), Color8(128, 132, 130), Color8(168, 170, 164), Color8(204, 204, 192)],
}


func _icon_sword(tones: Array) -> Image:
	var img := _new_image(T, T)
	var dir := Vector2(1, -1).normalized()
	var perp := Vector2(1, 1).normalized()
	var base := Vector2(4.5, 28.5)
	var grip := [C.wood_deep, C.wood_dark, C.wood, C.wood_light]
	# Blade, grip, guard and pommel are stamped along the diagonal, one pixel at a time.
	for i in range(0, 400):
		var t := i * 0.07
		var half := 0.0
		var col: Color = tones[2]
		if t < 1.6:
			half = 1.6
			col = C.gold
		elif t < 6.5:
			half = 1.0
			col = grip[1 + (int(t * 1.5) % 2)]
		elif t < 8.0:
			half = 4.6
			col = C.gold if int(t * 3.0) % 2 == 0 else C.wood_hi
		elif t < 27.5:
			half = 2.3 if t < 24.0 else maxf((27.5 - t) * 0.65, 0.0)
			col = tones[2]
		else:
			continue
		var w := -half
		while w <= half:
			var p := base + dir * t + perp * w
			var shade := col
			if t >= 8.0:
				if w < -half * 0.45:
					shade = tones[4]
				elif w > half * 0.45:
					shade = tones[1]
				elif absf(w) < 0.4:
					shade = tones[3]
			elif t >= 6.5:
				shade = col.darkened(0.25) if w > half * 0.5 else col
			_px(img, int(p.x), int(p.y), shade)
			w += 0.5
	_outline(img, C.outline)
	return img

func _icon_fiber() -> Image:
	var img := _new_image(T, T)
	for i in 5:
		_line(img, Vector2(8 + i * 3, 26), Vector2(6 + i * 5, 8 + (i % 2) * 4), [C.grass_dark, C.grass, C.grass_light][i % 3], 2)
	_rect(img, 9, 19, 14, 2, C.cloth)
	_outline(img, C.outline)
	return img


func _icon_bone() -> Image:
	var img := _new_image(T, T)
	var t: Array = MAT["bone"]
	_tube(img, Vector2(9, 23), Vector2(23, 9), 3, [t[1], t[2], t[3], t[4]])
	for p in [Vector2(7, 21), Vector2(11, 25), Vector2(21, 7), Vector2(25, 11)]:
		_blob(img, p.x, p.y, 3, 3, [t[1], t[2], t[3]], 0.0, int(p.x))
	_outline(img, C.outline)
	return img


func _icon_crystal() -> Image:
	var img := _new_image(T, T)
	var t: Array = MAT["crystal"]
	_fill_poly(img, PackedVector2Array([Vector2(16, 3), Vector2(22, 12), Vector2(20, 27), Vector2(12, 27), Vector2(10, 12)]), t)
	_fill_poly(img, PackedVector2Array([Vector2(8, 14), Vector2(11, 20), Vector2(10, 28), Vector2(4, 26), Vector2(5, 19)]), t)
	_fill_poly(img, PackedVector2Array([Vector2(24, 16), Vector2(28, 22), Vector2(27, 28), Vector2(21, 27), Vector2(21, 21)]), t)
	_line(img, Vector2(15, 8), Vector2(14, 20), t[4], 1)
	_outline(img, C.outline)
	return img


func _icon_jam() -> Image:
	var img := _new_image(T, T)
	_box(img, 8, 11, 16, 16, Color8(196, 220, 226), 0.0, 0)
	_rect(img, 9, 15, 14, 11, BERRY[1])
	_rect(img, 9, 15, 14, 2, BERRY[2])
	_rect(img, 9, 24, 14, 2, BERRY[0])
	_rect(img, 7, 7, 18, 5, C.wood)
	_rect(img, 7, 7, 18, 1, C.wood_light)
	_rect(img, 7, 11, 18, 1, C.wood_dark)
	_px(img, 11, 18, BERRY[3])
	_outline(img, C.outline)
	return img


func _icon_farm_plot() -> Image:
	return _make_structure("farm_plot_2")


## Mineral outcrop: a rock blob flecked with the ore colours (feet at bottom centre).
func _make_ore(specks: Array, seed: int) -> Image:
	var img := _new_image(T, T)
	var tones := [C.rock_deep, C.rock_dark, C.rock, C.rock_light]
	_blob(img, 16, 22, 12, 8, tones, 0.14, 600 + seed)
	_blob(img, 15, 15, 9, 8, tones, 0.14, 610 + seed)
	_blob(img, 12, 12, 4, 3, [C.rock_light, C.rock_hi], 0.0, 620 + seed)
	_outline(img, C.outline)
	for i in 9:
		var x := 8 + int(_hash(i, 1, 630 + seed) * 16.0)
		var y := 11 + int(_hash(i, 2, 630 + seed) * 14.0)
		if img.get_pixel(x, y).a > 0.5 and img.get_pixel(x + 1, y + 1).a > 0.5:
			_rect(img, x, y, 2, 2, specks[i % specks.size()])
			_px(img, x, y, specks[(i + 1) % specks.size()])
	return img


func _make_grass_tuft() -> Image:
	var img := _new_image(T, T)
	var greens := [C.grass_deep, C.grass_dark, C.grass, C.grass_light]
	for i in 9:
		var bx := 8 + i * 2
		var h := 9 + int(_hash(i, 3, 640) * 9.0)
		var lean := int((_hash(i, 4, 641) - 0.5) * 8.0)
		_line(img, Vector2(bx, 28), Vector2(bx + lean, 28 - h), greens[1 + i % 3], 2)
		_px(img, bx + lean, 28 - h, greens[3])
	_outline(img, C.outline)
	return img


func _make_clay() -> Image:
	var img := _new_image(T, T)
	var t: Array = MAT["clay"]
	_blob(img, 16, 24, 12, 5, [t[0], t[1], t[2], t[3]], 0.15, 650)
	_blob(img, 13, 22, 4, 2, [t[3], t[4]], 0.0, 651)
	_blob(img, 21, 25, 3, 1.5, [t[0], t[1]], 0.0, 652)
	_outline(img, C.outline)
	return img


## Plot growth stage: 0 tilled soil, 1 sprouts, 2 ripe berries.
func _make_farm_plot(stage: int) -> Image:
	var img := _new_image(T, T)
	_rect(img, 0, 0, T, T, C.dirt_dark)
	for row in 4:
		var y := 2 + row * 8
		_rect(img, 1, y, T - 2, 3, C.dirt_light)
		_rect(img, 1, y + 3, T - 2, 3, C.dirt)
		_rect(img, 1, y + 6, T - 2, 1, C.dirt_deep)
	for i in 14:
		_px(img, int(_hash(i, 5, 660) * 30.0) + 1, int(_hash(i, 6, 660) * 30.0) + 1, C.dirt_dark)
	_rect(img, 0, 0, T, 1, C.wood_dark)
	_rect(img, 0, T - 1, T, 1, C.wood_dark)
	_rect(img, 0, 0, 1, T, C.wood_dark)
	_rect(img, T - 1, 0, 1, T, C.wood_dark)
	if stage >= 1:
		for p in [Vector2i(7, 8), Vector2i(23, 8), Vector2i(7, 24), Vector2i(23, 24), Vector2i(15, 16)]:
			_rect(img, p.x, p.y - 1, 2, 5, C.grass_dark)
			_rect(img, p.x - 3, p.y - 2, 3, 2, C.grass)
			_rect(img, p.x + 2, p.y - 3, 3, 2, C.grass_light)
			if stage == 2:
				_rect(img, p.x - 4, p.y - 6, 10, 5, C.grass_dark)
				_rect(img, p.x - 3, p.y - 6, 8, 2, C.grass)
				_berry(img, p.x - 3, p.y - 4)
				_berry(img, p.x + 1, p.y - 3)
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


## 32x32 creature sprites, feet at the bottom centre.
func _make_enemy(kind: String) -> Image:
	var img := _new_image(32, 32)
	var eye := Color(1.0, 0.85, 0.2)
	match kind:
		"grub":
			_blob(img, 16, 22, 10, 6, [Color(0.18, 0.28, 0.12), Color(0.3, 0.45, 0.2), Color(0.45, 0.62, 0.3), Color(0.6, 0.75, 0.4)], 0.15, 3)
			_blob(img, 22, 19, 5, 4, [Color(0.22, 0.34, 0.14), Color(0.36, 0.5, 0.22), Color(0.5, 0.66, 0.32)], 0.1, 4)
			_rect(img, 23, 18, 2, 2, eye)
		"stalker":
			_blob(img, 15, 18, 9, 5, [Color(0.12, 0.1, 0.16), Color(0.2, 0.17, 0.26), Color(0.3, 0.26, 0.38), Color(0.42, 0.36, 0.5)], 0.12, 5)
			_blob(img, 23, 15, 4, 3, [Color(0.16, 0.13, 0.2), Color(0.26, 0.22, 0.32), Color(0.38, 0.32, 0.46)], 0.1, 6)
			for lx in [8, 12, 17, 21]:
				_line(img, Vector2(lx, 21), Vector2(lx + (lx - 15) / 3, 27), Color(0.2, 0.17, 0.26))
			_rect(img, 24, 14, 2, 2, Color(1.0, 0.3, 0.25))
		_:
			_blob(img, 16, 18, 11, 10, [Color(0.22, 0.22, 0.24), Color(0.36, 0.37, 0.38), Color(0.5, 0.5, 0.5), Color(0.64, 0.65, 0.62)], 0.2, 7)
			_blob(img, 12, 14, 5, 4, [Color(0.2, 0.34, 0.16), Color(0.3, 0.46, 0.22)], 0.2, 8)
			_blob(img, 17, 10, 5, 4, [Color(0.3, 0.3, 0.32), Color(0.46, 0.46, 0.46), Color(0.6, 0.6, 0.58)], 0.12, 9)
			_rect(img, 15, 10, 2, 2, Color(0.4, 0.9, 1.0))
			_rect(img, 19, 10, 2, 2, Color(0.4, 0.9, 1.0))
	_outline(img, Color(0.05, 0.05, 0.07))
	return img


# ---------------------------------------------------------------- beveled icons
# Shapes are built as pixel masks, then shaded with the light from the top-left:
# a bright rim, a softer second ring, a mid fill and a dark bottom-right edge.

const WOOD5 := [Color8(56, 38, 30), Color8(80, 54, 38), Color8(120, 82, 50), Color8(160, 114, 68), Color8(194, 150, 92)]
const GOLD5 := [Color8(110, 70, 24), Color8(170, 116, 40), Color8(226, 184, 72), Color8(244, 214, 120), Color8(255, 244, 190)]
const RUBY5 := [Color8(90, 16, 30), Color8(150, 30, 50), Color8(210, 56, 70), Color8(240, 120, 120), Color8(255, 210, 200)]


func _mask_fn(test: Callable) -> Dictionary:
	var m := {}
	for y in T:
		for x in T:
			if test.call(Vector2(x + 0.5, y + 0.5)):
				m[Vector2i(x, y)] = true
	return m


func _mask_poly(pts: PackedVector2Array) -> Dictionary:
	return _mask_fn(func(p: Vector2) -> bool: return Geometry2D.is_point_in_polygon(p, pts))


func _mask_ellipse(c: Vector2, rx: float, ry: float) -> Dictionary:
	return _mask_fn(func(p: Vector2) -> bool: return pow((p.x - c.x) / rx, 2) + pow((p.y - c.y) / ry, 2) <= 1.0)


func _mask_stroke(a: Vector2, b: Vector2, half: float) -> Dictionary:
	return _mask_fn(func(p: Vector2) -> bool: return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= half)


func _mask_add(a: Dictionary, b: Dictionary) -> Dictionary:
	var m := a.duplicate()
	m.merge(b)
	return m


func _mask_cut(a: Dictionary, b: Dictionary) -> Dictionary:
	var m := a.duplicate()
	for k in b:
		m.erase(k)
	return m


func _bevel(img: Image, mask: Dictionary, tones: Array) -> void:
	for p in mask:
		var out := func(dx: int, dy: int) -> bool: return not mask.has(p + Vector2i(dx, dy))
		var col: Color = tones[2]
		var dark: bool = out.call(1, 0) or out.call(0, 1)
		var lit: bool = out.call(-1, 0) or out.call(0, -1)
		if dark and lit:
			col = tones[2]
		elif dark:
			col = tones[1]
		elif lit:
			col = tones[4]
		elif out.call(-2, 0) or out.call(0, -2) or out.call(-1, -1):
			col = tones[3]
		elif out.call(2, 0) or out.call(0, 2) or out.call(1, 1):
			col = tones[2].lerp(tones[1], 0.5)
		_px(img, p.x, p.y, col)


func _handle(img: Image, a := Vector2(6.5, 27.5), b := Vector2(21.5, 12.5)) -> void:
	_bevel(img, _mask_stroke(a, b, 1.5), WOOD5)
	for t in [0.25, 0.55]:
		var p := a.lerp(b, t)
		_px(img, int(p.x), int(p.y), WOOD5[1])


func _ic_axe(tones: Array) -> Image:
	var img := _new_image(T, T)
	_handle(img)
	var hub := Vector2(19.5, 13.5)
	var d := Vector2(1, -1).normalized()
	var n := Vector2(-1, -1).normalized()
	var head := _mask_fn(func(p: Vector2) -> bool:
		var r := p - hub
		var s := r.dot(n)
		var u := r.dot(d)
		var w := 2.6 + maxf(s - 2.0, 0.0) * 0.6
		return s >= -3.0 and s <= 9.5 - 1.6 * pow(u / 6.8, 2) and absf(u) <= w)
	_bevel(img, head, tones)
	# Honed cutting edge.
	for p in head:
		var s := (Vector2(p) + Vector2(0.5, 0.5) - hub).dot(n)
		if s > 7.6 and head.has(p + Vector2i(-1, -1)) == false:
			_px(img, p.x, p.y, tones[4])
	_rect(img, 19, 13, 2, 2, C.cloth)
	_px(img, 20, 14, C.pants_dark)
	_outline(img, C.outline)
	return img


func _ic_pickaxe(tones: Array) -> Image:
	var img := _new_image(T, T)
	_handle(img, Vector2(6.5, 27.5), Vector2(20.5, 13.5))
	var hub := Vector2(21.0, 12.0)
	var d := Vector2(1, -1).normalized()
	var along := Vector2(1, 1).normalized()
	var head := _mask_fn(func(p: Vector2) -> bool:
		var r := p - hub
		var u := r.dot(along)
		var s := r.dot(d)
		var centre := 1.5 - 0.03 * u * u
		var half := 2.5 * (1.0 - pow(u / 13.0, 2)) + 0.5
		return absf(u) <= 13.0 and absf(s - centre) <= half)
	_bevel(img, head, tones)
	_rect(img, 20, 12, 2, 2, C.cloth)
	_px(img, 21, 13, C.pants_dark)
	_outline(img, C.outline)
	return img


func _ic_stick() -> Image:
	var img := _new_image(T, T)
	var bark := [C.bark_dark.darkened(0.3), C.bark_dark, C.bark, C.bark_light, C.bark_light.lightened(0.2)]
	_bevel(img, _mask_add(_mask_stroke(Vector2(6.5, 26.5), Vector2(25.5, 6.5), 1.6), _mask_stroke(Vector2(15.5, 17.5), Vector2(22.5, 18.5), 1.0)), bark)
	for t in [0.3, 0.62]:
		var p := Vector2(6.5, 26.5).lerp(Vector2(25.5, 6.5), t)
		_px(img, int(p.x), int(p.y), bark[0])
	_blob(img, 24, 18, 2.2, 1.6, [C.grass_dark, C.grass, C.grass_light], 0.0, 701)
	_outline(img, C.outline)
	return img


func _ic_ingots(tones: Array) -> Image:
	var img := _new_image(T, T)
	for off in [Vector2(3, -6), Vector2(-2, 3)]:
		var top := _mask_poly(PackedVector2Array([Vector2(10, 11) + off, Vector2(23, 11) + off, Vector2(26, 15) + off, Vector2(7, 15) + off]))
		var front := _mask_poly(PackedVector2Array([Vector2(7, 15) + off, Vector2(26, 15) + off, Vector2(26, 20) + off, Vector2(7, 20) + off]))
		for p in front:
			var t: float = (p.y - (15 + off.y)) / 5.0
			_px(img, p.x, p.y, tones[2].lerp(tones[1], t))
		_bevel(img, top, [tones[2], tones[2], tones[3], tones[4], tones[4]])
		_line(img, Vector2(7, 19) + off, Vector2(25, 19) + off, tones[0])
		_line(img, Vector2(8, 16) + off, Vector2(25, 16) + off, tones[3])
	_outline(img, C.outline)
	return img

## Rock chunk with embedded ore nuggets (empty specks = plain mineral lump).
func _ic_ore(rock: Array, ore: Array, seed: int) -> Image:
	var img := _new_image(T, T)
	var pts := PackedVector2Array([Vector2(6, 17), Vector2(10, 9), Vector2(18, 6), Vector2(25, 10), Vector2(27, 19), Vector2(22, 26), Vector2(11, 26)])
	_bevel(img, _mask_poly(pts), rock)
	# Facet crease.
	_line(img, Vector2(12, 12), Vector2(17, 17), rock[1])
	_line(img, Vector2(17, 17), Vector2(24, 15), rock[3])
	if ore.size() > 0:
		for i in 5:
			var c := Vector2(9 + _hash(i, 1, seed) * 15.0, 10 + _hash(i, 2, seed) * 13.0)
			var nug := _mask_ellipse(c, 1.9 + _hash(i, 3, seed), 1.6)
			var keep := {}
			for p in nug:
				if img.get_pixel(p.x, p.y).a > 0.5:
					keep[p] = true
			_bevel(img, keep, ore)
	_outline(img, C.outline)
	return img


func _ic_clay() -> Image:
	var img := _new_image(T, T)
	var t: Array = MAT["clay"]
	var m := _mask_poly(PackedVector2Array([Vector2(6, 14), Vector2(12, 9), Vector2(22, 9), Vector2(27, 14), Vector2(26, 24), Vector2(7, 24)]))
	_bevel(img, m, t)
	_bevel(img, _mask_ellipse(Vector2(14, 14), 2.5, 1.6), [t[3], t[0], t[1], t[1], t[0]])
	_bevel(img, _mask_ellipse(Vector2(20, 17), 2.0, 1.4), [t[3], t[0], t[1], t[1], t[0]])
	_outline(img, C.outline)
	return img


func _ic_armor(tones: Array, leather: bool) -> Image:
	var img := _new_image(T, T)
	var body := _mask_poly(PackedVector2Array([Vector2(8, 7), Vector2(13, 6), Vector2(16, 10), Vector2(19, 6), Vector2(24, 7), Vector2(25, 26), Vector2(16, 28), Vector2(7, 26)]))
	_bevel(img, body, tones)
	for sx in [-1, 1]:
		var cx: int = 16 + sx * 10
		_bevel(img, _mask_ellipse(Vector2(cx, 10), 4.5, 4.0), [tones[0], tones[1], tones[3], tones[4], tones[4]])
	if leather:
		for y in range(12, 26, 2):
			_px(img, 16, y, tones[0])
		_line(img, Vector2(9, 20), Vector2(23, 20), tones[1])
		_rect(img, 9, 21, 15, 2, C.wood_deep)
		_rect(img, 15, 21, 3, 2, C.gold)
	else:
		_line(img, Vector2(16, 12), Vector2(16, 25), tones[4])
		_line(img, Vector2(17, 12), Vector2(17, 25), tones[1])
		for y in [15, 20]:
			_line(img, Vector2(9, y), Vector2(24, y), tones[1])
			_line(img, Vector2(9, y + 1), Vector2(24, y + 1), tones[3])
	_outline(img, C.outline)
	return img


func _ic_helm(tones: Array, kind: String) -> Image:
	var img := _new_image(T, T)
	var dome := _mask_fn(func(p: Vector2) -> bool:
		return p.y <= 19.0 and pow((p.x - 16.0) / 11.0, 2) + pow((p.y - 19.0) / 13.0, 2) <= 1.0)
	_bevel(img, dome, tones)
	match kind:
		"leather":
			for x in range(8, 25, 3):
				_px(img, x, 12, tones[0])
			_bevel(img, _mask_poly(PackedVector2Array([Vector2(3, 19), Vector2(29, 19), Vector2(27, 23), Vector2(5, 23)])), tones)
		"copper":
			_bevel(img, _mask_poly(PackedVector2Array([Vector2(4, 18), Vector2(28, 18), Vector2(28, 22), Vector2(4, 22)])), tones)
			_bevel(img, _mask_poly(PackedVector2Array([Vector2(14, 3), Vector2(18, 3), Vector2(18, 18), Vector2(14, 18)])), GOLD5)
			for x in [7, 12, 20, 25]:
				_px(img, x, 20, GOLD5[3])
		"iron":
			_bevel(img, _mask_poly(PackedVector2Array([Vector2(5, 17), Vector2(27, 17), Vector2(27, 28), Vector2(21, 28), Vector2(21, 21), Vector2(11, 21), Vector2(11, 28), Vector2(5, 28)])), tones)
			_rect(img, 8, 18, 7, 2, C.outline)
			_rect(img, 17, 18, 7, 2, C.outline)
			_bevel(img, _mask_poly(PackedVector2Array([Vector2(15, 17), Vector2(17, 17), Vector2(17, 26), Vector2(15, 26)])), tones)
	_outline(img, C.outline)
	return img


func _ic_boots(tones: Array, cuff: Array) -> Image:
	var img := _new_image(T, T)
	for off in [Vector2(7, -3), Vector2(0, 0)]:
		var boot := _mask_poly(PackedVector2Array([
			Vector2(6, 8) + off, Vector2(14, 8) + off, Vector2(14, 20) + off,
			Vector2(20, 22) + off, Vector2(20, 27) + off, Vector2(6, 27) + off]))
		_bevel(img, boot, tones)
		_bevel(img, _mask_poly(PackedVector2Array([Vector2(5, 7) + off, Vector2(15, 7) + off, Vector2(15, 11) + off, Vector2(5, 11) + off])), cuff)
		_line(img, Vector2(6, 26) + off, Vector2(19, 26) + off, C.outline)
		_line(img, Vector2(7, 25) + off, Vector2(19, 25) + off, tones[0])
	_outline(img, C.outline)
	return img


func _ic_ring(band: Array, gem: Array) -> Image:
	var img := _new_image(T, T)
	var ring := _mask_cut(_mask_ellipse(Vector2(16, 19), 9.5, 8.5), _mask_ellipse(Vector2(16, 19.5), 5.8, 4.8))
	_bevel(img, ring, band)
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(16, 4), Vector2(22, 10), Vector2(16, 15), Vector2(10, 10)])), gem)
	_px(img, 14, 8, gem[4])
	_px(img, 15, 7, gem[4])
	_outline(img, C.outline)
	return img


func _ic_amulet(pendant: String) -> Image:
	var img := _new_image(T, T)
	var cord := GOLD5 if pendant == "crystal" else WOOD5
	for i in 15:
		var a := PI * (0.05 + 0.9 * float(i) / 14.0)
		var p := Vector2(16 - cos(a) * 11.0, 4 + sin(a) * 11.0)
		_rect(img, int(p.x), int(p.y), 2, 2, cord[2] if i % 2 == 0 else cord[1])
	if pendant == "crystal":
		_bevel(img, _mask_ellipse(Vector2(16, 17), 4.5, 4.5), GOLD5)
		_bevel(img, _mask_poly(PackedVector2Array([Vector2(16, 14), Vector2(20, 19), Vector2(16, 28), Vector2(12, 19)])), MAT["crystal"])
	else:
		_bevel(img, _mask_poly(PackedVector2Array([Vector2(10, 15), Vector2(22, 15), Vector2(21, 21), Vector2(16, 30), Vector2(11, 21)])), MAT["bone"])
		_line(img, Vector2(14, 18), Vector2(16, 26), MAT["bone"][1])
		_rect(img, 11, 13, 10, 3, C.wood_dark)
		_rect(img, 11, 13, 10, 1, C.wood_light)
	_outline(img, C.outline)
	return img


func _ic_rope() -> Image:
	var img := _new_image(T, T)
	var tones := [C.pants_dark, Color8(150, 122, 78), C.cloth, Color8(214, 194, 146), Color8(236, 222, 186)]
	for i in 3:
		var cy := 22.0 - i * 5.0
		var loop := _mask_cut(_mask_ellipse(Vector2(16, cy), 11.0 - i, 5.0), _mask_ellipse(Vector2(16, cy - 0.5), 7.5 - i, 2.6))
		_bevel(img, loop, tones)
		for p in loop:
			if (p.x + p.y * 2) % 5 == 0:
				_px(img, p.x, p.y, tones[1])
	_bevel(img, _mask_stroke(Vector2(24.5, 10.5), Vector2(28.5, 5.5), 1.2), tones)
	_outline(img, C.outline)
	return img


func _ic_hide() -> Image:
	var img := _new_image(T, T)
	var fur := [Color8(70, 46, 30), Color8(110, 76, 50), Color8(150, 106, 70), Color8(182, 138, 96), Color8(206, 170, 126)]
	var pts := PackedVector2Array([Vector2(4, 9), Vector2(10, 6), Vector2(16, 8), Vector2(22, 6), Vector2(28, 9), Vector2(26, 16), Vector2(28, 24), Vector2(21, 27), Vector2(16, 24), Vector2(11, 27), Vector2(4, 24), Vector2(6, 16)])
	_bevel(img, _mask_poly(pts), fur)
	for i in 18:
		var x := 7 + int(_hash(i, 7, 711) * 19.0)
		var y := 9 + int(_hash(i, 8, 711) * 15.0)
		_px(img, x, y, fur[1])
		_px(img, x + 1, y - 1, fur[3])
	_outline(img, C.outline)
	return img


func _ic_leather() -> Image:
	var img := _new_image(T, T)
	var t: Array = MAT["leather"]
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(9, 9), Vector2(27, 9), Vector2(27, 25), Vector2(9, 25)])), t)
	_bevel(img, _mask_ellipse(Vector2(8, 17), 4.0, 8.5), [t[0], t[1], t[3], t[4], t[4]])
	_line(img, Vector2(8, 10), Vector2(8, 24), t[1])
	for x in range(12, 26, 3):
		_px(img, x, 11, t[4])
		_px(img, x, 23, t[4])
	_outline(img, C.outline)
	return img


func _ic_coal() -> Image:
	var img := _new_image(T, T)
	var t: Array = MAT["coal"]
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(5, 18), Vector2(9, 10), Vector2(17, 7), Vector2(25, 11), Vector2(27, 20), Vector2(20, 26), Vector2(10, 25)])), t)
	_line(img, Vector2(11, 13), Vector2(16, 18), t[1])
	_line(img, Vector2(16, 18), Vector2(24, 16), t[3])
	for p in [Vector2i(12, 11), Vector2i(20, 12), Vector2i(14, 21), Vector2i(22, 20)]:
		_px(img, p.x, p.y, t[4])
	_outline(img, C.outline)
	return img


# ---------------------------------------------------------------- stations & food

const HIDE5 := [Color8(80, 50, 34), Color8(124, 84, 56), Color8(168, 118, 78), Color8(200, 154, 106), Color8(226, 190, 140)]
const CAP5 := [Color8(72, 36, 28), Color8(124, 58, 38), Color8(172, 88, 52), Color8(212, 134, 86), Color8(240, 192, 146)]
const RAW5 := [Color8(90, 20, 28), Color8(150, 36, 44), Color8(200, 70, 72), Color8(232, 120, 116), Color8(250, 190, 180)]
const COOK5 := [Color8(70, 36, 22), Color8(118, 62, 34), Color8(160, 94, 50), Color8(196, 132, 72), Color8(230, 180, 110)]
const LEAF5 := [Color8(30, 70, 40), Color8(40, 90, 46), Color8(62, 122, 54), Color8(100, 162, 68), Color8(150, 198, 96)]


## Blacksmith's anvil on a tree stump, hammer resting on top.
func _st_anvil() -> Image:
	var img := _new_image(T, T)
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(9, 21), Vector2(23, 21), Vector2(25, 31), Vector2(7, 31)])), WOOD5)
	for y in [24, 28]:
		_line(img, Vector2(10, y), Vector2(22, y), WOOD5[1])
	var body := _mask_poly(PackedVector2Array([
		Vector2(1, 9), Vector2(27, 9), Vector2(27, 14), Vector2(21, 15), Vector2(20, 18),
		Vector2(24, 22), Vector2(8, 22), Vector2(12, 18), Vector2(11, 15), Vector2(6, 14)]))
	_bevel(img, body, MAT["iron"])
	_line(img, Vector2(3, 10), Vector2(26, 10), MAT["iron"][4])
	_line(img, Vector2(12, 21), Vector2(21, 21), MAT["iron"][0])
	_bevel(img, _mask_stroke(Vector2(14, 7.5), Vector2(28, 3.5), 1.2), WOOD5)
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(10, 3), Vector2(16, 3), Vector2(16, 9), Vector2(10, 9)])), MAT["iron"])
	_outline(img, C.outline)
	return img


## Iron cauldron over a small fire, bubbling stew and steam.
func _st_cooking_pot() -> Image:
	var img := _new_image(T, T)
	for l in [[Vector2(5, 29), Vector2(15, 26)], [Vector2(27, 29), Vector2(17, 26)]]:
		_bevel(img, _mask_stroke(l[0], l[1], 1.4), WOOD5)
	_rect(img, 12, 25, 8, 4, C.fire_out)
	_rect(img, 13, 24, 6, 3, C.fire_mid)
	_rect(img, 15, 24, 2, 2, C.fire_core)
	var pot := _mask_cut(_mask_ellipse(Vector2(16, 17), 11, 9), _mask_fn(func(p: Vector2) -> bool: return p.y < 12.0))
	_bevel(img, pot, [Color8(28, 28, 34), Color8(44, 46, 54), Color8(66, 70, 80), Color8(98, 104, 116), Color8(140, 148, 160)])
	_bevel(img, _mask_ellipse(Vector2(16, 12), 12, 3.2), MAT["iron"])
	var soup := _mask_ellipse(Vector2(16, 12), 9, 1.8)
	for p in soup:
		_px(img, p.x, p.y, COOK5[3] if p.y < 12 else COOK5[2])
	for b in [Vector2i(12, 12), Vector2i(19, 11), Vector2i(16, 13)]:
		_px(img, b.x, b.y, COOK5[4])
	for s in [[11, 7], [16, 4], [21, 6]]:
		_px(img, s[0], s[1], Color(1, 1, 1, 0.55))
		_px(img, s[0] + 1, s[1] - 1, Color(1, 1, 1, 0.4))
		_px(img, s[0], s[1] - 2, Color(1, 1, 1, 0.3))
	_outline(img, C.outline)
	return img


## Wooden frame with a hide laced inside to cure.
func _st_tanning_rack() -> Image:
	var img := _new_image(T, T)
	var hide := _mask_poly(PackedVector2Array([
		Vector2(9, 8), Vector2(16, 9), Vector2(23, 8), Vector2(24, 15), Vector2(23, 23),
		Vector2(16, 22), Vector2(9, 23), Vector2(8, 15)]))
	for l in [[Vector2(6, 9), Vector2(9, 9)], [Vector2(26, 9), Vector2(23, 9)], [Vector2(6, 22), Vector2(9, 22)],
			[Vector2(26, 22), Vector2(23, 22)], [Vector2(16, 6), Vector2(16, 9)], [Vector2(6, 15), Vector2(8, 15)], [Vector2(26, 15), Vector2(24, 15)]]:
		_line(img, l[0], l[1], Color8(206, 180, 120))
	for x in [5.5, 26.5]:
		_bevel(img, _mask_stroke(Vector2(x, 3), Vector2(x, 30), 1.6), WOOD5)
	for y in [5.5, 24.5]:
		_bevel(img, _mask_stroke(Vector2(3, y), Vector2(29, y), 1.4), WOOD5)
	_bevel(img, hide, HIDE5)
	for p in hide:
		if _hash(p.x, p.y, 917) > 0.9:
			_px(img, p.x, p.y, HIDE5[1])
	_outline(img, C.outline)
	return img


## Stone bench with a toothed saw wheel and a fresh-cut block.
func _st_stonecutter() -> Image:
	var img := _new_image(T, T)
	for x in [5, 22]:
		_bevel(img, _mask_poly(PackedVector2Array([Vector2(x, 17), Vector2(x + 6, 17), Vector2(x + 6, 31), Vector2(x, 31)])), MAT["stone"])
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(2, 14), Vector2(30, 14), Vector2(30, 19), Vector2(2, 19)])), WOOD5)
	var blade := _mask_ellipse(Vector2(13, 9), 7.5, 7.5)
	_bevel(img, blade, MAT["iron"])
	for i in 12:
		var a := TAU * i / 12.0
		_px(img, int(13 + cos(a) * 8.2), int(9 + sin(a) * 8.2), MAT["iron"][3])
	for p in _mask_ellipse(Vector2(13, 9), 2.2, 2.2):
		_px(img, p.x, p.y, MAT["iron"][0])
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(21, 7), Vector2(29, 7), Vector2(29, 14), Vector2(21, 14)])), MAT["stone"])
	_outline(img, C.outline)
	return img


func _mushroom(img: Image, cx: float, base_y: float, s: float) -> void:
	_bevel(img, _mask_stroke(Vector2(cx, base_y), Vector2(cx, base_y - 4.0 * s), 1.3 * s), MAT["bone"])
	var cap := _mask_cut(_mask_ellipse(Vector2(cx, base_y - 4.0 * s), 4.2 * s, 3.0 * s),
		_mask_fn(func(p: Vector2) -> bool: return p.y > base_y - 4.0 * s + 0.6 * s))
	_bevel(img, cap, CAP5)
	for d in [Vector2(-1.6, -1.6), Vector2(1.4, -2.2), Vector2(2.6, -0.6)]:
		_px(img, int(cx + d.x * s), int(base_y - 4.0 * s + d.y * s), CAP5[4])


## Mushroom cluster growing on the ground (resource node).
func _make_mushrooms() -> Image:
	var img := _new_image(T, T)
	_mushroom(img, 11, 27, 1.5)
	_mushroom(img, 20, 28, 1.9)
	_mushroom(img, 15, 29, 1.0)
	for x in [7, 9, 24, 26]:
		_line(img, Vector2(x, 29), Vector2(x + 1, 25), LEAF5[2 + x % 2])
	_outline(img, C.outline)
	return img


func _ic_mushroom() -> Image:
	var img := _new_image(T, T)
	_mushroom(img, 12, 26, 1.5)
	_mushroom(img, 19, 28, 2.2)
	_outline(img, C.outline)
	return img


func _ic_raw_meat() -> Image:
	var img := _new_image(T, T)
	var meat := _mask_poly(PackedVector2Array([Vector2(4, 13), Vector2(12, 7), Vector2(23, 8), Vector2(27, 15), Vector2(23, 24), Vector2(11, 26), Vector2(5, 21)]))
	_bevel(img, meat, RAW5)
	_line(img, Vector2(8, 14), Vector2(20, 11), RAW5[4])
	_line(img, Vector2(9, 20), Vector2(22, 18), RAW5[3])
	_bevel(img, _mask_ellipse(Vector2(18, 16), 2.6, 2.6), MAT["bone"])
	_outline(img, C.outline)
	return img


func _ic_cooked_meat() -> Image:
	var img := _new_image(T, T)
	_bevel(img, _mask_stroke(Vector2(17, 17), Vector2(26, 26), 1.6), MAT["bone"])
	_bevel(img, _mask_add(_mask_ellipse(Vector2(25, 28), 2, 2), _mask_ellipse(Vector2(28, 25), 2, 2)), MAT["bone"])
	_bevel(img, _mask_ellipse(Vector2(13, 13), 9, 8), COOK5)
	for p in [Vector2i(9, 10), Vector2i(14, 8), Vector2i(10, 15), Vector2i(16, 13)]:
		_px(img, p.x, p.y, COOK5[4])
	_outline(img, C.outline)
	return img


func _ic_roasted_mushroom() -> Image:
	var img := _new_image(T, T)
	_handle(img, Vector2(4.5, 28.5), Vector2(27.5, 5.5))
	for c in [Vector2(10, 22), Vector2(16, 16), Vector2(22, 10)]:
		_bevel(img, _mask_ellipse(c + Vector2(1, 2), 2.2, 2.2), MAT["bone"])
		_bevel(img, _mask_ellipse(c, 5, 3.6), [COOK5[0], CAP5[1], CAP5[2], CAP5[3], CAP5[4]])
		_px(img, int(c.x) - 2, int(c.y) - 1, COOK5[0])
		_px(img, int(c.x) + 1, int(c.y), COOK5[0])
	_outline(img, C.outline)
	return img


## Wooden bowl of food: surface tones, coloured chunks and optional steam.
func _ic_bowl(surface: Array, bits: Array, hot: bool) -> Image:
	var img := _new_image(T, T)
	var bowl := _mask_cut(_mask_ellipse(Vector2(16, 18), 13, 10), _mask_fn(func(p: Vector2) -> bool: return p.y < 17.0))
	_bevel(img, bowl, WOOD5)
	_rect(img, 11, 28, 10, 2, WOOD5[1])
	_bevel(img, _mask_ellipse(Vector2(16, 17), 13, 4), WOOD5)
	var top := _mask_ellipse(Vector2(16, 17), 10.5, 2.6)
	for p in top:
		_px(img, p.x, p.y, surface[1] if p.y >= 17 else surface[0])
	for i in 7:
		var x := 9 + int(_hash(i, 1, 940) * 14.0)
		var y := 15 + int(_hash(i, 2, 940) * 4.0)
		if top.has(Vector2i(x, y)) and top.has(Vector2i(x + 1, y)):
			_rect(img, x, y, 2, 1, bits[i % bits.size()])
	if hot:
		for s in [[11, 10], [16, 7], [21, 9]]:
			_px(img, s[0], s[1], Color(1, 1, 1, 0.6))
			_px(img, s[0] + 1, s[1] - 2, Color(1, 1, 1, 0.45))
			_px(img, s[0], s[1] - 4, Color(1, 1, 1, 0.3))
	_outline(img, C.outline)
	return img
