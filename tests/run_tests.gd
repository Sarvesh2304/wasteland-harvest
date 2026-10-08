extends SceneTree
## Headless test runner: godot --headless --path . --script res://tests/run_tests.gd
##
## Same convention as the sibling project (blood-fields-empires): a custom lightweight
## GDScript test runner, no addons (not GUT), invocable headlessly per CLAUDE.md's Testing
## section. Test files live alongside this script as `test_*.gd`, extend `test_case.gd`, and
## define zero-arg methods named `test_*`. Phase 1 ships this harness with a single trivial
## placeholder test proving the scaffold runs end-to-end; real systems tests land from Phase 2
## onward as those systems exist.

const TESTS_DIR := "res://tests/"


func _initialize() -> void:
	var total := 0
	var failed := 0
	for file_name in _discover_test_files():
		var case = load(TESTS_DIR + file_name).new()
		var basename := file_name.get_basename()
		for method_name in _discover_test_methods(case):
			total += 1
			var failures_before: int = case.get_failures().size()
			case.begin_test("%s.%s" % [basename, method_name])
			case.call(method_name)
			if case.did_current_test_fail():
				failed += 1
				var failures: Array[String] = case.get_failures()
				for i in range(failures_before, failures.size()):
					print("FAIL: %s" % failures[i])
	print("Ran %d tests, %d passed, %d failed." % [total, total - failed, failed])
	quit(0 if failed == 0 else 1)


## WH_TEST_FILTER=<text> runs only the test files whose name contains <text> (e.g. "ruins").
func _discover_test_files() -> Array[String]:
	var only := OS.get_environment("WH_TEST_FILTER")
	var files: Array[String] = []
	for file_name in DirAccess.get_files_at(TESTS_DIR):
		if file_name.begins_with("test_") and file_name.ends_with(".gd") \
				and file_name != "test_case.gd" and (only == "" or file_name.contains(only)):
			files.append(file_name)
	files.sort()
	return files


func _discover_test_methods(case) -> Array[String]:
	var methods: Array[String] = []
	for method in case.get_method_list():
		if method.name.begins_with("test_") and method.args.is_empty():
			methods.append(method.name)
	methods.sort()
	return methods
