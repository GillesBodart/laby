class_name ResourceCatalog
extends RefCounted
## Gatherable resource nodes (besides trees, rocks and berry bushes), which
## all share scenes/world/props/resource_node.tscn. Data only.
##   tool/tier: kind and minimum tier needed to harvest (tier 0 = bare hands)

const NODES := {
	# --- forest (Clearing); trees, rocks and berry bushes have their own scenes
	"grass": {"item": "fiber", "amount": 2, "hits": 1, "tool": "hands", "tier": 0, "xp": 1, "walkable": true},
	"mushroom": {"item": "mushroom", "amount": 2, "hits": 1, "tool": "hands", "tier": 0, "xp": 1, "walkable": true},
	"clay": {"item": "clay", "amount": 3, "hits": 2, "tool": "hands", "tier": 0, "xp": 2},
	"flint": {"item": "flint", "amount": 2, "hits": 2, "tool": "hands", "tier": 0, "xp": 2},
	"reeds": {"item": "reed", "amount": 3, "hits": 1, "tool": "hands", "tier": 0, "xp": 1, "walkable": true},
	"herb": {"item": "herb", "amount": 2, "hits": 1, "tool": "hands", "tier": 0, "xp": 2, "walkable": true},
	"wheat": {"item": "wheat", "amount": 3, "hits": 1, "tool": "hands", "tier": 0, "xp": 1, "walkable": true},
	"cotton": {"item": "cotton", "amount": 2, "hits": 1, "tool": "hands", "tier": 0, "xp": 1, "walkable": true},
	"resin_stump": {"item": "resin", "amount": 2, "hits": 3, "tool": "axe", "tier": 1, "xp": 3},
	"beehive": {"item": "honey", "amount": 2, "hits": 2, "tool": "hands", "tier": 0, "xp": 4},
	"apple_tree": {"item": "apple", "amount": 3, "hits": 3, "tool": "hands", "tier": 0, "xp": 2},
	"carrot": {"item": "carrot", "amount": 2, "hits": 1, "tool": "hands", "tier": 0, "xp": 1, "walkable": true},
	"blueberry": {"item": "blueberry", "amount": 3, "hits": 1, "tool": "hands", "tier": 0, "xp": 1},
	"flower": {"item": "petals", "amount": 2, "hits": 1, "tool": "hands", "tier": 0, "xp": 1, "walkable": true},
	"sand": {"item": "sand", "amount": 3, "hits": 2, "tool": "hands", "tier": 0, "xp": 1, "walkable": true},
	"nest": {"item": "egg", "amount": 2, "hits": 1, "tool": "hands", "tier": 0, "xp": 2, "walkable": true},
	"potato": {"item": "potato", "amount": 2, "hits": 1, "tool": "hands", "tier": 0, "xp": 1, "walkable": true},
	# --- labyrinth (Stone)
	"rubble": {"item": "stone", "amount": 3, "hits": 3, "tool": "pickaxe", "tier": 1, "xp": 2},
	"ore_coal": {"item": "coal", "amount": 2, "hits": 4, "tool": "pickaxe", "tier": 1, "xp": 5},
	"ore_copper": {"item": "copper_ore", "amount": 2, "hits": 5, "tool": "pickaxe", "tier": 1, "xp": 7},
	"ore_tin": {"item": "tin_ore", "amount": 2, "hits": 5, "tool": "pickaxe", "tier": 1, "xp": 7},
	"ore_iron": {"item": "iron_ore", "amount": 2, "hits": 6, "tool": "pickaxe", "tier": 2, "xp": 12},
	"ore_silver": {"item": "silver_ore", "amount": 2, "hits": 6, "tool": "pickaxe", "tier": 2, "xp": 14},
	"ore_gold": {"item": "gold_ore", "amount": 2, "hits": 7, "tool": "pickaxe", "tier": 3, "xp": 18},
	"ore_crystal": {"item": "crystal", "amount": 1, "hits": 8, "tool": "pickaxe", "tier": 3, "xp": 25},
	"quartz": {"item": "quartz", "amount": 2, "hits": 5, "tool": "pickaxe", "tier": 2, "xp": 10},
	"obsidian": {"item": "obsidian", "amount": 2, "hits": 9, "tool": "pickaxe", "tier": 3, "xp": 28},
	"sulfur": {"item": "sulfur", "amount": 2, "hits": 3, "tool": "pickaxe", "tier": 1, "xp": 6},
	"saltpeter": {"item": "saltpeter", "amount": 2, "hits": 3, "tool": "pickaxe", "tier": 1, "xp": 6},
	"glowcap": {"item": "glowcap", "amount": 2, "hits": 1, "tool": "hands", "tier": 0, "xp": 4, "walkable": true},
	"cave_moss": {"item": "moss", "amount": 3, "hits": 1, "tool": "hands", "tier": 0, "xp": 1, "walkable": true},
	"vines": {"item": "vine", "amount": 3, "hits": 2, "tool": "hands", "tier": 0, "xp": 2},
	"bone_pile": {"item": "bone", "amount": 3, "hits": 2, "tool": "hands", "tier": 0, "xp": 3},
	"scrap_heap": {"item": "scrap", "amount": 3, "hits": 4, "tool": "pickaxe", "tier": 1, "xp": 6},
	"machine": {"item": "cog", "amount": 2, "hits": 6, "tool": "pickaxe", "tier": 2, "xp": 15},
	"shadow_orchid": {"item": "shadow_petal", "amount": 1, "hits": 1, "tool": "hands", "tier": 0, "xp": 10, "walkable": true},
	"cobweb": {"item": "silk", "amount": 2, "hits": 1, "tool": "hands", "tier": 0, "xp": 2, "walkable": true},
}

## Resource nodes found in each biome (trees, rocks and bushes are separate scenes).
const FOREST := ["tree", "rock", "bush", "grass", "mushroom", "clay", "flint", "reeds", "herb", "wheat",
	"cotton", "resin_stump", "beehive", "apple_tree", "carrot", "blueberry", "flower", "sand", "nest", "potato"]
const LABYRINTH := ["rubble", "ore_coal", "ore_copper", "ore_tin", "ore_iron", "ore_silver", "ore_gold",
	"ore_crystal", "quartz", "obsidian", "sulfur", "saltpeter", "glowcap", "cave_moss", "vines", "bone_pile",
	"scrap_heap", "machine", "shadow_orchid", "cobweb"]


static func has(type: String) -> bool:
	return NODES.has(type)


static func texture_path(type: String) -> String:
	return "res://assets/sprites/resources/%s.png" % type


## Copies the node definition onto a Gatherable.
static func apply(node: Gatherable, type: String) -> void:
	var d: Dictionary = NODES[type]
	node.item_id = d.item
	node.yield_amount = d.amount
	node.max_hits = d.hits
	node.tool_kind = d.tool
	node.min_tier = d.tier
	node.xp = d.xp
