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
## slot -> uses spent by the worn tool or weapon (see ItemCatalog.durability_of).
var wear := {}


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


## Puts on the item from backpack slot `index` (default: the last copy of `id`);
## the item worn before goes back with its wear.
func equip(inv: Inventory, id: String, index := -1) -> bool:
	var slot := ItemCatalog.slot_of(id)
	if index < 0 or index >= inv.slots.size() or inv.slots[index].is_empty() or inv.slots[index].id != id:
		index = inv.find_last(id)
	if slot == "" or index < 0:
		return false
	var used := int(inv.slots[index].get("wear", 0))
	inv.take(index, 1)
	var old := get_item(slot)
	if old != "" and inv.add_worn(old, int(wear.get(slot, 0))) > 0:
		inv.add_worn(id, used)
		return false
	items[slot] = id
	wear[slot] = used
	changed.emit()
	return true


func unequip(inv: Inventory, slot: String) -> bool:
	var id := get_item(slot)
	if id == "" or inv.add_worn(id, int(wear.get(slot, 0))) > 0:
		return false
	items.erase(slot)
	wear.erase(slot)
	changed.emit()
	return true


## Uses left of the worn item (0 when it never wears out or nothing is worn).
func uses_left(slot: String) -> int:
	var dur := ItemCatalog.durability_of(get_item(slot))
	return maxi(dur - int(wear.get(slot, 0)), 0) if dur > 0 else 0


## Spends `uses` of the worn item's durability; returns its id when it broke
## (it is then gone), else "".
func wear_out(slot: String, uses := 1) -> String:
	var id := get_item(slot)
	var dur := ItemCatalog.durability_of(id)
	if dur <= 0:
		return ""
	wear[slot] = int(wear.get(slot, 0)) + uses
	if int(wear[slot]) < dur:
		return ""
	items.erase(slot)
	wear.erase(slot)
	changed.emit()
	return id


## slot -> id, plus "wear" (slot -> uses spent) when something is worn down.
func to_data() -> Dictionary:
	var out := items.duplicate()
	var used := {}
	for slot in wear:
		if int(wear[slot]) > 0:
			used[slot] = int(wear[slot])
	if not used.is_empty():
		out["wear"] = used
	return out


func load_data(data: Dictionary) -> void:
	items = {}
	wear = {}
	for slot in data:
		if not slot in SLOTS:
			continue
		var id := String(data[slot])
		if ItemCatalog.slot_of(id) == slot:
			items[slot] = id
	var used: Dictionary = data.get("wear", {})
	for slot in used:
		if items.has(slot):
			wear[slot] = int(used[slot])
	changed.emit()
