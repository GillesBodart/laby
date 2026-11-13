class_name WallEdges
extends Node2D
## Rims the tops of maze and Clearing walls where they meet open ground: an
## ink border with a sunlit lip on the top/left sides, a shaded lip on the
## right, a cast shadow on the ground to the right of a wall and at the foot
## of every wall face. Light comes from the upper left, like every sprite.
## Drawn in CHUNK x CHUNK tile blocks so off-screen blocks are culled.

const CHUNK := 16
const INK := Color8(16, 18, 22)
const LIP := Color(1, 1, 0.9, 0.22)
const SHADE := Color(0, 0, 0.04, 0.28)
## Soft contact shadow on the ground: a smooth fade over CAST_DEPTH px.
const CAST := Color(0.02, 0.02, 0.05, 0.48)
const CAST_DEPTH := 12.0

static var _fade_down: GradientTexture2D
static var _fade_right: GradientTexture2D

var layout: ClearingLayout
var _chunks: Array[Node2D] = []


static func _fade(to: Vector2) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, CAST)
	g.set_color(1, Color(CAST, 0.0))
	g.add_point(0.35, Color(CAST, CAST.a * 0.5))
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 16 if to.x > 0.0 else 1
	tex.height = 16 if to.y > 0.0 else 1
	tex.fill_to = to
	return tex


static func is_top(id: int) -> bool:
	return id == TileCatalog.Id.WALL_TOP or id == TileCatalog.Id.WALL_TOP_MOSS


static func is_face(id: int) -> bool:
	return id in [TileCatalog.Id.WALL_FACE_HIGH, TileCatalog.Id.WALL_FACE_HIGH_VINES,
		TileCatalog.Id.WALL_FACE_LOW, TileCatalog.Id.WALL_FACE_LOW_VINES]


func setup(new_layout: ClearingLayout) -> void:
	if _fade_down == null:
		_fade_down = _fade(Vector2(0, 1))
		_fade_right = _fade(Vector2(1, 0))
	layout = new_layout
	for ch in _chunks:
		ch.free()
	_chunks.clear()
	for cy in ceili(layout.size.y / float(CHUNK)):
		for cx in ceili(layout.size.x / float(CHUNK)):
			var ch := Node2D.new()
			var r := Rect2i(cx * CHUNK, cy * CHUNK, CHUNK, CHUNK)
			ch.draw.connect(_draw_chunk.bind(ch, r))
			add_child(ch)
			_chunks.append(ch)


## Redraws after walls moved (Labyrinth shifts).
func refresh() -> void:
	for ch in _chunks:
		ch.queue_redraw()


func _open(cell: Vector2i) -> bool:
	if not layout.in_bounds(cell):
		return false
	var id := layout.get_wall(cell)
	return not (is_top(id) or is_face(id))


func _draw_chunk(ci: Node2D, r: Rect2i) -> void:
	var t := float(TileCatalog.TILE_SIZE)
	for y in range(r.position.y, mini(r.end.y, layout.size.y)):
		for x in range(r.position.x, mini(r.end.x, layout.size.x)):
			var c := Vector2i(x, y)
			var id := layout.get_wall(c)
			var o := Vector2(x, y) * t
			if is_top(id):
				if _open(c + Vector2i.UP):
					ci.draw_rect(Rect2(o, Vector2(t, 1)), INK)
					ci.draw_rect(Rect2(o + Vector2(0, 1), Vector2(t, 1)), LIP)
				if _open(c + Vector2i.LEFT):
					ci.draw_rect(Rect2(o, Vector2(1, t)), INK)
					ci.draw_rect(Rect2(o + Vector2(1, 0), Vector2(1, t)), LIP)
				if _open(c + Vector2i.RIGHT):
					ci.draw_rect(Rect2(o + Vector2(t - 1, 0), Vector2(1, t)), INK)
					ci.draw_rect(Rect2(o + Vector2(t - 3, 0), Vector2(2, t)), SHADE)
					ci.draw_texture_rect(_fade_right, Rect2(o + Vector2(t, 0), Vector2(CAST_DEPTH, t)), false)
				if _open(c + Vector2i.DOWN):
					ci.draw_rect(Rect2(o + Vector2(0, t - 1), Vector2(t, 1)), INK)
			elif is_face(id):
				if _open(c + Vector2i.DOWN):
					ci.draw_texture_rect(_fade_down, Rect2(o + Vector2(0, t), Vector2(t, CAST_DEPTH)), false)
				if _open(c + Vector2i.LEFT):
					ci.draw_rect(Rect2(o, Vector2(1, t)), INK)
				if _open(c + Vector2i.RIGHT):
					ci.draw_rect(Rect2(o + Vector2(t - 1, 0), Vector2(1, t)), INK)
					ci.draw_texture_rect(_fade_right, Rect2(o + Vector2(t, 0), Vector2(CAST_DEPTH, t)), false)
