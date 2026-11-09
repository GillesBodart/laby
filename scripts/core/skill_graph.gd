class_name SkillGraph
extends RefCounted
## Radial passive skill graph (pure data). A hub of root nodes surrounds the
## centre; each specialization cluster radiates outward along its own angle.
## Adding a cluster or a node is a data change only.
##
## CLUSTERS: id -> {name, color, angle (degrees, 0 = right, 90 = down)}
## NODES: id -> {
##   name, cluster,
##   at       [radius, offset]: polar placement along the cluster's angle
##            (offset is perpendicular, in node units),
##   max      ranks (default 1), cost per rank (default 1),
##   kind     "small" | "notable" | "keystone",
##   requires any-of prerequisites (empty = hub root, always reachable),
##   fx       stat -> bonus per rank (see FX_TEXT),
##   gate     sector that must have been reached ("" = none)}

const CLUSTERS := {
	"core": {"name": "Survivor's Core", "color": Color8(236, 222, 186), "angle": 0.0},
	"warrior": {"name": "Warrior", "color": Color8(214, 86, 72), "angle": 0.0},
	"ranger": {"name": "Ranger", "color": Color8(118, 184, 86), "angle": 60.0},
	"survivor": {"name": "Survivor", "color": Color8(226, 172, 76), "angle": 120.0},
	"scholar": {"name": "Scholar", "color": Color8(108, 160, 226), "angle": 180.0},
	"beastmaster": {"name": "Beastmaster", "color": Color8(196, 122, 206), "angle": 240.0},
	"builder": {"name": "Builder", "color": Color8(176, 132, 88), "angle": 300.0},
}

## Bonus wording; "%s" is replaced by the signed amount.
const FX_TEXT := {
	"hp": "%s max health", "dmg": "%s attack damage", "ranged": "%s ranged damage",
	"armor": "%s armor", "block": "%s%% block chance", "crit": "%s%% critical hits",
	"speed": "%s%% move speed", "run_cost": "%s%% less run/roll stamina", "strength": "%s Strength",
	"hunger": "%s%% slower hunger", "thirst": "%s%% slower thirst", "regen": "%s%% faster healing",
	"warm": "%s cold protection", "cool": "%s heat protection", "gather": "%s%% double harvest",
	"xp": "%s%% experience", "tame": "%s taming tier", "companions": "%s companion",
	"lore": "%s glyph insight", "struct_hp": "%s%% structure toughness",
}

