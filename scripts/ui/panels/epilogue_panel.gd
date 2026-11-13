extends Control
## Epilogue shown once, when the players first walk out of the maze: what the
## run took (days, guardians, people, discoveries), then walk back in or go
## back to the title. Opened in the Clearing after the escape travel (see
## GameState.epilogue_pending). Pauses the game while open.
## Also the end of a permadeath run (open_fallen): same summary, and the only
## way out is the title screen.

const PANEL := Rect2(110, 34, 260, 202)
const BUTTON := Vector2(112, 20)

const INK := UiPalette.INK
const CREAM := UiPalette.CREAM
const BROWN := UiPalette.BROWN
const TEXT_DARK := UiPalette.TEXT_DARK
const GOLD := UiPalette.GOLD
const TEXT_LIGHT := UiPalette.TEXT_LIGHT
const TEXT_DIM := UiPalette.TEXT_DIM
const BUTTONS := ["Walk back in", "Title screen"]
const FALLEN_BUTTONS := ["Title screen"]

var _font: Font
var _hover := -1
## True when showing the end of a permadeath run.
var fallen := false


func _ready() -> void:
	add_to_group("ui_panels")
	add_to_group("epilogue_panel")
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


## The player fell in a permadeath run.
func open_fallen() -> void:
	fallen = true
	open()


func _buttons() -> Array:
	return FALLEN_BUTTONS if fallen else BUTTONS


## [label, value] lines of the run summary.
static func stats() -> Array:
	var tamed := GameState.companions.size()
	var found := 0
	for kind in GameState.journal:
		found += GameState.journal[kind].size()
	return [
		["Days in the maze", str(TimeSystem.clock.day())],
		["Guardians slain", "%d / %d" % [GameState.bosses_defeated.size(), Sectors.ORDER.size()]],
		["Survivors in the camp", str(GameState.survivors.size())],
		["Creatures tamed", str(tamed)],
		["Journal entries", str(found)],
		["Structures built", str(GameState.structures.size())],
	]


## Who walks out: the survivors of the camp, or the player alone.
static func together_line(survivors: int) -> String:
	if survivors <= 0:
		return "You walk out alone, and that is allowed."
	return "%d of you walk out together, squinting." % (survivors + 1)


func choose(i: int) -> void:
	Sound.play("ui")
	visible = false
	get_tree().paused = false
	if fallen or i == 1:
		GameState.change_scene("res://scenes/ui/main_menu.tscn")


func _button_rect(i: int) -> Rect2:
	var n := _buttons().size()
	var x := PANEL.position.x + (PANEL.size.x - BUTTON.x * n - 8.0 * (n - 1)) / 2.0 + i * (BUTTON.x + 8.0)
	return Rect2(Vector2(x, PANEL.end.y - BUTTON.y - 10.0), BUTTON)


func _process(_delta: float) -> void:
	if not visible:
		return
	_hover = -1
	for i in _buttons().size():
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
	UiFrame.plate(self, r, fill, border)


## Centred line, text-size scaled and shrunk to fit inside the panel.
func _center(y: float, s: String, px: int, col: Color) -> void:
	var sz := UiFrame.fs(px)
	while sz > 8 and _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > PANEL.size.x - 16:
		sz -= 1
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string(_font, Vector2(roundf(PANEL.get_center().x - w / 2.0), y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.SHADE)
	UiFrame.box(self, PANEL)
	var title := UiFrame.title_plate(self, PANEL.get_center().x, PANEL.position.y + 8, "YOU DID NOT SURVIVE" if fallen else "OUT OF THE MAZE", 140)
	var y := title.end.y + 16.0
	if fallen:
		_center(y, "One life, and the maze has taken it.", 10, TEXT_LIGHT)
		_center(y + 12.0, "This run's saves are gone with you.", 10, TEXT_DIM)
	else:
		_center(y, "Light. Wind. An open sky with no walls in it.", 10, TEXT_LIGHT)
		_center(y + 11.0, "Behind you, the old engines grind on, guarding nothing.", 10, TEXT_DIM)
		_center(y + 22.0, together_line(GameState.survivors.size()), 10, TEXT_DIM)
		y += 8.0
	y += 30.0
	var rs := UiFrame.fs(12, 1.15)
	for row in stats():
		draw_string(_font, Vector2(PANEL.position.x + 28, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, rs, TEXT_LIGHT)
		draw_string(_font, Vector2(PANEL.position.x + 28, y), row[1], HORIZONTAL_ALIGNMENT_RIGHT, PANEL.size.x - 56, rs, GOLD)
		y += 15.0
	var buttons := _buttons()
	var bs := UiFrame.fs(12, 1.15)
	for i in buttons.size():
		var r := _button_rect(i)
		_box(r, CREAM, GOLD if i == _hover else BROWN)
		var label: String = "%d  %s" % [i + 1, buttons[i]]
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
		draw_string(_font, Vector2(roundf(r.get_center().x - w / 2.0), r.end.y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, TEXT_DARK)
	UiFrame.footer(self, "[{click}] / [1-%d] choose" % buttons.size())
