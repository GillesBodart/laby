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
	var poses := {}
	var heights := {}
	for i in 30:
		await _tree().physics_frame
		poses[player.sprite.frame] = true
		heights[snappedf(player.sprite.get_parent().position.y, 0.1)] = true
	check(player.global_position.y < start.y - 10.0, "moved up")
	check_eq(player.sprite.animation, &"walk_up", "walk animation")
	check(poses.size() >= 3, "steps through the walk-cycle poses")
	check(heights.size() >= 3, "the body rises and falls with each step")

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


func _free_night_creatures() -> void:
	for group in ["ring_prowlers", "raiders"]:
		for e in _tree().get_nodes_in_group(group):
			e.free()


func test_guard_opens_the_shut_gate_at_night() -> void:
	var world: Node = await _start_world(21 * 60 + 30)
	_free_night_creatures()
	var clearing: ClearingWorld = world.get_node("Clearing")
	var player := _local_player()
	var gate: Vector2i = clearing.layout.gates[0].cells[1]
	player.global_position = ClearingWorld.cell_center(gate + Vector2i.UP)
	player.facing = Vector2.UP
	await _frames(2)
	check(not clearing.gates.is_open, "shut at night")
	var latch := player.find_interactable()
	check(latch is GateLatch, "the shut gate can be knocked on from outside")
	GameState.survivors = [{"cast": 0, "role": "gatherer"}]
	latch.interact(player)
	await _frames(2)
	check(not clearing.gates.is_open, "nobody on guard: stays shut")

	GameState.survivors = [{"cast": 0, "role": "gatherer"}, {"cast": 5, "role": "guard"}]
	latch.interact(player)
	await _frames(2)
	check(clearing.gates.is_open, "the guard opens it")
	check(clearing.walls.get_cell_source_id(gate) == -1, "door tile lifted")
	check(player.find_interactable() == null, "nothing to knock on while open")
	clearing.gates._physics_process(ClearingGates.GUARD_OPEN_SECONDS)
	await _frames(2)
	check(not clearing.gates.is_open, "shuts again after a few seconds")
	world.free()


func test_lean_to_waits_for_dawn_at_a_price() -> void:
	var world: Node = await _start_world(21 * 60 + 30)
	_free_night_creatures()
	var player := _local_player()
	var lean: LeanTo = _tree().get_first_node_in_group("lean_to")
	check(lean != null, "a lean-to stands in the ring")
	player.global_position = lean.global_position + Vector2(0, 14)
	player.facing = Vector2.UP
	await _frames(1)
	check(player.find_interactable() == lean, "lean-to in reach")
	player.survival.thirst_enabled = true
	var hunger := player.survival.hunger
	var thirst := player.survival.thirst
	var health := player.survival.health
	lean.interact(player)
	check_eq(int(TimeSystem.minute_of_day()), DayClock.DAWN_START, "woke at 05:00")
	check_eq(player.survival.hunger, hunger - Survival.ROUGH_NIGHT_HUNGER, "hungry")
	check_eq(player.survival.thirst, thirst - Survival.ROUGH_NIGHT_THIRST, "thirsty")
	check(player.survival.health <= health, "no rest heal")
	await _frames(2)
	check(world.get_node("Clearing").gates.is_open, "the gates are open at dawn")
	check(not LeanTo.rest(player), "no waiting by day")
	world.free()


func test_ring_prowlers_stay_out_of_sight_of_the_lean_to() -> void:
	var world: Node = await _start_world(21 * 60 + 30)
	var prowlers := _tree().get_nodes_in_group("ring_prowlers")
	check_eq(prowlers.size(), World.RING_PROWLERS, "creatures prowl the ring at night")
	var lean: LeanTo = _tree().get_first_node_in_group("lean_to")
	var lean_cell := Vector2i((lean.global_position / TileCatalog.TILE_SIZE).floor())
	for e in prowlers:
		var c := Vector2i((e.global_position / TileCatalog.TILE_SIZE).floor())
		check(ClearingGenerator.is_ring_cell(c), "%s in the ring" % c)
		check(not FlowField.sees(world.layout, c, lean_cell), "%s hidden from the lean-to" % c)
		check(not e.patrol.is_empty(), "patrols the ring")
	TimeSystem.set_time_of_day(DayClock.DAWN_START - 1)
	TimeSystem.advance(2.0)
	await _frames(1)
	check(_tree().get_nodes_in_group("ring_prowlers").all(func(e): return e.is_queued_for_deletion()), "gone at dawn")
	world.free()


func _spawn_enemy(world: Node, type: String, cell: Vector2i) -> Enemy:
	var enemy: Enemy = load("res://scenes/entities/enemy.tscn").instantiate()
	enemy.setup(type)
	enemy.position = ClearingWorld.cell_center(cell)
	world.get_node("Clearing").entities.add_child(enemy)
	return enemy


func test_walls_hide_the_player_from_creatures() -> void:
	var world: Node = await _start_world(10 * 60)
	var player := _local_player()
	var r := ClearingGenerator.CLEARING_RECT
	var spot := Vector2i(r.position.x + 16, r.position.y)
	player.global_position = ClearingWorld.cell_center(spot)
	var behind := _spawn_enemy(world, "stalker", spot + Vector2i(0, -ClearingGenerator.WALL_THICKNESS - 1))
	await _frames(20)
	check(behind._target == null, "a creature behind the wall does not start chasing")
	behind.free()
	var seen := _spawn_enemy(world, "stalker", spot + Vector2i(4, 0))
	await _frames(20)
	check(seen._target == player, "a creature in sight gives chase")
	world.free()


func test_creature_keeps_its_home() -> void:
	var world: Node = await _start_world(10 * 60)
	var player := _local_player()
	var r := ClearingGenerator.CLEARING_RECT
	var home_cell := Vector2i(r.position.x + 16, r.position.y + 1)
	var enemy := _spawn_enemy(world, "stalker", home_cell)
	var home := enemy.global_position
	player.global_position = ClearingWorld.cell_center(home_cell + Vector2i(3, 0))
	await _frames(20)
	check(enemy._target == player, "chasing")
	# Out of the leash but near enough that the creature stays awake.
	player.global_position = ClearingWorld.cell_center(home_cell + Vector2i(8, 12))
	enemy.global_position = home + Vector2(8 * TileCatalog.TILE_SIZE, 0)
	await _frames(60)
	check(enemy._target == null, "lost the prey")
	var far := 8.0 * TileCatalog.TILE_SIZE
	await _frames(150)
	check(enemy.global_position.distance_to(home) < far - 48.0, "walks back to where it lived (%.0f -> %.0f)" % [far, enemy.global_position.distance_to(home)])
	world.free()
