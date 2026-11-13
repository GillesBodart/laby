extends Node
## Gamepad support (Xbox layout names; any SDL-mapped pad works).
##
## In play: left stick moves, right stick aims shots, A attack, B dodge roll,
## X gather / use (hold), Y backpack, LB eat, RB drink, LT run, RT place /
## repair in build mode, D-pad up skills / down journal / left next building /
## right build mode, L3 companions follow/stay, R3 remove building, Back map,
## Start pause menu (it acts as Esc: it also closes any open panel).
##
## While a panel or the pause menu is open the pad drives a mouse cursor:
## left stick (or D-pad) moves it, A clicks, X right-clicks, B or Y goes back (Esc).

const DEADZONE := 0.25
## Cursor speed in viewport pixels per second at full tilt.
const CURSOR_SPEED := 520.0

## Joypad events added to each action on top of the keyboard keys.
const BUTTONS := {
	"attack": [JOY_BUTTON_A],
	"dodge": [JOY_BUTTON_B],
	"interact": [JOY_BUTTON_X],
	"inventory": [JOY_BUTTON_Y],
	"eat": [JOY_BUTTON_LEFT_SHOULDER],
	"drink": [JOY_BUTTON_RIGHT_SHOULDER],
	"skills": [JOY_BUTTON_DPAD_UP],
	"journal": [JOY_BUTTON_DPAD_DOWN],
	"build_next": [JOY_BUTTON_DPAD_LEFT],
	"build_toggle": [JOY_BUTTON_DPAD_RIGHT],
	"companion": [JOY_BUTTON_LEFT_STICK],
	"build_remove": [JOY_BUTTON_RIGHT_STICK],
	"map": [JOY_BUTTON_BACK],
}
const BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Up", JOY_BUTTON_DPAD_DOWN: "Down", JOY_BUTTON_DPAD_LEFT: "Left",
	JOY_BUTTON_DPAD_RIGHT: "Right", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "Back",
}
const AXIS_NAMES := {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}
## [axis, direction] pairs.
const AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"run": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"build_place": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}

## True once a pad button or stick was used after the last mouse/key input.
var using_pad := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_pad_events()


## Adds the pad bindings to the input map (idempotent; KeyBindings calls it
## again after restoring the default keys).
func add_pad_events() -> void:
	for action in BUTTONS:
		for b in BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = b
			ev.device = -1
			_add(action, ev)
	for action in AXES:
		var ev := InputEventJoypadMotion.new()
		ev.axis = AXES[action][0]
		ev.axis_value = AXES[action][1]
		ev.device = -1
		_add(action, ev)


func _add(action: String, ev: InputEvent) -> void:
	if InputMap.has_action(action) and not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


## Button or key to show in on-screen prompts, following the last device used.
func prompt(action: String) -> String:
	if using_pad and BUTTONS.has(action):
		return BUTTON_NAMES.get(BUTTONS[action][0], "?")
	if using_pad and AXES.has(action) and AXES[action][0] in AXIS_NAMES:
		return AXIS_NAMES[AXES[action][0]]
	return KeyBindings.key_label(KeyBindings.key_of(action))


## Replaces every {action} token in a text with that action's prompt
## ("Hold {interact}" -> "Hold E" or "Hold X"). Unknown tokens stay as they are.
func fill(text: String) -> String:
	var start := text.find("{")
	while start != -1:
		var end := text.find("}", start)
		if end == -1:
			break
		var action := text.substr(start + 1, end - start - 1)
		if InputMap.has_action(action):
			var label := prompt(action)
			text = text.substr(0, start) + label + text.substr(end + 1)
			start = text.find("{", start + label.length())
		else:
			start = text.find("{", end)
	return text


## True when a panel, the pause menu or the title screen is showing, so the pad
## drives the cursor.
func ui_active() -> bool:
	if get_tree().get_first_node_in_group("title_menu"):
		return true
	var menu := get_tree().get_first_node_in_group("settings_menu") as CanvasItem
	if menu and menu.visible:
		return true
	for p in get_tree().get_nodes_in_group("ui_panels"):
		if p.visible:
			return true
	return false


## True when the pad is steering a menu: gameplay should ignore pad input.
func driving_ui() -> bool:
	return using_pad and ui_active()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		using_pad = true
	elif (event is InputEventKey or event is InputEventMouseButton) and not event.has_meta("pad"):
		using_pad = false
	if not event is InputEventJoypadButton:
		return
	var b: int = event.button_index
	if b == JOY_BUTTON_START:
		if event.pressed:
			send_key(KEY_ESCAPE)
		get_viewport().set_input_as_handled()
		return
	if not ui_active():
		return
	# In menus the pad's gameplay bindings are swallowed and turned into clicks.
	get_viewport().set_input_as_handled()
	if not event.pressed:
		return
	match b:
		JOY_BUTTON_A:
			click(MOUSE_BUTTON_LEFT)
		JOY_BUTTON_X:
			click(MOUSE_BUTTON_RIGHT)
		JOY_BUTTON_B, JOY_BUTTON_Y:
			send_key(KEY_ESCAPE)


## Feeds a key press + release into the input pipeline.
func send_key(key: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.set_meta("pad", true)
		ev.physical_keycode = key
		ev.keycode = key
		ev.pressed = down
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


## Clicks at the cursor.
func click(button: MouseButton) -> void:
	var pos := get_viewport().get_mouse_position()
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.set_meta("pad", true)
		ev.button_index = button
		ev.pressed = down
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


## Stick (or D-pad) vector for the menu cursor, with a dead zone.
static func cursor_vector(stick: Vector2, dpad: Vector2) -> Vector2:
	if dpad != Vector2.ZERO:
		return dpad.normalized() * 0.6
	if stick.length() < DEADZONE:
		return Vector2.ZERO
	return stick.limit_length(1.0) * ((stick.length() - DEADZONE) / (1.0 - DEADZONE))


## Right-stick aim (ZERO inside the dead zone).
static func aim_vector(stick: Vector2) -> Vector2:
	return stick.normalized() if stick.length() >= 0.5 else Vector2.ZERO


func _process(delta: float) -> void:
	if not using_pad or not ui_active():
		return
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var dpad := Vector2(
		float(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT)),
		float(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP)))
	var v := cursor_vector(stick, dpad)
	if v == Vector2.ZERO:
		return
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var pos := (vp.get_mouse_position() + v * CURSOR_SPEED * (size.x / 960.0) * delta).clamp(Vector2.ZERO, size - Vector2.ONE)
	vp.warp_mouse(pos)
