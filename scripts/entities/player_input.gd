class_name PlayerInput
extends Node
## Converts local device input into a movement intent. Only the owning peer
## reads the keyboard; remote players' intents will be fed by RPC (co-op).

var peer_id: int = GameState.OFFLINE_PEER_ID
var move_vector := Vector2.ZERO
var run := false
var interact := false
var attack := false
## Direction from the player towards the mouse (ZERO until the mouse is used,
## then shots follow the cursor instead of the facing direction).
var aim_dir := Vector2.ZERO
var _mouse_used := false


func is_local() -> bool:
	return peer_id == GameState.local_peer_id()


func _physics_process(_delta: float) -> void:
	if not is_local():
		return
	move_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	run = Input.is_action_pressed("run")
	interact = Input.is_action_pressed("interact")
	attack = Input.is_action_pressed("attack")
	var body := get_parent() as Node2D
	if _mouse_used and body:
		aim_dir = (body.get_global_mouse_position() - body.global_position - Vector2(0, -10)).normalized()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and is_local():
		_mouse_used = true
