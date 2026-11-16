extends Control
## Skill graph screen (K, or E at a Skill Altar). Radial passive tree from
## SkillGraph: click a glowing node to spend a point, drag to pan, wheel to
## zoom. At an altar a RESPEC button refunds every point for a Memory Shard.
## Nodes show a glyph of their headline stat and pips for their ranks.
## Drawn in 480x270 UI space.

const SIZE := Vector2(480, 270)
const UNIT := 13.0
const PANEL := Rect2(16, 14, 448, 240)
const WELL := Rect2(25, 23, 430, 222)
const CENTER := Vector2(240, 138)
const INK := UiPalette.INK
const CREAM := UiPalette.CREAM
const BROWN := UiPalette.BROWN
const GOLD := UiPalette.GOLD
const DIM := Color8(70, 76, 74)
const TEXT_DARK := UiPalette.TEXT_DARK
const TEXT_LIGHT := UiPalette.TEXT_LIGHT
const RESPEC_RECT := Rect2(352, 228, 96, 20)
const ALTAR_RANGE := 64.0
const WELL_FILL := Color(0.02, 0.07, 0.05)
const LOCKED_FILL := Color8(22, 28, 27)

var _font: Font
var _pan := Vector2.ZERO
var _zoom := 1.0
var _dragging := false
var _drag_moved := 0.0
var _hover := ""
var _altar: Node2D


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	return CENTER + _pan + p * UNIT * _zoom


func _radius(id: String) -> float:
	match SkillGraph.kind(id):
		"keystone":
			return 8.5
		"notable":
			return 7.0
	return 5.5


## Skill node under a UI-space point ("" if none).
func node_at(pos: Vector2) -> String:
	if not WELL.has_point(pos):
		return ""
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
	_zoom = clampf(_zoom * factor, 0.7, 2.2)
	_pan = (m - CENTER) - ((m - CENTER - _pan) * (_zoom / old))


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
		EventBus.notify.emit("Sealed until you reach the %s." % Sectors.display_name(SkillGraph.gate(id)))
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


## Text at a base size scaled by the text-size setting.
func _text(pos: Vector2, s: String, col: Color, fsize := 16) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFrame.fs(fsize), col)


func _text_w(s: String, fsize := 16) -> float:
	return _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFrame.fs(fsize)).x


func _box(r: Rect2, fill: Color, border: Color, radius := 4) -> void:
	UiFrame.plate(self, r, fill, border, radius)


