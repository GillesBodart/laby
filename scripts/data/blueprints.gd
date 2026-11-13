class_name Blueprints
extends RefCounted
## Blueprints: rare recipes that no ingredient reveals (data only). They lie in
## the treasure chests hidden at the end of labyrinth dead ends (see
## LabyrinthGenerator.CHEST_COUNT): each sector teaches its own set, and once
## read the whole camp knows them (GameState.blueprints). Chests also hold a
## couple of gems or metals from that sector.

## Recipe outputs taught by the chests of each sector (one per chest).
const POOLS := {
	"labyrinth": ["crystal_blade", "crystal_amulet", "war_hammer", "crossbow"],
	"overgrowth": ["venom_dagger", "glow_amulet", "druid_staff", "horn_halberd"],
	"desert": ["sunstone_ring", "amber_amulet", "arc_staff", "silver_sword"],
	"ice": ["frost_staff", "frost_ring", "mithril_sword", "gold_amulet"],
	"volcano": ["ember_blade", "ember_bow", "fire_staff", "fire_cloak"],
	"hell": ["hellsteel_greatsword", "bone_crown", "soul_amulet", "shadow_amulet"],
}
## Valuables of a sector's chests: [item, min, max]; a chest holds LOOT_PICKS of them.
const LOOT := {
	"labyrinth": [["quartz", 2, 4], ["crystal", 1, 2], ["silver_ingot", 1, 2], ["gold_ingot", 1, 1]],
	"overgrowth": [["crystal", 1, 3], ["amber", 1, 2], ["gold_ingot", 1, 2], ["glow_gland", 1, 2]],
	"desert": [["amber", 2, 3], ["sunstone", 1, 2], ["gold_ingot", 1, 3], ["fossil", 1, 2]],
	"ice": [["frost_crystal", 2, 3], ["mithril_ingot", 1, 2], ["crystal", 1, 3], ["silver_ingot", 2, 3]],
	"volcano": [["obsidian", 2, 4], ["ember_ingot", 1, 2], ["magma_core", 1, 1], ["gold_ingot", 2, 3]],
	"hell": [["soul_shard", 1, 3], ["hellsteel_ingot", 1, 2], ["obsidian", 2, 4], ["gold_ingot", 2, 4]],
}
const LOOT_PICKS := 2

static var _gated := {}


## True when the recipe(s) making `id` need a blueprint to show up.
static func gates(id: String) -> bool:
	if _gated.is_empty():
		for s in POOLS:
			for r in POOLS[s]:
				_gated[r] = s
	return _gated.has(id)


## Sector whose chests teach the blueprint for `id` ("" if none).
static func sector_of(id: String) -> String:
	return _gated.get(id, "") if gates(id) else ""


## The blueprint a chest teaches: one of its sector's not yet known by the camp
## (`roll` in [0, 1) picks which), "" once the sector holds no more.
static func pick(sector: String, known: Dictionary, roll: float) -> String:
	var left: Array = POOLS.get(sector, []).filter(func(id): return not known.has(id))
	if left.is_empty():
		return ""
	return left[mini(int(roll * left.size()), left.size() - 1)]


## A chest's valuables: [{id, count}], LOOT_PICKS distinct entries of the sector's table.
static func loot(sector: String, rng: RandomNumberGenerator) -> Array:
	var table: Array = LOOT.get(sector, LOOT.labyrinth).duplicate()
	var out := []
	for i in mini(LOOT_PICKS, table.size()):
		var e: Array = table.pop_at(rng.randi_range(0, table.size() - 1))
		out.append({"id": e[0], "count": rng.randi_range(e[1], e[2])})
	return out
