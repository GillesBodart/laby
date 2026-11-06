class_name EnemyCatalog
extends RefCounted
## Data table of every creature (no nodes). Two biomes: the forest of the
## Clearing and the stone Labyrinth. Sprites are Dungeon Crawl Stone Soup
## tiles (CC0) imported by tools/generate_placeholder_art.gd.
##
## Fields (missing ones fall back to DEFAULTS):
##   name, biome ("forest" | "labyrinth"), hp, damage, speed, aggro, range,
##   cooldown, xp, radius, face (-1 sprite looks left, 1 right, 0 front)
##   temper  passive (flees) | neutral (fights back) | hostile | nocturnal
##           (hostile at dusk and night, neutral by day)
##   attack  melee | charge | pounce | slam | ranged | hit_run | ambush |
##           explode | summon | blink
##   drops   [{id, min, max, chance}]
##   shield  fraction of damage blocked from the front while guarding
##   armor   flat damage absorbed per hit
##   effect  "poison" | "slow" applied by its hits
##   projectile {kind, speed, count, spread, effect} for ranged / summon
##   keep    preferred distance for ranged attackers
##   regen   hp per second
##   summon, summon_max  creature spawned by summoners
##   blast   explosion radius
##   phasing walks through walls
##   depth   [min, max] maze depth band (labyrinth), weight = spawn weight

const DEFAULTS := {
	"hp": 20, "damage": 6, "speed": 60.0, "aggro": 130.0, "range": 20.0, "cooldown": 1.2,
	"xp": 5, "radius": 7.0, "face": 0, "temper": "hostile", "attack": "melee",
	"drops": [], "shield": 0.0, "armor": 0, "effect": "", "projectile": {}, "keep": 0.0,
	"regen": 0.0, "summon": "", "summon_max": 0, "blast": 0.0, "phasing": false,
	"depth": [0.0, 9.0], "weight": 1.0, "elite": false,
}

