class_name EnemyCatalog
extends RefCounted
## Data table of every creature (no nodes). One heroic-fantasy bestiary
## grouped into families (wolves, goblinkin, brutes, undead...) whose species
## climb a ladder of variants biome after biome. Sprites are 9x3 pose sheets
## drawn by tools/creature_art.gd from each family's rig (see CreatureSheet).
##
## Fields (missing ones fall back to DEFAULTS):
##   name, lore (one-line journal flavour), biome, family (key of FAMILIES),
##   rig (optional override of the family rig), hp, damage, speed, aggro, range,
##   cooldown, xp, radius
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
##   boss    sector guardian placed in the arena, never picked randomly
##   volley  {kind, speed, count, spread, effect, every} ring fired by bosses
## Drops may also be written compactly as [id, min, max, chance].
## Biomes: forest, labyrinth, overgrowth, desert, ice, volcano, hell.

const DEFAULTS := {
	"hp": 20, "damage": 6, "speed": 60.0, "aggro": 130.0, "range": 20.0, "cooldown": 1.2,
	"xp": 5, "radius": 7.0, "temper": "hostile", "attack": "melee", "family": "", "rig": "",
	"drops": [], "shield": 0.0, "armor": 0, "effect": "", "projectile": {}, "keep": 0.0,
	"regen": 0.0, "summon": "", "summon_max": 0, "blast": 0.0, "phasing": false,
	"depth": [0.0, 9.0], "weight": 1.0, "elite": false, "boss": false, "volley": {}, "lore": "",
}

## Creature families: shared silhouette, rig (body plan of the art generator
## and the animation driver) and journal line.
const FAMILIES := {
	"grazers": {"name": "Grazers", "rig": "quadruped",
		"lore": "Grass in, wool out. Leave them be and they will return the favour."},
	"canines": {"name": "Wolves & Hounds", "rig": "quadruped",
		"lore": "Pack hunters. Where you see one, count the shadows behind it."},
	"bears": {"name": "Bears", "rig": "quadruped",
		"lore": "Bristle and claw. They were here first and will say so loudly."},
	"vermin": {"name": "Crawlers", "rig": "crawler",
		"lore": "Too many legs, every one of them in a hurry."},
	"wingpests": {"name": "Wings", "rig": "flyer",
		"lore": "Buzzing, flapping, and always where the food is."},
	"wyrmkin": {"name": "Wyrmkin", "rig": "serpent",
		"lore": "No legs, then legs, then wings. The big ones never stop growing."},
	"goblinkin": {"name": "Little Folk", "rig": "biped",
		"lore": "Goblins, kobolds, gnomes: small, greedy, and better organised than you'd like."},
	"brutes": {"name": "Big Folk", "rig": "biped",
		"lore": "Too big for the corridors. They widen them."},
	"undead": {"name": "The Restless", "rig": "biped",
		"lore": "The maze kept them. They never noticed they were allowed to stop."},
	"demons": {"name": "Pitborn", "rig": "biped",
		"lore": "Born of the Pit's heat. They find the rest of the maze chilly and dull."},
	"spirits": {"name": "Wisps & Shades", "rig": "spirit",
		"lore": "Weather, fire and grief that got up and drifted."},
	"fungus": {"name": "Capfolk", "rig": "fungus",
		"lore": "Mushrooms that walk. Each has one trick, and it only works once."},
}

## Ids of creatures cut from the bestiary, mapped to the species that replaced
## them, so old saves (companions, journal) keep working.
const LEGACY := {
	"glimmerwing": "gloss_moth", "lantern_fly": "gloss_moth", "shell_crawler": "grub",
	"horned_yak": "tusk_boar", "mossback": "bramble_bear", "bark_gecko": "shade_mamba",
	"shadow_wolf": "stalker", "grass_adder": "shade_mamba", "ember_wasp": "bumbler",
	"spitting_toad": "deathcap", "carrion_crow": "dart_bat", "thicket_archer": "goblin_archer",
	"thicket_warden": "goblin_guard", "thicket_druid": "goblin_archer", "elder_treant": "bramble_bear",
	"cave_rat": "grub", "vine_stalker": "stalker", "acid_blob": "grub", "ooze": "grub",
	"centipede": "maze_spider", "tunnel_beetle": "grub", "bone_slinger": "kobold_slinger",
	"scrap_raider": "kobold_slinger", "gargoyle": "bone_guard", "sentinel_orb": "spark_wisp",
	"arc_servitor": "spark_wisp", "watcher_eye": "spark_wisp", "echo_phantom": "wraith",
	"rust_golem": "bone_guard", "warden": "bone_guard", "gate_guardian": "minotaur",
	"treehopper": "gloss_moth", "wild_hog": "tusk_boar", "wolf_spider": "maze_spider",
	"bog_leaper": "shade_mamba", "spined_toad": "deathcap", "vine_constrictor": "shade_mamba",
	"bloodgnat": "hive_stinger", "thorn_hunter": "deathcap", "briar_patch": "deathcap",
	"grove_dryad": "deathcap", "satyr_raider": "orc_javelineer", "gnoll_poacher": "goblin_archer",
	"moss_wyrm": "ash_wyvern",
	"sand_lizard": "dune_yak", "dust_mammoth": "mammoth_yak", "basilisk": "salamander",
	"catoblepas": "mammoth_yak", "carrion_shrike": "dart_bat", "riddle_sphinx": "tomb_king",
	"dune_archer": "orc_javelineer", "yaktaur_captain": "orc_javelineer",
	"naga_sharpshooter": "orc_javelineer", "naga_warrior": "dune_scorpion", "jackal_sentinel": "mummy",
	"dust_devil": "fire_elemental", "sand_twister": "fire_elemental", "tomb_ushabti": "mummy",
	"dune_harpy": "dart_bat",
	"ice_newt": "snow_sheep", "rime_beast": "frost_wolf", "hippogriff": "frost_wolf",
	"griffon": "rime_alpha", "blizzard_demon": "frost_gnome", "ice_devil": "frost_troll",
	"hungry_ghost": "wraith", "drowned_soul": "wraith", "meltwater_elemental": "frost_troll",
	"crystal_guardian": "frost_troll", "azure_jelly": "grub", "glint_eye": "frost_gnome",
	"silent_spectre": "wraith", "snow_tengu": "frost_wolf",
	"firebrand": "salamander", "storm_salamander": "salamander", "flame_vortex": "fire_elemental",
	"basalt_elemental": "magma_crab", "iron_golem": "ash_ogre", "fire_orb": "salamander",
	"efreet": "fire_elemental", "red_devil": "crimson_imp", "sun_demon": "fire_elemental",
	"boulder_beetle": "magma_crab", "ember_spider": "maze_spider", "magma_wasp": "cinder_bat",
	"hell_hog": "hellhound", "hell_beast": "hellhound", "hellwing": "quasit", "tormentor": "hellion",
	"soul_eater": "quasit", "smoke_demon": "quasit", "shadow_imp": "quasit", "iron_imp": "quasit",
	"demonic_crawler": "hell_knight", "green_death": "hellion", "blue_devil": "hell_knight",
	"flayed_ghost": "reaper",
}

