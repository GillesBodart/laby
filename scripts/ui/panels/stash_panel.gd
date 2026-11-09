extends Control
## Chest window (E on a chest, or G next to one): backpack grid on the left,
## shared Stash on the right (kept on death). Click a slot to move the whole
## stack across, right-click to move one. 1 = store materials, 2 = take all.
## Tools and placeable items stay in the backpack when storing materials.

const REACH := 80.0
const PANEL := Rect2(40, 26, 392, 220)
const SLOT := 22.0
const PITCH := 24.0
const BAG_COLS := 6
const STASH_COLS := 8
const BAG_ORIGIN := Vector2(52, 74)
const STASH_ORIGIN := Vector2(228, 74)

const INK := Color8(27, 20, 16)
const CREAM := Color8(236, 222, 186)
const TAN := Color8(214, 176, 124)
const SLOT_FILL := Color8(176, 136, 92)
const BROWN := Color8(96, 72, 48)
const TEXT_DARK := Color8(58, 42, 30)
const GOLD := Color8(242, 210, 92)
const GREEN := Color8(50, 76, 58)
const GREEN_DARK := Color8(24, 38, 30)
const TEXT_LIGHT := Color8(238, 226, 196)

var _font: Font
var _icons := {}
## Hovered target: {"side": "bag"/"stash", "index": int} or {"button": 1/2} or {}.
var _hover := {}


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.get_project_theme().default_font
	EventBus.chest_used.connect(open)


func _player() -> Player:
	return GameState.players.get(GameState.local_peer_id())


func near_chest() -> bool:
	var player := _player()
	if player == null:
		return false
	for c in get_tree().get_nodes_in_group("chest"):
		if c.global_position.distance_to(player.global_position) <= REACH:
			return true
	return false


func open() -> void:
	for p in get_tree().get_nodes_in_group("ui_panels"):
		if p != self:
			p.visible = false
	visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("stash"):
		if visible:
			visible = false
		elif near_chest():
			open()
		else:
			EventBus.notify.emit("Stand next to a chest to open the Stash.")
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				visible = false
			KEY_1:
				deposit()
			KEY_2:
				withdraw()
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_click(event.button_index == MOUSE_BUTTON_RIGHT)
			get_viewport().set_input_as_handled()


func _click(one: bool) -> void:
	var player := _player()
	if player == null:
		return
	if _hover.has("button"):
		if _hover.button == 1:
			deposit()
		else:
			withdraw()
	elif _hover.has("side"):
		if _hover.side == "bag":
			player.inventory.move_to(GameState.stash, _hover.index, 1 if one else 9999)
		else:
			GameState.stash.move_to(player.inventory, _hover.index, 1 if one else 9999)
	elif not PANEL.has_point(get_local_mouse_position()):
		visible = false


## Stores every material (not tools or placeables); returns the amount moved.
func deposit() -> int:
	var player := _player()
	if player == null:
		return 0
	var moved := 0
	for i in player.inventory.slots.size():
		var s: Dictionary = player.inventory.slots[i]
		if s.is_empty() or ItemCatalog.tool_of(s.id) != "" or BuildCatalog.is_placeable(s.id):
			continue
		moved += player.inventory.move_to(GameState.stash, i, s.count)
	return moved


func withdraw() -> int:
	var player := _player()
	if player == null:
		return 0
	var moved := 0
	for i in GameState.stash.slots.size():
		if not GameState.stash.slots[i].is_empty():
			moved += GameState.stash.move_to(player.inventory, i, GameState.stash.slots[i].count)
	return moved


func _slot_rect(origin: Vector2, cols: int, i: int) -> Rect2:
	return Rect2(origin + Vector2(i % cols, i / cols) * PITCH, Vector2(SLOT, SLOT))


func _button_rect(n: int) -> Rect2:
	var origin := BAG_ORIGIN if n == 1 else STASH_ORIGIN
	var w := BAG_COLS * PITCH - 2 if n == 1 else STASH_COLS * PITCH - 2
	return Rect2(origin + Vector2(0, 5 * PITCH + 4), Vector2(w, 16))


func _process(_delta: float) -> void:
	if not visible:
		return
	if not near_chest():
		visible = false
		return
	var player := _player()
	var m := get_local_mouse_position()
	_hover = {}
	for i in player.inventory.slots.size():
		if _slot_rect(BAG_ORIGIN, BAG_COLS, i).has_point(m):
			_hover = {"side": "bag", "index": i}
	for i in GameState.stash.slots.size():
		if _slot_rect(STASH_ORIGIN, STASH_COLS, i).has_point(m):
			_hover = {"side": "stash", "index": i}
	for n in [1, 2]:
		if _button_rect(n).has_point(m):
			_hover = {"button": n}
	queue_redraw()