func _draw() -> void:
	var player := _player()
	if player == null:
		return
	var s := player.survival
	draw_rect(Rect2(Vector2.ZERO, SIZE), UiPalette.SHADE)
	UiFrame.box(self, PANEL)
	_draw_well()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	var z := UNIT * _zoom
	var hub := graph_to_screen(Vector2.ZERO)
	# Soft glow behind each specialization, then its name plate.
	for c in SkillGraph.CLUSTERS:
		if c == "core":
			continue
		var info: Dictionary = SkillGraph.CLUSTERS[c]
		var dir := Vector2.from_angle(deg_to_rad(info.angle))
		var glow := hub + dir * 5.0 * z
		for k in 3:
			var gr := (3.4 - k * 0.9) * z
			if WELL.grow(gr).has_point(glow):
				draw_circle(glow, gr, Color(info.color, 0.045), true, -1.0, true)
	_hub_ring(hub, z)
	# Edges: lit when both ends are learned, amber when they open a new node.
	for e in SkillGraph.edges():
		var seg := _clip(graph_to_screen(SkillGraph.position(e[0])), graph_to_screen(SkillGraph.position(e[1])))
		if seg.is_empty():
			continue
		var r0 := s.rank(e[0]) > 0
		var r1 := s.rank(e[1]) > 0
		if r0 and r1:
			draw_line(seg[0], seg[1], INK, 4.5, true)
			draw_line(seg[0], seg[1], SkillGraph.cluster_color(e[1]), 2.5, true)
		elif r0:
			draw_line(seg[0], seg[1], INK, 3.0, true)
			draw_line(seg[0], seg[1], Color(GOLD, 0.55), 1.5, true)
		else:
			draw_line(seg[0], seg[1], Color8(66, 80, 74), 1.2, true)
	for id in SkillGraph.NODES:
		_draw_node(id, s, pulse)
	_hub_medallion(hub, z, s.level)
	for c in SkillGraph.CLUSTERS:
		if c != "core":
			_cluster_label(c, hub, z)
	# Header: title, then the spendable points.
	UiFrame.title_plate(self, SIZE.x / 2.0, 4, "SKILL GRAPH")
	var pts := "Points  %d" % s.skill_points
	var pw := _text_w(pts, 11) + 14.0
	var chip := Rect2(WELL.position + Vector2(6, 6), Vector2(pw, float(UiFrame.fs(11)) + 6.0))
	draw_style_box(UiFrame.flat(Color(INK, 0.8), GOLD if s.skill_points > 0 else DIM, 6), chip)
	_text(chip.position + Vector2(7, float(UiFrame.fs(11)) + 1.0), pts, GOLD if s.skill_points > 0 else TEXT_LIGHT, 11)
	var hint := "[{skills}] close  [{click}] learn  [Drag] pan  [Wheel] zoom"
	if _at_altar():
		# Keep the centred footer clear of the respec button.
		UiFrame.footer(self, hint, SIZE.x / 2.0, (RESPEC_RECT.position.x - SIZE.x / 2.0) * 2.0 - 8.0)
		var shards := player.inventory.count(Survival.RESPEC_ITEM)
		_box(RESPEC_RECT, Color8(70, 44, 110), GOLD if shards > 0 else DIM, 3)
		var label := "RESPEC (%d shard)" % shards
		var ls := UiFrame.fs(11)
		while ls > 8 and _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x > RESPEC_RECT.size.x - 8:
			ls -= 1
		draw_string(_font, RESPEC_RECT.position + Vector2(4, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, ls, TEXT_LIGHT)
	else:
		UiFrame.footer(self, hint)
	if _hover != "":
		_draw_tooltip(_hover, s)


## Dark sunken well inside the felt frame, lighter toward the hub.
func _draw_well() -> void:
	draw_style_box(UiFrame.flat(WELL_FILL, UiPalette.INK, 5, 1), WELL)
	var c := WELL.get_center()
	for k in 5:
		var rr := WELL.size.y * (0.62 - k * 0.11)
		draw_circle(c, rr, Color(UiPalette.LEAF, 0.025), true, -1.0, true)
	draw_style_box(UiFrame.flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0.35), 5, 2), WELL.grow(-1))


func _hub_ring(hub: Vector2, z: float) -> void:
	if WELL.grow(-2).has_point(hub):
		draw_arc(hub, 1.6 * z, 0.0, TAU, 48, Color(CREAM, 0.16), 1.5, true)


