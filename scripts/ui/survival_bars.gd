extends Control
## HUD block with health, hunger, stamina and XP bars (480x270 UI space).

const PANEL := Rect2(4, 22, 112, 62)
const BAR_X := 28.0
const BAR_W := 80.0
const BAR_H := 7.0
const INK := Color8(27, 20, 16)
const BG := Color(0.08, 0.08, 0.12, 0.88)
const EDGE := Color(0.62, 0.55, 0.4, 1)
const TEXT := Color8(238, 226, 196)
const ROWS := [
	["HP", Color8(206, 62, 62)],
	["FD", Color8(226, 152, 58)],
	["EN", Color8(104, 184, 84)],
]

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
	draw_rect(PANEL, BG)
	draw_rect(PANEL, EDGE, false)
	var values := [s.health / s.max_health(), s.hunger / Survival.MAX_HUNGER, s.stamina / Survival.MAX_STAMINA]
	for i in ROWS.size():
		var y := PANEL.position.y + 4.0 + i * 14.0
		draw_string(_font, Vector2(PANEL.position.x + 4, y + 9), ROWS[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)
		var color: Color = ROWS[i][1]
		if i == 1 and s.is_starving():
			color = Color8(150, 40, 40)
		_bar(Vector2(PANEL.position.x + BAR_X, y + 2), values[i], color)
	var y := PANEL.position.y + 4.0 + 3 * 14.0
	draw_string(_font, Vector2(PANEL.position.x + 4, y + 9), "Lv%d" % s.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)
	_bar(Vector2(PANEL.position.x + BAR_X, y + 2), float(s.xp) / Survival.xp_for_level(s.level), Color8(118, 150, 230))


func _bar(pos: Vector2, fraction: float, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(BAR_W, BAR_H)), INK)
	var w := floorf((BAR_W - 2.0) * clampf(fraction, 0.0, 1.0))
	if w > 0.0:
		draw_rect(Rect2(pos + Vector2(1, 1), Vector2(w, BAR_H - 2.0)), color)
		draw_rect(Rect2(pos + Vector2(1, 1), Vector2(w, 1)), color.lightened(0.3))
