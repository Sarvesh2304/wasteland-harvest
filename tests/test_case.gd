extends RefCounted
## Minimal assertion base for the custom test runner (no addons, not GUT).
## Test files extend this and define zero-arg methods named `test_*`.
##
## Mirrors the convention established in the sibling project (blood-fields-empires), trimmed of
## the chess-specific helpers that don't apply here. Add Wasteland Harvest-specific helpers
## (e.g. farm-grid/tile assertions) here as later phases need them.

var _current_test := ""
var _current_failed := false
var _failures: Array[String] = []


func begin_test(name: String) -> void:
	_current_test = name
	_current_failed = false


func did_current_test_fail() -> bool:
	return _current_failed


func get_failures() -> Array[String]:
	return _failures


func fail(message: String) -> void:
	_current_failed = true
	_failures.append("%s — %s" % [_current_test, message])


func assert_true(condition: bool, message := "") -> void:
	if not condition:
		fail("expected true; %s" % message)


func assert_false(condition: bool, message := "") -> void:
	if condition:
		fail("expected false; %s" % message)


func assert_eq(actual, expected, message := "") -> void:
	if actual != expected:
		fail("expected %s, got %s; %s" % [str(expected), str(actual), message])


func assert_ne(actual, unexpected, message := "") -> void:
	if actual == unexpected:
		fail("did not expect %s; %s" % [str(unexpected), message])
