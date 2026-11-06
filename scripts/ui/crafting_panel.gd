extends PanelContainer
## Backpack / crafting screen (I). Two tabs (Tab key or click): the backpack with a
## paper doll of worn gear (click to equip / unequip) and an item note card, and a
## recipe book (click a recipe to craft, wheel to scroll). Opened with I the book
## holds hand recipes; E on a station (workbench, anvil...) opens that station's book.

const SIZE := Vector2(480, 270)
const COLS := 5
const PITCH := Vector2(40, 29)
const DIAMOND := 15
## Paper doll: equipment slot centres (24x24 boxes) and the ghost icon shown when empty.
const DOLL := {
	"head": Vector2(104, 62), "amulet": Vector2(134, 74), "weapon": Vector2(74, 104),
	"body": Vector2(104, 104), "ring": Vector2(134, 104), "feet": Vector2(104, 146),
	"offhand": Vector2(134, 134),
}
const GHOST := {
	"head": "leather_cap", "amulet": "bone_charm", "weapon": "stone_sword",
	"body": "leather_armor", "ring": "copper_ring", "feet": "leather_boots", "offhand": "wooden_shield",
}
const EQUIP_SLOT := Vector2(24, 24)
const PANEL := Rect2(44, 36, 320, 196)
const CARD := Rect2(372, 56, 100, 150)
## Recipe book: a scrollable grid of recipe slots; click one to craft it.
const GRID_COLS := 7
const GRID_ROWS := 4
const SLOT := Vector2(40, 36)
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
var _hover_slot := ""
var _scroll := 0
## Recipe-book category filter ("" = all categories, each starting on a new row).
var _cat := ""
var _hover_chip := -2
var _hover_sort := false
## Station whose recipe book is shown ("" = handcraft).
var station := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--tab=1":
			tab = 1
	EventBus.station_used.connect(_on_station_used)
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
	_hover_slot = _hover_equip(get_local_mouse_position()) if tab == 0 else ""
	_hover_chip = _hover_chip_index(get_local_mouse_position()) if tab == 1 else -2
	_hover_sort = tab == 0 and SORT_BUTTON.has_point(get_local_mouse_position())
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		for p in get_tree().get_nodes_in_group("ui_panels"):
			if p != self:
				p.visible = false
		visible = not visible
		if visible:
			station = ""
			_scroll = 0
			_cat = ""
		get_viewport().set_input_as_handled()
	elif not visible:
		return
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			visible = false
		elif event.physical_keycode == KEY_TAB:
			tab = (tab + 1) % TABS.size()
		elif event.physical_keycode == KEY_DOWN and tab == 1:
			_scroll_by(1)
		elif event.physical_keycode == KEY_UP and tab == 1:
			_scroll_by(-1)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if tab == 1:
			_scroll_by(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_local_mouse_position()
		for i in TABS.size():
			if _tab_rect(i).has_point(m):
				tab = i
				return
		if tab == 1 and _hover_chip > -2:
			_cat = "" if _hover_chip < 0 else _categories()[_hover_chip]
			_scroll = 0
		elif tab == 0 and _hover_sort:
			sort_backpack()
		elif tab == 1 and _hover >= 0:
			craft(_hover)
		elif tab == 0 and _hover_slot != "":
			unequip(_hover_slot)
		elif tab == 0 and _hover >= 0:
			equip_slot(_hover)


func _on_station_used(group: String) -> void:
	if group == "":
		visible = false
		return
	for p in get_tree().get_nodes_in_group("ui_panels"):
		if p != self:
			p.visible = false
	station = group
	tab = 1
	_scroll = 0
	_cat = ""
	visible = true


## Grid cells of the book for the current station and filter: recipe indices, with
## -1 padding so each category starts on a fresh row.
func _book() -> Array:
	var out := []
	var last := ""
	var known := _known()
	for i in ItemCatalog.recipes_at(station):
		if not ItemCatalog.recipe_known(i, known):
			continue
		var cat := ItemCatalog.category_of(ItemCatalog.RECIPES[i].id)
		if _cat != "" and cat != _cat:
			continue
		if last != "" and cat != last:
			while out.size() % GRID_COLS != 0:
				out.append(-1)
		last = cat
		out.append(i)
	return out


## Categories present in the current station's book, in display order.
func _categories() -> Array:
	var out := []
	var known := _known()
	for i in ItemCatalog.recipes_at(station):
		if not ItemCatalog.recipe_known(i, known):
			continue
		var cat := ItemCatalog.category_of(ItemCatalog.RECIPES[i].id)
		if cat not in out:
			out.append(cat)
	return out


## First recipe output of a category in the book (used as the chip icon).
func _category_icon(cat: String) -> String:
	var known := _known()
	for i in ItemCatalog.recipes_at(station):
		if ItemCatalog.recipe_known(i, known) and ItemCatalog.category_of(ItemCatalog.RECIPES[i].id) == cat:
			return ItemCatalog.RECIPES[i].id
	return ""


## Items the local player has discovered (recipes unlock from these).
func _known() -> Dictionary:
	var player := _player()
	return player.inventory.known if player != null else {}


func sort_backpack() -> void:
	var player := _player()
	if player != null:
		player.inventory.sort(player.survival.insured_slots())
		EventBus.notify.emit("Backpack sorted")


func _scroll_by(d: int) -> void:
	var rows := ceili(_book().size() / float(GRID_COLS))
	_scroll = clampi(_scroll + d, 0, maxi(rows - GRID_ROWS, 0))


func craft(index: int) -> bool:
	var player := _player()
	if player == null:
		return false
	var recipe: Dictionary = ItemCatalog.RECIPES[index]
	var ok := Crafting.craft(player.inventory, recipe, player.nearby_stations())
	var item := ItemCatalog.item_name(recipe.id)
	EventBus.notify.emit(("Crafted %s" % item) if ok else ("Cannot craft %s" % item))
	# Fresh gear goes straight on when its slot is free.
	var slot := ItemCatalog.slot_of(recipe.id)
	if ok and slot != "" and player.equipment.get_item(slot) == "":
		player.equipment.equip(player.inventory, recipe.id)
	return ok


## Puts on the item in a backpack slot (swapping out what was worn).
func equip_slot(index: int) -> bool:
	var player := _player()
	if player == null:
		return false
	var s: Dictionary = player.inventory.slots[index]
	if not s.is_empty() and ItemCatalog.slot_of(s.id) == "" and ItemCatalog.is_consumable(s.id):
		return player.use_item(s.id)
	if s.is_empty() or ItemCatalog.slot_of(s.id) == "":
		return false
	var ok := player.equipment.equip(player.inventory, s.id)
	if ok:
		EventBus.notify.emit("Equipped %s" % ItemCatalog.item_name(s.id))
	return ok


func unequip(slot: String) -> bool:
	var player := _player()
	if player == null or player.equipment.get_item(slot) == "":
		return false
	var id := player.equipment.get_item(slot)
	var ok := player.equipment.unequip(player.inventory, slot)
	EventBus.notify.emit(("Took off %s" % ItemCatalog.item_name(id)) if ok else "Backpack full!")
	return ok

# ------------------------------------------------------------- layout

func _tab_rect(i: int) -> Rect2:
	return Rect2(14, 60 + i * 30, 24, 24)


func _slot_center(i: int) -> Vector2:
	var origin := Vector2(180, 60)
	return origin + Vector2((i % COLS) * PITCH.x, (i / COLS) * PITCH.y)


func _recipe_rect(pos: int) -> Rect2:
	var slot := pos - _scroll * GRID_COLS
	var origin := PANEL.position + Vector2((PANEL.size.x - GRID_COLS * SLOT.x) / 2.0, 30)
	return Rect2(origin + Vector2((slot % GRID_COLS) * SLOT.x, (slot / GRID_COLS) * SLOT.y), SLOT - Vector2(2, 2))


func _visible_recipes() -> Array:
	var first := _scroll * GRID_COLS
	var last := mini(first + GRID_COLS * GRID_ROWS, _book().size())
	return range(first, last)


## Filter chip i (-1 = "all") above the recipe grid.
func _chip_rect(i: int) -> Rect2:
	var n := _categories().size() + 1
	var w := 22.0
	var x0 := PANEL.get_center().x - n * w / 2.0
	return Rect2(x0 + (i + 1) * w, PANEL.position.y + 10, w - 2, 18)


func _hover_chip_index(m: Vector2) -> int:
	for i in range(-1, _categories().size()):
		if _chip_rect(i).has_point(m):
			return i
	return -2


const SORT_BUTTON := Rect2(372, 212, 100, 18)


func _hover_equip(m: Vector2) -> String:
	for slot in DOLL:
		if Rect2(DOLL[slot] - EQUIP_SLOT / 2.0, EQUIP_SLOT).has_point(m):
			return slot
	return ""


func _hover_index(m: Vector2) -> int:
	if tab == 0:
		for i in Inventory.DEFAULT_SLOTS:
			var d := (m - _slot_center(i)).abs()
			if d.x + d.y <= DIAMOND:
				return i
	else:
		var book := _book()
		for pos in _visible_recipes():
			if book[pos] >= 0 and _recipe_rect(pos).has_point(m):
				return book[pos]
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


func _icon(c: Vector2, id: String, half := 6, tint := Color.WHITE) -> void:
	var small := half < 5
	var path := "res://assets/ui/items/%s%s.png" % [id, "_s" if small else ""]
	if ResourceLoader.exists(path):
		var tex := _icon_tex(path)
		var sz := Vector2(tex.get_size()) * 0.5
		draw_set_transform((c - sz * 0.5).round(), 0.0, Vector2(0.5, 0.5))
		draw_texture(tex, Vector2.ZERO, tint)
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
	_text_center(title.get_center().x, 26, TABS[tab] if tab == 0 else String(ItemCatalog.STATIONS[station]).to_upper(), TEXT_DARK)

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
		var worn := _draw_doll(player)
		if worn != "":
			detail_id = worn
			detail_extra = "Click to take off."
		elif detail_id != "" and ItemCatalog.slot_of(detail_id) != "":
			detail_extra = "Click to equip (%s)." % Equipment.SLOT_NAMES[ItemCatalog.slot_of(detail_id)]
		elif detail_id != "" and ItemCatalog.is_consumable(detail_id):
			detail_extra = "Click to use."
		_box(SORT_BUTTON, CREAM if _hover_sort else TAN, GOLD if _hover_sort else BROWN, 3)
		var sw := _font.get_string_size("SORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(_font, Vector2(SORT_BUTTON.get_center().x - sw / 2.0, SORT_BUTTON.end.y - 5), "SORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT_DARK)
	else:
		detail_id = _draw_crafting(player)
		if _hover >= 0:
			var rec: Dictionary = ItemCatalog.RECIPES[_hover]
			detail_extra = _recipe_text(rec, player)
	_draw_card(detail_id, detail_extra)
	_text_center(PANEL.get_center().x, 247, "[I] close  [Tab] switch  [Click] equip / craft  [E] station", TEXT_LIGHT)


func _draw_backpack(player: Player) -> String:
	var inv := player.inventory
	var hovered := ""
	for i in inv.slots.size():
		var c := _slot_center(i)
		var s: Dictionary = inv.slots[i]
		var selected := i == _hover
		var insured := i < player.survival.insured_slots()
		_diamond(c, DIAMOND, CREAM, GOLD if selected else (OK if insured else BROWN))
		_diamond(c, DIAMOND - 3, Color8(240, 200, 140) if selected else (Color8(196, 214, 150) if insured else TAN), BROWN)
		if insured:
			_padlock(c + Vector2(-11, -12))
		if s.is_empty():
			continue
		_icon(c + Vector2(0, -1), s.id)
		if selected:
			hovered = s.id
		if s.count > 1:
			var t := "%d" % s.count
			var p := c + Vector2(13 - _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, 13)
			draw_string(_font, p + Vector2(1, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
			draw_string(_font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT_LIGHT)
	return hovered


## Tiny padlock marking an insured slot (kept on death).
func _padlock(p: Vector2) -> void:
	draw_arc(p + Vector2(3, 2), 2.0, PI, TAU, 6, INK, 1.5)
	draw_rect(Rect2(p + Vector2(0, 2), Vector2(6, 5)), INK)
	draw_rect(Rect2(p + Vector2(1, 3), Vector2(4, 3)), GOLD)


## Paper doll of worn gear plus the resulting stats. Returns the hovered worn item id.
func _draw_doll(player: Player) -> String:
	var eq := player.equipment
	# Faint survivor silhouette behind the slots.
	var ghost := Color(GREEN_LINE, 0.35)
	draw_circle(Vector2(104, 64), 13.0, ghost)
	draw_colored_polygon(PackedVector2Array([Vector2(86, 82), Vector2(122, 82), Vector2(126, 124), Vector2(82, 124)]), ghost)
	draw_rect(Rect2(88, 124, 10, 22), ghost)
	draw_rect(Rect2(110, 124, 10, 22), ghost)
	draw_line(Vector2(84, 86), Vector2(74, 104), ghost, 5.0)
	draw_line(Vector2(124, 86), Vector2(134, 104), ghost, 5.0)
	var hovered := ""
	for slot in DOLL:
		var r := Rect2(DOLL[slot] - EQUIP_SLOT / 2.0, EQUIP_SLOT)
		var id := eq.get_item(slot)
		var hot: bool = slot == _hover_slot
		_box(r, CREAM if id != "" else TAN, GOLD if hot else BROWN, 3)
		if id != "":
			_icon(r.get_center(), id)
			if hot:
				hovered = id
		else:
			_icon(r.get_center(), GHOST[slot], 6, Color(0.35, 0.25, 0.15, 0.35))
	var lines := [
		"ATK %d" % player.weapon_damage(),
		"DEF %d" % player.armor(),
		"HP %d" % int(player.survival.max_health()),
		"BLK %d%%" % player.block_chance(),
		"STR %d (%d safe)" % [player.survival.strength(), player.survival.insured_slots()],
	]
	for i in lines.size():
		draw_string(_font, Vector2(62, 174 + i * 12), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT_LIGHT)
	return hovered


func _draw_crafting(player: Player) -> String:
	var inv := player.inventory
	var stations := player.nearby_stations()
	var book := _book()
	for pos in _visible_recipes():
		var i: int = book[pos]
		if i < 0:
			continue
		var rec: Dictionary = ItemCatalog.RECIPES[i]
		var ok := Crafting.can_craft(inv, rec, stations)
		var r := _recipe_rect(pos)
		_box(r, CREAM if ok else TAN, GOLD if i == _hover else BROWN, 3)
		_icon(r.get_center() + Vector2(0, -1), rec.id, 7)
		if rec.out > 1:
			var t := "%d" % rec.out
			var p := r.end - Vector2(_font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 2, 2)
			_text(p + Vector2(1, 1), t, INK)
			_text(p, t, TEXT_LIGHT)
		if not ok:
			draw_rect(r.grow(-1), Color(0.35, 0.28, 0.2, 0.45))
	_draw_chips()
	var locked := 0
	for i in ItemCatalog.recipes_at(station):
		if not ItemCatalog.recipe_known(i, player.inventory.known):
			locked += 1
	if book.is_empty():
		var msg := "No recipes yet: gather new materials to discover some."
		var mw := _font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(_font, Vector2(PANEL.get_center().x - mw / 2.0, PANEL.get_center().y), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT_LIGHT)
	if locked > 0:
		var lt := "%d undiscovered" % locked
		var lw := _font.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(_font, Vector2(PANEL.end.x - lw - 14, PANEL.end.y - 10), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT_LIGHT)
	if station == "":
		var hint := "E at a campfire, workbench, furnace, anvil... for more."
		var w := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(_font, Vector2(PANEL.get_center().x - w / 2.0, PANEL.end.y - 14), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT_LIGHT)
	elif station not in stations:
		var warn := "Too far from the %s!" % ItemCatalog.STATIONS[station]
		var w := _font.get_string_size(warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(_font, Vector2(PANEL.get_center().x - w / 2.0, PANEL.end.y - 14), warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD)
	return ItemCatalog.RECIPES[_hover].id if _hover >= 0 else ""


## Category filter chips: "all" (a grid glyph) then one icon per category.
func _draw_chips() -> void:
	var cats := _categories()
	for i in range(-1, cats.size()):
		var r := _chip_rect(i)
		var on: bool = _cat == ("" if i < 0 else cats[i])
		var hot := i == _hover_chip
		_box(r, CREAM if on else TAN, GOLD if on or hot else BROWN, 3)
		if i < 0:
			for k in 4:
				draw_rect(Rect2(r.get_center() + Vector2(-5 + (k % 2) * 6, -5 + (k / 2) * 6), Vector2(4, 4)), BROWN)
		else:
			_icon(r.get_center(), _category_icon(cats[i]), 6, Color.WHITE if on or hot else Color(1, 1, 1, 0.7))
	if _hover_chip > -2:
		var label := "All" if _hover_chip < 0 else String(ItemCatalog.CATEGORY_NAMES[cats[_hover_chip]])
		var r := _chip_rect(_hover_chip)
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var tip := Rect2(r.get_center().x - w / 2.0 - 4, r.end.y + 2, w + 8, 13)
		_box(tip, CREAM, BROWN, 2)
		draw_string(_font, Vector2(tip.position.x + 4, tip.end.y - 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT_DARK)


## Ingredient lines (have/need) plus the required station.
func _recipe_text(rec: Dictionary, player: Player) -> String:
	var lines := PackedStringArray()
	for k in rec["in"]:
		lines.append("%s %d/%d" % [ItemCatalog.item_name(k), player.inventory.count(k), rec["in"][k]])
	lines.append("At %s" % ItemCatalog.STATIONS[rec.station] if rec.station != "" else "By hand")
	return "\n".join(lines)


func _draw_card(id: String, extra: String) -> void:
	_box(CARD, CREAM, BROWN, 2)
	var ly := CARD.position.y + 44
	while ly < CARD.end.y - 6:
		draw_rect(Rect2(CARD.position.x + 6, ly, CARD.size.x - 12, 1), TAN)
		ly += 12
	if id == "":
		draw_multiline_string(_font, CARD.position + Vector2(8, 22), "Hover an item\nfor details.", HORIZONTAL_ALIGNMENT_LEFT, CARD.size.x - 16, 10, -1, FADED)
		return
	var nm := ItemCatalog.item_name(id)
	var nw := _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(_font, Vector2(CARD.get_center().x - nw / 2.0, CARD.position.y + 16), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT_DARK)
	draw_rect(Rect2(CARD.position.x + 8, CARD.position.y + 21, CARD.size.x - 16, 1), BROWN)
	var cat := ItemCatalog.category_name(id).to_upper()
	var cw := _font.get_string_size(cat, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(_font, Vector2(CARD.get_center().x - cw / 2.0, CARD.position.y + 31), cat, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, FADED)
	var body := ItemCatalog.description(id)
	if extra != "":
		body += "\n" + extra
	draw_multiline_string(_font, CARD.position + Vector2(8, 44), body, HORIZONTAL_ALIGNMENT_LEFT, CARD.size.x - 16, 10, -1, TEXT_DARK)
