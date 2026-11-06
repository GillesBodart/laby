extends Node
## Drives the DayClock in real time and broadcasts time events on the
## EventBus. Only the authority (host / offline) advances time; clients
## will receive it via sync once LAN co-op lands.

## Real seconds for one full in-game day (default: 12 minutes).
@export var real_seconds_per_day: float = 720.0

var clock := DayClock.new()
var time_scale: float = 1.0
var paused: bool = false
var _last_minute: int = -1


func _process(delta: float) -> void:
	if paused or not GameState.is_authority():
		return
	advance(delta * time_scale * DayClock.MINUTES_PER_DAY / real_seconds_per_day)


func advance(minutes: float) -> void:
	for event in clock.advance(minutes):
		match event.type:
			"phase":
				EventBus.phase_changed.emit(event.phase)
			"day_started":
				EventBus.day_started.emit(event.day)
			"night_started":
				EventBus.night_started.emit(event.night)
	var minute := int(clock.minute_of_day())
	if minute != _last_minute:
		_last_minute = minute
		EventBus.minute_changed.emit(clock.day(), minute)


func reset() -> void:
	clock = DayClock.new()
	_last_minute = -1


func set_time_of_day(minute_of_day: int) -> void:
	var base := (clock.day() - 1) * DayClock.MINUTES_PER_DAY + DayClock.DAWN_START
	var offset := fposmod(minute_of_day - DayClock.DAWN_START, DayClock.MINUTES_PER_DAY)
	clock.total_minutes = base + offset
	_broadcast_state()


func minute_of_day() -> float:
	return clock.minute_of_day()


func phase() -> int:
	return clock.phase()


func get_save_data() -> Dictionary:
	return clock.to_dict()


func load_save_data(data: Dictionary) -> void:
	clock.from_dict(data)
	_broadcast_state()


func _broadcast_state() -> void:
	_last_minute = int(clock.minute_of_day())
	EventBus.phase_changed.emit(clock.phase())
	EventBus.minute_changed.emit(clock.day(), _last_minute)
