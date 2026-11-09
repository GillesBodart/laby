extends Control
## Pause / settings menu (Esc). Pauses the game and offers Resume, Save and
## Load (one of SaveSystem.SLOTS slots, slot 1 = quick save), Controls (click a
## shortcut, then press the new key) and Quit. Drawn in 480x270 UI space.
## With title_mode (title screen) it is a plain SETTINGS menu: Controls, Sound
## and Back, without pausing nor opening on Esc.

const SIZE := Vector2(480, 270)
const PANEL := Rect2(90, 40, 300, 196)
const WIDE := Rect2(30, 38, 420, 214)
const ROW_H := 15.0

const INK := Color8(27, 20, 16)
const GREEN_DARK := Color8(24, 38, 30)
const GREEN := Color8(50, 76, 58)
const GREEN_LINE := Color8(108, 148, 116)
const CREAM := Color8(236, 222, 186)
const TAN := Color8(214, 176, 124)
const BROWN := Color8(96, 72, 48)
const TEXT_DARK := Color8(58, 42, 30)
const TEXT_LIGHT := Color8(238, 226, 196)
const FADED := Color8(150, 126, 98)
const GOLD := Color8(242, 210, 92)

const MAIN := ["Resume", "Save game", "Load game", "Controls", "Sound", "Quit game"]
const TITLE_MAIN := ["Controls", "Sound", "Back"]
const VOLUME_LABELS := {"master": "Master volume", "sfx": "Effects", "ambience": "Ambience"}

## "main" | "save" | "load" | "controls" | "sound"
var page := "main"
## Action waiting for a key press ("" = none).
var waiting := ""
var status := ""
## Opened from the title screen (see the class comment).
var title_mode := false
var _opened_on := "main"
var _hover := -1
var _font: Font


func _ready() -> void:
	add_to_group("settings_menu")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = SIZE
	_font = ThemeDB.get_project_theme().default_font


func open(start_page := "main") -> void:
	for p in get_tree().get_nodes_in_group("ui_panels"):
		p.visible = false
	page = start_page
	_opened_on = start_page
	waiting = ""
	status = ""
	visible = true
	if not title_mode:
		get_tree().paused = true


func close() -> void:
	visible = false
	waiting = ""
	if not title_mode:
		get_tree().paused = false


func _any_panel_open() -> bool:
	for p in get_tree().get_nodes_in_group("ui_panels"):
		if p.visible:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if title_mode:
			return
		# Esc first closes an open panel (they handle it); otherwise opens the menu.
		if event is InputEventKey and event.pressed and not event.echo \
				and event.physical_keycode == KEY_ESCAPE and not _any_panel_open():
			open()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if waiting != "":
			_finish_rebind(event.physical_keycode)
		elif event.physical_keycode == KEY_ESCAPE:
			back()
		elif event.physical_keycode in [KEY_DOWN, KEY_UP]:
			var n := _rows().size()
			_hover = posmod((_hover if _hover >= 0 else -1) + (1 if event.physical_keycode == KEY_DOWN else -1), n)
		elif event.physical_keycode in [KEY_LEFT, KEY_RIGHT] and page == "sound":
			adjust(_hover, 1 if event.physical_keycode == KEY_RIGHT else -1)
		elif event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and _hover >= 0:
			activate(_hover)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if waiting != "":
			waiting = ""
			status = "Cancelled."
			return
		var i := _row_at(get_local_mouse_position())
		if i >= 0:
			activate(i)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT \
			and page == "sound":
		adjust(_row_at(get_local_mouse_position()), -1)


## Changes the volume on row i of the Sound page by d steps.
func adjust(i: int, d: int) -> void:
	if page != "sound" or i < 0 or i >= Sound.CHANNELS.size():
		return
	var ch: String = Sound.CHANNELS[i]
	Sound.set_volume(ch, int(Sound.volume[ch]) + d)
	Sound.play("ui")


func back() -> void:
	if page == "main" or (title_mode and page == _opened_on):
		close()
	else:
		page = "main"
		status = ""
		_hover = -1


