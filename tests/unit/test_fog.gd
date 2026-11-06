extends TestCase


func test_reveal_marks_cells_once() -> void:
	var fog := FogMap.new(Vector2i(20, 20))
	check(not fog.is_explored(Vector2i(10, 10)), "starts hidden")
	var added := fog.reveal(Vector2i(10, 10), 3)
	check(added > 0, "reveal adds cells")
	check(fog.is_explored(Vector2i(10, 10)), "center explored")
	check(fog.is_explored(Vector2i(13, 10)), "edge within radius explored")
	check(not fog.is_explored(Vector2i(16, 10)), "far cell hidden")
	check_eq(fog.reveal(Vector2i(10, 10), 3), 0, "second reveal adds nothing")


func test_reveal_clips_to_bounds() -> void:
	var fog := FogMap.new(Vector2i(5, 5))
	fog.reveal(Vector2i(0, 0), 4)
	check(fog.is_explored(Vector2i(0, 0)), "corner explored")
	check(not fog.is_explored(Vector2i(-1, 0)), "out of bounds is never explored")


func test_fog_save_round_trip() -> void:
	var fog := FogMap.new(Vector2i(30, 12))
	fog.reveal(Vector2i(8, 6), 4)
	var copy := FogMap.from_data(JSON.parse_string(JSON.stringify(fog.to_data())))
	check_eq(copy.explored_count(), fog.explored_count(), "same explored count")
	check(copy.is_explored(Vector2i(8, 6)), "explored cell kept")


func test_labyrinth_layout_is_fogged() -> void:
	check(LabyrinthGenerator.generate(7).fogged, "labyrinth is fogged")
	check(not ClearingGenerator.generate(7).fogged, "clearing is not fogged")
