class_name PlayerInput
extends Node
## Converts local device input into a movement intent. Only the owning peer
## reads the keyboard; remote players' intents will be fed by RPC (co-op).

var peer_id: int = GameState.OFFLINE_PEER_ID
var move_vector := Vector2.ZERO
var run := false
var interact := false
var attack := false


func is_local() -> bool:
	return peer_id == GameState.local_peer_id()


func _physics_process(_delta: float) -> void:
	if not is_local():
		return
	move_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	run = Input.is_action_pressed("run")
	interact = Input.is_action_pressed("interact")
	attack = Input.is_action_pressed("attack")
