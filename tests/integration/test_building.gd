extends TestCase
## Building, refunds, doors and save/load of structures and the Stash.

const WORLD_SCENE := "res://scenes/world/world.tscn"


## A creature that is always hostile, for the sleep checks.
class HostileStub extends Node2D:
	func _hostile() -> bool:
		return true


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
	var door := clearing.structure_at(cell)
	var player: Player = GameState.players.values()[0]
	player.global_position = ClearingWorld.cell_center(cell + Vector2i.DOWN)
	player.facing = Vector2.UP
	check(player.find_interactable() == door, "E reaches the door outside build mode")
	check_eq(door.interact_hint(), "Close door", "door hint")
	player.global_position = ClearingWorld.cell_center(cell)
	check(not door.use_door() and door.is_open, "won't shut on someone in the doorway")
	player.global_position = ClearingWorld.cell_center(cell + Vector2i.DOWN)
	door.interact(player)
	check(not GameState.structures[cell].open and not door.is_open, "E closes the door")
	door.interact(player)
	check(GameState.structures[cell].open, "E opens it again")
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


func test_build_on_floors_and_join_wall_runs() -> void:
	var world: Node = await _start()
	var clearing: ClearingWorld = world.get_node("Clearing")
	var cell := _free_cell(clearing)
	check(clearing.place_structure(cell, "wooden_floor"), "floor laid")
	check(not clearing.place_structure(cell, "stone_floor"), "no floor on a floor")
	check(clearing.place_structure(cell, "chest"), "chest stands on the floor")
	check(not clearing.place_structure(cell, "workbench"), "one thing per floor tile")
	check_eq(clearing.structure_at(cell).type, "chest", "chest on top")
	check_eq(Settlement.count(GameState.structures, "wooden_floor"), 1, "floor still counts")
	var data: Dictionary = JSON.parse_string(JSON.stringify(clearing.get_save_data()))
	clearing.load_save_data(data)
	check_eq(GameState.structures[cell].get("floor", ""), "wooden_floor", "floor saved under the chest")
	check_eq(clearing.remove_structure(cell), "chest", "chest picked up first")
	check_eq(clearing.structure_at(cell).type, "wooden_floor", "floor left behind")
	check_eq(clearing.remove_structure(cell), "wooden_floor", "then the floor")
	# Raiders wreck what stands on a floor, not the floor.
	clearing.place_structure(cell, "stone_floor")
	clearing.place_structure(cell, "stone_wall")
	clearing.structure_at(cell).damage(9999)
	check_eq(GameState.structures[cell].type, "stone_floor", "wrecked wall leaves its floor")
	clearing.remove_structure(cell)
	# A vertical wall run joins into one wall; only its bottom shows the face.
	var below := cell + Vector2i.DOWN
	clearing.place_structure(cell, "wooden_wall")
	check_eq(clearing.structure_at(cell)._sprite.texture.resource_path, BuildCatalog.texture_path("wooden_wall"), "lone wall")
	check(clearing.place_structure(below, "wooden_wall"), "wall below")
	check_eq(clearing.structure_at(cell)._sprite.texture.resource_path, BuildCatalog.texture_path("wooden_wall", false, 0, "_run_top"), "top of the run")
	check_eq(clearing.structure_at(below)._sprite.texture.resource_path, BuildCatalog.texture_path("wooden_wall", false, 0, "_run_end"), "face at the bottom")
	clearing.remove_structure(below)
	check_eq(clearing.structure_at(cell)._sprite.texture.resource_path, BuildCatalog.texture_path("wooden_wall"), "lone again")
	for w in BuildCatalog.WALLS:
		for j in ["_run_top", "_run_mid", "_run_end"]:
			check(FileAccess.file_exists(BuildCatalog.texture_path(w, false, 0, j)), "%s%s art" % [w, j])
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
	check(FileAccess.file_exists("res://assets/sprites/environment/crops/wheat_2.png"), "crop art")
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


func test_sleep_in_a_closed_room_at_night() -> void:
	var world: Node = await _start()
	var clearing: ClearingWorld = world.get_node("Clearing")
	var player: Player = GameState.players.values()[0]
	var bed := Vector2i(-1, -1)
	var r := clearing.layout.clearing_rect
	for y in range(r.position.y + 3, r.end.y - 3):
		for x in range(r.position.x + 3, r.end.x - 3):
			var ok := true
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var c := Vector2i(x + dx, y + dy)
					ok = ok and clearing.build_blocker(c, "stone_wall") == "" and c != player.cell()
			if ok and bed == Vector2i(-1, -1):
				bed = Vector2i(x, y)
	check(bed != Vector2i(-1, -1), "room for a hut")
	check(clearing.place_structure(bed, "bed"), "bed placed")
	var hint: String = clearing.structure_at(bed).interact_hint()
	check(hint.begins_with("Sleep"), "bed offers sleep")
	TimeSystem.set_time_of_day(22 * 60)
	check(player.sleep_blocker(bed).begins_with("Too exposed"), "an open bed is no place to sleep")
	var ring: Array[Vector2i] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			if Vector2i(x, y) != Vector2i.ZERO:
				ring.append(bed + Vector2i(x, y))
	for c in ring:
		check(clearing.place_structure(c, "wooden_door" if c == bed + Vector2i.DOWN else "stone_wall"), "wall at %s" % c)
	var roofs := _tree().get_nodes_in_group("roofs").filter(func(n): return n.covers(bed))
	check_eq(roofs.size(), 1, "the closed hut gets a roof")
	check(roofs[0].covers(bed + Vector2i(1, 1)), "the roof spans the walls")
	player.global_position = ClearingWorld.cell_center(bed)
	check(roofs[0]._hidden(), "the roof lifts while the player is inside")
	clearing.remove_structure(bed + Vector2i.UP)
	check(_tree().get_nodes_in_group("roofs").filter(func(n): return n.covers(bed)).is_empty(), "an opened hut loses its roof")
	check(clearing.place_structure(bed + Vector2i.UP, "stone_wall"), "wall back")
	for raider in _tree().get_nodes_in_group("raiders"):
		raider.free()
	for e in _tree().get_nodes_in_group("enemies"):
		e.free()
	TimeSystem.set_time_of_day(12 * 60)
	check(player.sleep_blocker(bed).begins_with("You are not tired"), "no sleeping by day")
	TimeSystem.set_time_of_day(22 * 60)
	player.global_position = ClearingWorld.cell_center(bed)
	var foe := HostileStub.new()
	foe.add_to_group("enemies")
	clearing.add_child(foe)
	foe.global_position = ClearingWorld.cell_center(bed + Vector2i(3, 0))
	clearing.toggle_structure(bed + Vector2i.DOWN)
	check(player.sleep_blocker(bed).begins_with("You cannot sleep with enemies"), "an open door lets the prowler in")
	clearing.toggle_structure(bed + Vector2i.DOWN)
	check_eq(player.sleep_blocker(bed), "", "shut in, the prowler outside does not matter")
	foe.global_position = ClearingWorld.cell_center(bed)
	check(player.sleep_blocker(bed) != "", "but one inside the room does")
	foe.free()
	player.survival.health = 20.0
	check(player.try_sleep(bed), "sleeps")
	check_eq(int(TimeSystem.minute_of_day()), DayClock.DAY_START, "wakes at 07:00")
	check_eq(player.survival.health, player.survival.max_health(), "healed")
	check_eq(player.survival.bonus("regen"), 50, "rested all day")
	check(player.survival.room_time > 600.0, "buff lasts the day")
	world.free()