const TYPES := {
	# ============================================================ forest
	"hare": {"name": "Meadow Hare", "biome": "forest", "hp": 10, "damage": 0, "speed": 78.0, "radius": 6.0,
		"face": -1, "temper": "passive", "xp": 2, "weight": 3.0,
		"drops": [{"id": "raw_meat", "min": 1, "max": 1, "chance": 1.0}, {"id": "fur", "min": 1, "max": 1, "chance": 0.5}]},
	"woolback": {"name": "Woolback", "biome": "forest", "hp": 20, "damage": 0, "speed": 40.0, "radius": 9.0,
		"face": 1, "temper": "passive", "xp": 3, "weight": 2.5,
		"drops": [{"id": "wool", "min": 1, "max": 3, "chance": 1.0}, {"id": "raw_meat", "min": 1, "max": 2, "chance": 1.0}]},
	"glimmerwing": {"name": "Glimmerwing", "biome": "forest", "hp": 6, "damage": 0, "speed": 50.0, "radius": 5.0,
		"temper": "passive", "xp": 2, "weight": 2.0,
		"drops": [{"id": "wing_dust", "min": 1, "max": 2, "chance": 1.0}]},
	"lantern_fly": {"name": "Lantern Fly", "biome": "forest", "hp": 7, "damage": 0, "speed": 46.0, "radius": 5.0,
		"face": -1, "temper": "passive", "xp": 3, "weight": 1.5,
		"drops": [{"id": "glow_gland", "min": 1, "max": 1, "chance": 0.7}, {"id": "wing_dust", "min": 1, "max": 1, "chance": 0.5}]},
	"shell_crawler": {"name": "Shell Crawler", "biome": "forest", "hp": 24, "damage": 0, "speed": 16.0, "armor": 3,
		"face": -1, "temper": "passive", "xp": 4, "weight": 1.5,
		"drops": [{"id": "shell", "min": 1, "max": 1, "chance": 1.0}, {"id": "slime", "min": 1, "max": 2, "chance": 0.8}]},
	"tusk_boar": {"name": "Tusk Boar", "biome": "forest", "hp": 42, "damage": 9, "speed": 58.0, "radius": 9.0,
		"face": -1, "temper": "neutral", "attack": "charge", "cooldown": 2.2, "xp": 10, "weight": 2.0,
		"drops": [{"id": "raw_meat", "min": 1, "max": 3, "chance": 1.0}, {"id": "tusk", "min": 1, "max": 1, "chance": 0.5},
			{"id": "hide", "min": 1, "max": 1, "chance": 0.6}]},
	"bramble_bear": {"name": "Bramble Bear", "biome": "forest", "hp": 90, "damage": 16, "speed": 52.0, "radius": 11.0,
		"face": 1, "temper": "neutral", "attack": "slam", "range": 26.0, "cooldown": 2.0, "blast": 34.0, "xp": 26,
		"drops": [{"id": "raw_meat", "min": 2, "max": 4, "chance": 1.0}, {"id": "fur", "min": 2, "max": 3, "chance": 1.0},
			{"id": "honey", "min": 1, "max": 1, "chance": 0.3}]},
	"horned_yak": {"name": "Horned Yak", "biome": "forest", "hp": 70, "damage": 12, "speed": 44.0, "radius": 11.0,
		"face": 1, "temper": "neutral", "attack": "charge", "cooldown": 2.6, "xp": 18,
		"drops": [{"id": "raw_meat", "min": 2, "max": 3, "chance": 1.0}, {"id": "hide", "min": 1, "max": 2, "chance": 1.0},
			{"id": "wool", "min": 1, "max": 2, "chance": 0.6}]},
	"bumbler": {"name": "Bumbler", "biome": "forest", "hp": 14, "damage": 5, "speed": 84.0, "radius": 6.0,
		"face": -1, "temper": "neutral", "attack": "hit_run", "effect": "poison", "xp": 6,
		"drops": [{"id": "honey", "min": 1, "max": 1, "chance": 0.6}, {"id": "wing_dust", "min": 1, "max": 1, "chance": 0.5}]},
	"mossback": {"name": "Mossback", "biome": "forest", "hp": 60, "damage": 8, "speed": 26.0, "radius": 10.0,
		"face": 1, "temper": "neutral", "shield": 0.8, "armor": 2, "cooldown": 1.6, "xp": 14,
		"drops": [{"id": "shell", "min": 1, "max": 2, "chance": 1.0}, {"id": "raw_meat", "min": 1, "max": 2, "chance": 0.8}]},
	"bark_gecko": {"name": "Bark Gecko", "biome": "forest", "hp": 20, "damage": 6, "speed": 96.0, "radius": 7.0,
		"face": 1, "temper": "neutral", "attack": "hit_run", "xp": 6,
		"drops": [{"id": "scale", "min": 1, "max": 2, "chance": 1.0}, {"id": "hide", "min": 1, "max": 1, "chance": 0.3}]},
	"dusk_jackal": {"name": "Dusk Jackal", "biome": "forest", "hp": 30, "damage": 8, "speed": 98.0, "radius": 8.0,
		"face": -1, "temper": "nocturnal", "cooldown": 1.0, "aggro": 170.0, "xp": 9, "weight": 1.5,
		"drops": [{"id": "fur", "min": 1, "max": 1, "chance": 0.8}, {"id": "fang", "min": 1, "max": 1, "chance": 0.5},
			{"id": "raw_meat", "min": 1, "max": 1, "chance": 0.7}]},
	"shadow_wolf": {"name": "Shadow Wolf", "biome": "forest", "hp": 56, "damage": 13, "speed": 90.0, "radius": 9.0,
		"face": -1, "temper": "nocturnal", "attack": "pounce", "cooldown": 1.8, "aggro": 190.0, "xp": 18,
		"drops": [{"id": "fur", "min": 1, "max": 2, "chance": 1.0}, {"id": "fang", "min": 1, "max": 2, "chance": 0.8},
			{"id": "raw_meat", "min": 1, "max": 2, "chance": 1.0}]},
	"grass_adder": {"name": "Grass Adder", "biome": "forest", "hp": 18, "damage": 7, "speed": 70.0, "radius": 6.0,
		"face": 1, "attack": "ambush", "effect": "poison", "xp": 7,
		"drops": [{"id": "scale", "min": 1, "max": 2, "chance": 1.0}, {"id": "venom_sac", "min": 1, "max": 1, "chance": 0.4}]},
	"leaping_spider": {"name": "Leaping Spider", "biome": "forest", "hp": 22, "damage": 7, "speed": 66.0, "radius": 7.0,
		"attack": "pounce", "effect": "poison", "cooldown": 1.6, "xp": 8,
		"drops": [{"id": "silk", "min": 1, "max": 2, "chance": 1.0}, {"id": "venom_sac", "min": 1, "max": 1, "chance": 0.3},
			{"id": "chitin", "min": 1, "max": 1, "chance": 0.4}]},
	"ember_wasp": {"name": "Ember Wasp", "biome": "forest", "hp": 16, "damage": 7, "speed": 104.0, "radius": 6.0,
		"face": 1, "attack": "hit_run", "effect": "poison", "xp": 7,
		"drops": [{"id": "chitin", "min": 1, "max": 1, "chance": 0.7}, {"id": "venom_sac", "min": 1, "max": 1, "chance": 0.3},
			{"id": "wing_dust", "min": 1, "max": 1, "chance": 0.4}]},
	"spitting_toad": {"name": "Spitting Toad", "biome": "forest", "hp": 28, "damage": 6, "speed": 34.0, "radius": 8.0,
		"face": -1, "attack": "ranged", "keep": 80.0, "cooldown": 2.0, "range": 150.0, "xp": 8,
		"projectile": {"kind": "spit", "speed": 120.0, "effect": "slow"},
		"drops": [{"id": "slime", "min": 1, "max": 2, "chance": 1.0}, {"id": "venom_sac", "min": 1, "max": 1, "chance": 0.3}]},
	"carrion_crow": {"name": "Carrion Crow", "biome": "forest", "hp": 16, "damage": 6, "speed": 110.0, "radius": 6.0,
		"face": -1, "temper": "nocturnal", "attack": "hit_run", "aggro": 180.0, "xp": 6,
		"drops": [{"id": "feather", "min": 1, "max": 3, "chance": 1.0}]},
	"puffcap": {"name": "Puffcap", "biome": "forest", "hp": 14, "damage": 14, "speed": 44.0, "radius": 7.0,
		"attack": "explode", "effect": "poison", "blast": 38.0, "range": 18.0, "xp": 6,
		"drops": [{"id": "spores", "min": 1, "max": 3, "chance": 1.0}, {"id": "mushroom", "min": 1, "max": 1, "chance": 0.5}]},
	"thicket_archer": {"name": "Thicket Archer", "biome": "forest", "hp": 36, "damage": 8, "speed": 56.0, "radius": 7.0,
		"attack": "ranged", "keep": 110.0, "range": 170.0, "cooldown": 1.8, "aggro": 170.0, "xp": 14,
		"projectile": {"kind": "arrow", "speed": 190.0},
		"drops": [{"id": "flint_arrow", "min": 1, "max": 4, "chance": 1.0}, {"id": "feather", "min": 1, "max": 2, "chance": 0.6},
			{"id": "short_bow", "min": 1, "max": 1, "chance": 0.05}]},
	"thicket_warden": {"name": "Thicket Warden", "biome": "forest", "hp": 72, "damage": 11, "speed": 46.0, "radius": 8.0,
		"shield": 0.85, "cooldown": 1.4, "xp": 18,
		"drops": [{"id": "wood", "min": 2, "max": 3, "chance": 1.0}, {"id": "resin", "min": 1, "max": 2, "chance": 0.6},
			{"id": "wooden_shield", "min": 1, "max": 1, "chance": 0.08}]},
	"thicket_druid": {"name": "Thicket Druid", "biome": "forest", "hp": 50, "damage": 9, "speed": 44.0, "radius": 7.0,
		"attack": "summon", "summon": "puffcap", "summon_max": 3, "keep": 100.0, "range": 160.0, "cooldown": 2.2, "xp": 22,
		"projectile": {"kind": "thorn", "speed": 150.0, "count": 3, "spread": 0.3},
		"drops": [{"id": "herb", "min": 2, "max": 3, "chance": 1.0}, {"id": "petals", "min": 1, "max": 3, "chance": 0.8},
			{"id": "healing_salve", "min": 1, "max": 1, "chance": 0.2}]},
	"elder_treant": {"name": "Elder Treant", "biome": "forest", "hp": 180, "damage": 22, "speed": 28.0, "radius": 13.0,
		"temper": "neutral", "attack": "slam", "range": 30.0, "blast": 44.0, "cooldown": 2.6, "armor": 4, "regen": 2.0,
		"xp": 45, "weight": 0.4, "elite": true,
		"drops": [{"id": "wood", "min": 6, "max": 10, "chance": 1.0}, {"id": "resin", "min": 2, "max": 4, "chance": 1.0},
			{"id": "herb", "min": 2, "max": 4, "chance": 0.8}]},
	# ============================================================ labyrinth
	"cave_rat": {"name": "Cave Rat", "biome": "labyrinth", "hp": 14, "damage": 5, "speed": 82.0, "radius": 6.0,
		"face": 1, "cooldown": 0.9, "xp": 4, "depth": [0.0, 0.6], "weight": 2.0,
		"drops": [{"id": "raw_meat", "min": 1, "max": 1, "chance": 0.5}, {"id": "fur", "min": 1, "max": 1, "chance": 0.4}]},
	"grub": {"name": "Moss Grub", "biome": "labyrinth", "hp": 22, "damage": 6, "speed": 42.0, "radius": 7.0,
		"face": 1, "effect": "slow", "cooldown": 1.1, "xp": 6, "depth": [0.0, 0.5], "weight": 2.0,
		"drops": [{"id": "slime", "min": 1, "max": 2, "chance": 1.0}, {"id": "hide", "min": 1, "max": 1, "chance": 0.4}]},
	"dart_bat": {"name": "Dart Bat", "biome": "labyrinth", "hp": 14, "damage": 6, "speed": 112.0, "radius": 6.0,
		"attack": "hit_run", "aggro": 160.0, "xp": 6, "depth": [0.05, 9.0],
		"drops": [{"id": "wing_dust", "min": 1, "max": 1, "chance": 0.6}, {"id": "fang", "min": 1, "max": 1, "chance": 0.3}]},
	"stalker": {"name": "Stalker", "biome": "labyrinth", "hp": 38, "damage": 10, "speed": 92.0, "radius": 8.0,
		"face": -1, "aggro": 150.0, "cooldown": 0.9, "xp": 12, "depth": [0.25, 9.0],
		"drops": [{"id": "raw_meat", "min": 1, "max": 2, "chance": 1.0}, {"id": "bone", "min": 1, "max": 2, "chance": 0.6},
			{"id": "fang", "min": 1, "max": 1, "chance": 0.4}]},
	"vine_stalker": {"name": "Vine Lurker", "biome": "labyrinth", "hp": 40, "damage": 11, "speed": 64.0, "radius": 8.0,
		"attack": "ambush", "xp": 12, "depth": [0.15, 0.9],
		"drops": [{"id": "vine", "min": 2, "max": 3, "chance": 1.0}, {"id": "herb", "min": 1, "max": 1, "chance": 0.4}]},
	"maze_spider": {"name": "Maze Spider", "biome": "labyrinth", "hp": 26, "damage": 8, "speed": 70.0, "radius": 7.0,
		"attack": "pounce", "effect": "poison", "cooldown": 1.6, "xp": 9, "depth": [0.2, 9.0],
		"drops": [{"id": "silk", "min": 1, "max": 2, "chance": 1.0}, {"id": "chitin", "min": 1, "max": 1, "chance": 0.5},
			{"id": "venom_sac", "min": 1, "max": 1, "chance": 0.3}]},
	"broodmother": {"name": "Broodmother", "biome": "labyrinth", "hp": 95, "damage": 10, "speed": 38.0, "radius": 11.0,
		"attack": "summon", "summon": "maze_spider", "summon_max": 3, "keep": 90.0, "range": 150.0, "cooldown": 2.4,
		"xp": 32, "depth": [0.55, 9.0], "weight": 0.5, "elite": true,
		"projectile": {"kind": "web", "speed": 130.0, "effect": "slow"},
		"drops": [{"id": "silk", "min": 3, "max": 5, "chance": 1.0}, {"id": "venom_sac", "min": 1, "max": 2, "chance": 1.0},
			{"id": "chitin", "min": 2, "max": 2, "chance": 1.0}]},
	"acid_blob": {"name": "Acid Blob", "biome": "labyrinth", "hp": 30, "damage": 7, "speed": 30.0, "radius": 8.0,
		"attack": "ranged", "keep": 80.0, "range": 140.0, "cooldown": 2.0, "xp": 9, "depth": [0.2, 9.0],
		"projectile": {"kind": "spit", "speed": 120.0, "effect": "poison"},
		"drops": [{"id": "slime", "min": 2, "max": 3, "chance": 1.0}, {"id": "sulfur", "min": 1, "max": 1, "chance": 0.3}]},
	"ooze": {"name": "Grey Ooze", "biome": "labyrinth", "hp": 52, "damage": 9, "speed": 34.0, "radius": 9.0,
		"effect": "slow", "regen": 2.0, "cooldown": 1.3, "xp": 12, "depth": [0.3, 9.0],
		"drops": [{"id": "slime", "min": 2, "max": 4, "chance": 1.0}, {"id": "glowcap", "min": 1, "max": 1, "chance": 0.3}]},
	"centipede": {"name": "Rock Centipede", "biome": "labyrinth", "hp": 34, "damage": 9, "speed": 72.0, "radius": 8.0,
		"face": 1, "effect": "poison", "cooldown": 1.1, "xp": 10, "depth": [0.2, 0.9],
		"drops": [{"id": "chitin", "min": 1, "max": 2, "chance": 1.0}, {"id": "venom_sac", "min": 1, "max": 1, "chance": 0.4}]},
	"tunnel_beetle": {"name": "Tunnel Beetle", "biome": "labyrinth", "hp": 60, "damage": 12, "speed": 50.0, "radius": 9.0,
		"face": -1, "attack": "charge", "shield": 0.7, "armor": 2, "cooldown": 2.4, "xp": 16, "depth": [0.3, 9.0],
		"drops": [{"id": "chitin", "min": 2, "max": 3, "chance": 1.0}, {"id": "copper_ore", "min": 1, "max": 2, "chance": 0.4}]},
	"bone_guard": {"name": "Bone Guard", "biome": "labyrinth", "hp": 70, "damage": 12, "speed": 48.0, "radius": 8.0,
		"shield": 0.85, "cooldown": 1.3, "xp": 18, "depth": [0.35, 9.0],
		"drops": [{"id": "bone", "min": 2, "max": 3, "chance": 1.0}, {"id": "scrap", "min": 1, "max": 2, "chance": 0.5},
			{"id": "iron_shield", "min": 1, "max": 1, "chance": 0.04}]},
	"bone_slinger": {"name": "Bone Slinger", "biome": "labyrinth", "hp": 32, "damage": 8, "speed": 56.0, "radius": 7.0,
		"attack": "ranged", "keep": 100.0, "range": 160.0, "cooldown": 1.7, "xp": 11, "depth": [0.25, 9.0],
		"projectile": {"kind": "bone", "speed": 170.0},
		"drops": [{"id": "bone", "min": 1, "max": 3, "chance": 1.0}]},
	"scrap_raider": {"name": "Scrap Raider", "biome": "labyrinth", "hp": 46, "damage": 11, "speed": 64.0, "radius": 8.0,
		"face": -1, "attack": "ranged", "keep": 110.0, "range": 170.0, "cooldown": 2.0, "xp": 15, "depth": [0.3, 9.0],
		"projectile": {"kind": "javelin", "speed": 200.0},
		"drops": [{"id": "scrap", "min": 1, "max": 3, "chance": 1.0}, {"id": "leather", "min": 1, "max": 1, "chance": 0.4},
			{"id": "iron_arrow", "min": 2, "max": 5, "chance": 0.3}]},
	"gargoyle": {"name": "Gargoyle", "biome": "labyrinth", "hp": 80, "damage": 14, "speed": 60.0, "radius": 9.0,
		"attack": "ambush", "armor": 4, "cooldown": 1.3, "xp": 22, "depth": [0.45, 9.0],
		"drops": [{"id": "stone", "min": 2, "max": 4, "chance": 1.0}, {"id": "quartz", "min": 1, "max": 1, "chance": 0.3},
			{"id": "obsidian", "min": 1, "max": 1, "chance": 0.15}]},
	"spark_wisp": {"name": "Spark Wisp", "biome": "labyrinth", "hp": 18, "damage": 20, "speed": 76.0, "radius": 6.0,
		"attack": "explode", "blast": 42.0, "range": 18.0, "xp": 10, "depth": [0.4, 9.0],
		"drops": [{"id": "spark_core", "min": 1, "max": 1, "chance": 0.5}]},
	"sentinel_orb": {"name": "Sentinel Orb", "biome": "labyrinth", "hp": 50, "damage": 9, "speed": 44.0, "radius": 8.0,
		"attack": "ranged", "keep": 120.0, "range": 170.0, "cooldown": 2.2, "armor": 2, "xp": 18, "depth": [0.5, 9.0],
		"projectile": {"kind": "bolt", "speed": 180.0, "count": 3, "spread": 0.25},
		"drops": [{"id": "spark_core", "min": 1, "max": 1, "chance": 0.4}, {"id": "cog", "min": 1, "max": 2, "chance": 0.8},
			{"id": "scrap", "min": 1, "max": 2, "chance": 0.6}]},
	"arc_servitor": {"name": "Arc Servitor", "biome": "labyrinth", "hp": 85, "damage": 10, "speed": 40.0, "radius": 9.0,
		"attack": "ranged", "keep": 100.0, "range": 160.0, "cooldown": 2.6, "armor": 3, "xp": 28, "depth": [0.65, 9.0],
		"projectile": {"kind": "bolt", "speed": 160.0, "count": 5, "spread": 0.6},
		"drops": [{"id": "spark_core", "min": 1, "max": 2, "chance": 0.7}, {"id": "cog", "min": 1, "max": 3, "chance": 1.0},
			{"id": "silver_ore", "min": 1, "max": 2, "chance": 0.4}]},
	"watcher_eye": {"name": "Watcher Eye", "biome": "labyrinth", "hp": 45, "damage": 9, "speed": 0.0, "radius": 9.0,
		"face": -1, "attack": "ranged", "range": 190.0, "aggro": 190.0, "cooldown": 1.6, "xp": 14, "depth": [0.3, 9.0],
		"projectile": {"kind": "orb", "speed": 140.0},
		"drops": [{"id": "glow_gland", "min": 1, "max": 1, "chance": 0.6}, {"id": "ectoplasm", "min": 1, "max": 1, "chance": 0.3}]},
	"wraith": {"name": "Wraith", "biome": "labyrinth", "hp": 55, "damage": 14, "speed": 66.0, "radius": 8.0,
		"attack": "blink", "cooldown": 1.4, "aggro": 170.0, "xp": 22, "depth": [0.55, 9.0],
		"drops": [{"id": "ectoplasm", "min": 1, "max": 2, "chance": 1.0}, {"id": "shadow_petal", "min": 1, "max": 1, "chance": 0.2}]},
	"echo_phantom": {"name": "Echo Phantom", "biome": "labyrinth", "hp": 40, "damage": 12, "speed": 74.0, "radius": 7.0,
		"attack": "hit_run", "phasing": true, "aggro": 170.0, "xp": 18, "depth": [0.45, 9.0],
		"drops": [{"id": "ectoplasm", "min": 1, "max": 1, "chance": 1.0}]},
	"rust_golem": {"name": "Rust Golem", "biome": "labyrinth", "hp": 120, "damage": 18, "speed": 36.0, "radius": 11.0,
		"attack": "slam", "range": 28.0, "blast": 38.0, "cooldown": 2.2, "armor": 5, "xp": 32, "depth": [0.55, 9.0],
		"drops": [{"id": "scrap", "min": 3, "max": 5, "chance": 1.0}, {"id": "iron_ore", "min": 1, "max": 2, "chance": 0.6},
			{"id": "cog", "min": 1, "max": 1, "chance": 0.5}]},
	"warden": {"name": "Stone Warden", "biome": "labyrinth", "hp": 140, "damage": 20, "speed": 38.0, "radius": 11.0,
		"attack": "slam", "range": 28.0, "blast": 40.0, "cooldown": 2.0, "armor": 4, "xp": 38, "depth": [0.7, 9.0],
		"drops": [{"id": "stone", "min": 4, "max": 6, "chance": 1.0}, {"id": "crystal", "min": 1, "max": 1, "chance": 0.3}]},
	"minotaur": {"name": "Maze Minotaur", "biome": "labyrinth", "hp": 220, "damage": 26, "speed": 62.0, "radius": 12.0,
		"face": 1, "attack": "charge", "cooldown": 2.4, "aggro": 180.0, "xp": 70, "depth": [0.8, 9.0], "weight": 0.3, "elite": true,
		"drops": [{"id": "horn", "min": 1, "max": 1, "chance": 1.0}, {"id": "raw_meat", "min": 3, "max": 5, "chance": 1.0},
			{"id": "leather", "min": 2, "max": 3, "chance": 1.0}]},
	"gate_guardian": {"name": "Gate Guardian", "biome": "labyrinth", "hp": 260, "damage": 24, "speed": 34.0, "radius": 12.0,
		"attack": "slam", "range": 30.0, "blast": 46.0, "shield": 0.8, "armor": 6, "cooldown": 2.4, "xp": 80,
		"depth": [0.85, 9.0], "weight": 0.3, "elite": true,
		"drops": [{"id": "gold_ore", "min": 2, "max": 4, "chance": 1.0}, {"id": "obsidian", "min": 2, "max": 3, "chance": 1.0},
			{"id": "crystal", "min": 1, "max": 2, "chance": 1.0}]},
}

