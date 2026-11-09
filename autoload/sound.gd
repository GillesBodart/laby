extends Node
## Plays the game's synthesised sound (see Synth): positional-ish effects
## through a small voice pool, and an ambience bed that follows the area and
## the time of day (with birds by day in the Clearing, distant clanks and
## growls in the maze). Volumes (0-10) persist in user://settings.cfg.

const VOICES := 10
## Effects farther than this from the local player are not heard.
const HEARING := 520.0
const CHANNELS := ["master", "sfx", "ambience"]
const DEFAULTS := {"master": 8, "sfx": 8, "ambience": 6}
const BUS := {"sfx": "SFX", "ambience": "Ambience"}

var settings_path := "user://settings.cfg"
var volume := DEFAULTS.duplicate()
var ambience := ""

var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _beds: Array[AudioStreamPlayer] = []
var _bed := 0
var _check := 0.0
var _flourish := 6.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for ch in BUS:
		if AudioServer.get_bus_index(BUS[ch]) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, BUS[ch])
			AudioServer.set_bus_send(i, "Master")
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS.sfx
		add_child(p)
		_pool.append(p)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS.ambience
		p.volume_db = -80.0
		add_child(p)
		_beds.append(p)
	load_volumes()
	EventBus.day_started.connect(func(_d): play("dawn"))
	EventBus.night_started.connect(func(_n): play("dusk"))


## Plays an effect; `at` (world position) fades it with distance to the
## local player. Returns false when it is out of earshot or unknown.
func play(id: String, at := Vector2.INF, pitch_jitter := 0.06) -> bool:
	if not Synth.has_sound(id):
		return false
	var gain := 1.0
	if at != Vector2.INF:
		var me: Node2D = GameState.players.get(GameState.local_peer_id())
		if me and is_instance_valid(me):
			gain = clampf(1.0 - me.global_position.distance_to(at) / HEARING, 0.0, 1.0)
		if gain <= 0.0:
			return false
	if not _cache.has(id):
		_cache[id] = Synth.render(id)
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _cache[id]
	p.volume_db = linear_to_db(0.25 + 0.75 * gain)
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()
	return true


## Ambience for an area and phase.
static func ambience_for(area: String, night: bool) -> String:
	if area == "clearing":
		return "night" if night else "meadow"
	return "maze_night" if night else "maze"


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		var night := TimeSystem.phase() == DayClock.Phase.NIGHT
		set_ambience(ambience_for(GameState.area, night) if not GameState.players.is_empty() else "")
	# Cross-fade: the current bed rises, the other one fades out.
	for i in _beds.size():
		var target := 0.0 if i == _bed and ambience != "" else -60.0
		var p := _beds[i]
		p.volume_db = move_toward(p.volume_db, target, delta * 30.0)
		if i != _bed and p.playing and p.volume_db <= -59.0:
			p.stop()
	_flourish -= delta
	if _flourish <= 0.0 and ambience != "":
		_flourish = randf_range(5.0, 14.0)
		match ambience:
			"meadow":
				play("bird", Vector2.INF, 0.15)
			"maze":
				play("clank", Vector2.INF, 0.2)
			"maze_night":
				play("growl" if randf() < 0.5 else "clank", Vector2.INF, 0.2)


func set_ambience(kind: String) -> void:
	if kind == ambience:
		return
	ambience = kind
	if kind == "":
		return
	_bed = 1 - _bed
	var key := "amb_" + kind
	if not _cache.has(key):
		_cache[key] = Synth.render_ambience(kind)
	var p := _beds[_bed]
	p.stream = _cache[key]
	p.volume_db = -60.0
	p.play()


# ------------------------------------------------------------- volume

func set_volume(channel: String, level: int) -> void:
	volume[channel] = clampi(level, 0, 10)
	_apply()
	save_volumes()


func _apply() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(volume.master / 10.0, 0.0001)))
	AudioServer.set_bus_mute(master, volume.master == 0)
	for ch in BUS:
		var i := AudioServer.get_bus_index(BUS[ch])
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volume[ch] / 10.0, 0.0001)))
		AudioServer.set_bus_mute(i, volume[ch] == 0)


func save_volumes() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	for ch in CHANNELS:
		cfg.set_value("audio", ch, int(volume[ch]))
	cfg.save(settings_path)


func load_volumes() -> void:
	volume = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		for ch in CHANNELS:
			volume[ch] = clampi(int(cfg.get_value("audio", ch, DEFAULTS[ch])), 0, 10)
	_apply()
