class_name Rooms
extends RefCounted
## Rooms in the Clearing: areas fully closed by walls and doors. What stands
## inside a room grants comfort buffs to whoever is in it (Survival.room_buffs).
## Pure data over GameState.structures (cell -> {"type", optional "floor"}).

## Bigger enclosures are yards, not rooms.
const MAX_CELLS := 64
## Each buff: what the room needs (any one of `needs`, or every tile floored),
## and the Survival.bonus stats it adds.
const BUFFS := [
	{"id": "rested", "name": "Rested", "needs": ["bed"], "stats": {"regen": 50}, "desc": "+50% health regen"},
	{"id": "nourished", "name": "Nourished", "needs": ["cooking_pot"], "stats": {"hunger": 25}, "desc": "hunger drains 25% slower"},
	{"id": "handy", "name": "Handy", "needs": ["workbench", "furnace", "anvil", "tanning_rack", "stonecutter", "loom", "alchemy_table"], "stats": {"dmg": 2}, "desc": "+2 damage"},
	{"id": "organised", "name": "Organised", "needs": ["chest"], "stats": {"strength": 5}, "desc": "+5 strength"},
	{"id": "cosy", "name": "Cosy", "needs": ["standing_torch"], "stats": {"hp": 15}, "desc": "+15 max health"},
	{"id": "comfortable", "name": "Comfortable", "needs": [], "floored": true, "stats": {"run_cost": 15}, "desc": "running costs 15% less stamina"},
]


static func encloses(type: String) -> bool:
	return BuildCatalog.is_wall(type) or type == "wooden_door"


static func _type_at(structures: Dictionary, cell: Vector2i) -> String:
	return String(structures.get(cell, {}).get("type", ""))


static func _floored(structures: Dictionary, cell: Vector2i) -> bool:
	var d: Dictionary = structures.get(cell, {})
	return String(d.get("type", "")) in BuildCatalog.SURFACES or String(d.get("floor", "")) in BuildCatalog.SURFACES


## The room around `cell`: {"cells": Array of Vector2i, "contents": {type: n},
## "floored": bool}, or {} when the cell is in the open (or is a wall).
static func find(structures: Dictionary, cell: Vector2i) -> Dictionary:
	if encloses(_type_at(structures, cell)):
		return {}
	var seen := {cell: true}
	var todo: Array[Vector2i] = [cell]
	var i := 0
	while i < todo.size():
		var c := todo[i]
		i += 1
		for n in [c + Vector2i.LEFT, c + Vector2i.RIGHT, c + Vector2i.UP, c + Vector2i.DOWN]:
			if seen.has(n) or encloses(_type_at(structures, n)):
				continue
			seen[n] = true
			todo.append(n)
			if todo.size() > MAX_CELLS:
				return {}
	var contents := {}
	var floored := true
	for c in todo:
		var t := _type_at(structures, c)
		if t != "" and BuildCatalog.TYPES.get(t, {}).get("layer", "") == "entity":
			contents[t] = int(contents.get(t, 0)) + 1
		floored = floored and _floored(structures, c)
	return {"cells": todo, "contents": contents, "floored": floored}


## Same value for a room whichever of its tiles it was found from.
static func key(room: Dictionary):
	return null if room.is_empty() else room.cells.min()


## Names of the buffs whose stats are all in `stats` (Survival.room_buffs).
static func names_for(stats: Dictionary) -> Array:
	var out := []
	for b in BUFFS:
		var all := true
		for k in b.stats:
			all = all and int(stats.get(k, 0)) >= int(b.stats[k])
		if all:
			out.append(b.name)
	return out


## Buffs (entries of BUFFS) a room grants.
static func buffs_of(room: Dictionary) -> Array:
	var out := []
	if room.is_empty():
		return out
	for b in BUFFS:
		var ok: bool = room.floored if b.get("floored", false) else false
		for t in b.needs:
			ok = ok or room.contents.has(t)
		if ok:
			out.append(b)
	return out


## Summed stats of a room's buffs (for Survival.add_room_buffs).
static func stats_of(room: Dictionary) -> Dictionary:
	var stats := {}
	for b in buffs_of(room):
		for k in b.stats:
			stats[k] = int(stats.get(k, 0)) + int(b.stats[k])
	return stats


## "Rested (+50% health regen), Cosy (+15 max health)" or a hint when bare.
static func describe(room: Dictionary) -> String:
	var parts := []
	for b in buffs_of(room):
		parts.append("%s (%s)" % [b.name, b.desc])
	if parts.is_empty():
		return "a bare room: a bed, cooking pot, station, chest, torch or floor would make it comfier"
	return ", ".join(parts)
