extends CanvasLayer
## HUD: day/clock panel, survival bars, goal, the panels, and the notice feed
## (bottom right) that shows EventBus.notify messages and item drops.

const NATIVE_SIZE := Vector2(960, 540)
const CLOCK_COLOR := Color(0.93, 0.89, 0.78)
const DUSK_COLOR := UiPalette.AMBER

@onready var icon: TextureRect = %Icon
@onready var clock_label: Label = %ClockLabel

var _night := false
var _clock_panel: Control
## Bottom-right stack of notices (NoticeFeed).
var feed: Control


func _ready() -> void:
	# Panels are laid out for 480x270 and drawn at 2x on the 960x540 viewport;
	# the always-on widgets live in `native`, at the full 960x540 resolution.
	scale = Vector2(2, 2)
	var native := Control.new()
	native.name = "Native"
	native.mouse_filter = Control.MOUSE_FILTER_IGNORE
	native.scale = Vector2(0.5, 0.5)
	native.size = NATIVE_SIZE
	add_child(native)
	move_child(native, 0)
	var clock_panel: Control = $ClockPanel
	_clock_panel = clock_panel
	clock_panel.reparent(native, false)
	clock_panel.position = Vector2(8, 8)
	icon.texture = null
	icon.custom_minimum_size = Vector2(14, 14)
	icon.draw.connect(_draw_phase_icon)
	EventBus.minute_changed.connect(_on_minute_changed)
	var bars := Control.new()
	bars.set_script(preload("res://scripts/ui/hud/survival_bars.gd"))
	native.add_child(bars)
	var goal_box := Control.new()
	goal_box.set_script(preload("res://scripts/ui/hud/goal_box.gd"))
	native.add_child(goal_box)
	var panel := PanelContainer.new()
	panel.set_script(preload("res://scripts/ui/panels/crafting_panel.gd"))
	add_child(panel)
	var map_panel := Control.new()
	map_panel.set_script(preload("res://scripts/ui/panels/map_panel.gd"))
	add_child(map_panel)
	var skills_panel := Control.new()
	skills_panel.set_script(preload("res://scripts/ui/panels/skills_panel.gd"))
	add_child(skills_panel)
	var journal_panel := Control.new()
	journal_panel.set_script(preload("res://scripts/ui/panels/journal_panel.gd"))
	add_child(journal_panel)
	var stash_panel := Control.new()
	stash_panel.set_script(preload("res://scripts/ui/panels/stash_panel.gd"))
	add_child(stash_panel)
	var seed_panel := Control.new()
	seed_panel.set_script(preload("res://scripts/ui/panels/seed_panel.gd"))
	add_child(seed_panel)
	var settlement_panel := Control.new()
	settlement_panel.set_script(preload("res://scripts/ui/panels/settlement_panel.gd"))
	add_child(settlement_panel)
	var waystone_panel := Control.new()
	waystone_panel.set_script(preload("res://scripts/ui/panels/waystone_panel.gd"))
	add_child(waystone_panel)
	var epilogue := Control.new()
	epilogue.set_script(preload("res://scripts/ui/panels/epilogue_panel.gd"))
	add_child(epilogue)
	# Drawn at native resolution; it hides itself while a panel is open.
	feed = Control.new()
	feed.set_script(preload("res://scripts/ui/hud/notice_feed.gd"))
	feed.scale = Vector2(0.5, 0.5)
	add_child(feed)
	EventBus.notify.connect(show_notice)
	# Added last so it sees Esc after panels had the chance to close themselves.
	var menu := Control.new()
	menu.set_script(preload("res://scripts/ui/menus/settings_menu.gd"))
	add_child(menu)
	_on_minute_changed(TimeSystem.clock.day(), int(TimeSystem.minute_of_day()))
	Accessibility.changed.connect(_apply_text_size)
	_apply_text_size()


## The clock grows from the top-left corner.
func _apply_text_size() -> void:
	var s := Accessibility.text_scale()
	_clock_panel.scale = Vector2(s, s)
	_clock_panel.position = Vector2(8, 8) * s


func _on_minute_changed(day: int, minute_of_day: int) -> void:
	var phase := DayClock.phase_at(minute_of_day)
	# The sun / moon icon tells the phase; only dusk adds a countdown.
	clock_label.text = "Day %d  %02d:%02d" % [day, minute_of_day / 60, minute_of_day % 60]
	# Dusk counts down to nightfall: the gates shut and the maze shifts then.
	var left := DayClock.NIGHT_START - minute_of_day
	if phase == DayClock.Phase.DUSK and left > 0:
		clock_label.text += "  -  night in %d:%02d" % [left / 60, left % 60]
		clock_label.add_theme_color_override("font_color", DUSK_COLOR)
	else:
		clock_label.add_theme_color_override("font_color", CLOCK_COLOR)
	_night = phase == DayClock.Phase.NIGHT
	icon.queue_redraw()
	_clock_panel.reset_size()


## Smooth sun (rays around a disc) or crescent moon telling the day phase.
func _draw_phase_icon() -> void:
	var c := icon.size / 2.0
	var ink := UiPalette.INK
	if _night:
		# Crescent: the outer disc minus a disc offset up-right.
		var R := 6.0
		var r := 5.0
		var q := Vector2(3.0, -1.5)
		var d := q.length()
		var tu := q.angle()
		var a := (R * R - r * r + d * d) / (2.0 * d)
		var h := sqrt(R * R - a * a)
		# Angles of the two cusps, seen from each circle's centre.
		var phi := atan2(h, a)
		var psi := atan2(h, a - d)
		var moon := PackedVector2Array()
		for i in 25:
			moon.append(c + Vector2.from_angle(lerpf(tu + phi, tu + TAU - phi, i / 24.0)) * R)
		# Back along the bite, on the side facing the moon's centre.
		for i in range(1, 24):
			moon.append(c + q + Vector2.from_angle(lerpf(tu - psi, tu + psi - TAU, i / 24.0)) * r)
		var loop := moon.duplicate()
		loop.append(moon[0])
		icon.draw_polyline(loop, ink, 2.0, true)
		icon.draw_colored_polygon(moon, Color8(214, 222, 240))
		return
	var sun := Color8(255, 204, 82)
	for i in 8:
		var d := Vector2.RIGHT.rotated(i * TAU / 8.0)
		icon.draw_line(c + d * 4.6, c + d * 6.6, ink, 2.6, true)
		icon.draw_line(c + d * 4.8, c + d * 6.3, sun, 1.3, true)
	icon.draw_circle(c, 4.2, ink, true, -1.0, true)
	icon.draw_circle(c, 3.3, sun, true, -1.0, true)
	icon.draw_circle(c + Vector2(-1.1, -1.1), 1.1, Color(1, 1, 0.85, 0.8), true, -1.0, true)


## A message in the bottom-right notice feed.
func show_notice(text: String) -> void:
	feed.push_text(text)
