class_name Structure
extends StaticBody2D
## A player-built tile structure (wall, floor, door, chest, crafting station).

var type := ""
var cell := Vector2i.ZERO
var is_open := false
var stage := 0
## Part of a generated area (sector waystones), not a player build.
var fixed := false

var _sprite := Sprite2D.new()
## Crop growing on a farm plot (drawn over the soil).
var _crop_sprite := Sprite2D.new()
var _collision := CollisionShape2D.new()
var _light: PointLight2D
var _time := 0.0


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
	if not fixed:
		add_to_group("structures")
	if def.group != "":
		add_to_group(def.group)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	_collision.shape = shape
	add_child(_collision)
	_add_contact_shadow(def)
	add_child(_sprite)
	if is_farm():
		add_child(_crop_sprite)
	if type in ["well", "waystone", "skill_altar", "bed"] or def.get("door", false):
		add_to_group("interactable")
	if def.has("light"):
		_light = PointLight2D.new()
		_light.texture = preload("res://resources/lights/light_banded.tres")
		_light.color = Color(1, 0.72, 0.42)
		_light.texture_scale = 2.6 * def.light
		_light.position = Vector2(0, -20)
		add_child(_light)
	_refresh()


func is_farm() -> bool:
	return type == "farm_plot"


static var _wall_shadow: ImageTexture

## Grounds the structure: walls and doors cast a short banded shadow onto the
## tile below them (hidden under the next wall of a vertical run), furniture
## sits on a soft oval.
func _add_contact_shadow(def: Dictionary) -> void:
	if def.layer != "entity":
		return
	var shadow := Sprite2D.new()
	if type.ends_with("_wall") or def.get("door", false):
		if _wall_shadow == null:
			var img := Image.create(32, 8, false, Image.FORMAT_RGBA8)
			for y in 8:
				for x in 32:
					var a := 0.3 if y < 3 else (0.15 if y < 6 else (0.15 if (x + y) % 2 == 0 else 0.0))
					img.set_pixel(x, y, Color(0.02, 0.02, 0.06, a))
			_wall_shadow = ImageTexture.create_from_image(img)
		shadow.texture = _wall_shadow
		shadow.position = Vector2(0, 20)
	else:
		shadow.texture = preload("res://assets/sprites/effects/shadow.png")
		shadow.position = Vector2(0, 13)
	add_child(shadow)


func _process(delta: float) -> void:
	if _light:
		_time += delta
		_light.energy = LightingCurve.darkness_at(TimeSystem.minute_of_day()) * (1.0 + 0.08 * sin(_time * 11.0))
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


func interact_hint() -> String:
	match type:
		"well":
			return "Drink / fill waterskins"
		"skill_altar":
			return "Skill Altar: skills / respec"
		"bed":
			return "Sleep until morning"
	if BuildCatalog.TYPES[type].get("door", false):
		return "Close door" if is_open else "Open door"
	return "Waystone: travel"


func interact(player: Player) -> void:
	if BuildCatalog.TYPES[type].get("door", false):
		use_door()
	elif type == "bed":
		player.try_sleep(cell)
	elif type == "well":
		player.drink_at_source()
	elif type == "skill_altar":
		if player.input.is_local():
			EventBus.altar_used.emit(self)
	elif player.input.is_local():
		EventBus.waystone_used.emit(self)


## E on a door: opens or closes it (kept in GameState). A door will not shut
## on a survivor standing in the doorway.
func use_door() -> bool:
	if is_open:
		for p in GameState.players.values():
			if is_instance_valid(p) and p.cell() == cell:
				EventBus.notify.emit("Step out of the doorway to close the door")
				return false
	var world := get_tree().get_first_node_in_group("clearing_world") as ClearingWorld
	if world:
		world.toggle_structure(cell)
	else:
		toggle()
	Sound.play("door", global_position)
	return true


func toggle() -> void:
	if BuildCatalog.TYPES[type].get("door", false):
		is_open = not is_open
		_refresh()


## Redraws after a neighbour changed (walls join the walls above and below).
func refresh_look() -> void:
	_refresh()


func _wall_join() -> String:
	if fixed or not BuildCatalog.is_wall(type):
		return ""
	var up: Dictionary = GameState.structures.get(cell + Vector2i.UP, {})
	var down: Dictionary = GameState.structures.get(cell + Vector2i.DOWN, {})
	return BuildCatalog.wall_join(BuildCatalog.is_wall(up.get("type", "")), BuildCatalog.is_wall(down.get("type", "")))


func _refresh() -> void:
	var def: Dictionary = BuildCatalog.TYPES[type]
	_sprite.texture = load(BuildCatalog.texture_path(type, is_open, 0 if is_farm() else stage, _wall_join()))
	if is_farm():
		var path := "res://assets/sprites/environment/crops/%s_%d.png" % [crop(), stage]
		_crop_sprite.texture = load(path) if stage > 0 and ResourceLoader.exists(path) else null
	_collision.set_deferred("disabled", not def.solid or is_open)


# ------------------------------------------------------------- raids

## Best struct_hp bonus among the survivors who built the camp.
static func toughness_bonus() -> float:
	var best := 0.0
	for p in GameState.players.values():
		if is_instance_valid(p):
			best = maxf(best, p.survival.bonus("struct_hp"))
	return best


func max_hp() -> int:
	return BuildCatalog.max_hp(type, toughness_bonus())


func hp() -> int:
	return int(GameState.structures.get(cell, {}).get("hp", max_hp()))


func is_damaged() -> bool:
	return not fixed and max_hp() > 0 and hp() < max_hp()


## Raider blow. At 0 hp the structure is wrecked (removed, nothing refunded).
func damage(amount: int) -> void:
	if fixed or max_hp() == 0 or not GameState.structures.has(cell):
		return
	var left := hp() - amount
	GameState.structures[cell]["hp"] = left
	HitChips.burst(get_parent(), global_position, [Color8(150, 110, 70), Color8(110, 100, 90)], 5)
	Sound.play("hit", global_position)
	if left <= 0:
		EventBus.notify.emit("Raiders wrecked your %s!" % ItemCatalog.item_name(type))
		var world := get_tree().get_first_node_in_group("clearing_world") as ClearingWorld
		if world:
			world.remove_structure(cell)
		return
	queue_redraw()


## Restores up to `amount` hp; returns how much was mended.
func mend(amount: int) -> int:
	if not is_damaged():
		return 0
	var add := mini(amount, max_hp() - hp())
	GameState.structures[cell]["hp"] = hp() + add
	if hp() >= max_hp():
		GameState.structures[cell].erase("hp")
	queue_redraw()
	return add


func _draw() -> void:
	if not is_damaged():
		return
	var r := Rect2(-12, -21, 24, 3)
	draw_rect(r, Color8(27, 20, 16))
	draw_rect(Rect2(r.position + Vector2.ONE, Vector2((r.size.x - 2) * hp() / float(max_hp()), 1)), Color8(214, 160, 70))