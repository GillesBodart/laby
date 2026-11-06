extends Node
## Session-wide state: world seed and the player registry.
## Players are keyed by multiplayer peer id so nothing assumes a single
## local player (LAN co-op readiness).

const OFFLINE_PEER_ID := 1

var world_seed: int = 0
var players: Dictionary = {} # peer_id -> Player node
## Save data waiting to be applied once the world scene is built.
var pending_save: Dictionary = {}


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
