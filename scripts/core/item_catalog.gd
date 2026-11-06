class_name ItemCatalog
extends RefCounted
## Single table of items and crafting recipes (data only, no nodes).
##
## Item fields: name, stack, color (fallback icon), desc, and optionally
##   tool   - "axe" | "pickaxe" (gathering kind), with tier 1 stone .. 3 iron
##   slot   - equipment slot (see Equipment.SLOTS); weapons and tools default to "weapon"
##   dmg    - bonus attack damage while equipped
##   armor  - damage absorbed per hit while equipped
##   hp     - bonus max health while equipped
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
	"leather_armor": {"name": "Leather Armor", "stack": 1, "color": Color8(132, 84, 52), "slot": "body", "armor": 2, "desc": "Body armor. Absorbs 2 damage per hit."},
	"copper_armor": {"name": "Copper Armor", "stack": 1, "color": Color8(214, 132, 80), "slot": "body", "armor": 4, "desc": "Body armor. Absorbs 4 damage per hit."},
	"iron_armor": {"name": "Iron Armor", "stack": 1, "color": Color8(190, 194, 202), "slot": "body", "armor": 7, "desc": "Body armor. Absorbs 7 damage per hit."},
	"leather_cap": {"name": "Leather Cap", "stack": 1, "color": Color8(132, 84, 52), "slot": "head", "armor": 1, "desc": "Head. Absorbs 1 damage."},
	"copper_helm": {"name": "Copper Helm", "stack": 1, "color": Color8(214, 132, 80), "slot": "head", "armor": 2, "desc": "Head. Absorbs 2 damage."},
	"iron_helm": {"name": "Iron Helm", "stack": 1, "color": Color8(190, 194, 202), "slot": "head", "armor": 3, "desc": "Head. Absorbs 3 damage."},
	"leather_boots": {"name": "Leather Boots", "stack": 1, "color": Color8(132, 84, 52), "slot": "feet", "armor": 1, "desc": "Feet. Absorbs 1 damage."},
	"copper_boots": {"name": "Copper Boots", "stack": 1, "color": Color8(214, 132, 80), "slot": "feet", "armor": 1, "hp": 10, "desc": "Feet. Absorbs 1 damage, +10 max health."},
	"iron_boots": {"name": "Iron Boots", "stack": 1, "color": Color8(190, 194, 202), "slot": "feet", "armor": 2, "hp": 10, "desc": "Feet. Absorbs 2 damage, +10 max health."},
	"copper_ring": {"name": "Copper Ring", "stack": 1, "color": Color8(214, 132, 80), "slot": "ring", "dmg": 2, "desc": "Ring. +2 damage."},
	"crystal_ring": {"name": "Crystal Ring", "stack": 1, "color": Color8(120, 220, 240), "slot": "ring", "dmg": 5, "desc": "Ring. +5 damage."},
	"bone_charm": {"name": "Bone Charm", "stack": 1, "color": Color8(232, 224, 200), "slot": "amulet", "hp": 20, "desc": "Amulet. +20 max health."},
	"crystal_amulet": {"name": "Crystal Amulet", "stack": 1, "color": Color8(120, 220, 240), "slot": "amulet", "hp": 40, "armor": 1, "desc": "Amulet. +40 max health, absorbs 1."},
	# --- food
	"mushroom": {"name": "Mushroom", "stack": 40, "color": Color8(172, 88, 52), "food": 5.0, "desc": "Earthy cap from the forest floor. Better cooked (+5 food)."},
	"raw_meat": {"name": "Raw Meat", "stack": 40, "color": Color8(200, 70, 72), "food": 6.0, "desc": "From maze creatures. Cook it! (+6 food)"},
	"cooked_meat": {"name": "Cooked Meat", "stack": 20, "color": Color8(160, 94, 50), "food": 35.0, "desc": "Roasted over the fire (+35 food)."},
	"roasted_mushroom": {"name": "Mushroom Skewer", "stack": 20, "color": Color8(124, 58, 38), "food": 18.0, "desc": "Smoky and filling (+18 food)."},
	"berry_jam": {"name": "Berry Jam", "stack": 20, "color": Color8(150, 30, 70), "food": 45.0, "desc": "Thick and sweet (+45 food)."},
	"mushroom_soup": {"name": "Mushroom Soup", "stack": 10, "color": Color8(226, 196, 150), "food": 50.0, "desc": "Warm and creamy (+50 food)."},
	"forest_salad": {"name": "Forest Salad", "stack": 10, "color": Color8(100, 162, 68), "food": 40.0, "desc": "Leaves, berries and caps (+40 food)."},
	"meat_stew": {"name": "Meat Stew", "stack": 10, "color": Color8(170, 100, 56), "food": 85.0, "desc": "A survivor's feast (+85 food)."},
	# --- buildings
	"workbench": {"name": "Workbench", "stack": 5, "color": Color8(166, 120, 72), "desc": "Place with B, E to use. Woodwork and new stations."},
	"furnace": {"name": "Furnace", "stack": 5, "color": Color8(120, 120, 124), "desc": "Place with B, E to use. Smelts ore, fires clay."},
	"anvil": {"name": "Anvil", "stack": 5, "color": Color8(96, 100, 108), "desc": "Place with B, E to use. Forges metal tools, weapons, armor, jewels."},
	"cooking_pot": {"name": "Cooking Pot", "stack": 5, "color": Color8(66, 70, 80), "desc": "Place with B, E to use. Soups, stews and meals."},
	"tanning_rack": {"name": "Tanning Rack", "stack": 5, "color": Color8(168, 118, 78), "desc": "Place with B, E to use. Leather and leather gear."},
	"stonecutter": {"name": "Stonecutter", "stack": 5, "color": Color8(128, 132, 130), "desc": "Place with B, E to use. Stone and brick blocks."},
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
	# --- by hand (I)
	{"id": "plank", "out": 2, "in": {"wood": 1}, "station": ""},
	{"id": "stick", "out": 3, "in": {"wood": 1}, "station": ""},
	{"id": "rope", "out": 1, "in": {"fiber": 3}, "station": ""},
	{"id": "torch", "out": 2, "in": {"stick": 1, "fiber": 2}, "station": ""},
	{"id": "stone_axe", "out": 1, "in": {"stick": 2, "stone": 3}, "station": ""},
	{"id": "stone_pickaxe", "out": 1, "in": {"stick": 2, "stone": 3}, "station": ""},
	{"id": "stone_sword", "out": 1, "in": {"stick": 1, "stone": 2}, "station": ""},
	{"id": "bone_sword", "out": 1, "in": {"bone": 3, "rope": 1}, "station": ""},
	{"id": "bone_charm", "out": 1, "in": {"bone": 3, "rope": 1}, "station": ""},
	{"id": "farm_plot", "out": 1, "in": {"plank": 2, "stick": 1}, "station": ""},
	{"id": "forest_salad", "out": 1, "in": {"fiber": 2, "berry": 3, "mushroom": 1}, "station": ""},
	# --- campfire
	{"id": "workbench", "out": 1, "in": {"plank": 8, "stone": 4}, "station": "campfire"},
	{"id": "cooked_meat", "out": 1, "in": {"raw_meat": 1}, "station": "campfire"},
	{"id": "roasted_mushroom", "out": 1, "in": {"mushroom": 2, "stick": 1}, "station": "campfire"},
	# --- workbench: woodwork and new stations
	{"id": "chest", "out": 1, "in": {"plank": 6, "stick": 2}, "station": "workbench"},
	{"id": "wooden_wall", "out": 2, "in": {"plank": 3, "stick": 1}, "station": "workbench"},
	{"id": "wooden_floor", "out": 4, "in": {"plank": 2}, "station": "workbench"},
	{"id": "wooden_door", "out": 1, "in": {"plank": 4, "stick": 2}, "station": "workbench"},
	{"id": "furnace", "out": 1, "in": {"stone": 10, "clay": 4}, "station": "workbench"},
	{"id": "tanning_rack", "out": 1, "in": {"stick": 6, "rope": 3}, "station": "workbench"},
	{"id": "stonecutter", "out": 1, "in": {"stone": 8, "plank": 4}, "station": "workbench"},
	{"id": "anvil", "out": 1, "in": {"copper_ingot": 6, "wood": 2}, "station": "workbench"},
	# --- furnace: smelting and firing
	{"id": "copper_ingot", "out": 2, "in": {"copper_ore": 2, "coal": 1}, "station": "furnace"},
	{"id": "iron_ingot", "out": 1, "in": {"iron_ore": 2, "coal": 1}, "station": "furnace"},
	{"id": "brick", "out": 2, "in": {"clay": 2, "coal": 1}, "station": "furnace"},
	{"id": "cooking_pot", "out": 1, "in": {"clay": 6, "rope": 1}, "station": "furnace"},
	# --- stonecutter: masonry
	{"id": "stone_wall", "out": 2, "in": {"stone": 4}, "station": "stonecutter"},
	{"id": "stone_floor", "out": 4, "in": {"stone": 2}, "station": "stonecutter"},
	{"id": "brick_wall", "out": 2, "in": {"brick": 4}, "station": "stonecutter"},
	# --- tanning rack: leather goods
	{"id": "leather", "out": 1, "in": {"hide": 2}, "station": "tanning_rack"},
	{"id": "leather_armor", "out": 1, "in": {"leather": 5, "rope": 2}, "station": "tanning_rack"},
	{"id": "leather_cap", "out": 1, "in": {"leather": 3}, "station": "tanning_rack"},
	{"id": "leather_boots", "out": 1, "in": {"leather": 2, "rope": 1}, "station": "tanning_rack"},
	# --- anvil: metal tools, weapons, armor and jewellery
	{"id": "copper_axe", "out": 1, "in": {"stick": 2, "copper_ingot": 3}, "station": "anvil"},
	{"id": "copper_pickaxe", "out": 1, "in": {"stick": 2, "copper_ingot": 3}, "station": "anvil"},
	{"id": "copper_sword", "out": 1, "in": {"stick": 1, "copper_ingot": 2}, "station": "anvil"},
	{"id": "copper_helm", "out": 1, "in": {"copper_ingot": 4, "leather": 1}, "station": "anvil"},
	{"id": "copper_armor", "out": 1, "in": {"copper_ingot": 8, "leather": 2}, "station": "anvil"},
	{"id": "copper_boots", "out": 1, "in": {"copper_ingot": 3, "leather": 1}, "station": "anvil"},
	{"id": "copper_ring", "out": 1, "in": {"copper_ingot": 2}, "station": "anvil"},
	{"id": "iron_axe", "out": 1, "in": {"stick": 2, "iron_ingot": 3}, "station": "anvil"},
	{"id": "iron_pickaxe", "out": 1, "in": {"stick": 2, "iron_ingot": 3}, "station": "anvil"},
	{"id": "iron_sword", "out": 1, "in": {"stick": 1, "iron_ingot": 2}, "station": "anvil"},
	{"id": "iron_helm", "out": 1, "in": {"iron_ingot": 4, "leather": 1}, "station": "anvil"},
	{"id": "iron_armor", "out": 1, "in": {"iron_ingot": 8, "leather": 3}, "station": "anvil"},
	{"id": "iron_boots", "out": 1, "in": {"iron_ingot": 3, "leather": 1}, "station": "anvil"},
	{"id": "crystal_blade", "out": 1, "in": {"stick": 1, "crystal": 3, "iron_ingot": 2}, "station": "anvil"},
	{"id": "crystal_ring", "out": 1, "in": {"crystal": 2, "iron_ingot": 1}, "station": "anvil"},
	{"id": "crystal_amulet", "out": 1, "in": {"crystal": 3, "copper_ingot": 2, "rope": 1}, "station": "anvil"},
	# --- cooking pot: meals
	{"id": "berry_jam", "out": 1, "in": {"berry": 4}, "station": "cooking_pot"},
	{"id": "mushroom_soup", "out": 1, "in": {"mushroom": 3, "berry": 1}, "station": "cooking_pot"},
	{"id": "meat_stew", "out": 1, "in": {"cooked_meat": 1, "mushroom": 2, "berry": 2}, "station": "cooking_pot"},
]

## Crafting stations (node groups) with display names; "" means by hand.
const STATIONS := {
	"": "Handcraft", "campfire": "Campfire", "workbench": "Workbench", "furnace": "Furnace",
	"anvil": "Anvil", "cooking_pot": "Cooking Pot", "tanning_rack": "Tanning Rack", "stonecutter": "Stonecutter",
}


## Indices into RECIPES made at a given station ("" = by hand).
static func recipes_at(station: String) -> Array:
	var out := []
	for i in RECIPES.size():
		if RECIPES[i].station == station:
			out.append(i)
	return out


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


static func hp_of(id: String) -> int:
	return ITEMS[id].get("hp", 0)


## Equipment slot the item goes into ("" = not equippable).
static func slot_of(id: String) -> String:
	if not ITEMS.has(id):
		return ""
	var item: Dictionary = ITEMS[id]
	if item.has("slot"):
		return item.slot
	return "weapon" if item.get("dmg", 0) > 0 else ""