## Level medallion at the hub.
func _hub_medallion(hub: Vector2, z: float, level: int) -> void:
	var r := 0.95 * z
	if not WELL.grow(-r).has_point(hub):
		return
	draw_circle(hub + Vector2(0, 1.5), r + 1.5, Color(0, 0, 0, 0.45), true, -1.0, true)
	draw_circle(hub, r + 1.5, INK, true, -1.0, true)
	draw_circle(hub, r, UiPalette.FOREST.darkened(0.35), true, -1.0, true)
	draw_circle(hub + Vector2(-0.25, -0.3) * r, r * 0.55, Color(UiPalette.LEAF, 0.25), true, -1.0, true)
	draw_arc(hub, r, 0.0, TAU, 32, UiPalette.MUSTARD, 1.5, true)
	var fsz := UiFrame.fs(11)
	var num := str(level)
	var nw := _font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	draw_string(_font, hub + Vector2(-nw / 2.0, _font.get_ascent(fsz) * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, GOLD)


## Name plate beside the cluster's keystone, on its outer side.
func _cluster_label(c: String, hub: Vector2, z: float) -> void:
	var info: Dictionary = SkillGraph.CLUSTERS[c]
	var dir := Vector2.from_angle(deg_to_rad(info.angle))
	var w := _text_w(info.name, 11)
	var h := float(UiFrame.fs(11)) + 5.0
	var at := hub + dir * 7.0 * z
	at.x += signf(dir.x) * (8.5 * 1.22 * _zoom + 8.0 + w / 2.0 + 7.0)
	var r := Rect2(at - Vector2(w / 2.0 + 7.0, h / 2.0), Vector2(w + 14.0, h))
	if not WELL.encloses(r):
		return
	draw_style_box(UiFrame.flat(Color(INK, 0.78), Color(info.color, 0.55), 7), r)
	_text(r.position + Vector2(7, h - 4.0), info.name, info.color.lightened(0.15), 11)


## Segment a-b clipped to the well (empty when fully outside).
func _clip(a: Vector2, b: Vector2) -> PackedVector2Array:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	var box := WELL.grow(-2)
	for k in 4:
		var p: float = [-d.x, d.x, -d.y, d.y][k]
		var q: float = [a.x - box.position.x, box.end.x - a.x, a.y - box.position.y, box.end.y - a.y][k]
		if is_zero_approx(p):
			if q < 0.0:
				return PackedVector2Array()
			continue
		var t := q / p
		if p < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
		if t0 > t1:
			return PackedVector2Array()
	return PackedVector2Array([a + d * t0, a + d * t1])


func _draw_node(id: String, s: Survival, pulse: float) -> void:
	var p := graph_to_screen(SkillGraph.position(id))
	var r := _radius(id) * _zoom
	if not WELL.grow(-r).has_point(p):
		return
	var col := SkillGraph.cluster_color(id)
	var rank := s.rank(id)
	var reach := SkillGraph.reachable(id, s.skills)
	var gated := not SkillGraph.gate_open(id, GameState.reached)
	var k := SkillGraph.kind(id)
	var fill := col.darkened(0.12) if rank > 0 else (col.darkened(0.74) if reach else LOCKED_FILL)
	var rim := col.lightened(0.35) if rank > 0 else (col.darkened(0.05) if reach else DIM)
	var glyph := INK if rank > 0 else (col.lightened(0.2) if reach else Color8(92, 98, 96))
	if s.can_learn(id, GameState.reached):
		draw_circle(p, r + 3.0 + pulse * 1.5, Color(GOLD, 0.2 + 0.25 * pulse), true, -1.0, true)
		rim = GOLD
	var shape := _diamond(p, r * 1.22) if k == "keystone" else PackedVector2Array()
	if k == "keystone":
		var shadow := _diamond(p + Vector2(0, 1.5), r * 1.22 + 2.0)
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
		draw_colored_polygon(_diamond(p, r * 1.22 + 1.6), INK)
		draw_colored_polygon(shape, fill)
	else:
		draw_circle(p + Vector2(0, 1.5), r + 1.4, Color(0, 0, 0, 0.45), true, -1.0, true)
		draw_circle(p, r + 1.4, INK, true, -1.0, true)
		draw_circle(p, r, fill, true, -1.0, true)
	if rank > 0:
		draw_circle(p + Vector2(-0.28, -0.32) * r, r * 0.5, Color(col.lightened(0.45), 0.45), true, -1.0, true)
	_glyph(_stat_of(id), p, r * (0.58 if k == "small" else 0.62), glyph, fill)
	if k == "keystone":
		var loop := shape.duplicate()
		loop.append(shape[0])
		draw_polyline(loop, rim, 1.6, true)
		var outer := _diamond(p, r * 1.22 + 3.2)
		outer.append(outer[0])
		draw_polyline(outer, Color(rim, 0.55), 1.0, true)
	else:
		draw_arc(p, r, 0.0, TAU, 28, rim, 1.8 if k == "notable" else 1.3, true)
		if k == "notable":
			draw_arc(p, r + 3.0, 0.0, TAU, 32, Color(rim, 0.55), 1.0, true)
	# Rank pips under multi-rank nodes.
	var mr := SkillGraph.max_rank(id)
	if mr > 1:
		var pr := r + 3.4
		for i in mr:
			var a := PI / 2.0 + (i - (mr - 1) / 2.0) * 0.42
			var q := p + Vector2.from_angle(a) * pr
			draw_circle(q, 1.9, INK, true, -1.0, true)
			draw_circle(q, 1.2, GOLD if i < rank else Color8(60, 66, 64), true, -1.0, true)
	if gated:
		_lock(p + Vector2(r * 0.72, -r * 0.72))
	if id == _hover:
		draw_arc(p, r + (5.0 if k != "small" else 3.0), 0.0, TAU, 32, Color.WHITE, 1.0, true)


static func _diamond(p: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])


## Small padlock badge: sealed until a sector is reached.
func _lock(c: Vector2) -> void:
	draw_circle(c, 3.6, INK, true, -1.0, true)
	draw_arc(c + Vector2(0, -0.6), 1.3, PI, TAU, 8, Color8(200, 196, 180), 0.9, true)
	draw_rect(Rect2(c + Vector2(-1.7, -0.5), Vector2(3.4, 2.4)), Color8(200, 196, 180))


