class_name ItemCatalog
extends RefCounted
## Single table of items and crafting recipes (data only, no nodes).
##
## Item fields: name, stack, color (fallback icon), desc, and optionally
##   tool   - "axe" | "pickaxe" (gathering kind), with tier 1 stone .. 3 iron
##   dmg    - bonus attack damage while carried
##   armor  - damage absorbed per hit while carried
##   food   - hunger restored when eaten

const ITEMS := {
	# --- raw resources
	"wood": {"name": "Wood", "stack": 40, "color": Color8(140, 100, 64), "desc": "Rough logs from the Clearing's trees."},
	"stone": {"name": "Stone", "stack": 40, "color": Color8(150, 154, 148), "desc": "Grey stone. Good for tools and walls."},
	"fiber": {"name": "Fiber", "stack": 40, "color": Color8(150, 176, 84), "desc": "Tough plant fibers from tall grass."},
	"clay": {"name": "Clay", "stack": 40, "color": Color8(176, 112, 80), "desc": "Wet red clay. Fire it into bricks."},
	"coal": {"name": "Coal", "stack": 40, "color": Color8(40, 40, 46), "desc": "Black fuel for the furnace."},
	"copper_ore": {"name": "Copper Ore", "stack": 40, "color": Color8(196, 120, 72), "desc": "Green-streaked ore. Smelt it."},
	"iron_ore": {"name": "Iron Ore", "stack": 40, "color": Color8(168, 140, 130), "desc": "Heavy ore. Needs a copper pickaxe."},
	"crystal": {"name": "Crystal", "stack": 20, "color": Color8(120, 220, 240), "desc": "A humming crystal from deep in the maze."},
	"hide": {"name": "Hide", "stack": 40, "color": Color8(150, 104, 70), "desc": "Tough skin of maze creatures."},
	"bone": {"name": "Bone", "stack": 40, "color": Color8(232, 224, 200), "desc": "Pale bones from stalkers."},
	"berry": {"name": "Berries", "stack": 40, "color": Color8(200, 52, 84), "food": 14.0, "desc": "Sweet wild berries. R eats them (+14 food)."},
	# --- materials
	"plank": {"name": "Plank", "stack": 40, "color": Color8(190, 146, 92), "desc": "Cut planks. Used for all building."},
	"stick": {"name": "Stick", "stack": 40, "color": Color8(120, 84, 52), "desc": "Sturdy sticks for handles."},
	"rope": {"name": "Rope", "stack": 40, "color": Color8(196, 170, 108), "desc": "Twisted fiber cord."},
	"brick": {"name": "Brick", "stack": 40, "color": Color8(184, 82, 60), "desc": "Fired clay brick. Cook at a furnace."},
	"copper_ingot": {"name": "Copper Ingot", "stack": 40, "color": Color8(214, 132, 80), "desc": "Smelted copper."},
	"iron_ingot": {"name": "Iron Ingot", "stack": 40, "color": Color8(190, 194, 202), "desc": "Smelted iron."},
	"leather": {"name": "Leather", "stack": 40, "color": Color8(132, 84, 52), "desc": "Cured hide for armor."},
	"torch": {"name": "Torch", "stack": 20, "color": Color8(245, 154, 58), "desc": "Lights the way in the dark."},
	# --- tools and weapons (tier decides which ores can be mined)
	"stone_axe": {"name": "Stone Axe", "stack": 1, "color": Color8(170, 172, 164), "tool": "axe", "tier": 1, "dmg": 6, "desc": "Chops trees faster. +6 damage."},
	"stone_pickaxe": {"name": "Stone Pickaxe", "stack": 1, "color": Color8(140, 146, 152), "tool": "pickaxe", "tier": 1, "dmg": 4, "desc": "Mines rocks, coal and copper. +4 damage."},
	"stone_sword": {"name": "Stone Sword", "stack": 1, "color": Color8(160, 166, 160), "dmg": 8, "desc": "A crude blade. +8 damage."},
	"bone_sword": {"name": "Bone Sword", "stack": 1, "color": Color8(232, 224, 200), "dmg": 7, "desc": "Light and sharp. +7 damage."},
	"copper_axe": {"name": "Copper Axe", "stack": 1, "color": Color8(214, 132, 80), "tool": "axe", "tier": 2, "dmg": 8, "desc": "Chops quickly. +8 damage."},
	"copper_pickaxe": {"name": "Copper Pickaxe", "stack": 1, "color": Color8(214, 132, 80), "tool": "pickaxe", "tier": 2, "dmg": 6, "desc": "Mines iron ore. +6 damage."},
	"copper_sword": {"name": "Copper Sword", "stack": 1, "color": Color8(214, 132, 80), "dmg": 11, "desc": "+11 damage."},
	"iron_axe": {"name": "Iron Axe", "stack": 1, "color": Color8(190, 194, 202), "tool": "axe", "tier": 3, "dmg": 11, "desc": "Fells trees in a blink. +11 damage."},
	"iron_pickaxe": {"name": "Iron Pickaxe", "stack": 1, "color": Color8(190, 194, 202), "tool": "pickaxe", "tier": 3, "dmg": 9, "desc": "Mines crystals. +9 damage."},
	"iron_sword": {"name": "Iron Sword", "stack": 1, "color": Color8(190, 194, 202), "dmg": 15, "desc": "+15 damage."},
	"crystal_blade": {"name": "Crystal Blade", "stack": 1, "color": Color8(120, 220, 240), "dmg": 22, "desc": "Hums with power. +22 damage."},
	# --- armor (the best piece in the backpack is worn)
	"leather_armor": {"name": "Leather Armor", "stack": 1, "color": Color8(132, 84, 52), "armor": 2, "desc": "Absorbs 2 damage per hit."},
	"copper_armor": {"name": "Copper Armor", "stack": 1, "color": Color8(214, 132, 80), "armor": 4, "desc": "Absorbs 4 damage per hit."},
	"iron_armor": {"name": "Iron Armor", "stack": 1, "color": Color8(190, 194, 202), "armor": 7, "desc": "Absorbs 7 damage per hit."},
	# --- food
	"berry_jam": {"name": "Berry Jam", "stack": 20, "color": Color8(150, 30, 70), "food": 45.0, "desc": "Thick and sweet. R eats it (+45 food)."},
	# --- buildings
	"workbench": {"name": "Workbench", "stack": 5, "color": Color8(166, 120, 72), "desc": "Place with B. Unlocks crafting."},
	"furnace": {"name": "Furnace", "stack": 5, "color": Color8(120, 120, 124), "desc": "Place with B. Smelts ore, fires bricks."},
	"chest": {"name": "Chest", "stack": 5, "color": Color8(150, 104, 60), "desc": "Place with B. Opens the Stash (G)."},
	"wooden_wall": {"name": "Wooden Wall", "stack": 40, "color": Color8(150, 106, 64), "desc": "Place with B. Blocks the way."},
	"wooden_floor": {"name": "Wooden Floor", "stack": 40, "color": Color8(190, 146, 92), "desc": "Place with B. Walkable."},
	"wooden_door": {"name": "Wooden Door", "stack": 10, "color": Color8(130, 92, 58), "desc": "Place with B. F opens/closes."},
	"stone_wall": {"name": "Stone Wall", "stack": 40, "color": Color8(130, 138, 132), "desc": "Place with B. Sturdy defense."},
	"stone_floor": {"name": "Stone Floor", "stack": 40, "color": Color8(150, 154, 148), "desc": "Place with B. Walkable."},
	"brick_wall": {"name": "Brick Wall", "stack": 40, "color": Color8(184, 82, 60), "desc": "Place with B. Warm red masonry."},
	"farm_plot": {"name": "Farm Plot", "stack": 10, "color": Color8(110, 78, 50), "desc": "Place with B. E plants a berry; ripe in 4 min."},
}

