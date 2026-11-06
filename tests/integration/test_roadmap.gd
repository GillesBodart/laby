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
