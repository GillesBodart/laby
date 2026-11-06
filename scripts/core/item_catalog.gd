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
	"stone_hammer": {"name": "Stone Hammer", "stack": 1, "color": Color8(128, 132, 128)},
	"wooden_club": {"name": "Wooden Club", "stack": 1, "color": Color8(107, 74, 47)},
	"workbench": {"name": "Workbench", "stack": 5, "color": Color8(166, 120, 72)},
	"chest": {"name": "Chest", "stack": 5, "color": Color8(150, 104, 60)},
	"wooden_door": {"name": "Wooden Door", "stack": 10, "color": Color8(130, 92, 58)},
}

## station: "" = craftable anywhere, otherwise a node group that must be near.
const RECIPES := [
	{"id": "plank", "out": 2, "in": {"wood": 1}, "station": ""},
	{"id": "stick", "out": 3, "in": {"wood": 1}, "station": ""},
	{"id": "torch", "out": 1, "in": {"stick": 2, "wood": 1}, "station": "campfire"},
	{"id": "stone_axe", "out": 1, "in": {"stick": 2, "stone": 3}, "station": ""},
	{"id": "stone_pickaxe", "out": 1, "in": {"stick": 2, "stone": 3}, "station": ""},
	{"id": "stone_hammer", "out": 1, "in": {"stick": 2, "stone": 2}, "station": ""},
	{"id": "wooden_club", "out": 1, "in": {"plank": 3}, "station": ""},
	{"id": "workbench", "out": 1, "in": {"plank": 8, "stone": 4}, "station": "campfire"},
	{"id": "chest", "out": 1, "in": {"plank": 6, "stick": 2}, "station": "workbench"},
	{"id": "wooden_door", "out": 1, "in": {"plank": 4, "stick": 2}, "station": "workbench"},
]


static func item_name(id: String) -> String:
	return ITEMS[id].name


static func stack_size(id: String) -> int:
	return ITEMS[id].stack


static func tool_of(id: String) -> String:
	return ITEMS[id].get("tool", "")
