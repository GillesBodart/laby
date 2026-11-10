extends SceneTree
## Generates the game's pixel art procedurally (32px tiles, detailed shading).
## Every PNG follows the final layout (sizes, atlas coords, frame grids),
## so hand-painted art can replace them later without touching gameplay code.
##
## Run from the project root, then refresh the import cache:
##   godot --headless --path . --script res://tools/generate_placeholder_art.gd
##   godot --headless --path . --editor --quit

const Catalog := preload("res://scripts/data/tile_catalog.gd")
const T := 32
const VARIANTS := 10
const STRUCTURES := ["workbench", "chest", "wooden_wall", "wooden_floor", "wooden_door_closed", "wooden_door_open", "furnace",
	"stone_wall", "brick_wall", "stone_floor", "farm_plot_0", "farm_plot_1", "farm_plot_2", "anvil", "cooking_pot", "tanning_rack", "stonecutter"]

const C := {
	"outline": Color8(24, 22, 32),
	"void": Color8(14, 16, 22),
	"grass": Color8(100, 160, 68),
	"grass_dark": Color8(84, 144, 62),
	"grass_deep": Color8(54, 106, 50),
	"grass_light": Color8(132, 184, 84),
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
## Palette the character routines draw with: C, or C with a survivor's colours.
var P: Dictionary = C.duplicate()


func _init() -> void:
	if "--ui" in OS.get_cmdline_user_args():
		_save(_make_ui_frame(), "res://assets/ui/frame.png")
		print("UI frame generated.")
		quit()
		return
	if "--tiles" in OS.get_cmdline_user_args():
		_save(_make_tileset(), Catalog.TEXTURE_PATH)
		print("Tileset generated.")
		quit()
		return
	if "--roof" in OS.get_cmdline_user_args():
		_save(_make_roof(), "res://assets/sprites/structures/roof.png")
		print("Roof generated.")
		quit()
		return
	if "--walls" in OS.get_cmdline_user_args():
		_make_wall_joins()
		print("Wall joins generated.")
		quit()
		return
	if "--structures" in OS.get_cmdline_user_args():
		for s in STRUCTURES:
			_save(_make_structure(s), "res://assets/sprites/structures/%s.png" % s)
		_make_wall_joins()
		print("Structures generated.")
		quit()
		return
	if "--chars" in OS.get_cmdline_user_args():
		_save(_make_player(), "res://assets/sprites/characters/player.png")
		_make_npcs()
		print("Characters generated.")
		quit()
		return
	if "--npcs" in OS.get_cmdline_user_args():
		_make_npcs()
		print("Survivors generated.")
		quit()
		return
	if "--creatures" in OS.get_cmdline_user_args():
		_import_creatures()
		print("Creatures generated.")
		quit()
		return
	for dir in ["res://assets/tilesets", "res://assets/sprites/characters", "res://assets/sprites/effects", "res://assets/sprites/environment/trees", "res://assets/sprites/environment/rocks", "res://assets/sprites/environment/gatherables", "res://assets/sprites/structures", "res://assets/ui", "res://assets/ui/icons/items/small", "res://assets/sprites/enemies"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save(_make_tileset(), Catalog.TEXTURE_PATH)
	_save(_make_player(), "res://assets/sprites/characters/player.png")
	_make_npcs()
	for v in VARIANTS:
		_save(_make_tree(v), "res://assets/sprites/environment/trees/tree_%d.png" % v)
		_save(_make_rock(v), "res://assets/sprites/environment/rocks/rock_%d.png" % v)
	_save(_make_tree(0), "res://assets/sprites/environment/tree.png")
	_save(_make_rock(0), "res://assets/sprites/environment/rock.png")
	_save(_make_campfire(), "res://assets/sprites/environment/campfire.png")
	for s in STRUCTURES:
		_save(_make_structure(s), "res://assets/sprites/structures/%s.png" % s)
	_make_wall_joins()
	_save(_make_roof(), "res://assets/sprites/structures/roof.png")
	_save(_make_shadow(), "res://assets/sprites/effects/shadow.png")
	_save(_make_time_icons(), "res://assets/ui/icons/time_icons.png")
	_save(_make_ui_frame(), "res://assets/ui/frame.png")
	_make_item_icons()
	_save(_make_bush(), "res://assets/sprites/environment/bush.png")
	_save(_make_grass_tuft(), "res://assets/sprites/environment/gatherables/grass.png")
	_save(_make_clay(), "res://assets/sprites/environment/gatherables/clay.png")
	_save(_make_mushrooms(), "res://assets/sprites/environment/gatherables/mushroom.png")
	_save(_make_ore([Color8(20, 20, 26), Color8(52, 52, 60), Color8(80, 80, 92)], 1), "res://assets/sprites/environment/gatherables/ore_coal.png")
	_save(_make_ore([MAT["copper"][2], MAT["copper"][3], Color8(80, 170, 120)], 2), "res://assets/sprites/environment/gatherables/ore_copper.png")
	_save(_make_ore([Color8(196, 160, 140), Color8(150, 110, 96), Color8(220, 190, 170)], 3), "res://assets/sprites/environment/gatherables/ore_iron.png")
	_save(_make_ore([MAT["crystal"][2], MAT["crystal"][3], MAT["crystal"][4]], 4), "res://assets/sprites/environment/gatherables/ore_crystal.png")
	_make_biome_art()
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
	if color == C.outline:
		_ink(img)
		return
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


## Mask over the whole canvas of `img`, whatever its size.
func _mk(img: Image, test: Callable) -> Dictionary:
	var m := {}
	for y in img.get_height():
		for x in img.get_width():
			if test.call(Vector2(x + 0.5, y + 0.5)):
				m[Vector2i(x, y)] = true
	return m


## Raises (k > 0) or lowers a pixel along a tone ramp, if it is on that ramp.
func _tone_shift(img: Image, x: int, y: int, tones: Array, k: int) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var i := tones.find(img.get_pixel(x, y))
	if i >= 0:
		img.set_pixel(x, y, tones[clampi(i + k, 0, tones.size() - 1)])


## Leaf tufts filling an elliptical crown: a staggered grid inside plus a
## ring of tufts along the edge that gives the scalloped silhouette.
func _crown_tufts(c: Vector2, rx: float, ry: float, r: float, seed: int) -> Array:
	var tufts: Array = []
	var step := r * 1.05
	var row := 0
	var y := c.y - ry + r * 0.6
	while y <= c.y + ry - r * 0.4:
		var x := c.x - rx + r * 0.6 + (step * 0.5 if row % 2 else 0.0)
		while x <= c.x + rx - r * 0.4:
			var q := Vector2((x - c.x) / maxf(rx - r * 0.7, 1.0), (y - c.y) / maxf(ry - r * 0.7, 1.0))
			if q.length() <= 1.0:
				var j := Vector2(_hash(int(x), int(y), seed) - 0.5, _hash(int(y), int(x), seed) - 0.5) * r * 0.5
				tufts.append(Vector3(x + j.x, y + j.y, r * (0.85 + _hash(int(x), row, seed + 1) * 0.3)))
			x += step
		y += step * 0.86
		row += 1
	var n := int(TAU * (rx + ry) * 0.5 / (r * 1.1))
	for i in n:
		var a := TAU * i / n + _hash(i, 3, seed) * 0.3
		tufts.append(Vector3(c.x + cos(a) * (rx - r * 0.75), c.y + sin(a) * (ry - r * 0.75), r * (0.8 + _hash(i, 4, seed) * 0.3)))
	return tufts


## Foliage made of rounded leaf tufts, the crown of a classic 16-bit RPG tree.
## Each tuft is lit as a small sphere and as part of the whole crown (`dome`:
## centre x, y and radii), its lower rim shaded where it overlaps the tuft
## behind, and a few bright leaf glints on its sunny side.
## tufts: Vector3(x, y, r). tones: 5, dark -> light.
func _foliage(img: Image, tufts: Array, dome: Vector4, tones: Array, seed: int) -> void:
	var light := Vector3(-0.55, -0.72, 0.42).normalized()
	tufts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	for i in tufts.size():
		var c: Vector3 = tufts[i]
		var ph := _hash(i, 7, seed) * TAU
		for y in range(int(c.y - c.z) - 2, int(c.y + c.z) + 3):
			for x in range(int(c.x - c.z) - 2, int(c.x + c.z) + 3):
				var lx := (x + 0.5 - c.x) / c.z
				var ly := (y + 0.5 - c.y) / c.z
				var edge := 1.0 + 0.13 * sin(atan2(ly, lx) * 6.0 + ph)
				var d := (lx * lx + ly * ly) / (edge * edge)
				if d > 1.0:
					continue
				var nl := Vector3(lx / edge, ly / edge, sqrt(1.0 - d))
				var gx := (x + 0.5 - dome.x) / dome.z
				var gy := (y + 0.5 - dome.y) / dome.w
				var ng := Vector3(gx, gy, sqrt(maxf(0.0, 1.0 - minf(gx * gx + gy * gy, 1.0)))).normalized()
				var lit := nl.dot(light) * 0.95 + ng.dot(light) * 0.6 + (_hash(x, y, seed) - 0.5) * 0.06
				var t := clampi(int((lit + 0.55) / 1.6 * 5.0), 0, 4)
				if d > 0.62 and lx + ly * 1.4 > 0.6:
					t = maxi(t - 1, 0)
				if d > 0.8 and ly > 0.15:
					t = maxi(t - 1, 0)
				if d > 0.92 and ly > 0.35:
					t = 0
				_px(img, x, y, tones[t])
		for k in 4:
			var a := -2.4 + _hash(i, k, seed + 3) * 1.7
			var rr := c.z * (0.2 + _hash(i, k, seed + 4) * 0.45)
			var px := int(c.x + cos(a) * rr)
			var py := int(c.y + sin(a) * rr)
			_tone_shift(img, px, py, tones, 1)
			_tone_shift(img, px + 1, py, tones, 1)
			_tone_shift(img, px, py + 1, tones, -1)
			_tone_shift(img, px + 1, py + 1, tones, -1)


## Cylinder-shaded bark: light on the left, deep on the right, wavy grooves.
func _bark(img: Image, mask: Dictionary, axis_x: Callable, half_w: Callable, tones: Array, seed: int) -> void:
	for p: Vector2i in mask:
		var hw: float = half_w.call(float(p.y))
		var u := clampf((p.x + 0.5 - float(axis_x.call(float(p.y))) + hw) / (hw * 2.0), 0.0, 1.0)
		var t := 3 if u < 0.22 else (2 if u < 0.55 else (1 if u < 0.85 else 0))
		var groove := sin((p.x - float(axis_x.call(float(p.y)))) * 1.25 + sin(p.y * 0.3 + seed) * 1.4)
		if groove > 0.8 and t > 0:
			t -= 1
		elif groove < -0.85 and u < 0.5 and _hash(p.x, p.y, seed) > 0.4:
			t = mini(t + 1, 4)
		_px(img, p.x, p.y, tones[t])


const TREE_CROWN := [Vector2(24, 21), Vector2(22, 23), Vector2(25, 20), Vector2(21, 22), Vector2(25, 22),
	Vector2(23, 21), Vector2(24, 23), Vector2(22, 20), Vector2(25, 21), Vector2(23, 22)]


func _make_tree(v: int) -> Image:
	var img := _new_image(64, 80)
	rng.seed = 5000 + v * 17
	var tint: float = TREE_TINT[v]
	var tones: Array = []
	for k in ["leaf_deep", "leaf_dark", "leaf", "leaf_light", "leaf_hi"]:
		tones.append(_tint(C[k], tint))
	var BK := [C.bark_dark.darkened(0.35), C.bark_dark, C.bark, C.bark_light, C.bark_light.lightened(0.18)]
	var base_y := 76.0
	var tw := 4.5 + (v * 3) % 4 * 0.5
	var crown: Vector2 = TREE_CROWN[v]
	var cc := Vector2(32, 6 + crown.y)

	# Trunk with a root flare and a couple of roots gripping the ground.
	var axis := func(y: float) -> float: return 32.0 + sin(y * 0.09 + v) * 0.8
	var half := func(y: float) -> float: return tw + pow(maxf(0.0, (y - 62.0) / 14.0), 2.0) * 5.5
	var trunk := _mk(img, func(p: Vector2) -> bool: return p.y > 34.0 and p.y < base_y and absf(p.x - float(axis.call(p.y))) <= float(half.call(p.y)))
	_bark(img, trunk, axis, half, BK, v)
	for s in [-1.0, 1.0]:
		var root := _mk(img, func(p: Vector2) -> bool: return Geometry2D.get_closest_point_to_segment(p, Vector2(32 + s * tw, base_y - 5), Vector2(32 + s * (tw + 9), base_y - 0.5)).distance_to(p) <= 1.6)
		_bark(img, root, func(_y: float) -> float: return 32.0 + s * (tw + 4.0), func(_y: float) -> float: return 6.0, BK, v + 9)
	# Branches reaching into the crown (mostly hidden, seen through gaps).
	for s in [-1.0, 1.0]:
		var br := _mk(img, func(p: Vector2) -> bool: return Geometry2D.get_closest_point_to_segment(p, Vector2(32, 44), Vector2(32 + s * 11, 30)).distance_to(p) <= 1.5)
		for p: Vector2i in br:
			_px(img, p.x, p.y, BK[1] if s > 0 else BK[2])

	var tufts := _crown_tufts(cc, crown.x, crown.y, 7.0 + (v % 3) * 0.5, 900 + v)
	_foliage(img, tufts, Vector4(cc.x - 3, cc.y - 4, crown.x + 4, crown.y + 4), tones, 100 + v)

	# The crown's shade on the trunk just below it.
	for p: Vector2i in trunk:
		var col := img.get_pixel(p.x, p.y)
		if BK.has(col) and p.y < cc.y + crown.y + 7:
			_tone_shift(img, p.x, p.y, BK, -1)
	if TREE_FRUIT.has(v):
		var fruit: Color = TREE_FRUIT[v]
		for i in 9:
			var t: Vector3 = tufts[int(_hash(i, 1, 1300 + v) * tufts.size())]
			var fx := int(t.x + (_hash(i, 2, 1300 + v) - 0.5) * t.z)
			var fy := int(t.y + (_hash(i, 3, 1300 + v) - 0.2) * t.z * 0.6)
			if img.get_pixel(clampi(fx, 0, 62), clampi(fy, 0, 78)).a > 0.0:
				_rect(img, fx, fy, 2, 2, fruit)
				_px(img, fx, fy, fruit.lightened(0.5))
				_px(img, fx + 1, fy + 1, fruit.darkened(0.35))
				_px(img, fx, fy + 2, tones[0])
				_px(img, fx + 1, fy + 2, tones[0])
	_ink(img)
	return img


## Low berry bush (feet at the bottom center of a 32x32 frame).
func _make_bush() -> Image:
	var img := _new_image(T, T)
	var greens := [C.grass_deep.darkened(0.25), C.grass_deep, C.grass_dark, C.grass, C.grass_light]
	_foliage(img, _crown_tufts(Vector2(16, 20), 13.0, 9.0, 4.6, 401), Vector4(14, 17, 14, 11), greens, 401)
	_ink(img)
	for p in [Vector2i(10, 15), Vector2i(19, 13), Vector2i(23, 20), Vector2i(14, 21), Vector2i(7, 22), Vector2i(17, 17), Vector2i(25, 15)]:
		_berry(img, p.x, p.y)
	return img


func _n_shrub(fruit: Array, r: float, seed: int) -> Image:
	var img := _new_image(T, T)
	_foliage(img, _crown_tufts(Vector2(16, 20), 13.0, 9.5, 4.6, seed), Vector4(14, 17, 14, 11), LEAF5, seed)
	_ink(img)
	var tones: Array = fruit if fruit.size() == 5 else [fruit[0], fruit[0], fruit[1], fruit[2], fruit[3]]
	for i in 8:
		var c := Vector2(7 + _hash(i, 1, seed) * 18.0, 13 + _hash(i, 2, seed) * 13.0)
		if img.get_pixel(int(c.x), int(c.y)).a > 0.5 and img.get_pixel(int(c.x), int(c.y)) != C.outline:
			_berry_dot(img, c, tones, r)
			_px(img, int(c.x - r * 0.4), int(c.y - r * 0.4), tones[4].lightened(0.3))
	return img


func _n_apple_tree() -> Image:
	var img := _new_image(T, T)
	var BK := [C.bark_dark.darkened(0.35), C.bark_dark, C.bark, C.bark_light, C.bark_light.lightened(0.18)]
	var trunk := _mk(img, func(p: Vector2) -> bool: return p.y > 14.0 and p.y < 30.0 and absf(p.x - 16.0) <= 2.6 + maxf(0.0, p.y - 26.0) * 0.8)
	_bark(img, trunk, func(_y: float) -> float: return 16.0, func(y: float) -> float: return 2.6 + maxf(0.0, y - 26.0) * 0.8, BK, 3)
	_foliage(img, _crown_tufts(Vector2(16, 12), 14.0, 10.5, 4.6, 1140), Vector4(14, 9, 15, 12), LEAF5, 1140)
	_ink(img)
	for c in [Vector2(9, 10), Vector2(19, 6), Vector2(24, 14), Vector2(13, 17), Vector2(17, 12), Vector2(6, 15), Vector2(21, 19)]:
		_berry_dot(img, c, RED5, 2.0)
		_px(img, int(c.x) - 1, int(c.y) - 1, RED5[4].lightened(0.3))
		_px(img, int(c.x), int(c.y) - 3, LEAF5[1])
	return img


func _n_stump() -> Image:
	var img := _new_image(T, T)
	var BK := [C.bark_dark.darkened(0.35), C.bark_dark, C.bark, C.bark_light, C.bark_light.lightened(0.18)]
	var half := func(y: float) -> float: return 10.5 + pow(maxf(0.0, (y - 24.0) / 5.0), 2.0) * 3.0
	var body := _mk(img, func(p: Vector2) -> bool: return p.y > 15.0 and p.y < 30.0 and absf(p.x - 16.0) <= float(half.call(p.y)))
	_bark(img, body, func(_y: float) -> float: return 16.0, half, BK, 11)
	var top := _mk(img, func(p: Vector2) -> bool: return pow((p.x - 16.0) / 10.5, 2) + pow((p.y - 15.5) / 4.5, 2) <= 1.0)
	for p: Vector2i in top:
		var d := sqrt(pow((p.x + 0.5 - 16.0) / 10.5, 2) + pow((p.y + 0.5 - 15.5) / 4.5, 2))
		var ring := int(d * 4.5) % 2 == 0
		var col: Color = WOOD5[4] if ring else WOOD5[3]
		if d > 0.86:
			col = WOOD5[2] if p.y < 15 else WOOD5[1]
		elif d < 0.15:
			col = WOOD5[2]
		_px(img, p.x, p.y, col)
	_line(img, Vector2(16, 15), Vector2(21, 13), WOOD5[1])
	for d in [Vector2(8, 19), Vector2(22, 21)]:
		_bevel(img, _mask_add(_mask_stroke(d, d + Vector2(0, 4), 1.2), _mask_ellipse(d + Vector2(0, 5), 1.9, 2.0)), AMBER5)
		_px(img, int(d.x) - 1, int(d.y) + 4, AMBER5[4])
	return _fin(img)


## Tapered, curved grass blade; lit on its left half, sunny at the tip.
func _blade(img: Image, base: Vector2, tip: Vector2, bend: float, w: float, tones: Array) -> void:
	var ctrl := base.lerp(tip, 0.55) + Vector2(bend, 0)
	var steps := int(base.distance_to(tip) * 2.0) + 2
	for i in steps + 1:
		var t := float(i) / steps
		var p := base.lerp(ctrl, t).lerp(ctrl.lerp(tip, t), t)
		var hw := w * (1.0 - t * 0.9)
		for k in range(-2, 3):
			var dx := k * 0.5
			if absf(dx) > hw:
				continue
			var col: Color = tones[3] if dx < 0.0 else tones[2]
			if dx > 0.0 and absf(dx) > hw - 0.6:
				col = tones[1]
			if t > 0.8:
				col = tones[4]
			elif t < 0.18:
				col = tones[1] if dx >= 0.0 else tones[2]
			_px(img, int(round(p.x + dx)), int(round(p.y)), col)


func _make_grass_tuft() -> Image:
	var img := _new_image(T, T)
	var greens := [C.grass_deep.darkened(0.2), C.grass_deep, C.grass_dark, C.grass, C.grass_light]
	var back := [greens[0], greens[0], greens[1], greens[2], greens[3]]
	for i in 13:
		var bx := 7.0 + i * 1.5 + (_hash(i, 1, 640) - 0.5) * 2.0
		var h := 11.0 + _hash(i, 3, 640) * 12.0 - absf(i - 6.0) * 0.6
		var lean := (bx - 16.0) * 0.55 + (_hash(i, 4, 641) - 0.5) * 5.0
		_blade(img, Vector2(bx, 29), Vector2(bx + lean, 29 - h), (_hash(i, 5, 642) - 0.5) * 6.0, 1.3, back if i % 2 else greens)
	for i in 5:
		var bx := 10.0 + i * 3.0
		_blade(img, Vector2(bx, 30), Vector2(bx + (bx - 16.0) * 0.8, 30 - 7.0 - _hash(i, 6, 643) * 5.0), 1.5, 1.2, greens)
	return _fin(img)


func _make_clay() -> Image:
	var img := _new_image(T, T)
	var t: Array = MAT["clay"]
	var mound := _mk(img, func(p: Vector2) -> bool: return pow((p.x - 16.0) / 13.0, 2) + pow((p.y - 24.0) / 6.5, 2) <= 1.0 and p.y < 29.5)
	_bevel(img, mound, t)
	# Strata and a wet sheen where the clay has been dug.
	for k in 3:
		var y := 22 + k * 2
		for x in range(5, 28):
			if mound.has(Vector2i(x, y)) and sin(x * 0.5 + k * 2.0) > -0.3:
				_px(img, x, y, t[1])
	_bevel(img, _mask_ellipse(Vector2(12, 21), 4.5, 2.2), [t[1], t[2], t[3], t[4], t[4].lightened(0.2)])
	_line(img, Vector2(10, 20), Vector2(13, 20), Color8(250, 226, 200))
	_px(img, 20, 22, Color8(250, 226, 200))
	for c in [Vector2(23, 21), Vector2(6, 27), Vector2(26, 27)]:
		_bevel(img, _mask_ellipse(c, 2.0, 1.4), MAT["stone"])
	return _fin(img)


func _mushroom(img: Image, cx: float, base_y: float, s: float) -> void:
	_bevel(img, _mask_stroke(Vector2(cx, base_y), Vector2(cx, base_y - 4.0 * s), 1.3 * s), MAT["bone"])
	var cap := _mask_cut(_mask_ellipse(Vector2(cx, base_y - 4.0 * s), 4.2 * s, 3.0 * s),
		_mask_fn(func(p: Vector2) -> bool: return p.y > base_y - 4.0 * s + 0.6 * s))
	_bevel(img, cap, CAP5)
	# Gills under the rim, then pale spots on the cap.
	var low := -1
	for p: Vector2i in cap:
		low = maxi(low, p.y)
	for p: Vector2i in cap:
		if p.y == low:
			_px(img, p.x, p.y + 1, Color8(150, 110, 90))
	for d in [Vector2(-1.6, -1.6), Vector2(1.4, -2.2), Vector2(2.6, -0.6)]:
		_px(img, int(cx + d.x * s), int(base_y - 4.0 * s + d.y * s), CAP5[4])
		if s > 1.4:
			_px(img, int(cx + d.x * s) + 1, int(base_y - 4.0 * s + d.y * s), Color8(250, 236, 220))


func _make_mushrooms() -> Image:
	var img := _new_image(T, T)
	var moss := [C.moss_dark, C.moss_dark, C.moss, C.moss_light, C.moss_light.lightened(0.15)]
	_bevel(img, _mask_ellipse(Vector2(16, 28), 12, 2.6), moss)
	_mushroom(img, 11, 27, 1.5)
	_mushroom(img, 21, 28, 1.9)
	_mushroom(img, 15, 29, 1.0)
	_mushroom(img, 26, 29, 0.8)
	for x in [6, 8, 24, 28]:
		_blade(img, Vector2(x, 29), Vector2(x + 1, 23), 1.0, 0.8, LEAF5)
	return _fin(img)


## Boulder lit from the upper left: a lumpy superellipse with facets.
func _boulder(img: Image, c: Vector2, w: float, h: float, p: float, tones: Array, seed: int, base: float) -> Dictionary:
	var light := Vector3(-0.5, -0.75, 0.5).normalized()
	var ph1 := _hash(seed, 1, 5) * TAU
	var ph2 := _hash(seed, 2, 5) * TAU
	var m := {}
	for y in img.get_height():
		for x in img.get_width():
			var dx := (x + 0.5 - c.x) / w
			var dy := (y + 0.5 - c.y) / h
			var ang := atan2(dy, dx)
			var lump := 1.0 + 0.1 * sin(ang * 3.0 + ph1) + 0.06 * sin(ang * 5.0 + ph2)
			if pow(absf(dx), p) + pow(absf(dy), p) > pow(lump, p) or y > base:
				continue
			var nx := dx / lump
			var ny := dy / lump
			var d := minf(pow(absf(nx), p) + pow(absf(ny), p), 1.0)
			var nz := pow(maxf(0.0, 1.0 - d), 1.0 / p)
			# Quantised normals give flat facets instead of a smooth ball.
			var fn := Vector3(snappedf(nx, 0.45), snappedf(ny, 0.45), nz + 0.3).normalized()
			var lit := fn.dot(light) + (_hash(x, y, seed) - 0.5) * 0.16
			_px(img, x, y, tones[clampi(int((lit + 0.15) / 1.05 * tones.size()), 0, tones.size() - 1)])
			m[Vector2i(x, y)] = true
	return m


func _make_ore(specks: Array, seed: int) -> Image:
	var img := _new_image(T, T)
	var rock := [C.rock_deep, C.rock_dark, C.rock, C.rock_light, C.rock_hi]
	var body := _boulder(img, Vector2(15, 19), 12.5, 10.5, 2.4, rock, 600 + seed, 29.0)
	_boulder(img, Vector2(26, 26), 4.2, 3.4, 2.0, rock, 610 + seed, 29.0)
	var ore := [specks[0].darkened(0.5), specks[0].darkened(0.22), specks[0], specks[1], specks[2]]
	# A dark vein the nuggets sit along.
	var a := Vector2(6 + _hash(seed, 3, 7) * 4.0, 13 + _hash(seed, 4, 7) * 4.0)
	var b := Vector2(24, 20 + _hash(seed, 5, 7) * 5.0)
	for i in 14:
		var q := a.lerp(b, i / 13.0) + Vector2(0, sin(i * 0.9 + seed) * 1.5)
		if body.has(Vector2i(q)):
			_px(img, int(q.x), int(q.y), rock[0])
	for i in 6:
		var t := (i + 0.5) / 6.0
		var q := a.lerp(b, t) + Vector2((_hash(i, 1, seed) - 0.5) * 4.0, (_hash(i, 2, seed) - 0.5) * 5.0)
		if not body.has(Vector2i(q)):
			continue
		var m := _mask_poly(_rough(q, 1.9 + _hash(i, 3, seed) * 1.0, 6, seed + i * 13))
		_bevel(img, m, ore)
	_fin(img)
	for i in 3:
		var q := a.lerp(b, (i + 0.3) / 3.0)
		if body.has(Vector2i(q)):
			_px(img, int(q.x) - 1, int(q.y) - 2, Color.WHITE)
	return img


## Campfire: log tepee in a ring of stones, flames swaying over 3 frames.
func _make_campfire() -> Image:
	var img := _new_image(T * 3, T)
	var stone := [C.rock_deep, C.rock_dark, C.rock, C.rock_light, C.rock_hi]
	var WD := [C.wood_deep, C.wood_dark, C.wood, C.wood_light, C.wood_hi]
	var ring: Array = []
	for i in 11:
		var a := TAU * i / 11.0 + 0.2
		ring.append(Vector3(16.0 + cos(a) * 12.0, 25.0 + sin(a) * 4.6, sin(a)))
	for frame in 3:
		var f := _new_image(T, T)
		rng.seed = 77 + frame
		for s in ring:
			if s.z < 0.0:
				_boulder(f, Vector2(s.x, s.y), 3.0, 2.4, 2.2, stone, 150 + int(s.x * 7.0), 31.0)
		_blob(f, 16, 25, 9.5, 3.6, [C.fire_deep, C.fire_deep, C.fire_out, C.fire_mid], 0.35, 140 + frame)
		for lg in [[Vector2(7, 26), Vector2(15, 12)], [Vector2(25, 26), Vector2(17, 12)]]:
			_bevel(f, _mask_stroke(lg[0], lg[1], 1.7), WD)
		# Flames: an outer tongue, a hot middle and a white-yellow core.
		var layers := [[C.fire_out, 19, 7.0], [C.fire_mid, 14, 5.0], [C.fire_core, 8, 2.8]]
		for layer in layers:
			var h: int = layer[1] + rng.randi_range(-1, 1)
			var wmax: float = layer[2]
			for y in h:
				var fr := float(y) / h
				var hw := wmax * pow(1.0 - fr, 0.7) * (1.0 + 0.25 * sin(y * 0.9 + frame * 2.1))
				var sway := sin(fr * 3.4 + frame * 2.1) * 2.2 * fr
				for x in range(int(16 + sway - hw), int(16 + sway + hw) + 1):
					_px(f, x, 24 - y, layer[0])
		for side in [-1, 1]:
			for y in 7:
				_px(f, 16 + side * (6 + y / 3) + (frame - 1), 23 - y - (frame % 2), C.fire_out if y < 5 else C.fire_mid)
		for lg in [[Vector2(8, 29), Vector2(14, 19)], [Vector2(24, 29), Vector2(18, 19)]]:
			_bevel(f, _mask_stroke(lg[0], lg[1], 1.6), WD)
			_bevel(f, _mask_ellipse(lg[0], 1.8, 1.8), [WD[1], WD[2], WD[3], WD[4], WD[4]])
			_px(f, int(lg[0].x), int(lg[0].y), WD[1])
		for s in ring:
			if s.z >= 0.0:
				_boulder(f, Vector2(s.x, s.y), 3.2, 2.5, 2.2, stone, 150 + int(s.x * 7.0), 31.0)
		_ink(f)
		for i in 3:
			_px(f, rng.randi_range(9, 23), rng.randi_range(0, 5), C.fire_core)
		img.blit_rect(f, Rect2i(0, 0, T, T), Vector2i(frame * T, 0))
	return img


func _wood_tones() -> Array:
	return [C.wood_deep, C.wood_dark, C.wood, C.wood_light, C.wood_hi]


## Horizontal planks with grain streaks, knots and a lit top edge per plank.
func _plank_face(img: Image, x0: int, y0: int, w: int, h: int, ph: int, tones: Array, seed: int, top_lit := true) -> void:
	for y in range(y0, y0 + h):
		var r := (y - y0) / ph
		var yy := (y - y0) % ph
		var shift := (_hash(r, seed, 1) - 0.5) * 0.12
		for x in range(x0, x0 + w):
			var col: Color = tones[2].lightened(shift)
			var g := _hash(int((x + r * 7) / 5), y, seed)
			if g > 0.8:
				col = tones[1].lightened(shift)
			elif g < 0.1:
				col = tones[3].lightened(shift)
			if yy == 0 and top_lit:
				col = tones[3].lightened(shift)
			elif yy == ph - 1:
				col = tones[0]
			_px(img, x, y, col)
		if yy == ph / 2 and _hash(r, seed, 2) > 0.5:
			var kx := x0 + 3 + int(_hash(r, seed, 3) * (w - 6))
			_px(img, kx, y, tones[0])
			_px(img, kx + 1, y, tones[1])


func _st_chest() -> Image:
	var img := _new_image(T, T)
	var WD := _wood_tones()
	var IR: Array = MAT["iron"]
	var GD := [Color8(110, 70, 24), Color8(170, 116, 40), C.gold, Color8(244, 214, 120), Color8(255, 244, 190)]
	# Front face and the lid seen from above.
	_plank_face(img, 4, 17, 24, 12, 4, WD, 241)
	_rect(img, 4, 28, 24, 1, WD[0])
	var lid := [WD[1], WD[2], WD[3], WD[4], WD[4].lightened(0.1)]
	_plank_face(img, 4, 6, 24, 9, 3, lid, 242)
	_rect(img, 4, 15, 24, 1, WD[4])
	_rect(img, 4, 16, 24, 1, WD[1])
	_rect(img, 5, 17, 22, 1, WD[0])
	# Iron corner bands with rivets, wrapping lid and body.
	for bx in [4, 25]:
		_rect(img, bx, 6, 3, 23, IR[2])
		_rect(img, bx, 6, 1, 23, IR[3])
		_rect(img, bx + 2, 6, 1, 23, IR[1])
		for ry in [8, 13, 20, 26]:
			_px(img, bx + 1, ry, IR[4])
			_px(img, bx + 1, ry + 1, IR[0])
	_rect(img, 4, 15, 24, 2, IR[2])
	_rect(img, 4, 15, 24, 1, IR[3])
	# Gold lock plate and keyhole.
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(12.5, 14), Vector2(19.5, 14), Vector2(19.5, 20), Vector2(16, 22.5), Vector2(12.5, 20)])), GD)
	_rect(img, 15, 16, 2, 2, C.outline)
	_px(img, 15, 18, C.outline)
	_px(img, 13, 14, GD[4])
	_ink(img)
	return img


