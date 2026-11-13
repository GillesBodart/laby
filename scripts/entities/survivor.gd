class_name Survivor
extends CharacterBody2D
## A survivor living in the Clearing (see Settlement, GameState.survivors).
## Potters about near the campfire by day and sits close to it at night.
## E talks to them and opens the settlement panel, where roles are set.

const SPEED := 22.0
const WANDER := 3.5 * 32.0
## Guards go after raiders anywhere near the camp and strike every GUARD_RATE s.
const GUARD_RANGE := 12.0 * 32.0
const GUARD_DAMAGE := 5
const GUARD_RATE := 1.1

var index := 0 # in GameState.survivors
var home := Vector2.ZERO
var _target := Vector2.ZERO
var _wait := 0.0
var _sprite := Sprite2D.new()
var _gait: Gait
var _foe: Node2D = null
var _strike := 0.0


static func create(survivor_index: int, home_pos: Vector2) -> Survivor:
	var s := Survivor.new()
	s.index = survivor_index
	s.home = home_pos
	return s


func record() -> Dictionary:
	return GameState.survivors[index] if index < GameState.survivors.size() else {}


func cast() -> Dictionary:
	var r := record()
	return Settlement.CAST[int(r.cast)] if not r.is_empty() else Settlement.CAST[0]


func _ready() -> void:
	add_to_group("survivors")
	add_to_group("interactable")
	collision_layer = 0
	collision_mask = 1
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -4)
	add_child(col)
	var shadow := Sprite2D.new()
	shadow.texture = load("res://assets/sprites/effects/shadow.png")
	shadow.position = Vector2(0, -2)
	add_child(shadow)
	# Walk strip: idle pose then contact/passing/contact/passing.
	var walk := "res://assets/sprites/characters/survivors/%s_walk.png" % cast().sprite
	if ResourceLoader.exists(walk):
		_sprite.texture = load(walk)
		_sprite.hframes = 5
	else:
		_sprite.texture = load("res://assets/sprites/characters/survivors/%s.png" % cast().sprite)
	_sprite.offset = Vector2(0, -_sprite.texture.get_height() / 2.0 + 2)
	add_child(_sprite)
	_gait = Gait.attach(self, [_sprite])
	_gait.hop = 0.8
	_gait.sway_deg = 2.5
	_gait.squash = 0.035
	position = home + Vector2(randf_range(-20, 20), randf_range(-12, 12))
	_target = position


func _physics_process(delta: float) -> void:
	if record().get("role", "") == "guard" and _defend(delta):
		return
	_wait -= delta
	var to := _target - position
	if to.length() < 3.0 or _wait < -6.0:
		# Arrived, or stuck against something for a while: rest, then wander on.
		velocity = Vector2.ZERO
		if _wait <= 0.0:
			_pick_target()
	else:
		velocity = to.normalized() * SPEED
		_sprite.flip_h = to.x < 0
	move_and_slide()
	_animate(delta)


func _animate(delta: float) -> void:
	_gait.advance(delta, velocity.length())
	if _sprite.hframes > 1:
		var moving := velocity.length() > 4.0
		_sprite.frame = 1 + int(fposmod(_gait.steps * 2.0 + 0.5, 4.0)) if moving else 0


## Guard duty: chase the nearest raider near the camp and strike it.
func _defend(delta: float) -> bool:
	_strike = maxf(_strike - delta, 0.0)
	if _foe == null or not is_instance_valid(_foe) or _foe.is_queued_for_deletion():
		_foe = null
		var best := GUARD_RANGE
		for e in get_tree().get_nodes_in_group("raiders"):
			var d := home.distance_to(e.global_position)
			if d < best and not e.is_queued_for_deletion():
				best = d
				_foe = e
	if _foe == null:
		return false
	var to := _foe.global_position - global_position
	if to.length() > 20.0:
		velocity = to.normalized() * SPEED * 3.5
		_sprite.flip_h = to.x < 0
	else:
		velocity = Vector2.ZERO
		if _strike == 0.0:
			_strike = GUARD_RATE
			_foe.take_damage(GUARD_DAMAGE, self)
	move_and_slide()
	_animate(delta)
	return true


func _pick_target() -> void:
	var night := TimeSystem.phase() == DayClock.Phase.NIGHT
	var r := 40.0 if night else WANDER
	_target = home + Vector2(randf_range(-r, r), randf_range(-r * 0.6, r * 0.6))
	_wait = randf_range(1.5, 4.0)


func can_interact(_player: Node) -> bool:
	return not record().is_empty()


func interact_hint() -> String:
	return "Talk to %s (%s)" % [cast().name, record().get("role", "")]


func interact(_player: Node) -> void:
	EventBus.notify.emit("%s: \"%s\"" % [cast().name, cast().line])
	EventBus.survivor_talked.emit(self)
