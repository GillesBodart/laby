class_name LabyrinthGenerator
extends RefCounted
## Deterministically builds a labyrinth sector (see Sectors) from a seed: a
## maze (recursive backtracker) shaped by the sector's "maze" data (size,
## loops, chambers...), a short vestibule at the bottom leading back south,
## and a guardian's arena at the top, reached through a single south door,
## whose sealed gate opens north onto the next sector. Each sector adds its
## own rule ("signature"): thorn curtains, oases, warming braziers, vents.
##
## The walls move: at each night start (shift = night index) a few seeded
## regions of the maze are re-carved and some passages crossing their border
## close. A reachability check reopens closed passages until every cell and
## the arena door can be reached again, so a shift threatens routes but never
## seals anything off. Landmarks, glyph stones and treasure chests never move
## and nothing spawns on them. Enemies, resources and landmarks do not depend
## on the shift.

const PITCH := 5 # 3 open tiles + 2 wall tiles
const OPEN := 3
const BORDER := 3
const VESTIBULE_ROWS := 8
const RESOURCE_CHANCE := 0.55
const SECOND_CHANCE := 0.2
const SAFE_RADIUS := 4 # maze cells around the entrance with no enemies
const SEED_SALT := 7919
const SECTOR_SALT := 104729
## Maze cells merged into the guardian's arena (top centre, see arena()).
const ARENA_SIZE := Vector2i(4, 3)
## One-tile pillars in the arena (tile offsets from its top-left corner): cover
## at the crossings of the old cell walls, clear of the door-to-boss lane.
const ARENA_PILLARS := [Vector2i(3, 3), Vector2i(14, 3), Vector2i(3, 9), Vector2i(14, 9)]
## Shifting regions (count per sector in its maze data), their size in maze
## cells, and the chance for each passage crossing their border to close.
const SHIFT_SIZE := Vector2i(4, 3)
const SHIFT_CLOSE_CHANCE := 0.35
const LANDMARK_COUNT := 5
## Landmarks found in every sector (plus the sector's own two, see Sectors).
const SHARED_LANDMARKS := ["column", "statue_guardian", "old_engine"]
const LANDMARK_SPACING := 5
const GLYPH_COUNT := 4
## Open chambers: blocks of maze cells with their inner walls knocked down
## (breathing room, fights with space to dodge, a change from corridors).
const CHAMBER_SIZES := [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]
const BIG_CHAMBER := Vector2i(3, 3)
## Oases (Sunken Dunes): open 3x3-cell sinks around a pool.
const OASIS_SIZE := Vector2i(3, 3)
## Extra loops near the entrance, where the player learns the maze: fewer
## dead ends to backtrack from while lightly equipped.
const ENTRY_LOOP_RADIUS := 6
## Dead ends end on a reward: a deposit from the rare end of the sector's
## table, so every wrong turn may still pay.
const CACHE_CHANCE := 0.6
const CACHE_MIN_DIST := 4
const CACHE_RARE_DEPTH := 0.2
const CACHE_SALT := 60013
## Treasure chests (one blueprint each, see Blueprints): at the back of far
## dead ends, never moving, opened once. A guard waits at the way in.
const CHEST_COUNT := 4
const CHEST_MIN_DIST := 7
const CHEST_SALT := 77017
const GUARD_SALT := 45127
const GUARD_DEPTH := 0.2
const ELITE_DENS := 2
const ELITE_SALT := 31337
const SIGNATURE_SALT := 70001
## Thorn curtain props: across a vertical passage / a horizontal one.
const CURTAIN := "thorn_curtain"
const CURTAIN_V := "thorn_curtain_v"
const VENT := "magma_vent"

const Id := TileCatalog.Id
const DIRS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var _rng := RandomNumberGenerator.new()
var _layout: ClearingLayout
var _solid: Dictionary = {}
var _sector := "labyrinth"
var _maze: Dictionary
var _cols := 0
var _rows := 0
var _arena: Rect2i
var _entry: Vector2i
var _door: Vector2i
var _shift := 0
var _seed := 0
## Maze cells holding a landmark, glyph stone or chest (nothing spawns there).
var _landmark_cells := {}
## Maze cells kept calm: no creature, no ordinary deposit (rest spots, oases).
var _quiet := {}
var _oases: Array = []
var _chest_spots: Array = []
## Path distance (in maze cells) from the entrance in the unshifted maze, and
## the length of the way to the arena door: depth 1.0 is the guardian's door.
var _cell_dist := {}
var _parent := {}
var _route_len := 1.0
## Facts of the unshifted maze per "seed:sector" (landmarks, glyphs, chests).
static var _base_cache := {}


static func cols(sector := "labyrinth") -> int:
	return Sectors.maze(sector).cols


static func rows(sector := "labyrinth") -> int:
	return Sectors.maze(sector).rows


static func map_size(sector := "labyrinth") -> Vector2i:
	return Vector2i(cols(sector) * PITCH + 4, rows(sector) * PITCH + 4 + VESTIBULE_ROWS)


## Maze cell above the vestibule.
static func entry_cell(sector := "labyrinth") -> Vector2i:
	return Vector2i(cols(sector) / 2, rows(sector) - 1)


