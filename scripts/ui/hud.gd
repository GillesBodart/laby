extends CanvasLayer
## Retro HUD: day/clock panel and transient notifications.

const ICONS := preload("res://assets/ui/time_icons.png")
const NOTICE_SECONDS := 3.5

@onready var icon: TextureRect = %Icon
@onready var clock_label: Label = %ClockLabel
@onready var notice: Label = %Notice

var _sun := AtlasTexture.new()
var _moon := AtlasTexture.new()
var _notice_tween: Tween


func _ready() -> void:
	# UI is laid out for 480x270 and drawn at 2x on the 960x540 viewport.
	scale = Vector2(2, 2)
	notice.set_anchors_preset(Control.PRESET_TOP_LEFT)
	notice.position = Vector2(40, 246)
	notice.size = Vector2(400, 16)
	_sun.atlas = ICONS
	_sun.region = Rect2(0, 0, 9, 9)
	_moon.atlas = ICONS
	_moon.region = Rect2(9, 0, 9, 9)
	notice.modulate.a = 0.0
	EventBus.minute_changed.connect(_on_minute_changed)
	EventBus.notify.connect(show_notice)
	var bars := Control.new()
	bars.set_script(preload("res://scripts/ui/survival_bars.gd"))
	add_child(bars)
	var panel := PanelContainer.new()
	panel.set_script(preload("res://scripts/ui/crafting_panel.gd"))
	add_child(panel)
	var map_panel := Control.new()
	map_panel.set_script(preload("res://scripts/ui/map_panel.gd"))
	add_child(map_panel)
	var skills_panel := Control.new()
	skills_panel.set_script(preload("res://scripts/ui/skills_panel.gd"))
	add_child(skills_panel)
	var journal_panel := Control.new()
	journal_panel.set_script(preload("res://scripts/ui/journal_panel.gd"))
	add_child(journal_panel)
	var stash_panel := Control.new()
	stash_panel.set_script(preload("res://scripts/ui/stash_panel.gd"))
	add_child(stash_panel)
	var seed_panel := Control.new()
	seed_panel.set_script(preload("res://scripts/ui/seed_panel.gd"))
	add_child(seed_panel)
	var waystone_panel := Control.new()
	waystone_panel.set_script(preload("res://scripts/ui/waystone_panel.gd"))
	add_child(waystone_panel)
	# Added last so it sees Esc after panels had the chance to close themselves.
	var menu := Control.new()
	menu.set_script(preload("res://scripts/ui/settings_menu.gd"))
	add_child(menu)
	_on_minute_changed(TimeSystem.clock.day(), int(TimeSystem.minute_of_day()))


func _on_minute_changed(day: int, minute_of_day: int) -> void:
	var phase := DayClock.phase_at(minute_of_day)
	clock_label.text = "Day %d  %02d:%02d  %s" % [day, minute_of_day / 60, minute_of_day % 60, DayClock.phase_name(phase)]
	icon.texture = _moon if phase == DayClock.Phase.NIGHT else _sun


func show_notice(text: String) -> void:
	notice.text = text
	if _notice_tween:
		_notice_tween.kill()
	notice.modulate.a = 1.0
	_notice_tween = create_tween()
	_notice_tween.tween_interval(NOTICE_SECONDS)
	_notice_tween.tween_property(notice, "modulate:a", 0.0, 0.6)
