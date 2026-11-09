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
	"bed": {"solid": true, "layer": "entity", "group": "bed"},
}


## Toughness against raiders (0 = floors, never targeted). onus is the
## builder's struct_hp skill bonus in percent.
static func max_hp(type: String, bonus := 0.0) -> int:
	if not TYPES.has(type) or TYPES[type].layer == "floor":
		return 0
	var base := 50
	if type in ["stone_wall", "brick_wall"]:
		base = 160
	elif type in ["wooden_wall", "wooden_door"]:
		base = 80
	return int(base * (1.0 + bonus / 100.0))


## Item spent to mend a damaged structure: its recipe's main ingredient.
static func repair_item(type: String) -> String:
	for r in ItemCatalog.RECIPES:
		if r.id == type:
			var best := ""
			for id in r.in:
				if best == "" or int(r.in[id]) > int(r.in[best]):
					best = id
			return best
	return type


static func is_placeable(item_id: String) -> bool:
	return TYPES.has(item_id)


static func texture_path(type: String, open := false, stage := 0) -> String:
	if type == "farm_plot":
		return "res://assets/sprites/structures/farm_plot_%d.png" % stage
	if type == "wooden_door":
		return "res://assets/sprites/structures/wooden_door_%s.png" % ("open" if open else "closed")
	return "res://assets/sprites/structures/%s.png" % type
