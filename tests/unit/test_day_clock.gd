extends TestCase


func test_starts_on_day_one_morning() -> void:
	var clock := DayClock.new()
	check_eq(clock.day(), 1, "day")
	check_eq(clock.phase(), DayClock.Phase.DAY, "phase")
	check_eq(clock.night_index(), 0, "no night yet")


func test_phase_boundaries() -> void:
	check_eq(DayClock.phase_at(0), DayClock.Phase.NIGHT, "midnight")
	check_eq(DayClock.phase_at(DayClock.DAWN_START), DayClock.Phase.DAWN, "dawn")
	check_eq(DayClock.phase_at(DayClock.DAY_START - 1), DayClock.Phase.DAWN, "late dawn")
	check_eq(DayClock.phase_at(DayClock.DUSK_START), DayClock.Phase.DUSK, "dusk")
	check_eq(DayClock.phase_at(DayClock.NIGHT_START), DayClock.Phase.NIGHT, "night")


func test_full_day_emits_events_in_order() -> void:
	var clock := DayClock.new()
	var events := clock.advance(DayClock.MINUTES_PER_DAY)
	var kinds: Array = []
	for e in events:
		kinds.append(e.type if e.type != "phase" else "phase_%d" % e.phase)
	check_eq(kinds, [
		"phase_%d" % DayClock.Phase.DUSK,
		"phase_%d" % DayClock.Phase.NIGHT, "night_started",
		"phase_%d" % DayClock.Phase.DAWN, "day_started",
		"phase_%d" % DayClock.Phase.DAY,
	], "event sequence")
	check_eq(clock.day(), 2, "day after 24h")
	check_eq(clock.night_index(), 1, "one night passed")


func test_day_and_night_indices_in_events() -> void:
	var clock := DayClock.new()
	var nights: Array = []
	var days: Array = []
	for e in clock.advance(DayClock.MINUTES_PER_DAY * 3):
		if e.type == "night_started":
			nights.append(e.night)
		elif e.type == "day_started":
			days.append(e.day)
	check_eq(nights, [1, 2, 3], "night indices")
	check_eq(days, [2, 3, 4], "day indices")


func test_large_step_does_not_skip_boundaries() -> void:
	var a := DayClock.new()
	var b := DayClock.new()
	var big := a.advance(5000.0).size()
	var small := 0
	for i in 500:
		small += b.advance(10.0).size()
	check_eq(big, small, "same number of events")
	check(is_equal_approx(a.total_minutes, b.total_minutes), "same final time")


func test_round_trip() -> void:
	var a := DayClock.new()
	a.advance(2000.0)
	var b := DayClock.new()
	b.from_dict(a.to_dict())
	check_eq(b.day(), a.day(), "day restored")
	check_eq(b.minute_of_day(), a.minute_of_day(), "minute restored")
