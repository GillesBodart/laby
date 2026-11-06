class_name Player
extends CharacterBody2D
## Survivor controlled by a PlayerInput intent (keyboard locally,
## network later). Movement uses a small state machine.

enum State { IDLE, MOVE }

const WALK_SPEED := 72.0
const RUN_SPEED := 115.0
const ACCELERATION := 900.0
const FRICTION := 1200.0
const SHEET := preload("res://assets/sprites/player.png")
const FRAME_SIZE := Vector2i(16, 16)
const ANIMATIONS := {
	"idle_down": {"row": 0, "frames": [0], "fps": 1.0},
	"walk_down": {"row": 0, "frames": [1, 0, 2, 0], "fps": 8.0},
	"idle_up": {"row": 1, "frames": [0], "fps": 1.0},
	"walk_up": {"row": 1, "frames": [1, 0, 2, 0], "fps": 8.0},
	"idle_side": {"row": 2, "frames": [0], "fps": 1.0},
	"walk_side": {"row": 2, "frames": [1, 0, 2, 0], "fps": 8.0},
}

const REACH := 18.0
const STATION_RANGE := 56.0
const GATHER_COOLDOWN := 0.4

@export var peer_id: int = GameState.OFFLINE_PEER_ID

var state: State = State.IDLE
var facing := Vector2.DOWN
var inventory := Inventory.new()
var _gather_timer := 0.0

@onready var input: PlayerInput = $PlayerInput
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var light: PointLight2D = $Light


func _ready() -> void:
	add_to_group("players")
	add_to_group("persist")
	input.peer_id = peer_id
	sprite.sprite_frames = SpriteFramesBuilder.build(SHEET, FRAME_SIZE, ANIMATIONS)
	sprite.play("idle_down")
	GameState.register_player(self)


func _exit_tree() -> void:
	if GameState.players.get(peer_id) == self:
		GameState.unregister_player(peer_id)


func _physics_process(delta: float) -> void:
	var move := input.move_vector
	match state:
		State.IDLE:
			if move != Vector2.ZERO:
				state = State.MOVE
		State.MOVE:
			if move == Vector2.ZERO:
				state = State.IDLE

	if state == State.MOVE:
		var speed := RUN_SPEED if input.run else WALK_SPEED
		velocity = velocity.move_toward(move * speed, ACCELERATION * delta)
		facing = _cardinal(move)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	_update_visuals()
	_gather_timer = maxf(_gather_timer - delta, 0.0)
	if input.interact and _gather_timer == 0.0:
		_try_gather()


func _try_gather() -> void:
	var target := find_gatherable()
	if target:
		_gather_timer = GATHER_COOLDOWN
		target.hit(self)


## Nearest harvestable prop within reach in front of the player.
func find_gatherable() -> Gatherable:
	var probe := global_position + Vector2(0, -4) + facing * 8.0
	var best: Gatherable = null
	var best_d := REACH
	for node in get_tree().get_nodes_in_group("gatherable"):
		var d := probe.distance_to(node.global_position + Vector2(0, -3))
		if d < best_d:
			best_d = d
			best = node
	return best


## Crafting stations available near the player.
func nearby_stations() -> Array:
	var found: Array = []
	for group in ["campfire", "workbench"]:
		for node in get_tree().get_nodes_in_group(group):
			if global_position.distance_to(node.global_position) <= STATION_RANGE:
				found.append(group)
				break
	# Until placeable stations (M3), a carried workbench counts.
	if inventory.count("workbench") > 0 and not found.has("workbench"):
		found.append("workbench")
	return found

func _cardinal(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2.RIGHT if v.x > 0 else Vector2.LEFT
	return Vector2.DOWN if v.y > 0 else Vector2.UP


func _update_visuals() -> void:
	var dir_name := "down"
	if facing == Vector2.UP:
		dir_name = "up"
	elif facing.x != 0:
		dir_name = "side"
	sprite.flip_h = facing == Vector2.LEFT
	var anim := ("walk_" if state == State.MOVE else "idle_") + dir_name
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.speed_scale = 1.5 if input.run else 1.0
	light.energy = 0.55 * LightingCurve.darkness_at(TimeSystem.minute_of_day())


func get_save_key() -> String:
	return "player_%d" % peer_id


func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"facing": [facing.x, facing.y],
		"inventory": inventory.to_data(),
	}


func load_save_data(data: Dictionary) -> void:
	inventory.load_data(data.get("inventory", []))
	var p: Array = data.get("position", [global_position.x, global_position.y])
	global_position = Vector2(p[0], p[1])
	var f: Array = data.get("facing", [0, 1])
	facing = Vector2(f[0], f[1])
	velocity = Vector2.ZERO
