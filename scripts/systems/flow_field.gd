class_name FlowField
extends RefCounted
## Breadth-first distance field over the walkable tiles of a layout, grown
## from one target tile up to RADIUS steps. Creatures descend it to chase
## around walls instead of pressing into them. Pure data: no nodes.
##
## Fields are shared (FlowField.shared): one per layout, target tile and set
## of extra blocked cells, rebuilt when the layout's walls change (polled at
## most once per WALL_POLL_MS through a hash of the wall array).

const RADIUS := 40
const SPAN := RADIUS * 2 + 1
const UNREACHED := -1
const NO_STEP := Vector2i(-1, -1)
const MAX_SHARED := 16
const WALL_POLL_MS := 1000
## 8 neighbours, orthogonal first so ties prefer straight moves.
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]

static var _pool: Array[FlowField] = []
static var _sig_layout_id := 0
static var _sig_time := -WALL_POLL_MS
static var _sig := 0

var layout: ClearingLayout
var target := NO_STEP
var blocked: Dictionary = {}
var walls_sig := 0
var last_used := 0
## Top-left cell of the SPAN x SPAN window centred on the target.
var origin := Vector2i.ZERO
var _dist := PackedInt32Array()
var _open := PackedByteArray()
var _queue := PackedInt32Array()


func _init() -> void:
	_dist.resize(SPAN * SPAN)
	_open.resize(SPAN * SPAN)
	_queue.resize(SPAN * SPAN)


## The shared field leading to `to` on `on` (built or refreshed as needed).
## `extra_blocked` (cell -> true) are cells the layout does not know are shut,
## such as closed gates.
static func shared(on: ClearingLayout, to: Vector2i, extra_blocked: Dictionary = {}) -> FlowField:
	var sig := walls_signature(on)
	var now := Time.get_ticks_msec()
	var oldest: FlowField = null
	for f in _pool:
		if f.layout == on and f.target == to and f.blocked == extra_blocked:
			if f.walls_sig != sig:
				f.build(on, to, extra_blocked, sig)
			f.last_used = now
			return f
		if oldest == null or f.last_used < oldest.last_used:
			oldest = f
	var field: FlowField = oldest
	if _pool.size() < MAX_SHARED or field == null:
		field = FlowField.new()
		_pool.append(field)
	field.build(on, to, extra_blocked, sig)
	field.last_used = now
	return field


## Cheap change detector for a layout's walls (the Labyrinth moves them in
## place at night): rehashed at most once per WALL_POLL_MS.
static func walls_signature(on: ClearingLayout) -> int:
	var now := Time.get_ticks_msec()
	if on.get_instance_id() != _sig_layout_id or now - _sig_time >= WALL_POLL_MS:
		_sig_layout_id = on.get_instance_id()
		_sig_time = now
		_sig = hash(on.walls)
	return _sig


## Drops every shared field (a new area was loaded).
static func clear_shared() -> void:
	_pool.clear()
	_sig_layout_id = 0


func build(on: ClearingLayout, to: Vector2i, extra_blocked: Dictionary = {}, sig := 0) -> void:
	layout = on
	target = to
	blocked = extra_blocked
	walls_sig = sig
	origin = to - Vector2i(RADIUS, RADIUS)
	_dist.fill(UNREACHED)
	# Passability of the window, read straight from the layout arrays.
	var w := on.size.x
	var water := TileCatalog.Id.WATER
	for ly in SPAN:
		var y := origin.y + ly
		for lx in SPAN:
			var x := origin.x + lx
			var ok := x >= 0 and y >= 0 and x < w and y < on.size.y
			if ok:
				var gi := y * w + x
				ok = on.walls[gi] == ClearingLayout.NO_TILE and on.ground[gi] != water
				if ok and not extra_blocked.is_empty():
					ok = not extra_blocked.has(Vector2i(x, y))
			_open[ly * SPAN + lx] = 1 if ok else 0
	var start := RADIUS * SPAN + RADIUS
	_dist[start] = 0
	_queue[0] = start
	var head := 0
	var tail := 1
	while head < tail:
		var i := _queue[head]
		head += 1
		var d := _dist[i] + 1
		if d > RADIUS:
			continue
		var lx := i % SPAN
		var ly := i / SPAN
		if lx > 0:
			tail = _visit(i - 1, d, tail)
		if lx < SPAN - 1:
			tail = _visit(i + 1, d, tail)
		if ly > 0:
			tail = _visit(i - SPAN, d, tail)
		if ly < SPAN - 1:
			tail = _visit(i + SPAN, d, tail)


func _visit(n: int, d: int, tail: int) -> int:
	if _dist[n] != UNREACHED or _open[n] == 0:
		return tail
	_dist[n] = d
	_queue[tail] = n
	return tail + 1


## Steps from `cell` to the target (UNREACHED when out of reach).
func distance(cell: Vector2i) -> int:
	var l := cell - origin
	if l.x < 0 or l.y < 0 or l.x >= SPAN or l.y >= SPAN:
		return UNREACHED
	return _dist[l.y * SPAN + l.x]


## Neighbour of `cell` one step closer to the target; diagonals only when
## both orthogonal cells are open, so walkers never clip a wall corner.
## NO_STEP when `cell` is out of reach or already on the target.
func next_step(cell: Vector2i) -> Vector2i:
	var here := distance(cell)
	if here <= 0:
		return NO_STEP
	var best := NO_STEP
	var best_d := here
	for k in DIRS.size():
		var dir: Vector2i = DIRS[k]
		var n := cell + dir
		var nd := distance(n)
		if nd == UNREACHED or nd >= best_d:
			continue
		if k >= 4 and (distance(Vector2i(cell.x + dir.x, cell.y)) == UNREACHED or distance(Vector2i(cell.x, cell.y + dir.y)) == UNREACHED):
			continue
		best = n
		best_d = nd
	return best


## True when no wall of the layout lies on the straight line between the two
## cells (supercover walk: corners touched by the line count).
static func sees(on: ClearingLayout, a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	var n := maxi(absi(d.x), absi(d.y))
	if n == 0:
		return true
	var from := Vector2(a) + Vector2(0.5, 0.5)
	var step := Vector2(d) / float(n * 2)
	for i in range(1, n * 2):
		var c := Vector2i((from + step * i).floor())
		if on.is_wall(c):
			return false
	return true