func _st_workbench() -> Image:
	var img := _new_image(T, T)
	var WD := _wood_tones()
	var IR: Array = MAT["iron"]
	# Legs with a stretcher, then the thick top seen from above.
	for lx in [4, 24]:
		_bevel(img, _mask_poly(PackedVector2Array([Vector2(lx, 18), Vector2(lx + 4, 18), Vector2(lx + 4, 30), Vector2(lx, 30)])), WD)
	_rect(img, 8, 25, 16, 2, WD[1])
	_rect(img, 8, 25, 16, 1, WD[2])
	_rect(img, 3, 19, 26, 3, WD[1])
	_rect(img, 3, 19, 26, 1, WD[2])
	_rect(img, 3, 21, 26, 1, WD[0])
	var top := [WD[1], WD[2], WD[3], WD[4], WD[4].lightened(0.12)]
	_plank_face(img, 2, 8, 28, 9, 3, top, 232)
	_rect(img, 2, 17, 28, 2, WD[2])
	_rect(img, 2, 17, 28, 1, WD[4])
	_rect(img, 2, 18, 28, 1, WD[1])
	# A vice at the left end.
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(2, 13), Vector2(7, 13), Vector2(7, 21), Vector2(2, 21)])), IR)
	_line(img, Vector2(1, 22), Vector2(8, 22), IR[3])
	# Saw, hammer, shavings and nails on the top.
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(9, 9.5), Vector2(19, 9.5), Vector2(19, 13), Vector2(10, 12)])), IR)
	for tx in range(10, 19, 2):
		_px(img, tx, 13, IR[1])
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(18, 9), Vector2(22, 9), Vector2(22, 13.5), Vector2(18, 13.5)])), WD)
	_px(img, 20, 11, WD[0])
	_bevel(img, _mask_stroke(Vector2(22.5, 15.5), Vector2(28.5, 11.5), 0.9), WD)
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(26, 8), Vector2(30, 10.5), Vector2(28.5, 13), Vector2(24.5, 10.5)])), IR)
	for p in [Vector2i(11, 15), Vector2i(13, 16), Vector2i(15, 15)]:
		_px(img, p.x, p.y, WD[4])
		_px(img, p.x + 1, p.y, WD[3])
	_px(img, 9, 15, IR[3])
	_px(img, 24, 16, IR[3])
	_ink(img)
	return img


func _st_furnace() -> Image:
	var img := _new_image(T, T)
	var ST: Array = [C.rock_deep, C.rock_dark, C.rock, C.rock_light, C.rock_hi]
	var body := _mk(img, func(p: Vector2) -> bool:
		return p.x > 3.0 and p.x < 29.0 and p.y < 30.0 and (p.y > 13.0 or pow((p.x - 16.0) / 12.6, 2) + pow((p.y - 13.0) / 8.5, 2) <= 1.0))
	# Irregular masonry courses; each stone bevelled.
	var widths := [6, 8, 5, 7, 6, 9, 5, 7]
	for p: Vector2i in body:
		var row := (p.y - 4) / 5
		var yy := (p.y - 4) % 5
		var off := int(_hash(row, 0, 251) * 6.0)
		var x := p.x + off
		var acc := 0
		var k := 0
		while acc + int(widths[(k + row) % widths.size()]) <= x:
			acc += int(widths[(k + row) % widths.size()])
			k += 1
		var xx := x - acc
		var sw: int = widths[(k + row) % widths.size()]
		var t := 2
		if _hash(k, row, 252) > 0.6:
			t = 3
		if yy == 0 or xx == 0:
			t = 0
		elif yy == 1 or xx == 1:
			t = mini(t + 1, 4)
		elif yy == 4 or xx == sw - 1:
			t = 1
		if p.x > 23 and t > 0:
			t -= 1
		_px(img, p.x, p.y, ST[t])
	# Arched mouth: a soot-black interior with fire glowing at its floor.
	var mouth := _mk(img, func(p: Vector2) -> bool: return p.y < 28.0 and absf(p.x - 16.0) < 5.5 and (p.y > 21.0 or pow((p.x - 16.0) / 5.5, 2) + pow((p.y - 21.0) / 5.0, 2) <= 1.0))
	for p: Vector2i in mouth:
		var depth := (28.0 - p.y) / 11.0
		var col: Color = C.fire_deep.lerp(C.outline, clampf(depth * 1.3, 0.0, 1.0))
		if p.y >= 25:
			col = C.fire_out if absf(p.x - 16.0) < 4.0 else C.fire_deep
		if p.y >= 26 and absf(p.x - 16.0) < 2.5:
			col = C.fire_mid
		_px(img, p.x, p.y, col)
	_rect(img, 14, 27, 4, 1, C.fire_core)
	for p: Vector2i in body:
		if not mouth.has(p) and Vector2(p).distance_to(Vector2(16, 26)) < 9.0 and img.get_pixel(p.x, p.y) != ST[0]:
			img.set_pixel(p.x, p.y, img.get_pixel(p.x, p.y).lerp(C.fire_out, 0.25))
	_rect(img, 9, 28, 14, 2, ST[3])
	_rect(img, 9, 28, 14, 1, ST[4])
	# Chimney stack.
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(12, 0), Vector2(20, 0), Vector2(20, 7), Vector2(12, 7)])), [ST[0], ST[1], ST[2], ST[3], ST[4]])
	_rect(img, 13, 0, 6, 2, C.outline)
	_rect(img, 12, 4, 8, 1, ST[1])
	_ink(img)
	return img


