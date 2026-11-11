class_name MainMenu
extends Control
## Title screen (the main scene): New game, Load game, Settings and Exit.
## Load game and Settings open the pause menu in title_mode (its slot and
## Controls / Sound pages). Drawn in 480x270 UI space at 2x, over a maze
## backdrop with the Clearing at its heart. Keyboard (Up/Down/Enter), mouse
## and pad (via Gamepad's cursor) all work. New game opens a small page to
## pick the run's death rules before it begins.

const SCENE := "res://scenes/ui/main_menu.tscn"
const Menu := preload("res://scripts/ui/menus/settings_menu.gd")

const SIZE := Vector2(480, 270)
const ROWS := ["New game", "Load game", "Settings", "Exit"]
const BUTTON := Vector2(120, 20)
const WIDE_BUTTON := Vector2(220, 20)
## New game page: Begin, the two death rules (toggles), Back.
const NEW_HINTS := [
	"Start the run with these rules.",
	"Recoverable: wake at camp, your pack waits where you fell.\nPermanent: one life; death ends the run and erases its saves.",
	"Recover: a downed companion rests at the campfire.\nPermanent: a companion that falls is gone for good.",
	"Back to the title.",
]
const BUTTON_TOP := 98.0
const BUTTON_STEP := 25.0

## Backdrop maze: CELL-pixel tiles on an odd grid (walls between corridors),
## shifted left by half a tile so 49 tiles centre on the 480 px screen.
const CELL := 10
const GRID := Vector2i(49, 27)
const ORIGIN := Vector2(-5, 0)
## Open grass in the middle (tiles), under the buttons.
const CLEARING := Rect2i(17, 8, 15, 12)
const BACKDROP_SEED := 1997

const FLOOR := Color8(30, 36, 32)
const STONE_TOP := Color8(84, 90, 82)
const STONE_FACE := Color8(56, 62, 58)
const STONE_SHADOW := Color8(20, 24, 26)
const MOSS := Color8(66, 94, 58)
const GRASS := Color8(54, 88, 50)
const GRASS_LIGHT := Color8(78, 114, 62)
const GLOW := Color8(150, 226, 196)
const NIGHT := Color(0.02, 0.03, 0.05, 0.22)

var status := ""
## "" (title rows) or "new" (new game rules).
var page := ""
var permadeath := false
var companion_permadeath := false
var _hover := -1
var _font: Font
var _time := 0.0
var _settings: Control
## Pre-built backdrop: [[Rect2, Color], ...] and the glowing glyph rects.
var _tiles: Array = []
var _glyphs: Array[Rect2] = []


func _ready() -> void:
	add_to_group("title_menu")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = SIZE
	# UI is laid out for 480x270 and drawn at 2x on the 960x540 viewport.
	scale = Vector2(2, 2)
	_font = ThemeDB.get_project_theme().default_font
	get_tree().paused = false
	TimeSystem.paused = true
	_build_backdrop()
	_settings = Control.new()
	_settings.set_script(Menu)
	_settings.title_mode = true
	add_child(_settings)


func _exit_tree() -> void:
	TimeSystem.paused = false


func has_any_save() -> bool:
	for s in SaveSystem.SLOTS:
		if SaveSystem.has_save(s):
			return true
	return false


func rows() -> Array:
	if page == "new":
		return ["Begin", "Your death: %s" % ("Permanent" if permadeath else "Recoverable"),
			"Companions: %s" % ("Permanent" if companion_permadeath else "Recover"), "Back"]
	return ROWS


## Runs row i of the current page.
func activate(i: int) -> void:
	if i < 0 or i >= rows().size():
		return
	Sound.play("ui")
	status = ""
	if page == "new":
		match i:
			0:
				start_new_game()
			1:
				permadeath = not permadeath
			2:
				companion_permadeath = not companion_permadeath
			3:
				page = ""
				_hover = 0
		return
	match i:
		0:
			page = "new"
			_hover = 0
		1:
			if has_any_save():
				_settings.open("load")
			else:
				status = "No saved games yet."
		2:
			_settings.open("main")
		3:
			get_tree().quit()


func start_new_game() -> void:
	GameState.new_game(0, {"permadeath": permadeath, "companion_permadeath": companion_permadeath})
	TimeSystem.reset()
	GameState.change_scene(GameState.area_scene())


func _unhandled_input(event: InputEvent) -> void:
	if _settings.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_DOWN, KEY_UP:
				var d := 1 if event.physical_keycode == KEY_DOWN else -1
				_hover = posmod((_hover if _hover >= 0 else (-1 if d > 0 else 0)) + d, rows().size())
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if page != "":
					activate(rows().size() - 1)
					get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _hover >= 0:
					activate(_hover)
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _row_at(get_local_mouse_position())
		if i >= 0:
			activate(i)
			get_viewport().set_input_as_handled()


func _row_rect(i: int) -> Rect2:
	var b := WIDE_BUTTON if page == "new" else BUTTON
	return Rect2(SIZE.x / 2.0 - b.x / 2.0, BUTTON_TOP + i * BUTTON_STEP, b.x, b.y)


func _row_at(m: Vector2) -> int:
	for i in rows().size():
		if _row_rect(i).has_point(m):
			return i
	return -1


func _process(delta: float) -> void:
	_time += delta
	if not _settings.visible:
		var i := _row_at(get_local_mouse_position())
		if i >= 0:
			_hover = i
	queue_redraw()

# ------------------------------------------------------------- backdrop