## Maze cells of the guardian's arena: centred at the top, ARENA_SIZE wide.
static func arena(sector := "labyrinth") -> Rect2i:
	return Rect2i(Vector2i(cols(sector) / 2 - ARENA_SIZE.x / 2, 0), ARENA_SIZE)


## The single way into the arena: the cell south of its centre.
static func door_cell(sector := "labyrinth") -> Vector2i:
	return Vector2i(cols(sector) / 2, ARENA_SIZE.y)


static func generate(seed_value: int, sector := "labyrinth", shift := 0) -> ClearingLayout:
	var g := LabyrinthGenerator.new()
	g._sector = sector
	g._shift = shift
	return g._generate(seed_value)


## Top-left tile of a maze cell's open 3x3 area.
static func cell_origin(mc: Vector2i) -> Vector2i:
	return Vector2i(BORDER + mc.x * PITCH, BORDER + mc.y * PITCH)


## Maze cell holding a tile (walls between cells count with the cell above/left).
static func cell_of(tile: Vector2i) -> Vector2i:
	return Vector2i(floori((tile.x - BORDER) / float(PITCH)), floori((tile.y - BORDER) / float(PITCH)))


func _generate(seed_value: int) -> ClearingLayout:
	_seed = seed_value
	_maze = Sectors.maze(_sector)
	_cols = _maze.cols
	_rows = _maze.rows
	_arena = arena(_sector)
	_entry = entry_cell(_sector)
	_door = door_cell(_sector)
	_rng.seed = seed_value + SEED_SALT + Sectors.index_of(_sector) * SECTOR_SALT
	var size := map_size(_sector)
	_layout = ClearingLayout.new(size)
	for y in size.y:
		for x in size.x:
			_solid[Vector2i(x, y)] = true
			_layout.set_ground(Vector2i(x, y), Id.MAZE_FLOOR)

	_oases = oases(seed_value, _sector)
	_carve_maze()
	_seal_arena()
	_open_extras()
	_measure_depth()
	# Facts of the unshifted maze, so nothing fixed ever moves.
	var dead_ends := _dead_ends()
	_place_landmarks()
	_place_glyphs()
	_place_chests(dead_ends)
	_place_signature()
	_store_base()
	_layout.shift_tiles = []
	if _shift > 0:
		var regions := shift_regions(seed_value, _sector, _shift)
		var closed: Array = []
		for region in regions:
			_reshape(region)
			# The border passages may close too: the rect covers them.
			_layout.shift_tiles.append(region_tiles(region).grow(PITCH - OPEN))
		for region in regions:
			closed.append_array(_close_border(region))
		_open_extras()
		_restore_reach(closed)
		_lengthen_route(regions)
	var o := cell_origin(_entry)
	var vestibule := Rect2i(o.x, o.y + OPEN, OPEN, size.y - 3 - (o.y + OPEN))
	_carve(vestibule)
	var arena_tiles := region_tiles(_arena)
	for p in ARENA_PILLARS:
		_solid[arena_tiles.position + p] = true
	var north := cell_origin(Vector2i(_cols / 2, 0))
	_carve(Rect2i(north.x, 1, OPEN, BORDER - 1))
	_layout.clearing_rect = Rect2i(o, Vector2i(OPEN, OPEN))
	_paint_ground()
	_paint_oases()
	# Decoration has its own stream so the creature and resource rolls
	# below stay the same whatever the walls did.
	var deco := RandomNumberGenerator.new()
	deco.seed = _rng.seed + 1
	var info := Sectors.info(_sector)
	WallResolver.resolve(_layout, _solid, deco, info.art.vines, info.art.top_alt)

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
	var keys: Array = [info.key]
	if forward == "escape":
		keys = Sectors.ORDER.map(func(s): return Sectors.DATA[s].key)
	_layout.sector_gate = {"rect": Rect2i(north.x, BORDER - 1, OPEN, 1), "keys": keys}
	_layout.boss = {"type": info.boss, "cell": arena_tiles.get_center()}
	_layout.arena_rect = arena_tiles
	# Havens: a fire in the vestibule (beside the waystone's lane) and one at
	# the arena door, a last rest before the guardian. Night creatures shun them.
	_layout.props.append({"type": "campfire", "cell": Vector2i(o.x + 2, _layout.return_cell.y + 1)})
	_layout.props.append({"type": "campfire", "cell": cell_origin(_door) + Vector2i(0, OPEN - 1)})
	_place_enemies(dead_ends)
	_place_resources()
	_place_caches(dead_ends)
	_drop_buried()
	return _layout


## Fixed chambers of a sector: maze-cell rects clear of the arena, the
## entrance rows and each other.
static func chambers(seed_value: int, sector: String) -> Array:
	var m := Sectors.maze(sector)
	var sizes: Array = CHAMBER_SIZES + ([BIG_CHAMBER] if m.get("big_chambers", false) else [])
	var rng := _sector_rng(seed_value, sector, 27449)
	var keep_out := arena(sector).grow(1)
	var out := []
	var tries := 0
	while out.size() < m.chambers and tries < 200:
		tries += 1
		var sz: Vector2i = sizes[rng.randi_range(0, sizes.size() - 1)]
		var r := Rect2i(Vector2i(rng.randi_range(0, m.cols - sz.x), rng.randi_range(2, m.rows - 2 - sz.y)), sz)
		if r.intersects(keep_out) or out.any(func(o): return o.grow(1).intersects(r)):
			continue
		out.append(r)
	return out


