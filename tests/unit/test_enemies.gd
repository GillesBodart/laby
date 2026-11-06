extends TestCase


func test_catalog_sane() -> void:
	for id in EnemyCatalog.TYPES:
		var d := EnemyCatalog.def(id)
		check(d.hp > 0 and (d.speed > 0.0 or d.attack == "ranged"), "%s stats" % id)
		check(d.damage > 0 or d.temper == "passive" or d.attack == "summon", "%s can hurt" % id)
		check(d.biome in ["forest", "labyrinth"], "%s biome" % id)
		for drop in d.drops:
			check(ItemCatalog.ITEMS.has(drop.id), "%s drop %s exists" % [id, drop.id])
		if d.attack == "ranged":
			check(not d.projectile.is_empty(), "%s has a projectile" % id)
		if d.summon != "":
			check(EnemyCatalog.has(d.summon), "%s summons a known creature" % id)
		check(ResourceLoader.exists(EnemyCatalog.sprite_path(id)), "%s sprite" % id)


func test_rosters_are_varied() -> void:
	for biome in ["forest", "labyrinth"]:
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


func test_resources_per_biome() -> void:
	for list in [ResourceCatalog.FOREST, ResourceCatalog.LABYRINTH]:
		check(list.size() >= 20, "20 resources per biome")
		for t in list:
			if ResourceCatalog.has(t):
				check(ItemCatalog.ITEMS.has(ResourceCatalog.NODES[t].item), "%s yields a known item" % t)
				check(ResourceLoader.exists("res://assets/sprites/resources/%s.png" % t), "%s sprite" % t)
	var lab := LabyrinthGenerator.generate(5)
	var kinds := {}
	for p in lab.props:
		if ResourceCatalog.has(p.type):
			kinds[p.type] = true
	check(kinds.size() >= 12, "labyrinth spawns many resource kinds (%d)" % kinds.size())