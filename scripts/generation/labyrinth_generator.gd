class_name LabyrinthGenerator
extends RefCounted
## Deterministically builds a labyrinth sector (see Sectors) from a seed: a
## perfect maze (recursive backtracker) with a few loops, a short vestibule
## at the bottom leading back south, and a guardian's arena at the top whose
## sealed gate opens north onto the next sector.
##
## The walls move: at each night start (shift = night index) a few seeded
## regions of the maze are re-carved. Each region gets a fresh spanning tree,
## so the maze stays connected. Landmarks and treasure chests never move and nothing spawns on
## them. Enemies, resources and landmarks do not depend on the shift.

const COLS := 20
const ROWS := 14
const PITCH := 5 # 3 open tiles + 2 wall tiles
const OPEN := 3
const BORDER := 3
const VESTIBULE_ROWS := 8
const LOOP_CHANCE := 0.08
const ENEMY_CHANCE := 0.14
const RESOURCE_CHANCE := 0.55
const SECOND_CHANCE := 0.2
## Resource table of the Stone sector: [node type, weight, minimum depth].
const RESOURCES: Array = Sectors.DATA.labyrinth.resources
const SAFE_RADIUS := 4 # maze cells around the entrance with no enemies
const SEED_SALT := 7919
const SECTOR_SALT := 104729
## Maze cells merged into the guardian's arena (top centre).
const ARENA := Rect2i(8, 0, 4, 2)
## Shifting regions per night and their size in maze cells.
const SHIFT_REGIONS := 3
const SHIFT_SIZE := Vector2i(4, 3)
const LANDMARK_COUNT := 5
const LANDMARK_TYPES := ["statue_angel", "statue_dragon", "statue_guardian", "statue_hero",
	"statue_sword", "statue_twins", "column", "old_engine"]
const GLYPH_COUNT := 4
## Open chambers: blocks of maze cells with their inner walls knocked down
## (breathing room, fights with space to dodge, a change from corridors).
const CHAMBERS := 3
const CHAMBER_SIZES := [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]
## Extra loops near the entrance, where the player learns the maze: fewer
## dead ends to backtrack from while lightly equipped.
const ENTRY_LOOP_RADIUS := 6
const ENTRY_LOOP_CHANCE := 0.3
## Dead ends end on a reward: a deposit from the rare end of the sector's
## table, so every wrong turn may still pay.
const CACHE_CHANCE := 0.6
const CACHE_MIN_DIST := 4
const CACHE_RARE_DEPTH := 0.2
const CACHE_SALT := 60013
## Treasure chests (one blueprint each, see Blueprints): at the back of far
## dead ends, never moving, opened once.
const CHEST_COUNT := 4
const CHEST_MIN_DIST := 7
const CHEST_SALT := 77017

const Id := TileCatalog.Id

var _rng := RandomNumberGenerator.new()
var _layout: ClearingLayout
var _solid: Dictionary = {}
var _sector := "labyrinth"
var _shift := 0
var _seed := 0
var _landmark_cells := {}
## Chest maze cells per "seed:sector" (they come from the unshifted maze).
static var _chest_cells_cache := {}


static func map_size() -> Vector2i:
	return Vector2i(COLS * PITCH + 4, ROWS * PITCH + 4 + VESTIBULE_ROWS)


static func generate(seed_value: int, sector := "labyrinth", shift := 0) -> ClearingLayout:
	var g := LabyrinthGenerator.new()
	g._sector = sector
	g._shift = shift
	return g._generate(seed_value)


## Top-left tile of a maze cell's open 3x3 area.
static func cell_origin(mc: Vector2i) -> Vector2i:
	return Vector2i(BORDER + mc.x * PITCH, BORDER + mc.y * PITCH)