## Oases of a sector (signature "oases"): open sinks clear of the chambers.
static func oases(seed_value: int, sector: String) -> Array:
	var sig: Dictionary = Sectors.info(sector).get("signature", {})
	if not sig.has("oases"):
		return []
	var m := Sectors.maze(sector)
	var rng := _sector_rng(seed_value, sector, 64007)
	var want := rng.randi_range(sig.oases[0], sig.oases[1])
	var taken: Array = chambers(seed_value, sector) + [arena(sector)]
	var out := []
	var tries := 0
	while out.size() < want and tries < 300:
		tries += 1
		var r := Rect2i(Vector2i(rng.randi_range(0, m.cols - OASIS_SIZE.x), rng.randi_range(2, m.rows - 3 - OASIS_SIZE.y)), OASIS_SIZE)
		if (taken + out).any(func(o): return o.grow(1).intersects(r)):
			continue
		out.append(r)
	return out


func _in_rooms(mc: Vector2i) -> bool:
	for r in chambers(_seed, _sector) + _oases:
		if r.has_point(mc):
			return true
	return false


func _in_oasis(mc: Vector2i) -> bool:
	return _oases.any(func(r): return r.has_point(mc))


## Chambers, oases and entrance loops: only ever opens walls, so it can run
## again after a shift (a shift region crossing a chamber does not wall it up).
func _open_extras() -> void:
	for r: Rect2i in chambers(_seed, _sector) + _oases:
		_carve(region_tiles(r))
	var rng := _sector_rng(_seed, _sector, 8111)
	var chance: float = _maze.entry_loops
	for my in _rows:
		for mx in _cols:
			var c := Vector2i(mx, my)
			var near := absi(c.x - _entry.x) + absi(c.y - _entry.y) <= ENTRY_LOOP_RADIUS
			for d in [Vector2i.RIGHT, Vector2i.DOWN]:
				var roll := rng.randf()
				if near and _in_maze(c + d) and roll < chance and not _arena.has_point(c) and not _arena.has_point(c + d):
					_link(c, c + d)


## The arena keeps a single way in (the door from the south): every other
## passage into it closes, and cells cut off that way are linked back to
## the rest of the maze.
func _seal_arena() -> void:
	_carve(region_tiles(_arena))
	for my in range(_arena.position.y, _arena.end.y):
		for mx in range(_arena.position.x, _arena.end.x):
			var c := Vector2i(mx, my)
			for d in DIRS:
				var n: Vector2i = c + d
				if _in_maze(n) and not _arena.has_point(n):
					_link(c, n, n != _door)
	while true:
		var seen := _reach()
		if seen.size() >= _cols * _rows:
			return
		var linked := false
		for my in _rows:
			for mx in _cols:
				var c := Vector2i(mx, my)
				if linked or seen.has(c) or _arena.has_point(c):
					continue
				for d in DIRS:
					var n: Vector2i = c + d
					if _in_maze(n) and seen.has(n) and not _arena.has_point(n):
						_link(c, n)
						linked = true
						break
		if not linked:
			return


## Maze cells reachable from the entrance through open passages.
func _reach() -> Dictionary:
	var seen := {_entry: true}
	var queue: Array[Vector2i] = [_entry]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in DIRS:
			var n: Vector2i = c + d
			if _in_maze(n) and not seen.has(n) and _is_linked(c, d):
				seen[n] = true
				queue.append(n)
	return seen


## Maze cells with a single way in (vestibule, arena and landmarks aside),
## with the direction of that way.
func _dead_ends() -> Array:
	var out := []
	for my in _rows:
		for mx in _cols:
			var c := Vector2i(mx, my)
			if c == _entry or _arena.has_point(c) or _landmark_cells.has(c):
				continue
			var ways := _ways(c)
			if ways.size() == 1:
				out.append({"mc": c, "way": ways[0]})
	return out


func _ways(c: Vector2i) -> Array[Vector2i]:
	var ways: Array[Vector2i] = []
	for d in DIRS:
		if _in_maze(c + d) and _is_linked(c, d):
			ways.append(d)
	return ways


func _is_linked(c: Vector2i, d: Vector2i) -> bool:
	var o := cell_origin(c)
	var gap := o + Vector2i(OPEN, 0) if d == Vector2i.RIGHT else o + Vector2i(-1, 0) if d == Vector2i.LEFT \
		else o + Vector2i(0, OPEN) if d == Vector2i.DOWN else o + Vector2i(0, -1)
	return not _solid.has(gap)


