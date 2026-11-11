extends Control
## HUD "Goal" box (top-right, native 960x540): the next step of the
## Objectives chain with its progress and a one-line hint. A goal met pops a
## notice and a chime. The first check after a load is silent, so an old save
## does not replay the whole chain.

const WIDTH := 252.0
const RIGHT := 952.0
const TOP := 8.0
const PAD := 6.0
const FONT := 16
const LINE := 17.0
const CHECK_EVERY := 0.5
const GOLD := Color8(240, 196, 92)
const DIM := Color8(184, 172, 148)

var _font: Font
var _wait := 0.0
var _primed := false
var _ctx := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.get_project_theme().default_font
	size = Vector2(960, 540)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = CHECK_EVERY
	var player := GameState.players.get(GameState.local_peer_id()) as Player
	if player == null:
		return
	_ctx = Objectives.context(player)
	var fresh: Array = Objectives.update(GameState.goals, _ctx)
	if _primed and not fresh.is_empty():
		var next := Objectives.current(GameState.goals)
		var text := "Goal complete: %s" % Objectives.by_id(fresh[-1]).text
		if not next.is_empty():
			text += "  -  Next: %s" % next.text
		EventBus.notify.emit(text)
		Sound.play("level")
	_primed = true
	queue_redraw()


func _draw() -> void:
	if not _primed:
		return
	for p in get_tree().get_nodes_in_group("ui_panels"):
		if p.visible:
			return
	var goal := Objectives.current(GameState.goals)
	if goal.is_empty():
		return
	var p := Objectives.progress(goal, _ctx)
	var inner := WIDTH - PAD * 2.0
	var hint_h := _font.get_multiline_string_size(goal.hint, HORIZONTAL_ALIGNMENT_LEFT, inner, FONT).y
	var r := Rect2(RIGHT - WIDTH, TOP, WIDTH, PAD * 2.0 + LINE * 2.0 + hint_h + 2.0)
	UiFrame.panel(self, r)
	var x := r.position.x + PAD
	var y := r.position.y + PAD + 12.0
	draw_string(_font, Vector2(x, y), "GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, GOLD)
	if p[1] > 1:
		draw_string(_font, Vector2(x, y), "%d/%d" % p, HORIZONTAL_ALIGNMENT_RIGHT, inner, FONT, GOLD)
	y += LINE
	draw_string(_font, Vector2(x, y), goal.text, HORIZONTAL_ALIGNMENT_LEFT, inner, FONT, UiFrame.TEXT)
	y += LINE
	draw_multiline_string(_font, Vector2(x, y + 2.0), goal.hint, HORIZONTAL_ALIGNMENT_LEFT, inner, FONT, -1, DIM)
