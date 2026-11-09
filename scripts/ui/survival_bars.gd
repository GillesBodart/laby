extends Control
## HUD block with health, hunger, thirst, stamina, temperature and XP bars (480x270 UI space).

const PANEL := Rect2(4, 22, 112, 62)
const BAR_X := 28.0
const BAR_W := 80.0
const BAR_H := 7.0
const INK := Color8(27, 20, 16)
const BG := Color(0.08, 0.08, 0.12, 0.88)
const EDGE := Color(0.62, 0.55, 0.4, 1)
const TEXT := Color8(238, 226, 196)

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	position = Vector2.ZERO
	size = Vector2(480, 270)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var player := GameState.players.get(GameState.local_peer_id()) as Player
	if player == null:
		return
	var s := player.survival
	var rows := [
		["HP", s.health / s.max_health(), Color8(206, 62, 62)],
		["FD", s.hunger / Survival.MAX_HUNGER, Color8(150, 40, 40) if s.is_starving() else Color8(226, 152, 58)],
	]
	if s.thirst_enabled:
		rows.append(["WT", s.thirst / Survival.MAX_THIRST, Color8(150, 40, 40) if s.is_dehydrated() else Color8(70, 150, 220)])
	rows.append(["EN", s.stamina / Survival.MAX_STAMINA, Color8(104, 184, 84)])
	var climate := Sectors.climate_of(GameState.area)
	var show_temp := climate != 0 or absf(s.temperature) > 1.0
	var panel := Rect2(PANEL.position, Vector2(PANEL.size.x, 6.0 + (rows.size() + 1 + (1 if show_temp else 0)) * 14.0))
	draw_rect(panel, BG)
	draw_rect(panel, EDGE, false)
	var y := panel.position.y + 4.0
	for r in rows:
		draw_string(_font, Vector2(panel.position.x + 4, y + 9), r[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)
		_bar(Vector2(panel.position.x + BAR_X, y + 2), r[1], r[2])
		y += 14.0
	if show_temp:
		draw_string(_font, Vector2(panel.position.x + 4, y + 9), "TP", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)
		_temp_bar(Vector2(panel.position.x + BAR_X, y + 2), s.temperature)
		y += 14.0
	draw_string(_font, Vector2(panel.position.x + 4, y + 9), "Lv%d" % s.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)
	_bar(Vector2(panel.position.x + BAR_X, y + 2), float(s.xp) / Survival.xp_for_level(s.level), Color8(118, 150, 230))
	_draw_prompt(player)


## Centred gauge: blue fills left when cold, orange fills right when hot.
func _temp_bar(pos: Vector2, t: float) -> void:
	draw_rect(Rect2(pos, Vector2(BAR_W, BAR_H)), INK)
	var mid := pos.x + BAR_W / 2.0
	var w := floorf((BAR_W / 2.0 - 1.0) * clampf(absf(t) / 100.0, 0.0, 1.0))
	var col := Color8(240, 120, 50) if t > 0.0 else Color8(110, 180, 250)
	if absf(t) >= Survival.TEMP_HARM and int(Time.get_ticks_msec() / 250) % 2 == 0:
		col = Color8(250, 250, 250)
	if w > 0.0:
		var x := mid if t > 0.0 else mid - w
		draw_rect(Rect2(Vector2(x, pos.y + 1), Vector2(w, BAR_H - 2.0)), col)
	draw_rect(Rect2(Vector2(mid, pos.y), Vector2(1, BAR_H)), TEXT)

## "[E] Recover your remains" above the notices when something usable is in reach.
func _draw_prompt(player: Player) -> void:
	for p in get_tree().get_nodes_in_group("ui_panels"):
		if p.visible:
			return
	var thing := player.find_interactable()
	if thing == null or not thing.has_method("interact_hint"):
		return
	var text := "[%s] %s" % [Gamepad.prompt("interact"), thing.interact_hint()]
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10.0
	var r := Rect2(240.0 - w / 2.0, 222, w, 15)
	draw_rect(r, BG)
	draw_rect(r, EDGE, false)
	draw_string(_font, Vector2(r.position.x + 5, r.position.y + 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)


func _bar(pos: Vector2, fraction: float, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(BAR_W, BAR_H)), INK)
	var w := floorf((BAR_W - 2.0) * clampf(fraction, 0.0, 1.0))
	if w > 0.0:
		draw_rect(Rect2(pos + Vector2(1, 1), Vector2(w, BAR_H - 2.0)), color)
		draw_rect(Rect2(pos + Vector2(1, 1), Vector2(w, 1)), color.lightened(0.3))