## Landmarks stand where the player has to choose: one in the middle of each
## chamber, the others on junctions (three ways or more), spread apart.
func _place_landmarks() -> void:
	var rng := _sector_rng(_seed, _sector, 31337)
	var types: Array = SHARED_LANDMARKS + Sectors.info(_sector).landmarks
	_shuffle(types, rng)
	var spots := []
	for r: Rect2i in chambers(_seed, _sector):
		var tile := region_tiles(r).position + region_tiles(r).size / 2
		spots.append({"mc": cell_of(tile), "cell": tile})
	spots.resize(mini(spots.size(), LANDMARK_COUNT))
	var junctions := []
	for my in _rows:
		for mx in _cols:
			var c := Vector2i(mx, my)
			if _ways(c).size() >= 3 and not _arena.grow(1).has_point(c) and not _in_rooms(c) \
					and absi(c.x - _entry.x) + absi(c.y - _entry.y) >= 3:
				junctions.append(c)
	_shuffle(junctions, rng)
	var spacing := LANDMARK_SPACING
	while spots.size() < LANDMARK_COUNT and spacing > 0:
		for c in junctions:
			if spots.size() >= LANDMARK_COUNT:
				break
			if spots.any(func(s): return absi(s.mc.x - c.x) + absi(s.mc.y - c.y) < spacing):
				continue
			spots.append({"mc": c, "cell": cell_origin(c) + Vector2i.ONE})
		spacing -= 1
	for i in spots.size():
		_landmark_cells[spots[i].mc] = true
		_layout.landmarks.append({"type": types[i % types.size()], "cell": spots[i].cell, "mc": spots[i].mc})


## Glyph stones: the glyph ids index Glyphs.DATA and follow depth in row bands
## scaled to the maze: the shift stone near the entrance, the route stone on
## the way in (both closer than the arena), the deeper ones towards it.
func _place_glyphs() -> void:
	var rng := _sector_rng(_seed, _sector, 51551)
	var f := _rows / 14.0
	var bands := [Vector2i(roundi(_rows * 9 / 14.0), roundi(_rows * 11 / 14.0)),
		Vector2i(roundi(_rows * 7 / 14.0), roundi(_rows * 10 / 14.0)),
		Vector2i(3, roundi(_rows * 7 / 14.0)), Vector2i(1, roundi(_rows * 4 / 14.0))]
	var near := roundi(8 * f)
	for i in GLYPH_COUNT:
		var band: Vector2i = bands[i]
		var spot := Vector2i(-1, -1)
		for tries in 600:
			var mc := Vector2i(rng.randi_range(0, _cols - 1), rng.randi_range(band.x, band.y))
			if tries >= 400:
				mc = Vector2i(rng.randi_range(0, _cols - 1), rng.randi_range(1, _rows - 1))
			if _landmark_cells.has(mc) or _arena.grow(1).has_point(mc) or _in_oasis(mc) or mc == _entry:
				continue
			if i <= 1 and _cell_dist.get(mc, 1 << 20) >= _route_len:
				continue
			if i == 1 and tries < 200 and absi(mc.x - _entry.x) + absi(mc.y - _entry.y) > near:
				continue
			spot = mc
			break
		if spot.x < 0:
			continue
		_landmark_cells[spot] = true
		_layout.glyphs.append({"glyph": "%s_%d" % [_sector, i], "cell": cell_origin(spot) + Vector2i.ONE, "mc": spot})


## Treasure chests in the middle of far dead ends (unshifted maze, so they never
## move), spread apart. Their cells hold no creature nor ordinary deposit.
func _place_chests(dead_ends: Array) -> void:
	var rng := _sector_rng(_seed, _sector, CHEST_SALT)
	var spots: Array = dead_ends.filter(func(de): return not _landmark_cells.has(de.mc) and not _in_rooms(de.mc) \
		and absi(de.mc.x - _entry.x) + absi(de.mc.y - _entry.y) >= CHEST_MIN_DIST)
	while _chest_spots.size() < CHEST_COUNT and not spots.is_empty():
		var de: Dictionary = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		if _chest_spots.any(func(p): return absi(p.mc.x - de.mc.x) + absi(p.mc.y - de.mc.y) < 4):
			continue
		_chest_spots.append(de)
	for i in _chest_spots.size():
		var mc: Vector2i = _chest_spots[i].mc
		_landmark_cells[mc] = true
		_layout.chests.append({"id": "%s_chest_%d" % [_sector, i], "cell": cell_origin(mc) + Vector2i.ONE})


## The sector's own rule (Sectors "signature"), laid on the unshifted maze.
func _place_signature() -> void:
	var sig: Dictionary = Sectors.info(_sector).get("signature", {})
	var rng := _sector_rng(_seed, _sector, SIGNATURE_SALT)
	if sig.has("thorn_curtains"):
		_place_curtains(rng, rng.randi_range(sig.thorn_curtains[0], sig.thorn_curtains[1]))
	if sig.has("braziers"):
		_place_braziers(rng, sig.braziers)
	if sig.has("vents"):
		_place_vents(rng, rng.randi_range(sig.vents[0], sig.vents[1]))
	for r: Rect2i in _oases:
		for my in range(r.position.y, r.end.y):
			for mx in range(r.position.x, r.end.x):
				_quiet[Vector2i(mx, my)] = true
		var c := region_tiles(r).get_center()
		for off in [Vector2i(-2, -2), Vector2i(2, 2)]:
			_layout.props.append({"type": "date_palm", "cell": c + off})
		for off in [Vector2i(6, -6), Vector2i(-6, 6), Vector2i(-6, -5)]:
			_layout.props.append({"type": "cactus", "cell": c + off})


