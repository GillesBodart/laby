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
		var far := LabyrinthGenerator.cell_origin(Vector2i(LabyrinthGenerator.cols("labyrinth") - 1, 0))
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
		if prop.type in ClearingWorld.FIXTURES:
			continue
		check(layout.clearing_rect.has_point(prop.cell), "prop inside glade")
		if prop.type == "tree":
			trees += 1
			check(layout.get_ground(prop.cell) != TileCatalog.Id.DIRT, "tree not on path")
	check(trees >= 20, "enough trees (%d)" % trees)


func test_build_plot_is_clear() -> void:
	for seed_value in [5, 42, 2024]:
		var layout := ClearingGenerator.generate(seed_value)
		var plot := ClearingGenerator.build_plot(layout.campfire_cell)
		for prop in layout.props:
			check(not plot.has_point(prop.cell), "no %s in the build plot at %s (seed %d)" % [prop.type, prop.cell, seed_value])
		for y in range(plot.position.y, plot.end.y):
			for x in range(plot.position.x, plot.end.x):
				check(layout.is_walkable(Vector2i(x, y)), "plot cell %d,%d open (seed %d)" % [x, y, seed_value])


func test_gate_fixtures() -> void:
	var layout := ClearingGenerator.generate(9)
	var gate_x: int = layout.gates[0].cells[1].x
	var by_type := {}
	for prop in layout.props:
		if prop.type in ClearingWorld.FIXTURES:
			by_type[prop.type] = by_type.get(prop.type, []) + [prop.cell]
	check_eq(by_type.get("brazier", []).size(), 2, "two braziers")
	for cell in by_type.get("brazier", []):
		check(layout.clearing_rect.has_point(cell) and absi(cell.x - gate_x) == ClearingGenerator.BRAZIER_SPREAD, "brazier beside the gate at %s" % cell)
		check(layout.is_walkable(cell), "brazier on open ground")
	check_eq(by_type.get("lean_to", []).size(), 1, "one lean-to")
	var lean: Vector2i = by_type.lean_to[0]
	check(ClearingGenerator.is_ring_cell(lean) and layout.is_walkable(lean), "lean-to in the open ring at %s" % lean)


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


func test_ponds_block_and_reeds_grow_on_banks() -> void:
	var layout := ClearingGenerator.generate(5)
	check(layout.ponds.size() > 0, "ponds generated")
	var water := 0
	for y in layout.size.y:
		for x in layout.size.x:
			if layout.get_ground(Vector2i(x, y)) == TileCatalog.Id.WATER:
				water += 1
				check(not layout.is_walkable(Vector2i(x, y)), "water not walkable")
	check(water > 0, "water cells")
	for prop in layout.props:
		if prop.type != "reeds":
			continue
		var near := false
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var n: Vector2i = prop.cell + Vector2i(dx, dy)
				if layout.in_bounds(n) and layout.get_ground(n) == TileCatalog.Id.WATER:
					near = true
		check(near, "reeds at %s beside water" % prop.cell)


func test_dirt_overlay_rounds_outer_corners() -> void:
	var layout := ClearingGenerator.generate(5)
	var tile := TileCatalog.TILE_SIZE
	var chunks := DirtOverlay.build(layout, tile, 5)
	check(chunks.size() > 0, "dirt chunks painted")
	var pixel := func(p: Vector2i) -> Color:
		for chunk in chunks:
			var local: Vector2i = p - Vector2i(chunk.pos)
			if Rect2i(Vector2i.ZERO, chunk.image.get_size()).has_point(local):
				return chunk.image.get_pixelv(local)
		return Color(0, 0, 0, 0)
	var corners := 0
	for y in range(1, layout.size.y - 1):
		for x in range(1, layout.size.x - 1):
			var c := Vector2i(x, y)
			if layout.get_ground(c) != TileCatalog.Id.DIRT:
				continue
			var dirt := func(d: Vector2i) -> bool: return layout.get_ground(c + d) == TileCatalog.Id.DIRT
			var grass := func(d: Vector2i) -> bool: return layout.get_ground(c + d) in [TileCatalog.Id.GRASS, TileCatalog.Id.GRASS_ALT, TileCatalog.Id.GRASS_FLOWERS]
			if not (grass.call(Vector2i(-1, 0)) and grass.call(Vector2i(0, -1)) and grass.call(Vector2i(-1, -1))):
				continue
			if not (dirt.call(Vector2i(1, 0)) and dirt.call(Vector2i(0, 1)) and dirt.call(Vector2i(1, 1))):
				continue
			corners += 1
			check(pixel.call(c * tile).a < 0.5, "corner %s rounded off" % c)
			check(pixel.call(c * tile + Vector2i(tile - 2, tile - 2)).a == 1.0, "inner side of %s is dirt" % c)
	check(corners > 0, "found outer corners")