## Irregular flagstones that tile seamlessly: two staggered courses per tile.
func _paint_flagstones(img: Image) -> void:
	var tones: Array = MAT["stone"]
	var rows := [[0, 14, [0, 13, 22]], [14, 18, [6, 17, 27]]]
	for row in rows:
		var y0: int = row[0]
		var h: int = row[1]
		var cuts: Array = row[2]
		for y in range(y0, y0 + h):
			for x in T:
				var k := 0
				for i in cuts.size():
					if posmod(x - int(cuts[i]), T) < posmod(x - int(cuts[k]), T):
						k = i
				var xx := posmod(x - int(cuts[k]), T)
				var sw := posmod(int(cuts[(k + 1) % cuts.size()]) - int(cuts[k]), T)
				var yy := y - y0
				var shade := (_hash(k, y0, 282) - 0.5) * 0.16
				var col: Color = tones[2].lightened(shade)
				if _hash(x, y, 283) > 0.95:
					col = tones[1].lightened(shade)
				elif _hash(x, y, 284) > 0.96:
					col = tones[3].lightened(shade)
				if xx == 0 or yy == 0:
					col = tones[0]
				elif xx == 1 or yy == 1:
					col = tones[3].lightened(shade)
				elif xx == sw - 1 or yy == h - 1:
					col = tones[1]
				_px(img, x, y, col)
	for p in [Vector2i(9, 6), Vector2i(10, 7), Vector2i(10, 8), Vector2i(22, 22), Vector2i(23, 23)]:
		_px(img, p.x, p.y, tones[0])
	for p in [Vector2i(13, 2), Vector2i(13, 3), Vector2i(6, 20), Vector2i(17, 29)]:
		_px(img, p.x, p.y, C.moss)


## Finishing pass for sprites: a soft volume rim (lit top edge, shaded
## bottom/right edge) and a selective outline - each outline pixel is a deep
## shade of the colour it borders, pure ink only along the bottom so the
## sprite stays grounded.
func _ink(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	var solid := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and src.get_pixel(x, y).a > 0.5
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a <= 0.5 or c == C.outline:
				continue
			if not solid.call(x, y - 1):
				img.set_pixel(x, y, c.lightened(0.14))
			elif not solid.call(x, y + 1) or not solid.call(x + 1, y):
				img.set_pixel(x, y, c.darkened(0.16))
	src = img.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			var sum := Vector3.ZERO
			var n := 0
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and src.get_pixel(q.x, q.y).a > 0.5:
					var nc := src.get_pixel(q.x, q.y)
					sum += Vector3(nc.r, nc.g, nc.b)
					n += 1
			if n == 0:
				continue
			var avg := Color(sum.x / n, sum.y / n, sum.z / n)
			var ink: Color = C.outline
			if not solid.call(x, y - 1):
				ink = avg.darkened(0.72).lerp(C.outline, 0.35)
			img.set_pixel(x, y, ink)


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
		Catalog.Id.WATER: func(_img: Image) -> void: pass, # invisible collider; ponds are overlays
	}
	for id in painters:
		var origin: Vector2i = Catalog.atlas_coords(id) * T
		var tile := _new_image(T, T)
		rng.seed = 1000 + id
		painters[id].call(tile)
		img.blit_rect(tile, Rect2i(0, 0, T, T), origin)
	# Large seamless grass: one shared base, so the three variants join without seams.
	for v in 3:
		var id: int = [Catalog.Id.GRASS, Catalog.Id.GRASS_ALT, Catalog.Id.GRASS_FLOWERS][v]
		var macro := _paint_grass_macro(v)
		img.blit_rect(macro, Rect2i(0, 0, macro.get_width(), macro.get_height()), Catalog.DEFS[id].macro * T)
		img.blit_rect(macro, Rect2i(0, 0, T, T), Catalog.atlas_coords(id) * T)
	for moss in [false, true]:
		var id: int = Catalog.Id.WALL_TOP_MOSS if moss else Catalog.Id.WALL_TOP
		var macro := _paint_wall_top_macro(moss)
		img.blit_rect(macro, Rect2i(0, 0, macro.get_width(), macro.get_height()), Catalog.DEFS[id].macro * T)
		img.blit_rect(macro, Rect2i(0, 0, T, T), Catalog.atlas_coords(id) * T)
	return img


## Soft grass, 7 close tones: wide gentle light/shade patches under dense small
## tufts of blades, no hard dark blobs. Tileable with period MACRO tiles.
const GRASS7 := [Color8(66, 122, 56), Color8(78, 136, 60), Color8(92, 150, 64), Color8(106, 162, 70),
	Color8(120, 174, 76), Color8(138, 188, 86), Color8(162, 204, 104)]


func _pnoise(x: float, y: float, cs: float, s: int, period: int) -> float:
	var n := int(period / cs)
	var fx := x / cs
	var fy := y / cs
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - x0
	var ty := fy - y0
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	return lerpf(lerpf(_hash(posmod(x0, n), posmod(y0, n), s), _hash(posmod(x0 + 1, n), posmod(y0, n), s), tx),
		lerpf(_hash(posmod(x0, n), posmod(y0 + 1, n), s), _hash(posmod(x0 + 1, n), posmod(y0 + 1, n), s), tx), ty)