## Open passages between two ordinary cells (no arena, chamber nor oasis).
func _passages() -> Array:
	var out := []
	for my in _rows:
		for mx in _cols:
			var c := Vector2i(mx, my)
			for d in [Vector2i.RIGHT, Vector2i.DOWN]:
				var n: Vector2i = c + d
				if not _in_maze(n) or not _is_linked(c, d):
					continue
				if _arena.grow(1).has_point(c) or _arena.grow(1).has_point(n) or _in_rooms(c) or _in_rooms(n):
					continue
				out.append([c, n])
	return out


## Thorn curtains close side passages: never one on the shortest ways from the
## entrance to the arena door or to a chest. An axe cuts them.
func _place_curtains(rng: RandomNumberGenerator, count: int) -> void:
	var critical := {}
	for target in [_door] + _chest_spots.map(func(s): return s.mc):
		var c: Vector2i = target
		while _parent.has(c):
			var p: Vector2i = _parent[c]
			critical[[mini(c.x, p.x), mini(c.y, p.y), c.x != p.x]] = true
			c = p
	var options := _passages().filter(func(pair): return not critical.has(
		[mini(pair[0].x, pair[1].x), mini(pair[0].y, pair[1].y), pair[0].x != pair[1].x]))
	_shuffle(options, rng)
	for i in mini(count, options.size()):
		var a: Vector2i = options[i][0]
		var b: Vector2i = options[i][1]
		var o := cell_origin(a)
		if a.x != b.x:
			_layout.props.append({"type": CURTAIN_V, "cell": o + Vector2i(OPEN, 1)})
		else:
			_layout.props.append({"type": CURTAIN, "cell": o + Vector2i(1, OPEN)})


## Warming fires on junctions of the cold halls, spread apart, in a cell corner.
func _place_braziers(rng: RandomNumberGenerator, count: int) -> void:
	var options := []
	for my in _rows:
		for mx in _cols:
			var c := Vector2i(mx, my)
			if _ways(c).size() >= 3 and not _arena.grow(1).has_point(c) and not _in_rooms(c) \
					and not _landmark_cells.has(c) and absi(c.x - _entry.x) + absi(c.y - _entry.y) > SAFE_RADIUS:
				options.append(c)
	_shuffle(options, rng)
	var picked: Array[Vector2i] = []
	for c in options:
		if picked.size() >= count:
			break
		if picked.any(func(p): return absi(p.x - c.x) + absi(p.y - c.y) < 6):
			continue
		picked.append(c)
		_quiet[c] = true
		var corner := Vector2i(rng.randi_range(0, 1) * (OPEN - 1), rng.randi_range(0, 1) * (OPEN - 1))
		_layout.props.append({"type": "campfire", "cell": cell_origin(c) + corner})


## Magma vents burn one side lane of a passage (two tiles): never the whole way.
func _place_vents(rng: RandomNumberGenerator, count: int) -> void:
	var options := _passages()
	_shuffle(options, rng)
	var used := {}
	for pair in options:
		if _layout.hazards.size() >= count:
			break
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		if used.has(a) or used.has(b) or a == _entry or b == _entry:
			continue
		used[a] = true
		used[b] = true
		var o := cell_origin(a)
		var lane := rng.randi_range(0, 1) * (OPEN - 1)
		var rect := Rect2i(o + Vector2i(OPEN, lane), Vector2i(PITCH - OPEN, 1)) if a.x != b.x \
			else Rect2i(o + Vector2i(lane, OPEN), Vector2i(1, PITCH - OPEN))
		_layout.hazards.append({"type": VENT, "rect": rect})


func _store_base() -> void:
	var key := "%d:%s" % [_seed, _sector]
	if _base_cache.has(key):
		return
	var fixed: Array = _landmark_cells.keys()
	_base_cache[key] = {
		"landmarks": _layout.landmarks.map(func(m): return {"type": m.type, "mc": m.mc, "cell": m.cell}),
		"glyphs": _layout.glyphs.map(func(g): return {"glyph": g.glyph, "mc": g.mc}),
		"chests": _chest_spots.map(func(s): return s.mc),
		"fixed": fixed,
		"route": _route_len,
		"dist": _cell_dist.duplicate(),
	}


## Depth of a maze cell (unshifted maze): path cells from the entrance over the
## route length to the arena door, so the door sits at 1.0.
static func cell_depth(seed_value: int, sector: String, mc: Vector2i) -> float:
	var base := _base(seed_value, sector)
	return float(base.dist.get(mc, base.route)) / base.route


static func _base(seed_value: int, sector: String) -> Dictionary:
	var key := "%d:%s" % [seed_value, sector]
	if not _base_cache.has(key):
		generate(seed_value, sector, 0)
	return _base_cache[key]


