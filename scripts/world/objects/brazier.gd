class_name Brazier
extends StaticBody2D
## Iron fire basket on a stone post: two flank the Clearing's north gate so
## the way home reads from afar, warm against the cold maze light.

const TEXTURE_PATH := "res://assets/sprites/environment/landmarks/brazier.png"
const LIGHT_COLOR := Color(1.0, 0.7, 0.4)

var _light: PointLight2D
var _time := 0.0


func _ready() -> void:
	collision_mask = 0
	add_to_group("brazier")
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -4)
	add_child(col)
	var shadow := Sprite2D.new()
	shadow.texture = preload("res://assets/sprites/effects/shadow.png")
	shadow.position = Vector2(0, -2)
	add_child(shadow)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load(TEXTURE_PATH)
	sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0 + 2.0)
	add_child(sprite)
	_light = PointLight2D.new()
	_light.texture = preload("res://resources/lights/light_banded.tres")
	_light.color = LIGHT_COLOR
	_light.texture_scale = 1.6
	_light.position = Vector2(0, -26)
	add_child(_light)
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	_light.energy = LightingCurve.darkness_at(TimeSystem.minute_of_day()) * (1.0 + 0.1 * sin(_time * 9.0) + 0.05 * sin(_time * 23.0))