static var _cache := {}


static func has(id: String) -> bool:
	return TYPES.has(id)


## Full definition of a creature (DEFAULTS merged with its entry).
static func def(id: String) -> Dictionary:
	if not _cache.has(id):
		var d: Dictionary = DEFAULTS.duplicate(true)
		d.merge(TYPES[id], true)
		_cache[id] = d
	return _cache[id]


static func sprite_path(id: String) -> String:
	return "res://assets/sprites/enemies/%s.png" % id


## Ids of every creature living in a biome.
static func roster(biome: String) -> Array:
	return TYPES.keys().filter(func(id): return TYPES[id].biome == biome)


## Weighted pick of a creature of a biome. In the labyrinth only species
## whose depth band contains `depth` (0 entrance .. ~1.4 far end) qualify.
static func pick(biome: String, depth: float, roll: float, filter := Callable()) -> String:
	var pool := []
	var total := 0.0
	for id in roster(biome):
		var d := def(id)
		if depth < d.depth[0] or depth > d.depth[1]:
			continue
		if filter.is_valid() and not filter.call(d):
			continue
		pool.append(id)
		total += d.weight
	if pool.is_empty():
		return ""
	var x := roll * total
	for id in pool:
		x -= def(id).weight
		if x <= 0.0:
			return id
	return pool[-1]


## Labyrinth species chosen for a maze cell by its distance from the entrance.
static func type_for_depth(depth: float, roll: float) -> String:
	return pick("labyrinth", depth, roll)


## Hostility right now: nocturnal creatures only hunt at dusk and night.
static func is_hostile(id: String, night: bool) -> bool:
	var t: String = def(id).temper
	return t == "hostile" or (t == "nocturnal" and night)
