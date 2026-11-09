class_name DayClock
extends RefCounted
## Pure day/night clock logic (no nodes, no signals) so it can be tested
## and driven deterministically by the host.
##
## Time is measured in in-game minutes since the start of the campaign.
## A "day" begins at dawn: Day N runs from dawn N to dawn N+1, and
## night N is the night that follows day N.

enum Phase { DAWN, DAY, DUSK, NIGHT }

const MINUTES_PER_DAY := 1440
const DAWN_START := 5 * 60
const DAY_START := 7 * 60
const DUSK_START := 18 * 60
const NIGHT_START := 20 * 60
const BOUNDARIES := [DAWN_START, DAY_START, DUSK_START, NIGHT_START]
const START_MINUTE := DAY_START

var total_minutes: float = START_MINUTE


static func phase_at(minute_of_day: float) -> int:
	if minute_of_day < DAWN_START:
		return Phase.NIGHT
	if minute_of_day < DAY_START:
		return Phase.DAWN
	if minute_of_day < DUSK_START:
		return Phase.DAY
	if minute_of_day < NIGHT_START:
		return Phase.DUSK
	return Phase.NIGHT


static func phase_name(phase: int) -> String:
	return Phase.keys()[phase].capitalize()


func minute_of_day() -> float:
	return fposmod(total_minutes, MINUTES_PER_DAY)


func phase() -> int:
	return phase_at(minute_of_day())


func day() -> int:
	return int(floor((total_minutes - DAWN_START) / MINUTES_PER_DAY)) + 1


## Night index of the current/most recent night (0 before the first night).
func night_index() -> int:
	return int(floor((total_minutes - NIGHT_START) / MINUTES_PER_DAY)) + 1


func is_night() -> bool:
	return phase() == Phase.NIGHT


## Advances the clock and returns the boundary events crossed, in order:
## {"type": "phase", "phase": int} plus "day_started"/"night_started"
## events carrying "day"/"night" indices.
func advance(minutes: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var remaining := minutes
	while remaining > 0.0:
		var mod := minute_of_day()
		var until := _minutes_to_next_boundary(mod)
		if remaining < until:
			total_minutes += remaining
			break
		total_minutes += until
		remaining -= until
		var p := phase()
		events.append({"type": "phase", "phase": p})
		if p == Phase.DAWN:
			events.append({"type": "day_started", "day": day()})
		elif p == Phase.NIGHT:
			events.append({"type": "night_started", "night": night_index()})
	return events


func _minutes_to_next_boundary(mod: float) -> float:
	for b in BOUNDARIES:
		if mod < b:
			return b - mod
	return MINUTES_PER_DAY - mod + DAWN_START


func to_dict() -> Dictionary:
	return {"total_minutes": total_minutes}


func from_dict(data: Dictionary) -> void:
	total_minutes = float(data.get("total_minutes", START_MINUTE))