## A rare deposit at the back wall of most dead ends (the middle tile opposite
## the way in: never in a passage, never on a cell's corner nodes). Own rng
## stream: creatures and ordinary resources roll the same as before.
func _place_caches(dead_ends: Array) -> void:
	var rng := _sector_rng(_seed, _sector, CACHE_SALT)
	var table: Array = Sectors.info(_sector).resources.filter(func(r): return r[2] >= CACHE_RARE_DEPTH)
	var occupied := {}
	for p in _layout.props:
		occupied[p.cell] = true
	for de in dead_ends:
		var mc: Vector2i = de.mc
		var roll := rng.randf()
		var pick := rng.randf()
		var dist := absi(mc.x - _entry.x) + absi(mc.y - _entry.y)
		if dist < CACHE_MIN_DIST or roll > CACHE_CHANCE or table.is_empty() or _quiet.has(mc):
			continue
		# With both back corners already taken, a cache would wall the back
		# off: a later shift opening a passage there would find it plugged.
		var back: Vector2i = cell_origin(mc) + Vector2i.ONE - Vector2i(de.way)
		var side := Vector2i(absi(de.way.y), absi(de.way.x))
		if occupied.has(back + side) and occupied.has(back - side):
			continue
		var depth := _depth(mc)
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
		_layout.props.append({"type": type, "cell": back})
		_layout.caches.append(back)


## A fixed share of the eligible cells holds a creature: shuffled from the
## seed, round(enemy_chance x eligible) of them.
func _place_enemies(dead_ends: Array) -> void:
	for c in DIRS + [Vector2i.ZERO]:
		_quiet[_door + c] = true
	var eligible: Array = []
	for my in _rows:
		for mx in _cols:
			var mc := Vector2i(mx, my)
			if absi(mc.x - _entry.x) + absi(mc.y - _entry.y) <= SAFE_RADIUS or _arena.has_point(mc) \
					or _landmark_cells.has(mc) or _quiet.has(mc):
				continue
			eligible.append(mc)
	_shuffle(eligible, _rng)
	for i in roundi(float(_maze.enemy_chance) * eligible.size()):
		var mc: Vector2i = eligible[i]
		var type := EnemyCatalog.pick(_sector, _depth(mc), _rng.randf())
		if type != "":
			_layout.enemy_spawns.append({"type": type, "cell": cell_origin(mc) + Vector2i.ONE})
	_place_elite_dens(dead_ends)
	_place_chest_guards()


## An elite lairs in each of the farthest free dead ends: the rare beasts that
## drop Memory Shards are always somewhere to be found. Own rng stream.
func _place_elite_dens(dead_ends: Array) -> void:
	var rng := _sector_rng(_seed, _sector, ELITE_SALT)
	var taken := {}
	for s in _layout.enemy_spawns:
		taken[s.cell] = true
	var spots: Array = dead_ends.filter(func(de): return not _landmark_cells.has(de.mc) and not _quiet.has(de.mc) \
		and not taken.has(cell_origin(de.mc) + Vector2i.ONE))
	spots.sort_custom(func(a, b): return _cell_dist.get(a.mc, 0) > _cell_dist.get(b.mc, 0))
	for i in mini(int(_maze.get("elite_dens", ELITE_DENS)), spots.size()):
		var type := EnemyCatalog.pick(_sector, _depth(spots[i].mc), rng.randf(), func(d): return d.elite)
		if type == "":
			type = EnemyCatalog.pick(_sector, 2.0, rng.randf(), func(d): return d.elite)
		if type != "":
			_layout.enemy_spawns.append({"type": type, "cell": cell_origin(spots[i].mc) + Vector2i.ONE})


## Each chest's only neighbour holds a guard a little tougher than its depth.
func _place_chest_guards() -> void:
	var rng := _sector_rng(_seed, _sector, GUARD_SALT)
	var taken := {}
	for s in _layout.enemy_spawns:
		taken[s.cell] = true
	for spot in _chest_spots:
		var mc: Vector2i = spot.mc + spot.way
		var cell := cell_origin(mc) + Vector2i.ONE
		var roll := rng.randf()
		if not _in_maze(mc) or _arena.has_point(mc) or _landmark_cells.has(mc) or _quiet.has(mc) or taken.has(cell):
			continue
		var depth := minf(_depth(spot.mc) + GUARD_DEPTH, 1.3)
		var type := EnemyCatalog.pick(_sector, depth, roll, func(d): return d.temper != "passive")
		if type == "":
			type = EnemyCatalog.pick(_sector, depth, roll)
		if type != "":
			taken[cell] = true
			_layout.enemy_spawns.append({"type": type, "cell": cell})


## Breadth-first path distances over the maze cells, from the entrance, with
## the BFS tree (shortest ways back to the entrance).
func _measure_depth() -> void:
	_cell_dist = {_entry: 0}
	_parent = {}
	var queue: Array[Vector2i] = [_entry]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in DIRS:
			var n: Vector2i = c + d
			if _in_maze(n) and not _cell_dist.has(n) and _is_linked(c, d):
				_cell_dist[n] = _cell_dist[c] + 1
				_parent[n] = c
				queue.append(n)
	_route_len = maxf(1.0, _cell_dist.get(_door, _cols + _rows))


func _depth(mc: Vector2i) -> float:
	return clampf(_cell_dist.get(mc, _route_len) / _route_len, 0.0, 1.3)


## Resource nodes sit in the corners of maze cells (never blocking passages);
## richer deposits lie deeper in the maze.
func _place_resources() -> void:
	var corners := [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]
	for my in _rows:
		for mx in _cols:
			var mc := Vector2i(mx, my)
			var dist := absi(mc.x - _entry.x) + absi(mc.y - _entry.y)
			var depth := _depth(mc)
			var first := _rng.randi_range(0, 3)
			var rolls := [_rng.randf(), _rng.randf()]
			if dist <= 1 or _arena.has_point(mc) or _landmark_cells.has(mc) or _quiet.has(mc):
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


