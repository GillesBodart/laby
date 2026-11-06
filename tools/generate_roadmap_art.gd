extends SceneTree
## Pixel art for the late-game systems (death remains, survival props, sectors,
## settlement, glyphs...). Same conventions as generate_placeholder_art.gd:
## cel-shaded tones dark -> light, 1px dark outline, 32px icons + 16px copies.
## Some sprites are Dungeon Crawl Stone Soup tiles (CC0) vendored in
## tools/third_party/dcss/extra (see CREDITS.md).
##
##   godot --headless --path . --script res://tools/generate_roadmap_art.gd
##   godot --headless --path . --editor --quit

const OUTLINE := Color8(24, 22, 32)
const DCSS_EXTRA := "res://tools/third_party/dcss/extra"
const LEATHER := [Color8(66, 40, 26), Color8(98, 62, 38), Color8(132, 88, 54), Color8(170, 120, 74), Color8(204, 160, 104)]
const BONE := [Color8(150, 140, 116), Color8(196, 186, 160), Color8(226, 218, 196), Color8(246, 242, 226)]
const STONE := [Color8(44, 51, 52), Color8(70, 80, 78), Color8(98, 110, 104), Color8(132, 144, 134), Color8(170, 182, 168)]
const WOOD := [Color8(56, 38, 30), Color8(80, 54, 38), Color8(120, 82, 50), Color8(160, 114, 68), Color8(194, 150, 92)]
const WATER := [Color8(30, 60, 110), Color8(44, 96, 150), Color8(70, 140, 190), Color8(130, 196, 230), Color8(214, 240, 250)]
const FIRE := [Color8(140, 40, 36), Color8(210, 76, 44), Color8(246, 168, 60), Color8(255, 240, 160)]
const GLOW := [Color8(40, 110, 110), Color8(70, 170, 160), Color8(120, 230, 210), Color8(210, 255, 244)]


func _init() -> void:
	for dir in ["res://assets/sprites/structures", "res://assets/ui/items", "res://assets/sprites/props", "res://assets/sprites/npcs", "res://assets/sprites/enemies"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save(_remains(), "res://assets/sprites/remains.png")
	print("Roadmap art generated.")
	quit()


# ---------------------------------------------------------------- helpers

func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save %s (%d)" % [path, err])


func _icon(img: Image, id: String) -> void:
	_save(img, "res://assets/ui/items/%s.png" % id)
	var small := img.duplicate() as Image
	small.resize(16, 16, Image.INTERPOLATE_LANCZOS)
	_save(small, "res://assets/ui/items/%s_s.png" % id)


func _img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _hash(x: int, y: int, s: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + s * 2147483647
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)


func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, col)


## Cel-shaded ellipse lit from the upper left; tones dark -> light.
func _blob(img: Image, cx: float, cy: float, rx: float, ry: float, tones: Array, jitter := 0.1, seed := 0) -> void:
	var light := Vector3(-0.5, -0.7, 0.55).normalized()
	for y in range(int(floor(cy - ry)) - 1, int(ceil(cy + ry)) + 2):
		for x in range(int(floor(cx - rx)) - 1, int(ceil(cx + rx)) + 2):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			var d := nx * nx + ny * ny
			if d > 1.0:
				continue
			var lit := Vector3(nx, ny, sqrt(maxf(0.0, 1.0 - d))).dot(light) + (_hash(x, y, seed) - 0.5) * jitter
			_px(img, x, y, tones[int(clampf((lit + 0.45) / 1.35, 0.0, 0.999) * tones.size())])


## Bevelled box: light top/left edge, dark bottom/right edge.
func _box(img: Image, x: int, y: int, w: int, h: int, tones: Array, seed := 0) -> void:
	var n: int = tones.size()
	for yy in h:
		for xx in w:
			var col: Color = tones[n / 2]
			if _hash(x + xx, y + yy, seed) > 0.8:
				col = tones[n / 2 - 1]
			if yy == 0 or xx == 0:
				col = tones[n - 1]
			elif yy == h - 1 or xx == w - 1:
				col = tones[0]
			elif yy == h - 2:
				col = tones[1]
			_px(img, x + xx, y + yy, col)


func _line(img: Image, a: Vector2, b: Vector2, col: Color, width := 1) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / maxf(steps, 1))
		_rect(img, int(round(p.x)) - width / 2, int(round(p.y)) - width / 2, width, width, col)


func _outline(img: Image, color := OUTLINE) -> Image:
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < img.get_width() and n.y < img.get_height() and src.get_pixel(n.x, n.y).a > 0.0:
					img.set_pixel(x, y, color)
					break
	return img


## A vendored DCSS tile, outlined and optionally scaled to `size` px.
func _dcss(rel: String, size := 32) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s.png" % [DCSS_EXTRA, rel]))
	if img == null:
		push_error("Missing DCSS tile " + rel)
		return _img(32, 32)
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	if used.size.x > 0:
		img = img.get_region(used)
	var scale := float(size) / maxf(img.get_width(), img.get_height())
	if absf(scale - 1.0) > 0.01:
		img.resize(maxi(int(round(img.get_width() * scale)), 1), maxi(int(round(img.get_height() * scale)), 1), Image.INTERPOLATE_NEAREST)
	var out := _img(img.get_width() + 2, img.get_height() + 2)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(1, 1))
	return _outline(out)


# ---------------------------------------------------------------- sprites

## Torn backpack spilling its contents, with a bleached bone.
func _remains() -> Image:
	var img := _img(26, 20)
	_blob(img, 13, 12, 9, 6.5, LEATHER, 0.15, 3)
	_rect(img, 8, 7, 10, 2, LEATHER[1])
	_rect(img, 9, 6, 8, 1, LEATHER[3])
	_line(img, Vector2(6, 11), Vector2(20, 11), LEATHER[0])
	_blob(img, 21, 15, 2.5, 2, [Color8(150, 40, 50), Color8(210, 70, 80), Color8(250, 150, 160)], 0.1, 5)
	_blob(img, 5, 15, 2.2, 1.8, [Color8(90, 100, 110), Color8(150, 156, 164), Color8(200, 204, 210)], 0.1, 6)
	_line(img, Vector2(3, 18), Vector2(12, 16), BONE[2], 2)
	_px(img, 2, 17, BONE[3]); _px(img, 2, 19, BONE[1]); _px(img, 13, 15, BONE[3]); _px(img, 13, 17, BONE[1])
	return _outline(img)