func _paint_grass_macro(variant: int) -> Image:
	var P := T * Catalog.MACRO
	var img := _new_image(P, P)
	var level := PackedFloat32Array()
	level.resize(P * P)
	for y in P:
		for x in P:
			var n := _pnoise(x, y, 64, 31, P) * 0.55 + _pnoise(x, y, 32, 32, P) * 0.3 + _pnoise(x, y, 16, 33, P) * 0.15
			# Tones 2..4 for the base; a soft 2x2 checker dither blends the band edges.
			var t := clampf((n - 0.28) / 0.44, 0.0, 1.0) * 2.0 + 2.0
			var dither := 0.25 if (x + y) % 2 == 0 else -0.25
			level[y * P + x] = t
			img.set_pixel(x, y, GRASS7[clampi(int(t + dither * 0.5), 2, 4)])
	# Tufts: a darker root and 2-3 leaning blades a step lighter than the ground.
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	for i in 2600:
		var x := r.randi_range(0, P - 1)
		var y := r.randi_range(0, P - 1)
		var base := int(level[y * P + x])
		var light := clampi(base + 1 + (1 if r.randf() < 0.18 else 0), 0, 6)
		_wpx(img, x, y, GRASS7[base - 1])
		_wpx(img, x + 1, y, GRASS7[base - 1])
		for b in r.randi_range(2, 3):
			var lean := r.randi_range(-1, 1)
			var hgt := r.randi_range(2, 4)
			for k in hgt:
				var col: Color = GRASS7[light] if k > 0 else GRASS7[base]
				_wpx(img, x + b + (lean if k >= hgt - 1 else 0), y - k - 1, col)
	# Sparse shade curls give depth without blotches.
	for i in 500:
		var x := r.randi_range(0, P - 1)
		var y := r.randi_range(0, P - 1)
		var base := int(level[y * P + x])
		_wpx(img, x, y, GRASS7[maxi(base - 2, 0)])
		_wpx(img, x + 1, y - 1, GRASS7[maxi(base - 1, 0)])
	if variant == 1:
		# Clover patches.
		for i in 70:
			var c := Vector2i(r.randi_range(0, P - 1), r.randi_range(0, P - 1))
			for leaf in [Vector2i(0, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				var q: Vector2i = c + leaf * 2
				_wpx(img, q.x, q.y, GRASS7[5])
				_wpx(img, q.x + 1, q.y, GRASS7[6])
				_wpx(img, q.x, q.y + 1, GRASS7[3])
				_wpx(img, q.x + 1, q.y + 1, GRASS7[5])
	elif variant == 2:
		for i in 90:
			var x := r.randi_range(0, P - 1)
			var y := r.randi_range(0, P - 1)
			var petal: Color = [C.flower_y, C.flower_w, C.flower_r, Color8(196, 170, 236)][i % 4]
			_wpx(img, x, y + 1, GRASS7[1])
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				_wpx(img, x + d.x, y + d.y, petal)
			_wpx(img, x, y, C.flower_y if i % 4 != 0 else Color8(200, 120, 40))
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


## Weathered concrete cap slabs, 6 tones, lit from the upper left.
const STONE6 := [Color8(64, 72, 72), Color8(84, 94, 92), Color8(104, 114, 108), Color8(124, 134, 124),
	Color8(146, 154, 142), Color8(172, 178, 162)]
## Ivy mats creeping over the wall tops: ink, shade, body, lit, sunlit.
const IVY5 := [Color8(22, 42, 32), Color8(36, 66, 42), Color8(54, 94, 50), Color8(80, 124, 58),
	Color8(118, 158, 74)]
## Slab row heights of the wall-top macro; they sum to T * MACRO so it tiles.
const SLAB_ROWS := [28, 36, 24, 32, 40, 28, 36, 32]


## Seamless MACRO x MACRO tile wall-top texture: big irregular slabs with
## bevels, cracks and stains, partly covered by ivy mats. WALL_TOP and
## WALL_TOP_MOSS share the same slabs and ivy so neighbouring cells join; the
## moss variant only adds tufts that stay inside each tile.
func _paint_wall_top_macro(moss: bool) -> Image:
	var P := T * Catalog.MACRO
	var img := _new_image(P, P)
	var r := RandomNumberGenerator.new()
	r.seed = 7171
	var slab := PackedInt32Array()
	slab.resize(P * P)
	var level := PackedInt32Array()
	level.resize(P * P)
	var y0 := 0
	for row in SLAB_ROWS.size():
		var h: int = SLAB_ROWS[row]
		var x0 := r.randi_range(0, 40)
		var widths: Array[int] = []
		var total := 0
		while total < P:
			var w := r.randi_range(28, 56)
			if P - total - w < 28:
				w = P - total
			widths.append(w)
			total += w
		var sx := x0
		for i in widths.size():
			var w: int = widths[i]
			var id := row * 64 + i
			var tone := 2 + (1 if _hash(id, 3, 61) > 0.55 else 0) - (1 if _hash(id, 4, 61) > 0.85 else 0)
			var chip := r.randi_range(0, 3) if r.randf() < 0.35 else -1
			for yy in h:
				for xx in w:
					var x := posmod(sx + xx, P)
					var y := y0 + yy
					var k := y * P + x
					slab[k] = id
					var n := _pnoise(x, y, 64, 62, P) * 0.55 + _pnoise(x, y, 16, 63, P) * 0.37 + _hash(x, y, 64) * 0.08
					var lv := tone
					if n < 0.34:
						lv -= 1
					elif n > 0.7 and (x + y) % 2 == 0:
						lv += 1
					# Bevel: lit top/left rim, shaded bottom/right, dark joint.
					if yy == h - 1 or xx == w - 1:
						lv = 0
					elif yy == 0 or xx == 0:
						lv = mini(tone + 2, 5)
					elif yy == h - 2 or xx == w - 2:
						lv = maxi(tone - 1, 1)
					# Chipped corner.
					var corner := Vector2i(0 if chip % 2 == 0 else w - 1, 0 if chip < 2 else h - 1)
					if chip >= 0 and absi(xx - corner.x) + absi(yy - corner.y) < 5:
						lv = 1 if absi(xx - corner.x) + absi(yy - corner.y) < 4 else 0
					level[k] = clampi(lv, 0, 5)
			sx += w
		y0 += h
	# Hairline cracks wandering across slabs.
	for i in 22:
		var x := r.randi_range(0, P - 1)
		var y := r.randi_range(0, P - 1)
		var dir := Vector2i(1 if r.randf() < 0.5 else -1, 0) if r.randf() < 0.5 else Vector2i(0, 1)
		for s in r.randi_range(6, 16):
			var k := posmod(y, P) * P + posmod(x, P)
			if level[k] > 1:
				level[k] = 1
				var k2 := posmod(y + 1, P) * P + posmod(x + 1, P)
				level[k2] = mini(level[k2] + 1, 5)
			if r.randf() < 0.4:
				if dir.y == 0:
					y += r.randi_range(-1, 1)
				else:
					x += r.randi_range(-1, 1)
			x += dir.x
			y += dir.y
	for y in P:
		for x in P:
			img.set_pixel(x, y, STONE6[level[y * P + x]])
	# Ivy cover from tileable noise; leaves are drawn as small lit clusters.
	var ivy := PackedByteArray()
	ivy.resize(P * P)
	for y in P:
		for x in P:
			var n := _pnoise(x, y, 64, 71, P) * 0.62 + _pnoise(x, y, 16, 72, P) * 0.34 + _hash(x, y, 73) * 0.04
			ivy[y * P + x] = 1 if n > 0.6 else 0
	for y in P:
		for x in P:
			if ivy[y * P + x] == 0:
				# Ivy casts a short shadow down and to the right.
				if ivy[posmod(y - 1, P) * P + x] == 1 or ivy[posmod(y - 2, P) * P + posmod(x - 1, P)] == 1:
					img.set_pixel(x, y, STONE6[maxi(level[y * P + x] - 2, 0)])
				continue
			var edge := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if ivy[posmod(y + d.y, P) * P + posmod(x + d.x, P)] == 0:
					edge = true
			img.set_pixel(x, y, IVY5[0] if edge else IVY5[1])
	for i in 5200:
		var x := r.randi_range(0, P - 1)
		var y := r.randi_range(0, P - 1)
		if ivy[y * P + x] == 0:
			continue
		var lit := 3 if r.randf() < 0.7 else 4
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			if ivy[posmod(y + d.y, P) * P + posmod(x + d.x, P)] == 1:
				_wpx(img, x + d.x, y + d.y, IVY5[2])
		_wpx(img, x, y, IVY5[lit])
		if ivy[posmod(y + 2, P) * P + posmod(x + 1, P)] == 1:
			_wpx(img, x + 1, y + 2, IVY5[1])
	# Trailing tendrils escaping the mats along slab joints.
	for i in 90:
		var x := r.randi_range(0, P - 1)
		var y := r.randi_range(0, P - 1)
		if ivy[y * P + x] == 0:
			continue
		var dir: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][r.randi_range(0, 3)]
		for s in r.randi_range(4, 12):
			x += dir.x + (r.randi_range(-1, 1) if dir.y != 0 and r.randf() < 0.3 else 0)
			y += dir.y + (r.randi_range(-1, 1) if dir.x != 0 and r.randf() < 0.3 else 0)
			_wpx(img, x, y, IVY5[1])
			if s % 3 == 1:
				_wpx(img, x + 1, y - 1, IVY5[3])
	if moss:
		# Tufts kept 4 px inside each tile so moss cells still join plain ones.
		for ty in Catalog.MACRO:
			for tx in Catalog.MACRO:
				for j in 3:
					var cx := tx * T + r.randi_range(6, T - 7)
					var cy := ty * T + r.randi_range(6, T - 7)
					for q in 10:
						var x := cx + r.randi_range(-2, 2)
						var y := cy + r.randi_range(-1, 1)
						_wpx(img, x, y, IVY5[2] if q < 5 else (IVY5[3] if q < 8 else IVY5[4]))
					_wpx(img, cx - 2, cy + 2, IVY5[0])
					_wpx(img, cx + 2, cy + 2, IVY5[0])
	return img

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

## Character frames are 48x48: a chibi ~42 px tall (feet on row 46), drawn at
## the same pixel density as the 32 px tiles - big head, clustered hair
## strands, shaded clothing with folds, belt and gear.
const CF := 48
const BONE4 := [Color8(120, 104, 84), Color8(164, 148, 120), Color8(206, 192, 162), Color8(236, 228, 204)]
const STEEL4 := [Color8(58, 62, 74), Color8(96, 102, 116), Color8(142, 148, 162), Color8(200, 206, 216)]


## dir: 0 down, 1 up, 2 side (right). step: 0 idle, 1/2 walking.
func _make_player() -> Image:
	var img := _new_image(CF * 3, CF * 3)
	for row in 3:
		for col in 3:
			var frame := _new_image(CF, CF)
			_draw_hero(frame, row, col, {})
			_ink(frame)
			img.blit_rect(frame, Rect2i(0, 0, CF, CF), Vector2i(col * CF, row * CF))
	return img


func _cmask(test: Callable) -> Dictionary:
	var m := {}
	for y in CF:
		for x in CF:
			if test.call(Vector2(x + 0.5, y + 0.5)):
				m[Vector2i(x, y)] = true
	return m


func _cm_ellipse(c: Vector2, rx: float, ry: float) -> Dictionary:
	return _cmask(func(p: Vector2) -> bool: return pow((p.x - c.x) / rx, 2) + pow((p.y - c.y) / ry, 2) <= 1.0)


func _cm_poly(pts: PackedVector2Array) -> Dictionary:
	return _cmask(func(p: Vector2) -> bool: return Geometry2D.is_point_in_polygon(p, pts))


func _cm_stroke(a: Vector2, b: Vector2, half: float) -> Dictionary:
	return _cmask(func(p: Vector2) -> bool: return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= half)


## Cel shading lit from the upper left; tones = [deep, dark, mid, light].
func _shade(img: Image, mask: Dictionary, tones: Array) -> void:
	for p in mask:
		var o := func(dx: int, dy: int) -> bool: return not mask.has(p + Vector2i(dx, dy))
		var col: Color = tones[2]
		if o.call(1, 0) or o.call(0, 1):
			col = tones[1]
		elif o.call(-1, 0) or o.call(0, -1):
			col = tones[3]
		elif o.call(2, 0) or o.call(1, 1) or o.call(0, 2):
			col = tones[2].lerp(tones[1], 0.5)
		_px(img, p.x, p.y, col)


func _tones(base: Color, dark: Color, light: Color) -> Array:
	return [dark.darkened(0.28), dark, base, light]


## Hair: sphere lighting broken into strands radiating from the crown, a
## glossy highlight arc, and darker tips where locks overlap the face.
func _shade_hair(f: Image, m: Dictionary, c: Vector2, r: float, crown: Vector2, tones: Array) -> void:
	var light := Vector3(-0.5, -0.75, 0.45).normalized()
	for p in m:
		var q := Vector2(p) + Vector2(0.5, 0.5)
		var n := (q - c) / r
		var nz := sqrt(maxf(0.0, 1.0 - minf(n.length_squared(), 1.0)))
		var a := (q - crown).angle()
		var strand := sin(a * 15.0)
		var lit := Vector3(n.x, n.y, nz).dot(light) + strand * 0.16
		var col: Color = tones[clampi(int((lit + 0.55) / 1.35 * 4.0), 0, 3)]
		if absf(n.length() - 0.6) < 0.1 and n.y < -0.15 and n.x < 0.35 and strand > -0.4:
			col = tones[3].lightened(0.2)
		if not m.has(p + Vector2i(0, 1)):
			col = tones[0]
		_px(f, p.x, p.y, col)


func _draw_hero(f: Image, dir: int, step: int, d: Dictionary) -> void:
	var bob := 1 if step != 0 else 0
	var sw := 0 if step == 0 else (3 if step == 1 else -3)
	var cx := 24.0
	var hy := 15.0 + bob
	var ty := 24 + bob
	var side := dir == 2
	var SK := _tones(P.skin, P.skin_dark, P.skin.lightened(0.14))
	SK[0] = P.skin_deep
	var TU := _tones(P.tunic, P.tunic_dark, P.tunic_light)
	var PA := _tones(P.pants, P.pants_dark, P.pants.lightened(0.16))
	var BO := _tones(P.boot, P.boot_dark, P.boot.lightened(0.22))
	var PK := _tones(P.pack, P.pack_dark, P.pack.lightened(0.18))
	var HA := [P.hair_dark.darkened(0.25), P.hair_dark, P.hair, P.hair_light]
	var CL := _tones(P.cloth, P.cloth.darkened(0.25), P.cloth.lightened(0.18))
	var player: bool = d.is_empty()

	# Long hair hangs behind the shoulders.
	if d.get("long_hair", false) and dir == 0:
		for s in [-1, 1]:
			var m := _cm_poly(PackedVector2Array([Vector2(cx + s * 7, hy), Vector2(cx + s * 12, hy), Vector2(cx + s * 13.5, ty + 10), Vector2(cx + s * 8, ty + 11)]))
			_shade_hair(f, m, Vector2(cx, hy), 14.0, Vector2(cx, hy - 11), HA)

	# Gear behind the body.
	if side:
		_shade(f, _cm_poly(PackedVector2Array([Vector2(cx - 12, ty), Vector2(cx - 5, ty), Vector2(cx - 5, ty + 12), Vector2(cx - 11, ty + 12), Vector2(cx - 12.5, ty + 10)])), PK)
		_rect(f, int(cx) - 12, ty + 4, 7, 1, PK[0])
		_rect(f, int(cx) - 10, ty + 5, 2, 2, P.gold)
		if player:
			_shade(f, _cm_ellipse(Vector2(cx - 8.5, ty - 0.5), 4.5, 2.5), CL)
			_px(f, int(cx) - 9, ty - 1, CL[1])

	# Legs (feet on row 46); the far leg is shaded darker in profile.
	var leg_top := 35
	if side:
		var far := [PA[0], PA[0], PA[1], PA[2]]
		var far_b := [BO[0], BO[0], BO[1], BO[2]]
		_hero_leg(f, int(cx) - 3 - sw, leg_top, 0, far, far_b, true)
		_hero_leg(f, int(cx) - 3 + sw, leg_top, 0, PA, BO, true)
	else:
		_hero_leg(f, int(cx) - 6, leg_top, 2 if sw > 0 else 0, PA, BO, false)
		_hero_leg(f, int(cx) + 1, leg_top, 2 if sw < 0 else 0, PA, BO, false)

	# Torso: tunic flaring into a short skirt over the hips.
	var tw := 5.5 if side else 8.0
	var torso := _cm_poly(PackedVector2Array([Vector2(cx - tw, ty), Vector2(cx + tw, ty), Vector2(cx + tw, ty + 8), Vector2(cx + tw + 1, ty + 13.5), Vector2(cx - tw - 1, ty + 13.5), Vector2(cx - tw, ty + 8)]))
	_shade(f, torso, TU)
	var bx0 := int(cx - tw)
	var bw := int(tw * 2)
	_rect(f, bx0, ty + 8, bw, 1, PK[1])
	_rect(f, bx0, ty + 9, bw, 1, PK[0])
	for fx in ([-4, 3] if not side else [-1]):
		for yy in range(ty + 10, ty + 13):
			_px(f, int(cx) + fx, yy, TU[1])
		_px(f, int(cx) + fx + 1, ty + 12, TU[3])
	if dir == 0:
		for r in 4:
			_rect(f, int(cx) - 3 + r, ty + r, 6 - r * 2, 1, CL[2] if r < 2 else CL[1])
		_rect(f, int(cx) - 1, ty, 2, 1, SK[1])
		_rect(f, int(cx) - 2, ty + 8, 4, 2, P.gold)
		_px(f, int(cx) - 1, ty + 8, P.gold.lightened(0.35))
		_rect(f, int(cx) - 1, ty + 9, 2, 1, P.gold.darkened(0.35))
		if player:
			for sx in [-6, 4]:
				_rect(f, int(cx) + sx, ty, 2, 8, PK[1])
				_px(f, int(cx) + sx, ty, PK[3])
	elif dir == 1:
		_rect(f, int(cx) - 1, ty + 8, 2, 2, PK[2])
	else:
		_rect(f, int(cx) + 3, ty + 8, 2, 2, P.gold)
		if player:
			_rect(f, int(cx) - 3, ty, 2, 8, PK[1])
	_rect(f, bx0 + 1, ty + 1, 1, 5, TU[3])

	# Apron over the tunic (front view).
	if d.has("apron") and dir == 0:
		var a: Array = d.apron
		var AP := _tones(a[1], a[0], a[1].lightened(0.15))
		_shade(f, _cm_poly(PackedVector2Array([Vector2(cx - 5, ty + 3), Vector2(cx + 5, ty + 3), Vector2(cx + 6, ty + 14.5), Vector2(cx - 6, ty + 14.5)])), AP)
		for sx in [-5, 4]:
			_rect(f, int(cx) + sx, ty, 1, 3, a[0])
		_rect(f, int(cx) - 6, ty + 8, 12, 1, a[0].darkened(0.2))
		_rect(f, int(cx) - 2, ty + 10, 4, 3, AP[1])
		_rect(f, int(cx) - 2, ty + 10, 4, 1, AP[0])

	# Arms: sleeve and hand, swinging against the stride.
	if side:
		_hero_arm(f, Vector2(cx + 0.5, ty + 2.5), Vector2(cx + 0.5 + sw * 1.2, ty + 11.0), TU, SK)
	else:
		var lift := sw * 0.5
		_hero_arm(f, Vector2(cx - 10.0, ty + 2.5), Vector2(cx - 11.0, ty + 11.0 - lift), TU, SK)
		_hero_arm(f, Vector2(cx + 10.0, ty + 2.5), Vector2(cx + 11.0, ty + 11.0 + lift), TU, SK)

	# Backpack with bedroll, seen from behind.
	if dir == 1 and player:
		_shade(f, _cm_poly(PackedVector2Array([Vector2(cx - 7, ty + 1), Vector2(cx + 7, ty + 1), Vector2(cx + 7.5, ty + 12), Vector2(cx + 6, ty + 13), Vector2(cx - 6, ty + 13), Vector2(cx - 7.5, ty + 12)])), PK)
		_shade(f, _cm_poly(PackedVector2Array([Vector2(cx - 7, ty + 1), Vector2(cx + 7, ty + 1), Vector2(cx + 7, ty + 5), Vector2(cx - 7, ty + 5)])), [PK[0], PK[1], PK[3], PK[3].lightened(0.1)])
		_rect(f, int(cx) - 7, ty + 5, 14, 1, PK[0])
		_rect(f, int(cx) - 1, ty + 5, 2, 2, P.gold)
		_shade(f, _cm_poly(PackedVector2Array([Vector2(cx - 4, ty + 8), Vector2(cx + 4, ty + 8), Vector2(cx + 4, ty + 12), Vector2(cx - 4, ty + 12)])), PK)
		_rect(f, int(cx) - 4, ty + 8, 8, 1, PK[0])
		_shade(f, _cm_poly(PackedVector2Array([Vector2(cx - 9, ty - 3), Vector2(cx + 9, ty - 3), Vector2(cx + 9, ty + 1), Vector2(cx - 9, ty + 1)])), CL)
		for sx in [-9, 8]:
			_rect(f, int(cx) + sx, ty - 2, 1, 2, CL[0])
		for sx in [-5, 4]:
			_rect(f, int(cx) + sx, ty - 3, 1, 4, PK[1])

	# Head.
	var hc := Vector2(cx + (1 if side else 0), hy)
	if dir == 0:
		for s in [-1, 1]:
			_shade(f, _cm_ellipse(Vector2(cx + s * 10, hy + 2), 1.8, 2.5), SK)
	_blob(f, hc.x, hc.y, 10.0, 9.4, [SK[1], SK[2], SK[2], SK[3]], 0.0, 83)
	var crown := Vector2(cx, hy - 11)
	if dir == 0:
		var hair := _cmask(func(p: Vector2) -> bool:
			if pow((p.x - cx) / 11.0, 2) + pow((p.y - hy + 1) / 10.5, 2) > 1.0:
				return false
			var k := posmod(int(floor(p.x)) - int(cx) + 2, 5)
			var fringe: float = hy - 3 + [1, 3, 4, 2, 0][k]
			return p.y < fringe or (absf(p.x - cx) > 8.5 and p.y < hy + 5))
		if d.get("helmet", false):
			hair = _mask_cut(hair, _cmask(func(p: Vector2) -> bool: return p.y < hy - 1))
		_shade_hair(f, hair, Vector2(cx, hy - 1), 11.0, crown, HA)
		_hero_face(f, cx, hy, d)
	elif dir == 1:
		var hair := _cmask(func(p: Vector2) -> bool:
			var e := pow((p.x - cx) / 11.0, 2) + pow((p.y - hy + 1) / 10.5, 2)
			var k := posmod(int(floor(p.x)) - int(cx) + 1, 4)
			return e <= 1.0 and p.y < hy + 6 + [0, 2, 1, 2][k])
		_shade_hair(f, hair, Vector2(cx, hy - 1), 11.0, crown, HA)
	else:
		var hair := _cmask(func(p: Vector2) -> bool:
			if pow((p.x - cx) / 10.8, 2) + pow((p.y - hy + 1) / 10.5, 2) > 1.0:
				return false
			var k := posmod(int(floor(p.x)) - int(cx), 4)
			var fringe: float = hy - 3 + [2, 3, 1, 0][k]
			return p.y < fringe or (p.x < cx + 1 and p.y < hy + 6))
		_shade_hair(f, hair, Vector2(cx, hy - 1), 11.0, crown, HA)
		_shade(f, _cm_ellipse(Vector2(cx + 1.5, hy + 2.5), 1.8, 2.3), SK)
		_px(f, int(cx) + 1, hy + 2, SK[0])
		var ex := int(cx) + 6
		var ey := int(hy) + 1
		_rect(f, ex, ey, 3, 1, P.outline)
		_rect(f, ex, ey + 1, 2, 3, P.get("eye", Color8(58, 42, 36)))
		_px(f, ex, ey + 1, Color.WHITE)
		_px(f, ex + 1, ey + 3, P.get("eye", Color8(58, 42, 36)).lightened(0.3))
		_px(f, int(cx) + 11, ey + 3, SK[2])
		_px(f, int(cx) + 11, ey + 4, SK[1])
		_rect(f, int(cx) + 8, ey + 6, 2, 1, SK[0])
		_rect(f, ex - 1, ey + 5, 2, 1, P.flower_r.lightened(0.3))


func _hero_face(f: Image, cx: float, hy: float, d: Dictionary) -> void:
	var eye: Color = P.get("eye", Color8(58, 42, 36))
	var y0 := int(hy) + 1
	for s in [-1, 1]:
		var x0 := int(cx) - 7 if s < 0 else int(cx) + 4
		_rect(f, x0, y0, 3, 1, P.outline)
		_px(f, x0 - 1 if s < 0 else x0 + 3, y0 + 1, P.outline)
		_rect(f, x0, y0 + 1, 3, 3, eye)
		_rect(f, x0, y0 + 3, 3, 1, eye.lightened(0.28))
		_px(f, x0 + (0 if s < 0 else 1), y0 + 1, Color.WHITE)
		_px(f, x0 + (0 if s < 0 else 1), y0 + 2, Color(1, 1, 1).lerp(eye, 0.35))
		_rect(f, x0 + (-1 if s < 0 else 2), y0 + 5, 2, 1, P.flower_r.lightened(0.3))
	_px(f, int(cx) - 1, y0 + 4, P.skin_dark)
	if not d.has("beak"):
		_rect(f, int(cx) - 1, y0 + 6, 2, 1, P.skin_deep)


func _hero_leg(f: Image, x: int, top: int, lift: int, pa: Array, bo: Array, profile: bool) -> void:
	var bottom := 46 - lift
	_shade(f, _cm_poly(PackedVector2Array([Vector2(x, top), Vector2(x + 5, top), Vector2(x + 5, bottom - 5), Vector2(x, bottom - 5)])), pa)
	var toe := 2 if profile else 0
	var boot := _cm_poly(PackedVector2Array([Vector2(x - 0.5, bottom - 6), Vector2(x + 5.5, bottom - 6), Vector2(x + 5.5 + toe, bottom - 2.5), Vector2(x + 5.5 + toe, bottom + 1), Vector2(x - 0.5, bottom + 1)]))
	_shade(f, boot, bo)
	_rect(f, x, bottom - 6, 6, 1, bo[3])
	_rect(f, x - 1, bottom, 7 + toe, 1, bo[0])


func _hero_arm(f: Image, s: Vector2, h: Vector2, tu: Array, sk: Array) -> void:
	_shade(f, _cm_stroke(s, s.lerp(h, 0.72), 2.1), tu)
	var cuff := s.lerp(h, 0.72)
	_px(f, int(cuff.x) - 1, int(cuff.y), tu[1])
	_px(f, int(cuff.x), int(cuff.y), tu[1])
	_shade(f, _cm_ellipse(h, 2.1, 2.0), sk)


# ---------------------------------------------------------------- survivors

## The Clearing's survivors (Settlement.CAST): the player's body and
## proportions, facing the camera, each with their own colours and features.
const NPCS := {
	"npc_human": {"tunic": [Color8(150, 74, 50), Color8(104, 50, 38), Color8(188, 106, 70)],
		"hair": [Color8(44, 32, 28), Color8(70, 50, 40), Color8(98, 72, 54)], "beard": "short"},
	"npc_elf": {"skin": [Color8(250, 222, 196), Color8(222, 184, 156), Color8(190, 148, 124)],
		"hair": [Color8(196, 160, 72), Color8(234, 206, 120), Color8(250, 236, 170)],
		"tunic": [Color8(62, 132, 112), Color8(40, 92, 80), Color8(100, 170, 140)], "ears": "pointed", "long_hair": true, "eye": Color8(40, 110, 90)},
	"npc_dwarf": {"hair": [Color8(130, 130, 130), Color8(176, 176, 172), Color8(216, 214, 206)],
		"tunic": [Color8(88, 96, 140), Color8(60, 64, 100), Color8(120, 130, 172)], "beard": "long", "apron": [Color8(120, 80, 48), Color8(150, 104, 62)]},
	"npc_halfling": {"hair": [Color8(150, 66, 30), Color8(196, 98, 44), Color8(226, 136, 70)],
		"tunic": [Color8(200, 160, 60), Color8(150, 112, 40), Color8(230, 196, 96)], "apron": [Color8(206, 200, 184), Color8(240, 236, 222)]},
	"npc_tengu": {"skin": [Color8(150, 140, 160), Color8(110, 100, 120), Color8(80, 72, 90)],
		"hair": [Color8(30, 30, 44), Color8(52, 52, 74), Color8(84, 84, 112)],
		"tunic": [Color8(64, 92, 150), Color8(42, 60, 104), Color8(96, 130, 190)], "beak": true, "eye": Color8(200, 150, 40)},
	"npc_deep_dwarf": {"skin": [Color8(170, 176, 190), Color8(132, 138, 156), Color8(100, 104, 122)],
		"hair": [Color8(70, 74, 84), Color8(110, 116, 128), Color8(170, 176, 186)],
		"tunic": [Color8(96, 100, 108), Color8(60, 63, 72), Color8(150, 156, 164)], "beard": "long", "beard_tones": [Color8(196, 196, 196), Color8(232, 232, 228)], "helmet": true},
	"npc_faun": {"skin": [Color8(222, 170, 126), Color8(188, 132, 96), Color8(150, 100, 74)],
		"hair": [Color8(70, 44, 30), Color8(104, 66, 42), Color8(136, 92, 58)],
		"tunic": [Color8(150, 118, 64), Color8(108, 82, 46), Color8(186, 156, 92)],
		"legs": [Color8(110, 76, 52), Color8(80, 54, 38)], "hooves": [Color8(44, 34, 30), Color8(28, 22, 20)], "horns": true},
	"npc_merfolk": {"skin": [Color8(150, 204, 196), Color8(112, 170, 166), Color8(80, 132, 134)],
		"hair": [Color8(30, 96, 110), Color8(44, 136, 146), Color8(84, 180, 180)],
		"tunic": [Color8(214, 208, 190), Color8(170, 160, 140), Color8(240, 236, 222)], "ears": "fins", "long_hair": true, "eye": Color8(30, 80, 110)},
}


func _make_npcs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/characters/survivors"))
	for id in NPCS:
		_save(_make_npc(NPCS[id]), "res://assets/sprites/characters/survivors/%s.png" % id)


func _make_npc(d: Dictionary) -> Image:
	P = C.duplicate()
	if d.has("skin"):
		P.skin = d.skin[0]
		P.skin_dark = d.skin[1]
		P.skin_deep = d.skin[2]
	P.hair_dark = d.hair[0]
	P.hair = d.hair[1]
	P.hair_light = d.hair[2]
	P.tunic = d.tunic[0]
	P.tunic_dark = d.tunic[1]
	P.tunic_light = d.tunic[2]
	if d.has("eye"):
		P.eye = d.eye
	if d.has("legs"):
		P.pants = d.legs[0]
		P.pants_dark = d.legs[1]
	if d.has("hooves"):
		P.boot = d.hooves[0]
		P.boot_dark = d.hooves[1]
	var f := _new_image(CF, CF)
	var cx := 24.0
	var hy := 15.0
	var HA := [P.hair_dark.darkened(0.25), P.hair_dark, P.hair, P.hair_light]
	_draw_hero(f, 0, 0, d)
	var head := _cm_ellipse(Vector2(cx, hy), 10.0, 9.4)
	match d.get("beard", ""):
		"short":
			var m := _mask_add(_cmask(func(p: Vector2) -> bool: return head.has(Vector2i(p)) and p.y > hy + 4.5 and absf(p.x - cx) > 2.5 or head.has(Vector2i(p)) and p.y > hy + 7), _cm_ellipse(Vector2(cx, hy + 8.5), 6.0, 2.5))
			_shade_hair(f, m, Vector2(cx, hy + 4), 9.0, Vector2(cx, hy + 2), HA)
			_rect(f, int(cx) - 3, int(hy) + 5, 6, 1, HA[1])
			_rect(f, int(cx) - 1, int(hy) + 6, 2, 1, P.skin_deep)
		"long":
			var bt: Array = d.get("beard_tones", [P.hair, P.hair_light])
			var BT := [P.hair_dark, bt[0].darkened(0.15), bt[0], bt[1]]
			var m := _mask_add(_cmask(func(p: Vector2) -> bool: return head.has(Vector2i(p)) and p.y > hy + 4.5), _cm_poly(PackedVector2Array([Vector2(cx - 9, hy + 6), Vector2(cx + 9, hy + 6), Vector2(cx + 6, hy + 17), Vector2(cx, hy + 21), Vector2(cx - 6, hy + 17)])))
			_shade_hair(f, m, Vector2(cx, hy + 8), 12.0, Vector2(cx, hy + 3), BT)
			_rect(f, int(cx) - 4, int(hy) + 5, 8, 1, bt[1])
			_rect(f, int(cx) - 1, int(hy) + 7, 2, 1, BT[0])
	match d.get("ears", ""):
		"pointed":
			for s in [-1, 1]:
				_shade(f, _mask_add(_cm_stroke(Vector2(cx + s * 9.5, hy + 3), Vector2(cx + s * 15, hy - 3), 1.4), _cm_ellipse(Vector2(cx + s * 10, hy + 2.5), 1.8, 2.4)), [P.skin_deep, P.skin_dark, P.skin, P.skin.lightened(0.14)])
				_px(f, int(cx + s * 11.5), int(hy) + 1, P.skin_deep)
		"fins":
			for s in [-1, 1]:
				var m := _cm_poly(PackedVector2Array([Vector2(cx + s * 9, hy - 1), Vector2(cx + s * 15.5, hy - 4), Vector2(cx + s * 13.5, hy + 1), Vector2(cx + s * 15.5, hy + 5), Vector2(cx + s * 9, hy + 5)]))
				_shade(f, m, HA)
				for k in 3:
					_line(f, Vector2(cx + s * 9.5, hy + 1 + k), Vector2(cx + s * 14, hy - 3 + k * 4), HA[1])
	if d.get("horns", false):
		# Ram horns curling out of the hair at the temples.
		for s in [-1, 1]:
			var pts := [Vector2(cx + s * 6, hy - 7), Vector2(cx + s * 10, hy - 11), Vector2(cx + s * 13.5, hy - 9), Vector2(cx + s * 14, hy - 5), Vector2(cx + s * 11.5, hy - 3.5)]
			var m := {}
			for i in pts.size() - 1:
				m = _mask_add(m, _cm_stroke(pts[i], pts[i + 1], 2.0 - i * 0.35))
			_shade(f, m, BONE4)
			for i in range(1, pts.size() - 1):
				_px(f, int(pts[i].x), int(pts[i].y), BONE4[0])
	if d.get("beak", false):
		var OR := [Color8(150, 86, 34), Color8(196, 120, 40), Color8(232, 168, 60), Color8(250, 210, 120)]
		_shade(f, _cm_poly(PackedVector2Array([Vector2(cx - 3.5, hy + 4), Vector2(cx + 3.5, hy + 4), Vector2(cx + 0.5, hy + 11), Vector2(cx - 0.5, hy + 11)])), OR)
		_rect(f, int(cx) - 3, int(hy) + 6, 6, 1, OR[0])
		_px(f, int(cx) - 2, int(hy) + 4, OR[3])
	if d.get("helmet", false):
		var m := _mask_add(_cmask(func(p: Vector2) -> bool: return pow((p.x - cx) / 11.5, 2) + pow((p.y - hy + 1) / 10.5, 2) <= 1.0 and p.y < hy - 1), _cm_poly(PackedVector2Array([Vector2(cx - 12.5, hy - 2.5), Vector2(cx + 12.5, hy - 2.5), Vector2(cx + 12.5, hy + 0.5), Vector2(cx - 12.5, hy + 0.5)])))
		_shade(f, m, STEEL4)
		for yy in range(int(hy) - 11, int(hy) - 2):
			_px(f, int(cx) - 1, yy, STEEL4[3])
			_px(f, int(cx), yy, STEEL4[1])
		for rx in [-9, -5, 4, 8]:
			_px(f, int(cx) + rx, int(hy) - 1, STEEL4[3])
	_ink(f)
	P = C.duplicate()
	return f


# ---------------------------------------------------------------- trees

const TREE_TINT := [0.0, 0.05, -0.06, 0.08, 0.0, -0.08, 0.1, -0.03, 0.04, 0.0]
const TREE_FRUIT := {3: Color8(210, 70, 48), 8: Color8(210, 70, 48), 5: Color8(246, 214, 96)}


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

## Roof strip over closed rooms (scripts/world/visuals/roof.gd), four 32x32 tiles
## that tile sideways: back slope (foreshortened, sunlit), ridge, front
## slope, and the front slope's bottom row with its eave board.
const ROOF5 := [Color8(58, 30, 32), Color8(96, 46, 40), Color8(138, 66, 48), Color8(172, 94, 62), Color8(206, 136, 90)]


func _make_roof() -> Image:
	var img := _new_image(T * 4, T * ROOF_VARIANTS)
	for v in ROOF_VARIANTS:
		for tile in 4:
			_roof_tile(img, tile * T, v * T, tile, v)
	return img


const ROOF_VARIANTS := 3


func _roof_tile(img: Image, ox: int, oy: int, tile: int, v: int) -> void:
	for y in T:
		for x in T:
			var back := tile == 0 or (tile == 1 and y < 10)
			var sh := 4 if back else 8
			var yy := y if back else y - (18 if tile == 1 else 0)
			var row := yy / sh
			var gy := posmod(yy, sh)
			var gx := posmod(x + (row % 2) * 4, 8)
			var col_i := (x + (row % 2) * 4) / 8
			var jitter := (_hash(col_i, row + tile * 17, 601 + v * 7) - 0.5) * 0.18
			var base: Color = ROOF5[3] if back else ROOF5[2]
			var col := base.lightened(jitter) if jitter > 0.0 else base.darkened(-jitter)
			if gy == sh - 1:
				col = ROOF5[1] if back else ROOF5[0]
			elif gx == 7:
				col = ROOF5[1]
			elif gy == 0:
				col = ROOF5[4] if back else ROOF5[3]
			elif not back and gy == sh - 2:
				col = col.darkened(0.14 if gx in [0, 6] else 0.08)
			# Moss and lichen gather in a few clumps on the shaded front slope.
			if not back and _hash(x / 8, (y + oy) / 8, 604 + v) > 0.9 and _hash(x, y, 605 + v) > 0.2:
				col = C.moss_dark if gy >= sh - 2 else (C.moss if _hash(x, y, 606) > 0.4 else C.moss_light)
			img.set_pixel(ox + x, oy + y, col)
	if tile == 1:
		var beam := [C.outline, ROOF5[4], ROOF5[3], ROOF5[3], ROOF5[2], ROOF5[1], C.outline, ROOF5[0]]
		for i in beam.size():
			for x in T:
				var c: Color = beam[i]
				if i in [2, 3] and x % 8 == 7:
					c = ROOF5[1]
				img.set_pixel(ox + x, oy + 10 + i, c)
	if tile == 3:
		var eave := [ROOF5[0], C.wood_hi, C.wood_light, C.wood, C.wood_dark, C.outline]
		for i in eave.size():
			for x in T:
				var c: Color = eave[i]
				if i in [2, 3] and _hash(x / 4, i, 603 + v) > 0.8:
					c = C.wood
				img.set_pixel(ox + x, oy + 26 + i, c)

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



## 9-slice HUD frame (margins 3): ink rim with clipped corners, a bevelled
## brass edge and a faint top highlight over a translucent night-blue fill.
func _make_ui_frame() -> Image:
	var rows := [".kkkkkk.", "kLLLLLLk", "kLhhhhDk", "kLbbbbDk", "kLbbbbDk", "kLbbbbDk", "kDDDDDDk", ".kkkkkk."]
	var cols := {"k": Color8(14, 11, 14), "L": Color8(176, 152, 104), "D": Color8(104, 82, 56),
		"h": Color8(40, 36, 48, 236), "b": Color8(20, 18, 28, 228)}
	var img := _new_image(8, 8)
	for y in 8:
		for x in 8:
			var ch: String = rows[y][x]
			if cols.has(ch):
				img.set_pixel(x, y, cols[ch])
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
			_face_depth(img, 8, T - 3)
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
			return _st_workbench()
		"chest":
			return _st_chest()
		"furnace":
			return _st_furnace()
		"stone_wall":
			_wall_blocks(img, MAT["stone"], 261, false)
		"brick_wall":
			_wall_blocks(img, MAT["brick"], 271, true)
		"stone_floor":
			_paint_flagstones(img)
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
	_ink(img)
	return img


## Depth on a wall face spanning rows y0..y1-1: the cap's overhang shadow at
## the top and ambient occlusion deepening towards the ground.
func _face_depth(img: Image, y0: int, y1: int) -> void:
	var shade := {y0: 0.34, y0 + 1: 0.14, y1 - 3: 0.06, y1 - 2: 0.14, y1 - 1: 0.24}
	for y in shade:
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, c.darkened(shade[y]))


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
	_face_depth(img, 8, T - 1)
	if not brick:
		# Moss creeping up from the ground between the blocks.
		for i in 4:
			var mx := 3 + int(_hash(i, 1, seed) * 24.0)
			var mh := 1 + int(_hash(i, 2, seed) * 3.0)
			for k in mh:
				_px(img, mx, T - 2 - k, C.moss if k < mh - 1 else C.moss_light)
				if k == 0:
					_px(img, mx + 1, T - 2, C.moss_dark)
					_px(img, mx - 1, T - 2, C.moss)
	_rect(img, 1, 1, T - 2, 7, tones[3])
	_rect(img, 1, 1, T - 2, 1, tones[4])
	_rect(img, 1, 7, T - 2, 1, tones[1])
	for x in range(1, T - 1, 4):
		_px(img, x + int(_hash(x, 0, seed) * 3.0), 3, tones[2])


