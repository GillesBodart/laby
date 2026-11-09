extends Control
## Skill graph screen (K, or E at a Skill Altar). Radial passive tree from
## SkillGraph: click a glowing node to spend a point, drag to pan, wheel to
## zoom. At an altar a RESPEC button refunds every point for a Memory Shard.
## Drawn in 480x270 UI space.

const SIZE := Vector2(480, 270)
const UNIT := 16.0
const INK := Color8(27, 20, 16)
const CREAM := Color8(236, 222, 186)
const BROWN := Color8(120, 84, 52)
const GOLD := Color8(242, 210, 92)
const DIM := Color8(70, 72, 80)
const TEXT_DARK := Color8(58, 42, 30)
const TEXT_LIGHT := Color8(238, 226, 196)
const RESPEC_RECT := Rect2(372, 240, 100, 22)
const ALTAR_RANGE := 64.0

var _font: Font
var _pan := Vector2.ZERO
var _zoom := 0.85
var _dragging := false
var _drag_moved := 0.0
var _hover := ""
var _altar: Node2D


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2.ZERO
	size = SIZE
	_font = ThemeDB.get_project_theme().default_font
	EventBus.altar_used.connect(open_at_altar)


func _player() -> Player:
	return GameState.players.get(GameState.local_peer_id())


func open_at_altar(altar: Node2D) -> void:
	_show()
	_altar = altar


func _show() -> void:
	for p in get_tree().get_nodes_in_group("ui_panels"):
		if p != self:
			p.visible = false
	visible = true
	_altar = null


func graph_to_screen(p: Vector2) -> Vector2:
	return SIZE / 2.0 + Vector2(0, 8) + _pan + p * UNIT * _zoom


func _radius(id: String) -> float:
	match SkillGraph.kind(id):
		"keystone":
			return 7.0
		"notable":
			return 5.5
	return 4.0


## Skill node under a UI-space point ("" if none).
func node_at(pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for id in SkillGraph.NODES:
		var d := graph_to_screen(SkillGraph.position(id)).distance_to(pos)
		if d <= _radius(id) * _zoom + 3.0 and d < best_d:
			best = id
			best_d = d
	return best


func _at_altar() -> bool:
	var p := _player()
	return _altar != null and is_instance_valid(_altar) and p != null \
			and p.global_position.distance_to(_altar.global_position) < ALTAR_RANGE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skills"):
		if visible:
			visible = false
		else:
			_show()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var m := get_local_mouse_position()
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(m, 1.15)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(m, 1.0 / 1.15)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_dragging = true
					_drag_moved = 0.0
				elif _dragging:
					_dragging = false
					if _drag_moved < 4.0:
						_click(m)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _dragging:
			var d: Vector2 = event.relative * (SIZE.x / maxf(get_viewport_rect().size.x, 1.0))
			_pan += d
			_drag_moved += d.length()
		_hover = node_at(get_local_mouse_position())


func _zoom_at(m: Vector2, factor: float) -> void:
	var old := _zoom
	_zoom = clampf(_zoom * factor, 0.6, 2.2)
	var anchor := SIZE / 2.0 + Vector2(0, 8)
	_pan = (m - anchor) - ((m - anchor - _pan) * (_zoom / old))


func _click(m: Vector2) -> void:
	if _at_altar() and RESPEC_RECT.has_point(m):
		respec()
		return
	var id := node_at(m)
	if id != "":
		learn(id)


func learn(id: String) -> bool:
	var player := _player()
	if player == null:
		return false
	var ok := player.survival.learn(id, GameState.reached)
	if ok:
		EventBus.notify.emit("%s %d/%d" % [SkillGraph.node(id).name, player.survival.rank(id), SkillGraph.max_rank(id)])
	elif SkillGraph.has(id) and not SkillGraph.gate_open(id, GameState.reached):
		EventBus.notify.emit("Sealed until you reach %s." % Sectors.display_name(SkillGraph.gate(id)))
	queue_redraw()
	return ok


## Offers a Memory Shard to unlearn every skill (altar only).
func respec() -> bool:
	var player := _player()
	if player == null or not _at_altar():
		return false
	if player.survival.skills.is_empty():
		EventBus.notify.emit("Nothing to unlearn.")
		return false
	if not player.inventory.remove(Survival.RESPEC_ITEM, 1):
		EventBus.notify.emit("The altar asks for a Memory Shard.")
		return false
	var refund := player.survival.respec()
	EventBus.notify.emit("Your mind is clear again. %d points returned." % refund)
	return true


func _process(_delta: float) -> void:
	if visible:
		if _altar != null and not _at_altar():
			_altar = null
		queue_redraw()


func _text(pos: Vector2, s: String, col: Color, fsize := 16) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _text_w(s: String, fsize := 16) -> float:
	return _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x


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
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.03, 0.04, 0.07, 1.0))
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	# Hub ring and cluster labels.
	draw_arc(graph_to_screen(Vector2.ZERO), 1.6 * UNIT * _zoom, 0.0, TAU, 40, Color(1, 1, 1, 0.08), 1.0)
	for c in SkillGraph.CLUSTERS:
		if c == "core":
			continue
		var info: Dictionary = SkillGraph.CLUSTERS[c]
		var at := graph_to_screen(Vector2.from_angle(deg_to_rad(info.angle)) * 7.9)
		var w := _text_w(info.name, 12)
		var dx := cos(deg_to_rad(info.angle))
		if absf(dx) > 0.9:
			at.x += signf(dx) * (w / 2.0 + 8.0)
		_text(at - Vector2(w / 2.0, -4), info.name, info.color.darkened(0.1), 12)
	# Edges.
	for e in SkillGraph.edges():
		var a := graph_to_screen(SkillGraph.position(e[0]))
		var b := graph_to_screen(SkillGraph.position(e[1]))
		var lit := s.rank(e[0]) > 0 and s.rank(e[1]) > 0
		var col := SkillGraph.cluster_color(e[1]) if lit else (Color8(120, 110, 90) if s.rank(e[0]) > 0 else Color8(48, 50, 58))
		draw_line(a, b, col, 2.0 if lit else 1.0)
	# Nodes.
	for id in SkillGraph.NODES:
		_draw_node(id, s, pulse)
	# Header.
	var title := Rect2(SIZE.x / 2.0 - 60, 4, 120, 20)
	_box(title, CREAM, BROWN, 3)
	_text(Vector2(title.get_center().x - _text_w("SKILL GRAPH", 14) / 2.0, 19), "SKILL GRAPH", TEXT_DARK, 14)
	_text(Vector2(8, 18), "Level %d" % s.level, TEXT_LIGHT, 14)
	_text(Vector2(8, 34), "Points: %d" % s.skill_points, GOLD if s.skill_points > 0 else TEXT_LIGHT, 14)
	draw_rect(Rect2(0, SIZE.y - 20, SIZE.x, 20), Color(0.03, 0.04, 0.07, 1.0))
	_text(Vector2(8, SIZE.y - 8), "[K] close   click: learn   drag: pan   wheel: zoom", Color8(160, 150, 130), 11)
	if _at_altar():
		var shards := player.inventory.count(Survival.RESPEC_ITEM)
		_box(RESPEC_RECT, Color8(70, 44, 110), GOLD if shards > 0 else DIM, 3)
		_text(RESPEC_RECT.position + Vector2(8, 15), "RESPEC (%d shard)" % shards, TEXT_LIGHT, 11)
	if _hover != "":
		_draw_tooltip(_hover, s)