## Runs the row at index i of the current page.
func activate(i: int) -> void:
	var rows := _rows()
	if i < 0 or i >= rows.size():
		return
	Sound.play("ui")
	match page:
		"main" when title_mode:
			match i:
				0: _goto("controls")
				1: _goto("sound")
				2: close()
		"main":
			match i:
				0: close()
				1: _goto("save")
				2: _goto("load")
				3: _goto("controls")
				4: _goto("sound")
				5: get_tree().quit()
		"sound":
			if i < Sound.CHANNELS.size():
				# Click steps up and wraps; right-click / Left arrow steps down.
				var ch: String = Sound.CHANNELS[i]
				Sound.set_volume(ch, (int(Sound.volume[ch]) + 1) % 11)
			else:
				back()
		"save", "load":
			if i == SaveSystem.SLOTS:
				back()
			elif page == "save":
				var ok := SaveSystem.save_game(i) == OK
				status = ("Saved to slot %d." % (i + 1)) if ok else "Could not save!"
			elif SaveSystem.has_save(i):
				close()
				SaveSystem.load_game(i)
			else:
				status = "Slot %d is empty." % (i + 1)
		"controls":
			if i < KeyBindings.ACTIONS.size():
				waiting = KeyBindings.ACTIONS[i][0]
				status = "Press a key for %s (Esc cancels)" % KeyBindings.ACTIONS[i][1]
			elif i == KeyBindings.ACTIONS.size():
				KeyBindings.reset_defaults()
				status = "Default controls restored."
			else:
				back()


func _goto(p: String) -> void:
	page = p
	status = ""
	_hover = -1


func _finish_rebind(key: Key) -> void:
	var action := waiting
	waiting = ""
	if key == KEY_ESCAPE:
		status = "Cancelled."
		return
	var other := KeyBindings.action_for_key(key)
	if not KeyBindings.rebind(action, key):
		status = "That key is reserved."
	elif other != "" and other != action:
		status = "%s = %s (swapped with %s)" % [_label(action), KeyBindings.key_label(key), _label(other)]
	else:
		status = "%s = %s" % [_label(action), KeyBindings.key_label(key)]


func _label(action: String) -> String:
	for a in KeyBindings.ACTIONS:
		if a[0] == action:
			return a[1]
	return action

# ------------------------------------------------------------- layout

## Row captions for the current page.
func _rows() -> Array:
	match page:
		"sound":
			var out := []
			for ch in Sound.CHANNELS:
				out.append(VOLUME_LABELS[ch])
			out.append("Back")
			return out
		"save", "load":
			var out := []
			for s in SaveSystem.SLOTS:
				out.append("Slot %d%s" % [s + 1, " (quick)" if s == 0 else ""])
			out.append("Back")
			return out
		"controls":
			var out := []
			for a in KeyBindings.ACTIONS:
				out.append(a[1])
			out.append_array(["Reset defaults", "Back"])
			return out
	return TITLE_MAIN if title_mode else MAIN


func _row_rect(i: int) -> Rect2:
	match page:
		"main":
			return Rect2(PANEL.position.x + 70, PANEL.position.y + 24 + i * 27, PANEL.size.x - 140, 22)
		"sound":
			if i == Sound.CHANNELS.size():
				return Rect2(PANEL.get_center().x - 40, PANEL.position.y + 34 + i * 40, 80, 22)
			return Rect2(PANEL.position.x + 18, PANEL.position.y + 26 + i * 40, PANEL.size.x - 36, 32)
		"save", "load":
			if i == SaveSystem.SLOTS:
				return Rect2(PANEL.get_center().x - 40, PANEL.position.y + 32 + i * 38, 80, 22)
			return Rect2(PANEL.position.x + 18, PANEL.position.y + 26 + i * 38, PANEL.size.x - 36, 32)
		"controls":
			var n: int = KeyBindings.ACTIONS.size()
			var half := ceili(n / 2.0)
			if i >= n:
				# Buttons sit just below the last binding row so they never cover one.
				var w := 96.0
				var x := WIDE.get_center().x - w - 6 if i == n else WIDE.get_center().x + 6
				return Rect2(x, WIDE.position.y + 14 + half * ROW_H + 3, w, 17)
			var col := i / half
			var row := i % half
			return Rect2(WIDE.position.x + 16 + col * 200, WIDE.position.y + 14 + row * ROW_H, 188, ROW_H - 3)
	return Rect2()


func _row_at(m: Vector2) -> int:
	for i in _rows().size():
		if _row_rect(i).has_point(m):
			return i
	return -1


func _process(_delta: float) -> void:
	if not visible:
		return
	var i := _row_at(get_local_mouse_position())
	if i >= 0:
		_hover = i
	queue_redraw()

# ------------------------------------------------------------- drawing

func _box(r: Rect2, fill: Color, border: Color, radius := 4) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, r)


