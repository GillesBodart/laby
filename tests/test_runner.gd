extends Node
## Headless test runner (autoloads available). Run:
##   godot --headless --path . res://tests/test_runner.tscn
## Exit code is the number of failures.

const SUITES := [
	"res://tests/unit/test_day_clock.gd",
	"res://tests/unit/test_clearing_generator.gd",
	"res://tests/unit/test_save_system.gd",
	"res://tests/unit/test_crafting.gd",
	"res://tests/unit/test_survival.gd",
	"res://tests/unit/test_project_setup.gd",
	"res://tests/integration/test_world.gd",
	"res://tests/integration/test_building.gd",
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var total := 0
	for path in SUITES:
		var suite: TestCase = load(path).new()
		var count: int = await suite.run_all()
		total += count
		failures.append_array(suite.failures)
		print("%s: %d tests, %d failures" % [path.get_file(), count, suite.failures.size()])
	for f in failures:
		printerr("FAIL ", f)
	print("== %d tests, %d failures ==" % [total, failures.size()])
	get_tree().quit(failures.size())