## Vertical wall runs (see BuildCatalog.wall_join): the wall's top surface
## carries on from tile to tile, and only the bottom tile shows its face.
##   _run_top: wall below only; _run_mid: walls above and below;
##   _run_end: the face at the bottom of a run (wall above only).
func _make_wall_joins() -> void:
	for kind in ["wooden_wall", "stone_wall", "brick_wall"]:
		var top := _new_image(T, T)
		_wall_top_surface(top, kind, 1, T)
		_ink(top)
		_save(top, "res://assets/sprites/structures/%s_run_top.png" % kind)
		var mid := _new_image(T, T)
		_wall_top_surface(mid, kind, 0, T)
		_rect(mid, 0, 0, 1, T, C.outline)
		_rect(mid, T - 1, 0, 1, T, C.outline)
		_save(mid, "res://assets/sprites/structures/%s_run_mid.png" % kind)
		var end := _make_structure(kind)
		_wall_top_surface(end, kind, 0, 7)
		_save(end, "res://assets/sprites/structures/%s_run_end.png" % kind)


## The top of a wall seen from above, rows y0..y1-1 between x 1 and T-2:
## planks along the run for wood, capstones for masonry.
func _wall_top_surface(img: Image, kind: String, y0: int, y1: int) -> void:
	if kind == "wooden_wall":
		for y in range(y0, y1):
			for x in range(1, T - 1):
				var p := (x - 1) / 10
				var xx := (x - 1) % 10
				var tone := (_hash(p, 3, 214) - 0.5) * 0.14
				var joint := int(_hash(p, 4, 215) * 24.0) + 4
				var col: Color = C.wood_light.lightened(tone)
				if xx == 0:
					col = C.wood_hi.lightened(tone)
				elif xx == 9:
					col = C.wood_dark
				elif y == joint:
					col = C.wood_deep
				elif _hash(x, y / 3, 216) > 0.8:
					col = C.wood
				_px(img, x, y, col)
			if y % 16 == 8:
				for p in 3:
					_px(img, 5 + p * 10, y, C.iron_dark)
		return
	var tones: Array = MAT["brick" if kind == "brick_wall" else "stone"]
	var seed := 271 if kind == "brick_wall" else 261
	for y in range(y0, y1):
		var row := y / 8
		for x in range(1, T - 1):
			var col: Color = tones[3].lightened((_hash(x / 8, row, seed + 5) - 0.5) * 0.1)
			if y % 8 == 7:
				col = tones[1]
			elif y % 8 == 0:
				col = tones[4]
			elif x == 1:
				col = tones[4]
			elif x == T - 2:
				col = tones[2]
			elif _hash(x, y, seed + 6) > 0.9:
				col = tones[2]
			_px(img, x, y, col)


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
		_save(big, "res://assets/ui/icons/items/%s.png" % id)
		var small := big.duplicate() as Image
		small.resize(16, 16, Image.INTERPOLATE_LANCZOS)
		_save(small, "res://assets/ui/icons/items/small/%s.png" % id)


const BERRY := [Color8(110, 24, 52), Color8(168, 36, 70), Color8(214, 70, 96), Color8(250, 150, 160)]


func _berry(img: Image, x: int, y: int) -> void:
	_rect(img, x, y, 3, 3, BERRY[1])
	_px(img, x, y + 2, BERRY[0])
	_px(img, x + 1, y + 2, BERRY[0])
	_px(img, x + 2, y + 1, BERRY[0])
	_px(img, x, y, BERRY[2])
	_px(img, x + 1, y, BERRY[3])


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


# ---------------------------------------------------------------- biome art (M10)
# Creature sprites and gear/potion icons are vendored Dungeon Crawl Stone Soup
# tiles (CC0, OpenGameArt) under tools/third_party/dcss, re-outlined to match.
# Everything else below is procedural, built from a few shaded primitives.

const DCSS := "res://tools/third_party/dcss"
const BRONZE5 := [Color8(96, 58, 26), Color8(146, 96, 40), Color8(196, 140, 62), Color8(226, 182, 98), Color8(246, 222, 150)]
const OBSID5 := [Color8(14, 10, 22), Color8(30, 22, 44), Color8(52, 40, 76), Color8(92, 76, 128), Color8(160, 146, 200)]
const SILVER5 := [Color8(90, 96, 112), Color8(140, 148, 164), Color8(188, 196, 210), Color8(222, 228, 238), Color8(250, 252, 255)]
const TIN5 := [Color8(80, 86, 90), Color8(120, 128, 130), Color8(160, 168, 166), Color8(196, 204, 200), Color8(230, 236, 232)]
const WHITE5 := [Color8(150, 146, 140), Color8(196, 192, 184), Color8(228, 224, 216), Color8(244, 242, 236), Color8(255, 255, 252)]
const AMBER5 := [Color8(110, 52, 10), Color8(170, 90, 20), Color8(220, 140, 40), Color8(246, 190, 80), Color8(255, 234, 160)]
const SULF5 := [Color8(120, 100, 20), Color8(170, 150, 30), Color8(220, 200, 60), Color8(244, 230, 110), Color8(255, 250, 190)]
const SLIME5 := [Color8(30, 80, 40), Color8(60, 130, 60), Color8(100, 180, 80), Color8(150, 220, 120), Color8(210, 250, 190)]
const VENOM5 := [Color8(50, 20, 60), Color8(90, 40, 110), Color8(140, 70, 160), Color8(190, 120, 200), Color8(230, 190, 240)]
const GLOW5 := [Color8(20, 70, 90), Color8(30, 120, 140), Color8(60, 190, 200), Color8(130, 240, 240), Color8(220, 255, 255)]
const BLUE5 := [Color8(24, 30, 70), Color8(44, 56, 120), Color8(70, 90, 170), Color8(120, 140, 210), Color8(190, 200, 250)]
const CARROT5 := [Color8(130, 50, 14), Color8(190, 84, 24), Color8(234, 124, 40), Color8(250, 166, 80), Color8(255, 214, 150)]
const POTATO5 := [Color8(96, 66, 36), Color8(140, 100, 58), Color8(180, 138, 86), Color8(208, 170, 116), Color8(230, 204, 156)]
const WHEAT5 := [Color8(120, 86, 30), Color8(170, 130, 50), Color8(214, 176, 80), Color8(238, 210, 120), Color8(252, 238, 180)]
const SAND5 := [Color8(150, 120, 74), Color8(190, 158, 104), Color8(222, 192, 134), Color8(238, 214, 162), Color8(250, 236, 196)]
const FUR5 := [Color8(60, 58, 56), Color8(96, 92, 88), Color8(136, 130, 122), Color8(176, 170, 160), Color8(214, 208, 198)]
const CHITIN5 := [Color8(30, 40, 30), Color8(50, 70, 46), Color8(80, 104, 60), Color8(120, 140, 80), Color8(170, 184, 120)]
const SCALE5 := [Color8(20, 60, 50), Color8(30, 96, 76), Color8(50, 138, 104), Color8(90, 180, 140), Color8(160, 220, 190)]
const PURPLE5 := [Color8(40, 16, 50), Color8(80, 30, 96), Color8(124, 54, 140), Color8(170, 96, 186), Color8(220, 170, 230)]
const PINK5 := [Color8(120, 40, 70), Color8(180, 70, 110), Color8(230, 120, 150), Color8(246, 170, 190), Color8(255, 220, 230)]
const CRUST5 := [Color8(110, 70, 30), Color8(160, 106, 50), Color8(204, 146, 72), Color8(230, 184, 104), Color8(248, 220, 150)]
const SOIL5 := [Color8(50, 34, 24), Color8(78, 54, 36), Color8(104, 74, 50), Color8(130, 96, 64), Color8(156, 120, 82)]
const GLASS5 := [Color8(60, 110, 130), Color8(110, 170, 190), Color8(170, 220, 230), Color8(210, 240, 246), Color8(250, 255, 255)]
const RED5 := [Color8(90, 20, 20), Color8(150, 36, 30), Color8(200, 60, 44), Color8(232, 104, 80), Color8(250, 170, 150)]

const DCSS_ICONS := ["apple", "honey", "flatbread", "hunter_feast", "fruit_salad", "healing_potion", "greater_potion",
	"antidote", "stamina_tonic", "glass_vial", "flint_knife", "wooden_club", "flint_spear", "tusk_dagger", "bronze_spear",
	"iron_spear", "war_hammer", "venom_dagger", "silver_sword", "horn_halberd", "short_bow", "long_bow", "bone_bow",
	"crossbow", "arc_staff", "flint_arrow", "iron_arrow", "blast_arrow", "wool_tunic", "fur_coat", "scale_vest",
	"chitin_armor", "silk_robe", "straw_hat", "fur_hood", "chitin_helm", "horned_helm", "reed_sandals", "fur_boots",
	"wooden_shield", "shell_shield", "bronze_shield", "iron_shield", "obsidian_shield", "silver_ring", "gold_ring",
	"quartz_ring", "obsidian_ring", "feather_charm", "fang_necklace", "glow_amulet", "gold_amulet", "shadow_amulet",
	"spark_core", "glow_gland"]


func _make_biome_art() -> void:
	_import_creatures()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/environment/crops"))
	for crop in FarmingScript.CROPS:
		var def: Dictionary = FarmingScript.CROPS[crop]
		var col := _item_color(def.yield)
		for stage in [1, 2]:
			_save(_make_crop(def.shape, col, stage), "res://assets/sprites/environment/crops/%s_%d.png" % [crop, stage])
	_save(_make_structure_m10("loom"), "res://assets/sprites/structures/loom.png")
	_save(_make_structure_m10("alchemy_table"), "res://assets/sprites/structures/alchemy_table.png")
	var nodes := _biome_nodes()
	for id in nodes:
		_save(nodes[id], "res://assets/sprites/environment/gatherables/%s.png" % id)
	var icons := _biome_icons()
	for id in DCSS_ICONS:
		icons[id] = _dcss("items/" + id)
	icons["loom"] = _make_structure_m10("loom")
	icons["alchemy_table"] = _make_structure_m10("alchemy_table")
	for id in icons:
		var big: Image = icons[id]
		_save(big, "res://assets/ui/icons/items/%s.png" % id)
		var small := big.duplicate() as Image
		small.resize(16, 16, Image.INTERPOLATE_LANCZOS)
		_save(small, "res://assets/ui/icons/items/small/%s.png" % id)


