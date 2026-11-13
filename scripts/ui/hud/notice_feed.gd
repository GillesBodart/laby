extends Control
## Small stacked item notices in the bottom-right corner (newest at the bottom).
## Repeats of the same item merge into one row; rows fade out after a while.

const SIZE := Vector2(960, 540)
const RIGHT := 952.0
const BOTTOM := 524.0
const ROW_H := 20.0
const MAX_ROWS := 6
const SECONDS := 3.0
const FADE := 0.5
const FONT_SIZE := 16
const STYLE := {
	"drop": {"sign": "-", "color": Color8(226, 140, 110)},
}
const BG := Color(0.06, 0.06, 0.09, 0.82)
const BORDER := Color8(96, 72, 48)

var _font: Font
## Each: {"verb", "id", "count", "t"} (t = seconds left).
var _rows: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	_font = ThemeDB.get_project_theme().default_font
	EventBus.item_feed.connect(push)


func push(verb: String, id: String, count: int) -> void:
	for r in _rows:
		if r.verb == verb and r.id == id:
			r.count += count
			r.t = SECONDS
			_rows.erase(r)
			_rows.append(r)
			queue_redraw()
			return
	_rows.append({"verb": verb, "id": id, "count": count, "t": SECONDS})
	while _rows.size() > MAX_ROWS:
		_rows.pop_front()
	queue_redraw()


func _process(delta: float) -> void:
	if _rows.is_empty():
		return
	for r in _rows:
		r.t -= delta
	_rows = _rows.filter(func(r): return r.t > 0.0)
	queue_redraw()


func _draw() -> void:
	Accessibility.scale_about(self, SIZE)
	var y := BOTTOM
	for i in range(_rows.size() - 1, -1, -1):
		var r: Dictionary = _rows[i]
		var style: Dictionary = STYLE.get(r.verb, {"sign": "+", "color": Color8(238, 226, 196)})
		var text := "%s%d %s" % [style.sign, r.count, ItemCatalog.item_name(r.id)]
		var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var box := Rect2(RIGHT - tw - 28, y - ROW_H, tw + 28, ROW_H - 2)
		var a := clampf(r.t / FADE, 0.0, 1.0)
		draw_rect(box, Color(BG, BG.a * a))
		draw_rect(box, Color(BORDER, a), false)
		_icon(Vector2(box.position.x + 12, box.get_center().y), r.id, a)
		draw_string(_font, Vector2(box.position.x + 22, box.end.y - 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(style.color, a))
		y -= ROW_H


## 16x16 item icon (the small variant when there is one), else a colour chip.
func _icon(c: Vector2, id: String, a: float) -> void:
	for path in ["res://assets/ui/icons/items/small/%s.png" % id, "res://assets/ui/icons/items/%s.png" % id]:
		if ResourceLoader.exists(path):
			draw_texture_rect(load(path), Rect2(c - Vector2(8, 8), Vector2(16, 16)), false, Color(1, 1, 1, a))
			return
	draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), Color(ItemCatalog.ITEMS[id].color, a))