## Carves a perfect maze (recursive backtracker, fixed seed) and the Clearing,
## then turns it into flat-coloured pixel rects once.
func _build_backdrop() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = BACKDROP_SEED
	var open := {}
	var start := Vector2i(1, 1)
	open[start] = true
	var stack: Array[Vector2i] = [start]
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var options := []
		for d in dirs:
			var n: Vector2i = c + d * 2
			if n.x > 0 and n.y > 0 and n.x < GRID.x - 1 and n.y < GRID.y - 1 and not open.has(n):
				options.append(d)
		if options.is_empty():
			stack.pop_back()
			continue
		var step: Vector2i = options[rng.randi() % options.size()]
		open[c + step] = true
		open[c + step * 2] = true
		stack.append(c + step * 2)
	for y in range(CLEARING.position.y, CLEARING.end.y):
		for x in range(CLEARING.position.x, CLEARING.end.x):
			open[Vector2i(x, y)] = true

	_tiles.clear()
	_glyphs.clear()
	for y in GRID.y:
		for x in GRID.x:
			var cell := Vector2i(x, y)
			var r := Rect2(ORIGIN + Vector2(cell * CELL), Vector2(CELL, CELL))
			if open.has(cell):
				var grass := CLEARING.has_point(cell)
				_tiles.append([r, GRASS if grass else FLOOR])
				if not open.has(cell + Vector2i.UP):
					# Wall shadow falling on the floor below it.
					_tiles.append([Rect2(r.position, Vector2(CELL, 2)), STONE_SHADOW])
				if grass and rng.randf() < 0.35:
					var tuft := r.position + Vector2(rng.randi_range(1, CELL - 4), rng.randi_range(3, CELL - 3))
					_tiles.append([Rect2(tuft, Vector2(1, 2)), GRASS_LIGHT])
					_tiles.append([Rect2(tuft + Vector2(2, 0), Vector2(1, 2)), GRASS_LIGHT])
				continue
			# Top-down 3/4 wall: a stone top, plus a front face when open below.
			var face := open.has(cell + Vector2i.DOWN)
			_tiles.append([r, STONE_TOP])
			if face:
				_tiles.append([Rect2(r.position + Vector2(0, CELL - 4), Vector2(CELL, 4)), STONE_FACE])
			if rng.randf() < 0.18:
				var moss := r.position + Vector2(rng.randi_range(0, CELL - 3), rng.randi_range(0, 3))
				_tiles.append([Rect2(moss, Vector2(3, 2)), MOSS])
			elif face and rng.randf() < 0.04:
				_glyphs.append(Rect2(r.position + Vector2(4, CELL - 3), Vector2(2, 2)))


func _draw_backdrop() -> void:
	for t in _tiles:
		draw_rect(t[0], t[1])
	for i in _glyphs.size():
		var a := 0.35 + 0.65 * absf(sin(_time * 0.8 + i * 1.7))
		draw_rect(_glyphs[i], Color(GLOW, a))
	# Stepped (pixel) vignette: each band darkens the edges a bit more.
	for band in 4:
		var t := 8.0 * (band + 1)
		draw_rect(Rect2(0, 0, SIZE.x, t), NIGHT)
		draw_rect(Rect2(0, SIZE.y - t, SIZE.x, t), NIGHT)
		draw_rect(Rect2(0, t, t, SIZE.y - 2 * t), NIGHT)
		draw_rect(Rect2(SIZE.x - t, t, t, SIZE.y - 2 * t), NIGHT)

# ------------------------------------------------------------- drawing

func _box(r: Rect2, fill: Color, border: Color, radius := 4) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, r)


func _text_center(cx: float, y: float, s: String, size_px: int, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(_font, Vector2(cx - w / 2.0, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func _draw() -> void:
	_draw_backdrop()
	var cx := SIZE.x / 2.0
	var plaque := Rect2(cx - 92, 14, 184, 62)
	_box(plaque, Menu.GREEN_DARK, Menu.INK, 8)
	_box(plaque.grow(-4), Menu.GREEN, Menu.GREEN_DARK, 6)
	_text_center(cx + 2, 54, "LABY", 36, Menu.INK)
	_text_center(cx, 52, "LABY", 36, Menu.GOLD)
	_text_center(cx, 69, "The walls remember.", 10, Menu.TEXT_LIGHT)
	var can_load := has_any_save()
	var list := rows()
	for i in list.size():
		var r := _row_rect(i)
		var usable := page != "" or i != 1 or can_load
		var hot := i == _hover and not _settings.visible
		var harsh := page == "new" and ((i == 1 and permadeath) or (i == 2 and companion_permadeath))
		_box(r, Menu.CREAM if hot and usable else Menu.TAN, Menu.GOLD if hot else (Color8(170, 50, 40) if harsh else Menu.BROWN), 3)
		_text_center(r.get_center().x, r.get_center().y + 5, list[i], 14 if page == "" else 12, Menu.TEXT_DARK if usable else Menu.FADED)
	draw_rect(Rect2(0, 254, SIZE.x, 16), Color(0.03, 0.05, 0.08, 0.95))
	if page == "new" and _hover >= 0 and not _settings.visible:
		var lines: PackedStringArray = String(NEW_HINTS[_hover]).split("\n")
		var box := Rect2(cx - 160, 202, 320, 8 + lines.size() * 12)
		_box(box, Color(0.03, 0.05, 0.08, 0.85), Menu.BROWN, 3)
		for k in lines.size():
			_text_center(cx, box.position.y + 14 + k * 12, lines[k], 10, Menu.TEXT_LIGHT)
	elif status != "":
		_text_center(cx, 214, status, 11, Menu.GOLD)
	_text_center(cx, 264, "[Up/Down] choose   [Enter]/[Click] select", 11, Menu.TEXT_LIGHT)
