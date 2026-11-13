extends TestCase


func _recipe(id: String) -> Dictionary:
	for r in ItemCatalog.RECIPES:
		if r.id == id:
			return r
	return {}


func test_inventory_stacks_and_overflow() -> void:
	var inv := Inventory.new(2)
	check_eq(inv.add("wood", 70), 0, "fits in two stacks")
	check_eq(inv.count("wood"), 70, "count")
	check_eq(inv.add("wood", 20), 10, "overflow returned")
	check(inv.remove("wood", 30), "remove")
	check_eq(inv.count("wood"), 50, "remaining")
	check(not inv.remove("wood", 99), "cannot remove too many")


func test_inventory_save_round_trip() -> void:
	var inv := Inventory.new()
	inv.add("stone", 7)
	var copy := Inventory.new()
	copy.load_data(JSON.parse_string(JSON.stringify(inv.to_data())))
	check_eq(copy.count("stone"), 7, "restored")


func test_crafting_consumes_and_respects_station() -> void:
	var inv := Inventory.new()
	inv.add("wood", 1)
	check(Crafting.craft(inv, _recipe("plank")), "plank crafted")
	check_eq(inv.count("plank"), 2, "plank yield")
	check_eq(inv.count("wood"), 0, "wood consumed")
	inv.add("plank", 6)
	inv.add("stone", 4)
	check(not Crafting.craft(inv, _recipe("workbench")), "needs campfire")
	check(Crafting.craft(inv, _recipe("workbench"), ["campfire"]), "workbench at campfire")
	check_eq(inv.count("workbench"), 1, "workbench in backpack")


func test_craft_fails_atomically_when_full() -> void:
	var inv := Inventory.new(1)
	inv.add("wood", 1)
	inv.slots[0] = {"id": "wood", "count": 1}
	check(not Crafting.craft(inv, _recipe("torch"), ["campfire"]), "missing sticks")
	var full := Inventory.new(1)
	full.add("stick", 2)
	full.add("wood", 1) # no free slot
	check_eq(full.count("wood"), 0, "wood did not fit")
	check(not Crafting.craft(full, _recipe("torch"), ["campfire"]), "no wood")


func test_craft_draws_from_room_chest() -> void:
	var inv := Inventory.new(4)
	var store := Inventory.new(4)
	inv.add("plank", 2)
	store.add("plank", 10)
	store.add("stone", 4)
	var bench := _recipe("workbench")
	check(not Crafting.can_craft(inv, bench, ["campfire"]), "backpack alone is short")
	check(Crafting.craft(inv, bench, ["campfire"], store), "chest tops up the ingredients")
	check_eq(inv.count("plank"), 0, "backpack used first")
	check_eq(store.count("plank"), 4, "rest taken from the chest")
	check_eq(store.count("stone"), 0, "chest stone used")
	check_eq(inv.count("workbench"), 1, "result lands in the backpack")
	var full := Inventory.new(1)
	full.add("stone_axe", 1)
	store.add("wood", 3)
	check(not Crafting.craft(full, _recipe("plank"), [], store), "backpack full: nothing crafted")
	check_eq(store.count("wood"), 3, "chest untouched on failure")


func test_recipes_reference_known_items() -> void:
	for r in ItemCatalog.RECIPES:
		check(ItemCatalog.ITEMS.has(r.id), "output %s" % r.id)
		for k in r["in"]:
			check(ItemCatalog.ITEMS.has(k), "ingredient %s" % k)