func _generate(seed_value: int) -> ClearingLayout:
	_rng.seed = seed_value + SEED_SALT + Sectors.index_of(_sector) * SECTOR_SALT
	var size := map_size()
	_layout = ClearingLayout.new(size)
	for y in size.y:
		for x in size.x:
			_solid[Vector2i(x, y)] = true
			_layout.set_ground(Vector2i(x, y), Id.MAZE_FLOOR)

	_seed = seed_value
	var links := _carve_maze()
	var marks := landmarks(seed_value, _sector)
	for m in marks:
		_landmark_cells[m.mc] = true
	var entry := Vector2i(COLS / 2, ROWS - 1)
	_open_extras(entry)
	# Dead ends of the unshifted maze, so the caches never move.
	var dead_ends := _dead_ends(entry)
	_layout.shift_tiles = []
	if _shift > 0:
		for region in shift_regions(seed_value, _sector, _shift):
			_reshape(region)
			_layout.shift_tiles.append(region_tiles(region))
		_open_extras(entry)
	var o := cell_origin(entry)
	var vestibule := Rect2i(o.x, o.y + OPEN, OPEN, size.y - 3 - (o.y + OPEN))
	_carve(vestibule)
	var a0 := cell_origin(ARENA.position)
	var a1 := cell_origin(ARENA.end - Vector2i.ONE) + Vector2i(OPEN, OPEN)
	var arena := Rect2i(a0, a1 - a0)
	_carve(arena)
	var north := cell_origin(Vector2i(COLS / 2, 0))
	_carve(Rect2i(north.x, 1, OPEN, BORDER - 1))
	_layout.clearing_rect = Rect2i(o, Vector2i(OPEN, OPEN))
	_paint_ground()
	# Decoration has its own stream so the creature and resource rolls
	# below stay the same whatever the walls did.
	var deco := RandomNumberGenerator.new()
	deco.seed = _rng.seed + 1
	WallResolver.resolve(_layout, _solid, deco)

	var back := Sectors.prev_of(_sector)
	_layout.portal_rect = Rect2i(o.x, size.y - 5, OPEN, 2)
	_layout.portal_target = back
	_layout.fogged = true
	_layout.return_cell = Vector2i(o.x + 1, o.y + OPEN + 1)
	_layout.spawn_cell = _layout.return_cell
	_layout.campfire_cell = _layout.return_cell
	var forward := Sectors.next_of(_sector)
	if forward == "":
		forward = "escape"
	_layout.portals = [
		{"rect": _layout.portal_rect, "target": back},
		{"rect": Rect2i(north.x, 1, OPEN, 1), "target": forward},
	]
	_layout.arrivals = {back: _layout.return_cell, forward: Vector2i(north.x + 1, BORDER + 1)}
	var info := Sectors.info(_sector)
	var keys: Array = [info.key]
	if forward == "escape":
		keys = Sectors.ORDER.map(func(s): return Sectors.DATA[s].key)
	_layout.sector_gate = {"rect": Rect2i(north.x, BORDER - 1, OPEN, 1), "keys": keys}
	_layout.boss = {"type": info.boss, "cell": arena.get_center()}
	_layout.arena_rect = arena
	for m in marks:
		_layout.landmarks.append({"type": m.type, "cell": cell_origin(m.mc) + Vector2i(1, 1)})
	for g in glyph_spots(seed_value, _sector):
		_layout.glyphs.append({"glyph": g.glyph, "cell": cell_origin(g.mc) + Vector2i(1, 1)})
		_landmark_cells[g.mc] = true
	_place_chests(entry, dead_ends)
	_place_enemies(entry)
	_place_resources(entry)
	_place_caches(entry, dead_ends)
	return _layout


## Fixed chambers of a sector: maze-cell rects clear of the arena, the
## entrance rows and each other.
static func chambers(seed_value: int, sector: String) -> Array:
	var rng := _sector_rng(seed_value, sector, 27449)
	var out := []
	var tries := 0
	while out.size() < CHAMBERS and tries < 100:
		tries += 1
		var sz: Vector2i = CHAMBER_SIZES[rng.randi_range(0, CHAMBER_SIZES.size() - 1)]
		var r := Rect2i(Vector2i(rng.randi_range(0, COLS - sz.x), rng.randi_range(2, ROWS - 2 - sz.y)), sz)
		if r.intersects(ARENA.grow(1)) or out.any(func(o): return o.grow(1).intersects(r)):
			continue
		out.append(r)
	return out


