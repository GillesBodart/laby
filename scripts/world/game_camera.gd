class_name GameCamera
extends Camera2D
## Follows the local player, clamped to the map bounds. shake jolts it
## briefly (the player being hurt): whole-pixel offsets, quickly damped.

## Below 1 the camera stands back: about 40x22 tiles on screen, like a
## classic RPG overview, instead of 30x17 big chunky pixels.
const ZOOM := 0.75
const SHAKE_MAX := 5.0
const SHAKE_DECAY := 3.0

var target: Node2D
var _trauma := 0.0


func _ready() -> void:
	zoom = Vector2(ZOOM, ZOOM)


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


## Adds 0..1 of trauma; the jolt grows with its square.
func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		global_position = target.global_position
	if _trauma > 0.0:
		_trauma = maxf(_trauma - SHAKE_DECAY * delta, 0.0)
		var s := SHAKE_MAX * _trauma * _trauma
		offset = Vector2(randf_range(-s, s), randf_range(-s, s)).round()
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO
