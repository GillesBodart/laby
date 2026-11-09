class_name ClearingGenerator
extends RefCounted
## Deterministically builds the starting area from a seed: a grassy glade
## enclosed by massive walls with four gates, surrounded by a ring
## corridor and corridor stubs hinting at the labyrinth beyond.

const MAP_SIZE := Vector2i(128, 98)
const CLEARING_RECT := Rect2i(14, 14, 100, 70)
const WALL_THICKNESS := 3
const RING_WIDTH := 3
const GATE_WIDTH := 3
const VARIANTS := 10
const PORTAL_ROWS := 3
const PLAZA_RADIUS := 3.5
const TREE_TARGET := 130
const ROCK_TARGET := 45
const BUSH_TARGET := 28
const GRASS_TARGET := 70
const CLAY_TARGET := 16
const MUSHROOM_TARGET := 14
## Smaller forest resources: [type, count, min spacing in tiles].
const EXTRA_NODES := [
	["grass", GRASS_TARGET, 1.5], ["clay", CLAY_TARGET, 4.0], ["mushroom", MUSHROOM_TARGET, 3.0],
	["flint", 14, 4.0], ["herb", 16, 3.0], ["wheat", 18, 2.0], ["cotton", 14, 2.5],
	["resin_stump", 10, 5.0], ["beehive", 6, 8.0], ["apple_tree", 10, 5.0], ["carrot", 12, 2.5],
	["blueberry", 12, 3.0], ["flower", 20, 2.0], ["sand", 12, 3.0], ["nest", 8, 6.0], ["potato", 12, 2.5],
]
const POND_TARGET := 5
## Reeds only grow on pond banks.
const REEDS_PER_POND := 6
const CREATURE_TARGET := 46
## Minimum distance (tiles) from the campfire per temperament: the camp stays safe.
const CREATURE_MIN_DIST := {"passive": 8.0, "neutral": 12.0, "nocturnal": 18.0, "hostile": 24.0}
const ELITE_MIN_DIST := 30.0

const Id := TileCatalog.Id


static func generate(seed_value: int) -> ClearingLayout:
	var gen := ClearingGenerator.new()
	return gen._generate(seed_value)


var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _layout: ClearingLayout
var _solid: Dictionary = {} # cell -> true for wall cells during carving


func _generate(seed_value: int) -> ClearingLayout:
	_rng.seed = seed_value
	_noise.seed = seed_value
	_noise.frequency = 0.08
	_layout = ClearingLayout.new(MAP_SIZE)
	_layout.clearing_rect = CLEARING_RECT
	var center := CLEARING_RECT.get_center()
	_layout.campfire_cell = center
	_layout.spawn_cell = center + Vector2i(0, 2)

	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			_solid[Vector2i(x, y)] = true
			_layout.set_ground(Vector2i(x, y), Id.MAZE_FLOOR)

	_carve_rect(CLEARING_RECT)
	var inner_ring := CLEARING_RECT.grow(WALL_THICKNESS)
	var outer_ring := inner_ring.grow(RING_WIDTH)
	for y in range(outer_ring.position.y, outer_ring.end.y):
		for x in range(outer_ring.position.x, outer_ring.end.x):
			if not inner_ring.has_point(Vector2i(x, y)):
				_solid.erase(Vector2i(x, y))
	_carve_gates(center, inner_ring, outer_ring)
	_carve_stubs(outer_ring)
	_paint_ground()
	_carve_paths(center)
	_resolve_walls()
	_setup_portal(center)
	_place_props(center)
	return _layout


