extends TestCase
## Late-game systems driven through the real world scene: death remains,
## thirst, light, taming, sectors, glyphs, settlement, raids.

const WORLD_SCENE := "res://scenes/world/world.tscn"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _start_world(minute_of_day: int) -> Node:
	GameState.new_game(2024)
	TimeSystem.reset()
	TimeSystem.set_time_of_day(minute_of_day)
	var world: Node = load(WORLD_SCENE).instantiate()
	_tree().root.add_child(world)
	await _tree().physics_frame
	return world


func _frames(n: int) -> void:
	for i in n:
		await _tree().physics_frame


func _local_player() -> Player:
	return GameState.players.get(GameState.local_peer_id())


## Puts the player one step below `pos`, facing up at it.
func _face(player: Player, pos: Vector2) -> void:
	player.global_position = pos + Vector2(0, 18)
	player.facing = Vector2.UP


func test_death_drops_remains_but_keeps_insured_slots() -> void:
	var world: Node = await _start_world(10 * 60)
	var player := _local_player()
	player.inventory.slots[0] = {"id": "stone", "count": 5}
	player.inventory.slots[3] = {"id": "wood", "count": 7}
	check_eq(player.survival.insured_slots(), 1, "10 strength insures one slot")
	var spot := player.global_position
	player.survival.damage(9999.0)
	await _frames(2)
	check_eq(player.inventory.count("stone"), 5, "insured slot kept")
	check_eq(player.inventory.count("wood"), 0, "rest of the pack dropped")
	check_eq(GameState.remains.size(), 1, "remains recorded")
	var piles := _tree().get_nodes_in_group("remains")
	check_eq(piles.size(), 1, "remains pile spawned")
	check(piles[0].global_position.distance_to(spot) < 1.0, "pile at the death spot")
	_face(player, piles[0].global_position)
	check(player.find_interactable() == piles[0], "pile in reach")
	piles[0].interact(player)
	await _frames(1)
	check_eq(player.inventory.count("wood"), 7, "items recovered")
	check(GameState.remains.is_empty(), "remains cleared")
	world.free()


func test_remains_survive_save_and_load() -> void:
	GameState.new_game(77)
	GameState.add_remains("labyrinth", Vector2(40, 50), [{"id": "wood", "count": 2}])
	var data := SaveSystem.collect()
	GameState.remains = []
	GameState.meta_from_data(JSON.parse_string(JSON.stringify(data)).meta)
	check_eq(GameState.remains.size(), 1, "remains restored")
	check_eq(String(GameState.remains[0].area), "labyrinth", "area kept")
	check_eq(int(GameState.remains[0].items[0].count), 2, "items kept")


func test_every_sector_generates_a_full_maze() -> void:
	var seen := {}
	for s in Sectors.ORDER:
		var a := LabyrinthGenerator.generate(5, s)
		var b := LabyrinthGenerator.generate(5, s)
		check_eq(a.enemy_spawns, b.enemy_spawns, "%s deterministic" % s)
		seen[str(a.props.slice(0, 5))] = true
		var targets := a.all_portals().map(func(p): return p.target)
		check(Sectors.prev_of(s) in targets, "%s leads back" % s)
		check((Sectors.next_of(s) if Sectors.next_of(s) != "" else "escape") in targets, "%s leads on" % s)
		check_eq(a.boss.type, Sectors.info(s).boss, "%s guardian" % s)
		check(EnemyCatalog.def(a.boss.type).boss, "%s guardian is a boss" % s)
		check(a.is_walkable(a.boss.cell), "%s arena open" % s)
		check(a.sector_gate.keys.has(Sectors.info(s).key), "%s gate needs its key" % s)
		check(a.enemy_spawns.size() >= 5, "%s inhabited" % s)
		for e in a.enemy_spawns:
			check_eq(EnemyCatalog.def(e.type).biome, s, "%s spawns its own creatures" % s)
			check(not EnemyCatalog.def(e.type).boss, "no stray bosses in %s" % s)
		var allowed := Sectors.resource_types(s)
		for p in a.props:
			check(p.type in allowed, "%s resource %s belongs" % [s, p.type])
	check_eq(seen.size(), Sectors.ORDER.size(), "every sector has its own layout")
	check_eq(LabyrinthGenerator.generate(5, "hell").sector_gate.keys.size(), 6, "the last gate needs every key")


