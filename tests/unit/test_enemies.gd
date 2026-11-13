extends TestCase


func test_catalog_sane() -> void:
	for id in EnemyCatalog.TYPES:
		var d := EnemyCatalog.def(id)
		check(d.hp > 0 and (d.speed > 0.0 or d.attack == "ranged"), "%s stats" % id)
		check(d.damage > 0 or d.temper == "passive" or d.attack == "summon", "%s can hurt" % id)
		check(d.biome == "forest" or Sectors.is_sector(d.biome), "%s biome" % id)
		for drop in d.drops:
			check(ItemCatalog.ITEMS.has(drop.id), "%s drop %s exists" % [id, drop.id])
		if d.attack == "ranged":
			check(not d.projectile.is_empty(), "%s has a projectile" % id)
		if d.summon != "":
			check(EnemyCatalog.has(d.summon), "%s summons a known creature" % id)
		check(ResourceLoader.exists(EnemyCatalog.sprite_path(id)), "%s sprite" % id)


func test_rosters_are_varied() -> void:
	for biome in ["forest"] + Sectors.ORDER:
		var ids := EnemyCatalog.roster(biome)
		check(ids.size() >= 20, "%s has 20+ creatures (%d)" % [biome, ids.size()])
		var styles := {}
		var shields := 0
		for id in ids:
			styles[EnemyCatalog.def(id).attack] = true
			if EnemyCatalog.def(id).shield > 0.0:
				shields += 1
		check(styles.size() >= 6, "%s mixes attack styles" % biome)
		check(styles.has("ranged"), "%s has ranged attackers" % biome)
		check(shields >= 1, "%s has shielded creatures" % biome)


func test_depth_selection() -> void:
	for i in 40:
		var roll := i / 40.0
		for depth in [0.05, 0.5, 1.2]:
			var id := EnemyCatalog.type_for_depth(depth, roll)
			check(id != "", "something lives at depth %.2f" % depth)
			var band: Array = EnemyCatalog.def(id).depth
			check(depth >= band[0] and depth <= band[1], "%s fits depth %.2f" % [id, depth])
	check_eq(EnemyCatalog.type_for_depth(0.5, 0.3), EnemyCatalog.type_for_depth(0.5, 0.3), "deterministic pick")
	var passive := EnemyCatalog.pick("forest", 0.0, 0.5, func(d: Dictionary) -> bool: return d.temper == "passive")
	check_eq(EnemyCatalog.def(passive).temper, "passive", "filter respected")


func test_hostility() -> void:
	for id in EnemyCatalog.TYPES:
		var t: String = EnemyCatalog.def(id).temper
		if t == "nocturnal":
			check(not EnemyCatalog.is_hostile(id, false) and EnemyCatalog.is_hostile(id, true), "%s hunts at night" % id)
		elif t == "passive":
			check(not EnemyCatalog.is_hostile(id, true), "%s never hunts" % id)


func test_labyrinth_spawns() -> void:
	var a := LabyrinthGenerator.generate(5)
	var b := LabyrinthGenerator.generate(5)
	check(a.enemy_spawns.size() >= 5, "has enemies")
	check_eq(a.enemy_spawns, b.enemy_spawns, "deterministic")
	for s in a.enemy_spawns:
		check(a.is_walkable(s.cell), "spawn walkable")
		check(EnemyCatalog.has(s.type) and EnemyCatalog.def(s.type).biome == "labyrinth", "valid labyrinth type")


func test_every_sector_keeps_elites_and_ordered_glyphs() -> void:
	for s in Sectors.ORDER:
		var entry := LabyrinthGenerator.entry_cell(s)
		var near := ceili(8.0 * LabyrinthGenerator.rows(s) / 14.0)
		for seed_value in [1, 7, 42]:
			var l := LabyrinthGenerator.generate(seed_value, s)
			var elites := l.enemy_spawns.filter(func(e): return EnemyCatalog.def(e.type).elite)
			check(elites.size() >= Sectors.maze(s).get("elite_dens", LabyrinthGenerator.ELITE_DENS), "%s seed %d: every elite den is held" % [s, seed_value])
			var spots := LabyrinthGenerator.glyph_spots(seed_value, s)
			check_eq(spots.size(), LabyrinthGenerator.GLYPH_COUNT, "%s: four glyph stones" % s)
			var rows := spots.map(func(g): return g.mc.y)
			check(rows[0] > rows[3] and rows[1] > rows[3], "%s: the story stone lies deeper than the first ones" % s)
			check(absi(spots[1].mc.x - entry.x) + absi(spots[1].mc.y - entry.y) <= near, "%s: the route stone is near the way in" % s)
			for shift in [1, 3]:
				for r in LabyrinthGenerator.shift_regions(seed_value, s, shift):
					check(not spots.any(func(g): return r.has_point(g.mc)), "%s: glyph stones never shift" % s)


