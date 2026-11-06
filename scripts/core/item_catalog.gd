class_name ItemCatalog
extends RefCounted
## Single table of items and crafting recipes (data only, no nodes).

const ITEMS := {
	"wood": {"name": "Wood", "stack": 20, "color": Color8(140, 100, 64)},
	"stone": {"name": "Stone", "stack": 20, "color": Color8(150, 154, 148)},
	"plank": {"name": "Plank", "stack": 20, "color": Color8(190, 146, 92)},
	"stick": {"name": "Stick", "stack": 20, "color": Color8(120, 84, 52)},
	"torch": {"name": "Torch", "stack": 10, "color": Color8(245, 154, 58)},
	"stone_axe": {"name": "Stone Axe", "stack": 1, "color": Color8(170, 172, 164), "tool": "axe"},
	"stone_pickaxe": {"name": "Stone Pickaxe", "stack": 1, "color": Color8(140, 146, 152), "tool": "pickaxe"},
	"wooden_wall": {"name": "Wooden Wall", "stack": 20, "color": Color8(150, 106, 64)},
	"wooden_floor": {"name": "Wooden Floor", "stack": 40, "color": Color8(190, 146, 92)},
	"workbench": {"name": "Workbench", "stack": 5, "color": Color8(166, 120, 72)},
	"chest": {"name": "Chest", "stack": 5, "color": Color8(150, 104, 60)},
	"wooden_door": {"name": "Wooden Door", "stack": 10, "color": Color8(130, 92, 58)},
	"berry": {"name": "Berries", "stack": 20, "color": Color8(200, 52, 84), "food": 14.0},
}

## station: "" = craftable anywhere, otherwise a node group that must be near.
const RECIPES := [
	{"id": "plank", "out": 2, "in": {"wood": 1}, "station": ""},
	{"id": "stick", "out": 3, "in": {"wood": 1}, "station": ""},
	{"id": "torch", "out": 1, "in": {"stick": 2, "wood": 1}, "station": "campfire"},
	{"id": "stone_axe", "out": 1, "in": {"stick": 2, "stone": 3}, "station": ""},
	{"id": "stone_pickaxe", "out": 1, "in": {"stick": 2, "stone": 3}, "station": ""},
	{"id": "wooden_wall", "out": 2, "in": {"plank": 3, "stick": 1}, "station": "workbench"},
	{"id": "wooden_floor", "out": 4, "in": {"plank": 2}, "station": "workbench"},
	{"id": "workbench", "out": 1, "in": {"plank": 8, "stone": 4}, "station": "campfire"},
	{"id": "chest", "out": 1, "in": {"plank": 6, "stick": 2}, "station": "workbench"},
	{"id": "wooden_door", "out": 1, "in": {"plank": 4, "stick": 2}, "station": "workbench"},
]


const DESC := {
	"wood": "Rough logs from the Clearing's trees.",
	"stone": "Grey stone. Good for tools and benches.",
	"plank": "Cut planks. Used for all building.",
	"stick": "Sturdy sticks for handles.",
	"torch": "Lights the way in the dark.",
	"stone_axe": "Chops trees faster.",
	"stone_pickaxe": "Mines rocks faster.",
	"wooden_wall": "Place with B. Blocks the way.",
	"wooden_floor": "Place with B. Walkable.",
	"workbench": "Place with B. Unlocks crafting.",
	"chest": "Place with B. Opens the Stash (G).",
	"wooden_door": "Place with B. F opens/closes.",
	"berry": "Sweet wild berries. R eats them (+14 food).",
}


static func description(id: String) -> String:
	return DESC.get(id, "")


static func item_name(id: String) -> String:
	return ITEMS[id].name


static func stack_size(id: String) -> int:
	return ITEMS[id].stack


static func tool_of(id: String) -> String:
	return ITEMS[id].get("tool", "")


## Hunger restored when eaten (0 = not food).
static func food_of(id: String) -> float:
	return ITEMS[id].get("food", 0.0)
