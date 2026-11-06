extends Node
## Session-wide state: world seed and the player registry.
## Players are keyed by multiplayer peer id so nothing assumes a single
## local player (LAN co-op readiness).

const OFFLINE_PEER_ID := 1
const STASH_SLOTS := 40
const AREA_SCENES := {
	"clearing": "res://scenes/world/world.tscn",
	"labyrinth": "res://scenes/world/labyrinth.tscn",
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
	survivals = {}
	fog = {}
	depleted_cells = {}
	structures = {}
	stash = Inventory.new(STASH_SLOTS)


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