func test_clearing_wildlife_keeps_camp_safe() -> void:
	var layout := ClearingGenerator.generate(5)
	check(layout.enemy_spawns.size() >= 20, "the forest is inhabited")
	var kinds := {}
	for s in layout.enemy_spawns:
		var d := EnemyCatalog.def(s.type)
		kinds[s.type] = true
		check_eq(d.biome, "forest", "%s is a forest creature" % s.type)
		var dist: float = Vector2(s.cell - layout.campfire_cell).length()
		check(dist >= 8.0, "%s not inside the camp" % s.type)
		if d.temper == "hostile":
			check(dist >= 24.0, "%s hunts far from the camp" % s.type)
	check(kinds.size() >= 8, "varied wildlife")


## 9x7 room split by a wall at x=4 with a gap at the bottom (y=5).
func _walled_room() -> ClearingLayout:
	var layout := ClearingLayout.new(Vector2i(9, 7))
	for y in 7:
		for x in 9:
			layout.set_ground(Vector2i(x, y), TileCatalog.Id.GRASS)
			if x == 0 or y == 0 or x == 8 or y == 6 or (x == 4 and y < 5):
				layout.set_wall(Vector2i(x, y), TileCatalog.Id.WALL_TOP)
	return layout


func test_flow_field_leads_around_a_wall() -> void:
	FlowField.clear_shared()
	var layout := _walled_room()
	var target := Vector2i(6, 1)
	var field := FlowField.shared(layout, target)
	check_eq(field.distance(target), 0, "target at distance 0")
	check_eq(field.distance(Vector2i(4, 2)), FlowField.UNREACHED, "wall cells unreached")
	var cell := Vector2i(2, 1)
	check(not FlowField.sees(layout, cell, target), "the wall hides the target")
	var steps := 0
	var went_through_gap := false
	while cell != target and steps < 30:
		var next := field.next_step(cell)
		check(next != FlowField.NO_STEP, "a step from %s" % cell)
		if next == FlowField.NO_STEP:
			break
		check(not layout.is_wall(next), "never steps into a wall (%s)" % next)
		went_through_gap = went_through_gap or next.x == 4
		cell = next
		steps += 1
	check_eq(cell, target, "reaches the target")
	check(went_through_gap, "goes round through the gap")
	check(FlowField.sees(layout, Vector2i(5, 1), target), "clear line on the same side")
	check(FlowField.shared(layout, target) == field, "field shared per layout and target")
	check(FlowField.shared(layout, target, {Vector2i(4, 5): true}) != field, "extra blocked cells get their own field")


func test_flow_field_rebuilds_when_walls_move() -> void:
	FlowField.clear_shared()
	var layout := _walled_room()
	var field := FlowField.shared(layout, Vector2i(6, 1))
	check(field.distance(Vector2i(2, 1)) > 0, "reachable through the gap")
	layout.set_wall(Vector2i(4, 5), TileCatalog.Id.WALL_TOP)
	FlowField._sig_time = -FlowField.WALL_POLL_MS # skip the once-per-second wall poll
	check(FlowField.shared(layout, Vector2i(6, 1)) == field, "same shared field, rebuilt in place")
	check_eq(field.distance(Vector2i(2, 1)), FlowField.UNREACHED, "sealed off once the gap closes")


func test_resources_per_biome() -> void:
	var lists := [ResourceCatalog.FOREST]
	for s in Sectors.ORDER:
		lists.append(Sectors.resource_types(s))
	for list in lists:
		check(list.size() >= 20, "20 resources per biome")
		for t in list:
			check(ResourceCatalog.has(t) or t in ["tree", "rock", "bush"], "%s is a resource node" % t)
			if ResourceCatalog.has(t):
				check(ItemCatalog.ITEMS.has(ResourceCatalog.NODES[t].item), "%s yields a known item" % t)
				check(ResourceLoader.exists("res://assets/sprites/environment/gatherables/%s.png" % t), "%s sprite" % t)
	var lab := LabyrinthGenerator.generate(5)
	var kinds := {}
	for p in lab.props:
		if ResourceCatalog.has(p.type):
			kinds[p.type] = true
	check(kinds.size() >= 12, "labyrinth spawns many resource kinds (%d)" % kinds.size())