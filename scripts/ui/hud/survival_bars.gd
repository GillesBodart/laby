extends Control
## HUD block with health, hunger, thirst, stamina, temperature and XP bars,
## plus room comfort and the interaction prompt. Native 960x540 space.

const PANEL_POS := Vector2(8, 36)
const ROW_H := 17.0
const ICON_X := 6.0
const BAR_X := 34.0
const BAR_W := 112.0
const BAR_H := 9.0
const PAD := 5.0
const INK := Color8(16, 12, 14)
const TRACK := Color8(40, 32, 34)
const TEXT := UiFrame.TEXT
const FONT := 16
## Below this share of health the heart bar raises the alarm.
const LOW_HEALTH := 0.25

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.get_project_theme().default_font
	position = Vector2.ZERO
	size = Vector2(960, 540)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var player := GameState.players.get(GameState.local_peer_id()) as Player
	if player == null:
		return
	var s := player.survival
	var hp := s.health / s.max_health()
	# Text size: the panel grows from the screen corner, the prompt from the bottom.
	Accessibility.scale_about(self, Vector2.ZERO)
	# Each row: icon, fill, colour, critical (blinks and gets a "!" badge so
	# the warning never relies on colour alone).
	var rows := [
		["heart", hp, Color8(214, 62, 62), hp < LOW_HEALTH],
		["food", s.hunger / Survival.MAX_HUNGER, Color8(150, 40, 40) if s.is_starving() else Color8(228, 150, 56), s.is_starving()],
	]
	if s.thirst_enabled:
		rows.append(["water", s.thirst / Survival.MAX_THIRST, Color8(150, 40, 40) if s.is_dehydrated() else Color8(72, 152, 226), s.is_dehydrated()])
	rows.append(["stamina", s.stamina / Survival.MAX_STAMINA, Color8(112, 190, 84), false])
	var blink := int(Time.get_ticks_msec() / 300) % 2 == 0
	var climate := Sectors.climate_of(GameState.area)
	var show_temp := climate != 0 or absf(s.temperature) > 1.0
	var count := rows.size() + 1 + (1 if show_temp else 0)
	var panel := Rect2(PANEL_POS, Vector2(BAR_X + BAR_W + 8.0, PAD * 2.0 + count * ROW_H - 3.0))
	UiFrame.panel(self, panel)
	var y := panel.position.y + PAD
	for r in rows:
		UiFrame.icon(self, Vector2(panel.position.x + ICON_X + 4, y - 1), r[0], r[2])
		var col: Color = r[2]
		if r[3] and blink:
			col = col.lightened(0.55)
		_bar(Vector2(panel.position.x + BAR_X, y + 1), r[1], col)
		if r[3]:
			_alert(Vector2(panel.end.x + 3, y - 2), blink)
		y += ROW_H
	if show_temp:
		var hot := s.temperature > 0.0
		UiFrame.icon(self, Vector2(panel.position.x + ICON_X + 4, y - 1), "temp", Color8(240, 120, 50) if hot else Color8(110, 180, 250))
		_temp_bar(Vector2(panel.position.x + BAR_X, y + 1), s.temperature)
		y += ROW_H
	draw_string(_font, Vector2(panel.position.x + ICON_X, y + 9), "Lv%d" % s.level, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, TEXT)
	_bar(Vector2(panel.position.x + BAR_X, y + 2), float(s.xp) / Survival.xp_for_level(s.level), Color8(124, 150, 236), BAR_H - 3.0)
	_draw_comfort(s, panel.end.y + 3.0)
	Accessibility.scale_about(self, Vector2(480, 524))
	_draw_prompt(player)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Room comfort under the panel: "Rested Cosy 4:58" (time it still lasts).
