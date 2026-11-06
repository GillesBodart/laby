extends TestCase

const TEST_SLOT := 99


class FakePersist:
	extends Node
	var value := 0

	func get_save_key() -> String:
		return "fake"

	func get_save_data() -> Dictionary:
		return {"value": value}

	func load_save_data(data: Dictionary) -> void:
		value = int(data.value)


func test_collect_and_apply_round_trip() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var node := FakePersist.new()
	node.value = 42
	node.add_to_group("persist")
	tree.root.add_child(node)

	var data: Dictionary = JSON.parse_string(JSON.stringify(SaveSystem.collect()))
	check_eq(int(data.seed), GameState.world_seed, "seed saved")
	check(data.nodes.has("fake"), "persist node saved")

	node.value = 0
	SaveSystem.apply_to_tree(data)
	check_eq(node.value, 42, "persist node restored")
	node.free()


func test_save_writes_file() -> void:
	check_eq(SaveSystem.save_game(TEST_SLOT), OK, "save ok")
	check(SaveSystem.has_save(TEST_SLOT), "file exists")
	DirAccess.remove_absolute(SaveSystem.slot_path(TEST_SLOT))
