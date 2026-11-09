class_name BuildCatalog
extends RefCounted
## Placeable structures. The structure type id equals the item id that is
## consumed when placing it (and refunded when removed).

const TYPES := {
	"workbench": {"solid": true, "layer": "entity", "group": "workbench"},
	"chest": {"solid": true, "layer": "entity", "group": "chest"},
	"furnace": {"solid": true, "layer": "entity", "group": "furnace"},
	"anvil": {"solid": true, "layer": "entity", "group": "anvil"},
	"cooking_pot": {"solid": true, "layer": "entity", "group": "cooking_pot"},
	"tanning_rack": {"solid": true, "layer": "entity", "group": "tanning_rack"},
	"stonecutter": {"solid": true, "layer": "entity", "group": "stonecutter"},
	"loom": {"solid": true, "layer": "entity", "group": "loom"},
	"alchemy_table": {"solid": true, "layer": "entity", "group": "alchemy_table"},
	"stone_wall": {"solid": true, "layer": "entity", "group": ""},
	"brick_wall": {"solid": true, "layer": "entity", "group": ""},
	"stone_floor": {"solid": false, "layer": "floor", "group": ""},
	"wooden_wall": {"solid": true, "layer": "entity", "group": ""},
	"wooden_floor": {"solid": false, "layer": "floor", "group": ""},
	"farm_plot": {"solid": false, "layer": "floor", "group": "farm_plot"},
	"wooden_door": {"solid": true, "layer": "entity", "group": "", "door": true},
	"well": {"solid": true, "layer": "entity", "group": "well"},
	"standing_torch": {"solid": true, "layer": "entity", "group": "standing_torch", "light": 1.2},
	"waystone": {"solid": true, "layer": "entity", "group": "waystone"},
	"skill_altar": {"solid": true, "layer": "entity", "group": "skill_altar"},
}


static func is_placeable(item_id: String) -> bool:
	return TYPES.has(item_id)


static func texture_path(type: String, open := false, stage := 0) -> String:
	if type == "farm_plot":
		return "res://assets/sprites/structures/farm_plot_%d.png" % stage
	if type == "wooden_door":
		return "res://assets/sprites/structures/wooden_door_%s.png" % ("open" if open else "closed")
	return "res://assets/sprites/structures/%s.png" % type