func _draw_comfort(s: Survival, top: float) -> void:
	if s.room_time <= 0.0 or s.room_buffs.is_empty():
		return
	var t := int(ceilf(s.room_time))
	var text := "%s %d:%02d" % [" ".join(Rooms.names_for(s.room_buffs)), t / 60, t % 60]
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x + 12.0
	var r := Rect2(PANEL_POS.x, top, maxf(w, 60.0), 20)
	UiFrame.panel(self, r)
	draw_string(_font, Vector2(r.position.x + 6, r.position.y + 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, Color8(156, 220, 124))


## Centred gauge: blue fills left when cold, orange fills right when hot.
func _temp_bar(pos: Vector2, t: float) -> void:
	_track(pos, BAR_H)
	var mid := pos.x + BAR_W / 2.0
	var w := floorf((BAR_W / 2.0 - 1.0) * clampf(absf(t) / 100.0, 0.0, 1.0))
	var col := Color8(240, 120, 50) if t > 0.0 else Color8(110, 180, 250)
	if absf(t) >= Survival.TEMP_HARM and int(Time.get_ticks_msec() / 250) % 2 == 0:
		col = Color8(250, 250, 250)
	if w > 0.0:
		var x := mid if t > 0.0 else mid - w
		_fill(Rect2(Vector2(x, pos.y + 1), Vector2(w, BAR_H - 2.0)), col)
	draw_rect(Rect2(Vector2(mid, pos.y), Vector2(1, BAR_H)), TEXT)


## "[E] Recover your remains" above the notices when something usable is in reach.
func _draw_prompt(player: Player) -> void:
	for p in get_tree().get_nodes_in_group("ui_panels"):
		if p.visible:
			return
	var thing := player.find_interactable()
	if thing == null or not thing.has_method("interact_hint"):
		return
	var key := Gamepad.prompt("interact")
	var hint: String = thing.interact_hint()
	var kw := _font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x + 8.0
	var w := kw + _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x + 16.0
	var r := Rect2(roundf(480.0 - w / 2.0), 442, w, 22)
	UiFrame.panel(self, r)
	# The key sits in its own little keycap.
	var cap := Rect2(r.position + Vector2(4, 4), Vector2(kw, 14))
	draw_rect(cap, Color8(226, 200, 140))
	draw_rect(Rect2(cap.position.x, cap.end.y - 2, cap.size.x, 2), Color8(150, 112, 64))
	draw_string(_font, Vector2(cap.position.x + 4, cap.position.y + 11), key, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, INK)
	draw_string(_font, Vector2(cap.end.x + 6, r.position.y + 15), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, TEXT)


## Little "!" badge hanging off the panel's right edge.
func _alert(pos: Vector2, lit: bool) -> void:
	var r := Rect2(pos, Vector2(12, 15))
	draw_rect(r.grow(1), INK)
	draw_rect(r, Color8(214, 62, 62) if lit else Color8(120, 30, 34))
	draw_string(_font, Vector2(r.position.x + 3, r.position.y + 12), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, Color8(255, 240, 210))


func _track(pos: Vector2, h: float) -> void:
	draw_rect(Rect2(pos - Vector2(1, 1), Vector2(BAR_W + 2, h + 2)), INK)
	draw_rect(Rect2(pos, Vector2(BAR_W, h)), TRACK)
	draw_rect(Rect2(pos, Vector2(BAR_W, 1)), TRACK.darkened(0.4))


## Glossy fill: lit top rows, a darker lip at the bottom.
func _fill(r: Rect2, color: Color) -> void:
	draw_rect(r, color)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), color.lightened(0.3))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), color.darkened(0.3))


func _bar(pos: Vector2, fraction: float, color: Color, h := BAR_H) -> void:
	_track(pos, h)
	var w := floorf(BAR_W * clampf(fraction, 0.0, 1.0))
	if w > 0.0:
		_fill(Rect2(pos, Vector2(w, h)), color)
	for q in [0.25, 0.5, 0.75]:
		draw_rect(Rect2(Vector2(pos.x + floorf(BAR_W * q), pos.y + 1), Vector2(1, h - 2)), Color(INK, 0.35))