extends TestCase


func _recipe(id: String) -> Dictionary:
	for r in ItemCatalog.RECIPES:
		if r.id == id:
			return r
	return {}


func test_inventory_stacks_and_overflow() -> void:
	var inv := Inventory.new(2)
	check_eq(inv.add("wood", 25), 0, "fits in two stacks")
	check_eq(inv.count("wood"), 25, "count")
	check_eq(inv.add("wood", 20), 5, "overflow returned")
	check(inv.remove("wood", 30), "remove")
	check_eq(inv.count("wood"), 10, "remaining")
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


func test_recipes_reference_known_items() -> void:
	for r in ItemCatalog.RECIPES:
		check(ItemCatalog.ITEMS.has(r.id), "output %s" % r.id)
		for k in r["in"]:
			check(ItemCatalog.ITEMS.has(k), "ingredient %s" % k)
