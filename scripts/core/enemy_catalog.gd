class_name EnemyCatalog
extends RefCounted
## Data table of labyrinth creatures (no nodes). Original designs: grubs,
## stalkers and wardens of the Stone biome.

const TYPES := {
	"grub": {
		"name": "Moss Grub", "hp": 18, "damage": 6, "speed": 46.0, "aggro": 110.0,
		"attack_range": 18.0, "cooldown": 1.1, "xp": 6,
		"drop": "berry", "drop_min": 0, "drop_max": 2, "radius": 7.0,
	},
	"stalker": {
		"name": "Stalker", "hp": 34, "damage": 10, "speed": 92.0, "aggro": 150.0,
		"attack_range": 20.0, "cooldown": 0.9, "xp": 12,
		"drop": "stone", "drop_min": 1, "drop_max": 3, "radius": 8.0,
	},
	"warden": {
		"name": "Stone Warden", "hp": 90, "damage": 18, "speed": 40.0, "aggro": 130.0,
		"attack_range": 26.0, "cooldown": 1.6, "xp": 35,
		"drop": "plank", "drop_min": 3, "drop_max": 6, "radius": 11.0,
	},
}


static func has(id: String) -> bool:
	return TYPES.has(id)


static func def(id: String) -> Dictionary:
	return TYPES[id]


## Species chosen for a maze cell by its distance from the entrance (0..1):
## the deeper the sector, the more dangerous the guardians.
static func type_for_depth(depth: float, roll: float) -> String:
	if depth > 0.7 and roll < 0.45:
		return "warden"
	if depth > 0.35 and roll < 0.6:
		return "stalker"
	return "grub"