const TYPES := {
	# ============================================================ forest
	"hare": {"name": "Meadow Hare", "lore": "Fast, fluffy and convinced you are a very slow wolf.", "biome": "forest", "family": "grazers", "hp": 10, "damage": 0, "speed": 78.0, "radius": 6.0,
		"temper": "passive", "xp": 2, "weight": 3.0,
		"drops": [{"id": "raw_meat", "min": 1, "max": 1, "chance": 1.0}, {"id": "fur", "min": 1, "max": 1, "chance": 0.5}]},
	"woolback": {"name": "Woolback", "lore": "Grows wool, eats grass, has no further plans.", "biome": "forest", "family": "grazers", "hp": 20, "damage": 0, "speed": 40.0, "radius": 9.0,
		"temper": "passive", "xp": 3, "weight": 2.5,
		"drops": [{"id": "wool", "min": 1, "max": 3, "chance": 1.0}, {"id": "raw_meat", "min": 1, "max": 2, "chance": 1.0}]},
	"tusk_boar": {"name": "Tusk Boar", "lore": "Charges first and has never once asked a question.", "biome": "forest", "family": "grazers", "hp": 42, "damage": 9, "speed": 58.0, "radius": 9.0,
		"temper": "neutral", "attack": "charge", "cooldown": 2.2, "xp": 10, "weight": 2.0,
		"drops": [{"id": "raw_meat", "min": 1, "max": 3, "chance": 1.0}, {"id": "tusk", "min": 1, "max": 1, "chance": 0.5},
			{"id": "hide", "min": 1, "max": 1, "chance": 0.6}]},
	"bramble_bear": {"name": "Bramble Bear", "lore": "Wears half the hedge it sleeps in. Its hugs are not friendly.", "biome": "forest", "family": "bears", "hp": 90, "damage": 16, "speed": 52.0, "radius": 11.0,
		"temper": "neutral", "attack": "slam", "range": 26.0, "cooldown": 2.0, "blast": 34.0, "xp": 26,
		"drops": [{"id": "raw_meat", "min": 2, "max": 4, "chance": 1.0}, {"id": "fur", "min": 2, "max": 3, "chance": 1.0},
			{"id": "honey", "min": 1, "max": 1, "chance": 0.3}]},
	"bumbler": {"name": "Bumbler", "lore": "Too round to fly well, too proud to stop trying.", "biome": "forest", "family": "wingpests", "hp": 14, "damage": 5, "speed": 84.0, "radius": 6.0,
		"temper": "neutral", "attack": "hit_run", "effect": "poison", "xp": 6,
		"drops": [{"id": "honey", "min": 1, "max": 1, "chance": 0.6}, {"id": "wing_dust", "min": 1, "max": 1, "chance": 0.5}]},
	"dusk_jackal": {"name": "Dusk Jackal", "lore": "Polite by day. After sunset it remembers it has teeth.", "biome": "forest", "family": "canines", "hp": 30, "damage": 8, "speed": 98.0, "radius": 8.0,
		"temper": "nocturnal", "cooldown": 1.0, "aggro": 170.0, "xp": 9, "weight": 1.5,
		"drops": [{"id": "fur", "min": 1, "max": 1, "chance": 0.8}, {"id": "fang", "min": 1, "max": 1, "chance": 0.5},
			{"id": "raw_meat", "min": 1, "max": 1, "chance": 0.7}]},
	"leaping_spider": {"name": "Leaping Spider", "lore": "Eight eyes, all of them judging your jump.", "biome": "forest", "family": "vermin", "hp": 22, "damage": 7, "speed": 66.0, "radius": 7.0,
		"attack": "pounce", "effect": "poison", "cooldown": 1.6, "xp": 8,
		"drops": [{"id": "silk", "min": 1, "max": 2, "chance": 1.0}, {"id": "venom_sac", "min": 1, "max": 1, "chance": 0.3},
			{"id": "chitin", "min": 1, "max": 1, "chance": 0.4}]},
	"puffcap": {"name": "Puffcap", "lore": "A mushroom with one trick, and it only works once.", "biome": "forest", "family": "fungus", "hp": 14, "damage": 14, "speed": 44.0, "radius": 7.0,
		"attack": "explode", "effect": "poison", "blast": 38.0, "range": 18.0, "xp": 6,
		"drops": [{"id": "spores", "min": 1, "max": 3, "chance": 1.0}, {"id": "mushroom", "min": 1, "max": 1, "chance": 0.5}]},
	"goblin_archer": {"name": "Goblin Archer", "lore": "Hides in the bushes, shoots first, collects the arrows later.", "biome": "forest", "family": "goblinkin", "hp": 36, "damage": 8, "speed": 56.0, "radius": 7.0,
		"attack": "ranged", "range": 170.0, "keep": 110.0, "cooldown": 1.8, "aggro": 170.0, "xp": 14, "weight": 0.8,
		"projectile": {"kind": "arrow", "speed": 190.0},
		"drops": [["flint_arrow", 1, 4, 1.0], ["feather", 1, 2, 0.6], ["short_bow", 1, 1, 0.05]]},
	"goblin_guard": {"name": "Goblin Guard", "lore": "A shield of bark and a grudge older than the trees.", "biome": "forest", "family": "goblinkin", "hp": 60, "damage": 10, "speed": 46.0, "radius": 8.0,
		"shield": 0.85, "cooldown": 1.4, "xp": 14, "weight": 0.8,
		"drops": [["wood", 1, 2, 1.0], ["hide", 1, 1, 0.5], ["wooden_shield", 1, 1, 0.08]]},
	# ============================================================ labyrinth
	"grub": {"name": "Moss Grub", "lore": "Leaves slime on everything, including your boots, for days.", "biome": "labyrinth", "family": "vermin", "hp": 22, "damage": 6, "speed": 42.0, "radius": 7.0,
		"effect": "slow", "cooldown": 1.1, "xp": 6, "depth": [0.0, 0.5], "weight": 2.0,
		"drops": [{"id": "slime", "min": 1, "max": 2, "chance": 1.0}, {"id": "hide", "min": 1, "max": 1, "chance": 0.4}]},
	"dart_bat": {"name": "Dart Bat", "lore": "Echolocates. Darts. Echolocates your ear.", "biome": "labyrinth", "family": "wingpests", "hp": 14, "damage": 6, "speed": 112.0, "radius": 6.0,
		"attack": "hit_run", "aggro": 160.0, "xp": 6, "depth": [0.05, 9.0],
		"drops": [{"id": "wing_dust", "min": 1, "max": 1, "chance": 0.6}, {"id": "fang", "min": 1, "max": 1, "chance": 0.3}]},
	"stalker": {"name": "Grey Wolf", "lore": "Hunts at night in total silence, which is somehow worse than howling.", "biome": "labyrinth", "family": "canines", "hp": 38, "damage": 10, "speed": 92.0, "radius": 8.0,
		"aggro": 150.0, "cooldown": 0.9, "xp": 12, "depth": [0.25, 9.0],
		"drops": [["raw_meat", 1, 1, 1.0], ["fang", 1, 1, 0.6], ["fur", 1, 1, 0.6]]},
	"maze_spider": {"name": "Maze Spider", "lore": "Knows the maze better than you. Spun half the cobwebs in it.", "biome": "labyrinth", "family": "vermin", "hp": 26, "damage": 8, "speed": 70.0, "radius": 7.0,
		"attack": "pounce", "effect": "poison", "cooldown": 1.6, "xp": 9, "depth": [0.2, 9.0],
		"drops": [{"id": "silk", "min": 1, "max": 2, "chance": 1.0}, {"id": "chitin", "min": 1, "max": 1, "chance": 0.5},
			{"id": "venom_sac", "min": 1, "max": 1, "chance": 0.3}]},
	"bone_guard": {"name": "Bone Guard", "lore": "Still on duty. Nobody told it the shift ended long ago.", "biome": "labyrinth", "family": "undead", "hp": 70, "damage": 12, "speed": 48.0, "radius": 8.0,
		"shield": 0.85, "cooldown": 1.3, "xp": 18, "depth": [0.35, 9.0],
		"drops": [{"id": "bone", "min": 2, "max": 3, "chance": 1.0}, {"id": "scrap", "min": 1, "max": 2, "chance": 0.5},
			{"id": "iron_shield", "min": 1, "max": 1, "chance": 0.04}]},
	"spark_wisp": {"name": "Storm Wisp", "lore": "A scrap of storm caught in the walls, looking for something to strike.", "biome": "labyrinth", "family": "spirits", "hp": 18, "damage": 20, "speed": 76.0, "radius": 6.0,
		"attack": "explode", "blast": 36.0, "range": 18.0, "xp": 10, "depth": [0.4, 9.0],
		"drops": [["spark_core", 1, 1, 0.7], ["ectoplasm", 1, 1, 0.3]]},
	"wraith": {"name": "Wraith", "lore": "A cold draught with opinions.", "biome": "labyrinth", "family": "spirits", "hp": 55, "damage": 14, "speed": 66.0, "radius": 8.0,
		"attack": "blink", "cooldown": 1.4, "aggro": 170.0, "xp": 22, "depth": [0.55, 9.0],
		"drops": [{"id": "ectoplasm", "min": 1, "max": 2, "chance": 1.0}, {"id": "shadow_petal", "min": 1, "max": 1, "chance": 0.2}]},
	"broodmother": {"name": "Broodmother", "lore": "Never alone. Never, ever alone.", "biome": "labyrinth", "family": "vermin", "hp": 140, "damage": 10, "speed": 38.0, "radius": 11.0,
		"attack": "summon", "summon": "maze_spider", "summon_max": 3, "keep": 90.0, "range": 150.0, "cooldown": 2.4,
		"xp": 32, "depth": [0.55, 9.0], "weight": 0.5, "elite": true,
		"projectile": {"kind": "web", "speed": 130.0, "effect": "slow"},
		"drops": [{"id": "silk", "min": 3, "max": 5, "chance": 1.0}, {"id": "venom_sac", "min": 1, "max": 2, "chance": 1.0},
			{"id": "chitin", "min": 2, "max": 2, "chance": 1.0}]},
	"minotaur": {"name": "Maze Minotaur", "lore": "Lives in a maze, loves the maze, takes trespassing personally.", "biome": "labyrinth", "family": "brutes", "hp": 220, "damage": 26, "speed": 62.0, "radius": 12.0,
		"attack": "charge", "cooldown": 2.4, "aggro": 180.0, "xp": 70, "depth": [0.8, 9.0], "weight": 0.3, "elite": true,
		"drops": [{"id": "horn", "min": 1, "max": 1, "chance": 1.0}, {"id": "raw_meat", "min": 3, "max": 5, "chance": 1.0},
			{"id": "leather", "min": 2, "max": 3, "chance": 1.0}]},
	"stone_colossus": {"name": "Stone Colossus", "lore": "A piece of the walls that learned to stand. It lets nothing pass.", "biome": "labyrinth", "family": "brutes", "boss": true, "hp": 700, "damage": 30, "speed": 40.0,
		"radius": 16.0, "attack": "slam", "range": 34.0, "blast": 56.0, "armor": 6, "cooldown": 2.0, "aggro": 200.0, "xp": 180,
		"volley": {"kind": "bone", "speed": 170.0, "count": 5, "spread": 0.8, "every": 4.0},
		"drops": [["key_stone", 1, 1, 1.0], ["crystal", 3, 5, 1.0], ["iron_ore", 4, 6, 1.0], ["gold_ore", 2, 3, 1.0]]},
	"kobold_slinger": {"name": "Kobold Slinger", "lore": "Throws rocks with great aim and terrible manners.", "biome": "labyrinth", "family": "goblinkin", "hp": 30, "damage": 7, "speed": 60.0, "radius": 7.0,
		"attack": "ranged", "range": 160.0, "keep": 100.0, "cooldown": 1.7, "xp": 7, "depth": [0.12, 9.0], "weight": 1.2,
		"projectile": {"kind": "bone", "speed": 170.0},
		"drops": [["bone", 1, 2, 0.6], ["cog", 1, 1, 0.25], ["copper_ore", 1, 1, 0.3]]},
	"she_wolf": {"name": "She-wolf", "lore": "Treats every passer-by as a threat to her pups. Correctly.", "biome": "labyrinth", "family": "canines", "hp": 44, "damage": 11, "speed": 96.0, "radius": 8.0,
		"attack": "pounce", "cooldown": 1.6, "aggro": 160.0, "xp": 14, "depth": [0.45, 9.0], "weight": 0.8,
		"drops": [["fur", 1, 2, 0.8], ["fang", 1, 1, 0.5], ["raw_meat", 1, 1, 0.7]]},
	# ============================================================ overgrowth
	"gloss_moth": {"name": "Gloss Moth", "lore": "So shiny it keeps landing on its own reflection.", "biome": "overgrowth", "family": "wingpests", "hp": 10, "damage": 0, "speed": 50.0, "radius": 5.0,
		"temper": "passive", "xp": 3, "weight": 2.0, "drops": [["wing_dust", 1, 2, 1.0]]},
	"moss_bear": {"name": "Moss Bear", "lore": "Hibernates all year. Wakes up grumpy about it.", "biome": "overgrowth", "family": "bears", "hp": 130, "damage": 20, "speed": 52.0, "radius": 11.0,
		"temper": "neutral", "attack": "slam", "range": 28.0, "blast": 36.0, "cooldown": 2.0, "xp": 34, "depth": [0.2, 9.0], "shield": 0.5,
		"drops": [["raw_meat", 2, 4, 1.0], ["fur", 2, 3, 1.0], ["moss", 2, 3, 1.0]]},
	"shade_mamba": {"name": "Shade Mamba", "lore": "Bites you twice before you finish saying ow.", "biome": "overgrowth", "family": "wyrmkin", "hp": 38, "damage": 10, "speed": 82.0, "radius": 6.0,
		"attack": "ambush", "effect": "poison", "xp": 16, "depth": [0.1, 9.0], "drops": [["venom_sac", 1, 1, 0.8], ["scale", 1, 1, 0.5]]},
	"hive_stinger": {"name": "Hive Stinger", "lore": "Works hard for the queen. Stings hard for the queen.", "biome": "overgrowth", "family": "wingpests", "hp": 18, "damage": 7, "speed": 88.0, "radius": 5.0,
		"attack": "hit_run", "effect": "poison", "xp": 8, "weight": 2.0, "drops": [["honey", 1, 1, 0.4], ["wing_dust", 1, 1, 0.5]]},
	"hive_queen": {"name": "Hive Queen", "lore": "Never lifts a stinger herself. Has several thousand for that.", "biome": "overgrowth", "family": "wingpests", "projectile": {"kind": "spit", "speed": 130.0, "effect": "slow"}, "hp": 140, "damage": 12, "speed": 40.0, "radius": 10.0,
		"attack": "summon", "summon": "hive_stinger", "summon_max": 4, "range": 160.0, "keep": 100.0, "cooldown": 2.4, "xp": 40,
		"elite": true, "weight": 0.4, "depth": [0.6, 9.0], "drops": [["royal_jelly", 1, 2, 1.0], ["honey", 2, 4, 1.0]]},
	"wander_cap": {"name": "Wandering Cap", "lore": "A mushroom that wandered off. Nobody knows where it is going.", "biome": "overgrowth", "family": "fungus", "hp": 26, "damage": 18, "speed": 44.0, "attack": "explode",
		"blast": 40.0, "effect": "poison", "xp": 10, "drops": [["spores", 1, 3, 1.0], ["mushroom", 1, 2, 1.0]]},
	"deathcap": {"name": "Deathcap", "lore": "The name is the warning. The spores are the punchline.", "biome": "overgrowth", "family": "fungus", "hp": 40, "damage": 8, "speed": 0.0, "attack": "ranged", "range": 150.0,
		"aggro": 150.0, "cooldown": 2.2, "xp": 12, "projectile": {"kind": "spit", "speed": 150.0, "effect": "poison"},
		"drops": [["spores", 2, 3, 1.0], ["glowcap", 1, 1, 0.5]]},
	"briar_hydra": {"rig": "quadruped", "name": "Briar Hydra", "lore": "Cut one head and the briars grow two. The Overgrowth feeds it.", "biome": "overgrowth", "family": "wyrmkin", "boss": true, "hp": 1000, "damage": 26, "speed": 44.0,
		"radius": 16.0, "attack": "ranged", "keep": 70.0, "range": 180.0, "aggro": 220.0, "cooldown": 1.8, "armor": 4, "regen": 2.0,
		"xp": 250, "projectile": {"kind": "thorn", "speed": 190.0, "count": 5, "spread": 0.9},
		"volley": {"kind": "spit", "speed": 140.0, "count": 8, "spread": 3.14, "effect": "poison", "every": 5.0},
		"drops": [["key_overgrowth", 1, 1, 1.0], ["living_root", 4, 6, 1.0], ["thorn", 6, 10, 1.0], ["scale", 3, 5, 1.0]]},
	"werewolf": {"name": "Werewolf", "lore": "Was a survivor once. Got lost one full moon and stayed lost.", "biome": "overgrowth", "family": "canines", "rig": "biped", "hp": 260, "damage": 24, "speed": 90.0, "radius": 12.0,
		"attack": "pounce", "cooldown": 1.8, "aggro": 190.0, "armor": 2, "regen": 1.5, "xp": 80, "elite": true, "weight": 0.35, "depth": [0.75, 9.0],
		"drops": [["fur", 2, 3, 1.0], ["fang", 1, 2, 1.0], ["moon_petal", 1, 1, 0.5]]},
	# ============================================================ desert
	"dune_yak": {"name": "Dune Yak", "lore": "Carries its own water in its hump and will not share.", "biome": "desert", "family": "grazers", "hp": 90, "damage": 0, "speed": 40.0, "radius": 12.0,
		"temper": "passive", "xp": 8, "weight": 1.5, "drops": [["raw_meat", 2, 4, 1.0], ["hide", 2, 2, 1.0], ["fur", 1, 2, 1.0]]},
	"dune_scorpion": {"name": "Dune Scorpion", "lore": "Tail up, claws out, mood permanently bad.", "biome": "desert", "family": "vermin", "shield": 0.6, "hp": 60, "damage": 13, "speed": 58.0, "radius": 8.0,
		"effect": "poison", "armor": 2, "xp": 18, "weight": 2.0, "drops": [["chitin", 1, 2, 1.0], ["venom_sac", 1, 1, 0.5]]},
	"emperor_scorpion": {"name": "Emperor Scorpion", "lore": "Rules the dunes from beneath them. Expects you to bow.", "biome": "desert", "family": "vermin", "cooldown": 2.4, "attack": "charge", "hp": 260, "damage": 26, "speed": 50.0, "radius": 13.0,
		"effect": "poison", "armor": 6, "shield": 0.5, "xp": 70, "elite": true, "weight": 0.35, "depth": [0.75, 9.0],
		"drops": [["chitin", 4, 6, 1.0], ["venom_sac", 2, 3, 1.0], ["amber", 1, 1, 0.5]]},
	"sandworm": {"name": "Dune Borer", "lore": "You hear it under the sand just before you hear nothing.", "biome": "desert", "family": "wyrmkin", "hp": 140, "damage": 24, "speed": 60.0, "radius": 11.0, "attack": "ambush",
		"xp": 36, "depth": [0.35, 9.0], "drops": [["hide", 2, 2, 1.0], ["raw_meat", 2, 3, 1.0], ["fossil", 1, 1, 0.3]]},
	"sun_wyrm": {"name": "Sun Wyrm", "lore": "It swims in the hot sand under the dunes. When it rises, the light goes white.", "biome": "desert", "family": "wyrmkin", "boss": true, "hp": 1400, "damage": 32, "speed": 54.0, "radius": 16.0,
		"attack": "ranged", "keep": 80.0, "range": 200.0, "aggro": 220.0, "cooldown": 1.8, "armor": 5, "xp": 400,
		"projectile": {"kind": "fire", "speed": 200.0, "count": 5, "spread": 0.7},
		"volley": {"kind": "fire", "speed": 150.0, "count": 12, "spread": 3.14, "every": 5.0},
		"drops": [["key_desert", 1, 1, 1.0], ["sunstone", 3, 5, 1.0], ["scale", 5, 8, 1.0], ["gold_ore", 4, 6, 1.0]]},
	"dune_hound": {"name": "Dune Jackal", "lore": "Thin, quick, and paid in bones.", "biome": "desert", "family": "canines", "hp": 50, "damage": 12, "speed": 86.0, "radius": 8.0,
		"temper": "nocturnal", "xp": 14, "weight": 2.5, "drops": [["fur", 1, 2, 1.0], ["fang", 1, 1, 0.5], ["raw_meat", 1, 1, 1.0]]},
	"orc_javelineer": {"name": "Orc Spearthrower", "lore": "Throws spears, fetches them, throws them again. Thrifty.", "biome": "desert", "family": "brutes", "hp": 110, "damage": 18, "speed": 48.0, "radius": 10.0,
		"attack": "ranged", "range": 170.0, "keep": 110.0, "cooldown": 2.0, "armor": 1, "xp": 24, "depth": [0.1, 9.0], "weight": 1.2,
		"projectile": {"kind": "javelin", "speed": 200.0},
		"drops": [["leather", 1, 2, 1.0], ["scrap", 1, 2, 0.4], ["bronze_ingot", 1, 1, 0.15]]},
	"mummy": {"name": "Mummy", "lore": "Wrapped up for eternity. Got up early, and in a mood.", "biome": "desert", "family": "undead", "hp": 150, "damage": 22, "speed": 34.0, "radius": 10.0,
		"attack": "slam", "range": 26.0, "blast": 32.0, "cooldown": 2.2, "armor": 2, "effect": "slow", "xp": 30, "depth": [0.3, 9.0],
		"drops": [["fiber", 2, 3, 1.0], ["bone", 1, 2, 1.0], ["amber", 1, 1, 0.2]]},
	"tomb_king": {"name": "Tomb King", "lore": "Ruled the dunes before the walls rose. Still expects the sand to kneel.", "biome": "desert", "family": "undead", "hp": 240, "damage": 22, "speed": 44.0, "radius": 12.0,
		"attack": "summon", "summon": "mummy", "summon_max": 2, "range": 160.0, "keep": 100.0, "cooldown": 2.6, "armor": 3, "effect": "slow",
		"xp": 70, "elite": true, "weight": 0.3, "depth": [0.8, 9.0],
		"projectile": {"kind": "orb", "speed": 150.0, "effect": "slow"},
		"drops": [["gold_ore", 1, 2, 1.0], ["amber", 1, 2, 1.0], ["sunstone", 1, 1, 0.5]]},
	# ============================================================ ice
	"snow_sheep": {"name": "Snow Sheep", "lore": "Wool so thick it has never felt the cold, or fear.", "biome": "ice", "family": "grazers", "hp": 50, "damage": 0, "speed": 44.0, "radius": 9.0, "temper": "passive",
		"xp": 6, "weight": 2.5, "drops": [["wool", 2, 4, 1.0], ["raw_meat", 1, 2, 1.0]]},
	"mammoth_yak": {"name": "Mammoth Yak", "lore": "A yak, but more. Much more.", "biome": "ice", "family": "grazers", "shield": 0.6, "hp": 280, "damage": 28, "speed": 50.0, "radius": 14.0,
		"temper": "neutral", "attack": "charge", "cooldown": 2.8, "xp": 60, "depth": [0.3, 9.0], "weight": 0.7,
		"drops": [["frost_pelt", 2, 3, 1.0], ["raw_meat", 4, 6, 1.0], ["horn", 1, 2, 1.0]]},
	"frost_wolf": {"name": "White Wolf", "lore": "Vanishes into the snow. Reappears much closer.", "biome": "ice", "family": "canines", "cooldown": 1.8, "effect": "slow", "attack": "pounce", "hp": 80, "damage": 16, "speed": 90.0, "radius": 9.0, "xp": 22,
		"weight": 2.5, "drops": [["frost_pelt", 1, 2, 1.0], ["fang", 1, 1, 0.6]]},
	"snow_bear": {"name": "Snow Bear", "lore": "Leaves you alone if you leave it alone. Mostly.", "biome": "ice", "family": "bears", "hp": 240, "damage": 30, "speed": 54.0, "radius": 13.0, "temper": "neutral",
		"attack": "slam", "range": 28.0, "blast": 36.0, "cooldown": 2.0, "xp": 56, "depth": [0.25, 9.0],
		"drops": [["frost_pelt", 2, 4, 1.0], ["raw_meat", 3, 5, 1.0]]},
	"frost_troll": {"name": "Frost Troll", "lore": "Regrows anything you chop off. Remembers who chopped it.", "biome": "ice", "family": "brutes", "hp": 300, "damage": 30, "speed": 56.0, "radius": 13.0, "regen": 4.0,
		"armor": 3, "xp": 70, "depth": [0.55, 9.0], "weight": 0.6, "drops": [["frost_pelt", 2, 3, 1.0], ["hide", 2, 2, 1.0], ["mithril_ore", 1, 1, 0.4]]},
	"frost_giant": {"name": "Frost Giant", "lore": "Big, slow and very cold. Mostly the cold.", "biome": "ice", "family": "brutes", "hp": 420, "damage": 38, "speed": 40.0, "radius": 16.0, "attack": "slam",
		"range": 32.0, "blast": 50.0, "armor": 6, "xp": 120, "elite": true, "weight": 0.3, "depth": [0.8, 9.0],
		"drops": [["frost_crystal", 2, 4, 1.0], ["mithril_ore", 2, 3, 1.0], ["frost_pelt", 3, 3, 1.0]]},
	"hoarfrost_dragon": {"rig": "quadruped", "name": "Hoarfrost Dragon", "lore": "Its breath is the cold that took the sleepers. It has never stopped breathing.", "biome": "ice", "family": "wyrmkin", "boss": true, "hp": 1900, "damage": 38, "speed": 56.0,
		"radius": 18.0, "attack": "ranged", "keep": 80.0, "range": 200.0, "aggro": 220.0, "cooldown": 1.8, "armor": 6, "xp": 550,
		"projectile": {"kind": "frost", "speed": 200.0, "count": 5, "spread": 0.8, "effect": "slow"},
		"volley": {"kind": "frost", "speed": 140.0, "count": 12, "spread": 3.14, "every": 5.0},
		"drops": [["key_ice", 1, 1, 1.0], ["frost_crystal", 5, 8, 1.0], ["mithril_ore", 5, 8, 1.0], ["scale", 5, 8, 1.0]]},
	"rime_alpha": {"name": "Alpha Wolf", "lore": "Eats first, howls last, and has the scars to settle any argument.", "biome": "ice", "family": "canines", "hp": 300, "damage": 28, "speed": 88.0, "radius": 12.0,
		"attack": "summon", "summon": "frost_wolf", "summon_max": 2, "range": 150.0, "keep": 80.0, "cooldown": 2.4, "aggro": 190.0, "armor": 2, "effect": "slow",
		"xp": 90, "elite": true, "weight": 0.3, "depth": [0.8, 9.0],
		"projectile": {"kind": "frost", "speed": 170.0, "count": 3, "spread": 0.4},
		"drops": [["frost_pelt", 2, 3, 1.0], ["fang", 2, 2, 1.0], ["mithril_ore", 1, 1, 0.3]]},
	"frost_gnome": {"name": "Gnome Rimecaster", "lore": "Three hundred years old. Throws ice like it still holds a grudge.", "biome": "ice", "family": "goblinkin", "hp": 90, "damage": 18, "speed": 52.0, "radius": 7.0,
		"attack": "ranged", "range": 170.0, "keep": 110.0, "cooldown": 1.8, "effect": "slow", "xp": 20, "depth": [0.15, 9.0], "weight": 1.5,
		"projectile": {"kind": "frost", "speed": 170.0, "effect": "slow"},
		"drops": [["frost_crystal", 1, 1, 0.7], ["quartz", 1, 1, 0.3], ["ice", 1, 1, 0.4]]},
	# ============================================================ volcano
	"cinder_bat": {"name": "Cinder Bat", "lore": "Flies through the smoke for fun. Is, technically, on fire.", "biome": "volcano", "family": "wingpests", "hp": 50, "damage": 14, "speed": 96.0, "radius": 6.0, "attack": "hit_run",
		"xp": 14, "weight": 2.5, "drops": [["wing_dust", 1, 2, 1.0], ["ash", 1, 1, 0.5]]},
	"magma_crab": {"name": "Magma Crab", "lore": "Walks sideways through lava, very smug about it.", "biome": "volcano", "family": "vermin", "hp": 160, "damage": 22, "speed": 40.0, "radius": 10.0, "armor": 8,
		"shield": 0.5, "xp": 40, "drops": [["shell", 2, 2, 1.0], ["magma_core", 1, 1, 0.3], ["basalt", 1, 2, 1.0]]},
	"salamander": {"rig": "quadruped", "name": "Salamander", "lore": "Bathes in lava, which tells you everything you need to know.", "biome": "volcano", "family": "wyrmkin", "projectile": {"kind": "fire", "speed": 170.0}, "cooldown": 2.0, "armor": 2, "keep": 100.0, "range": 160.0, "attack": "ranged", "hp": 160, "damage": 24, "speed": 66.0, "radius": 10.0, "xp": 40,
		"drops": [["scale", 2, 2, 1.0], ["fire_gland", 1, 1, 0.5]]},
	"crimson_imp": {"name": "Emberling", "lore": "Small, quick, and setting things alight for the giggles.", "biome": "volcano", "family": "demons", "hp": 90, "damage": 18, "speed": 74.0, "radius": 7.0, "attack": "blink",
		"cooldown": 1.4, "xp": 26, "weight": 2.0, "drops": [["ectoplasm", 1, 1, 1.0], ["fire_gland", 1, 1, 0.3]]},
	"ember_mystic": {"name": "Goblin Firecaller", "lore": "Calls the embers and they come. You wish it called them less.", "biome": "volcano", "family": "goblinkin", "hp": 200, "damage": 20, "speed": 44.0, "attack": "summon",
		"summon": "cinder_bat", "summon_max": 3, "keep": 120.0, "range": 180.0, "cooldown": 2.4, "xp": 56, "depth": [0.5, 9.0],
		"weight": 0.6, "projectile": {"kind": "fire", "speed": 170.0}, "drops": [["fire_gland", 2, 2, 1.0], ["fire_petal", 1, 2, 1.0]]},
	"fire_elemental": {"name": "Fire Elemental", "lore": "A bonfire that got up and left.", "biome": "volcano", "family": "spirits", "hp": 160, "damage": 24, "speed": 84.0, "radius": 10.0,
		"attack": "hit_run", "phasing": true, "xp": 44, "depth": [0.25, 9.0], "drops": [["magma_core", 1, 1, 0.6], ["ash", 2, 2, 1.0]]},
	"ash_ogre": {"name": "Ash Ogre", "lore": "Covered in ash and sneezes sparks. Bless it from a distance.", "biome": "volcano", "family": "brutes", "armor": 4, "elite": true, "hp": 480, "damage": 36, "speed": 44.0, "radius": 14.0, "attack": "slam",
		"range": 30.0, "blast": 44.0, "xp": 96, "depth": [0.75, 9.0], "weight": 0.35,
		"drops": [["hide", 3, 3, 1.0], ["ember_ore", 1, 2, 1.0], ["raw_meat", 2, 2, 1.0]]},
	"ash_wyvern": {"rig": "quadruped", "name": "Ash Wyvern", "lore": "Nests in the ash, flies on grudges.", "biome": "volcano", "family": "wyrmkin", "hp": 460, "damage": 38, "speed": 74.0, "radius": 15.0,
		"attack": "charge", "armor": 4, "xp": 120, "elite": true, "weight": 0.35, "depth": [0.75, 9.0],
		"drops": [["scale", 4, 6, 1.0], ["fire_gland", 2, 3, 1.0], ["magma_core", 1, 2, 1.0]]},
	"forgeheart_giant": {"name": "Forgeheart Giant", "lore": "It keeps the forge burning. It will not let you put the fire out.", "biome": "volcano", "family": "brutes", "boss": true, "hp": 2500, "damage": 46, "speed": 46.0,
		"radius": 20.0, "attack": "slam", "range": 36.0, "blast": 60.0, "armor": 9, "cooldown": 1.8, "aggro": 220.0, "xp": 700,
		"volley": {"kind": "fire", "speed": 170.0, "count": 10, "spread": 3.14, "every": 4.0},
		"drops": [["key_volcano", 1, 1, 1.0], ["ember_ore", 8, 12, 1.0], ["magma_core", 4, 6, 1.0], ["gold_ore", 5, 5, 1.0]]},
	# ============================================================ hell
	"hellhound": {"name": "Hellhound", "lore": "Breathes brimstone and wags its tail. Both are bad signs.", "biome": "hell", "family": "canines", "hp": 160, "damage": 26, "speed": 96.0, "radius": 10.0, "xp": 40,
		"weight": 2.5, "drops": [["fang", 1, 2, 1.0], ["fire_gland", 1, 1, 0.5]]},
	"quasit": {"name": "Sootling", "lore": "Leaves sooty little handprints on everything you own.", "biome": "hell", "family": "demons", "hp": 110, "damage": 20, "speed": 92.0, "radius": 7.0, "attack": "hit_run",
		"effect": "poison", "xp": 32, "weight": 2.0, "drops": [["venom_sac", 1, 1, 1.0], ["ectoplasm", 1, 1, 0.5]]},
	"hellion": {"name": "Cinder Hurler", "lore": "Throws cinders at people as a hobby. Takes the hobby seriously.", "biome": "hell", "family": "demons", "hp": 220, "damage": 30, "speed": 66.0, "attack": "ranged", "keep": 110.0,
		"range": 200.0, "xp": 60, "projectile": {"kind": "fire", "speed": 200.0, "count": 3, "spread": 0.4},
		"drops": [["demon_horn", 1, 1, 0.5], ["magma_core", 1, 1, 1.0]]},
	"hell_knight": {"name": "Pit Knight", "lore": "Guards the Pit in armour nobody remembers making.", "biome": "hell", "family": "undead", "hp": 420, "damage": 42, "speed": 58.0, "radius": 12.0, "shield": 0.7,
		"armor": 6, "xp": 100, "depth": [0.5, 9.0], "weight": 0.6,
		"drops": [["hellsteel_ore", 1, 3, 1.0], ["cursed_bone", 1, 2, 1.0], ["gold_ore", 1, 1, 0.5]]},
	"flying_skull": {"name": "Flying Skull", "lore": "A skull that flies and explodes. One of these is a bad idea.", "biome": "hell", "family": "spirits", "hp": 90, "damage": 50, "speed": 90.0, "radius": 7.0, "attack": "explode",
		"blast": 46.0, "xp": 30, "drops": [["cursed_bone", 1, 2, 1.0], ["bone", 2, 2, 1.0]]},
	"reaper": {"name": "Reaper", "lore": "Harvests anything that stands still. Do not stand still.", "biome": "hell", "family": "spirits", "weight": 0.3, "elite": true, "phasing": true, "hp": 500, "damage": 48, "speed": 70.0, "radius": 12.0, "attack": "blink",
		"cooldown": 1.5, "aggro": 180.0, "xp": 110, "depth": [0.75, 9.0], "drops": [["soul_shard", 1, 2, 1.0], ["ectoplasm", 1, 2, 1.0], ["shadow_petal", 1, 1, 0.4]]},
	"executioner": {"name": "Great Cleaver", "lore": "Carries a blade bigger than your door, and swings it like one.", "biome": "hell", "family": "demons", "cooldown": 2.0, "blast": 42.0, "range": 30.0, "attack": "slam", "hp": 700, "damage": 54, "speed": 70.0, "radius": 15.0, "armor": 8,
		"xp": 180, "elite": true, "weight": 0.3, "depth": [0.75, 9.0],
		"drops": [["hellsteel_ore", 3, 5, 1.0], ["demon_horn", 2, 3, 1.0], ["soul_shard", 2, 2, 1.0]]},
	"brimstone_fiend": {"name": "Brimstone Hulk", "lore": "Smells of rotten eggs and bad news. Hits like both.", "biome": "hell", "family": "demons", "hp": 800, "damage": 46, "speed": 54.0, "radius": 16.0,
		"attack": "ranged", "keep": 110.0, "range": 200.0, "armor": 6, "xp": 200, "elite": true, "weight": 0.3, "depth": [0.8, 9.0],
		"projectile": {"kind": "fire", "speed": 200.0, "count": 5, "spread": 0.7},
		"drops": [["brimstone", 3, 5, 1.0], ["soul_shard", 2, 3, 1.0], ["hellsteel_ore", 2, 4, 1.0]]},
	"pit_lord": {"name": "The Last Keeper", "lore": "Keeper of the last door. It was told no one may leave. It listened.", "biome": "hell", "family": "demons", "boss": true, "hp": 3800, "damage": 56, "speed": 58.0, "radius": 22.0,
		"attack": "summon", "summon": "flying_skull", "summon_max": 4, "range": 200.0, "keep": 90.0, "armor": 10, "cooldown": 2.0,
		"aggro": 230.0, "xp": 1200, "projectile": {"kind": "fire", "speed": 210.0, "count": 5, "spread": 0.6},
		"volley": {"kind": "fire", "speed": 150.0, "count": 16, "spread": 3.14, "every": 4.0},
		"drops": [["key_hell", 1, 1, 1.0], ["soul_shard", 6, 10, 1.0], ["hellsteel_ore", 6, 10, 1.0], ["demon_horn", 4, 4, 1.0]]},
}

