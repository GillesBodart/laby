extends PanelContainer
## Backpack + crafting screen (I). Pixel-RPG layout: item grid on the left,
## recipe list on the right. Press 1-0 to craft the listed recipe.

const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
const COLS := 5
const SLOT := 24
const GAP := 2
const SIZE := Vector2(460, 238)

const INK := Color8(27, 20, 16)
const FRAME := Color8(122, 84, 50)
const FRAME_LIGHT := Color8(166, 120, 72)
const FRAME_DARK := Color8(78, 52, 32)
const PARCHMENT := Color8(52, 40, 34)
const SLOT_BG := Color8(33, 26, 24)
const TEXT := Color8(238, 226, 196)
const DIM := Color8(150, 136, 118)
const GOLD := Color8(242, 210, 92)
const OK := Color8(140, 210, 100)

var _font: Font


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	custom_minimum_size = SIZE
	size = SIZE
	position = ((Vector2(480, 270) - SIZE) / 2.0).floor()
	_font = ThemeDB.fallback_font
	var inv := _inventory()
	if inv:
		inv.changed.connect(queue_redraw)


func _player() -> Player:
	return GameState.players.get(GameState.local_peer_id())


func _inventory() -> Inventory:
	var p := _player()
	return p.inventory if p else null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		for p in get_tree().get_nodes_in_group("ui_panels"):
			if p != self:
				p.visible = false
		visible = not visible
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			visible = false
			return
		var idx := KEYS.find(event.physical_keycode)
		if idx >= 0 and idx < ItemCatalog.RECIPES.size():
			craft(idx)


func craft(index: int) -> bool:
	var player := _player()
	if player == null:
		return false
	var recipe: Dictionary = ItemCatalog.RECIPES[index]
	var ok := Crafting.craft(player.inventory, recipe, player.nearby_stations())
	var item := ItemCatalog.item_name(recipe.id)
	EventBus.notify.emit(("Crafted %s" % item) if ok else ("Cannot craft %s" % item))
	queue_redraw()
	return ok


# ------------------------------------------------------------- drawing

func _text(pos: Vector2, s: String, col: Color, fsize := 16) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _bevel_box(r: Rect2, fill: Color, light: Color, dark: Color) -> void:
	draw_rect(r, fill)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), light)
	draw_rect(Rect2(r.position, Vector2(1, r.size.y)), light)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), dark)
	draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), dark)


func _draw_item_icon(r: Rect2, id: String) -> void:
	var col: Color = ItemCatalog.ITEMS[id].color
	var c := r.get_center().floor()
	var h := 5
	if ItemCatalog.tool_of(id) != "":
		# Tool: handle plus head.
		draw_line(c + Vector2(-5, 6), c + Vector2(5, -4), Color8(120, 84, 52), 2.0)
		draw_rect(Rect2(c + Vector2(1, -7), Vector2(7, 4)), col)
		draw_rect(Rect2(c + Vector2(1, -7), Vector2(7, 4)), INK, false)
		return
	draw_rect(Rect2(c - Vector2(h, h), Vector2(h * 2, h * 2)), col)
	draw_rect(Rect2(c - Vector2(h, h), Vector2(h * 2, 2)), col.lightened(0.3))
	draw_rect(Rect2(c + Vector2(-h, h - 2), Vector2(h * 2, 2)), col.darkened(0.3))
	draw_rect(Rect2(c - Vector2(h, h), Vector2(h * 2, h * 2)), INK, false)


