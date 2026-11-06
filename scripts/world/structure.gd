class_name Structure
extends StaticBody2D
## A player-built tile structure (wall, floor, door, chest, crafting station).

var type := ""
var cell := Vector2i.ZERO
var is_open := false
var stage := 0

var _sprite := Sprite2D.new()
## Crop growing on a farm plot (drawn over the soil).
var _crop_sprite := Sprite2D.new()
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
	if is_farm():
		add_child(_crop_sprite)
	_refresh()


func is_farm() -> bool:
	return type == "farm_plot"


func _process(_delta: float) -> void:
	if is_farm():
		var now := _farm_stage()
		if now != stage:
			stage = now
			_refresh()


## Crop sown here ("" when the plot is empty).
func crop() -> String:
	var data: Dictionary = GameState.structures.get(cell, {})
	if data.get("planted", Farming.NOT_PLANTED) < 0.0:
		return ""
	return data.get("crop", Farming.DEFAULT_CROP)


func _farm_stage() -> int:
	var planted: float = GameState.structures.get(cell, {}).get("planted", Farming.NOT_PLANTED)
	return Farming.stage(planted, TimeSystem.clock.total_minutes, Farming.grow_minutes(crop()))


## On an empty plot sows `crop_id` (or asks for a seed when ""); shows growth;
## harvests ripe crops. Returns true if something happened.
func farm_interact(player: Player, crop_id := "") -> bool:
	var data: Dictionary = GameState.structures[cell]
	var planted: float = data.get("planted", Farming.NOT_PLANTED)
	var now := TimeSystem.clock.total_minutes
	match _farm_stage():
		Farming.EMPTY:
			if crop_id == "":
				if player.input.is_local():
					EventBus.farm_plot_used.emit(self)
				return false
			var def: Dictionary = Farming.CROPS[crop_id]
			if not player.inventory.remove(def.seed, 1):
				EventBus.notify.emit("You need %s to plant" % ItemCatalog.item_name(def.seed))
				return false
			data["planted"] = now
			data["crop"] = crop_id
			EventBus.notify.emit("%s planted" % ItemCatalog.item_name(def.yield))
		Farming.GROWING:
			var left_min := Farming.minutes_left(planted, now, Farming.grow_minutes(crop()))
			EventBus.notify.emit("%s growing... %d min left" % [ItemCatalog.item_name(Farming.CROPS[crop()].yield), ceili(left_min / 120.0)])
			return false
		_:
			var def: Dictionary = Farming.CROPS[crop()]
			var n := randi_range(def.min, def.max)
			var left := player.inventory.add(def.yield, n)
			EventBus.notify.emit("Harvest: +%d %s" % [n - left, ItemCatalog.item_name(def.yield)])
			data["planted"] = Farming.NOT_PLANTED
			data.erase("crop")
			player.gain_xp(def.xp)
	stage = _farm_stage()
	_refresh()
	return true


func toggle() -> void:
	if BuildCatalog.TYPES[type].get("door", false):
		is_open = not is_open
		_refresh()


func _refresh() -> void:
	var def: Dictionary = BuildCatalog.TYPES[type]
	_sprite.texture = load(BuildCatalog.texture_path(type, is_open, 0 if is_farm() else stage))
	if is_farm():
		var path := "res://assets/sprites/crops/%s_%d.png" % [crop(), stage]
		_crop_sprite.texture = load(path) if stage > 0 and ResourceLoader.exists(path) else null
	_collision.set_deferred("disabled", not def.solid or is_open)
