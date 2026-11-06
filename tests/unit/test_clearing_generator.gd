extends TestCase


func test_same_seed_same_layout() -> void:
	var a := ClearingGenerator.generate(42)
	var b := ClearingGenerator.generate(42)
	check(a.ground == b.ground, "ground identical")
	check(a.walls == b.walls, "walls identical")
	check_eq(a.props, b.props, "props identical")


func test_different_seed_different_layout() -> void:
	var a := ClearingGenerator.generate(1)
	var b := ClearingGenerator.generate(2)
	check(a.props != b.props, "props differ")


func test_single_north_gate_in_walls() -> void:
	var layout := ClearingGenerator.generate(7)
	check_eq(layout.gates.size(), 1, "gate count")
	check_eq(layout.gates[0].side, "north", "gate on top")
	for gate in layout.gates:
		check_eq(gate.cells.size(), ClearingGenerator.GATE_WIDTH, "%s width" % gate.side)
		for cell in gate.cells:
			check(not layout.is_wall(cell), "%s gate open by default" % gate.side)
			check(not layout.clearing_rect.has_point(cell), "%s gate outside glade" % gate.side)
	check_eq(layout.portal_target, "labyrinth", "portal to labyrinth")
	check(layout.is_walkable(layout.return_cell), "return cell walkable")
	check(layout.portal_rect.position.y < layout.gates[0].cells[0].y, "portal beyond the gate")


func test_big_clearing_and_prop_variants() -> void:
	var layout := ClearingGenerator.generate(8)
	check(layout.clearing_rect.size.x >= 90 and layout.clearing_rect.size.y >= 60, "big glade")
	var seen := {}
	for prop in layout.props:
		if prop.type in ["tree", "rock"]:
			seen["%s_%d" % [prop.type, prop.variant]] = true
	check_eq(seen.size(), 20, "all 10 tree and 10 rock variants used")


func test_labyrinth_is_connected_and_returns_to_clearing() -> void:
	for seed_value in [1, 77]:
		var layout := LabyrinthGenerator.generate(seed_value)
		check_eq(layout.portal_target, "clearing", "portal back")
		check(layout.is_walkable(layout.spawn_cell), "spawn walkable")
		var reached := _flood(layout, layout.spawn_cell, {})
		var o := LabyrinthGenerator.cell_origin(Vector2i.ZERO)
		check(reached.has(o + Vector2i.ONE), "far corner reachable (seed %d)" % seed_value)
		var far := LabyrinthGenerator.cell_origin(Vector2i(LabyrinthGenerator.COLS - 1, 0))
		check(reached.has(far + Vector2i.ONE), "opposite corner reachable (seed %d)" % seed_value)
		check(reached.has(layout.portal_rect.position), "portal reachable (seed %d)" % seed_value)


func test_map_border_is_sealed() -> void:
	var layout := ClearingGenerator.generate(99)
	for x in layout.size.x:
		check(layout.is_wall(Vector2i(x, 0)) and layout.is_wall(Vector2i(x, layout.size.y - 1)), "horizontal border at x=%d" % x)
	for y in layout.size.y:
		check(layout.is_wall(Vector2i(0, y)) and layout.is_wall(Vector2i(layout.size.x - 1, y)), "vertical border at y=%d" % y)


func test_spawn_reaches_every_gate_and_ring() -> void:
	for seed_value in [3, 17, 123456]:
		var layout := ClearingGenerator.generate(seed_value)
		var blocked := layout.prop_cells()
		check(layout.is_walkable(layout.spawn_cell, blocked), "spawn walkable (seed %d)" % seed_value)
		var reached := _flood(layout, layout.spawn_cell, blocked)
		for gate in layout.gates:
			for cell in gate.cells:
				check(reached.has(cell), "gate %s reachable (seed %d)" % [gate.side, seed_value])
		var ring_cell := ClearingGenerator.CLEARING_RECT.grow(ClearingGenerator.WALL_THICKNESS).position - Vector2i.ONE
		check(reached.has(ring_cell), "outer ring reachable (seed %d)" % seed_value)


func test_props_on_open_grass() -> void:
	var layout := ClearingGenerator.generate(5)
	var trees := 0
	for prop in layout.props:
		check(not layout.is_wall(prop.cell), "prop not in wall")
		check(layout.clearing_rect.has_point(prop.cell), "prop inside glade")
		if prop.type == "tree":
			trees += 1
			check(layout.get_ground(prop.cell) != TileCatalog.Id.DIRT, "tree not on path")
	check(trees >= 20, "enough trees (%d)" % trees)


func test_wall_faces_only_above_open_cells() -> void:
	var layout := ClearingGenerator.generate(11)
	var low := [TileCatalog.Id.WALL_FACE_LOW, TileCatalog.Id.WALL_FACE_LOW_VINES]
	for y in layout.size.y - 1:
		for x in layout.size.x:
			var cell := Vector2i(x, y)
			if layout.get_wall(cell) in low:
				check(not layout.is_wall(cell + Vector2i.DOWN), "low face above open cell %s" % cell)


func _flood(layout: ClearingLayout, start: Vector2i, blocked: Dictionary) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cell + d
			if not seen.has(n) and layout.is_walkable(n, blocked):
				seen[n] = true
				queue.append(n)
	return seen
