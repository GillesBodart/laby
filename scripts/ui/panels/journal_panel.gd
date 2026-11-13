extends Control
## Field journal (J): everything the survivors have learned, in four tabs:
## creatures met, resources gathered, glyphs decoded and places found
## (landmarks, sectors, maze shifts). Reads GameState.journal.
## Drawn in 480x270 UI space. Tabs: click, 1-4 or A/D; scroll: wheel or W/S.

const SIZE := Vector2(480, 270)
const INK := UiPalette.INK
const BG := Color(0.03, 0.05, 0.08, 0.92)
const PAGE := UiPalette.PAGE
const PAGE_DARK := UiPalette.PAGE_DARK
const GOLD := UiPalette.GOLD
const TEXT_DARK := UiPalette.TEXT_DARK
const TEXT_MID := UiPalette.TEXT_MID
const TEXT_LIGHT := UiPalette.TEXT_LIGHT
## The page, inside the shared parchment frame (FRAME); tabs stand on its top.
const BOOK := Rect2(20, 45, 440, 202)
const FRAME := Rect2(15, 40, 450, 212)
const TABS := ["creatures", "resources", "glyphs", "places"]
const TAB_NAMES := ["Creatures", "Resources", "Glyphs", "Places"]
const ROW_H := 26.0
## Creature rows are taller: their lore line may wrap.
const CREATURE_ROW_H := 40.0
const TEMPER_LABEL := {"passive": "timid", "neutral": "fights back", "hostile": "hostile", "nocturnal": "hostile at night"}

var tab := 0
var _scroll := 0
var _font: Font
var _tex_cache := {}


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_scroll = clampi(_scroll + by, 0, maxi(entries().size() - _rows_visible(), 0))
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## Row height, grown with the text size (up to the body cap).
func _row_h() -> float:
	return (CREATURE_ROW_H if TABS[tab] == "creatures" else ROW_H) * _k()


## Layout scale of the page text.
func _k() -> float:
	return minf(Accessibility.text_scale(), UiFrame.BODY_CAP)


func _rows_visible() -> int:
	return int((BOOK.size.y - 2.0) / _row_h())


func _tab_rect(i: int) -> Rect2:
	return Rect2(BOOK.position.x + 8 + i * 84, FRAME.position.y - 15, 80, 17)


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
				var area := "Clearing" if d.biome == "forest" else Sectors.display_name(d.biome)
				out.append({"icon": EnemyCatalog.sprite_path(id), "title": d.name,
					"sub": "%s · %s" % [area, TEMPER_LABEL.get(d.temper, d.temper)],
					"stats": "Defeated %d · Tame %s · HP %d" % [int(j[id]), "-" if tier < 0 else str(tier), int(d.hp)],
					"text": d.lore})
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
						"sub": "decoded" if read else ("unread" if Glyphs.required_lore(id) == 0 else "needs glyph insight %d" % Glyphs.required_lore(id)),
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
				out.append({"icon": "", "title": "The walls move", "sub": "1 shift witnessed" if nights == 1 else "%d shifts witnessed" % nights,
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
			return Sectors.ORDER.size() + LabyrinthGenerator.all_landmark_types().size()
	return 0


func _tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


func _text(pos: Vector2, s: String, col: Color, fsize := 12, width := -1.0) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, UiFrame.fs(fsize), col)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), BG)
	UiFrame.title_plate(self, SIZE.x / 2.0, 2, "JOURNAL", 140)
	UiFrame.box(self, FRAME, true)
	var tab_size := mini(UiFrame.fs(11), 13)
	for i in TABS.size():
		var r := _tab_rect(i)
		var active := i == tab
		UiFrame.plate(self, r, PAGE if active else PAGE_DARK, UiPalette.BRASS_DARK, 3)
		if active:
			# Open at the bottom: the tab runs into the page.
			draw_rect(Rect2(r.position.x + 1, r.end.y - 3, r.size.x - 2, BOOK.position.y - r.end.y + 4), PAGE)
		var label := "%d %s" % [i + 1, TAB_NAMES[i]]
		draw_string(_font, r.position + Vector2(6, 12), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, tab_size, TEXT_DARK if active else TEXT_MID.darkened(0.25))
	var rows := entries()
	if rows.is_empty():
		_text(BOOK.position + Vector2(16, 30), "Nothing recorded yet. Explore, gather, fight, read the walls.", TEXT_MID, 12, BOOK.size.x - 24)
	var k := _k()
	var row_h := _row_h()
	var visible_rows := _rows_visible()
	var title_size := UiFrame.fs(12)
	var small := UiFrame.fs(10)
	for n in mini(visible_rows, rows.size() - _scroll):
		var e: Dictionary = rows[_scroll + n]
		var y := BOOK.position.y + 1 + n * row_h
		if n % 2 == 1:
			draw_rect(Rect2(BOOK.position.x + 2, y, BOOK.size.x - 4, row_h), PAGE_DARK.lerp(PAGE, 0.5))
		var tex := _tex(e.icon)
		if tex:
			var s := 22.0 / maxf(tex.get_width(), tex.get_height())
			var sz := Vector2(tex.get_size()) * s
			draw_texture_rect(tex, Rect2(Vector2(BOOK.position.x + 17, y + 13 * k) - sz / 2.0, sz), false)
		draw_string(_font, Vector2(BOOK.position.x + 34, y + 11 * k), e.title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, TEXT_DARK)
		var tw2 := _font.get_string_size(e.title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
		draw_string(_font, Vector2(BOOK.position.x + 40 + tw2, y + 11 * k), e.sub, HORIZONTAL_ALIGNMENT_LEFT, -1, small, TEXT_MID)
		if e.has("stats"):
			draw_string(_font, Vector2(BOOK.position.x + 34, y + 11 * k), e.stats, HORIZONTAL_ALIGNMENT_RIGHT, BOOK.size.x - 42, small, TEXT_MID)
			draw_multiline_string(_font, Vector2(BOOK.position.x + 34, y + 23 * k), e.text, HORIZONTAL_ALIGNMENT_LEFT,
				BOOK.size.x - 40, small, 2, TEXT_DARK)
		else:
			draw_string(_font, Vector2(BOOK.position.x + 34, y + 23 * k), e.text, HORIZONTAL_ALIGNMENT_LEFT, BOOK.size.x - 40, small, TEXT_MID)
	var total := _total()
	var count := rows.size()
	if TABS[tab] == "glyphs":
		count = GameState.journal.get("glyphs", {}).size()
	elif TABS[tab] == "places":
		count = GameState.journal.get("places", {}).size() + Sectors.ORDER.filter(func(s): return GameState.reached.has(s)).size()
	# Count and scroll range sit at the right end of the tab row.
	var status := "%d recorded" % count if total == 0 else "%d / %d" % [count, total]
	if rows.size() > visible_rows:
		status = "%d-%d   %s" % [_scroll + 1, mini(_scroll + visible_rows, rows.size()), status]
	var ss := mini(UiFrame.fs(11), 13)
	draw_string(_font, Vector2(_tab_rect(TABS.size() - 1).end.x + 4, FRAME.position.y - 4), status, HORIZONTAL_ALIGNMENT_RIGHT, FRAME.end.x - 6 - _tab_rect(TABS.size() - 1).end.x - 4, ss, GOLD)
	UiFrame.footer(self, "[{journal}] close  [1-4] / [A][D] tabs  [Wheel] / [W][S] scroll")
