class_name UiFrame
extends RefCounted
## The HUD's shared look: a 9-slice brass-rimmed frame and small smooth vector
## icons, drawn at native (960x540) resolution.

const STYLE := preload("res://resources/ui/hud_frame.tres")
const TEXT := Color8(238, 226, 196)
const INK := Color8(14, 11, 14)

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
		sb.anti_aliasing = true
		_boxes[key] = sb
	return _boxes[key]


## A vertical two-colour gradient inside `r`.
static func gradient(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


## Small plate: buttons, rows, slots, chips and cards. Soft drop shadow, a
## lit top edge and a shaded lower half give it volume.
static func plate(ci: CanvasItem, r: Rect2, fill: Color, border: Color, radius := 3) -> void:
	if fill.a > 0.5 and r.size.y >= 12.0 and r.size.x >= 12.0:
		ci.draw_style_box(flat(Color(0, 0, 0, 0.28), Color(0, 0, 0, 0.0), radius + 1, 0), Rect2(r.position + Vector2(0, 1.5), r.size))
	ci.draw_style_box(flat(fill, border, radius), r)
	if fill.a > 0.5 and r.size.y >= 12.0 and r.size.x >= 12.0:
		var inner := r.grow(-1.5)
		var rad := float(radius)
		ci.draw_line(inner.position + Vector2(rad, 0.5), Vector2(inner.end.x - rad, inner.position.y + 0.5), Color(1, 1, 1, 0.38), 1.0, true)
		gradient(ci, Rect2(inner.position + Vector2(1, inner.size.y * 0.55), Vector2(inner.size.x - 2, inner.size.y * 0.45 - 0.5)), Color(0, 0, 0, 0.0), Color(0.2, 0.08, 0.0, 0.14))


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
	ci.draw_style_box(flat(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 12, 0), Rect2(r.position + Vector2(-4, -2), r.size + Vector2(8, 8)))
	ci.draw_style_box(flat(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 10, 0), Rect2(r.position + Vector2(-2, -1), r.size + Vector2(4, 4)))
	ci.draw_style_box(flat(UiPalette.INK, UiPalette.INK, 8, 0), r)
	ci.draw_style_box(_boxes["rim"], r.grow(-1))
	ci.draw_style_box(flat(UiPalette.FELT_DARK, UiPalette.FELT_DARK, 6, 0), r.grow(-2))
	var inner := r.grow(-5)
	ci.draw_style_box(flat(UiPalette.PAGE if parchment else UiPalette.FELT, UiPalette.INK if parchment else UiPalette.FELT_DARK, 5), inner)
	# Light falling from the top, plus an inner shadow along the rim.
	var lit := inner.grow(-1)
	gradient(ci, lit, Color(1, 1, 0.8, 0.10 if not parchment else 0.18), Color(0, 0.06, 0.02, 0.22 if not parchment else 0.12))
	ci.draw_style_box(flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0.22), 5, 2), inner)
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


