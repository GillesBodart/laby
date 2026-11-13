extends Node
## Developer helpers.
## - F3: toggle fast time (x30), debug builds only.
## - Command line (after `--`); any flag except --title skips the title screen:
##     --title[=new]            stay on the title screen (=new: its New game page)
##     --seed=<int>             force world seed
##     --time=HH:MM             start at a given time of day
##     --at=<x>,<y>             teleport the local player to a tile cell
##     --area=<name>            start in an area (clearing or a sector id, see Sectors)
##     --skills                 open the skill screen with 3 points
##     --map                    open the map overlay
##     --explore                reveal the sector, read its glyphs, sample markers,
##                              journal entries and a wall shift
##     --journal                open the journal
##     --raid                   a walled Shelters camp under a night raid
##     --settlement[=camp]      a five-survivor camp, settlement panel open (unless camp)
##     --house                  a floored hut (wall runs, chest and bed on the floor)
##     --menu=<page>            open the Esc menu (main, save, load, controls, sound)
##     --give [--panel] [--sort] sample items (open the backpack, sort it)
##     --station=<group>        with --give: open that station's recipe book
##     --spawn=<id>,<id>...     place creatures in a ring around the player
##     --swing=<dir>[,<item>[,<sec>]]  swing a tool facing up/down/left/right;
##                              with <sec>, freeze the pose that many seconds in
##     --equip=<id>,<id>...     give and equip items (e.g. torch)
##     --tame=<id>,<id>...      tamed companions at the player's side
##     --die                    die with a full pack, then stand at the remains
##     --permadeath             one-life run rules (with --die: the run ends)
##     --epilogue               show the escape epilogue in the Clearing
##     --screenshot=<path.png>  capture the screen after a few frames and quit
##     --screenshot-frames=<n>  frames to wait before capturing (default 30)

const FAST_TIME_SCALE := 30.0

var _args := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else ""
	if _args.has("seed"):
		GameState.new_game(int(_args.seed))
	if _args.has("permadeath"):
		GameState.permadeath = true
		GameState.companion_permadeath = true
	if _args.get("title", "") == "new":
		_title_page.call_deferred()
	if _args.has("area") and GameState.AREA_SCENES.has(_args.area):
		GameState.area = _args.area
		get_tree().change_scene_to_file.call_deferred(GameState.area_scene())
	elif not _args.is_empty() and not _args.has("title"):
		_skip_title.call_deferred()
	if _args.has("time"):
		var hm: PackedStringArray = _args.time.split(":")
		TimeSystem.set_time_of_day.call_deferred(int(hm[0]) * 60 + (int(hm[1]) if hm.size() > 1 else 0))
	if _args.has("at"):
		_teleport_local_player.call_deferred(_args.at)
	if _args.has("explore"):
		_explore.call_deferred()
	if _args.has("journal"):
		_press_action.call_deferred("journal")
	if _args.has("raid"):
		_raid.call_deferred()
	if _args.has("settlement"):
		_settlement.call_deferred()
	if _args.has("house"):
		_house.call_deferred()
	if _args.has("map"):
		_press_map.call_deferred()
	if _args.has("menu"):
		_open_menu.call_deferred(_args.menu)
	if _args.has("skills"):
		_press_skills.call_deferred()
	if _args.has("give"):
		_give.call_deferred()
	if _args.has("spawn"):
		_spawn.call_deferred(_args.spawn)
	if _args.has("farm"):
		_farm.call_deferred(_args.farm)
	if _args.has("equip"):
		_equip.call_deferred(_args.equip)
	if _args.has("tame"):
		_tame.call_deferred(_args.tame)
	if _args.has("epilogue"):
		GameState.epilogue_pending = true
	if _args.has("die"):
		_die.call_deferred()
	if _args.has("swing"):
		_swing_loop.call_deferred(_args.swing)
	if _args.has("screenshot"):
		_capture.call_deferred(_args.screenshot, int(_args.get("screenshot-frames", "30")))


