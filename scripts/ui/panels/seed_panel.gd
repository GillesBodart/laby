extends Control
## Seed picker: opens when E is pressed on an empty farm plot. Lists every crop
## (seeds you carry first); click one or press its number key to sow it.
## Crops whose seed you have never found show as "?".

const PANEL := Rect2(90, 34, 300, 196)
const ROW := Vector2(140, 18)
const COLS := 2

const INK := UiPalette.INK
const CREAM := UiPalette.CREAM
const TAN := UiPalette.TAN
const BROWN := UiPalette.BROWN
const TEXT_DARK := UiPalette.TEXT_DARK
const FADED := UiPalette.FADED
const GOLD := UiPalette.GOLD
const TEXT_LIGHT := UiPalette.TEXT_LIGHT
## Largest side of a crop icon in its row.
const ICON_BOX := 13.0

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
	UiFrame.plate(self, r, fill, border, radius)


func _text(pos: Vector2, s: String, col: Color, fs := 16) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFrame.fs(fs), col)


func _text_w(s: String, fs: int) -> float:
	return _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFrame.fs(fs)).x


## One text size for every row's name and info: the largest (11 down to 8,
## text-size scaled) at which all the shown crop names fit their slot.
func _name_size(list: Array, player: Player) -> int:
	var size := UiFrame.fs(11)
	while size > 8:
		var fits := true
		for i in list.size():
			var def: Dictionary = Farming.CROPS[list[i]]
			if not player.inventory.knows(def.seed):
				continue
			var info := "x%d  %dm" % [player.inventory.count(def.seed), ceili(def.minutes / 120.0)]
			if _font.get_string_size(ItemCatalog.item_name(def.yield), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > ROW.x - 29 - _font.get_string_size(info, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x - 8:
				fits = false
				break
		if fits:
			break
		size -= 1
	return size


## Item icon whose visible (opaque) part is fitted, aspect kept, into an
## ICON_BOX square centred on `c`, so tightly cropped art is not oversized.
func _icon(c: Vector2, id: String, tint := Color.WHITE) -> void:
	var path := "res://assets/ui/icons/items/%s.png" % id
	if not ResourceLoader.exists(path):
		draw_rect(Rect2(c - Vector2(4, 4), Vector2(8, 8)), ItemCatalog.ITEMS[id].color * tint)
		return
	if not _icons.has(path):
		var loaded: Texture2D = load(path)
		var used := Rect2(0, 0, 1, 1)
		var img := loaded.get_image()
		if img != null and img.get_width() > 0:
			var u := img.get_used_rect()
			if u.has_area():
				used = Rect2(Vector2(u.position) / Vector2(img.get_size()), Vector2(u.size) / Vector2(img.get_size()))
		_icons[path] = [loaded, used]
	var tex: Texture2D = _icons[path][0]
	var used: Rect2 = _icons[path][1]
	var full := Vector2(tex.get_size())
	var k := ICON_BOX / maxf(used.size.x * full.x, used.size.y * full.y)
	var sz := full * k
	var visible_centre := (used.position + used.size / 2.0) * sz
	draw_texture_rect(tex, Rect2((c - visible_centre).round(), sz), false, tint)


func _draw() -> void:
	var player := _player()
	if player == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.SHADE)
	UiFrame.box(self, PANEL)
	UiFrame.title_plate(self, PANEL.get_center().x, PANEL.position.y + 6, "PLANT A SEED")
	var list := entries()
	var name_size := _name_size(list, player)
	var key := 0
	for i in list.size():
		var id: String = list[i]
		var def: Dictionary = Farming.CROPS[id]
		var have := player.inventory.count(def.seed)
		var known := player.inventory.knows(def.seed)
		var r := _row_rect(i)
		_box(r, CREAM if have > 0 else TAN, GOLD if i == _hover and have > 0 else BROWN)
		var col := TEXT_DARK if have > 0 else FADED
		# Number keys sow: only rows you can sow now carry one (they come first).
		if have > 0 and i < 9:
			key = i + 1
			_text(r.position + Vector2(3, 13), "%d" % key, FADED, 10)
		if known:
			_icon(r.position + Vector2(18, 9), def.yield, Color.WHITE if have > 0 else Color(1, 1, 1, 0.5))
			var info := "x%d  %dm" % [have, ceili(def.minutes / 120.0)]
			var w := _font.get_string_size(info, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
			draw_string(_font, Vector2(r.end.x - w - 4, r.position.y + 13), info, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, col)
			draw_string(_font, r.position + Vector2(29, 13), ItemCatalog.item_name(def.yield), HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, col)
		else:
			draw_string(_font, r.position + Vector2(29, 13), "? ? ?", HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, FADED)
	if _hover >= 0 and _hover < list.size():
		var def: Dictionary = Farming.CROPS[list[_hover]]
		var hint := "Find this seed in the wild first."
		if player.inventory.knows(def.seed):
			hint = "%s: %d-%d %s, ripe in %d min, +%d XP" % [ItemCatalog.item_name(def.seed), def.min, def.max, ItemCatalog.item_name(def.yield), ceili(def.minutes / 120.0), def.xp]
		_text(Vector2(PANEL.get_center().x - _text_w(hint, 10) / 2.0, PANEL.end.y - 10), hint, TEXT_LIGHT, 10)
	UiFrame.footer(self, "[{click}] sow  [1-%d] sow by number  [{back}] close" % maxi(key, 1) if key > 0 else "[{back}] close")
