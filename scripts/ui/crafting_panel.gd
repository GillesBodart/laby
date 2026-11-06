extends PanelContainer
## Backpack / crafting screen (I). Two tabs (Tab key or click): a diamond-slot
## backpack with an item note card, and the crafting list (1-0 or click).

const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
const SIZE := Vector2(480, 270)
const COLS := 5
const PITCH := Vector2(52, 40)
const DIAMOND := 18
const PANEL := Rect2(44, 36, 320, 196)
const CARD := Rect2(372, 56, 100, 150)
const TABS := ["INVENTORY", "CRAFTING"]

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
const OK := Color8(46, 110, 50)

var tab := 0
var _font: Font
var _hover := -1


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--tab=1"):
		tab = 1
	add_to_group("ui_panels")
	visible = false
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	custom_minimum_size = SIZE
	size = SIZE
	position = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _player() -> Player:
	return GameState.players.get(GameState.local_peer_id())


func _process(_delta: float) -> void:
	if not visible:
		return
	_hover = _hover_index(get_local_mouse_position())
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		for p in get_tree().get_nodes_in_group("ui_panels"):
			if p != self:
				p.visible = false
		visible = not visible
		get_viewport().set_input_as_handled()
	elif not visible:
		return
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			visible = false
		elif event.physical_keycode == KEY_TAB:
			tab = (tab + 1) % TABS.size()
		else:
			var idx := KEYS.find(event.physical_keycode)
			if idx >= 0 and idx < ItemCatalog.RECIPES.size():
				craft(idx)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_local_mouse_position()
		for i in TABS.size():
			if _tab_rect(i).has_point(m):
				tab = i
				return
		if tab == 1 and _hover >= 0:
			craft(_hover)


func craft(index: int) -> bool:
	var player := _player()
	if player == null:
		return false
	var recipe: Dictionary = ItemCatalog.RECIPES[index]
	var ok := Crafting.craft(player.inventory, recipe, player.nearby_stations())
	var item := ItemCatalog.item_name(recipe.id)
	EventBus.notify.emit(("Crafted %s" % item) if ok else ("Cannot craft %s" % item))
	return ok


# ------------------------------------------------------------- layout

func _tab_rect(i: int) -> Rect2:
	return Rect2(14, 60 + i * 30, 24, 24)


func _slot_center(i: int) -> Vector2:
	var origin := PANEL.position + Vector2((PANEL.size.x - COLS * PITCH.x) / 2.0 + PITCH.x / 2.0, 30)
	return origin + Vector2((i % COLS) * PITCH.x, (i / COLS) * PITCH.y)


func _row_rect(i: int) -> Rect2:
	return Rect2(PANEL.position.x + 14, PANEL.position.y + 10 + i * 18, PANEL.size.x - 28, 17)


func _hover_index(m: Vector2) -> int:
	if tab == 0:
		for i in Inventory.DEFAULT_SLOTS:
			var d := (m - _slot_center(i)).abs()
			if d.x + d.y <= DIAMOND:
				return i
	else:
		for i in ItemCatalog.RECIPES.size():
			if _row_rect(i).has_point(m):
				return i
	return -1


# ------------------------------------------------------------- drawing

func _text(pos: Vector2, s: String, col: Color) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _text_center(cx: float, y: float, s: String, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_text(Vector2(cx - w / 2.0, y), s, col)


func _box(r: Rect2, fill: Color, border: Color, radius := 4) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, r)


func _diamond(c: Vector2, r: float, fill: Color, border: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, border, 1.0)


var _icon_cache := {}


func _icon_tex(path: String) -> Texture2D:
	if not _icon_cache.has(path):
		_icon_cache[path] = ImageTexture.create_from_image((load(path) as Texture2D).get_image())
	return _icon_cache[path]


func _icon(c: Vector2, id: String, half := 6) -> void:
	var small := half < 5
	var path := "res://assets/ui/items/%s%s.png" % [id, "_s" if small else ""]
	if ResourceLoader.exists(path):
		var tex := _icon_tex(path)
		var sz := Vector2(tex.get_size()) * 0.5
		draw_set_transform((c - sz * 0.5).round(), 0.0, Vector2(0.5, 0.5))
		draw_texture(tex, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var col: Color = ItemCatalog.ITEMS[id].color
	if ItemCatalog.tool_of(id) != "":
		draw_line(c + Vector2(-half, half), c + Vector2(half, -half + 2), Color8(120, 84, 52), 2.0)
		var head := Rect2(c + Vector2(1, -half - 1), Vector2(half + 1, 5))
		draw_rect(head, col)
		draw_rect(head, INK, false)
		return
	var r := Rect2(c - Vector2(half, half), Vector2(half * 2, half * 2))
	draw_rect(r, col)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), col.lightened(0.3))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), col.darkened(0.3))
	draw_rect(r, INK, false)


