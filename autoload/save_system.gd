extends Node
## JSON save/load. Nodes in the "persist" group provide
## get_save_key() / get_save_data() / load_save_data(data).

const SAVE_VERSION := 1
const SAVE_DIR := "user://saves"
## Slot 0 is the quick save (F5/F9); the settings menu offers all of them.
const SLOTS := 3


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		if save_game() == OK:
			EventBus.notify.emit("Game saved.")
	elif event.is_action_pressed("quick_load"):
		if not load_game():
			EventBus.notify.emit("No save found.")


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func collect() -> Dictionary:
	var nodes := {}
	for node in get_tree().get_nodes_in_group("persist"):
		nodes[node.get_save_key()] = node.get_save_data()
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"seed": GameState.world_seed,
		"area": GameState.area,
		"stash": GameState.stash.to_data(),
		"fog": GameState.fog_to_data(),
		"time": TimeSystem.get_save_data(),
		"nodes": nodes,
	}


func save_game(slot: int = 0) -> Error:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write save: %s" % FileAccess.get_open_error())
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(collect(), "\t"))
	return OK


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Short description of a slot for menus ("" = empty or unreadable).
func slot_summary(slot: int) -> String:
	if not has_save(slot):
		return ""
	var data = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	var minutes := float(data.get("time", {}).get("total_minutes", 0.0))
	var clock := DayClock.new()
	clock.total_minutes = minutes
	var area := String(data.get("area", "clearing")).capitalize()
	return "Day %d  %s  %s" % [clock.day(), area, String(data.get("saved_at", "")).substr(0, 16)]

## Loads the save and rebuilds the world from its seed; node data is applied
## by the world scene once it is ready (see apply_to_tree).
func load_game(slot: int = 0) -> bool:
	if not has_save(slot):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != SAVE_VERSION:
		push_error("Invalid or incompatible save file.")
		return false
	GameState.world_seed = int(data.seed)
	GameState.area = String(data.get("area", "clearing"))
	GameState.arriving = false
	GameState.depleted_cells = {}
	GameState.structures = {}
	GameState.stash.load_data(data.get("stash", []))
	GameState.fog_from_data(data.get("fog", {}))
	GameState.pending_save = data
	TimeSystem.load_save_data(data.time)
	get_tree().change_scene_to_file(GameState.area_scene())
	return true


func apply_to_tree(data: Dictionary) -> void:
	var nodes: Dictionary = data.get("nodes", {})
	for node in get_tree().get_nodes_in_group("persist"):
		var key: String = node.get_save_key()
		if nodes.has(key):
			node.load_save_data(nodes[key])
