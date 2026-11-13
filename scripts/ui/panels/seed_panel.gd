extends Control
## Seed picker: opens when E is pressed on an empty farm plot. Lists every crop
## (seeds you carry first); click one or press its number key to sow it.
## Crops whose seed you have never found show as "?".

const PANEL := Rect2(90, 34, 300, 196)
const ROW := Vector2(140, 18)
const COLS := 2

const INK := Color8(27, 20, 16)
const CREAM := Color8(236, 222, 186)
const TAN := Color8(214, 176, 124)
const BROWN := Color8(96, 72, 48)
const TEXT_DARK := Color8(58, 42, 30)
const FADED := Color8(150, 126, 98)
const GOLD := Color8(242, 210, 92)
const GREEN := Color8(50, 76, 58)
const GREEN_DARK := Color8(24, 38, 30)
const TEXT_LIGHT := Color8(238, 226, 196)

var plot: Node = null
var _font: Font
var _hover := -1
var _icons := {}


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.get_project_theme().default_font
	EventBus.farm_plot_used.connect(open)


func _player() -> Player:
	return GameState.players.get(GameState.local_peer_id())


func open(target: Node) -> void:
	for p in get_tree().get_nodes_in_group("ui_panels"):
		if p != self:
			p.visible = false
	plot = target
	visible = true


## Crop ids in display order: sowable now, then known, then undiscovered.
func entries() -> Array:
	var player := _player()
	var out := Farming.crop_ids()
	if player == null:
		return out
	var rank := func(id: String) -> int:
		var seed_id: String = Farming.CROPS[id].seed
		if player.inventory.count(seed_id) > 0:
			return 0
		return 1 if player.inventory.knows(seed_id) else 2
	var order := {}
	for i in out.size():
		order[out[i]] = i
	out.sort_custom(func(a: String, b: String) -> bool:
		var ra: int = rank.call(a)
		var rb: int = rank.call(b)
		return ra < rb or (ra == rb and order[a] < order[b]))
	return out


## Sows the crop; returns true when planted.
func plant(crop_id: String) -> bool:
	var player := _player()
	if player == null or plot == null or not is_instance_valid(plot):
		return false
	var ok: bool = plot.farm_interact(player, crop_id)
	if ok:
		visible = false
	return ok


func _row_rect(i: int) -> Rect2:
	return Rect2(PANEL.position + Vector2(8 + (i % COLS) * (ROW.x + 4), 34 + (i / COLS) * (ROW.y + 2)), ROW)


func _process(_delta: float) -> void:
	if not visible:
		return
	if plot == null or not is_instance_valid(plot):
		visible = false
		return
	var player := _player()
	if player == null or player.global_position.distance_to(plot.global_position) > 64.0:
		visible = false
		return
	_hover = -1
	var m := get_local_mouse_position()
	for i in Farming.CROPS.size():
		if _row_rect(i).has_point(m):
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
			var list := entries()
			if k - KEY_1 < list.size():
				plant(list[k - KEY_1])
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover >= 0:
			plant(entries()[_hover])
		elif not PANEL.has_point(get_local_mouse_position()):
			visible = false
		get_viewport().set_input_as_handled()


func _box(r: Rect2, fill: Color, border: Color, radius := 3) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, r)


func _text(pos: Vector2, s: String, col: Color, fs := 16) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Draws s shrinking the font (12 down to 9) so it fits in width.
func _fit_text(pos: Vector2, s: String, col: Color, width: float) -> void:
	var fs := 12
	while fs > 9 and _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, fs, col, TextServer.JUSTIFICATION_NONE)


func _icon(c: Vector2, id: String, tint := Color.WHITE) -> void:
	var path := "res://assets/ui/icons/items/%s.png" % id
	if not ResourceLoader.exists(path):
		draw_rect(Rect2(c - Vector2(4, 4), Vector2(8, 8)), ItemCatalog.ITEMS[id].color * tint)
		return
	if not _icons.has(path):
		_icons[path] = load(path)
	var tex: Texture2D = _icons[path]
	draw_set_transform((c - Vector2(tex.get_size()) * 0.25).round(), 0.0, Vector2(0.5, 0.5))
	draw_texture(tex, Vector2.ZERO, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	var player := _player()
	if player == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.08, 0.6))
	_box(PANEL, GREEN_DARK, INK, 4)
	draw_rect(PANEL.grow(-3), GREEN, false)
	var title := Rect2(PANEL.get_center().x - 60, PANEL.position.y + 6, 120, 22)
	_box(title, CREAM, BROWN)
	var t := "PLANT A SEED"
	_text(Vector2(title.get_center().x - _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x / 2.0, title.end.y - 5), t, TEXT_DARK)
	var list := entries()
	for i in list.size():
		var id: String = list[i]
		var def: Dictionary = Farming.CROPS[id]
		var have := player.inventory.count(def.seed)
		var known := player.inventory.knows(def.seed)
		var r := _row_rect(i)
		_box(r, CREAM if have > 0 else TAN, GOLD if i == _hover and have > 0 else BROWN)
		var col := TEXT_DARK if have > 0 else FADED
		if i < 9:
			_text(r.position + Vector2(3, 13), "%d" % (i + 1), FADED, 10)
		if known:
			_icon(r.position + Vector2(18, 9), def.yield, Color.WHITE if have > 0 else Color(1, 1, 1, 0.5))
			var info := "x%d  %dm" % [have, ceili(def.minutes / 120.0)]
			var w := _font.get_string_size(info, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			_text(Vector2(r.end.x - w - 4, r.position.y + 13), info, col, 10)
			_fit_text(r.position + Vector2(29, 13), ItemCatalog.item_name(def.yield), col, r.size.x - 29 - w - 8)
		else:
			_text(r.position + Vector2(29, 13), "? ? ?", FADED, 12)
	var hint := "Click or 1-9 to sow  -  Esc to close"
	if _hover >= 0 and _hover < list.size():
		var def: Dictionary = Farming.CROPS[list[_hover]]
		if player.inventory.knows(def.seed):
			hint = "%s: %d-%d %s, ripe in %d min, +%d XP" % [ItemCatalog.item_name(def.seed), def.min, def.max, ItemCatalog.item_name(def.yield), ceili(def.minutes / 120.0), def.xp]
		else:
			hint = "Find this seed in the wild first."
	var hw := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	_text(Vector2(PANEL.get_center().x - hw / 2.0, PANEL.end.y - 8), hint, TEXT_LIGHT, 10)
