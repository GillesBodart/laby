class_name TreasureChest
extends StaticBody2D
## A treasure chest at the end of a labyrinth dead end (see
## LabyrinthGenerator.CHEST_COUNT). Opened once (GameState.opened_chests): it
## teaches the camp one of its sector's blueprints and holds a few gems or
## metals (see Blueprints). What does not fit the backpack is left in a pile.

const XP := 25

var id := ""
var sector := "labyrinth"
var cell: Vector2i
var _sprite := Sprite2D.new()


static func create(chest_id: String, chest_sector: String, at: Vector2i) -> TreasureChest:
	var c := TreasureChest.new()
	c.id = chest_id
	c.sector = chest_sector
	c.cell = at
	return c


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("treasure_chests")
	collision_mask = 0
	position = ClearingWorld.cell_center(cell) + Vector2(0, 12)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 10)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -5)
	add_child(col)
	add_child(_sprite)
	_refresh()


func _refresh() -> void:
	_sprite.texture = load("res://assets/sprites/environment/landmarks/treasure_chest%s.png" % ("_open" if is_open() else ""))
	_sprite.offset = Vector2(0, -_sprite.texture.get_height() / 2.0)


func is_open() -> bool:
	return GameState.opened_chests.has(id)


func can_interact(_player: Node) -> bool:
	return true


func interact_hint() -> String:
	return "Open the old chest" if not is_open() else "Empty chest"


## Seeded per chest and world, so a reload cannot reroll the contents.
func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [GameState.world_seed, id])
	return rng


func interact(player: Node) -> void:
	if is_open():
		EventBus.notify.emit("The chest is empty.")
		return
	GameState.opened_chests[id] = true
	var rng := _rng()
	var bp := Blueprints.pick(sector, GameState.blueprints, rng.randf())
	var lines := PackedStringArray()
	if bp != "":
		GameState.blueprints[bp] = true
		var rec: Dictionary = ItemCatalog.RECIPES[ItemCatalog.RECIPES.find_custom(func(r): return r.id == bp)]
		var at := "by hand" if rec.station == "" else "at the %s" % ItemCatalog.STATIONS[rec.station]
		lines.append("Blueprint found: %s (craft it %s)." % [ItemCatalog.item_name(bp), at])
	var leftover := []
	for stack in Blueprints.loot(sector, rng):
		var left: int = player.inventory.add(stack.id, stack.count) if "inventory" in player else stack.count
		if stack.count - left > 0:
			EventBus.item_feed.emit("pickup", stack.id, stack.count - left)
		if left > 0:
			leftover.append({"id": stack.id, "count": left})
	if not leftover.is_empty():
		var entry := GameState.add_remains(GameState.area, global_position + Vector2(0, 10), leftover)
		entry["dropped"] = true
		var world := get_tree().get_first_node_in_group("clearing_world") as ClearingWorld
		if world != null:
			world.spawn_remains(entry)
		lines.append("Your backpack is full: the rest lies by the chest.")
	if player.has_method("gain_xp"):
		player.gain_xp(XP)
	_refresh()
	Sound.play("glyph", global_position, 0.0)
	HitChips.burst(get_parent(), global_position + Vector2(0, -12), [Color8(250, 214, 96), Color8(200, 150, 60)], 10)
	EventBus.notify.emit(" ".join(lines) if not lines.is_empty() else "The chest holds a few valuables.")
