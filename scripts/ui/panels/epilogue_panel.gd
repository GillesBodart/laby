extends Control
## Epilogue shown once, when the players first walk out of the Maze: what the
## run took (days, guardians, people, discoveries), then keep exploring or go
## back to the title. Opened in the Clearing after the escape travel (see
## GameState.epilogue_pending). Pauses the game while open.

const PANEL := Rect2(110, 34, 260, 202)
const BUTTON := Vector2(112, 20)

const INK := Color8(27, 20, 16)
const CREAM := Color8(236, 222, 186)
const BROWN := Color8(96, 72, 48)
const TEXT_DARK := Color8(58, 42, 30)
const GOLD := Color8(242, 210, 92)
const SLATE := Color8(44, 58, 72)
const SLATE_DARK := Color8(22, 30, 40)
const TEXT_LIGHT := Color8(238, 226, 196)
const TEXT_DIM := Color8(170, 182, 190)
const BUTTONS := ["Keep exploring", "Title screen"]

var _font: Font
var _hover := -1


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.get_project_theme().default_font
	if GameState.epilogue_pending:
		GameState.epilogue_pending = false
		open.call_deferred()


func open() -> void:
	for p in get_tree().get_nodes_in_group("ui_panels"):
		if p != self:
			p.visible = false
	visible = true
	get_tree().paused = true
	Sound.play("horn")


## [label, value] lines of the run summary.
static func stats() -> Array:
	var tamed := GameState.companions.size()
	var found := 0
	for kind in GameState.journal:
		found += GameState.journal[kind].size()
	return [
		["Days in the Maze", str(TimeSystem.clock.day())],
		["Guardians slain", "%d / %d" % [GameState.bosses_defeated.size(), Sectors.ORDER.size()]],
		["Survivors in the camp", str(GameState.survivors.size())],
		["Creatures tamed", str(tamed)],
		["Journal entries", str(found)],
		["Structures built", str(GameState.structures.size())],
	]


func choose(i: int) -> void:
	Sound.play("ui")
	visible = false
	get_tree().paused = false
	if i == 1:
		GameState.change_scene("res://scenes/ui/main_menu.tscn")


func _button_rect(i: int) -> Rect2:
	var x := PANEL.position.x + (PANEL.size.x - BUTTON.x * 2.0 - 8.0) / 2.0 + i * (BUTTON.x + 8.0)
	return Rect2(Vector2(x, PANEL.end.y - BUTTON.y - 10.0), BUTTON)


func _process(_delta: float) -> void:
	if not visible:
		return
	_hover = -1
	for i in BUTTONS.size():
		if _button_rect(i).has_point(get_local_mouse_position()):
			_hover = i
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE, KEY_ENTER, KEY_E, KEY_1:
				choose(0)
			KEY_2:
				choose(1)
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover >= 0:
			choose(_hover)
		get_viewport().set_input_as_handled()


func _box(r: Rect2, fill: Color, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	draw_style_box(sb, r)


func _center(y: float, s: String, px: int, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font, Vector2(roundf(PANEL.get_center().x - w / 2.0), y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.72))
	_box(PANEL, SLATE_DARK, INK)
	draw_rect(PANEL.grow(-3), SLATE, false)
	var title := Rect2(PANEL.get_center().x - 70, PANEL.position.y + 8, 140, 22)
	_box(title, CREAM, BROWN)
	var t := "OUT OF THE MAZE"
	draw_string(_font, Vector2(title.get_center().x - _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x / 2.0, title.end.y - 5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_DARK)
	var y := title.end.y + 16.0
	_center(y, "Light. Wind. An open sky with no walls in it.", 10, TEXT_LIGHT)
	_center(y + 12.0, "Behind you, the Maze keeps grinding.", 10, TEXT_DIM)
	y += 30.0
	for row in stats():
		draw_string(_font, Vector2(PANEL.position.x + 28, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT_LIGHT)
		draw_string(_font, Vector2(PANEL.position.x + 28, y), row[1], HORIZONTAL_ALIGNMENT_RIGHT, PANEL.size.x - 56, 12, GOLD)
		y += 15.0
	for i in BUTTONS.size():
		var r := _button_rect(i)
		_box(r, CREAM, GOLD if i == _hover else BROWN)
		var label: String = "%d  %s" % [i + 1, BUTTONS[i]]
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(_font, Vector2(roundf(r.get_center().x - w / 2.0), r.end.y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT_DARK)
