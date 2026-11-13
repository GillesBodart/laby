class_name Sectors
extends RefCounted
## The chain of labyrinth sectors beyond the Clearing (data only).
## Each sector is a maze generated from the world seed with its own biome,
## climate, palette tint, resources and guardian boss. Killing the guardian
## yields its Key, which unseals the gate north to the next sector; the
## Hell sector's gate needs every Key and leads out of the maze.
##   climate  -2 freezing .. 0 mild .. +2 scorching (see Survival temperature)
##   tint     Ground/Walls self_modulate
##   moss     share of floor tiles drawn with the mossy variant
##   resources [node type, weight, minimum depth] (see LabyrinthGenerator)

const ORDER := ["labyrinth", "overgrowth", "desert", "ice", "volcano", "hell"]

const DATA := {
	"labyrinth": {"name": "Stone Labyrinth", "climate": 0, "tint": Color(1, 1, 1), "moss": 0.18,
		"boss": "stone_colossus", "key": "key_stone",
		"greet": "The Stone Labyrinth. The walls swallow the light.",
		"resources": [
			["rubble", 6.0, 0.0], ["ore_coal", 7.0, 0.0], ["ore_copper", 6.0, 0.0], ["ore_tin", 4.0, 0.1],
			["ore_iron", 4.0, 0.4], ["ore_silver", 2.5, 0.55], ["ore_gold", 1.5, 0.75], ["ore_crystal", 1.2, 0.8],
			["quartz", 2.0, 0.35], ["sulfur", 2.0, 0.25], ["saltpeter", 2.0, 0.25],
			["glowcap", 3.0, 0.2], ["cave_moss", 4.0, 0.0], ["vines", 3.5, 0.0], ["bone_pile", 3.0, 0.1],
			["scrap_heap", 2.5, 0.3], ["machine", 1.2, 0.5], ["shadow_orchid", 0.8, 0.65], ["cobweb", 3.0, 0.15],
			["grass", 2.0, 0.0], ["mushroom", 1.5, 0.0],
		]},
	"overgrowth": {"name": "Overgrowth", "climate": 0, "tint": Color(0.78, 1.0, 0.72), "moss": 0.6,
		"boss": "briar_hydra", "key": "key_overgrowth",
		"greet": "The Overgrowth. Roots split the walls. Something hums.",
		"resources": [
			["thornbush", 4.0, 0.0], ["giant_fern", 5.0, 0.0], ["hive_comb", 1.5, 0.3], ["spore_pod", 3.0, 0.1],
			["root_knot", 2.5, 0.2], ["moonflower", 1.2, 0.5], ["vines", 5.0, 0.0], ["cave_moss", 4.0, 0.0],
			["mushroom", 3.0, 0.0], ["herb", 3.0, 0.0], ["glowcap", 2.0, 0.2], ["beehive", 1.5, 0.1],
			["flower", 2.0, 0.0], ["grass", 4.0, 0.0], ["resin_stump", 2.0, 0.0], ["apple_tree", 1.5, 0.2],
			["blueberry", 2.0, 0.0], ["shadow_orchid", 0.8, 0.6], ["ore_copper", 2.0, 0.0], ["ore_iron", 1.5, 0.4],
		]},
	"desert": {"name": "Sunken Dunes", "climate": 1, "tint": Color(1.28, 1.08, 0.74), "moss": 0.05,
		"boss": "sun_wyrm", "key": "key_desert",
		"greet": "The Sunken Dunes. The air burns your throat. Find water.",
		"resources": [
			["cactus", 5.0, 0.0], ["sandstone", 5.0, 0.0], ["dry_bush", 4.0, 0.0], ["salt_flat", 3.0, 0.1],
			["amber_deposit", 1.5, 0.4], ["date_palm", 2.5, 0.1], ["fossil", 1.5, 0.3], ["sunstone", 0.8, 0.7],
			["sand", 4.0, 0.0], ["flint", 3.0, 0.0], ["ore_copper", 2.0, 0.0], ["ore_tin", 2.0, 0.0],
			["ore_gold", 1.5, 0.5], ["ore_silver", 1.5, 0.4], ["bone_pile", 3.0, 0.0], ["quartz", 2.0, 0.3],
			["saltpeter", 2.0, 0.1], ["scrap_heap", 1.5, 0.2], ["rubble", 3.0, 0.0], ["obsidian", 0.8, 0.8],
		]},
	"ice": {"name": "Rime Halls", "climate": -2, "tint": Color(0.86, 1.04, 1.36), "moss": 0.08,
		"boss": "hoarfrost_dragon", "key": "key_ice",
		"greet": "The Rime Halls. Frost creeps up the walls. Stay warm.",
		"resources": [
			["ice_block", 5.0, 0.0], ["frost_lichen", 4.0, 0.0], ["snow_drift", 4.0, 0.0], ["ore_mithril", 1.5, 0.4],
			["blue_crystal", 1.5, 0.4], ["frozen_tree", 4.0, 0.0], ["snowberry", 3.0, 0.0], ["rubble", 3.0, 0.0],
			["ore_coal", 4.0, 0.0], ["ore_iron", 3.0, 0.0], ["ore_silver", 2.0, 0.2], ["ore_crystal", 1.2, 0.5],
			["quartz", 2.0, 0.2], ["bone_pile", 2.0, 0.0], ["cave_moss", 2.0, 0.0], ["glowcap", 2.0, 0.1],
			["ore_gold", 1.0, 0.6], ["obsidian", 1.0, 0.7], ["cobweb", 1.5, 0.0], ["mushroom", 1.0, 0.0],
		]},
	"volcano": {"name": "Cinder Forge", "climate": 2, "tint": Color(0.82, 0.56, 0.48), "moss": 0.05,
		"boss": "forgeheart_giant", "key": "key_volcano",
		"greet": "The Cinder Forge. The stones glow. The heat kills the unprepared.",
		"resources": [
			["basalt", 5.0, 0.0], ["magma_vent", 2.0, 0.2], ["ash_pile", 4.0, 0.0], ["ore_ember", 2.0, 0.3],
			["fire_lily", 2.0, 0.1], ["charred_stump", 3.0, 0.0], ["ore_coal", 4.0, 0.0], ["ore_iron", 3.0, 0.0],
			["ore_gold", 1.5, 0.3], ["sulfur", 4.0, 0.0], ["saltpeter", 2.0, 0.0], ["obsidian", 2.5, 0.2],
			["ore_crystal", 1.0, 0.5], ["rubble", 3.0, 0.0], ["quartz", 1.5, 0.2], ["bone_pile", 2.0, 0.0],
			["scrap_heap", 2.0, 0.0], ["machine", 1.5, 0.3], ["glowcap", 1.5, 0.0], ["ore_silver", 1.5, 0.2],
		]},
	"hell": {"name": "Pit", "climate": 2, "tint": Color(0.96, 0.5, 0.46), "moss": 0.1,
		"boss": "pit_lord", "key": "key_hell",
		"greet": "The Pit. The heart of the maze. Something watches.",
		"resources": [
			["bone_spire", 4.0, 0.0], ["soul_crystal", 1.5, 0.3], ["blood_moss", 4.0, 0.0], ["ore_hellsteel", 2.0, 0.3],
			["brimstone", 3.0, 0.0], ["hellfire_bloom", 1.5, 0.2], ["obsidian", 3.0, 0.0], ["sulfur", 3.0, 0.0],
			["ore_gold", 2.0, 0.2], ["ore_ember", 2.0, 0.1], ["ore_mithril", 1.5, 0.3], ["basalt", 3.0, 0.0],
			["magma_vent", 1.5, 0.2], ["ash_pile", 3.0, 0.0], ["bone_pile", 3.0, 0.0], ["shadow_orchid", 1.5, 0.2],
			["scrap_heap", 2.0, 0.0], ["machine", 1.5, 0.2], ["ore_crystal", 1.5, 0.3], ["ore_iron", 2.0, 0.0],
		]},
}


static func is_sector(area: String) -> bool:
	return DATA.has(area)


static func info(sector: String) -> Dictionary:
	return DATA[sector]


static func index_of(sector: String) -> int:
	return ORDER.find(sector)


## Area south of a sector ("clearing" for the first one).
static func prev_of(sector: String) -> String:
	var i := index_of(sector)
	return "clearing" if i <= 0 else ORDER[i - 1]


## Sector north of this one ("" past the last).
static func next_of(sector: String) -> String:
	var i := index_of(sector)
	return ORDER[i + 1] if i >= 0 and i + 1 < ORDER.size() else ""


static func climate_of(area: String) -> int:
	return DATA[area].climate if DATA.has(area) else 0


static func display_name(area: String) -> String:
	return DATA[area].name if DATA.has(area) else area.capitalize()


## Resource node types appearing in a sector.
static func resource_types(sector: String) -> Array:
	return DATA[sector].resources.map(func(r): return r[0])