## Copies every vendored creature tile to assets/sprites/enemies.
func _import_creatures() -> void:
	var dir := DirAccess.open(DCSS + "/monsters")
	if dir == null:
		push_error("Missing %s/monsters" % DCSS)
		return
	for f in dir.get_files():
		if f.ends_with(".png"):
			var id := f.get_basename()
			_save(_fit_creature(_dcss("monsters/" + id, false), EnemyCatalogScript.size_of(id)), "res://assets/sprites/enemies/" + f)


const EnemyCatalogScript := preload("res://scripts/data/enemy_catalog.gd")
const FarmingScript := preload("res://scripts/systems/farming.gd")

const STEM5 := [Color8(28, 60, 30), Color8(44, 88, 40), Color8(70, 124, 52), Color8(108, 160, 70), Color8(156, 200, 104)]


## Item colour read from the catalog source (ItemCatalog needs autoloads to compile).
func _item_color(id: String) -> Color:
	var src := FileAccess.get_file_as_string("res://scripts/data/item_catalog.gd")
	var re := RegEx.create_from_string('"%s": \\{[^\\n]*?"color": Color8\\((\\d+), (\\d+), (\\d+)\\)' % id)
	var m := re.search(src)
	if m == null:
		push_error("No colour for %s" % id)
		return Color.MAGENTA
	return Color8(int(m.get_string(1)), int(m.get_string(2)), int(m.get_string(3)))


## 32x32 crop overlay for a farm plot (transparent; drawn over the tilled soil).
## Stage 1 = sprouts, stage 2 = ripe plants bearing the crop's colour.
func _make_crop(shape: String, col: Color, stage: int) -> Image:
	var img := _new_image(32, 32)
	var fruit := [col.darkened(0.55), col.darkened(0.3), col, col.lightened(0.25), col.lightened(0.55)]
	var spots := [Vector2(9, 14), Vector2(23, 14), Vector2(9, 28), Vector2(23, 28)]
	if shape == "tree":
		spots = [Vector2(16, 28)]
	for i in spots.size():
		var f: Vector2 = spots[i]
		if stage == 1:
			_bevel(img, _mask_stroke(f, f + Vector2(0, -3), 0.6), STEM5)
			_leaf(img, f + Vector2(0, -3), PI * 1.15, 4.5, STEM5)
			_leaf(img, f + Vector2(0, -3), -PI * 0.15, 4.5, STEM5)
			if shape == "tree":
				_bevel(img, _mask_stroke(f, f + Vector2(0, -7), 1.0), WOOD5)
				_leaf(img, f + Vector2(0, -7), -PI * 0.5, 5.0, STEM5)
			continue
		match shape:
			"bush":
				_blob(img, f.x, f.y - 5, 6, 5, STEM5, 0.25, 900 + i)
				for d in [Vector2(-3, -7), Vector2(2, -8), Vector2(3, -4), Vector2(-2, -3)]:
					_berry_dot(img, f + d, fruit, 1.5)
			"root":
				_bevel(img, _mask_ellipse(f + Vector2(0, -1), 3.0, 1.8), fruit)
				for a in [-PI * 0.75, -PI * 0.5, -PI * 0.25]:
					_leaf(img, f + Vector2(0, -2), a, 8.0, STEM5)
			"stalk":
				_leaf(img, f, PI * 1.1, 5.0, STEM5)
				_leaf(img, f, -PI * 0.1, 5.0, STEM5)
				for dx in [-3, 0, 3]:
					var top := f + Vector2(dx * 1.6, -9 + absi(dx) * 0.5)
					for y in range(int(top.y) + 2, int(f.y) + 1):
						var t := (f.y - y) / (f.y - top.y)
						_px(img, int(round(f.x + dx * 0.5 + (top.x - f.x - dx * 0.5) * t)), y, STEM5[2] if col.v <= 0.5 else fruit[1])
					for k in 3:
						_px(img, int(top.x) - 1, int(top.y) + k, fruit[3] if k == 0 else fruit[2])
						_px(img, int(top.x), int(top.y) + k - 1, fruit[4] if k == 0 else fruit[3])
			"flower":
				_bevel(img, _mask_stroke(f, f + Vector2(0, -8), 0.6), STEM5)
				_leaf(img, f + Vector2(0, -3), PI * 1.2, 5.0, STEM5)
				_leaf(img, f + Vector2(0, -4), -PI * 0.2, 5.0, STEM5)
				for k in 5:
					var a := TAU * k / 5.0 - PI / 2.0
					_berry_dot(img, f + Vector2(0, -9) + Vector2(cos(a), sin(a)) * 2.4, fruit, 1.5)
				_px(img, int(f.x), int(f.y - 9), Color8(250, 220, 90))
			"cap":
				_bevel(img, _mask_stroke(f, f + Vector2(0, -4), 1.0), [Color8(150, 130, 100), Color8(190, 172, 140), Color8(222, 208, 180), Color8(236, 226, 204), Color8(250, 244, 230)])
				_bevel(img, _mask_cut(_mask_ellipse(f + Vector2(0, -5), 5.0, 3.6), _mask_fn(func(p: Vector2) -> bool: return p.y > f.y - 4.5)), fruit)
				_px(img, int(f.x - 2), int(f.y - 7), fruit[4])
			"tree":
				_bevel(img, _mask_stroke(f, f + Vector2(0, -10), 1.6), WOOD5)
				_blob(img, f.x, f.y - 17, 10, 8, STEM5, 0.25, 950)
				_blob(img, f.x - 5, f.y - 14, 5, 4, STEM5, 0.25, 951)
				for d in [Vector2(-5, -18), Vector2(3, -20), Vector2(6, -14), Vector2(-2, -13), Vector2(1, -17)]:
					_berry_dot(img, f + d, fruit, 1.8)
	_outline(img, Color8(28, 34, 22))
	return img


## Catalog sizes were tuned for the old 32 px hero; creatures now stand next to
## a 42 px one.
const CREATURE_SCALE := 1.4


## Crops a creature to its pixels and fits its longest side to the catalog size
## (x CREATURE_SCALE). The source art is kept at its native 1:1 detail whenever
## it fits, doubled with scale2x for the big ones; only tiny critters are
## filtered down. Finished with the same rim light and outline as our sprites.
func _fit_creature(src: Image, size: int) -> Image:
	var used := src.get_used_rect()
	var body := src.get_region(used)
	var target := mini(int(round(size * CREATURE_SCALE)), 88) - 2
	var native := maxi(used.size.x, used.size.y)
	var big := body
	if target >= native * 1.75:
		big = _scale2x(body)
	elif target < native * 0.9:
		var k := float(target) / native
		big = _scale2x(body)
		big.resize(maxi(int(round(used.size.x * k)), 1), maxi(int(round(used.size.y * k)), 1), Image.INTERPOLATE_LANCZOS)
	var w := big.get_width()
	var h := big.get_height()
	var img := _new_image(w + 2, h + 2)
	for y in h:
		for x in w:
			var c := big.get_pixel(x, y)
			if c.a >= 0.5:
				img.set_pixel(x + 1, y + 1, Color(c.r, c.g, c.b, 1.0))
	_ink(img)
	return img


## EPX / Scale2x: doubles pixel art while keeping diagonal edges smooth.
func _scale2x(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	var g := func(x: int, y: int) -> Color: return src.get_pixel(clampi(x, 0, w - 1), clampi(y, 0, h - 1))
	for y in h:
		for x in w:
			var p: Color = g.call(x, y)
			var a: Color = g.call(x, y - 1)
			var b: Color = g.call(x + 1, y)
			var c: Color = g.call(x - 1, y)
			var d: Color = g.call(x, y + 1)
			out.set_pixel(x * 2, y * 2, a if c == a and c != d and a != b else p)
			out.set_pixel(x * 2 + 1, y * 2, b if a == b and a != c and b != d else p)
			out.set_pixel(x * 2, y * 2 + 1, c if d == c and d != b and c != a else p)
			out.set_pixel(x * 2 + 1, y * 2 + 1, d if b == d and b != a and d != c else p)
	return out


## Loads a vendored 32px tile, hardens its alpha and adds our dark outline.
func _dcss(rel: String, outline := true) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s.png" % [DCSS, rel]))
	if img == null:
		push_error("Missing DCSS tile " + rel)
		return _new_image(T, T)
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != T or img.get_height() != T:
		img.resize(T, T, Image.INTERPOLATE_NEAREST)
	for y in T:
		for x in T:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(0, 0, 0, 0) if c.a < 0.5 else Color(c.r, c.g, c.b, 1.0))
	if outline:
		_outline(img, C.outline)
	return img


# ---- primitives

func _rough(c: Vector2, r: float, sides: int, seed: int, squash := 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a := TAU * i / sides + _hash(i, 0, seed) * 0.5
		var rr := r * (0.75 + _hash(i, 1, seed) * 0.35)
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * squash))
	return pts


func _speck(img: Image, mask: Dictionary, col: Color, chance: float, seed: int) -> void:
	for p in mask:
		if _hash(p.x, p.y, seed) > 1.0 - chance:
			_px(img, p.x, p.y, col)


func _fin(img: Image) -> Image:
	_outline(img, C.outline)
	return img


## Heap of irregular chunks (minerals, goo, powders).
func _i_lump(tones: Array, seed: int, n := 3) -> Image:
	var img := _new_image(T, T)
	var cs := [Vector2(11, 20), Vector2(21, 21), Vector2(16, 13)]
	var rs := [7.0, 7.0, 6.5]
	for i in n:
		var m := _mask_poly(_rough(cs[i], rs[i], 7, seed + i * 7))
		_bevel(img, m, tones)
		_speck(img, m, tones[4], 0.06, seed + 50 + i)
	return _fin(img)


func _i_shard(tones: Array, seed: int) -> Image:
	var img := _new_image(T, T)
	var j := func(v: Vector2, i: int) -> Vector2: return v + Vector2(_hash(i, 1, seed) - 0.5, _hash(i, 2, seed) - 0.5) * 4.0
	_bevel(img, _mask_poly(PackedVector2Array([j.call(Vector2(5, 22), 0), j.call(Vector2(13, 5), 1), j.call(Vector2(25, 8), 2), j.call(Vector2(27, 20), 3), j.call(Vector2(17, 28), 4)])), tones)
	_line(img, Vector2(13, 8), Vector2(17, 25), tones[3])
	_line(img, Vector2(14, 7), Vector2(23, 10), tones[4])
	_line(img, Vector2(17, 25), Vector2(25, 19), tones[1])
	return _fin(img)


func _crystals(img: Image, base: Vector2, tones: Array, s := 1.0) -> void:
	for k in [[-5.0, 10.0, -0.4], [5.0, 11.0, 0.35], [0.0, 16.0, 0.0]]:
		var dir := Vector2(sin(k[2]), -cos(k[2]))
		var side := Vector2(-dir.y, dir.x) * 2.8 * s
		var root := base + Vector2(k[0], 0) * s
		var shoulder: Vector2 = root + dir * (k[1] - 3.5) * s
		var tip: Vector2 = root + dir * k[1] * s
		_bevel(img, _mask_poly(PackedVector2Array([root - side, shoulder - side, tip, shoulder + side, root + side])), tones)
		_line(img, root + dir * s, tip - dir * 2.0, tones[4])


func _i_crystals(tones: Array) -> Image:
	var img := _new_image(T, T)
	_crystals(img, Vector2(16, 28), tones, 1.3)
	return _fin(img)


func _i_sack(cloth: Array, content: Array, sparkle := Color(0, 0, 0, 0)) -> Image:
	var img := _new_image(T, T)
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(9, 12), Vector2(23, 12), Vector2(27, 21), Vector2(25, 29), Vector2(7, 29), Vector2(5, 21)])), cloth)
	_bevel(img, _mask_ellipse(Vector2(16, 12), 8, 3), cloth)
	_bevel(img, _mask_ellipse(Vector2(16, 11.5), 6, 2), content)
	_bevel(img, _mask_ellipse(Vector2(16, 9), 4, 3), content)
	_line(img, Vector2(9, 15), Vector2(23, 15), cloth[0])
	for p in [Vector2i(10, 22), Vector2i(14, 19), Vector2i(20, 24), Vector2i(22, 18)]:
		_px(img, p.x, p.y, cloth[1])
	if sparkle.a > 0:
		for p in [Vector2i(9, 5), Vector2i(23, 6), Vector2i(26, 12), Vector2i(5, 10)]:
			_px(img, p.x, p.y, sparkle)
			_px(img, p.x + 1, p.y, sparkle.darkened(0.3))
	return _fin(img)


## Three stacked folds of fabric.
func _i_bolt(tones: Array, stripe: Color) -> Image:
	var img := _new_image(T, T)
	for i in 3:
		var y := 21 - i * 6
		_bevel(img, _mask_poly(PackedVector2Array([Vector2(5 + i, y), Vector2(27 - i, y - 2), Vector2(27 - i, y + 5), Vector2(5 + i, y + 7)])), tones)
		_line(img, Vector2(6 + i, y + 3), Vector2(26 - i, y + 1), stripe)
	return _fin(img)


## Ball of thread or yarn.
func _i_ball(tones: Array, strand: Color) -> Image:
	var img := _new_image(T, T)
	_blob(img, 16, 17, 10, 10, [tones[1], tones[2], tones[3], tones[4]], 0.1, 960)
	for k in 3:
		var rot := 0.6 + k * 0.95
		for s in 48:
			var a := TAU * s / 48.0
			if sin(a) > 0.0:
				var p := Vector2(cos(a) * 8.5, sin(a) * 3.0).rotated(rot) + Vector2(16, 17)
				_px(img, int(p.x), int(p.y), strand)
	_line(img, Vector2(24, 23), Vector2(29, 29), tones[2])
	return _fin(img)


func _i_coil(tones: Array, leaves := false) -> Image:
	var img := _new_image(T, T)
	for k in 4:
		var r := 11.0 - k * 2.3
		for s in 72:
			var a := TAU * s / 72.0
			var p := Vector2(16 + cos(a) * r, 18 + sin(a) * r * 0.6)
			_rect(img, int(p.x), int(p.y), 2, 2, tones[1 + (k + int(sin(a) < 0.0)) % 4])
	if leaves:
		for c in [Vector2(6, 15), Vector2(25, 21), Vector2(13, 25), Vector2(20, 11)]:
			_bevel(img, _mask_ellipse(c, 3.0, 2.0), LEAF5)
	return _fin(img)


## Tapering curved spike from a to b (tusk, horn, fang).
func _i_horn(tones: Array, a: Vector2, b: Vector2, bend: float, thick: float, rings := false) -> Image:
	var img := _new_image(T, T)
	var m := {}
	var perp := (b - a).normalized().rotated(PI / 2)
	for i in 15:
		var t := i / 14.0
		var p := a.lerp(b, t) + perp * sin(t * PI) * bend
		var r := maxf(0.8, thick * (1.0 - t * 0.85))
		m = _mask_add(m, _mask_ellipse(p, r, r))
	_bevel(img, m, tones)
	if rings:
		for t in [0.15, 0.3, 0.45]:
			var p := a.lerp(b, t) + perp * sin(t * PI) * bend
			_line(img, p - perp.rotated(0.3) * thick, p + perp.rotated(0.3) * thick * 0.8, tones[1])
	return _fin(img)


func _mush(img: Image, cx: float, base_y: float, s: float, cap: Array) -> void:
	_bevel(img, _mask_stroke(Vector2(cx, base_y), Vector2(cx, base_y - 4.0 * s), 1.2 * s), MAT["bone"])
	var top := base_y - 4.0 * s
	_bevel(img, _mask_cut(_mask_ellipse(Vector2(cx, top), 4.2 * s, 3.0 * s), _mask_fn(func(p: Vector2) -> bool: return p.y > top + 0.6 * s)), cap)
	for d in [Vector2(-1.6, -1.6), Vector2(1.4, -2.2), Vector2(2.6, -0.6)]:
		_px(img, int(cx + d.x * s), int(top + d.y * s), cap[4])


func _berry_dot(img: Image, c: Vector2, tones: Array, r := 2.4) -> void:
	_bevel(img, _mask_ellipse(c, r, r), tones)
	_px(img, int(c.x - r * 0.4), int(c.y - r * 0.4), tones[4])


func _leaf(img: Image, c: Vector2, ang: float, len: float, tones: Array) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x) * len * 0.35
	_bevel(img, _mask_poly(PackedVector2Array([c, c + d * len * 0.5 + n, c + d * len, c + d * len * 0.5 - n])), tones)


# ---- item icons

