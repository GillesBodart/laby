class_name Farming
extends RefCounted
## Pure crop-growth rules for farm plots (no nodes). Time is the DayClock's
## total_minutes; `planted` is the minute a berry was sown, or NOT_PLANTED.

const NOT_PLANTED := -1.0
## A third of an in-game day (4 real minutes at the default day length).
const GROW_MINUTES := 480.0
const EMPTY := 0
const GROWING := 1
const RIPE := 2


static func stage(planted: float, now: float) -> int:
	if planted < 0.0:
		return EMPTY
	return RIPE if now - planted >= GROW_MINUTES else GROWING


static func minutes_left(planted: float, now: float) -> float:
	return maxf(GROW_MINUTES - (now - planted), 0.0)
