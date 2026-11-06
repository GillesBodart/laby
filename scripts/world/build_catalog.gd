class_name BuildCatalog
extends RefCounted
## Placeable structures. The structure type id equals the item id that is
## consumed when placing it (and refunded when removed).

const TYPES := {
	"workbench": {"solid": true, "layer": "entity", "group": "workbench"},
	"chest": {"solid": true, "layer": "entity", "group": "chest"},
	"wooden_wall": {"solid": true, "layer": "entity", "group": ""},
	"wooden_floor": {"solid": false, "layer": "floor", "group": ""},
	"wooden_door": {"solid": true, "layer": "entity", "group": "", "door": true},
}


static func is_placeable(item_id: String) -> bool:
	return TYPES.has(item_id)


static func texture_path(type: String, open := false) -> String:
	if type == "wooden_door":
		return "res://assets/sprites/structures/wooden_door_%s.png" % ("open" if open else "closed")
	return "res://assets/sprites/structures/%s.png" % type