## Chambers and entrance loops: only ever opens walls, so it can run again
## after a shift (a shift region crossing a chamber does not wall it up).
func _open_extras(entry: Vector2i) -> void:
	for r: Rect2i in chambers(_seed, _sector):
		_carve(region_tiles(r))
	var rng := _sector_rng(_seed, _sector, 8111)
	for my in ROWS:
		for mx in COLS:
			var c := Vector2i(mx, my)
			var near := absi(c.x - entry.x) + absi(c.y - entry.y) <= ENTRY_LOOP_RADIUS
			for d in [Vector2i.RIGHT, Vector2i.DOWN]:
				var roll := rng.randf()
				if near and _in_maze(c + d) and roll < ENTRY_LOOP_CHANCE:
					_link(c, c + d)


## Maze cells with a single way in (vestibule, arena and landmarks aside),
## with the direction of that way.
func _dead_ends(entry: Vector2i) -> Array:
	var out := []
	for my in ROWS:
		for mx in COLS:
			var c := Vector2i(mx, my)
			if c == entry or ARENA.has_point(c) or _landmark_cells.has(c):
				continue
			var ways: Array[Vector2i] = []
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if _in_maze(c + d) and _is_linked(c, d):
					ways.append(d)
			if ways.size() == 1:
				out.append({"mc": c, "way": ways[0]})
	return out


func _is_linked(c: Vector2i, d: Vector2i) -> bool:
	var o := cell_origin(c)
	var gap := o + Vector2i(OPEN, 0) if d == Vector2i.RIGHT else o + Vector2i(-1, 0) if d == Vector2i.LEFT \
		else o + Vector2i(0, OPEN) if d == Vector2i.DOWN else o + Vector2i(0, -1)
	return not _solid.has(gap)


## Treasure chests in the middle of far dead ends (unshifted maze, so they never
## move), spread apart. Their cells hold no creature nor ordinary deposit.
func _place_chests(entry: Vector2i, dead_ends: Array) -> void:
	var rng := _sector_rng(_seed, _sector, CHEST_SALT)
	var spots: Array = dead_ends.filter(func(de): return not _landmark_cells.has(de.mc) \
		and absi(de.mc.x - entry.x) + absi(de.mc.y - entry.y) >= CHEST_MIN_DIST)
	var picked: Array[Vector2i] = []
	while picked.size() < CHEST_COUNT and not spots.is_empty():
		var mc: Vector2i = spots.pop_at(rng.randi_range(0, spots.size() - 1)).mc
		if picked.any(func(p): return absi(p.x - mc.x) + absi(p.y - mc.y) < 4):
			continue
		picked.append(mc)
	for i in picked.size():
		_landmark_cells[picked[i]] = true
		_layout.chests.append({"id": "%s_chest_%d" % [_sector, i], "cell": cell_origin(picked[i]) + Vector2i(1, 1)})


## A rare deposit at the back wall of most dead ends (the middle tile opposite
## the way in: never in a passage, never on a cell's corner nodes). Own rng
## stream: creatures and ordinary resources roll the same as before.
func _place_caches(entry: Vector2i, dead_ends: Array) -> void:
	var rng := _sector_rng(_seed, _sector, CACHE_SALT)
	var table: Array = Sectors.info(_sector).resources.filter(func(r): return r[2] >= CACHE_RARE_DEPTH)
	for de in dead_ends:
		var mc: Vector2i = de.mc
		var roll := rng.randf()
		var pick := rng.randf()
		var dist := absi(mc.x - entry.x) + absi(mc.y - entry.y)
		if dist < CACHE_MIN_DIST or roll > CACHE_CHANCE or table.is_empty():
			continue
		var depth := dist / float(COLS + ROWS) * 1.4
		var fits: Array = table.filter(func(r): return r[2] <= depth + 0.3)
		if fits.is_empty():
			fits = [table.reduce(func(a, b): return a if a[2] <= b[2] else b)]
		var total := 0.0
		for r in fits:
			total += r[1]
		var x := pick * total
		var type: String = fits[-1][0]
		for r in fits:
			x -= r[1]
			if x <= 0.0:
				type = r[0]
				break
		_layout.props.append({"type": type, "cell": cell_origin(mc) + Vector2i.ONE - Vector2i(de.way)})


