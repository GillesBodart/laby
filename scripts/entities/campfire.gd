extends Node2D
## Clearing campfire: animated flames and a flickering warm light that
## matters more as night falls.

const SHEET := preload("res://assets/sprites/campfire.png")
const BASE_ENERGY := 1.1

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var light: PointLight2D = $Light

var _time := 0.0


func _ready() -> void:
	add_to_group("campfire")
	sprite.sprite_frames = SpriteFramesBuilder.build(SHEET, Vector2i(16, 16), {
		"burn": {"row": 0, "frames": [0, 1, 2], "fps": 7.0},
	})
	sprite.play("burn")


func _process(delta: float) -> void:
	_time += delta
	var flicker := 0.08 * sin(_time * 11.0) + 0.05 * sin(_time * 23.0 + 1.3)
	var darkness := LightingCurve.darkness_at(TimeSystem.minute_of_day())
	light.energy = darkness * (BASE_ENERGY + flicker)
