class_name GameCamera
extends Camera2D
## Follows the local player, clamped to the map bounds.

var target: Node2D


func follow(node: Node2D, snap := true) -> void:
	target = node
	if snap and target:
		global_position = target.global_position
		reset_smoothing()


func set_bounds(size_px: Vector2i) -> void:
	limit_left = 0
	limit_top = 0
	limit_right = size_px.x
	limit_bottom = size_px.y


func _physics_process(_delta: float) -> void:
	if is_instance_valid(target):
		global_position = target.global_position
