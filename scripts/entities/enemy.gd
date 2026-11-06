class_name Enemy
extends CharacterBody2D
## Labyrinth creature: idles until a player comes within its aggro range,
## then chases and bites. Stats come from EnemyCatalog.

const KNOCKBACK := 140.0
const KNOCK_DECAY := 700.0

var type_id := "grub"
var hp := 1
var _def: Dictionary
var _cooldown := 0.0
var _knock := Vector2.ZERO
var _flash := 0.0
var _dead := false

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $Collision


func setup(id: String) -> void:
	type_id = id
	_def = EnemyCatalog.def(id)
	hp = _def.hp


func _ready() -> void:
	if _def.is_empty():
		setup(type_id)
	add_to_group("enemies")
	sprite.texture = load("res://assets/sprites/enemies/%s.png" % type_id)
	var shape := CircleShape2D.new()
	shape.radius = _def.radius
	collision.shape = shape


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(1.8, 1.8, 1.8) if _flash > 0.0 else Color.WHITE
	var target := _nearest_player()
	var desired := Vector2.ZERO
	if target:
		var to := target.global_position - global_position
		if to.length() > _def.attack_range:
			desired = to.normalized() * _def.speed
		elif _cooldown == 0.0:
			_cooldown = _def.cooldown
			target.take_damage(_def.damage, self)
		sprite.flip_h = to.x < 0.0
	velocity = desired + _knock
	_knock = _knock.move_toward(Vector2.ZERO, KNOCK_DECAY * delta)
	move_and_slide()


func _nearest_player() -> Player:
	var best: Player = null
	var best_d: float = _def.aggro
	for p in GameState.players.values():
		if p.survival.is_dead():
			continue
		var d := global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


func take_damage(amount: int, source: Player = null) -> void:
	if _dead:
		return
	hp -= amount
	_flash = 0.12
	if source:
		_knock = (global_position - source.global_position).normalized() * KNOCKBACK
	if hp <= 0:
		_die(source)


func _die(killer: Player) -> void:
	_dead = true
	if killer:
		var n := randi_range(_def.drop_min, _def.drop_max)
		if n > 0:
			killer.inventory.add(_def.drop, n)
			EventBus.notify.emit("%s defeated: +%d %s" % [_def.name, n, ItemCatalog.item_name(_def.drop)])
		else:
			EventBus.notify.emit("%s defeated" % _def.name)
		killer.gain_xp(_def.xp)
	queue_free()
