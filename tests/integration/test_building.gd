extends TestCase
## Building, refunds, doors and save/load of structures and the Stash.

const WORLD_SCENE := "res://scenes/world/world.tscn"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _start() -> Node:
	GameState.new_game(2024)
	TimeSystem.reset()
	TimeSystem.set_time_of_day(10 * 60)
	var world: Node = load(WORLD_SCENE).instantiate()
	_tree().root.add_child(world)
	await _tree().physics_frame
	return world


func _free_cell(clearing: ClearingWorld) -> Vector2i:
	var props := clearing.layout.prop_cells()
	var r := clearing.layout.clearing_rect
	for y in range(r.position.y + 5, r.end.y):
		for x in range(r.position.x + 5, r.end.x):
			var c := Vector2i(x, y)
			if not props.has(c) and c != clearing.layout.campfire_cell and c != clearing.layout.spawn_cell:
				return c
	return Vector2i(-1, -1)


func test_recipes_fit_the_panel_and_placeables_are_items() -> void:
	check(ItemCatalog.RECIPES.size() >= 30, "a rich recipe book")
	for t in BuildCatalog.TYPES:
		check(ItemCatalog.ITEMS.has(t), "%s is an item" % t)
		check(FileAccess.file_exists(BuildCatalog.texture_path(t)), "%s art exists" % t)


func test_place_door_remove_and_refund() -> void:
	var world: Node = await _start()
	var clearing: ClearingWorld = world.get_node("Clearing")
	var cell := _free_cell(clearing)
	check(clearing.place_structure(cell, "wooden_wall"), "wall placed")
	check(not clearing.place_structure(cell, "wooden_floor"), "cell occupied")
	check(clearing.build_blocker(Vector2i(0, 0), "wooden_wall") != "", "no building outside the clearing")
	check_eq(clearing.remove_structure(cell), "wooden_wall", "removed type returned")
	check(clearing.place_structure(cell, "wooden_door"), "door placed")
	clearing.toggle_structure(cell)
	check(GameState.structures[cell].open, "door opened")
	world.free()


func test_structures_and_stash_survive_save_load() -> void:
	var world: Node = await _start()
	var clearing: ClearingWorld = world.get_node("Clearing")
	var cell := _free_cell(clearing)
	clearing.place_structure(cell, "chest")
	GameState.stash.add("stone", 7)
	var data: Dictionary = JSON.parse_string(JSON.stringify(SaveSystem.collect()))
	world.free()

	GameState.new_game(2024)
	GameState.stash.load_data(data.stash) # as SaveSystem.load_game does
	GameState.pending_save = data
	world = load(WORLD_SCENE).instantiate()
	_tree().root.add_child(world)
	await _tree().physics_frame
	var restored: ClearingWorld = world.get_node("Clearing")
	check(restored.structure_at(cell) != null, "structure restored")
	check_eq(GameState.stash.count("stone"), 7, "stash restored")
	world.free()


func test_station_recipe_books() -> void:
	var total := 0
	for s in ItemCatalog.STATIONS:
		var book := ItemCatalog.recipes_at(s)
		check(book.size() > 0, "%s has recipes" % s)
		total += book.size()
		if s != "" and s != "campfire":
			check(BuildCatalog.TYPES.has(s) and BuildCatalog.TYPES[s].group == s, "%s is a placeable station" % s)
	check_eq(total, ItemCatalog.RECIPES.size(), "every recipe belongs to a known station")
	check(ItemCatalog.recipes_at("anvil").has(ItemCatalog.RECIPES.find(ItemCatalog.RECIPES.filter(func(r): return r.id == "iron_sword")[0])), "swords at the anvil")


func test_e_on_a_station_opens_its_book() -> void:
	var world: Node = await _start()
	var clearing: ClearingWorld = world.get_node("Clearing")
	var cell := _free_cell(clearing)
	check(clearing.place_structure(cell, "anvil"), "anvil placed")
	var player: Player = GameState.players.get(GameState.local_peer_id())
	player.global_position = ClearingWorld.cell_center(cell + Vector2i(0, 1)) + Vector2(0, 8)
	player.facing = Vector2.UP
	check_eq(player.find_station(), "anvil", "anvil found in front")
	var opened := []
	var on_used := func(s: String) -> void: opened.append(s)
	EventBus.station_used.connect(on_used)
	player._try_gather(true)
	EventBus.station_used.disconnect(on_used)
	check_eq(opened, ["anvil"], "E opens the anvil book")
	check(player.nearby_stations().has("anvil"), "anvil counts for crafting")
	world.free()

func test_farm_plot_offers_seeds_and_grows_the_chosen_crop() -> void:
	var world: Node = await _start()
	var clearing: ClearingWorld = world.get_node("Clearing")
	var cell := _free_cell(clearing)
	check(clearing.place_structure(cell, "farm_plot"), "plot placed")
	var plot: Structure = null
	for s in _tree().get_nodes_in_group("farm_plot"):
		if s.cell == cell:
			plot = s
	var player: Player = GameState.players.get(GameState.local_peer_id())
	player.inventory.add("wheat", 2)
	var asked := []
	var on_used := func(p: Node) -> void: asked.append(p)
	EventBus.farm_plot_used.connect(on_used)
	check(not plot.farm_interact(player), "E on an empty plot does not plant by itself")
	EventBus.farm_plot_used.disconnect(on_used)
	check_eq(asked, [plot], "seed picker requested")
	check(Farming.plantable(player.inventory).has("wheat"), "wheat is sowable")
	check(not plot.farm_interact(player, "carrot"), "no carrot seed")
	check(plot.farm_interact(player, "wheat"), "wheat sown")
	check_eq(player.inventory.count("wheat"), 1, "one wheat used")
	check_eq(plot.crop(), "wheat", "wheat growing")
	check(FileAccess.file_exists("res://assets/sprites/crops/wheat_2.png"), "crop art")
	TimeSystem.clock.total_minutes += Farming.grow_minutes("wheat")
	check(plot.farm_interact(player), "ripe wheat harvested")
	check(player.inventory.count("wheat") >= 1 + Farming.CROPS.wheat.min, "wheat yield")
	check_eq(plot.crop(), "", "plot empty again")
	world.free()


func test_every_crop_uses_real_items() -> void:
	for id in Farming.CROPS:
		var def: Dictionary = Farming.CROPS[id]
		check(ItemCatalog.ITEMS.has(def.seed) and ItemCatalog.ITEMS.has(def.yield), "%s items exist" % id)
		check(def.min <= def.max and def.minutes > 0.0, "%s numbers" % id)
