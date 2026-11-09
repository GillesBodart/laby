extends Control
## Map overlay (M): the whole Clearing, or the explored part of the Labyrinth.
## Drawn in 480x270 UI space; the world is rendered into a small image.

const SIZE := Vector2(480, 270)
const FRAME := Rect2(24, 32, 432, 214)
const INK := Color8(27, 20, 16)
const BG := Color(0.03, 0.05, 0.08, 0.88)
const PLATE := Color8(236, 222, 186)
const EDGE := Color8(242, 210, 92)
const TEXT_DARK := Color8(58, 42, 30)
const TEXT_LIGHT := Color8(238, 226, 196)
const REFRESH := 0.25

const WALL := Color8(58, 64, 60)
const FLOOR_MAZE := Color8(150, 156, 148)
const GRASS := Color8(96, 156, 66)
const WATER := Color8(62, 134, 142)
const DIRT := Color8(140, 108, 70)
const GATE := Color8(242, 210, 92)
const TREE := Color8(40, 90, 42)
const BUILT := Color8(200, 150, 90)
const FOG := Color8(10, 12, 16)
const UNSURE := Color8(150, 110, 60)
const LANDMARK := Color8(242, 210, 92)
const GLYPH := Color8(120, 230, 190)
const MARKER_COLORS := {"danger": Color8(230, 70, 60), "resource": Color8(110, 210, 90), "door": Color8(240, 200, 80), "note": Color8(235, 235, 235)}

var _font: Font
var _texture: ImageTexture
var _image: Image
var _timer := 0.0
## Marker kind placed by a left click (keys 1-4 pick it).
var marker_kind := "danger"
var _route: Array = []
var _route_key := ""


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2.ZERO
	size = SIZE
	_font = ThemeDB.get_project_theme().default_font


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		for p in get_tree().get_nodes_in_group("ui_panels"):
			if p != self:
				p.visible = false
		visible = not visible
		_timer = 0.0
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		visible = false
	elif visible and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_4:
		marker_kind = GameState.MARKER_KINDS[event.physical_keycode - KEY_1]
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventMouseButton and event.pressed:
		click(get_local_mouse_position(), event.button_index)
		get_viewport().set_input_as_handled()


## Left click drops a marker of the chosen kind, right click removes one.
func click(at: Vector2, button: int) -> void:
	var cell := map_cell_at(at)
	if cell.x < 0:
		return
	if button == MOUSE_BUTTON_LEFT:
		GameState.add_marker(GameState.area, marker_kind, cell)
	elif button == MOUSE_BUTTON_RIGHT:
		GameState.remove_marker_near(GameState.area, cell)
	queue_redraw()


## Map cell under a point of the panel, or (-1, -1) outside the map.
func map_cell_at(point: Vector2) -> Vector2i:
	var world := _world()
	if world == null:
		return Vector2i(-1, -1)
	var scale := _scale(world)
	var rel := (point - _origin(world)) / scale
	var cell := Vector2i(floori(rel.x), floori(rel.y))
	if not world.layout.in_bounds(cell):
		return Vector2i(-1, -1)
	return cell


func _scale(world: World) -> float:
	return minf(FRAME.size.x / world.layout.size.x, FRAME.size.y / world.layout.size.y)


func _origin(world: World) -> Vector2:
	return FRAME.position + (FRAME.size - Vector2(world.layout.size) * _scale(world)) / 2.0


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		_rebuild()
	queue_redraw()


func _world() -> World:
	return get_tree().current_scene as World


func _rebuild() -> void:
	var world := _world()
	if world == null:
		return
	var layout := world.layout
	if _image == null or _image.get_size() != layout.size:
		_image = Image.create(layout.size.x, layout.size.y, false, Image.FORMAT_RGBA8)
	var props := layout.prop_cells()
	for y in layout.size.y:
		for x in layout.size.x:
			var cell := Vector2i(x, y)
			if world.fog != null and not world.fog.is_explored(cell):
				_image.set_pixel(x, y, FOG)
			elif world.fog != null and world.fog.is_uncertain(cell):
				# The walls moved here since: hatched, last known state faded.
				var c := _cell_color(world, cell, props) if (x + y) % 3 != 0 else UNSURE
				_image.set_pixel(x, y, c.lerp(FOG, 0.45))
			else:
				_image.set_pixel(x, y, _cell_color(world, cell, props))
	if _texture == null or _texture.get_size() != Vector2(layout.size):
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)


func _cell_color(world: World, cell: Vector2i, props: Dictionary) -> Color:
	var layout := world.layout
	if GameState.structures.has(cell):
		return BUILT
	if layout.is_wall(cell):
		return WALL
	if props.has(cell) and props[cell] == "tree" and not GameState.depleted_cells.has(cell):
		return TREE
	match layout.get_ground(cell):
		TileCatalog.Id.DIRT:
			return DIRT
		TileCatalog.Id.GATE_FLOOR:
			return GATE
		TileCatalog.Id.MAZE_FLOOR, TileCatalog.Id.MAZE_FLOOR_MOSS:
			return FLOOR_MAZE
		TileCatalog.Id.WATER:
			return WATER
	return GRASS


