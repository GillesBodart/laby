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
