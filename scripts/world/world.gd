extends Node2D
## Main gameplay scene: builds the Clearing from the world seed, spawns the
## local player and wires the camera.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@onready var clearing: ClearingWorld = $Clearing
@onready var camera: GameCamera = $Camera


func _ready() -> void:
	var layout := ClearingGenerator.generate(GameState.world_seed)
	clearing.build(layout)
	camera.set_bounds(clearing.pixel_size())

	var player := spawn_player(GameState.local_peer_id(), ClearingWorld.cell_center(layout.spawn_cell))
	var save := GameState.take_pending_save()
	if save.is_empty():
		EventBus.notify.emit("You wake up in the Clearing. The walls are... enormous.")
	else:
		SaveSystem.apply_to_tree(save)
	camera.follow(player)


func spawn_player(peer_id: int, at: Vector2) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.peer_id = peer_id
	player.name = "Player_%d" % peer_id
	player.position = at
	clearing.entities.add_child(player)
	return player