func _draw() -> void:
	var player := _player()
	if player == null:
		return
	# Frame.
	draw_rect(Rect2(Vector2.ZERO, SIZE), INK)
	_bevel_box(Rect2(Vector2(1, 1), SIZE - Vector2(2, 2)), FRAME, FRAME_LIGHT, FRAME_DARK)
	_bevel_box(Rect2(Vector2(5, 5), SIZE - Vector2(10, 10)), PARCHMENT, FRAME_DARK, FRAME_LIGHT)
	# Corner studs.
	for p in [Vector2(3, 3), Vector2(SIZE.x - 5, 3), Vector2(3, SIZE.y - 5), Vector2(SIZE.x - 5, SIZE.y - 5)]:
		draw_rect(Rect2(p, Vector2(2, 2)), GOLD)

	# --- Backpack (left).
	var gx := 14.0
	_text(Vector2(gx, 24), "BACKPACK", GOLD)
	draw_rect(Rect2(gx, 28, COLS * (SLOT + GAP) - GAP, 1), FRAME_LIGHT)
	var inv := player.inventory
	var hover_name := ""
	for i in inv.slots.size():
		var col := i % COLS
		var row := i / COLS
		var r := Rect2(gx + col * (SLOT + GAP), 34 + row * (SLOT + GAP), SLOT, SLOT)
		_bevel_box(r, SLOT_BG, INK, FRAME_DARK)
		var s: Dictionary = inv.slots[i]
		if s.is_empty():
			continue
		_draw_item_icon(r, s.id)
		if s.count > 1:
			var t := str(s.count)
			var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			_text(r.position + Vector2(SLOT - w - 1, SLOT - 2) + Vector2(1, 1), t, INK)
			_text(r.position + Vector2(SLOT - w - 1, SLOT - 2), t, TEXT)
	# Item name list under the grid.
	var ly := 34 + ((inv.slots.size() + COLS - 1) / COLS) * (SLOT + GAP) + 14.0
	var names: Dictionary = {}
	for s in inv.slots:
		if not s.is_empty():
			names[s.id] = int(names.get(s.id, 0)) + s.count
	if names.is_empty():
		_text(Vector2(gx, ly), "Empty", DIM)
	else:
		for id in names:
			_text(Vector2(gx, ly), "%s x%d" % [ItemCatalog.item_name(id), names[id]], TEXT)
			ly += 13.0
			if ly > SIZE.y - 24:
				break

	# --- Crafting (right).
	var cx := 160.0
	draw_rect(Rect2(cx - 8, 12, 1, SIZE.y - 38), FRAME_DARK)
	_text(Vector2(cx, 24), "CRAFTING", GOLD)
	var stations := player.nearby_stations()
	var near := "Near: " + (", ".join(stations) if not stations.is_empty() else "nothing")
	var nw := _font.get_string_size(near, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_text(Vector2(SIZE.x - 14 - nw, 24), near, DIM)
	draw_rect(Rect2(cx, 28, SIZE.x - cx - 14, 1), FRAME_LIGHT)
	for i in ItemCatalog.RECIPES.size():
		var rec: Dictionary = ItemCatalog.RECIPES[i]
		var y := 34.0 + i * 18.0
		var ok := Crafting.can_craft(inv, rec, stations)
		var row_r := Rect2(cx, y, SIZE.x - cx - 14, 17)
		_bevel_box(row_r, Color8(64, 50, 42) if ok else SLOT_BG, INK, FRAME_DARK)
		_draw_item_icon(Rect2(cx + 1, y + 1, 15, 15), rec.id)
		_text(Vector2(cx + 20, y + 13), "%d" % ((i + 1) % 10), GOLD if ok else DIM)
		var label := ItemCatalog.item_name(rec.id)
		if rec.out > 1:
			label += " x%d" % rec.out
		_text(Vector2(cx + 32, y + 13), label, TEXT if ok else DIM)
		var cx_end := row_r.end.x - 4
		for k in rec["in"].keys():
			var amount := "%d" % rec["in"][k]
			var aw := _font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			_text(Vector2(cx_end - aw, y + 13), amount, OK if ok else DIM)
			var ir := Rect2(cx_end - aw - 9, y + 5, 8, 8)
			var icol: Color = ItemCatalog.ITEMS[k].color
			draw_rect(ir, icol)
			draw_rect(ir, INK, false)
			cx_end -= aw + 14
		if rec.station != "":
			var tag := "bench" if rec.station == "workbench" else "fire"
			var tw := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			_text(Vector2(cx_end - tw - 2, y + 13), tag, GOLD if ok else DIM)

	_text(Vector2(14, SIZE.y - 11), "[I] close   [1-0] craft", DIM)