func _biome_icons() -> Dictionary:
	var ic := {}
	var bone: Array = MAT["bone"]
	ic["flint"] = _i_shard([Color8(30, 30, 38), Color8(56, 58, 68), Color8(90, 92, 104), Color8(130, 132, 142), Color8(180, 182, 190)], 11)
	ic["reed"] = _i_bundle(LEAF5, HIDE5, "reed")
	ic["wheat"] = _i_bundle(WHEAT5, WHEAT5, "wheat")
	ic["herb"] = _i_sprig(LEAF5, Color8(240, 240, 250))
	ic["cotton"] = _i_cotton()
	ic["resin"] = _i_drop(AMBER5)
	ic["slime"] = _i_drop(SLIME5)
	ic["ectoplasm"] = _i_drop([Color8(60, 110, 110), Color8(110, 180, 170), Color8(170, 230, 210), Color8(210, 250, 236), Color8(245, 255, 250)])
	ic["egg"] = _i_egg()
	ic["carrot"] = _i_carrot(CARROT5, false)
	ic["roasted_carrot"] = _i_carrot([COOK5[0], COOK5[1], CARROT5[1], CARROT5[2], CARROT5[3]], true)
	ic["potato"] = _i_potato(POTATO5, false)
	ic["baked_potato"] = _i_potato(COOK5, true)
	ic["blueberry"] = _i_berries(BLUE5)
	ic["petals"] = _i_petals(PINK5, 970)
	ic["shadow_petal"] = _i_petals(PURPLE5, 975)
	ic["sand"] = _i_pile(SAND5, 980)
	ic["tin_ore"] = _ic_ore(MAT["stone"], TIN5, 733)
	ic["silver_ore"] = _ic_ore(MAT["stone"], SILVER5, 734)
	ic["gold_ore"] = _ic_ore(MAT["stone"], GOLD5, 735)
	ic["quartz"] = _i_crystals(WHITE5)
	ic["obsidian"] = _i_shard(OBSID5, 21)
	ic["sulfur"] = _i_lump(SULF5, 990)
	ic["saltpeter"] = _i_lump(WHITE5, 995)
	ic["glowcap"] = _i_glowcap()
	ic["moss"] = _i_lump(LEAF5, 1000)
	ic["vine"] = _i_coil(LEAF5, true)
	ic["scrap"] = _i_scrap()
	ic["cog"] = _i_cog(MAT["iron"])
	ic["silk"] = _i_ball(WHITE5, WHITE5[1])
	ic["wool"] = _i_wool()
	ic["wing_dust"] = _i_sack(HIDE5, PINK5, Color8(255, 240, 160))
	ic["spores"] = _i_sack(LEAF5, [CAP5[1], CAP5[2], CAP5[3], CAP5[4], WHITE5[4]], CAP5[4])
	ic["tusk"] = _i_horn(bone, Vector2(6, 26), Vector2(26, 6), 5.0, 3.6)
	ic["horn"] = _i_horn([Color8(50, 36, 30), Color8(86, 64, 50), Color8(128, 100, 80), Color8(170, 140, 112), Color8(214, 190, 160)], Vector2(7, 27), Vector2(25, 5), 7.0, 4.5, true)
	ic["fang"] = _i_horn(bone, Vector2(12, 6), Vector2(19, 27), 3.0, 4.0)
	ic["fur"] = _i_pelt(FUR5)
	ic["venom_sac"] = _i_sac(VENOM5)
	ic["glow_gland"] = _i_sac(GLOW5)
	ic["chitin"] = _i_plate(CHITIN5)
	ic["scale"] = _i_scales(SCALE5)
	ic["shell"] = _i_shell()
	ic["feather"] = _i_feather()
	ic["flour"] = _i_sack([Color8(130, 110, 80), Color8(170, 150, 110), Color8(204, 186, 146), Color8(226, 212, 176), Color8(240, 232, 206)], WHITE5)
	ic["gunpowder"] = _i_sack(HIDE5, MAT["coal"], C.fire_mid)
	ic["glass"] = _i_glass()
	ic["cloth"] = _i_bolt([Color8(120, 100, 70), Color8(160, 140, 100), Color8(200, 182, 138), Color8(222, 206, 166), Color8(238, 228, 196)], Color8(140, 70, 50))
	ic["silk_cloth"] = _i_bolt(WHITE5, Color8(180, 150, 210))
	ic["felt"] = _i_bolt(RED5, RED5[4])
	ic["bronze_ingot"] = _ic_ingots(BRONZE5)
	ic["silver_ingot"] = _ic_ingots(SILVER5)
	ic["gold_ingot"] = _ic_ingots(GOLD5)
	ic["glue"] = _i_pot(MAT["clay"], AMBER5)
	ic["dye"] = _ic_bowl([RED5[2], RED5[1]], [BLUE5[2], SULF5[3], LEAF5[3], PURPLE5[3]], false)
	ic["bowstring"] = _i_coil(WHITE5)
	for m in [["bronze", BRONZE5], ["obsidian", OBSID5]]:
		ic[m[0] + "_axe"] = _ic_axe(m[1])
		ic[m[0] + "_pickaxe"] = _ic_pickaxe(m[1])
	ic["bronze_sword"] = _icon_sword(BRONZE5)
	ic["obsidian_blade"] = _icon_sword(OBSID5)
	ic["bronze_armor"] = _ic_armor(BRONZE5, false)
	ic["obsidian_plate"] = _ic_armor(OBSID5, false)
	ic["bronze_helm"] = _ic_helm(BRONZE5, "copper")
	ic["obsidian_helm"] = _ic_helm(OBSID5, "iron")
	ic["bronze_boots"] = _ic_boots(BRONZE5, MAT["leather"])
	ic["obsidian_boots"] = _ic_boots(OBSID5, PURPLE5)
	ic["fried_egg"] = _i_fried_egg()
	ic["candied_apple"] = _i_candied_apple()
	ic["omelette"] = _i_omelette()
	ic["porridge"] = _ic_bowl([Color8(236, 222, 186), Color8(206, 188, 146)], [WHEAT5[3], BERRY[2], Color8(240, 230, 200)], true)
	ic["carrot_soup"] = _ic_bowl([CARROT5[3], CARROT5[2]], [CARROT5[1], LEAF5[3], CARROT5[4]], true)
	ic["vegetable_stew"] = _ic_bowl([COOK5[3], COOK5[2]], [CARROT5[2], POTATO5[3], LEAF5[3], COOK5[0]], true)
	ic["glowcap_broth"] = _ic_bowl([GLOW5[3], GLOW5[2]], [GLOW5[4], CAP5[3], LEAF5[3]], true)
	ic["apple_pie"] = _i_pie(RED5)
	ic["blueberry_pie"] = _i_pie(BLUE5)
	ic["honey_cake"] = _i_cake()
	ic["moss_poultice"] = _i_poultice()
	ic["bandage"] = _i_bandage()
	ic["healing_salve"] = _i_pot(MAT["iron"], SLIME5)
	return ic


func _i_bundle(stem: Array, head: Array, kind: String) -> Image:
	var img := _new_image(T, T)
	for i in 5:
		var a := Vector2(12 + i * 2, 29)
		var b := Vector2(5 + i * 5.5, 7 + absf(i - 2) * 2.5)
		_line(img, a, b, stem[1 + i % 3])
		if kind == "wheat":
			_bevel(img, _mask_ellipse(b, 2.2, 4.2), head)
			for k in 3:
				_px(img, int(b.x) - 2, int(b.y) - 2 + k * 2, head[1])
		else:
			_bevel(img, _mask_stroke(b, b + (a - b).normalized() * 7.0, 1.7), head)
	_line(img, Vector2(10, 21), Vector2(22, 21), WOOD5[3], 2)
	_line(img, Vector2(10, 22), Vector2(22, 22), WOOD5[1])
	return _fin(img)


func _i_sprig(tones: Array, flower: Color) -> Image:
	var img := _new_image(T, T)
	_line(img, Vector2(16, 29), Vector2(16, 6), tones[1], 2)
	for i in 5:
		var s := -1.0 if i % 2 == 0 else 1.0
		_leaf(img, Vector2(16, 11 + i * 4), PI * 0.5 - s * PI * 0.4 - PI * 0.5 * (1 - s), 9.0, tones)
	for d in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		_px(img, 16 + int(d.x), 5 + int(d.y), flower)
	_px(img, 16, 5, SULF5[3])
	return _fin(img)


func _i_cotton() -> Image:
	var img := _new_image(T, T)
	_line(img, Vector2(16, 29), Vector2(16, 14), WOOD5[2], 2)
	_line(img, Vector2(16, 20), Vector2(9, 13), WOOD5[2])
	_line(img, Vector2(16, 18), Vector2(23, 11), WOOD5[2])
	for c in [Vector2(9, 11), Vector2(23, 9), Vector2(16, 10)]:
		_blob(img, c.x, c.y, 5, 4.5, [WHITE5[1], WHITE5[2], WHITE5[3], WHITE5[4]], 0.2, 1010)
		_px(img, int(c.x), int(c.y) + 4, WOOD5[1])
	return _fin(img)


func _i_drop(tones: Array) -> Image:
	var img := _new_image(T, T)
	var m := _mask_add(_mask_ellipse(Vector2(16, 20), 8, 8), _mask_poly(PackedVector2Array([Vector2(16, 4), Vector2(23, 17), Vector2(9, 17)])))
	_bevel(img, m, tones)
	_rect(img, 12, 16, 2, 4, tones[4])
	_px(img, 13, 14, tones[4])
	return _fin(img)


func _i_egg() -> Image:
	var img := _new_image(T, T)
	var t := [Color8(170, 150, 120), Color8(210, 190, 156), Color8(236, 222, 190), Color8(248, 240, 216), Color8(255, 252, 240)]
	_blob(img, 16, 17, 8, 11, [t[1], t[2], t[3], t[4]], 0.04, 1020)
	for i in 6:
		_px(img, 11 + int(_hash(i, 1, 1021) * 10.0), 10 + int(_hash(i, 2, 1021) * 14.0), Color8(170, 120, 90))
	return _fin(img)


func _i_carrot(tones: Array, roasted: bool) -> Image:
	var img := _new_image(T, T)
	if roasted:
		_handle(img, Vector2(4.5, 28.5), Vector2(14.5, 18.5))
	else:
		for a in [-2.2, -1.7, -1.2]:
			_leaf(img, Vector2(22, 9), a, 9.0, LEAF5)
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(18, 7), Vector2(25, 13), Vector2(8, 28)])), tones)
	for t in [0.3, 0.5, 0.7]:
		var p := Vector2(21, 10).lerp(Vector2(9, 27), t)
		_line(img, p, p + Vector2(2, 2), tones[1])
	return _fin(img)


func _i_potato(tones: Array, baked: bool) -> Image:
	var img := _new_image(T, T)
	_bevel(img, _mask_poly(_rough(Vector2(16, 18), 11.0, 9, 1030, 0.75)), tones)
	for p in [Vector2i(11, 15), Vector2i(19, 13), Vector2i(21, 21), Vector2i(13, 22)]:
		_px(img, p.x, p.y, tones[0])
	if baked:
		_line(img, Vector2(10, 17), Vector2(22, 17), WHITE5[3], 2)
		_rect(img, 14, 14, 5, 3, SULF5[3])
		_rect(img, 15, 14, 2, 1, SULF5[4])
	return _fin(img)


func _i_berries(tones: Array) -> Image:
	var img := _new_image(T, T)
	_leaf(img, Vector2(16, 10), -2.4, 9.0, LEAF5)
	_leaf(img, Vector2(16, 10), -0.7, 9.0, LEAF5)
	for c in [Vector2(11, 16), Vector2(18, 14), Vector2(15, 21), Vector2(22, 20), Vector2(9, 23), Vector2(19, 26)]:
		_berry_dot(img, c, tones, 3.4)
		_px(img, int(c.x), int(c.y) - 2, tones[0])
	return _fin(img)


func _i_petals(tones: Array, seed: int) -> Image:
	var img := _new_image(T, T)
	for i in 5:
		var c := Vector2(9 + _hash(i, 1, seed) * 14.0, 9 + _hash(i, 2, seed) * 14.0)
		var a := _hash(i, 3, seed) * TAU
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		_bevel(img, _mask_poly(PackedVector2Array([c - d * 6.0, c + n * 3.5, c + d * 6.0, c - n * 3.5])), tones)
		_line(img, c - d * 3.0, c + d * 3.0, tones[1])
	return _fin(img)


func _i_pile(tones: Array, seed: int) -> Image:
	var img := _new_image(T, T)
	_blob(img, 16, 24, 13, 9, [tones[1], tones[2], tones[3], tones[4]], 0.25, seed, 27)
	_speck(img, _mask_ellipse(Vector2(16, 24), 12, 8), tones[0], 0.08, seed + 1)
	_rect(img, 5, 27, 22, 1, tones[1])
	return _fin(img)


func _i_glowcap() -> Image:
	var img := _new_image(T, T)
	_mush(img, 12, 26, 1.5, GLOW5)
	_mush(img, 20, 28, 2.1, GLOW5)
	return _fin(img)


func _i_scrap() -> Image:
	var img := _new_image(T, T)
	var rust := [Color8(70, 36, 24), Color8(116, 60, 34), Color8(160, 90, 50), Color8(196, 128, 76), Color8(220, 170, 120)]
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(4, 18), Vector2(17, 13), Vector2(20, 24), Vector2(7, 28)])), rust)
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(12, 6), Vector2(26, 8), Vector2(25, 18), Vector2(14, 16)])), MAT["iron"])
	_bevel(img, _mask_stroke(Vector2(18, 27), Vector2(28, 19), 1.6), MAT["iron"])
	for p in [Vector2i(15, 9), Vector2i(23, 11), Vector2i(9, 21)]:
		_px(img, p.x, p.y, C.outline)
	return _fin(img)


func _gear(img: Image, c: Vector2, r: float, tones: Array, teeth := 8) -> void:
	var m := _mask_ellipse(c, r, r)
	for i in teeth:
		var a := TAU * i / teeth
		m = _mask_add(m, _mask_stroke(c + Vector2(cos(a), sin(a)) * r, c + Vector2(cos(a), sin(a)) * (r + 2.5), 1.6))
	_bevel(img, _mask_cut(m, _mask_ellipse(c, r * 0.35, r * 0.35)), tones)


func _i_cog(tones: Array) -> Image:
	var img := _new_image(T, T)
	_gear(img, Vector2(16, 16), 9.0, tones, 9)
	return _fin(img)


func _i_wool() -> Image:
	var img := _new_image(T, T)
	for c in [Vector2(11, 20), Vector2(21, 20), Vector2(16, 13), Vector2(16, 22)]:
		_blob(img, c.x, c.y, 7, 6, [WHITE5[1], WHITE5[2], WHITE5[3], WHITE5[4]], 0.3, 1040 + int(c.x))
	return _fin(img)


func _i_pelt(tones: Array) -> Image:
	var img := _new_image(T, T)
	var pts := PackedVector2Array([Vector2(4, 9), Vector2(10, 6), Vector2(16, 8), Vector2(22, 6), Vector2(28, 9), Vector2(26, 16), Vector2(28, 24), Vector2(21, 27), Vector2(16, 24), Vector2(11, 27), Vector2(4, 24), Vector2(6, 16)])
	var m := _mask_poly(pts)
	_bevel(img, m, tones)
	for i in 24:
		var x := 7 + int(_hash(i, 7, 1050) * 19.0)
		var y := 9 + int(_hash(i, 8, 1050) * 15.0)
		_line(img, Vector2(x, y), Vector2(x + 1, y + 2), tones[1 + i % 3])
	return _fin(img)


func _i_sac(tones: Array) -> Image:
	var img := _new_image(T, T)
	_blob(img, 16, 19, 10, 9, [tones[1], tones[2], tones[3], tones[4]], 0.08, 1060)
	_bevel(img, _mask_stroke(Vector2(16, 10), Vector2(19, 4), 1.6), tones)
	for i in 5:
		_line(img, Vector2(10 + i * 3, 13 + i % 2), Vector2(9 + i * 3, 25), tones[1])
	_px(img, 12, 14, tones[4])
	return _fin(img)


func _i_plate(tones: Array) -> Image:
	var img := _new_image(T, T)
	var m := _mask_cut(_mask_ellipse(Vector2(16, 24), 13, 18), _mask_fn(func(p: Vector2) -> bool: return p.y > 27.0))
	_bevel(img, m, tones)
	for y in [12, 18, 23]:
		for x in range(5, 28):
			if m.has(Vector2i(x, y)):
				_px(img, x, y, tones[1])
				if m.has(Vector2i(x, y - 1)):
					_px(img, x, y - 1, tones[3])
	return _fin(img)


func _i_scales(tones: Array) -> Image:
	var img := _new_image(T, T)
	for row in 3:
		for col in 3 - row % 2:
			var c := Vector2(9 + col * 7 + (row % 2) * 3.5, 9 + row * 7)
			_bevel(img, _mask_cut(_mask_ellipse(c, 4.5, 5.5), _mask_fn(func(p: Vector2) -> bool: return p.y < c.y - 2.0)), tones)
	return _fin(img)


func _i_shell() -> Image:
	var img := _new_image(T, T)
	var t := [Color8(140, 90, 80), Color8(200, 130, 110), Color8(236, 176, 150), Color8(248, 210, 186), Color8(255, 236, 220)]
	var c := Vector2(16, 25)
	var m := _mask_fn(func(p: Vector2) -> bool: return p.y <= c.y and p.distance_to(c) <= 13.0)
	_bevel(img, m, t)
	for i in 7:
		var a := PI + PI * (i + 1) / 8.0
		_line(img, c, c + Vector2(cos(a), sin(a)) * 12.0, t[1])
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(12, 24), Vector2(20, 24), Vector2(18, 29), Vector2(14, 29)])), t)
	return _fin(img)


func _i_feather() -> Image:
	var img := _new_image(T, T)
	var a := Vector2(7, 27)
	var b := Vector2(25, 5)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	for i in 22:
		var t := 0.2 + 0.8 * i / 21.0
		var p := a.lerp(b, t)
		var w := sin(t * PI) * 6.5 + 1.0
		_line(img, p, p + n * w + d * 2.0, WHITE5[2 + i % 2] if i % 5 else BLUE5[3])
		_line(img, p, p - n * w + d * 2.0, WHITE5[1 + i % 2])
	_line(img, a, b, WHITE5[0])
	return _fin(img)


func _i_glass() -> Image:
	var img := _new_image(T, T)
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(7, 6), Vector2(25, 4), Vector2(27, 26), Vector2(5, 28)])), GLASS5)
	_line(img, Vector2(10, 21), Vector2(18, 9), GLASS5[4], 2)
	_line(img, Vector2(15, 23), Vector2(21, 14), GLASS5[4])
	return _fin(img)


func _i_pot(jar: Array, goo: Array) -> Image:
	var img := _new_image(T, T)
	_bevel(img, _mask_add(_mask_ellipse(Vector2(16, 20), 10, 8), _mask_poly(PackedVector2Array([Vector2(9, 11), Vector2(23, 11), Vector2(23, 16), Vector2(9, 16)]))), jar)
	_bevel(img, _mask_ellipse(Vector2(16, 11), 8, 2.5), jar)
	_bevel(img, _mask_ellipse(Vector2(16, 11), 6, 1.6), goo)
	_bevel(img, _mask_stroke(Vector2(11, 12), Vector2(10, 18), 1.4), goo)
	return _fin(img)


func _i_fried_egg() -> Image:
	var img := _new_image(T, T)
	_bevel(img, _mask_poly(_rough(Vector2(16, 17), 12.0, 10, 1070, 0.8)), WHITE5)
	_blob(img, 15, 15, 4.5, 4.5, [SULF5[1], CARROT5[2], CARROT5[3], SULF5[4]], 0.0, 1071)
	return _fin(img)


func _i_candied_apple() -> Image:
	var img := _new_image(T, T)
	_bevel(img, _mask_stroke(Vector2(16, 4), Vector2(16, 14), 1.0), WOOD5)
	_blob(img, 16, 20, 10, 9, [RED5[0], RED5[1], RED5[2], RED5[3]], 0.0, 1080)
	_rect(img, 10, 14, 3, 3, RED5[4])
	_px(img, 9, 17, Color(1, 1, 1))
	_line(img, Vector2(7, 24), Vector2(25, 24), AMBER5[3])
	return _fin(img)


func _i_omelette() -> Image:
	var img := _new_image(T, T)
	var m := _mask_fn(func(p: Vector2) -> bool: return p.y >= 12.0 and pow((p.x - 16.0) / 13.0, 2) + pow((p.y - 12.0) / 14.0, 2) <= 1.0)
	_bevel(img, m, [CARROT5[1], SULF5[1], SULF5[2], SULF5[3], SULF5[4]])
	for p in [Vector2i(10, 16), Vector2i(18, 15), Vector2i(14, 20), Vector2i(21, 19)]:
		_rect(img, p.x, p.y, 2, 1, LEAF5[3])
	return _fin(img)


func _i_pie(fill: Array) -> Image:
	var img := _new_image(T, T)
	_bevel(img, _mask_ellipse(Vector2(16, 19), 14, 8), CRUST5)
	_bevel(img, _mask_ellipse(Vector2(16, 18), 11, 5.5), fill)
	for i in 4:
		_line(img, Vector2(8 + i * 5, 13), Vector2(11 + i * 5, 23), CRUST5[3])
	_line(img, Vector2(5, 17), Vector2(27, 17), CRUST5[4])
	return _fin(img)


func _i_cake() -> Image:
	var img := _new_image(T, T)
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(5, 14), Vector2(27, 14), Vector2(27, 27), Vector2(5, 27)])), CRUST5)
	_line(img, Vector2(6, 20), Vector2(26, 20), WHITE5[3], 2)
	_bevel(img, _mask_ellipse(Vector2(16, 13), 11, 3), AMBER5)
	for x in [8, 14, 21, 25]:
		_line(img, Vector2(x, 14), Vector2(x, 16 + x % 4), AMBER5[2])
	return _fin(img)


