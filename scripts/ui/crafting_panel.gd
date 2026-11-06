extends PanelContainer
## Inventory + crafting panel (Tab). Press 1-0 to craft the listed recipe.

const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

var _label := Label.new()


func _ready() -> void:
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.94)
	style.set_border_width_all(1)
	style.border_color = Color(0.62, 0.55, 0.4)
	style.set_content_margin_all(5)
	add_theme_stylebox_override("panel", style)
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.78))
	add_child(_label)
	position = Vector2(150, 12)


func _player() -> Player:
	return GameState.players.get(GameState.local_peer_id())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		visible = not visible
		_refresh()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and not event.echo:
		var idx := KEYS.find(event.physical_keycode)
		if idx >= 0 and idx < ItemCatalog.RECIPES.size():
			craft(idx)


func craft(index: int) -> bool:
	var player := _player()
	if player == null:
		return false
	var recipe: Dictionary = ItemCatalog.RECIPES[index]
	var ok := Crafting.craft(player.inventory, recipe, player.nearby_stations())
	var item := ItemCatalog.item_name(recipe.id)
	EventBus.notify.emit(("Crafted %s" % item) if ok else ("Cannot craft %s" % item))
	_refresh()
	return ok


func _refresh() -> void:
	var player := _player()
	if player == null:
		return
	var stations := player.nearby_stations()
	var lines: Array[String] = ["BACKPACK"]
	var row := ""
	var n := 0
	for s in player.inventory.slots:
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
	lines.append("CRAFT  [1-0]")
	for i in ItemCatalog.RECIPES.size():
		var r: Dictionary = ItemCatalog.RECIPES[i]
		var cost := ", ".join(r["in"].keys().map(func(k: String) -> String: return "%d %s" % [r["in"][k], ItemCatalog.item_name(k)]))
		var mark := "*" if Crafting.can_craft(player.inventory, r, stations) else " "
		var at := "" if r.station == "" else " @%s" % r.station
		lines.append("%s%d %s (%s)%s" % [mark, (i + 1) % 10, ItemCatalog.item_name(r.id), cost, at])
	_label.text = "\n".join(lines)
