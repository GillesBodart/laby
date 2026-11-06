class_name ResourceCatalog
extends RefCounted
## Gatherable resource nodes (besides trees, rocks and berry bushes), which
## all share scenes/world/props/resource_node.tscn. Data only.
##   tool/tier: kind and minimum tier needed to harvest (tier 0 = bare hands)

const NODES := {
	"grass": {"item": "fiber", "amount": 2, "hits": 1, "tool": "hands", "tier": 0, "xp": 1, "walkable": true},
	"mushroom": {"item": "mushroom", "amount": 2, "hits": 1, "tool": "hands", "tier": 0, "xp": 1, "walkable": true},
	"clay": {"item": "clay", "amount": 3, "hits": 2, "tool": "hands", "tier": 0, "xp": 2},
	"ore_coal": {"item": "coal", "amount": 2, "hits": 4, "tool": "pickaxe", "tier": 1, "xp": 5},
	"ore_copper": {"item": "copper_ore", "amount": 2, "hits": 5, "tool": "pickaxe", "tier": 1, "xp": 7},
	"ore_iron": {"item": "iron_ore", "amount": 2, "hits": 6, "tool": "pickaxe", "tier": 2, "xp": 12},
	"ore_crystal": {"item": "crystal", "amount": 1, "hits": 8, "tool": "pickaxe", "tier": 3, "xp": 25},
}


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
