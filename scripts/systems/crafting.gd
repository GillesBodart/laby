class_name Crafting
extends RefCounted
## Recipe rules: availability and execution against an Inventory.
## An optional `store` (the Stash, when a chest shares the player's room) also
## supplies ingredients: the backpack is used first, then the store.


## How many `id` are available to craft with.
static func available(inv: Inventory, id: String, store: Inventory = null) -> int:
	return inv.count(id) + (store.count(id) if store != null else 0)


static func can_craft(inv: Inventory, recipe: Dictionary, stations: Array = [], store: Inventory = null) -> bool:
	var station: String = recipe.station
	if station != "" and not stations.has(station):
		return false
	for id in recipe["in"]:
		if available(inv, id, store) < recipe["in"][id]:
			return false
	return true


## Crafts one batch into `inv`. Returns false (both inventories untouched) if
## impossible or the backpack is full.
static func craft(inv: Inventory, recipe: Dictionary, stations: Array = [], store: Inventory = null) -> bool:
	if not can_craft(inv, recipe, stations, store):
		return false
	var backup := inv.to_data()
	var store_backup := store.to_data() if store != null else []
	for id in recipe["in"]:
		var need: int = recipe["in"][id]
		var own := mini(inv.count(id), need)
		inv.remove(id, own)
		if need > own:
			store.remove(id, need - own)
	if inv.add(recipe.id, recipe.out) > 0:
		inv.load_data(backup)
		if store != null:
			store.load_data(store_backup)
		return false
	return true
