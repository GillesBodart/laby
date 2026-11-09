extends TestCase

const TEST_PATH := "user://test_settings.cfg"


func _with_temp_settings() -> String:
	var saved: String = KeyBindings.settings_path
	KeyBindings.settings_path = TEST_PATH
	return saved


func _restore(saved: String) -> void:
	KeyBindings.reset_defaults()
	KeyBindings.settings_path = saved


func test_rebind_swaps_conflicting_keys_and_persists() -> void:
	var saved := _with_temp_settings()
	var eat_key := KeyBindings.key_of("eat")
	var attack_key := KeyBindings.key_of("attack")
	check(KeyBindings.rebind("attack", eat_key), "rebind accepted")
	check_eq(KeyBindings.key_of("attack"), eat_key, "attack takes the key")
	check_eq(KeyBindings.key_of("eat"), attack_key, "eat receives the old key")
	InputMap.load_from_project_settings()
	KeyBindings.load_bindings()
	check_eq(KeyBindings.key_of("attack"), eat_key, "binding reloaded from settings file")
	var cfg := ConfigFile.new()
	cfg.load(TEST_PATH)
	cfg.set_value("audio", "master", 3)
	cfg.save(TEST_PATH)
	_restore(saved)
	check_eq(KeyBindings.key_of("attack"), attack_key, "reset restores default")
	cfg = ConfigFile.new()
	cfg.load(TEST_PATH)
	check(not cfg.has_section("keys"), "reset forgets the key bindings")
	check_eq(cfg.get_value("audio", "master", 0), 3, "reset keeps other settings")
	DirAccess.remove_absolute(TEST_PATH)


func test_rebind_rejects_escape_and_keeps_secondary_keys() -> void:
	var saved := _with_temp_settings()
	var before := InputMap.action_get_events("move_up").size()
	check(not KeyBindings.rebind("move_up", KEY_ESCAPE), "escape is reserved")
	check(KeyBindings.rebind("move_up", KEY_P), "rebind to free key")
	var events := InputMap.action_get_events("move_up")
	check_eq(events.size(), before, "secondary keys kept")
	check_eq(KeyBindings.key_of("move_up"), KEY_P, "new key is primary")
	_restore(saved)