func test_pond_art_is_never_clipped() -> void:
	for s in [1, 5, 9, 42, 77, 2024]:
		for pond in ClearingGenerator.generate(s).ponds:
			var img := Pond.paint(pond.blobs, 16, pond.seed)
			var clipped := 0
			for x in img.get_width():
				clipped += int(img.get_pixel(x, 0).a > 0.0) + int(img.get_pixel(x, img.get_height() - 1).a > 0.0)
			for y in img.get_height():
				clipped += int(img.get_pixel(0, y).a > 0.0) + int(img.get_pixel(img.get_width() - 1, y).a > 0.0)
			check_eq(clipped, 0, "seed %d pond border is transparent" % s)
func test_labyrinth_chambers_open_and_dead_ends_rewarded() -> void:
	var layout := LabyrinthGenerator.generate(9)
	var rooms := LabyrinthGenerator.chambers(9, "labyrinth")
	check_eq(rooms.size(), Sectors.maze("labyrinth").chambers, "chamber count")
	for r: Rect2i in rooms:
		var tiles := LabyrinthGenerator.region_tiles(r)
		var open := true
		for y in range(tiles.position.y, tiles.end.y):
			for x in range(tiles.position.x, tiles.end.x):
				open = open and not layout.is_wall(Vector2i(x, y))
		check(open, "chamber %s fully open" % r)
	# Caches sit mid-edge of a cell, against its back wall.
	var caches := 0
	for p in layout.props:
		var local: Vector2i = p.cell - LabyrinthGenerator.cell_origin(Vector2i.ZERO)
		var off := Vector2i(posmod(local.x, LabyrinthGenerator.PITCH), posmod(local.y, LabyrinthGenerator.PITCH))
		if off in [Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2)]:
			caches += 1
			var back: Vector2i = p.cell + (off - Vector2i.ONE)
			check(layout.is_wall(back), "cache %s backs onto a wall" % p.cell)
	check(caches >= 5, "dead ends hold caches (%d)" % caches)


## Tiles that stop a walker: every prop but thorn curtains (an axe cuts them),
## plus landmarks, glyph stones and chests. Magma vents are not props.
func _maze_blockers(layout: ClearingLayout) -> Dictionary:
	var blocked := {}
	for p in layout.props:
		if p.type not in [LabyrinthGenerator.CURTAIN, LabyrinthGenerator.CURTAIN_V]:
			blocked[p.cell] = true
	for list in [layout.landmarks, layout.glyphs, layout.chests]:
		for e in list:
			blocked[e.cell] = true
	return blocked


func _touches(reached: Dictionary, cell: Vector2i) -> bool:
	return [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].any(func(d): return reached.has(cell + d))


func _route_tiles(layout: ClearingLayout) -> int:
	var blocked := _maze_blockers(layout)
	var dist := {layout.return_cell: 0}
	var queue: Array[Vector2i] = [layout.return_cell]
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		if cur == layout.boss.cell:
			return dist[cur]
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cur + d
			if not dist.has(n) and layout.is_walkable(n, blocked):
				dist[n] = dist[cur] + 1
				queue.append(n)
	return -1


func test_sector_mazes_stay_fair_through_shifts() -> void:
	for s in Sectors.ORDER:
		for seed_value in range(1, 11):
			for shift in 6:
				var l := LabyrinthGenerator.generate(seed_value, s, shift)
				var reached := _flood(l, l.return_cell, _maze_blockers(l))
				var lost := []
				for my in LabyrinthGenerator.rows(s):
					for mx in LabyrinthGenerator.cols(s):
						var o := LabyrinthGenerator.cell_origin(Vector2i(mx, my))
						var any := false
						for t in 9:
							any = any or reached.has(o + Vector2i(t % 3, t / 3))
						if not any:
							lost.append(Vector2i(mx, my))
				for e in l.chests + l.glyphs:
					if not _touches(reached, e.cell):
						lost.append(e.cell)
				if not reached.has(l.boss.cell):
					lost.append("arena")
				check(lost.is_empty(), "%s seed %d shift %d: all reachable %s" % [s, seed_value, shift, lost])


