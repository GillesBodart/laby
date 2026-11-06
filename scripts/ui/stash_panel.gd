extends PanelContainer
## Stash chest panel (G near a chest). 1 = deposit materials, 2 = withdraw all.
## Tools and placeable items are kept in the backpack when depositing.

const REACH := 40.0

var _label := Label.new()


func _ready() -> void:
	add_to_group("ui_panels")
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.94)
	style.set_border_width_all(1)
	style.border_color = Color(0.62, 0.55, 0.4)
	style.set_content_margin_all(5)
	add_theme_stylebox_override("panel", style)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.78))
	add_child(_label)
	position = Vector2(150, 12)


func _player() -> Player:
	return GameState.players.get(GameState.local_peer_id())


func near_chest() -> bool:
	var player := _player()
	if player == null:
		return false
	for c in get_tree().get_nodes_in_group("chest"):
		if c.global_position.distance_to(player.global_position) <= REACH:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("stash"):
		if visible:
			visible = false
		elif near_chest():
			for p in get_tree().get_nodes_in_group("ui_panels"):
				if p != self:
					p.visible = false
			visible = true
			_refresh()
		else:
			EventBus.notify.emit("Stand next to a chest to open the Stash.")
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_1:
			deposit()
		elif event.physical_keycode == KEY_2:
			withdraw()


func deposit() -> int:
	var player := _player()
	if player == null:
		return 0
	var moved := 0
	for s in player.inventory.slots.duplicate(true):
		if s.is_empty() or ItemCatalog.tool_of(s.id) != "" or BuildCatalog.is_placeable(s.id):
			continue
		var rest := GameState.stash.add(s.id, s.count)
		var taken: int = s.count - rest
		if taken > 0:
			player.inventory.remove(s.id, taken)
			moved += taken
	_refresh()
	return moved


func withdraw() -> int:
	var player := _player()
	if player == null:
		return 0
	var moved := 0
	for s in GameState.stash.slots.duplicate(true):
		if s.is_empty():
			continue
		var rest := player.inventory.add(s.id, s.count)
		var taken: int = s.count - rest
		if taken > 0:
			GameState.stash.remove(s.id, taken)
			moved += taken
	_refresh()
	return moved


func _refresh() -> void:
	var lines: Array[String] = ["STASH  (safe on death)"]
	var row := ""
	var n := 0
	for s in GameState.stash.slots:
		if s.is_empty():
			continue
		row += "%s x%d   " % [ItemCatalog.item_name(s.id), s.count]
		n += 1
		if n % 3 == 0:
			lines.append(row)
			row = ""
	if row != "":
		lines.append(row)
	if n == 0:
		lines.append("(empty)")
	lines.append("")
	lines.append("1 Deposit materials   2 Withdraw all")
	_label.text = "\n".join(lines)
