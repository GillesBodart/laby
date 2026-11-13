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

## Panels and menus are laid out in 480x270 and drawn at 2x. They share one
## frame language: box() (ink outline, the HUD's brass rim, green felt with a
## stitched seam), title_plate() above or at the top of it and footer() at a
## fixed spot along the bottom of the screen.
const PANEL_SPACE := Vector2(480, 270)
const TITLE_SIZE := 16
const BODY_SIZE := 10
const FOOTER_SIZE := 10
## Baseline of the footer line in panel space.
const FOOTER_Y := 264.0
## How far body text may grow with the text-size setting before a fixed panel
## layout would overflow; titles and footers fit themselves and may grow more.
const BODY_CAP := 1.25
const TITLE_CAP := 1.25
const FOOTER_CAP := 1.5

static var _cache := {}
static var _boxes := {}
static var _font: Font


static func panel(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_style_box(STYLE, r)


static func font() -> Font:
	if _font == null:
		_font = ThemeDB.get_project_theme().default_font
	return _font


## `base` font size scaled by the Accessibility text size, capped at `cap`
## times the base so fixed layouts keep fitting.
static func fs(base: int, cap := BODY_CAP) -> int:
	return roundi(base * minf(Accessibility.text_scale(), cap))


## Rounded flat box, cached per look (no style box allocated per frame).
static func flat(fill: Color, border: Color, radius := 3, width := 1) -> StyleBoxFlat:
	var key := "%s/%s/%d/%d" % [fill.to_html(), border.to_html(), radius, width]
	if not _boxes.has(key):
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = border
		sb.set_border_width_all(width)
		sb.set_corner_radius_all(radius)
		_boxes[key] = sb
	return _boxes[key]


## Small plate: buttons, rows, slots, chips and cards.
static func plate(ci: CanvasItem, r: Rect2, fill: Color, border: Color, radius := 3) -> void:
	ci.draw_style_box(flat(fill, border, radius), r)


## The shared panel frame. `parchment` swaps the felt for a page (map, journal).
static func box(ci: CanvasItem, r: Rect2, parchment := false) -> void:
	if not _boxes.has("rim"):
		var rim := StyleBoxFlat.new()
		rim.bg_color = UiPalette.BRASS
		rim.border_color = UiPalette.BRASS_DARK
		rim.border_width_right = 1
		rim.border_width_bottom = 1
		rim.set_corner_radius_all(7)
		_boxes["rim"] = rim
	ci.draw_style_box(flat(UiPalette.INK, UiPalette.INK, 8, 0), r)
	ci.draw_style_box(_boxes["rim"], r.grow(-1))
	ci.draw_style_box(flat(UiPalette.FELT_DARK, UiPalette.FELT_DARK, 6, 0), r.grow(-2))
	var inner := r.grow(-5)
	ci.draw_style_box(flat(UiPalette.PAGE if parchment else UiPalette.FELT, UiPalette.INK if parchment else UiPalette.FELT_DARK, 5), inner)
	if parchment:
		return
	var seam := inner.grow(-4)
	var col := UiPalette.STITCH
	for side in [[seam.position, Vector2(seam.end.x, seam.position.y)], [Vector2(seam.position.x, seam.end.y), seam.end],
			[seam.position, Vector2(seam.position.x, seam.end.y)], [Vector2(seam.end.x, seam.position.y), seam.end]]:
		ci.draw_dashed_line(side[0], side[1], col, 1.0, 3.0)


## Cream title plate centred on `center_x` with its top at `top`; widens to
## fit the (text-size scaled) title. Returns the plate's rect.
static func title_plate(ci: CanvasItem, center_x: float, top: float, text: String, min_w := 120.0) -> Rect2:
	var f := font()
	var size := fs(TITLE_SIZE, TITLE_CAP)
	var w := maxf(min_w, f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 24.0)
	var h := maxf(22.0, f.get_height(size) + 2.0)
	var r := Rect2(roundf(center_x - w / 2.0), top, roundf(w), h)
	plate(ci, r, UiPalette.CREAM, UiPalette.BROWN)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := roundf(top + (h - f.get_height(size)) / 2.0 + f.get_ascent(size))
	ci.draw_string(f, Vector2(roundf(center_x - tw / 2.0), base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UiPalette.TEXT_DARK)
	return r


## Key hints along the bottom of the screen, at one fixed spot and size for
## every panel ("[Esc] close  [Tab] switch"). {action} tokens are filled with
## the active device's keys / buttons; shrinks to fit `width`.
static func footer(ci: CanvasItem, text: String, center_x := PANEL_SPACE.x / 2.0, width := PANEL_SPACE.x - 16.0) -> void:
	var f := font()
	var s := Gamepad.fill(text)
	var size := fs(FOOTER_SIZE, FOOTER_CAP)
	while size > 8 and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(roundf(center_x - w / 2.0), FOOTER_Y)
	ci.draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(UiPalette.INK, 0.8))
	ci.draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UiPalette.TEXT_DIM)


## True while a panel (backpack, map, journal...) is open: the HUD's notices
## and prompts stay out of its way.
static func any_panel_open(tree: SceneTree) -> bool:
	if tree == null:
		return false
	for p in tree.get_nodes_in_group("ui_panels"):
		if p.visible:
			return true
	return false


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
