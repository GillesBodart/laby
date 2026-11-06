class_name TestCase
extends RefCounted
## Minimal test base: every method starting with "test_" is run by the
## runner; failures are collected rather than aborting.

var failures: Array[String] = []
var _current := ""


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [_current, message])


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%s: %s (expected %s, got %s)" % [_current, message, str(expected), str(actual)])


func run_all() -> int:
	var count := 0
	for method in get_method_list():
		var method_name: String = method.name
		if method_name.begins_with("test_"):
			_current = method_name
			await call(method_name)
			count += 1
	return count
