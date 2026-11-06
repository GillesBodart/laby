extends TestCase


func test_catalog_sane() -> void:
	for id in EnemyCatalog.TYPES:
		var d := EnemyCatalog.def(id)
		check(d.hp > 0 and d.damage > 0 and d.speed > 0.0, "%s stats" % id)
		check(ItemCatalog.ITEMS.has(d.drop), "%s drop exists" % id)
		check(ResourceLoader.exists("res://assets/sprites/enemies/%s.png" % id), "%s sprite" % id)


func test_depth_selection() -> void:
	check_eq(EnemyCatalog.type_for_depth(0.1, 0.0), "grub", "shallow grub")
	check_eq(EnemyCatalog.type_for_depth(0.5, 0.1), "stalker", "mid stalker")
	check_eq(EnemyCatalog.type_for_depth(0.9, 0.1), "warden", "deep warden")


func test_labyrinth_spawns() -> void:
	var a := LabyrinthGenerator.generate(5)
	var b := LabyrinthGenerator.generate(5)
	check(a.enemy_spawns.size() >= 5, "has enemies")
	check_eq(a.enemy_spawns, b.enemy_spawns, "deterministic")
	for s in a.enemy_spawns:
		check(a.is_walkable(s.cell), "spawn walkable")
		check(EnemyCatalog.has(s.type), "valid type")
	check(ClearingGenerator.generate(5).enemy_spawns.is_empty(), "no enemies in the clearing")
