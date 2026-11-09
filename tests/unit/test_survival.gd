extends TestCase


func test_hunger_drains_and_eating_restores() -> void:
	var s := Survival.new()
	s.tick(100.0, false, false)
	check(s.hunger < Survival.MAX_HUNGER, "hunger drains")
	var before := s.hunger
	s.eat(5.0)
	check_eq(s.hunger, before + 5.0, "eating restores hunger")
	s.eat(999.0)
	check_eq(s.hunger, Survival.MAX_HUNGER, "hunger is capped")


func test_running_exhausts_then_recovers() -> void:
	var s := Survival.new()
	for i in 90:
		s.tick(0.05, true, true)
	check(not s.can_run(), "exhausted after long run")
	for i in 400:
		s.tick(0.05, false, false)
	check(s.can_run(), "can run again after resting")


func test_starvation_kills() -> void:
	var s := Survival.new()
	s.hunger = 0.0
	var died := [false]
	s.died.connect(func() -> void: died[0] = true)
	for i in 200:
		s.tick(0.5, false, false)
	check(died[0], "died signal emitted")
	check(s.is_dead(), "health reaches zero")
	s.revive()
	check(not s.is_dead() and s.hunger > 0.0, "revive restores needs")


func test_well_fed_regenerates_health() -> void:
	var s := Survival.new()
	s.health = 40.0
	s.tick(10.0, false, false)
	check(s.health > 40.0, "health regenerates while fed")


func test_xp_levels_grant_skill_points() -> void:
	var s := Survival.new()
	check_eq(s.add_xp(Survival.xp_for_level(1) + 5), 1, "one level gained")
	check_eq(s.level, 2, "level 2")
	check_eq(s.skill_points, 1, "skill point granted")
	check_eq(s.xp, 5, "leftover xp kept")


func test_save_round_trip() -> void:
	var s := Survival.new()
	s.hunger = 33.0
	s.add_xp(50)
	var copy := Survival.new()
	copy.load_data(JSON.parse_string(JSON.stringify(s.to_data())))
	check_eq(copy.level, s.level, "level")
	check_eq(copy.hunger, 33.0, "hunger")


func test_food_items() -> void:
	check(ItemCatalog.food_of("berry") > 0.0, "berry is food")
	check_eq(ItemCatalog.food_of("wood"), 0.0, "wood is not food")


func test_skills() -> void:
	var s := Survival.new()
	check(not s.learn("vigor"), "no points")
	s.skill_points = 4
	check(s.learn("vigor"), "learn")
	check_eq(s.max_health(), 115.0, "vigor")
	s.learn("vigor")
	s.learn("vigor")
	check(not s.learn("vigor"), "max rank")
	check_eq(s.skill_points, 1, "points spent")
	s.learn("might")
	check_eq(s.damage_bonus(), 3, "might")
	var t := Survival.new()
	t.load_data(s.to_data())
	check_eq(t.rank("vigor"), 3, "saved ranks")
	check_eq(t.health, 145.0, "health kept")


func test_skill_graph_paths_gates_and_respec() -> void:
	check_eq(SkillGraph.validate(), [], "graph data valid")
	var s := Survival.new()
	s.skill_points = 20
	check(not s.learn("w_edge"), "cluster blocked until its hub root")
	check(s.learn("might") and s.learn("w_edge"), "root opens the cluster")
	check(s.learn("w_hide") and s.learn("w_guard"), "branches")
	check(s.learn("w_crit") and s.learn("w_iron"), "notable then path")
	check(not s.learn("w_berserk"), "keystone sealed before its sector")
	check(s.learn("w_berserk", {"overgrowth": true}), "keystone opens once reached")
	check_eq(s.damage_bonus(), 3 + 2 + 10, "damage stacks")
	check_eq(s.bonus("armor"), 1 + 1 - 3, "keystone trade-off")
	s.learn("fleet")
	check(s.speed_multiplier() > 1.0, "speed bonus")
	var spent := 20 - s.skill_points
	check_eq(s.respec(), spent, "respec refunds every point")
	check_eq(s.skill_points, 20, "points back")
	check_eq(s.damage_bonus(), 0, "bonuses cleared")
	check_eq(s.max_health(), Survival.MAX_HEALTH, "health cap back to base")