## Hub roots point toward their cluster (same angle).
const NODES := {
	# --- hub
	"might": {"name": "Might", "cluster": "core", "at": [1.6, 0.0], "max": 3, "fx": {"dmg": 3}},
	"fleet": {"name": "Fleet Foot", "cluster": "core", "at": [1.6, 0.0], "angle": 60.0, "max": 3, "fx": {"speed": 8}},
	"vigor": {"name": "Vigor", "cluster": "core", "at": [1.6, 0.0], "angle": 120.0, "max": 3, "fx": {"hp": 15}},
	"curious": {"name": "Curious Mind", "cluster": "core", "at": [1.6, 0.0], "angle": 180.0, "max": 3, "fx": {"xp": 8}},
	"stamina": {"name": "Endurance", "cluster": "core", "at": [1.6, 0.0], "angle": 240.0, "max": 3, "fx": {"run_cost": 20}},
	"brawn": {"name": "Brawn", "cluster": "core", "at": [1.6, 0.0], "angle": 300.0, "max": 3, "fx": {"strength": 5}},
	# --- warrior
	"w_edge": {"name": "Keen Edge", "cluster": "warrior", "at": [3.0, 0.0], "max": 3, "requires": ["might"], "fx": {"dmg": 2}},
	"w_guard": {"name": "Guard Stance", "cluster": "warrior", "at": [4.0, -1.0], "max": 3, "requires": ["w_edge"], "fx": {"block": 5}},
	"w_hide": {"name": "Thick Hide", "cluster": "warrior", "at": [4.0, 1.0], "max": 3, "requires": ["w_edge"], "fx": {"armor": 1}},
	"w_crit": {"name": "Brutal Strikes", "cluster": "warrior", "at": [5.0, 0.0], "kind": "notable", "requires": ["w_guard", "w_hide"], "fx": {"crit": 15}},
	"w_iron": {"name": "Iron Body", "cluster": "warrior", "at": [6.0, -1.0], "max": 2, "requires": ["w_crit"], "fx": {"hp": 20, "armor": 1}},
	"w_berserk": {"name": "Berserker", "cluster": "warrior", "at": [7.0, 0.0], "kind": "keystone", "requires": ["w_iron"], "gate": "overgrowth", "fx": {"dmg": 10, "crit": 10, "armor": -3}},
	# --- ranger
	"r_aim": {"name": "Steady Aim", "cluster": "ranger", "at": [3.0, 0.0], "max": 3, "requires": ["fleet"], "fx": {"ranged": 2}},
	"r_light": {"name": "Light Step", "cluster": "ranger", "at": [4.0, -1.0], "max": 2, "requires": ["r_aim"], "fx": {"speed": 5}},
	"r_lungs": {"name": "Deep Lungs", "cluster": "ranger", "at": [4.0, 1.0], "max": 2, "requires": ["r_aim"], "fx": {"run_cost": 10}},
	"r_hunter": {"name": "Hunter's Mark", "cluster": "ranger", "at": [5.0, 0.0], "kind": "notable", "requires": ["r_light", "r_lungs"], "fx": {"ranged": 4, "crit": 5}},
	"r_scav": {"name": "Scavenger", "cluster": "ranger", "at": [6.0, 1.0], "max": 2, "requires": ["r_hunter"], "fx": {"gather": 8, "xp": 5}},
	"r_deadeye": {"name": "Deadeye", "cluster": "ranger", "at": [7.0, 0.0], "kind": "keystone", "requires": ["r_scav"], "gate": "desert", "fx": {"ranged": 10, "hp": -20}},
	# --- survivor
	"s_forage": {"name": "Forager", "cluster": "survivor", "at": [3.0, 0.0], "max": 3, "requires": ["vigor"], "fx": {"hunger": 10}},
	"s_camel": {"name": "Camel", "cluster": "survivor", "at": [4.0, -1.0], "max": 3, "requires": ["s_forage"], "fx": {"thirst": 12}},
	"s_mend": {"name": "Quick Mending", "cluster": "survivor", "at": [4.0, 1.0], "max": 3, "requires": ["s_forage"], "fx": {"regen": 25}},
	"s_weather": {"name": "Weathered", "cluster": "survivor", "at": [5.0, 0.0], "kind": "notable", "requires": ["s_camel", "s_mend"], "fx": {"warm": 1, "cool": 1}},
	"s_tough": {"name": "Tough as Roots", "cluster": "survivor", "at": [6.0, 0.0], "max": 2, "requires": ["s_weather"], "fx": {"hp": 15, "regen": 15}},
	"s_iron_gut": {"name": "Iron Stomach", "cluster": "survivor", "at": [7.0, 0.0], "kind": "keystone", "requires": ["s_tough"], "gate": "ice", "fx": {"hunger": 40, "thirst": 40, "speed": -6}},
	# --- scholar
	"k_notes": {"name": "Field Notes", "cluster": "scholar", "at": [3.0, 0.0], "max": 3, "requires": ["curious"], "fx": {"xp": 6}},
	"k_glyph": {"name": "Glyph Reader", "cluster": "scholar", "at": [4.0, -1.0], "requires": ["k_notes"], "fx": {"lore": 1}},
	"k_herbs": {"name": "Herb Lore", "cluster": "scholar", "at": [4.0, 1.0], "max": 2, "requires": ["k_notes"], "fx": {"regen": 20, "gather": 5}},
	"k_insight": {"name": "Insight", "cluster": "scholar", "at": [5.0, 0.0], "kind": "notable", "requires": ["k_glyph", "k_herbs"], "fx": {"xp": 15, "lore": 1}},
	"k_mind": {"name": "Ordered Mind", "cluster": "scholar", "at": [6.0, 0.0], "max": 2, "requires": ["k_insight"], "fx": {"hp": 10, "run_cost": 5}},
	"k_glyphwalker": {"name": "Glyphwalker", "cluster": "scholar", "at": [7.0, 0.0], "kind": "keystone", "requires": ["k_mind"], "gate": "overgrowth", "fx": {"lore": 2, "xp": 20, "dmg": -3}},
	# --- beastmaster
	"b_calm": {"name": "Calming Voice", "cluster": "beastmaster", "at": [3.0, 0.0], "requires": ["stamina"], "fx": {"tame": 1}},
	"b_bond": {"name": "Bond", "cluster": "beastmaster", "at": [4.0, -1.0], "max": 2, "requires": ["b_calm"], "fx": {"hp": 10}},
	"b_track": {"name": "Tracker", "cluster": "beastmaster", "at": [4.0, 1.0], "max": 2, "requires": ["b_calm"], "fx": {"speed": 4, "gather": 4}},
	"b_tamer": {"name": "Beast Tamer", "cluster": "beastmaster", "at": [5.0, 0.0], "kind": "notable", "requires": ["b_bond", "b_track"], "fx": {"tame": 1, "companions": 1}},
	"b_wild": {"name": "Wild Heart", "cluster": "beastmaster", "at": [6.0, 0.0], "max": 2, "requires": ["b_tamer"], "fx": {"dmg": 2, "regen": 10}},
	"b_packlead": {"name": "Pack Leader", "cluster": "beastmaster", "at": [7.0, 0.0], "kind": "keystone", "requires": ["b_wild"], "gate": "desert", "fx": {"tame": 1, "companions": 1, "hp": -15}},
	# --- builder
	"u_haul": {"name": "Hauler", "cluster": "builder", "at": [3.0, 0.0], "max": 3, "requires": ["brawn"], "fx": {"gather": 6}},
	"u_mason": {"name": "Mason", "cluster": "builder", "at": [4.0, -1.0], "max": 3, "requires": ["u_haul"], "fx": {"struct_hp": 15}},
	"u_back": {"name": "Strong Back", "cluster": "builder", "at": [4.0, 1.0], "max": 2, "requires": ["u_haul"], "fx": {"strength": 5}},
	"u_engineer": {"name": "Engineer", "cluster": "builder", "at": [5.0, 0.0], "kind": "notable", "requires": ["u_mason", "u_back"], "fx": {"struct_hp": 25, "gather": 8}},
	"u_tools": {"name": "Toolwise", "cluster": "builder", "at": [6.0, 0.0], "max": 2, "requires": ["u_engineer"], "fx": {"gather": 6, "dmg": 1}},
	"u_master": {"name": "Master Builder", "cluster": "builder", "at": [7.0, 0.0], "kind": "keystone", "requires": ["u_tools"], "gate": "ice", "fx": {"struct_hp": 60, "strength": 10, "speed": -6}},
	# --- bridges between neighbouring clusters (hybrid builds)
	"x_skirmish": {"name": "Skirmisher", "cluster": "warrior", "at": [5.6, 0.0], "angle": 30.0, "kind": "notable", "requires": ["w_hide", "r_light"], "fx": {"dmg": 2, "ranged": 2, "speed": 3}},
	"x_hardy": {"name": "Hardy Hunter", "cluster": "survivor", "at": [5.6, 0.0], "angle": 90.0, "kind": "notable", "requires": ["r_lungs", "s_camel"], "fx": {"hp": 10, "hunger": 10}},
	"x_apothecary": {"name": "Apothecary", "cluster": "scholar", "at": [5.6, 0.0], "angle": 150.0, "kind": "notable", "requires": ["s_mend", "k_glyph"], "fx": {"regen": 30, "xp": 5}},
	"x_whisper": {"name": "Beast Whisperer", "cluster": "beastmaster", "at": [5.6, 0.0], "angle": 210.0, "kind": "notable", "requires": ["k_herbs", "b_bond"], "fx": {"tame": 1, "lore": 1}},
	"x_stables": {"name": "Stablemaster", "cluster": "builder", "at": [5.6, 0.0], "angle": 270.0, "kind": "notable", "requires": ["b_track", "u_mason"], "fx": {"companions": 1, "struct_hp": 10}},
	"x_siege": {"name": "Siegebreaker", "cluster": "warrior", "at": [5.6, 0.0], "angle": 330.0, "kind": "notable", "requires": ["u_back", "w_guard"], "fx": {"dmg": 3, "strength": 3}},
}