func _box(r: Rect2, fill: Color, border: Color, radius := 3) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, r)


func _text(pos: Vector2, s: String, col: Color, fs := 12) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _centered(r: Rect2, s: String, col: Color, fs := 12) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_text(Vector2(r.get_center().x - w / 2.0, r.get_center().y + fs * 0.35), s, col, fs)


func _icon(c: Vector2, id: String) -> void:
	var path := "res://assets/ui/icons/items/%s.png" % id
	if not ResourceLoader.exists(path):
		draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), ItemCatalog.ITEMS[id].color)
		return
	if not _icons.has(path):
		_icons[path] = load(path)
	var tex: Texture2D = _icons[path]
	draw_set_transform((c - Vector2(tex.get_size()) * 0.25).round(), 0.0, Vector2(0.5, 0.5))
	draw_texture(tex, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _grid(inv: RefCounted, origin: Vector2, cols: int, side: String) -> void:
	for i in inv.slots.size():
		var r := _slot_rect(origin, cols, i)
		var s: Dictionary = inv.slots[i]
		var hovered: bool = _hover.get("side", "") == side and _hover.get("index", -1) == i
		_box(r, SLOT_FILL if not s.is_empty() else Color(SLOT_FILL, 0.45), GOLD if hovered else BROWN, 2)
		if s.is_empty():
			continue
		_icon(r.get_center() + Vector2(0, -1), s.id)
		if s.count > 1:
			var t := str(s.count)
			var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			var p := r.end - Vector2(w + 1, 2)
			_text(p + Vector2(1, 1), t, INK, 9)
			_text(p, t, TEXT_LIGHT, 9)


func _draw() -> void:
	var player := _player()
	if player == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.08, 0.6))
	_box(PANEL, GREEN_DARK, INK, 4)
	draw_rect(PANEL.grow(-3), GREEN, false)
	var title := Rect2(PANEL.get_center().x - 50, PANEL.position.y + 6, 100, 22)
	_box(title, CREAM, BROWN)
	_centered(title, "CHEST", TEXT_DARK, 16)
	_text(BAG_ORIGIN + Vector2(0, -6), "BACKPACK", TEXT_LIGHT)
	var used := GameState.stash.slots.filter(func(s): return not s.is_empty()).size()
	_text(STASH_ORIGIN + Vector2(0, -6), "STASH  %d/%d" % [used, GameState.stash.slots.size()], TEXT_LIGHT)
	var note := "safe on death"
	var nw := _font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	_text(Vector2(STASH_ORIGIN.x + STASH_COLS * PITCH - 2 - nw, STASH_ORIGIN.y - 6), note, GOLD, 9)
	_grid(player.inventory, BAG_ORIGIN, BAG_COLS, "bag")
	_grid(GameState.stash, STASH_ORIGIN, STASH_COLS, "stash")
	var arrow_x := (BAG_ORIGIN.x + BAG_COLS * PITCH + STASH_ORIGIN.x) / 2.0 - 1
	var ay := BAG_ORIGIN.y + 2.5 * PITCH
	draw_colored_polygon(PackedVector2Array([Vector2(arrow_x - 6, ay - 9), Vector2(arrow_x + 2, ay - 9), Vector2(arrow_x + 2, ay - 12), Vector2(arrow_x + 7, ay - 6), Vector2(arrow_x + 2, ay), Vector2(arrow_x + 2, ay - 3), Vector2(arrow_x - 6, ay - 3)]), GOLD)
	draw_colored_polygon(PackedVector2Array([Vector2(arrow_x + 6, ay + 3), Vector2(arrow_x - 2, ay + 3), Vector2(arrow_x - 2, ay), Vector2(arrow_x - 7, ay + 6), Vector2(arrow_x - 2, ay + 12), Vector2(arrow_x - 2, ay + 9), Vector2(arrow_x + 6, ay + 9)]), TAN)
	for n in [1, 2]:
		var r := _button_rect(n)
		var hot: bool = _hover.get("button", 0) == n
		_box(r, CREAM if hot else TAN, GOLD if hot else BROWN)
		_centered(r, "[1] Store materials" if n == 1 else "[2] Take all", TEXT_DARK, 10)
	var hint := "Click: move stack   Right-click: move one   Esc: close"
	if _hover.has("side"):
		var inv: RefCounted = player.inventory if _hover.side == "bag" else GameState.stash
		var s: Dictionary = inv.slots[_hover.index]
		if not s.is_empty():
			hint = "%s x%d  -  %s" % [ItemCatalog.item_name(s.id), s.count, "click to store" if _hover.side == "bag" else "click to take"]
	_centered(Rect2(PANEL.position.x, PANEL.end.y - 16, PANEL.size.x, 12), hint, TEXT_LIGHT, 10)