## --give: fills the backpack with sample items; with --panel also opens it,
## with --chest places a chest holding a few stacks and opens it.
func _give() -> void:
	await get_tree().create_timer(0.3).timeout
	var p: Player = GameState.players.get(GameState.local_peer_id())
	if p == null:
		return
	for id in ["wood", "stone", "plank", "stick", "fiber", "coal", "copper_ore", "copper_ingot", "iron_ingot", "clay", "stone_axe", "workbench", "furnace", "berry", "iron_helm", "copper_ring", "leather_boots", "anvil", "cooking_pot", "tanning_rack", "stonecutter", "mushroom", "raw_meat", "short_bow", "flint_arrow", "healing_potion", "wooden_shield", "loom", "alchemy_table"]:
		p.inventory.add(id, mini(ItemCatalog.stack_size(id), 7))
	for id in ["iron_sword", "copper_armor", "bone_charm", "iron_shield"]:
		p.inventory.add(id, 1)
		p.equipment.equip(p.inventory, id)
	# Some wear, to show the durability bars.
	p.equipment.wear_out("weapon", ItemCatalog.durability_of("iron_sword") / 3)
	p.inventory.wear_slot(p.inventory.find_last("stone_axe"), ItemCatalog.durability_of("stone_axe") * 4 / 5)
	if _args.has("sort"):
		p.inventory.sort()
	if _args.has("chest"):
		for id in ["stone", "wood", "coal", "berry", "wheat", "bone"]:
			if ItemCatalog.ITEMS.has(id):
				GameState.stash.add(id, 12)
		var clearing := get_tree().current_scene.get_node_or_null("Clearing") as ClearingWorld
		if clearing:
			clearing.place_structure(clearing.walls.local_to_map(clearing.walls.to_local(p.global_position)) + Vector2i(1, 0), "chest")
		EventBus.chest_used.emit()
	elif _args.has("station"):
		EventBus.station_used.emit(_args.station)
	elif _args.has("panel"):
		var ev := InputEventAction.new()
		ev.action = "inventory"
		ev.pressed = true
		Input.parse_input_event(ev)


## --farm=<crop,...>: an empty plot right of the player whose seed picker opens,
## then plots with ripe crops (seeds for every crop are given).
func _farm(list: String) -> void:
	await get_tree().create_timer(0.4).timeout
	var p: Player = GameState.players.get(GameState.local_peer_id())
	var clearing := get_tree().current_scene.get_node_or_null("Clearing") as ClearingWorld
	if p == null or clearing == null:
		return
	for id in Farming.CROPS:
		p.inventory.add(Farming.CROPS[id].seed, 3)
	var base := clearing.walls.local_to_map(clearing.walls.to_local(p.global_position))
	var crops := Array(list.split(",", false)).filter(func(c): return Farming.CROPS.has(c))
	crops.push_front("")
	TimeSystem.clock.total_minutes += 1440.0 * 3
	for i in crops.size():
		var cell := base + Vector2i(1 + i, 0)
		if not clearing.place_structure(cell, "farm_plot"):
			continue
		if crops[i] != "":
			GameState.structures[cell].planted = TimeSystem.clock.total_minutes - Farming.grow_minutes(crops[i])
			GameState.structures[cell].crop = crops[i]
		elif not _args.has("panel"):
			for s in get_tree().get_nodes_in_group("farm_plot"):
				if s.cell == cell:
					s.farm_interact(p)


func _equip(list: String) -> void:
	await get_tree().create_timer(0.3).timeout
	var p: Player = GameState.players.get(GameState.local_peer_id())
	if p == null:
		return
	for id in list.split(",", false):
		if ItemCatalog.ITEMS.has(id):
			p.inventory.add(id, 1)
			p.equipment.equip(p.inventory, id)


## --tame: companions of the given species join the local player.
func _tame(list: String) -> void:
	await get_tree().create_timer(0.3).timeout
	var p: Player = GameState.players.get(GameState.local_peer_id())
	if p == null:
		return
	var i := 0
	for id in list.split(",", false):
		if EnemyCatalog.has(id):
			var rec := GameState.add_companion(id, p.peer_id)
			Companion.spawn(p.get_parent(), rec, p, p.global_position + Vector2(-20 + 40 * i, 14))
			i += 1


