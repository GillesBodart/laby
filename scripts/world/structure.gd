class_name Structure
extends StaticBody2D
## A player-built tile structure (wall, floor, door, chest, crafting station).

var type := ""
var cell := Vector2i.ZERO
var is_open := false
var stage := 0

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
	shape.size = Vector2(32, 32)
	_collision.shape = shape
	add_child(_collision)
	add_child(_sprite)
	_refresh()


func is_farm() -> bool:
	return type == "farm_plot"


func _process(_delta: float) -> void:
	if is_farm():
		var planted: float = GameState.structures.get(cell, {}).get("planted", Farming.NOT_PLANTED)
		var now := Farming.stage(planted, TimeSystem.clock.total_minutes)
		if now != stage:
			stage = now
			_refresh()


## Plants a berry, or harvests ripe crops. Returns true if something happened.
func farm_interact(player: Player) -> bool:
	var data: Dictionary = GameState.structures[cell]
	var planted: float = data.get("planted", Farming.NOT_PLANTED)
	var now := TimeSystem.clock.total_minutes
	match Farming.stage(planted, now):
		Farming.EMPTY:
			if not player.inventory.remove("berry", 1):
				EventBus.notify.emit("Plant a berry here")
				return false
			data["planted"] = now
			EventBus.notify.emit("Berry planted")
		Farming.GROWING:
			EventBus.notify.emit("Growing... %d min left" % ceili(Farming.minutes_left(planted, now) / 2.0))
			return false
		_:
			var n := randi_range(3, 5)
			var left := player.inventory.add("berry", n)
			EventBus.notify.emit("Harvest: +%d Berries" % (n - left))
			data["planted"] = Farming.NOT_PLANTED
			player.gain_xp(3)
	stage = Farming.stage(data["planted"], now)
	_refresh()
	return true


func toggle() -> void:
	if BuildCatalog.TYPES[type].get("door", false):
		is_open = not is_open
		_refresh()


func _refresh() -> void:
	var def: Dictionary = BuildCatalog.TYPES[type]
	_sprite.texture = load(BuildCatalog.texture_path(type, is_open, stage))
	_collision.set_deferred("disabled", not def.solid or is_open)