func test_tool_tiers_weapons_and_armor() -> void:
	var inv := Inventory.new()
	check_eq(inv.tool_tier("pickaxe"), 0, "no tool")
	inv.add("stone_pickaxe", 1)
	inv.add("iron_pickaxe", 1)
	check_eq(inv.tool_tier("pickaxe"), 3, "best pickaxe wins")
	var eq := Equipment.new()
	inv.add("copper_sword", 1)
	inv.add("iron_sword", 1)
	check(eq.equip(inv, "copper_sword"), "equip sword")
	check(eq.equip(inv, "iron_sword"), "swap sword")
	check_eq(inv.count("copper_sword"), 1, "old sword back in pack")
	check_eq(inv.count("iron_sword"), 0, "equipped sword left pack")
	check_eq(eq.stat("dmg"), ItemCatalog.damage_of("iron_sword"), "weapon damage")
	inv.add("iron_armor", 1)
	inv.add("iron_helm", 1)
	eq.equip(inv, "iron_armor")
	eq.equip(inv, "iron_helm")
	check_eq(eq.stat("armor"), ItemCatalog.armor_of("iron_armor") + ItemCatalog.armor_of("iron_helm"), "armor sums")
	check(not eq.equip(inv, "wood"), "wood is not gear")
	check(eq.unequip(inv, "head"), "unequip helm")
	check_eq(inv.count("iron_helm"), 1, "helm back in pack")
	check(eq.equip(inv, "iron_pickaxe"), "tool as weapon")
	check_eq(eq.tool_tier("pickaxe"), 3, "equipped tool tier")
	var copy := Equipment.new()
	copy.load_data(eq.to_data())
	check_eq(copy.get_item("body"), "iron_armor", "equipment round-trips")
	for id in ItemCatalog.ITEMS:
		var slot := ItemCatalog.slot_of(id)
		check(slot == "" or slot in Equipment.SLOTS, "valid slot for %s" % id)


func test_item_categories() -> void:
	for id in ItemCatalog.ITEMS:
		check(ItemCatalog.category_of(id) in ItemCatalog.CATEGORIES, "category for %s" % id)
	check_eq(ItemCatalog.category_of("iron_pickaxe"), "tool", "pickaxe")
	check_eq(ItemCatalog.category_of("iron_sword"), "weapon", "sword")
	check_eq(ItemCatalog.category_of("short_bow"), "weapon", "bow")
	check_eq(ItemCatalog.category_of("flint_arrow"), "ammo", "arrow")
	check_eq(ItemCatalog.category_of("iron_helm"), "armor", "helm")
	check_eq(ItemCatalog.category_of("wooden_shield"), "armor", "shield")
	check_eq(ItemCatalog.category_of("copper_ring"), "accessory", "ring")
	check_eq(ItemCatalog.category_of("healing_potion"), "medicine", "potion")
	check_eq(ItemCatalog.category_of("anvil"), "station", "anvil")
	check_eq(ItemCatalog.category_of("plank"), "material", "plank")
	check_eq(ItemCatalog.category_of("wood"), "resource", "wood")
	check_eq(ItemCatalog.category_of("raw_meat"), "food", "meat")


func test_recipe_books_grouped_by_category() -> void:
	for st in [""] + ItemCatalog.STATIONS.keys():
		var last := -1
		for i in ItemCatalog.recipes_at(st):
			var c := ItemCatalog.CATEGORIES.find(ItemCatalog.category_of(ItemCatalog.RECIPES[i].id))
			check(c >= last, "%s book ordered at %s" % [st, ItemCatalog.RECIPES[i].id])
			last = c


func test_inventory_sort_merges_and_orders() -> void:
	var inv := Inventory.new(6)
	inv.slots[0] = {"id": "wood", "count": 10}
	inv.slots[2] = {"id": "iron_sword", "count": 1}
	inv.slots[3] = {"id": "wood", "count": 5}
	inv.slots[5] = {"id": "stone_pickaxe", "count": 1}
	inv.sort()
	check_eq(inv.slots[0].id, "stone_pickaxe", "tools first")
	check_eq(inv.slots[1].id, "iron_sword", "weapons next")
	check_eq(inv.slots[2], {"id": "wood", "count": 15}, "wood merged")
	check(inv.slots[3].is_empty(), "empties at the end")