func _carve_rect(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_solid.erase(Vector2i(x, y))


func _carve_gates(center: Vector2i, inner_ring: Rect2i, outer_ring: Rect2i) -> void:
	var half := GATE_WIDTH / 2
	var r := CLEARING_RECT
	# side -> [passage rect through the wall band, corridor rect to the map edge, door line rect]
	var specs := {
		"north": [
			Rect2i(center.x - half, inner_ring.position.y, GATE_WIDTH, WALL_THICKNESS),
			Rect2i(center.x - half, 1, GATE_WIDTH, outer_ring.position.y - 1),
			Rect2i(center.x - half, r.position.y - 2, GATE_WIDTH, 1),
		],
	}
	for side in specs:
		var passage: Rect2i = specs[side][0]
		_carve_rect(passage)
		_carve_rect(specs[side][1])
		var door: Rect2i = specs[side][2]
		var cells: Array[Vector2i] = []
		for y in range(door.position.y, door.end.y):
			for x in range(door.position.x, door.end.x):
				cells.append(Vector2i(x, y))
		_layout.gates.append({"side": side, "cells": cells})


## Short dead-end corridors leaving the ring: the labyrinth teases the player.
func _carve_stubs(outer_ring: Rect2i) -> void:
	for i in 8:
		var side := _rng.randi_range(0, 3)
		var length := _rng.randi_range(2, 5)
		var rect: Rect2i
		match side:
			0:
				var x := _rng.randi_range(outer_ring.position.x + 2, outer_ring.end.x - 4)
				rect = Rect2i(x, outer_ring.position.y - length, 2, length)
			1:
				var x := _rng.randi_range(outer_ring.position.x + 2, outer_ring.end.x - 4)
				rect = Rect2i(x, outer_ring.end.y, 2, length)
			2:
				var y := _rng.randi_range(outer_ring.position.y + 2, outer_ring.end.y - 4)
				rect = Rect2i(outer_ring.position.x - length, y, length, 2)
			_:
				var y := _rng.randi_range(outer_ring.position.y + 2, outer_ring.end.y - 4)
				rect = Rect2i(outer_ring.end.x, y, length, 2)
		_carve_rect(rect.intersection(Rect2i(Vector2i.ONE, MAP_SIZE - Vector2i(2, 2))))


func _paint_ground() -> void:
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			if CLEARING_RECT.has_point(cell):
				var id := Id.GRASS
				if _noise.get_noise_2d(x, y) > 0.2:
					id = Id.GRASS_ALT
				if _rng.randf() < 0.04:
					id = Id.GRASS_FLOWERS
				_layout.set_ground(cell, id)
			elif not _solid.has(cell) and _rng.randf() < 0.15:
				_layout.set_ground(cell, Id.MAZE_FLOOR_MOSS)
	for gate in _layout.gates:
		for cell in gate.cells:
			_layout.set_ground(cell, Id.GATE_FLOOR)


func _carve_paths(center: Vector2i) -> void:
	for y in range(-4, 5):
		for x in range(-4, 5):
			if Vector2(x, y).length() <= PLAZA_RADIUS:
				_layout.set_ground(center + Vector2i(x, y), Id.DIRT)
	for gate in _layout.gates:
		var target: Vector2i = gate.cells[gate.cells.size() / 2]
		var dir := Vector2i(signi(target.x - center.x), signi(target.y - center.y))
		var perp := Vector2i(dir.y, dir.x)
		var cell := center
		var steps := 0
		while CLEARING_RECT.has_point(cell + dir):
			cell += dir
			steps += 1
			var remaining := absi(target.x - cell.x) + absi(target.y - cell.y)
			var wobble := 0
			if remaining > 5:
				wobble = int(round(_noise.get_noise_1d(steps * 3.0 + target.x) * 2.0))
			for w in [0, 1]:
				var c: Vector2i = cell + perp * (wobble + w - (1 if dir.x != 0 else 0))
				if CLEARING_RECT.has_point(c):
					_layout.set_ground(c, Id.DIRT)


func _resolve_walls() -> void:
	WallResolver.resolve(_layout, _solid, _rng)


func _setup_portal(center: Vector2i) -> void:
	var half := GATE_WIDTH / 2
	_layout.portal_rect = Rect2i(center.x - half, 1, GATE_WIDTH, PORTAL_ROWS)
	_layout.portal_target = "labyrinth"
	_layout.buildable = true
	_layout.return_cell = Vector2i(center.x, 1 + PORTAL_ROWS + 3)

func _is_solid(cell: Vector2i) -> bool:
	if not _layout.in_bounds(cell):
		return true
	return _solid.has(cell)


func _place_props(center: Vector2i) -> void:
	var occupied := {center: true}
	_layout.props.append({"type": "campfire", "cell": center})
	var inner := CLEARING_RECT.grow(-2)
	var gate_approaches: Array[Vector2i] = []
	for gate in _layout.gates:
		gate_approaches.append(gate.cells[gate.cells.size() / 2])

	_place_ponds(center, gate_approaches, occupied)

	var trees := 0
	for attempt in 3000:
		if trees >= TREE_TARGET:
			break
		var cell := Vector2i(
			_rng.randi_range(inner.position.x, inner.end.x - 1),
			_rng.randi_range(inner.position.y, inner.end.y - 1))
		if _noise.get_noise_2d(cell.x * 1.7, cell.y * 1.7) < 0.0 and _rng.randf() > 0.15:
			continue
		if not _is_free_for_prop(cell, center, gate_approaches, occupied, 3.0):
			continue
		occupied[cell] = true
		_layout.props.append({"type": "tree", "cell": cell, "variant": _rng.randi_range(0, VARIANTS - 1)})
		trees += 1

	var rocks := 0
	for attempt in 1500:
		if rocks >= ROCK_TARGET:
			break
		var cell := Vector2i(
			_rng.randi_range(inner.position.x, inner.end.x - 1),
			_rng.randi_range(inner.position.y, inner.end.y - 1))
		if not _is_free_for_prop(cell, center, gate_approaches, occupied, 2.0):
			continue
		occupied[cell] = true
		_layout.props.append({"type": "rock", "cell": cell, "variant": _rng.randi_range(0, VARIANTS - 1)})
		rocks += 1

	var bushes := 0
	for attempt in 1500:
		if bushes >= BUSH_TARGET:
			break
		var cell := Vector2i(
			_rng.randi_range(inner.position.x, inner.end.x - 1),
			_rng.randi_range(inner.position.y, inner.end.y - 1))
		if not _is_free_for_prop(cell, center, gate_approaches, occupied, 3.0):
			continue
		occupied[cell] = true
		_layout.props.append({"type": "bush", "cell": cell})
		bushes += 1

	for extra in EXTRA_NODES:
		var placed := 0
		for attempt in 2000:
			if placed >= extra[1]:
				break
			var cell := Vector2i(
				_rng.randi_range(inner.position.x, inner.end.x - 1),
				_rng.randi_range(inner.position.y, inner.end.y - 1))
			if not _is_free_for_prop(cell, center, gate_approaches, occupied, extra[2]):
				continue
			occupied[cell] = true
			_layout.props.append({"type": extra[0], "cell": cell})
			placed += 1
	_place_creatures(center, inner, occupied)


## Ponds away from the camp and paths; their water cells block movement and
## reeds grow on the muddy banks.
func _place_ponds(center: Vector2i, gates: Array[Vector2i], occupied: Dictionary) -> void:
	var area := CLEARING_RECT.grow(-6)
	for attempt in 200:
		if _layout.ponds.size() >= POND_TARGET:
			break
		var c := Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
		var blobs := []
		for i in _rng.randi_range(2, 4):
			var off := Vector2.from_angle(_rng.randf() * TAU) * (0.0 if i == 0 else _rng.randf_range(1.2, 2.6))
			blobs.append({"c": c + off, "r": Vector2(_rng.randf_range(1.4, 2.6), _rng.randf_range(1.1, 2.0))})
		var box := Pond.bounds(blobs)
		var cells := Rect2i(Vector2i(box.position.floor()), Vector2i(box.size.ceil()) + Vector2i.ONE)
		if not area.encloses(cells) or Vector2(center).distance_to(c) < 14.0:
			continue
		var ok := true
		for g in gates:
			if Vector2(g).distance_to(c) < 10.0:
				ok = false
		for p in _layout.ponds:
			if Pond.bounds(p.blobs).grow(2.0).intersects(box):
				ok = false
		for y in range(cells.position.y, cells.end.y):
			for x in range(cells.position.x, cells.end.x):
				if _layout.get_ground(Vector2i(x, y)) == Id.DIRT:
					ok = false
		if not ok:
			continue
		var shore: Array[Vector2i] = []
		for y in range(cells.position.y, cells.end.y):
			for x in range(cells.position.x, cells.end.x):
				var cell := Vector2i(x, y)
				var f := Pond.field(blobs, Vector2(cell) + Vector2(0.5, 0.5))
				if f >= Pond.SOLID:
					_layout.set_ground(cell, Id.WATER)
					occupied[cell] = true
				elif f >= Pond.SHORE:
					shore.append(cell)
		_layout.ponds.append({"blobs": blobs, "seed": _rng.randi()})
		var reeds := 0
		for i in shore.size() * 2:
			if reeds >= REEDS_PER_POND:
				break
			var cell: Vector2i = shore[_rng.randi_range(0, shore.size() - 1)]
			if not _is_free_for_prop(cell, center, gates, occupied, 1.4):
				continue
			occupied[cell] = true
			_layout.props.append({"type": "reeds", "cell": cell})
			reeds += 1
		# Keep the rest of the bank clear so the shoreline stays readable.
		for cell in shore:
			occupied[cell] = true


## Forest wildlife: gentle animals near the camp, predators further out.
func _place_creatures(center: Vector2i, inner: Rect2i, occupied: Dictionary) -> void:
	var placed := 0
	for attempt in 3000:
		if placed >= CREATURE_TARGET:
			break
		var cell := Vector2i(
			_rng.randi_range(inner.position.x, inner.end.x - 1),
			_rng.randi_range(inner.position.y, inner.end.y - 1))
		if occupied.has(cell) or _is_solid(cell):
			continue
		var dist := Vector2(cell - center).length()
		var type := EnemyCatalog.pick("forest", 0.0, _rng.randf(), func(d: Dictionary) -> bool:
			return dist >= (ELITE_MIN_DIST if d.elite else CREATURE_MIN_DIST[d.temper]))
		if type == "":
			continue
		occupied[cell] = true
		_layout.enemy_spawns.append({"type": type, "cell": cell})
		placed += 1


func _is_free_for_prop(cell: Vector2i, center: Vector2i, gates: Array[Vector2i],
		occupied: Dictionary, spacing: float) -> bool:
	if Vector2(cell - center).length() < 6.0:
		return false
	for g in gates:
		if Vector2(cell - g).length() < 5.0:
			return false
	for y in range(-1, 2):
		for x in range(-1, 2):
			var n := cell + Vector2i(x, y)
			if _layout.get_ground(n) == Id.DIRT:
				return false
	for other in occupied:
		if Vector2(cell - other).length() < spacing:
			return false
	return true