func _draw() -> void:
	var player := _player()
	if player == null:
		return
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.03, 0.05, 0.08, 0.72))

	# Title plaque.
	var title := Rect2(PANEL.position.x + PANEL.size.x / 2.0 - 70, 8, 140, 24)
	_box(title, CREAM, BROWN, 3)
	draw_rect(Rect2(title.position + Vector2(3, 3), title.size - Vector2(6, 6)), Color(0, 0, 0, 0), false)
	_text_center(title.get_center().x, 26, TABS[tab], TEXT_DARK)

	# Side tabs.
	for i in TABS.size():
		var r := _tab_rect(i)
		_box(r, CREAM if tab == i else TAN, GOLD if tab == i else BROWN, 3)
		if i == 0:
			var c := r.get_center()
			draw_rect(Rect2(c + Vector2(-6, -3), Vector2(12, 9)), BROWN)
			draw_rect(Rect2(c + Vector2(-3, -6), Vector2(6, 3)), BROWN)
			draw_rect(Rect2(c + Vector2(-6, 0), Vector2(12, 1)), CREAM)
		else:
			var c := r.get_center()
			draw_line(c + Vector2(-5, 5), c + Vector2(4, -4), BROWN, 2.0)
			draw_rect(Rect2(c + Vector2(0, -7), Vector2(7, 4)), BROWN)

	# Green panel with dashed inner frame.
	_box(PANEL, GREEN_DARK, INK, 8)
	var inner := PANEL.grow(-5)
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

	var detail_id := ""
	var detail_extra := ""
	if tab == 0:
		detail_id = _draw_backpack(player)
	else:
		detail_id = _draw_crafting(player)
		if _hover >= 0:
			var rec: Dictionary = ItemCatalog.RECIPES[_hover]
			detail_extra = "At %s" % rec.station if rec.station != "" else "Craft anywhere"
	_draw_card(detail_id, detail_extra)
	_text_center(PANEL.get_center().x, 247, "[I] close   [Tab] switch   [1-0] craft", TEXT_LIGHT)


func _draw_backpack(player: Player) -> String:
	var inv := player.inventory
	var hovered := ""
	for i in inv.slots.size():
		var c := _slot_center(i)
		var s: Dictionary = inv.slots[i]
		var selected := i == _hover
		_diamond(c, DIAMOND, CREAM, GOLD if selected else BROWN)
		_diamond(c, DIAMOND - 4, Color8(240, 200, 140) if selected else TAN, BROWN)
		if s.is_empty():
			continue
		_icon(c + Vector2(0, -3), s.id)
		if selected:
			hovered = s.id
		if s.count > 1:
			var t := "%d" % s.count
			var p := c + Vector2(-_font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x / 2.0, 12)
			_text(p + Vector2(1, 1), t, INK)
			_text(p, t, TEXT_LIGHT)
	return hovered


func _draw_crafting(player: Player) -> String:
	var inv := player.inventory
	var stations := player.nearby_stations()
	for i in ItemCatalog.RECIPES.size():
		var rec: Dictionary = ItemCatalog.RECIPES[i]
		var ok := Crafting.can_craft(inv, rec, stations)
		var r := _row_rect(i)
		_box(r, CREAM if ok else TAN, GOLD if i == _hover else BROWN, 3)
		_icon(r.position + Vector2(10, 8.5), rec.id, 5)
		_text(r.position + Vector2(20, 13), "%d" % ((i + 1) % 10), BROWN)
		var label := ItemCatalog.item_name(rec.id)
		if rec.out > 1:
			label += " x%d" % rec.out
		_text(r.position + Vector2(32, 13), label, TEXT_DARK if ok else FADED)
		var ex := r.end.x - 5
		for k in rec["in"].keys():
			var amount := "%d" % rec["in"][k]
			var aw := _font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			_text(Vector2(ex - aw, r.position.y + 13), amount, OK if ok else FADED)
			_icon(Vector2(ex - aw - 6, r.position.y + 8.5), k, 3)
			ex -= aw + 16
		if rec.station != "":
			var tag := "bench" if rec.station == "workbench" else "fire"
			var tw := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			_text(Vector2(ex - tw, r.position.y + 13), tag, BROWN if ok else FADED)
	return ItemCatalog.RECIPES[_hover].id if _hover >= 0 else ""


func _draw_card(id: String, extra: String) -> void:
	_box(CARD, CREAM, BROWN, 2)
	var ly := CARD.position.y + 44
	while ly < CARD.end.y - 6:
		draw_rect(Rect2(CARD.position.x + 6, ly, CARD.size.x - 12, 1), TAN)
		ly += 13
	if id == "":
		draw_multiline_string(_font, CARD.position + Vector2(8, 22), "Hover an item\nfor details.", HORIZONTAL_ALIGNMENT_LEFT, CARD.size.x - 16, 16, -1, FADED)
		return
	_text_center(CARD.get_center().x, CARD.position.y + 16, ItemCatalog.item_name(id), TEXT_DARK)
	draw_rect(Rect2(CARD.position.x + 8, CARD.position.y + 21, CARD.size.x - 16, 1), BROWN)
	var body := ItemCatalog.description(id)
	if extra != "":
		body += "\n" + extra
	draw_multiline_string(_font, CARD.position + Vector2(8, 38), body, HORIZONTAL_ALIGNMENT_LEFT, CARD.size.x - 16, 16, -1, TEXT_DARK)
