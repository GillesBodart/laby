class_name Equipment
extends RefCounted
## Worn gear per player (pure data). Equipping moves an item out of the
## backpack into its slot; the previous item in that slot goes back.

signal changed

const SLOTS := ["weapon", "offhand", "head", "body", "feet", "ring", "amulet"]
const SLOT_NAMES := {
	"weapon": "Weapon", "offhand": "Offhand", "head": "Head", "body": "Body",
	"feet": "Feet", "ring": "Ring", "amulet": "Amulet",
}

## slot -> item id.
var items := {}


func get_item(slot: String) -> String:
	return items.get(slot, "")


## Sum of an item stat ("dmg", "armor", "hp") over everything worn.
func stat(name: String) -> int:
	var total := 0
	for id in items.values():
		total += int(ItemCatalog.ITEMS[id].get(name, 0))
	return total


## Tier of the equipped weapon if it is a tool of that kind (0 otherwise).
func tool_tier(kind: String) -> int:
	var id := get_item("weapon")
	return ItemCatalog.tier_of(id) if id != "" and ItemCatalog.tool_of(id) == kind else 0


func equip(inv: Inventory, id: String) -> bool:
	var slot := ItemCatalog.slot_of(id)
	if slot == "" or not inv.remove(id, 1):
		return false
	var old := get_item(slot)
	if old != "" and inv.add(old, 1) > 0:
		inv.add(id, 1)
		return false
	items[slot] = id
	changed.emit()
	return true


func unequip(inv: Inventory, slot: String) -> bool:
	var id := get_item(slot)
	if id == "" or inv.add(id, 1) > 0:
		return false
	items.erase(slot)
	changed.emit()
	return true


func to_data() -> Dictionary:
	return items.duplicate()


func load_data(data: Dictionary) -> void:
	items = {}
	for slot in data:
		var id := String(data[slot])
		if slot in SLOTS and ItemCatalog.slot_of(id) == slot:
			items[slot] = id
	changed.emit()
