class_name Structure
extends StaticBody2D
## A player-built tile structure (wall, floor, door, workbench, chest).

var type := ""
var cell := Vector2i.ZERO
var is_open := false

var _sprite := Sprite2D.new()
var _collision := CollisionShape2D.new()


static func create(structure_type: String, structure_cell: Vector2i, open := false) -> Structure:
	var s := Structure.new()
	s.type = structure_type
	s.cell = structure_cell
	s.is_open = open
	return s


func _ready() -> void:
	var def: Dictionary = BuildCatalog.TYPES[type]
	collision_mask = 0
	position = ClearingWorld.cell_center(cell)
	add_to_group("structures")
	if def.group != "":
		add_to_group(def.group)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	_collision.shape = shape
	add_child(_collision)
	add_child(_sprite)
	_refresh()


func toggle() -> void:
	if BuildCatalog.TYPES[type].get("door", false):
		is_open = not is_open
		_refresh()


func _refresh() -> void:
	var def: Dictionary = BuildCatalog.TYPES[type]
	_sprite.texture = load(BuildCatalog.texture_path(type, is_open))
	_collision.set_deferred("disabled", not def.solid or is_open)