## --die: the player falls with a full pack, then faces the remains.
func _title_page() -> void:
	var menu := get_tree().get_first_node_in_group("title_menu")
	if menu != null:
		menu.activate(0)
		menu.activate(1)
		menu.set("_hover", 1)


func _die() -> void:
	await get_tree().create_timer(0.4).timeout
	var p: Player = GameState.players.get(GameState.local_peer_id())
	if p == null:
		return
	for id in ["wood", "stone", "berry", "fiber", "stone_axe"]:
		p.inventory.add(id, 5)
	p.global_position += Vector2(48, 0)
	p.survival.damage(9999.0)
	await get_tree().create_timer(0.3).timeout
	var piles := get_tree().get_nodes_in_group("remains")
	if not piles.is_empty():
		p.global_position = piles[0].global_position + Vector2(0, 30)
		p.facing = Vector2.UP


## --swing: repeats the tool swing (for checking the animation in screenshots).
func _swing_loop(spec: String) -> void:
	var parts := spec.split(",")
	var dirs := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
	var item := parts[1] if parts.size() > 1 else "iron_pickaxe"
	while is_inside_tree():
		await get_tree().create_timer(0.1).timeout
		var p: Player = GameState.players.get(GameState.local_peer_id())
		if p != null:
			p.facing = dirs.get(parts[0], Vector2.DOWN)
			p.swing(item)
			if parts.size() > 2:
				p._swing.pause()
				p._swing.custom_step(float(parts[2]))
				return
			await get_tree().create_timer(0.35).timeout


## --spawn: creatures in a ring 70px around the local player.
func _spawn(list: String) -> void:
	await get_tree().create_timer(0.5).timeout
	var p: Player = GameState.players.get(GameState.local_peer_id())
	if p == null:
		return
	var ids := Array(list.split(",", false)).filter(func(id): return EnemyCatalog.has(id))
	for i in ids.size():
		var e: Enemy = preload("res://scenes/entities/enemy.tscn").instantiate()
		e.setup(ids[i])
		e.position = p.position + Vector2.RIGHT.rotated(TAU * i / ids.size()) * 70.0
		p.get_parent().add_child(e)


func _open_menu(page: String) -> void:
	await get_tree().create_timer(0.4).timeout
	var menu := get_tree().get_first_node_in_group("settings_menu")
	if menu:
		menu.open(page if page != "" else "main")


## Any dev flag starts straight in the world (from the title screen only, so
## other entry scenes such as the test runner are left alone).
func _skip_title() -> void:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == MainMenu.SCENE:
		get_tree().change_scene_to_file(GameState.area_scene())


## The World scene once it is current (past the title screen); null if it
## never shows up.
func _await_world() -> World:
	for i in 30:
		var world := get_tree().current_scene as World
		if world and world.is_node_ready():
			return world
		await get_tree().process_frame
	return null


## --map: opens the map overlay after the world is built.
func _press_map() -> void:
	await get_tree().create_timer(0.8).timeout
	var ev := InputEventAction.new()
	ev.action = "map"
	ev.pressed = true
	Input.parse_input_event(ev)


func _press_action(action: String) -> void:
	await get_tree().create_timer(0.8).timeout
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


## --raid: walls, beds and a guard, then raiders arrive.
func _raid() -> void:
	var world := await _await_world()
	if world == null:
		return
	var fire := world.layout.campfire_cell
	for x in range(-3, 4):
		world.clearing.place_structure(fire + Vector2i(x, 4), "wooden_wall")
	world.clearing.place_structure(fire + Vector2i(3, -2), "bed")
	world.clearing.place_structure(fire + Vector2i(4, -2), "bed")
	world.clearing.place_structure(fire + Vector2i(5, -2), "workbench")
	world.clearing.place_structure(fire + Vector2i(-2, -2), "standing_torch")
	GameState.survivors.append({"cast": 5, "role": "guard"})
	EventBus.settlement_changed.emit()
	world.start_raid(4)
	for e in get_tree().get_nodes_in_group("raiders"):
		e.global_position = ClearingWorld.cell_center(fire) + Vector2(randf_range(-140, 140), randf_range(-90, -40))