## The node's headline stat (first bonus, positive ones first).
static func _stat_of(id: String) -> String:
	var fx: Dictionary = SkillGraph.node(id).get("fx", {})
	for st in fx:
		if fx[st] > 0:
			return st
	return fx.keys()[0] if not fx.is_empty() else ""


## Vector glyph for a stat, `s` is its half size.
func _glyph(stat: String, c: Vector2, s: float, col: Color, bg: Color) -> void:
	var w := maxf(s * 0.3, 1.0)
	match stat:
		"dmg":
			draw_line(c + Vector2(-0.55, 0.55) * s, c + Vector2(0.85, -0.85) * s, col, w * 1.1, true)
			draw_line(c + Vector2(-0.75, 0.05) * s, c + Vector2(-0.05, 0.75) * s, col, w, true)
			draw_line(c + Vector2(-0.45, 0.45) * s, c + Vector2(-0.85, 0.85) * s, col, w * 0.9, true)
		"ranged":
			draw_line(c + Vector2(-0.8, 0.8) * s, c + Vector2(0.45, -0.45) * s, col, w * 0.7, true)
			_poly([c + Vector2(0.9, -0.9) * s, c + Vector2(0.2, -0.65) * s, c + Vector2(0.65, -0.2) * s], col)
			draw_line(c + Vector2(-0.8, 0.8) * s, c + Vector2(-0.8, 0.3) * s, col, w * 0.7, true)
			draw_line(c + Vector2(-0.8, 0.8) * s, c + Vector2(-0.3, 0.8) * s, col, w * 0.7, true)
		"armor", "block":
			_poly([c + Vector2(-0.75, -0.7) * s, c + Vector2(0, -0.9) * s, c + Vector2(0.75, -0.7) * s,
				c + Vector2(0.65, 0.15) * s, c + Vector2(0, 0.9) * s, c + Vector2(-0.65, 0.15) * s], col)
			draw_line(c + Vector2(0, -0.6) * s, c + Vector2(0, 0.55) * s, bg, w * 0.6, true)
		"crit":
			_poly(_star(c, s * 0.95, s * 0.38, 8, PI / 8.0), col)
		"xp":
			_poly(_star(c, s * 0.95, s * 0.42, 5, -PI / 2.0), col)
		"hp":
			var heart := PackedVector2Array()
			for i in 24:
				var t := TAU * i / 24.0
				heart.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)) + 1.5) * (s * 0.95 / 16.0))
			draw_colored_polygon(heart, col)
		"speed":
			for dx in [-0.35, 0.35]:
				draw_polyline(PackedVector2Array([c + Vector2(dx - 0.35, -0.7) * s, c + Vector2(dx + 0.35, 0) * s, c + Vector2(dx - 0.35, 0.7) * s]), col, w, true)
		"run_cost":
			_poly([c + Vector2(0.33, -1.0) * s, c + Vector2(-0.67, 0.15) * s, c + Vector2(-0.07, 0.15) * s,
				c + Vector2(-0.33, 1.0) * s, c + Vector2(0.67, -0.18) * s, c + Vector2(0.07, -0.18) * s], col)
		"strength":
			_poly([c + Vector2(-0.95, -0.55) * s, c + Vector2(0.95, -0.55) * s, c + Vector2(0.6, -0.15) * s, c + Vector2(-0.95, -0.15) * s], col)
			_poly([c + Vector2(-0.3, -0.15) * s, c + Vector2(0.3, -0.15) * s, c + Vector2(0.55, 0.7) * s, c + Vector2(-0.55, 0.7) * s], col)
		"hunger":
			draw_line(c + Vector2(-0.1, 0.1) * s, c + Vector2(-0.7, 0.7) * s, col, w * 0.8, true)
			draw_circle(c + Vector2(-0.8, 0.55) * s, s * 0.17, col, true, -1.0, true)
			draw_circle(c + Vector2(-0.55, 0.8) * s, s * 0.17, col, true, -1.0, true)
			draw_set_transform(c + Vector2(0.2, -0.2) * s, -PI / 4.0)
			draw_circle(Vector2.ZERO, s * 0.6, col, true, -1.0, true)
			draw_set_transform(Vector2.ZERO)
		"thirst":
			var drop := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				drop.append(c + Vector2(0, 0.3) * s + Vector2(cos(a), sin(a)) * s * 0.62)
			drop.append(c + Vector2(0, -0.95) * s)
			draw_colored_polygon(drop, col)
		"regen":
			draw_line(c + Vector2(0, -0.75) * s, c + Vector2(0, 0.75) * s, col, w * 1.3, true)
			draw_line(c + Vector2(-0.75, 0) * s, c + Vector2(0.75, 0) * s, col, w * 1.3, true)
		"warm":
			_poly([c + Vector2(0, -0.95) * s, c + Vector2(0.45, -0.25) * s, c + Vector2(0.6, 0.3) * s, c + Vector2(0.3, 0.8) * s,
				c + Vector2(-0.3, 0.8) * s, c + Vector2(-0.6, 0.3) * s, c + Vector2(-0.45, -0.2) * s, c + Vector2(-0.15, 0.05) * s], col)
		"cool":
			for i in 3:
				var d := Vector2.from_angle(PI / 2.0 + i * PI / 3.0) * s * 0.85
				draw_line(c - d, c + d, col, w * 0.8, true)
		"gather":
			var leaf := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				leaf.append(c + Vector2(cos(a) * 0.9, sin(a) * 0.45).rotated(-PI / 4.0) * s)
			draw_colored_polygon(leaf, col)
			draw_line(c + Vector2(-0.75, 0.75) * s, c + Vector2(0.45, -0.45) * s, bg, w * 0.5, true)
		"tame", "companions":
			draw_circle(c + Vector2(0, 0.35) * s, s * 0.42, col, true, -1.0, true)
			for t in [Vector2(-0.62, -0.12), Vector2(-0.24, -0.58), Vector2(0.24, -0.58), Vector2(0.62, -0.12)]:
				draw_circle(c + t * s, s * 0.2, col, true, -1.0, true)
		"lore":
			var eye := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				eye.append(c + Vector2(cos(a) * 0.95, sin(a) * 0.5) * s)
			draw_colored_polygon(eye, col)
			draw_circle(c, s * 0.3, bg, true, -1.0, true)
		"struct_hp":
			_poly([c + Vector2(0, -0.95) * s, c + Vector2(0.9, -0.1) * s, c + Vector2(-0.9, -0.1) * s], col)
			draw_rect(Rect2(c + Vector2(-0.6, -0.1) * s, Vector2(1.2, 0.95) * s), col)
			draw_rect(Rect2(c + Vector2(-0.18, 0.3) * s, Vector2(0.36, 0.55) * s), bg)
		_:
			draw_circle(c, s * 0.35, col, true, -1.0, true)