func test_inventory_manual_move_and_discard() -> void:
	var inv := Inventory.new(4)
	inv.slots[0] = {"id": "wood", "count": 5}
	inv.slots[2] = {"id": "stone", "count": 3}
	inv.move_slot(0, 2)
	check_eq(inv.slots[0], {"id": "stone", "count": 3}, "different items swap")
	check_eq(inv.slots[2], {"id": "wood", "count": 5}, "dragged stack lands on target")
	inv.move_slot(2, 3)
	check(inv.slots[2].is_empty() and inv.slots[3].id == "wood", "move into an empty slot")
	var cap := ItemCatalog.stack_size("wood")
	inv.slots[1] = {"id": "wood", "count": cap - 2}
	inv.move_slot(3, 1)
	check_eq(int(inv.slots[1].count), cap, "same items merge up to the stack size")
	check_eq(inv.slots[3], {"id": "wood", "count": 3}, "overflow stays behind")
	check_eq(inv.discard(0, 1), {"id": "stone", "count": 1}, "drop one")
	check_eq(int(inv.slots[0].count), 2, "rest kept")
	check_eq(inv.discard(0, 99), {"id": "stone", "count": 2}, "drop whole stack")
	check(inv.slots[0].is_empty(), "slot emptied")
	inv.slots[0] = {"id": "memory_shard", "count": 1}
	check(inv.discard(0, 1).is_empty(), "bound items cannot be dropped")
	check_eq(inv.count("memory_shard"), 1, "bound item kept")


func test_farming_stages() -> void:
	check_eq(Farming.stage(Farming.NOT_PLANTED, 1000.0), Farming.EMPTY, "empty")
	check_eq(Farming.stage(100.0, 200.0), Farming.GROWING, "growing")
	check_eq(Farming.stage(100.0, 100.0 + Farming.GROW_MINUTES), Farming.RIPE, "ripe")


func test_labyrinth_spawns_ores() -> void:
	var layout := LabyrinthGenerator.generate(5)
	var ores := 0
	for p in layout.props:
		if str(p.type).begins_with("ore_"):
			ores += 1
			check(ResourceCatalog.has(p.type), "%s is a known resource" % p.type)
	check(ores > 10, "labyrinth holds ore deposits")


func _recipe_index(id: String) -> int:
	return ItemCatalog.RECIPES.find_custom(func(r: Dictionary) -> bool: return r.id == id)


func test_recipes_unlock_from_discovered_ingredients() -> void:
	var inv := Inventory.new()
	var knife := _recipe_index("flint_knife")
	check(not ItemCatalog.recipe_known(knife, inv.known), "hidden before discovery")
	var seen := []
	inv.discovered.connect(func(id: String) -> void: seen.append(id))
	inv.add("stick", 1)
	check(not ItemCatalog.recipe_known(knife, inv.known), "a staple stick reveals nothing special")
	inv.add("flint", 1)
	check(ItemCatalog.recipe_known(knife, inv.known), "the special ingredient reveals it")
	inv.remove("flint", 1)
	check(ItemCatalog.recipe_known(knife, inv.known), "stays known after using the item up")
	inv.add("flint", 1)
	check_eq(seen, ["stick", "flint"], "discovered once")
	check(not ItemCatalog.recipes_revealed_by("stick", inv.known).has(knife), "already revealed recipe not counted again")


func test_staple_recipes_need_every_staple() -> void:
	var axe := _recipe_index("stone_axe")
	check(not ItemCatalog.recipe_known(axe, {"stick": true}), "stick alone is not enough")
	check(ItemCatalog.recipe_known(axe, {"stick": true, "stone": true}), "all staples known reveals it")
	check(ItemCatalog.recipes_revealed_by("stone", {"stick": true}).has(axe), "the last staple reveals it")
	check(ItemCatalog.recipe_known(_recipe_index("plank"), {"wood": true}), "planks from wood")


func test_blueprint_recipes_need_a_blueprint() -> void:
	var blade := _recipe_index("crystal_blade")
	var known := {"stick": true, "crystal": true, "iron_ingot": true}
	check(Blueprints.gates("crystal_blade"), "crystal blade is a maze blueprint")
	check(not ItemCatalog.recipe_known(blade, known), "ingredients alone do not reveal it")
	check(ItemCatalog.recipe_known(blade, known, {"crystal_blade": true}), "the blueprint does")


