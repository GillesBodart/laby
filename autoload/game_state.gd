extends Node
## Session-wide state: world seed and the player registry.
## Players are keyed by multiplayer peer id so nothing assumes a single
## local player (LAN co-op readiness).

const OFFLINE_PEER_ID := 1
const STASH_SLOTS := 40
const AREA_SCENES := {
	"clearing": "res://scenes/world/world.tscn",
	"labyrinth": "res://scenes/world/labyrinth.tscn",
	"overgrowth": "res://scenes/world/labyrinth.tscn",
	"desert": "res://scenes/world/labyrinth.tscn",
	"ice": "res://scenes/world/labyrinth.tscn",
	"volcano": "res://scenes/world/labyrinth.tscn",
	"hell": "res://scenes/world/labyrinth.tscn",
}

var world_seed: int = 0
var players: Dictionary = {} # peer_id -> Player node
## Save data waiting to be applied once the world scene is built.
var pending_save: Dictionary = {}
var area := "clearing"
## Optional override of the scene switch (used by tests).
var scene_changer := Callable()
## True right after crossing a portal: the player spawns at the arrival cell.
var arriving := false
## Per-peer backpacks kept while changing area (peer_id -> Inventory data).
var inventories: Dictionary = {}
## Per-peer worn gear kept while changing area (peer_id -> Equipment data).
var equipments: Dictionary = {}
## Discovered item ids per peer (peer_id -> Array), kept across area changes.
var knowns: Dictionary = {}
## Per-peer survival stats kept while changing area (peer_id -> Survival data).
var survivals: Dictionary = {}
## Explored cells per area (area name -> FogMap), only for fogged areas.
var fog: Dictionary = {}
## Harvested Clearing props (cell -> true), so they stay gone across areas.
var depleted_cells: Dictionary = {}
## Player-built structures in the Clearing (cell -> {"type": String, "open": bool}).
## Something built on a floor keeps it as "floor" (the floor's type).
var structures: Dictionary = {}
## Shared Stash (chest storage): never lost on death (see design spec).
var stash := Inventory.new(STASH_SLOTS)
## Dropped backpacks: [{"area": String, "pos": [x, y], "items": Array}].
var remains: Array = []
## Area left by the last travel (picks the arrival cell in the new area).
var came_from := ""
## Sectors ever entered (sector id -> true): the Waystone travels to them.
var reached: Dictionary = {}
## Keys earned from sector guardians (key item id -> true); they unseal gates.
var keys: Dictionary = {}
## Guardians slain (boss type -> true); they never come back.
var bosses_defeated: Dictionary = {}
## Set once the players walk out of the Pit's last gate.
var escaped := false
## The escape travel asks the Clearing HUD to show the epilogue (not saved).
var epilogue_pending := false
## Tamed creatures: [{type, name, owner, hp, max_hp, level, xp, mode, downed}].
var companions: Array = []
## Field journal: kind (creatures/resources/glyphs/places) -> {id: count}.
var journal: Dictionary = {}
## Map markers per area: area -> [{kind, cell: [x, y]}].
var markers: Dictionary = {}

## Survivors living in the Clearing: [{cast (Settlement.CAST index), role}].
var survivors: Array = []
## Highest settlement tier announced so far.
var settlement_tier := 0
## Goals of the HUD chain already met (Objectives id -> true).
var goals: Dictionary = {}

const JOURNAL_KINDS := ["creatures", "resources", "glyphs", "places"]
const MARKER_KINDS := ["danger", "resource", "door", "note"]


func _ready() -> void:
	if world_seed == 0:
		new_game()
	EventBus.day_started.connect(func(_day): run_dawn())
	EventBus.night_started.connect(raid_while_away)


func new_game(seed_value: int = 0) -> void:
	if seed_value == 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		seed_value = rng.randi_range(1, 2_000_000_000)
	world_seed = seed_value
	pending_save = {}
	area = "clearing"
	arriving = false
	inventories = {}
	equipments = {}
	knowns = {}
	survivals = {}
	fog = {}
	depleted_cells = {}
	structures = {}
	stash = Inventory.new(STASH_SLOTS)
	remains = []
	came_from = ""
	reached = {}
	keys = {}
	bosses_defeated = {}
	escaped = false
	companions = []
	journal = {}
	markers = {}
	survivors = [{"cast": 0, "role": Settlement.CAST[0].role}]
	settlement_tier = 0
	goals = {}


## Progress data that lives outside the scene tree (saved by SaveSystem).
func meta_to_data() -> Dictionary:
	return {"remains": remains.duplicate(true), "reached": reached.keys(), "keys": keys.keys(),
		"bosses": bosses_defeated.keys(), "escaped": escaped, "companions": companions.duplicate(true),
		"journal": journal.duplicate(true), "markers": markers.duplicate(true),
		"survivors": survivors.duplicate(true), "settlement_tier": settlement_tier, "goals": goals.keys()}


