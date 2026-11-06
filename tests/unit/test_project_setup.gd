extends TestCase


func test_input_actions_exist() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "run", "interact", "quick_save", "quick_load"]:
		check(InputMap.has_action(action), "action %s" % action)
		if InputMap.has_action(action):
			check(not InputMap.action_get_events(action).is_empty(), "action %s has a binding" % action)


func test_pixel_perfect_settings() -> void:
	check_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 960, "viewport width")
	check_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 540, "viewport height")
	check_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "fractional", "fractional scaling")
	check_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0, "nearest filter")


func test_tileset_collision_matches_catalog() -> void:
	var tile_set := TileSetFactory.clearing_tileset()
	var source := tile_set.get_source(TileSetFactory.SOURCE_ID) as TileSetAtlasSource
	for id in TileCatalog.DEFS:
		var data := source.get_tile_data(TileCatalog.atlas_coords(id), 0)
		check(data != null, "tile %d exists" % id)
		if data:
			var has_collision := data.get_collision_polygons_count(0) > 0
			check_eq(has_collision, TileCatalog.is_solid(id), "collision for tile %d" % id)
