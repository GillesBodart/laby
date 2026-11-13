extends TestCase


func test_goals_reference_real_content() -> void:
	for g in Objectives.GOALS:
		if g.has("item"):
			for id in g.item[0]:
				check(ItemCatalog.ITEMS.has(id), "%s: item %s exists" % [g.id, id])
		if g.has("build"):
			for t in g.build[0]:
				check(BuildCatalog.TYPES.has(t), "%s: structure %s exists" % [g.id, t])
		if g.has("boss"):
			check(EnemyCatalog.has(g.boss), "%s: boss %s exists" % [g.id, g.boss])
		if g.has("reach"):
			check(Sectors.ORDER.has(g.reach), "%s: area %s exists" % [g.id, g.reach])
	check_eq(Objectives.ids().size(), Objectives.GOALS.size(), "goal count")
	check_eq(Objectives.GOALS[-1].id, "escape", "the chain ends with the escape")


func test_chain_advances_in_order_and_remembers() -> void:
	var done := {}
	check_eq(Objectives.current(done).id, "wood", "starts with wood")
	var ctx := {"items": {"wood": 3}}
	check_eq(Objectives.progress(Objectives.current(done), ctx), [3, 6], "partial progress")
	check(Objectives.update(done, ctx).is_empty(), "3 wood is not enough")
	# Goals later in the chain can be met early: they are ticked off too.
	ctx = {"items": {"wood": 6, "stone_pickaxe": 1}, "reached": {"labyrinth": true}}
	check_eq(Objectives.update(done, ctx), ["wood", "tool", "maze"], "met goals, in chain order")
	check_eq(Objectives.current(done).id, "stone", "first unmet goal is next")
	# Spending the wood does not undo the goal.
	check(Objectives.update(done, {"items": {}}).is_empty(), "nothing new")
	check_eq(Objectives.current(done).id, "stone", "wood stays done")


func test_room_goal_needs_a_closed_room_with_a_bed() -> void:
	var saved: Dictionary = GameState.structures
	var s := {}
	for x in range(0, 5):
		for y in range(0, 4):
			if x == 0 or x == 4 or y == 0 or y == 3:
				s[Vector2i(x, y)] = {"type": "wooden_wall"}
	GameState.structures = s
	check_eq(Objectives.context(null).rooms, 1, "an empty closed room is a house")
	s[Vector2i(2, 1)] = {"type": "bed"}
	check_eq(Objectives.context(null).rooms_with_bed, 1, "walled bed counts")
	check_eq(Objectives.context(null).rooms, 1, "still one house")
	s.erase(Vector2i(4, 2))
	check_eq(Objectives.context(null).rooms_with_bed, 0, "a gap in the wall is no room")
	check_eq(Objectives.context(null).rooms, 0, "a gap in the wall is no house")
	GameState.structures = saved


func test_house_comes_before_the_bed() -> void:
	var ids := Objectives.ids()
	check(ids.find("workbench") < ids.find("house"), "workbench before house")
	check(ids.find("house") < ids.find("bed"), "house before bed")
