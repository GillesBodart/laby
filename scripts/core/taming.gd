class_name Taming
extends RefCounted
## Taming rules (pure data). A creature can be tamed by feeding it its
## favourite food once it is weakened (passive creatures need no beating).
## Tier grows with toughness; the Beastmaster cluster raises the tier a
## survivor may tame ("tame" bonus) and the party cap ("companions").
## Guardians can never be tamed.

const WEAK_HP := 0.5
## Plant eaters of each biome and what they crave.
const PLANT_FOOD := {
	"forest": "berry", "labyrinth": "mushroom", "overgrowth": "glowcap", "desert": "dates",
	"ice": "snowberry", "volcano": "cooked_meat", "hell": "cooked_meat",
}
## Per-species overrides.
const FAVOURITE := {
	"bramble_bear": "honey", "moss_bear": "honey", "bumbler": "honey", "hive_stinger": "honey",
	"woolback": "carrot", "hare": "carrot", "snow_sheep": "snowberry", "tusk_boar": "potato",
	"wild_hog": "potato", "cave_rat": "mushroom", "shell_crawler": "mushroom",
}
const ELITE_FOOD := "royal_jelly"


## 1 (critters) .. 5 (elites of the deep); -1 = untameable.
static func tier(id: String) -> int:
	var d := EnemyCatalog.def(id)
	if d.boss:
		return -1
	var hp: int = d.hp
	var t := 1 if hp <= 30 else (2 if hp <= 70 else (3 if hp <= 140 else 4))
	return t + (1 if d.elite else 0)


## Highest tier a survivor can tame: the weakest tier without Beastmaster nodes.
static func max_tier(s: Survival) -> int:
	return 1 + s.bonus("tame")


static func party_cap(s: Survival) -> int:
	return 1 + s.bonus("companions")


static func favourite(id: String) -> String:
	var d := EnemyCatalog.def(id)
	if d.elite:
		return ELITE_FOOD
	if FAVOURITE.has(id):
		return FAVOURITE[id]
	if d.damage == 0 or d.temper == "passive":
		return PLANT_FOOD.get(d.biome, "berry")
	return "raw_meat"


## Weakened enough to accept food?
static func receptive(id: String, hp: int, max_hp: int) -> bool:
	return EnemyCatalog.def(id).temper == "passive" or hp <= int(max_hp * WEAK_HP)


## Companion combat stats derived from the creature (passive ones still nip).
static func companion_damage(id: String) -> int:
	return maxi(int(EnemyCatalog.def(id).damage), 3)


## Why taming fails right now ("" = it would succeed).
static func refusal(id: String, hp: int, max_hp: int, s: Survival, has_food: bool, party: int) -> String:
	var name: String = EnemyCatalog.def(id).name
	var t := tier(id)
	if t < 0:
		return "The %s cannot be tamed." % name
	if t > max_tier(s):
		return "The %s is too wild for you (tier %d, Beastmaster skills raise your limit)." % [name, t]
	if not receptive(id, hp, max_hp):
		return "Weaken the %s first." % name
	if not has_food:
		return "The %s craves %s." % [name, ItemCatalog.item_name(favourite(id))]
	if party >= party_cap(s):
		return "Your party is full (%d)." % party_cap(s)
	return ""
