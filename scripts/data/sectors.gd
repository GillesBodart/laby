class_name Sectors
extends RefCounted
## The chain of labyrinth sectors beyond the Clearing (data only).
## Each sector is a maze generated from the world seed with its own biome,
## climate, palette tint, resources and guardian boss. Killing the guardian
## yields its Key, which unseals the gate north to the next sector; the
## Hell sector's gate needs every Key and leads out of the maze.
##   climate  -2 freezing .. 0 mild .. +2 scorching (see Survival temperature)
##   tint     subtle mood modulate of Ground/Walls (the palette lives in art)
##   moss     share of floor tiles drawn with the accent variant (MAZE_FLOOR_MOSS)
##   resources [node type, weight, minimum depth] (see LabyrinthGenerator)
##   art      look of the sector's tile atlas (see ART and
##            tools/generate_placeholder_art.gd, which paints it):
##     tiles    atlas texture, same layout as TileCatalog.TEXTURE_PATH
##     vines    share of wall faces with the vine variant (WallResolver)
##     top_alt  share of wall tops with the accent-heavy variant (WALL_TOP_MOSS)
##     accent   ivy | moss | sand | frost | ember | corruption
##     cover    wall-top accent coverage (0 none .. 1 everywhere)
##     stone    6 wall-top tones, face 3 wall-face tones, floor 5 floor tones,
##     glow     5 accent tones (all dark -> light), void the unlit pit colour

const ORDER := ["labyrinth", "overgrowth", "desert", "ice", "volcano", "hell"]

