class_name Builder
extends Node2D
## Local build mode: B toggles, Q cycles the structure, F places (or toggles a
## door, or repairs raid damage), X removes the targeted structure and refunds its item.

const REACH := 28.0

var player: Player
var active := false
var _index := 0
var _ghost := Sprite2D.new()


func _ready() -> void:
	player = get_parent() as Player
	top_level = true
	_ghost.z_index = 100
	_ghost.visible = false
	add_child(_ghost)


func _world() -> ClearingWorld:
	return get_tree().get_first_node_in_group("clearing_world") as ClearingWorld


func placeable_items() -> Array[String]:
	var list: Array[String] = []
	for s in player.inventory.slots:
		if not s.is_empty() and BuildCatalog.is_placeable(s.id) and not list.has(s.id):
			list.append(s.id)
	return list


func selected_item() -> String:
	var list := placeable_items()
	if list.is_empty():
		return ""
	_index = _index % list.size()
	return list[_index]


func target_cell() -> Vector2i:
	var probe := player.global_position + Vector2(0, -8) + player.facing * REACH
	return Vector2i(floori(probe.x / TileCatalog.TILE_SIZE), floori(probe.y / TileCatalog.TILE_SIZE))


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.input.is_local():
		return
	if event.is_action_pressed("build_toggle"):
		set_active(not active)
	elif not active:
		return
	elif event.is_action_pressed("build_next"):
		_index += 1
		_announce()
	elif event.is_action_pressed("build_place"):
		primary()
	elif event.is_action_pressed("build_remove"):
		remove()


func set_active(on: bool) -> void:
	active = on
	_ghost.visible = on
	if on:
		_announce()
	else:
		EventBus.notify.emit("Build mode off.")


func _announce() -> void:
	var item := selected_item()
	if item == "":
		EventBus.notify.emit("Build mode: nothing to place. Craft walls, floors, a workbench or a chest (Tab).")
	else:
		EventBus.notify.emit("Build: %s  [Q] next  [F] place  [X] remove" % ItemCatalog.item_name(item))


## F: toggle a door under the cursor, otherwise place the selected item.
func primary() -> bool:
	var world := _world()
	if world == null:
		return false
	var cell := target_cell()
	var item := selected_item()
	var existing := world.structure_at(cell)
	if existing and existing.is_damaged():
		return repair(existing)
	if existing and not BuildCatalog.can_stand_on(existing.type, item):
		if BuildCatalog.TYPES[existing.type].get("door", false):
			return existing.use_door()
		Sound.play("ui", existing.global_position)
		return true
	if item == "":
		return false
	var why := world.build_blocker(cell, item)
	if why != "":
		EventBus.notify.emit(why)
		return false
	if not player.inventory.remove(item, 1):
		return false
	Sound.play("build", player.global_position)
	var before := Rooms.buffs_of(Rooms.find(GameState.structures, cell)).size()
	if not world.place_structure(cell, item):
		return false
	_announce_room(cell, item, before)
	return true


## Closing a room, or adding comfort to one, says what the room now gives.
func _announce_room(cell: Vector2i, item: String, buffs_before: int) -> void:
	if Rooms.encloses(item):
		for n in [cell + Vector2i.UP, cell + Vector2i.DOWN, cell + Vector2i.LEFT, cell + Vector2i.RIGHT]:
			var room := Rooms.find(GameState.structures, n)
			if not room.is_empty():
				EventBus.notify.emit("Room closed (%d tiles): %s" % [room.cells.size(), Rooms.describe(room)])
				if Rooms.key(player.current_room()) == Rooms.key(room):
					player._room_key = Rooms.key(room)
				return
		return
	var room := Rooms.find(GameState.structures, cell)
	if Rooms.buffs_of(room).size() > buffs_before:
		EventBus.notify.emit("Room: %s" % Rooms.describe(room))


## F on a damaged structure: one of its main material mends it fully.
func repair(s: Structure) -> bool:
	var item := BuildCatalog.repair_item(s.type)
	if not player.inventory.remove(item, 1):
		EventBus.notify.emit("Repairing needs 1 %s" % ItemCatalog.item_name(item))
		return false
	s.mend(s.max_hp())
	Sound.play("build", s.global_position)
	EventBus.notify.emit("%s repaired" % ItemCatalog.item_name(s.type))
	return true


func remove() -> bool:
	var world := _world()
	if world == null:
		return false
	var cell := target_cell()
	var s := world.structure_at(cell)
	if s == null:
		return false
	if player.inventory.add(s.type, 1) > 0:
		EventBus.notify.emit("Backpack full!")
		return false
	world.remove_structure(cell)
	Sound.play("build", player.global_position)
	return true


func _process(_delta: float) -> void:
	if not active:
		return
	var world := _world()
	var item := selected_item()
	if world == null or item == "":
		_ghost.visible = false
		return
	_ghost.visible = true
	var cell := target_cell()
	_ghost.texture = load(BuildCatalog.texture_path(item))
	_ghost.global_position = ClearingWorld.cell_center(cell)
	var ok := world.build_blocker(cell, item) == ""
	_ghost.modulate = Color(0.6, 1, 0.6, 0.65) if ok else Color(1, 0.45, 0.45, 0.65)
