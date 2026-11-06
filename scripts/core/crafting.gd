class_name Crafting
extends RefCounted
## Recipe rules: availability and execution against an Inventory.


static func can_craft(inv: Inventory, recipe: Dictionary, stations: Array = []) -> bool:
	var station: String = recipe.station
	if station != "" and not stations.has(station):
		return false
	return inv.has_all(recipe["in"])


## Crafts one batch. Returns false (inventory untouched) if impossible or full.
static func craft(inv: Inventory, recipe: Dictionary, stations: Array = []) -> bool:
	if not can_craft(inv, recipe, stations):
		return false
	var backup := inv.to_data()
	for id in recipe["in"]:
		inv.remove(id, recipe["in"][id])
	if inv.add(recipe.id, recipe.out) > 0:
		inv.load_data(backup)
		return false
	return true
