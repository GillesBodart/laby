extends TestCase
## Loads the real world scene and drives it with simulated input/time.

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


func test_player_walks_and_is_blocked_by_walls() -> void:
	var world: Node = await _start_world(10 * 60)
	var player := _local_player()
	check(player != null, "player spawned")
	var start := player.global_position
	Input.action_press("move_up")
	await _frames(30)
	check(player.global_position.y < start.y - 10.0, "moved up")

	var clearing := ClearingGenerator.CLEARING_RECT
	player.global_position = ClearingWorld.cell_center(Vector2i(clearing.position.x + 3, clearing.position.y + 1))
	await _frames(90)
	Input.action_release("move_up")
	check(player.global_position.y > clearing.position.y * TileCatalog.TILE_SIZE, "stopped by the clearing wall")
	world.free()


func test_gates_close_at_night_and_reopen_at_dawn() -> void:
	var world: Node = await _start_world(DayClock.NIGHT_START - 1)
	var clearing: ClearingWorld = world.get_node("Clearing")
	var gate_cell: Vector2i = clearing.layout.gates[0].cells[0]
	check(clearing.walls.get_cell_source_id(gate_cell) == -1, "gate open before night")

	TimeSystem.advance(2.0)
	await _frames(1)
	check(not clearing.gates.is_open, "gates closed at night")
	check_eq(clearing.walls.get_cell_atlas_coords(gate_cell), TileCatalog.atlas_coords(TileCatalog.Id.GATE_CLOSED), "door tile placed")

	TimeSystem.set_time_of_day(DayClock.DAWN_START - 1)
	TimeSystem.advance(2.0)
	await _frames(1)
	check(clearing.gates.is_open, "gates open at dawn")
	check(clearing.walls.get_cell_source_id(gate_cell) == -1, "door tile removed")
	world.free()


func test_save_then_rebuild_restores_player_and_time() -> void:
	var world: Node = await _start_world(15 * 60)
	var spot := ClearingWorld.cell_center(ClearingGenerator.CLEARING_RECT.position + Vector2i(4, 4))
	_local_player().global_position = spot
	var data: Dictionary = JSON.parse_string(JSON.stringify(SaveSystem.collect()))
	world.free()

	TimeSystem.reset()
	GameState.world_seed = int(data.seed)
	GameState.pending_save = data
	TimeSystem.load_save_data(data.time)
	world = load(WORLD_SCENE).instantiate()
	_tree().root.add_child(world)
	await _tree().physics_frame
	check(_local_player().global_position.distance_to(spot) < 1.0, "player position restored")
	check_eq(int(TimeSystem.minute_of_day()) / 60, 15, "time restored")
	world.free()


func test_gathering_a_tree_yields_wood_and_persists() -> void:
	var world: Node = await _start_world(10 * 60)
	var player := _local_player()
	var tree: Gatherable = null
	for n in _tree().get_nodes_in_group("gatherable"):
		if n.item_id == "wood":
			tree = n
			break
	check(tree != null, "tree exists")
	player.global_position = tree.global_position + Vector2(0, 6)
	player.facing = Vector2.UP
	check(player.find_gatherable() == tree, "tree in reach")
	var cell := tree.cell
	for i in tree.max_hits:
		if is_instance_valid(tree):
			tree.hit(player)
	check_eq(player.inventory.count("wood"), 3, "wood gathered")
	var data: Dictionary = JSON.parse_string(JSON.stringify(SaveSystem.collect()))
	world.free()

	GameState.pending_save = data
	world = load(WORLD_SCENE).instantiate()
	_tree().root.add_child(world)
	await _tree().physics_frame
	check_eq(_local_player().inventory.count("wood"), 3, "inventory restored")
	var clearing: ClearingWorld = world.get_node("Clearing")
	for n in _tree().get_nodes_in_group("gatherable"):
		check(n.cell != cell, "depleted tree stays gone")
	world.free()


func test_walking_through_the_gate_travels_to_labyrinth_and_back() -> void:
	var world: Node = await _start_world(10 * 60)
	var layout: ClearingLayout = world.layout
	var requested: Array[String] = []
	GameState.scene_changer = func(path: String) -> void: requested.append(path)
	_local_player().inventory.add("wood", 4)
	_local_player().global_position = ClearingWorld.cell_center(layout.portal_rect.position + Vector2i(1, 1))
	await _frames(3)
	check_eq(requested, ["res://scenes/world/labyrinth.tscn"], "labyrinth requested once")
	check_eq(GameState.area, "labyrinth", "area switched")
	world.free()

	var lab: World = load(GameState.area_scene()).instantiate()
	_tree().root.add_child(lab)
	await _tree().physics_frame
	check_eq(lab.layout.portal_target, "clearing", "labyrinth portal")
	check_eq(_local_player().inventory.count("wood"), 4, "backpack carried over")
	check_eq(ClearingWorld.cell_center(lab.layout.return_cell), _local_player().global_position, "arrives at the vestibule")
	_local_player().global_position = ClearingWorld.cell_center(lab.layout.portal_rect.position + Vector2i(1, 1))
	await _frames(3)
	check_eq(GameState.area, "clearing", "back in the clearing")
	check_eq(requested.size(), 2, "clearing requested")
	GameState.scene_changer = Callable()
	lab.free()


func test_gate_waits_for_player_to_step_off() -> void:
	var world: Node = await _start_world(DayClock.NIGHT_START - 1)
	var clearing: ClearingWorld = world.get_node("Clearing")
	var gate_cell: Vector2i = clearing.layout.gates[0].cells[1]
	var player := _local_player()
	player.global_position = ClearingWorld.cell_center(gate_cell)
	await _frames(1)

	TimeSystem.advance(2.0)
	await _frames(2)
	check(clearing.walls.get_cell_source_id(gate_cell) == -1, "occupied gate cell stays open")

	player.global_position = ClearingWorld.cell_center(clearing.layout.spawn_cell)
	await _frames(2)
	check(clearing.walls.get_cell_source_id(gate_cell) != -1, "gate cell closes once free")
	world.free()

func test_player_kills_enemy_and_enemy_hurts_player() -> void:
	var world: Node = await _start_world(10 * 60)
	var player := _local_player()
	var enemy: Enemy = load("res://scenes/entities/enemy.tscn").instantiate()
	enemy.setup("grub")
	world.add_child(enemy)
	player.facing = Vector2.RIGHT
	enemy.global_position = player.global_position + Vector2(20, 0)
	var hp_before := player.survival.health
	await _frames(40)
	check(player.survival.health < hp_before, "enemy bit the player")
	var xp_before := player.survival.xp
	Input.action_press("attack")
	await _frames(120)
	Input.action_release("attack")
	check(not is_instance_valid(enemy) or enemy.is_queued_for_deletion(), "enemy killed")
	check(player.survival.xp > xp_before or player.survival.level > 1, "xp gained")
	world.free()


func test_bow_shoots_toward_the_aim() -> void:
	var world: Node = await _start_world(10 * 60)
	var player := _local_player()
	player.inventory.add("short_bow", 1)
	player.equipment.equip(player.inventory, "short_bow")
	player.inventory.add("flint_arrow", 2)
	player.facing = Vector2.UP
	player.input.aim_dir = Vector2(3, 1).normalized()
	check(player._fire("arrow"), "arrow fired")
	var shot: Projectile = null
	for n in player.get_parent().get_children():
		if n is Projectile:
			shot = n
	check(shot != null and shot.velocity.normalized().is_equal_approx(Vector2(3, 1).normalized()), "flies toward the mouse")
	check_eq(player.facing, Vector2.RIGHT, "player turns toward the shot")
	world.free()