## Props and hazards laid on the unshifted maze whose tiles a shift walled up.
func _drop_buried() -> void:
	_layout.props.assign(_layout.props.filter(func(p): return not _solid.has(p.cell) and _layout.get_ground(p.cell) != Id.WATER))
	_layout.caches = _layout.caches.filter(func(c): return not _solid.has(c))
	_layout.hazards = _layout.hazards.filter(func(h): return not _solid.has(h.rect.position))


func _carve(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_solid.erase(Vector2i(x, y))


## Carves every maze cell and the passages between them. In long-hall
## sectors ("straight") the carver keeps its heading when it can.
func _carve_maze() -> void:
	for my in _rows:
		for mx in _cols:
			_carve(Rect2i(cell_origin(Vector2i(mx, my)), Vector2i(OPEN, OPEN)))
	var straight: float = _maze.get("straight", 0.0)
	var heading := {}
	var visited := {Vector2i.ZERO: true}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d in DIRS:
			var n: Vector2i = cur + d
			if _in_maze(n) and not visited.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = options[_rng.randi_range(0, options.size() - 1)]
		var ahead: Vector2i = cur + heading.get(cur, Vector2i.ZERO)
		if straight > 0.0 and ahead != cur and options.has(ahead) and _rng.randf() < straight:
			next = ahead
		heading[next] = next - cur
		_link(cur, next)
		visited[next] = true
		stack.append(next)
	# Loops make the maze less of a perfect tree.
	var loops: float = _maze.loops
	for my in _rows:
		for mx in _cols:
			var c := Vector2i(mx, my)
			for d in [Vector2i.RIGHT, Vector2i.DOWN]:
				if _in_maze(c + d) and _rng.randf() < loops:
					_link(c, c + d)


func _in_maze(mc: Vector2i) -> bool:
	return mc.x >= 0 and mc.y >= 0 and mc.x < _cols and mc.y < _rows


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
	var moss: float = Sectors.info(_sector).moss
	for y in _layout.size.y:
		for x in _layout.size.x:
			var cell := Vector2i(x, y)
			if not _solid.has(cell) and _cell_noise(cell) < moss:
				_layout.set_ground(cell, Id.MAZE_FLOOR_MOSS)


## A pool in the middle of each oasis (drinkable like any pond).
func _paint_oases() -> void:
	var rng := _sector_rng(_seed, _sector, 64013)
	for r: Rect2i in _oases:
		var c := Vector2(region_tiles(r).get_center()) + Vector2(0.5, 0.5)
		var blobs := [{"c": c, "r": Vector2(1.5, 1.2)}]
		for y in range(-3, 4):
			for x in range(-3, 4):
				var cell := Vector2i(c.floor()) + Vector2i(x, y)
				if Pond.field(blobs, Vector2(cell) + Vector2(0.5, 0.5)) >= Pond.SOLID:
					_layout.set_ground(cell, Id.WATER)
		_layout.ponds.append({"blobs": blobs, "seed": rng.randi()})


func _cell_noise(cell: Vector2i) -> float:
	return float(absi(hash(Vector3i(cell.x, cell.y, _seed))) % 10000) / 10000.0


static func _sector_rng(seed_value: int, sector: String, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + salt + Sectors.index_of(sector) * SECTOR_SALT
	return rng


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = list[i]
		list[i] = list[j]
		list[j] = t


## Maze cells between a tile and the entrance cell through the open passages
## of a (possibly shifted) layout: 0 in the vestibule, -1 when cut off.
static func cells_home(layout: ClearingLayout, sector: String, tile: Vector2i) -> int:
	var entry := entry_cell(sector)
	var start := cell_of(tile)
	if tile.y >= cell_origin(entry).y + OPEN:
		return 0
	var c_max := Vector2i(cols(sector), rows(sector))
	if start.x < 0 or start.y < 0 or start.x >= c_max.x or start.y >= c_max.y:
		return -1
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == entry:
			return dist[c]
		var o := cell_origin(c)
		for d in DIRS:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= c_max.x or n.y >= c_max.y or dist.has(n):
				continue
			var gap: Vector2i = o + Vector2i(OPEN, 0) if d == Vector2i.RIGHT else o + Vector2i(-1, 0) if d == Vector2i.LEFT \
				else o + Vector2i(0, OPEN) if d == Vector2i.DOWN else o + Vector2i(0, -1)
			if layout.is_wall(gap):
				continue
			dist[n] = dist[c] + 1
			queue.append(n)
	return -1


## Walking pace used to judge the way home (tiles per real second).
const HOME_PACE := 4.5
const HOME_MARGIN := 1.5


## Whether the daylight left (real seconds) is short for a walk of `cells`
## maze cells home (PITCH tiles each), with a safety margin.
static func dusk_warning_due(seconds_left: float, cells: int) -> bool:
	return cells > 0 and seconds_left < HOME_MARGIN * cells * PITCH / HOME_PACE


## Every landmark type that can stand in some sector.
static func all_landmark_types() -> Array:
	var out: Array = SHARED_LANDMARKS.duplicate()
	for s in Sectors.ORDER:
		out.append_array(Sectors.info(s).landmarks)
	return out


## Fixed landmarks of a sector: [{type, mc (maze cell), cell (tile)}].
static func landmarks(seed_value: int, sector: String) -> Array:
	return _base(seed_value, sector).landmarks


## Glyph stones of a sector: [{glyph, mc}] (see _place_glyphs).
static func glyph_spots(seed_value: int, sector: String) -> Array:
	return _base(seed_value, sector).glyphs


## Length (maze cells) of the way from the entrance to the arena door in the
## unshifted maze.
static func route_length(seed_value: int, sector: String) -> float:
	return _base(seed_value, sector).route


## Maze-cell rects re-carved at a shift (night index), never holding a
## landmark, glyph stone or chest, nor touching the entrance rows, the arena
## or an oasis.
static func shift_regions(seed_value: int, sector: String, shift: int) -> Array:
	if shift <= 0:
		return []
	var m := Sectors.maze(sector)
	var rng := _sector_rng(seed_value + shift * 7907, sector, 99991)
	var fixed: Array = _base(seed_value, sector).fixed
	var avoid: Array = [arena(sector).grow(1)] + oases(seed_value, sector)
	var out := []
	var tries := 0
	while out.size() < m.shift_regions and tries < 300:
		tries += 1
		var r := Rect2i(Vector2i(rng.randi_range(0, m.cols - SHIFT_SIZE.x), rng.randi_range(2, m.rows - 2 - SHIFT_SIZE.y)), SHIFT_SIZE)
		if out.any(func(o): return o.grow(1).intersects(r)) or fixed.any(func(mc): return r.has_point(mc)) \
				or avoid.any(func(a): return a.intersects(r)):
			continue
		out.append(r)
	return out


## Maze cells of the sector's treasure chests. They are picked in the
## unshifted maze, so they never move and the shifting regions avoid them.
static func chest_cells(seed_value: int, sector: String) -> Array:
	return _base(seed_value, sector).chests


## Tiles covered by a region of maze cells (cells plus the walls between them).
static func region_tiles(region: Rect2i) -> Rect2i:
	var a := cell_origin(region.position)
	var b := cell_origin(region.end - Vector2i.ONE) + Vector2i(OPEN, OPEN)
	return Rect2i(a, b - a)


## Closes every passage inside the region, then carves a new spanning tree
## through it (plus a loop in the first sector only). Passages crossing the
## border are kept here (see _close_border).
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
		for d in DIRS:
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
	if Sectors.index_of(_sector) == 0:
		var c := region.position + Vector2i(rng.randi_range(0, region.size.x - 2), rng.randi_range(0, region.size.y - 1))
		_link(c, c + Vector2i.RIGHT)


## Some passages crossing the region's border close (SHIFT_CLOSE_CHANCE each).
## Returns the closed ones as [cell, neighbour] pairs.
func _close_border(region: Rect2i) -> Array:
	var rng := _sector_rng(_seed + _shift * 7907 + region.position.x * 31 + region.position.y, _sector, 5209)
	var out := []
	for my in range(region.position.y, region.end.y):
		for mx in range(region.position.x, region.end.x):
			var c := Vector2i(mx, my)
			for d in DIRS:
				var n: Vector2i = c + d
				if region.has_point(n) or not _in_maze(n) or _arena.grow(1).has_point(n):
					continue
				var roll := rng.randf()
				if roll < SHIFT_CLOSE_CHANCE and _is_linked(c, d):
					_link(c, n, true)
					out.append([c, n])
	return out


## Fairness: while some cell (or the arena door) cannot be reached from the
## entrance, reopen a closed passage, preferring one joining the reached part
## to the cut-off part.
func _restore_reach(closed: Array) -> void:
	while not closed.is_empty():
		var seen := _reach()
		if seen.size() >= _cols * _rows:
			return
		var pick := 0
		for i in closed.size():
			if seen.has(closed[i][0]) != seen.has(closed[i][1]):
				pick = i
				break
		_link(closed[pick][0], closed[pick][1])
		closed.remove_at(pick)


## A shift threatens the way in: while the route to the arena door is shorter
## than before the shift, close a passage of it that touches a moving region,
## as long as every cell stays reachable.
func _lengthen_route(regions: Array) -> void:
	for guard in 16:
		var path := _cell_path(_entry, _door)
		if path.size() - 1 >= _route_len:
			return
		var cut := false
		for i in path.size() - 1:
			var a: Vector2i = path[i]
			var b: Vector2i = path[i + 1]
			if not regions.any(func(r): return r.has_point(a) or r.has_point(b)):
				continue
			_link(a, b, true)
			if _reach().size() >= _cols * _rows:
				cut = true
				break
			_link(a, b)
		if not cut:
			return


## Shortest chain of linked cells from `from` to `to` (both included).
func _cell_path(from: Vector2i, to: Vector2i) -> Array:
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == to:
			break
		for d in DIRS:
			var n: Vector2i = c + d
			if _in_maze(n) and not prev.has(n) and _is_linked(c, d):
				prev[n] = c
				queue.append(n)
	if not prev.has(to):
		return []
	var out := [to]
	while out.back() != from:
		out.append(prev[out.back()])
	out.reverse()
	return out
