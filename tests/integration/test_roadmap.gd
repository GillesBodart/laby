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


func test_dodge_roll_dodges_and_costs_stamina() -> void:
	var world: Node = await _start_world(10 * 60)
	var player := _local_player()
	var start := player.global_position
	var stamina := player.survival.stamina
	check(player.dodge(Vector2.RIGHT), "rolls")
	check(player.survival.stamina < stamina, "costs stamina")
	check(not player.dodge(Vector2.RIGHT), "no chained rolls")
	var hp := player.survival.health
	player.take_damage(20)
	check_eq(player.survival.health, hp, "untouchable mid-roll")
	await _frames(20)
	check(player.global_position.x - start.x > 40.0, "the roll carries the player")
	player.take_damage(20)
	check(player.survival.health < hp, "vulnerable again after")
	player.survival.stamina = 5.0
	await _frames(40)
	player.survival.stamina = 5.0
	check(not player.dodge(Vector2.LEFT), "too tired to roll")
	world.free()


func test_torch_lights_and_wards_night_hunters() -> void:
	var world: Node = await _start_world(23 * 60)
	var player := _local_player()
	for fire in _tree().get_nodes_in_group("campfire"):
		player.global_position = fire.global_position + Vector2(0, 400)
	var jackal: Enemy = load("res://scenes/world/props/enemy.tscn").instantiate()
	jackal.setup("dusk_jackal")
	player.get_parent().add_child(jackal)
	jackal.global_position = player.global_position + Vector2(60, 0)
	check(not jackal._warded(player), "darkness leaves you exposed")
	await _frames(2)
	var dark_scale := player.light.texture_scale
	player.inventory.add("torch", 1)
	check(player.equipment.equip(player.inventory, "torch"), "torch held in the offhand")
	await _frames(2)
	check(player.holds_light(), "holding light")
	check(player.light.texture_scale > dark_scale, "light reaches further")
	check(jackal._warded(player), "the jackal keeps its distance")
	jackal._provoked = true
	check(not jackal._warded(player), "unless provoked")
	world.free()

func test_skill_altar_respecs_for_a_memory_shard() -> void:
	var world: Node = await _start_world(10 * 60)
	var clearing: ClearingWorld = world.get_node("Clearing")
	var player := _local_player()
	var r := clearing.layout.clearing_rect
	var cell := Vector2i(-1, -1)
	var props := clearing.layout.prop_cells()
	for y in range(r.position.y + 5, r.end.y):
		for x in range(r.position.x + 5, r.end.x):
			var c := Vector2i(x, y)
			if cell.x < 0 and not props.has(c) and c != clearing.layout.campfire_cell and c != clearing.layout.spawn_cell:
				cell = c
	check(clearing.place_structure(cell, "skill_altar"), "altar placed")
	var altar: Node2D = _tree().get_nodes_in_group("skill_altar")[0]
	var panel: Control = _tree().get_nodes_in_group("ui_panels").filter(func(p): return p.has_method("open_at_altar"))[0]
	player.survival.skill_points = 3
	check(panel.learn("might"), "panel learns")
	check(not panel.learn("w_berserk"), "keystone out of reach")
	_face(player, altar.global_position)
	check(player.find_interactable() == altar, "altar in reach")
	altar.interact(player)
	await _frames(1)
	check(panel.visible, "altar opens the graph")
	check(not panel.respec(), "respec needs a shard")
	player.inventory.add(Survival.RESPEC_ITEM, 1)
	check(panel.respec(), "respec with a shard")
	check_eq(player.survival.skill_points, 3, "points refunded")
	check_eq(player.inventory.count(Survival.RESPEC_ITEM), 0, "shard spent")
	check(panel.node_at(panel.graph_to_screen(SkillGraph.position("vigor"))) == "vigor", "click finds nodes")
	world.free()