## --house: a floored hut right of the campfire, one wall material per side,
## with a chest and a bed on the floor (checks wall joins and floor building).
func _house() -> void:
	var world := await _await_world()
	if world == null:
		return
	var o := world.layout.campfire_cell + Vector2i(2, -3)
	# Clear the trees and rocks in the way so the hut closes into a room.
	for node in get_tree().get_nodes_in_group("gatherable"):
		if node is Gatherable and Rect2i(o, Vector2i(6, 6)).has_point(node.cell):
			GameState.depleted_cells[node.cell] = true
			node.free()
	for y in range(0, 6):
		for x in range(0, 6):
			var cell := o + Vector2i(x, y)
			var edge := x == 0 or x == 5 or y == 0 or y == 5
			world.clearing.place_structure(cell, "stone_floor" if x < 3 else "wooden_floor")
			if not edge:
				continue
			var wall := "wooden_wall" if x == 5 else ("brick_wall" if x == 0 else "stone_wall")
			if y == 5 and x == 2:
				wall = "wooden_door"
			world.clearing.place_structure(cell, wall)
	world.clearing.place_structure(o + Vector2i(1, 1), "chest")
	world.clearing.place_structure(o + Vector2i(4, 1), "bed")
	world.clearing.place_structure(o + Vector2i(4, 3), "chest")


## --settlement: a lived-in camp with its panel open.
func _settlement() -> void:
	await _await_world()
	GameState.survivors.clear()
	for i in 5:
		GameState.survivors.append({"cast": i, "role": Settlement.CAST[i].role})
	EventBus.settlement_changed.emit()
	if _args.get("settlement") != "camp":
		EventBus.survivor_talked.emit(null)


## --explore: a well-travelled sector for map and journal screenshots.
func _explore() -> void:
	await get_tree().create_timer(0.4).timeout
	var world := get_tree().current_scene as World
	if world == null or world.fog == null:
		return
	for y in world.layout.size.y:
		for x in world.layout.size.x:
			world.fog.reveal(Vector2i(x, y), 0)
	for i in LabyrinthGenerator.GLYPH_COUNT:
		GameState.log_journal("glyphs", "%s_%d" % [GameState.area, i])
	for m in world.layout.landmarks:
		GameState.log_journal("places", m.type)
	for e in world.layout.enemy_spawns.slice(0, 6):
		GameState.log_journal("creatures", e.type, 2)
	for p in world.layout.props.slice(0, 12):
		GameState.log_journal("resources", String(ResourceCatalog.NODES.get(p.type, {}).get("item", "stone")))
	var cell := world.layout.return_cell
	GameState.add_marker(GameState.area, "danger", cell + Vector2i(-8, -20))
	GameState.add_marker(GameState.area, "resource", cell + Vector2i(12, -30))
	GameState.add_marker(GameState.area, "door", cell + Vector2i(0, -50))
	if world.has_method("apply_shift"):
		world.apply_shift(1)


## --skills: grants 3 skill points and opens the skill screen.
func _press_skills() -> void:
	await get_tree().create_timer(0.8).timeout
	var p: Player = GameState.players.get(GameState.local_peer_id())
	if p:
		p.survival.skill_points += 3
		p.survival.learn("might")
	var ev := InputEventAction.new()
	ev.action = "skills"
	ev.pressed = true
	Input.parse_input_event(ev)


func _teleport_local_player(cell_text: String) -> void:
	for i in 5:
		await get_tree().process_frame
	var player = GameState.players.get(GameState.local_peer_id())
	if player:
		var xy := cell_text.split(",")
		player.global_position = ClearingWorld.cell_center(Vector2i(int(xy[0]), int(xy[1])))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_fast_time") and OS.is_debug_build():
		TimeSystem.time_scale = 1.0 if TimeSystem.time_scale > 1.0 else FAST_TIME_SCALE
		EventBus.notify.emit("Time x%d" % int(TimeSystem.time_scale))


func _capture(path: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Screenshot saved: ", path)
	get_tree().quit()
