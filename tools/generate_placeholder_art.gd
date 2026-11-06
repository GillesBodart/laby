extends SceneTree
## Generates the placeholder pixel-art used during early milestones.
## Every PNG follows the final layout (sizes, atlas coords, frame grids),
## so real art can replace them later without touching gameplay code.
##
## Run from the project root:
##   godot --headless --path . --script res://tools/generate_placeholder_art.gd

const Catalog := preload("res://scripts/world/tile_catalog.gd")
const T := 16

# Shared palette (Clearing / Stone biome). Keep per-biome palettes small.
const C := {
	"outline": Color8(27, 26, 36),
	"void": Color8(16, 18, 24),
	"grass": Color8(78, 138, 58),
	"grass_dark": Color8(58, 108, 46),
	"grass_light": Color8(112, 170, 76),
	"flower_y": Color8(242, 210, 92),
	"flower_w": Color8(236, 232, 214),
	"dirt": Color8(138, 106, 68),
	"dirt_dark": Color8(106, 80, 51),
	"dirt_light": Color8(166, 130, 86),
	"stone": Color8(66, 76, 74),
	"stone_dark": Color8(45, 52, 52),
	"stone_light": Color8(84, 95, 91),
	"wall_top": Color8(128, 142, 132),
	"wall_top_light": Color8(162, 174, 160),
	"wall_top_dark": Color8(98, 112, 104),
	"wall_face": Color8(72, 85, 81),
	"wall_face_dark": Color8(48, 58, 56),
	"wall_face_light": Color8(96, 110, 104),
	"wall_base": Color8(33, 40, 40),
	"moss": Color8(79, 118, 58),
	"moss_light": Color8(108, 150, 72),
	"vine": Color8(52, 98, 46),
	"vine_light": Color8(92, 143, 61),
	"wood": Color8(107, 74, 47),
	"wood_dark": Color8(74, 52, 38),
	"wood_light": Color8(140, 100, 64),
	"iron": Color8(93, 97, 104),
	"iron_light": Color8(140, 146, 152),
	"leaf": Color8(60, 120, 52),
	"leaf_dark": Color8(38, 84, 42),
	"leaf_light": Color8(102, 160, 70),
	"leaf_hi": Color8(150, 196, 96),
	"bark": Color8(96, 66, 44),
	"bark_dark": Color8(66, 45, 32),
	"rock": Color8(128, 132, 128),
	"rock_dark": Color8(86, 90, 90),
	"rock_light": Color8(170, 172, 164),
	"fire_core": Color8(255, 236, 140),
	"fire_mid": Color8(245, 154, 58),
	"fire_out": Color8(200, 67, 43),
	"sun": Color8(255, 214, 92),
	"moon": Color8(214, 222, 240),
}

# Character palette (pattern keys).
const P := {
	".": Color(0, 0, 0, 0),
	"o": Color8(27, 26, 36),
	"h": Color8(107, 62, 38),
	"H": Color8(74, 42, 28),
	"s": Color8(240, 192, 154),
	"S": Color8(201, 141, 108),
	"e": Color8(27, 26, 36),
	"t": Color8(79, 122, 58),
	"T": Color8(53, 82, 38),
	"p": Color8(110, 90, 64),
	"b": Color8(58, 44, 34),
}

var rng := RandomNumberGenerator.new()


