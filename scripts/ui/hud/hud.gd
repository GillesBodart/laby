extends CanvasLayer
## HUD: day/clock panel, survival bars, goal, the panels, and the notice feed
## (bottom right) that shows EventBus.notify messages and item drops.

const ICONS := preload("res://assets/ui/icons/time_icons.png")
const NATIVE_SIZE := Vector2(960, 540)
const CLOCK_COLOR := Color(0.93, 0.89, 0.78)
const DUSK_COLOR := UiPalette.AMBER

@onready var icon: TextureRect = %Icon
@onready var clock_label: Label = %ClockLabel

var _sun := AtlasTexture.new()
var _moon := AtlasTexture.new()
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
	_sun.atlas = ICONS
	_sun.region = Rect2(0, 0, 9, 9)
	_moon.atlas = ICONS
	_moon.region = Rect2(9, 0, 9, 9)
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
	icon.texture = _moon if phase == DayClock.Phase.NIGHT else _sun
	_clock_panel.reset_size()


## A message in the bottom-right notice feed.
func show_notice(text: String) -> void:
	feed.push_text(text)