static func has(id: String) -> bool:
	return NODES.has(id)


static func node(id: String) -> Dictionary:
	return NODES[id]


static func max_rank(id: String) -> int:
	return int(NODES[id].get("max", 1))


static func cost(id: String) -> int:
	return int(NODES[id].get("cost", 1))


static func kind(id: String) -> String:
	return NODES[id].get("kind", "small")


static func requires(id: String) -> Array:
	return NODES[id].get("requires", [])


static func gate(id: String) -> String:
	return NODES[id].get("gate", "")


static func cluster_color(id: String) -> Color:
	return CLUSTERS[NODES[id].cluster].color


## Position in graph units (hub at the origin).
static func position(id: String) -> Vector2:
	var n: Dictionary = NODES[id]
	var deg: float = n.get("angle", CLUSTERS[n.cluster].angle)
	var dir := Vector2.from_angle(deg_to_rad(deg))
	return dir * float(n.at[0]) + dir.orthogonal() * float(n.at[1])


## Undirected edges [a, b] drawn between prerequisites and their nodes.
static func edges() -> Array:
	var out := []
	for id in NODES:
		for r in requires(id):
			out.append([r, id])
	return out


## A node is reachable when it is a root or any prerequisite has a rank.
static func reachable(id: String, ranks: Dictionary) -> bool:
	var req := requires(id)
	return req.is_empty() or req.any(func(r): return int(ranks.get(r, 0)) > 0)