func test_taming_rules_scale_with_beastmaster() -> void:
	check_eq(Taming.tier("hare"), 1, "critters are tier 1")
	check_eq(Taming.tier("sun_wyrm"), -1, "guardians never tame")
	check_eq(Taming.favourite("hare"), "carrot", "species favourite")
	check_eq(Taming.favourite("tusk_boar"), "potato", "boar favourite")
	check_eq(Taming.favourite("dusk_jackal"), "raw_meat", "hunters want meat")
	var s := Survival.new()
	check_eq(Taming.max_tier(s), 1, "non-Beastmasters tame the weakest tier")
	check(Taming.refusal("bramble_bear", 10, 90, s, true, 0).contains("too wild"), "bear too wild")
	s.skill_points = 10
	for id in ["stamina", "b_calm", "b_bond", "b_track", "b_tamer"]:
		check(s.learn(id), "learn " + id)
	check_eq(Taming.max_tier(s), 3, "Beastmaster raises the tier")
	check_eq(Taming.party_cap(s), 2, "and the party cap")
	check(Taming.refusal("bramble_bear", 80, 90, s, true, 0).contains("Weaken"), "must be weakened")
	check_eq(Taming.refusal("bramble_bear", 40, 90, s, true, 0), "", "weakened bear tames")
	check(Taming.refusal("bramble_bear", 40, 90, s, true, 2).contains("full"), "party cap enforced")


func test_tamed_companion_follows_fights_and_persists() -> void:
	var world: Node = await _start_world(10 * 60)
	var player := _local_player()
	for fire in _tree().get_nodes_in_group("campfire"):
		player.global_position = fire.global_position + Vector2(0, 300)
	var hare: Enemy = load("res://scenes/world/props/enemy.tscn").instantiate()
	hare.setup("hare")
	player.get_parent().add_child(hare)
	hare.global_position = player.global_position + Vector2(0, -18)
	player.facing = Vector2.UP
	await _frames(1)
	hare.global_position = player.global_position + Vector2(0, -18)
	check(player.find_interactable() == hare, "gentle creature can be fed")
	check(not hare.tame(player), "no carrot, no friend")
	player.inventory.add("carrot", 2)
	check(hare.tame(player), "tamed with its favourite food")
	check_eq(player.inventory.count("carrot"), 1, "food eaten")
	await _frames(2)
	check_eq(GameState.party_of(player.peer_id).size(), 1, "recorded in the party")
	var pet: Companion = player.companions()[0]
	player.global_position += Vector2(120, 0)
	await _frames(40)
	check(pet.global_position.distance_to(player.global_position) < 60.0, "companion follows")
	var rat: Enemy = load("res://scenes/world/props/enemy.tscn").instantiate()
	rat.setup("cave_rat")
	player.get_parent().add_child(rat)
	rat.global_position = player.global_position + Vector2(40, 0)
	await _frames(1)
	rat._target = player
	rat._provoked = true
	var rat_hp := rat.hp
	await _frames(90)
	check(not is_instance_valid(rat) or rat.hp < rat_hp, "companion attacks hunters")
	player.toggle_companions()
	check(pet.is_staying(), "V: stay")
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.meta_to_data()))
	GameState.companions = []
	GameState.meta_from_data(data)
	check_eq(GameState.companions.size(), 1, "companions saved")
	check_eq(String(GameState.companions[0].type), "hare", "species kept")
	world.free()
	GameState.companions[0].downed = true
	world = await _start_world(10 * 60)
	check(_tree().get_nodes_in_group("companions").is_empty(), "new game clears companions")
	world.free()


func test_downed_companion_recovers_in_the_clearing() -> void:
	GameState.new_game(2024)
	TimeSystem.reset()
	TimeSystem.set_time_of_day(10 * 60)
	var rec := GameState.add_companion("hare", GameState.local_peer_id())
	rec.downed = true
	rec.hp = 0
	var world: Node = load(WORLD_SCENE).instantiate()
	_tree().root.add_child(world)
	await _frames(2)
	check(not rec.downed and rec.hp == rec.max_hp, "healed back home")
	check_eq(_tree().get_nodes_in_group("companions").size(), 1, "back at your side")
	var pet: Companion = _tree().get_nodes_in_group("companions")[0]
	pet.take_damage(999)
	await _frames(1)
	check(rec.downed, "downed after a beating")
	world.free()