func _draw_node(id: String, s: Survival, pulse: float) -> void:
	var p := graph_to_screen(SkillGraph.position(id))
	var r := _radius(id) * _zoom
	var col := SkillGraph.cluster_color(id)
	var rank := s.rank(id)
	var reach := SkillGraph.reachable(id, s.skills)
	var gated := not SkillGraph.gate_open(id, GameState.reached)
	var fill := col if rank > 0 else (Color8(34, 36, 44) if reach else Color8(18, 19, 24))
	var border := col.lightened(0.3) if rank > 0 else (col.darkened(0.2) if reach else DIM)
	if s.can_learn(id, GameState.reached):
		draw_circle(p, r + 2.5 + pulse * 1.5, Color(GOLD, 0.35 + 0.35 * pulse))
		border = GOLD
	if SkillGraph.kind(id) == "keystone":
		var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
		draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		draw_polyline(pts, border, 1.5)
	else:
		draw_circle(p, r, fill)
		draw_arc(p, r, 0.0, TAU, 16, border, 1.5 if SkillGraph.kind(id) == "notable" else 1.0)
	if rank > 0 and rank < SkillGraph.max_rank(id):
		draw_circle(p, maxf(r * 0.35, 1.5), INK)
	if gated:
		draw_rect(Rect2(p + Vector2(-1.5, -1.5), Vector2(3, 3)), Color8(150, 150, 160))
	if id == _hover:
		draw_arc(p, r + 2.0, 0.0, TAU, 16, Color.WHITE, 1.0)


func _draw_tooltip(id: String, s: Survival) -> void:
	var n := SkillGraph.node(id)
	var lines := [
		["%s  %d/%d" % [n.name, s.rank(id), SkillGraph.max_rank(id)], TEXT_DARK],
		["%s, %s" % [SkillGraph.CLUSTERS[n.cluster].name, SkillGraph.kind(id)], BROWN],
		[SkillGraph.describe(id) + (" per rank" if SkillGraph.max_rank(id) > 1 else ""), TEXT_DARK],
	]
	if not SkillGraph.reachable(id, s.skills):
		var names := SkillGraph.requires(id).map(func(r): return SkillGraph.node(r).name)
		lines.append(["Needs: " + " or ".join(PackedStringArray(names)), Color8(150, 60, 40)])
	if not SkillGraph.gate_open(id, GameState.reached):
		lines.append(["Sealed until %s" % Sectors.display_name(SkillGraph.gate(id)), Color8(150, 60, 40)])
	var w := 0.0
	for l in lines:
		w = maxf(w, _text_w(l[0], 11))
	var m := get_local_mouse_position() + Vector2(10, 10)
	var box := Rect2(m, Vector2(w + 12, lines.size() * 13 + 6))
	if box.end.x > SIZE.x - 4:
		box.position.x = m.x - box.size.x - 20
	if box.end.y > SIZE.y - 4:
		box.position.y = SIZE.y - 4 - box.size.y
	_box(box, CREAM, BROWN, 3)
	for i in lines.size():
		_text(box.position + Vector2(6, 14 + i * 13), lines[i][0], lines[i][1], 11)
