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

var _font: Font
var _texture: ImageTexture
var _image: Image
var _timer := 0.0


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2.ZERO
	size = SIZE
	_font = ThemeDB.fallback_font


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
	var scale := minf(FRAME.size.x / world.layout.size.x, FRAME.size.y / world.layout.size.y)
	var map_size := Vector2(world.layout.size) * scale
	var origin := FRAME.position + (FRAME.size - map_size) / 2.0
	draw_rect(Rect2(origin - Vector2(2, 2), map_size + Vector2(4, 4)), EDGE, false, 2.0)
	draw_texture_rect(_texture, Rect2(origin, map_size), false)
	for portal_def in world.layout.all_portals():
		var portal := Rect2(origin + Vector2(portal_def.rect.position) * scale, Vector2(portal_def.rect.size) * scale)
		draw_rect(portal, Color8(120, 220, 120), false, 1.0)
	if not world.layout.boss.is_empty() and world.fog != null and world.fog.is_explored(world.layout.boss.cell):
		var bp := origin + (Vector2(world.layout.boss.cell) + Vector2(0.5, 0.5)) * scale
		var dead := GameState.bosses_defeated.has(world.layout.boss.type)
		draw_rect(Rect2(bp - Vector2(3, 3), Vector2(6, 6)), Color8(120, 120, 120) if dead else Color8(190, 90, 230))
		draw_rect(Rect2(bp - Vector2(3, 3), Vector2(6, 6)), INK, false, 1.0)
	var blink := int(Time.get_ticks_msec() / 400) % 2 == 0
	for player in GameState.players.values():
		var c := world.clearing.walls.local_to_map(world.clearing.walls.to_local(player.global_position))
		var p := origin + (Vector2(c) + Vector2(0.5, 0.5)) * scale
		draw_circle(p, 3.0, INK)
		draw_circle(p, 2.0, Color.WHITE if blink else Color8(230, 70, 70))
	var footer := "[M] close"
	if world.fog != null:
		footer = "Explored %d%%    [M] close" % int(world.fog.explored_fraction() * 100.0)
	draw_string(_font, Vector2(24, 266), footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_LIGHT)
