class_name Settlement
extends RefCounted
## The Clearing as a growing community (pure data). Its tier comes from what
## has been built (GameState.structures); each tier welcomes more survivors.
## Survivors (a fixed, quirky cast) hold a role and work at every dawn: the
## settlement eats from the Stash, then each fed survivor produces into it.

const TIERS := ["Camp", "Shelters", "Village", "Fortified Base", "Community"]
## Survivors a tier can house.
const CAP := [1, 3, 5, 7, 8]
## What a tier needs (structure groups -> count; "bosses" = guardians slain).
const NEEDS := [
	{},
	{"bed": 2, "workbench": 1},
	{"bed": 4, "farm_plot": 4, "station": 3, "well": 1},
	{"bed": 6, "wall": 30, "wooden_door": 1, "standing_torch": 4},
	{"bed": 8, "stone_wall": 30, "farm_plot": 8, "station": 6, "bosses": 1},
]
const NEED_NAMES := {
	"bed": "Beds", "workbench": "Workbench", "farm_plot": "Farm plots", "station": "Crafting stations",
	"well": "Well", "wall": "Walls", "stone_wall": "Stone / brick walls", "wooden_door": "Door",
	"standing_torch": "Standing torches", "bosses": "Guardians slain",
}
const STATIONS := ["workbench", "furnace", "anvil", "cooking_pot", "tanning_rack", "stonecutter", "loom", "alchemy_table"]

const ROLES := ["gatherer", "farmer", "builder", "cook", "guard", "cartographer", "healer"]
const ROLE_TEXT := {
	"gatherer": "Brings wood, stone and fiber.",
	"farmer": "Grows wheat and carrots (more with farm plots).",
	"builder": "Saws planks, cuts stone, mends damaged structures.",
	"cook": "Cooks raw meat in the Stash; the camp eats less.",
	"guard": "Defends the Clearing when the maze sends raiders.",
	"cartographer": "Charts a patch of a sector you have visited.",
	"healer": "Brews healing potions from herbs, or picks herbs.",
}

## The cast, in arrival order. sprite = assets/sprites/npcs/<sprite>.png
const CAST := [
	{"name": "Bram", "sprite": "npc_human", "role": "gatherer",
		"line": "I counted the walls yesterday. Today there is one more. Nobody believes me."},
	{"name": "Nettle", "sprite": "npc_elf", "role": "farmer",
		"line": "The carrots listen if you speak slowly. The wheat just gossips."},
	{"name": "Old Tuck", "sprite": "npc_dwarf", "role": "builder",
		"line": "Whoever built those walls never heard of mortar. Or mercy."},
	{"name": "Pip", "sprite": "npc_halfling", "role": "cook",
		"line": "Everything tastes better with optimism. And salt. Mostly salt."},
	{"name": "Wren", "sprite": "npc_tengu", "role": "cartographer",
		"line": "I draw maps of places that do not exist yet. Then the walls move and, well."},
	{"name": "Hollis", "sprite": "npc_deep_dwarf", "role": "guard",
		"line": "I sleep standing up. Snore in rhythm, too. Very intimidating."},
	{"name": "Fennick", "sprite": "npc_faun", "role": "gatherer",
		"line": "I'm allergic to moss. I live in a moss maze. Life is a joke I didn't get."},
	{"name": "Marisol", "sprite": "npc_merfolk", "role": "healer",
		"line": "Has anyone seen the sea? It was right here. I'm almost sure."},
]


## How many built structures fall under a need key.
static func count(structures: Dictionary, key: String) -> int:
	var n := 0
	for cell in structures:
		var t: String = structures[cell].type
		match key:
			"station":
				n += int(t in STATIONS)
			"wall":
				n += int(t in ["wooden_wall", "stone_wall", "brick_wall"])
			"stone_wall":
				n += int(t in ["stone_wall", "brick_wall"])
			_:
				n += int(t == key)
	return n


static func _have(key: String, structures: Dictionary, bosses: int) -> int:
	return bosses if key == "bosses" else count(structures, key)


## Current tier: the highest one whose needs (and all lower ones) are met.
static func tier(structures: Dictionary, bosses := 0) -> int:
	var t := 0
	for i in range(1, TIERS.size()):
		if missing(i, structures, bosses).is_empty():
			t = i
		else:
			break
	return t


## [{key, label, have, need}] still short for a tier.
static func missing(tier_index: int, structures: Dictionary, bosses := 0) -> Array:
	var out := []
	for key in NEEDS[tier_index]:
		var have := _have(key, structures, bosses)
		if have < NEEDS[tier_index][key]:
			out.append({"key": key, "label": NEED_NAMES[key], "have": have, "need": NEEDS[tier_index][key]})
	return out


static func cap(tier_index: int) -> int:
	return CAP[clampi(tier_index, 0, CAP.size() - 1)]


static func is_food(id: String) -> bool:
	return ItemCatalog.food_of(id) > 0.0


## Food the settlement eats each dawn (cooks stretch the pot).
static func food_needed(survivors: Array) -> int:
	var cooks := survivors.filter(func(s): return s.role == "cook").size()
	return maxi(survivors.size() - cooks, 0) if not survivors.is_empty() else 0