const DATA := {
	"labyrinth": {"name": "Stone Labyrinth", "climate": 0, "tint": Color(1, 1, 1), "moss": 0.18,
		"art": {"tiles": "res://assets/tilesets/clearing_tiles.png", "vines": 0.25, "top_alt": 0.3,
			"accent": "ivy", "cover": 0.36,
			"stone": [Color8(64, 72, 72), Color8(84, 94, 92), Color8(104, 114, 108), Color8(124, 134, 124), Color8(146, 154, 142), Color8(172, 178, 162)],
			"face": [Color8(46, 56, 54), Color8(74, 88, 83), Color8(102, 116, 109)],
			"floor": [Color8(36, 42, 44), Color8(50, 58, 58), Color8(60, 68, 67), Color8(70, 79, 76), Color8(84, 93, 88)],
			"glow": [Color8(22, 42, 32), Color8(36, 66, 42), Color8(54, 94, 50), Color8(80, 124, 58), Color8(118, 158, 74)],
			"void": Color8(14, 16, 22)},
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
	"overgrowth": {"name": "Overgrowth", "climate": 0, "tint": Color(0.96, 1.0, 0.94), "moss": 0.6,
		"art": {"tiles": "res://assets/tilesets/sector_overgrowth_tiles.png", "vines": 0.5, "top_alt": 0.5,
			"accent": "moss", "cover": 0.55,
			"stone": [Color8(30, 44, 34), Color8(44, 62, 46), Color8(60, 80, 58), Color8(78, 98, 70), Color8(98, 118, 82), Color8(124, 142, 98)],
			"face": [Color8(24, 36, 28), Color8(46, 64, 48), Color8(70, 90, 64)],
			"floor": [Color8(20, 30, 22), Color8(30, 42, 30), Color8(38, 52, 36), Color8(46, 62, 42), Color8(58, 76, 50)],
			"glow": [Color8(12, 36, 18), Color8(26, 72, 30), Color8(44, 112, 40), Color8(78, 154, 52), Color8(136, 200, 78)],
			"void": Color8(8, 16, 10)},
		"boss": "briar_hydra", "key": "key_overgrowth",
		"greet": "The Overgrowth. Roots split the walls. Something hums.",
		"resources": [
			["thornbush", 4.0, 0.0], ["giant_fern", 5.0, 0.0], ["hive_comb", 1.5, 0.3], ["spore_pod", 3.0, 0.1],
			["root_knot", 2.5, 0.2], ["moonflower", 1.2, 0.5], ["vines", 5.0, 0.0], ["cave_moss", 4.0, 0.0],
			["mushroom", 3.0, 0.0], ["herb", 3.0, 0.0], ["glowcap", 2.0, 0.2], ["beehive", 1.5, 0.1],
			["flower", 2.0, 0.0], ["grass", 4.0, 0.0], ["resin_stump", 2.0, 0.0], ["apple_tree", 1.5, 0.2],
			["blueberry", 2.0, 0.0], ["shadow_orchid", 0.8, 0.6], ["ore_copper", 2.0, 0.0], ["ore_iron", 1.5, 0.4],
		]},
	"desert": {"name": "Sunken Dunes", "climate": 1, "tint": Color(1.04, 1.0, 0.94), "moss": 0.05,
		"art": {"tiles": "res://assets/tilesets/sector_desert_tiles.png", "vines": 0.03, "top_alt": 0.35,
			"accent": "sand", "cover": 0.4,
			"stone": [Color8(116, 72, 40), Color8(150, 98, 56), Color8(180, 126, 74), Color8(204, 152, 94), Color8(224, 178, 118), Color8(242, 206, 150)],
			"face": [Color8(102, 62, 36), Color8(148, 98, 58), Color8(186, 134, 82)],
			"floor": [Color8(108, 74, 44), Color8(132, 94, 58), Color8(146, 106, 66), Color8(158, 118, 74), Color8(172, 132, 86)],
			"glow": [Color8(170, 120, 66), Color8(204, 156, 92), Color8(226, 186, 120), Color8(240, 208, 148), Color8(250, 228, 182)],
			"void": Color8(40, 24, 14)},
		"boss": "sun_wyrm", "key": "key_desert",
		"greet": "The Sunken Dunes. The air burns your throat. Find water.",
		"resources": [
			["cactus", 5.0, 0.0], ["sandstone", 5.0, 0.0], ["dry_bush", 4.0, 0.0], ["salt_flat", 3.0, 0.1],
			["amber_deposit", 1.5, 0.4], ["date_palm", 2.5, 0.1], ["fossil", 1.5, 0.3], ["sunstone", 0.8, 0.7],
			["sand", 4.0, 0.0], ["flint", 3.0, 0.0], ["ore_copper", 2.0, 0.0], ["ore_tin", 2.0, 0.0],
			["ore_gold", 1.5, 0.5], ["ore_silver", 1.5, 0.4], ["bone_pile", 3.0, 0.0], ["quartz", 2.0, 0.3],
			["saltpeter", 2.0, 0.1], ["scrap_heap", 1.5, 0.2], ["rubble", 3.0, 0.0], ["obsidian", 0.8, 0.8],
		]},
	"ice": {"name": "Rime Halls", "climate": -2, "tint": Color(0.97, 1.0, 1.05), "moss": 0.08,
		"art": {"tiles": "res://assets/tilesets/sector_ice_tiles.png", "vines": 0.0, "top_alt": 0.35,
			"accent": "frost", "cover": 0.42,
			"stone": [Color8(62, 84, 112), Color8(84, 110, 140), Color8(110, 140, 170), Color8(140, 170, 198), Color8(174, 202, 224), Color8(212, 232, 246)],
			"face": [Color8(46, 64, 92), Color8(76, 102, 134), Color8(108, 138, 170)],
			"floor": [Color8(44, 60, 82), Color8(58, 76, 100), Color8(66, 86, 112), Color8(76, 98, 124), Color8(90, 112, 138)],
			"glow": [Color8(138, 190, 220), Color8(174, 218, 238), Color8(206, 238, 250), Color8(232, 248, 255), Color8(255, 255, 255)],
			"void": Color8(10, 16, 30)},
		"boss": "hoarfrost_dragon", "key": "key_ice",
		"greet": "The Rime Halls. Frost creeps up the walls. Stay warm.",
		"resources": [
			["ice_block", 5.0, 0.0], ["frost_lichen", 4.0, 0.0], ["snow_drift", 4.0, 0.0], ["ore_mithril", 1.5, 0.4],
			["blue_crystal", 1.5, 0.4], ["frozen_tree", 4.0, 0.0], ["snowberry", 3.0, 0.0], ["rubble", 3.0, 0.0],
			["ore_coal", 4.0, 0.0], ["ore_iron", 3.0, 0.0], ["ore_silver", 2.0, 0.2], ["ore_crystal", 1.2, 0.5],
			["quartz", 2.0, 0.2], ["bone_pile", 2.0, 0.0], ["cave_moss", 2.0, 0.0], ["glowcap", 2.0, 0.1],
			["ore_gold", 1.0, 0.6], ["obsidian", 1.0, 0.7], ["cobweb", 1.5, 0.0], ["mushroom", 1.0, 0.0],
		]},
	"volcano": {"name": "Cinder Forge", "climate": 2, "tint": Color(1.0, 0.96, 0.94), "moss": 0.05,
		"art": {"tiles": "res://assets/tilesets/sector_volcano_tiles.png", "vines": 0.0, "top_alt": 0.4,
			"accent": "ember", "cover": 0.3,
			"stone": [Color8(14, 12, 14), Color8(24, 21, 23), Color8(36, 31, 31), Color8(48, 41, 40), Color8(62, 52, 49), Color8(82, 68, 60)],
			"face": [Color8(14, 12, 14), Color8(34, 29, 30), Color8(56, 47, 45)],
			"floor": [Color8(18, 16, 18), Color8(26, 23, 24), Color8(32, 28, 29), Color8(39, 34, 34), Color8(48, 41, 40)],
			"glow": [Color8(110, 18, 10), Color8(186, 38, 14), Color8(236, 92, 24), Color8(255, 162, 52), Color8(255, 228, 140)],
			"void": Color8(30, 6, 4)},
		"boss": "forgeheart_giant", "key": "key_volcano",
		"greet": "The Cinder Forge. The stones glow. The heat kills the unprepared.",
		"resources": [
			["basalt", 5.0, 0.0], ["magma_vent", 2.0, 0.2], ["ash_pile", 4.0, 0.0], ["ore_ember", 2.0, 0.3],
			["fire_lily", 2.0, 0.1], ["charred_stump", 3.0, 0.0], ["ore_coal", 4.0, 0.0], ["ore_iron", 3.0, 0.0],
			["ore_gold", 1.5, 0.3], ["sulfur", 4.0, 0.0], ["saltpeter", 2.0, 0.0], ["obsidian", 2.5, 0.2],
			["ore_crystal", 1.0, 0.5], ["rubble", 3.0, 0.0], ["quartz", 1.5, 0.2], ["bone_pile", 2.0, 0.0],
			["scrap_heap", 2.0, 0.0], ["machine", 1.5, 0.3], ["glowcap", 1.5, 0.0], ["ore_silver", 1.5, 0.2],
		]},
	"hell": {"name": "Pit", "climate": 2, "tint": Color(1.0, 0.95, 1.0), "moss": 0.1,
		"art": {"tiles": "res://assets/tilesets/sector_hell_tiles.png", "vines": 0.05, "top_alt": 0.4,
			"accent": "corruption", "cover": 0.42,
			"stone": [Color8(28, 14, 32), Color8(44, 22, 50), Color8(62, 32, 68), Color8(82, 44, 86), Color8(104, 60, 104), Color8(130, 82, 124)],
			"face": [Color8(24, 12, 28), Color8(50, 26, 56), Color8(76, 42, 80)],
			"floor": [Color8(24, 12, 26), Color8(32, 18, 34), Color8(38, 22, 40), Color8(46, 27, 47), Color8(56, 34, 56)],
			"glow": [Color8(64, 6, 22), Color8(118, 14, 40), Color8(176, 28, 56), Color8(222, 62, 82), Color8(250, 132, 150)],
			"void": Color8(20, 4, 12)},
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
