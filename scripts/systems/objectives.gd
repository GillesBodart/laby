class_name Objectives
extends RefCounted
## The goal chain shown in the HUD's "Goal" box: what to do next, from the
## first logs to the way out. It teaches the core loop one step at a time
## (gather -> craft -> build -> shelter -> explore -> decode -> slay ->
## escape) instead of a wall of tutorial text.
##
## Pure data: `check(ctx)` reads a snapshot built by `context()`, so the rules
## are testable without a scene. A goal, once met, stays done (GameState.goals)
## even if its items are spent later.
##
## ctx keys: items {id: n} (backpack, worn gear and Stash), structures
## {type: n}, rooms_with_bed int, reached {area: true}, bosses {type: true},
## glyphs int, companions int, survivors int, escaped bool.

## Each goal: id, text, hint (how), and what it needs:
##   "item": [ids, n]  - n of any of these items
##   "build": [types, n] - n placed structures of any of these types
##   "room": n         - closed rooms holding a bed
##   "reach": area     - set foot in that area
##   "boss": type      - that guardian slain
##   "glyphs": n       - glyph stones read
##   "survivors": n    - people living in the camp
##   "escaped": true
const GOALS := [
	{"id": "wood", "text": "Gather 6 Wood", "hint": "Hold E next to a tree.", "item": [["wood"], 6]},
	{"id": "stone", "text": "Gather 6 Stone", "hint": "Hold E next to a rock.", "item": [["stone"], 6]},
	{"id": "tool", "text": "Craft a Stone Axe or Pickaxe", "hint": "I opens the backpack; sticks come from wood.", "item": [["stone_axe", "stone_pickaxe"], 1]},
	{"id": "workbench", "text": "Build a Workbench", "hint": "Craft it at the campfire (E), place it with B.", "build": [["workbench"], 1]},
	{"id": "bed", "text": "Build a Straw Bed", "hint": "Workbench recipe. Grass gives fiber.", "build": [["bed"], 1]},
	{"id": "room", "text": "Close a room around your bed", "hint": "Walls and a door all round: sleep there at night.", "room": 1},
	{"id": "maze", "text": "Enter the Labyrinth", "hint": "North gate. Go by day: it shuts at 20:00.", "reach": "labyrinth"},
	{"id": "glyph", "text": "Read a glyph stone", "hint": "Carved stones in quiet maze corners. Press E.", "glyphs": 1},
	{"id": "village", "text": "Grow the camp to 3 survivors", "hint": "2 beds, a workbench and food in the Stash (Tab: Camp).", "survivors": 3},
	{"id": "boss_labyrinth", "text": "Slay the Stone Colossus", "hint": "Its arena lies at the north end of the Stone Labyrinth.", "boss": "stone_colossus"},
	{"id": "boss_overgrowth", "text": "Slay the Briar Hydra", "hint": "The Stone Key opens the Overgrowth, north of the arena.", "boss": "briar_hydra"},
	{"id": "boss_desert", "text": "Slay the Sun Wyrm", "hint": "The Sunken Dunes are thirsty: carry a waterskin.", "boss": "sun_wyrm"},
	{"id": "boss_ice", "text": "Slay the Hoarfrost Dragon", "hint": "The Rime Halls freeze the unprepared: wear warm gear.", "boss": "hoarfrost_dragon"},
	{"id": "boss_volcano", "text": "Slay the Forgeheart Giant", "hint": "The Cinder Forge burns: cooling gear or draughts.", "boss": "forgeheart_giant"},
	{"id": "boss_hell", "text": "Slay the Pit Lord", "hint": "The last guardian waits at the bottom of the Pit.", "boss": "pit_lord"},
	{"id": "escape", "text": "Walk out of the Maze", "hint": "Six Keys open the Pit's final gate.", "escaped": true},
]


static func ids() -> Array:
	return GOALS.map(func(g): return g.id)


static func by_id(id: String) -> Dictionary:
	for g in GOALS:
		if g.id == id:
			return g
	return {}


## [have, need] for a goal; need 1 for yes/no goals.
static func progress(goal: Dictionary, ctx: Dictionary) -> Array:
	if goal.has("item"):
		var n := 0
		for id in goal.item[0]:
			n += int(ctx.get("items", {}).get(id, 0))
		return [mini(n, goal.item[1]), goal.item[1]]
	if goal.has("build"):
		var n := 0
		for t in goal.build[0]:
			n += int(ctx.get("structures", {}).get(t, 0))
		return [mini(n, goal.build[1]), goal.build[1]]
	if goal.has("room"):
		return [mini(int(ctx.get("rooms_with_bed", 0)), goal.room), goal.room]
	if goal.has("reach"):
		return [1 if ctx.get("reached", {}).has(goal.reach) else 0, 1]
	if goal.has("boss"):
		return [1 if ctx.get("bosses", {}).has(goal.boss) else 0, 1]
	if goal.has("glyphs"):
		return [mini(int(ctx.get("glyphs", 0)), goal.glyphs), goal.glyphs]
	if goal.has("survivors"):
		return [mini(int(ctx.get("survivors", 0)), goal.survivors), goal.survivors]
	if goal.has("escaped"):
		return [1 if ctx.get("escaped", false) else 0, 1]
	return [0, 1]


static func met(goal: Dictionary, ctx: Dictionary) -> bool:
	var p := progress(goal, ctx)
	return p[0] >= p[1]


## Marks every goal met in `ctx` as done; returns the ids newly done, in order.
static func update(done: Dictionary, ctx: Dictionary) -> Array:
	var fresh := []
	for g in GOALS:
		if not done.has(g.id) and met(g, ctx):
			done[g.id] = true
			fresh.append(g.id)
	return fresh


## The first goal not done yet ({} once everything is done).
static func current(done: Dictionary) -> Dictionary:
	for g in GOALS:
		if not done.has(g.id):
			return g
	return {}


## Snapshot of the game for the goal rules, from a player and GameState.
static func context(player: Node) -> Dictionary:
	var items := {}
	var sources: Array = [GameState.stash]
	if player != null:
		sources.append(player.inventory)
	for inv in sources:
		for s in inv.slots:
			if s != null and not s.is_empty():
				items[s.id] = int(items.get(s.id, 0)) + int(s.count)
	if player != null:
		for slot in Equipment.SLOTS:
			var id: String = player.equipment.get_item(slot)
			if id != "":
				items[id] = int(items.get(id, 0)) + 1
	var structures := {}
	var beds: Array[Vector2i] = []
	for cell in GameState.structures:
		var t := String(GameState.structures[cell].get("type", ""))
		structures[t] = int(structures.get(t, 0)) + 1
		if t == "bed":
			beds.append(cell)
	var rooms := {}
	for cell in beds:
		var room := Rooms.find(GameState.structures, cell)
		if not room.is_empty():
			rooms[Rooms.key(room)] = true
	return {"items": items, "structures": structures, "rooms_with_bed": rooms.size(),
		"reached": GameState.reached, "bosses": GameState.bosses_defeated,
		"glyphs": GameState.journal.get("glyphs", {}).size(), "companions": GameState.companions.size(),
		"survivors": GameState.survivors.size(), "escaped": GameState.escaped}
