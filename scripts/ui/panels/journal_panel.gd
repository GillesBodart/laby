extends Control
## Field journal (J): everything the survivors have learned, in four tabs:
## creatures met, resources gathered, glyphs decoded and places found
## (landmarks, sectors, maze shifts). Reads GameState.journal.
## Drawn in 480x270 UI space. Tabs: click, 1-4 or A/D; scroll: wheel or W/S.

const SIZE := Vector2(480, 270)
const INK := Color8(27, 20, 16)
const BG := Color(0.03, 0.05, 0.08, 0.92)
const PAGE := Color8(236, 222, 186)
const PAGE_DARK := Color8(214, 196, 152)
const GOLD := Color8(242, 210, 92)
const TEXT_DARK := Color8(58, 42, 30)
const TEXT_MID := Color8(110, 84, 60)
const TEXT_LIGHT := Color8(238, 226, 196)
const BOOK := Rect2(20, 34, 440, 216)
const TABS := ["creatures", "resources", "glyphs", "places"]
const TAB_NAMES := ["Creatures", "Resources", "Glyphs", "Places"]
const ROW_H := 26.0
const ROWS_VISIBLE := 8

var tab := 0
var _scroll := 0
var _font: Font
var _tex_cache := {}


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2.ZERO
	size = SIZE
	_font = ThemeDB.get_project_theme().default_font


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		if visible:
			visible = false
		else:
			for p in get_tree().get_nodes_in_group("ui_panels"):
				if p != self:
					p.visible = false
			visible = true
			_scroll = 0
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				visible = false
			KEY_1, KEY_2, KEY_3, KEY_4:
				set_tab(event.physical_keycode - KEY_1)
			KEY_A, KEY_LEFT:
				set_tab(posmod(tab - 1, TABS.size()))
			KEY_D, KEY_RIGHT:
				set_tab((tab + 1) % TABS.size())
			KEY_W, KEY_UP:
				scroll(-1)
			KEY_S, KEY_DOWN:
				scroll(1)
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				scroll(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				scroll(1)
			MOUSE_BUTTON_LEFT:
				var m := get_local_mouse_position()
				for i in TABS.size():
					if _tab_rect(i).has_point(m):
						set_tab(i)
		get_viewport().set_input_as_handled()


func set_tab(i: int) -> void:
	tab = clampi(i, 0, TABS.size() - 1)
	_scroll = 0
	queue_redraw()


func scroll(by: int) -> void:
	_scroll = clampi(_scroll + by, 0, maxi(entries().size() - ROWS_VISIBLE, 0))
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _tab_rect(i: int) -> Rect2:
	return Rect2(BOOK.position.x + 8 + i * 84, BOOK.position.y - 16, 80, 16)


## Rows of the current tab: [{icon, title, sub, text}], undiscovered ones hidden.
func entries() -> Array:
	var out := []
	var j: Dictionary = GameState.journal.get(TABS[tab], {})
	match TABS[tab]:
		"creatures":
			var ids := j.keys()
			ids.sort_custom(func(a, b): return _creature_order(a) < _creature_order(b))
			for id in ids:
				if not EnemyCatalog.has(id):
					continue
				var d := EnemyCatalog.def(id)
				var tier := Taming.tier(id)
				out.append({"icon": EnemyCatalog.sprite_path(id), "title": d.name,
					"sub": "%s  %s  %s" % [String(d.biome).capitalize(), d.temper, d.attack],
					"text": "Defeated %d   Tame tier %s   HP %d" % [int(j[id]), "-" if tier < 0 else str(tier), int(d.hp)]})
		"resources":
			var ids := j.keys()
			ids.sort_custom(func(a, b): return ItemCatalog.sorts_before(a, b))
			for id in ids:
				if not ItemCatalog.ITEMS.has(id):
					continue
				out.append({"icon": "res://assets/ui/icons/items/%s.png" % id, "title": ItemCatalog.item_name(id),
					"sub": ItemCatalog.category_name(id), "text": "Gathered %d times. %s" % [int(j[id]), ItemCatalog.description(id)]})
		"glyphs":
			for s in Sectors.ORDER:
				if not GameState.reached.has(s):
					continue
				for i in LabyrinthGenerator.GLYPH_COUNT:
					var id := "%s_%d" % [s, i]
					var read := j.has(id)
					out.append({"icon": "res://assets/sprites/environment/landmarks/glyph_stone%s.png" % ("_read" if read else ""),
						"title": "%s, stone %d" % [Sectors.display_name(s), i + 1],
						"sub": "decoded" if read else "unread (insight %d)" % Glyphs.required_lore(id),
						"text": Glyphs.text(id) if read else "Somewhere in this sector..."})
		"places":
			for s in Sectors.ORDER:
				if GameState.reached.has(s):
					out.append({"icon": "", "title": Sectors.display_name(s), "sub": "sector",
						"text": "Reached. Guardian %s." % ("slain" if GameState.bosses_defeated.has(Sectors.info(s).boss) else "alive")})
			for id in j:
				out.append({"icon": "res://assets/sprites/environment/landmarks/landmark_%s.png" % id, "title": Glyphs.landmark_name(id),
					"sub": "landmark", "text": Glyphs.landmark_text(id)})
			var nights := maxi(TimeSystem.clock.night_index(), 0)
			if nights > 0:
				out.append({"icon": "", "title": "The walls move", "sub": "%d shift%s witnessed" % [nights, "s" if nights > 1 else ""],
					"text": "Each nightfall some passages close and others open. Old maps grow unreliable."})
	return out


func _creature_order(id: String) -> String:
	var biomes := ["forest", "labyrinth", "overgrowth", "desert", "ice", "volcano", "hell"]
	return "%d%s" % [biomes.find(String(EnemyCatalog.def(id).biome)), EnemyCatalog.def(id).name]


func _total() -> int:
	match TABS[tab]:
		"creatures":
			return EnemyCatalog.TYPES.size()
		"glyphs":
			return Sectors.ORDER.size() * LabyrinthGenerator.GLYPH_COUNT
		"places":
			return Sectors.ORDER.size() + LabyrinthGenerator.LANDMARK_TYPES.size()
	return 0


func _tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


func _text(pos: Vector2, s: String, col: Color, fsize := 12, width := -1.0) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, fsize, col)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), BG)
	draw_rect(Rect2(170, 2, 140, 18), PAGE)
	draw_rect(Rect2(170, 2, 140, 18), INK, false)
	var tw := _font.get_string_size("JOURNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_text(Vector2(240 - tw / 2.0, 16), "JOURNAL", TEXT_DARK, 14)
	for i in TABS.size():
		var r := _tab_rect(i)
		draw_rect(r, PAGE if i == tab else PAGE_DARK.darkened(0.25))
		draw_rect(r, INK, false)
		var label := "%d %s" % [i + 1, TAB_NAMES[i]]
		_text(r.position + Vector2(6, 12), label, TEXT_DARK if i == tab else TEXT_MID, 11)
	draw_rect(BOOK, PAGE)
	draw_rect(BOOK, INK, false, 2.0)
	draw_line(BOOK.position + Vector2(0, 2), BOOK.position + Vector2(BOOK.size.x, 2), GOLD, 1.0)
	var rows := entries()
	if rows.is_empty():
		_text(BOOK.position + Vector2(16, 30), "Nothing recorded yet. Explore, gather, fight, read the walls.", TEXT_MID, 12)
	for k in mini(ROWS_VISIBLE, rows.size() - _scroll):
		var e: Dictionary = rows[_scroll + k]
		var y := BOOK.position.y + 4 + k * ROW_H
		if k % 2 == 1:
			draw_rect(Rect2(BOOK.position.x + 2, y, BOOK.size.x - 4, ROW_H), PAGE_DARK.lerp(PAGE, 0.5))
		var tex := _tex(e.icon)
		if tex:
			var s := 22.0 / maxf(tex.get_width(), tex.get_height())
			var sz := Vector2(tex.get_size()) * s
			draw_texture_rect(tex, Rect2(Vector2(BOOK.position.x + 17, y + 13) - sz / 2.0, sz), false)
		_text(Vector2(BOOK.position.x + 34, y + 11), e.title, TEXT_DARK, 12)
		var tw2 := _font.get_string_size(e.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_text(Vector2(BOOK.position.x + 40 + tw2, y + 11), e.sub, TEXT_MID, 10)
		_text(Vector2(BOOK.position.x + 34, y + 23), e.text, TEXT_MID, 10, BOOK.size.x - 40)
	var total := _total()
	var count := rows.size()
	if TABS[tab] == "glyphs":
		count = GameState.journal.get("glyphs", {}).size()
	elif TABS[tab] == "places":
		count = GameState.journal.get("places", {}).size() + Sectors.ORDER.filter(func(s): return GameState.reached.has(s)).size()
	var status := "%d recorded" % count if total == 0 else "%d / %d" % [count, total]
	_text(Vector2(BOOK.end.x - 70, BOOK.end.y + 14), status, GOLD, 11)
	if rows.size() > ROWS_VISIBLE:
		_text(Vector2(BOOK.end.x - 160, BOOK.end.y + 14), "%d-%d" % [_scroll + 1, mini(_scroll + ROWS_VISIBLE, rows.size())], TEXT_LIGHT, 11)
	_text(Vector2(8, SIZE.y - 6), "J: close    1-4 / A D: tabs    wheel / W S: scroll", Color8(160, 150, 130), 11)