func _init() -> void:
	for dir in ["res://assets/tilesets", "res://assets/sprites", "res://assets/ui"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save(_make_tileset(), Catalog.TEXTURE_PATH)
	_save(_make_player(), "res://assets/sprites/player.png")
	_save(_make_tree(), "res://assets/sprites/tree.png")
	_save(_make_rock(), "res://assets/sprites/rock.png")
	_save(_make_campfire(), "res://assets/sprites/campfire.png")
	_save(_make_shadow(), "res://assets/sprites/shadow.png")
	_save(_make_time_icons(), "res://assets/ui/time_icons.png")
	print("Placeholder art generated.")
	quit()


func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save %s (%d)" % [path, err])


func _new_image(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


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


func _speckle(img: Image, color: Color, count: int) -> void:
	for i in count:
		img.set_pixel(rng.randi_range(0, T - 1), rng.randi_range(0, T - 1), color)


func _paint_grass(img: Image, variant: int) -> void:
	img.fill(C.grass_dark if variant == 1 else C.grass)
	_speckle(img, C.grass if variant == 1 else C.grass_dark, 34)
	for i in 14:
		var x := rng.randi_range(0, T - 1)
		var y := rng.randi_range(0, T - 2)
		img.set_pixel(x, y, C.grass_light)
		img.set_pixel(x, y + 1, C.grass_dark)
	if variant == 2:
		for i in 4:
			var x := rng.randi_range(1, T - 2)
			var y := rng.randi_range(1, T - 2)
			var col: Color = C.flower_y if i % 2 == 0 else C.flower_w
			img.set_pixel(x, y, col)
			img.set_pixel(x, y + 1, C.grass_dark)


func _paint_dirt(img: Image) -> void:
	img.fill(C.dirt)
	_speckle(img, C.dirt_dark, 26)
	_speckle(img, C.dirt_light, 12)
	for i in 3:
		var x := rng.randi_range(0, T - 3)
		var y := rng.randi_range(0, T - 2)
		img.set_pixel(x, y, C.dirt_light)
		img.set_pixel(x + 1, y, C.dirt_light)
		img.set_pixel(x, y + 1, C.dirt_dark)
		img.set_pixel(x + 1, y + 1, C.dirt_dark)


func _paint_floor(img: Image, moss: bool) -> void:
	img.fill(C.stone)
	_speckle(img, C.stone_dark, 10)
	for x in T:
		img.set_pixel(x, 7, C.stone_dark)
		img.set_pixel(x, 15, C.stone_dark)
		img.set_pixel(x, 0, C.stone_light)
		img.set_pixel(x, 8, C.stone_light)
	for y in range(0, 7):
		img.set_pixel(15, y, C.stone_dark)
	for y in range(8, 15):
		img.set_pixel(7, y, C.stone_dark)
	if moss:
		for i in 3:
			var cx := rng.randi_range(2, 13)
			var cy := rng.randi_range(2, 13)
			for j in 6:
				var x := clampi(cx + rng.randi_range(-2, 2), 0, T - 1)
				var y := clampi(cy + rng.randi_range(-1, 1), 0, T - 1)
				img.set_pixel(x, y, C.moss_light if j == 0 else C.moss)


func _paint_void(img: Image) -> void:
	img.fill(C.void)
	_speckle(img, C.outline, 6)


func _paint_gate_floor(img: Image) -> void:
	_paint_floor(img, false)
	for x in range(3, 13):
		for y in range(6, 10):
			img.set_pixel(x, y, C.iron if (y == 6 or y == 9) else C.wall_base)
	for x in [4, 11]:
		img.set_pixel(x, 7, C.iron_light)


func _paint_wall_top(img: Image, moss: bool) -> void:
	img.fill(C.wall_top)
	_speckle(img, C.wall_top_dark, 8)
	for x in T:
		img.set_pixel(x, 7, C.wall_top_dark)
		img.set_pixel(x, 15, C.wall_top_dark)
		img.set_pixel(x, 8, C.wall_top_light)
		img.set_pixel(x, 0, C.wall_top_light)
	for y in range(0, 7):
		img.set_pixel(11, y, C.wall_top_dark)
	for y in range(8, 15):
		img.set_pixel(4, y, C.wall_top_dark)
	if moss:
		for i in 4:
			var cx := rng.randi_range(1, 14)
			var cy := rng.randi_range(1, 14)
			for j in 7:
				var x := clampi(cx + rng.randi_range(-2, 2), 0, T - 1)
				var y := clampi(cy + rng.randi_range(-1, 1), 0, T - 1)
				img.set_pixel(x, y, C.moss_light if j < 2 else C.moss)


func _paint_wall_face(img: Image, low: bool, vines: bool) -> void:
	img.fill(C.wall_face)
	_speckle(img, C.wall_face_dark, 10)
	for x in T:
		img.set_pixel(x, 7, C.wall_face_dark)
		img.set_pixel(x, 8, C.wall_face_light)
	for y in range(0, 7):
		img.set_pixel(5, y, C.wall_face_dark)
		img.set_pixel(6, y, C.wall_face_light)
	for y in range(9, 16):
		img.set_pixel(12, y, C.wall_face_dark)
		img.set_pixel(13, y, C.wall_face_light)
	if low:
		for x in T:
			img.set_pixel(x, 13, C.wall_face_dark)
			img.set_pixel(x, 14, C.wall_base)
			img.set_pixel(x, 15, C.wall_base)
	if vines:
		for vx in [2, 9]:
			var length := rng.randi_range(9, 16)
			for y in length:
				var x: int = vx + (1 if (y / 3) % 2 == 0 else 0)
				img.set_pixel(x, y, C.vine)
				if y % 3 == 1:
					img.set_pixel(x + 1, y, C.vine_light)
					img.set_pixel(x - 1, y, C.vine_light)


func _paint_gate_closed(img: Image) -> void:
	img.fill(C.wood)
	for x in T:
		for y in T:
			if x % 4 == 0:
				img.set_pixel(x, y, C.wood_dark)
			elif x % 4 == 1:
				img.set_pixel(x, y, C.wood_light)
	for band_y in [3, 12]:
		for x in T:
			img.set_pixel(x, band_y, C.iron)
			img.set_pixel(x, band_y + 1, C.wall_base)
		for x in [2, 7, 13]:
			img.set_pixel(x, band_y, C.iron_light)
	for x in T:
		img.set_pixel(x, 15, C.wall_base)


# ---------------------------------------------------------------- characters

const PLAYER_HEAD_DOWN := [
	"................",
	".....oooooo.....",
	"....ohhhhhho....",
	"...ohhhhhhhho...",
	"...ohhhhhhhho...",
	"...ohssssssho...",
	"...ossessesso...",
	"...osssssssso...",
	"....oSSSSSSo....",
]
const PLAYER_HEAD_UP := [
	"................",
	".....oooooo.....",
	"....ohhhhhho....",
	"...ohhhhhhhho...",
	"...ohhhhhhhho...",
	"...ohhhhhhhho...",
	"...ohhHhhHhho...",
	"...ohhhhhhhho...",
	"....oSSSSSSo....",
]
const PLAYER_HEAD_SIDE := [
	"................",
	".....oooooo.....",
	"....ohhhhhho....",
	"...ohhhhhhhho...",
	"...ohhhhhhhho...",
	"...ohhhhsssso...",
	"...ohhhsssesoo..",
	"...ohhsssssso...",
	"....oSSSSSSo....",
]
const PLAYER_BODY := [
	"...otttttttto...",
	"..osttTttTttso..",
	"..osttttttttso..",
	"...oTTTTTTTTo...",
	"....oppppppo....",
]
const PLAYER_LEGS_FRONT := [
	["....opo..opo....", "....obb..bbo...."],
	["....obb..opo....", ".........bbo...."],
	["....opo..bbo....", "....obb........."],
]
const PLAYER_LEGS_SIDE := [
	[".....opppo......", ".....obbbbo....."],
	["....opo.opo.....", "...obo...obo...."],
	[".....oppo.......", ".....obbo......."],
]


func _make_player() -> Image:
	# 3 columns (idle, step A, step B) x 3 rows (down, up, side-right).
	var img := _new_image(T * 3, T * 3)
	var heads := [PLAYER_HEAD_DOWN, PLAYER_HEAD_UP, PLAYER_HEAD_SIDE]
	for row in 3:
		var legs: Array = PLAYER_LEGS_SIDE if row == 2 else PLAYER_LEGS_FRONT
		for col in 3:
			var pattern: Array = []
			pattern.append_array(heads[row])
			pattern.append_array(PLAYER_BODY)
			pattern.append_array(legs[col])
			# Bob the upper body one pixel on step frames.
			var bob := 1 if col != 0 else 0
			_blit_pattern(img, pattern, Vector2i(col * T, row * T), bob)
	return img


func _blit_pattern(img: Image, pattern: Array, origin: Vector2i, bob := 0) -> void:
	for y in pattern.size():
		var line: String = pattern[y]
		var dy := y + (bob if y < 14 else 0)
		if dy >= T:
			continue
		for x in mini(line.length(), T):
			var key := line[x]
			if key != ".":
				img.set_pixel(origin.x + x, origin.y + dy, P[key])


# ---------------------------------------------------------------- props

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


func _make_tree() -> Image:
	var img := _new_image(32, 40)
	rng.seed = 42
	# Trunk with roots.
	for y in range(24, 38):
		for x in range(13, 19):
			var col: Color = C.bark
			if x == 13 or (x == 16 and y % 4 == 0):
				col = C.bark_dark
			elif x == 17:
				col = C.bark_dark
			img.set_pixel(x, y, col)
	for p in [Vector2i(12, 37), Vector2i(11, 37), Vector2i(19, 37), Vector2i(20, 37), Vector2i(12, 36), Vector2i(19, 36)]:
		img.set_pixel(p.x, p.y, C.bark_dark)
	# Canopy: irregular blob lit from top-left.
	var center := Vector2(16, 14)
	for y in range(0, 30):
		for x in range(1, 31):
			var d := Vector2(x, y) - center
			var ang := d.angle()
			var radius := 13.0 + 1.6 * sin(ang * 5.0) + 0.8 * cos(ang * 9.0)
			if d.length() > radius:
				continue
			var shade := (d.x + d.y) / radius
			var col: Color = C.leaf
			if shade < -0.55:
				col = C.leaf_light
			elif shade > 0.45:
				col = C.leaf_dark
			if d.length() > radius - 1.5 and d.y > 0:
				col = C.leaf_dark
			img.set_pixel(x, y, col)
	# Leaf clusters.
	for i in 26:
		var p := center + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 9))
		var px := int(p.x)
		var py := int(p.y)
		if img.get_pixel(px, py).a == 0.0:
			continue
		var lit := (p - center).x + (p - center).y < 0
		img.set_pixel(px, py, C.leaf_hi if lit else C.leaf_light)
		if py + 1 < 40 and img.get_pixel(px, py + 1).a > 0.0:
			img.set_pixel(px, py + 1, C.leaf_dark)
	_outline(img, C.outline)
	return img