func _place_enemies(entry: Vector2i) -> void:
	var max_dist := float(COLS + ROWS)
	for my in ROWS:
		for mx in COLS:
			var mc := Vector2i(mx, my)
			var dist := absi(mc.x - entry.x) + absi(mc.y - entry.y)
			var roll := _rng.randf()
			if dist <= SAFE_RADIUS or roll > ENEMY_CHANCE or ARENA.has_point(mc) or _landmark_cells.has(mc):
				continue
			var type := EnemyCatalog.pick(_sector, dist / max_dist * 1.4, _rng.randf())
			var o := cell_origin(mc)
			_layout.enemy_spawns.append({"type": type, "cell": o + Vector2i(1, 1)})


## Resource nodes sit in the corners of maze cells (never blocking passages);
## richer deposits lie deeper in the maze.
func _place_resources(entry: Vector2i) -> void:
	var max_dist := float(COLS + ROWS)
	var corners := [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]
	for my in ROWS:
		for mx in COLS:
			var mc := Vector2i(mx, my)
			var dist := absi(mc.x - entry.x) + absi(mc.y - entry.y)
			var depth := dist / max_dist * 1.4
			var first := _rng.randi_range(0, 3)
			var rolls := [_rng.randf(), _rng.randf()]
			if dist <= 1 or ARENA.has_point(mc) or _landmark_cells.has(mc):
				continue
			for k in 2:
				if rolls[k] > (RESOURCE_CHANCE if k == 0 else SECOND_CHANCE):
					continue
				var cell: Vector2i = cell_origin(mc) + corners[(first + k * 2) % 4]
				_layout.props.append({"type": _pick_resource(depth), "cell": cell})


func _pick_resource(depth: float) -> String:
	var table: Array = Sectors.info(_sector).resources
	var total := 0.0
	for r in table:
		if depth >= r[2]:
			total += r[1]
	var x := _rng.randf() * total
	for r in table:
		if depth >= r[2]:
			x -= r[1]
			if x <= 0.0:
				return r[0]
	return table[0][0]

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


func _link(a: Vector2i, b: Vector2i, close := false) -> void:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var o := cell_origin(lo)
	var rect := Rect2i(o.x + OPEN, o.y, PITCH - OPEN, OPEN) if a.x != b.x else Rect2i(o.x, o.y + OPEN, OPEN, PITCH - OPEN)
	if close:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				_solid[Vector2i(x, y)] = true
	else:
		_carve(rect)


func _paint_ground() -> void:
	for y in _layout.size.y:
		for x in _layout.size.x:
			var cell := Vector2i(x, y)
			if not _solid.has(cell) and _cell_noise(cell) < Sectors.info(_sector).moss:
				_layout.set_ground(cell, Id.MAZE_FLOOR_MOSS)

func _cell_noise(cell: Vector2i) -> float:
	return float(absi(hash(Vector3i(cell.x, cell.y, _seed))) % 10000) / 10000.0