func meta_from_data(data: Dictionary) -> void:
	remains = []
	for r in data.get("remains", []):
		remains.append({"area": String(r.area), "pos": [float(r.pos[0]), float(r.pos[1])], "items": Array(r.items),
			"dropped": bool(r.get("dropped", false))})
	reached = _set_of(data.get("reached", []))
	keys = _set_of(data.get("keys", []))
	bosses_defeated = _set_of(data.get("bosses", []))
	escaped = bool(data.get("escaped", false))
	companions = []
	for c in data.get("companions", []):
		if EnemyCatalog.has(String(c.get("type", ""))):
			companions.append({"type": String(c.type), "name": String(c.get("name", "")), "owner": int(c.get("owner", 1)),
				"hp": int(c.hp), "max_hp": int(c.max_hp), "level": int(c.get("level", 1)), "xp": int(c.get("xp", 0)),
				"mode": String(c.get("mode", "follow")), "downed": bool(c.get("downed", false))})
	journal = {}
	var j: Dictionary = data.get("journal", {})
	for kind in JOURNAL_KINDS:
		var entries: Dictionary = j.get(kind, {})
		for id in entries:
			log_journal(kind, String(id), int(entries[id]))
	survivors = []
	for s in data.get("survivors", [{"cast": 0, "role": Settlement.CAST[0].role}]):
		var ci := int(s.get("cast", -1))
		if ci >= 0 and ci < Settlement.CAST.size() and Settlement.ROLES.has(String(s.get("role", ""))):
			survivors.append({"cast": ci, "role": String(s.role)})
	settlement_tier = int(data.get("settlement_tier", 0))
	goals = _set_of(data.get("goals", []))
	markers = {}
	var m: Dictionary = data.get("markers", {})
	for a in m:
		for mk in m[a]:
			add_marker(String(a), String(mk.get("kind", "note")), Vector2i(int(mk.cell[0]), int(mk.cell[1])))


func _set_of(list: Array) -> Dictionary:
	var out := {}
	for k in list:
		out[String(k)] = true
	return out


## The settlement's dawn: eat, work, chart, welcome newcomers (see Settlement).
func run_dawn() -> Dictionary:
	var r := Settlement.dawn(survivors, structures, stash, bosses_defeated.size())
	for i in int(r.chart):
		_chart_somewhere()
	var bits := PackedStringArray()
	for id in r.gained:
		bits.append("+%d %s" % [r.gained[id], ItemCatalog.item_name(id)])
	if not bits.is_empty():
		EventBus.notify.emit("Dawn at the camp: %s (in the Stash)." % ", ".join(bits))
	for line in r.report:
		EventBus.notify.emit(line)
	var builders := survivors.filter(func(s): return s.role == "builder").size()
	if builders > 0:
		var mended := mend_structures(builders * Settlement.BUILDER_REPAIR)
		if mended > 0:
			EventBus.notify.emit("The builders mended %d damaged structure%s." % [mended, "" if mended == 1 else "s"])
	if int(r.arrival) >= 0:
		survivors.append({"cast": int(r.arrival), "role": Settlement.CAST[r.arrival].role})
		EventBus.notify.emit("%s stumbles out of the maze at dawn and joins the camp!" % Settlement.CAST[r.arrival].name)
		EventBus.settlement_changed.emit()
	check_tier()
	return r


## Removes what is built on the cell, leaving the floor it stood on.
## Returns the removed type ("" if none).
func clear_structure(cell: Vector2i) -> String:
	if not structures.has(cell):
		return ""
	var d: Dictionary = structures[cell]
	if d.has("floor"):
		structures[cell] = {"type": d.floor, "open": false, "planted": Farming.NOT_PLANTED}
	else:
		structures.erase(cell)
	return d.type


## Mends damaged structures with a pool of hit points; returns how many.
func mend_structures(pool: int) -> int:
	var n := 0
	var bonus := Structure.toughness_bonus()
	for cell in structures:
		var d: Dictionary = structures[cell]
		if pool <= 0:
			break
		if not d.has("hp"):
			continue
		var full := BuildCatalog.max_hp(d.type, bonus)
		var add := mini(pool, full - int(d.hp))
		pool -= add
		d.hp = int(d.hp) + add
		if int(d.hp) >= full:
			d.erase("hp")
		n += 1
	get_tree().call_group("structures", "queue_redraw")
	return n


## A raid on the Clearing while nobody is home: damage lands on random
## structures; the camp's defence soaks part of it. Returns structures wrecked.
func raid_while_away(night: int) -> int:
	if area == "clearing":
		return 0
	var defence := Settlement.defence(survivors, structures)
	var n := Settlement.raid_size(Settlement.tier(structures, bosses_defeated.size()), night, defence)
	var pool := Settlement.unattended_damage(n, defence)
	var bonus := Structure.toughness_bonus()
	var targets := structures.keys().filter(func(c): return BuildCatalog.max_hp(structures[c].type) > 0)
	var hit := {}
	var wrecked := 0
	while pool > 0 and not targets.is_empty():
		var cell: Vector2i = targets.pick_random()
		var d: Dictionary = structures[cell]
		var blow := mini(pool, 20)
		pool -= blow
		d.hp = int(d.get("hp", BuildCatalog.max_hp(d.type, bonus))) - blow
		hit[cell] = true
		if int(d.hp) <= 0:
			clear_structure(cell)
			targets.erase(cell)
			wrecked += 1
	if n > 0:
		EventBus.notify.emit("Raiders struck the camp while you were away: %d structures damaged, %d wrecked." % [hit.size(), wrecked])
	return wrecked