## A smooth vector icon in an 11x11 box whose top-left is `pos`: ink outline,
## `color` body and a soft highlight. Ids: heart, food, water, stamina, temp, xp.
static func icon(ci: CanvasItem, pos: Vector2, id: String, color: Color) -> void:
	var c := pos + Vector2(5.5, 5.5)
	var hi := color.lightened(0.5)
	match id:
		"heart":
			var pts := _heart(c, 5.2)
			_shape(ci, pts, color)
			ci.draw_circle(c + Vector2(-2.3, -1.9), 1.1, Color(hi, 0.85), true, -1.0, true)
		"food":
			# Drumstick: bone handle, then the meat.
			ci.draw_line(c + Vector2(0.5, 0.5), c + Vector2(4.5, 4.5), INK, 3.6, true)
			ci.draw_line(c + Vector2(0.5, 0.5), c + Vector2(4.2, 4.2), Color8(236, 228, 210), 1.8, true)
			ci.draw_circle(c + Vector2(4.6, 3.6), 1.6, INK, true, -1.0, true)
			ci.draw_circle(c + Vector2(3.6, 4.6), 1.6, INK, true, -1.0, true)
			ci.draw_circle(c + Vector2(4.6, 3.6), 0.9, Color8(236, 228, 210), true, -1.0, true)
			ci.draw_circle(c + Vector2(3.6, 4.6), 0.9, Color8(236, 228, 210), true, -1.0, true)
			_shape(ci, _ellipse(c + Vector2(-1.3, -1.3), 4.0, 3.2, -PI / 4.0), color)
			ci.draw_circle(c + Vector2(-2.6, -2.4), 1.0, Color(hi, 0.8), true, -1.0, true)
		"water":
			var drop := PackedVector2Array()
			for i in 17:
				var a := PI * (0.0 + i / 16.0)
				drop.append(c + Vector2(0, 1.4) + Vector2(cos(a), sin(a)) * 3.8)
			drop.append(c + Vector2(0, -5.2))
			drop.reverse()
			_shape(ci, drop, color)
			ci.draw_circle(c + Vector2(-1.4, 1.0), 0.9, Color(hi, 0.85), true, -1.0, true)
		"stamina":
			_shape(ci, PackedVector2Array([c + Vector2(1.8, -5.4), c + Vector2(-3.6, 0.8), c + Vector2(-0.4, 0.8),
				c + Vector2(-1.8, 5.4), c + Vector2(3.6, -1.0), c + Vector2(0.4, -1.0)]), color)
		"temp":
			var tube := Rect2(c + Vector2(-1.4, -5.2), Vector2(2.8, 7.0))
			ci.draw_style_box(flat(INK, INK, 2, 0), tube.grow(1.0))
			ci.draw_circle(c + Vector2(0, 2.8), 3.0, INK, true, -1.0, true)
			ci.draw_style_box(flat(Color8(232, 226, 212), Color8(232, 226, 212), 1, 0), tube)
			ci.draw_rect(Rect2(c + Vector2(-0.6, -1.0), Vector2(1.2, 3.0)), color)
			ci.draw_circle(c + Vector2(0, 2.8), 2.1, color, true, -1.0, true)
			ci.draw_circle(c + Vector2(-0.7, 2.1), 0.6, Color(hi, 0.85), true, -1.0, true)
		"xp":
			var star := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				star.append(c + Vector2(cos(a), sin(a)) * (5.4 if i % 2 == 0 else 2.4))
			_shape(ci, star, color)


static func _shape(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, INK, 2.0, true)
	ci.draw_colored_polygon(pts, color)
	ci.draw_polyline(loop, color.darkened(0.35), 0.8, true)


static func _heart(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y + 1.5) * (r / 16.0))
	return pts


static func _ellipse(c: Vector2, rx: float, ry: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


## A thin durability bar (left-aligned at `pos`, `width` px) for a worn tool;
## draws nothing for fresh or unbreakable items.
static func wear_bar(ci: CanvasItem, pos: Vector2, width: float, id: String, wear: int) -> void:
	var dur := ItemCatalog.durability_of(id)
	if dur <= 0 or wear <= 0:
		return
	var frac := clampf(1.0 - float(wear) / dur, 0.0, 1.0)
	ci.draw_style_box(flat(INK, INK, 2, 0), Rect2(pos - Vector2.ONE, Vector2(width + 2, 4)))
	ci.draw_line(pos + Vector2(0.5, 1), pos + Vector2(maxf(width * frac, 1.0) - 0.5, 1), wear_color(frac), 2.0, true)


## Bar colour for a share of durability left.
static func wear_color(frac: float) -> Color:
	var good := Accessibility.color("good")
	var mid := Accessibility.color("warn")
	var bad := Accessibility.color("bad")
	return mid.lerp(good, (frac - 0.5) * 2.0) if frac >= 0.5 else bad.lerp(mid, frac * 2.0)
