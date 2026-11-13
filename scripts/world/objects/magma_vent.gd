class_name MagmaVent
extends Node2D
## Cinder Forge floor hazard: a glowing crack along one lane of a passage
## (see LabyrinthGenerator._place_vents). Anyone standing on it burns a little
## every TICK seconds; the other lanes stay safe.

const TEXTURE_PATH := "res://assets/sprites/environment/hazards/magma_vent.png"
const DAMAGE := 4
const TICK := 0.8
const LIGHT_COLOR := Color(1.0, 0.45, 0.15)

var rect: Rect2i
var _time := 0.0
var _tick := 0.0
var _light: PointLight2D


static func create(tiles: Rect2i) -> MagmaVent:
	var v := MagmaVent.new()
	v.rect = tiles
	return v


func _ready() -> void:
	add_to_group("hazards")
	var t := TileCatalog.TILE_SIZE
	position = Vector2(rect.position * t)
	var tex: Texture2D = load(TEXTURE_PATH)
	for y in rect.size.y:
		for x in rect.size.x:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.position = Vector2(x * t, y * t)
			s.flip_h = (rect.position.x + x + rect.position.y + y) % 2 == 1
			add_child(s)
	_light = PointLight2D.new()
	_light.texture = preload("res://resources/lights/light_banded.tres")
	_light.color = LIGHT_COLOR
	_light.texture_scale = 0.7
	_light.position = Vector2(rect.size * t) / 2.0
	add_child(_light)
	_time = float(rect.position.x * 7 + rect.position.y) * 0.37


func _process(delta: float) -> void:
	_time += delta
	_light.energy = 0.55 + 0.25 * sin(_time * 3.0) + 0.1 * sin(_time * 11.0)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	var t := float(TileCatalog.TILE_SIZE)
	var area := Rect2(Vector2(rect.position) * t, Vector2(rect.size) * t)
	for p in GameState.players.values():
		if is_instance_valid(p) and area.has_point(p.global_position):
			p.take_damage(DAMAGE, self)
