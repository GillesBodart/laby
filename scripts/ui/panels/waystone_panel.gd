extends Control
## Waystone travel picker: lists the Clearing and every sector already
## reached; click one or press its number key to travel there.

const PANEL := Rect2(140, 50, 200, 170)
const ROW := Vector2(184, 18)

const CREAM := UiPalette.CREAM
const BROWN := UiPalette.BROWN
const TEXT_DARK := UiPalette.TEXT_DARK
const FADED := UiPalette.FADED
const GOLD := UiPalette.GOLD

var stone: Node = null
var _font: Font
var _hover := -1


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.get_project_theme().default_font
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


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.SHADE)
	UiFrame.box(self, PANEL)
	UiFrame.title_plate(self, PANEL.get_center().x, PANEL.position.y + 6, "WAYSTONE", 100)
	var list := destinations()
	var num := UiFrame.fs(10)
	var big := UiFrame.fs(12)
	for i in list.size():
		var r := _row_rect(i)
		var here: bool = list[i] == GameState.area
		UiFrame.plate(self, r, CREAM, GOLD if i == _hover else BROWN)
		if i < 9:
			draw_string(_font, r.position + Vector2(4, 13), "%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, num, FADED)
		var name := "The Clearing" if list[i] == "clearing" else Sectors.display_name(list[i])
		draw_string(_font, r.position + Vector2(18, 13), name + ("  (here)" if here else ""), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 22, big, FADED if here else TEXT_DARK)
	UiFrame.footer(self, "[{click}] / [1-%d] travel  [{back}] close" % mini(list.size(), 9))
