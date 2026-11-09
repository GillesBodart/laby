extends Node
## Developer helpers.
## - F3: toggle fast time (x30).
## - Command line (after `--`):
##     --seed=<int>             force world seed
##     --time=HH:MM             start at a given time of day
##     --at=<x>,<y>             teleport the local player to a tile cell
##     --area=<name>            start in an area (clearing or a sector id, see Sectors)
##     --skills                 open the skill screen with 3 points
##     --map                    open the map overlay
##     --menu=<page>            open the Esc menu (main, save, load, controls)
##     --give [--panel] [--sort] sample items (open the backpack, sort it)
##     --station=<group>        with --give: open that station's recipe book
##     --spawn=<id>,<id>...     place creatures in a ring around the player
##     --swing=<dir>[,<item>[,<sec>]]  swing a tool facing up/down/left/right;
##                              with <sec>, freeze the pose that many seconds in
##     --die                    die with a full pack, then stand at the remains
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
	if _args.has("area") and GameState.AREA_SCENES.has(_args.area):
		GameState.area = _args.area
		get_tree().change_scene_to_file.call_deferred(GameState.area_scene())
	if _args.has("time"):
		var hm: PackedStringArray = _args.time.split(":")
		TimeSystem.set_time_of_day.call_deferred(int(hm[0]) * 60 + (int(hm[1]) if hm.size() > 1 else 0))
	if _args.has("at"):
		_teleport_local_player.call_deferred(_args.at)
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


## --die: the player falls with a full pack, then faces the remains.
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
		var e: Enemy = preload("res://scenes/world/props/enemy.tscn").instantiate()
		e.setup(ids[i])
		e.position = p.position + Vector2.RIGHT.rotated(TAU * i / ids.size()) * 70.0
		p.get_parent().add_child(e)


func _open_menu(page: String) -> void:
	await get_tree().create_timer(0.4).timeout
	var menu := get_tree().get_first_node_in_group("settings_menu")
	if menu:
		menu.open(page if page != "" else "main")


## --map: opens the map overlay after the world is built.
func _press_map() -> void:
	await get_tree().create_timer(0.8).timeout
	var ev := InputEventAction.new()
	ev.action = "map"
	ev.pressed = true
	Input.parse_input_event(ev)


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
	if event.is_action_pressed("debug_fast_time"):
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
