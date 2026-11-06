class_name LabyrinthGenerator
extends RefCounted
## Deterministically builds the first labyrinth sector (Stone biome) from a
## seed: a perfect maze (recursive backtracker) with a few loops and a short
## vestibule at the bottom leading back to the Clearing.

const COLS := 20
const ROWS := 14
const PITCH := 5 # 3 open tiles + 2 wall tiles
const OPEN := 3
const BORDER := 3
const VESTIBULE_ROWS := 8
const LOOP_CHANCE := 0.08
const ENEMY_CHANCE := 0.09
const ORE_CHANCE := 0.3
const SAFE_RADIUS := 4 # maze cells around the entrance with no enemies
const SEED_SALT := 7919

const Id := TileCatalog.Id

var _rng := RandomNumberGenerator.new()
var _layout: ClearingLayout
var _solid: Dictionary = {}


static func map_size() -> Vector2i:
	return Vector2i(COLS * PITCH + 4, ROWS * PITCH + 4 + VESTIBULE_ROWS)


static func generate(seed_value: int) -> ClearingLayout:
	return LabyrinthGenerator.new()._generate(seed_value)


## Top-left tile of a maze cell's open 3x3 area.
static func cell_origin(mc: Vector2i) -> Vector2i:
	return Vector2i(BORDER + mc.x * PITCH, BORDER + mc.y * PITCH)


func _generate(seed_value: int) -> ClearingLayout:
	_rng.seed = seed_value + SEED_SALT
	var size := map_size()
	_layout = ClearingLayout.new(size)
	for y in size.y:
		for x in size.x:
			_solid[Vector2i(x, y)] = true
			_layout.set_ground(Vector2i(x, y), Id.MAZE_FLOOR)

	var links := _carve_maze()
	var entry := Vector2i(COLS / 2, ROWS - 1)
	var o := cell_origin(entry)
	var vestibule := Rect2i(o.x, o.y + OPEN, OPEN, size.y - 3 - (o.y + OPEN))
	_carve(vestibule)
	_layout.clearing_rect = Rect2i(o, Vector2i(OPEN, OPEN))
	_paint_ground()
	WallResolver.resolve(_layout, _solid, _rng)

	_layout.portal_rect = Rect2i(o.x, size.y - 5, OPEN, 2)
	_layout.portal_target = "clearing"
	_layout.fogged = true
	_layout.return_cell = Vector2i(o.x + 1, o.y + OPEN + 1)
	_layout.spawn_cell = _layout.return_cell
	_layout.campfire_cell = _layout.return_cell
	_place_enemies(entry)
	_place_resources(entry)
	return _layout


func _place_enemies(entry: Vector2i) -> void:
	var max_dist := float(COLS + ROWS)
	for my in ROWS:
		for mx in COLS:
			var mc := Vector2i(mx, my)
			var dist := absi(mc.x - entry.x) + absi(mc.y - entry.y)
			var roll := _rng.randf()
			if dist <= SAFE_RADIUS or roll > ENEMY_CHANCE:
				continue
			var type := EnemyCatalog.type_for_depth(dist / max_dist * 1.4, _rng.randf())
			var o := cell_origin(mc)
			_layout.enemy_spawns.append({"type": type, "cell": o + Vector2i(1, 1)})


## Ore deposits sit in the corners of maze cells (never blocking passages);
## richer ores lie deeper in the maze.
func _place_resources(entry: Vector2i) -> void:
	var max_dist := float(COLS + ROWS)
	var corners := [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]
	for my in ROWS:
		for mx in COLS:
			var mc := Vector2i(mx, my)
			var dist := absi(mc.x - entry.x) + absi(mc.y - entry.y)
			var depth := dist / max_dist * 1.4
			var roll := _rng.randf()
			var cell: Vector2i = cell_origin(mc) + corners[_rng.randi_range(0, 3)]
			if dist <= 1:
				continue
			if roll < ORE_CHANCE:
				var kind := _rng.randf()
				var type := "ore_coal" if kind < 0.5 else "ore_copper"
				if depth > 0.8 and kind > 0.88:
					type = "ore_crystal"
				elif depth > 0.4 and kind > 0.6:
					type = "ore_iron"
				_layout.props.append({"type": type, "cell": cell})
			elif roll < ORE_CHANCE + 0.12:
				_layout.props.append({"type": "grass", "cell": cell})
			elif roll < ORE_CHANCE + 0.18:
				_layout.props.append({"type": "mushroom", "cell": cell})


func _carve(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_solid.erase(Vector2i(x, y))


## Carves every maze cell and the passages between them.
## Returns the list of linked cell pairs.
func _carve_maze() -> Array:
	for my in ROWS:
		for mx in COLS:
			_carve(Rect2i(cell_origin(Vector2i(mx, my)), Vector2i(OPEN, OPEN)))
	var links: Array = []
	var visited := {Vector2i.ZERO: true}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cur + d
			if _in_maze(n) and not visited.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = options[_rng.randi_range(0, options.size() - 1)]
		_link(cur, next)
		links.append([cur, next])
		visited[next] = true
		stack.append(next)
	# Loops make the maze less of a perfect tree.
	for my in ROWS:
		for mx in COLS:
			var c := Vector2i(mx, my)
			for d in [Vector2i.RIGHT, Vector2i.DOWN]:
				if _in_maze(c + d) and _rng.randf() < LOOP_CHANCE:
					_link(c, c + d)
					links.append([c, c + d])
	return links


func _in_maze(mc: Vector2i) -> bool:
	return mc.x >= 0 and mc.y >= 0 and mc.x < COLS and mc.y < ROWS


func _link(a: Vector2i, b: Vector2i) -> void:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var o := cell_origin(lo)
	if a.x != b.x:
		_carve(Rect2i(o.x + OPEN, o.y, PITCH - OPEN, OPEN))
	else:
		_carve(Rect2i(o.x, o.y + OPEN, OPEN, PITCH - OPEN))


func _paint_ground() -> void:
	for y in _layout.size.y:
		for x in _layout.size.x:
			var cell := Vector2i(x, y)
			if not _solid.has(cell) and _rng.randf() < 0.18:
				_layout.set_ground(cell, Id.MAZE_FLOOR_MOSS)
