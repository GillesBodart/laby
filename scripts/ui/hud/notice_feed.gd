extends Control
## Small stacked notices in the bottom-right corner (newest at the bottom):
## item rows ("+3 Wood", repeats of the same item merge into one row) and
## text rows (EventBus.notify messages, wrapped). Rows fade out after a while.
## Hidden while a panel is open; their timers wait until it closes.

const SIZE := Vector2(960, 540)
const RIGHT := 952.0
const BOTTOM := 524.0
const ROW_H := 20.0
const MAX_ROWS := 6
const SECONDS := 3.0
## Text rows stay longer, and longer still for long messages.
const TEXT_SECONDS := 3.5
const TEXT_SECONDS_MAX := 7.0
## Widest a text row may be before it wraps (native px, after text scaling),
## leaving the bottom-centre prompt free.
const TEXT_W := 320.0
const PAD := 8.0
const FADE := 0.5
const FONT_SIZE := 16
## Text notices stay small (smaller than item rows) so they never crowd play.
const TEXT_FONT_SIZE := 13
const STYLE := {
	"drop": {"sign": "-", "color": Color8(226, 140, 110)},
}
const BG := UiPalette.HUD_BG
const BORDER := UiPalette.BRASS_DARK
const TEXT_COLOR := Color(0.98, 0.92, 0.74)

var _font: Font
var _icons := {}
## Item rows: {"verb", "id", "count", "t"}; text rows: {"text", "w", "h", "t"}
## (t = seconds left, w / h = measured box size).
var _rows: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	EventBus.item_feed.connect(push)


func _get_font() -> Font:
	if _font == null:
		_font = UiFrame.font()
	return _font


func push(verb: String, id: String, count: int) -> void:
	for r in _rows:
		if r.has("id") and r.verb == verb and r.id == id:
			r.count += count
			r.t = SECONDS
			_rows.erase(r)
			_rows.append(r)
			queue_redraw()
			return
	_add({"verb": verb, "id": id, "count": count, "t": SECONDS})


## A message row; the same message again only refreshes it.
func push_text(text: String) -> void:
	var t := minf(TEXT_SECONDS + text.length() * 0.03, TEXT_SECONDS_MAX)
	for r in _rows:
		if r.has("text") and r.text == text:
			r.t = t
			_rows.erase(r)
			_rows.append(r)
			queue_redraw()
			return
	var f := _get_font()
	var w := minf(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_FONT_SIZE).x, TEXT_W / Accessibility.text_scale() - PAD * 2.0)
	var h := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, ceilf(w) + 1.0, TEXT_FONT_SIZE).y
	_add({"text": text, "w": ceilf(w) + 1.0, "h": ceilf(h), "t": t})


func _add(row: Dictionary) -> void:
	_rows.append(row)
	while _rows.size() > MAX_ROWS:
		_rows.pop_front()
	queue_redraw()


## Height of a row's box, gap included.
func _row_height(r: Dictionary) -> float:
	return r.h + PAD + 2.0 if r.has("text") else ROW_H


func _process(delta: float) -> void:
	# Out of the way of panels (backpack, map...); nothing expires meanwhile.
	var hidden := UiFrame.any_panel_open(get_tree()) if is_inside_tree() else false
	visible = not hidden
	if _rows.is_empty() or hidden:
		return
	for r in _rows:
		r.t -= delta
	_rows = _rows.filter(func(r): return r.t > 0.0)
	queue_redraw()


func _draw() -> void:
	Accessibility.scale_about(self, SIZE)
	var f := _get_font()
	var y := BOTTOM
	for i in range(_rows.size() - 1, -1, -1):
		var r: Dictionary = _rows[i]
		var a := clampf(r.t / FADE, 0.0, 1.0)
		var rh := _row_height(r)
		if r.has("text"):
			var box := Rect2(RIGHT - r.w - PAD * 2.0, y - rh, r.w + PAD * 2.0, rh - 2.0)
			draw_rect(box, Color(BG, BG.a * a))
			draw_rect(box, Color(BORDER, a), false)
			draw_multiline_string(f, box.position + Vector2(PAD, PAD / 2.0 + f.get_ascent(TEXT_FONT_SIZE)), r.text, HORIZONTAL_ALIGNMENT_LEFT, r.w, TEXT_FONT_SIZE, -1, Color(TEXT_COLOR, a))
		else:
			var style: Dictionary = STYLE.get(r.verb, {"sign": "+", "color": Color8(238, 226, 196)})
			var text := "%s%d %s" % [style.sign, r.count, ItemCatalog.item_name(r.id)]
			var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			var box := Rect2(RIGHT - tw - 28, y - rh, tw + 28, rh - 2)
			draw_rect(box, Color(BG, BG.a * a))
			draw_rect(box, Color(BORDER, a), false)
			_icon(Vector2(box.position.x + 12, box.get_center().y), r.id, a)
			draw_string(f, Vector2(box.position.x + 22, box.end.y - 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(style.color, a))
		y -= rh


## 16x16 item icon (the small variant when there is one), else a colour chip.
func _icon(c: Vector2, id: String, a: float) -> void:
	if not _icons.has(id):
		_icons[id] = null
		for path in ["res://assets/ui/icons/items/small/%s.png" % id, "res://assets/ui/icons/items/%s.png" % id]:
			if ResourceLoader.exists(path):
				_icons[id] = load(path)
				break
	if _icons[id] != null:
		draw_texture_rect(_icons[id], Rect2(c - Vector2(8, 8), Vector2(16, 16)), false, Color(1, 1, 1, a))
		return
	draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), Color(ItemCatalog.ITEMS[id].color, a))