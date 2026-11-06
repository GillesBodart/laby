extends Control
## Skill screen (K): spend skill points (1-4 or click) on ranks of each skill.
## Drawn in 480x270 UI space.

const SIZE := Vector2(480, 270)
const PANEL := Rect2(110, 24, 260, 226)
const INK := Color8(27, 20, 16)
const CREAM := Color8(236, 222, 186)
const BROWN := Color8(120, 84, 52)
const GOLD := Color8(242, 210, 92)
const GREEN := Color8(58, 96, 64)
const GREEN_DARK := Color8(34, 58, 42)
const TEXT_DARK := Color8(58, 42, 30)
const TEXT_LIGHT := Color8(238, 226, 196)

var _font: Font


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2.ZERO
	size = SIZE
	_font = ThemeDB.fallback_font


func _player() -> Player:
	return GameState.players.get(GameState.local_peer_id())


func _skill_ids() -> Array:
	return Survival.SKILLS.keys()


func _row_rect(i: int) -> Rect2:
	return Rect2(PANEL.position.x + 12, PANEL.position.y + 44 + i * 40, PANEL.size.x - 24, 36)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skills"):
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
		else:
			var idx: int = event.physical_keycode - KEY_1
			if idx >= 0 and idx < _skill_ids().size():
				learn(_skill_ids()[idx])
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_local_mouse_position()
		for i in _skill_ids().size():
			if _row_rect(i).has_point(m):
				learn(_skill_ids()[i])


func learn(id: String) -> bool:
	var player := _player()
	if player == null:
		return false
	var ok := player.survival.learn(id)
	if ok:
		EventBus.notify.emit("%s rank %d" % [Survival.SKILLS[id].name, player.survival.rank(id)])
	queue_redraw()
	return ok


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _text(pos: Vector2, s: String, col: Color) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _box(r: Rect2, fill: Color, border: Color, radius := 4) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, r)


func _draw() -> void:
	var player := _player()
	if player == null:
		return
	var s := player.survival
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.03, 0.05, 0.08, 0.72))
	_box(PANEL, GREEN_DARK, INK, 8)
	_box(PANEL.grow(-5), GREEN, GREEN_DARK, 6)
	var title := Rect2(PANEL.get_center().x - 70, 8, 140, 24)
	_box(title, CREAM, BROWN, 3)
	_text(Vector2(title.position.x + 44, 25), "SKILLS", TEXT_DARK)
	_text(Vector2(PANEL.position.x + 14, PANEL.position.y + 36), "Level %d   Points: %d" % [s.level, s.skill_points], GOLD)
	for i in _skill_ids().size():
		var id: String = _skill_ids()[i]
		var r := _row_rect(i)
		var rank := s.rank(id)
		_box(r, CREAM, GOLD if s.can_learn(id) else BROWN, 3)
		_text(r.position + Vector2(6, 14), "%d %s" % [i + 1, Survival.SKILLS[id].name], TEXT_DARK)
		_text(r.position + Vector2(6, 31), Survival.SKILLS[id].desc, BROWN)
		for k in Survival.SKILL_MAX_RANK:
			var pip := Rect2(r.end.x - 48 + k * 14, r.position.y + 6, 10, 10)
			_box(pip, GOLD if k < rank else Color8(170, 150, 120), INK, 2)
	_text(Vector2(PANEL.position.x + 14, PANEL.end.y - 10), "[K] close  [1-4] learn", TEXT_LIGHT)
