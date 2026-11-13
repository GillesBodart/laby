extends Control
## Settlement overview (talk to a survivor): tier and what the next one
## needs, the camp's needs, and the survivors - click one to change its role.

const PANEL := Rect2(70, 24, 340, 222)
const ROW := Vector2(160, 16)

const INK := UiPalette.INK
const CREAM := UiPalette.CREAM
const BROWN := UiPalette.BROWN
const TEXT_DARK := UiPalette.TEXT_DARK
const FADED := UiPalette.FADED
const GOLD := UiPalette.GOLD
const TEXT_LIGHT := UiPalette.TEXT_LIGHT

var _font: Font
var _hover := -1
var _icons := {}


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.get_project_theme().default_font
	EventBus.survivor_talked.connect(func(_s): open())


func open() -> void:
	for p in get_tree().get_nodes_in_group("ui_panels"):
		if p != self:
			p.visible = false
	visible = true
	queue_redraw()


## Cycles survivor i to the next role.
func cycle_role(i: int) -> void:
	if i < 0 or i >= GameState.survivors.size():
		return
	var s: Dictionary = GameState.survivors[i]
	s.role = Settlement.next_role(s.role)
	EventBus.notify.emit("%s is now the camp's %s." % [Settlement.CAST[int(s.cast)].name, s.role])
	queue_redraw()


func _row_rect(i: int) -> Rect2:
	return Rect2(PANEL.position + Vector2(172, 50 + i * (ROW.y + 2)), ROW)


func _process(_delta: float) -> void:
	if not visible:
		return
	var h := -1
	for i in GameState.survivors.size():
		if _row_rect(i).has_point(get_local_mouse_position()):
			h = i
	if h != _hover:
		_hover = h
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k == KEY_ESCAPE:
			visible = false
		elif k >= KEY_1 and k <= KEY_8:
			cycle_role(k - KEY_1)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover >= 0:
			cycle_role(_hover)
		elif not PANEL.has_point(get_local_mouse_position()):
			visible = false
		get_viewport().set_input_as_handled()


func _box(r: Rect2, fill: Color, border: Color) -> void:
	UiFrame.plate(self, r, fill, border)


## Body text, scaled by the text-size setting; `width` clips it to a column.
func _text(at: Vector2, s: String, sz: int, c: Color, width := -1.0) -> void:
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, width, UiFrame.fs(sz), c)


## Met / unmet colour, darkened to read on the cream plates.
func _state(ok: bool) -> Color:
	return Accessibility.color("good" if ok else "bad").darkened(0.35)


func _npc(sprite: String) -> Texture2D:
	if not _icons.has(sprite):
		_icons[sprite] = load("res://assets/sprites/characters/survivors/%s.png" % sprite)
	return _icons[sprite]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.SHADE)
	UiFrame.box(self, PANEL)
	var tier: int = GameState.settlement_tier
	UiFrame.title_plate(self, PANEL.get_center().x, PANEL.position.y + 6, "THE CLEARING - %s" % Settlement.TIERS[tier].to_upper(), 160)

	# Left column: next tier checklist and needs.
	var left := Rect2(PANEL.position + Vector2(8, 34), Vector2(156, PANEL.size.y - 54))
	_box(left, CREAM, BROWN)
	var lh := float(UiFrame.fs(10)) + 2.0
	var y := left.position.y + 13
	var x := left.position.x + 6
	var cw := left.size.x - 10
	if tier + 1 < Settlement.TIERS.size():
		_text(Vector2(x, y), "Next: %s (room for %d)" % [Settlement.TIERS[tier + 1], Settlement.cap(tier + 1)], 10, TEXT_DARK, cw)
		y += lh + 1
		var need: Dictionary = Settlement.NEEDS[tier + 1]
		for key in need:
			var have: int = Settlement.count(GameState.structures, key) if key != "bosses" else GameState.bosses_defeated.size()
			var ok: bool = have >= int(need[key])
			_text(Vector2(x + 4, y), "%s %s %d/%d" % ["+" if ok else "-", Settlement.NEED_NAMES[key], mini(have, int(need[key])), int(need[key])], 10, _state(ok), cw - 4)
			y += lh
	else:
		_text(Vector2(x, y), "The camp is complete.", 10, _state(true), cw)
		y += lh
	y += 6
	var n := Settlement.needs(GameState.survivors, GameState.structures, GameState.stash)
	_text(Vector2(x, y), "Camp needs (%d/%d people)" % [GameState.survivors.size(), Settlement.cap(tier)], 10, TEXT_DARK, cw)
	y += lh + 1
	var rows := [
		["Food in the Stash (%d / %d a day)" % [Settlement.food_points(GameState.stash), Settlement.food_needed(GameState.survivors) * Settlement.RATION], n.food],
		["Water (a well for 3+)", n.water],
		["Shelter (beds)", n.shelter],
	]
	for r in rows:
		_text(Vector2(x + 4, y), ("+ " if r[1] else "- ") + r[0], 10, _state(r[1]), cw - 4)
		y += lh
	_text(Vector2(x + 4, y), "Defence rating: %d" % n.defence, 10, TEXT_DARK, cw - 4)

	# Right column: survivors.
	_text(PANEL.position + Vector2(172, 44), "Survivors - click to change role", 10, TEXT_LIGHT, 160)
	for i in GameState.survivors.size():
		var s: Dictionary = GameState.survivors[i]
		var c: Dictionary = Settlement.CAST[int(s.cast)]
		var r := _row_rect(i)
		_box(r, CREAM, GOLD if i == _hover else BROWN)
		var tex := _npc(c.sprite)
		if tex:
			# Square crop around the head (the top ~60% of the 48 px figure).
			var side := tex.get_width() * 0.6
			draw_texture_rect_region(tex, Rect2(r.position + Vector2(2, 1), Vector2(14, 14)), Rect2(Vector2(tex.get_width() * 0.2, 0), Vector2(side, side)))
		_text(r.position + Vector2(20, 12), c.name, 10, TEXT_DARK, 60)
		_text(r.position + Vector2(82, 12), String(s.role), 10, BROWN, 76)
	if _hover >= 0:
		var role: String = GameState.survivors[_hover].role
		var rs := UiFrame.fs(10)
		draw_multiline_string(_font, Vector2(PANEL.position.x + 172, PANEL.end.y - 8 - _font.get_height(rs)), Settlement.ROLE_TEXT[role], HORIZONTAL_ALIGNMENT_LEFT, 160, rs, 2, GOLD)
	UiFrame.footer(self, "[{click}] / [1-8] change role  [{back}] close")