static func gate_open(id: String, reached: Dictionary) -> bool:
	return gate(id) == "" or reached.has(gate(id))


## Summed bonuses of every allocated rank.
static func totals(ranks: Dictionary) -> Dictionary:
	var out := {}
	for id in ranks:
		if not NODES.has(id):
			continue
		var fx: Dictionary = NODES[id].get("fx", {})
		for stat in fx:
			out[stat] = out.get(stat, 0) + fx[stat] * int(ranks[id])
	return out


## "+3 attack damage, -3 armor" (per rank).
static func describe(id: String) -> String:
	var parts := PackedStringArray()
	var fx: Dictionary = NODES[id].get("fx", {})
	for stat in fx:
		var v: int = fx[stat]
		parts.append(FX_TEXT.get(stat, stat + " %s") % (("+%d" if v >= 0 else "%d") % v))
	return ", ".join(parts)


## Problems with the data (unknown prerequisites, unknown stats, nodes not
## reachable from the hub). Empty when the graph is valid.
static func validate() -> Array:
	var errors := []
	var seen := {}
	var frontier := []
	for id in NODES:
		if not CLUSTERS.has(NODES[id].cluster):
			errors.append("%s: unknown cluster" % id)
		for r in requires(id):
			if not NODES.has(r):
				errors.append("%s requires unknown %s" % [id, r])
		for stat in NODES[id].get("fx", {}):
			if not FX_TEXT.has(stat):
				errors.append("%s: unknown stat %s" % [id, stat])
		if requires(id).is_empty():
			frontier.append(id)
	while not frontier.is_empty():
		var id: String = frontier.pop_back()
		if seen.has(id):
			continue
		seen[id] = true
		for other in NODES:
			if not seen.has(other) and id in requires(other):
				frontier.append(other)
	for id in NODES:
		if not seen.has(id):
			errors.append("%s unreachable from the hub" % id)
	return errors
