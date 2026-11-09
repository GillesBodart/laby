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
## Tamed creatures: [{type, name, owner, hp, max_hp, level, xp, mode, downed}].
var companions: Array = []


func _ready() -> void:
	if world_seed == 0:
		new_game()


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


## Progress data that lives outside the scene tree (saved by SaveSystem).
func meta_to_data() -> Dictionary:
	return {"remains": remains.duplicate(true), "reached": reached.keys(), "keys": keys.keys(),
		"bosses": bosses_defeated.keys(), "escaped": escaped, "companions": companions.duplicate(true)}


func meta_from_data(data: Dictionary) -> void:
	remains = []
	for r in data.get("remains", []):
		remains.append({"area": String(r.area), "pos": [float(r.pos[0]), float(r.pos[1])], "items": Array(r.items)})
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


func _set_of(list: Array) -> Dictionary:
	var out := {}
	for k in list:
		out[String(k)] = true
	return out


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
	if scene_changer.is_valid():
		scene_changer.call(AREA_SCENES[target])
	else:
		get_tree().change_scene_to_file.call_deferred(AREA_SCENES[target])


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