static func _sector_rng(seed_value: int, sector: String, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + salt + Sectors.index_of(sector) * SECTOR_SALT
	return rng


## Fixed landmarks of a sector: [{type, mc (maze cell)}], spread out at
## mid-depth, away from the entrance and the arena.
static func landmarks(seed_value: int, sector: String) -> Array:
	var rng := _sector_rng(seed_value, sector, 31337)
	var types := LANDMARK_TYPES.duplicate()
	var out := []
	var tries := 0
	while out.size() < LANDMARK_COUNT and tries < 200:
		tries += 1
		var mc := Vector2i(rng.randi_range(0, COLS - 1), rng.randi_range(2, ROWS - 3))
		if out.any(func(m): return absi(m.mc.x - mc.x) + absi(m.mc.y - mc.y) < 5):
			continue
		var t: String = types.pop_at(rng.randi_range(0, types.size() - 1))
		out.append({"type": t, "mc": mc})
	return out


## Glyph stones: [{glyph, mc}] in dead-quiet corners of the maze (never on a
## landmark). The glyph ids index Glyphs.DATA.
static func glyph_spots(seed_value: int, sector: String) -> Array:
	var rng := _sector_rng(seed_value, sector, 51551)
	var taken := {}
	for m in landmarks(seed_value, sector):
		taken[m.mc] = true
	var out := []
	var tries := 0
	while out.size() < GLYPH_COUNT and tries < 200:
		tries += 1
		var mc := Vector2i(rng.randi_range(0, COLS - 1), rng.randi_range(1, ROWS - 3))
		if taken.has(mc) or ARENA.has_point(mc):
			continue
		taken[mc] = true
		out.append({"glyph": "%s_%d" % [sector, out.size()], "mc": mc})
	return out


## Maze-cell rects re-carved at a shift (night index), never holding a
## landmark nor touching the entrance rows or the arena.
static func shift_regions(seed_value: int, sector: String, shift: int) -> Array:
	if shift <= 0:
		return []
	var rng := _sector_rng(seed_value + shift * 7907, sector, 99991)
	var fixed := landmarks(seed_value, sector).map(func(m): return m.mc) + chest_cells(seed_value, sector)
	var out := []
	var tries := 0
	while out.size() < SHIFT_REGIONS and tries < 100:
		tries += 1
		var r := Rect2i(Vector2i(rng.randi_range(0, COLS - SHIFT_SIZE.x), rng.randi_range(2, ROWS - 2 - SHIFT_SIZE.y)), SHIFT_SIZE)
		if out.any(func(o): return o.grow(1).intersects(r)) or fixed.any(func(mc): return r.has_point(mc)):
			continue
		out.append(r)
	return out


## Maze cells of the sector's treasure chests. They are picked in the
## unshifted maze, so they never move and the shifting regions avoid them.
static func chest_cells(seed_value: int, sector: String) -> Array:
	var key := "%d:%s" % [seed_value, sector]
	if not _chest_cells_cache.has(key):
		_chest_cells_cache[key] = generate(seed_value, sector, 0).chests.map(
			func(c): return (c.cell - Vector2i(BORDER + 1, BORDER + 1)) / PITCH)
	return _chest_cells_cache[key]


## Tiles covered by a region of maze cells (cells plus the walls between them).
static func region_tiles(region: Rect2i) -> Rect2i:
	var a := cell_origin(region.position)
	var b := cell_origin(region.end - Vector2i.ONE) + Vector2i(OPEN, OPEN)
	return Rect2i(a, b - a)


## Closes every passage inside the region, then carves a new spanning tree
## (plus a loop) through it. Passages crossing the border are kept, so every
## path that went through the region still does.
func _reshape(region: Rect2i) -> void:
	var rng := _sector_rng(_seed + _shift * 7907 + region.position.x * 31 + region.position.y, _sector, 4441)
	for my in range(region.position.y, region.end.y):
		for mx in range(region.position.x, region.end.x):
			var c := Vector2i(mx, my)
			for d in [Vector2i.RIGHT, Vector2i.DOWN]:
				if region.has_point(c + d):
					_link(c, c + d, true)
	var visited := {region.position: true}
	var stack: Array[Vector2i] = [region.position]
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cur + d
			if region.has_point(n) and not visited.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		_link(cur, next)
		visited[next] = true
		stack.append(next)
	var c := region.position + Vector2i(rng.randi_range(0, region.size.x - 2), rng.randi_range(0, region.size.y - 1))
	_link(c, c + Vector2i.RIGHT)