func test_thirst_and_climate() -> void:
	var s := Survival.new()
	s.tick(100.0, false, false)
	check_eq(s.thirst, Survival.MAX_THIRST, "thirst sleeps until the desert")
	s.thirst_enabled = true
	s.tick(100.0, false, false)
	check(s.thirst < Survival.MAX_THIRST, "thirst drains once enabled")
	s.thirst = 0.0
	var hp := s.health
	s.tick(1.0, false, false)
	check(s.health < hp, "dehydration hurts")
	s.drink(999.0)
	check_eq(s.thirst, Survival.MAX_THIRST, "drinking is capped")
	check_eq(s.climate_stress(2, 0, 0), 2, "the forge is deadly bare")
	check_eq(s.climate_stress(2, 0, 1), 1, "cool gear helps")
	check_eq(s.climate_stress(-1, 1, 0), 0, "a coat is enough for the ice")
	s.warmth = 60.0
	check_eq(s.climate_stress(-2, 0, 0), 0, "warming buff counts as 2")
	s.warmth = 0.0
	for i in 30:
		s.tick_climate(1.0, 2, 0, 0)
	check_eq(s.temperature, 100.0, "body heats to the extreme")
	hp = s.health
	s.tick(1.0, false, false)
	check(s.health < hp, "extreme heat hurts")
	for i in 30:
		s.tick_climate(1.0, 1, 0, 0)
	hp = s.health
	s.tick(1.0, false, false)
	check(s.health >= hp, "mild heat is bearable")


func test_rooms_need_closed_walls_and_grant_buffs() -> void:
	var st := {}
	# A 3x3 inside ringed by walls, with a door on the south side.
	for x in range(-1, 4):
		for y in range(-1, 4):
			if x == -1 or x == 3 or y == -1 or y == 3:
				st[Vector2i(x, y)] = {"type": "wooden_wall"}
	st[Vector2i(1, 3)] = {"type": "wooden_door", "open": true}
	st[Vector2i(0, 0)] = {"type": "bed", "floor": "stone_floor"}
	st[Vector2i(2, 0)] = {"type": "chest", "floor": "wooden_floor"}
	var room := Rooms.find(st, Vector2i(1, 1))
	check_eq(room.cells.size(), 9, "doors close rooms too")
	check(room.contents.has("bed") and room.contents.has("chest"), "contents found")
	check(not room.floored, "partly floored")
	check_eq(Rooms.key(room), Rooms.key(Rooms.find(st, Vector2i(2, 2))), "same room from any tile")
	var stats := Rooms.stats_of(room)
	check_eq(stats.get("regen", 0), 50, "bed rests")
	check_eq(stats.get("strength", 0), 5, "chest organises")
	check(not stats.has("run_cost"), "no floor comfort yet")
	for x in 3:
		for y in 3:
			var c := Vector2i(x, y)
			if not st.has(c):
				st[c] = {"type": "stone_floor"}
	check(Rooms.find(st, Vector2i(1, 1)).floored, "fully floored")
	check(Rooms.find(st, Vector2i(5, 5)).is_empty(), "outside is no room")
	check(Rooms.find(st, Vector2i(-1, 0)).is_empty(), "a wall is no room")
	st.erase(Vector2i(3, 1))
	check(Rooms.find(st, Vector2i(1, 1)).is_empty(), "a gap opens the room")
	# Too big to be a room: a 9x9 ring.
	var big := {}
	for i in range(-1, 10):
		for c in [Vector2i(i, -1), Vector2i(i, 9), Vector2i(-1, i), Vector2i(9, i)]:
			big[c] = {"type": "stone_wall"}
	check(Rooms.find(big, Vector2i(4, 4)).is_empty(), "81 tiles is a yard")


func test_room_buffs_add_up_then_expire() -> void:
	var s := Survival.new()
	var base := s.max_health()
	s.add_room_buffs({"hp": 15, "dmg": 2}, 10.0)
	check_eq(s.max_health(), base + 15, "cosy room raises max health")
	check_eq(s.bonus("dmg"), 2, "stations make you handy")
	s.add_room_buffs({"hp": 5}, 2.0)
	check_eq(s.bonus("hp"), 15, "best value kept")
	check_eq(Rooms.names_for(s.room_buffs), ["Handy", "Cosy"], "names shown on the HUD")
	var data: Dictionary = JSON.parse_string(JSON.stringify(s.to_data()))
	var t := Survival.new()
	t.load_data(data)
	check_eq(t.bonus("hp"), 15, "room buffs saved")
	s.health = s.max_health()
	s.tick(11.0, false, false)
	check(s.room_buffs.is_empty(), "comfort wears off")
	check(s.health <= s.max_health(), "health clamped to the lower cap")
	s.hunger = 50.0
	s.health = 10.0
	s.sleep()
	check_eq(s.health, s.max_health(), "sleep heals")
	check_eq(s.hunger, 50.0 - Survival.SLEEP_HUNGER, "sleep makes you hungry")