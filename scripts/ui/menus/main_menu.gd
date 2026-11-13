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
	"Recoverable: wake at camp; your backpack waits where you fell.\nPermanent: one life; death ends the run and erases its saves.",
	"Recoverable: a fallen companion rests at the campfire.\nPermanent: a companion that falls is gone for good.",
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
## Pre-built backdrop: [[Rect2, Color], ...] fills, wall faces, wall shadows,
## [[centre, radius], ...] moss, grass tufts and the glowing glyph points.
var _tiles: Array = []
var _faces: Array[Rect2] = []
var _shadows: Array[Rect2] = []
var _moss: Array = []
var _tufts: Array[Vector2] = []
var _glyphs: Array[Vector2] = []


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
			"Companion death: %s" % ("Permanent" if companion_permadeath else "Recoverable"), "Back"]
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
## then turns it into smooth shapes once: flat fills, soft wall shadows,
## rounded moss and grass blades.
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
	_faces.clear()
	_shadows.clear()
	_moss.clear()
	_tufts.clear()
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
					_shadows.append(Rect2(r.position, Vector2(CELL, 4)))
				if grass and rng.randf() < 0.35:
					_tufts.append(r.position + Vector2(rng.randf_range(2, CELL - 3), rng.randf_range(4, CELL - 2)))
				continue
			# Top-down 3/4 wall: a stone top, plus a front face when open below.
			var face := open.has(cell + Vector2i.DOWN)
			_tiles.append([r, STONE_TOP])
			if face:
				_faces.append(Rect2(r.position + Vector2(0, CELL - 4), Vector2(CELL, 4)))
			if rng.randf() < 0.18:
				var moss := r.position + Vector2(rng.randf_range(1.5, CELL - 1.5), rng.randf_range(1.0, 4.0))
				_moss.append([moss, rng.randf_range(1.2, 2.2)])
			elif face and rng.randf() < 0.04:
				_glyphs.append(r.position + Vector2(5, CELL - 2))


## A rect filled with a vertical (or horizontal) two-colour gradient.
func _gradient_rect(r: Rect2, from: Color, to: Color, vertical := true) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var cols := PackedColorArray([from, from if vertical else to, to, to if vertical else from])
	draw_polygon(pts, cols)


func _draw_backdrop() -> void:
	for t in _tiles:
		draw_rect(t[0], t[1])
	for r in _faces:
		_gradient_rect(r, STONE_FACE, STONE_SHADOW.lerp(STONE_FACE, 0.5))
	for r in _shadows:
		_gradient_rect(r, Color(STONE_SHADOW, 0.85), Color(STONE_SHADOW, 0.0))
	for m in _moss:
		var c: Vector2 = m[0]
		var rad: float = m[1]
		draw_circle(c, rad, MOSS, true, -1.0, true)
		draw_circle(c + Vector2(rad * 0.8, rad * 0.3), rad * 0.7, MOSS.lightened(0.08), true, -1.0, true)
	for p in _tufts:
		draw_line(p, p + Vector2(-0.8, -2.4), GRASS_LIGHT, 0.6, true)
		draw_line(p + Vector2(1.2, 0), p + Vector2(1.6, -2.8), GRASS_LIGHT, 0.6, true)
	for i in _glyphs.size():
		var a := 0.35 + 0.65 * absf(sin(_time * 0.8 + i * 1.7))
		draw_circle(_glyphs[i], 3.0, Color(GLOW, a * 0.18), true, -1.0, true)
		draw_circle(_glyphs[i], 1.1, Color(GLOW, a), true, -1.0, true)
	# Soft vignette darkening the edges.
	var edge := Color(NIGHT, 0.75)
	var clear := Color(NIGHT, 0.0)
	var v := 40.0
	_gradient_rect(Rect2(0, 0, SIZE.x, v), edge, clear)
	_gradient_rect(Rect2(0, SIZE.y - v, SIZE.x, v), clear, edge)
	_gradient_rect(Rect2(0, 0, v, SIZE.y), edge, clear, false)
	_gradient_rect(Rect2(SIZE.x - v, 0, v, SIZE.y), clear, edge, false)

# ------------------------------------------------------------- drawing

func _box(r: Rect2, fill: Color, border: Color, radius := 4) -> void:
	UiFrame.plate(self, r, fill, border, radius)


## Centred text at a base size scaled by the text-size setting, shrunk to
## `width` when given.
func _text_center(cx: float, y: float, s: String, size_px: int, col: Color, width := -1.0) -> void:
	var sz := UiFrame.fs(size_px)
	while width > 0.0 and sz > 8 and _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > width:
		sz -= 1
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string(_font, Vector2(cx - w / 2.0, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _draw() -> void:
	_draw_backdrop()
	var cx := SIZE.x / 2.0
	var plaque := Rect2(cx - 92, 14, 184, 62)
	UiFrame.box(self, plaque)
	draw_string(_font, Vector2(cx - _font.get_string_size("LABY", HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x / 2.0 + 2, 54), "LABY", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Menu.INK)
	draw_string(_font, Vector2(cx - _font.get_string_size("LABY", HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x / 2.0, 52), "LABY", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Menu.GOLD)
	_text_center(cx, 69, "The walls remember.", 10, Menu.TEXT_LIGHT, plaque.size.x - 16)
	var can_load := has_any_save()
	var list := rows()
	for i in list.size():
		var r := _row_rect(i)
		var usable := page != "" or i != 1 or can_load
		var hot := i == _hover and not _settings.visible
		var harsh := page == "new" and ((i == 1 and permadeath) or (i == 2 and companion_permadeath))
		_box(r, Menu.CREAM if hot and usable else Menu.TAN, Menu.GOLD if hot else (Accessibility.color("bad") if harsh else Menu.BROWN), 3)
		_text_center(r.get_center().x, r.get_center().y + 5, list[i], 14 if page == "" else 12, Menu.TEXT_DARK if usable else Menu.FADED, r.size.x - 6)
	draw_rect(Rect2(0, 254, SIZE.x, 16), Color(0.03, 0.05, 0.08, 0.95))
	if page == "new" and _hover >= 0 and not _settings.visible:
		var lines: PackedStringArray = String(NEW_HINTS[_hover]).split("\n")
		var lh := float(UiFrame.fs(10)) + 2.0
		var box := Rect2(cx - 160, 202, 320, 8 + lines.size() * lh)
		_box(box, Color(0.03, 0.05, 0.08, 0.85), Menu.BROWN, 3)
		for k in lines.size():
			_text_center(cx, box.position.y + 2 + lh * (k + 1), lines[k], 10, Menu.TEXT_LIGHT, box.size.x - 8)
	elif status != "":
		_text_center(cx, 214, status, 11, Menu.GOLD, SIZE.x - 16)
	UiFrame.footer(self, "[Up/Down] choose  [Enter] / [{click}] select")
