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
	_sun.atlas = ICONS
	_sun.region = Rect2(0, 0, 9, 9)
	_moon.atlas = ICONS
	_moon.region = Rect2(9, 0, 9, 9)
	notice.modulate.a = 0.0
	EventBus.minute_changed.connect(_on_minute_changed)
	EventBus.notify.connect(show_notice)
	var panel := PanelContainer.new()
	panel.set_script(preload("res://scripts/ui/crafting_panel.gd"))
	add_child(panel)
	var stash_panel := PanelContainer.new()
	stash_panel.set_script(preload("res://scripts/ui/stash_panel.gd"))
	add_child(stash_panel)
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