func test_guardian_keys_unseal_and_persist() -> void:
	GameState.new_game(31)
	check(not GameState.has_keys(["key_stone"]), "starts sealed")
	GameState.defeat_boss("stone_colossus")
	check(GameState.has_keys(["key_stone"]), "the colossus yields its key")
	GameState.reached["desert"] = true
	GameState.escaped = true
	check(GameState.thirst_unlocked(), "the desert unlocks thirst")
	var data := SaveSystem.collect()
	GameState.new_game(31)
	GameState.meta_from_data(JSON.parse_string(JSON.stringify(data)).meta)
	check(GameState.keys.has("key_stone") and GameState.bosses_defeated.has("stone_colossus"), "keys and bosses saved")
	check(GameState.reached.has("desert") and GameState.escaped, "progress saved")
	check_eq(Sectors.prev_of("labyrinth"), "clearing", "first sector backs onto the Clearing")
	check_eq(Sectors.next_of("hell"), "", "the Pit is the last sector")


func test_sector_scene_has_gate_guardian_and_waystone() -> void:
	GameState.new_game(2024)
	TimeSystem.reset()
	TimeSystem.set_time_of_day(10 * 60)
	GameState.area = "desert"
	GameState.arriving = false
	var world: Node = load("res://scenes/world/labyrinth.tscn").instantiate()
	_tree().root.add_child(world)
	await _frames(2)
	check(GameState.reached.has("desert"), "sector marked reached")
	check_eq(_tree().get_nodes_in_group("sector_gate").size(), 1, "gate sealed")
	var bosses := _tree().get_nodes_in_group("enemies").filter(func(e): return e.type_id == "sun_wyrm")
	check_eq(bosses.size(), 1, "guardian waits in its arena")
	var stones := _tree().get_nodes_in_group("waystone")
	check_eq(stones.size(), 1, "a waystone stands in the vestibule")
	var player := _local_player()
	check(player.survival.thirst_enabled, "thirst is on in the desert")
	_face(player, stones[0].global_position)
	check(player.find_interactable() == stones[0], "waystone in reach")
	check_eq(preload("res://scripts/ui/waystone_panel.gd").destinations(), ["clearing", "desert"], "waystone lists reached places")
	GameState.defeat_boss("sun_wyrm")
	await _frames(2)
	check_eq(_tree().get_nodes_in_group("sector_gate").size(), 0, "gate opens with the key")
	world.free()
	GameState.area = "clearing"


func test_water_sources_and_waterskins() -> void:
	var world: Node = await _start_world(10 * 60)
	var player := _local_player()
	player.survival.thirst_enabled = true
	player.survival.thirst = 20.0
	player.inventory.add("waterskin", 2)
	player.drink_at_source()
	check_eq(player.survival.thirst, Survival.MAX_THIRST, "drank its fill")
	check_eq(player.inventory.count("waterskin_full"), 2, "skins filled")
	player.survival.thirst = 10.0
	check(player.use_item("waterskin_full"), "drink from a skin")
	check(player.survival.thirst > 55.0, "skin quenches")
	check_eq(player.inventory.count("waterskin"), 1, "empty skin given back")
	check(player.use_item("warming_tonic") == false, "nothing to use without the tonic")
	player.inventory.add("warming_tonic", 1)
	check(player.use_item("warming_tonic"), "tonics are always drinkable")
	check(player.survival.warmth > 0.0, "warmth buff on")
	world.free()