func _poly(pts: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), col)


static func _star(c: Vector2, ro: float, ri: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := rot + i * PI / n
		pts.append(c + Vector2.from_angle(a) * (ro if i % 2 == 0 else ri))
	return pts


func _draw_tooltip(id: String, s: Survival) -> void:
	var n := SkillGraph.node(id)
	var lines := [
		["%s  %d/%d" % [n.name, s.rank(id), SkillGraph.max_rank(id)], TEXT_DARK],
		["%s, %s" % [SkillGraph.CLUSTERS[n.cluster].name, SkillGraph.kind(id)], BROWN],
		[SkillGraph.describe(id) + (" per rank" if SkillGraph.max_rank(id) > 1 else ""), TEXT_DARK],
	]
	var warn := Accessibility.color("bad").darkened(0.3)
	if not SkillGraph.reachable(id, s.skills):
		var names := SkillGraph.requires(id).map(func(r): return SkillGraph.node(r).name)
		lines.append(["Needs: " + " or ".join(PackedStringArray(names)), warn])
	if not SkillGraph.gate_open(id, GameState.reached):
		lines.append(["Sealed until you reach the %s" % Sectors.display_name(SkillGraph.gate(id)), warn])
	var w := 0.0
	for l in lines:
		w = maxf(w, _text_w(l[0], 11))
	var lh := float(UiFrame.fs(11)) + 2.0
	var m := get_local_mouse_position() + Vector2(10, 10)
	var box := Rect2(m, Vector2(w + 12, lines.size() * lh + 6))
	if box.end.x > SIZE.x - 4:
		box.position.x = m.x - box.size.x - 20
	box.position.x = maxf(box.position.x, 4.0)
	if box.end.y > SIZE.y - 4:
		box.position.y = SIZE.y - 4 - box.size.y
	_box(box, CREAM, BROWN, 3)
	for i in lines.size():
		_text(box.position + Vector2(6, 1 + lh * (i + 1)), lines[i][0], lines[i][1], 11)