## station: "" = craftable anywhere, otherwise a node group that must be near.
const RECIPES := [
	{"id": "plank", "out": 2, "in": {"wood": 1}, "station": ""},
	{"id": "stick", "out": 3, "in": {"wood": 1}, "station": ""},
	{"id": "rope", "out": 1, "in": {"fiber": 3}, "station": ""},
	{"id": "torch", "out": 2, "in": {"stick": 1, "fiber": 2}, "station": ""},
	{"id": "stone_axe", "out": 1, "in": {"stick": 2, "stone": 3}, "station": ""},
	{"id": "stone_pickaxe", "out": 1, "in": {"stick": 2, "stone": 3}, "station": ""},
	{"id": "stone_sword", "out": 1, "in": {"stick": 1, "stone": 2}, "station": ""},
	{"id": "bone_sword", "out": 1, "in": {"bone": 3, "rope": 1}, "station": ""},
	{"id": "farm_plot", "out": 1, "in": {"plank": 2, "stick": 1}, "station": ""},
	{"id": "workbench", "out": 1, "in": {"plank": 8, "stone": 4}, "station": "campfire"},
	{"id": "berry_jam", "out": 1, "in": {"berry": 4}, "station": "campfire"},
	{"id": "furnace", "out": 1, "in": {"stone": 10, "clay": 4}, "station": "workbench"},
	{"id": "chest", "out": 1, "in": {"plank": 6, "stick": 2}, "station": "workbench"},
	{"id": "wooden_wall", "out": 2, "in": {"plank": 3, "stick": 1}, "station": "workbench"},
	{"id": "wooden_floor", "out": 4, "in": {"plank": 2}, "station": "workbench"},
	{"id": "wooden_door", "out": 1, "in": {"plank": 4, "stick": 2}, "station": "workbench"},
	{"id": "stone_wall", "out": 2, "in": {"stone": 4}, "station": "workbench"},
	{"id": "stone_floor", "out": 4, "in": {"stone": 2}, "station": "workbench"},
	{"id": "brick", "out": 2, "in": {"clay": 2, "coal": 1}, "station": "furnace"},
	{"id": "brick_wall", "out": 2, "in": {"brick": 4}, "station": "workbench"},
	{"id": "copper_ingot", "out": 2, "in": {"copper_ore": 2, "coal": 1}, "station": "furnace"},
	{"id": "iron_ingot", "out": 1, "in": {"iron_ore": 2, "coal": 1}, "station": "furnace"},
	{"id": "leather", "out": 1, "in": {"hide": 2}, "station": "workbench"},
	{"id": "copper_axe", "out": 1, "in": {"stick": 2, "copper_ingot": 3}, "station": "workbench"},
	{"id": "copper_pickaxe", "out": 1, "in": {"stick": 2, "copper_ingot": 3}, "station": "workbench"},
	{"id": "copper_sword", "out": 1, "in": {"stick": 1, "copper_ingot": 2}, "station": "workbench"},
	{"id": "iron_axe", "out": 1, "in": {"stick": 2, "iron_ingot": 3}, "station": "workbench"},
	{"id": "iron_pickaxe", "out": 1, "in": {"stick": 2, "iron_ingot": 3}, "station": "workbench"},
	{"id": "iron_sword", "out": 1, "in": {"stick": 1, "iron_ingot": 2}, "station": "workbench"},
	{"id": "crystal_blade", "out": 1, "in": {"stick": 1, "crystal": 3, "iron_ingot": 2}, "station": "workbench"},
	{"id": "leather_armor", "out": 1, "in": {"leather": 5, "rope": 2}, "station": "workbench"},
	{"id": "copper_armor", "out": 1, "in": {"copper_ingot": 8, "leather": 2}, "station": "workbench"},
	{"id": "iron_armor", "out": 1, "in": {"iron_ingot": 8, "leather": 3}, "station": "workbench"},
]


static func description(id: String) -> String:
	return ITEMS[id].get("desc", "")


static func item_name(id: String) -> String:
	return ITEMS[id].name


static func stack_size(id: String) -> int:
	return ITEMS[id].stack


static func tool_of(id: String) -> String:
	return ITEMS[id].get("tool", "")


static func tier_of(id: String) -> int:
	return ITEMS[id].get("tier", 0)


static func damage_of(id: String) -> int:
	return ITEMS[id].get("dmg", 0)


static func armor_of(id: String) -> int:
	return ITEMS[id].get("armor", 0)


## Hunger restored when eaten (0 = not food).
static func food_of(id: String) -> float:
	return ITEMS[id].get("food", 0.0)
