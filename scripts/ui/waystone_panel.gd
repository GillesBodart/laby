extends Control
## Waystone travel picker: lists the Clearing and every sector already
## reached; click one or press its number key to travel there.

const PANEL := Rect2(140, 50, 200, 170)
const ROW := Vector2(184, 18)

const INK := Color8(27, 20, 16)
const CREAM := Color8(236, 222, 186)
const BROWN := Color8(96, 72, 48)
const TEXT_DARK := Color8(58, 42, 30)
const FADED := Color8(150, 126, 98)
const GOLD := Color8(242, 210, 92)
const SLATE := Color8(44, 58, 72)
const SLATE_DARK := Color8(22, 30, 40)
const TEXT_LIGHT := Color8(238, 226, 196)

var stone: Node = null
var _font: Font
var _hover := -1


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	EventBus.waystone_used.connect(open)


func open(target: Node) -> void:
	for p in get_tree().get_nodes_in_group("ui_panels"):
		if p != self:
			p.visible = false
	stone = target
	visible = true


## Destinations: the Clearing, then reached sectors in maze order.
static func destinations() -> Array:
	var out := ["clearing"]
	for s in Sectors.ORDER:
		if GameState.reached.has(s):
			out.append(s)
	return out


func go(i: int) -> void:
	var list := destinations()
	if i < 0 or i >= list.size():
		return
	visible = false
	if list[i] == GameState.area:
		EventBus.notify.emit("You are already there.")
		return
	EventBus.notify.emit("The waystone hums...")
	GameState.travel(list[i])


func _row_rect(i: int) -> Rect2:
	return Rect2(PANEL.position + Vector2(8, 34 + i * (ROW.y + 2)), ROW)


func _process(_delta: float) -> void:
	if not visible:
		return
	var player: Player = GameState.players.get(GameState.local_peer_id())
	if stone == null or not is_instance_valid(stone) or player == null \
			or player.global_position.distance_to(stone.global_position) > 64.0:
		visible = false
		return
	_hover = -1
	for i in destinations().size():
		if _row_rect(i).has_point(get_local_mouse_position()):
			_hover = i
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k == KEY_ESCAPE:
			visible = false
		elif k >= KEY_1 and k <= KEY_9:
			go(k - KEY_1)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover >= 0:
			go(_hover)
		elif not PANEL.has_point(get_local_mouse_position()):
			visible = false
		get_viewport().set_input_as_handled()


func _box(r: Rect2, fill: Color, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	draw_style_box(sb, r)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.08, 0.6))
	_box(PANEL, SLATE_DARK, INK)
	draw_rect(PANEL.grow(-3), SLATE, false)
	var title := Rect2(PANEL.get_center().x - 50, PANEL.position.y + 6, 100, 22)
	_box(title, CREAM, BROWN)
	var t := "WAYSTONE"
	draw_string(_font, Vector2(title.get_center().x - _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x / 2.0, title.end.y - 5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_DARK)
	var list := destinations()
	for i in list.size():
		var r := _row_rect(i)
		var here: bool = list[i] == GameState.area
		_box(r, CREAM, GOLD if i == _hover else BROWN)
		draw_string(_font, r.position + Vector2(4, 13), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, FADED)
		var name := "The Clearing" if list[i] == "clearing" else Sectors.display_name(list[i])
		draw_string(_font, r.position + Vector2(18, 13), name + ("  (here)" if here else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, FADED if here else TEXT_DARK)
	var hint := "Click or 1-9 to travel  -  Esc to close"
	var hw := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(_font, Vector2(PANEL.get_center().x - hw / 2.0, PANEL.end.y - 8), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT_LIGHT)