func _make_rock() -> Image:
	var img := _new_image(T, T)
	var center := Vector2(7.5, 9.5)
	for y in T:
		for x in T:
			var d := Vector2(x, y) - center
			if (d.x * d.x) / 36.0 + (d.y * d.y) / 20.0 > 1.0:
				continue
			var col: Color = C.rock
			if d.y < -2 or (d.x < -3 and d.y < 0):
				col = C.rock_light
			elif d.y > 2:
				col = C.rock_dark
			img.set_pixel(x, y, col)
	for p in [Vector2i(8, 8), Vector2i(9, 9), Vector2i(9, 10)]:
		img.set_pixel(p.x, p.y, C.rock_dark)
	img.set_pixel(5, 7, C.moss_light)
	img.set_pixel(6, 7, C.moss)
	_outline(img, C.outline)
	return img


func _make_campfire() -> Image:
	var img := _new_image(T * 3, T)
	for frame in 3:
		var o := Vector2i(frame * T, 0)
		rng.seed = 77 + frame
		# Stones ring.
		for p in [Vector2i(3, 13), Vector2i(5, 14), Vector2i(8, 14), Vector2i(11, 14), Vector2i(12, 12), Vector2i(3, 11)]:
			img.set_pixel(o.x + p.x, o.y + p.y, C.rock)
			img.set_pixel(o.x + p.x + 1, o.y + p.y, C.rock_dark)
		# Crossed logs.
		for i in 8:
			img.set_pixel(o.x + 4 + i, o.y + 10 + i / 4, C.wood)
			img.set_pixel(o.x + 11 - i, o.y + 10 + i / 4, C.wood_light)
		# Flame.
		for x in range(5, 11):
			var h := 7 - absi(x - 8) * 2 + rng.randi_range(-1, 1)
			for y in range(maxi(h, 0)):
				var py := 10 - y
				var col: Color = C.fire_out
				if y < h - 2 and absi(x - 8) <= 1:
					col = C.fire_core
				elif y < h - 1:
					col = C.fire_mid
				img.set_pixel(o.x + x, o.y + py, col)
		var spark := Vector2i(rng.randi_range(5, 10), rng.randi_range(0, 2))
		img.set_pixel(o.x + spark.x, o.y + spark.y, C.fire_core)
	return img


func _make_shadow() -> Image:
	var img := _new_image(T, 6)
	var shadow := Color(0, 0, 0, 0.35)
	for y in 6:
		for x in T:
			var d := Vector2((x - 7.5) / 7.5, (y - 2.5) / 2.8)
			if d.length_squared() <= 1.0:
				img.set_pixel(x, y, shadow)
	return img


func _make_time_icons() -> Image:
	# 2 frames of 9x9: sun, moon.
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
