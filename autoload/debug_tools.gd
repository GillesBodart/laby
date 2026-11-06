extends Node
## Developer helpers.
## - F3: toggle fast time (x30).
## - Command line (after `--`):
##     --seed=<int>             force world seed
##     --time=HH:MM             start at a given time of day
##     --at=<x>,<y>             teleport the local player to a tile cell
##     --area=<name>            start in an area (clearing, labyrinth)
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
	if _args.has("give"):
		_give.call_deferred()
	if _args.has("screenshot"):
		_capture.call_deferred(_args.screenshot, int(_args.get("screenshot-frames", "30")))


## --give: fills the backpack with sample items; with --panel also opens it.
func _give() -> void:
	await get_tree().create_timer(0.3).timeout
	var p: Player = GameState.players.get(GameState.local_peer_id())
	if p == null:
		return
	for id in ["wood", "stone", "plank", "stick", "stone_axe", "workbench"]:
		p.inventory.add(id, 1 if ItemCatalog.tool_of(id) != "" else 7)
	if _args.has("panel"):
		var ev := InputEventAction.new()
		ev.action = "inventory"
		ev.pressed = true
		Input.parse_input_event(ev)


func _teleport_local_player(cell_text: String) -> void:
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