func _i_poultice() -> Image:
	var img := _new_image(T, T)
	_bevel(img, _mask_poly(_rough(Vector2(16, 18), 11.0, 8, 1090, 0.8)), LEAF5)
	_line(img, Vector2(6, 18), Vector2(26, 18), WOOD5[3], 2)
	_line(img, Vector2(16, 9), Vector2(16, 27), WOOD5[3])
	_rect(img, 15, 17, 3, 3, WOOD5[1])
	return _fin(img)


func _i_bandage() -> Image:
	var img := _new_image(T, T)
	_bevel(img, _mask_ellipse(Vector2(13, 17), 8, 9), WHITE5)
	for r in [5.5, 3.0]:
		for s in 48:
			var a := TAU * s / 48.0
			_px(img, int(13 + cos(a) * r), int(17 + sin(a) * r * 1.1), WHITE5[1])
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(16, 22), Vector2(28, 22), Vector2(28, 27), Vector2(16, 26)])), WHITE5)
	_rect(img, 21, 23, 3, 1, RED5[2])
	_rect(img, 22, 22, 1, 3, RED5[2])
	return _fin(img)


# ---- resource node sprites (32px, base around y 29)

func _biome_nodes() -> Dictionary:
	var n := {}
	n["flint"] = _make_ore([Color8(30, 30, 38), Color8(70, 72, 84), Color8(150, 150, 162)], 5)
	n["ore_tin"] = _make_ore([TIN5[2], TIN5[3], TIN5[4]], 6)
	n["ore_silver"] = _make_ore([SILVER5[2], SILVER5[3], SILVER5[4]], 7)
	n["ore_gold"] = _make_ore([GOLD5[2], GOLD5[3], GOLD5[4]], 8)
	n["sulfur"] = _make_ore([SULF5[2], SULF5[3], SULF5[4]], 9)
	n["saltpeter"] = _make_ore([WHITE5[2], WHITE5[3], WHITE5[4]], 10)
	n["reeds"] = _n_stalks(LEAF5, HIDE5, 7, 22)
	n["wheat"] = _n_stalks(WHEAT5, WHEAT5, 8, 18)
	n["herb"] = _n_herb()
	n["cotton"] = _n_shrub([WHITE5[1], WHITE5[2], WHITE5[3], WHITE5[4]], 3.2, 1110)
	n["blueberry"] = _n_shrub(BLUE5, 2.2, 1120)
	n["resin_stump"] = _n_stump()
	n["beehive"] = _n_beehive()
	n["apple_tree"] = _n_apple_tree()
	n["carrot"] = _n_crop(func(img: Image, x: int) -> void:
		_bevel(img, _mask_poly(PackedVector2Array([Vector2(x - 2, 24), Vector2(x + 2, 24), Vector2(x, 28)])), CARROT5)
		for a in [-2.2, -1.6, -1.0]:
			_leaf(img, Vector2(x, 24), a, 7.0, LEAF5))
	n["potato"] = _n_crop(func(img: Image, x: int) -> void:
		for a in [-2.5, -1.9, -1.2, -0.6]:
			_leaf(img, Vector2(x, 25), a, 8.0, LEAF5)
		_px(img, x, 17, WHITE5[4]))
	n["flower"] = _n_flowers()
	n["sand"] = _n_mound(SAND5, 1130)
	n["nest"] = _n_nest()
	n["rubble"] = _n_rubble()
	n["quartz"] = _n_crystals(WHITE5)
	n["obsidian"] = _n_crystals(OBSID5)
	n["glowcap"] = _n_glowcaps()
	n["cave_moss"] = _n_moss()
	n["vines"] = _n_vines()
	n["bone_pile"] = _n_bones()
	n["scrap_heap"] = _n_scrap()
	n["machine"] = _n_machine()
	n["shadow_orchid"] = _n_orchid()
	n["cobweb"] = _n_web()
	return n


func _n_stalks(stem: Array, head: Array, count: int, h: float) -> Image:
	var img := _new_image(T, T)
	for i in count:
		var x := 6.0 + i * (20.0 / count) + _hash(i, 1, 1100) * 2.0
		var top := Vector2(x + (_hash(i, 2, 1100) - 0.5) * 6.0, 29.0 - h * (0.75 + _hash(i, 3, 1100) * 0.3))
		_line(img, Vector2(x, 29), top, stem[1 + i % 3])
		if stem == head:
			_bevel(img, _mask_ellipse(top, 1.8, 3.6), head)
		else:
			_bevel(img, _mask_stroke(top + Vector2(0, 1), top + Vector2(0, 6), 1.6), head)
	return _fin(img)


func _n_herb() -> Image:
	var img := _new_image(T, T)
	for i in 7:
		var a := -PI + PI * (i + 0.5) / 7.0
		_leaf(img, Vector2(16, 28), a, 10.0 + (i % 2) * 3.0, LEAF5)
	for c in [Vector2(10, 18), Vector2(16, 14), Vector2(22, 18)]:
		_line(img, Vector2(16, 27), c, LEAF5[1])
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			_px(img, int(c.x) + d.x, int(c.y) + d.y, WHITE5[4])
		_px(img, int(c.x), int(c.y), SULF5[3])
	return _fin(img)


func _n_beehive() -> Image:
	var img := _new_image(T, T)
	_bevel(img, _mask_stroke(Vector2(16, 29), Vector2(16, 20), 1.6), WOOD5)
	var dome := _mask_cut(_mask_ellipse(Vector2(16, 17), 10, 12), _mask_fn(func(p: Vector2) -> bool: return p.y > 24.0))
	_bevel(img, dome, WHEAT5)
	for y in [10, 14, 18, 22]:
		for x in range(4, 29):
			if dome.has(Vector2i(x, y)):
				_px(img, x, y, WHEAT5[1])
	_bevel(img, _mask_ellipse(Vector2(16, 20), 2.5, 2.0), [C.outline, C.outline, Color8(50, 30, 20), Color8(50, 30, 20), Color8(70, 40, 24)])
	for p in [Vector2i(5, 6), Vector2i(26, 9), Vector2i(23, 3)]:
		_px(img, p.x, p.y, SULF5[3])
		_px(img, p.x + 1, p.y, C.outline)
	return _fin(img)


func _n_crop(plant: Callable) -> Image:
	var img := _new_image(T, T)
	_blob(img, 16, 27, 13, 4, [SOIL5[1], SOIL5[2], SOIL5[3], SOIL5[4]], 0.25, 1150)
	for x in [9, 16, 23]:
		plant.call(img, x)
	return _fin(img)


func _n_flowers() -> Image:
	var img := _new_image(T, T)
	var cols := [PINK5, SULF5, BLUE5, WHITE5, PINK5]
	for i in 5:
		var base := Vector2(7 + i * 4.5, 29)
		var head := base + Vector2((_hash(i, 1, 1160) - 0.5) * 4.0, -8.0 - _hash(i, 2, 1160) * 10.0)
		_line(img, base, head, LEAF5[2])
		_leaf(img, base.lerp(head, 0.4), -0.6 if i % 2 else -2.5, 5.0, LEAF5)
		var t: Array = cols[i]
		for d in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			_bevel(img, _mask_ellipse(head + d, 1.6, 1.6), t)
		_px(img, int(head.x), int(head.y), SULF5[3] if t != SULF5 else CARROT5[2])
	return _fin(img)


func _n_mound(tones: Array, seed: int) -> Image:
	var img := _new_image(T, T)
	_blob(img, 16, 25, 14, 7, [tones[1], tones[2], tones[3], tones[4]], 0.25, seed, 30)
	_speck(img, _mask_ellipse(Vector2(16, 25), 13, 6), tones[0], 0.07, seed + 1)
	for i in 4:
		_line(img, Vector2(7 + i * 5, 26), Vector2(10 + i * 5, 25), tones[1])
	return _fin(img)


func _n_nest() -> Image:
	var img := _new_image(T, T)
	var egg := [Color8(150, 170, 170), Color8(180, 210, 210), Color8(210, 236, 232), Color8(232, 248, 244), Color8(250, 255, 252)]
	_bevel(img, _mask_ellipse(Vector2(16, 24), 12, 5.5), WOOD5)
	for c in [Vector2(12, 21), Vector2(18, 20), Vector2(15, 23)]:
		_blob(img, c.x, c.y, 3.2, 4.0, [egg[1], egg[2], egg[3], egg[4]], 0.0, 1170)
	var ring := _mask_cut(_mask_ellipse(Vector2(16, 25), 13, 5.5), _mask_ellipse(Vector2(16, 22), 10, 3.5))
	_bevel(img, ring, WOOD5)
	for i in 14:
		var a := TAU * i / 14.0
		var p := Vector2(16 + cos(a) * 12.0, 25 + sin(a) * 4.5)
		_line(img, p, p + Vector2(3, -1).rotated(a), WOOD5[1 + i % 3])
	return _fin(img)


func _n_rubble() -> Image:
	var img := _new_image(T, T)
	var tones := [C.rock_deep, C.rock_dark, C.rock, C.rock_light]
	for r in [[9, 25, 6, 4.5], [22, 25, 6.5, 5], [15, 19, 7, 6], [26, 20, 3, 2.5], [5, 21, 3, 2.5]]:
		_blob(img, r[0], r[1], r[2], r[3], tones, 0.18, 1180 + r[0])
	return _fin(img)


func _n_crystals(tones: Array) -> Image:
	var img := _new_image(T, T)
	_blob(img, 16, 27, 12, 3.5, [C.rock_deep, C.rock_dark, C.rock, C.rock_light], 0.2, 1190)
	_crystals(img, Vector2(16, 28), tones, 1.25)
	_crystals(img, Vector2(7, 29), tones, 0.55)
	_crystals(img, Vector2(26, 29), tones, 0.6)
	return _fin(img)


func _n_glowcaps() -> Image:
	var img := _new_image(T, T)
	_mush(img, 10, 27, 1.4, GLOW5)
	_mush(img, 19, 29, 2.0, GLOW5)
	_mush(img, 25, 26, 1.0, GLOW5)
	_fin(img)
	for p in [Vector2i(6, 12), Vector2i(14, 6), Vector2i(27, 14), Vector2i(22, 4)]:
		_px(img, p.x, p.y, GLOW5[4])
	return img


func _n_moss() -> Image:
	var img := _new_image(T, T)
	var tones := [C.moss_dark, C.moss_dark, C.moss, C.moss_light]
	_blob(img, 16, 26, 14, 4.5, tones, 0.5, 1200)
	_blob(img, 11, 23, 6, 3, tones, 0.5, 1201)
	_blob(img, 21, 23, 7, 3.5, tones, 0.5, 1202)
	_speck(img, _mask_ellipse(Vector2(16, 25), 13, 5), LEAF5[4], 0.06, 1203)
	return _fin(img)


func _n_vines() -> Image:
	var img := _new_image(T, T)
	for i in 6:
		var pts := []
		var x := 4.0 + i * 4.8
		for k in 6:
			pts.append(Vector2(x + sin(k * 1.3 + i) * 3.0, 29.0 - k * (3.5 + _hash(i, k, 1210) * 1.5)))
		for k in 5:
			_line(img, pts[k], pts[k + 1], LEAF5[1 + (i + k) % 2], 2)
			if (i + k) % 2 == 0:
				_leaf(img, pts[k + 1], -PI * 0.5 + (0.9 if k % 2 else -0.9), 5.0, LEAF5)
	return _fin(img)


func _n_bones() -> Image:
	var img := _new_image(T, T)
	var bone: Array = MAT["bone"]
	for l in [[Vector2(4, 27), Vector2(20, 22)], [Vector2(12, 21), Vector2(28, 28)], [Vector2(6, 21), Vector2(13, 28)]]:
		_bevel(img, _mask_stroke(l[0], l[1], 1.4), bone)
		for e in l:
			_bevel(img, _mask_add(_mask_ellipse(e + Vector2(-1, -1), 1.8, 1.8), _mask_ellipse(e + Vector2(1, 1), 1.8, 1.8)), bone)
	_bevel(img, _mask_add(_mask_ellipse(Vector2(18, 15), 6.5, 6), _mask_poly(PackedVector2Array([Vector2(14, 18), Vector2(22, 18), Vector2(21, 23), Vector2(15, 23)]))), bone)
	for c in [Vector2i(15, 15), Vector2i(20, 15)]:
		_rect(img, c.x, c.y, 2, 2, C.outline)
	_px(img, 17, 18, C.outline)
	for x in [16, 18, 20]:
		_px(img, x, 22, bone[0])
	return _fin(img)


func _n_scrap() -> Image:
	var img := _new_image(T, T)
	var rust := [Color8(70, 36, 24), Color8(116, 60, 34), Color8(160, 90, 50), Color8(196, 128, 76), Color8(220, 170, 120)]
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(3, 29), Vector2(9, 19), Vector2(17, 16), Vector2(25, 19), Vector2(29, 29)])), rust)
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(7, 20), Vector2(17, 12), Vector2(20, 17), Vector2(10, 24)])), MAT["iron"])
	_gear(img, Vector2(22, 20), 4.0, MAT["iron"], 7)
	_bevel(img, _mask_stroke(Vector2(5, 14), Vector2(14, 23), 1.3), MAT["iron"])
	_speck(img, _mask_ellipse(Vector2(16, 25), 12, 5), rust[0], 0.1, 1220)
	return _fin(img)


func _n_machine() -> Image:
	var img := _new_image(T, T)
	var hull := [Color8(36, 44, 46), Color8(58, 70, 70), Color8(86, 100, 96), Color8(118, 132, 124), Color8(150, 164, 152)]
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(4, 12), Vector2(28, 12), Vector2(28, 29), Vector2(4, 29)])), hull)
	_bevel(img, _mask_poly(PackedVector2Array([Vector2(7, 7), Vector2(17, 7), Vector2(17, 12), Vector2(7, 12)])), hull)
	_gear(img, Vector2(21, 19), 4.5, BRONZE5, 8)
	_rect(img, 7, 16, 7, 4, C.outline)
	_rect(img, 8, 17, 2, 2, Color8(220, 70, 50))
	_rect(img, 11, 17, 2, 2, GLOW5[3])
	for x in range(6, 27, 4):
		_px(img, x, 27, hull[0])
	_bevel(img, _mask_stroke(Vector2(19, 9), Vector2(27, 5), 1.3), MAT["iron"])
	var moss := [C.moss_dark, C.moss_dark, C.moss, C.moss_light]
	_blob(img, 8, 28, 5, 2.5, moss, 0.5, 1230)
	_blob(img, 26, 13, 3, 2, moss, 0.5, 1231)
	return _fin(img)


func _n_orchid() -> Image:
	var img := _new_image(T, T)
	_line(img, Vector2(16, 29), Vector2(15, 12), Color8(30, 40, 34), 2)
	_leaf(img, Vector2(16, 28), -2.6, 10.0, [Color8(16, 24, 20), Color8(26, 40, 32), Color8(40, 60, 46), Color8(60, 86, 64), Color8(90, 120, 90)])
	_leaf(img, Vector2(16, 28), -0.5, 10.0, [Color8(16, 24, 20), Color8(26, 40, 32), Color8(40, 60, 46), Color8(60, 86, 64), Color8(90, 120, 90)])
	for a in [-2.6, -1.57, -0.5, 0.6, 2.5]:
		_leaf(img, Vector2(15, 11), a, 7.0, PURPLE5)
	_bevel(img, _mask_ellipse(Vector2(15, 11), 2, 2), [GLOW5[1], GLOW5[2], GLOW5[3], GLOW5[4], GLOW5[4]])
	return _fin(img)


func _n_web() -> Image:
	var img := _new_image(T, T)
	var silk := Color(0.92, 0.92, 0.96, 0.8)
	var c := Vector2(16, 17)
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		_line(img, c, c + Vector2(cos(a) * 14.0, sin(a) * 12.0), silk)
	for r in [3.5, 7.0, 10.5]:
		for i in 8:
			var a0 := TAU * i / 8.0 + 0.2
			var a1 := TAU * (i + 1) / 8.0 + 0.2
			_line(img, c + Vector2(cos(a0) * r, sin(a0) * r * 0.86), c + Vector2(cos(a1) * r, sin(a1) * r * 0.86), Color(0.85, 0.85, 0.9, 0.6))
	_blob(img, 21, 12, 2.5, 2.5, [Color8(20, 18, 24), Color8(40, 34, 44), Color8(60, 50, 64), Color8(90, 80, 96)], 0.0, 1240)
	return img


# ---- stations

func _make_structure_m10(kind: String) -> Image:
	var img := _new_image(T, T)
	if kind == "loom":
		for x in [4.5, 27.5]:
			_bevel(img, _mask_stroke(Vector2(x, 4), Vector2(x, 30), 1.6), WOOD5)
		for y in [5.5, 23.5]:
			_bevel(img, _mask_stroke(Vector2(3, y), Vector2(29, y), 1.5), WOOD5)
		for x in range(7, 26, 2):
			_line(img, Vector2(x, 7), Vector2(x, 15), WHITE5[2])
		var cloth := _mask_poly(PackedVector2Array([Vector2(7, 15), Vector2(26, 15), Vector2(26, 22), Vector2(7, 22)]))
		_bevel(img, cloth, [RED5[0], RED5[1], RED5[2], RED5[3], RED5[4]])
		for y in [17, 20]:
			_line(img, Vector2(7, y), Vector2(25, y), SULF5[2])
		_bevel(img, _mask_stroke(Vector2(9, 14.5), Vector2(24, 14.5), 1.0), WOOD5)
		_bevel(img, _mask_ellipse(Vector2(25, 27), 3.5, 2.5), WHITE5)
	else:
		_bevel(img, _mask_poly(PackedVector2Array([Vector2(3, 15), Vector2(29, 15), Vector2(29, 19), Vector2(3, 19)])), WOOD5)
		for x in [5, 25]:
			_bevel(img, _mask_poly(PackedVector2Array([Vector2(x, 19), Vector2(x + 3, 19), Vector2(x + 3, 30), Vector2(x, 30)])), WOOD5)
		_bevel(img, _mask_add(_mask_ellipse(Vector2(9, 11), 4.5, 4.5), _mask_stroke(Vector2(9, 3), Vector2(9, 8), 1.4)), GLASS5)
		_blob(img, 9, 12, 3, 2.5, [SLIME5[1], SLIME5[2], SLIME5[3], SLIME5[4]], 0.0, 1250)
		_bevel(img, _mask_poly(PackedVector2Array([Vector2(15, 4), Vector2(19, 4), Vector2(19, 8), Vector2(22, 15), Vector2(12, 15), Vector2(15, 8)])), GLASS5)
		_bevel(img, _mask_poly(PackedVector2Array([Vector2(14, 11), Vector2(20, 11), Vector2(22, 15), Vector2(12, 15)])), VENOM5)
		_bevel(img, _mask_add(_mask_ellipse(Vector2(25, 12), 3, 3), _mask_stroke(Vector2(25, 6), Vector2(25, 10), 1.1)), GLASS5)
		_blob(img, 25, 13, 2, 1.5, [RED5[1], RED5[2], RED5[3], RED5[4]], 0.0, 1251)
		_bevel(img, _mask_ellipse(Vector2(16, 24), 4, 2.5), MAT["stone"])
	_outline(img, C.outline)
	return img
