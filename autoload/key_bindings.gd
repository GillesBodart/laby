extends Node
## Rebindable keyboard shortcuts. Each action has one primary physical key
## (the first key event in the project InputMap); secondary keys such as the
## arrow keys for movement stay untouched. Overrides persist in user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"

## Rebindable actions in menu order, with display labels.
const ACTIONS := [
	["move_up", "Move up"], ["move_down", "Move down"], ["move_left", "Move left"],
	["move_right", "Move right"], ["run", "Run"], ["interact", "Gather / use"],
	["attack", "Attack"], ["dodge", "Dodge roll"], ["eat", "Eat"], ["drink", "Drink potion"], ["inventory", "Backpack"], ["map", "Map"],
	["skills", "Skills"], ["journal", "Journal"], ["companion", "Companions follow/stay"], ["stash", "Stash"], ["build_toggle", "Build mode"],
	["build_next", "Next building"], ["build_place", "Place / door"],
	["build_remove", "Remove building"], ["quick_save", "Quick save"], ["quick_load", "Quick load"],
]
## Keys reserved by menus that cannot be bound.
const RESERVED := [KEY_ESCAPE]

var settings_path := SETTINGS_PATH


func _ready() -> void:
	load_bindings()


## Physical keycode of an action's primary key (KEY_NONE if unbound).
func key_of(action: String) -> Key:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev.physical_keycode
	return KEY_NONE


## Human name of a key on the player's keyboard layout (Z on AZERTY for W).
func key_label(key: Key) -> String:
	if key == KEY_NONE:
		return "-"
	var logical := DisplayServer.keyboard_get_keycode_from_physical(key)
	var s := OS.get_keycode_string(logical if logical != KEY_NONE else key)
	return s if s != "" else OS.get_keycode_string(key)


func action_for_key(key: Key) -> String:
	for a in ACTIONS:
		if key_of(a[0]) == key:
			return a[0]
	return ""


## Binds the key; an action already using it receives the old key (swap).
## Returns false for reserved keys.
func rebind(action: String, key: Key) -> bool:
	if key in RESERVED or key == KEY_NONE:
		return false
	var old := key_of(action)
	if old == key:
		return true
	var other := action_for_key(key)
	_set_primary(action, key)
	if other != "":
		_set_primary(other, old)
	save_bindings()
	return true


func reset_defaults() -> void:
	InputMap.load_from_project_settings()
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK and cfg.has_section("keys"):
		cfg.erase_section("keys")
		cfg.save(settings_path)


func save_bindings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	for a in ACTIONS:
		cfg.set_value("keys", a[0], int(key_of(a[0])))
	cfg.save(settings_path)


func load_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	for a in ACTIONS:
		if cfg.has_section_key("keys", a[0]):
			_set_primary(a[0], int(cfg.get_value("keys", a[0])) as Key)


func _set_primary(action: String, key: Key) -> void:
	var events := InputMap.action_get_events(action)
	for ev in events:
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
			break
	if key == KEY_NONE:
		return
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	# Re-add secondaries after the primary so it stays first.
	var rest := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	for r in rest:
		InputMap.action_add_event(action, r)
