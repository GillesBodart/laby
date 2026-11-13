class_name UiFrame
extends RefCounted
## The HUD's shared look: a 9-slice brass-rimmed frame and small pixel icons,
## drawn at native (960x540) resolution.

const STYLE := preload("res://resources/ui/hud_frame.tres")
const TEXT := Color8(238, 226, 196)
const INK := Color8(14, 11, 14)

## 9x9 icons: X main colour, h highlight, d shade, b pale (bone / glass).
const ICONS := {
	"heart": [".XX...XX.", "XhXX.XXXX", "XhXXXXXXX", "XXXXXXXXd", ".XXXXXXd.", "..XXXXd..", "...XXd...", "....d....", "........."],
	"food": [".....XXX.", "....XhXXX", "...XhXXXX", "...XXXXXd", "....XXXd.", "...bd....", "..bb.....", ".bbb.....", "..b......"],
	"water": ["....X....", "...XXX...", "..XhXXX..", ".XhXXXXX.", ".XhXXXXd.", "XXhXXXXXd", "XXXXXXXXd", ".XXXXXdd.", "..ddddd.."],
	"stamina": [".....XXX.", "....XhX..", "...XhX...", "..XXXXXX.", "....XXd..", "...XXd...", "..XXd....", ".Xd......", "X........"],
	"temp": ["....bb...", "...b..b..", "...bXXb..", "...bXXb..", "...bXXb..", "..bXXXXb.", "..bXhXXb.", "..bXXXdb.", "...bbbb.."],
	"xp": ["....X....", "....X....", "...XhX...", "XXXXhXXXX", ".XXXXXXd.", "..XXXXd..", "..XX.XX..", ".XX...XX.", ".d.....d."],
}

static var _cache := {}


static func panel(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_style_box(STYLE, r)


## A 9x9 icon (11x11 with its ink outline) whose top-left is `pos`.
static func icon(ci: CanvasItem, pos: Vector2, id: String, color: Color) -> void:
	var key := "%s/%s" % [id, color.to_html()]
	if not _cache.has(key):
		_cache[key] = _build(ICONS[id], color)
	for px in _cache[key]:
		ci.draw_rect(Rect2(pos + px[0], Vector2.ONE), px[1])


## A thin durability bar (left-aligned at `pos`, `width` px) for a worn tool;
## draws nothing for fresh or unbreakable items.
static func wear_bar(ci: CanvasItem, pos: Vector2, width: float, id: String, wear: int) -> void:
	var dur := ItemCatalog.durability_of(id)
	if dur <= 0 or wear <= 0:
		return
	var frac := clampf(1.0 - float(wear) / dur, 0.0, 1.0)
	ci.draw_rect(Rect2(pos - Vector2.ONE, Vector2(width + 2, 4)), INK)
	ci.draw_rect(Rect2(pos, Vector2(maxf(width * frac, 1.0), 2)), wear_color(frac))


## Bar colour for a share of durability left.
static func wear_color(frac: float) -> Color:
	var good := Accessibility.color("good")
	var mid := Accessibility.color("warn")
	var bad := Accessibility.color("bad")
	return mid.lerp(good, (frac - 0.5) * 2.0) if frac >= 0.5 else bad.lerp(mid, frac * 2.0)


static func _build(rows: Array, color: Color) -> Array:
	var tones := {"X": color, "h": color.lightened(0.45), "d": color.darkened(0.4), "b": Color8(232, 226, 212)}
	var out := []
	var solid := {}
	for y in rows.size():
		for x in rows[y].length():
			if tones.has(rows[y][x]):
				solid[Vector2i(x, y)] = rows[y][x]
	var rim := {}
	for c in solid:
		for n in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not solid.has(c + n):
				rim[c + n] = true
	for c in rim:
		out.append([Vector2(c + Vector2i.ONE), INK])
	for c in solid:
		out.append([Vector2(c + Vector2i.ONE), tones[solid[c]]])
	return out
