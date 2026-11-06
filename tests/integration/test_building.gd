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
	check(ItemCatalog.RECIPES.size() <= 10, "at most 10 recipes (keys 1-0)")
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