func test_sector_maze_sizes_depth_and_glyph_order() -> void:
	for s in Sectors.ORDER:
		var m := Sectors.maze(s)
		for seed_value in [3, 8]:
			var l := LabyrinthGenerator.generate(seed_value, s)
			check_eq(l.size, LabyrinthGenerator.map_size(s), "%s map size" % s)
			check(LabyrinthGenerator.region_tiles(LabyrinthGenerator.arena(s)).has_point(l.boss.cell), "%s boss in its arena" % s)
			check_eq(LabyrinthGenerator.cols(s), int(m.cols), "%s cols from data" % s)
			check_eq(LabyrinthGenerator.rows(s), int(m.rows), "%s rows from data" % s)
			var door := LabyrinthGenerator.door_cell(s)
			check(is_equal_approx(LabyrinthGenerator.cell_depth(seed_value, s, door), 1.0), "%s: the arena door is the deepest point of the route" % s)
			var spots := LabyrinthGenerator.glyph_spots(seed_value, s)
			check(LabyrinthGenerator.cell_depth(seed_value, s, spots[1].mc) < 1.0, "%s: stone 1 is closer than the arena" % s)
		check(LabyrinthGenerator.map_size(s).x > LabyrinthGenerator.map_size("labyrinth").x or s == "labyrinth", "%s is bigger than the first sector" % s)


func test_shifts_lengthen_the_route_on_median() -> void:
	var changes: Array = []
	for s in Sectors.ORDER:
		for seed_value in range(1, 6):
			var base := _route_tiles(LabyrinthGenerator.generate(seed_value, s, 0))
			for shift in [1, 2, 3]:
				changes.append(_route_tiles(LabyrinthGenerator.generate(seed_value, s, shift)) - base)
	changes.sort()
	check(changes[changes.size() / 2] >= 0, "median route change after a shift >= 0 (%s)" % [changes])


func test_sector_signatures() -> void:
	var home := LabyrinthGenerator.generate(6, "ice")
	check_eq(LabyrinthGenerator.cells_home(home, "ice", home.return_cell), 0, "the vestibule is home")
	var far := LabyrinthGenerator.cells_home(home, "ice", LabyrinthGenerator.cell_origin(LabyrinthGenerator.door_cell("ice")) + Vector2i.ONE)
	check(far >= LabyrinthGenerator.rows("ice") - 4, "the arena door is a long walk home (%d cells)" % far)
	check(LabyrinthGenerator.dusk_warning_due(30.0, far) and not LabyrinthGenerator.dusk_warning_due(600.0, far), "warned only when the light runs short")
	var counts := {}
	for s in Sectors.ORDER:
		var l := LabyrinthGenerator.generate(4, s)
		counts[s] = {
			"curtains": l.props.filter(func(p): return p.type in [LabyrinthGenerator.CURTAIN, LabyrinthGenerator.CURTAIN_V]).size(),
			"palms": l.props.filter(func(p): return p.type == "date_palm").size(),
			"fires": l.props.filter(func(p): return p.type == "campfire").size(),
			"vents": l.hazards.size(),
		}
		for h in l.hazards:
			check(not l.is_wall(h.rect.position), "%s vent on open ground" % s)
	check(counts.overgrowth.curtains >= 6 and counts.overgrowth.curtains <= 10, "thorn curtains in the Overgrowth (%d)" % counts.overgrowth.curtains)
	check(counts.desert.palms >= 2, "oases in the Dunes")
	check_eq(counts.ice.fires - counts.labyrinth.fires, 3, "warming braziers in the Rime Halls")
	check(counts.volcano.vents >= 6, "magma vents in the Forge")
	for s in ["labyrinth", "hell"]:
		check_eq(counts[s].curtains + counts[s].palms + counts[s].vents, 0, "%s keeps to its walls" % s)

func test_clearing_woods_meadow_and_habitats() -> void:
	for seed_value in [5, 7]:
		var layout := ClearingGenerator.generate(seed_value)
		var center := layout.campfire_cell
		var inner := ClearingGenerator.CLEARING_RECT.grow(-2)
		var near_fire := 0
		var woods := 0
		var meadow := 0
		for p in layout.props:
			var edge := ClearingGenerator._edge(p.cell, center, inner)
			check(ClearingGenerator._fits_habitat(p.type, edge), "%s at %s fits its habitat" % [p.type, p.cell])
			if p.type != "tree":
				continue
			near_fire += int(Vector2(p.cell - center).length() <= 14.0)
			woods += int(edge >= 0.6)
			meadow += int(edge < 0.4)
		check(near_fire >= 4, "a grove near the camp (%d trees, seed %d)" % [near_fire, seed_value])
		check(woods > meadow * 2, "woods along the walls (%d) outnumber meadow trees (%d)" % [woods, meadow])
