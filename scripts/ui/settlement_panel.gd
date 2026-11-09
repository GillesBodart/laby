extends Control
## Settlement overview (talk to a survivor): tier and what the next one
## needs, the camp's needs, and the survivors - click one to change its role.

const PANEL := Rect2(70, 24, 340, 222)
const ROW := Vector2(160, 16)

const INK := Color8(27, 20, 16)
const CREAM := Color8(236, 222, 186)
const BROWN := Color8(96, 72, 48)
const TEXT_DARK := Color8(58, 42, 30)
const FADED := Color8(150, 126, 98)
const GOLD := Color8(242, 210, 92)
const GREEN := Color8(70, 130, 60)
const RED := Color8(170, 60, 50)
const WOOD := Color8(70, 52, 36)
const WOOD_DARK := Color8(40, 30, 22)
const TEXT_LIGHT := Color8(238, 226, 196)

var _font: Font
var _hover := -1
var _icons := {}


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
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
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	draw_style_box(sb, r)


func _text(at: Vector2, s: String, sz: int, c: Color) -> void:
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)


func _npc(sprite: String) -> Texture2D:
	if not _icons.has(sprite):
		_icons[sprite] = load("res://assets/sprites/npcs/%s.png" % sprite)
	return _icons[sprite]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.02, 0.6))
	_box(PANEL, WOOD_DARK, INK)
	draw_rect(PANEL.grow(-3), WOOD, false)
	var tier: int = GameState.settlement_tier
	var title := Rect2(PANEL.get_center().x - 80, PANEL.position.y + 6, 160, 22)
	_box(title, CREAM, BROWN)
	var t := "THE CLEARING - %s" % Settlement.TIERS[tier].to_upper()
	_text(Vector2(title.get_center().x - _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x / 2.0, title.end.y - 7), t, 12, TEXT_DARK)

	# Left column: next tier checklist and needs.
	var left := Rect2(PANEL.position + Vector2(8, 34), Vector2(156, PANEL.size.y - 54))
	_box(left, CREAM, BROWN)
	var y := left.position.y + 13
	var x := left.position.x + 6
	if tier + 1 < Settlement.TIERS.size():
		_text(Vector2(x, y), "Next: %s (room for %d)" % [Settlement.TIERS[tier + 1], Settlement.cap(tier + 1)], 10, TEXT_DARK)
		y += 13
		var need: Dictionary = Settlement.NEEDS[tier + 1]
		for key in need:
			var have: int = Settlement.count(GameState.structures, key) if key != "bosses" else GameState.bosses_defeated.size()
			var ok: bool = have >= int(need[key])
			_text(Vector2(x + 4, y), "%s %s %d/%d" % ["+" if ok else "-", Settlement.NEED_NAMES[key], mini(have, int(need[key])), int(need[key])], 10, GREEN if ok else RED)
			y += 12
	else:
		_text(Vector2(x, y), "The settlement is complete.", 10, GREEN)
		y += 12
	y += 6
	var n := Settlement.needs(GameState.survivors, GameState.structures, GameState.stash)
	_text(Vector2(x, y), "Camp needs (%d/%d people)" % [GameState.survivors.size(), Settlement.cap(tier)], 10, TEXT_DARK)
	y += 13
	var rows := [
		["Food in the Stash (%d/day)" % Settlement.food_needed(GameState.survivors), n.food],
		["Water (a well for 3+)", n.water],
		["Shelter (beds)", n.shelter],
	]
	for r in rows:
		_text(Vector2(x + 4, y), ("+ " if r[1] else "- ") + r[0], 10, GREEN if r[1] else RED)
		y += 12
	_text(Vector2(x + 4, y), "Defence rating: %d" % n.defence, 10, TEXT_DARK)

	# Right column: survivors.
	_text(PANEL.position + Vector2(172, 44), "Survivors - click to change role", 10, TEXT_LIGHT)
	for i in GameState.survivors.size():
		var s: Dictionary = GameState.survivors[i]
		var c: Dictionary = Settlement.CAST[int(s.cast)]
		var r := _row_rect(i)
		_box(r, CREAM, GOLD if i == _hover else BROWN)
		var tex := _npc(c.sprite)
		if tex:
			draw_texture_rect_region(tex, Rect2(r.position + Vector2(2, 1), Vector2(14, 14)), Rect2(Vector2(0, 0), Vector2(tex.get_width(), tex.get_height() * 0.6)))
		_text(r.position + Vector2(20, 12), c.name, 10, TEXT_DARK)
		_text(r.position + Vector2(82, 12), String(s.role), 10, BROWN)
	if _hover >= 0:
		var role: String = GameState.survivors[_hover].role
		_text(Vector2(PANEL.position.x + 172, PANEL.end.y - 24), Settlement.ROLE_TEXT[role], 10, GOLD)
	var hint := "Click / 1-8 change role  -  Esc to close"
	var hw := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	_text(Vector2(PANEL.get_center().x - hw / 2.0, PANEL.end.y - 8), hint, 10, TEXT_LIGHT)
