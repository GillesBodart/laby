extends TestCase

const TEST_PATH := "user://test_sound_settings.cfg"


func test_every_effect_renders_audible() -> void:
	for id in Synth.SOUNDS:
		var w := Synth.render(id)
		check(w.data.size() > 200, "%s has samples" % id)
		check(Synth.peak(w) > 0.05, "%s is audible" % id)
		check(Synth.peak(w) <= 1.0, "%s does not clip" % id)
		check(w.get_length() < 3.0, "%s is short" % id)
		check_eq(w.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s plays once" % id)


func test_render_is_deterministic() -> void:
	check_eq(Synth.render("hit", 4).data, Synth.render("hit", 4).data, "same seed, same sound")
	check(not Synth.has_sound("nonsense"), "unknown sound")
	check(not Sound.play("nonsense"), "unknown sound is not played")


func test_ambience_loops() -> void:
	for kind in Synth.AMBIENCE:
		var w := Synth.render_ambience(kind)
		check_eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops" % kind)
		check(absf(w.get_length() - Synth.LOOP_SECONDS) < 0.6, "%s loop length" % kind)
		check(Synth.peak(w) > 0.02, "%s is audible" % kind)


func test_ambience_follows_area_and_night() -> void:
	check_eq(Sound.ambience_for("clearing", false), "meadow", "clearing by day")
	check_eq(Sound.ambience_for("clearing", true), "night", "clearing at night")
	check_eq(Sound.ambience_for("sector_1_0", false), "maze", "maze by day")
	check_eq(Sound.ambience_for("sector_1_0", true), "maze_night", "maze at night")


func test_volume_persists_and_mutes() -> void:
	var saved_path := Sound.settings_path
	var saved: Dictionary = Sound.volume.duplicate()
	Sound.settings_path = TEST_PATH
	Sound.set_volume("sfx", 3)
	Sound.set_volume("master", 14)
	Sound.set_volume("ambience", 0)
	check_eq(Sound.volume.master, 10, "volume clamped")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")), "zero mutes the bus")
	Sound.volume = Sound.DEFAULTS.duplicate()
	Sound.load_volumes()
	check_eq(Sound.volume.sfx, 3, "sfx volume reloaded")
	check_eq(Sound.volume.ambience, 0, "ambience volume reloaded")
	DirAccess.remove_absolute(TEST_PATH)
	Sound.settings_path = saved_path
	for ch in saved:
		Sound.set_volume(ch, saved[ch])