## Announces a newly reached settlement tier.
func check_tier() -> int:
	var t := Settlement.tier(structures, bosses_defeated.size())
	if t > settlement_tier:
		settlement_tier = t
		EventBus.notify.emit("The Clearing has grown into a %s! Room for %d survivors." % [Settlement.TIERS[t], Settlement.cap(t)])
	return t


## A cartographer charts a patch of a visited sector's fog.
func _chart_somewhere() -> void:
	var areas := fog.keys().filter(func(a): return Sectors.is_sector(a))
	if areas.is_empty():
		return
	var f: FogMap = fog[areas.pick_random()]
	f.reveal(Vector2i(randi_range(0, f.size.x - 1), randi_range(0, f.size.y - 1)), 7)


## Logs a journal entry (count = times seen); true when it is a new one.
func log_journal(kind: String, id: String, count := 1) -> bool:
	if not JOURNAL_KINDS.has(kind) or id == "":
		return false
	if not journal.has(kind):
		journal[kind] = {}
	var fresh: bool = not journal[kind].has(id)
	journal[kind][id] = int(journal[kind].get(id, 0)) + count
	return fresh


func in_journal(kind: String, id: String) -> bool:
	return journal.has(kind) and journal[kind].has(id)


func add_marker(area_name: String, kind: String, cell: Vector2i) -> void:
	if not MARKER_KINDS.has(kind):
		kind = "note"
	if not markers.has(area_name):
		markers[area_name] = []
	markers[area_name].append({"kind": kind, "cell": [cell.x, cell.y]})


## Removes the marker of an area closest to cell (within max_dist cells).
func remove_marker_near(area_name: String, cell: Vector2i, max_dist := 4.0) -> bool:
	var list: Array = markers.get(area_name, [])
	var best := -1
	var best_d := max_dist
	for i in list.size():
		var d := Vector2(cell).distance_to(Vector2(list[i].cell[0], list[i].cell[1]))
		if d <= best_d:
			best_d = d
			best = i
	if best < 0:
		return false
	list.remove_at(best)
	return true


## Companions owned by a survivor (downed ones included).
func party_of(peer_id: int) -> Array:
	return companions.filter(func(c): return int(c.owner) == peer_id)


func add_companion(type: String, peer_id: int) -> Dictionary:
	var hp := int(EnemyCatalog.def(type).hp)
	var c := {"type": type, "name": String(EnemyCatalog.def(type).name), "owner": peer_id, "hp": hp, "max_hp": hp,
		"level": 1, "xp": 0, "mode": "follow", "downed": false}
	companions.append(c)
	return c


## Records a slain guardian and grants its sector's Key.
func defeat_boss(type: String) -> void:
	bosses_defeated[type] = true
	for s in Sectors.ORDER:
		if Sectors.DATA[s].boss == type:
			keys[Sectors.DATA[s].key] = true
			EventBus.notify.emit("The %s is unsealed. A gate opens to the north..." % Sectors.DATA[s].name)


func has_keys(list: Array) -> bool:
	return list.all(func(k): return keys.has(k))


## Thirst only matters once the players have felt the desert sun.
func thirst_unlocked() -> bool:
	return reached.has("desert")


## Leaves a lootable pile of items where a player fell.
func add_remains(area_name: String, pos: Vector2, items: Array) -> Dictionary:
	var entry := {"area": area_name, "pos": [pos.x, pos.y], "items": items}
	remains.append(entry)
	return entry


func fog_for(area_name: String, size: Vector2i) -> FogMap:
	if not fog.has(area_name) or fog[area_name].size != size:
		fog[area_name] = FogMap.new(size)
	return fog[area_name]


func fog_to_data() -> Dictionary:
	var out := {}
	for k in fog:
		out[k] = fog[k].to_data()
	return out


func fog_from_data(data: Dictionary) -> void:
	fog = {}
	for k in data:
		fog[k] = FogMap.from_data(data[k])


func area_scene() -> String:
	return AREA_SCENES[area]


## Moves every player to another area (scene change).
func travel(target: String) -> void:
	if not AREA_SCENES.has(target) or target == area:
		return
	came_from = area
	area = target
	arriving = true
	change_scene(AREA_SCENES[target])


## Switches scene, or hands the path to scene_changer when a test set one.
func change_scene(path: String) -> void:
	if scene_changer.is_valid():
		scene_changer.call(path)
	else:
		get_tree().change_scene_to_file.call_deferred(path)


func local_peer_id() -> int:
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return OFFLINE_PEER_ID


func is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func register_player(player: Node) -> void:
	players[player.peer_id] = player
	EventBus.player_spawned.emit(player)


func unregister_player(peer_id: int) -> void:
	players.erase(peer_id)
	EventBus.player_despawned.emit(peer_id)


func take_pending_save() -> Dictionary:
	var data := pending_save
	pending_save = {}
	return data