func test_blueprint_pools_are_valid() -> void:
	var ingredients := {}
	for r in ItemCatalog.RECIPES:
		for id in r["in"]:
			ingredients[id] = true
	for sector in Blueprints.POOLS:
		var pool: Array = Blueprints.POOLS[sector]
		check(pool.size() >= LabyrinthGenerator.CHEST_COUNT, "%s: one blueprint per chest" % sector)
		for id in pool:
			check(_recipe_index(id) >= 0, "%s has a recipe" % id)
			check(not ingredients.has(id), "%s is not an ingredient elsewhere (no dead ends)" % id)
			check_eq(Blueprints.sector_of(id), sector, "%s sector" % id)
		for entry in Blueprints.LOOT[sector]:
			check(ItemCatalog.ITEMS.has(entry[0]), "%s loot %s exists" % [sector, entry[0]])
	var first: String = Blueprints.pick("labyrinth", {}, 0)
	check(first in Blueprints.POOLS["labyrinth"], "pick from the pool")
	check(Blueprints.pick("labyrinth", {first: true}, 0) != first, "pick skips known blueprints")


func test_known_items_survive_save() -> void:
	var inv := Inventory.new()
	inv.add("stone", 2)
	inv.remove("stone", 2)
	var copy := Inventory.new()
	copy.load_known(inv.known_to_data())
	check(copy.knows("stone"), "known restored")
	var legacy := Inventory.new()
	legacy.load_data([{"id": "stone", "count": 1}])
	check(legacy.knows("stone"), "old saves: carried items count as discovered")


func test_moving_a_slot_between_inventories() -> void:
	var bag := Inventory.new(4)
	var chest := Inventory.new(2)
	bag.add("stone", 10)
	check_eq(bag.move_to(chest, 0, 1), 1, "right-click moves one")
	check_eq(bag.move_to(chest, 0, 9999), 9, "click moves the rest of the stack")
	check(bag.slots[0].is_empty() and chest.count("stone") == 10, "stack now in the chest")
	chest.add("wood", ItemCatalog.stack_size("wood"))
	bag.add("coal", 3)
	check_eq(bag.move_to(chest, 0, 3), 0, "full chest takes nothing")
	check_eq(bag.count("coal"), 3, "coal kept")

func test_tools_wear_out_and_keep_wear_when_moved() -> void:
	check_eq(ItemCatalog.durability_of("wood"), 0, "materials never wear")
	var dur := ItemCatalog.durability_of("stone_axe")
	check(dur > 0, "tools wear")
	var inv := Inventory.new(6)
	inv.add("stone_axe", 1)
	var i := inv.find_last("stone_axe")
	check(not inv.wear_slot(i, dur - 1), "one use left")
	inv.sort()
	i = inv.find_last("stone_axe")
	check_eq(int(inv.slots[i].wear), dur - 1, "sort keeps wear")
	var copy := Inventory.new(6)
	copy.load_data(JSON.parse_string(JSON.stringify(inv.to_data())))
	check_eq(int(copy.slots[copy.find_last("stone_axe")].wear), dur - 1, "save keeps wear")
	var eq := Equipment.new()
	check(eq.equip(inv, "stone_axe", i), "equipped")
	check_eq(eq.uses_left("weapon"), 1, "wear follows into the hand")
	var eq2 := Equipment.new()
	eq2.load_data(JSON.parse_string(JSON.stringify(eq.to_data())))
	check_eq(eq2.uses_left("weapon"), 1, "equipment save keeps wear")
	check(eq.unequip(inv, "weapon"), "unequipped")
	check_eq(int(inv.slots[inv.find_last("stone_axe")].wear), dur - 1, "wear follows back")
	check(eq.equip(inv, "stone_axe"), "equipped again")
	check_eq(eq.wear_out("weapon"), "stone_axe", "last use breaks it")
	check_eq(eq.get_item("weapon"), "", "broken tool is gone")
	inv.add("stone_axe", 1)
	check(inv.wear_slot(inv.find_last("stone_axe"), dur), "backpack tool breaks")
	check_eq(inv.count("stone_axe"), 0, "and leaves the backpack")
