class_name ClearingGenerator
extends RefCounted
## Deterministically builds the starting area from a seed: a grassy glade
## enclosed by massive walls with four gates, surrounded by a ring
## corridor and corridor stubs hinting at the labyrinth beyond.

const MAP_SIZE := Vector2i(72, 56)
const CLEARING_RECT := Rect2i(14, 12, 44, 32)
const WALL_THICKNESS := 3
const RING_WIDTH := 3
const GATE_WIDTH := 3
const PLAZA_RADIUS := 3.5
const TREE_TARGET := 40
const ROCK_TARGET := 14

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
		"south": [
			Rect2i(center.x - half, r.end.y, GATE_WIDTH, WALL_THICKNESS),
			Rect2i(center.x - half, outer_ring.end.y, GATE_WIDTH, MAP_SIZE.y - 1 - outer_ring.end.y),
			Rect2i(center.x - half, r.end.y + 1, GATE_WIDTH, 1),
		],
		"west": [
			Rect2i(inner_ring.position.x, center.y - half, WALL_THICKNESS, GATE_WIDTH),
			Rect2i(1, center.y - half, outer_ring.position.x - 1, GATE_WIDTH),
			Rect2i(r.position.x - 2, center.y - half, 1, GATE_WIDTH),
		],
		"east": [
			Rect2i(r.end.x, center.y - half, WALL_THICKNESS, GATE_WIDTH),
			Rect2i(outer_ring.end.x, center.y - half, MAP_SIZE.x - 1 - outer_ring.end.x, GATE_WIDTH),
			Rect2i(r.end.x + 1, center.y - half, 1, GATE_WIDTH),
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
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			if not _solid.has(cell):
				continue
			var below := cell + Vector2i.DOWN
			var below2 := cell + Vector2i(0, 2)
			var id: int
			if not _is_solid(below):
				id = Id.WALL_FACE_LOW_VINES if _rng.randf() < 0.25 else Id.WALL_FACE_LOW
			elif not _is_solid(below2):
				id = Id.WALL_FACE_HIGH_VINES if _rng.randf() < 0.25 else Id.WALL_FACE_HIGH
			else:
				id = Id.WALL_TOP_MOSS if _rng.randf() < 0.2 else Id.WALL_TOP
			_layout.set_wall(cell, id)


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

	var trees := 0
	for attempt in 800:
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
		_layout.props.append({"type": "tree", "cell": cell})
		trees += 1

	var rocks := 0
	for attempt in 400:
		if rocks >= ROCK_TARGET:
			break
		var cell := Vector2i(
			_rng.randi_range(inner.position.x, inner.end.x - 1),
			_rng.randi_range(inner.position.y, inner.end.y - 1))
		if not _is_free_for_prop(cell, center, gate_approaches, occupied, 2.0):
			continue
		occupied[cell] = true
		_layout.props.append({"type": "rock", "cell": cell})
		rocks += 1


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
