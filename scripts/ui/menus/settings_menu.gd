extends Control
## Pause / settings menu (Esc). Pauses the game and offers Resume, Save and
## Load (one of SaveSystem.SLOTS slots, slot 1 = quick save), Controls (click a
## shortcut, then press the new key), Sound, Accessibility (text size,
## colour-blind palette) and Quit. Drawn in 480x270 UI space.
## With title_mode (title screen) it is a plain SETTINGS menu: Controls, Sound,
## Accessibility and Back, without pausing nor opening on Esc.

const SIZE := Vector2(480, 270)
const PANEL := Rect2(90, 40, 300, 196)
const WIDE := Rect2(30, 38, 420, 214)
const ROW_H := 15.0

const INK := UiPalette.INK
const GREEN_DARK := UiPalette.FELT_DARK
const GREEN := UiPalette.FELT
const GREEN_LINE := UiPalette.STITCH
const CREAM := UiPalette.CREAM
const TAN := UiPalette.TAN
const BROWN := UiPalette.BROWN
const TEXT_DARK := UiPalette.TEXT_DARK
const TEXT_LIGHT := UiPalette.TEXT_LIGHT
const FADED := UiPalette.FADED
const GOLD := UiPalette.GOLD

const MAIN := ["Resume", "Save game", "Load game", "Controls", "Sound", "Accessibility", "Quit game"]
const TITLE_MAIN := ["Controls", "Sound", "Accessibility", "Back"]
const ACCESS_HINTS := [
	"Bigger text: HUD, panels, prompts, notices, damage.",
	"Orange / blue / yellow instead of red / green on the map,\npanels, companion markers and durability bars.",
]
const VOLUME_LABELS := {"master": "Master volume", "sfx": "Effects", "ambience": "Ambience"}

## "main" | "save" | "load" | "controls" | "sound" | "access"
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
				2: _goto("access")
				3: close()
		"main":
			match i:
				0: close()
				1: _goto("save")
				2: _goto("load")
				3: _goto("controls")
				4: _goto("sound")
				5: _goto("access")
				6: get_tree().quit()
		"access":
			match i:
				0: Accessibility.set_text_size(Accessibility.text_size + 1)
				1: Accessibility.set_colorblind(not Accessibility.colorblind)
				_: back()
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
		"access":
			return ["Text size: %s" % Accessibility.text_size_name(),
				"Colour-blind palette: %s" % ("On" if Accessibility.colorblind else "Off"), "Back"]
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
			# Seven rows in the pause menu: tighter steps so they fit the frame.
			var step := 24.0 if _rows().size() > 6 else 27.0
			return Rect2(PANEL.position.x + 70, PANEL.position.y + 20 + i * step, PANEL.size.x - 140, 20 if step < 27.0 else 22)
		"access":
			if i == 2:
				return Rect2(PANEL.get_center().x - 40, PANEL.position.y + 34 + i * 40, 80, 22)
			return Rect2(PANEL.position.x + 30, PANEL.position.y + 26 + i * 40, PANEL.size.x - 60, 26)
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
	UiFrame.plate(self, r, fill, border, radius)


## Text at a base size scaled by the text-size setting.
func _text(pos: Vector2, s: String, size_px: int, col: Color) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFrame.fs(size_px), col)


func _text_center(cx: float, y: float, s: String, size_px: int, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFrame.fs(size_px)).x
	_text(Vector2(cx - w / 2.0, y), s, size_px, col)


func _frame(r: Rect2) -> void:
	UiFrame.box(self, r)


func _button(r: Rect2, caption: String, hot: bool, size_px := 12) -> void:
	_box(r, CREAM if hot else TAN, GOLD if hot else BROWN, 3)
	var sz := UiFrame.fs(size_px)
	while sz > 8 and _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > r.size.x - 6:
		sz -= 1
	var w := _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string(_font, Vector2(r.get_center().x - w / 2.0, roundf(r.get_center().y + minf(sz, r.size.y) * 0.35)), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, TEXT_DARK)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.03, 0.05, 0.08, 0.78))
	var frame := WIDE if page == "controls" else PANEL
	var titles := {"main": "SETTINGS" if title_mode else "PAUSED", "save": "SAVE GAME", "load": "LOAD GAME", "controls": "CONTROLS", "sound": "SOUND", "access": "ACCESSIBILITY"}
	_frame(frame)
	UiFrame.title_plate(self, frame.get_center().x, frame.position.y - 28, titles[page], 160)
	var rows := _rows()
	match page:
		"main":
			for i in rows.size():
				_button(_row_rect(i), rows[i], i == _hover, 14)
		"access":
			for i in rows.size():
				_button(_row_rect(i), rows[i], i == _hover, 12)
			# Live preview of both settings.
			var y := PANEL.position.y + 150.0
			if _hover >= 0 and _hover < ACCESS_HINTS.size():
				var lines: PackedStringArray = String(ACCESS_HINTS[_hover]).split("\n")
				for k in lines.size():
					_text_center(PANEL.get_center().x, y + k * 11, lines[k], 9, TEXT_LIGHT)
			var px := PANEL.get_center().x - 60
			for k in 3:
				var key: String = ["danger", "resource", "ally"][k]
				draw_circle(Vector2(px + k * 60, PANEL.end.y - 18), 4.0, Accessibility.color(key))
				_text(Vector2(px + k * 60 + 7, PANEL.end.y - 14), ["Danger", "Resource", "Ally"][k], 9, TEXT_LIGHT)
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
	var hint := "[{back}] back  [{click}] select" if page != "main" or title_mode else "[{back}] resume  [{click}] select"
	if page == "sound":
		hint = "[{click}] / [Right] louder  [{right_click}] / [Left] softer  [{back}] back"
	draw_rect(Rect2(0, 254, SIZE.x, 16), Color(0.03, 0.05, 0.08, 0.95))
	if page == "controls" and status != "":
		_text_center(frame.get_center().x, UiFrame.FOOTER_Y, status, 11, GOLD)
		return
	if status != "":
		_text_center(frame.get_center().x, frame.end.y + 13, status, 11, GOLD)
	UiFrame.footer(self, hint)