## Settlement needs: fed (enough food in the stash), water (a well once
## three or more live here), shelter (a bed each beyond the first), defence.
static func needs(survivors: Array, structures: Dictionary, stash: Inventory) -> Dictionary:
	var food := 0
	for s in stash.slots:
		if not s.is_empty() and is_food(s.id):
			food += int(s.count)
	return {
		"food": food >= food_needed(survivors),
		"water": survivors.size() < 3 or count(structures, "well") > 0,
		"shelter": count(structures, "bed") >= survivors.size() - 1,
		"defence": defence(survivors, structures),
	}


## Defence rating used against raids: guards, walls and torches.
static func defence(survivors: Array, structures: Dictionary) -> int:
	var guards := survivors.filter(func(s): return s.role == "guard").size()
	return guards * 6 + floori(count(structures, "wall") / 5.0) + count(structures, "standing_torch")


## Items a survivor brings in at dawn (before stash conversions).
static func produce(role: String, structures: Dictionary) -> Dictionary:
	match role:
		"gatherer":
			return {"wood": 3, "stone": 2, "fiber": 2}
		"farmer":
			var plots := count(structures, "farm_plot")
			return {"wheat": 2 + mini(plots >> 2, 3), "carrot": 1 + int(plots >= 8)}
		"builder":
			return {"plank": 2, "stone": 2}
	return {}


## Eats the settlement's food from the stash (cooked food first); returns
## how many were eaten.
static func eat(survivors: Array, stash: Inventory) -> int:
	var need := food_needed(survivors)
	var eaten := 0
	var order := []
	for s in stash.slots:
		if not s.is_empty() and is_food(s.id) and not order.has(s.id):
			order.append(s.id)
	order.sort_custom(func(a, b): return ItemCatalog.food_of(a) > ItemCatalog.food_of(b))
	for id in order:
		while eaten < need and stash.count(id) > 0:
			stash.remove(id, 1)
			eaten += 1
	return eaten


## A full dawn for the given state. Returns {gained: {item: n}, report: [String],
## chart: int (cartographers at work), arrival: int (cast index or -1)}.
static func dawn(survivors: Array, structures: Dictionary, stash: Inventory, bosses := 0) -> Dictionary:
	var out := {"gained": {}, "report": [], "chart": 0, "arrival": -1}
	if survivors.is_empty():
		return out
	var n := needs(survivors, structures, stash)
	var fed: bool = n.food
	eat(survivors, stash)
	if not fed:
		out.report.append("The camp went hungry: only half the work got done.")
	if not n.water:
		out.report.append("No well: the survivors waste the morning fetching water.")
	var work := 1.0 if fed and n.water else 0.5
	for s in survivors:
		for id in produce(s.role, structures):
			var amount := maxi(int(produce(s.role, structures)[id] * work), 1)
			out.gained[id] = int(out.gained.get(id, 0)) + amount
		match s.role:
			"cook":
				var meat := mini(stash.count("raw_meat"), 4)
				if meat > 0:
					stash.remove("raw_meat", meat)
					out.gained["cooked_meat"] = int(out.gained.get("cooked_meat", 0)) + meat
			"healer":
				if stash.count("herb") >= 2:
					stash.remove("herb", 2)
					out.gained["healing_potion"] = int(out.gained.get("healing_potion", 0)) + 1
				else:
					out.gained["herb"] = int(out.gained.get("herb", 0)) + 2
			"cartographer":
				out.chart += 1
	for id in out.gained:
		stash.add(id, out.gained[id])
	var t := tier(structures, bosses)
	if fed and survivors.size() < cap(t) and count(structures, "bed") >= survivors.size() and survivors.size() < CAST.size():
		out.arrival = next_arrival(survivors)
	return out


## First cast member not living here yet.
static func next_arrival(survivors: Array) -> int:
	var present := survivors.map(func(s): return int(s.cast))
	for i in CAST.size():
		if not present.has(i):
			return i
	return -1


static func next_role(role: String) -> String:
	return ROLES[(ROLES.find(role) + 1) % ROLES.size()]


## Tonight's raid on the Clearing: how many raiders come. None while the camp
## is a lone fire (tier 0) or before the second night; then every other
## night, more as the settlement grows and fewer the better it is defended.
static func raid_size(tier_index: int, night: int, defence_rating: int) -> int:
	if tier_index <= 0 or night < 2 or night % 2 == 1:
		return 0
	return clampi(1 + tier_index * 2 + floori(night / 5.0) - floori(defence_rating / 8.0), 0, 12)


## How deep in the maze raiders come from (stronger kinds for bigger camps).
static func raid_depth(tier_index: int) -> float:
	return 0.2 + 0.25 * tier_index


## Damage a raid deals to the camp while nobody is there to fight it off.
static func unattended_damage(raiders: int, defence_rating: int) -> int:
	return maxi(raiders * 30 - defence_rating * 4, 0)


## Structure hit points builders mend each dawn.
const BUILDER_REPAIR := 120