func _draw() -> void:
	var world := _world()
	if world == null or _texture == null:
		return
	draw_rect(Rect2(Vector2.ZERO, SIZE), BG)
	var title := Sectors.display_name(GameState.area).to_upper() if world.layout.fogged else "THE CLEARING"
	draw_rect(Rect2(160, 4, 160, 20), PLATE)
	draw_rect(Rect2(160, 4, 160, 20), INK, false)
	var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(_font, Vector2(240 - tw / 2.0, 19), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_DARK)
	var scale := _scale(world)
	var map_size := Vector2(world.layout.size) * scale
	var origin := _origin(world)
	draw_rect(Rect2(origin - Vector2(2, 2), map_size + Vector2(4, 4)), EDGE, false, 2.0)
	draw_texture_rect(_texture, Rect2(origin, map_size), false)
	for portal_def in world.layout.all_portals():
		var portal := Rect2(origin + Vector2(portal_def.rect.position) * scale, Vector2(portal_def.rect.size) * scale)
		draw_rect(portal, Color8(120, 220, 120), false, 1.0)
	var hints := _glyph_hints()
	_draw_hints(world, hints, origin, scale)
	if not world.layout.boss.is_empty() and world.fog != null and (world.fog.is_explored(world.layout.boss.cell) or hints.has("key")):
		var bp := origin + (Vector2(world.layout.boss.cell) + Vector2(0.5, 0.5)) * scale
		var dead := GameState.bosses_defeated.has(world.layout.boss.type)
		draw_rect(Rect2(bp - Vector2(3, 3), Vector2(6, 6)), Color8(120, 120, 120) if dead else Color8(190, 90, 230))
		draw_rect(Rect2(bp - Vector2(3, 3), Vector2(6, 6)), INK, false, 1.0)
	for m in world.layout.landmarks:
		if hints.has("lore") or world.fog == null or world.fog.is_explored(m.cell):
			_diamond(origin + (Vector2(m.cell) + Vector2(0.5, 0.5)) * scale, 3.0, LANDMARK)
	for g in world.layout.glyphs:
		if hints.has("lore") or world.fog == null or world.fog.is_explored(g.cell):
			var gp := origin + (Vector2(g.cell) + Vector2(0.5, 0.5)) * scale
			draw_rect(Rect2(gp - Vector2(2, 2), Vector2(4, 4)), GLYPH if GameState.in_journal("glyphs", g.glyph) else Color8(90, 110, 104))
			draw_rect(Rect2(gp - Vector2(2, 2), Vector2(4, 4)), INK, false, 1.0)
	for mk in GameState.markers.get(GameState.area, []):
		var mp := origin + (Vector2(mk.cell[0], mk.cell[1]) + Vector2(0.5, 0.5)) * scale
		draw_circle(mp, 3.5, INK)
		draw_circle(mp, 2.5, MARKER_COLORS.get(mk.kind, Color.WHITE))
	var blink := int(Time.get_ticks_msec() / 400) % 2 == 0
	for player in GameState.players.values():
		var c := world.clearing.walls.local_to_map(world.clearing.walls.to_local(player.global_position))
		var p := origin + (Vector2(c) + Vector2(0.5, 0.5)) * scale
		draw_circle(p, 3.0, INK)
		draw_circle(p, 2.0, Color.WHITE if blink else Color8(230, 70, 70))
	var footer := "[M] close"
	if world.fog != null:
		footer = "Explored %d%%   1-4: %s   click: mark / erase   M: close" % [int(world.fog.explored_fraction() * 100.0), marker_kind]
		draw_circle(Vector2(456, 260), 4.0, INK)
		draw_circle(Vector2(456, 260), 3.0, MARKER_COLORS[marker_kind])
	draw_string(_font, Vector2(24, 266), footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_LIGHT)


func _diamond(at: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r - 1), at + Vector2(r + 1, 0), at + Vector2(0, r + 1), at + Vector2(-r - 1, 0)]), INK)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), color)


## Hints earned from this sector's decoded glyph stones (see Glyphs.HINTS).
func _glyph_hints() -> Dictionary:
	var out := {}
	if not Sectors.is_sector(GameState.area):
		return out
	for i in LabyrinthGenerator.GLYPH_COUNT:
		var id := "%s_%d" % [GameState.area, i]
		if GameState.in_journal("glyphs", id):
			out[Glyphs.hint(id)] = true
	return out


func _draw_hints(world: World, hints: Dictionary, origin: Vector2, scale: float) -> void:
	if hints.has("shift"):
		# Tonight's moving passages (or the next ones, by day).
		var night := TimeSystem.clock.night_index()
		var next := night + (0 if TimeSystem.phase() != DayClock.Phase.NIGHT else 1)
		for region in LabyrinthGenerator.shift_regions(GameState.world_seed, GameState.area, maxi(next, 1)):
			var r := LabyrinthGenerator.region_tiles(region)
			draw_rect(Rect2(origin + Vector2(r.position) * scale, Vector2(r.size) * scale), Color8(240, 150, 60), false, 1.0)
	if hints.has("route"):
		var key := "%s:%d" % [GameState.area, TimeSystem.clock.night_index()]
		if key != _route_key:
			_route_key = key
			_route = route(world.layout, world.layout.return_cell, world.layout.boss.get("cell", world.layout.return_cell))
		for i in range(0, _route.size(), 2):
			draw_rect(Rect2(origin + (Vector2(_route[i]) + Vector2(0.3, 0.3)) * scale, Vector2(1.5, 1.5)), GLYPH)
	if hints.has("key") and world.layout.arena_rect.size != Vector2i.ZERO:
		var a: Rect2i = world.layout.arena_rect
		draw_rect(Rect2(origin + Vector2(a.position) * scale, Vector2(a.size) * scale), Color8(190, 90, 230), false, 1.0)


## Shortest walkable path between two cells (BFS over the layout walls).
static func route(layout: ClearingLayout, from: Vector2i, to: Vector2i) -> Array:
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		if cur == to:
			break
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cur + d
			if layout.in_bounds(n) and not layout.is_wall(n) and not prev.has(n):
				prev[n] = cur
				queue.append(n)
	if not prev.has(to):
		return []
	var path: Array = [to]
	while path.back() != from:
		path.append(prev[path.back()])
	path.reverse()
	return path