## Every maze cell centre and the arena reachable from the vestibule.
func _all_reachable(layout: ClearingLayout) -> bool:
	var seen := {layout.return_cell: true}
	var queue: Array[Vector2i] = [layout.return_cell]
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cur + d
			if layout.in_bounds(n) and not layout.is_wall(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	for my in LabyrinthGenerator.ROWS:
		for mx in LabyrinthGenerator.COLS:
			if not seen.has(LabyrinthGenerator.cell_origin(Vector2i(mx, my)) + Vector2i.ONE):
				return false
	return seen.has(layout.boss.cell)


func test_maze_shifts_stay_connected_and_keep_landmarks() -> void:
	for s in ["labyrinth", "ice"]:
		var base := LabyrinthGenerator.generate(9, s, 0)
		check(base.shift_tiles.is_empty(), "%s: no shift before the first night" % s)
		check_eq(base.landmarks.size(), LabyrinthGenerator.LANDMARK_COUNT, "%s landmarks" % s)
		check_eq(base.glyphs.size(), LabyrinthGenerator.GLYPH_COUNT, "%s glyph stones" % s)
		var moved_any := false
		for shift in [1, 2, 5]:
			var l := LabyrinthGenerator.generate(9, s, shift)
			check(_all_reachable(l), "%s shift %d fully connected" % [s, shift])
			check_eq(l.shift_tiles.size(), LabyrinthGenerator.SHIFT_REGIONS, "%s shift %d regions" % [s, shift])
			check_eq(l.landmarks, base.landmarks, "landmarks never move")
			check_eq(l.glyphs, base.glyphs, "glyph stones never move")
			check_eq(l.enemy_spawns, base.enemy_spawns, "creatures unchanged by the shift")
			check_eq(l.props, base.props, "resources unchanged by the shift")
			var outside_same := true
			for y in l.size.y:
				for x in l.size.x:
					var c := Vector2i(x, y)
					var inside: bool = l.shift_tiles.any(func(r): return r.has_point(c))
					if l.is_wall(c) != base.is_wall(c):
						if inside:
							moved_any = true
						else:
							outside_same = false
			check(outside_same, "%s shift %d only touches its regions" % [s, shift])
			for m in l.landmarks:
				check(not l.shift_tiles.any(func(r): return r.has_point(m.cell)), "landmark outside moving regions")
		check(moved_any, "%s: the walls really move" % s)


func test_fog_uncertainty_and_map_markers_persist() -> void:
	var fog := FogMap.new(Vector2i(30, 30))
	fog.reveal(Vector2i(10, 10), 4)
	fog.mark_uncertain(Rect2i(8, 8, 4, 4))
	check(fog.is_uncertain(Vector2i(9, 9)), "explored cell flagged")
	check(not fog.is_uncertain(Vector2i(25, 25)), "unexplored cells are never uncertain")
	fog.shift = 3
	var copy := FogMap.from_data(JSON.parse_string(JSON.stringify(fog.to_data())))
	check_eq(copy.uncertain_count(), fog.uncertain_count(), "uncertainty saved")
	check_eq(copy.shift, 3, "shift saved")
	copy.reveal(Vector2i(9, 9), 1)
	check(not copy.is_uncertain(Vector2i(9, 9)), "seeing it again clears the doubt")
	GameState.new_game(12)
	GameState.add_marker("labyrinth", "danger", Vector2i(5, 6))
	GameState.add_marker("labyrinth", "door", Vector2i(20, 6))
	GameState.log_journal("creatures", "cave_rat")
	check(not GameState.log_journal("creatures", "cave_rat"), "second sighting is not new")
	var data := SaveSystem.collect()
	GameState.new_game(12)
	GameState.meta_from_data(JSON.parse_string(JSON.stringify(data)).meta)
	check_eq(GameState.markers.get("labyrinth", []).size(), 2, "markers saved")
	check_eq(int(GameState.journal.creatures.cave_rat), 2, "journal counts saved")
	check(GameState.remove_marker_near("labyrinth", Vector2i(6, 6)), "right click removes the nearest")
	check_eq(String(GameState.markers.labyrinth[0].kind), "door", "the other marker stays")


func test_live_shift_moves_walls_and_glyphs_need_insight() -> void:
	GameState.new_game(2024)
	TimeSystem.reset()
	TimeSystem.set_time_of_day(19 * 60 + 50)
	GameState.area = "labyrinth"
	GameState.arriving = false
	var world: Node = load("res://scenes/world/labyrinth.tscn").instantiate()
	_tree().root.add_child(world)
	await _frames(2)
	check_eq(_tree().get_nodes_in_group("landmarks").size(), LabyrinthGenerator.LANDMARK_COUNT + LabyrinthGenerator.GLYPH_COUNT, "landmarks and glyph stones stand")
	var before: PackedInt32Array = world.layout.walls.duplicate()
	for x in world.layout.size.x:
		for y in world.layout.size.y:
			world.fog.reveal(Vector2i(x, y), 0)
	TimeSystem.advance(20)
	await _frames(2)
	var expected := LabyrinthGenerator.generate(2024, "labyrinth", 1)
	var same := true
	for y in expected.size.y:
		for x in expected.size.x:
			var c := Vector2i(x, y)
			if expected.is_wall(c) != world.layout.is_wall(c):
				same = false
			if expected.is_wall(c) != (world.clearing.walls.get_cell_source_id(c) != -1):
				same = false
	check(same, "nightfall turns the maze into tonight's layout")
	check(world.layout.walls != before, "walls changed")
	check(world.fog.uncertain_count() > 0, "the map flags moved passages")
	check_eq(world.fog.shift, 1, "fog knows the shift")
	var player := _local_player()
	var stones := _tree().get_nodes_in_group("landmarks").filter(func(l): return l.kind == "glyph")
	stones.sort_custom(func(a, b): return Glyphs.index_of(a.id) < Glyphs.index_of(b.id))
	stones[0].interact(player)
	check(GameState.in_journal("glyphs", "labyrinth_0"), "first stone needs no insight")
	stones[2].interact(player)
	check(not GameState.in_journal("glyphs", "labyrinth_2"), "deeper stones need glyph insight")
	var statue: Landmark = _tree().get_nodes_in_group("landmarks").filter(func(l): return l.kind == "landmark")[0]
	statue.interact(player)
	check(GameState.in_journal("places", statue.id), "landmark logged")
	var path := preload("res://scripts/ui/map_panel.gd").route(world.layout, world.layout.return_cell, world.layout.boss.cell)
	check(path.size() > 20, "a route to the arena exists after the shift")
	world.free()
	GameState.area = "clearing"

func _structs(types: Dictionary) -> Dictionary:
	var out := {}
	var x := 0
	for t in types:
		for i in types[t]:
			out[Vector2i(x, 0)] = {"type": t}
			x += 1
	return out


func test_settlement_tiers_follow_structures() -> void:
	check_eq(Settlement.tier({}), 0, "a lone camp")
	var s := _structs({"bed": 2, "workbench": 1})
	check_eq(Settlement.tier(s), 1, "beds and a workbench make shelters")
	s = _structs({"bed": 4, "workbench": 1, "furnace": 1, "anvil": 1, "farm_plot": 4, "well": 1})
	check_eq(Settlement.tier(s), 2, "a village")
	check_eq(Settlement.missing(3, s).size(), 4, "fortification still needs beds, walls, door and torches")
	s = _structs({"bed": 8, "workbench": 1, "furnace": 1, "anvil": 1, "cooking_pot": 1, "loom": 1, "stonecutter": 1,
		"farm_plot": 8, "well": 1, "stone_wall": 30, "wooden_door": 1, "standing_torch": 4})
	check_eq(Settlement.tier(s), 3, "a community needs a guardian slain")
	check_eq(Settlement.tier(s, 1), 4, "...and then it is one")


func test_settlement_dawn_feeds_works_and_welcomes() -> void:
	var stash := Inventory.new(40)
	stash.add("cooked_meat", 2)
	stash.add("raw_meat", 3)
	stash.add("herb", 2)
	var people := [{"cast": 0, "role": "gatherer"}, {"cast": 1, "role": "cook"}, {"cast": 2, "role": "healer"}]
	var s := _structs({"bed": 4, "workbench": 1, "furnace": 1, "anvil": 1, "farm_plot": 4, "well": 1})
	var r := Settlement.dawn(people, s, stash)
	check_eq(stash.count("raw_meat"), 0, "the cook used the raw meat")
	check_eq(stash.count("cooked_meat"), 3, "two eaten (cooks don't), three cooked")
	check_eq(stash.count("healing_potion"), 1, "healer brewed the herbs")
	check_eq(stash.count("wood"), 3, "gatherer worked a full day")
	check_eq(int(r.arrival), 3, "fed, housed and room to spare: Pip arrives")
	var hungry := Inventory.new(40)
	var r2 := Settlement.dawn([{"cast": 0, "role": "gatherer"}, {"cast": 1, "role": "gatherer"}], s, hungry)
	check_eq(hungry.count("wood"), 2, "hungry camp works at half pace")
	check_eq(int(r2.arrival), -1, "nobody joins a hungry camp")


func test_survivors_live_in_the_clearing_and_persist() -> void:
	var world: Node = await _start_world(10 * 60)
	check_eq(GameState.survivors.size(), 1, "a new game starts with one survivor")
	await _frames(2)
	var npcs := _tree().get_nodes_in_group("survivors")
	check_eq(npcs.size(), 1, "the survivor walks the camp")
	var player := _local_player()
	check(player.find_interactable() != npcs[0], "the survivor does not block the wake-up spot")
	_face(player, npcs[0].global_position)
	check(player.find_interactable() == npcs[0], "survivor can be talked to")
	GameState.structures[Vector2i(1, 1)] = {"type": "bed", "open": false, "planted": Farming.NOT_PLANTED}
	GameState.structures[Vector2i(2, 1)] = {"type": "bed", "open": false, "planted": Farming.NOT_PLANTED}
	GameState.structures[Vector2i(3, 1)] = {"type": "workbench", "open": false, "planted": Farming.NOT_PLANTED}
	GameState.stash.add("cooked_meat", 3)
	TimeSystem.advance(24 * 60)
	await _frames(2)
	check_eq(GameState.survivors.size(), 2, "a newcomer arrived at dawn")
	check_eq(_tree().get_nodes_in_group("survivors").size(), 2, "and walks the camp")
	GameState.survivors[1].role = Settlement.next_role(GameState.survivors[1].role)
	var data := SaveSystem.collect()
	GameState.survivors = []
	GameState.meta_from_data(JSON.parse_string(JSON.stringify(data)).meta)
	check_eq(GameState.survivors.size(), 2, "survivors restored")
	check_eq(String(GameState.survivors[1].role), "builder", "role kept")
	world.free()

func test_raid_rules_scale_with_tier_and_defence() -> void:
	check_eq(Settlement.raid_size(0, 4, 0), 0, "a lone fire is left alone")
	check_eq(Settlement.raid_size(2, 1, 0), 0, "no raid on the first night")
	check_eq(Settlement.raid_size(2, 3, 0), 0, "raids come every other night")
	check(Settlement.raid_size(3, 4, 0) > Settlement.raid_size(1, 4, 0), "bigger camps draw bigger raids")
	check(Settlement.raid_size(3, 4, 24) < Settlement.raid_size(3, 4, 0), "defence thins them")
	check(BuildCatalog.max_hp("stone_wall") > BuildCatalog.max_hp("wooden_wall"), "stone is tougher")
	check_eq(BuildCatalog.max_hp("wooden_floor"), 0, "floors are not targets")
	check(BuildCatalog.max_hp("wooden_wall", 25.0) > BuildCatalog.max_hp("wooden_wall"), "masonry skill toughens walls")
	check_eq(BuildCatalog.repair_item("wooden_wall"), "plank", "walls are mended with their main material")


func _shelters_camp(world: Node) -> void:
	var fire: Vector2i = world.layout.campfire_cell
	world.clearing.place_structure(fire + Vector2i(3, -3), "bed")
	world.clearing.place_structure(fire + Vector2i(4, -3), "bed")
	world.clearing.place_structure(fire + Vector2i(5, -3), "workbench")
	world.clearing.place_structure(fire + Vector2i(3, 3), "wooden_wall")


func test_night_raid_wrecks_and_guards_fight_back() -> void:
	var world: Node = await _start_world(10 * 60)
	_shelters_camp(world)
	check_eq(GameState.settlement_tier, 1, "the camp became Shelters")
	check_eq(world.start_raid(1), 0, "first night stays calm")
	var n: int = world.start_raid(2)
	check(n > 0, "second night brings raiders")
	await _frames(1)
	var raiders := _tree().get_nodes_in_group("raiders")
	check_eq(raiders.size(), n, "raiders spawned")
	var wall: Structure = world.clearing.structure_at(world.layout.campfire_cell + Vector2i(3, 3))
	wall.damage(30)
	check(wall.is_damaged(), "walls take damage")
	wall.damage(999)
	await _frames(1)
	check(not GameState.structures.has(world.layout.campfire_cell + Vector2i(3, 3)), "and break")
	var e: Enemy = raiders[0]
	e._target = null
	var bed: Structure = world.clearing.structure_at(world.layout.campfire_cell + Vector2i(3, -3))
	e.global_position = bed.global_position + Vector2(0, 20)
	_local_player().global_position = Vector2(-5000, -5000)
	var hurt := func(): return GameState.structures.size() < 3 or GameState.structures.values().any(func(d): return d.has("hp"))
	for i in 300:
		await _tree().physics_frame
		if hurt.call():
			break
	check(hurt.call(), "a raider batters the camp")
	GameState.survivors[0].role = "guard"
	var guard: Survivor = _tree().get_nodes_in_group("survivors")[0]
	var r: Enemy = _tree().get_nodes_in_group("raiders").filter(func(x): return is_instance_valid(x))[0]
	r.global_position = guard.home + Vector2(30, 0)
	var hp_before := r.hp
	for i in 420:
		await _tree().physics_frame
		if not is_instance_valid(r) or r.hp < hp_before:
			break
	check(not is_instance_valid(r) or r.hp < hp_before, "a guard strikes the raider")
	world.end_raid()
	await _frames(1)
	check_eq(_tree().get_nodes_in_group("raiders").size(), 0, "raiders leave at dawn")
	world.free()


func test_raid_while_away_and_builders_mend() -> void:
	GameState.new_game(9)
	var s := _structs({"bed": 2, "workbench": 1, "wooden_wall": 6})
	for c in s:
		s[c]["open"] = false
	GameState.structures = s
	GameState.area = "labyrinth"
	var before := GameState.structures.size()
	GameState.raid_while_away(4)
	var damaged := GameState.structures.values().filter(func(d): return d.has("hp")).size()
	check(damaged > 0 or GameState.structures.size() < before, "the unattended camp got hit")
	GameState.area = "clearing"
	for c in GameState.structures:
		GameState.structures[c]["hp"] = 10
	GameState.survivors = [{"cast": 0, "role": "builder"}]
	GameState.run_dawn()
	var mended := GameState.structures.values().filter(func(d): return not d.has("hp")).size()
	check(mended >= 1, "builders mend at dawn")