func _text(pos: Vector2, s: String, size_px: int, col: Color) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func _text_center(cx: float, y: float, s: String, size_px: int, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	_text(Vector2(cx - w / 2.0, y), s, size_px, col)


func _frame(r: Rect2) -> void:
	_box(r, GREEN_DARK, INK, 8)
	var inner := r.grow(-5)
	_box(inner, GREEN, GREEN_DARK, 6)
	var f := inner.grow(-4)
	var x := f.position.x
	while x < f.end.x:
		draw_rect(Rect2(x, f.position.y, 3, 1), GREEN_LINE)
		draw_rect(Rect2(x, f.end.y - 1, 3, 1), GREEN_LINE)
		x += 6
	var y := f.position.y
	while y < f.end.y:
		draw_rect(Rect2(f.position.x, y, 1, 3), GREEN_LINE)
		draw_rect(Rect2(f.end.x - 1, y, 1, 3), GREEN_LINE)
		y += 6


func _button(r: Rect2, caption: String, hot: bool, size_px := 12) -> void:
	_box(r, CREAM if hot else TAN, GOLD if hot else BROWN, 3)
	_text_center(r.get_center().x, r.get_center().y + size_px * 0.35, caption, size_px, TEXT_DARK)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.03, 0.05, 0.08, 0.78))
	var frame := WIDE if page == "controls" else PANEL
	var titles := {"main": "SETTINGS" if title_mode else "PAUSED", "save": "SAVE GAME", "load": "LOAD GAME", "controls": "CONTROLS", "sound": "SOUND"}
	var title := Rect2(frame.get_center().x - 70, 10, 140, 24)
	_box(title, CREAM, BROWN, 3)
	_text_center(title.get_center().x, 28, titles[page], 16, TEXT_DARK)
	_frame(frame)
	var rows := _rows()
	match page:
		"main":
			for i in rows.size():
				_button(_row_rect(i), rows[i], i == _hover, 14)
		"sound":
			for i in rows.size():
				var r := _row_rect(i)
				if i == Sound.CHANNELS.size():
					_button(r, rows[i], i == _hover)
					continue
				var level := int(Sound.volume[Sound.CHANNELS[i]])
				_box(r, CREAM if i == _hover else TAN, GOLD if i == _hover else BROWN, 3)
				_text(r.position + Vector2(8, 13), rows[i], 12, TEXT_DARK)
				_text(r.end - Vector2(28, 19), "%d" % level, 12, TEXT_DARK)
				for p in 10:
					var pip := Rect2(r.position.x + 8 + p * 21, r.position.y + 18, 18, 8)
					draw_rect(pip, BROWN)
					if p < level:
						draw_rect(pip.grow(-1), GREEN if p < 7 else GOLD)
		"save", "load":
			for i in rows.size():
				var r := _row_rect(i)
				if i == SaveSystem.SLOTS:
					_button(r, rows[i], i == _hover)
					continue
				var summary := SaveSystem.slot_summary(i)
				var usable := page == "save" or summary != ""
				_box(r, CREAM if i == _hover and usable else TAN, GOLD if i == _hover else BROWN, 3)
				_text(r.position + Vector2(8, 13), rows[i], 12, TEXT_DARK)
				_text(r.position + Vector2(8, 26), summary if summary != "" else "- empty -", 10, TEXT_DARK if summary != "" else FADED)
		"controls":
			var n: int = KeyBindings.ACTIONS.size()
			for i in n:
				var r := _row_rect(i)
				var action: String = KeyBindings.ACTIONS[i][0]
				var hot := i == _hover
				if hot or waiting == action:
					draw_rect(r, Color(1, 1, 1, 0.08))
				_text(r.position + Vector2(4, 10), rows[i], 11, TEXT_LIGHT)
				var key_box := Rect2(r.end.x - 66, r.position.y, 66, r.size.y)
				var label := "..." if waiting == action else KeyBindings.key_label(KeyBindings.key_of(action))
				_box(key_box, CREAM if waiting == action or hot else TAN, GOLD if waiting == action else BROWN, 2)
				_text_center(key_box.get_center().x, key_box.position.y + 10, label, 10, TEXT_DARK)
			_button(_row_rect(n), rows[n], _hover == n, 11)
			_button(_row_rect(n + 1), rows[n + 1], _hover == n + 1, 11)
	var hint := "[Esc] back   [Click] select" if page != "main" or title_mode else "[Esc] resume   [Click] select"
	if page == "sound":
		hint = "[Click]/[Right] louder   [Right-click]/[Left] softer   [Esc] back"
	draw_rect(Rect2(0, 254, SIZE.x, 16), Color(0.03, 0.05, 0.08, 0.95))
	if page == "controls" and status != "":
		_text_center(frame.get_center().x, 264, status, 11, GOLD)
		return
	if status != "":
		_text_center(frame.get_center().x, frame.end.y + 13, status, 11, GOLD)
	_text_center(frame.get_center().x, 264, hint, 11, TEXT_LIGHT)