static var _cache := {}


static func has(id: String) -> bool:
	return TYPES.has(id)


## Full definition of a creature (DEFAULTS merged with its entry).
static func def(id: String) -> Dictionary:
	if not _cache.has(id):
		var d: Dictionary = DEFAULTS.duplicate(true)
		d.merge(TYPES[id], true)
		var drops := []
		for e in d.drops:
			if e is Array:
				drops.append({"id": e[0], "min": e[1], "max": e[2], "chance": e[3]})
			else:
				drops.append(e)
		d.drops = drops
		_cache[id] = d
	return _cache[id]


## Sprite size in pixels (longest side) next to the ~42px hero: critters are
## small, beasts and bosses tower over the player. The art generator fits
## every creature into a square cell of CreatureSheet.cell_for(size).
const SIZES := {
	"hare": 21, "woolback": 33, "tusk_boar": 36, "bramble_bear": 54, "bumbler": 21,
	"dusk_jackal": 33, "leaping_spider": 24, "puffcap": 27, "goblin_archer": 30, "goblin_guard": 33,
	"grub": 24, "dart_bat": 24, "kobold_slinger": 27, "stalker": 39, "she_wolf": 36, "maze_spider": 30,
	"bone_guard": 42, "spark_wisp": 21, "wraith": 42, "broodmother": 63, "minotaur": 66,
	"stone_colossus": 90,
	"gloss_moth": 21, "moss_bear": 57, "shade_mamba": 36, "hive_stinger": 18, "hive_queen": 48,
	"wander_cap": 30, "deathcap": 30, "werewolf": 66, "briar_hydra": 90,
	"dune_yak": 51, "dune_scorpion": 36, "emperor_scorpion": 66, "sandworm": 54, "dune_hound": 33,
	"orc_javelineer": 48, "mummy": 45, "tomb_king": 54, "sun_wyrm": 96,
	"snow_sheep": 33, "mammoth_yak": 66, "frost_wolf": 39, "rime_alpha": 63, "snow_bear": 60,
	"frost_troll": 60, "frost_gnome": 30, "frost_giant": 78, "hoarfrost_dragon": 96,
	"cinder_bat": 27, "magma_crab": 42, "salamander": 45, "crimson_imp": 24, "ember_mystic": 33,
	"fire_elemental": 45, "ash_ogre": 72, "ash_wyvern": 72, "forgeheart_giant": 96,
	"hellhound": 45, "quasit": 24, "hellion": 42, "hell_knight": 54, "flying_skull": 24,
	"reaper": 60, "executioner": 72, "brimstone_fiend": 75, "pit_lord": 96,
}


static func size_of(id: String) -> int:
	return SIZES.get(id, 30)


## Current id of a creature, following LEGACY for species cut from the bestiary.
static func resolve(id: String) -> String:
	return LEGACY.get(id, id)


## Body plan of a creature: its own "rig" or its family's.
static func rig_of(id: String) -> String:
	var d := def(id)
	if d.rig != "":
		return d.rig
	return FAMILIES.get(d.family, {}).get("rig", "quadruped")


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
		if d.boss or depth < d.depth[0] or depth > d.depth[1]:
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
